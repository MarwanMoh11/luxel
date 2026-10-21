## Wick's lantern light: every shot, trail, impact and effect, from art/cast/light/weapons.json
## (written by docs/art_concepts/lastlight/cast/light.py; the rules are documented in that JSON).
## The Run keeps the gameplay (combat.gd: shots, hits; progression: powers); this picks each shot's look and plays
## the effects. Ported to the Run API for beta v1 (ARCHITECTURE.md 6).
extends RefCounted

const ROOT := "res://art/cast/light/"
enum { GROUND, MOON, TRAIL, UNDER_HERO, OVER_HERO, OVER } # draw layers, bottom to top
const NEAR := 16.0 # px: a shot this close to the lantern draws under Wick, so volleys across him come from behind
const TRAIL_ROWS: Array[String] = ["gold", "star", "rose", "lime", "sky", "coral", "blue"]
const GLASS: Array[String] = ["rose", "lime", "sky", "coral", "blue"]
const MOTE_ROWS: Array[String] = ["gold", "rose", "sky", "lime", "ice"]
const SLOTS := { # colour per bullet index by volley size; "core" is the centre shot
	1: ["core"], 2: ["core", "rose"], 3: ["rose", "core", "lime"], 4: ["lime", "core", "rose", "sky"],
	5: ["sky", "rose", "core", "lime", "coral"]}
const IMPACTS: Array[String] = ["impact", "toll_1", "toll_2", "toll_3"]
const FORMS: Array[String] = ["prism", "needle", "moon", "toll", "flies", "wake"] # forms_of keys, design 6 order
const FLY_COUNT: Array[int] = [0, 2, 3, 5] # fireflies by tier (the tier is the form; more flies hit harder)
const MOTES := 18
const MOTE_FLIGHT := 650.0
const WAKE_GAP := 150.0
# Sell mote tails: the row's mid colour, then one shade darker (Last Light palette).
const MOTE_TAIL := {
	"gold": [Color("#ffd98c"), Color("#f5a96a")], "rose": [Color("#ec9fa8"), Color("#a0466a")],
	"sky": [Color("#78a9da"), Color("#3e6db0")], "lime": [Color("#a3cf7d"), Color("#4c9e78")],
	"ice": [Color("#c7e5ef"), Color("#78a9da")]}

var run # the Run (run.gd), duck-typed: reads shop levels, powers and the clock
var sheets := {} # name -> {"tex", "size", "origin", "ms", "total", "loop"}
var orbits := {} # firefly count ("1".."6") -> one 24-tick orbit per fly
var splash := {} # the bell toll's reach: "radius" and "reach_ms" by tier (light_attacks.gd hurts with it)
var sting := {} # a firefly's sortie: "out_ms", "back_ms", "arc_px"
var puffs: Array = [] # one-shot sprites: {"s", "row", "pos", "t", "layer", "at" ("" | "emit" | "feet")}
var motes: Array = [] # the sell stream: {"j", "t", "from", "row", "absorb"}
var _wake_cd := 0.0


func setup(r) -> void:
	run = r
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "weapons.json"))
	for name: String in data["sheets"]:
		var s: Dictionary = data["sheets"][name]
		sheets[name] = {
			"tex": load(ROOT + str(s["file"])), "size": _vec(s["frame_size"]), "origin": _vec(s["origin"]),
			"ms": PackedFloat32Array(s["ms"]), "total": float(s["duration_ms"]), "loop": bool(s["loop"])}
	orbits = data["fireflies"]["orbits"]
	splash = data["splash"]
	sting = data["sting"]


func reset() -> void:
	puffs.clear()
	motes.clear()
	_wake_cd = 0.0


# --- what the powers turn on ---------------------------------------------------------------------------------

## 0 = full; 1..3 = the finale's last-light stages as PIXELS are sold; 4 = DISPLAY: OFF (nothing drawn).
func stage() -> int:
	if run.display_off():
		return 4
	var left: int = 100 - run.lv("pixels")
	return 0 if left > 70 else 1 if left > 40 else 2 if left > 15 else 3


