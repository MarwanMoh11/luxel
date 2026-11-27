class_name LxNullMothBrain
extends LxEnemyBrain
## Null Moth (Island 5, Starfall Observatory).
## Projects a 22px event-horizon void halo that EATS straight bolts (HitResult.BLOCKED).
## Curved gravity bolts (curve_angle_deg >= 25 deg), Prism, Beam, Throw/Recall, or hitting
## during Recover (when its halo drops!) shatter the cloak and stagger it for 0.80 s!

const HALO_RADIUS: float = 22.0
const CURVE_PIERCE_DEG: float = 20.0
const NOTICE_TIME: float = 0.24
const COMMIT_TIME: float = 0.30
const BOLT_SPEED: float = 210.0
const BOLT_MAX_AGE: float = 1.10
const STAGGER_TIME: float = 0.80

var _loop_t: float = 0.0
var _shot_dir: Vector2 = Vector2.RIGHT
var _shot_fired: bool = false
var _bolts: Array[Dictionary] = []
var _preview_pts: PackedVector2Array = PackedVector2Array()
var _halo_broken_t: float = 0.0
var _eat_flash_t: float = 0.0
var lens_highlight_t: float = 0.0


func _init() -> void:
	kind = "null_moth"
	max_hp = 2.2
	hp = 2.2
	body_radius = 5.5
	routine_speed = 48.0
	leash_radius = 158.0
	notice_radius = 124.0
	tell_time = 0.48
	recover_time = 0.95
	give_up_time = 2.0
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_loop_t = _randf_range(-PI, PI)
	_shot_dir = Vector2.from_angle(facing)
	_shot_fired = false
	_bolts.clear()
	_preview_pts = PackedVector2Array()
	_halo_broken_t = 0.0
	_eat_flash_t = 0.0
	lens_highlight_t = 0.0


func is_flying() -> bool:
	return state != State.RECOVER and state != State.STAGGER


func _has_void_halo() -> bool:
	return state != State.DEAD and state != State.RECOVER and state != State.STAGGER and _halo_broken_t <= 0.0


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
	if src == "lens" and rad > 0.0 and (orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius + 14.0):
		lens_highlight_t = maxf(lens_highlight_t, 0.85)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= CURVE_PIERCE_DEG

	# Void halo swallows straight plain bolts!
	if _has_void_halo() and src == LxHit.SOURCE_BOLT and not is_curved and not bool(h["pierce"]):
		_eat_flash_t = 0.24
		clank_t = 0.14
		_emit_sfx("i5_null_moth_eat")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var shatters_cloak: bool = _has_void_halo() and (is_curved or src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE])
	if is_curved or src == LxHit.SOURCE_PRISM:
		dmg *= 1.40

	var is_open: bool = shatters_cloak or not _has_void_halo()
	hp -= dmg
	flash_t = 0.14 if (is_heavy or shatters_cloak) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (110.0 if (is_heavy or shatters_cloak) else 26.0)

	if hp <= 0.001:
		opened_kill = is_open
		_bolts.clear()
		_die(hit)
		return HitResult.KILLED

	if shatters_cloak or is_heavy or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_halo_broken_t = 3.0
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		LxDamageFx.boss_impact(pos, 0.08, 44.0, 50.0, 46.0, 1.20, 0.22)
		_emit_sfx("hush_veil_shatter")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_halo_broken_t = maxf(0.0, _halo_broken_t - dt)
	_eat_flash_t = maxf(0.0, _eat_flash_t - dt)
	lens_highlight_t = maxf(0.0, lens_highlight_t - dt)
	_tick_bolts(dt)
	match state:
		State.ROUTINE:
			_step_sentry_figure(dt, 0.74)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 5.0, dt)
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
				cooldown = 0.82
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

	_step_sentry_figure(dt, 0.80)
	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	if to_t.length() > 0.1:
		_turn_toward(to_t.angle(), 4.2, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and to_t.length() <= notice_radius and _claim_token():
		_shot_dir = to_t.normalized() if to_t.length() > 0.1 else Vector2.from_angle(facing)
		facing = _shot_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_update_preview()
		_emit_attack_started()
		_emit_sfx("echo_moth_tell")


func _step_tell(dt: float) -> void:
	if state_timer > last_tell_duration * 0.45:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 3.0, dt)
			_shot_dir = Vector2.from_angle(facing)
		_update_preview()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = COMMIT_TIME
		_shot_fired = false
		_emit_sfx("echo_moth_bolt")


