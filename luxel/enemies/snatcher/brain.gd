class_name LxSnatcherBrain
extends LxEnemyBrain
## Magpie Snatcher brain at full Act I parity.
## Wants the hung lantern, shies from Wick, swallows bolts for 0 damage,
## catches a lantern thrown straight at it, and shares single light claim + attack director.

signal bolt_swallowed(source: LxEnemyBrain, at_pos: Vector2)

enum SubState { PERCH, SHIFT, SHY, TELL, RUN, GRAB, CARRY, BAFFLED, STAGGER }

const WALK_SPEED: float = 44.0
const SHY_R_DEFAULT: float = 50.0
const SHY_SPEED_DEFAULT: float = 128.0
const SIGHT_R: float = 172.0
const TELL_DEFAULT: float = 0.50
const RUN_SPEED_DEFAULT: float = 105.0
const RUN_MAX_TIME: float = 2.4
const GRAB_TIME_DEFAULT: float = 0.72
const GRAB_R: float = 6.5
const CARRY_SPEED_DEFAULT: float = 36.0
const CARRY_AWAY: float = 44.0
const BAFFLED_TIME: float = 1.05
const STAGGER_TIME: float = 0.65
const KNOCK_SPEED: float = 160.0
const AGAIN_CD: float = 1.15
const PERCH_MIN: float = 2.5
const PERCH_MAX: float = 4.2
const MOVE_MAX: float = 4.0
const GULP_TIME: float = 0.28

var sub_state: int = SubState.PERCH
var perches: Array[Vector2] = []
var perch_i: int = 0
var goal: Vector2 = Vector2.ZERO
var run_from: Vector2 = Vector2.ZERO
var run_to: Vector2 = Vector2.ZERO
var carrying_lantern: bool = false
var gulp_t: float = 0.0
var gulp_count: int = 0

var shy_r: float = SHY_R_DEFAULT
var shy_speed: float = SHY_SPEED_DEFAULT
var run_speed: float = RUN_SPEED_DEFAULT
var grab_time: float = GRAB_TIME_DEFAULT
var carry_speed: float = CARRY_SPEED_DEFAULT


