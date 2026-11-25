extends Node
## Level editor core: the open room, what is selected, and every edit you can make to it (editor.gd adds the screen).

const Style := preload("res://luxel/editor/ed_style.gd")
const Io := preload("res://luxel/editor/ed_io.gd")
const Room := preload("res://luxel/editor/ed_room.gd")
const Catalog := preload("res://luxel/editor/ed_catalog.gd")
const Thumbs := preload("res://luxel/editor/ed_thumbs.gd")
const World := preload("res://luxel/editor/ed_world.gd")
const Notes := preload("res://luxel/editor/ed_notes.gd")
const Canvas := preload("res://luxel/editor/ed_canvas.gd")
const Palette := preload("res://luxel/editor/ed_palette.gd")
const SideCard := preload("res://luxel/editor/ed_side.gd")
const Browser := preload("res://luxel/editor/ed_browser.gd")

enum Tool { HAND, STAMP, ERASE, WIRE, NOTE }

const SESSION: String = "user://editor/session.json"
const UI_SIZE := Vector2i(1280, 720)
const TOP_H: float = 52.0
const BOTTOM_H: float = 174.0

var main: LxMain = null
var world: World = null
var room: Room = null
var catalog: Catalog = null
var thumbs: Thumbs = null
var notes: Notes = null
var canvas: Canvas = null
var cam: Camera2D = null
var ui: CanvasLayer = null

var playing: bool = false
var tool: int = Tool.HAND
var tab: String = "ground"
var stamp: Dictionary = {}
var brush: int = 1
var selection: Array[Dictionary] = []
var wire_from: Dictionary = {}

var _palette: Palette = null
var _side: SideCard = null
var _browser: Browser = null
var _title: Label = null
var _sub: Label = null
var _help: PanelContainer = null
var _saved: Label = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _toast: Label = null
var _toast_t: float = 0.0
var _note_box: PanelContainer = null
var _note_text: TextEdit = null
var _note_cur: Dictionary = {}
var _note_head: Label = null
var _note_reply: Label = null
var _hint_layer: CanvasLayer = null
var _hint_root: Control = null
var _clip: Array[Dictionary] = []
var _save_t: float = -1.0
var _last_sfx: float = 0.0
var _god: bool = false


# ---- Names ----

func region_title(isl: int, reg: String) -> String:
	var nk: String = str(Lx.packs.region_meta(isl, reg).get("name_key", "")) if Lx.packs != null else ""
	if nk.is_empty() and room != null and room.island == isl and room.region == reg:
		nk = str(room.json.get("name_key", ""))
	if not nk.is_empty() and LxStrings.has_id(nk):
		return LxStrings.text(nk).capitalize()
	return reg.replace("_", " ").capitalize()


func room_title_of(ex: Dictionary) -> String:
	var reg: String = str(ex.get("to_region", "?"))
	var isl: int = int(ex.get("to_island", room.island))
	if reg.begins_with("island") and reg.contains(":"):
		isl = int(reg.get_slice(":", 0).trim_prefix("island"))
		reg = reg.get_slice(":", 1)
	return region_title(isl, reg)


func room_title() -> String: return region_title(room.island, room.region)


func dungeon_title(g: String) -> String:
	var nk: String = str(Lx.packs.dungeon(g).get("name_key", ""))
	return LxStrings.text(nk) if LxStrings.has_id(nk) else g.replace("_", " ")


func room_subtitle() -> String:
	var g: String = Lx.packs.dungeon_of(room.island, room.region) if Lx.packs != null else ""
	return "%s, %s (%s)" % ["Hub" if room.island == 0 else "Island %d" % room.island, "outside" if g.is_empty() else dungeon_title(g).capitalize(), room.region]


# ---- Selecting ----

func select(refs: Array) -> void:
	selection.clear()
	for r: Variant in refs:
		selection.append(r as Dictionary)
	_side.refresh()


func toggle_select(ref: Dictionary) -> void:
	for i: int in range(selection.size()):
		if selection[i]["list"] == ref["list"] and int(selection[i]["i"]) == int(ref["i"]):
			selection.remove_at(i)
			_side.refresh()
			return
	selection.append(ref)
	_side.refresh()


