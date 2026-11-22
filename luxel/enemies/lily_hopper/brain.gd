class_name LxLilyHopperBrain
extends LxEnemyBrain
## Lily Hopper (Island 4): hops pad to pad; crouches 0.50s tell, performs a committed
## leap, lands with an expanding shockwave ring (source="shockwave", avoided by Wings
## glide), and recovers 1.15s on landing.

enum CommitStage { LEAP, RING }

const PAD_PAUSE_MIN: float = 0.85
const PAD_PAUSE_MAX: float = 1.45
const LEAP_RANGE: float = 110.0
const LEAP_DURATION: float = 0.36
const LEAP_HEIGHT: float = 19.0
const RING_DURATION: float = 0.30
const RING_START_R: float = 6.0
const RING_MAX_R: float = 56.0
const RING_BAND: float = 8.5
const STOMP_R: float = 12.0
const POST_COOLDOWN: float = 1.05

var pads: Array[Vector2] = []
var pad_i: int = 0
var hop_pause_t: float = 0.8
var hop_z: float = 0.0
var commit_stage: int = CommitStage.LEAP
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var ring_progress: float = 0.0
var ring_hit: bool = false


func _init() -> void:
	kind = "lily_hopper"
	island_id = 4
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 42.0
	leash_radius = 156.0
	notice_radius = 128.0
	tell_time = 0.50
	recover_time = 1.15
	give_up_time = 1.8
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	pads.clear()
	var raw_pts: Variant = spec.get("perches", spec.get("route", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				pads.append(_clamp_pt(_to_vec2(pt_v, home)))
	if pads.size() < 2:
		var r: float = minf(48.0, leash_radius * 0.45)
		pads = [_clamp_pt(home + Vector2(-r, -16.0)), _clamp_pt(home + Vector2(r, -16.0)), _clamp_pt(home + Vector2(0.0, r * 0.6))]
	pad_i = 0
	hop_pause_t = _randf_range(PAD_PAUSE_MIN, PAD_PAUSE_MAX)
	hop_z = 0.0
	commit_stage = CommitStage.LEAP
	leap_from = pos
	leap_to = pos
	ring_progress = 0.0
	ring_hit = false


func is_flying() -> bool:
	return state == State.COMMIT and commit_stage == CommitStage.LEAP and hop_z > 5.0


func _step_brain(dt: float) -> void:
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target_pos):
				hop_z = 0.0
				state = State.NOTICE
				state_timer = 0.30
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("hopper_notice")
		State.NOTICE:
			hop_z = 0.0
			_face_point(target_pos, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			hop_z = 0.0
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.2, dt)
				leap_to = _clamp_pt(target_pos)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			hop_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			hop_z = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				hop_z = 0.0
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				hop_z = absf(sin(anim_t * 10.0)) * 5.0
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	if hop_pause_t > 0.0:
		hop_pause_t -= dt
		hop_z = 0.0
		return
	var wp: Vector2 = pads[pad_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		pad_i = (pad_i + 1) % pads.size()
		hop_pause_t = _randf_range(PAD_PAUSE_MIN, PAD_PAUSE_MAX)
		hop_z = 0.0
		return
	facing = to_w.angle()
	hop_z = absf(sin(anim_t * 11.0)) * 6.0
	_move_step(to_w.limit_length(routine_speed * 0.85 * dt), false)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.2, dt)

	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
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

	if is_lead and cooldown <= 0.0 and dist <= LEAP_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		leap_to = _clamp_pt(target_pos)
		hop_z = 0.0
		_emit_attack_started()
		_emit_sfx("hopper_crouch")
		return

	hop_z = absf(sin(anim_t * 9.0)) * 4.0
	var spd: float = minf(routine_speed * 0.84, routine_speed - 2.0)
	if dist > LEAP_RANGE * 0.78:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if (slot % 2 == 0) else -1.0)
		_move_step(perp * spd * 0.65 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	commit_stage = CommitStage.LEAP
	state_timer = LEAP_DURATION
	leap_from = pos
	ring_progress = 0.0
	ring_hit = false
	var to_l: Vector2 = leap_to - leap_from
	if to_l.length() > 1.0:
		facing = to_l.angle()
	_emit_sfx("hopper_leap")


func _step_commit(dt: float) -> void:
	if commit_stage == CommitStage.LEAP:
		state_timer = maxf(0.0, state_timer - dt)
		var prog: float = 1.0 - clampf(state_timer / LEAP_DURATION, 0.0, 1.0)
		hop_z = sin(prog * PI) * LEAP_HEIGHT
		var desired: Vector2 = leap_from.lerp(leap_to, prog)
		_move_step(desired - pos, true)
		if state_timer <= 0.0:
			hop_z = 0.0
			commit_stage = CommitStage.RING
			state_timer = RING_DURATION
			ring_progress = 0.0
			ring_hit = false
			if Lx.events != null:
				Lx.events.shake_requested.emit(0.14)
			_emit_sfx("hopper_land")
			if _has_player() and pos.distance_to(_get_wick_pos()) <= STOMP_R:
				ring_hit = true
				var push: Vector2 = (_get_wick_pos() - pos).normalized()
				_emit_shockwave_hit(push)
		return

	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / RING_DURATION, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _emit_shockwave_hit(hit_dir: Vector2) -> void:
	var saved_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(hit_dir)
	kind = saved_kind


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 1.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _visual_offset() -> Vector2:
	if state == State.TELL:
		return Vector2(0.0, 2.0)
	return Vector2(0.0, -hop_z)


func _body_color() -> Color:
	return PAL["jade"] as Color


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Lily-pad leaf crown + rose blossom silhouette.
		var leaf_r: float = body_radius + (2.0 if state == State.TELL else 0.5)
		draw_arc(off + Vector2(0.0, -body_radius + 1.0), leaf_r * 0.75, 0.2, TAU - 0.2, 12, PAL["lime"] as Color, 2.0)
		draw_circle(off + Vector2(2.0, -body_radius - 1.0), 2.0, PAL["rose"] as Color)
	if state == State.TELL:
		var rel: Vector2 = leap_to - pos
		draw_arc(rel, 7.0, 0.0, TAU, 14, PAL["sky"] as Color, 1.5)
		draw_line(off, rel, PAL["ice"] as Color, 1.0)
	elif state == State.COMMIT and commit_stage == CommitStage.RING:
		var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, PAL["sky"] as Color, 3.0)
		draw_arc(Vector2.ZERO, maxf(2.0, ring_r - 2.5), 0.0, TAU, 24, PAL["cream"] as Color, 1.2)
