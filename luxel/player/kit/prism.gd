class_name LxMovePrism
extends LxMove
## Prism (Island 2, passive): Light Bolts bounce off brass LxMirrors and glass tiles
## along the exact physical reflection vector (ZERO auto-aim), upgrading to SOURCE_PRISM,
## scaling damage by damage_mult (1.15), refreshing range, and spawning gold sparks.

var bounces_count: int = 0


func can_use() -> bool:
	return unlocked and wick != null and not wick.dead


func get_bounces() -> int:
	if not unlocked:
		return 0
	if Lx.state != null:
		return maxi(1, Lx.state.get_effective_prism_bounces())
	return maxi(1, int(get_data().get("bounces", 1)))


func get_damage_mult() -> float:
	return float(get_data().get("damage_mult", 1.15))


func get_range_refresh() -> float:
	return float(get_data().get("range_refresh", 118.0))


func try_reflect_interactable(item: Object, from_p: Vector2, to_p: Vector2, in_dir: Vector2) -> Dictionary:
	if item == null or not is_instance_valid(item) or in_dir.length_squared() <= 0.0001:
		return {"hit": false}
	var dir_n: Vector2 = in_dir.normalized()
	var ipos: Vector2 = wick.get_entity_pos(item) if wick != null else to_p
	var seg_pt: Vector2 = Geometry2D.get_closest_point_to_segment(ipos, from_p, to_p)
	var rpos: Vector2 = seg_pt
	var rdir: Vector2 = Vector2.ZERO

	# 1. Explicit reflect_bolt(pos, dir) hook (returns reflected Vector2 or Dictionary)
	if item.has_method("reflect_bolt"):
		var rinfo: Variant = item.call("reflect_bolt", seg_pt, dir_n)
		if rinfo is Vector2:
			var rv: Vector2 = rinfo as Vector2
			if rv.length_squared() > 0.0001:
				rdir = rv.normalized()
		elif rinfo is Dictionary:
			var rd: Dictionary = rinfo as Dictionary
			if bool(rd.get("hit", false)):
				var rv: Vector2 = rd.get("dir", Vector2.ZERO) as Vector2
				if rv.length_squared() > 0.0001:
					rdir = rv.normalized()
					rpos = rd.get("pos", seg_pt) as Vector2

	# 2. Brass LxMirror contract: is_reflective() + reflect_dir(in_dir)
	if rdir.length_squared() <= 0.0001 and item.has_method("is_reflective") \
			and bool(item.call("is_reflective")) and item.has_method("reflect_dir"):
		var rv2: Variant = item.call("reflect_dir", dir_n)
		if rv2 is Vector2 and (rv2 as Vector2).length_squared() > 0.0001:
			rdir = (rv2 as Vector2).normalized()
			rpos = _mirror_plane_hit(item, ipos, from_p, dir_n, seg_pt)

	if rdir.length_squared() <= 0.0001:
		return {"hit": false}

	var exit_pos: Vector2 = _compute_exit_pos(item, rpos, rdir)
	return {"hit": true, "pos": rpos, "exit_pos": exit_pos, "dir": rdir}


func try_reflect_world(world_ctx: Node, from_p: Vector2, to_p: Vector2, in_dir: Vector2) -> Dictionary:
	if world_ctx == null or wick == null or in_dir.length_squared() <= 0.0001:
		return {"hit": false}
	var dir_n: Vector2 = in_dir.normalized()

	# 1. Custom world mirror hook if provided by a lab or scene
	var mhit: Dictionary = wick.world_get_mirror_hit(world_ctx, from_p, to_p)
	if bool(mhit.get("hit", false)):
		var hpos: Vector2 = mhit.get("pos", to_p) as Vector2
		var rdir_v: Variant = mhit.get("dir", Vector2.ZERO)
		var rdir: Vector2 = Vector2.ZERO
		if rdir_v is Vector2 and (rdir_v as Vector2).length_squared() > 0.0001:
			rdir = (rdir_v as Vector2).normalized()
		else:
			var n: Vector2 = mhit.get("normal", -dir_n) as Vector2
			rdir = dir_n.bounce(n.normalized()).normalized() if n.length_squared() > 0.0001 else -dir_n
		return {"hit": true, "pos": hpos, "exit_pos": hpos + rdir * 2.0, "dir": rdir}

	# 2. Glass / mirror tile reflection in LxRegionLoader .map grid
	if not world_ctx.has_method("tile_at"):
		return {"hit": false}
	var ttype: String = str(world_ctx.call("tile_at", to_p))
	if ttype != "glass" and ttype != "mirror":
		return {"hit": false}

	var ts_v: Variant = world_ctx.get("tile_size")
	var ts: float = float(ts_v) if (ts_v is int or ts_v is float) and float(ts_v) > 0.0 else float(LxMapFormat.DEFAULT_TILE_SIZE)
	var tx: int = int(floor(to_p.x / ts))
	var ty: int = int(floor(to_p.y / ts))
	var rect := Rect2(float(tx) * ts, float(ty) * ts, ts, ts)
	var hit_info: Dictionary = _ray_enter_rect(from_p, to_p, rect)
	var hit_pos: Vector2 = hit_info.get("pos", from_p) as Vector2
	var normal: Vector2 = hit_info.get("normal", -dir_n) as Vector2
	if normal.length_squared() <= 0.0001:
		normal = -dir_n
	var reflected_dir: Vector2 = dir_n.bounce(normal.normalized()).normalized()
	var exit_pos: Vector2 = hit_pos + reflected_dir * 2.0
	if rect.grow(0.5).has_point(exit_pos):
		exit_pos = hit_pos + normal.normalized() * 2.0
	return {"hit": true, "pos": hit_pos, "exit_pos": exit_pos, "dir": reflected_dir}


