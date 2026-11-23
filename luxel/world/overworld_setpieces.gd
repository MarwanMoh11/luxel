class_name LxOverworldSetpieces
extends Node2D
## Monumental, progress-reactive living architectural setpieces unique to each of the 8 overworlds.
## Renders beneath actors (z_index = -4) using strictly the 20 opaque Last Light palette colours.
##
## - Island 1 (Bell Isle): Belfry golden chime waves + Plaza lantern garlands & beacon filaments
## - Island 2 (Tidewater Harbor): Sweeping Overworld Lighthouse Fresnel Searchlight beam
## - Island 3 (Thornwood Hollow): Living bioluminescent Heartwood root-veins feeding the Hollow Oak
## - Island 4 (Mirefen Gardens): Conservatory stained-glass prism rays & gliding luminous lagoon koi
## - Island 5 (Starfall Observatory): Colossal counter-rotating brass Orrery rings & planetoids
## - Island 6 (Ashen Kiln): Breathing caldera magma fissures pulsing in sync with vent_cycle
## - Island 7 (Moon Shoals): Giant reflected Silver Moon in the lagoon synced with lunar_phase
## - Island 8 (The Long Night): Monumental Fractured Eclipse Corona cracking into golden Dawn

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
var _beacons: Array[Node] = []
var _koi: Array[Dictionary] = []
var _wildlife: LxOverworldWildlife = null
var _chimes: LxBellChimes = null
var _discoveries: LxBiomeDiscoveries = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -4


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	_rules = rules
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_active = rules != null and not rules.is_dungeon
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_door_pos = _default_anchor(_island_id)
	_beacons.clear()
	_koi.clear()
	if _active and _region != null and _region.has_method("get_interactables"):
		var items_v: Variant = _region.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if it is LxBeacon and is_instance_valid(it):
					_beacons.append(it as Node)
				elif it is LxInteractable and is_instance_valid(it):
					var obj: LxInteractable = it as LxInteractable
					if obj.id.begins_with("door_dungeon_") or obj.id == "door_ward_barrier":
						_door_pos = obj.pos
	if _active and _island_id == 4:
		var pools: Array[Vector2] = [
			Vector2(416.0, 312.0), Vector2(800.0, 312.0),
			Vector2(432.0, 568.0), Vector2(784.0, 568.0),
			Vector2(608.0, 412.0), Vector2(608.0, 624.0),
		]
		var rng := RandomNumberGenerator.new()
		rng.seed = 40471
		for k: int in range(pools.size()):
			_koi.append({
				"center": pools[k],
				"rx": rng.randf_range(18.0, 32.0),
				"ry": rng.randf_range(12.0, 22.0),
				"spd": rng.randf_range(0.36, 0.62) * (1.0 if k % 2 == 0 else -1.0),
				"phase": rng.randf_range(0.0, TAU),
				"col": "coral" if k % 3 == 0 else ("gold" if k % 3 == 1 else "ice"),
			})
	if _wildlife == null and get_parent() != null:
		_wildlife = LxOverworldWildlife.new()
		_wildlife.name = "OverworldWildlife"
		get_parent().add_child(_wildlife)
	if _wildlife != null:
		_wildlife.configure(rules, region_node)
	if _chimes == null and get_parent() != null:
		_chimes = LxBellChimes.new()
		_chimes.name = "BellChimes"
		get_parent().add_child(_chimes)
	if _chimes != null:
		_chimes.configure(rules, region_node)
	if _discoveries == null and get_parent() != null:
		_discoveries = LxBiomeDiscoveries.new()
		_discoveries.name = "BiomeDiscoveries"
		get_parent().add_child(_discoveries)
	if _discoveries != null:
		_discoveries.configure(rules, region_node, _door_pos)
	queue_redraw()


