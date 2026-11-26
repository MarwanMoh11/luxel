class_name LxToneDoor
extends LxToy
## Resonant barrier opened by an LxRingWave whose tone matches `tone` ("dawn" | "dusk" | "war").
## Props: tone ("dawn"|"dusk"|"war"), size [w,h], hold_secs (float, 0 = stays open), toggle (bool), persist (bool).

var tone: String = "dawn"
var opened: bool = false
var hold_secs: float = 0.0
var toggle_mode: bool = false
var _hold_left: float = 0.0
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _init_open: bool = false


func _toy_setup() -> void:
	kind = "tone_door"
	tone = str(props.get("tone", "dawn")).strip_edges().to_lower()
	if tone not in ["dawn", "dusk", "war"]:
		tone = "dawn"
	if not props.has("size"):
		size = Vector2(32.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	hold_secs = maxf(0.0, float(props.get("hold_secs", 0.0)))
	toggle_mode = bool(props.get("toggle", false))
	_init_open = bool(props.get("opened", powered))
	opened = _init_open
	powered = opened
	_hold_left = hold_secs if (opened and hold_secs > 0.0) else 0.0
	_open_t = 0.0
	_rattle_t = 0.0
	z_index = -4 if opened else 0
	queue_redraw()


func reset_toy() -> void:
	if persist and opened:
		return
	opened = _init_open
	_hold_left = 0.0
	powered = opened
	z_index = -4 if opened else 0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	var dirty: bool = false
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		dirty = true
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		dirty = true
	if opened and hold_secs > 0.0:
		_hold_left -= dt
		dirty = true
		if _hold_left <= 0.0 and not _wick_inside():
			opened = false
			powered = false
			z_index = 0
			_emit_sfx("door_locked")
			_notify_linked_targets(false)
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or opened:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		_rattle_t = 0.24
		_emit_sfx("door_locked")
		queue_redraw()
		return true
	return false


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active:
		return
	if in_tone.strip_edges().to_lower() != tone:
		_rattle_t = 0.28
		_emit_sfx("door_locked")
		queue_redraw()
		return
	if toggle_mode and opened:
		if not _wick_inside():
			opened = false
			powered = false
			z_index = 0
			_emit_sfx("door_locked")
			_notify_linked_targets(false)
			queue_redraw()
		return
	if not opened:
		opened = true
		powered = true
		_open_t = 0.36
		z_index = -4
		_emit_sfx("door_open")
		_emit_gust(maxf(size.x, size.y) + 18.0, 42.0)
		_notify_linked_targets(true)
		if persist and region != null and region.has_method("save_interactables_to_state"):
			region.call("save_interactables_to_state")
	if hold_secs > 0.0:
		_hold_left = hold_secs
	queue_redraw()


func _wick_inside() -> bool:
	return rect_at(pos).grow(4.0).has_point(wick_pos())


func is_solid() -> bool:
	return active and not opened


func blocks_sight() -> bool:
	return active and not opened


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if opened:
		return Vector4(pos.x, pos.y, 32.0, 0.42)
	return Vector4(pos.x, pos.y, 26.0, 0.36)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["opened"] = opened
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("opened"):
		opened = bool(d["opened"])
		powered = opened
		z_index = -4 if opened else 0
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var rdx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + rdx
	var y0: float = floorf(-h * 0.5)
	var trip: Array[Color] = LxToyDraw.color_triplet(tone)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var reduced: bool = LxHudFx.flash_reduced()
	var horiz: bool = w >= h
	var jb: float = clampf(floorf(minf(w, h) * 0.35), 5.0, 7.0)

	if opened:
		# Clean open stone doorposts flanking recessed floor threshold
		if horiz:
			draw_rect(Rect2(x0 + jb, y0 + 2.0, maxf(2.0, w - jb * 2.0), maxf(2.0, h - 4.0)), Color(c_void, 0.28))
			draw_rect(Rect2(x0 + jb, y0 + h - 3.0, maxf(2.0, w - jb * 2.0), 1.0), c_dusk)
			_draw_doorpost(Rect2(x0, y0 - 1.0, jb, h + 1.0), trip)
			_draw_doorpost(Rect2(x0 + w - jb, y0 - 1.0, jb, h + 1.0), trip)
		else:
			draw_rect(Rect2(x0 + 2.0, y0 + jb, maxf(2.0, w - 4.0), maxf(2.0, h - jb * 2.0)), Color(c_void, 0.28))
			_draw_doorpost(Rect2(x0 - 1.0, y0, w + 1.0, jb), trip)
			_draw_doorpost(Rect2(x0 - 1.0, y0 + h - jb, w + 1.0, jb), trip)
		if hold_secs > 0.0 and _hold_left > 0.0:
			LxToyDraw.draw_bar(self, Vector2(-7.0, y0 - 5.0), 14.0, _hold_left / hold_secs, trip[1])
		if _open_t > 0.0:
			var u: float = 1.0 - clampf(_open_t / 0.36, 0.0, 1.0)
			var alpha: float = (1.0 - u) * (0.60 if reduced else 0.92)
			draw_arc(Vector2.ZERO, roundf(lerpf(5.0, maxf(w, h) * 0.58, u)), 0.0, TAU, 18, Color(trip[2], alpha), 1.5)
			if not reduced:
				draw_arc(Vector2.ZERO, roundf(lerpf(3.0, maxf(w, h) * 0.40, u)), 0.0, TAU, 14, Color(c_cream, alpha), 1.0)
		_draw_signal_pulses()
		return

	# Grounded drop shadow beneath closed temple double doors
	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 1.0, 3.0), Color(c_void, 0.38))

	# Outer recessed arch jamb surround
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), c_night, c_dusk, c_stone, c_void)
	# Recessed arch lintel shadow
	draw_rect(Rect2(x0 + 2.0, y0 + 1.0, w - 4.0, 2.0), c_void)

	# Carved stone arch jamb pillars on both ends + inner double door leaves
	var inner_r: Rect2 = Rect2(x0 + jb, y0 + 2.0, maxf(6.0, w - jb * 2.0), maxf(6.0, h - 3.0)) if horiz else Rect2(x0 + 2.0, y0 + jb, maxf(6.0, w - 3.0), maxf(6.0, h - jb * 2.0))
	if horiz:
		_draw_doorpost(Rect2(x0, y0 - 1.0, jb, h + 1.0), trip)
		_draw_doorpost(Rect2(x0 + w - jb, y0 - 1.0, jb, h + 1.0), trip)
	else:
		_draw_doorpost(Rect2(x0 - 1.0, y0, w + 1.0, jb), trip)
		_draw_doorpost(Rect2(x0 - 1.0, y0 + h - jb, w + 1.0, jb), trip)

	# Carved double door leaves with center seam & coffered panels
	draw_rect(inner_r, c_void)
	if horiz:
		var half_w: float = floorf(inner_r.size.x * 0.5)
		var l_leaf := Rect2(inner_r.position.x + 1.0, inner_r.position.y + 1.0, maxf(2.0, half_w - 2.0), maxf(2.0, inner_r.size.y - 2.0))
		var r_leaf := Rect2(inner_r.position.x + half_w + 1.0, inner_r.position.y + 1.0, maxf(2.0, inner_r.size.x - half_w - 2.0), maxf(2.0, inner_r.size.y - 2.0))
		for leaf: Rect2 in [l_leaf, r_leaf]:
			draw_rect(leaf, c_dusk)
			draw_rect(Rect2(leaf.position.x, leaf.position.y, leaf.size.x, 1.0), c_mauve)
			if leaf.size.x >= 4.0 and leaf.size.y >= 5.0:
				draw_rect(Rect2(leaf.position.x + 1.0, leaf.position.y + 2.0, leaf.size.x - 2.0, leaf.size.y - 4.0), c_night)
				draw_rect(Rect2(leaf.position.x + 1.0, leaf.position.y + 2.0, leaf.size.x - 2.0, 1.0), trip[0])
		# Brass ring handles flanking the center seam
		draw_rect(Rect2(inner_r.position.x + half_w - 2.0, roundf(inner_r.position.y + inner_r.size.y * 0.5), 1.0, 2.0), trip[1])
		draw_rect(Rect2(inner_r.position.x + half_w + 1.0, roundf(inner_r.position.y + inner_r.size.y * 0.5), 1.0, 2.0), trip[1])
	else:
		var half_h: float = floorf(inner_r.size.y * 0.5)
		var t_leaf := Rect2(inner_r.position.x + 1.0, inner_r.position.y + 1.0, maxf(2.0, inner_r.size.x - 2.0), maxf(2.0, half_h - 2.0))
		var b_leaf := Rect2(inner_r.position.x + 1.0, inner_r.position.y + half_h + 1.0, maxf(2.0, inner_r.size.x - 2.0), maxf(2.0, inner_r.size.y - half_h - 2.0))
		for leaf: Rect2 in [t_leaf, b_leaf]:
			draw_rect(leaf, c_dusk)
			draw_rect(Rect2(leaf.position.x, leaf.position.y, leaf.size.x, 1.0), c_mauve)
			if leaf.size.x >= 5.0 and leaf.size.y >= 4.0:
				draw_rect(Rect2(leaf.position.x + 2.0, leaf.position.y + 1.0, leaf.size.x - 4.0, leaf.size.y - 2.0), c_night)
				draw_rect(Rect2(leaf.position.x + 2.0, leaf.position.y + 1.0, 1.0, leaf.size.y - 2.0), trip[0])

	# Resonant tone inlay pattern (greyscale-distinct: Dawn bar, Dusk ribs, War chevrons)
	if tone == "dusk":
		var sx: float = inner_r.position.x + 2.0
		while sx < inner_r.end.x - 2.0:
			draw_rect(Rect2(sx, inner_r.position.y + 2.0, 1.0, maxf(2.0, inner_r.size.y - 4.0)), trip[1])
			sx += 4.0
	elif tone == "war":
		var wx: float = inner_r.position.x + 2.0
		while wx < inner_r.end.x - 4.0:
			draw_line(Vector2(wx, inner_r.end.y - 2.0), Vector2(wx + 3.0, inner_r.position.y + 2.0), trip[1], 1.0, false)
			wx += 5.0
	elif horiz:
		draw_rect(Rect2(inner_r.position.x + 2.0, -1.0, maxf(2.0, inner_r.size.x - 4.0), 2.0), trip[0])
		draw_rect(Rect2(inner_r.position.x + 3.0, -1.0, maxf(2.0, inner_r.size.x - 6.0), 1.0), trip[1])
	else:
		draw_rect(Rect2(-1.0, inner_r.position.y + 2.0, 2.0, maxf(2.0, inner_r.size.y - 4.0)), trip[0])
		draw_rect(Rect2(-1.0, inner_r.position.y + 3.0, 1.0, maxf(2.0, inner_r.size.y - 6.0)), trip[1])

	# Bold embossed tone crest medallion plate over center seam
	var crest_c := Vector2(rdx, 0.0)
	draw_rect(Rect2(crest_c.x - 5.0, crest_c.y - 4.0, 11.0, 9.0), c_void)
	draw_rect(Rect2(crest_c.x - 4.0, crest_c.y - 5.0, 9.0, 11.0), c_void)
	draw_rect(Rect2(crest_c.x - 4.0, crest_c.y - 4.0, 9.0, 9.0), trip[0])
	draw_rect(Rect2(crest_c.x - 3.0, crest_c.y - 3.0, 7.0, 7.0), c_night)
	draw_rect(Rect2(crest_c.x - 4.0, crest_c.y - 4.0, 5.0, 1.0), trip[2])
	LxToyDraw.draw_tone_crest(self, crest_c, tone, _rattle_t <= 0.0)

	# Resonant chime wave + reject glyph when struck
	if _rattle_t > 0.0:
		var ru: float = 1.0 - clampf(_rattle_t / 0.28, 0.0, 1.0)
		var r_rad: float = roundf(lerpf(5.0, 14.0, ru))
		var r_alpha: float = (1.0 - ru) * (0.55 if reduced else 0.88)
		draw_arc(crest_c, r_rad, 0.0, TAU, 16, Color(trip[1], r_alpha), 1.0)
		LxPixelGlyphs.draw_reject_x(self, Vector2(0.0, -5.0), ru, 1.0, reduced)
	_draw_signal_pulses()


func _draw_doorpost(r: Rect2, trip: Array[Color]) -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	draw_rect(Rect2(r.position.x + 1.0, r.end.y, r.size.x, 2.0), Color(c_void, 0.36))
	LxToyDraw.draw_bevel_box(self, r, c_night, c_dusk, c_stone, c_void)
	# Tone-inlaid capstone jewel on top of doorpost
	var cap_w: float = maxf(2.0, r.size.x - 4.0)
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, cap_w, 2.0), trip[1])
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, maxf(1.0, cap_w - 1.0), 1.0), trip[2])
