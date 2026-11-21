class_name LxWickKey
extends LxInteractable
## Dungeon key pickup: adds a small wick_key or boss keepers_flame into Lx.state.

var collected: bool = false
var key_kind: String = "wick_key"
var dungeon_id: String = ""


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "wick_key"))
	key_kind = str(props.get("key_kind", "keepers_flame" if raw_kind == "keepers_flame" else "wick_key"))
	kind = "wick_key"
	dungeon_id = str(props.get("dungeon_id", "island_%d" % island_id))
	if dungeon_id.is_empty():
		dungeon_id = "island_%d" % island_id
	collected = bool(props.get("collected", false))
	active = not collected
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or collected:
		return false
	collected = true
	active = false
	if Lx.state != null:
		Lx.state.add_key(dungeon_id, key_kind, 1)
		var flag_name: String = str(props.get("flag_id", props.get("sets_flag", "")))
		if not flag_name.is_empty():
			Lx.state.story_flags[flag_name] = true
	_emit_sfx("key_pickup")
	_emit_save("key_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if collected or not active:
		return Vector4.ZERO
	var r: float = 42.0 if key_kind == "keepers_flame" else 30.0
	return Vector4(pos.x, pos.y - 4.0, r, 0.85)


func get_interact_prompt() -> String:
	return "" if collected else "PROMPT_TAKE_KEY"


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected))
	active = not collected
	queue_redraw()


func _draw() -> void:
	if collected or not active:
		return
	var col: Color = PAL["coral"] if key_kind == "keepers_flame" else PAL["gold"]
	var core: Color = PAL["cream"]
	draw_circle(Vector2(0.0, -3.0), 4.5, PAL["night"])
	draw_circle(Vector2(0.0, -3.0), 3.5, col)
	draw_circle(Vector2(0.0, -3.0), 1.5, core)
	draw_rect(Rect2(-1.0, 0.0, 2.0, 6.0), col)
	draw_rect(Rect2(1.0, 3.0, 2.0, 2.0), col)
