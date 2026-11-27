class_name LxMapScreen
extends Node2D
## Archipelago map and Waystone fast travel (SWARM_SPEC 3.8).
## Shows explored regions (unexplored stay dark), lit Waystones, Beacons, Dungeon icon,
## and ember/secret counts (counts only, never secret locations).

signal closed()
signal fast_travel_requested(island_id: int, waystone_id: String)

const HUB_POS := Vector2(32.0, 42.0)
const ISLAND_POS: Array[Vector2] = [
	Vector2(44.0, 74.0), Vector2(76.0, 56.0), Vector2(108.0, 80.0), Vector2(140.0, 58.0),
	Vector2(172.0, 78.0), Vector2(204.0, 54.0), Vector2(236.0, 76.0), Vector2(268.0, 58.0),
]

const PANEL_RECT := Rect2(12.0, 10.0, 296.0, 160.0)
const PLINTH_TOP: Array[String] = ["jade", "teal", "jade", "teal", "blue", "plum", "sky", "dusk"]
const PLINTH_RIM: Array[String] = ["pine", "pine", "pine", "jade", "deep", "wine", "blue", "plum"]

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

const WAYSTONE_LABEL_KEYS: Dictionary = {
	"ws_lighthouse_upper": "WS_LIGHTHOUSE_UPPER",
	"ws_oak_upper": "WS_OAK_UPPER",
}

enum View { ARCHIPELAGO, ISLAND, DUNGEON }

var _view: int = View.ARCHIPELAGO
var _selected_island: int = 1
var _selected_dungeon_idx: int = 0
var _island_dungeons: Array[Dictionary] = []
var _island_nodes: Array[Dictionary] = []
var _island_node_idx: int = 0
var _hover_island: int = -1
var _hover_tab: int = -1
var _waystone_idx: int = 0
var _ws_scroll: int = 0
var _ws_filter_island: int = -1 # -1 = ALL, 0 = HUB, 1..8 = island
var _waystone_list: Array[Dictionary] = [] # {island_id, waystone_id, label}
var _elapsed: float = 0.0

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS; visible = false
func close() -> void: visible = false

func open() -> void:
	if Lx.data_islands.is_empty(): Lx.load_all_data()
	_selected_island = Lx.state.island_id if Lx.state != null else 1
	_ws_filter_island = _selected_island
	_hover_tab = -1
	_rebuild_dungeons()
	_rebuild_island_nodes()
	_view = View.ISLAND
	if Lx.state != null and Lx.packs != null:
		var cur_did: String = Lx.packs.dungeon_of(Lx.state.island_id, Lx.state.region_id)
		if not cur_did.is_empty():
			for di: int in range(_island_dungeons.size()):
				if str(_island_dungeons[di].get("id", "")) == cur_did:
					_selected_dungeon_idx = di
					_view = View.DUNGEON
					break
	_waystone_idx = 0; _ws_scroll = 0; _rebuild_waystones()
	_elapsed = 0.0; visible = true
	_play_ui_sfx("map_open")
	queue_redraw()

func set_view(v: int) -> void:
	_view = clampi(v, View.ARCHIPELAGO, View.DUNGEON)
	_rebuild_dungeons()
	_rebuild_island_nodes()
	queue_redraw()

func select_island(isl: int) -> void:
	_select_island(clampi(isl, 0, 8))

func _rebuild_dungeons() -> void:
	_island_dungeons = LxMapInfo.get_island_dungeons(_selected_island)
	_selected_dungeon_idx = clampi(_selected_dungeon_idx, 0, maxi(0, _island_dungeons.size() - 1))

func _rebuild_island_nodes() -> void:
	_island_nodes = LxMapIsland.build_island_nodes(_selected_island)
	_island_node_idx = clampi(_island_node_idx, 0, maxi(0, _island_nodes.size() - 1))

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta; queue_redraw()


func _rebuild_waystones() -> void:
	_waystone_list.clear()
	if Lx.state == null: return
	if _ws_filter_island == 0:
		_waystone_list.append({"island_id": 0, "waystone_id": "ws_hub", "label": LxStrings.text("MAP_HUB_LABEL").substr(0, 18), "_canon": true})
	elif _ws_filter_island == -1:
		_waystone_list.append({"island_id": 0, "waystone_id": "ws_hub", "label": LxStrings.text("MAP_HUB_LABEL").substr(0, 18), "_canon": true})
		_collect_waystones(-1, true)
	else:
		_collect_waystones(_ws_filter_island, false)
	_waystone_idx = clampi(_waystone_idx, 0, maxi(0, _waystone_list.size() - 1))
	_sync_ws_scroll()

