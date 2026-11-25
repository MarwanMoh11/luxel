class_name LxMapIsland
extends RefCounted
## Detailed per-island map page (Islands 1..8) and Wick House Hub floorplan (Island 0).
## Shows dungeons, set pieces, grand dungeons, superbosses (unseen/seen/open/cleared),
## gates with requirement icons, waystones, folk with open quests, moth/ember counts,
## and the soft "next light" pin marker (P).

const CHART_RECT := Rect2(20.0, 26.0, 178.0, 128.0)
const INFO_RECT := Rect2(202.0, 26.0, 98.0, 128.0)

const HUB_ROOMS: Array[Dictionary] = [
	{"id": "overworld", "name_key": "ZONE_WICK_HOUSE", "pos": Vector2(109.0, 90.0), "icon": "home", "links": ["attic", "workshop", "gallery", "cellar"]},
	{"id": "attic", "name_key": "ZONE_HUB_ATTIC", "pos": Vector2(109.0, 56.0), "icon": "moth", "links": ["observatory"]},
	{"id": "observatory", "name_key": "ZONE_HUB_OBSERVATORY", "pos": Vector2(148.0, 44.0), "icon": "bell", "links": []},
	{"id": "workshop", "name_key": "ZONE_HUB_WORKSHOP", "pos": Vector2(54.0, 86.0), "icon": "pane", "links": ["corridor"]},
	{"id": "corridor", "name_key": "ZONE_HUB_CORRIDOR", "pos": Vector2(48.0, 124.0), "icon": "move_dash", "links": []},
	{"id": "gallery", "name_key": "ZONE_HUB_GALLERY", "pos": Vector2(162.0, 86.0), "icon": "mirror", "links": ["pier"]},
	{"id": "pier", "name_key": "ZONE_HUB_PIER", "pos": Vector2(168.0, 124.0), "icon": "toy_skiff", "links": []},
	{"id": "cellar", "name_key": "ZONE_HUB_CELLAR", "pos": Vector2(109.0, 128.0), "icon": "skull", "links": []},
]

static var _static_cache: Dictionary = {} # isl_id -> Array[Dictionary]


static func clear_cache() -> void:
	_static_cache.clear()


static func build_island_nodes(isl_id: int) -> Array[Dictionary]:
	if isl_id == 0:
		return _build_hub_nodes()
	if not _static_cache.has(isl_id):
		_static_cache[isl_id] = _scan_island_static(isl_id)
	var base: Array = _static_cache[isl_id] as Array
	var out: Array[Dictionary] = []
	for item: Variant in base:
		if item is Dictionary:
			var nd: Dictionary = (item as Dictionary).duplicate(true)
			_decorate_node(nd, isl_id)
			if str(nd.get("kind", "")) == "quest" and str(nd.get("state", "")) == "cleared":
				continue # Show only folk with OPEN quests on the map
			out.append(nd)
	return out


static func _build_hub_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hr: Dictionary in HUB_ROOMS:
		var rid: String = str(hr["id"])
		var visited: bool = Lx.state != null and Lx.state.visited_regions.has("0:%s" % rid)
		var is_cur: bool = Lx.state != null and Lx.state.island_id == 0 and Lx.state.region_id == rid
		var st: String = "open" if (visited or rid == "overworld") else "seen"
		out.append({
			"id": "hub_" + rid,
			"island": 0,
			"kind": "waystone" if rid == "overworld" else "hub_room",
			"waystone_id": "ws_hub" if rid == "overworld" else "",
			"region": rid,
			"icon": str(hr["icon"]),
			"label": LxFolkData.tr_id(str(hr["name_key"])).substr(0, 16),
			"pos": hr["pos"] as Vector2,
			"state": st,
			"current": is_cur,
			"reqs": [],
			"world_pos": Vector2(240.0, 248.0),
		})
	return out


