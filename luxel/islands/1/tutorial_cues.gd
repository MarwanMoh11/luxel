class_name LxIsland1TutorialCues
extends Node2D
## Island 1 visual-first diegetic world cues (320x180 pixel art, strict Last Light 20-colour palette).
## Guides spawn -> floor lantern -> first enemy -> road lamps -> Orchard Beacon + Dash ->
## 32px Dash Chasm -> Moonlit River Throw/Zip -> Stage 5 Snatcher Bait/Zip/Dash with zero text walls.

const G := preload("res://luxel/islands/1/tutorial_glyphs.gd")
const POS_LANTERN := Vector2(640.0, 366.0)
const POS_WARDEN := Vector2(574.0, 366.0)
const POS_BEACON_ORCHARD := Vector2(224.0, 176.0)
const POS_SHRINE_DASH := Vector2(164.0, 176.0)
const POS_CHASM_TOP := Vector2(184.0, 232.0)
const POS_CHASM_BOT := Vector2(184.0, 280.0)
const POS_PIER_LIP := Vector2(984.0, 360.0)
const POS_BRAZIER_EAST := Vector2(1068.0, 360.0)
const SNATCHER_RANGE: float = 150.0
const SNATCHER_LINGER_S: float = 1.6
const SNATCHER_DASH_RANGE: float = 76.0
const GULP_FX_DUR: float = 1.15
const LEADING_LAMPS: Array[Dictionary] = [
	{"id": "lamp_plaza_w", "pos": Vector2(512.0, 344.0)},
	{"id": "lamp_orchard_turn", "pos": Vector2(448.0, 304.0)},
	{"id": "lamp_orchard_e", "pos": Vector2(424.0, 216.0)},
]

var _clock: float = 0.0
var _s0_w: float = 0.0; var _s1_w: float = 0.0; var _s2_w: float = 0.0
var _s3_halo_w: float = 0.0; var _s3_gap_w: float = 0.0; var _s4_w: float = 0.0; var _s5_w: float = 0.0
var _prev_has_lantern: bool = false
var _pickup_burst_t: float = 0.0
var _pickup_burst_pos: Vector2 = POS_LANTERN
var _warden_hit: bool = false
var _warden_died: bool = false
var _prev_warden_alive: bool = false
var _warden_death_pos: Vector2 = POS_WARDEN
var _celebrate_t: float = 0.0
var _dash_crossed: bool = false; var _river_crossed: bool = false
var _core_suppressed: bool = false
var _show_dash_cap: bool = false
var _has_thrown: bool = false; var _throw_hint_shown: bool = false
var _warden_blocks: int = 0
var _snatcher_killed: bool = false
var _snatcher_recovered: bool = false
var _snatcher_near_t: float = 0.0
var _snatcher_gulped_any: bool = false
var _snatcher_gulps: Dictionary = {}
var _tracked_snatchers: Array[LxSnatcherBrain] = []
var _active_snatcher: LxSnatcherBrain = null
var _gulp_fx_t: float = 0.0
var _gulp_fx_pos: Vector2 = Vector2.ZERO
var _bound_events: LxEventBus = null


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hydrate_from_state()
	_sync_events()


func hydrate_from_state() -> void:
	_prev_has_lantern = _has_lantern()
	_core_suppressed = _compute_core_suppressed()
	var st: LxGameState = Lx.state
	_throw_hint_shown = st != null and bool(st.story_flags.get("throw_combat_hint_shown", false))
	_snatcher_killed = st != null and bool(st.story_flags.get("tut_snatcher_killed", false))
	_snatcher_recovered = st != null and bool(st.story_flags.get("tut_snatcher_recovered", false))
	var has_belfry_or_beacon: bool = _core_suppressed or _any_island1_beacon_lit()
	_warden_died = (st != null and bool(st.story_flags.get("tut_plaza_warden_dead", false))) or has_belfry_or_beacon
	if _warden_died and st != null:
		st.story_flags["tut_plaza_warden_dead"] = true
	_dash_crossed = (st != null and bool(st.story_flags.get("tut_dash_crossed", false))) \
			or _is_beacon_lit("beacon_observatory") or _is_inter_bool("lamp_orchard_s", "lit") or _core_suppressed
	if _dash_crossed and st != null:
		st.story_flags["tut_dash_crossed"] = true
	_river_crossed = (st != null and (bool(st.story_flags.get("tut_river_crossed", false)) \
			or bool(st.story_flags.get("river_bridge_raised", false)))) \
			or _is_beacon_lit("beacon_bridge") or _core_suppressed
	var w_en: LxEnemyBrain = _find_warden()
	_prev_warden_alive = (not _warden_died) and w_en != null and w_en.is_alive()
	if _core_suppressed:
		_s0_w = 0.0; _s1_w = 0.0; _s2_w = 0.0; _s3_halo_w = 0.0; _s3_gap_w = 0.0; _s4_w = 0.0
		_show_dash_cap = false
	if _snatcher_killed:
		_s5_w = 0.0; _gulp_fx_t = 0.0; _active_snatcher = null


