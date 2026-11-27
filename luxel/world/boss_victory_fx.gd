class_name LxBossVictoryFx
extends RefCounted
## Post-boss sanctum victory dawn crescendo, processional Great Lamp runner, and
## biome-signature lingering celebration motes across all 8 Boss Sanctums.
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL

var _island_id: int = 1
var _center: Vector2 = Vector2.ZERO
var _lamp_pos: Vector2 = Vector2.ZERO
var _has_lamp: bool = false
var _boss_was_live: bool = false
var _surge_t: float = 0.0


func configure(island_id: int, center: Vector2, region_node: Node, live_boss: bool) -> void:
	_island_id = clampi(island_id, 1, 8)
	_center = center
	_lamp_pos = center + Vector2(0.0, -76.0)
	_has_lamp = false
	_boss_was_live = live_boss
	_surge_t = 0.0
	if region_node != null and is_instance_valid(region_node) and region_node.has_method("get_interactables"):
		var items_v: Variant = region_node.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if it is LxGreatLamp and is_instance_valid(it):
					_lamp_pos = (it as LxGreatLamp).pos
					_has_lamp = true
					break


func tick(dt: float, live_now: bool) -> void:
	if _surge_t > 0.0:
		_surge_t = maxf(0.0, _surge_t - dt)
	if _boss_was_live and not live_now:
		_surge_t = 0.88
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			var strength: float = 0.88 if LxHudFx.flash_reduced() else 1.42
			LxDarknessLayer.active_instance.add_burst_light(_center, 152.0, strength, 0.72)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, _center, 22.0, 12.0)
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, _center, 18.0, 10.0)
		if Lx.audio != null:
			var sfx_id: String = "prop_chime"
			match _island_id:
				1: sfx_id = "bell_toll"
				2: sfx_id = "lighthouse_toll"
				4: sfx_id = "wing_gale"
				5: sfx_id = "clockwork_chime"
				6: sfx_id = "forge_gust"
				7: sfx_id = "lens_reveal"
				8: sfx_id = "great_lamp_bloom"
			Lx.audio.play_sfx(sfx_id, _center, true)
	_boss_was_live = live_now


func draw_celebration(ci: CanvasItem, clock: float, fred: bool, cleared: bool) -> void:
	var c_glow: Color = LxBiomePalette.col(_island_id, "glow")
	var c_hi: Color = LxBiomePalette.col(_island_id, "hi")
	var c_cream: Color = PAL["cream"] as Color
	if _surge_t > 0.0:
		var u: float = 1.0 - clampf(_surge_t / 0.88, 0.0, 1.0)
		var a_s: float = (1.0 - u) * (0.55 if fred else 0.90)
		var r1: float = roundf(lerpf(14.0, 118.0, u))
		var r2: float = roundf(lerpf(8.0, 82.0, u))
		ci.draw_arc(_center.round(), r1, 0.0, TAU, 28, Color(c_glow, a_s), 2.0)
		ci.draw_arc(_center.round(), r2, 0.0, TAU, 22, Color(c_cream, a_s), 1.0)
		for k: int in range(8):
			var ang: float = float(k) * (TAU / 8.0) + u * 0.65
			var sp: Vector2 = (_center + Vector2.from_angle(ang) * lerpf(10.0, 92.0, u)).round()
			ci.draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), Color(c_cream if k % 2 == 0 else c_hi, a_s))
	if not cleared:
		return
	var relit: bool = Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var c_cen: Vector2 = _center.round()
	var halo_r: float = roundf(18.0 + (0.0 if fred else sin(clock * 1.9) * 2.0))
	ci.draw_arc(c_cen, halo_r, 0.0, TAU, 20, Color((PAL["gold"] as Color) if relit else c_glow, 0.24 if fred else 0.34), 1.0)
	var h_rot: float = 0.0 if fred else clock * 0.55
	for hk: int in range(4):
		var ha: float = h_rot + float(hk) * (PI * 0.5)
		var hp: Vector2 = (c_cen + Vector2.from_angle(ha) * halo_r).round()
		ci.draw_rect(Rect2(hp, Vector2.ONE), Color(c_cream if hk % 2 == 0 else c_glow, 0.65 if fred else 0.85))
	LxHudFx.draw_biome_crest(ci, _island_id, c_cen, Color(c_glow, 0.68), Color(c_cream, 0.78))
	if _has_lamp and _lamp_pos.distance_to(_center) > 28.0:
		_draw_lamp_procession(ci, clock, fred, relit, c_glow, c_hi, c_cream)
	_draw_biome_victory_shower(ci, clock, fred, relit, c_glow, c_hi, c_cream)


