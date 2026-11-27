class_name LxFireflyGuide
extends RefCounted
## Wayfinding & room-objective intelligence for Pip the Firefly Companion.
## Priority order:
##   1. Unsolved puzzle/room objectives in the current room (shrines, perches, braziers,
##      beacons, great lamps, switches, plates, sensors, light plants, chests, blooms, relays).
##   2. Next progression doorway/exit toward the island's next unlit dungeon/beacon/region.
##   3. Nearby hidden secrets (uncaught moths, cracked walls, unrevealed phantom paths).

const OVERWORLD_OBJ_MAX: float = 340.0
const SECRET_BASE_RADIUS: float = 148.0


static func find_guide_target(wick: LxWick, world_ctx: Node, sense_mult: float = 1.0, on_demand: bool = false) -> Dictionary:
	if wick == null or not is_instance_valid(wick):
		return {}
	var wp: Vector2 = wick.global_position
	var room_rect: Rect2 = _current_room_rect(world_ctx)
	var is_dng: bool = _is_dungeon(world_ctx)
	var obj_cap: float = 9999.0 if is_dng else ((OVERWORLD_OBJ_MAX * 1.45 if on_demand else OVERWORLD_OBJ_MAX) * sense_mult)

	# 1) Unsolved puzzle & companion objectives in the current room
	var best_obj: Dictionary = _find_room_objective(wick, world_ctx, wp, room_rect, is_dng, obj_cap)
	if not best_obj.is_empty():
		return best_obj

	# 2) Next progression doorway / exit
	var best_exit: Dictionary = _find_progression_exit(world_ctx, wp, room_rect, is_dng)
	if not best_exit.is_empty():
		return best_exit

	# 3) Nearby hidden secrets / moths
	var sec_cap: float = (SECRET_BASE_RADIUS * (1.55 if on_demand else 1.0)) * sense_mult
	return _find_secret_target(wick, world_ctx, wp, room_rect, is_dng, sec_cap)


static func find_passive_sense(wick: LxWick, world_ctx: Node, sense_mult: float = 1.0) -> Dictionary:
	if wick == null or not is_instance_valid(wick):
		return {}
	var wp: Vector2 = wick.global_position
	var room_rect: Rect2 = _current_room_rect(world_ctx)
	var is_dng: bool = _is_dungeon(world_ctx)
	var max_d: float = 118.0 * sense_mult
	var best_p: Vector2 = Vector2.INF
	var best_d: float = max_d
	var is_secret: bool = false
	if LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance):
		var wt: Vector2 = LxFireflyWorldContent.active_instance.find_nearest_sense_target(wp, max_d)
		if wt.is_finite() and _in_room(wt, room_rect, is_dng):
			best_p = wt
			best_d = wp.distance_to(wt)
	var cap: float = minf(best_d, 108.0 * sense_mult)
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not _is_interactable_valid_target(it_v, world_ctx):
			continue
		var item: Object = it_v as Object
		var ip: Vector2 = wick.get_entity_pos(item)
		if not _in_room(ip, room_rect, is_dng):
			continue
		var k: String = str(item.get("kind")).to_lower()
		var ok: bool = false
		var sec_flag: bool = false
		if k == "chest" and not _bool_prop(item, "opened"):
			ok = true; sec_flag = true
		elif k == "moth" and not _bool_prop(item, "caught"):
			ok = true; sec_flag = true
		elif k == "cracked_wall" and not _bool_prop(item, "broken"):
			ok = true; sec_flag = true
		elif k == "beacon" and not _bool_prop(item, "lit") and _bool_prop(item, "ignitable"):
			ok = true
		elif k == "great_lamp" and not _bool_prop(item, "lit") and _is_great_lamp_ready(item):
			ok = true
		if ok:
			var d: float = wp.distance_to(ip)
			if d < cap:
				cap = d; best_p = ip; is_secret = sec_flag
	if best_p.is_finite():
		return {"pos": best_p, "is_secret": is_secret}
	return {}


static func has_nearby_enemies(wick: LxWick, world_ctx: Node, radius: float = 112.0) -> bool:
	if wick == null or not is_instance_valid(wick):
		return false
	var wp: Vector2 = wick.global_position
	var r2: float = radius * radius
	for e_v: Variant in wick.world_get_enemies(world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object):
			continue
		var enemy: Object = e_v as Object
		if not wick.is_entity_alive(enemy):
			continue
		if enemy is CanvasItem and not (enemy as CanvasItem).visible:
			continue
		if wick.get_entity_pos(enemy).distance_squared_to(wp) <= r2:
			return true
	return false