static func _scan_island_static(isl_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var packs: LxPackRegistry = Lx.packs if Lx.packs != null else Lx.ensure_packs()
	var dngs: Array[Dictionary] = LxMapInfo.get_island_dungeons(isl_id)
	var minors: Array[Dictionary] = []
	var setpieces: Array[Dictionary] = []
	var grands: Array[Dictionary] = []
	for d: Dictionary in dngs:
		var did: String = str(d.get("id", ""))
		var regs: Array = d.get("regions", []) as Array
		if bool(d.get("grand", false)) or bool(d.get("builtin", false)):
			grands.append(d)
		elif regs.size() <= 6 or did in ["great_toll", "leviathan", "briar_court", "garden_party", "fall", "iron_collision", "masquerade"]:
			setpieces.append(d)
		else:
			minors.append(d)

	# 1. Minor dungeons (west/south-west/east-lower slots)
	var minor_slots: Array[Vector2] = [Vector2(56.0, 74.0), Vector2(142.0, 110.0), Vector2(60.0, 118.0)]
	for mi: int in range(minors.size()):
		var dm: Dictionary = minors[mi]
		var did: String = str(dm.get("id", ""))
		out.append({
			"id": "dng_" + did, "island": isl_id, "kind": "minor_dungeon",
			"dungeon_id": did, "dmeta": dm.duplicate(true),
			"region": str(dm.get("entry", "overworld")),
			"icon": "lantern",
			"label": LxMapDungeon._dungeon_display_name(dm, did).substr(0, 16),
			"pos": minor_slots[mi % minor_slots.size()],
			"reqs": _parse_req_flags(dm.get("requires_flags", []) as Array),
			"world_pos": Vector2(-1.0, -1.0),
		})

	# 2. Set piece (upper-west / center-north)
	for si: int in range(setpieces.size()):
		var ds: Dictionary = setpieces[si]
		var did: String = str(ds.get("id", ""))
		out.append({
			"id": "set_" + did, "island": isl_id, "kind": "set_piece",
			"dungeon_id": did, "dmeta": ds.duplicate(true),
			"region": str(ds.get("entry", "overworld")),
			"icon": "spark",
			"label": LxMapDungeon._dungeon_display_name(ds, did).substr(0, 16),
			"pos": Vector2(104.0, 58.0 + float(si) * 18.0),
			"reqs": _parse_req_flags(ds.get("requires_flags", []) as Array),
			"world_pos": Vector2(-1.0, -1.0),
		})

	# 3. Grand dungeon (prominent north-east crown)
	for gi: int in range(grands.size()):
		var dg: Dictionary = grands[gi]
		var did: String = str(dg.get("id", ""))
		var g_reqs: Array[Dictionary] = [
			{"flag": "beacons_3", "icon": "lantern"},
		]
		for m_d: Dictionary in minors:
			var mdf: String = str(m_d.get("done_flag", "dungeon_done:" + str(m_d.get("id", ""))))
			g_reqs.append({"flag": mdf, "icon": "key"})
		out.append({
			"id": "grand_" + did, "island": isl_id, "kind": "grand_dungeon",
			"dungeon_id": did, "dmeta": dg.duplicate(true),
			"region": str(dg.get("entry", "overworld")),
			"icon": "crown",
			"label": LxMapDungeon._dungeon_display_name(dg, did).substr(0, 16),
			"pos": Vector2(148.0, 54.0),
			"reqs": g_reqs,
			"world_pos": Vector2(-1.0, -1.0),
		})

	# 4. Superboss (far east / hidden corner)
	for bid: String in packs.all_boss_ids():
		var bm: Dictionary = packs.boss_meta(bid)
		if int(bm.get("island", 0)) != isl_id or bool(bm.get("mini", false)):
			continue
		var bdng: String = str(bm.get("dungeon", ""))
		var breg: String = str(bm.get("region", ""))
		var is_super: bool = breg.begins_with("superboss") or breg.begins_with("sb_") or breg.begins_with("vault_") or breg.begins_with("cave_") or bdng == "superboss" or bdng.is_empty()
		if not is_super:
			continue
		var sb_reqs: Array[Dictionary] = []
		if bid == "first_dark":
			sb_reqs.append({"flag": "moths>=80", "icon": "moth"})
		var nk: String = str(bm.get("name_key", ""))
		var lbl: String = LxFolkData.tr_id(nk).substr(0, 16) if (not nk.is_empty() and LxFolkData.has_str(nk)) else LxStrings.sanitize(bid, 16)
		out.append({
			"id": "sb_" + bid, "island": isl_id, "kind": "superboss",
			"boss_id": bid, "region": breg, "icon": "skull", "label": lbl,
			"pos": Vector2(174.0, 86.0), "reqs": sb_reqs,
			"world_pos": Vector2(-1.0, -1.0),
		})
		break

	# 5. Overworld Gates & Waystones (read from overworld.json)
	var ow_path: String = "res://luxel/islands/%d/overworld.json" % isl_id
	if FileAccess.file_exists(ow_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ow_path))
		if parsed is Dictionary:
			var ow: Dictionary = parsed as Dictionary
			var bounds_w: float = maxf(320.0, float(int(ow.get("width", 80)) * int(ow.get("tile_size", 16))))
			var bounds_h: float = maxf(180.0, float(int(ow.get("height", 48)) * int(ow.get("tile_size", 16))))
			var mpath: String = "res://luxel/islands/%d/overworld.map" % isl_id
			if FileAccess.file_exists(mpath):
				var mp: Dictionary = LxMapFormat.parse_map(mpath)
				bounds_w = maxf(320.0, float(int(mp.get("width", 80)) * int(ow.get("tile_size", 16))))
				bounds_h = maxf(180.0, float(int(mp.get("height", 48)) * int(ow.get("tile_size", 16))))
			# Gate exits with requires_flags
			var gate_n: int = 0
			for ex_v: Variant in (ow.get("exits", []) as Array):
				if not (ex_v is Dictionary):
					continue
				var ex: Dictionary = ex_v as Dictionary
				var rf_v: Variant = ex.get("requires_flags", [])
				if not (rf_v is Array) or (rf_v as Array).is_empty():
					continue
				var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
				var mp2: Vector2 = _world_to_chart(er.get_center(), Vector2(bounds_w, bounds_h))
				out.append({
					"id": "gate_%d_%d" % [isl_id, gate_n], "island": isl_id, "kind": "gate",
					"region": "overworld", "icon": "key",
					"label": LxStrings.text("MAP_LOCKED"),
					"pos": mp2, "reqs": _parse_req_flags(rf_v as Array),
					"world_pos": er.get_center(),
				})
				gate_n += 1
			# Waystones
			var ws_n: int = 0
			for it_v: Variant in (ow.get("interactables", []) as Array):
				if not (it_v is Dictionary) or str((it_v as Dictionary).get("kind", "")) != "waystone":
					continue
				var it: Dictionary = it_v as Dictionary
				var wid: String = str(it.get("id", ""))
				var wpos: Vector2 = LxMapFormat.to_vec2(it.get("pos", []))
				out.append({
					"id": "ws_" + wid, "island": isl_id, "kind": "waystone",
					"waystone_id": wid, "region": "overworld", "icon": "star",
					"label": LxStrings.sanitize(wid.trim_prefix("ws_"), 14),
					"pos": _world_to_chart(wpos, Vector2(bounds_w, bounds_h)),
					"reqs": [], "world_pos": wpos,
				})
				ws_n += 1
				if ws_n >= 4:
					break

	# 6. Folk with Quests on this island
	var q_slots: Array[Vector2] = [Vector2(42.0, 100.0), Vector2(86.0, 128.0), Vector2(126.0, 130.0), Vector2(74.0, 52.0)]
	var qi: int = 0
	for q: Dictionary in LxQuests.current().all_quests():
		if int(q.get("island", 0)) != isl_id:
			continue
		var qid: String = str(q.get("id", ""))
		var place: Dictionary = LxUiNav.resolve_quest_place(q)
		out.append({
			"id": "q_" + qid, "island": isl_id, "kind": "quest",
			"quest_id": qid, "region": str(place.get("region", "overworld")),
			"icon": str(q.get("icon", "book")),
			"label": str(place.get("label", LxFolkData.tr_id("JOURNAL_TAB_QUESTS"))),
			"pos": q_slots[qi % q_slots.size()], "reqs": [],
			"world_pos": Vector2(-1.0, -1.0),
		})
		qi += 1
		if qi >= 4:
			break

	_deoverlap_nodes(out)
	return out


