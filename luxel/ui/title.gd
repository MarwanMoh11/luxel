class_name LxTitleScreen
extends Node2D
## Title screen with west-to-east LUXEL luxel wordmark, 3-slot save selector,
## delete confirmation, Options, and Quit.

signal slot_selected(slot_num: int, is_new_game: bool)
signal options_requested()
signal quit_requested()

enum Mode { MAIN, SLOTS, CONFIRM_DELETE }

const MAIN_ITEMS: Array[String] = ["TITLE_PLAY", "TITLE_OPTIONS", "TITLE_QUIT"]
const SLOT_COUNT: int = 3

var mode: int = Mode.MAIN
var _elapsed: float = 0.0
var _main_idx: int = 0
var _slot_idx: int = 0
var _confirm_idx: int = 1 # 0 = YES, 1 = NO (safe default)
var _summaries: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _fireflies: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop()
	refresh_slots()


func open(show_slots: bool = false) -> void:
	visible = true
	mode = Mode.SLOTS if show_slots else Mode.MAIN
	_elapsed = 0.0
	_confirm_idx = 1
	refresh_slots()
	queue_redraw()


func close() -> void:
	visible = false


func refresh_slots() -> void:
	_summaries.clear()
	for i: int in range(1, SLOT_COUNT + 1):
		if Lx.save != null:
			_summaries.append(Lx.save.slot_summary(i))
		else:
			_summaries.append({"empty": true, "slot": i})
	queue_redraw()


