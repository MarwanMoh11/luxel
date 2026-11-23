class_name LxBiomeSkyAccents
extends RefCounted
## Bespoke per-island living open-sea & void-abyss phenomena rendered strictly over
## open water/tide/pit/void tiles (never obscuring land). Strictly 20 Last Light colours.
##
## - Island 1 (Bell Isle): Bobbing distant twilight harbor lantern-buoys & warm sea glints
## - Island 2 (Tidewater Harbor): Sweeping coastal ocean swell ribbons & rocking spar-buoys
## - Island 3 (Thornwood Hollow): Drifting emerald canopy mist ribbons & lime spore clusters
## - Island 4 (Mirefen Gardens): Floating blooming rose-and-cream lotus pads & dew rings
## - Island 5 (Starfall Observatory): Etched celestial zodiac constellations across the void
## - Island 6 (Ashen Kiln): Breathing molten magma convection veins in volcanic caldera pits
## - Island 7 (Moon Shoals): Vertical silver moonlight reflection pillars & mirrored stars
## - Island 8 (The Long Night): Fractured eclipse nebula rings cracking into golden Dawn

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 192.0
const HALF_H: float = 120.0

var _island_id: int = 1
var _is_dungeon: bool = false
var _nodes: Array[Dictionary] = [] # {pos, phase, kind, span}
var _links: Array[Array] = []      # [Vector2, Vector2] for Isl 5 zodiac constellations


func is_empty() -> bool:
	return _nodes.is_empty() and _links.is_empty()


func configure(grid: Array[PackedStringArray], tile_size: int, island_id: int, is_dungeon: bool) -> void:
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_nodes.clear()
	_links.clear()
	var h: int = grid.size()
	if h < 4:
		return
	var w: int = grid[0].size()
	if w < 4:
		return
	var ts: float = float(maxi(8, tile_size))
	var want_open: PackedStringArray = _open_tiles_for(_island_id)
	var limit: int = 10 if is_dungeon else 18
	var min_sep_sq: float = 2304.0 if is_dungeon else 3600.0 # >= 48px / 60px apart

	for ty: int in range(1, h - 1):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(1, w - 1):
			if _nodes.size() >= limit:
				break
			if not want_open.has(row[tx]):
				continue
			if not (want_open.has(grid[ty - 1][tx]) and want_open.has(grid[ty + 1][tx]) and want_open.has(row[tx - 1]) and want_open.has(row[tx + 1])):
				continue
			var hv: int = (tx * 668265263 ^ ty * 2147483647 ^ _island_id * 374761393) & 0x7FFFFFFF
			if (hv % (7 if is_dungeon else 5)) != 0:
				continue
			var p := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts).round()
			var ok: bool = true
			for prev: Dictionary in _nodes:
				if (prev["pos"] as Vector2).distance_squared_to(p) < min_sep_sq:
					ok = false
					break
			if not ok:
				continue
			_nodes.append({
				"pos": p,
				"phase": float(hv % 628) * 0.01,
				"kind": (hv >> 8) % 3,
				"span": 7.0 + float((hv >> 12) % 7),
			})
		if _nodes.size() >= limit:
			break

	if _island_id == 5 and _nodes.size() >= 2:
		for i: int in range(_nodes.size()):
			var pi: Vector2 = _nodes[i]["pos"] as Vector2
			var best_j: int = -1
			var best_d2: float = 13456.0 # <= 116 px
			for j: int in range(i + 1, _nodes.size()):
				var d2: float = pi.distance_squared_to(_nodes[j]["pos"] as Vector2)
				if d2 > 900.0 and d2 < best_d2:
					best_d2 = d2
					best_j = j
			if best_j >= 0 and _links.size() < 10:
				_links.append([pi, _nodes[best_j]["pos"] as Vector2])


static func _open_tiles_for(isl: int) -> PackedStringArray:
	match isl:
		2, 4, 7:
			return PackedStringArray(["water", "tide"])
		6:
			return PackedStringArray(["pit", "void"])
		_:
			return PackedStringArray(["water", "tide", "pit", "void"])


