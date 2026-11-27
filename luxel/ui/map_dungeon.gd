class_name LxMapDungeon
extends RefCounted
## Builds and renders a room-graph dungeon map from region JSON exits + optional registry map:[col,row].
## Shows visited/adjacent/current rooms, locks, uncollected keys, boss/mini marks,
## unexplored exit stubs, and the active room respawn anchor.

static var _graph_cache: Dictionary = {} # "island:dungeon_id" -> static graph template


static func clear_cache() -> void:
	_graph_cache.clear()


static func build_graph(island_id: int, dungeon_id: String) -> Dictionary:
	var packs: LxPackRegistry = Lx.packs if Lx.packs != null else Lx.ensure_packs()
	var dmeta: Dictionary = packs.dungeon(dungeon_id)
	if dmeta.is_empty():
		return {}
	var key: String = "%d:%s" % [island_id, dungeon_id]
	var tpl: Dictionary
	if _graph_cache.has(key):
		tpl = _graph_cache[key] as Dictionary
	else:
		tpl = _build_template(island_id, dungeon_id, dmeta, packs)
		_graph_cache[key] = tpl
	return _decorate_live_state(tpl)


static func _build_template(island_id: int, dungeon_id: String, dmeta: Dictionary, packs: LxPackRegistry) -> Dictionary:
	var regs: Array[String] = []
	for r_v: Variant in (dmeta.get("regions", []) as Array):
		var rs: String = str(r_v).strip_edges()
		if not rs.is_empty() and not regs.has(rs):
			regs.append(rs)
	var entry_r: String = str(dmeta.get("entry", regs[0] if not regs.is_empty() else "")).strip_edges()
	if not entry_r.is_empty() and not regs.has(entry_r):
		regs.insert(0, entry_r)

	var boss_id: String = str(dmeta.get("boss", "")).strip_edges()
	var mini_id: String = str(dmeta.get("mini_boss", "")).strip_edges()
	var boss_reg: String = str(packs.boss_meta(boss_id).get("region", "")) if not boss_id.is_empty() else ""
	var mini_reg: String = str(packs.boss_meta(mini_id).get("region", "")) if not mini_id.is_empty() else ""

	var raw_nodes: Dictionary = {}
	for r: String in regs:
		var jpath: String = "res://luxel/islands/%d/%s.json" % [island_id, r]
		var mpath: String = "res://luxel/islands/%d/%s.map" % [island_id, r]
		var j: Dictionary = {}
		if FileAccess.file_exists(jpath):
			var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(jpath))
			if p is Dictionary:
				j = p as Dictionary
		var bounds_sz: Vector2 = _read_map_bounds(mpath, j)
		var rmeta: Dictionary = packs.region_meta(island_id, r)
		var has_explicit: bool = false
		var explicit_pos := Vector2i.ZERO
		var mv: Variant = rmeta.get("map", j.get("map", null))
		if mv is Array and (mv as Array).size() >= 2:
			has_explicit = true
			explicit_pos = Vector2i(int((mv as Array)[0]), int((mv as Array)[1]))
		var has_b: bool = (not boss_reg.is_empty() and r == boss_reg)
		var has_m: bool = (not mini_reg.is_empty() and r == mini_reg)
		for en_v: Variant in (j.get("enemies", []) as Array):
			if en_v is Dictionary:
				var ek: String = str((en_v as Dictionary).get("kind", "")).to_lower()
				var eb: String = str((en_v as Dictionary).get("boss_id", "")).to_lower()
				if not boss_id.is_empty() and (ek == boss_id or eb == boss_id): has_b = true
				if not mini_id.is_empty() and (ek == mini_id or eb == mini_id): has_m = true
		var lock_door_ids: Array[String] = []
		var key_ids: Array[String] = []
		var boss_key_ids: Array[String] = []
		var has_anchor_obj: bool = false
		for it_v: Variant in (j.get("interactables", []) as Array):
			if not (it_v is Dictionary):
				continue
			var it: Dictionary = it_v as Dictionary
			var ik: String = str(it.get("kind", "")).to_lower()
			var iid: String = str(it.get("id", ""))
			if ik in ["locked_door", "boss_door", "boss_key", "door"]:
				var pr: Dictionary = it.get("props", {}) as Dictionary if it.get("props") is Dictionary else {}
				var dt: String = str(pr.get("door_type", ik))
				if dt in ["locked_door", "boss_door", "boss_key", "wick_key"]:
					lock_door_ids.append(iid)
			if ik == "wick_key":
				key_ids.append(iid)
			elif ik in ["boss_key", "keepers_flame"]:
				boss_key_ids.append(iid)
			elif ik == "room_anchor":
				has_anchor_obj = true
		var exit_list: Array[Dictionary] = []
		var has_outside_exit: bool = false
		for ex_v: Variant in (j.get("exits", []) as Array):
			if not (ex_v is Dictionary): continue
			var ex: Dictionary = ex_v as Dictionary
			var to_isl: int = int(ex.get("to_island", island_id))
			var to_reg: String = str(ex.get("to_region", ""))
			if to_isl != island_id or not regs.has(to_reg):
				if not to_reg.is_empty():
					has_outside_exit = true
				continue
			if to_reg == r: continue
			var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
			exit_list.append({
				"to": to_reg,
				"dir": _infer_dir(er, bounds_sz),
				"locked_door_id": str(ex.get("locked_door_id", "")),
				"requires_flags": (ex.get("requires_flags", []) as Array).duplicate() if ex.get("requires_flags") is Array else [],
			})
		raw_nodes[r] = {
			"id": r, "has_explicit": has_explicit, "pos": explicit_pos,
			"exits": exit_list, "has_boss": has_b, "has_mini": has_m,
			"lock_door_ids": lock_door_ids, "key_ids": key_ids, "boss_key_ids": boss_key_ids,
			"has_anchor_obj": has_anchor_obj, "has_outside_exit": has_outside_exit,
			"is_entry": r == entry_r,
		}

	var occupied: Dictionary = {}
	var placed: Dictionary = {}
	for r: String in regs:
		var nd: Dictionary = raw_nodes[r] as Dictionary
		if bool(nd["has_explicit"]):
			var p: Vector2i = nd["pos"] as Vector2i
			occupied[p] = r; placed[r] = p

	var q: Array[String] = []
	if not entry_r.is_empty() and raw_nodes.has(entry_r):
		if not placed.has(entry_r):
			var p0: Vector2i = _find_free_cell(Vector2i.ZERO, occupied)
			occupied[p0] = entry_r; placed[entry_r] = p0
		q.append(entry_r)
	for r: String in placed.keys():
		if not q.has(str(r)): q.append(str(r))

	var head: int = 0
	while head < q.size():
		var cur_r: String = q[head]; head += 1
		var cur_p: Vector2i = placed[cur_r] as Vector2i
		var nd: Dictionary = raw_nodes[cur_r] as Dictionary
		for ex: Dictionary in (nd["exits"] as Array):
			var nxt: String = str(ex["to"])
			if not placed.has(nxt) and raw_nodes.has(nxt):
				var np: Vector2i = _find_free_cell(cur_p + (ex["dir"] as Vector2i), occupied)
				occupied[np] = nxt; placed[nxt] = np; q.append(nxt)

	for r: String in regs:
		if not placed.has(r):
			var fp: Vector2i = _find_free_cell(Vector2i(placed.size(), 0), occupied)
			occupied[fp] = r; placed[r] = fp

	var min_x: int = 9999; var min_y: int = 9999; var max_x: int = -9999; var max_y: int = -9999
	for p: Vector2i in placed.values():
		min_x = mini(min_x, p.x); min_y = mini(min_y, p.y)
		max_x = maxi(max_x, p.x); max_y = maxi(max_y, p.y)
	if min_x > max_x:
		min_x = 0; min_y = 0; max_x = 0; max_y = 0

	var nodes_out: Dictionary = {}
	var edges_out: Array[Dictionary] = []
	var seen_edges: Dictionary = {}
	for r: String in regs:
		var nd: Dictionary = (raw_nodes[r] as Dictionary).duplicate(true)
		nd["pos"] = (placed[r] as Vector2i) - Vector2i(min_x, min_y)
		nodes_out[r] = nd
		for ex: Dictionary in (nd["exits"] as Array):
			var to_r: String = str(ex["to"])
			var ek: String = "%s|%s" % ([r, to_r] if r < to_r else [to_r, r])
			if not seen_edges.has(ek):
				seen_edges[ek] = true
				edges_out.append({
					"a": r, "b": to_r,
					"locked_door_id": str(ex.get("locked_door_id", "")),
					"requires_flags": ex.get("requires_flags", []),
				})
	return {
		"island_id": island_id, "dungeon_id": dungeon_id, "dmeta": dmeta.duplicate(true),
		"nodes": nodes_out, "edges": edges_out,
		"grid_w": maxi(1, max_x - min_x + 1), "grid_h": maxi(1, max_y - min_y + 1),
	}


