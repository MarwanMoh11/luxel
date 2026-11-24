class_name LxPaneGlassStep
extends LxPane
## Moon Shoals (Quest): Dashing close past a foe trims half dash cooldown; dimmer lantern glow.


func _init() -> void:
	id = "glass_step"
	island_id = 7
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_GLASS_STEP_NAME"
	desc_key = "PANE_GLASS_STEP_DESC"
	tint_key = "sky"


func on_dash(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var wr: Node = _world(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	if w == null or wr == null or not w.has_method("world_get_enemies"):
		return
	for ev: Variant in (w.call("world_get_enemies", wr) as Array):
		if not (ev is Object) or not is_instance_valid(ev as Object):
			continue
		if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", ev)):
			continue
		var epos: Vector2 = w.call("get_entity_pos", ev) as Vector2
		if epos.distance_to(pos) <= 42.0:
			var md: Variant = w.get("move_dash")
			if md is Object:
				(md as Object).set("cooldown_left", float((md as Object).get("cooldown_left")) * 0.5)
			_spawn_ring(ctx, pos, 2.0, 14.0, 0.18, "ice")
			break


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "light_radius":
		return value - 16.0
	return value