## The bell toll's tier. The form thresholds sit low so the first sales each light a new form (design 6;
## weapons.json's art notes keep the old ones).
func damage_tier() -> int:
	return toll_of(run.prog.mult["damage"])


func moon_tier() -> int:
	return moon_of(run.prog.mult["range"])


## The fireflies' form tier (0-3; forms_of and the menu's tags).
func flies() -> int:
	return flies_of(run.prog.mult["fire"])


## How many fireflies orbit Wick: FLY_COUNT by tier, capped by weapons.json's orbit tables.
func fly_count() -> int:
	return mini(FLY_COUNT[flies()], orbits.size())


## Seconds a moon trail glint of `tier` stays drawn (light_attacks.gd hurts with it as long).
func moon_life(tier: int) -> float:
	return float(sheets["moon_t%d" % tier]["total"]) / 1000.0


static func toll_of(damage_mult: float) -> int:
	return 0 if damage_mult < 1.05 else 1 if damage_mult < 1.5 else 2 if damage_mult < 2.5 else 3


static func moon_of(range_mult: float) -> int:
	return 0 if range_mult < 1.1 else 1 if range_mult < 1.4 else 2


static func flies_of(fire_mult: float) -> int:
	return 0 if fire_mult < 1.05 else 1 if fire_mult < 1.2 else 2 if fire_mult < 1.5 else 3


## Every form's tier for a set of powers (progression's mult, shots, pierce): FORMS keys -> 0 (off), 1, 2...
static func forms_of(mult: Dictionary, shots: int, pierce: int) -> Dictionary:
	return {"prism": int(shots > 1), "needle": int(pierce > 0), "moon": moon_of(mult["range"]),
		"toll": toll_of(mult["damage"]), "flies": flies_of(mult["fire"]), "wake": int(float(mult["speed"]) > 1.0)}


## The forms a sale of `power` would light or raise, in FORMS order: [[key, new tier], ...] (the menu's NEW: tag).
func new_forms(power: Dictionary) -> Array:
	var after: Dictionary = run.prog.preview(power)
	return gained(forms_of(run.prog.mult, run.prog.shots, run.prog.pierce),
		forms_of(after["mult"], after["shots"], after["pierce"]))


## The forms whose tier rose from `before` to `after` (forms_of dictionaries), in FORMS order.
static func gained(before: Dictionary, after: Dictionary) -> Array:
	var out := []
	for key: String in FORMS:
		if int(after[key]) > int(before[key]):
			out.append([key, int(after[key])])
	return out


func quick() -> bool:
	return run.prog.fire_interval() < 0.22


func wake_on() -> bool:
	return run.prog.mult["speed"] > 1.0


## Wick's lantern glow: brighter as more of the light's forms are on.
func glow_tier() -> int:
	var on := int(run.prog.shots > 1) + int(run.prog.pierce > 0) + int(moon_tier() > 0) + int(damage_tier() > 0)
	on += int(flies() > 0) + int(wake_on())
	return 0 if on == 0 else 1 if on < 4 else 2


## Seconds before a volley that the flare starts (anticipation and wind-up).
func lead() -> float:
	return (30.0 if quick() else 110.0) / 1000.0


# --- events from the run -------------------------------------------------------------------------------------

func wind_up() -> void:
	if stage() < 4:
		_add("flare_quick" if quick() else "flare", 0, Vector2.ZERO, OVER_HERO, "emit")


func volley(aim: float, n: int) -> void:
	if stage() > 0:
		return
	_add("smear", _dir_row(Vector2.from_angle(aim)), Vector2.ZERO, UNDER_HERO, "emit")
	if n >= 2:
		_add("prism_glint", 0, Vector2.ZERO, UNDER_HERO, "emit")


## Picks bullet `i` of an `n`-shot volley's look (core x colour); call once the bullet has its pos.
func style(shot, i: int, n: int) -> void:
	var slots: Array = SLOTS[mini(n, 5)]
	var key: String = slots[i] if i < slots.size() else GLASS[i % GLASS.size()]
	shot.origin = shot.pos
	shot.start = i % 4
	if run.prog.pierce >= 1:
		shot.key = "star" if key == "core" else key
		shot.look = "needle_" + shot.key
	elif key == "core":
		shot.key = "gold"
		shot.look = "ember"
	else:
		shot.key = key
		shot.look = "shard"


