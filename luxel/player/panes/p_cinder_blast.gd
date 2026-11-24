class_name LxPaneCinderBlast
extends LxPane
## Ashen Kiln (Dungeon): Recalling a hung lantern detonates a 40 px cinder blast; shorter hang time.


func _init() -> void:
	id = "cinder_blast"
	island_id = 6
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_CINDER_BLAST_NAME"
	desc_key = "PANE_CINDER_BLAST_DESC"
	tint_key = "coral"


func on_recall(ctx: Dictionary) -> void:
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_ring(ctx, pos, 4.0, 40.0, 0.26, "coral")
	_spawn_sparks(ctx, pos, Vector2.UP, 9, "apricot")
	_pulse_aoe(ctx, pos, 40.0, 1.35, 1.5, true, LxHit.SOURCE_RECALL)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "hang_time":
		return value - 1.5
	return value
