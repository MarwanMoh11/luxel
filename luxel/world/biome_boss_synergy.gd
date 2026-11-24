class_name LxBiomeBossSynergy
extends Node2D
## Weaves every island's signature live biome mechanic directly into its Final Boss Sanctum
## (Islands 1..8) so each boss encounter feels architecturally and mechanically distinct.
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL
const BOSS_REGIONS: PackedStringArray = [
	"belfry_r7", "lighthouse_r10", "oak_r10", "conservatory_r10",
	"orrery_r10", "kiln_r10", "spire_r10", "sanctum_r6",
]
const MINIBOSS_REGIONS: PackedStringArray = [
	"belfry_r5", "lighthouse_r6", "oak_r6", "conservatory_r6",
	"orrery_r6", "kiln_r6", "spire_r6", "sanctum_r4",
]
const ABYSS_STARS_5: Array[Vector2] = [
	Vector2(-154.0, 38.0), Vector2(-136.0, 48.0), Vector2(-148.0, 62.0),
	Vector2(-126.0, 56.0), Vector2(-152.0, 78.0), Vector2(-132.0, 74.0),
]

var _rules: LxBiomeRules = null
var _mech: LxBiomeMechanics = null
var _region: Node = null
var _island_id: int = 1
var _active: bool = false
var _is_miniboss: bool = false
var _miniboss_was_live: bool = false
var _mb_clear_t: float = 0.0
var _clock: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _bell_pulse_t: float = 0.0
var _was_dashing: bool = false
var _oak_harmony_cd: float = 0.0
var _orrery_nodes: Array[Dictionary] = [] # {ang, cd}
var _fresnel_buoys: Array[Dictionary] = [] # Isl 2 Lighthouse Hermit Fresnel Buoys {pos, cd, flash_t}
var _lunar_anchors: Array[Dictionary] = [] # Isl 7 Hollow Wick Mirror Anchors {pos, cd, flash_t}
var _dawn_relics: Array[Dictionary] = []   # Isl 8 The Hush Dawn Bell Relics {pos, cd, flash_t}
var _mb_synergy: LxMinibossSynergy = LxMinibossSynergy.new()
var _boss_victory: LxBossVictoryFx = LxBossVictoryFx.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1


func configure(rules: LxBiomeRules, mech: LxBiomeMechanics, region_node: Node) -> void:
	_rules = rules
	_mech = mech
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_clock = 0.0
	_bell_pulse_t = 0.0
	_was_dashing = false
	_oak_harmony_cd = 0.0
	_orrery_nodes.clear()
	_fresnel_buoys.clear()
	_lunar_anchors.clear()
	_dawn_relics.clear()
	var rid: String = str(region_node.get("current_region_id")) if region_node != null and region_node.get("current_region_id") != null else ""
	_active = BOSS_REGIONS.has(rid)
	_is_miniboss = MINIBOSS_REGIONS.has(rid)
	_miniboss_was_live = _is_miniboss and _has_live_enemies()
	_mb_clear_t = 0.0
	_center = rules.bounds.get_center() if rules != null else Vector2(224.0, 144.0)
	if _active and _rules != null:
		_seed_boss_arena_features()
		_boss_victory.configure(_island_id, _center, _region, _has_live_enemies())
	elif _is_miniboss and _rules != null:
		_mb_synergy.configure(_rules, _mech, _region, _center)
	queue_redraw()


func _seed_boss_arena_features() -> void:
	match _island_id:
		2: # Lighthouse Hermit: Fresnel origin + 2 Fresnel Prism Buoys
			_rules.beam_origin = Vector2(_center.x, 56.0)
			for off2: Vector2 in [Vector2(-104.0, 32.0), Vector2(104.0, 32.0)]:
				_fresnel_buoys.append({"pos": _center + off2, "cd": 0.0, "flash_t": 0.0})
		3: # Briar Matron: 4 emerald canopy Bloom-Lamps
			_rules._blooms.clear()
			for off: Vector2 in [Vector2(-120.0, -56.0), Vector2(120.0, -56.0), Vector2(-120.0, 56.0), Vector2(120.0, 56.0)]:
				_rules._blooms.append({"pos": _center + off, "lit_t": 4.0})
		4: # Heron Abbess: 4 Mist Updrafts over the indoor lagoon corners
			for off: Vector2 in [Vector2(-148.0, -68.0), Vector2(148.0, -68.0), Vector2(-148.0, 68.0), Vector2(148.0, 68.0)]:
				_rules._updrafts.append({"pos": _center + off, "r": 20.0, "cd": 0.0})
		5: # The Clockmaker: 4 orbiting Brass Conjunction Nodes
			for k: int in range(4):
				_orrery_nodes.append({"ang": float(k) * (TAU / 4.0), "cd": 0.0})
		6: # The Kilnmother: 4 rhythmic caldera Magma Vents
			_rules._vents.clear()
			var offs: Array[Vector2] = [Vector2(-116.0, -54.0), Vector2(116.0, -54.0), Vector2(-116.0, 54.0), Vector2(116.0, 54.0)]
			for i: int in range(offs.size()):
				_rules._vents.append({"pos": _center + offs[i], "phase": float(i) * 0.25, "ember_cd": 0.0, "erupted": false})
		7: # Hollow Wick: 2 Silver Lunar Mirror Anchors
			for off7: Vector2 in [Vector2(-112.0, 0.0), Vector2(112.0, 0.0)]:
				_lunar_anchors.append({"pos": _center + off7, "cd": 0.0, "flash_t": 0.0})
		8: # The Hush: 3 Golden Dawn Bell Relics
			for off8: Vector2 in [Vector2(-116.0, -40.0), Vector2(88.0, -56.0), Vector2(0.0, 68.0)]:
				_dawn_relics.append({"pos": _center + off8, "cd": 0.0, "flash_t": 0.0})


