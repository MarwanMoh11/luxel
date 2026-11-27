class_name LxReflectionBrain
extends LxEnemyBrain
## Island 7 Enemy: Reflection (Mirrored Trickster, HP 3.5, Shards 6).
## Mirrors Wick's lateral strafe on an optical silver floor line and echoes a delayed
## silver bolt (240 px/s, LxFields-bent) 0.46s after locking axis.
## Counters: sidestep after firing, Throw lures off-axis, Blue/Beam/Sunflare breaks tether.

const NOTICE_TIME: float = 0.24
const BOLT_TELL: float = 0.46
const BOLT_COMMIT: float = 0.18
const BOLT_RECOVER: float = 1.15
const BOLT_SPEED: float = 240.0
const BOLT_MAX_AGE: float = 1.15
const TETHER_STAGGER: float = 1.35

var _glide_t: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _bolt_fired: bool = false
var _tether_broken_t: float = 0.0
var _last_wick_pos: Vector2 = Vector2.ZERO
var _bolts: Array[Dictionary] = []


func _init() -> void:
	kind = "reflection"
	island_id = 7
	max_hp = 3.5
	hp = 3.5
	body_radius = 6.0
	routine_speed = 42.0
	leash_radius = 156.0
	notice_radius = 135.0
	tell_time = BOLT_TELL
	recover_time = BOLT_RECOVER
	give_up_time = 2.1
	shard_drop = 6
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_glide_t = _randf_range(-PI, PI)
	_aim_dir = Vector2.from_angle(facing)
	_bolt_fired = false
	_tether_broken_t = 0.0
	_last_wick_pos = home
	_bolts.clear()


func _is_black_world() -> bool:
	if Lx.vars == null:
		return false
	var reg_id: String = Lx.state.region_id if Lx.state != null else ""
	if reg_id.is_empty() and Lx.world != null:
		reg_id = str(Lx.world.get("current_region_id"))
	return Lx.vars.eval("world_face==black", island_id, reg_id)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue: bool = hit.is_blue()
	var is_heavy: bool = bool(h["stagger"]) or src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH]
	var breaks_tether: bool = is_blue or src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["cracks_armour"])

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	if _is_black_world():
		dmg *= 1.25
	if breaks_tether:
		dmg *= 1.35

	var is_open: bool = breaks_tether or _tether_broken_t > 0.0 or state in [State.RECOVER, State.STAGGER, State.ROUTINE]
	hp -= dmg
	flash_t = 0.14 if (breaks_tether or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 30.0)

	if hp <= 0.001:
		opened_kill = is_open
		_bolts.clear()
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if breaks_tether or is_heavy:
		_release_token()
		_tether_broken_t = 3.2 if breaks_tether else 1.5
		state = State.STAGGER
		state_timer = TETHER_STAGGER if breaks_tether else 0.55
		_emit_sfx("glass_shatter" if breaks_tether else "heavy_hit")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_tether_broken_t = maxf(0.0, _tether_broken_t - dt)
	_tick_bolts(dt)

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 5.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_last_wick_pos = _attention_target()
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
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	_glide_t = wrapf(_glide_t + dt * 1.1, -PI, PI)
	var tgt: Vector2 = home + Vector2(cos(_glide_t) * 28.0, sin(_glide_t) * 14.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * 0.72 * dt), false)
		_turn_toward(d.angle(), 3.6, dt)


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
	if dist > 0.1:
		_turn_toward(to_t.angle(), 4.5, dt)
		var dir_t: Vector2 = to_t / dist
		var perp := Vector2(-dir_t.y, dir_t.x)
		# Mirror Wick's lateral velocity across the optical axis (capped <= 0.88 * routine_speed for no-pursuit)
		var w_vel: Vector2 = (tgt - _last_wick_pos) / maxf(dt, 0.001)
		var lat_proj: float = clampf(-w_vel.dot(perp) / 80.0, -1.0, 1.0)
		var radial: float = clampf((dist - 76.0) / 48.0, -0.45, 0.45)
		var desire: Vector2 = (perp * (lat_proj if absf(lat_proj) > 0.15 else sin(anim_t * 2.1) * 0.55) + dir_t * radial)
		if desire.length_squared() > 0.01:
			_move_step(desire.normalized() * (routine_speed * 0.86) * dt, false)
	_last_wick_pos = tgt

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius and _has_clear_view(pos, tgt):
		if _claim_token():
			_aim_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(BOLT_TELL, false, attack_damage)
			state_timer = last_tell_duration
			_bolt_fired = false
			_emit_attack_started()
			_emit_sfx("clockwork_chime")


