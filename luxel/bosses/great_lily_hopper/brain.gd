class_name LxGreatLilyHopperBoss
extends LxLilyHopperBrain
## Mirefen Gardens mini-boss (Island 4): Great Lily Hopper (Bible §4.6 upgrade).
## 2 phases, HP 12.0. Pairs twin shockwave hops & 3-Arc Lily-Petal Spit (0.95 s punish)
## with 4 perimeter thermal updraft plumes (Wings hover + 1.35x air intercepts) and
## Phase 2 Submerging Rim Pads on twin-hop landings.

enum HopperMove { LEAP_HOP, PETAL_SPIT }

const BOSS_RING_MAX_R: float = 70.0
const BOSS_RING_BAND: float = 9.5
const BOSS_LEAP_RANGE: float = 122.0
const TWIN_CROUCH_PAUSE: float = 0.42
const SPIT_MIN_RANGE: float = 44.0
const SPIT_MAX_RANGE: float = 132.0
const SPIT_TELL_P1: float = 0.50
const SPIT_TELL_P2: float = 0.46
const SPIT_COMMIT_TIME: float = 0.24
const SPIT_RECOVER: float = 0.95
const SPIT_CD_P1: float = 3.1
const SPIT_CD_P2: float = 2.4
const PETAL_SPEED: float = 112.0
const PETAL_RADIUS: float = 4.5
const PETAL_MAX_DIST: float = 128.0
const PETAL_SPREAD: float = 0.28
const PHASE2_ROAR_TIME: float = 0.56
const UPDRAFT_R: float = 20.0
const SUBMERGE_DUR: float = 2.4

var active_move: int = HopperMove.LEAP_HOP
var twin_hop_pending: bool = false
var twin_pause_active: bool = false
var spit_cd: float = 1.8
var spit_dir: Vector2 = Vector2.RIGHT
var spit_fired: bool = false
var petals: Array[Dictionary] = []
var _roaring: bool = false
var _updrafts: Array[Dictionary] = []        # [{pos, catch_cd, burst_t}]
var _submerged_pads: Array[Dictionary] = []  # [{pos, ttl, max_ttl}]


func _init() -> void:
	super._init()
	kind = "great_lily_hopper"
	boss_id = "great_lily_hopper"
	island_id = 4
	is_boss = true
	max_hp = 12.0
	hp = 12.0
	body_radius = 7.5
	routine_speed = 44.0
	leash_radius = 172.0
	notice_radius = 140.0
	tell_time = 0.52
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 15


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	max_hp = maxf(12.0, max_hp)
	hp = max_hp
	is_boss = true
	boss_id = str(spec.get("boss_id", "great_lily_hopper"))
	island_id = int(spec.get("island_id", 4))
	active_move = HopperMove.LEAP_HOP
	twin_hop_pending = false
	twin_pause_active = false
	spit_cd = 1.8
	spit_dir = Vector2.from_angle(facing)
	spit_fired = false
	petals.clear()
	_roaring = false
	_submerged_pads.clear()
	_setup_perimeter_updrafts()


func _setup_perimeter_updrafts() -> void:
	_updrafts.clear()
	# Skip built-in corner thermals if room already places real updraft_vent interactables
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "updraft_vent":
				return
	for off_v: Vector2 in [Vector2(-76.0, -44.0), Vector2(76.0, -44.0), Vector2(-76.0, 44.0), Vector2(76.0, 44.0)]:
		_updrafts.append({"pos": _clamp_pt(home + off_v), "catch_cd": 0.0, "burst_t": 0.0})


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	# Allow gliding Wick's mid-air bolt intercepts to trigger 1.35x air-stagger too!
	var gliding_intercept: bool = is_flying() and Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).is_gliding()
	var saved_boss: bool = is_boss
	if gliding_intercept:
		is_boss = false
	var res: int = super.take_hit(hit)
	is_boss = saved_boss
	if res == HitResult.KILLED:
		petals.clear()
		_submerged_pads.clear()
	elif is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		_roaring = true
		hop_z = 0.0
		active_move = HopperMove.LEAP_HOP
		twin_hop_pending = false
		twin_pause_active = false
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		spit_cd = 0.90
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.24, 90.0, 88.0)
		_emit_sfx("great_hopper_phase2")


func _step_brain(dt: float) -> void:
	spit_cd = maxf(0.0, spit_cd - dt)
	_step_petals(dt)
	_step_updrafts_and_pads(dt)
	if state == State.NOTICE and _roaring:
		hop_z = 0.0
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	if state == State.TELL and active_move == HopperMove.PETAL_SPIT:
		hop_z = 0.0
		if state_timer > 0.16 * _assist_tell_scale():
			var tpos: Vector2 = _attention_target()
			_face_point(tpos, 3.6, dt)
			spit_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	super._step_brain(dt)


