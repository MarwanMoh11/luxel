extends Control
## The level view, part one: camera, coordinates and finding what is under the mouse (ed_canvas.gd adds input and drawing).

const Style := preload("res://luxel/editor/ed_style.gd")
const Io := preload("res://luxel/editor/ed_io.gd")
const Thumbs := preload("res://luxel/editor/ed_thumbs.gd")
const PICK_LISTS: Array[String] = ["enemies", "interactables", "scenery"]

var ed: Node = null
var cam: Camera2D = null
var zoom: float = 3.0
var mouse_w: Vector2 = Vector2.ZERO
var hover: Dictionary = {}
var grid_on: bool = true

var _pan: bool = false
var _press: String = ""  # what the held left button is doing
var _press_s: Vector2 = Vector2.ZERO
var _press_w: Vector2 = Vector2.ZERO
var _drag_from: Array[Vector2] = []
var _drag_d: Vector2 = Vector2.ZERO
var _last_cell: Vector2i = Vector2i(-99, -99)
var _rect_from: Vector2i = Vector2i(-99, -99)
var _cycle_at: Vector2 = Vector2(-999, -999)
var _cycle_i: int = 0
var _pop: Array[Dictionary] = []  # small placing effects {pos, t, col}
var _handle: Dictionary = {}
var _t: float = 0.0
var _inside: bool = false


func _ready() -> void:
	mouse_entered.connect(func() -> void: _inside = true)
	mouse_exited.connect(func() -> void: _inside = false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func w2s(p: Vector2) -> Vector2: return (p - cam.position) * zoom + size * 0.5
func s2w(p: Vector2) -> Vector2: return (p - size * 0.5) / zoom + cam.position
func r2s(r: Rect2) -> Rect2: return Rect2(w2s(r.position), r.size * zoom)


func set_zoom(z: float, around: Vector2 = Vector2(-1, -1)) -> void:
	var at: Vector2 = around if around.x >= 0.0 else size * 0.5
	var w: Vector2 = s2w(at)
	zoom = clampf(z, 0.6, 8.0)
	cam.zoom = Vector2(zoom, zoom)
	cam.position += w - s2w(at)
	_keep_near()


func fit() -> void:
	var px: Vector2 = ed.room.px_size()
	var area: Rect2 = ed.free_area()
	zoom = clampf(minf(area.size.x / (px.x + 24.0), area.size.y / (px.y + 24.0)), 0.6, 5.0)
	cam.zoom = Vector2(zoom, zoom)
	cam.position = px * 0.5 - (area.get_center() - size * 0.5) / zoom


func look_at_world(p: Vector2) -> void:
	cam.position = p - (ed.free_area().get_center() - size * 0.5) / zoom
	_keep_near()


func _keep_near() -> void:
	var px: Vector2 = ed.room.px_size()
	cam.position = cam.position.clamp(Vector2(-160, -160), px + Vector2(160, 160))


func _process(dt: float) -> void:
	_t += dt
	for i: int in range(_pop.size() - 1, -1, -1):
		_pop[i]["t"] = float(_pop[i]["t"]) + dt
		if float(_pop[i]["t"]) > 0.35:
			_pop.remove_at(i)
	queue_redraw()


func pop(p: Vector2, c: String = "gold") -> void:
	_pop.append({"pos": p, "t": 0.0, "col": c})


# ---- Picking ----

func rect_of(ref: Dictionary) -> Rect2:
	var it: Dictionary = ed.room.item(ref)
	if it.is_empty():
		return Rect2()
	var p: Vector2 = Io.vec(it.get("pos", [0, 0]))
	match str(ref["list"]):
		"exits":
			return LxMapFormat.to_rect2(it.get("rect", []))
		"decor":
			if it.get("rect") is Array: return LxMapFormat.to_rect2(it["rect"])
			if it.has("x0"): return Rect2(float(it["x0"]), float(it.get("y", 0)), float(it.get("x1", 0)) - float(it["x0"]), 24.0)
			if it.has("w"): return Rect2(float(it.get("x", 0)), float(it.get("y", 0)), float(it["w"]), float(it.get("h", 16)))
			if it.has("x"): p = Vector2(float(it["x"]), float(it.get("y", 0)))
			if it.get("size") is Array:
				var sz: Vector2 = Io.vec(it["size"])
				return Rect2(p - sz * 0.5, sz)
			var rr: float = float(it.get("radius", it.get("r", 16)))
			return Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
		"interactables":
			var pr: Dictionary = it["props"] as Dictionary if it.get("props") is Dictionary else {}
			if pr.get("size") is Array and (pr["size"] as Array).size() >= 2:
				var s2: Vector2 = Io.vec(pr["size"]).max(Vector2(12, 12))
				return Rect2(p - s2 * 0.5, s2)
	var th: Dictionary = ed.thumbs.get_thumb(entry_of(ref))
	if not th.is_empty():
		var r: Rect2 = th["rect"] as Rect2
		if bool(it.get("flip_x", false)):
			r.position.x = -r.position.x - r.size.x
		r = Rect2(p + r.position, r.size)
		if r.size.x < 8.0 or r.size.y < 8.0:
			r = r.grow(4.0)
		return r
	return Rect2(p - Vector2(10, 16), Vector2(20, 22))


func entry_of(ref: Dictionary) -> Dictionary:
	var it: Dictionary = ed.room.item(ref)
	if str(ref["list"]) == "scenery":
		return {"type": "scenery", "sheet": it.get("sheet", ""), "kind": it.get("prop", "")}
	return {"type": ref["list"], "kind": it.get("kind", "")}


func pick_all(w: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lists: Array[String] = PICK_LISTS.duplicate()
	if ed.tab == "decor":
		lists.push_front("decor")
	for l: String in lists:
		var a: Array = ed.room.list(l)
		for i: int in range(a.size()):
			var ref: Dictionary = {"list": l, "i": i}
			var r: Rect2 = rect_of(ref)
			if r.grow(2.0).has_point(w):
				var area: float = r.get_area()
				if l == "scenery" and ed.tab != "scenery":
					area += 300.0
				if l == "decor":
					area = r.get_area() - 100000.0
				out.append({"ref": ref, "area": area})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["area"]) < float(b["area"]))
	var refs: Array[Dictionary] = []
	for o: Dictionary in out:
		refs.append(o["ref"] as Dictionary)
	return refs


