class_name LxMeteorCarrierBrain
extends LxEnemyBrain
## Meteor Carrier (Island 5, Starfall Observatory).
## Heavy brass scarab hauling a live gravity-curving meteor boulder on its back.
## Hurls curving boulders via LxFields. Shooting its glowing boulder during TELL
## detonates it early on its own back, staggering the Carrier and blasting nearby foes!

const NOTICE_TIME: float = 0.28
const COMMIT_TIME: float = 0.35
const BOULDER_SPEED: float = 172.0
const BOULDER_RADIUS: float = 6.5
const BOULDER_MAX_AGE: float = 1.45
const DETONATE_AOE_R: float = 46.0
const DETONATE_SELF_DMG: float = 1.6
const DETONATE_FF_DMG: float = 1.5
const DETONATE_STAGGER_S: float = 1.10
const HEAVY_STAGGER_S: float = 0.70

var _route: Array[Vector2] = []
var _route_i: int = 0
var _throw_dir: Vector2 = Vector2.RIGHT
var _boulder_thrown: bool = false
var _boulders: Array[Dictionary] = []
var _preview_pts: PackedVector2Array = PackedVector2Array()
var _boom_fx_t: float = 0.0


func _init() -> void:
	kind = "meteor_carrier"
	max_hp = 4.5
	hp = 4.5
	body_radius = 7.5
	routine_speed = 26.0
	leash_radius = 148.0
	notice_radius = 130.0
	tell_time = 0.68
	recover_time = 1.20
	give_up_time = 2.2
	shard_drop = 6
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_route.clear()
	var raw: Variant = spec.get("route", [])
	if raw is Array:
		for pt_v: Variant in (raw as Array):
			_route.append(_to_vec2(pt_v, home))
	if _route.size() < 2:
		_route.append(home + Vector2(-24.0, 0.0))
		_route.append(home + Vector2(24.0, 0.0))
	_route_i = 0
	_throw_dir = Vector2.from_angle(facing)
	_boulder_thrown = false
	_boulders.clear()
	_preview_pts = PackedVector2Array()
	_boom_fx_t = 0.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	# Signature counterplay: shooting the hefted glowing boulder during TELL detonates it early!
	if state == State.TELL:
		_boom_fx_t = 0.32
		dmg += DETONATE_SELF_DMG
		hp -= dmg
		flash_t = 0.16
		_blast_nearby_foes()
		LxDamageFx.boss_impact(pos, 0.16, 66.0, 74.0, 70.0, 1.35, 0.28)
		_emit_sfx("i5_meteor_hit")
		if hp <= 0.001:
			opened_kill = true
			_boulders.clear()
			_die(hit)
			return HitResult.KILLED
		_release_token()
		state = State.STAGGER
		state_timer = DETONATE_STAGGER_S
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	var is_open: bool = state == State.RECOVER or state == State.STAGGER
	if is_open or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_THROW:
		dmg *= 1.15
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (68.0 if is_heavy else 14.0)

	if hp <= 0.001:
		opened_kill = is_open
		_boulders.clear()
		_die(hit)
		return HitResult.KILLED

	if is_heavy or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else HEAVY_STAGGER_S
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _blast_nearby_foes() -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_enemies"):
		return
	for ev: Variant in (world_ctx.call("get_enemies") as Array):
		if ev is LxEnemyBrain and ev != self and is_instance_valid(ev):
			var other: LxEnemyBrain = ev as LxEnemyBrain
			if other.is_alive() and other.pos.distance_to(pos) <= DETONATE_AOE_R + other.body_radius:
				var d: Vector2 = (other.pos - pos).normalized() if other.pos.distance_to(pos) > 0.1 else Vector2.RIGHT
				var ff := LxHit.make(LxHit.SOURCE_HAZARD, DETONATE_FF_DMG, d, pos, 2.0, true, true, self, true)
				other.take_hit(ff)


func _step_brain(dt: float) -> void:
	_boom_fx_t = maxf(0.0, _boom_fx_t - dt)
	_tick_boulders(dt)
	match state:
		State.ROUTINE:
			_step_patrol(dt)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 3.6, dt)
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
				cooldown = 0.95
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
				cooldown = 0.65
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

	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	var dist: float = to_t.length()
	if dist > 1.0:
		_turn_toward(to_t.angle(), 3.2, dt)
		if dist > 86.0:
			_move_step((to_t / dist) * (routine_speed * 0.85) * dt, false)
		elif dist < 44.0:
			_move_step((-to_t / dist) * (routine_speed * 0.65) * dt, false)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius and _claim_token():
		_throw_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _throw_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_update_preview()
		_emit_attack_started()
		_emit_sfx("golem_stomp_tell")


func _step_tell(dt: float) -> void:
	if state_timer > last_tell_duration * 0.45:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 2.2, dt)
			_throw_dir = Vector2.from_angle(facing)
		_update_preview()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = COMMIT_TIME
		_boulder_thrown = false
		_emit_sfx("i5_meteor_hit")


