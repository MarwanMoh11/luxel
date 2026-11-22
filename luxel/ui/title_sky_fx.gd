class_name LxTitleSkyFx
extends RefCounted
## Atmospheric pixel accents for the Title Screen sky & archipelago:
## periodic shooting star across the twilight sky & sweeping western lighthouse beam cone.
## Strictly uses LxPalette.PAL (20 opaque Last Light colours).


static func draw_sky_accents(ci: CanvasItem, elapsed: float) -> void:
	var fred: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))

	# 1. Serene shooting star sweeping diagonally across upper sky every 7.4 s
	var cycle: float = fmod(elapsed + 2.8, 7.4)
	if cycle < 0.78:
		var u: float = cycle / 0.78
		var head := Vector2(lerpf(218.0, 128.0, u), lerpf(12.0, 44.0, u)).round()
		var dir := Vector2(90.0, -32.0).normalized()
		var tail_len: float = (12.0 if fred else 18.0) * sin(u * PI)
		if tail_len >= 2.0:
			var mid: Vector2 = (head + dir * (tail_len * 0.45)).round()
			var tip: Vector2 = (head + dir * tail_len).round()
			ci.draw_line(mid, tip, LxPalette.PAL["blue"], 1.0)
			ci.draw_line(head, mid, LxPalette.PAL["sky"], 1.0)
			ci.draw_rect(Rect2(head, Vector2.ONE), LxPalette.PAL["cream"])
			if u > 0.25 and u < 0.72:
				ci.draw_rect(Rect2(head + Vector2(-1.0, 0.0), Vector2.ONE), LxPalette.PAL["ice"])
				ci.draw_rect(Rect2(head + Vector2(0.0, 1.0), Vector2.ONE), LxPalette.PAL["ice"])

	# 2. Sweeping western lighthouse beacon cone (x=38, y=117) pulsing in sync with lh_p
	var lh_p: float = 0.5 + 0.5 * sin(elapsed * 1.9)
	if lh_p > 0.36:
		var reach: float = roundf(lerpf(10.0, 46.0 if not fred else 28.0, (lh_p - 0.36) / 0.64))
		var alpha: float = (0.14 if fred else 0.22) * ((lh_p - 0.36) / 0.64)
		var beam_col := Color(LxPalette.PAL["gold"], alpha)
		var core_col := Color(LxPalette.PAL["cream"], alpha * 1.15)
		var step_x: float = 4.0
		while step_x < reach:
			var frac: float = step_x / maxf(reach, 1.0)
			var half_h: float = roundf(1.0 + frac * 5.0)
			ci.draw_rect(Rect2(39.0 + step_x, 117.0 - half_h, 4.0, half_h * 2.0 + 1.0), beam_col)
			if frac < 0.55:
				ci.draw_rect(Rect2(39.0 + step_x, 117.0, 4.0, 1.0), core_col)
			step_x += 4.0