func _init() -> void:
	kind = "snatcher"
	max_hp = 1.25
	hp = 1.25
	body_radius = 3.5
	routine_speed = WALK_SPEED
	leash_radius = 160.0
	notice_radius = SIGHT_R
	tell_time = TELL_DEFAULT
	recover_time = GRAB_TIME_DEFAULT
	shard_drop = 2


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	shy_r = float(spec.get("shy_r", SHY_R_DEFAULT))
	shy_speed = float(spec.get("shy_speed", SHY_SPEED_DEFAULT))
	run_speed = float(spec.get("run_speed", RUN_SPEED_DEFAULT))
	grab_time = maxf(MIN_RECOVER_TIME, float(spec.get("grab_time", GRAB_TIME_DEFAULT)))
	carry_speed = minf(routine_speed, float(spec.get("carry_speed", CARRY_SPEED_DEFAULT)))

	perches.clear()
	var raw_p: Variant = spec.get("perches", [])
	if raw_p is Array:
		for pt_v: Variant in (raw_p as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				perches.append(_clamp_point(_to_vec2(pt_v, home)))
	if perches.is_empty():
		var r_p: float = minf(68.0, leash_radius * 0.65)
		perches.append(_clamp_point(home + Vector2(-r_p, -r_p * 0.45)))
		perches.append(_clamp_point(home + Vector2(r_p, -r_p * 0.45)))
		perches.append(_clamp_point(home + Vector2(0.0, r_p * 0.55)))

	perch_i = 0
	pos = perches[0]
	goal = pos
	sub_state = SubState.PERCH
	state = State.ROUTINE
	state_timer = _randf_range(PERCH_MIN, PERCH_MAX)
	carrying_lantern = false
	gulp_t = 0.0
	gulp_count = 0
	var to_h: Vector2 = home - pos
	facing = to_h.angle() if to_h.length() > 0.01 else PI
	_clamp_to_leash()

	if Lx.events != null:
		if not Lx.events.lantern_recalled.is_connected(_on_lantern_recalled):
			Lx.events.lantern_recalled.connect(_on_lantern_recalled)
		if not Lx.events.lantern_caught.is_connected(_on_lantern_recalled):
			Lx.events.lantern_caught.connect(_on_lantern_recalled)


func is_flying() -> bool:
	return true


func wants_token() -> bool:
	return false


func catch_lantern() -> bool:
	if state == State.DEAD or state == State.STAGGER or carrying_lantern:
		return false
	if director != null and not director.claim_light(self):
		return false
	_take_lantern()
	return true


func try_catch_lantern(lantern_obj: Object = null) -> bool:
	if state == State.DEAD or state == State.STAGGER or carrying_lantern:
		return false
	if director != null and not director.claim_light(self):
		return false
	carrying_lantern = true
	_release_token()
	goal = _nearest_perch(CARRY_AWAY)
	sub_state = SubState.CARRY
	state = State.RETURN
	if lantern_obj != null and is_instance_valid(lantern_obj) and lantern_obj.has_method("on_grabbed"):
		lantern_obj.call("on_grabbed", self)
	elif Lx.events != null:
		Lx.events.lantern_stolen.emit(self, pos)
	_emit_sfx("snatcher_grab")
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2

	# Swallows bolts for 0 damage with flash & cue
	if src == "bolt" or src == "prism_bolt":
		gulp_t = GULP_TIME
		gulp_count += 1
		flash_t = 0.08
		bolt_swallowed.emit(self, pos)
		_emit_sfx("snatcher_gulp")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	# Caught if lantern thrown straight at it
	if src == "throw":
		if catch_lantern():
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED

	if state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = sub_state == SubState.GRAB or sub_state == SubState.CARRY \
			or sub_state == SubState.BAFFLED or sub_state == SubState.STAGGER
	var rel: Vector2 = orig - pos
	hp -= dmg
	flash_t = 0.15
	if rel.length() > 0.01:
		knock = -rel.normalized() * KNOCK_SPEED

	_drop_carried_lantern()
	_release_all_claims()

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	sub_state = SubState.STAGGER
	state = State.STAGGER
	state_timer = STAGGER_TIME
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _step_brain(dt: float) -> void:
	gulp_t = maxf(0.0, gulp_t - dt)
	match sub_state:
		SubState.PERCH:
			state = State.ROUTINE
			state_timer -= dt
			if _try_spot_lantern() or _try_shy():
				return
			if state_timer <= 0.0 and perches.size() > 1:
				perch_i = (perch_i + 1) % perches.size()
				_go_to(perches[perch_i], SubState.SHIFT, State.ROUTINE)
		SubState.SHIFT, SubState.SHY:
			if _try_spot_lantern() or (sub_state == SubState.SHIFT and _try_shy()):
				return
			var wick_p: Vector2 = _get_wick_pos()
			if sub_state == SubState.SHY and _has_player() and pos.distance_to(wick_p) < shy_r * 0.6 \
					and Geometry2D.get_closest_point_to_segment(wick_p, pos, goal).distance_to(wick_p) < 20.0:
				goal = _far_perch()
				perch_i = maxi(0, perches.find(goal))
			state_timer -= dt
			var spd: float = WALK_SPEED if sub_state == SubState.SHIFT else _safe_shy_speed(goal)
			if _walk_to(goal, spd, dt) or state_timer <= 0.0:
				if pos.distance_to(goal) <= 2.5:
					pos = goal
				sub_state = SubState.PERCH
				state = State.ROUTINE
				state_timer = _randf_range(PERCH_MIN, PERCH_MAX)
				_try_shy()
		SubState.TELL:
			state = State.TELL
			var lan_p: Vector2 = _get_lantern_pos()
			var to_l: Vector2 = lan_p - pos
			if to_l.length() > 0.01:
				facing = to_l.angle()
			state_timer -= dt
			if not _is_lantern_hung():
				_enter_baffled()
			elif state_timer <= 0.0:
				sub_state = SubState.RUN
				state = State.COMMIT
				state_timer = RUN_MAX_TIME
				run_from = pos
				run_to = _clamp_point(lan_p)
				_emit_sfx("snatcher_dive")
		SubState.RUN:
			state = State.COMMIT
			state_timer -= dt
			var arrived: bool = _walk_to(run_to, run_speed, dt)
			var lan_p: Vector2 = _get_lantern_pos()
			if _is_lantern_hung() and pos.distance_to(lan_p) <= GRAB_R:
				sub_state = SubState.GRAB
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, grab_time)
				last_recover_duration = state_timer
			elif arrived or state_timer <= 0.0:
				_enter_baffled()
		SubState.GRAB:
			state = State.RECOVER
			state_timer -= dt
			var lan_p: Vector2 = _get_lantern_pos()
			if not _is_lantern_hung() or pos.distance_to(lan_p) > GRAB_R + 2.5:
				_enter_baffled()
			elif state_timer <= 0.0:
				_take_lantern()
		SubState.CARRY:
			state = State.RETURN
			var ls: int = _get_lantern_state()
			if not carrying_lantern or (ls != 4 and ls != 2 and ls != 0):
				carrying_lantern = false
				_enter_baffled()
			elif _walk_to(goal, carry_speed, dt):
				pos = goal
				carrying_lantern = false
				_release_all_claims()
				if Lx.events != null:
					Lx.events.lantern_perched_loss.emit(pos)
				_emit_sfx("snatcher_perch_loss")
				sub_state = SubState.PERCH
				state = State.ROUTINE
				state_timer = _randf_range(PERCH_MIN, PERCH_MAX)
				cooldown = AGAIN_CD * 2.0
		SubState.BAFFLED:
			state = State.RECOVER
			state_timer -= dt
			if state_timer <= 0.0:
				_release_all_claims()
				_go_to(_nearest_perch(0.0), SubState.SHIFT, State.ROUTINE)
				_try_shy()
		SubState.STAGGER:
			state = State.STAGGER
			state_timer -= dt
			if state_timer <= 0.0:
				cooldown = AGAIN_CD
				_go_to(_far_perch(), SubState.SHY, State.POSITION)


