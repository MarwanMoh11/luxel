class_name LxPaneMoonPhase
extends LxPane
## Moon Shoals (Trial): Bolts alternate long fast silver and short heavy gold; cadence shifts.


func _init() -> void:
	id = "moon_phase"
	island_id = 7
	source_kind = "trial"
	lead_cost = 1
	name_key = "PANE_MOON_PHASE_NAME"
	desc_key = "PANE_MOON_PHASE_DESC"
	tint_key = "ice"


func on_bolt_fired(ctx: Dictionary) -> void:
	_room_counter += 1
	var bolt: Variant = ctx.get("bolt", null)
	if not (bolt is Object):
		return
	var bo: Object = bolt as Object
	var mr_v: Variant = bo.get("max_range")
	var sp_v: Variant = bo.get("speed")
	var dm_v: Variant = bo.get("damage")
	if _room_counter % 2 == 1:
		if mr_v is float or mr_v is int: bo.set("max_range", float(mr_v) + 38.0)
		if sp_v is float or sp_v is int: bo.set("speed", float(sp_v) + 60.0)
		if dm_v is float or dm_v is int: bo.set("damage", float(dm_v) * 0.80)
		bo.set("biome_tint", "ice")
	else:
		if mr_v is float or mr_v is int: bo.set("max_range", maxf(54.0, float(mr_v) - 32.0))
		if dm_v is float or dm_v is int: bo.set("damage", float(dm_v) * 1.40)
		bo.set("biome_tint", "gold")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_cooldown":
		return value + 0.02
	return value
