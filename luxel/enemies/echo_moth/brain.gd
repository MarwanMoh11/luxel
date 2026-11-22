class_name LxEchoMothBrain
extends LxEnemyBrain
## Echo Moth (Island 5, Starfall Observatory).
## Flutters a routine loop; records Wick's movement direction and mimics a committed dash or
## echo-bolt 1.0s later (tell 0.45s, recover 1.0s). Foreshadows Hollow Wick; baitable into hazards.

signal echo_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)

const ECHO_DELAY: float = 1.0
const LOOP_RX: float = 34.0
const LOOP_RY: float = 20.0
const NOTICE_TIME: float = 0.25
const DASH_COMMIT_TIME: float = 0.24
const DASH_SPEED: float = 210.0
const DASH_HIT_R: float = 12.0
const BOLT_COMMIT_TIME: float = 0.22
const BOLT_RANGE: float = 132.0
const BOLT_HALF_W: float = 8.0
const STAGGER_TIME: float = 0.50

var _clock: float = 0.0
var _loop_t: float = 0.0
var _prev_wick: Vector2 = Vector2.ZERO
var _has_prev_wick: bool = false
var _history: Array[Dictionary] = []
var _echo_dir: Vector2 = Vector2.RIGHT
var _echo_is_dash: bool = true
var _attack_seq: int = 0
var _commit_hit: bool = false
var _bolt_fired: bool = false


func _init() -> void:
	kind = "echo_moth"
	max_hp = 2.0
	hp = 2.0
	body_radius = 4.5
	routine_speed = 58.0
	leash_radius = 158.0
	notice_radius = 128.0
	tell_time = 0.45
	recover_time = 1.00
	give_up_time = 1.8
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_clock = 0.0
	_loop_t = _randf_range(0.0, TAU)
	_history.clear()
	_has_prev_wick = false
	_echo_dir = Vector2.from_angle(facing)
	_echo_is_dash = true
	_attack_seq = 0
	_commit_hit = false
	_bolt_fired = false


func is_flying() -> bool:
	return state != State.RECOVER and state != State.STAGGER


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = state == State.RECOVER or state == State.STAGGER or state == State.ROUTINE
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = (-rel.normalized() * (120.0 if is_heavy else 26.0))
	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED
	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_clock += dt
	_record_wick_motion(dt)
	match state:
		State.ROUTINE:
			_step_flutter_loop(dt, home, 0.72)
			if _has_player() and _get_wick_pos().distance_to(pos) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.01:
				_turn_toward(to_w.angle(), 5.0, dt)
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
				cooldown = 0.80
				if _should_give_up():
					state = State.RETURN
				else:
					state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
				cooldown = 0.55
		State.RETURN:
			_step_return(dt)


func _record_wick_motion(dt: float) -> void:
	if not _has_player():
		return
	var wp: Vector2 = _get_wick_pos()
	var dir: Vector2 = Vector2.RIGHT
	var spd: float = 0.0
	if _has_prev_wick and dt > 0.0001:
		var delta: Vector2 = wp - _prev_wick
		spd = delta.length() / dt
		if delta.length() > 0.05:
			dir = delta.normalized()
		elif (wp - pos).length() > 0.01:
			dir = (wp - pos).normalized()
	elif (wp - pos).length() > 0.01:
		dir = (wp - pos).normalized()
	_prev_wick = wp
	_has_prev_wick = true
	_history.append({"t": _clock, "dir": dir, "fast": spd > 130.0})
	while _history.size() > 2 and _clock - float((_history[0] as Dictionary)["t"]) > ECHO_DELAY + 0.35:
		_history.pop_front()


