class_name LxSatelliteEyeBrain
extends LxEnemyBrain
## Satellite Eye (Island 5, Starfall Observatory).
## Orbiting brass turret with an armored front shield and an exposed glowing coral rear lens.
## Straight front bolts clank; curve shots via LxFields (or Beam/Prism/flank) hit rear lens for 1.4x crit!

const CONE_HALF: float = 0.52
const FRONT_SHELL_HALF: float = 1.05
const REAR_CRIT_MULT: float = 1.40
const NOTICE_TIME: float = 0.24
const COMMIT_TIME: float = 0.28
const SHOT_SPEED: float = 225.0
const SHOT_MAX_AGE: float = 1.15
const SHOT_RADIUS: float = 3.5
const STAGGER_TIME: float = 0.60

var orbit_radius: float = 36.0
var orbit_angle: float = 0.0
var orbit_spin: float = 1.0
var _shot_dir: Vector2 = Vector2.RIGHT
var _shot_fired: bool = false
var _bolts: Array[Dictionary] = []
var _preview_pts: PackedVector2Array = PackedVector2Array()
var lens_pause_t: float = 0.0
var lens_highlight_t: float = 0.0
var lens_pause_cd: float = 0.0


func _init() -> void:
	kind = "satellite_eye"
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 38.0
	leash_radius = 152.0
	notice_radius = 135.0
	tell_time = 0.58
	recover_time = 1.05
	give_up_time = 2.0
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	orbit_radius = clampf(float(spec.get("orbit_radius", 36.0)), 16.0, maxf(24.0, leash_radius * 0.45))
	orbit_angle = _randf_range(-PI, PI)
	orbit_spin = -1.0 if float(spec.get("spin", 1.0)) < 0.0 else 1.0
	_shot_dir = Vector2.from_angle(facing)
	_shot_fired = false
	_bolts.clear()
	_preview_pts = PackedVector2Array()
	lens_pause_t = 0.0
	lens_highlight_t = 0.0
	lens_pause_cd = 0.0


func is_flying() -> bool:
	return state != State.STAGGER


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
		lens_highlight_t = maxf(lens_highlight_t, 0.80)
		if lens_pause_cd <= 0.0:
			lens_pause_t = maxf(lens_pause_t, 0.65)
			lens_pause_cd = 2.0
			_emit_sfx("orrery_lens_pause")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 20.0
	var bypass: bool = is_curved or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_BEAM \
			or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_SUNFLARE \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_SHELL_HALF

	if front_hit and not bypass and _has_active_shield():
		clank_t = 0.14
		if src == LxHit.SOURCE_BOLT:
			_emit_sfx("i5_meteor_hit")
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED
		# Heavy front throw chips lightly without full stagger
		dmg *= 0.45
		is_heavy = false
		_emit_sfx("i5_meteor_hit")
	elif (not front_hit) or is_curved or src == LxHit.SOURCE_RECALL:
		dmg *= REAR_CRIT_MULT

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_open: bool = (not front_hit) or bypass or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (85.0 if is_heavy else 20.0)
	if hp <= 0.001:
		opened_kill = is_open
		_bolts.clear()
		_die(hit)
		return HitResult.KILLED
	if is_heavy or is_curved or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	lens_pause_t = maxf(0.0, lens_pause_t - dt)
	lens_highlight_t = maxf(0.0, lens_highlight_t - dt)
	lens_pause_cd = maxf(0.0, lens_pause_cd - dt)
	_tick_bolts(dt)
	match state:
		State.ROUTINE:
			_step_orbit(dt, 0.85)
			if lens_pause_t <= 0.0:
				facing = wrapf(facing + orbit_spin * 1.35 * dt, -PI, PI)
			if _target_in_range():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 3.2, dt)
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
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.88
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
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

	_step_orbit(dt, 0.92)
	var to_t: Vector2 = _attention_target() - pos
	if lens_pause_t <= 0.0 and to_t.length() > 0.1:
		_turn_toward(to_t.angle(), 2.2, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and _target_in_range() and _claim_token():
		_shot_dir = Vector2.from_angle(facing)
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_update_preview()
		_emit_attack_started()
		_emit_sfx("orrery_bell_tell")


func _step_tell(dt: float) -> void:
	if state_timer > last_tell_duration * 0.42:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1 and lens_pause_t <= 0.0:
			_turn_toward(to_t.angle(), 2.0, dt)
			_shot_dir = Vector2.from_angle(facing)
		_update_preview()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = COMMIT_TIME
		_shot_fired = false
		_emit_sfx("orrery_beam_bolt")


func _step_commit(dt: float) -> void:
	if not _shot_fired:
		_shot_fired = true
		_bolts.append({
			"pos": pos + _shot_dir * (body_radius + 2.0),
			"prev": pos + _shot_dir * (body_radius + 2.0),
			"vel": _shot_dir * SHOT_SPEED,
			"age": 0.0,
		})
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_bolts(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	var lan_out: bool = _is_lantern_out()
	var lp: Vector2 = _get_lantern_pos()
	for i: int in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["age"] = float(b["age"]) + dt
		var bp: Vector2 = b["pos"] as Vector2
		var bv: Vector2 = b["vel"] as Vector2
		b["prev"] = bp
		var fa: Vector2 = LxFields.accel_at(bp, "bolt")
		if fa.length_squared() > 0.01:
			bv += fa * dt
			if bv.length_squared() > 1.0:
				bv = bv.normalized() * SHOT_SPEED
		var nxt: Vector2 = bp + bv * dt
		b["pos"] = nxt
		b["vel"] = bv
		if float(b["age"]) >= SHOT_MAX_AGE or not _has_clear_view(bp, nxt):
			_bolts.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, bp, nxt).distance_to(wp) <= SHOT_RADIUS + 4.0:
			_emit_player_hit(bv.normalized())
			_bolts.remove_at(i)
			continue
		if lan_out and Geometry2D.get_closest_point_to_segment(lp, bp, nxt).distance_to(lp) <= SHOT_RADIUS + 4.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lp)
			_bolts.remove_at(i)


