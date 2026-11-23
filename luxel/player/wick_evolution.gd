class_name LxWickEvolution
extends RefCounted
## Living 8-Island Progression Evolution on Wick & Wick's Thrown Lantern:
## As Wick relights each island's Great Lamp (Islands 1..8), their lantern gathers a subtle
## constellation of light & visual signatures from every saved island.
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL); Flash-Reduction safe.

const PAL: Dictionary = LxPalette.PAL


static func draw_wick_evolution(wick: LxWick, hand_pos: Vector2, clock_t: float, flash_red: bool) -> void:
	if wick == null or wick.dead or Lx.state == null or Lx.state.relit_islands.is_empty():
		return
	var relit: Array = Lx.state.relit_islands
	var t: float = clock_t * (0.45 if flash_red else 1.0)
	var lan_in_hand: bool = wick.lantern == null or wick.lantern.is_in_hand()
	var center := Vector2(0.0, -7.0)

	# Island 1 (Bell Isle): warm brass chime glint beside the held lantern
	if lan_in_hand and relit.has(1):
		var a1: float = 0.55 if flash_red else (0.45 + 0.30 * sin(t * 2.4))
		wick.draw_rect(Rect2((hand_pos + Vector2(0.0, -4.0)).round(), Vector2.ONE), Color(PAL["gold"] as Color, a1))

	# Island 2 (Tidewater Harbor): crisp sea-ice Fresnel prism rim on held lantern
	if lan_in_hand and relit.has(2):
		var a2: float = 0.42 if flash_red else (0.35 + 0.25 * sin(t * 2.8 + 1.1))
		wick.draw_rect(Rect2((hand_pos + Vector2(-3.0, -1.0)).round(), Vector2.ONE), Color(PAL["ice"] as Color, a2))
		wick.draw_rect(Rect2((hand_pos + Vector2(3.0, -1.0)).round(), Vector2.ONE), Color(PAL["ice"] as Color, a2))

	# Island 3 (Thornwood Hollow): gentle rising emerald-lime Heartwood dew mote near cloak shoulder
	if relit.has(3):
		var u3: float = fposmod(t * 0.48, 1.0)
		var p3 := Vector2(roundf(-5.0 + sin(t * 2.0) * 1.5), roundf(-4.0 - u3 * 8.0))
		wick.draw_rect(Rect2(p3, Vector2.ONE), Color(PAL["lime"] as Color, sin(u3 * PI) * (0.55 if flash_red else 0.78)))

	# Island 4 (Mirefen Gardens): rose-and-ice stained-glass feather shimmer while gliding
	if relit.has(4) and wick.is_gliding():
		var fl: float = 0.0 if flash_red else roundf(sin(t * 9.0))
		wick.draw_rect(Rect2(Vector2(-7.0, -7.0 + fl), Vector2(2.0, 1.0)), Color(PAL["rose"] as Color, 0.72))
		wick.draw_rect(Rect2(Vector2(5.0, -7.0 - fl), Vector2(2.0, 1.0)), Color(PAL["ice"] as Color, 0.72))

	# Island 5 (Starfall Observatory): faithful tiny golden astrolabe starlet orbiting the lantern
	if lan_in_hand and relit.has(5):
		var a5: float = t * 2.2
		var p5: Vector2 = (hand_pos + Vector2(cos(a5) * 6.5, sin(a5) * 3.5)).round()
		wick.draw_rect(Rect2(p5, Vector2.ONE), Color(PAL["gold"] as Color, 0.80))

	# Island 6 (Ashen Kiln): blazing solar coral-gold ember crown on muzzle flash
	if relit.has(6) and wick.muzzle_t > 0.0:
		wick.draw_arc(hand_pos.round(), 5.5, 0.0, TAU, 10, Color(PAL["coral"] as Color, 0.55 if flash_red else 0.80), 1.0)

	# Island 7 (Moon Shoals): serene pale silver crescent shimmer above Wick's shoulders
	if relit.has(7):
		wick.draw_arc(center + Vector2(0.0, -5.0), 6.0, PI * 1.2, PI * 1.8, 6, Color(PAL["ice"] as Color, 0.42 if flash_red else 0.62), 1.0)

	# 8/8 True Dawn Mastery: peaceful twinkling 8-island dawn crown around Wick
	if relit.size() >= 8:
		var a8: float = t * 1.1
		for k: int in range(4):
			var ang: float = a8 + float(k) * (PI * 0.5)
			var sp: Vector2 = (center + Vector2(cos(ang) * 9.5, sin(ang) * 4.5 - 3.0)).round()
			wick.draw_rect(Rect2(sp, Vector2.ONE), Color((PAL["cream"] if k % 2 == 0 else PAL["gold"]) as Color, 0.68 if flash_red else 0.88))


static func draw_lantern_constellation(lantern: CanvasItem, center: Vector2, anim_t: float, flash_red: bool) -> void:
	# Every saved island lends a tiny 1px star in its biome's signature glow orbiting Wick's thrown lantern!
	if lantern == null or Lx.state == null or Lx.state.relit_islands.is_empty():
		return
	var relit: Array = Lx.state.relit_islands
	var n: int = mini(relit.size(), 8)
	var spin: float = anim_t * (0.45 if flash_red else 1.05)
	var rx: float = 11.5 if n >= 5 else 9.5
	var ry: float = 5.5 if n >= 5 else 4.5
	for i: int in range(n):
		var iid: int = clampi(int(relit[i]), 1, 8)
		var ang: float = spin + float(i) * (TAU / float(n))
		var pt: Vector2 = (center + Vector2(cos(ang) * rx, sin(ang) * ry - 1.0)).round()
		var col: Color = LxBiomePalette.col(iid, "glow")
		var a: float = (0.58 if flash_red else 0.85) * (0.65 + 0.35 * sin(ang))
		lantern.draw_rect(Rect2(pt, Vector2.ONE), Color(col, a))
		if n >= 8 and i % 2 == 0:
			lantern.draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2.ONE), Color(PAL["cream"] as Color, a * 0.55))
