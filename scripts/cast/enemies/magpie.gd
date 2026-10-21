## The Magpie, the thief (art/cast/enemies/magpie/magpie.json): it stole a star from the lantern, and catching it
## pays a free Settings sale. It dives in at a side edge of the view with the star glinting in its beak (the glint
## follows the island's 2 s loop), then circles Wick wide on a breathing ellipse that stays on screen, dawdling now
## and then to flaunt the star. When Wick comes within panic_radius (an ellipse: VSCALE) it does a double take
## (startle: it hovers frozen for 270 ms, then bolts) and flees in dashes, zig-zagging and staring back, with a short
## stare between dashes; past CALM_RADIUS it calms down and circles again. After leave_after s it laughs, hovers and
## climbs out of view with the star (no reward); it also leaves when the finale starts. It never hurts Wick, flies
## over everything (always on the flyer layer) and is worth no XP: a kill knocks the star loose, the star hangs,
## arcs into the lantern (star_free, star_fly, star_home), and only then game.free_level_up() opens the menu.
## Catchable with intent, not by accident: shots don't lead, so a bird crossing at range mostly dodges them, and in
## a crowd the snuffers are the nearest target anyway. Chasing it is what works: the dash (95 px/s) zig-zags 35 deg off
## the line, so it gets away at 78 px/s against Wick's 85; each stare (STARE s) lets him close in and land shots, and
## it never lets him closer than BURST_GAP (then it flees straight, no zig-zag). Tuned with a key-pressing chaser bot
## at 1:05 on the real timeline, base power: 7 of 8 caught, in 3.4-6.6 s; standing still: 0 of 4.
extends "res://scripts/cast/enemies/enemy.gd"

enum Mode { ENTER, CRUISE, STARTLE, PANIC, ESCAPE, CLIMB }
enum Star { FREE, FLY, HOME, DONE }

const ALT := 16.0 # px: the cruising body above the ground point (fly frame_data altitude); steering uses the body
const RING := Vector2(118.0, 50.0) # px: the cruise ellipse around Wick's body (half-width, half-height)
const RING_BREATH := 14.0 # px the ellipse's width swells and shrinks, so the path curves instead of orbiting
const RING_LEAD := 0.55 # radians ahead on the ellipse it steers for
const VSCALE := 0.7 # the panic and calm radii are ellipses this much shorter than wide: the view is 320x180, so
		# the bird can't get 60 px above Wick (about 50 px of room) and would panic on its own path
const TAUNT_EVERY := Vector2(1.6, 2.4) # seconds of cruising between taunts: it dawdles, flaunting the star
const TAUNT := 0.45 # seconds a taunt lasts (a sitting target for a Wick who has it as his nearest enemy)
const TAUNT_SPEED := 15.0 # px/s while it taunts
const CALM_RADIUS := 90.0 # px: a panic ends beyond this
const DASH := Vector2(1.0, 1.4) # seconds of each panicked dash (at panic_speed, zig-zagging)
const STARE := 0.35 # seconds it then dawdles, staring back at Wick: he closes in and his shots land
const STARE_SPEED := 22.0 # px/s while it stares
const BURST_GAP := 28.0 # px: closer than this a stare ends and it dashes straight away, no zig-zag (95 px/s beats
		# Wick's 85), so it never sits on his head (hiding him) and the chase keeps a readable gap
const ZIG := 0.7 # sideways share of the panic flight (tan 35 deg)
const ZIG_FLIP := Vector2(0.35, 0.5) # seconds between zig-zag flips
const STARTLE_GAP := 1.5 # seconds: a panic this soon after the last one skips the double take
const STARTLE_HOVER := 270.0 # ms of the startle spent frozen (frames 0-1), then it bolts
const FLEE_DIRS := 32 # directions the panic weighs every step
const FLEE_LOOK := 30.0 # px ahead the panic judges a direction (distance won, view edge, island rim)
const EDGE_FREE := 20.0 # px: closer than this to the view's inset edge it stops zig-zagging and slides away
const STEER_CRUISE := 5.0 # 1/s: how fast its velocity turns toward the wanted one while cruising
const STEER_PANIC := 9.0 # ...and while fleeing (crisp zig-zags)
const ENTER_GLIDE := 0.6 # share of the cruise speed during the entrance dive
const ENTER_INSET := 26.0 # px inside the view's side edge where it dives in
const ENTER_MIN := 100.0 # px from Wick's body at least, so it doesn't panic on arrival
const INSET := Vector4(22.0, 36.0, 22.0, 26.0) # px its body keeps inside the view: left, top (under the HUD,
		# star included), right, bottom (its shadow)
