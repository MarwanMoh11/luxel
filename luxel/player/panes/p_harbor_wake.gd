class_name LxPaneHarborWake
extends LxPane
## Tidewater (Quest): Dash leaves a slowing sea-foam wake behind Wick; longer dash cooldown.


func _init() -> void:
	id = "harbor_wake"
	island_id = 2
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_HARBOR_WAKE_NAME"
	desc_key = "PANE_HARBOR_WAKE_DESC"
	tint_key = "sky"


func on_dash(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_pool(pos, 18.0, 2.6, 0.25, "ice", "foam")
	_spawn_sparks(ctx, pos, Vector2.UP, 5, "ice")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "dash_cooldown":
		return value + 0.12
	return value
