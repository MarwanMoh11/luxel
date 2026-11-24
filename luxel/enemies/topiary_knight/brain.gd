class_name LxTopiaryKnightBrain
extends LxEnemyBrain
## Topiary Knight (Island 4): Weeping-Angel hedge statue.
## Moves ONLY when Wick's aim cone, nearby hung lantern, and Echo Rose pools are OFF it.
## Freezes into an armored topiary statue when lit (can be pinned onto pressure_plates).
## Weak spot: blooming rose back takes 2x damage; Beam chips frozen front at 0.5x.

const FREEZE_CONE_COS: float = 0.72      # ~44 deg half-cone when Wick holds lantern
const FREEZE_AIM_DIST: float = 112.0
const FREEZE_HUNG_DIST: float = 64.0
const FREEZE_ECHO_DIST: float = 54.0
const FREEZE_ECHO_CONE_DIST: float = 92.0
const CLEAVE_RANGE: float = 34.0
const CLEAVE_ARC_R: float = 26.0
const CLEAVE_COMMIT_S: float = 0.24
const BACK_HALF_ANG: float = 1.22        # ~70 deg rear weak-spot cone
const POST_COOLDOWN: float = 1.05

var frozen: bool = false
var _freeze_hold_t: float = 0.0
var _freeze_sfx_cd: float = 0.0
var _cleave_hit: bool = false
var _cleave_dir: Vector2 = Vector2.RIGHT
var _leaf_t: float = 0.0


func _init() -> void:
	kind = "topiary_knight"
	island_id = 4
	max_hp = 4.5
	hp = 4.5
	body_radius = 7.0
	routine_speed = 64.0
	leash_radius = 158.0
	notice_radius = 148.0
	tell_time = 0.50
	recover_time = 1.15
	give_up_time = 2.0
	shard_drop = 6


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	frozen = false
	_freeze_hold_t = 0.0
	_freeze_sfx_cd = 0.0
	_cleave_hit = false
	_cleave_dir = Vector2.from_angle(facing)
	_leaf_t = 0.0


func on_light(a: Variant, b: Variant = Vector2.ZERO, c: Variant = "") -> void:
	if state == State.DEAD:
		return
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = str(c)
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2
		elif b is String:
			src = str(b)
	if rad <= 0.0:
		return
	var dist: float = pos.distance_to(orig)
	if src == "lantern_hand":
		# Hand lantern freezes ONLY when Wick's aim cone faces the knight!
		if dist <= minf(FREEZE_AIM_DIST, rad + 48.0) and _is_in_wick_aim_cone():
			_set_frozen(0.18)
	elif src == "lantern_hung" or src == "lens" or src == "lens_anchor":
		if dist <= minf(FREEZE_HUNG_DIST, rad):
			_set_frozen(0.22)
	elif dist <= minf(FREEZE_ECHO_DIST, rad):
		_set_frozen(0.20)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_heavy: bool = bool(h["stagger"])

	var rel: Vector2 = orig - pos
	var back_ang: float = wrapf(facing + PI, -PI, PI)
	var from_back: bool = rel.length() > 0.01 and absf(angle_difference(back_ang, rel.angle())) <= BACK_HALF_ANG
	var from_front: bool = not from_back

	# Back rose-bloom weak spot: 2.0x damage and opens/staggers!
	if from_back:
		dmg *= 2.0
		hp -= dmg
		flash_t = 0.16
		_leaf_t = 0.35
		if rel.length() > 0.01:
			knock = -rel.normalized() * (115.0 if is_heavy else 55.0)
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		if is_heavy or src == LxHit.SOURCE_BEAM:
			_release_token()
			state = State.STAGGER
			state_timer = 0.65
		_emit_sfx("heavy_hit")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	# Front armor when frozen: Beam/Sunflare chips 0.5x; Throw/Dash chips 0.45x; bolts clang!
	if frozen and from_front:
		if pierce or cracks or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
			hp -= dmg * 0.50
			flash_t = 0.10
			_leaf_t = 0.25
			if hp <= 0.001:
				opened_kill = false
				_die(hit)
				return HitResult.KILLED
			_emit_sfx("bolt_chip")
			_emit_enemy_hit(hit, HitResult.CHIPPED)
			return HitResult.CHIPPED
		if src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_DASH:
			hp -= dmg * 0.45
			clank_t = 0.14
			if hp <= 0.001:
				_die(hit)
				return HitResult.KILLED
			_emit_sfx("bramble_thorn_block")
			_emit_enemy_hit(hit, HitResult.CHIPPED)
			return HitResult.CHIPPED
		clank_t = 0.18
		_emit_sfx("bramble_thorn_block")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	# Unfrozen frontal hit (normal damage; heavy staggers)
	hp -= dmg
	flash_t = 0.12 if is_heavy else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (90.0 if is_heavy else 28.0)
	if hp <= 0.001:
		opened_kill = state == State.RECOVER or state == State.STAGGER
		_die(hit)
		return HitResult.KILLED
	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.28
		alert_t = 0.8
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_freeze_sfx_cd = maxf(0.0, _freeze_sfx_cd - dt)
	_leaf_t = maxf(0.0, _leaf_t - dt)
	_poll_world_lights()
	if _freeze_hold_t > 0.0:
		_freeze_hold_t = maxf(0.0, _freeze_hold_t - dt)
		frozen = true
	else:
		frozen = false

	# Frozen statue lock: halts motion, cancels windup/position, but still allows RETURN countdown when Wick leaves
	if frozen:
		var wick_p: Vector2 = _get_real_wick_pos()
		if state == State.TELL:
			_release_token()
			state = State.POSITION
		if state in [State.NOTICE, State.POSITION, State.WAIT_TOKEN]:
			if not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0:
				lost_t += dt
				if lost_t >= give_up_time:
					_release_token()
					frozen = false
					_freeze_hold_t = 0.0
					state = State.RETURN
					lost_t = 0.0
		elif state == State.RECOVER or state == State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		return

	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			# Statue idle: tiny subtle breeze tremble, awaits Wick entering notice radius
			if _has_player() and pos.distance_to(target_pos) <= notice_radius:
				state = State.NOTICE
				state_timer = 0.28
				alert_t = 0.75
				lost_t = 0.0
				_emit_sfx("warden_notice")
		State.NOTICE:
			_face_point(target_pos, 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_march(dt, target_pos)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.4, dt)
				_cleave_dir = Vector2.from_angle(facing)
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
				_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)


