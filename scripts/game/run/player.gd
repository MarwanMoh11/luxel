extends RefCounted
## Wick's body: input (UP KEY, the INPUT DELAY buffer), movement (MOVEMENT), collisions on the walk layer, hearts
## and MERCY TIME (design 6, 9.3). Bots: with run.autopilot the direction comes from run.bot (tests/run_bot.gd)
## or the plain dodge bot here; UP KEY and INPUT DELAY apply to them too.

const BASE_HP := 6
const FEET := Vector2(0, 3.5) # feet to the body circle's centre (the prototype's 7 px box)
const BODY_RADIUS := 3.5 # contact circle with enemies and hazards
const MOVE_ACCEL: Array[float] = [1.0, 0.25] # accel factor per MOVEMENT level (SNAPPY, ICE)
const INPUT_DELAY: Array[float] = [0.0, 0.2] # seconds of movement lag per INPUT DELAY level
const MERCY: Array[float] = [1.5, 0.8] # seconds of invulnerability after a hit per MERCY TIME level
const DODGE_NEAR := 60.0 # px: the dodge bot steps away from enemies this close
const GUARD_LEVEL := 12 # from act 3 (the CONTROLS tab's level, shop_data.gd) a hit can't take the last heart
const STAGGER := 0.5 # s Wick can't steer after a spill
const STORY := preload("res://scripts/game/story/story_text.gd")
const NUDGE_PX := 8 # px: walking head-on into a prop's edge this close to clearing it slides Wick around it
const NUDGE_SPEED := 0.6 # the nudge's sideways speed, of his own

var run ## the Run (run.gd), duck-typed
var feet := Vector2.ZERO ## the ground point under Wick (his body node's position)
var vel := Vector2.ZERO
var hp := 0
var max_hp := 0
var invuln := 0.0 ## seconds of MERCY TIME left
var stagger := 0.0 ## seconds of the lantern spilling's stagger left (no steering)
var spills := 0 ## times the lantern spilled this run (the results card)

var _buf_t := PackedFloat64Array()
var _buf_d := PackedVector2Array()


## Keeps the back-reference to the run.
func setup(r) -> void:
	run = r


## Back to the run's start state (spawn point, full hearts).
func reset() -> void:
	feet = run.island.spawn
	run.view.place_wick(feet)
	vel = Vector2.ZERO
	max_hp = BASE_HP + int(run.prog.hearts)
	hp = max_hp
	invuln = 0.0
	stagger = 0.0
	spills = 0
	_buf_t.clear()
	_buf_d.clear()
	_sync()


## Reads input (MOVEMENT, INPUT DELAY, UP KEY), moves and collides Wick's feet (slower on rough ground). World seconds.
func step(dt: float) -> void:
	vel = run.player_vel # the toad's dome may have shoved Wick since the last step
	var dir := _delayed(_lose_up(_wanted()))
	if stagger > 0.0:
		dir = Vector2.ZERO
		stagger = maxf(stagger - dt, 0.0)
	var accel: float = run.prog.accel() * MOVE_ACCEL[mini(run.lv("movement"), 1)]
	var body: CharacterBody2D = run.view.body
	vel = vel.move_toward(dir * run.prog.speed() * run.view.ground_speed(body.position), accel * dt)
	var before := body.position
	var motion := vel * dt
	for i in 3:
		var hit := body.move_and_collide(motion)
		if hit == null:
			break
		if i == 0:
			_nudge(body, hit.get_normal(), dir, dt)
		motion = hit.get_remainder().slide(hit.get_normal())
	feet = body.position
	if dt > 0.0:
		vel = (body.position - before) / dt
	invuln = maxf(invuln - dt, 0.0)
	_sync()


## Corner help: pushing straight into a wall (within about 25 degrees of its normal) while a sidestep of up to
## NUDGE_PX clears the way drifts Wick toward that side (the side he leans to first), so stones, trunks and posts
## don't stop him dead. Long walls have no clear sidestep and still stop him.
func _nudge(body: CharacterBody2D, normal: Vector2, dir: Vector2, dt: float) -> void:
	if dir.dot(-normal) < 0.9:
		return
	var side := normal.orthogonal()
	if dir.dot(side) < 0.0:
		side = -side
	for d in range(1, NUDGE_PX + 1):
		for s: Vector2 in [side, -side]:
			if not body.test_move(Transform2D(0.0, body.position + s * d), dir * 2.0):
				body.move_and_collide(s * minf(d, run.prog.speed() * NUDGE_SPEED * dt))
				return


## A contact can land now: not in MERCY TIME, not immortal (checks), not while a level-up is about to open.
func hittable() -> bool:
	return invuln <= 0.0 and not run.immortal and not run.levelup_pending()


