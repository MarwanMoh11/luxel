class_name LxTideCaptainBoss
extends LxCrabWardenBrain
## Tidewater Harbor mini-boss (Island 2): elite Tide Captain Crab Warden.
## 2 phases, HP 8.0, claw shield 2.6. Sidesteps with heavy pinch lunges + Tide Breaker shockwave slam.
## Prism bank shots curve cleanly around its captain claw shield.

const SLAM_TELL_P1: float = 0.58
const SLAM_TELL_P2: float = 0.50
const SLAM_FIRE_TIME: float = 0.26
const SLAM_RECOVER_P1: float = 1.22
const SLAM_RECOVER_P2: float = 1.05
const SLAM_START_R: float = 9.0
const SLAM_MAX_R: float = 62.0
const SLAM_BAND: float = 9.5
const SLAM_CD_P1: float = 4.6
const SLAM_CD_P2: float = 3.2
const PHASE2_ROAR_TIME: float = 0.60

var slam_attack: bool = false
var slam_cd: float = 1.6
var slam_progress: float = 0.0
var slam_hit: bool = false
var swings_since_slam: int = 0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "tide_captain"
	boss_id = "tide_captain"
	island_id = 2
	is_boss = true
	max_hp = 8.0
	hp = 8.0
	shield_max = 2.6
	shield_hp = 2.6
	shield_gone_duration = 4.5
	body_radius = 7.0
	routine_speed = 38.0
	leash_radius = 175.0
	notice_radius = 140.0
	reach = 40.0
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
	boss_id = str(spec.get("boss_id", "tide_captain"))
	island_id = int(spec.get("island_id", 2))
	slam_attack = false
	slam_cd = 1.6
	slam_progress = 0.0
	slam_hit = false
	swings_since_slam = 0
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var res: int = super.take_hit(hit)
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	return _check_phase_transition()


func _check_phase_transition() -> bool:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		wary = false
		_roaring = true
		slam_attack = false
		lunge_attack = false
		is_counter_attack = false
		slam_progress = 0.0
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max * 0.55
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		slam_cd = 0.85
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
			Lx.events.shake_requested.emit(0.26)
		_emit_sfx("tide_captain_phase2")
		return true
	return false


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


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if slam_cd <= 0.0 and (phase >= 2 or swings_since_slam >= 1) and dist < SLAM_MAX_R + 16.0 \
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
		_emit_sfx("tide_captain_slam_tell")
		return true
	slam_attack = false
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if slam_attack:
		state = State.COMMIT
		state_timer = SLAM_FIRE_TIME
		slam_progress = 0.0
		slam_hit = false
		_emit_sfx("tide_captain_slam_fire")
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
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		slam_attack = false
		slam_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SLAM_RECOVER_P2 if phase >= 2 else SLAM_RECOVER_P1)
		last_recover_duration = state_timer
		slam_cd = SLAM_CD_P2 if phase >= 2 else SLAM_CD_P1


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir)
	kind = prev_kind


func _swing_tell_base() -> float:
	return 0.42 if phase >= 2 else tell_time


func _lunge_tell_base() -> float:
	return 0.48 if phase >= 2 else lunge_tell_time


func _post_recover_cooldown() -> float:
	return 0.72 if phase >= 2 else 0.92


func _body_color() -> Color:
	return (PAL["wine"] as Color) if phase >= 2 else (PAL["coral"] as Color)


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if _sprite_sheet == null:
		# Naval bicorne hat silhouette
		var hat_y: float = -body_radius - 2.0
		draw_line(off + Vector2(-7.0, hat_y), off + Vector2(7.0, hat_y), PAL["deep"] as Color, 3.0)
		draw_line(off + Vector2(-4.5, hat_y - 2.5), off + Vector2(4.5, hat_y - 2.5), PAL["gold"] as Color, 1.5)
	var c: Vector2 = off.round()
	if slam_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, SLAM_MAX_R, a0, a0 + 0.24, 3, PAL["blue"] as Color, 1.0)
		var tr: float = lerpf(SLAM_MAX_R, SLAM_START_R + 6.0, prog)
		var pulse: float = 1.2 * sin(anim_t * 18.0)
		draw_arc(c, tr + 2.0 + pulse * 0.5, 0.0, TAU, 28, PAL["blue"] as Color, 1.4)
		draw_arc(c, tr, 0.0, TAU, 28, PAL["sky"] as Color, 1.8)
		draw_arc(c, maxf(3.0, tr - 2.2), 0.0, TAU, 24, PAL["ice"] as Color, 1.0)
	elif slam_attack and state == State.COMMIT:
		var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, slam_progress)
		draw_arc(c, ring_r + 3.6, 0.0, TAU, 36, PAL["deep"] as Color, 2.0)
		draw_arc(c, ring_r + 1.8, 0.0, TAU, 36, PAL["blue"] as Color, 2.4)
		draw_arc(c, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.2)
		draw_arc(c, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
		draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)
		for ti: int in range(8):
			var ta: float = anim_t * 2.1 + float(ti) * (TAU / 8.0)
			var td: Vector2 = Vector2.from_angle(ta)
			var tt: Vector2 = Vector2(-td.y, td.x)
			var crest: Vector2 = (c + td * (ring_r + 1.0)).round()
			draw_line((crest - tt * 3.0).round(), (crest + tt * 3.0 + td * 2.4).round(), PAL["ice"] as Color, 1.4)
			draw_circle((crest + td * 1.5).round(), 1.2, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.4, 0.0, TAU, 28, PAL["sky"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.2)
		draw_arc(c, maxf(3.0, rr - 2.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)
