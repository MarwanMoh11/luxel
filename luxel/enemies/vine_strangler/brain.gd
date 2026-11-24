class_name LxVineStranglerBrain
extends LxEnemyBrain
## Vine Strangler (Island 3): Ambush space-controller disguised as pillar ivy.
## Lashes a creeping root-tether (0.50s tell, 0.30s commit, 90 px reach, 1.20s recover)
## that pins Wick to a tether radius; Dash snaps tether & staggers, exposed gold knot
## takes crit damage, Throw baits the tether, Beam burns + staggers instantly.

const TETHER_REACH: float = 90.0
const COMMIT_TIME: float = 0.30
const TETHER_HOLD_TIME: float = 1.85
const TETHER_MAX_RADIUS: float = 36.0
const TETHER_SNAP_STAGGER: float = 0.90
const KNOT_CRIT_MULT: float = 1.45
const POST_COOLDOWN: float = 1.05

var disguised: bool = true
var tether_dir: Vector2 = Vector2.RIGHT
var tether_end: Vector2 = Vector2.ZERO
var tether_hit_done: bool = false
var tethered_wick: bool = false
var tether_anchor: Vector2 = Vector2.ZERO
var tether_t: float = 0.0


func _init() -> void:
	kind = "vine_strangler"
	island_id = 3
	max_hp = 3.5
	hp = 3.5
	body_radius = 6.5
	routine_speed = 32.0
	leash_radius = 148.0
	notice_radius = 96.0
	tell_time = 0.50
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	disguised = true
	tether_dir = Vector2.from_angle(facing)
	tether_end = pos
	tether_hit_done = false
	tethered_wick = false
	tether_anchor = pos
	tether_t = 0.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_burn: bool = src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or bool(h["pierce"])
	var is_heavy: bool = bool(h["stagger"]) or is_burn
	var rel: Vector2 = orig - pos

	var was_disguised: bool = disguised
	disguised = false
	if was_disguised and not is_burn and not is_heavy:
		dmg *= 0.65
	var knot_open: bool = state == State.RECOVER or state == State.STAGGER or tethered_wick
	if is_burn:
		dmg *= 1.40
	elif knot_open:
		dmg *= KNOT_CRIT_MULT

	hp -= dmg
	flash_t = 0.16 if (knot_open or is_burn) else 0.09
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 24.0)

	if hp <= 0.001:
		tethered_wick = false
		opened_kill = knot_open or is_burn
		_die(hit)
		return HitResult.KILLED

	if is_burn or is_heavy:
		tethered_wick = false
		_release_token()
		state = State.STAGGER
		state_timer = TETHER_SNAP_STAGGER if is_burn else 0.55
		_emit_sfx("vine_strangler_burn" if is_burn else "vine_strangler_snap")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if knot_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	_step_tether_pin(dt)
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			disguised = true
			if _sees_target(target_pos):
				_enter_notice()
		State.NOTICE:
			disguised = false
			_face_point(target_pos, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			disguised = false
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.0, dt)
				tether_dir = Vector2.from_angle(facing)
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
				cooldown = 0.55
				state = State.POSITION
		State.RETURN:
			tethered_wick = false
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				disguised = true
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_tether_pin(dt: float) -> void:
	if not tethered_wick:
		return
	tether_t -= dt
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if wick_node == null or wick_node.dead or tether_t <= 0.0:
		tethered_wick = false
		return
	# Counterplay: Dash or Zip snaps root tether and staggers the Strangler!
	if wick_node.is_dashing() or wick_node.is_zipping():
		tethered_wick = false
		_release_token()
		state = State.STAGGER
		state_timer = TETHER_SNAP_STAGGER
		LxDamageFx.boss_impact(pos, 0.10, 48.0, 52.0, 44.0, 1.18, 0.22)
		_emit_sfx("vine_strangler_snap")
		return
	var to_anchor: Vector2 = tether_anchor - wick_node.global_position
	var dist_a: float = to_anchor.length()
	if dist_a > TETHER_MAX_RADIUS and wick_node.has_method("push_external"):
		var pull_spd: float = clampf((dist_a - TETHER_MAX_RADIUS) * 8.0, 48.0, 140.0)
		wick_node.call("push_external", (to_anchor / dist_a) * pull_spd, "vine_tether")


