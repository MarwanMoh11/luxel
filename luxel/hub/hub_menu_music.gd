class_name LxHubMenuMusic
extends Node2D
## Music Box overlay: lists all unlocked soundtrack cues across the 8 islands,
## plays immediately on selection, saves as the Wick House track, and draws pixel equalizer bars.

signal closed()
signal track_selected(cue_id: String)

const PANEL := Rect2(26.0, 12.0, 268.0, 156.0)
const VISIBLE_ROWS: int = 7

const TRACK_CATALOG: Array[Dictionary] = [
	{"cue": "hub", "name_key": "HUB_TRK_HUB", "unlock": "always"},
	{"cue": "title", "name_key": "HUB_TRK_TITLE", "unlock": "always"},
	{"cue": "island1_explore", "name_key": "HUB_TRK_I1_EXP", "unlock": "island:1"},
	{"cue": "island1_dungeon", "name_key": "HUB_TRK_I1_DNG", "unlock": "island:1"},
	{"cue": "island1_boss_p1", "name_key": "HUB_TRK_I1_BOSS", "unlock": "boss_isl:1"},
	{"cue": "island2_explore", "name_key": "HUB_TRK_I2_EXP", "unlock": "island:2"},
	{"cue": "island2_dungeon", "name_key": "HUB_TRK_I2_DNG", "unlock": "island:2"},
	{"cue": "island2_boss_p1", "name_key": "HUB_TRK_I2_BOSS", "unlock": "boss_isl:2"},
	{"cue": "island3_explore", "name_key": "HUB_TRK_I3_EXP", "unlock": "island:3"},
	{"cue": "island3_dungeon", "name_key": "HUB_TRK_I3_DNG", "unlock": "island:3"},
	{"cue": "island3_boss_p1", "name_key": "HUB_TRK_I3_BOSS", "unlock": "boss_isl:3"},
	{"cue": "island4_explore", "name_key": "HUB_TRK_I4_EXP", "unlock": "island:4"},
	{"cue": "island4_boss_p1", "name_key": "HUB_TRK_I4_BOSS", "unlock": "boss_isl:4"},
	{"cue": "island5_explore", "name_key": "HUB_TRK_I5_EXP", "unlock": "island:5"},
	{"cue": "island5_boss_p1", "name_key": "HUB_TRK_I5_BOSS", "unlock": "boss_isl:5"},
	{"cue": "island6_explore", "name_key": "HUB_TRK_I6_EXP", "unlock": "island:6"},
	{"cue": "island6_boss_p1", "name_key": "HUB_TRK_I6_BOSS", "unlock": "boss_isl:6"},
	{"cue": "island7_explore", "name_key": "HUB_TRK_I7_EXP", "unlock": "island:7"},
	{"cue": "island7_boss_p1", "name_key": "HUB_TRK_I7_BOSS", "unlock": "boss_isl:7"},
	{"cue": "island8_explore", "name_key": "HUB_TRK_I8_EXP", "unlock": "island:8"},
	{"cue": "island8_boss_p1", "name_key": "HUB_TRK_I8_BOSS", "unlock": "boss_isl:8"},
	{"cue": "ending_dawn", "name_key": "HUB_TRK_DAWN", "unlock": "ending"},
]

var _rows: Array[Dictionary] = []
var _idx: int = 0
var _scroll: int = 0
var _clock: float = 0.0
var _playing_cue: String = "hub"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_rebuild()
	_playing_cue = str(Lx.state.story_flags.get("hub:music_track", "hub")) if Lx.state != null else "hub"
	_idx = 0
	for i: int in range(_rows.size()):
		if str(_rows[i]["cue"]) == _playing_cue:
			_idx = i
			break
	_sync_scroll()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func get_rows() -> Array[Dictionary]:
	return _rows


func select_index(i: int) -> void:
	if _rows.is_empty():
		return
	_idx = clampi(i, 0, _rows.size() - 1)
	_sync_scroll()
	queue_redraw()


func confirm_selected() -> bool:
	if _rows.is_empty() or _idx < 0 or _idx >= _rows.size():
		return false
	var row: Dictionary = _rows[_idx]
	if not bool(row["unlocked"]):
		if Lx.audio != null:
			Lx.audio.play_sfx("denied", Vector2.ZERO, false, true)
		return false
	var cue: String = str(row["cue"])
	_playing_cue = cue
	if Lx.state != null:
		Lx.state.story_flags["hub:music_track"] = cue
	if Lx.audio != null:
		Lx.audio.play_cue(cue)
		Lx.audio.play_sfx("ui_confirm", Vector2.ZERO, false, true)
	if Lx.events != null:
		Lx.events.save_requested.emit("hub_music")
	track_selected.emit(cue)
	queue_redraw()
	return true


func _rebuild() -> void:
	_rows.clear()
	for entry: Dictionary in TRACK_CATALOG:
		var unl: bool = _is_unlocked(str(entry["unlock"]))
		var r: Dictionary = entry.duplicate()
		r["unlocked"] = unl
		_rows.append(r)


