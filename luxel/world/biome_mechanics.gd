class_name LxBiomeMechanics
extends Node2D
## Deep interactive per-island gameplay payoffs complementing LxBiomeRules (Islands 1..8).
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL) and ZERO aim assist.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 184.0
const HALF_H: float = 114.0

static var active_instance: LxBiomeMechanics = null

var _rules: LxBiomeRules = null
var _region: Node = null
var _decals: LxGroundDecals = null
var _weather: LxBiomeWeather = null
var _boss_synergy: LxBiomeBossSynergy = null
var _passives: LxBiomePassives = null
var _dungeon_twists: LxBiomeDungeonTwists = null
var _setpieces: LxOverworldSetpieces = null
var _portals: LxPortalFx = null
var _cam_center: Vector2 = Vector2.ZERO
var _clock: float = 0.0

# Island 2: Tide Drift-Shards washed ashore by live tide cycles
var _drift_shards: Array[Dictionary] = [] # {pos, age, life}
var _last_drift_surge: bool = false

# Island 3: Cascading Canopy Bloom Waves
var _canopy_waves: Array[Dictionary] = [] # {pos, age, dur, max_r}

# Island 4: Lagoon Mist Tailwind (+22% glide speed after catching an updraft)
var tailwind_t: float = 0.0

# Island 5: Shootable Starfall Nova Crystals left by meteor impacts
var _star_crystals: Array[Dictionary] = [] # {pos, age, life}
var _nova_rings: Array[Dictionary] = [] # {pos, age, dur, max_r}

# Island 6: Molten Overdrive charges (Flare-Dashing a Magma Vent -> 3 piercing magma bolts)
var molten_charges: int = 0

# Island 7: Radiant Mirror Echo ghost position during Full Silver Moon
var mirror_echo_active: bool = false
var mirror_echo_pos: Vector2 = Vector2.ZERO

# Island 8: Shattered Eclipse Seals & Dawn Resonance counter (0..3)
var dawn_seals_broken: int = 0
var _seal_shatter_fx: Array[Dictionary] = [] # {pos, age, dur}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	active_instance = self
	_rules = rules
	_region = region_node
	_clock = 0.0
	_drift_shards.clear()
	_last_drift_surge = false
	_canopy_waves.clear()
	tailwind_t = 0.0
	_star_crystals.clear()
	_nova_rings.clear()
	molten_charges = 0
	mirror_echo_active = false
	mirror_echo_pos = Vector2.ZERO
	_seal_shatter_fx.clear()
	_sync_dawn_seals()
	if _decals == null and get_parent() != null:
		_decals = LxGroundDecals.new()
		_decals.name = "GroundDecals"
		get_parent().add_child(_decals)
	if _decals != null:
		_decals.configure(rules.island_id, region_node)
	if _weather == null and get_parent() != null:
		_weather = LxBiomeWeather.new()
		_weather.name = "BiomeWeather"
		get_parent().add_child(_weather)
	if _weather != null:
		_weather.configure(rules.island_id, rules.is_dungeon, rules.bounds.get_center())
	if _boss_synergy == null and get_parent() != null:
		_boss_synergy = LxBiomeBossSynergy.new()
		_boss_synergy.name = "BiomeBossSynergy"
		get_parent().add_child(_boss_synergy)
	if _boss_synergy != null:
		_boss_synergy.configure(rules, self, region_node)
	if _passives == null and get_parent() != null:
		_passives = LxBiomePassives.new()
		_passives.name = "BiomePassives"
		get_parent().add_child(_passives)
	if _passives != null:
		_passives.configure(rules, region_node)
	if _dungeon_twists == null and get_parent() != null:
		_dungeon_twists = LxBiomeDungeonTwists.new()
		_dungeon_twists.name = "BiomeDungeonTwists"
		get_parent().add_child(_dungeon_twists)
	if _dungeon_twists != null:
		_dungeon_twists.configure(rules, region_node)
	if _setpieces == null and get_parent() != null:
		_setpieces = LxOverworldSetpieces.new()
		_setpieces.name = "OverworldSetpieces"
		get_parent().add_child(_setpieces)
	if _setpieces != null:
		_setpieces.configure(rules, region_node)
	if _portals == null and get_parent() != null:
		_portals = LxPortalFx.new()
		_portals.name = "PortalFx"
		get_parent().add_child(_portals)
	if _portals != null:
		_portals.configure(rules, region_node)
	queue_redraw()


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0 or _rules == null or not is_instance_valid(_rules):
		return
	_clock += dt
	tailwind_t = maxf(0.0, tailwind_t - dt)
	_tick_fx_arrays(dt)
	if _decals != null and is_instance_valid(_decals):
		_decals.tick(dt, cam_center)
	if _weather != null and is_instance_valid(_weather):
		_weather.tick(dt, cam_center)
	if _boss_synergy != null and is_instance_valid(_boss_synergy):
		_boss_synergy.tick(dt)
	if _passives != null and is_instance_valid(_passives):
		_passives.tick(dt)
	if _dungeon_twists != null and is_instance_valid(_dungeon_twists):
		_dungeon_twists.tick(dt)
	if _setpieces != null and is_instance_valid(_setpieces):
		_setpieces.tick(dt, cam_center)
	if _portals != null and is_instance_valid(_portals):
		_portals.tick(dt, cam_center)
	match _rules.island_id:
		2:
			_tick_island2(dt)
		3:
			_tick_island3(dt)
		4:
			_tick_island4(dt)
		5:
			_tick_island5(dt)
		7:
			_tick_island7(dt)
		8:
			_tick_island8(dt)
	queue_redraw()


