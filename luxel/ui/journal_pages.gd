class_name LxJournalPages
extends RefCounted
## Page renderers for LxJournal:
## - Quests: icon step strip + place-to-go badge + pin indicator + scrollbar
## - Moths: 8x10 pips + 2-visit hint icon & region hint strip + Wick House reward tiers
## - Bestiary: all 60+ pack enemies (idle sprite + seen/defeated + weakness + detail bar + scrollbar)
## - Toys: move badge + unlock state + detail bar + scrollbar

static var _enemy_sheets: Dictionary = {}


static func hit_test_item(page: int, area: Rect2, pos: Vector2, scroll: int) -> int:
	if not area.has_point(pos):
		return -1
	match page:
		0: # QUESTS
			for vi: int in range(5):
				var r := Rect2(area.position.x + 2.0, area.position.y + 2.0 + float(vi * 20), area.size.x - 10.0, 18.0)
				if r.has_point(pos): return scroll + vi
		1: # MOTHS (8 islands, 2x4)
			for isl: int in range(1, 9):
				var col: int = (isl - 1) % 2
				var row: int = (isl - 1) / 2
				var r := Rect2(area.position.x + 2.0 + float(col) * 136.0, area.position.y + 13.0 + float(row) * 15.0, 132.0, 14.0)
				if r.has_point(pos): return isl - 1
		2: # BESTIARY (3x3)
			for vi: int in range(9):
				var c: int = vi % 3; var ri: int = vi / 3
				var card := Rect2(area.position.x + 2.0 + float(c * 88), area.position.y + 2.0 + float(ri * 30), 85.0, 28.0)
				if card.has_point(pos): return scroll * 3 + vi
		3: # TOYS (4x3)
			for vi: int in range(12):
				var c: int = vi % 4; var ri: int = vi / 4
				var card := Rect2(area.position.x + 2.0 + float(c * 66), area.position.y + 2.0 + float(ri * 30), 63.0, 28.0)
				if card.has_point(pos): return scroll * 4 + vi
	return -1


static func draw_quests(ci: CanvasItem, area: Rect2, sel: int, scroll: int) -> void:
	var qsvc: LxQuests = LxQuests.current()
	var list: Array[Dictionary] = qsvc.all_quests()
	var vis_rows: int = 5
	if list.is_empty():
		LxPixelFont.draw_centered(ci, LxFolkData.tr_id("JOURNAL_NO_QUESTS"), area.get_center().x, area.position.y + 44.0, LxPalette.PAL["stone"], 1)
		return
	var row_w: float = area.size.x - (10.0 if list.size() > vis_rows else 4.0)
	for vi: int in range(vis_rows):
		var qi: int = scroll + vi
		if qi >= list.size():
			break
		var q: Dictionary = list[qi]
		var qid: String = str(q.get("id", ""))
		var done: bool = qsvc.is_quest_done(qid)
		var started: bool = qsvc.is_quest_started(qid)
		var is_sel: bool = qi == sel
		var isl: int = int(q.get("island", 1))
		var place: Dictionary = LxUiNav.resolve_quest_place(q)
		var pinned: bool = LxUiNav.is_pinned(int(place.get("island", isl)), "quest:" + qid)
		var r := Rect2(area.position.x + 2.0, area.position.y + 2.0 + float(vi * 20), row_w, 18.0)
		var bdr: String = "gold" if is_sel else ("lime" if done else ("apricot" if started else "dusk"))
		LxPixelFont.draw_panel(ci, r, "plum" if is_sel else "night", bdr, "void")
		# Quest icon + island badge + divider
		LxBubble.draw_icon(ci, str(q.get("icon", "lantern")), r.position + Vector2(3.0, 4.0), 1.0)
		LxBubble.draw_icon(ci, "isl_%d" % clampi(isl, 1, 8), r.position + Vector2(14.0, 4.0), 1.0)
		ci.draw_rect(Rect2(r.position.x + 26.0, r.position.y + 3.0, 1.0, 12.0), LxPalette.PAL["dusk"])
		# Step pictogram strip (up to 4 icons) + arrow -> destination place label
		var step_icons: Array[String] = qsvc.get_active_bubble_icons(qid)
		if done:
			step_icons = ["check", "heart", "lantern"]
		var max_steps: int = mini(step_icons.size(), 4)
		for si: int in range(max_steps):
			LxBubble.draw_icon(ci, step_icons[si], r.position + Vector2(30.0 + float(si * 12), 4.0), 1.0)
		var place_x: float = r.position.x + 84.0
		var place_lbl: String = str(place.get("label", "")).substr(0, 22)
		LxBubble.draw_icon(ci, "star" if pinned else "arrow_e", Vector2(place_x, r.position.y + 4.0), 1.0)
		LxPixelFont.draw_left(ci, place_lbl, Vector2(place_x + 12.0, r.position.y + 6.0), LxPalette.PAL["gold"] if pinned else LxPalette.PAL["ice"], 1)
		# Reward icon + status badge on right
		var rew: Dictionary = q.get("reward", {}) as Dictionary
		LxBubble.draw_icon(ci, _reward_icon(str(rew.get("kind", "shards"))), Vector2(r.end.x - 42.0, r.position.y + 4.0), 1.0)
		var st_id: String = "JOURNAL_Q_DONE" if done else ("JOURNAL_Q_OPEN" if started else "JOURNAL_Q_NEW")
		var st_c: Color = LxPalette.PAL["lime"] if done else (LxPalette.PAL["gold"] if started else LxPalette.PAL["stone"])
		LxPixelFont.draw_right(ci, LxFolkData.tr_id(st_id), r.end.x - 5.0, r.position.y + 6.0, st_c, 1)
	_draw_scrollbar(ci, area, list.size(), vis_rows, scroll)


