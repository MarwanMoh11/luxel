class_name LxRainFrogBrain
extends LxEnemyBrain
## Rain Frog (Island 4): weather-swelling puddle spitter.
## Swells in RAIN to spit LxFields-bent puddle-bombs (24 px puddle snuffs unroofed
## timed_braziers & slows/damages; swept away by WIND!). Shrinks timidly under SUN or
## Beam (1.5x dmg taken, cannot spit for 3.5 s). Nudges nearby weather_wheel back to RAIN.

const SPIT_RANGE: float = 122.0
const SPIT_COMMIT_S: float = 0.30
const SPIT_SPEED: float = 148.0
const PUDDLE_RADIUS: float = 24.0
const PUDDLE_LIFE_S: float = 2.60
const SHRINK_BEAM_S: float = 3.50
const POST_COOLDOWN: float = 1.10

var _pads: Array[Vector2] = []
var _pad_i: int = 0
var _pause_t: float = 0.5
var _shrunk_t: float = 0.0
var _spit_target: Vector2 = Vector2.ZERO
var _spit_fired: bool = false
var _wheel_cd: float = 4.0

# Active spit globs (obey LxFields!) and ground puddles
var _globs: Array[Dictionary] = []   # [{pos, vel, target, z, t, dur}]
var _puddles: Array[Dictionary] = [] # [{pos, age, life, hit_cd}]


func _init() -> void:
	kind = "rain_frog"
	island_id = 4
	max_hp = 3.0
	hp = 3.0
	body_radius = 6.0
	routine_speed = 40.0
	leash_radius = 158.0
	notice_radius = 136.0
	tell_time = 0.50
	recover_time = 1.05
	give_up_time = 1.9
	shard_drop = 4


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_pads.clear()
	var raw_pts: Variant = spec.get("perches", spec.get("route", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				_pads.append(_clamp_pt(_to_vec2(pt_v, home)))
	if _pads.size() < 2:
		var r: float = minf(42.0, leash_radius * 0.35)
		_pads = [_clamp_pt(home + Vector2(-r, 0.0)), _clamp_pt(home + Vector2(r, 0.0))]
	_pad_i = 0
	_pause_t = 0.45
	_shrunk_t = 0.0
	_spit_target = pos
	_spit_fired = false
	_wheel_cd = 5.0
	_globs.clear()
	_puddles.clear()


func is_shrunk() -> bool:
	return _shrunk_t > 0.0 or _read_weather() == "sun"


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])

	var was_shrunk: bool = is_shrunk()
	if src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_shrunk_t = SHRINK_BEAM_S
		_emit_sfx("rain_frog_shrink")

	if was_shrunk:
		dmg *= 1.50
	elif src == LxHit.SOURCE_BEAM:
		# First Beam shrinks the swollen toad (leaving a crisp follow-up finish so players see it shrink!)
		dmg = minf(dmg, maxf(0.5, hp - 0.6))
	hp -= dmg
	var shrunk: bool = is_shrunk()
	flash_t = 0.15 if (shrunk or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 40.0)
	if hp <= 0.001:
		opened_kill = shrunk or state == State.RECOVER or state == State.STAGGER
		_die(hit)
		return HitResult.KILLED
	if is_heavy or src == LxHit.SOURCE_BEAM:
		_release_token()
		state = State.STAGGER
		state_timer = 0.60
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.28
		alert_t = 0.75
	_emit_enemy_hit(hit, HitResult.OPENED if shrunk else HitResult.CHIPPED)
	return HitResult.OPENED if shrunk else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_shrunk_t = maxf(0.0, _shrunk_t - dt)
	_wheel_cd = maxf(0.0, _wheel_cd - dt)
	_tick_globs(dt)
	_tick_puddles(dt)

	var shrunk: bool = is_shrunk()
	_sprite_scale = Vector2(0.78, 0.78) if shrunk else (Vector2(1.16, 1.12) if _read_weather() == "rain" else Vector2.ONE)

	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_player() and pos.distance_to(target_pos) <= notice_radius:
				state = State.NOTICE
				state_timer = 0.30
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("rain_frog_swell")
		State.NOTICE:
			_face_point(target_pos, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos, shrunk)
		State.TELL:
			if shrunk:
				_release_token()
				state = State.POSITION
				return
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.2, dt)
				_spit_target = target_pos
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
			if to_h.length() <= 3.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	if _pause_t > 0.0:
		_pause_t -= dt
		return
	var wp: Vector2 = _pads[_pad_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		_pad_i = (_pad_i + 1) % _pads.size()
		_pause_t = 0.75
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.80 * dt), false)


