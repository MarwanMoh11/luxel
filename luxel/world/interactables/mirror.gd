class_name LxMirror
extends LxInteractable
## Brass mirror reflecting Prism bolts off its surface normal.

var normal: Vector2 = Vector2(0.707107, 0.707107)
var rotatable: bool = false
var angle_step_deg: float = 45.0
var double_sided: bool = true
var size: Vector2 = Vector2(16.0, 16.0)
var _flash_t: float = 0.0
var _turn_t: float = 0.0
var _glint_stage: int = 0


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
	_turn_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _turn_t > 0.0:
		_turn_t = maxf(0.0, _turn_t - dt)
		dirty = true
	if active:
		var st: int = int(floorf(_clock * 1.6 + absf(pos.x * 0.03))) % 6
		if st != _glint_stage:
			_glint_stage = st
			dirty = true
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not rotatable:
		return false
	normal = normal.rotated(deg_to_rad(angle_step_deg)).normalized()
	_turn_t = 0.18
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


func get_interact_prompt() -> String:
	return "PROMPT_TURN_MIRROR" if (active and rotatable) else ""


func get_light_pool() -> Vector4:
	if _flash_t > 0.0:
		return Vector4(pos.x, pos.y, 52.0, 1.1)
	return Vector4.ZERO


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
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var lit: bool = _flash_t > 0.0
	draw_rect(Rect2(x0 + 1.0, y0 + 2.0, w - 1.0, h - 1.0), PAL["void"])
	if rotatable:
		var cx: float = floorf(x0 + w * 0.5)
		var cy: float = floorf(y0 + h * 0.5)
		var teeth: Array[Vector2] = [
			Vector2(cx - 1.0, y0 - 1.0), Vector2(cx - 1.0, y0 + h),
			Vector2(x0 - 1.0, cy - 1.0), Vector2(x0 + w, cy - 1.0),
			Vector2(x0, y0), Vector2(x0 + w - 2.0, y0),
			Vector2(x0, y0 + h - 2.0), Vector2(x0 + w - 2.0, y0 + h - 2.0),
		]
		for tp: Vector2 in teeth:
			draw_rect(Rect2(tp, Vector2(2.0, 2.0)), PAL["night"])
			draw_rect(Rect2(tp, Vector2(1.0, 1.0)), PAL["gold"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), PAL["dusk"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["stone"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 1.0, h - 4.0), PAL["mauve"])
	draw_rect(Rect2(x0 + 3.0, y0 + 3.0, w - 6.0, h - 6.0), PAL["apricot"] if lit else PAL["night"])
	draw_rect(Rect2(x0 + 4.0, y0 + 4.0, maxf(2.0, w - 8.0), maxf(2.0, h - 8.0)), PAL["dusk"])
	var rivets: Array[Vector2] = [
		Vector2(x0 + 2.0, y0 + 2.0), Vector2(x0 + w - 4.0, y0 + 2.0),
		Vector2(x0 + 2.0, y0 + h - 4.0), Vector2(x0 + w - 4.0, y0 + h - 4.0),
	]
	for rv: Vector2 in rivets:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), PAL["apricot"])
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), PAL["gold"])
	var span: float = floorf(minf(w, h) * 0.44)
	var tang: Vector2 = Vector2(-normal.y, normal.x) * span
	var p1: Vector2 = (-tang).round()
	var p2: Vector2 = tang.round()
	var back: Vector2 = (-normal * 1.5).round()
	var front: Vector2 = (normal * 1.0).round()
	draw_line(p1 + back, p2 + back, PAL["void"], 4.0)
	draw_line(p1 + back, p2 + back, PAL["apricot"], 2.0)
	draw_line(p1, p2, PAL["apricot"] if lit else PAL["deep"], 4.0)
	draw_line(p1, p2, PAL["gold"] if lit else PAL["blue"], 3.0)
	draw_line(p1 + front, p2 + front, PAL["cream"] if lit else PAL["sky"], 2.0)
	var gl_a: Vector2 = (-tang * 0.45 + front).round()
	var gl_b: Vector2 = (tang * 0.35 + front).round()
	draw_line(gl_a, gl_b, PAL["cream"] if lit else PAL["ice"], 1.0)
	draw_rect(Rect2(gl_a, Vector2(1.0, 1.0)), PAL["cream"])
	var fin_tip: Vector2 = (normal * 5.0).round()
	draw_line(front, fin_tip, PAL["night"], 3.0)
	draw_line(front, fin_tip, PAL["apricot"], 1.0)
	draw_rect(Rect2(fin_tip, Vector2(1.0, 1.0)), PAL["cream"] if lit else PAL["gold"])
	# Subtle optical sightline tick so players read the reflection angle at a glance.
	var sight_a: Vector2 = (normal * 8.0).round()
	var sight_b: Vector2 = (normal * 10.0).round()
	draw_rect(Rect2(sight_a, Vector2.ONE), PAL["gold"] if (_turn_t > 0.0 or lit) else PAL["sky"])
	draw_rect(Rect2(sight_b, Vector2.ONE), PAL["cream"] if (_turn_t > 0.0 or lit) else PAL["ice"])
	if not lit and _glint_stage <= 1:
		var gpos: Vector2 = (tang * (-0.35 if _glint_stage == 0 else 0.25) + front).round()
		draw_rect(Rect2(gpos, Vector2.ONE), PAL["cream"])
	if _turn_t > 0.0:
		draw_arc(Vector2.ZERO, roundf(minf(w, h) * 0.52), 0.0, TAU, 16, PAL["gold"], 1.0, false)
	if lit:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"])
		draw_rect(Rect2(0.0, -2.0, 1.0, 5.0), PAL["gold"])
		draw_rect(Rect2(-2.0, 0.0, 5.0, 1.0), PAL["gold"])