static func _decorate_live_state(tpl: Dictionary) -> Dictionary:
	var out: Dictionary = tpl.duplicate(true)
	var isl: int = int(out.get("island_id", 1))
	var nodes: Dictionary = out["nodes"] as Dictionary
	var visited_set: Dictionary = {}
	var anchor_reg: String = Lx.state.room_anchor_region if Lx.state != null else ""
	for r_v: Variant in nodes.keys():
		var r: String = str(r_v)
		var rkey: String = "%d:%s" % [isl, r]
		var vis: bool = Lx.state != null and Lx.state.visited_regions.has(rkey)
		if vis: visited_set[r] = true
		var nd: Dictionary = nodes[r] as Dictionary
		nd["visited"] = vis
		nd["current"] = Lx.state != null and Lx.state.island_id == isl and Lx.state.region_id == r
		nd["is_anchor"] = (anchor_reg == rkey) or (vis and bool(nd.get("has_anchor_obj", false)) and anchor_reg.is_empty() and bool(nd.get("current", false)))
		var has_lock: bool = false
		for did: Variant in (nd.get("lock_door_ids", []) as Array):
			var ds: String = str(did)
			if not ds.is_empty() and not _door_opened(isl, [r], ds):
				has_lock = true; break
		nd["has_lock"] = has_lock
		nd["has_key"] = _any_uncollected(isl, r, nd.get("key_ids", []) as Array)
		nd["has_boss_key"] = _any_uncollected(isl, r, nd.get("boss_key_ids", []) as Array)
		nd["unexplored_dirs"] = []
	for e: Dictionary in (out["edges"] as Array):
		var a: String = str(e["a"]); var b: String = str(e["b"])
		var locked: bool = false
		var ld: String = str(e.get("locked_door_id", ""))
		if not ld.is_empty() and not _door_opened(isl, [a, b], ld):
			locked = true
		for fl: Variant in (e.get("requires_flags", []) as Array):
			if not LxRegionLoader.check_flag_static(str(fl)):
				locked = true
		e["locked"] = locked
		if visited_set.has(a) and not visited_set.has(b) and nodes.has(b):
			(nodes[b] as Dictionary)["adjacent"] = true
			var pa: Vector2i = (nodes[a] as Dictionary)["pos"] as Vector2i
			var pb: Vector2i = (nodes[b] as Dictionary)["pos"] as Vector2i
			((nodes[a] as Dictionary)["unexplored_dirs"] as Array).append((pb - pa).clamp(Vector2i(-1, -1), Vector2i(1, 1)))
		elif visited_set.has(b) and not visited_set.has(a) and nodes.has(a):
			(nodes[a] as Dictionary)["adjacent"] = true
			var pa2: Vector2i = (nodes[b] as Dictionary)["pos"] as Vector2i
			var pb2: Vector2i = (nodes[a] as Dictionary)["pos"] as Vector2i
			((nodes[b] as Dictionary)["unexplored_dirs"] as Array).append((pb2 - pa2).clamp(Vector2i(-1, -1), Vector2i(1, 1)))
	return out


