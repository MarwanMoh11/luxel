class_name LxPaneRainPrism
extends LxPane
## Mirefen (Secret): Recall sheds 4 rain spark pools along return; slower recall speed.


func _init() -> void:
	id = "rain_prism"
	island_id = 4
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_RAIN_PRISM_NAME"
	desc_key = "PANE_RAIN_PRISM_DESC"
	tint_key = "ice"


func on_recall(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	var end_p: Vector2 = w.global_position if w != null else pos + Vector2(32.0, 0.0)
	var fx: LxPaneFx = _fx(ctx)
	for i: int in range(4):
		var pt: Vector2 = pos.lerp(end_p, float(i + 1) / 5.0)
		if fx != null:
			fx.add_pool(pt, 10.0, 1.8, 0.45, "ice", "ember")
		_spawn_sparks(ctx, pt, Vector2.DOWN, 3, "sky")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "recall_speed":
		return value - 80.0
	return value
