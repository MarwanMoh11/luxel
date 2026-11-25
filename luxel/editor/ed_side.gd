extends PanelContainer
## Right-hand card: the room (when nothing is selected) or the settings of what is selected.

const Style := preload("res://luxel/editor/ed_style.gd")
const Io := preload("res://luxel/editor/ed_io.gd")

var ed: Node = null
var _body: VBoxContainer = null


func setup(editor: Node) -> void:
	ed = editor
	custom_minimum_size = Vector2(276, 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 7)
	sc.add_child(_body)


func refresh() -> void:
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if ed.room == null:
		return
	if ed.selection.size() > 1:
		_many()
	elif ed.selection.size() == 1 and not ed.room.item(ed.selection[0]).is_empty():
		_one(ed.selection[0])
	else:
		_room()


func _title(t: String) -> void:
	var p := Style.Pix.new(t, 3, Style.col("gold"))
	if p.custom_minimum_size.x > 250.0:
		p.size_px = 2
		p.text = t
	_body.add_child(p)


func _text(t: String, size_px: int = 13, c: String = "stone") -> void:
	if not t.is_empty():
		_body.add_child(Style.label(t, size_px, c, true))


func _row(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	for i: Control in items:
		h.add_child(i)
	_body.add_child(h)
	return h


func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


# ---- The room ----

func _room() -> void:
	_title(ed.room_title())
	_text(ed.room_subtitle(), 13, "mauve")
	var dz: Dictionary = ed.room.json.get("design", {}) as Dictionary if ed.room.json.get("design") is Dictionary else {}
	if not str(dz.get("idea", "")).is_empty():
		_text("What Claude meant this room to be:", 12, "mauve")
		_text(str(dz["idea"]), 13, "stone")
	var v: String = ed.notes.verdict(ed.room.key())
	_text("Your verdict", 12, "mauve")
	var love: Button = _wide(Style.button("Love it", "heart", "Claude keeps this room exactly as it is.", func() -> void: ed.set_verdict("love")))
	var fix: Button = _wide(Style.button("Needs work", "fix", "Claude comes back to this room first.", func() -> void: ed.set_verdict("fix")))
	love.toggle_mode = true
	fix.toggle_mode = true
	love.button_pressed = v == "love"
	fix.button_pressed = v == "fix"
	_row([love, fix])
	var ns: Array = ed.notes.of_room(ed.room.key())
	_row([_wide(Style.button("Add a note for Claude", "note", "Then click where it belongs.", func() -> void: ed.set_tool(ed.Tool.NOTE)))])
	for n: Dictionary in ns:
		var b: Button = Style.button("%d. %s" % [int(n["id"]), str(n["text"]).replace("\n", " ").left(60)], "", str(n["text"]), func() -> void: ed.open_note(n))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0, 30)
		if str(n.get("status", "")) == "done":
			b.add_theme_color_override("font_color", Style.col("jade"))
		_body.add_child(b)
	if ed.room.changed_by_hand():
		_text("You have changed this room.", 12, "jade")
		var rb: Button = Style.button("Put back Claude's version", "undo", "Undo works after this too.")
		rb.pressed.connect(func() -> void:
			if rb.text == "Sure? Click again":
				ed.reset_room()
			else:
				rb.text = "Sure? Click again")
		_body.add_child(rb)
	var tips: String = "Drag anything to move it. Right-click a thing to copy it. Two fingers or Space+drag to look around, pinch or wheel to zoom. Double-click a green exit to walk through."
	_text(tips, 12, "mauve")


# ---- Several things ----

func _many() -> void:
	_title("%d things" % ed.selection.size())
	_text("Drag one to move them all. Arrow keys nudge.", 13)
	_row([
		_wide(Style.button("Copy", "copy", "Cmd+D", func() -> void: ed.duplicate_selection())),
		_wide(Style.button("Delete", "trash", "Delete key", func() -> void: ed.delete_selection())),
	])


# ---- One thing ----

