class_name LxBeamTrace
extends RefCounted
## Ray/polyline beam tracer with mirror/glass reflection AND deterministic LxFields curvature.
## Extracted from luxel/player/kit/beam.gd so both files stay well under 600 lines.

const RAY_STEP_PX: float = 2.0
const BEAM_FIELD_SPEED: float = 330.0
const CURVE_SPLIT_RAD: float = 0.045
const CURVE_MAX_SEG_PX: float = 12.0


static func trace_segments(
	wick: LxWick,
	ctx: Node,
	origin: Vector2,
	aim_dir: Vector2,
	max_range: float,
	max_bounces: int,
	reflections_out: Array[Dictionary] = []
) -> Array[Dictionary]:
	var segs: Array[Dictionary] = []
	var cur_pos: Vector2 = origin
	var cur_dir: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else Vector2.RIGHT
	var cur_color: String = LxHit.COLOR_YELLOW
	var ignore_mirror_id: int = -1
	var bounces_done: int = 0
	var has_tile_at: bool = ctx != null and ctx.has_method("tile_at")
	var has_is_wall: bool = ctx != null and ctx.has_method("is_wall")
	var can_reflect: bool = wick != null and wick.move_prism != null
	var use_fields: bool = LxFields.has_fields()
	var curve_angle_deg: float = 0.0

	var mirrors: Array[Object] = []
	var solid_blockers: Array[Rect2] = []
	if wick != null:
		for it_var: Variant in wick.world_get_interactables(ctx):
			if not is_instance_valid(it_var) or not (it_var is Object):
				continue
			var item: Object = it_var as Object
			if item.get("active") is bool and not bool(item.get("active")):
				continue
			if item.has_method("is_reflective") and bool(item.call("is_reflective")):
				mirrors.append(item)
			elif item.has_method("is_solid") and bool(item.call("is_solid")) \
					and item.has_method("blocks_sight") and bool(item.call("blocks_sight")) \
					and item.has_method("get_solid_rect"):
				var ikind: String = str(item.get("kind"))
				if ikind in ["bramble", "web", "cracked_wall", "obsidian_seal"]:
					continue
				var srect: Rect2 = item.call("get_solid_rect") as Rect2
				if srect.has_area():
					solid_blockers.append(srect)

	while bounces_done <= max_bounces:
		var dist: float = 0.0
		var seg_start: Vector2 = cur_pos
		var seg_dir0: Vector2 = cur_dir
		var seg_len: float = 0.0
		var prev_p: Vector2 = cur_pos
		var seg_end: Vector2 = cur_pos
		var reflected: bool = false
		while dist < max_range:
			var step: float = minf(RAY_STEP_PX, max_range - dist)
			dist += step
			if use_fields:
				var fa: Vector2 = LxFields.accel_at(prev_p, "beam")
				if fa.length_squared() > 0.01:
					var old_dir: Vector2 = cur_dir
					var dt_step: float = step / BEAM_FIELD_SPEED
					var v_next: Vector2 = cur_dir * BEAM_FIELD_SPEED + fa * dt_step
					if v_next.length_squared() > 1.0:
						cur_dir = v_next.normalized()
						curve_angle_deg += rad_to_deg(absf(old_dir.angle_to(cur_dir)))
			var pt: Vector2 = (prev_p + cur_dir * step) if use_fields else (cur_pos + cur_dir * dist)
			var ttype: String = ""
			if has_tile_at:
				ttype = str(ctx.call("tile_at", pt))
				if ttype == "wall":
					seg_end = prev_p
					break
			elif has_is_wall:
				if bool(ctx.call("is_wall", pt)):
					seg_end = prev_p
					break

			var hit_m: Object = null
			for m: Object in mirrors:
				if m.get_instance_id() == ignore_mirror_id:
					continue
				if ray_hits_mirror(wick, prev_p, pt, m):
					hit_m = m
					break
			if hit_m != null:
				if can_reflect and bounces_done < max_bounces:
					var refl: Dictionary = wick.move_prism.try_reflect_interactable(hit_m, prev_p, pt, cur_dir)
					if bool(refl.get("hit", false)):
						var rpos: Vector2 = refl.get("pos", pt) as Vector2
						var exit_pos: Vector2 = refl.get("exit_pos", rpos) as Vector2
						var rdir: Vector2 = refl.get("dir", -cur_dir) as Vector2
						var t_col: String = str(hit_m.call("get_transform_color")) if hit_m.has_method("get_transform_color") else LxHit.COLOR_BLUE
						if t_col.is_empty():
							t_col = LxHit.COLOR_BLUE
						segs.append({"start": seg_start, "end": rpos, "dir": seg_dir0, "color": cur_color, "bounce": bounces_done, "curve_angle_deg": curve_angle_deg})
						reflections_out.append({"item": hit_m, "pos": rpos, "exit_pos": exit_pos, "dir": rdir, "color": t_col, "bounce": bounces_done + 1})
						cur_pos = exit_pos
						cur_dir = rdir
						cur_color = t_col
						ignore_mirror_id = hit_m.get_instance_id()
						bounces_done += 1
						reflected = true
						break
				seg_end = prev_p
				break

			var hit_solid: bool = false
			for srect_b: Rect2 in solid_blockers:
				if srect_b.has_point(pt):
					hit_solid = true
					break
			if hit_solid:
				seg_end = prev_p
				break

			if (ttype == "glass" or ttype == "mirror") and can_reflect and bounces_done < max_bounces:
				var wrefl: Dictionary = wick.move_prism.try_reflect_world(ctx, prev_p, pt, cur_dir)
				if bool(wrefl.get("hit", false)):
					var wpos: Vector2 = wrefl.get("pos", prev_p) as Vector2
					var wexit: Vector2 = wrefl.get("exit_pos", wpos) as Vector2
					var wdir: Vector2 = wrefl.get("dir", -cur_dir) as Vector2
					segs.append({"start": seg_start, "end": wpos, "dir": seg_dir0, "color": cur_color, "bounce": bounces_done, "curve_angle_deg": curve_angle_deg})
					reflections_out.append({"item": null, "pos": wpos, "exit_pos": wexit, "dir": wdir, "color": LxHit.COLOR_BLUE, "bounce": bounces_done + 1})
					cur_pos = wexit
					cur_dir = wdir
					cur_color = LxHit.COLOR_BLUE
					ignore_mirror_id = -1
					bounces_done += 1
					reflected = true
					break

			prev_p = pt
			seg_end = pt
			seg_len += step
			# Split curved beam into readable polyline segments when fields bend direction
			if use_fields and (absf(seg_dir0.angle_to(cur_dir)) >= CURVE_SPLIT_RAD or (seg_len >= CURVE_MAX_SEG_PX and seg_dir0.dot(cur_dir) < 0.9998)):
				segs.append({"start": seg_start, "end": pt, "dir": (pt - seg_start).normalized() if pt.distance_squared_to(seg_start) > 0.01 else cur_dir, "color": cur_color, "bounce": bounces_done, "curve_angle_deg": curve_angle_deg})
				seg_start = pt
				seg_dir0 = cur_dir
				seg_len = 0.0

		if not reflected:
			if seg_end.distance_squared_to(seg_start) > 0.01 or segs.is_empty():
				var fdir: Vector2 = (seg_end - seg_start).normalized() if seg_end.distance_squared_to(seg_start) > 0.01 else cur_dir
				segs.append({"start": seg_start, "end": seg_end, "dir": fdir, "color": cur_color, "bounce": bounces_done, "curve_angle_deg": curve_angle_deg})
			break

	return segs


static func ray_hits_mirror(wick: LxWick, prev_p: Vector2, pt: Vector2, item: Object) -> bool:
	var ipos: Vector2 = wick.get_entity_pos(item) if wick != null else Vector2.ZERO
	var irad: float = wick.get_entity_radius(item, 8.0) if wick != null else 8.0
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area():
			var grown: Rect2 = srect.grow(1.5)
			if grown.has_point(pt) or grown.has_point(prev_p.lerp(pt, 0.5)):
				return true
	return Geometry2D.get_closest_point_to_segment(ipos, prev_p, pt).distance_to(ipos) <= irad + 1.5


static func segment_hits_item(a: Vector2, b: Vector2, half_w: float, item: Object, ipos: Vector2, irad: float) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ipos, a, b)
	if closest.distance_to(ipos) <= irad + half_w:
		return true
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area():
			var grown: Rect2 = srect.grow(half_w)
			var steps: int = maxi(1, int(ceil(a.distance_to(b) / 6.0)))
			for i: int in range(steps + 1):
				if grown.has_point(a.lerp(b, float(i) / float(steps))):
					return true
	return false
