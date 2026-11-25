class_name LxRegionRuntime
extends RefCounted
## Runtime helpers for LxRegionLoader: multi-dungeon flags, dirty-only interactable saves,
## destructible map-tile promotion, lazy LxFields/LxRoomScript wiring, and signal forwarding.

const KEY_DUNGEON_KINDS: Array[String] = [
	"door", "locked_door", "boss_door", "boss_key", "wick_key", "keepers_flame", "key", "chest",
]
const BOOL_PROGRESS_KEYS: Array[String] = [
	"lit", "opened", "collected", "claimed", "activated", "burned", "broken", "shattered",
	"powered", "is_current_anchor",
]
const FIELDS_PATH: String = "res://luxel/world/fields.gd"
const ROOM_SCRIPT_PATH: String = "res://luxel/world/room_script.gd"

static var _fields_script: Variant = null
static var _fields_checked: bool = false
static var _room_script_res: Variant = null
static var _room_script_checked: bool = false
static var _ground_missing: Dictionary = {}


static func flag_truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return bool(v)
	if v is int or v is float:
		return not is_zero_approx(float(v))
	if v is String:
		var s: String = (v as String).strip_edges().to_lower()
		return not s.is_empty() and s != "false" and s != "0"
	if v is Array:
		return not (v as Array).is_empty()
	if v is Dictionary:
		return not (v as Dictionary).is_empty()
	return true


static func check_flag_static(flag: String) -> bool:
	var trimmed: String = flag.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed.find("||") >= 0:
		for part: String in trimmed.split("||", false):
			if check_flag_static(part):
				return true
		return false
	if trimmed.find("&&") >= 0:
		for part: String in trimmed.split("&&", false):
			if not check_flag_static(part):
				return false
		return true
	if trimmed.begins_with("!"):
		return not check_flag_static(trimmed.substr(1))
	if Lx.state == null:
		return false
	if flag_truthy(Lx.state.story_flags.get(trimmed, false)):
		return true
	if Lx.state.lit_beacons.has(trimmed) or Lx.state.claimed_shrines.has(trimmed) \
			or Lx.state.broken_seals.has(trimmed) or Lx.state.defeated_bosses.has(trimmed) \
			or Lx.state.opened_doors.has(trimmed) or Lx.state.lit_waystones.has(trimmed):
		return true
	if trimmed.begins_with("dungeon_done:"):
		var did: String = trimmed.substr(13).strip_edges()
		if Lx.packs != null and not did.is_empty():
			var dmeta: Dictionary = Lx.packs.dungeon(did)
			var df: String = str(dmeta.get("done_flag", ""))
			if not df.is_empty() and df != trimmed and flag_truthy(Lx.state.story_flags.get(df, false)):
				return true
			var b: String = str(dmeta.get("boss", ""))
			if not b.is_empty() and Lx.state.defeated_bosses.has(b):
				return true
		return false
	if trimmed.begins_with("island_") and trimmed.ends_with("_relit"):
		return Lx.state.relit_islands.has(int(trimmed.substr(7, trimmed.length() - 13)))
	if trimmed.begins_with("great_lamp_"):
		return Lx.state.relit_islands.has(int(trimmed.substr(11)))
	return false


