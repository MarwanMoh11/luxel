class_name LxMooringPost
extends LxToy
## Island 2 16x24 water piling: catches Wick's thrown lantern with infinite hang while mounted,
## amplifies LxVehicleSkiff.on_wick_zip into a 90-180 deg tangential slingshot around orbit_r,
## and provides a safe dismount apron when allow_dismount is true.

var orbit_r: float = 44.0
var allow_dismount: bool = true
var state: String = "idle" # "idle" | "anchored" | "whipping"
var _catch_cd: float = 0.0
var _whip_t: float = 0.0
var _whip_skiff: Node = null
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "mooring_post"
	size = _parse_size(props.get("size", [16.0, 24.0]), Vector2(16.0, 24.0))
	radius = maxf(14.0, float(props.get("radius", 16.0)))
	orbit_r = clampf(float(props.get("orbit_r", 44.0)), 24.0, 88.0)
	allow_dismount = bool(props.get("allow_dismount", true))
	state = "idle"
	_catch_cd = 0.0
	_whip_t = 0.0
	_whip_skiff = null
	_pulse_t = 0.0
	z_index = 0
	queue_redraw()


func reset_toy() -> void:
	state = "idle"
	_whip_t = 0.0
	_whip_skiff = null
	_catch_cd = 0.0
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	# Tight 10x10 piling bollard center so Skiff orbits cleanly without snagging far out
	return Rect2(pos - Vector2(5.0, 5.0), Vector2(10.0, 10.0)) if active else Rect2()


func blocks_sight() -> bool:
	return false


func is_platform_solid() -> bool:
	return active and allow_dismount


func get_platform_rect() -> Rect2:
	return Rect2(pos - Vector2(14.0, 14.0), Vector2(28.0, 28.0)) if is_platform_solid() else Rect2()


func get_dismount_pos(from_pos: Vector2) -> Vector2:
	if not active or not allow_dismount:
		return Vector2.INF
	var dir: Vector2 = (from_pos - pos).normalized() if from_pos.distance_squared_to(pos) > 4.0 else Vector2.DOWN
	return pos + dir * 10.0


func begin_whip(skiff: Node) -> void:
	_whip_skiff = skiff
	_whip_t = 0.68
	state = "whipping"
	_pulse_t = 0.42
	_emit_sfx("harbor_creak")
	queue_redraw()


