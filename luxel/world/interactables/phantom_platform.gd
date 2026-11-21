class_name LxPhantomPlatform
extends LxInteractable
## Hidden bridge/platform that turns solid and visible when illuminated with Lens unlocked.

var revealed: bool = false
var persist_grace: float = 0.25
var size: Vector2 = Vector2(32.0, 16.0)
var _reveal_left: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "phantom_platform"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	persist_grace = maxf(0.05, float(props.get("persist_grace", 0.25)))
	revealed = bool(props.get("revealed", false))
	queue_redraw()


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	var has_lens: bool = source == "lens" or Lx.state == null or Lx.state.has_move("lens")
	if not has_lens:
		return
	var was: bool = revealed
	revealed = true
	_reveal_left = persist_grace
	if not was:
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if revealed and _reveal_left > 0.0:
		_reveal_left -= dt
		if _reveal_left <= 0.0:
			revealed = false
			queue_redraw()


func is_platform_solid() -> bool:
	return active and revealed


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if not revealed:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 32.0, 0.55)


func save_state() -> Dictionary:
	return {"active": active, "revealed": revealed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	revealed = bool(d.get("revealed", revealed))
	if revealed:
		_reveal_left = persist_grace
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = size * 0.5
	if revealed:
		draw_rect(Rect2(-half, size), PAL["deep"])
		draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["sky"])
		draw_rect(Rect2(-half + Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), PAL["ice"])
	else:
		draw_line(-half, Vector2(-half.x + 5.0, -half.y), PAL["deep"], 1.0)
		draw_line(Vector2(half.x - 5.0, -half.y), Vector2(half.x, -half.y), PAL["deep"], 1.0)
		draw_line(Vector2(-half.x, half.y), Vector2(-half.x + 5.0, half.y), PAL["deep"], 1.0)
		draw_line(Vector2(half.x - 5.0, half.y), half, PAL["deep"], 1.0)