## Drops the bullet's trail along the path it flew this step (colour motes every 3 px, moon every 2 px).
func track(shot, ms: float) -> void:
	shot.age += ms
	var st := stage()
	if st >= 2:
		return
	var travelled: float = shot.origin.distance_to(shot.pos)
	var heading: Vector2 = shot.vel.normalized()
	var sheet := "trail_needle" if shot.look.begins_with("needle") else "trail_t0"
	var row := TRAIL_ROWS.find("gold" if st == 1 else shot.key)
	while shot.trail_at <= travelled:
		if run.lv("particles") == 0:
			_add(sheet, row, shot.origin + heading * shot.trail_at, TRAIL)
		shot.trail_at += 3.0
	var tier := moon_tier() if st == 0 else 0
	while tier > 0 and shot.moon_at <= travelled:
		var k: int = shot.moon_k
		var at: Vector2 = shot.origin + heading * shot.moon_at
		var moon_row := 0
		if tier == 2 and k % 24 == 12:
			moon_row = 2
		elif k % 12 == 6:
			moon_row = 1
		else:
			var wave := 1.5 * sin(shot.moon_at / 6.0) if tier == 1 else 2.0 * sin(shot.moon_at / 7.0)
			at += Vector2(-heading.y, heading.x) * roundf(wave)
		_add("moon_t%d" % tier, moon_row, at, MOON)
		shot.moon_at += 2.0
		shot.moon_k += 1


## A bullet struck an enemy at `pos`; `pierced` = it flies on.
func hit(pos: Vector2, pierced: bool) -> void:
	var st := stage()
	if st >= 4:
		return
	if st >= 1:
		_add("last_hit", st - 1, pos, OVER)
		return
	_add(IMPACTS[damage_tier()], 0, pos, OVER)
	if pierced:
		_add("twinkle", 0, pos, OVER)


## The bell toll's ring reached an enemy at `pos` (splash).
func chime(pos: Vector2, tier: int) -> void:
	if stage() == 0:
		_add("chime", tier - 1, pos, OVER)


## A darting firefly passed `pos` (its trail mote, every 3 px).
func fly_trail(pos: Vector2) -> void:
	if sheets.has("fly_trail") and stage() < 2 and run.lv("particles") == 0:
		_add("fly_trail", 0, pos, OVER)


## A firefly stung an enemy at `pos`.
func sting_hit(pos: Vector2) -> void:
	if stage() < 2:
		_add("sting", 0, pos, OVER)


## A named overlay sheet at `pos` (a brain's request, e.g. "death_large"); skipped once PARTICLES is sold.
## The enemies play their own deaths; this is only what a brain asks for.
func overlay(sheet: String, pos: Vector2) -> void:
	if sheets.has(sheet) and stage() == 0 and run.lv("particles") == 0:
		_add(sheet, 0, pos, OVER)


## Wick's hop touched down at `feet`.
func land(feet: Vector2) -> void:
	if wake_on() and stage() < 2 and _wake_cd <= 0.0:
		_wake_cd = WAKE_GAP
		_add("wake", 0, feet, GROUND)


func heal() -> void:
	if stage() < 3:
		_add("heal", 0, Vector2.ZERO, GROUND, "feet")


## A sale landed: 18 motes fly from the screen border into the lantern.
func sell(id: String) -> void:
	if stage() >= 4:
		return
	var screen := Display.screen_rect() # the whole screen, also past the 320x180 game screen in fullscreen
	var perimeter := 2.0 * (screen.size.x - 4.0 + screen.size.y - 4.0)
	for j in MOTES:
		_mote(j, screen.position + _border(perimeter * (j + 0.5) / MOTES, screen.size), _mote_colour(id, j), false)


## Sell motes from world `points` into the lantern (the PARTICLES staging: the island's motes fly home).
## `key` is a setting id (its stream colours) or a mote colour (gold, rose, sky, lime, ice).
func stream_from(points: PackedVector2Array, key: String) -> void:
	var origin: Vector2 = run.view.origin()
	for j in points.size():
		_mote(j, points[j] - origin, _key_colour(key, j), false)


