class_name LxIsland6
extends RefCounted
## Island 6 (Ashen Kiln) progression beats, story hooks, region list, and main-path waypoints.

const ISLAND_ID: int = 6
const SEAL_ID: String = "kiln_gate_seal"
const BOSS_ID: String = "kilnmother"
const MINI_BOSS_KIND: String = "forge_warden"

const REQUIRED_BEACONS: Array[String] = ["beacon_6_1", "beacon_6_2", "beacon_6_3"]

const REGIONS: Array[String] = [
	"overworld", "ow_rail_yard", "ow_giant_stride", "ow_slag_basin", "ow_cinder_overlook",
	"cave_temper_foundry", "cave_slag_sluice", "cave_magnet_vault", "cave_bellows_trial",
	"cave_sunflare_crypt", "superboss_first_forge",
	"kiln_r1", "kiln_r2", "kiln_r3", "kiln_r4", "kiln_r5", "kiln_r6",
	"kiln_r7", "kiln_r8", "kiln_r9", "kiln_r10", "kiln_r11", "kiln_r12",
	"kiln_r13", "kiln_r14", "kiln_r15", "kiln_r16", "kiln_r17", "kiln_r18",
]

const MOTION_REGIONS: Array[String] = [
	"overworld", "ow_rail_yard", "ow_giant_stride", "ow_slag_basin", "ow_cinder_overlook",
]

const SEAL_DUNGEON_FLAGS: Array[String] = ["express_cleared", "colossus_cleared", "crash_done"]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _rule: LxIsland6Rule = null
var _motion_fx: LxIsland6MotionFx = null
var _vars_bound: LxWorldState = null


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
	_bind_vars()
	_rule = LxIsland6Rule.new()
	_rule.attach(_events, _state)


func detach() -> void:
	_clear_motion_fx()
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null
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
	_bind_vars()
	if _rule != null:
		_rule.on_region_loaded(region_id)
	_sync_overworld_gate(region_id)
	_mount_motion_fx(region_id)
	_apply_spark_shrine_bonus(region_id)


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _on_var_changed(_scope: String, var_name: String, value: Variant) -> void:
	if var_name == "kiln_shift" and _motion_fx != null and is_instance_valid(_motion_fx):
		_motion_fx.trigger_shift(str(value).strip_edges().to_lower())


func _clear_motion_fx() -> void:
	if _motion_fx != null and is_instance_valid(_motion_fx):
		_motion_fx.queue_free()
	_motion_fx = null


func _mount_motion_fx(region_id: String) -> void:
	_clear_motion_fx()
	if region_id not in MOTION_REGIONS:
		return
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	var b: Rect2 = Lx.world.get("bounds") as Rect2 if Lx.world.get("bounds") is Rect2 else Rect2(0, 0, 768, 512)
	var st: LxGameState = _get_state()
	var is_relit: bool = st != null and (st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("island_6_relit", false)) or bool(st.story_flags.get("great_lamp_6", false)))
	_motion_fx = LxIsland6MotionFx.new()
	_motion_fx.name = "Island6WorldMotionFx"
	_motion_fx.setup(region_id, b, LxIsland6Rule.get_kiln_shift(), is_relit)
	Lx.world.add_child(_motion_fx)


func _are_epic_dungeons_wired() -> bool:
	return FileAccess.file_exists("res://luxel/islands/6/train_r1.map") \
		and FileAccess.file_exists("res://luxel/islands/6/colossus_r1.map") \
		and FileAccess.file_exists("res://luxel/islands/6/crash_r1.map") \
		and (Lx.packs == null or not bool(Lx.packs.region_meta(ISLAND_ID, "train_r1").get("debug_only", false)))


func _legacy_passed_kiln_seal(st: LxGameState) -> bool:
	if st == null:
		return false
	return st.opened_doors.has("door_dungeon_6") \
		or st.broken_seals.has(SEAL_ID) \
		or st.broken_seals.has("door_dungeon_6") \
		or bool(st.story_flags.get("isl6_kiln_entered", false))


func _sync_overworld_gate(region_id: String) -> void:
	if region_id != "overworld" or Lx.world == null or not is_instance_valid(Lx.world):
		return
	var st: LxGameState = _get_state()
	if _legacy_passed_kiln_seal(st):
		if st != null and not st.opened_doors.has("door_dungeon_6"):
			st.opened_doors.append("door_dungeon_6")
		return
	if not _are_epic_dungeons_wired():
		return
	# Once Ember Express, Iron Colossus, and Iron Collision are all live, enforce full 6-flag seal
	if Lx.world.has_method("find_interactable"):
		var door_v: Variant = Lx.world.call("find_interactable", "door_dungeon_6")
		if door_v is LxDoor:
			var d: LxDoor = door_v as LxDoor
			for fl: String in SEAL_DUNGEON_FLAGS:
				if not d.required_flags.has(fl):
					d.required_flags.append(fl)


