class_name LxTideCaptainBoss
extends LxCrabWardenBrain
## Tidewater Harbor mini-boss (Island 2): elite Tide Captain Crab Warden.
## 2 phases, HP 8.0, claw shield 2.6.
## Signature kit: directional Brine Surge Cone (tell >= 0.52s), Blue-Bolt Guard Crack
## (blue/prism hits shatter claw guard for 1.4s stunned 1.5x punish), and P2 Lateral Claw-Rush Feint.

const SURGE_TELL_P1: float = 0.58
const SURGE_TELL_P2: float = 0.52
const SURGE_FIRE_TIME: float = 0.32
const SURGE_RECOVER_P1: float = 1.22
const SURGE_RECOVER_P2: float = 1.05
const SURGE_START_R: float = 10.0
const SURGE_MAX_R: float = 88.0
const SURGE_HALF_ARC: float = 0.58
const SURGE_BAND: float = 13.0
const SURGE_CD_P1: float = 4.4
const SURGE_CD_P2: float = 3.0
const GUARD_CRACK_STAGGER: float = 1.40
const GUARD_CRACK_MULT: float = 1.50
const FEINT_DIST: float = 18.0
const PHASE2_ROAR_TIME: float = 0.60

var surge_attack: bool = false
var surge_cd: float = 1.6
var surge_progress: float = 0.0
var surge_dir: Vector2 = Vector2.RIGHT
var surge_hit: bool = false
var swings_since_surge: int = 0
var guard_cracked_t: float = 0.0
var feint_done: bool = false
var feint_side: float = 1.0
var feint_ghost_pos: Vector2 = Vector2.ZERO
var feint_ghost_t: float = 0.0
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
	surge_attack = false
	surge_cd = 1.6
	surge_progress = 0.0
	surge_dir = Vector2.from_angle(facing)
	surge_hit = false
	swings_since_surge = 0
	guard_cracked_t = 0.0
	feint_done = false
	feint_side = 1.0
	feint_ghost_pos = pos
	feint_ghost_t = 0.0
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	# Blue-Bolt Guard Crack: shatters active claw guard for a 1.4s stunned 1.5x punish window!
	if is_blue_hit and _has_active_shield():
		var dmg: float = float(h["damage"]) * GUARD_CRACK_MULT
		var orig: Vector2 = h["origin"] as Vector2
		var rel: Vector2 = orig - pos
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		guard_cracked_t = GUARD_CRACK_STAGGER
		wary = true
		surge_attack = false
		lunge_attack = false
		is_counter_attack = false
		hp -= dmg
		flash_t = 0.18
		if rel.length() > 0.01:
			knock = -rel.normalized() * 68.0
		shield_broken.emit(self, pos)
		_boss_impact(0.20, 80.0, 84.0)
		_emit_sfx("tide_captain_guard_crack")
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		if not _check_phase_transition():
			_release_token()
			state = State.STAGGER
			state_timer = GUARD_CRACK_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	var hp_before: float = hp
	var res: int = super.take_hit(hit)
	# Apply 1.5x punish bonus during guard-crack stun for non-blue follow-up hits
	if is_alive() and guard_cracked_t > 0.0 and not is_blue_hit and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		var dealt: float = maxf(0.0, hp_before - hp)
		if dealt > 0.001:
			hp -= dealt * (GUARD_CRACK_MULT - 1.0)
			if hp <= 0.001:
				opened_kill = true
				_die(hit)
				return HitResult.KILLED
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
		surge_attack = false
		lunge_attack = false
		is_counter_attack = false
		surge_progress = 0.0
		guard_cracked_t = 0.0
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max * 0.55
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		surge_cd = 0.85
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.26, 92.0, 92.0)
		_emit_sfx("tide_captain_phase2")
		return true
	return false


func _step_brain(dt: float) -> void:
	surge_cd = maxf(0.0, surge_cd - dt)
	guard_cracked_t = maxf(0.0, guard_cracked_t - dt)
	feint_ghost_t = maxf(0.0, feint_ghost_t - dt)
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
	if surge_cd <= 0.0 and (phase >= 2 or swings_since_surge >= 1) and dist < SURGE_MAX_R + 14.0 \
			and _claim_token():
		surge_attack = true
		lunge_attack = false
		is_counter_attack = false
		state = State.TELL
		var base_t: float = SURGE_TELL_P2 if phase >= 2 else SURGE_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		surge_progress = 0.0
		surge_hit = false
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()
		surge_dir = Vector2.from_angle(facing)
		swings_since_surge = 0
		_emit_attack_started()
		_emit_sfx("tide_captain_slam_tell")
		return true
	surge_attack = false
	return super._try_start_attack(target_pos, dist)


func _begin_swing_tell(is_lunge: bool) -> void:
	feint_done = false
	feint_side = -feint_side
	super._begin_swing_tell(is_lunge)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if surge_attack:
		if state_timer > 0.20:
			var to_t: Vector2 = target_pos - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 2.6, dt)
				surge_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	# P2 Lateral Claw-Rush Feint during melee/lunge tell
	if phase >= 2 and not is_counter_attack and not feint_done and state_timer <= last_tell_duration * 0.65:
		feint_done = true
		feint_ghost_pos = pos
		feint_ghost_t = 0.28
		var to_f: Vector2 = target_pos - pos
		var perp: Vector2 = (to_f.normalized() if to_f.length() > 0.01 else Vector2.from_angle(facing)).rotated(PI * 0.5 * feint_side)
		_move_step(perp * FEINT_DIST, false)
		if target_pos.distance_to(pos) > 0.01:
			facing = (target_pos - pos).angle()
		_emit_sfx("tide_captain_feint")
	super._step_tell(dt, target_pos)