static func _find_room_objective(
	wick: LxWick, world_ctx: Node, wp: Vector2, room_rect: Rect2, is_dng: bool, max_d: float
) -> Dictionary:
	var best_pos: Vector2 = Vector2.INF
	var best_kind: String = ""
	var best_score: float = INF

	# Check companion world content (shrines, dungeon perches, active relays, blooms)
	if LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance):
		var fwc: LxFireflyWorldContent = LxFireflyWorldContent.active_instance
		var ft: Vector2 = fwc.find_nearest_sense_target(wp, max_d)
		if ft.is_finite() and _in_room(ft, room_rect, is_dng):
			var fd: float = wp.distance_to(ft)
			if fd >= 16.0:
				best_pos = ft; best_kind = "pip_feature"; best_score = fd + 40.0

	# Check world interactables (prioritise core room puzzles & ready beacons over side blooms)
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not _is_interactable_valid_target(it_v, world_ctx):
			continue
		var item: Object = it_v as Object
		var ip: Vector2 = wick.get_entity_pos(item)
		if not _in_room(ip, room_rect, is_dng):
			continue
		var dist: float = wp.distance_to(ip)
		if dist < 16.0 or dist > max_d:
			continue
		var k: String = str(item.get("kind")).to_lower()
		var tier_pen: float = -1.0
		if k == "great_lamp" and not _bool_prop(item, "lit") and _is_great_lamp_ready(item):
			tier_pen = 0.0
		elif k == "beacon" and not _bool_prop(item, "lit") and _bool_prop(item, "ignitable"):
			tier_pen = 10.0
		elif (k == "brazier" or k == "road_lamp") and not _bool_prop(item, "lit"):
			tier_pen = 20.0
		elif k == "switch_eye" and not _bool_prop(item, "activated"):
			tier_pen = 22.0
		elif (k == "pressure_plate" or k == "floor_switch") and not _bool_prop(item, "powered") and not _bool_prop(item, "pressed"):
			tier_pen = 24.0
		elif k == "light_sensor" and not _bool_prop(item, "powered"):
			tier_pen = 26.0
		elif k == "light_plant" and str(item.get("grow_kind")) != "wall" and _int_prop(item, "stage") < 2:
			tier_pen = 28.0
		elif k == "chest" and not _bool_prop(item, "opened"):
			tier_pen = 55.0
		if tier_pen >= 0.0:
			var sc: float = tier_pen + dist
			if sc < best_score:
				best_score = sc; best_pos = ip; best_kind = k

	if best_pos.is_finite():
		return {"pos": best_pos, "kind": best_kind, "priority": 1}
	return {}


static func _find_progression_exit(world_ctx: Node, wp: Vector2, room_rect: Rect2, is_dng: bool) -> Dictionary:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return {}
	if world_ctx.has_method("is_arena_locked") and bool(world_ctx.call("is_arena_locked")):
		return {}
	var exits_v: Variant = world_ctx.get("exits")
	if not (exits_v is Array):
		return {}
	var cur_isl: int = int(world_ctx.get("current_island_id")) if world_ctx.get("current_island_id") is int else (Lx.state.island_id if Lx.state != null else 1)
	var best_pos: Vector2 = Vector2.INF
	var best_score: float = INF
	var layers: Variant = world_ctx.get("_layers")
	var rscript: Variant = world_ctx.get("room_script")
	for ex_v: Variant in (exits_v as Array):
		if not (ex_v is Dictionary):
			continue
		var ex: Dictionary = ex_v as Dictionary
		var eid: String = str(ex.get("id", ""))
		if is_instance_valid(layers) and layers is Object and (layers as Object).has_method("is_exit_disabled") and bool((layers as Object).call("is_exit_disabled", eid)):
			continue
		if is_instance_valid(rscript) and rscript is Object and (rscript as Object).has_method("is_exit_locked") and bool((rscript as Object).call("is_exit_locked", eid)):
			continue
		if not LxRegionRuntime.exit_requirements_met(ex):
			continue
		var door_id: String = str(ex.get("locked_door_id", ""))
		if not door_id.is_empty() and world_ctx.has_method("find_interactable"):
			var door: Variant = world_ctx.call("find_interactable", door_id)
			if is_instance_valid(door) and door is Object and (door as Object).has_method("is_solid") and bool((door as Object).call("is_solid")):
				continue
		var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		if not er.has_area():
			continue
		var ep: Vector2 = er.get_center()
		if is_dng and room_rect.has_area() and not room_rect.grow(4.0).intersects(er):
			continue
		var d: float = wp.distance_to(ep)
		if d < 18.0:
			continue
		var to_reg: String = str(ex.get("to_region", ""))
		var to_isl: int = int(ex.get("to_island", cur_isl))
		var reg_key: String = "%d:%s" % [to_isl, to_reg]
		var unvisited: bool = Lx.state != null and not to_reg.is_empty() and not Lx.state.visited_regions.has(reg_key)
		var is_to_dng: bool = not to_reg.is_empty() and to_reg != "overworld" and not to_reg.begins_with("cave_")
		var bonus: float = 0.0
		if unvisited:
			bonus -= 180.0
		if is_to_dng:
			bonus -= 90.0
		if to_isl > cur_isl:
			bonus -= 60.0
		var sc: float = d + bonus
		if sc < best_score:
			best_score = sc; best_pos = ep
	if best_pos.is_finite():
		return {"pos": best_pos, "kind": "exit", "priority": 2}
	return {}


