class_name LxMoveDash
extends LxMove
## Flare Dash: directional dash with i-frames, shield-wear + stagger strike, gap crossing up to 32 px,
## perfect dodge cooldown refund, and Wings (LxMoveWings) glide continuation when lx_dash stays held.

const DASH_BOUNCE_TIME: float = 0.24
const DASH_BOUNCE_KNOCK: float = 150.0

var active: bool = false
var is_gliding: bool = false
var dash_held: bool = false

var dash_dir: Vector2 = Vector2.RIGHT
var dash_speed: float = 340.0
var dash_time_left: float = 0.0
var dash_elapsed: float = 0.0
var dash_dist_traveled: float = 0.0
var gap_max_px: float = 32.0
var iframes_left: float = 0.0
var perfect_window: float = 0.12
var perfect_refund_done: bool = false

var hit_ids: Array[int] = []
var _afterimage_cd: float = 0.0


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or active or is_gliding or wick.is_gliding() or wick.is_zipping() or wick.bounce_t > 0.0:
		return false
	return true


func press() -> bool:
	dash_held = true
	if not can_use():
		if not unlocked and wick != null:
			wick.emit_sfx("denied", wick.global_position, false)
		return false

	var data: Dictionary = get_data()
	var move_v: Vector2 = wick.get_move_input()
	if move_v.length_squared() > 0.01:
		dash_dir = move_v.normalized()
	elif wick.facing.length_squared() > 0.0001:
		dash_dir = wick.facing.normalized()
	else:
		dash_dir = Vector2.RIGHT

	dash_speed = float(data.get("speed", 340.0))
	var duration: float = float(data.get("duration", 0.17))
	var eff_cd: float = _get_effective_cooldown()

	active = true
	is_gliding = false
	if wick.move_wings != null:
		wick.move_wings.stop_glide()
	dash_time_left = duration
	dash_elapsed = 0.0
	dash_dist_traveled = 0.0
	gap_max_px = float(data.get("gap_max_px", 32.0))
	iframes_left = float(data.get("iframes", 0.19))
	perfect_window = float(data.get("perfect_window", 0.12))
	perfect_refund_done = false
	cooldown_left = eff_cd + duration
	hit_ids.clear()
	_afterimage_cd = 0.0

	wick.spawn_afterimage(LxWick.PAL_ICE)
	wick.spawn_ring(wick.global_position, 2.0, 12.0, 0.16, LxWick.PAL_ICE, 1.0)
	wick.emit_sfx("dash_whoosh", wick.global_position, false)
	return true


func release() -> void:
	dash_held = false
	if wick != null and wick.move_wings != null:
		wick.move_wings.stop_glide()
	is_gliding = false


func tick(dt: float) -> void:
	super.tick(dt)
	if iframes_left > 0.0:
		iframes_left = maxf(0.0, iframes_left - dt)


func tick_dash(dt: float, world_ctx: Node) -> void:
	if wick == null:
		return

	if active:
		dash_elapsed += dt
		dash_time_left -= dt
		var step_vec: Vector2 = dash_dir * dash_speed * dt
		dash_dist_traveled += step_vec.length()

		_afterimage_cd -= dt
		if _afterimage_cd <= 0.0:
			_afterimage_cd = 0.032
			wick.spawn_afterimage(LxWick.PAL_ICE)
		wick.spawn_sparks(wick.global_position, -dash_dir, 1, LxWick.PAL_ICE, 8.0, 22.0, 0.16)

		_check_dash_hits(world_ctx)

		if active and dash_time_left <= 0.0:
			active = false
			_maybe_start_wings_glide()
		return

	if wick.move_wings != null and wick.move_wings.gliding:
		wick.move_wings.tick_glide(dt, dash_held)
		is_gliding = wick.move_wings.gliding
		dash_dir = wick.move_wings.glide_dir
	else:
		is_gliding = false


func _maybe_start_wings_glide() -> void:
	if not dash_held or wick == null or wick.move_wings == null:
		is_gliding = false
		return
	is_gliding = wick.move_wings.start_glide(dash_dir)


func _check_dash_hits(world_ctx: Node) -> void:
	var data: Dictionary = get_data()
	var dmg: float = float(data.get("damage", 1.25))
	var wear: float = float(data.get("shield_wear", 1.0))
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.12))

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not wick.is_entity_alive(enemy):
			continue
		var eid: int = enemy.get_instance_id()
		if hit_ids.has(eid):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		var extra: float = 8.5 if wick.is_snatcher_entity(enemy) else 3.5
		if Geometry2D.get_closest_point_to_segment(epos, wick.last_pos, wick.global_position).distance_to(epos) <= erad + extra:
			hit_ids.append(eid)
			var hit: LxHit = LxHit.make(
				LxHit.SOURCE_DASH, dmg, dash_dir, wick.global_position - dash_dir * 12.0,
				wear, stag, false, wick, false
			)
			var res: int = wick.apply_hit_to_entity(enemy, hit)
			wick.on_hit_landed(hit, res, epos, hs, sh)
			if res == 0:
				# Shield blocked the dash -> crisp bounce-back
				active = false
				is_gliding = false
				if wick.move_wings != null:
					wick.move_wings.stop_glide()
				dash_time_left = 0.0
				wick.bounce_t = DASH_BOUNCE_TIME
				wick.knock = -dash_dir * DASH_BOUNCE_KNOCK
				return


func get_active_velocity() -> Vector2:
	if active:
		return dash_dir * dash_speed
	if wick != null and wick.move_wings != null and wick.move_wings.gliding:
		return wick.move_wings.get_glide_velocity()
	return Vector2.ZERO


func can_cross_gaps() -> bool:
	if is_gliding or (wick != null and wick.move_wings != null and wick.move_wings.gliding):
		return true
	return active and dash_dist_traveled <= gap_max_px + 28.0


func has_iframes() -> bool:
	return iframes_left > 0.0


func on_perfect_dodge() -> bool:
	if iframes_left <= 0.0:
		return false
	var data: Dictionary = get_data()
	var allow_refund: bool = bool(data.get("perfect_refund", true))
	if allow_refund and not perfect_refund_done:
		perfect_refund_done = true
		cooldown_left = 0.0
		wick.perfect_dodges += 1
		wick.spawn_ring(wick.global_position, 3.0, 16.0, 0.22, LxWick.PAL_SKY, 1.5)
		wick.spawn_sparks(wick.global_position, -dash_dir, 6, LxWick.PAL_ICE, 30.0, 75.0, 0.20)
		wick.emit_sfx("perfect_dodge", wick.global_position, false)
	return true


func cancel() -> void:
	active = false
	is_gliding = false
	dash_time_left = 0.0
	if wick != null and wick.move_wings != null:
		wick.move_wings.stop_glide()


func reset() -> void:
	super.reset()
	cancel()
	dash_held = false
	iframes_left = 0.0
	perfect_refund_done = false
	hit_ids.clear()


func _get_effective_cooldown() -> float:
	if Lx.state != null:
		return Lx.state.get_effective_dash_cooldown()
	return float(get_data().get("cooldown", 0.55))
