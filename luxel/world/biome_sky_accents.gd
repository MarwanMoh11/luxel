class_name LxBiomeSkyAccents
extends RefCounted
## Bespoke per-island living open-sea, void-abyss, lunar-aurora & floating-island rim accents
## rendered strictly over open water/tide/pit/void tiles (never obscuring walkable land).
## Strictly uses the 20 Last Light colours (LxPalette.PAL).
##
## - Island 1 (Bell Isle): Bobbing distant twilight harbor lantern-buoys & floating sky-island cliff skirt
## - Island 2 (Tidewater Harbor): Sweeping coastal ocean swell ribbons & rocking spar-buoys
## - Island 3 (Thornwood Hollow): Drifting emerald canopy mist ribbons & lime spore clusters
## - Island 4 (Mirefen Gardens): Floating blooming rose-and-cream lotus pads & dew rings
## - Island 5 (Starfall Observatory): Etched celestial zodiac constellations across the void
## - Island 6 (Ashen Kiln): Breathing molten magma convection veins in volcanic caldera pits
## - Island 7 (Moon Shoals): Vertical silver moonlight pillars & Mirror Spire deep-abyss lunar aurora
## - Island 8 (The Long Night): Fractured eclipse nebula rings cracking into golden Dawn

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 192.0
const HALF_H: float = 120.0

var _island_id: int = 1
var _is_dungeon: bool = false
var _tile_size: float = 16.0
var _nodes: Array[Dictionary] = []         # {pos, phase, kind, span}
var _links: Array[Array] = []              # [Vector2, Vector2] for Isl 5 zodiac constellations
var _aurora_ribbons: Array[Dictionary] = [] # {x0, x1, y, phase, amp, kind} for Isl 7 dungeon abyss
var _cliff_skirts: Array[Dictionary] = []   # {x, y, side, hv} for Isl 1 floating-island void rims
var _pit_lips: Array[Dictionary] = []       # {x, y, mask, hv} for Isl 3 pit cliff-lips & roots
var _lava_curbs: Array[Dictionary] = []     # {x, y, mask, hv} for Isl 6 dungeon lava masonry curbs


func is_empty() -> bool:
	return _nodes.is_empty() and _links.is_empty() and _aurora_ribbons.is_empty() and _cliff_skirts.is_empty() and _pit_lips.is_empty() and _lava_curbs.is_empty()


func configure(grid: Array[PackedStringArray], tile_size: int, island_id: int, is_dungeon: bool) -> void:
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_tile_size = float(maxi(8, tile_size))
	_nodes.clear()
	_links.clear()
	_aurora_ribbons.clear()
	_cliff_skirts.clear()
	_pit_lips.clear()
	_lava_curbs.clear()
	var h: int = grid.size()
	if h < 4:
		return
	var w: int = grid[0].size()
	if w < 4:
		return
	var ts: float = _tile_size
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

	if _island_id == 7 and _is_dungeon:
		_build_lunar_aurora(grid, h, w, ts)
	elif _island_id == 1 and not _is_dungeon:
		_build_bell_isle_cliff_skirts(grid, h, w, ts)
	elif _island_id == 3:
		_build_oak_pit_lips(grid, h, w, ts)
	elif _island_id == 6 and _is_dungeon:
		_build_kiln_lava_curbs(grid, h, w, ts)


func _build_lunar_aurora(grid: Array[PackedStringArray], h: int, w: int, ts: float) -> void:
	# Scan contiguous horizontal pit/void runs across Mirror Spire abysses (strictly masked off walkable tiles)
	for ty: int in range(1, h - 1):
		if (ty % 2) == 0:
			continue
		var row: PackedStringArray = grid[ty]
		var tx: int = 1
		while tx < w - 1:
			if not _is_abyss_tile(row[tx]):
				tx += 1
				continue
			var run_start: int = tx
			while tx < w - 1 and _is_abyss_tile(row[tx]):
				tx += 1
			var run_len: int = tx - run_start
			if run_len >= 4:
				var hv: int = (run_start * 2654435761 ^ ty * 2246822519 ^ 717) & 0x7FFFFFFF
				var x0: float = float(run_start) * ts + 4.0
				var x1: float = float(tx) * ts - 4.0
				if x1 - x0 >= 32.0:
					_aurora_ribbons.append({
						"x0": x0,
						"x1": x1,
						"y": roundf((float(ty) + 0.5) * ts),
						"phase": float(hv % 628) * 0.01,
						"amp": 2.0 + float((hv >> 4) % 3),
						"kind": (hv >> 8) % 2,
					})


