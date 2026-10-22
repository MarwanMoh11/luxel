## When and what spawns on the island (docs/art_concepts/lastlight/cast/ENEMY_BRIEF.md, Pacing; GAME_DESIGN.md 8).
## Moved from scripts/proto/low_settings/enemy_director.gd for beta v1, tables kept. The steady rate is a curve
## (SPAWN_BASE/LINEAR/SQUARE, SPAWN_MAX) x RATE under ENEMY_CAP; every spawn picks a kind by ROSTER share among
## the kinds that have debuted, and EVENTS add the scripted debuts and repeats on top. Each brain decides where it
## arrives (enemy.gd arrive); this decides when, how many and the group's anchor.
## Teaching: each debut (EVENTS `quiet`) and each formation thins the steady spawns around it, so the newcomer
## reads alone; a formation is announced FORMATION_QUIET[0] s ahead (the `formation` sound, a HUD pip at its
## anchor through run.formation_coming) and the lull before it arrives.
## Beta v1 changes: kills drop light shards (ROSTER `shards`, design 7.1) instead of XP; `paused` (the tutorial);
## FINALE_RATE and "no magpie" start at CONFIRM SALES (run.closing()); debuts go out through run.debut.
## The finale's tide (P8, design 10.1): set_tide(name) stops the formations for good and sends a ring of
## Snuffers (every TIDE_GLOAM-th a Gloam) from just off screen on all sides every TIDES[name].every s, each ring
## `grow` bigger; steady spawns run x TIDE_RATE. Tide rings go past ENEMY_CAP but keep the field under TIDE_CAP.
## Lab mode (`-- lab=<id>`) spawns only that kind, a pack every `lab_every` s; `-- at=<s>` starts the clock at
## <s> s (shares, caps, rate, hp and drops follow the clock).
extends RefCounted

const KINDS: Array[String] = ["snuffer", "owl", "toad", "sporecap", "gloam", "magpie"] ## brain `kind` = index here
const FALLBACK := "snuffer"

const SPAWN_BASE := 0.6 # enemies per second at the start (x RATE)
const SPAWN_LINEAR := 0.4 # extra per second per minute of the clock
const SPAWN_SQUARE := 0.12 # extra per second per minute squared
const SPAWN_MAX := 8.0
const ENEMY_CAP := 130 # live enemies at most for the steady spawns (events may go past it)
const HP_SQUARE := 0.10 # enemy hp x (1 + HP_SQUARE m^2), m = the clock's minutes

## Per kind: `from` = seconds when it joins the random mix (after its debut in EVENTS), `share` = its weight
## once ramped (the Snuffer takes what the others leave), `ramp` = seconds from `from` to the full share, `cap` =
## most alive at once as [[from s, n], ...] (n < 0: no cap), `pack` = [min, max] spawned together around one
## anchor, `lab_every` = seconds between packs in lab mode, `hp` = base hp (x10 scale), `size` = body width for
## the crowd push, `shards` = [[from s, count, light each], ...] dropped per kill (design 7.1; the Magpie's
## reward is its star: a free level-up).
const ROSTER := {
	"snuffer": {"from": 0.0, "share": 1.0, "ramp": 0.0, "cap": [[0, -1]], "pack": [2, 4], "lab_every": 2.5,
		"hp": 20, "size": 12.0, "shards": [[0, 1, 1.0], [30, 1, 2.0]]},
	"owl": {"from": 75.0, "share": 0.05, "ramp": 60.0, "cap": [[0, 2]], "pack": [1, 1], "lab_every": 3.0,
		"hp": 30, "size": 14.0, "shards": [[0, 3, 1.0]]},
	"toad": {"from": 120.0, "share": 0.04, "ramp": 60.0, "cap": [[0, 2], [240, 3]], "pack": [1, 1], "lab_every": 5.0,
		"hp": 140, "size": 18.0, "shards": [[0, 3, 3.0]]},
	"sporecap": {"from": 165.0, "share": 0.06, "ramp": 60.0, "cap": [[0, 2], [200, 3], [240, 4], [270, 5]],
		"pack": [1, 1], "lab_every": 4.0, "hp": 60, "size": 16.0, "shards": [[0, 3, 2.0]]},
	"gloam": {"from": 200.0, "share": 0.06, "ramp": 60.0, "cap": [[0, 10], [300, 14]], "pack": [3, 5],
		"lab_every": 4.0, "hp": 30, "size": 12.0, "shards": [[0, 3, 1.5]]},
	"magpie": {"cap": [[0, 1]], "pack": [1, 1], "lab_every": 12.0, "hp": 80, "size": 12.0, "shards": []},
}
## Steady spawn rate factor over the clock: [[s, factor], ...], linear in between. A slow start puts the first
## sale near 0:22, then a busy first minutes; the dip keeps the field under ENEMY_CAP while the newcomers arrive;
## the climb after it makes the late run and the finale "everything at once".
const RATE: Array = [[0.0, 0.6], [24.0, 0.6], [40.0, 0.75], [120.0, 0.75], [160.0, 0.6], [250.0, 0.45],
	[290.0, 0.7], [340.0, 1.1]]
