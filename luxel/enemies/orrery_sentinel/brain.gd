class_name LxOrrerySentinelBrain
extends LxEnemyBrain
## Orrery Sentinel (Island 5, Starfall Observatory).
## Glides smoothly along a clockwork rail with a rotating sight cone.
## Rings a bell (0.55s tell) when Wick enters the cone, then fires a beam-bolt along the cone.
## Front brass shell blocks normal bolts; back core takes full damage (prism_bolt, beam, or flank).

signal beam_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)

const CONE_HALF: float = 0.48
const CONE_RANGE: float = 134.0
const FRONT_SHELL_HALF: float = 1.05
const SCAN_TURN_SPEED: float = 1.25
const TRACK_TURN_SPEED: float = 1.45
const NOTICE_TIME: float = 0.24
const COMMIT_TIME: float = 0.24
const BOLT_RANGE: float = 148.0
const BOLT_HALF_W: float = 8.5
const STAGGER_TIME: float = 0.50
const RAIL_SPEED_RATIO: float = 0.72
const BACK_CRIT_MULT: float = 1.25

var rail_points: Array[Vector2] = []
var rail_i: int = 0
var rail_spin: float = 1.0
var shot_dir: Vector2 = Vector2.RIGHT
var shot_hit: bool = false
var shot_fired: bool = false
var _beam_end: Vector2 = Vector2.ZERO
var lens_pause_t: float = 0.0
var lens_highlight_t: float = 0.0
var lens_pause_cd: float = 0.0


func _init() -> void:
	kind = "orrery_sentinel"
	max_hp = 3.0
	hp = 3.0
	body_radius = 6.5
	routine_speed = 34.0
	leash_radius = 150.0
	notice_radius = CONE_RANGE
	tell_time = 0.55
	recover_time = 1.15
	give_up_time = 1.8
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	rail_points.clear()
	var raw_route: Variant = spec.get("route", [])
	if raw_route is Array:
		for pt_v: Variant in (raw_route as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				rail_points.append(_clamp_rail_point(_to_vec2(pt_v, home)))
	if rail_points.size() < 2:
		var r: float = minf(28.0, leash_radius * 0.35)
		rail_points.append(_clamp_rail_point(home + Vector2(-r, 0.0)))
		rail_points.append(_clamp_rail_point(home + Vector2(r, 0.0)))
	rail_i = 0
	rail_spin = 1.0 if float(spec.get("spin", 1.0)) >= 0.0 else -1.0
	shot_dir = Vector2.from_angle(facing)
	shot_hit = false
	shot_fired = false
	_beam_end = pos + shot_dir * BOLT_RANGE
	lens_pause_t = 0.0
	lens_highlight_t = 0.0
	lens_pause_cd = 0.0


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if state == State.DEAD:
		return
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = str(source)
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2
		elif b is String and src.is_empty():
			src = str(b)
	if src != "lens" or rad <= 0.0:
		return
	if orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius:
		lens_highlight_t = maxf(lens_highlight_t, 0.75)
		if lens_pause_cd <= 0.0:
			lens_pause_t = maxf(lens_pause_t, 0.60)
			lens_pause_cd = 1.8
			_emit_sfx("orrery_lens_pause")


func _back_crit_mult() -> float:
	return BACK_CRIT_MULT


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var bypass: bool = src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_BEAM \
			or src == LxHit.SOURCE_SUNFLARE or bool(h["pierce"]) or bool(h["cracks_armour"])
	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.01 \
			and absf(angle_difference(facing, rel.angle())) < FRONT_SHELL_HALF

	if front_hit and not bypass and _has_active_shield():
		clank_t = 0.14
		if src == LxHit.SOURCE_BOLT:
			_emit_sfx("orrery_clank")
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED
		# Heavy front throw chips brass shell lightly without full stagger
		dmg *= 0.45
		is_heavy = false
		_emit_sfx("orrery_clank")
	elif not front_hit:
		dmg *= _back_crit_mult()

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = (not front_hit) or bypass or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	if rel.length() > 0.01:
		var k_spd: float = 95.0 if is_heavy else 20.0
		knock = (-rel.normalized() * k_spd) if is_heavy else (knock - rel.normalized() * k_spd)

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if is_heavy or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
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
	match state:
		State.ROUTINE:
			_step_rail_patrol(dt)
			if lens_pause_t <= 0.0:
				facing = wrapf(facing + rail_spin * SCAN_TURN_SPEED * dt, -PI, PI)
			if _target_in_cone():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), TRACK_TURN_SPEED * 1.4, dt)
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
				cooldown = 0.85
				if _should_give_up():
					state = State.RETURN
				else:
					state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
				cooldown = 0.50
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

	_step_rail_patrol(dt)
	if lens_pause_t <= 0.0:
		facing = wrapf(facing + rail_spin * SCAN_TURN_SPEED * dt, -PI, PI)
	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN

	if can_act and cooldown <= 0.0 and _is_on_screen() and _target_in_cone() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("orrery_bell_tell")