func _one(ref: Dictionary) -> void:
	var l: String = str(ref["list"])
	var it: Dictionary = ed.room.item(ref)
	var kind: String = str(it.get("kind", it.get("prop", "")))
	_title(ed.catalog.name_of(l, it))
	_text(ed.catalog.blurb(l, kind), 13, "stone")
	var btns: Array = [_wide(Style.button("", "copy", "Duplicate (Cmd+D)", func() -> void: ed.duplicate_selection()))]
	if l == "scenery":
		btns.append(_wide(Style.button("", "flip", "Flip (X)", func() -> void: ed.flip_selection())))
	if l == "interactables":
		btns.append(_wide(Style.button("", "wire", "Wire it to something (W)", func() -> void: ed.set_tool(ed.Tool.WIRE))))
	btns.append(_wide(Style.button("", "note", "Note for Claude about this", func() -> void: ed.new_note(Io.vec(it.get("pos", [0, 0])), str(it.get("id", kind))))))
	btns.append(_wide(Style.button("", "trash", "Delete (Delete key)", func() -> void: ed.delete_selection())))
	_row(btns)
	match l:
		"scenery":
			_choice("Stands", ["sort", "ground", "overhead"], ["Upright", "Flat on floor", "Above Wick"], it.get("layer", "sort"), func(v: Variant) -> void: ed.set_field(ref, "layer", v))
			_bool("Shadow", bool(it.get("shadow", true)), func(v: bool) -> void: ed.set_field(ref, "shadow", v))
		"enemies":
			_number("Guards within", float(it.get("leash", 100)), 8.0, 24.0, 320.0, func(v: float) -> void: ed.set_field(ref, "leash", Io.num(v)), "How far it roams from here (the red ring).")
			_row([
				_wide(Style.button("Add patrol point", "", "Adds a gold dot; drag it where the enemy should walk.", func() -> void: ed.add_patrol(ref))),
				Style.button("", "trash", "Clear the patrol", func() -> void: ed.set_field(ref, "route", [])),
			])
		"decor":
			if it.has("radius"):
				_number("Size", float(it["radius"]), 4.0, 4.0, 160.0, func(v: float) -> void: ed.set_field(ref, "radius", Io.num(v)))
			if it.get("rect") is Array:
				var r: Array = it["rect"] as Array
				_number("Width", float(r[2]), 8.0, 8.0, 400.0, func(v: float) -> void: ed.set_field(ref, "rect", [r[0], r[1], Io.num(v), r[3]]))
				_number("Height", float(r[3]), 8.0, 8.0, 400.0, func(v: float) -> void: ed.set_field(ref, "rect", [r[0], r[1], r[2], Io.num(v)]))
		"interactables":
			_props(ref, it, kind)
	var id: String = str(it.get("id", ""))
	_text("%s%s at %s" % [kind, " (%s)" % id if not id.is_empty() else "", str(it.get("pos", ""))], 11, "plum")


