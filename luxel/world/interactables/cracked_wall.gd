class_name LxCrackedWall
extends LxInteractable
## Fractured stone barrier broken by Beam or Sunflare.

var broken: bool = false
var size: Vector2 = Vector2(16.0, 16.0)


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "cracked_wall"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	broken = bool(props.get("broken", false))
	active = not broken
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or broken:
		return false
	if hit.source in ["beam", "sunflare"]:
		broken = true
		active = false
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.16)
		_emit_sfx("stone_break")
		_emit_save("cracked_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active and not broken


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "broken": broken}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	broken = bool(d.get("broken", broken))
	active = not broken
	queue_redraw()


func _draw() -> void:
	if broken or not active:
		return
	var half: Vector2 = size * 0.5
	draw_rect(Rect2(-half, size), PAL["night"])
	draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["stone"])
	draw_line(-half + Vector2(3.0, 2.0), Vector2(1.0, 1.0), PAL["dusk"], 1.0)
	draw_line(Vector2(1.0, 1.0), half - Vector2(3.0, 2.0), PAL["night"], 1.0)
	draw_line(Vector2(1.0, 1.0), Vector2(-3.0, half.y - 2.0), PAL["dusk"], 1.0)
