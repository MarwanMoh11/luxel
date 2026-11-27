class_name LxBossTelegraphFx
extends RefCounted
## Shared ground-projected boss telegraph primitives for Luxel 1.0.
## Rendered as pixel-stepped carved rune rings, dithered ground scorches, and drifting
## ember/frost flecks (zero smooth vector draw_arc/draw_circle rings).
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and respects LxHudFx.flash_reduced().

const PAL: Dictionary = LxPalette.PAL


static func _col(key: String, fallback: String = "coral") -> Color:
	return LxPalette.color(key, fallback)


static func _draw_pixel_rune_arc(
	ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float,
	col: Color, dark_col: Color, thick: float = 2.0, dashed: bool = false, phase: float = 0.0
) -> void:
	var span: float = absf(a1 - a0)
	if span < 0.01 or r < 2.0:
		return
	var arc_len: float = r * span
	var step_px: float = 3.0 if dashed else 2.0
	var count: int = clampi(int(roundf(arc_len / step_px)), 6, 72)
	var bsz := Vector2(thick, thick)
	for i: int in range(count):
		if dashed and (i % 3 == 2):
			continue
		var frac: float = float(i) / float(maxi(1, count - (0 if span >= TAU - 0.02 else 1)))
		var ang: float = lerpf(a0, a1, frac) + phase
		var p: Vector2 = (c + Vector2(cos(ang) * r, sin(ang) * r)).round()
		ci.draw_rect(Rect2(p + Vector2(0.0, 1.0), bsz), dark_col)
		ci.draw_rect(Rect2(p, bsz), col)


static func _draw_dither_fill(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# Pixel-stepped horizontal scanline wash (crisp retro ground scorch without smooth vector edges)
	var ri: int = int(roundf(r))
	if ri < 3:
		return
	var step_y: int = 2 if ri <= 36 else 3
	var y: int = -ri + 1
	while y < ri:
		var dx: float = sqrt(maxf(0.0, r * r - float(y * y)))
		var hw: float = floorf(dx)
		if hw >= 1.0:
			ci.draw_rect(Rect2(c.x - hw, c.y + float(y), hw * 2.0, 1.0), col)
		y += step_y


static func _draw_pixel_line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, dark_col: Color, dashed: bool = false) -> void:
	var dist: float = a.distance_to(b)
	if dist < 1.0:
		return
	var step_px: float = 3.0 if dashed else 2.0
	var steps: int = clampi(int(roundf(dist / step_px)), 2, 96)
	for i: int in range(steps + 1):
		if dashed and (i % 3 == 2):
			continue
		var p: Vector2 = a.lerp(b, float(i) / float(steps)).round()
		ci.draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), dark_col)
		ci.draw_rect(Rect2(p, Vector2(2.0, 1.0)), col)


