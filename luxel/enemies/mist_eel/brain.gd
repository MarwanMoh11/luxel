class_name LxMistEelBrain
extends LxEnemyBrain
## Mist Eel (Island 4): aquatic ribbon arcer.
## Swims water ~/T and arcs 88 px between pools (obeying LxFields wind during leap).
## Mid-air bolt/Throw intercept deals 1.5x damage + 0.7 s stagger!
## Weather hook: dives briefly in RAIN; flops stranded & helpless (2x damage) in SUN!

const ARC_RANGE: float = 104.0
const ARC_DIST: float = 88.0
const ARC_COMMIT_S: float = 0.42
const ARC_HEIGHT: float = 20.0
const ARC_HIT_R: float = 14.0
const POST_COOLDOWN: float = 1.05
const AIR_INTERCEPT_MULT: float = 1.50
const AIR_STAGGER_S: float = 0.70

var _pools: Array[Vector2] = []
var _pool_i: int = 0
var _arc_from: Vector2 = Vector2.ZERO
var _arc_to: Vector2 = Vector2.ZERO
var _arc_z: float = 0.0
var _arc_hit: bool = false
var _stranded: bool = false
var _submerged: bool = false
var _dive_t: float = 0.0
var _flop_sfx_cd: float = 0.0


func _init() -> void:
	kind = "mist_eel"
	island_id = 4
	max_hp = 2.75
	hp = 2.75
	body_radius = 6.0
	routine_speed = 46.0
	leash_radius = 160.0
	notice_radius = 145.0
	tell_time = 0.52
	recover_time = 1.00
	give_up_time = 1.9
	shard_drop = 4


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_pools.clear()
	var raw_pts: Variant = spec.get("perches", spec.get("route", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				_pools.append(_clamp_pt(_to_vec2(pt_v, home)))
	if _pools.size() < 2:
		var r: float = minf(48.0, leash_radius * 0.40)
		_pools = [_clamp_pt(home + Vector2(-r, -12.0)), _clamp_pt(home + Vector2(r, 12.0))]
	_pool_i = 0
	_arc_from = pos
	_arc_to = pos
	_arc_z = 0.0
	_arc_hit = false
	_stranded = false
	_submerged = false
	_dive_t = 0.0
	_flop_sfx_cd = 0.0


func is_flying() -> bool:
	# Swims freely over water tiles and arcs over gaps!
	return true


func is_targetable() -> bool:
	return is_alive() and not _submerged


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if _submerged:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var mid_air: bool = state == State.COMMIT and _arc_z > 4.0

	if _stranded:
		dmg *= 2.0
	elif mid_air:
		dmg *= AIR_INTERCEPT_MULT

	hp -= dmg
	flash_t = 0.16 if (mid_air or _stranded or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if (mid_air or is_heavy) else 36.0)
	if hp <= 0.001:
		opened_kill = mid_air or _stranded or state == State.RECOVER or state == State.STAGGER
		_die(hit)
		return HitResult.KILLED

	if mid_air or is_heavy:
		_release_token()
		_arc_z = 0.0
		state = State.STAGGER
		state_timer = AIR_STAGGER_S if mid_air else 0.50
		_emit_sfx("mist_eel_flop")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.28
		alert_t = 0.75
	_emit_enemy_hit(hit, HitResult.OPENED if _stranded else HitResult.CHIPPED)
	return HitResult.OPENED if _stranded else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_flop_sfx_cd = maxf(0.0, _flop_sfx_cd - dt)
	var weather: String = _read_weather()
	_stranded = (weather == "sun")
	if _stranded:
		_submerged = false
		_arc_z = absf(sin(anim_t * 11.0)) * 3.0
		if state != State.STAGGER and state != State.RETURN:
			_release_token()
			state = State.STAGGER
			state_timer = 0.40
		if _flop_sfx_cd <= 0.0 and _is_on_screen():
			_flop_sfx_cd = 1.4
			_emit_sfx("mist_eel_flop")
		# Still return home if Wick walks far away
		var wp_s: Vector2 = _get_real_wick_pos()
		if not _has_player() or wp_s.distance_to(home) > leash_radius + 16.0:
			lost_t += dt
			if lost_t >= give_up_time:
				state = State.RETURN
				lost_t = 0.0
		return

	# In RAIN, briefly submerge while repositioning between arcs (never during TELL/COMMIT/RECOVER)
	if weather == "rain" and state in [State.POSITION, State.WAIT_TOKEN]:
		_dive_t += dt
		_submerged = fmod(_dive_t, 2.4) < 0.70
	else:
		_submerged = false
		_dive_t = 0.0

	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			_arc_z = 0.0
			_step_routine(dt)
			if _has_player() and pos.distance_to(target_pos) <= notice_radius:
				state = State.NOTICE
				state_timer = 0.28
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("mist_eel_arc")
		State.NOTICE:
			_arc_z = 0.0
			_face_point(target_pos, 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_arc_z = 0.0
			_step_position(dt, target_pos)
		State.TELL:
			_submerged = false
			_arc_z = 0.0
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.6, dt)
				var to_t: Vector2 = target_pos - pos
				var step_v: Vector2 = to_t.normalized() * minf(ARC_DIST, maxf(44.0, to_t.length() + 14.0)) if to_t.length() > 1.0 else Vector2.from_angle(facing) * 60.0
				_arc_to = _clamp_pt(pos + step_v)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			_arc_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			_arc_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			_submerged = false
			_arc_z = 0.0
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), true)


