## Wick, the lamplighter moth: picks and draws the hero's frames from art/cast/hero/hero.json
## (written by docs/art_concepts/lastlight/cast/hero.py, copied by cast/export_godot.py).
## The arena owns position and gameplay; this owns the animation. Times are in ms, positions are
## the feet anchor in arena pixels.
extends RefCounted

const ROOT := "res://art/cast/hero/"
const MOVING := 10.0 # px/s; slower counts as standing
const SIDE_BIAS := 1.2 # |vy| must beat |vx| by this much for the front or back view (diagonals use side)
const LAND_FRAME := 5 # hop: stand, crouch, take-off, air, fall, land
const CAST_ON: Array[String] = ["idle", "hop", "hurt"] # body anims the cast lantern overlay rides on
const HOLD_LAST: Array[String] = ["death", "ending"] # one-shots that keep their last frame

var anims := {} # name -> {"loop", "size", "anchor", "dirs": {dir -> clip}}
var rest_hand := {} # dir -> Vector2
var shadow_size := Vector2.ZERO
var shadow_anchor := Vector2.ZERO

var dir := "front"
var flip := false # facing left (side view only)
var tier := 0: # lantern glow tier 0..2; held while `cinematic` (the ending sets it before taking Wick)
	set(value):
		if not cinematic:
			tier = value
var still := false # ANIMATIONS sold: loops hold frame 0, one-shots show frame 0
var landed := false # true for the step a hop touches down
## The ending owns Wick: the run's step(), draw() and draw_shadow() calls do nothing, the ending uses the
## cine_* versions, and `still` (ANIMATIONS sold) no longer freezes him. reset() gives him back.
var cinematic := false

var _base := "idle"
var _base_t := 0.0
var _one := "" # a one-shot or menu pose playing over the base loop
var _one_t := 0.0
var _cast_t := -1.0 # ms into the cast overlay; < 0 = none
var _hop_frame := 0
var _range := {} # play_range: {"name", "frames": PackedInt32Array, "speed"} while that one-shot plays


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "hero.json"))
	var hands: Dictionary = data["rig"]["rest_hand"]
	for d: String in hands:
		rest_hand[d] = _vec(hands[d])
	shadow_size = _vec(data["shadow_frame"])
	shadow_anchor = _vec(data["shadow_anchor"])
	for name: String in data["animations"]:
		var a: Dictionary = data["animations"][name]
		var dirs := {}
		for d: String in a["dirs"]:
			dirs[d] = _clip(a["dirs"][d])
		anims[name] = {"loop": a["loop"], "size": _vec(a["frame"]), "anchor": _vec(a["anchor"]), "dirs": dirs}


func reset() -> void:
	dir = "front"
	flip = false
	_base = "idle"
	_base_t = 0.0
	_one = ""
	_cast_t = -1.0
	_range = {}
	cinematic = false


## One-shots: hurt, death, spawn, levelup (then levelup_hold), sell, ending.
func play(name: String) -> void:
	if name == "levelup" and _one == "levelup_hold":
		return
	_one = name
	_one_t = 0.0
	_range = {}


## Plays frames `from`..`to` of a one-shot (`to`..`from` with `reverse`) at `speed` x its timings, then holds
## the last one until the next play. The ending plays `ending` in halves and backwards this way.
func play_range(name: String, from: int, to: int, reverse := false, speed := 1.0) -> void:
	var frames := PackedInt32Array()
	for f in range(from, to + 1):
		frames.append(f)
	if reverse:
		frames.reverse()
	_one = name
	_one_t = 0.0
	_range = {"name": name, "frames": frames, "speed": maxf(speed, 0.01)}


## The frame the range is showing (-1 when no range plays).
func range_frame() -> int:
	return _range_frame(_one_t) if not _range.is_empty() and _one == _range["name"] else -1


## True once the range's last frame has had its time (or no range plays).
func range_done() -> bool:
	if range_frame() < 0:
		return true
	var ms: PackedFloat32Array = _clip_of(_range["name"])["ms"]
	var total := 0.0
	for f in _range["frames"]:
		total += ms[f] / float(_range["speed"])
	return _one_t >= total


func cast() -> void:
	_cast_t = 0.0


