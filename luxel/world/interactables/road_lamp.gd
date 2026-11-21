class_name LxRoadLamp
extends LxInteractable
## Road lantern post that ignites when struck or when Wick's lantern passes near it.

var lit: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "road_lamp"
	lit = bool(props.get("lit", false))
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or lit:
		return false
	return _ignite()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or lit:
		return false
	if hit.source in ["bolt", "prism_bolt", "throw", "recall", "zip", "beam", "sunflare"]:
		return _ignite()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or lit or light_radius < 20.0:
		return
	if source in ["wick_lantern", "thrown_lantern", "lantern", "sunflare", "beam"]:
		_ignite()


func _ignite() -> bool:
	lit = true
	_emit_sfx("lamp_lit")
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not lit:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 10.0, 54.0, 0.95)


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2.0, -14.0, 4.0, 16.0), PAL["night"])
	draw_rect(Rect2(-1.0, -13.0, 2.0, 14.0), PAL["plum"])
	draw_rect(Rect2(-4.0, -17.0, 8.0, 5.0), PAL["dusk"])
	if lit:
		draw_rect(Rect2(-3.0, -16.0, 6.0, 3.0), PAL["gold"])
		draw_rect(Rect2(-1.0, -15.0, 2.0, 2.0), PAL["cream"])
	else:
		draw_rect(Rect2(-3.0, -16.0, 6.0, 3.0), PAL["pine"])
