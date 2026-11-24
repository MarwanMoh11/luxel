class_name LxPhysGrate
extends LxToy
## Iron bar grate: solid for Wick, dash, zip, lantern throws, and enemies;
## see-through so Light Bolts, Beams, and light pass cleanly through the bars.


func _toy_setup() -> void:
	kind = "grate"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	queue_redraw()


func is_solid() -> bool:
	return active


func blocks_sight() -> bool:
	return false


func blocks_lantern() -> bool:
	return active


func blocks_bolt() -> bool:
	return false


func blocks_beam() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(1.0, 2.0), 0.32)
	var c_out: Color = PAL["void"] as Color
	var c_frame: Color = PAL["dusk"] as Color
	var c_hi: Color = PAL["stone"] as Color
	var c_bar: Color = PAL["mauve"] as Color
	var c_riv: Color = biome("hi")
	# Hollow iron frame (transparent center so floor/pit/water shows through!)
	draw_rect(r, c_out, false, 2.0)
	draw_rect(r.grow(-1.0), c_frame, false, 1.0)
	draw_line(r.position + Vector2(1.0, 1.0), Vector2(r.end.x - 1.0, r.position.y + 1.0), c_hi, 1.0)
	# Spaced wrought-iron bars with clear open gaps
	var horiz: bool = size.x >= size.y
	if horiz:
		var x: float = r.position.x + 5.0
		while x < r.end.x - 3.0:
			draw_rect(Rect2(roundf(x) - 1.0, r.position.y + 1.0, 3.0, r.size.y - 2.0), c_out)
			draw_line(Vector2(roundf(x), r.position.y + 2.0), Vector2(roundf(x), r.end.y - 2.0), c_bar, 1.0)
			draw_rect(Rect2(roundf(x), r.position.y + 2.0, 1.0, 2.0), c_hi)
			x += 6.0
		var mid_y: float = roundf(r.position.y + r.size.y * 0.5)
		draw_line(Vector2(r.position.x + 2.0, mid_y), Vector2(r.end.x - 2.0, mid_y), c_frame, 1.0)
	else:
		var y: float = r.position.y + 5.0
		while y < r.end.y - 3.0:
			draw_rect(Rect2(r.position.x + 1.0, roundf(y) - 1.0, r.size.x - 2.0, 3.0), c_out)
			draw_line(Vector2(r.position.x + 2.0, roundf(y)), Vector2(r.end.x - 2.0, roundf(y)), c_bar, 1.0)
			draw_rect(Rect2(r.position.x + 2.0, roundf(y), 2.0, 1.0), c_hi)
			y += 6.0
		var mid_x: float = roundf(r.position.x + r.size.x * 0.5)
		draw_line(Vector2(mid_x, r.position.y + 2.0), Vector2(mid_x, r.end.y - 2.0), c_frame, 1.0)
	# Corner rivets
	for cp: Vector2 in [r.position + Vector2(1.0, 1.0), Vector2(r.end.x - 2.0, r.position.y + 1.0), Vector2(r.position.x + 1.0, r.end.y - 2.0), r.end - Vector2(2.0, 2.0)]:
		draw_rect(Rect2(cp, Vector2.ONE), c_riv)
