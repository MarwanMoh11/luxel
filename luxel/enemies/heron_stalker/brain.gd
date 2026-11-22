class_name LxHeronStalkerBrain
extends LxEnemyBrain
## Heron Stalker (Island 4): wades patrol line; freezes and stares with a line sight-cue
## (0.55s tell), commits a long spear stab along the locked line, and gets its beak stuck
## in the mud during 1.35s recovery (prime punish window).

const PATROL_PAUSE: float = 0.75
const STAB_RANGE: float = 116.0
const STAB_MIN_LEN: float = 54.0
const STAB_MAX_LEN: float = 108.0
const STAB_SPEED: float = 315.0
const STAB_HIT_R: float = 15.0
const STAB_TIME_MAX: float = 0.36
const LOCK_CUTOFF: float = 0.26
const POST_COOLDOWN: float = 1.05

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var stab_dir: Vector2 = Vector2.RIGHT
var stab_from: Vector2 = Vector2.ZERO
var stab_len: float = 84.0
var stab_done: float = 0.0
var stab_hit: bool = false
var beak_stuck: bool = false


func _init() -> void:
	kind = "heron_stalker"
	island_id = 4
	max_hp = 3.25
	hp = 3.25
	body_radius = 5.5
	routine_speed = 38.0
	leash_radius = 160.0
	notice_radius = 136.0
	tell_time = 0.55
	recover_time = 1.35
	give_up_time = 1.8
	shard_drop = 4


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pt_v: Variant in (raw_r as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				route.append(_clamp_pt(_to_vec2(pt_v, home)))
	if route.size() < 2:
		var span: float = minf(44.0, leash_radius * 0.4)
		route = [_clamp_pt(home + Vector2(-span, 0.0)), _clamp_pt(home + Vector2(span, 0.0))]
	route_i = 0
	pause_t = 0.4
	stab_dir = Vector2.from_angle(facing)
	stab_from = pos
	stab_len = 84.0
	stab_done = 0.0
	stab_hit = false
	beak_stuck = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var is_punish: bool = beak_stuck or state == State.RECOVER or state == State.STAGGER

	hp -= dmg * (1.25 if beak_stuck else 1.0)
	flash_t = 0.14 if (is_heavy or is_punish) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01 and not beak_stuck:
		knock = -rel.normalized() * (115.0 if is_heavy else 26.0)

	if hp <= 0.001:
		opened_kill = is_punish
		_die(hit)
		return HitResult.KILLED

	if is_heavy and not beak_stuck:
		_release_token()
		state = State.STAGGER
		state_timer = 0.50
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.30
		alert_t = 0.8
	var res: int = HitResult.OPENED if is_punish else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			beak_stuck = false
			_step_routine(dt)
			if _sees_target(target_pos):
				state = State.NOTICE
				state_timer = 0.32
				alert_t = 0.85
				lost_t = 0.0
				_emit_sfx("heron_notice")
		State.NOTICE:
			_face_point(target_pos, 3.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			beak_stuck = false
			_step_stalk(dt, target_pos)
		State.TELL:
			# Freeze and stare: track briefly, then lock the spear sight-cue line solid.
			if state_timer > LOCK_CUTOFF * _assist_tell_scale():
				var to_t: Vector2 = target_pos - pos
				if to_t.length() > 0.01:
					_turn_toward(to_t.angle(), 3.0, dt)
					stab_dir = Vector2.from_angle(facing)
					stab_len = clampf(to_t.length() + 22.0, STAB_MIN_LEN, STAB_MAX_LEN)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			beak_stuck = true
			state_timer -= dt
			if state_timer <= 0.0:
				beak_stuck = false
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			beak_stuck = false
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			beak_stuck = false
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 2.5:
		route_i = (route_i + 1) % route.size()
		pause_t = PATROL_PAUSE
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.85 * dt), false)


