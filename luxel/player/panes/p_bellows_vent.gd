class_name LxPaneBellowsVent
extends LxPane
## Ashen Kiln (Quest): Dash blasts a fiery ember cone behind Wick; raises bolt recoil.


func _init() -> void:
	id = "bellows_vent"
	island_id = 6
	source_kind = "quest"
	lead_cost = 1
	name_key = "PANE_BELLOWS_VENT_NAME"
	desc_key = "PANE_BELLOWS_VENT_DESC"
	tint_key = "coral"


func on_dash(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	var dir: Vector2 = ctx.get("dir", Vector2.RIGHT) as Vector2
	var back: Vector2 = pos - dir.normalized() * 16.0
	_spawn_sparks(ctx, pos, -dir, 8, "coral")
	_pulse_aoe(ctx, back, 24.0, 0.75, 0.5, false, LxHit.SOURCE_DASH)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "recoil":
		return value + 35.0
	return value
