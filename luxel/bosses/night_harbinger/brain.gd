class_name LxNightHarbingerBoss
extends LxMoonshadeBrain
## The Long Night mini-boss (Island 8): Night Harbinger, elite lunar Moonshade Warden.
## 2 phases, HP 14.5, lunar shield 2.4.
## Pairs blink-feint lunges with Twin Blink-Cross Slash (lateral blink leaving a moon-echo
## that fires a delayed crescent arc, tell >= 0.50s)!

const BLINK_TELL_P1: float = 0.56
const BLINK_TELL_P2: float = 0.50
const BLINK_DIST: float = 26.0
const MAIN_SLASH_TIME: float = 0.22
const ECHO_SLASH_TIME: float = 0.28
const BLINK_COMMIT_TIME: float = MAIN_SLASH_TIME + ECHO_SLASH_TIME
const MAIN_SLASH_R: float = 48.0
const MAIN_SLASH_ARC: float = 1.28
const ECHO_CRESCENT_RANGE: float = 78.0
const ECHO_CRESCENT_HALF_W: float = 14.0
const BLINK_RECOVER_P1: float = 1.15
const BLINK_RECOVER_P2: float = 1.00
const BLINK_CD_P1: float = 3.8
const BLINK_CD_P2: float = 2.7
const PHASE2_ROAR_TIME: float = 0.58

var blink_slash_attack: bool = false
var blink_cd: float = 1.6
var blink_elapsed: float = 0.0
var main_slash_dir: Vector2 = Vector2.RIGHT
var main_slash_hit: bool = false
var echo_pos: Vector2 = Vector2.ZERO
var echo_dir: Vector2 = Vector2.RIGHT
var echo_fired: bool = false
var echo_hit: bool = false
var swings_since_blink: int = 0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "night_harbinger"
	boss_id = "night_harbinger"
	island_id = 8
	is_boss = true
	variant = VARIANT_WARDEN
	max_hp = 14.5
	hp = 14.5
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
	max_hp = maxf(14.5, max_hp)
	hp = max_hp
	variant = VARIANT_WARDEN
	kind = "night_harbinger"
	is_boss = true
	boss_id = str(spec.get("boss_id", "night_harbinger"))
	island_id = int(spec.get("island_id", 8))
	blink_slash_attack = false
	blink_cd = 1.6
	blink_elapsed = 0.0
	main_slash_dir = Vector2.from_angle(facing)
	main_slash_hit = false
	echo_pos = pos
	echo_dir = Vector2.from_angle(facing)
	echo_fired = false
	echo_hit = false
	swings_since_blink = 0
	_roaring = false


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		wary = false
		_roaring = true
		blink_slash_attack = false
		lunge_attack = false
		is_counter_attack = false
		blink_elapsed = 0.0
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max * 0.55
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		blink_cd = 0.80
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.28, 96.0, 96.0)
		_emit_sfx("night_harbinger_phase2")
		return true
	return false


func _step_brain(dt: float) -> void:
	if _roaring and state != State.NOTICE: _roaring = false
	blink_cd = maxf(0.0, blink_cd - dt)
	super._step_brain(dt)


func _on_stagger_end(target_pos: Vector2) -> void:
	blink_slash_attack = false
	super._on_stagger_end(target_pos)


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
	if blink_cd <= 0.0 and (phase >= 2 or swings_since_blink >= 1) and dist < 96.0 \
			and _claim_token():
		blink_slash_attack = true
		lunge_attack = false
		is_counter_attack = false
		feint_done = false
		feint_side = -feint_side
		state = State.TELL
		var base_t: float = BLINK_TELL_P2 if phase >= 2 else BLINK_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		echo_pos = pos
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()
		main_slash_dir = Vector2.from_angle(facing)
		echo_dir = main_slash_dir
		blink_elapsed = 0.0
		main_slash_hit = false
		echo_fired = false
		echo_hit = false
		swings_since_blink = 0
		_emit_attack_started()
		_emit_sfx("harbinger_wave_tell")
		return true
	blink_slash_attack = false
	return super._try_start_attack(target_pos, dist)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if not blink_slash_attack:
		super._step_tell(dt, target_pos)
		return
	if not feint_done and state_timer <= last_tell_duration * 0.62:
		feint_done = true
		echo_pos = pos
		_do_lateral_feint(target_pos, BLINK_DIST)
	if state_timer > 0.18:
		var to_m: Vector2 = target_pos - pos
		if to_m.length() > 0.01:
			_turn_toward(to_m.angle(), 4.2, dt)
			main_slash_dir = Vector2.from_angle(facing)
		var to_e: Vector2 = target_pos - echo_pos
		if to_e.length() > 0.01:
			echo_dir = to_e.normalized()
	state_timer -= dt
	if state_timer <= 0.0:
		_enter_commit()


