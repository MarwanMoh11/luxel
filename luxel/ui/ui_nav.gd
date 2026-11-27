class_name LxUiNav
extends RefCounted
## Shared navigation, Pin ("Next Light"), island-visit tracking, Previously-bar icons,
## rich save-slot summaries, and Pause/Map/Journal/Panes top tab bar for luxel/ui/.

const TAB_BAR_Y: float = 0.0
const TAB_BAR_H: float = 11.0
const TAB_IDS: Array[String] = ["PAUSE_TITLE", "PAUSE_MAP", "PAUSE_JOURNAL", "PAUSE_PANES"]
const TAB_SCREENS: Array[int] = [3, 4, 13, 14] # LxUiRoot.Screen: PAUSE, MAP, JOURNAL, PANES
const ONE_DAY_SECS: int = 86400

static var _region_exits_cache: Dictionary = {} # isl_id -> Dictionary[reg -> Array[{to, center}]]
static var _moth_regions_cache: Dictionary = {} # isl_id -> Array[{id, region, kind}]
static var _quest_regions_cache: Dictionary = {} # quest_id -> {island, region, label}


static func tr_any(preferred_id: String, fallback_id: String) -> String:
	if not preferred_id.is_empty() and LxFolkData.has_str(preferred_id):
		return LxFolkData.tr_id(preferred_id)
	return LxFolkData.tr_id(fallback_id)


static func fmt_pair(label_id: String, val_text: String) -> String:
	return LxStrings.fmt("FMT_PAIR", [LxFolkData.tr_id(label_id), val_text])


