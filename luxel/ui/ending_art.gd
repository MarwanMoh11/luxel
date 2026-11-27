class_name LxEndingArt
extends RefCounted
## Studio pixel-art renderer for Intro, Death, Dawn/Display-Off Endings, Results & Credits.
## Uses ONLY the 20 opaque Last Light colours in LxPalette.PAL.

const ICON_PAL: Dictionary = {
	"k": "void", "n": "night", "d": "dusk", "m": "mauve", "s": "stone",
	"w": "wine", "r": "coral", "a": "apricot", "g": "gold", "c": "cream",
	"b": "blue", "y": "sky", "i": "ice", "l": "lime", "p": "pine", "o": "rose",
}
const STAT_ICONS: Array[Array] = [
	["ggggg", ".ici.", "..c..", ".i.i.", "ggggg"], # Time: hourglass
	[".aaa.", "annna", "angna", "annna", "aaaaa"], # Dungeons: doorway
	["c.g.c", "cgggc", ".ggg.", "c.g.c", "..a.."], # Moths: moth
	[".sss.", "snsns", "ssrss", ".s.s.", "..m.."], # Deaths: fallen wick
]
const RIGHT_STAT_ICONS: Array[Array] = [
	["..c..", "g.g.g", "ggcgg", "ggggg", ".aaa."], # Clear %: crown
	[".rrr.", "rnrnr", "rrrrr", ".rgr.", ".r.r."], # Bosses: boss skull
	[".aga.", "aggga", "agcga", "aggga", ".ddd."], # Lamps relit: lantern
	["..g..", "ggggg", ".a.a.", "rr.rr", "..w.."], # Sold settings / tolls: scale
]
const RANK_STYLE: Dictionary = {
	"RANK_S": ["gold", "wine", "cream"], "RANK_A": ["lime", "pine", "gold"],
	"RANK_B": ["sky", "deep", "ice"], "RANK_C": ["apricot", "night", "coral"],
}
# 8 iconic archipelago landmarks: [base_col, base_rects, accent_col, accent_rects, lamp_dy]
const ISLAND_LANDMARKS: Array[Array] = [
	["night", [[-3, -12, 6, 8], [-4, -13, 8, 1], [-2, -15, 4, 2], [-1, -17, 2, 2]], "dusk", [[-1, -11, 2, 3]], -18.0], # 1 Bell Tower
	["night", [[-2, -12, 5, 8], [-3, -13, 7, 1], [-2, -16, 5, 3], [-1, -17, 3, 1]], "plum", [[-1, -15, 3, 2]], -18.0], # 2 Lighthouse
	["pine", [[-2, -9, 4, 5], [-7, -13, 14, 4], [-5, -16, 10, 3]], "night", [[-1, -8, 2, 4], [-5, -12, 10, 2]], -17.0], # 3 Hollow Oak
	["night", [[-6, -8, 12, 4], [-5, -11, 10, 3], [-3, -13, 6, 2]], "sky", [[-4, -9, 2, 3], [2, -9, 2, 3], [-1, -11, 2, 5]], -15.0], # 4 Glasshouse Dome
	["night", [[-5, -9, 10, 5], [-4, -12, 8, 3], [-2, -14, 4, 2]], "stone", [[2, -15, 2, 2], [3, -16, 2, 1]], -16.0], # 5 Orrery Dome
	["night", [[-5, -8, 10, 4], [-2, -15, 4, 7], [-3, -16, 6, 1]], "coral", [[-2, -7, 4, 2]], -18.0], # 6 Kiln Chimney
	["night", [[-3, -8, 6, 4], [-2, -13, 4, 5], [-1, -17, 2, 4]], "ice", [[0, -16, 1, 10], [-1, -11, 1, 5]], -19.0], # 7 Mirror Spire
	["night", [[-6, -13, 3, 9], [3, -13, 3, 9], [-4, -15, 8, 3], [-2, -17, 4, 2]], "dusk", [[-2, -11, 4, 5]], -19.0], # 8 Cathedral Arch
]

static func _px(ci: CanvasItem, rects: Array, col_key: String, ox: float = 0.0, oy: float = 0.0) -> void:
	var c: Color = LxPalette.PAL[col_key]
	for r: Array in rects:
		ci.draw_rect(Rect2(ox + float(r[0]), oy + float(r[1]), float(r[2]), float(r[3])), c)

static func _dither(ci: CanvasItem, x0: float, x1: float, y: float, col: Color, seed_k: int = 0) -> void:
	var x: float = x0
	var s: int = seed_k
	while x < x1:
		var h: int = (s * 37 + seed_k * 17 + 11) % 13
		var w: float = 3.0 + float(h % 5) * 2.0
		var gap: float = 2.0 + float((h / 2) % 4) * 2.0
		var dy: float = 0.0 if (h % 2 == 0) else 1.0
		ci.draw_rect(Rect2(x, y + dy, minf(w, x1 - x), 1.0), col)
		if h % 3 != 0 and x + 1.0 < x1:
			ci.draw_rect(Rect2(x + 1.0, y + 1.0, minf(w + 2.0, x1 - x - 1.0), 1.0), col)
		x += w + gap
		s += 1

static func _draw_stars(ci: CanvasItem, t: float, count: int, y0: float, y1: float, seed_k: int, slow: bool, fade: float, q0: float, q1: float) -> void:
	var span: int = maxi(1, int(y1 - y0))
	var fr: bool = LxHudFx.flash_reduced()
	for i: int in range(count):
		var sx: float = float((i * seed_k + 19) % 312 + 4)
		var sy: float = y0 + float((i * 41 + 7) % span)
		if fade > 0.0 and float(i % 7) / 7.0 < fade:
			continue
		var quiet: bool = sy >= q0 and sy <= q1 and sx > 44.0 and sx < 276.0
		var ph: float = (0.25 if i % 2 == 0 else 0.70) if fr else fmod(t + float(i) * 0.43, (2.8 if slow else 1.9) + float(i % 5) * 0.55)
		var hi: String = "mauve" if quiet else ("cream" if i % 7 == 0 else ("ice" if i % 3 == 0 else "stone"))
		var lo: String = "night" if quiet else ("dusk" if i % 2 == 0 else "mauve")
		ci.draw_rect(Rect2(sx, sy, 1.0, 1.0), LxPalette.PAL[hi if ph < 0.46 else lo])
		if not quiet and i % 6 == 0 and ph < 0.30 and fade < 0.45:
			_px(ci, [[-1, 0, 1, 1], [1, 0, 1, 1], [0, -1, 1, 1], [0, 1, 1, 1]], "sky" if i % 2 == 0 else "stone", sx, sy)

static func _draw_rivets(ci: CanvasItem, rect: Rect2, body: String, hi: String) -> void:
	var p: Vector2 = rect.position.round()
	var e: Vector2 = rect.end.round()
	for rv: Vector2 in [Vector2(p.x + 3.0, p.y + 3.0), Vector2(e.x - 5.0, p.y + 3.0), Vector2(p.x + 3.0, e.y - 5.0), Vector2(e.x - 5.0, e.y - 5.0)]:
		ci.draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxPalette.PAL["night"])
		ci.draw_rect(Rect2(rv, Vector2(2.0, 2.0)), LxPalette.PAL[body])
		ci.draw_rect(Rect2(rv, Vector2(1.0, 1.0)), LxPalette.PAL[hi])

