## The Hush Owl: the dodge teacher (art/cast/enemies/owl/owl.json). It drops in out of the dark sky, circles Wick
## ~80 px out staring at him, then LOCKS (stops dead, wings thrown back in a pale V, a hoot with visible rings),
## DIVES in a straight line through where Wick stood when the lock ended and 40 px past it, and RECOVERS in a dizzy
## tumble on the ground before it climbs back to the circle. It can't be hit while high (altitude >= 16 px): the
## auto-aim skips it, shots pass under it, and a toll splash or sting that lands on it then is ignored. It can only
## be hit in the dive and the recover, and only the dive hurts Wick.
## `pos` is the ground point under the owl (its shadow); the body is drawn `altitude` px above it (frame_data).
## It draws on the flyer layer while at LOW_LAYER_ALT or higher (or over a prop or water), else y-sorted.
## Selling SOUND removes the hoot and its rings (the trade-off); the other sales in tells.sales_that_hurt are global.
extends "res://scripts/cast/enemies/enemy.gd"

enum Phase { SPAWN, CRUISE, LOCK, DIVE, RECOVER }

const RING_SQUASH := 0.7 # the circle is an ellipse, 0.7 as tall as wide (it stays on the 320x180 screen)
## px the ring's centre sits below Wick's feet: the bodies fly ~29 px up, so on screen they circle his body and an
## owl at the top of the ring stays well on screen
const RING_DROP := 20.0
const RING_JITTER := 0.1 # each owl's ring radius is RING x (1 +- this), so a parliament doesn't stack
const CRUISE_MAX := 110.0 # px/s: top speed while finding and keeping its place on the ring (Wick runs ~85)
const CRUISE_GAIN := 2.5 # 1/s: how hard it steers toward its place on the ring
const CRUISE_ACCEL := 360.0 # px/s^2
const SLOT := 16.0 # px from its place on the ring that counts as circling
const FIRST_CIRCLE := 2.2 # seconds circling before its first lock (the debut owl is seen circling first)
const CIRCLE: Vector2 = Vector2(2.2, 3.4) # seconds circling between dives (random in this range)
const LOCK_RANGE: Vector2 = Vector2(28.0, 120.0) # ground px to Wick where it may lock
const VIEW_MARGIN := 14.0 # its body centre must be this far inside the view to lock: the whole tell shows
const LOCK_STAGGER := 0.35 # seconds between two owls' locks (parliaments lock one after another)
const DIVE_LEN: Vector2 = Vector2(64.0, 200.0) # the dive's length is the range + OVERSHOOT, clamped to this
const DIVE_SLACK := 0.3 # seconds a dive may run over its time (knocks slow it) before it ends anyway
const DIVE_REACH := 12.0 # ground px from Wick's feet that the dive hurts him (owl.json: hit_radius + 5)
const RECOVER_DRIFT := 90.0 # px/s it carries into the tumble, braking at RECOVER_BRAKE
const RECOVER_BRAKE := 360.0
const PUSH_DECAY := 400.0 # px/s^2 a hit's knock fades (as the walkers' push)
const DEATH_DRIFT := 120.0 # most px/s carried into the death fall, braking at DEATH_BRAKE until it lands
const DEATH_BRAKE := 240.0
const LOW_LAYER_ALT := 10.0 # under this altitude (over open ground) it y-sorts with props and Wick (rig.y_sort)
const SHADOW_MIRROR_NUDGE := 4.0 # px: a mirrored shadow keeps its sun nudge east (rig.mirror_left)
const BODY_CENTRE := Vector2(0, -9) # the body centre above the feet (rig.hit_centre); shots aim at it
const HEAD_TOP := Vector2(0, -19) # the hoot rings' origin above the feet (effects.hoot)
const FEATHER_SPREAD := Vector2(4, 3) # px around the hit centre where a hit sheds its 1-2 feathers
const PUFF_FRAME := 1 # death frames that play owl_puff and owl_thud
const THUD_FRAME := 6
const WINGBEAT_FRAME := 4 # spawn frame that plays owl_wingbeat (the brake)
const FX_DIR := "res://art/cast/enemies/owl/"

static var _fx_tex := {} # effect name -> Texture2D (effects in owl.json), shared by every owl

