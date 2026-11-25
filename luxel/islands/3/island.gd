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
	"ow_camp",
	"ow_shift_w",
	"ow_shift_e",
	"ow_shift_n",
	"ow_tiny_moss",
	"cave_amber_well",
	"cave_burrow_den",
	"cave_sap_vault",
	"cave_root_cellar",
	"trial_canopy_sprint",
	"trial_moth_scales",
	"sb_mother_root",
	"underroot_r1",
	"underroot_r2",
	"underroot_r3",
	"underroot_r4",
	"underroot_r5",
	"underroot_r6",
	"underroot_r7",
	"underroot_r8",
	"underroot_r9",
	"underroot_r10",
	"underroot_r11",
	"loom_r1",
	"loom_r2",
	"loom_r3",
	"loom_r4",
	"loom_r5",
	"loom_r6",
	"loom_r7",
	"loom_r8",
	"loom_r9",
	"loom_r10",
	"loom_r11",
	"court_r1",
	"court_r2",
	"court_r3",
	"court_r4",
	"oak_r1",
	"oak_r2",
	"oak_r2b",
	"oak_r3",
	"oak_r4",
	"oak_r4b",
	"oak_r5",
	"oak_r5b",
	"oak_r6",
	"oak_r6b",
	"oak_r7",
	"oak_r7b",
	"oak_r8",
	"oak_r8b",
	"oak_r9",
	"oak_r9b",
	"oak_r9c",
	"oak_r10",
]

const MINOR_BOSSES: Array[String] = [
	"hundred_lamps",
	"stag_colossus",
	"thread_keeper",
	"loom_widow",
	"knight_taproot",
	"knight_spindle",
	"briar_arbiter",
]