static func _draw_rune_chevron(ci: CanvasItem, tip: Vector2, dir: Vector2, wing: float, back: float, col: Color, dark_col: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var wl: Vector2 = (tip - dir * back - perp * wing).round()
	var wr: Vector2 = (tip - dir * back + perp * wing).round()
	_draw_pixel_line(ci, wl, tip, col, dark_col, false)
	_draw_pixel_line(ci, wr, tip, col, dark_col, false)
	ci.draw_rect(Rect2(tip.round() - Vector2.ONE, Vector2(2.0, 2.0)), col)


static func draw_ground_danger_ring(ci: CanvasItem, center: Vector2, rad: float, urgency: float, clk: float, fill_key: String = "coral", rim_key: String = "gold") -> void:
	var c: Vector2 = center.round()
	var r: float = maxf(4.0, rad)
	var u: float = clampf(urgency, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 14.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = Color(PAL["void"] as Color, 0.85)
	var c_cream: Color = PAL["cream"] as Color

	_draw_dither_fill(ci, c, r - 1.0, Color(c_fill, lerpf(0.16, 0.28, u)))
	var outer_c: Color = c_rim if (u > 0.72 and pulse_hi) else c_fill
	_draw_pixel_rune_arc(ci, c, r, 0.0, TAU, outer_c, c_void, 2.0, true, clk * (0.18 if fred else 0.35))

	# Contracting carved rune pulse ring showing exact impact beat
	var r_in: float = maxf(3.0, roundf(r * lerpf(0.84, 0.30, u)))
	var c_in: Color = c_cream if (u > 0.78 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	_draw_pixel_rune_arc(ci, c, r_in, 0.0, TAU, c_in, c_void, 1.0, false, -clk * 0.25)

	# 4 carved compass notches + rising ember/frost flecks on the outer rim
	for ti: int in range(4):
		var a: float = float(ti) * (PI * 0.5)
		var td: Vector2 = Vector2(cos(a), sin(a))
		var p_in: Vector2 = (c + td * maxf(2.0, r - 3.0)).round()
		var p_out: Vector2 = (c + td * (r + 2.0)).round()
		_draw_pixel_line(ci, p_in, p_out, c_cream if u > 0.60 else c_in, c_void, false)
		var su: float = fposmod(clk * (0.9 if fred else 1.6) + float(ti) * 0.25, 1.0)
		var sp: Vector2 = (c + Vector2.from_angle(a + 0.78) * (r - 1.0) + Vector2(0.0, -su * 6.0)).round()
		ci.draw_rect(Rect2(sp, Vector2.ONE), Color(c_cream if su < 0.35 else c_rim, (1.0 - su) * 0.85))
		if u >= 0.80:
			var dp: Vector2 = (c + Vector2.from_angle(a + 0.785398) * r).round()
			ci.draw_rect(Rect2(dp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
			ci.draw_rect(Rect2(dp - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if pulse_hi else c_rim)


static func draw_ground_danger_lane(ci: CanvasItem, from_p: Vector2, to_p: Vector2, half_w: float, urgency: float, clk: float, fill_key: String = "coral", rim_key: String = "gold") -> void:
	var delta: Vector2 = to_p - from_p
	var length: float = delta.length()
	if length < 1.0:
		return
	var dir: Vector2 = delta / length
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var hw: float = maxf(2.0, half_w)
	var u: float = clampf(urgency, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 14.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = Color(PAL["void"] as Color, 0.85)
	var c_cream: Color = PAL["cream"] as Color

	var a0: Vector2 = (from_p - perp * hw).round()
	var a1: Vector2 = (to_p - perp * hw).round()
	var b1: Vector2 = (to_p + perp * hw).round()
	var b0: Vector2 = (from_p + perp * hw).round()
	ci.draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), Color(c_fill, lerpf(0.11, 0.20, u)))

	var rail_c: Color = c_cream if (u > 0.72 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	_draw_pixel_line(ci, a0, a1, rail_c, c_void, true)
	_draw_pixel_line(ci, b0, b1, rail_c, c_void, true)
	_draw_pixel_line(ci, a1, b1, c_cream if u > 0.60 else rail_c, c_void, false)

	var chev_n: int = 3 if length >= 56.0 else 2
	var wing: float = minf(hw * 0.68, 8.0)
	var back: float = minf(5.0, length * 0.14)
	var c_chev: Color = c_cream if (u > 0.58 and pulse_hi) else c_rim
	for i: int in range(chev_n):
		var base_t: float = (float(i) + 0.5) / float(chev_n)
		var t_pos: float = base_t if fred else fposmod(base_t + clk * 0.62, 1.0)
		var tip: Vector2 = from_p.lerp(to_p, clampf(t_pos, 0.15, 0.90)).round()
		_draw_rune_chevron(ci, tip, dir, wing, back, c_chev, c_void)
	if u >= 0.80:
		for ep: Vector2 in [a1, b1]:
			ci.draw_rect(Rect2(ep - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
			ci.draw_rect(Rect2(ep - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if pulse_hi else c_rim)


static func draw_ground_danger_sector(ci: CanvasItem, origin: Vector2, ang0: float, ang1: float, rad: float, urgency: float, clk: float, fill_key: String = "coral", rim_key: String = "gold") -> void:
	var span: float = absf(ang1 - ang0)
	if span < 0.01:
		return
	var o: Vector2 = origin.round()
	var r: float = maxf(6.0, rad)
	var u: float = clampf(urgency, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 14.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = Color(PAL["void"] as Color, 0.85)
	var c_cream: Color = PAL["cream"] as Color
	var steps: int = clampi(int(ceilf(span * 8.0)), 6, 18)

	var pts: PackedVector2Array = PackedVector2Array([o])
	for i: int in range(steps + 1):
		var a: float = lerpf(ang0, ang1, float(i) / float(steps))
		pts.append((o + Vector2.from_angle(a) * r).round())
	ci.draw_colored_polygon(pts, Color(c_fill, lerpf(0.11, 0.20, u)))

	var p_s: Vector2 = (o + Vector2.from_angle(ang0) * r).round()
	var p_e: Vector2 = (o + Vector2.from_angle(ang1) * r).round()
	var a_lo: float = minf(ang0, ang1)
	var a_hi: float = maxf(ang0, ang1)
	var rim_c: Color = c_cream if (u > 0.72 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	_draw_pixel_rune_arc(ci, o, r, a_lo, a_hi, rim_c, c_void, 2.0, true, 0.0)
	_draw_pixel_line(ci, o, p_s, c_cream if u > 0.65 else c_rim, c_void, true)
	_draw_pixel_line(ci, o, p_e, c_fill, c_void, true)

	var r_in: float = maxf(6.0, roundf(r * lerpf(0.82, 0.34, u)))
	_draw_pixel_rune_arc(ci, o, r_in, a_lo, a_hi, c_cream if (u > 0.78 and pulse_hi) else c_rim, c_void, 1.0, false, 0.0)
	if u >= 0.80:
		var mid_tip: Vector2 = (o + Vector2.from_angle((a_lo + a_hi) * 0.5) * r).round()
		ci.draw_rect(Rect2(mid_tip - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
		ci.draw_rect(Rect2(mid_tip - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if pulse_hi else c_rim)


static func draw_ground_summon_ring(ci: CanvasItem, center: Vector2, rad: float, prog: float, clk: float, col_key: String = "gold") -> void:
	var c: Vector2 = center.round()
	var r: float = maxf(6.0, rad)
	var p: float = clampf(prog, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 12.0)) % 2 == 0)
	var col: Color = _col(col_key, "gold")
	var c_void: Color = Color(PAL["void"] as Color, 0.85)
	var c_cream: Color = PAL["cream"] as Color

	_draw_dither_fill(ci, c, r - 1.0, Color(col, lerpf(0.12, 0.22, p)))
	_draw_pixel_rune_arc(ci, c, r, 0.0, TAU, c_cream if (p > 0.78 and pulse_hi) else col, c_void, 2.0, true, clk * 0.35)

	var r_in: float = maxf(2.5, roundf(r * lerpf(0.92, 0.22, p)))
	_draw_pixel_rune_arc(ci, c, r_in, 0.0, TAU, c_cream if pulse_hi else col, c_void, 1.0, false, -clk * 0.45)
	ci.draw_rect(Rect2(c - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
	ci.draw_rect(Rect2(c, Vector2.ONE), c_cream if p > 0.5 else col)

	var ch_d: float = lerpf(r + 4.0, maxf(4.0, r * 0.42), p)
	for i: int in range(4):
		var d: Vector2 = Vector2.from_angle(float(i) * (PI * 0.5))
		var tip: Vector2 = (c + d * ch_d).round()
		_draw_rune_chevron(ci, tip, -d, 3.0, 3.5, c_cream if p > 0.65 else col, c_void)