func _sync_ws_scroll() -> void:
	var max_s: int = maxi(0, _waystone_list.size() - LxMapInfo.WS_VISIBLE)
	if _waystone_idx < _ws_scroll: _ws_scroll = _waystone_idx
	elif _waystone_idx >= _ws_scroll + LxMapInfo.WS_VISIBLE: _ws_scroll = _waystone_idx - LxMapInfo.WS_VISIBLE + 1
	_ws_scroll = clampi(_ws_scroll, 0, max_s)

func _collect_waystones(filter_isl: int, use_prefix: bool) -> void:
	var seen: Dictionary = {}; var seen_ids: Dictionary = {}
	for ws: String in Lx.state.lit_waystones:
		if seen_ids.has(ws): continue
		seen_ids[ws] = true
		var isl: int = _waystone_island(ws)
		if filter_isl >= 0 and isl != filter_isl: continue
		if use_prefix and isl == 0 and ws == "ws_hub": continue
		var base_lbl: String = _waystone_label(isl, ws)
		var lbl: String = (LxStrings.text("MAP_HUB_LABEL").substr(0, 18) if isl == 0 else LxStrings.fmt("MAP_WS_ISL_FMT", [isl, base_lbl]).substr(0, 18)) if use_prefix else base_lbl
		var key: String = "%d:%s" % [isl, base_lbl]
		var canon: bool = not LxMapFormat.find_waystone(isl, ws).is_empty()
		var entry: Dictionary = {"island_id": isl, "waystone_id": ws, "label": lbl, "_canon": canon}
		if seen.has(key) and not (canon and bool(_waystone_list[int(seen[key])].get("_canon", false))):
			var prev_i: int = int(seen[key])
			if canon and not bool(_waystone_list[prev_i].get("_canon", false)): _waystone_list[prev_i] = entry
		else:
			seen[key] = _waystone_list.size(); _waystone_list.append(entry)

