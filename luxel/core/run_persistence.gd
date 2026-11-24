class_name LxRunPersistence
extends RefCounted
## Safe death-respawn waystone resolution, region autosave rules, and state flush helpers.
## Keeps LxMain compact while preventing cross-island respawn warps and quit-to-title state loss.

static var _entry_ws_cache: Dictionary = {}

static func should_autosave_region_load(
	allow_flow_save: bool, island_changed: bool, island_id: int, region_id: String, state: LxGameState
) -> bool:
	if not allow_flow_save or state == null: return false
	if region_id != "overworld" or island_changed: return true
	return not (island_id == 1 and not state.has_lantern())

static func save_now(active_slot: int, state: LxGameState, save_svc: LxSaveService, region_loader: Node) -> bool:
	if state == null or save_svc == null: return false
	if region_loader != null and is_instance_valid(region_loader) and region_loader.has_method("save_interactables_to_state"):
		region_loader.call("save_interactables_to_state")
	return save_svc.save_slot(active_slot, state)

static func flush_and_save(
	active_slot: int, state: LxGameState, save_svc: LxSaveService, region_loader: Node, player: Node, _reason: String = "exit"
) -> bool:
	if state == null or save_svc == null: return false
	if region_loader != null and is_instance_valid(region_loader) and region_loader.has_method("save_interactables_to_state"):
		region_loader.call("save_interactables_to_state")
	var safe_pos: Vector2 = _resolve_safe_player_pos(player, region_loader)
	if safe_pos.x >= 0.0: state.spawn_pos = safe_pos
	return save_svc.save_slot(active_slot, state)

static func _resolve_safe_player_pos(player: Node, region_loader: Node) -> Vector2:
	if player == null or not is_instance_valid(player) or not (player is Node2D) or bool(player.get("dead")):
		return Vector2(-1.0, -1.0)
	var candidates: Array[Vector2] = [(player as Node2D).global_position]
	var last_safe: Variant = player.get("_last_safe_pos")
	if last_safe is Vector2 and (last_safe as Vector2) != Vector2.ZERO:
		candidates.append(last_safe as Vector2)
	for cand: Vector2 in candidates:
		if _is_safe_spawn_point(cand, region_loader):
			return cand.round()
	return Vector2(-1.0, -1.0)

static func _is_safe_spawn_point(pt: Vector2, region_loader: Node) -> bool:
	if not pt.is_finite() or pt.x < 0.0 or pt.y < 0.0: return false
	if region_loader == null or not is_instance_valid(region_loader): return true
	if region_loader.has_method("get_bounds"):
		var b: Rect2 = region_loader.call("get_bounds") as Rect2
		if b.has_area() and not b.has_point(pt): return false
	if region_loader.has_method("is_lethal_void_at") and bool(region_loader.call("is_lethal_void_at", pt)):
		return false
	if region_loader.has_method("tile_at") and region_loader.has_method("is_solid_tile"):
		if bool(region_loader.call("is_solid_tile", str(region_loader.call("tile_at", pt)), false, false)):
			return false
	return true

static func resolve_overworld_respawn(state: LxGameState) -> Dictionary:
	if state == null:
		return {"island": 1, "region": "overworld", "pos": Vector2(-1.0, -1.0)}
	var cur_isl: int = maxi(1, state.island_id)
	if state.last_waystone_island == cur_isl and not state.last_waystone_id.is_empty():
		var direct: Dictionary = LxMapFormat.find_waystone(cur_isl, state.last_waystone_id)
		if not direct.is_empty(): return direct
	for i: int in range(state.lit_waystones.size() - 1, -1, -1):
		var ws_id: String = state.lit_waystones[i]
		var loc: Dictionary = LxMapFormat.find_waystone(cur_isl, ws_id)
		if not loc.is_empty():
			state.last_waystone_island = cur_isl
			state.last_waystone_id = ws_id
			return loc
	var entry_loc: Dictionary = find_island_entry_waystone(cur_isl)
	if not entry_loc.is_empty():
		var eid: String = str(entry_loc.get("waystone_id", ""))
		if bool(entry_loc.get("prelit", false)) and not eid.is_empty():
			if not state.lit_waystones.has(eid): state.lit_waystones.append(eid)
			state.last_waystone_island = cur_isl
			state.last_waystone_id = eid
		return entry_loc
	var fallback: Dictionary = LxMapFormat.find_waystone(state.last_waystone_island, state.last_waystone_id)
	return fallback if not fallback.is_empty() else {"island": cur_isl, "region": "overworld", "pos": Vector2(-1.0, -1.0)}

static func find_island_entry_waystone(island_id: int) -> Dictionary:
	if _entry_ws_cache.has(island_id):
		return (_entry_ws_cache[island_id] as Dictionary).duplicate()
	var path: String = "res://luxel/islands/%d/overworld.json" % island_id
	var best: Dictionary = {}
	var best_rank: int = -1
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for it_v: Variant in ((parsed as Dictionary).get("interactables", []) as Array):
				if not (it_v is Dictionary) or str((it_v as Dictionary).get("kind", "")) != "waystone":
					continue
				var it: Dictionary = it_v as Dictionary
				var wid: String = str(it.get("id", ""))
				var wpos: Vector2 = LxMapFormat.to_vec2(it.get("pos", []), Vector2(-1.0, -1.0))
				if wid.is_empty() or wpos.x < 0.0: continue
				var pr: Dictionary = it.get("props", {}) as Dictionary if it.get("props") is Dictionary else {}
				var prelit: bool = bool(pr.get("lit", false))
				var is_entry: bool = wid.contains("entry") or wid.contains("landing") or wid.contains("hub") or wid.contains("plaza")
				var rank: int = (4 if prelit else 0) + (2 if is_entry else 1)
				if rank > best_rank:
					best_rank = rank
					best = {"island": island_id, "region": "overworld", "pos": wpos + Vector2(0.0, 14.0), "waystone_id": wid, "prelit": prelit}
	_entry_ws_cache[island_id] = best
	return best.duplicate()
