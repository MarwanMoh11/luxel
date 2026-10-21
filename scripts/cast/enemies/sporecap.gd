## The Sporecap: the turret, and the game's first enemy projectile (art/cast/enemies/sporecap/sporecap.json).
## It falls as a spinning seed for 1.0 s while its landing shadow grows and eight specks close in (not aimable,
## harmless; the fall keeps playing when ANIMATIONS is sold), lands 70-130 px from Wick on walkable ground in
## view, roots (never moves, ignores push) and sprouts (0.5 s, aimable from frame 2). Then the decision: its first
## ring comes right after the sprout (swell 0.6 s, puff), and from then on it cycles idle 2.0 s, swell 0.6 s,
## puff 0.4 s: a ring of 8 spores every 3.0 s, every other ring turned 22.5 deg (sporecap_spore.gd: they outlive
## the cap and cover stops them). It faces Wick, turning only when a cycle starts. Hits flash it; only an idle cap
## plays the hurt recoil, and hit-stop never delays a ring. Death: it droops, buckles and bursts into pale,
## harmless puffs. A garden (count > 1, formations) lands as a clump, one cap every GARDEN_STAGGER s.
extends "res://scripts/cast/enemies/enemy.gd"

const SPORE := preload("res://scripts/cast/enemies/sporecap_spore.gd")
const PUFF_RING := preload("res://scripts/cast/enemies/sporecap_ring.gd")

enum State {WAIT, FALL, SPROUT, IDLE, SWELL, PUFF}

const LAND_TRIES := 32 # landing spots tried in view, then as many anywhere
const VIEW_SIDE := 10.0 # px a landing spot keeps from the view's left and right edges
const VIEW_TOP := 24.0 # ... from the top edge (the cap stands ~20 px tall)
const VIEW_BOTTOM := 6.0 # ... from the bottom edge
const MIN_GAP := 18.0 # px between two caps' feet
const GARDEN_CENTRE := Vector2(85.0, 115.0) # px from Wick for a garden's first cap (the rest stay in 70-130)
const GARDEN_SPREAD := Vector2(16.0, 26.0) # px from the garden's first cap to the others
const GARDEN_STAGGER := 0.3 # seconds between the garden's falls
const TARGETABLE_FRAME := 2 # sprout frame from which it can be shot (sporecap.json behaviour.targetable)
const SPORE_SPEED := 42.0 # px/s (fallbacks: sporecap.json behaviour.ring has the numbers)
const SPORE_LIFE := 3.2 # seconds
const RING_TURN := 22.5 # degrees every other ring is turned

static var _garden := Vector2.INF # where the garden being placed put its first cap

var state := State.WAIT
var state_t := 0.0 # world seconds into `state`
var rings := 0 # rings released
var land_range := Vector2(70.0, 130.0) # px from Wick's feet
var _delay := 0.0 # seconds of WAIT before the fall
var _clock := 0.0 # game.run_time at the last step: hit-stop frames count too, so fire never delays a ring
var _fall := 1.0 # state lengths in seconds (behaviour)
var _sprout := 0.5
var _idle := 2.0
var _swell := 0.6
var _puff := 0.4
var _safe := 0.12 # seconds into the sprout before it can be shot
var _spores := 8
var _speed := SPORE_SPEED
var _life := SPORE_LIFE
var _turn := deg_to_rad(RING_TURN)
var _spawn_r := 6.0
var _spore_r := 3.0
var _cycle := 0.0 # cycle seconds since spawn: the clock state_t runs on (enemy tempo included), for the check
var _landed_at := -1.0 # _cycle at the landing / the last release (the check's timings)
var _last_ring := -1.0


func arrive(anchor: Vector2, index: int, count: int) -> void:
	land_range = Vector2(float(kit.behaviour["arrival"]["landing_distance_px"][0]),
		float(kit.behaviour["arrival"]["landing_distance_px"][1]))
	_delay = index * GARDEN_STAGGER
	var feet: Vector2 = game.wick_feet()
	var p := _landing(anchor, feet, index, count)
	if p == Vector2.INF:
		p = anchor
		game.stat("sporecap_land_fallback")
	pos = p
	if count > 1 and index == 0:
		_garden = p
	var d := p.distance_to(feet)
	game.stat("sporecap_land_near" if d >= land_range.x - 0.5 and d <= land_range.y + 0.5 else "sporecap_land_far")
	if not _in_view(p):
		game.stat("sporecap_land_unseen")


