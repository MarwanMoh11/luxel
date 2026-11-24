class_name LxPaneCanopyDew
extends LxPane
## Thornwood (Secret): Every 3 kills in one room blooms +0.5 heart; slower bolt fire rate.


func _init() -> void:
	id = "canopy_dew"
	island_id = 3
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_CANOPY_DEW_NAME"
	desc_key = "PANE_CANOPY_DEW_DESC"
	tint_key = "lime"


func on_kill(ctx: Dictionary) -> void:
	_room_counter += 1
	if _room_counter % 3 != 0:
		return
	var st: LxGameState = ctx.get("state", Lx.state) as LxGameState
	if st != null and st.hearts < float(st.max_hearts):
		st.hearts = minf(float(st.max_hearts), st.hearts + 0.5)
		if Lx.events != null:
			Lx.events.player_healed.emit(st.hearts)
	var w: Node2D = _wick(ctx)
	if w != null:
		_spawn_ring(ctx, w.global_position, 2.0, 16.0, 0.26, "lime")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_cooldown":
		return value + 0.05
	return value
