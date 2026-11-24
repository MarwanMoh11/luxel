class_name LxBiomeDungeonTwists
extends Node2D
## Living per-dungeon environmental twists & restrained pixel-stepped floor inlays (Dungeons 1..8).
## Renders at z_index = -6 strictly masked to solid walkable floor tiles (20 Last Light colours).

const PAL: Dictionary = LxPalette.PAL

var _rules: LxBiomeRules = null
var _region: Node = null
var _island_id: int = 1
var _active: bool = false
var _room_idx: int = 1
var _clock: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()
var _bell_wave_r: float = -1.0
var _bell_cd: float = 3.2
var _bell_pushed_ids: Array[int] = []
var _shafts: Array[Dictionary] = [] # Isl 4 drifting stained-glass sunbeams
var _sparks: Array[Dictionary] = [] # Isl 3/6 ambient dungeon motes
var _water_pts: Array[Vector2] = [] # Isl 2 caustic shimmer anchor tiles
var _spore_caps: Array[Dictionary] = [] # Isl 3 interactive spore-cap puffs
var _twist_cd: float = 0.0
var _was_dashing: bool = false
var _story_fx: LxDungeonStoryFx = LxDungeonStoryFx.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -6


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	_rules = rules
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_active = rules != null and rules.is_dungeon
	_clock = 0.0
	_bounds = rules.bounds if rules != null else Rect2(0.0, 0.0, 384.0, 224.0)
	_center = _bounds.get_center()
	_bell_wave_r = -1.0
	_bell_cd = 2.6
	_bell_pushed_ids.clear()
	_shafts.clear()
	_sparks.clear()
	_water_pts.clear()
	_spore_caps.clear()
	_twist_cd = 0.0
	_was_dashing = false
	_room_idx = _parse_room_index(region_node)
	var rid_s: String = str(region_node.get("current_region_id")) if (region_node != null and region_node.get("current_region_id") != null) else ""
	_story_fx.configure(rules, _room_idx, rid_s)
	if _active:
		_seed_room()
	queue_redraw()


static func _parse_room_index(region_node: Node) -> int:
	if region_node == null or region_node.get("current_region_id") == null:
		return 1
	var rid: String = str(region_node.get("current_region_id"))
	var pos: int = rid.rfind("_r")
	return clampi(int(rid.substr(pos + 2)), 1, 10) if pos >= 0 else 1


func _is_floor(pt: Vector2) -> bool:
	return _region != null and _region.has_method("tile_at") and str(_region.call("tile_at", pt)) in ["ground", "path"]


func _is_floor_area(pt: Vector2, r: float) -> bool:
	if not _is_floor(pt):
		return false
	if r <= 2.0:
		return true
	return _is_floor(pt + Vector2(r, 0.0)) and _is_floor(pt + Vector2(-r, 0.0)) \
		and _is_floor(pt + Vector2(0.0, r)) and _is_floor(pt + Vector2(0.0, -r))


func _draw_pixel_ring(c: Vector2, rad: int, col: Color, step_deg: int = 12) -> void:
	var n: int = maxi(8, int(roundf(360.0 / float(step_deg))))
	for i: int in range(n):
		var ang: float = (TAU * float(i)) / float(n)
		var pt: Vector2 = (c + Vector2(cos(ang), sin(ang)) * float(rad)).round()
		if _is_floor(pt):
			draw_rect(Rect2(pt, Vector2.ONE), col)


func _draw_floor_segment(a: Vector2, b: Vector2, col: Color, step_px: float = 2.0) -> void:
	var dist: float = a.distance_to(b)
	if dist < 1.0:
		return
	var steps: int = maxi(1, int(ceilf(dist / maxf(1.0, step_px))))
	for i: int in range(steps + 1):
		var pt: Vector2 = a.lerp(b, float(i) / float(steps)).round()
		if _is_floor(pt):
			draw_rect(Rect2(pt, Vector2.ONE), col)


