extends RefCounted
## Auto-aim, volleys, shots, hits and cover (design 6; ported from low_settings.gd and low_settings_island.gd).
## Shots leave the lantern glass and aim from it; the flare starts `light.lead()` early and Wick's cast 30 ms
## early, so the volley lands on the flare's smear frame. Cover and landmarks (physics layer 2) stop shots with an
## impact (the bell toll still rings out). Owns light_attacks (the toll's splash, the fireflies' stings).

const ATTACKS := preload("res://scripts/game/run/light_attacks.gd")
const FAN_ANGLE := 0.25 # radians between the shots of one volley
const KNOCKBACK := 60.0 # px/s a hit pushes (the prototype's feel; 0 once KNOCKBACK is sold)
const BLOCK_BACK := 8.0 # px behind a shot where its hit "comes from" (the toad's parasol test)
# A brain's hit area (centre() +- reach()) lies within BODY_SIDE px sideways, BODY_UP px above and BODY_DOWN px below
# its ground point, for every kind, clip and frame (owl at its highest altitude, a magpie's climb, a toad's hop).
const BODY_SIDE := 32.0
const BODY_UP := 96.0
const BODY_DOWN := 24.0
const CELL := 64.0 # px: the enemy grid's cells (_fill_cells)
const NEAR_MAX_AREA := 640.0 * 640.0 # px^2: a wider query scans the list instead of the grid


## A shot that can pass through `left` more enemies, never hitting the same one twice. Its look and trail are set
## and advanced by light_fx.gd.
class Shot extends RefCounted:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.8
	var left := 0 ## pierce left (ARCHITECTURE.md's pierce_left)
	var hit: Array = []
	var look := "ember"
	var key := "gold"
	var start := 0
	var age := 0.0
	var origin := Vector2.ZERO
	var trail_at := 6.0
	var moon_at := 12.0
	var moon_k := 0


var run ## the Run (run.gd), duck-typed
var bullets: Array = [] ## Shot objects in flight (the same array as run.bullets)
var attacks ## light_attacks.gd

var _fire_cd := 0.0
var _armed := false # the flare for the next volley has started
var _cast_armed := false # ...and so has Wick's cast
var _cells := {} # Vector2i -> Array of indices into _listed, ascending (list order); arrays are kept and reused
var _cells_used: Array[Vector2i] = []
var _listed: Array = [] # run.enemies when the grid was filled; a kill leaves its (dead) entry in place
var _listed_kills := 0 # the host's kill count then
var _grid_ok := false # filled this step
var _stepping := false # inside step()
var _found := PackedInt32Array() # one shot's candidates


## Keeps the back-reference to the run and builds light_attacks.
func setup(r) -> void:
	run = r
	attacks = ATTACKS.new()


## Clears shots and cooldowns for a new run.
func reset() -> void:
	bullets.clear()
	_listed.clear()
	_grid_ok = false
	_fire_cd = 0.0
	_armed = false
	_cast_armed = false
	if run.light != null:
		attacks.setup(run, run.light)
		attacks.reset()


## Fires volleys (AIM ASSIST, KNOCKBACK), moves shots, applies hits; calls light_fx and light_attacks.
## World seconds.
func step(dt: float) -> void:
	_stepping = true # enemies hold still until the end of the step: one grid serves every query
	_grid_ok = false
	_fire(dt)
	_move(dt)
	attacks.step(dt)
	_stepping = false
	_grid_ok = false


func _fire(dt: float) -> void:
	_fire_cd -= dt
	if _fire_cd > 0.0:
		_wind_up()
		return
	var target = _target()
	if target == null:
		return
	_fire_cd = run.prog.fire_interval() / run.fire_scale() # the spent lantern fires slower (run.RELIGHT_FIRE)
	_armed = false
	_cast_armed = false
	var from: Vector2 = run.lantern()
	var aim: float = (target.centre() - from).angle() # from the lantern, so point-blank shots still cross the target
	var n: int = maxi(1, run.prog.shots)
	for i in n:
		var b := Shot.new()
		b.pos = from
		b.vel = Vector2.from_angle(aim + (i - (n - 1) / 2.0) * FAN_ANGLE) * run.bullet_speed
		b.life = run.prog.shot_life()
		b.left = run.prog.pierce
		run.light.style(b, i, n)
		bullets.append(b)
		attacks.shot(b)
	run.light.volley(aim, n)
	run.fx.play("shoot", 0.1)


func _wind_up() -> void:
	if _armed and _cast_armed:
		return
	if not _armed and _fire_cd <= run.light.lead() and _nearest() != null:
		_armed = true
		run.light.wind_up()
	if _armed and not _cast_armed and _fire_cd <= 0.03:
		_cast_armed = true
		run.wick.cast()


## AIM ASSIST: the nearest aimable enemy in range of the lantern, or a random one once sold.
func _target():
	if run.lv("aim") == 0:
		return _nearest()
	var r: float = run.prog.range_px()
	var from: Vector2 = run.lantern()
	var in_range: Array = []
	for e in near_point(from, r):
		if e.aimable() and from.distance_squared_to(e.centre()) < r * r:
			in_range.append(e)
	return null if in_range.is_empty() else in_range[randi() % in_range.size()]


