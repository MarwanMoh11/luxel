## The lantern forms that fight (design 6). Bell toll (tier 1+): the ring of an impact hurts every enemy it
## reaches (weapons.json "splash"; a share of the shot's damage, when the ring gets there). Fireflies: each darts
## out to sting an enemy near Wick (weapons.json "sting"), then flies back to its orbit and reloads. Moon trail: a
## shot's glints linger as long as they are drawn and hurt each enemy that crosses them once. River wake: every hop
## that lands hurts the enemies in its ripple and pushes them away from Wick.
## Gameplay only: light_fx.gd draws the darting flies, the chimes, the stings, the glints and the wake. Owned by
## combat.gd (KNOCKBACK sold pushes 0). Forms hit hard on purpose, so each new one is felt.
extends RefCounted

const SPLASH_SHARE: Array[float] = [0.0, 0.5, 0.65, 0.8] # of the shot's damage, by bell toll tier
const SPLASH_PUSH := 30.0
const TOLL_PITCH: Array[float] = [1.0, 0.667, 0.5] # tiers 1-3: the A sample on A, D, low A (D minor)
const STING_RANGE := 72.0 # px from Wick's feet to the enemy's centre
const STING_SHARE := 0.8 # of the shot's damage
const STING_RELOAD := 0.6 # seconds between one fly's stings
const MOON_SHARE: Array[float] = [0.0, 0.35, 0.6] # of the shot's damage, by moon trail tier
const MOON_REACH := 3.0 # px from a glint to the enemy's body
const MOON_LAG := 8.0 # px: the live glints end this far behind the shot (the shot's own hit comes first)
const MOON_START := 12.0 # px from the lantern to the first glint (combat.gd Shot.moon_at)
const WAKE_RADIUS := 22.0 # px from Wick's feet to the enemy's body
const WAKE_SHARE := 0.6 # of the shot's damage
const WAKE_PUSH := 140.0 # px/s outward (none once KNOCKBACK is sold)
const SOUND_GAP := 0.1 # seconds: at most one toll and one sting sound per gap
const TRAIL_GAP := 3.0 # px between a darting fly's trail motes

var run # the Run (run.gd), duck-typed: enemies, hurt_enemy, shot_damage(), lv(), wick, combat, fx
var light # light_fx.gd: tiers, the splash and sting tables, and the effects
var _rings: Array = [] # splash on its way: {"e", "dmg", "t" (seconds left), "from", "tier"}
var _flies: Array = [] # per firefly: {"cd", "phase" (0 orbit, 1 out, 2 back), "t", "e", "from", "pos", "vel", "drop"}
var _moons: Array = [] # moon trails: {"shot", "age", "life", "dmg", "hit"}
var _toll_cd := 0.0
var _sting_cd := 0.0


func setup(r, l) -> void:
	run = r
	light = l


func reset() -> void:
	_rings.clear()
	_flies.clear()
	_moons.clear()
	_toll_cd = 0.0
	_sting_cd = 0.0


## A shot hit `struck` at `pos` for `dmg`: the bell toll's ring will reach the enemies around it.
func toll(pos: Vector2, struck, dmg: int) -> void:
	var tier: int = light.damage_tier()
	if tier == 0:
		return
	if _toll_cd <= 0.0 and light.stage() == 0:
		_toll_cd = SOUND_GAP
		run.fx.play("toll", 0.0, TOLL_PITCH[tier - 1])
	var radius: int = light.splash["radius"][tier]
	var reach: Array = light.splash["reach_ms"][tier]
	for e in run.enemies:
		if e == struck or not e.aimable():
			continue
		var d: float = pos.distance_to(e.centre()) - e.reach()
		if d > radius:
			continue
		var px := clampi(int(maxf(d, 0.0)), 0, mini(radius, reach.size() - 1))
		_rings.append({
			"e": e, "dmg": maxi(1, roundi(dmg * SPLASH_SHARE[tier])), "t": float(reach[px]) / 1000.0,
			"from": pos, "tier": tier})


