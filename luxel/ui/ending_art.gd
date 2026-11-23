class_name LxEndingArt
extends RefCounted
## Studio pixel-art renderer for Intro, Death, Dawn/Display-Off Endings, Results & Credits.
## Uses ONLY the 20 opaque Last Light colours in LxPalette.PAL.

const ICON_PAL: Dictionary = {
	"k": "void", "n": "night", "d": "dusk", "m": "mauve", "s": "stone",
	"w": "wine", "r": "coral", "a": "apricot", "g": "gold", "c": "cream",
	"b": "blue", "y": "sky", "i": "ice", "l": "lime", "p": "pine",
}
const STAT_ICONS: Array[Array] = [
	["ggggg", ".ici.", "..c..", ".i.i.", "ggggg"], # Time: hourglass
	[".sss.", "snsns", "ssrss", ".s.s.", "..m.."], # Deaths: fallen wick
	["..c..", ".cgc.", "agaga", "ragar", ".wrw."], # Embers: flame
	[".aga.", "aggga", "agcga", "aggga", ".ddd."], # Lamps relit: lantern
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

static func _dither(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var x: float = x0
	while x < x1:
		ci.draw_rect(Rect2(x, y, 2.0, 1.0), col)
		ci.draw_rect(Rect2(x + 4.0, y + 1.0, 4.0, 1.0), col)
		x += 8.0

static func _draw_stars(ci: CanvasItem, t: float, count: int, y0: float, y1: float, seed_k: int, slow: bool, fade: float, q0: float, q1: float) -> void:
	var span: int = maxi(1, int(y1 - y0))
	for i: int in range(count):
		var sx: float = float((i * seed_k + 19) % 312 + 4)
		var sy: float = y0 + float((i * 41 + 7) % span)
		if fade > 0.0 and float(i % 7) / 7.0 < fade:
			continue
		var quiet: bool = sy >= q0 and sy <= q1 and sx > 44.0 and sx < 276.0
		var ph: float = fmod(t + float(i) * 0.43, (2.8 if slow else 1.9) + float(i % 5) * 0.55)
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

static func _draw_filigree_divider(ci: CanvasItem, x0: float, x1: float, y: float, link: String, gem: String) -> void:
	var cx: float = roundf((x0 + x1) * 0.5)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 1.0), LxPalette.PAL["night"])
	ci.draw_rect(Rect2(x0 + 4.0, y, x1 - x0 - 8.0, 1.0), LxPalette.PAL["dusk"])
	var x: float = x0 + 8.0
	while x < x1 - 8.0:
		if absf(x - cx) > 6.0:
			ci.draw_rect(Rect2(x, y, 3.0, 1.0), LxPalette.PAL[link if int(x) % 12 == 0 else "dusk"])
		x += 6.0
	ci.draw_rect(Rect2(cx - 2.0, y, 5.0, 1.0), LxPalette.PAL[link])
	ci.draw_rect(Rect2(cx - 1.0, y - 1.0, 3.0, 3.0), LxPalette.PAL[gem])
	ci.draw_rect(Rect2(cx, y, 1.0, 1.0), LxPalette.PAL["cream"])