static func prepare_interactable_spec(spec: Dictionary, island_id: int, region_id: String) -> Dictionary:
	var kind: String = str(spec.get("kind", "")).strip_edges().to_lower()
	var need_dng: bool = KEY_DUNGEON_KINDS.has(kind)
	var need_lamp: bool = kind in ["great_lamp", "great_belfry_brazier"]
	if not need_dng and not need_lamp:
		return spec
	var raw_pr: Dictionary = spec["props"] as Dictionary if spec.get("props") is Dictionary else {}
	var did: String = ""
	if need_dng and str(raw_pr.get("dungeon_id", "")).strip_edges().is_empty():
		did = Lx.packs.dungeon_of(island_id, region_id) if Lx.packs != null else ""
	var rflags: Variant = raw_pr.get("requires_flags", spec.get("requires_flags", [])) if need_lamp else null
	var has_rflags: bool = rflags is Array and not (rflags as Array).is_empty()
	if did.is_empty() and not has_rflags:
		return spec
	var out: Dictionary = spec.duplicate(false)
	var pr: Dictionary = raw_pr.duplicate(false)
	if not did.is_empty():
		pr["dungeon_id"] = did
	if has_rflags:
		var parts := PackedStringArray()
		var existing_rf: String = str(pr.get("requires_flag", "")).strip_edges()
		if not existing_rf.is_empty():
			parts.append(existing_rf)
		for fl: Variant in (rflags as Array):
			var fs: String = str(fl).strip_edges()
			if not fs.is_empty() and not parts.has(fs):
				parts.append(fs)
		if not parts.is_empty():
			pr["requires_flag"] = " && ".join(parts)
	out["props"] = pr
	return out


static func capture_authored_default(item: LxInteractable, spec: Dictionary) -> Dictionary:
	var base: Dictionary = item.save_state().duplicate(true)
	var pr: Dictionary = spec.get("props", {}) as Dictionary if spec.get("props") is Dictionary else {}
	var reads_global_state: bool = item.kind in ["door", "waystone", "beacon", "obsidian_seal", "shrine", "moth", "lantern_pickup"]
	for k: String in BOOL_PROGRESS_KEYS:
		if not base.has(k):
			continue
		if pr.has(k):
			base[k] = bool(pr[k])
		elif k == "opened" and pr.has("starts_open"):
			base[k] = bool(pr["starts_open"])
		elif k in ["powered", "activated", "lit"] and (pr.has("on") or pr.has("starts_on") or pr.has("starts_lit")):
			base[k] = bool(pr.get("on", pr.get("starts_on", pr.get("starts_lit", false))))
		elif reads_global_state:
			base[k] = false
	if base.has("angle_idx") and pr.has("angle_idx"):
		base["angle_idx"] = int(pr["angle_idx"])
	if base.has("index") and pr.has("index"):
		base["index"] = int(pr["index"])
	return base


static func save_dirty_interactables(interactables: Array[LxInteractable], defaults: Dictionary, layers: LxRegionLayers = null) -> void:
	if Lx.state == null:
		return
	for it: LxInteractable in interactables:
		if it == null or not is_instance_valid(it) or it.id.is_empty():
			continue
		var key: String = it.get_state_key()
		var cur: Dictionary = it.save_state()
		if layers != null and layers.is_interactable_disabled(it.id) and cur.has("active"):
			cur["active"] = layers.get_saved_inter_active(it.id, true)
		var def_d: Variant = defaults.get(key, null)
		if def_d is Dictionary and _dicts_equal(cur, def_d as Dictionary):
			if Lx.state.interactable_states.has(key):
				Lx.state.interactable_states.erase(key)
		else:
			Lx.state.interactable_states[key] = cur


static func _dicts_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a.keys():
		if not b.has(k):
			return false
		var va: Variant = a[k]
		var vb: Variant = b[k]
		if va is Dictionary and vb is Dictionary:
			if not _dicts_equal(va as Dictionary, vb as Dictionary):
				return false
		elif typeof(va) != typeof(vb) or va != vb:
			return false
	return true


