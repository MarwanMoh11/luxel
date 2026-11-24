class_name LxBiomeRules
extends Node2D
## Island-unique live gameplay rules & interactive environmental phenomena across Islands 2..8.
## Renders beneath actors (z_index = -3) using strictly the 20 opaque Last Light colours.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 184.0
const HALF_H: float = 114.0

static var active_instance: LxBiomeRules = null

var island_id: int = 1
var is_dungeon: bool = false
var clock: float = 0.0
var bounds: Rect2 = Rect2()
var _region: Node = null
var _cam_center: Vector2 = Vector2.ZERO
var _mechanics: LxBiomeMechanics = null

# Island 2: Live Ocean Tides + Sweeping Lighthouse Fresnel Beam
var tide_phase: float = 0.0 # 0..1 cycle (0.60..1.0 = High Tide Surge)
var tide_surging: bool = false
var _last_tide_surge: bool = false
var beam_angle: float = PI * 0.5
var beam_origin: Vector2 = Vector2.ZERO
var beam_buff_t: float = 0.0

# Island 3: Light-Reactive Forest Bloom-Lamps + Hollow Oak Amber Sap Pools
var _blooms: Array[Dictionary] = [] # {pos, lit_t}
var _sap_pools: Array[Dictionary] = [] # {pos, r}

# Island 4: Botanical Mist Updraft Geysers (refreshes Moth Wings mid-glide!)
var _updrafts: Array[Dictionary] = [] # {pos, r, cd}

# Island 5: Falling Star Meteors + Starlight Surge speed boost
var _stars: Array[Dictionary] = [] # {pos, t, dur, landed}
var _star_cd: float = 2.8
var starlight_surge_t: float = 0.0

# Island 6: Breathing Magma Vents (Dash through eruption rim -> +18 Ember!)
var _vents: Array[Dictionary] = [] # {pos, phase, ember_cd, erupted}
var vent_cycle: float = 0.0

# Island 7: Live Lunar Phase Cycle (Full Silver Moon <-> Lunar Eclipse)
var lunar_phase: float = 1.0 # 1.0 = Full Silver Moon, 0.0 = Lunar Eclipse

# Island 8: The Hush's Encroaching Eclipse Pulse + Remix features
var eclipse_pulse: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -3
	active_instance = self

func _exit_tree() -> void:
	if active_instance == self: active_instance = null

func configure(p_island_id: int, p_bounds: Rect2, p_is_dungeon: bool, region_node: Node) -> void:
	active_instance = self
	island_id = clampi(p_island_id, 1, 8)
	is_dungeon = p_is_dungeon
	bounds = p_bounds
	_region = region_node
	clock = 0.0
	_cam_center = p_bounds.get_center()
	tide_phase = 0.0; tide_surging = false; _last_tide_surge = false
	beam_angle = PI * 0.5
	beam_origin = Vector2(p_bounds.position.x + p_bounds.size.x * 0.5, p_bounds.position.y + 18.0)
	beam_buff_t = 0.0
	_blooms.clear(); _sap_pools.clear(); _updrafts.clear(); _stars.clear(); _vents.clear()
	_star_cd = 2.4; starlight_surge_t = 0.0; vent_cycle = 0.0; lunar_phase = 1.0; eclipse_pulse = 0.0
	_populate_features()
	if _mechanics == null and get_parent() != null:
		_mechanics = LxBiomeMechanics.new(); _mechanics.name = "BiomeMechanics"; get_parent().add_child(_mechanics)
	if _mechanics != null:
		_mechanics.configure(self, _region)
	queue_redraw()