static func _decorate_node(nd: Dictionary, isl_id: int) -> void:
	var kind: String = str(nd.get("kind", ""))
	var reg: String = str(nd.get("region", "overworld"))
	var isl_visited: bool = Lx.state != null and (Lx.state.island_id == isl_id or _any_island_region_visited(isl_id))
	var reg_visited: bool = Lx.state != null and Lx.state.visited_regions.has("%d:%s" % [isl_id, reg])
	var reqs: Array = nd.get("reqs", []) as Array
	var all_met: bool = true
	for r_v: Variant in reqs:
		if r_v is Dictionary:
			var rd: Dictionary = r_v as Dictionary
			var ok: bool = _check_req_flag(str(rd.get("flag", "")), isl_id)
			rd["met"] = ok
			if not ok:
				all_met = false
	match kind:
		"minor_dungeon", "set_piece", "grand_dungeon":
			var dmeta: Dictionary = nd.get("dmeta", {}) as Dictionary
			if LxMapDungeon.is_dungeon_done(dmeta) or (kind == "grand_dungeon" and Lx.state != null and Lx.state.relit_islands.has(isl_id)):
				nd["state"] = "cleared"
			elif reg_visited or (isl_visited and all_met):
				nd["state"] = "open" if all_met else "seen"
			elif isl_visited:
				nd["state"] = "seen"
			else:
				nd["state"] = "unseen"
		"superboss":
			var bid: String = str(nd.get("boss_id", ""))
			if LxMapDungeon._is_boss_dead(bid):
				nd["state"] = "cleared"
			elif reg_visited:
				nd["state"] = "open" if all_met else "seen"
			elif isl_visited and all_met:
				nd["state"] = "seen"
			else:
				nd["state"] = "unseen"
		"gate":
			nd["state"] = "cleared" if all_met else ("seen" if isl_visited else "unseen")
		"waystone":
			var wid: String = str(nd.get("waystone_id", ""))
			var lit: bool = Lx.state != null and Lx.state.lit_waystones.has(wid)
			nd["state"] = "open" if lit else ("seen" if isl_visited else "unseen")
		"quest":
			var qid: String = str(nd.get("quest_id", ""))
			var qsvc: LxQuests = LxQuests.current()
			if qsvc.is_quest_done(qid):
				nd["state"] = "cleared"
			elif qsvc.is_quest_started(qid):
				nd["state"] = "open"
			elif isl_visited:
				nd["state"] = "seen"
			else:
				nd["state"] = "unseen"
		_:
			nd["state"] = "open" if isl_visited else "unseen"


