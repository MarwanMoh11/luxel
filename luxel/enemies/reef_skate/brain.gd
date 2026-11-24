class_name LxReefSkateBrain
extends LxEnemyBrain
## Reef Skate (Island 2 — Tidal Flanker):
## Glides smoothly over water/tide and skims fast (92 px/s) on a 72px hydro-dash commit.
## Island 2 rule: strands flopping helpless at `tide==ebb` on dry ground (speed 0, 1.5x dmg).
## Counterplay: Bolt chips, Dash dodges skim, Throw/Recall/Blue staggers, Tide/Ballast strands.

const SKIM_SPEED: float = 92.0
const SKIM_RANGE: float = 82.0
const COMMIT_TIME: float = 0.30
const NOTICE_TIME: float = 0.30
const POST_COOLDOWN: float = 0.85
const FLANK_RING_R: float = 54.0

var _patrol_phase: float = 0.0
var _strafe_sign: float = 1.0
var _skim_dir: Vector2 = Vector2.RIGHT
var _skim_hit: bool = false
var _stranded: bool = false
var _wake_pts: Array[Dictionary] = []


func _init() -> void:
	kind = "reef_skate"
	island_id = 2
	max_hp = 3.0
	hp = 3.0
	body_radius = 5.5
	routine_speed = 46.0
	leash_radius = 158.0
	notice_radius = 132.0
	tell_time = 0.46
	recover_time = 0.95
	give_up_time = 2.0
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_patrol_phase = _randf_range(0.0, TAU)
	_strafe_sign = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	_skim_dir = Vector2.from_angle(facing)
	_skim_hit = false
	_stranded = false
	_wake_pts.clear()


func is_flying() -> bool:
	# Skims freely over water/tide tiles when not stranded dry.
	return not _stranded


func _check_stranded() -> bool:
	if Lx.vars == null or world_ctx == null or not is_instance_valid(world_ctx):
		return false
	var in_real_region: bool = world_ctx is LxRegionLoader
	var var_store: Dictionary = Lx.vars.to_dict()
	var has_explicit_tide: bool = var_store.has("island:2") and (var_store["island:2"] is Dictionary) and (var_store["island:2"] as Dictionary).has("tide")
	var has_explicit_list: bool = var_store.has("dungeon:galleon") and (var_store["dungeon:galleon"] is Dictionary) and (var_store["dungeon:galleon"] as Dictionary).has("list")
	if not in_real_region and not has_explicit_tide and not has_explicit_list:
		return false
	var tile: String = str(world_ctx.call("tile_at", pos)) if world_ctx.has_method("tile_at") else "water"
	if tile == "water":
		return false
	var tide: String = str(Lx.vars.resolve_var("tide", island_id, zone, "")).to_lower()
	if tide == "ebb":
		return true
	if has_explicit_list and (tile == "ground" or tile == "path"):
		return true
	return false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"]) or hit.is_heavy()
	var is_blue: bool = hit.is_blue()
	var is_open: bool = _stranded or state == State.RECOVER or state == State.STAGGER or is_blue or is_heavy
	if _stranded:
		dmg *= 1.5
	elif is_blue:
		dmg *= 1.35
	hp -= dmg
	flash_t = 0.14 if is_open else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 58.0)
	if hp <= 0.001:
		opened_kill = is_open
		_die(hit)
		return HitResult.KILLED
	if is_heavy or is_blue or _stranded:
		_release_token()
		state = State.STAGGER
		state_timer = 0.60 if _stranded else 0.48
		_emit_sfx("skate_flop")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_step_wake(dt)
	var was_stranded: bool = _stranded
	_stranded = _check_stranded()
	if _stranded:
		if not was_stranded:
			_release_token()
			_emit_sfx("skate_flop")
		state = State.STAGGER
		state_timer = maxf(state_timer, 0.25)
		return

	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			_face_point(target, 6.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_flank(dt, target)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target, 4.5, dt)
				_skim_dir = Vector2.from_angle(facing)
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
				_strafe_sign = -_strafe_sign
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 4.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_turn_toward(to_h.angle(), 5.0, dt)
				_move_step(to_h.limit_length(routine_speed * dt), is_flying())


func _step_routine(dt: float) -> void:
	_patrol_phase = wrapf(_patrol_phase + dt * 1.15, -PI, PI)
	var goal: Vector2 = home + Vector2(cos(_patrol_phase) * 28.0, sin(_patrol_phase * 2.0) * 14.0)
	var step_v: Vector2 = (goal - pos).limit_length(routine_speed * 0.72 * dt)
	if step_v.length() > 0.01:
		_turn_toward(step_v.angle(), 4.5, dt)
		_move_step(step_v, is_flying())


func _step_flank(dt: float, target: Vector2) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 12.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 5.2, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= SKIM_RANGE and _is_on_screen() and _has_clear_view(pos, target) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_skim_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _skim_dir.angle()
		_emit_attack_started()
		_emit_sfx("skate_skim")
		return

	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var perp: Vector2 = Vector2(-fwd.y, fwd.x) * _strafe_sign
	var radial: float = clampf((dist - FLANK_RING_R) / 36.0, -0.45, 0.55)
	var dir: Vector2 = (perp * 0.86 + fwd * radial).normalized()
	var fa: Vector2 = LxFields.accel_at(pos, "enemy")
	var vel: Vector2 = dir * (routine_speed * 0.86) + fa * 0.06
	vel = vel.limit_length(routine_speed * 0.90)
	_move_step(vel * dt, is_flying())


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_skim_hit = false
	_skim_dir = Vector2.from_angle(facing)
	_emit_sfx("tide_wave")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	var fa: Vector2 = LxFields.accel_at(pos, "enemy")
	var step_dir: Vector2 = (_skim_dir * SKIM_SPEED + fa * 0.08)
	_move_step(step_dir * dt, is_flying())
	if int(anim_t * 30.0) % 2 == 0:
		_wake_pts.append({"pos": pos, "ttl": 0.28})
	if not _skim_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= body_radius + 7.5:
		_skim_hit = true
		_emit_player_hit(_skim_dir)
	elif not _skim_hit and _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= body_radius + 6.5:
		_skim_hit = true
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("skate_skim")


func _step_wake(dt: float) -> void:
	for i: int in range(_wake_pts.size() - 1, -1, -1):
		var w: Dictionary = _wake_pts[i]
		w["ttl"] = float(w["ttl"]) - dt
		if float(w["ttl"]) <= 0.0:
			_wake_pts.remove_at(i)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 16.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target: Vector2) -> bool:
	if not _has_player() and not _is_lured():
		return false
	return pos.distance_to(target) <= notice_radius and _has_clear_view(pos, target)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length_squared() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _body_color() -> Color:
	return PAL["blue"] as Color


func _draw_extra(off: Vector2) -> void:
	for w: Dictionary in _wake_pts:
		var wp: Vector2 = ((w["pos"] as Vector2) - pos + off).round()
		var frac: float = clampf(float(w["ttl"]) / 0.28, 0.0, 1.0)
		draw_arc(wp, lerpf(6.0, 2.5, frac), 0.0, TAU, 10, Color(PAL["ice"] as Color, 0.65 * frac), 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var lane_end: Vector2 = off + _skim_dir * 72.0
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, lane_end, body_radius + 3.0, prog, anim_t, "sky", "gold")
	elif _stranded:
		draw_arc(off, body_radius + 4.0, 0.0, TAU, 12, PAL["gold"] as Color, 1.2)