static func _draw_filigree_divider(ci: CanvasItem, x0: float, x1: float, y: float, link: String, gem: String, show_gem: bool = true) -> void:
	var cx: float = roundf((x0 + x1) * 0.5)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 1.0), LxPalette.PAL["night"])
	ci.draw_rect(Rect2(x0 + 4.0, y, x1 - x0 - 8.0, 1.0), LxPalette.PAL["dusk"])
	var x: float = x0 + 8.0
	var step_i: int = 0
	while x < x1 - 8.0:
		if not show_gem or absf(x - cx) > 6.0:
			ci.draw_rect(Rect2(x, y, 3.0, 1.0), LxPalette.PAL[link if step_i % 2 == 0 else "dusk"])
		x += 6.0
		step_i += 1
	if show_gem:
		ci.draw_rect(Rect2(cx - 2.0, y, 5.0, 1.0), LxPalette.PAL[link])
		ci.draw_rect(Rect2(cx - 1.0, y - 1.0, 3.0, 3.0), LxPalette.PAL[gem])
		ci.draw_rect(Rect2(cx, y, 1.0, 1.0), LxPalette.PAL["cream"])
	else:
		ci.draw_rect(Rect2(x0, y, 2.0, 1.0), LxPalette.PAL[link])
		ci.draw_rect(Rect2(x1 - 2.0, y, 2.0, 1.0), LxPalette.PAL[link])

static func _draw_split_filigree_divider(ci: CanvasItem, x0: float, x1: float, gap_x0: float, gap_x1: float, y: float, link: String, gem: String) -> void:
	for wing: Array in [[x0, gap_x0, true], [gap_x1, x1, false]]:
		var wx0: float = float(wing[0])
		var wx1: float = float(wing[1])
		var is_left: bool = bool(wing[2])
		ci.draw_rect(Rect2(wx0, y, wx1 - wx0, 1.0), LxPalette.PAL["night"])
		ci.draw_rect(Rect2(wx0 + 2.0, y, wx1 - wx0 - 4.0, 1.0), LxPalette.PAL["dusk"])
		var x: float = wx0 + 4.0
		var wi: int = 0
		while x < wx1 - 6.0:
			ci.draw_rect(Rect2(x, y, 3.0, 1.0), LxPalette.PAL[link if wi % 2 == 0 else "dusk"])
			x += 6.0
			wi += 1
		var tip_x: float = wx1 - 2.0 if is_left else wx0
		ci.draw_rect(Rect2(tip_x, y, 2.0, 1.0), LxPalette.PAL[gem])
		ci.draw_rect(Rect2(tip_x + (1.0 if is_left else 0.0), y, 1.0, 1.0), LxPalette.PAL["cream"])

static func _draw_pixel_ring(ci: CanvasItem, center: Vector2, r: float, segs: int, col: Color, thickness: float = 1.0) -> void:
	if col.a <= 0.0 or r < 1.0:
		return
	var cx: float = roundf(center.x)
	var cy: float = roundf(center.y)
	for i: int in range(segs):
		var a: float = float(i) * TAU / float(segs)
		ci.draw_rect(Rect2(roundf(cx + cos(a) * r), roundf(cy + sin(a) * r), thickness, thickness), col)

static func draw_intro_backdrop(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	var fr: bool = LxHudFx.flash_reduced()
	if t < 2.5:
		# Beat 1 (0.0-2.5s): Dusk horizon + Bell Tower silhouette + expanding brass toll waves.
		var bt1: float = clampf(t / 2.5, 0.0, 1.0)
		var sky_band: String = "plum" if bt1 < 0.45 else "dusk"
		ci.draw_rect(Rect2(0.0, 130.0, 320.0, 8.0), LxPalette.PAL[sky_band])
		_dither(ci, 0.0, 320.0, 128.0, LxPalette.PAL[sky_band], 3)
		ci.draw_rect(Rect2(0.0, 138.0, 320.0, 26.0), LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 136.0, LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 162.0, LxPalette.PAL["void"])
		_draw_stars(ci, t, 28, 8.0, 122.0, 73, true, 0.0, 76.0, 100.0)
		# Expanding concentric pixel-stepped brass toll waves from the belfry (160, 126).
		for wi: int in range(2):
			var wu: float = fmod(t * (0.42 if fr else 0.72) + float(wi) * 0.5, 1.0)
			var wr: float = roundf(lerpf(8.0, 52.0, 1.0 - (1.0 - wu) * (1.0 - wu)))
			var wcol: Color = LxPalette.fade_step(1.0 - wu * 0.85, "gold" if wu < 0.42 else "apricot")
			_draw_pixel_ring(ci, Vector2(160.0, 126.0), wr, 28, wcol)
		# Bell Tower silhouette at x=160, y=126 grounded onto horizon hill.
		_px(ci, [[-18, 12, 36, 5], [-12, 9, 24, 4], [-7, -2, 14, 14], [-9, -3, 18, 2], [-6, -7, 12, 4], [-4, -11, 8, 4], [-2, -14, 4, 3], [-1, -17, 2, 3]], "night", 160.0, 126.0)
		_px(ci, [[-8, -3, 16, 1], [-5, -7, 10, 1], [-6, 10, 12, 1]], "dusk", 160.0, 126.0)
		_px(ci, [[-3, -2, 6, 7]], "void", 160.0, 126.0)
		var swing: float = 0.0 if fr else roundf(sin(t * 7.0) * 1.0)
		_px(ci, [[-1 + swing, -1, 3, 4], [-2 + swing, 2, 5, 1]], "apricot", 160.0, 126.0)
		ci.draw_rect(Rect2(160.0 + swing, 126.0, 1.0, 2.0), LxPalette.PAL["gold"])
	elif t < 5.0:
		# Beat 2 (2.5-5.0s): 8 bespoke biome archipelago silhouettes bookending Credits, snuffing west-to-east.
		var lt2: float = t - 2.5
		ci.draw_rect(Rect2(0.0, 138.0, 320.0, 26.0), LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 136.0, LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 162.0, LxPalette.PAL["void"])
		_draw_stars(ci, t, 30, 8.0, 124.0, 73, true, 0.0, 76.0, 100.0)
		var lit_states: Array = []
		for ii: int in range(8):
			var sa: float = 0.25 + float(ii) * 0.24
			lit_states.append(1.0 if lt2 < sa else (1.0 - (lt2 - sa) / 0.30 if lt2 < sa + 0.30 else 0.0))
		_draw_archipelago_silhouettes(ci, 148.0, lit_states, t)
	else:
		# Beat 3 (5.0-7.5s): Single warm brass lantern ignites at (160, 128) with pixel gold ring & sparks.
		var lt3: float = t - 5.0
		ci.draw_rect(Rect2(0.0, 138.0, 320.0, 26.0), LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 136.0, LxPalette.PAL["night"])
		_dither(ci, 0.0, 320.0, 162.0, LxPalette.PAL["void"])
		_draw_stars(ci, t, 30, 8.0, 124.0, 73, true, 0.0, 76.0, 100.0)
		var flk: bool = fr or fmod(t * 2.8, 1.0) < 0.58
		var dr: float = 0.0 if fr else roundf(sin(t * 2.2))
		var bt3: float = clampf(lt3 / 1.5, 0.0, 1.0)
		if bt3 < 0.94:
			var ring_r: float = roundf(lerpf(6.0, 44.0, 1.0 - pow(1.0 - bt3, 2.0)))
			_draw_pixel_ring(ci, Vector2(160.0, 128.0), ring_r, 30, LxPalette.fade_step(1.0 - bt3 * 0.85, "cream" if bt3 < 0.25 else "gold"))
			if ring_r > 12.0:
				_draw_pixel_ring(ci, Vector2(160.0, 128.0), ring_r - 6.0, 22, LxPalette.fade_step(1.0 - bt3, "apricot"))
		_px(ci, [[-10, 0, 1, 1], [10, 0, 1, 1], [-7, -5, 1, 1], [7, -5, 1, 1], [-7, 5, 1, 1], [7, 5, 1, 1], [-4 + dr, 10, 9, 1], [-2 - dr, 13, 5, 1]], "plum", 160.0, 128.0)
		_px(ci, [[-6, 0, 1, 1], [6, 0, 1, 1], [0, -6, 1, 1], [0, 6, 1, 1], [-4, -3, 1, 1], [4, -3, 1, 1], [-4, 3, 1, 1], [4, 3, 1, 1]], "coral" if flk else "wine", 160.0, 128.0)
		_px(ci, [[-2, -5, 5, 1], [-3, -4, 7, 1], [-3, 4, 7, 1], [-2, 5, 5, 1]], "night", 160.0, 128.0)
		_px(ci, [[-1, -6, 3, 1], [-2, -3, 1, 6], [2, -3, 1, 6], [-2, 3, 5, 1]], "apricot", 160.0, 128.0)
		ci.draw_rect(Rect2(159.0, 125.0, 3.0, 6.0), LxPalette.PAL["gold" if flk else "apricot"])
		ci.draw_rect(Rect2(160.0, 126.0, 1.0, 4.0), LxPalette.PAL["cream"])
		ci.draw_rect(Rect2(159.0 + dr, 138.0, 3.0, 1.0), LxPalette.PAL["apricot"])
		for mi: int in range(6):
			var mu: float = fmod(lt3 * (0.45 if fr else 0.70) + float(mi) * 0.19, 1.0)
			var mx: float = roundf(160.0 + sin(t * 2.1 + float(mi) * 1.4) * (10.0 + mu * 12.0))
			var my: float = roundf(124.0 - mu * 34.0)
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), LxPalette.PAL["cream" if mi % 2 == 0 else "gold"])

