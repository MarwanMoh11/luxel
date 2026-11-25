class_name LxSkiffBell
extends LxToy
## Brass harbor recall bell: ring via interact (E) or bolt shot to call the
## region's Skiff cleanly back to this dock's open-water mooring point.

var dock_pos: Vector2 = Vector2.ZERO
var dock_dir: Vector2 = Vector2.RIGHT
var _ring_t: float = 0.0


func _toy_setup() -> void:
	kind = "skiff_bell"
	radius = 15.0
	dock_pos = _parse_vec2(props.get("dock_pos", [pos.x + 32.0, pos.y]), pos + Vector2(32.0, 0.0))
	dock_dir = dir_vec("dock_dir", Vector2.RIGHT)
	_ring_t = 0.0
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	return _ring_bell()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW, LxHit.SOURCE_BEAM]:
		return _ring_bell()
	return false


func _ring_bell() -> bool:
	if not active or region == null or not is_instance_valid(region):
		return false
	_ring_t = 0.55
	_emit_sfx("bell_toll_light")
	var skiff: LxVehicleSkiff = _find_region_skiff()
	if skiff != null:
		if skiff.rider != null and is_instance_valid(skiff.rider):
			skiff.rider.dismount(pos)
		skiff.heading = dock_dir
		skiff.recall_to_dock(dock_pos)
	elif region.has_method("spawn_interactable"):
		var created: Variant = region.call("spawn_interactable", {
			"id": "skiff_recalled_" + id,
			"kind": "vehicle_skiff",
			"pos": [dock_pos.x, dock_pos.y],
			"props": {"dir": [dock_dir.x, dock_dir.y]},
		})
		if created is LxVehicleSkiff:
			(created as LxVehicleSkiff).recall_to_dock(dock_pos)
	if Lx.events != null and LxStrings.has_id("ISL2_SKIFF_CALLED"):
		Lx.events.narration_requested.emit("ISL2_SKIFF_CALLED", "narration", 2.0)
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func _find_region_skiff() -> LxVehicleSkiff:
	if region == null or not region.has_method("get_interactables"):
		return null
	var best: LxVehicleSkiff = null
	var best_d2: float = INF
	for it_v: Variant in (region.call("get_interactables") as Array):
		if it_v is LxVehicleSkiff and is_instance_valid(it_v as Object):
			var sk: LxVehicleSkiff = it_v as LxVehicleSkiff
			if not sk.active:
				continue
			var d2: float = sk.pos.distance_squared_to(pos)
			if d2 < best_d2:
				best_d2 = d2
				best = sk
	return best


func get_interact_prompt() -> String:
	return "PROMPT_RING_SKIFF" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-5.0, -3.0), Vector2(10.0, 8.0)) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if _ring_t > 0.0:
		_ring_t = maxf(0.0, _ring_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 36.0 if _ring_t > 0.0 else 22.0, 0.65 if _ring_t > 0.0 else 0.34)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var sway: float = 0.0 if (LxHudFx.flash_reduced() or _ring_t <= 0.0) else roundf(sin(_ring_t * 28.0) * 1.5)

	_draw_ground_shadow(7.0, 2.5, Vector2(0.0, 2.0))
	# Timber post & crossbar
	draw_rect(Rect2(-3.0, -14.0, 6.0, 18.0), c_void)
	draw_rect(Rect2(-2.0, -13.0, 4.0, 16.0), PAL["wine"] as Color)
	draw_rect(Rect2(-1.0, -13.0, 1.0, 16.0), PAL["apricot"] as Color)
	draw_rect(Rect2(-7.0, -15.0, 14.0, 3.0), c_void)
	draw_rect(Rect2(-6.0, -14.0, 12.0, 1.0), c_dusk)
	# Hanging brass bell
	draw_rect(Rect2(-4.0 + sway, -12.0, 8.0, 7.0), c_void)
	draw_rect(Rect2(-3.0 + sway, -11.0, 6.0, 5.0), c_cream if _ring_t > 0.25 else c_gold)
	draw_rect(Rect2(-4.0 + sway, -7.0, 8.0, 2.0), PAL["apricot"] as Color)
	draw_rect(Rect2(-1.0 + sway, -5.0, 2.0, 2.0), c_cream)
	if _ring_t > 0.0:
		var u: float = 1.0 - clampf(_ring_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2(0.0, -9.0), roundf(lerpf(5.0, 22.0, u)), 0.0, TAU, 16, PAL["ice"] as Color, 1.2)
	_draw_signal_pulses()