static func _default_anchor(isl: int) -> Vector2:
	match isl:
		1:
			return Vector2(640.0, 232.0)
		2:
			return Vector2(1536.0, 168.0)
		3:
			return Vector2(352.0, 120.0)
		4:
			return Vector2(608.0, 248.0)
		5:
			return Vector2(544.0, 488.0)
		6:
			return Vector2(1312.0, 168.0)
		7:
			return Vector2(672.0, 184.0)
		_:
			return Vector2(336.0, 168.0)


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if _wildlife != null and is_instance_valid(_wildlife):
		_wildlife.tick(dt, cam_center)
	if _chimes != null and is_instance_valid(_chimes):
		_chimes.tick(dt, cam_center)
	if _discoveries != null and is_instance_valid(_discoveries):
		_discoveries.tick(dt, cam_center)
	if not _active or dt <= 0.0:
		return
	_clock += dt
	queue_redraw()


func _is_relit() -> bool:
	return Lx.state != null and Lx.state.relit_islands.has(_island_id)


func _in_view(p: Vector2, pad: float = 0.0) -> bool:
	return absf(p.x - _cam_center.x) <= (HALF_W + pad) and absf(p.y - _cam_center.y) <= (HALF_H + pad)


func _draw() -> void:
	if not _active or _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	var relit: bool = _is_relit()
	match _island_id:
		1:
			_draw_bell_isle(fred, relit)
		2:
			_draw_tidewater_lighthouse(fred, relit)
		3:
			_draw_thornwood_roots(fred, relit)
		4:
			_draw_mirefen_prism_koi(fred, relit)
		5:
			_draw_starfall_orrery(fred, relit)
		6:
			_draw_ashen_fissures(fred, relit)
		7:
			_draw_moon_shoals_reflection(fred, relit)
		8:
			_draw_long_night_eclipse(fred, relit)


func _draw_bell_isle(fred: bool, relit: bool) -> void:
	# Golden Belfry chime wave radiating softly from the Belfry Gate
	if _in_view(_door_pos, 110.0):
		var cyc: float = fposmod(_clock * 0.28, 1.0)
		var r: float = roundf(lerpf(18.0, 108.0, cyc))
		var a: float = (1.0 - cyc) * (0.20 if fred else (0.38 if relit else 0.26))
		draw_arc(_door_pos.round(), r, 0.0, TAU, 28, Color(PAL["gold"] as Color, a), 1.2)
	# Warm lantern-garland arc spanning Plaza waystone -> Rest Shrine
	var p_a := Vector2(536.0, 392.0)
	var p_b := Vector2(640.0, 396.0)
	if _in_view((p_a + p_b) * 0.5, 80.0):
		var prev: Vector2 = p_a
		for s: int in range(1, 9):
			var u: float = float(s) / 8.0
			var sag: float = sin(u * PI) * 14.0
			var pt: Vector2 = p_a.lerp(p_b, u) + Vector2(0.0, sag)
			draw_line(prev.round(), pt.round(), Color(PAL["mauve"] as Color, 0.35), 1.0)
			if s < 8:
				var gl_c: Color = (PAL["cream"] if (relit or (s % 2 == 0)) else PAL["gold"]) as Color
				draw_rect(Rect2(pt.round() - Vector2.ONE, Vector2(2.0, 2.0)), Color(gl_c, 0.72))
			prev = pt
	# Living Sundial Plaza golden dial hand & beacon-progress radiance (640, 396)
	var dial_c := Vector2(640.0, 396.0)
	if _in_view(dial_c, 64.0):
		var lit_n: int = 0
		for bn: Node in _beacons:
			if bn is LxBeacon and is_instance_valid(bn) and (bn as LxBeacon).lit:
				lit_n += 1
		var dial_a: float = (0.24 if fred else 0.42) if (relit or lit_n > 0) else 0.22
		var hand_ang: float = -PI * 0.5 + (TAU * float(lit_n) / 3.0) + _clock * (0.25 if relit else 0.08)
		draw_arc(dial_c, 26.0, 0.0, TAU, 24, Color((PAL["gold"] if (relit or lit_n >= 3) else PAL["apricot"]) as Color, dial_a), 1.0)
		draw_line(dial_c, (dial_c + Vector2.from_angle(hand_ang) * 22.0).round(), Color(PAL["cream"] as Color, dial_a * 1.4), 1.2)
		for k: int in range(3):
			var ka: float = -PI * 0.5 + float(k) * (TAU / 3.0)
			var kp: Vector2 = (dial_c + Vector2.from_angle(ka) * 26.0).round()
			draw_rect(Rect2(kp - Vector2.ONE, Vector2(2.0, 2.0)), (PAL["cream"] if (relit or k < lit_n) else PAL["dusk"]) as Color)
	_draw_beacon_conduits(PAL["gold"] as Color, PAL["cream"] as Color, fred, relit)


