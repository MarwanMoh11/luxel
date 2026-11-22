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
const PLINTH_TOP: Array[String] = ["jade", "teal", "jade", "teal", "blue", "plum", "sky", "dusk"]
const PLINTH_RIM: Array[String] = ["pine", "pine", "pine", "jade", "deep", "wine", "blue", "plum"]

const DUNGEON_NAME_KEYS: Dictionary = {
	1: "ZONE_BELFRY",
	2: "DUNGEON_2_NAME",
	3: "DUNGEON_3_NAME",
	4: "DUNGEON_4_NAME",
	5: "DUNGEON_5_NAME",
	6: "DUNGEON_6_NAME",
	7: "DUNGEON_7_NAME",
	8: "DUNGEON_8_NAME",
}

const ISLAND_ZONE_KEYS: Dictionary = {
	1: ["ZONE_PLAZA", "ZONE_ORCHARD", "ZONE_OBSERVATORY", "ZONE_GLASSHOUSE", "ZONE_BRIDGE", "ZONE_BELL_TOWER"],
	2: ["ZONE_ISL2_1", "ZONE_ISL2_2", "ZONE_ISL2_3", "ZONE_ISL2_4", "ZONE_ISL2_5", "ZONE_ISL2_6"],
	3: ["ZONE_ISL3_1", "ZONE_ISL3_2", "ZONE_ISL3_3", "ZONE_ISL3_4", "ZONE_ISL3_5", "ZONE_ISL3_6"],
	4: ["ZONE_ISL4_1", "ZONE_ISL4_2", "ZONE_ISL4_3", "ZONE_ISL4_4", "ZONE_ISL4_5", "ZONE_ISL4_6"],
	5: ["ZONE_ISL5_1", "ZONE_ISL5_2", "ZONE_ISL5_3", "ZONE_ISL5_4", "ZONE_ISL5_5", "ZONE_ISL5_6"],
	6: ["ZONE_ISL6_1", "ZONE_ISL6_2", "ZONE_ISL6_3", "ZONE_ISL6_4", "ZONE_ISL6_5", "ZONE_ISL6_6"],
	7: ["ZONE_ISL7_1", "ZONE_ISL7_2", "ZONE_ISL7_3", "ZONE_ISL7_4", "ZONE_ISL7_5", "ZONE_ISL7_6"],
	8: ["ZONE_ISL8_1", "ZONE_ISL8_2", "ZONE_ISL8_3", "ZONE_ISL8_4"],
}

var _selected_island: int = 1
var _hover_island: int = 0
var _waystone_idx: int = 0
var _waystone_list: Array[Dictionary] = [] # {island_id, waystone_id, label}
var _elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if Lx.data_islands.is_empty():
		Lx.load_all_data()
	_selected_island = Lx.state.island_id if Lx.state != null else 1
	_rebuild_waystones()
	_waystone_idx = 0; _elapsed = 0.0; visible = true
	_play_ui_sfx("menu_open")
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


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
				"label": _waystone_label(isl, ws),
			})
	if _waystone_list.is_empty():
		for ws: String in Lx.state.lit_waystones:
			var isl: int = _waystone_island(ws)
			_waystone_list.append({
				"island_id": isl,
				"waystone_id": ws,
				"label": _waystone_label(isl, ws),
			})
	_waystone_idx = clampi(_waystone_idx, 0, maxi(0, _waystone_list.size() - 1))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var mpos: Vector2 = (event as InputEventMouseMotion).position
		var next_hover: int = 0
		for i: int in range(ISLAND_POS.size()):
			if mpos.distance_to(ISLAND_POS[i]) <= 12.0:
				next_hover = i + 1
				break
		if next_hover != _hover_island:
			_hover_island = next_hover
			if next_hover > 0: _play_ui_sfx("ui_move")
			queue_redraw()
		var start_idx: int = maxi(0, _waystone_idx - 2)
		var vis_count: int = mini(_waystone_list.size() - start_idx, 3)
		for row: int in range(vis_count):
			if _ws_row_rect(row).has_point(mpos):
				if _waystone_idx != start_idx + row:
					_waystone_idx = start_idx + row
					_play_ui_sfx("ui_move")
					queue_redraw()
				return
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
		_play_ui_sfx("menu_close")
		closed.emit()
		get_viewport().set_input_as_handled()


