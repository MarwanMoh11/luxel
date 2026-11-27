class_name LxFields
extends RefCounted
## Spatial force fields (gravity wells, polarity wells, wind zones) that bend projectiles,
## lantern throws, beams, Wick, enemies, and loose blocks deterministically.
## Frozen API (CONTRACTS.md): add(f), remove(f), clear(), has_fields(), get_all(),
## accel_at(p, what), sample_curve(...).

const MAX_ACCEL: float = 2400.0
const SIM_DT: float = 1.0 / 60.0
const BEAM_STEP_PX: float = 2.0

static var _fields: Array[Object] = []


static func add(f: Object) -> void:
	if f == null or not is_instance_valid(f):
		return
	if not _fields.has(f):
		_fields.append(f)


static func remove(f: Object) -> void:
	var idx: int = _fields.find(f)
	if idx >= 0:
		_fields.remove_at(idx)


static func clear() -> void:
	_fields.clear()


static func has_fields() -> bool:
	if _fields.is_empty():
		return false
	for i: int in range(_fields.size() - 1, -1, -1):
		var f: Object = _fields[i]
		if f == null or not is_instance_valid(f):
			_fields.remove_at(i)
	return not _fields.is_empty()


static func get_all() -> Array[Object]:
	var out: Array[Object] = []
	for i: int in range(_fields.size() - 1, -1, -1):
		var f: Object = _fields[i]
		if f == null or not is_instance_valid(f):
			_fields.remove_at(i)
		else:
			out.append(f)
	return out


## Returns combined acceleration (px/s^2) at world position `p` for `what` in:
## "bolt", "lantern", "beam", "wick", "enemy", "block".
static func accel_at(p: Vector2, what: String) -> Vector2:
	if _fields.is_empty() or not p.is_finite():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for i: int in range(_fields.size() - 1, -1, -1):
		var f: Object = _fields[i]
		if f == null or not is_instance_valid(f):
			_fields.remove_at(i)
			continue
		if f.has_method("is_field_active") and not bool(f.call("is_field_active")):
			continue
		if f.has_method("field_accel"):
			var a_v: Variant = f.call("field_accel", p, what)
			if a_v is Vector2:
				var a: Vector2 = a_v as Vector2
				if a.is_finite():
					total += a
	var mag_sq: float = total.length_squared()
	if not is_finite(mag_sq) or mag_sq <= 0.000001:
		return Vector2.ZERO
	if mag_sq > MAX_ACCEL * MAX_ACCEL:
		total = total.normalized() * MAX_ACCEL
	return total


## Finds the nearest active gravity/polarity well that can capture a tangential lantern throw.
static func find_orbit_capture_well(p: Vector2, move_dir: Vector2) -> Object:
	if _fields.is_empty() or not p.is_finite() or move_dir.length_squared() <= 0.0001:
		return null
	var best: Object = null
	var best_d2: float = INF
	for i: int in range(_fields.size() - 1, -1, -1):
		var f: Object = _fields[i]
		if f == null or not is_instance_valid(f):
			_fields.remove_at(i)
			continue
		if f.has_method("can_capture_orbit") and bool(f.call("can_capture_orbit", p, move_dir)):
			var fp: Variant = f.get("pos")
			if fp is Vector2:
				var d2: float = p.distance_squared_to(fp as Vector2)
				if d2 < best_d2:
					best_d2 = d2
					best = f
	return best


## Finds the nearest active radial well within `max_dist` of `p` (for extended honest aim preview).
static func nearest_active_well(p: Vector2, max_dist: float = 180.0) -> Object:
	if _fields.is_empty() or not p.is_finite():
		return null
	var best: Object = null
	var best_d2: float = max_dist * max_dist
	for i: int in range(_fields.size() - 1, -1, -1):
		var f: Object = _fields[i]
		if f == null or not is_instance_valid(f):
			_fields.remove_at(i)
			continue
		if f.has_method("is_field_active") and not bool(f.call("is_field_active")):
			continue
		var fr_v: Variant = f.get("field_radius")
		var fp_v: Variant = f.get("pos")
		if (fr_v is float or fr_v is int) and fp_v is Vector2:
			var d2: float = p.distance_squared_to(fp_v as Vector2)
			if d2 <= best_d2:
				best_d2 = d2
				best = f
	return best


