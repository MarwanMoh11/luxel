class_name LxIsland5
extends RefCounted
## Island 5 (Starfall Observatory) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 5
const SEAL_ID: String = "orrery_seal"
const BOSS_ID: String = "astronomer"
const MINI_BOSS_KIND: String = "clockwork_warden"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_5_1",
	"beacon_5_2",
	"beacon_5_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"orrery_r1",
	"orrery_r2",
	"orrery_r3",
	"orrery_r4",
	"orrery_r5",
	"orrery_r6",
	"orrery_r7",
	"orrery_r8",
	"orrery_r9",
	"orrery_r10",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _r3_kills: int = 0
var _r8_kills: int = 0


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
			"id": "wp_5_entry_moth",
			"region": "overworld",
			"zone": "star_landing",
			"pos": [248.0, 432.0],
			"action": "clear_encounter",
			"target": "echo_moth_5_entry",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_5_beacon_1",
			"region": "overworld",
			"zone": "brass_terrace",
			"pos": [184.0, 184.0],
			"action": "light_beacon",
			"target": "beacon_5_1",
			"grants_flag": "beacon_5_1",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_5_beacon_2",
			"region": "overworld",
			"zone": "echo_promenade",
			"pos": [512.0, 360.0],
			"action": "light_beacon",
			"target": "beacon_5_2",
			"grants_flag": "beacon_5_2",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings"],
			"requires_flags": ["beacon_5_1"],
		},
		{
			"id": "wp_5_beacon_3",
			"region": "overworld",
			"zone": "zenith_rim",
			"pos": [824.0, 392.0],
			"action": "light_beacon",
			"target": "beacon_5_3",
			"grants_flag": "beacon_5_3",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings"],
			"requires_flags": ["beacon_5_2"],
		},
		{
			"id": "wp_5_enter_orrery",
			"region": "overworld",
			"zone": "orrery_plaza",
			"pos": [512.0, 60.0],
			"action": "enter_exit",
			"target": "exit_to_orrery",
			"to_region": "orrery_r1",
			"requires_moves": ["dash", "throw", "prism", "beam", "wings"],
			"requires_flags": ["beacon_5_1", "beacon_5_2", "beacon_5_3"],
		},
		{
			"id": "wp_5_key_1",
			"region": "orrery_r2",
			"zone": "orrery_r2",
			"pos": [24.0, 88.0],
			"action": "collect_key",
			"target": "wick_key_5_1",
			"grants_flag": "wick_key_5_1",
			"requires_moves": ["beam", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_5_r3_combat",
			"region": "orrery_r3",
			"zone": "orrery_r3",
			"pos": [160.0, 88.0],
			"action": "clear_room",
			"target": "door_o5_r3_combat",
			"grants_flag": "o5_r3_cleared",
			"requires_moves": ["prism", "wings"],
			"requires_flags": ["wick_key_5_1"],
		},
		{
			"id": "wp_5_r4_mirrors",
			"region": "orrery_r4",
			"zone": "orrery_r4",
			"pos": [200.0, 88.0],
			"action": "open_shutter",
			"target": "door_o5_r4_shutter",
			"grants_flag": "o5_r4_shutter_open",
			"requires_moves": ["prism"],
			"requires_flags": ["wick_key_5_1", "o5_r3_cleared"],
		},
		{
			"id": "wp_5_shrine_lens",
			"region": "orrery_r5",
			"zone": "orrery_r5",
			"pos": [56.0, 56.0],
			"action": "claim_shrine",
			"target": "shrine_lens",
			"grants_move": "lens",
			"requires_moves": ["prism", "wings"],
			"requires_flags": ["o5_r4_shutter_open"],
		},
		{
			"id": "wp_5_miniboss",
			"region": "orrery_r6",
			"zone": "orrery_r6",
			"pos": [160.0, 72.0],
			"action": "defeat_miniboss",
			"target": "boss_clockwork_warden",
			"grants_flag": "wick_key_5_2",
			"requires_moves": ["lens"],
			"requires_flags": [],
		},
		{
			"id": "wp_5_r7_starlight",
			"region": "orrery_r7",
			"zone": "orrery_r7",
			"pos": [40.0, 56.0],
			"action": "open_shutter",
			"target": "door_o5_r7_shutter",
			"grants_flag": "o5_r7_shutter_open",
			"requires_moves": ["lens"],
			"requires_flags": ["wick_key_5_2"],
		},
		{
			"id": "wp_5_r8_combat",
			"region": "orrery_r8",
			"zone": "orrery_r8",
			"pos": [160.0, 88.0],
			"action": "clear_room",
			"target": "door_o5_r8_combat",
			"grants_flag": "o5_r8_cleared",
			"requires_moves": ["lens", "throw"],
			"requires_flags": ["o5_r7_shutter_open"],
		},
		{
			"id": "wp_5_keepers_flame",
			"region": "orrery_r9",
			"zone": "orrery_r9",
			"pos": [264.0, 128.0],
			"action": "collect_key",
			"target": "keepers_flame_5",
			"grants_flag": "keepers_flame_5",
			"requires_moves": ["lens", "wings", "prism"],
			"requires_flags": ["o5_r8_cleared"],
		},
		{
			"id": "wp_5_boss",
			"region": "orrery_r10",
			"zone": "orrery_r10",
			"pos": [160.0, 72.0],
			"action": "defeat_boss",
			"target": "boss_astronomer",
			"grants_flag": "boss_astronomer_defeated",
			"requires_moves": ["lens"],
			"requires_flags": ["keepers_flame_5"],
		},
		{
			"id": "wp_5_great_lamp",
			"region": "orrery_r10",
			"zone": "orrery_r10",
			"pos": [160.0, 40.0],
			"action": "light_great_lamp",
			"target": "great_lamp_5",
			"grants_flag": "island_5_relit",
			"requires_moves": ["lens"],
			"requires_flags": ["boss_astronomer_defeated"],
		},
		{
			"id": "wp_5_bridge_to_6",
			"region": "orrery_r10",
			"zone": "orrery_r10",
			"pos": [312.0, 88.0],
			"action": "enter_exit",
			"target": "exit_o5_r10_bridge",
			"to_region": "island6:overworld",
			"requires_moves": ["lens"],
			"requires_flags": ["island_5_relit"],
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
		if st != null and not bool(st.story_flags.get("isl5_arrived", false)):
			st.story_flags["isl5_arrived"] = true
			_emit_narration("ISL5_ARRIVAL", "narration", 4.0)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "orrery_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_ASTRONOMER", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island5_boss_p1")
	elif region_id.begins_with("orrery_"):
		if region_id == "orrery_r1" and st != null and not bool(st.story_flags.get("isl5_dungeon_entered", false)):
			st.story_flags["isl5_dungeon_entered"] = true
			_emit_narration("DUNGEON_5_NAME", "title", 3.5)
		elif region_id == "orrery_r3":
			_r3_kills = 0
		elif region_id == "orrery_r8":
			_r8_kills = 0
		if _events != null:
			_events.music_mode_requested.emit("island5_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_lens" or move_id == "lens":
		_events.prompt_requested.emit("PROMPT_LENS", "", 6.0)
		_events.sfx_requested.emit("shrine_unlock", Vector2.ZERO, false)
		_emit_narration("CUE_SHRINE_CLAIMED", "title", 3.0)


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
		st.story_flags["seal_broken_5"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_emit_narration("DUNGEON_5_NAME", "narration", 3.0)
		_events.save_requested.emit("seal_broken_5")


func _on_enemy_killed(_enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	if st.region_id == "orrery_r3":
		_r3_kills += 1
		if _r3_kills >= 2 and not bool(st.story_flags.get("o5_r3_cleared", false)):
			st.story_flags["o5_r3_cleared"] = true
			if _events != null:
				_events.sfx_requested.emit("door_open", Vector2.ZERO, false)
				_emit_narration("CUE_DOOR_OPEN", "title", 2.5)
	elif st.region_id == "orrery_r8":
		_r8_kills += 1
		if _r8_kills >= 3 and not bool(st.story_flags.get("o5_r8_cleared", false)):
			st.story_flags["o5_r8_cleared"] = true
			if _events != null:
				_events.sfx_requested.emit("door_open", Vector2.ZERO, false)
				_emit_narration("CUE_DOOR_OPEN", "title", 2.5)
	elif st.region_id == "orrery_r6" and kind == MINI_BOSS_KIND:
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["clockwork_warden_defeated"] = true
		st.story_flags["boss_clockwork_warden_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_emit_narration("CUE_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("clockwork_warden_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island5_boss_p2")
		_events.shake_requested.emit(0.32)
		_emit_narration("CUE_PHASE_2", "warning", 3.5)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID or boss_id != BOSS_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_astronomer_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_astronomer_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_5"] = true
		st.story_flags["island_5_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL5_RELIGHT", "title", 4.0)
		_emit_narration("ISL5_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_5")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
