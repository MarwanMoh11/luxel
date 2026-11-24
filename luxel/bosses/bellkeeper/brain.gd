class_name LxBellkeeperBoss
extends LxWardenBrain
## Grand Bellkeeper Boss (Island 1, belfry_r7): Upgraded to Island 1 Bible!
## First major boss most players meet: FAIR, READABLE, and GRAND.
## Preserves existing bellkeeper sprite, crown silhouette, SFX, and teaching role.
## - P1 (100%-55%): Swings, hop-lunges, and Bell Slams (+ fair golden gap-ring chime bolts);
##   War Bell cracks his golden crown shield!
## - P2 (<= 55%): Spire flagstones light up as a GRAND CLOCK FACE with a slow sweeping
##   Phantom Minute Hand (0.35 rad/s; Dusk Bell freezes it 2.0s; Dash passes cleanly through!)
##   + Double-Toll Slam + summons toll_moth + owl sharing LxAttackDirector.
## - P3 (<= 25%): Three-Tone Toll Duel — telegraphs Gold (Dawn) / Ice (Dusk) / Coral (War)
##   crown aura (0.60s) before Double-Toll; countering with matching rim bell triggers 1.6s stagger!

signal add_spawn_requested(specs: Array[Dictionary], boss: LxEnemyBrain)

const SLAM_WINDUP_P1: float = 0.66
const SLAM_WINDUP_P3: float = 0.60
const DOUBLE_TOLL_GAP: float = 0.48
const DOUBLE_TOLL_GAP_P3: float = 0.46
const SLAM_FIRE_TIME: float = 0.26
const SLAM_RECOVER_P1: float = 1.35
const DOUBLE_TOLL_RECOVER_P2: float = 1.45
const DOUBLE_TOLL_RECOVER_P3: float = 1.15
const PHASE2_ROAR_TIME: float = 0.80
const SLAM_START_R: float = 8.0
const SLAM_MAX_R: float = 68.0
const SLAM_BAND: float = 9.5
const SLAM_CD_P1: float = 4.0
const SLAM_CD_P2: float = 2.9
const SLAM_CD_P3: float = 2.4
const CLOCK_HAND_SPEED: float = 0.35
const CLOCK_HAND_LEN: float = 98.0
const CLOCK_HAND_HIT_CD: float = 1.25
const TONE_CYCLE: PackedStringArray = ["dawn", "dusk", "war"]

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
var _p3_chime_t: float = 0.0
var _clock_active: bool = false
var _clock_ang: float = -PI * 0.5
var _clock_freeze_t: float = 0.0
var _clock_hit_cd: float = 0.0
var _clock_warm_t: float = 0.0
var _saw_first_tell: bool = false
var _toll_tone: String = "dawn"
var _tone_idx: int = 0
var _patterns: LxBossPatterns = null


func _init() -> void:
	kind = "bellkeeper"
	boss_id = "bellkeeper"
	island_id = 1
	is_boss = true
	max_hp = 52.0
	hp = 52.0
	shield_max = 2.8
	shield_hp = 2.8
	shield_gone_duration = 4.8
	body_radius = 7.0
	routine_speed = 42.0
	leash_radius = 185.0
	notice_radius = 160.0
	reach = 42.0
	lunge_reach = 108.0
	swing_r = 33.0
	swing_arc = 1.32
	tell_time = 0.48
	lunge_tell_time = 0.52
	recover_time = 1.15
	shard_drop = 30


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
	_p3_chime_t = 0.0
	_clock_active = false
	_clock_ang = -PI * 0.5
	_clock_freeze_t = 0.0
	_clock_hit_cd = 0.0
	_clock_warm_t = 0.0
	_saw_first_tell = false
	_toll_tone = "dawn"
	_tone_idx = 0
	if _patterns == null:
		_patterns = LxBossPatterns.new(self)
	_patterns.clear()


func _step_brain(dt: float) -> void:
	slam_cd = maxf(0.0, slam_cd - dt)
	_p3_chime_t = maxf(0.0, _p3_chime_t - dt)
	_clock_freeze_t = maxf(0.0, _clock_freeze_t - dt)
	_clock_hit_cd = maxf(0.0, _clock_hit_cd - dt)
	if state == State.TELL:
		_saw_first_tell = true
	if _patterns != null:
		_patterns.tick(dt, world_ctx)
	if _clock_active and state != State.DEAD:
		_step_clock_hand(dt)
	super._step_brain(dt)