const GRAND_SEAL_FLAGS: Array[String] = [
	"underroot_done",
	"loom_done",
	"briar_court_done",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _rule: LxIsland3Rule = null


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
	_rule = LxIsland3Rule.new()
	_rule.attach(_events, _state)


func detach() -> void:
	if _rule != null:
		_rule.detach()
		_rule = null
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


func on_region_loaded(region_id: String) -> void:
	if _rule != null:
		_rule.on_region_loaded(region_id)
	if region_id == "overworld":
		_sync_oak_seal_gate()


func get_rule() -> LxIsland3Rule:
	return _rule


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		_wp("wp_3_entry_ws", "overworld", "moss_trailhead", [312.0, 936.0], "waystone", "interact", "ws_3_entry", "Arrive at Thornwood Hollow moss trailhead", ["bolt", "dash", "throw", "prism"], []),
		_wp("wp_3_beacon_1", "overworld", "spore_glade", [152.0, 568.0], "beacon", "light_beacon", "beacon_3_1", "Clear Spore Glade and light Beacon 1", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_1"),
		_wp("wp_3_beacon_2", "overworld", "briar_crossing", [568.0, 568.0], "beacon", "light_beacon", "beacon_3_2", "Clear Briar Crossing and light Beacon 2", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_2"),
		_wp("wp_3_beacon_3", "overworld", "canopy_bridge", [120.0, 312.0], "beacon", "light_beacon", "beacon_3_3", "Clear Canopy Bridge and light Beacon 3", ["bolt", "dash", "throw", "prism"], [], "", "beacon_3_3"),
		_wp("wp_3_enter_oak", "overworld", "hollow_oak_glade", [352.0, 60.0], "exit", "enter_exit", "exit_to_oak", "Enter The Hollow Oak past the shattered ward barrier", ["dash", "throw", "prism"], ["beacon_3_1", "beacon_3_2", "beacon_3_3"], "", "", "oak_r1"),
		_wp("wp_oak_r1_ws", "oak_r1", "oak_r1", [200.0, 120.0], "waystone", "interact", "ws_oak", "Light Hollow Oak Root Hub Waystone", ["dash", "throw", "prism"], []),
		_wp("wp_oak_r2_key1", "oak_r2", "oak_r2", [328.0, 184.0], "wick_key", "collect_key", "wick_key_3_1", "Solve Knotwork Roots blue mirror switch puzzle and take wick_key_3_1", ["dash", "throw", "prism"], [], "", "wick_key_3_1"),
		_wp("wp_oak_r3_combat", "oak_r3", "oak_r3", [392.0, 120.0], "combat_gate", "clear_room", "door_oak_r3_combat", "Clear Spore Gallery Sporecap and Gloam encounter", ["dash", "throw", "prism"], [], "", "oak_r3_cleared"),
		_wp("wp_oak_r4_pool", "oak_r4", "oak_r4", [376.0, 104.0], "switch_door", "open_shutter", "door_oak_r4_shutter", "Unlock Sunshaft Pool key door and ignite three light-pool braziers", ["dash", "throw", "prism"], ["wick_key_3_1"], "", "oak_r4_pool_lit"),
		_wp("wp_oak_r5_shrine_beam", "oak_r5", "oak_r5", [104.0, 104.0], "shrine", "claim_shrine", "shrine_beam", "Claim Beam Shrine and pierce bramble and cracked_wall teaching lane", ["dash", "throw", "prism"], [], "beam"),
		_wp("wp_oak_r6_miniboss", "oak_r6", "oak_r6", [328.0, 128.0], "mini_boss", "defeat_miniboss", "boss_elder_sporecap", "Defeat Elder Sporecap in Spore Crown and claim wick_key_3_2", ["dash", "throw", "prism", "beam"], [], "", "wick_key_3_2"),
		_wp("wp_oak_r7_loom", "oak_r7", "oak_r7", [160.0, 40.0], "switch_door", "open_shutter", "door_oak_r7_shutter", "Unlock Weavers Loom key door and refract Blue Piercing Beam through bramble into blue switch_eye", ["dash", "throw", "prism", "beam"], ["wick_key_3_2"], "", "oak_r7_loom_open"),
		_wp("wp_oak_r8_bastion", "oak_r8", "oak_r8", [192.0, 24.0], "combat_gate", "clear_room", "door_oak_r8_combat", "Clear Bramble Bastion Bramble Knight and Gloam encounter", ["dash", "throw", "prism", "beam"], [], "", "oak_r8_cleared"),
		_wp("wp_oak_r9_boss_key", "oak_r9", "oak_r9", [392.0, 72.0], "keepers_flame", "collect_key", "keepers_flame_3", "Solve Keepers Amber Vault Blue Transformer and Beam synthesis for keepers_flame_3 and unlock door_boss_3", ["dash", "throw", "prism", "beam"], [], "", "keepers_flame_3"),
		_wp("wp_oak_r10_boss", "oak_r10", "oak_r10", [240.0, 144.0], "boss", "defeat_boss", "boss_briar_matron", "Defeat the Briar Matron in The Hollow Crown", ["dash", "throw", "prism", "beam"], ["keepers_flame_3"], "", "boss_briar_matron_defeated"),
		_wp("wp_oak_r10_great_lamp", "oak_r10", "oak_r10", [240.0, 56.0], "great_lamp", "light_great_lamp", "great_lamp_3", "Relight Great Lamp 3 to wake Thornwood Hollow", ["dash", "throw", "prism", "beam"], ["boss_briar_matron_defeated"], "", "island_3_relit"),
		_wp("wp_3_bridge_to_island_4", "oak_r10", "oak_r10", [472.0, 136.0], "exit", "enter_exit", "exit_oak_r10_island4", "Cross Bridge of Light to Island 4 Mirefen Gardens", ["beam"], ["island_3_relit"], "", "", "overworld", 4),
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


func is_grand_seal_ready() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	if _is_legacy_seal_open(st):
		return true
	if not are_all_beacons_lit():
		return false
	for fl: String in GRAND_SEAL_FLAGS:
		if not bool(st.story_flags.get(fl, false)):
			return false
	return true


func _is_legacy_seal_open(st: LxGameState) -> bool:
	if st == null:
		return false
	return (
		st.broken_seals.has(SEAL_ID)
		or bool(st.story_flags.get("seal_broken_3", false))
		or bool(st.story_flags.get("isl3_oak_entered", false))
		or st.opened_doors.has("door_dungeon_3")
	)


func _migrate_legacy_seal(st: LxGameState) -> void:
	if st == null:
		return
	if _is_legacy_seal_open(st):
		st.story_flags["seal_broken_3"] = true
		st.story_flags["grand_seal_3_ready"] = true
		if not st.broken_seals.has(SEAL_ID):
			st.broken_seals.append(SEAL_ID)
		if not st.opened_doors.has("door_dungeon_3"):
			st.opened_doors.append("door_dungeon_3")


func _sync_oak_seal_gate() -> void:
	var st: LxGameState = _get_state()
	if st == null or not (Lx.world is LxRegionLoader):
		return
	var world: LxRegionLoader = Lx.world as LxRegionLoader
	var door_node: LxInteractable = world.find_interactable("door_dungeon_3")
	if _is_legacy_seal_open(st):
		_migrate_legacy_seal(st)
		if door_node is LxDoor:
			(door_node as LxDoor).opened = true
			door_node.queue_redraw()


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	_migrate_legacy_seal(st)
	if region_id == "overworld":
		if st != null and not bool(st.story_flags.get("isl3_arrived", false)):
			st.story_flags["isl3_arrived"] = true
			_emit_narration("ISL3_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.sfx_requested.emit("prop_rustle", Vector2.ZERO, false)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "ow_camp":
		if st != null and not bool(st.story_flags.get("isl3_camp_visited", false)):
			st.story_flags["isl3_camp_visited"] = true
			_emit_narration("ISL3_CAMP_NAME", "title", 3.0)
		elif st != null and st.relit_islands.has(ISLAND_ID) and not bool(st.story_flags.get("isl3_camp_relit_seen", false)):
			st.story_flags["isl3_camp_relit_seen"] = true
			_emit_narration("ISL3_CAMP_RELIT_NOTE", "narration", 3.8)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("ow_shift_"):
		if region_id == "ow_shift_w" and st != null and not bool(st.story_flags.get("isl3_shift_seen", false)):
			st.story_flags["isl3_shift_seen"] = true
			_emit_narration("ISL3_SHIFT_W_NAME", "title", 3.0)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "ow_tiny_moss":
		if st != null:
			st.story_flags["quest:hide:hollow_stump"] = true
		if _events != null:
			_events.music_mode_requested.emit("isl3_underroot")
	elif region_id.begins_with("cave_"):
		if _events != null:
			_events.music_mode_requested.emit("island3_dungeon")
	elif region_id.begins_with("trial_"):
		if _events != null:
			_events.music_mode_requested.emit("isl3_setpiece")
	elif region_id == "sb_mother_root":
		var mr_live: bool = st == null or (not st.defeated_bosses.has("mother_root") and not bool(st.story_flags.get("mother_root_defeated", false)))
		if mr_live:
			_emit_narration("ISL3_SB_MOTHER_NAME", "title", 3.2)
		if _events != null:
			_events.music_mode_requested.emit("superboss_a" if mr_live else "explore")
	elif region_id.begins_with("court_"):
		if _events != null:
			var ct_boss_live: bool = (
				(region_id == "court_r2" and st != null and not st.defeated_bosses.has("knight_taproot") and not bool(st.story_flags.get("court_taproot_done", false)))
				or (region_id == "court_r3" and st != null and not st.defeated_bosses.has("knight_spindle") and not bool(st.story_flags.get("court_spindle_done", false)))
				or (region_id == "court_r4" and st != null and not st.defeated_bosses.has("briar_arbiter") and not bool(st.story_flags.get("briar_court_done", false)))
			)
			_events.music_mode_requested.emit("isl3_boss_minor_p1" if ct_boss_live else "isl3_setpiece")
	elif region_id.begins_with("underroot_"):
		if _events != null:
			var ur_boss_live: bool = (
				(region_id == "underroot_r11" and st != null and not st.defeated_bosses.has("hundred_lamps"))
				or (region_id == "underroot_r6" and st != null and not st.defeated_bosses.has("stag_colossus"))
			)
			_events.music_mode_requested.emit("isl3_boss_minor_p1" if ur_boss_live else "isl3_underroot")
	elif region_id.begins_with("loom_"):
		if _events != null:
			var lm_boss_live: bool = (
				(region_id == "loom_r11" and st != null and not st.defeated_bosses.has("loom_widow"))
				or (region_id == "loom_r6" and st != null and not st.defeated_bosses.has("thread_keeper"))
			)
			_events.music_mode_requested.emit("isl3_boss_minor_p1" if lm_boss_live else "isl3_loom")
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
				_events.sfx_requested.emit("prop_chime", Vector2.ZERO, false)
		if _events != null:
			var mb_live: bool = region_id == "oak_r6" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			if mb_live:
				_emit_narration("MINIBOSS_3", "title", 3.2)
			var oak_cue: String = "island3_boss_p1" if mb_live else ("isl3_underroot" if region_id == "oak_r4b" else ("island3_combat" if region_id == "oak_r9b" else "island3_dungeon"))
			_events.music_mode_requested.emit(oak_cue)


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
	if is_grand_seal_ready():
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
		_emit_narration("CUE_SEAL_SHATTER_3", "title", 3.5)
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
			_events.save_requested.emit("elder_sporecap_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id == BOSS_ID or boss_id == MINI_BOSS_KIND:
		if phase >= 2 and _events != null:
			_events.music_mode_requested.emit("island3_boss_p2")
			_events.shake_requested.emit(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))
	elif boss_id == "mother_root":
		if phase >= 2 and _events != null:
			_events.shake_requested.emit(0.32 if phase >= 3 else 0.26)
	elif MINOR_BOSSES.has(boss_id):
		if phase >= 2 and _events != null:
			_events.music_mode_requested.emit("isl3_boss_minor_p2")
			_events.shake_requested.emit(0.30 if phase >= 3 else 0.24)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id == "mother_root":
		if st != null:
			if not st.defeated_bosses.has("mother_root"):
				st.defeated_bosses.append("mother_root")
			st.story_flags["mother_root_defeated"] = true
		if _events != null:
			_events.music_mode_requested.emit("explore")
			_events.save_requested.emit("mother_root_defeated")
		return
	if MINOR_BOSSES.has(boss_id):
		if st != null and not st.defeated_bosses.has(boss_id):
			st.defeated_bosses.append(boss_id)
		if _events != null:
			var post_cue: String = "isl3_underroot" if boss_id in ["stag_colossus", "hundred_lamps"] else ("isl3_loom" if boss_id in ["thread_keeper", "loom_widow"] else "isl3_setpiece")
			_events.music_mode_requested.emit(post_cue)
		if is_grand_seal_ready():
			_trigger_seal_shatter()
		return
	if boss_id != BOSS_ID:
		return
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
	if _rule != null:
		_rule.set_clearing_pinned("w", true)
		_rule.set_clearing_pinned("e", true)
		_rule.set_clearing_pinned("n", true)
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL3_RELIGHT", "title", 4.0)
		_emit_narration("ISL3_RELIT_NOTE", "narration", 4.0)
		_emit_narration("ISL3_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_3")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
