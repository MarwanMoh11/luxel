class_name LxSlagSlimeBrain
extends LxEnemyBrain
## Slag Slime (Island 6, Ashen Kiln — Living Puzzle-Toy / Tank).
## Molten lava-ooze resisting weak yellow chip (0.35x); hit by ANY Blue light (Prism bounce,
## Blue Transformer, Blue Beam, or blue on_light) to freeze for 8.0s into a solid, pushable
## basalt block that depresses pressure plates and blocks beams/boss pendulums!
## Lance / Sunflare / heavy hits shatter frozen slime in 1 blow (+15 Ember!).

const SPLASH_TRIGGER_R: float = 48.0
const SPLASH_HIT_R: float = 36.0
const SPLASH_COMMIT_TIME: float = 0.28
const FREEZE_DURATION: float = 8.0
const MOLTEN_CHIP_MULT: float = 0.35
const FROZEN_SHATTER_MULT: float = 3.0
const BLOCK_SIZE := Vector2(16.0, 16.0)

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var frozen: bool = false
var frozen_t: float = 0.0
var splash_hit: bool = false
var _ext_vel: Vector2 = Vector2.ZERO


func _init() -> void:
	kind = "slag_slime"
	island_id = 6
	max_hp = 3.5
	hp = 3.5
	body_radius = 7.0
	routine_speed = 22.0
	leash_radius = 136.0
	notice_radius = 108.0
	tell_time = 0.58
	recover_time = 1.30
	give_up_time = 1.6
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pt_v: Variant in (raw_r as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				route.append(pt)
	route_i = 0
	pause_t = 0.0
	frozen = false
	frozen_t = 0.0
	splash_hit = false
	_ext_vel = Vector2.ZERO


# ---- Pushable Frozen Basalt Block API (interacts with Wick, tilt_group, plates, Colossus Heart) ----

func is_frozen_block() -> bool: return frozen and is_alive()
func is_solid() -> bool: return frozen and is_alive()
func is_movable() -> bool: return frozen and is_alive()
func is_weight_body() -> bool: return frozen and is_alive()
func get_solid_rect() -> Rect2: return Rect2(pos - BLOCK_SIZE * 0.5, BLOCK_SIZE) if (frozen and is_alive()) else Rect2()


func move_to(new_pos: Vector2) -> void:
	pos = _collide_move(pos, new_pos, false)
	_clamp_to_leash()
	queue_redraw()


func push_block_external(v: Vector2) -> void:
	if frozen and is_alive() and v.is_finite():
		_ext_vel += v


func freeze_into_block(dur: float = FREEZE_DURATION) -> void:
	if not is_alive():
		return
	frozen = true
	frozen_t = maxf(frozen_t, dur)
	_release_token()
	state = State.STAGGER
	state_timer = frozen_t
	_emit_sfx("magma_crack")
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 3.0, 18.0, 0.24, PAL["ice"] as Color, 1.4)
	queue_redraw()


func reheat() -> void:
	if not frozen or not is_alive():
		return
	frozen = false
	frozen_t = 0.0
	state = State.POSITION
	state_timer = 0.0
	_emit_sfx("furnace_draw")
	queue_redraw()


func on_light(_a: Variant, _b: Variant = null, src_tag: String = "") -> void:
	var tag: String = src_tag if not src_tag.is_empty() else (str(_b) if _b is String else "")
	if tag.to_lower().contains("blue") and is_alive() and not frozen:
		freeze_into_block(FREEZE_DURATION)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_blue: bool = hit.is_blue()
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos

	# Blue light freezes molten slime into a solid basalt push-block!
	if is_blue and not frozen:
		freeze_into_block(FREEZE_DURATION)
		hp = maxf(0.1, hp - dmg * 0.5)
		flash_t = 0.16
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	var is_opening: bool = frozen or state == State.RECOVER or state == State.STAGGER
	if frozen:
		# Frozen basalt block: shatters in 1 Lance/Sunflare/Heavy blow (+15 Ember!)
		if cracks or is_heavy or dmg >= 1.25:
			dmg *= FROZEN_SHATTER_MULT
		else:
			dmg *= 2.2
	else:
		# Molten ooze resists weak yellow bolts
		if not is_heavy and not cracks and not bool(h["pierce"]):
			dmg *= MOLTEN_CHIP_MULT
			clank_t = 0.12
			_emit_sfx("shield_clang")

	hp -= dmg
	flash_t = 0.14 if (frozen or is_heavy or cracks) else 0.08
	if rel.length() > 0.01:
		var k_spd: float = 40.0 if frozen else (95.0 if is_heavy else 24.0)
		knock = -rel.normalized() * k_spd

	if hp <= 0.001:
		var was_frozen: bool = frozen
		frozen = false
		frozen_t = 0.0
		opened_kill = is_opening
		if was_frozen:
			_grant_shatter_ember()
			_emit_sfx("shield_shatter")
		_die(hit)
		return HitResult.KILLED

	if is_heavy and not frozen:
		_release_token()
		state = State.STAGGER
		state_timer = 1.4 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else 0.50
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _grant_shatter_ember() -> void:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			var emax: float = w.move_sunflare.get_ember_max()
			w.ember = minf(emax, w.ember + 15.0)


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["frozen"] = frozen
	d["frozen_t"] = frozen_t
	return d


