class_name LxI5Constellation
extends RefCounted
## Constellation bridge & lit-triangle walkable ground manager for LxI5StarNode (Island 5).
## Turns linked lit stars (12px bridges), lit 3-star triangles, and Starlight Sextant
## thrown-lantern links into real walkable platforms over void, drawn in the Last Light palette.

class StarSupportCell:
	extends LxInteractable
	var cell_rect: Rect2 = Rect2()

	func _ready() -> void:
		super._ready()
		id = ""
		kind = "_star_support"
		radius = 0.0
		visible = false

	func is_platform_solid() -> bool:
		return active and cell_rect.has_area()

	func get_platform_rect() -> Rect2:
		return cell_rect if is_platform_solid() else Rect2()


class ConstellationCanvas:
	extends Node2D
	var unlit_edges: Array[PackedVector2Array] = []
	var lit_edges: Array[PackedVector2Array] = []
	var sextant_edges: Array[PackedVector2Array] = []
	var lit_triangles: Array[PackedVector2Array] = []
	var lantern_vertex: Vector2 = Vector2.INF
	var anim_t: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var pal: Dictionary = LxInteractable.PAL
		var fr: bool = LxHudFx.flash_reduced()
		var shim: float = 0.85 if fr else (0.78 + 0.22 * sin(anim_t * 3.2))

		# 1. Subtle etched chalk link hints between unlit/linked sockets
		for e: PackedVector2Array in unlit_edges:
			_draw_dashed(e[0], e[1], Color(pal["sky"] as Color, 0.26), 4.0, 5.0)

		# 2. Lit constellation triangles (solid walkable star-glass floor in void)
		for tri: PackedVector2Array in lit_triangles:
			draw_colored_polygon(tri, Color(pal["deep"] as Color, 0.72))
			draw_colored_polygon(tri, Color(pal["gold"] as Color, 0.22 * shim))
			for k: int in range(3):
				var a: Vector2 = tri[k]
				var b: Vector2 = tri[(k + 1) % 3]
				draw_line(a, b, Color(pal["gold"] as Color, 0.85), 2.0)
				draw_line(a, b, Color(pal["cream"] as Color, 0.75 * shim), 1.0)
			var cen: Vector2 = ((tri[0] + tri[1] + tri[2]) / 3.0).round()
			draw_line(cen + Vector2(-3.0, 0.0), cen + Vector2(3.0, 0.0), Color(pal["cream"] as Color, 0.68), 1.0)
			draw_line(cen + Vector2(0.0, -3.0), cen + Vector2(0.0, 3.0), Color(pal["cream"] as Color, 0.68), 1.0)
			draw_rect(Rect2(cen - Vector2.ONE, Vector2(2.0, 2.0)), pal["gold"] as Color)

		# 3. Solid 12px star bridges between lit neighbors
		for e: PackedVector2Array in lit_edges:
			_draw_star_bridge(e[0], e[1], pal, false, shim)

		# 4. Starlight Sextant live bridges to thrown lantern
		for e: PackedVector2Array in sextant_edges:
			_draw_star_bridge(e[0], e[1], pal, true, shim)

		if lantern_vertex.is_finite():
			var lp: Vector2 = lantern_vertex.round()
			draw_arc(lp, 9.0, 0.0, TAU, 16, Color(pal["cream"] as Color, 0.85), 1.2)
			draw_line(lp + Vector2(-5.0, 0.0), lp + Vector2(5.0, 0.0), pal["gold"] as Color, 1.0)
			draw_line(lp + Vector2(0.0, -5.0), lp + Vector2(0.0, 5.0), pal["gold"] as Color, 1.0)

	func _draw_star_bridge(a: Vector2, b: Vector2, pal: Dictionary, is_sextant: bool, shim: float) -> void:
		var d: Vector2 = b - a
		var dist: float = d.length()
		if dist < 2.0:
			return
		var dn: Vector2 = d / dist
		var perp := Vector2(-dn.y, dn.x)
		var hw: float = 5.5
		var quad := PackedVector2Array([a + perp * hw, b + perp * hw, b - perp * hw, a - perp * hw])
		draw_colored_polygon(quad, Color(pal["night"] as Color, 0.86))
		var inner_hw: float = 4.0
		var inner := PackedVector2Array([a + perp * inner_hw, b + perp * inner_hw, b - perp * inner_hw, a - perp * inner_hw])
		draw_colored_polygon(inner, Color((pal["sky"] if is_sextant else pal["deep"]) as Color, 0.62))
		var rim_c: Color = (pal["ice"] if is_sextant else pal["gold"]) as Color
		draw_line(a + perp * hw, b + perp * hw, rim_c, 1.0)
		draw_line(a - perp * hw, b - perp * hw, rim_c, 1.0)
		draw_line(a, b, Color(pal["cream"] as Color, 0.72 * shim), 1.0)
		var cur: float = 6.0
		while cur < dist - 4.0:
			var sp: Vector2 = (a + dn * cur).round()
			draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), pal["cream"] as Color if is_sextant else pal["gold"] as Color)
			cur += 10.0

	func _draw_dashed(a: Vector2, b: Vector2, col: Color, dash: float, gap: float) -> void:
		var d: Vector2 = b - a
		var dist: float = d.length()
		if dist < 2.0:
			return
		var dn: Vector2 = d / dist
		var cur: float = 0.0
		while cur < dist:
			var seg_end: float = minf(cur + dash, dist)
			draw_line((a + dn * cur).round(), (a + dn * seg_end).round(), col, 1.0)
			cur += dash + gap


