extends RefCounted
## The room being edited: raw .map rows + raw JSON, with undo/redo, drafts and saving.
## Every save also keeps Claude's original (base/) and the hand-edited version (edited/) in docs/level_edits.

const Io := preload("res://luxel/editor/ed_io.gd")
const LISTS: Array[String] = ["interactables", "enemies", "scenery", "decor", "exits"]
const UNDO_MAX: int = 200
const DRAFT_MAP: String = "user://editor/draft.map"
const DRAFT_JSON: String = "user://editor/draft.json"

static var islands_dir: String = "res://luxel/islands"
static var edits_dir: String = Io.EDITS_DIR

var island: int = 1
var region: String = ""
var head: PackedStringArray = PackedStringArray()
var tail: PackedStringArray = PackedStringArray()
var rows: PackedStringArray = PackedStringArray()
var legend: Dictionary = {}
var json: Dictionary = {}
var width: int = 0
var height: int = 0
var ts: int = 16
var dirty: bool = false

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _pending: Dictionary = {}
var _disk_map: String = ""
var _disk_json: String = ""
var _json_newline: bool = true
var _json_ascii: bool = false


func key() -> String: return "%d:%s" % [island, region]
func file_key() -> String: return "%d_%s" % [island, region]
func map_path() -> String: return "%s/%d/%s.map" % [islands_dir, island, region]
func json_path() -> String: return "%s/%d/%s.json" % [islands_dir, island, region]
func px_size() -> Vector2: return Vector2(width * ts, height * ts)


func load_room(isl: int, reg: String) -> bool:
	island = isl
	region = reg
	_undo.clear()
	_redo.clear()
	_pending.clear()
	_disk_map = Io.read(map_path())
	_disk_json = Io.read(json_path())
	if _disk_map.is_empty() or _disk_json.is_empty():
		return false
	dirty = false
	return _parse(_disk_map, _disk_json)


func _parse(map_text: String, json_text: String) -> bool:
	head = PackedStringArray()
	tail = PackedStringArray()
	rows = PackedStringArray()
	legend = LxMapFormat.DEFAULT_LEGEND.duplicate()
	var lines: PackedStringArray = map_text.replace("\r\n", "\n").split("\n")
	# Some rooms are a bare grid with no header.
	var in_map: bool = not lines.has("MAP")
	var done: bool = false
	for line: String in lines:
		if done:
			tail.append(line)
		elif in_map:
			var s: String = line.strip_edges()
			if s.is_empty() or s == "END" or s == "ENDMAP":
				if s.is_empty() and rows.is_empty():
					continue
				done = true
				tail.append(line)
			else:
				rows.append(line)
		else:
			head.append(line)
			var t: String = line.strip_edges()
			if t == "MAP":
				in_map = true
			elif t.begins_with("LEGEND "):
				var parts: PackedStringArray = t.substr(7).strip_edges().split(" ", false)
				if parts.size() >= 2:
					legend[parts[0].substr(0, 1)] = parts[1].to_lower()
	json = Io.parse_json(json_text)
	_json_newline = json_text.ends_with("\n")
	_json_ascii = json_text.contains("\\u")
	ts = int(json.get("tile_size", 16))
	if ts <= 0:
		ts = 16
	height = rows.size()
	width = 0
	for r: String in rows:
		width = maxi(width, r.length())
	for i: int in range(height):
		rows[i] = rows[i].rpad(width, "_")
	return width > 0 and height > 0 and not json.is_empty()


func list(list_name: String) -> Array:
	## Read-only for a list the room doesn't have (reading must never change the file).
	return json[list_name] as Array if json.get(list_name) is Array else []


func own_list(list_name: String) -> Array:
	if not (json.get(list_name) is Array):
		json[list_name] = []
	return json[list_name] as Array


func item(ref: Dictionary) -> Dictionary:
	var a: Array = list(str(ref.get("list", "")))
	var i: int = int(ref.get("i", -1))
	return a[i] as Dictionary if i >= 0 and i < a.size() and a[i] is Dictionary else {}


func props(d: Dictionary) -> Dictionary:
	if not (d.get("props") is Dictionary):
		d["props"] = {}
	return d["props"] as Dictionary


func find_id(id: String) -> Dictionary:
	for l: String in ["interactables", "enemies"]:
		var a: Array = list(l)
		for i: int in range(a.size()):
			if a[i] is Dictionary and str((a[i] as Dictionary).get("id", "")) == id:
				return {"list": l, "i": i}
	return {}


func new_id(kind: String) -> String:
	var n: int = 1
	while true:
		var cand: String = "%s_%s_m%d" % [kind, region, n]
		if find_id(cand).is_empty():
			return cand
		n += 1
	return kind


# ---- Tiles ----

func tile(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "void"
	return str(legend.get(rows[y].substr(x, 1), "void"))


func set_tile(x: int, y: int, type: String) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height or tile(x, y) == type:
		return false
	var ch: String = _char_for(type)
	if ch.is_empty():
		return false
	rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)
	return true


