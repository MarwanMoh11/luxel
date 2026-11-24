class_name LxWaterFx
extends Node2D
## Pixel-snapped living shoreline foam, moonlight water glints, kiln magma crust,
## floating-island abyss stars, and reactive water ripples (strictly 20 Last Light colours).

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 176.0
const HALF_H: float = 108.0
const MAX_RIPPLES: int = 12
const MAX_SPRAYS: int = 28

static var active_instance: LxWaterFx = null

var _island_id: int = 1
var _is_dungeon: bool = false
var _tile_size: int = 16
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _shores: Array[Dictionary] = [] # {x, y, mask, phase}
var _glints: Array[Dictionary] = [] # {x, y, w, phase, spd, tide}
var _abyss: Array[Dictionary] = []  # {x, y, phase, kind} kind: 0=star, 1=magma
var _ripples: Array[Dictionary] = []
var _sprays: Array[Dictionary] = [] # {pos, vel, age, dur, col, sz}
var _water_cells: Dictionary = {}
var _lava_cells: Dictionary = {}
var _spray_sfx_cd: float = 0.0
var _lan_skim_cd: float = 0.0
var _lan_hang_cd: float = 0.0
var _sky_accents: LxBiomeSkyAccents = LxBiomeSkyAccents.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -8
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func configure(grid: Array[PackedStringArray], tile_size: int, island_id: int, is_dungeon: bool) -> void:
	active_instance = self
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_tile_size = maxi(8, tile_size)
	_clock = 0.0
	_shores.clear()
	_glints.clear()
	_abyss.clear()
	_ripples.clear()
	_sprays.clear()
	_water_cells.clear()
	_lava_cells.clear()
	_spray_sfx_cd = 0.0
	_lan_skim_cd = 0.0
	_lan_hang_cd = 0.0
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
				if use_magma:
					_lava_cells[Vector2i(tx, ty)] = true
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


func _push_ripple(world_pos: Vector2, col_key: String, max_r: float, dur: float = -1.0, v_wake: bool = false, wake_dir: Vector2 = Vector2.RIGHT, col2_override: String = "") -> void:
	if _ripples.size() >= MAX_RIPPLES:
		_ripples.pop_front()
	var c1_k: String = col_key
	var c2_k: String = col2_override if not col2_override.is_empty() else "sky"
	if col_key == "ice" and col2_override.is_empty():
		if _island_id == 3:
			c1_k = "lime"; c2_k = "jade"
		elif _island_id == 4:
			c1_k = "rose"; c2_k = "ice"
	_ripples.append({
		"pos": world_pos, "age": 0.0,
		"dur": dur if dur > 0.0 else (0.42 if max_r <= 12.0 else 0.52),
		"max_r": max_r,
		"c1": LxPalette.color(c1_k, "ice"), "c2": LxPalette.color(c2_k, "sky"),
		"v_wake": v_wake, "dir": wake_dir.normalized() if wake_dir.length_squared() > 0.0001 else Vector2.RIGHT,
	})


func _push_spray(at_pos: Vector2, vel: Vector2, dur: float, col: Color, sz: float = 1.0) -> void:
	if _sprays.size() >= MAX_SPRAYS:
		_sprays.pop_front()
	_sprays.append({"pos": at_pos, "vel": vel, "age": 0.0, "dur": dur, "col": col, "sz": sz})


func _spray_color(is_lava: bool = false, warm: bool = false) -> Color:
	if warm:
		return (PAL["cream"] if randf() < 0.42 else PAL["gold"]) as Color
	if is_lava or _island_id == 6:
		var r6: float = randf()
		return (PAL["gold"] if r6 < 0.28 else (PAL["apricot"] if r6 < 0.64 else PAL["coral"])) as Color
	if _island_id == 3:
		return (PAL["lime"] if randf() < 0.55 else PAL["jade"]) as Color
	if _island_id == 4:
		return (PAL["rose"] if randf() < 0.52 else PAL["ice"]) as Color
	var r0: float = randf()
	return (PAL["cream"] if r0 < 0.25 else (PAL["ice"] if r0 < 0.65 else PAL["sky"])) as Color