func _step_tell(dt: float) -> void:
	# Gentle aim lock during first portion of bell ring, then freezes angle so Wick can sidestep
	if state_timer > 0.24 * _assist_tell_scale():
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), TRACK_TURN_SPEED * 0.8, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = COMMIT_TIME
		shot_dir = Vector2.from_angle(facing)
		shot_hit = false
		shot_fired = false
		_beam_end = pos + shot_dir * _clamped_beam_len(shot_dir, BOLT_RANGE)
		_emit_sfx("orrery_beam_bolt")


func _step_commit(dt: float) -> void:
	if not shot_fired:
		shot_fired = true
		beam_bolt_fired.emit(pos, shot_dir, self)
		LxDamageFx.boss_impact(pos + shot_dir * 26.0, 0.08, 52.0, 56.0, 60.0, 1.30, 0.24)
	if not shot_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(wp, pos, _beam_end)
		if closest.distance_to(wp) <= BOLT_HALF_W and _has_clear_view(pos, wp):
			shot_hit = true
			_emit_player_hit(shot_dir)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		var closest_l: Vector2 = Geometry2D.get_closest_point_to_segment(lp, pos, _beam_end)
		if closest_l.distance_to(lp) <= BOLT_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer
		facing = wrapf(facing + rail_spin * 0.45, -PI, PI)


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 2.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	var spd: float = routine_speed * 0.88
	_move_step(to_h.limit_length(spd * dt), false)
	facing = wrapf(facing + rail_spin * SCAN_TURN_SPEED * 0.6 * dt, -PI, PI)
	if _target_in_cone() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()


func _step_rail_patrol(dt: float) -> void:
	if rail_points.size() < 2:
		return
	var wp: Vector2 = rail_points[rail_i]
	if pos.distance_to(wp) <= 2.5:
		rail_i = (rail_i + 1) % rail_points.size()
		return
	var spd: float = routine_speed * RAIL_SPEED_RATIO
	_move_step((wp - pos).limit_length(spd * dt), false)


func _target_in_cone() -> bool:
	var tgt: Vector2 = _attention_target()
	if not _has_player() and not _is_lantern_out():
		return false
	var to_t: Vector2 = tgt - pos
	var dist: float = to_t.length()
	if dist > notice_radius or dist < 0.01:
		return false
	if absf(angle_difference(facing, to_t.angle())) > CONE_HALF:
		return false
	return _has_clear_view(pos, tgt)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0:
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("orrery_notice")