const FINALE_RATE := 1.2 # x RATE from CONFIRM SALES on (run.closing())
const GAMER_RATE := 1.5 # x RATE in GAMER MODE (run.gamer)
## Scripted spawns: at `at` s, `count` of `kind` around one anchor; `every` = [min, max] s to repeat (until
## `until` s); `finale` false = skipped once the run is closing; `quiet` = [s before, s after] its first time
## with no steady spawns (a debut). A debut always comes in full; one whose kind is at its cap tries again every
## second.
const EVENTS: Array[Dictionary] = [
	{"at": 40.0, "kind": "owl", "count": 1, "quiet": [4.0, 3.0]},
	{"at": 70.0, "kind": "magpie", "count": 1, "every": [50.0, 60.0], "finale": false, "quiet": [2.0, 2.0]},
	{"at": 90.0, "kind": "toad", "count": 1, "quiet": [6.0, 4.0]},
	{"at": 135.0, "kind": "sporecap", "count": 1, "every": [40.0, 50.0], "quiet": [6.0, 4.0]},
	{"at": 180.0, "kind": "gloam", "count": 4, "quiet": [6.0, 4.0]},
]
## Formations from 3:30: each name is a method `_formation_<name>(anchor)` here that spawns the group and returns
## how many came. The five take turns 22 s apart, so two never land together; they go on through the finale.
const FORMATION_QUIET: Array[float] = [2.5, 2.0]
const FORMATIONS: Array[Dictionary] = [
	{"at": 210.0, "every": [110.0, 110.0], "until": 480.0, "name": "snuffer_ring"},
	{"at": 232.0, "every": [110.0, 110.0], "until": 480.0, "name": "owl_parliament"},
	{"at": 254.0, "every": [110.0, 110.0], "until": 480.0, "name": "toad_line"},
	{"at": 276.0, "every": [110.0, 110.0], "until": 480.0, "name": "spore_garden"},
	{"at": 298.0, "every": [110.0, 110.0], "until": 480.0, "name": "gloam_pack"},
]
const RING := Vector2(14.0, 22.0) # Snuffers in a ring: at 3:30, and by RING_FULL s
const RING_FULL := 330.0
const RING_MARGIN := 6.0 # px past the view's half-diagonal: every ring point starts just off screen
const PARLIAMENT := 2 # owls
const TOAD_LINE := 2
const GARDEN := 2 # sporecaps
const GLOAM_PACK := 5
## The tide's stages: `every` s between rings, `count` = the first ring (absent: the count goes on), `grow` per
## ring, `near` = the ring's radius x the view's half-diagonal (1 = just off screen), `hp` = x a ring enemy's hp,
## `rate` = x the steady spawns (default TIDE_RATE), `recycle` = off-screen tide enemies leave to make room at the cap.
const TIDES := {
	"swell": {"every": 2.5, "count": 14, "grow": 6, "near": 0.65, "hp": 6.0}, # B1: the last player menu to CONFIRM
	"charge": {"every": 3.0, "grow": 6, "near": 0.75, "hp": 4.0}, # B2: in the self-sales' gaps
	# B5 after the relight: the dark wins (P8b M2): close, tough rings only, against the spent lantern
	"rest": {"every": 1.5, "count": 40, "grow": 10, "near": 0.3, "hp": 16.0, "rate": 0.0, "recycle": true},
	"stand": {"every": 3.0, "grow": 6}, # B6: AUTO-SELL
	"close": {"every": 1.5, "grow": 6, "near": 0.8}, # B6 from run.CLOSE_AT % left: closer, twice as often
}
const TIDE_RATE := 1.5 # x the steady spawns while a tide runs
const TIDE_CAP := 210 # live enemies at most after a tide ring (web performance)
const TIDE_GLOAM := 4 # every 4th of a ring is a Gloam
const ANCHOR_TRIES := 8 # edge points a debut or formation compares to arrive on the clear side
const ANCHOR_CLEAR := 70.0 # px