func node_of(ref: Dictionary) -> Node2D:
	var i: int = int(ref["i"])
	var it: Dictionary = room.item(ref)
	match str(ref["list"]):
		"scenery":
			return world.loader._scenery_props[i] if i < world.loader._scenery_props.size() else null
		"interactables":
			return world.loader.find_interactable(str(it.get("id", "")))
		"enemies":
			for e: LxEnemyBrain in world.loader.get_enemies():
				if e.enemy_id == str(it.get("id", "")):
					return e
	return null


func set_tool(t: int) -> void:
	tool = t
	wire_from = {}
	if t != Tool.HAND and t != Tool.WIRE:
		select([])
	_palette.sync_tool()
	canvas._hint()
	match t:
		Tool.WIRE: toast("Drag from a switch, plate or lamp to the door it should open.")
		Tool.NOTE: toast("Click anywhere to pin a note for Claude.")


func set_tab(t: String) -> void:
	tab = t
	_palette._search.text = ""
	_palette.refresh()
	sfx("ui_move")


func pick_stamp(e: Dictionary) -> void:
	if tool == Tool.STAMP and Thumbs.key_of(stamp) == Thumbs.key_of(e):
		set_tool(Tool.HAND)
		return
	stamp = e.duplicate()
	set_tool(Tool.STAMP)
	sfx("ui_move")


func set_stamp_tile(t: String) -> void:
	for e: Dictionary in catalog.TILES:
		if str(e["id"]) == t:
			stamp = {"type": "tile", "kind": t, "name": e["name"]}
			set_tool(Tool.STAMP)
			toast("Painting: %s" % str(e["name"]))


func stamp_copy(ref: Dictionary) -> void:
	## Right-click: hold a copy of that exact thing, ready to place.
	var it: Dictionary = room.item(ref)
	stamp = canvas.entry_of(ref)
	stamp["copy"] = it.duplicate(true)
	stamp["name"] = catalog.name_of(str(ref["list"]), it)
	set_tool(Tool.STAMP)
	toast("Copying: %s" % str(stamp["name"]))


# ---- Edits ----

func after_edit(repaint: bool = false) -> void:
	world.rebuild(room, world.wick.global_position)
	_save_t = 0.8
	_status("...")
	if repaint:
		save_now()
		world.request_paint(room)
	_refresh()


func commit_tiles() -> void:
	if room.commit({"op": "tiles", "tile": stamp.get("kind", "")}):
		after_edit(true)


func place(e: Dictionary, pos: Vector2) -> void:
	var l: String = str(e["type"])
	if l == "tile":
		return
	var spec: Dictionary = {}
	var kind: String = str(e["kind"])
	if e.has("copy"):
		spec = (e["copy"] as Dictionary).duplicate(true)
	else:
		spec = catalog.spec_for(e, "", pos)
	if l == "interactables" and kind == "moth":
		var mid: String = catalog.next_moth(room.island)
		if mid.is_empty():
			toast("Every moth of this island is already placed. Move one of those instead.")
			sfx("denied")
			return
		catalog.used_moths[mid] = true
		spec["props"] = {"id": mid}
	room.begin()
	if l in ["interactables", "enemies"]:
		spec["id"] = room.new_id(kind)
	var ref: Dictionary = {"list": l, "i": room.list(l).size()}
	room.own_list(l).append(spec)
	if e.has("copy"):
		room.shift_item(ref, pos - _anchor(spec))
	_fill_zone(l, kind, spec, pos, e.has("copy"))
	if not room.commit({"op": "add", "list": l, "kind": kind, "id": spec.get("id", ""), "pos": Io.arr(pos)}):
		return
	canvas.pop(pos)
	sfx("prop_chime" if l == "scenery" else "pane_fit")
	after_edit(l == "decor")


func _anchor(it: Dictionary) -> Vector2:
	if it.has("pos"):
		return Io.vec(it["pos"])
	if it.get("rect") is Array:
		return LxMapFormat.to_rect2(it["rect"]).get_center()
	return Vector2.ZERO


