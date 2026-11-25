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


static func draw_half_lantern(ci: CanvasItem, origin: Vector2, max_h: int, half_count: int) -> void:
	if half_count <= 0:
		return
	var pal: Dictionary = LxPalette.PAL
	var cols: int = mini(max_h, 6)
	var x: float = origin.x + float(cols) * 7.0 + 3.0
	var y: float = origin.y - 1.0
	var txt: String = LxStrings.fmt("MAP_WS_COUNT_FMT", [half_count, 2]) if LxStrings.has_id("MAP_WS_COUNT_FMT") else LxStrings.fmt("HUD_SHARDS_FMT", [half_count])
	var tw: float = float(LxPixelFont.width(txt, 1))
	ci.draw_rect(Rect2(x - 1.0, y, tw + 10.0, 8.0), Color(pal["void"] as Color, 0.72))
	# Mini half-lit brass lantern icon (5x7)
	ci.draw_rect(Rect2(x, y, 5.0, 7.0), pal["night"] as Color)
	ci.draw_rect(Rect2(x + 1.0, y, 3.0, 1.0), pal["apricot"] as Color)
	ci.draw_rect(Rect2(x, y + 1.0, 5.0, 1.0), pal["gold"] as Color)
	ci.draw_rect(Rect2(x, y + 2.0, 1.0, 4.0), pal["apricot"] as Color)
	ci.draw_rect(Rect2(x + 4.0, y + 2.0, 1.0, 4.0), pal["mauve"] as Color)
	ci.draw_rect(Rect2(x, y + 6.0, 5.0, 1.0), pal["apricot"] as Color)
	ci.draw_rect(Rect2(x + 1.0, y + 2.0, 2.0, 4.0), pal["gold"] as Color)
	ci.draw_rect(Rect2(x + 1.0, y + 3.0, 1.0, 2.0), pal["cream"] as Color)
	ci.draw_rect(Rect2(x + 3.0, y + 2.0, 1.0, 4.0), pal["dusk"] as Color)
	LxPixelFont.draw_left(ci, txt, Vector2(x + 7.0, y + 1.0), pal["gold"] as Color, 1)


static func resolve_active_temper() -> String:
	if Lx.player != null and is_instance_valid(Lx.player):
		var tv: Variant = Lx.player.get("temper")
		if tv is String:
			var ts: String = (tv as String).strip_edges().to_lower()
			if ts in ["skip", "scatter", "lance"]:
				return ts
	if Lx.state != null and Lx.state.story_flags.has("wick_temper"):
		var fs: String = str(Lx.state.story_flags.get("wick_temper", "")).strip_edges().to_lower()
		if fs in ["skip", "scatter", "lance"]:
			return fs
	if Lx.vars != null:
		var vs: String = str(Lx.vars.get_var("game", "wick_temper", "")).strip_edges().to_lower()
		if vs in ["skip", "scatter", "lance"]:
			return vs
	return ""


static func has_owned_temper() -> bool:
	if not resolve_active_temper().is_empty():
		return true
	if Lx.state != null:
		for k: String in ["temper_known_skip", "temper_known_scatter", "temper_known_lance"]:
			if bool(Lx.state.story_flags.get(k, false)):
				return true
		var arr: Variant = Lx.state.story_flags.get("wick_tempers_known", [])
		if arr is Array and not (arr as Array).is_empty():
			return true
	return false


static func is_temper_mark_drawn() -> bool:
	if Lx.state == null or not has_owned_temper():
		return false
	if Lx.state.island_id == 6 and LxIsland6Rule.active_instance != null:
		return false
	return true


static func compute_left_stack_y(max_h: int, hearts_visible: bool = true, include_temper: bool = false) -> float:
	var y: float = (20.0 if max_h > 6 else 14.0) if hearts_visible else 5.0
	if Lx.state != null:
		match Lx.state.island_id:
			1:
				if LxIsland1Rule.active_instance != null:
					var r1: Object = LxIsland1Rule.active_instance
					var bt: float = float(r1.get("bell_window_t")) if r1.get("bell_window_t") != null else 0.0
					var rt: float = float(r1.get("resonance_t")) if r1.get("resonance_t") != null else 0.0
					if bt > 0.01 or rt > 0.01:
						y = maxf(y, 35.0)
			2:
				if LxIsland2Rule.active_instance != null:
					y = maxf(y, 37.0)
			3:
				if LxIsland3Rule.active_instance != null:
					var r3: Object = LxIsland3Rule.active_instance
					var rows3: int = 0
					if r3.has_method("get_turns_left") and int(r3.call("get_turns_left")) >= 0: rows3 += 1
					if bool(r3.get("is_tiny")): rows3 += 1
					if float(r3.get("sap_t")) > 0.01 if r3.get("sap_t") != null else false: rows3 += 1
					if rows3 > 0:
						y = maxf(y, 20.0 + float(rows3) * 14.0 + 3.0)
			5:
				if LxIsland5Rule.active_instance != null:
					y = maxf(y, 54.0 if max_h > 6 else 47.0)
			6:
				if LxIsland6Rule.active_instance != null:
					y = maxf(y, 47.0)
	if include_temper and is_temper_mark_drawn():
		y += 12.0
	return y


