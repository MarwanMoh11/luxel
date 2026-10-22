## One Last Light enemy kind's art and numbers: art/cast/enemies/<id>/<id>.json (written by
## docs/art_concepts/lastlight/cast/enemies/<id>.py, copied by cast/export_godot.py) and its sheets.
## Loaded once per kind and shared by every enemy of that kind. Clips are built on first use and cached.
## A clip: {"anim", "dir", "loop", "size", "anchor", "frames", "ms", "total", "data" (frame_data),
## "tex" {layer: Texture2D}, "rimmed" {body/flash: the sheet over its rim, bake_rims.gd}, "centres" (the hit
## centre per frame, unmirrored), "unmirrored" (a front, back or any view), "eye_mids" (the middle of each frame's
## eye pixels, unanchored and INF where there are none, from eyes.json; empty without an eyes sheet)}. Clips are
## never changed once built.
## Layers whose name contains "shadow" use the kind's shadow_size / shadow_anchor; every other layer uses the
## animation's frame size and anchor (the feet).
extends RefCounted

const ROOT := "res://art/cast/enemies/"
const DIR_FALLBACK: Array[String] = ["front", "side", "any", "back"]
const UNMIRRORED: Array[String] = ["front", "back", "any"] # views never mirrored (enemy.gd UNMIRRORED)
const RIMMED := "rimmed/" # body and flash sheets over their rim, baked by bake_rims.gd
const EYES := "eyes.json" # each eyes sheet's eye pixels per frame, baked by bake_rims.gd (run.gd eye_pairs)

var id := ""
var data := {} ## the whole JSON
var behaviour := {} ## its "behaviour" block (the roster numbers)
var tells := {}
var hit_radius := 6.0
var body_radius := 6.0
var shadow_size := Vector2.ZERO
var shadow_anchor := Vector2.ZERO
var looks: Array[String] = [""] ## sheet sets ("" = the only one); the Snuffer has tin, soot and dent
var look_weights := {} ## look -> weight (rig.look_weights), empty when there is one look

var eye_mids := {} ## eyes sheet path -> PackedVector2Array: each frame's eye middle (eye_mid), from eyes.json
var _clips := {} # anim -> dir -> look -> clip


func _init(kind_id: String) -> void:
	id = kind_id
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + "/" + id + ".json"))
	behaviour = data.get("behaviour", {})
	tells = data.get("tells", {})
	hit_radius = float(data.get("hit_radius", 6))
	body_radius = float(data.get("body_radius", hit_radius))
	shadow_size = vec(data["shadow_frame"])
	shadow_anchor = vec(data["shadow_anchor"])
	if data.has("looks"):
		looks.assign(data["looks"])
	look_weights = data.get("rig", {}).get("look_weights", {})
	var eyes := ROOT + id + "/" + EYES
	if FileAccess.file_exists(eyes):
		var baked: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(eyes))
		for rel: String in baked:
			var mids := PackedVector2Array()
			for s: Array in baked[rel]:
				mids.append(eye_mid(Vector3i(int(s[0]), int(s[1]), int(s[2]))))
			eye_mids[rel] = mids


func has_anim(anim: String) -> bool:
	return data["animations"].has(anim)


## The directions an animation was drawn in.
func dirs(anim: String) -> Array:
	return data["animations"][anim]["dirs"].keys()


## The clip of `anim` seen from `dir` (falls back to front, side, any, back when that view wasn't drawn).
func clip(anim: String, dir: String, look := "") -> Dictionary:
	var by_dir: Dictionary = _clips.get(anim, {})
	var by_look: Dictionary = by_dir.get(dir, {})
	if by_look.has(look):
		return by_look[look]
	var a: Dictionary = data["animations"][anim]
	var d := dir
	if not a["dirs"].has(d):
		for f in DIR_FALLBACK:
			if a["dirs"].has(f):
				d = f
				break
		if not a["dirs"].has(d):
			d = a["dirs"].keys()[0]
	var c := _build(anim, d, look)
	by_look[look] = c
	by_dir[dir] = by_look
	_clips[anim] = by_dir
	return c


## A look picked by rig.look_weights (or the only one).
func pick_look() -> String:
	if look_weights.is_empty():
		return looks[0]
	return pick(look_weights)


## A key of {name: weight} picked at random by weight.
static func pick(weights: Dictionary) -> String:
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var r := randf() * total
	for k: String in weights:
		r -= float(weights[k])
		if r < 0.0:
			return k
	return weights.keys()[0]


## The baked rimmed copy of sheet `rel` of kind `id` (bake_rims.gd).
static func rimmed(kind_id: String, rel: String) -> String:
	return ROOT + kind_id + "/" + RIMMED + rel


static func vec(v: Variant) -> Vector2:
	return Vector2.ZERO if v == null else Vector2(float(v[0]), float(v[1]))


## Frame `f` of an eyes sheet `size` wide: its eye pixels (alpha over half) as their x sum, y sum and count.
static func eye_sum(img: Image, f: int, size: Vector2) -> Vector3i:
	var x0 := int(f * size.x)
	var s := Vector3i.ZERO
	for y in int(size.y):
		for x in int(size.x):
			if x0 + x < img.get_width() and y < img.get_height() and img.get_pixel(x0 + x, y).a > 0.5:
				s += Vector3i(x, y, 1)
	return s


## The middle of those pixels on the pixel centres, in the frame (not yet anchored); INF when there are none.
static func eye_mid(s: Vector3i) -> Vector2:
	return Vector2.INF if s.z == 0 else Vector2(s.x, s.y) / s.z + Vector2(0.5, 0.5)


func _build(anim: String, dir: String, look: String) -> Dictionary:
	var a: Dictionary = data["animations"][anim]
	var d: Dictionary = a["dirs"][dir]
	var src: Dictionary = d.get("sheets", d)
	if src.has(look):
		src = src[look]
	elif not src.has("body") and src.size() > 0 and src.values()[0] is Dictionary:
		src = src.values()[0] # an unknown look: the first one
	var tex := {}
	var rim := {}
	for layer: String in src:
		if src[layer] is String and str(src[layer]).ends_with(".png"):
			tex[layer] = load(ROOT + id + "/" + str(src[layer]))
			if (layer == "body" or layer == "flash") and ResourceLoader.exists(rimmed(id, src[layer])):
				rim[layer] = load(rimmed(id, src[layer]))
	var ms := PackedFloat32Array()
	var centres := PackedVector2Array()
	var fallback: Variant = data.get("centre", data.get("body_centre", [0, -hit_radius]))
	for fd: Dictionary in d["frame_data"]:
		ms.append(float(fd["ms"]))
		var c: Variant = fd.get("hit_centre", fd.get("centre"))
		centres.append(vec(fallback if c == null else c))
	var total := 0.0
	for v in ms:
		total += v
	return {
		"anim": anim, "dir": dir, "loop": bool(a.get("loop", false)),
		"size": vec(a.get("frame", data["frame"])), "anchor": vec(a.get("anchor", data["anchor"])),
		"frames": int(d["frames"]), "ms": ms, "total": total, "data": d["frame_data"], "tex": tex,
		"rimmed": rim, "centres": centres, "unmirrored": UNMIRRORED.has(dir),
		"eye_mids": eye_mids.get(str(src.get("eyes", "")), PackedVector2Array())}
