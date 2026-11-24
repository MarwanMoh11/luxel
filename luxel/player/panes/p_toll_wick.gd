class_name LxPaneTollWick
extends LxPane
## Long Night (Dungeon): At 2 hearts or fewer, bolts burn fierce and pierce; dimmer light always.


func _init() -> void:
	id = "toll_wick"
	island_id = 8
	source_kind = "dungeon"
	lead_cost = 1
	name_key = "PANE_TOLL_WICK_NAME"
	desc_key = "PANE_TOLL_WICK_DESC"
	tint_key = "rose"


func on_bolt_fired(ctx: Dictionary) -> void:
	var st: LxGameState = ctx.get("state", Lx.state) as LxGameState
	if st != null and st.hearts <= 2.0:
		var bolt: Variant = ctx.get("bolt", null)
		if bolt is Object:
			(bolt as Object).set("is_pierce", true)
			(bolt as Object).set("biome_tint", "rose")


func modify_stat(stat_name: String, value: float, ctx: Dictionary = {}) -> float:
	var st: LxGameState = ctx.get("state", Lx.state) as LxGameState
	if stat_name == "bolt_damage" and st != null and st.hearts <= 2.0:
		return value * 1.45
	if stat_name == "light_radius":
		return value - 14.0
	return value