func _step_orbit(dt: float, speed_ratio: float) -> void:
	if lens_pause_t > 0.0:
		return
	var omega: float = (routine_speed * speed_ratio) / maxf(orbit_radius, 12.0)
	orbit_angle = wrapf(orbit_angle + orbit_spin * omega * dt, -PI, PI)
	var tgt: Vector2 = home + Vector2.from_angle(orbit_angle) * orbit_radius
	var step: Vector2 = tgt - pos
	if step.length() > 0.5:
		_move_step(step.limit_length(routine_speed * speed_ratio * dt), true)


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= orbit_radius + 4.0:
		state = State.ROUTINE
		lost_t = 0.0
		return
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)
	if _target_in_range() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()


func _update_preview() -> void:
	var res: Dictionary = LxFields.sample_curve(pos + _shot_dir * (body_radius + 2.0), _shot_dir, SHOT_SPEED, "bolt", 128.0, 8.0, world_ctx)
	_preview_pts = res.get("points", PackedVector2Array()) as PackedVector2Array


func _target_in_range() -> bool:
	if not _has_player() and not _is_lured():
		return false
	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	var d: float = to_t.length()
	if d > notice_radius or d < 0.1:
		return false
	return absf(angle_difference(facing, to_t.angle())) <= CONE_HALF + 0.35 and _has_clear_view(pos, tgt)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


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
	_emit_sfx("orrery_notice")


func _has_active_shield() -> bool:
	return state != State.DEAD and state != State.STAGGER


func _body_color() -> Color:
	return PAL["apricot"] as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Rear coral gem glow indicator
	var back_c: Vector2 = (c - Vector2.from_angle(facing) * (body_radius * 0.85)).round()
	draw_circle(back_c, 2.2, PAL["coral"] as Color)
	draw_rect(Rect2(back_c, Vector2.ONE), PAL["cream"] as Color)
	if lens_highlight_t > 0.0:
		draw_arc(back_c, 5.2, 0.0, TAU, 14, PAL["gold"] as Color, 1.0)
		draw_arc(back_c, 3.0, 0.0, TAU, 10, PAL["ice"] as Color, 1.0)

	# Thin sky laser sightline during TELL (curves cleanly through LxFields!)
	if state == State.TELL and _preview_pts.size() >= 2:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var hot_p: bool = prog > 0.65
		var col: Color = (PAL["coral"] if hot_p else PAL["sky"]) as Color
		for k: int in range(_preview_pts.size() - 1):
			var a: Vector2 = (_preview_pts[k] - pos + off).round()
			var b: Vector2 = (_preview_pts[k + 1] - pos + off).round()
			if hot_p or k % 2 == 0:
				draw_line(a, b, PAL["void"] as Color, 4.0 if hot_p else 3.0)
				draw_line(a, b, col, 2.0 if hot_p else 1.0)

	# Active star-ray bolts
	for b: Dictionary in _bolts:
		var lp: Vector2 = ((b["pos"] as Vector2) - pos + off).round()
		var bv: Vector2 = (b["vel"] as Vector2).normalized()
		draw_line((lp - bv * 7.0).round(), lp, PAL["void"] as Color, 5.0)
		draw_line((lp - bv * 7.0).round(), lp, PAL["blue"] as Color, 3.0)
		draw_line((lp - bv * 5.0).round(), lp, PAL["sky"] as Color, 2.0)
		draw_circle(lp, 2.2, PAL["cream"] as Color)