func _draw_tidewater_lighthouse(fred: bool, relit: bool) -> void:
	# Grand working Overworld Lighthouse Fresnel beam sweeping slowly across the harbor!
	var origins: Array[Vector2] = [_door_pos + Vector2(0.0, -18.0), Vector2(760.0, 168.0)]
	for idx: int in range(origins.size()):
		var orig: Vector2 = origins[idx]
		if not _in_view(orig, 260.0):
			continue
		var ang: float = PI + sin(_clock * (0.34 if idx == 0 else -0.44) + float(idx) * 1.4) * 0.85
		var span: float = 250.0 if idx == 0 else 145.0
		var cone: float = 0.22 if idx == 0 else 0.16
		var p1: Vector2 = (orig + Vector2.from_angle(ang - cone) * span).round()
		var p2: Vector2 = (orig + Vector2.from_angle(ang + cone) * span).round()
		var beam_c: Color = (PAL["gold"] if relit else PAL["ice"]) as Color
		var a: float = (0.07 if fred else 0.13) if idx == 0 else (0.05 if fred else 0.09)
		draw_colored_polygon(PackedVector2Array([orig.round(), p1, p2]), Color(beam_c, a))
		var mid_end: Vector2 = (orig + Vector2.from_angle(ang) * span).round()
		draw_line(orig.round(), mid_end, Color((PAL["cream"] if relit else PAL["sky"]) as Color, a * 1.6), 1.0)


func _draw_thornwood_roots(fred: bool, relit: bool) -> void:
	# Bioluminescent Heartwood root-veins feeding northward from each Sap-Shrine to Hollow Oak
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node):
			continue
		var b: LxBeacon = b_node as LxBeacon
		var lit_b: bool = relit or b.lit
		var start: Vector2 = b.pos.round()
		var mid: Vector2 = start.lerp(target, 0.5) + Vector2(32.0 if start.x < target.x else -32.0, 18.0)
		var base_c: Color = (PAL["lime"] if lit_b else PAL["pine"]) as Color
		var base_a: float = (0.28 if fred else 0.48) if lit_b else 0.28
		var prev: Vector2 = start
		for s: int in range(1, 13):
			var u: float = float(s) / 12.0
			var q0: Vector2 = start.lerp(mid, u)
			var q1: Vector2 = mid.lerp(target, u)
			var pt: Vector2 = q0.lerp(q1, u).round()
			if _in_view(pt, 48.0) or _in_view(prev, 48.0):
				draw_line(prev, pt, Color(base_c, base_a), 2.0 if lit_b else 1.2)
			prev = pt
		# Pulsing sap-light packet traveling along each root branch
		var pu: float = fposmod(_clock * (0.48 if lit_b else 0.18) + start.x * 0.01, 1.0)
		var pp: Vector2 = start.lerp(mid, pu).lerp(mid.lerp(target, pu), pu).round()
		if _in_view(pp, 16.0):
			draw_circle(pp, 3.0 if lit_b else 2.0, Color((PAL["cream"] if lit_b else PAL["jade"]) as Color, 0.78))


func _draw_mirefen_prism_koi(fred: bool, relit: bool) -> void:
	# Stained-glass rose/gold/ice prism rays radiating from Sunken Conservatory dome
	if _in_view(_door_pos, 190.0):
		var c: Vector2 = _door_pos.round()
		var cols: Array[String] = ["rose", "gold", "ice"]
		var a: float = 0.06 if fred else (0.13 if relit else 0.09)
		for k: int in range(3):
			var ang: float = PI * 0.30 + float(k) * 0.22 + sin(_clock * 0.35 + float(k)) * 0.08
			var p1: Vector2 = (c + Vector2.from_angle(ang - 0.08) * 185.0).round()
			var p2: Vector2 = (c + Vector2.from_angle(ang + 0.08) * 185.0).round()
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(PAL[cols[k]] as Color, a))
	# Gliding luminous koi fish silhouettes beneath the lotus lagoon
	for k: Dictionary in _koi:
		var ang: float = _clock * float(k["spd"]) + float(k["phase"])
		var cen: Vector2 = k["center"] as Vector2
		var p: Vector2 = (cen + Vector2(cos(ang) * float(k["rx"]), sin(ang) * float(k["ry"]))).round()
		if not _in_view(p, 24.0):
			continue
		var tail_ang: float = ang - signf(float(k["spd"])) * 0.22
		var tp: Vector2 = (cen + Vector2(cos(tail_ang) * float(k["rx"]), sin(tail_ang) * float(k["ry"]))).round()
		var kc: Color = PAL[str(k["col"])] as Color
		draw_line(tp, p, Color(kc, 0.58), 2.0)
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, 0.70))


