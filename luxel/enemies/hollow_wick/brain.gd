class_name LxHollowWickBrain
extends LxEnemyBrain
## Hollow Wick (Island 7, Moon Shoals): the dark wearing Wick's kit.
## Rotates between honest telegraphed Bolt Volley (tell 0.45s), Flare Dash (tell 0.42s),
## and Lantern Throw+Zip (tell 0.52s), recovering 1.05s after each.
## LURE works on him: distracted by Wick's hung lantern!

signal hollow_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)
signal hollow_lantern_thrown(origin: Vector2, target: Vector2, source: LxEnemyBrain)

enum MoveKind { BOLT_VOLLEY, FLARE_DASH, LANTERN_ZIP }

const TELL_VOLLEY: float = 0.45
const TELL_DASH: float = 0.42
const TELL_ZIP: float = 0.52
const VOLLEY_COMMIT_TIME: float = 0.36
const VOLLEY_RANGE: float = 136.0
const VOLLEY_HALF_W: float = 8.0
const DASH_COMMIT_TIME: float = 0.22
const DASH_SPEED: float = 285.0
const DASH_HIT_R: float = 13.0
const ZIP_THROW_TIME: float = 0.18
const ZIP_FLY_TIME: float = 0.24
const ZIP_BURST_R: float = 22.0
const NOTICE_TIME: float = 0.30
const STAGGER_TIME: float = 0.48

var route: Array[Vector2] = []
var route_i: int = 0
var move_index: int = 0
var active_move: int = MoveKind.BOLT_VOLLEY
var commit_dir: Vector2 = Vector2.RIGHT
var commit_elapsed: float = 0.0
var commit_hit: bool = false
var volley_shots: int = 0
var dark_lantern_pos: Vector2 = Vector2.ZERO
var dark_lantern_out: bool = false
var zip_started: bool = false
var lured_now: bool = false
var _orbit_side: float = 1.0

func _init() -> void:
	kind = "hollow_wick"
	max_hp = 6.5
	hp = 6.5
	body_radius = 4.5
	routine_speed = 54.0
	leash_radius = 164.0
	notice_radius = 136.0
	tell_time = TELL_VOLLEY
	recover_time = 1.05
	give_up_time = 1.8
	shard_drop = 8
	attack_damage = 1.0

func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_route: Variant = spec.get("route", [])
	if raw_route is Array:
		for pt_v: Variant in (raw_route as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				route.append(_clamp_point(_to_vec2(pt_v, home)))
	route_i = 0
	move_index = 0
	active_move = MoveKind.BOLT_VOLLEY
	commit_dir = Vector2.from_angle(facing)
	commit_elapsed = 0.0
	commit_hit = false
	volley_shots = 0
	dark_lantern_pos = pos
	dark_lantern_out = false
	zip_started = false
	lured_now = false
	_orbit_side = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0

func distance_to_attention_target() -> float:
	return pos.distance_to(_attention_target())

func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var is_opening: bool = state == State.RECOVER or state == State.STAGGER or lured_now
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.07
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 24.0)
	if hp <= 0.001:
		opened_kill = is_opening
		dark_lantern_out = false
		_die(hit)
		return HitResult.KILLED
	if is_heavy:
		_release_token()
		dark_lantern_out = false
		state = State.STAGGER
		state_timer = 1.5 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED

func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["active_move"] = active_move
	d["lured"] = lured_now
	return d

func _step_brain(dt: float) -> void:
	lured_now = _is_lured()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
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
			dark_lantern_out = false
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				move_index = (move_index + 1) % 3
				cooldown = 0.72
				_orbit_side = -_orbit_side
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
				cooldown = 0.55
		State.RETURN:
			_step_return(dt)

func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.75 * dt), false)
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 2.5:
		route_i = (route_i + 1) % route.size()
		return
	facing = (wp - pos).angle()
	_move_step((wp - pos).limit_length(routine_speed * 0.80 * dt), false)

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
		_turn_toward(to_t.angle(), 4.2, dt)
	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= notice_radius and _is_on_screen() and _claim_token():
		_begin_move_tell(target)
		return
	if dist > 0.01:
		var radial: Vector2 = to_t / dist
		var move_v: Vector2 = (radial.rotated(PI * 0.5 * _orbit_side) + radial * clampf((dist - 58.0) / 48.0, -0.5, 0.5)).normalized()
		_move_step(move_v * routine_speed * 0.85 * dt, false)