func _props(ref: Dictionary, it: Dictionary, kind: String) -> void:
	var pr: Dictionary = it["props"] as Dictionary if it.get("props") is Dictionary else {}
	var sch: Dictionary = ed.catalog.prop_schema(kind)
	var keys: Array = sch.keys()
	if keys.is_empty():
		for k: String in pr.keys():
			if pr[k] is bool or ((pr[k] is int or pr[k] is float) and not k.contains("flag")) or k == "size":
				sch[k] = {"label": k.replace("_", " ").capitalize(), "type": "bool" if pr[k] is bool else ("size" if k == "size" else "number")}
		keys = sch.keys()
	for k: String in keys:
		var s: Dictionary = sch[k] as Dictionary
		var lab: String = str(s.get("label", k))
		var tip: String = str(s.get("help", ""))
		var cur: Variant = pr.get(k, null)
		match str(s.get("type", "")):
			"bool":
				_bool(lab, bool(cur) if cur != null else false, func(v: bool) -> void: ed.set_prop(ref, k, v), tip)
			"number":
				var stp: float = float(s.get("step", 1.0))
				_number(lab, float(cur) if (cur is int or cur is float) else float(s.get("min", 0.0)), stp, float(s.get("min", -9999.0)), float(s.get("max", 9999.0)), func(v: float) -> void: ed.set_prop(ref, k, Io.num(v)), tip)
			"choice":
				var opts: Array = s.get("options", []) as Array
				var names: Array = []
				for o: Variant in opts:
					names.append(" + ".join(PackedStringArray(o as Array)) if o is Array else str(o).replace("_", " "))
				_choice(lab, opts, names, cur, func(v: Variant) -> void: ed.set_prop(ref, k, v), tip)
			"size":
				var sz: Vector2 = Io.vec(cur, Vector2(16, 16))
				_number(lab + " W", sz.x, 8.0, 8.0, 512.0, func(v: float) -> void: ed.set_prop(ref, k, [Io.num(v), Io.num(sz.y)]), tip)
				_number(lab + " H", sz.y, 8.0, 8.0, 512.0, func(v: float) -> void: ed.set_prop(ref, k, [Io.num(sz.x), Io.num(v)]), tip)
			"text":
				var le := LineEdit.new()
				le.text = str(cur) if cur != null else ""
				le.placeholder_text = lab
				le.tooltip_text = tip
				le.text_submitted.connect(func(t: String) -> void: ed.set_prop(ref, k, t))
				_body.add_child(Style.label(lab, 12, "mauve"))
				_body.add_child(le)
	var links: Array[String] = []
	var items: Array = ed.room.list("interactables")
	for w: Dictionary in ed.room.wires():
		if int(w["from"]) == int(ref["i"]):
			links.append("Drives: " + ed.catalog.name_of("interactables", items[int(w["to"])] as Dictionary))
		elif int(w["to"]) == int(ref["i"]):
			links.append("Waits for: " + ed.catalog.name_of("interactables", items[int(w["from"])] as Dictionary))
	if not links.is_empty():
		_text("\n".join(PackedStringArray(links)), 12, "gold")
	var need: Array[String] = []
	for k2: String in ["requires_flags", "requires_flag", "requires_moves", "key_id", "clear_zone"]:
		if pr.has(k2) and not str(pr[k2]).is_empty() and str(pr[k2]) != "[]":
			need.append("%s: %s" % [k2.replace("_", " "), str(pr[k2])])
	if not need.is_empty():
		_text("Story lock: " + ", ".join(PackedStringArray(need)), 11, "mauve")


func _lab(t: String, tip: String = "") -> Label:
	var l: Label = Style.label(t, 13, "stone")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP if not tip.is_empty() else Control.MOUSE_FILTER_IGNORE
	return l


func _bool(lab: String, on: bool, cb: Callable, tip: String = "") -> void:
	var b: Button = Style.button("Yes" if on else "No", "", tip)
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(84, 30)
	b.toggled.connect(func(v: bool) -> void: cb.call(v))
	_row([_lab(lab, tip), b])


func _number(lab: String, cur: float, step: float, lo: float, hi: float, cb: Callable, tip: String = "") -> void:
	var minus: Button = Style.button("-", "", tip, func() -> void: cb.call(clampf(cur - step, lo, hi)))
	var plus: Button = Style.button("+", "", tip, func() -> void: cb.call(clampf(cur + step, lo, hi)))
	minus.custom_minimum_size = Vector2(30, 30)
	plus.custom_minimum_size = Vector2(30, 30)
	var v := LineEdit.new()
	v.text = str(Io.num(cur))
	v.custom_minimum_size = Vector2(58, 30)
	v.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.text_submitted.connect(func(t: String) -> void:
		if t.is_valid_float():
			cb.call(clampf(t.to_float(), lo, hi)))
	_row([_lab(lab, tip), minus, v, plus])


func _choice(lab: String, vals: Array, names: Array, cur: Variant, cb: Callable, tip: String = "") -> void:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.tooltip_text = tip
	o.custom_minimum_size = Vector2(128, 30)
	o.clip_text = true
	var at: int = -1
	for i: int in range(vals.size()):
		o.add_item(str(names[i]))
		if typeof(vals[i]) == typeof(cur) and vals[i] == cur:
			at = i
		elif (vals[i] is float or vals[i] is int) and (cur is float or cur is int) and is_equal_approx(float(vals[i]), float(cur)):
			at = i
	if at < 0 and cur != null:
		o.add_item(str(cur))
		at = o.item_count - 1
	o.select(at)
	o.item_selected.connect(func(i: int) -> void:
		if i < vals.size():
			cb.call(vals[i]))
	_row([_lab(lab, tip), o])