static func promote_destructible_map_tiles(region: LxRegionLoader) -> void:
	if region.width <= 0 or region.height <= 0:
		return
	var ts: float = float(region.tile_size)
	var visited: Dictionary = {}
	for ty: int in range(region.height):
		var row: PackedStringArray = region.grid[ty]
		for tx: int in range(region.width):
			var ttype: String = row[tx]
			if ttype != "bramble" and ttype != "cracked":
				continue
			var key := Vector2i(tx, ty)
			if visited.has(key):
				continue
			var target_kind: String = "bramble" if ttype == "bramble" else "cracked_wall"
			var tile_center := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
			if _has_covering(region.get_interactables(), target_kind, tile_center):
				region.grid[ty][tx] = "ground"
				visited[key] = true
				continue
			var rx1: int = tx
			while rx1 + 1 < region.width and region.grid[ty][rx1 + 1] == ttype and not visited.has(Vector2i(rx1 + 1, ty)):
				if _has_covering(region.get_interactables(), target_kind, Vector2((float(rx1 + 1) + 0.5) * ts, (float(ty) + 0.5) * ts)):
					break
				rx1 += 1
			var ry1: int = ty
			if rx1 == tx:
				while ry1 + 1 < region.height and region.grid[ry1 + 1][tx] == ttype and not visited.has(Vector2i(tx, ry1 + 1)):
					if _has_covering(region.get_interactables(), target_kind, Vector2((float(tx) + 0.5) * ts, (float(ry1 + 1) + 0.5) * ts)):
						break
					ry1 += 1
			for cy: int in range(ty, ry1 + 1):
				for cx: int in range(tx, rx1 + 1):
					visited[Vector2i(cx, cy)] = true
					region.grid[cy][cx] = "ground"
			var cols_n: int = rx1 - tx + 1
			var rows_n: int = ry1 - ty + 1
			var size_px := Vector2(float(cols_n) * ts, float(rows_n) * ts)
			var center_px := Vector2((float(tx) + float(cols_n) * 0.5) * ts, (float(ty) + float(rows_n) * 0.5) * ts)
			region.spawn_interactable({
				"id": "map_%s_%d_%d" % [ttype, tx, ty],
				"kind": target_kind,
				"pos": [center_px.x, center_px.y],
				"props": {"size": [size_px.x, size_px.y], "from_map_tile": true},
			})


static func _has_covering(items: Array[LxInteractable], target_kind: String, pt: Vector2) -> bool:
	for it: LxInteractable in items:
		if it != null and it.kind == target_kind and it.get_solid_rect().grow(2.0).has_point(pt):
			return true
	return false


static func clear_fields() -> void:
	var sc: Variant = _get_fields_script()
	if sc != null and sc.has_method("clear"):
		sc.call("clear")


static func add_field(f: Object) -> void:
	if f == null:
		return
	var sc: Variant = _get_fields_script()
	if sc != null and sc.has_method("add"):
		sc.call("add", f)


static func _get_fields_script() -> Variant:
	if not _fields_checked:
		_fields_checked = true
		if ResourceLoader.exists(FIELDS_PATH):
			_fields_script = ResourceLoader.load(FIELDS_PATH)
	return _fields_script


static func create_room_script(region: LxRegionLoader, events: Array[Dictionary]) -> Object:
	if events.is_empty():
		return null
	if not _room_script_checked:
		_room_script_checked = true
		if ResourceLoader.exists(ROOM_SCRIPT_PATH):
			_room_script_res = ResourceLoader.load(ROOM_SCRIPT_PATH)
	if _room_script_res is GDScript:
		var inst: Variant = (_room_script_res as GDScript).new()
		if inst is Object:
			if inst is Node:
				(inst as Node).name = "RoomScript"
				region.add_child(inst as Node)
			if (inst as Object).has_method("setup"):
				(inst as Object).call("setup", region, events, region.current_island_id, region.current_region_id)
			return inst as Object
	return null


static func snapshot_signals(items: Array[LxInteractable]) -> Dictionary:
	var out: Dictionary = {}
	for it: LxInteractable in items:
		if it != null and is_instance_valid(it) and not it.id.is_empty():
			out[it.id] = _interactable_signal_state(it)
	return out


static func poll_signals(region: LxRegionLoader, prev: Dictionary) -> void:
	for it: LxInteractable in region.get_interactables():
		if it == null or not is_instance_valid(it) or it.id.is_empty():
			continue
		var now_on: bool = _interactable_signal_state(it)
		var had: bool = prev.has(it.id)
		var was_on: bool = bool(prev.get(it.id, false))
		if not had:
			prev[it.id] = now_on
			continue
		if now_on != was_on:
			prev[it.id] = now_on
			region.notify("signal:" + it.id, {"id": it.id, "kind": it.kind, "powered": now_on})
			if now_on and it.kind == "room_anchor":
				region.set_room_anchor(it.pos)


