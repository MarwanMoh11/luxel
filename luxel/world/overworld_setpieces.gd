class_name LxOverworldSetpieces
extends Node2D
## Monumental, progress-reactive living architectural setpieces unique to each of the 8 overworlds.
## Renders beneath actors (z_index = -4) as crisp pixel-stepped motifs strictly masked to terrain.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 220.0
const HALF_H: float = 150.0

var _rules: LxBiomeRules = null
var _region: Node = null
var _island_id: int = 1
var _active: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _door_pos: Vector2 = Vector2.ZERO
var _spawn_pos: Vector2 = Vector2.ZERO
var _fresnel_origins: Array[Vector2] = []
var _moon_discs: Array[Vector2] = []
var _spine_points: Array[Vector2] = []
var _beacons: Array[Node] = []
var _koi: Array[Dictionary] = []
var _pulse_rings: Array[Dictionary] = [] # {pos, age, dur, r0, r1, col}
var _lit_spine: Dictionary = {} # Island 8 pilgrimage stepping stones lit by Wick
var _setpiece_cd: float = 0.0
var _dial_spin_t: float = 0.0
var _wildlife: LxOverworldWildlife = null
var _chimes: LxBellChimes = null
var _discoveries: LxBiomeDiscoveries = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -4

func configure(rules: LxBiomeRules, region_node: Node) -> void:
	_rules = rules; _region = region_node
	_island_id = rules.island_id if rules != null else 1
	_active = rules != null and not rules.is_dungeon
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_door_pos = _default_anchor(_island_id)
	var sp_v: Variant = _region.get("spawn_pos") if (_region != null and is_instance_valid(_region)) else null
	_spawn_pos = (sp_v as Vector2) if (sp_v is Vector2 and (sp_v as Vector2) != Vector2.ZERO) else _cam_center
	_fresnel_origins.clear(); _moon_discs.clear(); _spine_points.clear(); _beacons.clear()
	_koi.clear(); _pulse_rings.clear(); _lit_spine.clear()
	_setpiece_cd = 0.0; _dial_spin_t = 0.0
	if _active and _region != null and _region.has_method("get_interactables"):
		var items_v: Variant = _region.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if it is LxBeacon and is_instance_valid(it): _beacons.append(it as Node)
				elif it is LxInteractable and is_instance_valid(it):
					var obj: LxInteractable = it as LxInteractable
					if obj.id.begins_with("door_dungeon_") or obj.id == "door_ward_barrier": _door_pos = obj.pos
	if _active and _island_id == 2:
		_fresnel_origins.append(_door_pos + Vector2(0.0, -18.0))
		var mid_target: Vector2 = _spawn_pos.lerp(_door_pos, 0.5)
		var best_b: Vector2 = mid_target; var best_d: float = INF
		for bn: Node in _beacons:
			if bn is LxBeacon and is_instance_valid(bn):
				var bp: Vector2 = (bn as LxBeacon).pos
				if bp.distance_to(mid_target) < best_d:
					best_d = bp.distance_to(mid_target); best_b = bp + Vector2(0.0, -14.0)
		_fresnel_origins.append(best_b)
	elif _active and _island_id == 4:
		var pools: Array[Vector2] = _sample_interior_water(6, 2, 128.0, 8)
		if pools.size() < 4: pools = _sample_interior_water(6, 1, 96.0, 8)
		var rng := RandomNumberGenerator.new(); rng.seed = 40471
		for k: int in range(pools.size()):
			_koi.append({
				"center": pools[k], "rx": rng.randf_range(16.0, 28.0), "ry": rng.randf_range(10.0, 18.0),
				"spd": rng.randf_range(0.36, 0.62) * (1.0 if k % 2 == 0 else -1.0), "phase": rng.randf_range(0.0, TAU),
				"col": "coral" if k % 3 == 0 else ("gold" if k % 3 == 1 else "ice"), "burst_t": 0.0, "cd": 0.0,
			})
	elif _active and _island_id == 7:
		_moon_discs = _sample_interior_water(2, 2, 220.0, 10)
		if _moon_discs.size() < 2: _moon_discs = _sample_interior_water(2, 1, 120.0, 10)
		if _moon_discs.is_empty():
			var c7: Vector2 = _rules.bounds.get_center() if _rules != null else _cam_center
			_moon_discs = [c7 + Vector2(-120.0, 0.0), c7 + Vector2(120.0, 0.0)]
	elif _active and _island_id == 8:
		_spine_points = _build_pilgrimage_spine()
	if _wildlife == null and get_parent() != null:
		_wildlife = LxOverworldWildlife.new(); _wildlife.name = "OverworldWildlife"; get_parent().add_child(_wildlife)
	if _wildlife != null: _wildlife.configure(rules, region_node)
	if _chimes == null and get_parent() != null:
		_chimes = LxBellChimes.new(); _chimes.name = "BellChimes"; get_parent().add_child(_chimes)
	if _chimes != null: _chimes.configure(rules, region_node)
	if _discoveries == null and get_parent() != null:
		_discoveries = LxBiomeDiscoveries.new(); _discoveries.name = "BiomeDiscoveries"; get_parent().add_child(_discoveries)
	if _discoveries != null: _discoveries.configure(rules, region_node, _door_pos)
	queue_redraw()


