class_name LxNightHarbingerBoss
extends LxMoonshadeBrain
## The Long Night mini-boss (Island 8): Night Harbinger, elite lunar Moonshade Warden.
## 2 phases, HP 9.0, lunar shield 2.4. Pairs blink-feint lunges with Shadow Crescent shockwaves.

const WAVE_TELL_P1: float = 0.58
const WAVE_TELL_P2: float = 0.50
const WAVE_COMMIT_TIME: float = 0.28
const WAVE_START_R: float = 10.0
const WAVE_MAX_R: float = 68.0
const WAVE_BAND: float = 9.5
const WAVE_RECOVER_P1: float = 1.15
const WAVE_RECOVER_P2: float = 1.00
const WAVE_CD_P1: float = 4.2
const WAVE_CD_P2: float = 2.9
const PHASE2_ROAR_TIME: float = 0.58

var wave_attack: bool = false
var wave_cd: float = 1.6
var wave_progress: float = 0.0
var wave_hit: bool = false
var swings_since_wave: int = 0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "night_harbinger"
	boss_id = "night_harbinger"
	island_id = 8
	is_boss = true
	variant = VARIANT_WARDEN
	max_hp = 9.0
	hp = 9.0
	shield_max = 2.4
	shield_hp = 2.4
	shield_gone_duration = 4.6
	body_radius = 7.0
	routine_speed = 42.0
	leash_radius = 175.0
	notice_radius = 144.0
	reach = 40.0
	lunge_reach = 104.0
	swing_r = 32.0
	swing_arc = 1.28
	tell_time = 0.48
	lunge_tell_time = 0.54
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 22


func _configure_variant_defaults() -> void:
	variant = VARIANT_WARDEN
	body_radius = 7.0
	routine_speed = 42.0
	shield_max = 2.4
	tell_time = 0.48
	recover_time = 1.10


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var forced: Dictionary = spec.duplicate()
	forced["variant"] = VARIANT_WARDEN
	super.setup(forced, p_director, p_world)
	variant = VARIANT_WARDEN
	kind = "night_harbinger"
	is_boss = true
	boss_id = str(spec.get("boss_id", "night_harbinger"))
	island_id = int(spec.get("island_id", 8))
	wave_attack = false
	wave_cd = 1.6
	wave_progress = 0.0
	wave_hit = false
	swings_since_wave = 0
	_roaring = false


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		wary = false
		_roaring = true
		wave_attack = false
		lunge_attack = false
		is_counter_attack = false
		wave_progress = 0.0
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max * 0.55
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		wave_cd = 0.80
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
			Lx.events.shake_requested.emit(0.28)
		_emit_sfx("night_harbinger_phase2")
		return true
	return false


func _step_brain(dt: float) -> void:
	wave_cd = maxf(0.0, wave_cd - dt)
	super._step_brain(dt)


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.5, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false
		state = State.POSITION
		step_clock = 0.0
		cooldown = 0.35


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if wave_cd <= 0.0 and (phase >= 2 or swings_since_wave >= 1) and dist < WAVE_MAX_R + 18.0 \
			and _claim_token():
		wave_attack = true
		lunge_attack = false
		is_counter_attack = false
		feint_done = false
		feint_side = -feint_side
		state = State.TELL
		var base_t: float = WAVE_TELL_P2 if phase >= 2 else WAVE_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		wave_progress = 0.0
		wave_hit = false
		swings_since_wave = 0
		_emit_attack_started()
		_emit_sfx("harbinger_wave_tell")
		return true
	wave_attack = false
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if wave_attack:
		state = State.COMMIT
		state_timer = WAVE_COMMIT_TIME
		wave_progress = 0.0
		wave_hit = false
		_emit_sfx("harbinger_wave_fire")
		return
	swings_since_wave += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not wave_attack:
		super._step_commit(dt)
		return
	state_timer = maxf(0.0, state_timer - dt)
	wave_progress = 1.0 - clampf(state_timer / WAVE_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(WAVE_START_R, WAVE_MAX_R, wave_progress)
	if not wave_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= WAVE_BAND:
			wave_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			var prev_kind: String = kind
			kind = "shockwave"
			_emit_player_hit(push)
			kind = prev_kind
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		wave_attack = false
		wave_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, WAVE_RECOVER_P2 if phase >= 2 else WAVE_RECOVER_P1)
		last_recover_duration = state_timer
		wave_cd = WAVE_CD_P2 if phase >= 2 else WAVE_CD_P1