func _seed_room() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_island_id * 977 + _room_idx * 131)
	if _island_id == 2 and _region != null:
		var grid_v: Variant = _region.get("grid")
		if grid_v is Array:
			var grid: Array = grid_v as Array
			for ty: int in range(1, grid.size() - 1, 2):
				var row: PackedStringArray = grid[ty] as PackedStringArray
				for tx: int in range(1, row.size() - 1, 2):
					if row[tx] in ["water", "tide"] and _water_pts.size() < 18:
						_water_pts.append(Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0))
	elif _island_id == 4:
		for k: int in range(2):
			_shafts.append({
				"x": _bounds.position.x + _bounds.size.x * (0.30 + float(k) * 0.40),
				"y": _center.y, "phase": float(k) * PI, "col": "rose" if k == 0 else "ice",
			})
	elif _island_id in [3, 6]:
		for k: int in range(12):
			_sparks.append({
				"x": rng.randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0),
				"y": rng.randf_range(_bounds.position.y + 20.0, _bounds.end.y - 20.0),
				"spd": rng.randf_range(12.0, 26.0), "phase": rng.randf_range(0.0, TAU),
			})
		if _island_id == 3:
			for k: int in range(2):
				var sx: float = _center.x + (-68.0 if k == 0 else 68.0)
				var sy: float = _center.y + (-26.0 if k == 0 else 26.0)
				var cand := Vector2(clampf(sx, _bounds.position.x + 40.0, _bounds.end.x - 40.0), clampf(sy, _bounds.position.y + 40.0, _bounds.end.y - 40.0)).round()
				if _is_floor_area(cand, 6.0):
					_spore_caps.append({"pos": cand, "cd": 0.0, "burst_t": 0.0})