static func draw_death_vignette(ci: CanvasItem, panel: Rect2) -> void:
	var v: Color = LxPalette.PAL["void"]
	_px(ci, [[0, 0, 320, 16], [0, 162, 320, 18], [0, 16, 22, 146], [298, 16, 22, 146]], "void")
	_dither(ci, 20.0, 300.0, 16.0, v)
	_dither(ci, 20.0, 300.0, 160.0, v)
	for row: int in range(18, 160, 4):
		_px(ci, [[22, row, 2, 2], [26, row + 2, 2, 2], [296, row, 2, 2], [292, row + 2, 2, 2]], "void")
	ci.draw_rect(Rect2(panel.position + Vector2(3.0, 3.0), panel.size), v)
	ci.draw_rect(panel.grow(1.0), v)

static func draw_death_ornaments(ci: CanvasItem, panel: Rect2, t: float) -> void:
	_draw_rivets(ci, panel, "coral", "gold")
	# Extinguished/smoking miniature lantern crest atop DEATH_PANEL above DEATH_TITLE.
	_px(ci, [[-8, -7, 17, 15]], "night", 160.0, 34.0)
	_px(ci, [[-7, -6, 15, 13]], "coral", 160.0, 34.0)
	_px(ci, [[-6, -5, 13, 11]], "void", 160.0, 34.0)
	_px(ci, [[-1, -4, 3, 1], [-3, -3, 7, 1], [-2, -2, 1, 5], [2, -2, 1, 5], [-3, 3, 7, 1]], "mauve", 160.0, 34.0)
	ci.draw_rect(Rect2(159.0, 32.0, 3.0, 5.0), LxPalette.PAL["night"])
	var fr_dm: bool = LxHudFx.flash_reduced()
	var ember_pulse: float = 0.45 if fr_dm else fmod(t * 1.8, 1.0)
	ci.draw_rect(Rect2(160.0, 35.0, 1.0, 2.0), LxPalette.PAL["apricot" if ember_pulse < 0.28 else ("coral" if ember_pulse < 0.62 else "wine")])
	for s: int in range(3):
		var sy: float = 28.0 - fmod((0.0 if fr_dm else t * 6.5) + float(s) * 4.0, 12.0)
		var sx: float = 160.0 + (0.0 if fr_dm else roundf(sin(t * 2.5 + float(s) * 2.1) * 2.0))
		ci.draw_rect(Rect2(sx, roundf(sy), 2.0 if s == 0 else 1.0, 1.0), LxPalette.PAL["stone" if sy > 22.0 else "mauve"])
	for am: int in range(4):
		var ax: float = (panel.position.x + 12.0 + float(am % 2) * 10.0) if am < 2 else (panel.end.x - 14.0 - float(am % 2) * 10.0)
		var ay: float = roundf(panel.position.y + 14.0 + fmod((0.0 if fr_dm else t * (7.0 + float(am) * 1.6)) + float(am) * 19.0, panel.size.y - 26.0))
		ci.draw_rect(Rect2(ax + (0.0 if fr_dm else roundf(sin(t * 1.9 + float(am)) * 1.5)), ay, 1.0, 1.0), LxPalette.PAL["stone" if am % 2 == 0 else "mauve"])
	_draw_filigree_divider(ci, panel.position.x + 18.0, panel.end.x - 18.0, 99.0, "coral", "apricot")
	var isl_d: int = Lx.state.island_id if Lx.state != null else 1
	var b_hi_d: Color = LxBiomePalette.col(isl_d, "hi")
	LxHudFx.draw_biome_crest(ci, isl_d, Vector2(panel.position.x + 16.0, 52.0), b_hi_d, LxPalette.PAL["cream"] as Color)
	LxHudFx.draw_biome_crest(ci, isl_d, Vector2(panel.end.x - 17.0, 52.0), b_hi_d, LxPalette.PAL["cream"] as Color)