func _step_stalk(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.0, dt)

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

	if is_lead and cooldown <= 0.0 and dist <= STAB_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		stab_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = stab_dir.angle()
		stab_len = clampf(dist + 22.0, STAB_MIN_LEN, STAB_MAX_LEN)
		_emit_attack_started()
		_emit_sfx("heron_stare")
		return

	var spd: float = minf(routine_speed * 0.84, routine_speed - 2.0)
	if dist > STAB_RANGE * 0.82:
		_move_step(to_t.normalized() * spd * dt, false)
	elif dist < 34.0 and dist > 0.01:
		_move_step(-to_t.normalized() * spd * 0.7 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = minf(STAB_TIME_MAX, stab_len / maxf(STAB_SPEED, 60.0) + 0.08)
	stab_from = pos
	stab_done = 0.0
	stab_hit = false
	facing = stab_dir.angle()
	_emit_sfx("heron_stab")


func _step_commit(dt: float) -> void:
	state_timer -= dt
	var before: Vector2 = pos
	var stride: float = STAB_SPEED * dt
	_move_step(stab_dir * stride, false)
	var moved: float = before.distance_to(pos)
	stab_done = maxf(stab_done, (pos - stab_from).dot(stab_dir))

	var beak_tip: Vector2 = pos + stab_dir * 12.0
	if not stab_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, before, beak_tip).distance_to(wp) <= STAB_HIT_R:
			stab_hit = true
			_emit_player_hit(stab_dir)

	if _is_lured():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, before, beak_tip).distance_to(lp) <= STAB_HIT_R:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lp)

	var hit_wall: bool = stride > 0.5 and moved < stride * 0.25
	if stab_done >= stab_len or hit_wall or state_timer <= 0.0:
		state = State.RECOVER
		beak_stuck = true
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer
		LxDamageFx.boss_impact(pos + stab_dir * 10.0, 0.10, 48.0, 56.0, 0.0, 1.0, 0.0, "sky")
		_emit_sfx("heron_beak_stuck")


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 1.0)
	if pt.distance_to(home) > cap:
		return home + (pt - home).normalized() * cap
	return pt


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _body_color() -> Color:
	return PAL["stone"] as Color


func _draw_extra(off: Vector2) -> void:
	var fwd: Vector2 = Vector2.from_angle(facing)
	var c: Vector2 = off.round()
	if beak_stuck:
		var mud_pt: Vector2 = (c + fwd * 10.0 + Vector2(0.0, 3.0)).round()
		if _sprite_sheet == null:
			draw_line(c, mud_pt, PAL["apricot"] as Color, 2.0)
		var rp: float = fmod(anim_t * 1.6, 1.0)
		var rp2: float = fmod(rp + 0.5, 1.0)
		draw_arc(mud_pt, 3.5, 0.0, TAU, 12, PAL["pine"] as Color, 1.4)
		draw_arc(mud_pt, 4.5 + rp * 5.5, 0.0, TAU, 16, PAL["blue"] as Color, 1.4)
		draw_arc(mud_pt, 3.5 + rp2 * 4.5, 0.0, TAU, 14, PAL["sky"] as Color, 1.0)
		draw_rect(Rect2(mud_pt + Vector2(-4.0, -2.0), Vector2(1.0, 1.0)), PAL["sky"] as Color, true)
		draw_rect(Rect2(mud_pt + Vector2(4.0, -1.0), Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
	elif _sprite_sheet == null:
		# Tall wading neck crest & long spear beak silhouette.
		var neck_top: Vector2 = off + Vector2(0.0, -body_radius - 5.0)
		draw_line(off + Vector2(0.0, -3.0), neck_top, PAL["ice"] as Color, 2.5)
		draw_line(neck_top, neck_top + fwd * 11.0, PAL["apricot"] as Color, 1.8)
	if state == State.TELL:
		var locked: bool = state_timer <= LOCK_CUTOFF * _assist_tell_scale()
		var tgt: Vector2 = (c + stab_dir * stab_len).round()
		var cue_c: Color = (PAL["coral"] as Color) if locked else (PAL["gold"] as Color)
		draw_line(c, tgt, cue_c, 1.4 if locked else 1.0)
		var arm: float = 5.0 if locked else 3.5
		var in_a: float = 3.0 if locked else 2.0
		draw_line(tgt + Vector2(-arm, 0.0), tgt + Vector2(arm, 0.0), PAL["gold"] as Color, 1.2)
		draw_line(tgt + Vector2(0.0, -arm), tgt + Vector2(0.0, arm), PAL["gold"] as Color, 1.2)
		draw_line(tgt + Vector2(-in_a, 0.0), tgt + Vector2(in_a, 0.0), PAL["ice"] as Color, 1.0)
		draw_line(tgt + Vector2(0.0, -in_a), tgt + Vector2(0.0, in_a), PAL["ice"] as Color, 1.0)
		if locked:
			draw_arc(tgt, 3.5, 0.0, TAU, 8, PAL["ice"] as Color, 1.0)
		draw_rect(Rect2(tgt, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT:
		var perp: Vector2 = Vector2(-stab_dir.y, stab_dir.x)
		var tail: Vector2 = (c - stab_dir * 18.0).round()
		var tip: Vector2 = (c + stab_dir * 16.0).round()
		draw_line(tail, (c + stab_dir * 13.0).round(), PAL["sky"] as Color, 3.5)
		draw_line((c - stab_dir * 13.0).round(), tip, PAL["ice"] as Color, 2.0)
		draw_line((c - stab_dir * 7.0).round(), (tip + stab_dir * 2.0).round(), PAL["cream"] as Color, 1.0)
		draw_line((c + stab_dir * 8.0 + perp * 3.0).round(), tip, PAL["sky"] as Color, 1.0)
		draw_line((c + stab_dir * 8.0 - perp * 3.0).round(), tip, PAL["sky"] as Color, 1.0)
		draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
