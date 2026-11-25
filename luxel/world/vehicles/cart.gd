class_name LxVehicleCart
extends LxToy
## Island 6 Rail Cart: rides a rail polyline, switches branches on signal,
## propelled by input or lantern recoil, and lets Wick jump cleanly between carts.

const CART_MAX_ACCEL: float = 220.0
const RECOIL_BOOST: float = 72.0
const FRICTION: float = 1.45
const JUMP_SPEED: float = 235.0
const JUMP_TIME: float = 0.28

var rail: Array[Vector2] = []
var alt_rail: Array[Vector2] = []
var using_alt: bool = false
var speed: float = 95.0
var loop: bool = false
var auto_run: bool = false
var rail_dist: float = 0.0
var rail_vel: float = 0.0
var tangent: Vector2 = Vector2.RIGHT
var rider: LxWick = null
var _board_grace: float = 0.0
var _wheel_phase: float = 0.0


func _toy_setup() -> void:
	kind = "vehicle_cart"
	size = Vector2(20.0, 14.0)
	radius = 13.0
	rail = LxPhysDraw.parse_path(props.get("rail", []), pos)
	if props.has("alt_rail"):
		alt_rail = LxPhysDraw.parse_path(props.get("alt_rail", []), pos)
	speed = maxf(24.0, float(props.get("speed", 95.0)))
	loop = bool(props.get("loop", false))
	auto_run = bool(props.get("auto", false))
	using_alt = false
	rail_dist = 0.0
	rail_vel = speed * 0.65 if auto_run else 0.0
	var active_rail: Array[Vector2] = _active_rail()
	if not active_rail.is_empty():
		pos = active_rail[0]
		position = pos.round()
	_update_pose_on_rail()
	z_index = LxPhysDraw.floor_z(region, -1)
	queue_redraw()


func _active_rail() -> Array[Vector2]:
	return alt_rail if (using_alt and alt_rail.size() >= 2) else rail


func _rail_total_len(pts: Array[Vector2]) -> float:
	if pts.size() < 2:
		return 0.0
	var total: float = 0.0
	var segs: int = pts.size() if loop else (pts.size() - 1)
	for i: int in range(segs):
		total += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return total


func _on_power_changed(is_on: bool) -> void:
	if alt_rail.size() >= 2:
		using_alt = is_on
		var total: float = _rail_total_len(_active_rail())
		rail_dist = clampf(rail_dist, 0.0, maxf(0.0, total))
		_update_pose_on_rail()
		_emit_sfx("shield_clang")
	else:
		rail_vel = -rail_vel if absf(rail_vel) > 5.0 else (speed * 0.7 if is_on else 0.0)
	queue_redraw()


func interact(actor: Node = null) -> bool:
	if not active or not (actor is LxWick):
		return false
	var w: LxWick = actor as LxWick
	if rider == w:
		return try_dismount(w)
	if w.is_mounted() or w.global_position.distance_to(pos) > 28.0:
		return false
	return w.mount(self)


func on_mounted(w: LxWick) -> void:
	rider = w
	if not w.fired.is_connected(_on_rider_fired):
		w.fired.connect(_on_rider_fired)
	w.global_position = pos
	w.last_pos = pos
	_emit_sfx("shield_clang")
	queue_redraw()


func on_dismounted(w: LxWick) -> void:
	if is_instance_valid(w) and w.fired.is_connected(_on_rider_fired):
		w.fired.disconnect(_on_rider_fired)
	if rider == w:
		rider = null
	_board_grace = 0.22
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(rider) and rider.fired.is_connected(_on_rider_fired):
		rider.fired.disconnect(_on_rider_fired)
	rider = null


func try_dismount(w: LxWick) -> bool:
	var exit_p: Vector2 = _find_safe_exit()
	if not exit_p.is_finite():
		_emit_sfx("denied")
		return false
	w.dismount(exit_p)
	return true


func _find_safe_exit() -> Vector2:
	if region == null:
		return pos + Vector2(0.0, -16.0)
	var side := Vector2(-tangent.y, tangent.x)
	for cand: Vector2 in [pos + side * 16.0, pos - side * 16.0, pos + side * 24.0, pos - side * 24.0, pos + tangent * 18.0, pos - tangent * 18.0]:
		if LxPhysDraw.is_tile_safe_land(region, cand):
			return cand
	return Vector2.INF


func _on_rider_fired(aim_dir: Vector2, fire_kind: String) -> void:
	if rider == null or aim_dir.length_squared() <= 0.0001:
		return
	var mult: float = 1.9 if fire_kind == "beam" else (0.9 if fire_kind == "throw" else 1.0)
	var boost: float = (-aim_dir.normalized()).dot(tangent) * RECOIL_BOOST * mult
	rail_vel = clampf(rail_vel + boost, -speed * 1.25, speed * 1.25)


## Pressing Dash on a cart launches Wick cleanly to jump onto another cart or platform!
func on_wick_dash(w: LxWick) -> bool:
	if rider != w:
		return false
	var mv: Vector2 = w.get_move_input()
	var jdir: Vector2 = mv.normalized() if mv.length_squared() > 0.04 else (w.facing.normalized() if w.facing.length_squared() > 0.01 else Vector2(-tangent.y, tangent.x))
	_board_grace = 0.24
	w.dismount(pos)
	w.launch(jdir, JUMP_SPEED, JUMP_TIME)
	_emit_sfx("dash_whoosh")
	return true