static func format_epic_time(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	var hrs: int = total / 3600
	var mins: int = (total % 3600) / 60
	var secs: int = total % 60
	var m_s: String = ("0" + str(mins)) if (hrs > 0 and mins < 10) else str(mins)
	var s_s: String = ("0" + str(secs)) if secs < 10 else str(secs)
	if hrs > 0:
		return LxStrings.fmt("FMT_CLOCK", [str(hrs), LxStrings.fmt("FMT_CLOCK", [m_s, s_s])])
	return LxStrings.fmt("FMT_CLOCK", [m_s, s_s])


# ---- Pause <-> Map <-> Journal <-> Panes Top Tab Bar ----

static func should_show_pause_tabs(active_screen: int) -> bool:
	if Lx.ui == null:
		return false
	if active_screen == 14: # PANES: hide pause bar when opened from Rest Shop/Workshop
		var ret: int = int(Lx.ui.get("_return_screen"))
		if ret != 3 and ret != 4 and ret != 13 and ret != 14:
			return false
	return TAB_SCREENS.has(active_screen)


static func tab_rect(idx: int) -> Rect2:
	var start_x: float = 52.0
	var w: float = 52.0
	var gap: float = 3.0
	return Rect2(start_x + float(idx) * (w + gap), TAB_BAR_Y, w, TAB_BAR_H)


static func draw_pause_tab_bar(ci: CanvasItem, active_screen: int) -> void:
	if not should_show_pause_tabs(active_screen):
		return
	var pal: Dictionary = LxPalette.PAL
	ci.draw_rect(Rect2(48.0, 0.0, 224.0, 11.0), pal["void"] as Color)
	for i: int in range(TAB_IDS.size()):
		var r: Rect2 = tab_rect(i)
		var is_act: bool = TAB_SCREENS[i] == active_screen
		LxPixelFont.draw_panel(ci, r, "plum" if is_act else "night", "gold" if is_act else "dusk", "void")
		var lbl: String = LxFolkData.tr_id(TAB_IDS[i]).substr(0, 7)
		var tc: Color = (pal["gold"] if is_act else pal["stone"]) as Color
		LxPixelFont.draw_centered(ci, lbl, r.get_center().x, r.position.y + 3.0, tc, 1)


static func handle_tab_bar_click(pos: Vector2, active_screen: int) -> bool:
	if not should_show_pause_tabs(active_screen):
		return false
	for i: int in range(TAB_SCREENS.size()):
		if tab_rect(i).has_point(pos):
			var target: int = TAB_SCREENS[i]
			if target != active_screen and Lx.ui != null and Lx.ui.has_method("switch_pause_tab"):
				Lx.ui.call("switch_pause_tab", target)
			return true
	return false


static func handle_tab_bar_key(event: InputEvent, active_screen: int) -> bool:
	if not should_show_pause_tabs(active_screen):
		return false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: Key = (event as InputEventKey).keycode
		var idx: int = -1
		if kc == KEY_F1: idx = 0
		elif kc == KEY_F2: idx = 1
		elif kc == KEY_F3: idx = 2
		elif kc == KEY_F4: idx = 3
		if idx >= 0:
			var target: int = TAB_SCREENS[idx]
			if target != active_screen and Lx.ui != null and Lx.ui.has_method("switch_pause_tab"):
				Lx.ui.call("switch_pause_tab", target)
			return true
	return false


# ---- Options: Next Light Diegetic Mote Toggle ----

static func is_next_light_cue_enabled() -> bool:
	if Lx.save != null and Lx.save.settings.has("next_light_cue"):
		return bool(Lx.save.settings["next_light_cue"])
	if Lx.state != null and Lx.state.story_flags.has("opt:next_light_cue"):
		return bool(Lx.state.story_flags["opt:next_light_cue"])
	return true


static func set_next_light_cue_enabled(on: bool) -> void:
	if Lx.save != null:
		Lx.save.settings["next_light_cue"] = on
	if Lx.state != null:
		Lx.state.story_flags["opt:next_light_cue"] = on


# ---- Pin ("Next Light") State & Outdoor Direction ----

static func get_pin() -> Dictionary:
	if Lx.state == null:
		return {}
	var v: Variant = Lx.state.story_flags.get("map_pin", null)
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func is_pinned(island_id: int, icon_id: String) -> bool:
	var p: Dictionary = get_pin()
	return not p.is_empty() and int(p.get("island", -1)) == island_id and str(p.get("id", "")) == icon_id


static func toggle_pin(node_spec: Dictionary) -> bool:
	if Lx.state == null or node_spec.is_empty():
		return false
	var isl: int = int(node_spec.get("island", Lx.state.island_id))
	var nid: String = str(node_spec.get("id", ""))
	if is_pinned(isl, nid):
		Lx.state.story_flags.erase("map_pin")
		return false
	var wp: Vector2 = node_spec.get("world_pos", Vector2(-1.0, -1.0)) as Vector2 if node_spec.get("world_pos") is Vector2 else Vector2(-1.0, -1.0)
	Lx.state.story_flags["map_pin"] = {
		"island": isl,
		"id": nid,
		"kind": str(node_spec.get("kind", "")),
		"region": str(node_spec.get("region", "overworld")),
		"icon": str(node_spec.get("icon", "lantern")),
		"label": str(node_spec.get("label", "")),
		"world_pos": [wp.x, wp.y],
	}
	return true


static func compute_pin_world_dir() -> Vector2:
	if Lx.state == null or Lx.world == null or Lx.player == null or not is_instance_valid(Lx.player):
		return Vector2.ZERO
	if not (Lx.player is Node2D):
		return Vector2.ZERO
	if bool(Lx.world.get("is_dungeon")):
		return Vector2.ZERO
	var pin: Dictionary = get_pin()
	if pin.is_empty():
		return Vector2.ZERO
	var cur_isl: int = Lx.state.island_id
	if int(pin.get("island", -1)) != cur_isl:
		return Vector2.ZERO
	var cur_reg: String = Lx.state.region_id
	var target_reg: String = str(pin.get("region", "overworld"))
	var ppos: Vector2 = (Lx.player as Node2D).global_position
	if target_reg == cur_reg or target_reg.is_empty():
		var wp_v: Variant = pin.get("world_pos", [-1.0, -1.0])
		if wp_v is Array and (wp_v as Array).size() >= 2:
			var wp := Vector2(float((wp_v as Array)[0]), float((wp_v as Array)[1]))
			if wp.x >= 0.0 and wp.y >= 0.0:
				var d: Vector2 = wp - ppos
				return d.normalized() if d.length() > 28.0 else Vector2.ZERO
		return Vector2.ZERO
	var exit_pt: Vector2 = _find_exit_toward_region(cur_isl, cur_reg, target_reg)
	if exit_pt.x >= 0.0:
		var d2: Vector2 = exit_pt - ppos
		return d2.normalized() if d2.length() > 16.0 else Vector2.ZERO
	return Vector2.ZERO


static func _find_exit_toward_region(isl_id: int, from_reg: String, target_reg: String) -> Vector2:
	var adj: Dictionary = _get_island_exit_graph(isl_id)
	if not adj.has(from_reg):
		return Vector2(-1.0, -1.0)
	var visited: Dictionary = {from_reg: true}
	var queue: Array[Dictionary] = []
	for ex: Dictionary in (adj[from_reg] as Array):
		var to_r: String = str(ex["to"])
		if to_r == target_reg:
			return ex["center"] as Vector2
		if not visited.has(to_r):
			visited[to_r] = true
			queue.append({"reg": to_r, "first_pt": ex["center"]})
	var head: int = 0
	while head < queue.size() and head < 96:
		var cur: Dictionary = queue[head]; head += 1
		var r: String = str(cur["reg"])
		if not adj.has(r):
			continue
		for ex: Dictionary in (adj[r] as Array):
			var nxt: String = str(ex["to"])
			if nxt == target_reg:
				return cur["first_pt"] as Vector2
			if not visited.has(nxt):
				visited[nxt] = true
				queue.append({"reg": nxt, "first_pt": cur["first_pt"]})
	return Vector2(-1.0, -1.0)


static func _get_island_exit_graph(isl_id: int) -> Dictionary:
	if _region_exits_cache.has(isl_id):
		return _region_exits_cache[isl_id] as Dictionary
	var adj: Dictionary = {}
	var dir_path: String = "res://luxel/islands/%d" % isl_id
	var da: DirAccess = DirAccess.open(dir_path)
	if da != null:
		for fn: String in da.get_files():
			if not fn.ends_with(".json"):
				continue
			var reg: String = fn.trim_suffix(".json")
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(fn)))
			if not (parsed is Dictionary):
				continue
			var list: Array[Dictionary] = []
			for ex_v: Variant in ((parsed as Dictionary).get("exits", []) as Array):
				if not (ex_v is Dictionary):
					continue
				var ex: Dictionary = ex_v as Dictionary
				if int(ex.get("to_island", isl_id)) != isl_id:
					continue
				var to_r: String = str(ex.get("to_region", ""))
				if to_r.is_empty():
					continue
				var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
				list.append({"to": to_r, "center": er.get_center()})
			adj[reg] = list
	_region_exits_cache[isl_id] = adj
	return adj


