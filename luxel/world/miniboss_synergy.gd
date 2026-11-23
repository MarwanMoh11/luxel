class_name LxMinibossSynergy
extends RefCounted
## Interactive flanking Biome Resonance Crests inside all 8 Mini-Boss Arenas
## (belfry_r5, lighthouse_r6, oak_r6, conservatory_r6, orrery_r6, kiln_r6, spire_r6, sanctum_r4).
## Teaches and rewards each island's signature live mechanic mid-fight (strictly 20 Last Light colours).

const PAL: Dictionary = LxPalette.PAL

var _rules: LxBiomeRules = null
var _mech: LxBiomeMechanics = null
var _region: Node = null
var _island_id: int = 1
var _center: Vector2 = Vector2.ZERO
var _anchors: Array[Dictionary] = [] # {pos, cd, flash_t}


func configure(rules: LxBiomeRules, mech: LxBiomeMechanics, region_node: Node, center: Vector2) -> void:
	_rules = rules
	_mech = mech
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_center = center.round()
	_anchors.clear()
	if rules == null:
		return
	var safe: Rect2 = rules.bounds.grow(-34.0)
	var span_x: float = minf(76.0, maxf(44.0, safe.size.x * 0.28))
	for sx: float in [-span_x, span_x]:
		var pt := Vector2(
			clampf(center.x + sx, safe.position.x, safe.end.x),
			clampf(center.y + 18.0, safe.position.y, safe.end.y)
		).round()
		_anchors.append({"pos": pt, "cd": 0.0, "flash_t": 0.0})


func tick(dt: float, live: bool) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var act: bool = w != null and not w.dead and (w.is_dashing() or w.is_gliding() or w.is_zipping())
	var lp: Vector2 = w.lantern.pos if (w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out()) else Vector2(-9999.0, -9999.0)
	for anc: Dictionary in _anchors:
		anc["cd"] = maxf(0.0, float(anc["cd"]) - dt)
		anc["flash_t"] = maxf(0.0, float(anc["flash_t"]) - dt)
		if float(anc["cd"]) > 0.0:
			continue
		var ap: Vector2 = anc["pos"] as Vector2
		if (act and w.global_position.distance_to(ap) <= 22.0) or lp.distance_to(ap) <= 20.0:
			_activate(anc, w)


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick, _live: bool) -> bool:
	for anc: Dictionary in _anchors:
		if float(anc["cd"]) > 0.0:
			continue
		var ap: Vector2 = anc["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(ap, from_p, to_p).distance_to(ap) <= 15.0:
			_activate(anc, w)
			return true
	return false


func _activate(anc: Dictionary, w: LxWick) -> void:
	var ap: Vector2 = anc["pos"] as Vector2
	anc["cd"] = 6.5
	anc["flash_t"] = 0.52
	var glow_c: Color = LxBiomePalette.col(_island_id, "glow")
	var sfx_id: String = "prop_chime"
	var decal_k: int = LxGroundDecals.Kind.PRISM_STAR
	var burst_r: float = 86.0
	match _island_id:
		1: # Bell Warden: golden acoustic chime nudges nearby adds & feeds Ember
			sfx_id = "prop_chime"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			_push_non_boss_adds(ap, 92.0, 56.0)
			if w != null and is_instance_valid(w) and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 5.0)
		2: # Tide Captain: Harbor Fresnel Prism charges 2.6s Fresnel Focus!
			sfx_id = "lighthouse_toll"
			decal_k = LxGroundDecals.Kind.RIPPLE
			if _rules != null:
				_rules.beam_buff_t = maxf(_rules.beam_buff_t, 2.6)
		3: # Elder Sporecap: Heartwood Sap-Bud cascades emerald canopy wave!
			sfx_id = "spore_pop"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			if _mech != null and is_instance_valid(_mech):
				_mech.on_bloom_ignited(ap, false)
		4: # Great Lily Hopper: Mist Well refreshes Wings + grants 2.4s Rose Tailwind!
			sfx_id = "wing_gale"
			decal_k = LxGroundDecals.Kind.RIPPLE
			if _mech != null and is_instance_valid(_mech):
				_mech.tailwind_t = maxf(_mech.tailwind_t, 2.4)
			if w != null and is_instance_valid(w) and w.is_gliding() and w.move_wings != null:
				w.move_wings.glide_time_left = w.move_wings.glide_duration
				w.move_wings.glide_dist_left = w.move_wings.glide_max_px
		5: # Clockwork Warden: Brass Escapement Node triggers 2.8s Starlight Surge!
			sfx_id = "clockwork_chime"
			decal_k = LxGroundDecals.Kind.PRISM_STAR
			if _rules != null:
				_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 2.8)
		6: # Forge Warden: Smelter Bellows Vent grants +2 Molten Overdrive charges!
			sfx_id = "forge_gust"
			decal_k = LxGroundDecals.Kind.SCORCH
			if _mech != null and is_instance_valid(_mech):
				_mech.grant_molten_overdrive(2)
		7: # Moon Spire Trial: Silver Lunar Mirror snaps Full Silver Moon (Mirror Echo!)
			sfx_id = "lens_reveal"
			decal_k = LxGroundDecals.Kind.PRISM_STAR
			burst_r = 98.0
			if _rules != null:
				_rules.lunar_phase = 1.0
				_rules.clock = 0.0
		8: # Night Harbinger: Golden Dawn Seal feeds +10 Ember & cuts the eclipse!
			sfx_id = "bell_toll"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			burst_r = 108.0
			if w != null and is_instance_valid(w) and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 10.0)
	if w != null and is_instance_valid(w):
		w.spawn_ring(ap, 4.0, 26.0, 0.28, glow_c, 1.5)
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, ap, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(ap, burst_r, 0.82 if LxHudFx.flash_reduced() else 1.24, 0.42)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(decal_k, ap, 14.0, 5.5)


