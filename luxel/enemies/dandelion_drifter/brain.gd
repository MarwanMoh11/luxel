class_name LxDandelionDrifterBrain
extends LxEnemyBrain
## Dandelion Drifter (Island 3): Aerial disrupter hovering over pits/water.
## Puffs 3 floating seed-mines (0.48s tell, 0.28s commit, 1.10s recover) that drift
## with LxFields wind/gravity and bloom into thorn-snags when Wick's lantern nears them!
## Counterplay: Bolt pops mines afar, Throw blooms mines safely away, Beam slices line.

const STANDOFF_RANGE: float = 80.0
const PUFF_RANGE: float = 132.0
const COMMIT_TIME: float = 0.28
const MINE_SPEED: float = 48.0
const MINE_MAX_AGE: float = 4.2
const MINE_LIGHT_BLOOM_R: float = 46.0
const MINE_SNAG_R: float = 16.0
const MINE_SNAG_DUR: float = 2.0
const MAX_MINES: int = 6
const POST_COOLDOWN: float = 1.05

var drift_pts: Array[Vector2] = []
var drift_i: int = 0
var mines: Array[Dictionary] = []
var puff_dir: Vector2 = Vector2.RIGHT
var _puff_done: bool = false


func _init() -> void:
	kind = "dandelion_drifter"
	island_id = 3
	max_hp = 2.2
	hp = 2.2
	body_radius = 5.5
	routine_speed = 40.0
	leash_radius = 160.0
	notice_radius = 130.0
	tell_time = 0.48
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	drift_pts.clear()
	var raw_pts: Variant = spec.get("route", spec.get("perches", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				drift_pts.append(_clamp_pt(_to_vec2(pt_v, home)))
	if drift_pts.size() < 2:
		var r: float = minf(46.0, leash_radius * 0.40)
		drift_pts = [
			_clamp_pt(home + Vector2(-r, -16.0)),
			_clamp_pt(home + Vector2(r, -16.0)),
			_clamp_pt(home + Vector2(0.0, 24.0)),
		]
	drift_i = 0
	mines.clear()
	puff_dir = Vector2.from_angle(facing)
	_puff_done = false


func is_flying() -> bool:
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"]) or src == LxHit.SOURCE_BEAM
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	if state == State.TELL or state == State.RECOVER:
		dmg *= 1.25
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.09
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 42.0)
	if hp <= 0.001:
		opened_kill = state == State.RECOVER or state == State.STAGGER or state == State.TELL
		mines.clear()
		_die(hit)
		return HitResult.KILLED
	if is_heavy or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_tick_mines(dt)
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target_pos):
				_enter_notice()
		State.NOTICE:
			_face_point(target_pos, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.0, dt)
				puff_dir = Vector2.from_angle(facing)
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
				cooldown = 0.45
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), true)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.28
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("dandelion_notice")


func _step_routine(dt: float) -> void:
	var wp: Vector2 = drift_pts[drift_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 4.0:
		drift_i = (drift_i + 1) % drift_pts.size()
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.72 * dt), true)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.4, dt)
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

	var can_act: bool = director == null or director.can_claim_ranged_token(self)
	state = State.POSITION if can_act else State.WAIT_TOKEN

	if can_act and cooldown <= 0.0 and dist <= PUFF_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		puff_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = puff_dir.angle()
		_emit_attack_started()
		_emit_sfx("dandelion_tell")
		return

	# Keep ~80 px aerial standoff while orbiting
	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var perp: Vector2 = Vector2(-fwd.y, fwd.x) * (1.0 if slot % 2 == 0 else -1.0)
	var radial: float = clampf((dist - STANDOFF_RANGE) / 36.0, -0.75, 0.60)
	var spd: float = routine_speed * 0.80
	_move_step((perp * 0.72 + fwd * radial).normalized() * spd * dt, true)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_puff_done = false
	_emit_sfx("dandelion_puff")