func _sample_echo() -> Dictionary:
	var target_t: float = _clock - ECHO_DELAY
	if _history.is_empty():
		var fallback: Vector2 = (_get_wick_pos() - pos).normalized() if _has_player() else Vector2.from_angle(facing)
		return {"dir": fallback, "fast": false}
	for i: int in range(_history.size() - 1, -1, -1):
		var item: Dictionary = _history[i]
		if float(item["t"]) <= target_t:
			return item
	return _history[0]


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

	_step_flutter_loop(dt, home, 0.80)
	var to_w: Vector2 = _get_wick_pos() - pos
	if to_w.length() > 0.01:
		_turn_toward(to_w.angle(), 4.2, dt)

	state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN
	if cooldown <= 0.0 and _is_on_screen() and _clock >= ECHO_DELAY * 0.5 \
			and to_w.length() <= notice_radius and _claim_token():
		var sample: Dictionary = _sample_echo()
		_echo_dir = (sample["dir"] as Vector2).normalized()
		if _echo_dir.length_squared() < 0.01:
			_echo_dir = to_w.normalized() if to_w.length() > 0.01 else Vector2.from_angle(facing)
		_echo_is_dash = bool(sample["fast"]) or (_attack_seq % 2 == 0)
		_attack_seq += 1
		facing = _echo_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("echo_moth_tell")


func _step_tell(dt: float) -> void:
	facing = _echo_dir.angle()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = DASH_COMMIT_TIME if _echo_is_dash else BOLT_COMMIT_TIME
		_commit_hit = false
		_bolt_fired = false
		_emit_sfx("echo_moth_dash" if _echo_is_dash else "echo_moth_bolt")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	if _echo_is_dash:
		var step: float = DASH_SPEED * dt
		var before: Vector2 = pos
		_move_step(_echo_dir * step, true)
		var moved: float = before.distance_to(pos)
		if not _commit_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= DASH_HIT_R:
			_commit_hit = true
			_emit_player_hit(_echo_dir)
		# Baitable into obstacles/hazards: bonking ends dash into recover
		var hit_obstacle: bool = step > 0.5 and moved < step * 0.30
		if _check_hazard_at(pos):
			hp = maxf(0.25, hp - 0.5)
			flash_t = 0.14
			hit_obstacle = true
		if hit_obstacle or state_timer <= 0.0:
			_enter_recover()
	else:
		if not _bolt_fired:
			_bolt_fired = true
			echo_bolt_fired.emit(pos, _echo_dir, self)
		var end_p: Vector2 = pos + _echo_dir * BOLT_RANGE
		if not _commit_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(wp, pos, end_p)
			if closest.distance_to(wp) <= BOLT_HALF_W and _has_clear_view(pos, wp):
				_commit_hit = true
				_emit_player_hit(_echo_dir)
		if state_timer <= 0.0:
			_enter_recover()


func _enter_recover() -> void:
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
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)
	if _has_player() and _get_wick_pos().distance_to(home) <= notice_radius * 0.85:
		_enter_notice()


func _step_flutter_loop(dt: float, center: Vector2, speed_ratio: float) -> void:
	_loop_t = wrapf(_loop_t + dt * 1.45, -PI, PI)
	var target: Vector2 = center + Vector2(cos(_loop_t) * LOOP_RX, sin(_loop_t * 2.0) * LOOP_RY)
	var d: Vector2 = target - pos
	if d.length() > 1.0:
		var spd: float = routine_speed * speed_ratio
		_move_step(d.limit_length(spd * dt), true)
		if state == State.ROUTINE:
			facing = d.angle()


func _check_hazard_at(p: Vector2) -> bool:
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx != null and is_instance_valid(ctx) and ctx.has_method("is_hazard_at"):
			return bool(ctx.call("is_hazard_at", p))
	return false


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("echo_moth_notice")


