class_name LxPaneRipTide
extends LxPane
## Tidewater (Dungeon): Light Zip drags nearby enemies into the arrival burst; shorter hang time.


func _init() -> void:
	id = "rip_tide"
	island_id = 2
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_RIP_TIDE_NAME"
	desc_key = "PANE_RIP_TIDE_DESC"
	tint_key = "sky"


func on_zip(ctx: Dictionary) -> void:
	if str(ctx.get("phase", "arrival")) != "arrival":
		return
	var w: Node2D = _wick(ctx)
	var wr: Node = _world(ctx)
	var dest: Vector2 = ctx.get("to_pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	_spawn_ring(ctx, dest, 34.0, 6.0, 0.24, "sky")
	if w == null or wr == null or not w.has_method("world_get_enemies"):
		return
	for ev: Variant in (w.call("world_get_enemies", wr) as Array):
		if not (ev is Node2D) or not is_instance_valid(ev as Object):
			continue
		var en: Node2D = ev as Node2D
		if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", en)):
			continue
		var d: float = en.global_position.distance_to(dest)
		if d > 10.0 and d <= 52.0:
			en.global_position = en.global_position.move_toward(dest, 18.0)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "hang_time":
		return value - 1.2
	return value
