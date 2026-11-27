class_name LxIsland2
extends RefCounted
## Island 2 (Tidewater Harbor) progression beats, story hooks, tidal gating, region list, and main-path waypoints.

const ISLAND_ID: int = 2
const SEAL_ID: String = "lighthouse_seal"
const BOSS_ID: String = "lighthouse_hermit"
const MINI_BOSS_KIND: String = "tide_captain"
const SUPERBOSS_ID: String = "undertow"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_2_1",
	"beacon_2_2",
	"beacon_2_3",
]

const REQUIRED_EPIC_DUNGEONS: Array[Dictionary] = [
	{"id": "galleon", "flag": "galleon_done"},
	{"id": "locks", "flag": "locks_done"},
	{"id": "leviathan", "flag": "leviathan_done"},
]

const OVERWORLD_REGIONS: Array[String] = [
	"overworld",
	"ow_shoals_west",
	"ow_canal_south",
	"ow_open_sound",
	"ow_boathouse",
]

const CAVE_REGIONS: Array[String] = [
	"cave_rib_vault",
	"cave_bell_cistern",
	"cave_smuggler_cellar",
	"cave_rooftop_belfry",
]

const REGIONS: Array[String] = [
	"overworld",
	"ow_shoals_west",
	"ow_canal_south",
	"ow_open_sound",
	"ow_boathouse",
	"cave_rib_vault",
	"cave_bell_cistern",
	"cave_smuggler_cellar",
	"cave_rooftop_belfry",
	"cave_undertow_maw",
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
	"lighthouse_r11",
	"lighthouse_r12",
	"lighthouse_r13",
	"lighthouse_r14",
	"lighthouse_r15",
	"lighthouse_r16",
	"lighthouse_r17",
	"lighthouse_r18",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _rule: LxIsland2Rule = null


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
	_rule = LxIsland2Rule.new()
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
		_sync_lighthouse_seal_gate()
	if region_id in OVERWORLD_REGIONS:
		_apply_relit_harbor_state()
	_check_leviathan_awakening()


func get_rule() -> LxIsland2Rule:
	return _rule


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		_wp("wp_2_entry_ws", "overworld", "harbor_landing", [104.0, 296.0], "waystone", "interact", "ws_2_entry", "Arrive at Tidewater Harbor landing pier", ["bolt", "dash", "throw"], []),
		_wp("wp_2_beacon_1", "overworld", "drydock_quays", [200.0, 88.0], "beacon", "light_beacon", "beacon_2_1", "Clear Drydock Quays and light Beacon 1", ["bolt", "dash", "throw"], [], "", "beacon_2_1"),
		_wp("wp_2_beacon_2", "overworld", "tide_causeway", [760.0, 120.0], "beacon", "light_beacon", "beacon_2_2", "Cross Tide Causeway and light Beacon 2", ["bolt", "dash", "throw"], [], "", "beacon_2_2"),
		_wp("wp_2_beacon_3", "overworld", "breakwater_reef", [872.0, 520.0], "beacon", "light_beacon", "beacon_2_3", "Clear Breakwater Reef and light Beacon 3", ["bolt", "dash", "throw"], [], "", "beacon_2_3"),
		_wp("wp_2_enter_lighthouse", "overworld", "lighthouse_promontory", [1040.0, 108.0], "exit", "enter_exit", "exit_to_lighthouse", "Enter The Lighthouse past the shattered ward barrier", ["dash", "throw"], ["beacon_2_1", "beacon_2_2", "beacon_2_3"], "", "", "lighthouse_r1"),
		_wp("wp_lh_r1_ws", "lighthouse_r1", "lighthouse_r1", [184.0, 136.0], "waystone", "interact", "ws_lighthouse", "Light Lighthouse Cyclic Hub Waystone", ["dash", "throw"], []),
		_wp("wp_lh_r2_key1", "lighthouse_r2", "lighthouse_r2", [312.0, 72.0], "wick_key", "collect_key", "wick_key_2_1", "Solve Tide Lock Blue Transformer puzzle and take wick_key_2_1", ["dash", "throw"], [], "", "wick_key_2_1"),
		_wp("wp_lh_r3_combat", "lighthouse_r3", "lighthouse_r3", [392.0, 120.0], "combat_gate", "clear_room", "door_lh_r3_combat", "Clear Pier Ward enemies to open combat gate", ["dash", "throw"], [], "", "lh_r3_cleared"),
		_wp("wp_lh_r4_atrium", "lighthouse_r4", "lighthouse_r4", [360.0, 104.0], "switch_door", "open_shutter", "door_lh_r4_shutter", "Unlock Glass Atrium key door and light twin chasm braziers", ["dash", "throw"], ["wick_key_2_1"], "", "lh_r4_shutter_open"),
		_wp("wp_lh_r5_shrine_prism", "lighthouse_r5", "lighthouse_r5", [120.0, 136.0], "shrine", "claim_shrine", "shrine_prism", "Claim Prism Shrine and solve dual Blue Transformer Rotunda", ["dash", "throw"], [], "prism"),
		_wp("wp_lh_r6_miniboss", "lighthouse_r6", "lighthouse_r6", [352.0, 128.0], "mini_boss", "defeat_miniboss", "boss_tide_captain", "Defeat Tide Captain on Flooded Drydock Basin and claim wick_key_2_2", ["dash", "throw", "prism"], [], "", "wick_key_2_2"),
		_wp("wp_lh_r7_mirror_gallery", "lighthouse_r7", "lighthouse_r7", [192.0, 40.0], "switch_door", "open_shutter", "door_lh_r7_shutter", "Unlock Mirror Gallery key door and solve Blue Portal & Transformer puzzle", ["dash", "throw", "prism"], ["wick_key_2_2"], "", "lh_r7_gallery_open"),
		_wp("wp_lh_r8_belfry", "lighthouse_r8", "lighthouse_r8", [224.0, 24.0], "combat_gate", "clear_room", "door_lh_r8_combat", "Clear Gulls Belfry encounter using movable Blue Transformers", ["dash", "throw", "prism"], [], "", "lh_r8_cleared"),
		_wp("wp_lh_r9_boss_key", "lighthouse_r9", "lighthouse_r9", [392.0, 120.0], "keepers_flame", "collect_key", "keepers_flame_2", "Solve Upper Prism Nave for keepers_flame_2 and unlock door_boss_2", ["dash", "throw", "prism"], [], "", "keepers_flame_2"),
		_wp("wp_lh_r10_boss", "lighthouse_r10", "lighthouse_r10", [224.0, 144.0], "boss", "defeat_boss", "boss_lighthouse_hermit", "Defeat the Lighthouse Hermit in the Circular Fresnel Crown", ["dash", "throw", "prism"], ["keepers_flame_2"], "", "boss_lighthouse_hermit_defeated"),
		_wp("wp_lh_r10_great_lamp", "lighthouse_r10", "lighthouse_r10", [224.0, 56.0], "great_lamp", "light_great_lamp", "great_lamp_2", "Relight Great Lamp 2 to wake Tidewater Harbor", ["dash", "throw", "prism"], ["boss_lighthouse_hermit_defeated"], "", "island_2_relit"),
		_wp("wp_2_bridge_to_island_3", "lighthouse_r10", "lighthouse_r10", [440.0, 136.0], "exit", "enter_exit", "exit_lh_r10_island3", "Cross Bridge of Light to Island 3 Thornwood Hollow", ["prism"], ["island_2_relit"], "", "", "overworld", 3),
	]


