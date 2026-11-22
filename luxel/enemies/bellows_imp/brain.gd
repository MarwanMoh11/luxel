class_name LxBellowsImpBrain
extends LxEnemyBrain
## Bellows Imp (Island 6, Ashen Kiln).
## Tends furnaces; inhales (0.50s tell), commits directional gust pushing Wick & thrown lantern
## back, recovers 1.10s; fragile once bellows struck (punctured on hit during tell or heavy hit).

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

const GUST_RANGE: float = 116.0
const GUST_HALF_W: float = 24.0
const GUST_DAMAGE_R: float = 56.0
const GUST_COMMIT_TIME: float = 0.34
const GUST_PUSH_WICK: float = 240.0
const GUST_PUSH_LANTERN: float = 135.0
const NOTICE_TIME: float = 0.28
const STAGGER_TIME: float = 0.60
const PUNCTURED_MULT: float = 1.5

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var bellows_punctured: bool = false
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false


func _init() -> void:
	kind = "bellows_imp"
	max_hp = 1.75
	hp = 1.75
	body_radius = 4.5
	routine_speed = 38.0
	leash_radius = 148.0
	notice_radius = 128.0
	tell_time = 0.50
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_route: Variant = spec.get("route", [])
	if raw_route is Array:
		for pt_v: Variant in (raw_route as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				route.append(pt)
	route_i = 0
	pause_t = 0.0
	bellows_punctured = false
	gust_dir = Vector2.from_angle(facing)
	gust_hit = false
	gust_announced = false


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

	var struck_inflated: bool = state == State.TELL
	if struck_inflated or is_heavy:
		if not bellows_punctured:
			bellows_punctured = true
			_emit_sfx("bellows_puncture")
	if bellows_punctured:
		dmg *= PUNCTURED_MULT

	var is_opening: bool = bellows_punctured or struck_inflated or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if (is_heavy or struck_inflated) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 35.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if is_heavy or struck_inflated:
		_release_token()
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
	d["bellows_punctured"] = bellows_punctured
	return d


func _step_brain(dt: float) -> void:
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 4.5, dt)
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
				cooldown = 0.90
				if _should_give_up():
					state = State.RETURN
				else:
					state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
				cooldown = 0.65
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.75 * dt), false)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 2.5:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.85
		return
	var to_wp: Vector2 = wp - pos
	_turn_toward(to_wp.angle(), 3.6, dt)
	_move_step(to_wp.limit_length(routine_speed * 0.80 * dt), false)


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
		_turn_toward(to_t.angle(), 3.4, dt)

	state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN
	if cooldown <= 0.0 and dist <= GUST_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		if dist > 0.01:
			facing = to_t.angle()
		_emit_attack_started()
		_emit_sfx("bellows_inhale")
		return

	# Maintain mid-range furnace-tending standoff (never closing faster than routine_speed)
	var ideal_r: float = 68.0
	if dist > 0.01 and absf(dist - ideal_r) > 12.0:
		var dir_to: Vector2 = to_t / dist
		var step_dir: Vector2 = dir_to if dist > ideal_r else -dir_to
		var spd: float = routine_speed * 0.82
		_move_step(step_dir * spd * dt, false)


func _step_tell(dt: float) -> void:
	if state_timer > 0.16:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 2.2, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = GUST_COMMIT_TIME
		gust_dir = Vector2.from_angle(facing)
		gust_hit = false
		gust_announced = false
		_emit_sfx("bellows_gust")


func _step_commit(dt: float) -> void:
	if not gust_announced:
		gust_announced = true
		gust_emitted.emit(pos, gust_dir, GUST_RANGE, GUST_HALF_W, self)
		if world_ctx != null and world_ctx.has_method("on_enemy_gust"):
			world_ctx.call("on_enemy_gust", self, pos, gust_dir, GUST_RANGE, GUST_HALF_W)

	var end_p: Vector2 = pos + gust_dir * GUST_RANGE
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		var closest_w: Vector2 = Geometry2D.get_closest_point_to_segment(wp, pos, end_p)
		if closest_w.distance_to(wp) <= GUST_HALF_W:
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
				Lx.player.call("apply_recoil", gust_dir * GUST_PUSH_WICK * dt)
			if not gust_hit and pos.distance_to(wp) <= GUST_DAMAGE_R:
				gust_hit = true
				_emit_player_hit(gust_dir)

	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		var closest_l: Vector2 = Geometry2D.get_closest_point_to_segment(lp, pos, end_p)
		if closest_l.distance_to(lp) <= GUST_HALF_W + 4.0:
			_push_thrown_lantern(dt)

	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _push_thrown_lantern(dt: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if lan_v is Object and is_instance_valid(lan_v as Object):
		var lan: Object = lan_v as Object
		var st_v: Variant = lan.get("state")
		if st_v != null and (int(st_v) == 1 or int(st_v) == 2):
			var cur_v: Variant = lan.get("pos")
			if cur_v is Vector2:
				var pushed: Vector2 = (cur_v as Vector2) + gust_dir * GUST_PUSH_LANTERN * dt
				lan.set("pos", pushed)
				if lan is Node2D:
					(lan as Node2D).global_position = pushed.round()


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 2.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.88 * dt), false)
	if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()


