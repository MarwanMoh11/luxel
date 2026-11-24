class_name LxMoonJellyBrain
extends LxEnemyBrain
## Island 7 Enemy: Moon Jelly (Optical Splitter, HP 3.0 / 1.2 mini, Shards 5).
## Drifts over water/pits; raw Yellow bolts split it into 2 fast mini-jellies!
## Counters: Blue light (Prism), Beam, Sunflare, or Throw shatter it cleanly with ZERO split!

const NOTICE_TIME: float = 0.24
const RIPPLE_TELL: float = 0.50
const RIPPLE_COMMIT: float = 0.22
const RIPPLE_RECOVER: float = 1.15
const RIPPLE_RADIUS: float = 34.0
const MINI_RIPPLE_RADIUS: float = 22.0
const MOTE_SPEED: float = 108.0
const MOTE_MAX_AGE: float = 0.95
const STAGGER_TIME: float = 0.60

var is_mini: bool = false
var _drift_t: float = 0.0
var _pulse_hit: bool = false
var _motes_fired: bool = false
var _did_split: bool = false
var _motes: Array[Dictionary] = []


func _init() -> void:
	kind = "moon_jelly"
	island_id = 7
	max_hp = 3.0
	hp = 3.0
	body_radius = 6.5
	routine_speed = 36.0
	leash_radius = 152.0
	notice_radius = 120.0
	tell_time = RIPPLE_TELL
	recover_time = RIPPLE_RECOVER
	give_up_time = 2.0
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	is_mini = bool(spec.get("mini", false))
	super.setup(spec, p_director, p_world)
	if is_mini:
		max_hp = float(spec.get("max_hp", 1.2))
		hp = max_hp
		body_radius = 4.2
		routine_speed = 46.0
		shard_drop = 1
		_sprite_scale = Vector2(0.68, 0.68)
		_sprite_tint = PAL["ice"] as Color
	_drift_t = _randf_range(-PI, PI)
	_pulse_hit = false
	_motes_fired = false
	_did_split = false
	_motes.clear()


func is_flying() -> bool:
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var clean_shatter: bool = hit.is_blue() or src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_PRISM] or bool(h["pierce"])

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	if clean_shatter:
		dmg *= 1.25

	var is_open: bool = clean_shatter or state in [State.RECOVER, State.STAGGER]
	hp -= dmg
	flash_t = 0.14 if (clean_shatter or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = is_open
		_motes.clear()
		if not is_mini and not clean_shatter and not _did_split:
			_spawn_mini_split()
		else:
			_emit_sfx("glass_shatter")
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if clean_shatter or is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.35 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_sfx("prism_hit")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _spawn_mini_split() -> void:
	_did_split = true
	_emit_sfx("moon_jelly_split")
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("spawn_enemy"):
		return
	for sgn: float in [-1.0, 1.0]:
		var sp_pos: Vector2 = _collide_move(pos, pos + Vector2(sgn * 14.0, -sgn * 5.0), true)
		world_ctx.call("spawn_enemy", {
			"kind": "moon_jelly", "mini": true,
			"pos": sp_pos, "home": home,
			"leash_radius": leash_radius,
			"max_hp": 1.2, "shard_drop": 1,
		})


func _step_brain(dt: float) -> void:
	_tick_motes(dt)
	match state:
		State.ROUTINE:
			_step_drift(dt, 0.72)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = RIPPLE_COMMIT
				_pulse_hit = false
				_motes_fired = false
				_emit_sfx("prism_bounce")
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.55
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


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
		var dir_t: Vector2 = to_t / dist
		var sway: Vector2 = dir_t.rotated(PI * 0.5) * sin(anim_t * 2.5) * 0.45
		var desire: Vector2 = (dir_t * (0.75 if dist > 30.0 else -0.25) + sway).normalized()
		_move_step(desire * (routine_speed * 0.86) * dt, true)
		_turn_toward(to_t.angle(), 4.0, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= (74.0 if not is_mini else 54.0) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(RIPPLE_TELL, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("glass_chime")


func _step_commit(dt: float) -> void:
	var r: float = MINI_RIPPLE_RADIUS if is_mini else RIPPLE_RADIUS
	if not _motes_fired:
		_motes_fired = true
		var n: int = 2 if is_mini else 4
		var base_a: float = facing + PI * 0.25
		for i: int in range(n):
			var d: Vector2 = Vector2.from_angle(base_a + float(i) * (TAU / float(n)))
			_motes.append({
				"pos": pos + d * (body_radius + 2.0),
				"prev": pos + d * (body_radius + 2.0),
				"vel": d * MOTE_SPEED,
				"age": 0.0,
			})
	if not _pulse_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= r:
		_pulse_hit = true
		var push: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.DOWN
		_emit_player_hit(push)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, RIPPLE_RECOVER)
		last_recover_duration = state_timer


func _tick_motes(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		m["age"] = float(m["age"]) + dt
		var p0: Vector2 = m["pos"] as Vector2
		var v: Vector2 = m["vel"] as Vector2
		m["prev"] = p0
		var fa: Vector2 = LxFields.accel_at(p0, "bolt")
		if fa.length_squared() > 0.01:
			v += fa * dt
			if v.length_squared() > 1.0:
				v = v.normalized() * MOTE_SPEED
		var p1: Vector2 = p0 + v * dt
		m["pos"] = p1
		m["vel"] = v
		if float(m["age"]) >= MOTE_MAX_AGE or not _has_clear_view(p0, p1):
			_motes.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, p0, p1).distance_to(wp) <= 6.0:
			_emit_player_hit(v.normalized())
			_motes.remove_at(i)


func _step_drift(dt: float, speed_ratio: float) -> void:
	_drift_t = wrapf(_drift_t + dt * 1.0, -PI, PI)
	var tgt: Vector2 = home + Vector2(cos(_drift_t) * 26.0, sin(_drift_t * 2.0) * 16.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * speed_ratio * dt), true)
		facing = d.angle()


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), true)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


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
	alert_t = 0.68
	lost_t = 0.0
	_emit_sfx("glass_chime")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.06, 38.0, 44.0, 40.0, 1.22, 0.22)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["ice"] if si % 2 == 0 else PAL["sky"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 28.0, 72.0, 0.26)


func _visual_offset() -> Vector2:
	return Vector2(0.0, sin(anim_t * 3.2) * 2.5 - 4.0)


func _body_color() -> Color:
	return PAL["ice"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var r: float = MINI_RIPPLE_RADIUS if is_mini else RIPPLE_RADIUS
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, Vector2.ZERO, r, prog, anim_t, "sky", "ice")
	elif state == State.COMMIT:
		var prog: float = 1.0 - clampf(state_timer / RIPPLE_COMMIT, 0.0, 1.0)
		var rr: float = lerpf(8.0, r, prog)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 24, PAL["ice"] as Color, 2.2)
		draw_arc(Vector2.ZERO, maxf(4.0, rr - 2.0), 0.0, TAU, 20, PAL["cream"] as Color, 1.0)
	for m: Dictionary in _motes:
		var lp: Vector2 = ((m["pos"] as Vector2) - pos + c).round()
		draw_circle(lp, 2.4, PAL["blue"] as Color)
		draw_circle(lp, 1.4, PAL["ice"] as Color)
		draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
