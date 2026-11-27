class_name LxMoveSunflare
extends LxMove
## Sunflare (Island 6): press lx_sunflare (Q / Y) at full Ember meter.
## Spends full Ember meter, emits radial burst (radius 76) cracking heavy armour & stunning 1.6s,
## shatters LxObsidianSeal & LxCrackedWall in radius, and lights EVERY LxBrazier in the current room.

const FLARE_VIS_DURATION: float = 0.34

var flare_vis_t: float = 0.0
var flare_vis_max: float = FLARE_VIS_DURATION
var flare_origin: Vector2 = Vector2.ZERO
var flare_radius: float = 76.0
var flares_fired: int = 0

var _world_ctx: Node = null
var _buffer_t: float = 0.0


func set_world_ctx(world_ctx: Node) -> void:
	_world_ctx = world_ctx


func get_ember_max() -> float:
	if Lx.state != null:
		return Lx.state.get_effective_ember_max()
	return float(get_data().get("ember_max", 100.0))


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or wick.is_zipping():
		return false
	return wick.ember >= get_ember_max() - 0.001


func press() -> bool:
	return trigger_sunflare(_world_ctx)


func trigger_sunflare(world_ctx: Node = null) -> bool:
	if not can_use():
		if unlocked and not locked and wick != null and not wick.dead and wick.ember >= get_ember_max() - 0.001 and (wick.is_zipping() or cooldown_left > 0.0):
			_buffer_t = 0.12
			return false
		if wick != null:
			wick.emit_sfx("denied", wick.global_position, false)
		return false
	_buffer_t = 0.0

	if wick.move_beam != null:
		wick.move_beam.cancel()

	var ctx: Node = world_ctx if world_ctx != null else (_world_ctx if _world_ctx != null else Lx.world)
	var data: Dictionary = get_data()
	var counter_emp: bool = wick.move_dash != null and wick.move_dash.consume_counter()
	var rad: float = float(data.get("radius", 76.0)) + (12.0 if counter_emp else 0.0)
	var dmg: float = float(data.get("damage", 3.0)) * (1.25 if counter_emp else 1.0)
	var wear: float = float(data.get("shield_wear", 4.0)) + (1.0 if counter_emp else 0.0)
	var stun_t: float = float(data.get("stun_time", 1.6))
	var cracks: bool = bool(data.get("cracks_armour", true))
	var stagger: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.14))
	var sh: float = float(data.get("shake", 0.24))

	wick.ember = 0.0
	var origin: Vector2 = wick.global_position
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.trigger_focus_flash(1.0)
		LxDarknessLayer.active_instance.add_burst_light(origin, rad * 1.9, 1.25 if LxHudFx.flash_reduced() else 1.85, 0.48)

	# 1. Hit every alive enemy within radial burst (cracks_armour=true, stun 1.6s)
	var enemies: Array = wick.world_get_enemies(ctx)
	for e_var: Variant in enemies:
		if not is_instance_valid(e_var) or not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not wick.is_entity_alive(enemy):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		if epos.distance_to(origin) <= rad + erad and wick.world_has_clear_view(ctx, origin, epos, erad + 2.0):
			var dir: Vector2 = (epos - origin).normalized() if epos.distance_to(origin) > 0.1 else wick.facing
			var hit: LxHit = LxHit.make(
				LxHit.SOURCE_SUNFLARE, dmg, dir, origin,
				wear, stagger, true, wick, cracks
			)
			var res: int = wick.apply_hit_to_entity(enemy, hit)
			if res == LxEnemyBrain.HitResult.OPENED and wick.is_entity_alive(enemy):
				var st_v: Variant = enemy.get("state")
				var st_t: Variant = enemy.get("state_timer")
				if st_v is int and int(st_v) == LxEnemyBrain.State.STAGGER and st_t is float and float(st_t) < stun_t:
					enemy.set("state_timer", stun_t)
			wick.on_hit_landed(hit, res, epos, hs, sh)

	# 2. Shatter LxObsidianSeal & LxCrackedWall in radius + light EVERY LxBrazier in the current room
	var room_rect: Rect2 = Rect2()
	if ctx != null and ctx.has_method("get_current_room_rect"):
		room_rect = ctx.call("get_current_room_rect") as Rect2

	var inters: Array = wick.world_get_interactables(ctx)
	for it_var: Variant in inters:
		if not is_instance_valid(it_var) or not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if item.get("active") is bool and not bool(item.get("active")):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 8.0)
		var is_brazier: bool = (item is LxBrazier) or (str(item.get("kind")) == "brazier")
		if is_brazier:
			var in_room: bool = (not room_rect.has_area()) or room_rect.grow(8.0).has_point(ipos)
			if in_room and _has_clear_view_to_item(ctx, origin, item, ipos, irad):
				if item.has_method("on_light"):
					item.call("on_light", 999.0, "sunflare")
				elif item.has_method("on_hit"):
					var bdir: Vector2 = (ipos - origin).normalized() if ipos.distance_to(origin) > 0.1 else Vector2.UP
					item.call("on_hit", LxHit.make(LxHit.SOURCE_SUNFLARE, dmg, bdir, origin, wear, stagger, true, wick, cracks))
				wick.spawn_sparks(ipos, Vector2.UP, 6, LxWick.PAL_GOLD, 24.0, 72.0, 0.24)
				continue

		if item.has_method("on_hit") and _within_burst(origin, rad, item, ipos, irad) and _has_clear_view_to_item(ctx, origin, item, ipos, irad):
			var idir: Vector2 = (ipos - origin).normalized() if ipos.distance_to(origin) > 0.1 else wick.facing
			var hit_i: LxHit = LxHit.make(
				LxHit.SOURCE_SUNFLARE, dmg, idir, origin,
				wear, stagger, true, wick, cracks
			)
			var hit_res: Variant = item.call("on_hit", hit_i)
			if hit_res is bool and bool(hit_res):
				wick.spawn_sparks(ipos, idir, 10, LxWick.PAL_GOLD, 35.0, 105.0, 0.28)
	if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
		for ri: int in range(8):
			var rdir: Vector2 = Vector2.from_angle(float(ri) * (TAU * 0.125))
			LxBiomeMechanics.active_instance.try_hit_biome_target(origin, origin + rdir * rad, rdir, wick)

	# 3. Big Last Light gold/cream expanding ring + hitstop 0.14s + shake 0.24
	flare_origin = origin
	flare_radius = rad
	flare_vis_max = FLARE_VIS_DURATION
	flare_vis_t = FLARE_VIS_DURATION
	flares_fired += 1
	cooldown_left = 0.35

	wick.trigger_hitstop(hs)
	if Lx.hitstop != null and is_instance_valid(Lx.hitstop) and Lx.hitstop.has_method("trigger_slowmo"):
		Lx.hitstop.trigger_slowmo(0.45, 0.22)
	wick.trigger_shake(sh)
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", Vector2.UP, 3.0)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if is_instance_valid(amb) and amb is Object and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", origin, rad * 1.4, 130.0)
		var wfx: Variant = Lx.world.get("_water_fx")
		if is_instance_valid(wfx) and wfx is Object and (wfx as Object).has_method("spawn_ripple"):
			(wfx as Object).call("spawn_ripple", origin, "gold", 18.0)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.SCORCH, origin, rad * 0.48, 9.0)
	var isl_sf: int = Lx.state.island_id if Lx.state != null else 1
	wick.spawn_ring(origin, 4.0, rad, 0.36, LxWick.PAL_GOLD, 2.5)
	wick.spawn_ring(origin, 2.0, rad * 0.82, 0.28, LxWick.PAL_CREAM, 2.0)
	wick.spawn_ring(origin, 6.0, rad * 1.08, 0.42, LxBiomePalette.col(isl_sf, "hi"), 1.5)
	if counter_emp:
		wick.spawn_ring(origin, 8.0, rad * 1.15, 0.44, LxWick.PAL_CREAM, 2.0)
		wick.emit_sfx("perfect_counter", origin, false)
	var b_glow_sf: Color = LxBiomePalette.col(isl_sf, "glow")
	for i: int in range(16):
		var sdir: Vector2 = Vector2.from_angle(TAU * float(i) / 16.0)
		var scol: Color = b_glow_sf if (i % 4 == 3) else (LxWick.PAL_CREAM if (i % 2 == 0) else LxWick.PAL_GOLD)
		wick.spawn_sparks(origin, sdir, 1, scol, 55.0, 145.0, 0.30)
	wick.emit_sfx("sunflare_burst", origin, false)
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if flare_vis_t > 0.0:
		flare_vis_t = maxf(0.0, flare_vis_t - dt)
	if _buffer_t > 0.0:
		_buffer_t = maxf(0.0, _buffer_t - dt)
		if can_use():
			trigger_sunflare(_world_ctx)