static var _region_cache: Dictionary = {} # region_instance_id -> {cells, canvas, sig}


static func collect_stars(reg: Node) -> Array[LxI5StarNode]:
	var out: Array[LxI5StarNode] = []
	if reg == null or not is_instance_valid(reg) or not reg.has_method("get_interactables"):
		return out
	for it_v: Variant in (reg.call("get_interactables") as Array):
		if it_v is LxI5StarNode and is_instance_valid(it_v as Object):
			out.append(it_v as LxI5StarNode)
	return out


static func _sextant_lantern_pos() -> Vector2:
	if Lx.state == null or not bool(Lx.state.story_flags.get("power_sextant", false)):
		return Vector2.INF
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return Vector2.INF
	var w: LxWick = Lx.player as LxWick
	if w.dead or w.lantern == null or not is_instance_valid(w.lantern):
		return Vector2.INF
	return w.lantern.pos if w.lantern.is_lure_active() else Vector2.INF


static func _stars_can_link(a: LxI5StarNode, b: LxI5StarNode) -> bool:
	if a == b:
		return false
	var has_explicit: bool = (not a.links.is_empty()) or (not b.links.is_empty())
	if a.links.has(b.id) or b.links.has(a.id):
		return true
	if has_explicit:
		return false
	return a.pos.distance_to(b.pos) <= minf(a.link_range, b.link_range)