func _draw_lamp_procession(ci: CanvasItem, clock: float, fred: bool, relit: bool, c_glow: Color, c_hi: Color, c_cream: Color) -> void:
	var dir: Vector2 = (_lamp_pos - _center).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var dist: float = _lamp_pos.distance_to(_center)
	var steps: int = clampi(int(dist / 22.0), 2, 5)
	var base_a: float = 0.42 if fred else 0.54
	var lead_col: Color = (PAL["gold"] as Color) if relit else c_glow
	for i: int in range(1, steps):
		var frac: float = float(i) / float(steps)
		var wave: float = 1.0 if fred else (0.55 + 0.45 * sin(clock * 3.4 - float(i) * 1.05))
		var pt: Vector2 = _center.lerp(_lamp_pos, frac).round()
		var p_l: Vector2 = (pt + perp * 6.0 - dir * 3.0).round()
		var p_r: Vector2 = (pt - perp * 6.0 - dir * 3.0).round()
		ci.draw_line(p_l, pt, Color(lead_col, base_a * wave), 1.0)
		ci.draw_line(p_r, pt, Color(lead_col, base_a * wave), 1.0)
		ci.draw_rect(Rect2(pt, Vector2.ONE), Color(c_cream if relit else c_hi, clampf(base_a * wave * 1.35, 0.0, 0.92)))


func _draw_biome_victory_shower(ci: CanvasItem, clock: float, fred: bool, relit: bool, c_glow: Color, c_hi: Color, c_cream: Color) -> void:
	var spd: float = 0.22 if fred else 0.42
	var a_mul: float = 0.62 if fred else 0.86
	for k: int in range(8):
		var u: float = fposmod(clock * spd + float(k) * 0.125, 1.0)
		var fade: float = sin(u * PI) * a_mul
		var lane_x: float = (float(k) - 3.5) * 24.0 + sin(clock * (0.9 if fred else 1.7) + float(k) * 1.4) * 7.0
		var py: float = _center.y + 44.0 - u * 108.0
		var pt := Vector2(roundf(_center.x + lane_x), roundf(py))
		match _island_id:
			1: # Brass chime arcs + warm gold sparks
				ci.draw_rect(Rect2(pt, Vector2(2.0, 1.0)), Color(PAL["gold"] as Color if k % 2 == 0 else c_cream, fade))
				if k % 3 == 0:
					ci.draw_arc(pt, 3.0, PI * 1.15, PI * 1.85, 6, Color(PAL["apricot"] as Color, fade * 0.75), 1.0)
			2: # Sea-spray ice diamonds
				var dc: Color = (PAL["ice"] if k % 2 == 0 else PAL["sky"]) as Color
				ci.draw_rect(Rect2(pt + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(dc, fade))
				ci.draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(c_cream if relit else dc, fade))
			3: # Emerald-lime floating blossom petals
				var pc: Color = (PAL["lime"] if k % 2 == 0 else PAL["jade"]) as Color
				ci.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), Color(pc, fade))
				ci.draw_rect(Rect2(pt, Vector2.ONE), Color(c_cream, fade * 0.9))
			4: # Stained-glass rose & ice prisms
				var gc: Color = (PAL["rose"] if k % 2 == 0 else PAL["ice"]) as Color
				ci.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), Color(gc, fade))
				ci.draw_rect(Rect2(pt + Vector2(1.0, -1.0), Vector2.ONE), Color(PAL["gold"] as Color, fade * 0.8))
			5: # Orbiting zodiac micro-stars
				var ang5: float = clock * (0.35 if fred else 0.75) + float(k) * (TAU / 8.0)
				var p5: Vector2 = (_center + Vector2(cos(ang5) * (62.0 + float(k % 2) * 18.0), sin(ang5) * (36.0 + float(k % 2) * 10.0))).round()
				ci.draw_rect(Rect2(p5, Vector2(2.0, 1.0)), Color(PAL["gold"] as Color if k % 2 == 0 else PAL["sky"] as Color, a_mul * 0.85))
				ci.draw_rect(Rect2(p5, Vector2.ONE), Color(c_cream, a_mul))
			6: # Cooled tranquil hearth-gold & apricot lantern embers
				ci.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), Color((PAL["gold"] if relit or k % 2 == 0 else PAL["apricot"]) as Color, fade))
				ci.draw_rect(Rect2(pt, Vector2.ONE), Color(c_cream, fade * 0.85))
			7: # Silver-gold lunar crescent dew
				ci.draw_rect(Rect2(pt, Vector2(1.0, 2.0)), Color((PAL["gold"] if relit else PAL["ice"]) as Color, fade))
				ci.draw_rect(Rect2(pt + Vector2(1.0, 0.0), Vector2.ONE), Color(c_cream, fade * 0.85))
			_: # Island 8: Unified 8-biome dawn tapestry motes rising together!
				var bcol: Color = LxBiomePalette.col(k + 1, "glow")
				ci.draw_rect(Rect2(pt + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(bcol, fade))
				ci.draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(c_cream if relit else bcol, fade))
