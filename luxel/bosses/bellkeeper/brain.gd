class_name LxBellkeeperBoss
extends LxWardenBrain
## Grand Bellkeeper Boss (Island 1): 3-phase keeper at Act I parity + Phase 3 frantic chime tempo.
## Phase 1: Bell Slam expanding ring (tell 0.66s / recover 1.35s).
## Phase 2 (<= 50% HP): Belfry Wakes roar + Double-Toll slam + add spawn request sharing LxAttackDirector.
## Phase 3 (<= 20% HP): Frantic chime tempo while strictly obeying all 7.4 tell/recover floors.

signal add_spawn_requested(specs: Array[Dictionary], boss: LxEnemyBrain)

const SLAM_WINDUP_P1: float = 0.66
const SLAM_WINDUP_P3: float = 0.52
const DOUBLE_TOLL_GAP: float = 0.44
const DOUBLE_TOLL_GAP_P3: float = 0.38
const SLAM_FIRE_TIME: float = 0.26
const SLAM_RECOVER_P1: float = 1.35
const DOUBLE_TOLL_RECOVER_P2: float = 1.45
const DOUBLE_TOLL_RECOVER_P3: float = 1.05
const PHASE2_ROAR_TIME: float = 0.80
const SLAM_START_R: float = 8.0
const SLAM_MAX_R: float = 66.0
const SLAM_BAND: float = 9.5
const SLAM_CD_P1: float = 4.2
const SLAM_CD_P2: float = 3.0
const SLAM_CD_P3: float = 2.2

enum SlamStage { NONE, RING_1, TOLL_PAUSE, RING_2 }

var slam_attack: bool = false
var slam_stage: int = SlamStage.NONE
var slam_cd: float = 1.8
var slam_progress: float = 0.0
var slam_hit: bool = false
var double_toll_enabled: bool = false
var swings_since_slam: int = 0
var _roaring: bool = false
var _adds_requested: bool = false


func _init() -> void:
	kind = "bellkeeper"
	boss_id = "bellkeeper"
	island_id = 1
	is_boss = true
	max_hp = 10.0
	hp = 10.0
	shield_max = 2.8
	shield_hp = 2.8
	shield_gone_duration = 4.8
	body_radius = 7.0
	routine_speed = 42.0
	leash_radius = 185.0
	notice_radius = 150.0
	reach = 42.0
	lunge_reach = 108.0
	swing_r = 33.0
	swing_arc = 1.32
	tell_time = 0.48
	lunge_tell_time = 0.52
	recover_time = 1.15
	shard_drop = 25


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "bellkeeper"))
	island_id = int(spec.get("island_id", 1))
	slam_attack = false
	slam_stage = SlamStage.NONE
	slam_cd = 1.8
	slam_progress = 0.0
	slam_hit = false
	double_toll_enabled = false
	swings_since_slam = 0
	_roaring = false
	_adds_requested = false


func _step_brain(dt: float) -> void:
	slam_cd = maxf(0.0, slam_cd - dt)
	super._step_brain(dt)


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.4, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false
		state = State.POSITION
		step_clock = 0.0
		cooldown = 0.35


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		_enter_phase2()
		return true
	if phase < 3 and hp <= max_hp * 0.20 and hp > 0.001:
		_enter_phase3()
		return false
	return false


func _enter_phase2() -> void:
	phase = 2
	double_toll_enabled = true
	wary = false
	_roaring = true
	slam_attack = false
	slam_stage = SlamStage.NONE
	lunge_attack = false
	is_counter_attack = false
	slam_progress = 0.0
	_release_token()
	state = State.NOTICE
	state_timer = PHASE2_ROAR_TIME
	slam_cd = 0.75
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, 2)
		Lx.events.shake_requested.emit(0.35)
	_emit_sfx("bellkeeper_phase2_roar")
	_request_phase2_adds()


