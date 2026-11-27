class_name LxPetalDuelistBrain
extends LxEnemyBrain
## Petal Duelist (Island 4): rose glass-moth fencer.
## Parries frontal bolts (not Beam, Throw, Dash, or rear flank).
## Commits a 72 px Rapier Lunge and leaves a 2.0 s rose afterimage that telegraphs
## and repeats the exact lunge 1.2 s later! Echo Rose decoys bait both.

const PARRY_HALF_ANG: float = 1.05
const LUNGE_RANGE: float = 86.0
const LUNGE_DIST: float = 72.0
const LUNGE_COMMIT_S: float = 0.24
const LUNGE_HIT_R: float = 13.0
const ECHO_DELAY_S: float = 1.20
const ECHO_TELL_S: float = 0.50
const ECHO_COMMIT_S: float = 0.24
const ECHO_TOTAL_LIFE: float = 2.00
const POST_COOLDOWN: float = 1.05

var _route: Array[Vector2] = []
var _route_i: int = 0
var _pause_t: float = 0.4
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_hit: bool = false
var _parry_fx_t: float = 0.0

# Active rose afterimages: [{origin, pos, dir, age, hit, active}]
var _echoes: Array[Dictionary] = []


func _init() -> void:
	kind = "petal_duelist"
	island_id = 4
	max_hp = 3.5
	hp = 3.5
	body_radius = 5.5
	routine_speed = 48.0
	leash_radius = 158.0
	notice_radius = 132.0
	tell_time = 0.48
	recover_time = 1.05
	give_up_time = 1.9
	shard_drop = 5


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pt_v: Variant in (raw_r as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				_route.append(_clamp_pt(_to_vec2(pt_v, home)))
	if _route.size() < 2:
		var span: float = minf(40.0, leash_radius * 0.35)
		_route = [_clamp_pt(home + Vector2(-span, -8.0)), _clamp_pt(home + Vector2(span, 8.0))]
	_route_i = 0
	_pause_t = 0.35
	_lunge_dir = Vector2.from_angle(facing)
	_lunge_hit = false
	_parry_fx_t = 0.0
	_echoes.clear()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_heavy: bool = bool(h["stagger"])

	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) <= PARRY_HALF_ANG
	var can_parry: bool = state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]

	# Beam pierces straight through parry for 0.8s stagger!
	if (pierce or cracks) and can_parry:
		hp -= dmg * 1.15
		flash_t = 0.16
		if rel.length() > 0.01:
			knock = -rel.normalized() * 110.0
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		_release_token()
		state = State.STAGGER
		state_timer = 0.80
		_emit_sfx("warden_shield_break")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	# Frontal normal/prism bolts are parried while in fencing guard!
	if can_parry and from_front and (src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM):
		clank_t = 0.16
		_parry_fx_t = 0.25
		_emit_sfx("petal_parry")
		if state == State.ROUTINE:
			state = State.NOTICE
			state_timer = 0.26
			alert_t = 0.75
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	# Throw, Dash, Recall, flank bolts, or RECOVER/STAGGER punish deal full damage!
	var is_open: bool = state == State.RECOVER or state == State.STAGGER or not from_front
	hp -= dmg * (1.25 if is_open else 1.0)
	flash_t = 0.15 if (is_heavy or is_open) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 42.0)
	if hp <= 0.001:
		opened_kill = is_open
		_die(hit)
		return HitResult.KILLED
	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.72
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.28
		alert_t = 0.75
	_emit_enemy_hit(hit, HitResult.OPENED if is_open else HitResult.CHIPPED)
	return HitResult.OPENED if is_open else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_parry_fx_t = maxf(0.0, _parry_fx_t - dt)
	_tick_echoes(dt)
	var target_pos: Vector2 = _get_wick_pos()

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_player() and pos.distance_to(target_pos) <= notice_radius:
				state = State.NOTICE
				state_timer = 0.28
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("warden_notice")
		State.NOTICE:
			_face_point(target_pos, 4.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.8, dt)
				_lunge_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	if _pause_t > 0.0:
		_pause_t -= dt
		return
	var wp: Vector2 = _route[_route_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		_route_i = (_route_i + 1) % _route.size()
		_pause_t = 0.65
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.80 * dt), false)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 4.2, dt)

	var wick_p: Vector2 = _get_real_wick_pos()
	if not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0:
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

	if is_lead and cooldown <= 0.0 and dist <= LUNGE_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_lunge_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _lunge_dir.angle()
		_emit_attack_started()
		_emit_sfx("warden_windup")
		return

	var spd: float = routine_speed * 0.85
	if dist > LUNGE_RANGE * 0.78:
		_move_step(to_t.normalized() * spd * dt, false)
	elif dist < 36.0 and dist > 0.01:
		_move_step(-to_t.normalized() * spd * 0.7 * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if (slot % 2 == 0) else -1.0)
		_move_step(perp * spd * 0.7 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LUNGE_COMMIT_S
	_lunge_hit = false
	facing = _lunge_dir.angle()
	# Leave a rose afterimage at the lunge start that repeats 1.2s later!
	_echoes.append({
		"origin": pos,
		"pos": pos,
		"dir": _lunge_dir,
		"age": 0.0,
		"hit": false,
	})
	if _echoes.size() > 2:
		_echoes.pop_front()
	_emit_sfx("petal_lunge")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	var before: Vector2 = pos
	var spd: float = LUNGE_DIST / maxf(LUNGE_COMMIT_S, 0.05)
	_move_step(_lunge_dir * spd * dt, false)
	var tip: Vector2 = pos + _lunge_dir * 10.0
	if not _lunge_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, before, tip).distance_to(wp) <= LUNGE_HIT_R:
			_lunge_hit = true
			_emit_player_hit(_lunge_dir)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_echoes(dt: float) -> void:
	var scale_t: float = _assist_tell_scale()
	var commit_start: float = ECHO_DELAY_S * scale_t
	var commit_end: float = commit_start + ECHO_COMMIT_S
	var i: int = _echoes.size() - 1
	while i >= 0:
		var ec: Dictionary = _echoes[i]
		var prev_age: float = float(ec["age"])
		var age: float = prev_age + dt
		ec["age"] = age
		if prev_age < commit_start and age >= commit_start:
			_emit_sfx("petal_echo")
		if age >= commit_start and age <= commit_end:
			var edir: Vector2 = ec["dir"] as Vector2
			var epos: Vector2 = ec["pos"] as Vector2
			# Wind/fields gently nudge the rose afterimage too!
			var fa: Vector2 = LxFields.accel_at(epos, "enemy")
			var spd: float = LUNGE_DIST / maxf(ECHO_COMMIT_S, 0.05)
			var nxt: Vector2 = epos + (edir * spd + fa * 0.25) * dt
			if not bool(ec["hit"]) and _has_player():
				var wp: Vector2 = _get_wick_pos()
				if Geometry2D.get_closest_point_to_segment(wp, epos, nxt + edir * 8.0).distance_to(wp) <= LUNGE_HIT_R:
					ec["hit"] = true
					_emit_player_hit(edir)
			ec["pos"] = nxt
		if age >= maxf(ECHO_TOTAL_LIFE, commit_end + 0.35):
			_echoes.remove_at(i)
		i -= 1