## Takes one heart; false if safe, invulnerable (MERCY TIME), or the last heart from act 3 on (GUARD_LEVEL, and
## always while closing), so a player who reached act 3 sees the finale. Starts MERCY TIME
## whenever the contact registers, also when no heart is lost. A guarded hit from GUARD_LEVEL (not while closing)
## spills the lantern instead: the gauge's light scatters as shards Wick can run back in for a few seconds.
func hurt() -> bool:
	if not hittable():
		return false
	invuln = MERCY[mini(run.lv("mercy"), 1)]
	if run.safe:
		return false
	if hp <= 1 and (run.closing() or run.prog.level >= GUARD_LEVEL):
		if not run.closing():
			_spill()
		return false
	hp -= 1
	return true


## The lantern spills: the gauge empties into shards around Wick, a stagger, a line over him.
func _spill() -> void:
	spills += 1
	stagger = STAGGER
	run.shards.spill(run.lantern(), run.prog.spill())
	if run.hud != null:
		run.hud.nag(STORY.line("quip.lantern_spills", "THE LANTERN SPILLS."), 1.2)


## Restores `n` hearts up to max_hp.
func heal(n: int) -> void:
	hp = clampi(hp + n, 0, max_hp)


## The body circle's centre (contact with enemies and hazards).
func body_centre() -> Vector2:
	return feet - FEET


func _sync() -> void:
	run.player_vel = vel
	run.player_pos = feet - FEET


func _wanted() -> Vector2:
	if run.autopilot:
		return run.bot.dir(run) if run.bot != null else dodge_dir()
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	return d.normalized()


## The plain dodge bot: away from close enemies and harmful hazards, pulled toward the island's spawn.
func dodge_dir() -> Vector2:
	var away := Vector2.ZERO
	var body := body_centre()
	for e in run.enemies:
		var d: Vector2 = body - e.centre()
		var l2 := maxf(d.length_squared(), 1.0)
		if l2 < DODGE_NEAR * DODGE_NEAR:
			away += d / l2
	for h in run.hazards:
		var d: Vector2 = body - h.pos
		var l2 := maxf(d.length_squared(), 1.0)
		if h.harmful and l2 < 1600.0:
			away += d / l2 * 2.0
	return (away + (run.island.spawn - body) / 4000.0).normalized()


# UP KEY sold (FLAKY): Up/W cuts out in dead spans between live ones, on run time (menus freeze it and are spared).
const UP_LIVE := Vector2(0.4, 1.0) ## seconds a live span lasts (min, max)
const UP_DEAD := Vector2(0.25, 0.6) ## seconds a dead span lasts (min, max): about 38% of the time dead
var _up_rng := RandomNumberGenerator.new() ## seeded from the run's RNG at the sale, so seeded bot runs repeat
var _up_dead := false ## Up is cutting out right now
var _up_until := -1.0 ## run_time the current span ends (-1: UP KEY not sold)


## Movement through the flaky Up key (bots too): during a dead span Up/W does nothing.
func _lose_up(d: Vector2) -> Vector2:
	_tick_up()
	if _up_dead and d.y < 0.0:
		d.y = 0.0
	return d.normalized()


func _tick_up() -> void:
	if run.lv("up_key") == 0:
		_up_until = -1.0
		_up_dead = false
		return
	var now: float = run.run_time
	if _up_until < 0.0: # the first step after the sale starts on a live span
		_up_rng.seed = randi()
		_up_dead = false
		_up_until = now + _up_rng.randf_range(UP_LIVE.x, UP_LIVE.y)
	while now >= _up_until:
		_up_dead = not _up_dead
		var span := UP_DEAD if _up_dead else UP_LIVE
		_up_until += _up_rng.randf_range(span.x, span.y)


## True while the flaky Up key is cutting out (the HUD shows UP: STUCK if Up is held).
func up_dead() -> bool:
	return _up_dead


## INPUT DELAY: the direction that was held `delay` seconds of play ago (a time-stamped buffer).
func _delayed(d: Vector2) -> Vector2:
	var delay := INPUT_DELAY[mini(run.lv("input_delay"), 1)]
	if delay <= 0.0:
		_buf_t.clear()
		_buf_d.clear()
		return d
	var now: float = run.run_time
	_buf_t.append(now)
	_buf_d.append(d)
	var due := now - delay
	while _buf_t.size() > 1 and _buf_t[1] <= due:
		_buf_t.remove_at(0)
		_buf_d.remove_at(0)
	return _buf_d[0] if _buf_t[0] <= due else Vector2.ZERO
