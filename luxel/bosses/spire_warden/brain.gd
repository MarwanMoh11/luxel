class_name LxSpireWardenBoss
extends LxMoonshadeBrain
## Mirror Spire mini-boss (Island 7): Silver Mirror-Knight Sentinel.
## 2 phases, HP 7.5, prismatic mirror-buckler 2.2 (cracked by refracted Blue Bolts or Moon-Mirror Pedestal).
## P1: Prismatic Spear Lunge + Lunar Arc. P2 (<=55% HP): Roar + buckler reform + Mirror-Blink Cross-Lunge.

const SPEAR_TELL_P1: float = 0.56
const SPEAR_TELL_P2: float = 0.48
const SPEAR_COMMIT_TIME: float = 0.24
const MIRROR_COMMIT_TIME: float = 0.22
const SPEAR_RANGE: float = 96.0
const SPEAR_HALF_W: float = 11.0
const SPEAR_LUNGE_SPEED: float = 250.0
const SPEAR_ARC_R: float = 38.0
const SPEAR_HALF_ARC: float = 1.05
const MIRROR_RANGE: float = 88.0
const MIRROR_HALF_W: float = 12.0
const BLINK_DIST: float = 26.0
const SPEAR_RECOVER_P1: float = 1.15
const SPEAR_RECOVER_P2: float = 0.98
const SPEAR_CD_P1: float = 3.4
const SPEAR_CD_P2: float = 2.3
const GUARD_CRACK_STAGGER: float = 1.35
const GUARD_CRACK_MULT: float = 1.45
const PHASE2_ROAR_TIME: float = 0.58

var spear_attack: bool = false
var spear_cd: float = 1.4
var spear_elapsed: float = 0.0
var spear_dir: Vector2 = Vector2.RIGHT
var spear_hit: bool = false
var mirror_pos: Vector2 = Vector2.ZERO
var mirror_dir: Vector2 = Vector2.RIGHT
var mirror_fired: bool = false
var mirror_hit: bool = false
var swings_since_spear: int = 0
var guard_cracked_t: float = 0.0
var shimmer_t: float = 0.0
var _roaring: bool = false

func _init() -> void:
	super._init()
	kind = "spire_warden"; boss_id = "moonshade_warden"; island_id = 7; is_boss = true; variant = VARIANT_WARDEN
	max_hp = 7.5; hp = 7.5; shield_max = 2.2; shield_hp = 2.2; shield_gone_duration = 4.6
	body_radius = 6.5; routine_speed = 40.0; leash_radius = 175.0; notice_radius = 142.0
	reach = 38.0; lunge_reach = 98.0; swing_r = 30.0; swing_arc = 1.20
	tell_time = 0.48; lunge_tell_time = 0.54; recover_time = 1.12; give_up_time = 1.8; shard_drop = 14

func _configure_variant_defaults() -> void:
	variant = VARIANT_WARDEN; body_radius = 6.5; routine_speed = 40.0
	shield_max = 2.2; tell_time = 0.48; recover_time = 1.12

func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var forced: Dictionary = spec.duplicate()
	forced["variant"] = VARIANT_WARDEN
	forced["kind"] = "spire_warden"
	super.setup(forced, p_director, p_world)
	variant = VARIANT_WARDEN; kind = "spire_warden"; is_boss = true
	boss_id = str(spec.get("boss_id", "moonshade_warden"))
	island_id = int(spec.get("island_id", 7))
	spear_attack = false; spear_cd = 1.4; spear_elapsed = 0.0; spear_hit = false
	spear_dir = Vector2.from_angle(facing); mirror_pos = pos; mirror_dir = spear_dir
	mirror_fired = false; mirror_hit = false; swings_since_spear = 0
	guard_cracked_t = 0.0; shimmer_t = 0.0; _roaring = false