static func draw_lantern_core(ci: CanvasItem, at: Vector2, tier: int, t: float) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	if tier <= 0:
		_px(ci, [[-2, -4, 5, 1], [-2, 4, 5, 1], [-2, -3, 1, 7], [2, -3, 1, 7]], "night", x, y)
		ci.draw_rect(Rect2(x, y, 1.0, 1.0), LxPalette.PAL["apricot"])
		return
	var fr: bool = LxHudFx.flash_reduced()
	var flk: bool = fr or fmod(t * 3.4, 1.0) < 0.55
	var shift: float = 0.0 if (fr or fmod(t * 6.0, 1.0) < 0.5) else 1.0
	if tier >= 2:
		_px(ci, [[-8, 0, 1, 1], [8, 0, 1, 1], [0, -10, 1, 1], [0, 9, 1, 1], [-6, -5, 1, 1], [6, -5, 1, 1], [-6, 5, 1, 1], [6, 5, 1, 1]], "coral" if flk else "wine", x, y)
		_px(ci, [[-5, -1, 1, 3], [5, -1, 1, 3]], "apricot" if flk else "coral", x, y)
	_px(ci, [[-4, -6, 9, 2], [-4, 5, 9, 2], [-4, -4, 1, 9], [4, -4, 1, 9]], "night", x, y)
	_px(ci, [[-1, -8, 3, 1], [-2, -7, 1, 1], [2, -7, 1, 1], [-3, -5, 7, 1], [-3, 4, 7, 1]], "apricot" if tier >= 2 else "dusk", x, y)
	_px(ci, [[-3, -4, 1, 8], [3, -4, 1, 8], [-2, 5, 5, 1]], "coral" if tier >= 2 else "mauve", x, y)
	if tier >= 2:
		ci.draw_rect(Rect2(x - 2.0, y - 4.0, 5.0, 8.0), LxPalette.PAL["apricot"])
		ci.draw_rect(Rect2(x - 1.0, y - 3.0, 3.0, 6.0), LxPalette.PAL["gold"])
		_px(ci, [[-1, -2, 1, 4], [-1 + shift, -1, 2, 3], [0, -3, 1, 1]], "cream", x, y)
	else:
		ci.draw_rect(Rect2(x - 2.0, y - 4.0, 5.0, 8.0), LxPalette.PAL["wine"])
		ci.draw_rect(Rect2(x - 1.0, y - 2.0, 3.0, 4.0), LxPalette.PAL["coral"])
		ci.draw_rect(Rect2(x - 1.0 + shift, y - 1.0, 2.0, 2.0), LxPalette.PAL["gold" if flk else "apricot"])

static func draw_ending_dawn(ci: CanvasItem, t: float, islands: Array[Vector2], motes: Array[Dictionary]) -> void:
	var rise: float = clampf(t / 4.2, 0.0, 1.0)
	_draw_dawn_sky(ci, t, rise)
	_draw_dawn_sea(ci, t, rise)
	for i: int in range(islands.size()):
		_draw_dawn_island(ci, i, islands[i], t)
	_draw_wick_silhouette(ci, t)
	for m: Dictionary in motes:
		var mx: float = roundf(fmod(160.0 + cos(float(m["angle"])) * 140.0 + t * 8.0, 320.0))
		var my: float = roundf(120.0 - fmod(t * float(m["speed"]) * 0.4 + float(m["phase"]) * 80.0, 96.0))
		ci.draw_rect(Rect2(mx, my, 2.0, 2.0), LxPalette.color(str(m["color"])))
	# Buy-back golden sparks rising from the lantern when tolls were sold and returned at dawn.
	var receipts_n: int = LxSold.current().get_dawn_receipts().size()
	if receipts_n > 0 and t >= 1.1:
		var fr_d: bool = LxHudFx.flash_reduced()
		for ri: int in range(mini(receipts_n, 12)):
			var age: float = t - (1.1 + float(ri) * 0.28)
			if age < 0.0: continue
			var u: float = clampf(age / 2.2, 0.0, 1.0)
			var rx: float = roundf(27.0 + u * (133.0 + float((ri % 5) - 2) * 26.0))
			var ry: float = roundf(145.0 - u * 86.0 - sin(u * PI) * 18.0)
			if ry >= 18.0 and ry < 160.0:
				var col_k: String = "cream" if (fr_d or ri % 2 == 0) else "gold"
				ci.draw_rect(Rect2(rx, ry, 2.0, 2.0), LxPalette.PAL[col_k])

static func _draw_dawn_sky(ci: CanvasItem, t: float, rise: float) -> void:
	var cols: Array[Color] = [
		LxPalette.PAL["deep" if rise > 0.35 else "night"], LxPalette.PAL["blue" if rise > 0.45 else "deep"],
		LxPalette.PAL["sky" if rise > 0.58 else ("blue" if rise > 0.25 else "dusk")], LxPalette.PAL["coral" if rise > 0.30 else "plum"],
		LxPalette.PAL["apricot" if rise > 0.28 else "coral"], LxPalette.PAL["gold" if rise > 0.42 else "apricot"],
	]
	for bi: int in range(cols.size()):
		var by: float = 16.0 + float(bi) * 18.0
		ci.draw_rect(Rect2(0.0, by, 320.0, 16.0 if bi == 5 else 18.0), cols[bi])
		if bi > 0:
			_dither(ci, 0.0, 320.0, by - 2.0, cols[bi], bi + 1)
	_draw_stars(ci, t, 20, 18.0, 56.0, 67, true, rise * 1.15, 31.0, 42.0)
	var sun_y: float = roundf(lerpf(128.0, 88.0, rise))
	var ray_col: Color = LxPalette.PAL["gold" if rise > 0.45 else "apricot"]
	for ri: int in range(7):
		var ang: float = -PI * 0.88 + float(ri) * (PI * 0.76 / 6.0) + sin(t * 0.6 + float(ri)) * 0.03
		var d: float = 26.0
		var max_d: float = 34.0 + rise * 48.0 + (8.0 if ri % 2 == 0 else 0.0)
		while d < max_d:
			var ry: float = roundf(sun_y + sin(ang) * d)
			if ry >= 18.0 and ry < 121.0:
				ci.draw_rect(Rect2(roundf(160.0 + cos(ang) * d), ry, 2.0 if d < 46.0 else 1.0, 1.0), ray_col)
			d += 4.0
	ci.draw_circle(Vector2(160.0, sun_y), 25.0, LxPalette.PAL["apricot"])
	ci.draw_circle(Vector2(160.0, sun_y), 18.0, LxPalette.PAL["gold"])
	ci.draw_circle(Vector2(160.0, sun_y), 11.0, LxPalette.PAL["cream"])
	# If all 8 islands' Harmony Secrets were mastered, crown the rising Dawn sun with an 8-biome constellation arc!
	if rise > 0.35 and Lx.state != null:
		var harm_all: bool = true
		for hid: int in range(1, 9):
			if not bool(Lx.state.story_flags.get("disc_all_%d" % hid, false)):
				harm_all = false
				break
		if harm_all:
			for hi: int in range(8):
				var ha: float = -PI * 0.85 + float(hi) * (PI * 0.70 / 7.0)
				var hp: Vector2 = Vector2(roundf(160.0 + cos(ha) * 33.0), roundf(sun_y + sin(ha) * 33.0))
				if hp.y >= 18.0 and hp.y < 120.0:
					ci.draw_rect(Rect2(hp - Vector2.ONE, Vector2(3.0, 1.0)), LxBiomePalette.col(hi + 1, "glow"))
					ci.draw_rect(Rect2(hp + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), LxBiomePalette.col(hi + 1, "glow"))
					ci.draw_rect(Rect2(hp, Vector2.ONE), LxPalette.PAL["cream"])
	if rise > 0.45:
		for bi: int in range(3):
			var bx: float = roundf(fmod(24.0 + float(bi) * 86.0 + t * (10.5 + float(bi) * 2.2), 344.0) - 12.0)
			var by: float = roundf(42.0 + float(bi) * 11.0 + sin(t * 2.2 + float(bi) * 1.7) * 3.0)
			var flap: float = -1.0 if fmod(t * 3.2 + float(bi) * 0.35, 1.0) < 0.5 else 1.0
			ci.draw_rect(Rect2(bx, by, 1.0, 1.0), LxPalette.PAL["night"])
			ci.draw_rect(Rect2(bx - 1.0, by + flap, 1.0, 1.0), LxPalette.PAL["dusk"])
			ci.draw_rect(Rect2(bx + 1.0, by + flap, 1.0, 1.0), LxPalette.PAL["dusk"])
	for cl: Array in [[22, 54, 46, 2.2, "rose"], [214, 48, 52, 1.9, "rose"], [86, 74, 40, 2.6, "apricot"], [242, 78, 44, 2.3, "apricot"], [36, 94, 38, 3.0, "gold"]]:
		var cx: float = roundf(fmod(float(cl[0]) + t * float(cl[3]), 360.0) - 20.0)
		var cy: float = float(cl[1])
		var cw: float = float(cl[2])
		ci.draw_rect(Rect2(cx + 6.0, cy - 2.0, cw - 12.0, 2.0), LxPalette.PAL[str(cl[4])])
		ci.draw_rect(Rect2(cx + 2.0, cy, cw - 4.0, 2.0), LxPalette.PAL["apricot"])
		ci.draw_rect(Rect2(cx, cy + 2.0, cw, 1.0), LxPalette.PAL["gold"])
		ci.draw_rect(Rect2(cx + 8.0, cy + 2.0, cw - 16.0, 1.0), LxPalette.PAL["cream"])

