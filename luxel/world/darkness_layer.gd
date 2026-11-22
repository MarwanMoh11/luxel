class_name LxDarknessLayer
extends CanvasLayer
## Smooth feathered twilight overlay with biome-aware Last Light grading,
## dual-frequency candlelight flicker, reactive combat/discovery light bursts,
## relit zone transitions, subtle corner vignette, and an expanding dawn wave.

const DARKNESS_SHADER: Shader = preload("res://luxel/world/darkness.gdshader")
const VIEW_SIZE: Vector2 = Vector2(320.0, 180.0)
const MAX_LIGHTS: int = 16
const MAX_LIT_ZONES: int = 8
const MAX_BURST_LIGHTS: int = 12
const TINT_LERP_S: float = 0.6
const DEFAULT_TINT: Vector3 = Vector3(0.42, 0.40, 0.64)

const BIOME_TINTS: Dictionary = {
	1: Vector3(0.46, 0.40, 0.62), # Bell Isle: warm dusk indigo
	2: Vector3(0.36, 0.46, 0.64), # Tidewater Harbor: coastal sea-mist slate
	3: Vector3(0.34, 0.48, 0.56), # Thornwood Hollow: deep woodland emerald-night
	4: Vector3(0.35, 0.49, 0.62), # Mirefen Gardens: moonlit botanical teal
	5: Vector3(0.36, 0.42, 0.68), # Starfall Observatory: astral sapphire
	6: Vector3(0.50, 0.36, 0.54), # Ashen Kiln: volcanic soot-plum
	7: Vector3(0.44, 0.49, 0.70), # Moon Shoals: silvery pale moonlight
	8: Vector3(0.32, 0.28, 0.52), # The Long Night: deepest eclipsed obsidian
}

var darkness_strength: float = 0.56
var vignette_strength: float = 0.14
var wave_active: bool = false
var wave_origin: Vector2 = Vector2.ZERO
var wave_radius: float = 0.0

var _veil: ColorRect = null
var _mat: ShaderMaterial = null
var _clock: float = 0.0
var _wave_speed: float = 280.0
var _wave_max_radius: float = 1600.0
var _zone_fades: Dictionary = {}
var _current_tint: Vector3 = DEFAULT_TINT
var _from_tint: Vector3 = DEFAULT_TINT
var _target_tint: Vector3 = DEFAULT_TINT
var _tint_t: float = 1.0
var _tint_ready: bool = false
var _burst_lights: Array[Dictionary] = []
var _bound_events: LxEventBus = null

func _ready() -> void:
	layer = 5
	_ensure_veil()
	_sync_events()

func _exit_tree() -> void:
	_set_events(_bound_events, false)
	_bound_events = null

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

func _sync_events() -> void:
	if Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events:
		return
	_set_events(_bound_events, false)
	_bound_events = Lx.events
	_set_events(_bound_events, true)

func _set_events(ev: LxEventBus, bind: bool) -> void:
	if ev == null or not is_instance_valid(ev):
		return
	var pairs: Array = [
		[&"enemy_killed", _on_enemy_killed], [&"lantern_hung", _on_lantern_hung],
		[&"lantern_caught", _on_lantern_caught], [&"lantern_struck", _on_lantern_struck],
		[&"beacon_lit", _on_beacon_lit], [&"waystone_lit", _on_waystone_lit],
		[&"shrine_claimed", _on_shrine_claimed], [&"boss_phase_changed", _on_boss_phase_changed],
		[&"boss_defeated", _on_boss_defeated], [&"great_lamp_relit", _on_great_lamp_relit],
		[&"ember_piece_collected", _on_ember_piece], [&"upgrade_purchased", _on_upgrade_purchased],
	]
	for pair: Array in pairs:
		var sig: StringName = pair[0] as StringName
		var cb: Callable = pair[1] as Callable
		if bind and not ev.is_connected(sig, cb):
			ev.connect(sig, cb)
		elif not bind and ev.is_connected(sig, cb):
			ev.disconnect(sig, cb)

func set_darkness(strength: float) -> void:
	darkness_strength = clampf(strength, 0.0, 1.0)

func reset_zones() -> void:
	_zone_fades.clear()
	_burst_lights.clear()

func trigger_dawn_wave(origin: Vector2, speed: float = 280.0, max_radius: float = 1600.0) -> void:
	wave_active = true
	wave_origin = origin
	wave_radius = 0.0
	_wave_speed = maxf(20.0, speed)
	_wave_max_radius = maxf(100.0, max_radius)