func _die(hit: Object) -> void:
	_echoes.clear()
	super._die(hit)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _has_active_shield() -> bool:
	return state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]


func _shield_color() -> Color:
	return PAL["rose"] as Color


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _parry_fx_t > 0.0:
		draw_arc(c, body_radius + 5.5, facing - 0.95, facing + 0.95, 10, PAL["cream"] as Color, 2.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var end_p: Vector2 = (c + _lunge_dir * LUNGE_DIST).round()
		draw_line(c, end_p, PAL["void"] as Color, 4.0)
		draw_line(c, end_p, (PAL["coral"] if prog > 0.65 else PAL["rose"]) as Color, 2.0)
	elif state == State.COMMIT:
		draw_line((c - _lunge_dir * 12.0).round(), (c + _lunge_dir * 14.0).round(), PAL["void"] as Color, 5.0)
		draw_line((c - _lunge_dir * 12.0).round(), (c + _lunge_dir * 14.0).round(), PAL["rose"] as Color, 3.0)
		draw_line(c, (c + _lunge_dir * 15.0).round(), PAL["cream"] as Color, 1.0)

	# Draw rose-petal afterimages in local coordinates
	var scale_t: float = _assist_tell_scale()
	var commit_start: float = ECHO_DELAY_S * scale_t
	var tell_start: float = maxf(0.0, commit_start - ECHO_TELL_S * scale_t)
	var commit_end: float = commit_start + ECHO_COMMIT_S
	for ec: Dictionary in _echoes:
		var ep: Vector2 = ((ec["pos"] as Vector2) - pos).round()
		var edir: Vector2 = ec["dir"] as Vector2
		var age: float = float(ec["age"])
		var alpha: float = 0.55 if LxHudFx.flash_reduced() else 0.78
		# Ghost silhouette
		draw_rect(Rect2(ep + Vector2(-4.0, -14.0), Vector2(8.0, 14.0)), Color(PAL["wine"] as Color, alpha * 0.7))
		draw_rect(Rect2(ep + Vector2(-3.0, -13.0), Vector2(6.0, 11.0)), Color(PAL["rose"] as Color, alpha))
		draw_rect(Rect2(ep + Vector2(-1.0, -11.0), Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, alpha))
		if age >= tell_start and age < commit_start:
			var t_end: Vector2 = (ep + edir * LUNGE_DIST).round()
			draw_line(ep, t_end, Color(PAL["void"] as Color, alpha), 3.0)
			draw_line(ep, t_end, Color(PAL["rose"] as Color, alpha), 1.0)
			draw_arc(ep, 7.0, 0.0, TAU, 12, Color(PAL["cream"] as Color, alpha), 1.0)
		elif age >= commit_start and age <= commit_end:
			draw_line((ep - edir * 10.0).round(), (ep + edir * 14.0).round(), PAL["void"] as Color, 5.0)
			draw_line((ep - edir * 10.0).round(), (ep + edir * 14.0).round(), PAL["rose"] as Color, 3.0)
			draw_line(ep, (ep + edir * 15.0).round(), PAL["cream"] as Color, 1.0)