static func _find_secret_target(
	wick: LxWick, world_ctx: Node, wp: Vector2, room_rect: Rect2, is_dng: bool, max_d: float
) -> Dictionary:
	var best_pos: Vector2 = Vector2.INF
	var best_kind: String = ""
	var best_d: float = max_d
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not _is_interactable_valid_target(it_v, world_ctx):
			continue
		var item: Object = it_v as Object
		var ip: Vector2 = wick.get_entity_pos(item)
		if not _in_room(ip, room_rect, is_dng):
			continue
		var k: String = str(item.get("kind")).to_lower()
		var ok: bool = (k == "moth" and not _bool_prop(item, "caught")) \
			or (k == "cracked_wall" and not _bool_prop(item, "broken")) \
			or (k == "phantom_platform" and not _bool_prop(item, "revealed") and Lx.state != null and Lx.state.has_move("lens"))
		if ok:
			var d: float = wp.distance_to(ip)
			if d >= 14.0 and d < best_d:
				best_d = d; best_pos = ip; best_kind = k
	if best_pos.is_finite():
		return {"pos": best_pos, "kind": best_kind, "priority": 3}
	return {}


static func _is_interactable_valid_target(it_v: Variant, world_ctx: Node) -> bool:
	if not is_instance_valid(it_v) or not (it_v is Object):
		return false
	var item: Object = it_v as Object
	if item.get("active") is bool and not bool(item.get("active")):
		return false
	if item is CanvasItem and not (item as CanvasItem).visible:
		return false
	if world_ctx != null and is_instance_valid(world_ctx):
		var layers: Variant = world_ctx.get("_layers")
		var iid: String = str(item.get("id")) if item.get("id") != null else ""
		if not iid.is_empty() and is_instance_valid(layers) and layers is Object and (layers as Object).has_method("is_interactable_disabled"):
			if bool((layers as Object).call("is_interactable_disabled", iid)):
				return false
	return true


static func _is_great_lamp_ready(item: Object) -> bool:
	if item.has_method("get_interact_prompt"):
		return not str(item.call("get_interact_prompt")).is_empty()
	if item.get("_ready_cache") is bool:
		return bool(item.get("_ready_cache"))
	return true


static func _current_room_rect(world_ctx: Node) -> Rect2:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_current_room_rect"):
		var r: Variant = world_ctx.call("get_current_room_rect")
		if r is Rect2:
			return r as Rect2
	return Rect2()


static func _bool_prop(obj: Object, prop: String) -> bool:
	var v: Variant = obj.get(prop)
	return (v as bool) if (v is bool) else false


static func _int_prop(obj: Object, prop: String) -> int:
	var v: Variant = obj.get(prop)
	return int(v) if (v is int or v is float) else 0


static func _is_dungeon(world_ctx: Node) -> bool:
	return world_ctx != null and is_instance_valid(world_ctx) and _bool_prop(world_ctx, "is_dungeon")


static func _in_room(p: Vector2, room_rect: Rect2, is_dng: bool) -> bool:
	if not is_dng or not room_rect.has_area():
		return true
	return room_rect.has_point(p)
