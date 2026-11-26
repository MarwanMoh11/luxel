class_name LxDewLens
extends LxToy
## Island 3 tiny-world 16x16 dewdrop water lens.
## - Liquid state: hold-E rolls smoothly along `rail_axis` ("free"|"x"|"y"|"none"). Yellow bolt/beam focuses
##   through the droplet into a distinct 6 px `"dew_ray"` (source="dew_ray", bounces off blue_transformers & glass
##   up to 5 times for Lantern-Jar starbursts) that burns `dry_root_knot`s, cracks enemy armor, blooms `light_plant`s
##   2x, and NEVER cracks big-world `cracked_wall`s.
## - Frozen state: Blue hit freezes the droplet for `frozen_secs` into a faceted 3-way Prism splitter (-20/0/+20 deg)!
## Props: movable (bool, true), rail_axis ("free"|"x"|"y"|"none"), focus_range (float, 140.0),
## frozen_secs (float, 10.0), max_bounces (int, 5), persist (bool), target_id/target_ids.

const SOURCE_DEW_RAY: String = "dew_ray"
const RAY_WIDTH_PX: float = 6.0
const RAY_STEP_PX: float = 3.0
const RAY_VIS_SECS: float = 0.30
const SPLIT_DEG: float = 20.0

var movable: bool = true
var rail_axis: String = "free"
var focus_range: float = 140.0
var frozen_secs: float = 10.0
var max_bounces: int = 5

var origin_pos: Vector2 = Vector2.ZERO
var frozen_t: float = 0.0
var ray_vis_t: float = 0.0
var ray_segments: Array[Dictionary] = [] # [{start, end, dir, color, bounce}]
var _glint_t: float = 0.0
var _reentry_guard: bool = false


func _toy_setup() -> void:
	kind = "dew_lens"
	size = Vector2(16.0, 16.0)
	radius = 9.0
	movable = bool(props.get("movable", true))
	rail_axis = str(props.get("rail_axis", "free")).strip_edges().to_lower()
	if rail_axis not in ["free", "x", "y", "none"]:
		rail_axis = "free"
	if rail_axis == "none":
		movable = false
	focus_range = maxf(40.0, float(props.get("focus_range", 140.0)))
	frozen_secs = maxf(1.0, float(props.get("frozen_secs", 10.0)))
	max_bounces = clampi(int(props.get("max_bounces", 5)), 0, 8)
	origin_pos = pos
	frozen_t = 0.0
	ray_vis_t = 0.0
	ray_segments.clear()
	_glint_t = 0.0
	_reentry_guard = false
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	pos = origin_pos
	position = pos.round()
	frozen_t = 0.0
	ray_vis_t = 0.0
	ray_segments.clear()
	set_powered(false)
	queue_redraw()


func is_frozen() -> bool:
	return frozen_t > 0.0


func is_solid() -> bool:
	return active


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(6.0, 6.0), Vector2(12.0, 12.0)) if is_solid() else Rect2()


func is_movable() -> bool:
	return active and movable and rail_axis != "none"


func is_weight_body() -> bool:
	return active


func get_push_rect_at(target_pos: Vector2) -> Rect2:
	var clamped: Vector2 = _clamp_to_rail(target_pos)
	return Rect2(clamped - Vector2(6.0, 6.0), Vector2(12.0, 12.0))


func move_to(new_pos: Vector2) -> void:
	pos = _clamp_to_rail(new_pos)
	position = pos.round()
	queue_redraw()


func nudge(delta: Vector2) -> bool:
	if not is_movable() or delta.length_squared() <= 0.001:
		return false
	var target: Vector2 = _clamp_to_rail(pos + delta)
	if target.distance_squared_to(pos) <= 0.01:
		return false
	if region != null and region.has_method("can_place_rect"):
		if not bool(region.call("can_place_rect", get_push_rect_at(target), id)):
			return false
	move_to(target)
	return true


func _clamp_to_rail(p: Vector2) -> Vector2:
	if rail_axis == "x":
		return Vector2(p.x, origin_pos.y)
	if rail_axis == "y":
		return Vector2(origin_pos.x, p.y)
	return p


