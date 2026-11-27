class_name LxNetCasterBrain
extends LxEnemyBrain
## Net Caster (Island 2 — Lantern Disrupter):
## Mends rope on piers; casts weighted net pinning a thrown/hung lantern for 3.0s
## (blocks recall until Dash/Zip cuts net or Net Caster dies), or snares Wick if lantern is in hand.
## Counterplay: Bolts interrupt TELL, Dash cuts net, Blue/Prism deals 1.35x + stagger, Skiff carves clear.

const CAST_RANGE: float = 128.0
const COMMIT_TIME: float = 0.24
const NET_SPEED: float = 132.0
const NET_MAX_DIST: float = 112.0
const NET_RADIUS: float = 8.0
const PIN_DURATION: float = 3.0
const POST_COOLDOWN: float = 1.25

var _patrol_sign: float = 1.0
var _patrol_pause: float = 0.0
var _cast_dir: Vector2 = Vector2.RIGHT
var _cast_target: Vector2 = Vector2.ZERO
var _nets: Array[Dictionary] = []
var _pin_t: float = 0.0
var _pin_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	kind = "net_caster"
	island_id = 2
	max_hp = 2.5
	hp = 2.5
	body_radius = 5.5
	routine_speed = 32.0
	leash_radius = 152.0
	notice_radius = 136.0
	tell_time = 0.58
	recover_time = 1.20
	give_up_time = 2.0
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_patrol_sign = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	_patrol_pause = 0.6
	_cast_dir = Vector2.from_angle(facing)
	_cast_target = home
	_nets.clear()
	_pin_t = 0.0
	_pin_pos = Vector2.ZERO


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"]) or hit.is_heavy()
	var is_blue: bool = hit.is_blue()
	var interrupted_tell: bool = state == State.TELL
	if is_blue:
		dmg *= 1.35
	hp -= dmg
	flash_t = 0.14 if (is_heavy or is_blue or interrupted_tell) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 46.0)
	if hp <= 0.001:
		opened_kill = interrupted_tell or is_blue or state == State.RECOVER or state == State.STAGGER
		_cut_pinned_net(false)
		_nets.clear()
		_die(hit)
		return HitResult.KILLED
	# Bolts interrupt Net Caster's tell!
	if interrupted_tell or is_heavy or is_blue:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
		_emit_sfx("net_cut")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_step_nets(dt)
	_step_pin(dt)
	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target):
				_enter_notice()
		State.NOTICE:
			_face_point(target, 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_guard(dt, target)
		State.TELL:
			if state_timer > 0.22 * _assist_tell_scale():
				_face_point(target, 3.2, dt)
				_cast_target = target
				var to_c: Vector2 = _cast_target - pos
				if to_c.length_squared() > 0.01:
					_cast_dir = to_c.normalized()
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
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
				_turn_toward(to_h.angle(), 4.2, dt)
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	if _patrol_pause > 0.0:
		_patrol_pause -= dt
		return
	var goal: Vector2 = home + Vector2(_patrol_sign * 22.0, 0.0)
	var d: Vector2 = goal - pos
	if d.length() <= 2.5:
		_patrol_sign = -_patrol_sign
		_patrol_pause = 0.95
	else:
		_turn_toward(d.angle(), 3.6, dt)
		_move_step(d.limit_length(routine_speed * 0.65 * dt), false)


func _step_guard(dt: float, target: Vector2) -> void:
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
		_turn_toward(to_t.angle(), 4.2, dt)

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= CAST_RANGE and _is_on_screen() and _has_clear_view(pos, target) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_cast_target = target
		_cast_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = _cast_dir.angle()
		_emit_attack_started()
		_emit_sfx("net_cast")
		return

	# Maintain safe pier casting distance (72..96px) without chasing
	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var radial: float = clampf((dist - 82.0) / 36.0, -0.65, 0.50)
	var step_v: Vector2 = fwd * (routine_speed * 0.78 * radial)
	if step_v.length_squared() > 1.0:
		_move_step(step_v * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_nets.append({
		"pos": pos + _cast_dir * (body_radius + 3.0),
		"vel": _cast_dir * NET_SPEED,
		"traveled": 0.0,
	})
	_emit_sfx("net_cast")


func _step_nets(dt: float) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	for i: int in range(_nets.size() - 1, -1, -1):
		var n: Dictionary = _nets[i]
		var prev_p: Vector2 = n["pos"] as Vector2
		var vel: Vector2 = n["vel"] as Vector2
		var fa: Vector2 = LxFields.accel_at(prev_p, "bolt")
		if fa.length_squared() > 0.01:
			vel = (vel + fa * dt).limit_length(NET_SPEED * 1.45)
			n["vel"] = vel
		var step: Vector2 = vel * dt
		var nxt_p: Vector2 = prev_p + step
		n["pos"] = nxt_p
		n["traveled"] = float(n["traveled"]) + step.length()
		var remove_it: bool = float(n["traveled"]) >= NET_MAX_DIST or not _has_clear_view(prev_p, nxt_p)
		if not remove_it and lan_out and nxt_p.distance_to(lan_p) <= NET_RADIUS + 6.0:
			_pin_lantern(lan_p)
			remove_it = true
		elif not remove_it and _has_player() and nxt_p.distance_to(wick_p) <= NET_RADIUS + 4.5:
			var ndir: Vector2 = vel.normalized() if vel.length_squared() > 0.01 else _cast_dir
			_emit_player_hit(ndir)
			remove_it = true
		if remove_it:
			_nets.remove_at(i)


func _pin_lantern(at_pos: Vector2) -> void:
	_pin_t = PIN_DURATION
	_pin_pos = at_pos
	_emit_sfx("net_pin")
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.lantern != null and w.lantern.is_lure_active():
			w.lantern.hang_timer = maxf(w.lantern.hang_timer, PIN_DURATION)
	if Lx.events != null:
		Lx.events.lantern_struck.emit(at_pos)


func _step_pin(dt: float) -> void:
	if _pin_t <= 0.0:
		return
	_pin_t = maxf(0.0, _pin_t - dt)
	if not _is_lantern_out():
		_pin_t = 0.0
		return
	_pin_pos = _get_lantern_pos()
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		# Dash or Zip cuts the net immediately!
		var cutting: bool = (w.move_dash != null and w.move_dash.is_active()) or (w.move_zip != null and w.move_zip.is_active())
		if cutting and w.global_position.distance_to(_pin_pos) <= 28.0:
			_cut_pinned_net(true)
			return
		# Hold lantern pinned while net lasts
		if w.lantern != null and w.lantern.state == LxLantern.State.RECALLING:
			w.lantern.state = LxLantern.State.HANGING
			w.lantern.pos = _pin_pos
			w.lantern.vel = Vector2.ZERO


func _cut_pinned_net(play_sfx: bool) -> void:
	if _pin_t > 0.0:
		_pin_t = 0.0
		if play_sfx:
			_emit_sfx("net_cut")


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.32
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("harbor_creak")


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
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var rel_t: Vector2 = (_cast_target - pos + off).round()
		LxBossTelegraphFx.draw_ground_danger_ring(self, rel_t, 12.0, prog, anim_t, "apricot", "gold")
		draw_line(off.round(), rel_t, PAL["void"] as Color, 3.0)
		draw_line(off.round(), rel_t, PAL["apricot"] as Color, 1.0)
	for n: Dictionary in _nets:
		var np: Vector2 = ((n["pos"] as Vector2) - pos + off).round()
		draw_arc(np, NET_RADIUS, 0.0, TAU, 12, PAL["void"] as Color, 4.0)
		draw_arc(np, NET_RADIUS, 0.0, TAU, 12, PAL["apricot"] as Color, 2.0)
		draw_line(np + Vector2(-5.0, -5.0), np + Vector2(5.0, 5.0), PAL["coral"] as Color, 1.0)
		draw_line(np + Vector2(5.0, -5.0), np + Vector2(-5.0, 5.0), PAL["coral"] as Color, 1.0)
	if _pin_t > 0.0:
		var pp: Vector2 = (_pin_pos - pos + off).round()
		draw_arc(pp, 10.0, 0.0, TAU, 12, PAL["void"] as Color, 4.0)
		draw_arc(pp, 10.0, 0.0, TAU, 12, PAL["apricot"] as Color, 2.0)
		draw_line(pp + Vector2(-7.0, 0.0), pp + Vector2(7.0, 0.0), PAL["gold"] as Color, 1.0)
		draw_line(pp + Vector2(0.0, -7.0), pp + Vector2(0.0, 7.0), PAL["gold"] as Color, 1.0)