func pick(w: Vector2) -> Dictionary:
	var c: Array[Dictionary] = pick_all(w)
	return c[0] if not c.is_empty() else {}


func exit_at(w: Vector2) -> Dictionary:
	var a: Array = ed.room.list("exits")
	for i: int in range(a.size()):
		if rect_of({"list": "exits", "i": i}).grow(4.0).has_point(w):
			return a[i] as Dictionary
	return {}


func note_at(s: Vector2) -> Dictionary:
	for n: Dictionary in ed.notes.of_room(ed.room.key()):
		if Rect2(w2s(Io.vec(n["pos"])) + Vector2(-13, -34), Vector2(26, 36)).has_point(s):
			return n
	return {}


func cell(w: Vector2) -> Vector2i:
	return Vector2i(floori(w.x / ed.room.ts), floori(w.y / ed.room.ts))


func snap(p: Vector2, step: float) -> Vector2:
	var st: float = 1.0 if Input.is_key_pressed(KEY_ALT) else step
	return (p / st).round() * st


func snap_step(list_name: String) -> float:
	return 4.0 if list_name in ["scenery", "decor"] else 8.0


func _same(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and a["list"] == b["list"] and int(a["i"]) == int(b["i"])


func is_selected(ref: Dictionary) -> bool:
	for s: Dictionary in ed.selection:
		if _same(s, ref):
			return true
	return false
