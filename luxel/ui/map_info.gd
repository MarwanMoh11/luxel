class_name LxMapInfo
extends RefCounted
## Header progress bar, per-island info box, and Waystone fast-travel list for LxMapScreen.

const DUNGEON_NAME_KEYS: Dictionary = {
	1: "ZONE_BELFRY", 2: "DUNGEON_2_NAME", 3: "DUNGEON_3_NAME", 4: "DUNGEON_4_NAME",
	5: "DUNGEON_5_NAME", 6: "DUNGEON_6_NAME", 7: "DUNGEON_7_NAME", 8: "DUNGEON_8_NAME",
}

const WS_VISIBLE: int = 3


static func draw_header_progress(ci: CanvasItem, elapsed: float) -> void:
	var pct: int = Lx.state.get_completion_pct() if Lx.state != null else 0
	var pct_txt: String = LxStrings.fmt("MAP_COMPLETION_FMT", [pct])
	LxPixelFont.draw_right(ci, pct_txt, 298.0, 16.0, LxPalette.PAL["gold"] if pct >= 100 else LxPalette.PAL["cream"], 1)
	var pct_w: float = float(LxPixelFont.width(pct_txt, 1))
	var bar_right: float = 298.0 - pct_w - 5.0
	var jewel_x0: float = roundf(bar_right - 39.0)
	var fr: bool = LxHudFx.flash_reduced()
	for i: int in range(8):
		var isl: int = i + 1
		var relit: bool = Lx.state != null and Lx.state.relit_islands.has(isl)
		var harm: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl, false))
		var jx: float = jewel_x0 + float(i) * 5.0
		var jy: float = 17.0
		ci.draw_rect(Rect2(jx, jy, 3.0, 3.0), LxBiomePalette.col(isl, "glow") if relit else LxPalette.PAL["night"])
		ci.draw_rect(Rect2(jx + 1.0, jy + 1.0, 1.0, 1.0), LxPalette.PAL["cream" if relit else "dusk"])
		if harm:
			var hi: bool = fr or fmod(elapsed * 2.2 + float(i) * 0.3, 1.0) < 0.55
			ci.draw_rect(Rect2(jx + 1.0, jy - 2.0, 1.0, 1.0), LxPalette.PAL["cream" if hi else "gold"])
	# Compact completion underline bar directly beneath the 8 jewels.
	var bar_w: float = 38.0
	ci.draw_rect(Rect2(jewel_x0, 21.0, bar_w, 1.0), LxPalette.PAL["dusk"])
	var fill_w: float = roundf(bar_w * float(pct) / 100.0)
	if fill_w > 0.0:
		ci.draw_rect(Rect2(jewel_x0, 21.0, fill_w, 1.0), LxPalette.PAL["lime" if pct >= 100 else "gold"])


