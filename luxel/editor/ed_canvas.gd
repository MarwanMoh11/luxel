extends "res://luxel/editor/ed_pick.gd"
## The level view, part two: the mouse, and everything drawn over the room (grid, exits, vision, selection, wires, notes, ghost).


# ---- Input ----

func _gui_input(ev: InputEvent) -> void:
	if ed == null or ed.room == null:
		return
	if ev is InputEventPanGesture:
		cam.position += (ev as InputEventPanGesture).delta * 12.0 / zoom
		_keep_near()
		accept_event()
	elif ev is InputEventMagnifyGesture:
		set_zoom(zoom * (ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
		accept_event()
	elif ev is InputEventMouseButton:
		_button(ev as InputEventMouseButton)
		accept_event()
	elif ev is InputEventMouseMotion:
		_motion(ev as InputEventMouseMotion)
		accept_event()


func _button(b: InputEventMouseButton) -> void:
	mouse_w = s2w(b.position)
	match b.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if b.pressed: set_zoom(zoom * 1.12, b.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if b.pressed: set_zoom(zoom / 1.12, b.position)
		MOUSE_BUTTON_MIDDLE:
			_pan = b.pressed
		MOUSE_BUTTON_RIGHT:
			if b.pressed: _right(b)
		MOUSE_BUTTON_LEFT:
			if b.pressed:
				get_viewport().gui_release_focus()
				if Input.is_key_pressed(KEY_SPACE):
					_pan = true
				else:
					_left_down(b)
			else:
				if _pan:
					_pan = false
				_left_up()


func _right(_b: InputEventMouseButton) -> void:
	if ed.tool == ed.Tool.STAMP:
		if str(ed.stamp.get("type", "")) == "tile":
			var c: Vector2i = cell(mouse_w)
			ed.set_stamp_tile(ed.room.tile(c.x, c.y))
		else:
			ed.set_tool(ed.Tool.HAND)
		return
	var ref: Dictionary = pick(mouse_w)
	if not ref.is_empty():
		ed.stamp_copy(ref)
	else:
		var c2: Vector2i = cell(mouse_w)
		ed.set_stamp_tile(ed.room.tile(c2.x, c2.y))


func _left_down(b: InputEventMouseButton) -> void:
	_press_s = b.position
	_press_w = mouse_w
	_drag_d = Vector2.ZERO
	_press = ""
	match int(ed.tool):
		ed.Tool.STAMP:
			if str(ed.stamp.get("type", "")) == "tile":
				_press = "tiles"
				ed.room.begin()
				_last_cell = cell(mouse_w)
				_rect_from = _last_cell if b.shift_pressed else Vector2i(-99, -99)
				if not b.shift_pressed:
					_paint_line(_last_cell, _last_cell)
			else:
				ed.place(ed.stamp, ghost_pos())
		ed.Tool.ERASE:
			_press = "erase"
			ed.room.begin()
			_erase_here()
		ed.Tool.WIRE:
			var src: Dictionary = _pick_wireable()
			if not src.is_empty():
				_press = "wire"
				ed.wire_from = src
				ed.sfx("ui_move")
		ed.Tool.NOTE:
			var n: Dictionary = note_at(b.position)
			if not n.is_empty():
				ed.open_note(n)
			else:
				var ref: Dictionary = pick(mouse_w)
				ed.new_note(mouse_w, str(ed.room.item(ref).get("id", "")) if not ref.is_empty() else "")
		_:
			_hand_down(b)


func _hand_down(b: InputEventMouseButton) -> void:
	var n: Dictionary = note_at(b.position)
	if not n.is_empty():
		ed.open_note(n)
		return
	if b.double_click:
		var ex: Dictionary = exit_at(mouse_w)
		if not ex.is_empty():
			ed.travel(ex)
			return
	var h: Dictionary = _handle_at(b.position)
	if not h.is_empty():
		_press = "handle"
		_handle = h
		ed.room.begin()
		return
	if wick_rect().has_point(mouse_w):
		_press = "wick"
		return
	var cands: Array[Dictionary] = pick_all(mouse_w)
	if cands.is_empty():
		_press = "band"
		if not b.shift_pressed:
			ed.select([])
		return
	var ref: Dictionary = cands[0]
	if b.position.distance_to(_cycle_at) < 4.0 and cands.size() > 1 and ed.selection.size() <= 1 and not b.double_click:
		_cycle_i = (_cycle_i + 1) % cands.size()
		ref = cands[_cycle_i]
	else:
		_cycle_i = 0
		for c: Dictionary in cands:
			if is_selected(c):
				ref = c
				break
	_cycle_at = b.position
	if b.shift_pressed:
		ed.toggle_select(ref)
	elif not is_selected(ref):
		ed.select([ref])
	_press = "move"
	_drag_from.clear()
	for s: Dictionary in ed.selection:
		_drag_from.append(Io.vec(ed.room.item(s).get("pos", [0, 0])))


func _motion(m: InputEventMouseMotion) -> void:
	mouse_w = s2w(m.position)
	if _pan:
		cam.position -= m.relative / zoom
		_keep_near()
		return
	match _press:
		"tiles":
			if _rect_from.x < -90:
				var c: Vector2i = cell(mouse_w)
				if c != _last_cell:
					_paint_line(_last_cell, c)
					_last_cell = c
			else:
				_last_cell = cell(mouse_w)
		"erase":
			_erase_here()
		"move":
			if _drag_d == Vector2.ZERO and m.position.distance_to(_press_s) < 5.0:
				return
			_drag_to()
		"wick":
			ed.world.place_wick(mouse_w)
		"handle":
			var p: Vector2 = snap(mouse_w, 8.0)
			var it: Dictionary = ed.room.item(_handle["ref"] as Dictionary)
			(it[str(_handle["k"])] as Array)[int(_handle["n"])] = Io.arr(p)
		_:
			hover = pick(mouse_w) if ed.tool != ed.Tool.STAMP else {}
			_hint()


func _hint() -> void:
	var ex: Dictionary = exit_at(mouse_w)
	if ed.tool == ed.Tool.HAND and not ex.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif ed.tool == ed.Tool.HAND and not hover.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif ed.tool in [ed.Tool.STAMP, ed.Tool.WIRE, ed.Tool.NOTE]:
		mouse_default_cursor_shape = Control.CURSOR_CROSS
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _left_up() -> void:
	match _press:
		"tiles":
			if _rect_from.x > -90:
				_fill_rect(_rect_from, _last_cell)
			ed.commit_tiles()
		"erase":
			ed.commit_erase()
		"move":
			if _drag_d != Vector2.ZERO:
				ed.move_selection(_drag_d)
		"handle":
			if ed.room.commit({"op": "patrol", "what": ed.room.item(_handle["ref"] as Dictionary).get("id", "")}):
				ed.after_edit()
		"wire":
			var dst: Dictionary = _pick_wireable()
			if not dst.is_empty() and not _same(dst, ed.wire_from):
				ed.toggle_wire(ed.wire_from, dst)
			ed.wire_from = {}
		"band":
			var r: Rect2 = Rect2(_press_w, Vector2.ZERO).expand(mouse_w)
			if r.size.x > 4.0 or r.size.y > 4.0:
				ed.select(_in_rect(r))
	_press = ""
	_drag_d = Vector2.ZERO
	_rect_from = Vector2i(-99, -99)


func _in_rect(r: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: String in PICK_LISTS:
		var a: Array = ed.room.list(l)
		for i: int in range(a.size()):
			if r.has_point(Io.vec((a[i] as Dictionary).get("pos", [-999, -999]))):
				out.append({"list": l, "i": i})
	return out


func _drag_to() -> void:
	if ed.selection.is_empty():
		return
	var first: Dictionary = ed.selection[0]
	var step: float = snap_step(str(first["list"]))
	var d: Vector2 = mouse_w - _press_w
	_drag_d = snap(_drag_from[0] + d, step) - _drag_from[0] if ed.room.item(first).has("pos") else snap(d, step)
	for i: int in range(ed.selection.size()):
		var node: Node2D = ed.node_of(ed.selection[i])
		if node != null:
			node.position = (_drag_from[i] + _drag_d).round()


func _brush_cells(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = int(ed.brush)
	var off: int = (n - 1) / 2
	for y: int in range(n):
		for x: int in range(n):
			out.append(c + Vector2i(x - off, y - off))
	return out


func _paint_line(a: Vector2i, b: Vector2i) -> void:
	var n: int = maxi(1, maxi(absi(b.x - a.x), absi(b.y - a.y)))
	var hit: bool = false
	for i: int in range(n + 1):
		var c: Vector2i = Vector2i(roundi(lerpf(a.x, b.x, float(i) / n)), roundi(lerpf(a.y, b.y, float(i) / n)))
		for k: Vector2i in _brush_cells(c):
			hit = ed.room.set_tile(k.x, k.y, str(ed.stamp["kind"])) or hit
	if hit:
		ed.sfx("footstep_stone", 0.06)
		ed.world.patch.queue_redraw()


func _fill_rect(a: Vector2i, b: Vector2i) -> void:
	for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			ed.room.set_tile(x, y, str(ed.stamp["kind"]))


func _erase_here() -> void:
	var ref: Dictionary = pick(mouse_w)
	if not ref.is_empty():
		pop(rect_of(ref).get_center(), "coral")
		ed.erase_now(ref)


func _pick_wireable() -> Dictionary:
	for r: Dictionary in pick_all(mouse_w):
		if str(r["list"]) == "interactables":
			return r
	return {}


func ghost_pos() -> Vector2:
	return snap(mouse_w, snap_step(str(ed.stamp.get("type", ""))))


func wick_rect() -> Rect2:
	return Rect2(ed.world.wick.global_position - Vector2(8, 16), Vector2(16, 20))


func _handles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in ed.selection:
		if str(s["list"]) == "enemies":
			var it: Dictionary = ed.room.item(s)
			for k: String in ["route", "perches"]:
				if it.get(k) is Array:
					for n: int in range((it[k] as Array).size()):
						if (it[k] as Array)[n] is Array:
							out.append({"ref": s, "k": k, "n": n, "pos": Io.vec((it[k] as Array)[n])})
	return out


func _handle_at(s: Vector2) -> Dictionary:
	for h: Dictionary in _handles():
		if w2s(h["pos"] as Vector2).distance_to(s) < 9.0:
			return h
	return {}


# ---- Drawing ----

func _draw() -> void:
	if ed == null or ed.room == null or cam == null:
		return
	var px: Vector2 = ed.room.px_size()
	var full: Rect2 = r2s(Rect2(Vector2.ZERO, px))
	if grid_on and zoom >= 1.4:
		_draw_grid(px)
	draw_rect(full.grow(2.0), Style.col("gold", 0.5), false, 2.0)
	_draw_exits()
	if ed.vision_on:
		_draw_vision()
	if ed.tool == ed.Tool.WIRE or not ed.selection.is_empty():
		_draw_wires()
	_draw_selection()
	_draw_wick()
	_draw_notes()
	_draw_tool()
	for p: Dictionary in _pop:
		var k: float = float(p["t"]) / 0.35
		draw_arc(w2s(p["pos"] as Vector2), (6.0 + 16.0 * k) * zoom * 0.5, 0, TAU, 24, Style.col(str(p["col"]), 1.0 - k), 3.0 * (1.0 - k) + 0.5)


func _draw_grid(px: Vector2) -> void:
	var ts: float = float(ed.room.ts)
	var c: Color = Style.col("cream", 0.09 if zoom < 3.0 else 0.13)
	for x: int in range(int(px.x / ts) + 1):
		var a: Vector2 = w2s(Vector2(x * ts, 0))
		draw_line(a, a + Vector2(0, px.y * zoom), c, 1.0)
	for y: int in range(int(px.y / ts) + 1):
		var b: Vector2 = w2s(Vector2(0, y * ts))
		draw_line(b, b + Vector2(px.x * zoom, 0), c, 1.0)


func _tag(p: Vector2, text: String, bg: Color, fg: Color = Color("fff4dc"), center: bool = true) -> void:
	var f: Font = get_theme_default_font()
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var r := Rect2(p + Vector2(-w * 0.5 - 6.0 if center else 0.0, -10.0), Vector2(w + 12.0, 20.0))
	r.position = r.position.clamp(Vector2(4, 60), size - r.size - Vector2(4, 4))
	draw_style_box(Style.box(bg, Color.TRANSPARENT, 0, 0, 5), r)
	draw_string(f, r.position + Vector2(6, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, fg)


func _draw_exits() -> void:
	var a: Array = ed.room.list("exits")
	for i: int in range(a.size()):
		var r: Rect2 = r2s(rect_of({"list": "exits", "i": i}))
		var hot: bool = r.grow(6.0).has_point(w2s(mouse_w)) and ed.tool == ed.Tool.HAND
		draw_rect(r, Style.col("lime", 0.32 if hot else 0.16))
		draw_rect(r, Style.col("lime", 0.9 if hot else 0.5), false, 2.0)
		if hot:
			_tag(r.get_center(), "To %s  (double-click to go)" % ed.room_title_of(a[i] as Dictionary), Style.col("teal"))


func _draw_wires() -> void:
	var items: Array = ed.room.list("interactables")
	var sel: Dictionary = {}
	for s: Dictionary in ed.selection:
		if str(s["list"]) == "interactables":
			sel[int(s["i"])] = true
	for w: Dictionary in ed.room.wires():
		if ed.tool != ed.Tool.WIRE and not sel.has(int(w["from"])) and not sel.has(int(w["to"])):
			continue
		var p0: Vector2 = w2s(Io.vec((items[int(w["from"])] as Dictionary).get("pos", [0, 0])))
		var p1: Vector2 = w2s(Io.vec((items[int(w["to"])] as Dictionary).get("pos", [0, 0])))
		_wire(p0, p1, Style.col("gold"))
	if _press == "wire" and not ed.wire_from.is_empty():
		_wire(w2s(Io.vec(ed.room.item(ed.wire_from).get("pos", [0, 0]))), w2s(mouse_w), Style.col("lime"))


func _wire(a: Vector2, b: Vector2, c: Color) -> void:
	var mid: Vector2 = (a + b) * 0.5 + Vector2(0, -minf(40.0, a.distance_to(b) * 0.18))
	var pts := PackedVector2Array()
	for i: int in range(17):
		var t: float = i / 16.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, Style.col("void", 0.7), 5.0)
	draw_polyline(pts, c, 2.5)
	for k: int in range(3):
		var tt: float = fposmod(_t * 0.5 + k / 3.0, 1.0)
		var q: Vector2 = a.lerp(mid, tt).lerp(mid.lerp(b, tt), tt)
		draw_circle(q, 3.5, Style.col("cream"))
	var d: Vector2 = (pts[16] - pts[14]).normalized()
	draw_colored_polygon(PackedVector2Array([b, b - d * 12.0 + d.orthogonal() * 6.0, b - d * 12.0 - d.orthogonal() * 6.0]), c)


func _draw_selection() -> void:
	if not hover.is_empty() and _press.is_empty() and ed.tool in [ed.Tool.HAND, ed.Tool.ERASE, ed.Tool.NOTE]:
		var hit: Dictionary = ed.room.item(hover)
		if not hit.is_empty() and not is_selected(hover):
			var hr: Rect2 = r2s(rect_of(hover)).grow(2.0)
			var hc: Color = Style.col("coral") if ed.tool == ed.Tool.ERASE else Style.col("cream")
			draw_rect(hr, Color(hc, 0.75), false, 2.0)
			_tag(Vector2(hr.get_center().x, hr.position.y - 14.0), ed.catalog.name_of(str(hover["list"]), hit), Style.col("night", 0.9))
	for s: Dictionary in ed.selection:
		if ed.room.item(s).is_empty():
			continue
		var r: Rect2 = r2s(rect_of(s)).grow(3.0)
		if _press == "move":
			r.position += _drag_d * zoom
		draw_rect(r, Style.col("gold"), false, 2.5)
		var pr: Vector2 = Vector2(5, 5)
		for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			draw_rect(Rect2(c - pr * 0.5, pr), Style.col("cream"))
		if _press == "move" and _drag_d != Vector2.ZERO:
			_tag(Vector2(r.get_center().x, r.position.y - 14.0), "%+d, %+d" % [int(_drag_d.x), int(_drag_d.y)], Style.col("night", 0.9), Style.col("gold"))
		if str(s["list"]) == "enemies":
			_draw_enemy_range(s)


func _draw_vision() -> void:
	## The intended way through: a dashed walk and numbered steps.
	var v: Dictionary = ed.vision.cached(ed.room)
	var path: Array = v["path"] as Array
	for i: int in range(1, path.size()):
		var a: Vector2 = w2s(path[i - 1] as Vector2)
		var b: Vector2 = w2s(path[i] as Vector2)
		if a.distance_to(b) > 2.0:
			draw_dashed_line(a, b, Style.col("void", 0.6), 5.0, 9.0)
			draw_dashed_line(a, b, Style.col("sky", 0.9), 2.5, 9.0)
	if not path.is_empty():
		draw_circle(w2s(path[0] as Vector2), 6.0, Style.col("sky"))
	var f: Font = get_theme_default_font()
	var used: Dictionary = {}
	var hot: Dictionary = {}
	for s: Dictionary in v["steps"] as Array:
		var at: Vector2 = w2s(s["pos"] as Vector2)
		var from: Vector2 = w2s(s["from"] as Vector2)
		if from.distance_to(at) > 14.0 and not str(s["text"]).begins_with("Beat"):
			draw_line(from, at, Style.col("ice", 0.45), 1.5)
		var slot := Vector2i((at / 22.0).round())
		var k: int = int(used.get(slot, 0))
		used[slot] = k + 1
		at += Vector2(float(k % 4) * 21.0, -14.0 - float(k / 4) * 21.0)
		s["at"] = at
		var on: bool = int(s["n"]) == int(ed.hot_step) or at.distance_to(w2s(mouse_w)) < 11.0
		var c: Color = Style.col("coral") if bool(s["lost"]) else (Style.col("gold") if on else Style.col("ice"))
		draw_circle(at, 13.0 if on else 11.5, Style.col("void", 0.85))
		draw_circle(at, 11.5 if on else 10.0, c)
		draw_string(f, at + Vector2(-12, 5), "!" if bool(s["lost"]) else str(s["n"]), HORIZONTAL_ALIGNMENT_CENTER, 24, 13, Style.col("night"))
		if on:
			hot = s
	if not hot.is_empty():
		_tag((hot["at"] as Vector2) + Vector2(0, -26), "%d. %s%s" % [int(hot["n"]), str(hot["text"]), " (it is gone)" if bool(hot["lost"]) else ""], Style.col("night", 0.96), Style.col("gold"))


func _draw_enemy_range(s: Dictionary) -> void:
	var it: Dictionary = ed.room.item(s)
	var p: Vector2 = Io.vec(it.get("pos", [0, 0])) + (_drag_d if _press == "move" else Vector2.ZERO)
	var leash: float = float(it.get("leash", 0))
	if leash > 0.0:
		draw_arc(w2s(p), leash * zoom, 0, TAU, 64, Style.col("coral", 0.5), 2.0)
	var prev: Vector2 = w2s(p)
	if it.get("route") is Array:
		for q_v: Variant in (it["route"] as Array):
			var q: Vector2 = w2s(Io.vec(q_v))
			draw_dashed_line(prev, q, Style.col("gold", 0.8), 2.0, 6.0)
			prev = q
	for h: Dictionary in _handles():
		if _same(h["ref"] as Dictionary, s):
			draw_circle(w2s(h["pos"] as Vector2), 7.0, Style.col("night"))
			draw_circle(w2s(h["pos"] as Vector2), 5.0, Style.col("gold") if str(h["k"]) == "route" else Style.col("ice"))


func _draw_wick() -> void:
	var r: Rect2 = r2s(wick_rect())
	var bob: float = sin(_t * 3.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(r.get_center().x - 7, r.position.y - 16 + bob), Vector2(r.get_center().x + 7, r.position.y - 16 + bob), Vector2(r.get_center().x, r.position.y - 5 + bob)]), Style.col("gold"))
	if r.has_point(w2s(mouse_w)) and ed.tool == ed.Tool.HAND:
		draw_rect(r, Style.col("gold"), false, 2.0)
		_tag(Vector2(r.get_center().x, r.position.y - 30.0), "Wick: drag me where you want to start", Style.col("night", 0.9), Style.col("gold"))


func _draw_notes() -> void:
	var f: Font = get_theme_default_font()
	for n: Dictionary in ed.notes.of_room(ed.room.key()):
		var p: Vector2 = w2s(Io.vec(n["pos"]))
		var done: bool = str(n.get("status", "open")) == "done"
		var c: Color = Style.col("jade") if done else Style.col("gold")
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(-6, -10), p + Vector2(6, -10)]), c)
		draw_style_box(Style.box(c, Style.col("night"), 0, 0, 6, 2), Rect2(p + Vector2(-13, -34), Vector2(26, 25)))
		draw_string(f, p + Vector2(-13, -16), str(n.get("id", "")), HORIZONTAL_ALIGNMENT_CENTER, 26, 14, Style.col("night"))
		if Rect2(p + Vector2(-13, -34), Vector2(26, 36)).has_point(w2s(mouse_w)):
			_tag(p + Vector2(0, -48), str(n.get("text", "")).left(70), Style.col("night", 0.95))


