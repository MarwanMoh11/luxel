## Base of every Last Light enemy ("brain"): scripts/cast/enemies/<id>.gd extends this file and owns its kind's
## movement, states, drawing and reactions. The game (the Run, scripts/game/run/run.gd, with its enemy host
## enemies.gd) creates, steps, hits, kills and draws brains through the methods below; brains call back through
## `game` (the Run's brain API facade).
## Contract and examples: scripts/cast/enemies/README.md. The Snuffer (snuffer.gd) is the worked example.
## `pos` is the ground point under the creature (its feet anchor): shadow, y-sort and walking all use it.
extends RefCounted

const KIT := preload("res://scripts/cast/enemies/enemy_kit.gd")
const FLASH_TIME := 0.06 # seconds the flash layer replaces the body after a hit (weapons.json impact.enemy_flash)
const HIT_STOP: Array[float] = [0.05, 0.06, 0.07, 0.09] # seconds frozen per hit, by the light's damage tier
const SIDE_RATIO := 0.7 # |vx| > SIDE_RATIO * |vy| reads as the side view
const DIR_HOLD := 0.15 # seconds a new view must hold before the sprite turns to it
const UNMIRRORED: Array[String] = ["front", "back", "any"] # views never mirrored (the rim light stays west)
const SHADOW_ALTS: Array[String] = ["shadow_mirror", "shadow_left"] # unflipped shadows of a mirrored frame

var kind: int # index in director.gd KINDS (snuffer 0, owl 1, toad 2, sporecap 3, gloam 4, magpie 5)
var pos := Vector2.ZERO
var hp: int # x10 scale (director ROSTER `hp`, growing with the clock)
var push := Vector2.ZERO # knockback velocity, decays
var flash := 0.0
var game # the Run (scripts/game/run/run.gd): its brain API (README.md)
var kit: KIT # this kind's art and numbers, shared by every enemy of the kind
var id := "" # "snuffer", "owl", ...
var node: Node2D # this enemy's node in the island's y-sorted Sort layer (set and freed by the game)
var look := "" # sheet set (kit.looks)
var anim := ""
var anim_t := 0.0 # ms into `anim`
var clip := {} # the current clip (kit.clip(anim, dir, look))
var dir := "front" # side, front, back (+ any extra view the kind drew)
var flip := false # mirrored: facing left in the side view
var xp := -1 # unused since beta v1 (kills drop light shards: director ROSTER `shards`); kept for the brains
var dead := false # killed: out of gameplay; the death animation plays on as a remnant
var gone := false # set it to leave: an alive enemy is removed without a kill, a remnant is dropped
var hit_stop := 0.0 # seconds left frozen (the game skips step() and step_dead() meanwhile)
var age := 0.0 # seconds since spawn (world time)

var _want_dir := "front"
var _want_flip := false
var _want_t := 0.0


# --- virtuals: override in a brain ---------------------------------------------------------------------------

## After spawn: `game`, `kit`, `id`, `kind`, `hp`, `node` and (by arrive) `pos` are set. Pick a look and start an
## animation.
func setup() -> void:
	look = kit.pick_look()
	play("spawn" if kit.has_anim("spawn") else kit.data["animations"].keys()[0])


## Where it appears. `anchor` is the director's point for the group (a walkable point just outside the view),
## `index` of `count` enemies spawned together. Default: the anchor, the rest of a pack scattered around it.
func arrive(anchor: Vector2, index: int, count: int) -> void:
	pos = anchor
	if index == 0:
		return
	var spread := 6.0 + 3.0 * count
	for i in 6:
		var p := anchor + Vector2.from_angle(randf() * TAU) * randf_range(spread * 0.4, spread)
		if game.open(p):
			pos = p
			return


## Alive, every simulation step: world seconds (already scaled by the world speed).
func step(dt: float) -> void:
	advance(dt)
	age += dt


## A remnant (killed), every simulation step. Default: the death plays out, then the remnant is dropped.
func step_dead(dt: float) -> void:
	advance(dt)
	if done():
		gone = true


## Auto-aim may pick it (aim skips it otherwise). Default: alive.
func aimable() -> bool:
	return not dead