func _draw_starfall_orrery(fred: bool, relit: bool) -> void:
	# Colossal counter-rotating brass celestial rings around the Grand Orrery core!
	var c: Vector2 = _door_pos.round()
	var a_ring: float = 0.20 if fred else (0.42 if relit else 0.30)
	var radii: Array[float] = [148.0, 260.0, 368.0]
	var spds: Array[float] = [0.16, -0.11, 0.07]
	for idx: int in range(radii.size()):
		var rad: float = radii[idx]
		if not _in_view(c, rad + 24.0):
			continue
		var rot: float = _clock * spds[idx] + float(idx) * 1.1
		var rc: Color = (PAL["gold"] if (relit or idx != 1) else PAL["sky"]) as Color
		for seg: int in range(4):
			var a0: float = rot + float(seg) * (PI * 0.5)
			draw_arc(c, rad, a0, a0 + 0.95, 16, Color(rc, a_ring), 1.4 if idx == 0 else 1.0)
			var orb: Vector2 = (c + Vector2.from_angle(a0) * rad).round()
			if _in_view(orb, 16.0):
				draw_circle(orb, 3.0 if idx == 0 else 2.5, Color(PAL["gold"] as Color, 0.72))
				draw_rect(Rect2(orb, Vector2.ONE), PAL["cream"] as Color)
	_draw_beacon_conduits(PAL["sky"] as Color, PAL["gold"] as Color, fred, relit)


func _draw_ashen_fissures(fred: bool, relit: bool) -> void:
	# Breathing caldera magma-fissures pulsing in sync with vent_cycle!
	var pulse: float = 0.5 if fred else clampf(_rules.vent_cycle, 0.0, 1.0)
	var hot_c: Color = (PAL["gold"] if relit else (PAL["gold"] if pulse >= 0.56 else PAL["coral"])) as Color
	var dim_c: Color = (PAL["apricot"] if relit else PAL["wine"]) as Color
	var a: float = (0.28 + 0.34 * pulse) * (0.75 if fred else 1.0)
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node):
			continue
		var b: LxBeacon = b_node as LxBeacon
		var s: Vector2 = b.pos.round()
		var lit_b: bool = relit or b.lit
		var prev: Vector2 = s
		for k: int in range(1, 9):
			var u: float = float(k) / 8.0
			var zig: float = sin(float(k) * 2.3 + s.y * 0.02) * 18.0
			var pt: Vector2 = s.lerp(target, u) + Vector2(0.0, zig)
			if _in_view(pt, 48.0) or _in_view(prev, 48.0):
				draw_line(prev.round(), pt.round(), Color(hot_c if lit_b else dim_c, a), 2.0 if lit_b else 1.2)
			prev = pt


