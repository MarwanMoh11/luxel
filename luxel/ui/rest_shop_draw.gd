class_name LxRestShopDraw
extends RefCounted
## Pixel-art rendering helpers & 7x7 Last-Light icons for LxRestShop (all 16 upgrades + 4 wares).

const PANEL_RECT := Rect2(20.0, 12.0, 280.0, 156.0)
const SPARK_DUR: float = 0.45

const ICON_PAL: Dictionary = {
	"k": "void", "n": "night", "d": "dusk", "m": "mauve",
	"w": "wine", "r": "coral", "a": "apricot", "g": "gold",
	"c": "cream", "b": "blue", "s": "sky", "i": "ice",
	"j": "jade", "l": "lime", "p": "plum", "o": "rose", "t": "teal", "x": "stone",
}

const ICONS: Dictionary = {
	"bolt_damage": ["...c...", "..cgc..", "..gag..", ".gacag.", ".argrr.", "..dgd..", "..nnn.."],
	"bolt_rate": ["...cg..", "..cga..", ".cgag..", "..agac.", ".s.gag.", "..cga..", ".s.a..."],
	"throw_damage": ["..aga..", ".dgggd.", ".a.c.a.", ".acgca.", ".a.g.a.", ".dgggd.", "..ddd.."],
	"dash_cooldown": [".g...g.", "gg.c.gg", "agacaga", ".a.c.a.", ".s.g.s.", "..s.s..", "...a..."],
	"pickup_radius": ["..sss..", ".s...s.", "s..g..s", "s.gcg.s", "s..g..s", ".s...s.", "..sss.."],
	"throw_hang": ["...g...", "..g.g..", ".dgggd.", ".a.c.a.", ".acgca.", ".dgggd.", "..s.s.."],
	"zip_bomb": ["r..g..r", ".ra.ar.", "..gcg..", "gaacagg", "..gcg..", ".ra.ar.", "r..g..r"],
	"dash_charges": [".c...c.", "cc.g.cc", "ss.c.ss", ".s.g.s.", "cc.a.cc", ".c...c.", "......."],
	"prism_bounce": ["...g...", "..iic..", ".iissc.", ".iissb.", "gisbbbg", ".gbbbg.", "..ddd.."],
	"beam_charge": [".....c.", "....cg.", "..iicg.", ".isccag", "..iicg.", "....cg.", ".....c."],
	"beam_width": ["....gc.", "..ggcc.", "gaacccc", "ggccccc", "gaacccc", "..ggcc.", "....gc."],
	"wings_glide": [".i...i.", "iis.sii", "iscccsi", ".sgggs.", "..aga..", "..d.d..", "......."],
	"lens_duration": ["..sss..", ".siiis.", "siiccis", "sicgcis", "siiccis", ".siiis.", "..bbb.."],
	"lens_radius": ["..i.i..", ".i.s.i.", "i.sgs.i", ".sgcgs.", "i.sgs.i", ".i.s.i.", "..i.i.."],
	"ember_meter": [".rr.rr.", "ragagar", "ragcgar", "raggagr", ".rgggr.", "..rar..", "...w..."],
	"spare_wick": ["...c...", "..cgc..", "..aga..", ".rrgrr.", ".roror.", "..rrr..", "...w..."],
	"ware_lead": ["..xxx..", ".xmmm..", "xxmxxm.", "xmmmmx.", "xddddx.", ".xxxx..", "......."],
	"ware_slot": ["ggggggg", "g.s.i.g", "g.i.c.g", "g.s.i.g", "g.b.s.g", "g.s.i.g", "ggggggg"],
	"ware_pane": ["..ggg..", ".gscig.", "gsccigg", "gbsiigg", ".gbbbg.", "..ggg..", "......."],
	"ware_wick_oil": ["..ggg..", "...g...", "..aga..", ".aggca.", ".aaaga.", ".rrrrr.", "..www.."],
}
const DEFAULT_ICON: Array[String] = ["...g...", "..gag..", ".gacag.", "..gag..", "...g...", ".......", "......."]