static func _any_uncollected(isl: int, reg: String, ids: Array) -> bool:
	if ids.is_empty():
		return false
	if Lx.state == null:
		return true
	for iid_v: Variant in ids:
		var iid: String = str(iid_v)
		var st_v: Variant = Lx.state.interactable_states.get("%d:%s:%s" % [isl, reg, iid], Lx.state.interactable_states.get(iid, null))
		if st_v is Dictionary and (bool((st_v as Dictionary).get("collected", false)) or bool((st_v as Dictionary).get("opened", false))):
			continue
		return true
	return false


static func dungeon_pill_rect(rect: Rect2, idx: int, count: int) -> Rect2:
	var usable_w: float = rect.size.x - 14.0
	var pw: float = minf(66.0, floorf((usable_w - float(maxi(0, count - 1)) * 3.0) / float(maxi(1, count))))
	return Rect2(rect.position.x + 7.0 + float(idx) * (pw + 3.0), rect.position.y + 15.0, pw, 11.0)


static func draw_dungeon_graph(
	ci: CanvasItem, rect: Rect2, graph: Dictionary, elapsed: float,
	island_dungeons: Array[Dictionary] = [], sel_dng_idx: int = 0
) -> void:
	LxPixelFont.draw_panel(ci, rect, "night", "dusk", "void")
	for corner: Vector2 in [rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 3.0, rect.position.y + 1.0), Vector2(rect.position.x + 1.0, rect.end.y - 3.0), rect.end - Vector2(3.0, 3.0)]:
		ci.draw_rect(Rect2(corner, Vector2(2.0, 2.0)), LxPalette.PAL["gold"])
	if graph.is_empty():
		LxPixelFont.draw_centered(ci, LxStrings.text("MAP_NO_DUNGEONS"), rect.get_center().x, rect.get_center().y - 3.0, LxPalette.PAL["mauve"], 1)
		return

	var isl: int = int(graph.get("island_id", 1))
	var did: String = str(graph.get("dungeon_id", ""))
	var dmeta: Dictionary = graph.get("dmeta", {}) as Dictionary
	var nodes: Dictionary = graph.get("nodes", {}) as Dictionary
	var edges: Array = graph.get("edges", []) as Array
	var gw: int = maxi(1, int(graph.get("grid_w", 1)))
	var gh: int = maxi(1, int(graph.get("grid_h", 1)))

	# Header bar: dungeon name + rooms explored + keys held
	var dname: String = _dungeon_display_name(dmeta, did)
	var visited_n: int = 0
	for nd_v: Variant in nodes.values():
		if bool((nd_v as Dictionary).get("visited", false)): visited_n += 1
	var keys_n: int = (Lx.state.get_key_count(did, "wick_key") + Lx.state.get_key_count(did, "keepers_flame")) if Lx.state != null else 0
	var done: bool = is_dungeon_done(dmeta)
	var glow: Color = LxBiomePalette.col(isl, "glow")
	LxPixelFont.draw_left(ci, dname, rect.position + Vector2(7.0, 5.0), LxPalette.PAL["lime"] if done else glow, 1)
	var stats_r: String = "%s  %s" % [LxStrings.fmt("MAP_DUNGEON_ROOMS_FMT", [visited_n, nodes.size()]), LxStrings.fmt("MAP_DUNGEON_KEYS_FMT", [keys_n])]
	LxPixelFont.draw_right(ci, stats_r, rect.end.x - 7.0, rect.position.y + 5.0, LxPalette.PAL["apricot"] if keys_n > 0 else LxPalette.PAL["stone"], 1)
	ci.draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 13.0, rect.size.x - 10.0, 1.0), LxPalette.PAL["dusk"])

	# Multi-dungeon switcher pills when the island has > 1 dungeon
	var top_pad: float = 18.0
	if island_dungeons.size() > 1:
		top_pad = 30.0
		for di: int in range(island_dungeons.size()):
			var pr: Rect2 = dungeon_pill_rect(rect, di, island_dungeons.size())
			var dm: Dictionary = island_dungeons[di]
			var is_sel: bool = di == sel_dng_idx
			var is_done: bool = is_dungeon_done(dm)
			LxPixelFont.draw_panel(ci, pr, "plum" if is_sel else "void", "gold" if is_sel else ("lime" if is_done else "dusk"), "night")
			var max_c: int = maxi(4, int((pr.size.x - 8.0) / 4.0))
			var full_nm: String = _dungeon_display_name(dm, str(dm.get("id", "")))
			if full_nm.length() > max_c and full_nm.to_upper().begins_with("THE "):
				full_nm = full_nm.substr(4)
			var short_nm: String = full_nm.substr(0, max_c)
			LxPixelFont.draw_centered(ci, short_nm, pr.get_center().x, pr.position.y + 3.0, LxPalette.PAL["gold"] if is_sel else (LxPalette.PAL["lime"] if is_done else LxPalette.PAL["stone"]), 1)

	# Layout room grid inside inner plot area
	var plot := Rect2(rect.position.x + 10.0, rect.position.y + top_pad, rect.size.x - 20.0, rect.size.y - top_pad - 14.0)
	var cell_w: float = clampf(floorf(plot.size.x / float(gw)), 12.0, 30.0)
	var cell_h: float = clampf(floorf(plot.size.y / float(gh)), 10.0, 20.0)
	var room_w: float = clampf(cell_w - 6.0, 8.0, 20.0)
	var room_h: float = clampf(cell_h - 4.0, 6.0, 13.0)
	var ox: float = roundf(plot.position.x + (plot.size.x - cell_w * float(gw)) * 0.5)
	var oy: float = roundf(plot.position.y + (plot.size.y - cell_h * float(gh)) * 0.5)

	var centers: Dictionary = {}
	for r_v: Variant in nodes.keys():
		var gp: Vector2i = (nodes[r_v] as Dictionary)["pos"] as Vector2i
		centers[str(r_v)] = Vector2(roundf(ox + (float(gp.x) + 0.5) * cell_w), roundf(oy + (float(gp.y) + 0.5) * cell_h))

	# Draw exit connectors & lock blocks
	for e_v: Variant in edges:
		var e: Dictionary = e_v as Dictionary
		var a: String = str(e["a"]); var b: String = str(e["b"])
		var na: Dictionary = nodes.get(a, {}) as Dictionary; var nb: Dictionary = nodes.get(b, {}) as Dictionary
		if not (bool(na.get("visited", false)) or bool(nb.get("visited", false))):
			continue
		var pa: Vector2 = centers[a] as Vector2; var pb: Vector2 = centers[b] as Vector2
		var locked: bool = bool(e.get("locked", false))
		var both_vis: bool = bool(na.get("visited", false)) and bool(nb.get("visited", false))
		var col: Color = LxPalette.PAL["coral"] if locked else (LxPalette.PAL["stone"] if both_vis else LxPalette.PAL["apricot"])
		ci.draw_line(pa, pb, col, 2.0 if both_vis else 1.0, false)
		if locked:
			var mid: Vector2 = pa.lerp(pb, 0.5).round()
			ci.draw_rect(Rect2(mid - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), LxPalette.PAL["void"])
			ci.draw_rect(Rect2(mid - Vector2.ONE, Vector2(2.0, 2.0)), LxPalette.PAL["coral"])

	# Draw rooms, unexplored exit stubs, keys, boss/mini marks, and room anchor
	var fr: bool = LxHudFx.flash_reduced()
	var blink: bool = fr or fmod(elapsed * 3.0, 1.0) < 0.55
	var boss_dead: bool = _is_boss_dead(str(dmeta.get("boss", "")))
	var mini_dead: bool = _is_boss_dead(str(dmeta.get("mini_boss", "")))
	for r_v: Variant in nodes.keys():
		var nd: Dictionary = nodes[r_v] as Dictionary
		var vis: bool = bool(nd.get("visited", false))
		var adj: bool = bool(nd.get("adjacent", false))
		var cur: bool = bool(nd.get("current", false))
		var has_b: bool = bool(nd.get("has_boss", false))
		if not vis and not adj and not has_b:
			continue
		var c: Vector2 = centers[str(r_v)] as Vector2
		var rr := Rect2(roundf(c.x - room_w * 0.5), roundf(c.y - room_h * 0.5), room_w, room_h)
		var fill_c: Color = LxPalette.PAL["plum"] if cur else (LxPalette.PAL["teal"] if vis else LxPalette.PAL["night"])
		var rim_c: Color = LxPalette.PAL["gold"] if cur else (LxPalette.PAL["cream"] if vis else LxPalette.PAL["dusk"])
		ci.draw_rect(rr, rim_c)
		ci.draw_rect(rr.grow(-1.0), fill_c)
		# Unexplored exit pips on visited room edges
		if vis:
			for udir_v: Variant in (nd.get("unexplored_dirs", []) as Array):
				var ud: Vector2i = udir_v as Vector2i
				var ex_p := Vector2(roundf(c.x + float(ud.x) * (room_w * 0.5 + 1.0)), roundf(c.y + float(ud.y) * (room_h * 0.5 + 1.0)))
				ci.draw_rect(Rect2(ex_p - Vector2.ONE, Vector2(2.0, 2.0)), LxPalette.PAL["gold"] if blink else LxPalette.PAL["apricot"])
		# Entry marker (bottom-left sky pip)
		if bool(nd.get("is_entry", false)) and (vis or adj):
			ci.draw_rect(Rect2(rr.position.x + 1.0, rr.end.y - 3.0, 2.0, 2.0), LxPalette.PAL["sky"])
		# Lock dot (top-right coral)
		if bool(nd.get("has_lock", false)) and vis:
			ci.draw_rect(Rect2(rr.end.x - 3.0, rr.position.y + 1.0, 2.0, 2.0), LxPalette.PAL["coral"])
		# Uncollected key / boss key pip (top-left gold/apricot)
		if vis and (bool(nd.get("has_key", false)) or bool(nd.get("has_boss_key", false))):
			ci.draw_rect(Rect2(rr.position.x + 1.0, rr.position.y + 1.0, 2.0, 2.0), LxPalette.PAL["gold"] if bool(nd.get("has_boss_key", false)) else LxPalette.PAL["apricot"])
		# Room Anchor mark (bottom-right ice/sky cross)
		if bool(nd.get("is_anchor", false)):
			var ax: float = rr.end.x - 3.0; var ay: float = rr.end.y - 3.0
			ci.draw_rect(Rect2(ax - 1.0, ay, 3.0, 1.0), LxPalette.PAL["ice"])
			ci.draw_rect(Rect2(ax, ay - 1.0, 1.0, 3.0), LxPalette.PAL["sky"])
		# Boss / mini-boss / current Wick dot
		if has_b:
			var bc: Color = LxPalette.PAL["lime"] if boss_dead else LxPalette.PAL["coral"]
			ci.draw_rect(Rect2(c - Vector2(2.0, 1.0), Vector2(5.0, 3.0)), bc)
			ci.draw_rect(Rect2(c - Vector2(1.0, 2.0), Vector2(3.0, 1.0)), LxPalette.PAL["gold"] if not boss_dead else LxPalette.PAL["cream"])
		elif bool(nd.get("has_mini", false)) and (vis or adj):
			ci.draw_rect(Rect2(c - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), LxPalette.PAL["lime"] if mini_dead else LxPalette.PAL["apricot"])
		if cur:
			ci.draw_rect(Rect2(c - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), LxPalette.PAL["cream"] if blink else LxPalette.PAL["gold"])

	# Compact bottom legend: HERE, BOSS, LOCK, KEY, ANCHOR
	var ly: float = rect.end.y - 9.0
	var lx: float = rect.position.x + 8.0
	for item: Array in [
		[LxPalette.PAL["gold"], LxStrings.text("MAP_CURRENT")],
		[LxPalette.PAL["coral"], LxStrings.text("MAP_DUNGEON_BOSS")],
		[LxPalette.PAL["wine"], LxStrings.text("MAP_DUNGEON_LOCKED")],
		[LxPalette.PAL["apricot"], LxStrings.text("MAP_DUNGEON_KEYS_FMT").substr(0, 3)],
		[LxPalette.PAL["ice"], LxUiNav.tr_any("MAP_DUNGEON_ANCHOR", "ISL3_HUD_PIN")],
	]:
		ci.draw_rect(Rect2(lx, ly + 1.0, 3.0, 3.0), item[0] as Color)
		var lbl: String = str(item[1])
		LxPixelFont.draw_left(ci, lbl, Vector2(lx + 5.0, ly), LxPalette.PAL["stone"], 1)
		lx += float(LxPixelFont.width(lbl, 1)) + 15.0


