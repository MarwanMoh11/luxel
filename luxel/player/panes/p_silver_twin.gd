class_name LxPaneSilverTwin
extends LxPane
## Moon Shoals (Dungeon): Throwing the lantern also fires a manual reverse silver bolt; slower fire.


func _init() -> void:
	id = "silver_twin"
	island_id = 7
	source_kind = "dungeon"
	lead_cost = 3
	name_key = "PANE_SILVER_TWIN_NAME"
	desc_key = "PANE_SILVER_TWIN_DESC"
	tint_key = "ice"


func on_throw(ctx: Dictionary) -> void:
	var w: Node2D = _wick(ctx)
	var pos: Vector2 = ctx.get("pos", w.global_position if w != null else Vector2.ZERO) as Vector2
	var dir: Vector2 = -(ctx.get("dir", Vector2.RIGHT) as Vector2).normalized()
	_spawn_sparks(ctx, pos, dir, 6, "ice")
	if w != null and w.get("bolts") is Array:
		var b := LxMoveBolt.Bolt.new()
		b.dir = dir
		b.pos = pos + dir * 6.0
		b.prev_pos = b.pos
		b.speed = 340.0
		b.max_range = 128.0
		b.damage = 0.85
		b.shield_wear = 0.6
		b.is_prism = true
		b.light_color = LxHit.COLOR_BLUE
		b.biome_tint = "ice"
		(w.get("bolts") as Array).append(b)


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "bolt_cooldown":
		return value + 0.04
	return value
