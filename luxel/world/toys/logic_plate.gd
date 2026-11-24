class_name LxPressurePlate
extends LxToy
## Floor pressure plate depressed by Wick, lantern, blocks/mirrors/mimics, echoes, or enemies.
## Props: by (Array of "wick"|"lantern"|"block"|"enemy"), hold (bool), latch (bool), size [w,h], persist.

var allowed_by: PackedStringArray = PackedStringArray(["wick", "lantern", "block", "enemy"])
var hold_mode: bool = true
var latch_mode: bool = false
var pressed: bool = false
var _press_t: float = 0.0
var _press_weight: float = 0.0
var _was_initial_on: bool = false


func _toy_setup() -> void:
	kind = "pressure_plate"
	if not props.has("size"):
		size = Vector2(18.0, 18.0)
	radius = maxf(size.x, size.y) * 0.5
	z_index = -5
	latch_mode = bool(props.get("latch", false))
	hold_mode = bool(props.get("hold", not latch_mode))
	if latch_mode and not props.has("hold"):
		hold_mode = false
	var raw_by: Variant = props.get("by", ["wick", "lantern", "block", "enemy"])
	allowed_by = PackedStringArray()
	if raw_by is Array and not (raw_by as Array).is_empty():
		for b: Variant in (raw_by as Array):
			allowed_by.append(str(b).strip_edges().to_lower())
	else:
		allowed_by = PackedStringArray(["wick", "lantern", "block", "enemy"])
	_was_initial_on = powered
	pressed = powered
	_press_t = 1.0 if pressed else 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	pressed = _was_initial_on
	_press_weight = 0.0
	if powered != _was_initial_on:
		set_powered(_was_initial_on)
		emit_power(_was_initial_on)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var target_anim: float = 1.0 if pressed else 0.0
	if not is_equal_approx(_press_t, target_anim):
		_press_t = move_toward(_press_t, target_anim, dt * 8.0)
		queue_redraw()
	var w: float = _measure_weight()
	_press_weight = w
	var now_down: bool = w > 0.0
	if latch_mode:
		if now_down and not pressed:
			_set_plate_state(true)
	else:
		if now_down != pressed:
			_set_plate_state(now_down)


func _set_plate_state(down: bool) -> void:
	pressed = down
	set_powered(down)
	emit_power(down)
	if not down and bool(props.get("sfx", true)):
		_emit_sfx("footstep_stone")
	queue_redraw()


func _measure_weight() -> float:
	var plate_rect: Rect2 = rect_at(pos).grow(1.0)
	var total: float = 0.0
	if allowed_by.has("wick"):
		var wp: Vector2 = wick_pos()
		var wick_air: bool = false
		if Lx.player != null and is_instance_valid(Lx.player):
			if Lx.player.get("dead") is bool and bool(Lx.player.get("dead")):
				wick_air = true
			elif Lx.player.has_method("is_gliding") and bool(Lx.player.call("is_gliding")):
				wick_air = true
			elif Lx.player.has_method("is_zipping") and bool(Lx.player.call("is_zipping")):
				wick_air = true
		if not wick_air and plate_rect.has_point(wp):
			total += 1.0
	if allowed_by.has("lantern") and region != null and region.has_method("is_lantern_out"):
		if bool(region.call("is_lantern_out")):
			var lp: Vector2 = region.call("get_lantern_pos") as Vector2 if region.has_method("get_lantern_pos") else Vector2(-9999.0, -9999.0)
			if plate_rect.has_point(lp):
				total += 1.0
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or it_v == self:
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active:
				continue
			if allowed_by.has("block") and _is_weight_interactable(it):
				if it.is_solid() and it.get_solid_rect().intersects(plate_rect):
					total += _interactable_weight(it)
				elif plate_rect.has_point(it.pos):
					total += _interactable_weight(it)
			if allowed_by.has("wick") and it.has_method("is_echo_active") and bool(it.call("is_echo_active")):
				var ep: Vector2 = it.call("get_echo_pos") as Vector2
				if plate_rect.has_point(ep):
					total += 1.0
	if allowed_by.has("enemy") and region != null and region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if e_v is LxEnemyBrain and is_instance_valid(e_v):
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive() and not e.is_flying() and plate_rect.has_point(e.pos):
					total += 1.0
	return total


static func _is_weight_interactable(it: LxInteractable) -> bool:
	if it.kind in ["push_block", "mimic_statue", "carry_orb", "mirror", "blue_transformer"]:
		return true
	if it.has_method("is_movable") and bool(it.call("is_movable")):
		return true
	return it.has_method("is_weight_body") and bool(it.call("is_weight_body"))


static func _interactable_weight(it: LxInteractable) -> float:
	if it.props.has("weight"):
		return maxf(0.5, float(it.props["weight"]))
	if it.kind in ["push_block", "mimic_statue", "mirror", "blue_transformer"]:
		return 2.0
	return 1.0


func get_light_pool() -> Vector4:
	if not active or not powered:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 28.0, 0.48)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pressed"] = pressed
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pressed"):
		pressed = bool(d["pressed"])
		powered = pressed
		_press_t = 1.0 if pressed else 0.0
		if powered:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_cream: Color = PAL["cream"] as Color

	# Outer recessed stone rim
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), c_night, PAL["dusk"] as Color, c_mauve, c_void)
	# Corner bolts
	for cx: float in [x0 + 2.0, x0 + w - 3.0]:
		for cy: float in [y0 + 2.0, y0 + h - 3.0]:
			draw_rect(Rect2(cx, cy, 1.0, 1.0), c_glow if powered else c_stone)

	# Moving inner slab (drops 2px when pressed)
	var drop: float = roundf(_press_t * 2.0)
	var iw: float = maxf(6.0, w - 6.0)
	var ih: float = maxf(6.0, h - 6.0)
	var ix: float = floorf(-iw * 0.5)
	var iy: float = floorf(-ih * 0.5) - 1.0 + drop
	if drop < 2.0:
		draw_rect(Rect2(ix, iy + ih, iw, 2.0 - drop), c_void)
	var slab_mid: Color = trip[1] if powered else c_mauve
	var slab_hi: Color = c_cream if powered else c_stone
	var slab_dark: Color = trip[0] if powered else PAL["dusk"] as Color
	LxToyDraw.draw_bevel_box(self, Rect2(ix, iy, iw, ih), slab_dark, slab_mid, slab_hi, c_void)

	# Greyscale-distinct center glyph: hollow square when up, bright filled diamond when down
	var shape_i: int = 1 if powered else (3 if latch_mode else 0)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, iy + floorf(ih * 0.5)), shape_i, powered, c_glow if powered else c_mauve, c_cream if powered else c_stone)
	_draw_signal_pulses()
