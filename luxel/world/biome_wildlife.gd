class_name LxBiomeWildlife
extends RefCounted
## Pixel-snapped biome wildlife silhouettes, raindrop puddle ripples, and atmospheric micro-details
## across all 8 islands. Uses strictly the 20 opaque Last Light colours (LxPalette.PAL).

const VIEW_W: float = 340.0
const VIEW_H: float = 200.0
const HALF_W: float = 170.0
const HALF_H: float = 100.0


static func draw_biome_life(ci: CanvasItem, island_id: int, is_dungeon: bool, clock: float, cam_center: Vector2) -> void:
	var fred: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var min_x: float = cam_center.x - HALF_W
	var min_y: float = cam_center.y - HALF_H
	match island_id:
		1:
			if is_dungeon:
				_draw_belfry_incense(ci, clock, min_x, min_y, 5, fred)
			else:
				_draw_gliding_birds(ci, clock, min_x, min_y, 3, 24.0, "night", "dusk", false)
		2:
			if is_dungeon:
				_draw_mist_beads(ci, clock, min_x, min_y, 6, fred)
			else:
				_draw_gliding_birds(ci, clock, min_x, min_y, 3, 28.0, "stone", "ice", true)
		3:
			_draw_spore_wisps(ci, clock, min_x, min_y, 4 if is_dungeon else 6, fred)
		4:
			if is_dungeon:
				_draw_glasshouse_drips(ci, clock, min_x, min_y, 5, fred)
			else:
				_draw_rain_ripples(ci, clock, min_x, min_y, 9, fred)
		5:
			_draw_constellations(ci, clock, min_x, min_y, 3 if is_dungeon else 4, fred)
		6:
			_draw_heat_ribbons(ci, clock, min_x, min_y, 4 if is_dungeon else 6, fred)
		7:
			_draw_prism_glints(ci, clock, min_x, min_y, 4 if is_dungeon else 6, fred)
		_:
			_draw_eclipse_wisps(ci, clock, min_x, min_y, 4 if is_dungeon else 6, fred)
	if not is_dungeon and Lx.state != null and Lx.state.relit_islands.has(island_id):
		_draw_relit_celebration(ci, island_id, clock, min_x, min_y, fred)


static func _draw_gliding_birds(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, spd: float, col_a: String, col_b: String, wide: bool) -> void:
	var ca: Color = Color(LxPalette.PAL[col_a] as Color, 0.78)
	var cb: Color = Color(LxPalette.PAL[col_b] as Color, 0.68)
	for i: int in range(count):
		var fi: float = float(i)
		var dir_x: float = 1.0 if i % 2 == 0 else -1.0
		var bx: float = min_x + fposmod(fi * 113.0 + clock * spd * dir_x, VIEW_W)
		var by: float = min_y + 18.0 + fi * 44.0 + sin(clock * 1.4 + fi * 2.1) * 6.0
		var p := Vector2(roundf(bx), roundf(by))
		var flap: float = -1.0 if sin(clock * (5.2 + fi * 0.7) + fi) > 0.0 else 1.0
		var wing: float = 3.0 if wide else 2.0
		ci.draw_rect(Rect2(p, Vector2.ONE), ca)
		ci.draw_rect(Rect2(p + Vector2(-wing + 1.0, flap * 0.5).round(), Vector2.ONE), ca)
		ci.draw_rect(Rect2(p + Vector2(wing - 1.0, flap * 0.5).round(), Vector2.ONE), ca)
		ci.draw_rect(Rect2(p + Vector2(-wing, flap), Vector2.ONE), cb)
		ci.draw_rect(Rect2(p + Vector2(wing, flap), Vector2.ONE), cb)


static func _draw_spore_wisps(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_j: Color = LxPalette.PAL["jade"] as Color
	var c_l: Color = LxPalette.PAL["lime"] as Color
	var c_c: Color = LxPalette.PAL["cream"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var wx: float = min_x + fposmod(fi * 67.0 + sin(clock * 0.8 + fi) * 14.0, VIEW_W)
		var wy: float = min_y + fposmod(fi * 43.0 - clock * (6.5 + float(i % 3) * 2.0), VIEW_H)
		var p := Vector2(roundf(wx), roundf(wy))
		var a: float = (0.36 if fred else (0.30 + 0.25 * absf(sin(clock * 1.8 + fi))))
		ci.draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(c_j, a))
		ci.draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(c_j, a))
		ci.draw_rect(Rect2(p, Vector2.ONE), Color(c_c if i % 2 == 0 else c_l, a + 0.30))