func _handle_click(pos: Vector2) -> bool:
	for i: int in range(ISLAND_POS.size()):
		if pos.distance_to(ISLAND_POS[i]) <= 12.0:
			_selected_island = i + 1
			_waystone_idx = 0
			_rebuild_waystones()
			_play_ui_sfx("ui_move")
			queue_redraw()
			return true
	var start_idx: int = maxi(0, _waystone_idx - 2)
	var vis_count: int = mini(_waystone_list.size() - start_idx, 3)
	for row: int in range(vis_count):
		if _ws_row_rect(row).has_point(pos):
			var idx: int = start_idx + row
			_waystone_idx = idx
			var item: Dictionary = _waystone_list[idx]
			_play_ui_sfx("ui_confirm")
			fast_travel_requested.emit(int(item["island_id"]), str(item["waystone_id"]))
			return true
	return false


func _draw() -> void:
	LxPixelFont.draw_panel(self, PANEL_RECT, "void", "mauve", "night")
	LxPixelFont.draw_centered(self, LxStrings.text("MAP_TITLE"), 160.0, 16.0, LxPalette.PAL["gold"], 1)

	# Illustrated nautical / astronomical Archipelago Sky-Chart.
	var chart := Rect2(20.0, 26.0, 280.0, 66.0)
	_draw_chart_backdrop(chart)
	_draw_bridges()
	_draw_islands()

	# Lower left: island details. Lower right: Waystone fast travel.
	_draw_island_info(Rect2(20.0, 96.0, 146.0, 58.0))
	_draw_waystones(Rect2(170.0, 96.0, 130.0, 58.0))

	LxPixelFont.draw_centered(self, LxStrings.text("MAP_HINT"), 160.0, 160.0, LxPalette.PAL["stone"], 1)


func _draw_chart_backdrop(chart: Rect2) -> void:
	LxPixelFont.draw_panel(self, chart, "night", "dusk", "void")
	# Brass corner rivets on chart frame.
	for corner: Vector2 in [
		chart.position + Vector2(1.0, 1.0),
		Vector2(chart.end.x - 3.0, chart.position.y + 1.0),
		Vector2(chart.position.x + 1.0, chart.end.y - 3.0),
		chart.end - Vector2(3.0, 3.0),
	]:
		draw_rect(Rect2(corner, Vector2(2.0, 2.0)), LxPalette.PAL["gold"])

	# Deep sky-to-sea chart bands inside inner rect (22..298, 28..90).
	draw_rect(Rect2(22.0, 28.0, 276.0, 14.0), LxPalette.PAL["void"])
	draw_rect(Rect2(22.0, 74.0, 276.0, 16.0), LxPalette.PAL["deep"])
	var dx: float = 22.0
	while dx < 296.0:
		draw_rect(Rect2(dx, 42.0, 2.0, 1.0), LxPalette.PAL["void"])
		draw_rect(Rect2(dx + 2.0, 73.0, 2.0, 1.0), LxPalette.PAL["deep"])
		dx += 6.0

	# Faint dusk latitude / longitude border ticks & interior crosshairs.
	var dusk: Color = LxPalette.PAL["dusk"]
	var gx: float = 36.0
	while gx <= 284.0:
		draw_rect(Rect2(gx, 28.0, 1.0, 2.0), dusk)
		draw_rect(Rect2(gx, 88.0, 1.0, 2.0), dusk)
		gx += 16.0
	for gy: float in [38.0, 50.0, 62.0, 74.0]:
		draw_rect(Rect2(22.0, gy, 2.0, 1.0), dusk)
		draw_rect(Rect2(296.0, gy, 2.0, 1.0), dusk)
	for mx: float in [60.0, 124.0, 188.0, 252.0]:
		for my: float in [44.0, 66.0]:
			draw_rect(Rect2(mx - 1.0, my, 3.0, 1.0), dusk)
			draw_rect(Rect2(mx, my - 1.0, 1.0, 3.0), dusk)

	# Subtle chart stars twinkling gently.
	for s: int in range(18):
		var sx: float = 26.0 + float((s * 47 + 13) % 268)
		var sy: float = 30.0 + float((s * 19 + 5) % 44)
		if sx < 38.0 and sy > 70.0:
			continue
		var phase: float = fmod(_elapsed + float(s) * 0.41, 2.4 + float(s % 3) * 0.6)
		var scol: Color = (LxPalette.PAL["ice"] if s % 3 == 0 else LxPalette.PAL["stone"]) if phase < 0.45 else (LxPalette.PAL["mauve"] if s % 2 == 0 else dusk)
		draw_rect(Rect2(sx, sy, 1.0, 1.0), scol)

	# Calm sea-chart wave dashes near lower rim.
	for w: int in range(6):
		var wx: float = 54.0 + float(w) * 42.0 + roundf(sin(_elapsed * 0.8 + float(w)) * 2.0)
		var wy: float = 84.0 + float(w % 2) * 3.0
		draw_rect(Rect2(wx, wy, 5.0, 1.0), dusk)

	_draw_compass_rose(Vector2(29.0, 82.0))


