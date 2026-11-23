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
		2: # Tidewater Harbor: wide 4-islet sea-stack archipelago bridged across tide channels
			_px(canvas, c, [[-11, 2, 22, 2]], water)
			_px(canvas, c, [[-10, 1, 4, 2], [-4, 1, 4, 2], [2, 1, 4, 2], [7, 1, 4, 2]], night)
			_px(canvas, c, [[-10, -1, 4, 2], [-4, -1, 4, 2], [2, -1, 4, 2], [7, -1, 4, 2]], top_col)
			_px(canvas, c, [[-6, 0, 2, 1], [0, 0, 2, 1], [6, 0, 1, 1]], gold if relit else dusk)
		3: # Thornwood Hollow: tall vertical 3-tier root massif climb
			_px(canvas, c, [[-5, 2, 10, 3], [-4, 5, 8, 1]], night)
			_px(canvas, c, [[-6, -1, 12, 3]], rim_col)
			_px(canvas, c, [[-5, -3, 10, 3]], top_col)
		4: # Mirefen Gardens: circular floating botanical lagoon ring atoll
			_px(canvas, c, [[-8, 1, 16, 3], [-6, 4, 12, 1]], night)
			_px(canvas, c, [[-8, -1, 16, 2]], rim_col)
			_px(canvas, c, [[-7, -2, 14, 2]], top_col)
			_px(canvas, c, [[-4, -1, 8, 2]], water)
			_px(canvas, c, [[-2, -1, 4, 1]], sky)
		5: # Starfall Observatory: circular brass Astrolabe Wheel w/ 4 cardinal spokes
			_px(canvas, c, [[-7, 1, 14, 2], [-4, 3, 8, 2]], night)
			_px(canvas, c, [[-8, -1, 16, 2]], rim_col)
			_px(canvas, c, [[-6, -2, 12, 2]], top_col)
			_px(canvas, c, [[-7, -1, 14, 1], [-1, -2, 2, 4]], gold)
		6: # Ashen Kiln: jagged obsidian canyon split by glowing molten lava river
			_px(canvas, c, [[-10, 1, 20, 3], [-7, 4, 14, 1]], night)
			_px(canvas, c, [[-10, -1, 8, 2], [2, -1, 8, 2]], rim_col)
			_px(canvas, c, [[-9, -2, 7, 2], [2, -2, 7, 2]], top_col)
			_px(canvas, c, [[-2, -1, 4, 3]], lava)
			_px(canvas, c, [[-1, -1, 2, 2]], gold)
		7: # Moon Shoals: twin silver crescent sandbars cradling a mirror lake
			_px(canvas, c, [[-9, 1, 18, 2], [-6, 3, 12, 1]], water)
			_px(canvas, c, [[-9, -2, 5, 3], [4, -2, 5, 3]], rim_col)
			_px(canvas, c, [[-8, -2, 4, 2], [4, -2, 4, 2]], top_col)
			_px(canvas, c, [[-3, -1, 6, 2]], sky)
		8: # The Long Night: towering 5-tier vertical Gothic eclipse pilgrimage causeway
			_px(canvas, c, [[-4, 2, 8, 4], [-2, 6, 4, 1]], night)
			_px(canvas, c, [[-5, -1, 10, 3]], rim_col)
			_px(canvas, c, [[-4, -3, 8, 3]], top_col)
			_px(canvas, c, [[-1, -2, 2, 5]], gold if relit else dusk)
	if relit:
		var glow_c: Color = LxBiomePalette.col(isl_id, "glow")
		match isl_id:
			2:
				_px(canvas, c, [[-9, -1, 3, 1], [-3, -1, 3, 1], [3, -1, 3, 1], [8, -1, 2, 1]], glow_c)
				_px(canvas, c, [[-8, 3, 16, 1]], sky)
			4:
				_px(canvas, c, [[-6, -2, 12, 1]], glow_c)
				_px(canvas, c, [[-3, -1, 6, 1]], LxPalette.PAL["ice"] as Color)
			6:
				_px(canvas, c, [[-8, -2, 5, 1], [3, -2, 5, 1]], gold)
				_px(canvas, c, [[-1, 0, 2, 2]], LxPalette.PAL["cream"] as Color)
			7:
				_px(canvas, c, [[-8, -2, 4, 1], [4, -2, 4, 1]], LxPalette.PAL["ice"] as Color)
				_px(canvas, c, [[-2, 0, 4, 1]], LxPalette.PAL["cream"] as Color)
			8:
				_px(canvas, c, [[-3, -3, 6, 1], [-1, -2, 2, 5]], gold)
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


static func _draw_island_atmosphere(canvas: CanvasItem, c: Vector2, isl_id: int, relit: bool, elapsed: float) -> void:
	# Living miniature biome weather/landmark accents right on each explored Sky-Chart island
	var fred: bool = LxHudFx.flash_reduced()
	var t: float = 0.0 if fred else elapsed
	match isl_id:
		1: # Warm brass bell-chime shimmer rising off Bell Isle
			var u1: float = fposmod(t * 0.65, 1.0)
			canvas.draw_rect(Rect2(roundf(c.x + sin(t * 2.0) * 3.0), roundf(c.y - 10.0 - u1 * 4.0), 1.0, 1.0), LxPalette.PAL["gold" if relit else "apricot"] as Color)
		2: # Animated coastal sea-foam beneath the 4 sea-stack islets + sweeping lighthouse glint
			var fx: float = roundf(c.x - 9.0 + fposmod(t * 7.0, 18.0))
			canvas.draw_rect(Rect2(fx, roundf(c.y + 3.0), 2.0, 1.0), LxPalette.PAL["ice"] as Color)
			if not fred and sin(t * 2.2) > 0.2:
				canvas.draw_line((c + Vector2(2.0, -10.0)).round(), (c + Vector2(9.0, -11.0)).round(), Color(LxPalette.PAL["gold"] as Color, 0.55), 1.0)
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
