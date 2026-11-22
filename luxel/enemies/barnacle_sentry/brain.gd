class_name LxBarnacleSentryBrain
extends LxEnemyBrain
## Barnacle Sentry (Island 2): fixed post turret with armored front shell.
## Shell blocks direct front bolts; prism_bolt or flank/rear hits land cleanly.
## Tells 0.60s, opens shell to fire a slow glob along fixed facing, recovers 1.10s.

const TURN_GUARD: float = 2.4
const TURN_TELL: float = 1.6
const SHELL_BLOCK_HALF: float = 1.15
const FIRE_RANGE: float = 132.0
const COMMIT_TIME: float = 0.24
const GLOB_SPEED: float = 92.0
const GLOB_RADIUS: float = 4.5
const GLOB_MAX_DIST: float = 136.0
const POST_COOLDOWN: float = 1.15

var fire_dir: Vector2 = Vector2.RIGHT
var globs: Array[Dictionary] = []
var look_t: float = 0.0


func _init() -> void:
	kind = "barnacle_sentry"
	island_id = 2
	max_hp = 2.0
	hp = 2.0
	body_radius = 6.0
	routine_speed = 20.0
	leash_radius = 120.0
	notice_radius = 135.0
	tell_time = 0.60
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	fire_dir = Vector2.from_angle(facing)
	globs.clear()
	look_t = 0.0


func _has_active_shield() -> bool:
	return state == State.ROUTINE or state == State.NOTICE \
			or state == State.POSITION or state == State.WAIT_TOKEN or state == State.TELL


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_heavy: bool = bool(h["stagger"])
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < SHELL_BLOCK_HALF

	# Front shell blocks direct front bolts; prism_bolt, flank/rear, or open shell land cleanly.
	if _has_active_shield() and src == LxHit.SOURCE_BOLT and not pierce and not cracks and from_front:
		clank_t = 0.16
		_emit_sfx("barnacle_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	var flank_or_prism: bool = (not from_front) or src == LxHit.SOURCE_PRISM or not _has_active_shield()
	hp -= dmg
	flash_t = 0.14 if (is_heavy or flank_or_prism) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (55.0 if is_heavy else 18.0)

	if hp <= 0.001:
		opened_kill = flank_or_prism or state == State.RECOVER or state == State.STAGGER
		globs.clear()
		_die(hit)
		return HitResult.KILLED

	if is_heavy or src == LxHit.SOURCE_PRISM:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55 if is_heavy else 0.35
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.32
		alert_t = 0.7
	var res: int = HitResult.OPENED if flank_or_prism else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	_step_globs(dt)
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			if pos.distance_to(home) > 2.0:
				_move_step((home - pos).limit_length(routine_speed * 0.85 * dt), false)
			else:
				look_t += dt
				_turn_toward(sin(look_t * 0.55) * 0.9, 1.2, dt)
			if _sees_target(target_pos):
				state = State.NOTICE
				state_timer = 0.32
				alert_t = 0.75
				lost_t = 0.0
				_emit_sfx("barnacle_notice")
		State.NOTICE:
			_face_point(target_pos, TURN_GUARD, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_guard(dt, target_pos)
		State.TELL:
			if state_timer > 0.20 * _assist_tell_scale():
				_face_point(target_pos, TURN_TELL, dt)
				fire_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
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
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_move_step(to_h.limit_length(routine_speed * dt), false)
				_turn_toward(to_h.angle(), TURN_GUARD, dt)


func _step_guard(dt: float, target_pos: Vector2) -> void:
	if pos.distance_to(home) > 2.5:
		_move_step((home - pos).limit_length(routine_speed * 0.8 * dt), false)
	_face_point(target_pos, TURN_GUARD, dt)

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

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	var dist: float = pos.distance_to(target_pos)
	var ang_ok: bool = dist < 0.01 or absf(angle_difference(facing, (target_pos - pos).angle())) < 0.55
	if can_act and cooldown <= 0.0 and dist <= FIRE_RANGE and ang_ok and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		fire_dir = Vector2.from_angle(facing)
		_emit_attack_started()
		_emit_sfx("barnacle_tell")


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	fire_dir = Vector2.from_angle(facing)
	globs.append({
		"pos": pos + fire_dir * (body_radius + 2.0),
		"dir": fire_dir,
		"traveled": 0.0,
	})
	_emit_sfx("barnacle_fire")


func _step_globs(dt: float) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	var i: int = globs.size() - 1
	while i >= 0:
		var g: Dictionary = globs[i]
		var prev_p: Vector2 = g["pos"] as Vector2
		var dir: Vector2 = g["dir"] as Vector2
		var step: float = GLOB_SPEED * dt
		var nxt_p: Vector2 = prev_p + dir * step
		g["pos"] = nxt_p
		g["traveled"] = float(g["traveled"]) + step
		var remove_it: bool = float(g["traveled"]) >= GLOB_MAX_DIST or not _has_clear_view(prev_p, nxt_p)
		if not remove_it and _has_player() and nxt_p.distance_to(wick_p) <= GLOB_RADIUS + 4.5:
			_emit_player_hit(dir)
			remove_it = true
		elif not remove_it and lan_out and nxt_p.distance_to(lan_p) <= GLOB_RADIUS + 5.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lan_p)
			remove_it = true
		if remove_it:
			globs.remove_at(i)
		i -= 1


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	if not _has_player() and not _is_lured():
		return false
	return pos.distance_to(target_pos) <= notice_radius and _has_clear_view(pos, target_pos)


func _body_color() -> Color:
	return PAL["pine"] as Color


func _shield_color() -> Color:
	return PAL["stone"] as Color


func _draw_extra(off: Vector2) -> void:
	var fwd: Vector2 = Vector2.from_angle(facing)
	if _sprite_sheet == null:
		var back: Vector2 = -fwd
		# Pedestal ring + exposed glowing back aperture (shows flank/prism vulnerability).
		draw_arc(off, body_radius + 1.5, 0.0, TAU, 16, PAL["night"] as Color, 1.5)
		draw_circle(off + back * (body_radius * 0.72), 2.5, PAL["apricot"] as Color)
		draw_circle(off + back * (body_radius * 0.72), 1.2, PAL["gold"] as Color)

	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		draw_circle(off + fwd * (body_radius * 0.4), 2.0 + prog * 2.5, PAL["lime"] as Color)
		draw_line(off + fwd * body_radius, off + fwd * (body_radius + 14.0), PAL["gold"] as Color, 1.0)
	elif (state == State.COMMIT or state == State.RECOVER) and _sprite_sheet == null:
		draw_circle(off, body_radius * 0.58, PAL["coral"] as Color)
		draw_circle(off, body_radius * 0.30, PAL["gold"] as Color)

	for g: Dictionary in globs:
		var gp: Vector2 = (g["pos"] as Vector2) - pos
		draw_circle(gp, GLOB_RADIUS + 1.0, PAL["night"] as Color)
		draw_circle(gp, GLOB_RADIUS, PAL["lime"] as Color)
		draw_circle(gp + Vector2(-1.0, -1.0), 1.5, PAL["cream"] as Color)
