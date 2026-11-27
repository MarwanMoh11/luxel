class_name LxThornArcherBrain
extends LxEnemyBrain
## Thorn Archer (Island 3): Shadow-reloading sniper.
## Fires fast splinter-darts (0.46s tell, 0.18s commit, 290 px/s, bent by LxFields).
## Reloads ONLY in darkness — illuminating its perch with the lantern overgrows and
## JAMS its leaf-bow for 1.8 s (visibly blooming with vines & vulnerable to finish)!

const SHOT_RANGE: float = 148.0
const COMMIT_TIME: float = 0.18
const DART_SPEED: float = 290.0
const DART_MAX_AGE: float = 1.4
const JAM_DURATION: float = 1.80
const LIGHT_HOLD_S: float = 0.30
const POST_COOLDOWN: float = 0.85

var perches: Array[Vector2] = []
var perch_i: int = 0
var pause_t: float = 0.0
var illuminated: bool = false
var light_hold_t: float = 0.0
var jammed_t: float = 0.0
var _jam_cd: float = 0.0
var shot_dir: Vector2 = Vector2.RIGHT
var _shot_fired: bool = false
var darts: Array[Dictionary] = []


func _init() -> void:
	kind = "thorn_archer"
	island_id = 3
	max_hp = 2.8
	hp = 2.8
	body_radius = 5.5
	routine_speed = 38.0
	leash_radius = 158.0
	notice_radius = 144.0
	tell_time = 0.46
	recover_time = 1.00
	give_up_time = 1.8
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	perches.clear()
	var raw_pts: Variant = spec.get("perches", spec.get("route", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				perches.append(_clamp_pt(_to_vec2(pt_v, home)))
	if perches.size() < 2:
		var r: float = minf(44.0, leash_radius * 0.40)
		perches = [_clamp_pt(home + Vector2(-r, -12.0)), _clamp_pt(home + Vector2(r, 12.0))]
	perch_i = 0
	pause_t = 0.6
	illuminated = false
	light_hold_t = 0.0
	jammed_t = 0.0
	_jam_cd = 0.0
	shot_dir = Vector2.from_angle(facing)
	_shot_fired = false
	darts.clear()


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
	if rad <= 0.0:
		return
	if orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius:
		light_hold_t = LIGHT_HOLD_S
		illuminated = true
		# Hung lantern beside perch or light during reload overgrows & JAMS the leaf-bow!
		var strong_light: bool = src == "lantern_hung" or state == State.RECOVER or state == State.TELL
		if strong_light and jammed_t <= 0.0 and _jam_cd <= 0.0:
			_trigger_bow_jam()


func _trigger_bow_jam() -> void:
	jammed_t = JAM_DURATION
	_jam_cd = 3.2
	_release_token()
	if state == State.TELL:
		state = State.STAGGER
		state_timer = 0.70
	_emit_sfx("thorn_archer_jam")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"]) or src == LxHit.SOURCE_BEAM
	var rel: Vector2 = orig - pos

	if src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		light_hold_t = maxf(light_hold_t, 0.8)
		illuminated = true
		if jammed_t <= 0.0 and _jam_cd <= 0.0:
			_trigger_bow_jam()

	var is_open: bool = jammed_t > 0.0 or state == State.RECOVER or state == State.STAGGER
	if is_open:
		dmg *= 1.35
	hp -= dmg
	flash_t = 0.14 if (is_open or is_heavy) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 30.0)

	if hp <= 0.001:
		darts.clear()
		opened_kill = is_open
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if is_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	_tick_darts(dt)
	_jam_cd = maxf(0.0, _jam_cd - dt)
	jammed_t = maxf(0.0, jammed_t - dt)
	light_hold_t = maxf(0.0, light_hold_t - dt)
	# Also check direct hung-lantern proximity if world_ctx didn't push on_light
	if _is_lantern_hung() and pos.distance_to(_get_lantern_pos()) <= 64.0:
		light_hold_t = maxf(light_hold_t, 0.15)
		if jammed_t <= 0.0 and _jam_cd <= 0.0 and (state == State.RECOVER or state == State.TELL):
			_trigger_bow_jam()
	illuminated = light_hold_t > 0.0

	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target_pos):
				_enter_notice()
		State.NOTICE:
			_face_point(target_pos, 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.18 * _assist_tell_scale():
				_face_point(target_pos, 3.2, dt)
				shot_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			# Step out of lantern light to reload in shadow!
			if illuminated and _is_lantern_out():
				var away_l: Vector2 = (pos - _get_lantern_pos()).normalized()
				if away_l.length_squared() > 0.01:
					_move_step(away_l * routine_speed * 0.65 * dt, false)
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.50
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.28
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("thorn_archer_notice")


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = perches[perch_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		perch_i = (perch_i + 1) % perches.size()
		pause_t = 0.85
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.78 * dt), false)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.6, dt)
	if not _has_player() or target_pos.distance_to(home) > leash_radius + 16.0:
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var can_act: bool = (director == null or director.can_claim_ranged_token(self)) and jammed_t <= 0.0
	state = State.POSITION if can_act else State.WAIT_TOKEN

	if can_act and cooldown <= 0.0 and dist <= SHOT_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		shot_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = shot_dir.angle()
		_emit_attack_started()
		_emit_sfx("thorn_archer_tell")
		return

	# If illuminated, drift away from lantern toward shadow; otherwise hold mid-range perch
	var move_d: Vector2 = Vector2.ZERO
	if illuminated and _is_lantern_out():
		var away: Vector2 = pos - _get_lantern_pos()
		if away.length_squared() > 1.0:
			move_d = away.normalized()
	elif dist < 56.0 and dist > 0.1:
		move_d = -(to_t / dist)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
		move_d = perp * 0.65
	_move_step(move_d * routine_speed * 0.76 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_shot_fired = false
	_emit_sfx("thorn_archer_fire")


func _step_commit(dt: float) -> void:
	if not _shot_fired:
		_shot_fired = true
		darts.append({
			"pos": pos + shot_dir * 8.0,
			"prev_pos": pos + shot_dir * 8.0,
			"vel": shot_dir * DART_SPEED,
			"age": 0.0,
		})
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time + (0.80 if illuminated else 0.0))
		last_recover_duration = state_timer


