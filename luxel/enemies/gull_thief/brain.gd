class_name LxGullThiefBrain
extends LxEnemyBrain
## Gull Thief (Island 2): circles the pier, marks a hung lantern (attack + light tokens),
## dives to snatch it and carries it slowly (38 px/s) toward water/far perch.
## Unlike Magpie, bolts DO hurt Gull Thief (including while carrying).

enum SubState { CIRCLE, TELL, DIVE, HOIST, CARRY, BAFFLED, STAGGER }

const ORBIT_R: float = 42.0
const ORBIT_SPEED: float = 46.0
const DIVE_SPEED: float = 138.0
const DIVE_MAX_TIME: float = 1.85
const GRAB_R: float = 8.0
const HOIST_TIME: float = 0.65
const CARRY_SPEED: float = 38.0
const BAFFLED_TIME: float = 0.85
const STAGGER_TIME: float = 0.55
const AGAIN_CD: float = 1.25
const ALT_CIRCLE: float = 14.0
const ALT_CARRY: float = 10.0

var sub_state: int = SubState.CIRCLE
var perches: Array[Vector2] = []
var orbit_angle: float = 0.0
var orbit_spin: float = 1.0
var altitude: float = ALT_CIRCLE
var dive_target: Vector2 = Vector2.ZERO
var carry_goal: Vector2 = Vector2.ZERO
var carrying_lantern: bool = false

func _init() -> void:
	kind = "gull_thief"
	island_id = 2
	max_hp = 1.5
	hp = 1.5
	body_radius = 4.5
	routine_speed = 54.0
	leash_radius = 160.0
	notice_radius = 165.0
	tell_time = 0.45
	recover_time = HOIST_TIME
	give_up_time = 1.8
	shard_drop = 2

func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	perches.clear()
	var raw_p: Variant = spec.get("perches", [])
	if raw_p is Array:
		for pt_v: Variant in (raw_p as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				perches.append(_clamp_pt(_to_vec2(pt_v, home)))
	if perches.is_empty():
		var r: float = minf(84.0, leash_radius * 0.72)
		perches = [_clamp_pt(home + Vector2(-r, -r * 0.35)), _clamp_pt(home + Vector2(r, -r * 0.35)), _clamp_pt(home + Vector2(0.0, r * 0.55))]
	orbit_angle = _randf_range(-PI, PI)
	orbit_spin = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	sub_state = SubState.CIRCLE
	state = State.ROUTINE
	altitude = ALT_CIRCLE
	carrying_lantern = false
	carry_goal = home
	dive_target = home
	if Lx.events != null:
		if not Lx.events.lantern_recalled.is_connected(_on_lantern_recalled):
			Lx.events.lantern_recalled.connect(_on_lantern_recalled)
		if not Lx.events.lantern_caught.is_connected(_on_lantern_recalled):
			Lx.events.lantern_caught.connect(_on_lantern_recalled)

func is_flying() -> bool:
	return true

func wants_token() -> bool:
	return sub_state == SubState.CIRCLE and cooldown <= 0.0 and _is_lantern_hung()

func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var was_carrying: bool = carrying_lantern
	var is_opening: bool = was_carrying or sub_state == SubState.HOIST \
			or sub_state == SubState.BAFFLED or sub_state == SubState.DIVE
	hp -= dmg
	flash_t = 0.14 if (is_heavy or was_carrying) else 0.09
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 65.0)
	if was_carrying:
		_drop_carried_lantern()
	_release_all_claims()
	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED
	if is_heavy or was_carrying or sub_state == SubState.DIVE or sub_state == SubState.HOIST:
		sub_state = SubState.STAGGER
		state = State.STAGGER
		state_timer = STAGGER_TIME if is_heavy else 0.38
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED

func _step_brain(dt: float) -> void:
	match sub_state:
		SubState.CIRCLE:
			state = State.ROUTINE
			altitude = move_toward(altitude, ALT_CIRCLE, 42.0 * dt)
			_step_circle(dt)
			_try_mark_lantern()
		SubState.TELL:
			state = State.TELL
			altitude = move_toward(altitude, ALT_CIRCLE + 2.0, 32.0 * dt)
			var lan_p: Vector2 = _get_lantern_pos()
			if (lan_p - pos).length() > 0.01:
				facing = (lan_p - pos).angle()
			state_timer -= dt
			if not _is_lantern_hung():
				_enter_baffled()
			elif state_timer <= 0.0:
				sub_state = SubState.DIVE
				state = State.COMMIT
				state_timer = DIVE_MAX_TIME
				dive_target = _clamp_pt(lan_p)
				_emit_sfx("gull_dive")
		SubState.DIVE:
			state = State.COMMIT
			altitude = move_toward(altitude, 2.0, 75.0 * dt)
			state_timer -= dt
			var arrived: bool = _fly_to(dive_target, DIVE_SPEED, dt)
			var lan_p: Vector2 = _get_lantern_pos()
			if _is_lantern_hung() and pos.distance_to(lan_p) <= GRAB_R:
				_begin_hoist()
			elif arrived or state_timer <= 0.0:
				_enter_baffled()
		SubState.HOIST:
			state = State.RECOVER
			altitude = move_toward(altitude, ALT_CARRY, 26.0 * dt)
			state_timer -= dt
			if not carrying_lantern:
				_enter_baffled()
			elif state_timer <= 0.0:
				sub_state = SubState.CARRY
				state = State.RETURN
				carry_goal = _farthest_perch()
		SubState.CARRY:
			state = State.RETURN
			altitude = move_toward(altitude, ALT_CARRY, 32.0 * dt)
			var ls: int = _get_lantern_state()
			if not carrying_lantern or (ls != 4 and ls != 2 and ls != 0):
				carrying_lantern = false
				_enter_baffled()
			elif _fly_to(carry_goal, CARRY_SPEED, dt):
				pos = carry_goal
				carrying_lantern = false
				_release_all_claims()
				if Lx.events != null:
					Lx.events.lantern_perched_loss.emit(pos)
				_emit_sfx("gull_water_loss")
				sub_state = SubState.CIRCLE
				state = State.ROUTINE
				cooldown = AGAIN_CD * 1.6
		SubState.BAFFLED:
			state = State.RECOVER
			altitude = move_toward(altitude, ALT_CIRCLE, 36.0 * dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_release_all_claims()
				sub_state = SubState.CIRCLE
				state = State.ROUTINE
		SubState.STAGGER:
			state = State.STAGGER
			altitude = move_toward(altitude, 4.0, 60.0 * dt)
			state_timer -= dt
			if state_timer <= 0.0:
				cooldown = AGAIN_CD
				sub_state = SubState.CIRCLE
				state = State.ROUTINE

func _step_circle(dt: float) -> void:
	orbit_angle = wrapf(orbit_angle + orbit_spin * (ORBIT_SPEED / maxf(ORBIT_R, 12.0)) * dt, -PI, PI)
	var desired: Vector2 = home + Vector2(cos(orbit_angle) * ORBIT_R, sin(orbit_angle) * ORBIT_R * 0.68)
	var step_v: Vector2 = (desired - pos).limit_length(minf(ORBIT_SPEED, routine_speed * 0.90) * dt)
	if step_v.length() > 0.01:
		facing = step_v.angle()
		_move_step(step_v, true)

func _try_mark_lantern() -> bool:
	if cooldown > 0.0 or not _is_lantern_hung() or not _is_on_screen():
		return false
	var lan_p: Vector2 = _get_lantern_pos()
	if pos.distance_to(lan_p) > notice_radius or lan_p.distance_to(home) > leash_radius:
		return false
	if director != null:
		if not director.can_claim_token(self) or not director.claim_light(self):
			return false
		if not director.claim_token(self):
			director.release_light(self)
			return false
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(tell_time, false, 1.0)
	state_timer = last_tell_duration
	dive_target = _clamp_pt(lan_p)
	_emit_attack_started()
	_emit_sfx("gull_mark")
	return true

func _begin_hoist() -> void:
	carrying_lantern = true
	_release_token() # Free combat token; light_claimer stays held during hoist & carry.
	sub_state = SubState.HOIST
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, HOIST_TIME)
	last_recover_duration = state_timer
	if Lx.events != null:
		Lx.events.lantern_stolen.emit(self, pos)
	_emit_sfx("gull_snatch")

func _enter_baffled() -> void:
	_release_all_claims()
	carrying_lantern = false
	sub_state = SubState.BAFFLED
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, BAFFLED_TIME)
	last_recover_duration = state_timer
	cooldown = AGAIN_CD

func _drop_carried_lantern() -> void:
	if not carrying_lantern:
		return
	carrying_lantern = false
	if Lx.events != null:
		Lx.events.lantern_dropped.emit(pos)

func _release_all_claims() -> void:
	_release_token()
	if director != null:
		director.release_light(self)

func _on_lantern_recalled(_at: Vector2) -> void:
	if carrying_lantern:
		carrying_lantern = false
		_enter_baffled()

func _farthest_perch() -> Vector2:
	var best: Vector2 = perches[0]
	var best_d: float = -1.0
	var wick_p: Vector2 = _get_wick_pos()
	for p: Vector2 in perches:
		var d: float = p.distance_to(pos) + p.distance_to(wick_p) * 0.5
		if d > best_d:
			best_d = d
			best = p
	return best

func _fly_to(dest: Vector2, spd: float, dt: float) -> bool:
	var d: Vector2 = dest - pos
	if d.length() <= 2.0:
		return true
	facing = d.angle()
	_move_step(d.limit_length(spd * dt), true)
	return pos.distance_to(dest) <= 2.0

func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 1.0)
	return (home + (pt - home).normalized() * cap) if pt.distance_to(home) > cap else pt

func _visual_offset() -> Vector2:
	return Vector2(0.0, -altitude)

func _body_color() -> Color:
	return PAL["ice"] as Color

func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		var flap: float = sin(anim_t * (14.0 if carrying_lantern else 9.0)) * 4.0
		var fwd: Vector2 = Vector2.from_angle(facing)
		var side: Vector2 = Vector2(-fwd.y, fwd.x)
		draw_line(off, off + side * 8.0 + Vector2(0.0, flap), PAL["sky"] as Color, 2.0)
		draw_line(off, off - side * 8.0 + Vector2(0.0, flap), PAL["sky"] as Color, 2.0)
		draw_line(off + fwd * 3.0, off + fwd * 8.0, PAL["apricot"] as Color, 1.5)
	if state == State.TELL:
		var rel: Vector2 = dive_target - pos
		draw_line(off, rel, PAL["gold"] as Color, 1.0)
		draw_arc(rel, 5.0, 0.0, TAU, 12, PAL["coral"] as Color, 1.5)
	elif carrying_lantern:
		draw_circle(off + Vector2(0.0, 6.0), 3.0, PAL["gold"] as Color)
		draw_circle(off + Vector2(0.0, 6.0), 1.5, PAL["cream"] as Color)