func _exit_tree() -> void:
	_unbind_events()


func _sync_events() -> void:
	if Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events:
		return
	_unbind_events()
	_bound_events = Lx.events
	if not _bound_events.enemy_hit.is_connected(_on_enemy_hit):
		_bound_events.enemy_hit.connect(_on_enemy_hit)
	if not _bound_events.enemy_killed.is_connected(_on_enemy_killed):
		_bound_events.enemy_killed.connect(_on_enemy_killed)
	if not _bound_events.lantern_thrown.is_connected(_on_lantern_thrown):
		_bound_events.lantern_thrown.connect(_on_lantern_thrown)
	if _bound_events.has_signal("lantern_picked_up") and not _bound_events.is_connected("lantern_picked_up", _on_lantern_picked_up):
		_bound_events.connect("lantern_picked_up", _on_lantern_picked_up)
	if not _bound_events.lantern_dropped.is_connected(_on_lantern_dropped):
		_bound_events.lantern_dropped.connect(_on_lantern_dropped)


func _unbind_events() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events):
		_bound_events = null
		return
	if _bound_events.enemy_hit.is_connected(_on_enemy_hit):
		_bound_events.enemy_hit.disconnect(_on_enemy_hit)
	if _bound_events.enemy_killed.is_connected(_on_enemy_killed):
		_bound_events.enemy_killed.disconnect(_on_enemy_killed)
	if _bound_events.lantern_thrown.is_connected(_on_lantern_thrown):
		_bound_events.lantern_thrown.disconnect(_on_lantern_thrown)
	if _bound_events.has_signal("lantern_picked_up") and _bound_events.is_connected("lantern_picked_up", _on_lantern_picked_up):
		_bound_events.disconnect("lantern_picked_up", _on_lantern_picked_up)
	if _bound_events.lantern_dropped.is_connected(_on_lantern_dropped):
		_bound_events.lantern_dropped.disconnect(_on_lantern_dropped)
	_bound_events = null


func _on_lantern_dropped(_at: Vector2) -> void:
	_snatcher_recovered = true
	if Lx.state != null:
		Lx.state.story_flags["tut_snatcher_recovered"] = true


func _on_lantern_picked_up(_pickup_id: String, pickup_pos: Vector2) -> void:
	_pickup_burst_pos = pickup_pos; _pickup_burst_t = 0.65


func _on_lantern_thrown(_pos: Vector2, _dir: Vector2) -> void:
	_has_thrown = true
	if _throw_hint_shown and Lx.events != null:
		Lx.events.prompt_requested.emit("", "", 0.0)


func _trigger_throw_combat_hint() -> void:
	if _throw_hint_shown or _core_suppressed:
		return
	_throw_hint_shown = true
	if Lx.state != null:
		Lx.state.story_flags["throw_combat_hint_shown"] = true
	if Lx.events != null:
		Lx.events.prompt_requested.emit("PROMPT_THROW", "lx_throw", 3.0)


