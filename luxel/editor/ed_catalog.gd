extends RefCounted
## Everything the editor can place. Read from the rooms themselves (what exists, typical settings) plus
## catalog_text.json (names, one-line descriptions, which settings to show).

const Io := preload("res://luxel/editor/ed_io.gd")
const TEXT_PATH: String = "res://luxel/editor/catalog_text.json"

const TILES: Array[Dictionary] = [
	{"id": "ground", "name": "Floor", "blurb": "Walkable ground."},
	{"id": "path", "name": "Path", "blurb": "Walkable, painted as a path."},
	{"id": "wall", "name": "Wall", "blurb": "Solid. Blocks walking, shots and light."},
	{"id": "water", "name": "Water", "blurb": "Can't be walked on."},
	{"id": "pit", "name": "Pit", "blurb": "Wick falls. Dash, zip or glide over it."},
	{"id": "void", "name": "Void", "blurb": "Nothing: the edge of the world."},
	{"id": "bridge", "name": "Bridge", "blurb": "Walkable planks."},
	{"id": "phantom", "name": "Phantom floor", "blurb": "Only solid under the True Lens."},
	{"id": "bramble", "name": "Bramble", "blurb": "Blocks the way until burned."},
	{"id": "cracked", "name": "Cracked wall", "blurb": "Breaks to a strong hit."},
	{"id": "tide", "name": "Tide", "blurb": "Water that can drain."},
	{"id": "glass", "name": "Glass", "blurb": "Solid, pretty, blocks shots."},
	{"id": "mirror", "name": "Mirror wall", "blurb": "Solid wall of mirror."},
	{"id": "carpet", "name": "Carpet", "blurb": "Walkable carpet."},
	{"id": "stairs", "name": "Stairs", "blurb": "Walkable stairs."},
	{"id": "grate", "name": "Grate", "blurb": "Blocks walking, light passes."},
	{"id": "rail", "name": "Rail", "blurb": "Low railing: blocks walking, not sight."},
	{"id": "foliage", "name": "Hedge", "blurb": "Blocks walking, not sight."},
]

const DECOR: Array[Dictionary] = [
	{"id": "circle", "name": "Floor circle", "spec": {"kind": "circle", "radius": 24, "style": "ritual"}},
	{"id": "inlay", "name": "Inlay", "spec": {"kind": "inlay", "rect": [0, 0, 64, 48]}},
	{"id": "rug", "name": "Rug", "spec": {"kind": "rug", "rect": [0, 0, 64, 32], "style": "hearth"}},
	{"id": "light_shaft", "name": "Light shaft", "spec": {"kind": "light_shaft", "size": [36, 48], "tint": "warm", "shear": -0.15}},
	{"id": "cracks", "name": "Cracks", "spec": {"kind": "cracks", "radius": 16, "glow": false}},
	{"id": "stain", "name": "Stain", "spec": {"kind": "stain", "radius": 16, "style": "moss"}},
	{"id": "grate", "name": "Floor grate", "spec": {"kind": "grate", "rect": [0, 0, 48, 32], "glow": false}},
	{"id": "compass", "name": "Compass", "spec": {"kind": "compass", "radius": 20}},
	{"id": "window_strip", "name": "Windows", "spec": {"kind": "window_strip", "x0": 0, "x1": 96, "y": 0, "style": "slag"}},
	{"id": "mural", "name": "Mural", "spec": {"kind": "mural", "radius": 24, "style": "moon"}},
]

const TABS: Array[Dictionary] = [
	{"id": "ground", "name": "GROUND"},
	{"id": "scenery", "name": "SCENERY"},
	{"id": "light", "name": "LIGHTS"},
	{"id": "puzzle", "name": "PUZZLE"},
	{"id": "door", "name": "DOORS"},
	{"id": "hazard", "name": "HAZARDS"},
	{"id": "travel", "name": "TRAVEL"},
	{"id": "reward", "name": "REWARDS"},
	{"id": "enemies", "name": "ENEMIES"},
	{"id": "bosses", "name": "BOSSES"},
	{"id": "story", "name": "STORY"},
	{"id": "decor", "name": "FLOOR ART"},
]

