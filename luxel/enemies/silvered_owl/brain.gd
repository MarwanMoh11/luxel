class_name LxSilveredOwlBrain
extends LxEnemyBrain
## Island 7 Enemy: Silvered Owl (Chrome Stealth Sniper, HP 4.0, Shards 6).
## Orbits chasms cloaked in chrome stealth EXCEPT for its dark floor shadow, then converges
## twin silver sights (tell 0.62s, locks final 0.20s), stoop dives (265 px/s), perched recover (1.25s).
## Counters: Lens instant-decloaks (1.4s stagger); track floor shadow when Lens is stolen; Throw lures dive!

const NOTICE_TIME: float = 0.28
const LOCK_TELL: float = 0.62
const LOCK_AIM_CUTOFF: float = 0.20
const DIVE_COMMIT: float = 0.26
const DIVE_SPEED: float = 265.0
const DIVE_HIT_R: float = 20.0
const PERCH_RECOVER: float = 1.25
const DECLOAK_STAGGER: float = 1.40
const DECLOAK_GRACE: float = 3.20

var decloaked: bool = false
var decloak_t: float = 0.0
var _orbit_a: float = 0.0
var _lock_target: Vector2 = Vector2.ZERO
var _dive_dir: Vector2 = Vector2.RIGHT
var _dive_hit: bool = false


func _init() -> void:
	kind = "silvered_owl"
	island_id = 7
	max_hp = 4.0
	hp = 4.0
	body_radius = 6.5
	routine_speed = 68.0
	leash_radius = 176.0
	notice_radius = 148.0
	tell_time = LOCK_TELL
	recover_time = PERCH_RECOVER
	give_up_time = 2.2
	shard_drop = 6
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	decloaked = bool(spec.get("start_revealed", false))
	decloak_t = DECLOAK_GRACE if decloaked else 0.0
	_orbit_a = _randf_range(-PI, PI)
	_lock_target = home
	_dive_dir = Vector2.from_angle(facing)
	_dive_hit = false


func is_flying() -> bool:
	return state != State.RECOVER and state != State.STAGGER


func is_targetable() -> bool:
	if not is_alive():
		return false
	return decloaked or state in [State.COMMIT, State.RECOVER, State.STAGGER]


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	if state == State.DEAD:
		return
	if source == "lantern_hand" or source == "lantern_recall":
		return
	var in_light: bool = true
	if a is Vector2 and (b is float or b is int):
		in_light = pos.distance_to(a as Vector2) <= float(b) + body_radius
	elif (a is float or a is int) and b is Vector2:
		in_light = pos.distance_to(b as Vector2) <= float(a) + body_radius
	if in_light:
		_trigger_decloak(source == "lens")


func _trigger_decloak(with_stagger: bool) -> void:
	var was_cloaked: bool = not decloaked
	decloaked = true
	decloak_t = maxf(decloak_t, DECLOAK_GRACE)
	if was_cloaked:
		LxDamageFx.boss_impact(pos, 0.06, 44.0, 52.0, 44.0, 1.24, 0.24)
		_emit_sfx("lens_reveal")
		if with_stagger and state != State.STAGGER:
			_release_token()
			state = State.STAGGER
			state_timer = DECLOAK_STAGGER


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var force_reveal: bool = src in [LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_BEAM]
	if not is_targetable() and not force_reveal:
		_emit_sfx("moon_blink")
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	if force_reveal and not decloaked:
		_trigger_decloak(true)

	var is_heavy: bool = bool(h["stagger"]) or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_open: bool = state in [State.RECOVER, State.STAGGER] or decloaked
	if state == State.RECOVER:
		dmg *= 1.25
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (110.0 if is_heavy else 26.0)

	if hp <= 0.001:
		opened_kill = is_open
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else 0.65
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	decloak_t = maxf(0.0, decloak_t - dt)
	_check_lens_decloak()

	match state:
		State.ROUTINE:
			_step_orbit(dt, 0.78)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			_step_tell(dt)
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.90
				_emit_sfx("feather_flutter")
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)

	if state in [State.COMMIT, State.RECOVER, State.STAGGER]:
		decloak_t = maxf(decloak_t, 0.18)
	decloaked = decloak_t > 0.0


func _check_lens_decloak() -> void:
	if Lx.state == null or not Lx.state.has_move("lens"):
		return
	var ldata: Dictionary = Lx.get_move_data("lens")
	var pulse_r: float = float(ldata.get("pulse_radius", 104.0))
	var hung_r: float = float(ldata.get("hung_radius", 78.0))
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= hung_r + body_radius:
		_trigger_decloak(false)
		return
	if _has_player() and Lx.player != null and is_instance_valid(Lx.player):
		var ml: Variant = Lx.player.get("move_lens")
		if ml is Object and (ml as Object).has_method("is_pulse_active") and bool((ml as Object).call("is_pulse_active")):
			if pos.distance_to(_get_wick_pos()) <= pulse_r + body_radius:
				_trigger_decloak(true)