func tick(dt: float) -> void:
	if not _active or dt <= 0.0 or _rules == null:
		return
	_clock += dt
	_twist_cd = maxf(0.0, _twist_cd - dt)
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var dashing_now: bool = w != null and not w.dead and w.is_dashing()
	var dash_started: bool = dashing_now and not _was_dashing
	match _island_id:
		1: # Great Belfry: periodic golden acoustic bell-chime pulse nudges nearby non-boss foes & feeds soft Ember
			_bell_cd -= dt
			if _bell_cd <= 0.0:
				_bell_cd = 6.8
				_bell_wave_r = 10.0
				_bell_pushed_ids.clear()
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(_center, 86.0, 0.72 if LxHudFx.flash_reduced() else 1.05, 0.42)
				if w != null and not w.dead and w.global_position.distance_to(_center) <= 96.0:
					if w.move_sunflare != null and w.move_sunflare.unlocked:
						w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 1.5)
					if Lx.audio != null:
						Lx.audio.play_sfx("prop_chime", _center, true)
			if _bell_wave_r >= 0.0:
				_bell_wave_r += 118.0 * dt
				_nudge_foes_on_wave(_center, _bell_wave_r, 14.0, 38.0)
				if _bell_wave_r > maxf(_bounds.size.x, _bounds.size.y) * 0.55:
					_bell_wave_r = -1.0
		2: # Lighthouse: single sweeping Fresnel beam synced with LxBiomeRules
			var b_ang2: float = PI * 0.5 + sin(_clock * 0.42 + float(_room_idx) * 0.9) * 0.95
			var b_orig2 := Vector2(_center.x, _bounds.position.y + 18.0)
			_rules.beam_origin = b_orig2
			_rules.beam_angle = b_ang2
			if w != null and not w.dead:
				var delta2: Vector2 = w.global_position - b_orig2
				var b_span2: float = minf(_bounds.size.x, _bounds.size.y) * 0.85
				if delta2.length() <= b_span2 and delta2.length_squared() > 16.0:
					if absf(wrapf(delta2.angle() - b_ang2, -PI, PI)) <= 0.17:
						_rules.beam_buff_t = maxf(_rules.beam_buff_t, 1.4)
		3: # Hollow Oak: floating forest spores + interactive Spore-Caps
			for sp: Dictionary in _sparks:
				sp["y"] = float(sp["y"]) - float(sp["spd"]) * 0.45 * dt
				sp["x"] = float(sp["x"]) + sin(_clock * 1.6 + float(sp["phase"])) * 7.0 * dt
				if float(sp["y"]) < _bounds.position.y + 12.0:
					sp["y"] = _bounds.end.y - 14.0
			for cap: Dictionary in _spore_caps:
				cap["cd"] = maxf(0.0, float(cap["cd"]) - dt)
				cap["burst_t"] = maxf(0.0, float(cap["burst_t"]) - dt)
				if w != null and not w.dead and float(cap["cd"]) <= 0.0 and (dashing_now or w.is_zipping()):
					var cp: Vector2 = cap["pos"] as Vector2
					if w.global_position.distance_to(cp) <= 22.0:
						cap["cd"] = 4.5
						cap["burst_t"] = 0.45
						_trigger_spore_puff(cp)
		4: # Sunken Conservatory: drifting stained-glass sunbeams recharge Ember & extend Glide Tailwind
			for sh: Dictionary in _shafts:
				var sx: float = _center.x + sin(_clock * 0.35 + float(sh["phase"])) * (_bounds.size.x * 0.28)
				sh["x"] = sx
				if w != null and not w.dead and absf(w.global_position.x - sx) <= 22.0:
					if w.move_sunflare != null and w.move_sunflare.unlocked:
						w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 4.5 * dt)
					if w.is_gliding() and LxBiomeMechanics.active_instance != null:
						LxBiomeMechanics.active_instance.tailwind_t = maxf(LxBiomeMechanics.active_instance.tailwind_t, 1.4)
		5: # Grand Orrery: rotating brass planetary conjunction nodes grant Starlight Surge
			if w != null and not w.dead:
				var d: float = w.global_position.distance_to(_center)
				if absf(d - 58.0) <= 10.0 or absf(d - 96.0) <= 10.0:
					_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 0.45)
				if _twist_cd <= 0.0:
					for npt: Vector2 in _orrery_node_positions():
						if w.global_position.distance_to(npt) <= 16.0:
							_twist_cd = 2.4
							_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 2.8)
							w.spawn_ring(npt, 2.0, 16.0, 0.24, LxWick.PAL_GOLD, 1.2)
							if Lx.audio != null:
								Lx.audio.play_sfx("clockwork_chime", npt, true)
							break
		6: # Great Kiln: furnace ember gust empowers Flare-Dashing west with +1 Molten Overdrive charge
			var gust_on: bool = fposmod(_clock, 6.0) >= 4.4
			var gust: float = 2.2 if gust_on else 1.0
			for sp: Dictionary in _sparks:
				sp["x"] = float(sp["x"]) - float(sp["spd"]) * gust * dt
				sp["y"] = float(sp["y"]) - float(sp["spd"]) * 0.35 * dt
				if float(sp["x"]) < _bounds.position.x + 12.0:
					sp["x"] = _bounds.end.x - 14.0
				if float(sp["y"]) < _bounds.position.y + 12.0:
					sp["y"] = _bounds.end.y - 14.0
			if gust_on and dash_started and _twist_cd <= 0.0 and w != null and w.facing.x < -0.25:
				_twist_cd = 2.2
				if LxBiomeMechanics.active_instance != null:
					LxBiomeMechanics.active_instance.molten_charges = mini(3, LxBiomeMechanics.active_instance.molten_charges + 1)
				w.spawn_sparks(w.global_position, Vector2.LEFT, 5, LxWick.PAL_APRICOT, 28.0, 72.0, 0.22)
				if Lx.audio != null:
					Lx.audio.play_sfx("furnace_draw", w.global_position, true)
		7: # Moon Spire: dashing across lunar focus during Full Silver Moon illuminates chamber
			if _rules.lunar_phase > 0.65 and dash_started and _twist_cd <= 0.0 and w != null and w.global_position.distance_to(_center) <= 36.0:
				_twist_cd = 2.6
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(_center, 110.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.55)
				if Lx.audio != null:
					Lx.audio.play_sfx("lens_reveal", _center, true)
		8: # Bell Sanctum: Dawn Cracks pulse bonus Ember toward Sunflare during heartbeat peaks
			var beat: float = 0.5 + 0.5 * sin(_clock * 2.1)
			if beat > 0.82 and _twist_cd <= 0.0 and w != null and not w.dead and w.move_sunflare != null and w.move_sunflare.unlocked:
				if w.global_position.distance_to(_center) <= 46.0:
					_twist_cd = 3.0
					w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 4.0)
					w.spawn_sparks(w.global_position, Vector2.UP, 4, LxWick.PAL_GOLD, 16.0, 42.0, 0.24)
					if Lx.audio != null:
						Lx.audio.play_sfx("eclipse_wave", w.global_position, true)
	_was_dashing = dashing_now
	_story_fx.tick(dt, w)
	queue_redraw()


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick) -> void:
	if not _active or _rules == null:
		return
	_story_fx.try_hit_segment(from_p, to_p, w)
	if _island_id == 3:
		for cap: Dictionary in _spore_caps:
			if float(cap["cd"]) > 0.0:
				continue
			var cp: Vector2 = cap["pos"] as Vector2
			if Geometry2D.get_closest_point_to_segment(cp, from_p, to_p).distance_to(cp) <= 14.0:
				cap["cd"] = 4.5
				cap["burst_t"] = 0.45
				_trigger_spore_puff(cp)
				return
	elif _island_id == 4 and _twist_cd <= 0.0:
		var mid_p: Vector2 = from_p.lerp(to_p, 0.5)
		for sh: Dictionary in _shafts:
			var sx: float = float(sh["x"])
			if absf(mid_p.x - sx) <= 18.0 or absf(to_p.x - sx) <= 18.0:
				_twist_cd = 2.0
				var hit_pt := Vector2(sx, clampf(mid_p.y, _bounds.position.y + 24.0, _bounds.end.y - 24.0))
				if w != null and is_instance_valid(w):
					if w.move_sunflare != null and w.move_sunflare.unlocked:
						w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 3.0)
					w.spawn_ring(hit_pt, 3.0, 20.0, 0.26, LxWick.PAL_ICE, 1.3)
				if Lx.audio != null:
					Lx.audio.play_sfx("prop_chime", hit_pt, true)
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(hit_pt, 72.0, 0.78 if LxHudFx.flash_reduced() else 1.12, 0.36)
				return
	elif _island_id == 5 and _twist_cd <= 0.0:
		for npt: Vector2 in _orrery_node_positions():
			if Geometry2D.get_closest_point_to_segment(npt, from_p, to_p).distance_to(npt) <= 14.0:
				_twist_cd = 2.4
				_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 2.8)
				if w != null and is_instance_valid(w):
					w.spawn_ring(npt, 2.0, 16.0, 0.24, LxWick.PAL_GOLD, 1.2)
				if Lx.audio != null:
					Lx.audio.play_sfx("clockwork_chime", npt, true)
				return
	elif _island_id == 7 and _rules.lunar_phase > 0.65 and _twist_cd <= 0.0:
		if Geometry2D.get_closest_point_to_segment(_center, from_p, to_p).distance_to(_center) <= 22.0:
			_twist_cd = 2.6
			if w != null and is_instance_valid(w):
				w.spawn_ring(_center, 4.0, 32.0, 0.30, LxWick.PAL_ICE, 1.5)
			if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
				LxDarknessLayer.active_instance.add_burst_light(_center, 110.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.55)
			if Lx.audio != null:
				Lx.audio.play_sfx("lens_reveal", _center, true)


