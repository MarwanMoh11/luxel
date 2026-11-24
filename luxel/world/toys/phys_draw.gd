class_name LxPhysDraw
extends RefCounted
## Shared pixel-art primitives and safe-physics helpers for E0-2 physics toys and vehicles.
## Strictly uses the 20-colour Last Light palette (LxPalette.PAL) and LxBiomePalette skins.

const PAL: Dictionary = LxInteractable.PAL


## Returns a z_index that draws below Wick (0) on painted maps or E0-1's -10 greybox layer,
## yet stays above legacy LxRegionLoader._draw() (0) on unpainted maps.
static func floor_z(region: Node, painted_z: int = -2) -> int:
	if region != null and is_instance_valid(region) and (region.get("_ground_sprite") != null or region.get("_greybox_ground") != null):
		return painted_z
	return 0


static func parse_path(raw: Variant, origin: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if raw is Array:
		for item: Variant in (raw as Array):
			var pt: Vector2 = LxMapFormat.to_vec2(item, Vector2.INF)
			if pt.is_finite():
				out.append(pt)
	if out.is_empty():
		out.append(origin)
	return out


static func draw_shadow_rect(c: CanvasItem, rect: Rect2, offset: Vector2 = Vector2(2.0, 2.0), alpha: float = 0.34) -> void:
	var r := Rect2((rect.position + offset).round(), rect.size.round())
	c.draw_rect(r, Color(PAL["void"] as Color, alpha))


static func draw_bevel_box(
	c: CanvasItem,
	rect: Rect2,
	base_c: Color,
	hi_c: Color,
	shade_c: Color,
	outline_c: Color = Color("0d0b1e"),
	rivet_c: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var w: float = r.size.x
	var h: float = r.size.y
	if w < 3.0 or h < 3.0:
		c.draw_rect(r, base_c)
		return
	c.draw_rect(r, outline_c)
	c.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, w - 2.0, h - 2.0), base_c)
	# Top & left crisp 1px highlight bevel
	c.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, w - 2.0, 1.0), hi_c)
	c.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, 1.0, h - 2.0), hi_c)
	# Bottom & right recessed shade bevel
	c.draw_rect(Rect2(r.position.x + 1.0, r.end.y - 2.0, w - 2.0, 1.0), shade_c)
	c.draw_rect(Rect2(r.end.x - 2.0, r.position.y + 2.0, 1.0, h - 3.0), shade_c)
	if rivet_c.a > 0.01 and w >= 10.0 and h >= 10.0:
		c.draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, 1.0, 1.0), rivet_c)
		c.draw_rect(Rect2(r.end.x - 3.0, r.position.y + 2.0, 1.0, 1.0), rivet_c)
		c.draw_rect(Rect2(r.position.x + 2.0, r.end.y - 3.0, 1.0, 1.0), rivet_c)
		c.draw_rect(Rect2(r.end.x - 3.0, r.end.y - 3.0, 1.0, 1.0), rivet_c)


static func draw_chevron(c: CanvasItem, center: Vector2, dir: Vector2, col: Color, shadow_col: Color = Color("0d0b1e"), arm: float = 3.0) -> void:
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	var p := Vector2(-d.y, d.x)
	var tip: Vector2 = (center + d * (arm * 0.6)).round()
	var wing_a: Vector2 = (center - d * (arm * 0.5) + p * arm).round()
	var wing_b: Vector2 = (center - d * (arm * 0.5) - p * arm).round()
	if shadow_col.a > 0.01:
		c.draw_line(wing_a + Vector2(0.0, 1.0), tip + Vector2(0.0, 1.0), shadow_col, 1.0)
		c.draw_line(wing_b + Vector2(0.0, 1.0), tip + Vector2(0.0, 1.0), shadow_col, 1.0)
	c.draw_line(wing_a, tip, col, 1.0)
	c.draw_line(wing_b, tip, col, 1.0)
	c.draw_rect(Rect2(tip, Vector2.ONE), col)


