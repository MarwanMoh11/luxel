class_name LxPaneVesperChime
extends LxPane
## Bell Isle (Trial): Every 4th bolt rings wide and pierces; trade-off: slower bolt cadence.


func _init() -> void:
	id = "vesper_chime"
	island_id = 1
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_VESPER_CHIME_NAME"
	desc_key = "PANE_VESPER_CHIME_DESC"
	tint_key = "apricot"


func on_bolt_fired(ctx: Dictionary) -> void:
	_room_counter += 1
	if _room_counter % 4 != 0:
		return
	var bolt: Variant = ctx.get("bolt", null)
	if bolt is Object:
		(bolt as Object).set("is_pierce", true)
		(bolt as Object).set("damage", float((bolt as Object).get("damage")) * 1.45)
		(bolt as Object).set("biome_tint", "gold")
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_ring(ctx, pos, 3.0, 16.0, 0.18, "gold")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_cooldown":
		return value + 0.045
	return value