func _step_commit(dt: float) -> void:
	if not _puff_done:
		_puff_done = true
		for ang_off: float in [-0.46, 0.0, 0.46]:
			if mines.size() >= MAX_MINES:
				mines.pop_front()
			var md: Vector2 = puff_dir.rotated(ang_off).normalized()
			mines.append({
				"pos": pos + md * 8.0,
				"vel": md * MINE_SPEED,
				"age": 0.0,
				"bloomed": false,
				"snag_t": 0.0,
				"hit_cd": 0.0,
			})
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_mines(dt: float) -> void:
	if mines.is_empty():
		return
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	var lp: Vector2 = _get_lantern_pos()
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var beam_on: bool = wick_node != null and wick_node.move_beam != null and wick_node.move_beam.beam_vis_t > 0.0

	for i: int in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		m["age"] = float(m["age"]) + dt
		m["hit_cd"] = maxf(0.0, float(m["hit_cd"]) - dt)
		var mp: Vector2 = m["pos"] as Vector2

		# Counterplay: player bolts or Beam pop floating mines cleanly!
		var popped: bool = false
		if wick_node != null:
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(mp) <= 10.0:
					if not bool(bv.get("is_pierce")):
						wick_node.bolts.remove_at(bi)
					popped = true
					break
			if not popped and beam_on:
				if Geometry2D.get_closest_point_to_segment(mp, wick_node.move_beam.beam_start, wick_node.move_beam.beam_end).distance_to(mp) <= 12.0:
					popped = true
		if popped:
			if wick_node != null:
				wick_node.spawn_sparks(mp, Vector2.UP, 4, PAL["lime"] as Color, 20.0, 60.0, 0.16)
			_emit_sfx("dandelion_pop")
			mines.remove_at(i)
			continue

		if not bool(m["bloomed"]):
			var mv: Vector2 = m["vel"] as Vector2
			if LxFields.has_fields():
				mv += LxFields.accel_at(mp, "bolt") * dt * 0.45
			var spd: float = clampf(mv.length(), 18.0, 96.0)
			if mv.length_squared() > 0.01:
				mv = mv.normalized() * spd
			mp += mv * dt
			m["pos"] = mp
			m["vel"] = mv
			# Blooms into a thorn-snag near Wick's lantern (or on direct contact)!
			var near_light: bool = mp.distance_to(lp) <= MINE_LIGHT_BLOOM_R
			var hit_wall: bool = world_ctx != null and world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", mp)) == "wall"
			if near_light or hit_wall or float(m["age"]) >= MINE_MAX_AGE:
				if hit_wall or float(m["age"]) >= MINE_MAX_AGE:
					mines.remove_at(i)
					continue
				m["bloomed"] = true
				m["snag_t"] = MINE_SNAG_DUR
				_emit_sfx("dandelion_bloom")
		else:
			m["snag_t"] = float(m["snag_t"]) - dt
			if has_p and float(m["hit_cd"]) <= 0.0 and wp.distance_to(mp) <= MINE_SNAG_R:
				m["hit_cd"] = 0.85
				var kdir: Vector2 = (wp - mp).normalized() if wp.distance_to(mp) > 0.1 else Vector2.DOWN
				_emit_player_hit(kdir)
			if float(m["snag_t"]) <= 0.0:
				mines.remove_at(i)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	return home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 22.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _visual_offset() -> Vector2:
	return Vector2(0.0, -3.5 + sin(anim_t * 3.8) * 1.8)


func _body_color() -> Color:
	return PAL["cream"] as Color


func _draw_extra(off: Vector2) -> void:
	var fred: bool = LxHudFx.flash_reduced()
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var r: float = lerpf(16.0, 8.0, prog)
		draw_arc(off.round(), r, 0.0, TAU, 16, PAL["cream"] as Color if prog > 0.6 else PAL["gold"] as Color, 1.4)
	for m: Dictionary in mines:
		var mp: Vector2 = ((m["pos"] as Vector2) - pos).round()
		if bool(m["bloomed"]):
			var frac: float = clampf(float(m["snag_t"]) / MINE_SNAG_DUR, 0.0, 1.0)
			draw_circle(mp, MINE_SNAG_R, Color(PAL["pine"] as Color, 0.30 * frac))
			draw_arc(mp, MINE_SNAG_R, 0.0, TAU, 16, PAL["coral"] as Color, 1.5)
			draw_arc(mp, MINE_SNAG_R - 3.0, 0.0, TAU, 12, PAL["lime"] as Color, 1.0)
		else:
			draw_circle(mp, 4.5, PAL["void"] as Color)
			draw_circle(mp, 3.2, PAL["cream"] as Color)
			draw_circle(mp, 1.5, PAL["gold"] as Color if (fred or int(anim_t * 10.0) % 2 == 0) else PAL["lime"] as Color)
