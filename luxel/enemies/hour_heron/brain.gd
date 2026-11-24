class_name LxHourHeronBrain
extends LxEnemyBrain
## Hour Heron (Island 4): marble metronome lancer.
## Steps and strikes strictly on a 1.0 s tick; marble-invulnerable (GLANCED) between beats,
## vulnerable during its 0.45 s step window, TELL/COMMIT, and 1.10 s RECOVER!

const TICK_PERIOD: float = 1.0
const STEP_OPEN_WINDOW: float = 0.45
const STEP_DIST: float = 28.0
const LUNGE_RANGE: float = 104.0
const LUNGE_DIST: float = 84.0
const LUNGE_COMMIT_S: float = 0.26
const LUNGE_HIT_R: float = 14.0
const POST_COOLDOWN: float = 1.00

var _tick_clock: float = 0.0
var _step_open_t: float = 0.0
var _step_from: Vector2 = Vector2.ZERO
var _step_to: Vector2 = Vector2.ZERO
var _cardinal_idx: int = 0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_from: Vector2 = Vector2.ZERO
var _lunge_hit: bool = false
var _marble_flash_t: float = 0.0


func _init() -> void:
	kind = "hour_heron"
	island_id = 4
	max_hp = 3.5
	hp = 3.5
	body_radius = 6.0
	routine_speed = 46.0
	leash_radius = 158.0
	notice_radius = 140.0
	tell_time = 0.55
	recover_time = 1.10
	give_up_time = 2.0
	shard_drop = 5


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_tick_clock = 0.55
	_step_open_t = STEP_OPEN_WINDOW
	_step_from = pos
	_step_to = pos
	_cardinal_idx = 0
	_lunge_dir = Vector2.from_angle(facing)
	_lunge_from = pos
	_lunge_hit = false
	_marble_flash_t = 0.0


func is_vulnerable() -> bool:
	return _step_open_t > 0.0 or state in [State.TELL, State.COMMIT, State.RECOVER, State.STAGGER]


func is_targetable() -> bool:
	return is_alive()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"]) or bool(h["pierce"]) or bool(h["cracks_armour"])

	if not is_vulnerable():
		# Marble-invulnerable between metronome beats!
		clank_t = 0.18
		_marble_flash_t = 0.22
		_emit_sfx("hour_heron_clank")
		if state == State.ROUTINE:
			state = State.NOTICE
			state_timer = 0.30
			alert_t = 0.8
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var punish: bool = state == State.RECOVER or state == State.STAGGER or _step_open_t > 0.0
	hp -= dmg * (1.20 if state == State.RECOVER else 1.0)
	flash_t = 0.15 if (punish or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 34.0)
	if hp <= 0.001:
		opened_kill = punish
		_die(hit)
		return HitResult.KILLED
	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.28
		alert_t = 0.8
	_emit_enemy_hit(hit, HitResult.OPENED if punish else HitResult.CHIPPED)
	return HitResult.OPENED if punish else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_marble_flash_t = maxf(0.0, _marble_flash_t - dt)
	var ticked: bool = false
	_tick_clock += dt
	if _tick_clock >= TICK_PERIOD:
		_tick_clock -= TICK_PERIOD
		ticked = true
		_step_open_t = STEP_OPEN_WINDOW
		if _is_on_screen():
			_emit_sfx("hour_heron_tick")

	if _step_open_t > 0.0:
		_step_open_t = maxf(0.0, _step_open_t - dt)
		# Crisp mechanical slide during the first 0.22s of a step beat
		if state in [State.ROUTINE, State.POSITION, State.WAIT_TOKEN, State.RETURN]:
			var step_u: float = clampf(1.0 - (_step_open_t / STEP_OPEN_WINDOW), 0.0, 1.0)
			if step_u < 0.55:
				var desired: Vector2 = _step_from.lerp(_step_to, step_u / 0.55)
				_move_step(desired - pos, false)

	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			if ticked:
				_begin_cardinal_patrol_step()
			if _has_player() and pos.distance_to(target_pos) <= notice_radius:
				state = State.NOTICE
				state_timer = 0.28
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("heron_notice")
		State.NOTICE:
			_snap_cardinal_face(target_pos)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos, ticked)
		State.TELL:
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
				_step_from = home
				_step_to = home
				state = State.ROUTINE
				lost_t = 0.0
			elif ticked:
				facing = to_h.angle()
				_step_from = pos
				_step_to = pos + to_h.limit_length(STEP_DIST * 1.45)