static func sync(reg: Node, dt: float = 0.0, force: bool = false) -> void:
	if reg == null or not is_instance_valid(reg):
		return
	var rid: int = reg.get_instance_id()
	var entry: Dictionary = _region_cache.get(rid, {}) as Dictionary
	if entry.is_empty() or not is_instance_valid(entry.get("canvas", null)):
		entry = _init_cache(reg, rid)
	var canvas: ConstellationCanvas = entry["canvas"] as ConstellationCanvas
	if dt > 0.0:
		canvas.anim_t += dt

	var stars: Array[LxI5StarNode] = collect_stars(reg)
	var lan_v: Vector2 = _sextant_lantern_pos()
	var room_token: int = stars[0].get_instance_id() if not stars.is_empty() else 0
	if int(entry.get("room_token", -1)) != room_token:
		var old_cells: Array = entry.get("cells", []) as Array
		for oc_v: Variant in old_cells:
			if oc_v is Node and is_instance_valid(oc_v as Object):
				(oc_v as Node).queue_free()
		entry["cells"] = []
		entry["sig"] = ""
		entry["room_token"] = room_token
		entry["prev_edges"] = -1
		entry["prev_tris"] = -1

	var sig_parts := PackedStringArray()
	for s: LxI5StarNode in stars:
		sig_parts.append("%s:%d:%d:%d" % [s.id, 1 if s.is_lit_and_active() else 0, int(roundf(s.pos.x)), int(roundf(s.pos.y))])
	if lan_v.is_finite():
		sig_parts.append("L:%d:%d" % [int(roundf(lan_v.x * 0.5)), int(roundf(lan_v.y * 0.5))])
	var sig: String = "|".join(sig_parts)
	if not force and str(entry.get("sig", "")) == sig:
		if not canvas.lit_edges.is_empty() or not canvas.lit_triangles.is_empty() or not canvas.sextant_edges.is_empty():
			canvas.queue_redraw()
		return
	entry["sig"] = sig

	var lit_stars: Array[LxI5StarNode] = []
	var unlit_edges: Array[PackedVector2Array] = []
	for i: int in range(stars.size()):
		var sa: LxI5StarNode = stars[i]
		if sa.is_lit_and_active():
			lit_stars.append(sa)
		for j: int in range(i + 1, stars.size()):
			var sb: LxI5StarNode = stars[j]
			if sa.is_star_active() and sb.is_star_active() and sa.is_revealed() and sb.is_revealed():
				if _stars_can_link(sa, sb) and not (sa.is_lit_and_active() and sb.is_lit_and_active()):
					unlit_edges.append(PackedVector2Array([sa.pos, sb.pos]))

	var n_lit: int = lit_stars.size()
	var adj: Dictionary = {}
	var lit_edges: Array[PackedVector2Array] = []
	for i: int in range(n_lit):
		for j: int in range(i + 1, n_lit):
			if _stars_can_link(lit_stars[i], lit_stars[j]):
				adj["%d:%d" % [i, j]] = true
				lit_edges.append(PackedVector2Array([lit_stars[i].pos, lit_stars[j].pos]))

	var sextant_edges: Array[PackedVector2Array] = []
	var lan_linked: Array[int] = []
	if lan_v.is_finite():
		for i: int in range(n_lit):
			var sr: float = maxf(84.0, lit_stars[i].link_range)
			if lit_stars[i].pos.distance_to(lan_v) <= sr:
				lan_linked.append(i)
				sextant_edges.append(PackedVector2Array([lit_stars[i].pos, lan_v]))

	var lit_tris: Array[PackedVector2Array] = []
	for i: int in range(n_lit):
		for j: int in range(i + 1, n_lit):
			if not adj.has("%d:%d" % [i, j]):
				continue
			for k: int in range(j + 1, n_lit):
				if adj.has("%d:%d" % [i, k]) and adj.has("%d:%d" % [j, k]):
					lit_tris.append(PackedVector2Array([lit_stars[i].pos, lit_stars[j].pos, lit_stars[k].pos]))

	for ai: int in range(lan_linked.size()):
		for bi: int in range(ai + 1, lan_linked.size()):
			var i0: int = lan_linked[ai]
			var i1: int = lan_linked[bi]
			var p0: Vector2 = lit_stars[i0].pos
			var p1: Vector2 = lit_stars[i1].pos
			var area2: float = absf((p1.x - p0.x) * (lan_v.y - p0.y) - (p1.y - p0.y) * (lan_v.x - p0.x))
			if area2 > 128.0 and (adj.has("%d:%d" % [i0, i1]) or p0.distance_to(p1) <= 168.0):
				lit_tris.append(PackedVector2Array([p0, p1, lan_v]))

	var prev_edges: int = int(entry.get("prev_edges", -1))
	var prev_tris: int = int(entry.get("prev_tris", -1))
	entry["prev_edges"] = lit_edges.size()
	entry["prev_tris"] = lit_tris.size()
	if prev_edges >= 0 and (lit_tris.size() > prev_tris or lit_edges.size() > prev_edges):
		var fx_p: Vector2 = lit_tris[lit_tris.size() - 1][0] if not lit_tris.is_empty() else (lit_edges[lit_edges.size() - 1][0] if not lit_edges.is_empty() else Vector2.ZERO)
		if Lx.events != null:
			Lx.events.sfx_requested.emit("star_constellation", fx_p, fx_p != Vector2.ZERO)
		elif Lx.audio != null:
			Lx.audio.play_sfx("star_constellation", fx_p, fx_p != Vector2.ZERO)

	var has_sex_link: bool = not sextant_edges.is_empty()
	canvas.unlit_edges = unlit_edges
	canvas.lit_edges = lit_edges
	canvas.sextant_edges = sextant_edges
	canvas.lit_triangles = lit_tris
	canvas.lantern_vertex = lan_v if has_sex_link else Vector2.INF
	canvas.queue_redraw()
	_update_support_cells(reg, entry, lit_edges, sextant_edges, lit_tris, lan_v if has_sex_link else Vector2.INF)