func _fill_zone(l: String, kind: String, spec: Dictionary, pos: Vector2, copied: bool) -> void:
	var zid: String = ""
	for z_v: Variant in room.list("zones"):
		if z_v is Dictionary and LxMapFormat.to_rect2((z_v as Dictionary).get("rect", [])).has_point(pos):
			zid = str((z_v as Dictionary).get("id", ""))
			break
	if zid.is_empty():
		return
	if l == "enemies":
		spec["zone"] = zid
	elif l == "interactables":
		var o: Dictionary = catalog.objects.get(kind, {}) as Dictionary
		var seen: Dictionary = (o.get("props", {}) as Dictionary).get("zone", {}) as Dictionary
		var n: int = 0
		for v: Variant in seen.values():
			n += int(v)
		if (copied and room.props(spec).has("zone")) or n * 2 >= int(o.get("count", 1)) or str(room.props(spec).get("door_kind", "")) == "combat_gate":
			room.props(spec)["zone"] = zid


func move_selection(d: Vector2) -> void:
	room.begin()
	var what: Array = []
	var floor_art: bool = false
	for s: Dictionary in selection:
		room.shift_item(s, d)
		what.append(str(room.item(s).get("id", room.item(s).get("prop", room.item(s).get("kind", "")))))
		floor_art = floor_art or str(s["list"]) == "decor"
	if room.commit({"op": "move", "what": what, "by": Io.arr(d)}):
		sfx("wood_shift")
		for s: Dictionary in selection:
			canvas.pop(canvas.rect_of(s).get_center(), "cream")
		after_edit(floor_art)
	else:
		world.rebuild(room, world.wick.global_position)


func erase_now(ref: Dictionary) -> void:
	var l: String = str(ref["list"])
	var it: Dictionary = room.item(ref)
	var id: String = str(it.get("id", ""))
	var node: Node2D = node_of(ref)
	if node != null:
		node.visible = false
	if l == "scenery" and node != null:
		world.loader._scenery_props.erase(node)
	room.list(l).remove_at(int(ref["i"]))
	if not id.is_empty():
		room.drop_references(id)
	selection.clear()
	sfx("snuffer_gulp")


func commit_erase() -> void:
	if room.commit({"op": "erase"}):
		after_edit(tab == "decor")


func delete_selection() -> void:
	if selection.is_empty():
		return
	room.begin()
	var refs: Array[Dictionary] = selection.duplicate()
	refs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["i"]) > int(b["i"]))
	var what: Array = []
	var floor_art: bool = false
	for r: Dictionary in refs:
		if str(r["list"]) == "exits":
			continue
		var it: Dictionary = room.item(r)
		what.append(str(it.get("id", it.get("prop", it.get("kind", "")))))
		canvas.pop(canvas.rect_of(r).get_center(), "coral")
		floor_art = floor_art or str(r["list"]) == "decor"
		room.list(str(r["list"])).remove_at(int(r["i"]))
		if it.has("id"):
			room.drop_references(str(it["id"]))
	selection.clear()
	if room.commit({"op": "delete", "what": what}):
		toast("Deleted %d. Cmd+Z brings it back." % what.size())
		sfx("snuffer_gulp")
		after_edit(floor_art)


func duplicate_selection() -> void:
	_copy_clip()
	_paste_clip(Vector2(16, 16))


func _copy_clip() -> void:
	_clip.clear()
	for s: Dictionary in selection:
		_clip.append({"list": s["list"], "spec": room.item(s).duplicate(true)})


func _paste_clip(offset: Vector2) -> void:
	if _clip.is_empty():
		return
	room.begin()
	var fresh: Array[Dictionary] = []
	for c: Dictionary in _clip:
		var l: String = str(c["list"])
		var spec: Dictionary = (c["spec"] as Dictionary).duplicate(true)
		if l in ["interactables", "enemies"]:
			spec["id"] = room.new_id(str(spec.get("kind", "thing")))
		var ref: Dictionary = {"list": l, "i": room.list(l).size()}
		room.own_list(l).append(spec)
		room.shift_item(ref, offset)
		fresh.append(ref)
	if room.commit({"op": "paste", "n": fresh.size()}):
		selection = fresh
		sfx("pane_fit")
		after_edit()


