class_name LxPixelGlyphs
extends RefCounted
## Shared pure-palette pixel-art teaching glyphs for Islands 2..8.
## Strict Last Light 20-colour palette (LxPalette.PAL / LxPalette.fade_step only).
## Zero raw player-facing string literals; key labels always come from Lx.input.

const PAL: Dictionary = LxPalette.PAL


static func draw_dir_chevron(ci: CanvasItem, tip: Vector2, dir: Vector2, c_hi: Color, c_mid: Color) -> void:
	if c_hi.a <= 0.0 and c_mid.a <= 0.0:
		return
	var p: Vector2 = tip.round()
	var ang: float = dir.angle() if dir.length_squared() > 0.0001 else 0.0
	var oct: int = posmod(int(roundf(ang / (PI * 0.25))), 8)
	var arm_pts: Array[Vector2] = [p]
	if oct % 2 == 0:
		# Exact symmetric cardinal chevron (E, S, W, N)
		var cd := Vector2(1.0, 0.0) if oct == 0 else (
			Vector2(0.0, 1.0) if oct == 2 else (
				Vector2(-1.0, 0.0) if oct == 4 else Vector2(0.0, -1.0)
			)
		)
		var cn := Vector2(-cd.y, cd.x)
		for k: int in range(1, 4):
			arm_pts.append(p - cd * float(k) + cn * float(k))
			arm_pts.append(p - cd * float(k) - cn * float(k))
	else:
		# Exact symmetric 45-degree diagonal right-angle arrowhead (SE, SW, NW, NE)
		var sx: float = 1.0 if (oct == 1 or oct == 7) else -1.0
		var sy: float = 1.0 if (oct == 1 or oct == 3) else -1.0
		for k: int in range(1, 4):
			arm_pts.append(p + Vector2(-sx * float(k), 0.0))
			arm_pts.append(p + Vector2(0.0, -sy * float(k)))
	var cv := Color(PAL["void"] as Color, clampf(maxf(c_hi.a, c_mid.a), 0.0, 1.0))
	for pt: Vector2 in arm_pts:
		ci.draw_rect(Rect2(pt - Vector2.ONE, Vector2(3.0, 3.0)), cv)
	for idx: int in range(arm_pts.size()):
		var col: Color = c_mid if idx >= 5 else c_hi
		ci.draw_rect(Rect2(arm_pts[idx], Vector2.ONE), col)


static func draw_reject_x(ci: CanvasItem, center: Vector2, u: float, w: float, fred: bool) -> void:
	var uu: float = clampf(u, 0.0, 1.0)
	var fr: bool = fred or LxHudFx.flash_reduced()
	var c_ring: Color = LxPalette.fade_step(w * (1.0 - uu * 0.65), "cream" if uu < 0.25 else "gold")
	if c_ring.a > 0.0:
		var gr: float = roundf(lerpf(6.0, 14.0 if fr else 18.0, uu))
		ci.draw_arc(center.round(), gr, 0.0, TAU, 16, c_ring, 1.0, false)
	var c_coral: Color = LxPalette.fade_step(w * (1.0 - uu * 0.40), "coral")
	if c_coral.a <= 0.0:
		return
	var c_hi: Color = LxPalette.fade_step(w * (1.0 - uu * 0.45), "cream" if (uu < 0.28 and not fr) else "rose")
	var cv: Color = PAL["void"] as Color
	var xc: Vector2 = (center + Vector2(0.0, -roundf(uu * 4.0))).round()
	for k: int in range(-2, 3):
		var fk: float = float(k)
		ci.draw_rect(Rect2(xc + Vector2(fk - 1.0, fk - 1.0), Vector2(3.0, 3.0)), cv)
		ci.draw_rect(Rect2(xc + Vector2(fk - 1.0, -fk - 1.0), Vector2(3.0, 3.0)), cv)
	for k2: int in range(-2, 3):
		var fk2: float = float(k2)
		var col: Color = c_hi if absi(k2) <= 1 else c_coral
		ci.draw_rect(Rect2(xc + Vector2(fk2, fk2), Vector2.ONE), col)
		ci.draw_rect(Rect2(xc + Vector2(fk2, -fk2), Vector2.ONE), col)


static func draw_target_brackets(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.0:
		return
	var c: Vector2 = center.round()
	var rr: float = roundf(r)
	var cv := Color(PAL["void"] as Color, col.a)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var cx: float = c.x + sx * rr
			var cy: float = c.y + sy * rr
			var hx: float = cx if sx < 0.0 else cx - 2.0
			var vy: float = cy if sy < 0.0 else cy - 2.0
			ci.draw_rect(Rect2(hx - 1.0, cy - 1.0, 5.0, 3.0), cv)
			ci.draw_rect(Rect2(cx - 1.0, vy - 1.0, 3.0, 5.0), cv)
			ci.draw_rect(Rect2(hx, cy, 3.0, 1.0), col)
			ci.draw_rect(Rect2(cx, vy, 1.0, 3.0), col)


static func draw_action_keycap(
	ci: CanvasItem,
	center: Vector2,
	action_id: String,
	w: float,
	clock: float,
	fred: bool,
	accent_key: String = "gold"
) -> void:
	var acc_k: String = accent_key if PAL.has(accent_key) else "gold"
	var fr: bool = fred or LxHudFx.flash_reduced()
	var pulse: bool = fr or fmod(clock, 0.78) < 0.44
	var border_k: String = "cream" if pulse else acc_k
	var c_txt: Color = LxPalette.fade_step(w, border_k)
	if c_txt.a <= 0.0:
		return
	var c_border: Color = LxPalette.fade_step(w, border_k)
	var raw_glyph: String = Lx.input.get_glyph(action_id) if Lx.input != null else ""
	var glyph: String = LxStrings.sanitize(raw_glyph, 6)
	if glyph == "-":
		glyph = ""
	var tw: float = float(LxPixelFont.width(glyph, 1)) if not glyph.is_empty() else 5.0
	var bw: float = maxf(15.0, tw + 8.0)
	var rect := Rect2(roundf(center.x - bw * 0.5), roundf(center.y - 5.5), bw, 11.0)
	var is_pad: bool = Lx.input != null and Lx.input.last_device == "gamepad"
	var cv: Color = PAL["void"] as Color
	if is_pad:
		ci.draw_rect(Rect2(rect.position + Vector2(2.0, -1.0), Vector2(bw - 4.0, 1.0)), cv)
	ci.draw_rect(rect, cv)
	ci.draw_rect(rect.grow(-1.0), c_border)
	ci.draw_rect(rect.grow(-2.0), PAL["dusk"] as Color if is_pad else PAL["night"] as Color)
	if not glyph.is_empty():
		LxPixelFont.draw_centered(ci, glyph, rect.position.x + bw * 0.5, rect.position.y + 3.0, c_txt, 1, cv)
	else:
		var c := Vector2(roundf(rect.position.x + bw * 0.5), roundf(rect.position.y + 5.0))
		ci.draw_rect(Rect2(c + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), c_txt)
		ci.draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), c_txt)


static func opposite_glyph_pos(wpos: Vector2, target: Vector2, bob: float = 0.0) -> Vector2:
	var side: float = -16.0 if target.x >= wpos.x else 16.0
	return (wpos + Vector2(side, -22.0 + bob)).round()
