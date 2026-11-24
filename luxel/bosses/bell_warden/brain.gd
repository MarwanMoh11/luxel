class_name LxBellWardenBoss
extends LxWardenBrain
## Belfry Mini-Boss #1 (Island 1, belfry_r5): Upgraded Bell Warden.
## Preserves child-acolyte art, parasol shield teaching role, and Sanctuary Pedestal synergy.
## Upgrades to Island 1 Bible:
## - P1/P2 slams telegraph DAWN (wide gold ring) vs WAR (fast coral spike ring + 6 radial bolts).
## - P2 (<= 50% HP): Belfry Resonance Floor awakens + 0.55s Echo Slam pause before Ring 2;
##   ringing a bell (on_ring) or hitting with a heavy/pedestal blow during Echo Pause cancels Ring 2,
##   cracks shield, and opens a 1.8s counter-stagger!

const SLAM_TELL_P1: float = 0.62
const SLAM_TELL_P2: float = 0.56
const SLAM_FIRE_TIME: float = 0.25
const ECHO_PAUSE_TIME: float = 0.55
const SLAM_RECOVER_TIME: float = 1.25
const ECHO_CANCEL_STAGGER: float = 1.80
const SLAM_START_R: float = 8.0
const SLAM_MAX_R_DAWN: float = 64.0
const SLAM_MAX_R_WAR: float = 54.0
const SLAM_BAND: float = 9.0
const SLAM_CD_P1: float = 4.4
const SLAM_CD_P2: float = 3.2
const PHASE2_ROAR_TIME: float = 0.65

enum SlamStage { NONE, RING_1, ECHO_PAUSE, RING_2 }

var slam_attack: bool = false
var slam_stage: int = SlamStage.NONE
var slam_tone: String = "dawn"
var slam_cd: float = 1.5
var slam_progress: float = 0.0
var slam_hit: bool = false
var swings_since_slam: int = 0
var _roaring: bool = false
var _dusk_slow_t: float = 0.0
var _resonance_pulse_t: float = 0.0
var _patterns: LxBossPatterns = null


func _init() -> void:
	kind = "bell_warden"
	boss_id = "bell_warden"
	island_id = 1
	is_boss = true
	max_hp = 26.0
	hp = 26.0
	shield_max = 2.4
	shield_hp = 2.4
	shield_gone_duration = 4.5
	body_radius = 6.5
	routine_speed = 40.0
	leash_radius = 175.0
	notice_radius = 152.0
	reach = 38.0
	lunge_reach = 104.0
	swing_r = 30.0
	swing_arc = 1.24
	tell_time = 0.48
	lunge_tell_time = 0.54
	recover_time = 1.15
	shard_drop = 15


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "bell_warden"))
	island_id = int(spec.get("island_id", 1))
	slam_attack = false
	slam_stage = SlamStage.NONE
	slam_tone = "dawn"
	slam_cd = 1.5
	slam_progress = 0.0
	slam_hit = false
	swings_since_slam = 0
	_roaring = false
	_dusk_slow_t = 0.0
	_resonance_pulse_t = 0.0
	if _patterns == null:
		_patterns = LxBossPatterns.new(self)
	_patterns.clear()


func _step_brain(dt: float) -> void:
	if _roaring and state != State.NOTICE:
		_roaring = false
	slam_cd = maxf(0.0, slam_cd - dt)
	_dusk_slow_t = maxf(0.0, _dusk_slow_t - dt)
	_resonance_pulse_t = maxf(0.0, _resonance_pulse_t - dt)
	routine_speed = 24.0 if _dusk_slow_t > 0.0 else (44.0 if phase >= 2 else 40.0)
	if _patterns != null:
		_patterns.tick(dt, world_ctx)
	super._step_brain(dt)


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	# Bible rule: ringing a bell during P2 Echo Slam pause cancels Ring 2, cracks shield, & staggers 1.8s!
	if slam_attack and state == State.COMMIT and slam_stage == SlamStage.ECHO_PAUSE:
		_cancel_echo_slam_stagger()
		return
	if t == "war":
		if shield_hp > 0.0:
			_wear_shield(1.6)
	elif t == "dusk":
		_dusk_slow_t = 2.0
		if _patterns != null:
			_patterns.freeze_bolts_in_radius(pos, 120.0, 1.5, "dusk")
		_emit_sfx("clockwork_chime")


