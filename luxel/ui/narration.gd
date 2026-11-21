class_name LxNarration
extends Node2D
## 16 px void letterbox bars, bottom narration lines with palette-stepped fades,
## and one-line key-glyph prompts (SWARM_SPEC 2.5, 3.4, STORY.md 0).

const BAR_HEIGHT: float = 16.0
const FADE_SECS: float = 0.3
const VIEW_RECT := Rect2(0.0, 0.0, 320.0, 180.0)

var _bar: float = 0.0
var _bar_from: float = 0.0
var _bar_to: float = 0.0
var _bar_t: float = 0.0
var _bar_dur: float = 0.4

var _slots: Dictionary = {} # slot_name -> {lines, colour, y, scale, t, secs}
var _prompt_text: String = ""
var _prompt_t: float = 0.0
var _prompt_dur: float = 0.0
var _bound: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bind_events()


func bind_events() -> void:
	if _bound or Lx.events == null:
		return
	_bound = true
	if not Lx.events.narration_requested.is_connected(_on_narration_requested):
		Lx.events.narration_requested.connect(_on_narration_requested)
	if not Lx.events.prompt_requested.is_connected(_on_prompt_requested):
		Lx.events.prompt_requested.connect(_on_prompt_requested)


func set_letterbox(on: bool, secs: float = 0.4) -> void:
	_bar_from = _bar
	_bar_to = 1.0 if on else 0.0
	_bar_t = 0.0
	_bar_dur = maxf(secs, 0.0)
	if _bar_dur <= 0.0:
		_bar = _bar_to
	queue_redraw()


func is_letterbox_on() -> bool:
	return _bar_to > 0.5


func say_id(
	string_id: String,
	style: String = "cream",
	secs: float = 3.5,
	y: float = -1.0,
	scale: int = 1,
	slot: String = "main"
) -> void:
	var line: String = LxStrings.text(string_id)
	say_lines(PackedStringArray([line]), style, secs, y, scale, slot)


func say_lines(
	lines: PackedStringArray,
	style: String = "cream",
	secs: float = 3.5,
	y: float = -1.0,
	scale: int = 1,
	slot: String = "main"
) -> void:
	var col: String = style if LxPalette.is_valid_color(style) else "cream"
	_slots[slot] = {
		"lines": lines,
		"colour": col,
		"y": y,
		"scale": clampi(scale, 1, 5),
		"t": 0.0,
		"secs": maxf(secs, FADE_SECS * 2.0 + 0.1),
	}
	queue_redraw()


func show_prompt(string_id: String, action_id: String = "", secs: float = 4.0) -> void:
	if string_id.is_empty():
		clear_prompt()
		return
	if action_id.is_empty():
		_prompt_text = LxStrings.text(string_id)
	else:
		var glyph: String = "-"
		if Lx.input != null:
			glyph = LxStrings.sanitize(Lx.input.get_glyph(action_id), 12)
		var raw: String = LxStrings.text(string_id)
		if raw.find("%s") >= 0:
			_prompt_text = LxStrings.fmt(string_id, [glyph])
		else:
			_prompt_text = LxStrings.fmt("HUD_KEY_PROMPT_FMT", [glyph, raw])
	_prompt_t = 0.0
	_prompt_dur = maxf(secs, FADE_SECS * 2.0 + 0.2)
	queue_redraw()


func clear_prompt() -> void:
	_prompt_text = ""
	_prompt_t = 0.0
	_prompt_dur = 0.0
	queue_redraw()


func is_saying(slot: String = "main") -> bool:
	return _slots.has(slot)


func unsay(slot: String = "main") -> void:
	_slots.erase(slot)
	queue_redraw()


func clear_all() -> void:
	_slots.clear()
	clear_prompt()
	queue_redraw()


func _on_narration_requested(string_id: String, style: String, duration: float) -> void:
	say_id(string_id, style, duration)


func _on_prompt_requested(string_id: String, action_id: String, duration: float) -> void:
	show_prompt(string_id, action_id, duration)


func _process(delta: float) -> void:
	var dirty: bool = false
	if _bar != _bar_to:
		_bar_t += delta
		_bar = lerpf(_bar_from, _bar_to, clampf(_bar_t / _bar_dur, 0.0, 1.0)) if _bar_dur > 0.0 else _bar_to
		dirty = true
	if not _slots.is_empty():
		for key: Variant in _slots.keys():
			var slot_name: String = str(key)
			var entry: Dictionary = _slots[slot_name] as Dictionary
			entry["t"] = float(entry["t"]) + delta
			if float(entry["t"]) >= float(entry["secs"]):
				_slots.erase(slot_name)
			dirty = true
	if not _prompt_text.is_empty():
		_prompt_t += delta
		if _prompt_t >= _prompt_dur:
			_prompt_text = ""
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var sr: Rect2 = _screen_rect()
	if _bar > 0.0:
		var top_y: float = lerpf(sr.position.y, BAR_HEIGHT, _bar)
		var bot_y: float = lerpf(sr.end.y, 180.0 - BAR_HEIGHT, _bar)
		draw_rect(Rect2(sr.position.x, sr.position.y, sr.size.x, top_y - sr.position.y).abs(), LxPalette.PAL["void"])
		draw_rect(Rect2(sr.position.x, bot_y, sr.size.x, sr.end.y - bot_y).abs(), LxPalette.PAL["void"])

	for val: Variant in _slots.values():
		_draw_slot(val as Dictionary)

	if not _prompt_text.is_empty():
		_draw_prompt()


func _draw_slot(s: Dictionary) -> void:
	var t: float = float(s["t"])
	var secs: float = float(s["secs"])
	var p: float = minf(t, secs - t) / FADE_SECS
	var col: Color = LxPalette.fade_step(p, str(s["colour"]))
	if col.a <= 0.0:
		return
	var lines: PackedStringArray = s["lines"] as PackedStringArray
	var sc: int = int(s["scale"])
	var y: float = float(s["y"])
	var gap: float = 7.0 * float(sc)
	if y < 0.0:
		if is_letterbox_on():
			y = 166.0 if lines.size() == 1 else 165.0
		else:
			y = 152.0 - gap * float(lines.size() - 1)
	for i: int in range(lines.size()):
		LxPixelFont.draw_centered(self, lines[i], 160.0, y + gap * float(i), col, sc)


func _draw_prompt() -> void:
	var p: float = minf(_prompt_t, _prompt_dur - _prompt_t) / FADE_SECS
	var col: Color = LxPalette.fade_step(p, "cream")
	if col.a <= 0.0:
		return
	var tw: float = float(LxPixelFont.width(_prompt_text, 1))
	var box_w: float = tw + 12.0
	var box_h: float = 11.0
	var y: float = 148.0 if is_letterbox_on() else 164.0
	var rect := Rect2(roundf(160.0 - box_w * 0.5), y, box_w, box_h)
	LxPixelFont.draw_panel(self, rect, "dusk", "mauve", "night")
	LxPixelFont.draw_centered(self, _prompt_text, 160.0, y + 3.0, col, 1)


func _screen_rect() -> Rect2:
	var disp: Node = get_node_or_null("/root/Display")
	if disp != null and disp.has_method("screen_rect"):
		return disp.call("screen_rect") as Rect2
	return VIEW_RECT
