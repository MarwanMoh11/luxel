class_name LxPaneHourglassSand
extends LxPane
## Mirefen (Dungeon): Perfect dodge arms next bolt as a piercing lance; longer base dash cooldown.


func _init() -> void:
	id = "hourglass_sand"
	island_id = 4
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_HOURGLASS_SAND_NAME"
	desc_key = "PANE_HOURGLASS_SAND_DESC"
	tint_key = "gold"


func on_perfect_dodge(ctx: Dictionary) -> void:
	_active_flag = true
	var w: Node2D = _wick(ctx)
	if w != null:
		_spawn_ring(ctx, w.global_position, 2.0, 16.0, 0.20, "gold")


func on_bolt_fired(ctx: Dictionary) -> void:
	if not _active_flag:
		return
	_active_flag = false
	var bolt: Variant = ctx.get("bolt", null)
	if bolt is Object:
		(bolt as Object).set("is_pierce", true)
		(bolt as Object).set("cracks_armour", true)
		(bolt as Object).set("damage", float((bolt as Object).get("damage")) * 1.65)
		(bolt as Object).set("biome_tint", "gold")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "dash_cooldown":
		return value + 0.14
	return value