func _swing_tell_base() -> float:
	return 0.42 if phase >= 2 else tell_time


func _lunge_tell_base() -> float:
	return 0.48 if phase >= 2 else lunge_tell_time


func _post_recover_cooldown() -> float:
	return 0.68 if phase >= 2 else 0.88


func _body_color() -> Color:
	return (PAL["plum"] as Color) if phase >= 2 else (PAL["deep"] as Color)


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if _sprite_sheet == null:
		# Twin lunar crescent horns
		draw_arc(off + Vector2(0.0, -body_radius - 2.0), 5.5, 0.25, PI - 0.25, 12, PAL["ice"] as Color, 1.8)
	var c: Vector2 = off.round()
	if wave_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, WAVE_MAX_R, a0, a0 + 0.24, 3, PAL["plum"] as Color, 1.0)
		var tr: float = lerpf(WAVE_MAX_R, WAVE_START_R + 6.0, prog)
		draw_arc(c, tr + 2.2, 0.0, TAU, 28, PAL["plum"] as Color, 1.6)
		draw_arc(c, tr, 0.0, TAU, 28, PAL["coral"] as Color, 1.8)
		draw_arc(c, maxf(4.0, tr - 2.2), 0.0, TAU, 24, PAL["ice"] as Color, 1.0)
	elif wave_attack and state == State.COMMIT:
		var ring_r: float = lerpf(WAVE_START_R, WAVE_MAX_R, wave_progress)
		draw_arc(c, ring_r + 3.6, 0.0, TAU, 36, PAL["plum"] as Color, 2.2)
		draw_arc(c, ring_r + 1.8, 0.0, TAU, 36, PAL["wine"] as Color, 2.6)
		draw_arc(c, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.0)
		draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["gold"] as Color, 1.6)
		draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["ice"] as Color, 1.1)
		for di: int in range(8):
			var da: float = anim_t * 2.4 + float(di) * (TAU / 8.0)
			var dp: Vector2 = c + Vector2.from_angle(da) * ring_r
			var d_out: Color = (PAL["gold"] if di % 2 == 0 else PAL["ice"]) as Color
			var d_in: Color = (PAL["ice"] if di % 2 == 0 else PAL["cream"]) as Color
			_draw_eclipse_diamond(dp, 3.0, d_out, d_in)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var r1: float = body_radius + 11.0 + rp * 18.0
		var r2: float = maxf(6.0, r1 - 6.5)
		draw_arc(c, r1, 0.0, TAU, 32, PAL["coral"] as Color, 2.4)
		draw_arc(c, r2, 0.0, TAU, 28, PAL["gold"] as Color, 2.0)
		draw_arc(c, maxf(4.0, r2 - 2.0), 0.0, TAU, 24, PAL["ice"] as Color, 1.1)
		for ri: int in range(4):
			var rd: Vector2 = Vector2.from_angle(float(ri) * (TAU * 0.25))
			draw_line((c + rd * (r1 - 3.5)).round(), (c + rd * (r1 + 4.5)).round(), PAL["gold"] as Color, 1.6)
			draw_line((c + rd * (r1 - 1.5)).round(), (c + rd * (r1 + 2.5)).round(), PAL["ice"] as Color, 1.0)


func _draw_eclipse_diamond(pt: Vector2, rad: float, outer: Color, inner: Color) -> void:
	var p: Vector2 = pt.round()
	var t: Vector2 = p + Vector2(0.0, -rad)
	var r: Vector2 = p + Vector2(rad, 0.0)
	var d: Vector2 = p + Vector2(0.0, rad)
	var l: Vector2 = p + Vector2(-rad, 0.0)
	draw_line(t, r, outer, 1.2)
	draw_line(r, d, outer, 1.2)
	draw_line(d, l, outer, 1.2)
	draw_line(l, t, outer, 1.2)
	draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), inner, true)