func _emit_feature_fx(p: Vector2, sfx: String, lr: float, ls_lo: float, ls_hi: float, lt: float, dk: int = -1, dr: float = 0.0, dt_s: float = 0.0) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx, p, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(p, lr, ls_lo if LxHudFx.flash_reduced() else ls_hi, lt)
	if dk >= 0 and LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(dk, p, dr, dt_s)


func tick(dt: float) -> void:
	if (not _active and not _is_miniboss) or dt <= 0.0 or _rules == null:
		return
	_clock += dt
	if _is_miniboss:
		_mb_clear_t = maxf(0.0, _mb_clear_t - dt)
		var live_now: bool = _has_live_enemies()
		if _miniboss_was_live and not live_now:
			_mb_clear_t = 0.72
			_emit_feature_fx(_center, "prop_chime", 128.0, 0.85, 1.32, 0.52, LxGroundDecals.Kind.PRISM_STAR, 18.0, 9.0)
			if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
				LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, _center, 16.0, 8.0)
		_miniboss_was_live = live_now
		_mb_synergy.tick(dt, live_now)
		queue_redraw()
		return
	_bell_pulse_t = maxf(0.0, _bell_pulse_t - dt)
	_oak_harmony_cd = maxf(0.0, _oak_harmony_cd - dt)
	match _island_id:
		1: _tick_belfry_ring()
		2: _tick_fresnel_buoys(dt)
		3: _tick_oak_boss_blooms(dt)
		5: _tick_orrery_boss_nodes(dt)
		7: _tick_lunar_anchors(dt)
		8: _tick_dawn_relics(dt)
	_boss_victory.tick(dt, _has_live_enemies())
	queue_redraw()


func _tick_belfry_ring() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	var dashing: bool = w.is_dashing()
	if dashing and not _was_dashing and w.global_position.distance_to(_center) <= 78.0:
		_trigger_belfry_gong(w, 6.0)
	_was_dashing = dashing


func _trigger_belfry_gong(w: LxWick, ember_gain: float) -> void:
	_bell_pulse_t = 0.52
	if w != null and is_instance_valid(w) and w.move_sunflare != null and w.move_sunflare.unlocked:
		w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + ember_gain)
	_emit_feature_fx(_center, "prop_chime", 94.0, 0.85, 1.25, 0.36)