static func draw_moths(ci: CanvasItem, area: Rect2, sel: int = 0) -> void:
	var qsvc: LxQuests = LxQuests.current()
	var total_caught: int = qsvc.get_moth_count()
	var hdr: String = LxFolkData.fmt_id("JOURNAL_MOTHS_FMT", [total_caught, 80])
	LxBubble.draw_icon(ci, "moth", area.position + Vector2(4.0, 2.0), 1.0)
	LxPixelFont.draw_left(ci, hdr, area.position + Vector2(16.0, 4.0), LxPalette.PAL["gold"], 1)
	if LxFireflyState.is_joined():
		var charms_n: int = LxFireflyState.get_charm_count()
		var pip_txt: String = LxFolkData.fmt_id("PIP_JOURNAL_FMT", [LxFireflyState.get_bond_rank(), LxFireflyState.get_nectar_count()])
		var ch_txt: String = LxFolkData.fmt_id("PIP_JOURNAL_CHARM_FMT", [charms_n])
		var pip_w: float = float(LxPixelFont.width(pip_txt, 1))
		var ch_w: float = float(LxPixelFont.width(ch_txt, 1))
		var right_x: float = area.end.x - 4.0
		LxPixelFont.draw_right(ci, ch_txt, right_x, area.position.y + 4.0, LxPalette.PAL["gold" if charms_n > 0 else "stone"], 1)
		var pip_rx: float = roundf(right_x - ch_w - 6.0)
		var dot_x: float = roundf(pip_rx - pip_w - 5.0)
		var dot_y: float = roundf(area.position.y + 5.0)
		ci.draw_rect(Rect2(dot_x, dot_y, 3.0, 3.0), LxPalette.PAL["lime"])
		ci.draw_rect(Rect2(dot_x + 1.0, dot_y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
		if LxFireflyState.is_special_unlocked():
			ci.draw_rect(Rect2(dot_x - 4.0, dot_y + 1.0, 3.0, 1.0), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(dot_x - 3.0, dot_y, 1.0, 3.0), LxPalette.PAL["gold"])
			ci.draw_rect(Rect2(dot_x - 3.0, dot_y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
		LxPixelFont.draw_right(ci, pip_txt, pip_rx, area.position.y + 4.0, LxPalette.PAL["lime"], 1)
	var sel_isl: int = clampi(sel + 1, 1, 8)
	# 8 islands in 2 columns x 4 rows, 10 moth pips per island + hint eye icon after 2 visits
	for isl: int in range(1, 9):
		var col: int = (isl - 1) % 2
		var row: int = (isl - 1) / 2
		var r := Rect2(area.position.x + 2.0 + float(col) * 136.0, area.position.y + 13.0 + float(row) * 15.0, 132.0, 14.0)
		var counts: Vector2i = qsvc.get_moths_for_island(isl)
		var cap: int = maxi(10, counts.y)
		var full: bool = counts.x >= cap
		var is_sel: bool = isl == sel_isl
		var visits: int = LxUiNav.get_island_visits(isl)
		var has_hint: bool = (not full) and visits >= 2 and not LxUiNav.next_moth_hint_for_island(isl).is_empty()
		var bdr: String = "gold" if is_sel else ("lime" if full else LxBiomePalette.key(isl, "border"))
		LxPixelFont.draw_panel(ci, r, "plum" if is_sel else "night", bdr, "void")
		LxBubble.draw_icon(ci, "isl_%d" % isl, r.position + Vector2(2.0, 2.0), 1.0)
		var glow_c: Color = LxBiomePalette.col(isl, "glow")
		for p: int in range(10):
			var px: float = r.position.x + 14.0 + float(p * 7)
			var py: float = r.position.y + 4.0
			var lit: bool = p < counts.x
			ci.draw_rect(Rect2(px, py, 5.0, 5.0), LxPalette.PAL["void"])
			ci.draw_rect(Rect2(px + 1.0, py + 1.0, 3.0, 3.0), glow_c if lit else LxPalette.PAL["dusk"])
			if lit:
				ci.draw_rect(Rect2(px + 2.0, py + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
		if has_hint:
			LxBubble.draw_icon(ci, "eye", Vector2(r.end.x - 36.0, r.position.y + 2.0), 1.0)
		LxPixelFont.draw_right(ci, LxFolkData.fmt_id("FMT_RATIO", [counts.x, cap]), r.end.x - 3.0, r.position.y + 4.0, LxPalette.PAL["lime" if full else "stone"], 1)

	# Selected-island 2-visit hint strip (y+74..87)
	var hr := Rect2(area.position.x + 2.0, area.position.y + 74.0, area.size.x - 4.0, 13.0)
	LxPixelFont.draw_panel(ci, hr, "night", LxBiomePalette.key(sel_isl, "border"), "void")
	LxBubble.draw_icon(ci, "isl_%d" % sel_isl, hr.position + Vector2(3.0, 1.0), 1.0)
	var sel_counts: Vector2i = qsvc.get_moths_for_island(sel_isl)
	var sel_full: bool = sel_counts.x >= maxi(10, sel_counts.y)
	var sel_visits: int = LxUiNav.get_island_visits(sel_isl)
	if sel_full:
		LxBubble.draw_icon(ci, "check", hr.position + Vector2(16.0, 1.0), 1.0)
		LxPixelFont.draw_left(ci, LxFolkData.tr_id("JOURNAL_Q_DONE"), hr.position + Vector2(28.0, 4.0), LxPalette.PAL["lime"], 1)
	elif sel_visits >= 2:
		var hint: Dictionary = LxUiNav.next_moth_hint_for_island(sel_isl)
		LxBubble.draw_icon(ci, "eye", hr.position + Vector2(16.0, 1.0), 1.0)
		var hk: String = str(hint.get("kind", "overworld"))
		var hicon: String = "door" if hk == "dungeon" else ("crystal" if hk == "cave" else "lantern")
		LxBubble.draw_icon(ci, hicon, hr.position + Vector2(28.0, 1.0), 1.0)
		var reg_lbl: String = LxUiNav.region_display_label(sel_isl, str(hint.get("region", "overworld")), 24)
		LxPixelFont.draw_left(ci, reg_lbl, hr.position + Vector2(40.0, 4.0), LxPalette.PAL["ice"], 1)
	else:
		LxBubble.draw_icon(ci, "question", hr.position + Vector2(16.0, 1.0), 1.0)
		LxPixelFont.draw_left(ci, LxFolkData.fmt_id("FMT_RATIO", [sel_visits, 2]), hr.position + Vector2(28.0, 4.0), LxPalette.PAL["stone"], 1)
	if LxFireflyState.is_joined():
		var cspec: Dictionary = LxFireflyState.get_charm_spec_for_island(sel_isl)
		var c_done: bool = not cspec.is_empty() and LxFireflyState.has_charm(str(cspec["charm_id"]))
		var c_lbl: String = LxStrings.text(str(cspec["name_key"])) if c_done else LxFolkData.tr_id("JOURNAL_UNSEEN")
		var cw: float = float(LxPixelFont.width(c_lbl, 1))
		var cx: float = roundf(hr.end.x - 4.0 - cw - 5.0)
		var cy: float = roundf(hr.position.y + 5.0)
		ci.draw_rect(Rect2(cx, cy, 3.0, 3.0), LxPalette.PAL["gold" if c_done else "dusk"])
		ci.draw_rect(Rect2(cx + 1.0, cy + 1.0, 1.0, 1.0), LxPalette.PAL["cream" if c_done else "mauve"])
		LxPixelFont.draw_right(ci, c_lbl, hr.end.x - 4.0, hr.position.y + 4.0, LxPalette.PAL["gold" if c_done else "mauve"], 1)

	# Bottom Wick House Moth Lantern reward tier strip (5 / 10 / 20 / 35 / 50 / 65 / 80)
	var tr := Rect2(area.position.x + 2.0, area.position.y + 90.0, area.size.x - 4.0, 15.0)
	LxPixelFont.draw_panel(ci, tr, "night", "gold", "void")
	LxPixelFont.draw_left(ci, LxFolkData.tr_id("JOURNAL_TIERS"), tr.position + Vector2(4.0, 5.0), LxPalette.PAL["apricot"], 1)
	for i: int in range(LxQuests.MOTH_TIERS.size()):
		var req: int = LxQuests.MOTH_TIERS[i]
		var hit: bool = total_caught >= req
		var claimed: bool = qsvc.is_moth_tier_claimed(req)
		var pr := Rect2(tr.position.x + 48.0 + float(i * 31), tr.position.y + 2.0, 27.0, 11.0)
		LxPixelFont.draw_panel(ci, pr, "plum" if claimed else ("dusk" if hit else "void"), "lime" if claimed else ("gold" if hit else "dusk"), "void")
		LxPixelFont.draw_centered(ci, str(req), pr.get_center().x, pr.position.y + 3.0, LxPalette.PAL["cream"] if hit else LxPalette.PAL["stone"], 1)


static func draw_bestiary(ci: CanvasItem, area: Rect2, sel: int, scroll: int, clock_s: float) -> void:
	var kinds: PackedStringArray = LxEnemyFactory.known_kinds()
	var qsvc: LxQuests = LxQuests.current()
	var cols: int = 3
	var vis_rows: int = 3
	var start_i: int = scroll * cols
	var end_i: int = mini(kinds.size(), start_i + cols * vis_rows)
	for i: int in range(start_i, end_i):
		var vi: int = i - start_i
		var c: int = vi % cols
		var r_i: int = vi / cols
		var card := Rect2(area.position.x + 2.0 + float(c * 88), area.position.y + 2.0 + float(r_i * 30), 85.0, 28.0)
		var kind: String = kinds[i]
		var counts: Vector2i = qsvc.get_bestiary_counts(kind)
		var seen: bool = counts.x > 0 or counts.y > 0
		var is_sel: bool = i == sel
		LxPixelFont.draw_panel(ci, card, "plum" if is_sel else "night", "gold" if is_sel else ("mauve" if seen else "dusk"), "void")
		var box := Rect2(card.position.x + 3.0, card.position.y + 3.0, 20.0, 22.0)
		ci.draw_rect(box, LxPalette.PAL["void"])
		_draw_enemy_idle(ci, kind, box, seen, clock_s)
		var weak: String = LxFolkData.weakness_icon(kind) if seen else "question"
		LxBubble.draw_icon(ci, weak, Vector2(card.end.x - 12.0, card.position.y + 3.0), 1.0)
		var label: String = LxStrings.sanitize(kind, 9) if seen else LxFolkData.tr_id("JOURNAL_UNSEEN")
		LxPixelFont.draw_left(ci, label, card.position + Vector2(26.0, 5.0), LxPalette.PAL["cream"] if seen else (LxPalette.PAL["stone"] if is_sel else LxPalette.PAL["mauve"]), 1)
		var sd: String = LxFolkData.fmt_id("JOURNAL_SD_FMT", [counts.x, counts.y])
		LxPixelFont.draw_left(ci, sd, card.position + Vector2(26.0, 16.0), LxPalette.PAL["gold"] if counts.y > 0 else LxPalette.PAL["stone"], 1)

	# Bottom detail ribbon for selected creature + total count
	var bar := Rect2(area.position.x + 2.0, area.position.y + 93.0, area.size.x - 10.0, 13.0)
	LxPixelFont.draw_panel(ci, bar, "night", "dusk", "void")
	if sel >= 0 and sel < kinds.size():
		var sk: String = kinds[sel]
		var sc: Vector2i = qsvc.get_bestiary_counts(sk)
		var sseen: bool = sc.x > 0 or sc.y > 0
		LxBubble.draw_icon(ci, LxFolkData.weakness_icon(sk) if sseen else "question", bar.position + Vector2(3.0, 1.0), 1.0)
		var full_nm: String = LxStrings.sanitize(sk, 20) if sseen else LxFolkData.tr_id("JOURNAL_UNSEEN")
		LxPixelFont.draw_left(ci, full_nm, bar.position + Vector2(15.0, 4.0), LxPalette.PAL["gold"] if sseen else LxPalette.PAL["mauve"], 1)
		LxPixelFont.draw_right(ci, LxFolkData.fmt_id("FMT_RATIO", [sel + 1, kinds.size()]), bar.end.x - 4.0, bar.position.y + 4.0, LxPalette.PAL["stone"], 1)
	_draw_scrollbar(ci, area, ceili(float(kinds.size()) / float(cols)), vis_rows, scroll)


static func draw_toys(ci: CanvasItem, area: Rect2, sel: int, scroll: int) -> void:
	var toys: Array[Dictionary] = LxFolkData.toys_catalog()
	var cols: int = 4
	var vis_rows: int = 3
	var start_i: int = scroll * cols
	var end_i: int = mini(toys.size(), start_i + cols * vis_rows)
	for i: int in range(start_i, end_i):
		var vi: int = i - start_i
		var c: int = vi % cols
		var r_i: int = vi / cols
		var card := Rect2(area.position.x + 2.0 + float(c * 66), area.position.y + 2.0 + float(r_i * 30), 63.0, 28.0)
		var t: Dictionary = toys[i]
		var is_sel: bool = i == sel
		var mv: String = str(t.get("move", ""))
		var unlocked: bool = mv.is_empty() or (Lx.state != null and Lx.state.has_move(mv))
		LxPixelFont.draw_panel(ci, card, "plum" if is_sel else "night", "gold" if is_sel else ("sky" if unlocked else "dusk"), "void")
		LxBubble.draw_icon(ci, str(t.get("icon", "gear")), card.position + Vector2(26.0, 3.0), 1.0, Color.WHITE if unlocked else LxPalette.PAL["mauve"])
		if not mv.is_empty():
			LxBubble.draw_icon(ci, "move_" + mv, Vector2(card.end.x - 12.0, card.position.y + 3.0), 1.0, Color.WHITE if unlocked else LxPalette.PAL["dusk"])
		var nk: String = str(t.get("name_key", ""))
		var txt: String = LxFolkData.tr_id(nk) if not nk.is_empty() else LxStrings.sanitize(str(t.get("id", "")), 12)
		LxPixelFont.draw_centered(ci, txt.substr(0, 12), card.get_center().x, card.position.y + 17.0, LxPalette.PAL["cream"] if unlocked else LxPalette.PAL["mauve"], 1)

	# Bottom detail ribbon for selected toy
	var bar := Rect2(area.position.x + 2.0, area.position.y + 93.0, area.size.x - 10.0, 13.0)
	LxPixelFont.draw_panel(ci, bar, "night", "dusk", "void")
	if sel >= 0 and sel < toys.size():
		var st: Dictionary = toys[sel]
		var smv: String = str(st.get("move", ""))
		var sunl: bool = smv.is_empty() or (Lx.state != null and Lx.state.has_move(smv))
		LxBubble.draw_icon(ci, str(st.get("icon", "gear")), bar.position + Vector2(3.0, 1.0), 1.0)
		var snk: String = str(st.get("name_key", ""))
		var stxt: String = LxFolkData.tr_id(snk) if not snk.is_empty() else LxStrings.sanitize(str(st.get("id", "")), 18)
		LxPixelFont.draw_left(ci, stxt, bar.position + Vector2(15.0, 4.0), LxPalette.PAL["gold"] if sunl else LxPalette.PAL["mauve"], 1)
		if not smv.is_empty():
			LxBubble.draw_icon(ci, "move_" + smv, Vector2(bar.end.x - 28.0, bar.position.y + 1.0), 1.0)
		LxBubble.draw_icon(ci, "check" if sunl else "lock", Vector2(bar.end.x - 14.0, bar.position.y + 1.0), 1.0)
	_draw_scrollbar(ci, area, ceili(float(toys.size()) / float(cols)), vis_rows, scroll)


static func _draw_scrollbar(ci: CanvasItem, area: Rect2, total_rows: int, vis_rows: int, scroll: int) -> void:
	if total_rows <= vis_rows:
		return
	var track := Rect2(area.end.x - 6.0, area.position.y + 3.0, 3.0, area.size.y - 6.0)
	ci.draw_rect(track, LxPalette.PAL["night"])
	var thumb_h: float = maxf(10.0, roundf(track.size.y * float(vis_rows) / float(total_rows)))
	var frac: float = float(scroll) / float(maxi(1, total_rows - vis_rows))
	var ty: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
	ci.draw_rect(Rect2(track.position.x, ty, track.size.x, thumb_h), LxPalette.PAL["gold"])
	ci.draw_rect(Rect2(track.position.x, ty, track.size.x, 1.0), LxPalette.PAL["cream"])


static func _draw_enemy_idle(ci: CanvasItem, kind: String, box: Rect2, seen: bool, clock_s: float) -> void:
	var sheet: LxSpriteSheet = _get_enemy_sheet(kind)
	if sheet == null or sheet.tex == null or sheet.animations.is_empty():
		LxBubble.draw_icon(ci, "skull", box.position + Vector2(5.0, 6.0), 1.0, Color.WHITE if seen else LxPalette.PAL["dusk"])
		return
	var anim_key: String = sheet._resolve_anim_key("idle")
	var anim: Dictionary = sheet.animations.get(anim_key, {}) as Dictionary
	var dirs: Dictionary = anim.get("dirs", {}) as Dictionary
	if dirs.is_empty():
		return
	var dkey: String = "front" if dirs.has("front") else ("side" if dirs.has("side") else str(dirs.keys()[0]))
	var dinfo: Dictionary = dirs.get(dkey, {}) as Dictionary
	var rects: Array = dinfo.get("rects", []) as Array
	if rects.is_empty():
		return
	var src: Rect2 = LxSpriteSheet._to_rect2(rects[0])
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	var sc: float = minf(18.0 / src.size.x, 20.0 / src.size.y)
	var dw: float = roundf(src.size.x * sc)
	var dh: float = roundf(src.size.y * sc)
	var bob: float = 0.0 if (not seen or LxHudFx.flash_reduced()) else roundf(sin(clock_s * 3.0) * 0.6)
	var dst := Rect2(roundf(box.get_center().x - dw * 0.5), roundf(box.get_center().y - dh * 0.5 + bob), dw, dh)
	ci.draw_texture_rect_region(sheet.tex, dst, src, Color.WHITE if seen else LxPalette.PAL["dusk"])


static func _get_enemy_sheet(kind: String) -> LxSpriteSheet:
	if _enemy_sheets.has(kind):
		return _enemy_sheets[kind] as LxSpriteSheet
	var candidates: Array[String] = [
		"res://luxel/art/enemies/%s.json" % kind,
		"res://luxel/art/bosses/%s.json" % kind,
	]
	if Lx.packs != null:
		var ed: Dictionary = Lx.packs.enemy_data(kind)
		var sp: String = str(ed.get("sprite", ed.get("sheet", "")))
		if not sp.is_empty():
			if sp.begins_with("res://"):
				candidates.insert(0, sp)
			else:
				candidates.insert(0, "res://luxel/art/enemies/%s.json" % sp)
	var s: LxSpriteSheet = null
	for p: String in candidates:
		if FileAccess.file_exists(p):
			s = LxSpriteSheet.load_sheet(p)
			if s != null:
				break
	_enemy_sheets[kind] = s
	return s


static func _reward_icon(kind: String) -> String:
	match kind:
		"pane": return "pane"
		"ember_piece": return "heart"
		"moth": return "moth"
		"lead": return "gear"
		"slot": return "lantern"
		"flame": return "flame"
		_: return "shard"
