class_name LxBiomeDungeonTwists
extends Node2D
## Living per-dungeon environmental twists running inside every chamber of Dungeons 1..8.
## Gives each dungeon a distinct tactile rhythm beyond tile art (strictly 20 Last Light colours, zero aim assist).

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
var _sparks: Array[Dictionary] = [] # Isl 3/4/6 ambient dungeon motes
var _water_pts: Array[Vector2] = [] # Isl 2 caustic shimmer anchor tiles
var _spore_caps: Array[Dictionary] = [] # Isl 3 interactive spore-cap puffs
var _twist_cd: float = 0.0
var _was_dashing: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2


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
	if _active:
		_seed_room()
	queue_redraw()


static func _parse_room_index(region_node: Node) -> int:
	if region_node == null or region_node.get("current_region_id") == null:
		return 1
	var rid: String = str(region_node.get("current_region_id"))
	var pos: int = rid.rfind("_r")
	if pos >= 0:
		return clampi(int(rid.substr(pos + 2)), 1, 10)
	return 1


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
				"y": _center.y,
				"phase": float(k) * PI,
				"col": "rose" if k == 0 else "ice",
			})
	elif _island_id in [3, 6]:
		for k: int in range(14):
			_sparks.append({
				"x": rng.randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0),
				"y": rng.randf_range(_bounds.position.y + 20.0, _bounds.end.y - 20.0),
				"spd": rng.randf_range(12.0, 28.0),
				"phase": rng.randf_range(0.0, TAU),
			})
		if _island_id == 3 and _region != null and _region.has_method("tile_at"):
			for k: int in range(2):
				var sx: float = _center.x + (-68.0 if k == 0 else 68.0)
				var sy: float = _center.y + (-26.0 if k == 0 else 26.0)
				var cand := Vector2(clampf(sx, _bounds.position.x + 40.0, _bounds.end.x - 40.0), clampf(sy, _bounds.position.y + 40.0, _bounds.end.y - 40.0)).round()
				if str(_region.call("tile_at", cand)) in ["ground", "floor", "path"]:
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
		1: # Great Belfry: periodic golden acoustic bell-chime pulse nudges nearby non-boss foes
			_bell_cd -= dt
			if _bell_cd <= 0.0:
				_bell_cd = 6.8
				_bell_wave_r = 10.0
				_bell_pushed_ids.clear()
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(_center, 86.0, 0.72 if LxHudFx.flash_reduced() else 1.05, 0.42)
			if _bell_wave_r >= 0.0:
				_bell_wave_r += 118.0 * dt
				_nudge_foes_on_wave(_center, _bell_wave_r, 14.0, 38.0)
				if _bell_wave_r > maxf(_bounds.size.x, _bounds.size.y) * 0.55:
					_bell_wave_r = -1.0
		3: # Hollow Oak: floating forest spores + interactive Spore-Caps that puff foes back on dash/zip
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
		5: # Grand Orrery: rotating brass planetary rings & glowing Conjunction Nodes grant Starlight Surge
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
								Lx.audio.play_sfx("prop_chime", npt, true)
							break
		6: # Great Kiln: furnace ember gust empowers Flare-Dashing west with +1 Molten Overdrive charge!
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
		7: # Moon Spire: dashing across the silver lunar focus during Full Silver Moon illuminates the chamber
			if _rules.lunar_phase > 0.65 and dash_started and _twist_cd <= 0.0 and w != null and w.global_position.distance_to(_center) <= 36.0:
				_twist_cd = 2.6
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(_center, 110.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.55)
				if Lx.audio != null:
					Lx.audio.play_sfx("prop_chime", _center, true)
		8: # Bell Sanctum: Dawn Cracks pulse bonus Ember toward Sunflare during heartbeat peaks
			var beat: float = 0.5 + 0.5 * sin(_clock * 2.1)
			if beat > 0.82 and _twist_cd <= 0.0 and w != null and not w.dead and w.move_sunflare != null and w.move_sunflare.unlocked:
				if w.global_position.distance_to(_center) <= 46.0:
					_twist_cd = 3.0
					w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 4.0)
					w.spawn_sparks(w.global_position, Vector2.UP, 4, LxWick.PAL_GOLD, 16.0, 42.0, 0.24)
	_was_dashing = dashing_now
	queue_redraw()


