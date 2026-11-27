class_name LxI5OverworldFlow
extends RefCounted
## Island 5 (Starfall Observatory) overworld runtime coordinator:
## - Dynamic grand-seal gating (enforces meteor_done + planetarium_done once those non-debug dungeons exist,
##   while keeping legacy saves that already broke orrery_seal / opened door_dungeon_5 passed)
## - Dream Telescope floor timer, hit tracker, C/B/A/S rank grading, dream_best persistence & Floor 3 lead slot
## - Trial medal persistence (Bronze/Silver/Gold) for trial_comet_range and trial_constellation_sprint
## - Relit world cues (island_5_relit dawn narration, Event Horizon Phase 3 eclipse cue, First Bend fanfare)

const ISLAND_ID: int = 5
const SEAL_ID: String = "orrery_seal"
const DREAM_FLOORS: Array[String] = [
	"dream_r1", "dream_r2", "dream_r3", "dream_r4", "dream_r5", "dream_r6",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _region_id: String = ""
var _dream_run_s: float = 0.0
var _dream_hits: int = 0
var _dream_active: bool = false
var _dream_floors_cleared: int = 0


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	if _events == null:
		return
	_attached = true
	_events.player_damaged.connect(_on_player_damaged)
	_events.boss_phase_changed.connect(_on_boss_phase_changed)
	_events.boss_defeated.connect(_on_boss_defeated)
	_events.great_lamp_relit.connect(_on_great_lamp_relit)


func detach() -> void:
	if not _attached or _events == null:
		_attached = false
		return
	if _events.player_damaged.is_connected(_on_player_damaged):
		_events.player_damaged.disconnect(_on_player_damaged)
	if _events.boss_phase_changed.is_connected(_on_boss_phase_changed):
		_events.boss_phase_changed.disconnect(_on_boss_phase_changed)
	if _events.boss_defeated.is_connected(_on_boss_defeated):
		_events.boss_defeated.disconnect(_on_boss_defeated)
	if _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
		_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_region_id = region_id
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	if region_id == "overworld":
		_apply_seal_gating()
		_handle_relit_overworld(st)
	elif region_id in DREAM_FLOORS:
		if region_id == "dream_r1" or not _dream_active:
			_dream_active = true
			_dream_run_s = 0.0
			_dream_hits = 0
			_dream_floors_cleared = 0
		if _events != null:
			var cue: String = "isl5_setpiece" if region_id == "dream_r6" else (
				"isl5_planetarium" if region_id in ["dream_r2", "dream_r4", "dream_r5"] else "isl5_meteor"
			)
			_events.music_mode_requested.emit(cue)
	elif region_id == "superboss_horizon":
		if _events != null:
			if not st.defeated_bosses.has("event_horizon"):
				_events.music_mode_requested.emit("superboss_b")
			else:
				_events.music_mode_requested.emit("explore")
	else:
		_dream_active = false
		_apply_dungeon_arc_entry(st, region_id)
		_apply_region_music(region_id)


func are_seal_requirements_met() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	# Legacy save guarantee: any save that already passed the Orrery seal stays passed.
	if st.broken_seals.has(SEAL_ID) or st.opened_doors.has("door_dungeon_5") or st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("seal_broken_5", false)):
		return true
	for bid: String in ["beacon_5_1", "beacon_5_2", "beacon_5_3"]:
		if not st.lit_beacons.has(bid) and not bool(st.story_flags.get(bid, false)):
			return false
	if _is_dungeon_live("meteor_vault"):
		if not bool(st.story_flags.get("meteor_done", false)) and not bool(st.story_flags.get("dungeon_done:meteor_vault", false)):
			return false
	if _is_dungeon_live("planetarium"):
		if not bool(st.story_flags.get("planetarium_done", false)) and not bool(st.story_flags.get("dungeon_done:planetarium", false)):
			return false
	return true


