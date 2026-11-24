class_name LxRingWave
extends Node2D
## Expanding acoustic ring wave emitted by LxBell (tones: "dawn" | "dusk" | "war").
## Fixed speed, stopped by walls & acoustic baffles via 72-ray radial occlusion plus exact segment
## occlusion checks, touches each listener once, calls `on_ring(tone, dir)` on interactables and
## enemies, and notifies Island 1's rule engine for universal Dusk freeze / War shatter / Dawn wake.

const RAY_COUNT: int = 72
const RAY_STEP: float = 4.0

var origin: Vector2 = Vector2.ZERO
var tone: String = "dawn"
var speed: float = 135.0
var max_radius: float = 176.0
var radius: float = 4.0
var prev_radius: float = 0.0
var done: bool = false
var source_id: String = ""
var is_echo: bool = false
var chain_ids: PackedStringArray = PackedStringArray()
var region: Node = null

var _ray_limits: PackedFloat32Array = PackedFloat32Array()
var _touched_ids: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2


func setup(
	p_origin: Vector2,
	p_tone: String,
	p_region: Node,
	p_speed: float = 135.0,
	p_max_r: float = 176.0,
	p_source_id: String = "",
	p_is_echo: bool = false,
	p_chain: PackedStringArray = PackedStringArray()
) -> void:
	origin = p_origin
	position = origin.round()
	tone = p_tone.strip_edges().to_lower()
	if tone not in ["dawn", "dusk", "war"]:
		tone = "dawn"
	region = p_region
	speed = maxf(24.0, p_speed)
	max_radius = maxf(24.0, p_max_r)
	source_id = p_source_id
	is_echo = p_is_echo
	chain_ids = p_chain.duplicate()
	if not source_id.is_empty() and not chain_ids.has(source_id):
		chain_ids.append(source_id)
	radius = 4.0
	prev_radius = 0.0
	done = false
	_touched_ids.clear()
	_compute_radial_occlusion()
	queue_redraw()


func _compute_radial_occlusion() -> void:
	_ray_limits.resize(RAY_COUNT)
	for i: int in range(RAY_COUNT):
		var a: float = (TAU * float(i)) / float(RAY_COUNT)
		var dir := Vector2(cos(a), sin(a))
		var dist: float = 0.0
		var limit: float = max_radius
		while dist < max_radius:
			dist += RAY_STEP
			var pt: Vector2 = origin + dir * dist
			if _is_wall_at(pt):
				limit = maxf(4.0, dist - RAY_STEP * 0.5)
				break
		_ray_limits[i] = limit


func _is_wall_at(pt: Vector2, ignore_obj: Object = null) -> bool:
	if region == null or not is_instance_valid(region):
		return false
	if region.has_method("tile_at"):
		var tt: String = str(region.call("tile_at", pt))
		if LxMapFormat.blocks_sight_tile(tt):
			return true
	if region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active or it == ignore_obj:
				continue
			if not source_id.is_empty() and it.id == source_id:
				continue
			if it.kind in ["tone_door", "bell", "cracked_wall", "tone_coffin"]:
				continue
			if it.blocks_sight() and it.get_solid_rect().has_point(pt):
				return true
	return false


func is_occluded_to(target_pos: Vector2, target_rad: float, target_obj: Object = null) -> bool:
	var rel: Vector2 = target_pos - origin
	var dist: float = rel.length()
	if dist <= maxf(4.0, target_rad + 2.0):
		return false
	var dir: Vector2 = rel / dist
	var stop_at: float = maxf(0.0, dist - maxf(2.0, target_rad * 0.65))
	var d: float = RAY_STEP
	while d < stop_at:
		if _is_wall_at(origin + dir * d, target_obj):
			return true
		d += RAY_STEP
	return false


func occlusion_limit_at_angle(ang: float) -> float:
	if _ray_limits.size() != RAY_COUNT:
		return max_radius
	var u: float = fposmod(ang, TAU) / TAU * float(RAY_COUNT)
	var i0: int = int(floorf(u)) % RAY_COUNT
	var i1: int = (i0 + 1) % RAY_COUNT
	var f: float = u - floorf(u)
	return lerpf(_ray_limits[i0], _ray_limits[i1], f)


func tick(dt: float) -> void:
	if done or dt <= 0.0:
		return
	prev_radius = radius
	radius += speed * dt
	_deliver_rings()
	if radius >= max_radius:
		done = true
	queue_redraw()


