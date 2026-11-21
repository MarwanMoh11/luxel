class_name LxOwlBrain
extends LxEnemyBrain
## Hush Owl Sentinel brain at full Act I parity.
## Perch -> cruise orbit -> sightline lock (0.62s obeying LURE) -> stoop dive (278 px/s) ->
## grounded recover (1.30s). Shares LxAttackDirector token. Targetable in PERCH, DIVE, RECOVER, STAGGER.

const ALT_PERCH: float = 0.0
const ALT_DIVE: float = 6.0
const ALT_HIGH: float = 16.0
const ALT_LOCK: float = 18.0
const ALT_CRUISE: float = 20.0
const ALT_CLIMB_SPEED: float = 48.0

const WAKE_R: float = 122.0
const LURE_WAKE_R: float = 138.0
const DEFAULT_LEASH: float = 180.0
const ORBIT_R: float = 74.0
const ORBIT_SPEED: float = 64.0
const CRUISE_ACCEL: float = 320.0
const CRUISE_CD_MIN: float = 0.85
const CRUISE_CD_MAX: float = 1.35

const LOCK_TIME: float = 0.62
const LOCK_LURE_CUTOFF: float = 0.22
const LOCK_AIM_CUTOFF: float = 0.14
const LOCK_MIN_R: float = 22.0
const LOCK_MAX_R: float = 158.0

const DIVE_SPEED: float = 278.0
const DIVE_OVERSHOOT: float = 40.0
const DIVE_MIN_LEN: float = 64.0
const DIVE_MAX_LEN: float = 200.0
const DIVE_HIT_R: float = 13.0
const DIVE_SLACK: float = 0.22

const RECOVER_DEFAULT: float = 1.30
const RECOVER_DRIFT: float = 68.0
const RECOVER_BRAKE: float = 260.0
const STAGGER_TIME: float = 0.45
const KNOCK_SPEED: float = 120.0

var altitude: float = ALT_PERCH
var vel: Vector2 = Vector2.ZERO
var orbit_center: Vector2 = Vector2.ZERO
var orbit_angle: float = 0.0
var orbit_spin: float = 1.0
var cruise_cd: float = 1.1
var lock_target: Vector2 = Vector2.ZERO
var lock_lured: bool = false
var dive_from: Vector2 = Vector2.ZERO
var dive_to: Vector2 = Vector2.ZERO
var dive_dir: Vector2 = Vector2.RIGHT
var dive_len: float = 114.0
var dive_done: float = 0.0
var dive_hit: bool = false
var dive_snuffed: bool = false


func _init() -> void:
	kind = "owl"
	max_hp = 2.25
	hp = 2.25
	body_radius = 7.0
	routine_speed = 76.0
	leash_radius = DEFAULT_LEASH
	notice_radius = WAKE_R
	tell_time = LOCK_TIME
	recover_time = RECOVER_DEFAULT
	give_up_time = 2.2
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	if spec.has("perch") and not spec.has("home"):
		spec = spec.duplicate()
		spec["home"] = _to_vec2(spec["perch"], home)
	super.setup(spec, p_director, p_world)
	orbit_center = _to_vec2(spec["orbit_center"], home) if spec.has("orbit_center") else home
	orbit_spin = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	vel = Vector2.ZERO
	lock_lured = false
	dive_hit = false
	dive_snuffed = false

	var airborne: bool = bool(spec.get("start_airborne", false)) or bool(spec.get("phase2", false))
	if airborne:
		state = State.POSITION
		altitude = ALT_CRUISE
		cruise_cd = _randf_range(1.0, 1.6)
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.01:
			facing = to_w.angle()
			orbit_angle = (pos - _get_wick_pos()).angle()
	else:
		state = State.ROUTINE
		altitude = ALT_PERCH
		cruise_cd = _randf_range(CRUISE_CD_MIN, CRUISE_CD_MAX)


func is_flying() -> bool:
	return altitude >= ALT_DIVE


func is_targetable() -> bool:
	if not is_alive():
		return false
	# Targetable in PERCH (ROUTINE), DIVE (COMMIT), RECOVER, STAGGER
	return state == State.ROUTINE or state == State.COMMIT \
			or state == State.RECOVER or state == State.STAGGER