## The hit centre in world px: shots aim at it, splash and stings measure to it.
func centre() -> Vector2:
	var d: Dictionary = clip["data"][frame()]
	var c: Variant = d.get("hit_centre", d.get("centre"))
	if c == null:
		c = kit.data.get("centre", kit.data.get("body_centre", [0, -kit.hit_radius]))
	return pos + KIT.vec(c) * Vector2(-1.0 if mirrored() else 1.0, 1.0)


## Body radius around centre() for shots and splash reach.
func reach() -> float:
	return kit.hit_radius


## Does a shot at `p` touch it? Default: aimable and within reach() + 1 of centre().
func shot_hits(p: Vector2) -> bool:
	var r := reach() + 1.0
	return aimable() and p.distance_squared_to(centre()) <= r * r


## Does an attack coming from `from` (world px) bounce off? Default: never. The toad's parasol says yes from the
## front. Shots, the bell toll's splash and the fireflies' stings all ask this before they hurt.
func blocks(_from: Vector2) -> bool:
	return false


## A blocked attack struck it at `at`, coming from `from`: play the block (no damage, no flash).
func on_block(_at: Vector2, _from: Vector2) -> void:
	pass


## It took `damage` and lives (hp is already lowered). `push` = knockback velocity, `from` = where the attack came
## from (Vector2.INF when unknown). Default: flash, hit-stop, the push and the hurt animation.
func hurt(_damage: int, p: Vector2, _from: Vector2) -> void:
	flash = FLASH_TIME
	hit_stop = HIT_STOP[game.damage_tier()]
	push = p
	if kit.has_anim("hurt"):
		play("hurt")


## It was killed (already out of `enemies`, the XP is paid). Default: play `death`, or leave at once.
func die(_p: Vector2, _from: Vector2) -> void:
	dead = true
	flash = 0.0
	hit_stop = HIT_STOP[game.damage_tier()]
	if kit.has_anim("death"):
		play("death")
	else:
		gone = true


## Contact with Wick, whose body is a circle at `body` of `radius`. Default: the hit circle, while aimable.
func touches(body: Vector2, radius: float) -> bool:
	var r := reach() + radius
	return aimable() and body.distance_squared_to(centre()) < r * r


## Drawn on the flyer layer (above props and actors) instead of the Sort layer.
func flyer() -> bool:
	return false


## Takes part in the walkers' crowd push (game.separation).
func solid() -> bool:
	return not dead and not flyer()


## Under the Sort layer; the layer's shader shades the ground under whatever is drawn (any colour).
func draw_shadow(ci: CanvasItem) -> void:
	draw_layer(ci, "shadow")


func draw_body(ci: CanvasItem) -> void:
	var flashed: bool = flash > 0.0 and game.lv("hit_flash") == 0 and clip["tex"].has("flash")
	draw_layer(ci, "flash" if flashed else "body")


## The finale: only the eyes, above the dead pixels.
func draw_eyes(ci: CanvasItem) -> void:
	draw_layer(ci, "eyes")


## Headless check (tests/enemy_check.gd): failures for this kind from the run's stats ({} keys: README.md).
func lab_check(_stats: Dictionary) -> PackedStringArray:
	return PackedStringArray()


# --- helpers -------------------------------------------------------------------------------------------------

func play(name: String) -> void:
	anim = name
	anim_t = 0.0
	clip = kit.clip(anim, dir, look)


## Switches the view now (keeps the animation time).
func set_dir(d: String, mirrored: bool) -> void:
	_want_dir = d
	_want_flip = mirrored
	_want_t = 0.0
	if d != dir or mirrored != flip:
		dir = d
		flip = mirrored
		clip = kit.clip(anim, dir, look)


## Turns toward velocity `v`: side when |vx| > SIDE_RATIO |vy|, else front (down) or back (up). A new view must
## hold DIR_HOLD seconds first, so crowds don't flicker.
func face(v: Vector2, dt: float) -> void:
	if v.length_squared() < 0.01:
		return
	var d := "side" if absf(v.x) > SIDE_RATIO * absf(v.y) else ("front" if v.y > 0.0 else "back")
	var m := v.x < 0.0 if d == "side" else flip
	if d == dir and m == flip:
		_want_t = 0.0
		return
	if d != _want_dir or m != _want_flip:
		_want_dir = d
		_want_flip = m
		_want_t = 0.0
	_want_t += dt
	if _want_t >= DIR_HOLD:
		set_dir(d, m)


