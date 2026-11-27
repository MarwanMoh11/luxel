class_name LxPaneLastGlass
extends LxPane
## Long Night (Secret): While ember gauge is empty, bolts crack heavy; ember charges half as fast.


func _init() -> void:
	id = "last_glass"
	island_id = 8
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_LAST_GLASS_NAME"
	desc_key = "PANE_LAST_GLASS_DESC"
	tint_key = "rose"


func on_bolt_fired(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	if w != null and w.get("ember") != null and float(w.get("ember")) <= 1.0:
		var bolt: Variant = ctx.get("bolt", null)
		if bolt is Object:
			(bolt as Object).set("cracks_armour", true)
			(bolt as Object).set("biome_tint", "gold")


func modify_stat(stat_name: String, value: float, ctx: Dictionary = {}) -> float:
	var w: Node2D = _wick(ctx)
	if stat_name == "bolt_damage" and w != null and w.get("ember") != null and float(w.get("ember")) <= 1.0:
		return value * 1.40
	if stat_name == "ember_gain":
		return value * 0.50
	return value