func stop_dawn_wave() -> void:
	wave_active = false
	wave_radius = 0.0

func add_burst_light(pos: Vector2, radius: float, intensity: float, duration: float) -> void:
	if _burst_lights.size() >= MAX_BURST_LIGHTS:
		_burst_lights.pop_front()
	_burst_lights.append({
		"pos": pos, "r": maxf(8.0, radius),
		"i": clampf(intensity, 0.1, 2.0), "age": 0.0, "dur": clampf(duration, 0.08, 1.2),
	})

func sync(dt: float, region: LxRegionLoader = null, extra_lights: Array[Vector4] = []) -> void:
	_ensure_veil()
	if _mat == null:
		return
	if _bound_events != Lx.events:
		_sync_events()
	_clock += dt
	_update_biome_tint(dt, region)
	_tick_burst_lights(dt)

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

	var cam_center: Vector2 = Lx.camera.global_position if (Lx.camera != null and is_instance_valid(Lx.camera)) else view_sz * 0.5
	_mat.set_shader_parameter("cam_origin", (cam_center - view_sz * 0.5).round())
	_mat.set_shader_parameter("view_size", view_sz)
	_mat.set_shader_parameter("darkness_strength", clampf(darkness_strength, 0.0, 1.0))
	_mat.set_shader_parameter("biome_tint", _current_tint)
	_mat.set_shader_parameter("vignette_strength", clampf(vignette_strength, 0.0, 0.5))

	# Dual-frequency organic flame breath
	var flicker: float = 0.955 + 0.030 * sin(_clock * 5.2) + 0.015 * sin(_clock * 13.7)
	var lights := PackedVector4Array()
	_append_player_lights(lights, flicker)

	var candidates: Array[Dictionary] = []
	for b: Dictionary in _burst_lights:
		var bpos: Vector2 = b["pos"] as Vector2
		var u: float = clampf(float(b["age"]) / maxf(0.01, float(b["dur"])), 0.0, 1.0)
		var br: float = float(b["r"]) * (0.62 + 0.38 * (1.0 - u))
		var bi: float = float(b["i"]) * (1.0 - u) * (1.0 - u)
		if bi > 0.02 and bpos.distance_to(cam_center) <= 320.0 + br:
			candidates.append({"d": bpos.distance_squared_to(cam_center) - 1800.0, "v": Vector4(bpos.x, bpos.y, br, bi)})

	if region != null:
		for pool: Vector4 in region.get_light_pools():
			if pool.z <= 1.0 or pool.w <= 0.001:
				continue
			var p := Vector2(pool.x, pool.y)
			if p.distance_to(cam_center) <= 340.0 + pool.z:
				candidates.append({"d": p.distance_squared_to(cam_center), "v": Vector4(pool.x, pool.y, pool.z * flicker, pool.w)})
		for e: LxEnemyBrain in region.get_enemies():
			if e != null and is_instance_valid(e) and e.is_alive() and e.is_boss:
				var bp: Vector2 = e.global_position + Vector2(0.0, -10.0)
				if bp.distance_to(cam_center) <= 320.0:
					candidates.append({"d": bp.distance_squared_to(cam_center) - 2400.0, "v": Vector4(bp.x, bp.y, 70.0 * flicker, 0.94)})

	for extra: Vector4 in extra_lights:
		if extra.z <= 1.0 or extra.w <= 0.001:
			continue
		var ep := Vector2(extra.x, extra.y)
		if ep.distance_to(cam_center) <= 300.0 + extra.z:
			candidates.append({"d": ep.distance_squared_to(cam_center) + 2500.0, "v": extra})

	if Lx.player != null and is_instance_valid(Lx.player):
		var bolts_var: Variant = Lx.player.get("bolts")
		if bolts_var is Array:
			for b: Variant in (bolts_var as Array):
				var bp: Variant = b.get("pos") if (b is Dictionary or b is Object) else null
				if bp is Vector2 and (bp as Vector2).distance_to(cam_center) <= 240.0:
					var bpos: Vector2 = bp as Vector2
					candidates.append({"d": bpos.distance_squared_to(cam_center) + 5000.0, "v": Vector4(bpos.x, bpos.y, 34.0, 0.85)})
		var beam_v: Variant = Lx.player.get("move_beam")
		if beam_v is Object and is_instance_valid(beam_v):
			var bt: float = float((beam_v as Object).get("beam_vis_t"))
			if bt > 0.0:
				var bf: float = clampf(bt / maxf(0.01, float((beam_v as Object).get("beam_vis_max"))), 0.0, 1.0)
				var ba: Vector2 = (beam_v as Object).get("beam_start") as Vector2
				var bb: Vector2 = (beam_v as Object).get("beam_end") as Vector2
				var m1: Vector2 = ba.lerp(bb, 0.35)
				var m2: Vector2 = ba.lerp(bb, 0.85)
				candidates.append({"d": m1.distance_squared_to(cam_center) - 2200.0, "v": Vector4(m1.x, m1.y, 68.0 * bf, 1.55 * bf)})
				candidates.append({"d": m2.distance_squared_to(cam_center) - 2200.0, "v": Vector4(m2.x, m2.y, 62.0 * bf, 1.45 * bf)})
		var flare_v: Variant = Lx.player.get("move_sunflare")
		if flare_v is Object and is_instance_valid(flare_v):
			var ft: float = float((flare_v as Object).get("flare_vis_t"))
			if ft > 0.0:
				var ff: float = clampf(ft / maxf(0.01, float((flare_v as Object).get("flare_vis_max"))), 0.0, 1.0)
				var fo: Vector2 = (flare_v as Object).get("flare_origin") as Vector2
				var fr: float = float((flare_v as Object).get("flare_radius"))
				candidates.append({"d": fo.distance_squared_to(cam_center) - 3200.0, "v": Vector4(fo.x, fo.y, fr * 2.0 * (0.45 + 0.55 * (1.0 - ff)), 1.85 * ff)})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	for entry: Dictionary in candidates:
		if lights.size() >= MAX_LIGHTS:
			break
		lights.append(entry["v"] as Vector4)

	var lcount: int = mini(lights.size(), MAX_LIGHTS)
	lights.resize(MAX_LIGHTS)
	_mat.set_shader_parameter("lights", lights)
	_mat.set_shader_parameter("light_count", lcount)

	var zrects := PackedVector4Array()
	var zfades := PackedFloat32Array()
	if region != null:
		for z: Dictionary in region.get_zones():
			var zid: String = str(z.get("id", ""))
			if zid.is_empty():
				continue
			var target: float = 1.0 if region.is_zone_lit(zid) else 0.0
			var cur: float = float(_zone_fades.get(zid, target))
			cur = move_toward(cur, target, dt * 1.15) if dt > 0.0 else target
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
	_mat.set_shader_parameter("wave_active", 1.0 if wave_active else 0.0)
	if wave_active:
		_mat.set_shader_parameter("wave_origin", wave_origin)
		_mat.set_shader_parameter("wave_radius", wave_radius)

