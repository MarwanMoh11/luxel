class_name LxDarknessLayer
extends CanvasLayer
## Smooth feathered twilight overlay with up to 16 camera-prioritized light pools,
## relit zone transitions, and an expanding dawn relight wave.

const DARKNESS_SHADER: Shader = preload("res://luxel/world/darkness.gdshader")
const VIEW_SIZE: Vector2 = Vector2(320.0, 180.0)
const MAX_LIGHTS: int = 16
const MAX_LIT_ZONES: int = 8

var darkness_strength: float = 0.56
var wave_active: bool = false
var wave_origin: Vector2 = Vector2.ZERO
var wave_radius: float = 0.0

var _veil: ColorRect = null
var _mat: ShaderMaterial = null
var _clock: float = 0.0
var _wave_speed: float = 280.0
var _wave_max_radius: float = 1600.0
var _zone_fades: Dictionary = {}


func _ready() -> void:
	layer = 5
	_ensure_veil()


func _ensure_veil() -> void:
	if _veil != null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = DARKNESS_SHADER
	_veil = ColorRect.new()
	_veil.name = "TwilightVeil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.position = Vector2.ZERO
	_veil.size = VIEW_SIZE
	_veil.color = Color.WHITE
	_veil.material = _mat
	add_child(_veil)


func set_darkness(strength: float) -> void:
	darkness_strength = clampf(strength, 0.0, 1.0)


func reset_zones() -> void:
	_zone_fades.clear()


func trigger_dawn_wave(origin: Vector2, speed: float = 280.0, max_radius: float = 1600.0) -> void:
	wave_active = true
	wave_origin = origin
	wave_radius = 0.0
	_wave_speed = maxf(20.0, speed)
	_wave_max_radius = maxf(100.0, max_radius)


func stop_dawn_wave() -> void:
	wave_active = false
	wave_radius = 0.0


