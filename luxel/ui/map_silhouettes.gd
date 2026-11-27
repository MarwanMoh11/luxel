class_name LxMapSilhouettes
extends RefCounted
## Draws each island's true reshaped geographical silhouette on the Archipelago Sky-Chart
## using strictly the 20 opaque Last Light colours (LxPalette.PAL).


static func draw_plinth(canvas: CanvasItem, c: Vector2, isl_id: int, relit: bool, top_col: Color, rim_col: Color, elapsed: float = 0.0) -> void:
	var night: Color = LxPalette.PAL["night"] as Color
	var dusk: Color = LxPalette.PAL["dusk"] as Color
	var gold: Color = LxPalette.PAL["gold"] as Color
	var water: Color = LxPalette.PAL["deep"] as Color
	var sky: Color = LxPalette.PAL["sky"] as Color
	var lava: Color = LxPalette.PAL["coral"] as Color
	match isl_id:
		1: # Bell Isle: classic rounded cliff terrace
			_px(canvas, c, [[-7, 1, 14, 2], [-5, 3, 10, 1], [-3, 4, 6, 1]], night)
			_px(canvas, c, [[-7, -1, 14, 2]], rim_col)
			_px(canvas, c, [[-6, -2, 12, 2]], top_col)
		2: # Tidewater Harbor: curved horseshoe cove wrapping a choppy sea bay + eastern lighthouse headland
			_px(canvas, c, [[-9, 1, 18, 3], [-6, 4, 12, 1]], water)
			_px(canvas, c, [[-10, -1, 4, 4], [-8, -3, 14, 2], [5, -2, 5, 4], [2, 2, 6, 2], [-4, 3, 6, 1]], night)
			_px(canvas, c, [[-10, -2, 4, 3], [-8, -4, 14, 2], [5, -3, 5, 4], [2, 1, 6, 2], [-4, 2, 6, 1]], top_col)
			_px(canvas, c, [[-5, -1, 9, 3]], water)
			_px(canvas, c, [[-3, 0, 5, 1]], sky)
			_px(canvas, c, [[7, -4, 2, 2]], gold if relit else dusk)
		3: # Thornwood Hollow: Coiling Root Spiral ascending into the Hollow Oak
			_px(canvas, c, [[-9, 2, 16, 2], [-7, 4, 12, 1], [-4, 5, 7, 1]], night)
			_px(canvas, c, [[-10, 0, 5, 2], [-8, 1, 14, 2], [5, -2, 5, 3], [-5, -3, 11, 2]], rim_col)
			_px(canvas, c, [[-9, -1, 4, 2], [-6, 1, 11, 1], [6, -2, 3, 3], [-4, -3, 10, 1], [-4, -2, 3, 2], [-1, -1, 5, 1]], top_col)
			_px(canvas, c, [[-5, 0, 4, 1], [3, -1, 2, 2]], night)
		4: # Mirefen Gardens: Winding Lily Archipelago (4 staggered lily-pad islets)
			_px(canvas, c, [[-10, 0, 20, 4], [-7, 4, 14, 1], [-6, -2, 12, 2]], water)
			_px(canvas, c, [[-10, 1, 5, 2], [-5, -2, 5, 2], [1, 0, 5, 2], [5, -3, 5, 2]], rim_col)
			_px(canvas, c, [[-9, 0, 4, 2], [-4, -3, 4, 2], [2, -1, 4, 2], [6, -4, 4, 2]], top_col)
			_px(canvas, c, [[-5, 0, 2, 1], [0, -1, 2, 1], [5, -2, 2, 1]], gold if relit else dusk)
			_px(canvas, c, [[-2, 2, 4, 1], [-8, -2, 2, 1], [7, 2, 2, 1]], sky)
		5: # Starfall Observatory: Shattered Crescent Orbital Arcs around starlight core
			_px(canvas, c, [[-10, 1, 5, 2], [-5, 3, 10, 2], [6, 0, 4, 2]], night)
			_px(canvas, c, [[-10, -2, 3, 3], [-8, 1, 5, 2], [7, -3, 3, 3], [4, 1, 5, 2], [-3, -4, 6, 1]], rim_col)
			_px(canvas, c, [[-9, -2, 2, 2], [-7, 1, 4, 1], [7, -3, 2, 2], [4, 1, 4, 1], [-2, -4, 4, 1], [-2, -1, 4, 2]], top_col)
			_px(canvas, c, [[-6, -2, 3, 1], [3, -2, 3, 1], [-2, 2, 5, 1]], gold)
		6: # Ashen Kiln: Jagged Horseshoe Caldera cradling a glowing molten breach
			_px(canvas, c, [[-10, 0, 5, 4], [5, 0, 5, 4], [-7, 3, 5, 2], [2, 3, 5, 2], [-8, -2, 16, 2]], night)
			_px(canvas, c, [[-10, -2, 4, 4], [-7, -4, 14, 2], [6, -2, 4, 4], [-8, 2, 4, 2], [4, 2, 4, 2]], rim_col)
			_px(canvas, c, [[-9, -2, 3, 3], [-6, -4, 12, 2], [6, -2, 3, 3], [-7, 1, 3, 2], [4, 1, 3, 2]], top_col)
			_px(canvas, c, [[-5, -1, 10, 3], [-3, 2, 6, 2], [-2, 4, 4, 1]], lava)
			_px(canvas, c, [[-3, 0, 6, 1], [-1, 1, 2, 2]], gold)
		7: # Moon Shoals: Offset Yin-Yang Twin Crescents cradling staggered mirror pools
			_px(canvas, c, [[-10, -1, 20, 4], [-7, 3, 14, 2]], water)
			_px(canvas, c, [[-10, -3, 7, 2], [-10, -1, 4, 3], [-7, 1, 3, 2], [3, 1, 7, 2], [6, -2, 4, 3], [4, -3, 3, 2]], rim_col)
			_px(canvas, c, [[-9, -3, 6, 1], [-9, -2, 3, 3], [-7, 1, 2, 1], [4, 1, 5, 1], [7, -2, 2, 3], [5, -3, 2, 1]], top_col)
			_px(canvas, c, [[-5, -1, 4, 2], [1, 0, 4, 2]], sky)
		8: # The Long Night: Fractured Cathedral Shards tethered across the eclipse void
			_px(canvas, c, [[-9, 3, 5, 2], [-2, 4, 5, 2], [4, 1, 5, 2], [-7, -1, 5, 2], [-2, -3, 6, 2]], night)
			_px(canvas, c, [[-9, 1, 5, 2], [-2, 2, 5, 2], [4, -1, 5, 2], [-7, -2, 5, 1], [-3, -4, 7, 2]], rim_col)
			_px(canvas, c, [[-8, 1, 4, 1], [-1, 2, 3, 1], [5, -1, 3, 1], [-6, -2, 4, 1], [-2, -4, 5, 1]], top_col)
			_px(canvas, c, [[-4, 2, 2, 1], [2, 1, 2, 1], [-3, -1, 2, 1], [2, -2, 2, 1]], gold if relit else dusk)
	if relit:
		var glow_c: Color = LxBiomePalette.col(isl_id, "glow")
		match isl_id:
			2:
				_px(canvas, c, [[-9, -2, 3, 1], [-7, -4, 12, 1], [6, -3, 3, 1], [3, 1, 4, 1], [-3, 2, 4, 1]], glow_c)
				_px(canvas, c, [[-4, 0, 7, 1]], LxPalette.PAL["ice"] as Color)
			3:
				_px(canvas, c, [[-8, -1, 3, 1], [-5, 1, 9, 1], [6, -1, 2, 2], [-3, -3, 8, 1]], glow_c)
				_px(canvas, c, [[-1, -1, 3, 1]], gold)
			4:
				_px(canvas, c, [[-9, 0, 3, 1], [-4, -3, 3, 1], [2, -1, 3, 1], [6, -4, 3, 1]], glow_c)
				_px(canvas, c, [[-3, 2, 5, 1], [6, 1, 3, 1]], LxPalette.PAL["ice"] as Color)
			5:
				_px(canvas, c, [[-9, -2, 2, 1], [7, -3, 2, 1], [-2, -1, 4, 1]], glow_c)
				_px(canvas, c, [[-6, -2, 3, 1], [3, -2, 3, 1], [-2, 2, 5, 1]], LxPalette.PAL["cream"] as Color)
			6:
				_px(canvas, c, [[-8, -2, 2, 1], [-5, -4, 10, 1], [6, -2, 2, 1]], gold)
				_px(canvas, c, [[-2, 0, 4, 1], [-1, 1, 2, 2]], LxPalette.PAL["cream"] as Color)
			7:
				_px(canvas, c, [[-9, -3, 5, 1], [4, 1, 5, 1]], LxPalette.PAL["ice"] as Color)
				_px(canvas, c, [[-4, -1, 2, 1], [2, 0, 2, 1]], LxPalette.PAL["cream"] as Color)
			8:
				_px(canvas, c, [[-2, -4, 5, 1], [-4, 2, 2, 1], [2, 1, 2, 1], [-3, -1, 2, 1], [2, -2, 2, 1]], gold)
				_px(canvas, c, [[-7, 1, 2, 1], [6, -1, 2, 1], [0, -4, 2, 1]], LxPalette.PAL["cream"] as Color)
			_:
				_px(canvas, c, [[-5, -2, 10, 1]], glow_c)
				canvas.draw_rect(Rect2(roundf(c.x - 3.0), roundf(c.y - 2.0), 4.0, 1.0), gold)
	# Golden Harmony Star on the Sky-Chart once all overworld chimes/discoveries on this island are awakened
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_id, false)):
		var star_c: Vector2 = (c + Vector2(8.0, 5.0)).round()
		canvas.draw_rect(Rect2(star_c + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), LxPalette.PAL["void"] as Color)
		canvas.draw_rect(Rect2(star_c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), LxBiomePalette.col(isl_id, "glow"))
		canvas.draw_rect(Rect2(star_c + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), LxBiomePalette.col(isl_id, "glow"))
		canvas.draw_rect(Rect2(star_c, Vector2.ONE), LxPalette.PAL["cream"] as Color)
	_draw_island_atmosphere(canvas, c, isl_id, relit, elapsed)
	# Subtle breathing compass halo around the island where Wick currently stands
	if Lx.state != null and Lx.state.island_id == isl_id:
		var fred_c: bool = LxHudFx.flash_reduced()
		var ca_c: float = 0.34 if fred_c else (0.28 + 0.16 * sin(elapsed * 2.6))
		var cr_c: float = 13.0 if isl_id >= 2 else 11.0
		canvas.draw_arc(c.round(), cr_c, 0.0, TAU, 16, Color(LxBiomePalette.col(isl_id, "glow"), ca_c), 1.0)