func _select_island(isl: int) -> void:
	_selected_island = isl; _ws_filter_island = isl
	_selected_dungeon_idx = 0; _island_node_idx = 0
	_rebuild_dungeons(); _rebuild_island_nodes()
	_waystone_idx = 0; _ws_scroll = 0; _rebuild_waystones()
	_play_ui_sfx("ui_move"); queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if LxUiNav.handle_tab_bar_key(event, 4):
		get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion:
		var mpos: Vector2 = (event as InputEventMouseMotion).position
		var next_tab: int = -1
		for vi: int in range(3):
			if _tab_rect(vi).has_point(mpos): next_tab = vi; break
		if next_tab != _hover_tab:
			_hover_tab = next_tab
			if next_tab >= 0: _play_ui_sfx("ui_move")
			queue_redraw()
		if _view == View.ISLAND:
			var hi: int = LxMapIsland.hit_test_node(_island_nodes, mpos)
			if hi >= 0 and hi != _island_node_idx:
				_island_node_idx = hi; _play_ui_sfx("ui_move"); queue_redraw()
			return
		if _view == View.ARCHIPELAGO:
			var next_hover: int = 0 if mpos.distance_to(HUB_POS) <= 10.0 else -1
			if next_hover < 0:
				for i: int in range(ISLAND_POS.size()):
					if mpos.distance_to(ISLAND_POS[i]) <= 12.0: next_hover = i + 1; break
			if next_hover != _hover_island:
				_hover_island = next_hover
				if next_hover >= 0: _play_ui_sfx("ui_move")
				queue_redraw()
			for row: int in range(mini(_waystone_list.size() - _ws_scroll, LxMapInfo.WS_VISIBLE)):
				if LxMapInfo.ws_row_rect(row).has_point(mpos):
					if _waystone_idx != _ws_scroll + row: _waystone_idx = _ws_scroll + row; _play_ui_sfx("ui_move"); queue_redraw()
					return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_click(mb.position): get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_ui_sfx("menu_close"); closed.emit(); get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _view == View.ARCHIPELAGO and not _waystone_list.is_empty():
				var step: int = -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				var max_s: int = maxi(0, _waystone_list.size() - LxMapInfo.WS_VISIBLE)
				if max_s > 0:
					var next_s: int = clampi(_ws_scroll + step, 0, max_s)
					if next_s != _ws_scroll:
						_ws_scroll = next_s; _waystone_idx = clampi(_waystone_idx, _ws_scroll, mini(_waystone_list.size() - 1, _ws_scroll + LxMapInfo.WS_VISIBLE - 1))
						_play_ui_sfx("ui_move"); queue_redraw()
				else:
					var next_i: int = clampi(_waystone_idx + step, 0, _waystone_list.size() - 1)
					if next_i != _waystone_idx: _waystone_idx = next_i; _play_ui_sfx("ui_move"); queue_redraw()
			get_viewport().set_input_as_handled()
		return
	if _key_just(event, KEY_Q) or _joy_btn(event, JOY_BUTTON_LEFT_SHOULDER):
		_step_view(-1); get_viewport().set_input_as_handled(); return
	if _key_just(event, KEY_E) or _joy_btn(event, JOY_BUTTON_RIGHT_SHOULDER):
		_step_view(1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_map") or _key_just(event, KEY_ESCAPE) or _key_just(event, KEY_TAB):
		_play_ui_sfx("menu_close"); closed.emit(); get_viewport().set_input_as_handled(); return
	if _view == View.ISLAND:
		_input_island_view(event); return
	if _view == View.DUNGEON:
		if event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
			if _island_dungeons.size() > 1: _selected_dungeon_idx = (_selected_dungeon_idx - 1 + _island_dungeons.size()) % _island_dungeons.size(); _play_ui_sfx("ui_move"); queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
			if _island_dungeons.size() > 1: _selected_dungeon_idx = (_selected_dungeon_idx + 1) % _island_dungeons.size(); _play_ui_sfx("ui_move"); queue_redraw()
			get_viewport().set_input_as_handled()
		elif _key_just(event, KEY_BRACKETLEFT) or _key_just(event, KEY_PAGEUP):
			_select_island(8 if _selected_island <= 0 else _selected_island - 1); get_viewport().set_input_as_handled()
		elif _key_just(event, KEY_BRACKETRIGHT) or _key_just(event, KEY_PAGEDOWN):
			_select_island(0 if _selected_island >= 8 else _selected_island + 1); get_viewport().set_input_as_handled()
		return
	if _key_just(event, KEY_F):
		_ws_filter_island = _selected_island if _ws_filter_island == -1 else -1
		_waystone_idx = 0; _ws_scroll = 0; _rebuild_waystones(); _play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
		_select_island(8 if _selected_island <= 0 else _selected_island - 1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
		_select_island(0 if _selected_island >= 8 else _selected_island + 1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		if not _waystone_list.is_empty(): _waystone_idx = (_waystone_idx - 1 + _waystone_list.size()) % _waystone_list.size(); _sync_ws_scroll(); _play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		if not _waystone_list.is_empty(): _waystone_idx = (_waystone_idx + 1) % _waystone_list.size(); _sync_ws_scroll(); _play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		if not _waystone_list.is_empty():
			var item: Dictionary = _waystone_list[_waystone_idx]
			_play_ui_sfx("ui_confirm"); fast_travel_requested.emit(int(item["island_id"]), str(item["waystone_id"]))
		else: _play_ui_sfx("denied")
		get_viewport().set_input_as_handled()

func _input_island_view(event: InputEvent) -> void:
	if _key_just(event, KEY_P) or _joy_btn(event, JOY_BUTTON_Y):
		if _island_node_idx >= 0 and _island_node_idx < _island_nodes.size():
			LxUiNav.toggle_pin(_island_nodes[_island_node_idx])
			_play_ui_sfx("ui_confirm"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_BRACKETLEFT) or _key_just(event, KEY_PAGEUP):
		_select_island(8 if _selected_island <= 0 else _selected_island - 1); get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_BRACKETRIGHT) or _key_just(event, KEY_PAGEDOWN):
		_select_island(0 if _selected_island >= 8 else _selected_island + 1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT) or event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		if not _island_nodes.is_empty():
			_island_node_idx = (_island_node_idx - 1 + _island_nodes.size()) % _island_nodes.size()
			_play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT) or event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		if not _island_nodes.is_empty():
			_island_node_idx = (_island_node_idx + 1) % _island_nodes.size()
			_play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate_island_node(); get_viewport().set_input_as_handled()

func _activate_island_node() -> void:
	if _island_node_idx < 0 or _island_node_idx >= _island_nodes.size():
		return
	var nd: Dictionary = _island_nodes[_island_node_idx]
	var k: String = str(nd.get("kind", ""))
	if k == "waystone" and str(nd.get("state", "")) == "open":
		var wid: String = str(nd.get("waystone_id", ""))
		if not wid.is_empty():
			_play_ui_sfx("ui_confirm"); fast_travel_requested.emit(_selected_island, wid)
			return
	if k in ["minor_dungeon", "set_piece", "grand_dungeon"]:
		var did: String = str(nd.get("dungeon_id", ""))
		for di: int in range(_island_dungeons.size()):
			if str(_island_dungeons[di].get("id", "")) == did:
				_selected_dungeon_idx = di; break
		_view = View.DUNGEON; _play_ui_sfx("ui_confirm"); queue_redraw()
		return
	LxUiNav.toggle_pin(nd); _play_ui_sfx("ui_confirm"); queue_redraw()

func _step_view(dir: int) -> void:
	_view = (_view + dir + 3) % 3
	_rebuild_dungeons(); _rebuild_island_nodes(); _play_ui_sfx("ui_move"); queue_redraw()

func _tab_rect(v_idx: int) -> Rect2:
	return Rect2(122.0 + float(v_idx) * 39.0, 13.0, 37.0, 11.0)

func _handle_click(pos: Vector2) -> bool:
	if LxUiNav.handle_tab_bar_click(pos, 4):
		return true
	for vi: int in range(3):
		if _tab_rect(vi).has_point(pos):
			if _view != vi: _view = vi; _rebuild_dungeons(); _rebuild_island_nodes(); _play_ui_sfx("ui_move"); queue_redraw()
			return true
	if _view == View.DUNGEON:
		var drect := Rect2(20.0, 26.0, 280.0, 128.0)
		if _island_dungeons.size() > 1:
			for di: int in range(_island_dungeons.size()):
				if LxMapDungeon.dungeon_pill_rect(drect, di, _island_dungeons.size()).has_point(pos):
					_selected_dungeon_idx = di; _play_ui_sfx("ui_move"); queue_redraw(); return true
		return false
	if _view == View.ISLAND:
		var hi: int = LxMapIsland.hit_test_node(_island_nodes, pos)
		if hi >= 0:
			if hi == _island_node_idx: _activate_island_node()
			else: _island_node_idx = hi; _play_ui_sfx("ui_move"); queue_redraw()
			return true
		if Rect2(168.0, 28.0, 28.0, 12.0).has_point(pos):
			_select_island(0 if _selected_island >= 8 else _selected_island + 1); return true
		return false
	# Archipelago view clicks: waystone island search filter pills
	for fv: int in range(-1, 9):
		if LxMapInfo.ws_filter_rect(fv).has_point(pos):
			_ws_filter_island = fv; _waystone_idx = 0; _ws_scroll = 0
			_rebuild_waystones(); _play_ui_sfx("ui_move"); queue_redraw()
			return true
	if pos.distance_to(HUB_POS) <= 10.0:
		if _selected_island == 0: set_view(View.ISLAND)
		else: _select_island(0)
		return true
	for i: int in range(ISLAND_POS.size()):
		if pos.distance_to(ISLAND_POS[i]) <= 12.0:
			if _selected_island == i + 1: set_view(View.ISLAND)
			else: _select_island(i + 1)
			return true
	for row: int in range(mini(_waystone_list.size() - _ws_scroll, LxMapInfo.WS_VISIBLE)):
		if LxMapInfo.ws_row_rect(row).has_point(pos):
			_waystone_idx = _ws_scroll + row
			var item: Dictionary = _waystone_list[_waystone_idx]
			_play_ui_sfx("ui_confirm"); fast_travel_requested.emit(int(item["island_id"]), str(item["waystone_id"]))
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(PANEL_RECT.position + Vector2(3.0, 3.0), PANEL_RECT.size), LxPalette.PAL["void"])
	draw_rect(PANEL_RECT.grow(1.0), LxPalette.PAL["void"])
	LxPixelFont.draw_panel(self, PANEL_RECT, "void", "mauve", "night")
	_draw_panel_brackets()
	_draw_header_legend()
	_draw_view_tabs()
	LxMapInfo.draw_header_progress(self, _elapsed)
	LxUiNav.draw_pause_tab_bar(self, 4)

	if _view == View.ISLAND:
		LxMapIsland.draw_island_page(self, _selected_island, _island_nodes, _island_node_idx, _elapsed)
		LxPixelFont.draw_centered(self, LxStrings.text("MAP_DUNGEON_HINT"), 160.0, 160.0, LxPalette.PAL["stone"], 1)
		return

	if _view == View.DUNGEON:
		var graph: Dictionary = {}
		if not _island_dungeons.is_empty():
			var d: Dictionary = _island_dungeons[clampi(_selected_dungeon_idx, 0, _island_dungeons.size() - 1)]
			graph = LxMapDungeon.build_graph(_selected_island, str(d.get("id", "")))
		LxMapDungeon.draw_dungeon_graph(self, Rect2(20.0, 26.0, 280.0, 128.0), graph, _elapsed, _island_dungeons, _selected_dungeon_idx)
		LxPixelFont.draw_centered(self, LxStrings.text("MAP_DUNGEON_HINT"), 160.0, 160.0, LxPalette.PAL["stone"], 1)
		return

	# Illustrated nautical / astronomical Archipelago Sky-Chart.
	var chart := Rect2(20.0, 26.0, 280.0, 66.0)
	_draw_chart_backdrop(chart)
	_draw_bridges()
	_draw_islands()

	# Lower left: island details. Lower right: Waystone fast travel with island search filter.
	LxMapInfo.draw_island_info(self, Rect2(20.0, 96.0, 146.0, 58.0), _selected_island, _is_island_explored(_selected_island))
	LxMapInfo.draw_waystones(self, Rect2(170.0, 96.0, 130.0, 58.0), _waystone_list, _waystone_idx, _ws_scroll, _elapsed, _ws_filter_island)

	LxPixelFont.draw_centered(self, LxStrings.text("MAP_HINT"), 160.0, 160.0, LxPalette.PAL["stone"], 1)