func _step_tell(dt: float) -> void:
	# Tracks lightly early, locks optical axis in final 0.18s so sidestepping dodges cleanly
	if state_timer > 0.18 * _assist_tell_scale() and _has_attention_target():
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 3.0, dt)
			_aim_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = BOLT_COMMIT
		_bolt_fired = false


func _step_commit(dt: float) -> void:
	if not _bolt_fired:
		_bolt_fired = true
		_emit_sfx("orrery_bolt")
		var d: Vector2 = _aim_dir.normalized() if _aim_dir.length_squared() > 0.01 else Vector2.from_angle(facing)
		_bolts.append({
			"pos": pos + d * (body_radius + 3.0),
			"prev": pos + d * (body_radius + 3.0),
			"vel": d * BOLT_SPEED,
			"age": 0.0,
		})
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, BOLT_RECOVER)
		last_recover_duration = state_timer


func _tick_bolts(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["age"] = float(b["age"]) + dt
		var p0: Vector2 = b["pos"] as Vector2
		var v: Vector2 = b["vel"] as Vector2
		b["prev"] = p0
		var fa: Vector2 = LxFields.accel_at(p0, "bolt")
		if fa.length_squared() > 0.01:
			v += fa * dt
			if v.length_squared() > 1.0:
				v = v.normalized() * BOLT_SPEED
		var p1: Vector2 = p0 + v * dt
		b["pos"] = p1
		b["vel"] = v
		if float(b["age"]) >= BOLT_MAX_AGE or not _has_clear_view(p0, p1):
			_bolts.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, p0, p1).distance_to(wp) <= 6.5:
			_emit_player_hit(v.normalized())
			_bolts.remove_at(i)


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 4.0, dt)
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


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
	_emit_sfx("mirror_ping")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.07, 42.0, 48.0, 44.0, 1.24, 0.24)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["ice"] if si % 2 == 0 else PAL["sky"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 32.0, 78.0, 0.28)


func _visual_offset() -> Vector2:
	return Vector2(0.0, sin(anim_t * 3.4) * 1.8 - 2.0)


func _body_color() -> Color:
	return PAL["sky"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Optical silver mirror line connecting Reflection to its locked target
	if state in [State.POSITION, State.WAIT_TOKEN, State.TELL] and _tether_broken_t <= 0.0 and _has_attention_target():
		var rel: Vector2 = _attention_target() - pos
		if rel.length() <= notice_radius + 24.0:
			var line_col: Color = (PAL["rose"] if _is_black_world() else PAL["ice"]) as Color
			draw_line(Vector2.ZERO, rel.round(), Color(line_col, 0.22), 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, _aim_dir * 130.0, 6.0, prog, anim_t, "sky", "cream")
	for b: Dictionary in _bolts:
		var lp: Vector2 = ((b["pos"] as Vector2) - pos + c).round()
		var v: Vector2 = (b["vel"] as Vector2).normalized()
		draw_line((lp - v * 6.0).round(), lp, PAL["void"] as Color, 4.0)
		draw_line((lp - v * 6.0).round(), lp, PAL["blue"] as Color, 2.0)
		draw_circle(lp, 2.2, PAL["ice"] as Color)
		draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