func _push_non_boss_adds(origin: Vector2, rad: float, force: float) -> void:
	if _region == null or not _region.has_method("get_enemies"):
		return
	var ev: Variant = _region.call("get_enemies")
	if not (ev is Array):
		return
	for e_v: Variant in (ev as Array):
		if e_v is LxEnemyBrain and is_instance_valid(e_v):
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if e.is_alive() and not e.is_boss and e.pos.distance_to(origin) <= rad:
				var d: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
				e.knock += d * force


func draw_anchors(canvas: CanvasItem, clock: float, fred: bool, cleared: bool) -> void:
	var c_mid: Color = LxBiomePalette.col(_island_id, "mid")
	var c_hi: Color = LxBiomePalette.col(_island_id, "hi")
	var c_gl: Color = LxBiomePalette.col(_island_id, "glow")
	var cream: Color = PAL["cream"] as Color
	if cleared and _center != Vector2.ZERO:
		var r_v: float = roundf(20.0 + (0.0 if fred else sin(clock * 1.8) * 2.0))
		canvas.draw_arc(_center, r_v, 0.0, TAU, 20, Color(PAL["gold"] as Color, 0.28), 1.0)
		canvas.draw_arc(_center, r_v - 4.0, clock * 0.5, clock * 0.5 + PI * 1.2, 14, Color(c_gl, 0.34), 1.0)
		LxHudFx.draw_biome_crest(canvas, _island_id, _center, Color(c_gl, 0.72), Color(cream, 0.80))
	for anc: Dictionary in _anchors:
		var ap: Vector2 = (anc["pos"] as Vector2).round()
		var rdy: bool = cleared or float(anc["cd"]) <= 0.0
		var ft: float = float(anc["flash_t"])
		var pulse: float = 0.0 if fred else sin(clock * 3.0 + ap.x * 0.02)
		canvas.draw_circle(ap, 5.5 if rdy else 3.5, Color(c_mid if rdy else (PAL["night"] as Color), 0.56))
		canvas.draw_arc(ap, roundf((8.0 + pulse * 0.8) if rdy else 5.0), 0.0, TAU, 14, (PAL["gold"] as Color) if cleared else (c_gl if rdy else c_mid), 1.2)
		if rdy:
			LxHudFx.draw_biome_crest(canvas, _island_id, ap, c_hi, cream)
		if ft > 0.0:
			var u: float = 1.0 - clampf(ft / 0.52, 0.0, 1.0)
			canvas.draw_arc(ap, roundf(lerpf(8.0, 42.0, u)), 0.0, TAU, 18, Color(c_gl, (1.0 - u) * (0.58 if fred else 0.86)), 1.5)
			canvas.draw_arc(ap, roundf(lerpf(5.0, 28.0, u)), 0.0, TAU, 14, Color(cream, (1.0 - u) * 0.72), 1.0)