static func _draw_dawn_sea(ci: CanvasItem, t: float, rise: float) -> void:
	ci.draw_rect(Rect2(0.0, 122.0, 320.0, 42.0), LxPalette.PAL["night"])
	ci.draw_rect(Rect2(0.0, 122.0, 320.0, 12.0), LxPalette.PAL["deep"])
	_dither(ci, 0.0, 320.0, 134.0, LxPalette.PAL["night"])
	ci.draw_rect(Rect2(0.0, 152.0, 320.0, 12.0), LxPalette.PAL["void"])
	_dither(ci, 0.0, 320.0, 150.0, LxPalette.PAL["void"])
	ci.draw_rect(Rect2(0.0, 122.0, 320.0, 1.0), LxPalette.PAL["coral"])
	ci.draw_rect(Rect2(88.0, 122.0, 144.0, 1.0), LxPalette.PAL["gold"])
	for i: int in range(18):
		var wy: float = 125.0 + float((i * 7) % 34)
		var bx: float = float((i * 53 + 17) % 298 + 4) + roundf(sin(t * (1.2 + float(i % 3) * 0.4) + float(i)) * 3.0)
		ci.draw_rect(Rect2(bx, wy, 4.0 + float(i % 4) * 2.0, 1.0), LxPalette.PAL["blue" if wy < 142.0 else "deep"])
	for r: int in range(11):
		var ry: float = roundf(124.0 + float(r) * 3.2)
		var bw: float = (18.0 + float(r) * 4.6) * (0.45 + 0.55 * rise)
		var wob: float = roundf(sin(t * 2.6 + float(r) * 0.9) * (1.5 + float(r) * 0.35))
		ci.draw_rect(Rect2(roundf(160.0 - bw * 0.5 + wob), ry, roundf(bw), 1.0), LxPalette.PAL["gold" if r < 6 else "apricot"])
		if r < 7:
			var cw: float = maxf(4.0, bw * 0.48)
			ci.draw_rect(Rect2(roundf(160.0 - cw * 0.5 - wob * 0.5), ry, roundf(cw), 1.0), LxPalette.PAL["cream"])