func _tick_fx_arrays(dt: float) -> void:
	for arr: Array in [_canopy_waves, _nova_rings, _seal_shatter_fx]:
		for i: int in range(arr.size() - 1, -1, -1):
			var d: Dictionary = arr[i] as Dictionary
			d["age"] = float(d["age"]) + dt
			if float(d["age"]) >= float(d["dur"]):
				arr.remove_at(i)


# --- Island 2: Tide Surge pushes foes + spawns Tide Drift-Shards + Lighthouse Beam weakpoint ---
func _tick_island2(dt: float) -> void:
	if not _rules.is_dungeon:
		if _rules.tide_surging:
			if not _last_drift_surge and _drift_shards.size() < 2:
				var spot: Vector2 = _rules._find_walkable_near_cam()
				if spot != Vector2.ZERO:
					_drift_shards.append({"pos": spot, "age": 0.0, "life": 12.0})
			_push_enemies_in_tide(dt)
		_last_drift_surge = _rules.tide_surging
		_tick_drift_shards(dt)


func _push_enemies_in_tide(dt: float) -> void:
	if _region == null or not _region.has_method("get_enemies") or not _region.has_method("tile_at"):
		return
	var enemies_v: Variant = _region.call("get_enemies")
	if not (enemies_v is Array):
		return
	for e_v: Variant in (enemies_v as Array):
		if e_v is LxEnemyBrain and is_instance_valid(e_v):
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if e.is_alive() and not e.is_boss and str(_region.call("tile_at", e.pos)) == "tide":
				e.knock += Vector2(68.0 * dt, 0.0)


