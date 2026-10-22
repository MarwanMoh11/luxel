extends Node
## The run track: the round 3 arc (docs/soundtrack/round3/arc.py) as phrases, run_*.ogg, played back to back by an
## AudioStreamInteractive. Each phrase starts on the bar line where the last one ends, over the last one's ring.
## run.json says which phrase follows which. The arc follows the world's clock, not the music's: a menu stops the
## world but the music plays on behind the wall, so at three hold points (the opening's engine, the theme, Night)
## the music carries on with its own phrases until the run time is due for the next part, then hands over at a
## phrase end. Without menus the order is the arc as written. (Horizontal re-sequencing, as Wwise and FMOD games
## keep a score on the game's timeline.)

const DIR := "res://audio/music/"
## A phrase's successor is picked and queued in its last bar (late, so the run time is fresh)...
const QUEUE_BARS := 1.0
## ...but never closer to the bar line than this (the stream must get the request before it mixes past it).
const MARGIN := 0.15
## The clock: a silent 8-bit loop that starts with the track (one bar = 2000 samples). Its position is the track's.
const CLOCK_RATE := 1200
const CLOCK_BARS := 64
## Each phrase starts this much before its bar line on average: the stream times it from the last phrase's Ogg
## position, which its resampler reads 0-128 frames ahead (measured: 0-3.3 ms, mean 1.3).
const EARLY := 64.0 / 44100.0

## The arc (an AudioStreamInteractive): set volume_db and read playing as for any player.
var player: AudioStreamPlayer
## After tape_out(): the phrase that was playing, alone and from the same spot, for the MUSIC-sold wind-down
## (an interactive stream ignores pitch_scale).
var tape: AudioStreamPlayer
var plan := {} ## run.json: bpm, bar (seconds), start, phrases {name: {file, bars, part, next, exit?}}

var _stream: AudioStreamInteractive
var _clock: AudioStreamPlayer
var _slot := {} # phrase -> clip index
var _bar := 0.0
var _wraps := 0
var _last_pos := 0.0
var _r0 := 0.0 # run time when the track started
var _cur := "" # the phrase playing
var _cur_at := 0.0 # when it started, in clock seconds
var _cur_beat := 0.0 # where it starts in the music (whole bars since the track started), in seconds
var _next := "" # the phrase queued after it ("" until its last bar)


## Loads run.json and the phrases; the players go to `bus`.
func setup(bus: String) -> void:
	plan = JSON.parse_string(FileAccess.get_file_as_string(DIR + "run.json"))
	_bar = float(plan["bar"])
	var phrases: Dictionary = plan["phrases"]
	_stream = AudioStreamInteractive.new()
	_stream.clip_count = phrases.size()
	for name: String in phrases:
		var ph: Dictionary = phrases[name]
		var s: AudioStreamOggVorbis = load(DIR + str(ph["file"]))
		s.loop = false # it rings on under the next phrase
		s.bpm = float(plan["bpm"])
		s.beat_count = int(ph["bars"]) * 4 # its end is this bar line, not the end of its ring
		s.bar_beats = 4
		_slot[name] = _slot.size()
		_stream.set_clip_name(_slot[name], name)
		_stream.set_clip_stream(_slot[name], s)
	_stream.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
			AudioStreamInteractive.TRANSITION_FROM_TIME_END, AudioStreamInteractive.TRANSITION_TO_TIME_START,
			AudioStreamInteractive.FADE_DISABLED, 1.0)
	player = _player(_stream, bus)
	tape = _player(null, bus)
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_8_BITS
	silence.mix_rate = CLOCK_RATE
	var data := PackedByteArray()
	data.resize(roundi(CLOCK_BARS * _bar * CLOCK_RATE))
	silence.data = data
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = data.size()
	_clock = _player(silence, bus)


## Starts the arc from its first phrase (or `from`, for checks), `run_time` being the run's clock now.
func play(run_time: float, from := "") -> void:
	_r0 = run_time
	_begin(from if from != "" else str(plan["start"]))