static func _draw_dawn_island(ci: CanvasItem, idx: int, p: Vector2, t: float) -> void:
	var x: float = roundf(p.x)
	var y: float = roundf(p.y)
	var isl_id: int = clampi(idx + 1, 1, 8)
	var base_k: String = LxBiomePalette.key(isl_id, "dark")
	var rim_k: String = LxBiomePalette.key(isl_id, "mid")
	match isl_id:
		1: # Bell Isle: rounded sanctuary hill + eastern ford glint
			_px(ci, [[-12, 0, 24, 3], [-9, 3, 18, 2], [-5, 5, 10, 1]], base_k, x, y)
			_px(ci, [[-10, -2, 20, 3], [-6, -4, 12, 2]], "night", x, y)
			ci.draw_rect(Rect2(x - 6.0, y - 4.0, 12.0, 1.0), LxPalette.PAL[rim_k])
			_px(ci, [[7, 0, 2, 3]], "sky", x, y)
		2: # 4-islet Harbor piers
			_px(ci, [[-13, 0, 5, 3], [-6, 0, 5, 3], [1, 0, 5, 3], [8, 0, 5, 3]], base_k, x, y)
			_px(ci, [[-11, -1, 22, 1]], rim_k, x, y)
		3: # Thornwood Hollow: terraced emerald forest tiers
			_px(ci, [[-11, 0, 22, 3], [-8, 3, 16, 2]], "pine", x, y)
			_px(ci, [[-9, -2, 18, 2], [-6, -4, 12, 2]], "teal", x, y)
			_px(ci, [[-5, -5, 10, 1]], "jade", x, y)
		4: # Glasshouse lagoon ring
			_px(ci, [[-12, 0, 24, 3], [-8, 3, 16, 2]], base_k, x, y)
			_px(ci, [[-10, -2, 20, 2]], rim_k, x, y)
			_px(ci, [[-5, -1, 10, 1]], "sky", x, y)
		5: # Starfall Observatory: ringed astrolabe terrace
			_px(ci, [[-12, 0, 24, 3], [-9, 3, 18, 2]], "deep", x, y)
			_px(ci, [[-10, -1, 5, 2], [5, -1, 5, 2], [-4, -3, 8, 3]], "blue", x, y)
			_px(ci, [[-5, 0, 10, 1]], "gold", x, y)
		6: # Lava-split volcanic caldera
			_px(ci, [[-12, 0, 10, 3], [2, 0, 10, 3], [-9, 3, 18, 2]], "night", x, y)
			_px(ci, [[-2, -1, 4, 4]], "coral", x, y)
			_px(ci, [[-1, 0, 2, 2]], "gold", x, y)
		7: # Twin silver crescent shoals
			_px(ci, [[-12, 0, 8, 3], [4, 0, 8, 3], [-8, 3, 16, 2]], "deep", x, y)
			_px(ci, [[-11, -2, 7, 2], [4, -2, 7, 2]], "sky", x, y)
		_: # The Long Night: stepped obsidian cathedral causeway
			_px(ci, [[-11, 1, 22, 3], [-8, -1, 16, 2], [-5, -3, 10, 2]], "night", x, y)
			_px(ci, [[-2, -3, 4, 5]], "plum", x, y)
			_px(ci, [[-1, -3, 2, 5]], "gold", x, y)
	var lm: Array = ISLAND_LANDMARKS[clampi(idx, 0, ISLAND_LANDMARKS.size() - 1)]
	_px(ci, lm[1] as Array, str(lm[0]), x, y)
	_px(ci, lm[3] as Array, str(lm[2]), x, y)
	var lamp_y: float = y + float(lm[4])
	var lit_at: float = 1.0 + float(idx) * 0.35
	if t >= lit_at:
		var age: float = t - lit_at
		var flk: bool = LxHudFx.flash_reduced() or fmod(t * 3.8 + float(idx) * 0.4, 1.0) < 0.55
		var bio_glow: Color = LxBiomePalette.col(isl_id, "glow")
		var bio_hi: Color = LxBiomePalette.col(isl_id, "hi")
		if age < 0.48:
			var u_ring: float = clampf(age / 0.48, 0.0, 1.0)
			var ring_r: float = roundf(lerpf(3.0, 18.0, 1.0 - (1.0 - u_ring) * (1.0 - u_ring)))
			var r_col: Color = LxPalette.PAL["cream"] if u_ring < 0.30 else (bio_glow if u_ring < 0.68 else LxPalette.PAL["gold"])
			ci.draw_arc(Vector2(x, lamp_y), ring_r, 0.0, TAU, 20, r_col, 1.4 if u_ring < 0.5 else 1.0, false)
		if age < 0.55:
			ci.draw_rect(Rect2(x - 2.0, 16.0, 4.0, lamp_y - 16.0), bio_glow)
			ci.draw_rect(Rect2(x - 1.0, 16.0, 2.0, lamp_y - 16.0), LxPalette.PAL["cream"])
		else:
			var bh: float = minf(lamp_y - 22.0, 22.0 + sin(t * 2.1 + float(idx)) * 4.0)
			ci.draw_rect(Rect2(x, lamp_y - bh, 1.0, bh), bio_glow if flk else bio_hi)
		ci.draw_rect(Rect2(x - 2.0, lamp_y - 1.0, 4.0, 3.0), bio_glow)
		ci.draw_rect(Rect2(x - 1.0, lamp_y - 2.0, 2.0, 3.0), LxPalette.PAL["cream"])
		if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_id, false)):
			var hs := Vector2(x, lamp_y - 9.0).round()
			ci.draw_rect(Rect2(hs + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), bio_glow)
			ci.draw_rect(Rect2(hs + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), bio_glow)
			ci.draw_rect(Rect2(hs, Vector2.ONE), LxPalette.PAL["cream"])
		for rr: int in range(5):
			var wob: float = roundf(sin(t * 3.0 + float(idx) + float(rr)) * 1.4)
			var rw: float = maxf(2.0, 6.0 - float(rr))
			ci.draw_rect(Rect2(roundf(x - rw * 0.5 + wob), y + 6.0 + float(rr) * 3.0, rw, 1.0), LxPalette.PAL["cream"] if rr == 0 else (bio_glow if rr < 3 else bio_hi))

static func _draw_wick_silhouette(ci: CanvasItem, t: float) -> void:
	# Foreground left cliff outcrop & Wick silhouette with warm eastern sunrise rim-light.
	_px(ci, [[0, 152, 32, 12], [0, 149, 26, 4], [10, 148, 12, 2], [15, 136, 2, 3], [20, 136, 2, 3], [16, 139, 6, 4], [15, 143, 8, 6], [13, 146, 2, 4], [22, 144, 3, 2]], "void")
	_px(ci, [[0, 150, 25, 2], [26, 153, 5, 2], [14, 148, 8, 1], [16, 145, 3, 3], [25, 144, 4, 1], [25, 148, 4, 1]], "night")
	_px(ci, [[0, 149, 13, 1], [14, 146, 1, 3], [15, 143, 1, 3], [16, 139, 1, 4]], "plum")
	# Crisp 1 px warm sunrise rim-light along sunward eastern edge of cliff, cloak, hood & moth-ears.
	_px(ci, [[13, 149, 13, 1], [26, 152, 6, 1], [31, 153, 1, 5], [16, 137, 1, 2], [17, 139, 4, 1], [22, 145, 1, 4]], "apricot")
	_px(ci, [[16, 136, 1, 1], [21, 137, 1, 6], [22, 143, 1, 2], [23, 144, 2, 1], [25, 152, 2, 1]], "gold")
	ci.draw_rect(Rect2(21.0, 136.0, 1.0, 1.0), LxPalette.PAL["cream"])
	ci.draw_rect(Rect2(25.0, 145.0, 4.0, 3.0), LxPalette.PAL["apricot"])
	ci.draw_rect(Rect2(26.0, 145.0, 2.0, 2.0), LxPalette.PAL["gold"])
	ci.draw_rect(Rect2(26.0, 146.0, 1.0, 1.0), LxPalette.PAL["cream"])
	if LxHudFx.flash_reduced() or fmod(t * 2.8, 1.0) < 0.55:
		_px(ci, [[24, 146, 1, 1], [29, 146, 1, 1], [27, 143, 1, 1]], "gold")

static func rank_text_color(rank_key: String) -> Color:
	return LxPalette.PAL[str((RANK_STYLE.get(rank_key, RANK_STYLE["RANK_C"]) as Array)[0])]