const DOORS: Array[Dictionary] = [
	{"v": "switch_door", "name": "Door", "blurb": "Opens when everything wired to it is on.", "size": [32, 16]},
	{"v": "switch_door_side", "name": "Side door", "blurb": "A door in a left or right wall. Opens when what is wired to it is on.", "size": [16, 32]},
	{"v": "bridge_platform", "name": "Bridge", "blurb": "Slides out over a pit or water when what is wired to it is on.", "size": [48, 32]},
	{"v": "combat_gate", "name": "Combat gate", "blurb": "Opens when the enemies here are beaten.", "size": [32, 16]},
	{"v": "ward_barrier", "name": "Ward barrier", "blurb": "A magic barrier that a story event removes.", "size": [32, 16]},
	{"v": "shortcut_door", "name": "Shortcut door", "blurb": "Opens from the far side and stays open.", "size": [32, 16]},
]

const SKIP_TEMPLATE: Array[String] = ["id", "zone", "string_id", "name_key", "quest", "bubbles", "flag", "inputs", "links", "linked_to", "rotors", "bells", "persist", "dungeon_id", "secret_id", "trial_id", "story_flag", "group", "ws_id"]
const KIND_DEFAULTS: Dictionary = {
	"door": {"door_kind": "switch_door", "size": [32, 16]},
	"chest": {"reward": "shards", "reward_kind": "shards", "amount": 25},
	"road_lamp": {"lit": true},
	"enemy": {},
}

var text: Dictionary = {}
var objects: Dictionary = {}  # kind -> {count, islands:{isl:true}, props:{k:{json:count}}}
var enemies: Dictionary = {}  # kind -> {count, islands}
var scenery: Dictionary = {}  # sheet -> {prop: {count, spec}}
var scenery_rooms: Dictionary = {}  # sheet -> {islands}
var used_moths: Dictionary = {}


func build() -> void:
	text = Io.read_json(TEXT_PATH, {}) as Dictionary
	for isl: int in range(0, 9):
		for fname: String in DirAccess.get_files_at("res://luxel/islands/%d" % isl):
			if fname.ends_with(".json") and not fname.begins_with("_"):
				var d: Variant = Io.read_json("res://luxel/islands/%d/%s" % [isl, fname], null)
				if d is Dictionary:
					_scan(isl, d as Dictionary)
	if Lx.packs != null:
		for k: String in Lx.packs.enemy_kinds():
			if not enemies.has(k):
				enemies[k] = {"count": 0, "islands": {}}


func _scan(isl: int, d: Dictionary) -> void:
	for it_v: Variant in _arr(d, "interactables"):
		var it: Dictionary = it_v as Dictionary
		var k: String = str(it.get("kind", ""))
		if k.is_empty():
			continue
		if not objects.has(k):
			objects[k] = {"count": 0, "islands": {}, "props": {}}
		var o: Dictionary = objects[k] as Dictionary
		o["count"] = int(o["count"]) + 1
		(o["islands"] as Dictionary)[isl] = true
		if it.get("props") is Dictionary:
			for pk: String in (it["props"] as Dictionary).keys():
				var vals: Dictionary = (o["props"] as Dictionary).get_or_add(pk, {}) as Dictionary
				var enc: String = var_to_str((it["props"] as Dictionary)[pk])
				vals[enc] = int(vals.get(enc, 0)) + 1
			if k == "moth":
				used_moths[str((it["props"] as Dictionary).get("id", (it["props"] as Dictionary).get("moth_id", "")))] = true
	for e_v: Variant in _arr(d, "enemies"):
		var ek: String = str((e_v as Dictionary).get("kind", ""))
		if not ek.is_empty():
			var e: Dictionary = enemies.get_or_add(ek, {"count": 0, "islands": {}}) as Dictionary
			e["count"] = int(e["count"]) + 1
			(e["islands"] as Dictionary)[isl] = true
	for s_v: Variant in _arr(d, "scenery"):
		var s: Dictionary = s_v as Dictionary
		var sheet: String = str(s.get("sheet", ""))
		var prop: String = str(s.get("prop", ""))
		if sheet.is_empty() or prop.is_empty():
			continue
		var set_d: Dictionary = scenery.get_or_add(sheet, {}) as Dictionary
		var pd: Dictionary = set_d.get_or_add(prop, {"count": 0, "layers": {}}) as Dictionary
		pd["count"] = int(pd["count"]) + 1
		var ly: String = str(s.get("layer", "sort"))
		(pd["layers"] as Dictionary)[ly] = int((pd["layers"] as Dictionary).get(ly, 0)) + 1
		(scenery_rooms.get_or_add(sheet, {}) as Dictionary)[isl] = true


static func _arr(d: Dictionary, k: String) -> Array:
	var out: Array = []
	if d.get(k) is Array:
		for v: Variant in (d[k] as Array):
			if v is Dictionary:
				out.append(v)
	return out


# ---- Text ----

