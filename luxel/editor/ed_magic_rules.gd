extends RefCounted
## Turns the model's operations into room edits, and refuses the ones that would leave the box, break the room or delete something
## the story needs. Never trusts the answer: unknown kinds, tiles and references are skipped and reported.

const Io := preload("res://luxel/editor/ed_io.gd")

const WHAT: Dictionary = {"interactables": "object", "enemies": "enemy", "scenery": "scenery", "decor": "floor_art"}
const LISTS: Dictionary = {"object": "interactables", "enemy": "enemies", "scenery": "scenery", "floor_art": "decor"}
const PROTECTED: Array[String] = ["shrine", "great_lamp", "keepers_flame", "wick_key", "key", "waystone", "quest_item", "pane_pickup", "moth", "beacon", "lantern_pickup", "npc", "hub_npc", "obsidian_seal", "great_belfry_brazier"]
const OVER_GAPS: Array[String] = ["door", "phantom_platform", "lantern_hook", "tide_raft", "star_node", "moving_platform", "falling_bell_platform", "updraft_vent", "wind_zone", "stair_lift_pad", "silk_loom_spool", "tide_gate", "vehicle_skiff", "mooring_post", "clock_hand", "rail", "rotor", "gravity_well", "polarity_well"]
const BLOCKED: Array[String] = ["wall", "glass", "mirror", "grate", "rail", "foliage", "void"]
const GAPS: Array[String] = ["pit", "water", "tide", "void", "phantom"]


static func ref_of(l: String, it: Dictionary, i: int) -> String:
	return str(it.get("id", "")) if l in ["interactables", "enemies"] else ("s%d" % i if l == "scenery" else "f%d" % i)


static func palette(catalog: RefCounted, isl: int, json: Dictionary) -> Dictionary:
	var objects: Array = []
	for tab: String in ["light", "puzzle", "door", "hazard", "travel", "reward", "story"]:
		for e: Dictionary in catalog.call("entries", tab, isl, json, false, ""):
			var tune: Dictionary = {}
			var sch: Dictionary = catalog.call("prop_schema", str(e["kind"]))
			for k: String in sch.keys():
				var s: Dictionary = sch[k] as Dictionary
				tune[k] = s["options"] if s.has("options") else str(s.get("type", ""))
			objects.append({"kind": e["kind"], "variant": e.get("variant", ""), "name": e["name"], "blurb": e["blurb"], "props": catalog.call("entry_props", e), "tune": tune})
	var enemies: Array = []
	for e2: Dictionary in catalog.call("entries", "enemies", isl, json, false, ""):
		enemies.append({"kind": e2["kind"], "name": e2["name"], "blurb": e2["blurb"]})
	var bosses: Array = []
	for e3: Dictionary in catalog.call("entries", "bosses", isl, json, false, ""):
		bosses.append(e3["kind"])
	var sheets: Dictionary = {}
	for e4: Dictionary in catalog.call("entries", "scenery", isl, json, false, ""):
		var sh: LxSpriteSheet = LxSpriteSheet.load_sheet("res://luxel/art/props/%s.json" % str(e4["sheet"]))
		var rects: Variant = (sh.props[str(e4["kind"])] as Dictionary).get("rects", []) if sh != null else []
		var src: Rect2 = LxSpriteSheet._to_rect2((rects as Array)[0]) if rects is Array and not (rects as Array).is_empty() else Rect2(0, 0, 16, 16)
		var d: Dictionary = sheets.get_or_add(str(e4["sheet"]), {"sheet": e4["sheet"], "set": e4["blurb"], "props": []}) as Dictionary
		(d["props"] as Array).append({"prop": e4["kind"], "w": int(src.size.x), "h": int(src.size.y)})
	var art: Array = []
	for d2: Dictionary in catalog.get("DECOR"):
		art.append(d2["id"])
	return {"objects": objects, "enemies": enemies, "bosses": bosses, "scenery": sheets.values(), "floor_art": art}