func sync(dt: float, region: LxRegionLoader = null, extra_lights: Array[Vector4] = []) -> void:
	_ensure_veil()
	if _mat == null:
		return
	_clock += dt

	if wave_active:
		wave_radius += _wave_speed * dt
		if wave_radius >= _wave_max_radius:
			darkness_strength = maxf(0.0, darkness_strength - dt * 0.65)
			if darkness_strength <= 0.002:
				wave_active = false

	var view_sz: Vector2 = VIEW_SIZE
	if get_viewport() != null:
		var vr: Vector2 = get_viewport().get_visible_rect().size
		if vr.x > 0.0 and vr.y > 0.0:
			view_sz = vr
	_veil.position = Vector2.ZERO
	_veil.size = view_sz

	var cam_center: Vector2 = view_sz * 0.5
	if Lx.camera != null:
		cam_center = Lx.camera.global_position
	var cam_origin: Vector2 = (cam_center - view_sz * 0.5).round()

	_mat.set_shader_parameter("cam_origin", cam_origin)
	_mat.set_shader_parameter("view_size", view_sz)
	_mat.set_shader_parameter("darkness_strength", clampf(darkness_strength, 0.0, 1.0))

	var flicker: float = 0.96 + 0.04 * sin(_clock * 5.2)
	var lights := PackedVector4Array()

	# Priority 0: Wick and thrown lantern always keep the top GPU slots
	_append_player_lights(lights, flicker)

	# Priority 1: World light pools sorted by squared distance to camera center
	var candidates: Array[Dictionary] = []
	if region != null:
		var pools: Array[Vector4] = region.get_light_pools()
		for pool: Vector4 in pools:
			if pool.z <= 1.0 or pool.w <= 0.001:
				continue
			var p := Vector2(pool.x, pool.y)
			if p.distance_to(cam_center) <= 340.0 + pool.z:
				candidates.append({
					"d": p.distance_squared_to(cam_center),
					"v": Vector4(pool.x, pool.y, pool.z * flicker, pool.w),
				})

	for extra: Vector4 in extra_lights:
		if extra.z <= 1.0 or extra.w <= 0.001:
			continue
		var ep := Vector2(extra.x, extra.y)
		if ep.distance_to(cam_center) <= 300.0 + extra.z:
			candidates.append({
				"d": ep.distance_squared_to(cam_center) + 2500.0,
				"v": extra,
			})

	# Include live player bolts as soft transient pools when available
	if Lx.player != null and is_instance_valid(Lx.player):
		var bolts_var: Variant = Lx.player.get("bolts")
		if bolts_var is Array:
			for b: Variant in (bolts_var as Array):
				var bp: Variant = b.get("pos") if (b is Dictionary or b is Object) else null
				if bp is Vector2 and (bp as Vector2).distance_to(cam_center) <= 240.0:
					var bpos: Vector2 = bp as Vector2
					candidates.append({
						"d": bpos.distance_squared_to(cam_center) + 5000.0,
						"v": Vector4(bpos.x, bpos.y, 34.0, 0.85),
					})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	for entry: Dictionary in candidates:
		if lights.size() >= MAX_LIGHTS:
			break
		lights.append(entry["v"] as Vector4)

	var lcount: int = mini(lights.size(), MAX_LIGHTS)
	lights.resize(MAX_LIGHTS)
	_mat.set_shader_parameter("lights", lights)
	_mat.set_shader_parameter("light_count", lcount)

	# Relit zones with smooth fade transitions
	var zrects := PackedVector4Array()
	var zfades := PackedFloat32Array()
	if region != null:
		for z: Dictionary in region.get_zones():
			var zid: String = str(z.get("id", ""))
			if zid.is_empty():
				continue
			var target: float = 1.0 if region.is_zone_lit(zid) else 0.0
			var cur: float = float(_zone_fades.get(zid, target))
			if dt > 0.0:
				cur = move_toward(cur, target, dt * 1.15)
			else:
				cur = target
			_zone_fades[zid] = cur
			if cur > 0.005 and zrects.size() < MAX_LIT_ZONES:
				var r: Rect2 = LxMapFormat.to_rect2(z.get("rect", []))
				zrects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
				zfades.append(clampf(cur, 0.0, 1.0))

	var zcount: int = mini(zrects.size(), MAX_LIT_ZONES)
	zrects.resize(MAX_LIT_ZONES)
	zfades.resize(MAX_LIT_ZONES)
	_mat.set_shader_parameter("lit_zones", zrects)
	_mat.set_shader_parameter("lit_zone_fade", zfades)
	_mat.set_shader_parameter("lit_zone_count", zcount)

	if wave_active:
		_mat.set_shader_parameter("wave_active", 1.0)
		_mat.set_shader_parameter("wave_origin", wave_origin)
		_mat.set_shader_parameter("wave_radius", wave_radius)
	else:
		_mat.set_shader_parameter("wave_active", 0.0)


func _append_player_lights(lights: PackedVector4Array, flicker: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var p_pos: Vector2 = Vector2.ZERO
	if Lx.player is Node2D:
		p_pos = (Lx.player as Node2D).global_position
	elif Lx.player.has_method("get_pos"):
		p_pos = Lx.player.call("get_pos") as Vector2

	var lantern_out: bool = false
	var lan_pos: Vector2 = p_pos
	var custom_r: float = -1.0
	var lan_node: Variant = Lx.player.get("lantern")
	if lan_node != null and lan_node is Object:
		if (lan_node as Object).has_method("is_out"):
			lantern_out = bool((lan_node as Object).call("is_out"))
		elif (lan_node as Object).get("is_held") != null:
			lantern_out = not bool((lan_node as Object).get("is_held"))
		if (lan_node as Object).has_method("get_light_radius"):
			custom_r = float((lan_node as Object).call("get_light_radius"))
		if lantern_out:
			if (lan_node as Object).get("pos") is Vector2:
				lan_pos = (lan_node as Object).get("pos") as Vector2
			elif lan_node is Node2D:
				lan_pos = (lan_node as Node2D).global_position

	var has_lens: bool = Lx.state != null and Lx.state.has_move("lens")
	if not lantern_out:
		var base_hand: float = custom_r if custom_r > 0.0 else (108.0 if has_lens else 96.0)
		lights.append(Vector4(p_pos.x, p_pos.y - 8.0, base_hand * flicker, 1.35))
	else:
		lights.append(Vector4(p_pos.x, p_pos.y - 8.0, 42.0, 0.72))
		var base_hung: float = custom_r if custom_r > 0.0 else (118.0 if has_lens else 86.0)
		lights.append(Vector4(lan_pos.x, lan_pos.y - 6.0, base_hung * flicker, 1.38))