func _try_spot_lantern() -> bool:
	if cooldown > 0.0 or not _is_lantern_hung() or not _is_on_screen():
		return false
	var lan_p: Vector2 = _get_lantern_pos()
	if pos.distance_to(lan_p) > notice_radius or lan_p.distance_to(home) > leash_radius:
		return false
	if director != null:
		if not director.can_claim_token(self):
			return false
		if not director.claim_light(self):
			return false
		if not director.claim_token(self):
			director.release_light(self)
			return false
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(tell_time, false, 1.0)
	state_timer = last_tell_duration
	_emit_attack_started()
	_emit_sfx("snatcher_tell")
	return true


func _try_shy() -> bool:
	if not _has_player():
		return false
	if pos.distance_to(_get_wick_pos()) >= shy_r:
		return false
	_go_to(_far_perch(), SubState.SHY, State.POSITION)
	_emit_sfx("snatcher_shy")
	return true


func _take_lantern() -> void:
	carrying_lantern = true
	_release_token() # Free combat token while carrying; light_claimer stays held.
	goal = _nearest_perch(CARRY_AWAY)
	sub_state = SubState.CARRY
	state = State.RETURN
	if Lx.events != null:
		Lx.events.lantern_stolen.emit(self, pos)
	_emit_sfx("snatcher_grab")


func _enter_baffled() -> void:
	_release_all_claims()
	carrying_lantern = false
	sub_state = SubState.BAFFLED
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, BAFFLED_TIME)
	last_recover_duration = state_timer
	cooldown = AGAIN_CD
	_emit_sfx("snatcher_baffled")


func _go_to(dest: Vector2, sub: int, st: int) -> void:
	goal = _clamp_point(dest)
	sub_state = sub
	state = st
	state_timer = MOVE_MAX
	perch_i = maxi(0, perches.find(goal))


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


func _safe_shy_speed(dest: Vector2) -> float:
	if not _has_player():
		return WALK_SPEED
	var to_dest: Vector2 = dest - pos
	var to_wick: Vector2 = _get_wick_pos() - pos
	if to_dest.length() > 0.01 and to_wick.length() > 0.01:
		# Ensure SHY never closes on Wick faster than routine_speed
		if to_dest.normalized().dot(to_wick.normalized()) > 0.05:
			return routine_speed * 0.85
	return shy_speed