# ---- Applying ----

static func apply(ed: Node, area: Rect2i, ops: Array) -> Dictionary:
	## Edits ed.room in place (the caller holds begin/commit). Returns {done, paint, rects, skipped, problems}.
	var room: Object = ed.room
	var ts: float = float(room.ts)
	var px := Rect2(Vector2(area.position) * ts, Vector2(area.size) * ts)
	var before: Dictionary = reach(room)
	var skipped := PackedStringArray()
	var rects: Array = []
	var done: int = 0
	var paint: bool = false
	var names: Dictionary = {}  # temporary id -> real id
	var dead: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	# Scenery and floor art are addressed by position in the list, so remember them before the list changes.
	var by_ref: Dictionary = {}
	for l: String in ["scenery", "decor"]:
		var a: Array = room.list(l)
		for i: int in range(a.size()):
			by_ref[ref_of(l, a[i] as Dictionary, i)] = {"list": l, "item": a[i]}
	for op_v: Variant in ops:
		if not (op_v is Dictionary):
			continue
		var op: Dictionary = op_v as Dictionary
		match str(op.get("op", "")):
			"tiles":
				var n: int = _tiles(room, area, op, rects)
				done += 1 if n > 0 else 0
				paint = paint or n > 0
			"add":
				var made: Dictionary = _add(ed, px, op, names, skipped)
				if not made.is_empty():
					done += 1
					paint = paint or str(made["list"]) == "decor"
					fresh.append(made)
			"move", "delete", "set":
				var hit: Dictionary = _resolve(room, by_ref, names, str(op.get("id", "")))
				if hit.is_empty():
					skipped.append("Skipped a change to something that isn't in the room.")
					continue
				var it: Dictionary = hit["item"] as Dictionary
				var kind: String = str(it.get("kind", it.get("prop", "")))
				var at: Vector2 = _at(it)
				if not px.grow(10.0).has_point(at):
					skipped.append("Left %s alone: it is outside the box." % ed.catalog.name_of(str(hit["list"]), it))
					continue
				if str(op["op"]) == "set":
					if _apply_props(ed, hit, op):
						done += 1
						rects.append(_rect(ed, it))
				elif str(op["op"]) == "move":
					var to: Vector2 = _snap(Vector2(float(op.get("x", at.x)), float(op.get("y", at.y))), str(hit["list"]), px)
					room.shift_item(_ref(room, hit), to - at)
					done += 1
					paint = paint or str(hit["list"]) == "decor"
					fresh.append({"list": hit["list"], "item": it, "moved": true})
				elif PROTECTED.has(kind) or ed.catalog.is_boss(kind) or _holds_exit(room, str(it.get("id", ""))):
					skipped.append("Kept %s: the game needs it. Delete it by hand if you mean it." % ed.catalog.name_of(str(hit["list"]), it))
				else:
					dead.append(hit)
					rects.append(_rect(ed, it))
					done += 1
					paint = paint or str(hit["list"]) == "decor"
			"wire", "unwire":
				var a2: Dictionary = _resolve(room, by_ref, names, str(op.get("id", op.get("from", ""))))
				var b2: Dictionary = _resolve(room, by_ref, names, str(op.get("to", "")))
				if a2.is_empty() or b2.is_empty() or str(a2["list"]) != "interactables" or str(b2["list"]) != "interactables":
					skipped.append("Skipped a wire between things that can't be wired.")
					continue
				var f: int = int(_ref(room, a2)["i"])
				var t: int = int(_ref(room, b2)["i"])
				if f == t or room.has_wire(f, t) == (str(op["op"]) == "wire"):
					continue
				if str(op["op"]) == "wire":
					room.add_wire(f, t)
				else:
					room.remove_wire(f, t)
				done += 1
	for d: Dictionary in dead:
		room.list(str(d["list"])).erase(d["item"])
		if (d["item"] as Dictionary).has("id"):
			room.drop_references(str((d["item"] as Dictionary)["id"]))
	for m: Dictionary in fresh:
		rects.append(_rect(ed, m["item"] as Dictionary))
	return {"done": done, "paint": paint, "rects": rects, "skipped": _unique(skipped), "problems": _problems(ed, before, fresh)}


