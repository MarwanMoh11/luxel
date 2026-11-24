class_name LxIsland1TutorialGlyphs
extends RefCounted
## Pure-palette pixel-art drawing helpers for Island 1 diegetic tutorial cues.
## Strict Last Light 20-colour palette (LxPalette.PAL / LxPalette.fade_step only).

const PAL: Dictionary = LxPalette.PAL


static func draw_pixel_mouse(ci: CanvasItem, center: Vector2, right_btn: bool, w: float, clock: float, fred: bool) -> void:
	if Lx.input != null and Lx.input.last_device == "gamepad":
		draw_gamepad_glyph(ci, center, "lx_throw" if right_btn else "lx_fire", w, clock, fred)
		return
	var flash_on: bool = fred or fmod(clock, 0.76) < 0.42
	var c_hi: Color = LxPalette.fade_step(w, "cream" if flash_on else "gold")
	var c_rim: Color = LxPalette.fade_step(w, "gold" if flash_on else "apricot")
	if c_hi.a <= 0.0:
		return
	var tl: Vector2 = (center - Vector2(4.0, 5.0)).round()
	var cv: Color = PAL["void"] as Color
	var cs: Color = PAL["stone"] as Color
	var cm: Color = PAL["mauve"] as Color
	var cn: Color = PAL["night"] as Color
	for r: Rect2 in [Rect2(0.0, -2.0, 9.0, 15.0), Rect2(-1.0, -1.0, 11.0, 13.0), Rect2(-2.0, 0.0, 13.0, 11.0)]:
		ci.draw_rect(Rect2(tl + r.position, r.size), cv)
	for r2: Rect2 in [Rect2(1.0, 0.0, 7.0, 11.0), Rect2(0.0, 1.0, 9.0, 9.0)]:
		ci.draw_rect(Rect2(tl + r2.position, r2.size), cs)
	ci.draw_rect(Rect2(tl + Vector2(1.0, 1.0), Vector2(7.0, 9.0)), PAL["dusk"] as Color)
	ci.draw_rect(Rect2(tl + Vector2(2.0, 8.0), Vector2(5.0, 1.0)), cm)
	ci.draw_rect(Rect2(tl + Vector2(1.0, 5.0), Vector2(7.0, 1.0)), cn)
	ci.draw_rect(Rect2(tl + Vector2(4.0, 1.0), Vector2(1.0, 4.0)), cn)
	ci.draw_rect(Rect2(tl + Vector2(4.0, 2.0), Vector2(1.0, 2.0)), cs)
	ci.draw_rect(Rect2(tl + Vector2(1.0, 1.0), Vector2(3.0, 4.0)), cm if right_btn else c_hi)
	ci.draw_rect(Rect2(tl + Vector2(5.0, 1.0), Vector2(3.0, 4.0)), c_hi if right_btn else cm)
	ci.draw_rect(Rect2(tl + Vector2(5.0 if right_btn else 1.0, 4.0), Vector2(3.0, 1.0)), c_rim)
	if flash_on and not fred:
		ci.draw_rect(Rect2(tl + Vector2(10.0 if right_btn else -2.0, 0.0), Vector2.ONE), c_hi)
		ci.draw_rect(Rect2(tl + Vector2(9.0 if right_btn else -1.0, -2.0), Vector2.ONE), c_rim)


static func draw_gamepad_glyph(ci: CanvasItem, center: Vector2, action_id: String, w: float, clock: float, fred: bool) -> void:
	var pulse: bool = fred or fmod(clock, 0.76) < 0.42
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph(action_id), 6) if Lx.input != null else ""
	var c_txt: Color = LxPalette.fade_step(w, "cream" if pulse else "gold")
	if c_txt.a <= 0.0:
		return
	var bw: float = maxf(15.0, (float(LxPixelFont.width(glyph, 1)) if not glyph.is_empty() else 7.0) + 8.0)
	var rect := Rect2(roundf(center.x - bw * 0.5), roundf(center.y - 5.5), bw, 11.0)
	ci.draw_rect(Rect2(rect.position + Vector2(2.0, -1.0), Vector2(bw - 4.0, 1.0)), PAL["void"] as Color)
	LxPixelFont.draw_panel(ci, rect, "dusk", "cream" if pulse else "gold", "void")
	ci.draw_rect(Rect2(rect.position + Vector2(2.0, 1.0), Vector2(bw - 4.0, 1.0)), LxPalette.fade_step(w, "gold" if pulse else "apricot"))
	if not glyph.is_empty():
		LxPixelFont.draw_centered(ci, glyph, rect.position.x + bw * 0.5, rect.position.y + 3.0, c_txt, 1)
	else:
		ci.draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_txt)