func _populate_features() -> void:
	if _region == null or not is_instance_valid(_region):
		return
	var grid_v: Variant = _region.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		return
	var grid: Array = grid_v as Array
	var h: int = grid.size()
	var w: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(_region.get("tile_size")) if _region.get("tile_size") != null else 16.0

	if island_id == 3 and not is_dungeon:
		_scan_and_place(grid, w, h, ts, PackedStringArray(["ground", "path"]), 9, 10, func(p: Vector2, _hv: int) -> void:
			_blooms.append({"pos": p, "lit_t": 0.0})
		)
	elif island_id == 3 and is_dungeon:
		_scan_and_place(grid, w, h, ts, PackedStringArray(["ground", "path"]), 5, 3, func(p: Vector2, _hv: int) -> void:
			_sap_pools.append({"pos": p, "r": 14.0})
		)
	elif island_id == 4 or (island_id == 8 and not is_dungeon):
		var want_tiles := PackedStringArray(["water", "pit", "void"] if is_dungeon else (["water", "tide", "pit", "void"] if island_id == 8 else ["water", "tide"]))
		var max_u: int = 12 if (island_id == 4 and not is_dungeon) else 4
		var mire_rect: Rect2 = _find_zone_rect(PackedStringArray(["mire", "wing", "isl8_2"])) if island_id == 8 else Rect2()
		var u_filter: Callable = Callable()
		if island_id == 8:
			u_filter = func(p: Vector2) -> bool:
				if mire_rect.has_area():
					return mire_rect.has_point(p)
				var prog: float = _route_progress(p)
				return prog >= 0.22 and prog <= 0.72 and _has_walkable_near(grid, w, h, ts, p, 4)
		_scan_and_place(grid, w, h, ts, want_tiles, 5, max_u, func(p: Vector2, _hv: int) -> void:
			_updrafts.append({"pos": p, "r": 18.0, "cd": 0.0})
		, u_filter)
	if island_id == 6 or (island_id == 8 and not is_dungeon):
		var max_v: int = 9 if (island_id == 6 and not is_dungeon) else 3
		var kiln_rect: Rect2 = _find_zone_rect(PackedStringArray(["kiln", "forge", "ash", "isl8_3"])) if island_id == 8 else Rect2()
		var v_filter: Callable = Callable()
		if island_id == 8:
			v_filter = func(p: Vector2) -> bool:
				if kiln_rect.has_area():
					return kiln_rect.has_point(p)
				return _route_progress(p) >= 0.55
		_scan_and_place(grid, w, h, ts, PackedStringArray(["ground", "path"]), 7, max_v, func(p: Vector2, hv: int) -> void:
			_vents.append({"pos": p, "phase": float(hv % 100) * 0.005, "ember_cd": 0.0, "erupted": false})
		, v_filter)


func _find_zone_rect(keywords: PackedStringArray) -> Rect2:
	if _region == null or not is_instance_valid(_region): return Rect2()
	var zones_v: Variant = _region.get("zones")
	if not (zones_v is Array): return Rect2()
	for z_v: Variant in (zones_v as Array):
		if not (z_v is Dictionary): continue
		var z: Dictionary = z_v as Dictionary
		var z_id: String = str(z.get("id", "")).to_lower()
		var z_name: String = str(z.get("name_key", "")).to_lower()
		var matched: bool = false
		for kw: String in keywords:
			if z_id.find(kw) >= 0 or z_name.find(kw) >= 0: matched = true; break
		if not matched: continue
		var rv: Variant = z.get("rect")
		if rv is Array and (rv as Array).size() >= 4:
			var ra: Array = rv as Array
			return Rect2(float(ra[0]), float(ra[1]), float(ra[2]), float(ra[3]))
		if rv is Rect2: return rv as Rect2
	return Rect2()