static func _tiles(room: Object, area: Rect2i, op: Dictionary, rects: Array) -> int:
	var tile: String = str(op.get("tile", ""))
	if not LxMapFormat.DEFAULT_LEGEND.values().has(tile) or not (op.get("rects") is Array):
		return 0
	var n: int = 0
	for r_v: Variant in (op["rects"] as Array):
		if not (r_v is Array) or (r_v as Array).size() < 4:
			continue
		var q: Array = r_v as Array
		var r: Rect2i = Rect2i(int(q[0]), int(q[1]), maxi(1, int(q[2])), maxi(1, int(q[3]))).intersection(area)
		var hit: int = 0
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				hit += 1 if room.set_tile(x, y, tile) else 0
		if hit > 0:
			rects.append(Rect2(Vector2(r.position) * room.ts, Vector2(r.size) * room.ts))
		n += hit
	return n


static func _add(ed: Node, px: Rect2, op: Dictionary, names: Dictionary, skipped: PackedStringArray) -> Dictionary:
	var l: String = str(LISTS.get(str(op.get("what", "object")), ""))
	var kind: String = str(op.get("kind", ""))
	var e: Dictionary = {"type": l, "kind": kind}
	match l:
		"interactables":
			var cat: String = str(ed.catalog.info("interactables", kind).get("cat", "special"))
			if not ed.catalog.objects.has(kind) or cat == "special":
				skipped.append("Skipped \"%s\": the game has no such object to place." % kind)
				return {}
			if kind == "door":
				var v: String = str(op.get("variant", ""))
				e["variant"] = v if _has(ed.catalog.DOORS, "v", v) else "switch_door"
		"enemies":
			if not ed.catalog.enemies.has(kind):
				skipped.append("Skipped \"%s\": no such enemy." % kind)
				return {}
		"scenery":
			var sh: LxSpriteSheet = LxSpriteSheet.load_sheet("res://luxel/art/props/%s.json" % str(op.get("sheet", "")).get_file())
			if sh == null or not sh.props.has(kind):
				skipped.append("Skipped \"%s\": no such prop." % kind)
				return {}
			e["sheet"] = str(op["sheet"])
		"decor":
			if not _has(ed.catalog.DECOR, "id", kind):
				skipped.append("Skipped \"%s\": no such floor art." % kind)
				return {}
		_:
			return {}
	var pos: Vector2 = _snap(Vector2(float(op.get("x", px.get_center().x)), float(op.get("y", px.get_center().y))), l, px)
	var spec: Dictionary = ed.catalog.spec_for(e, "", pos)
	if kind == "moth" and l == "interactables":
		var mid: String = ed.catalog.next_moth(int(ed.room.island))
		if mid.is_empty():
			skipped.append("No moth added: all of this island's moths are placed.")
			return {}
		ed.catalog.used_moths[mid] = true
		spec["props"] = {"id": mid}
	if l in ["interactables", "enemies"]:
		spec["id"] = ed.room.new_id(kind)
		var tmp: String = str(op.get("id", ""))
		if not tmp.is_empty():
			names[tmp] = spec["id"]
	if l == "scenery" and bool(op.get("flip", false)):
		spec["flip_x"] = true
	ed.room.own_list(l).append(spec)
	ed._fill_zone(l, kind, spec, pos, false)
	var made: Dictionary = {"list": l, "item": spec}
	if op.get("props") is Dictionary and kind != "moth":
		_apply_props(ed, made, op)
	return made