var ring := 80.0 # px (behaviour.cruise.keep_distance_px), jittered per owl
var circle_speed := 48.0 # px/s along the ring (behaviour.cruise.circle_speed_px_s)
var lock_s := 0.7 # behaviour.lock.s
var dive_speed := 240.0 # px/s (behaviour.dive.speed_px_s)
var overshoot := 40.0 # px past where Wick stood (behaviour.dive.overshoot_px)
var high := 16.0 # px: at or above this altitude it can't be hit (behaviour.targetable.below_altitude_px)

var phase := Phase.SPAWN
var phase_t := 0.0 # seconds in this phase
var _vel := Vector2.ZERO
var _theta := 0.0 # its angle on the ring around Wick
var _spin := 1.0 # +1 clockwise, -1 counter-clockwise
var _last_target := Vector2.INF
var _circle_for := FIRST_CIRCLE # seconds to circle before the next lock
var _dive_from := Vector2.ZERO
var _dive_dir := Vector2.RIGHT
var _dive_len := 120.0
var _dive_done := 0.0 # px of the dive flown
var _dive_aim := Vector2.ZERO # Wick's feet when the lock ended
var _death_alt := 0.0 # its altitude when it died (the fall scales the death's altitudes by it)
var _on_ground := true # its ground point is open walkable ground (else it draws over the props: flyer layer)
var _hoot_ms := -1.0 # ms into the hoot rings; < 0 = none
var _feathers: Array[Dictionary] = [] # shed on hits: {"p": world px, "ms": age, "row": 0 stone / 1 ice}


func setup() -> void:
	var b: Dictionary = kit.behaviour
	ring = float(b.get("cruise", {}).get("keep_distance_px", ring)) * randf_range(1.0 - RING_JITTER, 1.0 + RING_JITTER)
	circle_speed = float(b.get("cruise", {}).get("circle_speed_px_s", circle_speed))
	lock_s = float(b.get("lock", {}).get("s", lock_s))
	dive_speed = float(b.get("dive", {}).get("speed_px_s", dive_speed))
	overshoot = float(b.get("dive", {}).get("overshoot_px", overshoot))
	high = float(b.get("targetable", {}).get("below_altitude_px", high))
	xp = int(b.get("xp", -1))
	_spin = 1.0 if randf() < 0.5 else -1.0
	if _fx_tex.is_empty():
		for fx: String in kit.data["effects"]:
			_fx_tex[fx] = load(FX_DIR + str(kit.data["effects"][fx]["file"]))
	look = kit.pick_look()
	play("spawn")
	set_dir("front", false)
	_on_ground = game.open(pos)
	_enter(Phase.SPAWN)


func step(dt: float) -> void:
	age += dt
	phase_t += dt
	_step_feathers(dt)
	match phase:
		Phase.SPAWN:
			var t0 := anim_t
			advance(dt)
			if _crossed(t0, WINGBEAT_FRAME):
				game.enemy_sound("owl_wingbeat")
			if done():
				_cruise()
		Phase.CRUISE:
			_step_cruise(dt)
		Phase.LOCK:
			_step_lock(dt)
		Phase.DIVE:
			_step_dive(dt)
		Phase.RECOVER:
			advance(dt)
			_vel = _vel.move_toward(Vector2.ZERO, RECOVER_BRAKE * dt)
			walk((_vel + push) * dt, true)
			push = push.move_toward(Vector2.ZERO, PUSH_DECAY * dt)
			if done():
				game.stat("owl_recovers")
				_cruise()
	if _hoot_ms >= 0.0:
		_hoot_ms += dt * 1000.0
		if _hoot_ms >= _fx_total("hoot"):
			_hoot_ms = -1.0
	_on_ground = game.open(pos)
	if game.finale():
		game.stat("owl_in_finale")


func step_dead(dt: float) -> void:
	_step_feathers(dt)
	var t0 := anim_t
	advance(dt)
	if _crossed(t0, PUFF_FRAME):
		game.enemy_sound("owl_puff")
	if _crossed(t0, THUD_FRAME):
		game.enemy_sound("owl_thud")
	if anim_t < _start_of(THUD_FRAME): # it drifts on as it falls, and lies still once it lands
		walk((_vel + push) * dt, true)
		_vel = _vel.move_toward(Vector2.ZERO, DEATH_BRAKE * dt)
		push = push.move_toward(Vector2.ZERO, PUSH_DECAY * dt)
	_on_ground = game.open(pos)
	if done():
		gone = true


