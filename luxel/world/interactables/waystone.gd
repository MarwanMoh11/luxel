class_name LxWaystone
extends LxInteractable
## Restores full hearts, sets the respawn point, unlocks fast travel, and requests an autosave.

var lit: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "waystone"
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.lit_waystones.has(id):
		lit = true
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	var first_time: bool = not lit
	lit = true
	if Lx.state != null:
		if not id.is_empty() and not Lx.state.lit_waystones.has(id):
			Lx.state.lit_waystones.append(id)
		Lx.state.heal_full()
		Lx.state.last_waystone_island = island_id
		Lx.state.last_waystone_id = id
		Lx.state.spawn_pos = pos + Vector2(0.0, 14.0)
	if Lx.events != null:
		Lx.events.waystone_lit.emit(island_id, id)
	_emit_sfx("waystone_lit" if first_time else "waystone_rest")
	_emit_save("waystone_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if lit:
		return Vector4(pos.x, pos.y - 10.0, 58.0, 1.05)
	return Vector4(pos.x, pos.y - 8.0, 26.0, 0.45)


func get_interact_prompt() -> String:
	return "PROMPT_WAYSTONE_REST" if lit else "PROMPT_WAYSTONE_LIGHT"


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	if Lx.state != null and Lx.state.lit_waystones.has(id):
		lit = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-6.0, -3.0, 12.0, 6.0), PAL["night"])
	draw_rect(Rect2(-5.0, -14.0, 10.0, 13.0), PAL["dusk"])
	draw_rect(Rect2(-4.0, -13.0, 8.0, 11.0), PAL["stone"])
	if lit:
		draw_rect(Rect2(-2.0, -11.0, 4.0, 7.0), PAL["sky"])
		draw_rect(Rect2(-1.0, -10.0, 2.0, 5.0), PAL["ice"])
		draw_circle(Vector2(0.0, -15.0), 2.5, PAL["gold"])
	else:
		draw_rect(Rect2(-2.0, -11.0, 4.0, 7.0), PAL["deep"])