static func _interactable_signal_state(it: LxInteractable) -> bool:
	for prop: String in ["powered", "lit", "opened", "activated", "shattered", "broken", "burned", "claimed", "collected", "is_current_anchor"]:
		var v: Variant = it.get(prop)
		if v is bool and bool(v):
			return true
	return false


static func setup_ground_visual(region: LxRegionLoader) -> Sprite2D:
	var png_path: String = "res://luxel/art/islands/%d/%s_ground.png" % [region.current_island_id, region.current_region_id]
	if _ground_missing.has(png_path):
		return null
	var tex: Texture2D = null
	if ResourceLoader.exists(png_path):
		var loaded: Resource = ResourceLoader.load(png_path)
		if loaded is Texture2D: tex = loaded as Texture2D
	elif FileAccess.file_exists(png_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(png_path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				tex = ImageTexture.create_from_image(img)
	else:
		_ground_missing[png_path] = true
	if tex == null: return null
	var sp := Sprite2D.new()
	sp.name = "PaintedGround"; sp.texture = tex; sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sp.z_index = -10
	region.add_child(sp)
	return sp


static func spawn_enemy_for_region(region: LxRegionLoader, spec: Dictionary, director: LxAttackDirector, root: Node2D, list: Array[LxEnemyBrain]) -> LxEnemyBrain:
	var kind: String = str(spec.get("kind", "")).strip_edges()
	if kind.is_empty(): return null
	var s: Dictionary = spec.duplicate(true)
	s["island_id"] = region.current_island_id
	var ep: Dictionary = s.get("props", {}) as Dictionary if s.get("props") is Dictionary else {}
	for k: String in ["max_hp", "shield_hp", "facing", "notice_radius", "tutorial_wait_lantern"]:
		if not s.has(k) and ep.has(k): s[k] = ep[k]
	if s.has("max_hp") and float(s["max_hp"]) <= 0.0: s.erase("max_hp")
	if s.has("notice_radius") and float(s["notice_radius"]) <= 0.0: s.erase("notice_radius")
	if s.has("shield_hp"): s["shield_hp"] = maxf(0.0, float(s["shield_hp"]))
	var brain: LxEnemyBrain = LxEnemyFactory.create(kind, s, director, region)
	if brain == null: return null
	if brain.is_boss and Lx.state != null:
		var bid: String = brain.boss_id if not brain.boss_id.is_empty() else brain.kind
		var alt: String = "hollow_wick" if brain.kind == "hollow_wick_boss" else ""
		var canon: String = str(Lx.packs.boss_meta(bid).get("id", bid)) if Lx.packs != null else bid
		if Lx.state.defeated_bosses.has(bid) or Lx.state.defeated_bosses.has(canon) \
				or Lx.state.defeated_bosses.has(brain.kind) or (not alt.is_empty() and Lx.state.defeated_bosses.has(alt)):
			brain.free(); return null
	root.add_child(brain)
	if not brain.is_flying() and not brain.is_boss and region.tile_at(brain.pos) in ["water", "tide", "pit", "void", "wall"]:
		var safe_p: Vector2 = _nearest_walkable_tile(region, brain.pos)
		if safe_p != brain.pos:
			brain.pos = safe_p
			brain.home = safe_p
	brain.position = brain.pos.round()
	LxRegionArena.tune_boss_ranges(brain, region)
	list.append(brain)
	if region.has_method("_on_enemy_tree_exiting"):
		brain.tree_exiting.connect(Callable(region, "_on_enemy_tree_exiting").bind(brain), Object.CONNECT_ONE_SHOT)
	return brain


static func _nearest_walkable_tile(region: LxRegionLoader, origin: Vector2) -> Vector2:
	for r: float in [16.0, 24.0, 32.0, 48.0]:
		for k: int in range(8):
			var cand: Vector2 = (origin + Vector2.from_angle(TAU * float(k) / 8.0) * r).round()
			if region.bounds.grow(-16.0).has_point(cand) and region.tile_at(cand) in ["ground", "path", "bridge"]:
				return cand
	return origin


static func resolve_room_for_pos(region: LxRegionLoader, p: Vector2, room_w: float, room_h: float) -> Dictionary:
	for rm: Dictionary in region.rooms:
		var r: Rect2 = LxMapFormat.to_rect2(rm.get("rect", []))
		if r.has_point(p): return {"id": str(rm.get("id", "room")), "rect": r}
	var rw: float = room_w; var rh: float = room_h
	if region.region_data.has("room_size"):
		var rs: Vector2 = LxMapFormat.to_vec2(region.region_data.get("room_size", [room_w, room_h]))
		rw = maxf(room_w, rs.x); rh = maxf(room_h, rs.y)
	elif bool(region.region_data.get("is_2x2_room", false)):
		return {"id": region.current_region_id, "rect": region.bounds}
	if region.bounds.size.x <= rw + 16.0 and region.bounds.size.y <= rh + 16.0:
		return {"id": region.current_region_id, "rect": region.bounds}
	var rx: int = maxi(0, int(floor(p.x / rw))); var ry: int = maxi(0, int(floor(p.y / rh)))
	return {"id": "r_%d_%d" % [rx, ry], "rect": Rect2(float(rx) * rw, float(ry) * rh, minf(rw, region.bounds.size.x - float(rx) * rw), minf(rh, region.bounds.size.y - float(ry) * rh))}


static func is_tile_supported(region: LxRegionLoader, tile_type: String, tile_center: Vector2, lens_circles: Array[Vector3]) -> bool:
	if tile_type == "phantom":
		for c: Vector3 in lens_circles:
			if tile_center.distance_squared_to(Vector2(c.x, c.y)) <= c.z * c.z: return true
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick; var ml: LxMoveLens = w.move_lens
			if ml != null and ml.unlocked:
				if ml.is_pulse_active() and tile_center.distance_squared_to(w.global_position) <= ml.pulse_radius * ml.pulse_radius: return true
				if ml.is_anchor_active() and w.lantern != null and tile_center.distance_squared_to(w.lantern.pos) <= ml.hung_radius * ml.hung_radius: return true
	if tile_type in ["pit", "void", "water", "tide", "phantom"]:
		for it: LxInteractable in region.get_interactables():
			if it != null and it.is_platform_solid() and it.get_platform_rect().has_point(tile_center): return true
	return false


static func exit_requirements_met(ex: Dictionary) -> bool:
	var req_moves: Variant = ex.get("requires_moves", [])
	if req_moves is Array and Lx.state != null:
		for m: Variant in (req_moves as Array):
			if not Lx.state.has_move(str(m)): return false
	var req_flags: Variant = ex.get("requires_flags", [])
	if req_flags is Array:
		for fl: Variant in (req_flags as Array):
			if not check_flag_static(str(fl)): return false
	return true


static func is_zone_lit(region: LxRegionLoader, zone_id: String) -> bool:
	if Lx.state != null and Lx.state.relit_islands.has(region.current_island_id): return true
	for z: Dictionary in region.zones:
		if str(z.get("id", "")) == zone_id and not bool(z.get("dark", true)): return true
	for it: LxInteractable in region.get_interactables():
		if it != null and it.kind == "beacon" and (it.get("lit") == true):
			if str(it.props.get("zone", "")) == zone_id: return true
			var relit: Variant = it.props.get("relit_zones", [])
			if relit is Array and (relit as Array).has(zone_id): return true
	return false


static func get_light_pools(items: Array[LxInteractable], props: Array[LxSceneryProp]) -> Array[Vector4]:
	var pools: Array[Vector4] = []
	for it: LxInteractable in items:
		if it != null and it.active:
			var p: Vector4 = it.get_light_pool()
			if p.z > 1.0 and p.w > 0.001: pools.append(p)
	for sp: LxSceneryProp in props:
		if sp != null and sp.light_pool.z > 1.0: pools.append(sp.light_pool)
	return pools


static func check_triggers(region: LxRegionLoader, player_pos: Vector2, fired: Dictionary) -> void:
	for trig: Dictionary in region.triggers:
		var tid: String = str(trig.get("id", ""))
		if tid.is_empty(): continue
		var unless_flag: String = str(trig.get("unless_flag", ""))
		if not unless_flag.is_empty() and check_flag_static(unless_flag): continue
		var once: bool = bool(trig.get("once", true))
		var flag_key: String = "trig_%d_%s_%s" % [region.current_island_id, region.current_region_id, tid]
		if once and (fired.has(tid) or (Lx.state != null and flag_truthy(Lx.state.story_flags.get(flag_key, false)))): continue
		if not LxMapFormat.to_rect2(trig.get("rect", [])).has_point(player_pos): continue
		fired[tid] = true
		if once and Lx.state != null: Lx.state.story_flags[flag_key] = true
		var sid: String = str(trig.get("string_id", ""))
		if not sid.is_empty() and Lx.events != null:
			Lx.events.narration_requested.emit(sid, str(trig.get("style", "narration")), float(trig.get("duration", 3.5)))


static func wick_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player is Node2D: return (Lx.player as Node2D).global_position
		if Lx.player.get("pos") is Vector2: return Lx.player.get("pos") as Vector2
	return Vector2(-99999.0, -99999.0)


static func lantern_state() -> int:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan) and (lan as Object).get("state") != null:
			return int((lan as Object).get("state"))
	return 0


static func lantern_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan):
			if (lan as Object).get("pos") is Vector2: return (lan as Object).get("pos") as Vector2
			if lan is Node2D: return (lan as Node2D).global_position
	return wick_pos()