## Only low (dive and recover): frame_data.targetable and under `high`.
func aimable() -> bool:
	return not dead and bool(_motion("targetable", false)) and altitude() < high


## The body centre: BODY_CENTRE above the feet, which fly `altitude` above the ground point.
func centre() -> Vector2:
	return pos + BODY_CENTRE - Vector2(0.0, altitude())


## A shot through its body while it is high passes under it.
func shot_hits(p: Vector2) -> bool:
	var r := reach() + 1.0
	if p.distance_squared_to(centre()) > r * r:
		return false
	if not aimable():
		game.stat("owl_shot_under")
		return false
	return true


## A toll splash or a sting that lands after it climbed out of reach passes under it (they were aimed while it
## was low). No block animation: nothing touched it.
func blocks(_from: Vector2) -> bool:
	return not dead and not aimable()


func on_block(_at: Vector2, _from: Vector2) -> void:
	game.stat("owl_passed_under")


## Low hits (the only kind under the targetable rule) flash it, knock it and shed feathers; the dive or tumble goes
## on. The `hurt` animation is drawn at cruise height, so it plays only for a hit while cruising (never, unless
## the rule is relaxed).
func hurt(_damage: int, p: Vector2, _from: Vector2) -> void:
	flash = FLASH_TIME
	hit_stop = HIT_STOP[game.damage_tier()]
	push = p
	game.enemy_sound("owl_squawk")
	game.stat("owl_hit_" + _phase_name())
	if altitude() >= high:
		game.stat("owl_hit_high")
	if phase == Phase.CRUISE:
		play("hurt")
	_shed_feathers()


func die(p: Vector2, _from: Vector2) -> void:
	game.stat("owl_kill_" + _phase_name())
	if altitude() >= high:
		game.stat("owl_hit_high")
	_death_alt = altitude()
	var carry := _dive_dir * dive_speed if phase == Phase.DIVE else _vel
	_vel = carry.limit_length(DEATH_DRIFT)
	dead = true
	flash = 0.0
	hit_stop = HIT_STOP[game.damage_tier()]
	push = p
	_hoot_ms = -1.0
	play("death")


## Only the dive hurts Wick: its ground point passing within DIVE_REACH of his feet (its shadow over his).
func touches(_body: Vector2, _radius: float) -> bool:
	return phase == Phase.DIVE and not dead and pos.distance_squared_to(game.wick_feet()) < DIVE_REACH * DIVE_REACH


func flyer() -> bool:
	return altitude() >= LOW_LAYER_ALT or not _on_ground


## It never takes part in the walkers' crowd push.
func solid() -> bool:
	return false


func draw_shadow(ci: CanvasItem) -> void:
	draw_layer(ci, "shadow", pos + Vector2(SHADOW_MIRROR_NUDGE if mirrored() else 0.0, 0.0))


func draw_body(ci: CanvasItem) -> void:
	var at := _body_at()
	if phase == Phase.DIVE and not dead:
		_draw_smear(ci)
	var flashed: bool = flash > 0.0 and game.lv("hit_flash") == 0 and clip["tex"].has("flash")
	draw_layer(ci, "flash" if flashed else "body", at)
	if _hoot_ms >= 0.0 and game.lv("sound") == 0:
		_draw_fx(ci, "hoot", 0, _fx_frame("hoot", _hoot_ms), at + HEAD_TOP)
		game.stat("owl_hoot_rings_drawn")
	for f in _feathers:
		_draw_fx(ci, "feather", f["row"], _fx_frame("feather", f["ms"]), f["p"])
	game.stat("owl_drawn_" + ("above" if flyer() else "sorted"))
	if flashed:
		game.stat("owl_flash_drawn")


func draw_eyes(ci: CanvasItem) -> void:
	draw_layer(ci, "eyes", _body_at())
	game.stat("owl_eyes_drawn_" + str(clip["dir"]))


## The body's altitude above its ground point (the death's frames assume a fall from cruise: scaled to its own).
func altitude() -> float:
	if anim == "death":
		return roundf(_death_alt * float(_motion("fall", 0.0)))
	return float(_motion("altitude", 0.0))


