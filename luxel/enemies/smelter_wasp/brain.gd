class_name LxSmelterWaspBrain
extends LxEnemyBrain
## Smelter Wasp (Island 6, Ashen Kiln — Aerial Harasser / Disrupter).
## Hovering glass-winged furnace wasp orbiting over lava pits (is_flying = true).
## Flares crucible abdomen (0.52s tell, 20px ground ring), dives & drops a molten cinder
## (obeys LxFields), then hovers low & vulnerable (1.15s recover).

const DROP_RANGE: float = 128.0
const DROP_RADIUS: float = 20.0
const COMMIT_TIME: float = 0.26
const STANDOFF_R: float = 74.0

var hover_z: float = 11.0
var drop_target: Vector2 = Vector2.ZERO
var dropped: bool = false
var _cinder_active: bool = false
var _cinder_pos: Vector2 = Vector2.ZERO
var _cinder_vel: Vector2 = Vector2.ZERO
var _cinder_t: float = 0.0
var _fig8_phase: float = 0.0


func _init() -> void:
	kind = "smelter_wasp"
	island_id = 6
	max_hp = 1.75
	hp = 1.75
	body_radius = 5.0
	routine_speed = 52.0
	leash_radius = 158.0
	notice_radius = 140.0
	tell_time = 0.52
	recover_time = 1.15
	give_up_time = 1.8
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	hover_z = 11.0
	drop_target = pos
	dropped = false
	_cinder_active = false
	_fig8_phase = float(slot) * 1.7


func is_flying() -> bool:
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var low_hover: bool = state == State.RECOVER or state == State.STAGGER
	if low_hover:
		dmg *= 1.30
	elif str(h["source"]) == LxHit.SOURCE_BEAM or str(h["source"]) == LxHit.SOURCE_ZIP:
		dmg *= 1.25

	var is_opening: bool = low_hover or is_heavy or str(h["source"]) == LxHit.SOURCE_BEAM
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (130.0 if is_heavy else 45.0)

	if hp <= 0.001:
		_cinder_active = false
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if is_heavy or state == State.TELL:
		_release_token()
		hover_z = 3.0
		state = State.STAGGER
		state_timer = 1.4 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else 0.65
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_fig8_phase += dt * 1.45
	_tick_cinder(dt)
	match state:
		State.ROUTINE:
			hover_z = lerpf(hover_z, 11.0 + sin(_fig8_phase * 2.0) * 2.0, dt * 6.0)
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			hover_z = lerpf(hover_z, 12.0, dt * 6.0)
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 5.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			hover_z = lerpf(hover_z, 11.5 + sin(anim_t * 5.0) * 1.8, dt * 6.0)
			_step_position(dt)
		State.TELL:
			hover_z = lerpf(hover_z, 16.0, dt * 7.0)
			if state_timer > 0.18 * _assist_tell_scale():
				var tgt: Vector2 = _attention_target()
				var to_t: Vector2 = tgt - pos
				if to_t.length() > 0.01:
					_turn_toward(to_t.angle(), 3.4, dt)
				drop_target = tgt
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = COMMIT_TIME
				dropped = false
				_emit_sfx("magma_crack")
		State.COMMIT:
			hover_z = lerpf(hover_z, 7.5, dt * 10.0)
			if not dropped:
				dropped = true
				_launch_cinder()
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
		State.RECOVER:
			hover_z = lerpf(hover_z, 3.5, dt * 8.0)
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			hover_z = lerpf(hover_z, 2.5, dt * 9.0)
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			hover_z = lerpf(hover_z, 11.0, dt * 6.0)
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * 0.88 * dt), true)
				if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
					_enter_notice()


func _step_routine(dt: float) -> void:
	# Smooth figure-8 patrol above home / lava pits
	var goal: Vector2 = home + Vector2(sin(_fig8_phase) * 32.0, sin(_fig8_phase * 2.0) * 14.0)
	var to_g: Vector2 = goal - pos
	if to_g.length() > 1.5:
		_turn_toward(to_g.angle(), 4.2, dt)
		_move_step(to_g.limit_length(routine_speed * 0.78 * dt), true)


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

	var target: Vector2 = _attention_target()
	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 4.4, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= DROP_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		drop_target = target
		_emit_attack_started()
		_emit_sfx("furnace_draw")
		return

	# Orbit without chasing faster than routine_speed
	if dist > 1.0:
		var rad: Vector2 = to_t / dist
		var orb := Vector2(-rad.y, rad.x) * (1.0 if (slot % 2 == 0) else -1.0)
		var r_w: float = clampf((dist - STANDOFF_R) / 42.0, -0.5, 0.45)
		_move_step((orb * 0.78 + rad * r_w).normalized() * (routine_speed * 0.75) * dt, true)


func _launch_cinder() -> void:
	_cinder_active = true
	_cinder_pos = pos
	var dur: float = 0.24
	_cinder_vel = (drop_target - pos) / dur
	_cinder_t = dur


func _tick_cinder(dt: float) -> void:
	if not _cinder_active:
		return
	if LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(_cinder_pos, "bolt")
		if fa.length_squared() > 0.01:
			_cinder_vel += fa * dt * 0.55
	_cinder_pos += _cinder_vel * dt
	_cinder_t -= dt
	if _cinder_t <= 0.0:
		_cinder_active = false
		if _has_player() and _get_wick_pos().distance_to(_cinder_pos) <= DROP_RADIUS:
			var push: Vector2 = (_get_wick_pos() - _cinder_pos).normalized() if _get_wick_pos().distance_to(_cinder_pos) > 0.1 else Vector2.DOWN
			_emit_player_hit(push, attack_damage)


func _sees_target() -> bool:
	var t: Vector2 = _attention_target()
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
	state = State.NOTICE
	state_timer = 0.26
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("owl_lock")


func _visual_offset() -> Vector2:
	return Vector2(0.0, -roundf(hover_z))


func _body_color() -> Color:
	return PAL["apricot"] as Color


func _draw_extra(_off: Vector2) -> void:
	if state == State.TELL or _cinder_active:
		var dp: Vector2 = (drop_target - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0) if state == State.TELL else 1.0
		draw_circle(dp, DROP_RADIUS, Color(PAL["coral"] as Color, 0.16 + 0.14 * prog))
		draw_arc(dp, DROP_RADIUS, 0.0, TAU, 18, PAL["void"] as Color, 4.0)
		draw_arc(dp, DROP_RADIUS, 0.0, TAU, 18, (PAL["cream"] if prog > 0.72 else PAL["gold"]) as Color, 2.0)
		if state == State.TELL:
			draw_arc(dp, lerpf(DROP_RADIUS, 4.0, prog), 0.0, TAU, 14, PAL["void"] as Color, 3.0)
			draw_arc(dp, lerpf(DROP_RADIUS, 4.0, prog), 0.0, TAU, 14, PAL["apricot"] as Color, 1.0)
	if _cinder_active:
		var cp: Vector2 = (_cinder_pos - pos).round()
		var cz: float = clampf(_cinder_t / 0.24, 0.0, 1.0) * 14.0
		draw_circle(cp + Vector2(0.0, -cz), 3.4, PAL["coral"] as Color)
		draw_circle(cp + Vector2(0.0, -cz), 1.8, PAL["cream"] as Color)
