## The Snuffer: the fodder you mow down by the dozen (art/cast/enemies/snuffer/snuffer.json). It rises out of a
## puff of void smoke, then waddle-hops straight at Wick at a constant speed (the hop is cosmetic); packs spread
## with the walkers' crowd push. Three looks (tin, soot, dent) and three deaths (pop, flip, cork) by weight.
## Its own death replaces the light's dissolve: the cone flies off and clatters down, and the fallen cone lingers
## LINGER seconds (none once PARTICLES is sold; selling it sweeps the lying ones away).
extends "res://scripts/cast/enemies/enemy.gd"

const SAFE_UNTIL_MS := 310.0 # spawn: it can't hurt or be hurt before frame 4
const LINGER := 4.0 # seconds a fallen cone stays on the ground
const LINGER_FRAME := 7 # death frame with the cone at rest (frame 8 dissolves it)
const LINGER_TOP := 22 # the held frame draws from this row down: the cone, not the last wisp of smoke above it
const STUCK_SPEED := 6.0 # px/s: slower than this for STUCK_TIME (pressed in a crowd, against a prop) = idle
const STUCK_TIME := 0.25
const DEATHS: Array[String] = ["death_pop", "death_flip", "death_cork"]

var speed := 32.0
var _linger := 0.0 # seconds left holding the fallen cone; < 0 = done with it
var _slow := 0.0
var _death_weights := {}


func setup() -> void:
	speed = float(kit.behaviour.get("speed_px_s", speed))
	_death_weights = kit.data["rig"]["death_weights"]
	look = kit.pick_look()
	play("spawn")
	game.enemy_sound("snuffer_spawn")
	game.stat("snuffer_look_" + look)


func step(dt: float) -> void:
	age += dt
	advance(dt) # hops are silent: a pack would drown the music
	if anim == "spawn":
		if done():
			_hop()
		return
	if anim == "hurt" and done():
		_hop()
	var before := pos
	var to_wick: Vector2 = game.wick_feet() - pos
	var settle := clampf(dt * 20.0, 0.0, 1.0)
	walk((to_wick.normalized() * speed + push) * dt + game.separation(self) * 0.5 * settle)
	push = push.move_toward(Vector2.ZERO, 400.0 * dt)
	var vel := (pos - before) / dt if dt > 0.0 else Vector2.ZERO
	face(vel if vel.length_squared() > 1.0 else to_wick, dt)
	if anim == "hurt":
		return
	_slow = _slow + dt if vel.length() < STUCK_SPEED else 0.0
	if anim == "hop" and _slow >= STUCK_TIME:
		play("idle")
	elif anim == "idle" and _slow == 0.0:
		_hop()


func step_dead(dt: float) -> void:
	if _linger > 0.0:
		_linger -= dt
		if game.lv("particles") > 0:
			gone = true
		elif _linger <= 0.0:
			_linger = -1.0
			anim_t = _start_of(LINGER_FRAME + 1)
		return
	if advance(dt):
		match fd("event"):
			"pop":
				game.enemy_sound("snuffer_pop")
			"clatter":
				game.enemy_sound("snuffer_clatter")
	if frame() == LINGER_FRAME and _linger == 0.0 and not still() and game.lv("particles") == 0:
		_linger = LINGER
		game.stat("snuffer_linger")
	if done():
		gone = true


func aimable() -> bool:
	return not dead and (anim != "spawn" or anim_t >= SAFE_UNTIL_MS)


func hurt(_damage: int, p: Vector2, _from: Vector2) -> void:
	hit_stop = HIT_STOP[game.damage_tier()] # hurt frame 0 is the flash (baked; skipped once HIT FLASH is sold)
	push = p
	if anim == "spawn":
		flash = FLASH_TIME # still rising: the flash layer instead
	else:
		play("hurt")


func die(_p: Vector2, _from: Vector2) -> void:
	dead = true
	flash = 0.0
	hit_stop = HIT_STOP[game.damage_tier()]
	var death := KIT.pick(_death_weights)
	play(death if DEATHS.has(death) else DEATHS[0])
	game.stat("snuffer_" + anim)


func set_dir(d: String, mirrored: bool) -> void:
	super(d, mirrored)
	game.stat("snuffer_view_" + d)


func draw_body(ci: CanvasItem) -> void:
	if _linger <= 0.0:
		super(ci)
		return
	# the fallen cone: only the lower rows of its resting frame
	var size: Vector2 = clip["size"]
	var anchor: Vector2 = clip["anchor"]
	var feet := pos.round()
	var left := feet.x - ((size.x - anchor.x) if mirrored() else anchor.x)
	var dest := Rect2(Vector2(left, feet.y - anchor.y + LINGER_TOP), Vector2(size.x, size.y - LINGER_TOP))
	if mirrored():
		dest.size.x = -size.x
	var src := Rect2(LINGER_FRAME * size.x, LINGER_TOP, size.x, size.y - LINGER_TOP)
	ci.draw_texture_rect_region(clip["tex"]["body"], dest, src)


func draw_shadow(ci: CanvasItem) -> void:
	draw_layer(ci, "shadow", Vector2.INF, LINGER_FRAME if _linger > 0.0 else -1)


func draw_eyes(ci: CanvasItem) -> void:
	if _linger <= 0.0:
		super(ci)


## Every look, death and view showed up; fallen cones lingered (none once PARTICLES or ANIMATIONS is sold).
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var want: Array[String] = []
	for l: String in kit.looks:
		want.append("snuffer_look_" + l)
	for d in DEATHS:
		want.append("snuffer_" + d)
	for v in ["side", "front", "back"]:
		want.append("snuffer_view_" + v)
	var no_linger := stats.has("sold_particles") or stats.has("sold_animations")
	if no_linger and stats.has("snuffer_linger"):
		fails.append("cones lingered with PARTICLES or ANIMATIONS sold")
	elif not no_linger:
		want.append("snuffer_linger")
	for key in want:
		if int(stats.get(key, 0)) < 1:
			fails.append("never saw " + key)
	return fails


func _hop() -> void:
	play("hop")
	anim_t = randi_range(0, clip["frames"] - 1) * clip["total"] / clip["frames"] # packs never hop in step
	_slow = 0.0
	var to_wick: Vector2 = game.wick_feet() - pos
	set_dir("side" if absf(to_wick.x) > SIDE_RATIO * absf(to_wick.y) else ("front" if to_wick.y > 0.0 else "back"),
		to_wick.x < 0.0)


## Milliseconds into the current clip where frame `f` starts.
func _start_of(f: int) -> float:
	var t := 0.0
	for i in mini(f, clip["frames"]):
		t += clip["ms"][i]
	return t
