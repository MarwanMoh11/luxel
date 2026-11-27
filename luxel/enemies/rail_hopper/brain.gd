class_name LxRailHopperBrain
extends LxEnemyBrain
## Rail Hopper (Island 6, Ashen Kiln — Flanker / Skirmisher).
## Spring-heeled brass rail-locust that hops along iron perches, coiling springs (0.46s tell)
## with a crisp landing ring before vaulting over cover in a 0.30s parabolic arc.
## Counterplay: mid-air intercept slams it into stagger (Scatter/Bolt/Throw), Skip snipes behind
## cover (1.25x), Dash/Wings evades landing and punishes 1.10s spring-compress recovery.

const LEAP_RANGE: float = 104.0
const LEAP_MAX_DIST: float = 68.0
const LEAP_TIME: float = 0.30
const LEAP_HEIGHT: float = 20.0
const LAND_HIT_R: float = 16.0
const PERCH_PAUSE_MIN: float = 0.75
const PERCH_PAUSE_MAX: float = 1.25

var perches: Array[Vector2] = []
var perch_i: int = 0
var pause_t: float = 0.7
var hop_z: float = 0.0
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var land_hit_done: bool = false


func _init() -> void:
	kind = "rail_hopper"
	island_id = 6
	max_hp = 2.0
	hp = 2.0
	body_radius = 5.5
	routine_speed = 56.0
	leash_radius = 156.0
	notice_radius = 132.0
	tell_time = 0.46
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 3
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
		var r: float = minf(46.0, leash_radius * 0.42)
		perches = [_clamp_pt(home + Vector2(-r, -12.0)), _clamp_pt(home + Vector2(r, -12.0)), _clamp_pt(home + Vector2(0.0, r * 0.55))]
	perch_i = 0
	pause_t = _randf_range(PERCH_PAUSE_MIN, PERCH_PAUSE_MAX)
	hop_z = 0.0
	leap_from = pos
	leap_to = pos
	land_hit_done = false


func is_flying() -> bool:
	return state == State.COMMIT and hop_z > 4.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var is_bounced: bool = str(h["source"]) == LxHit.SOURCE_PRISM
	var orig: Vector2 = h["origin"] as Vector2
	var mid_air: bool = is_flying()
	var post_land: bool = state == State.RECOVER

	if mid_air:
		dmg *= 1.35
	elif is_bounced or post_land:
		dmg *= 1.25

	var is_opening: bool = mid_air or post_land or is_bounced or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if (mid_air or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (130.0 if (mid_air or is_heavy) else 45.0)

	if hp <= 0.001:
		hop_z = 0.0
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if mid_air:
		hop_z = 0.0
		_release_token()
		state = State.STAGGER
		state_timer = 0.85
		_emit_sfx("shield_clang")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy:
		hop_z = 0.0
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			hop_z = 0.0
			_face_point(target, 5.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target)
		State.TELL:
			hop_z = 0.0
			if state_timer > 0.14 * _assist_tell_scale():
				_face_point(target, 3.6, dt)
				leap_to = _pick_leap_dest(target)
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
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			hop_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home
				hop_z = 0.0
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				hop_z = absf(sin(anim_t * 11.0)) * 5.0
				_move_step(to_h.limit_length(routine_speed * 0.88 * dt), false)
				if _sees_target(target) and target.distance_to(home) <= leash_radius:
					_enter_notice()


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		hop_z = 0.0
		return
	var wp: Vector2 = perches[perch_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		perch_i = (perch_i + 1) % perches.size()
		pause_t = _randf_range(PERCH_PAUSE_MIN, PERCH_PAUSE_MAX)
		hop_z = 0.0
		return
	facing = to_w.angle()
	hop_z = absf(sin(anim_t * 12.0)) * 5.5
	_move_step(to_w.limit_length(routine_speed * 0.80 * dt), false)


func _step_position(dt: float, target: Vector2) -> void:
	_face_point(target, 4.0, dt)
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var dist: float = pos.distance_to(target)
	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN
	if is_lead and cooldown <= 0.0 and dist <= LEAP_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		leap_to = _pick_leap_dest(target)
		hop_z = 0.0
		_emit_attack_started()
		_emit_sfx("piston_hiss")
		return

	# Flank-strafe at controlled speed (never exceeding routine_speed)
	var to_t: Vector2 = target - pos
	if dist > 1.0:
		var rad: Vector2 = to_t / dist
		var strafe: Vector2 = Vector2(-rad.y, rad.x) * (1.0 if (slot % 2 == 0) else -1.0)
		var radial: float = clampf((dist - 58.0) / 36.0, -0.45, 0.55)
		var move_v: Vector2 = (strafe * 0.72 + rad * radial).normalized() * (routine_speed * 0.78)
		hop_z = absf(sin(anim_t * 10.0)) * 3.5
		_move_step(move_v * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LEAP_TIME
	leap_from = pos
	land_hit_done = false
	var d: Vector2 = leap_to - leap_from
	if d.length() > 0.1:
		facing = d.angle()
	_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var u: float = 1.0 - clampf(state_timer / LEAP_TIME, 0.0, 1.0)
	var target_p: Vector2 = leap_from.lerp(leap_to, u)
	pos = _collide_move(pos, target_p, true)
	_clamp_to_leash()
	hop_z = sin(u * PI) * LEAP_HEIGHT
	if state_timer <= 0.0:
		hop_z = 0.0
		_emit_sfx("golem_stomp")
		if not land_hit_done and _has_player() and pos.distance_to(_get_wick_pos()) <= LAND_HIT_R:
			land_hit_done = true
			var push: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.from_angle(facing)
			_emit_player_hit(push, attack_damage)
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _pick_leap_dest(target: Vector2) -> Vector2:
	var off: Vector2 = target - pos
	if off.length() > LEAP_MAX_DIST:
		off = off.normalized() * LEAP_MAX_DIST
	return _clamp_pt(pos + off)


func _clamp_pt(pt: Vector2) -> Vector2:
	if leash_radius <= 0.0:
		return pt
	var off: Vector2 = pt - home
	var cap: float = maxf(0.0, leash_radius - 3.0)
	if off.length() > cap and off.length() > 0.01:
		return home + off.normalized() * cap
	return pt


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var d: Vector2 = pt - pos
	if d.length_squared() > 0.01:
		_turn_toward(d.angle(), rate, dt)


func _sees_target(t: Vector2) -> bool:
	if not _has_player() and not _is_lantern_out():
		return false
	return pos.distance_to(t) <= notice_radius


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	hop_z = 0.0
	state = State.NOTICE
	state_timer = 0.28
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("warden_alert")


func _visual_offset() -> Vector2:
	return Vector2(0.0, -roundf(hop_z))


func _body_color() -> Color:
	return PAL["apricot"] as Color


func _draw_extra(off: Vector2) -> void:
	if state == State.TELL or state == State.COMMIT:
		var dest_local: Vector2 = (leap_to - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration if state == State.TELL else LEAP_TIME, 0.05), 0.0, 1.0)
		var ring_c: Color = (PAL["cream"] if (state == State.COMMIT or prog > 0.72) else PAL["gold"]) as Color
		draw_circle(dest_local, LAND_HIT_R, Color(PAL["coral"] as Color, 0.16 if state == State.TELL else 0.28))
		draw_arc(dest_local, LAND_HIT_R, 0.0, TAU, 18, ring_c, 1.0)
		if state == State.TELL:
			draw_line(off.round(), dest_local, Color(PAL["apricot"] as Color, 0.65), 1.0)