func stop() -> void:
	player.stop()
	_clock.stop()
	tape.stop()
	_cur = ""


## Every frame: notices the phrase that started, and in each phrase's last bar queues the next one.
func step(run_time: float) -> void:
	if not player.playing or _cur == "":
		return
	var t := _time()
	var end := _cur_at + _len(_cur)
	if _next != "" and t >= end:
		_cur_beat += _len(_cur)
		_cur = _next
		_cur_at = end - EARLY
		_next = ""
		end = _cur_at + _len(_cur)
	var left := end - t
	if _next != "" or left > QUEUE_BARS * _bar:
		return
	if left > MARGIN:
		# Only once the stream itself has started this phrase (it can trail the clock by a few ms): a request
		# while the last phrase is still its current one waits from that phrase's end, which has passed, and
		# Godot 4.7 then mixes the next one from a negative offset, out of its buffer (a crash).
		var playback := player.get_stream_playback() as AudioStreamPlaybackInteractive
		if playback.get_current_clip_index() != _slot[_cur]:
			return
		_next = pick(plan, _cur, run_time - _r0 + left)
		playback.switch_to_clip(_slot[_next])
	elif left < 0.0: # its bar line went by unqueued (a long stall): the next phrase starts now
		_begin(pick(plan, _cur, run_time - _r0))


## The phrase after `name`, which ends at run time `at` (seconds since the track started, if no menu opens on the
## way): its exit once the next part is due within half the wait for the next chance to hand over, else its
## default. arc.py pick() is the same rule.
static func pick(p: Dictionary, name: String, at: float) -> String:
	var ph: Dictionary = p["phrases"][name]
	if not ph.has("exit"):
		return ph["next"]
	var e: Dictionary = ph["exit"]
	if float(e["due"]) - (at + float(e["lead"])) <= float(e["hold"]) / 2.0:
		return e["to"]
	return ph["next"]


## The part of the arc playing: "", "night" or "light" ("" when stopped).
func part() -> String:
	if not player.playing or _cur == "":
		return ""
	return str(plan["phrases"][_now()]["part"])


## Music seconds for the beat grid (bar lines where the phrases start, so it stays on the beat); -1 when stopped.
func clock() -> float:
	if not player.playing or _cur == "":
		return -1.0
	# Movie Maker mixes once per frame, so the wall time since the last mix is only noise there (renders repeat)
	return _cur_beat + _time() - _cur_at + (0.0 if OS.has_feature("movie") else AudioServer.get_time_since_last_mix())


## MUSIC sold: the phrase playing goes on alone on `tape` from the same spot, and the arc stops. -> tape
func tape_out() -> AudioStreamPlayer:
	var name := _now()
	var at := _cur_at if name == _cur else _cur_at + _len(_cur) - EARLY
	tape.stream = _stream.get_clip_stream(_slot[name]) if name != "" else null
	tape.volume_db = player.volume_db
	tape.pitch_scale = 1.0
	if tape.stream:
		tape.play(maxf(_time() - at, 0.0))
	player.stop()
	_clock.stop()
	_cur = ""
	return tape


func _begin(name: String) -> void:
	tape.stop()
	_stream.initial_clip = _slot[name]
	player.play()
	_clock.play()
	_wraps = 0
	_last_pos = 0.0
	_cur = name
	_cur_at = 0.0
	_cur_beat = 0.0
	_next = ""


## The phrase sounding now: the queued one once its bar line has passed (step() catches up next frame).
func _now() -> String:
	if _cur == "" or _next == "" or _time() < _cur_at + _len(_cur):
		return _cur
	return _next


func _len(name: String) -> float:
	return float(plan["phrases"][name]["bars"]) * _bar


## Track seconds since the track (re)started, from the clock's loop position and its wraps.
func _time() -> float:
	var pos := _clock.get_playback_position()
	if pos < _last_pos:
		_wraps += 1
	_last_pos = pos
	return _wraps * CLOCK_BARS * _bar + pos


func _player(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM # on the web, bus effects (the wall) need a stream
	add_child(p)
	return p
