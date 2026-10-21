## One Last Light enemy kind's art and numbers: art/cast/enemies/<id>/<id>.json (written by
## docs/art_concepts/lastlight/cast/enemies/<id>.py, copied by cast/export_godot.py) and its sheets.
## Loaded once per kind and shared by every enemy of that kind. Clips are built on first use and cached.
## A clip: {"anim", "dir", "loop", "size", "anchor", "frames", "ms", "total", "data" (frame_data),
## "tex" {layer: Texture2D}}.
## Layers whose name contains "shadow" use the kind's shadow_size / shadow_anchor; every other layer uses the
## animation's frame size and anchor (the feet).
extends RefCounted

const ROOT := "res://art/cast/enemies/"
const DIR_FALLBACK: Array[String] = ["front", "side", "any", "back"]

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


static func vec(v: Variant) -> Vector2:
	return Vector2.ZERO if v == null else Vector2(float(v[0]), float(v[1]))


func _build(anim: String, dir: String, look: String) -> Dictionary:
	var a: Dictionary = data["animations"][anim]
	var d: Dictionary = a["dirs"][dir]
	var src: Dictionary = d.get("sheets", d)
	if src.has(look):
		src = src[look]
	elif not src.has("body") and src.size() > 0 and src.values()[0] is Dictionary:
		src = src.values()[0] # an unknown look: the first one
	var tex := {}
	for layer: String in src:
		if src[layer] is String and str(src[layer]).ends_with(".png"):
			tex[layer] = load(ROOT + id + "/" + str(src[layer]))
	var ms := PackedFloat32Array()
	for fd: Dictionary in d["frame_data"]:
		ms.append(float(fd["ms"]))
	var total := 0.0
	for v in ms:
		total += v
	return {
		"anim": anim, "dir": dir, "loop": bool(a.get("loop", false)),
		"size": vec(a.get("frame", data["frame"])), "anchor": vec(a.get("anchor", data["anchor"])),
		"frames": int(d["frames"]), "ms": ms, "total": total, "data": d["frame_data"], "tex": tex}
