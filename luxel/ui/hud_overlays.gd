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
	var per_heart: int = maxi(1, int(Lx.get_decision("half_lanterns_per_heart", 8)))
	var txt: String = LxStrings.fmt("MAP_WS_COUNT_FMT", [half_count, per_heart]) if LxStrings.has_id("MAP_WS_COUNT_FMT") else LxStrings.fmt("HUD_SHARDS_FMT", [half_count])
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


static func draw_heart_extras(ci: CanvasItem, origin: Vector2, max_h: int, blink_t: float) -> void:
	if Lx.state == null:
		return
	var hc: int = Lx.state.half_lanterns
	if hc > 0:
		draw_half_lantern(ci, origin, max_h, hc)
	if Lx.state.get_upgrade_rank("spare_wick") > 0 and Lx.state.is_spare_wick_allowed():
		var cols: int = mini(max_h, 6)
		var sx: float = origin.x + float(cols) * 7.0 + 3.0
		if hc > 0:
			var per_h: int = maxi(1, int(Lx.get_decision("half_lanterns_per_heart", 8)))
			var htxt: String = LxStrings.fmt("MAP_WS_COUNT_FMT", [hc, per_h]) if LxStrings.has_id("MAP_WS_COUNT_FMT") else LxStrings.fmt("HUD_SHARDS_FMT", [hc])
			sx += float(LxPixelFont.width(htxt, 1)) + 11.0
		draw_spare_wick_pip(ci, Vector2(sx, origin.y - 1.0), Lx.state.spare_wick_ready, blink_t)


static func draw_spare_wick_pip(ci: CanvasItem, at: Vector2, ready: bool, blink_t: float) -> void:
	var pal: Dictionary = LxPalette.PAL
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	ci.draw_rect(Rect2(x - 1.0, y, 9.0, 8.0), Color(pal["void"] as Color, 0.72))
	ci.draw_rect(Rect2(x, y, 7.0, 7.0), pal["night"] as Color)
	if ready:
		var flk: bool = LxHudFx.flash_reduced() or fmod(blink_t * 3.0, 1.0) < 0.55
		ci.draw_rect(Rect2(x + 3.0, y, 1.0, 1.0), pal["cream"] as Color if flk else pal["gold"] as Color)
		ci.draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 2.0), pal["gold"] as Color)
		ci.draw_rect(Rect2(x + 3.0, y + 1.0, 1.0, 2.0), pal["cream"] as Color)
		ci.draw_rect(Rect2(x + 1.0, y + 3.0, 5.0, 2.0), pal["coral"] as Color)
		ci.draw_rect(Rect2(x + 2.0, y + 3.0, 3.0, 1.0), pal["apricot"] as Color)
		ci.draw_rect(Rect2(x + 2.0, y + 5.0, 3.0, 2.0), pal["rose"] as Color)
		ci.draw_rect(Rect2(x + 3.0, y + 5.0, 1.0, 1.0), pal["cream"] as Color)
	else:
		ci.draw_rect(Rect2(x + 3.0, y + 1.0, 1.0, 2.0), pal["mauve"] as Color)
		ci.draw_rect(Rect2(x + 1.0, y + 3.0, 5.0, 2.0), pal["dusk"] as Color)
		ci.draw_rect(Rect2(x + 2.0, y + 5.0, 3.0, 2.0), pal["dusk"] as Color)
		ci.draw_rect(Rect2(x + 2.0, y + 3.0, 3.0, 1.0), pal["mauve"] as Color)


static func record_results_best(stats: Dictionary, rank_key: String) -> Dictionary:
	var is_hard: bool = bool(stats.get("hard_mode", Lx.state.is_hard_mode() if Lx.state != null else false))
	var is_new_best: bool = false
	if Lx.save != null and not bool(stats.get("skip_record", false)):
		var play_s: float = float(stats.get("play_time_s", Lx.state.play_time_s if Lx.state != null else 0.0))
		var deaths: int = int(stats.get("deaths", Lx.state.deaths if Lx.state != null else 0))
		var relit: int = int(stats.get("relit_count", Lx.state.relit_islands.size() if Lx.state != null else 0))
		var embers: int = int(stats.get("ember_pieces", Lx.state.ember_pieces if Lx.state != null else 0))
		var comp_pct: int = int(stats.get("completion_pct", Lx.state.get_completion_pct(relit, embers) if Lx.state != null else 0))
		is_new_best = bool(Lx.save.record_best_mark(is_hard, play_s, deaths, comp_pct, rank_key).get("is_new_best", false))
	return {"is_hard": is_hard, "is_new_best": is_new_best}