func _enter_phase3() -> void:
	phase = 3
	double_toll_enabled = true
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, 3)
		Lx.events.shake_requested.emit(0.25)
	_emit_sfx("bellkeeper_phase3_chime")


func _request_phase2_adds() -> void:
	if _adds_requested:
		return
	_adds_requested = true
	var r: float = minf(72.0, leash_radius * 0.5)
	var specs: Array[Dictionary] = [
		{
			"kind": "snatcher",
			"home": home + Vector2(-r, -r * 0.5),
			"pos": home + Vector2(-r, -r * 0.5),
			"leash_radius": leash_radius * 0.75,
			"zone": zone,
		},
		{
			"kind": "owl",
			"home": home + Vector2(r, -r * 0.5),
			"pos": home + Vector2(r, -r * 0.5),
			"orbit_center": home,
			"start_airborne": true,
			"leash_radius": leash_radius * 0.85,
			"zone": zone,
		},
	]
	add_spawn_requested.emit(specs, self)
	if world_ctx != null and world_ctx.has_method("spawn_boss_adds"):
		world_ctx.call("spawn_boss_adds", specs, director)


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if slam_cd <= 0.0 and (phase >= 2 or swings_since_slam >= 1) and dist < SLAM_MAX_R + 16.0 \
			and _claim_token():
		slam_attack = true
		slam_stage = SlamStage.NONE
		lunge_attack = false
		is_counter_attack = false
		state = State.TELL
		var base_t: float = SLAM_WINDUP_P3 if phase >= 3 else SLAM_WINDUP_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		slam_progress = 0.0
		slam_hit = false
		swings_since_slam = 0
		_emit_attack_started()
		_emit_sfx("bellkeeper_slam_windup")
		return true
	slam_attack = false
	slam_stage = SlamStage.NONE
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if slam_attack:
		state = State.COMMIT
		slam_stage = SlamStage.RING_1
		state_timer = SLAM_FIRE_TIME
		slam_progress = 0.0
		slam_hit = false
		_emit_sfx("bellkeeper_slam_fire")
		return
	swings_since_slam += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not slam_attack:
		super._step_commit(dt)
		return
	match slam_stage:
		SlamStage.RING_1, SlamStage.RING_2:
			state_timer = maxf(0.0, state_timer - dt)
			slam_progress = 1.0 - clampf(state_timer / SLAM_FIRE_TIME, 0.0, 1.0)
			var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, slam_progress)
			if not slam_hit and _has_player():
				var wv: Vector2 = _get_wick_pos() - pos
				if absf(wv.length() - ring_r) <= SLAM_BAND:
					slam_hit = true
					var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
					_emit_player_hit(push)
			if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
				if Lx.events != null:
					Lx.events.lantern_struck.emit(_get_lantern_pos())
			if state_timer <= 0.0:
				if slam_stage == SlamStage.RING_1 and double_toll_enabled:
					slam_stage = SlamStage.TOLL_PAUSE
					var pause_base: float = DOUBLE_TOLL_GAP_P3 if phase >= 3 else DOUBLE_TOLL_GAP
					state_timer = _scaled_tell(pause_base, false, attack_damage)
					slam_progress = 0.0
					slam_hit = false
					_emit_sfx("bellkeeper_double_toll")
				else:
					_finish_slam_into_recover()
		SlamStage.TOLL_PAUSE:
			state_timer -= dt
			if state_timer <= 0.0:
				slam_stage = SlamStage.RING_2
				state_timer = SLAM_FIRE_TIME
				slam_progress = 0.0
				slam_hit = false
				_emit_sfx("bellkeeper_slam_fire")
		_:
			_finish_slam_into_recover()