func _build_bell_isle_cliff_skirts(grid: Array[PackedStringArray], h: int, w: int, ts: float) -> void:
	# Stepped floating sky-island rocky cliff skirt along eastern & southern void-adjacent rims on Island 1
	for ty: int in range(1, h - 1):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(1, w - 1):
			if not _is_rim_land(row[tx]):
				continue
			var hv: int = (tx * 374761393 ^ ty * 668265263 ^ 101) & 0x7FFFFFFF
			if row[tx + 1] == "void":
				_cliff_skirts.append({
					"x": float(tx + 1) * ts,
					"y": float(ty) * ts,
					"side": 0, # east rim dropping into void
					"hv": hv,
				})
			if grid[ty + 1][tx] == "void":
				_cliff_skirts.append({
					"x": float(tx) * ts,
					"y": float(ty + 1) * ts,
					"side": 1, # south underside dropping into void
					"hv": hv ^ 0x55AA,
				})


static func _is_abyss_tile(t: String) -> bool:
	return t == "pit" or t == "void"


static func _is_rim_land(t: String) -> bool:
	return t == "ground" or t == "path" or t == "wall" or t == "bridge"


static func _is_walkable(t: String) -> bool:
	return t == "ground" or t == "path" or t == "bridge"


func _build_oak_pit_lips(grid: Array[PackedStringArray], h: int, w: int, ts: float) -> void:
	for ty: int in range(h):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(w):
			if row[tx] != "pit":
				continue
			var m: int = (1 if (ty > 0 and grid[ty - 1][tx] != "pit" and grid[ty - 1][tx] != "void") else 0) \
				| (2 if (tx > 0 and _is_walkable(row[tx - 1])) else 0) \
				| (4 if (tx < w - 1 and _is_walkable(row[tx + 1])) else 0)
			if m != 0:
				_pit_lips.append({"x": float(tx) * ts, "y": float(ty) * ts, "mask": m, "hv": (tx * 374761393 ^ ty * 668265263 ^ 303) & 0x7FFFFFFF})


func _build_kiln_lava_curbs(grid: Array[PackedStringArray], h: int, w: int, ts: float) -> void:
	for ty: int in range(h):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(w):
			if not _is_walkable(row[tx]):
				continue
			var m: int = (1 if (ty > 0 and grid[ty - 1][tx] == "pit") else 0) \
				| (2 if (ty < h - 1 and grid[ty + 1][tx] == "pit") else 0) \
				| (4 if (tx > 0 and row[tx - 1] == "pit") else 0) \
				| (8 if (tx < w - 1 and row[tx + 1] == "pit") else 0)
			if m != 0:
				_lava_curbs.append({"x": float(tx) * ts, "y": float(ty) * ts, "mask": m, "hv": (tx * 668265263 ^ ty * 374761393 ^ 606) & 0x7FFFFFFF})


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

	if not _cliff_skirts.is_empty():
		_draw_bell_isle_cliff_skirts(ci, min_x, max_x, min_y, max_y, relit)

	if not _pit_lips.is_empty():
		_draw_oak_pit_lips(ci, min_x, max_x, min_y, max_y)

	if not _lava_curbs.is_empty():
		_draw_kiln_lava_curbs(ci, min_x, max_x, min_y, max_y)

	if not _aurora_ribbons.is_empty():
		_draw_lunar_aurora(ci, t, fred, min_x, max_x, min_y, max_y)

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
				ci.draw_line(mid6, p + Vector2(sp * 0.7, -2.0), Color(vc, 0.42 + heat * 0.32), 1.0)
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


