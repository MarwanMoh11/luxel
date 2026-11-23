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
var _sway_t: float = 0.0
var _sway_cd: float = 0.0
var _sway_dir: float = 1.0
var _sway_amp: float = 1.2
var _sway_px: float = 0.0
var _sfx_cd: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(_can_occlude or _can_sway)


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
		light_pool = Vector4(position.x, position.y - 10.0, g.x, g.y)
	else:
		light_pool = Vector4.ZERO

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
			_sway_t = 0.0
			_sway_cd = 0.0
			_sway_px = 0.0
			_occlude_a = 1.0
			modulate.a = 1.0
			set_process(_can_occlude or _can_sway)
	queue_redraw()


func _process(dt: float) -> void:
	var has_p: bool = Lx.player != null and is_instance_valid(Lx.player) and (Lx.player is Node2D)
	if _can_occlude and has_p:
		var pp: Vector2 = (Lx.player as Node2D).global_position
		var behind: bool = pp.y < position.y - 2.0 and pp.y > position.y - _frame_size.y - 2.0 and absf(pp.x - position.x) < _frame_size.x * 0.46
		var target_a: float = 0.48 if behind else 1.0
		if not is_equal_approx(_occlude_a, target_a):
			_occlude_a = move_toward(_occlude_a, target_a, dt * 4.5)
			modulate.a = _occlude_a
	if _can_sway:
		if _sway_cd > 0.0:
			_sway_cd = maxf(0.0, _sway_cd - dt)
		if _sfx_cd > 0.0:
			_sfx_cd = maxf(0.0, _sfx_cd - dt)
		if has_p and _sway_cd <= 0.0:
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


func is_animated() -> bool:
	return animated


func gust_sway(origin: Vector2, radius: float, strength: float) -> void:
	if not _can_sway or radius <= 1.0:
		return
	var diff: Vector2 = position - origin
	var d2: float = diff.length_squared()
	if d2 >= radius * radius:
		return
	var falloff: float = 1.0 - sqrt(d2) / radius
	_sway_dir = 1.0 if diff.x >= 0.0 else -1.0
	_sway_amp = maxf(_sway_amp if _sway_t > 0.0 else 0.0, clampf(1.1 + (strength / 52.0) * falloff * 2.1, 1.1, 3.0))
	_sway_t = maxf(_sway_t, 0.36 + 0.14 * falloff)
	if falloff > 0.35 and (prop_key.contains("chime") or prop_key.contains("bell") or prop_key.contains("prism") or prop_key.contains("pendulum")):
		_play_sway_sfx()
	set_process(true)


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
	elif prop_key.contains("chime") or prop_key.contains("bell") or prop_key.contains("prism") or prop_key.contains("crystal") or prop_key.contains("shard"):
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
		out.append(prop)
	return out