func _orrery_node_positions() -> Array[Vector2]:
	var rot1: float = _clock * 0.55
	var rot2: float = -_clock * 0.38
	return [_center + Vector2(cos(rot1), sin(rot1)) * 58.0, _center + Vector2(cos(rot2), sin(rot2)) * 96.0]


func _nudge_foes_on_wave(origin: Vector2, wave_r: float, band: float, force: float) -> void:
	if _region == null or not _region.has_method("get_enemies"):
		return
	var enemies_v: Variant = _region.call("get_enemies")
	if not (enemies_v is Array):
		return
	for e_v: Variant in (enemies_v as Array):
		if e_v is LxEnemyBrain and is_instance_valid(e_v):
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if not e.is_alive() or e.is_boss:
				continue
			var eid: int = e.get_instance_id()
			if _bell_pushed_ids.has(eid):
				continue
			var d: float = e.pos.distance_to(origin)
			if absf(d - wave_r) <= band:
				_bell_pushed_ids.append(eid)
				e.knock += ((e.pos - origin).normalized() if d > 1.0 else Vector2.RIGHT) * force


func _trigger_spore_puff(at: Vector2) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at, 84.0, 0.82 if LxHudFx.flash_reduced() else 1.18, 0.45)
	if Lx.audio != null:
		Lx.audio.play_sfx("spore_pop", at, true)
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and not e.is_boss and e.pos.distance_to(at) <= 68.0:
						e.knock += ((e.pos - at).normalized() if e.pos.distance_to(at) > 1.0 else Vector2.RIGHT) * 65.0
						e.flash_t = maxf(e.flash_t, 0.25)