static func apply_script_reward(
	raw: Variant, island_id: int, region_id: String, wpos: Vector2,
	spawn_cb: Callable, ev_id: String = ""
) -> void:
	if not (raw is Dictionary) or Lx.state == null:
		return
	var d: Dictionary = raw as Dictionary
	var rk: String = str(d.get("kind", "shards")).strip_edges().to_lower()
	match rk:
		"shards":
			Lx.state.add_shards(maxi(1, int(d.get("amount", 20))))
			if Lx.events != null: Lx.events.sfx_requested.emit("shard_pickup", wpos, false)
		"ember_piece":
			Lx.state.add_ember_piece()
		"half_lantern":
			if Lx.state.has_method("add_half_lantern"): Lx.state.call("add_half_lantern")
			else: Lx.state.add_ember_piece()
		"key", "wick_key", "keepers_flame":
			var default_dng: String = Lx.packs.dungeon_of(island_id, region_id) if Lx.packs != null else ""
			if default_dng.is_empty(): default_dng = "island_%d" % island_id
			var did: String = str(d.get("dungeon_id", default_dng)).strip_edges()
			if did.is_empty(): did = default_dng
			var kkind: String = str(d.get("key_kind", "keepers_flame" if rk == "keepers_flame" else "wick_key"))
			Lx.state.add_key(did, kkind, maxi(1, int(d.get("amount", 1))))
			if Lx.events != null: Lx.events.sfx_requested.emit("key_pickup", wpos, false)
		"pane":
			var pid: String = str(d.get("id", d.get("pane", d.get("value", "")))).strip_edges()
			if not pid.is_empty():
				var granted: bool = false
				if Lx.panes != null and Lx.panes.has_method("grant_pane"):
					granted = bool(Lx.panes.call("grant_pane", pid))
				else:
					granted = LxPanes.current().grant_pane(pid)
				if granted and Lx.events != null:
					Lx.events.sfx_requested.emit("shrine_claimed", wpos, false)
		"moth":
			var mid: String = str(d.get("id", d.get("moth", d.get("value", "")))).strip_edges()
			if not mid.is_empty():
				var q: Object = LxQuests.current()
				if q != null and q.has_method("catch_moth"):
					q.call("catch_moth", mid)
				else:
					Lx.state.story_flags["moth:" + mid] = true
				if Lx.events != null:
					Lx.events.sfx_requested.emit("moth_catch", wpos, false)
		"lead":
			var amt_l: int = maxi(1, int(d.get("amount", d.get("value", 1))))
			var added: bool = false
			if Lx.panes != null and Lx.panes.has_method("add_lead"):
				added = bool(Lx.panes.call("add_lead", amt_l))
			else:
				added = LxPanes.current().add_lead(amt_l)
			if added and Lx.events != null:
				Lx.events.sfx_requested.emit("shrine_claimed", wpos, false)
		"flag":
			var fid: String = str(d.get("id", d.get("flag", d.get("value", "")))).strip_edges()
			if not fid.is_empty(): Lx.state.story_flags[fid] = true
		"heal":
			if d.has("amount"):
				var amt_h: float = float(d.get("amount", 0.0))
				if amt_h > 0.0:
					Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + amt_h)
					if Lx.events != null: Lx.events.player_healed.emit(Lx.state.hearts)
				else:
					Lx.state.heal_full()
			else:
				Lx.state.heal_full()
		"chest":
			var cspec: Dictionary = d.duplicate(true); cspec["kind"] = "chest"
			if not cspec.has("id"):
				cspec["id"] = "reward_chest_%s" % (ev_id if not ev_id.is_empty() else region_id)
			if not cspec.has("pos"): cspec["pos"] = [wpos.x, wpos.y - 20.0]
			if spawn_cb.is_valid(): spawn_cb.call(cspec)


