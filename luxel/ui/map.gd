class_name LxMapScreen
extends Node2D
## Archipelago map and Waystone fast travel (SWARM_SPEC 3.8).
## Shows explored regions (unexplored stay dark), lit Waystones, Beacons, Dungeon icon,
## and ember/secret counts (counts only, never secret locations).

signal closed()
signal fast_travel_requested(island_id: int, waystone_id: String)

const ISLAND_POS: Array[Vector2] = [
	Vector2(44.0, 74.0),
	Vector2(76.0, 56.0),
	Vector2(108.0, 80.0),
	Vector2(140.0, 58.0),
	Vector2(172.0, 78.0),
	Vector2(204.0, 54.0),
	Vector2(236.0, 76.0),
	Vector2(268.0, 58.0),
]

const PANEL_RECT := Rect2(12.0, 10.0, 296.0, 160.0)

var _selected_island: int = 1
var _waystone_idx: int = 0
var _waystone_list: Array[Dictionary] = [] # {island_id, waystone_id, label}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if Lx.data_islands.is_empty():
		Lx.load_all_data()
	_selected_island = Lx.state.island_id if Lx.state != null else 1
	_rebuild_waystones()
	_waystone_idx = 0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _rebuild_waystones() -> void:
	_waystone_list.clear()
	if Lx.state == null:
		return
	for ws: String in Lx.state.lit_waystones:
		var isl: int = _waystone_island(ws)
		if isl == _selected_island or _selected_island == 0:
			_waystone_list.append({
				"island_id": isl,
				"waystone_id": ws,
				"label": LxStrings.sanitize(ws, 18),
			})
	if _waystone_list.is_empty():
		for ws: String in Lx.state.lit_waystones:
			var isl: int = _waystone_island(ws)
			_waystone_list.append({
				"island_id": isl,
				"waystone_id": ws,
				"label": LxStrings.sanitize(ws, 18),
			})
	_waystone_idx = clampi(_waystone_idx, 0, maxi(0, _waystone_list.size() - 1))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_click(mb.position):
				get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
		_selected_island = 8 if _selected_island <= 1 else _selected_island - 1
		_rebuild_waystones()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
		_selected_island = 1 if _selected_island >= 8 else _selected_island + 1
		_rebuild_waystones()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		if not _waystone_list.is_empty():
			_waystone_idx = (_waystone_idx - 1 + _waystone_list.size()) % _waystone_list.size()
			_play_ui_sfx("ui_move")
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		if not _waystone_list.is_empty():
			_waystone_idx = (_waystone_idx + 1) % _waystone_list.size()
			_play_ui_sfx("ui_move")
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		if not _waystone_list.is_empty():
			var item: Dictionary = _waystone_list[_waystone_idx]
			_play_ui_sfx("ui_confirm")
			fast_travel_requested.emit(int(item["island_id"]), str(item["waystone_id"]))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_map") or _key_just(event, KEY_ESCAPE) or _key_just(event, KEY_TAB):
		_play_ui_sfx("ui_back")
		closed.emit()
		get_viewport().set_input_as_handled()


func _handle_click(pos: Vector2) -> bool:
	for i: int in range(ISLAND_POS.size()):
		if pos.distance_to(ISLAND_POS[i]) <= 12.0:
			_selected_island = i + 1
			_rebuild_waystones()
			_play_ui_sfx("ui_move")
			queue_redraw()
			return true
	for i: int in range(mini(_waystone_list.size(), 3)):
		if _ws_row_rect(i).has_point(pos):
			_waystone_idx = i
			var item: Dictionary = _waystone_list[i]
			_play_ui_sfx("ui_confirm")
			fast_travel_requested.emit(int(item["island_id"]), str(item["waystone_id"]))
			return true
	return false


