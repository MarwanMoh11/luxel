class_name LxBrazier
extends LxInteractable
## Dungeon/overworld brazier lit by thrown lantern, beam, or sunflare; opens linked gates.

var lit: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "brazier"
	lit = bool(props.get("lit", props.get("lit_by_default", false)))
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or lit:
		return false
	if hit.source in ["throw", "recall", "zip", "beam", "sunflare"]:
		return _ignite()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or lit or light_radius <= 0.0:
		return
	if source in ["thrown_lantern", "lantern_hung", "lantern_fly", "lantern_recall", "lantern", "beam", "sunflare"] \
			or source.begins_with("lantern"):
		_ignite()


func interact(_actor: Node = null) -> bool:
	if not active or lit or not bool(props.get("allow_interact", false)):
		return false
	return _ignite()


func _ignite() -> bool:
	lit = true
	_emit_sfx("brazier_lit")
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not lit:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 64.0, 1.15)


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	if lit:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-6.0, -3.0, 12.0, 6.0), PAL["night"])
	draw_rect(Rect2(-5.0, -7.0, 10.0, 6.0), PAL["plum"])
	draw_rect(Rect2(-6.0, -9.0, 12.0, 3.0), PAL["mauve"])
	if lit:
		draw_circle(Vector2(0.0, -11.0), 4.0, PAL["coral"])
		draw_circle(Vector2(0.0, -12.0), 2.5, PAL["gold"])
		draw_circle(Vector2(0.0, -12.0), 1.2, PAL["cream"])
	else:
		draw_rect(Rect2(-3.0, -9.0, 6.0, 2.0), PAL["dusk"])