func _draw_moon_shoals_reflection(fred: bool, relit: bool) -> void:
	# Twin shimmering Reflected Moon Discs floating strictly inside the west & east open mirror-lagoon basins!
	var ph: float = 1.0 if relit else clampf(_rules.lunar_phase, 0.0, 1.0)
	var r: float = 42.0
	var a_disc: float = (0.14 + 0.24 * ph) * (0.75 if fred else 1.0)
	var disc_c: Color = (PAL["gold"] if relit else (PAL["ice"] if ph > 0.5 else PAL["sky"])) as Color
	for moon_c: Vector2 in [Vector2(476.0, 368.0), Vector2(868.0, 368.0)]:
		if not _in_view(moon_c, 84.0):
			continue
		var y_off: float = -r
		while y_off <= r:
			var half_span: float = sqrt(maxf(0.0, r * r - y_off * y_off))
			var wave: float = 0.0 if fred else sin(_clock * 2.2 + y_off * 0.25 + moon_c.x * 0.01) * 2.5
			var y_px: float = roundf(moon_c.y + y_off)
			var left_cut: float = lerpf(-half_span * 0.85, half_span * 0.35, 1.0 - ph)
			if half_span > left_cut + 2.0:
				draw_line(Vector2(roundf(moon_c.x + left_cut + wave), y_px), Vector2(roundf(moon_c.x + half_span + wave), y_px), Color(disc_c, a_disc), 2.0)
			y_off += 4.0
		draw_arc(moon_c, r + 3.0, 0.0, TAU, 28, Color((PAL["cream"] if relit else PAL["ice"]) as Color, a_disc * 1.1), 1.0)
	_draw_beacon_conduits(PAL["ice"] as Color, PAL["cream"] as Color, fred, relit)


func _draw_long_night_eclipse(fred: bool, relit: bool) -> void:
	# Monumental Fractured Eclipse Corona hovering around the northern Bell Sanctum!
	var c: Vector2 = _door_pos.round()
	var seals_b: int = LxBiomeMechanics.active_instance.dawn_seals_broken if (LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance)) else 0
	if _in_view(c, 160.0):
		var pulse: float = 0.0 if fred else sin(_clock * 2.0) * 3.0
		var r_ecl: float = roundf(74.0 + pulse)
		var ring_c: Color = (PAL["gold"] if relit else (PAL["rose"] if seals_b < 2 else PAL["gold"])) as Color
		draw_arc(c, r_ecl, 0.0, TAU, 36, Color(ring_c, 0.35 if fred else 0.56), 2.2)
		draw_arc(c, r_ecl - 5.0, 0.0, TAU, 32, Color((PAL["cream"] if relit else PAL["plum"]) as Color, 0.42), 1.2)
		var rays: int = 12 if relit else (seals_b * 3)
		for k: int in range(rays):
			var ang: float = _clock * 0.18 + float(k) * (TAU / maxf(1.0, float(rays)))
			var p0: Vector2 = (c + Vector2.from_angle(ang) * (r_ecl + 2.0)).round()
			var p1: Vector2 = (c + Vector2.from_angle(ang) * (r_ecl + (64.0 if relit else 44.0))).round()
			draw_line(p0, p1, Color(PAL["gold"] as Color, 0.32 if fred else 0.52), 1.6)
	# Golden Dawn Pilgrimage Spine leading up the vertical causeway (y: 1060 -> 210)
	var lit_ratio: float = 1.0 if relit else (float(seals_b) / 3.0)
	for step: int in range(18):
		var sy: float = 1040.0 - float(step) * 46.0
		var sp := Vector2(336.0, sy)
		if not _in_view(sp, 24.0):
			continue
		var frac: float = float(step) / 18.0
		var col: Color = (PAL["gold"] if frac <= lit_ratio + 0.12 else PAL["plum"]) as Color
		draw_rect(Rect2(sp - Vector2(2.0, 1.0), Vector2(4.0, 2.0)), Color(col, 0.55))


func _draw_beacon_conduits(col_dim: Color, col_hi: Color, fred: bool, relit: bool) -> void:
	var target: Vector2 = _door_pos.round()
	for b_node: Node in _beacons:
		if not (b_node is LxBeacon) or not is_instance_valid(b_node):
			continue
		var b: LxBeacon = b_node as LxBeacon
		if not relit and not b.lit:
			continue
		var start: Vector2 = b.pos.round()
		if not _in_view(start, 220.0) and not _in_view(target, 220.0):
			continue
		draw_line(start, target, Color(col_dim, 0.16 if fred else 0.26), 1.0)
		var u: float = fposmod(_clock * 0.36 + start.x * 0.007, 1.0)
		var pt: Vector2 = start.lerp(target, u).round()
		if _in_view(pt, 16.0):
			draw_rect(Rect2(pt - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_hi, 0.80))
