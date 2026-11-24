class_name LxMoonshadeBrain
extends LxWardenBrain
## Moonshade variants (Island 7, Moon Shoals).
## Cool-palette (deep/blue/sky/ice) shades supporting:
## - "moonshade_warden": blink-feint lateral step + shield
## - "moonshade_snatcher": faster shy + double-perch feint
## - "moonshade_owl": twin-angle sightline lock tell + stoop dive

const VARIANT_WARDEN: String = "moonshade_warden"
const VARIANT_SNATCHER: String = "moonshade_snatcher"
const VARIANT_OWL: String = "moonshade_owl"
const SHADE_NOTICE_TIME: float = 0.26
const BLINK_FEINT_DIST: float = 20.0
const SNATCH_SHY_R: float = 54.0
const SNATCH_SHY_SPEED: float = 138.0
const SNATCH_DIVE_SPEED: float = 225.0
const OWL_ORBIT_R: float = 72.0
const OWL_DIVE_SPEED: float = 274.0

var variant: String = VARIANT_WARDEN
var feint_done: bool = false
var feint_side: float = 1.0
var ghost_pos: Vector2 = Vector2.ZERO
var ghost_t: float = 0.0
var perches: Array[Vector2] = []
var perch_i: int = 0
var perch_goal: Vector2 = Vector2.ZERO
var perch_wait: float = 0.0
var altitude: float = 0.0
var orbit_angle: float = 0.0
var lock_target: Vector2 = Vector2.ZERO
var twin_offset_rad: float = 0.55
var dive_dir: Vector2 = Vector2.RIGHT
var dive_hit: bool = false

func _init() -> void:
	super._init()
	kind = VARIANT_WARDEN
	variant = VARIANT_WARDEN
	max_hp = 4.0
	hp = 4.0
	body_radius = 5.5
	routine_speed = 38.0
	leash_radius = 158.0
	notice_radius = 128.0
	tell_time = 0.48
	recover_time = 1.05
	give_up_time = 1.8
	shard_drop = 5
	attack_damage = 1.0

func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var req_var: String = str(spec.get("variant", "")).strip_edges().to_lower()
	var req_kind: String = str(spec.get("kind", kind)).strip_edges().to_lower()
	if req_var == VARIANT_SNATCHER or req_kind == VARIANT_SNATCHER:
		variant = VARIANT_SNATCHER
	elif req_var == VARIANT_OWL or req_kind == VARIANT_OWL:
		variant = VARIANT_OWL
	else:
		variant = VARIANT_WARDEN
	_configure_variant_defaults()
	super.setup(spec, p_director, p_world)
	kind = variant
	if variant != VARIANT_WARDEN:
		shield_max = 0.0
		shield_hp = 0.0
	feint_done = false
	feint_side = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	ghost_pos = pos
	ghost_t = 0.0
	altitude = 0.0
	orbit_angle = _randf_range(-PI, PI)
	dive_hit = false
	_init_perches(spec)