static func draw_intro_backdrop(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	ci.draw_rect(Rect2(0.0, 138.0, 320.0, 26.0), LxPalette.PAL["night"])
	_dither(ci, 0.0, 320.0, 136.0, LxPalette.PAL["night"])
	_dither(ci, 0.0, 320.0, 162.0, LxPalette.PAL["void"])
	_draw_stars(ci, t, 30, 8.0, 128.0, 73, true, 0.0, 76.0, 100.0)
	# Subtle flickering golden Wick-lantern glow silhouette below text (y = 128).
	var boost: bool = t >= 4.0
	var fr: bool = LxHudFx.flash_reduced()
	var flk: bool = fr or fmod(t * 2.5, 1.0) < 0.58
	var dr: float = 0.0 if fr else roundf(sin(t * 2.2))
	_px(ci, [[-10, 0, 1, 1], [10, 0, 1, 1], [-7, -5, 1, 1], [7, -5, 1, 1], [-7, 5, 1, 1], [7, 5, 1, 1], [-4 + dr, 10, 9, 1], [-2 - dr, 13, 5, 1]], "plum", 160.0, 128.0)
	_px(ci, [[-6, 0, 1, 1], [6, 0, 1, 1], [0, -6, 1, 1], [0, 6, 1, 1], [-4, -3, 1, 1], [4, -3, 1, 1], [-4, 3, 1, 1], [4, 3, 1, 1]], "coral" if (boost and flk) else "wine", 160.0, 128.0)
	_px(ci, [[-2, -5, 5, 1], [-3, -4, 7, 1], [-3, 4, 7, 1], [-2, 5, 5, 1]], "night", 160.0, 128.0)
	_px(ci, [[-1, -6, 3, 1], [-2, -3, 1, 6], [2, -3, 1, 6], [-2, 3, 5, 1]], "apricot", 160.0, 128.0)
	ci.draw_rect(Rect2(159.0, 125.0, 3.0, 6.0), LxPalette.PAL["gold" if flk else "apricot"])
	ci.draw_rect(Rect2(160.0, 126.0, 1.0, 4.0), LxPalette.PAL["cream"])
	ci.draw_rect(Rect2(159.0 + dr, 138.0, 3.0, 1.0), LxPalette.PAL["apricot" if boost else "coral"])
	if boost:
		var bt: float = clampf((t - 4.0) / 1.4, 0.0, 1.0)
		var ring_r: float = roundf(lerpf(6.0, 42.0, 1.0 - pow(1.0 - bt, 2.0)))
		if bt < 0.92:
			ci.draw_arc(Vector2(160.0, 128.0), ring_r, 0.0, TAU, 24, Color(LxPalette.PAL["gold"], (1.0 - bt) * 0.72), 1.0)
		for mi: int in range(6):
			var mu: float = fmod((t - 4.0) * 0.65 + float(mi) * 0.19, 1.0)
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
	var ember_pulse: float = fmod(t * 1.8, 1.0)
	ci.draw_rect(Rect2(160.0, 35.0, 1.0, 2.0), LxPalette.PAL["apricot" if ember_pulse < 0.28 else ("coral" if ember_pulse < 0.62 else "wine")])
	for s: int in range(3):
		var sy: float = 28.0 - fmod(t * 6.5 + float(s) * 4.0, 12.0)
		var sx: float = 160.0 + roundf(sin(t * 2.5 + float(s) * 2.1) * 2.0)
		ci.draw_rect(Rect2(sx, roundf(sy), 2.0 if s == 0 else 1.0, 1.0), LxPalette.PAL["stone" if sy > 22.0 else "mauve"])
	for am: int in range(4):
		var ax: float = (panel.position.x + 12.0 + float(am % 2) * 10.0) if am < 2 else (panel.end.x - 14.0 - float(am % 2) * 10.0)
		var ay: float = roundf(panel.position.y + 14.0 + fmod(t * (7.0 + float(am) * 1.6) + float(am) * 19.0, panel.size.y - 26.0))
		ci.draw_rect(Rect2(ax + roundf(sin(t * 1.9 + float(am)) * 1.5), ay, 1.0, 1.0), LxPalette.PAL["stone" if am % 2 == 0 else "mauve"])
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
			_dither(ci, 0.0, 320.0, by - 2.0, cols[bi])
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
		if age < 0.48:
			var u_ring: float = clampf(age / 0.48, 0.0, 1.0)
			var ring_r: float = roundf(lerpf(3.0, 18.0, 1.0 - (1.0 - u_ring) * (1.0 - u_ring)))
			var r_col: Color = LxPalette.PAL["cream"] if u_ring < 0.30 else (bio_glow if u_ring < 0.68 else LxPalette.PAL["gold"])
			ci.draw_arc(Vector2(x, lamp_y), ring_r, 0.0, TAU, 20, r_col, 1.4 if u_ring < 0.5 else 1.0, false)
		if age < 0.55:
			ci.draw_rect(Rect2(x - 2.0, 16.0, 4.0, lamp_y - 16.0), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(x - 1.0, 16.0, 2.0, lamp_y - 16.0), LxPalette.PAL["cream"])
		else:
			var bh: float = minf(lamp_y - 22.0, 22.0 + sin(t * 2.1 + float(idx)) * 4.0)
			ci.draw_rect(Rect2(x, lamp_y - bh, 1.0, bh), LxPalette.PAL["gold" if flk else "apricot"])
		ci.draw_rect(Rect2(x - 2.0, lamp_y - 1.0, 4.0, 3.0), LxPalette.PAL["gold"])
		ci.draw_rect(Rect2(x - 1.0, lamp_y - 2.0, 2.0, 3.0), LxPalette.PAL["cream"])
		if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_id, false)):
			var hs := Vector2(x, lamp_y - 9.0).round()
			ci.draw_rect(Rect2(hs + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), bio_glow)
			ci.draw_rect(Rect2(hs + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), bio_glow)
			ci.draw_rect(Rect2(hs, Vector2.ONE), LxPalette.PAL["cream"])
		for rr: int in range(5):
			var wob: float = roundf(sin(t * 3.0 + float(idx) + float(rr)) * 1.4)
			var rw: float = maxf(2.0, 6.0 - float(rr))
			ci.draw_rect(Rect2(roundf(x - rw * 0.5 + wob), y + 6.0 + float(rr) * 3.0, rw, 1.0), LxPalette.PAL["cream" if rr == 0 else ("gold" if rr < 3 else "apricot")])

