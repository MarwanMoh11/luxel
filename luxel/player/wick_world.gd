class_name LxWickWorld
extends RefCounted
## World query, collision, and entity-inspection helpers extracted from LxWick
## to keep luxel/player/wick.gd concise and <= 600 lines.

var _arity_cache: Dictionary = {}


func clear() -> void:
	_arity_cache.clear()


func collide_step(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2, rad: float, airborne: bool) -> Vector2:
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	if ctx == null:
		return to_p
	if ctx.has_method("collide"):
		var cross_pit: bool = airborne or wick.is_dashing() or wick.is_gliding() or wick.is_zipping() or wick.is_launched()
		var cross_water: bool = airborne or wick.is_dashing() or wick.is_gliding() or wick.is_zipping() or wick.is_launched()
		var step_dist: float = from_p.distance_to(to_p)
		if step_dist <= 3.5:
			return LxWickFx.collide_with_corner_slide(ctx, from_p, to_p, rad, cross_pit, cross_water)
		var steps: int = clampi(int(ceilf(step_dist / 3.5)), 2, 16)
		var cur: Vector2 = from_p
		var inc: Vector2 = (to_p - from_p) / float(steps)
		for _i: int in range(steps):
			var nxt: Vector2 = LxWickFx.collide_with_corner_slide(ctx, cur, cur + inc, rad, cross_pit, cross_water)
			if nxt.distance_squared_to(cur) < 0.0004:
				break
			cur = nxt
		return cur
	if ctx.has_method("resolve_move"):
		return ctx.call("resolve_move", from_p, to_p, rad, airborne) as Vector2
	if ctx.has_method("collide_step"):
		return (ctx.call("collide_step", from_p, to_p, rad, airborne) if get_method_arity(ctx, "collide_step") >= 4 else ctx.call("collide_step", from_p, to_p, rad)) as Vector2
	if ctx.has_method("is_blocked"):
		var cur: Vector2 = from_p
		if not bool(ctx.call("is_blocked", Vector2(to_p.x, cur.y), rad, airborne)):
			cur.x = to_p.x
		if not bool(ctx.call("is_blocked", Vector2(cur.x, to_p.y), rad, airborne)):
			cur.y = to_p.y
		return cur
	var bvar: Variant = ctx.call("get_bounds") if ctx.has_method("get_bounds") else (ctx.get("bounds") if ctx.get("bounds") is Rect2 else ctx.get("world_bounds"))
	if bvar is Rect2 and (bvar as Rect2).has_area():
		var r: Rect2 = (bvar as Rect2).grow(-rad)
		return Vector2(clampf(to_p.x, r.position.x, r.end.x), clampf(to_p.y, r.position.y, r.end.y))
	return to_p


func shot_blocked(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2 = Vector2.INF) -> bool:
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	if ctx == null:
		return false
	var target: Vector2 = to_p if to_p.is_finite() else from_p
	if ctx.has_method("tile_at") and LxMapFormat.blocks_sight_tile(str(ctx.call("tile_at", target))):
		return true
	if ctx.has_method("clear_view"):
		return not bool(ctx.call("clear_view", from_p, target))
	if ctx.has_method("is_shot_blocked"):
		return bool(ctx.call("is_shot_blocked", target))
	return bool(ctx.call("shot_blocked", target)) if ctx.has_method("shot_blocked") else false


func lantern_blocked(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2) -> bool:
	if shot_blocked(wick, world_ctx, from_p, to_p):
		return true
	return _hits_lantern_blocker(wick, world_ctx, from_p, to_p)


func zip_blocked(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2) -> bool:
	if shot_blocked(wick, world_ctx, from_p, to_p):
		return true
	return _hits_lantern_blocker(wick, world_ctx, from_p, to_p)


func has_clear_view(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2, target_pad: float = 0.0) -> bool:
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	if ctx == null or not ctx.has_method("clear_view"):
		return true
	var dest: Vector2 = to_p
	var d: float = from_p.distance_to(to_p)
	if target_pad > 0.0 and d > target_pad + 2.0:
		dest = to_p - ((to_p - from_p) / d) * target_pad
	return bool(ctx.call("clear_view", from_p, dest))


