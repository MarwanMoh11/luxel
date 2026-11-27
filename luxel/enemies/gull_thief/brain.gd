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
const CARRY_MAX_TIME: float = 6.0
const BAFFLED_TIME: float = 0.85
const STAGGER_TIME: float = 0.55
const AGAIN_CD: float = 1.25
const SWOOP_CD: float = 3.2
const SWOOP_TELL: float = 0.45
const SWOOP_COMMIT_TIME: float = 0.52
const SWOOP_HIT_R: float = 12.0
const SWOOP_RECOVER_TIME: float = 0.72
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
var attack_cd: float = 1.6
var swoop_mode: bool = false
var swoop_hit: bool = false
var glint_t: float = 0.0

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
	attack_cd = 1.6
	swoop_mode = false
	swoop_hit = false
	glint_t = 0.0
	if Lx.events != null:
		if not Lx.events.lantern_recalled.is_connected(_on_lantern_recalled):
			Lx.events.lantern_recalled.connect(_on_lantern_recalled)
		if not Lx.events.lantern_caught.is_connected(_on_lantern_recalled):
			Lx.events.lantern_caught.connect(_on_lantern_recalled)

func is_flying() -> bool:
	return true

func wants_token() -> bool:
	if sub_state != SubState.CIRCLE or cooldown > 0.0:
		return false
	if _is_lantern_hung():
		return true
	return attack_cd <= 0.0 and _has_player() and _get_wick_pos().distance_to(home) <= leash_radius

func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])

	# While circling/perched, glint-dodges straight yellow bolts; blue-transformed bolts / Dash / Recall stagger & open it!
	if sub_state == SubState.CIRCLE and src == LxHit.SOURCE_BOLT and not is_blue_hit \
			and not is_heavy and not pierce and not cracks:
		glint_t = 0.28
		var dodge_rel: Vector2 = pos - orig
		var perp: Vector2 = (dodge_rel.normalized() if dodge_rel.length() > 0.01 else Vector2.from_angle(facing)).rotated(PI * 0.5 * orbit_spin)
		_move_step(perp * 10.0, true)
		_emit_sfx("gull_dodge")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	var was_carrying: bool = carrying_lantern
	var is_opening: bool = was_carrying or is_blue_hit or sub_state == SubState.HOIST \
			or sub_state == SubState.BAFFLED or sub_state == SubState.DIVE or sub_state == SubState.STAGGER
	if is_blue_hit:
		dmg *= 1.25
	hp -= dmg
	flash_t = 0.14 if (is_heavy or was_carrying or is_blue_hit) else 0.09
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 65.0)
	if was_carrying:
		_drop_carried_lantern()
	swoop_mode = false
	_release_all_claims()
	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED
	if is_heavy or is_blue_hit or src == LxHit.SOURCE_DASH or src == LxHit.SOURCE_RECALL \
			or was_carrying or sub_state == SubState.DIVE or sub_state == SubState.HOIST:
		sub_state = SubState.STAGGER
		state = State.STAGGER
		state_timer = STAGGER_TIME if (is_heavy or is_blue_hit) else 0.38
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED

