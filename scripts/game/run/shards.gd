extends RefCounted
## Light shards (design 7): every kill pops shards that hover, then the lantern drinks them one by one, each landing
## on the 16th-note slot shard_audio reserves for it. Their light goes to progression. All times are world seconds
## on the shards' own clock (`now`), which stops while the world is frozen (freeze/thaw re-reserve the slots).

enum State { POP, HOVER, PULL }

const SMALL := 0
const MEDIUM := 1
const LARGE := 2
const STAR := 3

# Pop (7.2.1): out at i/n x TAU (+-jitter), easing out to a rest point 7-10 px away.
const POP_TIME := 0.16
const POP_SPEED := 70.0
const POP_SPEED_JITTER := 15.0
const POP_UP := -20.0 ## px/s added upwards
const POP_ANGLE_JITTER := 0.35
const POP_REACH := 0.7 ## share of speed x POP_TIME travelled under the quadratic ease-out
# Hover (7.2.2)
const HOVER_MIN := 0.05
const BOB_HZ := 6.0
# Pull (7.2.3): D = clamp(distance / PULL_SPEED, PULL_MIN, PULL_MAX), progress u^2 along a bowed Bezier.
const PULL_SPEED := 300.0
const PULL_MIN := 0.22
const PULL_MAX := 0.45
const BOW := 0.3
const TRAIL_LAG: Array[float] = [0.02, 0.04, 0.06] ## the 1 px tail: where the shard was this long ago
# Queue cap (7.2): past this many shards in flight a new one merges into the newest waiting one.
const QUEUE_CAP := 16
# Tutorial's first shard (design 12 T3)
const SLOW_HOVER := 0.2
# Gauge (7.3)
const LADDER := 14 ## chime degrees above the bottom D5
const STAR_STEP := 0.052 ## a 32nd at 144 BPM: the magpie star's run up the ladder
const BEAT := 60.0 / 144.0
const PULSE_FILL := 0.8 ## from this fill the lantern pulses on every beat

## Design 7.1, used only when the director has no drops for a kind: [[count, light], ...].
const FALLBACK_DROPS := {
	"snuffer": [[1, 1.0]], "owl": [[3, 1.0]], "toad": [[3, 3.0]], "sporecap": [[3, 2.0]], "gloam": [[3, 1.5]],
}
const SNUFFER_LATE := 30.0 ## clock seconds from which a Snuffer's shard is worth 2
const SNUFFER_LATE_DROPS := [[1, 2.0]]


class Shard:
	extends RefCounted
	var pos := Vector2.ZERO ## where it draws (world)
	var light := 1.0
	var size := 0 ## SMALL, MEDIUM, LARGE (STAR is the magpie's, drawn by the magpie)
	var state := 0 ## State
	var t := 0.0 ## seconds since it popped
	var slot := 0.0 ## arrival time on the shards' clock (a 16th slot)
	var index := 0 ## place in its kill: even bows one way, odd the other
	var origin := Vector2.ZERO ## the kill point
	var rest := Vector2.ZERO ## where the pop ends and the pull starts
	var pull_time := PULL_MIN ## D
	var hover_min := HOVER_MIN
	var lead := false ## first shard of its kill: plays the pull sound
	var trail := PackedVector2Array() ## the tail during the pull (20/40/60 ms ago)


var run ## the Run (run.gd), duck-typed
var list: Array = [] ## live shards (Shard), oldest first, for drawing
var cosmetic := false ## closing: shards still fly and chime but add no light
var now := 0.0 ## the shards' clock (world seconds since reset)
var dropped := 0.0 ## light dropped this run (checks)
var landed := 0.0 ## light landed this run (checks)
var merges := 0 ## shards merged by the queue cap (checks)

var _frozen := false
var _slow := 0.0 ## > 0: the next shard's pull takes this long (tutorial)
var _stars := 0 ## magpie stars waiting for their run up the ladder
var _star_left := 0 ## ticks left in the current star run
var _star_t := 0.0
var _beat := -1
var _rng := RandomNumberGenerator.new()


## Keeps the back-reference to the run.
func setup(r) -> void:
	run = r


## Removes every shard and star run; the clock restarts (new run, or DISPLAY: OFF).
func reset() -> void:
	list.clear()
	cosmetic = false
	now = 0.0
	dropped = 0.0
	landed = 0.0
	merges = 0
	_frozen = false
	_slow = 0.0
	_stars = 0
	_star_left = 0
	_star_t = 0.0
	_beat = -1
	_rng.randomize()
	if run != null and run.shard_audio != null:
		run.shard_audio.release_all()


## Seeds the pop jitter (checks and seeded runs).
func set_seed(s: int) -> void:
	_rng.seed = s