func _char_for(type: String) -> String:
	if type == "void":
		return "_"
	for ch: String in legend.keys():
		if ch != " " and str(legend[ch]) == type:
			return ch
	for cand: String in "XYZWKLNQUVabcdefghijk":
		if not legend.has(cand):
			legend[cand] = type
			if not head.has("MAP"):
				head.append("MAP")
			head.insert(head.find("MAP"), "LEGEND %s %s" % [cand, type])
			return cand
	return ""


# ---- Undo ----

func snapshot() -> Dictionary:
	return {"rows": rows.duplicate(), "json": json.duplicate(true), "head": head.duplicate(), "legend": legend.duplicate()}


func begin() -> void:
	if _pending.is_empty():
		_pending = snapshot()


func cancel() -> void:
	if not _pending.is_empty():
		_restore(_pending)
		_pending = {}


func commit(op: Dictionary = {}) -> bool:
	if _pending.is_empty():
		return false
	var before: Dictionary = _pending
	_pending = {}
	if before["rows"] == rows and (before["json"] as Dictionary) == json:
		return false
	before["op"] = op
	_undo.append(before)
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()
	dirty = true
	if not op.is_empty():
		log_op(op)
	return true


func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var s: Dictionary = _undo.pop_back()
	var now: Dictionary = snapshot()
	now["op"] = s.get("op", {})
	_redo.append(now)
	_restore(s)
	dirty = true
	log_op({"op": "undo", "undid": (s.get("op", {}) as Dictionary).get("op", "")})
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var s: Dictionary = _redo.pop_back()
	var now: Dictionary = snapshot()
	now["op"] = s.get("op", {})
	_undo.append(now)
	_restore(s)
	dirty = true
	log_op({"op": "redo"})
	return true


func _restore(s: Dictionary) -> void:
	rows = (s["rows"] as PackedStringArray).duplicate()
	json = (s["json"] as Dictionary).duplicate(true)
	head = (s["head"] as PackedStringArray).duplicate()
	legend = (s["legend"] as Dictionary).duplicate()


# ---- Files ----

func map_text() -> String:
	var out := PackedStringArray()
	out.append_array(head)
	out.append_array(rows)
	out.append_array(tail)
	return "\n".join(out)


func json_text() -> String:
	var t: String = Io.to_json(json)
	return (Io.ascii(t) if _json_ascii else t) + ("\n" if _json_newline else "")


func write_draft() -> void:
	Io.write(DRAFT_MAP, map_text())
	Io.write(DRAFT_JSON, json_text())


func base_map_path() -> String: return "%s/base/%s.map.txt" % [edits_dir, file_key()]
func base_json_path() -> String: return "%s/base/%s.json" % [edits_dir, file_key()]
func has_base() -> bool: return FileAccess.file_exists(base_map_path())


func changed_by_hand() -> bool:
	return has_base() and (map_text() != Io.read(base_map_path()) or json != Io.parse_json(Io.read(base_json_path())))


func save() -> bool:
	## Writes the room to the game's own files. False when nothing changed.
	var m: String = map_text()
	var j: String = json_text()
	dirty = false
	var same_json: bool = Io.parse_json(j) == Io.parse_json(_disk_json)
	if m == _disk_map and same_json:
		return false
	if not has_base():
		Io.write(base_map_path(), _disk_map)
		Io.write(base_json_path(), _disk_json)
	if m != _disk_map:
		Io.write(map_path(), m)
		_disk_map = m
	if not same_json:
		Io.write(json_path(), j)
		_disk_json = j
	Io.write("%s/edited/%s.map.txt" % [edits_dir, file_key()], _disk_map)
	Io.write("%s/edited/%s.json" % [edits_dir, file_key()], _disk_json)
	return true


func reset_to_base() -> bool:
	if not has_base():
		return false
	begin()
	if not _parse(Io.read(base_map_path()), Io.read(base_json_path())):
		cancel()
		return false
	return commit({"op": "reset_room"})


func disk_map() -> String: return _disk_map


func log_op(op: Dictionary) -> void:
	var line: Dictionary = {"t": Io.stamp_now(), "room": key()}
	line.merge(op)
	Io.append_line("%s/log.jsonl" % edits_dir, JSON.stringify(line))


# ---- Wires (which switch drives which door) ----

const OUT_KEYS: Array[String] = ["target_id", "target_ids", "target_portal_id", "linked_to", "links", "rotors", "bells", "linked_crystal", "mirror_id", "points_to"]
const IN_KEYS: Array[String] = ["requires_signals", "required_signals", "inputs"]


static func _as_list(v: Variant) -> Array:
	if v is Array:
		return v as Array
	return [v] if v is String and not (v as String).is_empty() else []