func on_bolt_reflected(at_pos: Vector2, out_dir: Vector2, chain_count: int = 1) -> void:
	bounces_count += 1
	if wick == null:
		return
	var isl_p: int = Lx.state.island_id if Lx.state != null else 1
	wick.spawn_sparks(at_pos, out_dir, 6, LxWick.PAL_GOLD, 35.0, 90.0, 0.18)
	wick.spawn_sparks(at_pos, out_dir, 2, LxWick.PAL_CREAM, 65.0, 115.0, 0.13)
	wick.spawn_ring(at_pos, 2.0, 11.0, 0.18, LxBiomePalette.col(isl_p, "glow"), 1.0)
	wick.spawn_ring(at_pos, 1.0, 7.0, 0.11, LxWick.PAL_CREAM, 1.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var bi_r: float = (0.92 if chain_count >= 2 else 0.72) if LxHudFx.flash_reduced() else (1.42 if chain_count >= 2 else 1.12)
		LxDarknessLayer.active_instance.add_burst_light(at_pos, 48.0 if chain_count >= 2 else 36.0, bi_r, 0.20)
	if chain_count >= 2:
		wick.spawn_sparks(at_pos, out_dir, 4, LxWick.PAL_ICE, 45.0, 110.0, 0.22)
		wick.spawn_ring(at_pos, 3.0, 15.0, 0.22, LxWick.PAL_ICE, 1.2)
		wick.emit_sfx("prism_chain", at_pos, true)
	else:
		wick.emit_sfx("prism_bounce", at_pos, true)


func reset() -> void:
	super.reset()
	bounces_count = 0


func _mirror_plane_hit(item: Object, ipos: Vector2, from_p: Vector2, dir_n: Vector2, fallback: Vector2) -> Vector2:
	var nv: Variant = item.get("normal")
	if not (nv is Vector2) or (nv as Vector2).length_squared() <= 0.0001:
		return fallback
	var n: Vector2 = (nv as Vector2).normalized()
	var denom: float = dir_n.dot(n)
	if absf(denom) <= 0.0001:
		return fallback
	var t: float = (ipos - from_p).dot(n) / denom
	if t < 0.0:
		return fallback
	var plane_pt: Vector2 = from_p + dir_n * t
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area() and srect.grow(2.5).has_point(plane_pt):
			return plane_pt
	elif plane_pt.distance_to(ipos) <= 12.0:
		return plane_pt
	return fallback


func _compute_exit_pos(item: Object, rpos: Vector2, rdir: Vector2) -> Vector2:
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area():
			var grown: Rect2 = srect.grow(0.5)
			if grown.has_point(rpos):
				var t_exit: float = _ray_exit_rect(rpos, rdir, grown)
				return rpos + rdir * (t_exit + 1.5)
	return rpos + rdir * 2.0


static func _ray_exit_rect(origin: Vector2, dir_n: Vector2, rect: Rect2) -> float:
	var t_max: float = INF
	if absf(dir_n.x) > 0.0001:
		var tx: float = (rect.end.x - origin.x) / dir_n.x if dir_n.x > 0.0 else (rect.position.x - origin.x) / dir_n.x
		if tx >= 0.0:
			t_max = minf(t_max, tx)
	if absf(dir_n.y) > 0.0001:
		var ty: float = (rect.end.y - origin.y) / dir_n.y if dir_n.y > 0.0 else (rect.position.y - origin.y) / dir_n.y
		if ty >= 0.0:
			t_max = minf(t_max, ty)
	return 2.0 if t_max == INF else t_max


static func _ray_enter_rect(from_p: Vector2, to_p: Vector2, rect: Rect2) -> Dictionary:
	var delta: Vector2 = to_p - from_p
	var t_min: float = 0.0
	var t_max: float = 1.0
	var hit_normal: Vector2 = Vector2.ZERO

	if absf(delta.x) > 0.0001:
		var inv_x: float = 1.0 / delta.x
		var tx1: float = (rect.position.x - from_p.x) * inv_x
		var tx2: float = (rect.end.x - from_p.x) * inv_x
		var nx: float = -1.0 if delta.x > 0.0 else 1.0
		if tx1 > tx2:
			var tmp: float = tx1
			tx1 = tx2
			tx2 = tmp
		if tx1 > t_min:
			t_min = tx1
			hit_normal = Vector2(nx, 0.0)
		t_max = minf(t_max, tx2)

	if absf(delta.y) > 0.0001:
		var inv_y: float = 1.0 / delta.y
		var ty1: float = (rect.position.y - from_p.y) * inv_y
		var ty2: float = (rect.end.y - from_p.y) * inv_y
		var ny: float = -1.0 if delta.y > 0.0 else 1.0
		if ty1 > ty2:
			var tmp2: float = ty1
			ty1 = ty2
			ty2 = tmp2
		if ty1 > t_min:
			t_min = ty1
			hit_normal = Vector2(0.0, ny)
		t_max = minf(t_max, ty2)

	if hit_normal.length_squared() <= 0.0001:
		var rel: Vector2 = from_p - rect.get_center()
		if absf(rel.x) >= absf(rel.y):
			hit_normal = Vector2(signf(rel.x) if absf(rel.x) > 0.01 else -signf(delta.x), 0.0)
		else:
			hit_normal = Vector2(0.0, signf(rel.y) if absf(rel.y) > 0.01 else -signf(delta.y))
		return {"pos": from_p, "normal": hit_normal}

	return {"pos": from_p + delta * clampf(t_min, 0.0, 1.0), "normal": hit_normal}
