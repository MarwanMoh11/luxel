class_name LxPaneDawnSpark
extends LxPane
## Long Night (Quest): Every kill flashes bright dawn light and feeds ember; shorter bolt reach.


func _init() -> void:
	id = "dawn_spark"
	island_id = 8
	source_kind = "quest"
	lead_cost = 3
	name_key = "PANE_DAWN_SPARK_NAME"
	desc_key = "PANE_DAWN_SPARK_DESC"
	tint_key = "gold"


func on_kill(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_ring(ctx, pos, 4.0, 32.0, 0.28, "gold")
	_spawn_sparks(ctx, pos, Vector2.UP, 8, "cream")
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 86.0, 1.35, 0.35)
	var w: Node2D = _wick(ctx)
	if w != null and w.get("ember") != null:
		w.set("ember", minf(100.0, float(w.get("ember")) + 14.0))


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_range":
		return value - 26.0
	return value