func _sample_interior_water(limit: int, clear_r: int, min_sep: float, max_shore_tiles: int = 9) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _region == null or not is_instance_valid(_region): return out
	var grid_v: Variant = _region.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty(): return out
	var grid: Array = grid_v as Array
	var h: int = grid.size(); var w: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(_region.get("tile_size")) if _region.get("tile_size") != null else 16.0
	var cands: Array[Dictionary] = []
	for ty: int in range(clear_r + 1, h - clear_r - 1, 2):
		for tx: int in range(clear_r + 1, w - clear_r - 1, 2):
			if not _is_open_water(grid, tx, ty, clear_r): continue
			var shore_d: int = _nearest_walkable_tiles(grid, w, h, tx, ty, max_shore_tiles)
			if shore_d >= 0: cands.append({"p": Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts), "d": shore_d})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["d"]) - 4.0) < absf(float(b["d"]) - 4.0))
	var sep_sq: float = min_sep * min_sep
	for c: Dictionary in cands:
		if out.size() >= limit: break
		var p: Vector2 = c["p"] as Vector2
		var ok: bool = true
		for prev: Vector2 in out:
			if prev.distance_squared_to(p) < sep_sq: ok = false; break
		if ok: out.append(p)
	return out

static func _is_open_water(grid: Array, tx: int, ty: int, r: int) -> bool:
	for dy: int in range(-r, r + 1):
		var row: PackedStringArray = grid[ty + dy] as PackedStringArray
		for dx: int in range(-r, r + 1):
			if row[tx + dx] != "water": return false
	return true

static func _nearest_walkable_tiles(grid: Array, w: int, h: int, tx: int, ty: int, max_r: int) -> int:
	var best: int = 999
	for dy: int in range(-max_r, max_r + 1, 2):
		var yy: int = ty + dy
		if yy < 0 or yy >= h: continue
		var row: PackedStringArray = grid[yy] as PackedStringArray
		for dx: int in range(-max_r, max_r + 1, 2):
			var xx: int = tx + dx
			if xx >= 0 and xx < w and row[xx] in ["ground", "path", "bridge"]:
				best = mini(best, maxi(absi(dx), absi(dy)))
	return best if best < 999 else -1


func _build_pilgrimage_spine() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _region == null or not is_instance_valid(_region):
		return out
	var grid_v: Variant = _region.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		return out
	var grid: Array = grid_v as Array
	var h: int = grid.size()
	var w: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(_region.get("tile_size")) if _region.get("tile_size") != null else 16.0
	var b_pts: Array[Vector2] = []
	for bn: Node in _beacons:
		if bn is LxBeacon and is_instance_valid(bn):
			b_pts.append((bn as LxBeacon).pos)
	b_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(_spawn_pos) < b.distance_squared_to(_spawn_pos))
	var poly: Array[Vector2] = [_spawn_pos]
	poly.append_array(b_pts)
	poly.append(_door_pos)
	for seg: int in range(poly.size() - 1):
		var a: Vector2 = poly[seg]
		var b: Vector2 = poly[seg + 1]
		var steps: int = maxi(1, int(floor(a.distance_to(b) / 48.0)))
		for s: int in range(steps + 1):
			if out.size() >= 22:
				return out
			var snapped: Vector2 = _snap_spine_tile(grid, w, h, ts, a.lerp(b, float(s) / float(steps)), 4)
			if snapped != Vector2.ZERO and (out.is_empty() or out[out.size() - 1].distance_to(snapped) >= 36.0):
				out.append(snapped)
	return out


