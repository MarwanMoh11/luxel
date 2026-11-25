extends "res://luxel/editor/ed_core.gd"
## Luxel level editor. Runs the real game underneath: edit the room you see, press B to play it, B to edit again.
## Saves straight into luxel/islands; keeps Claude's originals, the hand-edited versions, notes and a log in docs/level_edits.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	main = (load("res://luxel/luxel.tscn") as PackedScene).instantiate() as LxMain
	add_child(main)
	world = World.new()
	add_child(world)
	world.boot(main)
	catalog = Catalog.new()
	catalog.build()
	notes = Notes.new()
	notes.load_all()
	thumbs = Thumbs.new()
	thumbs.catalog = catalog
	add_child(thumbs)
	cam = Camera2D.new()
	cam.name = "EditCamera"
	add_child(cam)
	_build_ui()
	world.paint_started.connect(func() -> void: _status("Painting..."))
	world.paint_finished.connect(_on_painted)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("windowed"):
		get_window().mode = Window.MODE_MAXIMIZED
	get_window().title = "Luxel Level Editor"
	var s: Dictionary = Io.read_json(SESSION, {}) as Dictionary
	var key: String = str(s.get("room", "1:overworld"))
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("room=") and a.contains(":"):
			key = a.trim_prefix("room=")
	_enter_edit()
	_help.visible = not bool(s.get("seen_help", false))
	if not open_room(int(key.get_slice(":", 0)), key.get_slice(":", 1)):
		open_room(1, "overworld")


# ---- Layout ----

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 60
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Style.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	canvas = Canvas.new()
	canvas.ed = self
	canvas.cam = cam
	root.add_child(canvas)
	root.add_child(_build_top())
	_palette = Palette.new()
	root.add_child(_palette)
	_palette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_palette.offset_top = -BOTTOM_H
	_palette.setup(self)
	_side = SideCard.new()
	root.add_child(_side)
	_side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_side.offset_left = -292.0
	_side.offset_right = -10.0
	_side.offset_top = TOP_H + 10.0
	_side.offset_bottom = -BOTTOM_H - 10.0
	_side.setup(self)
	_toast = Style.label("", 16, "cream")
	_toast.add_theme_stylebox_override("normal", Style.box(Style.col("night", 0.95), Style.col("gold"), 0, 10, 8, 1))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	root.add_child(_toast)
	_note_box = _build_note_box()
	root.add_child(_note_box)
	_help = _build_help()
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_help)
	root.add_child(mid)
	_browser = Browser.new()
	root.add_child(_browser)
	_browser.setup(self)
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 61
	_hint_layer.visible = false
	add_child(_hint_layer)
	_hint_root = Style.Pix.new("B: EDIT", 1, Style.col("gold"), HORIZONTAL_ALIGNMENT_RIGHT)
	_hint_root.position = Vector2(320 - 40, 170)
	_hint_root.modulate.a = 0.75
	_hint_layer.add_child(_hint_root)


func _build_top() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.col("night", 0.98), Style.col("plum"), 0, 7, 0))
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.custom_minimum_size = Vector2(0, TOP_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	h.add_child(Style.button("Rooms", "rooms", "Every room in the game (M)", func() -> void: _browser.open()))
	_title = Style.label("", 18, "cream")
	h.add_child(_title)
	_sub = Style.label("", 13, "mauve")
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub.clip_text = true
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(_sub)
	_saved = Style.label("Saved", 13, "jade")
	_saved.custom_minimum_size = Vector2(86, 0)
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_saved)
	_undo_btn = Style.button("", "undo", "Undo (Cmd+Z)", undo)
	h.add_child(_undo_btn)
	_redo_btn = Style.button("", "redo", "Redo (Cmd+Shift+Z)", redo)
	h.add_child(_redo_btn)
	h.add_child(Style.button("", "grid", "Grid (G)", func() -> void: canvas.grid_on = not canvas.grid_on))
	h.add_child(Style.button("", "fit", "See the whole room (F)", func() -> void: canvas.fit()))
	h.add_child(Style.button(" ? ", "", "How this works", func() -> void: _help.visible = not _help.visible))
	var play: Button = Style.tint(Style.button("  PLAY  ", "play", "Play this room from where Wick stands (B or Enter)", toggle_play), "lime", "night", "teal")
	play.add_theme_font_size_override("font_size", 18)
	h.add_child(play)
	return p