static func draw_frame_ornaments(cv: CanvasItem, isl: int, elapsed: float, all_done: bool) -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxBiomePalette.col(isl, "glow")
	var apr: Color = LxBiomePalette.col(isl, "hi")
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	for rv: Vector2 in [
		Vector2(p.x + 3.0, p.y + 3.0), Vector2(e.x - 5.0, p.y + 3.0),
		Vector2(p.x + 3.0, e.y - 5.0), Vector2(e.x - 5.0, e.y - 5.0),
	]:
		cv.draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), night)
		cv.draw_rect(Rect2(rv, Vector2(2.0, 2.0)), apr)
		cv.draw_rect(Rect2(rv, Vector2(1.0, 1.0)), gold)
	var dy: float = 37.0
	cv.draw_rect(Rect2(28.0, dy, 264.0, 1.0), night)
	cv.draw_rect(Rect2(32.0, dy, 256.0, 1.0), dusk)
	if not LxHudFx.flash_reduced():
		for ei: int in range(4):
			var eu: float = fposmod(elapsed * 0.28 + float(ei) * 0.25, 1.0)
			var ex: float = (p.x + 3.0 + float(ei % 2) * 2.0) if ei < 2 else (e.x - 5.0 + float(ei % 2))
			var ey: float = roundf(e.y - 16.0 - eu * 116.0)
			var ea: float = sin(eu * PI) * 0.72
			if ea > 0.05:
				cv.draw_rect(Rect2(ex, ey, 1.0, 1.0), Color((LxPalette.PAL["cream"] as Color) if ei % 2 == 0 else gold, ea))
	if all_done:
		cv.draw_rect(Rect2(158.0, dy, 5.0, 1.0), LxPalette.PAL["gold"])
		cv.draw_rect(Rect2(160.0, dy - 2.0, 1.0, 5.0), LxPalette.PAL["gold"])
		cv.draw_rect(Rect2(160.0, dy, 1.0, 1.0), LxPalette.PAL["cream"])


static func draw_brazier_icon(cv: CanvasItem, at: Vector2, isl: int, elapsed: float, flare: bool) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var fr: bool = LxHudFx.flash_reduced()
	var tip: float = 0.0 if (fr or fmod(elapsed * 5.2, 1.0) < 0.5) else 1.0
	var bright: bool = fr or flare or fmod(elapsed * 2.6, 1.0) < 0.55
	var c_core: Color = LxBiomePalette.col(isl, "core")
	var c_glow: Color = LxBiomePalette.col(isl, "glow")
	var c_hi: Color = LxBiomePalette.col(isl, "hi")
	var c_mid: Color = LxBiomePalette.col(isl, "mid")
	if flare:
		cv.draw_rect(Rect2(x + 3.0, y - 2.0, 1.0, 2.0), c_core)
		cv.draw_rect(Rect2(x + 2.0, y - 1.0, 3.0, 2.0), c_glow)
	cv.draw_rect(Rect2(x + 2.0 + tip, y, 1.0, 1.0), c_core if bright else c_glow)
	cv.draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 2.0), c_glow)
	cv.draw_rect(Rect2(x + 3.0, y + 1.0, 1.0, 2.0), c_core)
	cv.draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 2.0), c_hi)
	cv.draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), c_glow)
	cv.draw_rect(Rect2(x + 3.0, y + 3.0, 1.0, 1.0), c_core)
	cv.draw_rect(Rect2(x, y + 4.0, 7.0, 1.0), c_mid)
	cv.draw_rect(Rect2(x + 1.0, y + 5.0, 5.0, 1.0), c_hi)
	cv.draw_rect(Rect2(x + 2.0, y + 6.0, 3.0, 1.0), LxPalette.PAL["dusk"])
	cv.draw_rect(Rect2(x + 1.0, y + 7.0, 5.0, 1.0), LxPalette.PAL["night"])