static func draw_dash_keycap(ci: CanvasItem, center: Vector2, w: float, clock: float, fred: bool) -> void:
	var pulse: bool = fred or fmod(clock, 0.8) < 0.44
	var col: Color = LxPalette.fade_step(w, "cream" if pulse else "gold")
	if col.a <= 0.0:
		return
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph("lx_dash"), 6) if Lx.input != null else ""
	var bw: float = maxf(15.0, (float(LxPixelFont.width(glyph, 1)) if not glyph.is_empty() else 7.0) + 8.0)
	var rect := Rect2(roundf(center.x - bw * 0.5), roundf(center.y - 5.5), bw, 11.0)
	LxPixelFont.draw_panel(ci, rect, "night", "cream" if pulse else "gold", "void")
	if not glyph.is_empty():
		LxPixelFont.draw_centered(ci, glyph, rect.position.x + bw * 0.5, rect.position.y + 3.0, col, 1)
	else:
		var c := Vector2(roundf(rect.position.x + bw * 0.5), roundf(rect.position.y + 5.0))
		for r: Rect2 in [Rect2(0.0, -2.0, 1.0, 5.0), Rect2(-2.0, 0.0, 5.0, 1.0), Rect2(-1.0, -1.0, 3.0, 1.0)]:
			ci.draw_rect(Rect2(c + r.position, r.size), col)


static func draw_down_chevron(ci: CanvasItem, tip: Vector2, c_hi: Color, c_mid: Color) -> void:
	var p: Vector2 = tip.round()
	var cv: Color = PAL["void"] as Color
	for r: Rect2 in [Rect2(-4.0, -4.0, 3.0, 2.0), Rect2(2.0, -4.0, 3.0, 2.0), Rect2(-2.0, -2.0, 5.0, 3.0), Rect2(-1.0, 0.0, 3.0, 2.0)]:
		ci.draw_rect(Rect2(p + r.position, r.size), cv)
	for rm: Rect2 in [Rect2(-3.0, -3.0, 2.0, 1.0), Rect2(2.0, -3.0, 2.0, 1.0)]:
		ci.draw_rect(Rect2(p + rm.position, rm.size), c_mid)
	for rh: Rect2 in [Rect2(-2.0, -2.0, 2.0, 1.0), Rect2(1.0, -2.0, 2.0, 1.0), Rect2(-1.0, -1.0, 3.0, 1.0), Rect2(0.0, 0.0, 1.0, 1.0)]:
		ci.draw_rect(Rect2(p + rh.position, rh.size), c_hi)


static func draw_right_chevron(ci: CanvasItem, tip: Vector2, c_hi: Color, c_mid: Color) -> void:
	var p: Vector2 = tip.round()
	for rm: Rect2 in [Rect2(-3.0, -3.0, 1.0, 2.0), Rect2(-3.0, 2.0, 1.0, 2.0)]:
		ci.draw_rect(Rect2(p + rm.position, rm.size), c_mid)
	for rh: Rect2 in [Rect2(-2.0, -2.0, 1.0, 2.0), Rect2(-2.0, 1.0, 1.0, 2.0), Rect2(-1.0, -1.0, 1.0, 3.0), Rect2(0.0, 0.0, 1.0, 1.0)]:
		ci.draw_rect(Rect2(p + rh.position, rh.size), c_hi)