func _build_note_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(380, 0)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	_note_head = Style.label("", 14, "gold")
	v.add_child(_note_head)
	_note_text = TextEdit.new()
	_note_text.custom_minimum_size = Vector2(360, 96)
	_note_text.placeholder_text = "Tell Claude what you want here. Cmd+Enter to save."
	_note_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note_text.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ENTER and (ev as InputEventKey).is_command_or_control_pressed():
			_note_text.accept_event()
			_save_note())
	v.add_child(_note_text)
	_note_reply = Style.label("", 13, "jade", true)
	v.add_child(_note_reply)
	var h := HBoxContainer.new()
	v.add_child(h)
	var ok: Button = Style.tint(Style.button("Save note", "check", "", _save_note), "gold")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ok)
	h.add_child(Style.button("Delete", "trash", "", func() -> void:
		if _note_cur.has("id"):
			notes.remove(int(_note_cur["id"]))
		_close_note()
		_side.refresh()))
	h.add_child(Style.button("", "close", "", _close_note))
	return p


func _build_help() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.col("night"), Style.col("gold"), 0, 18, 10, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Style.Pix.new("LEVEL EDITOR", 4, Style.col("gold")))
	for r: Array in [
		["hand", "Drag anything to move it. Click it to change its settings on the right."],
		["brush", "Pick something from the bottom bar, then click in the room to place it."],
		["copy", "Right-click any thing or tile to pick up a copy. Esc lets go."],
		["wire", "Wire: drag from a switch to a door, and the switch opens it."],
		["note", "Note: pin a message for Claude anywhere in the room."],
		["play", "B plays the room from where Wick stands. B again comes back to edit."],
		["rooms", "Rooms shows all 466 rooms. Double-click a green exit to walk through it."],
		["heart", "Love it / Needs work: your verdict tells Claude what to keep and what to fix."],
		["undo", "Cmd+Z undoes anything. Everything saves by itself."],
	]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var ic := TextureRect.new()
		ic.texture = Style.icon(str(r[0]), 2)
		ic.modulate = Style.col("gold")
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(26, 26)
		h.add_child(ic)
		h.add_child(Style.label(str(r[1]), 15, "cream"))
		v.add_child(h)
	v.add_child(Style.tint(Style.button("Let's go", "check", "", func() -> void:
		_help.visible = false
		_write_session()), "gold"))
	p.visible = false
	return p


func _write_session() -> void:
	Io.write(SESSION, Io.to_json({"room": room.key(), "seen_help": true}))


func free_area() -> Rect2:
	return Rect2(8, TOP_H + 8, canvas.size.x - 310.0, canvas.size.y - TOP_H - BOTTOM_H - 16.0)


func _set_view(edit: bool) -> void:
	var w: Window = get_window()
	if edit:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		w.content_scale_size = UI_SIZE
	else:
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		w.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		w.content_scale_size = Vector2i(320, 180)


# ---- Play / edit ----

func _enter_edit() -> void:
	playing = false
	world.freeze()
	_set_view(true)
	cam.enabled = true
	cam.make_current()
	ui.visible = true
	_hint_layer.visible = false


func toggle_play() -> void:
	if _browser.visible or _note_box.visible:
		return
	if playing:
		_stop_play()
	else:
		_start_play()


func _start_play() -> void:
	save_now()
	select([])
	var at: Vector2 = world.wick.global_position
	playing = true
	ui.visible = false
	cam.enabled = false
	_set_view(false)
	Lx.camera.make_current()
	world.go_live(room, at)
	world.wick.god = _god
	_hint_layer.visible = true
	sfx("waystone_warp")