static func _snap_spine_tile(grid: Array, w: int, h: int, ts: float, p: Vector2, rad: int) -> Vector2:
	var cx: int = int(floor(p.x / maxf(ts, 1.0)))
	var cy: int = int(floor(p.y / maxf(ts, 1.0)))
	var best_path := Vector2.ZERO; var best_path_d: float = INF
	var best_any := Vector2.ZERO; var best_any_d: float = INF
	for dy: int in range(-rad, rad + 1):
		var ty: int = cy + dy
		if ty < 0 or ty >= h: continue
		var row: PackedStringArray = grid[ty] as PackedStringArray
		for dx: int in range(-rad, rad + 1):
			var tx: int = cx + dx
			if tx < 0 or tx >= w: continue
			var t: String = row[tx]
			if t not in ["path", "bridge", "ground"]: continue
			var cand := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
			var d: float = cand.distance_squared_to(p)
			if t == "path" and d < best_path_d:
				best_path_d = d; best_path = cand
			elif d < best_any_d:
				best_any_d = d; best_any = cand
	return best_path if best_path != Vector2.ZERO else best_any


static func _default_anchor(isl: int) -> Vector2:
	match isl:
		1: return Vector2(640.0, 232.0)
		2: return Vector2(1040.0, 168.0)
		3: return Vector2(352.0, 120.0)
		4: return Vector2(608.0, 248.0)
		5: return Vector2(544.0, 488.0)
		6: return Vector2(1312.0, 168.0)
		7: return Vector2(672.0, 184.0)
		_: return Vector2(336.0, 168.0)


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if _wildlife != null and is_instance_valid(_wildlife): _wildlife.tick(dt, cam_center)
	if _chimes != null and is_instance_valid(_chimes): _chimes.tick(dt, cam_center)
	if _discoveries != null and is_instance_valid(_discoveries): _discoveries.tick(dt, cam_center)
	if not _active or dt <= 0.0:
		return
	_clock += dt
	_setpiece_cd = maxf(0.0, _setpiece_cd - dt)
	_dial_spin_t = maxf(0.0, _dial_spin_t - dt)
	for i: int in range(_pulse_rings.size() - 1, -1, -1):
		var pr: Dictionary = _pulse_rings[i]
		pr["age"] = float(pr["age"]) + dt
		if float(pr["age"]) >= float(pr["dur"]):
			_pulse_rings.remove_at(i)
	_tick_setpiece_interactions(dt)
	queue_redraw()