## A shot left the lantern: with the moon trail on, its glints will hurt what crosses them.
func shot(b) -> void:
	var tier: int = light.moon_tier()
	if tier == 0 or light.stage() > 0:
		return
	_moons.append({"shot": b, "age": 0.0, "life": light.moon_life(tier), "hit": [],
		"dmg": maxi(1, roundi(run.shot_damage() * MOON_SHARE[tier]))})


## World time `dt`: rings land, flies sting, glints and the wake hurt. A ring or sting that arrives after its
## target went out of reach (an owl back up high, a magpie climbing away) misses it.
func step(dt: float) -> void:
	_toll_cd -= dt
	_sting_cd -= dt
	if not _rings.is_empty():
		for r: Dictionary in _rings:
			r["t"] -= dt
			if r["t"] <= 0.0 and run.enemies.has(r["e"]) and r["e"].aimable():
				var at: Vector2 = r["e"].centre()
				if _lands(r["e"], r["dmg"], (at - r["from"]).normalized() * _push(SPLASH_PUSH), r["from"]):
					light.chime(at, r["tier"])
		_rings = _rings.filter(func(r: Dictionary) -> bool: return r["t"] > 0.0)
	_step_flies(dt)
	_step_moons(dt)
	_wake()


## Fly k's state, for drawing: {} while it orbits, else {"pos", "vel"} in world space.
func fly(k: int) -> Dictionary:
	if k >= _flies.size() or _flies[k]["phase"] == 0:
		return {}
	return _flies[k]


func _step_flies(dt: float) -> void:
	var n: int = light.fly_count()
	while _flies.size() < n: # a new fly joins with its reload staggered from the others
		_flies.append({"cd": STING_RELOAD * _flies.size() / float(n), "phase": 0, "t": 0.0, "e": null,
			"from": Vector2.ZERO, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "drop": Vector2.ZERO})
	_flies.resize(n)
	if dt <= 0.0:
		return
	var out: float = light.sting["out_ms"] / 1000.0
	var back: float = light.sting["back_ms"] / 1000.0
	var feet: Vector2 = run.wick_feet()
	for k in n:
		var f: Dictionary = _flies[k]
		var home: Vector2 = feet + light.orbit_offset(n, k)
		var was: Vector2 = f["pos"]
		match f["phase"]:
			0:
				f["pos"] = home
				f["cd"] -= dt
				if f["cd"] <= 0.0:
					var e = _prey(feet)
					if e != null:
						f["phase"] = 1
						f["t"] = 0.0
						f["e"] = e
						f["from"] = home
						f["drop"] = home
			1:
				f["t"] += dt
				var alive: bool = run.enemies.has(f["e"])
				if alive:
					var u := minf(f["t"] / out, 1.0)
					f["pos"] = _arc(f["from"], f["e"].centre(), 1.0 - (1.0 - u) * (1.0 - u))
				if not alive or f["t"] >= out:
					# the block test sees the dart's launch point (the fly's last spot hugs the target)
					if alive and f["e"].aimable():
						var at: Vector2 = f["e"].centre()
						if _lands(f["e"], maxi(1, roundi(run.shot_damage() * STING_SHARE)), Vector2.ZERO, f["from"]):
							light.sting_hit(at)
							if _sting_cd <= 0.0:
								_sting_cd = SOUND_GAP
								run.fx.play("sting", 0.0)
					f["phase"] = 2
					f["t"] = 0.0
					f["from"] = f["pos"]
					f["e"] = null
			2:
				f["t"] += dt
				var u := minf(f["t"] / back, 1.0)
				f["pos"] = _arc(f["from"], home, u * u * (3.0 - 2.0 * u))
				if u >= 1.0:
					f["phase"] = 0
					f["cd"] = STING_RELOAD / run.fire_scale() # slower while the lantern is spent
		_trail(f)
		f["vel"] = (f["pos"] - was) / dt


## A darting fly leaves a trail mote every TRAIL_GAP px of its path.
func _trail(f: Dictionary) -> void:
	if f["phase"] == 0:
		return
	var drop: Vector2 = f["drop"]
	var to: Vector2 = f["pos"]
	while drop.distance_to(to) >= TRAIL_GAP:
		drop = drop.move_toward(to, TRAIL_GAP)
		light.fly_trail(drop)
	f["drop"] = drop


