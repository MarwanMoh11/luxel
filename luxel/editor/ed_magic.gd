extends Node
## The AI brush: box an area, say what you want, get edits. The model only ever returns a list of operations; this file checks
## them, keeps them inside the box, and applies them as one undo step. Engine: tools/epic/editor_magic.py (claude, else agy).

const Style := preload("res://luxel/editor/ed_style.gd")
const Io := preload("res://luxel/editor/ed_io.gd")
const Vision := preload("res://luxel/editor/ed_vision.gd")
const Rules := preload("res://luxel/editor/ed_magic_rules.gd")
const Shot := preload("res://luxel/editor/ed_magic_shot.gd")

enum S { IDLE, ASK, THINK, READY, SHOW }

const IDEAS: Array[String] = ["Make it harder", "Make it easier", "Make it more beautiful", "Give it more room to breathe", "Add a secret", "Fix the flow", "Surprise me"]
const MOVES: Array[String] = ["bolt", "dash", "throw and zip", "prism", "beam", "glide", "True Lens", "Sunflare"]

var ed: Node = null
var state: int = S.IDLE
var area: Rect2i = Rect2i()  # tiles
var key: String = ""  # the room this request belongs to
var changed: Array[Rect2] = []  # world rects the last answer touched
var secs: float = 0.0

var _shot: Node = null
var _pid: int = -1
var _dir: String = ""
var _ask: String = ""
var _say: String = ""
var _warn: PackedStringArray = PackedStringArray()
var _conv: String = ""
var _engine: String = ""
var _problems: PackedStringArray = PackedStringArray()
var _tries: int = 0
var _applied: bool = false
var _result: Dictionary = {}
var _n: int = 0
var test_answer: Dictionary = {}  # checks feed an answer here instead of calling a model

var card: PanelContainer = null
var _head: Label = null
var _body: Label = null
var _text: TextEdit = null
var _chips: HFlowContainer = null
var _btns: HBoxContainer = null


func setup(editor: Node, root: Control) -> void:
	ed = editor
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shot = Shot.new()
	_shot.ed = ed
	add_child(_shot)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Style.col("night", 0.98), Style.col("rose"), 0, 12, 10, 2))
	card.custom_minimum_size = Vector2(420, 0)
	card.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	_head = Style.label("", 16, "rose")
	v.add_child(_head)
	_body = Style.label("", 14, "cream", true)
	_body.custom_minimum_size = Vector2(396, 0)
	v.add_child(_body)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(396, 64)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER] and not (ev as InputEventKey).shift_pressed:
			_text.accept_event()
			send(_text.text))
	v.add_child(_text)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 5)
	_chips.add_theme_constant_override("v_separation", 5)
	v.add_child(_chips)
	for t: String in IDEAS:
		var b: Button = Style.button(t, "", "", func() -> void:
			_text.text = t if _text.text.strip_edges().is_empty() else _text.text.strip_edges() + ". " + t
			_text.grab_focus())
		b.add_theme_font_size_override("font_size", 12)
		_chips.add_child(b)
	_btns = HBoxContainer.new()
	_btns.add_theme_constant_override("separation", 6)
	v.add_child(_btns)
	root.add_child(card)


func busy() -> bool: return state == S.THINK
func here() -> bool: return state != S.IDLE and ed.room != null and ed.room.key() == key
func area_px() -> Rect2: return Rect2(Vector2(area.position) * ed.room.ts, Vector2(area.size) * ed.room.ts)


# ---- Asking ----

func start(tiles: Rect2i) -> void:
	if state == S.THINK:
		ed.toast("One wish at a time: the last one is still being made.")
		return
	var full := Rect2i(0, 0, ed.room.width, ed.room.height)
	area = tiles.intersection(full)
	if area.size.x < 1 or area.size.y < 1:
		area = full
	key = ed.room.key()
	changed.clear()
	_conv = ""
	_engine = ""
	_applied = false
	state = S.ASK
	var free: Rect2 = ed.free_area()
	ed.canvas.frame(area_px(), Rect2(free.position, Vector2(maxf(240.0, free.size.x - card.custom_minimum_size.x - 30.0), free.size.y)))
	_show_ask("What should change here?" if area != full else "What should change in this room?", "")


func _show_ask(head: String, body: String) -> void:
	_head.text = head
	_body.text = body
	_body.visible = not body.is_empty()
	_text.text = ""
	_text.placeholder_text = "Say it in plain words. Enter sends it."
	_text.visible = true
	_chips.visible = true
	_set_buttons([["Do it", "wand", "gold", func() -> void: send(_text.text)], ["Cancel", "close", "", close]])
	_place()
	_text.grab_focus()


func _set_buttons(defs: Array) -> void:
	for c: Node in _btns.get_children():
		_btns.remove_child(c)
		c.queue_free()
	for d: Array in defs:
		var b: Button = Style.button(str(d[0]), str(d[1]), "", d[3] as Callable)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not str(d[2]).is_empty():
			Style.tint(b, str(d[2]))
		_btns.add_child(b)