func _draw() -> void:
	if not _active or _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	_draw_chamber_architecture(fred)
	_story_fx.draw_toys(self, _rules, fred)
	if _room_idx in [1, 5, 9] or (_island_id == 1 and _room_idx == 6):
		_draw_architectural_medallion(fred)
	match _island_id:
		1:
			if _bell_wave_r >= 0.0:
				var max_r: float = maxf(_bounds.size.x, _bounds.size.y) * 0.55
				var u: float = clampf(_bell_wave_r / maxf(max_r, 1.0), 0.0, 1.0)
				_draw_pixel_ring(_center.round(), int(roundf(_bell_wave_r)), Color(PAL["gold"] as Color, (1.0 - u) * (0.20 if fred else 0.34)), 10)
		2:
			# Single crisp Lighthouse Fresnel beam (synced to _rules.beam_origin/beam_angle)
			var b_orig: Vector2 = _rules.beam_origin.round()
			var b_span: float = minf(_bounds.size.x, _bounds.size.y) * 0.85
			var b_p1: Vector2 = (b_orig + Vector2.from_angle(_rules.beam_angle - 0.14) * b_span).round()
			var b_p2: Vector2 = (b_orig + Vector2.from_angle(_rules.beam_angle + 0.14) * b_span).round()
			draw_colored_polygon(PackedVector2Array([b_orig, b_p1, b_p2]), Color(PAL["ice"] as Color, 0.05 if fred else 0.08))
			var a2: float = 0.20 if fred else 0.32
			for wp: Vector2 in _water_pts:
				var phase: float = fposmod(_clock * 1.1 + wp.x * 0.03 + wp.y * 0.02, 1.0)
				var rr: int = int(roundf(lerpf(2.0, 6.0, phase)))
				var c2 := Color(PAL["ice"] as Color, (1.0 - phase) * a2)
				draw_rect(Rect2(wp.round() + Vector2(-rr, 0), Vector2(rr * 2 + 1, 1.0)), c2)
		3:
			var a3: float = 0.38 if fred else 0.62
			for i: int in range(_sparks.size()):
				var sp: Dictionary = _sparks[i]
				draw_rect(Rect2(roundf(float(sp["x"])), roundf(float(sp["y"])), 2.0 if i % 3 == 0 else 1.0, 1.0), Color((PAL["lime"] if i % 2 == 0 else PAL["gold"]) as Color, a3))
			for cap: Dictionary in _spore_caps:
				var cp: Vector2 = (cap["pos"] as Vector2).round()
				if not _is_floor(cp):
					continue
				var ready_c: bool = float(cap["cd"]) <= 0.0
				draw_rect(Rect2(cp + Vector2(-4.0, -2.0), Vector2(8.0, 5.0)), Color((PAL["jade"] if ready_c else PAL["pine"]) as Color, 0.65))
				draw_rect(Rect2(cp + Vector2(-3.0, -3.0), Vector2(6.0, 2.0)), Color((PAL["lime"] if ready_c else PAL["teal"]) as Color, 0.72))
				if ready_c:
					draw_rect(Rect2(cp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
				var bt: float = float(cap["burst_t"])
				if bt > 0.0:
					var bu: float = 1.0 - clampf(bt / 0.45, 0.0, 1.0)
					_draw_pixel_ring(cp, int(roundf(lerpf(6.0, 60.0, bu))), Color(PAL["lime"] as Color, (1.0 - bu) * 0.55), 10)
		4:
			var a4: float = 0.05 if fred else 0.08
			for sh: Dictionary in _shafts:
				var sx: float = roundf(float(sh["x"]))
				var top_y: float = _bounds.position.y + 16.0
				var bot_y: float = _bounds.end.y - 16.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(sx - 10.0, top_y), Vector2(sx + 10.0, top_y),
					Vector2(sx + 22.0, bot_y), Vector2(sx + 2.0, bot_y),
				]), Color(PAL[str(sh["col"])] as Color, a4))
		5:
			# Restrained pixel-stepped brass floor inlay tracks (strictly masked to walkable stone)
			var a5: float = 0.14 if fred else 0.20
			var c_pt: Vector2 = _center.round()
			_draw_pixel_ring(c_pt, 58, Color(PAL["gold"] as Color, a5), 10)
			_draw_pixel_ring(c_pt, 96, Color(PAL["sky"] as Color, a5 * 0.85), 8)
			for npt: Vector2 in _orrery_node_positions():
				var np: Vector2 = npt.round()
				if _is_floor(np):
					draw_rect(Rect2(np + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), Color(PAL["gold"] as Color, 0.55))
					draw_rect(Rect2(np - Vector2.ONE, Vector2(3.0, 3.0)), Color(PAL["cream"] as Color, 0.78))
		6:
			var gust_on: bool = fposmod(_clock, 6.0) >= 4.4
			var a6: float = (0.48 if gust_on else 0.30) if not fred else 0.26
			for i: int in range(_sparks.size()):
				var sp: Dictionary = _sparks[i]
				draw_rect(Rect2(roundf(float(sp["x"])), roundf(float(sp["y"])), 3.0 if gust_on else 2.0, 1.0), Color((PAL["gold"] if i % 3 == 0 else PAL["coral"]) as Color, a6))
		7:
			if _rules.lunar_phase > 0.5:
				var a7: float = (0.12 if fred else 0.18) * clampf((_rules.lunar_phase - 0.5) * 2.0, 0.0, 1.0)
				_draw_pixel_ring(_center.round(), 30, Color(PAL["ice"] as Color, a7), 12)
		8:
			var c8: Vector2 = _center.round()
			var a8: float = 0.14 if fred else 0.20
			for k: int in range(mini(_room_idx, 6)):
				var ang: float = float(k) * (TAU / 6.0) + 0.3
				_draw_floor_segment((c8 + Vector2(cos(ang) * 16.0, sin(ang) * 10.0)).round(), (c8 + Vector2(cos(ang) * 40.0, sin(ang) * 24.0)).round(), Color(PAL["gold"] as Color, a8), 2.0)