static func draw_dir_chevron(ci: CanvasItem, tip: Vector2, dir: Vector2, c_hi: Color, c_mid: Color) -> void:
	var p: Vector2 = tip.round()
	var ang: float = dir.angle() if dir.length_squared() > 0.0001 else 0.0
	var oct: int = posmod(int(roundf(ang / (PI * 0.25))), 8)
	var arm_pts: Array[Vector2] = [p]
	if oct % 2 == 0:
		# Exact symmetric cardinal chevron (E, S, W, N)
		var cd := Vector2(1.0, 0.0) if oct == 0 else (Vector2(0.0, 1.0) if oct == 2 else (Vector2(-1.0, 0.0) if oct == 4 else Vector2(0.0, -1.0)))
		var cn := Vector2(-cd.y, cd.x)
		for k: int in range(1, 4):
			arm_pts.append(p - cd * float(k) + cn * float(k))
			arm_pts.append(p - cd * float(k) - cn * float(k))
	else:
		# Exact symmetric 45-degree diagonal chevron (SE, SW, NW, NE)
		var sx: float = 1.0 if (oct == 1 or oct == 7) else -1.0
		var sy: float = 1.0 if (oct == 1 or oct == 3) else -1.0
		for k: int in range(1, 4):
			arm_pts.append(p + Vector2(-sx * float(k), 0.0))
			arm_pts.append(p + Vector2(0.0, -sy * float(k)))
	var cv: Color = PAL["void"] as Color
	for pt: Vector2 in arm_pts:
		ci.draw_rect(Rect2(pt - Vector2.ONE, Vector2(3.0, 3.0)), cv)
	for idx: int in range(arm_pts.size()):
		var col: Color = c_mid if idx >= 5 else c_hi
		ci.draw_rect(Rect2(arm_pts[idx], Vector2.ONE), col)


static func draw_target_brackets(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var cv: Color = PAL["void"] as Color
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var cx: float = center.x + sx * r
			var cy: float = center.y + sy * r
			var hx: float = cx if sx < 0.0 else cx - 2.0
			var vy: float = cy if sy < 0.0 else cy - 2.0
			ci.draw_rect(Rect2(hx - 1.0, cy - 1.0, 5.0, 3.0), cv)
			ci.draw_rect(Rect2(cx - 1.0, vy - 1.0, 3.0, 5.0), cv)
			ci.draw_rect(Rect2(hx, cy, 3.0, 1.0), col)
			ci.draw_rect(Rect2(cx, vy, 1.0, 3.0), col)


static func draw_pixel_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, segs: int, col: Color) -> void:
	for i: int in range(segs):
		var a: float = float(i) * TAU / float(segs)
		ci.draw_rect(Rect2(Vector2(roundf(center.x + cos(a) * rx), roundf(center.y + sin(a) * ry)), Vector2.ONE), col)


static func draw_gulp_reject_x(ci: CanvasItem, center: Vector2, u: float, w: float, fred: bool) -> void:
	var c_ring: Color = LxPalette.fade_step(w * (1.0 - u * 0.65), "cream" if u < 0.25 else "gold")
	if c_ring.a > 0.0:
		var gr: float = roundf(lerpf(6.0, 14.0 if fred else 18.0, u))
		ci.draw_arc(center.round(), gr, 0.0, TAU, 16, c_ring, 1.0, false)
	var c_coral: Color = LxPalette.fade_step(w * (1.0 - u * 0.40), "coral")
	if c_coral.a <= 0.0:
		return
	var c_hi: Color = LxPalette.fade_step(w * (1.0 - u * 0.45), "cream" if (u < 0.28 and not fred) else "rose")
	var cv: Color = PAL["void"] as Color
	var xc: Vector2 = (center + Vector2(0.0, -roundf(u * 4.0))).round()
	for k: int in range(-2, 3):
		var fk: float = float(k)
		ci.draw_rect(Rect2(xc + Vector2(fk - 1.0, fk - 1.0), Vector2(3.0, 3.0)), cv)
		ci.draw_rect(Rect2(xc + Vector2(fk - 1.0, -fk - 1.0), Vector2(3.0, 3.0)), cv)
	for k2: int in range(-2, 3):
		var fk2: float = float(k2)
		var col: Color = c_hi if absi(k2) <= 1 else c_coral
		ci.draw_rect(Rect2(xc + Vector2(fk2, fk2), Vector2.ONE), col)
		ci.draw_rect(Rect2(xc + Vector2(fk2, -fk2), Vector2.ONE), col)