func _draw_view_tabs() -> void:
	var labels: Array[String] = [
		LxFolkData.tr_id("MAP_TAB_WORLD"),
		LxUiNav.tr_any("MAP_TAB_ISLAND", "MAP_ISLAND_FMT").substr(0, 6),
		LxFolkData.tr_id("MAP_TAB_DUNGEON").substr(0, 7),
	]
	for vi: int in range(3):
		var r: Rect2 = _tab_rect(vi)
		var active: bool = _view == vi
		var hov: bool = (not active) and _hover_tab == vi
		LxPixelFont.draw_panel(self, r, "plum" if active else "night", "gold" if active else ("sky" if hov else "dusk"), "void")
		LxPixelFont.draw_centered(self, labels[vi], r.get_center().x, r.position.y + 3.0, LxPalette.PAL["gold"] if active else (LxPalette.PAL["ice"] if hov else LxPalette.PAL["stone"]), 1)

func _draw_panel_brackets() -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var night: Color = LxPalette.PAL["night"]
	for c: Array in [[p.x + 1.0, p.y + 1.0, 1.0, 1.0], [e.x - 2.0, p.y + 1.0, -1.0, 1.0], [p.x + 1.0, e.y - 2.0, 1.0, -1.0], [e.x - 2.0, e.y - 2.0, -1.0, -1.0]]:
		var cx: float = float(c[0]); var cy: float = float(c[1]); var sx: float = float(c[2]); var sy: float = float(c[3])
		draw_rect(Rect2(cx if sx > 0.0 else cx - 5.0, cy, 6.0, 1.0), apr)
		draw_rect(Rect2(cx, cy if sy > 0.0 else cy - 5.0, 1.0, 6.0), apr)
		draw_rect(Rect2(cx if sx > 0.0 else cx - 1.0, cy if sy > 0.0 else cy - 1.0, 2.0, 2.0), gold)
		var rv := Vector2(cx + sx * 2.0 - (0.0 if sx > 0.0 else 1.0), cy + sy * 2.0 - (0.0 if sy > 0.0 else 1.0))
		draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), night)
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), apr)
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), gold)