func _on_enemy_hit(enemy: Object, hit: Object, result: int) -> void:
	if not (enemy is LxEnemyBrain):
		return
	var eb: LxEnemyBrain = enemy as LxEnemyBrain
	if eb.enemy_id == "warden_plaza_0":
		_warden_hit = true
	if _core_suppressed or _throw_hint_shown or _has_thrown or not _has_lantern() or Lx.state == null or not Lx.state.has_move("throw"):
		return
	var src: String = str(hit.get("source")) if (hit != null and hit.get("source") != null) else ""
	if result == LxEnemyBrain.HitResult.BLOCKED and src != "throw":
		if eb.kind == "snatcher":
			_trigger_throw_combat_hint()
		elif eb.kind == "warden" and eb.enemy_id != "warden_plaza_0":
			_warden_blocks += 1
			if _warden_blocks >= 2:
				_trigger_throw_combat_hint()


func _on_enemy_killed(enemy: Object, kind: String, pos: Vector2, _opened: bool) -> void:
	if enemy is LxEnemyBrain and (enemy as LxEnemyBrain).enemy_id == "warden_plaza_0":
		_warden_death_pos = pos
		_warden_died = true
		_celebrate_t = 3.2
		if Lx.state != null:
			Lx.state.story_flags["tut_plaza_warden_dead"] = true
		if Lx.events != null:
			Lx.events.prompt_requested.emit("", "", 0.0)
	if kind == "snatcher" or enemy is LxSnatcherBrain:
		_mark_snatcher_killed()


func _mark_snatcher_killed() -> void:
	_snatcher_killed = true
	_s5_w = 0.0
	_gulp_fx_t = 0.0
	_active_snatcher = null
	if Lx.state != null:
		Lx.state.story_flags["tut_snatcher_killed"] = true