func _body_color() -> Color:
	return PAL["mauve"] as Color


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		var wing: float = 3.0 + sin(anim_t * 14.0) * 1.5
		draw_line(off + Vector2(-body_radius - wing, -1.0), off + Vector2(body_radius + wing, -1.0), PAL["sky"] as Color, 1.5)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var preview_len: float = (DASH_SPEED * DASH_COMMIT_TIME) if _echo_is_dash else BOLT_RANGE
		var c: Vector2 = off.round()
		var tip: Vector2 = (c + _echo_dir * preview_len).round()
		var perp_t := Vector2(-_echo_dir.y, _echo_dir.x)
		if _echo_is_dash:
			var dc: Color = (PAL["gold"] as Color) if prog > 0.65 else (PAL["ice"] as Color)
			draw_line(c, tip, dc, 1.2)
			draw_line((tip - _echo_dir * 5.0 + perp_t * 3.5).round(), tip, dc, 1.4)
			draw_line((tip - _echo_dir * 5.0 - perp_t * 3.5).round(), tip, dc, 1.4)
			draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		else:
			var hot: bool = prog > 0.65
			var lc: Color = (PAL["coral"] as Color) if hot else (PAL["gold"] as Color)
			if hot:
				draw_line(c, tip, lc, 1.4)
			else:
				for si: int in range(0, 16, 2):
					var p0: Vector2 = (c + _echo_dir * (preview_len * float(si) / 16.0)).round()
					var p1: Vector2 = (c + _echo_dir * (preview_len * float(si + 1) / 16.0)).round()
					draw_line(p0, p1, lc, 1.0)
			draw_line(tip + Vector2(-3.0, 0.0), tip + Vector2(3.0, 0.0), PAL["ice"] as Color, 1.0)
			draw_line(tip + Vector2(0.0, -3.0), tip + Vector2(0.0, 3.0), PAL["ice"] as Color, 1.0)
			draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT:
		var c: Vector2 = off.round()
		var perp: Vector2 = Vector2(-_echo_dir.y, _echo_dir.x)
		var step_dir: Vector2 = (-_echo_dir) if _echo_is_dash else _echo_dir
		var trail_len: float = 24.0 if _echo_is_dash else BOLT_RANGE
		var mid_p: Vector2 = c + step_dir * (trail_len * 0.55)
		var end_p: Vector2 = c + step_dir * trail_len
		var shim: float = sin(anim_t * 36.0)
		for si: int in range(-1, 2, 2):
			var s: float = float(si)
			var p0: Vector2 = (c + perp * (s * 2.0)).round()
			var p1: Vector2 = (mid_p + perp * (s * 2.6 + shim * 0.9)).round()
			var p2: Vector2 = (end_p + perp * (s * 1.4 - shim * 0.9)).round()
			draw_line(p0, p1, PAL["blue"] as Color, 2.0)
			draw_line(p1, p2, PAL["blue"] as Color, 1.5)
			draw_line(p0, p1, PAL["sky"] as Color, 1.0)
			draw_line(p1, p2, PAL["sky"] as Color, 1.0)
		draw_line(c, end_p.round(), PAL["ice"] as Color, 1.8)
		draw_line(c, (c + step_dir * (trail_len * (0.72 if _echo_is_dash else 0.92))).round(), PAL["cream"] as Color, 1.0)
		for mi: int in range(1, 4):
			var mp: Vector2 = (c + step_dir * (trail_len * float(mi) * 0.26) + perp * (shim * (2.0 if mi == 2 else -2.0))).round()
			draw_rect(Rect2(mp, Vector2(1.0, 1.0)), (PAL["cream"] as Color) if mi == 1 else (PAL["ice"] as Color), true)
		# Tiny 3 px starlight echo cross at origin
		draw_rect(Rect2(c + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), PAL["cream"] as Color, true)
		draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), PAL["cream"] as Color, true)
		draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
		draw_rect(Rect2(c + Vector2(2.0, 0.0), Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
		draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2(1.0, 1.0)), PAL["sky"] as Color, true)
		draw_rect(Rect2(c + Vector2(0.0, 2.0), Vector2(1.0, 1.0)), PAL["sky"] as Color, true)