static func _draw_wick_silhouette(ci: CanvasItem, t: float) -> void:
	# Foreground left cliff outcrop & Wick silhouette (moth-ears + cloak + softly glowing lantern).
	_px(ci, [[0, 152, 32, 12], [0, 149, 26, 4], [10, 148, 12, 2], [15, 136, 2, 3], [20, 136, 2, 3], [16, 139, 6, 4], [15, 143, 8, 6], [13, 146, 2, 4], [22, 144, 3, 2]], "void")
	_px(ci, [[24, 150, 4, 2], [28, 152, 4, 3], [14, 148, 8, 1], [16, 145, 3, 3], [25, 144, 4, 1], [25, 148, 4, 1]], "night")
	_px(ci, [[22, 149, 3, 1], [27, 152, 3, 1], [21, 137, 1, 6], [22, 143, 1, 5]], "plum")
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

static func draw_results_ornaments(ci: CanvasItem, panel: Rect2, rank_key: String, t: float) -> void:
	_draw_rivets(ci, panel, "apricot", "gold")
	_draw_filigree_divider(ci, panel.position.x + 14.0, panel.end.x - 14.0, 47.0, "apricot", "gold")
	_draw_rank_medallion(ci, rank_key, t)
	LxPixelFont.draw_panel(ci, Rect2(70.0, 74.0, 180.0, 50.0), "night", "dusk", "void")
	for row: int in range(STAT_ICONS.size()):
		var iy: float = 78.0 + float(row) * 12.0
		_draw_mini_icon(ci, STAT_ICONS[row], 82.0, iy)
		_draw_mini_icon(ci, STAT_ICONS[row], 233.0, iy)
	_draw_filigree_divider(ci, panel.position.x + 22.0, panel.end.x - 22.0, 132.0, "mauve", "apricot")
	for isl_c: int in range(1, 9):
		var relit_c: bool = Lx.state == null or Lx.state.relit_islands.has(isl_c)
		var cx_c: float = roundf(76.0 + float(isl_c - 1) * 24.0)
		var c1: Color = LxBiomePalette.col(isl_c, "glow") if relit_c else (LxPalette.PAL["dusk"] as Color)
		var c2: Color = (LxPalette.PAL["cream"] if relit_c else LxPalette.PAL["mauve"]) as Color
		LxHudFx.draw_biome_crest(ci, isl_c, Vector2(cx_c, 132.0), c1, c2)
		if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_c, false)):
			var sg_c: bool = LxHudFx.flash_reduced() or fmod(t * 2.4 + float(isl_c) * 0.4, 1.0) < 0.55
			ci.draw_rect(Rect2(cx_c, 126.0, 1.0, 3.0), c1)
			ci.draw_rect(Rect2(cx_c - 1.0, 127.0, 3.0, 1.0), c1)
			ci.draw_rect(Rect2(cx_c, 127.0, 1.0, 1.0), LxPalette.PAL["cream"] if sg_c else c1)
	if rank_key == "RANK_S" or rank_key == "RANK_A":
		var fr_r: bool = LxHudFx.flash_reduced()
		var cnt: int = 8 if rank_key == "RANK_S" else 4
		for pi: int in range(cnt):
			var side_x: float = (panel.position.x + 12.0 + float(pi % 2) * 12.0) if pi < cnt / 2 else (panel.end.x - 14.0 - float(pi % 2) * 12.0)
			var py: float = roundf(panel.position.y + 14.0 + fmod((0.0 if fr_r else t * (10.0 + float(pi % 3) * 3.0)) + float(pi) * 17.0, panel.size.y - 28.0))
			var px: float = roundf(side_x + (0.0 if fr_r else sin(t * 2.1 + float(pi) * 1.4) * 2.5))
			var pcol: String = "cream" if (rank_key == "RANK_S" and pi % 3 == 0) else ("gold" if pi % 2 == 0 else ("apricot" if rank_key == "RANK_S" else "lime"))
			ci.draw_rect(Rect2(px, py, 1.0, 1.0), LxPalette.PAL[pcol])

