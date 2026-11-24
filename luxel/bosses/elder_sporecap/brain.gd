class_name LxElderSporecapBoss
extends LxSporecapBrain
## Thornwood Hollow mini-boss (Island 3): Elder Sporecap.
## 2 phases, HP 7.5. Features Combat Burrow-Reposition (0.85s glowing mycelial trail;
## Beam pierces mound early for instant cap_open stagger) and P2 4-Cardinal Spore Lanes!

enum PulseStage { RING_1, PAUSE, CARDINAL_LANES }

const ELDER_RING_MAX_R: float = 84.0
const ELDER_RING_BAND: float = 10.0
const ELDER_ATTACK_RANGE: float = 90.0
const ELDER_COMMIT_TIME: float = 0.36
const LANE_PAUSE_TIME: float = 0.45
const LANE_COMMIT_TIME: float = 0.38
const LANE_MAX_RANGE: float = 96.0
const LANE_HALF_W: float = 11.0
const ELDER_BURROW_TIME: float = 0.85
const PHASE2_ROAR_TIME: float = 0.58

var pulse_stage: int = PulseStage.RING_1
var lane_base_ang: float = 0.0
var lane_progress: float = 0.0
var lane_hit: bool = false
var _mycelial_trail: Array[Vector2] = []
var _trail_sample_t: float = 0.0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "elder_sporecap"
	boss_id = "elder_sporecap"
	island_id = 3
	is_boss = true
	max_hp = 7.5
	hp = 7.5
	body_radius = 7.5
	routine_speed = 30.0
	leash_radius = 165.0
	notice_radius = 136.0
	tell_time = 0.56
	recover_time = 1.25
	give_up_time = 1.8
	shard_drop = 14


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "elder_sporecap"))
	island_id = int(spec.get("island_id", 3))
	pulse_stage = PulseStage.RING_1
	lane_base_ang = facing
	lane_progress = 0.0
	lane_hit = false
	_mycelial_trail.clear()
	_trail_sample_t = 0.0
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var res: int = super.take_hit(hit)
	if not burrowed:
		_mycelial_trail.clear()
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		burrowed = false
		combat_burrowing = false
		_mycelial_trail.clear()
		cap_open = false
		_roaring = true
		pulse_stage = PulseStage.RING_1
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.24, 92.0, 90.0)
		_emit_sfx("elder_sporecap_phase2")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		burrowed = false
		combat_burrowing = false
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _start_combat_burrow() -> void:
	combat_burrowing = true
	burrowed = true
	burrow_t = ELDER_BURROW_TIME
	_mycelial_trail.clear()
	_mycelial_trail.append(pos)
	_trail_sample_t = 0.0
	var to_w: Vector2 = _attention_target() - pos
	var base_a: float = to_w.angle() if to_w.length() > 0.01 else facing
	var side_a: float = base_a + (PI * 0.55 if (_recover_count % 2 == 1) else -PI * 0.55)
	var candidate: Vector2 = pos + Vector2.from_angle(side_a) * _randf_range(34.0, 52.0)
	var cap: float = maxf(0.0, leash_radius - 12.0)
	if candidate.distance_to(home) > cap:
		candidate = home + (candidate - home).normalized() * cap
	burrow_goal = candidate
	state = State.POSITION
	_emit_sfx("sporecap_burrow")


