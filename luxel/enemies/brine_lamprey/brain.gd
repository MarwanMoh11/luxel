class_name LxBrineLampreyBrain
extends LxEnemyBrain
## Brine Lamprey (Island 2 — Aquatic Stalker / Skiff Leech):
## Swims under water/tide as a visible sky/rose ripple. Boils coral on TELL (0.50s),
## leaps 48px onto pier OR latches onto mounted Skiff (halving Skiff thrust until Dash/Zip
## shakes it off stunned!), then flops in 1.05s RECOVER.
## Counterplay: Bolt hits flop/latch, Dash shakes off stunned, Throw blasts ripple, Blue sweeps water (1.4x).

const LEAP_RANGE: float = 64.0
const LEAP_SPEED: float = 140.0
const COMMIT_TIME: float = 0.34
const NOTICE_TIME: float = 0.28
const POST_COOLDOWN: float = 0.95

var _patrol_phase: float = 0.0
var _leap_dir: Vector2 = Vector2.RIGHT
var _leap_hit: bool = false
var _latched_skiff: LxVehicleSkiff = null
var _latch_t: float = 0.0
var _altitude: float = 0.0


func _init() -> void:
	kind = "brine_lamprey"
	island_id = 2
	max_hp = 2.0
	hp = 2.0
	body_radius = 5.0
	routine_speed = 46.0
	leash_radius = 156.0
	notice_radius = 132.0
	tell_time = 0.50
	recover_time = 1.05
	give_up_time = 2.0
	shard_drop = 2
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_patrol_phase = _randf_range(0.0, TAU)
	_leap_dir = Vector2.from_angle(facing)
	_leap_hit = false
	_latched_skiff = null
	_latch_t = 0.0
	_altitude = 0.0


func is_flying() -> bool:
	# Swims freely across water/tide tiles and leaps onto piers!
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue: bool = hit.is_blue()
	var is_heavy: bool = bool(h["stagger"]) or hit.is_heavy()
	var is_open: bool = _latched_skiff != null or state == State.RECOVER or state == State.STAGGER or is_blue
	if is_blue:
		dmg *= 1.4
	elif state == State.RECOVER or _latched_skiff != null:
		dmg *= 1.25
	hp -= dmg
	flash_t = 0.14 if (is_open or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if is_heavy else 65.0)
	if _latched_skiff != null:
		_detach_from_skiff(true)
	if hp <= 0.001:
		opened_kill = is_open
		_die(hit)
		return HitResult.KILLED
	if is_heavy or is_blue or is_open:
		_release_token()
		state = State.STAGGER
		state_timer = 0.65
		_emit_sfx("lamprey_shake")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	if _latched_skiff != null:
		_step_latched(dt)
		return

	_altitude = move_toward(_altitude, 0.0, 48.0 * dt)
	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			_face_point(target, 5.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_stalk(dt, target)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target, 4.2, dt)
				_leap_dir = Vector2.from_angle(facing)
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
			if to_h.length() <= 4.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_turn_toward(to_h.angle(), 4.5, dt)
				_move_step(to_h.limit_length(routine_speed * dt), true)


func _step_routine(dt: float) -> void:
	_patrol_phase = wrapf(_patrol_phase + dt * 1.4, -PI, PI)
	var goal: Vector2 = home + Vector2(cos(_patrol_phase) * 24.0, sin(_patrol_phase) * 18.0)
	var step_v: Vector2 = (goal - pos).limit_length(routine_speed * 0.72 * dt)
	if step_v.length() > 0.01:
		_turn_toward(step_v.angle(), 4.2, dt)
		_move_step(step_v, true)


func _step_stalk(dt: float, target: Vector2) -> void:
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
		_turn_toward(to_t.angle(), 4.8, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= LEAP_RANGE and _is_on_screen() and _has_clear_view(pos, target) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_leap_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _leap_dir.angle()
		_emit_attack_started()
		_emit_sfx("lamprey_boil")
		return

	# Sinuous stalking approach (stays strictly <= routine_speed)
	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var weave: Vector2 = Vector2(-fwd.y, fwd.x) * sin(anim_t * 4.5) * 0.55
	var dir: Vector2 = (fwd * 0.80 + weave).normalized()
	var fa: Vector2 = LxFields.accel_at(pos, "enemy")
	var vel: Vector2 = (dir * (routine_speed * 0.85) + fa * 0.06).limit_length(routine_speed * 0.90)
	_move_step(vel * dt, true)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_leap_hit = false
	_leap_dir = Vector2.from_angle(facing)
	_emit_sfx("marsh_splash")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	var u: float = 1.0 - clampf(state_timer / COMMIT_TIME, 0.0, 1.0)
	_altitude = sin(u * PI) * 10.0
	_move_step(_leap_dir * LEAP_SPEED * dt, true)

	if not _leap_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if pos.distance_to(wp) <= body_radius + 7.5:
			_leap_hit = true
			var skiff: LxVehicleSkiff = _find_mounted_skiff()
			if skiff != null:
				_latched_skiff = skiff
				_latch_t = 3.5
				_release_token()
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
				_emit_sfx("lamprey_latch")
				return
			_emit_player_hit(_leap_dir)

	if state_timer <= 0.0:
		_altitude = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _step_latched(dt: float) -> void:
	if _latched_skiff == null or not is_instance_valid(_latched_skiff) or _latched_skiff.rider == null:
		_detach_from_skiff(false)
		return
	_latch_t -= dt
	pos = _latched_skiff.pos - _latched_skiff.heading * 10.0
	position = pos.round()
	# Halve Skiff thrust via continuous drag while latched!
	_latched_skiff.vel *= pow(0.32, dt)
	var rider: LxWick = _latched_skiff.rider
	var shaken: bool = (rider.move_dash != null and rider.move_dash.is_active()) \
		or (rider.move_zip != null and rider.move_zip.is_active()) \
		or _latched_skiff._swing_t > 0.0
	if shaken or _latch_t <= 0.0:
		_detach_from_skiff(shaken)


func _detach_from_skiff(stunned: bool) -> void:
	var old: LxVehicleSkiff = _latched_skiff
	_latched_skiff = null
	_latch_t = 0.0
	if old != null and is_instance_valid(old):
		knock = -old.heading * 95.0
	if stunned:
		state = State.STAGGER
		state_timer = 0.75
		_emit_sfx("lamprey_shake")
	else:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _find_mounted_skiff() -> LxVehicleSkiff:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var v: Variant = w.get("mounted_vehicle")
		if v is LxVehicleSkiff and is_instance_valid(v):
			return v as LxVehicleSkiff
	return null


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("lamprey_boil")


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 16.0


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


func _visual_offset() -> Vector2:
	return Vector2(0.0, -_altitude)


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var rip_r: float = 7.5 + sin(anim_t * 6.0) * 1.4
	draw_arc(Vector2.ZERO, rip_r, 0.0, TAU, 14, PAL["rose" if state == State.TELL else "sky"] as Color, 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, off + _leap_dir * 48.0, 8.5, prog, anim_t, "coral", "gold")
	elif _latched_skiff != null:
		draw_arc(off, body_radius + 3.0, 0.0, TAU, 12, PAL["coral"] as Color, 1.0)
