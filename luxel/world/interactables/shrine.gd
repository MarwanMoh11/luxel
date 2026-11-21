class_name LxShrine
extends LxInteractable
## Move Shrine: unlocks props.move_id, emits shrine_claimed + save_requested.

var claimed: bool = false
var move_id: String = ""


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "shrine"
	move_id = str(props.get("move_id", ""))
	claimed = bool(props.get("claimed", false))
	if Lx.state != null:
		if Lx.state.claimed_shrines.has(id) or (not move_id.is_empty() and Lx.state.has_move(move_id)):
			claimed = true
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	claimed = true
	if Lx.state != null:
		if not move_id.is_empty():
			Lx.state.unlock_move(move_id)
		if not id.is_empty() and not Lx.state.claimed_shrines.has(id):
			Lx.state.claimed_shrines.append(id)
	if Lx.events != null:
		Lx.events.shrine_claimed.emit(id, move_id)
		Lx.events.shake_requested.emit(0.14)
	_emit_sfx("shrine_claimed")
	_emit_save("shrine_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not claimed:
		return Vector4(pos.x, pos.y - 10.0, 68.0, 1.15)
	return Vector4(pos.x, pos.y - 8.0, 42.0, 0.72)


func get_interact_prompt() -> String:
	return "" if claimed else "PROMPT_CLAIM_SHRINE"


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed))
	if Lx.state != null and Lx.state.claimed_shrines.has(id):
		claimed = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-8.0, -3.0, 16.0, 7.0), PAL["night"])
	draw_rect(Rect2(-6.0, -12.0, 12.0, 11.0), PAL["mauve"])
	draw_rect(Rect2(-5.0, -11.0, 10.0, 9.0), PAL["stone"])
	if not claimed:
		draw_circle(Vector2(0.0, -14.0), 4.5, PAL["apricot"])
		draw_circle(Vector2(0.0, -14.0), 2.5, PAL["gold"])
		draw_circle(Vector2(0.0, -14.0), 1.2, PAL["cream"])
	else:
		draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), PAL["dusk"])
