class_name LxHudOverlays
extends RefCounted
## Auxiliary HUD renderers kept outside hud.gd (<= 600 lines):
## - E0-4 challenge timer bar (show/update/hide_challenge_timer)
## - E0-2 locked-move padlock badge for stolen kit moves
## - D29 distinct Wick Key and Keeper's Flame dungeon key counters


static func draw_locked_move_badge(ci: CanvasItem, box: Rect2) -> void:
	var pal: Dictionary = LxPalette.PAL
	# Darken slot subtly with diagonal chain bar + crisp pixel padlock in bottom-right
	ci.draw_rect(Rect2(box.position + Vector2(2.0, 2.0), Vector2(9.0, 7.0)), Color(pal["void"] as Color, 0.45))
	ci.draw_line(box.position + Vector2(2.0, 8.0), box.position + Vector2(10.0, 2.0), pal["wine"] as Color, 1.0)
	var lx: float = box.end.x - 6.0
	var ly: float = box.end.y - 6.0
	ci.draw_rect(Rect2(lx - 1.0, ly - 1.0, 6.0, 7.0), pal["void"] as Color)
	ci.draw_rect(Rect2(lx + 1.0, ly - 1.0, 2.0, 2.0), pal["stone"] as Color)
	ci.draw_rect(Rect2(lx, ly + 1.0, 4.0, 4.0), pal["coral"] as Color)
	ci.draw_rect(Rect2(lx + 1.0, ly + 2.0, 2.0, 2.0), pal["void"] as Color)
	ci.draw_rect(Rect2(lx + 1.0, ly + 2.0, 1.0, 1.0), pal["gold"] as Color)


static func draw_dungeon_keys(ci: CanvasItem, top_right: Vector2, wick_keys: int, flames: int) -> bool:
	if wick_keys <= 0 and flames <= 0:
		return false
	var pal: Dictionary = LxPalette.PAL
	var y: float = top_right.y + 9.0
	var right_x: float = top_right.x
	if flames > 0:
		var fstr: String = LxStrings.fmt("HUD_FLAME_FMT", [flames]) if LxStrings.has_id("HUD_FLAME_FMT") else LxStrings.fmt("HUD_KEYS_FMT", [flames])
		var fw: float = float(LxPixelFont.width(fstr, 1))
		var ix: float = right_x - fw - 7.0
		ci.draw_rect(Rect2(ix - 2.0, y - 1.0, fw + 11.0, 8.0), Color(pal["void"] as Color, 0.72))
		# Mini Keeper's Flame pixel icon
		ci.draw_rect(Rect2(ix + 1.0, y, 2.0, 5.0), pal["coral"] as Color)
		ci.draw_rect(Rect2(ix, y + 2.0, 4.0, 3.0), pal["coral"] as Color)
		ci.draw_rect(Rect2(ix + 1.0, y + 1.0, 2.0, 3.0), pal["gold"] as Color)
		ci.draw_rect(Rect2(ix + 1.0, y + 2.0, 1.0, 2.0), pal["cream"] as Color)
		LxPixelFont.draw_right(ci, fstr, right_x, y, pal["coral"] as Color, 1)
		right_x = ix - 5.0
	if wick_keys > 0:
		var kstr: String = LxStrings.fmt("HUD_KEYS_FMT", [wick_keys])
		var kw: float = float(LxPixelFont.width(kstr, 1))
		var kx: float = right_x - kw - 7.0
		ci.draw_rect(Rect2(kx - 2.0, y - 1.0, kw + 11.0, 8.0), Color(pal["void"] as Color, 0.72))
		# Mini Wick Key pixel icon
		ci.draw_rect(Rect2(kx, y, 3.0, 3.0), pal["gold"] as Color)
		ci.draw_rect(Rect2(kx + 1.0, y + 1.0, 1.0, 1.0), pal["night"] as Color)
		ci.draw_rect(Rect2(kx + 1.0, y + 3.0, 1.0, 3.0), pal["apricot"] as Color)
		ci.draw_rect(Rect2(kx + 2.0, y + 4.0, 2.0, 1.0), pal["cream"] as Color)
		LxPixelFont.draw_right(ci, kstr, right_x, y, pal["apricot"] as Color, 1)
	return true


static func draw_challenge_timer(ci: CanvasItem, ch: Dictionary, blink_t: float, y_base: float) -> void:
	if not bool(ch.get("active", false)):
		return
	var pal: Dictionary = LxPalette.PAL
	var rem: float = maxf(0.0, float(ch.get("rem", 0.0)))
	var frac: float = clampf(float(ch.get("frac", 1.0)), 0.0, 1.0)
	var st: int = int(ch.get("state", 0))
	var urgent: bool = st == 0 and frac < 0.28
	var blink_hi: bool = LxHudFx.flash_reduced() or fmod(blink_t, 0.36) < 0.18
	var bdr: String = "lime" if st == 1 else ("coral" if (st == 2 or (urgent and blink_hi)) else "gold")
	var fill_c: Color = (pal["lime"] if st == 1 else (pal["coral"] if (st == 2 or urgent) else (pal["apricot"] if frac < 0.55 else pal["gold"]))) as Color
	var secs_i: int = int(floorf(rem))
	var tenths: int = int(floorf((rem - float(secs_i)) * 10.0)) % 10
	var t_str: String = LxStrings.fmt("HUD_CHALLENGE_FMT", [secs_i, tenths]) if LxStrings.has_id("HUD_CHALLENGE_FMT") else ("%d.%dS" % [secs_i, tenths])
	var w: float = 76.0
	var h: float = 12.0
	var x: float = roundf(160.0 - w * 0.5)
	var rect := Rect2(x, y_base, w, h)
	LxPixelFont.draw_panel(ci, rect, "night", bdr, "void")
	# Mini hourglass icon on left
	var hx: float = x + 4.0
	var hy: float = y_base + 3.0
	ci.draw_rect(Rect2(hx, hy, 4.0, 1.0), pal["gold"] as Color)
	ci.draw_rect(Rect2(hx + 1.0, hy + 1.0, 2.0, 1.0), pal["cream"] as Color)
	ci.draw_rect(Rect2(hx + 1.0, hy + 2.0, 2.0, 1.0), pal["apricot"] as Color)
	ci.draw_rect(Rect2(hx, hy + 3.0, 4.0, 1.0), pal["gold"] as Color)
	# Time text + progress fill bar
	var bar_x: float = x + 11.0
	var bar_w: float = w - 38.0
	ci.draw_rect(Rect2(bar_x, y_base + 4.0, bar_w, 3.0), pal["void"] as Color)
	var fw: float = floorf((bar_w - 2.0) * frac)
	if fw > 0.0:
		ci.draw_rect(Rect2(bar_x + 1.0, y_base + 5.0, fw, 1.0), fill_c)
	LxPixelFont.draw_right(ci, t_str, x + w - 4.0, y_base + 3.0, pal["cream"] as Color if (urgent and blink_hi) else fill_c, 1)