func _draw() -> void:
	LxPixelFont.draw_panel(self, PANEL_RECT, "void", "mauve", "night")
	LxPixelFont.draw_centered(self, LxStrings.text("MAP_TITLE"), 160.0, 16.0, LxPalette.PAL["gold"], 1)

	# Archipelago chart box.
	var chart := Rect2(20.0, 26.0, 280.0, 66.0)
	LxPixelFont.draw_panel(self, chart, "night", "dusk", "void")
	_draw_bridges()
	_draw_islands()

	# Lower left: island details. Lower right: Waystone fast travel.
	_draw_island_info(Rect2(20.0, 96.0, 146.0, 58.0))
	_draw_waystones(Rect2(170.0, 96.0, 130.0, 58.0))

	LxPixelFont.draw_centered(self, LxStrings.text("MAP_HINT"), 160.0, 160.0, LxPalette.PAL["stone"], 1)


func _draw_bridges() -> void:
	if Lx.state == null:
		return
	for i: int in range(ISLAND_POS.size() - 1):
		var a: Vector2 = ISLAND_POS[i]
		var b: Vector2 = ISLAND_POS[i + 1]
		var open_bridge: bool = Lx.state.relit_islands.has(i + 1)
		var col: Color = LxPalette.PAL["gold"] if open_bridge else LxPalette.PAL["dusk"]
		var steps: int = 8
		for s: int in range(1, steps):
			var p: Vector2 = a.lerp(b, float(s) / float(steps)).round()
			draw_rect(Rect2(p, Vector2(2.0, 2.0)), col)


func _draw_islands() -> void:
	for i: int in range(ISLAND_POS.size()):
		var isl_id: int = i + 1
		var c: Vector2 = ISLAND_POS[i]
		var explored: bool = _is_island_explored(isl_id)
		var relit: bool = Lx.state != null and Lx.state.relit_islands.has(isl_id)
		var is_cur: bool = Lx.state != null and Lx.state.island_id == isl_id
		var is_sel: bool = isl_id == _selected_island

		if is_sel:
			draw_rect(Rect2(c - Vector2(10.0, 8.0), Vector2(20.0, 16.0)), LxPalette.PAL["gold"])
		var fill: Color = LxPalette.PAL["gold"] if relit else (LxPalette.PAL["jade"] if explored else LxPalette.PAL["dusk"])
		var rim: Color = LxPalette.PAL["cream"] if is_cur else (LxPalette.PAL["pine"] if explored else LxPalette.PAL["night"])
		draw_rect(Rect2(c - Vector2(8.0, 6.0), Vector2(16.0, 12.0)), rim)
		draw_rect(Rect2(c - Vector2(7.0, 5.0), Vector2(14.0, 10.0)), fill)
		# Dungeon tower pip on explored islands.
		if explored:
			var dcol: Color = LxPalette.PAL["cream"] if relit else LxPalette.PAL["coral"]
			draw_rect(Rect2(c + Vector2(2.0, -4.0), Vector2(3.0, 4.0)), dcol)
		if is_cur:
			draw_rect(Rect2(c - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), LxPalette.PAL["cream"])


