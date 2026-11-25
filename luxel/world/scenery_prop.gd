class_name LxSceneryProp
extends Node2D
## Renders hand-crafted Last Light scenic props and landmarks from a region's "scenery" array.

const PAL: Dictionary = LxInteractable.PAL

const GLOW_PROPS: Dictionary = {
	"candelabra_tall": Vector2(44.0, 0.72),
	"stone_lantern_garden": Vector2(40.0, 0.68),
	"bridge_balustrade": Vector2(34.0, 0.55),
	"coastal_lantern_post": Vector2(42.0, 0.68),
	"fresnel_pedestal": Vector2(46.0, 0.75),
	"buoy_bobbing": Vector2(34.0, 0.58),
	"hanging_spore_lantern": Vector2(42.0, 0.68),
	"spore_brazier_stump": Vector2(44.0, 0.72),
	"giant_glowshroom_cluster": Vector2(36.0, 0.52),
	"floating_lantern_lily": Vector2(40.0, 0.68),
	"heron_lantern_post": Vector2(42.0, 0.68),
	"stained_floor_pool": Vector2(36.0, 0.50),
	"starlight_lantern_post": Vector2(44.0, 0.70),
	"observatory_brazier_stand": Vector2(48.0, 0.76),
	"armillary_sphere": Vector2(38.0, 0.55),
	"astro_floor_compass": Vector2(40.0, 0.56),
	"celestial_globe": Vector2(40.0, 0.58),
	"reflecting_star_basin": Vector2(40.0, 0.56),
	"slag_crucible": Vector2(54.0, 0.82),
	"hearth_brazier_tall": Vector2(48.0, 0.76),
	"ember_grate_vent": Vector2(42.0, 0.66),
	"cooled_magma_vent": Vector2(36.0, 0.56),
	"crucible_floor_seal": Vector2(40.0, 0.60),
	"smelter_chimney": Vector2(46.0, 0.68),
	"lunar_lantern_post": Vector2(42.0, 0.68),
	"silver_brazier_stand": Vector2(46.0, 0.74),
	"floating_prism_totem": Vector2(44.0, 0.70),
	"moon_crystal_cluster": Vector2(36.0, 0.54),
	"moon_dial_floor": Vector2(44.0, 0.60),
	"tide_mirror_basin": Vector2(40.0, 0.58),
	"crystal_archway": Vector2(42.0, 0.58),
	"dark_candelabra": Vector2(46.0, 0.74),
	"eclipse_brazier": Vector2(50.0, 0.78),
	"void_lantern_post": Vector2(42.0, 0.68),
	"remix_kiln_crucible": Vector2(52.0, 0.80),
	"eclipse_floor_seal": Vector2(40.0, 0.55),
	"shattered_rose_window": Vector2(44.0, 0.58),
	# E0-7 Epic theme light props (islands 1-8 + hub + caves)
	"archive_lantern_sconce": Vector2(42.0, 0.68),
	"briar_lantern_post": Vector2(42.0, 0.68),
	"thorn_hedge_brazier": Vector2(46.0, 0.74),
	"cave_lantern_post": Vector2(42.0, 0.68),
	"cavern_brazier_bowl": Vector2(46.0, 0.74),
	"glow_mineral_vein": Vector2(36.0, 0.54),
	"spot_lantern_rig": Vector2(48.0, 0.76),
	"carriage_wall_lamp": Vector2(42.0, 0.68),
	"iron_stove_brazier": Vector2(48.0, 0.76),
	"train_window_slag": Vector2(40.0, 0.60),
	"train_window_sunset": Vector2(40.0, 0.60),
	"cinder_brazier_cage": Vector2(46.0, 0.74),
	"roof_signal_lantern": Vector2(42.0, 0.68),
	"stair_lantern_candelabra": Vector2(46.0, 0.74),
	"bellows_hearth_stand": Vector2(48.0, 0.76),
	"ember_brazier_pillar": Vector2(48.0, 0.76),
	"molten_slag_crucible": Vector2(54.0, 0.82),
	"slag_chimney_vent": Vector2(46.0, 0.68),
	"tempering_floor_seal": Vector2(40.0, 0.60),
	"drifting_star_lantern": Vector2(44.0, 0.70),
	"star_chime_crystal": Vector2(36.0, 0.56),
	"brass_porthole_lamp": Vector2(40.0, 0.66),
	"hanging_ship_lantern": Vector2(44.0, 0.70),
	"hedgerow_lamp_urn": Vector2(40.0, 0.66),
	"lily_pond_lantern": Vector2(40.0, 0.68),
	"paper_lantern_post": Vector2(42.0, 0.68),
	"shaft_lantern_cage": Vector2(44.0, 0.70),
	"amber_lantern_post": Vector2(42.0, 0.68),
	"brass_sundial_pedestal": Vector2(38.0, 0.56),
	"hourglass_floor_dial": Vector2(40.0, 0.58),
	"black_candelabra": Vector2(44.0, 0.70),
	"dark_reflection_pool": Vector2(38.0, 0.54),
	"eclipse_brazier_bowl": Vector2(48.0, 0.76),
	"crystal_chandelier_arch": Vector2(48.0, 0.74),
	"lunar_brazier_bowl": Vector2(46.0, 0.74),
	"moon_glass_urn": Vector2(38.0, 0.58),
	"reflection_floor_pool": Vector2(40.0, 0.58),
	"silver_candelabra": Vector2(46.0, 0.74),
	"colossus_lantern_post": Vector2(44.0, 0.70),
	"furnace_vent_grate": Vector2(42.0, 0.66),
	"molten_crucible_vat": Vector2(54.0, 0.82),
	"acid_vent_sac": Vector2(38.0, 0.58),
	"whale_lantern_jar": Vector2(44.0, 0.70),
	"lock_lantern_post": Vector2(42.0, 0.68),
	"loom_lantern_brazier": Vector2(46.0, 0.74),
	"brass_lamp_sconce": Vector2(40.0, 0.66),
	"hearth_fireplace": Vector2(52.0, 0.80),
	"manor_candelabra": Vector2(46.0, 0.74),
	"crystal_candelabra": Vector2(46.0, 0.74),
	"moon_lantern_urn": Vector2(42.0, 0.68),
	"gravity_floor_seal": Vector2(40.0, 0.58),
	"meteor_crystal_cluster": Vector2(38.0, 0.56),
	"vault_lantern_brazier": Vector2(46.0, 0.74),
	"brass_star_globe": Vector2(40.0, 0.58),
	"floating_prism_lens": Vector2(42.0, 0.64),
	"planetarium_lantern": Vector2(44.0, 0.70),
	"zodiac_floor_dial": Vector2(42.0, 0.58),
	"rain_lantern_post": Vector2(42.0, 0.68),
	"storm_brazier_bowl": Vector2(46.0, 0.74),
	"pearl_lantern_post": Vector2(42.0, 0.68),
	"sea_anemone_glow": Vector2(36.0, 0.56),
	"toll_clerk_lantern": Vector2(42.0, 0.68),
	"ant_lantern_post": Vector2(42.0, 0.68),
	"glow_spore_cluster": Vector2(38.0, 0.58),
	"bell_floor_seal": Vector2(40.0, 0.58),
	"crypt_candelabra": Vector2(46.0, 0.74),
	"toll_brazier": Vector2(48.0, 0.76),
	"cozy_stone_hearth": Vector2(52.0, 0.80),
	"moth_lantern_tree": Vector2(48.0, 0.76),
	"pane_stained_easel": Vector2(38.0, 0.56),
	"warm_porch_lantern": Vector2(44.0, 0.70),
}