static func draw_island_info(ci: CanvasItem, box: Rect2, isl_id: int, explored: bool) -> void:
	if isl_id == 0:
		LxPixelFont.draw_panel(ci, box, "dusk", "gold", "night")
		LxHudFx.draw_biome_crest(ci, 1, box.position + Vector2(8.0, 8.0), LxPalette.PAL["gold"] as Color, LxPalette.PAL["cream"] as Color)
		LxPixelFont.draw_left(ci, LxStrings.text("MAP_HUB_LABEL"), box.position + Vector2(14.0, 5.0), LxPalette.PAL["gold"], 1)
		if Lx.state != null and Lx.state.island_id == 0:
			LxPixelFont.draw_right(ci, LxStrings.text("MAP_CURRENT"), box.end.x - 6.0, box.position.y + 5.0, LxPalette.PAL["cream"], 1)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_SECRETS", [count_secrets()]), box.position + Vector2(6.0, 26.0), LxPalette.PAL["sky"], 1)
		_draw_footer_counts(ci, box)
		return
	LxPixelFont.draw_panel(ci, box, "dusk", LxBiomePalette.key(isl_id, "border") if explored else "mauve", "night")
	var data: Dictionary = Lx.get_island_data(isl_id)
	if not explored:
		LxPixelFont.draw_left(ci, LxStrings.text("MAP_UNEXPLORED"), box.position + Vector2(6.0, 8.0), LxPalette.PAL["mauve"], 1)
		LxPixelFont.draw_left(ci, LxStrings.text("MAP_LOCKED"), box.position + Vector2(6.0, 18.0), LxPalette.PAL["coral"], 1)
		_draw_footer_counts(ci, box)
		return

	var isl_glow: Color = LxBiomePalette.col(isl_id, "glow")
	LxHudFx.draw_biome_crest(ci, isl_id, box.position + Vector2(8.0, 8.0), isl_glow, LxPalette.PAL["cream"] as Color)
	var is_cur: bool = Lx.state != null and Lx.state.island_id == isl_id
	var max_name: int = 16 if is_cur else 20
	var isl_name: String = LxStrings.sanitize(str(data.get("name", "")), 0)
	if isl_name.length() > max_name:
		var cut: String = isl_name.substr(0, max_name)
		var sp: int = cut.rfind(" ")
		isl_name = (cut.substr(0, sp) if sp >= 4 else cut).strip_edges()
	LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_ISLAND_FMT", [isl_id, isl_name]), box.position + Vector2(14.0, 5.0), isl_glow, 1)
	if is_cur:
		LxPixelFont.draw_right(ci, LxStrings.text("MAP_CURRENT"), box.end.x - 6.0, box.position.y + 5.0, LxPalette.PAL["cream"], 1)

	var beacons: int = count_beacons(isl_id)
	LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_BEACONS", [beacons]), box.position + Vector2(6.0, 14.0), LxPalette.PAL["cream"], 1)
	for bk: int in range(3):
		var bx: float = box.end.x - 24.0 + float(bk) * 6.0
		var lit_b: bool = bk < beacons
		ci.draw_rect(Rect2(bx, box.position.y + 14.0, 4.0, 4.0), isl_glow if lit_b else LxPalette.PAL["night"])
		ci.draw_rect(Rect2(bx + 1.0, box.position.y + 15.0, 2.0, 2.0), LxPalette.PAL["cream" if lit_b else "mauve"])

	var dngs: Array[Dictionary] = get_island_dungeons(isl_id)
	if dngs.size() <= 1:
		var isl_relit: bool = Lx.state != null and Lx.state.relit_islands.has(isl_id)
		var dungeon_label: String = get_dungeon_name(isl_id, data)
		var d_line: String = LxStrings.text("MAP_DUNGEON_CLEAR") if isl_relit else (LxStrings.fmt("MAP_DUNGEON", [dungeon_label]) if beacons >= 3 else LxStrings.text("MAP_DUNGEON_SEALED"))
		LxPixelFont.draw_left(ci, d_line, box.position + Vector2(6.0, 23.0), LxPalette.PAL["lime"] if isl_relit else LxPalette.PAL["apricot"], 1)
		if not dngs.is_empty():
			_draw_dungeon_pips(ci, box.end.x - 6.0, box.position.y + 23.0, dngs[0], isl_glow)
		_draw_relic_and_harmony(ci, box, isl_id, data)
	else:
		_draw_multi_dungeons(ci, box, dngs, isl_glow)
	_draw_footer_counts(ci, box)


