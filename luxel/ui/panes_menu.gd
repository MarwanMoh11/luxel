class_name LxPanesMenu
extends Node2D
## Stained-Glass Lantern Panes Menu (SPEC 3.5).
## Editable at rest shrines and Wick House Pane Workshop; read-only from Pause menu.
## Supports mouse (click + drag-and-drop onto lantern slots), keyboard, and gamepad.

signal closed()
signal pane_changed(pane_id: String, equipped: bool)

const PANEL_RECT := Rect2(14.0, 11.0, 292.0, 161.0)
const SHEET_PATH: String = "res://luxel/art/ui/panes.json"
const GRID_COLS: int = 8
const GRID_ROWS: int = 2
const TILE_W: float = 28.0
const TILE_H: float = 22.0
const TILE_GAP_X: float = 5.0
const TILE_GAP_Y: float = 4.0
const GRID_ORIGIN := Vector2(30.0, 74.0)

var read_only: bool = false
var _island_filter: int = 0          # 0 = ALL, 1..8 = island
var _panes: Array[LxPane] = []
var _idx: int = 0
var _focus_slots: bool = false       # keyboard/gamepad focus on top equipped lantern slots
var _slot_cursor: int = 0
var _scroll_row: int = 0
var _elapsed: float = 0.0
var _close_hover: bool = false
var _feedback_txt: String = ""
var _feedback_col: String = "lime"
var _feedback_t: float = 0.0
var _deny_t: float = 0.0
var _spark_slot: int = -1
var _spark_t: float = 0.0
var _sheet: LxSpriteSheet = null

# Mouse drag-and-drop state
var _dragging_id: String = ""
var _dragging_from_slot: int = -1
var _drag_pos: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _drag_active: bool = false


func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS; visible = false
func close() -> void: visible = false; _clear_drag()

func open(p_read_only: bool = false) -> void:
	read_only = p_read_only; _sheet = LxSpriteSheet.load_sheet(SHEET_PATH)
	LxPanes.current().load_from_state()
	_island_filter = 0; _rebuild_list()
	_idx = 0; _focus_slots = false; _slot_cursor = 0; _scroll_row = 0; _elapsed = 0.0
	_feedback_txt = ""; _feedback_t = 0.0; _deny_t = 0.0; _spark_slot = -1; _spark_t = 0.0
	_clear_drag(); visible = true; _play_sfx("menu_open"); queue_redraw()

func _clear_drag() -> void: _dragging_id = ""; _dragging_from_slot = -1; _drag_active = false
func _rebuild_list() -> void: _panes = LxPanes.current().panes_for_island(_island_filter); _idx = clampi(_idx, 0, maxi(0, _panes.size() - 1)); _sync_scroll()