func _clamp_rail_point(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _clamped_beam_len(dir: Vector2, max_len: float) -> float:
	var step_px: float = 8.0
	var clear_d: float = body_radius + 2.0
	# Each segment starts 4 px back: clear_view never samples a segment's end points
	var seg_d: float = 0.0
	var d: float = clear_d + step_px
	while d <= max_len:
		if not _has_clear_view(pos + dir * seg_d, pos + dir * d):
			var mid_d: float = clear_d + step_px * 0.5
			if mid_d < d and _has_clear_view(pos + dir * seg_d, pos + dir * mid_d):
				return mid_d
			return clear_d
		clear_d = d
		seg_d = d - 4.0
		d += step_px
	if clear_d < max_len and not _has_clear_view(pos + dir * seg_d, pos + dir * max_len):
		return clear_d
	return max_len


func _has_active_shield() -> bool:
	return state != State.DEAD and state != State.STAGGER


func _body_color() -> Color:
	return PAL["deep"] as Color


func _shield_color() -> Color:
	return PAL["apricot"] as Color


func _draw_star_flare(pt: Vector2, arm: float, outer_c: Color) -> void:
	var p: Vector2 = pt.round()
	var inner: float = maxf(1.5, arm * 0.55)
	draw_line(p + Vector2(-arm, 0.0), p + Vector2(arm, 0.0), outer_c, 1.0)
	draw_line(p + Vector2(0.0, -arm), p + Vector2(0.0, arm), outer_c, 1.0)
	draw_line(p + Vector2(-inner, 0.0), p + Vector2(inner, 0.0), PAL["cream"] as Color, 1.0)
	draw_line(p + Vector2(0.0, -inner), p + Vector2(0.0, inner), PAL["cream"] as Color, 1.0)
	draw_rect(Rect2(p, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _sprite_sheet == null:
		# Glowing exposed back core
		var back_pos: Vector2 = off - Vector2.from_angle(facing) * (body_radius * 0.7)
		draw_circle(back_pos, 2.5, PAL["coral"] as Color)
		draw_circle(back_pos, 1.2, PAL["cream"] as Color)
	if lens_highlight_t > 0.0:
		var back_c: Vector2 = (c - Vector2.from_angle(facing) * (body_radius * 0.75)).round()
		draw_arc(back_c, 5.5, 0.0, TAU, 14, PAL["gold"] as Color, 1.0)
		draw_arc(back_c, 3.2, 0.0, TAU, 10, PAL["ice"] as Color, 1.0)
		draw_line(back_c + Vector2(-4.0, 0.0), back_c + Vector2(4.0, 0.0), PAL["cream"] as Color, 1.0)
		draw_line(back_c + Vector2(0.0, -4.0), back_c + Vector2(0.0, 4.0), PAL["cream"] as Color, 1.0)
	# Rotating sight cone preview with brass astrolabe tick marks (strictly opaque 20-colour PAL).
	var cone_r: float = minf(notice_radius, 72.0)
	var cone_col: Color = (PAL["gold"] as Color) if state == State.TELL else (PAL["blue"] as Color)
	var tick_col: Color = (PAL["gold"] as Color) if state == State.TELL else (PAL["apricot"] as Color)
	var left_d: Vector2 = Vector2.from_angle(facing - CONE_HALF)
	var right_d: Vector2 = Vector2.from_angle(facing + CONE_HALF)
	if state == State.TELL:
		var fwd_t: Vector2 = Vector2.from_angle(facing)
		var locked_t: bool = state_timer <= 0.24 * _assist_tell_scale()
		var beam_len: float = _clamped_beam_len(fwd_t, BOLT_RANGE)
		var ray_start: Vector2 = (c + fwd_t * (body_radius + 1.0)).round()
		var ray_end: Vector2 = (c + fwd_t * beam_len).round()
		var ray_c: Color = (PAL["coral"] as Color) if locked_t else (PAL["gold"] as Color)
		draw_line(c, (c + left_d * cone_r).round(), cone_col, 1.0)
		draw_line(c, (c + right_d * cone_r).round(), cone_col, 1.0)
		draw_arc(c, cone_r, facing - CONE_HALF, facing + CONE_HALF, 14, cone_col, 1.0)
		if locked_t:
			draw_line(ray_start, ray_end, PAL["void"] as Color, 4.0)
			draw_line(ray_start, ray_end, ray_c, 2.0)
			_draw_star_flare(ray_start, 3.5, PAL["coral"] as Color)
		else:
			var segs_o: int = maxi(4, int(beam_len / 8.0))
			for bi: int in range(0, segs_o, 2):
				var b0: Vector2 = (c + fwd_t * lerpf(body_radius + 2.0, beam_len, float(bi) / float(segs_o))).round()
				var b1: Vector2 = (c + fwd_t * lerpf(body_radius + 2.0, beam_len, minf(float(bi + 1), float(segs_o)) / float(segs_o))).round()
				draw_line(b0, b1, PAL["void"] as Color, 3.0)
				draw_line(b0, b1, ray_c, 1.0)
			_draw_star_flare(ray_start, 2.5, PAL["gold"] as Color)
		draw_rect(Rect2(ray_end, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	else:
		for si: int in range(0, 8, 2):
			var d0: float = cone_r * (float(si) / 8.0)
			var d1: float = cone_r * (float(si + 1) / 8.0)
			draw_line((c + left_d * d0).round(), (c + left_d * d1).round(), cone_col, 1.0)
			draw_line((c + right_d * d0).round(), (c + right_d * d1).round(), cone_col, 1.0)
		for ai: int in range(6):
			var a0: float = lerpf(facing - CONE_HALF, facing + CONE_HALF, float(ai) / 6.0)
			draw_arc(c, cone_r, a0, a0 + CONE_HALF * 0.20, 3, cone_col, 1.0)
	for ti: int in range(5):
		var ta: float = lerpf(facing - CONE_HALF, facing + CONE_HALF, float(ti) / 4.0)
		var td: Vector2 = Vector2.from_angle(ta)
		var t_len: float = 4.5 if (ti % 2 == 0) else 2.5
		draw_line((c + td * (cone_r - t_len)).round(), (c + td * cone_r).round(), tick_col, 1.0)
	if state == State.COMMIT:
		var emit_p: Vector2 = (c + shot_dir * (body_radius + 1.0)).round()
		var local_end: Vector2 = (_beam_end - pos).round()
		draw_line(emit_p, local_end, PAL["void"] as Color, 6.0)
		draw_line(emit_p, local_end, PAL["gold"] as Color, 4.0)
		draw_line(emit_p, local_end, PAL["ice"] as Color, 2.0)
		draw_line(emit_p, local_end, PAL["cream"] as Color, 1.0)
		_draw_star_flare(emit_p, 5.0, PAL["gold"] as Color)
		_draw_star_flare(local_end, 6.0, PAL["ice"] as Color)
