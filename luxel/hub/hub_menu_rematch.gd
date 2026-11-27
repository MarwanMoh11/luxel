class_name LxHubMenuRematch
extends Node2D
## Rematch Mirror overlay: lists every defeated boss with best time, no-hit mark, medal,
## and time target, and warps Wick into that boss's own region for a rematch.

signal closed()
signal rematch_launched(boss_id: String)

const PANEL := Rect2(18.0, 10.0, 284.0, 160.0)
const VISIBLE_ROWS: int = 7

var _entries: Array[Dictionary] = [] # {id, meta, defeated, rec}
var _idx: int = 0
var _scroll: int = 0
var _clock: float = 0.0
var _msg_key: String = ""
var _msg_t: float = 0.0
var _hover_close: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_rebuild_entries()
	_idx = 0
	_scroll = 0
	_msg_key = ""
	_msg_t = 0.0
	_hover_close = false
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_hover_close = false


func get_entries() -> Array[Dictionary]:
	return _entries


func select_index(i: int) -> void:
	if _entries.is_empty():
		_idx = 0
		return
	_idx = clampi(i, 0, _entries.size() - 1)
	if _idx < _scroll:
		_scroll = _idx
	elif _idx >= _scroll + VISIBLE_ROWS:
		_scroll = _idx - VISIBLE_ROWS + 1
	queue_redraw()


func confirm_selected() -> bool:
	if _entries.is_empty() or _idx < 0 or _idx >= _entries.size():
		_flash_msg("HUB_REMATCH_NONE")
		return false
	var e: Dictionary = _entries[_idx]
	if not bool(e["defeated"]):
		_flash_msg("HUB_REMATCH_LOCKED")
		if Lx.audio != null:
			Lx.audio.play_sfx("denied", Vector2.ZERO, false, true)
		return false
	var bid: String = str(e["id"])
	if Lx.audio != null:
		Lx.audio.play_sfx("waystone_warp", Vector2.ZERO, false, true)
	closed.emit()
	var tracker: LxHubTracker = LxHubTracker.ensure()
	if tracker != null and tracker.start_rematch(bid):
		rematch_launched.emit(bid)
		return true
	return false


func _rebuild_entries() -> void:
	_entries.clear()
	if Lx.packs == null:
		return
	var defeated_rows: Array[Dictionary] = []
	var locked_rows: Array[Dictionary] = []
	for bid: String in Lx.packs.all_boss_ids():
		var meta: Dictionary = Lx.packs.boss_meta(bid)
		if meta.is_empty():
			continue
		var isl: int = int(meta.get("island", 1))
		var reg: String = str(meta.get("region", ""))
		if isl <= 0 or reg.is_empty():
			continue
		if not FileAccess.file_exists("res://luxel/islands/%d/%s.map" % [isl, reg]):
			continue
		var is_def: bool = _is_boss_defeated(bid, meta)
		var rec: Dictionary = LxHubState.get_rematch_record(bid)
		var row: Dictionary = {"id": bid, "meta": meta, "defeated": is_def, "rec": rec, "island": isl}
		if is_def:
			defeated_rows.append(row)
		else:
			locked_rows.append(row)
	var sort_fn := func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["island"]) != int(b["island"]):
			return int(a["island"]) < int(b["island"])
		return str(a["id"]) < str(b["id"])
	defeated_rows.sort_custom(sort_fn)
	locked_rows.sort_custom(sort_fn)
	_entries.append_array(defeated_rows)
	_entries.append_array(locked_rows)


static func _is_boss_defeated(bid: String, meta: Dictionary) -> bool:
	if Lx.state == null:
		return false
	if Lx.state.defeated_bosses.has(bid):
		return true
	var flag: String = str(meta.get("flag", ""))
	if not flag.is_empty() and bool(Lx.state.story_flags.get(flag, false)):
		return true
	if bid == "hollow_wick_boss" and Lx.state.defeated_bosses.has("hollow_wick"):
		return true
	return false