func setup() -> void:
	look = kit.pick_look()
	xp = int(kit.behaviour.get("xp", 4))
	var arrival: Dictionary = kit.behaviour["arrival"]
	var cycle: Dictionary = kit.behaviour["cycle"]
	var ring: Dictionary = kit.behaviour["ring"]
	_fall = float(arrival["fall_ms"]) / 1000.0
	_sprout = float(arrival["sprout_ms"]) / 1000.0
	_idle = float(cycle["idle_ms"]) / 1000.0
	_swell = float(cycle["swell_ms"]) / 1000.0
	_puff = float(cycle["puff_ms"]) / 1000.0
	_spores = int(ring["spores"])
	_speed = float(ring["speed_px_s"])
	_life = float(ring["life_s"])
	_turn = deg_to_rad(float(ring["alternate_rotation_deg"]))
	_spawn_r = float(ring["spawn_radius_px"])
	_spore_r = float(ring["spore_hit_radius_px"])
	var ms: PackedFloat32Array = kit.clip("sprout", "front")["ms"]
	_safe = 0.0
	for i in TARGETABLE_FRAME:
		_safe += ms[i] / 1000.0
	_clock = game.run_time
	play("fall")
	if _delay <= 0.0:
		_begin_fall()


func step(dt: float) -> void:
	age += dt
	var now: float = game.run_time
	var t := maxf(now - _clock, dt) # after a hit-stop the cycle catches up: fire never delays a ring
	_clock = now
	_cycle += t
	state_t += t
	advance(t)
	match state:
		State.WAIT:
			if state_t >= _delay:
				state_t -= _delay
				_begin_fall()
		State.FALL:
			if still() and frame() >= clip["frames"] - 2:
				game.stat("sporecap_fell_still") # the fall kept moving with ANIMATIONS sold
			if state_t >= _fall:
				_land()
		State.SPROUT:
			if state_t >= _sprout:
				_begin_swell(_sprout) # the decision: the first ring comes right after the sprout
		State.IDLE:
			if state_t >= _idle:
				_begin_swell(_idle)
			elif anim == "hurt" and done():
				play("idle")
				anim_t = fmod(state_t * 1000.0, clip["total"])
		State.SWELL:
			if state_t >= _swell:
				_begin_puff()
		State.PUFF:
			if state_t >= _puff:
				_begin_idle()


func aimable() -> bool:
	if dead or state <= State.FALL:
		return false
	return state != State.SPROUT or state_t >= _safe


## Waiting and falling it draws over the props (the seed comes down from the sky).
func flyer() -> bool:
	return not dead and state <= State.FALL


## Hits flash it; only an idle cap plays the hurt recoil (frame 0 is the baked flash). With ANIMATIONS sold the
## recoil would hold that white frame for 0.2 s a hit, so it flashes instead. Rooted: the push is ignored.
func hurt(_damage: int, _p: Vector2, _from: Vector2) -> void:
	_hit()
	if state == State.IDLE and not still():
		play("hurt")
		game.stat("sporecap_hurt_anim")
	else:
		flash = FLASH_TIME
		game.stat("sporecap_flash")


func die(_p: Vector2, _from: Vector2) -> void:
	_hit()
	dead = true
	flash = 0.0
	play("death")
	game.enemy_sound("sporecap_death")
	game.stat("sporecap_killed_fired" if rings > 0 else "sporecap_killed_unfired")


## The fall keeps playing with ANIMATIONS sold: it is the arrival's motion, and its growing shadow is the tell.
func frame() -> int:
	if anim != "fall" or not still():
		return super()
	var t := anim_t
	var ms: PackedFloat32Array = clip["ms"]
	for i in ms.size():
		t -= ms[i]
		if t < 0.0:
			return i
	return ms.size() - 1


## Hurt frame 0 is the baked flash (sporecap.json doesn't mark it): skipped once HIT FLASH is sold.
func is_flash_frame(f: int) -> bool:
	return (anim == "hurt" and f == 0) or super(f)