func _step_orbit(dt: float, ratio: float) -> void:
	_orbit_a = wrapf(_orbit_a + dt * 1.15, -PI, PI)
	var tgt: Vector2 = home + Vector2(cos(_orbit_a) * 44.0, sin(_orbit_a) * 26.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * ratio * dt), true)
		_turn_toward(d.angle(), 4.2, dt)


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	var dist: float = to_t.length()
	if dist > 1.0:
		_turn_toward(to_t.angle(), 4.0, dt)
		var dir_t: Vector2 = to_t / dist
		var perp := Vector2(-dir_t.y, dir_t.x)
		var radial: float = clampf((dist - 92.0) / 48.0, -0.5, 0.5)
		var desire: Vector2 = (perp * 0.85 + dir_t * radial).normalized()
		_move_step(desire * (routine_speed * 0.85) * dt, true)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius and _claim_token():
		_lock_target = tgt
		_dive_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _dive_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(LOCK_TELL, false, attack_damage)
		state_timer = last_tell_duration
		_dive_hit = false
		_emit_attack_started()
		_emit_sfx("owl_lock")


func _step_tell(dt: float) -> void:
	# Tracks target until final 0.20s lock cutoff
	if state_timer > LOCK_AIM_CUTOFF * _assist_tell_scale() and _has_attention_target():
		_lock_target = _attention_target()
		var to_l: Vector2 = _lock_target - pos
		if to_l.length() > 0.1:
			_dive_dir = to_l.normalized()
			facing = _dive_dir.angle()
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = DIVE_COMMIT
		_dive_hit = false
		_emit_sfx("owl_dive")


func _step_commit(dt: float) -> void:
	_move_step(_dive_dir * DIVE_SPEED * dt, true)
	if not _dive_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= DIVE_HIT_R:
		_dive_hit = true
		_emit_player_hit(_dive_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, PERCH_RECOVER)
		last_recover_duration = state_timer
		_emit_sfx("feather_flutter")


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 4.2, dt)
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 26.0


func _has_attention_target() -> bool:
	return _has_player() or _is_lured()


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.72
	lost_t = 0.0
	_emit_sfx("owl_lock")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 46.0, 52.0, 46.0, 1.24, 0.24)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["ice"] if si % 2 == 0 else PAL["coral"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 34.0, 82.0, 0.28)


func _visual_offset() -> Vector2:
	if state == State.RECOVER or state == State.STAGGER:
		return Vector2.ZERO
	return Vector2(0.0, -10.0 + sin(anim_t * 3.8) * 2.0)


func _body_color() -> Color:
	return PAL["ice"] as Color


func _draw() -> void:
	if state == State.DEAD:
		return
	if decloaked:
		super._draw()
		return
	# Chrome stealth: crisp dark floor shadow + faint silver glints + twin targeting sights!
	var sh_pts := PackedVector2Array()
	for si: int in range(12):
		var sa: float = (TAU * float(si)) / 12.0
		sh_pts.append(Vector2(roundf(cos(sa) * 9.5), roundf(2.0 + sin(sa) * 3.4)))
	draw_colored_polygon(sh_pts, Color(PAL["void"] as Color, 0.62))
	var off: Vector2 = _visual_offset().round()
	# Faint chrome shimmer arcs in air
	draw_arc(off, body_radius, anim_t * 2.0, anim_t * 2.0 + 0.9, 6, Color(PAL["ice"] as Color, 0.45), 1.0)
	draw_arc(off, body_radius, anim_t * 2.0 + PI, anim_t * 2.0 + PI + 0.9, 6, Color(PAL["sky"] as Color, 0.40), 1.0)
	_draw_sights(off)


func _draw_extra(off: Vector2) -> void:
	_draw_sights(off)


func _draw_sights(off: Vector2) -> void:
	if state == State.TELL:
		var lt: Vector2 = (_lock_target - pos).round()
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked: bool = state_timer <= LOCK_AIM_CUTOFF * _assist_tell_scale()
		var col: Color = (PAL["coral"] if locked else PAL["ice"]) as Color
		# Twin converging chrome sniper sights!
		var spread: float = lerpf(16.0, 0.0, prog)
		var perp := Vector2(-_dive_dir.y, _dive_dir.x)
		draw_line(off.round(), (lt + perp * spread).round(), col, 1.2)
		draw_line(off.round(), (lt - perp * spread).round(), col, 1.2)
		LxBossTelegraphFx.draw_ground_danger_ring(self, lt, DIVE_HIT_R, prog, anim_t, "coral" if locked else "sky", "cream")
	elif state == State.COMMIT:
		draw_line((off - _dive_dir * 14.0).round(), (off + _dive_dir * 10.0).round(), PAL["ice"] as Color, 2.2)
		draw_line((off - _dive_dir * 10.0).round(), (off + _dive_dir * 12.0).round(), PAL["cream"] as Color, 1.0)
