class_name LxBramble
extends LxInteractable
## Dense thorn barrier burned away by Beam.

var burned: bool = false
var size: Vector2 = Vector2(16.0, 16.0)


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "bramble"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	burned = bool(props.get("burned", false))
	active = not burned
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or burned:
		return false
	if hit.source == "beam":
		burned = true
		active = false
		_emit_sfx("bramble_burn")
		_emit_save("bramble_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active and not burned


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "burned": burned}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	burned = bool(d.get("burned", burned))
	active = not burned
	queue_redraw()


func _draw() -> void:
	if burned or not active:
		return
	var half: Vector2 = size * 0.5
	draw_rect(Rect2(-half, size), PAL["night"])
	draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["plum"])
	draw_line(-half + Vector2(2.0, 2.0), half - Vector2(2.0, 2.0), PAL["jade"], 1.5)
	draw_line(Vector2(half.x - 2.0, -half.y + 2.0), Vector2(-half.x + 2.0, half.y - 2.0), PAL["jade"], 1.5)
	draw_circle(Vector2(-2.0, -2.0), 1.5, PAL["coral"])
	draw_circle(Vector2(3.0, 2.0), 1.5, PAL["coral"])
