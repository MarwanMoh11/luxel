class_name LxPaneBriarThorn
extends LxPane
## Thornwood (Trial): Taking damage bursts a thorn ring around Wick; slower ember refill.


func _init() -> void:
	id = "briar_thorn"
	island_id = 3
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_BRIAR_THORN_NAME"
	desc_key = "PANE_BRIAR_THORN_DESC"
	tint_key = "jade"


func on_hurt(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = w.global_position if w != null else Vector2.ZERO
	_spawn_ring(ctx, pos, 4.0, 34.0, 0.24, "lime")
	_spawn_sparks(ctx, pos, Vector2.UP, 8, "jade")
	_pulse_aoe(ctx, pos, 34.0, 1.1, 1.0, true, LxHit.SOURCE_HAZARD)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "ember_gain":
		return value * 0.75
	return value
