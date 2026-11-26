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
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_trim: Color = biome("glow")
	var horiz: bool = size.x >= size.y

	if horiz:
		# Soft ground shadow strip under the elevated beam
		draw_rect(Rect2(r.position.x + 1.0, r.end.y - 2.0, r.size.x, 3.0), Color(c_void, 0.30))
		# Sturdy riveted timber/brass trestle posts spaced cleanly with end posts guaranteed
		var beam_h: float = clampf(floorf(r.size.y * 0.48), 5.0, 7.0)
		var post_y: float = r.position.y + beam_h - 1.0
		var post_h: float = maxf(4.0, r.end.y - post_y)
		var p_xs: Array[float] = [r.position.x + 3.0]
		var span: float = r.size.x - 6.0
		var segs: int = maxi(1, int(roundf(span / 12.0)))
		for i: int in range(1, segs + 1):
			p_xs.append(roundf(r.position.x + 3.0 + span * float(i) / float(segs)))

		# Recessed horizontal tie-brace connecting trestle legs
		if post_h >= 5.0:
			var tie_y: float = r.end.y - 4.0
			draw_rect(Rect2(r.position.x + 3.0, tie_y, maxf(2.0, r.size.x - 6.0), 3.0), c_void)
			draw_rect(Rect2(r.position.x + 3.0, tie_y + 1.0, maxf(2.0, r.size.x - 6.0), 1.0), c_wine)

		for px: float in p_xs:
			# Grounded post shadow + stone footing shoe
			draw_rect(Rect2(px - 2.0, r.end.y - 1.0, 6.0, 3.0), Color(c_void, 0.40))
			draw_rect(Rect2(px - 2.0, post_y, 5.0, post_h), c_void)
			draw_rect(Rect2(px - 1.0, post_y, 3.0, maxf(1.0, post_h - 1.0)), c_wine)
			draw_rect(Rect2(px - 1.0, post_y, 1.0, maxf(1.0, post_h - 2.0)), c_apricot)
			draw_rect(Rect2(px - 2.0, r.end.y - 2.0, 5.0, 2.0), c_night)
			draw_rect(Rect2(px - 1.0, r.end.y - 2.0, 3.0, 1.0), c_dusk)
			# Brass bracket rivet at post shoulder
			draw_rect(Rect2(px, post_y + 1.0, 1.0, 1.0), c_gold)

		# Thick 3/4 continuous elevated timber/brass top beam with sunlit top highlight
		var bar := Rect2(r.position.x, r.position.y - 1.0, r.size.x, beam_h + 1.0)
		draw_rect(bar, c_void)
		# Recessed south side of timber beam
		draw_rect(Rect2(bar.position.x + 1.0, bar.end.y - 3.0, bar.size.x - 2.0, 2.0), c_wine)
		# Sunlit top timber face + crisp cream/gold highlight edge
		draw_rect(Rect2(bar.position.x + 1.0, bar.position.y + 1.0, bar.size.x - 2.0, maxf(2.0, bar.size.y - 4.0)), c_apricot)
		draw_rect(Rect2(bar.position.x + 1.0, bar.position.y + 1.0, bar.size.x - 2.0, 1.0), c_gold)
		draw_rect(Rect2(bar.position.x + 2.0, bar.position.y + 1.0, maxf(2.0, bar.size.x - 4.0), 1.0), c_cream)
		# Brass riveted strap collars directly above every trestle post
		for px: float in p_xs:
			draw_rect(Rect2(px - 1.0, bar.position.y + 1.0, 3.0, bar.size.y - 2.0), c_dusk)
			draw_rect(Rect2(px - 1.0, bar.position.y + 1.0, 3.0, 2.0), c_gold)
			draw_rect(Rect2(px, bar.position.y + 1.0, 1.0, 1.0), c_cream)
			draw_rect(Rect2(px, bar.end.y - 3.0, 1.0, 1.0), c_gold)
		# Ornate end-cap brass finials
		draw_rect(Rect2(bar.position.x + 1.0, bar.position.y + 2.0, 1.0, 1.0), c_trim)
		draw_rect(Rect2(bar.end.x - 2.0, bar.position.y + 2.0, 1.0, 1.0), c_trim)
	else:
		# Vertical riveted timber/brass trestle rail
		draw_rect(Rect2(r.end.x - 2.0, r.position.y + 2.0, 3.0, r.size.y), Color(c_void, 0.34))
		var beam_w: float = clampf(floorf(r.size.x * 0.48), 5.0, 7.0)
		var leg_x: float = r.position.x + beam_w - 1.0
		var leg_w: float = maxf(3.0, r.end.x - leg_x)
		var p_ys: Array[float] = [r.position.y + 3.0]
		var vspan: float = r.size.y - 6.0
		var vsegs: int = maxi(1, int(roundf(vspan / 12.0)))
		for i: int in range(1, vsegs + 1):
			p_ys.append(roundf(r.position.y + 3.0 + vspan * float(i) / float(vsegs)))

		for py: float in p_ys:
			draw_rect(Rect2(r.position.x + 1.0, py + 1.0, r.size.x, 3.0), Color(c_void, 0.38))
			draw_rect(Rect2(leg_x, py - 2.0, leg_w, 5.0), c_void)
			draw_rect(Rect2(leg_x, py - 1.0, maxf(1.0, leg_w - 1.0), 3.0), c_wine)
			draw_rect(Rect2(leg_x, py - 1.0, maxf(1.0, leg_w - 2.0), 1.0), c_apricot)
			draw_rect(Rect2(r.end.x - 2.0, py - 1.0, 1.0, 3.0), c_dusk)

		var vbar := Rect2(r.position.x, r.position.y, beam_w + 1.0, r.size.y)
		draw_rect(vbar, c_void)
		draw_rect(Rect2(vbar.end.x - 3.0, vbar.position.y + 1.0, 2.0, vbar.size.y - 2.0), c_wine)
		draw_rect(Rect2(vbar.position.x + 1.0, vbar.position.y + 1.0, maxf(2.0, vbar.size.x - 4.0), vbar.size.y - 2.0), c_apricot)
		draw_rect(Rect2(vbar.position.x + 1.0, vbar.position.y + 1.0, 1.0, vbar.size.y - 2.0), c_gold)
		draw_rect(Rect2(vbar.position.x + 1.0, vbar.position.y + 2.0, 1.0, maxf(2.0, vbar.size.y - 4.0)), c_cream)
		for py: float in p_ys:
			draw_rect(Rect2(vbar.position.x + 1.0, py - 1.0, vbar.size.x - 2.0, 3.0), c_dusk)
			draw_rect(Rect2(vbar.position.x + 1.0, py - 1.0, 2.0, 3.0), c_gold)
			draw_rect(Rect2(vbar.position.x + 1.0, py, 1.0, 1.0), c_cream)
		draw_rect(Rect2(vbar.position.x + 2.0, vbar.position.y + 1.0, 1.0, 1.0), c_stone)
		draw_rect(Rect2(vbar.position.x + 2.0, vbar.end.y - 2.0, 1.0, 1.0), c_trim)
