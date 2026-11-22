class_name LxIsland1
extends RefCounted
## Island 1 (Bell Isle) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 1
const SEAL_ID: String = "bell_arch_seal"
const BOSS_ID: String = "bellkeeper"
const MINI_BOSS_KIND: String = "bell_warden"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_orchard",
	"beacon_observatory",
	"beacon_bridge",
]

const REGIONS: Array[String] = [
	"overworld",
	"belfry_r1",
	"belfry_r2",
	"belfry_r3",
	"belfry_r4",
	"belfry_r5",
	"belfry_r6",
	"belfry_r7",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _r4_kills: int = 0


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
			"id": "wp_plaza_warden",
			"region": "overworld",
			"zone": "plaza",
			"pos": [692.0, 362.0],
			"action": "clear_encounter",
			"target": "warden_plaza_0",
			"requires_moves": ["bolt"],
			"requires_flags": [],
		},
		{
			"id": "wp_shrine_dash",
			"region": "overworld",
			"zone": "orchard",
			"pos": [360.0, 198.0],
			"action": "claim_shrine",
			"target": "shrine_dash",
			"grants_move": "dash",
			"requires_moves": ["bolt"],
			"requires_flags": [],
		},
		{
			"id": "wp_beacon_orchard",
			"region": "overworld",
			"zone": "orchard",
			"pos": [204.0, 196.0],
			"action": "light_beacon",
			"target": "beacon_orchard",
			"grants_flag": "beacon_orchard",
			"requires_moves": ["bolt", "dash"],
			"requires_flags": [],
		},
		{
			"id": "wp_shrine_throw",
			"region": "overworld",
			"zone": "observatory",
			"pos": [314.0, 372.0],
			"action": "claim_shrine",
			"target": "shrine_throw",
			"grants_move": "throw",
			"requires_moves": ["bolt", "dash"],
			"requires_flags": ["beacon_orchard"],
		},
		{
			"id": "wp_beacon_observatory",
			"region": "overworld",
			"zone": "observatory",
			"pos": [182.0, 376.0],
			"action": "light_beacon",
			"target": "beacon_observatory",
			"grants_flag": "beacon_observatory",
			"requires_moves": ["bolt", "dash", "throw"],
			"requires_flags": ["beacon_orchard"],
		},
		{
			"id": "wp_glasshouse_magpies",
			"region": "overworld",
			"zone": "glasshouse",
			"pos": [640.0, 548.0],
			"action": "clear_encounter",
			"target": "snatcher_glasshouse_0",
			"requires_moves": ["bolt", "dash", "throw"],
			"requires_flags": ["beacon_observatory"],
		},
		{
			"id": "wp_beacon_bridge",
			"region": "overworld",
			"zone": "moonlit_bridge",
			"pos": [1128.0, 360.0],
			"action": "light_beacon",
			"target": "beacon_bridge",
			"grants_flag": "beacon_bridge",
			"requires_moves": ["bolt", "dash", "throw"],
			"requires_flags": ["beacon_observatory"],
		},
		{
			"id": "wp_enter_belfry",
			"region": "overworld",
			"zone": "bell_arch",
			"pos": [640.0, 108.0],
			"action": "enter_exit",
			"target": "exit_to_belfry",
			"to_region": "belfry_r1",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["beacon_orchard", "beacon_observatory", "beacon_bridge"],
		},
		{
			"id": "wp_belfry_key_1",
			"region": "belfry_r2",
			"zone": "belfry_chasm",
			"pos": [72.0, 88.0],
			"action": "collect_key",
			"target": "wick_key_1",
			"grants_flag": "wick_key_1",
			"requires_moves": ["dash"],
			"requires_flags": [],
		},
		{
			"id": "wp_belfry_gallery",
			"region": "belfry_r3",
			"zone": "belfry_gallery",
			"pos": [200.0, 88.0],
			"action": "open_shutter",
			"target": "door_r3_shutter",
			"grants_flag": "r3_shutter_open",
			"requires_moves": ["throw"],
			"requires_flags": ["wick_key_1"],
		},
		{
			"id": "wp_belfry_nave",
			"region": "belfry_r4",
			"zone": "belfry_nave",
			"pos": [160.0, 88.0],
			"action": "clear_room",
			"target": "door_r4_combat",
			"grants_flag": "r4_cleared",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["r3_shutter_open"],
		},
		{
			"id": "wp_belfry_miniboss",
			"region": "belfry_r5",
			"zone": "belfry_loft",
			"pos": [160.0, 72.0],
			"action": "defeat_miniboss",
			"target": "bell_warden_r5",
			"grants_flag": "wick_key_2",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["r4_cleared"],
		},
		{
			"id": "wp_belfry_boss_key",
			"region": "belfry_r6",
			"zone": "belfry_vault",
			"pos": [40.0, 88.0],
			"action": "collect_key",
			"target": "keepers_flame",
			"grants_flag": "keepers_flame",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["bell_warden_defeated", "wick_key_2"],
		},
		{
			"id": "wp_belfry_boss",
			"region": "belfry_r7",
			"zone": "belfry_spire",
			"pos": [160.0, 72.0],
			"action": "defeat_boss",
			"target": "boss_bellkeeper",
			"grants_flag": "boss_bellkeeper_defeated",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["keepers_flame"],
		},
		{
			"id": "wp_great_lamp_1",
			"region": "belfry_r7",
			"zone": "belfry_spire",
			"pos": [160.0, 40.0],
			"action": "light_great_lamp",
			"target": "great_lamp_1",
			"grants_flag": "great_lamp_1",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["boss_bellkeeper_defeated"],
		},
		{
			"id": "wp_bridge_to_island_2",
			"region": "overworld",
			"zone": "moonlit_bridge",
			"pos": [1232.0, 168.0],
			"action": "enter_exit",
			"target": "exit_to_island_2",
			"to_region": "island2:overworld",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["great_lamp_1"],
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
		if st != null and not bool(st.story_flags.get("isl1_arrived", false)):
			st.story_flags["isl1_arrived"] = true
			_emit_narration("ISL1_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.prompt_requested.emit("PROMPT_AIM_SHOOT", "lx_fire", 4.5)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "belfry_r7":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			if _events != null:
				_events.music_mode_requested.emit("island1_boss_p1")
	elif region_id.begins_with("belfry_"):
		if region_id == "belfry_r1" and st != null and not bool(st.story_flags.get("isl1_belfry_entered", false)):
			st.story_flags["isl1_belfry_entered"] = true
			_emit_narration("CH5_TITLE", "title", 3.5)
		elif region_id == "belfry_r4":
			_r4_kills = 0
		if _events != null:
			_events.music_mode_requested.emit("island1_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_dash" or move_id == "dash":
		_events.prompt_requested.emit("PROMPT_DASH", "lx_dash", 4.5)
		_events.sfx_requested.emit("shrine_unlock", Vector2.ZERO, false)
	elif shrine_id == "shrine_throw" or move_id == "throw":
		_events.prompt_requested.emit("PROMPT_THROW", "lx_throw", 4.5)
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
		st.story_flags["seal_broken_1"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_emit_narration("CUE_BELL_ARCH_OPEN", "narration", 3.5)
		_events.save_requested.emit("seal_broken_1")


func _on_enemy_killed(_enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	if st.region_id == "belfry_r4":
		_r4_kills += 1
		if _r4_kills >= 3 and not bool(st.story_flags.get("r4_cleared", false)):
			st.story_flags["r4_cleared"] = true
			if _events != null:
				_events.sfx_requested.emit("door_open", Vector2.ZERO, false)
				_emit_narration("CUE_DOOR_OPEN", "title", 2.5)
	elif st.region_id == "belfry_r5" and kind == MINI_BOSS_KIND:
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["bell_warden_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_emit_narration("CUE_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("bell_warden_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island1_boss_p2")
		_events.shake_requested.emit(0.32)
		_emit_narration("CUE_PHASE_2", "warning", 3.5)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID or boss_id != BOSS_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_bellkeeper_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_bellkeeper_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_1"] = true
		st.story_flags["island_1_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL1_RELIGHT", "title", 4.0)
		_emit_narration("ISL1_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_1")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
