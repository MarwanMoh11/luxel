extends RefCounted
## What each room, place and island was designed to be, in plain words: vision/island_<n>.json (written from the design
## documents) plus the room's own recorded design (what it teaches, how long it should take, the intended way through).

const Io := preload("res://luxel/editor/ed_io.gd")

const BEATS: Dictionary = {
	"ki": ["Introduce", "Shows an idea safely for the first time."],
	"sho": ["Develop", "Builds on an idea you already know."],
	"ten": ["Twist", "Turns the idea on its head."],
	"ketsu": ["Master", "Asks for everything so far."],
}
const KINDS: Dictionary = {"puzzle": "Puzzle", "combat": "Fight", "boss": "Boss", "story": "Story", "traversal": "Movement", "setpiece": "Set piece", "reward": "Reward"}

var ed: Node = null
var _files: Dictionary = {}  # island -> {time, data}
var _steps_for: Dictionary = {}
var _steps: Dictionary = {}


func _file(isl: int) -> Dictionary:
	var path: String = "res://luxel/editor/vision/island_%d.json" % isl
	if not FileAccess.file_exists(path):
		return {}
	var t: int = FileAccess.get_modified_time(path)
	var c: Dictionary = _files.get(isl, {}) as Dictionary
	if int(c.get("time", -1)) != t:
		var d: Variant = JSON.parse_string(Io.read(path))
		if not (d is Dictionary):
			return c.get("data", {}) as Dictionary
		_files[isl] = {"time": t, "data": d}
	return (_files[isl] as Dictionary)["data"] as Dictionary


func stamp(isl: int) -> int:
	var path: String = "res://luxel/editor/vision/island_%d.json" % isl
	return FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0


func _part(isl: int, block: String, id: String) -> Dictionary:
	var b: Variant = _file(isl).get(block, {})
	var d: Variant = (b as Dictionary).get(id, {}) if b is Dictionary else {}
	return d as Dictionary if d is Dictionary else {}


func island(isl: int) -> Dictionary:
	var d: Variant = _file(isl).get("island", {})
	return d as Dictionary if d is Dictionary else {}


func place(isl: int, dungeon: String) -> Dictionary: return _part(isl, "dungeons", dungeon)
func room(isl: int, reg: String) -> Dictionary: return _part(isl, "rooms", reg)


static func design(json: Dictionary) -> Dictionary:
	return json["design"] as Dictionary if json.get("design") is Dictionary else {}


func promise(isl: int, reg: String, json: Dictionary) -> String:
	var p: String = str(room(isl, reg).get("promise", ""))
	return p if not p.is_empty() else tidy(str(design(json).get("idea", "")))


static func tidy(t: String) -> String:
	## Drops the design documents' bookkeeping: (D06 fixed), (L_min=8)...
	var re := RegEx.create_from_string("\\s*\\((D\\d+[^)]*|L_?min[^)]*|R\\d+[^)]*)\\)")
	return re.sub(t, "", true).replace("_", " ").strip_edges()


func shape(json: Dictionary) -> String:
	## One line: what kind of room, where in the learning curve, how long.
	var d: Dictionary = design(json)
	var out := PackedStringArray()
	if KINDS.has(str(d.get("kind", ""))):
		out.append(str(KINDS[str(d["kind"])]))
	if BEATS.has(str(d.get("beat", ""))):
		out.append(str((BEATS[str(d["beat"])] as Array)[0]))
	if d.has("decisions"):
		out.append("%d decisions" % int(d["decisions"]))
	if d.has("expert_s"):
		out.append("about " + clock(float(d["expert_s"])) + " if you know it")
	return ", ".join(out)


func beat_help(json: Dictionary) -> String:
	var b: String = str(design(json).get("beat", ""))
	return "%s: %s" % BEATS[b] if BEATS.has(b) else ""


static func clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func rewards(r: RefCounted) -> String:
	## What the room really gives, read from what is placed in it.
	var out: Array[String] = []
	for it_v: Variant in r.call("list", "interactables"):
		var it: Dictionary = it_v as Dictionary
		var pr: Dictionary = it["props"] as Dictionary if it.get("props") is Dictionary else {}
		match str(it.get("kind", "")):
			"chest":
				var rk: String = str(pr.get("reward", pr.get("reward_kind", "shards")))
				out.append("%d shards" % int(pr.get("amount", 0)) if rk == "shards" else rk.replace("_", " "))
			"wick_key", "key": out.append("a key" if str(pr.get("key_kind", "")) != "keepers_flame" else "the Keeper's Flame")
			"keepers_flame": out.append("the Keeper's Flame")
			"moth": out.append("a moth")
			"pane_pickup": out.append("a glass pane")
			"shrine": out.append("a new move")
			"great_lamp": out.append("the Great Lamp")
			"waystone": out.append("a waystone")
			"quest_item": out.append("a quest item")
	for e_v: Variant in r.call("list", "enemies"):
		if ed.catalog.is_boss(str((e_v as Dictionary).get("kind", ""))):
			out.append("beating %s" % ed.catalog.nice("enemies", str((e_v as Dictionary)["kind"])))
	return ", ".join(PackedStringArray(out))


# ---- The intended way through ----

