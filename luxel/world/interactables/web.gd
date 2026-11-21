class_name LxWeb
extends LxInteractable
## Silk web barrier burned away by Beam.

var burned: bool = false
var size: Vector2 = Vector2(24.0, 16.0)


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "web"
	size = _parse_size(props.get("size", [24.0, 16.0]), Vector2(24.0, 16.0))
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
		_emit_sfx("web_burn")
		_notify_linked_targets(true)
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active and not burned


func blocks_sight() -> bool:
	return false


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
	draw_line(-half, half, PAL["stone"], 1.0)
	draw_line(Vector2(half.x, -half.y), Vector2(-half.x, half.y), PAL["stone"], 1.0)
	draw_line(Vector2(0.0, -half.y), Vector2(0.0, half.y), PAL["ice"], 1.0)
	draw_line(Vector2(-half.x, 0.0), Vector2(half.x, 0.0), PAL["ice"], 1.0)
	draw_rect(Rect2(-half * 0.5, half), PAL["cream"], false, 1.0)