func _init_perches(spec: Dictionary) -> void:
	perches.clear()
	var raw_p: Variant = spec.get("perches", [])
	if raw_p is Array:
		for pt_v: Variant in (raw_p as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				perches.append(pt)
	if perches.is_empty():
		var r: float = minf(56.0, leash_radius * 0.5)
		perches = [home + Vector2(-r, -r * 0.4), home + Vector2(r, -r * 0.4), home + Vector2(0.0, r * 0.5)]
	perch_i = 0
	perch_goal = perches[0]
	perch_wait = 1.2

func _configure_variant_defaults() -> void:
	var cfg: Dictionary = {
		VARIANT_SNATCHER: [4.5, 48.0, 0.0, 0.50, 0.90],
		VARIANT_OWL: [6.5, 74.0, 0.0, 0.62, 1.15],
		VARIANT_WARDEN: [5.5, 38.0, 1.75, 0.48, 1.05],
	}
	var vals: Array = cfg.get(variant, cfg[VARIANT_WARDEN]) as Array
	body_radius = float(vals[0])
	routine_speed = float(vals[1])
	shield_max = float(vals[2])
	tell_time = float(vals[3])
	recover_time = float(vals[4])

func is_flying() -> bool:
	return variant != VARIANT_WARDEN and state != State.ROUTINE and state != State.RECOVER and state != State.STAGGER

func is_targetable() -> bool:
	if not is_alive():
		return false
	if variant == VARIANT_OWL:
		return state == State.ROUTINE or state == State.COMMIT or state == State.RECOVER or state == State.STAGGER
	return true

func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["variant"] = variant
	return d

func take_hit(hit: LxHit) -> int:
	if variant == VARIANT_OWL and not is_targetable():
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED
	return super.take_hit(hit)

func _step_brain(dt: float) -> void:
	ghost_t = maxf(0.0, ghost_t - dt)
	if variant == VARIANT_WARDEN:
		super._step_brain(dt)
	elif variant == VARIANT_SNATCHER:
		_step_snatcher_shade(dt)
	else:
		_step_owl_shade(dt)

func _step_tell(dt: float, target_pos: Vector2) -> void:
	if variant == VARIANT_WARDEN and not is_counter_attack and not feint_done \
			and state_timer <= last_tell_duration * 0.68:
		feint_done = true
		_do_lateral_feint(target_pos, BLINK_FEINT_DIST)
	super._step_tell(dt, target_pos)

func _begin_swing_tell(is_lunge: bool) -> void:
	feint_done = false
	feint_side = -feint_side
	super._begin_swing_tell(is_lunge)

func _enter_notice() -> void:
	if variant == VARIANT_WARDEN:
		super._enter_notice()
		return
	state = State.NOTICE
	state_timer = SHADE_NOTICE_TIME
	alert_t = 0.7
	lost_t = 0.0
	_emit_sfx("shadow_whisper")

func _step_snatcher_shade(dt: float) -> void:
	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			perch_wait -= dt
			if pos.distance_to(perch_goal) > 2.5:
				_move_step((perch_goal - pos).limit_length(routine_speed * 0.85 * dt), true)
			elif perch_wait <= 0.0:
				perch_i = (perch_i + 1) % perches.size()
				perch_goal = perches[perch_i]
				perch_wait = 1.4
			if (_has_player() or _is_lantern_out()) and pos.distance_to(target) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_n: Vector2 = target - pos
			if to_n.length() > 0.01:
				facing = to_n.angle()
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
				lost_t = 0.0
		State.POSITION, State.WAIT_TOKEN:
			if _tick_shade_give_up(dt):
				return
			var wp: Vector2 = _get_wick_pos()
			if _has_player() and pos.distance_to(wp) < SNATCH_SHY_R:
				var dest_p: Vector2 = _pick_far_perch(wp)
				var closing: bool = (dest_p - pos).normalized().dot((wp - pos).normalized()) > 0.05
				_move_step((dest_p - pos).limit_length((routine_speed * 0.85 if closing else SNATCH_SHY_SPEED) * dt), true)
			else:
				_move_step((perch_goal - pos).limit_length(routine_speed * 0.80 * dt), true)
			var to_t: Vector2 = target - pos
			if to_t.length() > 0.01:
				facing = to_t.angle()
			var can_act: bool = director == null or director.can_claim_ranged_token(self)
			state = State.POSITION if can_act else State.WAIT_TOKEN
			if can_act and cooldown <= 0.0 and _is_on_screen() and to_t.length() <= notice_radius and _claim_token():
				_enter_shade_tell(target, "moonshade_feint")
		State.TELL:
			if not feint_done and state_timer <= last_tell_duration * 0.55:
				feint_done = true
				_do_lateral_feint(lock_target, 18.0)
			_tick_shade_tell_common(dt, 0.28)
		State.COMMIT:
			_tick_shade_commit(dt, SNATCH_DIVE_SPEED, 0.0)
		State.RECOVER:
			_tick_shade_recover(dt, 0.85)
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			_step_shade_return(dt)

func _step_owl_shade(dt: float) -> void:
	var target: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			altitude = move_toward(altitude, 0.0, 48.0 * dt)
			if (_has_player() or _is_lantern_out()) and pos.distance_to(target) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			altitude = move_toward(altitude, 4.0, 48.0 * dt)
			var to_n: Vector2 = target - pos
			if to_n.length() > 0.01:
				facing = to_n.angle()
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
				lost_t = 0.0
				cooldown = 0.65
		State.POSITION, State.WAIT_TOKEN:
			altitude = move_toward(altitude, 18.0, 48.0 * dt)
			if _tick_shade_give_up(dt):
				return
			orbit_angle = wrapf(orbit_angle + 0.9 * dt, -PI, PI)
			var desired: Vector2 = home + Vector2(cos(orbit_angle) * OWL_ORBIT_R, sin(orbit_angle) * OWL_ORBIT_R * 0.72)
			_move_step((desired - pos).limit_length(routine_speed * 0.88 * dt), true)
			var to_t: Vector2 = target - pos
			if to_t.length() > 0.01:
				facing = to_t.angle()
			var can_act: bool = director == null or director.can_claim_ranged_token(self)
			state = State.POSITION if can_act else State.WAIT_TOKEN
			if can_act and cooldown <= 0.0 and altitude >= 14.0 and _is_on_screen() and to_t.length() <= 156.0 and _claim_token():
				_enter_shade_tell(target, "moonshade_twin_lock")
		State.TELL:
			altitude = 18.0
			if state_timer > 0.20 * _assist_tell_scale():
				lock_target = target
			_tick_shade_tell_common(dt, 0.36)
		State.COMMIT:
			altitude = 6.0
			_tick_shade_commit(dt, OWL_DIVE_SPEED, 0.0)
		State.RECOVER:
			altitude = 0.0
			_tick_shade_recover(dt, 0.90)
		State.STAGGER:
			altitude = 0.0
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			altitude = move_toward(altitude, 0.0, 48.0 * dt)
			_step_shade_return(dt)

func _enter_shade_tell(target: Vector2, sfx: String) -> void:
	state = State.TELL
	is_counter_attack = false
	feint_done = false
	feint_side = -feint_side
	last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
	state_timer = last_tell_duration
	lock_target = target
	_emit_attack_started()
	_emit_sfx(sfx)

func _tick_shade_tell_common(dt: float, commit_dur: float) -> void:
	var to_l: Vector2 = lock_target - pos
	if to_l.length() > 0.01:
		facing = to_l.angle()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = commit_dur
		dive_dir = to_l.normalized() if to_l.length() > 0.01 else Vector2.from_angle(facing)
		dive_hit = false
		_emit_sfx("owl_dive")

func _tick_shade_commit(dt: float, spd: float, end_alt: float) -> void:
	_move_step(dive_dir * spd * dt, true)
	if not dive_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= 13.0:
		dive_hit = true
		_emit_player_hit(dive_dir)
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= 15.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())
	state_timer -= dt
	if state_timer <= 0.0:
		altitude = end_alt
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer

func _tick_shade_recover(dt: float, next_cd: float) -> void:
	state_timer -= dt
	if state_timer <= 0.0:
		_release_token()
		cooldown = next_cd
		state = State.RETURN if _shade_lost_target() else State.POSITION

func _tick_shade_give_up(dt: float) -> bool:
	if _shade_lost_target():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return true
	else:
		lost_t = 0.0
	return false

func _do_lateral_feint(target_pos: Vector2, dist_px: float) -> void:
	ghost_pos = pos
	ghost_t = 0.28
	var to_t: Vector2 = target_pos - pos
	var perp: Vector2 = (to_t.normalized() if to_t.length() > 0.01 else Vector2.from_angle(facing)).rotated(PI * 0.5 * feint_side)
	_move_step(perp * dist_px, is_flying())
	if target_pos.distance_to(pos) > 0.01:
		facing = (target_pos - pos).angle()
	LxDamageFx.boss_impact(ghost_pos, 0.0, 32.0, 42.0, 36.0, 1.20, 0.20)
	_emit_sfx("moonshade_blink")

func _step_shade_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)

func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0

func _shade_lost_target() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0

func _pick_far_perch(from_p: Vector2) -> Vector2:
	var best: Vector2 = perches[0]
	var best_d: float = -1.0
	for p: Vector2 in perches:
		var d: float = p.distance_to(from_p)
		if d > best_d:
			best_d = d
			best = p
	return best

func _visual_offset() -> Vector2:
	return Vector2(0.0, -altitude)

func _body_color() -> Color:
	return (PAL["blue"] as Color) if variant == VARIANT_SNATCHER else ((PAL["sky"] as Color) if variant == VARIANT_OWL else (PAL["deep"] as Color))

func _shield_color() -> Color:
	return PAL["ice"] as Color