func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null: return HitResult.GLANCED
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var is_blue_hit: bool = hit.is_blue() or str(h["source"]) == LxHit.SOURCE_PRISM
	if is_blue_hit and _has_active_shield():
		var rel: Vector2 = (h["origin"] as Vector2) - pos
		shield_hp = 0.0; shield_gone_t = shield_gone_duration; guard_cracked_t = GUARD_CRACK_STAGGER
		wary = true; spear_attack = false; lunge_attack = false; is_counter_attack = false
		hp -= float(h["damage"]) * GUARD_CRACK_MULT
		flash_t = 0.18
		if rel.length() > 0.01: knock = -rel.normalized() * 72.0
		shield_broken.emit(self, pos)
		_boss_impact(0.18, 78.0, 82.0)
		_emit_sfx("warden_shield_break"); _emit_sfx("lens_reveal")
		if hp <= 0.001:
			opened_kill = true; _die(hit); return HitResult.KILLED
		if not _check_phase_transition():
			_release_token(); state = State.STAGGER; state_timer = GUARD_CRACK_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	var hp_before: float = hp
	var res: int = super.take_hit(hit)
	if is_alive() and guard_cracked_t > 0.0 and not is_blue_hit and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		var dealt: float = maxf(0.0, hp_before - hp)
		if dealt > 0.001:
			hp -= dealt * (GUARD_CRACK_MULT - 1.0)
			if hp <= 0.001:
				opened_kill = true; _die(hit); return HitResult.KILLED
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res

func _is_hit_invulnerable() -> bool: return _roaring
func _on_damaged_alive(_hit: LxHit) -> bool: return _check_phase_transition()
func _swing_tell_base() -> float: return 0.42 if phase >= 2 else tell_time
func _lunge_tell_base() -> float: return 0.48 if phase >= 2 else lunge_tell_time
func _post_recover_cooldown() -> float: return 0.68 if phase >= 2 else 0.88
func _body_color() -> Color: return (LxPalette.PAL["sky"] if phase >= 2 else LxPalette.PAL["deep"]) as Color
func _shield_color() -> Color: return LxPalette.PAL["ice"] as Color

func _check_phase_transition() -> bool:
	if phase < 2 and hp <= max_hp * 0.55 and hp > 0.001:
		phase = 2; wary = false; _roaring = true
		spear_attack = false; lunge_attack = false; is_counter_attack = false
		spear_elapsed = 0.0; guard_cracked_t = 0.0; shimmer_t = 0.65
		shield_gone_t = 0.0; shield_hp = shield_max
		shield_reformed.emit(self, pos)
		_release_token(); state = State.NOTICE; state_timer = PHASE2_ROAR_TIME; spear_cd = 0.75
		LxDamageFx.trigger_boss_phase_reset(self, 2)
		if Lx.events != null: Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.26, 94.0, 94.0)
		_emit_sfx("boss_roar_spire"); _emit_sfx("lens_reveal")
		return true
	return false

func _step_brain(dt: float) -> void:
	spear_cd = maxf(0.0, spear_cd - dt)
	guard_cracked_t = maxf(0.0, guard_cracked_t - dt)
	shimmer_t = maxf(0.0, shimmer_t - dt)
	super._step_brain(dt)