func _draw_architectural_medallion(fred: bool) -> void:
	# Restrained pixel-stepped stone floor inlay strictly masked to walkable stone floors (alpha <= 0.20)
	var c: Vector2 = _center.round()
	if not _is_floor_area(c, 16.0):
		return
	var c_mid: Color = LxBiomePalette.col(_island_id, "mid")
	var c_hi: Color = LxBiomePalette.col(_island_id, "hi")
	var a: float = 0.14 if fred else 0.20
	var rad: int = 24 if _room_idx == 1 else (28 if _room_idx == 5 else 26)
	_draw_pixel_ring(c, rad, Color(c_mid, a), 10)
	_draw_pixel_ring(c, rad - 5, Color(c_hi, a * 0.8), 15)
	var spokes: int = 8 if _island_id in [2, 5, 8] else (6 if _island_id in [3, 4, 6] else 4)
	for k: int in range(spokes):
		var ang: float = float(k) * (TAU / float(spokes)) + (0.0 if _island_id % 2 == 0 else PI / float(spokes))
		_draw_floor_segment((c + Vector2.from_angle(ang) * 7.0).round(), (c + Vector2.from_angle(ang) * float(rad - 3)).round(), Color(c_hi if k % 2 == 0 else c_mid, a * 0.85), 3.0)