func _px(c: Vector2, rects: Array, col: Color) -> void:
	for r: Array in rects:
		draw_rect(Rect2(roundf(c.x + float(r[0])), roundf(c.y + float(r[1])), float(r[2]), float(r[3])), col)


func _draw_compass_rose(c: Vector2) -> void:
	var dusk: Color = LxPalette.PAL["dusk"]
	var apr: Color = LxPalette.PAL["apricot"]
	var gold: Color = LxPalette.PAL["gold"]
	var cream: Color = LxPalette.PAL["cream"]
	_px(c, [[-3, -2, 1, 1], [3, -2, 1, 1], [-3, 2, 1, 1], [3, 2, 1, 1], [-2, -3, 1, 1], [2, -3, 1, 1], [-2, 3, 1, 1], [2, 3, 1, 1], [-2, -2, 1, 1], [2, -2, 1, 1], [-2, 2, 1, 1], [2, 2, 1, 1]], dusk)
	_px(c, [[-1, -1, 1, 1], [1, -1, 1, 1], [-1, 1, 1, 1], [1, 1, 1, 1], [-4, 0, 9, 1], [0, 1, 1, 4]], apr)
	_px(c, [[-2, 0, 5, 1], [0, 1, 1, 2], [0, -4, 1, 4]], gold)
	draw_rect(Rect2(c.x, c.y - 5.0, 1.0, 2.0), cream if fmod(_elapsed, 2.0) < 1.2 else gold)
	draw_rect(Rect2(c.x, c.y, 1.0, 1.0), cream)


func _draw_bridges() -> void:
	if Lx.state == null:
		return
	for i: int in range(ISLAND_POS.size() - 1):
		var a: Vector2 = ISLAND_POS[i]
		var b: Vector2 = ISLAND_POS[i + 1]
		var open_bridge: bool = Lx.state.relit_islands.has(i + 1)
		for s: int in range(1, 8):
			var p: Vector2 = a.lerp(b, float(s) / 8.0).round()
			if open_bridge:
				draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), LxPalette.PAL["night"])
				draw_rect(Rect2(p, Vector2(2.0, 2.0)), LxPalette.PAL["gold"] if (s + floori(_elapsed * 3.2)) % 3 == 0 else LxPalette.PAL["apricot"])
			else:
				draw_rect(Rect2(p, Vector2(2.0, 1.0)), LxPalette.PAL["dusk"])
		if open_bridge:
			var t: float = fmod(_elapsed * 0.55 + float(i) * 0.21, 1.0)
			draw_rect(Rect2(a.lerp(b, clampf(t - 0.11, 0.08, 0.92)).round(), Vector2(1.0, 1.0)), LxPalette.PAL["apricot"])
			draw_rect(Rect2(a.lerp(b, clampf(t - 0.05, 0.08, 0.92)).round(), Vector2(2.0, 2.0)), LxPalette.PAL["gold"])
			var hp: Vector2 = a.lerp(b, clampf(t, 0.08, 0.92)).round()
			draw_rect(Rect2(hp + Vector2(-1.0, 0.0), Vector2(4.0, 2.0)), LxPalette.PAL["gold"])
			draw_rect(Rect2(hp, Vector2(2.0, 2.0)), LxPalette.PAL["cream"])