func _sees_target() -> bool:
	var t: Vector2 = _attention_target()
	if not _has_player() and not _is_lantern_out():
		return false
	return pos.distance_to(t) <= notice_radius and _has_clear_view(pos, t)


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
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("bellows_notice")


func _body_color() -> Color:
	return (PAL["wine"] as Color) if bellows_punctured else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Bellows sac swells during TELL inhale
		var sac_r: float = 4.5 if state == State.TELL else (2.0 if bellows_punctured else 3.0)
		var sac_pos: Vector2 = off - Vector2.from_angle(facing) * (body_radius * 0.65)
		draw_circle(sac_pos, sac_r, (PAL["gold"] as Color) if state == State.TELL else (PAL["apricot"] as Color))
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var c: Vector2 = off.round()
		var side: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var g_col: Color = (PAL["gold"] if prog > 0.65 else PAL["apricot"]) as Color
		for si: int in [-1, 1]:
			var s_off: Vector2 = side * (float(si) * GUST_HALF_W)
			draw_line((c + s_off + gust_dir * (body_radius + 2.0)).round(), (c + s_off + gust_dir * GUST_RANGE).round(), g_col, 1.0)
		for ii: int in range(3):
			var lat: float = float(ii - 1) * (GUST_HALF_W * 0.55)
			var u: float = fmod(prog * 2.2 + float(ii) * 0.33, 1.0)
			var d0: float = lerpf(GUST_RANGE * 0.85, body_radius + 6.0, u)
			var d1: float = maxf(body_radius + 3.0, d0 - 11.0)
			draw_line((c + side * lat + gust_dir * d0).round(), (c + side * lat + gust_dir * d1).round(), (PAL["cream"] if ii == 1 else PAL["gold"]) as Color, 1.0)
	elif state == State.COMMIT:
		var prog: float = 1.0 - clampf(state_timer / GUST_COMMIT_TIME, 0.0, 1.0)
		var side: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var reach: float = GUST_RANGE * lerpf(0.55, 0.96, prog)
		var base_p: Vector2 = off.round()
		for idx: int in range(-1, 2):
			var lane_w: float = float(idx) * (GUST_HALF_W * 0.48)
			var p0: Vector2 = (base_p + side * lane_w + gust_dir * (body_radius + 2.0)).round()
			var lane_len: float = reach * (1.0 if idx == 0 else 0.84)
			var p1: Vector2 = (base_p + side * (lane_w * 1.15) + gust_dir * lane_len).round()
			draw_line(p0, p1, PAL["coral"] as Color, 3.0 if idx == 0 else 2.0)
			var mid_c: Color = (PAL["gold"] as Color) if idx == 0 else (PAL["apricot"] as Color)
			draw_line(p0, p0.lerp(p1, 0.92).round(), mid_c, 1.6 if idx == 0 else 1.2)
			if idx == 0:
				draw_line(p0, p0.lerp(p1, 0.72).round(), PAL["cream"] as Color, 1.0)
		for ci: int in range(4):
			var ct: float = fmod(prog * 1.7 + float(ci) * 0.25, 1.0)
			var tip: Vector2 = (base_p + gust_dir * (body_radius + 8.0 + ct * (GUST_RANGE - 16.0))).round()
			var cw: float = lerpf(4.0, GUST_HALF_W * 0.76, ct)
			var back: Vector2 = -gust_dir * lerpf(4.0, 7.5, ct)
			var cc: Color = (PAL["cream"] as Color) if ct < 0.30 else ((PAL["gold"] as Color) if ct < 0.68 else (PAL["apricot"] as Color))
			draw_line(tip, (tip + back + side * cw).round(), cc, 1.2)
			draw_line(tip, (tip + back - side * cw).round(), cc, 1.2)
		for ei: int in range(8):
			var et: float = fmod(prog * 2.1 + float(ei) * 0.137, 1.0)
			var lat: float = sin(float(ei) * 2.4 + anim_t * 18.0) * lerpf(3.0, GUST_HALF_W * 0.85, et)
			var ep: Vector2 = (base_p + gust_dir * (body_radius + 4.0 + et * GUST_RANGE * 0.92) + side * lat).round()
			var mod3: int = ei % 3
			var ec: Color = (PAL["cream"] as Color) if mod3 == 0 else ((PAL["gold"] as Color) if mod3 == 1 else (PAL["coral"] as Color))
			draw_rect(Rect2(ep, Vector2(1.0, 1.0)), ec, true)
			if mod3 == 0:
				draw_rect(Rect2((ep - gust_dir * 2.0).round(), Vector2(1.0, 1.0)), PAL["apricot"] as Color, true)