func record_dream_floor_clear(floor_num: int) -> void:
	var st: LxGameState = _get_state()
	if st == null:
		return
	var fkey: String = "dream_r%d_ok" % clampi(floor_num, 1, 6)
	st.story_flags[fkey] = true
	_dream_floors_cleared = maxi(_dream_floors_cleared, floor_num)
	var base_pts: int = floor_num * 200
	var no_hit_bonus: int = 150 if _dream_hits == 0 else maxi(0, 90 - _dream_hits * 30)
	var score: int = base_pts + no_hit_bonus
	var prev_best: int = int(Lx.vars.get_var("island:5", "dream_best", 0)) if Lx.vars != null else 0
	if Lx.vars != null and score > prev_best:
		Lx.vars.set_var("island:5", "dream_best", score)
	var rank: String = "S" if (_dream_hits == 0 and floor_num >= 6) else ("A" if _dream_hits <= 1 else ("B" if _dream_hits <= 3 else "C"))
	st.story_flags["dream_last_rank"] = rank
	if floor_num >= 3 and not bool(st.story_flags.get("lead_slot_5", false)):
		st.story_flags["lead_slot_5"] = true
		LxPanes.current().add_lead(1)
		_emit_narration("I5_DR_LEAD_REWARD", "title", 3.0)
	if floor_num >= 6 and not bool(st.story_flags.get("dream_cleared", false)):
		st.story_flags["dream_cleared"] = true
		st.story_flags["star_crown_trophy"] = true
		st.add_shards(150)
		_emit_narration("I5_DR_CROWN_REWARD", "title", 3.2)


func record_trial_medal(trial_id: String, elapsed_s: float, gold_s: float, silver_s: float) -> String:
	var st: LxGameState = _get_state()
	var medal: String = "gold" if elapsed_s <= gold_s else ("silver" if elapsed_s <= silver_s else "bronze")
	if st != null:
		var order: Dictionary = {"": 0, "bronze": 1, "silver": 2, "gold": 3}
		var prev: String = str(st.story_flags.get("medal:" + trial_id, ""))
		if int(order.get(medal, 1)) >= int(order.get(prev, 0)):
			st.story_flags["medal:" + trial_id] = medal
	return medal


func _apply_seal_gating() -> void:
	var st: LxGameState = _get_state()
	var reg: LxRegionLoader = Lx.world as LxRegionLoader if (Lx.world is LxRegionLoader and is_instance_valid(Lx.world)) else null
	if st == null or reg == null:
		return
	var door_node: LxInteractable = reg.find_interactable("door_dungeon_5")
	if not (door_node is LxDoor):
		return
	var door: LxDoor = door_node as LxDoor
	# Legacy save bypass: keep already-passed seals open, and preserve already-past-Fall saves.
	if st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("isl5_dungeon_entered", false)) or st.has_move("lens"):
		if not bool(st.story_flags.get("fall_done", false)):
			st.story_flags["fall_done"] = true
			reg.apply_layers(false)
	if st.broken_seals.has(SEAL_ID) or st.opened_doors.has("door_dungeon_5") or st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("seal_broken_5", false)):
		door.opened = true
		door.queue_redraw()
		return
	if _is_dungeon_live("meteor_vault") and not door.required_flags.has("meteor_done"):
		door.required_flags.append("meteor_done")
	if _is_dungeon_live("planetarium") and not door.required_flags.has("planetarium_done"):
		door.required_flags.append("planetarium_done")


func _handle_relit_overworld(st: LxGameState) -> void:
	if not st.relit_islands.has(ISLAND_ID):
		return
	var reg: LxRegionLoader = Lx.world as LxRegionLoader if (Lx.world is LxRegionLoader and is_instance_valid(Lx.world)) else null
	if reg != null:
		reg.apply_layers(false)
	if not bool(st.story_flags.get("i5_relight_post_shown", false)):
		st.story_flags["i5_relight_post_shown"] = true
		_emit_narration("I5_RELIGHT_POST", "narration", 3.5)