static func _apply_props(ed: Node, hit: Dictionary, op: Dictionary) -> bool:
	var want: Dictionary = op["props"] as Dictionary if op.get("props") is Dictionary else {}
	var it: Dictionary = hit["item"] as Dictionary
	var ok: bool = false
	for k: String in want.keys():
		match str(hit["list"]):
			"interactables":
				var kind: String = str(it.get("kind", ""))
				var seen: Dictionary = (ed.catalog.objects.get(kind, {}) as Dictionary).get("props", {}) as Dictionary
				var sch: Dictionary = ed.catalog.prop_schema(kind)
				if k in ["id", "zone", "target_id", "target_ids", "inputs", "dungeon_id"] or k.contains("flag") or k.begins_with("requires_") or not (seen.has(k) or sch.has(k)):
					continue
				if (sch.get(k, {}) as Dictionary).has("options") and not _option_ok((sch[k] as Dictionary)["options"] as Array, want[k]):
					continue
				ed.room.props(it)[k] = _whole(want[k])
				ok = true
			"enemies":
				if k in ["leash", "route", "perches"]:
					it[k] = _whole(want[k])
					ok = true
			"scenery":
				if k in ["flip", "flip_x"]:
					it["flip_x"] = bool(want[k])
					ok = true
				elif k == "layer" and str(want[k]) in ["sort", "ground", "overhead"]:
					it["layer"] = want[k]
					ok = true
			"decor":
				if k in ["radius", "size", "rect", "style", "tint", "shear", "glow"]:
					it[k] = _whole(want[k])
					ok = true
	return ok


static func _option_ok(opts: Array, v: Variant) -> bool:
	for o: Variant in opts:
		if str(o) == str(v) or ((o is float or o is int) and (v is float or v is int) and is_equal_approx(float(o), float(v))):
			return true
	return false


static func _whole(v: Variant) -> Variant:
	## The answer arrives as JSON floats; rooms store whole numbers as ints.
	if v is float:
		return Io.num(v as float)
	if v is Array:
		var out: Array = []
		for x: Variant in (v as Array):
			out.append(_whole(x))
		return out
	return v


static func _resolve(room: Object, by_ref: Dictionary, names: Dictionary, id: String) -> Dictionary:
	var real: String = str(names.get(id, id)).trim_prefix("`").trim_suffix("`")
	if by_ref.has(real):
		return by_ref[real] as Dictionary
	var ref: Dictionary = room.find_id(real)
	return {"list": ref["list"], "item": room.item(ref)} if not ref.is_empty() else {}


static func _ref(room: Object, hit: Dictionary) -> Dictionary:
	var a: Array = room.list(str(hit["list"]))
	for i: int in range(a.size()):
		if is_same(a[i], hit["item"]):
			return {"list": hit["list"], "i": i}
	return {"list": hit["list"], "i": -1}


static func _at(it: Dictionary) -> Vector2:
	return Io.vec(it["pos"]) if it.has("pos") else LxMapFormat.to_rect2(it.get("rect", [0, 0, 0, 0])).get_center()


static func _snap(p: Vector2, l: String, px: Rect2) -> Vector2:
	var st: float = 4.0 if l in ["scenery", "decor"] else 8.0
	var lo: Vector2 = (px.position / st).ceil() * st
	var hi: Vector2 = ((px.end - Vector2.ONE) / st).floor() * st
	return ((p / st).round() * st).clamp(lo, hi.max(lo))


static func _rect(ed: Node, it: Dictionary) -> Rect2:
	for l: String in ["interactables", "enemies", "scenery", "decor"]:
		var a: Array = ed.room.list(l)
		for i: int in range(a.size()):
			if is_same(a[i], it):
				return ed.canvas.rect_of({"list": l, "i": i})
	return Rect2(_at(it) - Vector2(8, 8), Vector2(16, 16))