func steps(r: RefCounted) -> Dictionary:
	## {path: [points Wick walks], steps: [{n, text, pos, from, lost}]}. Follows things you move; flags things you removed.
	var json: Dictionary = r.get("json")
	var d: Dictionary = design(json)
	var was: Dictionary = r.get("first_ids")
	var st: Dictionary = d["start"] as Dictionary if d.get("start") is Dictionary else {}
	var cur: Vector2 = Io.vec(st.get("spawn", json.get("spawn", [0, 0])))
	var path: Array[Vector2] = [cur]
	var out: Array[Dictionary] = []
	var sol: Array = d["solution"] as Array if d.get("solution") is Array else []
	for op_v: Variant in sol:
		if not (op_v is Dictionary):
			continue
		var op: Dictionary = op_v as Dictionary
		var name: String = str(op.get("op", ""))
		var tgt: Variant = op.get("target", op.get("exit", op.get("at", null)))
		var p: Vector2 = _find(r, tgt, cur)
		var lost: bool = tgt is String and was.has(str(tgt)) and (r.call("find_id", str(tgt)) as Dictionary).is_empty()
		var what: String = _what(r, tgt)
		var text: String = ""
		if op.get("from") is Array:
			cur = Io.vec(op["from"])
			path.append(cur)
		var from: Vector2 = cur
		match name:
			"goto":
				cur = _find(r, op.get("to"), cur)
				path.append(cur)
				continue
			"interact":
				text = _use(what)
				cur = p
				path.append(p)
			"shoot": text = "Shoot %s" % what
			"beam": text = "Charge the beam at %s" % what
			"throw": text = "Throw the lantern at %s" % what
			"ring": text = "Ring %s" % what
			"rotate":
				text = "Turn %s" % what
				cur = p
				path.append(p)
			"push":
				text = "Push %s here" % what
				var to: Vector2 = Io.vec(op.get("to", [p.x, p.y]))
				path.append(p)
				path.append(to)
				from = p
				cur = to
				p = to
			"carry":
				if str(op.get("action", "")) == "pickup":
					text = "Pick up %s" % what
					path.append(p)
					cur = p
				else:
					p = _find(r, op.get("to"), cur)
					text = "Put it down here"
					path.append(p)
					cur = p
			"glide", "dismount":
				p = _find(r, op.get("to"), cur)
				text = "Glide across" if name == "glide" else "Step off"
				path.append(p)
				cur = p
			"stand_on":
				text = "Stand on %s" % what
				path.append(p)
				cur = p
			"mount":
				text = "Ride %s" % what
				path.append(p)
				cur = p
			"dash":
				text = "Dash"
				p = cur
			"zip":
				text = "Zip to the lantern"
				p = cur
			"recall":
				text = "Call the lantern back"
				p = cur
			"lens":
				text = "Use the True Lens"
				p = cur
			"sunflare":
				text = "Burst the Sunflare"
				p = cur
			"clear":
				text = "Beat the enemies"
				p = _crowd(r, str(op.get("zone", "")), cur)
			"wait_phase": text = "Wait for the right moment at %s" % what
			"expect_exit":
				text = "Leave to %s" % _exit_name(r, str(tgt))
				path.append(p)
				cur = p
			_:
				continue
		if not out.is_empty() and str(out[-1]["base"]) == text and (out[-1]["pos"] as Vector2).distance_to(p) < 3.0:
			out[-1]["times"] = int(out[-1]["times"]) + 1
			out[-1]["text"] = "%s, %d times" % [text, int(out[-1]["times"])]
			continue
		out.append({"n": out.size() + 1, "text": text, "base": text, "times": 1, "pos": p, "from": from, "lost": lost})
	return {"path": path, "steps": out}


func cached(r: RefCounted) -> Dictionary:
	var sig: Dictionary = {"key": r.call("key"), "v": r.get("version")}
	if sig != _steps_for:
		_steps_for = sig
		_steps = steps(r)
	return _steps


func _find(r: RefCounted, v: Variant, fallback: Vector2) -> Vector2:
	if v is Array:
		return Io.vec(v, fallback)
	if v is String:
		for l: String in ["interactables", "enemies", "exits"]:
			for it_v: Variant in r.call("list", l):
				var it: Dictionary = it_v as Dictionary
				if str(it.get("id", "")) == str(v):
					return Io.vec(it["pos"]) if it.has("pos") else LxMapFormat.to_rect2(it.get("rect", [])).get_center()
	return fallback


func _what(r: RefCounted, v: Variant) -> String:
	if v is String:
		for l: String in ["interactables", "enemies"]:
			for it_v: Variant in r.call("list", l):
				if str((it_v as Dictionary).get("id", "")) == str(v):
					return "the " + str(ed.catalog.name_of(l, it_v as Dictionary))
		return "the " + str(v).get_slice("_", 0)
	return "this spot"


static func _use(what: String) -> String:
	var w: String = what.to_lower()
	if w.contains("lore"): return "Read %s" % what
	if w.contains("chest"): return "Open %s" % what
	if w.contains("key") or w.contains("flame") or w.contains("moth") or w.contains("pane") or w.contains("pickup"): return "Take %s" % what
	if w.contains("waystone") or w.contains("lamp") or w.contains("beacon") or w.contains("brazier"): return "Light %s" % what
	return "Use %s" % what


func _exit_name(r: RefCounted, id: String) -> String:
	for ex_v: Variant in r.call("list", "exits"):
		if str((ex_v as Dictionary).get("id", "")) == id:
			return ed.room_title_of(ex_v as Dictionary)
	return "the next room"


func _crowd(r: RefCounted, zone: String, fallback: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	var n: int = 0
	for e_v: Variant in r.call("list", "enemies"):
		var e: Dictionary = e_v as Dictionary
		if zone.is_empty() or str(e.get("zone", "")) == zone:
			sum += Io.vec(e.get("pos", [0, 0]))
			n += 1
	return sum / float(n) if n > 0 else fallback