func _enter_notice() -> void:
	disguised = false
	state = State.NOTICE
	state_timer = 0.28
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("vine_strangler_notice")


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.2, dt)
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
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

	if is_lead and cooldown <= 0.0 and dist <= TETHER_REACH and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		tether_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = tether_dir.angle()
		_emit_attack_started()
		_emit_sfx("vine_strangler_tell")
		return

	if dist > TETHER_REACH * 0.76:
		_move_step(to_t.normalized() * routine_speed * 0.75 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	tether_hit_done = false
	tether_end = pos + tether_dir * TETHER_REACH
	_emit_sfx("vine_strangler_lash")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var prog: float = 1.0 - clampf(state_timer / COMMIT_TIME, 0.0, 1.0)
	var cur_len: float = lerpf(10.0, TETHER_REACH, sin(prog * PI * 0.5))
	tether_end = pos + tether_dir * cur_len
	if not tether_hit_done:
		# Throw lantern bait catches the vine tether harmlessly!
		if _is_lured() and Geometry2D.get_closest_point_to_segment(_get_lantern_pos(), pos, tether_end).distance_to(_get_lantern_pos()) <= 12.0:
			tether_hit_done = true
			tether_end = _get_lantern_pos()
			_emit_sfx("vine_strangler_snap")
		elif _has_player():
			var wp: Vector2 = _get_wick_pos()
			if Geometry2D.get_closest_point_to_segment(wp, pos, tether_end).distance_to(wp) <= 11.0:
				tether_hit_done = true
				tethered_wick = true
				tether_anchor = wp
				tether_t = TETHER_HOLD_TIME
				_emit_player_hit(tether_dir)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _body_color() -> Color:
	return PAL["jade"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if disguised and state == State.ROUTINE:
		if int(anim_t * 2.2) % 3 == 0:
			draw_rect(Rect2(c + Vector2(-2.0, -8.0), Vector2(1.0, 1.0)), PAL["rose"] as Color)
			draw_rect(Rect2(c + Vector2(2.0, -8.0), Vector2(1.0, 1.0)), PAL["rose"] as Color)
		return
	if state == State.TELL:
		var tip: Vector2 = (c + tether_dir * TETHER_REACH).round()
		var locked: bool = state_timer <= 0.16 * _assist_tell_scale()
		var col: Color = (PAL["coral"] if locked else PAL["rose"]) as Color
		draw_line(c, tip, col, 1.4 if locked else 1.0)
		draw_circle(tip, 3.0, col)
	elif state == State.COMMIT:
		var rel_e: Vector2 = (tether_end - pos).round()
		draw_line(c, rel_e, PAL["pine"] as Color, 3.5)
		draw_line(c, rel_e, PAL["coral"] as Color, 1.6)
		draw_circle(rel_e, 3.5, PAL["rose"] as Color)
	if tethered_wick and _has_player():
		var rel_w: Vector2 = (_get_wick_pos() - pos).round()
		var rel_a: Vector2 = (tether_anchor - pos).round()
		draw_arc(rel_a, TETHER_MAX_RADIUS, 0.0, TAU, 20, Color(PAL["rose"] as Color, 0.55), 1.0)
		draw_line(c, rel_w, PAL["pine"] as Color, 2.8)
		draw_line(c, rel_w, PAL["coral"] as Color, 1.3)
	if state == State.RECOVER or state == State.STAGGER:
		draw_arc(c + Vector2(0.0, -4.0), 5.0, 0.0, TAU, 12, PAL["gold"] as Color, 1.2)