static func _check_req_flag(flag_s: String, isl_id: int) -> bool:
	if flag_s.is_empty():
		return true
	if flag_s == "beacons_3":
		return LxMapInfo.count_beacons(isl_id) >= 3
	if flag_s.begins_with("moths>="):
		return LxQuests.current().get_moth_count() >= int(flag_s.substr(7))
	if flag_s.begins_with("great_lamp_") or flag_s.ends_with("_relit"):
		return Lx.state != null and Lx.state.relit_islands.has(isl_id)
	if Lx.state != null and Lx.state.lit_beacons.has(flag_s):
		return true
	return LxRegionLoader.check_flag_static(flag_s)


static func _parse_req_flags(raw_flags: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var beacon_cnt: int = 0
	for fv: Variant in raw_flags:
		var fs: String = str(fv)
		if fs.is_empty():
			continue
		if fs.begins_with("beacon"):
			beacon_cnt += 1
			if beacon_cnt <= 3:
				out.append({"flag": fs, "icon": "lantern"})
		elif fs.contains("moth"):
			out.append({"flag": fs, "icon": "moth"})
		elif fs.contains("great_lamp") or fs.contains("relit"):
			out.append({"flag": fs, "icon": "crown"})
		else:
			out.append({"flag": fs, "icon": "key"})
	return out


static func _any_island_region_visited(isl_id: int) -> bool:
	if Lx.state == null:
		return false
	if Lx.state.relit_islands.has(isl_id):
		return true
	var pfx: String = "%d:" % isl_id
	for vr: String in Lx.state.visited_regions:
		if vr.begins_with(pfx):
			return true
	return false


static func _world_to_chart(wpos: Vector2, bounds: Vector2) -> Vector2:
	var nx: float = clampf(wpos.x / maxf(1.0, bounds.x), 0.08, 0.92)
	var ny: float = clampf(wpos.y / maxf(1.0, bounds.y), 0.14, 0.86)
	return Vector2(roundf(CHART_RECT.position.x + 12.0 + nx * (CHART_RECT.size.x - 24.0)), roundf(CHART_RECT.position.y + 16.0 + ny * (CHART_RECT.size.y - 28.0)))


static func _deoverlap_nodes(nodes: Array[Dictionary]) -> void:
	for _pass: int in range(6):
		for i: int in range(nodes.size()):
			var pi: Vector2 = nodes[i]["pos"] as Vector2
			for j: int in range(i + 1, nodes.size()):
				var pj: Vector2 = nodes[j]["pos"] as Vector2
				var d: Vector2 = pj - pi
				var dist: float = d.length()
				if dist < 18.0:
					var push: Vector2 = (d.normalized() if dist > 0.1 else Vector2(1.0, 0.35).normalized()) * ((18.0 - dist) * 0.55)
					pi = (pi - push).clamp(CHART_RECT.position + Vector2(14.0, 20.0), CHART_RECT.end - Vector2(14.0, 14.0))
					pj = (pj + push).clamp(CHART_RECT.position + Vector2(14.0, 20.0), CHART_RECT.end - Vector2(14.0, 14.0))
					nodes[i]["pos"] = pi.round()
					nodes[j]["pos"] = pj.round()


# ---- Rendering ----

static func draw_island_page(ci: CanvasItem, isl_id: int, nodes: Array[Dictionary], sel_idx: int, elapsed: float) -> void:
	_draw_chart_frame(ci, isl_id, elapsed)
	if isl_id == 0:
		_draw_hub_links(ci)
	else:
		_draw_island_silhouette_bg(ci, isl_id)
	_draw_nodes(ci, isl_id, nodes, sel_idx, elapsed)
	_draw_player_marker(ci, isl_id, elapsed)
	_draw_info_sidebar(ci, isl_id, nodes, sel_idx)


static func _draw_chart_frame(ci: CanvasItem, isl_id: int, elapsed: float) -> void:
	var bdr: String = "gold" if isl_id == 0 else LxBiomePalette.key(isl_id, "border")
	LxPixelFont.draw_panel(ci, CHART_RECT, "night", bdr, "void")
	# Subtle grid ticks
	var dusk: Color = LxPalette.PAL["dusk"] as Color
	var gx: float = CHART_RECT.position.x + 24.0
	while gx < CHART_RECT.end.x - 10.0:
		ci.draw_rect(Rect2(gx, CHART_RECT.position.y + 2.0, 1.0, 2.0), dusk)
		ci.draw_rect(Rect2(gx, CHART_RECT.end.y - 4.0, 1.0, 2.0), dusk)
		gx += 28.0
	# Island header strip inside top of chart
	var name_txt: String = LxFolkData.tr_id("MAP_HUB_LABEL") if isl_id == 0 else LxStrings.fmt("MAP_ISLAND_FMT", [isl_id, LxStrings.sanitize(str(Lx.get_island_data(isl_id).get("name", "")), 16)])
	var glow_c: Color = (LxPalette.PAL["gold"] as Color) if isl_id == 0 else LxBiomePalette.col(isl_id, "glow")
	LxHudFx.draw_biome_crest(ci, maxi(1, isl_id), CHART_RECT.position + Vector2(9.0, 8.0), glow_c, LxPalette.PAL["cream"] as Color)
	LxPixelFont.draw_left(ci, name_txt.substr(0, 24), CHART_RECT.position + Vector2(16.0, 5.0), glow_c, 1)
	# Soft island prev/next arrows in chart top-right
	var ac: Color = LxPalette.PAL["gold"] if (LxHudFx.flash_reduced() or fmod(elapsed * 2.0, 1.0) < 0.6) else LxPalette.PAL["apricot"]
	LxPixelFont.draw_right(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [isl_id, 8]), CHART_RECT.end.x - 6.0, CHART_RECT.position.y + 5.0, ac, 1)
	ci.draw_rect(Rect2(CHART_RECT.position.x + 4.0, CHART_RECT.position.y + 13.0, CHART_RECT.size.x - 8.0, 1.0), dusk)