func _stop_play() -> void:
	world.leave_live()
	var isl: int = Lx.state.island_id
	var reg: String = Lx.state.region_id
	var at: Vector2 = world.wick.global_position
	_enter_edit()
	sfx("ui_pause")
	if room.island == isl and room.region == reg:
		world.rebuild(room, at)
		_refresh()
		await get_tree().process_frame
		canvas.look_at_world(at)
	else:
		open_room(isl, reg, at)


# ---- Rooms ----

func open_room(isl: int, reg: String, at: Vector2 = Vector2(-1, -1)) -> bool:
	save_now()
	var r: Room = Room.new()
	if not r.load_room(isl, reg):
		toast("That room can't be opened: %d:%s" % [isl, reg])
		return false
	room = r
	selection.clear()
	wire_from = {}
	var spawn: Vector2 = at if at.x >= 0.0 else Io.vec(room.json.get("spawn", [room.px_size().x * 0.5, room.px_size().y * 0.5]))
	world.rebuild(room, spawn)
	world.track_tiles(room)
	if world.has_unpainted():
		world.request_paint(room)
	thumbs.forget_tiles()
	if not _help.visible:
		_write_session()
	_refresh()
	_palette.refresh()
	canvas.fit.call_deferred()
	return true


func travel(ex: Dictionary) -> void:
	var dest: Vector2i = Vector2i(room.island, 0)
	var reg: String = str(ex.get("to_region", ""))
	var isl: int = int(ex.get("to_island", room.island))
	if reg.begins_with("island") and reg.contains(":"):
		isl = int(reg.get_slice(":", 0).trim_prefix("island"))
		reg = reg.get_slice(":", 1)
	if reg.is_empty() or dest.x < 0:
		return
	sfx("door_open")
	open_room(isl, reg, Io.vec(ex.get("to_spawn", [-1, -1]), Vector2(-1, -1)))


# ---- Notes and verdicts ----

func new_note(pos: Vector2, target: String) -> void:
	_note_cur = {"pos": pos, "target": target}
	_note_text.text = ""
	_note_head.text = "Note for Claude" + (" about %s" % target if not target.is_empty() else "")
	_note_reply.text = ""
	_show_note(pos)


func open_note(n: Dictionary) -> void:
	_note_cur = n
	_note_text.text = str(n.get("text", ""))
	_note_head.text = "Note %d%s" % [int(n["id"]), " (done)" if str(n.get("status", "")) == "done" else ""]
	_note_reply.text = "Claude: " + str(n["reply"]) if not str(n.get("reply", "")).is_empty() else ""
	_show_note(Io.vec(n["pos"]))


func _show_note(pos: Vector2) -> void:
	_note_box.visible = true
	_note_box.reset_size()
	var s: Vector2 = canvas.w2s(pos) + Vector2(18, -20)
	_note_box.position = s.clamp(Vector2(10, TOP_H + 10), (canvas.size - _note_box.size - Vector2(10, BOTTOM_H + 10)).max(Vector2(10, TOP_H + 10)))
	_note_text.grab_focus()


func _save_note() -> void:
	var t: String = _note_text.text.strip_edges()
	if not t.is_empty():
		if _note_cur.has("id"):
			if str(_note_cur.get("text", "")) != t:
				_note_cur["text"] = t
				_note_cur["status"] = "open"
			notes.save_all()
		else:
			notes.add(room.key(), _note_cur["pos"] as Vector2, t, str(_note_cur.get("target", "")))
		sfx("shard_pickup")
		toast("Noted for Claude.")
	_close_note()
	_side.refresh()


func _close_note() -> void:
	_note_box.visible = false
	_note_cur = {}
	if tool == Tool.NOTE:
		set_tool(Tool.HAND)