func _process(delta: float) -> void:
	if Lx.state == null or Lx.state.island_id != 1 or Lx.state.region_id != "overworld":
		visible = false
		return
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		visible = false
		return
	visible = true
	if _bound_events != Lx.events:
		_sync_events()
	_clock += delta
	_pickup_burst_t = maxf(0.0, _pickup_burst_t - delta)
	_celebrate_t = maxf(0.0, _celebrate_t - delta)
	_gulp_fx_t = maxf(0.0, _gulp_fx_t - delta)
	var wpos: Vector2 = _player_pos()
	var has_lan: bool = _has_lantern()
	var lan: Dictionary = _lantern_status()
	if not _has_thrown and bool(lan["out"]):
		_has_thrown = true
	if has_lan and not _prev_has_lantern:
		_pickup_burst_pos = _interactable_pos("lantern_pickup_1", POS_LANTERN)
		_pickup_burst_t = 0.65
	_prev_has_lantern = has_lan

	_core_suppressed = _compute_core_suppressed()
	if bool(Lx.state.story_flags.get("tut_snatcher_killed", false)):
		_snatcher_killed = true

	var warden: LxEnemyBrain = _find_warden()
	var warden_alive: bool = warden != null and warden.is_alive()
	if warden_alive and warden.hp < warden.max_hp:
		_warden_hit = true
	if _prev_warden_alive and not warden_alive:
		_warden_died = true
		_celebrate_t = 3.2
		Lx.state.story_flags["tut_plaza_warden_dead"] = true
	if not _warden_died and (_core_suppressed or _any_island1_beacon_lit()):
		_warden_died = true
		Lx.state.story_flags["tut_plaza_warden_dead"] = true
	_prev_warden_alive = (not _warden_died) and warden_alive

	var beacon_orchard_lit: bool = _is_beacon_lit("beacon_orchard")
	var has_dash: bool = Lx.state.has_move("dash") or Lx.state.claimed_shrines.has("shrine_dash")
	if has_dash and not _dash_crossed:
		var crossed_chasm: bool = (wpos.y >= 274.0 and wpos.x >= 148.0 and wpos.x <= 220.0) \
				or (wpos.y >= 274.0 and absf(wpos.x - 184.0) <= 68.0) \
				or (_player_is_dashing() and wpos.distance_to(Vector2(184.0, 250.0)) <= 52.0)
		if _is_beacon_lit("beacon_observatory") or _is_inter_bool("lamp_orchard_s", "lit") or crossed_chasm:
			_dash_crossed = true
			Lx.state.story_flags["tut_dash_crossed"] = true
			if Lx.events != null:
				Lx.events.prompt_requested.emit("", "", 0.0)
	if not _river_crossed and wpos.x >= 1036.0 and wpos.y >= 260.0 and wpos.y <= 450.0:
		_river_crossed = true
		Lx.state.story_flags["tut_river_crossed"] = true

	var t0: float = 0.0; var t1: float = 0.0; var t2: float = 0.0
	var t3_h: float = 0.0; var t3_g: float = 0.0; var t4: float = 0.0
	if _core_suppressed:
		_show_dash_cap = false
	else:
		t0 = 1.0 if (not has_lan) else 0.0
		t1 = (0.56 if _warden_hit else 1.0) if (has_lan and not _warden_died and warden_alive and wpos.distance_to(warden.pos) <= 220.0) else 0.0
		t2 = 1.0 if (has_lan and (_warden_died or not warden_alive) and not beacon_orchard_lit and wpos.x <= 780.0 and wpos.y <= 440.0) else 0.0
		t3_h = 1.0 if (has_lan and (not has_dash or not beacon_orchard_lit) and wpos.distance_to(POS_SHRINE_DASH.lerp(POS_BEACON_ORCHARD, 0.5)) <= 160.0) else 0.0
		var dist_rim: float = wpos.distance_to(Vector2(clampf(wpos.x, 164.0, 204.0), 236.0))
		_show_dash_cap = has_dash and not _dash_crossed and dist_rim <= 56.0
		t3_g = clampf((56.0 - dist_rim) / 28.0, 0.0, 1.0) if _show_dash_cap else 0.0
		t4 = 1.0 if (has_lan and Lx.state.has_move("throw") and not _is_river_resolved() and wpos.x >= 870.0 and wpos.y >= 260.0 and wpos.y <= 450.0) else 0.0

	var t5: float = _step_snatcher_tutorial(delta, wpos, has_lan, lan)
	_s0_w = move_toward(_s0_w, t0, delta * (4.2 if t0 < _s0_w else 3.2))
	_s1_w = move_toward(_s1_w, t1, delta * (4.0 if t1 < _s1_w else 2.8))
	_s2_w = move_toward(_s2_w, t2, delta * 2.4)
	_s3_halo_w = move_toward(_s3_halo_w, t3_h, delta * 2.5)
	_s3_gap_w = move_toward(_s3_gap_w, t3_g, delta * 4.0)
	_s4_w = move_toward(_s4_w, t4, delta * 3.2)
	_s5_w = move_toward(_s5_w, t5, delta * (4.5 if t5 < _s5_w else 3.6))
	if _s0_w > 0.01 or _s1_w > 0.01 or _s2_w > 0.01 or _s3_halo_w > 0.01 or _s3_gap_w > 0.01 \
			or _s4_w > 0.01 or _s5_w > 0.01 or _pickup_burst_t > 0.0 or _gulp_fx_t > 0.0:
		queue_redraw()


