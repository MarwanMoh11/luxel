class_name LxJournalPages
extends RefCounted
## Page renderers for LxJournal: Quests (icons), Moths (8x10 pips), Bestiary (idle sprite + counts + weakness), Toys.
## Strict 20-colour Last Light palette; no prose walls.

static var _enemy_sheets: Dictionary = {}


static func draw_quests(ci: CanvasItem, area: Rect2, sel: int, scroll: int) -> void:
	var qsvc: LxQuests = LxQuests.current()
	var list: Array[Dictionary] = qsvc.all_quests()
	var vis_rows: int = 5
	if list.is_empty():
		LxPixelFont.draw_centered(ci, LxFolkData.tr_id("JOURNAL_NO_QUESTS"), area.get_center().x, area.position.y + 44.0, LxPalette.PAL["stone"], 1)
		return
	for vi: int in range(vis_rows):
		var qi: int = scroll + vi
		if qi >= list.size():
			break
		var q: Dictionary = list[qi]
		var qid: String = str(q.get("id", ""))
		var done: bool = qsvc.is_quest_done(qid)
		var started: bool = qsvc.is_quest_started(qid)
		var is_sel: bool = qi == sel
		var r := Rect2(area.position.x + 2.0, area.position.y + 2.0 + float(vi * 20), area.size.x - 4.0, 18.0)
		var bdr: String = "gold" if is_sel else ("lime" if done else ("apricot" if started else "dusk"))
		var fill: String = "plum" if is_sel else "night"
		LxPixelFont.draw_panel(ci, r, fill, bdr, "void")
		# Quest type icon + island badge + divider
		LxBubble.draw_icon(ci, str(q.get("icon", "lantern")), r.position + Vector2(4.0, 4.0), 1.0)
		var isl: int = int(q.get("island", 1))
		LxBubble.draw_icon(ci, "isl_%d" % clampi(isl, 1, 8), r.position + Vector2(16.0, 4.0), 1.0)
		ci.draw_rect(Rect2(r.position.x + 29.0, r.position.y + 3.0, 1.0, 12.0), LxPalette.PAL["dusk"])
		# Step pictogram strip (no prose!)
		var step_icons: Array[String] = qsvc.get_active_bubble_icons(qid)
		if done:
			step_icons = ["check", "heart", "lantern"]
		for si: int in range(mini(step_icons.size(), 6)):
			LxBubble.draw_icon(ci, step_icons[si], r.position + Vector2(34.0 + float(si * 12), 4.0), 1.0)
		# Reward icon + status badge on right
		var rew: Dictionary = q.get("reward", {}) as Dictionary
		var rew_icon: String = _reward_icon(str(rew.get("kind", "shards")))
		LxBubble.draw_icon(ci, rew_icon, Vector2(r.end.x - 52.0, r.position.y + 4.0), 1.0)
		var st_id: String = "JOURNAL_Q_DONE" if done else ("JOURNAL_Q_OPEN" if started else "JOURNAL_Q_NEW")
		var st_c: Color = LxPalette.PAL["lime"] if done else (LxPalette.PAL["gold"] if started else LxPalette.PAL["stone"])
		LxPixelFont.draw_right(ci, LxFolkData.tr_id(st_id), r.end.x - 6.0, r.position.y + 6.0, st_c, 1)


