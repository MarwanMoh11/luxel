class_name LxIsland7
extends RefCounted
## Island 7 (Moon Shoals - THE ISLAND THAT LIES) progression beats, Silver/Black world state,
## Twin-Mask Gate coordination (Palace + Theatre -> Masquerade -> Mirror Spire, preserving
## legacy saves), boss/region music routing, and main-path waypoints.

const ISLAND_ID: int = 7
const SEAL_ID: String = "spire_gate_seal"
const BOSS_ID: String = "hollow_wick"
const MINI_BOSS_KIND: String = "moonshade_warden"
const MINI_BOSS_ALT_KIND: String = "spire_warden"

const REQUIRED_BEACONS: Array[String] = ["beacon_7_1", "beacon_7_2", "beacon_7_3"]
const HOLLOW_ENCOUNTERS: Array[String] = ["hollow_wick_enc_1", "hollow_wick_enc_2", "hollow_wick_enc_3"]
const MINOR_BOSS_IDS: Array[String] = [
	"silver_tide_mimic", "queen_in_glass", "the_prompter", "the_understudy", "kaleidoscope_duchess",
]

const REGIONS: Array[String] = [
	"overworld", "silver_quay", "black_shoals", "velvet_promenade", "glass_terrace", "zenith_atoll",
	"cave_mirror_tide", "cave_twin_grotto", "cave_phase_trial", "cave_echo_vault", "cave_glass_crypt",
	"superboss_noon",
	"palace_r1", "palace_r2", "palace_r3", "palace_r4", "palace_r5", "palace_r6",
	"palace_r7", "palace_r8", "palace_r9", "palace_r10", "palace_r11", "palace_r12",
	"theatre_r1", "theatre_r2", "theatre_r3", "theatre_r4", "theatre_r5", "theatre_r6",
	"theatre_r7", "theatre_r8", "theatre_r9", "theatre_r10", "theatre_r11", "theatre_r12",
	"masq_r1", "masq_r2", "masq_r3", "masq_r4",
	"spire_r1", "spire_r2", "spire_r3", "spire_r4", "spire_r5", "spire_r6", "spire_r7",
	"spire_r8", "spire_r9", "spire_r10", "spire_r11", "spire_r12", "spire_r13",
	"spire_r14", "spire_r15", "spire_r16", "spire_r17",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _attached: bool = false
var _rule: LxIsland7Rule = null


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
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
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)
	_rule = LxIsland7Rule.new()
	_rule.attach(_events, _state)
	_sync_spire_gate_flag()


func detach() -> void:
	if _rule != null:
		_rule.detach()
		_rule = null
	if _vars != null and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
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


func on_region_loaded(region_id: String) -> void:
	if _rule != null:
		_rule.on_region_loaded(region_id)
	if Lx.world != null and Lx.world.has_method("get_interactables"):
		for it_v: Variant in (Lx.world.call("get_interactables") as Array):
			if it_v is Object and (it_v as Object).has_method("sync_wick_origin"):
				(it_v as Object).call("sync_wick_origin")
	_sync_spire_gate_flag()