func _tick_setpiece_interactions(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if w == null or w.dead or _rules == null:
		return
	var wp: Vector2 = w.global_position
	var lp: Vector2 = w.lantern.pos if (w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out()) else Vector2(-9999.0, -9999.0)
	match _island_id:
		1:
			var dial_c := Vector2(640.0, 396.0)
			if _setpiece_cd <= 0.0 and ((w.is_dashing() and wp.distance_to(dial_c) <= 28.0) or lp.distance_to(dial_c) <= 26.0):
				_trigger_sundial_chime(dial_c, w)
		2:
			_rules.beam_buff_t = maxf(0.0, _rules.beam_buff_t - dt)
			for idx: int in range(_fresnel_origins.size()):
				var orig: Vector2 = _fresnel_origins[idx]
				var ang: float = (_rules.bounds.get_center() - orig).angle() + sin(_clock * (0.34 if idx == 0 else -0.44) + float(idx) * 1.4) * 0.85
				var d_v: Vector2 = wp - orig
				if d_v.length() <= (250.0 if idx == 0 else 145.0) and d_v.length() >= 18.0 and absf(wrapf(d_v.angle() - ang, -PI, PI)) <= (0.22 if idx == 0 else 0.16):
					var fresh: bool = _rules.beam_buff_t <= 0.05 and _setpiece_cd <= 0.0
					_rules.beam_buff_t = maxf(_rules.beam_buff_t, 1.2)
					if fresh:
						_setpiece_cd = 3.2
						_pulse_rings.append({"pos": wp, "age": 0.0, "dur": 0.42, "r0": 4.0, "r1": 20.0, "col": "ice"})
						if Lx.audio != null: Lx.audio.play_sfx("prop_chime", wp, true)
					break
		3:
			if _setpiece_cd <= 0.0 and w.is_dashing():
				for bn: Node in _beacons:
					if bn is LxBeacon and is_instance_valid(bn) and ((bn as LxBeacon).lit or _is_relit()):
						if wp.distance_to((bn as LxBeacon).pos.lerp(_door_pos, 0.5)) <= 44.0:
							_setpiece_cd = 2.4
							_pulse_rings.append({"pos": wp, "age": 0.0, "dur": 0.44, "r0": 4.0, "r1": 22.0, "col": "lime"})
							if w.move_sunflare != null and w.move_sunflare.unlocked:
								w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 4.0)
							if Lx.audio != null: Lx.audio.play_sfx("prop_chime", wp, true)
							break
		4:
			for k: Dictionary in _koi:
				k["cd"] = maxf(0.0, float(k.get("cd", 0.0)) - dt)
				k["burst_t"] = maxf(0.0, float(k.get("burst_t", 0.0)) - dt)
				if float(k["cd"]) <= 0.0 and (w.is_gliding() or w.is_dashing()):
					var cen: Vector2 = k["center"] as Vector2
					if wp.distance_to(cen) <= 42.0:
						k["cd"] = 3.2; k["burst_t"] = 1.4
						_pulse_rings.append({"pos": cen, "age": 0.0, "dur": 0.48, "r0": 4.0, "r1": 22.0, "col": "rose"})
						if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
							LxBiomeMechanics.active_instance.tailwind_t = maxf(LxBiomeMechanics.active_instance.tailwind_t, 2.0)
						if Lx.audio != null: Lx.audio.play_sfx("prop_chime", cen, true)
			var dv4: Vector2 = wp - _door_pos
			if dv4.length() <= 175.0 and dv4.length() >= 14.0 and absf(wrapf(dv4.angle() - (_rules.bounds.get_center() - _door_pos).angle(), -PI, PI)) <= 0.34:
				if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
					LxBiomeMechanics.active_instance.tailwind_t = maxf(LxBiomeMechanics.active_instance.tailwind_t, 0.8)
		5:
			if _setpiece_cd <= 0.0:
				for orb: Vector2 in _orrery_inner_orbs():
					if wp.distance_to(orb) <= 22.0 or lp.distance_to(orb) <= 22.0:
						_trigger_orrery_orb(orb, w); break
		6:
			if _setpiece_cd <= 0.0 and _rules.vent_cycle >= 0.52 and w.is_dashing():
				for bn6: Node in _beacons:
					if bn6 is LxBeacon and is_instance_valid(bn6) and wp.distance_to((bn6 as LxBeacon).pos.lerp(_door_pos, 0.5)) <= 44.0:
						_setpiece_cd = 3.0
						_pulse_rings.append({"pos": wp, "age": 0.0, "dur": 0.45, "r0": 5.0, "r1": 22.0, "col": "coral"})
						if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
							LxBiomeMechanics.active_instance.grant_molten_overdrive(1)
						if Lx.audio != null: Lx.audio.play_sfx("forge_gust", wp, true)
						break
		7:
			if _setpiece_cd <= 0.0 and w.is_dashing():
				for mc: Vector2 in _moon_discs:
					if wp.distance_to(mc) <= 64.0:
						_trigger_moon_disc(mc); break
		8:
			for step: int in range(_spine_points.size()):
				if _lit_spine.has(step): continue
				var sp: Vector2 = _spine_points[step]
				if wp.distance_to(sp) <= 26.0:
					_lit_spine[step] = true
					_pulse_rings.append({"pos": sp, "age": 0.0, "dur": 0.45, "r0": 3.0, "r1": 18.0, "col": "gold"})
					if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
						LxDarknessLayer.active_instance.add_burst_light(sp, 68.0, 0.78 if LxHudFx.flash_reduced() else 1.12, 0.42)
					if Lx.audio != null: Lx.audio.play_sfx("prop_chime", sp, true)
					break


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick) -> bool:
	if not _active or _setpiece_cd > 0.0 or _rules == null:
		return false
	match _island_id:
		1:
			var dial_c := Vector2(640.0, 396.0)
			if Geometry2D.get_closest_point_to_segment(dial_c, from_p, to_p).distance_to(dial_c) <= 22.0:
				_trigger_sundial_chime(dial_c, w); return true
		5:
			for orb: Vector2 in _orrery_inner_orbs():
				if Geometry2D.get_closest_point_to_segment(orb, from_p, to_p).distance_to(orb) <= 16.0:
					_trigger_orrery_orb(orb, w); return true
		7:
			for mc: Vector2 in _moon_discs:
				if Geometry2D.get_closest_point_to_segment(mc, from_p, to_p).distance_to(mc) <= 44.0:
					_trigger_moon_disc(mc); return true
	return false


func _orrery_inner_orbs() -> Array[Vector2]:
	var c: Vector2 = _door_pos.round()
	var rot: float = _clock * 0.16
	var out: Array[Vector2] = []
	for seg: int in range(4):
		out.append((c + Vector2.from_angle(rot + float(seg) * (PI * 0.5)) * 148.0).round())
	return out