func _step_position(dt: float, target_pos: Vector2, shrunk: bool) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.4, dt)

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

	# If shrunk in SUN, timidly hop away and try to nudge a nearby weather_wheel back to RAIN
	if shrunk:
		if _try_nudge_weather_wheel(dt):
			return
		if dist < 96.0 and dist > 0.01:
			_move_step(-to_t.normalized() * (routine_speed * 0.85) * dt, false)
		return

	if is_lead and cooldown <= 0.0 and dist <= SPIT_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_spit_target = target_pos
		_emit_attack_started()
		_emit_sfx("rain_frog_swell")
		return

	var spd: float = routine_speed * 0.82
	if dist > SPIT_RANGE * 0.82:
		_move_step(to_t.normalized() * spd * dt, false)
	elif dist < 44.0 and dist > 0.01:
		_move_step(-to_t.normalized() * spd * 0.72 * dt, false)


func _try_nudge_weather_wheel(dt: float) -> bool:
	if _wheel_cd > 0.0 or world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "weather_wheel":
			var wh: LxInteractable = it_v as LxInteractable
			var to_w: Vector2 = wh.pos - pos
			if to_w.length() <= 14.0:
				if wh.has_method("set_weather"):
					wh.call("set_weather", "rain", true)
				elif Lx.vars != null:
					Lx.vars.set_var("dungeon:rain_mausoleum", "weather", "rain")
				_wheel_cd = 9.0
				_emit_sfx("rain_frog_swell")
				return true
			if to_w.length() <= 120.0:
				facing = to_w.angle()
				_move_step(to_w.normalized() * (routine_speed * 0.85) * dt, false)
				return true
	return false


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = SPIT_COMMIT_S
	_spit_fired = false


func _step_commit(dt: float) -> void:
	if not _spit_fired:
		_spit_fired = true
		var to_s: Vector2 = _spit_target - pos
		var dist: float = clampf(to_s.length(), 24.0, SPIT_RANGE)
		var dir: Vector2 = to_s.normalized() if to_s.length() > 0.01 else Vector2.from_angle(facing)
		var dur: float = clampf(dist / SPIT_SPEED, 0.24, 0.72)
		_globs.append({
			"pos": pos + dir * 6.0,
			"vel": dir * (dist / dur),
			"z": 4.0,
			"t": 0.0,
			"dur": dur,
		})
		_emit_sfx("rain_frog_spit")
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_globs(dt: float) -> void:
	var i: int = _globs.size() - 1
	while i >= 0:
		var g: Dictionary = _globs[i]
		var gp: Vector2 = g["pos"] as Vector2
		var gv: Vector2 = g["vel"] as Vector2
		# LxFields (wind zones / gravity) bend the puddle-bomb in flight!
		gv += LxFields.accel_at(gp, "bolt") * dt
		gp += gv * dt
		var t: float = float(g["t"]) + dt
		var dur: float = float(g["dur"])
		g["pos"] = gp
		g["vel"] = gv
		g["t"] = t
		g["z"] = sin(clampf(t / maxf(dur, 0.05), 0.0, 1.0) * PI) * 18.0
		if t >= dur:
			_spawn_puddle(gp)
			_globs.remove_at(i)
		i -= 1


func _spawn_puddle(at_p: Vector2) -> void:
	_puddles.append({"pos": at_p, "age": 0.0, "life": PUDDLE_LIFE_S, "hit_cd": 0.0})
	if _puddles.size() > 3:
		_puddles.pop_front()
	_emit_sfx("mist_eel_flop")
	# Direct landing splash damage (telegraphed by SPIT TELL!)
	if _has_player() and _get_wick_pos().distance_to(at_p) <= PUDDLE_RADIUS:
		_emit_player_hit((_get_wick_pos() - at_p).normalized())
	# Snuff any unroofed timed_brazier inside puddle radius!
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "timed_brazier":
				var br: LxInteractable = it_v as LxInteractable
				if br.pos.distance_to(at_p) <= PUDDLE_RADIUS + br.radius and not bool(br.props.get("roofed", false)):
					if br.has_method("reset_toy"):
						br.call("reset_toy")


