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
	var flash_red: bool = LxHudFx.flash_reduced()
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
	var isl_l: int = Lx.state.island_id if Lx.state != null else 1
	var b_glow: Color = LxBiomePalette.col(isl_l, "glow")
	var relit_l: bool = Lx.state != null and Lx.state.relit_islands.has(isl_l)
	var harm_l: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_l, false))
	for j: int in range(4):
		var pang: float = rot + (float(j) * 2.0 + 0.78) * seg_step
		var pip: Vector2 = (center + Vector2.from_angle(pang) * last_radius).round()
		var tw: float = 0.72 if flash_red else (0.62 + 0.28 * sin(rot * 5.0 + float(j) * 1.57))
		var pcol: Color = LxWick.PAL_CREAM if (j % 2 == 0) else b_glow
		canvas.draw_rect(Rect2(pip, Vector2(1.0, 1.0)), Color(pcol, tw))
		var inner_pip: Vector2 = (center + Vector2.from_angle(pang) * inner_r).round()
		canvas.draw_rect(Rect2(inner_pip, Vector2(1.0, 1.0)), Color(LxWick.PAL_SKY, tw * 0.45))
		var cdir: Vector2 = Vector2.from_angle(float(j) * (PI * 0.5))
		var ct0: Vector2 = (center + cdir * (last_radius - 2.0)).round()
		var ct1: Vector2 = (center + cdir * (last_radius + 1.5)).round()
		canvas.draw_line(ct0, ct1, Color(LxWick.PAL_GOLD if (relit_l or harm_l) else b_glow, 0.42), 1.0)
	_draw_hidden_biome_runes(canvas, off, isl_l, LxWick.PAL_GOLD if (relit_l or harm_l) else b_glow, rot, flash_red)


func _draw_hidden_biome_runes(canvas: CanvasItem, off: Vector2, isl: int, b_glow: Color, rot: float, flash_red: bool) -> void:
	# Reveals delicate biome-unique astral runes anchored in world space inside the True Lens circle
	const STEP: float = 56.0
	var r_lim: float = last_radius - 6.0
	if r_lim <= 10.0:
		return
	var gx0: int = int(floor((last_origin.x - r_lim) / STEP))
	var gx1: int = int(ceil((last_origin.x + r_lim) / STEP))
	var gy0: int = int(floor((last_origin.y - r_lim) / STEP))
	var gy1: int = int(ceil((last_origin.y + r_lim) / STEP))
	for gy: int in range(gy0, gy1 + 1):
		for gx: int in range(gx0, gx1 + 1):
			var h: int = absi((gx * 73856093) ^ (gy * 19349663) ^ (isl * 83492791))
			if (h & 7) >= 3:
				continue
			var wp := Vector2(
				(float(gx) + 0.5) * STEP + float(((h >> 3) & 31) - 16),
				(float(gy) + 0.5) * STEP + float(((h >> 8) & 31) - 16)
			)
			var dist: float = wp.distance_to(last_origin)
			if dist >= r_lim:
				continue
			var reveal: float = clampf(1.0 - dist / r_lim, 0.0, 1.0)
			var tw: float = 0.72 if flash_red else (0.58 + 0.30 * sin(rot * 4.5 + float(h & 15)))
			var a: float = clampf(reveal * 0.42 * tw, 0.0, 0.48)
			if a < 0.04:
				continue
			var p: Vector2 = (wp + off).round()
			var c_main := Color(b_glow, a)
			var c_hi := Color(LxWick.PAL_ICE, a * 0.9)
			match isl:
				1: # Bell-arch glyph
					canvas.draw_arc(p, 3.0, PI, TAU, 6, c_main, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-0.5, 1.0), Vector2(1.0, 1.0)), c_hi)
				2: # Tide wave-chevron
					canvas.draw_line(p + Vector2(-3.0, 1.0), p + Vector2(0.0, -2.0), c_hi, 1.0)
					canvas.draw_line(p + Vector2(0.0, -2.0), p + Vector2(3.0, 1.0), c_main, 1.0)
				3: # Heartwood leaf-sprig
					canvas.draw_line(p + Vector2(-3.0, -1.0), p + Vector2(0.0, 2.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(3.0, -1.0), p + Vector2(0.0, 2.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-0.5, -2.0), Vector2(1.0, 1.0)), c_hi)
				4: # Stained-glass diamond
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(3.0, 0.0), p + Vector2(0.0, 3.0), c_hi, 1.0)
					canvas.draw_line(p + Vector2(0.0, 3.0), p + Vector2(-3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(0.0, -3.0), c_hi, 1.0)
				5: # Astral 4-point star
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(0.0, 3.0), c_hi, 1.0)
				6: # Forge ember chevron
					canvas.draw_line(p + Vector2(-3.0, 2.0), p + Vector2(0.0, -2.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -2.0), p + Vector2(3.0, 2.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p, Vector2(1.0, 1.0)), Color(LxWick.PAL_CREAM, a))
				7: # Silver lunar crescent
					canvas.draw_arc(p, 3.0, -PI * 0.45, PI * 0.45, 6, c_hi, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(1.0, 1.0)), c_main)
				_: # Dawn sunburst
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(0.0, 3.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(LxWick.PAL_CREAM, a))


func reset() -> void:
	super.reset()
	last_radius = 0.0