var run ## the Run (run.gd), duck-typed
var lab := "" ## "" = the real timeline; else the only kind spawned
var start_at := 0.0 ## the clock's start (seconds)
var paused := false ## tutorial: nothing spawns
var history: PackedStringArray = [] ## what spawned when, for the checks ("1:10 magpie x1")
var _cd := 1.0
var _next: Array[float] = [] # per EVENTS / FORMATIONS entry (events first): its next time, INF when done
var _last: Array[float] = [] # ...when it last fired (-INF: never)
var _first: Array[float] = [] # ...and when it first fired (-INF: never)
var _cued: Array[bool] = [] # a formation's cue played for its next time
var _anchor: Array[Vector2] = [] # ...and the anchor it announced
var tide := "" ## the TIDES stage running ("" = none yet; once set, the formations are over)
var tide_rings := 0 ## tide rings so far (checks)
var _tide := {} # the stage's numbers
var _tide_cd := 0.0
var _tide_n := 0 # the next ring's count


## Keeps the run and reads lab=<id> and at=<s> from the debug args.
func setup(r, args: PackedStringArray) -> void:
	run = r
	for a in args:
		if a.begins_with("lab="):
			lab = a.trim_prefix("lab=")
		elif a.begins_with("at="):
			start_at = float(a.trim_prefix("at="))
	if lab != "" and not KINDS.has(lab):
		push_warning("enemy lab: unknown kind '%s'" % lab)
		lab = ""


## Back to the start of the timeline.
func reset() -> void:
	_cd = 1.0
	paused = false
	tide = ""
	tide_rings = 0
	_tide = {}
	_tide_cd = 0.0
	_tide_n = 0
	history.clear()
	_next.clear()
	_last.clear()
	_first.clear()
	_cued.clear()
	_anchor.clear()
	for e in EVENTS + FORMATIONS:
		_next.append(float(e["at"]) if float(e["at"]) >= start_at else _first_repeat(e))
		_last.append(-INF)
		_first.append(-INF)
		_cued.append(false)
		_anchor.append(Vector2.INF)


## The director's clock in seconds (run time + start_at).
func time() -> float:
	return start_at + run.run_time