## Never mirrored: the long shadow keeps falling to the lower right when the cap faces left.
func draw_shadow(ci: CanvasItem) -> void:
	if state == State.WAIT and not dead:
		return
	var tex: Texture2D = clip["tex"].get("shadow")
	if tex == null:
		return
	var f := frame()
	if game.lv("hit_flash") > 0 and is_flash_frame(f):
		f = mini(f + 1, clip["frames"] - 1)
	var size := kit.shadow_size
	ci.draw_texture_rect_region(tex, Rect2(pos.round() - kit.shadow_anchor, size), Rect2(f * size.x, 0.0, size.x, size.y))


func draw_body(ci: CanvasItem) -> void:
	if state != State.WAIT or dead:
		super(ci)


func draw_eyes(ci: CanvasItem) -> void:
	if state != State.WAIT or dead:
		super(ci)


## Landing 70-130 px from Wick and in view, no hit while falling, the first ring right after the sprout, a ring
## every 3 s of 8 spores, cover stopping spores, a lone cap firing before it dies at early fire rate, spores
## hurting Wick (mortal with INPUT DELAY sold: otherwise the dodge bot outruns 42 px/s rings), the fall moving
## with ANIMATIONS sold, and every view, the hurt and the flash seen.
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var n := func(key: String) -> int: return int(stats.get("sporecap_" + key, 0))
	if n.call("landed") < 1:
		fails.append("no sporecap landed")
	for key: String in ["land_far", "land_fallback", "hit_falling", "first_ring_late", "period_off"]:
		if n.call(key) > 0:
			fails.append("sporecap_%s = %d" % [key, n.call(key)])
	if n.call("land_unseen") * 10 > n.call("land_near"):
		fails.append("%d of %d caps landed out of view" % [n.call("land_unseen"), n.call("land_near")])
	if n.call("rings") < 1 or n.call("first_ring_ok") < 1:
		fails.append("no ring fired (rings %d, first rings on time %d)" % [n.call("rings"), n.call("first_ring_ok")])
	if n.call("spores") != n.call("rings") * _spores:
		fails.append("%d spores in %d rings" % [n.call("spores"), n.call("rings")])
	if n.call("rings") >= 10 and n.call("period_ok") < 1:
		fails.append("never saw a second ring from one cap")
	if n.call("rings") >= 10 and n.call("spores_blocked") < 1:
		fails.append("no spore was stopped by cover")
	if n.call("rings") >= 10 and n.call("spores_expired") < 1:
		fails.append("no spore reached the end of its life")
	if not game.finale() and game.director.start_at < 60.0 and n.call("killed_unfired") > 0:
		fails.append("%d caps died before their first ring at early fire rate" % n.call("killed_unfired"))
	if not game.immortal and stats.has("sold_input_delay") and n.call("spores_hit_wick") < 1:
		fails.append("%d spores and none hurt Wick (mortal, INPUT DELAY sold)" % n.call("spores"))
	if stats.has("sold_animations") and n.call("fell_still") < 1:
		fails.append("the fall froze with ANIMATIONS sold")
	if not game.finale() and n.call("killed_fired") >= 6:
		for key in ["view_front", "view_side", "view_back", "hurt_anim", "flash"]:
			if n.call(key) < 1 and not (key == "hurt_anim" and stats.has("sold_animations")):
				fails.append("never saw sporecap_" + key)
	return fails


# --- the cycle -----------------------------------------------------------------------------------------------

func _begin_fall() -> void:
	state = State.FALL
	play("fall")
	anim_t = state_t * 1000.0
	game.enemy_sound("sporecap_land") # the 1.0 s falling whistle: it ends on the landing


func _land() -> void:
	_next(State.SPROUT, _fall)
	play("sprout")
	anim_t = state_t * 1000.0
	_face_wick()
	_landed_at = _cycle - state_t
	game.stat("sporecap_landed")


func _begin_swell(after: float) -> void:
	_next(State.SWELL, after)
	play("swell")
	anim_t = state_t * 1000.0
	game.enemy_sound("sporecap_swell")