static func draw_shard_gem_icon(cv: CanvasItem, at: Vector2, elapsed: float) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var glint: bool = LxHudFx.flash_reduced() or fmod(elapsed * 2.2, 1.0) < 0.45
	cv.draw_rect(Rect2(x + 3.0, y, 1.0, 1.0), LxPalette.PAL["cream"] if glint else LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 1.0), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 3.0), LxPalette.PAL["apricot"])
	cv.draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(x + 2.0, y + 2.0, 1.0, 2.0), LxPalette.PAL["cream"])
	cv.draw_rect(Rect2(x + 4.0, y + 3.0, 1.0, 2.0), LxPalette.PAL["coral"])
	cv.draw_rect(Rect2(x + 2.0, y + 5.0, 3.0, 1.0), LxPalette.PAL["coral"])
	cv.draw_rect(Rect2(x + 3.0, y + 6.0, 1.0, 1.0), LxPalette.PAL["wine"])
	if glint:
		cv.draw_rect(Rect2(x + 5.0, y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])


static func draw_item_icon(cv: CanvasItem, at: Vector2, uid: String, sel: bool, elapsed: float, dimmed: bool = false) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var rows: Array = ICONS.get(uid, DEFAULT_ICON) as Array
	for r_i: int in range(rows.size()):
		var row: String = str(rows[r_i])
		for c_i: int in range(row.length()):
			var ch: String = row[c_i]
			if ch == ".":
				continue
			var key: String = ("mauve" if (ch == "c" or ch == "g" or ch == "i") else "dusk") if dimmed else str(ICON_PAL.get(ch, "cream"))
			cv.draw_rect(Rect2(x + float(c_i), y + float(r_i), 1.0, 1.0), LxPalette.color(key))
	if sel and not dimmed and (LxHudFx.flash_reduced() or fmod(elapsed * 3.0, 1.0) < 0.45):
		cv.draw_rect(Rect2(x + 6.0, y, 1.0, 1.0), LxPalette.PAL["cream"])


static func draw_rank_pip(cv: CanvasItem, pr: Rect2, filled: bool, sel: bool, idx: int, elapsed: float, next_buy: bool = false) -> void:
	var fr: bool = LxHudFx.flash_reduced()
	cv.draw_rect(pr.grow(1.0), LxPalette.PAL["gold"] if (next_buy and (fr or fmod(elapsed * 3.6, 1.0) < 0.55)) else (LxPalette.PAL["apricot"] if next_buy else LxPalette.PAL["void"]))
	if not filled:
		cv.draw_rect(pr, LxPalette.PAL["night"])
		cv.draw_rect(Rect2(pr.position.x + 1.0, pr.end.y - 1.0, 3.0, 1.0), LxPalette.PAL["dusk"])
		cv.draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["gold"] if next_buy else LxPalette.PAL["dusk"])
		return
	var shimmer: bool = fr or fmod(elapsed * 2.5 + float(idx) * 0.35, 1.0) < 0.4
	cv.draw_rect(pr, LxPalette.PAL["apricot"])
	cv.draw_rect(Rect2(pr.position.x + 1.0, pr.position.y, 3.0, 5.0), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(pr.position.x, pr.position.y + 1.0, 5.0, 3.0), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
	if shimmer or sel:
		cv.draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 1.0, 1.0, 3.0), LxPalette.PAL["cream"])


