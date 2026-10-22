extends Node2D
## The title screen (STORY.md 2) over the island: the grove at full settings, lit by LUXEL itself. It opens dark;
## the title's luxels light one by one, west to east, each with a quiet lantern note, and their light shows the
## grove, then spills over all of it; the subtitle, the prompt and the best record follow. Fireflies drift up and
## join the letters. Any key or a click emits `start` (in an itch.io embed that first click also unlocks web
## audio), and the dark eats the title east to west, a letter at a time with a snuff, as the intro's lights-out
## wave will eat the grove's lanterns. Once the prompt shows, Left/Right (A/D, Tab, G) or a click on its line flips
## GAMER MODE instead.

signal start

const N := preload("res://scripts/game/ui/narration.gd")
const SAVE := preload("res://scripts/game/save.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const LUX := preload("res://scripts/game/ui/luxels.gd")
const LIGHT_SHADER := preload("res://scripts/game/screens/title_light.gdshader")
const FRAMING := Vector2(260, 90) ## camera centre (view origin 100, 0): the Lantern Mother left of centre, the void band on top
const PULSE := 0.8 ## seconds per prompt colour (cream, stone)
const TITLE_Y := 6.0 ## the luxels' top, in the void band (y 0-40)
const SUB_Y := 36
const MAX_STEP := 0.1 ## s the title's clock moves in one frame at most: a boot hitch (shader compiles) doesn't skip its lead-in
const LIGHT_AT := 0.5 ## the first luxel lights
const LIGHT_GAP := 0.07 ## between luxels
const FLASH := 0.08 ## a luxel lights cream, then gold
const REACH := 70.0 ## px one luxel's light reaches, grown over REACH_GROW
const REACH_GROW := 0.9
const STRENGTH := 0.35
const SPILL_AFTER := 0.3 ## after the last luxel the light spills over the whole grove
const SPILL := 1.4
const TEXT_AFTER := 0.5 ## the subtitle, the prompt and the best fade in this long after the last luxel
const NOTES: Array[int] = [86, 81, 77, 74, 69] ## by font row: each column strums down the D minor chord
const NOTE_DOWN := 14.0 ## dB under the music
const FLY_FLIGHT := 1.8
const FLY_EVERY := Vector2(2.5, 4.5) ## seconds between fireflies, once the grove is lit
const FLY_FLASH := 0.2
const OUT_GAP := 0.09 ## the letters go out east to west, one snuff each
const OUT_SPREAD := 0.06 ## a letter's luxels go out east to west within this
const EMBER := 0.05 ## a lit luxel going out shows ember, then unlit, then nothing
const UNLIT_FOR := 0.12
const DARK_LIFT := 0.4 ## a press during the lighting lifts the dark over this
const FADE_OUT := 0.6 ## all gone by then (the intro's letterbox slides in over the top)
const GAMER_Y := 148 ## the GAMER MODE toggle's top; its note GAMER_GAP under it while on
const GAMER_GAP := 8
const GAMER_KEYS: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_TAB, KEY_G]

static var _audio_ok := not OS.has_feature("web") ## web audio starts with the first input

var run ## run.gd (island, fx, view and hud through it)
var _best := ""
var _open := false
var _t := 0.0
var _closing := -1.0 ## seconds into the close; < 0 = not closing
var _close_dark := 0.0 ## the dark at the press
var _close_t := 0.0 ## _t at the press
var _origin := Vector2.ZERO
var _cells: Array[Dictionary] = []
var _lit_at := PackedFloat32Array()
var _out_at := PackedFloat32Array() ## closing time each luxel goes out
var _flash_to := PackedFloat32Array() ## a firefly's flash
var _next_note := 0
var _flies: Array[Dictionary] = [] ## {"from", "i", "t0", "bow"}
var _next_fly := 0.0
var _light: Node2D
var _mat: ShaderMaterial
var _lights := PackedVector4Array()
var _sent_lights := PackedVector4Array() ## what the material holds (see _sync_light)
var _sent_dark := -1.0
var _sent_rect := Rect2()


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = LIGHT_SHADER
	_mat.set_shader_parameter("void_col", N.PAL["void"])
	_mat.set_shader_parameter("halo_in", N.PAL["wine"])
	_mat.set_shader_parameter("halo_out", N.PAL["plum"])
	_light = Node2D.new()
	_light.show_behind_parent = true
	_light.material = _mat
	_light.draw.connect(func() -> void: _light.draw_rect(Display.screen_rect(), Color.WHITE))
	add_child(_light)


## Keeps the run (view, fx and island through it).
func setup(r: Node2D) -> void:
	run = r
	visible = false