static func draw_temper_mark(ci: CanvasItem, origin: Vector2, max_h: int, hearts_visible: bool = true) -> void:
	if not is_temper_mark_drawn():
		return
	var cur: String = resolve_active_temper()
	var pal: Dictionary = LxPalette.PAL
	var t_key: String = "ISL6_HUD_SKIP" if cur == "skip" else ("ISL6_HUD_SCAT" if cur == "scatter" else ("ISL6_HUD_LANC" if cur == "lance" else "ISL6_HUD_BASE"))
	var t_lbl: String = LxStrings.text(t_key) if LxStrings.has_id(t_key) else LxStrings.sanitize(cur.to_upper() if not cur.is_empty() else "BASE", 4)
	var col_name: String = "gold" if cur == "skip" else ("apricot" if cur == "scatter" else ("coral" if cur == "lance" else "stone"))
	var col: Color = pal[col_name] as Color
	var y: float = compute_left_stack_y(max_h, hearts_visible, false)
	var x: float = origin.x
	var box_w: float = float(LxPixelFont.width(t_lbl, 1)) + 16.0
	LxPixelFont.draw_panel(ci, Rect2(x, y, box_w, 10.0), "night", col_name, "void")
	var p := Vector2(roundf(x + 5.0), roundf(y + 5.0))
	match cur:
		"skip":
			ci.draw_rect(Rect2(p.x - 2.0, p.y + 1.0, 2.0, 1.0), col)
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 1.0, 3.0), col)
			ci.draw_rect(Rect2(p.x, p.y - 2.0, 2.0, 1.0), pal["cream"] as Color)
		"scatter":
			ci.draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 1.0, 2.0), col)
			ci.draw_rect(Rect2(p.x, p.y - 1.0, 1.0, 2.0), pal["cream"] as Color)
			ci.draw_rect(Rect2(p.x + 2.0, p.y - 2.0, 1.0, 2.0), col)
		"lance":
			ci.draw_rect(Rect2(p.x, p.y - 3.0, 1.0, 6.0), col)
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 3.0, 1.0), pal["cream"] as Color)
		_:
			ci.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3.0, 3.0), col)
	LxPixelFont.draw_left(ci, t_lbl, Vector2(x + 11.0, y + 2.0), col, 1)


static func sold_id_for_option_row(row_id: String) -> String:
	match row_id:
		"music_vol": return "music_off"
		"sfx_vol": return "sound_off"
		"screen_shake": return "camera_shake"
		"cursor_size", "cursor_color": return "cursor_ring"
		_: return ""


static func draw_sold_badge(ci: CanvasItem, at: Vector2, sold_count: int = 0, full_banner: bool = false, right_align: bool = false) -> void:
	var pal: Dictionary = LxPalette.PAL
	var txt: String = ""
	if full_banner:
		if sold_count > 0 and LxStrings.has_id("ISL8_RES_TOLLS"):
			txt = LxStrings.fmt("ISL8_RES_TOLLS", [mini(sold_count, 12)])
		elif LxStrings.has_id("ISL8_TOLL_ALREADY_SOLD"):
			txt = LxStrings.text("ISL8_TOLL_ALREADY_SOLD")
		else:
			txt = LxStrings.text("END_ASK_TITLE")
	else:
		txt = LxStrings.text("ISL8_TAG_SOLD") if LxStrings.has_id("ISL8_TAG_SOLD") else LxStrings.text("OPT_OFF")
	if txt.is_empty():
		return
	var w: float = float(LxPixelFont.width(txt, 1)) + 8.0
	var x: float = roundf(at.x - w) if right_align else roundf(at.x)
	var y: float = roundf(at.y)
	LxPixelFont.draw_panel(ci, Rect2(x, y, w, 9.0), "wine", "coral", "void")
	LxPixelFont.draw_centered(ci, txt, x + w * 0.5, y + 2.0, pal["gold"] as Color, 1)


static func get_ending_sold_key(ending_mode: String, receipt_count: int) -> String:
	if receipt_count <= 0:
		return ""
	var prefix: String = "ISL8_DAWN_" if ending_mode == "dawn" else "ISL8_END_"
	var tier: String = "ALL" if receipt_count >= 12 else ("MID" if receipt_count >= 5 else "FEW")
	var key: String = prefix + tier
	return key if LxStrings.has_id(key) else ""


