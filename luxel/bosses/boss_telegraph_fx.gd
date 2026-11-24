class_name LxBossTelegraphFx
extends RefCounted
## Shared ground-projected boss telegraph primitives for Luxel 1.0.
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and respects LxHudFx.flash_reduced().

const PAL: Dictionary = LxPalette.PAL


static func _col(key: String, fallback: String = "coral") -> Color:
	return LxPalette.color(key, fallback)


static func draw_ground_danger_ring(ci: CanvasItem, center: Vector2, rad: float, urgency: float, clk: float, fill_key: String = "coral", rim_key: String = "gold") -> void:
	var c: Vector2 = center.round()
	var r: float = maxf(4.0, rad)
	var u: float = clampf(urgency, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 16.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var segs: int = clampi(int(roundf(r * 0.65)), 18, 36)

	ci.draw_circle(c, r, Color(c_fill, lerpf(0.14, 0.24, u)))
	ci.draw_arc(c, r + 1.4, 0.0, TAU, segs, c_void, 2.6)
	ci.draw_arc(c, r, 0.0, TAU, segs, c_rim if (u > 0.72 and pulse_hi) else c_fill, 1.5)

	var r_in: float = maxf(3.0, roundf(r * lerpf(0.80, 0.34, u)))
	var c_in: Color = c_cream if (u > 0.80 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	ci.draw_arc(c, r_in, 0.0, TAU, maxi(14, segs - 6), c_in, 1.5)

	for ti: int in range(4):
		var td: Vector2 = Vector2.from_angle(float(ti) * (PI * 0.5))
		var p0: Vector2 = (c + td * maxf(2.0, r - 3.5)).round()
		var p1: Vector2 = (c + td * (r + 2.5)).round()
		ci.draw_line(p0, p1, c_void, 2.6)
		ci.draw_line(p0, p1, c_cream if u > 0.60 else c_in, 1.3)


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
	var pulse_hi: bool = fred or (int(floorf(clk * 16.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color

	var a0: Vector2 = (from_p - perp * hw).round()
	var a1: Vector2 = (to_p - perp * hw).round()
	var b1: Vector2 = (to_p + perp * hw).round()
	var b0: Vector2 = (from_p + perp * hw).round()
	ci.draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), Color(c_fill, lerpf(0.14, 0.24, u)))

	ci.draw_line(a0, a1, c_void, 2.6)
	ci.draw_line(b0, b1, c_void, 2.6)
	ci.draw_line(a1, b1, c_void, 2.6)

	var rail_c: Color = c_cream if (u > 0.72 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	ci.draw_line(a0, a1, rail_c, 1.4)
	ci.draw_line(b0, b1, rail_c, 1.4)
	ci.draw_line(a1, b1, c_cream if u > 0.60 else rail_c, 1.4)

	var chev_n: int = 3 if length >= 56.0 else 2
	var wing: float = minf(hw * 0.72, 9.0)
	var back: float = minf(6.0, length * 0.14)
	var c_chev: Color = c_cream if (u > 0.58 and pulse_hi) else c_rim
	for i: int in range(chev_n):
		var base_t: float = (float(i) + 0.5) / float(chev_n)
		var t_pos: float = base_t if fred else fposmod(base_t + clk * 0.65, 1.0)
		var tip: Vector2 = from_p.lerp(to_p, clampf(t_pos, 0.15, 0.92)).round()
		var wl: Vector2 = (tip - dir * back - perp * wing).round()
		var wr: Vector2 = (tip - dir * back + perp * wing).round()
		ci.draw_line(wl, tip, c_void, 2.4)
		ci.draw_line(wr, tip, c_void, 2.4)
		ci.draw_line(wl, tip, c_chev, 1.2)
		ci.draw_line(wr, tip, c_chev, 1.2)


static func draw_ground_danger_sector(ci: CanvasItem, origin: Vector2, ang0: float, ang1: float, rad: float, urgency: float, clk: float, fill_key: String = "coral", rim_key: String = "gold") -> void:
	var span: float = absf(ang1 - ang0)
	if span < 0.01:
		return
	var o: Vector2 = origin.round()
	var r: float = maxf(6.0, rad)
	var u: float = clampf(urgency, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 16.0)) % 2 == 0)
	var c_fill: Color = _col(fill_key, "coral")
	var c_rim: Color = _col(rim_key, "gold")
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var steps: int = clampi(int(ceilf(span * 10.0)), 8, 24)

	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(o)
	for i: int in range(steps + 1):
		var a: float = lerpf(ang0, ang1, float(i) / float(steps))
		pts.append((o + Vector2.from_angle(a) * r).round())
	ci.draw_colored_polygon(pts, Color(c_fill, lerpf(0.14, 0.24, u)))

	var p_s: Vector2 = (o + Vector2.from_angle(ang0) * r).round()
	var p_e: Vector2 = (o + Vector2.from_angle(ang1) * r).round()
	var a_lo: float = minf(ang0, ang1)
	var a_hi: float = maxf(ang0, ang1)
	ci.draw_arc(o, r + 1.2, a_lo, a_hi, steps, c_void, 2.6)
	ci.draw_line(o, p_s, c_void, 2.6)
	ci.draw_line(o, p_e, c_void, 2.6)

	var rim_c: Color = c_cream if (u > 0.72 and pulse_hi) else (c_rim if pulse_hi else c_fill)
	ci.draw_arc(o, r, a_lo, a_hi, steps, rim_c, 1.4)
	ci.draw_line(o, p_s, c_cream if u > 0.65 else c_rim, 1.5)
	ci.draw_line(o, p_e, c_fill, 1.3)

	var r_in: float = maxf(6.0, roundf(r * lerpf(0.82, 0.34, u)))
	ci.draw_arc(o, r_in, a_lo, a_hi, maxi(6, steps - 2), c_cream if (u > 0.78 and pulse_hi) else c_rim, 1.5)


static func draw_ground_summon_ring(ci: CanvasItem, center: Vector2, rad: float, prog: float, clk: float, col_key: String = "gold") -> void:
	var c: Vector2 = center.round()
	var r: float = maxf(6.0, rad)
	var p: float = clampf(prog, 0.0, 1.0)
	var fred: bool = LxHudFx.flash_reduced()
	var pulse_hi: bool = fred or (int(floorf(clk * 14.0)) % 2 == 0)
	var col: Color = _col(col_key, "gold")
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color

	ci.draw_circle(c, r, Color(col, lerpf(0.12, 0.24, p)))
	ci.draw_arc(c, r + 1.4, 0.0, TAU, 24, c_void, 2.6)
	ci.draw_arc(c, r, 0.0, TAU, 24, c_cream if (p > 0.78 and pulse_hi) else col, 1.4)

	var r_in: float = maxf(2.5, roundf(r * lerpf(0.92, 0.20, p)))
	ci.draw_arc(c, r_in, 0.0, TAU, 18, c_cream if pulse_hi else col, 1.5)
	ci.draw_circle(c, 2.0, c_cream if p > 0.5 else col)

	var ch_d: float = lerpf(r + 5.0, maxf(4.0, r * 0.42), p)
	for i: int in range(4):
		var d: Vector2 = Vector2.from_angle(float(i) * (PI * 0.5))
		var t: Vector2 = Vector2(-d.y, d.x)
		var tip: Vector2 = (c + d * ch_d).round()
		var w0: Vector2 = (tip + d * 4.5 - t * 3.5).round()
		var w1: Vector2 = (tip + d * 4.5 + t * 3.5).round()
		ci.draw_line(w0, tip, c_void, 2.4)
		ci.draw_line(w1, tip, c_void, 2.4)
		ci.draw_line(w0, tip, c_cream if p > 0.65 else col, 1.2)
		ci.draw_line(w1, tip, c_cream if p > 0.65 else col, 1.2)