func _orrery_node_positions() -> Array[Vector2]:
	var rot1: float = _clock * 0.55
	var rot2: float = -_clock * 0.38
	return [
		_center + Vector2(cos(rot1), sin(rot1)) * 58.0,
		_center + Vector2(cos(rot2), sin(rot2)) * 96.0,
	]


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
				var kdir: Vector2 = (e.pos - origin).normalized() if d > 1.0 else Vector2.RIGHT
				e.knock += kdir * force


func _trigger_spore_puff(at: Vector2) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at, 84.0, 0.82 if LxHudFx.flash_reduced() else 1.18, 0.45)
	if Lx.audio != null:
		Lx.audio.play_sfx("prop_rustle", at, true)
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and not e.is_boss and e.pos.distance_to(at) <= 68.0:
						var kdir: Vector2 = (e.pos - at).normalized() if e.pos.distance_to(at) > 1.0 else Vector2.RIGHT
						e.knock += kdir * 65.0
						e.flash_t = maxf(e.flash_t, 0.25)


func _draw() -> void:
	if not _active or _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	match _island_id:
		1:
			if _bell_wave_r >= 0.0:
				var max_r: float = maxf(_bounds.size.x, _bounds.size.y) * 0.55
				var u: float = clampf(_bell_wave_r / maxf(max_r, 1.0), 0.0, 1.0)
				var a: float = (1.0 - u) * (0.35 if fred else 0.62)
				draw_arc(_center.round(), roundf(_bell_wave_r), 0.0, TAU, 28, Color(PAL["gold"] as Color, a), 1.4)
				draw_arc(_center.round(), roundf(maxf(4.0, _bell_wave_r - 6.0)), 0.0, TAU, 24, Color(PAL["cream"] as Color, a * 0.7), 1.0)
		2:
			var a2: float = 0.28 if fred else 0.48
			for wp: Vector2 in _water_pts:
				var phase: float = fposmod(_clock * 1.1 + wp.x * 0.03 + wp.y * 0.02, 1.0)
				var rr: float = roundf(lerpf(2.0, 7.0, phase))
				draw_arc(wp.round(), rr, 0.0, TAU, 10, Color(PAL["ice"] as Color, (1.0 - phase) * a2), 1.0)
			if _rules.beam_buff_t > 0.0 and Lx.player is LxWick and is_instance_valid(Lx.player):
				var pp: Vector2 = (Lx.player as LxWick).global_position.round()
				draw_arc(pp, 11.0, _clock * 4.0, _clock * 4.0 + PI, 12, Color(PAL["gold"] as Color, 0.72), 1.2)
		3:
			var a3: float = 0.45 if fred else 0.72
			for i: int in range(_sparks.size()):
				var sp: Dictionary = _sparks[i]
				var pt := Vector2(roundf(float(sp["x"])), roundf(float(sp["y"])))
				draw_rect(Rect2(pt, Vector2(2.0 if i % 3 == 0 else 1.0, 1.0)), Color((PAL["lime"] if i % 2 == 0 else PAL["gold"]) as Color, a3))
			for cap: Dictionary in _spore_caps:
				var cp: Vector2 = (cap["pos"] as Vector2).round()
				var ready_c: bool = float(cap["cd"]) <= 0.0
				draw_circle(cp, 5.0 if ready_c else 3.0, Color((PAL["jade"] if ready_c else PAL["pine"]) as Color, 0.55))
				if ready_c:
					draw_arc(cp, 6.0 + roundf(sin(_clock * 3.0)), 0.0, TAU, 12, Color(PAL["lime"] as Color, a3 * 0.7), 1.0)
					draw_rect(Rect2(cp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
				var bt: float = float(cap["burst_t"])
				if bt > 0.0:
					var bu: float = 1.0 - clampf(bt / 0.45, 0.0, 1.0)
					draw_arc(cp, roundf(lerpf(6.0, 68.0, bu)), 0.0, TAU, 20, Color(PAL["lime"] as Color, (1.0 - bu) * a3), 1.6)
		4:
			var a4: float = 0.06 if fred else 0.11
			for sh: Dictionary in _shafts:
				var sx: float = roundf(float(sh["x"]))
				var top_y: float = _bounds.position.y + 12.0
				var bot_y: float = _bounds.end.y - 12.0
				var poly := PackedVector2Array([
					Vector2(sx - 12.0, top_y), Vector2(sx + 12.0, top_y),
					Vector2(sx + 28.0, bot_y), Vector2(sx + 4.0, bot_y),
				])
				draw_colored_polygon(poly, Color(PAL[str(sh["col"])] as Color, a4))
				draw_line(Vector2(sx, top_y), Vector2(sx + 16.0, bot_y), Color(PAL["cream"] as Color, a4 * 1.4), 1.0)
		5:
			var a5: float = 0.22 if fred else 0.38
			var rot1: float = _clock * 0.55
			var rot2: float = -_clock * 0.38
			var c_pt: Vector2 = _center.round()
			draw_arc(c_pt, 58.0, rot1, rot1 + 2.2, 20, Color(PAL["gold"] as Color, a5), 1.2)
			draw_arc(c_pt, 58.0, rot1 + PI, rot1 + PI + 2.2, 20, Color(PAL["sky"] as Color, a5), 1.2)
			draw_arc(c_pt, 96.0, rot2, rot2 + 1.8, 24, Color(PAL["gold"] as Color, a5 * 0.85), 1.0)
			draw_arc(c_pt, 96.0, rot2 + PI, rot2 + PI + 1.8, 24, Color(PAL["ice"] as Color, a5 * 0.85), 1.0)
			for npt: Vector2 in _orrery_node_positions():
				var np: Vector2 = npt.round()
				draw_circle(np, 3.5, Color(PAL["gold"] as Color, a5 * 1.8))
				draw_rect(Rect2(np - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
		6:
			var gust_on: bool = fposmod(_clock, 6.0) >= 4.4
			var a6: float = (0.55 if gust_on else 0.34) if not fred else 0.30
			for i: int in range(_sparks.size()):
				var sp: Dictionary = _sparks[i]
				var pt := Vector2(roundf(float(sp["x"])), roundf(float(sp["y"])))
				var col: Color = (PAL["gold"] if i % 3 == 0 else PAL["coral"]) as Color
				draw_rect(Rect2(pt, Vector2(3.0 if gust_on else 2.0, 1.0)), Color(col, a6))
		7:
			if _rules.lunar_phase > 0.5:
				var a7: float = (0.18 if fred else 0.30) * clampf((_rules.lunar_phase - 0.5) * 2.0, 0.0, 1.0)
				var c7: Vector2 = _center.round()
				draw_line(Vector2(_bounds.position.x + 24.0, c7.y), Vector2(_bounds.end.x - 24.0, c7.y), Color(PAL["ice"] as Color, a7), 1.0)
				draw_arc(c7, 34.0, -PI * 0.35, PI * 0.35, 14, Color(PAL["sky"] as Color, a7 * 1.4), 1.2)
				draw_arc(c7, 34.0, PI * 0.65, PI * 1.35, 14, Color(PAL["ice"] as Color, a7 * 1.4), 1.2)
		8:
			var beat: float = 0.5 + 0.5 * sin(_clock * 2.1)
			var a8: float = (0.14 if fred else 0.24) * beat
			var c8: Vector2 = _center.round()
			draw_arc(c8, roundf(lerpf(28.0, 56.0, beat)), 0.0, TAU, 22, Color(PAL["rose"] as Color, a8), 1.2)
			# Progressive golden Dawn Cracks brightening as Wick nears the Great Bell (r1 -> r6)
			for k: int in range(mini(_room_idx, 6)):
				var ang: float = float(k) * (TAU / 6.0) + 0.3
				var p0: Vector2 = (c8 + Vector2(cos(ang) * 18.0, sin(ang) * 12.0)).round()
				var p1: Vector2 = (c8 + Vector2(cos(ang) * 44.0, sin(ang) * 28.0)).round()
				draw_line(p0, p1, Color(PAL["gold"] as Color, 0.25 if fred else 0.42), 1.0)