# ---- Island Visits & Moth/Quest Hints ----

static func record_island_visit(isl_id: int) -> void:
	if Lx.state == null or isl_id <= 0:
		return
	var k: String = "island_visits:%d" % isl_id
	Lx.state.story_flags[k] = int(Lx.state.story_flags.get(k, 0)) + 1


static func get_island_visits(isl_id: int) -> int:
	if Lx.state == null or isl_id <= 0:
		return 0
	var explicit: int = int(Lx.state.story_flags.get("island_visits:%d" % isl_id, 0))
	var pref: String = "%d:" % isl_id
	var reg_hits: int = 0
	for vr: String in Lx.state.visited_regions:
		if vr.begins_with(pref):
			reg_hits += 1
	return maxi(explicit, 2 if reg_hits >= 3 else (1 if reg_hits >= 1 else 0))


static func next_moth_hint_for_island(isl_id: int) -> Dictionary:
	if not _moth_regions_cache.has(isl_id):
		var found: Array[Dictionary] = []
		var dir_path: String = "res://luxel/islands/%d" % isl_id
		var da: DirAccess = DirAccess.open(dir_path)
		if da != null:
			var files: Array[String] = []
			for fn: String in da.get_files():
				if fn.ends_with(".json"):
					files.append(fn)
			files.sort()
			for fn: String in files:
				var reg: String = fn.trim_suffix(".json")
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(fn)))
				if not (parsed is Dictionary):
					continue
				var j: Dictionary = parsed as Dictionary
				for it_v: Variant in (j.get("interactables", []) as Array):
					if it_v is Dictionary and str((it_v as Dictionary).get("kind", "")) == "moth":
						var it: Dictionary = it_v as Dictionary
						var pr: Dictionary = it.get("props", {}) as Dictionary if it.get("props") is Dictionary else {}
						var mid: String = str(pr.get("id", it.get("id", "")))
						var rkind: String = "cave" if reg.begins_with("cave_") else ("dungeon" if bool(j.get("is_dungeon", false)) else "overworld")
						found.append({"id": mid, "region": reg, "kind": rkind})
		_moth_regions_cache[isl_id] = found
	var qsvc: LxQuests = LxQuests.current()
	for entry: Dictionary in (_moth_regions_cache[isl_id] as Array):
		var mid: String = str(entry["id"])
		if not mid.is_empty() and not qsvc.is_moth_caught(mid):
			return entry
	return {}


