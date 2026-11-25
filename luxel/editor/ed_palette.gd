extends PanelContainer
## Bottom bar: tools on the left, tabs and pictures of everything you can place.

const Style := preload("res://luxel/editor/ed_style.gd")
const Thumbs := preload("res://luxel/editor/ed_thumbs.gd")
const TILE := Vector2(88, 94)

var ed: Node = null
var everything: bool = false
var _tabs: HBoxContainer = null
var _flow: HBoxContainer = null
var _scroll: ScrollContainer = null
var _search: LineEdit = null
var _all_btn: Button = null
var _tool_btns: Dictionary = {}
var _tiles: Dictionary = {}  # thumb key -> Array[Button]
var _brush_btn: Button = null
var _pending: Array[Dictionary] = []


func setup(editor: Node) -> void:
	ed = editor
	add_theme_stylebox_override("panel", Style.box(Style.col("night", 0.98), Style.col("plum"), 0, 8, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(_build_tools())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	for t: Dictionary in ed.catalog.TABS:
		var b: Button = Style.button(str(t["name"]))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 12)
		for st: Array in [["normal", "dusk", "void"], ["hover", "plum", "void"], ["pressed", "gold", "wine"]]:
			var sb: StyleBoxFlat = Style.box(Style.col(str(st[1])), Style.col(str(st[2])), 3, 5)
			sb.content_margin_top = 7
			sb.content_margin_bottom = 7
			b.add_theme_stylebox_override(str(st[0]), sb)
		b.set_meta("tab", str(t["id"]))
		b.pressed.connect(func() -> void: ed.set_tab(str(t["id"])))
		_tabs.add_child(b)
	_all_btn = Style.button("This island", "", "Show things used on this island, or everything in the game.", func() -> void:
		everything = not everything
		_all_btn.text = "Everything" if everything else "This island"
		refresh())
	_all_btn.add_theme_font_size_override("font_size", 13)
	top.add_child(_all_btn)
	_search = LineEdit.new()
	_search.placeholder_text = "Search..."
	_search.custom_minimum_size = Vector2(104, 0)
	_search.text_changed.connect(func(_t: String) -> void: refresh())
	top.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_scroll)
	_flow = HBoxContainer.new()
	_flow.add_theme_constant_override("separation", 5)
	_scroll.add_child(_flow)
	_scroll.gui_input.connect(_on_scroll_input)
	ed.thumbs.ready_thumb.connect(_on_thumb)


func _build_tools() -> Control:
	var all := HBoxContainer.new()
	all.add_theme_constant_override("separation", 4)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for d: Array in [
		["hand", ed.Tool.HAND, "Move", "Pick, move and select things (H)"],
		["erase", ed.Tool.ERASE, "Erase", "Click or drag over things to delete them (E)"],
		["wire", ed.Tool.WIRE, "Wire", "Drag from a switch to the door it should open (W). Drag again to unplug."],
		["note", ed.Tool.NOTE, "Note", "Pin a note for Claude anywhere (N)"],
	]:
		var t: int = int(d[1])
		var b: Button = Style.button(str(d[2]), str(d[0]), str(d[3]), func() -> void: ed.set_tool(t))
		b.toggle_mode = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(66, 64)
		_tool_btns[t] = b
		g.add_child(b)
	all.add_child(g)
	var m: Button = Style.button("Magic", "", "Drag a box and say what you want in plain words (A)", func() -> void: ed.magic_here())
	m.icon = Style.icon("wand", 3)
	m.toggle_mode = true
	m.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	m.custom_minimum_size = Vector2(72, 132)
	m.add_theme_stylebox_override("normal", Style.box(Style.col("wine"), Style.col("void"), 3, 14))
	m.add_theme_stylebox_override("hover", Style.box(Style.col("coral"), Style.col("void"), 3, 14))
	m.add_theme_stylebox_override("pressed", Style.box(Style.col("rose"), Style.col("wine"), 3, 14))
	_tool_btns[ed.Tool.MAGIC] = m
	all.add_child(m)
	return all


func _on_scroll_input(ev: InputEvent) -> void:
	# A mouse wheel or a two-finger swipe scrolls the pictures sideways.
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.scroll_horizontal += 90
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.scroll_horizontal -= 90
	elif ev is InputEventPanGesture:
		var d: Vector2 = (ev as InputEventPanGesture).delta
		_scroll.scroll_horizontal += int((d.x + d.y) * 14.0)


func typing() -> bool: return _search.has_focus()


