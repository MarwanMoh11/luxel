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
var shell_cracked_t: float = 0.0


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
	shell_cracked_t = 0.0


func _has_active_shield() -> bool:
	if shell_cracked_t > 0.0:
		return false
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
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < SHELL_BLOCK_HALF

	# Front shell blocks direct yellow front bolts; blue/prism bolts, flank/rear, or cracked shell land cleanly.
	if _has_active_shield() and src == LxHit.SOURCE_BOLT and not is_blue_hit and not pierce and not cracks and from_front:
		clank_t = 0.16
		_emit_sfx("barnacle_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	if is_blue_hit:
		dmg *= 1.5
		shell_cracked_t = 3.5
		_emit_sfx("barnacle_shell_crack")

	var flank_or_prism: bool = (not from_front) or is_blue_hit or not _has_active_shield()
	hp -= dmg
	flash_t = 0.14 if (is_heavy or flank_or_prism) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (55.0 if is_heavy else 18.0)

	if hp <= 0.001:
		opened_kill = flank_or_prism or state == State.RECOVER or state == State.STAGGER
		globs.clear()
		_die(hit)
		return HitResult.KILLED

	if is_heavy or is_blue_hit:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
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
	shell_cracked_t = maxf(0.0, shell_cracked_t - dt)
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

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
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
	LxDamageFx.boss_impact(pos + fire_dir * (body_radius + 4.0), 0.04, 26.0, 34.0, 32.0, 1.15, 0.18, "sky")
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


func _clamped_glob_len(dir: Vector2) -> float:
	var max_len: float = body_radius + 2.0 + GLOB_MAX_DIST
	var step_px: float = 8.0
	var clear_d: float = body_radius + 4.0
	var d: float = clear_d + step_px
	while d <= max_len:
		if not _has_clear_view(pos, pos + dir * d):
			var mid_d: float = clear_d + step_px * 0.5
			if mid_d < d and _has_clear_view(pos, pos + dir * mid_d):
				return mid_d
			return clear_d
		clear_d = d
		d += step_px
	if clear_d < max_len and not _has_clear_view(pos, pos + dir * max_len):
		return clear_d
	return max_len


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

	if shell_cracked_t > 0.0:
		var sc: Vector2 = off.round()
		draw_arc(sc, body_radius + 2.2, facing - 1.1, facing + 1.1, 10, PAL["sky"] as Color, 1.4)
		draw_line((sc + fwd * 2.0).round(), (sc + fwd * (body_radius + 3.0)).round(), PAL["cream"] as Color, 1.0)
		draw_line((sc + Vector2.from_angle(facing + 0.45) * 2.0).round(), (sc + Vector2.from_angle(facing + 0.55) * (body_radius + 2.5)).round(), PAL["ice"] as Color, 1.0)
		draw_line((sc + Vector2.from_angle(facing - 0.45) * 2.0).round(), (sc + Vector2.from_angle(facing - 0.55) * (body_radius + 2.5)).round(), PAL["ice"] as Color, 1.0)

	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked_t: bool = state_timer <= 0.20 * _assist_tell_scale()
		var muzzle: Vector2 = (off + fwd * (body_radius + 1.0)).round()
		var fl: float = roundf(2.0 + prog * 3.0)
		var aim_col: Color = (PAL["coral"] as Color) if locked_t else ((PAL["gold"] as Color) if prog > 0.50 else (PAL["sky"] as Color))
		var sight_len: float = _clamped_glob_len(fwd)
		var tip: Vector2 = (off + fwd * sight_len).round()
		var d_cur: float = body_radius + 4.0
		while d_cur < sight_len - 2.0:
			var d_end: float = minf(d_cur + 5.0, sight_len)
			var s0: Vector2 = (off + fwd * d_cur).round()
			var s1: Vector2 = (off + fwd * d_end).round()
			draw_line(s0, s1, PAL["void"] as Color, 2.2)
			draw_line(s0, s1, aim_col, 1.2 if locked_t else 1.0)
			d_cur += 9.0
		draw_rect(Rect2(tip + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), PAL["void"] as Color, true)
		draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		draw_circle(muzzle, 1.8 + prog * 1.4, PAL["deep"] as Color)
		draw_circle(muzzle, 1.2 + prog * 0.9, PAL["coral"] as Color if locked_t else PAL["sky"] as Color)
		draw_line(muzzle + Vector2(-fl, 0.0), muzzle + Vector2(fl, 0.0), PAL["ice"] as Color, 1.0)
		draw_line(muzzle + Vector2(0.0, -fl), muzzle + Vector2(0.0, fl), PAL["ice"] as Color, 1.0)
		draw_rect(Rect2(muzzle, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT or state == State.RECOVER:
		if _sprite_sheet == null:
			draw_circle(off, body_radius * 0.58, PAL["coral"] as Color)
			draw_circle(off, body_radius * 0.30, PAL["gold"] as Color)
		elif state == State.RECOVER:
			var op: Vector2 = (off + Vector2(0.0, -2.0)).round()
			draw_rect(Rect2(op + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), PAL["coral"] as Color, true)
			draw_rect(Rect2(op, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)

	for g: Dictionary in globs:
		var gp: Vector2 = ((g["pos"] as Vector2) - pos).round()
		var gd: Vector2 = g["dir"] as Vector2
		if gd.length_squared() < 0.001:
			gd = fwd
		var perp: Vector2 = Vector2(-gd.y, gd.x)
		var trav: float = float(g["traveled"])
		var tail_end: Vector2 = (gp - gd * 8.0).round()
		draw_line((gp - gd * 3.0).round(), tail_end, PAL["deep"] as Color, 1.5)
		draw_line((gp - gd * 3.0).round(), (gp - gd * 6.5).round(), PAL["sky"] as Color, 1.0)
		for si: int in range(3):
			var dist_s: float = 5.0 + float(si) * 2.5
			var lat_s: float = sin(trav * 0.25 + float(si) * 2.1) * (1.2 + float(si) * 0.6)
			var sp: Vector2 = (gp - gd * dist_s + perp * lat_s).round()
			draw_rect(Rect2(sp, Vector2(1.0, 1.0)), (PAL["ice"] as Color) if si == 0 else (PAL["sky"] as Color), true)
		var pinch: Vector2 = (gp - gd * 2.2).round()
		draw_circle(gp, GLOB_RADIUS + 0.5, PAL["deep"] as Color)
		draw_circle(pinch, GLOB_RADIUS * 0.62, PAL["deep"] as Color)
		draw_circle(gp, GLOB_RADIUS - 0.8, PAL["sky"] as Color)
		draw_circle(pinch, GLOB_RADIUS * 0.42, PAL["sky"] as Color)
		draw_circle((gp + Vector2(-1.0, -1.0)).round(), GLOB_RADIUS * 0.48, PAL["ice"] as Color)
		draw_rect(Rect2(gp + Vector2(-2.0, -2.0), Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