func _tick_drift_shards(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for i: int in range(_drift_shards.size() - 1, -1, -1):
		var ds: Dictionary = _drift_shards[i]
		ds["age"] = float(ds["age"]) + dt
		var p: Vector2 = ds["pos"] as Vector2
		if w != null and not w.dead and w.global_position.distance_to(p) <= 18.0:
			if Lx.state != null:
				Lx.state.shards += 5
			if Lx.events != null:
				Lx.events.shard_collected.emit(5)
			w.spawn_ring(p, 2.0, 14.0, 0.22, LxWick.PAL_ICE, 1.2)
			w.emit_sfx("shard_pickup", p, true)
			_drift_shards.remove_at(i)
		elif float(ds["age"]) >= float(ds["life"]):
			_drift_shards.remove_at(i)


func is_in_lighthouse_beam(world_pos: Vector2) -> bool:
	if _rules == null or _rules.island_id != 2 or not _rules.is_dungeon:
		return false
	var bdir: Vector2 = Vector2.from_angle(_rules.beam_angle)
	var bend: Vector2 = _rules.beam_origin + bdir * 210.0
	return Geometry2D.get_closest_point_to_segment(world_pos, _rules.beam_origin, bend).distance_to(world_pos) <= 22.0


# --- Island 3: Cascading Forest Bloom-Lamp Canopy Wave + Dark-Foe Stun ---
func on_bloom_ignited(origin: Vector2, allow_chain: bool = true) -> void:
	_canopy_waves.append({"pos": origin, "age": 0.0, "dur": 0.45, "max_r": 110.0})
	if _decals != null and is_instance_valid(_decals):
		_decals.add_decal(LxGroundDecals.Kind.BLOSSOM, origin, 16.0, 7.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(origin, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.35, 0.36)
	if allow_chain and _rules != null:
		for b: Dictionary in _rules._blooms:
			var bp: Vector2 = b["pos"] as Vector2
			if bp.distance_to(origin) > 8.0 and bp.distance_to(origin) <= 112.0 and float(b["lit_t"]) < 10.0:
				b["lit_t"] = 16.0
				_canopy_waves.append({"pos": bp, "age": 0.0, "dur": 0.38, "max_r": 72.0})
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and not e.is_boss and e.pos.distance_to(origin) <= 108.0:
						var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
						e.knock += kdir * 82.0
						e.flash_t = maxf(e.flash_t, 0.35)


func _tick_island3(_dt: float) -> void:
	pass


# --- Island 4: Lagoon Mist Tailwind ---
func on_updraft_caught(pos: Vector2) -> void:
	tailwind_t = 2.2
	if _passives != null and is_instance_valid(_passives):
		_passives.on_updraft_gust(pos)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_sparks(pos, Vector2.UP, 4, LxWick.PAL_SKY, 24.0, 62.0, 0.24)


func get_glide_speed_mult() -> float:
	return 1.22 if tailwind_t > 0.0 else 1.0


func _tick_island4(_dt: float) -> void:
	if tailwind_t > 0.0 and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.is_gliding():
			tailwind_t = minf(tailwind_t, 0.15)


# --- Island 5: Shootable Starfall Nova Crystals ---
func spawn_star_crystal(at: Vector2) -> void:
	if _star_crystals.size() >= 3:
		_star_crystals.pop_front()
	_star_crystals.append({"pos": at, "age": 0.0, "life": 5.5})


func _tick_island5(dt: float) -> void:
	for i: int in range(_star_crystals.size() - 1, -1, -1):
		_star_crystals[i]["age"] = float(_star_crystals[i]["age"]) + dt
		if float(_star_crystals[i]["age"]) >= float(_star_crystals[i]["life"]):
			_star_crystals.remove_at(i)


func try_hit_biome_target(from_p: Vector2, to_p: Vector2, dir: Vector2, wick: LxWick) -> bool:
	if _rules == null or not is_instance_valid(_rules):
		return false
	# Island 3: Shooting near a Forest Bloom-Lamp (overworld OR Briar Matron boss arena!) triggers a Canopy Wave
	if _rules.island_id == 3 and _rules.is_dungeon and _boss_synergy != null and is_instance_valid(_boss_synergy):
		_boss_synergy.try_hit_boss_bloom(from_p, to_p)
	if _rules.island_id == 3 and not _rules.is_dungeon:
		for b: Dictionary in _rules._blooms:
			var bp: Vector2 = b["pos"] as Vector2
			if Geometry2D.get_closest_point_to_segment(bp, from_p, to_p).distance_to(bp) <= 13.0:
				var was_unlit: bool = float(b["lit_t"]) < 12.0
				b["lit_t"] = 16.0
				if was_unlit:
					on_bloom_ignited(bp, true)
					if Lx.audio != null:
						Lx.audio.play_sfx("prop_chime", bp, true)
				return false # Bolt passes cleanly through the Bloom-Lamp!
	# Island 5: Shooting a Starfall Crystal detonates a golden Astral Nova!
	if _rules.island_id == 5:
		for i: int in range(_star_crystals.size() - 1, -1, -1):
			var cp: Vector2 = _star_crystals[i]["pos"] as Vector2
			if Geometry2D.get_closest_point_to_segment(cp, from_p, to_p).distance_to(cp) <= 13.0:
				_star_crystals.remove_at(i)
				_detonate_astral_nova(cp, dir, wick)
				return true
	return false


func _detonate_astral_nova(at: Vector2, dir: Vector2, wick: LxWick) -> void:
	_nova_rings.append({"pos": at, "age": 0.0, "dur": 0.42, "max_r": 78.0})
	if _decals != null and is_instance_valid(_decals):
		_decals.add_decal(LxGroundDecals.Kind.PRISM_STAR, at, 18.0, 7.5)
	if Lx.audio != null:
		Lx.audio.play_sfx("prism_chain", at, true)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.16)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at, 88.0, 0.95 if LxHudFx.flash_reduced() else 1.48, 0.34)
	if wick != null and is_instance_valid(wick):
		wick.spawn_sparks(at, -dir, 10, LxWick.PAL_GOLD, 42.0, 118.0, 0.24)
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and e.pos.distance_to(at) <= 78.0:
						var kdir: Vector2 = (e.pos - at).normalized() if e.pos.distance_to(at) > 1.0 else Vector2.RIGHT
						var hit: LxHit = LxHit.make(LxHit.SOURCE_PRISM, 1.5, kdir, at, 0.5, true, false, wick, false)
						if wick != null:
							wick.apply_hit_to_entity(e, hit)