static func is_dungeon_done(dmeta: Dictionary) -> bool:
	if Lx.state == null: return false
	var df: String = str(dmeta.get("done_flag", "dungeon_done:" + str(dmeta.get("id", ""))))
	if not df.is_empty() and LxRegionLoader.check_flag_static(df): return true
	var boss: String = str(dmeta.get("boss", ""))
	return not boss.is_empty() and _is_boss_dead(boss)


static func _is_boss_dead(boss_id: String) -> bool:
	if boss_id.is_empty() or Lx.state == null: return false
	if Lx.state.defeated_bosses.has(boss_id): return true
	if Lx.packs != null:
		var canon: String = str(Lx.packs.boss_meta(boss_id).get("id", boss_id))
		if Lx.state.defeated_bosses.has(canon): return true
	return false


static func _dungeon_display_name(dmeta: Dictionary, fallback_id: String) -> String:
	var nk: String = str(dmeta.get("name_key", ""))
	if not nk.is_empty() and LxFolkData.has_str(nk): return LxFolkData.tr_id(nk)
	var nm: String = str(dmeta.get("name", fallback_id))
	return LxStrings.sanitize(nm, 28)


static func _read_map_bounds(mpath: String, j: Dictionary) -> Vector2:
	var ts: float = float(j.get("tile_size", 16))
	if FileAccess.file_exists(mpath):
		var m: Dictionary = LxMapFormat.parse_map(mpath)
		return Vector2(float(int(m.get("width", 20))) * ts, float(int(m.get("height", 12))) * ts)
	return Vector2(320.0, 192.0)