func _tick_darts(dt: float) -> void:
	if darts.is_empty():
		return
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(darts.size() - 1, -1, -1):
		var d: Dictionary = darts[i]
		d["age"] = float(d["age"]) + dt
		var p: Vector2 = d["pos"] as Vector2
		d["prev_pos"] = p
		var v: Vector2 = d["vel"] as Vector2
		if LxFields.has_fields():
			v += LxFields.accel_at(p, "bolt") * dt
			if v.length_squared() > 1.0:
				v = v.normalized() * clampf(v.length(), 160.0, 340.0)
		var nxt: Vector2 = p + v * dt
		d["pos"] = nxt
		d["vel"] = v
		var hit_wall: bool = world_ctx != null and world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", nxt)) == "wall"
		if hit_wall or float(d["age"]) >= DART_MAX_AGE:
			darts.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, p, nxt).distance_to(wp) <= 7.0:
			_emit_player_hit(v.normalized())
			darts.remove_at(i)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	return home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt


func _sees_target(target_pos: Vector2) -> bool:
	return _has_player() and pos.distance_to(target_pos) <= notice_radius


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Overgrown vine-bloom jam indicator on bow!
	if jammed_t > 0.0:
		draw_arc(c, body_radius + 3.5, 0.0, TAU, 16, PAL["lime"] as Color, 2.0)
		for k: int in range(4):
			var a: float = anim_t * 2.2 + float(k) * (PI * 0.5)
			var bp: Vector2 = (c + Vector2.from_angle(a) * (body_radius + 4.0)).round()
			draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["rose"] as Color if k % 2 == 0 else PAL["lime"] as Color)
	if state == State.TELL:
		var locked: bool = state_timer <= 0.18 * _assist_tell_scale()
		var tip: Vector2 = (c + shot_dir * 130.0).round()
		var col: Color = (PAL["cream"] if locked else PAL["coral"]) as Color
		draw_line(c, tip, col, 2.0 if locked else 1.0)
		draw_circle((c + shot_dir * 10.0).round(), 2.5, PAL["cream"] as Color)
	for d: Dictionary in darts:
		var p: Vector2 = ((d["pos"] as Vector2) - pos).round()
		var dn: Vector2 = (d["vel"] as Vector2).normalized()
		var tail: Vector2 = (p - dn * 9.0).round()
		draw_line(tail, p, PAL["void"] as Color, 3.0)
		draw_line(tail, p, PAL["coral"] as Color, 2.0)
		draw_line((p - dn * 4.0).round(), p, PAL["cream"] as Color, 1.0)