func wires() -> Array[Dictionary]:
	## [{from, to}] indices into interactables, without duplicates.
	var a: Array = list("interactables")
	var by_id: Dictionary = {}
	for i: int in range(a.size()):
		by_id[str((a[i] as Dictionary).get("id", ""))] = i
	var seen: Dictionary = {}
	var out: Array[Dictionary] = []
	for i: int in range(a.size()):
		var d: Dictionary = a[i] as Dictionary
		var pr: Dictionary = d["props"] as Dictionary if d.get("props") is Dictionary else {}
		for k: String in OUT_KEYS:
			for t: Variant in _as_list(pr.get(k)):
				if by_id.has(str(t)) and int(by_id[str(t)]) != i:
					_add_wire(out, seen, i, int(by_id[str(t)]))
		for k: String in IN_KEYS:
			for t: Variant in _as_list(pr.get(k)):
				if by_id.has(str(t)) and int(by_id[str(t)]) != i:
					_add_wire(out, seen, int(by_id[str(t)]), i)
	return out


func _add_wire(out: Array[Dictionary], seen: Dictionary, from: int, to: int) -> void:
	var k := Vector2i(from, to)
	if seen.has(k):
		return
	seen[k] = true
	out.append({"from": from, "to": to})


func has_wire(from: int, to: int) -> bool:
	for w: Dictionary in wires():
		if int(w["from"]) == from and int(w["to"]) == to:
			return true
	return false


func add_wire(from: int, to: int) -> void:
	var a: Array = list("interactables")
	var src: Dictionary = a[from] as Dictionary
	var dst: Dictionary = a[to] as Dictionary
	var sid: String = str(src.get("id", ""))
	var did: String = str(dst.get("id", ""))
	var sp: Dictionary = props(src)
	var dp: Dictionary = props(dst)
	var sk: String = str(src.get("kind", ""))
	var dk: String = str(dst.get("kind", ""))
	if sk == "blue_portal" and dk == "blue_portal":
		sp["target_portal_id"] = did
		dp["target_portal_id"] = sid
		return
	if sk == "star_node" and dk == "star_node":
		_list_add(sp, "links", did)
		return
	if sp.has("target_ids") or (sp.has("target_id") and not str(sp["target_id"]).is_empty()):
		var cur: Array = _as_list(sp.get("target_ids")).duplicate()
		if sp.has("target_id"):
			if not cur.has(sp["target_id"]) and not str(sp["target_id"]).is_empty():
				cur.push_front(sp["target_id"])
			sp.erase("target_id")
		if not cur.has(did):
			cur.append(did)
		sp["target_ids"] = cur
	else:
		sp["target_id"] = did
	if dk == "logic_gate" or dp.has("inputs"):
		_list_add(dp, "inputs", sid)
	elif dk in ["door", "switch_door", "bridge_platform", "combat_gate"] or dp.has("requires_signals"):
		_list_add(dp, "requires_signals", sid)


func remove_wire(from: int, to: int) -> void:
	var a: Array = list("interactables")
	var sp: Dictionary = props(a[from] as Dictionary)
	var dp: Dictionary = props(a[to] as Dictionary)
	var sid: String = str((a[from] as Dictionary).get("id", ""))
	var did: String = str((a[to] as Dictionary).get("id", ""))
	for k: String in OUT_KEYS:
		_list_drop(sp, k, did)
	for k: String in IN_KEYS:
		_list_drop(dp, k, sid)
	if str(dp.get("target_portal_id", "")) == sid:
		dp.erase("target_portal_id")


func drop_references(id: String) -> void:
	## After deleting `id`, nothing in the room should still wait for it.
	for d_v: Variant in list("interactables"):
		var pr: Variant = (d_v as Dictionary).get("props")
		if pr is Dictionary:
			for k: String in OUT_KEYS + IN_KEYS:
				_list_drop(pr as Dictionary, k, id)


static func _list_add(pr: Dictionary, k: String, id: String) -> void:
	var cur: Array = _as_list(pr.get(k)).duplicate()
	if not cur.has(id):
		cur.append(id)
	pr[k] = cur


static func _list_drop(pr: Dictionary, k: String, id: String) -> void:
	if not pr.has(k):
		return
	if pr[k] is Array:
		(pr[k] as Array).erase(id)
		if (pr[k] as Array).is_empty():
			pr.erase(k)
	elif str(pr[k]) == id:
		pr.erase(k)


func shift_item(ref: Dictionary, d: Vector2) -> void:
	## Moves a thing with everything that hangs on it (patrol route, perches, rect).
	var it: Dictionary = item(ref)
	if it.is_empty():
		return
	if it.has("pos"):
		it["pos"] = Io.arr(Io.vec(it["pos"]) + d)
	if it.get("rect") is Array and (it["rect"] as Array).size() >= 4:
		var r: Array = it["rect"] as Array
		it["rect"] = [Io.num(float(r[0]) + d.x), Io.num(float(r[1]) + d.y), r[2], r[3]]
	if str(ref.get("list", "")) == "decor" and not it.has("pos") and not it.has("rect"):
		for k: String in ["x", "x0", "x1"]:
			if it.has(k):
				it[k] = Io.num(float(it[k]) + d.x)
		if it.has("y"):
			it["y"] = Io.num(float(it["y"]) + d.y)
	if str(ref.get("list", "")) == "enemies":
		for k: String in ["route", "perches"]:
			if it.get(k) is Array:
				var pts: Array = []
				for p: Variant in (it[k] as Array):
					pts.append(Io.arr(Io.vec(p) + d) if p is Array else p)
				it[k] = pts
