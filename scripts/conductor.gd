extends Node
## Global clock for everything rhythmic (autoloaded as "Conductor").
## Timing always comes from the audio playback position, never from frame
## delta. Based on Godot's "Sync the gameplay with audio and music" docs page.

signal beat(beat_number: int)
signal measure(measure_number: int)
signal song_finished

var bpm: float = 120.0
var beats_per_measure: int = 4
## Extra correction for audio/input lag, in seconds. Raise it when players
## are always measured late; lower it when they are always measured early.
var latency_offset: float = 0.0
## Restart the song when it ends (handy for tests and menus).
var loop: bool = true

## Latency-corrected song time in seconds, updated every frame.
var song_position: float = 0.0
var song_position_in_beats: float = 0.0

var seconds_per_beat: float:
	get:
		return 60.0 / bpm

var _last_beat: int = -1
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	# Web builds default to "sample" playback, where get_playback_position()
	# lags the real audio by exactly 1 s (the position worklet is held in reset
	# for a second). Mixing the music in Godot keeps the position accurate.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.finished.connect(_on_player_finished)


func play_song(stream: AudioStream, song_bpm: float, start_at: float = 0.0) -> void:
	bpm = song_bpm
	_player.stream = stream
	_last_beat = -1
	_player.play(start_at)


func stop() -> void:
	_player.stop()
	_last_beat = -1


func is_playing() -> bool:
	return _player.playing


## What the player is hearing right now, in seconds, corrected for latency.
func get_song_position() -> float:
	if not _player.playing:
		return song_position
	var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix()
	pos -= AudioServer.get_output_latency()
	pos -= latency_offset
	return pos


## Seconds between now and the nearest beat. Negative = early, positive = late.
func offset_from_nearest_beat() -> float:
	var beats := get_song_position() / seconds_per_beat
	return (beats - roundf(beats)) * seconds_per_beat


func _process(_delta: float) -> void:
	if not _player.playing:
		return
	song_position = get_song_position()
	song_position_in_beats = song_position / seconds_per_beat
	var current_beat := floori(song_position_in_beats)
	if current_beat > _last_beat and song_position >= 0.0:
		_last_beat = current_beat
		beat.emit(current_beat)
		if current_beat % beats_per_measure == 0:
			measure.emit(floori(float(current_beat) / beats_per_measure))


func _on_player_finished() -> void:
	song_finished.emit()
	if loop:
		_last_beat = -1
		_player.play()
