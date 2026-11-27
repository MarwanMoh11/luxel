class_name LxPistolShrimpBrain
extends LxEnemyBrain
## Pistol Shrimp (Island 2 — Recoil Sniper):
## Snaps oversized golden claw firing a 210 px/s cavitation shock-bolt (bends with LxFields);
## recoil kicks the Shrimp 22px backward (bait near pits/water!).
## Counterplay: Dash easy Perfect Dodge, Throw knocks off ledges, Blue/Prism cracks claw
## (1.5x dmg + 0.7s stun), Skiff drifts sideways.

const FIRE_RANGE: float = 148.0
const SHOT_SPEED: float = 210.0
const SHOT_MAX_DIST: float = 168.0
const SHOT_RADIUS: float = 4.0
const RECOIL_DIST: float = 22.0
const COMMIT_TIME: float = 0.18
const POST_COOLDOWN: float = 1.10

var _patrol_sign: float = 1.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _shots: Array[Dictionary] = []
var _claw_cracked_t: float = 0.0


func _init() -> void:
	kind = "pistol_shrimp"
	island_id = 2
	max_hp = 3.0
	hp = 3.0
	body_radius = 5.5
	routine_speed = 34.0
	leash_radius = 154.0
	notice_radius = 148.0
	tell_time = 0.64
	recover_time = 1.25
	give_up_time = 2.0
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_patrol_sign = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	_aim_dir = Vector2.from_angle(facing)
	_shots.clear()
	_claw_cracked_t = 0.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue: bool = hit.is_blue()
	var is_heavy: bool = bool(h["stagger"]) or hit.is_heavy()
	if is_blue:
		dmg *= 1.5
		_claw_cracked_t = 3.0
	hp -= dmg
	flash_t = 0.14 if (is_blue or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (145.0 if is_heavy else 62.0)
	if hp <= 0.001:
		opened_kill = is_blue or is_heavy or state == State.RECOVER or state == State.STAGGER
		_shots.clear()
		_die(hit)
		return HitResult.KILLED
	if is_blue:
		_release_token()
		state = State.STAGGER
		state_timer = 0.70
		_emit_sfx("barnacle_shell_crack")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.45
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_claw_cracked_t = maxf(0.0, _claw_cracked_t - dt)
	_step_shots(dt)
	# If recoil or knockback pushed Shrimp into lethal pit/water, it falls in!
	if _is_in_lethal_hazard():
		opened_kill = true
		_shots.clear()
		_die(null)
		return

	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			_face_point(target, 4.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_snipe(dt, target)
		State.TELL:
			if state_timer > 0.22 * _assist_tell_scale():
				_face_point(target, 3.6, dt)
				_aim_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
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
			if to_h.length() <= 3.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_turn_toward(to_h.angle(), 4.2, dt)
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	var goal: Vector2 = home + Vector2(_patrol_sign * 20.0, sin(anim_t * 1.4) * 6.0)
	var d: Vector2 = goal - pos
	if d.length() <= 3.0:
		_patrol_sign = -_patrol_sign
	else:
		_turn_toward(d.angle(), 3.6, dt)
		_move_step(d.limit_length(routine_speed * 0.65 * dt), false)


func _step_snipe(dt: float, target: Vector2) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 14.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 4.4, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	var ang_ok: bool = dist < 0.01 or absf(angle_difference(facing, to_t.angle())) < 0.45
	if can_act and cooldown <= 0.0 and dist <= FIRE_RANGE and ang_ok and _is_on_screen() \
			and _has_clear_view(pos, target) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_aim_dir = Vector2.from_angle(facing)
		_emit_attack_started()
		_emit_sfx("shrimp_charge")
		return

	# Keep sniper spacing (~92px) without chasing
	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var radial: float = clampf((dist - 92.0) / 38.0, -0.70, 0.45)
	if absf(radial) > 0.12:
		_move_step(fwd * (routine_speed * 0.78 * radial) * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_aim_dir = Vector2.from_angle(facing)
	_shots.append({
		"pos": pos + _aim_dir * (body_radius + 3.0),
		"vel": _aim_dir * SHOT_SPEED,
		"traveled": 0.0,
	})
	# Signature recoil: kicks Shrimp 22px backward! (v0 = 162 px/s -> 162^2 / (2*600) = ~22px via knock!)
	knock = -_aim_dir * 162.0
	LxDamageFx.boss_impact(pos + _aim_dir * (body_radius + 4.0), 0.06, 34.0, 42.0, 38.0, 1.18, 0.18, "gold")
	_emit_sfx("shrimp_snap")


func _step_shots(dt: float) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	for i: int in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		var prev_p: Vector2 = s["pos"] as Vector2
		var vel: Vector2 = s["vel"] as Vector2
		var fa: Vector2 = LxFields.accel_at(prev_p, "bolt")
		if fa.length_squared() > 0.01:
			vel = (vel + fa * dt).limit_length(SHOT_SPEED * 1.4)
			s["vel"] = vel
		var step: Vector2 = vel * dt
		var nxt_p: Vector2 = prev_p + step
		s["pos"] = nxt_p
		s["traveled"] = float(s["traveled"]) + step.length()
		var remove_it: bool = float(s["traveled"]) >= SHOT_MAX_DIST or not _has_clear_view(prev_p, nxt_p)
		if not remove_it and _has_player() and Geometry2D.get_closest_point_to_segment(wick_p, prev_p, nxt_p).distance_to(wick_p) <= SHOT_RADIUS + 4.5:
			_emit_player_hit(vel.normalized())
			remove_it = true
		elif not remove_it and lan_out and nxt_p.distance_to(lan_p) <= SHOT_RADIUS + 5.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lan_p)
			remove_it = true
		if remove_it:
			_shots.remove_at(i)


func _is_in_lethal_hazard() -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return false
	if world_ctx.has_method("tile_at"):
		var t: String = str(world_ctx.call("tile_at", pos))
		if t == "pit" or t == "void":
			return true
	return false


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.30
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("shrimp_charge")


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 18.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target: Vector2) -> bool:
	if not _has_player() and not _is_lured():
		return false
	return pos.distance_to(target) <= notice_radius and _has_clear_view(pos, target)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length_squared() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _body_color() -> Color:
	return PAL["coral"] as Color


func _draw_extra(off: Vector2) -> void:
	var fwd: Vector2 = Vector2.from_angle(facing)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked_t: bool = state_timer <= 0.22 * _assist_tell_scale()
		var col: Color = (PAL["coral"] as Color) if locked_t else ((PAL["gold"] as Color) if prog > 0.5 else (PAL["ice"] as Color))
		var s_a: Vector2 = (off + fwd * 6.0).round()
		var s_b: Vector2 = (off + fwd * 124.0).round()
		draw_line(s_a, s_b, PAL["void"] as Color, 4.0 if locked_t else 3.0)
		draw_line(s_a, s_b, col, 2.0 if locked_t else 1.0)
		var br: float = lerpf(11.0, 2.5, prog)
		var bc: Vector2 = (off + fwd * (body_radius + 4.0)).round()
		draw_arc(bc, br, 0.0, TAU, 14, PAL["void"] as Color, 3.0)
		draw_arc(bc, br, 0.0, TAU, 14, col, 1.0)
	for s: Dictionary in _shots:
		var sp: Vector2 = ((s["pos"] as Vector2) - pos + off).round()
		var sd: Vector2 = (s["vel"] as Vector2).normalized()
		draw_line((sp - sd * 10.0).round(), sp, PAL["void"] as Color, 4.0)
		draw_line((sp - sd * 10.0).round(), sp, PAL["coral"] as Color, 2.0)
		draw_line((sp - sd * 7.0).round(), sp, PAL["gold"] as Color, 1.0)
		draw_circle(sp, 2.2, PAL["cream"] as Color)