func get_rule() -> LxIsland7Rule:
	return _rule


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		{
			"id": "wp_hollow_enc_1", "region": "overworld", "zone": "mirror_shallows",
			"pos": [312.0, 168.0], "action": "clear_encounter", "target": "hollow_wick_enc_1",
			"grants_flag": "hollow_wick_enc_1_cleared",
			"requires_moves": ["bolt", "dash", "throw", "prism"], "requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_1", "region": "overworld", "zone": "mirror_shallows",
			"pos": [200.0, 184.0], "action": "light_beacon", "target": "beacon_7_1",
			"grants_flag": "beacon_7_1",
			"requires_moves": ["bolt", "dash", "throw", "prism"], "requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_2", "region": "overworld", "zone": "tideglass_basin",
			"pos": [312.0, 536.0], "action": "light_beacon", "target": "beacon_7_2",
			"grants_flag": "beacon_7_2",
			"requires_moves": ["bolt", "dash", "throw", "beam"], "requires_flags": [],
		},
		{
			"id": "wp_hollow_enc_2", "region": "overworld", "zone": "inverted_causeway",
			"pos": [680.0, 600.0], "action": "clear_encounter", "target": "hollow_wick_enc_2",
			"grants_flag": "hollow_wick_enc_2_cleared",
			"requires_moves": ["dash", "throw", "wings"], "requires_flags": [],
		},
		{
			"id": "wp_hollow_enc_3", "region": "overworld", "zone": "lunar_glasscourt",
			"pos": [1112.0, 392.0], "action": "clear_encounter", "target": "hollow_wick_enc_3",
			"grants_flag": "hollow_wick_enc_3_cleared",
			"requires_moves": ["dash", "throw", "lens", "sunflare"], "requires_flags": [],
		},
		{
			"id": "wp_isl7_beacon_3", "region": "overworld", "zone": "lunar_glasscourt",
			"pos": [1096.0, 184.0], "action": "light_beacon", "target": "beacon_7_3",
			"grants_flag": "beacon_7_3",
			"requires_moves": ["dash", "throw", "lens", "sunflare"], "requires_flags": [],
		},
		{
			"id": "wp_enter_terrace", "region": "overworld", "zone": "spire_terrace",
			"pos": [704.0, 80.0], "action": "enter_exit", "target": "exit_to_spire",
			"to_region": "glass_terrace",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["beacon_7_1", "beacon_7_2", "beacon_7_3"],
		},
		{
			"id": "wp_enter_spire", "region": "glass_terrace", "zone": "glass_terrace",
			"pos": [400.0, 96.0], "action": "enter_exit", "target": "exit_gt_spire_direct",
			"to_region": "spire_r1",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["masquerade_done"],
		},
		{
			"id": "wp_spire_key_1", "region": "spire_r2", "zone": "spire_r2",
			"pos": [72.0, 112.0], "action": "collect_key", "target": "wick_key_7_1",
			"grants_flag": "wick_key_7_1", "requires_moves": ["prism", "beam"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r3_combat", "region": "spire_r3", "zone": "spire_r3",
			"pos": [240.0, 24.0], "action": "clear_room", "target": "door_spire_r3_north",
			"requires_moves": ["dash", "throw"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r4_crossing", "region": "spire_r4", "zone": "spire_r4",
			"pos": [360.0, 136.0], "action": "unlock_door", "target": "door_spire_r4_east",
			"requires_moves": ["wings", "lens"], "requires_flags": ["wick_key_7_1"],
		},
		{
			"id": "wp_spire_r5_refraction", "region": "spire_r5", "zone": "spire_r5",
			"pos": [472.0, 120.0], "action": "solve_puzzle", "target": "door_spire_r5_east",
			"requires_moves": ["sunflare", "throw"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r12_key", "region": "spire_r12", "zone": "spire_r12",
			"pos": [240.0, 264.0], "action": "collect_key", "target": "wick_key_7_3",
			"grants_flag": "wick_key_7_3", "requires_moves": ["beam", "prism"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r13_duchess", "region": "spire_r13", "zone": "spire_r13",
			"pos": [240.0, 176.0], "action": "defeat_miniboss", "target": "mini_kaleidoscope_duchess",
			"grants_flag": "spire_duchess_seal", "requires_moves": ["prism", "dash"], "requires_flags": ["wick_key_7_3"],
		},
		{
			"id": "wp_spire_miniboss", "region": "spire_r6", "zone": "spire_r6",
			"pos": [256.0, 136.0], "action": "defeat_miniboss", "target": "mini_moonshade_warden",
			"grants_flag": "wick_key_7_2", "requires_moves": ["dash", "throw", "sunflare"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r7_inverted", "region": "spire_r7", "zone": "spire_r7",
			"pos": [56.0, 120.0], "action": "solve_puzzle", "target": "door_spire_r7_west",
			"requires_moves": ["prism", "lens", "wings"], "requires_flags": ["wick_key_7_2"],
		},
		{
			"id": "wp_spire_r14_nave", "region": "spire_r14", "zone": "spire_r14",
			"pos": [48.0, 168.0], "action": "solve_puzzle", "target": "door_spire_r14_west",
			"grants_flag": "spire_r14_solved", "requires_moves": ["prism", "throw"], "requires_flags": [],
		},
		{
			"id": "wp_spire_r15_counterfeit", "region": "spire_r15", "zone": "spire_r15",
			"pos": [240.0, 152.0], "action": "clear_room", "target": "door_spire_r15_south",
			"grants_flag": "spire_false_lamp_broken", "requires_moves": ["lens"], "requires_flags": ["spire_r14_solved"],
		},
		{
			"id": "wp_spire_r8_combat", "region": "spire_r8", "zone": "spire_r8",
			"pos": [24.0, 120.0], "action": "clear_room", "target": "door_spire_r8_west",
			"requires_moves": ["dash", "throw", "lens"], "requires_flags": [],
		},
		{
			"id": "wp_spire_boss_key", "region": "spire_r9", "zone": "spire_r9",
			"pos": [72.0, 120.0], "action": "collect_key", "target": "keepers_flame_7",
			"grants_flag": "keepers_flame_7", "requires_moves": ["sunflare"], "requires_flags": [],
		},
		{
			"id": "wp_spire_boss", "region": "spire_r10", "zone": "spire_r10",
			"pos": [240.0, 144.0], "action": "defeat_boss", "target": "boss_hollow_wick",
			"grants_flag": "boss_hollow_wick_defeated",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["keepers_flame_7", "spire_duchess_seal", "spire_false_lamp_broken"],
		},
		{
			"id": "wp_great_lamp_7", "region": "spire_r10", "zone": "spire_r10",
			"pos": [240.0, 64.0], "action": "light_great_lamp", "target": "great_lamp_7",
			"grants_flag": "great_lamp_7",
			"requires_moves": ["sunflare"], "requires_flags": ["boss_hollow_wick_defeated"],
		},
		{
			"id": "wp_bridge_to_island_8", "region": "spire_r10", "zone": "spire_r10",
			"pos": [240.0, 8.0], "action": "enter_exit", "target": "exit_r10_bridge_8",
			"to_region": "overworld", "to_island": 8,
			"requires_moves": ["sunflare"], "requires_flags": ["great_lamp_7"],
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


func is_epic_gate_full() -> bool:
	if Lx.packs == null:
		return false
	var pal: Dictionary = Lx.packs.dungeon("palace")
	var tht: Dictionary = Lx.packs.dungeon("theatre")
	var masq: Dictionary = Lx.packs.region_meta(ISLAND_ID, "masq_r1")
	if pal.is_empty() or bool(pal.get("debug_only", false)):
		return false
	if tht.is_empty() or bool(tht.get("debug_only", false)):
		return false
	if masq.is_empty() or bool(masq.get("debug_only", false)):
		return false
	return true


func _sync_spire_gate_flag() -> void:
	var st: LxGameState = _get_state()
	if st == null:
		return
	var legacy_passed: bool = bool(st.story_flags.get("isl7_spire_entered", false)) \
		or st.opened_doors.has("door_twin_mask_gate") \
		or _is_miniboss_defeated(st) \
		or st.defeated_bosses.has(BOSS_ID) \
		or st.relit_islands.has(ISLAND_ID)
	var palace_ok: bool = bool(st.story_flags.get("palace_cleared", false)) or bool(st.story_flags.get("dungeon_done:palace", false))
	var theatre_ok: bool = bool(st.story_flags.get("theatre_cleared", false)) or bool(st.story_flags.get("dungeon_done:theatre", false))
	if palace_ok and theatre_ok:
		st.story_flags["twin_masks_ready"] = true
	if legacy_passed:
		st.story_flags["twin_mask_gate_open"] = true
		if bool(st.story_flags.get("isl7_spire_entered", false)):
			st.story_flags["masquerade_done"] = true
		return
	if are_all_beacons_lit() and ((palace_ok and theatre_ok) or not is_epic_gate_full()):
		st.story_flags["twin_mask_gate_open"] = true


func _on_var_changed(scope: String, var_name: String, value: Variant) -> void:
	if scope != "island:7" or var_name != "world_face":
		return
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	var face: String = str(value).strip_edges().to_lower()
	if face == "black":
		if not bool(st.story_flags.get("ow_world_black", false)):
			st.story_flags["ow_world_black"] = true
			_emit_narration("ISL7_FACE_BLACK", "narration", 3.4)
	elif face == "silver":
		if bool(st.story_flags.get("ow_world_black", false)) and not bool(st.story_flags.get("ow_world_silver", false)):
			st.story_flags["ow_world_silver"] = true
			_emit_narration("ISL7_FACE_SILVER", "narration", 3.0)


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	_sync_spire_gate_flag()
	var st: LxGameState = _get_state()
	if region_id == "overworld":
		if st != null and not bool(st.story_flags.get("isl7_arrived", false)):
			st.story_flags["isl7_arrived"] = true
			_emit_narration("ISL7_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.sfx_requested.emit("lens_reveal", Vector2.ZERO, false)
		_emit_music("explore")
	elif region_id == "silver_quay":
		if st != null:
			st.story_flags["silver_quay_visited"] = true
			if st.relit_islands.has(ISLAND_ID) and not bool(st.story_flags.get("isl7_relit_quay_shown", false)):
				st.story_flags["isl7_relit_quay_shown"] = true
				_emit_narration("ISL7_RELIT_QUAY", "narration", 3.6)
		_emit_music("explore")
	elif region_id == "black_shoals":
		if st != null:
			st.story_flags["black_shoals_visited"] = true
		_emit_music("explore")
	elif region_id == "velvet_promenade":
		if st != null:
			st.story_flags["velvet_promenade_visited"] = true
		_emit_music("isl7_theatre")
	elif region_id == "glass_terrace":
		if st != null:
			st.story_flags["glass_terrace_seen"] = true
		_emit_music("explore" if (st != null and st.relit_islands.has(ISLAND_ID)) else "isl7_setpiece")
	elif region_id == "zenith_atoll":
		if st != null:
			st.story_flags["zenith_visited"] = true
		_emit_music("explore")
	elif region_id == "superboss_noon":
		if st != null and not bool(st.story_flags.get("shadow_at_noon_defeated", false)):
			_emit_narration("ISL7_NOON_ENTER", "title", 3.4)
			_emit_music("superboss_b")
		else:
			_emit_music("explore")
	elif region_id.begins_with("masq_"):
		_emit_music("isl7_setpiece")
	elif region_id.begins_with("palace_"):
		if region_id == "palace_r5" and st != null and not bool(st.story_flags.get("palace_miniboss_done", false)):
			_emit_music("isl7_boss_minor_p1")
		elif region_id == "palace_r12" and st != null and not bool(st.story_flags.get("palace_cleared", false)):
			_emit_music("isl7_boss_minor_p1")
		else:
			_emit_music("isl7_palace")
	elif region_id.begins_with("theatre_"):
		if region_id == "theatre_r5" and st != null and not bool(st.story_flags.get("theatre_miniboss_done", false)):
			_emit_music("isl7_boss_minor_p1")
		elif region_id == "theatre_r12" and st != null and not bool(st.story_flags.get("theatre_cleared", false)):
			_emit_music("isl7_boss_minor_p1")
		else:
			_emit_music("isl7_theatre")
	elif region_id == "spire_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_HOLLOW", "title", 3.5)
			_emit_music("island7_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID):
			_emit_music("explore")
	elif region_id.begins_with("spire_"):
		if region_id == "spire_r1" and st != null and not bool(st.story_flags.get("isl7_spire_entered", false)):
			st.story_flags["isl7_spire_entered"] = true
			_emit_narration("DUNGEON_7_NAME", "title", 3.5)
			if _events != null:
				_events.sfx_requested.emit("phantom_phase", Vector2.ZERO, false)
		if region_id == "spire_r6" and st != null and not _is_miniboss_defeated(st):
			_emit_narration("MINIBOSS_7", "title", 3.2)
			_emit_music("island7_boss_p1")
		elif region_id == "spire_r13" and st != null and not bool(st.story_flags.get("kaleidoscope_duchess_defeated", false)):
			_emit_music("isl7_boss_minor_p1")
		else:
			_emit_music("island7_dungeon")


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
	_sync_spire_gate_flag()


func _trigger_seal_shatter() -> void:
	var st: LxGameState = _get_state()
	if st != null:
		if st.broken_seals.has(SEAL_ID):
			return
		st.broken_seals.append(SEAL_ID)
		st.story_flags["seal_broken_7"] = true
	_sync_spire_gate_flag()
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
		st.story_flags["hollow_wick_encounters_cleared"] = int(st.story_flags.get("hollow_wick_encounters_cleared", 0)) + 1
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
			_emit_music("island7_dungeon")
			_events.save_requested.emit("moonshade_warden_defeated")
	elif st.region_id == "spire_r10" and (kind == "hollow_wick_boss" or eid == "boss_hollow_wick"):
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_hollow_wick_defeated"] = true


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if _events == null or phase < 2:
		return
	if boss_id == "shadow_at_noon":
		_emit_music("superboss_b")
		_events.shake_requested.emit(0.32 if phase >= 3 else 0.26)
	elif MINOR_BOSS_IDS.has(boss_id):
		_emit_music("isl7_boss_minor_p2")
		_events.shake_requested.emit(0.30 if phase >= 3 else 0.24)
	elif boss_id == BOSS_ID or boss_id == "hollow_wick_boss" or _is_miniboss_id(boss_id):
		_emit_music("island7_boss_p2")
		_events.shake_requested.emit(0.28 if _is_miniboss_id(boss_id) else (0.38 if phase >= 3 else 0.32))


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id == "shadow_at_noon":
		if st != null:
			if not st.defeated_bosses.has("shadow_at_noon"):
				st.defeated_bosses.append("shadow_at_noon")
			st.story_flags["shadow_at_noon_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("shadow_reunite", Vector2.ZERO, false)
			_emit_music("explore")
			_emit_narration("ISL7_NOON_REUNITED", "title", 3.6)
			_events.save_requested.emit("shadow_at_noon_defeated")
		return
	if _is_miniboss_id(boss_id):
		if st != null:
			if not st.defeated_bosses.has(MINI_BOSS_KIND):
				st.defeated_bosses.append(MINI_BOSS_KIND)
			st.defeated_bosses.erase(MINI_BOSS_ALT_KIND)
			st.story_flags["defeated_moonshade_warden"] = true
			st.story_flags["moonshade_warden_defeated"] = true
		return
	if MINOR_BOSS_IDS.has(boss_id):
		_sync_spire_gate_flag()
		if boss_id in ["silver_tide_mimic", "queen_in_glass"]:
			_emit_music("isl7_palace")
		elif boss_id in ["the_prompter", "the_understudy"]:
			_emit_music("isl7_theatre")
		elif boss_id == "kaleidoscope_duchess":
			_emit_music("island7_dungeon")
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
		_emit_music("explore")
		_emit_narration("ISL7_RELIGHT", "title", 4.0)
		_emit_narration("ISL7_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_7")


func _emit_music(cue: String) -> void:
	if _events != null:
		_events.music_mode_requested.emit(cue)


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
