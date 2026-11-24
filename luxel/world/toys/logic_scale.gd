class_name LxScale
extends LxToy
## Two-pan balance scale comparing weight on `left` and `right` pans (or linked plate IDs).
## Props: left ([dx,dy] offset or plate id), right ([dx,dy] offset or plate id), pan_radius (float),
## mode ("balance"|"left_heavy"|"right_heavy"|"either"), need_weight (float, default 1.0), persist, target_id/target_ids.

var left_offset: Vector2 = Vector2(-28.0, 0.0)
var right_offset: Vector2 = Vector2(28.0, 0.0)
var left_plate_id: String = ""
var right_plate_id: String = ""
var pan_radius: float = 12.0
var mode: String = "balance"
var need_weight: float = 1.0

var left_weight: float = 0.0
var right_weight: float = 0.0
var tilt: float = 0.0
var solved: bool = false
var _vis_tilt: float = 0.0


func _toy_setup() -> void:
	kind = "scale"
	z_index = -5
	pan_radius = maxf(8.0, float(props.get("pan_radius", 12.0)))
	mode = str(props.get("mode", "balance")).strip_edges().to_lower()
	need_weight = maxf(0.5, float(props.get("need_weight", 1.0)))
	left_plate_id = ""
	right_plate_id = ""
	left_offset = _parse_pan_spec(props.get("left", [-28.0, 0.0]), Vector2(-28.0, 0.0), true)
	right_offset = _parse_pan_spec(props.get("right", [28.0, 0.0]), Vector2(28.0, 0.0), false)
	radius = maxf(left_offset.length(), right_offset.length()) + pan_radius
	solved = powered
	left_weight = 0.0
	right_weight = 0.0
	tilt = 0.0
	_vis_tilt = 0.0
	queue_redraw()


func _parse_pan_spec(v: Variant, fallback: Vector2, is_left: bool) -> Vector2:
	if v is String:
		if is_left:
			left_plate_id = str(v).strip_edges()
		else:
			right_plate_id = str(v).strip_edges()
		return fallback
	if v is Array or v is Vector2:
		var pt: Vector2 = LxMapFormat.to_vec2(v, fallback)
		if bool(props.get("world_coords", false)):
			return pt - pos
		return pt
	return fallback


func reset_toy() -> void:
	if persist and solved:
		return
	solved = false
	left_weight = 0.0
	right_weight = 0.0
	tilt = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var lw: float = _measure_pan(true)
	var rw: float = _measure_pan(false)
	var dirty: bool = not is_equal_approx(lw, left_weight) or not is_equal_approx(rw, right_weight)
	left_weight = lw
	right_weight = rw
	var diff: float = right_weight - left_weight
	tilt = clampf(diff * 0.5, -1.0, 1.0)
	if not is_equal_approx(_vis_tilt, tilt):
		_vis_tilt = move_toward(_vis_tilt, tilt, dt * 4.5)
		dirty = true
	var met: bool = _check_condition(left_weight, right_weight)
	if bool(props.get("latch", false)) and solved:
		met = true
	if met != solved:
		solved = met
		set_powered(solved)
		emit_power(solved)
		if solved:
			_emit_sfx("switch_eye")
		dirty = true
	if dirty:
		queue_redraw()


func _check_condition(lw: float, rw: float) -> bool:
	match mode:
		"left_heavy":
			return lw >= need_weight and lw > rw + 0.01
		"right_heavy":
			return rw >= need_weight and rw > lw + 0.01
		"either":
			return lw >= need_weight or rw >= need_weight
		_:
			return lw >= need_weight and rw >= need_weight and absf(lw - rw) <= 0.01