## The sell stream played outward: motes leave the lantern for the screen border (or world `points`), in the
## colours of `key` (the intro's relight, the ending's credits).
func stream_out(key := "", points := PackedVector2Array()) -> void:
	if not points.is_empty():
		var origin: Vector2 = run.view.origin()
		for j in points.size():
			_mote(j, points[j] - origin, _key_colour(key, j), true)
		return
	var screen := Display.screen_rect()
	var perimeter := 2.0 * (screen.size.x - 4.0 + screen.size.y - 4.0)
	for j in MOTES:
		_mote(j, screen.position + _border(perimeter * (j + 0.5) / MOTES, screen.size), _key_colour(key, j), true)


func _mote(j: int, from: Vector2, colour: String, outward: bool) -> void:
	var delay := float((j * 7) % MOTES) * 30.0
	motes.append({"j": j, "t": -delay, "from": from, "row": MOTE_ROWS.find(colour), "out": outward,
		"absorb": not outward and (delay == 0.0 or delay == (MOTES - 1) * 30.0)})


func _key_colour(key: String, j: int) -> String:
	return key if MOTE_ROWS.has(key) else _mote_colour(key, j)


func step(dt: float) -> void:
	var ms := dt * 1000.0
	_wake_cd -= ms
	for p: Dictionary in puffs:
		p["t"] += ms
	puffs = puffs.filter(func(p: Dictionary) -> bool: return p["t"] < sheets[p["s"]]["total"])
	for m: Dictionary in motes:
		m["t"] += ms
		if m["t"] >= MOTE_FLIGHT and m["absorb"]:
			_add("sell_absorb", 0, Vector2.ZERO, OVER_HERO, "emit")
	motes = motes.filter(func(m: Dictionary) -> bool: return m["t"] < MOTE_FLIGHT)


# --- drawing -------------------------------------------------------------------------------------------------

func draw_layer(ci: CanvasItem, layer: int, feet: Vector2, emit: Vector2) -> void:
	if stage() >= 4:
		return
	for p: Dictionary in puffs:
		if p["layer"] != layer:
			continue
		var at: Vector2 = emit if p["at"] == "emit" else feet if p["at"] == "feet" else p["pos"]
		_sprite(ci, p["s"], p["row"], _frame(p["s"], p["t"]), at)


## `near`: only the shots still within NEAR px of the lantern (drawn under Wick), else only the others.
func draw_shots(ci: CanvasItem, bullets: Array, near: bool) -> void:
	var st := stage()
	if st >= 4:
		return
	for shot in bullets:
		if (shot.origin.distance_to(shot.pos) < NEAR) != near:
			continue
		if st >= 1:
			_sprite(ci, "last_shot", st - 1, _frame("last_shot", shot.age), shot.pos)
			continue
		var row := 0
		if shot.look.begins_with("needle"):
			row = _dir_row(shot.vel)
		elif shot.look == "shard":
			row = GLASS.find(shot.key)
		var frame: int = 0 if run.still() else (shot.start + int(shot.age / 60.0)) % 4
		_sprite(ci, shot.look, row, frame, shot.pos)


## Fireflies orbiting Wick's feet: call with behind = true before Wick and false after.
func draw_flies(ci: CanvasItem, feet: Vector2, behind: bool) -> void:
	var n := fly_count()
	if n == 0 or stage() >= 2:
		return
	var orbit: Array = orbits[str(n)]
	for k in n:
		var dart: Dictionary = run.combat.attacks.fly(k)
		if not dart.is_empty():
			if not behind: # away from Wick, stinging: always in front
				var frame := 0 if run.still() else int(run.anim_time / 0.06) % 2
				_sprite(ci, "dart", _dir_row(dart["vel"]), frame, dart["pos"].round())
			continue
		var o: Dictionary = orbit[k][_tick()]
		if bool(o["behind"]) == behind:
			_sprite(ci, "firefly", 0, int(o["frame"]), feet + Vector2(o["dx"], o["dy"]))