static func draw_bait_guide(ci: CanvasItem, start_p: Vector2, bait_p: Vector2, w: float, clock: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var bc: Vector2 = bait_p.round()
	var spd: float = 0.35 if fred else 0.78
	for ri: int in range(2):
		var p: float = fmod(clock * spd + float(ri) * 0.5, 1.0)
		var rcol: Color = LxPalette.fade_step(w * (1.0 - p * 0.72), "cream" if p < 0.30 else "gold")
		if rcol.a > 0.0:
			draw_pixel_ellipse(ci, bc, roundf(lerpf(7.0, 15.0, p)), roundf(lerpf(3.5, 7.5, p)), 14, rcol)
	var cv: Color = PAL["void"] as Color
	ci.draw_rect(Rect2(bc + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), cv)
	ci.draw_rect(Rect2(bc + Vector2(-1.0, -2.0), Vector2(3.0, 5.0)), cv)
	ci.draw_rect(Rect2(bc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), c_gold)
	ci.draw_rect(Rect2(bc + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), c_cream if (fred or sin(clock * 4.2) > 0.0) else c_gold)
	var arc_h: float = clampf(start_p.distance_to(bait_p) * 0.42, 18.0, 36.0)
	var ctrl: Vector2 = start_p.lerp(bait_p, 0.5) + Vector2(0.0, -arc_h)
	var shift: float = 0.0 if fred else fmod(clock * 0.48, 1.0 / 7.0)
	for i: int in range(7):
		var u: float = clampf(float(i) / 7.0 + shift, 0.06, 0.94)
		var pt: Vector2 = quad_bezier(start_p, ctrl, bait_p, u).round()
		ci.draw_rect(Rect2(pt + Vector2(-1.0, -1.0), Vector2(4.0, 3.0)), cv)
		ci.draw_rect(Rect2(pt, Vector2(2.0, 1.0)), c_cream if u > 0.68 else (c_gold if i % 2 == 0 else c_apr))
	var tbob: float = 0.0 if fred else roundf(sin(clock * 4.0) * 1.5)
	draw_down_chevron(ci, bc + Vector2(0.0, -11.0 + tbob), c_cream, c_gold)


static func draw_strike_chevrons(ci: CanvasItem, origin: Vector2, target: Vector2, w: float, clock: float, fred: bool, is_dash: bool) -> void:
	var delta_v: Vector2 = target - origin
	if delta_v.length() < 12.0:
		return
	var dir: Vector2 = delta_v.normalized()
	var c_hi: Color = LxPalette.fade_step(w, "cream")
	var c_mid: Color = LxPalette.fade_step(w, "ice" if is_dash else "gold")
	var c_low: Color = LxPalette.fade_step(w, "sky" if is_dash else "apricot")
	if c_mid.a <= 0.0:
		return
	var spd: float = 0.60 if fred else 1.45
	for i: int in range(4):
		var u: float = fmod(clock * spd + float(i) * 0.25, 1.0)
		var pt: Vector2 = origin.lerp(target, lerpf(0.18, 0.84, u)).round()
		draw_dir_chevron(ci, pt, dir, c_hi if u > 0.62 else c_mid, c_low)
	if not is_dash:
		var rr: float = 9.0 + (0.0 if fred else roundf(sin(clock * 5.2) * 1.5))
		ci.draw_arc(target.round(), rr, 0.0, TAU, 16, c_mid, 1.0, false)


static func draw_zip_blast_zone(ci: CanvasItem, lan_center: Vector2, sn_center: Vector2, hot: bool, w: float, clock: float, fred: bool) -> void:
	var c_hi: Color = LxPalette.fade_step(w, "cream" if hot else "gold")
	var c_mid: Color = LxPalette.fade_step(w, "gold" if hot else "apricot")
	if c_mid.a <= 0.0:
		return
	var lc: Vector2 = lan_center.round()
	var pulse_r: float = 21.0 + (0.0 if fred else roundf(sin(clock * (7.0 if hot else 3.8)) * 1.5))
	var segs: int = 16
	var rot: float = 0.0 if fred else clock * (1.1 if hot else 0.45)
	for i: int in range(segs):
		if i % 2 != 0:
			continue
		var a0: float = rot + float(i) * (TAU / float(segs))
		var a1: float = rot + (float(i) + 0.65) * (TAU / float(segs))
		ci.draw_arc(lc, pulse_r, a0, a1, 3, c_hi if (hot and i % 4 == 0) else c_mid, 1.0, false)
	var d_sn: float = lc.distance_to(sn_center)
	if hot and d_sn > 12.0 and d_sn <= 96.0:
		var dir_in: Vector2 = (lc - sn_center) / d_sn
		var shift: float = 0.0 if fred else fmod(clock * 20.0, 7.0)
		var d: float = 10.0 + shift
		while d < d_sn - 10.0:
			var pt: Vector2 = (sn_center + dir_in * d).round()
			ci.draw_rect(Rect2(pt, Vector2(2.0, 1.0)), c_hi if d > d_sn - 24.0 else c_mid)
			d += 7.0


static func draw_stolen_alert_ring(ci: CanvasItem, sn_center: Vector2, w: float, clock: float, fred: bool) -> void:
	var c_coral: Color = LxPalette.fade_step(w, "coral")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	if c_coral.a <= 0.0:
		return
	var sc: Vector2 = sn_center.round()
	var p: float = 0.35 if fred else fmod(clock * 1.45, 1.0)
	var r: float = roundf(lerpf(10.0, 20.0, p))
	var rc: Color = LxPalette.fade_step(w * (1.0 - p * 0.65), "cream" if p < 0.28 else "coral")
	if rc.a > 0.0:
		ci.draw_arc(sc, r, 0.0, TAU, 16, rc, 1.0, false)
	var br: float = 11.0 + (0.0 if fred else roundf(sin(clock * 8.0) * 1.5))
	draw_target_brackets(ci, sc, br, c_cream if (fred or fmod(clock, 0.36) < 0.18) else c_coral)


static func draw_stage0_lantern(ci: CanvasItem, wpos: Vector2, lpos: Vector2, w: float, clock: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var spd: float = 0.35 if fred else 0.72
	for ri: int in range(2):
		var p: float = fmod(clock * spd + float(ri) * 0.5, 1.0)
		var rcol: Color = LxPalette.fade_step(w * (1.0 - p * 0.78), "cream" if p < 0.32 else "gold")
		if rcol.a > 0.0:
			draw_pixel_ellipse(ci, lpos + Vector2(0.0, 1.0), roundf(lerpf(9.0, 21.0, p)), roundf(lerpf(4.0, 9.0, p)), 14, rcol)
	var start_p: Vector2 = wpos + Vector2(0.0, -5.0)
	var end_p: Vector2 = lpos + Vector2(0.0, -4.0)
	if start_p.distance_to(end_p) >= 16.0:
		var m_spd: float = 0.28 if fred else 0.52
		for mi: int in range(7):
			var u: float = fmod(clock * m_spd + float(mi) / 7.0, 1.0)
			var mp: Vector2 = start_p.lerp(end_p, u)
			mp.y += roundf(sin(u * TAU + float(mi) * 1.3 + clock * (1.2 if fred else 2.6)) * 3.5)
			ci.draw_rect(Rect2(mp.round(), Vector2(2.0, 1.0) if u > 0.6 else Vector2.ONE), c_cream if u > 0.75 else (c_gold if u > 0.35 else c_apr))
	draw_down_chevron(ci, lpos + Vector2(0.0, -21.0 + (0.0 if fred else roundf(sin(clock * 4.2) * 2.0))), c_cream, c_gold)


static func draw_stage1_shoot(ci: CanvasItem, wpos: Vector2, w_target: Vector2, w: float, clock: float, fred: bool) -> void:
	var tpos: Vector2 = w_target + Vector2(0.0, -7.0)
	var origin: Vector2 = wpos + Vector2(0.0, -6.0)
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var delta_v: Vector2 = tpos - origin
	var dist: float = delta_v.length()
	if dist > 28.0:
		var dir: Vector2 = delta_v / dist
		var d: float = 15.0 + (0.0 if fred else fmod(clock * 18.0, 8.0))
		while d < dist - 14.0:
			var dp: Vector2 = (origin + dir * d).round()
			ci.draw_rect(Rect2(dp + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), PAL["void"] as Color)
			ci.draw_rect(Rect2(dp, Vector2(2.0, 1.0)), c_cream if d > dist - 34.0 else (c_gold if int(d / 8.0) % 2 == 0 else c_apr))
			d += 8.0
	var br: float = 11.0 + (0.0 if fred else roundf(sin(clock * 4.0) * 1.2))
	draw_target_brackets(ci, tpos.round(), br, c_cream if (fred or sin(clock * 4.0) > 0.2) else c_gold)
	var mid: Vector2 = wpos.lerp(w_target, 0.5)
	draw_pixel_mouse(ci, (mid + Vector2(0.0, -18.0 + (0.0 if fred else roundf(sin(clock * 3.4) * 1.0)))).round(), false, w, clock, fred)


static func draw_stage2_path(ci: CanvasItem, pts: Array[Vector2], next_pos: Vector2, show_head: bool, celebrate_t: float, w: float, clock: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var count: int = 14 if celebrate_t > 0.0 else 8
	var spd: float = (0.20 if fred else 0.36) if celebrate_t > 0.0 else (0.10 if fred else 0.18)
	for i: int in range(count):
		var u: float = fmod(clock * spd + float(i) / float(count), 1.0)
		var sway := Vector2.ZERO if fred else Vector2(cos(clock * 2.3 + float(i) * 2.1) * 2.0, sin(clock * 3.0 + float(i) * 1.7) * 3.0)
		var fp: Vector2 = (sample_polyline(pts, u) + sway).round()
		var bright: bool = (i % 3 == 0) or celebrate_t > 0.5
		ci.draw_rect(Rect2(fp, Vector2(2.0, 1.0) if bright else Vector2.ONE), c_cream if bright else c_gold)
		if not fred and bright:
			ci.draw_rect(Rect2(fp + Vector2(2.0, 1.0), Vector2.ONE), c_apr)
	if not show_head:
		return
	var head: Vector2 = (next_pos + Vector2(0.0, -14.0)).round()
	var pu: float = 0.45 if fred else fmod(clock * 0.85, 1.0)
	var lcol: Color = LxPalette.fade_step(w * (1.0 - pu * 0.7), "cream" if pu < 0.35 else "gold")
	if lcol.a > 0.0:
		ci.draw_arc(head, roundf(lerpf(5.0, 14.0, pu)), 0.0, TAU, 16, lcol, 1.0, false)
	if fred or int(clock * 4.0) % 2 == 0:
		ci.draw_rect(Rect2(head + Vector2(0.0, -6.0), Vector2.ONE), c_cream)


static func draw_stage3_orchard(ci: CanvasItem, s_pos: Vector2, b_pos: Vector2, w: float, clock: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var ctrl: Vector2 = s_pos.lerp(b_pos, 0.5) + Vector2(0.0, 3.0)
	var spd: float = 0.14 if fred else 0.28
	for i: int in range(4):
		var u: float = fmod(clock * spd + float(i) * 0.25, 1.0)
		var pt: Vector2 = quad_bezier(s_pos, ctrl, b_pos, u).round()
		ci.draw_rect(Rect2(pt, Vector2.ONE), c_gold if (i % 2 == 0) else c_apr)


static func draw_stage3_chasm(ci: CanvasItem, top_p: Vector2, bot_p: Vector2, show_cap: bool, w: float, clock: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0:
		return
	var spd: float = 0.45 if fred else 1.15
	for ci_i: int in range(3):
		var u: float = fmod(clock * spd + float(ci_i) / 3.0, 1.0)
		var cy: float = roundf(lerpf(top_p.y + 6.0, bot_p.y - 4.0, u))
		draw_down_chevron(ci, Vector2(top_p.x, cy), c_cream if u > 0.65 else (c_gold if u > 0.28 else c_apr), c_gold)
	ci.draw_rect(Rect2(bot_p.x - 4.0, bot_p.y + 2.0, 9.0, 1.0), LxPalette.fade_step(w, "mauve"))
	ci.draw_rect(Rect2(bot_p.x - 2.0, bot_p.y + 2.0, 5.0, 1.0), c_gold)
	if show_cap:
		draw_dash_keycap(ci, Vector2(184.0, 196.0 + (0.0 if fred else roundf(sin(clock * 3.4) * 1.0))).round(), w, clock, fred)


static func draw_stage4_river(ci: CanvasItem, wpos: Vector2, brazier_pos: Vector2, pier_lip: Vector2, lan_out: bool, lan_pos: Vector2, w: float, clock: float, fred: bool) -> void:
	var bob: float = 0.0 if fred else roundf(sin(clock * 3.4) * 1.0)
	var mpos: Vector2 = (wpos + Vector2(14.0, -22.0 + bob)).round()
	if lan_out and lan_pos.x >= 1004.0:
		var lpos: Vector2 = lan_pos + Vector2(0.0, -4.0)
		var origin: Vector2 = wpos + Vector2(0.0, -6.0)
		var c_ice: Color = LxPalette.fade_step(w, "ice")
		var c_sky: Color = LxPalette.fade_step(w, "sky")
		var c_cream: Color = LxPalette.fade_step(w, "cream")
		if c_ice.a > 0.0:
			var spd_z: float = 0.55 if fred else 1.35
			for zi: int in range(4):
				var u: float = fmod(clock * spd_z + float(zi) * 0.25, 1.0)
				draw_right_chevron(ci, origin.lerp(lpos, lerpf(0.16, 0.84, u)).round(), c_cream if u > 0.65 else c_ice, c_sky)
			ci.draw_arc(lpos.round(), 10.0 + (0.0 if fred else roundf(sin(clock * 5.0) * 1.5)), 0.0, TAU, 16, c_ice, 1.0, false)
		draw_pixel_mouse(ci, mpos, false, w, clock, fred)
		return
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	var c_mist: Color = LxPalette.fade_step(w, "stone")
	var c_slate: Color = LxPalette.fade_step(w, "mauve")
	if c_gold.a <= 0.0:
		return
	var start_p := Vector2(clampf(wpos.x + 8.0, 948.0, pier_lip.x), clampf(wpos.y - 6.0, 336.0, 380.0))
	var end_p: Vector2 = brazier_pos + Vector2(0.0, -6.0)
	var ctrl: Vector2 = start_p.lerp(end_p, 0.5) + Vector2(0.0, -44.0)
	var shift: float = 0.0 if fred else fmod(clock * 0.45, 1.0 / 9.0)
	for i: int in range(9):
		var u: float = clampf(float(i) / 9.0 + shift, 0.05, 0.96)
		var pt: Vector2 = quad_bezier(start_p, ctrl, end_p, u).round()
		ci.draw_rect(Rect2(pt + Vector2(-2.0, -1.0), Vector2(5.0, 4.0)), PAL["void"] as Color)
		ci.draw_rect(Rect2(pt + Vector2(-1.0, 0.0), Vector2(3.0, 2.0)), c_gold if i % 2 == 0 else c_apr)
		ci.draw_rect(Rect2(pt + Vector2(0.0, 0.0), Vector2(2.0, 1.0)), c_cream if (u > 0.60 or i % 2 == 0) else c_gold)
		ci.draw_rect(Rect2(pt + Vector2(1.0, 1.0), Vector2(1.0, 1.0)), c_cream if u > 0.72 else c_gold)
	var bc: Vector2 = brazier_pos.round()
	var wisp_spd: float = 0.25 if fred else 0.52
	for wi: int in range(3):
		var wu: float = fmod(clock * wisp_spd + float(wi) / 3.0, 1.0)
		var wx: float = roundf(sin(clock * (1.2 if fred else 2.2) + float(wi) * 2.1) * (1.2 + wu * 1.6))
		var wy: float = roundf(-9.0 - wu * 10.0)
		var wc: Color = c_slate if wu < 0.45 else (c_mist if wu < 0.80 else (PAL["dusk"] as Color))
		ci.draw_rect(Rect2(bc + Vector2(wx, wy), Vector2(2.0, 1.0) if wu < 0.55 else Vector2.ONE), wc)
	var tbob: float = 0.0 if fred else roundf(sin(clock * 4.2) * 1.5)
	var dc: Vector2 = bc + Vector2(0.0, -29.0 + tbob)
	var hot_d: bool = fred or sin(clock * 4.2) > 0.1
	ci.draw_rect(Rect2(dc + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), PAL["void"] as Color)
	ci.draw_rect(Rect2(dc + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), PAL["void"] as Color)
	ci.draw_rect(Rect2(dc + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), c_gold)
	ci.draw_rect(Rect2(dc + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), c_cream if hot_d else c_gold)
	ci.draw_rect(Rect2(dc + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), c_cream if hot_d else c_gold)
	draw_down_chevron(ci, bc + Vector2(0.0, -20.0 + tbob), c_cream if hot_d else c_gold, c_apr)
	draw_pixel_mouse(ci, mpos, true, w, clock, fred)


static func quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv: float = 1.0 - t
	return a * (inv * inv) + b * (2.0 * inv * t) + c * (t * t)


static func sample_polyline(pts: Array[Vector2], t: float) -> Vector2:
	if pts.size() <= 1:
		return pts[0] if not pts.is_empty() else Vector2.ZERO
	var total: float = 0.0
	var lens: Array[float] = []
	for i: int in range(pts.size() - 1):
		var d: float = pts[i].distance_to(pts[i + 1])
		lens.append(d)
		total += d
	var target_d: float = clampf(t, 0.0, 1.0) * maxf(0.001, total)
	var acc: float = 0.0
	for i: int in range(lens.size()):
		if acc + lens[i] >= target_d or i == lens.size() - 1:
			return pts[i].lerp(pts[i + 1], clampf((target_d - acc) / maxf(0.001, lens[i]), 0.0, 1.0))
		acc += lens[i]
	return pts[pts.size() - 1]
