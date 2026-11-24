class_name LxGloamBrain
extends LxEnemyBrain
## Gloam (Island 3): drifts between dark pools; shadowy/intangible in darkness
## (reduces bolts until illuminated), becomes solid & targetable in Wick's lantern
## or Lens light; lunges from dark after 0.45s tell, recovers 1.00s.

const DEFAULT_HAND_LIGHT_R: float = 52.0
const DEFAULT_HUNG_LIGHT_R: float = 104.0
const LIGHT_HOLD_DURATION: float = 0.25
const BEAM_FLASH_DURATION: float = 1.20
const DARK_BOLT_MULT: float = 0.15
const LUNGE_RANGE: float = 96.0
const LUNGE_SPEED: float = 245.0
const LUNGE_TIME: float = 0.26
const LUNGE_HIT_R: float = 14.0
const POST_COOLDOWN: float = 1.05

var pools: Array[Vector2] = []
var pool_i: int = 0
var pause_t: float = 0.0
var illuminated: bool = false
var light_hold_t: float = 0.0
var phase_fx_t: float = 0.0
var lunge_dir: Vector2 = Vector2.RIGHT
var lunge_hit: bool = false

func _init() -> void:
	kind = "gloam"
	island_id = 3
	max_hp = 2.25
	hp = 2.25
	body_radius = 5.5
	routine_speed = 42.0
	leash_radius = 156.0
	notice_radius = 136.0
	tell_time = 0.45
	recover_time = 1.00
	give_up_time = 1.8
	shard_drop = 3

func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	pools.clear()
	var raw_pts: Variant = spec.get("route", spec.get("perches", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				pools.append(_clamp_pt(_to_vec2(pt_v, home)))
	if pools.size() < 2:
		var r: float = minf(52.0, leash_radius * 0.45)
		pools = [_clamp_pt(home + Vector2(-r, -r * 0.3)), _clamp_pt(home + Vector2(r, r * 0.3)), home]
	pool_i = 0
	pause_t = 0.4
	illuminated = false
	light_hold_t = 0.0
	phase_fx_t = 0.0
	lunge_dir = Vector2.from_angle(facing)
	lunge_hit = false

func on_light(a: Variant, b: Variant = Vector2.ZERO, _c: Variant = "") -> void:
	var radius: float = 0.0
	var orig: Vector2 = Vector2.ZERO
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		radius = float(b)
	elif a is float or a is int:
		radius = float(a)
		if b is Vector2:
			orig = b as Vector2
	if radius <= 0.0:
		return
	if orig == Vector2.ZERO or pos.distance_to(orig) <= radius + body_radius:
		light_hold_t = LIGHT_HOLD_DURATION
		illuminated = true

func is_targetable() -> bool:
	return is_alive() and (illuminated or state == State.RECOVER or state == State.STAGGER)

func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	if src == LxHit.SOURCE_BEAM:
		light_hold_t = maxf(light_hold_t, BEAM_FLASH_DURATION)
		illuminated = true
		_emit_sfx("gloam_reveal")
	elif src == LxHit.SOURCE_SUNFLARE or src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL:
		light_hold_t = maxf(light_hold_t, LIGHT_HOLD_DURATION * 2.0)
		illuminated = true
	var solid: bool = illuminated or state == State.RECOVER or state == State.STAGGER
	if not solid:
		phase_fx_t = 0.24
		if src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM:
			hp -= dmg * DARK_BOLT_MULT
			_emit_sfx("gloam_phase")
			if hp <= 0.001:
				_die(hit)
				return HitResult.KILLED
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED
		dmg *= 0.35
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 30.0)
	if hp <= 0.001:
		opened_kill = solid
		_die(hit)
		return HitResult.KILLED
	if is_heavy and solid:
		_release_token()
		state = State.STAGGER
		state_timer = 0.50
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		state = State.NOTICE
		state_timer = 0.30
		alert_t = 0.75
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED

func _step_brain(dt: float) -> void:
	phase_fx_t = maxf(0.0, phase_fx_t - dt)
	_update_illumination(dt)
	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target(target_pos):
				state = State.NOTICE
				state_timer = 0.30
				alert_t = 0.75
				lost_t = 0.0
				_emit_sfx("gloam_notice")
		State.NOTICE:
			_face_point(target_pos, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_stalk(dt, target_pos)
		State.TELL:
			if state_timer > 0.15 * _assist_tell_scale():
				_face_point(target_pos, 3.0, dt)
				lunge_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)

func _update_illumination(dt: float) -> void:
	light_hold_t = maxf(0.0, light_hold_t - dt)
	var hand_r: float = DEFAULT_HAND_LIGHT_R
	var hung_r: float = DEFAULT_HUNG_LIGHT_R
	if _is_lantern_out():
		if pos.distance_to(_get_lantern_pos()) <= hung_r + body_radius:
			light_hold_t = maxf(light_hold_t, LIGHT_HOLD_DURATION)
	elif _has_player() and pos.distance_to(_get_wick_pos()) <= hand_r + body_radius:
		light_hold_t = maxf(light_hold_t, LIGHT_HOLD_DURATION)
	illuminated = light_hold_t > 0.0

func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = pools[pool_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		pool_i = (pool_i + 1) % pools.size()
		pause_t = 0.85
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.78 * dt), false)

func _step_stalk(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.2, dt)
	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0
	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN
	if is_lead and cooldown <= 0.0 and dist <= LUNGE_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		lunge_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = lunge_dir.angle()
		_emit_attack_started()
		_emit_sfx("gloam_tell")
		return
	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var perp: Vector2 = Vector2(-fwd.y, fwd.x) * (1.0 if (slot % 2 == 0) else -1.0)
	var radial: float = clampf((dist - 56.0) / 28.0, -0.5, 0.6)
	var spd: float = minf(routine_speed * 0.85, routine_speed - 2.0)
	_move_step((perp * 0.75 + fwd * radial).normalized() * spd * dt, false)