## Shows the title with the best record (ARCHITECTURE.md's show(best): `show` is CanvasItem's). Puts the island
## back at full settings, frames the grove, starts the title cue and lights LUXEL from the dark.
func open(best: Dictionary) -> void:
	_best = STORY.best_line(best, SAVE.gamer)
	_open = true
	_t = 0.0
	_closing = -1.0
	var label := STORY.line("title.name")
	_origin = LUX.origin(label, 160, TITLE_Y)
	_cells = LUX.cells(label, _origin)
	var n := _cells.size()
	_lit_at.resize(n)
	_out_at.resize(n)
	_flash_to.resize(n)
	_flash_to.fill(0.0)
	for i in n:
		_lit_at[i] = LIGHT_AT + LIGHT_GAP * i
	_next_note = 0
	_flies.clear()
	_next_fly = _all_lit() + SPILL_AFTER + SPILL + 1.0
	visible = true
	if run != null:
		run.hud.set_shown(false)
		run.fx.restore()
		run.island.apply({})
		run.view.pan_to(FRAMING, 0.0)
		run.fx.title(true)
	_sync_light()


## Hides the title (ARCHITECTURE.md's hide()): the dark eats it in 0.6 s.
func close() -> void:
	if not visible or _closing >= 0.0:
		return
	_open = false
	_close_dark = _dark()
	_close_t = _t
	_closing = 0.0
	_flies.clear()
	var last_letter := 0
	for c in _cells:
		last_letter = maxi(last_letter, c["letter"])
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var letter_east := -INF
		var letter_west := INF
		for o in _cells:
			if o["letter"] == c["letter"]:
				letter_east = maxf(letter_east, o["p"].x)
				letter_west = minf(letter_west, o["p"].x)
		var across: float = 0.0 if letter_east <= letter_west else (letter_east - c["p"].x) / (letter_east - letter_west)
		_out_at[i] = OUT_GAP * (last_letter - c["letter"]) + OUT_SPREAD * across
	for letter in last_letter + 1:
		get_tree().create_timer(OUT_GAP * (last_letter - letter)).timeout.connect(_snuff)


## True while the title takes input.
func is_open() -> bool:
	return _open


## A key press or a click that counts as "any key" (F11 and Alt+Enter belong to the Display autoload).
static func any_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and not key.alt_pressed and key.keycode != KEY_F11
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not any_press(event):
		return
	_audio_ok = true
	get_viewport().set_input_as_handled()
	if _text_in() > 0.0 and _toggles(event):
		_toggle_gamer()
		return
	close()
	start.emit()