func _tick_puddles(dt: float) -> void:
	var weather: String = _read_weather()
	var i: int = _puddles.size() - 1
	while i >= 0:
		var pd: Dictionary = _puddles[i]
		var pp: Vector2 = pd["pos"] as Vector2
		# WIND or LxFields sweeps puddles rapidly aside!
		var fa: Vector2 = LxFields.accel_at(pp, "bolt")
		if fa.length_squared() > 4.0:
			pp += fa.normalized() * 68.0 * dt
			pd["pos"] = pp
			pd["age"] = float(pd["age"]) + dt * 1.8
		elif weather == "wind":
			pd["age"] = float(pd["age"]) + dt * 2.2
		else:
			pd["age"] = float(pd["age"]) + dt
		pd["hit_cd"] = maxf(0.0, float(pd["hit_cd"]) - dt)
		if float(pd["hit_cd"]) <= 0.0 and _has_player() and _get_wick_pos().distance_to(pp) <= PUDDLE_RADIUS * 0.78:
			pd["hit_cd"] = 0.85
			_emit_player_hit((_get_wick_pos() - pp).normalized())
		if float(pd["age"]) >= float(pd["life"]):
			_puddles.remove_at(i)
		i -= 1


func _die(hit: Object) -> void:
	_globs.clear()
	_puddles.clear()
	super._die(hit)


func _read_weather() -> String:
	if Lx.vars != null:
		var reg_id: String = str(world_ctx.get("region_id")) if (world_ctx != null and is_instance_valid(world_ctx) and world_ctx.get("region_id") != null) else ""
		var w: String = str(Lx.vars.resolve_var("weather", island_id, reg_id, ""))
		if w.is_empty():
			w = str(Lx.vars.get_var("dungeon:rain_mausoleum", "weather", ""))
		if not w.is_empty():
			return w.to_lower()
	return ""


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _body_color() -> Color:
	return (PAL["lime"] if is_shrunk() else PAL["teal"]) as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Draw active puddles
	for pd: Dictionary in _puddles:
		var pp: Vector2 = ((pd["pos"] as Vector2) - pos).round()
		var fade: float = 1.0 - clampf(float(pd["age"]) / maxf(float(pd["life"]), 0.1), 0.0, 1.0)
		draw_circle(pp, PUDDLE_RADIUS * 0.88, Color(PAL["blue"] as Color, 0.35 * fade))
		draw_arc(pp, PUDDLE_RADIUS, 0.0, TAU, 20, Color(PAL["sky"] as Color, 0.85 * fade), 1.4)
		draw_arc(pp, PUDDLE_RADIUS * 0.55, 0.0, TAU, 14, Color(PAL["ice"] as Color, 0.65 * fade), 1.0)
	# Draw flying spit globs
	for g: Dictionary in _globs:
		var gp: Vector2 = ((g["pos"] as Vector2) - pos).round()
		var gz: float = float(g["z"])
		draw_circle(gp, 3.0, Color(PAL["void"] as Color, 0.35))
		draw_circle(gp + Vector2(0.0, -gz), 4.0, PAL["sky"] as Color)
		draw_circle(gp + Vector2(-1.0, -gz - 1.0), 1.6, PAL["cream"] as Color)

	if state == State.TELL:
		var rel: Vector2 = (_spit_target - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var col: Color = (PAL["coral"] if prog > 0.68 else PAL["sky"]) as Color
		draw_arc(rel, PUDDLE_RADIUS, 0.0, TAU, 18, col, 1.3)
		draw_arc(rel, lerpf(PUDDLE_RADIUS, 4.0, prog), 0.0, TAU, 14, PAL["ice"] as Color, 1.0)
		draw_line(c, rel, Color(PAL["sky"] as Color, 0.55), 1.0)