func _draw_lunar_glint(pt: Vector2, arm: float) -> void:
	var p: Vector2 = pt.round()
	var inner: float = maxf(1.0, arm * 0.55)
	draw_line(p + Vector2(-arm, 0.0), p + Vector2(arm, 0.0), PAL["sky"] as Color, 1.2)
	draw_line(p + Vector2(0.0, -arm), p + Vector2(0.0, arm), PAL["sky"] as Color, 1.2)
	draw_line(p + Vector2(-inner, 0.0), p + Vector2(inner, 0.0), PAL["ice"] as Color, 1.0)
	draw_line(p + Vector2(0.0, -inner), p + Vector2(0.0, inner), PAL["ice"] as Color, 1.0)
	draw_rect(Rect2(p, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)

func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if ghost_t > 0.0:
		var gt: float = clampf(ghost_t / 0.28, 0.0, 1.0)
		var gp: Vector2 = (ghost_pos - pos + off).round()
		var bv: Vector2 = c - gp
		var ba: float = bv.angle() if bv.length_squared() > 0.01 else facing
		draw_line(gp, c, (PAL["blue"] if gt > 0.45 else PAL["deep"]) as Color, 1.4)
		draw_arc(gp, body_radius + 1.2, ba - 1.35, ba + 1.35, 10, PAL["deep"] as Color, 2.0)
		if gt > 0.30:
			draw_arc(gp, body_radius, ba - 1.15, ba + 1.15, 10, PAL["blue"] as Color, 1.4)
		if gt > 0.50:
			draw_arc(gp.lerp(c, 0.30).round(), body_radius * 0.85, ba - 0.95, ba + 0.95, 8, PAL["sky"] as Color, 1.2)
		if gt > 0.65:
			draw_arc(gp.lerp(c, 0.62).round(), body_radius * 0.65, ba - 0.70, ba + 0.70, 6, PAL["ice"] as Color, 1.0)
			draw_rect(Rect2(gp.lerp(c, 0.45).round(), Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
		_draw_lunar_glint(gp, 3.0 if gt > 0.45 else 2.0)
	if variant == VARIANT_OWL and state == State.TELL:
		var tgt_pt: Vector2 = (lock_target - pos).round()
		var delta: Vector2 = tgt_pt - c
		var lock_cut: float = 0.20 * _assist_tell_scale()
		var locked_o: bool = state_timer <= lock_cut
		var lock_frac: float = clampf((state_timer - lock_cut) / maxf(last_tell_duration - lock_cut, 0.05), 0.0, 1.0)
		var spread: float = twin_offset_rad * lock_frac
		var len_t: float = delta.length()
		var base_a: float = delta.angle() if len_t > 0.01 else facing
		var tip_a: Vector2 = (c + Vector2.from_angle(base_a + spread * feint_side) * len_t).round()
		var tip_b: Vector2 = (c + Vector2.from_angle(base_a - spread * feint_side) * len_t).round()
		draw_line(c, tip_a, (PAL["coral"] if locked_o else PAL["sky"]) as Color, 1.2 if locked_o else 1.0)
		draw_line(c, tip_b, (PAL["cream"] if locked_o else PAL["ice"]) as Color, 1.6 if locked_o else 1.4)
		_draw_lunar_glint(tip_a, 3.0 if not locked_o else 4.5)
		_draw_lunar_glint(tip_b, 5.0 if locked_o else 4.0)
	elif variant == VARIANT_SNATCHER and state == State.TELL:
		var tgt: Vector2 = (lock_target - pos).round()
		draw_line(c, tgt, PAL["blue"] as Color, 1.8)
		draw_line(c, tgt, PAL["ice"] as Color, 1.0)
		_draw_lunar_glint(tgt, 4.0)
	elif variant == VARIANT_WARDEN and state == State.TELL:
		var fwd_w: Vector2 = Vector2.from_angle(facing)
		var urg_w: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		if lunge_attack:
			var lane_len: float = minf(lunge_reach, GAP_LUNGE_SPEED * LUNGE_SWING_TIME + swing_r * 0.50)
			LxBossTelegraphFx.draw_ground_danger_lane(self, c, c + fwd_w * lane_len, swing_r * 0.52, urg_w, anim_t, "sky" if feint_done else "coral", "ice" if feint_done else "gold")
		else:
			var fill_k: String = "sky" if (feint_done or is_counter_attack) else "coral"
			var rim_k: String = "ice" if (feint_done or is_counter_attack) else "gold"
			LxBossTelegraphFx.draw_ground_danger_sector(self, c, facing - swing_arc, facing + swing_arc, swing_r + (6.0 if is_counter_attack else 8.0), urg_w, anim_t, fill_k, rim_k)
			if feint_done:
				var post_len: float = SWING_LUNGE_SPEED * SWING_TIME + swing_r * 0.45
				LxBossTelegraphFx.draw_ground_danger_lane(self, c, c + fwd_w * post_len, swing_r * 0.40, urg_w, anim_t, "sky", "coral")
		_draw_lunar_glint(c + fwd_w * (body_radius + 7.0), 3.5)
