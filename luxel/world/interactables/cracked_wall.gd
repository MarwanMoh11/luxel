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
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	draw_rect(Rect2(x0, y0, w, h), PAL["void"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	var row_h: float = 6.0 if h >= 14.0 else maxf(4.0, floorf((h - 2.0) * 0.5))
	var by: float = y0 + 1.0
	var row: int = 0
	while by < y0 + h - 1.0:
		var bh: float = minf(row_h, y0 + h - 1.0 - by)
		var bx: float = x0 + 1.0 - (4.0 if row % 2 == 1 else 0.0)
		while bx < x0 + w - 1.0:
			var rx0: float = maxf(x0 + 1.0, bx)
			var rx1: float = minf(x0 + w - 1.0, bx + 9.0)
			var bw: float = rx1 - rx0
			if bw >= 3.0 and bh >= 3.0:
				draw_rect(Rect2(rx0, by, bw - 1.0, bh - 1.0), PAL["dusk"])
				draw_rect(Rect2(rx0, by, bw - 1.0, maxf(1.0, bh - 2.0)), PAL["mauve"])
				draw_rect(Rect2(rx0, by, bw - 1.0, 1.0), PAL["stone"])
				draw_rect(Rect2(rx0, by, 1.0, bh - 2.0), PAL["stone"])
			bx += 9.0
		by += row_h
		row += 1
	var hub: Vector2 = Vector2(floorf(x0 + w * 0.52), floorf(y0 + h * 0.48))
	var cracks: Array = [
		[Vector2(x0 + 2.0, y0 + 2.0), Vector2(floorf(x0 + w * 0.3), floorf(y0 + h * 0.35)), hub],
		[hub, Vector2(floorf(x0 + w * 0.68), floorf(y0 + h * 0.68)), Vector2(x0 + w - 2.0, y0 + h - 2.0)],
		[hub, Vector2(floorf(x0 + w * 0.72), floorf(y0 + h * 0.25)), Vector2(x0 + w - 3.0, y0 + 2.0)],
		[hub, Vector2(floorf(x0 + w * 0.32), floorf(y0 + h * 0.78)), Vector2(x0 + 3.0, y0 + h - 2.0)],
	]
	for raw_seg: Variant in cracks:
		var seg: Array = raw_seg as Array
		var a: Vector2 = seg[0] as Vector2
		var b: Vector2 = seg[1] as Vector2
		var c: Vector2 = seg[2] as Vector2
		draw_line(a - Vector2(1.0, 1.0), b - Vector2(1.0, 1.0), PAL["stone"], 1.0)
		draw_line(a, b, PAL["void"], 2.0)
		draw_line(b, c, PAL["void"], 1.5)
	draw_rect(Rect2(hub - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PAL["void"])
	draw_line(Vector2(hub.x - 2.0, hub.y - 1.0), Vector2(hub.x + 2.0, hub.y + 1.0), PAL["apricot"], 1.0)
	draw_rect(Rect2(hub, Vector2(1.0, 1.0)), PAL["gold"])
	draw_rect(Rect2(x0 + 2.0, y0 + h - 2.0, 2.0, 2.0), PAL["mauve"])
	draw_rect(Rect2(x0 + 2.0, y0 + h - 2.0, 1.0, 1.0), PAL["stone"])
	draw_rect(Rect2(x0 + w - 5.0, y0 + h - 2.0, 2.0, 1.0), PAL["dusk"])
	draw_rect(Rect2(hub.x - 3.0, y0 + h - 1.0, 2.0, 1.0), PAL["stone"])