func _draw_lunar_aurora(ci: CanvasItem, t: float, fred: bool, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	# Soft low-alpha stepped horizontal lunar-aurora shimmer ribbons strictly over Mirror Spire abyss tiles
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var a_scale: float = 0.72 if fred else 1.0
	for rb: Dictionary in _aurora_ribbons:
		var x0: float = float(rb["x0"])
		var x1: float = float(rb["x1"])
		var base_y: float = float(rb["y"])
		if x1 < min_x or x0 > max_x or base_y + 10.0 < min_y or base_y - 10.0 > max_y:
			continue
		var ph: float = float(rb["phase"])
		var amp: float = float(rb["amp"])
		var kind: int = int(rb["kind"])
		var span: float = maxf(1.0, x1 - x0)
		var step: float = 6.0
		var x: float = x0
		while x < x1:
			var seg_w: float = minf(step, x1 - x)
			var u: float = (x - x0) / span
			var env: float = sin(u * PI)
			if env > 0.08:
				var wv: float = sin(u * 6.2 + t * 0.85 + ph)
				var wy: float = roundf(base_y + wv * amp)
				var breath: float = 0.75 if fred else (0.68 + 0.32 * sin(t * 1.2 + ph + u * 4.0))
				var a_lo: float = 0.14 * env * breath * a_scale
				var a_hi: float = 0.22 * env * breath * a_scale
				# Deep sky curtain veil beneath the shimmer ridge
				ci.draw_rect(Rect2(roundf(x), wy + 1.0, seg_w, 3.0), Color(c_deep if kind == 1 else c_sky, a_lo))
				# Primary stepped sky/ice aurora crest
				ci.draw_rect(Rect2(roundf(x), wy, seg_w, 1.0), Color(c_ice if wv > 0.2 else c_sky, a_hi))
				# Delicate upward aurora curtain filament & cream starlight peak glint
				if env > 0.45 and wv > 0.35:
					ci.draw_rect(Rect2(roundf(x + seg_w * 0.5), wy - 2.0, 1.0, 2.0), Color(c_ice, a_hi * 0.78))
					if wv > 0.72:
						ci.draw_rect(Rect2(roundf(x + seg_w * 0.5), wy - 1.0, 1.0, 1.0), Color(c_cr, a_hi * 0.92))
			x += step


func _draw_bell_isle_cliff_skirts(ci: CanvasItem, min_x: float, max_x: float, min_y: float, max_y: float, relit: bool) -> void:
	# Handcrafted 4-5 px stepped rocky floating-island cliff skirt along Bell Isle void-adjacent rims
	var ts: float = _tile_size
	var c_stone: Color = (PAL["gold"] if relit else PAL["stone"]) as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_night: Color = PAL["night"] as Color
	for sk: Dictionary in _cliff_skirts:
		var sx: float = float(sk["x"])
		var sy: float = float(sk["y"])
		if sx + ts < min_x or sx - 8.0 > max_x or sy + ts < min_y or sy - 8.0 > max_y:
			continue
		var hv: int = int(sk["hv"])
		var side: int = int(sk["side"])
		if side == 0:
			# Eastern rim: 4-5 px stepped rock strata stepping into the eastern void
			for band: int in range(4):
				var by: float = sy + float(band) * 4.0
				var bh: float = minf(4.0, ts - float(band) * 4.0)
				if bh <= 0.0:
					break
				var bhv: int = (hv >> (band * 3)) & 7
				var depth: float = 4.0 + float(bhv % 2) # 4..5 px
				# Crisp stone/mauve top rim edge knitting land into rock lip
				ci.draw_rect(Rect2(sx - 1.0, by, 1.0, bh), Color(c_stone if (bhv & 1) == 0 else c_mauve, 0.85))
				# Mid rocky plum cliff shelf
				ci.draw_rect(Rect2(sx, by, 2.0, bh), c_plum)
				# Stepped dusk outer rock face
				ci.draw_rect(Rect2(sx + 2.0, by, maxf(1.0, depth - 2.0), bh), c_dusk)
				# Deep under-crag night taper at far edge
				ci.draw_rect(Rect2(sx + depth, by + (1.0 if (bhv & 2) != 0 else 0.0), 1.0, maxf(1.0, bh - 1.0)), c_night)
				# Subtle moss/stone highlight fleck on alternating ledges
				if (bhv % 3) == 0:
					ci.draw_rect(Rect2(sx + 1.0, by, 1.0, 1.0), Color(c_stone, 0.72))
		else:
			# Southern floating-island underside: 4-5 px stepped crag taper hanging over void
			for band: int in range(4):
				var bx: float = sx + float(band) * 4.0
				var bw: float = minf(4.0, ts - float(band) * 4.0)
				if bw <= 0.0:
					break
				var bhv2: int = (hv >> (band * 3)) & 7
				var drop: float = 4.0 + float(bhv2 % 2)
				ci.draw_rect(Rect2(bx, sy - 1.0, bw, 1.0), Color(c_mauve, 0.82))
				ci.draw_rect(Rect2(bx, sy, bw, 2.0), c_plum)
				ci.draw_rect(Rect2(bx, sy + 2.0, bw, maxf(1.0, drop - 2.0)), c_dusk)
				ci.draw_rect(Rect2(bx + (1.0 if (bhv2 & 1) != 0 else 0.0), sy + drop, maxf(1.0, bw - 1.0), 1.0), c_night)


func _draw_oak_pit_lips(ci: CanvasItem, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	var ts: float = _tile_size
	var c_pine: Color = PAL["pine"] as Color; var c_night: Color = PAL["night"] as Color
	var c_void: Color = PAL["void"] as Color; var c_jade: Color = PAL["jade"] as Color; var c_dusk: Color = PAL["dusk"] as Color
	for lip: Dictionary in _pit_lips:
		var px: float = float(lip["x"]); var py: float = float(lip["y"])
		if px + ts < min_x or px > max_x or py + ts < min_y or py > max_y:
			continue
		var mask: int = int(lip["mask"]); var hv: int = int(lip["hv"])
		if (mask & 2) != 0:
			ci.draw_rect(Rect2(px, py, 1.0, ts), c_night)
		if (mask & 4) != 0:
			ci.draw_rect(Rect2(px + ts - 1.0, py, 1.0, ts), c_night)
		if (mask & 1) != 0:
			ci.draw_rect(Rect2(px, py, ts, 1.0), c_pine)
			ci.draw_rect(Rect2(px, py + 1.0, ts, 1.0), c_night)
			for dx: int in range(hv & 1, int(ts), 2):
				ci.draw_rect(Rect2(px + float(dx), py + 2.0, 1.0, 1.0), c_void)
			var n_roots: int = 2 + ((hv >> 1) & 1)
			for ri: int in range(n_roots):
				var rx: float = clampf(roundf(2.0 + float(ri) * (11.0 / float(n_roots)) + float((hv >> (ri * 3 + 2)) % 3)), 1.0, ts - 2.0)
				var rk: int = (hv >> (ri * 2 + 18)) % 3
				ci.draw_rect(Rect2(px + rx, py + 1.0, 1.0, 2.0 + float((hv >> (ri * 2 + 12)) % 4)), c_pine if rk == 0 else (c_jade if rk == 1 else c_dusk))


func _draw_kiln_lava_curbs(ci: CanvasItem, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	var ts: float = _tile_size
	var c_stone: Color = PAL["stone"] as Color; var c_apr: Color = PAL["apricot"] as Color
	for cb: Dictionary in _lava_curbs:
		var px: float = float(cb["x"]); var py: float = float(cb["y"])
		if px + ts < min_x or px > max_x or py + ts < min_y or py > max_y:
			continue
		var mask: int = int(cb["mask"]); var hv: int = int(cb["hv"])
		var oa: float = 2.0 + float(hv % 3); var ob: float = 9.0 + float((hv >> 3) % 4)
		for side: int in range(4):
			if (mask & (1 << side)) == 0:
				continue
			if side < 2:
				var ey: float = py if side == 0 else py + ts - 1.0
				ci.draw_rect(Rect2(px, ey, ts, 1.0), c_stone)
				ci.draw_rect(Rect2(px + oa, ey, 3.0, 1.0), c_apr); ci.draw_rect(Rect2(px + ob, ey, 2.0, 1.0), c_apr)
			else:
				var ex: float = px if side == 2 else px + ts - 1.0
				ci.draw_rect(Rect2(ex, py, 1.0, ts), c_stone)
				ci.draw_rect(Rect2(ex, py + oa, 1.0, 3.0), c_apr); ci.draw_rect(Rect2(ex, py + ob, 1.0, 2.0), c_apr)