func _draw_header_legend() -> void:
	# Map title + compact micro-icon legend left of view tabs (x=22..138, y=16).
	if _view == View.ARCHIPELAGO:
		LxPixelFont.draw_left(self, LxStrings.text("MAP_TITLE"), Vector2(22.0, 16.0), LxPalette.PAL["gold"], 1)
		var sx0: float = 96.0
		_px(Vector2(sx0, 18.0), [[-1, 0, 3, 1], [0, -1, 1, 3]], LxPalette.PAL["gold"])
		draw_rect(Rect2(sx0, 18.0, 1.0, 1.0), LxPalette.PAL["cream"])
		LxPixelFont.draw_left(self, LxStrings.text("MAP_LEGEND_RELIT"), Vector2(sx0 + 4.0, 16.0), LxPalette.PAL["stone"], 1)
		return
	var lx: float = 22.0
	draw_rect(Rect2(lx, 16.0, 3.0, 5.0), LxPalette.PAL["night"])
	_px(Vector2(lx, 16.0), [[0, 0, 3, 1], [0, 4, 3, 1]], LxPalette.PAL["apricot"])
	draw_rect(Rect2(lx, 17.0, 3.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(lx + 1.0, 18.0, 1.0, 1.0), LxPalette.PAL["cream"])
	LxPixelFont.draw_left(self, LxStrings.text("MAP_CURRENT"), Vector2(lx + 5.0, 16.0), LxPalette.PAL["stone"], 1)
	var sx: float = lx + 28.0
	_px(Vector2(sx, 18.0), [[-1, 0, 3, 1], [0, -1, 1, 3]], LxPalette.PAL["gold"])
	draw_rect(Rect2(sx, 18.0, 1.0, 1.0), LxPalette.PAL["cream"])
	LxPixelFont.draw_left(self, LxStrings.text("MAP_LEGEND_RELIT"), Vector2(sx + 4.0, 16.0), LxPalette.PAL["stone"], 1)


func _draw_chart_backdrop(chart: Rect2) -> void:
	LxMapSilhouettes.draw_chart_backdrop(self, chart, _elapsed)


func _px(c: Vector2, rects: Array, col: Color) -> void:
	for r: Array in rects:
		draw_rect(Rect2(roundf(c.x + float(r[0])), roundf(c.y + float(r[1])), float(r[2]), float(r[3])), col)


func _draw_bridges() -> void:
	if Lx.state == null:
		return
	for i: int in range(ISLAND_POS.size() - 1):
		var a: Vector2 = ISLAND_POS[i]
		var b: Vector2 = ISLAND_POS[i + 1]
		var open_bridge: bool = Lx.state.relit_islands.has(i + 1)
		var b_hi: Color = LxBiomePalette.col(i + 1, "glow")
		var b_lo: Color = LxBiomePalette.col(i + 1, "hi")
		for s: int in range(1, 8):
			var p: Vector2 = a.lerp(b, float(s) / 8.0).round()
			if open_bridge:
				draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), LxPalette.PAL["night"])
				draw_rect(Rect2(p, Vector2(2.0, 2.0)), b_hi if ((s if LxHudFx.flash_reduced() else s + floori(_elapsed * 3.2)) % 3 == 0) else b_lo)
			else:
				draw_rect(Rect2(p, Vector2(2.0, 1.0)), LxPalette.PAL["dusk"])
		if open_bridge:
			var t: float = fmod(_elapsed * 0.55 + float(i) * 0.21, 1.0)
			draw_rect(Rect2(a.lerp(b, clampf(t - 0.11, 0.08, 0.92)).round(), Vector2(1.0, 1.0)), b_lo)
			draw_rect(Rect2(a.lerp(b, clampf(t - 0.05, 0.08, 0.92)).round(), Vector2(2.0, 2.0)), b_hi)
			var hp: Vector2 = a.lerp(b, clampf(t, 0.08, 0.92)).round()
			draw_rect(Rect2(hp + Vector2(-1.0, 0.0), Vector2(4.0, 2.0)), b_hi)
			draw_rect(Rect2(hp, Vector2(2.0, 2.0)), LxPalette.PAL["cream"])