func _begin_move_tell(target: Vector2) -> void:
	active_move = move_index
	state = State.TELL
	is_counter_attack = false
	var base_t: float = TELL_DASH if active_move == MoveKind.FLARE_DASH else (TELL_ZIP if active_move == MoveKind.LANTERN_ZIP else TELL_VOLLEY)
	last_tell_duration = _scaled_tell(base_t, false, attack_damage)
	state_timer = last_tell_duration
	if target.distance_to(pos) > 0.01:
		facing = (target - pos).angle()
	commit_dir = Vector2.from_angle(facing)
	if active_move == MoveKind.LANTERN_ZIP:
		dark_lantern_pos = _clamp_point(pos + commit_dir * clampf(target.distance_to(pos), 32.0, 92.0))
	_emit_attack_started()
	_emit_sfx("hollow_wick_tell")

func _step_tell(dt: float) -> void:
	if state_timer > 0.16:
		var target_now: Vector2 = _attention_target()
		var to_t: Vector2 = target_now - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 3.2, dt)
			commit_dir = Vector2.from_angle(facing)
		if active_move == MoveKind.LANTERN_ZIP:
			dark_lantern_pos = _clamp_point(pos + commit_dir * clampf(target_now.distance_to(pos), 32.0, 92.0))
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		commit_elapsed = 0.0
		commit_hit = false
		volley_shots = 0
		zip_started = false
		if active_move == MoveKind.BOLT_VOLLEY:
			state_timer = VOLLEY_COMMIT_TIME
		elif active_move == MoveKind.FLARE_DASH:
			state_timer = DASH_COMMIT_TIME
		else:
			state_timer = ZIP_THROW_TIME + ZIP_FLY_TIME
			dark_lantern_pos = _clamp_point(dark_lantern_pos)
			dark_lantern_out = true
			hollow_lantern_thrown.emit(pos, dark_lantern_pos, self)
		_emit_sfx("hollow_wick_commit")

func _step_commit(dt: float) -> void:
	commit_elapsed += dt
	state_timer -= dt
	if active_move == MoveKind.BOLT_VOLLEY:
		_step_commit_volley()
	elif active_move == MoveKind.FLARE_DASH:
		_move_step(commit_dir * DASH_SPEED * dt, true)
		_check_contact_hit(DASH_HIT_R)
	else:
		_step_commit_zip(dt)
	if state_timer <= 0.0:
		dark_lantern_out = false
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer

func _step_commit_volley() -> void:
	var expected: int = mini(3, int(commit_elapsed / 0.11) + 1)
	while volley_shots < expected:
		var bdir: Vector2 = commit_dir.rotated((float(volley_shots) - 1.0) * 0.14)
		volley_shots += 1
		hollow_bolt_fired.emit(pos, bdir, self)
		var end_p: Vector2 = pos + bdir * VOLLEY_RANGE
		if not commit_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= VOLLEY_HALF_W and _has_clear_view(pos, wp):
				commit_hit = true
				_emit_player_hit(bdir)
		if _is_lantern_out():
			var lp: Vector2 = _get_lantern_pos()
			if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= VOLLEY_HALF_W + 2.0 and Lx.events != null:
				Lx.events.lantern_struck.emit(lp)

func _step_commit_zip(dt: float) -> void:
	if commit_elapsed < ZIP_THROW_TIME:
		return
	if not zip_started:
		zip_started = true
		_emit_sfx("hollow_wick_zip")
	var to_l: Vector2 = dark_lantern_pos - pos
	if to_l.length() > 3.0:
		_move_step(to_l.limit_length(340.0 * dt), true)
	if pos.distance_to(dark_lantern_pos) <= 6.0:
		_check_contact_hit(ZIP_BURST_R)

func _check_contact_hit(rad: float) -> void:
	if not commit_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= rad:
		commit_hit = true
		_emit_player_hit(commit_dir)
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= rad + 2.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())

func _step_return(dt: float) -> void:
	dark_lantern_out = false
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()

func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 32.0

func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()

func _sees_target() -> bool:
	return (pos.distance_to(_get_lantern_pos()) <= notice_radius + 16.0) if _is_lured() else (_has_player() and pos.distance_to(_get_wick_pos()) <= notice_radius)

func _should_give_up() -> bool:
	return (not _is_lured()) and (not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0)

func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("hollow_wick_notice")

