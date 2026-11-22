class_name LxIsland6
extends RefCounted
## Island 6 (Ashen Kiln) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 6
const SEAL_ID: String = "kiln_gate_seal"
const BOSS_ID: String = "kilnmother"
const MINI_BOSS_KIND: String = "forge_warden"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_6_1",
	"beacon_6_2",
	"beacon_6_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"kiln_r1",
	"kiln_r2",
	"kiln_r3",
	"kiln_r4",
	"kiln_r5",
	"kiln_r6",
	"kiln_r7",
	"kiln_r8",
	"kiln_r9",
	"kiln_r10",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	if _events == null:
		return
	_attached = true
	_events.region_entered.connect(_on_region_entered)
	_events.beacon_lit.connect(_on_beacon_lit)
	_events.shrine_claimed.connect(_on_shrine_claimed)
	_events.enemy_killed.connect(_on_enemy_killed)
	_events.boss_phase_changed.connect(_on_boss_phase_changed)
	_events.boss_defeated.connect(_on_boss_defeated)
	_events.great_lamp_relit.connect(_on_great_lamp_relit)


func detach() -> void:
	if not _attached or _events == null:
		_attached = false
		return
	if _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	if _events.beacon_lit.is_connected(_on_beacon_lit):
		_events.beacon_lit.disconnect(_on_beacon_lit)
	if _events.shrine_claimed.is_connected(_on_shrine_claimed):
		_events.shrine_claimed.disconnect(_on_shrine_claimed)
	if _events.enemy_killed.is_connected(_on_enemy_killed):
		_events.enemy_killed.disconnect(_on_enemy_killed)
	if _events.boss_phase_changed.is_connected(_on_boss_phase_changed):
		_events.boss_phase_changed.disconnect(_on_boss_phase_changed)
	if _events.boss_defeated.is_connected(_on_boss_defeated):
		_events.boss_defeated.disconnect(_on_boss_defeated)
	if _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
		_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
	_attached = false


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		{
			"id": "wp_isl6_beacon_1",
			"region": "overworld",
			"zone": "ash_drifts",
			"pos": [184.0, 120.0],
			"action": "light_beacon",
			"target": "beacon_6_1",
			"grants_flag": "beacon_6_1",
			"requires_moves": ["bolt", "dash", "throw"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl6_beacon_2",
			"region": "overworld",
			"zone": "slag_foundry",
			"pos": [280.0, 392.0],
			"action": "light_beacon",
			"target": "beacon_6_2",
			"grants_flag": "beacon_6_2",
			"requires_moves": ["bolt", "dash", "throw", "beam"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl6_beacon_3",
			"region": "overworld",
			"zone": "furnace_causeway",
			"pos": [872.0, 136.0],
			"action": "light_beacon",
			"target": "beacon_6_3",
			"grants_flag": "beacon_6_3",
			"requires_moves": ["bolt", "dash", "throw", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_enter_kiln",
			"region": "overworld",
			"zone": "kiln_approach",
			"pos": [512.0, 64.0],
			"action": "enter_exit",
			"target": "exit_to_kiln",
			"to_region": "kiln_r1",
			"requires_moves": ["dash", "throw", "wings", "lens"],
			"requires_flags": ["beacon_6_1", "beacon_6_2", "beacon_6_3"],
		},
		{
			"id": "wp_kiln_key_1",
			"region": "kiln_r2",
			"zone": "kiln_r2",
			"pos": [40.0, 88.0],
			"action": "collect_key",
			"target": "wick_key_6_1",
			"grants_flag": "wick_key_6_1",
			"requires_moves": ["throw"],
			"requires_flags": [],
		},
		{
			"id": "wp_kiln_r3_combat",
			"region": "kiln_r3",
			"zone": "kiln_r3",
			"pos": [160.0, 88.0],
			"action": "clear_room",
			"target": "door_kiln_r3_north",
			"requires_moves": ["dash", "throw"],
			"requires_flags": [],
		},
		{
			"id": "wp_kiln_r4_crossing",
			"region": "kiln_r4",
			"zone": "kiln_r4",
			"pos": [296.0, 88.0],
			"action": "unlock_door",
			"target": "door_kiln_r4_east",
			"requires_moves": ["wings", "lens"],
			"requires_flags": ["wick_key_6_1"],
		},
		{
			"id": "wp_shrine_sunflare",
			"region": "kiln_r5",
			"zone": "kiln_r5",
			"pos": [152.0, 88.0],
			"action": "claim_shrine",
			"target": "shrine_sunflare",
			"grants_move": "sunflare",
			"requires_moves": ["wings", "lens"],
			"requires_flags": ["wick_key_6_1"],
		},
		{
			"id": "wp_kiln_miniboss",
			"region": "kiln_r6",
			"zone": "kiln_r6",
			"pos": [184.0, 88.0],
			"action": "defeat_miniboss",
			"target": "mini_forge_warden",
			"grants_flag": "wick_key_6_2",
			"requires_moves": ["sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_kiln_furnace_hall",
			"region": "kiln_r7",
			"zone": "kiln_r7",
			"pos": [160.0, 88.0],
			"action": "solve_puzzle",
			"target": "door_kiln_r7_west",
			"requires_moves": ["sunflare"],
			"requires_flags": ["wick_key_6_2"],
		},
		{
			"id": "wp_kiln_r8_combat",
			"region": "kiln_r8",
			"zone": "kiln_r8",
			"pos": [152.0, 88.0],
			"action": "clear_room",
			"target": "door_kiln_r8_west",
			"requires_moves": ["sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_kiln_boss_key",
			"region": "kiln_r9",
			"zone": "kiln_r9",
			"pos": [56.0, 88.0],
			"action": "collect_key",
			"target": "keepers_flame_6",
			"grants_flag": "keepers_flame_6",
			"requires_moves": ["sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_kiln_boss",
			"region": "kiln_r10",
			"zone": "kiln_r10",
			"pos": [160.0, 72.0],
			"action": "defeat_boss",
			"target": "boss_kilnmother",
			"grants_flag": "boss_kilnmother_defeated",
			"requires_moves": ["sunflare"],
			"requires_flags": ["keepers_flame_6"],
		},
		{
			"id": "wp_great_lamp_6",
			"region": "kiln_r10",
			"zone": "kiln_r10",
			"pos": [160.0, 48.0],
			"action": "light_great_lamp",
			"target": "great_lamp_6",
			"grants_flag": "great_lamp_6",
			"requires_moves": ["sunflare"],
			"requires_flags": ["boss_kilnmother_defeated"],
		},
		{
			"id": "wp_bridge_to_island_7",
			"region": "kiln_r10",
			"zone": "kiln_r10",
			"pos": [160.0, 8.0],
			"action": "enter_exit",
			"target": "exit_r10_bridge_7",
			"to_region": "overworld",
			"to_island": 7,
			"requires_moves": ["sunflare"],
			"requires_flags": ["great_lamp_6"],
		},
	]


func are_all_beacons_lit() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	for bid: String in REQUIRED_BEACONS:
		if not st.lit_beacons.has(bid) and not bool(st.story_flags.get(bid, false)):
			return false
	return true


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if region_id == "overworld":
		if st != null and not bool(st.story_flags.get("isl6_arrived", false)):
			st.story_flags["isl6_arrived"] = true
			_emit_narration("ISL6_ARRIVAL", "narration", 4.0)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "kiln_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_KILNMOTHER", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island6_boss_p1")
	elif region_id.begins_with("kiln_"):
		if region_id == "kiln_r1" and st != null and not bool(st.story_flags.get("isl6_kiln_entered", false)):
			st.story_flags["isl6_kiln_entered"] = true
			_emit_narration("DUNGEON_6_NAME", "title", 3.5)
		if _events != null:
			_events.music_mode_requested.emit("island6_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_sunflare" or move_id == "sunflare":
		_emit_narration("MOVE_SUNFLARE_NAME", "title", 3.5)
		_events.prompt_requested.emit("PROMPT_SUNFLARE", "lx_sunflare", 6.0)
		_events.sfx_requested.emit("shrine_unlock", Vector2.ZERO, false)


func _on_beacon_lit(island_id: int, beacon_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.lit_beacons.has(beacon_id):
			st.lit_beacons.append(beacon_id)
		st.story_flags[beacon_id] = true
	_emit_narration("CUE_BEACON_LIT", "title", 2.5)
	if are_all_beacons_lit():
		_trigger_seal_shatter()


func _trigger_seal_shatter() -> void:
	var st: LxGameState = _get_state()
	if st != null:
		if st.broken_seals.has(SEAL_ID):
			return
		st.broken_seals.append(SEAL_ID)
		st.story_flags["seal_broken_6"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_events.save_requested.emit("seal_broken_6")


func _on_enemy_killed(enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	var eid: String = str(enemy.get("enemy_id")) if enemy != null else ""
	if kind == MINI_BOSS_KIND or eid == "mini_forge_warden":
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["defeated_" + MINI_BOSS_KIND] = true
		st.story_flags[MINI_BOSS_KIND + "_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_emit_narration("CUE_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("forge_warden_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island6_boss_p2")
		_events.shake_requested.emit(0.32)
		_emit_narration("CUE_PHASE_2", "warning", 3.0)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id == MINI_BOSS_KIND:
		if st != null:
			if not st.defeated_bosses.has(MINI_BOSS_KIND):
				st.defeated_bosses.append(MINI_BOSS_KIND)
			st.story_flags["defeated_" + MINI_BOSS_KIND] = true
			st.story_flags[MINI_BOSS_KIND + "_defeated"] = true
		return
	if boss_id != BOSS_ID:
		return
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_kilnmother_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_kilnmother_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_6"] = true
		st.story_flags["island_6_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL6_RELIGHT", "title", 4.0)
		_emit_narration("ISL6_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_6")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