func _nearest():
	var r: float = run.prog.range_px()
	var from: Vector2 = run.lantern()
	var best_e = null
	var best_d := r * r
	for e in near_point(from, r):
		if not e.aimable():
			continue
		var d := from.distance_squared_to(e.centre())
		if d < best_d:
			best_d = d
			best_e = e
	return best_e


func _move(dt: float) -> void:
	var push_k := 0.0 if run.lv("knockback") > 0 else KNOCKBACK
	var dmg: int = run.shot_damage() # the lantern's power included (spent after the relight, design 10.4)
	for i in range(bullets.size() - 1, -1, -1):
		var b: Shot = bullets[i]
		b.pos += b.vel * dt
		b.life -= dt
		run.light.track(b, dt * 1000.0)
		var hit = _hit(b)
		var heading := b.vel.normalized()
		var from := b.pos - heading * BLOCK_BACK
		if hit != null and hit.blocks(from):
			hit.on_block(b.pos, from)
			run.stat("blocks")
			bullets.remove_at(i) # pierce included
		elif hit != null:
			run.light.hit(b.pos, b.left > 0)
			b.hit.append(hit) # the moon trail's glints spare what the shot itself hit
			if b.left > 0:
				b.left -= 1
			else:
				bullets.remove_at(i)
			run.hurt_enemy(hit, dmg, heading * push_k, from)
			attacks.toll(b.pos, hit, dmg)
		elif not run.view.open(b.pos, 2, false):
			run.light.hit(b.pos, false) # cover and landmarks stop shots
			attacks.toll(b.pos, null, dmg)
			bullets.remove_at(i)
		elif b.life <= 0.0:
			bullets.remove_at(i)


## The first enemy the shot touches (not one it already pierced), in list order: only those the grid hands over
## (a px wider than the cull, so float rounding never drops one), then the cheap cull, then shot_hits.
func _hit(b: Shot):
	var p := b.pos
	_gather(p - Vector2(BODY_SIDE + 1.0, BODY_DOWN + 1.0), p + Vector2(BODY_SIDE + 1.0, BODY_UP + 1.0))
	for k in _found:
		var e = _listed[k]
		if e.dead or b.hit.has(e):
			continue
		if absf(p.x - e.pos.x) > BODY_SIDE or p.y > e.pos.y + BODY_DOWN or p.y < e.pos.y - BODY_UP:
			continue
		if e.shot_hits(p):
			return e
	return null


## The live enemies, in list order, whose hit area (centre() +- reach(), see BODY_SIDE) may reach into the box
## `lo`..`hi` (world px): a cheap pre-cull for the area tests here and in light_attacks.gd.
func near(lo: Vector2, hi: Vector2) -> Array:
	lo -= Vector2(BODY_SIDE + 1.0, BODY_DOWN + 1.0)
	hi += Vector2(BODY_SIDE + 1.0, BODY_UP + 1.0)
	var out: Array = []
	if (hi.x - lo.x) * (hi.y - lo.y) > NEAR_MAX_AREA: # wider than most of the map: the list is cheaper
		for e in run.enemies:
			var at: Vector2 = e.pos
			if at.x >= lo.x and at.x <= hi.x and at.y >= lo.y and at.y <= hi.y:
				out.append(e)
		return out
	_gather(lo, hi)
	for k in _found:
		var e = _listed[k]
		var at: Vector2 = e.pos
		if not e.dead and at.x >= lo.x and at.x <= hi.x and at.y >= lo.y and at.y <= hi.y:
			out.append(e)
	return out


## `near` around a point: the enemies whose hit area may come within `r` px of `p`.
func near_point(p: Vector2, r: float) -> Array:
	return near(p - Vector2(r, r), p + Vector2(r, r))


## _found = the indices into _listed (ascending, so list order) of the enemies whose ground point's cell overlaps
## the box `lo`..`hi`; dead ones (killed since the grid was filled) included.
func _gather(lo: Vector2, hi: Vector2) -> void:
	if not _grid_ok or run.enemies.size() != _listed.size() - (run.enemies_host.kills - _listed_kills):
		_fill_cells() # first query of the step, or an enemy joined (a kill only leaves a dead entry behind)
	_found.clear()
	for cy in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
		for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			var cell: Variant = _cells.get(Vector2i(cx, cy))
			if cell != null:
				for k: int in cell:
					_found.append(k)
	_found.sort()


## Sorts the live enemies into CELL cells by ground point (they don't move while shots and forms hit).
func _fill_cells() -> void:
	for c in _cells_used:
		(_cells[c] as Array).clear()
	_cells_used.clear()
	_listed = run.enemies.duplicate()
	_listed_kills = run.enemies_host.kills
	_grid_ok = _stepping # outside a step the enemies may move before the next query
	for k in _listed.size():
		var at: Vector2 = _listed[k].pos
		var c := Vector2i(floori(at.x / CELL), floori(at.y / CELL))
		var cell: Variant = _cells.get(c)
		if cell == null:
			cell = []
			_cells[c] = cell
		if (cell as Array).is_empty():
			_cells_used.append(c)
		(cell as Array).append(k)