static func resolve_quest_place(q: Dictionary) -> Dictionary:
	var qid: String = str(q.get("id", ""))
	if _quest_regions_cache.has(qid):
		return _quest_regions_cache[qid] as Dictionary
	var isl: int = int(q.get("island", 1))
	var reg: String = str(q.get("region", ""))
	if reg.is_empty():
		var dir_path: String = "res://luxel/islands/%d" % isl
		var da: DirAccess = DirAccess.open(dir_path)
		if da != null:
			for fn: String in da.get_files():
				if not fn.ends_with(".json"):
					continue
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(fn)))
				if not (parsed is Dictionary):
					continue
				for it_v: Variant in ((parsed as Dictionary).get("interactables", []) as Array):
					if it_v is Dictionary:
						var pr: Dictionary = (it_v as Dictionary).get("props", {}) as Dictionary if (it_v as Dictionary).get("props") is Dictionary else {}
						if str(pr.get("quest", "")) == qid:
							reg = fn.trim_suffix(".json")
							break
				if not reg.is_empty():
					break
	if reg.is_empty():
		reg = "overworld"
	var label: String = region_display_label(isl, reg, 22)
	var out := {"island": isl, "region": reg, "label": label}
	_quest_regions_cache[qid] = out
	return out


static func region_display_label(isl: int, reg: String, max_len: int = 14) -> String:
	if isl == 0 and reg == "overworld":
		return LxFolkData.tr_id("MAP_HUB_SHORT")
	if Lx.packs != null:
		var rmeta: Dictionary = Lx.packs.region_meta(isl, reg)
		var nk: String = str(rmeta.get("name_key", ""))
		if not nk.is_empty() and LxFolkData.has_str(nk):
			return LxFolkData.tr_id(nk).substr(0, max_len)
		var did: String = Lx.packs.dungeon_of(isl, reg)
		if not did.is_empty():
			return LxMapDungeon._dungeon_display_name(Lx.packs.dungeon(did), did).substr(0, max_len)
	if reg == "overworld":
		var idata: Dictionary = Lx.get_island_data(isl)
		var inm: String = LxStrings.sanitize(str(idata.get("name", "")), max_len)
		if not inm.is_empty():
			return inm
	var clean: String = reg
	for pfx: String in ["ow_", "cave_", "sb_", "superboss_", "vault_"]:
		if clean.begins_with(pfx):
			clean = clean.substr(pfx.length())
	return LxStrings.sanitize(clean, max_len)


# ---- Save Slot Rich Summary & Previously Icon Strip ----