func _sync_scroll() -> void:
	var row: int = _idx / GRID_COLS
	if row < _scroll_row: _scroll_row = row
	elif row >= _scroll_row + GRID_ROWS: _scroll_row = row - GRID_ROWS + 1
	_scroll_row = clampi(_scroll_row, 0, maxi(0, ceili(float(_panes.size()) / float(GRID_COLS)) - GRID_ROWS))

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - delta)
		if _feedback_t <= 0.0: _feedback_txt = ""
	if _deny_t > 0.0: _deny_t = maxf(0.0, _deny_t - delta)
	if _spark_t > 0.0:
		_spark_t = maxf(0.0, _spark_t - delta)
		if _spark_t <= 0.0: _spark_slot = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if LxUiNav.handle_tab_bar_key(event, 14):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return

	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause") or _key_just(event, KEY_ESCAPE):
		_play_sfx("menu_close")
		closed.emit()
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_Q) or _key_just(event, KEY_PAGEUP) or _joy_btn(event, JOY_BUTTON_LEFT_SHOULDER):
		_focus_slots = false
		_switch_island(-1)
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_E) or _key_just(event, KEY_TAB) or _key_just(event, KEY_PAGEDOWN) or _joy_btn(event, JOY_BUTTON_RIGHT_SHOULDER):
		_focus_slots = false
		_switch_island(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
		_move_cursor(-1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
		_move_cursor(1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_move_cursor(0, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_move_cursor(0, 1)
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_X) or _key_just(event, KEY_DELETE) or _key_just(event, KEY_BACKSPACE) or _joy_btn(event, JOY_BUTTON_X):
		_quick_unequip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_toggle_selected()
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(pos: Vector2) -> void:
	_drag_pos = pos
	if not _dragging_id.is_empty() and not _drag_active and pos.distance_to(_drag_start) > 4.0:
		_drag_active = true
	var over_c: bool = _close_btn_rect().has_point(pos)
	if over_c != _close_hover:
		_close_hover = over_c
		if over_c: _play_sfx("ui_move")
	var hit_i: int = _grid_index_at(pos)
	if hit_i >= 0 and hit_i != _idx:
		_idx = hit_i
		_play_sfx("ui_move")
	queue_redraw()


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	var pos: Vector2 = mb.position
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_play_sfx("menu_close")
		closed.emit()
		get_viewport().set_input_as_handled()
		return
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var delta_r: int = -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		var max_r: int = maxi(0, ceili(float(_panes.size()) / float(GRID_COLS)) - GRID_ROWS)
		_scroll_row = clampi(_scroll_row + delta_r, 0, max_r)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		if LxUiNav.handle_tab_bar_click(pos, 14):
			get_viewport().set_input_as_handled()
			return
		if _close_btn_rect().has_point(pos):
			_play_sfx("menu_close")
			closed.emit()
			get_viewport().set_input_as_handled()
			return
		for fi: int in range(9):
			if _filter_rect(fi).has_point(pos):
				_island_filter = fi
				_rebuild_list()
				_play_sfx("ui_move")
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		var s_idx: int = _slot_index_at(pos)
		if s_idx >= 0:
			var eq: PackedStringArray = LxPanes.current().equipped_ids()
			if not read_only and s_idx < eq.size():
				_dragging_id = eq[s_idx]
				_dragging_from_slot = s_idx
				_drag_start = pos
				_drag_pos = pos
				_drag_active = false
			get_viewport().set_input_as_handled()
			return
		var g_idx: int = _grid_index_at(pos)
		if g_idx >= 0:
			_idx = g_idx
			var p: LxPane = _panes[g_idx]
			if not read_only and LxPanes.current().has_pane(p.id):
				_dragging_id = p.id
				_dragging_from_slot = -1
				_drag_start = pos
				_drag_pos = pos
				_drag_active = false
			else:
				_toggle_selected()
			get_viewport().set_input_as_handled()
			return
	else:
		if not _dragging_id.is_empty():
			_finish_drag(pos)
			get_viewport().set_input_as_handled()


func _finish_drag(pos: Vector2) -> void:
	var pid: String = _dragging_id
	var from_s: int = _dragging_from_slot
	var was_drag: bool = _drag_active
	_clear_drag()
	if read_only:
		return
	var drop_s: int = _slot_index_at(pos)
	var pm: LxPanes = LxPanes.current()
	if not was_drag:
		if from_s >= 0:
			if pm.unequip_slot(from_s):
				_set_feedback("PANE_REMOVED", "stone")
				_play_sfx("ui_back")
				pane_changed.emit(pid, false)
		else:
			_toggle_pane(pid)
		return
	if from_s >= 0:
		if drop_s >= 0 and drop_s < pm.equipped_ids().size() and drop_s != from_s:
			pm.swap_slots(from_s, drop_s)
			_spark_slot = drop_s
			_spark_t = 0.35
			_play_sfx("pane_fit")
		elif drop_s < 0:
			pm.unequip_slot(from_s)
			_set_feedback("PANE_REMOVED", "stone")
			_play_sfx("ui_back")
			pane_changed.emit(pid, false)
	else:
		if drop_s >= 0:
			var rep: int = drop_s if drop_s < pm.equipped_ids().size() else -1
			_equip_pane(pid, rep)


func _switch_island(dir: int) -> void:
	_island_filter = (_island_filter + dir + 9) % 9
	_rebuild_list()
	_play_sfx("ui_move")
	queue_redraw()


func _move_cursor(dx: int, dy: int) -> void:
	if _focus_slots:
		if dy > 0:
			_focus_slots = false
			_play_sfx("ui_move"); queue_redraw(); return
		if dx != 0:
			_slot_cursor = (_slot_cursor + dx + LxPanes.MAX_SLOTS) % LxPanes.MAX_SLOTS
			_play_sfx("ui_move"); queue_redraw()
		return
	if _panes.is_empty():
		return
	if dy < 0 and _idx < GRID_COLS:
		_focus_slots = true
		_slot_cursor = clampi(_idx, 0, LxPanes.MAX_SLOTS - 1)
		_play_sfx("ui_move"); queue_redraw(); return
	var next_i: int = _idx + dx + dy * GRID_COLS
	if next_i < 0:
		next_i = _panes.size() - 1
	elif next_i >= _panes.size():
		next_i = 0
	_idx = next_i
	_sync_scroll()
	_play_sfx("ui_move")
	queue_redraw()


func _quick_unequip() -> void:
	if read_only:
		_set_feedback("PANES_READONLY_TIP", "sky"); _play_sfx("denied"); return
	var pm: LxPanes = LxPanes.current()
	if _focus_slots:
		var eq: PackedStringArray = pm.equipped_ids()
		if _slot_cursor < eq.size():
			var pid: String = eq[_slot_cursor]
			if pm.unequip_slot(_slot_cursor):
				_set_feedback("PANE_REMOVED", "stone"); _play_sfx("ui_back"); pane_changed.emit(pid, false)
		return
	if _idx >= 0 and _idx < _panes.size() and pm.is_equipped(_panes[_idx].id):
		var pid2: String = _panes[_idx].id
		pm.unequip(pid2)
		_set_feedback("PANE_REMOVED", "stone"); _play_sfx("ui_back"); pane_changed.emit(pid2, false)


func _toggle_selected() -> void:
	if _focus_slots:
		_quick_unequip()
		return
	if _idx < 0 or _idx >= _panes.size():
		return
	if read_only:
		_set_feedback("PANES_READONLY_TIP", "sky")
		_play_sfx("denied")
		return
	_toggle_pane(_panes[_idx].id)


func _toggle_pane(pid: String) -> void:
	var pm: LxPanes = LxPanes.current()
	if pm.is_equipped(pid):
		pm.unequip(pid)
		_set_feedback("PANE_REMOVED", "stone")
		_play_sfx("ui_back")
		pane_changed.emit(pid, false)
		return
	_equip_pane(pid, -1)


func _equip_pane(pid: String, at_slot: int) -> void:
	var pm: LxPanes = LxPanes.current()
	var err: String = pm.can_equip(pid, at_slot)
	if not err.is_empty():
		_set_feedback(err, "coral")
		_deny_t = 0.24
		_play_sfx("denied")
		return
	if pm.equip(pid, at_slot):
		_spark_slot = at_slot if at_slot >= 0 else pm.equipped_ids().size() - 1
		_spark_t = 0.42
		_set_feedback("PANE_EQUIPPED", "lime")
		_play_sfx("pane_fit")
		pane_changed.emit(pid, true)


func _set_feedback(str_id: String, col_key: String) -> void:
	_feedback_txt = LxFolkData.tr_id(str_id)
	_feedback_col = col_key
	_feedback_t = 1.5
	queue_redraw()


func _draw() -> void:
	var isl: int = clampi(Lx.state.island_id if Lx.state != null else 1, 1, 8)
	var bdr_k: String = LxBiomePalette.key(isl, "border")
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", bdr_k, "night")
	_draw_ornaments(isl)
	LxUiNav.draw_pause_tab_bar(self, 14)

	var pm: LxPanes = LxPanes.current()
	# Header: Title + Read-only badge + Lead budget pips + Owned count
	LxPixelFont.draw_left(self, LxFolkData.tr_id("PANES_TITLE"), Vector2(24.0, 15.0), LxPalette.PAL["gold"], 1)
	if read_only:
		var ro_r := Rect2(94.0, 13.0, 44.0, 9.0)
		LxPixelFont.draw_panel(self, ro_r, "night", "sky", "void")
		LxPixelFont.draw_centered(self, LxFolkData.tr_id("PANES_VIEW_ONLY"), ro_r.get_center().x, 15.0, LxPalette.PAL["ice"], 1)

	var lead_txt: String = LxFolkData.fmt_id("PANES_LEAD_FMT", [pm.used_lead(), pm.get_max_lead()])
	LxPixelFont.draw_left(self, lead_txt, Vector2(146.0, 15.0), LxPalette.PAL["cream"], 1)
	for li: int in range(pm.get_max_lead()):
		var lx: float = 192.0 + float(li * 5)
		var filled: bool = li < pm.used_lead()
		draw_rect(Rect2(lx, 15.0, 4.0, 5.0), LxPalette.PAL["void"])
		draw_rect(Rect2(lx + 1.0, 16.0, 2.0, 3.0), LxPalette.PAL["gold"] if filled else LxPalette.PAL["night"])

	var own_txt: String = LxFolkData.fmt_id("PANES_OWNED_FMT", [pm.owned_ids().size(), pm.all_ids().size()])
	LxPixelFont.draw_right(self, own_txt, 298.0, 15.0, LxPalette.PAL["apricot"], 1)

	# Lantern glass slots row (3..5 arched stained-glass sockets)
	_draw_lantern_slots(pm)

	# Island filter strip (ALL + 1..8 with per-island owned count)
	_draw_island_filters(pm)

	# Pane tile grid + subtle scrollbar when > 2 rows
	_draw_pane_grid(pm)
	_draw_grid_scrollbar()

	# Bottom inspector box
	_draw_inspector(pm)

	# Footer hint + Close button
	var hint_id: String = "PANES_HINT_VIEW" if read_only else "PANES_HINT_EDIT"
	LxPixelFont.draw_left(self, LxFolkData.tr_id(hint_id), Vector2(22.0, 160.0), LxPalette.PAL["stone"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxFolkData.tr_id("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)

	# Drag ghost
	if _drag_active and not _dragging_id.is_empty():
		var dp: Vector2 = _drag_pos.round() - Vector2(6.0, 6.0)
		draw_rect(Rect2(dp - Vector2.ONE, Vector2(14.0, 14.0)), LxPalette.PAL["gold"])
		_draw_pane_sprite(_dragging_id, dp, false)


func _draw_lantern_slots(pm: LxPanes) -> void:
	var eq: PackedStringArray = pm.equipped_ids()
	var slots: int = pm.get_slots()
	for si: int in range(LxPanes.MAX_SLOTS):
		var sr: Rect2 = _slot_rect(si)
		var locked: bool = si >= slots
		var filled: bool = si < eq.size()
		var bdr: String = "cream" if (_focus_slots and si == _slot_cursor) else ("night" if locked else ("gold" if filled else "mauve"))
		var fill: String = "plum" if ((_focus_slots and si == _slot_cursor) or filled) else ("void" if locked else "night")
		if _spark_t > 0.0 and si == _spark_slot:
			bdr = "cream"
		# Arched lantern-glass brass bail & cap
		draw_rect(Rect2(sr.position.x + 11.0, sr.position.y - 4.0, 6.0, 1.0), LxPalette.PAL["gold"] if filled else LxPalette.PAL["dusk"])
		draw_rect(Rect2(sr.position.x + 10.0, sr.position.y - 3.0, 1.0, 1.0), LxPalette.PAL["apricot"] if not locked else LxPalette.PAL["night"])
		draw_rect(Rect2(sr.position.x + 17.0, sr.position.y - 3.0, 1.0, 1.0), LxPalette.PAL["apricot"] if not locked else LxPalette.PAL["night"])
		draw_rect(Rect2(sr.position.x + 6.0, sr.position.y - 2.0, sr.size.x - 12.0, 2.0), LxPalette.PAL["apricot"] if not locked else LxPalette.PAL["dusk"])
		LxPixelFont.draw_panel(self, sr, fill, bdr, "void")
		if locked:
			draw_rect(Rect2(sr.get_center().x - 2.0, sr.get_center().y - 2.0, 4.0, 4.0), LxPalette.PAL["dusk"])
			draw_rect(Rect2(sr.get_center().x - 1.0, sr.get_center().y - 4.0, 2.0, 2.0), LxPalette.PAL["mauve"])
		elif filled:
			var p: LxPane = pm.get_pane(eq[si])
			_draw_pane_sprite(eq[si], sr.position + Vector2(4.0, 4.0), false)
			if p != null:
				for ci: int in range(p.lead_cost):
					draw_rect(Rect2(sr.position.x + 20.0, sr.position.y + 4.0 + float(ci * 4), 3.0, 3.0), LxPalette.PAL["gold"])
		else:
			draw_rect(Rect2(sr.get_center().x - 1.0, sr.get_center().y - 1.0, 2.0, 2.0), LxPalette.PAL["dusk"])


func _draw_island_filters(pm: LxPanes) -> void:
	for fi: int in range(9):
		var fr: Rect2 = _filter_rect(fi)
		var sel: bool = fi == _island_filter
		var bdr: String = "gold" if sel else "dusk"
		var fill: String = "plum" if sel else "night"
		LxPixelFont.draw_panel(self, fr, fill, bdr, "void")
		var lbl: String = LxFolkData.tr_id("PANES_TAB_ALL") if fi == 0 else str(fi)
		var col: Color = LxPalette.PAL["gold"] if sel else (LxBiomePalette.col(fi, "glow") if fi > 0 else LxPalette.PAL["cream"])
		LxPixelFont.draw_centered(self, lbl, fr.get_center().x, fr.position.y + 3.0, col, 1)
	if _island_filter > 0:
		var cnt: int = pm.owned_count_for_island(_island_filter)
		var ct: String = LxFolkData.fmt_id("PANES_ISL_COUNT_FMT", [_island_filter, cnt, 4])
		LxPixelFont.draw_right(self, ct, 296.0, 57.0, LxBiomePalette.col(_island_filter, "glow"), 1)


func _draw_pane_grid(pm: LxPanes) -> void:
	var start_i: int = _scroll_row * GRID_COLS
	var end_i: int = mini(_panes.size(), start_i + GRID_COLS * GRID_ROWS)
	for i: int in range(start_i, end_i):
		var vis: int = i - start_i
		var tr: Rect2 = _tile_rect(vis)
		var p: LxPane = _panes[i]
		var sel: bool = i == _idx
		var owned: bool = pm.has_pane(p.id)
		var eq: bool = pm.is_equipped(p.id)
		if sel and _deny_t > 0.0 and LxHudFx.shake_enabled():
			tr.position.x += roundf(sin(_deny_t * 50.0) * 1.5)
		var bdr: String = "coral" if (sel and _deny_t > 0.0) else ("gold" if sel else ("lime" if eq else ("mauve" if owned else "night")))
		var fill: String = "plum" if sel else ("dusk" if eq else ("night" if owned else "void"))
		LxPixelFont.draw_panel(self, tr, fill, bdr, "void")
		_draw_pane_sprite(p.id, tr.position + Vector2(3.0, 5.0), not owned)
		# Lead cost pips on right edge of tile
		for c: int in range(p.lead_cost):
			var pc: Color = LxPalette.PAL["gold"] if owned else LxPalette.PAL["dusk"]
			draw_rect(Rect2(tr.end.x - 6.0, tr.position.y + 4.0 + float(c * 4), 2.0, 2.0), pc)
		# Equipped corner diamond
		if eq:
			draw_rect(Rect2(tr.end.x - 6.0, tr.end.y - 6.0, 3.0, 3.0), LxPalette.PAL["lime"])
			draw_rect(Rect2(tr.end.x - 5.0, tr.end.y - 5.0, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_inspector(pm: LxPanes) -> void:
	var box := Rect2(22.0, 126.0, 276.0, 28.0)
	LxPixelFont.draw_panel(self, box, "night", "mauve", "void")
	if not _feedback_txt.is_empty():
		LxPixelFont.draw_centered(self, _feedback_txt, box.get_center().x, box.position.y + 11.0, LxPalette.color(_feedback_col), 1)
		return
	var p: LxPane = null
	if _focus_slots:
		var eq_s: PackedStringArray = pm.equipped_ids()
		if _slot_cursor < eq_s.size():
			p = pm.get_pane(eq_s[_slot_cursor])
		if p == null:
			LxPixelFont.draw_centered(self, LxFolkData.tr_id("PANES_HINT_EDIT" if not read_only else "PANES_HINT_VIEW"), box.get_center().x, box.position.y + 11.0, LxPalette.PAL["stone"], 1)
			return
	else:
		if _idx < 0 or _idx >= _panes.size():
			return
		p = _panes[_idx]
	var owned: bool = pm.has_pane(p.id)
	_draw_pane_sprite(p.id, box.position + Vector2(6.0, 8.0), not owned)
	if not owned:
		LxPixelFont.draw_left(self, LxFolkData.tr_id("PANE_UNKNOWN_NAME"), box.position + Vector2(23.0, 6.0), LxPalette.PAL["mauve"], 1)
		var hint_src: String = LxFolkData.fmt_id("PANE_SRC_FMT", [p.island_id, LxFolkData.tr_id("PANE_SRC_" + p.source_kind.to_upper())])
		LxPixelFont.draw_left(self, hint_src, box.position + Vector2(23.0, 16.0), LxPalette.PAL["stone"], 1)
		return
	LxPixelFont.draw_left(self, LxFolkData.tr_id(p.name_key), box.position + Vector2(23.0, 5.0), LxPalette.PAL["gold"], 1)
	var meta: String = LxFolkData.fmt_id("PANE_COST_FMT", [p.lead_cost, p.island_id])
	LxPixelFont.draw_right(self, meta, box.end.x - 6.0, box.position.y + 5.0, LxPalette.PAL["apricot"], 1)
	LxPixelFont.draw_left(self, LxFolkData.tr_id(p.desc_key), box.position + Vector2(23.0, 16.0), LxPalette.PAL["cream"], 1)


func _draw_pane_sprite(pid: String, top_left: Vector2, dimmed: bool) -> void:
	if _sheet != null and _sheet.tex != null and _sheet.props.has(pid):
		var mod: Color = LxPalette.PAL["dusk"] if dimmed else Color.WHITE
		_sheet.draw_prop(self, top_left + Vector2(6.0, 6.0), pid, _elapsed, mod)
		return
	draw_rect(Rect2(top_left, Vector2(12.0, 12.0)), LxPalette.PAL["dusk"] if dimmed else LxPalette.PAL["gold"])


func _draw_ornaments(isl: int) -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var hi: Color = LxBiomePalette.col(isl, "hi")
	var glow: Color = LxBiomePalette.col(isl, "glow")
	for rv: Vector2 in [
		Vector2(p.x + 3.0, p.y + 3.0), Vector2(e.x - 5.0, p.y + 3.0),
		Vector2(p.x + 3.0, e.y - 5.0), Vector2(e.x - 5.0, e.y - 5.0),
	]:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), hi)
		draw_rect(Rect2(rv, Vector2.ONE), glow)
	draw_rect(Rect2(22.0, 22.0, 276.0, 1.0), LxPalette.PAL["night"])
	var dx: float = 26.0
	while dx < 294.0:
		draw_rect(Rect2(dx, 22.0, 3.0, 1.0), hi if int(dx) % 12 == 0 else LxPalette.PAL["dusk"])
		dx += 6.0
	draw_rect(Rect2(159.0, 21.0, 3.0, 3.0), glow)
	draw_rect(Rect2(160.0, 22.0, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_grid_scrollbar() -> void:
	var total_rows: int = ceili(float(_panes.size()) / float(GRID_COLS))
	if total_rows <= GRID_ROWS:
		return
	var track := Rect2(294.0, 74.0, 3.0, 48.0)
	draw_rect(track.grow(1.0), LxPalette.PAL["night"])
	draw_rect(track, LxPalette.PAL["void"])
	var thumb_h: float = maxf(10.0, roundf(track.size.y * float(GRID_ROWS) / float(total_rows)))
	var frac: float = float(_scroll_row) / float(maxi(1, total_rows - GRID_ROWS))
	var ty: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
	draw_rect(Rect2(track.position.x, ty, track.size.x, thumb_h), LxPalette.PAL["gold"])
	draw_rect(Rect2(track.position.x, ty, track.size.x, 1.0), LxPalette.PAL["cream"])


func _slot_rect(si: int) -> Rect2:
	return Rect2(76.0 + float(si) * 35.0, 31.0, 28.0, 20.0)


func _filter_rect(fi: int) -> Rect2:
	if fi == 0:
		return Rect2(22.0, 54.0, 26.0, 11.0)
	return Rect2(50.0 + float(fi - 1) * 18.0, 54.0, 16.0, 11.0)


func _tile_rect(vis_idx: int) -> Rect2:
	var col: int = vis_idx % GRID_COLS
	var row: int = vis_idx / GRID_COLS
	return Rect2(
		GRID_ORIGIN.x + float(col) * (TILE_W + TILE_GAP_X),
		GRID_ORIGIN.y + float(row) * (TILE_H + TILE_GAP_Y),
		TILE_W, TILE_H
	)


func _close_btn_rect() -> Rect2:
	return Rect2(242.0, 157.0, 56.0, 11.0)


func _slot_index_at(pos: Vector2) -> int:
	for si: int in range(LxPanes.MAX_SLOTS):
		if _slot_rect(si).has_point(pos):
			return si
	return -1


func _grid_index_at(pos: Vector2) -> int:
	var start_i: int = _scroll_row * GRID_COLS
	var end_i: int = mini(_panes.size(), start_i + GRID_COLS * GRID_ROWS)
	for i: int in range(start_i, end_i):
		if _tile_rect(i - start_i).has_point(pos):
			return i
	return -1


func _play_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _joy_btn(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