const SWAY_PROPS: Dictionary = {
	"river_reeds": true, "flower_bed_cool": true, "flower_bed_warm": true,
	"hanging_chimes": true, "weeping_willow": true, "belfry_bell_hanging": true,
	"buoy_bobbing": true, "harbor_wind_vane": true, "tide_bell_post": true,
	"fern_cluster": true, "tiny_shrooms": true, "hanging_spore_lantern": true,
	"spider_silk_banner": true, "canopy_vine_post": true, "giant_glowshroom_cluster": true,
	"cattail_reeds": true, "blooming_lotus": true, "floating_lantern_lily": true, "marsh_willow": true,
	"giant_lotus_pad": true, "mossy_planter_urn": true,
	"hanging_pendulum": true, "armillary_sphere": true, "celestial_globe": true, "brass_orrery_stand": true,
	"foundry_hook_crane": true, "slag_crucible": true, "ember_grate_vent": true, "hearth_brazier_tall": true,
	"silver_willow_pale": true, "floating_prism_totem": true, "moon_crystal_cluster": true, "shattered_mirror_shard": true,
	"tattered_sanctum_banner": true, "floating_cathedral_shard": true, "eclipse_brazier": true, "remix_kiln_crucible": true,
}

const MAX_FLAKES: int = 6