func _route_progress(p: Vector2) -> float:
	var sp: Vector2 = bounds.position + Vector2(bounds.size.x * 0.5, bounds.size.y * 0.85)
	var dp: Vector2 = bounds.position + Vector2(bounds.size.x * 0.5, bounds.size.y * 0.15)
	if _region != null and is_instance_valid(_region):
		var sp_v: Variant = _region.get("spawn_pos")
		if sp_v is Vector2 and (sp_v as Vector2) != Vector2.ZERO: sp = sp_v as Vector2
		if _region.has_method("find_interactable"):
			var door_v: Variant = _region.call("find_interactable", "door_dungeon_%d" % island_id)
			if door_v is Node2D and is_instance_valid(door_v): dp = (door_v as Node2D).global_position
	var d_spawn: float = p.distance_to(sp)
	return clampf(d_spawn / maxf(1.0, d_spawn + p.distance_to(dp)), 0.0, 1.0)

static func _has_walkable_near(grid: Array, w: int, h: int, ts: float, p: Vector2, rad_tiles: int) -> bool:
	var cx: int = int(floor(p.x / maxf(ts, 1.0)))
	var cy: int = int(floor(p.y / maxf(ts, 1.0)))
	for dy: int in range(-rad_tiles, rad_tiles + 1):
		var ty: int = cy + dy
		if ty < 0 or ty >= h: continue
		var row: PackedStringArray = grid[ty] as PackedStringArray
		for dx: int in range(-rad_tiles, rad_tiles + 1):
			var tx: int = cx + dx
			if tx >= 0 and tx < w and row[tx] in ["ground", "path", "bridge"]: return true
	return false

func _scan_and_place(
	grid: Array, w: int, h: int, ts: float, match_tiles: PackedStringArray,
	stride: int, limit: int, on_place: Callable, filter: Callable = Callable()
) -> void:
	var placed: Array[Vector2] = []
	var min_sep_sq: float = (float(stride) * ts * 0.72) ** 2
	for ty: int in range(2, h - 2, 2):
		var row: PackedStringArray = grid[ty] as PackedStringArray
		for tx: int in range(2, w - 2, 2):
			if placed.size() >= limit: return
			if not match_tiles.has(row[tx]): continue
			var up_t: String = (grid[ty - 1] as PackedStringArray)[tx]
			var dn_t: String = (grid[ty + 1] as PackedStringArray)[tx]
			if not ((match_tiles.has(up_t) or up_t in ["ground", "path", "water"]) and (match_tiles.has(dn_t) or dn_t in ["ground", "path", "water"])): continue
			var hv: int = (tx * 73856093 ^ ty * 19349663 ^ island_id * 83492791) & 0x7FFFFFFF
			if (hv % stride) != 0: continue
			var p := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
			if (filter.is_valid() and not bool(filter.call(p))) or _too_close(p, placed, min_sep_sq): continue
			placed.append(p)
			on_place.call(p, hv)

static func _too_close(p: Vector2, pts: Array[Vector2], sep_sq: float) -> bool:
	for o: Vector2 in pts:
		if o.distance_squared_to(p) < sep_sq: return true
	return false


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0:
		return
	clock += dt
	match island_id:
		2: _tick_island2(dt)
		3: _tick_island3(dt)
		4: _tick_island4(dt)
		5: _tick_island5(dt)
		6: _tick_island6(dt)
		7: lunar_phase = 0.5 + 0.5 * cos(clock * (TAU / 9.0))
		8: _tick_island8(dt)
	if _mechanics != null and is_instance_valid(_mechanics):
		_mechanics.tick(dt, cam_center)
	queue_redraw()


func _tick_island2(dt: float) -> void:
	if not is_dungeon:
		tide_phase = fposmod(clock / 6.8, 1.0)
		tide_surging = tide_phase >= 0.60
		if tide_surging and not _last_tide_surge and Lx.audio != null:
			Lx.audio.play_sfx("tide_surge", _cam_center, true)
		_last_tide_surge = tide_surging
		if tide_surging and Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping():
				if _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", w.global_position)) == "tide":
					w.apply_recoil(Vector2(28.0 * dt * 8.0, 0.0))
	else:
		# Single dungeon Fresnel searchlight is driven and drawn by LxBiomeDungeonTwists
		beam_buff_t = maxf(0.0, beam_buff_t - dt)