## Drops the shards a kill of kind `id` gives (director.drops) at `pos` (the enemy's centre).
func drop(pos: Vector2, id: String) -> void:
	var table := _drops(id)
	var n := 0
	for entry: Array in table:
		n += int(entry[0])
	if n == 0:
		return
	run.shard_audio.pop()
	run.shard_fx.pop(pos)
	var i := 0
	for entry: Array in table:
		for k in int(entry[0]):
			_add(pos, float(entry[1]), i, n)
			i += 1


## The magpie's star reached the lantern at `pos`: the gauge runs up the ladder in 32nds and fills (one level-up).
func star(pos: Vector2) -> void:
	if cosmetic:
		return
	run.shard_fx.drink(pos, true)
	_stars += 1


## Tutorial: the next shard hangs SLOW_HOVER, then its pull takes `secs`.
func slow_next_pull(secs: float) -> void:
	_slow = secs


## Moves shards; on arrival: shard_audio.arrive, shard_fx.drink, prog.add_light, run.shard_landed.
func step(dt: float) -> void:
	if _frozen:
		return
	now += dt
	if run.has_method("lv"):
		run.shard_fx.still = run.lv("animations") > 0
	_step_star(dt)
	var arrived: Array = []
	for s: Shard in list:
		s.t += dt
		_move(s)
		if s.state == State.PULL and now + dt * 0.5 >= s.slot:
			arrived.append(s)
	for s: Shard in arrived:
		list.erase(s)
		_arrive(s)
	_pulse()


## Menus and pause: hold every shard and release its arrival slot.
func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	run.shard_audio.release_all()


## After a menu: re-reserve arrival slots on the music's current grid, in the old order, and carry on.
func thaw() -> void:
	if not _frozen:
		return
	_frozen = false
	var order := list.duplicate()
	order.sort_custom(func(a: Shard, b: Shard) -> bool: return a.slot < b.slot)
	var after := now # each slot after the one before keeps the drinking order
	for s: Shard in order:
		if s.state == State.PULL:
			_retime_pull(s, after)
		else:
			var left := maxf(POP_TIME + s.hover_min - s.t, 0.0)
			s.slot = run.shard_audio.reserve(maxf(now + left + s.pull_time, after + 0.001), now)
		after = s.slot


## Shards not yet arrived.
func in_flight() -> int:
	return list.size()


## Magpie stars that reached the lantern but have not filled the gauge yet (queued or running up the ladder).
func stars_pending() -> int:
	return _stars + (1 if _star_left > 0 else 0)


## Draws every shard through shard_fx at `pos - origin`.
func draw(ci: CanvasItem, origin := Vector2.ZERO) -> void:
	for s: Shard in list:
		var trail := s.trail
		if origin != Vector2.ZERO and not trail.is_empty():
			trail = PackedVector2Array()
			for p in s.trail:
				trail.append(p - origin)
		run.shard_fx.draw_shard(ci, s.pos - origin, s.size, s.t, trail)


## Size class for a shard of `light` (7.1: small <= 1, medium <= 2, large >= 3).
static func size_for(v: float) -> int:
	if v <= 1.0:
		return SMALL
	if v < 3.0:
		return MEDIUM
	return LARGE


## Ladder degree 0..LADDER for a fill (design 7.4).
static func degree(f: float) -> int:
	return clampi(ceili(f * LADDER - 0.000001), 0, LADDER)


func _drops(id: String) -> Array:
	var table: Array = []
	if run.director != null:
		table = run.director.drops(id)
	if not table.is_empty() or not FALLBACK_DROPS.has(id):
		return table
	if id == "snuffer" and run.clock() >= SNUFFER_LATE:
		return SNUFFER_LATE_DROPS
	return FALLBACK_DROPS[id]


func _add(pos: Vector2, v: float, i: int, n: int) -> void:
	dropped += v
	var waiting := _newest_waiting()
	if list.size() >= QUEUE_CAP and waiting != null:
		waiting.light += v
		waiting.size = maxi(waiting.size, size_for(waiting.light))
		merges += 1
		run.shard_fx.merge(waiting.pos)
		return
	var s := Shard.new()
	s.light = v
	s.size = size_for(v)
	s.index = i
	s.lead = i == 0
	s.origin = pos
	s.pos = pos
	var angle := float(i) / float(n) * TAU + _rng.randf_range(-POP_ANGLE_JITTER, POP_ANGLE_JITTER)
	var speed := POP_SPEED + _rng.randf_range(-POP_SPEED_JITTER, POP_SPEED_JITTER)
	s.rest = pos + (Vector2.from_angle(angle) * speed + Vector2(0.0, POP_UP)) * POP_TIME * POP_REACH
	s.pull_time = clampf(s.rest.distance_to(run.lantern()) / PULL_SPEED, PULL_MIN, PULL_MAX)
	if _slow > 0.0:
		s.hover_min = SLOW_HOVER
		s.pull_time = _slow
		_slow = 0.0
	s.slot = run.shard_audio.reserve(now + POP_TIME + s.hover_min + s.pull_time, now)
	list.append(s)