func _place() -> void:
	# Docked beside the box, never over it: start() moves the view to make room.
	card.visible = true
	card.reset_size()
	var free: Rect2 = ed.free_area()
	card.position = Vector2(free.end.x - card.size.x, clampf(ed.canvas.r2s(area_px()).get_center().y - card.size.y * 0.5, free.position.y, maxf(free.position.y, free.end.y - card.size.y)))


func close() -> void:
	if state == S.THINK and _pid > 0:
		OS.kill(_pid)
		_pid = -1
	state = S.IDLE
	changed.clear()
	card.visible = false
	if ed.tool == ed.Tool.MAGIC:
		ed.set_tool(ed.Tool.HAND)


func on_room_opened() -> void:
	card.visible = false
	if state in [S.ASK, S.SHOW]:
		state = S.IDLE
		changed.clear()
	elif state == S.READY and here():
		_use_result()


func send(text: String) -> void:
	var t: String = text.strip_edges()
	if t.is_empty() or state == S.THINK:
		return
	_ask = t
	_problems.clear()
	_tries = 0
	get_viewport().gui_release_focus()
	_go()


func _go() -> void:
	state = S.THINK
	secs = 0.0
	ed.select([])
	ed.hot_step = -1
	_thinking()
	if not test_answer.is_empty():
		_result = test_answer
		_use_result()
		return
	_n += 1
	_dir = "%s/magic/%d_%d" % [Io.work_dir, int(Time.get_unix_time_from_system()), _n]
	DirAccess.make_dir_recursive_absolute(_dir)
	await _shot.take(area, _things(), _dir)
	if state != S.THINK:
		return
	Io.write(_dir + "/request.json", JSON.stringify(_request()))
	var py: String = "/opt/homebrew/bin/python3" if FileAccess.file_exists("/opt/homebrew/bin/python3") else "/usr/bin/python3"
	_pid = OS.create_process(py, [ProjectSettings.globalize_path("res://tools/epic/editor_magic.py"), ProjectSettings.globalize_path(_dir)])
	if _pid <= 0:
		_failed("The AI helper couldn't be started.")


func _thinking() -> void:
	_head.text = "Making it..."
	_body.text = "\"%s\"" % _ask
	_body.visible = true
	_text.visible = false
	_chips.visible = false
	_set_buttons([["Stop", "close", "", close]])
	_place()


func _process(dt: float) -> void:
	if state != S.THINK:
		return
	secs += dt
	_head.text = "Making it... %d s%s" % [int(secs), "  (small wishes 10-20 s, puzzles about a minute)" if secs < 40.0 else ""]
	if not here():
		card.visible = false
	if _pid > 0 and not OS.is_process_running(_pid):
		_pid = -1
		var r: Variant = JSON.parse_string(Io.read(_dir + "/result.json"))
		if not (r is Dictionary):
			_failed("The AI helper stopped without an answer.")
			return
		_result = r as Dictionary
		if not bool(_result.get("ok", false)):
			_failed("No answer: " + str(_result.get("error", "")).left(200))
		elif here() and not ed.playing:
			_use_result()
		else:
			state = S.READY
			ed.toast("Your change is ready in %s. Open it to see." % ed.region_title(int(key.get_slice(":", 0)), key.get_slice(":", 1)))


func _failed(why: String) -> void:
	state = S.ASK if here() else S.IDLE
	ed.sfx("denied")
	if here():
		var t: String = _ask
		_show_ask("That didn't work", why)
		_text.text = t
	else:
		ed.toast(why)


# ---- What the model gets to see ----

func _things() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var px: Rect2 = area_px().grow(8.0)
	var mark: int = 0
	for l: String in ["interactables", "enemies", "scenery", "decor"]:
		var a: Array = ed.room.list(l)
		for i: int in range(a.size()):
			var it: Dictionary = a[i] as Dictionary
			var r: Rect2 = ed.canvas.rect_of({"list": l, "i": i})
			var p: Vector2 = Io.vec(it.get("pos", [r.get_center().x, r.get_center().y]))
			var inside: bool = px.has_point(p)
			var t: Dictionary = {
				"ref": Rules.ref_of(l, it, i), "what": Rules.WHAT[l], "kind": str(it.get("kind", it.get("prop", ""))),
				"name": ed.catalog.name_of(l, it), "pos": [int(p.x), int(p.y)], "in": inside, "rect": r, "mark": 0,
			}
			if inside:
				mark += 1
				t["mark"] = mark
				var pr: Dictionary = (it["props"] as Dictionary).duplicate(true) if it.get("props") is Dictionary else {}
				if l == "scenery":
					pr = {"sheet": it.get("sheet", ""), "flip": it.get("flip_x", false)}
				elif l == "enemies":
					pr = {"leash": it.get("leash", 0), "route": it.get("route", [])}
				t["props"] = pr
			out.append(t)
	return out