func _measure_pan(is_left: bool) -> float:
	var pid: String = left_plate_id if is_left else right_plate_id
	if not pid.is_empty() and region != null and region.has_method("find_interactable"):
		var found: Variant = region.call("find_interactable", pid)
		if found is LxPressurePlate:
			return float((found as LxPressurePlate).get("_press_weight"))
		if found is LxToy:
			return 1.0 if (found as LxToy).powered else 0.0
	var center: Vector2 = pos + (left_offset if is_left else right_offset)
	var rect := Rect2(center - Vector2(pan_radius, pan_radius), Vector2(pan_radius * 2.0, pan_radius * 2.0))
	var total: float = 0.0
	var wp: Vector2 = wick_pos()
	if rect.has_point(wp):
		var dead_w: bool = Lx.player != null and is_instance_valid(Lx.player) and bool(Lx.player.get("dead"))
		if not dead_w:
			total += 1.0
	if region != null and region.has_method("is_lantern_out") and bool(region.call("is_lantern_out")):
		var lp: Vector2 = region.call("get_lantern_pos") as Vector2 if region.has_method("get_lantern_pos") else Vector2(-9999.0, -9999.0)
		if rect.has_point(lp):
			total += 1.0
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or it_v == self:
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active:
				continue
			if LxPressurePlate._is_weight_interactable(it):
				if (it.is_solid() and it.get_solid_rect().intersects(rect)) or rect.has_point(it.pos):
					total += LxPressurePlate._interactable_weight(it)
			if it.has_method("is_echo_active") and bool(it.call("is_echo_active")):
				if rect.has_point(it.call("get_echo_pos") as Vector2):
					total += 1.0
	if region != null and region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if e_v is LxEnemyBrain and is_instance_valid(e_v):
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive() and not e.is_flying() and rect.has_point(e.pos):
					total += 1.0
	return total


func get_light_pool() -> Vector4:
	if not active or not solved:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 44.0, 0.72)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["solved"] = solved
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("solved"):
		solved = bool(d["solved"])
		powered = solved
		if solved:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)
	var lp: Vector2 = left_offset
	var rp: Vector2 = right_offset
	if not left_plate_id.is_empty() and region != null and region.has_method("find_interactable"):
		var li: Variant = region.call("find_interactable", left_plate_id)
		if li is LxInteractable:
			lp = (li as LxInteractable).pos - pos
	if not right_plate_id.is_empty() and region != null and region.has_method("find_interactable"):
		var ri: Variant = region.call("find_interactable", right_plate_id)
		if ri is LxInteractable:
			rp = (ri as LxInteractable).pos - pos

	# Connecting stone balance channel + tilting crossbar
	var l_drop: float = roundf(-_vis_tilt * 3.0)
	var r_drop: float = roundf(_vis_tilt * 3.0)
	var la: Vector2 = lp + Vector2(0.0, l_drop)
	var ra: Vector2 = rp + Vector2(0.0, r_drop)
	draw_line(lp, rp, PAL["night"] as Color, 3.0, false)
	draw_line(la, ra, c_glow if solved else trip[1], 1.0, false)

	# Pans (only draw local pans if not delegating to external plates)
	if left_plate_id.is_empty():
		_draw_pan(la, left_weight, c_glow)
	if right_plate_id.is_empty():
		_draw_pan(ra, right_weight, c_glow)

	# Central fulcrum indicator + tilt needle
	LxToyDraw.draw_bevel_box(self, Rect2(-5.0, -5.0, 10.0, 10.0), PAL["night"] as Color, trip[0], trip[2], c_void)
	var needle_x: float = roundf(_vis_tilt * 3.0)
	draw_rect(Rect2(-3.0, -7.0, 7.0, 2.0), c_void)
	draw_rect(Rect2(needle_x, -7.0, 1.0, 3.0), PAL["cream"] as Color if solved else (PAL["coral"] as Color))
	LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, 1 if solved else 0, solved, c_glow if solved else PAL["mauve"] as Color, PAL["cream"] as Color)
	_draw_signal_pulses()


func _draw_pan(center: Vector2, weight: float, c_glow: Color) -> void:
	var r: float = roundf(pan_radius)
	var rect := Rect2((center - Vector2(r, r)).round(), Vector2(r * 2.0, r * 2.0))
	var has_w: bool = weight > 0.0
	LxToyDraw.draw_bevel_box(
		self,
		rect,
		PAL["night"] as Color,
		PAL["dusk"] as Color if not has_w else LxBiomePalette.col(island_id, "dark"),
		c_glow if solved else (PAL["stone"] as Color if has_w else PAL["mauve"] as Color)
	)
	var pips: int = mini(4, int(roundf(weight)))
	for i: int in range(pips):
		var px: float = roundf(center.x - float(pips - 1) * 2.0 + float(i) * 4.0)
		draw_rect(Rect2(px - 1.0, roundf(center.y) - 1.0, 2.0, 2.0), PAL["cream"] as Color if solved else c_glow)