func _apply_dungeon_arc_entry(st: LxGameState, region_id: String) -> void:
	if region_id == "meteor_r1" and not bool(st.story_flags.get("isl5_meteor_entered", false)):
		st.story_flags["isl5_meteor_entered"] = true
		_emit_narration("I5_DNG_METEOR", "title", 3.2)
	elif region_id == "planet_r1" and not bool(st.story_flags.get("isl5_planet_entered", false)):
		st.story_flags["isl5_planet_entered"] = true
		_emit_narration("I5_DNG_PLANET", "title", 3.2)
	elif region_id == "fall_r1" and not bool(st.story_flags.get("isl5_fall_entered", false)):
		st.story_flags["isl5_fall_entered"] = true
		_emit_narration("I5_DNG_FALL", "title", 3.2)


func _apply_region_music(region_id: String) -> void:
	if _events == null:
		return
	var st: LxGameState = _get_state()
	if region_id.begins_with("meteor_"):
		var mb: bool = (region_id == "meteor_r6" and st != null and not st.defeated_bosses.has("apogee_hound")) \
			or (region_id == "meteor_r11" and st != null and not st.defeated_bosses.has("twin_moons"))
		_events.music_mode_requested.emit("isl5_boss_minor_p1" if mb else "isl5_meteor")
		return
	if region_id.begins_with("planet_"):
		var pb: bool = (region_id == "planet_r6" and st != null and not st.defeated_bosses.has("meridian_weaver")) \
			or (region_id == "planet_r11" and st != null and not st.defeated_bosses.has("the_zodiac"))
		_events.music_mode_requested.emit("isl5_boss_minor_p1" if pb else "isl5_planetarium")
		return
	if region_id.begins_with("fall_"):
		var fb: bool = region_id == "fall_r4" and st != null and not st.defeated_bosses.has("the_counterweight")
		_events.music_mode_requested.emit("isl5_boss_minor_p1" if fb else "isl5_setpiece")
		return
	match region_id:
		"ow_meteor_apron", "trial_comet_range":
			_events.music_mode_requested.emit("isl5_meteor")
		"ow_dome_causeway", "trial_constellation_sprint":
			_events.music_mode_requested.emit("isl5_planetarium")
		"ow_starfall_cliff":
			_events.music_mode_requested.emit("explore")
		"cave_gravity_well", "cave_broken_pendulum", "cave_star_cistern", "cave_astrolabe_crypt":
			_events.music_mode_requested.emit("island5_dungeon")


func _is_dungeon_live(dungeon_id: String) -> bool:
	if Lx.packs == null:
		return false
	var meta: Dictionary = Lx.packs.dungeon(dungeon_id)
	if meta.is_empty():
		return false
	return not bool(meta.get("debug_only", false))


func _on_player_damaged(amount: float, _from: Vector2, _dir: Vector2, _src: String) -> void:
	if _dream_active and amount > 0.0 and _region_id in DREAM_FLOORS:
		_dream_hits += 1


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id == "event_horizon" and _events != null:
		if phase >= 3:
			_emit_narration("I5_CUE_ECLIPSE", "title", 2.8)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id == "event_horizon":
		if st != null:
			st.story_flags["superboss_5_defeated"] = true
			if not st.defeated_bosses.has("event_horizon"):
				st.defeated_bosses.append("event_horizon")
		if _events != null:
			_emit_narration("I5_SH_DEFEATED", "title", 3.5)
			_events.music_mode_requested.emit("explore")
			_events.save_requested.emit("superboss_5_defeated")
	elif boss_id in ["twin_moons", "the_zodiac"]:
		if are_seal_requirements_met() and st != null and not st.broken_seals.has(SEAL_ID):
			st.broken_seals.append(SEAL_ID)
			st.story_flags["seal_broken_5"] = true
			if _events != null:
				_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
				_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
				_events.shake_requested.emit(0.24)
				_emit_narration("I5_CUE_CHAINS", "title", 3.2)
				_events.save_requested.emit("seal_broken_5")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		st.story_flags["island_5_relit"] = true


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
