extends RefCounted
## The designer's notes pinned in rooms, and a verdict per room. Plain JSON in docs/level_edits so Claude reads it back;
## Claude answers by setting "reply" and "status": "done".

const Io := preload("res://luxel/editor/ed_io.gd")
const Room := preload("res://luxel/editor/ed_room.gd")

var notes: Array = []
var verdicts: Dictionary = {}
var checks: Dictionary = {}  # room -> {question: "yes" / "no"}


func _notes_path() -> String: return Room.edits_dir + "/notes.json"
func _verdicts_path() -> String: return Room.edits_dir + "/verdicts.json"


func load_all() -> void:
	var n: Variant = Io.read_json(_notes_path(), [])
	notes = n as Array if n is Array else []
	var v: Variant = Io.read_json(_verdicts_path(), {})
	verdicts = v as Dictionary if v is Dictionary else {}
	var c: Variant = Io.read_json(Room.edits_dir + "/checks.json", {})
	checks = c as Dictionary if c is Dictionary else {}


func save_all() -> void:
	Io.write(_notes_path(), Io.to_json(notes) + "\n")
	Io.write(_verdicts_path(), Io.to_json(verdicts) + "\n")
	Io.write(Room.edits_dir + "/checks.json", Io.to_json(checks) + "\n")


func of_room(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n_v: Variant in notes:
		if n_v is Dictionary and str((n_v as Dictionary).get("room", "")) == key:
			out.append(n_v as Dictionary)
	return out


func add(key: String, pos: Vector2, text: String, target: String) -> Dictionary:
	var top: int = 0
	for n_v: Variant in notes:
		top = maxi(top, int((n_v as Dictionary).get("id", 0)))
	var n: Dictionary = {"id": top + 1, "room": key, "pos": Io.arr(pos.round()), "target": target, "text": text, "status": "open", "reply": "", "time": Io.stamp_now()}
	notes.append(n)
	save_all()
	return n


func remove(id: int) -> void:
	for i: int in range(notes.size() - 1, -1, -1):
		if int((notes[i] as Dictionary).get("id", 0)) == id:
			notes.remove_at(i)
	save_all()


func verdict(key: String) -> String:
	return str((verdicts.get(key, {}) as Dictionary).get("verdict", ""))


func set_verdict(key: String, v: String) -> void:
	if v.is_empty():
		verdicts.erase(key)
	else:
		verdicts[key] = {"verdict": v, "time": Io.stamp_now()}
	save_all()


func check(key: String, question: String) -> String:
	return str((checks.get(key, {}) as Dictionary).get(question, ""))


func set_check(key: String, question: String, v: String) -> void:
	var d: Dictionary = checks.get_or_add(key, {}) as Dictionary
	if v.is_empty():
		d.erase(question)
	else:
		d[question] = v
	if d.is_empty():
		checks.erase(key)
	save_all()


func open_count(key: String) -> int:
	var c: int = 0
	for n: Dictionary in of_room(key):
		if str(n.get("status", "open")) != "done":
			c += 1
	return c