func _step_snatcher_tutorial(delta: float, wpos: Vector2, has_lan: bool, lan: Dictionary) -> float:
	var lan_out: bool = bool(lan["out"])
	var lan_carried: bool = bool(lan["carried"])
	var allow_stolen_rescue: bool = not _snatcher_recovered and not _core_suppressed
	if not has_lan or (_snatcher_killed and not (lan_carried and allow_stolen_rescue)):
		_active_snatcher = null
		_snatcher_near_t = 0.0
		return 0.0
	if not _snatcher_killed:
		for prev_sn: LxSnatcherBrain in _tracked_snatchers:
			if is_instance_valid(prev_sn) and not prev_sn.is_alive():
				_mark_snatcher_killed()
				return 0.0
	var best: LxSnatcherBrain = null
	var best_score: float = INF
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		var arr: Variant = Lx.world.call("get_enemies")
		if arr is Array:
			for e: Variant in (arr as Array):
				if not (e is LxSnatcherBrain) or not is_instance_valid(e):
					continue
				var sn: LxSnatcherBrain = e as LxSnatcherBrain
				if not sn.is_alive():
					continue
				var d: float = wpos.distance_to(sn.pos)
				if d > SNATCHER_RANGE:
					continue
				if not _tracked_snatchers.has(sn):
					_tracked_snatchers.append(sn)
				var sid: int = sn.get_instance_id()
				var prev_g: int = int(_snatcher_gulps.get(sid, 0))
				if sn.gulp_count > prev_g:
					_snatcher_gulps[sid] = sn.gulp_count
					_snatcher_gulped_any = true
					_gulp_fx_t = GULP_FX_DUR
					_gulp_fx_pos = sn.pos + Vector2(0.0, -9.0)
				elif sn.gulp_t > 0.0:
					_snatcher_gulped_any = true
					_gulp_fx_pos = sn.pos + Vector2(0.0, -9.0)
					_gulp_fx_t = maxf(_gulp_fx_t, GULP_FX_DUR * 0.85)
				var bias: float = -400.0 if (sn.carrying_lantern or sn.sub_state == LxSnatcherBrain.SubState.CARRY) else (-200.0 if _is_snatcher_active_substate(sn.sub_state) else 0.0)
				var score: float = d + bias
				if score < best_score:
					best_score = score
					best = sn
	_active_snatcher = best
	if best == null:
		_snatcher_near_t = maxf(0.0, _snatcher_near_t - delta * 1.5)
		return 0.0
	var is_stolen: bool = best.carrying_lantern or best.sub_state == LxSnatcherBrain.SubState.CARRY or lan_carried
	if is_stolen:
		return 1.0 if (not _snatcher_killed or allow_stolen_rescue) else 0.0
	if _snatcher_killed:
		return 0.0
	if lan_out:
		return 1.0
	if bool(lan["in_hand"]):
		_snatcher_near_t += delta
	if _is_snatcher_active_substate(best.sub_state):
		return 1.0
	if bool(lan["in_hand"]) and (_snatcher_gulped_any or best.gulp_count > 0 or _snatcher_near_t >= SNATCHER_LINGER_S):
		return 1.0
	return 0.0


func _draw() -> void:
	if not visible or Lx.state == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	var wpos: Vector2 = _player_pos()
	if _pickup_burst_t > 0.0:
		var u: float = 1.0 - clampf(_pickup_burst_t / 0.65, 0.0, 1.0)
		var col: Color = LxPalette.fade_step(1.0 - u, "cream" if u < 0.35 else "gold")
		if col.a > 0.0:
			draw_arc(_pickup_burst_pos.round(), roundf(lerpf(6.0, 26.0 if fred else 32.0, u)), 0.0, TAU, 20, col, 1.0, false)
	if _s0_w > 0.08: _draw_stage0_lantern_pull(wpos, _s0_w, fred)
	if _s1_w > 0.08: _draw_stage1_shoot_cue(wpos, _s1_w, fred)
	if _s2_w > 0.08: _draw_stage2_leading_path(wpos, _s2_w, fred)
	if _s3_halo_w > 0.08: _draw_stage3_orchard_harmony(_s3_halo_w, fred)
	if _s3_gap_w > 0.08: _draw_stage3_dash_chasm(_s3_gap_w, fred)
	if _s4_w > 0.08: _draw_stage4_river_throw(wpos, _s4_w, fred)
	if not _snatcher_killed and _gulp_fx_t > 0.0:
		var gu: float = 1.0 - clampf(_gulp_fx_t / GULP_FX_DUR, 0.0, 1.0)
		G.draw_gulp_reject_x(self, _gulp_fx_pos, gu, clampf(_gulp_fx_t / 0.45, 0.0, 1.0), fred)
	if _s5_w > 0.08 and _active_snatcher != null and is_instance_valid(_active_snatcher) and _active_snatcher.is_alive():
		_draw_stage5_snatcher(wpos, _active_snatcher, _s5_w, fred)


func _draw_stage0_lantern_pull(wpos: Vector2, w: float, fred: bool) -> void:
	G.draw_stage0_lantern(self, wpos, _interactable_pos("lantern_pickup_1", POS_LANTERN).round(), w, _clock, fred)


func _draw_stage1_shoot_cue(wpos: Vector2, w: float, fred: bool) -> void:
	var warden: LxEnemyBrain = _find_warden()
	var w_target: Vector2 = warden.pos if (warden != null and warden.is_alive()) else POS_WARDEN
	G.draw_stage1_shoot(self, wpos, w_target, w, _clock, fred)


