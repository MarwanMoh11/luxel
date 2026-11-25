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
	"bell_yard",
	"vesper_graveyard",
	"manor_gardens",
	"belfry_forecourt",
	"cliff_foundry",
	"cave_echo_well",
	"cave_whisper",
	"cave_shed",
	"cave_foundry_trial",
	"cave_lens_grotto",
	"superboss_silent",
	"belfry_r1",
	"belfry_r2",
	"belfry_r3",
	"belfry_r4",
	"belfry_r5",
	"belfry_r6",
	"belfry_r7",
]

const OUTDOOR_RELIT_REGIONS: PackedStringArray = [
	"bell_yard",
	"vesper_graveyard",
	"manor_gardens",
	"belfry_forecourt",
	"cliff_foundry",
]

const TutorialCuesScript := preload("res://luxel/islands/1/tutorial_cues.gd")
const RuleScript := preload("res://luxel/islands/1/rule.gd")
const RelitFxScript := preload("res://luxel/islands/1/overworld/ow_relit_fx.gd")

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _r4_kills: int = 0
var _tutorial_cues: Node2D = null
var _rule: LxIsland1Rule = null
var _relit_fx: Node2D = null


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
	_events.lantern_picked_up.connect(_on_lantern_picked_up)
	_rule = RuleScript.new() as LxIsland1Rule
	if _rule != null:
		_rule.attach(_events, _state)


func detach() -> void:
	if _rule != null:
		_rule.detach()
		_rule = null
	_unmount_tutorial_cues()
	_unmount_relit_fx()
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
	if _events.lantern_picked_up.is_connected(_on_lantern_picked_up):
		_events.lantern_picked_up.disconnect(_on_lantern_picked_up)
	_attached = false


func on_region_loaded(region_id: String) -> void:
	if region_id.begins_with("belfry_") and region_id != "belfry_forecourt":
		_mark_belfry_entered()
		_unmount_tutorial_cues()
		_unmount_relit_fx()
	elif region_id == "overworld":
		_mount_tutorial_cues()
		_unmount_relit_fx()
	else:
		_unmount_tutorial_cues()
		if OUTDOOR_RELIT_REGIONS.has(region_id):
			_mount_relit_fx()
		else:
			_unmount_relit_fx()
	if _rule != null:
		_rule.on_region_loaded(region_id)


func _mount_relit_fx() -> void:
	_unmount_relit_fx()
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	var fx: Node2D = RelitFxScript.new() as Node2D
	if fx != null:
		fx.name = "Island1RelitFx"
		var b: Variant = Lx.world.get("bounds")
		if b is Rect2 and fx.has_method("setup"):
			fx.call("setup", b as Rect2)
		Lx.world.add_child(fx)
		_relit_fx = fx


func _unmount_relit_fx() -> void:
	if _relit_fx != null and is_instance_valid(_relit_fx):
		_relit_fx.queue_free()
	_relit_fx = null
	if Lx.world != null and is_instance_valid(Lx.world):
		var leftover: Node = Lx.world.get_node_or_null("Island1RelitFx")
		if leftover != null and is_instance_valid(leftover) and not leftover.is_queued_for_deletion():
			leftover.queue_free()


func _mark_belfry_entered() -> void:
	var st: LxGameState = _get_state()
	if st != null:
		st.story_flags["tut_belfry_entered"] = true


func _mount_tutorial_cues() -> void:
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	if _tutorial_cues != null and is_instance_valid(_tutorial_cues) \
			and not _tutorial_cues.is_queued_for_deletion() and _tutorial_cues.get_parent() == Lx.world:
		if _tutorial_cues.has_method("hydrate_from_state"):
			_tutorial_cues.call("hydrate_from_state")
		return
	var existing: Node = Lx.world.get_node_or_null("Island1TutorialCues")
	if existing is Node2D and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_tutorial_cues = existing as Node2D
		if _tutorial_cues.has_method("hydrate_from_state"):
			_tutorial_cues.call("hydrate_from_state")
		return
	var cues: Node2D = TutorialCuesScript.new() as Node2D
	if cues != null:
		cues.name = "Island1TutorialCues"
		Lx.world.add_child(cues)
		_tutorial_cues = cues
		if _tutorial_cues.has_method("hydrate_from_state"):
			_tutorial_cues.call("hydrate_from_state")