static func _format_best_mark_line(is_hard: bool) -> String:
	var tag: String = LxStrings.text("RESULTS_HARD_TAG" if is_hard else "RESULTS_NORM_TAG")
	var bm: Dictionary = Lx.save.get_best_mark(is_hard) if Lx.save != null else {}
	if bm.is_empty():
		return LxStrings.fmt("RESULTS_BEST_NONE_FMT", [tag])
	var t_s: String = LxUiNav.format_epic_time(float(bm.get("best_time_s", 0.0)))
	var pct: int = clampi(int(bm.get("best_pct", 0)), 0, 100)
	var rk_id: String = str(bm.get("best_rank", "RANK_C"))
	var rk: String = LxStrings.text(rk_id) if LxStrings.has_id(rk_id) else LxStrings.text("RANK_C")
	return LxStrings.fmt("RESULTS_BEST_FMT", [tag, t_s, pct, rk])


static func draw_results_mode_and_bests(ci: CanvasItem, _panel: Rect2, is_hard: bool, is_new_best: bool, elapsed: float) -> void:
	var pal: Dictionary = LxPalette.PAL
	var m_rect := Rect2(34.0, 43.0, 64.0, 10.0)
	LxPixelFont.draw_panel(ci, m_rect, "wine" if is_hard else "night", "coral" if is_hard else "mauve", "night" if is_hard else "void")
	var m_txt: String = LxStrings.text("RESULTS_MODE_HARD" if is_hard else "RESULTS_MODE_NORMAL")
	LxPixelFont.draw_centered(ci, m_txt, m_rect.get_center().x, m_rect.position.y + 3.0, pal["gold"] as Color if is_hard else pal["stone"] as Color, 1)
	if is_new_best:
		var nb_rect := Rect2(222.0, 43.0, 64.0, 10.0)
		var pulse_nb: bool = LxHudFx.flash_reduced() or fmod(elapsed * 2.4, 1.0) < 0.55
		LxPixelFont.draw_panel(ci, nb_rect, "pine", "lime" if pulse_nb else "gold", "night")
		LxPixelFont.draw_centered(ci, LxStrings.text("RESULTS_NEW_BEST"), nb_rect.get_center().x, nb_rect.position.y + 3.0, pal["cream"] as Color if pulse_nb else pal["gold"] as Color, 1)
	var bar_r := Rect2(34.0, 143.0, 252.0, 10.0)
	LxPixelFont.draw_panel(ci, bar_r, "night", "coral" if is_hard else "dusk", "void")
	ci.draw_rect(Rect2(160.0, 145.0, 1.0, 6.0), pal["dusk"] as Color)
	LxPixelFont.draw_centered(ci, _format_best_mark_line(false), 97.0, 146.0, pal["gold"] as Color if not is_hard else pal["stone"] as Color, 1)
	LxPixelFont.draw_centered(ci, _format_best_mark_line(true), 223.0, 146.0, pal["coral"] as Color if is_hard else pal["mauve"] as Color, 1)


static func resolve_active_temper() -> String:
	if Lx.player != null and is_instance_valid(Lx.player):
		var tv: Variant = Lx.player.get("temper")
		if tv is String:
			var ts: String = (tv as String).strip_edges().to_lower()
			if ts in ["skip", "scatter", "lance"]:
				return ts
	if Lx.state != null:
		var fs: String = str(Lx.state.story_flags.get("wick_temper", "")).strip_edges().to_lower()
		return fs if fs in ["skip", "scatter", "lance"] else ""
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


static func _find_hud_node(node_name: String) -> Node:
	if Lx.root != null:
		var n: Node = Lx.root.get_node_or_null(node_name)
		if n != null and is_instance_valid(n): return n
	if Lx.ui != null:
		var n2: Node = Lx.ui.get_node_or_null(node_name)
		if n2 != null and is_instance_valid(n2): return n2
	if Lx.world != null:
		var n3: Node = Lx.world.find_child(node_name, true, false)
		if n3 != null and is_instance_valid(n3): return n3
	return null


static func has_active_island_hud(isl_id: int) -> bool:
	match isl_id:
		1: return LxIsland1Rule.active_instance != null or _find_hud_node("Island1RuleHud") != null
		2: return _find_hud_node("Island2TideHudLayer") != null
		3: return _find_hud_node("Island3HudOverlay") != null
		5: return _find_hud_node("I5AstrolabeHud") != null
		6: return _find_hud_node("Island6HudMark") != null or LxIsland6Rule.active_instance != null
		_: return false


static func is_temper_mark_drawn() -> bool:
	if Lx.state == null or not has_owned_temper():
		return false
	if Lx.state.island_id == 6 and has_active_island_hud(6):
		return false
	return true