func set_verdict(v: String) -> void:
	notes.set_verdict(room.key(), "" if notes.verdict(room.key()) == v else v)
	sfx("heart_pickup" if v == "love" else "ui_move")
	_side.refresh()


# ---- Every frame ----

func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false
	if _save_t >= 0.0:
		_save_t -= dt
		if _save_t < 0.0:
			save_now()
			if world.is_painting():
				_status("Painting...")


func _exit_tree() -> void:
	Style.clear_icons()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if room != null and not playing:
			save_now()
			world.paint_before_quit()
		get_tree().quit()


# ---- Keys ----

func _typing() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not (ev as InputEventKey).pressed:
		return
	var k: InputEventKey = ev as InputEventKey
	if _typing():
		if k.keycode == KEY_ESCAPE:
			get_viewport().gui_release_focus()
			_close_note()
			get_viewport().set_input_as_handled()
		return
	if not k.echo and (k.keycode == KEY_B or k.keycode == KEY_F1):
		toggle_play()
		get_viewport().set_input_as_handled()
		return
	if playing:
		if k.keycode == KEY_F2 and not k.echo:
			_god = not _god
			world.wick.god = _god
			(_hint_root as Style.Pix).text = "B: EDIT" if not _god else "B: EDIT  GOD"
			_hint_root.position.x = 320 - _hint_root.custom_minimum_size.x - 4
		return
	if _edit_key(k):
		get_viewport().set_input_as_handled()


func _edit_key(k: InputEventKey) -> bool:
	var cmd: bool = k.is_command_or_control_pressed()
	if _browser.visible:
		if k.keycode in [KEY_ESCAPE, KEY_M]:
			_browser.visible = false
			return true
		return false
	if cmd:
		match k.keycode:
			KEY_Z:
				if k.shift_pressed: redo()
				else: undo()
			KEY_Y: redo()
			KEY_S:
				save_now()
				toast("Saved. (It also saves by itself.)")
			KEY_D: duplicate_selection()
			KEY_C: _copy_clip()
			KEY_V: _paste_clip(Vector2(16, 16))
			KEY_A:
				select(canvas._in_rect(Rect2(Vector2.ZERO, room.px_size())))
			_: return false
		return true
	match k.keycode:
		KEY_ESCAPE:
			if _help.visible: _help.visible = false
			elif _note_box.visible: _close_note()
			elif tool != Tool.HAND: set_tool(Tool.HAND)
			else: select([])
		KEY_ENTER, KEY_KP_ENTER: toggle_play()
		KEY_H, KEY_1: set_tool(Tool.HAND)
		KEY_E, KEY_2: set_tool(Tool.ERASE)
		KEY_W, KEY_3: set_tool(Tool.WIRE)
		KEY_N, KEY_4: set_tool(Tool.NOTE)
		KEY_G: canvas.grid_on = not canvas.grid_on
		KEY_F: canvas.fit()
		KEY_M: _browser.open()
		KEY_X: flip_selection()
		KEY_DELETE, KEY_BACKSPACE: delete_selection()
		KEY_EQUAL, KEY_KP_ADD: canvas.set_zoom(canvas.zoom * 1.2)
		KEY_MINUS, KEY_KP_SUBTRACT: canvas.set_zoom(canvas.zoom / 1.2)
		KEY_BRACKETLEFT: brush = maxi(1, brush - 1); _palette.refresh()
		KEY_BRACKETRIGHT: brush = mini(3, brush + 1); _palette.refresh()
		KEY_LEFT: _arrow(Vector2.LEFT, k)
		KEY_RIGHT: _arrow(Vector2.RIGHT, k)
		KEY_UP: _arrow(Vector2.UP, k)
		KEY_DOWN: _arrow(Vector2.DOWN, k)
		_: return false
	return true


func _arrow(d: Vector2, k: InputEventKey) -> void:
	if selection.is_empty():
		cam.position += d * 90.0 / canvas.zoom
		canvas._keep_near()
	else:
		move_selection(d * (8.0 if k.shift_pressed else 1.0))
