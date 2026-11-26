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
			if not is_instance_valid(it_v) or not (it_v is LxInteractable) or it_v == self:
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
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var latched_on: bool = latch_mode and powered

	# Crisp cream/gold outer halo when latched & solved
	if latched_on:
		draw_rect(Rect2(x0 - 1.0, y0 - 1.0, w + 2.0, h + 2.0), c_gold, false, 1.0)
		var glint_ok: bool = LxHudFx.flash_reduced() or int(floorf(_clock * 4.0)) % 2 == 0
		if glint_ok:
			for hx: float in [x0 - 1.0, x0 + w]:
				for hy: float in [y0 - 1.0, y0 + h]:
					draw_rect(Rect2(hx, hy, 1.0, 1.0), c_cream)

	# Grounded floor lip shadow for strong contrast on dusk floors
	draw_rect(Rect2(x0 + 1.0, y0 + h, w, 2.0), Color(c_void, 0.38))

	# Heavy bevelled outer stone socket frame (high-contrast stone highlight rim)
	var rim_hi: Color = c_cream if latched_on else (c_gold if powered else c_stone)
	var rim_mid: Color = c_apricot if latched_on else (c_dusk if powered else c_mauve)
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), c_night, rim_mid, rim_hi, c_void)

	# Recessed dark pit inside the socket frame
	var iw: float = maxf(6.0, w - 6.0)
	var ih: float = maxf(6.0, h - 6.0)
	var ix: float = floorf(-iw * 0.5)
	var pit_y: float = floorf(-ih * 0.5)
	draw_rect(Rect2(ix - 1.0, pit_y - 1.0, iw + 2.0, ih + 2.0), c_void)
	draw_rect(Rect2(ix, pit_y, iw, ih), c_night)

	# Chunky brass corner rivets (apricot idle -> gold pressed -> cream latched)
	var rivet_c: Color = c_cream if latched_on else (c_gold if powered else c_apricot)
	for cx: float in [x0 + 1.0, x0 + w - 3.0]:
		for cy: float in [y0 + 1.0, y0 + h - 3.0]:
			draw_rect(Rect2(cx, cy, 2.0, 2.0), c_void)
			draw_rect(Rect2(cx, cy, 1.0, 1.0), rivet_c)

	# Moving inner stone slab (raised proud when unpressed, sunken recessed when pressed)
	var drop: float = roundf(_press_t * 2.0)
	var iy: float = pit_y - 2.0 + drop
	if drop < 2.0:
		# Raised south skirt wall showing vertical height when unpressed
		var skirt_h: float = 2.0 - drop
		draw_rect(Rect2(ix, iy + ih, iw, skirt_h + 1.0), c_void)
		draw_rect(Rect2(ix + 1.0, iy + ih, iw - 2.0, skirt_h), c_dusk)
	var slab_dark: Color = c_wine if powered else c_dusk
	var slab_mid: Color = c_coral if powered else c_mauve
	var slab_hi: Color = c_gold if powered else c_stone
	LxToyDraw.draw_bevel_box(self, Rect2(ix, iy, iw, ih), slab_dark, slab_mid, slab_hi, c_void)
	if not powered:
		# Sunlit crisp top-left slab bevel for instant readability on dusk tiles
		draw_rect(Rect2(ix + 1.0, iy + 1.0, iw - 3.0, 1.0), c_stone)
		draw_rect(Rect2(ix + 1.0, iy + 1.0, 1.0, 1.0), c_cream)
	else:
		# Recessed inner press shadow + glowing warm cardinal channels
		draw_rect(Rect2(ix + 1.0, iy + 1.0, iw - 2.0, 1.0), c_wine)
		draw_rect(Rect2(ix + 2.0, iy + floorf(ih * 0.5), iw - 4.0, 1.0), c_gold)
		draw_rect(Rect2(floorf(ix + iw * 0.5), iy + 2.0, 1.0, ih - 4.0), c_gold)

	# Centre sigil: warm coral/gold lit diamond when pressed, crisp carved glyph when up
	var shape_i: int = 1 if powered else (3 if latch_mode else 0)
	var g_main: Color = c_gold if powered else c_dusk
	var g_hi: Color = c_cream if powered else c_stone
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, iy + floorf(ih * 0.5)), shape_i, powered, g_main, g_hi)
	_draw_signal_pulses()