## The puff's frame 0 releases the ring from the cap's crown (frame 0's emit, mirrored with the sprite).
func _begin_puff() -> void:
	_next(State.PUFF, _swell)
	play("puff")
	anim_t = state_t * 1000.0
	var crown := pos + KIT.vec(clip["data"][0]["emit"]) * Vector2(-1.0 if mirrored() else 1.0, 1.0)
	var turn := _turn if rings % 2 == 1 else 0.0
	for i in _spores:
		var d := Vector2.from_angle(turn + i * TAU / _spores)
		var s := SPORE.new()
		s.setup(kit, crown + d * _spawn_r, d * _speed, _life, _spore_r)
		game.add_hazard(s)
	if game.lv("particles") == 0:
		game.add_hazard(PUFF_RING.new(kit, crown))
	game.enemy_sound("sporecap_puff")
	_time_ring()
	rings += 1


func _begin_idle() -> void:
	_next(State.IDLE, _puff)
	play("idle")
	anim_t = state_t * 1000.0
	_face_wick()


## Moves on to `s`, keeping the time past the end of the state that lasted `after` seconds.
func _next(s: State, after: float) -> void:
	state = s
	state_t = maxf(state_t - after, 0.0)


## Faces Wick (sporecap.json rig.directions): front below, back above, side left/right (mirrored for left).
func _face_wick() -> void:
	var to: Vector2 = game.wick_feet() - pos
	if absf(to.y) >= absf(to.x):
		set_dir("front" if to.y > 0.0 else "back", false)
	else:
		set_dir("side", to.x < 0.0)
	game.stat("sporecap_view_" + dir)


## A hit freezes it (hit-stop); step() catches the cycle up afterwards.
func _hit() -> void:
	if state <= State.FALL:
		game.stat("sporecap_hit_falling")
	hit_stop = HIT_STOP[game.damage_tier()]


## The check's timings: the first ring sprout + swell after the landing, then one every idle + swell + puff.
func _time_ring() -> void:
	var now: float = _cycle - state_t # in cycle time, so DIFFICULTY's faster tempo keeps the periods exact
	var want := (_sprout + _swell) if rings == 0 else (_idle + _swell + _puff)
	var since := (now - _landed_at) if rings == 0 else (now - _last_ring)
	var ok := absf(since - want) <= 0.05
	if rings == 0:
		game.stat("sporecap_first_ring_ok" if ok else "sporecap_first_ring_late")
	else:
		game.stat("sporecap_period_ok" if ok else "sporecap_period_off")
	_last_ring = now
	game.stat("sporecap_rings")
	game.stat("sporecap_spores", _spores)


# --- the landing ---------------------------------------------------------------------------------------------

## A walkable spot 70-130 px from Wick's feet, in view, apart from the other caps: toward `anchor` first, then
## anywhere around Wick; a garden's later caps land around its first. INF when nothing fits (in view or not).
func _landing(anchor: Vector2, feet: Vector2, index: int, count: int) -> Vector2:
	var toward := (anchor - feet).angle() if anchor.distance_squared_to(feet) > 1.0 else randf() * TAU
	var near := GARDEN_CENTRE if count > 1 and index == 0 else land_range
	for seen in [true, false]:
		for i in LAND_TRIES:
			var p: Vector2
			if index > 0 and _garden != Vector2.INF and i < LAND_TRIES / 2:
				p = _garden + Vector2.from_angle(randf() * TAU) * randf_range(GARDEN_SPREAD.x, GARDEN_SPREAD.y)
			else:
				var a := toward + randf_range(-0.6, 0.6) if i < 6 else randf() * TAU
				p = feet + Vector2.from_angle(a) * randf_range(near.x, near.y)
			if _fits(p, feet, seen):
				return p
	return Vector2.INF


func _fits(p: Vector2, feet: Vector2, seen: bool) -> bool:
	var d := p.distance_to(feet)
	if d < land_range.x or d > land_range.y or (seen and not _in_view(p)) or not game.open(p):
		return false
	for e in game.enemies:
		if e.id == id and not e.dead and e.pos.distance_squared_to(p) < MIN_GAP * MIN_GAP:
			return false
	return true


func _in_view(p: Vector2) -> bool:
	var v: Rect2 = game.view_rect()
	return p.x >= v.position.x + VIEW_SIDE and p.x <= v.end.x - VIEW_SIDE \
		and p.y >= v.position.y + VIEW_TOP and p.y <= v.end.y - VIEW_BOTTOM