func _step_brain(dt: float) -> void:
	attack_cd = maxf(0.0, attack_cd - dt)
	glint_t = maxf(0.0, glint_t - dt)
	match sub_state:
		SubState.CIRCLE:
			state = State.ROUTINE
			altitude = move_toward(altitude, ALT_CIRCLE, 42.0 * dt)
			_step_circle(dt)
			if not _try_mark_lantern():
				_try_start_swoop()
		SubState.TELL:
			state = State.TELL
			altitude = move_toward(altitude, ALT_CIRCLE + 2.0, 32.0 * dt)
			state_timer -= dt
			if swoop_mode:
				if state_timer > 0.16 * _assist_tell_scale() and _has_player():
					dive_target = _clamp_pt(_get_wick_pos())
				var to_w: Vector2 = dive_target - pos
				if to_w.length() > 0.01:
					facing = to_w.angle()
				if state_timer <= 0.0:
					sub_state = SubState.DIVE
					state = State.COMMIT
					state_timer = SWOOP_COMMIT_TIME
					swoop_hit = false
					_emit_sfx("gull_dive")
			else:
				var lan_p: Vector2 = _get_lantern_pos()
				if (lan_p - pos).length() > 0.01:
					facing = (lan_p - pos).angle()
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
			altitude = move_toward(altitude, 2.0, 85.0 * dt)
			state_timer -= dt
			var arrived: bool = _fly_to(dive_target, DIVE_SPEED, dt)
			if swoop_mode:
				if not swoop_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= SWOOP_HIT_R:
					swoop_hit = true
					var sdir: Vector2 = (dive_target - pos).normalized() if dive_target.distance_to(pos) > 0.01 else Vector2.from_angle(facing)
					_emit_player_hit(sdir)
				if arrived or state_timer <= 0.0:
					swoop_mode = false
					attack_cd = SWOOP_CD
					_enter_baffled(SWOOP_RECOVER_TIME)
			else:
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
				state_timer = CARRY_MAX_TIME
				carry_goal = _farthest_perch()
		SubState.CARRY:
			state = State.RETURN
			state_timer -= dt
			altitude = move_toward(altitude, ALT_CARRY, 32.0 * dt)
			var ls: int = _get_lantern_state()
			if not carrying_lantern or (ls != 4 and ls != 2 and ls != 0):
				carrying_lantern = false
				_enter_baffled()
			elif _fly_to(carry_goal, CARRY_SPEED, dt) or state_timer <= 0.0:
				if pos.distance_to(carry_goal) <= 2.5:
					pos = carry_goal
				carrying_lantern = false
				_release_all_claims()
				var lan_c: LxLantern = _carried_wick_lantern()
				if lan_c != null:
					lan_c.on_perched_loss()
				elif Lx.events != null:
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
	swoop_mode = false
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(tell_time, false, 1.0)
	state_timer = last_tell_duration
	dive_target = _clamp_pt(lan_p)
	_emit_attack_started()
	_emit_sfx("gull_mark")
	return true

func _try_start_swoop() -> bool:
	if attack_cd > 0.0 or cooldown > 0.0 or _is_lantern_hung() or not _has_player() or not _is_on_screen():
		return false
	var wp: Vector2 = _get_wick_pos()
	if pos.distance_to(wp) > notice_radius or wp.distance_to(home) > leash_radius:
		return false
	if not _claim_token():
		return false
	swoop_mode = true
	swoop_hit = false
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(SWOOP_TELL, false, attack_damage)
	state_timer = last_tell_duration
	dive_target = _clamp_pt(wp)
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
	var lan: LxLantern = _wick_lantern()
	if lan != null and lan.is_lure_active():
		lan.on_grabbed(self)
	elif Lx.events != null:
		Lx.events.lantern_stolen.emit(self, pos)
	_emit_sfx("gull_snatch")

func _enter_baffled(dur: float = BAFFLED_TIME) -> void:
	_release_all_claims()
	carrying_lantern = false
	swoop_mode = false
	sub_state = SubState.BAFFLED
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, dur)
	last_recover_duration = state_timer
	cooldown = AGAIN_CD

func _wick_lantern() -> LxLantern:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var lan: LxLantern = (Lx.player as LxWick).lantern
		if lan != null and is_instance_valid(lan):
			return lan
	return null

func _carried_wick_lantern() -> LxLantern:
	var lan: LxLantern = _wick_lantern()
	if lan != null and lan.state == LxLantern.State.CARRIED and lan.carrier == self:
		return lan
	return null