## A frame_data value that moves the owl (altitude, fall, targetable). With ANIMATIONS sold the pose holds frame 0,
## but a one-shot's drop, dive and fall still play out by time (movement goes on); loops hold frame 0.
func _motion(key: String, default: Variant) -> Variant:
	var f := frame()
	if still() and not clip["loop"]:
		var t := anim_t
		var ms: PackedFloat32Array = clip["ms"]
		f = ms.size() - 1
		for i in ms.size():
			t -= ms[i]
			if t < 0.0:
				f = i
				break
	return clip["data"][f].get(key, default)


func play(name: String) -> void:
	super(name)
	game.stat("owl_seen_%s_%s" % [anim, clip["dir"]])


func set_dir(d: String, mirrored: bool) -> void:
	var was: String = clip["dir"]
	super(d, mirrored)
	if clip["dir"] != was:
		game.stat("owl_seen_%s_%s" % [anim, clip["dir"]])


# --- phases --------------------------------------------------------------------------------------------------

func _enter(p: Phase) -> void:
	phase = p
	phase_t = 0.0


## Back to circling: the glide loop at a random point (owls never flap in step), its angle on the ring from where
## it is now.
func _cruise() -> void:
	_enter(Phase.CRUISE)
	if anim != "spawn": # the first circle after the drop-in is FIRST_CIRCLE
		_circle_for = randf_range(CIRCLE.x, CIRCLE.y)
	play("fly")
	anim_t = randf() * clip["total"]
	var rel: Vector2 = pos - game.wick_feet() - Vector2(0.0, RING_DROP)
	_theta = atan2(rel.y / RING_SQUASH, rel.x)
	_last_target = Vector2.INF


func _step_cruise(dt: float) -> void:
	advance(dt)
	if anim == "hurt" and done():
		play("fly")
	var w: Vector2 = game.wick_feet()
	_theta += _spin * circle_speed / ring * dt
	var target := w + Vector2(cos(_theta) * ring, RING_DROP + sin(_theta) * ring * RING_SQUASH)
	var lead := Vector2.ZERO if _last_target == Vector2.INF or dt <= 0.0 else (target - _last_target) / dt
	_last_target = target
	var want := (lead + (target - pos) * CRUISE_GAIN).limit_length(CRUISE_MAX)
	_vel = _vel.move_toward(want, CRUISE_ACCEL * dt)
	walk(_vel * dt, true)
	face(w - pos, dt) # it keeps its face on its prey
	if phase_t >= _circle_for and pos.distance_to(target) < SLOT and _may_lock(w):
		_lock()


## In range, its body well inside the view, and no other owl locked in the last LOCK_STAGGER seconds.
func _may_lock(w: Vector2) -> bool:
	var d := pos.distance_to(w)
	if d < LOCK_RANGE.x or d > LOCK_RANGE.y:
		return false
	if not game.view_rect().grow(-VIEW_MARGIN).has_point(centre()):
		return false
	for e in game.enemies:
		if e != self and e.get_script() == get_script() and e.phase == Phase.LOCK and e.phase_t < LOCK_STAGGER:
			return false
	return true


## LOCK: it stops dead and rears (frame 0 is the whole tell), hoots, and keeps staring at Wick.
func _lock() -> void:
	for e in game.enemies:
		if e != self and e.get_script() == get_script() and e.phase == Phase.LOCK and e.phase_t < LOCK_STAGGER - 0.01:
			game.stat("owl_lock_clash")
	_enter(Phase.LOCK)
	_vel = Vector2.ZERO
	push = Vector2.ZERO # a shove taken while circling (Wick hurt nearby) would bend the telegraphed dive
	play("lock")
	_set_view(game.wick_feet() - pos)
	_hoot_ms = 0.0
	game.enemy_sound("owl_hoot")
	game.stat("owl_locks")


func _step_lock(dt: float) -> void:
	advance(dt)
	face(game.wick_feet() - pos, dt)
	if frame() > 0:
		game.stat("owl_lock_late_frames")
	if phase_t >= lock_s:
		_dive()


## DIVE: a straight line through Wick's feet as the lock ends, OVERSHOOT px past them.
func _dive() -> void:
	_enter(Phase.DIVE)
	_dive_aim = game.wick_feet()
	var to := _dive_aim - pos
	if to.length() > 1.0:
		_dive_dir = to.normalized()
	else:
		_dive_dir = _view_vector()
	_dive_len = clampf(to.length() + overshoot, DIVE_LEN.x, DIVE_LEN.y)
	_dive_from = pos
	_dive_done = 0.0
	play("dive")
	_set_view(_dive_dir)
	game.enemy_sound("owl_whoosh")
	game.stat("owl_dives")