func _step_commit(dt: float) -> void:
	if not _shot_fired:
		_shot_fired = true
		_bolts.append({
			"pos": pos + _shot_dir * (body_radius + 2.0),
			"prev": pos + _shot_dir * (body_radius + 2.0),
			"vel": _shot_dir * BOLT_SPEED,
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
				bv = bv.normalized() * BOLT_SPEED
		var nxt: Vector2 = bp + bv * dt
		b["pos"] = nxt; b["vel"] = bv
		if float(b["age"]) >= BOLT_MAX_AGE or not _has_clear_view(bp, nxt):
			_bolts.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, bp, nxt).distance_to(wp) <= 7.0:
			_emit_player_hit(bv.normalized())
			_bolts.remove_at(i)


func _step_sentry_figure(dt: float, speed_ratio: float) -> void:
	_loop_t = wrapf(_loop_t + dt * 1.25, -PI, PI)
	var tgt: Vector2 = home + Vector2(cos(_loop_t) * 32.0, sin(_loop_t * 2.0) * 18.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * speed_ratio * dt), true)
		if state == State.ROUTINE:
			facing = d.angle()


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home; state = State.ROUTINE; lost_t = 0.0; return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _update_preview() -> void:
	var res: Dictionary = LxFields.sample_curve(pos + _shot_dir * (body_radius + 2.0), _shot_dir, BOLT_SPEED, "bolt", 116.0, 8.0, world_ctx)
	_preview_pts = res.get("points", PackedVector2Array()) as PackedVector2Array


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 22.0


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
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("echo_moth_notice")


func _has_active_shield() -> bool:
	return _has_void_halo()


func _shield_color() -> Color:
	return PAL["plum"] as Color


func _body_color() -> Color:
	return PAL["night"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = LxHudFx.flash_reduced()
	# 22px event-horizon void halo ring while active!
	if _has_void_halo():
		var hr: float = HALO_RADIUS * (0.85 if _eat_flash_t > 0.0 else 1.0)
		var ring_c: Color = (PAL["ice"] if _eat_flash_t > 0.0 else PAL["dusk"]) as Color
		draw_arc(c, hr, 0.0, TAU, 24, Color(ring_c, 0.72), 1.0)
		var spin: float = anim_t * (0.9 if fred else 2.2)
		for k: int in range(6):
			var a: float = spin + float(k) * (TAU / 6.0)
			var mp: Vector2 = (c + Vector2.from_angle(a) * hr).round()
			draw_rect(Rect2(mp, Vector2(2.0, 2.0)), (PAL["ice"] if k % 2 == 0 else PAL["plum"]) as Color)

	if lens_highlight_t > 0.0:
		# Highlight curved-approach arc when True Lens pulses!
		draw_arc(c, HALO_RADIUS + 4.0, facing + 0.9, facing + TAU - 0.9, 18, PAL["gold"] as Color, 1.0)

	if state == State.TELL and _preview_pts.size() >= 2:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var hot_p: bool = prog > 0.65
		var lc: Color = (PAL["coral"] if hot_p else PAL["ice"]) as Color
		for k: int in range(_preview_pts.size() - 1):
			var a: Vector2 = (_preview_pts[k] - pos + off).round()
			var b: Vector2 = (_preview_pts[k + 1] - pos + off).round()
			if hot_p or k % 2 == 0:
				draw_line(a, b, lc, 2.0 if hot_p else 1.0)

	for b: Dictionary in _bolts:
		var lp: Vector2 = ((b["pos"] as Vector2) - pos + off).round()
		draw_circle(lp, 3.2, PAL["void"] as Color)
		draw_arc(lp, 3.4, 0.0, TAU, 10, PAL["ice"] as Color, 1.0)
		draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
