class_name LxCometHoundBrain
extends LxEnemyBrain
## Comet Hound (Island 5, Starfall Observatory).
## Trots orbital loops near home/gravity wells, then curves its lunge through LxFields
## like a comet slingshot. Baiting its curve into a wall or flipping a well bonk-staggers it!

const NOTICE_TIME: float = 0.24
const LUNGE_COMMIT_TIME: float = 0.34
const LUNGE_SPEED: float = 240.0
const LUNGE_HIT_R: float = 12.5
const BONK_STAGGER_TIME: float = 0.90
const HEAVY_STAGGER_TIME: float = 0.65
const LOOP_RX: float = 34.0
const LOOP_RY: float = 22.0

var _loop_t: float = 0.0
var _loop_sign: float = 1.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_vel: Vector2 = Vector2.ZERO
var _lunge_hit: bool = false
var _curve_pts: PackedVector2Array = PackedVector2Array()
var _bonked: bool = false
var lens_highlight_t: float = 0.0


func _init() -> void:
	kind = "comet_hound"
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 46.0
	leash_radius = 158.0
	notice_radius = 120.0
	tell_time = 0.50
	recover_time = 0.95
	give_up_time = 2.0
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_loop_t = _randf_range(0.0, TAU)
	_loop_sign = -1.0 if float(spec.get("spin", 1.0)) < 0.0 else 1.0
	_lunge_dir = Vector2.from_angle(facing)
	_lunge_vel = Vector2.ZERO
	_lunge_hit = false
	_bonked = false
	_curve_pts = PackedVector2Array()
	lens_highlight_t = 0.0


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if state == State.DEAD:
		return
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = str(source)
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2; rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2: orig = b as Vector2
		elif b is String and src.is_empty(): src = str(b)
	if src == "lens" and rad > 0.0 and (orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius):
		lens_highlight_t = maxf(lens_highlight_t, 0.65)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var is_open: bool = state == State.RECOVER or state == State.STAGGER or state == State.ROUTINE
	if is_open or curve_deg >= 20.0:
		dmg *= 1.25
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (110.0 if is_heavy else 26.0)
	if hp <= 0.001:
		opened_kill = is_open or curve_deg >= 20.0
		_die(hit)
		return HitResult.KILLED
	if is_heavy or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else HEAVY_STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	lens_highlight_t = maxf(0.0, lens_highlight_t - dt)
	match state:
		State.ROUTINE:
			_step_orbit_trot(dt, 0.78)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 6.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			_step_tell(dt)
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			if _lunge_vel.length() > 6.0:
				_move_step(_lunge_vel * dt * 0.25, false)
				_lunge_vel = _lunge_vel.move_toward(Vector2.ZERO, 220.0 * dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.78
				_loop_sign = -_loop_sign
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				_bonked = false
				state = State.POSITION
				cooldown = 0.55
		State.RETURN:
			_step_return(dt)


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	var dist: float = to_t.length()
	if dist > 1.0:
		var rad: Vector2 = to_t / dist
		var tang: Vector2 = rad.rotated(PI * 0.5 * _loop_sign)
		var radial_bias: float = clampf((dist - 74.0) / 48.0, -0.45, 0.55)
		var desire: Vector2 = (tang + rad * radial_bias).normalized()
		# Gently lean with nearby LxFields gravity wells during approach
		var fa: Vector2 = LxFields.accel_at(pos, "enemy")
		if fa.length_squared() > 1.0:
			desire = (desire + fa.normalized() * 0.28).normalized()
		_move_step(desire * (routine_speed * 0.88) * dt, false)
		_turn_toward(to_t.angle(), 5.2, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius and dist >= 22.0 and _claim_token():
		_lunge_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _lunge_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_update_curve_preview()
		_emit_attack_started()
		_emit_sfx("i5_comet_bark")


func _step_tell(dt: float) -> void:
	# Track gently in first half of crouch, then freeze curve so Wick can cut inside!
	if state_timer > last_tell_duration * 0.45:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 1.0:
			_turn_toward(to_t.angle(), 3.2, dt)
			_lunge_dir = Vector2.from_angle(facing)
		_update_curve_preview()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = LUNGE_COMMIT_TIME
		_lunge_vel = _lunge_dir * LUNGE_SPEED
		_lunge_hit = false
		_bonked = false
		_emit_sfx("i5_gravity_bend")


func _step_commit(dt: float) -> void:
	# Bend lunge dynamically through LxFields (gravity wells & polarity flips!)
	var fa: Vector2 = LxFields.accel_at(pos, "enemy")
	if fa.length_squared() > 0.5:
		_lunge_vel += fa * 1.8 * dt
	else:
		# Subtle intrinsic comet-arc sweep when no field is nearby
		_lunge_vel = _lunge_vel.rotated(_loop_sign * 0.72 * dt)
	if _lunge_vel.length_squared() > 1.0:
		_lunge_vel = _lunge_vel.normalized() * LUNGE_SPEED
		_lunge_dir = _lunge_vel.normalized()
		facing = _lunge_dir.angle()

	var step: Vector2 = _lunge_vel * dt
	var before: Vector2 = pos
	_move_step(step, false)
	var moved: float = before.distance_to(pos)

	if not _lunge_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= LUNGE_HIT_R:
		_lunge_hit = true
		_emit_player_hit(_lunge_dir)
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= LUNGE_HIT_R and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())

	# Bonk stagger if curved lunge slams into solid stone wall/pier!
	if step.length() > 0.6 and moved < step.length() * 0.34:
		_bonked = true
		_release_token()
		state = State.STAGGER
		state_timer = BONK_STAGGER_TIME
		knock = -_lunge_dir * 75.0
		_lunge_vel = Vector2.ZERO
		LxDamageFx.boss_impact(pos, 0.08, 42.0, 48.0, 44.0, 1.18, 0.20)
		_emit_sfx("i5_meteor_hit")
		return

	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _step_orbit_trot(dt: float, speed_ratio: float) -> void:
	_loop_t = wrapf(_loop_t + dt * 1.35 * _loop_sign, -PI, PI)
	var target: Vector2 = home + Vector2(cos(_loop_t) * LOOP_RX, sin(_loop_t) * LOOP_RY)
	var d: Vector2 = target - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * speed_ratio * dt), false)
		facing = d.angle()