func _enter_commit() -> void:
	if surge_attack:
		state = State.COMMIT
		state_timer = SURGE_FIRE_TIME
		surge_progress = 0.0
		surge_hit = false
		surge_dir = Vector2.from_angle(facing)
		_boss_impact(0.18, 84.0, 88.0)
		_emit_sfx("tide_captain_slam_fire")
		return
	swings_since_surge += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not surge_attack:
		super._step_commit(dt)
		return
	state_timer = maxf(0.0, state_timer - dt)
	surge_progress = 1.0 - clampf(state_timer / SURGE_FIRE_TIME, 0.0, 1.0)
	var wave_r: float = lerpf(SURGE_START_R, SURGE_MAX_R, surge_progress)
	var cone_a: float = surge_dir.angle()
	if not surge_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		var wd: float = wv.length()
		if wd > 0.01 and absf(wd - wave_r) <= SURGE_BAND \
				and absf(angle_difference(cone_a, wv.angle())) <= SURGE_HALF_ARC:
			surge_hit = true
			_emit_player_hit(surge_dir)
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
				Lx.player.call("apply_recoil", surge_dir * 65.0)
	if _is_lured():
		var lv: Vector2 = _get_lantern_pos() - pos
		if lv.length() <= wave_r + 4.0 and (lv.length() < 0.01 or absf(angle_difference(cone_a, lv.angle())) <= SURGE_HALF_ARC):
			if Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		surge_attack = false
		surge_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SURGE_RECOVER_P2 if phase >= 2 else SURGE_RECOVER_P1)
		last_recover_duration = state_timer
		surge_cd = SURGE_CD_P2 if phase >= 2 else SURGE_CD_P1


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
	if not surge_attack:
		super._draw_extra(off)
	if _sprite_sheet == null:
		# Naval bicorne hat silhouette
		var hat_y: float = -body_radius - 2.0
		draw_line(off + Vector2(-7.0, hat_y), off + Vector2(7.0, hat_y), PAL["deep"] as Color, 3.0)
		draw_line(off + Vector2(-4.5, hat_y - 2.5), off + Vector2(4.5, hat_y - 2.5), PAL["gold"] as Color, 1.5)
	var c: Vector2 = off.round()
	if feint_ghost_t > 0.0:
		var gp: Vector2 = (feint_ghost_pos - pos + off).round()
		draw_line(gp, c, PAL["sky"] as Color, 1.4)
		draw_arc(gp, body_radius, 0.0, TAU, 12, PAL["ice"] as Color, 1.2)
	if guard_cracked_t > 0.0:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 18, PAL["sky"] as Color, 1.8)
		draw_arc(c, body_radius + 2.5, 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	if surge_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var ca: float = surge_dir.angle()
		var a0: float = ca - SURGE_HALF_ARC
		var a1: float = ca + SURGE_HALF_ARC
		var hot: bool = state_timer <= 0.16
		var edge_c: Color = (PAL["cream"] if hot else PAL["sky"]) as Color
		draw_line(c, (c + Vector2.from_angle(a0) * SURGE_MAX_R).round(), edge_c, 1.5 if hot else 1.2)
		draw_line(c, (c + Vector2.from_angle(a1) * SURGE_MAX_R).round(), edge_c, 1.5 if hot else 1.2)
		draw_arc(c, SURGE_MAX_R, a0, a1, 14, PAL["blue"] as Color, 1.2)
		var inner_r: float = lerpf(SURGE_START_R + 6.0, SURGE_MAX_R * 0.72, prog)
		draw_arc(c, inner_r, a0, a1, 14, (PAL["cream"] if hot else PAL["ice"]) as Color, 2.0 if hot else 1.5)
	elif surge_attack and state == State.COMMIT:
		var wave_r: float = lerpf(SURGE_START_R, SURGE_MAX_R, surge_progress)
		var ca: float = surge_dir.angle()
		var a0: float = ca - SURGE_HALF_ARC
		var a1: float = ca + SURGE_HALF_ARC
		draw_arc(c, wave_r + 3.2, a0, a1, 18, PAL["deep"] as Color, 2.4)
		draw_arc(c, wave_r + 1.4, a0, a1, 18, PAL["blue"] as Color, 2.8)
		draw_arc(c, wave_r, a0, a1, 18, PAL["sky"] as Color, 3.4)
		draw_arc(c, maxf(3.0, wave_r - 2.2), a0, a1, 16, PAL["ice"] as Color, 2.0)
		draw_arc(c, maxf(3.0, wave_r - 3.6), a0, a1, 14, PAL["cream"] as Color, 1.1)
		for ti: int in range(5):
			var ta: float = lerpf(a0 + 0.08, a1 - 0.08, float(ti) / 4.0)
			var td: Vector2 = Vector2.from_angle(ta)
			var crest: Vector2 = (c + td * (wave_r + 1.5)).round()
			draw_circle(crest, 1.4, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.4, 0.0, TAU, 28, PAL["sky"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.2)
		draw_arc(c, maxf(3.0, rr - 2.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.10, 1.38, 0.38, "ice")
