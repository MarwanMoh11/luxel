class_name LxPistonKnightBrain
extends LxEnemyBrain
## Piston Knight (Island 6, Ashen Kiln — Heavy Armored Vanguard).
## Frontal boiler-plate resists normal hits to 25% until cracked by Lance/Sunflare or heavy wear.
## Vents steam (0.56s tell), commits a 225 px/s pneumatic thrust (64px) that jams its lance into
## the floor on recovery (1.35s) exposing its glowing CORAL REAR EXHAUST VALVE (2x dmg + 1.3s stagger!).

const ARMOUR_MAX_DEFAULT: float = 3.0
const ARMOUR_RES_MULT: float = 0.25
const THRUST_TRIGGER_R: float = 82.0
const THRUST_SPEED: float = 225.0
const THRUST_TIME: float = 0.28
const THRUST_HIT_R: float = 16.0
const GUARD_HOME_CAP: float = 72.0

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var armour_intact: bool = true
var armour_max: float = ARMOUR_MAX_DEFAULT
var armour_hp: float = ARMOUR_MAX_DEFAULT
var thrust_dir: Vector2 = Vector2.RIGHT
var thrust_hit: bool = false
var jammed_wall: bool = false


func _init() -> void:
	kind = "piston_knight"
	island_id = 6
	max_hp = 5.0
	hp = 5.0
	body_radius = 7.5
	routine_speed = 28.0
	leash_radius = 144.0
	notice_radius = 120.0
	tell_time = 0.56
	recover_time = 1.35
	give_up_time = 1.5
	shard_drop = 6
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
	armour_max = maxf(1.0, float(spec.get("armour_hp", ARMOUR_MAX_DEFAULT)))
	armour_hp = armour_max
	armour_intact = true
	thrust_dir = Vector2.from_angle(facing)
	thrust_hit = false
	jammed_wall = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var cracks: bool = bool(h["cracks_armour"])
	var pierce: bool = bool(h["pierce"])
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = orig - pos

	# Rear exhaust valve check! (Skip wall-bank / flank behind facing!)
	var fwd: Vector2 = Vector2.from_angle(facing)
	var from_dir: Vector2 = rel.normalized() if rel.length() > 0.01 else (-h["dir"] as Vector2)
	var hit_rear_valve: bool = from_dir.dot(fwd) < -0.25

	var just_cracked: bool = false
	if hit_rear_valve:
		dmg *= 2.0
		_emit_sfx("piston_hiss")
	elif armour_intact:
		if cracks:
			_crack_armour()
			just_cracked = true
		elif pierce:
			armour_hp -= maxf(wear, 2.0)
			if armour_hp <= 0.001:
				_crack_armour()
				just_cracked = true
		else:
			clank_t = 0.14
			dmg *= ARMOUR_RES_MULT
			var a_wear: float = wear if (is_heavy or wear >= 1.5) else wear * 0.30
			armour_hp -= a_wear
			if armour_hp <= 0.001:
				_crack_armour()
				just_cracked = true
			else:
				_emit_sfx("shield_clang")

	var is_opening: bool = hit_rear_valve or (not armour_intact) or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.16 if (hit_rear_valve or just_cracked or is_heavy) else 0.08
	if rel.length() > 0.01:
		var k_spd: float = 85.0 if (hit_rear_valve or not armour_intact) else 18.0
		knock = -rel.normalized() * k_spd

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if hit_rear_valve or just_cracked:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else 1.30
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy and not armour_intact:
		_release_token()
		state = State.STAGGER
		state_timer = 0.60
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _crack_armour() -> void:
	armour_intact = false
	armour_hp = 0.0
	LxDamageFx.boss_impact(pos, 0.14, 62.0, 68.0, 66.0, 1.32, 0.30)
	_emit_sfx("magma_crack")


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["armour_intact"] = armour_intact
	d["armour_hp"] = armour_hp
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
				_turn_toward(to_t.angle(), 3.4, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			if state_timer > 0.18 * _assist_tell_scale():
				var to_t: Vector2 = _attention_target() - pos
				if to_t.length() > 0.01:
					_turn_toward(to_t.angle(), 2.0, dt)
			thrust_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = THRUST_TIME
				thrust_hit = false
				jammed_wall = false
				_emit_sfx("warden_swing")
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			# Facing stays LOCKED while lance is jammed so Wick can flank rear valve!
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
				if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
					_enter_notice()


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.80 * dt), false)
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
	_turn_toward(to_wp.angle(), 2.8, dt)
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
		_turn_toward(to_t.angle(), 2.8, dt)

	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN
	if is_lead and cooldown <= 0.0 and dist <= THRUST_TRIGGER_R and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		if dist > 0.01:
			facing = to_t.angle()
		thrust_dir = Vector2.from_angle(facing)
		_emit_attack_started()
		_emit_sfx("piston_hiss")
		return

	var dest: Vector2 = target - (to_t / maxf(dist, 0.01)) * 32.0
	var cap: float = minf(GUARD_HOME_CAP, maxf(0.0, leash_radius - 2.0))
	if dest.distance_to(home) > cap:
		dest = home + (dest - home).normalized() * cap
	if dest.distance_to(pos) > 3.0:
		_move_step((dest - pos).limit_length(routine_speed * 0.86 * dt), false)


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var before: Vector2 = pos
	var want: Vector2 = thrust_dir * THRUST_SPEED * dt
	_move_step(want, false)
	var moved: float = pos.distance_to(before)
	if moved < want.length() * 0.35 and state_timer < THRUST_TIME * 0.8:
		jammed_wall = true
		state_timer = 0.0
		_emit_sfx("shield_clang")

	if not thrust_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= THRUST_HIT_R:
		thrust_hit = true
		_emit_player_hit(thrust_dir, attack_damage)

	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time + (0.25 if jammed_wall else 0.0))
		last_recover_duration = state_timer


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
	state_timer = 0.30
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("warden_alert")


func _body_color() -> Color:
	return (PAL["stone"] as Color) if armour_intact else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 2.0, 1.5, armour_hp, armour_max)
	# Rear coral exhaust valve glint
	var rear_p: Vector2 = (off - Vector2.from_angle(facing) * (body_radius + 1.0)).round()
	draw_circle(rear_p, 2.2, PAL["coral"] as Color)
	if state == State.RECOVER or state == State.TELL:
		draw_circle(rear_p, 1.2, PAL["gold"] as Color)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var end_p: Vector2 = (off + thrust_dir * 64.0).round()
		var side := Vector2(-thrust_dir.y, thrust_dir.x) * 8.0
		var col: Color = (PAL["cream"] if prog > 0.72 else PAL["coral"]) as Color
		draw_line((off + side).round(), (end_p + side).round(), PAL["void"] as Color, 3.0)
		draw_line((off - side).round(), (end_p - side).round(), PAL["void"] as Color, 3.0)
		draw_line((off + side).round(), (end_p + side).round(), col, 1.0)
		draw_line((off - side).round(), (end_p - side).round(), col, 1.0)
		var fill_end: Vector2 = off.lerp(end_p, prog).round()
		draw_line(off.round(), fill_end, PAL["void"] as Color, 4.0)
		draw_line(off.round(), fill_end, PAL["gold"] as Color, 2.0)