func get_lit_bloom_count() -> int:
	var n: int = 0
	for b: Dictionary in _blooms:
		if float(b.get("lit_t", 0.0)) > 0.0:
			n += 1
	return n


func _tick_island3(dt: float) -> void:
	if not is_dungeon:
		var ppos: Vector2 = _player_pos()
		var lpos: Vector2 = _lantern_pos()
		var p_act: bool = _player_light_burst_active()
		for b: Dictionary in _blooms:
			var lt: float = float(b["lit_t"])
			if lt > 0.0:
				b["lit_t"] = maxf(0.0, lt - dt)
			var bp: Vector2 = b["pos"] as Vector2
			if (p_act and bp.distance_squared_to(ppos) <= 2304.0) or bp.distance_squared_to(lpos) <= 1296.0:
				if lt <= 0.1:
					if Lx.audio != null:
						Lx.audio.play_sfx("prop_chime", bp, true)
					if _mechanics != null and is_instance_valid(_mechanics):
						_mechanics.on_bloom_ignited(bp, true)
				b["lit_t"] = 16.0
	else:
		if _region != null and _region.has_method("get_enemies"):
			var enemies_v: Variant = _region.call("get_enemies")
			if enemies_v is Array:
				for e_v: Variant in (enemies_v as Array):
					if e_v is LxEnemyBrain and is_instance_valid(e_v):
						var e: LxEnemyBrain = e_v as LxEnemyBrain
						if not e.is_alive() or e.is_boss:
							continue
						for sp: Dictionary in _sap_pools:
							if e.pos.distance_to(sp["pos"] as Vector2) <= float(sp["r"]):
								e.knock *= maxf(0.0, 1.0 - 4.0 * dt)
		var p_act_d: bool = _player_light_burst_active()
		var ppos_d: Vector2 = _player_pos()
		for sp: Dictionary in _sap_pools:
			sp["lit_t"] = maxf(0.0, float(sp.get("lit_t", 0.0)) - dt)
			if p_act_d and ppos_d.distance_to(sp["pos"] as Vector2) <= float(sp["r"]) + 10.0 and float(sp["lit_t"]) <= 0.1:
				sp["lit_t"] = 6.0
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(sp["pos"] as Vector2, 72.0, 0.85 if LxHudFx.flash_reduced() else 1.18, 0.45)
				if Lx.audio != null:
					Lx.audio.play_sfx("prop_chime", sp["pos"] as Vector2, true)


func _tick_island4(dt: float) -> void:
	for u: Dictionary in _updrafts:
		u["cd"] = maxf(0.0, float(u["cd"]) - dt)
		if float(u["cd"]) > 0.0:
			continue
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if w.is_gliding() and w.move_wings != null and w.global_position.distance_to(u["pos"] as Vector2) <= float(u["r"]) + 8.0:
				u["cd"] = 0.65
				w.move_wings.glide_time_left = w.move_wings.glide_duration
				w.move_wings.glide_dist_left = w.move_wings.glide_max_px
				w.spawn_ring(u["pos"] as Vector2, 4.0, 22.0, 0.28, LxWick.PAL_ICE, 1.4)
				w.spawn_sparks(w.global_position, Vector2.UP, 6, LxWick.PAL_CREAM, 22.0, 56.0, 0.22)
				w.emit_sfx("wing_gale", u["pos"] as Vector2, true)
				if _mechanics != null and is_instance_valid(_mechanics):
					_mechanics.on_updraft_caught(u["pos"] as Vector2)


func _tick_island5(dt: float) -> void:
	starlight_surge_t = maxf(0.0, starlight_surge_t - dt)
	_star_cd -= dt
	if _star_cd <= 0.0 and _stars.size() < 2:
		_star_cd = 5.4
		var spot: Vector2 = _find_walkable_near_cam()
		if spot != Vector2.ZERO:
			_stars.append({"pos": spot, "t": 0.0, "dur": 1.45, "landed": false})
	for i: int in range(_stars.size() - 1, -1, -1):
		var s: Dictionary = _stars[i]
		s["t"] = float(s["t"]) + dt
		var t: float = float(s["t"])
		var dur: float = float(s["dur"])
		if not bool(s["landed"]) and t >= dur:
			s["landed"] = true
			_on_star_impact(s["pos"] as Vector2)
		if t >= dur + 0.55:
			_stars.remove_at(i)


