class_name LxStarJellyBrain
extends LxEnemyBrain
## Star Jelly (Island 5, Starfall Observatory).
## Drifts lazily over void/constellation decks; pulses a 28px shock-ring + curving spores.
## Killed by straight bolts -> splits into 2 fast 0.75 HP Dwarf Jellies!
## Beam, Heavy Throw, Recall, Sunflare, or Curved Bolt (>= 25 deg) vaporizes cleanly with ZERO split!

const NOTICE_TIME: float = 0.26
const COMMIT_TIME: float = 0.35
const SHOCK_RADIUS: float = 28.0
const DWARF_SHOCK_RADIUS: float = 20.0
const SPORE_SPEED: float = 112.0
const SPORE_MAX_AGE: float = 1.05
const STAGGER_TIME: float = 0.55

var is_dwarf: bool = false
var _drift_t: float = 0.0
var _pulse_hit: bool = false
var _spores_fired: bool = false
var _spores: Array[Dictionary] = []
var _did_split: bool = false


func _init() -> void:
	kind = "star_jelly"
	max_hp = 2.2
	hp = 2.2
	body_radius = 6.5
	routine_speed = 34.0
	leash_radius = 152.0
	notice_radius = 110.0
	tell_time = 0.55
	recover_time = 1.00
	give_up_time = 2.0
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	is_dwarf = bool(spec.get("dwarf", false))
	super.setup(spec, p_director, p_world)
	if is_dwarf:
		max_hp = float(spec.get("max_hp", 0.75))
		hp = max_hp
		body_radius = 4.2
		routine_speed = 44.0
		shard_drop = 1
		_sprite_scale = Vector2(0.68, 0.68)
		_sprite_tint = PAL["rose"] as Color
	_drift_t = _randf_range(-PI, PI)
	_pulse_hit = false
	_spores_fired = false
	_spores.clear()
	_did_split = false


func is_flying() -> bool:
	return true


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var clean_vaporize: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_PRISM] \
			or bool(h["pierce"]) or curve_deg >= 25.0
	if clean_vaporize:
		dmg *= 1.15

	var is_open: bool = clean_vaporize or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (100.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = is_open
		_spores.clear()
		if not is_dwarf and not clean_vaporize and not _did_split:
			_spawn_dwarf_split()
		_die(hit)
		return HitResult.KILLED

	if is_heavy or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		_release_token()
		state = State.STAGGER
		state_timer = 1.35 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _spawn_dwarf_split() -> void:
	_did_split = true
	_emit_sfx("star_jelly_split")
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("spawn_enemy"):
		return
	for sgn: float in [-1.0, 1.0]:
		var off: Vector2 = Vector2(sgn * 13.0, -sgn * 6.0)
		var sp_pos: Vector2 = _collide_move(pos, pos + off, true)
		world_ctx.call("spawn_enemy", {
			"kind": "star_jelly", "dwarf": true,
			"pos": sp_pos, "home": home,
			"leash_radius": leash_radius,
			"max_hp": 0.75, "shard_drop": 1,
		})


func _step_brain(dt: float) -> void:
	_tick_spores(dt)
	match state:
		State.ROUTINE:
			_step_nebula_drift(dt, 0.72)
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
				state_timer = COMMIT_TIME
				_pulse_hit = false
				_spores_fired = false
				_emit_sfx("star_jelly_pulse")
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
				state = State.POSITION
				cooldown = 0.55
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
		var sway: Vector2 = dir_t.rotated(PI * 0.5) * sin(anim_t * 2.4) * 0.45
		var desire: Vector2 = (dir_t * (0.75 if dist > 30.0 else -0.25) + sway).normalized()
		_move_step(desire * (routine_speed * 0.86) * dt, true)
		_turn_toward(to_t.angle(), 4.0, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= (78.0 if not is_dwarf else 58.0) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("star_jelly_swell")


func _step_commit(dt: float) -> void:
	var shock_r: float = DWARF_SHOCK_RADIUS if is_dwarf else SHOCK_RADIUS
	if not _spores_fired:
		_spores_fired = true
		var n: int = 2 if is_dwarf else 4
		var base_a: float = facing + PI * 0.25
		for i: int in range(n):
			var d: Vector2 = Vector2.from_angle(base_a + float(i) * (TAU / float(n)))
			_spores.append({
				"pos": pos + d * (body_radius + 2.0),
				"prev": pos + d * (body_radius + 2.0),
				"vel": d * SPORE_SPEED,
				"age": 0.0,
			})
	if not _pulse_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= shock_r:
		_pulse_hit = true
		var push: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.DOWN
		_emit_player_hit(push)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _tick_spores(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(_spores.size() - 1, -1, -1):
		var sp: Dictionary = _spores[i]
		sp["age"] = float(sp["age"]) + dt
		var p0: Vector2 = sp["pos"] as Vector2
		var v: Vector2 = sp["vel"] as Vector2
		sp["prev"] = p0
		var fa: Vector2 = LxFields.accel_at(p0, "bolt")
		if fa.length_squared() > 0.01:
			v += fa * dt
			if v.length_squared() > 1.0:
				v = v.normalized() * SPORE_SPEED
		var p1: Vector2 = p0 + v * dt
		sp["pos"] = p1; sp["vel"] = v
		if float(sp["age"]) >= SPORE_MAX_AGE or not _has_clear_view(p0, p1):
			_spores.remove_at(i)
			continue
		if has_p and Geometry2D.get_closest_point_to_segment(wp, p0, p1).distance_to(wp) <= 6.5:
			_emit_player_hit(v.normalized())
			_spores.remove_at(i)


func _step_nebula_drift(dt: float, speed_ratio: float) -> void:
	_drift_t = wrapf(_drift_t + dt * 0.95, -PI, PI)
	var tgt: Vector2 = home + Vector2(cos(_drift_t) * 26.0, sin(_drift_t * 2.0) * 16.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * speed_ratio * dt), true)
		facing = d.angle()


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home; state = State.ROUTINE; lost_t = 0.0; return
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
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("star_jelly_swell")


func _visual_offset() -> Vector2:
	return Vector2(0.0, sin(anim_t * 3.2) * 2.5 - 4.0)


func _body_color() -> Color:
	return PAL["rose"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var shock_r: float = DWARF_SHOCK_RADIUS if is_dwarf else SHOCK_RADIUS
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, Vector2.ZERO, shock_r, prog, anim_t, "rose", "gold")
	elif state == State.COMMIT:
		var prog: float = 1.0 - clampf(state_timer / COMMIT_TIME, 0.0, 1.0)
		var r: float = lerpf(8.0, shock_r, prog)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, PAL["sky"] as Color, 2.2)
		draw_arc(Vector2.ZERO, maxf(4.0, r - 2.0), 0.0, TAU, 20, PAL["cream"] as Color, 1.0)
	for sp: Dictionary in _spores:
		var lp: Vector2 = ((sp["pos"] as Vector2) - pos + c).round()
		draw_circle(lp, 2.5, PAL["plum"] as Color)
		draw_circle(lp, 1.5, PAL["gold"] as Color)
		draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