static func _draw_island_silhouette_bg(ci: CanvasItem, isl_id: int) -> void:
	var c: Vector2 = CHART_RECT.get_center() + Vector2(0.0, 6.0)
	var fill_c: Color = Color(LxBiomePalette.col(isl_id, "dark"), 0.72)
	var rim_c: Color = Color(LxBiomePalette.col(isl_id, "mid"), 0.55)
	# Organic per-island landmass backdrop matching each island's identity
	match isl_id:
		1:
			ci.draw_rect(Rect2(c - Vector2(68.0, 34.0), Vector2(136.0, 68.0)), fill_c)
			ci.draw_rect(Rect2(c - Vector2(52.0, 42.0), Vector2(104.0, 84.0)), fill_c)
		2:
			ci.draw_rect(Rect2(c - Vector2(72.0, 36.0), Vector2(144.0, 22.0)), fill_c)
			ci.draw_rect(Rect2(c - Vector2(72.0, 14.0), Vector2(36.0, 50.0)), fill_c)
			ci.draw_rect(Rect2(c + Vector2(34.0, -14.0), Vector2(38.0, 50.0)), fill_c)
			ci.draw_rect(Rect2(c - Vector2(36.0, -24.0), Vector2(70.0, 18.0)), Color(LxPalette.PAL["deep"] as Color, 0.75))
		3:
			ci.draw_rect(Rect2(c - Vector2(66.0, 38.0), Vector2(132.0, 74.0)), fill_c)
			ci.draw_rect(Rect2(c - Vector2(26.0, 18.0), Vector2(52.0, 36.0)), rim_c)
		4:
			for pad: Array in [[-54, -22, 46, 32], [-6, -34, 48, 30], [28, -4, 44, 34], [-34, 14, 52, 26]]:
				ci.draw_rect(Rect2(c + Vector2(float(pad[0]), float(pad[1])), Vector2(float(pad[2]), float(pad[3]))), fill_c)
		5:
			ci.draw_arc(c, 42.0, 0.0, TAU, 28, rim_c, 6.0)
			ci.draw_circle(c, 16.0, fill_c)
		6:
			ci.draw_rect(Rect2(c - Vector2(70.0, 38.0), Vector2(140.0, 76.0)), fill_c)
			ci.draw_rect(Rect2(c - Vector2(14.0, 26.0), Vector2(28.0, 56.0)), Color(LxPalette.PAL["coral"] as Color, 0.28))
		7:
			ci.draw_rect(Rect2(c - Vector2(70.0, 36.0), Vector2(64.0, 72.0)), fill_c)
			ci.draw_rect(Rect2(c + Vector2(6.0, -36.0), Vector2(64.0, 72.0)), Color(LxPalette.PAL["void"] as Color, 0.78))
			ci.draw_line(c - Vector2(0.0, 38.0), c + Vector2(0.0, 38.0), LxPalette.PAL["sky"] as Color, 1.0)
		_:
			for sh: Array in [[-68, -32, 44, 28], [-16, -38, 52, 32], [24, -8, 46, 36], [-56, 8, 56, 28]]:
				ci.draw_rect(Rect2(c + Vector2(float(sh[0]), float(sh[1])), Vector2(float(sh[2]), float(sh[3]))), fill_c)
	ci.draw_rect(Rect2(CHART_RECT.position + Vector2(6.0, 16.0), CHART_RECT.size - Vector2(12.0, 22.0)), rim_c, false, 1.0)