func _draw_islands() -> void:
	_draw_hub_pin()
	for i: int in range(ISLAND_POS.size()):
		var isl_id: int = i + 1
		var c: Vector2 = ISLAND_POS[i]
		var explored: bool = _is_island_explored(isl_id)
		var relit: bool = Lx.state != null and Lx.state.relit_islands.has(isl_id)
		var is_cur: bool = Lx.state != null and Lx.state.island_id == isl_id
		var is_sel: bool = isl_id == _selected_island
		if not explored: _draw_unexplored_island(c, isl_id)
		else:
			_draw_island_plinth(c, isl_id, relit); _draw_island_landmark(c, isl_id, relit)
			if relit: _draw_relit_sparkle(c + Vector2(0.0, -14.0), isl_id)
			if is_cur: _draw_wick_pip(c + Vector2(-9.0, -9.0 + (0.0 if LxHudFx.flash_reduced() else roundf(sin(_elapsed * 3.8) * 1.5))))
		if is_sel: _draw_selection_brackets(c, false)
		elif isl_id == _hover_island: _draw_selection_brackets(c, true)
		var num_col: Color = LxPalette.PAL["gold"] if is_sel else (LxPalette.PAL["cream"] if explored else LxPalette.PAL["mauve"])
		LxPixelFont.draw_centered(self, str(isl_id), c.x, c.y + 8.0, num_col, 1)