func _step_brain(dt: float) -> void:
	if frozen:
		_step_frozen(dt)
		return
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 3.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = SPLASH_COMMIT_TIME
				splash_hit = false
				_emit_sfx("magma_crack")
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.90
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.55
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
				if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
					_enter_notice()


func _step_frozen(dt: float) -> void:
	state = State.STAGGER
	frozen_t = maxf(0.0, frozen_t - dt)
	state_timer = frozen_t
	# Allow external conveyors / tilt_group / Wick body nudge to push frozen basalt cube!
	if LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(pos, "block")
		if fa.length_squared() > 4.0:
			_ext_vel += fa * dt
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var rel: Vector2 = pos - w.global_position
		var dist: float = rel.length()
		if not w.dead and dist > 0.1 and dist < 13.5:
			_ext_vel += (rel / dist) * 52.0
	if _ext_vel.length_squared() > 1.0:
		_move_step(_ext_vel.limit_length(95.0) * dt, false)
	_ext_vel = Vector2.ZERO
	if frozen_t <= 0.0:
		frozen = false
		state = State.RETURN if _should_give_up() else State.POSITION
		cooldown = 0.65


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.80 * dt), false)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 2.5:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.90
		return
	var to_wp: Vector2 = wp - pos
	_turn_toward(to_wp.angle(), 2.8, dt)
	_move_step(to_wp.limit_length(routine_speed * 0.82 * dt), false)


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

	var target: Vector2 = _attention_target()
	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 3.0, dt)

	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN
	if is_lead and cooldown <= 0.0 and dist <= SPLASH_TRIGGER_R and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		splash_hit = false
		_emit_attack_started()
		_emit_sfx("furnace_draw")
		return

	# Keep slow slime close to home so return-home is fast (<6s)
	var dest: Vector2 = target
	var cap: float = minf(68.0, maxf(0.0, leash_radius - 2.0))
	if dest.distance_to(home) > cap:
		dest = home + (dest - home).normalized() * cap
	if dest.distance_to(pos) > 10.0:
		_move_step((dest - pos).limit_length(routine_speed * 0.86 * dt), false)


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	var prog: float = 1.0 - clampf(state_timer / SPLASH_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(8.0, SPLASH_HIT_R, prog)
	var gliding: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).is_gliding()
	if not splash_hit and not gliding and _has_player() and pos.distance_to(_get_wick_pos()) <= ring_r:
		splash_hit = true
		var push: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.DOWN
		_emit_player_hit(push, attack_damage)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _sees_target() -> bool:
	var t: Vector2 = _attention_target()
	if not _has_player() and not _is_lantern_out():
		return false
	return pos.distance_to(t) <= notice_radius and _has_clear_view(pos, t)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.28
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("furnace_draw")


func _body_color() -> Color:
	return (PAL["mauve"] as Color) if frozen else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if frozen:
		# Ice-rimmed frozen block indicator & thaw countdown arc
		var frac: float = clampf(frozen_t / FREEZE_DURATION, 0.0, 1.0)
		draw_rect(Rect2(c - BLOCK_SIZE * 0.5, BLOCK_SIZE), Color(PAL["ice"] as Color, 0.75), false, 1.0)
		draw_arc(c, 12.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, PAL["sky"] as Color, 1.0)
		return
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var r: float = lerpf(SPLASH_HIT_R, 10.0, prog)
		draw_arc(c, SPLASH_HIT_R, 0.0, TAU, 20, PAL["void"] as Color, 3.0)
		draw_arc(c, SPLASH_HIT_R, 0.0, TAU, 20, PAL["coral"] as Color, 1.0)
		draw_arc(c, r, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(c, r, 0.0, TAU, 20, (PAL["cream"] if prog > 0.72 else PAL["gold"]) as Color, 2.0)
	elif state == State.COMMIT:
		var prog: float = 1.0 - clampf(state_timer / SPLASH_COMMIT_TIME, 0.0, 1.0)
		var rr: float = lerpf(8.0, SPLASH_HIT_R, prog)
		draw_circle(c, rr, Color(PAL["coral"] as Color, 0.26 * (1.0 - prog * 0.4)))
		draw_arc(c, rr, 0.0, TAU, 22, PAL["void"] as Color, 4.0)
		draw_arc(c, rr, 0.0, TAU, 22, PAL["gold"] as Color, 2.0)