static func draw_purchase_sparkle(cv: CanvasItem, center: Vector2, isl: int, spark_t: float) -> void:
	var prog: float = clampf(1.0 - (spark_t / SPARK_DUR), 0.0, 1.0)
	var dist: float = roundf(3.0 + prog * 7.0)
	var d_diag: float = roundf(dist * 0.7)
	var col: Color = (LxPalette.PAL["cream"] as Color) if prog < 0.3 else (LxBiomePalette.col(isl, "glow") if prog < 0.65 else LxBiomePalette.col(isl, "hi"))
	var dirs: Array[Vector2] = [
		Vector2(dist, 0.0), Vector2(-dist, 0.0), Vector2(0.0, dist), Vector2(0.0, -dist),
		Vector2(d_diag, d_diag), Vector2(-d_diag, d_diag), Vector2(d_diag, -d_diag), Vector2(-d_diag, -d_diag),
	]
	if prog < 0.35:
		cv.draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
		cv.draw_rect(Rect2(center + Vector2(-3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
	for off: Vector2 in dirs:
		cv.draw_rect(Rect2((center + off).round(), Vector2(1.0, 1.0)), col)


static func draw_shard_pill(cv: CanvasItem, desc_rect: Rect2, shards: int, cost: int, badge_txt: String, badge_col: String) -> void:
	var pill_h: float = 11.0
	var py: float = desc_rect.position.y + 6.0
	var pr_end: float = desc_rect.end.x - 5.0
	if not badge_txt.is_empty():
		var bw: float = float(LxPixelFont.width(badge_txt, 1)) + 10.0
		var bp := Rect2(pr_end - bw, py, bw, pill_h)
		var bdr: String = "pine" if badge_col == "lime" else badge_col
		LxPixelFont.draw_panel(cv, bp, "void", bdr, "night")
		LxPixelFont.draw_centered(cv, badge_txt, bp.get_center().x, py + 3.0, LxPalette.color(badge_col), 1)
		return
	var affordable: bool = shards >= cost
	var before_txt: String = LxStrings.fmt("HUD_SHARDS_FMT", [shards])
	var after_txt: String = LxStrings.fmt("HUD_SHARDS_FMT", [shards - cost])
	var bw2: float = float(LxPixelFont.width(before_txt, 1))
	var aw2: float = float(LxPixelFont.width(after_txt, 1))
	var pill_w: float = 28.0 + bw2 + aw2
	var pill := Rect2(pr_end - pill_w, py, pill_w, pill_h)
	LxPixelFont.draw_panel(cv, pill, "void", "gold" if affordable else "coral", "night")
	var gx: float = pill.position.x + 4.0
	var gy: float = py + 3.0
	cv.draw_rect(Rect2(gx + 1.0, gy, 1.0, 5.0), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(gx, gy + 1.0, 3.0, 3.0), LxPalette.PAL["apricot"])
	cv.draw_rect(Rect2(gx + 1.0, gy + 1.0, 1.0, 2.0), LxPalette.PAL["cream"])
	var bx: float = gx + 6.0
	LxPixelFont.draw_left(cv, before_txt, Vector2(bx, gy), LxPalette.PAL["stone"], 1)
	var ax: float = bx + bw2 + 3.0
	var arr_col: Color = LxPalette.PAL["apricot"] if affordable else LxPalette.PAL["coral"]
	cv.draw_rect(Rect2(ax, gy + 2.0, 5.0, 1.0), arr_col)
	cv.draw_rect(Rect2(ax + 3.0, gy + 1.0, 1.0, 3.0), arr_col)
	cv.draw_rect(Rect2(ax + 2.0, gy, 1.0, 1.0), arr_col)
	cv.draw_rect(Rect2(ax + 2.0, gy + 4.0, 1.0, 1.0), arr_col)
	LxPixelFont.draw_left(cv, after_txt, Vector2(ax + 8.0, gy), LxPalette.PAL["gold"] if affordable else LxPalette.PAL["coral"], 1)


static func draw_scrollbar(cv: CanvasItem, total: int, visible_rows: int, scroll: int) -> void:
	if total <= visible_rows:
		return
	var track := Rect2(289.0, 39.0, 3.0, 86.0)
	cv.draw_rect(track.grow(1.0), LxPalette.PAL["night"])
	cv.draw_rect(track, LxPalette.PAL["void"])
	var thumb_h: float = maxf(14.0, track.size.y * float(visible_rows) / float(total))
	var frac: float = float(scroll) / float(maxi(1, total - visible_rows))
	var thumb_y: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
	cv.draw_rect(Rect2(track.position.x, thumb_y, track.size.x, roundf(thumb_h)), LxPalette.PAL["gold"])
	cv.draw_rect(Rect2(track.position.x, thumb_y, track.size.x, 1.0), LxPalette.PAL["cream"])