func _unmount_tutorial_cues() -> void:
	if _tutorial_cues != null and is_instance_valid(_tutorial_cues):
		_tutorial_cues.queue_free()
	_tutorial_cues = null
	if Lx.world != null and is_instance_valid(Lx.world):
		var leftover: Node = Lx.world.get_node_or_null("Island1TutorialCues")
		if leftover != null and is_instance_valid(leftover) and not leftover.is_queued_for_deletion():
			leftover.queue_free()


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		{
			"id": "wp_lantern_pickup",
			"region": "overworld",
			"zone": "plaza",
			"pos": [640.0, 366.0],
			"action": "interact",
			"target": "lantern_pickup_1",
			"grants_move": "throw",
			"grants_flag": "lantern_picked_up",
			"requires_moves": [],
			"requires_flags": [],
		},
		{
			"id": "wp_plaza_warden",
			"region": "overworld",
			"zone": "plaza",
			"pos": [574.0, 366.0],
			"action": "clear_encounter",
			"target": "warden_plaza_0",
			"requires_moves": ["bolt"],
			"requires_flags": [],
		},
		{
			"id": "wp_shrine_dash",
			"region": "overworld",
			"zone": "orchard",
			"pos": [164.0, 176.0],
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
			"pos": [224.0, 176.0],
			"action": "light_beacon",
			"target": "beacon_orchard",
			"grants_flag": "beacon_orchard",
			"requires_moves": ["bolt", "dash"],
			"requires_flags": [],
		},
		{
			"id": "wp_beacon_observatory",
			"region": "overworld",
			"zone": "observatory",
			"pos": [184.0, 376.0],
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
			"pos": [1156.0, 344.0],
			"action": "light_beacon",
			"target": "beacon_bridge",
			"grants_flag": "beacon_bridge",
			"requires_moves": ["bolt", "dash", "throw"],
			"requires_flags": ["beacon_observatory"],
		},
		{
			"id": "wp_enter_forecourt",
			"region": "overworld",
			"zone": "bell_arch",
			"pos": [640.0, 108.0],
			"action": "enter_exit",
			"target": "exit_to_belfry",
			"to_region": "belfry_forecourt",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["beacon_orchard", "beacon_observatory", "beacon_bridge"],
		},
		{
			"id": "wp_enter_belfry",
			"region": "belfry_forecourt",
			"zone": "belfry_forecourt",
			"pos": [288.0, 24.0],
			"action": "enter_exit",
			"target": "exit_forecourt_north",
			"to_region": "belfry_r1",
			"requires_moves": ["dash", "throw"],
			"requires_flags": ["beacon_orchard", "beacon_observatory", "beacon_bridge"],
		},
		{
			"id": "wp_belfry_key_1",
			"region": "belfry_r2",
			"zone": "belfry_chasm",
			"pos": [104.0, 120.0],
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
			"pos": [232.0, 104.0],
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
			"pos": [208.0, 136.0],
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
			"pos": [224.0, 104.0],
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
			"pos": [48.0, 112.0],
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
			"pos": [224.0, 128.0],
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
			"pos": [224.0, 56.0],
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
		_mount_tutorial_cues()
		if Lx.root != null and int(Lx.root.get("flow")) == LxMain.Flow.INTRO:
			return
		if st != null and not bool(st.story_flags.get("isl1_arrived", false)):
			st.story_flags["isl1_arrived"] = true
			_emit_narration("ISL1_ARRIVAL", "narration", 4.0)
			if _events != null:
				_events.sfx_requested.emit("bell_toll", Vector2.ZERO, false)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "belfry_r7":
		_mark_belfry_entered()
		_unmount_tutorial_cues()
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_BELLKEEPER", "title", 3.5)
			if _events != null:
				_events.music_mode_requested.emit("island1_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("belfry_") and region_id != "belfry_forecourt":
		_mark_belfry_entered()
		_unmount_tutorial_cues()
		if region_id == "belfry_r1" and st != null and not bool(st.story_flags.get("isl1_belfry_entered", false)):
			st.story_flags["isl1_belfry_entered"] = true
			_emit_narration("CH5_TITLE", "title", 3.5)
			if _events != null:
				_events.sfx_requested.emit("intro_toll", Vector2.ZERO, false)
		elif region_id == "belfry_r4":
			_r4_kills = 0
		if _events != null:
			var mb_live: bool = region_id == "belfry_r5" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			if mb_live:
				_emit_narration("MINIBOSS_1", "title", 3.2)
			_events.music_mode_requested.emit("island1_boss_p1" if mb_live else "island1_dungeon")
	elif region_id == "superboss_silent":
		_unmount_tutorial_cues()
		var sb_dead: bool = st != null and (st.defeated_bosses.has("silent_bell") or bool(st.story_flags.get("silent_bell_defeated", false)))
		if not sb_dead:
			_emit_narration("ISL1_BOSS_SILENT", "title", 3.2)
			if Lx.audio != null and is_instance_valid(Lx.audio):
				Lx.audio.silence_music(0.15)
		elif _events != null:
			_events.music_mode_requested.emit("explore")
	elif OUTDOOR_RELIT_REGIONS.has(region_id):
		_unmount_tutorial_cues()
		_mount_relit_fx()
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("cave_"):
		_unmount_tutorial_cues()
		if _events != null:
			var cue: String = "isl1_manor" if region_id == "cave_shed" else ("isl1_setpiece" if region_id == "cave_foundry_trial" else "isl1_undercroft")
			_events.music_mode_requested.emit(cue)


func _on_lantern_picked_up(_pickup_id: String, _pos: Vector2) -> void:
	if _events != null:
		_events.prompt_requested.emit("PROMPT_AIM_SHOOT", "lx_fire", 5.5)


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if _events == null:
		return
	if shrine_id == "shrine_dash" or move_id == "dash":
		_emit_narration("MOVE_DASH_NAME", "title", 3.0)
		_events.prompt_requested.emit("PROMPT_DASH", "lx_dash", 5.0)
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
	if kind == "snatcher":
		st.story_flags["tut_snatcher_killed"] = true
	if _enemy is LxEnemyBrain and (_enemy as LxEnemyBrain).enemy_id == "warden_plaza_0":
		st.story_flags["tut_plaza_warden_dead"] = true
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
			_events.music_mode_requested.emit("island1_dungeon")
			_events.save_requested.emit("bell_warden_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID and boss_id != MINI_BOSS_KIND:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island1_boss_p2")
		_events.shake_requested.emit(0.28 if boss_id == MINI_BOSS_KIND else (0.38 if phase >= 3 else 0.32))


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