static func _is_unlocked(rule: String) -> bool:
	if rule == "always":
		return true
	if Lx.state == null:
		return false
	if rule == "ending":
		return bool(Lx.state.story_flags.get("ending_seen", false)) or Lx.state.relit_islands.has(8)
	if rule.begins_with("island:"):
		var isl: int = int(rule.substr(7))
		if isl <= 1 or Lx.state.relit_islands.has(isl):
			return true
		for vr: String in Lx.state.visited_regions:
			if vr.begins_with("%d:" % isl):
				return true
		return false
	if rule.begins_with("boss_isl:"):
		var bisl: int = int(rule.substr(9))
		if Lx.state.relit_islands.has(bisl):
			return true
		if Lx.packs != null:
			for bid: String in Lx.state.defeated_bosses:
				if int(Lx.packs.boss_meta(bid).get("island", 0)) == bisl:
					return true
		return false
	return false


func _sync_scroll() -> void:
	if _idx < _scroll:
		_scroll = _idx
	elif _idx >= _scroll + VISIBLE_ROWS:
		_scroll = _idx - VISIBLE_ROWS + 1
	_scroll = clampi(_scroll, 0, maxi(0, _rows.size() - VISIBLE_ROWS))


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	queue_redraw()


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
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
			if _close_rect().has_point(mb.position):
				_play_ui("menu_close"); closed.emit(); return true
			for ri: int in range(VISIBLE_ROWS):
				var ei: int = _scroll + ri
				if ei >= _rows.size():
					break
				if _row_rect(ri).has_point(mb.position):
					select_index(ei)
					confirm_selected()
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
		if k == KEY_ENTER or k == KEY_SPACE or k == KEY_E:
			confirm_selected(); return true
	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause"):
		_play_ui("menu_close"); closed.emit(); return true
	if event.is_action_pressed("lx_ui_accept"):
		confirm_selected(); return true
	return false


func _play_ui(sfx: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx, Vector2.ZERO, false, true)


func _close_rect() -> Rect2:
	return Rect2(PANEL.end.x - 16.0, PANEL.position.y + 4.0, 12.0, 12.0)


func _row_rect(ri: int) -> Rect2:
	return Rect2(PANEL.position.x + 8.0, PANEL.position.y + 30.0 + float(ri) * 15.0, PANEL.size.x - 16.0, 13.0)


func _draw() -> void:
	if not visible:
		return
	draw_rect(PANEL, LxPalette.PAL["void"])
	draw_rect(PANEL.grow(-1.0), LxPalette.PAL["night"])
	draw_rect(Rect2(PANEL.position.x + 2.0, PANEL.position.y + 2.0, PANEL.size.x - 4.0, 16.0), LxPalette.PAL["wine"])
	draw_rect(Rect2(PANEL.position.x + 1.0, PANEL.position.y + 1.0, PANEL.size.x - 2.0, 1.0), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "music", Vector2(PANEL.position.x + 6.0, PANEL.position.y + 5.0), 1.0)
	LxPixelFont.draw(self, LxStrings.text("HUB_MUSIC_TITLE"), Vector2(PANEL.position.x + 20.0, PANEL.position.y + 7.0), LxPalette.PAL["gold"], 1)

	var cr: Rect2 = _close_rect()
	draw_rect(cr, LxPalette.PAL["dusk"])
	LxPixelFont.draw_centered(self, "X", cr.position.x + cr.size.x * 0.5, cr.position.y + 3.0, LxPalette.PAL["cream"], 1)

	var unl_n: int = 0
	for r: Dictionary in _rows:
		if bool(r["unlocked"]):
			unl_n += 1
	LxPixelFont.draw(self, LxStrings.fmt("HUB_MUSIC_COUNT", [unl_n, _rows.size()]), Vector2(PANEL.position.x + 10.0, PANEL.position.y + 21.0), LxPalette.PAL["stone"], 1)

	var fred: bool = LxHudFx.flash_reduced()
	for ri: int in range(VISIBLE_ROWS):
		var ei: int = _scroll + ri
		if ei >= _rows.size():
			break
		var row: Dictionary = _rows[ei]
		var rr: Rect2 = _row_rect(ri)
		var sel: bool = ei == _idx
		var unl: bool = bool(row["unlocked"])
		var is_now: bool = str(row["cue"]) == _playing_cue
		draw_rect(rr, LxPalette.PAL["plum"] if sel else LxPalette.PAL["void"])
		if sel:
			draw_rect(Rect2(rr.position.x, rr.position.y, 2.0, rr.size.y), LxPalette.PAL["gold"])
		var lbl: String = LxStrings.text(str(row["name_key"])) if unl else LxStrings.text("HUB_MUSIC_LOCKED")
		var col: Color = LxPalette.PAL["gold"] if is_now else (LxPalette.PAL["cream"] if unl else LxPalette.PAL["mauve"])
		LxPixelFont.draw(self, lbl, Vector2(rr.position.x + 6.0, rr.position.y + 4.0), col, 1)
		if is_now:
			# Animated pixel equalizer bars
			for bi: int in range(4):
				var bh: float = 4.0 if fred else clampf(roundf(3.0 + 4.0 * absf(sin(_clock * 5.2 + float(bi) * 1.1))), 2.0, 8.0)
				draw_rect(Rect2(rr.end.x - 22.0 + float(bi * 4), rr.end.y - 2.0 - bh, 2.0, bh), LxPalette.PAL["gold"])

	var fy: float = PANEL.end.y - 16.0
	draw_rect(Rect2(PANEL.position.x + 4.0, fy - 2.0, PANEL.size.x - 8.0, 1.0), LxPalette.PAL["dusk"])
	LxPixelFont.draw(self, LxStrings.text("HUB_MUSIC_HINT"), Vector2(PANEL.position.x + 10.0, fy + 3.0), LxPalette.PAL["stone"], 1)