func get_interact_prompt() -> String:
	return "PROMPT_ROLL_DEW" if is_movable() else ""


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	_glint_t += dt
	if frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		dirty = true
		if frozen_t <= 0.0:
			set_powered(false)
			_emit_sfx("prop_rustle")
	if ray_vis_t > 0.0:
		ray_vis_t = maxf(0.0, ray_vis_t - dt)
		dirty = true
		if ray_vis_t <= 0.0:
			ray_segments.clear()
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _reentry_guard:
		return false
	if hit.source == SOURCE_DEW_RAY:
		return false
	if hit.source not in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM]:
		return false

	var in_dir: Vector2 = hit.dir.normalized() if hit.dir.length_squared() > 0.001 else Vector2.RIGHT
	# Blue hit on a liquid droplet freezes it into a 3-way Prism Splitter!
	if hit.is_blue() and not is_frozen():
		frozen_t = frozen_secs
		set_powered(true)
		_emit_sfx("mirror_ping")
		_emit_gust(38.0, 28.0)
		queue_redraw()
		return true

	# Frozen droplet acts as a 3-way Prism Splitter (-20/0/+20 deg)
	if is_frozen():
		_fire_frozen_split(in_dir, hit)
		return true

	# Liquid droplet focuses yellow light into a piercing 6 px "dew_ray"
	_fire_dew_ray(in_dir, hit)
	return true


func _fire_frozen_split(in_dir: Vector2, hit: LxHit) -> void:
	_reentry_guard = true
	ray_segments.clear()
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for sdeg: float in [-SPLIT_DEG, 0.0, SPLIT_DEG]:
		var sdir: Vector2 = in_dir.rotated(deg_to_rad(sdeg)).normalized()
		if w != null:
			var sb := LxMoveBolt.Bolt.new()
			sb.dir = sdir
			sb.prev_pos = pos
			sb.pos = pos + sdir * 10.0
			sb.speed = 330.0
			sb.base_speed = 330.0
			sb.max_range = focus_range
			sb.damage = maxf(0.45, hit.damage * 0.85)
			sb.shield_wear = 1.0
			sb.bounces_left = 1
			sb.bounce_count = 1
			sb.is_prism = true
			sb.is_split_shard = true
			sb.light_color = LxHit.COLOR_BLUE
			sb.cracks_armour = true
			sb.hit_ids.append(get_instance_id())
			w.bolts.append(sb)
		else:
			_trace_and_deliver_ray(sdir, focus_range * 0.85, 1, LxHit.COLOR_BLUE, maxf(0.5, hit.damage))
	_emit_sfx("prism_chain")
	_emit_gust(44.0, 34.0)
	emit_power(true)
	_reentry_guard = false
	queue_redraw()


func _fire_dew_ray(in_dir: Vector2, hit: LxHit) -> void:
	_reentry_guard = true
	ray_segments.clear()
	var dmg: float = maxf(1.2, hit.damage * 2.2)
	_trace_and_deliver_ray(in_dir, focus_range, max_bounces, LxHit.COLOR_YELLOW, dmg)
	ray_vis_t = RAY_VIS_SECS
	_emit_sfx("dew_focus_ray")
	_emit_gust(48.0, 36.0)
	emit_power(true)
	_reentry_guard = false
	queue_redraw()


