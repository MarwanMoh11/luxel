class_name LxFloorSigil
extends LxToy
## One-line floor path puzzle: walk every cell in `cells` once without revisiting or stepping off.
## Stepping onto a revisited cell or off the grid before completion resets cleanly (zero softlock).
## Props: cells (Array of [gx,gy]), cell_size (float, default 16.0), start ([gx,gy] optional), persist, target_id/target_ids.

var cells: Array[Vector2i] = []
var cell_size: float = 16.0
var has_start: bool = false
var start_cell: Vector2i = Vector2i.ZERO
var visited: Array[Vector2i] = []
var solved: bool = false
var _error_t: float = 0.0
var _cell_set: Dictionary = {}
var _inside_grid: bool = false


func _toy_setup() -> void:
	kind = "floor_sigil"
	z_index = -5
	cell_size = maxf(10.0, float(props.get("cell_size", 16.0)))
	cells.clear()
	_cell_set.clear()
	var raw: Variant = props.get("cells", [[0, 0], [1, 0], [2, 0], [2, 1], [1, 1], [0, 1]])
	if raw is Array:
		for item: Variant in (raw as Array):
			if item is Array and (item as Array).size() >= 2:
				var c := Vector2i(int((item as Array)[0]), int((item as Array)[1]))
				if not _cell_set.has(c):
					_cell_set[c] = true
					cells.append(c)
	if cells.is_empty():
		for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			_cell_set[c] = true
			cells.append(c)
	has_start = props.has("start") and props.get("start") is Array and (props.get("start") as Array).size() >= 2
	if has_start:
		var sa: Array = props.get("start") as Array
		start_cell = Vector2i(int(sa[0]), int(sa[1]))
	else:
		start_cell = cells[0]
	var max_d: float = cell_size
	for c: Vector2i in cells:
		max_d = maxf(max_d, (Vector2(c) * cell_size).length() + cell_size)
	radius = max_d
	visited.clear()
	solved = powered
	if solved:
		visited = cells.duplicate()
	_error_t = 0.0
	_inside_grid = false
	queue_redraw()


func reset_toy() -> void:
	if persist and solved:
		return
	visited.clear()
	solved = false
	_inside_grid = false
	_error_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func cell_world_center(c: Vector2i) -> Vector2:
	return pos + Vector2(float(c.x) * cell_size, float(c.y) * cell_size)


func tick(dt: float) -> void:
	super.tick(dt)
	if _error_t > 0.0:
		_error_t = maxf(0.0, _error_t - dt)
		queue_redraw()
	if not active or solved:
		return
	var wp: Vector2 = wick_pos()
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player.get("dead") == true or (Lx.player.has_method("is_gliding") and bool(Lx.player.call("is_gliding"))):
			return
	var stepped: Vector2i = _cell_at_point(wp)
	if _cell_set.has(stepped):
		_inside_grid = true
		_step_cell(stepped)
	elif _inside_grid:
		_inside_grid = false
		if not visited.is_empty() and not solved:
			_fail_reset()


func _cell_at_point(world_p: Vector2) -> Vector2i:
	var rel: Vector2 = world_p - pos
	var gx: int = int(roundf(rel.x / cell_size))
	var gy: int = int(roundf(rel.y / cell_size))
	var center: Vector2 = Vector2(float(gx) * cell_size, float(gy) * cell_size)
	if absf(rel.x - center.x) <= cell_size * 0.52 and absf(rel.y - center.y) <= cell_size * 0.52:
		return Vector2i(gx, gy)
	return Vector2i(-9999, -9999)


func _step_cell(c: Vector2i) -> void:
	if visited.is_empty():
		if has_start and c != start_cell:
			return
		visited.append(c)
		_emit_sfx("prop_chime")
		_check_complete()
		queue_redraw()
		return
	var last: Vector2i = visited[visited.size() - 1]
	if c == last:
		return
	var manhattan: int = absi(c.x - last.x) + absi(c.y - last.y)
	if manhattan == 1 and not visited.has(c):
		visited.append(c)
		_emit_sfx("prop_chime")
		_check_complete()
		queue_redraw()
	elif visited.size() >= 2 and c == visited[visited.size() - 2]:
		# Friendly single-step undo if the player steps back onto previous tile
		visited.pop_back()
		_emit_sfx("footstep_stone")
		queue_redraw()
	else:
		_fail_reset()


func _check_complete() -> void:
	if visited.size() < cells.size():
		return
	solved = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("switch_eye")
	_emit_gust(64.0, 40.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 72.0, 0.72 if LxHudFx.flash_reduced() else 1.10, 0.36)