static func _draw_island_atmosphere(canvas: CanvasItem, c: Vector2, isl_id: int, relit: bool, elapsed: float) -> void:
	# Living miniature biome weather/landmark accents right on each explored Sky-Chart island
	var fred: bool = LxHudFx.flash_reduced()
	var t: float = 0.0 if fred else elapsed
	match isl_id:
		1: # Warm brass bell-chime shimmer rising off Bell Isle
			var u1: float = fposmod(t * 0.65, 1.0)
			canvas.draw_rect(Rect2(roundf(c.x + sin(t * 2.0) * 3.0), roundf(c.y - 10.0 - u1 * 4.0), 1.0, 1.0), LxPalette.PAL["gold" if relit else "apricot"] as Color)
		2: # Animated coastal sea-foam inside the horseshoe bay + sweeping lighthouse headland glint
			var fx: float = roundf(c.x - 5.0 + fposmod(t * 5.0, 10.0))
			canvas.draw_rect(Rect2(fx, roundf(c.y + 1.0), 2.0, 1.0), LxPalette.PAL["ice"] as Color)
			if not fred and sin(t * 2.2) > 0.2:
				canvas.draw_line((c + Vector2(8.0, -4.0)).round(), (c + Vector2(1.0, -7.0)).round(), Color(LxPalette.PAL["gold"] as Color, 0.55), 1.0)
		3: # Rising emerald-lime canopy fireflies framing the Hollow Oak
			for k: int in range(2):
				var u3: float = fposmod(t * 0.5 + float(k) * 0.5, 1.0)
				var px3: float = roundf(c.x + (-6.0 if k == 0 else 6.0) + sin(t * 2.2 + float(k) * 3.0) * 1.5)
				canvas.draw_rect(Rect2(px3, roundf(c.y - 5.0 - u3 * 7.0), 1.0, 1.0), LxPalette.PAL["lime" if k == 0 else "cream"] as Color)
		4: # Rose & ice stained-glass conservatory sparkles above the lagoon atoll
			var sh4: float = roundf(sin(t * 2.4) * 3.0)
			canvas.draw_rect(Rect2(roundf(c.x - 3.0 + sh4), roundf(c.y - 11.0), 1.0, 1.0), LxPalette.PAL["rose"] as Color)
			canvas.draw_rect(Rect2(roundf(c.x + 3.0 - sh4), roundf(c.y - 9.0), 1.0, 1.0), LxPalette.PAL["ice"] as Color)
		5: # Tiny orbiting golden planetoid circling the Astrolabe Wheel
			var ang5: float = t * 1.8
			var p5 := Vector2(roundf(c.x + cos(ang5) * 9.0), roundf(c.y - 6.0 + sin(ang5) * 3.0))
			canvas.draw_rect(Rect2(p5, Vector2.ONE), LxPalette.PAL["gold" if relit else "sky"] as Color)
		6: # Rising volcanic coral/gold embers above Ashen Kiln's lava split
			for k: int in range(2):
				var u6: float = fposmod(t * 0.75 + float(k) * 0.5, 1.0)
				var px6: float = roundf(c.x + sin(t * 3.0 + float(k) * 2.5) * 3.0)
				canvas.draw_rect(Rect2(px6, roundf(c.y - 6.0 - u6 * 7.0), 1.0, 1.0), LxPalette.PAL["gold" if (relit or k == 0) else "coral"] as Color)
		7: # Shimmering silver lunar aurora arc above the twin Moon Shoals sandbars
			var ay7: float = roundf(c.y - 12.0 + sin(t * 1.6))
			canvas.draw_line(Vector2(roundf(c.x - 6.0), ay7), Vector2(roundf(c.x + 6.0), ay7), Color(LxPalette.PAL["gold" if relit else "ice"] as Color, 0.70), 1.0)
		8: # Eclipsed plum-rose ring transforming into a radiant golden dawn crown once relit
			var rc8: Color = (LxPalette.PAL["gold"] if relit else LxPalette.PAL["rose"]) as Color
			canvas.draw_arc((c + Vector2(0.0, -7.0)).round(), 7.0, 0.0, TAU, 12, Color(rc8, 0.55 if fred else 0.75), 1.0)
			if relit:
				canvas.draw_rect(Rect2((c + Vector2(0.0, -15.0)).round(), Vector2.ONE), LxPalette.PAL["cream"] as Color)