func select_slot(slot_num: int) -> void:
	var idx: int = clampi(slot_num - 1, 0, SLOT_COUNT - 1)
	if idx >= _summaries.size():
		refresh_slots()
	var is_new: bool = bool(_summaries[idx].get("empty", true))
	_play_ui_sfx("ui_confirm")
	slot_selected.emit(idx + 1, is_new)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	for ff: Dictionary in _fireflies:
		ff["y"] = float(ff["y"]) - float(ff["spd"]) * delta
		if float(ff["y"]) < -4.0:
			ff["y"] = 184.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_handle_mouse_hover((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_mouse_click(mb.position):
				get_viewport().set_input_as_handled()
		return

	if mode == Mode.MAIN:
		_input_main(event)
	elif mode == Mode.SLOTS:
		_input_slots(event)
	elif mode == Mode.CONFIRM_DELETE:
		_input_confirm(event)


func _input_main(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_main_idx = (_main_idx - 1 + MAIN_ITEMS.size()) % MAIN_ITEMS.size()
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_main_idx = (_main_idx + 1) % MAIN_ITEMS.size()
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate_main(_main_idx)
		get_viewport().set_input_as_handled()


func _activate_main(idx: int) -> void:
	_play_ui_sfx("ui_confirm")
	match idx:
		0:
			refresh_slots()
			mode = Mode.SLOTS
		1:
			options_requested.emit()
		2:
			quit_requested.emit()
	queue_redraw()


func _input_slots(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_slot_idx = (_slot_idx - 1 + SLOT_COUNT) % SLOT_COUNT
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_slot_idx = (_slot_idx + 1) % SLOT_COUNT
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		select_slot(_slot_idx + 1)
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_DELETE) or _key_just(event, KEY_BACKSPACE) or _joy_just(event, JOY_BUTTON_X):
		if _slot_idx < _summaries.size() and not bool(_summaries[_slot_idx].get("empty", true)):
			mode = Mode.CONFIRM_DELETE
			_confirm_idx = 1
			_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		mode = Mode.MAIN
		_play_ui_sfx("ui_back")
		get_viewport().set_input_as_handled()


func _input_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_left") or event.is_action_pressed("lx_move_right") or _key_just(event, KEY_LEFT) or _key_just(event, KEY_RIGHT):
		_confirm_idx = 1 - _confirm_idx
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		if _confirm_idx == 0 and Lx.save != null:
			Lx.save.delete_slot(_slot_idx + 1)
			refresh_slots()
			_play_ui_sfx("ui_confirm")
		else:
			_play_ui_sfx("ui_back")
		mode = Mode.SLOTS
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		mode = Mode.SLOTS
		_play_ui_sfx("ui_back")
		get_viewport().set_input_as_handled()


func _handle_mouse_hover(pos: Vector2) -> void:
	if mode == Mode.MAIN:
		for i: int in range(MAIN_ITEMS.size()):
			if _main_btn_rect(i).has_point(pos):
				_main_idx = i
				return
	elif mode == Mode.SLOTS:
		for i: int in range(SLOT_COUNT):
			if _slot_rect(i).has_point(pos):
				_slot_idx = i
				return


func _handle_mouse_click(pos: Vector2) -> bool:
	if mode == Mode.MAIN:
		for i: int in range(MAIN_ITEMS.size()):
			if _main_btn_rect(i).has_point(pos):
				_main_idx = i
				_activate_main(i)
				return true
	elif mode == Mode.SLOTS:
		for i: int in range(SLOT_COUNT):
			var del_r: Rect2 = _slot_del_rect(i)
			if i < _summaries.size() and not bool(_summaries[i].get("empty", true)) and del_r.has_point(pos):
				_slot_idx = i
				mode = Mode.CONFIRM_DELETE
				_confirm_idx = 1
				return true
			if _slot_rect(i).has_point(pos):
				_slot_idx = i
				select_slot(i + 1)
				return true
	elif mode == Mode.CONFIRM_DELETE:
		if _confirm_btn_rect(0).has_point(pos):
			if Lx.save != null:
				Lx.save.delete_slot(_slot_idx + 1)
				refresh_slots()
			mode = Mode.SLOTS
			return true
		if _confirm_btn_rect(1).has_point(pos):
			mode = Mode.SLOTS
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	_draw_backdrop()

	if mode == Mode.MAIN:
		_draw_main()
	else:
		_draw_slots()
		if mode == Mode.CONFIRM_DELETE:
			_draw_confirm_delete()


func _draw_backdrop() -> void:
	# Distant silhouetted archipelago horizon band.
	draw_rect(Rect2(0.0, 146.0, 320.0, 34.0), LxPalette.PAL["night"])
	draw_rect(Rect2(26.0, 138.0, 64.0, 10.0), LxPalette.PAL["night"])
	draw_rect(Rect2(214.0, 134.0, 82.0, 14.0), LxPalette.PAL["night"])
	draw_rect(Rect2(126.0, 141.0, 56.0, 7.0), LxPalette.PAL["dusk"])
	for st: Dictionary in _stars:
		var phase: float = fmod(_elapsed + float(st["off"]), float(st["per"]))
		var col_name: String = str(st["hi"]) if phase < 0.4 else str(st["lo"])
		draw_rect(Rect2(float(st["x"]), float(st["y"]), 1.0, 1.0), LxPalette.color(col_name))
	for ff: Dictionary in _fireflies:
		var fx: float = roundf(float(ff["x"]) + sin(_elapsed * 1.4 + float(ff["off"])) * 5.0)
		var fy: float = roundf(float(ff["y"]))
		var col_name: String = "gold" if fmod(_elapsed + float(ff["off"]), 1.2) < 0.6 else "apricot"
		draw_rect(Rect2(fx, fy, 2.0, 2.0), LxPalette.color(col_name))


func _draw_main() -> void:
	var word: String = LxStrings.text("TITLE_WORDMARK")
	LxLuxels.draw_wordmark(self, word, 160.0, 20.0, _elapsed)

	var sub_p: float = clampf((_elapsed - LxLuxels.intro_duration(word)) / 0.4, 0.0, 1.0)
	LxPixelFont.draw_faded(
		self,
		LxStrings.text("TITLE_SUBTITLE"),
		Vector2(160.0, 52.0),
		sub_p,
		"apricot",
		1,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	for i: int in range(MAIN_ITEMS.size()):
		var r: Rect2 = _main_btn_rect(i)
		var sel: bool = i == _main_idx
		LxPixelFont.draw_panel(self, r, "plum" if sel else "dusk", "gold" if sel else "mauve", "night")
		var ink: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
		LxPixelFont.draw_centered(self, LxStrings.text(MAIN_ITEMS[i]), r.get_center().x, r.position.y + 4.0, ink, 1)
		if sel:
			draw_rect(Rect2(r.position.x + 5.0, r.position.y + 5.0, 3.0, 3.0), LxPalette.PAL["cream"])

	var pulse_col: Color = LxPalette.PAL["cream"] if fmod(_elapsed, 1.6) < 0.8 else LxPalette.PAL["stone"]
	LxPixelFont.draw_centered(self, LxStrings.text("TITLE_PROMPT"), 160.0, 162.0, pulse_col, 1)


func _draw_slots() -> void:
	LxPixelFont.draw_centered(self, LxStrings.text("SLOT_SELECT_TITLE"), 160.0, 14.0, LxPalette.PAL["gold"], 2)
	for i: int in range(SLOT_COUNT):
		var r: Rect2 = _slot_rect(i)
		var sel: bool = i == _slot_idx
		var info: Dictionary = _summaries[i] if i < _summaries.size() else {"empty": true}
		var is_empty: bool = bool(info.get("empty", true))
		LxPixelFont.draw_panel(self, r, "plum" if sel else "dusk", "gold" if sel else "mauve", "night")

		var slot_lbl: String = LxStrings.fmt("SLOT_LABEL", [i + 1])
		LxPixelFont.draw_left(self, slot_lbl, r.position + Vector2(7.0, 5.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)

		if is_empty:
			LxPixelFont.draw_left(self, LxStrings.text("SLOT_EMPTY"), r.position + Vector2(7.0, 15.0), LxPalette.PAL["stone"], 1)
			LxPixelFont.draw_right(self, LxStrings.text("SLOT_NEW"), r.end.x - 8.0, r.position.y + 10.0, LxPalette.PAL["lime"] if sel else LxPalette.PAL["stone"], 1)
		else:
			var isl_id: int = int(info.get("island_id", 1))
			var isl_data: Dictionary = Lx.get_island_data(isl_id)
			var isl_name: String = LxStrings.sanitize(str(isl_data.get("name", "")), 20)
			var relit: int = int(info.get("relit_count", 0))
			var time_str: String = LxStrings.format_time(float(info.get("play_time_s", 0.0)))
			var meta: String = LxStrings.fmt("SLOT_META", [isl_name, relit, time_str])
			LxPixelFont.draw_left(self, meta, r.position + Vector2(7.0, 15.0), LxPalette.PAL["cream"], 1)
			LxPixelFont.draw_right(self, LxStrings.text("SLOT_CONTINUE"), r.end.x - 42.0, r.position.y + 5.0, LxPalette.PAL["gold"] if sel else LxPalette.PAL["stone"], 1)
			var del_r: Rect2 = _slot_del_rect(i)
			LxPixelFont.draw_panel(self, del_r, "wine" if sel else "night", "coral" if sel else "mauve", "void")
			LxPixelFont.draw_centered(self, LxStrings.text("SLOT_DELETE"), del_r.get_center().x, del_r.position.y + 3.0, LxPalette.PAL["cream"], 1)

	LxPixelFont.draw_centered(self, LxStrings.text("SLOT_HINT"), 160.0, 164.0, LxPalette.PAL["stone"], 1)


func _draw_confirm_delete() -> void:
	var box := Rect2(74.0, 62.0, 172.0, 56.0)
	LxPixelFont.draw_panel(self, box, "night", "coral", "void")
	var msg: String = LxStrings.fmt("SLOT_CONFIRM_DEL", [_slot_idx + 1])
	LxPixelFont.draw_centered(self, msg, 160.0, 72.0, LxPalette.PAL["coral"], 1)
	var labels: Array[String] = ["SLOT_YES", "SLOT_NO"]
	for i: int in range(2):
		var br: Rect2 = _confirm_btn_rect(i)
		var sel: bool = i == _confirm_idx
		var fill: String = "coral" if (sel and i == 0) else ("plum" if sel else "dusk")
		LxPixelFont.draw_panel(self, br, fill, "gold" if sel else "mauve", "void")
		LxPixelFont.draw_centered(self, LxStrings.text(labels[i]), br.get_center().x, br.position.y + 4.0, LxPalette.PAL["cream"], 1)


func _main_btn_rect(i: int) -> Rect2:
	return Rect2(106.0, 76.0 + float(i) * 20.0, 108.0, 15.0)


func _slot_rect(i: int) -> Rect2:
	return Rect2(26.0, 40.0 + float(i) * 38.0, 268.0, 30.0)


func _slot_del_rect(i: int) -> Rect2:
	var r: Rect2 = _slot_rect(i)
	return Rect2(r.end.x - 36.0, r.position.y + 9.0, 31.0, 12.0)


func _confirm_btn_rect(i: int) -> Rect2:
	return Rect2(86.0 + float(i) * 78.0, 92.0, 70.0, 15.0)


func _build_backdrop() -> void:
	_stars.clear()
	for i: int in range(36):
		var sx: float = float((i * 73 + 19) % 316 + 2)
		var sy: float = float((i * 41 + 7) % 130 + 2)
		_stars.append({
			"x": sx,
			"y": sy,
			"off": float(i) * 0.37,
			"per": 1.8 + float(i % 5) * 0.55,
			"hi": "ice" if i % 4 == 0 else "stone",
			"lo": "dusk" if i % 3 == 0 else "mauve",
		})
	_fireflies.clear()
	for i: int in range(8):
		_fireflies.append({
			"x": 24.0 + float(i) * 38.0,
			"y": float((i * 29) % 170),
			"spd": 6.0 + float(i % 3) * 3.0,
			"off": float(i) * 0.9,
		})


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _joy_just(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