func playing(name: String) -> bool:
	return _one == name


func step(dt: float, vel: Vector2) -> void:
	if not cinematic:
		_advance(dt, vel)


## The ending's step: Wick stands still and only animates.
func cine_step(dt: float) -> void:
	_advance(dt, Vector2.ZERO)


func _advance(dt: float, vel: Vector2) -> void:
	var ms := dt * 1000.0
	var moving := vel.length() > MOVING
	if moving:
		if absf(vel.y) > absf(vel.x) * SIDE_BIAS:
			dir = "front" if vel.y > 0.0 else "back"
		else:
			dir = "side"
			flip = vel.x < 0.0
	var base := "hop" if moving else "idle"
	_base_t = _base_t + ms if base == _base else 0.0
	_base = base
	landed = false
	if _base == "hop" and _one == "":
		# The hop's own clock, not the shown frame: ANIMATIONS holds the pose, the river wake keeps landing.
		var f := _frame(_clip_of("hop"), _base_t, true, false)
		landed = f == LAND_FRAME and _hop_frame != LAND_FRAME
		_hop_frame = f
	if _one != "":
		_one_t += ms
		if not anims[_one]["loop"] and _one_t >= _clip_of(_one)["total"] and not HOLD_LAST.has(_one) \
				and _range.is_empty():
			_one = "levelup_hold" if _one == "levelup" else ""
			_one_t = 0.0
	if _cast_t >= 0.0:
		_cast_t += ms
		if _cast_t >= _clip_of("cast")["total"]:
			_cast_t = -1.0


## Centre of the lantern glass, relative to the feet: where shots and the flare start.
func emit() -> Vector2:
	var c := _current()
	var fd: Dictionary = c["clip"]["frames"][c["frame"]]
	var e: Variant = fd["emit"]
	var off := Vector2.ZERO
	var cf := _cast_frame(c)
	if cf >= 0:
		e = _clip_of("cast")["frames"][cf]["emit"]
		off = _vec(fd["hand"]) - rest_hand[_dir_of("cast")]
	var p := Vector2(0, -6) if e == null else _vec(e) + off
	return Vector2(-p.x, p.y) if _mirrored(c["name"]) else p


func lantern_behind() -> bool:
	var c := _current()
	var cf := _cast_frame(c)
	if cf >= 0:
		return _clip_of("cast")["frames"][cf]["lantern_behind"]
	return c["clip"]["frames"][c["frame"]]["lantern_behind"]


## The shadow mask, tinted `color`, under everything else. It always falls to the lower right.
func draw_shadow(ci: CanvasItem, feet: Vector2, color: Color) -> void:
	if not cinematic:
		cine_shadow(ci, feet, color)


## draw_shadow for the ending (draws while `cinematic`).
func cine_shadow(ci: CanvasItem, feet: Vector2, color: Color) -> void:
	var c := _current()
	var tex: Texture2D = c["clip"]["shadow"]
	if tex == null:
		return
	var src := Rect2(c["frame"] * shadow_size.x, 0, shadow_size.x, shadow_size.y)
	ci.draw_texture_rect_region(tex, Rect2((feet - shadow_anchor).round(), shadow_size), src, color)


## Body and lantern. `flash` swaps in the cream hit silhouette; `lantern_only` draws just the light.
func draw(ci: CanvasItem, feet: Vector2, flash := false, lantern_only := false) -> void:
	if not cinematic:
		cine_draw(ci, feet, flash, lantern_only)