const ESCAPE_HOVER := 330.0 # ms of the escape's smug hover (frames 0-2): shots still land, then it climbs
const CLIMB := 150.0 # px/s it keeps climbing after the escape's last frame, until it is above the view
const CLIMB_FLAP := 0.07 # seconds per wing frame while it climbs (escape frames 8-9)
const REACH := 10.0 # px: its hit circle (magpie.json hit_radius 6 covers the torso; this covers the wings)
const PUSH_SHARE := 0.25 # share of a shot's knockback it takes (full knockback would help it flee)
const STAR_ROOT := "res://art/cast/enemies/magpie/"
const STAR_TRAIL: Array[Color] = [Color8(255, 217, 140), Color8(245, 169, 106)] # gold, apricot (30 / 60 ms back)

var mode := Mode.ENTER
var vel := Vector2.ZERO
var cruise_speed := 60.0
var panic_speed := 95.0
var panic_radius := 60.0
var leave_after := 9.0
var _sign := 1.0 # circling direction
var _turn_cd := 0.0 # seconds before it may reverse its circling again
var _zig := 1.0
var _eyes_pass := false # inside draw_eyes (the finale's Top layer): the star draws there, not late
var _zig_t := 0.0
var _calm_at := -INF # age when the last panic ended
var _born := 0.0 # game.clock() at spawn: the escape timer runs on world time (hit-stops don't stretch it)
var _taunt_t := 2.0 # seconds to the next taunt (> 0) or left of the current one (< 0)
var _dash_t := 0.0 # seconds left of the current dash (> 0) or stare (< 0)
var _escape_dir := Vector2.RIGHT
var _climb := 0.0 # px climbed past the escape's last frame
var _climb_t := 0.0
var _star := Star.FREE
var _star_t := 0.0 # ms into the current star effect
var _star_at := Vector2.ZERO # star_free origin (world px)
var _fly_from := Vector2.ZERO
var _fly_ms := 0.0
var _chimed := false
var _fx := {} # effect name -> {"tex", "frame", "origin", "ms", "total"}


func setup() -> void:
	look = kit.pick_look()
	xp = 0 # the reward is the free level-up
	var b: Dictionary = kit.behaviour
	cruise_speed = float(b.get("cruise_speed", cruise_speed))
	panic_speed = float(b.get("panic_speed", panic_speed))
	panic_radius = float(b.get("panic_radius", panic_radius))
	leave_after = float(b.get("leave_after_s", leave_after))
	_born = game.clock()
	_load_fx()
	_sign = 1.0 if randf() < 0.5 else -1.0
	_zig = 1.0 if randf() < 0.5 else -1.0
	var inward: Vector2 = game.wick_body() - _body()
	vel = inward.normalized() * cruise_speed * ENTER_GLIDE
	mode = Mode.ENTER
	play("enter")
	_face_now(inward)
	game.enemy_sound("magpie_chatter")
	game.stat("magpie_enter")


## At a side edge of the view (inside it, so the dive shows), over the island and well away from Wick.
func arrive(anchor: Vector2, _index: int, _count: int) -> void:
	var view: Rect2 = game.view_rect()
	var wick: Vector2 = game.wick_body()
	var left_first := randf() < 0.5
	for i in 24:
		var b := Vector2.ZERO
		if i < 16: # the side edges, at any height where the dive (44 px up) still shows
			var left := left_first == (i % 2 == 0)
			b.x = view.position.x + ENTER_INSET if left else view.end.x - ENTER_INSET
			b.y = randf_range(view.position.y + 44.0, view.end.y - INSET.w)
		else: # then the top and bottom edges
			b.x = randf_range(view.position.x + INSET.x, view.end.x - INSET.z)
			b.y = view.position.y + 44.0 if i % 2 == 0 else view.end.y - INSET.w
		var p := b + Vector2(0, ALT)
		if _gap(b, wick) >= ENTER_MIN and game.open(p, 0):
			pos = p
			game.stat("magpie_enter_in_view")
			return
	pos = anchor # no room on screen (the view mostly over the void): the director's point just off screen
	game.stat("magpie_enter_outside")