## The newest shard that has not started its pull (merges go there), or null.
func _newest_waiting() -> Shard:
	for k in range(list.size() - 1, -1, -1):
		var s: Shard = list[k]
		if s.state != State.PULL:
			return s
	return null


func _move(s: Shard) -> void:
	if s.state == State.POP:
		if s.t < POP_TIME:
			var u := s.t / POP_TIME
			s.pos = s.origin.lerp(s.rest, 1.0 - (1.0 - u) * (1.0 - u))
			return
		s.state = State.HOVER
	if s.state == State.HOVER:
		if now < s.slot - s.pull_time:
			s.pos = s.rest + Vector2(0.0, -1.0 if sin(TAU * BOB_HZ * s.t) > 0.0 else 0.0)
			return
		s.state = State.PULL
		if s.lead:
			run.shard_audio.pull(s.slot - now)
	var emit: Vector2 = run.lantern()
	var start := s.slot - s.pull_time
	s.pos = _path(s, emit, (now - start) / s.pull_time)
	var trail := PackedVector2Array()
	for lag in TRAIL_LAG:
		trail.append(_path(s, emit, (now - lag - start) / s.pull_time))
	s.trail = trail


## Where a pulling shard is at progress `u` (0 = rest point, 1 = the lantern): eased u^2 on a bowed Bezier.
func _path(s: Shard, emit: Vector2, u: float) -> Vector2:
	var e := clampf(u, 0.0, 1.0)
	e *= e
	var chord := emit - s.rest
	var side := 1.0 if s.index % 2 == 0 else -1.0
	var ctrl := (s.rest + emit) * 0.5 + chord.orthogonal().normalized() * BOW * chord.length() * side
	var w := 1.0 - e
	return s.rest * (w * w) + ctrl * (2.0 * w * e) + emit * (e * e)


## After a freeze: a new slot for a shard mid-pull, keeping its progress so it doesn't jump.
func _retime_pull(s: Shard, after: float) -> void:
	var left := maxf(s.slot - now, 0.0)
	var slot: float = run.shard_audio.reserve(maxf(now + left, after + 0.001), now)
	if left > 0.001:
		s.pull_time = (slot - now) * s.pull_time / left
	else:
		s.pull_time = maxf(slot - now, 0.001)
	s.slot = slot


func _arrive(s: Shard) -> void:
	var emit: Vector2 = run.lantern()
	var big := s.size >= LARGE
	var f: float = run.prog.fill() if cosmetic else run.prog.fill_after(s.light)
	run.shard_audio.arrive(f, big)
	run.shard_fx.drink(emit, big)
	landed += s.light
	if cosmetic:
		run.shard_landed.emit(0.0, run.prog.fill())
		return
	var ups: int = run.prog.add_light(s.light)
	run.shard_landed.emit(s.light, run.prog.fill())
	if ups > 0:
		_full(emit)


func _full(emit: Vector2) -> void:
	run.shard_audio.full()
	run.shard_fx.full(emit)
	run.gauge_full.emit()


## The magpie star's run: the rest of the ladder in 32nds (the first note at once); the last one fills the gauge.
func _step_star(dt: float) -> void:
	if cosmetic: # CONFIRM SALES sold mid-run: a star on its way fills nothing, so no full chime in the finale
		_stars = 0
		_star_left = 0
		return
	if _star_left == 0:
		if _stars == 0:
			return
		_stars -= 1
		var from: float = run.prog.light_fill()
		_star_left = maxi(LADDER - degree(from), 1)
		_star_t = STAR_STEP
		run.shard_audio.star_run(from)
	else:
		_star_t += dt
	while _star_left > 0 and _star_t >= STAR_STEP - 0.0001:
		_star_t -= STAR_STEP
		var add: float = (run.prog.need - run.prog.light) / float(_star_left)
		_star_left -= 1
		if run.prog.add_light(add) > 0:
			_full(run.lantern())


## From PULSE_FILL the lantern pulses on every quarter beat of the music (or of the shards' clock).
func _pulse() -> void:
	var clock := -1.0
	if run.get("fx") != null:
		clock = run.fx.music_clock()
	if clock < 0.0:
		clock = now
	var b := floori(clock / BEAT)
	if b != _beat and _beat >= 0 and run.prog.fill() >= PULSE_FILL:
		run.shard_fx.ready_pulse(run.lantern())
	_beat = b
