extends PanelContainer
## Right-hand card: the room (when nothing is selected) or the settings of what is selected.

const Style := preload("res://luxel/editor/ed_style.gd")
const Io := preload("res://luxel/editor/ed_io.gd")

var ed: Node = null
var _body: VBoxContainer = null
var _view: String = "room"
var _scroll: ScrollContainer = null
var _showing: String = ""
var _keep: int = 0


func setup(editor: Node) -> void:
	ed = editor
	custom_minimum_size = Vector2(276, 0)
	var sc := ScrollContainer.new()
	_scroll = sc
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 7)
	sc.add_child(_body)


func refresh() -> void:
	# Ticking something must not throw the card back to the top.
	var now: String = "%s/%s/%s" % [ed.room.key() if ed.room != null else "", _view, str(ed.selection)]
	var keep: int = _scroll.scroll_vertical if now == _showing else 0
	_showing = now
	_fill_card()
	_keep = keep
	if not get_tree().process_frame.is_connected(_rescroll):
		get_tree().process_frame.connect(_rescroll, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _rescroll() -> void:
	_scroll.scroll_vertical = _keep


func _fill_card() -> void:
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
	_text(ed.room_subtitle(), 12, "mauve")
	var tabs: Array = []
	for t: Array in [["room", "Room"], ["place", "Place"], ["island", "Island"]]:
		var b: Button = _wide(Style.button(str(t[1]), "", "", func() -> void:
			_view = str(t[0])
			refresh()))
		b.toggle_mode = true
		b.button_pressed = _view == str(t[0])
		b.add_theme_font_size_override("font_size", 13)
		tabs.append(b)
	_row(tabs)
	match _view:
		"place": _place_view()
		"island": _island_view()
		_: _room_view()


func _head(t: String) -> void:
	_body.add_child(Style.Pix.new(t, 2, Style.col("apricot")))


func _room_view() -> void:
	var v: Object = ed.vision
	var isl: int = int(ed.room.island)
	var reg: String = str(ed.room.region)
	var dz: Dictionary = v.design(ed.room.json)
	var mine: Dictionary = v.room(isl, reg)
	_head("The vision")
	_text(v.promise(isl, reg, ed.room.json), 15, "cream")
	if not str(mine.get("aha", "")).is_empty():
		_text("You should realise: " + str(mine["aha"]), 13, "gold")
	var shape: Label = Style.label(v.shape(ed.room.json), 12, "stone", true)
	shape.tooltip_text = v.beat_help(ed.room.json)
	shape.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(shape)
	if not str(dz.get("teaches", "")).is_empty():
		_text("Teaches: " + v.tidy(str(dz["teaches"])), 12, "stone")
	var rw: String = v.rewards(ed.room)
	if not rw.is_empty():
		_text("Gives: " + rw, 12, "stone")
	if ed.run_times.has(ed.room.key()):
		var mean: float = float(dz.get("expert_s", 0))
		_text("Your last run: %s%s" % [v.clock(float(ed.run_times[ed.room.key()])), "  (meant: %s)" % v.clock(mean) if mean > 0.0 else ""], 13, "jade")
	var qs: Variant = mine.get("checks", [])
	if qs is Array and not (qs as Array).is_empty():
		_head("Is it there?")
		for q: Variant in (qs as Array):
			_check(str(q))
	_head("Your verdict")
	var vd: String = ed.notes.verdict(ed.room.key())
	var love: Button = _wide(Style.button("Love it", "heart", "Claude keeps this room exactly as it is.", func() -> void: ed.set_verdict("love")))
	var fix: Button = _wide(Style.button("Needs work", "fix", "Claude comes back to this room first.", func() -> void: ed.set_verdict("fix")))
	love.toggle_mode = true
	fix.toggle_mode = true
	love.button_pressed = vd == "love"
	fix.button_pressed = vd == "fix"
	_row([love, fix])
	_row([_wide(Style.button("Add a note for Claude", "note", "Then click where it belongs.", func() -> void: ed.set_tool(ed.Tool.NOTE)))])
	for n: Dictionary in ed.notes.of_room(ed.room.key()):
		_note_row(n)
	var st: Array = (v.cached(ed.room) as Dictionary)["steps"] as Array
	if not st.is_empty():
		_head("Intended way through")
		for s: Dictionary in st:
			_step(s)
	if ed.room.changed_by_hand():
		_text("You have changed this room.", 12, "jade")
		var rb: Button = Style.button("Put back Claude's version", "undo", "Undo works after this too.")
		rb.pressed.connect(func() -> void:
			if rb.text == "Sure? Click again":
				ed.reset_room()
			else:
				rb.text = "Sure? Click again")
		_body.add_child(rb)


func _note_row(n: Dictionary) -> void:
	var b: Button = Style.button("%d. %s" % [int(n["id"]), str(n["text"]).replace("\n", " ").left(60)], "", str(n["text"]), func() -> void: ed.open_note(n))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0, 30)
	if str(n.get("status", "")) == "done":
		b.add_theme_color_override("font_color", Style.col("jade"))
	_body.add_child(b)