func _drop_carried_lantern() -> void:
	if not carrying_lantern:
		return
	carrying_lantern = false
	var lan_c: LxLantern = _carried_wick_lantern()
	if lan_c != null:
		lan_c.on_dropped(pos)
	elif Lx.events != null:
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
	var c := Vector2(roundf(off.x), roundf(off.y))
	var fwd: Vector2 = Vector2.from_angle(facing)
	var side := Vector2(-fwd.y, fwd.x)
	if _sprite_sheet == null:
		var flap: float = sin(anim_t * (14.0 if carrying_lantern else 9.0)) * 4.0
		draw_line(off, off + side * 8.0 + Vector2(0.0, flap), PAL["sky"] as Color, 2.0)
		draw_line(off, off - side * 8.0 + Vector2(0.0, flap), PAL["sky"] as Color, 2.0)
		draw_line(off + fwd * 3.0, off + fwd * 8.0, PAL["apricot"] as Color, 1.5)
	if glint_t > 0.0:
		var gr: float = body_radius + 3.0 + (1.0 - clampf(glint_t / 0.28, 0.0, 1.0)) * 4.0
		draw_arc(c, gr, 0.0, TAU, 12, PAL["ice"] as Color, 1.2)
		draw_line(c + Vector2(-4.0, 0.0), c + Vector2(4.0, 0.0), PAL["cream"] as Color, 1.0)
		draw_line(c + Vector2(0.0, -4.0), c + Vector2(0.0, 4.0), PAL["cream"] as Color, 1.0)
	if state == State.TELL:
		var rel := Vector2(roundf(dive_target.x - pos.x), roundf(dive_target.y - pos.y))
		var delta: Vector2 = rel - c
		var dist: float = delta.length()
		if dist > 4.0:
			var dir: Vector2 = delta / dist
			var shift: float = fmod(anim_t * 22.0, 6.0)
			var steps: int = mini(26, int(dist / 6.0))
			for di: int in range(steps):
				var d0: float = float(di) * 6.0 + shift
				if d0 >= dist - 4.0:
					break
				var p0 := Vector2(roundf(c.x + dir.x * d0), roundf(c.y + dir.y * d0))
				var p1 := Vector2(roundf(c.x + dir.x * minf(d0 + 2.0, dist - 3.0)), roundf(c.y + dir.y * minf(d0 + 2.0, dist - 3.0)))
				draw_line(p0, p1, (PAL["gold"] as Color) if (di % 2 == 0) else (PAL["coral"] as Color), 1.0)
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var rad: float = roundf(lerpf(6.5, 3.5, prog))
		for ci: int in range(4):
			var cd: Vector2 = Vector2.from_angle(float(ci) * (PI * 0.5))
			var tp := Vector2(roundf(rel.x + cd.x * rad), roundf(rel.y + cd.y * rad))
			var ti := Vector2(roundf(rel.x + cd.x * maxf(1.5, rad - 2.5)), roundf(rel.y + cd.y * maxf(1.5, rad - 2.5)))
			draw_line(ti, tp, PAL["coral"] as Color, 1.2)
			draw_rect(Rect2(tp, Vector2(1.0, 1.0)), PAL["gold"] as Color, true)
		draw_rect(Rect2(rel, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT:
		for si: int in range(-1, 2, 2):
			var s: float = float(si)
			var w0 := Vector2(roundf(c.x + side.x * (s * 5.5) - fwd.x * 1.5), roundf(c.y + side.y * (s * 5.5) - fwd.y * 1.5))
			var w1 := Vector2(roundf(c.x + side.x * (s * 7.5) - fwd.x * 14.0), roundf(c.y + side.y * (s * 7.5) - fwd.y * 14.0))
			draw_line(w0, w1, PAL["sky"] as Color, 1.5)
			draw_line(w0, Vector2(roundf(c.x + side.x * (s * 6.5) - fwd.x * 9.0), roundf(c.y + side.y * (s * 6.5) - fwd.y * 9.0)), PAL["ice"] as Color, 1.0)
			draw_rect(Rect2(w1, Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
	if carrying_lantern:
		var sway: float = roundf(sin(anim_t * 11.0) * 1.5)
		var lx: float = c.x + sway
		var ly: float = c.y + 6.0
		draw_rect(Rect2(lx - 1.0, ly - 4.0, 3.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 3.0, ly - 3.0, 7.0, 7.0), PAL["void"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 2.0, 5.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly + 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 1.0, ly - 1.0, 3.0, 3.0), PAL["gold"] as Color, true)
		var flick: float = 0.0 if (LxHudFx.flash_reduced() or int(anim_t * 14.0) % 2 == 0) else -1.0
		draw_rect(Rect2(lx, ly + flick, 1.0, 2.0), PAL["cream"] as Color, true)
		for mi: int in range(2):
			var mp: float = fmod(anim_t * 2.5 + float(mi) * 0.5, 1.0)
			draw_rect(Rect2(roundf(lx - fwd.x * (4.0 + mp * 6.0)), roundf(ly - fwd.y * (4.0 + mp * 6.0) - mp * 2.0), 1.0, 1.0), PAL["gold"] as Color, true)
