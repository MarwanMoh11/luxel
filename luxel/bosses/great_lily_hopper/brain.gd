class_name LxGreatLilyHopperBoss
extends LxLilyHopperBrain
## Mirefen Gardens mini-boss (Island 4): Great Lily Hopper with twin shockwave hops.
## 2 phases, HP 7.5. Phase 2 chains a second shockwave leap before a generous landing recovery.

const BOSS_RING_MAX_R: float = 70.0
const BOSS_RING_BAND: float = 9.5
const BOSS_LEAP_RANGE: float = 122.0
const TWIN_CROUCH_PAUSE: float = 0.42
const PHASE2_ROAR_TIME: float = 0.56

var twin_hop_pending: bool = false
var twin_pause_active: bool = false
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "great_lily_hopper"
	boss_id = "great_lily_hopper"
	island_id = 4
	is_boss = true
	max_hp = 7.5
	hp = 7.5
	body_radius = 7.5
	routine_speed = 44.0
	leash_radius = 172.0
	notice_radius = 140.0
	tell_time = 0.52
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 15


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "great_lily_hopper"))
	island_id = int(spec.get("island_id", 4))
	twin_hop_pending = false
	twin_pause_active = false
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var res: int = super.take_hit(hit)
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		_roaring = true
		hop_z = 0.0
		twin_hop_pending = false
		twin_pause_active = false
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
			Lx.events.shake_requested.emit(0.24)
		_emit_sfx("great_hopper_phase2")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		hop_z = 0.0
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


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

	if is_lead and cooldown <= 0.0 and dist <= BOSS_LEAP_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		var base_t: float = 0.46 if phase >= 2 else tell_time
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		leap_to = _clamp_pt(target_pos)
		hop_z = 0.0
		twin_hop_pending = phase >= 2
		twin_pause_active = false
		_emit_attack_started()
		_emit_sfx("hopper_crouch")
		return

	hop_z = absf(sin(anim_t * 9.0)) * 4.5
	var spd: float = minf(routine_speed * 0.84, routine_speed - 2.0)
	if dist > BOSS_LEAP_RANGE * 0.76:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if (slot % 2 == 0) else -1.0)
		_move_step(perp * spd * 0.65 * dt, false)


func _step_commit(dt: float) -> void:
	if twin_pause_active:
		hop_z = 0.0
		var target_pos: Vector2 = _attention_target()
		if state_timer > 0.14:
			_face_point(target_pos, 4.0, dt)
			leap_to = _clamp_pt(target_pos)
		state_timer -= dt
		if state_timer <= 0.0:
			twin_pause_active = false
			commit_stage = CommitStage.LEAP
			state_timer = LEAP_DURATION
			leap_from = pos
			ring_progress = 0.0
			ring_hit = false
			_emit_sfx("hopper_leap")
		return

	if commit_stage == CommitStage.LEAP:
		super._step_commit(dt)
		return

	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / RING_DURATION, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, BOSS_RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= BOSS_RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if twin_hop_pending:
			twin_hop_pending = false
			twin_pause_active = true
			state_timer = _scaled_tell(TWIN_CROUCH_PAUSE, false, attack_damage)
			leap_to = _clamp_pt(_attention_target())
			ring_progress = 0.0
			ring_hit = false
			_emit_sfx("hopper_crouch")
		else:
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _body_color() -> Color:
	return (PAL["teal"] as Color) if phase >= 2 else (PAL["jade"] as Color)


func _draw_extra(off: Vector2) -> void:
	# Royal twin-blossom lily crown
	var leaf_r: float = body_radius + (2.5 if state == State.TELL else 1.0)
	draw_arc(off + Vector2(0.0, -body_radius + 1.0), leaf_r * 0.85, 0.2, TAU - 0.2, 16, PAL["lime"] as Color, 2.2)
	draw_circle(off + Vector2(-3.0, -body_radius - 1.5), 2.2, PAL["rose"] as Color)
	draw_circle(off + Vector2(3.0, -body_radius - 1.5), 2.2, PAL["gold"] as Color)
	if state == State.TELL or twin_pause_active:
		var rel: Vector2 = leap_to - pos
		draw_arc(rel, 9.0, 0.0, TAU, 16, PAL["sky"] as Color, 1.8)
		draw_line(off, rel, PAL["ice"] as Color, 1.2)
	elif state == State.COMMIT and commit_stage == CommitStage.RING:
		var ring_r: float = lerpf(RING_START_R, BOSS_RING_MAX_R, ring_progress)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, PAL["sky"] as Color, 3.2)
		draw_arc(Vector2.ZERO, maxf(2.0, ring_r - 2.5), 0.0, TAU, 24, PAL["cream"] as Color, 1.4)
	elif _roaring:
		draw_arc(off, body_radius + 11.0, 0.0, TAU, 22, PAL["lime"] as Color, 2.0)