func _tick_fresnel_buoys(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var act: bool = w != null and not w.dead and (w.is_dashing() or w.is_zipping())
	var lp: Vector2 = w.lantern.pos if (w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out()) else Vector2(-9999.0, -9999.0)
	for buoy: Dictionary in _fresnel_buoys:
		buoy["cd"] = maxf(0.0, float(buoy["cd"]) - dt)
		buoy["flash_t"] = maxf(0.0, float(buoy["flash_t"]) - dt)
		if float(buoy["cd"]) > 0.0 or _is_boss_cleared():
			continue
		var bp: Vector2 = buoy["pos"] as Vector2
		if (act and w.global_position.distance_to(bp) <= 24.0) or lp.distance_to(bp) <= 22.0:
			_activate_fresnel_buoy(buoy, w)


func _activate_fresnel_buoy(buoy: Dictionary, w: LxWick) -> void:
	var bp: Vector2 = buoy["pos"] as Vector2
	buoy["cd"] = 6.0; buoy["flash_t"] = 0.55
	_rules.beam_buff_t = maxf(_rules.beam_buff_t, 3.0)
	if w != null and is_instance_valid(w):
		w.spawn_ring(bp, 4.0, 28.0, 0.28, LxWick.PAL_ICE, 1.5)
	_emit_feature_fx(bp, "lighthouse_toll", 94.0, 0.85, 1.28, 0.42, LxGroundDecals.Kind.RIPPLE, 15.0, 5.5)


func _tick_orrery_boss_nodes(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for nd: Dictionary in _orrery_nodes:
		nd["ang"] = wrapf(float(nd["ang"]) + dt * 0.42, -PI, PI)
		nd["cd"] = maxf(0.0, float(nd["cd"]) - dt)
		if float(nd["cd"]) > 0.0 or w == null or w.dead:
			continue
		var np: Vector2 = _center + Vector2(cos(float(nd["ang"])) * 108.0, sin(float(nd["ang"])) * 62.0)
		if w.global_position.distance_to(np) <= 18.0:
			_activate_orrery_node(nd, np, w)


func _activate_orrery_node(nd: Dictionary, np: Vector2, w: LxWick) -> void:
	nd["cd"] = 2.6
	_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 3.2)
	if w != null and is_instance_valid(w):
		w.spawn_ring(np, 3.0, 22.0, 0.24, LxWick.PAL_GOLD, 1.5)
	_emit_feature_fx(np, "clockwork_chime", 76.0, 0.85, 1.20, 0.32, LxGroundDecals.Kind.PRISM_STAR, 13.0, 5.0)


func _tick_oak_boss_blooms(dt: float) -> void:
	var ppos: Vector2 = (Lx.player as LxWick).global_position if (Lx.player is LxWick and is_instance_valid(Lx.player)) else Vector2(-9999.0, -9999.0)
	var lpos: Vector2 = Vector2(-9999.0, -9999.0)
	var p_act: bool = false
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		p_act = w.is_dashing() or w.is_beam_charging()
		if w.lantern != null and is_instance_valid(w.lantern):
			lpos = w.lantern.global_position
	var lit_n: int = 0
	for b: Dictionary in _rules._blooms:
		var lt: float = float(b["lit_t"])
		if lt > 0.0:
			b["lit_t"] = maxf(0.0, lt - dt)
		var bp: Vector2 = b["pos"] as Vector2
		if (p_act and bp.distance_squared_to(ppos) <= 1764.0) or bp.distance_squared_to(lpos) <= 1296.0:
			if lt <= 0.2:
				if Lx.audio != null:
					Lx.audio.play_sfx("prop_chime", bp, true)
				if _mech != null and is_instance_valid(_mech):
					_mech.on_bloom_ignited(bp, true)
			b["lit_t"] = 14.0
		lit_n += 1 if float(b["lit_t"]) > 0.0 else 0
	if lit_n >= 4 and _oak_harmony_cd <= 0.0 and not _is_boss_cleared():
		_oak_harmony_cd = 22.0
		if Lx.state != null and Lx.state.hearts < float(Lx.state.max_hearts):
			Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 0.5)
			if Lx.events != null:
				Lx.events.player_healed.emit(0.5)
		if Lx.audio != null:
			Lx.audio.play_sfx("prop_chime", _center, true)


func try_hit_boss_bloom(from_p: Vector2, to_p: Vector2) -> void:
	try_hit_boss_feature(from_p, to_p, Lx.player as LxWick if Lx.player is LxWick else null)


func try_hit_boss_feature(from_p: Vector2, to_p: Vector2, w: LxWick) -> void:
	if _is_miniboss and _rules != null:
		_mb_synergy.try_hit_segment(from_p, to_p, w, _has_live_enemies())
		return
	if not _active or _rules == null or _is_boss_cleared():
		return
	match _island_id:
		1:
			if _bell_pulse_t <= 0.0 and Geometry2D.get_closest_point_to_segment(_center, from_p, to_p).distance_to(_center) <= 20.0:
				_trigger_belfry_gong(w, 4.0)
				return
		2:
			for buoy: Dictionary in _fresnel_buoys:
				if float(buoy["cd"]) <= 0.0 and Geometry2D.get_closest_point_to_segment(buoy["pos"] as Vector2, from_p, to_p).distance_to(buoy["pos"] as Vector2) <= 16.0:
					_activate_fresnel_buoy(buoy, w)
					return
		3:
			for b: Dictionary in _rules._blooms:
				var bp: Vector2 = b["pos"] as Vector2
				if Geometry2D.get_closest_point_to_segment(bp, from_p, to_p).distance_to(bp) <= 14.0:
					var was_dim: bool = float(b["lit_t"]) < 10.0
					b["lit_t"] = 14.0
					if was_dim:
						if _mech != null and is_instance_valid(_mech):
							_mech.on_bloom_ignited(bp, true)
						if Lx.audio != null:
							Lx.audio.play_sfx("prop_chime", bp, true)
		5:
			for nd: Dictionary in _orrery_nodes:
				if float(nd["cd"]) > 0.0:
					continue
				var np: Vector2 = _center + Vector2(cos(float(nd["ang"])) * 108.0, sin(float(nd["ang"])) * 62.0)
				if Geometry2D.get_closest_point_to_segment(np, from_p, to_p).distance_to(np) <= 14.0:
					_activate_orrery_node(nd, np, w)
					return
		6:
			for v: Dictionary in _rules._vents:
				var vp: Vector2 = v["pos"] as Vector2
				if float(v.get("ember_cd", 0.0)) <= 0.0 and Geometry2D.get_closest_point_to_segment(vp, from_p, to_p).distance_to(vp) <= 16.0:
					v["ember_cd"] = 5.5
					if _mech != null and is_instance_valid(_mech):
						_mech.grant_molten_overdrive(1)
					if w != null and is_instance_valid(w):
						w.spawn_ring(vp, 4.0, 26.0, 0.26, LxWick.PAL_APRICOT, 1.5)
					_emit_feature_fx(vp, "forge_gust", 86.0, 0.84, 1.24, 0.38, LxGroundDecals.Kind.SCORCH, 13.0, 5.5)
					return
		7:
			for anc: Dictionary in _lunar_anchors:
				if float(anc["cd"]) <= 0.0 and Geometry2D.get_closest_point_to_segment(anc["pos"] as Vector2, from_p, to_p).distance_to(anc["pos"] as Vector2) <= 16.0:
					_activate_lunar_anchor(anc, w)
					return
		8:
			for rel: Dictionary in _dawn_relics:
				if float(rel["cd"]) <= 0.0 and Geometry2D.get_closest_point_to_segment(rel["pos"] as Vector2, from_p, to_p).distance_to(rel["pos"] as Vector2) <= 16.0:
					_activate_dawn_relic(rel, w)
					return