func _update_biome_tint(dt: float, region: LxRegionLoader) -> void:
	var isl_id: int = 1
	if region != null and region.current_island_id > 0:
		isl_id = region.current_island_id
	elif Lx.state != null and is_instance_valid(Lx.state) and Lx.state.island_id > 0:
		isl_id = Lx.state.island_id
	var desired: Vector3 = BIOME_TINTS.get(clampi(isl_id, 1, 8), DEFAULT_TINT) as Vector3
	if not _tint_ready:
		_current_tint = desired
		_from_tint = desired
		_target_tint = desired
		_tint_t = 1.0
		_tint_ready = true
		return
	if not desired.is_equal_approx(_target_tint):
		_from_tint = _current_tint
		_target_tint = desired
		_tint_t = 0.0
	if _tint_t < 1.0 and dt > 0.0:
		_tint_t = minf(1.0, _tint_t + dt / TINT_LERP_S)
		_current_tint = _from_tint.lerp(_target_tint, _tint_t * _tint_t * (3.0 - 2.0 * _tint_t))

func _tick_burst_lights(dt: float) -> void:
	if dt <= 0.0 or _burst_lights.is_empty():
		return
	for i: int in range(_burst_lights.size() - 1, -1, -1):
		var b: Dictionary = _burst_lights[i]
		var age: float = float(b["age"]) + dt
		if age >= float(b["dur"]):
			_burst_lights.remove_at(i)
		else:
			b["age"] = age