func _check(q: String) -> void:
	var cur: String = ed.notes.check(ed.room.key(), q)
	var l: Label = Style.label(q, 13, "cream", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var items: Array = [l]
	for o: Array in [["yes", "check", "jade", "Yes, it's there"], ["no", "close", "coral", "Not yet: Claude will work on it"]]:
		var b: Button = Style.button("", str(o[1]), str(o[3]), func() -> void: ed.set_check(q, str(o[0])))
		b.toggle_mode = true
		b.button_pressed = cur == str(o[0])
		b.add_theme_stylebox_override("pressed", Style.box(Style.col(str(o[2])), Style.col("void"), 3, 6))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		items.append(b)
	_row(items)


func _step(s: Dictionary) -> void:
	var n: int = int(s["n"])
	var b: Button = Style.button("%d. %s" % [n, str(s["text"])], "", "", func() -> void: ed.canvas.look_at_world(s["pos"] as Vector2))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", Style.box(Style.col("dusk", 0.45), Color.TRANSPARENT, 0, 4, 4))
	b.add_theme_color_override("font_color", Style.col("coral") if bool(s["lost"]) else Style.col("ice"))
	b.mouse_entered.connect(func() -> void: ed.hot_step = n)
	b.mouse_exited.connect(func() -> void:
		if int(ed.hot_step) == n:
			ed.hot_step = -1)
	_body.add_child(b)
	if bool(s["lost"]):
		_text("This step uses something that isn't in the room any more.", 11, "coral")


func _place_view() -> void:
	var isl: int = int(ed.room.island)
	var g: String = Lx.packs.dungeon_of(isl, ed.room.region)
	if g.is_empty():
		_text("This room isn't part of a dungeon. See Island for how it fits.", 13)
		return
	var p: Dictionary = ed.vision.place(isl, g)
	_head(ed.dungeon_title(g))
	_text(str(p.get("promise", "")), 14, "cream")
	for k: Array in [["power", "New power: "], ["arc", "How it builds: "], ["boss", "The boss should test: "]]:
		if not str(p.get(str(k[0]), "")).is_empty():
			_text(str(k[1]) + str(p[str(k[0])]), 13, "stone")
	_head("Its rooms")
	for reg_v: Variant in (Lx.packs.dungeon(g).get("regions", []) as Array):
		var reg: String = str(reg_v)
		var here: bool = reg == str(ed.room.region)
		var key: String = "%d:%s" % [isl, reg]
		var mark: String = {"love": "  <3", "fix": "  (needs work)"}.get(ed.notes.verdict(key), "")
		var b: Button = Style.button(ed.region_title(isl, reg) + mark, "", ed.vision.promise(isl, reg, {}), func() -> void: ed.open_room(isl, reg))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		if here:
			b.toggle_mode = true
			b.button_pressed = true
		_body.add_child(b)
		_text(ed.vision.promise(isl, reg, {}), 11, "mauve")


func _island_view() -> void:
	var d: Dictionary = ed.vision.island(int(ed.room.island))
	if d.is_empty():
		_text("The island's vision is still being written.", 13)
		return
	_head(str(d.get("title", "")))
	for k: Array in [["rule", "Its one rule: ", "cream"], ["feel", "It should feel: ", "stone"], ["arc", "How it unfolds: ", "stone"]]:
		if not str(d.get(str(k[0]), "")).is_empty():
			_text(str(k[1]) + str(d[str(k[0])]), 13, str(k[2]))
	if d.get("moments") is Array:
		_head("Moments to remember")
		for m: Variant in (d["moments"] as Array):
			_text("* " + str(m), 13, "gold")


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
