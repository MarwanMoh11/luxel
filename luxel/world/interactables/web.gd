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
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var hub: Vector2 = Vector2(floorf(x0 + w * 0.48), floorf(y0 + h * 0.46))
	var anchors: Array[Vector2] = [
		Vector2(x0, y0), Vector2(floorf(x0 + w * 0.5), y0), Vector2(x0 + w - 1.0, y0),
		Vector2(x0 + w - 1.0, floorf(y0 + h * 0.5)), Vector2(x0 + w - 1.0, y0 + h - 1.0),
		Vector2(floorf(x0 + w * 0.5), y0 + h - 1.0), Vector2(x0, y0 + h - 1.0),
		Vector2(x0, floorf(y0 + h * 0.5)),
	]
	for a: Vector2 in anchors:
		var ax: float = clampf(a.x - 1.0, x0, x0 + w - 2.0)
		var ay: float = clampf(a.y - 1.0, y0, y0 + h - 2.0)
		draw_rect(Rect2(ax, ay, 2.0, 2.0), PAL["night"])
		draw_rect(Rect2(ax, ay, 1.0, 1.0), PAL["dusk"])
	for i: int in range(anchors.size()):
		var ap: Vector2 = anchors[i]
		draw_line(hub + Vector2(0.0, 1.0), ap + Vector2(0.0, 1.0), PAL["dusk"], 1.0)
		draw_line(hub, ap, PAL["ice"] if i % 2 == 1 else PAL["stone"], 1.0)
	var rings: Array[float] = [0.34, 0.64, 0.88]
	var ring_cols: Array[Color] = [PAL["cream"] as Color, PAL["ice"] as Color, PAL["stone"] as Color]
	for ri: int in range(rings.size()):
		var t: float = rings[ri]
		var sag: float = t * 0.84
		var col: Color = ring_cols[ri]
		for i: int in range(anchors.size()):
			var p1: Vector2 = hub.lerp(anchors[i], t).round()
			var p2: Vector2 = hub.lerp(anchors[(i + 1) % anchors.size()], t).round()
			var mid: Vector2 = hub.lerp((anchors[i] + anchors[(i + 1) % anchors.size()]) * 0.5, sag).round()
			draw_line(p1, mid, col, 1.0)
			draw_line(mid, p2, col, 1.0)
			if ri == 1 and (i == 0 or i == 1 or i == 7):
				draw_rect(Rect2(p1, Vector2(1.0, 1.0)), PAL["cream"])
	draw_rect(Rect2(hub - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PAL["ice"])
	draw_rect(Rect2(hub, Vector2(1.0, 1.0)), PAL["cream"])