func info(list_name: String, kind: String) -> Dictionary:
	var block: String = "objects" if list_name == "interactables" else list_name
	var d: Variant = (text.get(block, {}) as Dictionary).get(kind, null)
	if d == null and block == "enemies":
		d = (text.get("bosses", {}) as Dictionary).get(kind, null)
	return d as Dictionary if d is Dictionary else {}


func nice(list_name: String, kind: String) -> String:
	return str(info(list_name, kind).get("name", kind.replace("_", " ").capitalize()))


func blurb(list_name: String, kind: String) -> String:
	return str(info(list_name, kind).get("blurb", ""))


func sheet_name(sheet: String) -> String:
	return str((text.get("scenery", {}) as Dictionary).get(sheet, sheet.trim_prefix("theme_").replace("_", " ").capitalize()))


func is_boss(kind: String) -> bool:
	return (text.get("bosses", {}) as Dictionary).has(kind) or (Lx.packs != null and not Lx.packs.boss_meta(kind).is_empty())


func prop_schema(kind: String) -> Dictionary:
	var p: Variant = info("interactables", kind).get("props", {})
	return p as Dictionary if p is Dictionary else {}


func name_of(list_name: String, it: Dictionary) -> String:
	match list_name:
		"scenery": return str(it.get("prop", "")).replace("_", " ").capitalize()
		"decor": return "Floor art: " + str(it.get("kind", "")).replace("_", " ")
		"exits": return "Exit to " + str(it.get("to_region", "?"))
		_:
			if str(it.get("kind", "")) == "door" and it.get("props") is Dictionary:
				var dk: String = str((it["props"] as Dictionary).get("door_kind", (it["props"] as Dictionary).get("door_type", "")))
				for d: Dictionary in DOORS:
					if str(d["v"]) == dk:
						return str(d["name"])
			return nice(list_name, str(it.get("kind", "")))


# ---- Templates ----

func template(kind: String) -> Dictionary:
	## The settings most rooms use for this kind, without ids, flags and links.
	var out: Dictionary = {}
	var o: Dictionary = objects.get(kind, {}) as Dictionary
	var n: int = maxi(1, int(o.get("count", 1)))
	for k: String in (o.get("props", {}) as Dictionary).keys():
		if SKIP_TEMPLATE.has(k) or k.ends_with("_id") or k.ends_with("_ids") or k.ends_with("_key") or k.contains("flag") or k.begins_with("requires_") or k.begins_with("required_") or k.begins_with("on_"):
			continue
		var best: String = ""
		var best_n: int = 0
		var total: int = 0
		var vals: Dictionary = (o["props"] as Dictionary)[k] as Dictionary
		for enc: String in vals.keys():
			total += int(vals[enc])
			if int(vals[enc]) > best_n:
				best_n = int(vals[enc])
				best = enc
		if total * 10 >= n * 4 and not best.is_empty():
			out[k] = str_to_var(best)
	for k: String in (KIND_DEFAULTS.get(kind, {}) as Dictionary).keys():
		out[k] = (KIND_DEFAULTS[kind] as Dictionary)[k]
	return out


func prop_layer(sheet: String, prop: String) -> String:
	var best: String = "sort"
	var n: int = 0
	var pd: Dictionary = (scenery.get(sheet, {}) as Dictionary).get(prop, {}) as Dictionary
	for ly: String in (pd.get("layers", {}) as Dictionary).keys():
		if int((pd["layers"] as Dictionary)[ly]) > n:
			n = int((pd["layers"] as Dictionary)[ly])
			best = ly
	return best


# ---- Palette ----