func _append_player_lights(lights: PackedVector4Array, flicker: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var p_pos: Vector2 = _player_pos()
	var lantern_out: bool = false
	var lan_pos: Vector2 = p_pos
	var custom_r: float = -1.0
	var lan_node: Variant = Lx.player.get("lantern")
	if lan_node != null and lan_node is Object and is_instance_valid(lan_node):
		var lo: Object = lan_node as Object
		lantern_out = bool(lo.call("is_out")) if lo.has_method("is_out") else (not bool(lo.get("is_held")) if lo.get("is_held") != null else false)
		if lo.has_method("get_light_radius"):
			custom_r = float(lo.call("get_light_radius"))
		if lantern_out:
			lan_pos = lo.get("pos") as Vector2 if lo.get("pos") is Vector2 else ((lo as Node2D).global_position if lo is Node2D else p_pos)
	var has_lens: bool = Lx.state != null and is_instance_valid(Lx.state) and Lx.state.has_move("lens")
	if not lantern_out:
		var base_hand: float = maxf(108.0 if has_lens else 96.0, custom_r)
		lights.append(Vector4(p_pos.x, p_pos.y - 8.0, base_hand * flicker, 1.35))
	else:
		lights.append(Vector4(p_pos.x, p_pos.y - 8.0, 42.0, 0.72))
		var base_hung: float = maxf(118.0 if has_lens else 86.0, custom_r)
		lights.append(Vector4(lan_pos.x, lan_pos.y - 6.0, base_hung * flicker, 1.38))

func _player_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player is Node2D:
			return (Lx.player as Node2D).global_position
		if Lx.player.has_method("get_pos"):
			return Lx.player.call("get_pos") as Vector2
	return Lx.camera.global_position if (Lx.camera != null and is_instance_valid(Lx.camera)) else Vector2.ZERO

func _interactable_pos(id: String, fallback_kind: String = "") -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world):
		if not id.is_empty() and Lx.world.has_method("find_interactable"):
			var it: Variant = Lx.world.call("find_interactable", id)
			if it is Node2D and is_instance_valid(it):
				return (it as Node2D).global_position
		if not fallback_kind.is_empty() and Lx.world.has_method("get_interactables"):
			var arr: Variant = Lx.world.call("get_interactables")
			if arr is Array:
				for item: Variant in (arr as Array):
					if item is Node2D and is_instance_valid(item) and str((item as Object).get("kind")) == fallback_kind:
						return (item as Node2D).global_position
	return _player_pos()

func _boss_pos(boss_id: String) -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		var enemies: Variant = Lx.world.call("get_enemies")
		if enemies is Array:
			for e: Variant in (enemies as Array):
				if e is Node2D and is_instance_valid(e) and (str((e as Object).get("kind")) == boss_id or bool((e as Object).get("is_boss"))):
					return (e as Node2D).global_position
	return _player_pos()

func _on_enemy_killed(_e: Object, _k: String, pos: Vector2, opened: bool) -> void:
	add_burst_light(pos, 76.0 if opened else 54.0, 1.40 if opened else 1.05, 0.42 if opened else 0.26)
func _on_lantern_hung(pos: Vector2) -> void: add_burst_light(pos, 64.0, 1.22, 0.28)
func _on_lantern_caught(pos: Vector2) -> void: add_burst_light(pos, 56.0, 1.12, 0.22)
func _on_lantern_struck(pos: Vector2) -> void: add_burst_light(pos, 84.0, 1.48, 0.36)
func _on_beacon_lit(_i: int, bid: String) -> void: add_burst_light(_interactable_pos(bid, "beacon"), 124.0, 1.60, 0.68)
func _on_waystone_lit(_i: int, wid: String) -> void: add_burst_light(_interactable_pos(wid, "waystone"), 112.0, 1.50, 0.60)
func _on_shrine_claimed(sid: String, _m: String) -> void: add_burst_light(_interactable_pos(sid, "shrine"), 118.0, 1.55, 0.64)
func _on_boss_phase_changed(bid: String, _p: int) -> void: add_burst_light(_boss_pos(bid), 112.0, 1.52, 0.56)
func _on_boss_defeated(bid: String, _i: int) -> void: add_burst_light(_boss_pos(bid), 144.0, 1.72, 0.75)
func _on_great_lamp_relit(_i: int) -> void: add_burst_light(_interactable_pos("great_lamp", "great_lamp"), 154.0, 1.80, 0.75)
func _on_ember_piece(_total: int) -> void: add_burst_light(_player_pos(), 96.0, 1.45, 0.52)
func _on_upgrade_purchased(_id: String, _rank: int) -> void: add_burst_light(_player_pos(), 108.0, 1.50, 0.55)