func _step_petals(dt: float) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	var i: int = petals.size() - 1
	while i >= 0:
		var p: Dictionary = petals[i]
		var prev_p: Vector2 = p["pos"] as Vector2
		var pdir: Vector2 = p["dir"] as Vector2
		var step: float = PETAL_SPEED * dt
		var nxt_p: Vector2 = prev_p + pdir * step
		p["pos"] = nxt_p
		p["traveled"] = float(p["traveled"]) + step
		var remove_it: bool = float(p["traveled"]) >= PETAL_MAX_DIST or not _has_clear_view(prev_p, nxt_p)
		if not remove_it and _has_player() and nxt_p.distance_to(wick_p) <= PETAL_RADIUS + 4.5:
			_emit_player_hit(pdir)
			remove_it = true
		elif not remove_it and lan_out and nxt_p.distance_to(lan_p) <= PETAL_RADIUS + 5.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lan_p)
			remove_it = true
		if remove_it:
			petals.remove_at(i)
		i -= 1


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.2, dt)

	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN

	if is_lead and cooldown <= 0.0 and _is_on_screen():
		# Mid-range 3-Arc Lily-Petal Spit
		if spit_cd <= 0.0 and dist >= SPIT_MIN_RANGE and dist <= SPIT_MAX_RANGE \
				and _has_clear_view(pos, target_pos) and _claim_token():
			active_move = HopperMove.PETAL_SPIT
			state = State.TELL
			is_counter_attack = false
			var base_s: float = SPIT_TELL_P2 if phase >= 2 else SPIT_TELL_P1
			last_tell_duration = _scaled_tell(base_s, false, attack_damage)
			state_timer = last_tell_duration
			if dist > 0.01:
				facing = to_t.angle()
			spit_dir = Vector2.from_angle(facing)
			spit_fired = false
			hop_z = 0.0
			_emit_attack_started()
			_emit_sfx("hopper_crouch")
			return
		if dist <= BOSS_LEAP_RANGE and _claim_token():
			active_move = HopperMove.LEAP_HOP
			state = State.TELL
			is_counter_attack = false
			var base_t: float = 0.46 if phase >= 2 else tell_time
			last_tell_duration = _scaled_tell(base_t, false, attack_damage)
			state_timer = last_tell_duration
			leap_to = _clamp_pt(target_pos)
			hop_z = 0.0
			twin_hop_pending = phase >= 2
			twin_pause_active = false
			_emit_attack_started()
			_emit_sfx("hopper_crouch")
			return

	hop_z = absf(sin(anim_t * 9.0)) * 4.5
	var spd: float = minf(routine_speed * 0.84, routine_speed - 2.0)
	if dist > BOSS_LEAP_RANGE * 0.76:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if (slot % 2 == 0) else -1.0)
		_move_step(perp * spd * 0.65 * dt, false)


func _enter_commit() -> void:
	if active_move == HopperMove.PETAL_SPIT:
		state = State.COMMIT
		state_timer = SPIT_COMMIT_TIME
		spit_dir = Vector2.from_angle(facing)
		spit_fired = false
		_emit_sfx("barnacle_fire")
		return
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == HopperMove.PETAL_SPIT:
		if not spit_fired:
			spit_fired = true
			for idx: int in [-1, 0, 1]:
				var pdir: Vector2 = spit_dir.rotated(float(idx) * PETAL_SPREAD)
				petals.append({
					"pos": pos + pdir * (body_radius + 3.0),
					"dir": pdir,
					"traveled": 0.0,
				})
			_boss_impact(0.08, 48.0, 52.0)
		state_timer -= dt
		if state_timer <= 0.0:
			active_move = HopperMove.LEAP_HOP
			spit_cd = SPIT_CD_P2 if phase >= 2 else SPIT_CD_P1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, SPIT_RECOVER)
			last_recover_duration = state_timer
		return

	if twin_pause_active:
		hop_z = 0.0
		var target_pos: Vector2 = _attention_target()
		if state_timer > 0.14:
			_face_point(target_pos, 4.0, dt)
			leap_to = _clamp_pt(target_pos)
		state_timer -= dt
		if state_timer <= 0.0:
			twin_pause_active = false
			commit_stage = CommitStage.LEAP
			state_timer = LEAP_DURATION
			leap_from = pos
			ring_progress = 0.0
			ring_hit = false
			_boss_impact(0.10, 62.0, 58.0)
			_emit_sfx("hopper_leap")
		return

	if commit_stage == CommitStage.LEAP:
		super._step_commit(dt)
		return

	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / RING_DURATION, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, BOSS_RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= BOSS_RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if twin_hop_pending:
			_trigger_submerging_rim_pads()
			twin_hop_pending = false
			twin_pause_active = true
			state_timer = _scaled_tell(TWIN_CROUCH_PAUSE, false, attack_damage)
			leap_to = _clamp_pt(_attention_target())
			ring_progress = 0.0
			ring_hit = false
			_emit_sfx("hopper_crouch")
		else:
			if phase >= 2:
				_trigger_submerging_rim_pads()
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _trigger_submerging_rim_pads() -> void:
	_submerged_pads.clear()
	for off_v: Vector2 in [Vector2(-60.0, -34.0), Vector2(60.0, -34.0), Vector2(-60.0, 34.0), Vector2(60.0, 34.0)]:
		_submerged_pads.append({"pos": _clamp_pt(home + off_v), "ttl": SUBMERGE_DUR, "max_ttl": SUBMERGE_DUR})