func spawn_ripple(world_pos: Vector2, col_key: String = "ice", max_r: float = 11.0) -> void:
	if not _is_near_water(world_pos):
		return
	_push_ripple(world_pos, col_key, max_r)


func spawn_shore_spray(world_pos: Vector2, move_dir: Vector2, burst: bool = false) -> void:
	if _water_cells.is_empty():
		return
	var ts: float = float(_tile_size)
	var cx: int = int(floorf(world_pos.x / ts))
	var cy: int = int(floorf(world_pos.y / ts))
	var best_d2: float = 576.0
	var best_p: Vector2 = Vector2.ZERO
	var found: bool = false
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var cell := Vector2i(cx + dx, cy + dy)
			if not _water_cells.has(cell):
				continue
			var x0: float = float(cell.x) * ts
			var y0: float = float(cell.y) * ts
			var clamped := Vector2(clampf(world_pos.x, x0 + 1.0, x0 + ts - 2.0), clampf(world_pos.y, y0 + 1.0, y0 + ts - 2.0))
			var d2: float = clamped.distance_squared_to(world_pos)
			if d2 < best_d2:
				best_d2 = d2
				best_p = clamped
				found = true
	if not found:
		return
	_push_ripple(best_p, "ice", 10.0 if burst else 7.5, 0.38 if burst else 0.32)
	var mdir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 0.0001 else Vector2.UP
	var cnt: int = randi_range(4, 5) if burst else randi_range(2, 3)
	for k: int in range(cnt):
		var spread: float = 18.0 if burst else 13.0
		var v := mdir * randf_range(10.0, 26.0 if burst else 18.0) + Vector2(randf_range(-spread, spread), randf_range(-34.0 if burst else -26.0, -14.0))
		_push_spray(best_p + Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)), v, randf_range(0.24, 0.36), _spray_color(false, false), 2.0 if (burst and k == 0) else 1.0)
	if _spray_sfx_cd <= 0.0 and Lx.audio != null:
		_spray_sfx_cd = 0.28
		Lx.audio.play_sfx("footstep_water", best_p, true)


func on_bolt_skim(world_pos: Vector2, dir: Vector2, is_blue: bool) -> void:
	var cell := Vector2i(int(floorf(world_pos.x / float(_tile_size))), int(floorf(world_pos.y / float(_tile_size))))
	var over_water: bool = _water_cells.has(cell)
	var over_lava: bool = (not over_water) and _island_id == 6 and _lava_cells.has(cell)
	if not over_water and not over_lava:
		return
	var dn: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	var perp := Vector2(-dn.y, dn.x)
	var c1: String = "coral" if over_lava else ("ice" if is_blue else "ice")
	var c2: String = "apricot" if over_lava else ("sky" if is_blue else "")
	_push_ripple(world_pos, c1, 7.0, 0.28, true, dn, c2)
	for sgn: float in [-1.0, 1.0]:
		var sv: Vector2 = perp * sgn * randf_range(14.0, 24.0) - dn * randf_range(4.0, 10.0) + Vector2(0.0, randf_range(-24.0, -14.0))
		var scol: Color = (PAL["ice"] if is_blue else _spray_color(false, false)) as Color if not over_lava else _spray_color(true, false)
		_push_spray(world_pos, sv, randf_range(0.20, 0.30), scol, 1.0)