static func _px(canvas: CanvasItem, c: Vector2, rects: Array, col: Color) -> void:
	for r: Array in rects:
		canvas.draw_rect(Rect2(roundf(c.x + float(r[0])), roundf(c.y + float(r[1])), float(r[2]), float(r[3])), col)


static func draw_chart_backdrop(canvas: CanvasItem, chart: Rect2, elapsed: float) -> void:
	LxPixelFont.draw_panel(canvas, chart, "night", "dusk", "void")
	for corner: Vector2 in [chart.position + Vector2(1.0, 1.0), Vector2(chart.end.x - 3.0, chart.position.y + 1.0), Vector2(chart.position.x + 1.0, chart.end.y - 3.0), chart.end - Vector2(3.0, 3.0)]:
		canvas.draw_rect(Rect2(corner, Vector2(2.0, 2.0)), LxPalette.PAL["gold"])
	canvas.draw_rect(Rect2(22.0, 28.0, 276.0, 14.0), LxPalette.PAL["void"])
	canvas.draw_rect(Rect2(22.0, 74.0, 276.0, 16.0), LxPalette.PAL["deep"])
	var dx: float = 22.0
	while dx < 296.0:
		canvas.draw_rect(Rect2(dx, 42.0, 2.0, 1.0), LxPalette.PAL["void"])
		canvas.draw_rect(Rect2(dx + 2.0, 73.0, 2.0, 1.0), LxPalette.PAL["deep"])
		dx += 6.0
	var dusk: Color = LxPalette.PAL["dusk"]
	var gx: float = 36.0
	while gx <= 284.0:
		canvas.draw_rect(Rect2(gx, 28.0, 1.0, 2.0), dusk)
		canvas.draw_rect(Rect2(gx, 88.0, 1.0, 2.0), dusk)
		gx += 16.0
	for gy: float in [38.0, 50.0, 62.0, 74.0]:
		canvas.draw_rect(Rect2(22.0, gy, 2.0, 1.0), dusk)
		canvas.draw_rect(Rect2(296.0, gy, 2.0, 1.0), dusk)
	for mx: float in [60.0, 124.0, 188.0, 252.0]:
		for my: float in [44.0, 66.0]:
			canvas.draw_rect(Rect2(mx - 1.0, my, 3.0, 1.0), dusk)
			canvas.draw_rect(Rect2(mx, my - 1.0, 1.0, 3.0), dusk)
	var fred: bool = LxHudFx.flash_reduced()
	var t: float = 0.0 if fred else elapsed
	for s: int in range(18):
		var sx: float = 26.0 + float((s * 47 + 13) % 268)
		var sy: float = 30.0 + float((s * 19 + 5) % 44)
		if sx < 38.0 and sy > 70.0:
			continue
		var phase: float = fmod(t + float(s) * 0.41, 2.4 + float(s % 3) * 0.6)
		var scol: Color = (LxPalette.PAL["ice"] if s % 3 == 0 else LxPalette.PAL["stone"]) if phase < 0.45 else (LxPalette.PAL["mauve"] if s % 2 == 0 else dusk)
		canvas.draw_rect(Rect2(sx, sy, 1.0, 1.0), scol)
	for w: int in range(6):
		var wx: float = 54.0 + float(w) * 42.0 + (0.0 if fred else roundf(sin(elapsed * 0.8 + float(w)) * 2.0))
		var wy: float = 84.0 + float(w % 2) * 3.0
		canvas.draw_rect(Rect2(wx, wy, 5.0, 1.0), dusk)
	draw_compass_rose(canvas, Vector2(29.0, 82.0), elapsed)