static func compute_left_stack_y(max_h: int, hearts_visible: bool = true, include_temper: bool = false) -> float:
	var y: float = (20.0 if max_h > 6 else 14.0) if hearts_visible else 5.0
	if Lx.state != null:
		match Lx.state.island_id:
			1:
				if has_active_island_hud(1):
					y = maxf(y, 35.0)
			2:
				if has_active_island_hud(2):
					y = maxf(y, 37.0)
			3:
				if has_active_island_hud(3) or Lx.vars != null:
					var rows3: int = 0
					if Lx.state.region_id in ["ow_shift_w", "ow_shift_e", "ow_shift_n", "_proof_i3_1"] or (Lx.vars != null and int(Lx.vars.get_var("island:3", "wood_turn", 0)) > 0):
						rows3 += 1
					if Lx.vars != null and str(Lx.vars.get_var("island:3", "size", "normal")) == "tiny":
						rows3 += 1
					if Lx.vars != null and str(Lx.vars.get_var("dungeon:hollow_oak", "oak_sap", "low")) == "high":
						rows3 += 1
					if rows3 > 0:
						y = maxf(y, 20.0 + float(rows3) * 14.0 + 3.0)
			5:
				var h5: Node = _find_hud_node("I5AstrolabeHud")
				if h5 != null and (not (h5 is CanvasItem) or (h5 as CanvasItem).visible):
					y = maxf(y, 54.0 if max_h > 6 else 47.0)
			6:
				if has_active_island_hud(6):
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
		if is_instance_valid(nar_v) and nar_v is Object:
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


static func draw_beacon_gauge(ci: CanvasItem, cx: float, y: float, isl: int, lit_count: int, lantern_frame: Array[Rect2]) -> void:
	var spacing: float = 11.0
	var start_x: float = roundf(cx - spacing)
	ci.draw_rect(Rect2(start_x - 5.0, y - 2.0, spacing * 2.0 + 11.0, 11.0), Color(LxPalette.PAL["void"] as Color, 0.72))
	var lit_glass: Color = LxBiomePalette.col(isl, "glow")
	var lit_frame: Color = LxBiomePalette.col(isl, "hi")
	for i: int in range(3):
		var p := Vector2(start_x + float(i) * spacing - 2.0, y)
		var is_lit: bool = i < lit_count
		ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(7.0, 9.0)), LxPalette.PAL["night"])
		ci.draw_rect(Rect2(p + Vector2(1.0, 2.0), Vector2(3.0, 4.0)), lit_glass if is_lit else LxPalette.PAL["dusk"])
		if is_lit:
			ci.draw_rect(Rect2(p + Vector2(2.0, 3.0), Vector2(1.0, 2.0)), LxPalette.PAL["cream"])
		var frame_col: Color = lit_frame if is_lit else LxPalette.PAL["mauve"]
		for r: Rect2 in lantern_frame:
			ci.draw_rect(Rect2(p + r.position, r.size), frame_col)


static func draw_move_icon(ci: CanvasItem, move_id: String, at: Vector2, col: Color) -> void:
	var cream: Color = LxPalette.PAL["cream"] as Color
	match move_id:
		"bolt":
			ci.draw_rect(Rect2(at + Vector2(1.0, 2.0), Vector2(5.0, 2.0)), col)
			ci.draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(2.0, 4.0)), cream)
		"dash":
			ci.draw_rect(Rect2(at + Vector2(0.0, 2.0), Vector2(3.0, 1.0)), col)
			ci.draw_rect(Rect2(at + Vector2(1.0, 4.0), Vector2(4.0, 1.0)), col)
			ci.draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(2.0, 5.0)), cream)
		"throw":
			ci.draw_rect(Rect2(at + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), col)
			ci.draw_rect(Rect2(at + Vector2(3.0, 2.0), Vector2(1.0, 3.0)), cream)
		"prism":
			ci.draw_rect(Rect2(at + Vector2(0.0, 3.0), Vector2(2.0, 1.0)), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(2.0, 3.0)), LxPalette.PAL["ice"])
			ci.draw_rect(Rect2(at + Vector2(3.0, 3.0), Vector2(1.0, 1.0)), cream)
			ci.draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(2.0, 1.0)), LxPalette.PAL["sky"])
			ci.draw_rect(Rect2(at + Vector2(6.0, 0.0), Vector2(1.0, 1.0)), LxPalette.PAL["ice"])
			ci.draw_rect(Rect2(at + Vector2(4.0, 3.0), Vector2(3.0, 1.0)), LxPalette.PAL["ice"])
			ci.draw_rect(Rect2(at + Vector2(4.0, 5.0), Vector2(2.0, 1.0)), LxPalette.PAL["sky"])
			ci.draw_rect(Rect2(at + Vector2(6.0, 6.0), Vector2(1.0, 1.0)), LxPalette.PAL["ice"])
		"beam":
			ci.draw_rect(Rect2(at + Vector2(0.0, 2.0), Vector2(7.0, 3.0)), col)
			ci.draw_rect(Rect2(at + Vector2(0.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["gold"])
		"wings":
			ci.draw_rect(Rect2(at + Vector2(0.0, 1.0), Vector2(3.0, 2.0)), col)
			ci.draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(3.0, 2.0)), col)
			ci.draw_rect(Rect2(at + Vector2(2.0, 3.0), Vector2(3.0, 2.0)), cream)
		"lens":
			ci.draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(5.0, 5.0)), col)
			ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), LxPalette.PAL["deep"])
			ci.draw_rect(Rect2(at + Vector2(3.0, 3.0), Vector2(1.0, 1.0)), cream)
		"sunflare":
			ci.draw_rect(Rect2(at + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), col)
			ci.draw_rect(Rect2(at + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), col)
			ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), cream)
		_:
			ci.draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), col)