# --- Island 6: Molten Overdrive ---
func grant_molten_overdrive(charges: int = 3) -> void:
	molten_charges = maxi(molten_charges, charges)


func consume_molten_charge() -> bool:
	if molten_charges <= 0:
		return false
	molten_charges -= 1
	return true


# --- Island 7: Radiant Mirror Echo (Full Silver Moon Twin-Bolt) ---
func _tick_island7(_dt: float) -> void:
	mirror_echo_active = false
	if _rules.lunar_phase <= 0.65:
		return
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead:
			var aim: Vector2 = w.facing.normalized() if w.facing.length_squared() > 0.001 else Vector2.RIGHT
			var perp := Vector2(-aim.y, aim.x)
			mirror_echo_pos = w.global_position + perp * 12.0 + Vector2(0.0, sin(_clock * 4.5) * 1.5)
			mirror_echo_active = true


# --- Island 8: Shattering Sky Eclipse Seals & Dawn Resonance ---
func _sync_dawn_seals() -> void:
	dawn_seals_broken = 0
	if Lx.state != null:
		for bid: String in ["beacon_8_1", "beacon_8_2", "beacon_8_3"]:
			if Lx.state.lit_beacons.has(bid):
				dawn_seals_broken += 1


func _tick_island8(_dt: float) -> void:
	var prev: int = dawn_seals_broken
	_sync_dawn_seals()
	if dawn_seals_broken > prev:
		var spot: Vector2 = _cam_center + Vector2(0.0, -54.0)
		_seal_shatter_fx.append({"pos": spot, "age": 0.0, "dur": 0.72})
		if Lx.audio != null:
			Lx.audio.play_sfx("bell_toll", spot, false)