func entries(tab: String, isl: int, room_json: Dictionary, everything: bool, query: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var q: String = query.strip_edges().to_lower()
	if not q.is_empty():
		for t: Dictionary in TABS:
			for e: Dictionary in entries(str(t["id"]), isl, room_json, true, ""):
				if str(e["name"]).to_lower().contains(q) or str(e["kind"]).to_lower().contains(q) or str(e.get("blurb", "")).to_lower().contains(q):
					out.append(e)
		return out
	match tab:
		"ground":
			for t: Dictionary in TILES:
				out.append({"type": "tile", "kind": t["id"], "name": t["name"], "blurb": t["blurb"]})
		"decor":
			for t: Dictionary in DECOR:
				out.append({"type": "decor", "kind": t["id"], "name": t["name"], "blurb": "Painted into the floor."})
		"scenery":
			out = _scenery_entries(isl, room_json, everything)
		"enemies", "bosses":
			for k: String in enemies.keys():
				if is_boss(k) != (tab == "bosses"):
					continue
				var e: Dictionary = enemies[k] as Dictionary
				if not everything and not (e["islands"] as Dictionary).has(isl):
					continue
				out.append({"type": "enemies", "kind": k, "name": nice("enemies", k), "blurb": blurb("enemies", k), "count": e["count"]})
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
		_:
			for k: String in objects.keys():
				var cat: String = str(info("interactables", k).get("cat", "special"))
				if cat != tab:
					continue
				var o: Dictionary = objects[k] as Dictionary
				var isls: Dictionary = o["islands"] as Dictionary
				if not everything and not isls.has(isl) and isls.size() < 3:
					continue
				if k == "door":
					for d: Dictionary in DOORS:
						out.append({"type": "interactables", "kind": "door", "variant": d["v"], "name": d["name"], "blurb": d["blurb"], "count": int(o["count"])})
					continue
				out.append({"type": "interactables", "kind": k, "name": nice("interactables", k), "blurb": blurb("interactables", k), "count": o["count"]})
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	return out


func _scenery_entries(isl: int, room_json: Dictionary, everything: bool) -> Array[Dictionary]:
	var sheets: Array[String] = []
	for s_v: Variant in _arr(room_json, "scenery"):
		var s: String = str((s_v as Dictionary).get("sheet", ""))
		if not s.is_empty() and not sheets.has(s):
			sheets.append(s)
	var theme_sheet: String = "theme_" + str(room_json.get("theme", ""))
	if FileAccess.file_exists("res://luxel/art/props/%s.json" % theme_sheet) and not sheets.has(theme_sheet):
		sheets.push_front(theme_sheet)
	var isl_sheet: String = "island%d_scenery" % isl
	if FileAccess.file_exists("res://luxel/art/props/%s.json" % isl_sheet) and not sheets.has(isl_sheet):
		sheets.append(isl_sheet)
	var rest: Array = scenery.keys()
	rest.sort()
	for s: String in rest:
		if not sheets.has(s) and (everything or (scenery_rooms.get(s, {}) as Dictionary).has(isl)):
			sheets.append(s)
	var out: Array[Dictionary] = []
	for s: String in sheets:
		var sh: LxSpriteSheet = LxSpriteSheet.load_sheet("res://luxel/art/props/%s.json" % s)
		if sh == null:
			continue
		for prop: String in sh.props.keys():
			out.append({"type": "scenery", "kind": prop, "sheet": s, "name": prop.replace("_", " ").capitalize(), "blurb": sheet_name(s)})
	return out


func spec_for(entry: Dictionary, id: String, pos: Vector2) -> Dictionary:
	## A brand-new room entry for a palette item.
	match str(entry["type"]):
		"scenery":
			return {"sheet": entry["sheet"], "prop": entry["kind"], "pos": Io.arr(pos), "layer": prop_layer(str(entry["sheet"]), str(entry["kind"])), "flip_x": false, "shadow": true, "phase": 0.0}
		"enemies":
			return {"id": id, "kind": entry["kind"], "pos": Io.arr(pos), "route": [], "perches": [], "zone": "", "leash": 110}
		"decor":
			var spec: Dictionary = {}
			for t: Dictionary in DECOR:
				if t["id"] == entry["kind"]:
					spec = (t["spec"] as Dictionary).duplicate(true)
			if spec.get("rect") is Array:
				var r: Array = spec["rect"] as Array
				spec["rect"] = [Io.num(pos.x - float(r[2]) * 0.5), Io.num(pos.y - float(r[3]) * 0.5), r[2], r[3]]
			elif spec.has("x0"):
				var w: float = float(spec["x1"]) - float(spec["x0"])
				spec["x0"] = Io.num(pos.x - w * 0.5)
				spec["x1"] = Io.num(pos.x + w * 0.5)
				spec["y"] = Io.num(pos.y)
			else:
				spec["pos"] = Io.arr(pos)
			return spec
		_:
			return {"id": id, "kind": entry["kind"], "pos": Io.arr(pos), "props": entry_props(entry)}


func entry_props(entry: Dictionary) -> Dictionary:
	var out: Dictionary = template(str(entry["kind"]))
	for d: Dictionary in DOORS:
		if entry.has("variant") and str(d["v"]) == str(entry["variant"]):
			out["door_kind"] = str(d["v"]).trim_suffix("_side")
			out["size"] = (d["size"] as Array).duplicate()
	return out


func next_moth(isl: int) -> String:
	if Lx.packs == null:
		return ""
	var ids: Array = Lx.packs.moths().keys()
	ids.sort()
	for m: String in ids:
		if m.begins_with("moth_%d_" % isl) and not used_moths.has(m):
			return m
	return ""