func _cancel_echo_slam_stagger() -> void:
	slam_attack = false
	slam_stage = SlamStage.NONE
	slam_progress = 0.0
	if shield_hp > 0.0:
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		_sync_warden_sheet()
	_release_token()
	state = State.STAGGER
	state_timer = ECHO_CANCEL_STAGGER
	last_recover_duration = ECHO_CANCEL_STAGGER
	slam_cd = SLAM_CD_P2
	_boss_impact(0.22, 84.0, 86.0)
	_emit_sfx("warden_shield_break")


func take_hit(hit: LxHit) -> int:
	# Allow Sanctuary Pedestal wave or heavy throw/dash during Echo Pause to trigger the 1.8s cancel-stagger!
	if hit != null and slam_attack and state == State.COMMIT and slam_stage == SlamStage.ECHO_PAUSE:
		var h: Dictionary = _read_hit(hit)
		if bool(h["stagger"]) or bool(h["cracks_armour"]):
			hp = maxf(0.5, hp - float(h["damage"]))
			_cancel_echo_slam_stagger()
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
	return super.take_hit(hit)


func _on_stagger_end(target_pos: Vector2) -> void:
	slam_attack = false
	slam_stage = SlamStage.NONE
	super._on_stagger_end(target_pos)


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
		slam_stage = SlamStage.NONE
		lunge_attack = false
		slam_progress = 0.0
		_resonance_pulse_t = 1.0
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		slam_cd = 0.85
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.24, 90.0, 88.0)
		_emit_sfx("bell_warden_phase2")
		return true
	return false


func _die(hit: Object) -> void:
	if _patterns != null:
		_patterns.clear()
	super._die(hit)


func _slam_max_r() -> float:
	return SLAM_MAX_R_WAR if slam_tone == "war" else SLAM_MAX_R_DAWN


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if slam_cd <= 0.0 and (phase >= 2 or swings_since_slam >= 1) and dist < SLAM_MAX_R_DAWN + 22.0 \
			and _claim_token():
		slam_attack = true
		slam_stage = SlamStage.NONE
		slam_tone = "war" if slam_tone == "dawn" else "dawn"
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
	slam_stage = SlamStage.NONE
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if slam_attack:
		state = State.COMMIT
		slam_stage = SlamStage.RING_1
		state_timer = SLAM_FIRE_TIME
		slam_progress = 0.0
		slam_hit = false
		_resonance_pulse_t = 0.65
		_fire_tone_bolts()
		_boss_impact(0.16, 78.0, 82.0)
		_emit_sfx("bell_slam_fire")
		return
	swings_since_slam += 1
	super._enter_commit()


func _fire_tone_bolts() -> void:
	if _patterns == null:
		return
	if slam_tone == "war":
		var aim_a: float = (_get_wick_pos() - pos).angle() if _has_player() else facing
		_patterns.emit_gap_ring(pos, 7 if phase >= 2 else 6, 118.0 if phase >= 2 else 104.0, aim_a + PI * 0.45, 0.72, {"color": "coral", "source": "bell_warden_war"})
	elif phase >= 2:
		var aim_d: Vector2 = (_get_wick_pos() - pos).normalized() if _has_player() and _get_wick_pos().distance_to(pos) > 1.0 else Vector2.from_angle(facing)
		_patterns.emit_fan(pos, aim_d, 3, 0.65, 108.0, {"color": "gold", "source": "bell_warden_dawn"})