func _flash_msg(key: String) -> void:
	_msg_key = key
	_msg_t = 2.0
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		if _msg_t <= 0.0:
			_msg_key = ""
	queue_redraw()


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseMotion:
		var mp: Vector2 = (event as InputEventMouseMotion).position
		var hc: bool = _close_rect().has_point(mp)
		if hc != _hover_close:
			_hover_close = hc
			if hc:
				_play_ui("ui_move")
			queue_redraw()
		for ri: int in range(VISIBLE_ROWS):
			var ei: int = _scroll + ri
			if ei >= _entries.size():
				break
			if _row_rect(ri).has_point(mp):
				if ei != _idx:
					select_index(ei)
					_play_ui("ui_move")
				break
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_ui("menu_close"); closed.emit(); return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_index(_idx - 1); _play_ui("ui_move"); return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_index(_idx + 1); _play_ui("ui_move"); return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = mb.position
			if _close_rect().has_point(p):
				_play_ui("menu_close"); closed.emit(); return true
			for ri: int in range(VISIBLE_ROWS):
				var ei: int = _scroll + ri
				if ei >= _entries.size():
					break
				if _row_rect(ri).has_point(p):
					if _idx == ei:
						confirm_selected()
					else:
						select_index(ei); _play_ui("ui_move")
					return true
			return true
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_BACKSPACE:
			_play_ui("menu_close"); closed.emit(); return true
		if k == KEY_UP or k == KEY_W:
			select_index(_idx - 1); _play_ui("ui_move"); return true
		if k == KEY_DOWN or k == KEY_S:
			select_index(_idx + 1); _play_ui("ui_move"); return true
		if k == KEY_PAGEUP:
			select_index(_idx - VISIBLE_ROWS); _play_ui("ui_move"); return true
		if k == KEY_PAGEDOWN:
			select_index(_idx + VISIBLE_ROWS); _play_ui("ui_move"); return true
		if k == KEY_ENTER or k == KEY_SPACE or k == KEY_E:
			confirm_selected(); return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var jb: int = (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER:
			select_index(_idx - VISIBLE_ROWS); _play_ui("ui_move"); return true
		if jb == JOY_BUTTON_RIGHT_SHOULDER:
			select_index(_idx + VISIBLE_ROWS); _play_ui("ui_move"); return true
	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause"):
		_play_ui("menu_close"); closed.emit(); return true
	if event.is_action_pressed("lx_ui_accept"):
		confirm_selected(); return true
	if event.is_action_pressed("lx_move_up"):
		select_index(_idx - 1); _play_ui("ui_move"); return true
	if event.is_action_pressed("lx_move_down"):
		select_index(_idx + 1); _play_ui("ui_move"); return true
	return false


func _play_ui(sfx: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx, Vector2.ZERO, false, true)


func _close_rect() -> Rect2:
	return Rect2(PANEL.end.x - 18.0, PANEL.position.y + 4.0, 12.0, 12.0)


func _row_rect(ri: int) -> Rect2:
	return Rect2(PANEL.position.x + 8.0, PANEL.position.y + 30.0 + float(ri) * 15.0, PANEL.size.x - 22.0, 13.0)


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(PANEL.position + Vector2(2.0, 2.0), PANEL.size), LxPalette.PAL["void"])
	LxPixelFont.draw_panel(self, PANEL, "night", "ice", "void")
	draw_rect(Rect2(PANEL.position.x + 2.0, PANEL.position.y + 2.0, PANEL.size.x - 4.0, 16.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(PANEL.position.x + 2.0, PANEL.position.y + 18.0, PANEL.size.x - 4.0, 1.0), LxPalette.PAL["ice"])
	for rv: Vector2 in [
		Vector2(PANEL.position.x + 3.0, PANEL.position.y + 3.0),
		Vector2(PANEL.end.x - 5.0, PANEL.position.y + 3.0),
		Vector2(PANEL.position.x + 3.0, PANEL.end.y - 5.0),
		Vector2(PANEL.end.x - 5.0, PANEL.end.y - 5.0),
	]:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), LxPalette.PAL["apricot"])
		draw_rect(Rect2(rv, Vector2.ONE), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "crown", Vector2(PANEL.position.x + 7.0, PANEL.position.y + 5.0), 1.0)
	LxPixelFont.draw(self, LxStrings.text("HUB_REMATCH_TITLE"), Vector2(PANEL.position.x + 20.0, PANEL.position.y + 7.0), LxPalette.PAL["ice"], 1)

	# Close button
	var cr: Rect2 = _close_rect()
	LxPixelFont.draw_panel(self, cr, "coral" if _hover_close else "wine", "gold" if _hover_close else "mauve", "void")
	LxPixelFont.draw_centered(self, "X", cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["cream"], 1)

	# Summary counter
	var def_n: int = 0
	var nh_n: int = 0
	for e: Dictionary in _entries:
		if bool(e["defeated"]):
			def_n += 1
		if bool((e["rec"] as Dictionary).get("no_hit", false)):
			nh_n += 1
	var sum_s: String = LxStrings.fmt("HUB_REMATCH_COUNT", [def_n, _entries.size(), nh_n])
	LxPixelFont.draw(self, sum_s, Vector2(PANEL.position.x + 10.0, PANEL.position.y + 21.0), LxPalette.PAL["stone"], 1)

	# Boss rows
	for ri: int in range(VISIBLE_ROWS):
		var ei: int = _scroll + ri
		if ei >= _entries.size():
			break
		var e: Dictionary = _entries[ei]
		var r: Rect2 = _row_rect(ri)
		var sel: bool = ei == _idx
		var is_def: bool = bool(e["defeated"])
		LxPixelFont.draw_panel(self, r, "plum" if sel else "void", "gold" if sel else "dusk", "void")
		var meta: Dictionary = e["meta"] as Dictionary
		var rec: Dictionary = e["rec"] as Dictionary
		var isl: int = int(e["island"])
		var name_str: String = LxStrings.text(str(meta.get("name_key", ""))) if is_def else LxStrings.text("HUB_REMATCH_UNKNOWN")
		var label: String = "I%d %s" % [isl, name_str.substr(0, 22)]
		var col: Color = LxPalette.PAL["cream"] if is_def else LxPalette.PAL["mauve"]
		LxPixelFont.draw(self, label, Vector2(r.position.x + 5.0, r.position.y + 4.0), col, 1)
		if is_def:
			var best_s: float = float(rec.get("best_s", -1.0))
			var t_str: String = ("%04.1fS" % best_s) if best_s > 0.0 else "--.-S"
			LxPixelFont.draw_right(self, t_str, r.end.x - 30.0, r.position.y + 4.0, LxPalette.PAL["gold"] if best_s > 0.0 else LxPalette.PAL["stone"], 1)
			# Medal pip (void-backed with top specular pixel when earned)
			var med: int = int(rec.get("medal", 0))
			var mc: Color = LxPalette.PAL["gold"] if med >= 3 else (LxPalette.PAL["ice"] if med == 2 else (LxPalette.PAL["apricot"] if med == 1 else LxPalette.PAL["dusk"]))
			var mp_x: float = roundf(r.end.x - 24.0)
			var mp_y: float = roundf(r.position.y + 3.0)
			draw_rect(Rect2(mp_x, mp_y, 6.0, 7.0), LxPalette.PAL["void"])
			draw_rect(Rect2(mp_x + 1.0, mp_y + 1.0, 4.0, 5.0), mc)
			if med > 0:
				draw_rect(Rect2(mp_x + 1.0, mp_y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
			# No-hit pip
			if bool(rec.get("no_hit", false)):
				LxPixelFont.draw_right(self, LxStrings.text("HUB_NH_TAG"), r.end.x - 5.0, r.position.y + 4.0, LxPalette.PAL["lime"], 1)

	# Scrollbar when list exceeds visible rows
	if _entries.size() > VISIBLE_ROWS:
		var track := Rect2(PANEL.end.x - 10.0, PANEL.position.y + 30.0, 3.0, float(VISIBLE_ROWS - 1) * 15.0 + 13.0)
		draw_rect(track.grow(1.0), LxPalette.PAL["dusk"])
		draw_rect(track, LxPalette.PAL["void"])
		var thumb_h: float = maxf(10.0, roundf(track.size.y * float(VISIBLE_ROWS) / float(_entries.size())))
		var max_s: int = maxi(1, _entries.size() - VISIBLE_ROWS)
		var frac: float = clampf(float(_scroll) / float(max_s), 0.0, 1.0)
		var ty: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
		draw_rect(Rect2(track.position.x, ty, track.size.x, thumb_h), LxPalette.PAL["ice"])
		draw_rect(Rect2(track.position.x, ty, track.size.x, 1.0), LxPalette.PAL["cream"])

	# Footer hint / target times
	var fy: float = PANEL.end.y - 22.0
	draw_rect(Rect2(PANEL.position.x + 4.0, fy - 2.0, PANEL.size.x - 8.0, 1.0), LxPalette.PAL["dusk"])
	if not _msg_key.is_empty():
		LxPixelFont.draw_centered(self, LxStrings.text(_msg_key), PANEL.position.x + PANEL.size.x * 0.5, fy + 3.0, LxPalette.PAL["coral"], 1)
	elif not _entries.is_empty() and _idx < _entries.size():
		var cur: Dictionary = _entries[_idx]
		var tgt: Vector3 = LxHubState.boss_time_targets(cur["meta"] as Dictionary)
		var goal_s: String = LxStrings.fmt("HUB_REMATCH_GOALS", [int(tgt.x), int(tgt.y), int(tgt.z)])
		LxPixelFont.draw(self, goal_s, Vector2(PANEL.position.x + 10.0, fy + 2.0), LxPalette.PAL["gold"], 1)
		LxPixelFont.draw(self, LxStrings.text("HUB_REMATCH_HINT"), Vector2(PANEL.position.x + 10.0, fy + 10.0), LxPalette.PAL["stone"], 1)