static func draw_compass_rose(canvas: CanvasItem, c: Vector2, elapsed: float) -> void:
	var dusk: Color = LxPalette.PAL["dusk"]
	var apr: Color = LxPalette.PAL["apricot"]
	var gold: Color = LxPalette.PAL["gold"]
	var cream: Color = LxPalette.PAL["cream"]
	_px(canvas, c, [[-3, -2, 1, 1], [3, -2, 1, 1], [-3, 2, 1, 1], [3, 2, 1, 1], [-2, -3, 1, 1], [2, -3, 1, 1], [-2, 3, 1, 1], [2, 3, 1, 1], [-2, -2, 1, 1], [2, -2, 1, 1], [-2, 2, 1, 1], [2, 2, 1, 1]], dusk)
	_px(canvas, c, [[-1, -1, 1, 1], [1, -1, 1, 1], [-1, 1, 1, 1], [1, 1, 1, 1], [-4, 0, 9, 1], [0, 1, 1, 4]], apr)
	_px(canvas, c, [[-2, 0, 5, 1], [0, 1, 1, 2], [0, -4, 1, 4]], gold)
	canvas.draw_rect(Rect2(c.x, c.y - 5.0, 1.0, 2.0), cream if (LxHudFx.flash_reduced() or fmod(elapsed, 2.0) < 1.2) else gold)
	canvas.draw_rect(Rect2(c.x, c.y, 1.0, 1.0), cream)