static func _draw_hub_links(ci: CanvasItem) -> void:
	var by_id: Dictionary = {}
	for hr: Dictionary in HUB_ROOMS:
		by_id[str(hr["id"])] = hr["pos"] as Vector2
	var col: Color = LxPalette.PAL["apricot"] as Color
	for hr: Dictionary in HUB_ROOMS:
		var a: Vector2 = hr["pos"] as Vector2
		for dst: Variant in (hr.get("links", []) as Array):
			var ds: String = str(dst)
			if by_id.has(ds):
				ci.draw_line(a, by_id[ds] as Vector2, col, 2.0, false)


static func _draw_nodes(ci: CanvasItem, isl_id: int, nodes: Array[Dictionary], sel_idx: int, elapsed: float) -> void:
	var pal: Dictionary = LxPalette.PAL
	var fr: bool = LxHudFx.flash_reduced()
	var pulse: bool = fr or fmod(elapsed * 2.6, 1.0) < 0.55
	for i: int in range(nodes.size()):
		var nd: Dictionary = nodes[i]
		var p: Vector2 = (nd["pos"] as Vector2).round()
		var st: String = str(nd.get("state", "seen"))
		var sel: bool = i == sel_idx
		var pinned: bool = LxUiNav.is_pinned(isl_id, str(nd.get("id", "")))
		var rim_c: Color = _state_color(st)
		var bg_c: Color = (pal["plum"] if sel else pal["void"]) as Color
		# Soft "Next Light" pin halo
		if pinned:
			var hr: float = 9.0 if pulse else 8.0
			ci.draw_arc(p, hr, 0.0, TAU, 14, pal["gold"] as Color, 1.0)
			ci.draw_rect(Rect2(p + Vector2(-1.0, -hr - 2.0), Vector2(3.0, 1.0)), pal["cream"] as Color)
			ci.draw_rect(Rect2(p + Vector2(0.0, -hr - 3.0), Vector2(1.0, 3.0)), pal["gold"] as Color)
		# Node frame (13x13)
		var nr := Rect2(p - Vector2(6.0, 6.0), Vector2(13.0, 13.0))
		ci.draw_rect(nr.grow(1.0), pal["void"] as Color)
		ci.draw_rect(nr, (pal["cream"] if (sel and pulse) else (pal["gold"] if sel else rim_c)) as Color)
		ci.draw_rect(nr.grow(-1.0), bg_c)
		# Icon (dimmed when unseen)
		var mod_c: Color = (pal["mauve"] as Color) if st == "unseen" else Color.WHITE
		var ic: String = "question" if st == "unseen" else str(nd.get("icon", "lantern"))
		LxBubble.draw_icon(ci, ic, p - Vector2(4.0, 4.0), 1.0, mod_c)
		# State corner pip (top-right)
		if st == "cleared":
			ci.draw_rect(Rect2(nr.end.x - 3.0, nr.position.y, 3.0, 3.0), pal["lime"] as Color)
		elif st == "seen" and not (nd.get("reqs", []) as Array).is_empty():
			ci.draw_rect(Rect2(nr.end.x - 3.0, nr.position.y, 3.0, 3.0), pal["coral"] as Color)
		elif str(nd.get("kind", "")) == "quest":
			ci.draw_rect(Rect2(nr.end.x - 3.0, nr.position.y, 3.0, 3.0), pal["gold"] as Color)
		# Gate requirement mini-pips below the node
		var reqs: Array = nd.get("reqs", []) as Array
		if not reqs.is_empty() and st != "cleared" and st != "unseen":
			var rw: float = float(mini(reqs.size(), 4)) * 4.0
			var rx0: float = roundf(p.x - rw * 0.5)
			for ri: int in range(mini(reqs.size(), 4)):
				var met: bool = bool((reqs[ri] as Dictionary).get("met", false))
				ci.draw_rect(Rect2(rx0 + float(ri * 4), nr.end.y + 1.0, 3.0, 3.0), pal["void"] as Color)
				ci.draw_rect(Rect2(rx0 + float(ri * 4) + 1.0, nr.end.y + 2.0, 1.0, 1.0), (pal["lime"] if met else pal["coral"]) as Color)