func step(dt: float) -> void:
	age += dt
	advance(dt)
	_turn_cd -= dt
	if game.alive("magpie") > 1:
		game.stat("magpie_crowded")
	if mode <= Mode.PANIC and (game.clock() - _born >= leave_after or game.finale()):
		_escape()
	match mode:
		Mode.ENTER:
			_fly(dt)
			if done():
				mode = Mode.CRUISE
				_play_loop()
		Mode.CRUISE:
			_cruise(dt)
		Mode.STARTLE:
			_startle(dt)
		Mode.PANIC:
			_panic(dt)
		Mode.ESCAPE:
			_leave(dt)
		Mode.CLIMB:
			_leave(dt)
	if anim == "hurt" and done():
		_play_loop()


func step_dead(dt: float) -> void:
	advance(dt)
	_star_t += dt * 1000.0
	match _star:
		Star.FREE:
			if not _chimed and _fx_frame("free", true) >= 3: # the hang with the big glint
				_chimed = true
				game.enemy_sound("star_chime")
			if _star_t >= _fx["free"]["total"]:
				_star = Star.FLY
				_star_t = 0.0
				_fly_from = _star_at + KIT.vec(kit.data["effects"]["star_free"]["launch_from"])
				_fly_ms = clampf(220.0 + 1.6 * _fly_from.distance_to(game.lantern()), 280.0, 650.0)
		Star.FLY:
			if _star_t >= _fly_ms:
				_star = Star.HOME
				_star_t = 0.0
				game.enemy_sound("star_home")
				game.stat("magpie_star_home")
		Star.HOME:
			if _star_t >= _fx["home"]["total"]:
				_star = Star.DONE
				_reward()
	if _star == Star.DONE and done():
		gone = true


func aimable() -> bool:
	return not dead and mode != Mode.CLIMB and not (mode == Mode.ESCAPE and anim_t >= ESCAPE_HOVER)


func hurt(_damage: int, p: Vector2, _from: Vector2) -> void:
	hit_stop = HIT_STOP[game.damage_tier()]
	push = p * PUSH_SHARE
	game.enemy_sound("magpie_squawk")
	if mode != Mode.CRUISE:
		flash = FLASH_TIME # the swoops, the double take and the panic's stare play on under the flash layer
		return
	play("hurt")


func die(_p: Vector2, _from: Vector2) -> void:
	dead = true
	flash = 0.0
	hit_stop = HIT_STOP[game.damage_tier()]
	var left := vel.x < 0.0 if absf(vel.x) > 1.0 else flip
	play("death")
	set_dir("side", left)
	var release := KIT.vec(kit.data["animations"]["death"]["star_release"])
	_star_at = pos + release * Vector2(-1.0 if left else 1.0, 1.0)
	_star = Star.FREE
	_star_t = 0.0
	game.enemy_sound("magpie_squawk")


## Shots aim at it without leading, so a generous circle keeps a fleeing bird catchable.
func reach() -> float:
	return REACH


## Contact damage 0: it never attacks.
func touches(_body_at: Vector2, _radius: float) -> bool:
	return false


func flyer() -> bool:
	return true


## Hurt and death frame 0 are the baked flash (not marked in magpie.json).
func is_flash_frame(f: int) -> bool:
	return (f == 0 and (anim == "hurt" or anim == "death")) or super(f)


func play(name: String) -> void:
	super(name)
	game.stat("magpie_anim_" + name)


func set_dir(d: String, m: bool) -> void:
	super(d, m)
	if not dead:
		game.stat("magpie_view_" + d)


