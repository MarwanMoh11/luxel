## The Parasol Toad's headless lab probe (only in `enemy_check -- lab=toad`, where Wick is the dodge bot, which
## never flanks). Every PROBE_GAP s a toad near Wick, hopping and facing him, gets the next probe, through the
## game's own paths; the results go to stats for toad.gd lab_check:
## 0) a real pierce-2 shot straight at the canopy (must stop on it), a bell toll and a sting from Wick's side
##    through game.hurt_enemy, with the source points light_attacks.gd passes (both must bounce);
## 1) and 2) a real pierce-2 shot 30 deg clockwise / counter-clockwise of the facing (must stop: block_cw and
##    block_ccw play) and one 90 deg off on that side (must hit);
## 3) a spin: the toad is turned away from Wick by hand (the turn-rate check skips that step), then a toll and a
##    sting from Wick's side must hurt it, and Wick's auto-fire lands in its back while it turns round (real back
##    hits, and the kills the check needs).
extends RefCounted

const SHOT := preload("res://scripts/game/run/combat.gd").Shot
const PROBE_GAP := 1.4 # s between probes on one toad
const RANGE := 110.0 # px from Wick's body: probes wait until the toad is this near
const SHOT_FROM := 30.0 # px from the toad's centre where a probe shot starts
const TOLL_OUT := 10.0 # px beyond the body's edge where a probe toll rang (the struck neighbour)
const STING_DMG := 5 # half a base shot (light_attacks.gd STING_SHARE)
const TOLL_DMG := 4 # a tier-II toll share of a base shot

var toad # toad.gd
var game
var _stage := 0
var _wait := 0.5
var _shots: Array[Dictionary] = [] # probe shots in flight: {"shot", "kind" ("front" or "side")}


func _init(t) -> void:
	toad = t
	game = t.game


func step(dt: float) -> void:
	_resolve()
	_wait -= dt
	if _wait > 0.0 or toad.dead:
		return
	var to: Vector2 = game.wick_body() - toad.centre()
	if to.length() > RANGE or toad.anim == "hurt":
		return
	if _stage % 4 != 3 and (toad.planted or absf(toad.offset(game.wick_body())) > 30.0):
		return # the front probes want it settled on Wick
	match _stage % 4:
		0:
			_fire(0.0, "front")
			_attack("toll_front", toad.centre() + to.normalized() * (toad.reach() + TOLL_OUT), TOLL_DMG)
			_attack("sting_front", _sting_from(to), STING_DMG)
		1:
			_fire(30.0, "front")
			_fire(90.0, "side")
		2:
			_fire(-30.0, "front")
			_fire(-90.0, "side")
		3:
			toad.facing = toad.snap(rad_to_deg(to.angle()) + 180.0)
			toad.target = toad.facing
			toad.planted = true
			toad.spun = true
			game.stat("toad_probe_spins")
			_attack("toll_back", toad.centre() + to.normalized() * (toad.reach() + TOLL_OUT), TOLL_DMG)
			_attack("sting_back", _sting_from(to), STING_DMG)
	_stage += 1
	_wait = PROBE_GAP


## A real shot (pierce 2) from SHOT_FROM px out at `off` deg from the facing, flying at the toad's centre.
func _fire(off: float, kind: String) -> void:
	var c: Vector2 = toad.centre()
	var s := SHOT.new()
	s.pos = c + Vector2.from_angle(deg_to_rad(toad.facing + off)) * SHOT_FROM
	s.origin = s.pos
	s.vel = (c - s.pos).normalized() * game.bullet_speed
	s.life = 0.5
	s.left = 2
	game.bullets.append(s)
	_shots.append({"shot": s, "kind": kind})


## A toll or sting landing through game.hurt_enemy from `from`: blocked = no hp lost.
func _attack(kind: String, from: Vector2, dmg: int) -> void:
	if toad.hp <= dmg:
		return
	var hp: int = toad.hp
	var blocks: int = game.stats.get("blocks", 0)
	game.hurt_enemy(toad, dmg, Vector2.ZERO, from)
	var blocked: bool = toad.hp == hp and int(game.stats.get("blocks", 0)) == blocks + 1
	var expect_block := kind.ends_with("front")
	game.stat("toad_probe_%s_%s" % [kind, "blocked" if blocked else "hit"])
	if blocked != expect_block:
		push_warning("toad probe %s: %s" % [kind, "blocked" if blocked else "hit"])


## A sting's source as light_attacks.gd passes it: the fly's position one step before it lands, about 1 px short
## of the centre along its dart from Wick, bowed 2.5 px sideways by its arc.
func _sting_from(to: Vector2) -> Vector2:
	var d := to.normalized()
	return toad.centre() + d * 1.0 + d.orthogonal() * 2.5


## Probe shots: a front shot must end on the canopy (toad.blocked_at holds where things struck it), a side shot
## must hit.
func _resolve() -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var s = _shots[i]["shot"]
		var kind: String = _shots[i]["kind"]
		var hit: bool = s.hit.has(toad)
		var stopped: bool = not game.bullets.has(s) and toad.blocked_at.has(s.pos)
		if not hit and not stopped and game.bullets.has(s):
			continue
		_shots.remove_at(i)
		if kind == "front":
			game.stat("toad_probe_pierce_blocked" if stopped else ("toad_probe_front_hit" if hit else
				"toad_probe_front_missed"))
		else:
			game.stat("toad_probe_side_hit" if hit else ("toad_probe_side_blocked" if stopped else
				"toad_probe_side_missed"))
	toad.blocked_at.clear()
