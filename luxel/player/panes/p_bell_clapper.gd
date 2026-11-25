class_name LxPaneBellClapper
extends LxPane
## Bell Isle (Dungeon): Recall rings a 36 px chime shockwave (0.9 dmg, cracks armour, rings bells);
## trade-off: shorter throw range (-24 px).

const CHIME_RADIUS: float = 36.0


func _init() -> void:
	id = "bell_clapper"
	island_id = 1
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_BELL_CLAPPER_NAME"
	desc_key = "PANE_BELL_CLAPPER_DESC"
	tint_key = "gold"


func on_recall(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_ring(ctx, pos, 4.0, CHIME_RADIUS, 0.28, "gold")
	_spawn_sparks(ctx, pos, Vector2.UP, 6, "cream")
	_pulse_aoe(ctx, pos, CHIME_RADIUS, 0.9, 1.5, true, LxHit.SOURCE_RECALL)
	_ring_nearby_bells(ctx, pos)


func _ring_nearby_bells(ctx: Dictionary, center: Vector2) -> void:
	var wr: Node = _world(ctx)
	var w: Node2D = _wick(ctx)
	if wr == null or not wr.has_method("get_interactables"):
		return
	var inters: Variant = wr.call("get_interactables")
	if not (inters is Array):
		return
	for it_v: Variant in (inters as Array):
		if not is_instance_valid(it_v) or not (it_v is Object):
			continue
		var item: Object = it_v as Object
		if str(item.get("kind")) != "bell":
			continue
		if item.get("active") is bool and not bool(item.get("active")):
			continue
		var ipos: Vector2 = item.get("pos") as Vector2 if item.get("pos") is Vector2 else (
			(item as Node2D).global_position if item is Node2D else Vector2.INF
		)
		var irad: float = float(item.get("radius")) if (item.get("radius") is float or item.get("radius") is int) else 12.0
		if ipos.is_finite() and ipos.distance_to(center) <= CHIME_RADIUS + irad:
			var bdir: Vector2 = (ipos - center).normalized() if ipos.distance_to(center) > 0.5 else Vector2.RIGHT
			var hit: LxHit = LxHit.make(LxHit.SOURCE_RECALL, 0.9, bdir, center, 1.5, true, false, w, false)
			if item.has_method("on_hit"):
				item.call("on_hit", hit)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "throw_range":
		return value - 24.0
	return value
