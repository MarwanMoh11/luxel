class_name LxPaneNullWell
extends LxPane
## Starfall (Secret): Hung lantern gently draws loose moths and collectibles toward it; dimmer radius.


func _init() -> void:
	id = "null_well"
	island_id = 5
	source_kind = "secret"
	lead_cost = 3
	name_key = "PANE_NULL_WELL_NAME"
	desc_key = "PANE_NULL_WELL_DESC"
	tint_key = "deep"


func tick(dt: float, ctx: Dictionary) -> void:
	super.tick(dt, ctx)
	var w: Node2D = _wick(ctx)
	var wr: Node = _world(ctx)
	if w == null or wr == null or not (w.get("lantern") is Object):
		return
	var lan: Object = w.get("lantern") as Object
	if not lan.has_method("is_lure_active") or not bool(lan.call("is_lure_active")):
		return
	var lpos: Vector2 = lan.get("pos") as Vector2
	if wr.has_method("get_interactables"):
		for it_v: Variant in (wr.call("get_interactables") as Array):
			if is_instance_valid(it_v) and it_v is LxInteractable and str((it_v as LxInteractable).kind) == "moth":
				var m: LxInteractable = it_v as LxInteractable
				if m.active and m.pos.distance_to(lpos) <= 92.0:
					m.pos = m.pos.move_toward(lpos, 32.0 * dt)
					m.position = m.pos.round()


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "light_radius":
		return value - 18.0
	if stat_name == "hang_time":
		return value + 1.5
	return value