static var _global_sway_sfx_ms: int = 0

var sheet_name: String = ""
var prop_key: String = ""
var layer_name: String = "sort"
var flip_x: bool = false
var cast_shadow: bool = true
var animated: bool = false
var light_pool: Vector4 = Vector4.ZERO

var _sheet: LxSpriteSheet = null
var _clock: float = 0.0
var _valid: bool = false
var _frame_size: Vector2 = Vector2.ZERO
var _shadow_poly: PackedVector2Array = PackedVector2Array()
var _ms_arr: Array = []
var _frame_count: int = 0
var _loop: bool = true
var _last_frame: int = -1
var _can_occlude: bool = false
var _occlude_a: float = 1.0
var _can_sway: bool = false
var _is_resonant: bool = false
var _is_foliage: bool = false
var _sway_t: float = 0.0
var _sway_cd: float = 0.0
var _sway_dir: float = 1.0
var _sway_amp: float = 1.2
var _sway_px: float = 0.0
var _sfx_cd: float = 0.0
var _is_glow: bool = false
var _flare_t: float = 0.0
var _flare_cd: float = 0.0
var _flare_dir: float = 1.0
var _graze_cd: float = 0.0
var _ring_t: float = 0.0
var _ring_dur: float = 0.36
var _ring_c1: Color = PAL["gold"] as Color
var _ring_c2: Color = PAL["cream"] as Color
var _flakes: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(_can_occlude or _can_sway or _is_glow)