func _draw_islands() -> void:
	for i: int in range(ISLAND_POS.size()):
		var isl_id: int = i + 1
		var c: Vector2 = ISLAND_POS[i]
		var explored: bool = _is_island_explored(isl_id)
		var relit: bool = Lx.state != null and Lx.state.relit_islands.has(isl_id)
		var is_cur: bool = Lx.state != null and Lx.state.island_id == isl_id
		var is_sel: bool = isl_id == _selected_island

		if not explored:
			_draw_unexplored_island(c, isl_id)
		else:
			_draw_island_plinth(c, isl_id, relit)
			_draw_island_landmark(c, isl_id, relit)
			if relit:
				_draw_relit_sparkle(c + Vector2(0.0, -14.0), isl_id)
			if is_cur:
				_draw_wick_pip(c + Vector2(-9.0, -9.0 + roundf(sin(_elapsed * 3.8) * 1.5)))
		if is_sel:
			_draw_selection_brackets(c, false)
		elif isl_id == _hover_island:
			_draw_selection_brackets(c, true)

		var num_col: Color = LxPalette.PAL["gold"] if is_sel else (LxPalette.PAL["cream"] if explored else LxPalette.PAL["mauve"])
		LxPixelFont.draw_centered(self, str(isl_id), c.x, c.y + 8.0, num_col, 1)


func _draw_unexplored_island(c: Vector2, isl_id: int) -> void:
	_px(c, [[-6, -2, 12, 3], [-4, -4, 8, 2]], LxPalette.PAL["dusk"])
	_px(c, [[-2, -6, 4, 2], [-7, 0, 14, 2], [-5, 2, 10, 2], [-2, 4, 4, 1]], LxPalette.PAL["night"])
	for k: int in range(3):
		var fx: float = roundf(c.x - 5.0 + float(k) * 5.0 + sin(_elapsed * 1.1 + float(isl_id) + float(k) * 2.0) * 1.5)
		draw_rect(Rect2(fx, c.y - 3.0 - float(k % 2) * 2.0, 1.0, 1.0), LxPalette.PAL["mauve"])


func _draw_island_plinth(c: Vector2, isl_id: int, relit: bool) -> void:
	_px(c, [[-7, 1, 14, 2], [-5, 3, 10, 1], [-3, 4, 6, 1], [-1, 5, 2, 1]], LxPalette.PAL["night"])
	_px(c, [[-5, 1, 10, 1], [-3, 2, 3, 1]], LxPalette.PAL["dusk"])
	draw_rect(Rect2(c.x - 7.0, c.y - 1.0, 14.0, 2.0), LxPalette.color(PLINTH_RIM[isl_id - 1]))
	draw_rect(Rect2(c.x - 6.0, c.y - 2.0, 12.0, 2.0), LxPalette.color(PLINTH_TOP[isl_id - 1]))
	if relit:
		draw_rect(Rect2(c.x - 6.0, c.y - 2.0, 5.0, 1.0), LxPalette.PAL["gold"])