static func draw_results_backdrop(ci: CanvasItem, panel: Rect2, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	ci.draw_rect(Rect2(0.0, 148.0, 320.0, 32.0), LxPalette.PAL["night"])
	_dither(ci, 0.0, 320.0, 146.0, LxPalette.PAL["night"])
	_draw_stars(ci, t, 32, 6.0, 142.0, 79, true, 0.0, 22.0, 158.0)
	ci.draw_rect(Rect2(panel.position + Vector2(3.0, 3.0), panel.size), LxPalette.PAL["void"])

static func draw_results_ornaments(ci: CanvasItem, panel: Rect2, rank_key: String, t: float, relit_count: int = -1) -> void:
	_draw_rivets(ci, panel, "apricot", "gold")
	_draw_split_filigree_divider(ci, panel.position.x + 14.0, panel.end.x - 14.0, 146.0, 174.0, 35.0, "apricot", "gold")
	_draw_rank_medallion(ci, rank_key, t)
	LxPixelFont.draw_panel(ci, Rect2(34.0, 59.0, 252.0, 64.0), "night", "dusk", "void")
	ci.draw_rect(Rect2(160.0, 63.0, 1.0, 56.0), LxPalette.PAL["dusk"])
	for row: int in range(STAT_ICONS.size()):
		var iy: float = 64.0 + float(row) * 12.0
		_draw_mini_icon(ci, STAT_ICONS[row], 40.0, iy)
		_draw_mini_icon(ci, RIGHT_STAT_ICONS[row], 167.0, iy)
	_draw_mini_icon(ci, ["..i..", ".icy.", "iccyb", ".yyb.", "..b.."], 40.0, 112.0)
	_draw_mini_icon(ci, ["..ooc", "..o.o", "..o..", "coo..", ".ow.."], 167.0, 112.0)
	_draw_filigree_divider(ci, panel.position.x + 22.0, panel.end.x - 22.0, 127.0, "mauve", "apricot", false)
	var eff_relit: int = relit_count if relit_count >= 0 else (Lx.state.relit_islands.size() if Lx.state != null else 8)
	for isl_c: int in range(1, 9):
		var relit_c: bool = eff_relit >= 8 or isl_c <= eff_relit or (Lx.state != null and Lx.state.relit_islands.has(isl_c))
		var cx_c: float = roundf(62.0 + float(isl_c - 1) * 28.0)
		var c1: Color = LxBiomePalette.col(isl_c, "glow") if relit_c else (LxPalette.PAL["dusk"] as Color)
		var c2: Color = (LxPalette.PAL["cream"] if relit_c else LxPalette.PAL["mauve"]) as Color
		LxHudFx.draw_biome_crest(ci, isl_c, Vector2(cx_c, 137.0), c1, c2)
		if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_c, false)):
			var sg_c: bool = LxHudFx.flash_reduced() or fmod(t * 2.4 + float(isl_c) * 0.4, 1.0) < 0.55
			ci.draw_rect(Rect2(cx_c, 130.0, 1.0, 3.0), c1); ci.draw_rect(Rect2(cx_c - 1.0, 131.0, 3.0, 1.0), c1)
			ci.draw_rect(Rect2(cx_c, 131.0, 1.0, 1.0), LxPalette.PAL["cream"] if sg_c else c1)
	if rank_key == "RANK_S" or rank_key == "RANK_A":
		var fr_r: bool = LxHudFx.flash_reduced()
		var cnt: int = 8 if rank_key == "RANK_S" else 4
		var all_relit_r: bool = eff_relit >= 8
		for pi: int in range(cnt):
			var side_x: float = (panel.position.x + 8.0 + float(pi % 2) * 8.0) if pi < cnt / 2 else (panel.end.x - 10.0 - float(pi % 2) * 8.0)
			var py: float = roundf(panel.position.y + 14.0 + fmod((0.0 if fr_r else t * (10.0 + float(pi % 3) * 3.0)) + float(pi) * 17.0, panel.size.y - 28.0))
			var px: float = roundf(side_x + (0.0 if fr_r else sin(t * 2.1 + float(pi) * 1.4) * 2.0))
			var p_c: Color = LxBiomePalette.col((pi % 8) + 1, "glow") if all_relit_r else LxPalette.PAL["cream" if (rank_key == "RANK_S" and pi % 3 == 0) else ("gold" if pi % 2 == 0 else ("apricot" if rank_key == "RANK_S" else "lime"))]
			ci.draw_rect(Rect2(px, py, 1.0, 1.0), p_c)

static func _draw_rank_medallion(ci: CanvasItem, rank_key: String, t: float) -> void:
	var st: Array = RANK_STYLE.get(rank_key, RANK_STYLE["RANK_C"]) as Array
	var rim: String = str(st[0])
	_px(ci, [[104, 44, 18, 8], [198, 44, 18, 8], [122, 39, 76, 17]], "night")
	_px(ci, [[106, 45, 16, 6], [198, 45, 16, 6], [125, 41, 70, 13]], str(st[1]))
	_px(ci, [[105, 45, 17, 1], [105, 50, 17, 1], [198, 45, 17, 1], [198, 50, 17, 1], [123, 40, 74, 1], [123, 54, 74, 1], [123, 40, 2, 15], [195, 40, 2, 15]], rim)
	_px(ci, [[104, 47, 2, 2], [214, 47, 2, 2]], "dusk")
	_px(ci, [[124, 40, 1, 1], [195, 40, 1, 1], [124, 54, 1, 1], [195, 54, 1, 1]], str(st[2]))
	if rank_key == "RANK_S":
		_px(ci, [[155, 36, 11, 2], [155, 35, 2, 1], [159, 34, 3, 2], [164, 35, 2, 1]], "gold")
		_px(ci, [[160, 34, 1, 2], [156, 36, 1, 1], [164, 36, 1, 1]], "cream")
		var sg: bool = LxHudFx.flash_reduced() or fmod(t * 2.4, 1.0) < 0.5
		_px(ci, [[117, 40, 1, 1], [202, 40, 1, 1]] if sg else [[117, 54, 1, 1], [202, 54, 1, 1]], "cream")
		_px(ci, [[116, 40, 1, 1], [118, 40, 1, 1], [201, 40, 1, 1], [203, 40, 1, 1]] if sg else [[116, 54, 1, 1], [118, 54, 1, 1], [201, 54, 1, 1], [203, 54, 1, 1]], "gold")
	elif rank_key == "RANK_A":
		_px(ci, [[155, 36, 4, 2], [162, 36, 4, 2], [158, 35, 5, 1]], "lime")
		ci.draw_rect(Rect2(159.0, 36.0, 3.0, 2.0), LxPalette.PAL["gold"])
		if LxHudFx.flash_reduced() or fmod(t * 2.0, 1.0) < 0.45:
			_px(ci, [[118, 41, 1, 1], [201, 41, 1, 1]], "cream")
	elif rank_key == "RANK_B":
		_px(ci, [[159, 34, 3, 3], [157, 35, 7, 1]], "sky")
		ci.draw_rect(Rect2(160.0, 35.0, 1.0, 1.0), LxPalette.PAL["ice"])
	else:
		ci.draw_rect(Rect2(158.0, 35.0, 5.0, 2.0), LxPalette.PAL["apricot"])
		ci.draw_rect(Rect2(160.0, 35.0, 1.0, 1.0), LxPalette.PAL["coral"])

static func _draw_mini_icon(ci: CanvasItem, rows: Array, ox: float, oy: float) -> void:
	for r: int in range(rows.size()):
		var row: String = str(rows[r])
		for c: int in range(row.length()):
			if row[c] != ".":
				ci.draw_rect(Rect2(ox + float(c), oy + float(r), 1.0, 1.0), LxPalette.color(str(ICON_PAL.get(row[c], "cream"))))

