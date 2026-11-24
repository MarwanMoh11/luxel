class_name LxPaneBelfryWeight
extends LxPane
## Bell Isle (Secret): Heavy recoil kicks Wick back for kiting; close-range bolts crack extra hard.


func _init() -> void:
	id = "belfry_weight"
	island_id = 1
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_BELFRY_WEIGHT_NAME"
	desc_key = "PANE_BELFRY_WEIGHT_DESC"
	tint_key = "coral"


func on_bolt_hit(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	if w != null and pos.distance_to(w.global_position) <= 44.0:
		_spawn_ring(ctx, pos, 2.0, 14.0, 0.16, "coral")
		_pulse_aoe(ctx, pos, 16.0, 0.35, 0.4, true, LxHit.SOURCE_BOLT)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "recoil":
		return value + 65.0
	if stat_name == "bolt_range":
		return value - 22.0
	return value