func _step_updrafts_and_pads(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	for ud: Dictionary in _updrafts:
		ud["catch_cd"] = maxf(0.0, float(ud["catch_cd"]) - dt)
		ud["burst_t"] = maxf(0.0, float(ud["burst_t"]) - dt)
		if gliding and wick.move_wings != null and wick.global_position.distance_to(ud["pos"] as Vector2) <= UPDRAFT_R + 6.0:
			wick.move_wings.refresh_glide(1.25, 2.2)
			if float(ud["catch_cd"]) <= 0.0:
				ud["catch_cd"] = 0.42
				ud["burst_t"] = 0.30
				_emit_sfx("updraft_catch")
	for i: int in range(_submerged_pads.size() - 1, -1, -1):
		var sp: Dictionary = _submerged_pads[i]
		sp["ttl"] = float(sp["ttl"]) - dt
		if wick != null and not wick.dead and not gliding and wick.global_position.distance_to(sp["pos"] as Vector2) <= 15.0:
			if wick.has_method("push_external"):
				var away: Vector2 = (wick.global_position - (sp["pos"] as Vector2)).normalized()
				wick.push_external(away * 22.0, "submerged_pad")
		if float(sp["ttl"]) <= 0.0:
			_submerged_pads.remove_at(i)


func _body_color() -> Color:
	return (PAL["teal"] as Color) if phase >= 2 else (PAL["jade"] as Color)


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Royal twin-blossom lily crown
		var leaf_r: float = body_radius + (2.5 if state == State.TELL else 1.0)
		draw_arc(off + Vector2(0.0, -body_radius + 1.0), leaf_r * 0.85, 0.2, TAU - 0.2, 16, PAL["lime"] as Color, 2.2)
		draw_circle(off + Vector2(-3.0, -body_radius - 1.5), 2.2, PAL["rose"] as Color)
		draw_circle(off + Vector2(3.0, -body_radius - 1.5), 2.2, PAL["gold"] as Color)
	var c: Vector2 = off.round()
	if active_move == HopperMove.PETAL_SPIT and state == State.TELL:
		var hot_s: bool = state_timer <= 0.16 * _assist_tell_scale()
		var sc: Color = (PAL["coral"] if hot_s else PAL["rose"]) as Color
		for idx: int in [-1, 0, 1]:
			var pdir: Vector2 = spit_dir.rotated(float(idx) * PETAL_SPREAD)
			draw_line(c, (c + pdir * 72.0).round(), sc, 1.4 if hot_s else 1.0)
			draw_circle((c + pdir * 16.0).round(), 1.8, (PAL["cream"] if hot_s else PAL["rose"]) as Color)
	elif (active_move == HopperMove.LEAP_HOP and state == State.TELL) or twin_pause_active:
		var rel: Vector2 = (leap_to - pos).round()
		for oi: int in range(10):
			var a0: float = float(oi) * (TAU / 10.0)
			draw_arc(rel, BOSS_RING_MAX_R, a0, a0 + 0.28, 3, PAL["blue"] as Color, 1.0)
		var br: float = 9.5 + (0.0 if LxHudFx.flash_reduced() else 0.5 * sin(anim_t * 16.0))
		var locked_t: bool = state_timer <= 0.14
		draw_arc(rel, br, 0.0, TAU, 20, (PAL["gold"] if locked_t else PAL["sky"]) as Color, 2.0 if locked_t else 1.6)
		draw_arc(rel, maxf(3.0, br - 3.5), 0.0, TAU, 16, (PAL["cream"] if locked_t else PAL["ice"]) as Color, 1.2 if locked_t else 1.0)
		var b_off: float = br + 1.5
		for bi: int in range(4):
			var sx: float = -1.0 if (bi == 0 or bi == 3) else 1.0
			var sy: float = -1.0 if bi < 2 else 1.0
			var corner: Vector2 = (rel + Vector2(sx * b_off, sy * b_off)).round()
			draw_line(corner, corner + Vector2(-sx * 3.5, 0.0), PAL["cream"] as Color, 1.4)
			draw_line(corner, corner + Vector2(0.0, -sy * 3.5), PAL["cream"] as Color, 1.4)
		for ti: int in range(5):
			var t: float = float(ti + 1) / 6.0
			var arc_y: float = -sin(t * PI) * 14.0
			var bp: Vector2 = (c.lerp(rel, t) + Vector2(0.0, arc_y)).round()
			draw_circle(bp, 1.6, PAL["sky"] as Color)
			draw_circle(bp, 0.9, PAL["cream"] as Color)
	elif active_move == HopperMove.LEAP_HOP and state == State.COMMIT and commit_stage == CommitStage.RING:
		var ring_r: float = lerpf(RING_START_R, BOSS_RING_MAX_R, ring_progress)
		draw_arc(Vector2.ZERO, ring_r + 2.6, 0.0, TAU, 36, PAL["blue"] as Color, 2.4)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
		draw_arc(Vector2.ZERO, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
		draw_arc(Vector2.ZERO, maxf(2.0, ring_r - 3.8), 0.0, TAU, 24, PAL["cream"] as Color, 1.1)
		for pi: int in range(6):
			var pa: float = anim_t * 2.4 + float(pi) * (TAU / 6.0)
			var pd: Vector2 = Vector2.from_angle(pa)
			var pt: Vector2 = Vector2(-pd.y, pd.x)
			var p_pos: Vector2 = (pd * (ring_r + sin(anim_t * 9.0 + float(pi)) * 2.2)).round()
			draw_line((p_pos - pt * 2.5).round(), (p_pos + pt * 2.5).round(), PAL["coral"] as Color, 1.8)
			draw_circle(p_pos, 1.4, PAL["rose"] as Color)
			draw_circle(p_pos, 0.7, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.2, 0.0, TAU, 28, PAL["jade"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["lime"] as Color, 2.4)
		draw_arc(c, maxf(3.0, rr - 2.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)

	# Perimeter thermal updraft plumes (Wings hover + air-intercept support!)
	for ud: Dictionary in _updrafts:
		var up: Vector2 = ((ud["pos"] as Vector2) - pos).round()
		draw_arc(up, UPDRAFT_R, 0.0, TAU, 18, Color(PAL["sky"] as Color, 0.42), 1.0)
		draw_arc(up, UPDRAFT_R - 5.0, anim_t * 3.5, anim_t * 3.5 + PI * 1.1, 12, Color(PAL["ice"] as Color, 0.78), 1.2)
		draw_rect(Rect2(up + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), Color(PAL["night"] as Color, 0.70))
		draw_rect(Rect2(up + Vector2(-3.0, -1.0), Vector2(6.0, 2.0)), PAL["sky"] as Color)

	# Phase 2 Submerging Rim Pads (tidal ripple indicator)
	for sp: Dictionary in _submerged_pads:
		var pp_s: Vector2 = ((sp["pos"] as Vector2) - pos).round()
		var frac_s: float = clampf(float(sp["ttl"]) / maxf(float(sp["max_ttl"]), 0.05), 0.0, 1.0)
		draw_circle(pp_s, 14.0, Color(PAL["blue"] as Color, 0.36 * frac_s))
		draw_arc(pp_s, 14.0, 0.0, TAU, 14, Color(PAL["sky"] as Color, 0.78 * frac_s), 1.4)

	# Active Lily-Petal projectiles
	for p: Dictionary in petals:
		var pp: Vector2 = ((p["pos"] as Vector2) - pos).round()
		var pd: Vector2 = p["dir"] as Vector2
		draw_line((pp - pd * 6.0).round(), pp, PAL["wine"] as Color, 1.6)
		draw_circle(pp, PETAL_RADIUS, PAL["coral"] as Color)
		draw_circle(pp, PETAL_RADIUS * 0.65, PAL["rose"] as Color)
		draw_circle(pp, 1.3, PAL["cream"] as Color)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.05, 1.32, 0.34, "ice")