## Advances the timeline: spawns, debuts, formations (through the run's signals). World seconds.
func step(dt: float) -> void:
	if paused:
		return
	var t := time()
	if lab == "":
		if tide != "":
			_tide_cd -= dt
			if _tide_cd <= 0.0:
				_tide_cd += float(_tide["every"])
				_tide_ring()
		for i in _next.size():
			if i >= EVENTS.size() and tide != "":
				break # the tide replaced the formations
			if i >= EVENTS.size() and not _cued[i] and t >= _next[i] - FORMATION_QUIET[0]:
				_cue(i)
			if t >= _next[i]:
				_fire(i, t)
	_cd -= dt
	if _cd > 0.0:
		return
	if lab != "":
		_cd = float(ROSTER[lab]["lab_every"])
		_spawn_group(lab, _pack(lab), t, false)
		return
	if _quiet(t):
		_cd = 0.25
		return
	var m := t / 60.0
	var rate := minf(SPAWN_BASE + SPAWN_LINEAR * m + SPAWN_SQUARE * m * m, SPAWN_MAX)
	rate *= _rate(t) * (FINALE_RATE if run.closing() else 1.0) * (GAMER_RATE if run.gamer else 1.0)
	rate *= float(_tide.get("rate", TIDE_RATE)) if tide != "" else 1.0
	if rate <= 0.0: # a tide stage with no steady spawns: every enemy comes in its rings
		_cd = 0.25
		return
	var id := _pick(t)
	var n := _spawn_group(id, _pack(id), t, false)
	_cd = maxf(n, 1) / rate


## Starts tide stage `name` (TIDES), or "" for none. A stage with a `count` sends its first ring at once; one
## without goes on counting from the last ring, its next ring no later than its `every`.
func set_tide(name: String) -> void:
	if name == tide:
		return
	tide = name
	if name == "":
		return
	_tide = TIDES[name]
	if _tide.has("count"):
		_tide_n = int(_tide["count"])
		_tide_cd = 0.0
	else:
		_tide_cd = minf(_tide_cd, float(_tide["every"]))
	history.append("%s tide %s" % [_stamp(time()), name])


## One tide ring around Wick (points over the void a little further out, else skipped), capped by TIDE_CAP.
func _tide_ring() -> int:
	var room: int = TIDE_CAP - run.enemies.size()
	if bool(_tide.get("recycle", false)) and room < _tide_n:
		room += _recycle(_tide_n - room)
	var n := mini(_tide_n, room)
	_tide_n += int(_tide["grow"])
	tide_rings += 1
	if n <= 0:
		return 0
	var centre: Vector2 = run.wick_feet()
	var near := float(_tide.get("near", 1.0))
	var radius: float = run.view_rect().size.length() * 0.5 * near + (RING_MARGIN if near >= 1.0 else 0.0)
	var turn := randf() * TAU
	var came := 0
	for i in n:
		for out: float in [0.0, 24.0, 48.0]:
			var p: Vector2 = centre + Vector2.from_angle(turn + TAU * i / n) * (radius + out)
			if run.open(p):
				var e = run.spawn("gloam" if i % TIDE_GLOAM == TIDE_GLOAM - 1 else "snuffer", p, 0, 1)
				e.hp = ceili(e.hp * float(_tide.get("hp", 1.0)))
				came += 1
				break
	return came


## Up to `want` tide enemies (Snuffers, Gloams) off screen leave the field, the farthest from Wick first, so a
## ring at the cap still closes round him once he has run from the crowd. Returns how many left.
func _recycle(want: int) -> int:
	var view: Rect2 = run.view_rect()
	var feet: Vector2 = run.wick_feet()
	var far: Array = []
	for e in run.enemies:
		if (e.id == "snuffer" or e.id == "gloam") and not e.dead and not e.gone and not view.has_point(e.pos):
			far.append(e)
	far.sort_custom(func(a, b) -> bool: return feet.distance_squared_to(a.pos) > feet.distance_squared_to(b.pos))
	var n := mini(want, far.size())
	for i in n:
		far[i].gone = true
	return n


## Shards a kill of kind `id` drops at the current clock: [[count, light], ...].
func drops(id: String) -> Array:
	var table: Array = ROSTER.get(id, {}).get("shards", [])
	var t := time()
	var out := [] as Array
	for row: Array in table:
		if t >= float(row[0]):
			out = [[int(row[1]), float(row[2])]]
	return out