func _trace_and_deliver_ray(
	start_dir: Vector2,
	range_px: float,
	bounces_max: int,
	start_color: String,
	base_dmg: float
) -> void:
	var cur_pos: Vector2 = pos + start_dir * 8.0
	var cur_dir: Vector2 = start_dir.normalized()
	var cur_col: String = start_color
	var ignore_id: int = get_instance_id()
	var bounces_done: int = 0
	var segs_local: Array[Dictionary] = []

	var inters: Array = region.call("get_interactables") as Array if (region != null and region.has_method("get_interactables")) else []
	var enemies: Array = region.call("get_enemies") as Array if (region != null and region.has_method("get_enemies")) else []
	var w_att: Object = Lx.player if (Lx.player != null and is_instance_valid(Lx.player)) else self

	while bounces_done <= bounces_max:
		var dist: float = 0.0
		var seg_start: Vector2 = cur_pos
		var prev_p: Vector2 = cur_pos
		var seg_end: Vector2 = cur_pos
		var reflected: bool = false
		while dist < range_px:
			var step: float = minf(RAY_STEP_PX, range_px - dist)
			dist += step
			var pt: Vector2 = cur_pos + cur_dir * dist
			var ttype: String = str(region.call("tile_at", pt)) if (region != null and region.has_method("tile_at")) else "ground"
			if ttype == "wall":
				seg_end = prev_p
				break
			if (ttype == "glass" or ttype == "mirror") and bounces_done < bounces_max:
				var wn: Vector2 = _glass_normal(prev_p, pt, cur_dir)
				var rdir_g: Vector2 = cur_dir.bounce(wn).normalized()
				segs_local.append({"start": seg_start, "end": prev_p, "dir": cur_dir, "color": cur_col, "bounce": bounces_done})
				cur_pos = prev_p + rdir_g * 3.0
				cur_dir = rdir_g
				ignore_id = -1
				bounces_done += 1
				reflected = true
				break
			# Check reflective interactables (blue_transformer / mirror / beetle_mount)
			var hit_m: LxInteractable = null
			for it_v: Variant in inters:
				if not (it_v is LxInteractable):
					continue
				var it: LxInteractable = it_v as LxInteractable
				if not is_instance_valid(it) or not it.active or it.get_instance_id() == ignore_id:
					continue
				if it.is_reflective() and it.pos.distance_to(pt) <= maxf(8.0, it.radius) + 1.5:
					hit_m = it
					break
			if hit_m != null and bounces_done < bounces_max:
				var rdir_m: Vector2 = hit_m.reflect_dir(cur_dir)
				if rdir_m.length_squared() > 0.001:
					var next_col: String = str(hit_m.call("get_transform_color")) if hit_m.has_method("get_transform_color") else LxHit.COLOR_BLUE
					if next_col.is_empty():
						next_col = LxHit.COLOR_BLUE
					segs_local.append({"start": seg_start, "end": hit_m.pos, "dir": cur_dir, "color": cur_col, "bounce": bounces_done})
					var ping: LxHit = LxHit.make(SOURCE_DEW_RAY, base_dmg, cur_dir, hit_m.pos, 1.0, false, true, w_att, true, next_col)
					hit_m.on_hit(ping)
					cur_pos = hit_m.pos + rdir_m * 10.0
					cur_dir = rdir_m
					cur_col = next_col
					ignore_id = hit_m.get_instance_id()
					bounces_done += 1
					reflected = true
					break
			prev_p = pt
			seg_end = pt
		if not reflected:
			segs_local.append({"start": seg_start, "end": seg_end, "dir": cur_dir, "color": cur_col, "bounce": bounces_done})
			break

	# Deliver distinct "dew_ray" hits along every segment (NEVER cracks big-world cracked_wall!)
	var half_w: float = RAY_WIDTH_PX * 0.5
	var hit_inter_ids: Dictionary = {get_instance_id(): true}
	var hit_enemy_ids: Dictionary = {}
	for seg: Dictionary in segs_local:
		ray_segments.append(seg)
		var sa: Vector2 = seg["start"] as Vector2
		var sb: Vector2 = seg["end"] as Vector2
		var sdir: Vector2 = seg["dir"] as Vector2
		var scol: String = str(seg["color"])
		var dew_hit: LxHit = LxHit.make(
			SOURCE_DEW_RAY, base_dmg, sdir, sa,
			2.0, true, true, w_att, true, scol
		)
		for it_v: Variant in inters:
			if not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active or it == self:
				continue
			if it.kind == "cracked_wall":
				continue
			var iid: int = it.get_instance_id()
			if hit_inter_ids.has(iid) or it.is_reflective():
				continue
			if _seg_hits_item(sa, sb, half_w, it):
				hit_inter_ids[iid] = true
				it.on_hit(dew_hit)
		for e_v: Variant in enemies:
			if not (e_v is LxEnemyBrain):
				continue
			var en: LxEnemyBrain = e_v as LxEnemyBrain
			if not is_instance_valid(en) or not en.is_alive():
				continue
			var eid: int = en.get_instance_id()
			if hit_enemy_ids.has(eid):
				continue
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(en.pos, sa, sb)
			if cp.distance_to(en.pos) <= en.body_radius + half_w:
				hit_enemy_ids[eid] = true
				en.take_hit(dew_hit)