func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LUNGE_TIME
	lunge_hit = false
	LxDamageFx.boss_impact(pos, 0.06, 36.0, 46.0)
	_emit_sfx("gloam_lunge")

func _step_commit(dt: float) -> void:
	_move_step(lunge_dir * LUNGE_SPEED * dt, false)
	if not lunge_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= LUNGE_HIT_R:
		lunge_hit = true
		_emit_player_hit(lunge_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer

func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)

func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 1.0)
	return (home + (pt - home).normalized() * cap) if pt.distance_to(home) > cap else pt

func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0

func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()

func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius

func _visual_offset() -> Vector2:
	return Vector2(0.0, -2.5 + sin(anim_t * 4.5) * 1.5)

func _body_color() -> Color:
	return (PAL["mauve"] as Color) if (illuminated or state == State.RECOVER) else (PAL["void"] as Color)

func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		var rim: Color = (PAL["ice"] as Color) if (illuminated or phase_fx_t > 0.0) else (PAL["dusk"] as Color)
		draw_arc(off, body_radius + 2.0, 0.0, TAU, 14, rim, 1.5 if illuminated else 1.0)
		var fwd: Vector2 = Vector2.from_angle(facing)
		var side: Vector2 = Vector2(-fwd.y, fwd.x)
		draw_circle(off + fwd * 2.0 + side * 2.0, 1.2, PAL["ice"] as Color)
		draw_circle(off + fwd * 2.0 - side * 2.0, 1.2, PAL["ice"] as Color)
	elif illuminated:
		draw_arc(off, body_radius + 3.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.4)
	var c: Vector2 = off.round()
	if state == State.TELL:
		var locked: bool = state_timer <= 0.15 * _assist_tell_scale()
		var reach_len: float = LUNGE_SPEED * LUNGE_TIME
		var tip: Vector2 = (c + lunge_dir * reach_len).round()
		var line_c: Color = (PAL["coral"] as Color) if locked else (PAL["ice"] as Color)
		if locked:
			draw_line(c, tip, line_c, 1.4)
		else:
			for si: int in range(0, 10, 2):
				var p0: Vector2 = (c + lunge_dir * (reach_len * float(si) / 10.0)).round()
				var p1: Vector2 = (c + lunge_dir * (reach_len * float(si + 1) / 10.0)).round()
				draw_line(p0, p1, line_c, 1.2)
		var perp_t := Vector2(-lunge_dir.y, lunge_dir.x)
		draw_line((tip - lunge_dir * 4.0 + perp_t * 3.0).round(), tip, line_c, 1.2)
		draw_line((tip - lunge_dir * 4.0 - perp_t * 3.0).round(), tip, line_c, 1.2)
		draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT:
		var perp: Vector2 = Vector2(-lunge_dir.y, lunge_dir.x)
		var la: float = lunge_dir.angle()
		draw_line(c, (c - lunge_dir * 22.0).round(), PAL["void"] as Color, 4.0)
		for si: int in range(-1, 2, 2):
			var s: float = float(si)
			draw_line((c + perp * (s * 3.0)).round(), (c - lunge_dir * 18.0 + perp * (s * 4.5)).round(), PAL["plum"] as Color, 1.6)
			draw_line((c + perp * (s * 1.5)).round(), (c - lunge_dir * 13.0 + perp * (s * 2.0)).round(), PAL["sky"] as Color, 1.0)
		draw_arc((c - lunge_dir * 8.0).round(), body_radius * 0.9, la + PI * 0.55, la + PI * 1.45, 8, PAL["plum"] as Color, 1.8)
		draw_arc((c - lunge_dir * 15.0).round(), body_radius * 0.72, la + PI * 0.65, la + PI * 1.35, 6, PAL["sky"] as Color, 1.2)
		draw_line((c + lunge_dir * 4.0).round(), (c - lunge_dir * 10.0).round(), PAL["ice"] as Color, 1.2)
	if phase_fx_t > 0.0:
		var pf: float = clampf(phase_fx_t / 0.24, 0.0, 1.0)
		var d: float = roundf(body_radius + 3.0 + (1.0 - pf) * 4.0)
		var id: float = roundf(d * 0.58)
		var top: Vector2 = c + Vector2(0.0, -d)
		var bot: Vector2 = c + Vector2(0.0, d)
		var lft: Vector2 = c + Vector2(-d, 0.0)
		var rgt: Vector2 = c + Vector2(d, 0.0)
		draw_line(top, rgt, PAL["ice"] as Color, 1.4)
		draw_line(rgt, bot, PAL["ice"] as Color, 1.4)
		draw_line(bot, lft, PAL["ice"] as Color, 1.4)
		draw_line(lft, top, PAL["ice"] as Color, 1.4)
		draw_line(c + Vector2(0.0, -id), c + Vector2(id, 0.0), PAL["cream"] as Color, 1.0)
		draw_line(c + Vector2(id, 0.0), c + Vector2(0.0, id), PAL["cream"] as Color, 1.0)
		draw_line(c + Vector2(0.0, id), c + Vector2(-id, 0.0), PAL["cream"] as Color, 1.0)
		draw_line(c + Vector2(-id, 0.0), c + Vector2(0.0, -id), PAL["cream"] as Color, 1.0)
		draw_rect(Rect2(top, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		draw_rect(Rect2(bot, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		draw_rect(Rect2(lft, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		draw_rect(Rect2(rgt, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