func _draw_chamber_architecture(fred: bool) -> void:
	# Subtle pixel-stepped stone floor inlays gated strictly on solid walkable tiles (alpha <= 0.22)
	var x0: float = _bounds.position.x + 18.0
	var y0: float = _bounds.position.y + 18.0
	var x1: float = _bounds.end.x - 18.0
	var y1: float = _bounds.end.y - 18.0
	if x1 - x0 < 64.0 or y1 - y0 < 48.0:
		return
	var c: Vector2 = _center.round()
	var a: float = 0.14 if fred else 0.20
	var corners: Array[Vector2] = [
		Vector2(x0 + 10.0, y0 + 10.0).round(), Vector2(x1 - 10.0, y0 + 10.0).round(),
		Vector2(x0 + 10.0, y1 - 10.0).round(), Vector2(x1 - 10.0, y1 - 10.0).round(),
	]
	match _island_id:
		1: # Great Belfry: subtle nave flagstone grooves & corner stone brackets
			var groove_c := Color(PAL["stone"] as Color, a * 0.9)
			_draw_floor_segment(Vector2(x0 + 26.0, c.y - 26.0).round(), Vector2(x1 - 26.0, c.y - 26.0).round(), groove_c, 3.0)
			_draw_floor_segment(Vector2(x0 + 26.0, c.y + 26.0).round(), Vector2(x1 - 26.0, c.y + 26.0).round(), groove_c, 3.0)
			for cp1: Vector2 in corners:
				if _is_floor_area(cp1, 6.0):
					draw_rect(Rect2(cp1 + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), Color(PAL["apricot"] as Color, a), false, 1.0)
		2: # Lighthouse: brass compass pips on walkable stone floor
			for dir2: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var pip: Vector2 = (c + Vector2(dir2.x * minf(64.0, (x1 - x0) * 0.34), dir2.y * minf(40.0, (y1 - y0) * 0.34))).round()
				if _is_floor_area(pip, 4.0):
					_draw_floor_segment(pip - dir2 * 3.0, pip + dir2 * 3.0, Color(PAL["sky"] as Color, a * 1.05), 1.0)
		3: # Hollow Oak: subtle creeping moss-inlaid root lines strictly on stone floor
			for idx3: int in range(4):
				var cp3: Vector2 = corners[idx3]
				if not _is_floor_area(cp3, 6.0):
					continue
				var inward: Vector2 = (c - cp3).normalized()
				var tip3: Vector2 = (cp3 + inward * 20.0).round()
				_draw_floor_segment(cp3, tip3, Color(PAL["teal"] as Color, a * 1.1), 2.0)
				if _is_floor(tip3):
					draw_rect(Rect2(tip3, Vector2(2.0, 2.0)), Color(PAL["lime"] as Color, a))
		4: # Sunken Conservatory: small inlaid tile diamonds strictly on solid floor corners
			var glass_cols: Array[Color] = [PAL["rose"] as Color, PAL["ice"] as Color, PAL["gold"] as Color, PAL["sky"] as Color]
			for idx4: int in range(4):
				var cp4: Vector2 = corners[idx4]
				if not _is_floor_area(cp4, 6.0):
					continue
				var gc := Color(glass_cols[(idx4 + _room_idx) % 4], a)
				draw_rect(Rect2(cp4 + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), gc)
				draw_rect(Rect2(cp4 + Vector2(-1.0, -2.0), Vector2(3.0, 5.0)), gc)
		5: # Grand Orrery: etched floor meridian grooves & small brass corner inlays
			_draw_floor_segment(Vector2(x0 + 20.0, c.y).round(), Vector2(x1 - 20.0, c.y).round(), Color(PAL["blue"] as Color, a * 0.85), 3.0)
			_draw_floor_segment(Vector2(c.x, y0 + 16.0).round(), Vector2(c.x, y1 - 16.0).round(), Color(PAL["blue"] as Color, a * 0.85), 3.0)
			for cp5: Vector2 in corners:
				if _is_floor_area(cp5, 6.0):
					_draw_pixel_ring(cp5, 5, Color(PAL["gold"] as Color, a), 30)
		6: # Great Kiln: recessed corner iron floor-grates strictly on solid basalt floor
			var gust6: bool = fposmod(_clock, 6.0) >= 4.4
			var ember6: Color = (PAL["gold"] if gust6 else PAL["coral"]) as Color
			for cp6: Vector2 in corners:
				if not _is_floor_area(cp6, 8.0):
					continue
				var gr := Rect2((cp6 - Vector2(6.0, 4.0)).round(), Vector2(12.0, 8.0))
				draw_rect(gr, Color(PAL["void"] as Color, a * 1.1))
				for slat: int in range(3):
					draw_rect(Rect2(gr.position.x + 2.0, gr.position.y + 1.0 + float(slat) * 3.0, gr.size.x - 4.0, 1.0), Color(ember6, a * (1.1 if gust6 else 0.75)))
		7: # Moon Spire: subtle silver floor-tile inlay strips strictly on walkable slate
			var sheen7: float = a * (0.65 + 0.35 * clampf(_rules.lunar_phase, 0.15, 1.0))
			var half_w: float = minf(44.0, (x1 - x0) * 0.22)
			for sy7: float in [y0 + 10.0, y1 - 10.0]:
				_draw_floor_segment(Vector2(roundf(c.x - half_w), roundf(sy7)), Vector2(roundf(c.x + half_w), roundf(sy7)), Color(PAL["sky"] as Color, sheen7), 2.0)
		8: # Bell Sanctum: subtle plum/rose cathedral stone floor tracery strictly on solid nave floor
			var vein_col: Color = (PAL["cream"] if _room_idx >= 5 else (PAL["gold"] if _room_idx >= 3 else PAL["rose"])) as Color
			for cp8: Vector2 in corners:
				if not _is_floor_area(cp8, 8.0):
					continue
				var inward8: Vector2 = (c - cp8).normalized()
				_draw_pixel_ring(cp8, 6, Color(PAL["plum"] as Color, a), 30)
				_draw_floor_segment(cp8, (cp8 + inward8 * 18.0).round(), Color(vein_col, a), 2.0)