func _step_clock_hand(dt: float) -> void:
	_clock_warm_t += dt
	if _clock_freeze_t > 0.0:
		return
	_clock_ang = wrapf(_clock_ang + CLOCK_HAND_SPEED * dt, -PI, PI)
	# Grand, fair Minute Hand: never hurts before first tell or during roar warmup, and Dash passes cleanly through!
	if not _saw_first_tell or _roaring or _clock_warm_t < 1.25 or _clock_hit_cd > 0.0 or not _has_player():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if wick_node != null and wick_node.is_dashing() and wick_node.move_dash != null and wick_node.move_dash.has_iframes():
		return
	var wp: Vector2 = _get_wick_pos()
	var tip: Vector2 = home + Vector2.from_angle(_clock_ang) * CLOCK_HAND_LEN
	var inner: Vector2 = home + Vector2.from_angle(_clock_ang) * 18.0
	if Geometry2D.get_closest_point_to_segment(wp, inner, tip).distance_to(wp) <= 6.5:
		_clock_hit_cd = CLOCK_HAND_HIT_CD
		var perp: Vector2 = Vector2.from_angle(_clock_ang + PI * 0.5)
		_emit_player_hit(perp, 1.0)


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	# P2/P3 Clock Face Minute Hand freezes 2.0s on DUSK!
	if t == "dusk" and _clock_active:
		_clock_freeze_t = 2.0
		if _patterns != null:
			_patterns.freeze_bolts_in_radius(pos, 140.0, 1.6, "dusk")
		_emit_sfx("clockwork_chime")
	# P1-P3 WAR cracks golden crown shield!
	if t == "war" and shield_hp > 0.0:
		_wear_shield(shield_max)
	# P3 Three-Tone Counter-Stagger (1.6s!) during matching aura or Toll Pause
	if phase >= 3 and slam_attack and (state == State.TELL or (state == State.COMMIT and slam_stage == SlamStage.TOLL_PAUSE)):
		if t == _toll_tone or (t == "dusk" and slam_stage == SlamStage.TOLL_PAUSE):
			slam_attack = false
			slam_stage = SlamStage.NONE
			slam_progress = 0.0
			_release_token()
			state = State.STAGGER
			state_timer = 1.60
			last_recover_duration = 1.60
			slam_cd = SLAM_CD_P3
			_boss_impact(0.22, 88.0, 90.0)
			_emit_sfx("warden_shield_break")


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
	if phase < 2 and hp <= max_hp * 0.55 and hp > 0.001:
		_enter_phase2()
		return true
	if phase < 3 and hp <= max_hp * 0.25 and hp > 0.001:
		_enter_phase3()
		return false
	return false


func _enter_phase2() -> void:
	phase = 2
	double_toll_enabled = true
	_clock_active = true
	_clock_warm_t = 0.0
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
		Lx.events.shake_requested.emit(0.32)
	LxDamageFx.trigger_boss_phase_reset(self, 2)
	_emit_sfx("bellkeeper_phase2_roar")
	_emit_sfx("clockwork_chime")
	_request_phase2_adds()


func _enter_phase3() -> void:
	phase = 3
	double_toll_enabled = true
	_clock_active = true
	_p3_chime_t = 0.55
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, 3)
		Lx.events.shake_requested.emit(0.25)
	LxDamageFx.trigger_boss_phase_reset(self, 3)
	_emit_sfx("bellkeeper_phase3_chime")


