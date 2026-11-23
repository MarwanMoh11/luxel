class_name LxWaterFx
extends Node2D
## Pixel-snapped living shoreline foam, moonlight water glints, kiln magma crust,
## floating-island abyss stars, and reactive water ripples (strictly 20 Last Light colours).

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 176.0
const HALF_H: float = 108.0
const MAX_RIPPLES: int = 12

var _island_id: int = 1
var _is_dungeon: bool = false
var _tile_size: int = 16
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _shores: Array[Dictionary] = [] # {x, y, mask, phase}
var _glints: Array[Dictionary] = [] # {x, y, w, phase, spd, tide}
var _abyss: Array[Dictionary] = []  # {x, y, phase, kind} kind: 0=star, 1=magma
var _ripples: Array[Dictionary] = []
var _water_cells: Dictionary = {}
var _sky_accents: LxBiomeSkyAccents = LxBiomeSkyAccents.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -8


func configure(grid: Array[PackedStringArray], tile_size: int, island_id: int, is_dungeon: bool) -> void:
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_tile_size = maxi(8, tile_size)
	_clock = 0.0
	_shores.clear()
	_glints.clear()
	_abyss.clear()
	_ripples.clear()
	_water_cells.clear()
	var h: int = grid.size()
	if h <= 0:
		queue_redraw()
		return
	var w: int = grid[0].size()
	var ts: float = float(_tile_size)
	var use_magma: bool = _island_id == 6
	var use_stars: bool = _island_id in [1, 3, 5, 7, 8] or is_dungeon
	for ty: int in range(h):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(w):
			var t: String = row[tx]
			var hash_v: int = (tx * 73856093 ^ ty * 19349663 ^ _island_id * 83492791) & 0x7FFFFFFF
			if t == "water" or t == "tide":
				_water_cells[Vector2i(tx, ty)] = true
				var mask: int = 0
				if ty > 0 and _is_land(grid[ty - 1][tx]):
					mask |= 1
				if ty < h - 1 and _is_land(grid[ty + 1][tx]):
					mask |= 2
				if tx > 0 and _is_land(row[tx - 1]):
					mask |= 4
				if tx < w - 1 and _is_land(row[tx + 1]):
					mask |= 8
				if mask != 0:
					_shores.append({
						"x": float(tx) * ts, "y": float(ty) * ts,
						"mask": mask, "phase": float(hash_v % 628) * 0.01,
					})
				if (hash_v % (3 if t == "tide" else 4)) == 0:
					_glints.append({
						"x": float(tx) * ts + float((hash_v >> 4) % maxi(1, _tile_size - 5)),
						"y": float(ty) * ts + float((hash_v >> 8) % maxi(1, _tile_size - 2)) + 1.0,
						"w": 3.0 + float((hash_v >> 12) % 3),
						"phase": float((hash_v >> 2) % 628) * 0.01,
						"spd": 1.1 + float((hash_v >> 14) % 4) * 0.35,
						"tide": t == "tide",
					})
			elif (t == "pit" or t == "void") and (use_magma or use_stars):
				var mod_k: int = 5 if (use_magma and t == "pit") else 9
				if (hash_v % mod_k) == 0:
					_abyss.append({
						"x": float(tx) * ts + float((hash_v >> 3) % maxi(1, _tile_size - 3)) + 1.0,
						"y": float(ty) * ts + float((hash_v >> 7) % maxi(1, _tile_size - 3)) + 1.0,
						"phase": float(hash_v % 628) * 0.01,
						"kind": 1 if (use_magma and t == "pit") else 0,
					})
	_sky_accents.configure(grid, _tile_size, _island_id, _is_dungeon)
	queue_redraw()


func spawn_ripple(world_pos: Vector2, col_key: String = "ice", max_r: float = 11.0) -> void:
	if not _is_near_water(world_pos):
		return
	if _ripples.size() >= MAX_RIPPLES:
		_ripples.pop_front()
	_ripples.append({
		"pos": world_pos, "age": 0.0, "dur": 0.42 if max_r <= 12.0 else 0.52, "max_r": max_r,
		"c1": LxPalette.color(col_key, "ice"), "c2": LxPalette.color("sky"),
	})


func _is_near_water(world_pos: Vector2) -> bool:
	if _island_id == 4 and not _is_dungeon:
		return true
	if _water_cells.is_empty():
		return false
	var cx: int = int(floorf(world_pos.x / float(_tile_size)))
	var cy: int = int(floorf(world_pos.y / float(_tile_size)))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if _water_cells.has(Vector2i(cx + dx, cy + dy)):
				return true
	return false


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if _shores.is_empty() and _glints.is_empty() and _abyss.is_empty() and _ripples.is_empty() and _sky_accents.is_empty():
		return
	_clock += dt
	for i: int in range(_ripples.size() - 1, -1, -1):
		var rp: Dictionary = _ripples[i]
		var age: float = float(rp["age"]) + dt
		if age >= float(rp["dur"]):
			_ripples.remove_at(i)
		else:
			rp["age"] = age
	queue_redraw()


