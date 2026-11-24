class_name LxPaneAnvilStrike
extends LxPane
## Ashen Kiln (Secret): Zip impact cracks shields and armour in a wide ring; longer dash cooldown.


func _init() -> void:
	id = "anvil_strike"
	island_id = 6
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_ANVIL_STRIKE_NAME"
	desc_key = "PANE_ANVIL_STRIKE_DESC"
	tint_key = "apricot"


func on_zip(ctx: Dictionary) -> void:
	if str(ctx.get("phase", "arrival")) != "arrival":
		return
	var w: Node2D = _wick(ctx)
	var dest: Vector2 = ctx.get("to_pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	_spawn_ring(ctx, dest, 4.0, 38.0, 0.28, "apricot")
	_spawn_sparks(ctx, dest, Vector2.UP, 10, "gold")
	_pulse_aoe(ctx, dest, 38.0, 0.85, 3.0, true, LxHit.SOURCE_ZIP)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "dash_cooldown":
		return value + 0.16
	return value
