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
	var flash_red: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var rot: float = float(Time.get_ticks_msec()) * 0.00035
	var inner_r: float = maxf(4.0, last_radius - 2.5)
	var seg_step: float = TAU / 8.0
	var arc_span: float = seg_step * 0.56
	var inner_span: float = seg_step * 0.42
	for i: int in range(8):
		var shim: float = 1.0 if flash_red else (0.84 + 0.16 * sin(rot * 4.0 + float(i) * 1.1))
		var a0: float = rot + float(i) * seg_step
		canvas.draw_arc(center, last_radius, a0, a0 + arc_span, 6, Color(LxWick.PAL_ICE, 0.24 * shim), 1.0)
		var b0: float = -rot * 0.65 + (float(i) + 0.35) * seg_step
		canvas.draw_arc(center, inner_r, b0, b0 + inner_span, 5, Color(LxWick.PAL_SKY, 0.15 * shim), 1.0)
	for j: int in range(4):
		var pang: float = rot + (float(j) * 2.0 + 0.78) * seg_step
		var pip: Vector2 = (center + Vector2.from_angle(pang) * last_radius).round()
		var tw: float = 0.72 if flash_red else (0.62 + 0.28 * sin(rot * 5.0 + float(j) * 1.57))
		var pcol: Color = LxWick.PAL_CREAM if (j % 2 == 0) else LxWick.PAL_ICE
		canvas.draw_rect(Rect2(pip, Vector2(1.0, 1.0)), Color(pcol, tw))
		var inner_pip: Vector2 = (center + Vector2.from_angle(pang) * inner_r).round()
		canvas.draw_rect(Rect2(inner_pip, Vector2(1.0, 1.0)), Color(LxWick.PAL_SKY, tw * 0.45))


func reset() -> void:
	super.reset()
	last_radius = 0.0