static func _draw_rank_medallion(ci: CanvasItem, rank_key: String, t: float) -> void:
	var st: Array = RANK_STYLE.get(rank_key, RANK_STYLE["RANK_C"]) as Array
	var rim: String = str(st[0])
	_px(ci, [[104, 57, 18, 8], [198, 57, 18, 8], [122, 53, 76, 16]], "night")
	_px(ci, [[106, 58, 16, 6], [198, 58, 16, 6], [125, 55, 70, 12]], str(st[1]))
	_px(ci, [[105, 58, 17, 1], [105, 63, 17, 1], [198, 58, 17, 1], [198, 63, 17, 1], [123, 54, 74, 1], [123, 67, 74, 1], [123, 54, 2, 14], [195, 54, 2, 14]], rim)
	_px(ci, [[104, 60, 2, 2], [214, 60, 2, 2]], "dusk")
	_px(ci, [[124, 54, 1, 1], [195, 54, 1, 1], [124, 67, 1, 1], [195, 67, 1, 1]], str(st[2]))
	if rank_key == "RANK_S":
		_px(ci, [[155, 51, 11, 2], [155, 50, 2, 1], [159, 49, 3, 2], [164, 50, 2, 1]], "gold")
		_px(ci, [[160, 49, 1, 2], [156, 51, 1, 1], [164, 51, 1, 1]], "cream")
		var sg: bool = LxHudFx.flash_reduced() or fmod(t * 2.4, 1.0) < 0.5
		_px(ci, [[117, 54, 1, 1], [202, 54, 1, 1]] if sg else [[117, 67, 1, 1], [202, 67, 1, 1]], "cream")
		_px(ci, [[116, 54, 1, 1], [118, 54, 1, 1], [201, 54, 1, 1], [203, 54, 1, 1]] if sg else [[116, 67, 1, 1], [118, 67, 1, 1], [201, 67, 1, 1], [203, 67, 1, 1]], "gold")
	elif rank_key == "RANK_A":
		_px(ci, [[155, 51, 4, 2], [162, 51, 4, 2], [158, 50, 5, 1]], "lime")
		ci.draw_rect(Rect2(159.0, 51.0, 3.0, 2.0), LxPalette.PAL["gold"])
		if LxHudFx.flash_reduced() or fmod(t * 2.0, 1.0) < 0.45:
			_px(ci, [[118, 55, 1, 1], [201, 55, 1, 1]], "cream")
	elif rank_key == "RANK_B":
		_px(ci, [[159, 50, 3, 3], [157, 51, 7, 1]], "sky")
		ci.draw_rect(Rect2(160.0, 51.0, 1.0, 1.0), LxPalette.PAL["ice"])
	else:
		ci.draw_rect(Rect2(158.0, 51.0, 5.0, 2.0), LxPalette.PAL["apricot"])
		ci.draw_rect(Rect2(160.0, 51.0, 1.0, 1.0), LxPalette.PAL["coral"])

static func _draw_mini_icon(ci: CanvasItem, rows: Array, ox: float, oy: float) -> void:
	for r: int in range(rows.size()):
		var row: String = str(rows[r])
		for c: int in range(row.length()):
			if row[c] != ".":
				ci.draw_rect(Rect2(ox + float(c), oy + float(r), 1.0, 1.0), LxPalette.color(str(ICON_PAL.get(row[c], "cream"))))