static func read_world_var(vname: String, island_id: int, region_id: String, local_vars: Dictionary) -> Variant:
	if Lx.vars != null and is_instance_valid(Lx.vars) and Lx.vars.has_method("get_var"):
		for sc: String in ["room:%d:%s" % [island_id, region_id], "island:%d" % island_id, "game"]:
			var v: Variant = Lx.vars.call("get_var", sc, vname, "__MISSING__")
			if str(v) != "__MISSING__": return v
	if local_vars.has(vname): return local_vars[vname]
	if Lx.state != null:
		for sc2: String in ["room:%d:%s" % [island_id, region_id], "island:%d" % island_id, "game"]:
			var k: String = "wvar:%s:%s" % [sc2, vname]
			if Lx.state.story_flags.has(k): return Lx.state.story_flags[k]
	return ""


static func eval_cond_fallback(
	expr: String, island_id: int, region_id: String, local_vars: Dictionary, is_flag_cb: Callable
) -> bool:
	for or_part: String in expr.split(" || "):
		var ok: bool = true
		for atom_raw: String in or_part.split(" && "):
			var atom: String = atom_raw.strip_edges()
			if not atom.is_empty() and not _eval_cond_atom(atom, island_id, region_id, local_vars, is_flag_cb):
				ok = false; break
		if ok: return true
	return false


static func _eval_cond_atom(
	atom: String, island_id: int, region_id: String, local_vars: Dictionary, is_flag_cb: Callable
) -> bool:
	if atom.begins_with("!flag:"): return not bool(is_flag_cb.call(atom.substr(6).strip_edges()))
	if atom.begins_with("flag:"): return bool(is_flag_cb.call(atom.substr(5).strip_edges()))
	for op: String in ["==", "!=", ">=", "<=", ">", "<"]:
		var p: int = atom.find(op)
		if p > 0:
			var cur: Variant = read_world_var(atom.substr(0, p).strip_edges(), island_id, region_id, local_vars)
			var rhs: String = atom.substr(p + op.length()).strip_edges()
			match op:
				"==": return str(cur) == rhs
				"!=": return str(cur) != rhs
				">=": return float(cur) >= float(rhs)
				"<=": return float(cur) <= float(rhs)
				">": return float(cur) > float(rhs)
				"<": return float(cur) < float(rhs)
	return bool(is_flag_cb.call(atom))
