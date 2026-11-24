class_name LxPaneTollEcho
extends LxPane
## Bell Isle (Quest): Perfect dodge leaves a ringing brass decoy that pulses nearby foes.


func _init() -> void:
	id = "toll_echo"
	island_id = 1
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_TOLL_ECHO_NAME"
	desc_key = "PANE_TOLL_ECHO_DESC"
	tint_key = "gold"


func on_perfect_dodge(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_decoy(pos, 2.8, "gold", "chime")
	_spawn_ring(ctx, pos, 3.0, 20.0, 0.24, "cream")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "dash_cooldown":
		return value + 0.08
	return value
