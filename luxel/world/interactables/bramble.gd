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
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var cols: int = maxi(2, int(roundf(w / 6.0)))
	var rows: int = maxi(2, int(roundf(h / 6.0)))
	var seed_n: int = int(absf(pos.x * 13.0 + pos.y * 7.0))
	for r: int in range(rows):
		for c: int in range(cols):
			var jx: float = float(((c * 5 + r * 3 + seed_n) % 3) - 1)
			var jy: float = float(((c * 3 + r * 7 + seed_n) % 3) - 1)
			var cx: float = floorf(x0 + 3.0 + float(c) * (w - 6.0) / float(maxi(1, cols - 1)) + jx)
			var cy: float = floorf(y0 + 3.0 + float(r) * (h - 6.0) / float(maxi(1, rows - 1)) + jy)
			draw_rect(Rect2(cx - 3.0, cy - 2.0, 7.0, 6.0), PAL["void"])
			draw_rect(Rect2(cx - 3.0, cy - 3.0, 6.0, 6.0), PAL["night"])
			draw_rect(Rect2(cx - 2.0, cy - 2.0, 5.0, 4.0), PAL["pine"])
			draw_rect(Rect2(cx - 2.0, cy - 2.0, 3.0, 2.0), PAL["teal"])
			if (c + r + seed_n) % 2 == 0:
				draw_rect(Rect2(cx - 2.0, cy - 2.0, 2.0, 1.0), PAL["jade"])
				draw_rect(Rect2(cx - 2.0, cy - 2.0, 1.0, 1.0), PAL["lime"])
	var v1a: Vector2 = Vector2(x0 + 1.0, y0 + h - 3.0)
	var v1m: Vector2 = Vector2(floorf(x0 + w * 0.5), floorf(y0 + h * 0.4))
	var v1b: Vector2 = Vector2(x0 + w - 2.0, y0 + 2.0)
	draw_line(v1a, v1m, PAL["dusk"], 2.0)
	draw_line(v1m, v1b, PAL["dusk"], 2.0)
	draw_line(v1a, v1m, PAL["plum"], 1.0)
	draw_line(v1m, v1b, PAL["plum"], 1.0)
	var v2a: Vector2 = Vector2(x0 + 2.0, y0 + 2.0)
	var v2m: Vector2 = Vector2(floorf(x0 + w * 0.45), floorf(y0 + h * 0.6))
	var v2b: Vector2 = Vector2(x0 + w - 2.0, y0 + h - 3.0)
	draw_line(v2a, v2m, PAL["dusk"], 2.0)
	draw_line(v2m, v2b, PAL["dusk"], 2.0)
	draw_line(v2a, v2m, PAL["plum"], 1.0)
	draw_line(v2m, v2b, PAL["plum"], 1.0)
	var thorns: Array[Vector2] = [
		Vector2(floorf(x0 + w * 0.25), floorf(y0 + h * 0.3)),
		Vector2(floorf(x0 + w * 0.7), floorf(y0 + h * 0.28)),
		Vector2(floorf(x0 + w * 0.3), floorf(y0 + h * 0.72)),
		Vector2(floorf(x0 + w * 0.72), floorf(y0 + h * 0.68)),
	]
	for ti: int in range(thorns.size()):
		var tp: Vector2 = thorns[ti]
		draw_rect(Rect2(tp.x - 1.0, tp.y, 1.0, 1.0), PAL["mauve"])
		draw_rect(Rect2(tp.x, tp.y - 1.0, 2.0, 2.0), PAL["coral"] if ti % 2 == 0 else PAL["rose"])
		draw_rect(Rect2(tp.x, tp.y - 1.0, 1.0, 1.0), PAL["rose"])