func get_epic_overworld_waypoints() -> Array[Dictionary]:
	return [
		_wp("wp_2_skiff_cut", "overworld", "harbor_landing", [152.0, 392.0], "skiff_tether", "interact", "tether_skiff_harbor", "Untether the Harbor Skiff at low tide", ["bolt", "dash", "throw"], [], "", "skiff_unlocked"),
		_wp("wp_2_tide_organ", "overworld", "harbor_landing", [280.0, 264.0], "state_lever", "shoot", "organ_harbor_w", "Sound the Quay Tide Organ to shift harbor tides", ["bolt", "dash", "throw"], ["skiff_unlocked"], "", "tide_organ_used"),
		_wp("wp_2_shoals_ws", "ow_shoals_west", "shoals_east", [680.0, 264.0], "waystone", "interact", "ws_2_shoals", "Sail West to Shipwreck Shoals and The Drowned Galleon", ["bolt", "dash", "throw"], ["skiff_unlocked"]),
		_wp("wp_2_canal_ws", "ow_canal_south", "canal_quarter", [280.0, 88.0], "waystone", "interact", "ws_2_canal", "Sail South to Canal Quarter, Boathouse Camp, and The Smugglers Locks", ["bolt", "dash", "throw"], ["skiff_unlocked"]),
		_wp("wp_2_sound_ws", "ow_open_sound", "outer_sound", [104.0, 344.0], "waystone", "interact", "ws_2_sound", "Sail North-East to Outer Sound for Flood Regatta, Leviathan, and Undertow Maw", ["bolt", "dash", "throw"], ["skiff_unlocked"]),
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


func has_legacy_seal_pass() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	return st.broken_seals.has(SEAL_ID) \
		or st.opened_doors.has("door_dungeon_2") \
		or bool(st.story_flags.get("seal_broken_2", false))


func are_all_beacons_lit() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	for bid: String in REQUIRED_BEACONS:
		if not st.lit_beacons.has(bid) and not bool(st.story_flags.get(bid, false)):
			return false
	return true


func are_all_epic_dungeons_live() -> bool:
	if Lx.packs == null:
		return false
	for spec: Dictionary in REQUIRED_EPIC_DUNGEONS:
		var dm: Dictionary = Lx.packs.dungeon(str(spec["id"]))
		if dm.is_empty() or bool(dm.get("debug_only", false)):
			return false
	return true


func is_epic_dungeon_done(dungeon_id: String, done_flag: String) -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	return bool(st.story_flags.get(done_flag, false)) \
		or bool(st.story_flags.get("dungeon_done:" + dungeon_id, false))


func are_all_seal_requirements_met() -> bool:
	if has_legacy_seal_pass():
		return true
	if not are_all_beacons_lit():
		return false
	if are_all_epic_dungeons_live():
		for spec: Dictionary in REQUIRED_EPIC_DUNGEONS:
			if not is_epic_dungeon_done(str(spec["id"]), str(spec["flag"])):
				return false
	return true


func _sync_lighthouse_seal_gate() -> void:
	var st: LxGameState = _get_state()
	if st == null or not (Lx.world is LxRegionLoader):
		return
	var world: LxRegionLoader = Lx.world as LxRegionLoader
	var door_node: LxInteractable = world.find_interactable("door_dungeon_2")
	# Legacy saves that already broke lighthouse_seal stay passed permanently.
	if has_legacy_seal_pass():
		if not st.broken_seals.has(SEAL_ID):
			st.broken_seals.append(SEAL_ID)
		if not st.opened_doors.has("door_dungeon_2"):
			st.opened_doors.append("door_dungeon_2")
		if door_node is LxDoor:
			(door_node as LxDoor).opened = true
			door_node.queue_redraw()
		return
	# Once Galleon + Locks + Leviathan are all live, enforce full bible gating on door_dungeon_2.
	if are_all_epic_dungeons_live() and door_node is LxDoor:
		var d: LxDoor = door_node as LxDoor
		for spec: Dictionary in REQUIRED_EPIC_DUNGEONS:
			var fl: String = str(spec["flag"])
			if not d.required_flags.has(fl) and not is_epic_dungeon_done(str(spec["id"]), fl):
				d.required_flags.append(fl)


func _apply_relit_harbor_state() -> void:
	var st: LxGameState = _get_state()
	if st == null or not (st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("island_2_relit", false))):
		return
	if not (Lx.world is LxRegionLoader):
		return
	var world: LxRegionLoader = Lx.world as LxRegionLoader
	for it: LxInteractable in world.get_interactables():
		if it != null and is_instance_valid(it) and it.kind == "road_lamp":
			if it.get("lit") is bool and not bool(it.get("lit")):
				it.set("lit", true)
				it.queue_redraw()