func _request_phase2_adds() -> void:
	if _adds_requested:
		return
	_adds_requested = true
	var r: float = minf(72.0, leash_radius * 0.5)
	var add1_kind: String = "toll_moth" if (Lx.packs != null and not Lx.packs.enemy_script("toll_moth").is_empty()) else "snatcher"
	var specs: Array[Dictionary] = [
		{
			"kind": add1_kind,
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


func _die(hit: Object) -> void:
	_clock_active = false
	if _patterns != null:
		_patterns.clear()
	super._die(hit)


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if slam_cd <= 0.0 and (phase >= 2 or swings_since_slam >= 1) and dist < SLAM_MAX_R + 24.0 \
			and _claim_token():
		slam_attack = true
		slam_stage = SlamStage.NONE
		lunge_attack = false
		is_counter_attack = false
		if phase >= 3:
			_toll_tone = TONE_CYCLE[_tone_idx % TONE_CYCLE.size()]
			_tone_idx += 1
		else:
			_toll_tone = "dawn"
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
		_emit_chime_bolts(false)
		_boss_impact(0.20, 92.0, 95.0)
		_emit_sfx("bellkeeper_slam_fire")
		return
	swings_since_slam += 1
	super._enter_commit()


func _emit_chime_bolts(is_second_ring: bool) -> void:
	if _patterns == null:
		return
	var aim_a: float = (_get_wick_pos() - pos).angle() if _has_player() else facing
	var col_k: String = "gold"
	if phase >= 3:
		col_k = "ice" if _toll_tone == "dusk" else ("coral" if _toll_tone == "war" else "gold")
	var cnt: int = 8 if phase >= 3 else (7 if phase >= 2 else 6)
	var spd: float = 114.0 if phase >= 3 else (106.0 if phase >= 2 else 98.0)
	var gap_off: float = PI * (0.35 if is_second_ring else 0.50)
	_patterns.emit_gap_ring(pos, cnt, spd, aim_a + gap_off, 0.80, {"color": col_k, "source": "bellkeeper_chime"})


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
				_emit_chime_bolts(true)
				_boss_impact(0.20, 92.0, 95.0)
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
	return 0.45 if phase >= 3 else tell_time


func _lunge_tell_base() -> float:
	return 0.48 if phase >= 3 else lunge_tell_time


func _swing_recover_duration() -> float:
	return 0.90 if phase >= 3 else recover_time


func _post_recover_cooldown() -> float:
	if phase >= 3:
		return 0.58
	if phase >= 2:
		return 0.74
	return 0.92


func _body_color() -> Color:
	if phase >= 3:
		return PAL["coral"] as Color
	if phase >= 2:
		return PAL["wine"] as Color
	return PAL["plum"] as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	# P2/P3 Grand Spire Clock Face floor overlay & sweeping Phantom Minute Hand!
	if _clock_active and state != State.DEAD:
		var hc: Vector2 = (home - pos).round()
		var frozen: bool = _clock_freeze_t > 0.0
		var ring_c: Color = PAL["ice"] as Color if frozen else PAL["gold"] as Color
		draw_arc(hc, CLOCK_HAND_LEN, 0.0, TAU, 48, Color(ring_c, 0.28), 1.4)
		for hi: int in range(12):
			var ha: float = float(hi) * (TAU / 12.0)
			var d_h: Vector2 = Vector2.from_angle(ha)
			draw_line((hc + d_h * (CLOCK_HAND_LEN - 7.0)).round(), (hc + d_h * CLOCK_HAND_LEN).round(), Color(ring_c, 0.42), 1.5 if hi % 3 == 0 else 1.0)
		var hand_dir: Vector2 = Vector2.from_angle(_clock_ang)
		var hand_p0: Vector2 = (hc + hand_dir * 16.0).round()
		var hand_p1: Vector2 = (hc + hand_dir * CLOCK_HAND_LEN).round()
		var live_hand: bool = _saw_first_tell and not _roaring and _clock_warm_t >= 1.25
		var hand_a: float = 0.85 if live_hand else 0.32
		draw_line(hand_p0, hand_p1, Color(PAL["night"] as Color, hand_a), 4.2)
		draw_line(hand_p0, hand_p1, Color(PAL["ice"] if frozen else PAL["gold"], hand_a), 2.2)
		draw_line(hand_p0, hand_p1, Color(PAL["cream"] as Color, hand_a * 0.85), 1.0)

	if _patterns != null:
		_patterns.draw_patterns(self, pos)

	# P3 Three-Tone Crown Aura indicator
	if phase >= 3 and state != State.DEAD:
		var aura_k: String = "ice" if _toll_tone == "dusk" else ("coral" if _toll_tone == "war" else "gold")
		draw_arc(off.round(), body_radius + 7.5, 0.0, TAU, 20, Color(PAL[aura_k] as Color, 0.72), 1.5)

	if slam_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var fk: String = "ice" if (phase >= 3 and _toll_tone == "dusk") else ("coral" if (phase >= 3 and _toll_tone == "war") else "gold")
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, SLAM_MAX_R, prog, anim_t, fk, "coral")
		if double_toll_enabled:
			var r_dbl: float = maxf(6.0, lerpf(SLAM_MAX_R, SLAM_START_R + 6.0, prog) * 0.55)
			draw_arc(off, r_dbl, 0.0, TAU, 20, PAL["coral"] as Color, 1.3)
	elif slam_attack and state == State.COMMIT:
		if slam_stage == SlamStage.TOLL_PAUSE:
			var p_den: float = _scaled_tell(DOUBLE_TOLL_GAP_P3 if phase >= 3 else DOUBLE_TOLL_GAP, false, attack_damage)
			var p_urg: float = 1.0 - clampf(state_timer / maxf(p_den, 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, off, SLAM_MAX_R, p_urg, anim_t, "gold", "coral")
		else:
			var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, slam_progress)
			draw_arc(off, ring_r + 3.0, 0.0, TAU, 36, PAL["apricot"] as Color, 2.2)
			draw_arc(off, ring_r, 0.0, TAU, 36, PAL["gold"] as Color, 3.4)
			draw_arc(off, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 18.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
		if phase == 2 and _adds_requested:
			var sr: float = minf(72.0, leash_radius * 0.5)
			LxBossTelegraphFx.draw_ground_summon_ring(self, home + Vector2(-sr, -sr * 0.5) - pos, 16.0, rp, anim_t, "gold")
			LxBossTelegraphFx.draw_ground_summon_ring(self, home + Vector2(sr, -sr * 0.5) - pos, 16.0, rp, anim_t, "gold")
	if _p3_chime_t > 0.0:
		var cp: float = 1.0 - clampf(_p3_chime_t / 0.55, 0.0, 1.0)
		var cr: float = body_radius + 10.0 + cp * 22.0
		draw_arc(off, cr + 2.0, 0.0, TAU, 28, PAL["coral"] as Color, 2.0)
		draw_arc(off, cr, 0.0, TAU, 28, PAL["gold"] as Color, 2.2)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.48, 0.42)
