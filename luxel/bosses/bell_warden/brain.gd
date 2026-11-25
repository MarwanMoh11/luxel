class_name LxBellWardenBoss
extends LxBossBase
## Belfry Mini-Boss #1 (Island 1, belfry_r5): Bell Warden migrated onto LxBossBase.
## Preserves child-acolyte art, parasol shield teaching role, Sanctuary Pedestal synergy,
## and Island 1 Bible upgrades:
## - Armour outside punish windows (parasol guard + brass bell-mantle; bolts chip with glint).
## - P1/P2 slams telegraph DAWN (wide gold ring + fan) vs WAR (fast coral spike ring + gap-ring).
## - P2 (<= 50% HP): Belfry Resonance Floor + 2 acoustic grate pits + 2 bronze pillars +
##   0.55s Echo Slam pause before Ring 2 (bell ring or heavy/pedestal hit cancels Ring 2,
##   shatters shield, and triggers 1.80s counter-stagger!).

signal shield_broken(enemy: LxEnemyBrain, at_pos: Vector2)
signal shield_reformed(enemy: LxEnemyBrain, at_pos: Vector2)

const FRONT_GUARD_HALF: float = 1.08
const SLAM_START_R: float = 8.0
const SLAM_MAX_R_DAWN: float = 64.0
const SLAM_MAX_R_WAR: float = 54.0
const SLAM_BAND: float = 9.5
const SLAM_RING_TIME: float = 0.26
const ECHO_PAUSE_TIME: float = 0.55
const ECHO_CANCEL_STAGGER: float = 1.80
const LUNGE_SPEED: float = 205.0

enum SlamStage { NONE, RING_1, ECHO_PAUSE, RING_2 }

var shield_max: float = 2.4
var shield_hp: float = 2.4
var shield_gone_duration: float = 4.5
var shield_gone_t: float = 0.0

var slam_tone: String = "dawn"
var slam_stage: int = SlamStage.NONE
var _slam_stage_t: float = 0.0
var _slam_progress: float = 0.0
var _slam_hit: bool = false
var _aim_dir: Vector2 = Vector2.LEFT
var _lunge_hit: bool = false
var _dusk_slow_t: float = 0.0
var _resonance_pulse_t: float = 0.0
var _echo_stagger_bonus: bool = false
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0


func _init() -> void:
	super._init()
	kind = "bell_warden"
	boss_id = "bell_warden"
	boss_name_key = "MINIBOSS_1"
	island_id = 1
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island1_boss_p1"
	music_p2_cue = "island1_boss_p2"
	max_hp = 72.0
	hp = 72.0
	body_radius = 7.0
	move_speed = 42.0
	stagger_threshold = 10.0
	stagger_duration = 1.65
	punish_dmg_mult = 1.30
	post_recover_cd = 0.30
	intro_duration = 0.15
	phase_shift_duration = 0.65
	death_duration = 1.8
	shard_drop = 15