func _check_leviathan_awakening() -> void:
	var st: LxGameState = _get_state()
	if st == null or bool(st.story_flags.get("isl2_leviathan_awakened", false)):
		return
	if is_epic_dungeon_done("galleon", "galleon_done") and is_epic_dungeon_done("locks", "locks_done"):
		st.story_flags["isl2_leviathan_awakened"] = true
		_emit_narration("ISL2_LEV_WAKE", "title", 3.6)
		if _events != null:
			_events.sfx_requested.emit("whale_groan_low", Vector2.ZERO, false)
			_emit_shake(0.24)


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if region_id == "overworld":
		if st != null and not bool(st.story_flags.get("isl2_arrived", false)):
			st.story_flags["isl2_arrived"] = true
			_emit_narration("ISL2_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.sfx_requested.emit("lighthouse_toll", Vector2.ZERO, false)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id in OVERWORLD_REGIONS:
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id in CAVE_REGIONS:
		if _events != null:
			_events.music_mode_requested.emit("island2_dungeon")
	elif region_id == "cave_undertow_maw":
		if st != null and not st.defeated_bosses.has(SUPERBOSS_ID) and not bool(st.story_flags.get("undertow_defeated", false)):
			_emit_narration("BOSS_UNDERTOW", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("superboss_a")
		elif _events != null:
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
				_events.sfx_requested.emit("harbor_creak", Vector2.ZERO, false)
		if _events != null:
			var mb_live: bool = region_id == "lighthouse_r6" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			if mb_live:
				_emit_narration("MINIBOSS_2", "title", 3.2)
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
	if are_all_seal_requirements_met():
		_trigger_seal_shatter()
	elif are_all_beacons_lit():
		_emit_narration("ISL2_SEAL_LOCKED", "narration", 3.2)


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
		_emit_shake(0.28)
		_emit_narration("CUE_SEAL_SHATTER_2", "title", 3.5)
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
			_events.save_requested.emit("tide_captain_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if _events == null or phase < 2:
		return
	if boss_id == BOSS_ID or boss_id == MINI_BOSS_KIND:
		_events.music_mode_requested.emit("island2_boss_p2")
		_emit_shake(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))
	elif boss_id in ["bosun_rig", "figurehead", "dredge_hulk", "twin_lockmasters", "gullet_lamprey"]:
		_events.music_mode_requested.emit("isl2_boss_minor_p2")
		_emit_shake(0.36 if phase >= 3 else 0.28)
	elif boss_id == SUPERBOSS_ID:
		_emit_shake(0.40 if phase >= 3 else 0.32)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id in ["figurehead", "twin_lockmasters"]:
		_check_leviathan_awakening()
		return
	if boss_id == SUPERBOSS_ID:
		if st != null:
			if not st.defeated_bosses.has(SUPERBOSS_ID):
				st.defeated_bosses.append(SUPERBOSS_ID)
			st.story_flags["undertow_defeated"] = true
			st.story_flags["boss_undertow_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
			_events.music_mode_requested.emit("explore")
			_events.save_requested.emit("boss_undertow_defeated")
		return
	if boss_id != BOSS_ID:
		return
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


func _emit_shake(amp: float) -> void:
	if _events != null:
		_events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