## Frames by progress (frame = floor(6 x distance flown along the line / length)). Ends at its length, or early at
## the rim.
func _step_dive(dt: float) -> void:
	var stride := dive_speed * dt
	var before := pos
	walk(_dive_dir * stride + push * dt, true)
	push = push.move_toward(Vector2.ZERO, PUSH_DECAY * dt)
	_dive_done = maxf(_dive_done, (pos - _dive_from).dot(_dive_dir)) # a knock slows it; it still flies the line
	anim_t = clip["total"] * minf(_dive_done / _dive_len, 0.999)
	var cut: bool = not game.open(before + _dive_dir * stride, 0) # the line leaves the island: it pulls up at the rim
	if _dive_done >= _dive_len or cut or phase_t > _dive_len / dive_speed + DIVE_SLACK:
		var past := (pos - _dive_aim).dot(_dive_dir)
		if cut:
			game.stat("owl_dive_cut")
		elif past >= overshoot - 4.0 or _dive_len >= DIVE_LEN.y:
			game.stat("owl_overshoot_ok")
		else:
			game.stat("owl_overshoot_short")
		_recover()


## RECOVER: it carries a little speed into the tumble, brakes, shakes its head and climbs (the window to shoot).
func _recover() -> void:
	_enter(Phase.RECOVER)
	_vel = _dive_dir * RECOVER_DRIFT
	play("recover")
	_set_view(_dive_dir)
	game.enemy_sound("owl_ruffle")


# --- helpers -------------------------------------------------------------------------------------------------

## Side, front or back for a vector, now (no hold): side when |x| > SIDE_RATIO |y|.
func _set_view(v: Vector2) -> void:
	if absf(v.x) > SIDE_RATIO * absf(v.y):
		set_dir("side", v.x < 0.0)
	else:
		set_dir("front" if v.y > 0.0 else "back", flip)


## The way it faces as a vector (a dive with no line: Wick under it).
func _view_vector() -> Vector2:
	match dir:
		"side":
			return Vector2.LEFT if flip else Vector2.RIGHT
		"back":
			return Vector2.UP
	return Vector2.DOWN


func _body_at() -> Vector2:
	return pos - Vector2(0.0, altitude())


func _phase_name() -> String:
	return Phase.keys()[phase].to_lower()


## Milliseconds into the current clip where frame `f` starts.
func _start_of(f: int) -> float:
	var t := 0.0
	for i in mini(f, clip["frames"]):
		t += clip["ms"][i]
	return t


## The clip's time passed the start of frame `f` since `t0` (by time, so sounds play with ANIMATIONS sold too).
func _crossed(t0: float, f: int) -> bool:
	var s := _start_of(f)
	return t0 < s and anim_t >= s


## The smear ghosts behind the dive, under the body: row = the dive's direction in 22.5 degree steps, frame = the
## dive's frame.
func _draw_smear(ci: CanvasItem) -> void:
	var rows: int = kit.data["effects"]["dive_smear"]["rows"]
	var row := posmod(roundi(_dive_dir.angle() / TAU * rows), rows)
	_draw_fx(ci, "dive_smear", row, frame(), centre())


func _draw_fx(ci: CanvasItem, fx: String, row: int, f: int, at: Vector2) -> void:
	var e: Dictionary = kit.data["effects"][fx]
	var size := KIT.vec(e["frame_size"])
	var origin := KIT.vec(e["origin"])
	ci.draw_texture_rect_region(_fx_tex[fx], Rect2((at - origin).round(), size),
		Rect2(Vector2(f * size.x, row * size.y), size))


func _fx_total(fx: String) -> float:
	var t := 0.0
	for ms: float in kit.data["effects"][fx]["ms"]:
		t += ms
	return t


## The effect's frame at `ms` (ANIMATIONS sold: frame 0 until it ends).
func _fx_frame(fx: String, ms: float) -> int:
	if still():
		return 0
	var e: Dictionary = kit.data["effects"][fx]
	var i := 0
	for d: float in e["ms"]:
		ms -= d
		if ms < 0.0:
			return i
		i += 1
	return i - 1


