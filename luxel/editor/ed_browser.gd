extends ColorRect
## Full-screen room picker: islands on top, rooms grouped by place, with a picture and your marks on each.

const Style := preload("res://luxel/editor/ed_style.gd")
const Room := preload("res://luxel/editor/ed_room.gd")
const CARD := Vector2(150, 112)

var ed: Node = null
var island: int = 1
var _tabs: HBoxContainer = null
var _body: VBoxContainer = null
var _load: Array[Dictionary] = []
var _pics: Dictionary = {}


func setup(editor: Node) -> void:
	ed = editor
	color = Style.col("void", 0.99)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	top.add_child(Style.Pix.new("PICK A ROOM", 4, Style.col("gold")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	top.add_child(_tabs)
	for i: int in range(0, 9):
		var b: Button = Style.button("Hub" if i == 0 else str(i), "", "", func() -> void: show_island(i))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(44, 36)
		_tabs.add_child(b)
	top.add_child(Style.button("", "close", "Close (Esc)", func() -> void: visible = false))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	sc.add_child(_body)


func open() -> void:
	visible = true
	show_island(int(ed.room.island))


func show_island(isl: int) -> void:
	island = isl
	for i: int in range(_tabs.get_child_count()):
		(_tabs.get_child(i) as Button).set_pressed_no_signal(i == isl)
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_load.clear()
	var groups: Dictionary = {}
	var order: Array[String] = []
	for reg: String in _regions(isl):
		var g: String = Lx.packs.dungeon_of(isl, reg) if Lx.packs != null else ""
		if not groups.has(g):
			groups[g] = []
			order.append(g)
		(groups[g] as Array).append(reg)
	order.sort()
	for g: String in order:
		var title: String = "Outside and small places" if g.is_empty() else ed.dungeon_title(g)
		_body.add_child(Style.Pix.new(title, 3, Style.col("apricot")))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_body.add_child(flow)
		var regs: Array = groups[g] as Array
		regs.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		if regs.has("overworld"):
			regs.erase("overworld")
			regs.push_front("overworld")
		for reg: String in regs:
			flow.add_child(_card(isl, reg))


func _regions(isl: int) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at("%s/%d" % [Room.islands_dir, isl]):
		if f.ends_with(".map") and not f.begins_with("_"):
			out.append(f.trim_suffix(".map"))
	return out


func _card(isl: int, reg: String) -> Control:
	var key: String = "%d:%s" % [isl, reg]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD
	b.clip_contents = true
	b.tooltip_text = "%s (%s)" % [ed.region_title(isl, reg), reg]
	b.pressed.connect(func() -> void:
		visible = false
		ed.open_room(isl, reg))
	if key == ed.room.key():
		Style.tint(b, "plum", "cream")
	var pic := TextureRect.new()
	pic.position = Vector2(6, 6)
	pic.size = Vector2(CARD.x - 12, 74)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	var l: Label = Style.label(ed.region_title(isl, reg), 12, "cream", true)
	l.position = Vector2(4, 80)
	l.size = Vector2(CARD.x - 8, 28)
	l.max_lines_visible = 2
	l.add_theme_constant_override("line_spacing", -3)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	var marks: Array = []
	match ed.notes.verdict(key):
		"love": marks.append(["heart", "coral"])
		"fix": marks.append(["fix", "gold"])
	if ed.notes.open_count(key) > 0:
		marks.append(["note", "gold"])
	if _edited("%d_%s" % [isl, reg]):
		marks.append(["brush", "lime"])
	for i: int in range(marks.size()):
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", Style.box(Style.col("void", 0.85), Color.TRANSPARENT, 0, 0, 4))
		bg.position = Vector2(8 + i * 30, 8)
		bg.size = Vector2(27, 27)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
		var ic := TextureRect.new()
		ic.texture = Style.icon(str((marks[i] as Array)[0]), 2)
		ic.modulate = Style.col(str((marks[i] as Array)[1]))
		ic.position = Vector2(3, 3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(ic)
	if _pics.has(key) and str(ed.room.key()) != key:
		pic.texture = _pics[key] as Texture2D
	else:
		_load.append({"key": key, "path": "res://luxel/art/islands/%d/%s_ground.png" % [isl, reg], "pic": pic})
	return b


func _edited(fk: String) -> bool:
	if not FileAccess.file_exists("%s/base/%s.map.txt" % [Room.edits_dir, fk]):
		return false
	for ext: String in [".map.txt", ".json"]:
		if FileAccess.get_md5("%s/base/%s%s" % [Room.edits_dir, fk, ext]) != FileAccess.get_md5("%s/edited/%s%s" % [Room.edits_dir, fk, ext]):
			return true
	return false


func _process(_dt: float) -> void:
	if not visible:
		return
	var t0: int = Time.get_ticks_msec()
	while not _load.is_empty() and Time.get_ticks_msec() - t0 < 8:
		var j: Dictionary = _load.pop_front()
		if not is_instance_valid(j["pic"]) or not FileAccess.file_exists(str(j["path"])):
			continue
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(str(j["path"]))) != OK:
			continue
		var k: float = minf(300.0 / img.get_width(), 150.0 / img.get_height())
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS if k < 1.0 else Image.INTERPOLATE_NEAREST)
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		_pics[str(j["key"])] = tex
		(j["pic"] as TextureRect).texture = tex