func sync_tool() -> void:
	for t: int in _tool_btns.keys():
		(_tool_btns[t] as Button).set_pressed_no_signal(t == int(ed.tool))
	for k: String in _tiles.keys():
		for b: Button in (_tiles[k] as Array):
			var on: bool = ed.tool == ed.Tool.STAMP and k == Thumbs.key_of(ed.stamp) and not ed.stamp.has("copy")
			b.set_pressed_no_signal(on)
			(b.get_node("Name") as Label).add_theme_color_override("font_color", Style.col("night") if on else Style.col("cream"))


func refresh() -> void:
	for b: Node in _tabs.get_children():
		(b as Button).set_pressed_no_signal(str(b.get_meta("tab")) == str(ed.tab) and _search.text.is_empty())
	for c: Node in _flow.get_children():
		_flow.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var list: Array = ed.catalog.entries(str(ed.tab), int(ed.room.island), ed.room.json, everything, _search.text)
	if str(ed.tab) == "ground" and _search.text.is_empty():
		_flow.add_child(_brush_box())
	_pending.clear()
	var last_set: String = ""
	for i: int in range(mini(list.size(), 160)):
		var e: Dictionary = list[i] as Dictionary
		if str(e["type"]) == "scenery" and str(e["sheet"]) != last_set and _search.text.is_empty():
			last_set = str(e["sheet"])
			_flow.add_child(_set_label(ed.catalog.sheet_name(last_set)))
		_flow.add_child(_tile(e))
	if list.is_empty():
		_flow.add_child(Style.label("Nothing here on this island yet. Try \"Everything\".", 15, "mauve"))
	_scroll.scroll_horizontal = 0
	sync_tool()


func _set_label(t: String) -> Control:
	var l: Label = Style.label(t, 13, "gold", true)
	l.custom_minimum_size = Vector2(76, 80)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _brush_box() -> Control:
	var v := VBoxContainer.new()
	v.add_child(Style.label("Brush", 12, "mauve"))
	for n: int in [1, 2, 3]:
		var b: Button = Style.button("%dx%d" % [n, n], "", "Brush size. Hold Shift and drag to fill a box.", func() -> void:
			ed.brush = n
			refresh())
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", Style.box(Style.col("dusk"), Style.col("void"), 2, 1))
		b.add_theme_stylebox_override("pressed", Style.box(Style.col("gold"), Style.col("wine"), 2, 1))
		b.button_pressed = int(ed.brush) == n
		v.add_child(b)
	return v


func _tile(e: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	b.toggle_mode = true
	b.clip_contents = true
	b.tooltip_text = str(e["name"]) + ("\n" + str(e["blurb"]) if not str(e.get("blurb", "")).is_empty() else "")
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var pic := TextureRect.new()
	pic.name = "Pic"
	if str(e["type"]) == "tile":
		pic.draw.connect(func() -> void: pic.draw_rect(Rect2(Vector2.ZERO, pic.size).grow(1.0), Style.col("mauve"), false, 2.0))
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.position = Vector2(8, 5)
	pic.size = Vector2(TILE.x - 16, 54)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	var l: Label = Style.label(str(e["name"]), 11, "cream", true)
	l.position = Vector2(3, 58)
	l.size = Vector2(TILE.x - 6, 33)
	l.clip_text = false
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", -4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "Name"
	b.add_child(l)
	b.pressed.connect(func() -> void: ed.pick_stamp(e))
	var k: String = Thumbs.key_of(e)
	(_tiles.get_or_add(k, []) as Array).append(b)
	_pending.append({"e": e, "pic": pic})
	return b


func _process(_dt: float) -> void:
	# Ask for pictures a few at a time, so opening a big tab stays smooth.
	for i: int in range(6):
		if _pending.is_empty():
			return
		var p: Dictionary = _pending.pop_front()
		if is_instance_valid(p["pic"]):
			_fill(p["pic"] as TextureRect, ed.thumbs.get_thumb(p["e"] as Dictionary))


func _fill(pic: TextureRect, th: Dictionary) -> void:
	if th.is_empty():
		return
	pic.texture = th["tex"] as Texture2D
	var sz: Vector2 = (th["rect"] as Rect2).size
	# Whole-number zoom for small pictures keeps the pixels square.
	var k: float = minf(pic.size.x / sz.x, pic.size.y / sz.y)
	var z: float = floorf(k) if k >= 1.0 else k
	z = minf(z, 3.0)
	var fit: Vector2 = sz * z
	pic.position = Vector2((TILE.x - fit.x) * 0.5, 5.0 + (54.0 - fit.y) * 0.5).round()
	pic.size = fit


func _on_thumb(k: String) -> void:
	for b_v: Variant in (_tiles.get(k, []) as Array):
		if is_instance_valid(b_v):
			_fill((b_v as Button).get_node("Pic") as TextureRect, ed.thumbs.get_thumb_by_key(k))
