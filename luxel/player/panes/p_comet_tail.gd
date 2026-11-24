class_name LxPaneCometTail
extends LxPane
## Starfall (Trial): Long-range bolt hits flare bright for extra damage; point-blank hits are weaker.


func _init() -> void:
	id = "comet_tail"
	island_id = 5
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_COMET_TAIL_NAME"
	desc_key = "PANE_COMET_TAIL_DESC"
	tint_key = "sky"


func on_bolt_hit(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	if w != null and pos.distance_to(w.global_position) >= 82.0:
		_spawn_ring(ctx, pos, 2.0, 15.0, 0.18, "sky")
		_pulse_aoe(ctx, pos, 14.0, 0.40, 0.25, false, LxHit.SOURCE_BOLT)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_speed":
		return value + 55.0
	if stat_name == "bolt_damage":
		return value * 0.85
	return value
