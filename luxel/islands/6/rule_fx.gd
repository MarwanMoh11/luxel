class_name LxIsland6RuleFx
extends RefCounted
## Pixel-art draw helpers for Island 6 moving-train scrolling windows/roof streaks
## and the compact HUD Temper + Timetable / Kiln Heat / Stride Pendulum badge.
## Strictly uses the 20-colour Last Light palette and LxStrings string IDs.

const PAL: Dictionary = LxPalette.PAL


static func draw_train_fx(canvas: Node2D, train_mode: String, train_scroll: float) -> void:
	if canvas == null or Lx.world == null:
		return
	var b: Rect2 = Lx.world.get("bounds") as Rect2 if Lx.world.get("bounds") is Rect2 else Rect2(0, 0, 384, 224)
	if not b.has_area():
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_stone: Color = PAL["stone"] as Color
	if train_mode == "interior":
		var wx: float = 36.0
		while wx < b.size.x - 52.0:
			var win := Rect2(wx, 3.0, 26.0, 10.0)
			canvas.draw_rect(win.grow(1.0), c_void)
			canvas.draw_rect(win, c_wine)
			canvas.draw_rect(Rect2(wx, 8.0, 26.0, 5.0), c_coral)
			var px: float = wx + 26.0 - fposmod(train_scroll + wx * 0.5, 26.0)
			canvas.draw_rect(Rect2(roundf(px) - 1.0, 4.0, 2.0, 9.0), c_night)
			var sx: float = wx + 26.0 - fposmod(train_scroll * 1.4 + wx * 0.3, 24.0)
			canvas.draw_rect(Rect2(roundf(sx), 5.0, 3.0, 1.0), c_gold)
			canvas.draw_rect(Rect2(wx + 12.0, 3.0, 2.0, 10.0), c_stone)
			wx += 48.0
		var rx: float = b.size.x - 16.0 - fposmod(train_scroll * 1.5, 48.0)
		while rx > 16.0:
			canvas.draw_rect(Rect2(roundf(rx), b.size.y - 3.0, 5.0, 1.0), c_apr)
			rx -= 48.0
	elif train_mode == "roof":
		var alpha: float = 0.42 if LxHudFx.flash_reduced() else 0.72
		for row_y: float in [5.0, 11.0, b.size.y - 12.0, b.size.y - 6.0]:
			var sx: float = b.size.x - fposmod(train_scroll * (1.2 if row_y < 20.0 else 1.6) + row_y * 7.0, 64.0)
			while sx > 8.0:
				canvas.draw_rect(Rect2(roundf(sx), row_y, 10.0, 1.0), Color(c_apr, alpha))
				canvas.draw_rect(Rect2(roundf(sx) + 10.0, row_y, 4.0, 1.0), Color(c_gold, alpha))
				sx -= 64.0