func draw_accents(ci: CanvasItem, clock: float, cam_center: Vector2, relit: bool) -> void:
	if ci == null or is_empty():
		return
	var fred: bool = LxHudFx.flash_reduced()
	var t: float = clock * (0.45 if fred else 1.0)
	var min_x: float = cam_center.x - HALF_W
	var max_x: float = cam_center.x + HALF_W
	var min_y: float = cam_center.y - HALF_H
	var max_y: float = cam_center.y + HALF_H

	if _island_id == 5 and not _links.is_empty():
		var line_c: Color = (PAL["gold"] if relit else PAL["blue"]) as Color
		var la: float = 0.28 if fred else (0.38 if relit else 0.30)
		for ln: Array in _links:
			var a: Vector2 = ln[0] as Vector2
			var b: Vector2 = ln[1] as Vector2
			if (a.x < min_x and b.x < min_x) or (a.x > max_x and b.x > max_x) or (a.y < min_y and b.y < min_y) or (a.y > max_y and b.y > max_y):
				continue
			ci.draw_line(a, b, Color(line_c, la), 1.0)

	var seals_b: int = LxBiomeMechanics.active_instance.dawn_seals_broken if (_island_id == 8 and LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance)) else 0
	for nd: Dictionary in _nodes:
		var p: Vector2 = nd["pos"] as Vector2
		if p.x < min_x or p.x > max_x or p.y < min_y or p.y > max_y:
			continue
		var ph: float = float(nd["phase"])
		var k: int = int(nd["kind"])
		var sp: float = float(nd["span"])
		match _island_id:
			1: # Distant twilight harbor lantern-buoys bobbing softly in outer sea
				var bob: float = 0.0 if fred else roundf(sin(t * 1.8 + ph) * 1.2)
				var bp := Vector2(p.x, p.y + bob)
				ci.draw_rect(Rect2(bp + Vector2(-2.0, 2.0), Vector2(4.0, 1.0)), Color(PAL["apricot"] as Color, 0.35))
				ci.draw_rect(Rect2(bp + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), PAL["gold"] as Color)
				ci.draw_rect(Rect2(bp, Vector2.ONE), PAL["cream"] as Color)
			2: # Coastal ocean swell ribbons + rocking coral/gold spar-buoys
				if k == 0:
					var bob2: float = 0.0 if fred else roundf(sin(t * 2.2 + ph) * 1.4)
					var bp2 := Vector2(p.x, p.y + bob2)
					ci.draw_rect(Rect2(bp2 + Vector2(-1.0, -3.0), Vector2(2.0, 4.0)), PAL["coral"] as Color)
					ci.draw_rect(Rect2(bp2 + Vector2(-1.0, -4.0), Vector2(2.0, 1.0)), (PAL["gold"] if relit else PAL["ice"]) as Color)
					ci.draw_rect(Rect2(bp2 + Vector2(-3.0, 1.0), Vector2(6.0, 1.0)), Color(PAL["ice"] as Color, 0.45))
				else:
					var drift: float = 0.0 if fred else roundf(sin(t * 1.2 + ph) * 4.0)
					var sw_c: Color = (PAL["gold"] if relit else PAL["ice"]) as Color
					ci.draw_line(Vector2(p.x - sp + drift, p.y), Vector2(p.x + sp + drift, p.y), Color(PAL["sky"] as Color, 0.36), 1.0)
					ci.draw_line(Vector2(p.x - sp * 0.5 + drift, p.y - 1.0), Vector2(p.x + sp * 0.5 + drift, p.y - 1.0), Color(sw_c, 0.42), 1.0)
			3: # Drifting emerald canopy mist ribbons & floating lime spore constellation
				var dx3: float = 0.0 if fred else roundf(sin(t * 0.9 + ph) * 5.0)
				ci.draw_rect(Rect2(p.x - sp + dx3, p.y, sp * 2.0, 2.0), Color(PAL["teal"] as Color, 0.22))
				ci.draw_rect(Rect2(p.x - sp * 0.6 + dx3, p.y - 1.0, sp * 1.2, 1.0), Color(PAL["jade"] as Color, 0.30))
				var sp_y: float = roundf(p.y - 3.0 + sin(t * 1.6 + ph) * 2.0)
				ci.draw_rect(Rect2(p.x + dx3, sp_y, 1.0, 1.0), Color((PAL["gold"] if relit else PAL["lime"]) as Color, 0.65))
			4: # Floating blooming rose-and-cream lotus pads & tranquil dew rings
				var sway4: float = 0.0 if fred else roundf(sin(t * 1.4 + ph) * 1.2)
				var lp := Vector2(p.x + sway4, p.y)
				ci.draw_rect(Rect2(lp + Vector2(-4.0, -1.0), Vector2(8.0, 4.0)), Color(PAL["teal"] as Color, 0.65))
				ci.draw_rect(Rect2(lp + Vector2(-3.0, 0.0), Vector2(6.0, 2.0)), Color(PAL["jade"] as Color, 0.72))
				if k != 2:
					ci.draw_rect(Rect2(lp + Vector2(-1.0, -2.0), Vector2(3.0, 2.0)), (PAL["gold"] if relit else PAL["rose"]) as Color)
					ci.draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
				var du: float = fposmod(t * 0.35 + ph, 1.0)
				ci.draw_arc(lp + Vector2(0.0, 1.0), roundf(lerpf(4.0, 10.0, du)), 0.0, TAU, 12, Color(PAL["ice"] as Color, (1.0 - du) * 0.34), 1.0)
			5: # Starfall gleaming zodiac constellation nodes
				var tw: bool = fred or sin(t * 2.2 + ph) > -0.2
				if tw:
					var sc: Color = (PAL["gold"] if k != 2 else PAL["sky"]) as Color
					ci.draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), Color(sc, 0.65))
					ci.draw_rect(Rect2(p + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), Color(sc, 0.65))
					ci.draw_rect(Rect2(p, Vector2.ONE), PAL["cream"] as Color)
			6: # Caldera molten magma convection veins pulsing smoothly in lava pits
				var heat: float = 0.55 if fred else (0.45 + 0.55 * sin(t * 1.9 + ph))
				var vc: Color = (PAL["gold"] if (relit or heat > 0.78) else (PAL["apricot"] if heat > 0.45 else PAL["coral"])) as Color
				var mid6 := Vector2(p.x + roundf(sin(ph) * 4.0), p.y + roundf(cos(ph) * 3.0))
				ci.draw_line(p - Vector2(sp * 0.7, 2.0), mid6, Color(PAL["wine"] as Color, 0.48), 2.0)
				ci.draw_line(mid6, p + Vector2(sp * 0.7, -2.0), Color(vc, 0.42 + heat * 0.32), 1.2)
				if heat > 0.72:
					ci.draw_rect(Rect2(mid6, Vector2.ONE), PAL["cream"] as Color)
			7: # Shimmering vertical silver moonlight reflection pillars across the glassy lagoon
				var sh: float = 0.65 if fred else (0.45 + 0.55 * sin(t * 1.6 + ph))
				var pc: Color = (PAL["gold"] if relit else PAL["ice"]) as Color
				for ry: int in range(4):
					var wob: float = 0.0 if fred else roundf(sin(t * 2.2 + ph + float(ry) * 0.9) * 1.4)
					var rw: float = maxf(2.0, 6.0 - float(ry))
					ci.draw_rect(Rect2(roundf(p.x - rw * 0.5 + wob), p.y - 4.0 + float(ry) * 3.0, rw, 1.0), Color(PAL["cream"] if ry == 0 else pc, sh * (0.58 - float(ry) * 0.10)))
			8: # Fractured eclipse nebula rings cracking into golden Dawn rays
				var dawn8: bool = relit or seals_b >= 2
				var ec: Color = (PAL["gold"] if dawn8 else PAL["rose"]) as Color
				var ea: float = 0.24 if fred else (0.38 if dawn8 else 0.30)
				var rad8: float = roundf(6.0 + (0.0 if fred else sin(t * 1.5 + ph) * 1.5))
				ci.draw_arc(p, rad8, t * 0.5 + ph, t * 0.5 + ph + PI * 1.35, 14, Color(ec, ea), 1.0)
				if dawn8:
					ci.draw_rect(Rect2(p, Vector2.ONE), PAL["cream"] as Color)