func wants_token() -> bool:
	return (state == State.POSITION or state == State.WAIT_TOKEN) and cruise_cd <= 0.0 and altitude >= ALT_HIGH


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2

	if not is_targetable():
		if src == "bolt" or src == "prism_bolt":
			_emit_sfx("owl_pass_under")
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var rel: Vector2 = orig - pos
	hp -= dmg
	flash_t = 0.15 if is_heavy else 0.07
	if rel.length() > 0.01:
		var k_spd: float = KNOCK_SPEED if is_heavy else 24.0
		knock = (-rel.normalized() * k_spd) if is_heavy else (knock - rel.normalized() * k_spd)

	if hp <= 0.001:
		opened_kill = true
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		vel = Vector2.ZERO
		altitude = ALT_PERCH
		state = State.STAGGER
		state_timer = 1.6 if src == "sunflare" else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE:
		_wake_into_cruise(_get_wick_pos(), 1.0)
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	match state:
		State.ROUTINE:
			altitude = move_toward(altitude, ALT_PERCH, ALT_CLIMB_SPEED * dt)
			vel = Vector2.ZERO
			var wake_t: Vector2 = _check_wake()
			if wake_t != Vector2.INF:
				_wake_into_cruise(wake_t, _randf_range(1.1, 1.6))
		State.NOTICE:
			state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_cruise(dt)
		State.TELL:
			_step_lock(dt)
		State.COMMIT:
			_step_dive(dt)
		State.RECOVER:
			_step_recover(dt)
		State.STAGGER:
			altitude = ALT_PERCH
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				_enter_cruise(_randf_range(1.2, 1.8))
		State.RETURN:
			_step_return(dt)


func _step_cruise(dt: float) -> void:
	altitude = move_toward(altitude, ALT_CRUISE, ALT_CLIMB_SPEED * dt)
	cruise_cd = maxf(0.0, cruise_cd - dt)

	var wick_p: Vector2 = _get_wick_pos()
	var lured: bool = _can_lure()
	var target: Vector2 = _get_lantern_pos() if lured else wick_p

	if not lured and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	orbit_angle = wrapf(orbit_angle + orbit_spin * (ORBIT_SPEED / maxf(ORBIT_R, 12.0)) * dt, -PI, PI)
	var anchor: Vector2 = target
	var anchor_cap: float = leash_radius * 0.65
	if anchor.distance_to(orbit_center) > anchor_cap:
		anchor = orbit_center + (anchor - orbit_center).normalized() * anchor_cap

	var desired: Vector2 = anchor + Vector2(cos(orbit_angle) * ORBIT_R, sin(orbit_angle) * ORBIT_R * 0.78)
	var max_cruise: float = minf(routine_speed * 0.92, routine_speed - 2.0)
	var want_vel: Vector2 = ((desired - pos) * 3.0).limit_length(max_cruise)
	vel = vel.move_toward(want_vel, CRUISE_ACCEL * dt)
	_move_step(vel * dt, true)

	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		facing = to_t.angle()

	state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN
	if cruise_cd <= 0.0 and altitude >= ALT_HIGH and dist >= LOCK_MIN_R and dist <= LOCK_MAX_R \
			and _is_on_screen() and _claim_token():
		_enter_lock(target, lured)


func _enter_lock(target: Vector2, lured: bool) -> void:
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
	state_timer = last_tell_duration
	altitude = ALT_LOCK
	vel = Vector2.ZERO
	lock_target = target
	lock_lured = lured
	var to_t: Vector2 = target - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()
	_emit_attack_started()
	_emit_sfx("owl_lure" if lured else "owl_lock")


func _step_lock(dt: float) -> void:
	altitude = move_toward(altitude, ALT_LOCK, ALT_CLIMB_SPEED * dt)
	vel = Vector2.ZERO
	state_timer -= dt

	var scale: float = _assist_tell_scale()
	if state_timer > LOCK_LURE_CUTOFF * scale:
		if _can_lure():
			if not lock_lured:
				lock_lured = true
				_emit_sfx("owl_lure")
			lock_target = _get_lantern_pos()
		elif not lock_lured:
			lock_target = _get_wick_pos()
	elif not lock_lured and state_timer > LOCK_AIM_CUTOFF * scale:
		lock_target = _get_wick_pos()

	var to_t: Vector2 = lock_target - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()

	if state_timer <= 0.0:
		_enter_dive()