func _draw_tool() -> void:
	if not _inside and _press.is_empty():
		return
	match int(ed.tool):
		ed.Tool.STAMP:
			if str(ed.stamp.get("type", "")) == "tile":
				_draw_tile_ghost()
			else:
				var th: Dictionary = ed.thumbs.get_thumb(ed.stamp)
				var p: Vector2 = ghost_pos()
				if not th.is_empty():
					draw_texture_rect(th["tex"] as Texture2D, r2s(Rect2(p + (th["rect"] as Rect2).position, (th["rect"] as Rect2).size)), false, Color(1, 1, 1, 0.75))
				var s: Vector2 = w2s(p)
				draw_line(s - Vector2(6, 0), s + Vector2(6, 0), Style.col("gold"), 2.0)
				draw_line(s - Vector2(0, 6), s + Vector2(0, 6), Style.col("gold"), 2.0)
		ed.Tool.WIRE:
			var r: Dictionary = _pick_wireable()
			if not r.is_empty():
				draw_rect(r2s(rect_of(r)).grow(3.0), Style.col("lime"), false, 2.5)
		ed.Tool.HAND:
			if _press == "band":
				var br: Rect2 = r2s(Rect2(_press_w, Vector2.ZERO).expand(mouse_w))
				draw_rect(br, Style.col("sky", 0.18))
				draw_rect(br, Style.col("sky"), false, 1.5)


func _draw_tile_ghost() -> void:
	var ts: float = float(ed.room.ts)
	var cells: Array[Vector2i] = []
	if _rect_from.x > -90:
		for y: int in range(mini(_rect_from.y, _last_cell.y), maxi(_rect_from.y, _last_cell.y) + 1):
			for x: int in range(mini(_rect_from.x, _last_cell.x), maxi(_rect_from.x, _last_cell.x) + 1):
				cells.append(Vector2i(x, y))
	else:
		cells = _brush_cells(cell(mouse_w))
	var th: Dictionary = ed.thumbs.get_thumb(ed.stamp)
	for c: Vector2i in cells:
		var r: Rect2 = r2s(Rect2(Vector2(c) * ts, Vector2(ts, ts)))
		if not th.is_empty():
			draw_texture_rect(th["tex"] as Texture2D, r, false, Color(1, 1, 1, 0.55))
		draw_rect(r, Style.col("gold"), false, 1.5)