func _on_star_impact(at: Vector2) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx("star_lance", at, true)
	if _mechanics != null and is_instance_valid(_mechanics):
		_mechanics.spawn_star_crystal(at)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at, 66.0, 0.85 if LxHudFx.flash_reduced() else 1.38, 0.34)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var d: float = w.global_position.distance_to(at)
		if d >= 14.0 and d <= 52.0:
			starlight_surge_t = 2.6
			w.spawn_ring(w.global_position, 3.0, 16.0, 0.24, LxWick.PAL_GOLD, 1.4)
			w.emit_sfx("prism_chain", w.global_position, false)
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and not e.is_boss and e.pos.distance_to(at) <= 24.0:
						var kdir: Vector2 = (e.pos - at).normalized() if e.pos.distance_to(at) > 0.5 else Vector2.RIGHT
						e.knock += kdir * 75.0


func _tick_island6(dt: float) -> void:
	vent_cycle = fposmod(clock / 5.2, 1.0)
	for v: Dictionary in _vents:
		v["ember_cd"] = maxf(0.0, float(v["ember_cd"]) - dt)
		var vp: float = fposmod(vent_cycle + float(v["phase"]), 1.0)
		var erupting: bool = vp >= 0.56
		if erupting and not bool(v["erupted"]):
			v["erupted"] = true
			if (v["pos"] as Vector2).distance_to(_cam_center) <= 180.0 and Lx.audio != null:
				Lx.audio.play_sfx("forge_gust", v["pos"] as Vector2, true)
		elif not erupting:
			v["erupted"] = false
		if erupting and float(v["ember_cd"]) <= 0.0 and Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if w.is_dashing() and w.global_position.distance_to(v["pos"] as Vector2) <= 34.0:
				v["ember_cd"] = 2.0
				if w.move_sunflare != null and w.move_sunflare.unlocked:
					w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 18.0)
				w.spawn_ring(w.global_position, 3.0, 18.0, 0.24, LxWick.PAL_GOLD, 1.4)
				w.emit_sfx("ember_pickup", w.global_position, false)
				if _mechanics != null and is_instance_valid(_mechanics):
					_mechanics.grant_molten_overdrive(3)


func _tick_island8(dt: float) -> void:
	var lit_b: int = 0
	if Lx.state != null:
		for bid: String in ["beacon_8_1", "beacon_8_2", "beacon_8_3"]:
			if Lx.state.lit_beacons.has(bid):
				lit_b += 1
	eclipse_pulse = (0.5 + 0.5 * sin(clock * (TAU / 9.0))) * clampf(1.0 - float(lit_b) / 3.0, 0.0, 1.0)
	if not is_dungeon:
		_tick_island4(dt)
		_tick_island6(dt)


func get_darkness_offset() -> float:
	if Lx.state != null and Lx.state.relit_islands.has(island_id) and not is_dungeon:
		return 0.0
	match island_id:
		3: return 0.16 if not is_dungeon else 0.06
		7: return lerpf(0.14, -0.16, lunar_phase)
		8: return eclipse_pulse * 0.15
		_: return 0.0


func get_shader_phase() -> float:
	match island_id:
		2: return 1.0 if tide_surging else tide_phase
		6: return vent_cycle
		7: return lunar_phase
		8: return eclipse_pulse
		_: return 0.5 + 0.5 * sin(clock * 0.8)