func _trigger_sundial_chime(dial_c: Vector2, w: LxWick) -> void:
	_setpiece_cd = 4.2; _dial_spin_t = 0.85
	_pulse_rings.append({"pos": dial_c, "age": 0.0, "dur": 0.58, "r0": 6.0, "r1": 36.0, "col": "gold"})
	if Lx.audio != null: Lx.audio.play_sfx("prop_chime", dial_c, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(dial_c, 96.0, 0.82 if LxHudFx.flash_reduced() else 1.22, 0.48)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, dial_c, 16.0, 6.0)
	if w != null and is_instance_valid(w):
		w.spawn_sparks(dial_c, Vector2.UP, 6, LxWick.PAL_GOLD, 22.0, 56.0, 0.28)


func _trigger_orrery_orb(orb: Vector2, w: LxWick) -> void:
	_setpiece_cd = 2.8; _rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 2.8)
	_pulse_rings.append({"pos": orb, "age": 0.0, "dur": 0.46, "r0": 4.0, "r1": 24.0, "col": "gold"})
	if Lx.audio != null: Lx.audio.play_sfx("clockwork_chime", orb, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(orb, 82.0, 0.80 if LxHudFx.flash_reduced() else 1.18, 0.40)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, orb, 13.0, 5.5)
	if w != null and is_instance_valid(w):
		w.spawn_ring(orb, 3.0, 20.0, 0.24, LxWick.PAL_GOLD, 1.4)