## A new enemy's hp at the current clock (x10 scale).
func hp(id: String) -> int:
	var m := time() / 60.0
	return ceili(float(ROSTER[id]["hp"]) * (1.0 + HP_SQUARE * m * m))


## The body width of kind `id` for the crowd push.
static func size(id: String) -> float:
	return float(ROSTER[id]["size"])


## Most of `id` alive at once at time `t` (-1 = no cap).
func cap(id: String, t: float) -> int:
	var n := -1
	for c: Array in ROSTER[id]["cap"]:
		if t >= float(c[0]):
			n = int(c[1])
	return n


## Spawns up to `count` of `id` around one anchor; returns how many. `logged` (the scripted events) also goes
## past ENEMY_CAP.
func _spawn_group(id: String, count: int, t: float, logged: bool) -> int:
	var room: int = count if logged else ENEMY_CAP - run.enemies.size()
	var limit := cap(id, t)
	if limit >= 0:
		room = mini(room, limit - run.alive(id))
	count = mini(count, room)
	if count <= 0:
		return 0
	var anchor: Vector2 = _clear_anchor() if logged else run.edge_point()
	for i in count:
		run.spawn(id, anchor, i, count)
	if logged:
		history.append("%s %s x%d" % [_stamp(t), id, count])
	return count


## A formation's cue: the anchor is picked now, so the HUD pip and the arrival agree.
func _cue(i: int) -> void:
	_cued[i] = true
	_anchor[i] = run.wick_feet() if FORMATIONS[i - EVENTS.size()]["name"] == "snuffer_ring" else _clear_anchor()
	run.enemy_sound("formation")
	run.formation_coming.emit(_anchor[i])


func _fire(i: int, t: float) -> void:
	var list := EVENTS + FORMATIONS
	var e: Dictionary = list[i]
	if not e.get("finale", true) and run.closing():
		_next[i] = INF
		return
	if i >= EVENTS.size():
		if not _cued[i]:
			_cue(i)
		if _anchor[i] != Vector2.INF and run.view_rect().has_point(_anchor[i]) and e["name"] != "snuffer_ring":
			_anchor[i] = _clear_anchor() # Wick walked toward it: arrive off screen after all
		var n: int = call("_formation_" + str(e["name"]), _anchor[i])
		history.append("%s formation %s x%d" % [_stamp(t), e["name"], n])
		_cued[i] = false
	elif _spawn_group(str(e["kind"]), int(e["count"]), t, true) == 0:
		_next[i] = t + 1.0 # the kind is at its cap: try again in a second
		return
	elif _first[i] == -INF:
		run.debut.emit(str(e["kind"]))
	_last[i] = t
	if _first[i] == -INF:
		_first[i] = t
	_next[i] = _repeat(e, t)


## No steady spawns now: before and after a debut (its first time) or any formation.
func _quiet(t: float) -> bool:
	var list := EVENTS + FORMATIONS
	for i in list.size():
		var formation := i >= EVENTS.size()
		if formation and tide != "":
			break
		var q: Array = FORMATION_QUIET if formation else list[i].get("quiet", [])
		if q.is_empty():
			continue
		if (formation or _first[i] == -INF) and _next[i] < INF and t >= _next[i] - float(q[0]):
			return true
		if t < (_last[i] if formation else _first[i]) + float(q[1]):
			return true
	return false


## The steady rate factor at `t` (RATE, linear in between).
func _rate(t: float) -> float:
	var prev: Array = RATE[0]
	for r: Array in RATE:
		if t < float(r[0]):
			var u := (t - float(prev[0])) / maxf(float(r[0]) - float(prev[0]), 0.001)
			return lerpf(float(prev[1]), float(r[1]), u)
		prev = r
	return float(prev[1])


func _repeat(e: Dictionary, t: float) -> float:
	if not e.has("every"):
		return INF
	var next := t + randf_range(float(e["every"][0]), float(e["every"][1]))
	return next if next <= float(e.get("until", INF)) else INF