static func draw_hud_mark(
	canvas: Node2D,
	clock: float,
	temper_pop_t: float,
	shift_flash_t: float,
	stride_active: bool,
	stride_side: int,
	stride_warn: bool,
	stride_stabilized: bool
) -> void:
	if canvas == null or Lx.state == null:
		return
	var st: LxGameState = Lx.state
	var cur_temper: String = (Lx.player as LxWick).temper if (Lx.player is LxWick and is_instance_valid(Lx.player)) else LxIsland6Rule.get_saved_temper()
	var on_isl6: bool = st.island_id == LxIsland6Rule.ISLAND_ID
	if cur_temper.is_empty() and not on_isl6:
		return
	var base_y: float = 22.0 if st.max_hearts > 6 else 16.0
	var x: float = 5.0

	if not cur_temper.is_empty() or not LxIsland6Rule.get_known_tempers().is_empty():
		var t_key: String = "ISL6_HUD_SKIP" if cur_temper == "skip" else ("ISL6_HUD_SCAT" if cur_temper == "scatter" else ("ISL6_HUD_LANC" if cur_temper == "lance" else "ISL6_HUD_BASE"))
		var t_lbl: String = LxStrings.text(t_key) if LxStrings.has_id(t_key) else ""
		var t_col_name: String = "gold" if cur_temper == "skip" else ("apricot" if cur_temper == "scatter" else ("coral" if cur_temper == "lance" else "stone"))
		var bdr: String = "cream" if temper_pop_t > 0.0 else t_col_name
		var box_w: float = float(LxPixelFont.width(t_lbl, 1)) + 16.0
		var py: float = base_y - (1.0 if temper_pop_t > 0.15 else 0.0)
		LxPixelFont.draw_panel(canvas, Rect2(x, py, box_w, 10.0), "night", bdr, "void")
		draw_temper_glyph(canvas, Vector2(x + 5.0, py + 5.0), cur_temper, temper_color(cur_temper))
		LxPixelFont.draw_left(canvas, t_lbl, Vector2(x + 11.0, py + 2.0), PAL["cream"] as Color if temper_pop_t > 0.0 else temper_color(cur_temper), 1)
		x += box_w + 3.0

	if not on_isl6:
		return

	var reg: String = st.region_id
	var is_kiln: bool = reg.begins_with("kiln_") or reg == "_proof_i6_2"
	if stride_active:
		var pill := Rect2(x, base_y, 26.0, 10.0)
		var pb: String = "ice" if stride_stabilized else ("cream" if (stride_warn and (LxHudFx.flash_reduced() or fmod(clock, 0.3) < 0.15)) else "gold")
		LxPixelFont.draw_panel(canvas, pill, "night", pb, "void")
		var cx: float = x + 13.0
		var bob_x: float = cx if stride_stabilized else cx + float(stride_side) * 6.0
		canvas.draw_line(Vector2(cx, base_y + 2.0), Vector2(bob_x, base_y + 7.0), PAL["stone"] as Color, 1.0)
		canvas.draw_rect(Rect2(bob_x - 1.0, base_y + 6.0, 3.0, 2.0), PAL["ice"] as Color if stride_stabilized else (PAL["coral"] as Color if stride_warn else PAL["gold"] as Color))
		x += 29.0

	if is_kiln:
		var surge: bool = LxIsland6Rule.get_kiln_heat() == "surge"
		var hk: String = "ISL6_HUD_SURGE" if surge else "ISL6_HUD_LOW"
		var htxt: String = LxStrings.text(hk) if LxStrings.has_id(hk) else ""
		var hw: float = float(LxPixelFont.width(htxt, 1)) + 8.0
		LxPixelFont.draw_panel(canvas, Rect2(x, base_y, hw, 10.0), "night", "coral" if surge else "mauve", "void")
		LxPixelFont.draw_left(canvas, htxt, Vector2(x + 4.0, base_y + 2.0), PAL["gold"] as Color if surge else PAL["stone"] as Color, 1)
	elif not reg.begins_with("colossus_") and not reg.begins_with("train_") and not reg.begins_with("crash_"):
		var sh: String = LxIsland6Rule.get_kiln_shift()
		var sk: String = "ISL6_HUD_SHIFT_A" if sh == "station_a" else ("ISL6_HUD_SHIFT_B" if sh == "station_b" else "ISL6_HUD_SHIFT_C")
		var stxt: String = LxStrings.text(sk) if LxStrings.has_id(sk) else ""
		var sw: float = float(LxPixelFont.width(stxt, 1)) + 16.0
		var sbdr: String = "cream" if shift_flash_t > 0.0 else "apricot"
		LxPixelFont.draw_panel(canvas, Rect2(x, base_y, sw, 10.0), "night", sbdr, "void")
		LxPixelFont.draw_left(canvas, stxt, Vector2(x + 4.0, base_y + 2.0), PAL["gold"] as Color, 1)
		var sidx: int = LxIsland6Rule.VALID_SHIFTS.find(sh)
		for i: int in range(3):
			var pc: Color = PAL["cream"] as Color if i == sidx else PAL["dusk"] as Color
			canvas.draw_rect(Rect2(x + sw - 11.0 + float(i * 3), base_y + 4.0, 2.0, 2.0), pc)


static func temper_color(mode: String) -> Color:
	match mode:
		"skip": return PAL["gold"] as Color
		"scatter": return PAL["apricot"] as Color
		"lance": return PAL["coral"] as Color
		_: return PAL["stone"] as Color


static func draw_temper_glyph(ci: CanvasItem, c: Vector2, mode: String, col: Color) -> void:
	var p: Vector2 = c.round()
	match mode:
		"skip":
			ci.draw_rect(Rect2(p.x - 2.0, p.y + 1.0, 2.0, 1.0), col)
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 1.0, 3.0), col)
			ci.draw_rect(Rect2(p.x, p.y - 2.0, 2.0, 1.0), PAL["cream"] as Color)
		"scatter":
			ci.draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 1.0, 2.0), col)
			ci.draw_rect(Rect2(p.x, p.y - 1.0, 1.0, 2.0), PAL["cream"] as Color)
			ci.draw_rect(Rect2(p.x + 2.0, p.y - 2.0, 1.0, 2.0), col)
		"lance":
			ci.draw_rect(Rect2(p.x, p.y - 3.0, 1.0, 6.0), col)
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 3.0, 1.0), PAL["cream"] as Color)
		_:
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3.0, 3.0), col)