static func draw_credits_backdrop(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	ci.draw_rect(Rect2(0.0, 146.0, 320.0, 34.0), LxPalette.PAL["night"])
	_dither(ci, 0.0, 320.0, 144.0, LxPalette.PAL["night"])
	_draw_stars(ci, t, 34, 6.0, 138.0, 73, true, 0.0, -1.0, -1.0)
	# True reshaped 8-island archipelago silhouettes across the twilight credits horizon
	_px(ci, [
		[8, 155, 28, 9], [14, 153, 16, 2], [18, 150, 5, 5], [19, 149, 3, 1],                  # 1 Bell Isle cliff + belfry
		[44, 157, 6, 7], [52, 157, 6, 7], [60, 157, 6, 7], [68, 157, 6, 7], [57, 151, 5, 6], # 2 Tidewater 4-islet piers + lighthouse
		[84, 157, 28, 7], [88, 154, 20, 3], [91, 152, 14, 2], [94, 150, 8, 2],               # 3 Thornwood 3-tier oak massif
		[124, 157, 28, 7], [130, 153, 16, 4], [133, 151, 10, 2], [136, 150, 4, 1],           # 4 Mirefen lagoon + conservatory dome
		[162, 156, 30, 8], [166, 154, 22, 2], [171, 151, 12, 3], [174, 149, 6, 2],           # 5 Starfall astrolabe wheel + dome
		[201, 156, 12, 8], [218, 156, 12, 8], [212, 151, 6, 6],                              # 6 Ashen Kiln split caldera + chimney
		[240, 157, 10, 7], [258, 157, 10, 7], [252, 150, 4, 7],                              # 7 Moon Shoals twin crescents + spire
		[278, 157, 32, 7], [283, 155, 22, 2], [288, 150, 3, 6], [297, 150, 3, 6], [291, 151, 6, 2], # 8 Long Night stepped cathedral arch
	], "dusk")
	_px(ci, [[213, 158, 5, 5]], "coral") # Subtle lava-river cleft glow in Ashen Kiln silhouette
	_px(ci, [[250, 159, 8, 4]], "deep")  # Mirror lake reflection between Moon Shoals crescents
	ci.draw_rect(Rect2(0.0, 164.0, 320.0, 16.0), LxPalette.PAL["void"])
	_dither(ci, 0.0, 320.0, 163.0, LxPalette.PAL["void"])
	for bi: int in range(8):
		var b: Array = [[20, 149], [59, 150], [97, 152], [137, 149], [176, 148], [215, 150], [253, 149], [293, 149]][bi]
		var bx: float = float(b[0])
		var by: float = float(b[1])
		var lit_c: bool = LxHudFx.flash_reduced() or fmod(t * 1.6 + float(bi) * 0.55, 1.0) < 0.6
		var bc_glow: Color = LxBiomePalette.col(bi + 1, "glow")
		var bc_hi: Color = LxBiomePalette.col(bi + 1, "hi")
		ci.draw_rect(Rect2(bx, by - 5.0, 1.0, 5.0), bc_hi if lit_c else (LxPalette.PAL["dusk"] as Color))
		ci.draw_rect(Rect2(bx, by, 1.0, 1.0), LxPalette.PAL["cream"] if lit_c else bc_glow)
		ci.draw_rect(Rect2(bx - 1.0, 166.0 + float(bi % 3) * 2.0, 3.0, 1.0), bc_glow if lit_c else bc_hi)
		if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % (bi + 1), false)):
			ci.draw_rect(Rect2(bx - 1.0, by - 9.0, 3.0, 1.0), bc_glow)
			ci.draw_rect(Rect2(bx, by - 10.0, 1.0, 3.0), bc_glow)
			ci.draw_rect(Rect2(bx, by - 9.0, 1.0, 1.0), LxPalette.PAL["cream"] if lit_c else bc_glow)
	# Gentle rising lantern fireflies along left/right margins (center text lane stays clean).
	for mi: int in range(14):
		var side_x: float = float(8 + (mi * 13) % 38) if mi % 2 == 0 else float(274 + (mi * 17) % 38)
		var mx: float = roundf(side_x + sin(t * 1.15 + float(mi) * 1.3) * 4.0)
		var my: float = roundf(152.0 - fmod(t * (7.0 + float(mi % 3) * 2.5) + float(mi) * 23.0, 148.0))
		var pulse: float = fmod(t + float(mi) * 0.47, 1.8)
		if pulse < 0.7:
			ci.draw_rect(Rect2(mx, my, 2.0, 2.0), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), LxPalette.PAL["cream"])
		elif pulse < 1.25:
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), LxPalette.PAL["apricot"])
		else:
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), LxPalette.PAL["coral"])
