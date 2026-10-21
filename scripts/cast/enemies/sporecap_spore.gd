## A Sporecap spore (sporecap.json effects.spore), the game's first enemy projectile: a dark core in a pale
## membrane with six turning spikes (a spiky ring in 2 colours, never a filled dot like Wick's embers). It flies
## straight out of the puff and hurts Wick on contact; cover and landmarks stop it (the game calls on_blocked).
## At the end of its life, on cover or on Wick it pops (effects.spore_pop, harmless; it just vanishes once
## PARTICLES is sold). The spikes turn on the world's 12 fps tick (2 ticks a frame), so they hold still once
## ANIMATIONS is sold. In the finale only its ice pixels (the eyes layer) draw, above the dead pixels.
## The static helpers draw the kind's effect sheets (the puff ring uses them too).
extends "res://scripts/cast/enemies/hazard.gd"

const ROOT := "res://art/cast/enemies/sporecap/"
const POP_SOUND_GAP := 0.08 # seconds: a ring's eight pops at once make one sound

static var _tex := {} # sheet path -> Texture2D, shared by every spore
static var _last_pop := -1.0 # game.run_time of the last pop sound

var _spore := {} # effects.spore
var _pop := {} # effects.spore_pop
var _popping := -1.0 # ms into the pop; < 0 while it flies


## `kit` = the Sporecap's kit; flies from `at` at `v` px/s for `seconds`, touching Wick within `r` px.
func setup(kit, at: Vector2, v: Vector2, seconds: float, r: float) -> void:
	var fx: Dictionary = kit.data["effects"]
	_spore = fx["spore"]
	_pop = fx["spore_pop"]
	pos = at
	vel = v
	life = seconds
	radius = r


func step(dt: float) -> void:
	if _popping < 0.0:
		super(dt)
		return
	age += dt
	_popping += dt * 1000.0
	if _popping >= float(_pop["total_ms"]):
		gone = true


func expire() -> void:
	_burst("expired")


func on_hit_wick() -> void:
	_burst("hit_wick")


func on_blocked() -> void:
	_burst("blocked")


func draw_shadow(ci: CanvasItem) -> void:
	if _popping < 0.0:
		blit(ci, _spore, "shadow", pos, _spin())


func draw(ci: CanvasItem) -> void:
	if _popping < 0.0:
		blit(ci, _spore, "body", pos, _spin())
	else:
		blit(ci, _pop, "body", pos, 0 if game.still() else frame_of(_pop, _popping))


func draw_eyes(ci: CanvasItem) -> void:
	if _popping < 0.0:
		blit(ci, _spore, "eyes", pos, _spin())


## Draws frame `f` of effect `fx`'s `layer` sheet with its origin on `at`.
static func blit(ci: CanvasItem, fx: Dictionary, layer: String, at: Vector2, f: int) -> void:
	if not fx.has(layer):
		return
	var path: String = fx[layer]
	if not _tex.has(path):
		_tex[path] = load(ROOT + path)
	var size := Vector2(float(fx["frame"][0]), float(fx["frame"][1]))
	var origin := Vector2(float(fx["origin"][0]), float(fx["origin"][1]))
	ci.draw_texture_rect_region(_tex[path], Rect2(at.round() - origin, size), Rect2(f * size.x, 0.0, size.x, size.y))


## The frame of one-shot effect `fx` at `ms` into it (the last frame after the end).
static func frame_of(fx: Dictionary, ms: float) -> int:
	var list: Array = fx["ms"]
	for i in list.size():
		ms -= float(list[i])
		if ms < 0.0:
			return i
	return list.size() - 1


## The spikes' frame: 2 world ticks each (frame 0 while ANIMATIONS is sold, since the tick holds at 0).
func _spin() -> int:
	return (game.tick() / 2) % int(_spore["frames"])


func _burst(why: String) -> void:
	game.stat("sporecap_spores_" + why)
	harmful = false
	vel = Vector2.ZERO
	if absf(game.run_time - _last_pop) >= POP_SOUND_GAP:
		_last_pop = game.run_time
		game.enemy_sound("spore_pop")
	if game.lv("particles") > 0:
		gone = true
	else:
		_popping = 0.0
