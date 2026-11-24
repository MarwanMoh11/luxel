class_name LxPaneVineSnare
extends LxPane
## Thornwood (Quest): Thrown lantern roots nearby enemies with vines; slower throw speed.


func _init() -> void:
	id = "vine_snare"
	island_id = 3
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_VINE_SNARE_NAME"
	desc_key = "PANE_VINE_SNARE_DESC"
	tint_key = "jade"


func on_throw(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	var dir: Vector2 = ctx.get("dir", Vector2.RIGHT) as Vector2
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_pool(pos + dir * 32.0, 20.0, 3.0, 0.15, "jade", "vine")
	_spawn_sparks(ctx, pos, dir, 5, "lime")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "throw_speed":
		return value - 70.0
	return value
