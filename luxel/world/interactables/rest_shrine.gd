class_name LxRestShrine
extends LxInteractable
## Lamplighter's Rest upgrade shrine: heals Wick and opens the lantern upgrade UI.


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "rest_shrine"
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if Lx.state != null:
		Lx.state.heal_full()
	_emit_sfx("rest_shrine")
	if Lx.ui != null and Lx.ui.has_method("open_rest_shop"):
		Lx.ui.call("open_rest_shop")
	elif Lx.events != null:
		Lx.events.prompt_requested.emit("REST_SHOP_TITLE", "lx_interact", 2.0)
	_emit_save("rest_shrine")
	return true


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 10.0, 74.0, 1.2)


func get_interact_prompt() -> String:
	return "PROMPT_REST_SHRINE"


func _draw() -> void:
	if _draw_prop_sprite("rest_shrine"):
		return
	draw_rect(Rect2(-10.0, -4.0, 20.0, 8.0), PAL["night"])
	draw_rect(Rect2(-9.0, -6.0, 18.0, 8.0), PAL["mauve"])
	draw_rect(Rect2(-6.0, -16.0, 12.0, 12.0), PAL["stone"])
	draw_circle(Vector2(0.0, -12.0), 4.0, PAL["apricot"])
	draw_circle(Vector2(0.0, -12.0), 2.5, PAL["gold"])
	draw_circle(Vector2(0.0, -12.0), 1.2, PAL["cream"])
