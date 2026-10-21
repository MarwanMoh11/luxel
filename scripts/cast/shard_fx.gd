extends RefCounted
## Shard sprites and the lantern's drink/full effects; draws only. Loads art/cast/shards/shards.json (written by
## docs/art_concepts/lastlight/cast/shards.py) and, for the star (size 3), the magpie's own star sheets.
## A shard draws its hover loop while `trail` is empty, and its pull streak (the row facing
## its travel, from the newest trail point to `pos`) plus the 1 px trail while pulled.

const ROOT := "res://art/cast/shards/"
const SIZE_NAMES: Array[String] = ["small", "medium", "large"]
const DIRS := 16
## The trail, newest first (20, 40, 60 ms ago): gold, apricot, coral (= core.SHADE[apricot]).
const TRAIL: Array[Color] = [Color("#ffd98c"), Color("#f5a96a"), Color("#e2725b")]
const FOLLOW_EMIT: Array[String] = ["drink", "drink_large", "lantern_full", "ready_pulse"]

var sheets := {} ## name -> {"tex", "size", "origin", "ms", "total", "loop", "frames"}
var bob_px := 1.0 ## from shards.json (shards.gd applies the bob)
var bob_hz := 6.0
## Added: ANIMATIONS sold holds every shard loop on frame 0 (the owner sets it; one-shots still play).
var still := false
var puffs: Array[Dictionary] = [] ## one-shots: {"s": sheet, "pos": Vector2, "ms": float}


## Loads the sheets and timings.
func setup() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "shards.json"))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("shard_fx: cannot read " + ROOT + "shards.json")
		return
	var d: Dictionary = data
	for name: String in d["sheets"]:
		var s: Dictionary = d["sheets"][name]
		sheets[name] = _sheet(load(ROOT + str(s["file"])), s["frame_size"], s["origin"], s["ms"], bool(s["loop"]))
	bob_px = float(d["hover"]["bob_px"])
	bob_hz = float(d["hover"]["bob_hz"])
	var st: Dictionary = d["star"]
	if ResourceLoader.exists(st["hover"]) and ResourceLoader.exists(st["pull"]):
		var hover_ms: Array = []
		hover_ms.resize(int(st["hover_frames"]))
		hover_ms.fill(83.33)
		sheets["star_hover"] = _sheet(load(st["hover"]), st["hover_frame"], st["hover_origin"], hover_ms, true)
		var pull_ms: Array = []
		pull_ms.resize(int(st["pull_frames"]))
		pull_ms.fill(float(st["pull_ms"]))
		sheets["star_pull"] = _sheet(load(st["pull"]), st["pull_frame"], st["pull_origin"], pull_ms, true)
	else: # without the magpie's art the star draws as a large shard
		sheets["star_hover"] = sheets["shard_large"]
		sheets["star_pull"] = sheets["pull_large"]


## Advances the one-shot effects.
func step(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for p: Dictionary in puffs:
		p["ms"] = float(p["ms"]) + dt * 1000.0
		if p["ms"] < sheets[p["s"]]["total"]:
			keep.append(p)
	puffs = keep


## Draws one shard (size 0 small, 1 medium, 2 large, 3 star) at `pos`, `t` s into its life, with its trail.
## `pos` is where the shard is drawn (shards.gd already adds the hover bob). `trail` = its positions 20, 40 and
## 60 ms ago while it is pulled (newest first), empty during the pop and the hover.
func draw_shard(ci: CanvasItem, pos: Vector2, size: int, t: float, trail: PackedVector2Array) -> void:
	if sheets.is_empty():
		return
	size = clampi(size, 0, 3)
	if not trail.is_empty():
		var dir := pos - trail[0]
		if dir.length_squared() > 0.0001:
			for i in mini(trail.size(), TRAIL.size()):
				ci.draw_rect(Rect2(trail[i].round(), Vector2.ONE), TRAIL[i])
			var row := posmod(roundi(dir.angle() / (TAU / DIRS)), DIRS)
			var s: Dictionary = sheets["star_pull" if size == 3 else "pull_" + SIZE_NAMES[size]]
			_blit(ci, s, 0 if still else _frame(s, t * 1000.0), row, pos)
			return
	var h: Dictionary = sheets["star_hover" if size == 3 else "shard_" + SIZE_NAMES[size]]
	_blit(ci, h, 0 if still else _frame(h, t * 1000.0), 0, pos)


## A shard pops out of a kill at `pos` (once per kill).
func pop(pos: Vector2) -> void:
	_puff("shard_pop", pos)


## The lantern at `pos` drinks a shard (`big` for large ones and the star). Follows the lantern (draw's emit).
func drink(pos: Vector2, big: bool) -> void:
	_puff("drink_large" if big else "drink", pos)


## The gauge is full: the lantern at `pos` flares (a starburst at the glass).
func full(pos: Vector2) -> void:
	_puff("lantern_full", pos)


## The lantern is nearly full (fill >= 0.8): the 1 px halo ring at `pos`, 80 ms; call it on every beat.
func ready_pulse(pos: Vector2) -> void:
	for p: Dictionary in puffs:
		if p["s"] == "ready_pulse":
			p["ms"] = 0.0
			return
	_puff("ready_pulse", pos)


## Added: a new shard merged into the waiting one at `pos` (queue cap): a small twinkle on it.
func merge(pos: Vector2) -> void:
	_puff("merge", pos)


## Draws the one-shot sprites; `emit` = the lantern glass (drink, full and the pulse follow it).
func draw(ci: CanvasItem, emit: Vector2) -> void:
	for p: Dictionary in puffs:
		var s: Dictionary = sheets[p["s"]]
		var f := _frame(s, float(p["ms"]))
		if f >= 0:
			_blit(ci, s, f, 0, emit if FOLLOW_EMIT.has(p["s"]) else p["pos"])


## Added: drops every one-shot (restart).
func reset() -> void:
	puffs.clear()


func _puff(name: String, pos: Vector2) -> void:
	if sheets.has(name):
		puffs.append({"s": name, "pos": pos, "ms": 0.0})


func _sheet(tex: Texture2D, fsize: Array, origin: Array, ms: Array, loop: bool) -> Dictionary:
	var m := PackedFloat32Array(ms)
	var total := 0.0
	for v: float in m:
		total += v
	return {"tex": tex, "size": Vector2(float(fsize[0]), float(fsize[1])),
		"origin": Vector2(float(origin[0]), float(origin[1])), "ms": m, "total": total, "loop": loop,
		"frames": m.size()}


## Frame index at `ms` into the sheet; loops wrap, one-shots return -1 once done.
func _frame(s: Dictionary, ms: float) -> int:
	if s["loop"]:
		ms = fmod(ms, float(s["total"]))
	var m: PackedFloat32Array = s["ms"]
	for i in m.size():
		if ms < m[i]:
			return i
		ms -= m[i]
	return 0 if s["loop"] else -1


func _blit(ci: CanvasItem, s: Dictionary, frame: int, row: int, at: Vector2) -> void:
	var size: Vector2 = s["size"]
	ci.draw_texture_rect_region(s["tex"], Rect2(at.round() - s["origin"], size),
		Rect2(Vector2(frame * size.x, row * size.y), size))