func _draw_hub_pin() -> void:
	var c: Vector2 = HUB_POS
	_px(c, [[-5, 1, 10, 2], [-4, 3, 8, 1]], LxPalette.PAL["dusk"])
	_px(c, [[-4, -3, 8, 4]], LxPalette.PAL["stone"])
	_px(c, [[-5, -4, 10, 1], [-4, -5, 8, 1], [-2, -6, 4, 1]], LxPalette.PAL["wine"])
	_px(c, [[2, -7, 2, 2]], LxPalette.PAL["plum"])
	_px(c, [[-1, -2, 2, 2]], LxPalette.PAL["gold"])
	_px(c, [[0, -2, 1, 1]], LxPalette.PAL["cream"])
	if Lx.state != null and Lx.state.island_id == 0:
		_draw_wick_pip(c + Vector2(-9.0, -8.0 + (0.0 if LxHudFx.flash_reduced() else roundf(sin(_elapsed * 3.8) * 1.5))))
	if _selected_island == 0: _draw_selection_brackets(c, false)
	elif _hover_island == 0: _draw_selection_brackets(c, true)
	LxPixelFont.draw_centered(self, LxStrings.text("MAP_HUB_SHORT"), c.x, c.y + 6.0, LxPalette.PAL["gold"] if _selected_island == 0 else LxPalette.PAL["cream"], 1)


func _draw_unexplored_island(c: Vector2, isl_id: int) -> void:
	LxMapSilhouettes.draw_unexplored_island(self, c, isl_id, _elapsed)


func _draw_island_plinth(c: Vector2, isl_id: int, relit: bool) -> void:
	LxMapSilhouettes.draw_plinth(self, c, isl_id, relit, LxPalette.color(PLINTH_TOP[isl_id - 1]), LxPalette.color(PLINTH_RIM[isl_id - 1]), _elapsed)


func _draw_island_landmark(c: Vector2, isl_id: int, relit: bool) -> void:
	LxMapSilhouettes.draw_island_landmark(self, c, isl_id, relit, _elapsed)


func _draw_relit_sparkle(p: Vector2, isl_id: int) -> void:
	var sp := Vector2(roundf(p.x), maxf(29.0, roundf(p.y)))
	if LxHudFx.flash_reduced() or fmod(_elapsed * 1.8 + float(isl_id) * 0.37, 1.2) < 0.6:
		_px(sp, [[-1, 0, 1, 1], [1, 0, 1, 1], [0, -1, 1, 1], [0, 1, 1, 1]], LxPalette.PAL["gold"])
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), LxPalette.PAL["cream"])
	else:
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), LxPalette.PAL["gold"])


func _draw_wick_pip(p: Vector2) -> void:
	var wp := Vector2(roundf(p.x), maxf(30.0, roundf(p.y)))
	var flk: bool = LxHudFx.flash_reduced() or fmod(_elapsed * 3.0, 1.0) < 0.55
	draw_rect(Rect2(wp, Vector2(5.0, 6.0)), LxPalette.PAL["night"])
	_px(wp, [[1, 0, 3, 1], [1, 5, 3, 1]], LxPalette.PAL["apricot"])
	_px(wp, [[1, 1, 3, 4]], LxPalette.PAL["gold"] if flk else LxPalette.PAL["apricot"])
	_px(wp, [[2, 2, 1, 2]], LxPalette.PAL["cream"])


