class_name LxPaneEmberSeed
extends LxPane
## Thornwood (Dungeon): Bolt hits plant short-lived burning ember pools; slower bolt speed.


func _init() -> void:
	id = "ember_seed"
	island_id = 3
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_EMBER_SEED_NAME"
	desc_key = "PANE_EMBER_SEED_DESC"
	tint_key = "lime"


func on_bolt_hit(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_pool(pos, 13.0, 2.2, 0.45, "coral", "ember")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_speed":
		return value - 65.0
	return value