static func _init_cache(reg: Node, rid: int) -> Dictionary:
	var canvas := ConstellationCanvas.new()
	canvas.name = "I5ConstellationCanvas"
	canvas.z_as_relative = false
	canvas.z_index = LxPhysDraw.floor_z(reg, -4)
	var parent_n: Node = reg.get("_floor_interactables_root") as Node if reg.get("_floor_interactables_root") is Node else reg
	parent_n.add_child(canvas)
	parent_n.move_child(canvas, 0)
	var d: Dictionary = {"canvas": canvas, "cells": [], "sig": ""}
	_region_cache[rid] = d
	return d


static func _update_support_cells(
	reg: Node,
	entry: Dictionary,
	lit_edges: Array[PackedVector2Array],
	sextant_edges: Array[PackedVector2Array],
	lit_tris: Array[PackedVector2Array],
	lan_v: Vector2
) -> void:
	var w: int = int(reg.get("width")) if reg.get("width") != null else 0
	var h: int = int(reg.get("height")) if reg.get("height") != null else 0
	var ts_v: Variant = reg.get("tile_size")
	var ts: float = float(ts_v) if (ts_v is int or ts_v is float) and float(ts_v) > 0.0 else 16.0
	var rects: Array[Rect2] = []

	if w > 0 and h > 0 and (not lit_edges.is_empty() or not sextant_edges.is_empty() or not lit_tris.is_empty()):
		var all_edges: Array[PackedVector2Array] = []
		all_edges.append_array(lit_edges)
		all_edges.append_array(sextant_edges)
		var min_x: float = INF; var min_y: float = INF; var max_x: float = -INF; var max_y: float = -INF
		for e: PackedVector2Array in all_edges:
			for p: Vector2 in e:
				min_x = minf(min_x, p.x); min_y = minf(min_y, p.y)
				max_x = maxf(max_x, p.x); max_y = maxf(max_y, p.y)
		for tri: PackedVector2Array in lit_tris:
			for p: Vector2 in tri:
				min_x = minf(min_x, p.x); min_y = minf(min_y, p.y)
				max_x = maxf(max_x, p.x); max_y = maxf(max_y, p.y)
		var tx0: int = maxi(0, int(floorf((min_x - 16.0) / ts)))
		var tx1: int = mini(w - 1, int(floorf((max_x + 16.0) / ts)))
		var ty0: int = maxi(0, int(floorf((min_y - 16.0) / ts)))
		var ty1: int = mini(h - 1, int(floorf((max_y + 16.0) / ts)))
		for ty: int in range(ty0, ty1 + 1):
			for tx: int in range(tx0, tx1 + 1):
				var tc := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
				var covered: bool = false
				for e: PackedVector2Array in all_edges:
					if Geometry2D.get_closest_point_to_segment(tc, e[0], e[1]).distance_to(tc) <= 10.5:
						covered = true
						break
				if not covered:
					for tri: PackedVector2Array in lit_tris:
						if Geometry2D.is_point_in_polygon(tc, tri):
							covered = true
							break
				if not covered and lan_v.is_finite() and tc.distance_to(lan_v) <= 12.0:
					covered = true
				if covered:
					rects.append(Rect2(float(tx) * ts, float(ty) * ts, ts, ts))

	var cells: Array = entry["cells"] as Array
	var parent_n: Node = reg.get("_floor_interactables_root") as Node if reg.get("_floor_interactables_root") is Node else reg
	var inter_list_v: Variant = reg.get("_interactables")
	if not (inter_list_v is Array):
		inter_list_v = reg.get("interactables")
	var inter_list: Array = inter_list_v as Array if inter_list_v is Array else []

	for ci: int in range(cells.size() - 1, -1, -1):
		if cells[ci] == null or not is_instance_valid(cells[ci] as Object):
			cells.remove_at(ci)

	while cells.size() < rects.size():
		var c := StarSupportCell.new()
		c.region = reg
		parent_n.add_child(c)
		if inter_list_v is Array:
			inter_list.append(c)
		cells.append(c)

	for i: int in range(cells.size()):
		var c: StarSupportCell = cells[i] as StarSupportCell
		if c == null or not is_instance_valid(c):
			continue
		if inter_list_v is Array and not inter_list.has(c):
			inter_list.append(c)
		if i < rects.size():
			c.active = true
			c.cell_rect = rects[i]
		else:
			c.active = false
			c.cell_rect = Rect2()
