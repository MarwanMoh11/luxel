class_name LxPhysRail
extends LxToy
## Waist-high balustrade rail: solid for Wick walking and Flare Dash;
## thrown lantern, Light Bolts, Beams, and flying enemies pass cleanly over it.


func _toy_setup() -> void:
	kind = "rail"
	size = _parse_size(props.get("size", [32.0, 10.0]), Vector2(32.0, 10.0))
	radius = maxf(size.x, size.y) * 0.5
	queue_redraw()


func is_solid() -> bool:
	return active


func blocks_sight() -> bool:
	return false


func blocks_lantern() -> bool:
	return false


func blocks_flyer() -> bool:
	return false


func blocks_bolt() -> bool:
	return false


func blocks_beam() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(1.0, 2.0), 0.30)
	var c_out: Color = PAL["void"] as Color
	var c_post: Color = PAL["dusk"] as Color
	var c_rail: Color = PAL["stone"] as Color
	var c_cap: Color = biome("hi")
	var c_trim: Color = biome("glow")
	var horiz: bool = size.x >= size.y
	if horiz:
		# Spaced balusters underneath top handrail
		var x: float = r.position.x + 3.0
		while x < r.end.x - 3.0:
			draw_rect(Rect2(roundf(x) - 1.0, r.position.y + 3.0, 3.0, maxf(2.0, r.size.y - 4.0)), c_out)
			draw_rect(Rect2(roundf(x), r.position.y + 3.0, 1.0, maxf(2.0, r.size.y - 4.0)), c_post)
			x += 7.0
		# Continuous elevated waist-high handrail bar + end finials
		var bar := Rect2(r.position.x, r.position.y, r.size.x, minf(5.0, r.size.y))
		LxPhysDraw.draw_bevel_box(self, bar, c_rail, PAL["cream"] as Color, c_post, c_out)
		draw_rect(Rect2(bar.position + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_cap)
		draw_rect(Rect2(bar.end.x - 3.0, bar.position.y + 1.0, 2.0, 2.0), c_cap)
		draw_rect(Rect2(bar.position.x + 1.0, bar.position.y + 1.0, 1.0, 1.0), c_trim)
		draw_rect(Rect2(bar.end.x - 2.0, bar.position.y + 1.0, 1.0, 1.0), c_trim)
	else:
		var y: float = r.position.y + 3.0
		while y < r.end.y - 3.0:
			draw_rect(Rect2(r.position.x + 2.0, roundf(y) - 1.0, maxf(2.0, r.size.x - 4.0), 3.0), c_out)
			draw_rect(Rect2(r.position.x + 2.0, roundf(y), maxf(2.0, r.size.x - 4.0), 1.0), c_post)
			y += 7.0
		var vbar := Rect2(r.position.x, r.position.y, minf(5.0, r.size.x), r.size.y)
		LxPhysDraw.draw_bevel_box(self, vbar, c_rail, PAL["cream"] as Color, c_post, c_out)
		draw_rect(Rect2(vbar.position + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_cap)
		draw_rect(Rect2(vbar.position.x + 1.0, vbar.end.y - 3.0, 2.0, 2.0), c_cap)
