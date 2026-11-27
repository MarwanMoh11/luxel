class_name LxSporecapBrain
extends LxEnemyBrain
## Sporecap (Island 3): burrows/surfaces routine; swells cap (0.55s tell), emits a
## radial spore shockwave ring (source="shockwave"), and leaves cap wide open in
## 1.30s recovery (takes 1.5x damage while open; invulnerable/reduced while burrowed).

const RING_START_R: float = 8.0
const RING_MAX_R: float = 64.0
const RING_BAND: float = 9.0
const COMMIT_TIME: float = 0.34
const ATTACK_RANGE: float = 70.0
const POST_COOLDOWN: float = 1.05
const OPEN_DMG_MULT: float = 1.5
const BURROW_PHASE_TIME: float = 1.5
const SURFACE_PHASE_TIME: float = 2.2
const COMBAT_BURROW_TIME: float = 0.85

var burrowed: bool = false
var cap_open: bool = false
var combat_burrowing: bool = false
var burrow_t: float = SURFACE_PHASE_TIME
var burrow_goal: Vector2 = Vector2.ZERO
var ring_progress: float = 0.0
var ring_hit: bool = false
var _recover_count: int = 0


func _init() -> void:
	kind = "sporecap"
	island_id = 3
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 28.0
	leash_radius = 148.0
	notice_radius = 122.0
	tell_time = 0.55
	recover_time = 1.30
	give_up_time = 1.8
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	burrowed = false
	cap_open = false
	combat_burrowing = false
	burrow_t = SURFACE_PHASE_TIME
	burrow_goal = home
	ring_progress = 0.0
	ring_hit = false
	_recover_count = 0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])

	# Burrowed underground: SOURCE_BEAM unearths for 1.0x + instant cap_open stagger;
	# other light bolts are blocked; other heavy/pierce deals 0.25x and unearths.
	var beam_unearthed: bool = false
	if burrowed:
		if src == LxHit.SOURCE_BEAM:
			burrowed = false
			combat_burrowing = false
			cap_open = true
			beam_unearthed = true
			_emit_sfx("sporecap_surface")
		elif not is_heavy and not pierce and not cracks:
			clank_t = 0.12
			_emit_sfx("sporecap_burrow_block")
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED
		else:
			dmg *= 0.25
			burrowed = false
			combat_burrowing = false
			state = State.NOTICE
			state_timer = 0.30

	var is_open_hit: bool = (cap_open or state == State.RECOVER) and not beam_unearthed
	if is_open_hit:
		dmg *= OPEN_DMG_MULT

	hp -= dmg
	flash_t = 0.15 if (is_open_hit or is_heavy or beam_unearthed) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (95.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = is_open_hit or beam_unearthed or state == State.STAGGER
		_die(hit)
		return HitResult.KILLED

	if beam_unearthed:
		_release_token()
		cap_open = true
		state = State.STAGGER
		state_timer = 0.75
		LxDamageFx.boss_impact(pos, 0.12, 54.0, 60.0, 48.0, 1.25, 0.26)
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy and not is_open_hit:
		_release_token()
		cap_open = true
		state = State.STAGGER
		state_timer = 0.50
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		burrowed = false
		combat_burrowing = false
		state = State.NOTICE
		state_timer = 0.30
		alert_t = 0.75
	var res: int = HitResult.OPENED if is_open_hit else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			cap_open = false
			combat_burrowing = false
			_step_routine(dt)
			if _sees_target(target_pos):
				burrowed = false
				state = State.NOTICE
				state_timer = 0.32
				alert_t = 0.8
				lost_t = 0.0
				_emit_sfx("sporecap_surface")
		State.NOTICE:
			burrowed = false
			combat_burrowing = false
			_face_point(target_pos, 3.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			cap_open = false
			if combat_burrowing:
				_step_combat_burrow(dt)
			else:
				burrowed = false
				_step_position(dt, target_pos)
		State.TELL:
			burrowed = false
			combat_burrowing = false
			cap_open = false
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			cap_open = true
			state_timer -= dt
			if state_timer <= 0.0:
				cap_open = false
				_release_token()
				cooldown = POST_COOLDOWN
				_recover_count += 1
				var wick_p: Vector2 = _get_wick_pos()
				var should_return: bool = not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0)
				if should_return:
					state = State.RETURN
				elif _recover_count % 2 == 1:
					_start_combat_burrow()
				else:
					state = State.POSITION
		State.STAGGER:
			combat_burrowing = false
			state_timer -= dt
			if state_timer <= 0.0:
				cap_open = false
				_release_token()
				state = State.POSITION
		State.RETURN:
			cap_open = false
			combat_burrowing = false
			burrowed = true
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				burrowed = false
				burrow_t = SURFACE_PHASE_TIME
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_move_step(to_h.limit_length(routine_speed * dt), false)
				facing = to_h.angle()


func _start_combat_burrow() -> void:
	combat_burrowing = true
	burrowed = true
	burrow_t = COMBAT_BURROW_TIME
	var ang: float = _randf_range(-PI, PI)
	var dist_b: float = _randf_range(26.0, 44.0)
	var candidate: Vector2 = pos + Vector2.from_angle(ang) * dist_b
	var cap: float = maxf(0.0, leash_radius - 10.0)
	if candidate.distance_to(home) > cap:
		candidate = home + (candidate - home).normalized() * cap
	burrow_goal = candidate
	state = State.POSITION
	_emit_sfx("sporecap_burrow")


func _step_combat_burrow(dt: float) -> void:
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
		lost_t += dt
		if lost_t >= give_up_time:
			combat_burrowing = false
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0
	burrow_t -= dt
	var to_g: Vector2 = burrow_goal - pos
	if to_g.length() > 2.0:
		var spd: float = minf(routine_speed * 0.85, routine_speed - 1.5)
		_move_step(to_g.limit_length(spd * dt), false)
		facing = to_g.angle()
	if burrow_t <= 0.0:
		combat_burrowing = false
		burrowed = false
		_emit_sfx("sporecap_surface")


func _step_routine(dt: float) -> void:
	burrow_t -= dt
	if burrowed:
		var to_g: Vector2 = burrow_goal - pos
		if to_g.length() > 2.0:
			_move_step(to_g.limit_length(routine_speed * 0.82 * dt), false)
			facing = to_g.angle()
		if burrow_t <= 0.0:
			burrowed = false
			burrow_t = SURFACE_PHASE_TIME
			_emit_sfx("sporecap_surface")
	elif burrow_t <= 0.0:
		burrowed = true
		burrow_t = BURROW_PHASE_TIME
		var ang: float = _randf_range(-PI, PI)
		var r: float = _randf_range(12.0, minf(36.0, leash_radius * 0.4))
		burrow_goal = home + Vector2.from_angle(ang) * r
		_emit_sfx("sporecap_burrow")


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

	if is_lead and cooldown <= 0.0 and dist <= ATTACK_RANGE and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("sporecap_swell")
		return

	if dist > ATTACK_RANGE * 0.72:
		var spd: float = minf(routine_speed * 0.85, routine_speed - 1.5)
		_move_step(to_t.normalized() * spd * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	cap_open = true
	ring_progress = 0.0
	ring_hit = false
	LxDamageFx.boss_impact(pos, 0.12, 68.0, 74.0, 58.0, 1.28, 0.28)
	_emit_sfx("sporecap_burst")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if state_timer <= 0.0:
		state = State.RECOVER
		cap_open = true
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _emit_shockwave_hit(hit_dir: Vector2) -> void:
	var saved_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(hit_dir)
	kind = saved_kind


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
	if burrowed:
		return PAL["dusk"] as Color
	if cap_open:
		return PAL["gold"] as Color
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	if burrowed:
		draw_arc(off + Vector2(0.0, 2.0), body_radius + 1.0, PI, TAU, 12, PAL["pine"] as Color, 3.0)
		return
	var swell: float = 0.0
	if state == State.TELL:
		swell = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
	if _sprite_sheet == null:
		var cap_r: float = body_radius + 2.5 + swell * 3.5
		var cap_c: Color = (PAL["coral"] as Color) if state == State.TELL else (PAL["wine"] as Color)
		draw_circle(off + Vector2(0.0, -3.0), cap_r, PAL["night"] as Color)
		draw_circle(off + Vector2(0.0, -3.0), cap_r - 1.0, cap_c)
		draw_circle(off + Vector2(-2.5, -4.5), 1.5, PAL["lime"] as Color)
		draw_circle(off + Vector2(2.5, -2.5), 1.5, PAL["lime"] as Color)

	if state == State.TELL:
		var c: Vector2 = off.round()
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, RING_MAX_R, a0, a0 + 0.24, 3, PAL["jade"] as Color, 1.0)
		var hot_s: bool = state_timer <= 0.18 * _assist_tell_scale()
		draw_arc(c, lerpf(RING_MAX_R * 0.75, RING_START_R + 4.0, swell), 0.0, TAU, 24, (PAL["cream"] if hot_s else PAL["lime"]) as Color, 2.0 if hot_s else 1.0)
	elif state == State.COMMIT:
		var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
		var c: Vector2 = off.round()
		draw_arc(c, ring_r + 2.0, 0.0, TAU, 28, PAL["pine"] as Color, 3.0)
		draw_arc(c, ring_r, 0.0, TAU, 28, PAL["jade"] as Color, 2.0)
		draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 24, PAL["lime"] as Color, 1.0)
		var lift: float = -sin(ring_progress * PI) * 3.0
		for mi: int in range(6):
			var ma: float = float(mi) * (TAU / 6.0) + ring_progress * 0.85 + sin(anim_t * 6.0 + float(mi)) * 0.14
			var mr: float = ring_r + sin(float(mi) * 1.9 + ring_progress * 6.0) * 3.5
			var mp: Vector2 = (c + Vector2.from_angle(ma) * mr + Vector2(0.0, lift)).round()
			if mi % 2 == 0:
				draw_rect(Rect2(mp, Vector2(2.0, 2.0)), PAL["lime"] as Color, true)
				draw_rect(Rect2(mp, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
			else:
				draw_rect(Rect2(mp + Vector2(1.0, 1.0), Vector2(1.0, 1.0)), PAL["jade"] as Color, true)
				draw_rect(Rect2(mp, Vector2(1.0, 1.0)), PAL["lime"] as Color, true)
	elif cap_open:
		if _sprite_sheet == null:
			draw_circle(off + Vector2(0.0, -3.0), body_radius * 0.7, PAL["gold"] as Color)
			draw_circle(off + Vector2(0.0, -3.0), body_radius * 0.35, PAL["cream"] as Color)
		else:
			draw_arc(off, body_radius + 3.0, 0.0, TAU, 20, PAL["gold"] as Color, 2.0)
