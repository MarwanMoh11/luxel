class_name LxAnchorDrownedBrain
extends LxEnemyBrain
## Anchor Drowned (Island 2 — Heavy Terrain Tank):
## Drags a huge iron anchor (28 px/s). Front anchor blocks yellow bolts; wide 1.40s haul
## recovery exposes back for flanking, and planted anchor acts as solid cover + temporary
## mooring post (0.9s) for Skiff/lantern zip. Blue/Prism banks deal 1.5x + stagger!
## Counterplay: Lure onto plates with Throw, flank during haul, Blue/Prism behind anchor, Skiff zip.

const SLAM_RANGE: float = 64.0
const SLAM_RADIUS: float = 28.0
const DRAG_LEN: float = 76.0
const FRONT_BLOCK_HALF: float = 1.08
const COMMIT_TIME: float = 0.32
const NOTICE_TIME: float = 0.40
const MOORING_WINDOW: float = 0.90
const POST_COOLDOWN: float = 1.15

var _patrol_sign: float = 1.0
var _slam_dir: Vector2 = Vector2.RIGHT
var _slam_hit: bool = false
var _anchor_pos: Vector2 = Vector2.ZERO
var _anchor_planted_t: float = 0.0
var _guard_cracked_t: float = 0.0


func _init() -> void:
	kind = "anchor_drowned"
	island_id = 2
	max_hp = 6.5
	hp = 6.5
	body_radius = 7.5
	routine_speed = 28.0
	leash_radius = 148.0
	notice_radius = 128.0
	tell_time = 0.62
	recover_time = 1.40
	give_up_time = 2.2
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_patrol_sign = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	_slam_dir = Vector2.from_angle(facing)
	_slam_hit = false
	_anchor_pos = pos + _slam_dir * 16.0
	_anchor_planted_t = 0.0
	_guard_cracked_t = 0.0


func is_anchor_planted() -> bool:
	return _anchor_planted_t > 0.0 and is_alive()


func get_anchor_pos() -> Vector2:
	return _anchor_pos


func _has_active_shield() -> bool:
	if _guard_cracked_t > 0.0:
		return false
	return state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue: bool = hit.is_blue()
	var is_heavy: bool = bool(h["stagger"]) or hit.is_heavy()
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_BLOCK_HALF

	# Front iron anchor blocks straight frontal yellow bolts!
	if _has_active_shield() and src == LxHit.SOURCE_BOLT and not is_blue and not pierce and not cracks and from_front:
		clank_t = 0.16
		_emit_sfx("anchor_clang")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	var is_rear_or_open: bool = (not from_front) or state == State.RECOVER or state == State.STAGGER or is_blue or cracks
	if is_blue:
		dmg *= 1.5
		_guard_cracked_t = 3.2
	elif not from_front or state == State.RECOVER:
		dmg *= 1.25
	if cracks or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or src == LxHit.SOURCE_HAZARD:
		_guard_cracked_t = 3.6

	hp -= dmg
	flash_t = 0.14 if is_rear_or_open else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (52.0 if (is_heavy or is_blue) else 16.0)
	if hp <= 0.001:
		opened_kill = is_rear_or_open
		_anchor_planted_t = 0.0
		_die(hit)
		return HitResult.KILLED
	if is_blue or cracks or (is_heavy and is_rear_or_open):
		_release_token()
		state = State.STAGGER
		state_timer = 0.65
		_emit_sfx("warden_shield_break")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if is_rear_or_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	_guard_cracked_t = maxf(0.0, _guard_cracked_t - dt)
	_anchor_planted_t = maxf(0.0, _anchor_planted_t - dt)
	var target: Vector2 = _attention_target()

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			_face_point(target, 2.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_march(dt, target)
		State.TELL:
			if state_timer > 0.24 * _assist_tell_scale():
				_face_point(target, 2.0, dt)
				_slam_dir = Vector2.from_angle(facing)
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
			if to_h.length() <= 4.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_turn_toward(to_h.angle(), 2.8, dt)
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	var goal: Vector2 = home + Vector2(_patrol_sign * 24.0, 0.0)
	var d: Vector2 = goal - pos
	if d.length() <= 3.0:
		_patrol_sign = -_patrol_sign
	else:
		_turn_toward(d.angle(), 2.2, dt)
		_move_step(d.limit_length(routine_speed * 0.70 * dt), false)


func _step_march(dt: float, target: Vector2) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 14.0):
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
		_turn_toward(to_t.angle(), 2.6, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= SLAM_RANGE and _is_on_screen() and _has_clear_view(pos, target) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_slam_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _slam_dir.angle()
		_emit_attack_started()
		_emit_sfx("harbor_creak")
		return

	if dist > 28.0:
		_move_step(to_t.normalized() * (routine_speed * 0.85 * dt), false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_slam_hit = false
	_slam_dir = Vector2.from_angle(facing)
	_anchor_pos = pos + _slam_dir * 32.0
	_emit_sfx("anchor_slam")
	LxDamageFx.boss_impact(_anchor_pos, 0.10, 44.0, 52.0, 48.0, 1.22, 0.22, "sky")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	# Heavy forward anchor drag
	_move_step(_slam_dir * 52.0 * dt, false)
	_anchor_pos = pos + _slam_dir * 24.0
	if not _slam_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		var seg_d: float = Geometry2D.get_closest_point_to_segment(wp, pos, pos + _slam_dir * 42.0).distance_to(wp)
		if seg_d <= 14.0 or wp.distance_to(_anchor_pos) <= SLAM_RADIUS * 0.72:
			_slam_hit = true
			_emit_player_hit(_slam_dir)
	if state_timer <= 0.0:
		_anchor_planted_t = MOORING_WINDOW
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("anchor_clang")


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


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
	return PAL["pine"] as Color


func _shield_color() -> Color:
	return PAL["stone"] as Color


func _draw_extra(off: Vector2) -> void:
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, off + _slam_dir * DRAG_LEN, 11.0, prog, anim_t, "coral", "gold")
		LxBossTelegraphFx.draw_ground_danger_ring(self, off + _slam_dir * 28.0, SLAM_RADIUS, prog, anim_t, "coral", "gold")
	if _anchor_planted_t > 0.0:
		var ap: Vector2 = (_anchor_pos - pos + off).round()
		draw_line(off.round(), ap, PAL["mauve"] as Color, 1.6)
		draw_circle(ap, 4.5, PAL["night"] as Color)
		draw_arc(ap, 5.5, 0.0, TAU, 12, PAL["gold"] as Color, 1.2)
		draw_circle(ap, 2.0, PAL["ice"] as Color)
