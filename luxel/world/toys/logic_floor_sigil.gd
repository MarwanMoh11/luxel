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
		if bool(Lx.player.get("dead")) or (Lx.player.has_method("is_gliding") and bool(Lx.player.call("is_gliding"))):
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
	if absf(rel.x - center.x) <= cell_size * 0.45 and absf(rel.y - center.y) <= cell_size * 0.45:
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
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_hi: Color = LxBiomePalette.col(island_id, "hi")
	var c_dark: Color = LxBiomePalette.col(island_id, "dark")
	var cs: float = roundf(cell_size)
	var half: float = floorf(cs * 0.5)

	for c: Vector2i in cells:
		var center := Vector2(float(c.x) * cs, float(c.y) * cs)
		var rect := Rect2(center.x - half + 1.0, center.y - half + 1.0, cs - 2.0, cs - 2.0)
		var is_lit: bool = solved or visited.has(c)
		var is_err: bool = _error_t > 0.0
		var fill: Color = (PAL["coral"] as Color) if is_err else (c_hi if solved else (c_dark if is_lit else PAL["night"] as Color))
		var rim: Color = (PAL["cream"] as Color) if solved else (c_glow if is_lit else PAL["dusk"] as Color)
		LxToyDraw.draw_bevel_box(self, rect, PAL["night"] as Color, fill, rim, c_void)
		if is_lit:
			draw_rect(Rect2(center.x - 2.0, center.y - 2.0, 4.0, 4.0), PAL["cream"] as Color if solved else c_glow)
		elif has_start and c == start_cell:
			LxToyDraw.draw_shape_glyph(self, center, 2, false, c_glow, PAL["cream"] as Color)
		else:
			draw_rect(Rect2(center.x - 1.0, center.y - 1.0, 2.0, 2.0), PAL["dusk"] as Color)

	# Connected line along visited sequence
	for i: int in range(visited.size() - 1):
		var a := Vector2(float(visited[i].x) * cs, float(visited[i].y) * cs)
		var b := Vector2(float(visited[i + 1].x) * cs, float(visited[i + 1].y) * cs)
		draw_line(a, b, PAL["cream"] as Color if solved else c_glow, 2.0, false)
	_draw_signal_pulses()