func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01: _turn_toward(to_t.angle(), TURN_PATROL * 1.5, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false; state = State.POSITION; step_clock = 0.0; cooldown = 0.35

func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if spear_cd <= 0.0 and (phase >= 2 or swings_since_spear >= 1) and dist < SPEAR_RANGE + 16.0 and _claim_token():
		spear_attack = true; lunge_attack = false; is_counter_attack = false
		feint_done = false; feint_side = -feint_side; state = State.TELL
		last_tell_duration = _scaled_tell(SPEAR_TELL_P2 if phase >= 2 else SPEAR_TELL_P1, false, attack_damage)
		state_timer = last_tell_duration; mirror_pos = pos
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01: facing = to_t.angle()
		spear_dir = Vector2.from_angle(facing); mirror_dir = spear_dir
		spear_elapsed = 0.0; spear_hit = false; mirror_fired = false; mirror_hit = false; swings_since_spear = 0
		_emit_attack_started(); _emit_sfx("harbinger_wave_tell")
		return true
	spear_attack = false
	return super._try_start_attack(target_pos, dist)

func _step_tell(dt: float, target_pos: Vector2) -> void:
	if not spear_attack:
		super._step_tell(dt, target_pos); return
	if phase >= 2 and not feint_done and state_timer <= last_tell_duration * 0.62:
		feint_done = true; mirror_pos = pos
		_do_lateral_feint(target_pos, BLINK_DIST)
	if state_timer > 0.16:
		var to_m: Vector2 = target_pos - pos
		if to_m.length() > 0.01:
			_turn_toward(to_m.angle(), 4.2, dt); spear_dir = Vector2.from_angle(facing)
		var to_r: Vector2 = target_pos - mirror_pos
		if to_r.length() > 0.01: mirror_dir = to_r.normalized()
	state_timer -= dt
	if state_timer <= 0.0: _enter_commit()

func _enter_commit() -> void:
	if spear_attack:
		state = State.COMMIT
		state_timer = (SPEAR_COMMIT_TIME + MIRROR_COMMIT_TIME) if (phase >= 2 and feint_done) else SPEAR_COMMIT_TIME
		spear_elapsed = 0.0; spear_hit = false; mirror_fired = false; mirror_hit = false
		spear_dir = Vector2.from_angle(facing)
		_boss_impact(0.16, 76.0, 80.0); _emit_sfx("warden_swing")
		return
	swings_since_spear += 1
	super._enter_commit()

func _step_commit(dt: float) -> void:
	if not spear_attack:
		super._step_commit(dt); return
	spear_elapsed += dt
	state_timer = maxf(0.0, state_timer - dt)
	if spear_elapsed <= SPEAR_COMMIT_TIME:
		_move_step(spear_dir * (SPEAR_LUNGE_SPEED * (1.14 if phase >= 2 else 1.0)) * dt, false)
		if not spear_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= SPEAR_ARC_R and (wv.length() < 0.01 or absf(angle_difference(spear_dir.angle(), wv.angle())) <= SPEAR_HALF_ARC):
				spear_hit = true; _emit_player_hit(spear_dir)
		if _is_lured() and _get_lantern_pos().distance_to(pos) <= SPEAR_ARC_R and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	elif phase >= 2 and feint_done:
		if not mirror_fired:
			mirror_fired = true
			LxDamageFx.boss_impact(mirror_pos, 0.14, 72.0, 76.0, 68.0, 1.32, 0.28, "ice")
			_emit_sfx("lens_reveal")
		var m_prog: float = clampf((spear_elapsed - SPEAR_COMMIT_TIME) / MIRROR_COMMIT_TIME, 0.0, 1.0)
		var m_pt: Vector2 = mirror_pos + mirror_dir * lerpf(8.0, MIRROR_RANGE, m_prog)
		if not mirror_hit and _has_player() and m_pt.distance_to(_get_wick_pos()) <= MIRROR_HALF_W:
			mirror_hit = true; _emit_player_hit(mirror_dir)
		if _is_lured() and m_pt.distance_to(_get_lantern_pos()) <= MIRROR_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		spear_attack = false; spear_elapsed = 0.0; state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SPEAR_RECOVER_P2 if phase >= 2 else SPEAR_RECOVER_P1)
		last_recover_duration = state_timer
		spear_cd = SPEAR_CD_P2 if phase >= 2 else SPEAR_CD_P1

