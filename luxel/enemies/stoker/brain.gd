class_name LxStokerBrain
extends LxEnemyBrain
## Stoker (Island 6, Ashen Kiln — Area Pressure / Catalyst).
## Furnace hand that shovels glowing 3-coal arcs (obeying LxFields) leaving 2.5s ember puddles,
## re-heating cooled Slag Slimes and accelerating room conveyors.
## Counterplay: hitting mid-tell scatters shovel (1.1s stagger), hung lantern lures it to stoke,
## piercing/Lance/Beam cuts through its forge apron.

const FLING_RANGE: float = 118.0
const COMMIT_TIME: float = 0.25
const COAL_SPEED: float = 152.0
const COAL_ARC_DEG: float = 30.0
const PUDDLE_RADIUS: float = 14.0
const PUDDLE_TTL: float = 2.5
const NOTICE_TIME: float = 0.30
const TELL_SCATTER_STAGGER: float = 1.10

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var aim_dir: Vector2 = Vector2.RIGHT
var flung: bool = false
var _coals: Array[Dictionary] = []
var _puddles: Array[Dictionary] = []


func _init() -> void:
	kind = "stoker"
	island_id = 6
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 36.0
	leash_radius = 148.0
	notice_radius = 124.0
	tell_time = 0.52
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pt_v: Variant in (raw_r as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				route.append(pt)
	route_i = 0
	pause_t = 0.0
	aim_dir = Vector2.from_angle(facing)
	flung = false
	_coals.clear()
	_puddles.clear()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var pierce: bool = bool(h["pierce"]) or bool(h["cracks_armour"])
	var orig: Vector2 = h["origin"] as Vector2
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var mid_tell: bool = state == State.TELL
	if mid_tell:
		dmg *= 1.35
	elif pierce:
		dmg *= 1.25
	elif state == State.RECOVER or state == State.STAGGER:
		dmg *= 1.20

	var is_opening: bool = mid_tell or pierce or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if (mid_tell or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if (mid_tell or is_heavy) else 38.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_coals.clear()
		_puddles.clear()
		_die(hit)
		return HitResult.KILLED

	if mid_tell:
		_release_token()
		state = State.STAGGER
		state_timer = TELL_SCATTER_STAGGER
		_emit_sfx("shield_shatter")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_tick_coals_and_puddles(dt)
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
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.78 * dt), false)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 2.5:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.75
		return
	var to_wp: Vector2 = wp - pos
	_turn_toward(to_wp.angle(), 3.6, dt)
	_move_step(to_wp.limit_length(routine_speed * 0.82 * dt), false)


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
		_turn_toward(to_t.angle(), 3.8, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= FLING_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		if dist > 0.01:
			facing = to_t.angle()
		aim_dir = Vector2.from_angle(facing)
		flung = false
		_emit_attack_started()
		_emit_sfx("furnace_draw")
		return

	var ideal_r: float = 64.0
	if dist > 0.01 and absf(dist - ideal_r) > 10.0:
		var dir_to: Vector2 = to_t / dist
		var step_dir: Vector2 = dir_to if dist > ideal_r else -dir_to
		_move_step(step_dir * (routine_speed * 0.82) * dt, false)


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 * _assist_tell_scale():
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 2.4, dt)
	aim_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = COMMIT_TIME
		flung = false
		_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	if not flung:
		flung = true
		_spawn_coal_arc()
		_stoke_room_toys()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _spawn_coal_arc() -> void:
	for deg: float in [-COAL_ARC_DEG, 0.0, COAL_ARC_DEG]:
		var d: Vector2 = aim_dir.rotated(deg_to_rad(deg)).normalized()
		_coals.append({
			"pos": pos + d * (body_radius + 3.0),
			"vel": d * COAL_SPEED,
			"ttl": 0.48,
			"max_ttl": 0.48,
		})


func _stoke_room_toys() -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	if world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is Object and is_instance_valid(it_v as Object):
				var it: Object = it_v as Object
				if str(it.get("kind")) == "conveyor" and it.has_method("boost_speed"):
					it.call("boost_speed", 1.35, 3.0)


