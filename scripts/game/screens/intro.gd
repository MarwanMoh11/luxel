extends Node2D
## The intro (STORY.md 3, 24.4 s): the grove's lights go out, the camera pans to the sundial, Wick drops in and
## relights the island, four narration lines; any key jumps to the hand-off. The intro draws its own Wick (on this
## layer, above the gnomon) until the hand-off; the run's Wick takes over at start_run(true).

signal finished

const N := preload("res://scripts/game/ui/narration.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const TITLE := preload("res://scripts/game/screens/title.gd")
const WICK := preload("res://scripts/cast/wick.gd")
const SHADE := preload("res://scripts/cast/shade.gdshader")
const CHIME := preload("res://audio/music/lantern_74.wav") ## D5
const PAL: Dictionary = N.PAL

const LENGTH := 24.4
const HAND_OFF := 24.0 ## letterbox out, HUD in, T1: `finished` fires here
const SKIP_LABEL_AT := 1.0
const TITLE_VIEW := Rect2(100, 0, 320, 180) ## the title framing (title.gd FRAMING)
const WAVE_AT := 2.6 ## first lantern out
const WAVE_GAP := 0.15
const POOLS_AT := 5.4 ## light pools and the ground glow
const MOTHER_AT := 5.8 ## the Lantern Mother and her chandelier, last; the music goes behind the wall
const LAST: Array[String] = ["orchard_lantern_mother", "orchard_chandelier"]
const PAN_AT := 7.0
const PAN_SECS := 5.5
const DROP_AT := 12.5
const FLARE_AT := 13.5
const RELIGHT_AT := 14.2 ## the motes reach the edges: the island relights, the wall lifts
const GLOW_AT := 21.6
const GLOW_SECS := 1.5
const MOTES := 18
const MOTE_FLIGHT := 0.45
const MOTE_STAGGER := 0.015

var run ## run.gd
var narration ## narration.gd
var wick: WICK
var _t := -1.0 ## seconds into the intro; < 0 = not playing
var _events: Array = [] ## [t, Callable], sorted by t
var _next := 0
var _armed := false ## ignores the key press that started the intro
var _wick_on := false
var _motes_t := -1.0
var _lit := {} ## Sprite2D -> its lit texture (only for the fallback without Island.set_lit)
var _shadow: Node2D
var _chime: AudioStreamPlayer


## Keeps the run and the narration node.
func setup(r: Node2D, narr: Node2D) -> void:
	run = r
	narration = narr
	visible = false
	wick = WICK.new()
	_shadow = Node2D.new()
	_shadow.show_behind_parent = true
	var shade := ShaderMaterial.new()
	shade.shader = SHADE
	_shadow.material = shade
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_chime = AudioStreamPlayer.new()
	_chime.stream = CHIME
	_chime.volume_db = -6.0
	add_child(_chime)


## Plays the intro from the top.
func play() -> void:
	_t = 0.0
	_next = 0
	_armed = false
	_wick_on = false
	_motes_t = -1.0
	visible = true
	wick.reset()
	run.hud.set_shown(false)
	run.view.pan_to(TITLE.FRAMING, 0.0) # main's run.idle() gave the camera back to the sundial
	narration.letterbox(true, 0.4)
	_build_events()


## Jumps to the hand-off state at once: camera at spawn, island lit, music out of the wall, `finished`.
func skip() -> void:
	if _t < 0.0:
		return
	narration.clear()
	_relight()
	run.view.pan_to(run.island.spawn, 0.0)
	_hand_off()
	_end()


## True while the intro plays.
func playing() -> bool:
	return _t >= 0.0


func _build_events() -> void:
	_events = []
	for id: String in STORY.INTRO:
		var beat: Dictionary = STORY.INTRO[id]
		_at(beat["t"], narration.say_id.bind(id, beat["colour"], beat["secs"]))
	var wave := _wave()
	var gap := minf(WAVE_GAP, (POOLS_AT - WAVE_AT) / maxf(wave.size(), 1.0))
	for i in wave.size():
		_at(WAVE_AT + gap * i, _snuff.bind(wave[i]))
	_at(POOLS_AT, _pools_out)
	_at(MOTHER_AT, _mother_out)
	_at(PAN_AT, func() -> void: run.view.pan_to(run.island.spawn, PAN_SECS))
	_at(DROP_AT, _drop)
	_at(FLARE_AT, _flare)
	_at(RELIGHT_AT, _relight)
	_at(GLOW_AT, _glow.bind(1))
	_at(GLOW_AT + GLOW_SECS, _glow.bind(0))
	_at(HAND_OFF, _hand_off)
	_at(LENGTH, _end)
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _at(t: float, f: Callable) -> void:
	_events.append([t, f])


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_armed = true
	_t += delta
	while _t >= 0.0 and _next < _events.size() and _t >= _events[_next][0]:
		_next += 1
		(_events[_next - 1][1] as Callable).call()
	if _wick_on:
		wick.step(delta, Vector2.ZERO)
	if _motes_t >= 0.0:
		_motes_t += delta
	queue_redraw()
	_shadow.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _t >= 0.0 and _armed and _t < HAND_OFF and TITLE.any_press(event):
		get_viewport().set_input_as_handled()
		skip()


# ---- beats --------------------------------------------------------------------------------------------------

## The lit props in the title view except the Lantern Mother and her chandelier, east to west.
func _wave() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var seen := TITLE_VIEW.grow_individual(16, 0, 16, 64) # props stand on their feet: tall ones reach up into view
	for s in _lit_props():
		if seen.has_point(s.position) and not LAST.has(String(s.name)):
			out.append(s)
	out.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.x > b.position.x)
	return out