func _hits_lantern_blocker(wick: LxWick, world_ctx: Node, from_p: Vector2, to_p: Vector2) -> bool:
	var dist: float = from_p.distance_to(to_p)
	var steps: int = maxi(1, int(ceil(dist / 4.0)))
	for it_v: Variant in world_list(wick, world_ctx, "get_interactables", "interactables", "lx_interactables"):
		if not is_instance_valid(it_v) or not (it_v is Object):
			continue
		var item: Object = it_v as Object
		if item.get("active") is bool and not bool(item.get("active")):
			continue
		if not item.has_method("blocks_lantern"):
			continue
		var arity: int = get_method_arity(item, "blocks_lantern")
		var blocked: bool = bool(item.call("blocks_lantern", from_p, to_p)) if arity >= 2 else bool(item.call("blocks_lantern"))
		if not blocked:
			continue
		var srect: Rect2 = Rect2()
		if item.has_method("get_lantern_block_rect"):
			srect = item.call("get_lantern_block_rect") as Rect2
		elif item.has_method("get_solid_rect"):
			srect = item.call("get_solid_rect") as Rect2
		else:
			continue
		if not srect.has_area():
			continue
		var grown: Rect2 = srect.grow(1.5)
		for i: int in range(1, steps + 1):
			if grown.has_point(from_p.lerp(to_p, float(i) / float(steps))):
				return true
	return false


func get_mirror_hit(world_ctx: Node, from_p: Vector2, to_p: Vector2) -> Dictionary:
	if world_ctx != null and world_ctx.has_method("get_mirror_hit"):
		var res: Variant = world_ctx.call("get_mirror_hit", from_p, to_p)
		return res as Dictionary if res is Dictionary else {}
	return {}


func world_list(wick: LxWick, world_ctx: Node, getter: String, prop: String, group_name: String) -> Array:
	if world_ctx != null:
		if world_ctx.has_method(getter):
			var a: Variant = world_ctx.call(getter)
			if a is Array:
				return a as Array
		var v: Variant = world_ctx.get(prop)
		if v is Array:
			return v as Array
	return wick.get_tree().get_nodes_in_group(group_name) if wick.is_inside_tree() else []


func get_entity_pos(entity: Object) -> Vector2:
	if entity is Node2D:
		return (entity as Node2D).global_position
	var pv: Variant = entity.get("pos")
	return pv as Vector2 if pv is Vector2 else Vector2.ZERO


func get_entity_radius(entity: Object, fallback: float = 8.0) -> float:
	for key: String in ["body_radius", "radius", "body"]:
		var rv: Variant = entity.get(key)
		if rv is float or rv is int:
			return float(rv)
	return fallback


func is_entity_alive(entity: Object) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.has_method("is_dead") and bool(entity.call("is_dead")):
		return false
	if entity.has_method("is_targetable") and not bool(entity.call("is_targetable")):
		return false
	var dv: Variant = entity.get("dead")
	if dv is bool and bool(dv):
		return false
	var hpv: Variant = entity.get("hp")
	return not ((hpv is float or hpv is int) and float(hpv) <= 0.0)


func is_snatcher_entity(entity: Object) -> bool:
	var kv: Variant = entity.get("kind")
	if kv is String:
		var ks: String = (kv as String).to_lower()
		return ks.contains("snatcher") or ks.contains("magpie") or ks.contains("gull") or ks.contains("thief")
	return false


func apply_hit_to_entity(entity: Object, hit: LxHit) -> int:
	return int(entity.call("take_hit", hit)) if (entity != null and is_instance_valid(entity) and entity.has_method("take_hit")) else -1


func get_method_arity(obj: Object, method_name: String) -> int:
	if not is_instance_valid(obj):
		return 4
	var scr: Variant = obj.get_script()
	var tkey: String = str((scr as Object).get_instance_id()) if is_instance_valid(scr) else obj.get_class()
	var key: String = "%s:%s" % [tkey, method_name]
	if _arity_cache.has(key):
		return int(_arity_cache[key])
	if _arity_cache.size() >= 256:
		_arity_cache.clear()
	for m: Dictionary in obj.get_method_list():
		if str(m.get("name", "")) == method_name:
			var sz: int = (m.get("args", []) as Array).size()
			_arity_cache[key] = sz
			return sz
	_arity_cache[key] = 4
	return 4