static func _draw_player_marker(ci: CanvasItem, isl_id: int, elapsed: float) -> void:
	if Lx.state == null or Lx.state.island_id != isl_id:
		return
	var p := Vector2(CHART_RECT.position.x + 14.0, CHART_RECT.end.y - 14.0)
	if isl_id == 0:
		for hr: Dictionary in HUB_ROOMS:
			if str(hr["id"]) == Lx.state.region_id:
				p = (hr["pos"] as Vector2) + Vector2(-9.0, -7.0)
				break
	var flk: bool = LxHudFx.flash_reduced() or fmod(elapsed * 3.0, 1.0) < 0.55
	ci.draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), LxPalette.PAL["void"] as Color)
	ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(3.0, 3.0)), LxPalette.PAL["gold" if flk else "apricot"] as Color)
	ci.draw_rect(Rect2(p, Vector2.ONE), LxPalette.PAL["cream"] as Color)


static func _draw_info_sidebar(ci: CanvasItem, isl_id: int, nodes: Array[Dictionary], sel_idx: int) -> void:
	var pal: Dictionary = LxPalette.PAL
	var bdr: String = "gold" if isl_id == 0 else LxBiomePalette.key(isl_id, "border")
	LxPixelFont.draw_panel(ci, INFO_RECT, "dusk", bdr, "night")
	var x0: float = INFO_RECT.position.x + 5.0
	var y: float = INFO_RECT.position.y + 5.0

	# 1. Counts strip (Moths, Embers, Beacons / Folk)
	var qsvc: LxQuests = LxQuests.current()
	if isl_id == 0:
		var m_tot: int = qsvc.get_moth_count()
		LxBubble.draw_icon(ci, "moth", Vector2(x0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [m_tot, 80]), Vector2(x0 + 12.0, y + 2.0), pal["gold"] as Color, 1)
		var folk_n: int = 0
		if Lx.state != null:
			for k: Variant in Lx.state.story_flags.keys():
				if str(k).begins_with("folk:") and bool(Lx.state.story_flags[k]): folk_n += 1
		LxBubble.draw_icon(ci, "home", Vector2(x0 + 48.0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [folk_n, 10]), Vector2(x0 + 60.0, y + 2.0), pal["cream"] as Color, 1)
	else:
		var mc: Vector2i = qsvc.get_moths_for_island(isl_id)
		LxBubble.draw_icon(ci, "moth", Vector2(x0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [mc.x, maxi(10, mc.y)]), Vector2(x0 + 12.0, y + 2.0), pal["lime" if mc.x >= maxi(10, mc.y) else "gold"] as Color, 1)
		var emb: int = Lx.state.ember_pieces if Lx.state != null else 0
		LxBubble.draw_icon(ci, "ember", Vector2(x0 + 46.0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [emb, 16]), Vector2(x0 + 58.0, y + 2.0), pal["apricot"] as Color, 1)
		y += 12.0
		var b_lit: int = LxMapInfo.count_beacons(isl_id)
		LxBubble.draw_icon(ci, "lantern", Vector2(x0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [b_lit, 3]), Vector2(x0 + 12.0, y + 2.0), pal["cream"] as Color, 1)
		var d_list: Array[Dictionary] = LxMapInfo.get_island_dungeons(isl_id)
		var d_done: int = 0
		for dd: Dictionary in d_list:
			if LxMapDungeon.is_dungeon_done(dd): d_done += 1
		LxBubble.draw_icon(ci, "crown", Vector2(x0 + 46.0, y), 1.0)
		LxPixelFont.draw_left(ci, LxStrings.fmt("MAP_WS_COUNT_FMT", [d_done, d_list.size()]), Vector2(x0 + 58.0, y + 2.0), pal["lime" if (not d_list.is_empty() and d_done == d_list.size()) else "sky"] as Color, 1)

	var div_y: float = INFO_RECT.position.y + 30.0
	ci.draw_rect(Rect2(x0, div_y, INFO_RECT.size.x - 10.0, 1.0), pal["night"] as Color)

	# 2. Selected node details card
	var card_r := Rect2(x0 - 1.0, div_y + 3.0, INFO_RECT.size.x - 8.0, 62.0)
	LxPixelFont.draw_panel(ci, card_r, "night", "mauve", "void")
	if sel_idx >= 0 and sel_idx < nodes.size():
		var nd: Dictionary = nodes[sel_idx]
		var st: String = str(nd.get("state", "seen"))
		var pinned: bool = LxUiNav.is_pinned(isl_id, str(nd.get("id", "")))
		LxBubble.draw_icon(ci, "question" if st == "unseen" else str(nd.get("icon", "lantern")), card_r.position + Vector2(4.0, 4.0), 1.0)
		var title_s: String = LxFolkData.tr_id("JOURNAL_UNSEEN") if st == "unseen" else str(nd.get("label", ""))
		LxPixelFont.draw_left(ci, title_s.substr(0, 16), card_r.position + Vector2(16.0, 5.0), _state_color(st), 1)
		# State badge
		var st_key: String = "JOURNAL_Q_DONE" if st == "cleared" else ("JOURNAL_Q_OPEN" if st == "open" else ("MAP_LOCKED" if st == "seen" else "JOURNAL_UNSEEN"))
		LxPixelFont.draw_left(ci, LxFolkData.tr_id(st_key), card_r.position + Vector2(5.0, 17.0), _state_color(st), 1)
		if pinned:
			LxPixelFont.draw_right(ci, LxUiNav.tr_any("ISL3_HUD_PIN", "MAP_CURRENT"), card_r.end.x - 4.0, card_r.position.y + 17.0, pal["gold"] as Color, 1)
		# Gate requirement icons row
		var reqs: Array = nd.get("reqs", []) as Array
		if not reqs.is_empty():
			for ri: int in range(mini(reqs.size(), 5)):
				var rd: Dictionary = reqs[ri] as Dictionary
				var rx: float = card_r.position.x + 5.0 + float(ri * 14)
				var ry: float = card_r.position.y + 27.0
				var met: bool = bool(rd.get("met", false))
				ci.draw_rect(Rect2(rx - 1.0, ry - 1.0, 11.0, 11.0), (pal["lime"] if met else pal["coral"]) as Color)
				ci.draw_rect(Rect2(rx, ry, 9.0, 9.0), pal["void"] as Color)
				LxBubble.draw_icon(ci, str(rd.get("icon", "key")), Vector2(rx, ry), 1.0, Color.WHITE if met else pal["stone"] as Color)
		# Action cue inside card bottom
		var k: String = str(nd.get("kind", ""))
		var act_s: String = LxStrings.fmt("HUD_KEY_PROMPT_FMT", ["P", LxUiNav.tr_any("ISL3_HUD_PIN", "MAP_CURRENT")])
		LxPixelFont.draw_left(ci, act_s, card_r.position + Vector2(5.0, 42.0), pal["gold"] as Color, 1)
		if k == "waystone" and st == "open":
			LxPixelFont.draw_left(ci, LxStrings.text("MAP_TRAVEL_PROMPT").substr(0, 18), card_r.position + Vector2(5.0, 51.0), pal["sky"] as Color, 1)
		elif k in ["minor_dungeon", "set_piece", "grand_dungeon"]:
			LxPixelFont.draw_left(ci, LxStrings.fmt("HUD_KEY_PROMPT_FMT", ["E", LxFolkData.tr_id("MAP_TAB_DUNGEON")]), card_r.position + Vector2(5.0, 51.0), pal["ice"] as Color, 1)

	# 3. Compact 4-state legend at sidebar bottom
	var ly: float = INFO_RECT.end.y - 26.0
	var states: Array[Array] = [["unseen", "JOURNAL_UNSEEN"], ["seen", "MAP_LOCKED"], ["open", "JOURNAL_Q_OPEN"], ["cleared", "JOURNAL_Q_DONE"]]
	for si: int in range(4):
		var lx: float = x0 + float(si % 2) * 45.0
		var ry2: float = ly + float(si / 2) * 10.0
		ci.draw_rect(Rect2(lx, ry2 + 1.0, 4.0, 4.0), _state_color(str(states[si][0])))
		LxPixelFont.draw_left(ci, LxFolkData.tr_id(str(states[si][1])).substr(0, 6), Vector2(lx + 6.0, ry2), pal["stone"] as Color, 1)

static func hit_test_node(nodes: Array[Dictionary], pos: Vector2) -> int:
	for i: int in range(nodes.size()):
		if pos.distance_to(nodes[i]["pos"] as Vector2) <= 9.0: return i
	return -1

static func _state_color(st: String) -> Color:
	var pal: Dictionary = LxPalette.PAL
	match st:
		"cleared": return pal["lime"] as Color
		"open": return pal["gold"] as Color
		"seen": return pal["sky"] as Color
		_: return pal["mauve"] as Color