static func _infer_dir(er: Rect2, bounds_sz: Vector2) -> Vector2i:
	if not er.has_area() or bounds_sz.x <= 1.0 or bounds_sz.y <= 1.0:
		return Vector2i(1, 0)
	var c: Vector2 = er.get_center()
	var nx: float = c.x / bounds_sz.x
	var ny: float = c.y / bounds_sz.y
	if ny <= 0.25: return Vector2i(0, -1)
	if ny >= 0.75: return Vector2i(0, 1)
	if nx <= 0.25: return Vector2i(-1, 0)
	if nx >= 0.75: return Vector2i(1, 0)
	return Vector2i(1, 0)


static func _find_free_cell(want: Vector2i, occupied: Dictionary) -> Vector2i:
	if not occupied.has(want):
		return want
	for radius: int in range(1, 16):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cand := want + Vector2i(dx, dy)
				if not occupied.has(cand):
					return cand
	return want + Vector2i(16, 0)


## Doors are saved as "island:region:id" (bare ids only for legacy regions in old saves).
static func _door_opened(isl: int, regions: Array, door_id: String) -> bool:
	if Lx.state == null:
		return false
	for reg_v: Variant in regions:
		var reg: String = str(reg_v)
		if Lx.state.opened_doors.has("%d:%s:%s" % [isl, reg, door_id]):
			return true
		if LxLegacy.is_legacy_region(isl, reg) and Lx.state.opened_doors.has(door_id):
			return true
	return false