func _configure_boss(spec: Dictionary) -> void:
	var base_hp: float = 72.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	boss_id = str(spec.get("boss_id", "bell_warden"))
	island_id = int(spec.get("island_id", 1))
	configure_phases([0.50])

	# Attack 1: Parasol Cleave — wide directional bell-parasol sweep + 3-bolt gold fan
	register_attack("parasol_sweep", {
		"weight": 1.25, "tell": 0.50, "commit": 0.28, "recover": 1.05, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			ground.warn_sector(pos, facing - 1.15, facing + 1.15, 42.0, last_tell_duration, 1.0, "gold", "coral")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 160.0), 8.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.72, 134.0 if phase >= 2 else 118.0, {"color": "gold", "source": "bell_warden_sweep", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * (70.0 if _dusk_slow_t <= 0.0 else 32.0) * dt, false),
	})

	# Attack 2: Belfry Lunge — telegraphed hop-lunge spear thrust + closing coral chime fan
	register_attack("belfry_lunge", {
		"weight": 1.20, "tell": 0.54, "commit": 0.34, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			_lunge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 116.0), 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_lunge_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_lunge_hit = false
			patterns.emit_fan(pos, _aim_dir, 3, 0.52, 128.0, {"color": "coral", "source": "bell_warden_lunge", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var spd: float = LUNGE_SPEED * (0.48 if _dusk_slow_t > 0.0 else (1.10 if phase >= 2 else 1.0))
			move_boss(_aim_dir * spd * dt, false)
			if not _lunge_hit:
				_lunge_hit = check_contact_damage(20.0, _aim_dir, 1.0, "bell_warden_lunge"),
	})

	# Attack 3: Tone Slam — alternates DAWN (wide gold ring) vs WAR (fast coral spike ring + gap-ring);
	# P2 adds 0.55s Echo Pause before Ring 2 (cancellable by bell ring or heavy/pedestal hit for 1.80s stagger!).
	register_attack("tone_slam", {
		"weight": 1.35, "tell": 0.60, "commit": 1.08, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			slam_tone = "war" if slam_tone == "dawn" else "dawn"
			slam_stage = SlamStage.NONE
			_slam_progress = 0.0
			_slam_hit = false
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var fk: String = "coral" if slam_tone == "war" else "gold"
			ground.warn_ring(pos, _slam_max_r(), last_tell_duration, 0.0, fk, "cream")
			stage.play_sfx("bell_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			slam_stage = SlamStage.RING_1
			_slam_stage_t = SLAM_RING_TIME
			_slam_progress = 0.0
			_slam_hit = false
			_resonance_pulse_t = 0.65
			state_timer = (SLAM_RING_TIME * 2.0 + ECHO_PAUSE_TIME * get_tell_scale()) if phase >= 2 else SLAM_RING_TIME
			_fire_tone_bolts()
			LxDamageFx.boss_impact(pos, 0.16, 78.0, 82.0, 84.0, 1.38, 0.36)
			stage.play_sfx("bell_slam_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			_step_tone_slam_commit(dt),
	})

	# Attack 4 (P2): Resonance Chimes — Belfry floor rains bell impacts on Wick & perimeter corners
	register_attack("resonance_chimes", {
		"phases": [2], "weight": 2.20, "tell": 0.54, "commit": 0.34, "recover": 1.15, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var drops: Array[Vector2] = _perimeter_targets(tgt, 4)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _aim_dir
			patterns.emit_fan(pos, d, 5, 0.78, 134.0, {"color": "gold", "source": "bell_warden_chime", "reflectable": true})
			_resonance_pulse_t = 0.75
			stage.shake(0.16)
			stage.play_sfx("bell_slam_fire", pos),
	})


func _on_engage() -> void:
	# Short intro beat so Belfry R5 pedestal synergy & tutorial checks engage smoothly
	state_timer = 0.05


func _on_reset_encounter() -> void:
	shield_hp = shield_max
	shield_gone_t = 0.0
	slam_tone = "dawn"
	slam_stage = SlamStage.NONE
	_slam_stage_t = 0.0
	_slam_progress = 0.0
	_slam_hit = false
	_lunge_hit = false
	_dusk_slow_t = 0.0
	_resonance_pulse_t = 0.0
	_echo_stagger_bonus = false
	_armour_glint_t = 0.0


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_dusk_slow_t = maxf(0.0, _dusk_slow_t - dt)
	_resonance_pulse_t = maxf(0.0, _resonance_pulse_t - dt)
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	move_speed = 22.0 if _dusk_slow_t > 0.0 else (46.0 if phase >= 2 else 42.0)
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
			shield_reformed.emit(self, pos)
			stage.play_sfx("warden_shield_reform", pos)
	if boss_state != BossState.STAGGER:
		_echo_stagger_bonus = false
	if boss_state != BossState.COMMIT:
		slam_stage = SlamStage.NONE


func _step_tone_slam_commit(dt: float) -> void:
	match slam_stage:
		SlamStage.RING_1, SlamStage.RING_2:
			_slam_stage_t = maxf(0.0, _slam_stage_t - dt)
			_slam_progress = 1.0 - clampf(_slam_stage_t / SLAM_RING_TIME, 0.0, 1.0)
			var ring_r: float = lerpf(SLAM_START_R, _slam_max_r(), _slam_progress)
			if not _slam_hit and _has_player():
				var wv: Vector2 = _get_wick_pos() - pos
				if absf(wv.length() - ring_r) <= SLAM_BAND:
					_slam_hit = true
					var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
					emit_boss_damage(push, 1.0, "bell_warden_slam", pos, true)
			if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
			if _slam_stage_t <= 0.0:
				if slam_stage == SlamStage.RING_1 and phase >= 2:
					slam_stage = SlamStage.ECHO_PAUSE
					_slam_stage_t = ECHO_PAUSE_TIME * get_tell_scale()
					_slam_progress = 0.0
					_slam_hit = false
					stage.play_sfx("clockwork_chime", pos)
				else:
					slam_stage = SlamStage.NONE
					state_timer = 0.0
		SlamStage.ECHO_PAUSE:
			_slam_stage_t = maxf(0.0, _slam_stage_t - dt)
			if _slam_stage_t <= 0.0:
				slam_stage = SlamStage.RING_2
				_slam_stage_t = SLAM_RING_TIME
				_slam_progress = 0.0
				_slam_hit = false
				_resonance_pulse_t = 0.65
				_fire_tone_bolts()
				LxDamageFx.boss_impact(pos, 0.18, 82.0, 86.0, 88.0, 1.38, 0.36)
				stage.play_sfx("bell_slam_fire", pos)


func _fire_tone_bolts() -> void:
	var aim_a: float = (_get_wick_pos() - pos).angle() if _has_player() else facing
	if slam_tone == "war":
		patterns.emit_gap_ring(pos, 8 if phase >= 2 else 6, 128.0 if phase >= 2 else 112.0, aim_a + PI * 0.45, 0.72, {"color": "coral", "source": "bell_warden_war", "reflectable": true})
	else:
		var aim_d: Vector2 = (_get_wick_pos() - pos).normalized() if (_has_player() and _get_wick_pos().distance_to(pos) > 1.0) else Vector2.from_angle(facing)
		patterns.emit_fan(pos, aim_d, 5 if phase >= 2 else 3, 0.72, 122.0, {"color": "gold", "source": "bell_warden_dawn", "reflectable": true})


func on_ring(tone: String, _dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	# Bible rule: ringing a bell during P2 Echo Slam pause cancels Ring 2, cracks shield, & staggers 1.80s!
	if boss_state == BossState.COMMIT and active_attack_id == "tone_slam" and slam_stage == SlamStage.ECHO_PAUSE:
		_cancel_echo_slam_stagger()
		return
	if t == "war":
		if _has_active_shield():
			_wear_shield(1.6)
		add_stagger(4.5)
	elif t == "dusk":
		_dusk_slow_t = 2.0
		patterns.freeze_bolts_in_radius(pos, 130.0, 1.5, "dusk")
		stage.play_sfx("clockwork_chime", pos)


func _cancel_echo_slam_stagger() -> void:
	slam_stage = SlamStage.NONE
	_slam_progress = 0.0
	if shield_hp > 0.0:
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		shield_broken.emit(self, pos)
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_echo_stagger_bonus = true
	_set_boss_state(BossState.STAGGER, ECHO_CANCEL_STAGGER)
	last_recover_duration = ECHO_CANCEL_STAGGER
	staggered.emit(ECHO_CANCEL_STAGGER)
	LxDamageFx.boss_impact(pos, 0.22, 84.0, 86.0, 88.0, 1.40, 0.36)
	stage.play_sfx("warden_shield_break", pos)


func _has_active_shield() -> bool:
	return shield_hp > 0.001 and shield_gone_t <= 0.0


func _is_hit_invulnerable() -> bool:
	return boss_state == BossState.PHASE_SHIFT


func _wear_shield(amount: float) -> bool:
	if not _has_active_shield():
		return false
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amount))
	if shield_hp <= 0.001:
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		shield_broken.emit(self, pos)
		stage.play_sfx("warden_shield_break", pos)
		add_stagger(stagger_threshold * 0.85)
		return true
	clank_t = 0.14
	return false


func take_hit(hit: LxHit) -> int:
	# Allow Sanctuary Pedestal wave or heavy throw/dash during Echo Pause to trigger 1.80s cancel-stagger!
	if hit != null and boss_state == BossState.COMMIT and active_attack_id == "tone_slam" and slam_stage == SlamStage.ECHO_PAUSE:
		var h: Dictionary = _read_hit(hit)
		if bool(h["stagger"]) or bool(h["cracks_armour"]) or float(h["shield_wear"]) >= 1.2:
			hp = maxf(0.5, hp - float(h["damage"]))
			_cancel_echo_slam_stagger()
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	var is_heavy: bool = is_pierce or bool(h["stagger"]) or bool(h["cracks_armour"]) or float(h["shield_wear"]) >= 1.2 or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH]

	if _has_active_shield() and (is_heavy or float(h["shield_wear"]) >= 1.0):
		_wear_shield(maxf(float(h["shield_wear"]), 1.25))

	if is_pierce:
		return dmg * (1.20 if is_punishable() else 1.0)
	if is_punishable():
		return dmg * (1.15 if _echo_stagger_bonus else 1.0)

	# Outside punish windows: parasol shield & brass mantle armour chip bolts with glint!
	var ang_diff: float = absf(angle_difference(facing, rel.angle())) if rel.length() > 1.0 else 0.0
	var is_front: bool = rel.length() > 1.0 and ang_diff < FRONT_GUARD_HALF
	_armour_glint_t = 0.22
	_armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing
	if _has_active_shield() and is_front:
		clank_t = 0.14
		if src == LxHit.SOURCE_BOLT:
			_wear_shield(0.24)
			stage.play_sfx("boss_armour_glint", pos)
			return dmg * 0.16
		return dmg * 0.45
	clank_t = 0.10
	if src == LxHit.SOURCE_BOLT:
		stage.play_sfx("boss_armour_chip", pos)
		return dmg * 0.28
	return dmg * 0.56


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		slam_stage = SlamStage.NONE
		_resonance_pulse_t = 1.0
		shield_gone_t = 0.0
		shield_hp = shield_max
		shield_reformed.emit(self, pos)
		_carve_safe_pit(0.26, 0.20)
		_carve_safe_pit(0.74, 0.78)
		var c: Vector2 = arena_rect.get_center()
		props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, -34.0)), 4.0, "bw_acoustic_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, 34.0)), 4.0, "bw_acoustic_e")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("bell_warden_phase2", pos)


