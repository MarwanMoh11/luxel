class_name LxRelitKeepsakes
extends RefCounted
## Monumental Dawn Keepsakes that permanently crown each saved island's sanctuary threshold
## once its Great Lamp is relit (Islands 1..8). Strictly uses the 20 Last Light colours.

const PAL: Dictionary = LxPalette.PAL


static func draw_keepsake(ci: CanvasItem, island_id: int, door_pos: Vector2, clock: float, fred: bool) -> void:
	if ci == null:
		return
	var c: Vector2 = (door_pos + Vector2(0.0, -28.0)).round()
	var g: Color = LxBiomePalette.col(island_id, "glow")
	var hi: Color = LxBiomePalette.col(island_id, "hi")
	var cr: Color = PAL["cream"] as Color
	var gold: Color = PAL["gold"] as Color
	var pulse: float = 0.72 if fred else (0.64 + 0.36 * sin(clock * 2.4))
	match island_id:
		1: # Bell Isle: Restored Golden Belfry Carillon Arch + 3 swaying micro-bells
			ci.draw_arc(c + Vector2(0.0, 6.0), 18.0, PI * 1.12, PI * 1.88, 16, Color(gold, 0.78 * pulse), 1.5)
			ci.draw_arc(c + Vector2(0.0, 6.0), 15.0, PI * 1.16, PI * 1.84, 14, Color(cr, 0.55 * pulse), 1.0)
			for k: int in range(-1, 2):
				var sw: float = 0.0 if fred else roundf(sin(clock * 2.6 + float(k) * 1.1) * 1.2)
				var bp := (c + Vector2(float(k) * 10.0 + sw, -5.0 + absf(float(k)) * 3.0)).round()
				ci.draw_rect(Rect2(bp + Vector2(-2.0, 0.0), Vector2(4.0, 3.0)), gold)
				ci.draw_rect(Rect2(bp + Vector2(-1.0, 0.0), Vector2(2.0, 2.0)), cr)
				ci.draw_rect(Rect2(bp + Vector2(0.0, 3.0), Vector2.ONE), PAL["apricot"] as Color)
		2: # Tidewater Harbor: Twin Azure-Gold Triumph Pennants + Fresnel Sun-Crown
			for side: float in [-1.0, 1.0]:
				var px: float = c.x + side * 20.0
				ci.draw_line(Vector2(px, c.y + 10.0), Vector2(px, c.y - 8.0), PAL["apricot"] as Color, 1.0)
				ci.draw_rect(Rect2(px - 1.0, c.y - 9.0, 2.0, 2.0), gold)
				var wav: float = 0.0 if fred else roundf(sin(clock * 3.2 + side) * 1.5)
				var tip := Vector2(px + side * 9.0, c.y - 5.0 + wav)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px, c.y - 8.0), tip, Vector2(px, c.y - 2.0)]), Color(PAL["sky"] as Color, 0.82))
				ci.draw_line(Vector2(px, c.y - 5.0), tip, Color(gold, 0.85), 1.0)
			ci.draw_arc(c + Vector2(0.0, -4.0), 10.0, 0.0, TAU, 16, Color(gold, 0.65 * pulse), 1.2)
			ci.draw_rect(Rect2(c + Vector2(-1.0, -5.0), Vector2(2.0, 2.0)), cr)
		3: # Thornwood Hollow: Blooming Emerald-Gold Heartwood Dawn Canopy
			ci.draw_arc(c + Vector2(0.0, 8.0), 22.0, PI * 1.08, PI * 1.92, 18, Color(PAL["jade"] as Color, 0.72), 2.0)
			ci.draw_arc(c + Vector2(0.0, 8.0), 20.0, PI * 1.12, PI * 1.88, 16, Color(PAL["lime"] as Color, 0.82 * pulse), 1.0)
			for k: int in range(5):
				var ang: float = PI * 1.18 + float(k) * (PI * 0.64 / 4.0)
				var bob: float = 0.0 if fred else sin(clock * 2.4 + float(k)) * 1.0
				var lp: Vector2 = (c + Vector2(0.0, 8.0) + Vector2.from_angle(ang) * (21.0 + bob)).round()
				ci.draw_rect(Rect2(lp - Vector2.ONE, Vector2(3.0, 3.0)), gold if k % 2 == 0 else (PAL["lime"] as Color))
				ci.draw_rect(Rect2(lp, Vector2.ONE), cr)
		4: # Mirefen Gardens: Rotating 8-Petal Rose/Ice/Gold Stained-Glass Sun-Rosette
			var rot: float = 0.0 if fred else clock * 0.45
			ci.draw_arc(c + Vector2(0.0, -2.0), 13.0, 0.0, TAU, 20, Color(gold, 0.74 * pulse), 1.2)
			for k: int in range(8):
				var a: float = rot + float(k) * (TAU / 8.0)
				var p0: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(a) * 4.0).round()
				var p1: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(a) * 12.0).round()
				var pc: Color = (PAL["rose"] if k % 3 == 0 else (PAL["ice"] if k % 3 == 1 else gold)) as Color
				ci.draw_line(p0, p1, Color(pc, 0.82 * pulse), 1.4)
			ci.draw_circle(c + Vector2(0.0, -2.0), 2.5, cr)
		5: # Starfall Observatory: Illuminated Golden-Sky Zodiac Astrolabe Crown
			var r1: float = 0.0 if fred else clock * 0.65
			var r2: float = 0.0 if fred else -clock * 0.45
			ci.draw_arc(c + Vector2(0.0, -2.0), 15.0, r1, r1 + PI * 1.5, 18, Color(gold, 0.82 * pulse), 1.4)
			ci.draw_arc(c + Vector2(0.0, -2.0), 10.0, r2, r2 + PI * 1.5, 16, Color(PAL["sky"] as Color, 0.82 * pulse), 1.2)
			for k: int in range(6):
				var sa: float = r1 * 0.5 + float(k) * (TAU / 6.0)
				var sp: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(sa) * 15.0).round()
				ci.draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), cr if k % 2 == 0 else gold)
		6: # Ashen Kiln: Twin Tempered Phoenix Hearth Braziers + Crown Arch
			ci.draw_arc(c + Vector2(0.0, 6.0), 19.0, PI * 1.15, PI * 1.85, 16, Color(PAL["coral"] as Color, 0.70 * pulse), 1.2)
			for side: float in [-1.0, 1.0]:
				var bx: float = c.x + side * 18.0
				var fh: float = roundf(9.0 + (0.0 if fred else absf(sin(clock * 5.2 + side)) * 4.0))
				ci.draw_rect(Rect2(bx - 3.0, c.y + 4.0, 6.0, 3.0), PAL["apricot"] as Color)
				ci.draw_rect(Rect2(bx - 2.0, c.y + 4.0 - fh, 4.0, fh), PAL["coral"] as Color)
				ci.draw_rect(Rect2(bx - 1.0, c.y + 4.0 - fh * 0.72, 2.0, fh * 0.72), gold)
				ci.draw_rect(Rect2(bx, c.y + 3.0 - fh * 0.45, 1.0, fh * 0.45), cr)
		7: # Moon Shoals: Interlocking Silver-Ice & Dawn-Gold Twin Crescent Mirror Halos
			var cen := c + Vector2(0.0, -2.0)
			ci.draw_arc(cen + Vector2(-4.0, 0.0), 11.0, PI * 0.35, PI * 1.65, 16, Color(PAL["ice"] as Color, 0.84 * pulse), 1.6)
			ci.draw_arc(cen + Vector2(4.0, 0.0), 11.0, -PI * 0.65, PI * 0.65, 16, Color(gold, 0.84 * pulse), 1.6)
			ci.draw_line(cen + Vector2(0.0, -9.0), cen + Vector2(0.0, 9.0), Color(cr, 0.68 * pulse), 1.0)
			ci.draw_rect(Rect2(cen - Vector2.ONE, Vector2(2.0, 2.0)), cr)
		_: # The Long Night: Grand Cathedral Dawn Sun-Cross orbited by all 8 islands' biome stars!
			var cen8 := c + Vector2(0.0, -4.0)
			ci.draw_arc(cen8, 16.0, 0.0, TAU, 24, Color(gold, 0.78 * pulse), 1.4)
			for r_i: int in range(8):
				var ra: float = float(r_i) * (TAU / 8.0)
				var len_r: float = 15.0 if r_i % 2 == 0 else 10.0
				ci.draw_line(cen8, (cen8 + Vector2.from_angle(ra) * len_r).round(), Color(gold if r_i % 2 == 0 else cr, 0.82 * pulse), 1.4 if r_i % 2 == 0 else 1.0)
			var orb_rot: float = 0.0 if fred else clock * 0.55
			for isl_s: int in range(1, 9):
				var oa: float = orb_rot + float(isl_s - 1) * (TAU / 8.0)
				var op: Vector2 = (cen8 + Vector2.from_angle(oa) * 20.0).round()
				ci.draw_rect(Rect2(op - Vector2.ONE, Vector2(2.0, 2.0)), LxBiomePalette.col(isl_s, "glow"))
				ci.draw_rect(Rect2(op, Vector2.ONE), cr)
			ci.draw_circle(cen8, 3.0, cr)

	# Harmony Star crown & orbiting mastery sparks floating directly above the Keepsake when all discoveries are found!
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % island_id, false)):
		var hy: float = c.y - 24.0 + (0.0 if fred else roundf(sin(clock * 2.2) * 1.2))
		var hs := Vector2(c.x, hy).round()
		var h_rot: float = 0.0 if fred else clock * 1.1
		ci.draw_arc(hs, 6.0, h_rot, h_rot + PI * 1.35, 10, Color(g, 0.56 * pulse), 1.0)
		for hk: int in range(2):
			var ha: float = h_rot + float(hk) * PI
			var hp: Vector2 = (hs + Vector2(cos(ha) * 6.0, sin(ha) * 3.5)).round()
			ci.draw_rect(Rect2(hp, Vector2.ONE), Color(cr if hk == 0 else gold, 0.85))
		ci.draw_rect(Rect2(hs + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), g)
		ci.draw_rect(Rect2(hs + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), g)
		ci.draw_rect(Rect2(hs + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), hi)
		ci.draw_rect(Rect2(hs, Vector2.ONE), cr)
	# Post-game 8/8 True Dawn Chorus: revisiting any saved island crowns its Keepsake with gentle golden dawn motes!
	if Lx.state != null and Lx.state.relit_islands.size() >= 8 and island_id < 8:
		var dc_rot: float = 0.0 if fred else clock * 0.45
		for dk: int in range(4):
			var da: float = dc_rot + float(dk) * (PI * 0.5)
			var dp: Vector2 = (c + Vector2(cos(da) * 24.0, -2.0 + sin(da) * 10.0)).round()
			ci.draw_rect(Rect2(dp, Vector2(2.0 if dk % 2 == 0 else 1.0, 1.0)), Color(cr if dk % 2 == 0 else gold, 0.65 * pulse))
