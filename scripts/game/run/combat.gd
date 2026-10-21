extends RefCounted
## Auto-aim, volleys, shots, hits and cover (design 6; ported from low_settings.gd and low_settings_island.gd).
## Shots leave the lantern glass and aim from it; the flare starts `light.lead()` early and Wick's cast 30 ms
## early, so the volley lands on the flare's smear frame. Cover and landmarks (physics layer 2) stop shots with an
## impact (the bell toll still rings out). Owns light_attacks (the toll's splash, the fireflies' stings).

const ATTACKS := preload("res://scripts/game/run/light_attacks.gd")
const FAN_ANGLE := 0.25 # radians between the shots of one volley
const KNOCKBACK := 60.0 # px/s a hit pushes (the prototype's feel; 0 once KNOCKBACK is sold)
const BLOCK_BACK := 8.0 # px behind a shot where its hit "comes from" (the toad's parasol test)


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


## Keeps the back-reference to the run and builds light_attacks.
func setup(r) -> void:
	run = r
	attacks = ATTACKS.new()


## Clears shots and cooldowns for a new run.
func reset() -> void:
	bullets.clear()
	_fire_cd = 0.0
	_armed = false
	_cast_armed = false
	if run.light != null:
		attacks.setup(run, run.light)
		attacks.reset()


## Fires volleys (AIM ASSIST, KNOCKBACK), moves shots, applies hits; calls light_fx and light_attacks.
## World seconds.
func step(dt: float) -> void:
	_fire(dt)
	_move(dt)
	attacks.step(dt)


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
	for e in run.enemies:
		if e.aimable() and from.distance_squared_to(e.centre()) < r * r:
			in_range.append(e)
	return null if in_range.is_empty() else in_range[randi() % in_range.size()]


func _nearest():
	var r: float = run.prog.range_px()
	var from: Vector2 = run.lantern()
	var best_e = null
	var best_d := r * r
	for e in run.enemies:
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


## The first enemy the shot touches (not one it already pierced). A brain's hit area lies within 32 px sideways,
## 96 px above and 24 px below its ground point (cheap cull before shot_hits).
func _hit(b: Shot):
	for e in run.enemies:
		if b.hit.has(e):
			continue
		if absf(b.pos.x - e.pos.x) > 32.0 or b.pos.y > e.pos.y + 24.0 or b.pos.y < e.pos.y - 96.0:
			continue
		if e.shot_hits(b.pos):
			return e
	return null