func _draw_island_landmark(c: Vector2, isl_id: int, relit: bool) -> void:
	match isl_id:
		1: # Bell Isle: peaked Bell Tower belfry + gold bell dot.
			_px(c, [[-2, -8, 5, 6]], LxPalette.PAL["stone"])
			_px(c, [[1, -8, 2, 6]], LxPalette.PAL["mauve"])
			_px(c, [[-1, -7, 3, 3], [-1, -11, 3, 1]], LxPalette.PAL["night"])
			_px(c, [[-3, -9, 7, 1], [-2, -10, 5, 1]], LxPalette.PAL["plum"])
			_px(c, [[0, -12, 1, 1]], LxPalette.PAL["gold"])
			_px(c, [[0, -6, 1, 2]], LxPalette.PAL["cream"] if relit else LxPalette.PAL["gold"])
		2: # Tidewater Harbor: striped coastal Lighthouse spire + beacon glint.
			_px(c, [[-2, -8, 4, 6]], LxPalette.PAL["cream"])
			_px(c, [[-2, -7, 4, 1], [-2, -4, 4, 1]], LxPalette.PAL["coral"])
			_px(c, [[1, -8, 1, 6]], LxPalette.PAL["stone"])
			_px(c, [[-3, -9, 6, 1]], LxPalette.PAL["dusk"])
			_px(c, [[-1, -12, 2, 1]], LxPalette.PAL["night"])
			var lit: bool = fmod(_elapsed, 1.6) < 0.9
			_px(c, [[-1, -11, 2, 2]], LxPalette.PAL["cream"] if lit else LxPalette.PAL["gold"])
			if lit:
				_px(c, [[-3, -10, 1, 1], [2, -10, 1, 1]], LxPalette.PAL["gold"])
		3: # Thornwood Hollow: domed ancient Hollow Oak canopy (jade/pine).
			_px(c, [[-2, -5, 4, 3]], LxPalette.PAL["dusk"])
			_px(c, [[0, -4, 1, 2]], LxPalette.PAL["apricot"])
			_px(c, [[-5, -8, 10, 3]], LxPalette.PAL["pine"])
			_px(c, [[-5, -9, 10, 2]], LxPalette.PAL["teal"])
			_px(c, [[-4, -10, 8, 2]], LxPalette.PAL["jade"])
			_px(c, [[-2, -11, 4, 1], [-4, -9, 2, 1]], LxPalette.PAL["lime"])
		4: # Mirefen Gardens: arched pale glasshouse conservatory dome (ice/sky).
			_px(c, [[-5, -3, 10, 1]], LxPalette.PAL["mauve"])
			_px(c, [[-5, -6, 10, 3]], LxPalette.PAL["sky"])
			_px(c, [[-4, -8, 8, 2], [-2, -9, 4, 1]], LxPalette.PAL["ice"])
			_px(c, [[-2, -7, 1, 4], [2, -7, 1, 4]], LxPalette.PAL["blue"])
			_px(c, [[-3, -8, 2, 1], [0, -10, 1, 1]], LxPalette.PAL["cream"])
		5: # Starfall Observatory: crossed brass Orrery / telescope dome (gold/blue).
			_px(c, [[-4, -6, 8, 4]], LxPalette.PAL["blue"])
			_px(c, [[-3, -7, 6, 1]], LxPalette.PAL["sky"])
			_px(c, [[1, -6, 3, 4]], LxPalette.PAL["deep"])
			for d: int in range(-3, 4):
				draw_rect(Rect2(c.x + float(d), roundf(c.y - 8.0 - float(d) * 0.5), 1.0, 1.0), LxPalette.PAL["gold"])
				draw_rect(Rect2(c.x + float(d), roundf(c.y - 8.0 + float(d) * 0.5), 1.0, 1.0), LxPalette.PAL["apricot"])
			_px(c, [[0, -11, 1, 2]], LxPalette.PAL["cream"])
		6: # Ashen Kiln: smoking volcanic forge chimney (coral/apricot ember glow).
			_px(c, [[-3, -7, 6, 5]], LxPalette.PAL["dusk"])
			_px(c, [[-2, -9, 4, 2]], LxPalette.PAL["night"])
			_px(c, [[-3, -9, 6, 1]], LxPalette.PAL["wine"])
			_px(c, [[-1, -4, 2, 2]], LxPalette.PAL["apricot"] if fmod(_elapsed * 2.2, 1.0) < 0.5 else LxPalette.PAL["coral"])
			_px(c, [[0, -3, 1, 1]], LxPalette.PAL["gold"])
			var puff: float = floorf(fmod(_elapsed * 2.5, 3.0))
			draw_rect(Rect2(roundf(c.x - 1.0 + puff * 0.5), c.y - 10.0 - puff, 1.0, 1.0), LxPalette.PAL["coral"])
			draw_rect(Rect2(c.x + 1.0, c.y - 11.0 - fmod(puff + 1.0, 3.0), 1.0, 1.0), LxPalette.PAL["mauve"])
		7: # Moon Shoals: slender crescent Moon Mirror Spire (ice/cream).
			_px(c, [[-3, -3, 6, 1]], LxPalette.PAL["blue"])
			_px(c, [[-1, -8, 2, 5], [1, -11, 1, 1]], LxPalette.PAL["sky"])
			_px(c, [[-1, -8, 1, 5], [-1, -9, 2, 1]], LxPalette.PAL["ice"])
			_px(c, [[-2, -11, 1, 3], [-1, -12, 2, 1]], LxPalette.PAL["cream"])
		8: # The Long Night: twin-spired eclipsed cathedral arch (plum/rose/cream).
			_px(c, [[-5, -10, 2, 8], [3, -10, 2, 8]], LxPalette.PAL["plum"])
			_px(c, [[-5, -11, 1, 2], [4, -11, 1, 2], [-2, -10, 4, 4]], LxPalette.PAL["rose"])
			_px(c, [[-3, -5, 6, 3]], LxPalette.PAL["dusk"])
			_px(c, [[-1, -4, 2, 2]], LxPalette.PAL["night"])
			_px(c, [[-1, -10, 2, 1]], LxPalette.PAL["cream"])
			_px(c, [[-1, -9, 2, 2]], LxPalette.PAL["void"])