func _tick_lunar_anchors(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var act: bool = w != null and not w.dead and (w.is_dashing() or w.muzzle_t > 0.0 or w.is_zipping())
	for anc: Dictionary in _lunar_anchors:
		anc["cd"] = maxf(0.0, float(anc["cd"]) - dt)
		anc["flash_t"] = maxf(0.0, float(anc["flash_t"]) - dt)
		if float(anc["cd"]) <= 0.0 and act and not _is_boss_cleared() and w.global_position.distance_to(anc["pos"] as Vector2) <= 28.0:
			_activate_lunar_anchor(anc, w)


func _activate_lunar_anchor(anc: Dictionary, w: LxWick) -> void:
	var ap: Vector2 = anc["pos"] as Vector2
	anc["cd"] = 6.5; anc["flash_t"] = 0.55; _rules.lunar_phase = 1.0; _rules.clock = 0.0
	if w != null and is_instance_valid(w):
		w.spawn_ring(ap, 4.0, 28.0, 0.28, LxWick.PAL_ICE, 1.5)
	_emit_feature_fx(ap, "lens_reveal", 92.0, 0.85, 1.28, 0.42, LxGroundDecals.Kind.PRISM_STAR, 15.0, 6.0)


func _tick_dawn_relics(dt: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var act: bool = w != null and not w.dead and (w.is_dashing() or w.muzzle_t > 0.0 or w.is_zipping())
	for rel: Dictionary in _dawn_relics:
		rel["cd"] = maxf(0.0, float(rel["cd"]) - dt)
		rel["flash_t"] = maxf(0.0, float(rel["flash_t"]) - dt)
		if float(rel["cd"]) <= 0.0 and act and not _is_boss_cleared() and w.global_position.distance_to(rel["pos"] as Vector2) <= 26.0:
			_activate_dawn_relic(rel, w)


func _activate_dawn_relic(rel: Dictionary, w: LxWick) -> void:
	var rp: Vector2 = rel["pos"] as Vector2
	rel["cd"] = 7.5; rel["flash_t"] = 0.55
	if w != null and is_instance_valid(w):
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 12.0)
		w.spawn_ring(rp, 4.0, 30.0, 0.30, LxWick.PAL_GOLD, 1.6)
	_emit_feature_fx(rp, "prop_chime", 112.0, 0.88, 1.38, 0.48, LxGroundDecals.Kind.BLOSSOM, 15.0, 6.0)


func _is_boss_cleared() -> bool:
	if Lx.state == null:
		return false
	if Lx.state.relit_islands.has(_island_id):
		return true
	var boss_id: String = str(Lx.get_island_data(_island_id).get("boss", ""))
	return not boss_id.is_empty() and Lx.state.defeated_bosses.has(boss_id)


func _has_live_enemies() -> bool:
	if _region == null or not _region.has_method("get_enemies"):
		return false
	var ev: Variant = _region.call("get_enemies")
	if ev is Array:
		for e_v: Variant in (ev as Array):
			if e_v is LxEnemyBrain and is_instance_valid(e_v) and (e_v as LxEnemyBrain).is_alive():
				return true
	return false


func _draw_miniboss_arena(fred: bool) -> void:
	var c: Vector2 = _center.round()
	var live: bool = _has_live_enemies()
	var col_a: Color = LxBiomePalette.col(_island_id, "hi") if live else (PAL["gold"] as Color)
	var col_b: Color = LxBiomePalette.col(_island_id, "glow") if live else (PAL["cream"] as Color)
	var pulse: float = 0.0 if fred else sin(_clock * (2.6 if live else 1.4))
	var r_out: float = roundf((44.0 if live else 30.0) + pulse * 2.0)
	var a_ring: float = (0.34 if live else 0.42) * (0.75 if fred else 1.0)
	draw_arc(c, r_out, _clock * 0.5, _clock * 0.5 + PI * 0.85, 18, Color(col_a, a_ring), 1.4)
	draw_arc(c, r_out, _clock * 0.5 + PI, _clock * 0.5 + PI * 1.85, 18, Color(col_b, a_ring), 1.4)
	var spokes: int = 8 if _island_id == 5 else (6 if _island_id in [3, 6] else 4)
	for k: int in range(spokes):
		var ang: float = (PI * 0.25) + float(k) * (TAU / float(spokes)) + (_clock * 0.22 if live else 0.0)
		var pt: Vector2 = (c + Vector2.from_angle(ang) * (r_out + 4.0)).round()
		draw_rect(Rect2(pt - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_b if k % 2 == 0 else col_a, a_ring * 1.4))
	LxHudFx.draw_biome_crest(self, _island_id, c, Color(col_a, a_ring * 1.35), Color(PAL["cream"] as Color, a_ring * 1.2))
	_mb_synergy.draw_anchors(self, _clock, fred, not live)
	if _mb_clear_t > 0.0:
		var u_mb: float = 1.0 - clampf(_mb_clear_t / 0.72, 0.0, 1.0)
		var r_mb: float = roundf(lerpf(12.0, 96.0, u_mb))
		var a_mb: float = (1.0 - u_mb) * (0.55 if fred else 0.88)
		draw_arc(c, r_mb, 0.0, TAU, 28, Color(LxBiomePalette.col(_island_id, "glow"), a_mb), 2.0)
		draw_arc(c, roundf(r_mb * 0.72), 0.0, TAU, 22, Color(PAL["cream"] as Color, a_mb), 1.2)


func _draw() -> void:
	if _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	if _is_miniboss:
		_draw_miniboss_arena(fred)
		return
	if not _active:
		return
	var cleared: bool = _is_boss_cleared()
	var live_boss: LxEnemyBrain = null if cleared else _live_boss()
	var ph: int = live_boss.phase if live_boss != null else 1
	if not cleared:
		_draw_center_ritual_ring(fred, ph, live_boss)
		_draw_boss_phase_corners(fred, ph)
	_boss_victory.draw_celebration(self, _clock, fred, cleared)
	match _island_id:
		1:
			if not cleared:
				var a1: float = 0.22 if fred else (0.20 + 0.10 * sin(_clock * 2.4))
				draw_arc(_center.round(), 34.0, 0.0, TAU, 24, Color(PAL["apricot"] as Color, a1), 1.0)
			if _bell_pulse_t > 0.0:
				var u: float = 1.0 - clampf(_bell_pulse_t / 0.52, 0.0, 1.0)
				draw_arc(_center.round(), roundf(lerpf(18.0, 88.0, u)), 0.0, TAU, 24, Color(PAL["gold"] as Color, (1.0 - u) * (0.55 if fred else 0.85)), 1.6)
			if cleared:
				draw_arc(_center.round(), roundf(36.0 + (0.0 if fred else sin(_clock * 1.8) * 4.0)), 0.0, TAU, 24, Color(PAL["gold"] as Color, 0.35), 1.2)
				draw_line(_center + Vector2(-14.0, 0.0), _center + Vector2(14.0, 0.0), Color(PAL["cream"] as Color, 0.32), 1.0)
				draw_line(_center + Vector2(0.0, -14.0), _center + Vector2(0.0, 14.0), Color(PAL["cream"] as Color, 0.32), 1.0)
		2:
			for buoy: Dictionary in _fresnel_buoys:
				var bp2: Vector2 = (buoy["pos"] as Vector2).round()
				var rdy2: bool = float(buoy["cd"]) <= 0.0
				var ft2: float = float(buoy["flash_t"])
				draw_circle(bp2, 5.5 if (rdy2 or cleared) else 3.5, Color((PAL["sky"] if (rdy2 or cleared) else PAL["deep"]) as Color, 0.58))
				draw_arc(bp2, 8.0 if (rdy2 or cleared) else 5.0, 0.0, TAU, 14, (PAL["gold"] if cleared else (PAL["ice"] if rdy2 else PAL["blue"])) as Color, 1.2)
				if rdy2 or cleared:
					draw_rect(Rect2(bp2 - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
				if ft2 > 0.0:
					var u2: float = 1.0 - clampf(ft2 / 0.55, 0.0, 1.0)
					draw_arc(bp2, roundf(lerpf(8.0, 44.0, u2)), 0.0, TAU, 18, Color(PAL["ice"] as Color, (1.0 - u2) * 0.85), 1.4)
			if cleared:
				draw_arc(Vector2(_center.x, 56.0), roundf(22.0 + (0.0 if fred else sin(_clock * 2.0) * 3.0)), 0.0, TAU, 20, Color(PAL["gold"] as Color, 0.42), 1.4)
				draw_arc(Vector2(_center.x, 56.0), 34.0, PI * 0.18, PI * 0.82, 16, Color(PAL["ice"] as Color, 0.36), 1.2)
		3:
			var lit_c: int = 0
			for b: Dictionary in _rules._blooms:
				var bp: Vector2 = (b["pos"] as Vector2).round()
				var lit: bool = cleared or float(b["lit_t"]) > 0.0
				lit_c += 1 if lit else 0
				draw_circle(bp, 5.5 if lit else 3.5, (PAL["jade"] if lit else PAL["pine"]) as Color)
				draw_circle(bp, 2.5 if lit else 1.5, (PAL["cream"] if lit else PAL["teal"]) as Color)
				if lit:
					draw_arc(bp, roundf(12.0 + (0.0 if fred else sin(_clock * 4.0 + bp.x) * 2.0)), 0.0, TAU, 16, Color(PAL["lime"] as Color, 0.65), 1.0)
			if lit_c >= 4 and _rules._blooms.size() == 4:
				var ha: float = 0.24 if fred else (0.28 + 0.10 * sin(_clock * 3.0))
				var p0: Vector2 = (_rules._blooms[0]["pos"] as Vector2).round()
				var p1: Vector2 = (_rules._blooms[1]["pos"] as Vector2).round()
				var p2: Vector2 = (_rules._blooms[2]["pos"] as Vector2).round()
				var p3: Vector2 = (_rules._blooms[3]["pos"] as Vector2).round()
				draw_line(p0, p1, Color(PAL["lime"] as Color, ha), 1.0); draw_line(p2, p3, Color(PAL["lime"] as Color, ha), 1.0)
				draw_line(p0, p2, Color(PAL["gold"] as Color, ha), 1.0); draw_line(p1, p3, Color(PAL["gold"] as Color, ha), 1.0)
		4:
			if not cleared and ph >= 2:
				var sn: int = 6 if ph >= 3 else 4
				var wa: float = 0.24 if fred else (0.26 + 0.10 * sin(_clock * 3.2))
				for wi: int in range(sn):
					var wt: float = float(wi) / float(sn) if fred else fposmod(_clock * (0.28 if ph == 2 else 0.44) + float(wi) * 0.21, 1.0)
					var wy: float = _center.y + lerpf(-52.0, 52.0, float(wi) / float(maxi(1, sn - 1)))
					var wx: float = _center.x + lerpf(-96.0, 96.0, wt)
					draw_line(Vector2(wx - 16.0, wy + 3.0).round(), Vector2(wx + 16.0, wy - 3.0).round(), Color((PAL["ice"] if wi % 2 == 0 else PAL["sky"]) as Color, wa), 1.2)
				var glints: Array[Vector2] = [Vector2(-72.0, -34.0), Vector2(72.0, -34.0), Vector2(-64.0, 38.0), Vector2(64.0, 38.0)]
				for gi: int in range(glints.size()):
					var gp: Vector2 = (_center + glints[gi]).round()
					var gs: float = 3.5 if fred else (2.5 + 1.8 * absf(sin(_clock * 2.8 + float(gi) * 1.4)))
					var gc: Color = Color((PAL["rose"] if (ph >= 3 and gi % 2 == 1) else PAL["ice"]) as Color, 0.48)
					draw_line(gp + Vector2(-gs, 0.0), gp + Vector2(gs, 0.0), gc, 1.0)
					draw_line(gp + Vector2(0.0, -gs), gp + Vector2(0.0, gs), gc, 1.0)
			if cleared:
				var c4: Vector2 = _center.round()
				draw_arc(c4, 42.0, -PI * 0.85, -PI * 0.15, 18, Color(PAL["rose"] as Color, 0.42), 1.6)
				draw_arc(c4, 38.0, -PI * 0.85, -PI * 0.15, 18, Color(PAL["gold"] as Color, 0.42), 1.4)
				draw_arc(c4, 34.0, -PI * 0.85, -PI * 0.15, 18, Color(PAL["ice"] as Color, 0.42), 1.2)
		5:
			for si: int in range(ABYSS_STARS_5.size()):
				var st_p: Vector2 = (_center + ABYSS_STARS_5[si]).round()
				var tw5: float = 0.62 if fred else (0.35 + 0.55 * sin(_clock * (1.8 + float(si) * 0.35) + float(si) * 1.3))
				draw_rect(Rect2(st_p, Vector2.ONE), Color((PAL["sky"] if tw5 > 0.60 else PAL["deep"]) as Color, clampf(tw5, 0.25, 0.85)))
			for nd: Dictionary in _orrery_nodes:
				var ready_n: bool = float(nd["cd"]) <= 0.0
				var np: Vector2 = (_center + Vector2(cos(float(nd["ang"])) * 108.0, sin(float(nd["ang"])) * 62.0)).round()
				draw_arc(np, 7.0 if ready_n else 4.0, 0.0, TAU, 14, Color((PAL["gold"] if ready_n else PAL["blue"]) as Color, 0.72 if ready_n else 0.35), 1.2)
				if ready_n:
					draw_rect(Rect2(np - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
			if cleared:
				for k: int in range(6):
					var ang: float = _clock * 0.6 + float(k) * (TAU / 6.0)
					var sp: Vector2 = (_center + Vector2(cos(ang) * 48.0, sin(ang) * 34.0)).round()
					draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["gold"] as Color)
					draw_rect(Rect2(sp, Vector2.ONE), PAL["cream"] as Color)
		6:
			if not cleared and ph >= 2:
				var c6: Vector2 = _center.round()
				for v: Dictionary in _rules._vents:
					var vp: Vector2 = (v["pos"] as Vector2).round()
					var v_ph: float = float(v.get("phase", 0.0))
					var pulse6: float = 0.55 if fred else (0.45 + 0.45 * sin(_clock * (3.2 if ph >= 3 else 2.0) + v_ph * TAU))
					var mid6: Vector2 = c6.lerp(vp, 0.5) + Vector2(0.0, -6.0 if vp.y < c6.y else 6.0)
					draw_line(c6, mid6.round(), Color(PAL["wine"] as Color, 0.38 + 0.18 * pulse6), 2.8)
					draw_line(mid6.round(), vp, Color(PAL["wine"] as Color, 0.38 + 0.18 * pulse6), 2.8)
					draw_line(c6, mid6.round(), Color((PAL["gold"] if ph >= 3 else PAL["coral"]) as Color, 0.32 + 0.30 * pulse6), 1.3)
					draw_line(mid6.round(), vp, Color((PAL["gold"] if ph >= 3 else PAL["coral"]) as Color, 0.32 + 0.30 * pulse6), 1.3)
			if cleared:
				for k: int in range(6):
					var u6: float = fposmod(_clock * 0.45 + float(k) * 0.17, 1.0)
					var ep: Vector2 = (_center + Vector2(sin(_clock * 1.4 + float(k) * 1.9) * 36.0, 20.0 - u6 * 56.0)).round()
					draw_rect(Rect2(ep, Vector2(2.0, 2.0)), Color((PAL["gold"] if k % 2 == 0 else PAL["apricot"]) as Color, sin(u6 * PI) * 0.78))
		7:
			for anc: Dictionary in _lunar_anchors:
				var ap: Vector2 = (anc["pos"] as Vector2).round()
				var rdy7: bool = float(anc["cd"]) <= 0.0
				var ft7: float = float(anc["flash_t"])
				draw_circle(ap, 6.0 if rdy7 else 4.0, Color((PAL["sky"] if rdy7 else PAL["deep"]) as Color, 0.55))
				draw_arc(ap, 8.0 if rdy7 else 5.0, -PI * 0.65, PI * 0.65, 12, (PAL["ice"] if rdy7 else PAL["blue"]) as Color, 1.3)
				if rdy7:
					draw_rect(Rect2(ap - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
				if ft7 > 0.0:
					var u7: float = 1.0 - clampf(ft7 / 0.55, 0.0, 1.0)
					draw_arc(ap, roundf(lerpf(8.0, 42.0, u7)), 0.0, TAU, 18, Color(PAL["ice"] as Color, (1.0 - u7) * 0.85), 1.4)
			if cleared or _rules.lunar_phase > 0.65:
				var a: float = 0.25 if fred else (0.28 + 0.14 * sin(_clock * 3.0))
				draw_line(_center + Vector2(-128.0, -48.0), _center + Vector2(128.0, -48.0), Color(PAL["ice"] as Color, a), 1.0)
				draw_arc(_center.round(), 52.0, _clock * 0.6, _clock * 0.6 + PI * 0.7, 16, Color(PAL["sky"] as Color, a * 1.4), 1.2)
				draw_arc(_center.round(), 52.0, _clock * 0.6 + PI, _clock * 0.6 + PI * 1.7, 16, Color((PAL["gold"] if cleared else PAL["ice"]) as Color, a * 1.4), 1.2)
		8:
			for rel: Dictionary in _dawn_relics:
				var rp: Vector2 = (rel["pos"] as Vector2).round()
				var rdy8: bool = float(rel["cd"]) <= 0.0
				var ft8: float = float(rel["flash_t"])
				draw_circle(rp, 5.5 if rdy8 else 3.5, Color((PAL["gold"] if (rdy8 or cleared) else PAL["plum"]) as Color, 0.60))
				draw_arc(rp, 8.0 if rdy8 else 5.0, 0.0, TAU, 14, (PAL["gold"] if (rdy8 or cleared) else PAL["rose"]) as Color, 1.2)
				if rdy8 or cleared:
					draw_rect(Rect2(rp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
				if ft8 > 0.0:
					var u8: float = 1.0 - clampf(ft8 / 0.55, 0.0, 1.0)
					draw_arc(rp, roundf(lerpf(8.0, 48.0, u8)), 0.0, TAU, 20, Color(PAL["gold"] as Color, (1.0 - u8) * 0.88), 1.6)
			if cleared:
				for k: int in range(8):
					var ang: float = float(k) * (TAU / 8.0) + _clock * 0.18
					draw_line((_center + Vector2(cos(ang) * 18.0, sin(ang) * 14.0)).round(), (_center + Vector2(cos(ang) * 72.0, sin(ang) * 52.0)).round(), Color(PAL["gold"] as Color, 0.30 if fred else 0.48), 1.4)
			var seals: int = _mech.dawn_seals_broken if _mech != null else 0
			var relit: bool = Lx.state != null and Lx.state.relit_islands.has(8)
			for k: int in range(3):
				var ang: float = _clock * (0.9 if (relit or cleared) else 0.55) + float(k) * (TAU / 3.0)
				var sp: Vector2 = (_center + Vector2(cos(ang) * 74.0, sin(ang) * 44.0)).round()
				var lit_seal: bool = relit or cleared or k < seals
				draw_circle(sp, 3.5 if lit_seal else 2.5, (PAL["gold"] if lit_seal else PAL["plum"]) as Color)
				if lit_seal:
					draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)


func _live_boss() -> LxEnemyBrain:
	if _region == null or not _region.has_method("get_enemies"):
		return null
	var ev: Variant = _region.call("get_enemies")
	if ev is Array:
		for e_v: Variant in (ev as Array):
			if e_v is LxEnemyBrain and is_instance_valid(e_v):
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive() and e.is_boss:
					return e
	return null


func _draw_center_ritual_ring(fred: bool, ph: int, boss: LxEnemyBrain) -> void:
	var c: Vector2 = _center.round()
	var r: float = 54.0 + float(clampi(ph, 1, 4) - 1) * 4.0
	var base_c: Color = (PAL["sky"] if ph >= 4 else (PAL["coral"] if ph >= 3 else (LxBiomePalette.col(_island_id, "glow") if ph == 2 else LxBiomePalette.col(_island_id, "hi")))) as Color
	var a_ring: float = (0.18 + float(ph - 1) * 0.11) * (0.82 if fred else (0.88 + 0.16 * sin(_clock * (1.8 + float(ph) * 0.7))))
	if ph <= 2:
		draw_arc(c, r, 0.0, TAU, 32, Color(base_c, a_ring), 1.0 if ph == 1 else 1.4)
		if ph == 2:
			for k: int in range(4):
				var d: Vector2 = Vector2.from_angle(float(k) * (PI * 0.5) + _clock * 0.25)
				draw_line((c + d * (r - 4.0)).round(), (c + d * (r + 4.0)).round(), Color(PAL["gold"] as Color, a_ring * 1.2), 1.2)
	else:
		var segs: int = 8 if ph >= 4 else 6
		var rot: float = 0.0 if fred else _clock * (0.45 if ph >= 4 else 0.28)
		for k: int in range(segs):
			var a0: float = rot + float(k) * (TAU / float(segs))
			draw_arc(c, r, a0 + 0.08, a0 + (TAU / float(segs)) - 0.14, 6, Color(base_c, a_ring), 1.6)
			var fd: Vector2 = Vector2.from_angle(a0)
			draw_line((c + fd * (r - 6.0)).round(), (c + fd * (r + 5.0)).round(), Color((PAL["gold"] if ph >= 4 else PAL["apricot"]) as Color, a_ring * 1.15), 1.2)
		draw_arc(c, r - 6.0, 0.0, TAU, 28, Color((PAL["gold"] if ph >= 4 else PAL["wine"]) as Color, a_ring * 0.7), 1.0)
	if _island_id == 8 and ph >= 4 and boss != null and not bool(boss.get("veil_intact")):
		for ki: int in range(8):
			var ka: float = float(ki) * (TAU / 8.0)
			var kd: Vector2 = Vector2.from_angle(ka)
			var col_i: Color = LxBiomePalette.col(ki + 1, "glow")
			var ra: float = 0.42 if fred else (0.46 + 0.20 * sin(_clock * 4.0 + float(ki)))
			draw_line((c + kd * 92.0).round(), (c + kd * 20.0).round(), Color(col_i, ra), 1.5)
			var gt: float = 0.5 if fred else fposmod(_clock * 0.85 + float(ki) * 0.125, 1.0)
			var gp: Vector2 = (c + kd * lerpf(90.0, 22.0, gt)).round()
			draw_rect(Rect2(gp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)


func _draw_boss_phase_corners(fred: bool, ph: int) -> void:
	if ph < 2:
		return
	var r_in: Rect2 = _rules.bounds.grow(-30.0)
	var col: Color = (PAL["sky"] if ph >= 4 else (PAL["coral"] if ph >= 3 else LxBiomePalette.col(_island_id, "glow"))) as Color
	var a: float = 0.42 if fred else (0.36 + 0.24 * sin(_clock * (2.6 + float(ph) * 0.5)))
	var rad: float = 7.0 if ph == 2 else 9.0
	for pt: Vector2 in [r_in.position, Vector2(r_in.end.x, r_in.position.y), Vector2(r_in.position.x, r_in.end.y), r_in.end]:
		var cp: Vector2 = pt.round()
		draw_arc(cp, rad, _clock * 0.9, _clock * 0.9 + PI * 1.4, 10, Color(col, a), 1.2)
		LxHudFx.draw_biome_crest(self, _island_id, cp, Color(col, a * 1.25), Color(PAL["cream"] as Color, a))