func _far_perch() -> Vector2:
	var best: Vector2 = perches[0]
	var best_score: float = -1.0
	var wick_p: Vector2 = _get_wick_pos()
	for p: Vector2 in perches:
		if p.distance_to(pos) <= 4.0:
			continue
		var pass_by: float = Geometry2D.get_closest_point_to_segment(wick_p, pos, p).distance_to(wick_p)
		var score: float = pass_by * 4.0 + p.distance_to(wick_p)
		if score > best_score:
			best_score = score
			best = p
	return best


func _nearest_perch(min_away: float) -> Vector2:
	var best: Vector2 = perches[0]
	var best_d: float = INF
	var far: Vector2 = perches[0]
	var far_d: float = -1.0
	for p: Vector2 in perches:
		var d: float = p.distance_to(pos)
		if d >= min_away and d < best_d:
			best_d = d
			best = p
		if d > far_d:
			far_d = d
			far = p
	return best if best_d < INF else far


func _walk_to(dest: Vector2, spd: float, dt: float) -> bool:
	var d: Vector2 = dest - pos
	if d.length() <= 1.5:
		return true
	facing = d.angle()
	_move_step(d.limit_length(spd * dt), true)
	return pos.distance_to(dest) <= 1.5


func _clamp_point(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 1.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _body_color() -> Color:
	if gulp_t > 0.0:
		return PAL["gold"] as Color
	return PAL["blue"] as Color


func _draw_extra(off: Vector2) -> void:
	var c := Vector2(roundf(off.x), roundf(off.y))
	if carrying_lantern:
		var sway: float = roundf(sin(anim_t * 10.0) * 1.5)
		var lx: float = c.x + sway
		var ly: float = c.y + 5.0
		draw_rect(Rect2(lx, ly - 5.0, 1.0, 1.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 1.0, ly - 4.0, 3.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 3.0, ly - 3.0, 7.0, 7.0), PAL["void"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 2.0, 5.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly + 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		draw_rect(Rect2(lx - 1.0, ly - 1.0, 3.0, 3.0), PAL["gold"] as Color, true)
		var flick: float = 0.0 if (LxHudFx.flash_reduced() or int(anim_t * 14.0) % 2 == 0) else -1.0
		draw_rect(Rect2(lx, ly + flick, 1.0, 2.0), PAL["cream"] as Color, true)
		var back: Vector2 = -Vector2.from_angle(facing)
		for ti: int in range(2):
			var tp: float = fmod(anim_t * 2.4 + float(ti) * 0.5, 1.0)
			var mx: float = roundf(lx + back.x * (4.0 + tp * 6.0) + sin(anim_t * 9.0 + float(ti) * 2.5) * 1.5)
			var my: float = roundf(ly + back.y * (4.0 + tp * 6.0) - tp * 2.0)
			draw_rect(Rect2(mx, my, 1.0, 1.0), (PAL["cream"] as Color) if ti == 0 else (PAL["gold"] as Color), true)
	if gulp_t > 0.0:
		var gp: float = 1.0 - clampf(gulp_t / GULP_TIME, 0.0, 1.0)
		var gr: float = roundf(body_radius + 2.5 + gp * 5.0)
		draw_arc(c, gr + 1.0, 0.0, TAU, 16, PAL["apricot"] as Color, 1.4)
		draw_arc(c, gr, 0.0, TAU, 14, PAL["gold"] as Color, 1.0)
		for si: int in range(4):
			var sa: float = float(si) * (PI * 0.5) + PI * 0.25 + gp * 0.45
			var sd: Vector2 = Vector2.from_angle(sa)
			var p0 := Vector2(roundf(c.x + sd.x * (gr + 1.0)), roundf(c.y + sd.y * (gr + 1.0)))
			var p1 := Vector2(roundf(c.x + sd.x * (gr + 4.0)), roundf(c.y + sd.y * (gr + 4.0)))
			draw_line(p0, p1, PAL["gold"] as Color, 1.0)
			draw_rect(Rect2(p1, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