func get_light_pools() -> Array[Vector4]:
	var pools: Array[Vector4] = []
	if island_id == 2 and is_dungeon:
		var bdir: Vector2 = Vector2.from_angle(beam_angle)
		var p1: Vector2 = beam_origin + bdir * 52.0
		var p2: Vector2 = beam_origin + bdir * 116.0
		pools.append(Vector4(p1.x, p1.y, 54.0, 1.05))
		pools.append(Vector4(p2.x, p2.y, 62.0, 0.95))
	elif island_id == 3 and not is_dungeon:
		for b: Dictionary in _blooms:
			var lt: float = float(b["lit_t"])
			var bp: Vector2 = b["pos"] as Vector2
			pools.append(Vector4(bp.x, bp.y, 86.0 * clampf(lt / 2.0, 0.0, 1.0), 1.15 * clampf(lt / 2.0, 0.0, 1.0)) if lt > 0.0 else Vector4(bp.x, bp.y, 24.0, 0.35))
	elif island_id == 6 or (island_id == 8 and not is_dungeon):
		for v: Dictionary in _vents:
			var vp: float = fposmod(vent_cycle + float(v["phase"]), 1.0)
			if vp >= 0.45:
				var p: Vector2 = v["pos"] as Vector2
				pools.append(Vector4(p.x, p.y, 58.0 if vp >= 0.56 else 36.0, 1.10 if vp >= 0.56 else 0.58))
	return pools


func _is_walkable(pt: Vector2) -> bool:
	return _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", pt)) in ["ground", "path"]


func _draw_stepped_ring(c: Vector2, rad: int, col: Color, dots: int = 16, only_walkable: bool = false) -> void:
	for k: int in range(dots):
		var a: float = (TAU * float(k)) / float(dots)
		var pt: Vector2 = (c + Vector2(cos(a), sin(a)) * float(rad)).round()
		if not only_walkable or _is_walkable(pt):
			draw_rect(Rect2(pt, Vector2.ONE), col)


func _draw() -> void:
	if island_id <= 1:
		return
	var fred: bool = LxHudFx.flash_reduced()
	match island_id:
		2: _draw_island2(fred)
		3: _draw_island3(fred)
		4: _draw_updrafts(fred)
		5: _draw_stars(fred)
		6: _draw_vents(fred)
		7: _draw_mirror_reflection(fred)
		8:
			if not is_dungeon:
				_draw_updrafts(fred)
				_draw_vents(fred)


func _draw_island2(fred: bool) -> void:
	if is_dungeon or (not tide_surging and tide_phase < 0.46):
		return
	var col: Color = (PAL["ice"] if tide_surging else PAL["sky"]) as Color
	var min_x: float = _cam_center.x - HALF_W
	var min_y: float = _cam_center.y - HALF_H
	var drift: float = fposmod(clock * (48.0 if tide_surging else 18.0), 32.0)
	for row: int in range(8):
		var wy: float = roundf(min_y + float(row) * 28.0 + 10.0)
		var wx: float = roundf(min_x + drift + float((row * 19) % 48))
		if _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", Vector2(wx, wy))) in ["tide", "water"]:
			draw_rect(Rect2(wx, wy, 14.0 if tide_surging else 8.0, 1.0), Color(col, 0.45 if fred else 0.72))
			draw_rect(Rect2(wx + 2.0, wy - 1.0, 6.0, 1.0), Color(PAL["cream"] as Color, 0.30 if fred else 0.55))


