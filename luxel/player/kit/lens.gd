class_name LxMoveLens
extends LxMove
## Lens (Island 5, passive): expands lantern reveal radius (hand_radius 68, hung_radius 118),
## reveals LxPhantomPlatform interactables (on_light(radius, "lens")), reveals hidden enemies
## like PhantomOwl and Gloam (on_light(radius, origin, "lens")), and registers Lens circles on LxRegionLoader.

var last_origin: Vector2 = Vector2.ZERO
var last_radius: float = 0.0


func can_use() -> bool:
	return unlocked and wick != null and not wick.dead


func get_reveal_radius() -> float:
	if not unlocked or wick == null:
		return 0.0
	var data: Dictionary = get_data()
	var hand_r: float = float(data.get("hand_radius", 68.0))
	var hung_r: float = float(data.get("hung_radius", 118.0))
	if wick.lantern != null and wick.lantern.is_out():
		if wick.lantern.state == LxLantern.State.CARRIED:
			return 44.0
		return hung_r
	return hand_r


func get_reveal_origin() -> Vector2:
	if wick == null:
		return Vector2.ZERO
	if wick.lantern != null and wick.lantern.is_out():
		return wick.lantern.pos
	return wick.global_position


func register_circle(world_ctx: Node) -> void:
	if not unlocked or wick == null or wick.dead:
		return
	var rad: float = get_reveal_radius()
	if rad <= 0.0:
		return
	var origin: Vector2 = get_reveal_origin()
	last_origin = origin
	last_radius = rad
	var ctx: Node = world_ctx if world_ctx != null else Lx.world
	if ctx == null:
		return
	if ctx.has_method("register_lens_circle"):
		ctx.call("register_lens_circle", origin, rad)
	elif ctx.has_method("apply_light"):
		ctx.call("apply_light", origin, rad, "lens")


func tick_lens(_dt: float, world_ctx: Node) -> void:
	if not unlocked or wick == null or wick.dead:
		last_radius = 0.0
		return
	var rad: float = get_reveal_radius()
	var origin: Vector2 = get_reveal_origin()
	last_origin = origin
	last_radius = rad
	if rad <= 0.0:
		return

	var ctx: Node = world_ctx if world_ctx != null else Lx.world
	if ctx != null:
		if ctx.has_method("register_lens_circle"):
			ctx.call("register_lens_circle", origin, rad)
		elif ctx.has_method("apply_light"):
			ctx.call("apply_light", origin, rad, "lens")

	var inters: Array = wick.world_get_interactables(ctx)
	for it_var: Variant in inters:
		if not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if not is_instance_valid(item) or not item.has_method("on_light"):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 8.0)
		if ipos.distance_to(origin) <= rad + irad:
			item.call("on_light", rad, "lens")

	var enemies: Array = wick.world_get_enemies(ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not is_instance_valid(enemy) or not enemy.has_method("on_light"):
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		if epos.distance_to(origin) <= rad + erad:
			var arity: int = wick.get_method_arity(enemy, "on_light")
			if arity >= 3:
				enemy.call("on_light", rad, origin, "lens")
			elif arity == 2:
				enemy.call("on_light", rad, "lens")
			else:
				enemy.call("on_light", rad)


func draw_fx(canvas: CanvasItem, off: Vector2) -> void:
	if not unlocked or last_radius <= 0.0:
		return
	var center: Vector2 = (last_origin + off).round() + Vector2(0.0, -5.0)
	canvas.draw_arc(center, last_radius, 0.0, TAU, 36, Color(LxWick.PAL_ICE, 0.22), 1.0)
	canvas.draw_arc(center, maxf(4.0, last_radius - 2.0), 0.0, TAU, 36, Color(LxWick.PAL_SKY, 0.14), 1.0)


func reset() -> void:
	super.reset()
	last_radius = 0.0