func draw_shadow(ci: CanvasItem) -> void:
	if mode == Mode.CLIMB or (dead and done()) or not game.open(pos, 0):
		return # climbing out of view, or over the void
	draw_layer(ci, "shadow", pos, _shown_frame())


## Shadow, [star if star_behind], body, [star]: the star is the only warm thing on it.
func draw_body(ci: CanvasItem) -> void:
	if dead:
		if not done():
			draw_layer(ci, "body")
		_draw_loose_star(ci)
		return
	var f := _shown_frame()
	var at := pos + Vector2(0, -_climb)
	var behind := bool(clip["data"][f].get("star_behind", false))
	if behind:
		_draw_held_star(ci, f, at, true)
	var flashed: bool = flash > 0.0 and game.lv("hit_flash") == 0 and clip["tex"].has("flash")
	draw_layer(ci, "flash" if flashed else "body", at, f)
	if not behind:
		_draw_held_star(ci, f, at)


## The finale: its eyes and the stolen light stay over the dead pixels.
func draw_eyes(ci: CanvasItem) -> void:
	_eyes_pass = true
	_draw_eyes(ci)
	_eyes_pass = false


func _draw_eyes(ci: CanvasItem) -> void:
	if dead:
		if not done():
			draw_layer(ci, "eyes")
		_draw_loose_star(ci)
		return
	var f := _shown_frame()
	var at := pos + Vector2(0, -_climb)
	draw_layer(ci, "eyes", at, f)
	_draw_held_star(ci, f, at)


## The run's magpies entered on screen, panicked only within range and escaped on time, and every star that
## landed paid exactly one level-up (one menu). Never two alive (outside crowd runs), never hurt Wick.
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var crowd := false
	for a in OS.get_cmdline_user_args():
		crowd = crowd or a.begins_with("crowd=")
	var n := int(stats.get("spawned_magpie", 0))
	var rewards := int(stats.get("magpie_reward", 0))
	var menus := int(stats.get("menus_opened", 0))
	if int(stats.get("magpie_enter", 0)) != n:
		fails.append("%d spawned but %d entered" % [n, int(stats.get("magpie_enter", 0))])
	if int(stats.get("magpie_enter_in_view", 0)) < 1:
		fails.append("never entered inside the view")
	for key in ["wick_hurt_magpie", "magpie_panic_far", "magpie_escape_off_time", "magpie_reward_early"]:
		if int(stats.get(key, 0)) > 0:
			fails.append("%s = %d" % [key, int(stats[key])])
	if int(stats.get("magpie_levels", 0)) != rewards:
		fails.append("%d rewards gave %d levels" % [rewards, int(stats.get("magpie_levels", 0))])
	if rewards > int(stats.get("magpie_star_home", 0)):
		fails.append("more rewards (%d) than stars home (%d)" % [rewards, int(stats.get("magpie_star_home", 0))])
	if crowd:
		if menus > rewards or (rewards > 0 and menus < 1):
			fails.append("%d free level-ups opened %d menus" % [rewards, menus])
		for key in ["magpie_anim_startle", "magpie_anim_panic", "magpie_anim_escape", "left_magpie"]:
			if int(stats.get(key, 0)) < 1:
				fails.append("never saw " + key)
	else:
		if int(stats.get("magpie_crowded", 0)) > 0:
			fails.append("two magpies alive at once")
		if menus != rewards:
			fails.append("%d free level-ups opened %d menus" % [rewards, menus])
		var killed := int(stats.get("killed_magpie", 0))
		if killed - int(stats.get("remnants_done_magpie", 0)) > 1:
			fails.append("caught stars never landed")
		if not stats.has("sold_pixels") and killed > 0 and rewards < 1:
			fails.append("a catch never paid a level-up")
	var want: Array[String] = ["magpie_anim_enter", "magpie_anim_fly", "magpie_anim_hurt"]
	if not crowd: # a crowd of 30 shares the shots: few die (the plain runs prove the catch)
		want.append("magpie_anim_death")
	for v in ["side", "front", "back"]:
		want.append("magpie_view_" + v)
	for key in want:
		if int(stats.get(key, 0)) < 1:
			fails.append("never saw " + key)
	return fails


# --- flight ----------------------------------------------------------------------------------------------------

