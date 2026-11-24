class_name LxPaneAnchorLead
extends LxPane
## Tidewater (Secret): Heavy lantern hangs much longer and hits harder, but slows Wick while out.


func _init() -> void:
	id = "anchor_lead"
	island_id = 2
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_ANCHOR_LEAD_NAME"
	desc_key = "PANE_ANCHOR_LEAD_DESC"
	tint_key = "blue"


func on_throw(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_ring(ctx, pos, 2.0, 14.0, 0.22, "blue")


func modify_stat(stat_name: String, value: float, ctx: Dictionary = {}) -> float:
	if stat_name == "hang_time":
		return value + 3.0
	if stat_name == "throw_damage":
		return value + 0.75
	if stat_name == "move_speed":
		var w: Node2D = _wick(ctx)
		if w != null and w.get("lantern") is Object and (w.get("lantern") as Object).has_method("is_out") and bool((w.get("lantern") as Object).call("is_out")):
			return value - 14.0
	return value