func _step_commit(dt: float) -> void:
	if not slam_attack:
		super._step_commit(dt)
		return
	match slam_stage:
		SlamStage.RING_1, SlamStage.RING_2:
			state_timer = maxf(0.0, state_timer - dt)
			slam_progress = 1.0 - clampf(state_timer / SLAM_FIRE_TIME, 0.0, 1.0)
			var ring_r: float = lerpf(SLAM_START_R, _slam_max_r(), slam_progress)
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
				if slam_stage == SlamStage.RING_1 and phase >= 2:
					slam_stage = SlamStage.ECHO_PAUSE
					state_timer = _scaled_tell(ECHO_PAUSE_TIME, false, attack_damage)
					slam_progress = 0.0
					slam_hit = false
					_emit_sfx("clockwork_chime")
				else:
					_finish_slam_into_recover()
		SlamStage.ECHO_PAUSE:
			state_timer -= dt
			if state_timer <= 0.0:
				slam_stage = SlamStage.RING_2
				state_timer = SLAM_FIRE_TIME
				slam_progress = 0.0
				slam_hit = false
				_resonance_pulse_t = 0.65
				_fire_tone_bolts()
				_boss_impact(0.18, 82.0, 86.0)
				_emit_sfx("bell_slam_fire")
		_:
			_finish_slam_into_recover()


func _finish_slam_into_recover() -> void:
	slam_attack = false
	slam_stage = SlamStage.NONE
	slam_progress = 0.0
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, SLAM_RECOVER_TIME)
	last_recover_duration = state_timer
	slam_cd = SLAM_CD_P2 if phase >= 2 else SLAM_CD_P1


func _swing_tell_base() -> float:
	return 0.45 if phase >= 2 else tell_time


func _lunge_tell_base() -> float:
	return 0.50 if phase >= 2 else lunge_tell_time


func _post_recover_cooldown() -> float:
	return 0.72 if phase >= 2 else 0.90


func _body_color() -> Color:
	return PAL["apricot"] as Color if phase >= 2 else PAL["jade"] as Color


func _shield_color() -> Color:
	return PAL["sky"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P2 Arena Change: Belfry Resonance Floor etched around home!
	if phase >= 2 and state != State.DEAD:
		var hc: Vector2 = (home - pos).round()
		var col_f: Color = PAL["coral"] as Color if slam_tone == "war" else PAL["gold"] as Color
		var a_f: float = 0.34 if _resonance_pulse_t > 0.0 else 0.16
		draw_arc(hc, 64.0, 0.0, TAU, 36, Color(col_f, a_f), 1.4)
		draw_arc(hc, 96.0, 0.0, TAU, 44, Color(PAL["gold"] as Color, a_f * 0.7), 1.0)
	if _patterns != null:
		_patterns.draw_patterns(self, pos)

	var is_war: bool = slam_tone == "war"
	var c_outer: Color = (PAL["coral"] if is_war else PAL["apricot"]) as Color
	var c_mid: Color = (PAL["rose"] if is_war else PAL["gold"]) as Color
	var max_r: float = _slam_max_r()

	if slam_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, max_r, a0, a0 + 0.24, 3, c_outer, 1.2)
		var r: float = lerpf(max_r, SLAM_START_R + 6.0, prog)
		var pulse: float = 1.0 if LxHudFx.flash_reduced() else (1.0 + 0.6 * sin(anim_t * 18.0))
		var hot: bool = state_timer <= 0.14
		draw_arc(c, r + pulse, 0.0, TAU, 28, (PAL["gold"] if hot else c_outer) as Color, 1.3)
		draw_arc(c, r, 0.0, TAU, 28, (PAL["cream"] if hot else c_mid) as Color, 2.0 if hot else 1.8)
	elif slam_attack and state == State.COMMIT:
		if slam_stage == SlamStage.ECHO_PAUSE:
			var p_den: float = _scaled_tell(ECHO_PAUSE_TIME, false, attack_damage)
			var p_u: float = 1.0 - clampf(state_timer / maxf(p_den, 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, c, max_r, p_u, anim_t, "coral" if is_war else "gold", "cream")
			# Pulsing bell-counter halo indicating Echo Slam can be cancelled!
			draw_arc(c, body_radius + 10.0, 0.0, TAU, 20, PAL["ice"] as Color, 1.6)
		else:
			var ring_r: float = lerpf(SLAM_START_R, max_r, slam_progress)
			draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, c_outer, 2.2)
			draw_arc(c, ring_r, 0.0, TAU, 36, c_mid, 3.4)
			draw_arc(c, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
	if _dusk_slow_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.4)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.08, 1.38, 0.36)
