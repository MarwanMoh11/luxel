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
	var c_dark: Color = (PAL["deep"] if is_blue else PAL["wine"]) as Color
	var c_mid: Color = (PAL["blue"] if is_blue else PAL["apricot"]) as Color
	var c_hi: Color = (PAL["ice"] if is_blue else PAL["gold"]) as Color
	var c_void: Color = PAL["void"] as Color

	if not raised:
		# Lowered floor socket: clearly recessed with dotted phase outline
		draw_rect(Rect2(x0, y0, w, h), Color(c_void, 0.55))
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"] as Color)
		var rim_c: Color = (PAL["cream"] if (_pending_raise and (LxHudFx.flash_reduced() or int(floorf(_clock * 8.0)) % 2 == 0)) else c_mid)
		for sx: float in [x0 + 1.0, x0 + w - 4.0]:
			draw_rect(Rect2(sx, y0 + 1.0, 3.0, 1.0), rim_c)
			draw_rect(Rect2(sx, y0 + h - 2.0, 3.0, 1.0), rim_c)
		for sy: float in [y0 + 1.0, y0 + h - 4.0]:
			draw_rect(Rect2(x0 + 1.0, sy, 1.0, 3.0), rim_c)
			draw_rect(Rect2(x0 + w - 2.0, sy, 1.0, 3.0), rim_c)
		LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, 3 if is_blue else 1, false, c_dark, c_mid)
		return

	# Raised solid pillar with 3px vertical elevation & contact shadow
	var lift: float = roundf(_anim_t * 3.0)
	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 1.0, 2.0), Color(c_void, 0.65))
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0 - lift, w, h + lift), c_dark, c_mid, c_hi, c_void)
	# Top cap face
	draw_rect(Rect2(x0 + 2.0, y0 - lift + 2.0, w - 4.0, maxf(2.0, h - 5.0)), c_mid)
	draw_rect(Rect2(x0 + 2.0, y0 - lift + 2.0, w - 4.0, 1.0), PAL["cream"] as Color)
	# Front lip dark bevel
	draw_rect(Rect2(x0 + 1.0, y0 + h - 3.0, w - 2.0, 2.0), c_dark)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -lift - 1.0), 3 if is_blue else 1, true, c_dark, PAL["cream"] as Color)
