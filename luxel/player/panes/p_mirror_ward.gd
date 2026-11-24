class_name LxPaneMirrorWard
extends LxPane
## Moon Shoals (Secret): Getting hurt blinks Wick to the hung lantern if out and recalls it.


func _init() -> void:
	id = "mirror_ward"
	island_id = 7
	source_kind = "secret"
	lead_cost = 2
	name_key = "PANE_MIRROR_WARD_NAME"
	desc_key = "PANE_MIRROR_WARD_DESC"
	tint_key = "ice"


func on_hurt(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	if w == null or not (w.get("lantern") is Object):
		return
	var lan: Object = w.get("lantern") as Object
	if lan.has_method("is_lure_active") and bool(lan.call("is_lure_active")):
		var dest: Vector2 = lan.get("pos") as Vector2
		_spawn_ring(ctx, w.global_position, 2.0, 14.0, 0.20, "ice")
		w.global_position = dest
		w.set("knock", Vector2.ZERO)
		if lan.has_method("catch_by_wick"):
			lan.call("catch_by_wick", w)
		_spawn_ring(ctx, dest, 3.0, 18.0, 0.24, "cream")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "throw_damage":
		return value - 0.35
	return value