func _clamp_point(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	return home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt

func _body_color() -> Color:
	return PAL["night"] as Color

func _volley_count() -> int:
	return 3

func _volley_spread() -> float:
	return 0.14

func _draw_lunar_bolt(pt: Vector2, dir: Vector2) -> void:
	var p: Vector2 = pt.round()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var head: Vector2 = (p + dir * 3.5).round()
	var tail: Vector2 = (p - dir * 3.5).round()
	draw_line(tail, head, PAL["sky"] as Color, 2.6)
	draw_line((p + perp * 2.0).round(), head, PAL["ice"] as Color, 1.0)
	draw_line((p - perp * 2.0).round(), head, PAL["ice"] as Color, 1.0)
	draw_line(p, head, PAL["cream"] as Color, 1.2)
	draw_rect(Rect2(head, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)

func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if state == State.COMMIT and active_move == MoveKind.LANTERN_ZIP and dark_lantern_out and (commit_elapsed < ZIP_THROW_TIME or pos.distance_to(dark_lantern_pos) > 6.0):
		var z_urg: float = lerpf(0.75, 1.0, clampf(commit_elapsed / maxf(ZIP_THROW_TIME, 0.05), 0.0, 1.0))
		LxBossTelegraphFx.draw_ground_danger_ring(self, dark_lantern_pos - pos, 26.0, z_urg, anim_t, "sky", "coral")
	if dark_lantern_out or _sprite_sheet == null:
		var lan_off: Vector2 = ((dark_lantern_pos - pos) if dark_lantern_out else (c + Vector2.from_angle(facing) * 6.0)).round()
		if dark_lantern_out:
			draw_line(c, lan_off, PAL["deep"] as Color, 1.6)
			draw_line(c, lan_off, PAL["sky"] as Color, 1.0)
			for bi: int in range(1, 5):
				var bp: Vector2 = c.lerp(lan_off, float(bi) * 0.2).round()
				draw_rect(Rect2(bp + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), (PAL["ice"] as Color) if (bi % 2 == 0) else (PAL["sky"] as Color), true)
				draw_rect(Rect2(bp, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
			draw_arc(lan_off, 5.5, 0.0, TAU, 12, PAL["sky"] as Color, 1.0)
		draw_rect(Rect2(lan_off + Vector2(-1.0, -5.0), Vector2(2.0, 1.0)), PAL["sky"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(-2.0, -4.0), Vector2(4.0, 1.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), PAL["deep"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(-1.0, -2.0), Vector2(2.0, 4.0)), PAL["sky"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), PAL["ice"] as Color, true)
		draw_rect(Rect2(lan_off + Vector2(0.0, -1.0), Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	if state == State.TELL:
		var t_urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var hot_t: bool = state_timer <= 0.22 * _assist_tell_scale()
		var tc: Color = (PAL["coral"] if hot_t else (PAL["gold"] if lured_now else PAL["ice"])) as Color
		if active_move == MoveKind.FLARE_DASH:
			var dash_len: float = DASH_SPEED * DASH_COMMIT_TIME + DASH_HIT_R
			LxBossTelegraphFx.draw_ground_danger_lane(self, c, c + commit_dir * dash_len, DASH_HIT_R, t_urg, anim_t, "coral", "gold")
		elif active_move == MoveKind.BOLT_VOLLEY:
			draw_line(c, (c + commit_dir * 50.0).round(), tc, 1.8 if hot_t else 1.4)
			var vc: int = _volley_count()
			var vs: float = _volley_spread()
			var vm: float = float(vc - 1) * 0.5
			for vi: int in range(vc):
				var vdir: Vector2 = commit_dir.rotated((float(vi) - vm) * vs)
				draw_line(c, (c + vdir * VOLLEY_RANGE).round(), (PAL["coral"] if hot_t else PAL["blue"]) as Color, 1.4 if hot_t else 1.0)
				_draw_lunar_bolt(c + vdir * 22.0, vdir)
		elif active_move == MoveKind.LANTERN_ZIP:
			var zc: Vector2 = (dark_lantern_pos - pos).round()
			LxBossTelegraphFx.draw_ground_danger_ring(self, zc, 26.0, t_urg, anim_t, "sky", "coral")
			draw_line(c, zc, (PAL["coral"] if hot_t else PAL["sky"]) as Color, 1.3)
			draw_circle(zc, 2.2, (PAL["cream"] if hot_t else PAL["ice"]) as Color)
	elif state == State.COMMIT and active_move == MoveKind.BOLT_VOLLEY:
		var prog: float = clampf(commit_elapsed / VOLLEY_COMMIT_TIME, 0.0, 1.0)
		var vc2: int = _volley_count()
		var vs2: float = _volley_spread()
		var vm2: float = float(vc2 - 1) * 0.5
		for vi: int in range(vc2):
			var vdir: Vector2 = commit_dir.rotated((float(vi) - vm2) * vs2)
			var b_end: Vector2 = (c + vdir * VOLLEY_RANGE).round()
			draw_line(c, b_end, PAL["sky"] as Color, 2.0 if absf(float(vi) - vm2) < 0.1 else 1.4)
			draw_line(c, (c + vdir * (VOLLEY_RANGE * 0.85)).round(), PAL["ice"] as Color, 1.0)
			_draw_lunar_bolt(c + vdir * lerpf(16.0, VOLLEY_RANGE - 6.0, prog), vdir)