## Fly k of n's place on its orbit right now, from Wick's feet.
func orbit_offset(n: int, k: int) -> Vector2:
	var o: Dictionary = orbits[str(n)][k][_tick()]
	return Vector2(o["dx"], o["dy"])


## The orbit table's tick: 12 per second, shared with the island's 2 s loop (0 while ANIMATIONS is sold).
func _tick() -> int:
	return 0 if run.still() else int(run.anim_time * 12.0) % 24


func draw_stream(ci: CanvasItem, emit: Vector2) -> void:
	if stage() >= 4:
		return
	for m: Dictionary in motes:
		var t: float = m["t"]
		if t < 0.0:
			continue
		var key: String = MOTE_ROWS[m["row"]]
		for back in 4:
			var tt := t - 25.0 * (back + 1)
			if tt >= 0.0:
				ci.draw_rect(Rect2(_mote_at(m, tt, emit).round(), Vector2.ONE), MOTE_TAIL[key][back / 2])
		_sprite(ci, "sell_mote", m["row"], _frame("sell_mote", t), _mote_at(m, t, emit))


# --- internals -----------------------------------------------------------------------------------------------

func _add(sheet: String, row: int, pos: Vector2, layer: int, at := "") -> void:
	puffs.append({"s": sheet, "row": row, "pos": pos.round(), "t": 0.0, "layer": layer, "at": at})


func _frame(name: String, t: float) -> int:
	var s: Dictionary = sheets[name]
	if run.still():
		return 0
	var ms: PackedFloat32Array = s["ms"]
	if s["loop"]:
		t = fmod(t, s["total"])
	for i in ms.size():
		t -= ms[i]
		if t < 0.0:
			return i
	return ms.size() - 1


func _sprite(ci: CanvasItem, name: String, row: int, frame: int, at: Vector2) -> void:
	var s: Dictionary = sheets[name]
	var size: Vector2 = s["size"]
	var src := Rect2(frame * size.x, row * size.y, size.x, size.y)
	ci.draw_texture_rect_region(s["tex"], Rect2(at.round() - s["origin"], size), src)


static func _dir_row(v: Vector2) -> int:
	return posmod(roundi(atan2(v.y, v.x) / (TAU / 16.0)), 16)


## A point `d` px along the border of a `view`-sized screen (inset 2 px), clockwise from the top-left corner.
static func _border(d: float, view: Vector2) -> Vector2:
	var w := view.x - 4.0
	var h := view.y - 4.0
	if d < w:
		return Vector2(2.0 + d, 2.0)
	d -= w
	if d < h:
		return Vector2(2.0 + w, 2.0 + d)
	d -= h
	if d < w:
		return Vector2(2.0 + w - d, 2.0 + h)
	return Vector2(2.0, 2.0 + h - (d - w))


## A mote's place: inward from its start into the lantern, or (outward) the same path flown backwards.
static func _mote_at(m: Dictionary, t: float, emit: Vector2) -> Vector2:
	if m.get("out", false):
		return _mote_pos(m, MOTE_FLIGHT - t, emit)
	return _mote_pos(m, t, emit)


## Quadratic Bezier from the border into the lantern, bowing left or right, accelerating (e = u^2).
static func _mote_pos(m: Dictionary, t: float, emit: Vector2) -> Vector2:
	var p0: Vector2 = m["from"]
	var span := emit - p0
	var bow := 1.0 if m["j"] % 2 == 0 else -1.0
	var p1 := (p0 + emit) / 2.0 + Vector2(-span.y, span.x).normalized() * 0.3 * span.length() * bow
	var e := pow(clampf(t / MOTE_FLIGHT, 0.0, 1.0), 2.0)
	return p0.lerp(p1, e).lerp(p1.lerp(emit, e), e)


static func _mote_colour(id: String, j: int) -> String:
	match id:
		"colour":
			return ["rose", "sky", "lime", "gold"][j % 4]
		"brightness":
			return "gold"
		"pixels":
			return "ice"
		"particles":
			return ["gold", "lime"][j % 2]
	return "gold"


static func _vec(v: Variant) -> Vector2:
	return Vector2(v[0], v[1])
