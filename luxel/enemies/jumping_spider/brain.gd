class_name LxJumpingSpiderBrain
extends LxEnemyBrain
## Jumping Spider (Island 3): Pit-vaulting flanker.
## Paces rims; hangs on taut silk during tell (0.52s) painting a landing ring decal,
## vaults over walls/pits (0.34s arc, flying) leaving a slow-silk patch, recovers 1.10s.
## Counterplay: Bolt cuts silk mid-tell/leap -> crash stun; Dash ring; Beam burns silk!

const LEAP_RANGE: float = 116.0
const LEAP_TIME: float = 0.34
const LEAP_HEIGHT: float = 22.0
const LAND_HIT_R: float = 17.0
const SILK_PATCH_R: float = 18.0
const SILK_PATCH_DUR: float = 3.0
const SILK_CUT_STAGGER: float = 0.95
const POST_COOLDOWN: float = 1.00

var perches: Array[Vector2] = []
var perch_i: int = 0
var pause_t: float = 0.0
var hop_z: float = 0.0
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var leap_hit: bool = false
var silk_patches: Array[Dictionary] = []


func _init() -> void:
	kind = "jumping_spider"
	island_id = 3
	max_hp = 3.0
	hp = 3.0
	body_radius = 6.0
	routine_speed = 44.0
	leash_radius = 160.0
	notice_radius = 124.0
	tell_time = 0.52
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	perches.clear()
	var raw_pts: Variant = spec.get("perches", spec.get("route", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				perches.append(_clamp_pt(_to_vec2(pt_v, home)))
	if perches.size() < 2:
		var r: float = minf(48.0, leash_radius * 0.42)
		perches = [
			_clamp_pt(home + Vector2(-r, -16.0)),
			_clamp_pt(home + Vector2(r, -16.0)),
			_clamp_pt(home + Vector2(0.0, 26.0)),
		]
	perch_i = 0
	pause_t = 0.5
	hop_z = 0.0
	leap_from = pos
	leap_to = pos
	leap_hit = false
	silk_patches.clear()


func is_flying() -> bool:
	return state == State.COMMIT and hop_z > 4.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"]) or src == LxHit.SOURCE_BEAM
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos

	# Signature counterplay: shooting spider during TELL or airborne COMMIT cuts its silk -> crash-stun!
	var silk_cut: bool = state == State.TELL or is_flying()
	if silk_cut:
		dmg *= 1.40
		hop_z = 0.0
		_emit_sfx("jumping_spider_silk_cut")
	elif state == State.RECOVER or state == State.STAGGER:
		dmg *= 1.25
	if src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		silk_patches.clear()

	hp -= dmg
	flash_t = 0.16 if (silk_cut or is_heavy) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if (silk_cut or is_heavy) else 36.0)

	if hp <= 0.001:
		silk_patches.clear()
		opened_kill = silk_cut or state == State.RECOVER or state == State.STAGGER
		_die(hit)
		return HitResult.KILLED

	if silk_cut:
		_release_token()
		state = State.STAGGER
		state_timer = SILK_CUT_STAGGER
		LxDamageFx.boss_impact(pos, 0.10, 48.0, 54.0, 44.0, 1.18, 0.24, "ice")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy:
		_release_token()
		hop_z = 0.0
		state = State.STAGGER
		state_timer = 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if (state == State.RECOVER or state == State.STAGGER) else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	_tick_silk_patches(dt)
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			hop_z = 0.0
			_step_routine(dt)
			if _sees_target(target_pos):
				_enter_notice()
		State.NOTICE:
			hop_z = 0.0
			_face_point(target_pos, 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			hop_z = 0.0
			if state_timer > 0.18 * _assist_tell_scale():
				_face_point(target_pos, 3.4, dt)
				leap_to = _clamp_pt(target_pos)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			hop_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			hop_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.50
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				hop_z = 0.0
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				hop_z = absf(sin(anim_t * 10.0)) * 4.0
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.26
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("jumping_spider_notice")


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = perches[perch_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		perch_i = (perch_i + 1) % perches.size()
		pause_t = 0.8
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.78 * dt), false)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.5, dt)
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

	if is_lead and cooldown <= 0.0 and dist <= LEAP_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		leap_to = _clamp_pt(target_pos)
		_emit_attack_started()
		_emit_sfx("jumping_spider_tell")
		return

	var spd: float = routine_speed * 0.80
	if dist > LEAP_RANGE * 0.76:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
		_move_step(perp * spd * 0.65 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LEAP_TIME
	leap_from = pos
	leap_hit = false
	var to_l: Vector2 = leap_to - leap_from
	if to_l.length() > 1.0:
		facing = to_l.angle()
	_emit_sfx("jumping_spider_leap")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var prog: float = 1.0 - clampf(state_timer / LEAP_TIME, 0.0, 1.0)
	hop_z = sin(prog * PI) * LEAP_HEIGHT
	var desired: Vector2 = leap_from.lerp(leap_to, prog)
	_move_step(desired - pos, true)
	if state_timer <= 0.0:
		hop_z = 0.0
		_emit_sfx("jumping_spider_land")
		silk_patches.append({"pos": pos, "ttl": SILK_PATCH_DUR})
		if silk_patches.size() > 3:
			silk_patches.pop_front()
		if not leap_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= LAND_HIT_R:
			leap_hit = true
			var push: Vector2 = (_get_wick_pos() - pos).normalized() if _get_wick_pos().distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_emit_player_hit(push)
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_silk_patches(dt: float) -> void:
	if silk_patches.is_empty():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var beam_on: bool = wick_node != null and wick_node.move_beam != null and wick_node.move_beam.beam_vis_t > 0.0
	for i: int in range(silk_patches.size() - 1, -1, -1):
		var sp: Dictionary = silk_patches[i]
		sp["ttl"] = float(sp["ttl"]) - dt
		var p: Vector2 = sp["pos"] as Vector2
		if beam_on and Geometry2D.get_closest_point_to_segment(p, wick_node.move_beam.beam_start, wick_node.move_beam.beam_end).distance_to(p) <= SILK_PATCH_R:
			silk_patches.remove_at(i)
			continue
		if wick_node != null and not wick_node.dead and not wick_node.is_dashing() and not wick_node.is_zipping():
			if wick_node.global_position.distance_to(p) <= SILK_PATCH_R and wick_node.velocity.length_squared() > 16.0:
				if wick_node.has_method("push_external"):
					wick_node.call("push_external", -wick_node.velocity * 0.42, "spider_silk")
		if float(sp["ttl"]) <= 0.0:
			silk_patches.remove_at(i)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	return home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _visual_offset() -> Vector2:
	return Vector2(0.0, 2.0) if state == State.TELL else Vector2(0.0, -hop_z)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	for sp: Dictionary in silk_patches:
		var rel: Vector2 = ((sp["pos"] as Vector2) - pos).round()
		var frac: float = clampf(float(sp["ttl"]) / SILK_PATCH_DUR, 0.0, 1.0)
		draw_circle(rel, SILK_PATCH_R, Color(PAL["ice"] as Color, 0.22 * frac))
		draw_arc(rel, SILK_PATCH_R, 0.0, TAU, 16, Color(PAL["stone"] as Color, 0.65 * frac), 1.0)
		draw_line(rel + Vector2(-8.0, -5.0), rel + Vector2(8.0, 5.0), Color(PAL["ice"] as Color, 0.55 * frac), 1.0)
		draw_line(rel + Vector2(-8.0, 5.0), rel + Vector2(8.0, -5.0), Color(PAL["ice"] as Color, 0.55 * frac), 1.0)
	if state == State.TELL:
		var c: Vector2 = off.round()
		var rel_l: Vector2 = (leap_to - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked: bool = state_timer <= 0.18 * _assist_tell_scale()
		var rc: Color = (PAL["coral"] if locked else PAL["gold"]) as Color
		# Overhead silk line + target landing ring
		draw_line(c + Vector2(0.0, -8.0), c + Vector2(0.0, -24.0), PAL["ice"] as Color, 1.0)
		draw_line(c, rel_l, PAL["void"] as Color, 3.0)
		draw_line(c, rel_l, rc, 1.0)
		draw_arc(rel_l, LAND_HIT_R, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(rel_l, LAND_HIT_R, 0.0, TAU, 20, rc, 2.0)
		draw_arc(rel_l, lerpf(LAND_HIT_R, 4.0, prog), 0.0, TAU, 16, PAL["void"] as Color, 3.0)
		draw_arc(rel_l, lerpf(LAND_HIT_R, 4.0, prog), 0.0, TAU, 16, PAL["cream"] as Color, 1.0)