static func enrich_slot_summary(slot_num: int, base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if bool(out.get("empty", true)) or Lx.save == null:
		return out
	var d: Dictionary = Lx.save.load_slot_dict(slot_num)
	if d.is_empty():
		return out
	var sflags: Dictionary = d.get("story_flags", {}) as Dictionary if d.get("story_flags") is Dictionary else {}
	var bosses: Array = d.get("defeated_bosses", []) as Array if d.get("defeated_bosses") is Array else []
	var relit: Array = d.get("relit_islands", []) as Array if d.get("relit_islands") is Array else []
	var embers: int = int(d.get("ember_pieces", 0))
	var dng_done: int = 0
	var dng_tot: int = 0
	if Lx.packs != null:
		for dm: Dictionary in Lx.packs.all_dungeons():
			if bool(dm.get("debug_only", false)):
				continue
			dng_tot += 1
			var df: String = str(dm.get("done_flag", "dungeon_done:" + str(dm.get("id", ""))))
			var b_id: String = str(dm.get("boss", ""))
			if bool(sflags.get(df, false)) or (not b_id.is_empty() and bosses.has(b_id)):
				dng_done += 1
	var moths_n: int = 0
	for k: Variant in sflags.keys():
		var ks: String = str(k)
		if ks.begins_with("moth:") and not ks.begins_with("moth:tier_") and bool(sflags[k]):
			moths_n += 1
	var moves_d: Dictionary = d.get("unlocked_moves", {}) as Dictionary if d.get("unlocked_moves") is Dictionary else {}
	var moves_n: int = 0
	for mid: String in ["dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]:
		if bool(moves_d.get(mid, false)):
			moves_n += 1
	var harm_n: int = int(out.get("harmony_count", 0))
	var pct_f: float = (float(mini(relit.size(), 8)) / 8.0) * 35.0 \
		+ (float(dng_done) / float(maxi(1, dng_tot))) * 30.0 \
		+ (float(moves_n) / 7.0) * 12.0 \
		+ (float(mini(embers, 52)) / 52.0) * 10.0 \
		+ (float(mini(moths_n, 80)) / 80.0) * 8.0 \
		+ (float(harm_n) / 8.0) * 5.0
	out["completion_pct"] = 100 if pct_f >= 99.999 else clampi(mini(99, roundi(pct_f)), 0, 99)
	out["dungeons_done"] = dng_done
	out["dungeons_total"] = maxi(8, dng_tot)
	out["moths_caught"] = moths_n
	out["bosses_done"] = bosses.size()
	var spath: String = ProjectSettings.globalize_path(Lx.save.slot_path(slot_num))
	var mtime: int = int(FileAccess.get_modified_time(spath)) if FileAccess.file_exists(spath) else 0
	var stored_t: int = int(sflags.get("last_save_unix", 0))
	var last_t: int = stored_t if stored_t > 0 else mtime
	var now_t: int = int(Time.get_unix_time_from_system())
	out["after_day"] = last_t > 0 and (now_t - last_t) >= ONE_DAY_SECS
	return out


static func is_slot_after_day(slot_num: int) -> bool:
	if Lx.save == null:
		return false
	var spath: String = ProjectSettings.globalize_path(Lx.save.slot_path(slot_num))
	var mtime: int = int(FileAccess.get_modified_time(spath)) if FileAccess.file_exists(spath) else 0
	var d: Dictionary = Lx.save.load_slot_dict(slot_num)
	var sflags: Dictionary = d.get("story_flags", {}) as Dictionary if d.get("story_flags") is Dictionary else {}
	var stored_t: int = int(sflags.get("last_save_unix", 0))
	var last_t: int = stored_t if stored_t > 0 else mtime
	var now_t: int = int(Time.get_unix_time_from_system())
	return last_t > 0 and (now_t - last_t) >= ONE_DAY_SECS


static func build_previously_icons() -> Array[String]:
	var icons: Array[String] = []
	if Lx.state == null:
		return icons
	var isl: int = Lx.state.island_id
	icons.append("home" if isl == 0 else ("isl_%d" % clampi(isl, 1, 8)))
	if not Lx.state.relit_islands.is_empty():
		icons.append("crown")
	elif not Lx.state.defeated_bosses.is_empty():
		icons.append("skull")
	var pin: Dictionary = get_pin()
	if not pin.is_empty():
		icons.append("arrow_e")
		icons.append(str(pin.get("icon", "lantern")))
	else:
		var qsvc: LxQuests = LxQuests.current()
		for q: Dictionary in qsvc.all_quests():
			var qid: String = str(q.get("id", ""))
			if qsvc.is_quest_started(qid) and not qsvc.is_quest_done(qid):
				icons.append("book")
				icons.append(str(q.get("icon", "lantern")))
				break
	if LxQuests.current().get_moth_count() > 0:
		icons.append("moth")
	if icons.size() < 2:
		icons.append("lantern")
	return icons


static func count_total_dungeons() -> Vector2i:
	var done: int = 0
	var total: int = 0
	if Lx.packs != null:
		for d: Dictionary in Lx.packs.all_dungeons():
			if bool(d.get("debug_only", false)):
				continue
			total += 1
			if LxMapDungeon.is_dungeon_done(d):
				done += 1
	return Vector2i(done, maxi(8, total))


static func count_total_bosses() -> Vector2i:
	var done: int = 0
	var total: int = 0
	if Lx.packs != null:
		var ids: PackedStringArray = Lx.packs.all_boss_ids()
		total = ids.size()
		for bid: String in ids:
			if LxMapDungeon._is_boss_dead(bid):
				done += 1
	return Vector2i(done, maxi(16, total))