func _draw_island3(fred: bool) -> void:
	for b: Dictionary in _blooms:
		var p: Vector2 = (b["pos"] as Vector2).round()
		if not _on_screen(p) or not _is_walkable(p):
			continue
		var lit: bool = float(b["lit_t"]) > 0.0
		var r_pad: float = 4.0 if lit else 3.0
		draw_rect(Rect2(p + Vector2(-r_pad, -r_pad + 1.0), Vector2(r_pad * 2.0, r_pad * 2.0 - 2.0)), PAL["pine"] as Color)
		draw_rect(Rect2(p + Vector2(-r_pad + 1.0, -r_pad), Vector2(r_pad * 2.0 - 2.0, r_pad * 2.0)), PAL["pine"] as Color)
		draw_rect(Rect2(p + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), (PAL["lime"] if lit else PAL["jade"]) as Color)
		if lit:
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
			_draw_stepped_ring(p, 7 + (0 if fred else int(roundf(sin(clock * 3.0)))), Color(PAL["gold"] as Color, 0.36), 12, true)
	for sp: Dictionary in _sap_pools:
		var p: Vector2 = (sp["pos"] as Vector2).round()
		if not _on_screen(p) or not _is_walkable(p):
			continue
		var r: float = float(sp["r"])
		draw_rect(Rect2(p + Vector2(-r + 2.0, -r * 0.6), Vector2((r - 2.0) * 2.0, r * 1.2)), Color(PAL["apricot"] as Color, 0.18))
		draw_rect(Rect2(p + Vector2(-r * 0.6, -r * 0.8), Vector2(r * 1.2, r * 1.6)), Color(PAL["apricot"] as Color, 0.18))
		_draw_stepped_ring(p, int(r * 0.85), Color(PAL["gold"] as Color, 0.28), 16, true)
		var bx: float = roundf(p.x + sin(clock * 1.7 + p.x) * (r * 0.35))
		var by: float = roundf(p.y + cos(clock * 1.3 + p.y) * (r * 0.25))
		draw_rect(Rect2(bx, by, 2.0, 1.0), Color(PAL["cream"] as Color, 0.65))


func _draw_updrafts(fred: bool) -> void:
	for u: Dictionary in _updrafts:
		var p: Vector2 = (u["pos"] as Vector2).round()
		if not _on_screen(p):
			continue
		var r: float = float(u["r"])
		var rot: float = clock * (1.1 if fred else 2.4)
		for k: int in range(6):
			var a: float = rot + float(k) * (TAU / 6.0)
			var pt: Vector2 = (p + Vector2(cos(a) * r * 0.58, sin(a) * r * 0.42)).round()
			draw_rect(Rect2(pt, Vector2(2.0 if k % 2 == 0 else 1.0, 1.0)), Color((PAL["ice"] if k % 2 == 0 else PAL["sky"]) as Color, 0.48))
		for k: int in range(3):
			var uu: float = fposmod(clock * 0.85 + float(k) * 0.33, 1.0)
			var mx: float = roundf(p.x + cos(rot + float(k) * 2.1) * (r * 0.40 * (1.0 - uu * 0.4)))
			var my: float = roundf(p.y + 4.0 - uu * 16.0)
			draw_rect(Rect2(mx, my, 1.0, 2.0), Color((PAL["cream"] if uu < 0.35 else PAL["ice"]) as Color, sin(uu * PI) * 0.72))


func _draw_stars(fred: bool) -> void:
	for s: Dictionary in _stars:
		var p: Vector2 = (s["pos"] as Vector2).round()
		if not _is_walkable(p):
			continue
		var t: float = float(s["t"])
		var dur: float = float(s["dur"])
		if not bool(s["landed"]):
			var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
			var rr: int = int(roundf(lerpf(18.0, 3.0, u)))
			_draw_stepped_ring(p, rr, Color((PAL["cream"] if u > 0.75 else PAL["gold"]) as Color, 0.55 if fred else 0.75), 12, true)
			draw_rect(Rect2(p + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), Color(PAL["ice"] as Color, 0.65))
			draw_rect(Rect2(p + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), Color(PAL["ice"] as Color, 0.65))
		else:
			var a: float = clampf(1.0 - (t - dur) / 0.55, 0.0, 1.0)
			var br: int = int(roundf(lerpf(5.0, 22.0, 1.0 - a)))
			_draw_stepped_ring(p, br, Color(PAL["gold"] as Color, a * (0.45 if fred else 0.72)), 16, true)


