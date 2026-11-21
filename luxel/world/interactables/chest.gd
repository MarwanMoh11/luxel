class_name LxChest
extends LxInteractable
## Reward chest granting light shards, an ember piece, or a dungeon key.

var opened: bool = false
var reward_kind: String = "shards"
var amount: int = 15
var dungeon_id: String = ""


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "chest"
	reward_kind = str(props.get("reward_kind", "shards"))
	amount = maxi(1, int(props.get("amount", 15)))
	dungeon_id = str(props.get("dungeon_id", region_id))
	opened = bool(props.get("opened", false))
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	opened = true
	if Lx.state != null:
		match reward_kind:
			"ember_piece":
				Lx.state.add_ember_piece()
			"wick_key", "keepers_flame":
				Lx.state.add_key(dungeon_id, reward_kind, amount)
			_:
				Lx.state.add_shards(amount)
	_emit_sfx("chest_open")
	_emit_save("chest_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if opened:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 34.0, 0.65)


func get_interact_prompt() -> String:
	return "" if opened else "PROMPT_OPEN_CHEST"


func save_state() -> Dictionary:
	return {"active": active, "opened": opened}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-7.0, -6.0, 14.0, 10.0), PAL["night"])
	draw_rect(Rect2(-6.0, -5.0, 12.0, 8.0), PAL["wine"])
	if opened:
		draw_rect(Rect2(-6.0, -8.0, 12.0, 3.0), PAL["plum"])
		draw_rect(Rect2(-5.0, -4.0, 10.0, 3.0), PAL["dusk"])
	else:
		draw_rect(Rect2(-6.0, -5.0, 12.0, 2.0), PAL["gold"])
		draw_rect(Rect2(-2.0, -3.0, 4.0, 3.0), PAL["cream"])