func _tick_lantern_skim(dt: float) -> void:
	if _lan_skim_cd > 0.0:
		_lan_skim_cd = maxf(0.0, _lan_skim_cd - dt)
	if _lan_hang_cd > 0.0:
		_lan_hang_cd = maxf(0.0, _lan_hang_cd - dt)
	if (_water_cells.is_empty() and _lava_cells.is_empty()) or Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if not (lan_v is LxLantern) or not is_instance_valid(lan_v as Object):
		return
	var lan: LxLantern = lan_v as LxLantern
	if not lan.is_out():
		return
	var lpos: Vector2 = lan.pos
	var lcell := Vector2i(int(floorf(lpos.x / float(_tile_size))), int(floorf(lpos.y / float(_tile_size))))
	var over_w: bool = _water_cells.has(lcell)
	var over_l: bool = (not over_w) and _island_id == 6 and _lava_cells.has(lcell)
	if not over_w and not over_l:
		return
	if lan.vel.length_squared() > 400.0:
		if _lan_skim_cd <= 0.0:
			_lan_skim_cd = 0.10
			var ldir: Vector2 = lan.vel.normalized()
			var lperp := Vector2(-ldir.y, ldir.x)
			_push_ripple(lpos, "gold", 8.0, 0.34, true, ldir, "cream")
			for sgn: float in [-1.0, 1.0]:
				var lv: Vector2 = lperp * sgn * randf_range(12.0, 20.0) - ldir * 6.0 + Vector2(0.0, randf_range(-20.0, -12.0))
				_push_spray(lpos, lv, 0.24, _spray_color(over_l, true), 1.0)
	elif lan.is_hanging():
		if _lan_hang_cd <= 0.0:
			_lan_hang_cd = 0.90
			_push_ripple(lpos + Vector2(0.0, 2.0), "gold", 10.0, 0.62, false, Vector2.RIGHT, "cream")


func _is_near_water(world_pos: Vector2) -> bool:
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
	if _spray_sfx_cd > 0.0:
		_spray_sfx_cd = maxf(0.0, _spray_sfx_cd - dt)
	_tick_lantern_skim(dt)
	if _shores.is_empty() and _glints.is_empty() and _abyss.is_empty() and _ripples.is_empty() and _sprays.is_empty() and _sky_accents.is_empty():
		return
	_clock += dt
	for i: int in range(_ripples.size() - 1, -1, -1):
		var rp: Dictionary = _ripples[i]
		var age: float = float(rp["age"]) + dt
		if age >= float(rp["dur"]):
			_ripples.remove_at(i)
		else:
			rp["age"] = age
	for j: int in range(_sprays.size() - 1, -1, -1):
		var sp: Dictionary = _sprays[j]
		var sage: float = float(sp["age"]) + dt
		if sage >= float(sp["dur"]):
			_sprays.remove_at(j)
		else:
			sp["age"] = sage
			var sv: Vector2 = sp["vel"] as Vector2
			sv.y += 85.0 * dt
			sp["vel"] = sv
			sp["pos"] = (sp["pos"] as Vector2) + sv * dt
	queue_redraw()