func _trigger_moon_disc(mc: Vector2) -> void:
	_setpiece_cd = 3.8
	_pulse_rings.append({"pos": mc, "age": 0.0, "dur": 0.68, "r0": 8.0, "r1": 44.0, "col": "ice"})
	if Lx.audio != null: Lx.audio.play_sfx("lens_reveal", mc, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(mc, 96.0, 0.80 if LxHudFx.flash_reduced() else 1.18, 0.46)


func _is_relit() -> bool: return Lx.state != null and Lx.state.relit_islands.has(_island_id)
func _in_view(p: Vector2, pad: float = 0.0) -> bool:
	return absf(p.x - _cam_center.x) <= (HALF_W + pad) and absf(p.y - _cam_center.y) <= (HALF_H + pad)
func _is_walkable(pt: Vector2) -> bool:
	return _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", pt)) in ["ground", "path"]
func _is_water(pt: Vector2) -> bool:
	return _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", pt)) in ["water", "tide"]

func _lit_beacon_count() -> int:
	if _is_relit(): return 3
	var n: int = 0
	for bn: Node in _beacons:
		if bn is LxBeacon and is_instance_valid(bn) and (bn as LxBeacon).lit: n += 1
	return mini(n, 3)

func _draw_pixel_ring(c: Vector2, rad: int, col: Color, step_deg: int = 12, mask_walkable: bool = true) -> void:
	var n: int = maxi(8, int(roundf(360.0 / float(step_deg))))
	for i: int in range(n):
		var ang: float = (TAU * float(i)) / float(n)
		var pt: Vector2 = (c + Vector2(cos(ang), sin(ang)) * float(rad)).round()
		if _in_view(pt, 8.0) and (not mask_walkable or _is_walkable(pt)): draw_rect(Rect2(pt, Vector2.ONE), col)

func _draw_walkable_segment(a: Vector2, b: Vector2, col: Color, step_px: float = 3.0, sz: float = 1.0) -> void:
	var dist: float = a.distance_to(b)
	if dist < 1.0: return
	var steps: int = maxi(1, int(ceilf(dist / maxf(1.0, step_px))))
	for i: int in range(steps + 1):
		var pt: Vector2 = a.lerp(b, float(i) / float(steps)).round()
		if _in_view(pt, 8.0) and _is_walkable(pt): draw_rect(Rect2(pt, Vector2(sz, sz)), col)


func _draw() -> void:
	if not _active or _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	var relit: bool = _is_relit()
	match _island_id:
		1: _draw_bell_isle(fred, relit)
		2: _draw_tidewater_lighthouse(fred, relit)
		3: _draw_thornwood_roots(fred, relit)
		4: _draw_mirefen_prism_koi(fred, relit)
		5: _draw_starfall_orrery(fred, relit)
		6: _draw_ashen_fissures(fred, relit)
		7: _draw_moon_shoals_reflection(fred, relit)
		8: _draw_long_night_eclipse(fred, relit)
	if relit and _in_view(_door_pos, 110.0):
		LxRelitKeepsakes.draw_keepsake(self, _island_id, _door_pos, _clock, fred)
	for pr: Dictionary in _pulse_rings:
		var u: float = clampf(float(pr["age"]) / maxf(float(pr["dur"]), 0.01), 0.0, 1.0)
		var r: int = int(roundf(lerpf(float(pr["r0"]), float(pr["r1"]), u)))
		var pcol: Color = (PAL["cream"] if u < 0.30 else PAL[str(pr["col"])]) as Color
		_draw_pixel_ring((pr["pos"] as Vector2).round(), r, Color(pcol, (1.0 - u) * (0.38 if fred else 0.56)), 12, false)


func _draw_bell_isle(fred: bool, relit: bool) -> void:
	# Subtle weathered Sundial Plaza stone groove & beacon-progress pips (640, 396)
	var dial_c := Vector2(640.0, 396.0)
	if _in_view(dial_c, 48.0):
		var lit_n: int = _lit_beacon_count()
		var dial_a: float = (0.16 if fred else 0.22) if (relit or lit_n > 0) else 0.16
		var hand_ang: float = -PI * 0.5 + (TAU * float(lit_n) / 3.0) + _clock * (0.22 if relit else 0.06) + _dial_spin_t * 6.5
		_draw_pixel_ring(dial_c, 22, Color((PAL["gold"] if (relit or lit_n >= 3) else PAL["stone"]) as Color, dial_a), 12, true)
		_draw_walkable_segment(dial_c, (dial_c + Vector2.from_angle(hand_ang) * 18.0).round(), Color(PAL["apricot"] as Color, dial_a * 1.15), 2.0)
		for k: int in range(3):
			var kp: Vector2 = (dial_c + Vector2.from_angle(-PI * 0.5 + float(k) * (TAU / 3.0)) * 22.0).round()
			if _is_walkable(kp):
				draw_rect(Rect2(kp - Vector2.ONE, Vector2(2.0, 2.0)), Color((PAL["cream"] if (relit or k < lit_n) else PAL["dusk"]) as Color, 0.72))
	_draw_beacon_conduits(PAL["gold"] as Color, PAL["cream"] as Color, fred, relit)


func _draw_tidewater_lighthouse(fred: bool, relit: bool) -> void:
	var lit_n: int = _lit_beacon_count()
	for idx: int in range(_fresnel_origins.size()):
		var orig: Vector2 = _fresnel_origins[idx]
		if not _in_view(orig, 260.0): continue
		var ang: float = (_rules.bounds.get_center() - orig).angle() + sin(_clock * (0.34 if idx == 0 else -0.44) + float(idx) * 1.4) * 0.85
		var span: float = (250.0 if idx == 0 else 145.0) * (1.0 + float(lit_n) * 0.06)
		var cone: float = (0.20 if idx == 0 else 0.14) + float(lit_n) * 0.012
		var beam_c: Color = (PAL["gold"] if relit else PAL["ice"]) as Color
		var a: float = ((0.05 if fred else 0.08) if idx == 0 else (0.04 if fred else 0.06)) * (1.0 + float(lit_n) * 0.10)
		draw_colored_polygon(PackedVector2Array([orig.round(), (orig + Vector2.from_angle(ang - cone) * span).round(), (orig + Vector2.from_angle(ang + cone) * span).round()]), Color(beam_c, a))


func _draw_thornwood_roots(fred: bool, relit: bool) -> void:
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node): continue
		var b: LxBeacon = b_node as LxBeacon
		var lit_b: bool = relit or b.lit
		var start: Vector2 = b.pos.round()
		var mid: Vector2 = start.lerp(target, 0.5) + Vector2(32.0 if start.x < target.x else -32.0, 18.0)
		var base_c := Color((PAL["lime"] if lit_b else PAL["teal"]) as Color, (0.16 if fred else 0.24) if lit_b else 0.16)
		var prev: Vector2 = start
		for s: int in range(1, 13):
			var u: float = float(s) / 12.0
			var pt: Vector2 = start.lerp(mid, u).lerp(mid.lerp(target, u), u).round()
			if _in_view(pt, 48.0) or _in_view(prev, 48.0):
				_draw_walkable_segment(prev, pt, base_c, 3.0, 2.0 if lit_b else 1.0)
			prev = pt
		var pu: float = fposmod(_clock * (0.45 if lit_b else 0.18) + start.x * 0.01, 1.0)
		var pp: Vector2 = start.lerp(mid, pu).lerp(mid.lerp(target, pu), pu).round()
		if _in_view(pp, 16.0) and _is_walkable(pp):
			draw_rect(Rect2(pp - Vector2.ONE, Vector2(2.0, 2.0)), Color((PAL["cream"] if lit_b else PAL["jade"]) as Color, 0.68))