func _deliver_rings() -> void:
	if region == null or not is_instance_valid(region):
		return
	if region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is Object) or not is_instance_valid(it_v as Object):
				continue
			var obj: Object = it_v as Object
			if obj.get("id") is String:
				var oid_s: String = str(obj.get("id"))
				if not oid_s.is_empty() and (oid_s == source_id or chain_ids.has(oid_s)):
					continue
			if obj.get("active") is bool and not bool(obj.get("active")):
				continue
			var opos: Vector2 = obj.get("pos") as Vector2 if obj.get("pos") is Vector2 else (
				(obj as Node2D).global_position if obj is Node2D else Vector2.INF
			)
			if not opos.is_finite():
				continue
			var orad: float = float(obj.get("radius")) if (obj.get("radius") is float or obj.get("radius") is int) else 8.0
			_try_touch_listener(obj, opos, orad, false)
	if region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if not (e_v is Object) or not is_instance_valid(e_v as Object):
				continue
			var e: Object = e_v as Object
			if e.has_method("is_alive") and not bool(e.call("is_alive")):
				continue
			if e is CanvasItem and not (e as CanvasItem).visible:
				continue
			var epos: Vector2 = e.get("pos") as Vector2 if e.get("pos") is Vector2 else (
				(e as Node2D).global_position if e is Node2D else Vector2.INF
			)
			if not epos.is_finite():
				continue
			var erad: float = float(e.get("body_radius")) if (e.get("body_radius") is float or e.get("body_radius") is int) else 6.0
			_try_touch_listener(e, epos, erad, true)


func _try_touch_listener(listener: Object, target_pos: Vector2, target_rad: float, is_enemy: bool) -> void:
	var oid: int = listener.get_instance_id()
	if _touched_ids.has(oid):
		return
	var rel: Vector2 = target_pos - origin
	var dist: float = rel.length()
	var hit_min: float = maxf(0.0, prev_radius - target_rad - 2.0)
	var hit_max: float = radius + target_rad + 2.0
	if dist < hit_min or dist > hit_max:
		return
	var dir: Vector2 = rel / dist if dist > 0.01 else Vector2.RIGHT
	if is_occluded_to(target_pos, target_rad, listener):
		return
	_touched_ids[oid] = true
	var handled: bool = false
	if listener.has_method("on_ring_wave"):
		listener.call("on_ring_wave", self, tone, dir)
		handled = true
	elif listener.has_method("on_ring"):
		listener.call("on_ring", tone, dir)
		handled = true
	if region != null and region.has_method("notify"):
		region.call("notify", "ring_touch", {
			"tone": tone, "target": listener, "dir": dir, "origin": origin,
			"source_id": source_id, "is_echo": is_echo, "is_enemy": is_enemy, "handled": handled,
		})


func _draw() -> void:
	if done or _ray_limits.size() != RAY_COUNT:
		return
	var fade: float = clampf(1.0 - radius / maxf(max_radius, 1.0), 0.0, 1.0)
	var red: bool = LxHudFx.flash_reduced()
	var trip: Array[Color] = LxToyDraw.color_triplet(tone)
	var c_outer: Color = Color(trip[0], fade * (0.55 if red else 0.80))
	var c_core: Color = Color(trip[2], fade * (0.72 if red else 0.96))
	var c_cream: Color = Color(LxPalette.PAL["cream"] as Color, fade * (0.65 if red else 0.92))

	for i: int in range(RAY_COUNT):
		var lim0: float = _ray_limits[i]
		var lim1: float = _ray_limits[(i + 1) % RAY_COUNT]
		if radius > lim0 + 2.0 and radius > lim1 + 2.0:
			continue
		var r0: float = minf(radius, lim0)
		var r1: float = minf(radius, lim1)
		var a0: float = (TAU * float(i)) / float(RAY_COUNT)
		var a1: float = (TAU * float(i + 1)) / float(RAY_COUNT)
		var p0 := Vector2(roundf(cos(a0) * r0), roundf(sin(a0) * r0))
		var p1 := Vector2(roundf(cos(a1) * r1), roundf(sin(a1) * r1))
		# Greyscale-distinct silhouettes per tone:
		# Dusk = dashed ice line + perpendicular frost ticks; War = jagged spikes; Dawn = solid bright ring + pips
		if tone == "dusk" and (i / 2) % 2 == 1:
			continue
		draw_line(p0, p1, c_outer, 2.0 if not red else 1.0, false)
		draw_line(p0, p1, c_core, 1.0, false)
		if is_echo and r0 > 7.0 and r1 > 7.0:
			var e0 := Vector2(roundf(cos(a0) * (r0 - 4.0)), roundf(sin(a0) * (r0 - 4.0)))
			var e1 := Vector2(roundf(cos(a1) * (r1 - 4.0)), roundf(sin(a1) * (r1 - 4.0)))
			draw_line(e0, e1, Color(trip[1], fade * 0.65), 1.0, false)
		if tone == "war" and i % 4 == 0:
			var spk := Vector2(roundf(cos(a0) * (r0 + 4.0)), roundf(sin(a0) * (r0 + 4.0)))
			draw_line(p0, spk, c_cream, 1.0, false)
		elif tone == "dusk" and i % 6 == 0:
			var tk0 := Vector2(roundf(cos(a0) * maxf(2.0, r0 - 2.0)), roundf(sin(a0) * maxf(2.0, r0 - 2.0)))
			var tk1 := Vector2(roundf(cos(a0) * (r0 + 2.0)), roundf(sin(a0) * (r0 + 2.0)))
			draw_line(tk0, tk1, c_cream, 1.0, false)
		elif tone == "dawn" and i % 6 == 0:
			draw_rect(Rect2(p0, Vector2(2.0, 2.0)), c_cream)