## An event that started before the clock's start: its next repeat after it (or never).
func _first_repeat(e: Dictionary) -> float:
	if not e.has("every"):
		return INF
	return start_at + randf_range(0.0, float(e["every"][0]))


func _pack(id: String) -> int:
	var p: Array = ROSTER[id]["pack"]
	return randi_range(int(p[0]), int(p[1]))


## A kind for one steady spawn at time `t`: each debuted kind by its ramped share, the Snuffer for the rest.
## Kinds at their cap give their share back to the Snuffer.
func _pick(t: float) -> String:
	var r := randf()
	for id in KINDS:
		var k: Dictionary = ROSTER[id]
		if id == FALLBACK or not k.has("from") or t < float(k["from"]):
			continue
		var ramp := float(k["ramp"])
		var share := float(k["share"]) * (1.0 if ramp <= 0.0 else clampf((t - float(k["from"])) / ramp, 0.0, 1.0))
		if r < share:
			var limit := cap(id, t)
			return id if limit < 0 or run.alive(id) < limit else FALLBACK
		r -= share
	return FALLBACK


static func _stamp(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


# --- formations (3:30 on): each returns how many came ----------------------------------------------------------

## Snuffers on a ring just off screen all round Wick, so they close in together (points over the void are skipped).
func _formation_snuffer_ring(_anchor_at: Vector2) -> int:
	var n := roundi(lerpf(RING.x, RING.y, clampf((time() - 210.0) / (RING_FULL - 210.0), 0.0, 1.0)))
	var centre: Vector2 = run.wick_feet()
	var radius: float = run.view_rect().size.length() * 0.5 + RING_MARGIN
	var turn := randf() * TAU
	var came := 0
	for i in n:
		for out: float in [0.0, 24.0, 48.0]: # over the void: a little further out, else that spot stays empty
			var p: Vector2 = centre + Vector2.from_angle(turn + TAU * i / n) * (radius + out)
			if run.open(p):
				run.spawn("snuffer", p, 0, 1)
				came += 1
				break
	return came


## A parliament of owls circling in from one side; their locks are staggered by the owl itself.
func _formation_owl_parliament(anchor: Vector2) -> int:
	return _group("owl", PARLIAMENT, anchor)


## Toads abreast across the way to Wick, hopping in step: flank the line.
func _formation_toad_line(anchor: Vector2) -> int:
	return _group("toad", TOAD_LINE, anchor)


## Sporecaps landing close together in view: their rings ripple.
func _formation_spore_garden(anchor: Vector2) -> int:
	return _group("sporecap", GARDEN, anchor)


## A big Gloam pack: a line of eyes off screen.
func _formation_gloam_pack(anchor: Vector2) -> int:
	return _group("gloam", GLOAM_PACK, anchor)


## `count` of `id` around `anchor` (formations go past caps and ENEMY_CAP).
func _group(id: String, count: int, anchor: Vector2) -> int:
	if anchor == Vector2.INF:
		anchor = _clear_anchor()
	for i in count:
		run.spawn(id, anchor, i, count)
	return count


## For a debut or a formation: of ANCHOR_TRIES edge points, the one with the fewest enemies around it and on the
## way from it to Wick, so the newcomers arrive on the clear side.
func _clear_anchor() -> Vector2:
	var best: Vector2 = run.edge_point()
	var fewest := INF
	var feet: Vector2 = run.wick_feet()
	for k in ANCHOR_TRIES:
		var p: Vector2 = best if k == 0 else run.edge_point()
		var mid := p.lerp(feet, 0.5)
		var n := 0
		for e in run.enemies:
			if e.pos.distance_squared_to(p) < ANCHOR_CLEAR * ANCHOR_CLEAR \
					or e.pos.distance_squared_to(mid) < ANCHOR_CLEAR * ANCHOR_CLEAR:
				n += 1
		if n < fewest:
			fewest = n
			best = p
	return best