func _begin_cardinal_patrol_step() -> void:
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var d: Vector2 = dirs[_cardinal_idx % 4]
	_cardinal_idx = (_cardinal_idx + 1) % 4
	facing = d.angle()
	_step_from = pos
	_step_to = _clamp_pt(pos + d * STEP_DIST)


func _step_position(dt: float, target_pos: Vector2, ticked: bool) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()

	var wick_p: Vector2 = _get_real_wick_pos()
	if not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0:
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

	if not ticked:
		return

	_snap_cardinal_face(target_pos)
	if is_lead and cooldown <= 0.0 and dist <= LUNGE_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		# Snap lunge strictly along the closest cardinal axis (or direct if nearly aligned)
		_lunge_dir = _cardinal_toward(target_pos)
		facing = _lunge_dir.angle()
		_step_from = pos
		_step_to = pos
		_emit_attack_started()
		_emit_sfx("hour_heron_tick")
		return

	# Step on the 1.0 s tick toward cardinal alignment with Wick
	var step_dir: Vector2 = _cardinal_toward(target_pos)
	if dist < 34.0:
		step_dir = -step_dir
	_step_from = pos
	_step_to = _clamp_pt(pos + step_dir * STEP_DIST)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LUNGE_COMMIT_S
	_lunge_from = pos
	_lunge_hit = false
	facing = _lunge_dir.angle()
	_emit_sfx("hour_heron_lunge")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	var before: Vector2 = pos
	var spd: float = LUNGE_DIST / maxf(LUNGE_COMMIT_S, 0.05)
	_move_step(_lunge_dir * spd * dt, false)
	var tip: Vector2 = pos + _lunge_dir * 12.0
	if not _lunge_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, before, tip).distance_to(wp) <= LUNGE_HIT_R:
			_lunge_hit = true
			_emit_player_hit(_lunge_dir)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer
		_step_from = pos
		_step_to = pos


func _cardinal_toward(pt: Vector2) -> Vector2:
	var d: Vector2 = pt - pos
	if absf(d.x) >= absf(d.y):
		return Vector2.RIGHT if d.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if d.y >= 0.0 else Vector2.UP


func _snap_cardinal_face(pt: Vector2) -> void:
	facing = _cardinal_toward(pt).angle()


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _has_active_shield() -> bool:
	return not is_vulnerable()


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _body_color() -> Color:
	return (PAL["gold"] if is_vulnerable() else PAL["stone"]) as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Metronome pulse ring: bright gold when step-vulnerable, cool marble shield when invulnerable
	if is_vulnerable() and state != State.TELL and state != State.COMMIT:
		var pulse: float = 0.0 if LxHudFx.flash_reduced() else sin(anim_t * 14.0) * 1.0
		draw_arc(c, body_radius + 3.5 + pulse, 0.0, TAU, 16, PAL["gold"] as Color, 1.3)
	elif _marble_flash_t > 0.0:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 14, PAL["ice"] as Color, 1.6)

	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var end_p: Vector2 = (c + _lunge_dir * LUNGE_DIST).round()
		var col: Color = (PAL["coral"] if prog > 0.68 else PAL["gold"]) as Color
		draw_line(c, end_p, col, 1.8 if prog > 0.68 else 1.2)
		draw_arc(end_p, lerpf(8.0, 4.0, prog), 0.0, TAU, 12, PAL["cream"] as Color, 1.2)
	elif state == State.COMMIT:
		var tail: Vector2 = (c - _lunge_dir * 16.0).round()
		var tip: Vector2 = (c + _lunge_dir * 15.0).round()
		draw_line(tail, tip, PAL["gold"] as Color, 3.0)
		draw_line(c, tip, PAL["cream"] as Color, 1.5)
