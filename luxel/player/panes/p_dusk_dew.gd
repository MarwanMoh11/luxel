class_name LxPaneDuskDew
extends LxPane
## Mirefen (Quest): First 4 s of every room doubles ember gain; slower ember gain afterwards.


func _init() -> void:
	id = "dusk_dew"
	island_id = 4
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_DUSK_DEW_NAME"
	desc_key = "PANE_DUSK_DEW_DESC"
	tint_key = "ice"


func on_room_enter(ctx: Dictionary) -> void:
	super.on_room_enter(ctx)
	_timer = 4.0
	var w: Node2D = _wick(ctx)
	if w != null:
		_spawn_ring(ctx, w.global_position, 3.0, 18.0, 0.24, "ice")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "ember_gain":
		return value * (2.0 if _timer > 0.0 else 0.70)
	return value