static func draw_track_line(c: CanvasItem, origin_world: Vector2, pts: Array[Vector2], rail_col: Color, tie_col: Color, end_col: Color, closed: bool = false) -> void:
	if pts.size() < 2:
		return
	var seg_count: int = pts.size() if closed else (pts.size() - 1)
	for i: int in range(seg_count):
		var a: Vector2 = (pts[i] - origin_world).round()
		var b: Vector2 = (pts[(i + 1) % pts.size()] - origin_world).round()
		c.draw_line(a, b, Color(PAL["void"] as Color, 0.55), 3.0)
		c.draw_line(a, b, rail_col, 1.0)
		var delta: Vector2 = b - a
		var dist: float = delta.length()
		if dist > 4.0:
			var d: Vector2 = delta / dist
			var perp := Vector2(-d.y, d.x)
			var cur: float = 4.0
			while cur < dist - 2.0:
				var tp: Vector2 = (a + d * cur).round()
				c.draw_line((tp - perp * 2.0).round(), (tp + perp * 2.0).round(), tie_col, 1.0)
				cur += 6.0
	for p: Vector2 in pts:
		var lp: Vector2 = (p - origin_world).round()
		c.draw_rect(Rect2(lp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), PAL["void"] as Color)
		c.draw_rect(Rect2(lp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), end_col)


static func is_tile_safe_land(region: Node, world_pos: Vector2) -> bool:
	if region == null or not is_instance_valid(region):
		return true
	if region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", world_pos)):
		return false
	if region.has_method("tile_at"):
		var tt: String = str(region.call("tile_at", world_pos))
		if tt in ["wall", "bramble", "cracked", "glass", "mirror", "water", "tide", "pit", "void", "phantom"]:
			return false
	return true


static func safe_eject_wick(wick: Node2D, solid_rect: Rect2, region: Node, ignore_id: String = "", push_hint: Vector2 = Vector2.ZERO) -> void:
	if wick == null or not is_instance_valid(wick) or not solid_rect.has_area():
		return
	var rad: float = 4.0
	var expanded: Rect2 = solid_rect.grow(rad - 0.5)
	if not expanded.has_point(wick.global_position):
		return
	var wpos: Vector2 = wick.global_position
	var candidates: Array[Vector2] = []
	if push_hint.length_squared() > 0.01:
		var pd: Vector2 = push_hint.normalized()
		candidates.append(wpos + pd * (maxf(solid_rect.size.x, solid_rect.size.y) * 0.5 + rad + 2.0))
	candidates.append(Vector2(solid_rect.position.x - rad - 1.5, wpos.y))
	candidates.append(Vector2(solid_rect.end.x + rad + 1.5, wpos.y))
	candidates.append(Vector2(wpos.x, solid_rect.position.y - rad - 1.5))
	candidates.append(Vector2(wpos.x, solid_rect.end.y + rad + 1.5))
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for cand: Vector2 in candidates:
		var resolved: Vector2 = cand
		if region != null and region.has_method("collide"):
			resolved = region.call("collide", cand, rad, false, false, ignore_id) as Vector2
		if expanded.has_point(resolved):
			continue
		if region != null and region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", resolved)):
			continue
		var d: float = resolved.distance_to(wpos)
		if d < best_d:
			best_d = d
			best = resolved
	if best.is_finite():
		wick.global_position = best
		if wick.get("last_pos") is Vector2:
			wick.set("last_pos", best)
		return
	var safe_v: Variant = wick.get("_last_safe_pos")
	if safe_v is Vector2 and (safe_v as Vector2) != Vector2.ZERO and not expanded.has_point(safe_v as Vector2):
		wick.global_position = safe_v as Vector2
		if wick.get("last_pos") is Vector2:
			wick.set("last_pos", safe_v as Vector2)
