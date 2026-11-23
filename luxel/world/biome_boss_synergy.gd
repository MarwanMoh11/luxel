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

var _rules: LxBiomeRules = null
var _mech: LxBiomeMechanics = null
var _region: Node = null
var _island_id: int = 1
var _active: bool = false
var _clock: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _bell_pulse_t: float = 0.0
var _was_dashing: bool = false


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
	var rid: String = str(region_node.get("current_region_id")) if region_node != null and region_node.get("current_region_id") != null else ""
	_active = BOSS_REGIONS.has(rid)
	_center = rules.bounds.get_center() if rules != null else Vector2(224.0, 144.0)
	if _active and _rules != null:
		_seed_boss_arena_features()
	queue_redraw()


func _seed_boss_arena_features() -> void:
	match _island_id:
		2: # Lighthouse Hermit: aim Fresnel origin from the Great Lamp dais
			_rules.beam_origin = Vector2(_center.x, 56.0)
		3: # Briar Matron: 4 interactive emerald canopy Bloom-Lamps in the Cruciform wing corners
			_rules._blooms.clear()
			for off: Vector2 in [
				Vector2(-120.0, -56.0), Vector2(120.0, -56.0),
				Vector2(-120.0, 56.0), Vector2(120.0, 56.0),
			]:
				_rules._blooms.append({"pos": _center + off, "lit_t": 4.0})
		4: # Heron Abbess: 4 guaranteed live Mist Updrafts over the indoor lagoon corners
			for off: Vector2 in [
				Vector2(-148.0, -68.0), Vector2(148.0, -68.0),
				Vector2(-148.0, 68.0), Vector2(148.0, 68.0),
			]:
				_rules._updrafts.append({"pos": _center + off, "r": 20.0, "cd": 0.0})
		6: # The Kilnmother: 4 rhythmic caldera Magma Vents for mid-fight Molten Overdrive!
			_rules._vents.clear()
			var phases: Array[float] = [0.0, 0.25, 0.50, 0.75]
			var offs: Array[Vector2] = [
				Vector2(-116.0, -54.0), Vector2(116.0, -54.0),
				Vector2(-116.0, 54.0), Vector2(116.0, 54.0),
			]
			for i: int in range(offs.size()):
				_rules._vents.append({"pos": _center + offs[i], "phase": phases[i], "ember_cd": 0.0, "erupted": false})


func tick(dt: float) -> void:
	if not _active or dt <= 0.0 or _rules == null:
		return
	_clock += dt
	_bell_pulse_t = maxf(0.0, _bell_pulse_t - dt)
	if _island_id == 1:
		_tick_belfry_ring()
	elif _island_id == 3:
		_tick_oak_boss_blooms(dt)
	queue_redraw()


func _tick_belfry_ring() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	var dashing: bool = w.is_dashing()
	if dashing and not _was_dashing and w.global_position.distance_to(_center) <= 78.0:
		_bell_pulse_t = 0.52
		if Lx.audio != null:
			Lx.audio.play_sfx("prop_chime", _center, true)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(_center, 94.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.36)
	_was_dashing = dashing


func _tick_oak_boss_blooms(dt: float) -> void:
	var ppos: Vector2 = (Lx.player as LxWick).global_position if (Lx.player is LxWick and is_instance_valid(Lx.player)) else Vector2(-9999.0, -9999.0)
	var lpos: Vector2 = Vector2(-9999.0, -9999.0)
	var p_act: bool = false
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		p_act = w.is_dashing() or w.is_beam_charging()
		if w.lantern != null and is_instance_valid(w.lantern):
			lpos = w.lantern.global_position
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


func try_hit_boss_bloom(from_p: Vector2, to_p: Vector2) -> void:
	if not _active or _island_id != 3 or _rules == null:
		return
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


func _draw() -> void:
	if not _active or _rules == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	match _island_id:
		1:
			if _bell_pulse_t > 0.0:
				var u: float = 1.0 - clampf(_bell_pulse_t / 0.52, 0.0, 1.0)
				var r: float = roundf(lerpf(18.0, 88.0, u))
				draw_arc(_center.round(), r, 0.0, TAU, 24, Color(PAL["gold"] as Color, (1.0 - u) * (0.55 if fred else 0.85)), 1.6)
		3:
			for b: Dictionary in _rules._blooms:
				var bp: Vector2 = (b["pos"] as Vector2).round()
				var lit: bool = float(b["lit_t"]) > 0.0
				draw_circle(bp, 5.5 if lit else 3.5, (PAL["jade"] if lit else PAL["pine"]) as Color)
				draw_circle(bp, 2.5 if lit else 1.5, (PAL["cream"] if lit else PAL["teal"]) as Color)
				if lit:
					var rr: float = roundf(12.0 + (0.0 if fred else sin(_clock * 4.0 + bp.x) * 2.0))
					draw_arc(bp, rr, 0.0, TAU, 16, Color(PAL["lime"] as Color, 0.65), 1.0)
		7:
			if _rules.lunar_phase > 0.65:
				var a: float = 0.25 if fred else (0.28 + 0.14 * sin(_clock * 3.0))
				draw_line(_center + Vector2(-128.0, -48.0), _center + Vector2(128.0, -48.0), Color(PAL["ice"] as Color, a), 1.0)
				draw_arc(_center.round(), 52.0, _clock * 0.6, _clock * 0.6 + PI * 0.7, 16, Color(PAL["sky"] as Color, a * 1.4), 1.2)
				draw_arc(_center.round(), 52.0, _clock * 0.6 + PI, _clock * 0.6 + PI * 1.7, 16, Color(PAL["ice"] as Color, a * 1.4), 1.2)
		8:
			var seals: int = _mech.dawn_seals_broken if _mech != null else 0
			var relit: bool = Lx.state != null and Lx.state.relit_islands.has(8)
			for k: int in range(3):
				var ang: float = _clock * (0.9 if relit else 0.55) + float(k) * (TAU / 3.0)
				var sp: Vector2 = (_center + Vector2(cos(ang) * 74.0, sin(ang) * 44.0)).round()
				var lit_seal: bool = relit or k < seals
				draw_circle(sp, 3.5 if lit_seal else 2.5, (PAL["gold"] if lit_seal else PAL["plum"]) as Color)
				if lit_seal:
					draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