func _step_commit(dt: float) -> void:
	if not _boulder_thrown:
		_boulder_thrown = true
		_boulders.append({
			"pos": pos + _throw_dir * (body_radius + 4.0),
			"prev": pos + _throw_dir * (body_radius + 4.0),
			"vel": _throw_dir * BOULDER_SPEED,
			"age": 0.0,
			"curve_deg": 0.0,
		})
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_boulders(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(_boulders.size() - 1, -1, -1):
		var b: Dictionary = _boulders[i]
		b["age"] = float(b["age"]) + dt
		var p0: Vector2 = b["pos"] as Vector2
		var v: Vector2 = b["vel"] as Vector2
		var old_dir: Vector2 = v.normalized()
		b["prev"] = p0
		var fa: Vector2 = LxFields.accel_at(p0, "block")
		if fa.length_squared() > 0.01:
			v += fa * 1.45 * dt
			if v.length_squared() > 1.0:
				v = v.normalized() * BOULDER_SPEED
				b["curve_deg"] = float(b["curve_deg"]) + rad_to_deg(absf(old_dir.angle_to(v.normalized())))
		var p1: Vector2 = p0 + v * dt
		b["pos"] = p1; b["vel"] = v
		if float(b["age"]) >= BOULDER_MAX_AGE or not _has_clear_view(p0, p1):
			_boulders.remove_at(i)
			continue
		# Polarity-curved enemy boulders can smash OTHER enemies (bible meteor_r10!)
		if float(b["curve_deg"]) >= 30.0 and world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_enemies"):
			var hit_other: bool = false
			for ev: Variant in (world_ctx.call("get_enemies") as Array):
				if ev is LxEnemyBrain and ev != self and is_instance_valid(ev):
					var other: LxEnemyBrain = ev as LxEnemyBrain
					if other.is_alive() and other.pos.distance_to(p1) <= BOULDER_RADIUS + other.body_radius:
						var ff := LxHit.make(LxHit.SOURCE_HAZARD, 2.5, v.normalized(), p0, 2.0, true, true, self, true, LxHit.COLOR_YELLOW, float(b["curve_deg"]))
						other.take_hit(ff)
						hit_other = true
						break
			if hit_other:
				_emit_sfx("i5_meteor_hit")
				_boulders.remove_at(i)
				continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, p0, p1).distance_to(wp) <= BOULDER_RADIUS + 4.0:
			_emit_player_hit(v.normalized())
			_boulders.remove_at(i)


func _step_patrol(dt: float) -> void:
	if _route.size() < 2:
		return
	var wp: Vector2 = _route[_route_i]
	if pos.distance_to(wp) <= 3.0:
		_route_i = (_route_i + 1) % _route.size()
		return
	var d: Vector2 = wp - pos
	facing = d.angle()
	_move_step(d.limit_length(routine_speed * 0.85 * dt), false)


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home; state = State.ROUTINE; lost_t = 0.0; return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _update_preview() -> void:
	var res: Dictionary = LxFields.sample_curve(pos + _throw_dir * (body_radius + 4.0), _throw_dir, BOULDER_SPEED, "block", 124.0, 8.0, world_ctx)
	_preview_pts = res.get("points", PackedVector2Array()) as PackedVector2Array


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _has_attention_target() -> bool:
	return _has_player() or _is_lured()


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.72
	lost_t = 0.0
	_emit_sfx("golem_stomp_tell")


func _body_color() -> Color:
	return PAL["dusk"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _boom_fx_t > 0.0:
		var u: float = 1.0 - clampf(_boom_fx_t / 0.32, 0.0, 1.0)
		draw_arc(c, lerpf(10.0, DETONATE_AOE_R, u), 0.0, TAU, 24, PAL["coral"] as Color, 2.0)
		draw_arc(c, lerpf(6.0, DETONATE_AOE_R * 0.75, u), 0.0, TAU, 18, PAL["gold"] as Color, 1.2)

	if state == State.TELL and _preview_pts.size() >= 2:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var lc: Color = (PAL["coral"] if prog > 0.62 else PAL["apricot"]) as Color
		for k: int in range(_preview_pts.size() - 1):
			var a: Vector2 = (_preview_pts[k] - pos + off).round()
			var b: Vector2 = (_preview_pts[k + 1] - pos + off).round()
			draw_line(a, b, lc, 2.0 if prog > 0.62 else 1.2)
		# Glowing shoot-me cue ring on the hefted boulder during TELL!
		draw_arc(c + Vector2(0.0, -14.0), 8.5, 0.0, TAU, 16, PAL["gold"] as Color, 1.4)

	for b: Dictionary in _boulders:
		var lp: Vector2 = ((b["pos"] as Vector2) - pos + off).round()
		var bv: Vector2 = (b["vel"] as Vector2).normalized()
		draw_line((lp - bv * 9.0).round(), lp, PAL["wine"] as Color, 4.5)
		draw_line((lp - bv * 7.0).round(), lp, PAL["coral"] as Color, 2.5)
		draw_circle(lp, BOULDER_RADIUS, PAL["night"] as Color)
		draw_circle(lp, BOULDER_RADIUS - 1.2, PAL["coral"] as Color)
		draw_circle(lp + Vector2(-1.0, -1.0), 2.5, PAL["gold"] as Color)
		draw_rect(Rect2(lp + Vector2(-1.0, -1.0), Vector2.ONE), PAL["cream"] as Color)