func _glass_normal(from_p: Vector2, to_p: Vector2, dir: Vector2) -> Vector2:
	if region == null or not region.has_method("tile_at"):
		return -dir
	var gx: bool = str(region.call("tile_at", Vector2(to_p.x, from_p.y))) in ["glass", "mirror", "wall"]
	var gy: bool = str(region.call("tile_at", Vector2(from_p.x, to_p.y))) in ["glass", "mirror", "wall"]
	if gx and not gy:
		return Vector2(-signf(dir.x) if absf(dir.x) > 0.01 else -1.0, 0.0)
	if gy and not gx:
		return Vector2(0.0, -signf(dir.y) if absf(dir.y) > 0.01 else -1.0)
	return -dir


static func _seg_hits_item(a: Vector2, b: Vector2, half_w: float, it: LxInteractable) -> bool:
	if Geometry2D.get_closest_point_to_segment(it.pos, a, b).distance_to(it.pos) <= it.radius + half_w:
		return true
	if it.is_solid():
		var sr: Rect2 = it.get_solid_rect().grow(half_w)
		var steps: int = maxi(1, int(ceil(a.distance_to(b) / 6.0)))
		for i: int in range(steps + 1):
			if sr.has_point(a.lerp(b, float(i) / float(steps))):
				return true
	return false


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if ray_vis_t > 0.0:
		return Vector4(pos.x, pos.y, 44.0, 0.92)
	if is_frozen():
		return Vector4(pos.x, pos.y, 30.0, 0.55)
	return Vector4(pos.x, pos.y, 20.0, 0.32)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pos"):
		move_to(_parse_vec2(d["pos"], origin_pos))


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color

	# Rail groove indicator when constrained to x/y axis
	if rail_axis == "x":
		draw_rect(Rect2(-14.0, 3.0, 28.0, 2.0), c_void)
		draw_rect(Rect2(-13.0, 3.0, 26.0, 1.0), PAL["dusk"] as Color)
	elif rail_axis == "y":
		draw_rect(Rect2(-1.0, -14.0, 2.0, 28.0), c_void)
		draw_rect(Rect2(-1.0, -13.0, 1.0, 26.0), PAL["dusk"] as Color)

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.5)
	# Sculpted 3-leaf mossy petal cradle beneath the droplet
	draw_rect(Rect2(-8.0, 2.0, 16.0, 5.0), c_void)
	draw_rect(Rect2(-7.0, 3.0, 14.0, 3.0), c_pine)
	draw_rect(Rect2(-6.0, 2.0, 4.0, 2.0), PAL["teal"] as Color)
	draw_rect(Rect2(2.0, 2.0, 4.0, 2.0), PAL["teal"] as Color)
	draw_rect(Rect2(-4.0, 3.0, 8.0, 2.0), c_jade)
	draw_rect(Rect2(-3.0, 3.0, 4.0, 1.0), PAL["lime"] as Color)

	if is_frozen():
		# Faceted hexagonal ice crystal prism (clearly distinct from round liquid drop in greyscale)
		var hex := PackedVector2Array([
			Vector2(0.0, -9.0), Vector2(8.0, -4.0), Vector2(8.0, 3.0),
			Vector2(0.0, 7.0), Vector2(-8.0, 3.0), Vector2(-8.0, -4.0),
		])
		draw_colored_polygon(hex, c_void)
		var inner := PackedVector2Array([
			Vector2(0.0, -7.0), Vector2(6.0, -3.0), Vector2(6.0, 2.0),
			Vector2(0.0, 5.0), Vector2(-6.0, 2.0), Vector2(-6.0, -3.0),
		])
		draw_colored_polygon(inner, c_blue)
		var top_facet := PackedVector2Array([
			Vector2(0.0, -7.0), Vector2(5.0, -3.0), Vector2(0.0, 0.0), Vector2(-5.0, -3.0),
		])
		draw_colored_polygon(top_facet, c_sky)
		draw_rect(Rect2(-2.0, -5.0, 4.0, 3.0), c_ice)
		draw_rect(Rect2(-2.0, -5.0, 2.0, 2.0), c_cream)
		# 3-way split pips
		draw_rect(Rect2(-6.0, -7.0, 2.0, 1.0), c_cream)
		draw_rect(Rect2(4.0, -7.0, 2.0, 1.0), c_cream)
		draw_rect(Rect2(-1.0, -10.0, 2.0, 1.0), c_cream)
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, clampf(frozen_t / frozen_secs, 0.0, 1.0), c_ice, c_sky)
	else:
		# Translucent domed water-droplet orb with curved specular crescent & warm caustic base
		draw_circle(Vector2(0.0, -1.0), 8.0, c_void)
		draw_circle(Vector2(0.0, -1.0), 7.0, c_deep)
		draw_circle(Vector2(0.0, -1.5), 6.0, c_blue)
		draw_circle(Vector2(-0.5, -2.0), 4.5, c_sky)
		draw_arc(Vector2(0.0, -1.0), 6.0, PI * 0.9, PI * 1.55, 10, c_ice, 1.0)
		draw_rect(Rect2(-3.0, -5.0, 3.0, 2.0), c_ice)
		draw_rect(Rect2(-3.0, -5.0, 2.0, 1.0), c_cream)
		var shim: bool = LxHudFx.flash_reduced() or int(floorf(_glint_t * 3.0)) % 2 == 0
		draw_rect(Rect2(-2.0, 2.0, 4.0, 1.0), c_cream if shim else c_ice)
		draw_rect(Rect2(2.0, 1.0, 2.0, 1.0), c_gold)
		if is_movable():
			# Crisp brass/cream corner roll-pips so player immediately reads rollability
			draw_rect(Rect2(-9.0, -2.0, 2.0, 3.0), c_void)
			draw_rect(Rect2(7.0, -2.0, 2.0, 3.0), c_void)
			draw_rect(Rect2(-8.0, -1.0, 1.0, 2.0), c_cream)
			draw_rect(Rect2(7.0, -1.0, 1.0, 2.0), c_cream)

	# Render active focused "dew_ray" polyline segments
	if ray_vis_t > 0.0 and not ray_segments.is_empty():
		var u: float = clampf(ray_vis_t / RAY_VIS_SECS, 0.0, 1.0)
		var f_sc: float = 0.72 if LxHudFx.flash_reduced() else 1.0
		for seg: Dictionary in ray_segments:
			var a: Vector2 = ((seg["start"] as Vector2) - pos).round()
			var b: Vector2 = ((seg["end"] as Vector2) - pos).round()
			var is_b: bool = str(seg.get("color", LxHit.COLOR_YELLOW)) == LxHit.COLOR_BLUE
			var outer_c: Color = c_sky if is_b else c_apricot
			var mid_c: Color = c_ice if is_b else c_gold
			draw_line(a, b, Color(outer_c, u * 0.78 * f_sc), maxf(2.0, RAY_WIDTH_PX * u))
			draw_line(a, b, Color(mid_c, u * 0.95 * f_sc), maxf(1.0, (RAY_WIDTH_PX - 2.0) * u))
			draw_line(a, b, Color(c_cream, u), maxf(1.0, 2.0 * u))
			draw_circle(b, 3.5 * u, Color(c_cream, u * f_sc))
	_draw_signal_pulses()