func _enter_dive() -> void:
	state = State.COMMIT
	altitude = ALT_DIVE
	dive_from = pos
	var to_t: Vector2 = lock_target - pos
	dive_dir = to_t.normalized() if to_t.length() > 1.0 else Vector2.from_angle(facing)
	dive_len = clampf(to_t.length() + DIVE_OVERSHOOT, DIVE_MIN_LEN, DIVE_MAX_LEN)
	dive_to = dive_from + dive_dir * dive_len
	dive_done = 0.0
	dive_hit = false
	dive_snuffed = false
	facing = dive_dir.angle()
	state_timer = dive_len / maxf(DIVE_SPEED, 60.0) + DIVE_SLACK
	_emit_sfx("owl_dive")


func _step_dive(dt: float) -> void:
	altitude = ALT_DIVE
	state_timer -= dt
	var stride: float = DIVE_SPEED * dt
	var before: Vector2 = pos
	_move_step(dive_dir * stride, true)
	var moved: float = before.distance_to(pos)
	dive_done = maxf(dive_done, (pos - dive_from).dot(dive_dir))

	if not dive_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= DIVE_HIT_R:
		dive_hit = true
		_emit_player_hit(dive_dir)

	if not dive_snuffed and _is_lantern_out():
		var lan_p: Vector2 = _get_lantern_pos()
		if pos.distance_to(lan_p) <= DIVE_HIT_R + 2.0:
			dive_snuffed = true
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lan_p)

	var hit_edge: bool = stride > 0.5 and moved < stride * 0.25
	if dive_done >= dive_len or hit_edge or state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer
		altitude = ALT_PERCH
		vel = dive_dir * RECOVER_DRIFT
		_emit_sfx("owl_recover")


func _step_recover(dt: float) -> void:
	altitude = ALT_PERCH
	vel = vel.move_toward(Vector2.ZERO, RECOVER_BRAKE * dt)
	if vel.length() > 1.0:
		_move_step(vel * dt, false)
	state_timer -= dt
	if state_timer <= 0.0:
		_release_token()
		_enter_cruise(_randf_range(CRUISE_CD_MIN, CRUISE_CD_MAX))


func _step_return(dt: float) -> void:
	var wake_t: Vector2 = _check_wake()
	if wake_t != Vector2.INF and wake_t.distance_to(home) <= notice_radius * 0.85:
		_wake_into_cruise(wake_t, _randf_range(1.1, 1.6))
		return
	var to_h: Vector2 = home - pos
	var dist: float = to_h.length()
	if dist <= 2.5:
		pos = home
		vel = Vector2.ZERO
		altitude = ALT_PERCH
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	var ret_spd: float = minf(routine_speed * 0.92, routine_speed - 2.0)
	vel = to_h.normalized() * ret_spd
	_move_step(vel * dt, true)
	var target_alt: float = lerpf(ALT_PERCH, ALT_CRUISE, clampf(dist / 36.0, 0.0, 1.0))
	altitude = move_toward(altitude, target_alt, ALT_CLIMB_SPEED * dt)


func _enter_cruise(cd: float) -> void:
	state = State.POSITION
	lost_t = 0.0
	cruise_cd = cd
	lock_lured = false
	var target: Vector2 = _get_lantern_pos() if _can_lure() else _get_wick_pos()
	var rel: Vector2 = pos - target
	if rel.length() > 0.01:
		orbit_angle = rel.angle()


func _wake_into_cruise(target: Vector2, cd: float) -> void:
	_enter_cruise(cd)
	altitude = maxf(altitude, 4.0)
	var to_t: Vector2 = target - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()
	_emit_sfx("owl_wake")


func _check_wake() -> Vector2:
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if lp.distance_to(home) <= LURE_WAKE_R:
			return lp
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		if wp.distance_to(home) <= notice_radius:
			return wp
	return Vector2.INF


func _can_lure() -> bool:
	if not _is_lantern_out():
		return false
	var lp: Vector2 = _get_lantern_pos()
	return lp.distance_to(pos) <= 156.0 and lp.distance_to(home) <= leash_radius + 36.0


func _visual_offset() -> Vector2:
	return Vector2(0.0, -altitude)


func _body_color() -> Color:
	return PAL["deep"] as Color


func _draw_extra(off: Vector2) -> void:
	if state == State.TELL:
		var local_target: Vector2 = lock_target - pos
		var col: Color = (PAL["gold"] as Color) if lock_lured else (PAL["ice"] as Color)
		draw_line(off, local_target, col, 1.5)
		draw_circle(local_target, 3.0, col)
	elif state == State.COMMIT:
		draw_line(off, off - dive_dir * 12.0, PAL["sky"] as Color, 2.0)