static func _draw_rain_ripples(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_sky: Color = LxPalette.PAL["sky"] as Color
	var c_ice: Color = LxPalette.PAL["ice"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var per: float = 0.85 + float(i % 4) * 0.16
		var phase: float = fposmod(clock + fi * 0.37, per)
		var slot: float = floorf((clock + fi * 0.37) / per)
		var u: float = phase / per
		if u > 0.62:
			continue
		var rx: float = min_x + fposmod(slot * 73.0 + fi * 41.0 + 19.0, VIEW_W - 16.0) + 8.0
		var ry: float = min_y + fposmod(slot * 47.0 + fi * 29.0 + 11.0, VIEW_H - 16.0) + 8.0
		var p := Vector2(roundf(rx), roundf(ry))
		var alpha: float = (1.0 - u / 0.62) * (0.42 if fred else 0.65)
		if u < 0.18:
			ci.draw_rect(Rect2(p, Vector2(2.0, 1.0)), Color(c_ice, alpha))
		elif u < 0.40:
			ci.draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(1.0, 1.0)), Color(c_sky, alpha))
			ci.draw_rect(Rect2(p + Vector2(2.0, 0.0), Vector2(1.0, 1.0)), Color(c_sky, alpha))
			ci.draw_rect(Rect2(p + Vector2(-1.0, -1.0), Vector2(2.0, 1.0)), Color(c_ice, alpha * 0.85))
			ci.draw_rect(Rect2(p + Vector2(-1.0, 1.0), Vector2(2.0, 1.0)), Color(c_sky, alpha * 0.85))
		else:
			ci.draw_rect(Rect2(p + Vector2(-3.0, 0.0), Vector2(1.0, 1.0)), Color(c_sky, alpha * 0.7))
			ci.draw_rect(Rect2(p + Vector2(3.0, 0.0), Vector2(1.0, 1.0)), Color(c_sky, alpha * 0.7))
			ci.draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2(1.0, 1.0)), Color(c_sky, alpha * 0.6))
			ci.draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(1.0, 1.0)), Color(c_sky, alpha * 0.6))