static func _draw_archipelago_silhouettes(ci: CanvasItem, horizon_y: float, lit_states: Array, elapsed: float) -> void:
	var oy: float = horizon_y - 164.0
	var fr: bool = LxHudFx.flash_reduced()
	# Shared 8-biome archipelago silhouettes (Bell Isle -> Sanctum) bookending Intro Beat 2 & Credits.
	_px(ci, [
		[8, 155, 28, 9], [14, 153, 16, 2], [18, 150, 5, 5], [19, 149, 3, 1],
		[44, 157, 6, 7], [52, 157, 6, 7], [60, 157, 6, 7], [68, 157, 6, 7], [57, 151, 5, 6],
		[84, 157, 28, 7], [88, 154, 20, 3], [91, 152, 14, 2], [94, 150, 8, 2],
		[124, 157, 28, 7], [130, 153, 16, 4], [133, 151, 10, 2], [136, 150, 4, 1],
		[162, 156, 30, 8], [166, 154, 22, 2], [171, 151, 12, 3], [174, 149, 6, 2],
		[201, 156, 12, 8], [218, 156, 12, 8], [212, 151, 6, 6],
		[240, 157, 10, 7], [258, 157, 10, 7], [252, 150, 4, 7],
		[278, 157, 32, 7], [283, 155, 22, 2], [288, 150, 3, 6], [297, 150, 3, 6], [291, 151, 6, 2],
	], "dusk", 0.0, oy)
	_px(ci, [[213, 158, 5, 5]], "coral" if (lit_states.size() > 5 and float(lit_states[5]) > 0.0) else "wine", 0.0, oy)
	_px(ci, [[250, 159, 8, 4]], "deep", 0.0, oy)
	if horizon_y >= 160.0:
		ci.draw_rect(Rect2(0.0, horizon_y, 320.0, 180.0 - horizon_y), LxPalette.PAL["void"])
		_dither(ci, 0.0, 320.0, horizon_y - 1.0, LxPalette.PAL["void"])
	else:
		ci.draw_rect(Rect2(0.0, horizon_y, 320.0, 1.0), LxPalette.PAL["deep"])
		_dither(ci, 0.0, 320.0, horizon_y + 1.0, LxPalette.PAL["dusk"], 5)
		_dither(ci, 0.0, 320.0, horizon_y + 3.0, LxPalette.PAL["deep"], 9)
	var lamps: Array = [[20, 149], [59, 150], [97, 152], [137, 149], [176, 148], [215, 150], [253, 149], [293, 149]]
	for bi: int in range(8):
		var bx: float = float((lamps[bi] as Array)[0])
		var by: float = float((lamps[bi] as Array)[1]) + oy
		var st: float = float(lit_states[bi]) if bi < lit_states.size() else 0.0
		if st >= 1.5:
			var lit_c: bool = fr or fmod(elapsed * 1.6 + float(bi) * 0.55, 1.0) < 0.6
			var bc_glow: Color = LxBiomePalette.col(bi + 1, "glow")
			var bc_hi: Color = LxBiomePalette.col(bi + 1, "hi")
			ci.draw_rect(Rect2(bx, by - 5.0, 1.0, 5.0), bc_hi if lit_c else (LxPalette.PAL["dusk"] as Color))
			ci.draw_rect(Rect2(bx, by, 1.0, 1.0), LxPalette.PAL["cream"] if lit_c else bc_glow)
			ci.draw_rect(Rect2(bx - 1.0, horizon_y + 2.0 + float(bi % 3) * 2.0, 3.0, 1.0), bc_glow if lit_c else bc_hi)
			if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % (bi + 1), false)):
				ci.draw_rect(Rect2(bx - 1.0, by - 9.0, 3.0, 1.0), bc_glow)
				ci.draw_rect(Rect2(bx, by - 10.0, 1.0, 3.0), bc_glow)
				ci.draw_rect(Rect2(bx, by - 9.0, 1.0, 1.0), LxPalette.PAL["cream"] if lit_c else bc_glow)
		elif st >= 1.0:
			var flk2: bool = fr or fmod(elapsed * 3.0 + float(bi) * 0.4, 1.0) < 0.6
			var gw: float = 0.0 if fr else roundf(sin(elapsed * 2.4 + float(bi) * 1.1))
			ci.draw_rect(Rect2(bx - 1.0, by - 1.0, 2.0, 2.0), LxPalette.PAL["gold" if flk2 else "apricot"])
			ci.draw_rect(Rect2(bx, by - 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
			ci.draw_rect(Rect2(bx - 1.0 + gw, horizon_y + 2.0, 3.0, 1.0), LxPalette.PAL["gold" if flk2 else "apricot"])
			ci.draw_rect(Rect2(bx - gw, horizon_y + 4.0 + float(bi % 2) * 2.0, 2.0, 1.0), LxPalette.PAL["apricot" if flk2 else "wine"])
		elif st > 0.0:
			var su: float = 1.0 - st
			ci.draw_rect(Rect2(bx, by - 1.0, 1.0, 1.0), LxPalette.PAL["coral" if su < 0.5 else "wine"])
			ci.draw_rect(Rect2(bx + (0.0 if fr else roundf(sin(su * 5.0))), roundf(by - 3.0 - su * 6.0), 1.0, 1.0), LxPalette.PAL["mauve"])
		else:
			ci.draw_rect(Rect2(bx, by - 1.0, 1.0, 1.0), LxPalette.PAL["void"])

static func draw_credits_backdrop(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	ci.draw_rect(Rect2(0.0, 146.0, 320.0, 34.0), LxPalette.PAL["night"])
	_dither(ci, 0.0, 320.0, 144.0, LxPalette.PAL["night"])
	_draw_stars(ci, t, 34, 6.0, 138.0, 73, true, 0.0, -1.0, -1.0)
	_draw_archipelago_silhouettes(ci, 164.0, [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0], t)
	# Gentle rising lantern fireflies along left/right margins in all 8 biome glows (center lane stays clean).
	var fr_c: bool = LxHudFx.flash_reduced()
	for mi: int in range(14):
		var side_x: float = float(8 + (mi * 13) % 38) if mi % 2 == 0 else float(274 + (mi * 17) % 38)
		var mx: float = roundf(side_x + (0.0 if fr_c else sin(t * 1.15 + float(mi) * 1.3) * 4.0))
		var my: float = roundf(152.0 - fmod((0.0 if fr_c else t * (7.0 + float(mi % 3) * 2.5)) + float(mi) * 23.0, 148.0))
		var f_isl: int = (mi % 8) + 1
		var f_glow: Color = LxBiomePalette.col(f_isl, "glow")
		var f_hi: Color = LxBiomePalette.col(f_isl, "hi")
		var pulse: float = 0.4 if fr_c else fmod(t + float(mi) * 0.47, 1.8)
		if pulse < 0.7:
			ci.draw_rect(Rect2(mx, my, 2.0, 2.0), f_glow)
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), LxPalette.PAL["cream"])
		elif pulse < 1.25:
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), f_glow)
		else:
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), f_hi)
