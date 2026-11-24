class_name LxPaneSlagCoat
extends LxPane
## Ashen Kiln (Trial): Entering a room coats Wick in a 1-hit ash spark ward; slower walk speed.


func _init() -> void:
	id = "slag_coat"
	island_id = 6
	source_kind = "trial"
	lead_cost = 2
	name_key = "PANE_SLAG_COAT_NAME"
	desc_key = "PANE_SLAG_COAT_DESC"
	tint_key = "apricot"


func on_room_enter(ctx: Dictionary) -> void:
	super.on_room_enter(ctx)
	_active_flag = true
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.set_ash_ward(true)


func on_hurt(ctx: Dictionary) -> void:
	if not _active_flag:
		return
	_active_flag = false
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.consume_ash_ward()
	var st: LxGameState = ctx.get("state", Lx.state) as LxGameState
	var dmg: float = float(ctx.get("amount", 0.0))
	if st != null and dmg > 0.0 and st.hearts > 0.0:
		st.hearts = minf(float(st.max_hearts), st.hearts + minf(dmg, 0.5))
	var w: Node2D = _wick(ctx)
	if w != null:
		_spawn_ring(ctx, w.global_position, 3.0, 22.0, 0.24, "apricot")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "move_speed":
		return value - 10.0
	return value