static func get_island_dungeons(isl_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Lx.packs != null:
		for d: Dictionary in Lx.packs.dungeons_for_island(isl_id):
			if not bool(d.get("debug_only", false)):
				out.append(d)
	return out


static func _draw_multi_dungeons(ci: CanvasItem, box: Rect2, dngs: Array[Dictionary], glow: Color) -> void:
	var done_n: int = 0
	for d: Dictionary in dngs:
		if LxMapDungeon.is_dungeon_done(d): done_n += 1
	LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_DUNGEON_COUNT_FMT", [done_n, dngs.size()]), box.position + Vector2(6.0, 21.0), LxPalette.PAL["lime"] if done_n == dngs.size() else LxPalette.PAL["apricot"], 1)
	var shown: int = mini(dngs.size(), 3)
	for i: int in range(shown):
		var d: Dictionary = dngs[i]
		var ry: float = box.position.y + 28.0 + float(i) * 5.0
		var done: bool = LxMapDungeon.is_dungeon_done(d)
		var nm: String = LxMapDungeon._dungeon_display_name(d, str(d.get("id", ""))).substr(0, 14)
		ci.draw_rect(Rect2(box.position.x + 6.0, ry + 1.0, 3.0, 3.0), LxPalette.PAL["lime"] if done else glow)
		LxPixelFont.draw_left(ci, nm, Vector2(box.position.x + 11.0, ry), LxPalette.PAL["lime"] if done else LxPalette.PAL["cream"], 1)
		_draw_dungeon_pips(ci, box.end.x - 6.0, ry, d, glow)


static func _draw_dungeon_pips(ci: CanvasItem, right_x: float, y: float, d: Dictionary, glow: Color) -> void:
	var did: String = str(d.get("id", ""))
	var done: bool = LxMapDungeon.is_dungeon_done(d)
	var boss_dead: bool = LxMapDungeon._is_boss_dead(str(d.get("boss", "")))
	var mini_id: String = str(d.get("mini_boss", ""))
	var mini_dead: bool = LxMapDungeon._is_boss_dead(mini_id)
	var keys: int = (Lx.state.get_key_count(did, "wick_key") + Lx.state.get_key_count(did, "keepers_flame")) if Lx.state != null else 0
	var cx: float = right_x - 3.0
	# Done pip (rightmost)
	ci.draw_rect(Rect2(cx, y + 1.0, 3.0, 3.0), LxPalette.PAL["lime"] if done else LxPalette.PAL["night"])
	cx -= 5.0
	# Boss pip
	ci.draw_rect(Rect2(cx, y + 1.0, 3.0, 3.0), LxPalette.PAL["gold"] if boss_dead else LxPalette.PAL["coral"])
	cx -= 5.0
	# Mini-boss pip (if dungeon has one)
	if not mini_id.is_empty():
		ci.draw_rect(Rect2(cx, y + 1.0, 3.0, 3.0), glow if mini_dead else LxPalette.PAL["mauve"])
		cx -= 5.0
	# Keys held count
	if keys > 0:
		LxPixelFont.draw_right(ci, "x%d" % keys, cx + 2.0, y, LxPalette.PAL["apricot"], 1)


static func _draw_relic_and_harmony(ci: CanvasItem, box: Rect2, isl_id: int, data: Dictionary) -> void:
	var moves: Array = data.get("move_gained", []) as Array
	var ry: float = box.position.y + 32.0
	if moves.is_empty():
		LxPixelFont.draw_left(ci, LxStrings.text("MAP_TRIAL_ISLE"), Vector2(box.position.x + 6.0, ry), LxPalette.PAL["sky"], 1)
	else:
		var pick_id: String = str(moves[0])
		var any_unlocked: bool = false
		for mv: Variant in moves:
			var mid: String = str(mv)
			if Lx.state != null and Lx.state.has_move(mid):
				pick_id = mid
				any_unlocked = true
		if any_unlocked:
			var mdata: Dictionary = Lx.get_move_data(pick_id)
			var mkey: String = str(mdata.get("name_key", ""))
			var mname: String = LxStrings.text(mkey) if (not mkey.is_empty() and LxStrings.has_id(mkey)) else LxStrings.sanitize(pick_id, 14)
			LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_RELIC_FMT", [mname]), Vector2(box.position.x + 6.0, ry), LxPalette.PAL["ice"], 1)
		else:
			LxPixelFont.draw_left(ci, LxStrings.text("MAP_RELIC_LOCKED"), Vector2(box.position.x + 6.0, ry), LxPalette.PAL["mauve"], 1)

	var harm: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_id, false))
	if harm:
		var htxt: String = LxStrings.text("MAP_HARMONY_DONE")
		var hw: float = float(LxPixelFont.width(htxt, 1))
		var sx: float = box.end.x - 6.0 - hw - 5.0
		ci.draw_rect(Rect2(sx - 1.0, ry + 2.0, 3.0, 1.0), LxPalette.PAL["gold"])
		ci.draw_rect(Rect2(sx, ry + 1.0, 1.0, 3.0), LxPalette.PAL["gold"])
		ci.draw_rect(Rect2(sx, ry + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
		LxPixelFont.draw_right(ci, htxt, box.end.x - 6.0, ry, LxPalette.PAL["gold"], 1)


static func _draw_footer_counts(ci: CanvasItem, box: Rect2) -> void:
	var embers: int = Lx.state.ember_pieces if Lx.state != null else 0
	var moths: int = LxQuests.current().get_moth_count()
	LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_EMBERS", [embers]), box.position + Vector2(6.0, 44.0), LxPalette.PAL["apricot"] if embers >= 16 else LxPalette.PAL["stone"], 1)
	LxPixelFont.draw_right(ci, LxFolkData.fmt_id("JOURNAL_MOTHS_FMT", [moths, 80]), box.end.x - 6.0, box.position.y + 44.0, LxPalette.PAL["gold"] if moths > 0 else LxPalette.PAL["stone"], 1)


static func ws_filter_rect(filter_val: int) -> Rect2:
	# Compact island search filter pills inside top of Waystone box (170..300, y=109)
	# filter_val: -1 = ALL, 0 = HUB, 1..8 = island 1..8
	if filter_val == -1:
		return Rect2(174.0, 108.0, 16.0, 8.0)
	if filter_val == 0:
		return Rect2(191.0, 108.0, 11.0, 8.0)
	return Rect2(203.0 + float(filter_val - 1) * 11.0, 108.0, 10.0, 8.0)


static func draw_waystones(ci: CanvasItem, box: Rect2, ws_list: Array[Dictionary], ws_idx: int, ws_scroll: int, elapsed: float, ws_filter: int = -2) -> void:
	LxPixelFont.draw_panel(ci, box, "dusk", "mauve", "night")
	LxPixelFont.draw_left(ci, LxStrings.text("MAP_WAYSTONES"), box.position + Vector2(6.0, 4.0), LxPalette.PAL["sky"], 1)
	var total: int = ws_list.size()
	if total > 0:
		var cnt_txt: String = LxStrings.fmt("MAP_WS_COUNT_FMT", [ws_idx + 1, total])
		LxPixelFont.draw_right(ci, cnt_txt, box.end.x - 6.0, box.position.y + 4.0, LxPalette.PAL["gold"] if total > WS_VISIBLE else LxPalette.PAL["stone"], 1)

	# Island search filter strip (-1=ALL, 0=H, 1..8)
	if ws_filter >= -1:
		for fv: int in range(-1, 9):
			var fr: Rect2 = ws_filter_rect(fv)
			var act: bool = fv == ws_filter
			ci.draw_rect(fr, LxPalette.PAL["gold"] if act else LxPalette.PAL["night"])
			ci.draw_rect(fr.grow(-1.0), LxPalette.PAL["plum"] if act else LxPalette.PAL["void"])
			var flbl: String = LxFolkData.tr_id("PANES_TAB_ALL").substr(0, 3) if fv == -1 else (LxFolkData.tr_id("MAP_HUB_SHORT").substr(0, 1) if fv == 0 else str(fv))
			var fcol: Color = LxPalette.PAL["gold"] if act else (LxBiomePalette.col(fv, "glow") if fv > 0 else LxPalette.PAL["stone"])
			LxPixelFont.draw_centered(ci, flbl, fr.get_center().x, fr.position.y + 1.0, fcol, 1)

	if ws_list.is_empty():
		LxPixelFont.draw_left(ci, LxStrings.text("MAP_NO_WAYSTONES"), box.position + Vector2(6.0, 26.0), LxPalette.PAL["mauve"], 1)
		return

	var vis_count: int = mini(total - ws_scroll, WS_VISIBLE)
	for row: int in range(vis_count):
		var idx: int = ws_scroll + row
		var item: Dictionary = ws_list[idx]
		var r: Rect2 = ws_row_rect(row)
		var sel: bool = idx == ws_idx
		if sel:
			ci.draw_rect(r, LxPalette.PAL["gold"])
			ci.draw_rect(r.grow(-1.0), LxPalette.PAL["plum"])
			var bob: float = 0.0 if LxHudFx.flash_reduced() else (1.0 if fmod(elapsed * 3.0, 1.0) < 0.5 else 0.0)
			var dc := Vector2(174.0 + bob, r.position.y + 4.0)
			ci.draw_rect(Rect2(dc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(dc + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(dc, Vector2.ONE), LxPalette.PAL["cream"])
		ci.draw_rect(Rect2(r.position + Vector2(3.0, 2.0), Vector2(3.0, 5.0)), LxPalette.PAL["sky"] if sel else LxPalette.PAL["blue"])
		LxPixelFont.draw_left(ci, str(item["label"]), r.position + Vector2(9.0, 2.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)

	if total > WS_VISIBLE:
		var ax: float = box.end.x - 7.0
		var up_col: Color = LxPalette.PAL["gold"] if ws_scroll > 0 else LxPalette.PAL["night"]
		var dn_col: Color = LxPalette.PAL["gold"] if ws_scroll + WS_VISIBLE < total else LxPalette.PAL["night"]
		ci.draw_rect(Rect2(ax + 1.0, box.position.y + 22.0, 1.0, 1.0), up_col)
		ci.draw_rect(Rect2(ax, box.position.y + 23.0, 3.0, 1.0), up_col)
		ci.draw_rect(Rect2(ax, box.position.y + 43.0, 3.0, 1.0), dn_col)
		ci.draw_rect(Rect2(ax + 1.0, box.position.y + 44.0, 1.0, 1.0), dn_col)

	LxPixelFont.draw_left(ci, LxStrings.text("MAP_TRAVEL_PROMPT"), box.position + Vector2(6.0, 49.0), LxPalette.PAL["stone"], 1)


static func ws_row_rect(row: int) -> Rect2:
	return Rect2(179.0, 118.0 + float(row) * 9.0, 112.0, 8.0)


static func get_dungeon_name(isl_id: int, data: Dictionary) -> String:
	var key: String = str(DUNGEON_NAME_KEYS.get(isl_id, ""))
	return LxStrings.text(key) if (not key.is_empty() and LxStrings.has_id(key)) else LxStrings.sanitize(str(data.get("dungeon_name", "")), 20)


static func count_secrets() -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	for k_var: Variant in Lx.state.interactable_states.keys():
		var st_v: Variant = Lx.state.interactable_states[k_var]
		if not (st_v is Dictionary) or not bool((st_v as Dictionary).get("opened", false)):
			continue
		var key_s: String = str(k_var)
		var sep: int = key_s.rfind(":")
		var iid: String = key_s.substr(sep + 1) if sep >= 0 else key_s
		if iid.begins_with("chest"):
			count += 1
	for f_var: Variant in Lx.state.story_flags.keys():
		var fk: String = str(f_var)
		if not ((fk.begins_with("disc_") and not fk.begins_with("disc_all_")) or fk.begins_with("chime_1_")):
			continue
		var fv: Variant = Lx.state.story_flags[f_var]
		if fv is bool and bool(fv):
			count += 1
	return count


static func count_beacons(isl_id: int) -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	var p1: String = "isl%d_" % isl_id
	var p2: String = "%d:" % isl_id
	var p3: String = "beacon_%d_" % isl_id
	var p4: String = "beacon_isl%d_" % isl_id
	for b: String in Lx.state.lit_beacons:
		if b.begins_with(p1) or b.begins_with(p2) or b.begins_with(p3) or b.begins_with(p4) or (isl_id == 1 and b in ["beacon_orchard", "beacon_observatory", "beacon_bridge"]):
			count += 1
	return mini(count, 3)