## Moon trails: the glints still drawn (from MOON_START or the oldest live one, to MOON_LAG behind the shot) hurt
## each enemy whose body they touch, once per shot.
func _step_moons(dt: float) -> void:
	if _moons.is_empty():
		return
	var struck: Array = [] # [enemy, dmg, from]
	for m: Dictionary in _moons:
		m["age"] += dt
		var b = m["shot"]
		var speed: float = b.vel.length()
		var head: float = b.origin.distance_to(b.pos) - MOON_LAG
		var tail: float = maxf(MOON_START, speed * (float(m["age"]) - float(m["life"])))
		m["done"] = tail >= head and not run.combat.bullets.has(b)
		if tail >= head:
			continue
		var dir: Vector2 = b.vel / speed if speed > 0.0 else Vector2.RIGHT
		var a: Vector2 = b.origin + dir * tail
		var z: Vector2 = b.origin + dir * head
		var lo := Vector2(minf(a.x, z.x), minf(a.y, z.y)) - Vector2(24.0, 24.0)
		var hi := Vector2(maxf(a.x, z.x), maxf(a.y, z.y)) + Vector2(24.0, 24.0)
		for e in run.enemies:
			var c: Vector2 = e.centre()
			if c.x < lo.x or c.x > hi.x or c.y < lo.y or c.y > hi.y:
				continue
			if not e.aimable() or m["hit"].has(e) or b.hit.has(e):
				continue
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(c, a, z)
			if near.distance_to(c) <= e.reach() + MOON_REACH:
				m["hit"].append(e)
				struck.append([e, m["dmg"], near - dir * 8.0])
	_moons = _moons.filter(func(m: Dictionary) -> bool: return not m["done"])
	for s: Array in struck:
		if run.enemies.has(s[0]):
			_lands(s[0], s[1], Vector2.ZERO, s[2])


## River wake: a hop that lands hurts and pushes every enemy within the ripple.
func _wake() -> void:
	if not light.wake_on() or light.stage() >= 2 or run.wick == null or not run.wick.landed:
		return
	var feet: Vector2 = run.wick_feet()
	var dmg := maxi(1, roundi(run.shot_damage() * WAKE_SHARE))
	var near: Array = []
	for e in run.enemies:
		if e.aimable() and feet.distance_to(e.centre()) - e.reach() <= WAKE_RADIUS:
			near.append(e)
	for e in near:
		if run.enemies.has(e):
			var away: Vector2 = (e.centre() - feet).normalized()
			_lands(e, dmg, away * _push(WAKE_PUSH), feet)


## Hurts `e` unless it refuses (the toad's parasol, an owl back up high); true when the hit landed.
func _lands(e, dmg: int, push: Vector2, from: Vector2) -> bool:
	var before: int = e.hp
	run.hurt_enemy(e, dmg, push, from)
	return e.hp < before


## The nearest enemy within reach of Wick that no other fly is after (else the nearest one at all, so a lone
## enemy draws the whole swarm).
func _prey(feet: Vector2):
	var best = null
	var best_d := STING_RANGE * STING_RANGE
	var best_free := false
	for e in run.enemies:
		if not e.aimable():
			continue
		var d: float = feet.distance_squared_to(e.centre())
		if d >= STING_RANGE * STING_RANGE:
			continue
		var free := not _flies.any(func(f: Dictionary) -> bool: return f["e"] == e)
		if (free and not best_free) or (free == best_free and d < best_d):
			best = e
			best_d = d
			best_free = free
	return best


## A push of `speed` px/s: none once KNOCKBACK is sold.
func _push(speed: float) -> float:
	return 0.0 if run.lv("knockback") > 0 else speed


## From `a` to `b` at `u` (0..1), bowed sideways by the sting's arc.
func _arc(a: Vector2, b: Vector2, u: float) -> Vector2:
	var side := (b - a).orthogonal().normalized() * float(light.sting.get("arc_px", 0))
	return a.lerp(b, u) + side * sin(u * PI)