func _draw_mirefen_prism_koi(fred: bool, relit: bool) -> void:
	var lit_4: int = _lit_beacon_count()
	if _in_view(_door_pos, 190.0):
		var c: Vector2 = _door_pos.round()
		var cols: Array[String] = ["rose", "gold", "ice"]
		var a: float = (0.04 if fred else (0.08 if relit else 0.06)) * (1.0 + float(lit_4) * 0.10)
		var ray_dir: float = (_rules.bounds.get_center() - _door_pos).angle()
		for k: int in range(3):
			var ang: float = ray_dir + float(k - 1) * 0.22 + sin(_clock * 0.35 + float(k)) * 0.08
			var len4: float = 175.0 + float(lit_4) * 10.0
			draw_colored_polygon(PackedVector2Array([c, (c + Vector2.from_angle(ang - 0.07) * len4).round(), (c + Vector2.from_angle(ang + 0.07) * len4).round()]), Color(PAL[cols[k]] as Color, a))
	for k: Dictionary in _koi:
		var spd_k: float = float(k["spd"]) * (2.2 if float(k.get("burst_t", 0.0)) > 0.0 else 1.0)
		var ang: float = _clock * spd_k + float(k["phase"])
		var cen: Vector2 = k["center"] as Vector2
		var p: Vector2 = (cen + Vector2(cos(ang) * float(k["rx"]), sin(ang) * float(k["ry"]))).round()
		if not _in_view(p, 24.0) or not _is_water(p): continue
		var tail_ang: float = ang - signf(float(k["spd"])) * 0.22
		var tp: Vector2 = (cen + Vector2(cos(tail_ang) * float(k["rx"]), sin(tail_ang) * float(k["ry"]))).round()
		if _is_water(tp):
			draw_line(tp, p, Color(PAL[str(k["col"])] as Color, 0.52), 2.0)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, 0.65))


func _draw_starfall_orrery(fred: bool, relit: bool) -> void:
	# Subtle pixel-stepped stone astrolabe floor grooves (strictly masked to walkable tiles, no giant radar rings!)
	var lit_5: int = _lit_beacon_count()
	var c: Vector2 = _door_pos.round()
	var a_ring: float = 0.14 if fred else (0.20 if relit else 0.17)
	var radii: Array[int] = [148, 256]
	var spds: Array[float] = [0.16, -0.11]
	for idx: int in range(radii.size()):
		var rad: int = radii[idx]
		if not _in_view(c, float(rad) + 24.0): continue
		var rot: float = _clock * spds[idx] * (1.0 + float(lit_5) * 0.12) + float(idx) * 1.1
		var rc: Color = (PAL["gold"] if (relit or idx == 0) else PAL["sky"]) as Color
		_draw_pixel_ring(c, rad, Color(rc, a_ring), 5, true)
		for seg: int in range(4):
			var orb: Vector2 = (c + Vector2.from_angle(rot + float(seg) * (PI * 0.5)) * float(rad)).round()
			if _in_view(orb, 16.0) and _is_walkable(orb):
				draw_rect(Rect2(orb + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), Color(PAL["gold"] as Color, 0.58))
				draw_rect(Rect2(orb, Vector2.ONE), PAL["cream"] as Color)
	_draw_beacon_conduits(PAL["sky"] as Color, PAL["gold"] as Color, fred, relit)


func _draw_ashen_fissures(fred: bool, relit: bool) -> void:
	var pulse: float = 0.5 if fred else clampf(_rules.vent_cycle, 0.0, 1.0)
	var hot_c: Color = (PAL["gold"] if (relit or pulse >= 0.56) else PAL["coral"]) as Color
	var dim_c: Color = (PAL["apricot"] if relit else PAL["wine"]) as Color
	var a: float = (0.16 + 0.14 * pulse) * (0.75 if fred else 1.0)
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node): continue
		var b: LxBeacon = b_node as LxBeacon
		var s: Vector2 = b.pos.round()
		var lit_b: bool = relit or b.lit
		var prev: Vector2 = s
		for k: int in range(1, 9):
			var pt: Vector2 = (s.lerp(target, float(k) / 8.0) + Vector2(0.0, sin(float(k) * 2.3 + s.y * 0.02) * 16.0)).round()
			if _in_view(pt, 48.0) or _in_view(prev, 48.0):
				_draw_walkable_segment(prev, pt, Color(hot_c if lit_b else dim_c, a), 3.0, 2.0 if lit_b else 1.0)
			prev = pt


