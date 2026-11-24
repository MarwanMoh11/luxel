class_name LxPaneZenithLens
extends LxPane
## Starfall (Quest): At full hearts, every 3rd bolt becomes a piercing lance; slightly slower cadence.


func _init() -> void:
	id = "zenith_lens"
	island_id = 5
	source_kind = "quest"
	lead_cost = 2
	name_key = "PANE_ZENITH_LENS_NAME"
	desc_key = "PANE_ZENITH_LENS_DESC"
	tint_key = "cream"


func on_bolt_fired(ctx: Dictionary) -> void:
	var st: LxGameState = ctx.get("state", Lx.state) as LxGameState
	if st != null and st.hearts < float(st.max_hearts) - 0.01:
		return
	_room_counter += 1
	if _room_counter % 3 != 0:
		return
	var bolt: Variant = ctx.get("bolt", null)
	if bolt is Object:
		(bolt as Object).set("is_pierce", true)
		(bolt as Object).set("cracks_armour", true)
		(bolt as Object).set("speed", float((bolt as Object).get("speed")) + 85.0)
		(bolt as Object).set("damage", float((bolt as Object).get("damage")) * 1.55)
		(bolt as Object).set("biome_tint", "cream")
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_sparks(ctx, pos, Vector2.RIGHT, 4, "cream")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_cooldown":
		return value + 0.035
	return value