static func draw_unexplored_island(canvas: CanvasItem, c: Vector2, isl_id: int, elapsed: float) -> void:
	_px(canvas, c, [[-6, -2, 12, 3], [-4, -4, 8, 2]], LxPalette.PAL["dusk"])
	_px(canvas, c, [[-2, -6, 4, 2], [-7, 0, 14, 2], [-5, 2, 10, 2], [-2, 4, 4, 1]], LxPalette.PAL["night"])
	var fred: bool = LxHudFx.flash_reduced()
	for k: int in range(3):
		var drift: float = 0.0 if fred else sin(elapsed * 1.1 + float(isl_id) + float(k) * 2.0) * 1.5
		var fx: float = roundf(c.x - 5.0 + float(k) * 5.0 + drift)
		canvas.draw_rect(Rect2(fx, roundf(c.y - 3.0 - float(k % 2) * 2.0), 1.0, 1.0), LxPalette.PAL["mauve"])


static func draw_island_landmark(canvas: CanvasItem, c: Vector2, isl_id: int, relit: bool, elapsed: float) -> void:
	match isl_id:
		1:
			_px(canvas, c, [[-2, -8, 5, 6]], LxPalette.PAL["stone"])
			_px(canvas, c, [[1, -8, 2, 6]], LxPalette.PAL["mauve"])
			_px(canvas, c, [[-1, -7, 3, 3], [-1, -11, 3, 1]], LxPalette.PAL["night"])
			_px(canvas, c, [[-3, -9, 7, 1], [-2, -10, 5, 1]], LxPalette.PAL["plum"])
			_px(canvas, c, [[0, -12, 1, 1]], LxPalette.PAL["gold"])
			_px(canvas, c, [[0, -6, 1, 2]], LxPalette.PAL["cream"] if relit else LxPalette.PAL["gold"])
		2:
			_px(canvas, c, [[-2, -8, 4, 6]], LxPalette.PAL["cream"])
			_px(canvas, c, [[-2, -7, 4, 1], [-2, -4, 4, 1]], LxPalette.PAL["coral"])
			_px(canvas, c, [[1, -8, 1, 6]], LxPalette.PAL["stone"])
			_px(canvas, c, [[-3, -9, 6, 1]], LxPalette.PAL["dusk"])
			_px(canvas, c, [[-1, -12, 2, 1]], LxPalette.PAL["night"])
			var lit: bool = LxHudFx.flash_reduced() or fmod(elapsed, 1.6) < 0.9
			_px(canvas, c, [[-1, -11, 2, 2]], LxPalette.PAL["cream"] if lit else LxPalette.PAL["gold"])
			if lit:
				_px(canvas, c, [[-3, -10, 1, 1], [2, -10, 1, 1]], LxPalette.PAL["gold"])
		3:
			_px(canvas, c, [[-2, -5, 4, 3]], LxPalette.PAL["dusk"])
			_px(canvas, c, [[0, -4, 1, 2]], LxPalette.PAL["apricot"])
			_px(canvas, c, [[-5, -8, 10, 3]], LxPalette.PAL["pine"])
			_px(canvas, c, [[-5, -9, 10, 2]], LxPalette.PAL["teal"])
			_px(canvas, c, [[-4, -10, 8, 2]], LxPalette.PAL["jade"])
			_px(canvas, c, [[-2, -11, 4, 1], [-4, -9, 2, 1]], LxPalette.PAL["lime"])
		4:
			_px(canvas, c, [[-5, -3, 10, 1]], LxPalette.PAL["mauve"])
			_px(canvas, c, [[-5, -6, 10, 3]], LxPalette.PAL["sky"])
			_px(canvas, c, [[-4, -8, 8, 2], [-2, -9, 4, 1]], LxPalette.PAL["ice"])
			_px(canvas, c, [[-2, -7, 1, 4], [2, -7, 1, 4]], LxPalette.PAL["blue"])
			_px(canvas, c, [[-3, -8, 2, 1], [0, -10, 1, 1]], LxPalette.PAL["cream"])
		5:
			_px(canvas, c, [[-4, -6, 8, 4]], LxPalette.PAL["blue"])
			_px(canvas, c, [[-3, -7, 6, 1]], LxPalette.PAL["sky"])
			_px(canvas, c, [[1, -6, 3, 4]], LxPalette.PAL["deep"])
			for d: int in range(-3, 4):
				canvas.draw_rect(Rect2(c.x + float(d), roundf(c.y - 8.0 - float(d) * 0.5), 1.0, 1.0), LxPalette.PAL["gold"])
				canvas.draw_rect(Rect2(c.x + float(d), roundf(c.y - 8.0 + float(d) * 0.5), 1.0, 1.0), LxPalette.PAL["apricot"])
			_px(canvas, c, [[0, -11, 1, 2]], LxPalette.PAL["cream"])
		6:
			_px(canvas, c, [[-3, -7, 6, 5]], LxPalette.PAL["dusk"])
			_px(canvas, c, [[-2, -9, 4, 2]], LxPalette.PAL["night"])
			_px(canvas, c, [[-3, -9, 6, 1]], LxPalette.PAL["wine"])
			_px(canvas, c, [[-1, -4, 2, 2]], LxPalette.PAL["apricot"] if (LxHudFx.flash_reduced() or fmod(elapsed * 2.2, 1.0) < 0.5) else LxPalette.PAL["coral"])
			_px(canvas, c, [[0, -3, 1, 1]], LxPalette.PAL["gold"])
			var puff: float = 0.0 if LxHudFx.flash_reduced() else floorf(fmod(elapsed * 2.5, 3.0))
			canvas.draw_rect(Rect2(roundf(c.x - 1.0 + puff * 0.5), roundf(c.y - 10.0 - puff), 1.0, 1.0), LxPalette.PAL["coral"])
			canvas.draw_rect(Rect2(roundf(c.x + 1.0), roundf(c.y - 11.0 - fmod(puff + 1.0, 3.0)), 1.0, 1.0), LxPalette.PAL["mauve"])
		7:
			_px(canvas, c, [[-3, -3, 6, 1]], LxPalette.PAL["blue"])
			_px(canvas, c, [[-1, -8, 2, 5], [1, -11, 1, 1]], LxPalette.PAL["sky"])
			_px(canvas, c, [[-1, -8, 1, 5], [-1, -9, 2, 1]], LxPalette.PAL["ice"])
			_px(canvas, c, [[-2, -11, 1, 3], [-1, -12, 2, 1]], LxPalette.PAL["cream"])
		8:
			_px(canvas, c, [[-5, -10, 2, 8], [3, -10, 2, 8]], LxPalette.PAL["plum"])
			_px(canvas, c, [[-5, -11, 1, 2], [4, -11, 1, 2], [-2, -10, 4, 4]], LxPalette.PAL["rose"])
			_px(canvas, c, [[-3, -5, 6, 3]], LxPalette.PAL["dusk"])
			_px(canvas, c, [[-1, -4, 2, 2]], LxPalette.PAL["night"])
			_px(canvas, c, [[-1, -10, 2, 1]], LxPalette.PAL["cream"])
			_px(canvas, c, [[-1, -9, 2, 2]], LxPalette.PAL["void"])
