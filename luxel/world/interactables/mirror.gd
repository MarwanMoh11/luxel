class_name LxMirror
extends LxInteractable
## Brass mirror reflecting Prism bolts off its surface normal.

var normal: Vector2 = Vector2(0.707107, 0.707107)
var rotatable: bool = false
var angle_step_deg: float = 45.0
var double_sided: bool = true
var size: Vector2 = Vector2(16.0, 16.0)
var _flash_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mirror"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	rotatable = bool(props.get("rotatable", false))
	angle_step_deg = float(props.get("angle_step_deg", 45.0))
	double_sided = bool(props.get("double_sided", true))
	if props.has("normal"):
		var n: Vector2 = _parse_vec2(props.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	elif props.has("angle_deg"):
		var rad: float = deg_to_rad(float(props.get("angle_deg", 45.0)))
		normal = Vector2(cos(rad), sin(rad)).normalized()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		if _flash_t <= 0.0:
			queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not rotatable:
		return false
	normal = normal.rotated(deg_to_rad(angle_step_deg)).normalized()
	_emit_sfx("mirror_turn")
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam"]:
		_flash_t = 0.2
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func is_reflective() -> bool:
	return active


func reflect_dir(in_dir: Vector2) -> Vector2:
	if in_dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	var d: Vector2 = in_dir.normalized()
	var n: Vector2 = normal.normalized()
	if d.dot(n) > 0.0:
		if not double_sided:
			return Vector2.ZERO
		n = -n
	return d.bounce(n).normalized()


func save_state() -> Dictionary:
	return {"active": active, "normal": [normal.x, normal.y]}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if d.has("normal"):
		var n: Vector2 = _parse_vec2(d.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = size * 0.5
	draw_rect(Rect2(-half, size), PAL["night"])
	draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["apricot"] if _flash_t > 0.0 else PAL["plum"])
	var tangent: Vector2 = Vector2(-normal.y, normal.x) * (minf(size.x, size.y) * 0.44)
	draw_line(-tangent, tangent, PAL["cream"] if _flash_t > 0.0 else PAL["ice"], 3.0)
	draw_line(Vector2.ZERO, normal * 5.0, PAL["gold"], 1.0)