func _lit_props() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if run.island.has_method("lit_props"):
		out.assign(run.island.lit_props())
		return out
	for layer: String in ["GroundProps", "Sort", "Over"]:
		var node: Node = run.island.get_node_or_null(layer)
		if node == null:
			continue
		for child: Node in node.get_children():
			if child is Sprite2D and child.has_meta("unlit"):
				out.append(child)
	return out


func _set_lit(s: Sprite2D, on: bool) -> void:
	if run.island.has_method("set_lit"):
		run.island.set_lit(s, on)
		return
	if not _lit.has(s):
		_lit[s] = s.texture
	s.texture = _lit[s] if on else s.get_meta("unlit")


func _snuff(s: Sprite2D) -> void:
	_set_lit(s, false)
	_sfx("snuff", 0.15)


## Every light on the island goes out (pools and the ground glow too), but the Lantern Mother holds 0.4 s more.
func _pools_out() -> void:
	var last: Array[Sprite2D] = []
	for id in LAST:
		var s := run.island.find_child(id, true, false) as Sprite2D
		if s != null:
			last.append(s)
			if not _lit.has(s):
				_lit[s] = s.texture
	run.island.apply({"brightness": 1})
	for s in last:
		_set_lit(s, true)


func _mother_out() -> void:
	for id in LAST:
		var s := run.island.find_child(id, true, false) as Sprite2D
		if s != null:
			_set_lit(s, false)
	_sfx("snuff", 0.05)
	run.fx.menu(true)


func _drop() -> void:
	_wick_on = true
	wick.reset()
	wick.play("spawn")
	_sfx("owl_wingbeat", 0.06)


func _flare() -> void:
	wick.cast()
	_motes_t = 0.0
	_sfx("sell", 0.0)


func _relight() -> void:
	run.island.apply({})
	_lit.clear()
	run.fx.menu(false)


func _glow(tier: int) -> void:
	wick.tier = tier
	if tier > 0:
		_chime.play()


func _hand_off() -> void:
	_wick_on = false
	_motes_t = -1.0
	narration.letterbox(false, 0.4)
	run.fx.title(false)
	finished.emit()


func _end() -> void:
	_t = -1.0
	_events = []
	visible = false


## A sound effect through the fx, if the fx knows it (snuff arrives with P3's audio).
func _sfx(id: String, jitter: float) -> void:
	var db: Dictionary = run.fx.get_script().get_script_constant_map().get("SFX_DB", {})
	if db.has(id):
		run.fx.play(id, jitter)


# ---- drawing ------------------------------------------------------------------------------------------------

## Wick's feet on the game screen.
func _feet() -> Vector2:
	return (get_viewport().canvas_transform * run.island.spawn).round()


func _draw() -> void:
	if _t < 0.0:
		return
	if _wick_on:
		wick.draw(self, _feet())
		_draw_motes()
	if _t >= SKIP_LABEL_AT and _t < HAND_OFF and narration.bars_on():
		N.right(self, STORY.line("intro.skip"), 316, 6, PAL["mauve"])


func _draw_shadow() -> void:
	if _t >= 0.0 and _wick_on:
		wick.draw_shadow(_shadow, _feet(), Color.WHITE)


## The sell stream played outward: 18 gold motes from the lantern glass to the screen edges.
func _draw_motes() -> void:
	if _motes_t < 0.0:
		return
	var from := _feet() + wick.emit()
	var sr := Display.screen_rect()
	var perimeter := 2.0 * (sr.size.x + sr.size.y)
	for j in MOTES:
		var to := sr.position + _border(perimeter * (j + 0.5) / MOTES, sr.size)
		var t := _motes_t - float((j * 7) % MOTES) * MOTE_STAGGER
		for back: int in [3, 2, 1, 0]:
			var p := (t - 0.03 * back) / MOTE_FLIGHT
			if p < 0.0 or p > 1.0:
				continue
			var at := from.lerp(to, 1.0 - pow(1.0 - p, 2.0))
			if back == 0:
				draw_rect(Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), PAL["gold"])
				draw_rect(Rect2(at.round() - Vector2.ONE, Vector2.ONE), PAL["cream"])
			else:
				draw_rect(Rect2(at.round(), Vector2.ONE), PAL["gold"] if back == 1 else PAL["apricot"])


## The point `d` px clockwise along the border of a `size` rectangle, from its top-left corner.
func _border(d: float, size: Vector2) -> Vector2:
	if d < size.x:
		return Vector2(d, 0)
	d -= size.x
	if d < size.y:
		return Vector2(size.x - 1, d)
	d -= size.y
	if d < size.x:
		return Vector2(size.x - d, size.y - 1)
	return Vector2(0, size.y - (d - size.x))