func _request() -> Dictionary:
	var r: Object = ed.room
	var ts: int = int(r.ts)
	var legend: Dictionary = {}
	for row: String in r.rows:
		for ch: String in row:
			legend[ch] = r.legend.get(ch, "void")
	var things: Array = []
	for t: Dictionary in _things():
		var c: Dictionary = t.duplicate()
		c.erase("rect")
		things.append(c)
	var wires: Array = []
	var items: Array = r.list("interactables")
	for w: Dictionary in r.wires():
		wires.append([str((items[int(w["from"])] as Dictionary).get("id", "")), str((items[int(w["to"])] as Dictionary).get("id", ""))])
	var exits: Array = []
	for ex: Dictionary in r.list("exits"):
		var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		exits.append({"to": ed.room_title_of(ex), "tiles": [int(er.position.x / ts), int(er.position.y / ts), int(er.size.x / ts), int(er.size.y / ts)]})
	var mine: Dictionary = ed.vision.room(int(r.island), str(r.region))
	var steps: Array = []
	for s: Dictionary in ed.vision.cached(r)["steps"] as Array:
		steps.append(str(s["text"]))
	var dz: Dictionary = Vision.design(r.json)
	return {
		"ask": _ask, "key": key, "title": ed.room_title(), "subtitle": ed.room_subtitle(), "size": [r.width, r.height],
		"area": [area.position.x, area.position.y, area.size.x, area.size.y], "whole": area.size == Vector2i(r.width, r.height),
		"rows": Array(r.rows), "legend": legend, "things": things, "wires": wires, "exits": exits,
		"spawn": r.json.get("spawn", []), "wick": Io.arr(ed.world.wick.global_position.round()),
		"moves": MOVES.slice(0, clampi(int(r.island) + 2, 3, 8)),
		"vision": {"promise": ed.vision.promise(int(r.island), str(r.region), r.json), "aha": mine.get("aha", ""), "teaches": Vision.tidy(str(dz.get("teaches", ""))), "shape": ed.vision.shape(r.json), "rule": ed.vision.island(int(r.island)).get("rule", ""), "steps": steps},
		"palette": Rules.palette(ed.catalog, int(r.island), r.json),
		"conversation": _conv, "engine": _engine, "applied": _applied, "problems": Array(_problems),
	}


# ---- The answer ----

func _use_result() -> void:
	if not ed.canvas._press.is_empty():
		_use_result.call_deferred()  # never in the middle of a drag
		return
	var data: Dictionary = _result.get("data", {}) as Dictionary if _result.get("data") is Dictionary else {}
	_conv = str(_result.get("conversation", _conv))
	_engine = str(_result.get("engine", _engine))
	_say = str(data.get("say", "")).strip_edges()
	ed.room.begin()
	var out: Dictionary = Rules.apply(ed, area, data.get("ops", []) as Array if data.get("ops") is Array else [])
	var bad: PackedStringArray = out["problems"] as PackedStringArray
	if not bad.is_empty() and _tries < 1 and test_answer.is_empty():
		# One automatic second chance, with what went wrong spelled out.
		ed.room.cancel()
		ed.world.rebuild(ed.room, ed.world.wick.global_position)
		_tries += 1
		_problems = bad
		_applied = false
		_go()
		return
	_warn = bad
	for s: String in out["skipped"] as PackedStringArray:
		_warn.append(s)
	changed.assign(out["rects"] as Array)
	var did: bool = ed.room.commit({"op": "magic", "ask": _ask, "say": _say, "area": [area.position.x, area.position.y, area.size.x, area.size.y], "ops": int(out["done"]), "engine": _engine})
	_applied = _applied or did
	var note: String = str(data.get("note_for_claude", "")).strip_edges()
	if not note.is_empty():
		ed.notes.add(key, area_px().get_center(), "Asked: \"%s\". Couldn't be done here: %s" % [_ask, note], "")
		_warn.append("Left a note for Claude for the part the editor can't do.")
	if did:
		ed.after_edit(bool(out["paint"]))
		ed.sfx("star_constellation")
		for r: Rect2 in changed:
			ed.canvas.pop(r.get_center(), "rose")
	state = S.SHOW
	_show_result(did)


func _show_result(did: bool) -> void:
	_head.text = "Done" if did else "Nothing changed"
	_body.text = _say + ("\n\n" + "\n".join(_warn) if not _warn.is_empty() else "")
	_body.visible = true
	_text.text = ""
	_text.placeholder_text = "Not quite? Say what to change."
	_text.visible = true
	_chips.visible = false
	if did:
		_set_buttons([["Keep", "check", "lime", keep], ["Undo", "undo", "", undo], ["Try another", "wand", "", another]])
	else:
		_set_buttons([["Close", "check", "gold", close], ["Try another", "wand", "", another]])
	_place()


func keep() -> void:
	ed.sfx("ui_confirm")
	close()


func undo() -> void:
	ed.undo()
	close()


func another() -> void:
	if _applied and ed.room.can_undo():
		ed.undo()
	_applied = false
	send("Undo that. Same wish, but a clearly different idea: " + _ask)


func on_undo() -> void:
	if state == S.SHOW:
		close()