func _draw() -> void:
	if _shores.is_empty() and _glints.is_empty() and _abyss.is_empty() and _ripples.is_empty() and _sprays.is_empty() and _sky_accents.is_empty():
		return
	var min_x: float = _cam_center.x - HALF_W
	var max_x: float = _cam_center.x + HALF_W
	var min_y: float = _cam_center.y - HALF_H
	var max_y: float = _cam_center.y + HALF_H
	var ts: float = float(_tile_size)

	var relit_sea: bool = not _is_dungeon and Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var surging2: bool = _island_id == 2 and not _is_dungeon and LxBiomeRules.active_instance != null and is_instance_valid(LxBiomeRules.active_instance) and LxBiomeRules.active_instance.tide_surging
	var foam_hi: Color = (PAL["cream"] if surging2 else (PAL["rose"] if (relit_sea and _island_id == 4) else (PAL["lime"] if _island_id == 3 else (PAL["cream"] if _island_id == 7 else PAL["ice"])))) as Color
	var foam_lo: Color = (PAL["ice"] if surging2 else (PAL["ice"] if (relit_sea and _island_id == 4) else (PAL["jade"] if _island_id == 3 else (PAL["teal"] if _island_id == 4 else PAL["sky"])))) as Color
	var foam_spd: float = 3.2 if (surging2 and not LxHudFx.flash_reduced()) else 2.1
	for sh: Dictionary in _shores:
		var sx: float = float(sh["x"])
		var sy: float = float(sh["y"])
		if sx + ts < min_x or sx > max_x or sy + ts < min_y or sy > max_y:
			continue
		var ph: float = float(sh["phase"])
		var wv: float = sin(_clock * foam_spd + ph)
		var inset: float = 1.0 if wv > 0.25 else 0.0
		var col: Color = foam_hi if wv > 0.45 else foam_lo
		var m: int = int(sh["mask"])
		var south_off: float = 0.0 if _is_dungeon else 5.0
		if (m & 1) != 0:
			draw_rect(Rect2(sx + 2.0, sy + south_off + inset, ts - 4.0, 1.0), col)
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
				var sc: Color = (PAL["cream"] if p > 0.78 else PAL["gold"]) as Color if (relit_sea and (_island_id == 8 or p > 0.84)) else _abyss_star_color(p)
				var wide_st: bool = (_island_id == 5 or (relit_sea and _island_id in [1, 5, 7, 8])) and p > 0.88
				draw_rect(Rect2(ax, ay, 2.0 if wide_st else 1.0, 1.0), sc)
				if relit_sea and p > 0.92:
					draw_rect(Rect2(ax, ay - 1.0, 1.0, 3.0), Color(PAL["gold"] as Color, 0.55))

	_sky_accents.draw_accents(self, _clock, _cam_center, relit_sea)
	var fr_a: float = 0.75 if LxHudFx.flash_reduced() else 1.0
	for rp: Dictionary in _ripples:
		var rpos: Vector2 = (rp["pos"] as Vector2).round()
		if rpos.x < min_x - 16.0 or rpos.x > max_x + 16.0 or rpos.y < min_y - 16.0 or rpos.y > max_y + 16.0:
			continue
		var u: float = clampf(float(rp["age"]) / maxf(0.01, float(rp["dur"])), 0.0, 1.0)
		var rx: float = roundf(lerpf(2.0, float(rp.get("max_r", 11.0)), u))
		var rcol: Color = (rp["c1"] as Color) if u < 0.45 else (rp["c2"] as Color)
		var ra: float = clampf((1.0 - u) * 0.92 * fr_a, 0.0, 1.0)
		_draw_pixel_ripple(rpos, rx, rcol, ra)
		if bool(rp.get("v_wake", false)):
			var wdir: Vector2 = rp.get("dir", Vector2.RIGHT) as Vector2
			var arm_len: int = clampi(int(roundf(lerpf(3.0, 6.0, u))), 2, 6)
			for sgn: float in [-1.0, 1.0]:
				var arm: Vector2 = (-wdir).rotated(sgn * 0.55)
				for s: int in range(1, arm_len + 1):
					var vp: Vector2 = (rpos + arm * float(s) * 1.4).round()
					draw_rect(Rect2(vp, Vector2(1.0, 1.0)), Color(rcol, ra * (1.0 - float(s) / float(arm_len + 2))))
	for sp: Dictionary in _sprays:
		var sp_p: Vector2 = (sp["pos"] as Vector2).round()
		if sp_p.x < min_x or sp_p.x > max_x or sp_p.y < min_y or sp_p.y > max_y:
			continue
		var su: float = clampf(float(sp["age"]) / maxf(0.01, float(sp["dur"])), 0.0, 1.0)
		var ssz: float = float(sp["sz"])
		draw_rect(Rect2(sp_p, Vector2(ssz, ssz)), Color(sp["col"] as Color, (1.0 - su) * 0.92 * fr_a))


func _draw_pixel_ripple(center: Vector2, rx: float, col: Color, alpha: float) -> void:
	var ry: float = maxf(1.0, rx * 0.6)
	var steps: int = clampi(int(roundf(rx * 2.2)), 8, 24)
	var c := Color(col, alpha)
	for k: int in range(steps):
		var ang: float = (TAU * float(k)) / float(steps)
		var px: float = roundf(center.x + cos(ang) * rx)
		var py: float = roundf(center.y + sin(ang) * ry)
		draw_rect(Rect2(px, py, 1.0, 1.0), c)


func _abyss_star_color(p: float) -> Color:
	match _island_id:
		2:
			return (PAL["cream"] if p > 0.86 else (PAL["ice"] if p > 0.56 else PAL["blue"])) as Color
		3:
			return (PAL["lime"] if p > 0.82 else (PAL["jade"] if p > 0.55 else PAL["pine"])) as Color
		4:
			return (PAL["rose"] if p > 0.80 else (PAL["ice"] if p > 0.54 else PAL["teal"])) as Color
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