func _step_combat_burrow(dt: float) -> void:
	_trail_sample_t -= dt
	if _trail_sample_t <= 0.0:
		_trail_sample_t = 0.09
		_mycelial_trail.append(pos)
		if _mycelial_trail.size() > 14:
			_mycelial_trail.pop_front()
	super._step_combat_burrow(dt)
	if not combat_burrowing:
		_mycelial_trail.clear()


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 2.6, dt)

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

	if is_lead and cooldown <= 0.0 and dist <= ELDER_ATTACK_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		var base_t: float = 0.50 if phase >= 2 else tell_time
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		lane_base_ang = to_t.angle() if dist > 0.01 else facing
		_emit_attack_started()
		_emit_sfx("elder_sporecap_swell")
		return

	if dist > ELDER_ATTACK_RANGE * 0.70:
		var spd: float = minf(routine_speed * 0.85, routine_speed - 1.5)
		_move_step(to_t.normalized() * spd * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	pulse_stage = PulseStage.RING_1
	state_timer = ELDER_COMMIT_TIME
	cap_open = true
	ring_progress = 0.0
	ring_hit = false
	lane_progress = 0.0
	lane_hit = false
	_boss_impact(0.18, 92.0, 90.0)
	_emit_sfx("elder_sporecap_burst")


func _step_commit(dt: float) -> void:
	if pulse_stage == PulseStage.PAUSE:
		if state_timer > 0.16:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				lane_base_ang = to_t.angle()
		state_timer -= dt
		if state_timer <= 0.0:
			pulse_stage = PulseStage.CARDINAL_LANES
			state_timer = LANE_COMMIT_TIME
			lane_progress = 0.0
			lane_hit = false
			_boss_impact(0.20, 98.0, 96.0)
			_emit_sfx("elder_sporecap_burst")
		return

	if pulse_stage == PulseStage.CARDINAL_LANES:
		state_timer = maxf(0.0, state_timer - dt)
		lane_progress = 1.0 - clampf(state_timer / LANE_COMMIT_TIME, 0.0, 1.0)
		var cur_len: float = lerpf(10.0, LANE_MAX_RANGE, lane_progress)
		if not lane_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			for li: int in range(4):
				var ldir: Vector2 = Vector2.from_angle(lane_base_ang + float(li) * (PI * 0.5))
				var lend: Vector2 = pos + ldir * cur_len
				if Geometry2D.get_closest_point_to_segment(wp, pos, lend).distance_to(wp) <= LANE_HALF_W:
					lane_hit = true
					_emit_player_hit(ldir)
					break
		if _is_lured():
			var lp: Vector2 = _get_lantern_pos()
			for li: int in range(4):
				var ldir_l: Vector2 = Vector2.from_angle(lane_base_ang + float(li) * (PI * 0.5))
				if Geometry2D.get_closest_point_to_segment(lp, pos, pos + ldir_l * cur_len).distance_to(lp) <= LANE_HALF_W + 2.0:
					if Lx.events != null:
						Lx.events.lantern_struck.emit(lp)
					break
		if state_timer <= 0.0:
			pulse_stage = PulseStage.RING_1
			state = State.RECOVER
			cap_open = true
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer
		return

	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / ELDER_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, ELDER_RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= ELDER_RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if pulse_stage == PulseStage.RING_1 and phase >= 2:
			pulse_stage = PulseStage.PAUSE
			state_timer = _scaled_tell(LANE_PAUSE_TIME, false, attack_damage)
			lane_progress = 0.0
			lane_hit = false
			var to_t2: Vector2 = _attention_target() - pos
			if to_t2.length() > 0.01:
				lane_base_ang = to_t2.angle()
			_emit_sfx("elder_sporecap_swell")
		else:
			pulse_stage = PulseStage.RING_1
			state = State.RECOVER
			cap_open = true
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _body_color() -> Color:
	if burrowed:
		return PAL["dusk"] as Color
	if cap_open:
		return PAL["gold"] as Color
	return (PAL["wine"] as Color) if phase >= 2 else (PAL["plum"] as Color)


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if burrowed:
		# Glowing mycelial burrow trail + vulnerable mound (Beam pierces early!)
		for ti: int in range(_mycelial_trail.size()):
			var tp: Vector2 = (_mycelial_trail[ti] - pos + off).round()
			var col_t: Color = (PAL["lime"] if ti % 2 == 0 else PAL["jade"]) as Color
			draw_circle(tp, 2.2 if ti == _mycelial_trail.size() - 1 else 1.5, col_t)
			if ti > 0:
				var prev_tp: Vector2 = (_mycelial_trail[ti - 1] - pos + off).round()
				draw_line(prev_tp, tp, PAL["jade"] as Color, 1.4)
		draw_arc(c + Vector2(0.0, 2.0), body_radius + 1.5, PI, TAU, 14, PAL["pine"] as Color, 2.8)
		draw_arc(c + Vector2(0.0, 1.0), body_radius + 0.5, PI, TAU, 12, PAL["lime"] as Color, 1.2)
		return
	var swell: float = 0.0
	if state == State.TELL:
		swell = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
	if _sprite_sheet == null:
		var cap_r: float = body_radius + 3.5 + swell * 4.0
		draw_circle(off + Vector2(0.0, -4.0), cap_r, PAL["night"] as Color)
		draw_circle(off + Vector2(0.0, -4.0), cap_r - 1.2, (PAL["coral"] as Color) if phase >= 2 else (PAL["wine"] as Color))
		draw_circle(off + Vector2(0.0, -6.5), cap_r * 0.55, PAL["plum"] as Color)
		draw_circle(off + Vector2(-3.5, -5.0), 1.8, PAL["lime"] as Color)
		draw_circle(off + Vector2(3.5, -3.5), 1.8, PAL["lime"] as Color)

	if state == State.TELL:
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, ELDER_RING_MAX_R, a0, a0 + 0.24, 3, PAL["jade"] as Color, 1.0)
		var tr: float = lerpf(ELDER_RING_MAX_R * 0.85, RING_START_R + 5.0, swell)
		var pulse: float = 0.0 if LxHudFx.flash_reduced() else 1.4 * sin(anim_t * 20.0)
		var hot: bool = state_timer <= 0.14
		draw_arc(c, tr + 2.2 + pulse * 0.4, 0.0, TAU, 28, (PAL["lime"] if hot else PAL["jade"]) as Color, 1.4)
		draw_arc(c, tr, 0.0, TAU, 28, (PAL["cream"] if hot else PAL["lime"]) as Color, 2.2 if hot else 2.0)
		draw_arc(c, maxf(4.0, tr * 0.62 + pulse * 0.6), 0.0, TAU, 22, (PAL["cream"] if hot else PAL["gold"]) as Color, 1.4)
	elif state == State.COMMIT:
		if pulse_stage == PulseStage.PAUSE:
			var hot_p: bool = state_timer <= 0.16
			var lcol: Color = (PAL["cream"] if hot_p else PAL["lime"]) as Color
			for li: int in range(4):
				var ldir: Vector2 = Vector2.from_angle(lane_base_ang + float(li) * (PI * 0.5))
				var perp: Vector2 = Vector2(-ldir.y, ldir.x)
				var lend: Vector2 = (c + ldir * LANE_MAX_RANGE).round()
				draw_line((c + perp * (LANE_HALF_W * 0.65)).round(), (lend + perp * (LANE_HALF_W * 0.65)).round(), lcol, 1.3 if hot_p else 1.0)
				draw_line((c - perp * (LANE_HALF_W * 0.65)).round(), (lend - perp * (LANE_HALF_W * 0.65)).round(), lcol, 1.3 if hot_p else 1.0)
				draw_line(c, lend, (PAL["gold"] if hot_p else PAL["jade"]) as Color, 1.5)
		elif pulse_stage == PulseStage.CARDINAL_LANES:
			var cur_len: float = lerpf(10.0, LANE_MAX_RANGE, lane_progress)
			for li: int in range(4):
				var ldir: Vector2 = Vector2.from_angle(lane_base_ang + float(li) * (PI * 0.5))
				var lend: Vector2 = (c + ldir * cur_len).round()
				draw_line(c, lend, PAL["pine"] as Color, 8.0)
				draw_line(c, lend, PAL["jade"] as Color, 5.2)
				draw_line(c, lend, PAL["lime"] as Color, 2.8)
				draw_line(c, lend, PAL["cream"] as Color, 1.1)
				draw_circle(lend, 2.4, PAL["lime"] as Color)
				draw_circle(lend, 1.2, PAL["cream"] as Color)
		else:
			var ring_r: float = lerpf(RING_START_R, ELDER_RING_MAX_R, ring_progress)
			draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, PAL["pine"] as Color, 2.4)
			draw_arc(c, ring_r, 0.0, TAU, 36, PAL["jade"] as Color, 3.6)
			draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["lime"] as Color, 2.2)
			draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)
			for pi: int in range(8):
				var pa: float = anim_t * 2.6 + float(pi) * (TAU / 8.0)
				var wob: float = sin(anim_t * 10.0 + float(pi) * 1.6) * 2.6
				var pp: Vector2 = (c + Vector2.from_angle(pa) * (ring_r + wob)).round()
				draw_circle(pp, 2.2, PAL["pine"] as Color)
				draw_circle(pp, 1.4, PAL["lime"] as Color)
				draw_circle(pp, 0.7, PAL["cream"] as Color)
	elif cap_open:
		if _sprite_sheet == null:
			draw_circle(off + Vector2(0.0, -4.0), body_radius * 0.72, PAL["gold"] as Color)
			draw_circle(off + Vector2(0.0, -4.0), body_radius * 0.35, PAL["cream"] as Color)
		else:
			var vr: float = body_radius + 4.0 + (0.0 if LxHudFx.flash_reduced() else 0.8 * sin(anim_t * 14.0))
			draw_arc(c, vr + 1.4, 0.0, TAU, 24, PAL["apricot"] as Color, 1.2)
			draw_arc(c, vr, 0.0, TAU, 24, PAL["gold"] as Color, 1.8)
			for vi: int in range(4):
				var vd: Vector2 = Vector2.from_angle(anim_t * 1.5 + float(vi) * (TAU * 0.25))
				draw_circle((c + vd * (vr + 1.5)).round(), 1.1, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.2, 0.0, TAU, 28, PAL["jade"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["lime"] as Color, 2.4)
		draw_arc(c, maxf(3.0, rr - 2.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.08, 1.38, 0.36)