func _step_routine(dt: float) -> void:
	var wp: Vector2 = _pools[_pool_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.5:
		_pool_i = (_pool_i + 1) % _pools.size()
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.80 * dt), true)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.6, dt)

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

	if is_lead and not _submerged and cooldown <= 0.0 and dist <= ARC_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		var d: Vector2 = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = d.angle()
		_arc_to = _clamp_pt(pos + d * minf(ARC_DIST, maxf(44.0, dist + 14.0)))
		_emit_attack_started()
		_emit_sfx("mist_eel_arc")
		return

	var spd: float = routine_speed * 0.85
	if dist > ARC_RANGE * 0.82:
		_move_step(to_t.normalized() * spd * dt, true)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if (slot % 2 == 0) else -1.0)
		_move_step(perp * spd * 0.72 * dt, true)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = ARC_COMMIT_S
	_arc_from = pos
	_arc_hit = false
	_arc_z = 0.0
	var to_a: Vector2 = _arc_to - _arc_from
	if to_a.length() > 1.0:
		facing = to_a.angle()
	_emit_sfx("mist_eel_arc")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var prog: float = 1.0 - clampf(state_timer / ARC_COMMIT_S, 0.0, 1.0)
	_arc_z = sin(prog * PI) * ARC_HEIGHT
	var desired: Vector2 = _arc_from.lerp(_arc_to, prog)
	# LxFields wind bends the leaping eel mid-air!
	var fa: Vector2 = LxFields.accel_at(pos, "enemy")
	_move_step((desired - pos) + fa * dt * dt * 2.0, true)

	if not _arc_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= ARC_HIT_R:
		_arc_hit = true
		var hit_d: Vector2 = (_arc_to - _arc_from).normalized()
		_emit_player_hit(hit_d)

	if state_timer <= 0.0:
		_arc_z = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer
		_emit_sfx("mist_eel_flop")


func _read_weather() -> String:
	if Lx.vars != null:
		var reg_id: String = str(world_ctx.get("region_id")) if (world_ctx != null and is_instance_valid(world_ctx) and world_ctx.get("region_id") != null) else ""
		var w: String = str(Lx.vars.resolve_var("weather", island_id, reg_id, ""))
		if w.is_empty():
			w = str(Lx.vars.get_var("dungeon:rain_mausoleum", "weather", ""))
		if not w.is_empty():
			return w.to_lower()
	return ""


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _visual_offset() -> Vector2:
	return Vector2(0.0, -_arc_z)


func _body_color() -> Color:
	return (PAL["blue"] if _submerged else PAL["teal"]) as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _submerged:
		var r: float = 7.0 + sin(anim_t * 6.0) * 1.5
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, PAL["sky"] as Color, 1.0)
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 16, PAL["blue"] as Color, 1.0)
	elif _stranded:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 14, PAL["gold"] as Color, 1.0)
	if state == State.TELL:
		var rel: Vector2 = (_arc_to - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var col: Color = (PAL["gold"] if prog > 0.65 else PAL["sky"]) as Color
		draw_line(c, rel, PAL["void"] as Color, 3.0)
		draw_line(c, rel, col, 1.0)
		draw_arc(rel, lerpf(12.0, 6.0, prog), 0.0, TAU, 14, PAL["void"] as Color, 4.0)
		draw_arc(rel, lerpf(12.0, 6.0, prog), 0.0, TAU, 14, PAL["ice"] as Color, 2.0)
		draw_arc(Vector2.ZERO, 6.0 + prog * 8.0, 0.0, TAU, 14, PAL["sky"] as Color, 1.0)
	elif state == State.COMMIT:
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 12, PAL["sky"] as Color, 1.0)