## The body point it steers by (the shots' centre is near it).
func _body() -> Vector2:
	return pos - Vector2(0, ALT)


## The view inset so its body, star and shadow stay on screen (body space).
func _inner() -> Rect2:
	var v: Rect2 = game.view_rect()
	return Rect2(v.position + Vector2(INSET.x, INSET.y), v.size - Vector2(INSET.x + INSET.z, INSET.y + INSET.w))


func _ring() -> Vector2:
	return Vector2(RING.x + RING_BREATH * sin(age * 0.9), RING.y)


func _cruise(dt: float) -> void:
	var wick: Vector2 = game.wick_body()
	var ring := _ring()
	var a := ((_body() - wick) / ring).angle() + _sign * RING_LEAD
	var r := _inner()
	var target := (wick + Vector2.from_angle(a) * ring).clamp(r.position, r.end)
	if _turn_cd <= 0.0 and not game.open(target + Vector2(0, ALT), 0):
		_sign = -_sign # the ellipse runs off the island here: circle the other way
		_turn_cd = 1.0
	_taunt_t -= dt
	if _taunt_t <= -TAUNT:
		_taunt_t = randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)
	var speed := TAUNT_SPEED if _taunt_t < 0.0 else cruise_speed
	_steer((target - _body()).normalized() * speed, STEER_CRUISE, dt)
	_fly(dt)
	face(vel, dt)
	var d := _gap(_body(), game.wick_body())
	if d < panic_radius:
		_start_panic(d)


func _start_panic(d: float) -> void:
	if d > panic_radius:
		game.stat("magpie_panic_far")
	game.enemy_sound("magpie_alarm")
	game.stat("magpie_panic")
	_zig_t = randf_range(ZIG_FLIP.x, ZIG_FLIP.y)
	_dash_t = randf_range(DASH.x, DASH.y)
	if age - _calm_at < STARTLE_GAP:
		mode = Mode.PANIC
		_play_loop()
		return
	mode = Mode.STARTLE # the double take: it turns to Wick and freezes
	play("startle")
	_face_now(game.wick_body() - _body())


func _startle(dt: float) -> void:
	var want := Vector2.ZERO if anim_t < STARTLE_HOVER else _flee_dir() * panic_speed
	_steer(want, STEER_PANIC, dt)
	_fly(dt)
	if done():
		mode = Mode.PANIC
		_play_loop()
		_face_now(_away())


func _panic(dt: float) -> void:
	_zig_t -= dt
	if _zig_t <= 0.0:
		_zig = -_zig
		_zig_t = randf_range(ZIG_FLIP.x, ZIG_FLIP.y)
	var gap := _gap(_body(), game.wick_body())
	if _dash_t > 0.0:
		_dash_t -= dt
		if _dash_t <= 0.0:
			_dash_t = -STARE
			game.stat("magpie_stare")
	else:
		_dash_t += dt
		if _dash_t >= 0.0 or gap < BURST_GAP:
			_dash_t = randf_range(DASH.x, DASH.y)
	_steer(_flee_dir() * (panic_speed if _dash_t > 0.0 else STARE_SPEED), STEER_PANIC, dt)
	_fly(dt)
	face(vel, dt)
	if gap > CALM_RADIUS:
		mode = Mode.CRUISE
		_calm_at = age
		_play_loop()


## Away from Wick's body (any way when on top of him).
func _away() -> Vector2:
	var d: Vector2 = _body() - game.wick_body()
	return d.normalized() if d.length_squared() > 0.01 else Vector2.from_angle(randf() * TAU)


## How far `a` is from `b` for panicking and calming: px across, vertical px count 1 / VSCALE.
func _gap(a: Vector2, b: Vector2) -> float:
	return ((a - b) * Vector2(1.0, 1.0 / VSCALE)).length()


