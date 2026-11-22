class_name LxMapSilhouettes
extends RefCounted
## Draws each island's true reshaped geographical silhouette on the Archipelago Sky-Chart
## using strictly the 20 opaque Last Light colours (LxPalette.PAL).


static func draw_plinth(canvas: CanvasItem, c: Vector2, isl_id: int, relit: bool, top_col: Color, rim_col: Color) -> void:
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
		canvas.draw_rect(Rect2(roundf(c.x - 5.0), roundf(c.y - 2.0), 4.0, 1.0), gold)


static func _px(canvas: CanvasItem, c: Vector2, rects: Array, col: Color) -> void:
	for r: Array in rects:
		canvas.draw_rect(Rect2(roundf(c.x + float(r[0])), roundf(c.y + float(r[1])), float(r[2]), float(r[3])), col)