func flip_selection() -> void:
	room.begin()
	for s: Dictionary in selection:
		if str(s["list"]) == "scenery":
			room.item(s)["flip_x"] = not bool(room.item(s).get("flip_x", false))
	if room.commit({"op": "flip"}):
		sfx("mirror_turn")
		after_edit()


func set_field(ref: Dictionary, k: String, v: Variant) -> void:
	room.begin()
	room.item(ref)[k] = v
	if room.commit({"op": "set", "what": room.item(ref).get("id", room.item(ref).get("prop", "")), "field": k, "to": v}):
		sfx("ui_move")
		after_edit(str(ref["list"]) == "decor")


func set_prop(ref: Dictionary, k: String, v: Variant) -> void:
	room.begin()
	var pr: Dictionary = room.props(room.item(ref))
	pr[k] = v
	if str(room.item(ref).get("kind", "")) == "chest" and k in ["reward", "reward_kind"]:
		pr["reward"] = v
		pr["reward_kind"] = v
	if room.commit({"op": "set", "what": room.item(ref).get("id", ""), "field": k, "to": v}):
		sfx("ui_move")
		after_edit()


func add_patrol(ref: Dictionary) -> void:
	room.begin()
	var it: Dictionary = room.item(ref)
	var pts: Array = (it.get("route", []) as Array).duplicate() if it.get("route") is Array else []
	var last: Vector2 = Io.vec(pts[-1]) if not pts.is_empty() else Io.vec(it.get("pos", [0, 0]))
	pts.append(Io.arr(last + Vector2(32, 0)))
	it["route"] = pts
	if room.commit({"op": "patrol", "what": it.get("id", "")}):
		after_edit()


func toggle_wire(a: Dictionary, b: Dictionary) -> void:
	var f: int = int(a["i"])
	var t: int = int(b["i"])
	room.begin()
	var off: bool = room.has_wire(f, t)
	if off:
		room.remove_wire(f, t)
	else:
		room.add_wire(f, t)
	if room.commit({"op": "unwire" if off else "wire", "from": room.item(a).get("id", ""), "to": room.item(b).get("id", "")}):
		sfx("silk_snap" if off else "star_ignite")
		toast("Unplugged." if off else "%s now drives %s." % [catalog.name_of("interactables", room.item(a)), catalog.name_of("interactables", room.item(b))])
		after_edit()


func undo() -> void:
	var art: Array = room.list("decor").duplicate(true)
	_time_travel(room.undo(), art)


func redo() -> void:
	var art: Array = room.list("decor").duplicate(true)
	_time_travel(room.redo(), art)


func _time_travel(ok: bool, art: Array) -> void:
	if not ok:
		return
	selection.clear()
	sfx("ui_back")
	after_edit(world.has_unpainted() or art != room.list("decor"))


func reset_room() -> void:
	if room.reset_to_base():
		selection.clear()
		toast("Back to Claude's version. Cmd+Z returns yours.")
		after_edit(true)


# ---- Saving and messages ----

func save_now() -> void:
	_save_t = -1.0
	if room == null:
		return
	room.save()
	_status("Saved")


func _on_painted(ok: bool) -> void:
	_status("Saved")
	if not ok:
		toast("Saved, but the floor couldn't be repainted. Claude will fix the art.")


func _status(t: String) -> void:
	_saved.text = t
	_saved.add_theme_color_override("font_color", Style.col("jade") if t == "Saved" else Style.col("apricot"))


func _refresh() -> void:
	_title.text = room_title()
	_sub.text = room_subtitle()
	_undo_btn.disabled = not room.can_undo()
	_redo_btn.disabled = not room.can_redo()
	_side.refresh()


func toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast.reset_size()
	_toast.position = Vector2((canvas.size.x - 300.0 - _toast.size.x) * 0.5, TOP_H + 12.0)
	_toast_t = 3.2


func sfx(id: String, gap: float = 0.0) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if gap > 0.0 and now - _last_sfx < gap:
		return
	_last_sfx = now
	if Lx.audio != null:
		Lx.audio.play_sfx(id, Vector2.ZERO, false, true)