func _draw_island_info(box: Rect2) -> void:
	LxPixelFont.draw_panel(self, box, "dusk", "mauve", "night")
	var explored: bool = _is_island_explored(_selected_island)
	var data: Dictionary = Lx.get_island_data(_selected_island)
	if not explored:
		LxPixelFont.draw_left(self, LxStrings.text("MAP_UNEXPLORED"), box.position + Vector2(6.0, 8.0), LxPalette.PAL["mauve"], 1)
		LxPixelFont.draw_left(self, LxStrings.text("MAP_LOCKED"), box.position + Vector2(6.0, 18.0), LxPalette.PAL["coral"], 1)
		return
	var isl_name: String = LxStrings.sanitize(str(data.get("name", "")), 22)
	var title: String = LxStrings.fmt("MAP_ISLAND_FMT", [_selected_island, isl_name])
	LxPixelFont.draw_left(self, title, box.position + Vector2(6.0, 6.0), LxPalette.PAL["gold"], 1)
	if Lx.state != null and Lx.state.island_id == _selected_island:
		LxPixelFont.draw_right(self, LxStrings.text("MAP_CURRENT"), box.end.x - 6.0, box.position.y + 6.0, LxPalette.PAL["cream"], 1)

	var beacons: int = _count_beacons(_selected_island)
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_BEACONS", [beacons]), box.position + Vector2(6.0, 16.0), LxPalette.PAL["cream"], 1)

	var boss_id: String = str(data.get("boss", ""))
	var boss_done: bool = Lx.state != null and Lx.state.defeated_bosses.has(boss_id)
	var d_line: String = LxStrings.text("MAP_DUNGEON_CLEAR") if boss_done else (LxStrings.fmt("MAP_DUNGEON", [LxStrings.sanitize(str(data.get("dungeon_name", "")), 18)]) if beacons >= 3 else LxStrings.text("MAP_DUNGEON_SEALED"))
	LxPixelFont.draw_left(self, d_line, box.position + Vector2(6.0, 26.0), LxPalette.PAL["lime"] if boss_done else LxPalette.PAL["apricot"], 1)

	var embers: int = Lx.state.ember_pieces if Lx.state != null else 0
	var secrets: int = Lx.state.claimed_shrines.size() if Lx.state != null else 0
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_EMBERS", [embers]), box.position + Vector2(6.0, 38.0), LxPalette.PAL["stone"], 1)
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_SECRETS", [secrets]), box.position + Vector2(74.0, 38.0), LxPalette.PAL["stone"], 1)


func _draw_waystones(box: Rect2) -> void:
	LxPixelFont.draw_panel(self, box, "dusk", "mauve", "night")
	LxPixelFont.draw_left(self, LxStrings.text("MAP_WAYSTONES"), box.position + Vector2(6.0, 6.0), LxPalette.PAL["sky"], 1)
	if _waystone_list.is_empty():
		LxPixelFont.draw_left(self, LxStrings.text("MAP_NO_WAYSTONES"), box.position + Vector2(6.0, 20.0), LxPalette.PAL["mauve"], 1)
		return
	var vis_count: int = mini(_waystone_list.size(), 3)
	for i: int in range(vis_count):
		var item: Dictionary = _waystone_list[i]
		var r: Rect2 = _ws_row_rect(i)
		var sel: bool = i == _waystone_idx
		if sel:
			draw_rect(r, LxPalette.PAL["plum"])
		draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(3.0, 5.0)), LxPalette.PAL["sky"] if sel else LxPalette.PAL["blue"])
		LxPixelFont.draw_left(self, str(item["label"]), r.position + Vector2(8.0, 2.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)
	LxPixelFont.draw_left(self, LxStrings.text("MAP_TRAVEL_PROMPT"), box.position + Vector2(6.0, 48.0), LxPalette.PAL["stone"], 1)


func _ws_row_rect(i: int) -> Rect2:
	return Rect2(174.0, 112.0 + float(i) * 10.0, 122.0, 9.0)


func _is_island_explored(isl_id: int) -> bool:
	if Lx.state == null:
		return isl_id == 1
	if Lx.state.island_id == isl_id or Lx.state.relit_islands.has(isl_id):
		return true
	var prefix: String = "%d:" % isl_id
	for vr: String in Lx.state.visited_regions:
		if vr.begins_with(prefix):
			return true
	return false


func _count_beacons(isl_id: int) -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	var p1: String = "isl%d_" % isl_id
	var p2: String = "%d:" % isl_id
	for b: String in Lx.state.lit_beacons:
		if b.begins_with(p1) or b.begins_with(p2) or (isl_id == 1 and b.begins_with("beacon_")):
			count += 1
	return mini(count, 3)


func _waystone_island(ws_id: String) -> int:
	for n: int in range(1, 9):
		if ws_id.begins_with("isl%d_" % n) or ws_id.begins_with("%d:" % n):
			return n
	return 1


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