static func _draw_constellations(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_line: Color = LxPalette.PAL["blue"] as Color
	var c_star: Color = LxPalette.PAL["ice"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var pulse: float = 0.5 + 0.5 * sin(clock * 0.9 + fi * 1.7)
		if pulse < 0.30:
			continue
		var a: float = (pulse - 0.30) * (0.28 if fred else 0.45)
		var x0: float = roundf(min_x + fposmod(fi * 91.0 + 34.0, VIEW_W - 40.0) + 20.0)
		var y0: float = roundf(min_y + fposmod(fi * 53.0 + 22.0, VIEW_H - 40.0) + 16.0)
		var p0 := Vector2(x0, y0)
		var p1 := Vector2(x0 + (14.0 if i % 2 == 0 else -12.0), y0 + 8.0)
		var p2 := Vector2(x0 + (6.0 if i % 2 == 0 else -20.0), y0 + 18.0)
		ci.draw_line(p0, p1, Color(c_line, a), 1.0)
		ci.draw_line(p1, p2, Color(c_line, a * 0.85), 1.0)
		for sp: Vector2 in [p0, p1, p2]:
			ci.draw_rect(Rect2(sp, Vector2.ONE), Color(c_star, minf(1.0, a * 2.1)))


static func _draw_heat_ribbons(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_cor: Color = LxPalette.PAL["coral"] as Color
	var c_apr: Color = LxPalette.PAL["apricot"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var rx: float = min_x + fposmod(fi * 61.0 + 24.0, VIEW_W)
		var ry: float = min_y + fposmod(fi * 37.0 - clock * (14.0 + float(i % 3) * 4.0), VIEW_H)
		var wob: float = roundf(sin(clock * 4.5 + fi * 1.9) * 2.0)
		var p := Vector2(roundf(rx + wob), roundf(ry))
		var a: float = 0.42 if fred else 0.65
		ci.draw_rect(Rect2(p, Vector2(1.0, 2.0)), Color(c_apr, a))
		ci.draw_rect(Rect2(p + Vector2(-wob * 0.5, 2.0).round(), Vector2(1.0, 2.0)), Color(c_cor, a * 0.72))


static func _draw_prism_glints(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_ice: Color = LxPalette.PAL["ice"] as Color
	var c_crm: Color = LxPalette.PAL["cream"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var tw: float = maxf(0.0, sin(clock * (1.7 + float(i % 3) * 0.4) + fi * 2.3))
		if tw < 0.45:
			continue
		var gx: float = roundf(min_x + fposmod(fi * 67.0 + clock * 4.0, VIEW_W))
		var gy: float = roundf(min_y + fposmod(fi * 43.0 + sin(clock + fi) * 5.0, VIEW_H))
		var p := Vector2(gx, gy)
		var a: float = (tw - 0.45) * (0.95 if fred else 1.55)
		ci.draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), Color(c_ice, a * 0.75))
		ci.draw_rect(Rect2(p + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), Color(c_ice, a * 0.75))
		ci.draw_rect(Rect2(p, Vector2.ONE), Color(c_crm, minf(1.0, a)))


static func _draw_eclipse_wisps(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_pl: Color = LxPalette.PAL["plum"] as Color
	var c_mv: Color = LxPalette.PAL["mauve"] as Color
	var c_gd: Color = LxPalette.PAL["gold"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var wx: float = roundf(min_x + fposmod(fi * 71.0 - clock * (5.5 + float(i % 2) * 2.5), VIEW_W))
		var wy: float = roundf(min_y + fposmod(fi * 49.0 + sin(clock * 1.3 + fi) * 7.0, VIEW_H))
		var p := Vector2(wx, wy)
		var a: float = 0.48 if fred else 0.70
		ci.draw_rect(Rect2(p + Vector2(2.0, 0.0), Vector2(3.0, 1.0)), Color(c_pl, a * 0.65))
		ci.draw_rect(Rect2(p + Vector2(1.0, 0.0), Vector2(2.0, 1.0)), Color(c_mv, a * 0.85))
		if i % 2 == 0:
			ci.draw_rect(Rect2(p, Vector2.ONE), Color(c_gd, a))


static func _draw_belfry_incense(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_gd: Color = LxPalette.PAL["gold"] as Color
	var c_ap: Color = LxPalette.PAL["apricot"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var ix: float = min_x + fposmod(fi * 73.0 + sin(clock * 0.7 + fi * 1.4) * 9.0, VIEW_W)
		var iy: float = min_y + fposmod(fi * 47.0 - clock * (4.5 + float(i % 2) * 1.8), VIEW_H)
		var p := Vector2(roundf(ix), roundf(iy))
		var a: float = 0.34 if fred else (0.28 + 0.22 * absf(sin(clock * 1.3 + fi)))
		ci.draw_rect(Rect2(p, Vector2(1.0, 2.0)), Color(c_ap, a))
		ci.draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2.ONE), Color(c_gd, a + 0.20))


static func _draw_mist_beads(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_sk: Color = LxPalette.PAL["sky"] as Color
	var c_ic: Color = LxPalette.PAL["ice"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var mx: float = min_x + fposmod(fi * 59.0 + clock * (8.0 + float(i % 3) * 2.5), VIEW_W)
		var my: float = min_y + fposmod(fi * 41.0 + sin(clock * 0.9 + fi) * 5.0, VIEW_H)
		var p := Vector2(roundf(mx), roundf(my))
		var a: float = 0.32 if fred else 0.44
		ci.draw_rect(Rect2(p, Vector2(2.0, 1.0)), Color(c_sk, a))
		if i % 2 == 0:
			ci.draw_rect(Rect2(p, Vector2.ONE), Color(c_ic, a + 0.16))


static func _draw_glasshouse_drips(ci: CanvasItem, clock: float, min_x: float, min_y: float, count: int, fred: bool) -> void:
	var c_sk: Color = LxPalette.PAL["sky"] as Color
	var c_ic: Color = LxPalette.PAL["ice"] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var per: float = 1.6 + float(i % 3) * 0.45
		var ph: float = fposmod(clock + fi * 0.63, per)
		var slot: float = floorf((clock + fi * 0.63) / per)
		var u: float = ph / per
		var dx: float = roundf(min_x + fposmod(slot * 67.0 + fi * 53.0 + 18.0, VIEW_W - 36.0) + 18.0)
		var base_y: float = roundf(min_y + fposmod(slot * 43.0 + fi * 31.0 + 28.0, VIEW_H - 44.0) + 28.0)
		var a: float = 0.42 if fred else 0.62
		if u < 0.35:
			var fy: float = roundf(base_y - (1.0 - u / 0.35) * 22.0)
			ci.draw_rect(Rect2(dx, fy, 1.0, 2.0), Color(c_ic, a))
		elif u < 0.62:
			var r: float = roundf(1.0 + ((u - 0.35) / 0.27) * 3.0)
			var ra: float = (1.0 - (u - 0.35) / 0.27) * a
			ci.draw_rect(Rect2(dx - r, base_y, 1.0, 1.0), Color(c_sk, ra))
			ci.draw_rect(Rect2(dx + r, base_y, 1.0, 1.0), Color(c_sk, ra))
			ci.draw_rect(Rect2(dx, base_y, 1.0, 1.0), Color(c_ic, ra * 0.7))


static func _draw_relit_celebration(ci: CanvasItem, island_id: int, clock: float, min_x: float, min_y: float, fred: bool) -> void:
	# Each island awakens with its own signature celebratory relit wildlife!
	var wing_col: String = "gold"
	var body_col: String = "cream"
	var count: int = 3
	match island_id:
		2: # Tidewater Harbor: sunlit golden sea-swallows
			wing_col = "ice"
			body_col = "gold"
			count = 4
		3: # Thornwood Hollow: luminous emerald-lime forest butterflies
			wing_col = "lime"
			body_col = "cream"
			count = 4
		4: # Mirefen Gardens: iridescent rose-ice glasshouse dragonflies
			wing_col = "rose"
			body_col = "ice"
			count = 4
		5: # Starfall Observatory: radiant golden starlight wisps
			wing_col = "gold"
			body_col = "sky"
			count = 4
		6: # Ashen Kiln: warm hearth blossom embers
			wing_col = "apricot"
			body_col = "cream"
			count = 4
		7: # Moon Shoals: silver crystal lunar moths
			wing_col = "ice"
			body_col = "cream"
			count = 4
		8: # The Long Night: ascending golden dawn butterflies
			wing_col = "gold"
			body_col = "cream"
			count = 5
	var c_w: Color = LxPalette.PAL[wing_col] as Color
	var c_b: Color = LxPalette.PAL[body_col] as Color
	for i: int in range(count):
		var fi: float = float(i)
		var dir_x: float = 1.0 if i % 2 == 0 else -1.0
		var mx: float = min_x + fposmod(fi * 97.0 + clock * (14.0 + float(i % 2) * 4.0) * dir_x, VIEW_W)
		var my: float = min_y + fposmod(28.0 + fi * 44.0 + sin(clock * 2.4 + fi * 2.5) * 12.0, VIEW_H - 24.0)
		var p := Vector2(roundf(mx), roundf(my))
		var flap: float = 0.0 if (fred or sin(clock * 9.0 + fi * 1.7) > 0.0) else -1.0
		ci.draw_rect(Rect2(p, Vector2.ONE), c_b)
		ci.draw_rect(Rect2(p + Vector2(-1.0, flap), Vector2.ONE), c_w)
		ci.draw_rect(Rect2(p + Vector2(1.0, flap), Vector2.ONE), c_w)
		if island_id == 4 or island_id == 7:
			ci.draw_rect(Rect2(p + Vector2(-2.0, flap), Vector2.ONE), Color(c_b, 0.72))
			ci.draw_rect(Rect2(p + Vector2(2.0, flap), Vector2.ONE), Color(c_b, 0.72))
