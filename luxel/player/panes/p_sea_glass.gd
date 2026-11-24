class_name LxPaneSeaGlass
extends LxPane
## Tidewater (Trial): Every bolt gains an extra prism bounce; trade-off: shorter base range.


func _init() -> void:
	id = "sea_glass"
	island_id = 2
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_SEA_GLASS_NAME"
	desc_key = "PANE_SEA_GLASS_DESC"
	tint_key = "ice"


func on_bolt_fired(ctx: Dictionary) -> void:
	var bolt: Variant = ctx.get("bolt", null)
	if bolt is Object:
		var bl: int = int((bolt as Object).get("bounces_left"))
		(bolt as Object).set("bounces_left", bl + 1)
		(bolt as Object).set("biome_tint", "ice")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_range":
		return value - 24.0
	return value