static func draw_moths(ci: CanvasItem, area: Rect2) -> void:
	var qsvc: LxQuests = LxQuests.current()
	var total_caught: int = qsvc.get_moth_count()
	var hdr: String = LxFolkData.fmt_id("JOURNAL_MOTHS_FMT", [total_caught, 80])
	LxBubble.draw_icon(ci, "moth", area.position + Vector2(4.0, 3.0), 1.0)
	LxPixelFont.draw_left(ci, hdr, area.position + Vector2(16.0, 5.0), LxPalette.PAL["gold"], 1)
	# 8 islands in 2 columns x 4 rows, 10 moth pips per island (total 80)
	for isl: int in range(1, 9):
		var col: int = (isl - 1) % 2
		var row: int = (isl - 1) / 2
		var bx: float = area.position.x + 2.0 + float(col) * 136.0
		var by: float = area.position.y + 16.0 + float(row) * 18.0
		var r := Rect2(bx, by, 132.0, 16.0)
		var counts: Vector2i = qsvc.get_moths_for_island(isl)
		var full: bool = counts.y > 0 and counts.x >= counts.y
		LxPixelFont.draw_panel(ci, r, "night", "lime" if full else LxBiomePalette.key(isl, "border"), "void")
		LxBubble.draw_icon(ci, "isl_%d" % isl, r.position + Vector2(3.0, 3.0), 1.0)
		var glow_c: Color = LxBiomePalette.col(isl, "glow")
		for p: int in range(10):
			var px: float = r.position.x + 16.0 + float(p * 8)
			var py: float = r.position.y + 5.0
			var lit: bool = p < counts.x
			ci.draw_rect(Rect2(px, py, 6.0, 6.0), LxPalette.PAL["void"])
			ci.draw_rect(Rect2(px + 1.0, py + 1.0, 4.0, 4.0), glow_c if lit else LxPalette.PAL["dusk"])
			if lit:
				ci.draw_rect(Rect2(px + 2.0, py + 2.0, 2.0, 2.0), LxPalette.PAL["cream"])
		LxPixelFont.draw_right(ci, LxFolkData.fmt_id("FMT_RATIO", [counts.x, maxi(10, counts.y)]), r.end.x - 4.0, r.position.y + 5.0, LxPalette.PAL["lime" if full else "stone"], 1)

	# Bottom Wick House Moth Lantern reward tier strip (5 / 10 / 20 / 35 / 50 / 65 / 80)
	var tr := Rect2(area.position.x + 2.0, area.position.y + 90.0, area.size.x - 4.0, 16.0)
	LxPixelFont.draw_panel(ci, tr, "night", "gold", "void")
	LxPixelFont.draw_left(ci, LxFolkData.tr_id("JOURNAL_TIERS"), tr.position + Vector2(4.0, 5.0), LxPalette.PAL["apricot"], 1)
	for i: int in range(LxQuests.MOTH_TIERS.size()):
		var req: int = LxQuests.MOTH_TIERS[i]
		var hit: bool = total_caught >= req
		var claimed: bool = qsvc.is_moth_tier_claimed(req)
		var tx: float = tr.position.x + 48.0 + float(i * 31)
		var pr := Rect2(tx, tr.position.y + 3.0, 27.0, 10.0)
		LxPixelFont.draw_panel(ci, pr, "plum" if claimed else ("dusk" if hit else "void"), "lime" if claimed else ("gold" if hit else "dusk"), "void")
		LxPixelFont.draw_centered(ci, str(req), pr.get_center().x, pr.position.y + 2.0, LxPalette.PAL["cream"] if hit else LxPalette.PAL["stone"], 1)