func get_fire_rate_mult() -> float:
	if _rules == null:
		return 1.0
	var mult: float = 1.0
	if _rules.starlight_surge_t > 0.0:
		mult *= 0.82
	if _rules.island_id == 8 and dawn_seals_broken > 0:
		mult *= clampf(1.0 - float(dawn_seals_broken) * 0.08, 0.72, 1.0)
	return mult


func add_permanent_updraft(at: Vector2) -> void:
	if _rules == null:
		return
	_rules._updrafts.append({"pos": at, "r": 20.0, "cd": 0.0})


func spawn_drift_shards_near(origin: Vector2, count: int = 2) -> void:
	for k: int in range(count):
		if _drift_shards.size() >= 4:
			break
		var ang: float = float(k) * PI + 0.65
		var cand: Vector2 = (origin + Vector2(cos(ang) * 28.0, sin(ang) * 20.0)).round()
		_drift_shards.append({"pos": cand, "age": 0.0, "life": 16.0})


func _draw_beacon_ley_lines(col_a: Color, col_b: Color, show_next_guide: bool) -> void:
	if _rules == null or _rules.is_dungeon or _region == null or not _region.has_method("get_interactables"):
		return
	var items_v: Variant = _region.call("get_interactables")
	if not (items_v is Array):
		return
	var lit_pts: Array[Vector2] = []
	var unlit_pts: Array[Vector2] = []
	for it: Variant in (items_v as Array):
		if it is LxBeacon and is_instance_valid(it):
			var b: LxBeacon = it as LxBeacon
			if b.active:
				if b.lit:
					lit_pts.append(b.pos + Vector2(0.0, -12.0))
				else:
					unlit_pts.append(b.pos + Vector2(0.0, -12.0))
	if lit_pts.is_empty():
		return
	var a_line: float = 0.24 if LxHudFx.flash_reduced() else (0.34 + 0.12 * sin(_clock * 2.4))
	for i: int in range(lit_pts.size()):
		for j: int in range(i + 1, lit_pts.size()):
			draw_line(lit_pts[i], lit_pts[j], Color(col_a, a_line), 1.4)
			var u: float = fposmod(_clock * 0.35 + float(i + j) * 0.23, 1.0)
			var mp: Vector2 = lit_pts[i].lerp(lit_pts[j], u).round()
			if _on_screen(mp):
				draw_rect(Rect2(mp - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_b, a_line * 1.8))
	if show_next_guide and not unlit_pts.is_empty():
		var src: Vector2 = lit_pts[lit_pts.size() - 1]
		var dst: Vector2 = unlit_pts[0]
		var u2: float = fposmod(_clock * 0.55, 1.0)
		var gp: Vector2 = src.lerp(dst, u2).round()
		if _on_screen(gp):
			draw_rect(Rect2(gp - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_b, 0.78))
			draw_line(src.lerp(dst, maxf(0.0, u2 - 0.08)), gp, Color(col_a, 0.45), 1.0)


func _draw() -> void:
	if _rules == null or not is_instance_valid(_rules):
		return
	var fred: bool = LxHudFx.flash_reduced()
	match _rules.island_id:
		2:
			_draw_island2(fred)
		3:
			_draw_canopy_waves(fred)
		4:
			_draw_tailwind_ribbons(fred)
		5:
			_draw_beacon_ley_lines(PAL["sky"] as Color, PAL["gold"] as Color, true)
			_draw_star_crystals(fred)
		6:
			_draw_molten_orbit(fred)
		7:
			_draw_beacon_ley_lines(PAL["sky"] as Color, PAL["ice"] as Color, false)
			_draw_mirror_echo(fred)
		8:
			_draw_eclipse_seals(fred)