func tick_mounted(dt: float, w: LxWick, _world_ctx: Node) -> void:
	if rider != w:
		return
	var mv: Vector2 = w.get_move_input()
	if mv.length_squared() > 0.04:
		var push: float = mv.normalized().dot(tangent)
		rail_vel = clampf(rail_vel + push * CART_MAX_ACCEL * dt, -speed, speed)
	_step_rail(dt)
	w.global_position = pos
	w.velocity = tangent * rail_vel


func tick(dt: float) -> void:
	super.tick(dt)
	_board_grace = maxf(0.0, _board_grace - dt)
	if rider == null or not is_instance_valid(rider):
		rider = null
		if auto_run and absf(rail_vel) < speed * 0.4:
			rail_vel = move_toward(rail_vel, speed * (1.0 if rail_vel >= 0.0 else -1.0), 140.0 * dt)
		_step_rail(dt)
		# Catch an airborne / launched Wick jumping from another cart!
		if _board_grace <= 0.0 and is_instance_valid(Lx.player) and Lx.player is LxWick:
			var w: LxWick = Lx.player as LxWick
			if not w.dead and not w.is_mounted() and (w.is_launched() or w.is_dashing() or w.is_gliding()):
				if w.global_position.distance_to(pos) <= 15.0:
					w.mount(self)
					w.spawn_ring(pos, 2.0, 14.0, 0.20, LxWick.PAL_GOLD, 1.4)
	queue_redraw()


func _step_rail(dt: float) -> void:
	var pts: Array[Vector2] = _active_rail()
	var total: float = _rail_total_len(pts)
	if total <= 0.5:
		return
	if LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(pos, "wick")
		rail_vel = clampf(rail_vel + fa.dot(tangent) * dt, -speed * 1.35, speed * 1.35)
	if not auto_run:
		rail_vel *= exp(-FRICTION * dt)
		if absf(rail_vel) < 2.0:
			rail_vel = 0.0
	rail_dist += rail_vel * dt
	if loop:
		rail_dist = fposmod(rail_dist, total)
	else:
		if rail_dist <= 0.0:
			rail_dist = 0.0
			rail_vel = absf(rail_vel) * (0.85 if auto_run else 0.0)
		elif rail_dist >= total:
			rail_dist = total
			rail_vel = -absf(rail_vel) * (0.85 if auto_run else 0.0)
	_wheel_phase += absf(rail_vel) * dt * 0.35
	_update_pose_on_rail()


func _update_pose_on_rail() -> void:
	var pts: Array[Vector2] = _active_rail()
	if pts.size() < 2:
		return
	var rem: float = rail_dist
	var segs: int = pts.size() if loop else (pts.size() - 1)
	for i: int in range(segs):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var slen: float = a.distance_to(b)
		if slen <= 0.01:
			continue
		if rem <= slen or i == segs - 1:
			var t: float = clampf(rem / slen, 0.0, 1.0)
			pos = a.lerp(b, t)
			position = pos.round()
			tangent = (b - a) / slen
			return
		rem -= slen


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "PROMPT_LEAVE_CART" if rider != null else "PROMPT_BOARD_CART"


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["rail_dist"] = rail_dist
		d["using_alt"] = using_alt
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		using_alt = bool(d.get("using_alt", using_alt))
		rail_dist = float(d.get("rail_dist", rail_dist))
		_update_pose_on_rail()
	queue_redraw()


func _draw() -> void:
	# 1. Draw both rails (inactive branch dimmed, active branch crisp steel + sleepers)
	if alt_rail.size() >= 2:
		var inactive_pts: Array[Vector2] = rail if using_alt else alt_rail
		LxPhysDraw.draw_track_line(self, pos, inactive_pts, PAL["dusk"] as Color, PAL["night"] as Color, PAL["mauve"] as Color, loop)
	LxPhysDraw.draw_track_line(self, pos, _active_rail(), PAL["stone"] as Color, PAL["plum"] as Color, biome("glow"), loop)

	# 2. Contact shadow + iron minecart body
	var body := Rect2(-9.0, -7.0, 18.0, 12.0)
	LxPhysDraw.draw_shadow_rect(self, body, Vector2(1.0, 2.0), 0.42)
	# Bogie wheels
	var w_off: float = fmod(_wheel_phase, 2.0)
	for wx: float in [-7.0, 4.0]:
		draw_rect(Rect2(wx, 4.0, 3.0, 2.0), PAL["night"] as Color)
		draw_rect(Rect2(wx + (1.0 if w_off < 1.0 else 0.0), 4.0, 1.0, 1.0), PAL["stone"] as Color)
	LxPhysDraw.draw_bevel_box(self, body, PAL["dusk"] as Color, PAL["stone"] as Color, PAL["night"] as Color, PAL["void"] as Color, biome("hi"))
	# Recessed ore interior + warm forge/biome trim stripe
	draw_rect(Rect2(-6.0, -4.0, 12.0, 6.0), PAL["night"] as Color)
	draw_rect(Rect2(-7.0, 2.0, 14.0, 1.0), biome("glow") if rider != null else biome("mid"))
	# Front headlamp pip
	var front: Vector2 = (tangent * 8.0).round()
	draw_rect(Rect2(front - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color if rider != null else biome("hi"))