func _fail_reset() -> void:
	visited.clear()
	_error_t = 0.30
	_emit_sfx("denied")
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active or (visited.is_empty() and not solved):
		return Vector4.ZERO
	var last_c: Vector2i = visited[visited.size() - 1] if not visited.is_empty() else cells[0]
	var lp: Vector2 = cell_world_center(last_c)
	return Vector4(lp.x, lp.y, 44.0 if solved else 32.0, 0.75 if solved else 0.45)


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
			visited = cells.duplicate()
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
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
	var cs: float = roundf(cell_size)
	var half: float = floorf(cs * 0.5)
	var is_err: bool = _error_t > 0.0
	var reduced: bool = LxHudFx.flash_reduced()
	var tip_cell: Vector2i = visited[visited.size() - 1] if not visited.is_empty() else Vector2i(-9999, -9999)

	for c: Vector2i in cells:
		var center := Vector2(roundf(float(c.x) * cs), roundf(float(c.y) * cs))
		var rx: float = center.x - half + 1.0
		var ry: float = center.y - half + 1.0
		var rw: float = cs - 2.0
		var rh: float = cs - 2.0
		var is_lit: bool = solved or visited.has(c)
		var is_tip: bool = (not solved) and (not visited.is_empty()) and c == tip_cell

		# Grounded recessed drop lip so each stone medallion stands out cleanly on dusk floors
		draw_rect(Rect2(rx + 1.0, ry + rh, rw - 1.0, 1.0), Color(c_void, 0.36))

		var frame_dark: Color = c_wine if is_err else (c_apricot if solved else (c_wine if is_lit else c_dusk))
		var frame_mid: Color = c_coral if is_err else (c_gold if solved else (c_apricot if is_lit else c_mauve))
		var frame_hi: Color = c_apricot if is_err else (c_cream if solved else (c_gold if is_lit else c_stone))
		LxToyDraw.draw_bevel_box(self, Rect2(rx, ry, rw, rh), frame_dark, frame_mid, frame_hi, c_void)

		# Inner carved medallion bed
		var inset: float = 3.0
		var bed_c: Color = c_wine if is_err else (c_apricot if solved else (c_dusk if is_lit else c_night))
		if rw > inset * 2.0 + 2.0:
			draw_rect(Rect2(rx + inset, ry + inset, rw - inset * 2.0, rh - inset * 2.0), bed_c)

		# Corner inlay rivets (high contrast stone / gold / cream)
		var stud_c: Color = c_cream if solved else (c_gold if is_lit else c_stone)
		for sx: float in [rx + 2.0, rx + rw - 3.0]:
			for sy: float in [ry + 2.0, ry + rh - 3.0]:
				draw_rect(Rect2(sx, sy, 1.0, 1.0), stud_c)

		# Inner carved diamond rune (ember when visited, luminous gold/cream when solved, crisp stone idle)
		if is_err:
			LxToyDraw.draw_shape_glyph(self, center, 1, true, c_coral, c_apricot)
		elif solved:
			LxToyDraw.draw_shape_glyph(self, center, 1, true, c_gold, c_cream)
		elif is_lit:
			var ember_hi: Color = c_cream if is_tip else c_gold
			LxToyDraw.draw_shape_glyph(self, center, 1, true, c_apricot, ember_hi)
		elif has_start and c == start_cell:
			var start_hi: Color = c_cream if (reduced or int(floorf(_clock * 3.0)) % 2 == 0) else c_gold
			LxToyDraw.draw_shape_glyph(self, center, 2, false, c_apricot, start_hi)
		else:
			LxToyDraw.draw_shape_glyph(self, center, 1, false, c_stone, c_mauve)

	# Connected luminous rune thread along visited sequence
	for i: int in range(visited.size() - 1):
		var a := Vector2(roundf(float(visited[i].x) * cs), roundf(float(visited[i].y) * cs))
		var b := Vector2(roundf(float(visited[i + 1].x) * cs), roundf(float(visited[i + 1].y) * cs))
		draw_line(a, b, c_void, 4.0, false)
		draw_line(a, b, c_gold if solved else c_apricot, 2.0, false)
		draw_line(a, b, c_cream if solved else c_gold, 1.0, false)

	# Re-stamp bright diamond heart nodes over link junctions so runes read crisp
	for c: Vector2i in visited:
		var vc := Vector2(roundf(float(c.x) * cs), roundf(float(c.y) * cs))
		draw_rect(Rect2(vc.x - 1.0, vc.y - 1.0, 3.0, 3.0), c_cream if solved else c_gold)
		if (not solved) and c == tip_cell:
			draw_rect(Rect2(vc, Vector2.ONE), c_cream)
	_draw_signal_pulses()