func _draw_island2(fred: bool) -> void:
	for ds: Dictionary in _drift_shards:
		var p: Vector2 = (ds["pos"] as Vector2).round()
		if not _on_screen(p):
			continue
		var bob: float = roundf(sin(_clock * 4.2 + p.x) * 1.5)
		var pt := Vector2(p.x, p.y + bob)
		draw_circle(pt, 4.5, PAL["deep"] as Color)
		draw_rect(Rect2(pt + Vector2(-2.0, -3.0), Vector2(4.0, 6.0)), PAL["sky"] as Color)
		draw_rect(Rect2(pt + Vector2(-1.0, -2.0), Vector2(2.0, 4.0)), PAL["ice"] as Color)
		draw_rect(Rect2(pt + Vector2(-1.0, -1.0), Vector2(1.0, 1.0)), PAL["cream"] as Color)
		if not fred:
			draw_arc(pt, 6.0 + sin(_clock * 5.0) * 1.0, 0.0, TAU, 12, Color(PAL["gold"] as Color, 0.55), 1.0)
			var sr: float = fmod(_clock * 0.75 + p.x * 0.01, 1.0)
			draw_arc(pt, roundf(lerpf(6.0, 18.0, sr)), 0.0, TAU, 16, Color(PAL["ice"] as Color, (1.0 - sr) * 0.52), 1.0)
	if _rules.is_dungeon and _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v):
					var e: LxEnemyBrain = e_v as LxEnemyBrain
					if e.is_alive() and is_in_lighthouse_beam(e.pos):
						var ep: Vector2 = e.pos.round()
						draw_arc(ep, 12.0, 0.0, TAU, 16, PAL["gold"] as Color, 1.4)
						draw_arc(ep, 9.0, _clock * 3.0, _clock * 3.0 + PI, 10, PAL["cream"] as Color, 1.0)