## Advances the animation; true when the frame changed (then read fd("event")).
func advance(dt: float) -> bool:
	var before := frame()
	anim_t += dt * 1000.0
	if clip["loop"]:
		anim_t = fmod(anim_t, clip["total"])
	return frame() != before


## The current frame index (ANIMATIONS sold: loops hold frame 0, one-shots show frame 0 until they end; a baked
## flash frame 0 only for FLASH_TIME, see _still_frame).
func frame() -> int:
	return frame_at(anim_t)


func frame_at(t: float) -> int:
	var ms: PackedFloat32Array = clip["ms"]
	if clip["loop"]:
		if still():
			return 0
		t = fmod(t, clip["total"])
	elif t >= clip["total"]:
		return ms.size() - 1
	elif still():
		return _still_frame(t)
	for i in ms.size():
		t -= ms[i]
		if t < 0.0:
			return i
	return ms.size() - 1


## ANIMATIONS sold, a one-shot at `t` ms: frame 0, but a baked flash at the front shows only for FLASH_TIME (never
## once HIT FLASH is sold), then the first frame after it holds until the clip ends.
func _still_frame(t: float) -> int:
	var first := 0
	while first < clip["frames"] - 1 and is_flash_frame(first):
		first += 1
	if first > 0 and t < FLASH_TIME * 1000.0 and game.lv("hit_flash") == 0:
		return 0
	return first


## A one-shot is over.
func done() -> bool:
	return not clip["loop"] and anim_t >= clip["total"]


## A value from the current frame's frame_data.
func fd(key: String, default: Variant = null) -> Variant:
	return clip["data"][frame()].get(key, default)


func still() -> bool:
	return game.still()


## The frame is drawn mirrored: facing left in a side (or other non front/back) view.
func mirrored() -> bool:
	return flip and not UNMIRRORED.has(clip["dir"])


## Moves by `step` (world px) on the island: walkers slide around solid props, flyers only stay on the island.
func walk(step: Vector2, fly := false) -> void:
	pos = game.walk(self, step, fly)


## A frame whose pixels are the hit flash: skipped (the next frame shows) once HIT FLASH is sold.
func is_flash_frame(f: int) -> bool:
	var d: Dictionary = clip["data"][f]
	return bool(d.get("flashed", false)) or d.get("event", "") == "hit"


## Draws one layer of the current frame with its anchor on `at` (default: pos). Side views face right: a
## mirrored frame flips about the anchor. Shadows of a mirrored frame use the clip's unflipped `shadow_mirror`
## or `shadow_left` sheet when the kind drew one (the sun stays in the west), else flip like the body.
func draw_layer(ci: CanvasItem, layer: String, at := Vector2.INF, f := -1) -> void:
	var tex_by: Dictionary = clip["tex"]
	var shadow := layer.contains("shadow")
	var mirror := mirrored()
	if layer == "shadow" and mirror:
		for alt in SHADOW_ALTS:
			if tex_by.has(alt):
				layer = alt
				mirror = false
				break
	if not tex_by.has(layer):
		return
	if f < 0:
		f = frame()
		if game.lv("hit_flash") > 0 and is_flash_frame(f):
			f = mini(f + 1, clip["frames"] - 1)
	var size: Vector2 = kit.shadow_size if shadow else clip["size"]
	var anchor: Vector2 = kit.shadow_anchor if shadow else clip["anchor"]
	var feet := (pos if at == Vector2.INF else at).round()
	var left := feet.x - ((size.x - anchor.x) if mirror else anchor.x)
	var dest := Rect2(Vector2(left, feet.y - anchor.y), size)
	if mirror:
		dest.size.x = -size.x
	ci.draw_texture_rect_region(tex_by[layer], dest, Rect2(f * size.x, 0, size.x, size.y))