func _enter_commit() -> void:
	if blink_slash_attack:
		state = State.COMMIT
		state_timer = BLINK_COMMIT_TIME
		blink_elapsed = 0.0
		main_slash_hit = false
		echo_fired = false
		echo_hit = false
		main_slash_dir = Vector2.from_angle(facing)
		_boss_impact(0.16, 78.0, 82.0)
		_emit_sfx("warden_swing")
		return
	swings_since_blink += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not blink_slash_attack:
		super._step_commit(dt)
		return
	blink_elapsed += dt
	state_timer = maxf(0.0, state_timer - dt)
	if blink_elapsed <= MAIN_SLASH_TIME:
		# Phase A: Harbinger's primary crescent lunge-slash
		_move_step(main_slash_dir * 155.0 * dt, false)
		if not main_slash_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= MAIN_SLASH_R and (wv.length() < 0.01 or absf(angle_difference(main_slash_dir.angle(), wv.angle())) <= MAIN_SLASH_ARC):
				main_slash_hit = true
				_emit_player_hit(main_slash_dir)
		if _is_lured() and _get_lantern_pos().distance_to(pos) <= MAIN_SLASH_R:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
	else:
		# Phase B: Moon-echo fires its delayed crossing crescent arc!
		if not echo_fired:
			echo_fired = true
			LxDamageFx.boss_impact(echo_pos, 0.14, 72.0, 76.0, 68.0, 1.32, 0.28, "ice")
			_emit_sfx("harbinger_wave_fire")
		var e_prog: float = clampf((blink_elapsed - MAIN_SLASH_TIME) / ECHO_SLASH_TIME, 0.0, 1.0)
		var arc_pos: Vector2 = echo_pos + echo_dir * lerpf(8.0, ECHO_CRESCENT_RANGE, e_prog)
		if not echo_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			if arc_pos.distance_to(wp) <= ECHO_CRESCENT_HALF_W:
				echo_hit = true
				_emit_player_hit(echo_dir)
		if _is_lured() and arc_pos.distance_to(_get_lantern_pos()) <= ECHO_CRESCENT_HALF_W + 2.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		blink_slash_attack = false
		blink_elapsed = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, BLINK_RECOVER_P2 if phase >= 2 else BLINK_RECOVER_P1)
		last_recover_duration = state_timer
		blink_cd = BLINK_CD_P2 if phase >= 2 else BLINK_CD_P1


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
	if not blink_slash_attack:
		super._draw_extra(off)
	if _sprite_sheet == null:
		# Twin lunar crescent horns
		draw_arc(off + Vector2(0.0, -body_radius - 2.0), 5.5, 0.25, PI - 0.25, 12, PAL["ice"] as Color, 1.8)
	var c: Vector2 = off.round()
	if blink_slash_attack and state == State.TELL:
		var ep: Vector2 = (echo_pos - pos + off).round()
		var hot: bool = state_timer <= 0.18
		var ma: float = main_slash_dir.angle()
		# Primary slash arc preview
		draw_arc(c, MAIN_SLASH_R, ma - MAIN_SLASH_ARC * 0.75, ma + MAIN_SLASH_ARC * 0.75, 14, (PAL["coral"] if hot else PAL["gold"]) as Color, 1.6 if hot else 1.2)
		draw_line(c, (c + main_slash_dir * MAIN_SLASH_R).round(), (PAL["cream"] if hot else PAL["coral"]) as Color, 1.2)
		# Moon-echo silhouette + delayed crossing crescent sightline
		if feint_done:
			draw_line(ep, c, PAL["blue"] as Color, 1.2)
			draw_arc(ep, body_radius + 1.0, 0.0, TAU, 14, PAL["sky"] as Color, 1.4)
			draw_circle(ep, body_radius * 0.65, PAL["deep"] as Color)
			_draw_eclipse_diamond(ep, 3.5, PAL["ice"] as Color, PAL["cream"] as Color)
			var e_end: Vector2 = (ep + echo_dir * ECHO_CRESCENT_RANGE).round()
			draw_line(ep, e_end, (PAL["cream"] if hot else PAL["sky"]) as Color, 1.4 if hot else 1.1)
			var ea: float = echo_dir.angle()
			draw_arc((ep + echo_dir * 26.0).round(), 12.0, ea - 0.9, ea + 0.9, 10, PAL["ice"] as Color, 1.4)
	elif blink_slash_attack and state == State.COMMIT:
		var ep2: Vector2 = (echo_pos - pos + off).round()
		if blink_elapsed <= MAIN_SLASH_TIME:
			var prog1: float = clampf(blink_elapsed / MAIN_SLASH_TIME, 0.0, 1.0)
			var ma: float = main_slash_dir.angle()
			var a0: float = ma - MAIN_SLASH_ARC * 0.85
			var a1: float = lerpf(a0 + 0.35, ma + MAIN_SLASH_ARC * 0.85, prog1)
			draw_arc(c, MAIN_SLASH_R, a0, a1, 16, PAL["coral"] as Color, 3.0)
			draw_arc(c, MAIN_SLASH_R - 2.5, a0, a1, 14, PAL["gold"] as Color, 1.8)
			draw_arc(c, MAIN_SLASH_R - 4.0, a0 + 0.1, a1, 12, PAL["cream"] as Color, 1.0)
			# Moon-echo charging for delayed cross-slash
			draw_arc(ep2, body_radius + 3.0, 0.0, TAU, 14, PAL["ice"] as Color, 1.6)
			draw_line(ep2, (ep2 + echo_dir * ECHO_CRESCENT_RANGE).round(), PAL["sky"] as Color, 1.2)
		else:
			var e_prog: float = clampf((blink_elapsed - MAIN_SLASH_TIME) / ECHO_SLASH_TIME, 0.0, 1.0)
			var arc_c: Vector2 = (ep2 + echo_dir * lerpf(8.0, ECHO_CRESCENT_RANGE, e_prog)).round()
			var ea: float = echo_dir.angle()
			draw_line(ep2, arc_c, PAL["deep"] as Color, 2.0)
			draw_arc(arc_c, 15.0, ea - 1.15, ea + 1.15, 14, PAL["sky"] as Color, 3.2)
			draw_arc(arc_c, 13.5, ea - 1.05, ea + 1.05, 12, PAL["ice"] as Color, 2.0)
			draw_arc(arc_c, 12.0, ea - 0.90, ea + 0.90, 10, PAL["cream"] as Color, 1.2)
			_draw_eclipse_diamond(arc_c + echo_dir * 12.0, 3.0, PAL["gold"] as Color, PAL["cream"] as Color)
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


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.44, 0.40)
