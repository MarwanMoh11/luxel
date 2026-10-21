extends Node2D
## Beat test: proves the Conductor is in sync before building the real game.
## Space/Enter = tap on the beat. Left/Right = change the latency offset by 10 ms.

@export var click_track: AudioStream
@export var click_bpm: float = 120.0

const PERFECT_WINDOW := 0.050 # seconds either side of the beat
const GOOD_WINDOW := 0.100
const OFFSET_STEP := 0.010
const HISTORY_SIZE := 16

const BG_COLOR := Color("1a1c2c")
const IDLE_COLOR := Color("333c57")
const BEAT_COLOR := Color("41a6f6")
const ACCENT_COLOR := Color("ffcd75")
const TEXT_COLOR := Color("f4f4f4")

var _square: ColorRect
var _info: Label
var _result: Label
var _flash_color := BEAT_COLOR
var _flash := 0.0
var _offsets: Array[float] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)

	_square = ColorRect.new()
	_square.size = Vector2(48, 48)
	_square.position = Vector2(136, 56)
	_square.color = IDLE_COLOR
	add_child(_square)

	_info = _make_label(Vector2(8, 6))
	_result = _make_label(Vector2(8, 120))
	_result.text = "Tap SPACE on the beat."

	Conductor.beat.connect(_on_beat)
	Conductor.play_song(click_track, click_bpm)
	_update_info()


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_square.color = IDLE_COLOR.lerp(_flash_color, _flash)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_judge_tap()
	elif event.is_action_pressed("ui_right"):
		_nudge_latency(OFFSET_STEP)
	elif event.is_action_pressed("ui_left"):
		_nudge_latency(-OFFSET_STEP)


func _on_beat(beat_number: int) -> void:
	var accent := beat_number % Conductor.beats_per_measure == 0
	_flash_color = ACCENT_COLOR if accent else BEAT_COLOR
	_flash = 1.0


func _judge_tap() -> void:
	var offset := Conductor.offset_from_nearest_beat()
	var ms := roundi(offset * 1000.0)
	var verdict := "MISS"
	if absf(offset) <= PERFECT_WINDOW:
		verdict = "PERFECT"
	elif absf(offset) <= GOOD_WINDOW:
		verdict = "GOOD"

	var direction := "late" if ms > 0 else "early"
	if ms == 0:
		direction = "dead on"

	_offsets.append(offset)
	if _offsets.size() > HISTORY_SIZE:
		_offsets.pop_front()

	var line := "%s  %d ms %s" % [verdict, absi(ms), direction]
	print(line)
	_result.text = "%s\nAverage of last %d taps: %+d ms" % [
		line, _offsets.size(), roundi(_average_offset() * 1000.0)]


func _nudge_latency(amount: float) -> void:
	Conductor.latency_offset += amount
	_offsets.clear()
	_update_info()


func _average_offset() -> float:
	if _offsets.is_empty():
		return 0.0
	var total := 0.0
	for value in _offsets:
		total += value
	return total / _offsets.size()


func _update_info() -> void:
	_info.text = "BPM %d   Latency offset %+d ms\nSPACE tap   LEFT/RIGHT offset\nAlways late? Press RIGHT until avg is near 0" % [
		roundi(Conductor.bpm), roundi(Conductor.latency_offset * 1000.0)]


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(label)
	return label