func _finish_slam_into_recover() -> void:
	slam_attack = false
	slam_stage = SlamStage.NONE
	slam_progress = 0.0
	state = State.RECOVER
	var rec: float = SLAM_RECOVER_P1
	if phase >= 3:
		rec = DOUBLE_TOLL_RECOVER_P3
	elif phase >= 2:
		rec = DOUBLE_TOLL_RECOVER_P2
	state_timer = maxf(MIN_RECOVER_TIME, rec)
	last_recover_duration = state_timer
	slam_cd = SLAM_CD_P3 if phase >= 3 else (SLAM_CD_P2 if phase >= 2 else SLAM_CD_P1)


func _swing_tell_base() -> float:
	if phase >= 3:
		return 0.40
	return tell_time


func _lunge_tell_base() -> float:
	if phase >= 3:
		return 0.45
	return lunge_tell_time


func _swing_recover_duration() -> float:
	if phase >= 3:
		return 0.85
	return recover_time


func _post_recover_cooldown() -> float:
	if phase >= 3:
		return 0.55
	if phase >= 2:
		return 0.75
	return 0.95


func _body_color() -> Color:
	if phase >= 3:
		return PAL["coral"] as Color
	if phase >= 2:
		return PAL["wine"] as Color
	return PAL["plum"] as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# 3-pronged brass crown silhouette
		draw_line(off + Vector2(-4.0, -body_radius), off + Vector2(-5.0, -body_radius - 4.0), PAL["gold"] as Color, 1.5)
		draw_line(off + Vector2(0.0, -body_radius), off + Vector2(0.0, -body_radius - 5.0), PAL["gold"] as Color, 1.5)
		draw_line(off + Vector2(4.0, -body_radius), off + Vector2(5.0, -body_radius - 4.0), PAL["gold"] as Color, 1.5)

	if slam_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var r: float = lerpf(SLAM_MAX_R, SLAM_START_R + 6.0, prog)
		draw_arc(off, r, 0.0, TAU, 28, PAL["gold"] as Color, 1.5)
		if double_toll_enabled:
			draw_arc(off, maxf(4.0, r * 0.6), 0.0, TAU, 20, PAL["coral"] as Color, 1.0)
	elif slam_attack and state == State.COMMIT:
		if slam_stage == SlamStage.TOLL_PAUSE:
			var pr: float = SLAM_MAX_R * 0.5 + 2.0 * sin(anim_t * 18.0)
			draw_arc(off, pr + 2.0, 0.0, TAU, 24, PAL["apricot"] as Color, 1.8)
			draw_arc(off, pr, 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
			for ti: int in range(4):
				var td: Vector2 = Vector2.from_angle(float(ti) * (TAU * 0.25))
				draw_line((off + td * (pr - 3.0)).round(), (off + td * (pr + 4.0)).round(), PAL["cream"] as Color, 1.2)
		else:
			var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, slam_progress)
			draw_arc(off, ring_r + 3.0, 0.0, TAU, 36, PAL["apricot"] as Color, 2.2)
			draw_arc(off, ring_r, 0.0, TAU, 36, PAL["gold"] as Color, 3.4)
			draw_arc(off, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
			if ring_r > 14.0:
				draw_arc(off, ring_r - 6.0, 0.0, TAU, 24, PAL["coral"] as Color, 1.1)
			for ci: int in range(8):
				var ca: float = anim_t * 2.2 + float(ci) * (TAU / 8.0)
				var cd: Vector2 = Vector2.from_angle(ca)
				var cp: Vector2 = (off + cd * (ring_r + 1.5)).round()
				draw_line((off + cd * maxf(2.0, ring_r - 2.0)).round(), (off + cd * (ring_r + 6.0)).round(), PAL["apricot"] as Color, 1.2)
				draw_circle(cp, 2.0, PAL["gold"] as Color)
				draw_circle(cp, 1.0, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 18.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
		for ri: int in range(4):
			var rd: Vector2 = Vector2.from_angle(float(ri) * (TAU * 0.25))
			draw_line((off + rd * (rr - 3.0)).round(), (off + rd * (rr + 4.5)).round(), PAL["cream"] as Color, 1.2)