func draw_fx(canvas: CanvasItem, off: Vector2) -> void:
	if flare_vis_t <= 0.0:
		return
	var flash_red: bool = LxHudFx.flash_reduced()
	var flash_sc: float = 0.62 if flash_red else 1.0
	var prog: float = 1.0 - clampf(flare_vis_t / maxf(flare_vis_max, 0.01), 0.0, 1.0)
	var fade: float = 1.0 - prog
	var center: Vector2 = (flare_origin + off).round() + Vector2(0.0, -5.0)
	var cur_r: float = lerpf(8.0, flare_radius, prog)
	canvas.draw_circle(center, cur_r * 0.55, Color(LxWick.PAL_CREAM, fade * 0.28 * flash_sc))
	# 8-ray tapered golden solar starburst corona (alternating long PAL_GOLD & shorter PAL_CREAM)
	var r_in: float = lerpf(3.0, cur_r * 0.26, prog)
	for i: int in range(8):
		var is_long: bool = (i % 2 == 0)
		var rdir: Vector2 = Vector2.from_angle(float(i) * (TAU * 0.125))
		var rperp := Vector2(-rdir.y, rdir.x)
		var r_out: float = cur_r * (1.06 if is_long else 0.76)
		var base_p: Vector2 = center + rdir * r_in
		var tip_p: Vector2 = (center + rdir * r_out).round()
		var half_w: float = (4.2 if is_long else 2.8) * fade * lerpf(1.0, 0.80, 1.0 - flash_sc)
		var rcol: Color = LxWick.PAL_GOLD if is_long else LxWick.PAL_CREAM
		if half_w >= 1.0:
			var poly := PackedVector2Array([
				(base_p - rperp * half_w).round(),
				tip_p,
				(base_p + rperp * half_w).round(),
			])
			canvas.draw_colored_polygon(poly, Color(rcol, fade * (0.72 if is_long else 0.60) * flash_sc))
		canvas.draw_line(base_p.round(), tip_p, Color(rcol, fade * 0.85 * flash_sc), 1.0)
	# Expanding golden-cream nova rings + outer biome resonance corona
	var isl_d: int = Lx.state.island_id if Lx.state != null else 1
	var b_glow: Color = LxBiomePalette.col(isl_d, "glow")
	canvas.draw_arc(center, cur_r * 1.12, 0.0, TAU, 32, Color(b_glow, fade * (0.48 if flash_red else 0.62)), 2.0)
	canvas.draw_arc(center, cur_r, 0.0, TAU, 32, Color(LxWick.PAL_GOLD, fade * (0.76 if flash_red else 0.95)), 3.0)
	canvas.draw_arc(center, cur_r * 0.78, 0.0, TAU, 28, Color(LxWick.PAL_CREAM, fade * (0.68 if flash_red else 0.90)), 1.0)
	# Crisp inner 4-point dawn star + diagonal biome filigree rays
	var star_r: float = roundf(lerpf(14.0, 4.0, prog) * (0.78 if flash_red else 1.0))
	if star_r >= 2.0:
		var sa: float = fade * (0.72 if flash_red else 0.96)
		var inner_s: float = roundf(star_r * 0.62)
		var diag_s: float = roundf(star_r * 0.56)
		if diag_s >= 2.0:
			canvas.draw_line(center + Vector2(-diag_s, -diag_s), center + Vector2(diag_s, diag_s), Color(b_glow, sa * 0.72), 1.0)
			canvas.draw_line(center + Vector2(-diag_s, diag_s), center + Vector2(diag_s, -diag_s), Color(b_glow, sa * 0.72), 1.0)
		canvas.draw_line(center + Vector2(-star_r, 0.0), center + Vector2(star_r, 0.0), Color(LxWick.PAL_GOLD, sa), 1.0)
		canvas.draw_line(center + Vector2(0.0, -star_r), center + Vector2(0.0, star_r), Color(LxWick.PAL_GOLD, sa), 1.0)
		canvas.draw_line(center + Vector2(-inner_s, 0.0), center + Vector2(inner_s, 0.0), Color(LxWick.PAL_CREAM, sa), 1.0)
		canvas.draw_line(center + Vector2(0.0, -inner_s), center + Vector2(0.0, inner_s), Color(LxWick.PAL_CREAM, sa), 1.0)
		canvas.draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(LxWick.PAL_CREAM, sa))


func reset() -> void:
	super.reset()
	flare_vis_t = 0.0
	flares_fired = 0
	_buffer_t = 0.0


func _has_clear_view_to_item(ctx: Node, origin: Vector2, item: Object, ipos: Vector2, irad: float) -> bool:
	var target: Vector2 = ipos
	var pad: float = irad + 2.0 if (item.has_method("blocks_sight") and bool(item.call("blocks_sight"))) else 2.0
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area():
			target = Vector2(clampf(origin.x, srect.position.x, srect.end.x), clampf(origin.y, srect.position.y, srect.end.y))
			pad = 2.0
	return wick.world_has_clear_view(ctx, origin, target, pad)


func _within_burst(origin: Vector2, rad: float, item: Object, ipos: Vector2, irad: float) -> bool:
	if ipos.distance_to(origin) <= rad + irad:
		return true
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area():
			var closest := Vector2(
				clampf(origin.x, srect.position.x, srect.end.x),
				clampf(origin.y, srect.position.y, srect.end.y)
			)
			return closest.distance_to(origin) <= rad
	return false