func _apply_spark_shrine_bonus(region_id: String) -> void:
	if region_id not in ["overworld", "ow_rail_yard"]:
		return
	var st: LxGameState = _get_state()
	if st == null or not bool(st.story_flags.get("quest:q6_spark_hide:done", false)):
		return
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("ember") != null:
		var emax: float = st.get_effective_ember_max()
		var cur: float = float(Lx.player.get("ember"))
		var floor_e: float = emax * 0.30
		if cur < floor_e:
			Lx.player.set("ember", floor_e)
			if not bool(st.story_flags.get("isl6_shrine_boost_shown", false)):
				st.story_flags["isl6_shrine_boost_shown"] = true
				_emit_narration("ISL6_SHRINE_BOOST", "narration", 2.6)


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func _wp(id: String, region: String, zone: String, pos: Array, action: String, target: String, moves: Array, flags: Array, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {
		"id": id, "region": region, "zone": zone, "pos": pos,
		"action": action, "target": target,
		"requires_moves": moves, "requires_flags": flags,
	}
	for k: Variant in extra.keys():
		d[k] = extra[k]
	return d


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		_wp("wp_isl6_beacon_1", "overworld", "ash_drifts", [440.0, 120.0], "light_beacon", "beacon_6_1", ["bolt", "dash", "throw"], [], {"grants_flag": "beacon_6_1"}),
		_wp("wp_isl6_beacon_2", "overworld", "slag_foundry", [552.0, 440.0], "light_beacon", "beacon_6_2", ["bolt", "dash", "throw", "beam"], [], {"grants_flag": "beacon_6_2"}),
		_wp("wp_isl6_beacon_3", "overworld", "furnace_causeway", [1016.0, 120.0], "light_beacon", "beacon_6_3", ["bolt", "dash", "throw", "wings"], [], {"grants_flag": "beacon_6_3"}),
		_wp("wp_enter_kiln", "overworld", "kiln_approach", [1312.0, 80.0], "enter_exit", "exit_to_kiln", ["dash", "throw", "wings", "lens"], ["beacon_6_1", "beacon_6_2", "beacon_6_3"], {"to_region": "kiln_r1"}),
		_wp("wp_kiln_key_1", "kiln_r2", "kiln_r2", [72.0, 168.0], "collect_key", "wick_key_6_1", ["throw"], [], {"grants_flag": "wick_key_6_1"}),
		_wp("wp_kiln_r3_combat", "kiln_r3", "kiln_r3", [272.0, 24.0], "clear_room", "door_kiln_r3_north", ["dash", "throw"], []),
		_wp("wp_kiln_r4_crossing", "kiln_r4", "kiln_r4", [344.0, 104.0], "unlock_door", "door_kiln_r4_east", ["wings", "lens"], ["wick_key_6_1"]),
		_wp("wp_shrine_sunflare", "kiln_r5", "kiln_r5", [200.0, 104.0], "claim_shrine", "shrine_sunflare", ["wings", "lens"], ["wick_key_6_1"], {"grants_move": "sunflare"}),
		_wp("wp_kiln_miniboss", "kiln_r6", "kiln_r6", [288.0, 128.0], "defeat_miniboss", "mini_forge_warden", ["sunflare"], [], {"grants_flag": "wick_key_6_2"}),
		_wp("wp_kiln_furnace_hall", "kiln_r7", "kiln_r7", [48.0, 120.0], "solve_puzzle", "door_kiln_r7_west", ["sunflare"], ["wick_key_6_2"]),
		_wp("wp_kiln_r8_combat", "kiln_r8", "kiln_r8", [24.0, 136.0], "clear_room", "door_kiln_r8_west", ["sunflare"], []),
		_wp("wp_kiln_boss_key", "kiln_r9", "kiln_r9", [72.0, 136.0], "collect_key", "keepers_flame_6", ["sunflare"], [], {"grants_flag": "keepers_flame_6"}),
		_wp("wp_kiln_clamp_west", "kiln_r13", "kiln_r13", [432.0, 144.0], "solve_puzzle", "pull_r13_clamp_w", ["sunflare"], ["keepers_flame_6"], {"grants_flag": "kiln_cast_west"}),
		_wp("wp_kiln_clamp_east", "kiln_r16", "kiln_r16", [72.0, 112.0], "solve_puzzle", "pull_r16_clamp_e", ["sunflare"], ["kiln_cast_west"], {"grants_flag": "kiln_cast_east"}),
		_wp("wp_kiln_boss", "kiln_r10", "kiln_r10", [256.0, 136.0], "defeat_boss", "boss_kilnmother", ["sunflare"], ["keepers_flame_6", "kiln_cast_west", "kiln_cast_east"], {"grants_flag": "boss_kilnmother_defeated"}),
		_wp("wp_great_lamp_6", "kiln_r10", "kiln_r10", [256.0, 72.0], "light_great_lamp", "great_lamp_6", ["sunflare"], ["boss_kilnmother_defeated"], {"grants_flag": "great_lamp_6"}),
		_wp("wp_bridge_to_island_7", "kiln_r10", "kiln_r10", [256.0, 8.0], "enter_exit", "exit_r10_bridge_7", ["sunflare"], ["great_lamp_6"], {"to_region": "overworld", "to_island": 7}),
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
				_events.sfx_requested.emit("steam_whistle", Vector2.ZERO, false)
				_events.sfx_requested.emit("colossus_step", Vector2.ZERO, false)
				_events.shake_requested.emit(0.04 if LxHudFx.flash_reduced() else 0.09)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id in ["ow_rail_yard", "ow_giant_stride", "ow_slag_basin", "ow_cinder_overlook"]:
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "superboss_first_forge":
		if st != null and not st.defeated_bosses.has("first_forge") and not bool(st.story_flags.get("first_forge_defeated", false)):
			_emit_narration("ISL6_BOSS_FIRST", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("superboss_b")
		elif _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "kiln_r10":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_KILNMOTHER", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island6_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("kiln_"):
		if region_id == "kiln_r1" and st != null and not bool(st.story_flags.get("isl6_kiln_entered", false)):
			st.story_flags["isl6_kiln_entered"] = true
			_emit_narration("DUNGEON_6_NAME", "title", 3.5)
			if _events != null:
				_events.sfx_requested.emit("furnace_draw", Vector2.ZERO, false)
				_emit_shake(0.08)
		if _events != null:
			var mb_live: bool = region_id == "kiln_r6" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			var weaver_live: bool = region_id == "kiln_r15" and st != null and not st.defeated_bosses.has("crucible_weaver") and not bool(st.story_flags.get("crucible_weaver_defeated", false))
			if mb_live:
				_emit_narration("MINIBOSS_6", "title", 3.2)
				_events.music_mode_requested.emit("island6_boss_p1")
			elif weaver_live:
				_emit_narration("ISL6_BOSS_WEAVER", "title", 3.2)
				_events.music_mode_requested.emit("isl6_boss_minor_p1")
			else:
				_events.music_mode_requested.emit("island6_dungeon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_sunflare" or move_id == "sunflare":
		var st: LxGameState = _get_state()
		var emax: float = st.get_effective_ember_max() if st != null else 100.0
		if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("ember") != null:
			Lx.player.set("ember", emax)
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
	if are_all_beacons_lit():
		if not _are_epic_dungeons_wired() or _are_epic_seal_flags_met():
			_trigger_seal_shatter()


func _are_epic_seal_flags_met() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	for fl: String in SEAL_DUNGEON_FLAGS:
		if not bool(st.story_flags.get(fl, false)):
			return false
	return true


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
		_emit_shake(0.28)
		_emit_narration("CUE_SEAL_SHATTER_6", "title", 3.5)
		_emit_narration("DUNGEON_6_NAME", "narration", 3.0)
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
			_events.music_mode_requested.emit("island6_dungeon")
			_events.save_requested.emit("forge_warden_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id == "crucible_weaver":
		if phase >= 2 and _events != null:
			_events.music_mode_requested.emit("isl6_boss_minor_p2")
			_emit_shake(0.18)
		return
	if boss_id != BOSS_ID and boss_id != MINI_BOSS_KIND:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island6_boss_p2")
		_emit_shake(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))


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
	if boss_id == "first_forge":
		if st != null:
			if not st.defeated_bosses.has("first_forge"):
				st.defeated_bosses.append("first_forge")
			st.story_flags["first_forge_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
			_events.music_mode_requested.emit("explore")
			_events.save_requested.emit("first_forge_defeated")
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
	if _motion_fx != null and is_instance_valid(_motion_fx):
		_motion_fx.set_relit(true)
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_events.music_mode_requested.emit("explore")
		_emit_narration("ISL6_RELIGHT", "title", 4.0)
		_emit_narration("ISL6_BRIDGE", "narration", 4.0)
		_events.save_requested.emit("great_lamp_6")


func _emit_shake(amp: float) -> void:
	if _events != null:
		_events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