func _step_march(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 4.0, dt)

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

	if is_lead and cooldown <= 0.0 and dist <= CLEAVE_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_cleave_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _cleave_dir.angle()
		_emit_attack_started()
		_emit_sfx("warden_windup")
		return

	# Silent march at 60 px/s (< routine_speed 64 px/s so zero pursuit violation)
	if dist > CLEAVE_RANGE * 0.72:
		_move_step(to_t.normalized() * (routine_speed * 0.94) * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = CLEAVE_COMMIT_S
	_cleave_hit = false
	facing = _cleave_dir.angle()
	_emit_sfx("topiary_cleave")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	# Short forward lunge into cleave
	_move_step(_cleave_dir * 72.0 * dt, false)
	if not _cleave_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if wv.length() <= CLEAVE_ARC_R and absf(angle_difference(_cleave_dir.angle(), wv.angle())) <= 1.15:
			_cleave_hit = true
			_emit_player_hit(_cleave_dir)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _poll_world_lights() -> void:
	if state == State.RETURN:
		return
	# 1. Check Echo Rose ghosts (42px pool or echo facing cone)
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group("lx_echo_decoys"):
			if n == null or not is_instance_valid(n) or not n.has_method("is_echo_active"):
				continue
			if not bool(n.call("is_echo_active")):
				continue
			var ep: Vector2 = n.call("get_echo_pos") as Vector2
			var d: float = pos.distance_to(ep)
			if d <= FREEZE_ECHO_DIST:
				_set_frozen(0.16)
				return
			if d <= FREEZE_ECHO_CONE_DIST and n.get("echo_facing") is Vector2:
				var ef: Vector2 = (n.get("echo_facing") as Vector2).normalized()
				if ef.dot((pos - ep).normalized()) >= FREEZE_CONE_COS and _has_clear_view(ep, pos):
					_set_frozen(0.16)
					return
	# 2. Check hung lantern nearby
	if _is_lantern_hung():
		var lp: Vector2 = _get_lantern_pos()
		if pos.distance_to(lp) <= FREEZE_HUNG_DIST and _has_clear_view(lp, pos):
			_set_frozen(0.16)
			return
	# 3. Check Wick's aim cone (holding lantern & looking directly at knight)
	if _has_player() and not _is_lantern_hung() and _is_in_wick_aim_cone():
		if pos.distance_to(_get_real_wick_pos()) <= FREEZE_AIM_DIST and _has_clear_view(_get_real_wick_pos(), pos):
			_set_frozen(0.14)


func _is_in_wick_aim_cone() -> bool:
	var wp: Vector2 = _get_real_wick_pos()
	var to_me: Vector2 = pos - wp
	if to_me.length_squared() <= 1.0:
		return false
	var wf: Vector2 = Vector2.RIGHT
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_wick_facing"):
		wf = world_ctx.call("get_wick_facing") as Vector2
	elif Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("facing") is Vector2:
		wf = Lx.player.get("facing") as Vector2
	if wf.length_squared() <= 0.001:
		return false
	return wf.normalized().dot(to_me.normalized()) >= FREEZE_CONE_COS


func _set_frozen(hold_s: float) -> void:
	if not frozen and _freeze_sfx_cd <= 0.0:
		_freeze_sfx_cd = 0.75
		_emit_sfx("topiary_freeze")
	frozen = true
	_freeze_hold_t = maxf(_freeze_hold_t, hold_s)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _has_active_shield() -> bool:
	return frozen


func _shield_color() -> Color:
	return PAL["stone"] as Color


func _body_color() -> Color:
	return (PAL["stone"] if frozen else PAL["pine"]) as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Blooming rose back weak-spot marker (visible cue for 2x flank!)
	var back_p: Vector2 = (c - Vector2.from_angle(facing) * (body_radius + 1.5)).round()
	draw_circle(back_p, 2.5, PAL["rose"] as Color)
	draw_rect(Rect2(back_p, Vector2.ONE), PAL["cream"] as Color)

	# Stone-lock plinth aura when frozen by light
	if frozen:
		draw_arc(c, body_radius + 3.0, 0.0, TAU, 16, PAL["stone"] as Color, 1.2)
		if clank_t > 0.0:
			draw_arc(c, body_radius + 5.0, facing - 0.9, facing + 0.9, 10, PAL["cream"] as Color, 1.5)

	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var col: Color = (PAL["coral"] if prog > 0.65 else PAL["gold"]) as Color
		draw_arc(c, CLEAVE_ARC_R, _cleave_dir.angle() - 1.05, _cleave_dir.angle() + 1.05, 14, col, 1.4)
	elif state == State.COMMIT:
		draw_arc(c, CLEAVE_ARC_R, _cleave_dir.angle() - 1.15, _cleave_dir.angle() + 1.15, 16, PAL["lime"] as Color, 2.4)
		draw_arc(c, CLEAVE_ARC_R - 2.5, _cleave_dir.angle() - 1.0, _cleave_dir.angle() + 1.0, 14, PAL["cream"] as Color, 1.2)