func _draw() -> void:
	if _shores.is_empty() and _glints.is_empty() and _abyss.is_empty() and _ripples.is_empty() and _sky_accents.is_empty():
		return
	var min_x: float = _cam_center.x - HALF_W
	var max_x: float = _cam_center.x + HALF_W
	var min_y: float = _cam_center.y - HALF_H
	var max_y: float = _cam_center.y + HALF_H
	var ts: float = float(_tile_size)

	var relit_sea: bool = not _is_dungeon and Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var foam_hi: Color = (PAL["rose"] if (relit_sea and _island_id == 4) else (PAL["lime"] if _island_id == 3 else (PAL["cream"] if _island_id == 7 else PAL["ice"]))) as Color
	var foam_lo: Color = (PAL["ice"] if (relit_sea and _island_id == 4) else (PAL["jade"] if _island_id == 3 else (PAL["teal"] if _island_id == 4 else PAL["sky"]))) as Color
	for sh: Dictionary in _shores:
		var sx: float = float(sh["x"])
		var sy: float = float(sh["y"])
		if sx + ts < min_x or sx > max_x or sy + ts < min_y or sy > max_y:
			continue
		var ph: float = float(sh["phase"])
		var wv: float = sin(_clock * 2.1 + ph)
		var inset: float = 1.0 if wv > 0.25 else 0.0
		var col: Color = foam_hi if wv > 0.45 else foam_lo
		var m: int = int(sh["mask"])
		if (m & 1) != 0:
			draw_rect(Rect2(sx + 2.0, sy + inset, ts - 4.0, 1.0), col)
		if (m & 2) != 0:
			draw_rect(Rect2(sx + 2.0, sy + ts - 1.0 - inset, ts - 4.0, 1.0), col)
		if (m & 4) != 0:
			draw_rect(Rect2(sx + inset, sy + 2.0, 1.0, ts - 4.0), col)
		if (m & 8) != 0:
			draw_rect(Rect2(sx + ts - 1.0 - inset, sy + 2.0, 1.0, ts - 4.0), col)

	var gl_hi: Color = (PAL["cream"] if relit_sea else (PAL["gold"] if _island_id in [1, 2] else (PAL["lime"] if _island_id in [3, 4] else PAL["cream"]))) as Color
	var gl_lo: Color = (PAL["gold"] if relit_sea else (PAL["sky"] if _island_id in [1, 2, 5, 7, 8] else PAL["teal"])) as Color
	for gl: Dictionary in _glints:
		var gx: float = float(gl["x"])
		var gy: float = float(gl["y"])
		if gx < min_x or gx > max_x or gy < min_y or gy > max_y:
			continue
		var s: float = sin(_clock * float(gl["spd"]) + float(gl["phase"]))
		if s < -0.15:
			continue
		var dx: float = roundf(s * 2.0)
		var wpx: float = float(gl["w"]) if s > 0.35 else maxf(2.0, float(gl["w"]) - 1.0)
		var col: Color = gl_hi if s > 0.72 else ((PAL["apricot"] if relit_sea else PAL["ice"]) if bool(gl["tide"]) and s > 0.30 else gl_lo)
		draw_rect(Rect2(roundf(gx + dx), gy, wpx, 1.0), col)

	for ab: Dictionary in _abyss:
		var ax: float = float(ab["x"])
		var ay: float = float(ab["y"])
		if ax < min_x or ax > max_x or ay < min_y or ay > max_y:
			continue
		var p: float = sin(_clock * 1.4 + float(ab["phase"]))
		if int(ab["kind"]) == 1:
			if p > 0.15:
				var mc: Color = (PAL["cream"] if p > 0.78 else (PAL["gold"] if p > 0.48 else PAL["apricot"])) as Color if relit_sea else (PAL["apricot"] if p > 0.75 else (PAL["coral"] if p > 0.45 else PAL["wine"])) as Color
				draw_rect(Rect2(ax, ay, 2.0 if p > 0.55 else 1.0, 1.0), mc)
		else:
			if p > 0.25:
				var sc: Color = (PAL["cream"] if p > 0.78 else PAL["gold"]) as Color if (relit_sea and _island_id == 8) else _abyss_star_color(p)
				draw_rect(Rect2(ax, ay, 2.0 if ((_island_id == 5 or (relit_sea and _island_id == 8)) and p > 0.88) else 1.0, 1.0), sc)

	_sky_accents.draw_accents(self, _clock, _cam_center, relit_sea)
	for rp: Dictionary in _ripples:
		var u: float = clampf(float(rp["age"]) / maxf(0.01, float(rp["dur"])), 0.0, 1.0)
		var r: float = roundf(lerpf(2.0, float(rp.get("max_r", 11.0)), u))
		draw_arc((rp["pos"] as Vector2).round(), r, 0.0, TAU, 16, (rp["c1"] as Color) if u < 0.45 else (rp["c2"] as Color), 1.0, false)


func _abyss_star_color(p: float) -> Color:
	match _island_id:
		3:
			return (PAL["lime"] if p > 0.82 else (PAL["jade"] if p > 0.55 else PAL["pine"])) as Color
		5:
			return (PAL["cream"] if p > 0.88 else (PAL["gold"] if p > 0.62 else PAL["sky"])) as Color
		7:
			return (PAL["cream"] if p > 0.84 else (PAL["ice"] if p > 0.56 else PAL["blue"])) as Color
		8:
			return (PAL["gold"] if p > 0.88 else (PAL["rose"] if p > 0.62 else PAL["plum"])) as Color
		_:
			return (PAL["ice"] if p > 0.85 else (PAL["sky"] if p > 0.58 else PAL["dusk"])) as Color


static func _is_land(tile_type: String) -> bool:
	return tile_type in ["floor", "ground", "path", "wall", "cracked", "bramble"]