func _draw_extra(off: Vector2) -> void:
	if not spear_attack: super._draw_extra(off)
	var pal: Dictionary = LxPalette.PAL
	var c: Vector2 = off.round()
	var fred: bool = LxHudFx.flash_reduced()
	if guard_cracked_t > 0.0:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 18, pal["sky"] as Color, 1.8)
		draw_arc(c, body_radius + 2.5, 0.0, TAU, 14, pal["cream"] as Color, 1.0)
	if shimmer_t > 0.0:
		var sp: float = 1.0 - clampf(shimmer_t / 0.65, 0.0, 1.0)
		draw_arc(c, body_radius + 6.0 + sp * 14.0, 0.0, TAU, 24, pal["ice"] as Color, 1.8 if fred else 2.2)
		draw_arc(c, body_radius + 3.0 + sp * 9.0, 0.0, TAU, 20, pal["sky"] as Color, 1.2)
	if spear_attack and state == State.TELL:
		var urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, c, c + spear_dir * SPEAR_RANGE, SPEAR_HALF_W, urg, anim_t, "coral", "gold")
		if phase >= 2 and feint_done:
			var mp: Vector2 = (mirror_pos - pos + off).round()
			LxBossTelegraphFx.draw_ground_danger_lane(self, mp, mp + mirror_dir * MIRROR_RANGE, MIRROR_HALF_W, urg, anim_t, "sky", "ice")
			draw_line(mp, c, pal["blue"] as Color, 1.2)
			draw_circle(mp, body_radius * 0.68, pal["deep"] as Color)
			draw_arc(mp, body_radius + 1.2, 0.0, TAU, 14, pal["ice"] as Color, 1.4)
			_draw_lunar_glint(mp, 3.5)
	elif spear_attack and state == State.COMMIT:
		var mp2: Vector2 = (mirror_pos - pos + off).round()
		if spear_elapsed <= SPEAR_COMMIT_TIME:
			var p1: float = clampf(spear_elapsed / SPEAR_COMMIT_TIME, 0.0, 1.0)
			var a0: float = spear_dir.angle() - SPEAR_HALF_ARC * 0.90
			var a1: float = lerpf(a0 + 0.30, spear_dir.angle() + SPEAR_HALF_ARC * 0.90, p1)
			draw_arc(c, SPEAR_ARC_R, a0, a1, 16, pal["blue"] as Color, 3.0)
			draw_arc(c, SPEAR_ARC_R - 2.2, a0, a1, 14, pal["sky"] as Color, 2.0)
			draw_arc(c, SPEAR_ARC_R - 3.8, a0 + 0.1, a1, 12, pal["cream"] as Color, 1.1)
			if phase >= 2 and feint_done:
				draw_arc(mp2, body_radius + 2.5, 0.0, TAU, 14, pal["ice"] as Color, 1.5)
				draw_line(mp2, (mp2 + mirror_dir * MIRROR_RANGE).round(), pal["sky"] as Color, 1.2)
		elif phase >= 2 and feint_done:
			var p2: float = clampf((spear_elapsed - SPEAR_COMMIT_TIME) / MIRROR_COMMIT_TIME, 0.0, 1.0)
			var tip: Vector2 = (mp2 + mirror_dir * lerpf(8.0, MIRROR_RANGE, p2)).round()
			draw_line(mp2, tip, pal["sky"] as Color, 2.6)
			draw_line(mp2, tip, pal["ice"] as Color, 1.6)
			draw_arc(tip, 11.0, mirror_dir.angle() - 1.05, mirror_dir.angle() + 1.05, 12, pal["cream"] as Color, 1.8)
			_draw_lunar_glint(tip, 4.0)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var r1: float = body_radius + 10.0 + rp * 18.0
		draw_arc(c, r1, 0.0, TAU, 28, pal["sky"] as Color, 2.2)
		draw_arc(c, maxf(4.0, r1 - 4.0), 0.0, TAU, 24, pal["ice"] as Color, 1.6)
		draw_arc(c, maxf(3.0, r1 - 6.5), 0.0, TAU, 20, pal["cream"] as Color, 1.0)

func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.10, 1.38, 0.38, "ice")