## The panic's heading: of FLEE_DIRS directions, the one that wins the most distance from Wick, tilted ZIG toward
## the zig-zag side (35 deg off the line) while it has room, kept inside the view (it slides along the edge, away
## from Wick) and over the island. A small bonus for the current heading stops it dithering.
func _flee_dir() -> Vector2:
	var wick: Vector2 = game.wick_body()
	var b := _body()
	var r := _inner()
	var now := _gap(b, wick)
	var side := _away().orthogonal() * _zig
	var free := _outside(r.grow(-EDGE_FREE), b) == 0.0 and now >= BURST_GAP # too close: straight away, no zig
	var heading := vel.normalized()
	var best := _away()
	var best_score := -INF
	for i in FLEE_DIRS:
		var d := Vector2.from_angle(i * TAU / FLEE_DIRS)
		var ahead := b + d * FLEE_LOOK
		var score := (_gap(ahead, wick) - now) / FLEE_LOOK + 0.25 * d.dot(heading)
		if free:
			score += ZIG * d.dot(side)
		score -= 3.0 * _outside(r, ahead) / FLEE_LOOK
		if score > best_score and not game.open(pos + d * FLEE_LOOK, 0):
			score -= 3.0 # the island's rim (checked only for a direction that would win)
		if score > best_score:
			best_score = score
			best = d
	return best


## How far `p` lies outside `r` (px, summed over the axes).
static func _outside(r: Rect2, p: Vector2) -> float:
	return maxf(r.position.x - p.x, 0.0) + maxf(p.x - r.end.x, 0.0) + maxf(r.position.y - p.y, 0.0) \
		+ maxf(p.y - r.end.y, 0.0)


func _steer(want: Vector2, rate: float, dt: float) -> void:
	vel = vel.lerp(want, 1.0 - exp(-rate * dt))


## Moves by its velocity and any knockback; it stays over the island (flyers ignore props).
func _fly(dt: float) -> void:
	walk((vel + push) * dt, true)
	push = push.move_toward(Vector2.ZERO, 400.0 * dt)


## Out of time (or the finale began): a smug laugh, a hover, then off toward the nearest island edge.
func _escape() -> void:
	if not game.finale() and absf(game.clock() - _born - leave_after) > 0.1:
		game.stat("magpie_escape_off_time")
	mode = Mode.ESCAPE
	_escape_dir = _edge_dir()
	play("escape")
	_face_now(_escape_dir)
	game.enemy_sound("magpie_laugh")


## Toward the nearest island edge, away from Wick when two are about as near.
func _edge_dir() -> Vector2:
	var away := _away()
	var best := away
	var best_score := INF
	for i in 16:
		var d := Vector2.from_angle(i * TAU / 16.0)
		for r in range(40, 400, 40):
			if not game.open(pos + d * r, 0):
				var score := r - 60.0 * d.dot(away)
				if score < best_score:
					best_score = score
					best = d
				break
	return best


func _leave(dt: float) -> void:
	_steer(Vector2.ZERO if anim_t < ESCAPE_HOVER else _escape_dir * cruise_speed, STEER_CRUISE, dt)
	pos += (vel + push) * dt # free flight: it may leave the island now
	push = push.move_toward(Vector2.ZERO, 400.0 * dt)
	if mode == Mode.ESCAPE:
		if done():
			mode = Mode.CLIMB
		return
	_climb += CLIMB * dt
	_climb_t += dt
	var tail := pos.y - _climb - float(clip["data"][_shown_frame()]["altitude"]) + 10.0 # the bird's lowest pixel
	if tail < game.view_rect().position.y or _climb > 240.0:
		gone = true


## The animation it returns to after a hurt or a mode change (a playing hurt finishes first).
func _play_loop() -> void:
	if anim == "hurt" and not done():
		return
	var want := "panic" if mode == Mode.PANIC else "fly"
	if anim != want:
		play(want)


## Turns to `v` now (side, front or back), no hold.
func _face_now(v: Vector2) -> void:
	set_dir("side" if absf(v.x) > SIDE_RATIO * absf(v.y) else ("front" if v.y > 0.0 else "back"), v.x < 0.0)


## The frame to draw: the flash frame skipped once HIT FLASH is sold; wingbeats on the escape's last two frames
## while it climbs (frame 0 when ANIMATIONS is sold, as the climb starts from it then).
func _shown_frame() -> int:
	if mode == Mode.CLIMB and not dead:
		var n: int = clip["frames"]
		return 0 if still() else n - 2 + int(_climb_t / CLIMB_FLAP) % 2
	var f := frame()
	if game.lv("hit_flash") > 0 and is_flash_frame(f):
		f = mini(f + 1, clip["frames"] - 1)
	return f


