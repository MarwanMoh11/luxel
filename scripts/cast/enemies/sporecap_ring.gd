## The Sporecap's puff ring (sporecap.json effects.puff_ring): eight little clouds race out with the spores from
## the cap's crown on the puff's release frame. Harmless and never stopped by cover; drawn above actors and props
## with the hazards. The cap skips it once PARTICLES is sold; with ANIMATIONS sold it shows frame 0 for its 0.31 s.
extends "res://scripts/cast/enemies/hazard.gd"

const SPORE := preload("res://scripts/cast/enemies/sporecap_spore.gd")

var _fx := {}


func _init(kit, at: Vector2) -> void:
	_fx = kit.data["effects"]["puff_ring"]
	pos = at
	harmful = false
	blocked_by_cover = false
	life = float(_fx["total_ms"]) / 1000.0


func draw(ci: CanvasItem) -> void:
	SPORE.blit(ci, _fx, "body", pos, 0 if game.still() else SPORE.frame_of(_fx, age * 1000.0))