## Deterministic fixed-step trajectory preview matching bolt.gd / beam_trace.gd / lantern.gd.
## Same input ALWAYS produces the exact same curve; stops honestly at walls and solid baffles.
## Returns {points: PackedVector2Array, bent: bool, curve_angle_deg: float, hit_wall: bool, end_dir: Vector2}.
static func sample_curve(
	origin: Vector2,
	dir: Vector2,
	speed: float,
	what: String = "bolt",
	max_dist: float = 60.0,
	step_px: float = 4.0,
	world_ctx: Node = null
) -> Dictionary:
	var pts := PackedVector2Array()
	if not origin.is_finite() or dir.length_squared() <= 0.0001 or max_dist <= 0.0:
		return {"points": pts, "bent": false, "curve_angle_deg": 0.0, "hit_wall": false, "end_dir": Vector2.RIGHT}

	var cur_p: Vector2 = origin
	var cur_d: Vector2 = dir.normalized()
	var base_spd: float = maxf(20.0, speed)
	var cur_spd: float = base_spd
	var record_gap: float = maxf(1.5, step_px)
	var traveled: float = 0.0
	var since_record: float = 0.0
	var bent: bool = false
	var curve_angle_deg: float = 0.0
	var hit_wall: bool = false

	var has_tile: bool = world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("tile_at")
	var blockers: Array[Rect2] = _collect_sight_blockers(world_ctx)
	var is_beam: bool = (what == "beam")
	var is_bolt: bool = (what == "bolt")

	pts.append(cur_p)
	var guard: int = 0
	while traveled < max_dist and guard < 400:
		guard += 1
		var old_d: Vector2 = cur_d
		var dt_s: float = (minf(BEAM_STEP_PX, max_dist - traveled) / cur_spd) if is_beam else SIM_DT
		var fa: Vector2 = accel_at(cur_p, what)
		if fa.length_squared() > 0.01:
			bent = true
			var v: Vector2 = cur_d * cur_spd + fa * dt_s
			if v.length_squared() > 1.0:
				cur_d = v.normalized()
				curve_angle_deg += rad_to_deg(absf(old_d.angle_to(cur_d)))
				if is_bolt:
					cur_spd = clampf(v.length(), base_spd * 0.72, base_spd * 1.40)

		var ds: float = minf(cur_spd * dt_s, max_dist - traveled)
		var nxt: Vector2 = cur_p + cur_d * ds
		if _segment_blocked(cur_p, nxt, has_tile, world_ctx, blockers):
			hit_wall = true
			if cur_p.distance_squared_to(pts[pts.size() - 1]) > 0.25:
				pts.append(cur_p)
			break

		cur_p = nxt
		traveled += ds
		since_record += ds
		if since_record >= record_gap or traveled >= max_dist - 0.01:
			pts.append(cur_p)
			since_record = 0.0

	return {
		"points": pts,
		"bent": bent,
		"curve_angle_deg": curve_angle_deg,
		"hit_wall": hit_wall,
		"end_dir": cur_d,
	}


static func _collect_sight_blockers(world_ctx: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return out
	var inters: Variant = world_ctx.call("get_interactables")
	if not (inters is Array):
		return out
	for it_v: Variant in (inters as Array):
		if not is_instance_valid(it_v) or not (it_v is Object):
			continue
		var item: Object = it_v as Object
		if item.get("active") == false:
			continue
		if not (item.has_method("is_solid") and bool(item.call("is_solid"))):
			continue
		if not (item.has_method("blocks_sight") and bool(item.call("blocks_sight"))):
			continue
		var k: String = str(item.get("kind"))
		if k in ["bramble", "web", "cracked_wall", "obsidian_seal"]:
			continue
		if item.has_method("get_solid_rect"):
			var r: Rect2 = item.call("get_solid_rect") as Rect2
			if r.has_area():
				out.append(r)
	return out


static func _segment_blocked(a: Vector2, b: Vector2, has_tile: bool, world_ctx: Node, blockers: Array[Rect2]) -> bool:
	var mid: Vector2 = a.lerp(b, 0.5)
	if has_tile:
		if LxMapFormat.blocks_sight_tile(str(world_ctx.call("tile_at", b))):
			return true
		if LxMapFormat.blocks_sight_tile(str(world_ctx.call("tile_at", mid))):
			return true
	for r: Rect2 in blockers:
		if r.has_point(b) or r.has_point(mid):
			return true
	return false
