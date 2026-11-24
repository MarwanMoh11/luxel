class_name LxPaneOrbitShard
extends LxPane
## Starfall (Dungeon): Kills spawn an orbiting star mote for 6 s; smaller lantern light radius.


func _init() -> void:
	id = "orbit_shard"
	island_id = 5
	source_kind = "dungeon"
	lead_cost = 2
	name_key = "PANE_ORBIT_SHARD_NAME"
	desc_key = "PANE_ORBIT_SHARD_DESC"
	tint_key = "gold"


func on_kill(ctx: Dictionary) -> void:
	var fx: LxPaneFx = _fx(ctx)
	if fx != null:
		fx.add_orbital(6.0, "gold")
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO) as Vector2
	_spawn_sparks(ctx, pos, Vector2.UP, 5, "sky")


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "light_radius":
		return value - 14.0
	return value
