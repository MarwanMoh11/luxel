class_name LxIsland3
extends RefCounted
## Island 3 (Thornwood Hollow) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 3
const SEAL_ID: String = "hollow_oak_seal"
const BOSS_ID: String = "briar_matron"
const MINI_BOSS_KIND: String = "elder_sporecap"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_3_1",
	"beacon_3_2",
	"beacon_3_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"oak_r1",
	"oak_r2",
	"oak_r3",
	"oak_r4",
	"oak_r5",
	"oak_r6",
	"oak_r7",
	"oak_r8",
	"oak_r9",
	"oak_r10",
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
		_wp("wp_3_entry_ws", "overworld", "moss_trailhead", [312.0, 936.0], "waystone", "interact", "ws_3_entry", "Arrive at Thornwood Hollow moss trailhead", ["bolt", "dash", "throw", "prism"], []),
		_wp("wp_3_beacon_1", "overworld", "spore_glade", [152.0, 552.0], "beacon", "light_beacon", "beacon_3_1", "Clear Spore Glade and light Beacon 1", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_1"),
		_wp("wp_3_beacon_2", "overworld", "briar_crossing", [584.0, 584.0], "beacon", "light_beacon", "beacon_3_2", "Clear Briar Crossing and light Beacon 2", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_2"),
		_wp("wp_3_beacon_3", "overworld", "canopy_bridge", [120.0, 312.0], "beacon", "light_beacon", "beacon_3_3", "Clear Canopy Bridge and light Beacon 3", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_3"),
		_wp("wp_3_enter_oak", "overworld", "hollow_oak_glade", [352.0, 60.0], "exit", "enter_exit", "exit_to_oak", "Enter The Hollow Oak past the shattered ward barrier", ["dash", "throw", "prism"], ["beacon_3_1", "beacon_3_2", "beacon_3_3"], "", "", "oak_r1"),
		_wp("wp_oak_r1_ws", "oak_r1", "oak_r1", [208.0, 120.0], "waystone", "interact", "ws_oak", "Light Hollow Oak Root Vestibule Waystone", ["dash", "throw", "prism"], []),
		_wp("wp_oak_r2_key1", "oak_r2", "oak_r2", [280.0, 136.0], "wick_key", "collect_key", "wick_key_3_1", "Solve Knotwork Roots mirror switch puzzle and take wick_key_3_1", ["dash", "throw", "prism"], [], "", "wick_key_3_1"),
		_wp("wp_oak_r3_combat", "oak_r3", "oak_r3", [296.0, 88.0], "combat_gate", "clear_room", "door_oak_r3_combat", "Clear Spore Gallery Sporecap and Gloam encounter", ["dash", "throw", "prism"], [], "", "oak_r3_cleared"),
		_wp("wp_oak_r4_pool", "oak_r4", "oak_r4", [296.0, 88.0], "switch_door", "open_shutter", "door_oak_r4_shutter", "Unlock Sunshaft Pool key door and ignite three light-pool braziers", ["dash", "throw", "prism"], ["wick_key_3_1"], "", "oak_r4_pool_lit"),
		_wp("wp_oak_r5_shrine_beam", "oak_r5", "oak_r5", [104.0, 88.0], "shrine", "claim_shrine", "shrine_beam", "Claim Beam Shrine and pierce bramble and cracked_wall teaching lane", ["dash", "throw", "prism"], [], "beam"),
		_wp("wp_oak_r6_miniboss", "oak_r6", "oak_r6", [328.0, 128.0], "mini_boss", "defeat_miniboss", "boss_elder_sporecap", "Defeat Elder Sporecap in Spore Crown and claim wick_key_3_2", ["dash", "throw", "prism", "beam"], [], "", "wick_key_3_2"),
		_wp("wp_oak_r7_loom", "oak_r7", "oak_r7", [160.0, 24.0], "switch_door", "open_shutter", "door_oak_r7_shutter", "Unlock Weavers Loom key door and pierce web, cracked_wall, and switch_eye", ["dash", "throw", "prism", "beam"], ["wick_key_3_2"], "", "oak_r7_loom_open"),
		_wp("wp_oak_r8_bastion", "oak_r8", "oak_r8", [160.0, 24.0], "combat_gate", "clear_room", "door_oak_r8_combat", "Clear Bramble Bastion Bramble Knight and Gloam encounter", ["dash", "throw", "prism", "beam"], [], "", "oak_r8_cleared"),
		_wp("wp_oak_r9_boss_key", "oak_r9", "oak_r9", [264.0, 72.0], "keepers_flame", "collect_key", "keepers_flame_3", "Solve Keepers Amber Vault for keepers_flame_3 and unlock door_boss_3", ["dash", "throw", "prism", "beam"], [], "", "keepers_flame_3"),
		_wp("wp_oak_r10_boss", "oak_r10", "oak_r10", [240.0, 144.0], "boss", "defeat_boss", "boss_briar_matron", "Defeat the Briar Matron in The Hollow Crown", ["dash", "throw", "prism", "beam"], ["keepers_flame_3"], "", "boss_briar_matron_defeated"),
		_wp("wp_oak_r10_great_lamp", "oak_r10", "oak_r10", [240.0, 56.0], "great_lamp", "light_great_lamp", "great_lamp_3", "Relight Great Lamp 3 to wake Thornwood Hollow", ["dash", "throw", "prism", "beam"], ["boss_briar_matron_defeated"], "", "island_3_relit"),
		_wp("wp_3_bridge_to_island_4", "oak_r10", "oak_r10", [472.0, 144.0], "exit", "enter_exit", "exit_oak_r10_island4", "Cross Bridge of Light to Island 4 Mirefen Gardens", ["beam"], ["island_3_relit"], "", "", "overworld", 4),
	]


static func _wp(
	wp_id: String,
	region: String,
	zone: String,
	pos: Array,
	kind: String,
	action: String,
	target_id: String,
	desc: String,
	req_moves: Array,
	req_flags: Array,
	grants_move: String = "",
	grants_flag: String = "",
	to_region: String = "",
	to_island: int = 0
) -> Dictionary:
	var d: Dictionary = {
		"id": wp_id,
		"region": region,
		"zone": zone,
		"pos": pos,
		"kind": kind,
		"action": action,
		"target_id": target_id,
		"target": target_id,
		"desc": desc,
		"requires_moves": req_moves,
		"requires_flags": req_flags,
	}
	if not grants_move.is_empty():
		d["grants_move"] = grants_move
	if not grants_flag.is_empty():
		d["grants_flag"] = grants_flag
	if not to_region.is_empty():
		d["to_region"] = to_region
	if to_island > 0:
		d["to_island"] = to_island
	return d


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
		if st != null and not bool(st.story_flags.get("isl3_arrived", false)):
			st.story_flags["isl3_arrived"] = true
			_emit_narration("ISL3_ARRIVAL", "narration", 4.0)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "oak_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_MATRON", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island3_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("oak_"):
		if region_id == "oak_r1" and st != null and not bool(st.story_flags.get("isl3_oak_entered", false)):
			st.story_flags["isl3_oak_entered"] = true
			_emit_narration("DUNGEON_3_NAME", "title", 3.5)
		if _events != null:
			var mb_live: bool = region_id == "oak_r6" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			_events.music_mode_requested.emit("island3_boss_p1" if mb_live else "island3_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_beam" or move_id == "beam":
		_emit_narration("MOVE_BEAM_NAME", "title", 3.2)
		_events.prompt_requested.emit("PROMPT_BEAM", "lx_beam", 6.0)
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
		st.story_flags["seal_broken_3"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_emit_narration("DUNGEON_3_NAME", "narration", 3.0)
		_events.save_requested.emit("seal_broken_3")


func _on_enemy_killed(_enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	if st.region_id == "oak_r6" and kind == MINI_BOSS_KIND:
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["elder_sporecap_defeated"] = true
		st.story_flags["boss_elder_sporecap_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_events.music_mode_requested.emit("island3_dungeon")
			_emit_narration("CUE_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("elder_sporecap_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID and boss_id != MINI_BOSS_KIND:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island3_boss_p2")
		_events.shake_requested.emit(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))
		_emit_narration("CUE_PHASE_3" if phase >= 3 else "CUE_PHASE_2", "warning", 3.5)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID or boss_id != BOSS_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_briar_matron_defeated"] = true
		st.story_flags["briar_matron_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_briar_matron_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_3"] = true
		st.story_flags["island_3_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL3_RELIGHT", "title", 4.0)
		_emit_narration("ISL3_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_3")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
