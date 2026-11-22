class_name LxMoveWings
extends LxMove
## Wings (Island 4): hold lx_dash (Shift / A) at the end of a Flare Dash to glide up to
## glide_max_px (96 px) at glide_speed (120 px/s, max glide_duration 0.8 s).
## While gliding, Wick crosses pit and water tiles and hops over ground shockwave rings.

var gliding: bool = false
var glide_dir: Vector2 = Vector2.RIGHT
var glide_speed: float = 120.0
var glide_max_px: float = 96.0
var glide_duration: float = 0.8
var glide_dist_traveled: float = 0.0
var glide_dist_left: float = 0.0
var glide_time_left: float = 0.0
var glides_count: int = 0

var _afterimage_cd: float = 0.0
var _sw_cleared_this_glide: bool = false


func can_use() -> bool:
	return unlocked and wick != null and not wick.dead and not gliding and not wick.is_zipping()


func is_gliding() -> bool:
	return gliding


func clears_shockwave() -> bool:
	return gliding and bool(get_data().get("clears_shockwave", true))


func clears_pit() -> bool:
	return gliding and bool(get_data().get("clears_pit", true))


func start_glide(dir: Vector2) -> bool:
	if not can_use():
		return false
	var data: Dictionary = get_data()
	glide_speed = float(data.get("glide_speed", 120.0))
	glide_max_px = float(data.get("glide_max_px", 96.0))
	glide_duration = float(data.get("glide_duration", 0.8))
	if dir.length_squared() > 0.0001:
		glide_dir = dir.normalized()
	elif wick.facing.length_squared() > 0.0001:
		glide_dir = wick.facing.normalized()
	else:
		glide_dir = Vector2.RIGHT

	gliding = true
	glide_dist_traveled = 0.0
	glide_dist_left = glide_max_px
	glide_time_left = glide_duration
	glides_count += 1
	_afterimage_cd = 0.0
	_sw_cleared_this_glide = false

	wick.spawn_ring(wick.global_position, 2.0, 11.0, 0.18, LxWick.PAL_SKY, 1.0)
	wick.emit_sfx("wings_glide", wick.global_position, false)
	return true


func on_shockwave_cleared() -> void:
	if wick == null or _sw_cleared_this_glide:
		return
	_sw_cleared_this_glide = true
	wick.spawn_ring(wick.global_position, 3.0, 15.0, 0.22, LxWick.PAL_SKY, 1.4)
	wick.spawn_ring(wick.global_position, 2.0, 10.0, 0.16, LxWick.PAL_CREAM, 1.0)
	wick.spawn_sparks(wick.global_position, Vector2.UP, 6, LxWick.PAL_ICE, 24.0, 66.0, 0.22)
	wick.emit_sfx("prism_bounce", wick.global_position, false)
	if wick.move_sunflare != null and wick.move_sunflare.unlocked:
		var emax: float = wick.move_sunflare.get_ember_max()
		var was_full: bool = wick.ember >= emax - 0.001
		wick.ember = minf(emax, wick.ember + 6.0)
		if not was_full and wick.ember >= emax - 0.001:
			wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
			wick.emit_sfx("beam_ready", wick.global_position, false)


func stop_glide() -> void:
	gliding = false
	glide_time_left = 0.0
	glide_dist_left = 0.0


func tick_glide(dt: float, dash_held: bool) -> void:
	if not gliding:
		return
	if not dash_held or wick == null or wick.dead or wick.is_zipping():
		stop_glide()
		return
	var steer: Vector2 = wick.get_move_input()
	if steer.length_squared() > 0.04:
		glide_dir = glide_dir.lerp(steer.normalized(), minf(1.0, dt * 6.0)).normalized()

	var step_d: float = glide_speed * dt
	glide_dist_traveled += step_d
	glide_dist_left = maxf(0.0, glide_dist_left - step_d)
	glide_time_left = maxf(0.0, glide_time_left - dt)

	_afterimage_cd -= dt
	if _afterimage_cd <= 0.0:
		_afterimage_cd = 0.06
		wick.spawn_afterimage(LxWick.PAL_SKY)
		wick.spawn_sparks(wick.global_position, -glide_dir, 1, LxWick.PAL_ICE, 8.0, 22.0, 0.16)

	if glide_time_left <= 0.0 or glide_dist_left <= 0.0:
		stop_glide()


func get_glide_velocity() -> Vector2:
	return glide_dir * glide_speed if gliding else Vector2.ZERO


func reset() -> void:
	super.reset()
	stop_glide()
	glide_dist_traveled = 0.0
	glides_count = 0