func _draw_moon_shoals_reflection(fred: bool, relit: bool) -> void:
	var ph: float = 1.0 if relit else clampf(_rules.lunar_phase + float(_lit_beacon_count()) * 0.10, 0.0, 1.0)
	var r: float = 36.0
	var a_disc: float = (0.12 + 0.18 * ph) * (0.75 if fred else 1.0)
	var disc_c: Color = (PAL["gold"] if relit else (PAL["ice"] if ph > 0.5 else PAL["sky"])) as Color
	for moon_c: Vector2 in _moon_discs:
		if not _in_view(moon_c, 64.0): continue
		var y_off: float = -r
		while y_off <= r:
			var half_span: float = sqrt(maxf(0.0, r * r - y_off * y_off))
			var wave: float = 0.0 if fred else sin(_clock * 2.2 + y_off * 0.25 + moon_c.x * 0.01) * 2.0
			var y_px: float = roundf(moon_c.y + y_off)
			var left_cut: float = lerpf(-half_span * 0.85, half_span * 0.35, 1.0 - ph)
			if half_span > left_cut + 2.0:
				var p0 := Vector2(roundf(moon_c.x + left_cut + wave), y_px)
				var p1 := Vector2(roundf(moon_c.x + half_span + wave), y_px)
				if _is_water(p0) and _is_water(p1):
					draw_rect(Rect2(p0, Vector2(maxf(2.0, p1.x - p0.x), 1.0)), Color(disc_c, a_disc))
			y_off += 4.0
	_draw_beacon_conduits(PAL["ice"] as Color, PAL["cream"] as Color, fred, relit)


func _draw_long_night_eclipse(fred: bool, relit: bool) -> void:
	# Subtle pixel-stepped nave floor inlay around Bell Sanctum (masked strictly to walkable stone!)
	var c: Vector2 = _door_pos.round()
	var seals_b: int = LxBiomeMechanics.active_instance.dawn_seals_broken if (LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance)) else 0
	if _in_view(c, 110.0):
		var a8: float = 0.16 if fred else 0.22
		var ring_c: Color = (PAL["gold"] if (relit or seals_b >= 2) else PAL["rose"]) as Color
		_draw_pixel_ring(c, 64, Color(ring_c, a8), 8, true)
		var rays: int = 8 if relit else (seals_b * 2)
		for k: int in range(rays):
			var ang: float = _clock * 0.12 + float(k) * (TAU / maxf(1.0, float(rays)))
			_draw_walkable_segment((c + Vector2.from_angle(ang) * 66.0).round(), (c + Vector2.from_angle(ang) * 92.0).round(), Color(PAL["gold"] as Color, a8), 3.0)
	var lit_ratio: float = 1.0 if relit else (float(seals_b) / 3.0)
	var sp_count: float = maxf(1.0, float(_spine_points.size()))
	for step: int in range(_spine_points.size()):
		var sp: Vector2 = _spine_points[step]
		if not _in_view(sp, 24.0) or not _is_walkable(sp): continue
		var lit_s: bool = _lit_spine.has(step)
		var col: Color = (PAL["cream"] if lit_s else (PAL["gold"] if (float(step) / sp_count) <= lit_ratio + 0.12 else PAL["plum"])) as Color
		draw_rect(Rect2(sp - Vector2(2.0, 1.0), Vector2(4.0, 2.0)), Color(col, 0.72 if lit_s else 0.44))


func _draw_beacon_conduits(col_dim: Color, col_hi: Color, fred: bool, relit: bool) -> void:
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node): continue
		var b: LxBeacon = b_node as LxBeacon
		if not relit and not b.lit: continue
		var start: Vector2 = b.pos.round()
		if not _in_view(start, 220.0) and not _in_view(target, 220.0): continue
		_draw_walkable_segment(start, target, Color(col_dim, 0.12 if fred else 0.18), 6.0)
		var u: float = fposmod(_clock * 0.36 + start.x * 0.007, 1.0)
		var pt: Vector2 = start.lerp(target, u).round()
		if _in_view(pt, 16.0) and _is_walkable(pt):
			draw_rect(Rect2(pt - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_hi, 0.68))