func _reward() -> void:
	if game.finale() or game.display_off():
		return # no level-ups in the finale
	if _star != Star.DONE:
		game.stat("magpie_reward_early")
	var before: int = game.level
	game.free_level_up()
	game.stat("magpie_reward")
	game.stat("magpie_levels", int(game.level) - before)


# --- the star --------------------------------------------------------------------------------------------------

func _load_fx() -> void:
	for name in ["held", "free", "fly", "home"]:
		var e: Dictionary = kit.data["effects"]["star_" + name]
		var ms := PackedFloat32Array()
		for v: float in e["ms"]:
			ms.append(v)
		var total := 0.0
		for v in ms:
			total += v
		_fx[name] = {"tex": load(STAR_ROOT + str(e["file"])), "frame": KIT.vec(e["frame"]),
			"origin": KIT.vec(e["origin"]), "ms": ms, "total": total}


## Frame of a one-shot star effect at _star_t (frame 0 while ANIMATIONS is sold, unless `raw`).
func _fx_frame(name: String, raw := false) -> int:
	if still() and not raw:
		return 0
	var t := _star_t
	var ms: PackedFloat32Array = _fx[name]["ms"]
	for i in ms.size():
		t -= ms[i]
		if t < 0.0:
			return i
	return ms.size() - 1


func _draw_fx(ci: CanvasItem, name: String, at: Vector2, f: int, row := 0, direct := false) -> void:
	var e: Dictionary = _fx[name]
	var size: Vector2 = e["frame"]
	var dest := Rect2((at - e["origin"]).round(), size)
	var src := Rect2(f * size.x, row * size.y, size.x, size.y)
	if direct or _eyes_pass: # behind the body, or the finale's Top layer: stays with its own draw
		ci.draw_texture_rect_region(e["tex"], dest, src)
	else:
		late(game.view.above, e["tex"], dest, src) # over the horde's bodies


## In the beak: glints on the world's 2 s loop (frame 0 glints, so it still shows with ANIMATIONS sold).
func _draw_held_star(ci: CanvasItem, f: int, at: Vector2, direct := false) -> void:
	var beak: Variant = clip["data"][f].get("beak")
	if beak == null:
		return
	var b := KIT.vec(beak) * Vector2(-1.0 if mirrored() else 1.0, 1.0)
	_draw_fx(ci, "held", at + b, game.tick() % 24, 0, direct)


## Knocked loose: it tumbles up and hangs, arcs into the lantern, bursts there.
func _draw_loose_star(ci: CanvasItem) -> void:
	match _star:
		Star.FREE:
			_draw_fx(ci, "free", _star_at, _fx_frame("free"))
		Star.FLY:
			var p := _fly_pos(_star_t)
			var ahead := p - _fly_pos(_star_t - 10.0)
			var row := posmod(roundi(rad_to_deg(ahead.angle()) / 22.5), 16)
			for i in STAR_TRAIL.size():
				var back := _star_t - 30.0 * (i + 1)
				if back >= 0.0:
					ci.draw_rect(Rect2(_fly_pos(back).round(), Vector2.ONE), STAR_TRAIL[i])
			_draw_fx(ci, "fly", p, 0 if still() else int(_star_t / 40.0) % 2, row)
		Star.HOME:
			_draw_fx(ci, "home", game.lantern(), _fx_frame("home"))


## The flight at `t` ms: a quadratic Bezier from the launch to the lantern (recomputed as Wick moves), arcing
## 28 px up, accelerating into the lantern.
func _fly_pos(t: float) -> Vector2:
	var to: Vector2 = game.lantern()
	var mid := (_fly_from + to) * 0.5 - Vector2(0, 28)
	var u := clampf(t / _fly_ms, 0.0, 1.0)
	var e := u * u
	return _fly_from.lerp(mid, e).lerp(mid.lerp(to, e), e)
