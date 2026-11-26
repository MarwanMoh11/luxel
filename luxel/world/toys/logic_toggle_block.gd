class_name LxToggleBlock
extends LxToy
## Phase-linked retractable barrier controlled by LxCrystalToggle (matching `group`).
## Raised (solid) when current group phase == `phase`, lowered (passable) otherwise.
## Defers raising while Wick overlaps its footprint to prevent crush/clip softlocks.
## Props: group (String), phase (int 0|1), size [w,h], persist (bool).

var group_id: String = "default"
var active_phase: int = 0
var current_phase: int = 0
var raised: bool = true
var _pending_raise: bool = false
var _anim_t: float = 1.0


func _toy_setup() -> void:
	kind = "toggle_block"
	group_id = str(props.get("group", "default")).strip_edges()
	if group_id.is_empty():
		group_id = "default"
	active_phase = 1 if int(props.get("phase", 0)) == 1 else 0
	current_phase = 1 if int(props.get("start_phase", 0)) == 1 else 0
	if not props.has("size"):
		size = Vector2(16.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	raised = (current_phase == active_phase)
	_pending_raise = false
	_anim_t = 1.0 if raised else 0.0
	z_index = 0 if raised else -5
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	var start_p: int = 1 if int(props.get("start_phase", 0)) == 1 else 0
	set_group_phase(start_p)


func set_group_phase(new_phase: int) -> void:
	current_phase = 1 if new_phase == 1 else 0
	var want_raised: bool = (current_phase == active_phase)
	if want_raised:
		if _wick_inside():
			_pending_raise = true
			raised = false
		else:
			_pending_raise = false
			raised = true
	else:
		_pending_raise = false
		raised = false
	z_index = 0 if raised else -5
	queue_redraw()


func on_signal(_from_id: String, is_on: bool) -> void:
	set_group_phase(1 if is_on else 0)


func tick(dt: float) -> void:
	super.tick(dt)
	if _pending_raise and not _wick_inside():
		_pending_raise = false
		raised = true
		z_index = 0
		_emit_sfx("stone_break")
		queue_redraw()
	var target: float = 1.0 if raised else 0.0
	if not is_equal_approx(_anim_t, target):
		_anim_t = move_toward(_anim_t, target, dt * 7.5)
		queue_redraw()
	elif _pending_raise:
		queue_redraw()


func _wick_inside() -> bool:
	var wp: Vector2 = wick_pos()
	return rect_at(pos).grow(4.5).has_point(wp)


func is_solid() -> bool:
	return active and raised


func blocks_sight() -> bool:
	return active and raised


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["current_phase"] = current_phase
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("current_phase"):
		set_group_phase(int(d["current_phase"]))
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var is_blue: bool = active_phase == 1
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_dark: Color = (PAL["deep"] if is_blue else PAL["wine"]) as Color
	var c_mid: Color = (PAL["blue"] if is_blue else PAL["apricot"]) as Color
	var c_hi: Color = (PAL["sky"] if is_blue else PAL["gold"]) as Color
	var c_rim: Color = (PAL["ice"] if is_blue else c_cream) as Color

	if not raised:
		# Clean recessed floor socket frame with dotted inner rim so it never vanishes
		draw_rect(Rect2(x0, y0, w, h), c_void)
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), c_dusk)
		draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), c_night)
		# Recessed inner bevel lip
		draw_rect(Rect2(x0 + 2.0, y0 + h - 3.0, w - 4.0, 1.0), c_mauve)
		draw_rect(Rect2(x0 + w - 3.0, y0 + 2.0, 1.0, h - 4.0), c_mauve)
		# Corner stone brackets
		var pending_hi: bool = _pending_raise and (LxHudFx.flash_reduced() or int(floorf(_clock * 6.0)) % 2 == 0)
		var rim_c: Color = c_cream if pending_hi else c_hi
		for sx: float in [x0 + 1.0, x0 + w - 4.0]:
			draw_rect(Rect2(sx, y0 + 1.0, 3.0, 1.0), rim_c)
			draw_rect(Rect2(sx, y0 + h - 2.0, 3.0, 1.0), rim_c)
		for sy: float in [y0 + 1.0, y0 + h - 4.0]:
			draw_rect(Rect2(x0 + 1.0, sy, 1.0, 3.0), rim_c)
			draw_rect(Rect2(x0 + w - 2.0, sy, 1.0, 3.0), rim_c)
		# Dotted inner rim around socket perimeter
		var dot_c: Color = c_cream if pending_hi else c_mid
		var dx: float = x0 + 3.0
		while dx <= x0 + w - 4.0:
			draw_rect(Rect2(dx, y0 + 3.0, 2.0, 1.0), dot_c)
			draw_rect(Rect2(dx, y0 + h - 4.0, 2.0, 1.0), dot_c)
			dx += 4.0
		var dy: float = y0 + 5.0
		while dy <= y0 + h - 6.0:
			draw_rect(Rect2(x0 + 3.0, dy, 1.0, 2.0), dot_c)
			draw_rect(Rect2(x0 + w - 4.0, dy, 1.0, 2.0), dot_c)
			dy += 4.0
		_draw_phase_emblem(Vector2.ZERO, is_blue, false, c_dark, c_mid)
		return

	# Raised solid state: true 3/4 temple block depth (lit top face, darker south face, grounded shadow)
	var lift: float = roundf(_anim_t * 4.0)
	var top_y: float = y0 - lift
	var total_h: float = h + lift
	var south_h: float = clampf(floorf(h * 0.34) + floorf(lift * 0.5), 4.0, maxf(4.0, total_h - 6.0))
	var top_h: float = maxf(6.0, total_h - south_h)

	# Grounded drop shadow cast down-right
	draw_rect(Rect2(x0 + 2.0, y0 + h - 1.0, w, 3.0), Color(c_void, 0.38))
	draw_rect(Rect2(x0 + w, top_y + 2.0, 2.0, total_h - 1.0), Color(c_void, 0.32))

	# Outer dark silhouette
	draw_rect(Rect2(x0, top_y, w, total_h), c_void)

	# Darker south front face with carved masonry seam & corner pilasters
	var sy0: float = top_y + top_h
	draw_rect(Rect2(x0 + 1.0, sy0, w - 2.0, south_h - 1.0), c_dark)
	draw_rect(Rect2(x0 + 1.0, sy0, w - 2.0, 1.0), c_mid)
	draw_rect(Rect2(x0 + 1.0, sy0 + south_h - 2.0, w - 2.0, 1.0), c_night)
	draw_rect(Rect2(x0 + 2.0, sy0 + 1.0, 2.0, maxf(1.0, south_h - 3.0)), c_mid)
	draw_rect(Rect2(x0 + w - 4.0, sy0 + 1.0, 2.0, maxf(1.0, south_h - 3.0)), c_night)
	draw_rect(Rect2(floorf(x0 + w * 0.5), sy0 + 1.0, 1.0, maxf(1.0, south_h - 2.0)), c_void)

	# Lit top face with sunlit bevels & corner studs
	draw_rect(Rect2(x0 + 1.0, top_y + 1.0, w - 2.0, top_h - 1.0), c_mid)
	draw_rect(Rect2(x0 + 2.0, top_y + 2.0, w - 4.0, maxf(2.0, top_h - 3.0)), c_hi)
	draw_rect(Rect2(x0 + 1.0, top_y + 1.0, w - 2.0, 1.0), c_rim)
	draw_rect(Rect2(x0 + 1.0, top_y + 1.0, 1.0, top_h - 1.0), c_rim)
	draw_rect(Rect2(x0 + w - 2.0, top_y + 2.0, 1.0, top_h - 2.0), c_dark)
	for cx: float in [x0 + 2.0, x0 + w - 3.0]:
		draw_rect(Rect2(cx, top_y + 2.0, 1.0, 1.0), c_stone)

	# Carved Star (phase 0) or Crescent Moon (phase 1) emblem on lit top face
	var em_c := Vector2(0.0, roundf(top_y + top_h * 0.5))
	_draw_phase_emblem(em_c, is_blue, true, c_dark, c_cream)


func _draw_phase_emblem(center: Vector2, is_moon: bool, raised_now: bool, c_dark: Color, c_hi: Color) -> void:
	var cx: float = roundf(center.x)
	var cy: float = roundf(center.y)
	var c_void: Color = PAL["void"] as Color
	if is_moon:
		# Carved crescent moon emblem
		draw_rect(Rect2(cx - 3.0, cy - 3.0, 6.0, 7.0), c_void if raised_now else c_dark)
		draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 5.0), c_hi)
		draw_rect(Rect2(cx - 1.0, cy - 3.0, 3.0, 1.0), c_hi)
		draw_rect(Rect2(cx - 1.0, cy + 3.0, 3.0, 1.0), c_hi)
		draw_rect(Rect2(cx, cy - 2.0, 3.0, 5.0), c_dark if raised_now else PAL["night"] as Color)
	else:
		# Carved 4-point star emblem
		LxToyDraw.draw_shape_glyph(self, center, 5, raised_now, c_dark if raised_now else c_hi, c_hi)
