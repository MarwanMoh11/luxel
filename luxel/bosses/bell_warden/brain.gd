class_name LxBellWardenBoss
extends LxWardenBrain
## Belfry mini-boss (Island 1): elite Bell Warden with expanding Bell Slam ring + hop-lunge.
## 2 phases, HP 7.5, shield 2.4, cleanly obeys all 7.4 invariants.

const SLAM_TELL_P1: float = 0.62
const SLAM_TELL_P2: float = 0.56
const SLAM_FIRE_TIME: float = 0.25
const SLAM_RECOVER_TIME: float = 1.25
const SLAM_START_R: float = 8.0
const SLAM_MAX_R: float = 56.0
const SLAM_BAND: float = 9.0
const SLAM_CD_P1: float = 4.8
const SLAM_CD_P2: float = 3.4
const PHASE2_ROAR_TIME: float = 0.65

var slam_attack: bool = false
var slam_cd: float = 1.5
var slam_progress: float = 0.0
var slam_hit: bool = false
var swings_since_slam: int = 0
var _roaring: bool = false


func _init() -> void:
	kind = "bell_warden"
	boss_id = "bell_warden"
	is_boss = true
	max_hp = 7.5
	hp = 7.5
	shield_max = 2.4
	shield_hp = 2.4
	shield_gone_duration = 4.5
	body_radius = 6.5
	routine_speed = 40.0
	leash_radius = 175.0
	notice_radius = 140.0
	reach = 38.0
	lunge_reach = 100.0
	swing_r = 30.0
	swing_arc = 1.24
	tell_time = 0.48
	lunge_tell_time = 0.54
	recover_time = 1.15
	shard_drop = 12


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "bell_warden"))
	slam_attack = false
	slam_cd = 1.5
	slam_progress = 0.0
	slam_hit = false
	swings_since_slam = 0
	_roaring = false


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
	if phase < 2 and hp <= max_hp * 0.5 and hp > 0.001:
		phase = 2
		wary = false
		_roaring = true
		slam_attack = false
		lunge_attack = false
		slam_progress = 0.0
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		slam_cd = 0.9
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.24, 90.0, 88.0)
		_emit_sfx("bell_warden_phase2")
		return true
	return false


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if slam_cd <= 0.0 and (phase >= 2 or swings_since_slam >= 1) and dist < SLAM_MAX_R + 14.0 \
			and _claim_token():
		slam_attack = true
		lunge_attack = false
		is_counter_attack = false
		state = State.TELL
		var base_t: float = SLAM_TELL_P2 if phase >= 2 else SLAM_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		slam_progress = 0.0
		slam_hit = false
		swings_since_slam = 0
		_emit_attack_started()
		_emit_sfx("bell_slam_windup")
		return true
	slam_attack = false
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if slam_attack:
		state = State.COMMIT
		state_timer = SLAM_FIRE_TIME
		slam_progress = 0.0
		slam_hit = false
		_boss_impact(0.16, 78.0, 82.0)
		_emit_sfx("bell_slam_fire")
		return
	swings_since_slam += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not slam_attack:
		super._step_commit(dt)
		return
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
		slam_attack = false
		slam_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SLAM_RECOVER_TIME)
		last_recover_duration = state_timer
		slam_cd = SLAM_CD_P2 if phase >= 2 else SLAM_CD_P1


func _swing_tell_base() -> float:
	return 0.42 if phase >= 2 else tell_time


func _lunge_tell_base() -> float:
	return 0.50 if phase >= 2 else lunge_tell_time


func _post_recover_cooldown() -> float:
	return 0.75 if phase >= 2 else 0.95


func _body_color() -> Color:
	return PAL["wine"] as Color if phase >= 2 else PAL["plum"] as Color


func _shield_color() -> Color:
	return PAL["apricot"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if slam_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, SLAM_MAX_R, a0, a0 + 0.24, 3, PAL["apricot"] as Color, 1.0)
		var r: float = lerpf(SLAM_MAX_R, SLAM_START_R + 6.0, prog)
		var pulse: float = 1.0 if LxHudFx.flash_reduced() else (1.0 + 0.6 * sin(anim_t * 18.0))
		var hot: bool = state_timer <= 0.14
		draw_arc(c, r + pulse, 0.0, TAU, 28, (PAL["gold"] if hot else PAL["apricot"]) as Color, 1.2)
		draw_arc(c, r, 0.0, TAU, 28, (PAL["cream"] if hot else PAL["gold"]) as Color, 2.0 if hot else 1.8)
		for ti: int in range(4):
			var td: Vector2 = Vector2.from_angle(float(ti) * (TAU * 0.25))
			draw_line((c + td * maxf(2.0, r - 3.5)).round(), (c + td * (r + 3.5)).round(), PAL["cream"] as Color, 1.2)
	elif slam_attack and state == State.COMMIT:
		var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, slam_progress)
		draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, PAL["apricot"] as Color, 2.2)
		draw_arc(c, ring_r, 0.0, TAU, 36, PAL["gold"] as Color, 3.4)
		draw_arc(c, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
		for ci: int in range(8):
			var ca: float = anim_t * 2.2 + float(ci) * (TAU / 8.0)
			var cd: Vector2 = Vector2.from_angle(ca)
			var cp: Vector2 = (c + cd * (ring_r + 1.5)).round()
			draw_line((c + cd * maxf(2.0, ring_r - 2.0)).round(), (c + cd * (ring_r + 5.5)).round(), PAL["apricot"] as Color, 1.2)
			draw_circle(cp, 2.0, PAL["gold"] as Color)
			draw_circle(cp, 1.0, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
		for ri: int in range(4):
			var rd: Vector2 = Vector2.from_angle(float(ri) * (TAU * 0.25))
			draw_line((c + rd * (rr - 3.0)).round(), (c + rd * (rr + 4.0)).round(), PAL["cream"] as Color, 1.2)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.08, 1.38, 0.36)