## draw for the ending (draws while `cinematic`).
func cine_draw(ci: CanvasItem, feet: Vector2, flash := false, lantern_only := false) -> void:
	var c := _current()
	var clip: Dictionary = c["clip"]
	var f: int = c["frame"]
	var a: Dictionary = anims[c["name"]]
	var size: Vector2 = a["size"]
	var mirror := _mirrored(c["name"])
	var lantern: Texture2D = clip["lantern"][tier]
	var lsrc := Rect2(f * size.x, 0, size.x, size.y)
	var lfeet := feet
	var cf := _cast_frame(c)
	if cf >= 0:
		lantern = _clip_of("cast")["lantern"][tier]
		lsrc = Rect2(cf * size.x, 0, size.x, size.y)
		var off: Vector2 = _vec(clip["frames"][f]["hand"]) - rest_hand[_dir_of("cast")]
		lfeet += Vector2(-off.x if mirror else off.x, off.y)
	if lantern_only:
		_blit(ci, lantern, lsrc, lfeet, a, mirror)
		return
	var body: Texture2D = clip["flash"] if flash and clip["flash"] != null else clip["body"]
	var bsrc := Rect2(f * size.x, 0, size.x, size.y)
	if lantern_behind():
		_blit(ci, lantern, lsrc, lfeet, a, mirror)
		_blit(ci, body, bsrc, feet, a, mirror)
	else:
		_blit(ci, body, bsrc, feet, a, mirror)
		_blit(ci, lantern, lsrc, lfeet, a, mirror)


# --- internals ---------------------------------------------------------------------------------------------

func _current() -> Dictionary:
	var name := _one if _one != "" else _base
	var t := _one_t if _one != "" else _base_t
	var clip := _clip_of(name)
	var f := range_frame() if _one != "" else -1
	return {"name": name, "clip": clip, "frame": f if f >= 0 else _frame(clip, t, anims[name]["loop"])}


func _range_frame(t: float) -> int:
	var frames: PackedInt32Array = _range["frames"]
	var ms: PackedFloat32Array = _clip_of(_range["name"])["ms"]
	for f in frames:
		t -= ms[f] / float(_range["speed"])
		if t < 0.0:
			return f
	return frames[-1]


func _cast_frame(c: Dictionary) -> int:
	if _cast_t < 0.0 or not CAST_ON.has(c["name"]) or c["clip"]["frames"][c["frame"]]["hand"] == null:
		return -1
	return _frame(_clip_of("cast"), _cast_t, false)


## `hold`: ANIMATIONS (`still`) may freeze it; the landing check passes false.
func _frame(clip: Dictionary, t: float, loop: bool, hold := true) -> int:
	var ms: PackedFloat32Array = clip["ms"]
	var frozen := hold and still and not cinematic
	if loop:
		if frozen:
			return 0
		t = fmod(t, clip["total"])
	elif t >= clip["total"]:
		return ms.size() - 1
	elif frozen:
		return 0
	for i in ms.size():
		t -= ms[i]
		if t < 0.0:
			return i
	return ms.size() - 1


func _clip_of(name: String) -> Dictionary:
	return anims[name]["dirs"][_dir_of(name)]


func _dir_of(name: String) -> String:
	return dir if anims[name]["dirs"].has(dir) else "front"


func _mirrored(name: String) -> bool:
	return flip and _dir_of(name) == "side"


## Draws one frame with its anchor on `feet`; mirrored frames flip about the anchor line.
func _blit(ci: CanvasItem, tex: Texture2D, src: Rect2, feet: Vector2, a: Dictionary, mirror: bool) -> void:
	var size: Vector2 = a["size"]
	var anchor: Vector2 = a["anchor"]
	var left := feet.x - ((size.x - anchor.x) if mirror else anchor.x)
	var dest := Rect2(Vector2(left, feet.y - anchor.y).round(), size)
	if mirror:
		dest.size.x = -size.x
	ci.draw_texture_rect_region(tex, dest, src)


func _clip(src: Dictionary) -> Dictionary:
	var ms := PackedFloat32Array()
	for fd: Dictionary in src["frame_data"]:
		ms.append(fd["ms"])
	var total := 0.0
	for v in ms:
		total += v
	var lanterns: Array[Texture2D] = []
	for path: String in src["lantern"]:
		lanterns.append(load(ROOT + path))
	return {
		"frames": src["frame_data"], "ms": ms, "total": total, "lantern": lanterns,
		"body": _tex(src.get("body")), "flash": _tex(src.get("flash")), "shadow": _mask(src.get("shadow")),
	}


func _tex(path: Variant) -> Texture2D:
	return null if path == null else load(ROOT + str(path))


## The shadow sheet as a white mask, so drawing it with a modulate colour paints that colour.
func _mask(path: Variant) -> Texture2D:
	var tex := _tex(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _vec(v: Variant) -> Vector2:
	return Vector2(v[0], v[1])
