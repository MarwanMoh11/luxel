class_name LxPanePetalMirror
extends LxPane
## Mirefen (Trial): Dash leaves a 2 s petal decoy behind Wick; slightly longer dash cooldown.


func _init() -> void:
	id = "petal_mirror"
	island_id = 4
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_PETAL_MIRROR_NAME"
	desc_key = "PANE_PETAL_MIRROR_DESC"
	tint_key = "rose"


func on_dash(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_decoy(pos, 2.0, "rose", "petal")
	_spawn_sparks(ctx, pos, Vector2.UP, 4, "rose")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "dash_cooldown":
		return value + 0.09
	return value