static func draw_dawn_buyback_parade(ci: CanvasItem, t: float, receipts: PackedStringArray) -> void:
	if receipts.is_empty() or t < 1.2:
		return
	var pal: Dictionary = LxPalette.PAL
	var sold: LxSold = LxSold.current()
	var count: int = receipts.size()
	var step_s: float = clampf(4.2 / float(maxi(count, 1)), 0.28, 0.55)
	for i: int in range(count):
		var start_t: float = 1.25 + float(i) * step_s
		var age: float = t - start_t
		if age < 0.0 or age > 2.4:
			continue
		var sid: String = receipts[i]
		var meta: Dictionary = sold.get_setting(sid)
		var nk: String = str(meta.get("name_key", ""))
		if nk.is_empty() or not LxStrings.has_id(nk):
			continue
		var label: String = LxStrings.text(nk)
		var prog: float = clampf(age / 2.4, 0.0, 1.0)
		var fade: float = minf(age / 0.25, (2.4 - age) / 0.45)
		var lane_x: float = 82.0 if (i % 2 == 0) else 238.0
		var py: float = roundf(lerpf(118.0, 48.0, prog))
		var col: Color = LxPalette.fade_step(fade, "cream" if prog < 0.35 else "gold")
		if col.a <= 0.0:
			continue
		var w: float = float(LxPixelFont.width(label, 1)) + 8.0
		ci.draw_rect(Rect2(roundf(lane_x - w * 0.5), py - 1.0, w, 8.0), Color(pal["night"] as Color, clampf(fade * 0.72, 0.0, 0.72)))
		LxPixelFont.draw_centered(ci, label, lane_x, py, col, 1)


static func draw_ember_meter(ci: CanvasItem, at: Vector2, ember_val: float, ember_max: float, blink_t: float, idle_dim: bool = false) -> void:
	var bar_w: float = 68.0
	var bar_h: float = 8.0
	var frac: float = clampf(ember_val / maxf(1.0, ember_max), 0.0, 1.0)
	var ready: bool = frac >= 0.999
	var dim: bool = idle_dim and not ready and frac <= 0.01
	var border_col: String = "dusk" if dim else ("cream" if (ready and (LxHudFx.flash_reduced() or fmod(blink_t, 0.5) < 0.25)) else ("gold" if ready else "mauve"))
	LxPixelFont.draw_panel(ci, Rect2(at, Vector2(bar_w, bar_h)), "void" if dim else "night", border_col, "void")
	var inner_w: float = floorf((bar_w - 4.0) * frac)
	if inner_w > 0.0:
		var fill_c: Color = LxPalette.PAL["gold"] if ready else (LxPalette.PAL["apricot"] if frac >= 0.5 else LxPalette.PAL["coral"])
		ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(inner_w, bar_h - 4.0)), fill_c)
		if ready:
			ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(inner_w, 1.0)), LxPalette.PAL["cream"])
	var label_id: String = "HUD_EMBER_READY" if ready else "HUD_EMBER"
	var label_col: Color = LxPalette.PAL["dusk"] if dim else (LxPalette.PAL["gold"] if ready else LxPalette.PAL["stone"])
	LxPixelFont.draw_right(ci, LxStrings.text(label_id), at.x + bar_w, at.y - 7.0, label_col, 1)


static func draw_zip_cue(ci: CanvasItem, origin: Vector2, zip_alpha: float) -> void:
	if zip_alpha <= 0.02: return
	var pos: Vector2 = origin
	if Lx.ui != null:
		var nar_v: Variant = Lx.ui.get("narration")
		if nar_v is Object and is_instance_valid(nar_v):
			var nar: Object = nar_v as Object
			if nar.has_method("has_active_prompt") and bool(nar.call("has_active_prompt")):
				var saying: bool = nar.has_method("is_saying") and (bool(nar.call("is_saying", "main")) or bool(nar.call("is_saying", "title")))
				pos.y = 120.0 if saying else 133.0
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph("lx_fire"), 6) if Lx.input != null else "-"
	var txt: String = LxStrings.fmt("HUD_ZIP_CUE", [glyph])
	var w: float = float(LxPixelFont.width(txt, 1)) + 8.0
	ci.draw_rect(Rect2(pos, Vector2(w, 9.0)), Color(LxPalette.PAL["night"] as Color, zip_alpha * 0.85))
	ci.draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(w - 2.0, 7.0)), Color(LxPalette.PAL["dusk"] as Color, zip_alpha * 0.90))
	ci.draw_rect(Rect2(pos, Vector2(w, 1.0)), Color(LxPalette.PAL["gold"] as Color, zip_alpha))
	ci.draw_rect(Rect2(pos + Vector2(0.0, 8.0), Vector2(w, 1.0)), Color(LxPalette.PAL["gold"] as Color, zip_alpha))
	LxPixelFont.draw_left(ci, txt, pos + Vector2(4.0, 2.0), Color(LxPalette.PAL["gold"] as Color, zip_alpha), 1)