func _draw_canopy_waves(fred: bool) -> void:
	for cw: Dictionary in _canopy_waves:
		var u: float = clampf(float(cw["age"]) / maxf(float(cw["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(8.0, float(cw["max_r"]), u))
		var a: float = (1.0 - u) * (0.55 if fred else 0.85)
		var p: Vector2 = (cw["pos"] as Vector2).round()
		draw_arc(p, r, 0.0, TAU, 24, Color(PAL["lime"] as Color, a), 1.8)
		draw_arc(p, r * 0.82, 0.0, TAU, 20, Color(PAL["gold"] as Color, a * 0.85), 1.0)


func _draw_tailwind_ribbons(_fred: bool) -> void:
	if tailwind_t <= 0.0 or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	var p: Vector2 = w.global_position.round()
	for k: int in range(3):
		var a: float = _clock * 7.0 + float(k) * (TAU / 3.0)
		var rp: Vector2 = (p + Vector2(cos(a) * 10.0, sin(a) * 6.0)).round()
		draw_rect(Rect2(rp, Vector2(2.0, 1.0)), (PAL["cream"] if k == 0 else PAL["ice"]) as Color)


func _draw_star_crystals(fred: bool) -> void:
	for sc: Dictionary in _star_crystals:
		var p: Vector2 = (sc["pos"] as Vector2).round()
		if not _on_screen(p):
			continue
		var bob: float = roundf(sin(_clock * 5.0 + p.x) * 2.0)
		var pt := Vector2(p.x, p.y - 3.0 + bob)
		draw_circle(p + Vector2(0.0, 3.0), 4.0, PAL["void"] as Color)
		draw_colored_polygon(PackedVector2Array([
			pt + Vector2(0.0, -6.0), pt + Vector2(5.0, 0.0), pt + Vector2(0.0, 6.0), pt + Vector2(-5.0, 0.0)
		]), PAL["gold"] as Color)
		draw_colored_polygon(PackedVector2Array([
			pt + Vector2(0.0, -3.5), pt + Vector2(2.5, 0.0), pt + Vector2(0.0, 3.5), pt + Vector2(-2.5, 0.0)
		]), PAL["cream"] as Color)
		var pulse_r: float = roundf(9.0 + (0.0 if fred else sin(_clock * 6.0) * 2.0))
		draw_arc(pt, pulse_r, 0.0, TAU, 16, Color(PAL["ice"] as Color, 0.72), 1.0)
	for nr: Dictionary in _nova_rings:
		var u: float = clampf(float(nr["age"]) / maxf(float(nr["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(6.0, float(nr["max_r"]), u))
		var a: float = (1.0 - u) * (0.6 if fred else 0.92)
		var p: Vector2 = (nr["pos"] as Vector2).round()
		draw_arc(p, r, 0.0, TAU, 24, Color(PAL["gold"] as Color, a), 2.0)
		draw_arc(p, r * 0.72, 0.0, TAU, 20, Color(PAL["cream"] as Color, a), 1.2)


func _draw_molten_orbit(_fred: bool) -> void:
	if molten_charges <= 0 or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var p: Vector2 = (Lx.player as LxWick).global_position.round()
	for k: int in range(molten_charges):
		var a: float = _clock * 5.2 + float(k) * (TAU / float(maxi(1, molten_charges)))
		var op: Vector2 = (p + Vector2(cos(a) * 11.0, sin(a) * 8.0 - 4.0)).round()
		draw_circle(op, 2.5, PAL["coral"] as Color)
		draw_rect(Rect2(op - Vector2.ONE, Vector2(2.0, 2.0)), PAL["gold"] as Color)
		draw_rect(Rect2(op, Vector2.ONE), PAL["cream"] as Color)


func _draw_mirror_echo(fred: bool) -> void:
	if not mirror_echo_active:
		return
	var ep: Vector2 = mirror_echo_pos.round()
	var a: float = 0.52 if fred else (0.56 + 0.16 * sin(_clock * 5.5))
	draw_circle(ep + Vector2(0.0, 4.0), 4.5, Color(PAL["deep"] as Color, a * 0.65))
	draw_rect(Rect2(ep + Vector2(-3.0, -6.0), Vector2(6.0, 9.0)), Color(PAL["sky"] as Color, a))
	draw_rect(Rect2(ep + Vector2(-2.0, -7.0), Vector2(4.0, 4.0)), Color(PAL["ice"] as Color, a * 1.15))
	draw_rect(Rect2(ep + Vector2(-1.0, -5.0), Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, a * 1.25))
	draw_arc(ep + Vector2(0.0, -2.0), 7.0, 0.0, TAU, 14, Color(PAL["ice"] as Color, a * 0.7), 1.0)


func _draw_eclipse_seals(fred: bool) -> void:
	if not _rules.is_dungeon:
		var base: Vector2 = (_cam_center + Vector2(0.0, -72.0)).round()
		for k: int in range(3):
			var sp := Vector2(base.x + float(k - 1) * 18.0, base.y)
			var broken: bool = k < dawn_seals_broken
			if broken:
				draw_circle(sp, 3.5, Color(PAL["gold"] as Color, 0.72))
				draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
			else:
				draw_circle(sp, 4.5, Color(PAL["void"] as Color, 0.85))
				draw_arc(sp, 4.5, 0.0, TAU, 12, PAL["plum"] as Color, 1.2)
				draw_arc(sp, 4.5, -0.6, 0.8, 8, PAL["rose"] as Color, 1.0)
	for sf: Dictionary in _seal_shatter_fx:
		var u: float = clampf(float(sf["age"]) / maxf(float(sf["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(6.0, 56.0, u))
		var a: float = (1.0 - u) * (0.6 if fred else 0.92)
		var p: Vector2 = (sf["pos"] as Vector2).round()
		draw_arc(p, r, 0.0, TAU, 24, Color(PAL["gold"] as Color, a), 2.0)
		draw_arc(p, r * 0.65, 0.0, TAU, 18, Color(PAL["cream"] as Color, a), 1.2)


func _on_screen(p: Vector2) -> bool:
	return absf(p.x - _cam_center.x) <= HALF_W and absf(p.y - _cam_center.y) <= HALF_H