func _draw_stage2_leading_path(wpos: Vector2, w: float, fred: bool) -> void:
	var pts: Array[Vector2] = [
		_warden_death_pos + Vector2(0.0, -6.0),
		_interactable_pos("lamp_plaza_w", LEADING_LAMPS[0]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("lamp_orchard_turn", LEADING_LAMPS[1]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("lamp_orchard_e", LEADING_LAMPS[2]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("beacon_orchard", POS_BEACON_ORCHARD) + Vector2(0.0, -10.0),
	]
	var next_pos: Vector2 = _interactable_pos("beacon_orchard", POS_BEACON_ORCHARD)
	var targeting_beacon: bool = true
	for entry: Dictionary in LEADING_LAMPS:
		var lid: String = str(entry["id"])
		if not _is_inter_bool(lid, "lit"):
			next_pos = _interactable_pos(lid, entry["pos"] as Vector2)
			targeting_beacon = false
			break
	var show_head: bool = not (targeting_beacon and wpos.distance_to(next_pos) <= 96.0)
	G.draw_stage2_path(self, pts, next_pos, show_head, _celebrate_t, w, _clock, fred)


func _draw_stage3_orchard_harmony(w: float, fred: bool) -> void:
	var s_pos: Vector2 = _interactable_pos("shrine_dash", POS_SHRINE_DASH) + Vector2(15.0, 2.0)
	var b_pos: Vector2 = _interactable_pos("beacon_orchard", POS_BEACON_ORCHARD) + Vector2(-15.0, 2.0)
	G.draw_stage3_orchard(self, s_pos, b_pos, w, _clock, fred)


func _draw_stage3_dash_chasm(w: float, fred: bool) -> void:
	G.draw_stage3_chasm(self, POS_CHASM_TOP, POS_CHASM_BOT, _show_dash_cap, w, _clock, fred)


func _draw_stage4_river_throw(wpos: Vector2, w: float, fred: bool) -> void:
	var lan: Dictionary = _lantern_status()
	var brazier_pos: Vector2 = _interactable_pos("brazier_river_east", POS_BRAZIER_EAST)
	G.draw_stage4_river(self, wpos, brazier_pos, POS_PIER_LIP, bool(lan["out"]), lan["pos"] as Vector2, w, _clock, fred)


func _draw_stage5_snatcher(wpos: Vector2, sn: LxSnatcherBrain, w: float, fred: bool) -> void:
	var lan: Dictionary = _lantern_status()
	var lan_out: bool = bool(lan["out"])
	var lan_carried: bool = bool(lan["carried"])
	var lan_in_hand: bool = bool(lan["in_hand"])
	var lan_pos: Vector2 = lan["pos"] as Vector2
	var ss: int = sn.sub_state
	var bob: float = 0.0 if fred else roundf(sin(_clock * 3.8) * 1.0)
	var sn_center: Vector2 = (sn.pos + Vector2(0.0, -5.0)).round()
	var has_dash: bool = Lx.state != null and Lx.state.has_move("dash")

	# Case B: Bird stole the lantern -> urgent Dash (SHIFT) into the bird to recover the lantern & kill it
	var is_stolen: bool = lan_carried or sn.carrying_lantern or ss == LxSnatcherBrain.SubState.CARRY
	if is_stolen:
		G.draw_stolen_alert_ring(self, sn_center, w, _clock, fred)
		if has_dash:
			G.draw_strike_chevrons(self, wpos + Vector2(0.0, -5.0), sn_center, w, _clock, fred, true)
			var d_side: float = -18.0 if sn_center.x >= wpos.x else 18.0
			G.draw_dash_keycap(self, (wpos + Vector2(d_side, -23.0 + bob)).round(), w, _clock, fred)
		return

	if _snatcher_killed:
		return

	# Case A: Lantern is out on the ground & NOT stolen -> press LMB to Zip into the lantern to blast-kill the bird
	if lan_out:
		var z_target: Vector2 = lan_pos + Vector2(0.0, -4.0)
		var diving_or_close: bool = ss == LxSnatcherBrain.SubState.TELL or ss == LxSnatcherBrain.SubState.RUN \
				or ss == LxSnatcherBrain.SubState.GRAB or sn.pos.distance_to(lan_pos) <= 56.0
		var pulse_hot: bool = fred or fmod(_clock, 0.42 if diving_or_close else 0.72) < (0.24 if diving_or_close else 0.36)
		var br: float = 10.0 + (0.0 if fred else roundf(sin(_clock * (6.5 if diving_or_close else 3.8)) * 1.5))
		var c_br: Color = LxPalette.fade_step(w, "cream" if (diving_or_close and pulse_hot) else "gold")
		if c_br.a > 0.0:
			G.draw_target_brackets(self, sn_center, br, c_br)
		G.draw_zip_blast_zone(self, z_target, sn_center, diving_or_close, w, _clock, fred)
		G.draw_strike_chevrons(self, wpos + Vector2(0.0, -5.0), z_target, w, _clock, fred, false)
		var l_side: float = -15.0 if z_target.x >= wpos.x else 15.0
		G.draw_pixel_mouse(self, (wpos + Vector2(l_side, -22.0 + bob)).round(), false, w, _clock, fred)
		return

	# Case C: Bird is baffled right beside Wick while lantern is back in hand -> Dash strike opening
	if ss == LxSnatcherBrain.SubState.BAFFLED and has_dash and wpos.distance_to(sn.pos) <= SNATCHER_DASH_RANGE:
		var c_bf: Color = LxPalette.fade_step(w, "cream" if (fred or fmod(_clock, 0.44) < 0.24) else "gold")
		if c_bf.a > 0.0:
			G.draw_target_brackets(self, sn_center, 10.0, c_bf)
		G.draw_strike_chevrons(self, wpos + Vector2(0.0, -5.0), sn_center, w, _clock, fred, true)
		var b_side: float = -18.0 if sn_center.x >= wpos.x else 18.0
		G.draw_dash_keycap(self, (wpos + Vector2(b_side, -23.0 + bob)).round(), w, _clock, fred)
		return

	# Case 0: Lantern in hand -> throw lantern as bait (RMB)
	if lan_in_hand and (_snatcher_gulped_any or sn.gulp_count > 0 or _snatcher_near_t >= SNATCHER_LINGER_S):
		var bait_pos: Vector2 = _find_bait_ground(wpos, sn)
		G.draw_bait_guide(self, wpos + Vector2(0.0, -6.0), bait_pos, w, _clock, fred)
		var r_side: float = -15.0 if bait_pos.x >= wpos.x else 15.0
		G.draw_pixel_mouse(self, (wpos + Vector2(r_side, -22.0 + bob)).round(), true, w, _clock, fred)


func _find_bait_ground(wpos: Vector2, sn: LxSnatcherBrain) -> Vector2:
	var raw: Vector2 = wpos.lerp(sn.pos, 0.5)
	var leash_cap: float = maxf(20.0, sn.leash_radius - 12.0)
	if raw.distance_to(sn.home) > leash_cap:
		raw = sn.home + (raw - sn.home).normalized() * leash_cap
	var from_w: Vector2 = raw - wpos
	var d: float = from_w.length()
	if d < 22.0:
		var dir_to_sn: Vector2 = (sn.pos - wpos).normalized() if sn.pos.distance_to(wpos) > 1.0 else Vector2.RIGHT
		raw = wpos + dir_to_sn * 28.0
	elif d > 92.0:
		raw = wpos + (from_w / d) * 92.0
	if _is_open_ground(raw):
		return raw
	for off: Vector2 in [Vector2(0.0, 12.0), Vector2(0.0, -12.0), Vector2(12.0, 0.0), Vector2(-12.0, 0.0)]:
		var cand: Vector2 = raw + off
		if _is_open_ground(cand):
			return cand
	return raw


func _is_open_ground(pt: Vector2) -> bool:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("tile_at"):
		return true
	var tt: String = str(Lx.world.call("tile_at", pt))
	return not LxMapFormat.is_solid_tile(tt, false, false)


static func _is_snatcher_active_substate(ss: int) -> bool:
	return ss == LxSnatcherBrain.SubState.TELL or ss == LxSnatcherBrain.SubState.RUN \
			or ss == LxSnatcherBrain.SubState.GRAB or ss == LxSnatcherBrain.SubState.CARRY \
			or ss == LxSnatcherBrain.SubState.BAFFLED


func _compute_core_suppressed() -> bool:
	var st: LxGameState = Lx.state
	if st == null:
		return false
	if bool(st.story_flags.get("tut_belfry_entered", false)) or bool(st.story_flags.get("isl1_belfry_entered", false)):
		return true
	if st.relit_islands.has(1) or st.defeated_bosses.has("bellkeeper"):
		return true
	if _all_island1_beacons_lit():
		return true
	for vr: String in st.visited_regions:
		if vr.begins_with("1:belfry_"):
			return true
	return false


func _any_island1_beacon_lit() -> bool:
	return _is_beacon_lit("beacon_orchard") or _is_beacon_lit("beacon_observatory") or _is_beacon_lit("beacon_bridge")


func _all_island1_beacons_lit() -> bool:
	return _is_beacon_lit("beacon_orchard") and _is_beacon_lit("beacon_observatory") and _is_beacon_lit("beacon_bridge")


func _has_lantern() -> bool:
	if Lx.state == null: return true
	if Lx.state.has_method("has_lantern"): return bool(Lx.state.call("has_lantern"))
	if bool(Lx.state.story_flags.get("lantern_picked_up", false)): return true
	if Lx.world != null and Lx.world.has_method("find_interactable"): return Lx.world.call("find_interactable", "lantern_pickup_1") == null
	return true


func _player_pos() -> Vector2:
	return (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(708.0, 366.0)


func _player_is_dashing() -> bool:
	return Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing"))


func _lantern_status() -> Dictionary:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return {"out": false, "carried": false, "in_hand": true, "pos": Vector2.ZERO}
	var lv: Variant = Lx.player.get("lantern")
	if not (lv is Object) or not is_instance_valid(lv):
		return {"out": false, "carried": false, "in_hand": true, "pos": Vector2.ZERO}
	var lan: Object = lv as Object
	var is_out: bool = lan.has_method("is_lure_active") and bool(lan.call("is_lure_active"))
	var st_i: int = int(lan.get("state")) if lan.get("state") != null else 0
	var is_carried: bool = st_i == int(LxLantern.State.CARRIED)
	var in_hand: bool = (lan.has_method("is_in_hand") and bool(lan.call("is_in_hand"))) or (not is_out and not is_carried and st_i == int(LxLantern.State.IN_HAND))
	return {"out": is_out, "carried": is_carried, "in_hand": in_hand, "pos": lan.get("pos") as Vector2 if lan.get("pos") is Vector2 else Vector2.ZERO}


func _find_warden() -> LxEnemyBrain:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"): return null
	var arr: Variant = Lx.world.call("get_enemies")
	if arr is Array:
		for e: Variant in (arr as Array):
			if e is LxEnemyBrain and is_instance_valid(e) and (e as LxEnemyBrain).enemy_id == "warden_plaza_0": return e as LxEnemyBrain
	return null


func _interactable_pos(id: String, fallback: Vector2) -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("find_interactable"):
		var it: Variant = Lx.world.call("find_interactable", id)
		if it is LxInteractable and is_instance_valid(it): return (it as LxInteractable).pos
	return fallback


func _is_inter_bool(id: String, prop: String) -> bool:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("find_interactable"):
		var it: Variant = Lx.world.call("find_interactable", id)
		if it is LxInteractable and is_instance_valid(it): return bool((it as Object).get(prop))
	return false


func _is_beacon_lit(bid: String) -> bool:
	return (Lx.state != null and (Lx.state.lit_beacons.has(bid) or bool(Lx.state.story_flags.get(bid, false)))) or _is_inter_bool(bid, "lit")


func _is_river_resolved() -> bool:
	if _river_crossed: return true
	if Lx.state != null and (bool(Lx.state.story_flags.get("tut_river_crossed", false)) or bool(Lx.state.story_flags.get("river_bridge_raised", false)) or _is_beacon_lit("beacon_bridge")):
		return true
	return _is_inter_bool("brazier_river_east", "lit") or _is_inter_bool("door_river_bridge", "opened")