static func _has(defs: Array, k: String, v: String) -> bool:
	for d: Dictionary in defs:
		if str(d[k]) == v:
			return true
	return false


static func _holds_exit(room: Object, id: String) -> bool:
	for ex: Dictionary in room.list("exits"):
		if not id.is_empty() and str(ex.get("locked_door_id", "")) == id:
			return true
	return false


static func _unique(a: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for s: String in a:
		if not out.has(s):
			out.append(s)
	return out


# ---- Checking the result ----

static func reach(room: Object) -> Dictionary:
	## Tiles the player could get to with every move: walls stop them, gaps don't.
	var start: Vector2 = Io.vec(room.json.get("spawn", [room.px_size().x * 0.5, room.px_size().y * 0.5]))
	var c := Vector2i((start / float(room.ts)).floor())
	var seen: Dictionary = {}
	var todo: Array[Vector2i] = [c]
	seen[c] = true
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if seen.has(q) or q.x < 0 or q.y < 0 or q.x >= room.width or q.y >= room.height or BLOCKED.has(room.tile(q.x, q.y)):
				continue
			seen[q] = true
			todo.append(q)
	return seen


static func _touch(seen: Dictionary, r: Rect2, ts: float) -> bool:
	var a := Vector2i((r.position / ts).floor()) - Vector2i.ONE
	var b := Vector2i((r.end / ts).floor()) + Vector2i.ONE
	for y: int in range(a.y, b.y + 1):
		for x: int in range(a.x, b.x + 1):
			if seen.has(Vector2i(x, y)):
				return true
	return false


static func _problems(ed: Node, before: Dictionary, fresh: Array[Dictionary]) -> PackedStringArray:
	var room: Object = ed.room
	var ts: float = float(room.ts)
	var now: Dictionary = reach(room)
	var out := PackedStringArray()
	for ex: Dictionary in room.list("exits"):
		var r: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		if _touch(before, r, ts) and not _touch(now, r, ts):
			out.append("The exit to %s can't be reached any more." % ed.room_title_of(ex))
	for it: Dictionary in room.list("interactables"):
		var p: Vector2 = Io.vec(it.get("pos", [0, 0]))
		var box := Rect2(p, Vector2.ZERO)
		if not str(it.get("kind", "")) in ["road_lamp", "lore_stone"] and _touch(before, box, ts) and not _touch(now, box, ts):
			out.append("%s at (%d, %d) is walled off." % [ed.catalog.name_of("interactables", it), int(p.x), int(p.y)])
	for m: Dictionary in fresh:
		var it2: Dictionary = m["item"] as Dictionary
		var l: String = str(m["list"])
		var kind: String = str(it2.get("kind", it2.get("prop", "")))
		var p2: Vector2 = _at(it2)
		var under: String = room.tile(floori(p2.x / ts), floori((p2.y - (2.0 if l == "scenery" else 0.0)) / ts))
		var label: String = "%s at (%d, %d)" % [ed.catalog.name_of(l, it2), int(p2.x), int(p2.y)]
		if l == "interactables" and not OVER_GAPS.has(kind):
			if GAPS.has(under):
				out.append("%s stands on %s." % [label, under])
			elif BLOCKED.has(under) and not str(ed.catalog.info("interactables", kind).get("cat", "")) in ["door", "puzzle"]:
				out.append("%s is inside a %s." % [label, under])
		elif l == "enemies" and BLOCKED.has(under):
			out.append("%s is inside a %s." % [label, under])
		elif l == "scenery" and under in ["pit", "void"] and str(it2.get("layer", "sort")) != "overhead":
			out.append("%s floats over a %s." % [label, under])
		for ex2: Dictionary in room.list("exits"):
			if l in ["interactables", "scenery"] and kind != "door" and str(it2.get("layer", "sort")) == "sort" and LxMapFormat.to_rect2(ex2.get("rect", [])).has_point(p2):
				out.append("%s stands in an exit." % label)
	return out
