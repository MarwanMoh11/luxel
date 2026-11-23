class_name LxNarration
extends Node2D
## 16 px void letterbox bars, bottom narration lines with palette-stepped fades,
## and one-line key-glyph prompts (SWARM_SPEC 2.5, 3.4, STORY.md 0).

const BAR_HEIGHT: float = 16.0
const FADE_SECS: float = 0.3
const VIEW_RECT := Rect2(0.0, 0.0, 320.0, 180.0)
const STYLE_COLORS: Dictionary = {
	"title": "gold",
	"warning": "coral",
	"ominous": "ice",
	"narration": "cream",
}

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
	if line.find("%s") >= 0:
		var glyph: String = LxStrings.sanitize(Lx.input.get_glyph("lx_interact"), 12) if Lx.input != null else "E"
		line = LxStrings.fmt(string_id, [glyph])
	say_lines(PackedStringArray([line]), style, secs, y, scale, slot)


func say_lines(
	lines: PackedStringArray,
	style: String = "cream",
	secs: float = 3.5,
	y: float = -1.0,
	scale: int = 1,
	slot: String = "main"
) -> void:
	var mapped: String = str(STYLE_COLORS.get(style, style))
	var col: String = mapped if LxPalette.is_valid_color(mapped) else "cream"
	_slots[slot] = {
		"lines": lines,
		"colour": col,
		"y": y,
		"scale": clampi(scale, 1, 5),
		"t": 0.0,
		"secs": maxf(secs, FADE_SECS * 2.0 + 0.1),
		"slot": slot,
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
	var slot_name: String = "title" if (style == "title" or style == "warning") else "main"
	say_id(string_id, style, duration, -1.0, 1, slot_name)


func _on_prompt_requested(string_id: String, action_id: String, duration: float) -> void:
	show_prompt(string_id, action_id, duration)


func _process(delta: float) -> void:
	var dirty: bool = false
	if _bar != _bar_to:
		_bar_t += delta
		_bar = lerpf(_bar_from, _bar_to, clampf(_bar_t / _bar_dur, 0.0, 1.0)) if _bar_dur > 0.0 else _bar_to
		dirty = true
	var modal_paused: bool = (
		not is_letterbox_on()
		and Lx.ui != null
		and Lx.ui.has_method("is_modal_open")
		and bool(Lx.ui.call("is_modal_open"))
	)
	if not modal_paused:
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

	if not is_letterbox_on() and Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		return

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
	var slot_name: String = str(s.get("slot", "main"))
	var gap: float = 7.0 * float(sc)
	if y < 0.0:
		if is_letterbox_on():
			y = 166.0 if lines.size() == 1 else 165.0
		else:
			var base_y: float = 136.0 if _unlocked_move_count() >= 4 else 150.0
			if slot_name == "title":
				base_y -= 13.0 if _slots.has("main") else 2.0
			y = base_y - gap * float(lines.size() - 1)
	var no_motion: bool = LxHudFx.flash_reduced()
	if not is_letterbox_on() and not no_motion and t < 0.22:
		var ep: float = 1.0 - clampf(t / 0.22, 0.0, 1.0)
		y += roundf(2.0 * ep * ep)
	if not is_letterbox_on() and not lines.is_empty():
		var max_w: float = 0.0
		for ln: String in lines:
			max_w = maxf(max_w, float(LxPixelFont.width(ln, sc)))
		var is_title: bool = slot_name == "title"
		var isl: int = Lx.state.island_id if Lx.state != null else 1
		var pad_x: float = 13.0 if is_title else 6.0
		var box_h: float = gap * float(lines.size()) + 3.0
		var col_key: String = str(s.get("colour", "cream"))
		var border_k: String = "coral" if col_key == "coral" else (LxBiomePalette.key(isl, "border") if is_title else "dusk")
		var rect := Rect2(roundf(160.0 - max_w * 0.5 - pad_x), roundf(y - 2.0), roundf(max_w + pad_x * 2.0), roundf(box_h))
		LxPixelFont.draw_panel(self, rect, "night", border_k, "void")
		if is_title:
			var fin_c: Color = LxPalette.PAL["coral"] if col_key == "coral" else LxBiomePalette.col(isl, "glow")
			var hi_c: Color = LxPalette.PAL["cream"] as Color
			var cy_t: float = roundf(rect.position.y + rect.size.y * 0.5)
			LxHudFx.draw_biome_crest(self, isl, Vector2(rect.position.x + 6.0, cy_t), fin_c, hi_c)
			LxHudFx.draw_biome_crest(self, isl, Vector2(rect.end.x - 7.0, cy_t), fin_c, hi_c)
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
	var lift_prompt: bool = is_letterbox_on() or _unlocked_move_count() >= 4
	var y: float = 148.0 if lift_prompt else 164.0
	var no_motion: bool = LxHudFx.flash_reduced()
	if not no_motion and _prompt_t < 0.20:
		var pp: float = 1.0 - clampf(_prompt_t / 0.20, 0.0, 1.0)
		y += roundf(2.0 * pp * pp)
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var rect := Rect2(roundf(160.0 - box_w * 0.5), y, box_w, box_h)
	LxPixelFont.draw_panel(self, rect, "dusk", LxBiomePalette.key(isl, "border"), "night")
	var pin_c: Color = LxPalette.fade_step(p, LxBiomePalette.key(isl, "hi"))
	for cp: Vector2 in [
		Vector2(rect.position.x + 1.0, rect.position.y + 1.0), Vector2(rect.end.x - 2.0, rect.position.y + 1.0),
		Vector2(rect.position.x + 1.0, rect.end.y - 2.0), Vector2(rect.end.x - 2.0, rect.end.y - 2.0),
	]:
		draw_rect(Rect2(cp, Vector2.ONE), pin_c)
	LxPixelFont.draw_centered(self, _prompt_text, 160.0, y + 3.0, col, 1)


func _unlocked_move_count() -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	for v: Variant in Lx.state.unlocked_moves.values():
		if bool(v):
			count += 1
	return count


func _screen_rect() -> Rect2:
	var disp: Node = get_node_or_null("/root/Display")
	if disp != null and disp.has_method("screen_rect"):
		return disp.call("screen_rect") as Rect2
	return VIEW_RECT