## 1-2 feathers shed where it was hit (none once PARTICLES is sold).
func _shed_feathers() -> void:
	if game.lv("particles") > 0:
		return
	for i in randi_range(1, 2):
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FEATHER_SPREAD
		_feathers.append({"p": centre() + off, "ms": 0.0, "row": randi() % 2})
	game.stat("owl_feathers")


func _step_feathers(dt: float) -> void:
	if _feathers.is_empty():
		return
	if game.lv("particles") > 0:
		_feathers.clear()
		return
	var total := _fx_total("feather")
	for f in _feathers:
		f["ms"] += dt * 1000.0
	_feathers.assign(_feathers.filter(func(f: Dictionary) -> bool: return f["ms"] < total))


## The mechanic, headless (tests/enemy_check.gd): never hit high, locks lead to dives that overshoot, the recover
## can be hit, owls never lock together, every animation and view played, and each sale costs what it should.
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var n := func(k: String) -> int: return int(stats.get(k, 0))
	if n.call("owl_hit_high") > 0:
		fails.append("hit %d times while high" % n.call("owl_hit_high"))
	if n.call("owl_dives") < 2:
		fails.append("only %d dives" % n.call("owl_dives"))
	if n.call("owl_locks") < n.call("owl_dives"):
		fails.append("a dive without a lock")
	if n.call("owl_overshoot_short") > 0:
		fails.append("%d dives stopped short of the overshoot" % n.call("owl_overshoot_short"))
	if n.call("owl_overshoot_ok") < 1:
		fails.append("no dive overshot where Wick stood")
	if n.call("owl_hit_dive") + n.call("owl_kill_dive") + n.call("owl_hit_recover") + n.call("owl_kill_recover") < 1:
		fails.append("never hit low")
	if n.call("owl_hit_recover") + n.call("owl_kill_recover") < 1:
		fails.append("never hit in the recover")
	var finale: bool = n.call("owl_in_finale") > 0
	if n.call("owl_recovers") < 1 and not finale: # the finale's damage kills every owl low
		fails.append("never climbed back from a recover")
	if n.call("owl_lock_clash") > 0:
		fails.append("%d locks within LOCK_STAGGER of another owl's" % n.call("owl_lock_clash"))
	for v in ["side", "front", "back"]:
		if n.call("owl_seen_fly_" + v) < 1:
			fails.append("never circled in the %s view" % v)
	for a in ["spawn", "lock", "dive", "recover", "death"]:
		if a == "death" and n.call("killed_owl") < 1:
			continue # a crowd run may kill none (the shared check allows it)
		var seen := false
		for k: String in stats:
			seen = seen or k.begins_with("owl_seen_%s_" % a)
		if not seen:
			fails.append("never played " + a)
	var sold_anims := stats.has("sold_animations")
	if sold_anims and n.call("owl_lock_late_frames") > 0:
		fails.append("the lock moved past frame 0 with ANIMATIONS sold")
	elif not sold_anims and n.call("owl_lock_late_frames") < 1:
		fails.append("the lock never moved past frame 0")
	var drawn: int = n.call("owl_drawn_above") + n.call("owl_drawn_sorted")
	if drawn > 0: # drawing runs (it does headless too); check what the sales hide
		if n.call("owl_drawn_above") < 1 or n.call("owl_drawn_sorted") < 1:
			fails.append("never drawn on both layers (above %d, sorted %d)" % [
				n.call("owl_drawn_above"), n.call("owl_drawn_sorted")])
		if stats.has("sold_sound") and n.call("owl_hoot_rings_drawn") > 0:
			fails.append("hoot rings drawn with SOUND sold")
		elif not stats.has("sold_sound") and n.call("owl_hoot_rings_drawn") < 1:
			fails.append("hoot rings never drawn")
		if stats.has("sold_hit_flash") and n.call("owl_flash_drawn") > 0:
			fails.append("flashed with HIT FLASH sold")
		elif not stats.has("sold_hit_flash") and n.call("hits") > 0 and n.call("owl_flash_drawn") < 1:
			fails.append("hits never flashed")
		var eyes: int = n.call("owl_eyes_drawn_front") + n.call("owl_eyes_drawn_side") + n.call("owl_eyes_drawn_back")
		if finale and eyes < 1:
			fails.append("no eyes drawn in the finale")
		elif not finale and eyes > 0:
			fails.append("eyes drawn outside the finale")
	if stats.has("sold_particles") and n.call("owl_feathers") > 0:
		fails.append("shed feathers with PARTICLES sold")
	return fails