func _carve_safe_pit(fx: float, fy: float) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var wp := Vector2(lerpf(arena_rect.position.x, arena_rect.end.x, fx), lerpf(arena_rect.position.y, arena_rect.end.y, fy))
	var tx: int = int(wp.x / 16.0)
	var ty: int = int(wp.y / 16.0)
	var center_p := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", center_p)) in ["ground", "path"]:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


func _perimeter_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _slam_max_r() -> float:
	return SLAM_MAX_R_WAR if slam_tone == "war" else SLAM_MAX_R_DAWN


func _body_color() -> Color:
	return PAL["apricot"] as Color if phase >= 2 else PAL["jade"] as Color


func _shield_color() -> Color:
	return PAL["sky"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P2 Arena Change: Belfry Resonance Floor rings etched around home
	if phase >= 2 and boss_state != BossState.DEATH:
		var hc: Vector2 = (home - pos).round()
		var col_f: Color = PAL["coral"] as Color if slam_tone == "war" else PAL["gold"] as Color
		var a_f: float = 0.36 if _resonance_pulse_t > 0.0 else 0.18
		draw_arc(hc, 64.0, 0.0, TAU, 36, Color(col_f, a_f), 1.4)
		draw_arc(hc, 96.0, 0.0, TAU, 44, Color(PAL["gold"] as Color, a_f * 0.7), 1.0)

	# Armour glint when bolts chip outside punish windows
	if _armour_glint_t > 0.0 and boss_state != BossState.DEATH:
		var ga: float = clampf(_armour_glint_t / 0.22, 0.0, 1.0)
		draw_arc(c, body_radius + 4.5, _armour_glint_ang - 0.75, _armour_glint_ang + 0.75, 10, Color(PAL["cream"] as Color, ga), 2.0)

	var is_war: bool = slam_tone == "war"
	var c_outer: Color = (PAL["coral"] if is_war else PAL["apricot"]) as Color
	var c_mid: Color = (PAL["rose"] if is_war else PAL["gold"]) as Color
	var max_r: float = _slam_max_r()

	if boss_state == BossState.COMMIT and active_attack_id == "tone_slam":
		if slam_stage == SlamStage.ECHO_PAUSE:
			var p_den: float = ECHO_PAUSE_TIME * get_tell_scale()
			var p_u: float = 1.0 - clampf(_slam_stage_t / maxf(p_den, 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, c, max_r, p_u, anim_t, "coral" if is_war else "gold", "cream")
			draw_arc(c, body_radius + 10.0, 0.0, TAU, 20, PAL["ice"] as Color, 1.6)
		elif slam_stage == SlamStage.RING_1 or slam_stage == SlamStage.RING_2:
			var ring_r: float = lerpf(SLAM_START_R, max_r, _slam_progress)
			draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, c_outer, 2.2)
			draw_arc(c, ring_r, 0.0, TAU, 36, c_mid, 3.4)
			draw_arc(c, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	elif boss_state == BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(state_timer / maxf(phase_shift_duration, 0.05), 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
	if _dusk_slow_t > 0.0:
		draw_arc(c, body_radius + 5.5, 0.0, TAU, 16, PAL["ice"] as Color, 1.4)