func _draw_relit_sparkle(p: Vector2, isl_id: int) -> void:
	var sp := Vector2(roundf(p.x), maxf(29.0, roundf(p.y)))
	if fmod(_elapsed * 1.8 + float(isl_id) * 0.37, 1.2) < 0.6:
		_px(sp, [[-1, 0, 1, 1], [1, 0, 1, 1], [0, -1, 1, 1], [0, 1, 1, 1]], LxPalette.PAL["gold"])
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), LxPalette.PAL["cream"])
	else:
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), LxPalette.PAL["gold"])


func _draw_wick_pip(p: Vector2) -> void:
	var wp := Vector2(roundf(p.x), maxf(30.0, roundf(p.y)))
	var flk: bool = fmod(_elapsed * 3.0, 1.0) < 0.55
	draw_rect(Rect2(wp, Vector2(5.0, 6.0)), LxPalette.PAL["night"])
	_px(wp, [[1, 0, 3, 1], [1, 5, 3, 1]], LxPalette.PAL["apricot"])
	_px(wp, [[1, 1, 3, 4]], LxPalette.PAL["gold"] if flk else LxPalette.PAL["apricot"])
	_px(wp, [[2, 2, 1, 2]], LxPalette.PAL["cream"])


func _draw_selection_brackets(c: Vector2, is_hover: bool = false) -> void:
	var pulse: bool = not is_hover and fmod(_elapsed, 1.1) < 0.55
	var ex: float = 1.0 if pulse else 0.0
	var col: Color = LxPalette.PAL["sky"] if is_hover else (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"])
	var l: float = roundf(c.x - 10.0 - ex)
	var r: float = roundf(c.x + 10.0 + ex)
	var t: float = maxf(29.0, roundf(c.y - 13.0 - ex))
	var b: float = minf(88.0, roundf(c.y + 6.0 + ex))
	_px(Vector2.ZERO, [[l, t, 3, 1], [l, t, 1, 3], [r - 2, t, 3, 1], [r, t, 1, 3], [l, b, 3, 1], [l, b - 2, 1, 3], [r - 2, b, 3, 1], [r, b - 2, 1, 3]], col)


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
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_BEACONS", [beacons]), box.position + Vector2(6.0, 15.0), LxPalette.PAL["cream"], 1)
	for bk: int in range(3):
		var bx: float = box.end.x - 24.0 + float(bk) * 6.0
		var lit_b: bool = bk < beacons
		draw_rect(Rect2(bx, box.position.y + 15.0, 4.0, 4.0), LxPalette.PAL["gold" if lit_b else "night"])
		draw_rect(Rect2(bx + 1.0, box.position.y + 16.0, 2.0, 2.0), LxPalette.PAL["cream" if lit_b else "mauve"])

	var boss_id: String = str(data.get("boss", ""))
	var boss_done: bool = Lx.state != null and Lx.state.defeated_bosses.has(boss_id)
	var dungeon_label: String = _get_dungeon_name(_selected_island, data)
	var d_line: String = LxStrings.text("MAP_DUNGEON_CLEAR") if boss_done else (LxStrings.fmt("MAP_DUNGEON", [dungeon_label]) if beacons >= 3 else LxStrings.text("MAP_DUNGEON_SEALED"))
	LxPixelFont.draw_left(self, d_line, box.position + Vector2(6.0, 24.0), LxPalette.PAL["lime"] if boss_done else LxPalette.PAL["apricot"], 1)

	var zone_label: String = _primary_zone_label(_selected_island)
	if not zone_label.is_empty():
		LxPixelFont.draw_left(self, zone_label, box.position + Vector2(6.0, 33.0), LxPalette.PAL["sky"], 1)

	var embers: int = Lx.state.ember_pieces if Lx.state != null else 0
	var secrets: int = Lx.state.claimed_shrines.size() if Lx.state != null else 0
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_EMBERS", [embers]), box.position + Vector2(6.0, 44.0), LxPalette.PAL["stone"], 1)
	LxPixelFont.draw_left(self, LxStrings.fmt("MAP_SECRETS", [secrets]), box.position + Vector2(74.0, 44.0), LxPalette.PAL["stone"], 1)


func _draw_waystones(box: Rect2) -> void:
	LxPixelFont.draw_panel(self, box, "dusk", "mauve", "night")
	LxPixelFont.draw_left(self, LxStrings.text("MAP_WAYSTONES"), box.position + Vector2(6.0, 6.0), LxPalette.PAL["sky"], 1)
	if _waystone_list.is_empty():
		LxPixelFont.draw_left(self, LxStrings.text("MAP_NO_WAYSTONES"), box.position + Vector2(6.0, 20.0), LxPalette.PAL["mauve"], 1)
		return
	var start_idx: int = maxi(0, _waystone_idx - 2)
	var vis_count: int = mini(_waystone_list.size() - start_idx, 3)
	for row: int in range(vis_count):
		var idx: int = start_idx + row
		var item: Dictionary = _waystone_list[idx]
		var r: Rect2 = _ws_row_rect(row)
		var sel: bool = idx == _waystone_idx
		if sel:
			draw_rect(r, LxPalette.PAL["plum"])
		draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(3.0, 5.0)), LxPalette.PAL["sky"] if sel else LxPalette.PAL["blue"])
		LxPixelFont.draw_left(self, str(item["label"]), r.position + Vector2(8.0, 2.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)
	LxPixelFont.draw_left(self, LxStrings.text("MAP_TRAVEL_PROMPT"), box.position + Vector2(6.0, 48.0), LxPalette.PAL["stone"], 1)


func _ws_row_rect(i: int) -> Rect2:
	return Rect2(174.0, 112.0 + float(i) * 10.0, 122.0, 9.0)


func _get_dungeon_name(isl_id: int, data: Dictionary) -> String:
	var key: String = str(DUNGEON_NAME_KEYS.get(isl_id, ""))
	if not key.is_empty() and LxStrings.has_id(key):
		return LxStrings.text(key)
	return LxStrings.sanitize(str(data.get("dungeon_name", "")), 20)


func _primary_zone_label(isl_id: int) -> String:
	var zones: Array = ISLAND_ZONE_KEYS.get(isl_id, []) as Array
	if zones.is_empty():
		return ""
	var key: String = str(zones[0])
	return LxStrings.text(key) if LxStrings.has_id(key) else ""


func _waystone_label(isl_id: int, ws_id: String) -> String:
	if LxStrings.has_id(ws_id):
		return LxStrings.text(ws_id).substr(0, 18)
	var low: String = ws_id.to_lower()
	var zones: Array = ISLAND_ZONE_KEYS.get(isl_id, []) as Array
	if isl_id == 1:
		if low.contains("plaza"):
			return LxStrings.text("ZONE_PLAZA").substr(0, 18)
		if low.contains("orchard"):
			return LxStrings.text("ZONE_ORCHARD").substr(0, 18)
		if low.contains("observatory"):
			return LxStrings.text("ZONE_OBSERVATORY").substr(0, 18)
		if low.contains("glasshouse"):
			return LxStrings.text("ZONE_GLASSHOUSE").substr(0, 18)
		if low.contains("bridge"):
			return LxStrings.text("ZONE_BRIDGE").substr(0, 18)
		if low.contains("tower") or low.contains("bell"):
			return LxStrings.text("ZONE_BELL_TOWER").substr(0, 18)
	for z_idx: int in range(zones.size()):
		var num: String = str(z_idx + 1)
		if low.ends_with("_" + num) or low.contains("_z" + num) or low.contains("_zone" + num):
			return LxStrings.text(str(zones[z_idx])).substr(0, 18)
	if not zones.is_empty() and (low.contains("entry") or low.contains("landing") or low.contains("hub") or low.contains("quay") or low.contains("gate")):
		return LxStrings.text(str(zones[0])).substr(0, 18)
	var loc: Dictionary = LxMapFormat.find_waystone(isl_id, ws_id)
	if not loc.is_empty() and str(loc.get("region", "overworld")) != "overworld":
		var dkey: String = str(DUNGEON_NAME_KEYS.get(isl_id, ""))
		if not dkey.is_empty() and LxStrings.has_id(dkey):
			return LxStrings.text(dkey).substr(0, 18)
	var clean_id: String = low
	if clean_id.begins_with("ws_"):
		clean_id = clean_id.substr(3)
	if clean_id.length() >= 2 and clean_id[0] >= "1" and clean_id[0] <= "8" and clean_id[1] == "_":
		clean_id = clean_id.substr(2)
	return LxStrings.sanitize(clean_id, 18)


func _is_island_explored(isl_id: int) -> bool:
	if Lx.state == null:
		return isl_id == 1
	if Lx.state.island_id == isl_id or Lx.state.relit_islands.has(isl_id):
		return true
	var prefix: String = "%d:" % isl_id
	for vr: String in Lx.state.visited_regions:
		if vr.begins_with(prefix):
			return true
	for ws: String in Lx.state.lit_waystones:
		if _waystone_island(ws) == isl_id:
			return true
	return false


func _count_beacons(isl_id: int) -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	var p1: String = "isl%d_" % isl_id
	var p2: String = "%d:" % isl_id
	var p3: String = "beacon_%d_" % isl_id
	var p4: String = "beacon_isl%d_" % isl_id
	for b: String in Lx.state.lit_beacons:
		if b.begins_with(p1) or b.begins_with(p2) or b.begins_with(p3) or b.begins_with(p4) or (isl_id == 1 and b in ["beacon_orchard", "beacon_observatory", "beacon_bridge"]):
			count += 1
	return mini(count, 3)


func _waystone_island(ws_id: String) -> int:
	var found: Dictionary = LxMapFormat.find_waystone_any(ws_id)
	if not found.is_empty():
		return int(found.get("island", 1))
	var low: String = ws_id.to_lower()
	for n: int in range(1, 9):
		if low.begins_with("isl%d_" % n) or low.begins_with("ws_isl%d" % n) or low.begins_with("island%d_" % n) or low.begins_with("island_%d_" % n) or low.begins_with("ws_%d_" % n) or low.begins_with("%d:" % n):
			return n
	return 1


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