func _update_curve_preview() -> void:
	var res: Dictionary = LxFields.sample_curve(pos, _lunge_dir, LUNGE_SPEED, "enemy", LUNGE_SPEED * LUNGE_COMMIT_TIME, 7.0, world_ctx)
	var pts: PackedVector2Array = res.get("points", PackedVector2Array()) as PackedVector2Array
	if not bool(res.get("bent", false)):
		# Preview intrinsic comet arc when outside a field
		pts = PackedVector2Array()
		var p: Vector2 = pos
		var d: Vector2 = _lunge_dir
		var dt_s: float = LUNGE_COMMIT_TIME / 8.0
		pts.append(p)
		for _i: int in range(8):
			d = d.rotated(_loop_sign * 0.72 * dt_s)
			p += d * LUNGE_SPEED * dt_s
			pts.append(p)
	_curve_pts = pts


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _has_attention_target() -> bool:
	return _has_player() or _is_lured()


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.72
	lost_t = 0.0
	_emit_sfx("i5_comet_bark")


func _body_color() -> Color:
	return PAL["blue"] as Color


func _draw_extra(off: Vector2) -> void:
	var fred: bool = LxHudFx.flash_reduced()
	# Comet tail star sparks (nice idle & run life)
	var tail_dir: Vector2 = -Vector2.from_angle(facing)
	for i: int in range(2):
		var sp_phase: float = fmod(anim_t * (2.6 if not fred else 1.2) + float(i) * 0.5, 1.0)
		var sp: Vector2 = (off + tail_dir * (body_radius + 3.0 + sp_phase * 8.0) + Vector2(0.0, -3.0 + sin(anim_t * 6.0 + float(i)) * 1.5)).round()
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), (PAL["gold"] if i == 0 else PAL["ice"]) as Color)

	if state == State.TELL and _curve_pts.size() >= 2:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var hot_p: bool = prog > 0.65
		var col: Color = (PAL["coral"] if hot_p else PAL["sky"]) as Color
		var hi: Color = (PAL["cream"] if hot_p else PAL["gold"]) as Color
		for k: int in range(_curve_pts.size() - 1):
			var a: Vector2 = (_curve_pts[k] - pos + off).round()
			var b: Vector2 = (_curve_pts[k + 1] - pos + off).round()
			draw_line(a, b, PAL["void"] as Color, 4.0 if hot_p else 3.0)
			draw_line(a, b, col, 2.0 if hot_p else 1.0)
			if k % 2 == 0:
				draw_rect(Rect2(b, Vector2(1.0, 1.0)), hi)
	elif state == State.COMMIT:
		var c: Vector2 = off.round()
		var back_p: Vector2 = (c - _lunge_dir * 18.0).round()
		draw_line(back_p, c, PAL["void"] as Color, 5.0)
		draw_line(back_p, c, PAL["gold"] as Color, 3.0)
		draw_line(back_p, c, PAL["ice"] as Color, 1.0)
	elif lens_highlight_t > 0.0:
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.0)