## A GAMER MODE key, or a click on its line.
func _toggles(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.keycode in GAMER_KEYS
	var w := PixelFont.width(STORY.line("title.gamer_off"))
	return Rect2(160 - w / 2.0 - 12, GAMER_Y - 4, w + 24, 13).has_point(get_local_mouse_position())


func _toggle_gamer() -> void:
	SAVE.set_gamer(not SAVE.gamer)
	_best = STORY.best_line(SAVE.load_best(), SAVE.gamer)
	_note(NOTES[NOTES.size() - 1] if SAVE.gamer else NOTES[0], NOTE_DOWN)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += minf(delta, MAX_STEP)
	if _closing >= 0.0:
		_closing += delta
		if _closing >= FADE_OUT:
			visible = false
			_closing = -1.0
			return
	else:
		_play_notes()
		_step_flies()
	_sync_light()
	queue_redraw()


# ---- the light ---------------------------------------------------------------------------------------------

func _all_lit() -> float:
	return LIGHT_AT + LIGHT_GAP * maxf(_cells.size() - 1, 0.0)


## How dark the grove is outside the luxels' light: all dark until the last luxel, then the light spills.
func _dark() -> float:
	if _closing >= 0.0:
		return _close_dark * clampf(1.0 - _closing / DARK_LIFT, 0.0, 1.0)
	var u := clampf((_t - _all_lit() - SPILL_AFTER) / SPILL, 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)


func _sync_light() -> void:
	_lights.resize(_cells.size())
	for i in _cells.size():
		var on := _t >= _lit_at[i] and _state(i) >= LUX.EMBER
		var grow := clampf((_t - _lit_at[i]) / REACH_GROW, 0.0, 1.0)
		var c: Vector2 = _cells[i]["c"]
		_lights[i] = Vector4(c.x, c.y, REACH * (1.0 - (1.0 - grow) * (1.0 - grow)), STRENGTH if on else 0.0)
	if _lights != _sent_lights: # the material is only touched when a luxel's light moves
		_sent_lights = _lights.duplicate()
		var padded := _lights.duplicate()
		padded.resize(64)
		_mat.set_shader_parameter("lights", padded)
		_mat.set_shader_parameter("light_count", mini(_lights.size(), 64))
	var dark := _dark()
	if dark != _sent_dark:
		_sent_dark = dark
		_mat.set_shader_parameter("dark", dark)
	var rect := Display.screen_rect()
	if rect != _sent_rect: # the light quad covers the screen: it redraws when the screen resizes
		_sent_rect = rect
		_light.queue_redraw()


## Luxel `i` now.
func _state(i: int) -> int:
	var was_lit := _t >= _lit_at[i] if _closing < 0.0 else _close_t >= _lit_at[i]
	if _closing >= 0.0 and _closing >= _out_at[i]:
		var k := _closing - _out_at[i]
		if was_lit and k < EMBER:
			return LUX.EMBER
		return LUX.UNLIT if k < EMBER + UNLIT_FOR else LUX.HIDDEN
	if not was_lit:
		return LUX.UNLIT
	if _t < _lit_at[i] + FLASH or _t < _flash_to[i]:
		return LUX.FLASH
	return LUX.flicker(i, _t)


# ---- sound -------------------------------------------------------------------------------------------------

func _play_notes() -> void:
	while _next_note < _cells.size() and _t >= _lit_at[_next_note]:
		var row := int((_cells[_next_note]["p"].y - _origin.y) / LUX.SCALE)
		_note(NOTES[clampi(row, 0, NOTES.size() - 1)], NOTE_DOWN)
		_next_note += 1


func _note(midi: int, down: float) -> void:
	if _audio_ok and run != null:
		run.fx.title_note(midi, down)


func _snuff() -> void:
	if run != null:
		run.fx.play("snuff", 0.15)


# ---- fireflies ---------------------------------------------------------------------------------------------

## Now and then a firefly rises out of the grove and joins a luxel, which flashes.
func _step_flies() -> void:
	if _cells.is_empty():
		return
	if _t >= _next_fly:
		var bow := 1.0 if randf() < 0.5 else -1.0
		_flies.append({"from": Vector2(randf_range(30, 290), randf_range(110, 160)), "i": randi() % _cells.size(),
			"t0": _t, "bow": bow})
		_next_fly = _t + randf_range(FLY_EVERY.x, FLY_EVERY.y)
	for f in _flies.duplicate():
		if _t - float(f["t0"]) >= FLY_FLIGHT:
			_flash_to[f["i"]] = _t + FLY_FLASH
			_note(NOTES[0], NOTE_DOWN + 4.0)
			_flies.erase(f)


func _fly_at(f: Dictionary, t: float) -> Vector2:
	var p0: Vector2 = f["from"]
	var p2: Vector2 = _cells[f["i"]]["c"]
	var span := p2 - p0
	var p1 := (p0 + p2) / 2.0 + Vector2(-span.y, span.x).normalized() * 0.25 * span.length() * float(f["bow"])
	var u := clampf((t - float(f["t0"])) / FLY_FLIGHT, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	return p0.lerp(p1, e).lerp(p1.lerp(p2, e), e)


# ---- drawing -----------------------------------------------------------------------------------------------

func _draw() -> void:
	for i in _cells.size():
		LUX.draw(self, _cells[i]["p"], _state(i))
	for f in _flies:
		for back in [2, 1]:
			draw_rect(Rect2(_fly_at(f, _t - 0.06 * back).round(), Vector2.ONE), N.PAL["jade" if back == 2 else "lime"])
		var p := _fly_at(f, _t).round()
		for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_rect(Rect2(p + o, Vector2.ONE), N.PAL["lime"])
		draw_rect(Rect2(p, Vector2.ONE), N.PAL["cream"])
	var p := _text_in()
	if _closing >= 0.0:
		p = minf(p, 1.0 - _closing / FADE_OUT)
	N.centred(self, STORY.line("title.sub"), 160, SUB_Y, N.ramp("lime", p))
	var gamer := STORY.line("title.gamer_on" if SAVE.gamer else "title.gamer_off")
	var col := N.ramp("coral" if SAVE.gamer else "stone", p)
	var half := PixelFont.width(gamer) / 2.0
	N.centred(self, gamer, 160, GAMER_Y, col)
	_arrow(roundf(160 - half) - 7, GAMER_Y, -1, col)
	_arrow(roundf(160 + half) + 4, GAMER_Y, 1, col)
	if SAVE.gamer:
		N.centred(self, STORY.line("title.gamer_note"), 160, GAMER_Y + GAMER_GAP, N.ramp("stone", p))
	var pulse := "cream" if fmod(_t, PULSE * 2.0) < PULSE else "stone"
	N.centred(self, STORY.line("title.prompt"), 160, 166, N.ramp(pulse, p))
	if _best != "":
		N.right(self, _best, 316, 172, N.ramp("mauve", p))


## How far the subtitle, the prompt, the toggle and the best have faded in, 0..1.
func _text_in() -> float:
	return clampf((_t - _all_lit() - TEXT_AFTER) / 0.3, 0.0, 1.0)


## A 3x5 arrow (the font has no "<" or ">") with its left column at x, pointing `dir` (-1 left, 1 right), outlined.
func _arrow(x: float, y: float, dir: int, colour: Color) -> void:
	if colour.a == 0.0:
		return
	for o: Vector2 in PixelFont.OUTLINE:
		_arrow_cols(Vector2(x, y) + o, dir, N.NIGHT)
	_arrow_cols(Vector2(x, y), dir, colour)


func _arrow_cols(at: Vector2, dir: int, colour: Color) -> void:
	for c in 3:
		draw_rect(Rect2(at + Vector2(c if dir > 0 else 2 - c, c), Vector2(1, 5 - 2 * c)), colour)