static func draw_bestiary(ci: CanvasItem, area: Rect2, sel: int, scroll: int, clock_s: float) -> void:
	var kinds: PackedStringArray = LxEnemyFactory.KNOWN_KINDS
	var qsvc: LxQuests = LxQuests.current()
	var cols: int = 3
	var vis_rows: int = 3
	var start_i: int = scroll * cols
	var end_i: int = mini(kinds.size(), start_i + cols * vis_rows)
	for i: int in range(start_i, end_i):
		var vi: int = i - start_i
		var c: int = vi % cols
		var r_i: int = vi / cols
		var card := Rect2(area.position.x + 2.0 + float(c * 90), area.position.y + 2.0 + float(r_i * 34), 87.0, 31.0)
		var kind: String = kinds[i]
		var counts: Vector2i = qsvc.get_bestiary_counts(kind)
		var seen: bool = counts.x > 0 or counts.y > 0
		var is_sel: bool = i == sel
		LxPixelFont.draw_panel(ci, card, "plum" if is_sel else "night", "gold" if is_sel else ("mauve" if seen else "dusk"), "void")
		# Miniature idle frame viewport (22x22)
		var box := Rect2(card.position.x + 4.0, card.position.y + 4.0, 22.0, 23.0)
		ci.draw_rect(box, LxPalette.PAL["void"])
		_draw_enemy_idle(ci, kind, box, seen, clock_s)
		# Weakness icon (hidden as question mark until seen)
		var weak: String = LxFolkData.weakness_icon(kind) if seen else "question"
		LxBubble.draw_icon(ci, weak, Vector2(card.end.x - 13.0, card.position.y + 4.0), 1.0)
		# Name (sanitized short) + Seen / Defeated counts
		var label: String = LxStrings.sanitize(kind, 9) if seen else LxFolkData.tr_id("JOURNAL_UNSEEN")
		LxPixelFont.draw_left(ci, label, card.position + Vector2(29.0, 5.0), LxPalette.PAL["cream"] if seen else LxPalette.PAL["mauve"], 1)
		var sd: String = LxFolkData.fmt_id("JOURNAL_SD_FMT", [counts.x, counts.y])
		LxPixelFont.draw_left(ci, sd, card.position + Vector2(29.0, 17.0), LxPalette.PAL["gold"] if counts.y > 0 else LxPalette.PAL["stone"], 1)


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
		var card := Rect2(area.position.x + 2.0 + float(c * 68), area.position.y + 2.0 + float(r_i * 34), 65.0, 31.0)
		var t: Dictionary = toys[i]
		var is_sel: bool = i == sel
		var mv: String = str(t.get("move", ""))
		var unlocked: bool = mv.is_empty() or (Lx.state != null and Lx.state.has_move(mv))
		LxPixelFont.draw_panel(ci, card, "plum" if is_sel else "night", "gold" if is_sel else ("sky" if unlocked else "dusk"), "void")
		LxBubble.draw_icon(ci, str(t.get("icon", "gear")), card.position + Vector2(28.0, 5.0), 1.0, Color.WHITE if unlocked else LxPalette.PAL["mauve"])
		var nk: String = str(t.get("name_key", ""))
		var txt: String = LxFolkData.tr_id(nk) if not nk.is_empty() else LxStrings.sanitize(str(t.get("id", "")), 12)
		LxPixelFont.draw_centered(ci, txt.substr(0, 13), card.get_center().x, card.position.y + 19.0, LxPalette.PAL["cream"] if unlocked else LxPalette.PAL["mauve"], 1)


static func _draw_enemy_idle(ci: CanvasItem, kind: String, box: Rect2, seen: bool, clock_s: float) -> void:
	var sheet: LxSpriteSheet = _get_enemy_sheet(kind)
	if sheet == null or sheet.tex == null or sheet.animations.is_empty():
		LxBubble.draw_icon(ci, "skull", box.position + Vector2(6.0, 7.0), 1.0, Color.WHITE if seen else LxPalette.PAL["dusk"])
		return
	var anim_key: String = sheet._resolve_anim_key("idle")
	var anim: Dictionary = sheet.animations.get(anim_key, {}) as Dictionary
	var dirs: Dictionary = anim.get("dirs", {}) as Dictionary
	var dkey: String = "front" if dirs.has("front") else ("side" if dirs.has("side") else str(dirs.keys()[0]))
	var dinfo: Dictionary = dirs.get(dkey, {}) as Dictionary
	var rects: Array = dinfo.get("rects", []) as Array
	if rects.is_empty():
		return
	var src: Rect2 = LxSpriteSheet._to_rect2(rects[0])
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	# Scale down cleanly into the 20x21 miniature frame box
	var sc: float = minf(20.0 / src.size.x, 21.0 / src.size.y)
	var dw: float = roundf(src.size.x * sc)
	var dh: float = roundf(src.size.y * sc)
	var bob: float = 0.0 if (not seen or LxHudFx.flash_reduced()) else roundf(sin(clock_s * 3.0) * 0.6)
	var dst := Rect2(roundf(box.get_center().x - dw * 0.5), roundf(box.get_center().y - dh * 0.5 + bob), dw, dh)
	ci.draw_texture_rect_region(sheet.tex, dst, src, Color.WHITE if seen else LxPalette.PAL["dusk"])


static func _get_enemy_sheet(kind: String) -> LxSpriteSheet:
	if _enemy_sheets.has(kind):
		return _enemy_sheets[kind] as LxSpriteSheet
	var s: LxSpriteSheet = LxSpriteSheet.load_sheet("res://luxel/art/enemies/%s.json" % kind)
	if s == null:
		s = LxSpriteSheet.load_sheet("res://luxel/art/bosses/%s.json" % kind)
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