func _draw_vents(fred: bool) -> void:
	for v: Dictionary in _vents:
		var p: Vector2 = (v["pos"] as Vector2).round()
		if not _on_screen(p) or not _is_walkable(p):
			continue
		var vp: float = fposmod(vent_cycle + float(v["phase"]), 1.0)
		draw_rect(Rect2(p + Vector2(-6.0, -4.0), Vector2(12.0, 8.0)), PAL["night"] as Color)
		draw_rect(Rect2(p + Vector2(-5.0, -3.0), Vector2(10.0, 6.0)), PAL["void"] as Color)
		var core_c: Color = (PAL["gold"] if vp >= 0.56 else (PAL["coral"] if vp >= 0.45 else PAL["wine"])) as Color
		for sy: float in [-2.0, 0.0, 2.0]:
			draw_rect(Rect2(p + Vector2(-4.0, sy), Vector2(8.0, 1.0)), core_c)
		if vp >= 0.56:
			var u: float = (vp - 0.56) / 0.44
			_draw_stepped_ring(p, int(roundf(lerpf(7.0, 18.0, sin(u * PI)))), Color(PAL["coral"] as Color, 0.42 if fred else 0.62), 14, true)
			for ei: int in range(4):
				var eu: float = fposmod(clock * 1.8 + float(ei) * 0.25, 1.0)
				var ex: float = roundf(p.x + sin(clock * 4.0 + float(ei) * 1.7) * 5.0)
				var ey: float = roundf(p.y - eu * 18.0)
				draw_rect(Rect2(ex, ey, 2.0 if ei == 0 else 1.0, 1.0), (PAL["cream"] if eu < 0.3 else PAL["gold"]) as Color)
		elif vp >= 0.32:
			_draw_stepped_ring(p, 9, Color(PAL["apricot"] as Color, 0.32), 10, true)


func _draw_mirror_reflection(fred: bool) -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if _region != null and _region.has_method("tile_at"):
		var tt: String = str(_region.call("tile_at", w.global_position))
		if not is_dungeon and tt not in ["glass", "mirror", "path", "ground"]:
			return
	var rp: Vector2 = (w.global_position + Vector2(0.0, 6.0)).round()
	var a: float = (0.20 if fred else (0.16 + 0.12 * lunar_phase))
	draw_rect(Rect2(rp + Vector2(-3.0, 0.0), Vector2(6.0, 7.0)), Color(PAL["sky"] as Color, a))
	draw_rect(Rect2(rp + Vector2(-2.0, 5.0), Vector2(4.0, 3.0)), Color(PAL["ice"] as Color, a * 1.1))
	draw_rect(Rect2(rp + Vector2(3.0, 2.0), Vector2(2.0, 2.0)), Color(PAL["gold"] as Color, a * 1.15))


func _find_walkable_near_cam() -> Vector2:
	if _region == null or not _region.has_method("tile_at"):
		return Vector2.ZERO
	for attempt: int in range(10):
		var a: float = clock * 2.7 + float(attempt) * 1.9
		var r: float = 42.0 + float(attempt % 4) * 20.0
		var cand: Vector2 = (_cam_center + Vector2.from_angle(a) * r).round()
		if bounds.grow(-24.0).has_point(cand) and _is_walkable(cand):
			return cand
	return Vector2.ZERO


func _on_screen(p: Vector2) -> bool:
	return absf(p.x - _cam_center.x) <= HALF_W and absf(p.y - _cam_center.y) <= HALF_H

func _player_pos() -> Vector2:
	return (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(-9999.0, -9999.0)

func _lantern_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan) and (lan as Object).get("pos") is Vector2:
			return (lan as Object).get("pos") as Vector2
	return _player_pos()

func _player_light_burst_active() -> bool:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return false
	var w: LxWick = Lx.player as LxWick
	return w.is_dashing() or w.muzzle_t > 0.0 or w.throw_anim_t > 0.0 or w.is_zipping()