func _draw_selection_brackets(c: Vector2, is_hover: bool = false) -> void:
	var pulse: bool = not is_hover and not LxHudFx.flash_reduced() and fmod(_elapsed, 1.1) < 0.55
	var ex: float = 1.0 if pulse else 0.0
	var col: Color = LxPalette.PAL["sky"] if is_hover else (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"])
	var l: float = roundf(c.x - 10.0 - ex)
	var r: float = roundf(c.x + 10.0 + ex)
	var t: float = maxf(29.0, roundf(c.y - 13.0 - ex))
	var b: float = minf(88.0, roundf(c.y + 6.0 + ex))
	_px(Vector2.ZERO, [[l, t, 3, 1], [l, t, 1, 3], [r - 2, t, 3, 1], [r, t, 1, 3], [l, b, 3, 1], [l, b - 2, 1, 3], [r - 2, b, 3, 1], [r, b - 2, 1, 3]], col)


func _waystone_label(isl_id: int, ws_id: String) -> String:
	if LxStrings.has_id(ws_id):
		return LxStrings.text(ws_id).substr(0, 18)
	var low: String = ws_id.to_lower()
	if WAYSTONE_LABEL_KEYS.has(low):
		var wkey: String = str(WAYSTONE_LABEL_KEYS[low])
		if LxStrings.has_id(wkey):
			return LxStrings.text(wkey).substr(0, 18)
	var loc: Dictionary = LxMapFormat.find_waystone(isl_id, ws_id)
	var nkey: String = str(loc.get("name_key", ""))
	if not nkey.is_empty() and LxStrings.has_id(nkey):
		return LxStrings.text(nkey).substr(0, 18)
	var zones: Array = ISLAND_ZONE_KEYS.get(isl_id, []) as Array
	if isl_id == 1:
		for pair: Array in [["plaza", "ZONE_PLAZA"], ["orchard", "ZONE_ORCHARD"], ["observatory", "ZONE_OBSERVATORY"], ["glasshouse", "ZONE_GLASSHOUSE"], ["bridge", "ZONE_BRIDGE"], ["tower", "ZONE_BELL_TOWER"], ["bell", "ZONE_BELL_TOWER"]]:
			if low.contains(str(pair[0])):
				return LxStrings.text(str(pair[1])).substr(0, 18)
	for z_idx: int in range(zones.size()):
		var num: String = str(z_idx + 1)
		if low.ends_with("_" + num) or low.contains("_z" + num) or low.contains("_zone" + num):
			return LxStrings.text(str(zones[z_idx])).substr(0, 18)
	if not zones.is_empty() and (low.contains("entry") or low.contains("landing") or low.contains("hub") or low.contains("quay") or low.contains("gate")):
		return LxStrings.text(str(zones[0])).substr(0, 18)
	if not loc.is_empty() and str(loc.get("region", "overworld")) != "overworld":
		var reg_s: String = str(loc.get("region", ""))
		if Lx.packs != null:
			var rnk: String = str(Lx.packs.region_meta(isl_id, reg_s).get("name_key", ""))
			if not rnk.is_empty() and LxStrings.has_id(rnk):
				return LxStrings.text(rnk).substr(0, 18)
			var did: String = Lx.packs.dungeon_of(isl_id, reg_s)
			if not did.is_empty():
				return LxMapDungeon._dungeon_display_name(Lx.packs.dungeon(did), did).substr(0, 18)
		var dkey: String = str(LxMapInfo.DUNGEON_NAME_KEYS.get(isl_id, ""))
		if not dkey.is_empty() and LxStrings.has_id(dkey):
			return LxStrings.text(dkey).substr(0, 18)
	var clean_id: String = low
	if clean_id.begins_with("ws_"):
		clean_id = clean_id.substr(3)
	if clean_id.length() >= 2 and clean_id[0] >= "1" and clean_id[0] <= "8" and clean_id[1] == "_":
		clean_id = clean_id.substr(2)
	return LxStrings.sanitize(clean_id, 18)


func _is_island_explored(isl_id: int) -> bool:
	if isl_id == 0: return true
	if Lx.state == null: return isl_id == 1
	if Lx.state.island_id == isl_id or Lx.state.relit_islands.has(isl_id): return true
	var prefix: String = "%d:" % isl_id
	for vr: String in Lx.state.visited_regions:
		if vr.begins_with(prefix): return true
	for ws: String in Lx.state.lit_waystones:
		if _waystone_island(ws) == isl_id: return true
	return false

func _waystone_island(ws_id: String) -> int:
	if ws_id == "ws_hub": return 0
	var found: Dictionary = LxMapFormat.find_waystone_any(ws_id)
	if not found.is_empty(): return int(found.get("island", 1))
	var low: String = ws_id.to_lower()
	for n: int in range(1, 9):
		if low.begins_with("isl%d_" % n) or low.begins_with("ws_isl%d" % n) or low.begins_with("island%d_" % n) or low.begins_with("island_%d_" % n) or low.begins_with("ws_%d_" % n) or low.begins_with("%d:" % n):
			return n
	return 1

func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null: Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)

static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc

static func _joy_btn(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
