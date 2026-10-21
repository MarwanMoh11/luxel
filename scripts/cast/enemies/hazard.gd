## Base of an enemy projectile or ground hazard that outlives its owner (the Sporecap's spores). A brain makes
## one (extend this file in scripts/cast/enemies/<id>_*.gd), sets it up and hands it to game.add_hazard(h).
## The game steps it in world time, kills it on cover (when `blocked_by_cover`), hurts Wick on touch and draws
## it: draw_shadow under the Sort layer, draw on the flyer layer (above actors and props), draw_eyes in the finale.
extends RefCounted

var game # the island arena (its enemy API, README.md)
var pos := Vector2.ZERO # world px (its centre; it may draw its shadow lower)
var vel := Vector2.ZERO # px per world second (step() moves it by default)
var radius := 3.0 # contact radius with Wick's body
var life := 1.0 # world seconds left
var harmful := true # hurts Wick on contact (clear it while it pops)
var blocked_by_cover := true # cover and landmarks (the island's shot layer) stop it: on_blocked()
var gone := false # set it to drop the hazard
var age := 0.0


## Every simulation step, world seconds. Default: fly straight, expire at the end of its life.
func step(dt: float) -> void:
	age += dt
	pos += vel * dt
	life -= dt
	if life <= 0.0:
		expire()


## Its life ran out. Default: gone (keep it a moment with harmful = false to play a pop).
func expire() -> void:
	gone = true


## It touched Wick (the game hurts him; invulnerability frames still apply). Default: gone.
func on_hit_wick() -> void:
	gone = true


## It reached cover or a landmark. Default: gone.
func on_blocked() -> void:
	gone = true


## Contact with Wick's body (a circle at `body` of `r`).
func touches(body: Vector2, r: float) -> bool:
	var reach := radius + r
	return harmful and not gone and body.distance_squared_to(pos) < reach * reach


func draw_shadow(_ci: CanvasItem) -> void:
	pass


func draw(_ci: CanvasItem) -> void:
	pass


func draw_eyes(_ci: CanvasItem) -> void:
	pass
