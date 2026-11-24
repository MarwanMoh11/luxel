class_name LxIsland7
extends RefCounted
## Island 7 (Moon Shoals - The Twist) progression beats, Hollow Wick encounters, and waypoints.

const ISLAND_ID: int = 7
const SEAL_ID: String = "spire_gate_seal"
const BOSS_ID: String = "hollow_wick"
const MINI_BOSS_KIND: String = "moonshade_warden"
const MINI_BOSS_ALT_KIND: String = "spire_warden"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_7_1",
	"beacon_7_2",
	"beacon_7_3",
]

const HOLLOW_ENCOUNTERS: Array[String] = [
	"hollow_wick_enc_1",
	"hollow_wick_enc_2",
	"hollow_wick_enc_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"spire_r1",
	"spire_r2",
	"spire_r3",
	"spire_r4",
	"spire_r5",
	"spire_r6",
	"spire_r7",
	"spire_r8",
	"spire_r9",
	"spire_r10",
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
	_events.enemy_killed.connect(_on_enemy_killed)
	_events.boss_phase_changed.connect(_on_boss_phase_changed)
	_events.boss_defeated.connect(_on_boss_defeated)
	_events.great_lamp_relit.connect(_on_great_lamp_relit)
	_events.narration_requested.connect(_on_narration_requested)


func detach() -> void:
	if not _attached or _events == null:
		_attached = false
		return
	if _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	if _events.beacon_lit.is_connected(_on_beacon_lit):
		_events.beacon_lit.disconnect(_on_beacon_lit)
	if _events.enemy_killed.is_connected(_on_enemy_killed):
		_events.enemy_killed.disconnect(_on_enemy_killed)
	if _events.boss_phase_changed.is_connected(_on_boss_phase_changed):
		_events.boss_phase_changed.disconnect(_on_boss_phase_changed)
	if _events.boss_defeated.is_connected(_on_boss_defeated):
		_events.boss_defeated.disconnect(_on_boss_defeated)
	if _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
		_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
	if _events.narration_requested.is_connected(_on_narration_requested):
		_events.narration_requested.disconnect(_on_narration_requested)
	_attached = false


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		{
			"id": "wp_hollow_enc_1",
			"region": "overworld",
			"zone": "mirror_shallows",
			"pos": [312.0, 168.0],
			"action": "clear_encounter",
			"target": "hollow_wick_enc_1",
			"grants_flag": "hollow_wick_enc_1_cleared",
			"requires_moves": ["bolt", "dash", "throw", "prism"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_1",
			"region": "overworld",
			"zone": "mirror_shallows",
			"pos": [200.0, 184.0],
			"action": "light_beacon",
			"target": "beacon_7_1",
			"grants_flag": "beacon_7_1",
			"requires_moves": ["bolt", "dash", "throw", "prism"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_2",
			"region": "overworld",
			"zone": "tideglass_basin",
			"pos": [312.0, 536.0],
			"action": "light_beacon",
			"target": "beacon_7_2",
			"grants_flag": "beacon_7_2",
			"requires_moves": ["bolt", "dash", "throw", "beam"],
			"requires_flags": [],
		},
		{
			"id": "wp_hollow_enc_2",
			"region": "overworld",
			"zone": "inverted_causeway",
			"pos": [680.0, 600.0],
			"action": "clear_encounter",
			"target": "hollow_wick_enc_2",
			"grants_flag": "hollow_wick_enc_2_cleared",
			"requires_moves": ["dash", "throw", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_hollow_enc_3",
			"region": "overworld",
			"zone": "lunar_glasscourt",
			"pos": [1112.0, 392.0],
			"action": "clear_encounter",
			"target": "hollow_wick_enc_3",
			"grants_flag": "hollow_wick_enc_3_cleared",
			"requires_moves": ["dash", "throw", "lens", "sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_3",
			"region": "overworld",
			"zone": "lunar_glasscourt",
			"pos": [1096.0, 184.0],
			"action": "light_beacon",
			"target": "beacon_7_3",
			"grants_flag": "beacon_7_3",
			"requires_moves": ["dash", "throw", "lens", "sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_enter_spire",
			"region": "overworld",
			"zone": "spire_terrace",
			"pos": [704.0, 80.0],
			"action": "enter_exit",
			"target": "exit_to_spire",
			"to_region": "spire_r1",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["beacon_7_1", "beacon_7_2", "beacon_7_3"],
		},
		{
			"id": "wp_spire_key_1",
			"region": "spire_r2",
			"zone": "spire_r2",
			"pos": [72.0, 112.0],
			"action": "collect_key",
			"target": "wick_key_7_1",
			"grants_flag": "wick_key_7_1",
			"requires_moves": ["prism", "beam"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_r3_combat",
			"region": "spire_r3",
			"zone": "spire_r3",
			"pos": [240.0, 24.0],
			"action": "clear_room",
			"target": "door_spire_r3_north",
			"requires_moves": ["dash", "throw"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_r4_crossing",
			"region": "spire_r4",
			"zone": "spire_r4",
			"pos": [360.0, 136.0],
			"action": "unlock_door",
			"target": "door_spire_r4_east",
			"requires_moves": ["wings", "lens"],
			"requires_flags": ["wick_key_7_1"],
		},
		{
			"id": "wp_spire_r5_refraction",
			"region": "spire_r5",
			"zone": "spire_r5",
			"pos": [472.0, 120.0],
			"action": "solve_puzzle",
			"target": "door_spire_r5_east",
			"requires_moves": ["sunflare", "throw"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_miniboss",
			"region": "spire_r6",
			"zone": "spire_r6",
			"pos": [256.0, 136.0],
			"action": "defeat_miniboss",
			"target": "mini_moonshade_warden",
			"grants_flag": "wick_key_7_2",
			"requires_moves": ["dash", "throw", "sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_r7_inverted",
			"region": "spire_r7",
			"zone": "spire_r7",
			"pos": [56.0, 120.0],
			"action": "solve_puzzle",
			"target": "door_spire_r7_west",
			"requires_moves": ["prism", "lens", "wings"],
			"requires_flags": ["wick_key_7_2"],
		},
		{
			"id": "wp_spire_r8_combat",
			"region": "spire_r8",
			"zone": "spire_r8",
			"pos": [24.0, 120.0],
			"action": "clear_room",
			"target": "door_spire_r8_west",
			"requires_moves": ["dash", "throw", "lens"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_boss_key",
			"region": "spire_r9",
			"zone": "spire_r9",
			"pos": [72.0, 120.0],
			"action": "collect_key",
			"target": "keepers_flame_7",
			"grants_flag": "keepers_flame_7",
			"requires_moves": ["sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_spire_boss",
			"region": "spire_r10",
			"zone": "spire_r10",
			"pos": [240.0, 144.0],
			"action": "defeat_boss",
			"target": "boss_hollow_wick",
			"grants_flag": "boss_hollow_wick_defeated",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["keepers_flame_7"],
		},
		{
			"id": "wp_great_lamp_7",
			"region": "spire_r10",
			"zone": "spire_r10",
			"pos": [240.0, 64.0],
			"action": "light_great_lamp",
			"target": "great_lamp_7",
			"grants_flag": "great_lamp_7",
			"requires_moves": ["sunflare"],
			"requires_flags": ["boss_hollow_wick_defeated"],
		},
		{
			"id": "wp_bridge_to_island_8",
			"region": "spire_r10",
			"zone": "spire_r10",
			"pos": [240.0, 8.0],
			"action": "enter_exit",
			"target": "exit_r10_bridge_8",
			"to_region": "overworld",
			"to_island": 8,
			"requires_moves": ["sunflare"],
			"requires_flags": ["great_lamp_7"],
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
		if st != null and not bool(st.story_flags.get("isl7_arrived", false)):
			st.story_flags["isl7_arrived"] = true
			_emit_narration("ISL7_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.sfx_requested.emit("lens_reveal", Vector2.ZERO, false)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "spire_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_HOLLOW", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island7_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("spire_"):
		if region_id == "spire_r1" and st != null and not bool(st.story_flags.get("isl7_spire_entered", false)):
			st.story_flags["isl7_spire_entered"] = true
			_emit_narration("DUNGEON_7_NAME", "title", 3.5)
			if _events != null:
				_events.sfx_requested.emit("phantom_phase", Vector2.ZERO, false)
		if _events != null:
			var mb_live: bool = region_id == "spire_r6" and st != null and not _is_miniboss_defeated(st)
			if mb_live:
				_emit_narration("MINIBOSS_7", "title", 3.2)
			_events.music_mode_requested.emit("island7_boss_p1" if mb_live else "island7_dungeon")


func _on_narration_requested(string_id: String, _style: String, _duration: float) -> void:
	if string_id == "TWIST_HOLLOW":
		var st: LxGameState = _get_state()
		if st != null:
			st.story_flags["twist_hollow_shown"] = true


func _on_beacon_lit(island_id: int, beacon_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.lit_beacons.has(beacon_id):
			st.lit_beacons.append(beacon_id)
		st.story_flags[beacon_id] = true
	if are_all_beacons_lit():
		_trigger_seal_shatter()


func _trigger_seal_shatter() -> void:
	var st: LxGameState = _get_state()
	if st != null:
		if st.broken_seals.has(SEAL_ID):
			return
		st.broken_seals.append(SEAL_ID)
		st.story_flags["seal_broken_7"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER_7", "title", 3.5)
		_emit_narration("DUNGEON_7_NAME", "narration", 3.0)
		_events.save_requested.emit("seal_broken_7")


func _on_enemy_killed(enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	var eid: String = str(enemy.get("enemy_id")) if enemy != null else ""
	if st.region_id == "overworld" and (kind == "hollow_wick" or HOLLOW_ENCOUNTERS.has(eid)):
		if not eid.is_empty():
			st.story_flags[eid + "_cleared"] = true
		var count: int = int(st.story_flags.get("hollow_wick_encounters_cleared", 0)) + 1
		st.story_flags["hollow_wick_encounters_cleared"] = count
		var twist_already: bool = bool(st.story_flags.get("twist_hollow_shown", false)) \
				or bool(st.story_flags.get("trig_7_overworld_trig_twist_hollow_1", false))
		st.story_flags["twist_hollow_shown"] = true
		if not twist_already:
			_emit_narration("TWIST_HOLLOW", "ominous", 4.5)
	elif st.region_id == "spire_r6" and (_is_miniboss_id(kind) or eid == "mini_moonshade_warden"):
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.defeated_bosses.erase(MINI_BOSS_ALT_KIND)
		st.story_flags["defeated_moonshade_warden"] = true
		st.story_flags["moonshade_warden_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_events.music_mode_requested.emit("island7_dungeon")
			_events.save_requested.emit("moonshade_warden_defeated")
	elif st.region_id == "spire_r10" and (kind == "hollow_wick_boss" or eid == "boss_hollow_wick"):
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_hollow_wick_defeated"] = true


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID and boss_id != "hollow_wick_boss" and not _is_miniboss_id(boss_id):
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island7_boss_p2")
		_events.shake_requested.emit(0.28 if _is_miniboss_id(boss_id) else (0.38 if phase >= 3 else 0.32))


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if _is_miniboss_id(boss_id):
		if st != null:
			if not st.defeated_bosses.has(MINI_BOSS_KIND):
				st.defeated_bosses.append(MINI_BOSS_KIND)
			st.defeated_bosses.erase(MINI_BOSS_ALT_KIND)
			st.story_flags["defeated_moonshade_warden"] = true
			st.story_flags["moonshade_warden_defeated"] = true
		return
	if boss_id != BOSS_ID and boss_id != "hollow_wick_boss":
		return
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_hollow_wick_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_hollow_wick_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_7"] = true
		st.story_flags["island_7_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL7_RELIGHT", "title", 4.0)
		_emit_narration("ISL7_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_7")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state


static func _is_miniboss_id(id: String) -> bool:
	return id == MINI_BOSS_KIND or id == MINI_BOSS_ALT_KIND


static func _is_miniboss_defeated(st: LxGameState) -> bool:
	if st == null:
		return false
	return st.defeated_bosses.has(MINI_BOSS_KIND) or st.defeated_bosses.has(MINI_BOSS_ALT_KIND)