func end_whip(_skiff: Node = null) -> void:
	_whip_skiff = null
	_whip_t = 0.0
	if state == "whipping":
		state = "anchored" if _is_lantern_here() else "idle"
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _catch_cd > 0.0:
		return false
	if hit.source == LxHit.SOURCE_THROW:
		var lan: LxLantern = _get_wick_lantern()
		if lan != null:
			_anchor_lantern(lan)
			return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _catch_cd > 0.0:
		_catch_cd = maxf(0.0, _catch_cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if _whip_t > 0.0:
		_whip_t = maxf(0.0, _whip_t - dt)
		dirty = true
		if _whip_t <= 0.0:
			end_whip()

	var lan: LxLantern = _get_wick_lantern()
	if state == "anchored" or state == "whipping":
		if lan == null or (lan.state != LxLantern.State.HANGING and lan.state != LxLantern.State.FLYING):
			state = "idle"
			_whip_skiff = null
			_whip_t = 0.0
			_catch_cd = 0.25
			set_powered(false)
			dirty = true
		else:
			lan.state = LxLantern.State.HANGING
			lan.pos = pos
			lan.prev_pos = pos
			lan.global_position = pos.round()
			lan.vel = Vector2.ZERO
			# Infinite hang while mounted in Skiff (and generous refresh while anchored)
			var is_mounted_w: bool = Lx.player is LxWick and (Lx.player as LxWick).is_mounted()
			if is_mounted_w or state == "whipping":
				lan.hang_timer = lan.hang_max
			else:
				lan.hang_timer = maxf(lan.hang_timer, 1.2)
			dirty = true
	elif lan != null and _catch_cd <= 0.0:
		if (lan.state == LxLantern.State.FLYING or lan.state == LxLantern.State.HANGING) and lan.pos.distance_to(pos) <= 22.0:
			_anchor_lantern(lan)
			dirty = true

	if dirty or int(floorf(_clock * 3.0)) != int(floorf((_clock - dt) * 3.0)):
		queue_redraw()


func _anchor_lantern(lan: LxLantern) -> void:
	lan.state = LxLantern.State.HANGING
	lan.pos = pos
	lan.prev_pos = pos
	lan.global_position = pos.round()
	lan.vel = Vector2.ZERO
	lan.hang_timer = lan.hang_max
	lan.queue_redraw()
	state = "anchored"
	_pulse_t = 0.35
	set_powered(true)
	emit_power(true)
	_emit_sfx("lantern_land")
	_emit_gust(44.0, 28.0)
	queue_redraw()


func _is_lantern_here() -> bool:
	var lan: LxLantern = _get_wick_lantern()
	return lan != null and lan.state == LxLantern.State.HANGING and lan.pos.distance_to(pos) <= 10.0


func _get_wick_lantern() -> LxLantern:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lv: Variant = Lx.player.get("lantern")
		if lv is LxLantern and is_instance_valid(lv):
			return lv as LxLantern
	return null


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == "whipping":
		return Vector4(pos.x, pos.y - 6.0, 74.0, 1.10)
	if state == "anchored":
		return Vector4(pos.x, pos.y - 6.0, 56.0, 0.85)
	return Vector4.ZERO


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var wave_step: int = 0 if red else (int(floorf(_clock * 3.0)) % 2)

	# Water ripple base + optional orbit radius hint while anchored or whipping
	draw_arc(Vector2(0.0, 4.0), 9.0 + float(wave_step), 0.0, TAU, 14, Color(PAL["ice"] as Color, 0.55), 1.0)
	if state == "anchored" or state == "whipping":
		var ring_c: Color = (PAL["cream"] if state == "whipping" else PAL["gold"]) as Color
		var segs: int = 24
		for i: int in range(segs):
			if i % 2 == 0:
				var a0: float = (TAU * float(i)) / float(segs) + _clock * (2.6 if state == "whipping" else 0.7)
				var pt: Vector2 = Vector2(roundf(cos(a0) * orbit_r), roundf(sin(a0) * orbit_r))
				draw_rect(Rect2(pt, Vector2(2.0 if state == "whipping" else 1.0, 1.0)), Color(ring_c, 0.72))

	# Small timber dismount apron when allow_dismount is true
	if allow_dismount:
		LxPhysDraw.draw_bevel_box(self, Rect2(-9.0, 0.0, 18.0, 8.0), PAL["night"] as Color, PAL["stone"] as Color, PAL["void"] as Color, c_void)

	# Vertical weathered timber piling (16x24 silhouette, crisp dark outline)
	draw_rect(Rect2(-5.0, -14.0, 10.0, 20.0), c_void)
	draw_rect(Rect2(-4.0, -13.0, 8.0, 18.0), PAL["wine"] as Color)
	draw_rect(Rect2(-4.0, -13.0, 3.0, 18.0), PAL["apricot"] as Color)
	draw_rect(Rect2(2.0, -13.0, 2.0, 18.0), PAL["dusk"] as Color)
	# Coiled hemp mooring rope wraps
	for ry: float in [-5.0, -3.0, -1.0]:
		draw_line(Vector2(-4.0, ry), Vector2(3.0, ry), PAL["gold"] as Color if state != "idle" else PAL["stone"] as Color, 1.0)
		draw_line(Vector2(-4.0, ry + 1.0), Vector2(3.0, ry + 1.0), PAL["night"] as Color, 1.0)
	# Iron mooring cap ring + brass lantern cleat
	var cap_c: Color = (PAL["cream"] if state == "whipping" else (PAL["gold"] if state == "anchored" else PAL["stone"])) as Color
	draw_rect(Rect2(-6.0, -15.0, 12.0, 4.0), c_void)
	draw_rect(Rect2(-5.0, -14.0, 10.0, 2.0), PAL["deep"] as Color if state == "idle" else PAL["apricot"] as Color)
	draw_rect(Rect2(-4.0, -14.0, 8.0, 1.0), cap_c)
	# Mooring side horn cleats
	draw_rect(Rect2(-7.0, -11.0, 2.0, 2.0), c_void)
	draw_rect(Rect2(5.0, -11.0, 2.0, 2.0), c_void)
	draw_rect(Rect2(-6.0, -11.0, 1.0, 1.0), cap_c)
	draw_rect(Rect2(5.0, -11.0, 1.0, 1.0), cap_c)

	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.42, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(5.0, 18.0, u)), 0.0, TAU, 16, PAL["cream"] as Color if u < 0.4 else PAL["gold"] as Color, 1.2)
	_draw_signal_pulses()