func _tick_coals_and_puddles(dt: float) -> void:
	var has_p: bool = _has_player()
	var wp: Vector2 = _get_wick_pos()
	var gliding: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).is_gliding()

	for i: int in range(_coals.size() - 1, -1, -1):
		var c: Dictionary = _coals[i]
		var cp: Vector2 = c["pos"] as Vector2
		var cv: Vector2 = c["vel"] as Vector2
		if LxFields.has_fields():
			var fa: Vector2 = LxFields.accel_at(cp, "bolt")
			if fa.length_squared() > 0.01:
				cv = (cv + fa * dt).limit_length(COAL_SPEED * 1.45)
		var nxt: Vector2 = cp + cv * dt
		c["pos"] = nxt
		c["vel"] = cv
		c["ttl"] = float(c["ttl"]) - dt

		var hit_w: bool = has_p and nxt.distance_to(wp) <= 8.0
		if hit_w:
			_emit_player_hit(cv.normalized(), attack_damage)
			_coals.remove_at(i)
			continue
		var blocked: bool = not _has_clear_view(cp, nxt)
		if blocked or float(c["ttl"]) <= 0.0:
			_land_coal(nxt)
			_coals.remove_at(i)

	for j: int in range(_puddles.size() - 1, -1, -1):
		var pd: Dictionary = _puddles[j]
		pd["ttl"] = float(pd["ttl"]) - dt
		pd["cd"] = maxf(0.0, float(pd["cd"]) - dt)
		var pp: Vector2 = pd["pos"] as Vector2
		if has_p and not gliding and float(pd["cd"]) <= 0.0 and wp.distance_to(pp) <= PUDDLE_RADIUS:
			pd["cd"] = 0.85
			var push: Vector2 = (wp - pp).normalized() if wp.distance_to(pp) > 0.1 else Vector2.DOWN
			_emit_player_hit(push, attack_damage)
		if float(pd["ttl"]) <= 0.0:
			_puddles.remove_at(j)


func _land_coal(at_p: Vector2) -> void:
	_puddles.append({"pos": at_p, "ttl": PUDDLE_TTL, "cd": 0.12})
	_emit_sfx("magma_crack")
	# Re-heat any cooled slag_slime hit by stoker coals!
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx != null and is_instance_valid(ctx) and ctx.has_method("get_enemies"):
			for e_v: Variant in (ctx.call("get_enemies") as Array):
				if e_v is Object and is_instance_valid(e_v as Object) and e_v != self and (e_v as Object).has_method("reheat"):
					var ep: Vector2 = (e_v as Object).get("pos") as Vector2
					if ep.distance_to(at_p) <= PUDDLE_RADIUS + 10.0:
						(e_v as Object).call("reheat")
			break


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 2.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
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
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("warden_alert")


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var fred: bool = LxHudFx.flash_reduced()
	# Draw lingering ember puddles in local space
	for pd: Dictionary in _puddles:
		var lp: Vector2 = ((pd["pos"] as Vector2) - pos + off).round()
		var frac: float = clampf(float(pd["ttl"]) / PUDDLE_TTL, 0.0, 1.0)
		draw_circle(lp, PUDDLE_RADIUS, Color(PAL["coral"] as Color, 0.30 * frac))
		var rim_c: Color = PAL["apricot"] as Color if (fred or int(anim_t * 9.0) % 2 == 0) else (PAL["gold"] as Color)
		draw_arc(lp, PUDDLE_RADIUS, 0.0, TAU, 18, Color(rim_c, 0.80 * frac), 1.2)
	# Draw flying glowing coals
	for c: Dictionary in _coals:
		var cp: Vector2 = ((c["pos"] as Vector2) - pos + off).round()
		var arc_z: float = sin(clampf(float(c["ttl"]) / float(c["max_ttl"]), 0.0, 1.0) * PI) * 8.0
		draw_circle(cp, 2.5, Color(PAL["void"] as Color, 0.38))
		draw_circle(cp + Vector2(0.0, -arc_z), 3.0, PAL["coral"] as Color)
		draw_circle(cp + Vector2(0.0, -arc_z), 1.6, PAL["gold"] as Color)
		draw_rect(Rect2(cp + Vector2(-0.5, -arc_z - 0.5), Vector2.ONE), PAL["cream"] as Color)
	# 3-lane shovel arc telegraph during TELL
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var lcol: Color = (PAL["cream"] if prog > 0.72 else PAL["gold"]) as Color
		for deg: float in [-COAL_ARC_DEG, 0.0, COAL_ARC_DEG]:
			var d: Vector2 = aim_dir.rotated(deg_to_rad(deg)).normalized()
			draw_line((off + d * (body_radius + 3.0)).round(), (off + d * (66.0 * (0.45 + 0.55 * prog))).round(), lcol, 1.2)