func setup(spec: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet_name = str(spec.get("sheet", "")).strip_edges()
	prop_key = str(spec.get("prop", "")).strip_edges()
	layer_name = str(spec.get("layer", "sort")).strip_edges().to_lower()
	flip_x = bool(spec.get("flip_x", false))
	cast_shadow = bool(spec.get("shadow", true))
	_clock = maxf(0.0, float(spec.get("phase", 0.0)))
	position = LxMapFormat.to_vec2(spec.get("pos", Vector2.ZERO)).round()
	if not prop_key.is_empty():
		name = prop_key
	if GLOW_PROPS.has(prop_key):
		var g: Vector2 = GLOW_PROPS[prop_key] as Vector2
		var isl_g: int = Lx.state.island_id if Lx.state != null else 1
		var relit_mul: float = 1.14 if (Lx.state != null and Lx.state.relit_islands.has(isl_g)) else 1.0
		light_pool = Vector4(position.x, position.y - 10.0, g.x * relit_mul, g.y)
		_is_glow = true
	else:
		light_pool = Vector4.ZERO
		_is_glow = false
	_flare_t = 0.0

	_sheet = null
	_valid = false
	animated = false
	_frame_size = Vector2.ZERO
	_shadow_poly = PackedVector2Array()

	var path: String = ""
	if not sheet_name.is_empty() and not prop_key.is_empty():
		path = sheet_name if sheet_name.begins_with("res://") else (
			"res://luxel/art/props/%s" % sheet_name if sheet_name.ends_with(".json")
			else "res://luxel/art/props/%s.json" % sheet_name
		)
		_sheet = LxSpriteSheet.load_sheet(path)
	if _sheet != null and _sheet.props.has(prop_key):
		var pinfo_var: Variant = _sheet.props.get(prop_key, null)
		var rects_var: Variant = (pinfo_var as Dictionary).get("rects", null) if pinfo_var is Dictionary else null
		if rects_var is Array and not (rects_var as Array).is_empty():
			var pinfo: Dictionary = pinfo_var as Dictionary
			var rects: Array = rects_var as Array
			_valid = true
			_frame_count = rects.size()
			animated = _frame_count > 1
			var ms_v: Variant = pinfo.get("ms", [])
			_ms_arr = ms_v as Array if ms_v is Array else []
			_loop = bool(pinfo.get("loop", true))
			_last_frame = LxSpriteSheet._pick_frame(_frame_count, _ms_arr, _clock, _loop) if animated else 0
			var first: Variant = rects[0]
			if first is Array and (first as Array).size() >= 4:
				_frame_size = Vector2(float((first as Array)[2]), float((first as Array)[3]))
			if layer_name == "sort" and cast_shadow:
				_shadow_poly = _build_shadow_ellipse(_frame_size)
			_can_occlude = layer_name == "sort" and _frame_size.y >= 26.0 and _frame_size.x >= 16.0
			_can_sway = SWAY_PROPS.has(prop_key)
			_is_resonant = _match_resonant(prop_key)
			_is_foliage = (not _is_resonant) and (_can_sway or _match_foliage(prop_key))
			_sway_t = 0.0
			_sway_cd = 0.0
			_sway_px = 0.0
			_graze_cd = 0.0
			_ring_t = 0.0
			_flakes.clear()
			_occlude_a = 1.0
			modulate.a = 1.0
			set_process(_can_occlude or _can_sway or _is_glow)
	queue_redraw()


func _process(dt: float) -> void:
	var has_p: bool = Lx.player != null and is_instance_valid(Lx.player) and (Lx.player is Node2D)
	if _graze_cd > 0.0:
		_graze_cd = maxf(0.0, _graze_cd - dt)
	if _sfx_cd > 0.0:
		_sfx_cd = maxf(0.0, _sfx_cd - dt)
	if _can_occlude and has_p:
		var pp: Vector2 = (Lx.player as Node2D).global_position
		var behind: bool = pp.y < position.y - 2.0 and pp.y > position.y - _frame_size.y - 2.0 and absf(pp.x - position.x) < _frame_size.x * 0.46
		var target_a: float = 0.48 if behind else 1.0
		if not is_equal_approx(_occlude_a, target_a):
			_occlude_a = move_toward(_occlude_a, target_a, dt * 4.5)
			modulate.a = _occlude_a
	if _can_sway or _sway_t > 0.0:
		if _sway_cd > 0.0:
			_sway_cd = maxf(0.0, _sway_cd - dt)
		if _can_sway and has_p and _sway_cd <= 0.0:
			var pp2: Vector2 = (Lx.player as Node2D).global_position
			var d2: float = pp2.distance_squared_to(position)
			if d2 < 324.0:
				var vel_v: Variant = Lx.player.get("velocity")
				var vel: Vector2 = vel_v as Vector2 if vel_v is Vector2 else Vector2.ZERO
				if vel.length_squared() > 400.0:
					_sway_t = 0.36
					_sway_cd = 0.24
					_sway_dir = -1.0 if (pp2.x > position.x) else 1.0
					if absf(vel.x) > 25.0:
						_sway_dir = signf(vel.x)
					_sway_amp = 2.0 if vel.length_squared() > 14400.0 else 1.2
					_play_sway_sfx()
			else:
				var lan_v: Variant = Lx.player.get("lantern")
				if lan_v is Object and is_instance_valid(lan_v as Object) and bool((lan_v as Object).call("is_out")):
					var lpos: Vector2 = (lan_v as Object).get("pos") as Vector2
					var lvel: Vector2 = (lan_v as Object).get("vel") as Vector2
					if lvel.length_squared() > 400.0 and lpos.distance_squared_to(position) < 484.0:
						_sway_t = 0.36
						_sway_cd = 0.24
						_sway_dir = signf(lvel.x) if absf(lvel.x) > 25.0 else (-1.0 if (lpos.x > position.x) else 1.0)
						_sway_amp = 2.0
						_play_sway_sfx()
		if _sway_t > 0.0:
			_sway_t = maxf(0.0, _sway_t - dt)
			var next_px: float = roundf(sin(_sway_t * 24.0) * _sway_amp * (_sway_t / 0.36) * _sway_dir) if _sway_t > 0.0 else 0.0
			if not is_equal_approx(next_px, _sway_px):
				_sway_px = next_px
				queue_redraw()
	if _is_glow:
		if _flare_cd > 0.0:
			_flare_cd = maxf(0.0, _flare_cd - dt)
		if _flare_t > 0.0:
			_flare_t = maxf(0.0, _flare_t - dt)
			queue_redraw()
		elif has_p and _flare_cd <= 0.0:
			var pp3: Vector2 = (Lx.player as Node2D).global_position
			if pp3.distance_squared_to(position) < 484.0:
				var vel_g: Variant = Lx.player.get("velocity")
				if vel_g is Vector2 and (vel_g as Vector2).length_squared() > 2500.0:
					_flare_t = 0.38 if (vel_g as Vector2).length_squared() > 6400.0 else 0.28
					_flare_cd = 0.55
					_flare_dir = signf((vel_g as Vector2).x) if absf((vel_g as Vector2).x) > 10.0 else 1.0
					queue_redraw()
	var fx_dirty: bool = false
	if _ring_t > 0.0:
		_ring_t = maxf(0.0, _ring_t - dt)
		fx_dirty = true
	if not _flakes.is_empty():
		for fi: int in range(_flakes.size() - 1, -1, -1):
			var fl: Dictionary = _flakes[fi]
			var fage: float = float(fl["age"]) + dt
			if fage >= float(fl["life"]):
				_flakes.remove_at(fi)
			else:
				fl["age"] = fage
				var fv: Vector2 = fl["vel"] as Vector2
				fv.y += 74.0 * dt
				fv.x *= pow(0.35, dt)
				fl["vel"] = fv
				fl["pos"] = (fl["pos"] as Vector2) + fv * dt
		fx_dirty = true
	if fx_dirty:
		queue_redraw()
	if not _can_occlude and not _can_sway and not _is_glow and _sway_t <= 0.0 and _ring_t <= 0.0 and _flakes.is_empty() and _flare_t <= 0.0 and _graze_cd <= 0.0:
		set_process(false)


func is_animated() -> bool:
	return animated


func gust_sway(origin: Vector2, radius: float, strength: float) -> void:
	if (not _can_sway and not _is_glow) or radius <= 1.0:
		return
	var diff: Vector2 = position - origin
	var d2: float = diff.length_squared()
	if d2 >= radius * radius:
		return
	var falloff: float = 1.0 - sqrt(d2) / radius
	if _is_glow:
		_flare_dir = 1.0 if diff.x >= 0.0 else -1.0
		_flare_t = maxf(_flare_t, 0.32 + 0.16 * falloff)
		set_process(true)
		queue_redraw()
	if not _can_sway:
		return
	_sway_dir = 1.0 if diff.x >= 0.0 else -1.0
	_sway_amp = maxf(_sway_amp if _sway_t > 0.0 else 0.0, clampf(1.1 + (strength / 52.0) * falloff * 2.1, 1.1, 3.0))
	_sway_t = maxf(_sway_t, 0.36 + 0.14 * falloff)
	if falloff > 0.35 and (prop_key.contains("chime") or prop_key.contains("bell") or prop_key.contains("prism") or prop_key.contains("pendulum")):
		_play_sway_sfx()
	set_process(true)


func on_bolt_graze(hit_pos: Vector2, bolt_dir: Vector2, is_blue: bool) -> void:
	if not _valid or _graze_cd > 0.0:
		return
	if not _is_resonant and not _is_foliage and not _can_sway and not _is_glow:
		return
	_graze_cd = 0.10
	var dn: Vector2 = bolt_dir.normalized() if bolt_dir.length_squared() > 0.0001 else Vector2.RIGHT
	var side_dir: float = signf(dn.x) if absf(dn.x) > 0.15 else (1.0 if hit_pos.x < position.x else -1.0)
	if _is_resonant:
		_sway_dir = side_dir
		_sway_amp = 2.4
		_sway_t = maxf(_sway_t, 0.42)
		_sway_cd = 0.18
		_play_sway_sfx()
		_ring_dur = 0.36
		_ring_t = _ring_dur
		var is_crys: bool = prop_key.contains("prism") or prop_key.contains("crystal") or prop_key.contains("mirror") or prop_key.contains("shard")
		_ring_c1 = (PAL["ice"] if is_crys else PAL["gold"]) as Color
		_ring_c2 = (PAL["sky"] if is_crys else PAL["cream"]) as Color
		if is_crys and not LxHudFx.flash_reduced() and LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(position, 34.0, 0.78, 0.18)
	if _is_foliage or (_can_sway and not _is_resonant):
		_sway_dir = side_dir
		_sway_amp = maxf(_sway_amp if _sway_t > 0.0 else 0.0, 2.2)
		_sway_t = maxf(_sway_t, 0.38)
		_sway_cd = 0.18
		_play_sway_sfx()
		_spawn_graze_flakes(dn, is_blue)
	if _is_glow:
		_flare_t = maxf(_flare_t, 0.42)
		_flare_cd = 0.25
		_flare_dir = side_dir
		if not LxHudFx.flash_reduced() and LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(position + Vector2(0.0, -10.0), 42.0, 0.75, 0.20)
	set_process(true)
	queue_redraw()


static func graze_segment(world_ctx: Node, p0: Vector2, p1: Vector2, dir: Vector2, is_blue: bool) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var props_v: Variant = world_ctx.get("_scenery_props")
	if not (props_v is Array):
		return
	for pv: Variant in (props_v as Array):
		if not (pv is LxSceneryProp) or not is_instance_valid(pv as Object):
			continue
		var sp: LxSceneryProp = pv as LxSceneryProp
		if not sp._valid:
			continue
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(sp.position, p0, p1)
		if cp.distance_squared_to(sp.position) <= 169.0:
			sp.on_bolt_graze(cp, dir, is_blue)


func _spawn_graze_flakes(dn: Vector2, is_blue: bool) -> void:
	var cnt: int = randi_range(3, 5)
	var base_y: float = -minf(18.0, _frame_size.y * 0.52)
	for _i: int in range(cnt):
		if _flakes.size() >= MAX_FLAKES:
			_flakes.pop_front()
		var fp := Vector2(randf_range(-4.0, 4.0), base_y + randf_range(-3.0, 3.0))
		var fv: Vector2 = dn * randf_range(16.0, 32.0) + Vector2(randf_range(-10.0, 10.0), randf_range(-28.0, -13.0))
		_flakes.append({
			"pos": fp, "vel": fv, "age": 0.0, "life": randf_range(0.40, 0.58),
			"col": _flake_color(is_blue), "phase": randf_range(0.0, 2.0),
		})


func _flake_color(is_blue: bool) -> Color:
	if prop_key.contains("crucible") or prop_key.contains("vent") or prop_key.contains("hearth") or prop_key.contains("brazier") or prop_key.contains("ember") or prop_key.contains("kiln"):
		return (PAL["coral"] if randf() < 0.52 else PAL["apricot"]) as Color
	if prop_key.contains("silver") or prop_key.contains("crystal") or prop_key.contains("prism") or prop_key.contains("mirror") or prop_key.contains("lunar") or is_blue:
		return (PAL["ice"] if randf() < 0.55 else PAL["sky"]) as Color
	if prop_key.contains("flower") or prop_key.contains("lotus") or prop_key.contains("banner") or prop_key.contains("cathedral") or prop_key.contains("sanctum"):
		return (PAL["rose"] if randf() < 0.60 else PAL["gold"]) as Color
	return (PAL["lime"] if randf() < 0.55 else PAL["jade"]) as Color


static func _match_resonant(k: String) -> bool:
	return k.contains("bell") or k.contains("chime") or k.contains("prism") or k.contains("crystal") or k.contains("mirror") or k.contains("shard") or k.contains("armillary") or k.contains("orrery") or k.contains("globe") or k.contains("pendulum")


static func _match_foliage(k: String) -> bool:
	return k.contains("reed") or k.contains("flower") or k.contains("willow") or k.contains("fern") or k.contains("shroom") or k.contains("spore") or k.contains("banner") or k.contains("vine") or k.contains("lotus") or k.contains("moss") or k.contains("urn")


func tick(dt: float) -> void:
	if not animated:
		return
	_clock += dt
	var f: int = LxSpriteSheet._pick_frame(_frame_count, _ms_arr, _clock, _loop)
	if f != _last_frame:
		_last_frame = f
		queue_redraw()


func _draw() -> void:
	if not _valid or _sheet == null:
		return
	if _shadow_poly.size() >= 3:
		draw_colored_polygon(_shadow_poly, Color(PAL["void"] as Color, 0.32))
	var draw_off := Vector2(_sway_px, 0.0)
	if flip_x:
		draw_set_transform(draw_off, 0.0, Vector2(-1.0, 1.0))
		_sheet.draw_prop(self, Vector2.ZERO, prop_key, _clock)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_sheet.draw_prop(self, draw_off, prop_key, _clock)
	if _sway_t > 0.0:
		var u: float = clampf(1.0 - _sway_t / 0.36, 0.0, 1.0)
		var mc: Color = _sway_mote_color()
		var mh: float = minf(18.0, _frame_size.y * 0.55)
		var cnt: int = 4 if _sway_amp >= 1.9 else 2
		for mi: int in range(cnt):
			var mx: float = roundf(_sway_dir * (2.5 + u * (5.5 + float(mi) * 2.4)) + float((mi % 2) * 2 - 1) * (2.0 + float(mi) * 0.6))
			var my: float = roundf(-mh - u * (5.0 + float(mi) * 2.0) + sin(u * PI * 2.0 + float(mi)) * 1.5)
			draw_rect(Rect2(mx, my, 1.0, 1.0), Color(mc, (1.0 - u) * 0.90))
	if _flare_t > 0.0:
		var fu: float = clampf(1.0 - _flare_t / 0.44, 0.0, 1.0)
		var isl_f: int = Lx.state.island_id if Lx.state != null else 1
		var fc: Color = PAL["cream"] as Color if fu < 0.32 else LxBiomePalette.col(isl_f, "glow")
		var fh: float = minf(22.0, _frame_size.y * 0.68)
		for fi: int in range(3):
			var fx: float = roundf(_flare_dir * (1.5 + fu * (4.0 + float(fi) * 2.2)) + float(fi - 1) * 2.5)
			var fy: float = roundf(-fh - fu * (6.0 + float(fi) * 2.5))
			draw_rect(Rect2(fx, fy, 1.0, 1.0), Color(fc, (1.0 - fu) * 0.88))
	if _ring_t > 0.0:
		var ru: float = clampf(1.0 - _ring_t / maxf(_ring_dur, 0.01), 0.0, 1.0)
		var rx: float = lerpf(3.0, 15.0, ru)
		var ry: float = rx * 0.65
		var cy: float = -minf(15.0, _frame_size.y * 0.48)
		var fr_r: float = 0.72 if LxHudFx.flash_reduced() else 1.0
		var ra: float = (1.0 - ru) * 0.92 * fr_r
		for k: int in range(8):
			var ang: float = float(k) * (TAU / 8.0) + ru * 0.35
			var rp := Vector2(roundf(cos(ang) * rx), roundf(cy + sin(ang) * ry))
			var rc: Color = _ring_c2 if (ru < 0.35 or k % 2 == 0) else _ring_c1
			draw_rect(Rect2(rp, Vector2(1.0, 1.0)), Color(rc, ra))
	for fl: Dictionary in _flakes:
		var flu: float = clampf(float(fl["age"]) / maxf(float(fl["life"]), 0.01), 0.0, 1.0)
		var tall: bool = int(floorf((float(fl["age"]) + float(fl["phase"])) * 9.0)) % 2 == 1
		var sz := Vector2(1.0, 2.0) if tall else Vector2(2.0, 1.0)
		draw_rect(Rect2((fl["pos"] as Vector2).round(), sz), Color(fl["col"] as Color, (1.0 - flu) * 0.92))


func _play_sway_sfx() -> void:
	if _sfx_cd > 0.0 or Lx.audio == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _global_sway_sfx_ms < 220:
		return
	_global_sway_sfx_ms = now_ms
	var sfx_id: String = "prop_rustle"
	if prop_key.contains("armillary") or prop_key.contains("orrery") or prop_key.contains("globe") or prop_key.contains("pendulum"):
		sfx_id = "clockwork_chime"
	elif prop_key.contains("shroom") or prop_key.contains("spore"):
		sfx_id = "spore_pop"
	elif prop_key.contains("crucible") or prop_key.contains("vent") or prop_key.contains("hearth") or prop_key.contains("brazier"):
		sfx_id = "forge_gust"
	elif prop_key.contains("buoy") or prop_key.contains("vane") or prop_key.contains("crane"):
		sfx_id = "harbor_creak"
	elif prop_key.contains("chime") or prop_key.contains("bell") or prop_key.contains("prism") or prop_key.contains("crystal") or prop_key.contains("mirror") or prop_key.contains("shard"):
		sfx_id = "prop_chime"
	_sfx_cd = 0.72 if sfx_id != "prop_rustle" else 0.56
	Lx.audio.play_sfx(sfx_id, global_position, true)


func _sway_mote_color() -> Color:
	if prop_key.contains("crucible") or prop_key.contains("vent") or prop_key.contains("hearth") or prop_key.contains("brazier"):
		return PAL["coral"] as Color
	if prop_key.contains("flower") or prop_key.contains("lotus"):
		return PAL["rose"] as Color
	if prop_key.contains("chime") or prop_key.contains("bell") or prop_key.contains("lantern") or prop_key.contains("pendulum") or prop_key.contains("armillary") or prop_key.contains("orrery") or prop_key.contains("globe"):
		return PAL["gold"] as Color
	if prop_key.contains("prism") or prop_key.contains("silver") or prop_key.contains("crystal") or prop_key.contains("mirror"):
		return PAL["ice"] as Color
	if prop_key.contains("cathedral") or prop_key.contains("sanctum"):
		return PAL["rose"] as Color
	return PAL["lime"] as Color


static func _build_shadow_ellipse(frame_sz: Vector2) -> PackedVector2Array:
	var rx: float = clampf(frame_sz.x * 0.34, 4.0, 26.0)
	var ry: float = clampf(frame_sz.x * 0.12, 2.0, 8.0)
	var pts := PackedVector2Array()
	pts.resize(12)
	for i: int in range(12):
		var a: float = (TAU * float(i)) / 12.0
		var sx: float = cos(a) * rx + sin(a) * ry * 0.35 + 2.0
		var sy: float = sin(a) * ry + 1.0
		pts[i] = Vector2(roundf(sx), roundf(sy))
	return pts


static func spawn_from_specs(specs: Array, ground_root: Node2D, sort_root: Node2D, over_root: Node2D) -> Array[LxSceneryProp]:
	var out: Array[LxSceneryProp] = []
	for raw: Variant in specs:
		if not (raw is Dictionary):
			continue
		var prop := LxSceneryProp.new()
		prop.setup(raw as Dictionary)
		var target: Node2D = ground_root if prop.layer_name == "ground" else (over_root if (prop.layer_name == "overhead" or prop.layer_name == "over") else sort_root)
		if target == null:
			target = sort_root if sort_root != null else (ground_root if ground_root != null else over_root)
		if target != null:
			target.add_child(prop)
			prop._flush_initial_draw()
		out.append(prop)
	return out


func _flush_initial_draw() -> void:
	if not _valid or _sheet == null or _sheet.tex == null:
		return
	var pinfo_v: Variant = _sheet.props.get(prop_key, null)
	if not (pinfo_v is Dictionary):
		return
	var pinfo: Dictionary = pinfo_v as Dictionary
	var rects_v: Variant = pinfo.get("rects", null)
	if not (rects_v is Array) or (rects_v as Array).is_empty():
		return
	var rects: Array = rects_v as Array
	var idx: int = clampi(_last_frame, 0, rects.size() - 1)
	var src_rect: Rect2 = LxSpriteSheet._to_rect2(rects[idx])
	if src_rect.size.x <= 0.0 or src_rect.size.y <= 0.0:
		return
	var anchor: Vector2 = LxSpriteSheet._to_vec2(pinfo.get("anchor", null), _sheet.default_anchor)
	var ci: RID = get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if _shadow_poly.size() >= 3:
		RenderingServer.canvas_item_add_polygon(ci, _shadow_poly, PackedColorArray([Color(PAL["void"] as Color, 0.32)]))
	if flip_x:
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2.ZERO))
	RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2((-anchor).round(), src_rect.size), _sheet.tex.get_rid(), src_rect)
	if flip_x:
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
