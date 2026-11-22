class_name LxIsland2
extends RefCounted
## Island 2 (Tidewater Harbor) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 2
const SEAL_ID: String = "lighthouse_seal"
const BOSS_ID: String = "lighthouse_hermit"
const MINI_BOSS_KIND: String = "tide_captain"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_2_1",
	"beacon_2_2",
	"beacon_2_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"lighthouse_r1",
	"lighthouse_r2",
	"lighthouse_r3",
	"lighthouse_r4",
	"lighthouse_r5",
	"lighthouse_r6",
	"lighthouse_r7",
	"lighthouse_r8",
	"lighthouse_r9",
	"lighthouse_r10",
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
		_wp("wp_2_entry_ws", "overworld", "harbor_landing", [104.0, 296.0], "waystone", "interact", "ws_2_entry", "Arrive at Tidewater Harbor landing pier", ["bolt", "dash", "throw"], []),
		_wp("wp_2_beacon_1", "overworld", "drydock_quays", [200.0, 88.0], "beacon", "light_beacon", "beacon_2_1", "Clear Drydock Quays and light Beacon 1", ["bolt", "dash", "throw"], [], "", "beacon_2_1"),
		_wp("wp_2_beacon_2", "overworld", "tide_causeway", [760.0, 184.0], "beacon", "light_beacon", "beacon_2_2", "Cross Tide Causeway and light Beacon 2", ["bolt", "dash", "throw"], [], "", "beacon_2_2"),
		_wp("wp_2_beacon_3", "overworld", "breakwater_reef", [1176.0, 88.0], "beacon", "light_beacon", "beacon_2_3", "Clear Breakwater Reef and light Beacon 3", ["bolt", "dash", "throw"], [], "", "beacon_2_3"),
		_wp("wp_2_enter_lighthouse", "overworld", "lighthouse_promontory", [1536.0, 108.0], "exit", "enter_exit", "exit_to_lighthouse", "Enter The Lighthouse past the shattered ward barrier", ["dash", "throw"], ["beacon_2_1", "beacon_2_2", "beacon_2_3"], "", "", "lighthouse_r1"),
		_wp("wp_lh_r1_ws", "lighthouse_r1", "lighthouse_r1", [176.0, 128.0], "waystone", "interact", "ws_lighthouse", "Light Lighthouse Entry Hall Waystone", ["dash", "throw"], []),
		_wp("wp_lh_r2_key1", "lighthouse_r2", "lighthouse_r2", [264.0, 40.0], "wick_key", "collect_key", "wick_key_2_1", "Solve Tide Lock switch puzzle and take wick_key_2_1", ["dash", "throw"], [], "", "wick_key_2_1"),
		_wp("wp_lh_r3_combat", "lighthouse_r3", "lighthouse_r3", [296.0, 88.0], "combat_gate", "clear_room", "door_lh_r3_combat", "Clear Pier Ward enemies to open combat gate", ["dash", "throw"], [], "", "lh_r3_cleared"),
		_wp("wp_lh_r4_atrium", "lighthouse_r4", "lighthouse_r4", [296.0, 88.0], "switch_door", "open_shutter", "door_lh_r4_shutter", "Unlock Glass Atrium key door and light twin chasm braziers", ["dash", "throw"], ["wick_key_2_1"], "", "lh_r4_shutter_open"),
		_wp("wp_lh_r5_shrine_prism", "lighthouse_r5", "lighthouse_r5", [152.0, 112.0], "shrine", "claim_shrine", "shrine_prism", "Claim Prism Shrine and reflect bolt off mirror into switch_eye", ["dash", "throw"], [], "prism"),
		_wp("wp_lh_r6_miniboss", "lighthouse_r6", "lighthouse_r6", [344.0, 112.0], "mini_boss", "defeat_miniboss", "boss_tide_captain", "Defeat Tide Captain on Captains Deck and claim wick_key_2_2", ["dash", "throw", "prism"], [], "", "wick_key_2_2"),
		_wp("wp_lh_r7_mirror_gallery", "lighthouse_r7", "lighthouse_r7", [160.0, 24.0], "switch_door", "open_shutter", "door_lh_r7_shutter", "Unlock Mirror Gallery key door and bank Prism bolt into switch_eye", ["dash", "throw", "prism"], ["wick_key_2_2"], "", "lh_r7_gallery_open"),
		_wp("wp_lh_r8_belfry", "lighthouse_r8", "lighthouse_r8", [160.0, 24.0], "combat_gate", "clear_room", "door_lh_r8_combat", "Clear Gulls Belfry encounter using brass mirrors", ["dash", "throw", "prism"], [], "", "lh_r8_cleared"),
		_wp("wp_lh_r9_boss_key", "lighthouse_r9", "lighthouse_r9", [264.0, 88.0], "keepers_flame", "collect_key", "keepers_flame_2", "Solve Keepers Prism Vault for keepers_flame_2 and unlock door_boss_2", ["dash", "throw", "prism"], [], "", "keepers_flame_2"),
		_wp("wp_lh_r10_boss", "lighthouse_r10", "lighthouse_r10", [224.0, 144.0], "boss", "defeat_boss", "boss_lighthouse_hermit", "Defeat the Lighthouse Hermit in the Lantern Room", ["dash", "throw", "prism"], ["keepers_flame_2"], "", "boss_lighthouse_hermit_defeated"),
		_wp("wp_lh_r10_great_lamp", "lighthouse_r10", "lighthouse_r10", [224.0, 56.0], "great_lamp", "light_great_lamp", "great_lamp_2", "Relight Great Lamp 2 to wake Tidewater Harbor", ["dash", "throw", "prism"], ["boss_lighthouse_hermit_defeated"], "", "island_2_relit"),
		_wp("wp_2_bridge_to_island_3", "lighthouse_r10", "lighthouse_r10", [440.0, 144.0], "exit", "enter_exit", "exit_lh_r10_island3", "Cross Bridge of Light to Island 3 Thornwood Hollow", ["prism"], ["island_2_relit"], "", "", "overworld", 3),
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
		if st != null and not bool(st.story_flags.get("isl2_arrived", false)):
			st.story_flags["isl2_arrived"] = true
			_emit_narration("ISL2_ARRIVAL", "narration", 4.0)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "lighthouse_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_HERMIT", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island2_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("lighthouse_"):
		if region_id == "lighthouse_r1" and st != null and not bool(st.story_flags.get("isl2_lighthouse_entered", false)):
			st.story_flags["isl2_lighthouse_entered"] = true
			_emit_narration("DUNGEON_2_NAME", "title", 3.5)
		if _events != null:
			var mb_live: bool = region_id == "lighthouse_r6" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			_events.music_mode_requested.emit("island2_boss_p1" if mb_live else "island2_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_prism" or move_id == "prism":
		_emit_narration("MOVE_PRISM_NAME", "title", 3.2)
		_events.prompt_requested.emit("PROMPT_PRISM", "", 6.0)
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
		st.story_flags["seal_broken_2"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.28)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_emit_narration("DUNGEON_2_NAME", "narration", 3.0)
		_events.save_requested.emit("seal_broken_2")


func _on_enemy_killed(_enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	if st.region_id == "lighthouse_r6" and kind == MINI_BOSS_KIND:
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["tide_captain_defeated"] = true
		st.story_flags["boss_tide_captain_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_events.music_mode_requested.emit("island2_dungeon")
			_emit_narration("CUE_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("tide_captain_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID and boss_id != MINI_BOSS_KIND:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island2_boss_p2")
		_events.shake_requested.emit(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))
		_emit_narration("CUE_PHASE_3" if phase >= 3 else "CUE_PHASE_2", "warning", 3.5)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID or boss_id != BOSS_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_lighthouse_hermit_defeated"] = true
		st.story_flags["lighthouse_hermit_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_lighthouse_hermit_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_2"] = true
		st.story_flags["island_2_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL2_RELIGHT", "title", 4.0)
		_emit_narration("ISL2_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_2")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
