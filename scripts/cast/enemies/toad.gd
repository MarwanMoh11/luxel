## The Parasol Toad: the tank you walk around (art/cast/enemies/toad/toad.json; ENEMY_BRIEF.md). It squash-hops
## at Wick (16 px/s on average, moving only in the air) behind a lace parasol whose facing turns toward him at
## most TURN_RATE deg/s. Whatever arrives within BLOCK_HALF deg of that facing bounces off the canopy: shots
## (pierce included), the bell toll's splash and the fireflies' stings. A block does no damage and shows no flash:
## the canopy dents where it was struck (block / block_cw / block_ccw) and throws cool drops back at the shooter.
## From the sides and the back it is hit: a cream flash (baked into hurt frame 0, gone once HIT FLASH is sold),
## a flinch and a croak. Read it by the parasol: light dome and spike = blocked, dark ribs and warty back = shoot.
## Facing: a hop keeps the parasol on one of the 8 drawn facings (45 deg apart). Once Wick's lantern (where his
## shots leave from) is more than REPLANT deg off it, the toad lands, plants and turns on the spot to the drawn
## facing nearest it (the turn in-betweens show every 11.25 deg), then hops on. So circling it keeps it turning
## instead of coming at you.
## Heavy: shots never knock it back; the shove from touching Wick still does, but dies off twice as fast.
## The dome is a shield, not a weapon: Wick walking into it is pushed back out (DOME_SHOVE) with a dent, drops and
## the thup, and takes no damage (inert in the PIXELS finale, where only eyes show). Only the body (its sides and
## back) hurts on contact.
## Death: a leap, a flat flop, the parasol bows once and drifts off on the wind (the light's warm dissolve is baked
## in); the light's death_large overlay plays when the body is gone.
## In `enemy_check -- lab=toad` (the dodge bot never flanks) toad_lab.gd probes each toad through the game's real
## paths; lab_check reads what it and the toad recorded.
extends "res://scripts/cast/enemies/enemy.gd"

const LAB := preload("res://scripts/cast/enemies/toad_lab.gd")
const TURN_RATE := 85.0 # deg/s: the parasol's top turning speed (the art's in-betweens were timed for 100)
const BLOCK_HALF := 55.0 # deg either side of the facing that bounce off the canopy
const BLOCK_CENTRE := 18.0 # deg: a strike nearer the facing plays `block`, else block_cw / block_ccw
const REPLANT := 30.0 # deg Wick may drift off the hop's facing before the toad stops to turn
const SETTLE := 26.5 # deg: while turning, the facing it turns to moves on once Wick is this far off it
const POSE_SNAP := 5.625 # deg: this near a drawn facing, that facing's frames show (else a turn in-between)
const BLOCK_POSE := 11.25 # deg: a block while turning dents the canopy only this near a drawn facing
const AIR_FIRST := 3 # hop frames AIR_FIRST..AIR_LAST move (launch to landing); LAND_FRAME thumps
const AIR_LAST := 7
const LAND_FRAME := 7
const GONE_FRAME := 7 # death frame where the body is gone: the light's death_large overlay
const BLOCK_STOP := 0.04 # s frozen on a block (rig.hit_stop)
const SHOVE_DECAY := 800.0 # px/s^2: Wick's contact shove fades twice as fast as on a Snuffer
const CROWD := 0.25 # share of the crowd push it takes (a Snuffer takes 0.5)
const SPACING := 30.0 # px (feet to feet) toads keep between each other, so canopies never stack into a blob
const CANOPY := Vector2(7.0, 13.0) # px: the canopy's hit ellipse (half depth along the facing, half width across)
const SOURCE_MIN := 6.0 # px: a source this near the centre (a sting's last fly position) counts as Wick's side
const LINE_GAP := 34.0 # px between toads in a line (formations)
const DOME_SHOVE := 70.0 # px/s: Wick inside the dome is pushed back out at least this fast (a few px, no damage)
const DOME_GAP := 0.3 # s between one toad's dome dents (drops and thup) while Wick leans on it
const WICK_RADIUS := 3.5 # px: Wick's contact circle (arena PLAYER_SIZE / 2)
const SIDE_LIMIT := 125.0 # deg off the facing: beyond it a hit counts as from the back (stats only)
const VIEWS := {0: "side", 45: "front34", 90: "front", -45: "back34", -90: "back"}
const TURNS := {0: "side-front34", 45: "front34-front", -45: "side-back34", -90: "back34-back"} # by the lower facing

var facing := 0.0 ## deg, screen (0 = +x, clockwise): the parasol's facing, the one that blocks
var target := 0.0 ## deg: the drawn facing (a multiple of 45) it hops on or turns to
var planted := false ## turning on the spot instead of hopping
var speed := 16.0 ## px/s on average (it moves only in the air)
var spun := false ## set by the lab probe when it turns the toad by hand: the turn-rate check skips that step
var blocked_at: Array[Vector2] = [] ## lab probe only: where attacks struck the canopy since it last looked
var _air_speed := 0.0 # px/s while airborne
var _hop_ms := PackedFloat32Array() # the hop's frame times (every view shares them)
var _hop_total := 1000.0 # ms per hop
var _hop_t := 0.0 # ms into the hop cycle
var _idle_t := 0.0 # ms into the idle loop (shown while planted on a drawn facing)
var _idle_total := 2000.0 # ms per idle loop
var _turn_k := 0 # the turn in-between shown while anim == "turn"
var _body := Vector2(0, -9) # body_centre (feet-relative)
var _splash := {} # effects.splash_any_fx
var _splash_tex: Texture2D
var _splash_total := 0.0
var _splashes: Array[Dictionary] = [] # cool drops in flight: {"at", "row", "t" (ms)}
var _lab: LAB # the headless lab probe, else null
var _dome_cd := 0.0 # s until the dome may dent again
var _drawn := false # counted in the stats once


func setup() -> void:
	speed = float(kit.behaviour.get("speed_px_s", speed))
	xp = int(kit.behaviour.get("xp", xp))
	_body = KIT.vec(kit.data.get("body_centre", [0, -9]))
	_splash = kit.data["effects"]["splash_any_fx"]
	_splash_tex = load(KIT.ROOT + id + "/" + str(_splash["file"]))
	for ms: float in _splash["ms"]:
		_splash_total += ms
	look = kit.pick_look()
	_hop_ms = kit.clip("hop", "front", look)["ms"]
	_hop_total = kit.clip("hop", "front", look)["total"]
	_idle_total = kit.clip("idle", "front", look)["total"]
	var moving := 0.0
	for i in range(AIR_FIRST, AIR_LAST + 1):
		moving += _hop_ms[i]
	_air_speed = speed * _hop_total / moving
	facing = snap(_want())
	target = facing
	_show_pose()
	if game.director.lab == id and game.autopilot:
		_lab = LAB.new(self)


## A line of `count` shoulder to shoulder across the way to Wick (LINE_GAP apart, squeezed where the ground is
## narrow); a lone toad stands on the anchor.
func arrive(anchor: Vector2, index: int, count: int) -> void:
	pos = anchor
	if count <= 1:
		return
	var across: Vector2 = (game.wick_feet() - anchor).normalized().orthogonal()
	var slot := (index - (count - 1) / 2.0) * LINE_GAP
	for squeeze: float in [1.0, 0.75, 0.5, 0.25]:
		var p := anchor + across * slot * squeeze
		if game.open(p):
			pos = p
			return


func step(dt: float) -> void:
	age += dt
	var was := facing
	var want := _want()
	if planted:
		if absf(wrapf(want - target, -180.0, 180.0)) > SETTLE:
			target = snap(want)
		facing = _toward(facing, target, TURN_RATE * dt)
	_step_splashes(dt)
	_dome(dt)
	if _lab != null:
		_lab.step(dt)
	_check_turn(was, dt)
	if anim == "hurt":
		advance(dt)
		_drift(Vector2.ZERO, dt)
		if done():
			_hop_t = 0.0
			_show_pose()
		return
	if not planted and not _airborne() and absf(wrapf(want - target, -180.0, 180.0)) > REPLANT:
		planted = true
		target = snap(want)
		if _on_view():
			game.enemy_sound("toad_turn")
	elif planted and facing == target and absf(wrapf(want - target, -180.0, 180.0)) <= SETTLE:
		planted = false
		_hop_t = 0.0
	var move := Vector2.ZERO
	if planted:
		_idle_t += dt * 1000.0
	else:
		var before := _hop_frame()
		_hop_t = fmod(_hop_t + dt * 1000.0, _hop_total)
		var k := _hop_frame()
		if k >= AIR_FIRST and k <= AIR_LAST:
			move = (game.wick_feet() - pos).normalized() * _air_speed * dt
		if k == LAND_FRAME and before != LAND_FRAME:
			game.stat("toad_landings")
			if _on_view():
				game.enemy_sound("toad_hop")
	_drift(move, dt)
	if anim.begins_with("block") and not done() and (planted or not _airborne()):
		advance(dt)
	else:
		_show_pose()


func step_dead(dt: float) -> void:
	var before := _raw_frame()
	anim_t += dt * 1000.0
	_step_splashes(dt)
	if before < GONE_FRAME and _raw_frame() >= GONE_FRAME:
		game.light_overlay("death_large", pos + _body)
		game.enemy_sound("toad_whoosh")
	if done():
		gone = true


## The body circle, lifted with the hop.
func centre() -> Vector2:
	return pos + _body - Vector2(0.0, float(fd("lift", 0)))


## The body circle or the canopy: a shot from the front stops on the dome, not inside it.
func shot_hits(p: Vector2) -> bool:
	return super(p) or (aimable() and _in_canopy(p))


## Only the body hurts; the dome pushes Wick back instead (_dome).
func touches(body: Vector2, radius: float) -> bool:
	return super(body, radius)


func blocks(from: Vector2) -> bool:
	return absf(offset(from)) <= BLOCK_HALF


func on_block(at: Vector2, from: Vector2) -> void:
	hit_stop = BLOCK_STOP
	if _lab != null:
		blocked_at.append(at)
	_dent(at, from)
	_record(offset(from), true)


## The canopy dents where `at` struck it (from `from`), with the thup and cool drops back toward the source.
func _dent(at: Vector2, from: Vector2) -> void:
	var off := offset(from)
	var v := view_of(snap(facing))
	var name := "block" if absf(off) < BLOCK_CENTRE else ("block_cw" if off > 0.0 else "block_ccw")
	if v[1] and name != "block": # a mirrored sprite swaps its sides
		name = "block_ccw" if name == "block_cw" else "block_cw"
	var near := absf(wrapf(facing - snap(facing), -180.0, 180.0)) <= BLOCK_POSE
	if anim != "hurt" and ((planted and near) or (not planted and not _airborne())):
		_pose(name, v, 0.0, true)
	game.enemy_sound("toad_block")
	if game.lv("particles") == 0:
		var spot := _splash_at(at)
		var row := posmod(roundi(rad_to_deg((from - spot).angle()) / 22.5), 16)
		_splashes.append({"at": spot, "row": row, "t": 0.0})


## Wick inside the dome: pushed back out along the way from the canopy's centre, and the dome dents (no damage).
## Inert in the PIXELS finale.
func _dome(dt: float) -> void:
	_dome_cd -= dt
	var body: Vector2 = game.wick_body()
	if not aimable() or game.finale() or not _in_canopy(body, WICK_RADIUS):
		return # in the finale only the eyes show: the unseen dome lets Wick pass
	var out := body - _canopy()
	out = out.normalized() if out.length_squared() > 0.01 else Vector2.from_angle(deg_to_rad(facing))
	var vel: Vector2 = game.player_vel
	if vel.dot(out) < DOME_SHOVE:
		game.player_vel = vel + out * (DOME_SHOVE - vel.dot(out))
	if _dome_cd <= 0.0:
		_dome_cd = DOME_GAP
		_dent(_canopy() + out * CANOPY.x, body)
		game.stat("toad_dome")


## Heavy: no knockback; it flinches (hurt frame 0 is the baked flash) and croaks, and its hop starts over.
func hurt(_damage: int, _p: Vector2, from: Vector2) -> void:
	var off := offset(from) if from != Vector2.INF else INF # before the pose: a hop's lift moves the centre
	hit_stop = HIT_STOP[game.damage_tier()]
	push = Vector2.ZERO
	_pose("hurt", view_of(snap(facing)), 0.0, true)
	game.enemy_sound("toad_croak")
	_record(off, false)


func die(_p: Vector2, _from: Vector2) -> void:
	dead = true
	flash = 0.0
	push = Vector2.ZERO
	hit_stop = HIT_STOP[game.damage_tier()]
	_pose("death", view_of(snap(facing)), 0.0, true)
	game.enemy_sound("toad_death")


## Hurt and death frame 0 are the baked cream flash (not marked in toad.json).
func is_flash_frame(f: int) -> bool:
	return (f == 0 and (anim == "hurt" or anim == "death")) or super(f)


func frame() -> int:
	return _turn_k if anim == "turn" else super()


func draw_body(ci: CanvasItem) -> void:
	super(ci)
	if anim == "hurt" and frame() == 0:
		game.stat("toad_flash_drawn" if game.lv("hit_flash") == 0 else "toad_flash_skipped")
	if not _drawn: # lab_check only asks whether frames were drawn at all
		_drawn = true
		game.stat("toad_drawn")
	var size := KIT.vec(_splash["frame_size"])
	var origin := KIT.vec(_splash["origin"])
	for s: Dictionary in _splashes:
		var f := 0 if still() else _index(_splash["ms"], s["t"])
		var at: Vector2 = s["at"]
		ci.draw_texture_rect_region(_splash_tex, Rect2(at.round() - origin, size),
			Rect2(f * size.x, int(s["row"]) * size.y, size.x, size.y))


## Degrees from the parasol's facing to where an attack came from (+ = clockwise). A source nearer the centre
## than SOURCE_MIN (a sting's last fly position is 1-3 px off, bowed sideways) counts as coming from Wick,
## where every sting starts.
func offset(from: Vector2) -> float:
	var c := centre()
	var d := from - c
	if d.length() < SOURCE_MIN:
		d = game.wick_body() - c
	return wrapf(rad_to_deg(d.angle()) - facing, -180.0, 180.0)


## The drawn facing (a multiple of 45, in -180..180) nearest angle `a`.
static func snap(a: float) -> float:
	return wrapf(roundf(a / 45.0) * 45.0, -180.0, 180.0)


## How parasol angle `a` is drawn: [view, mirrored, turn frame (-1 = the view's own frames)]. Left-facing
## angles mirror side, front34 and back34; front and back are never mirrored.
static func view_of(a: float) -> Array:
	a = wrapf(a, -180.0, 180.0)
	var flip := absf(a) > 90.0
	if flip:
		a = (180.0 - a) if a > 0.0 else (-180.0 - a)
	var near := roundf(a / 45.0) * 45.0
	if absf(a - near) <= POSE_SNAP:
		return [VIEWS[int(near)], flip and absf(near) != 90.0, -1]
	var lo := floorf(a / 45.0) * 45.0
	var k := roundi((a - lo) / 11.25) if lo >= 0.0 else roundi((lo + 45.0 - a) / 11.25)
	return [TURNS[int(lo)], flip, clampi(k, 1, 3) - 1]


## Every stat the toad and its lab probe recorded proves the mechanic (README.md, Testing).
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var at_least := ["toad_blocks", "toad_hit_back", "toad_hit_side", "toad_turn_capped", "toad_landings"]
	for a in ["hop", "idle", "turn", "block", "block_cw", "block_ccw", "hurt", "death"]:
		at_least.append("toad_anim_" + a)
	for v in ["side", "front34", "front", "back34", "back", "mirrored"]:
		at_least.append("toad_view_" + v)
	var none := ["toad_turn_fast", "toad_hit_inside", "toad_block_outside"]
	if int(stats.get("toad_probe_spins", 0)) > 0: # the lab probe ran (enemy_check lab=toad)
		at_least.append_array(["toad_probe_pierce_blocked", "toad_probe_side_hit", "toad_probe_toll_front_blocked",
			"toad_probe_sting_front_blocked", "toad_probe_toll_back_hit", "toad_probe_sting_back_hit"])
		none.append_array(["toad_probe_front_hit", "toad_probe_side_blocked", "toad_probe_toll_front_hit",
			"toad_probe_sting_front_hit", "toad_probe_toll_back_blocked", "toad_probe_sting_back_blocked"])
	if int(stats.get("toad_drawn", 0)) > 0: # drawn frames were counted
		if stats.has("sold_hit_flash"):
			none.append("toad_flash_drawn")
		elif int(stats.get("toad_anim_hurt", 0)) > 0:
			at_least.append("toad_flash_drawn")
	if stats.has("sold_particles"):
		none.append("toad_splashes")
	else:
		at_least.append("toad_splashes")
	for key: String in at_least:
		if int(stats.get(key, 0)) < 1:
			fails.append("never saw " + key)
	for key: String in none:
		if int(stats.get(key, 0)) > 0:
			fails.append("%s happened %d times" % [key, int(stats[key])])
	return fails


# --- internals -----------------------------------------------------------------------------------------------

## The angle (deg) from the body to Wick's lantern, where his shots leave from.
func _want() -> float:
	return rad_to_deg((game.lantern() - (pos + _body)).angle())


func _toward(a: float, b: float, most: float) -> float:
	var d := wrapf(b - a, -180.0, 180.0)
	return b if absf(d) <= most else wrapf(a + signf(d) * most, -180.0, 180.0)


## The turn rate held this step (a lab spin is a hand turn and doesn't count).
func _check_turn(was: float, dt: float) -> void:
	var turned := absf(wrapf(facing - was, -180.0, 180.0))
	if spun:
		spun = false
		return
	if turned > TURN_RATE * dt + 0.001:
		game.stat("toad_turn_fast")
	if turned > 0.0:
		game.stat("toad_turned")
		if turned >= TURN_RATE * dt - 0.001:
			game.stat("toad_turn_capped")


## Walks by `move` plus the fading contact shove, a quarter of the crowd push and its share of the toads' spacing.
func _drift(move: Vector2, dt: float) -> void:
	var settle := clampf(dt * 20.0, 0.0, 1.0)
	walk(move + push * dt + (game.separation(self) * CROWD + _spacing() * 0.5) * settle)
	push = push.move_toward(Vector2.ZERO, SHOVE_DECAY * dt)


## Away from other live toads nearer than SPACING (the crowd push keeps them only SIZE 18 px apart).
func _spacing() -> Vector2:
	var sep := Vector2.ZERO
	for e in game.enemies:
		if e == self or e.kind != kind:
			continue
		var d: Vector2 = pos - e.pos
		var l2 := d.length_squared()
		if l2 < SPACING * SPACING and l2 > 0.0001:
			var l := sqrt(l2)
			sep += d / l * (SPACING - l)
	return sep


func _hop_frame() -> int:
	return _index(_hop_ms, _hop_t)


func _airborne() -> bool:
	var k := _hop_frame()
	return not planted and k >= AIR_FIRST and k <= AIR_LAST


## The frame `anim_t` falls in, ignoring ANIMATIONS (events and movement go on when it is sold).
func _raw_frame() -> int:
	return _index(clip["ms"], anim_t)


static func _index(ms: Variant, t: float) -> int:
	for i in ms.size():
		t -= float(ms[i])
		if t < 0.0:
			return i
	return ms.size() - 1


## Shows the hop on its facing, or (planted) the idle on a drawn facing or the turn in-between nearest the facing.
func _show_pose() -> void:
	if not planted:
		_pose("hop", view_of(target), _hop_t)
		return
	var v := view_of(facing)
	if v[2] < 0:
		_pose("idle", v, fmod(_idle_t, _idle_total))
	else:
		_turn_k = v[2]
		_pose("turn", v, 0.0)


## Switches to `name` seen as view `v` ([view, mirrored, ...]) at `t` ms; `restart` replays a one-shot.
func _pose(name: String, v: Array, t: float, restart := false) -> void:
	if name != anim or v[0] != dir or v[1] != flip or restart:
		if name != anim:
			game.stat("toad_anim_" + name)
		anim = name
		dir = v[0]
		flip = v[1]
		clip = kit.clip(anim, dir, look)
		game.stat("toad_view_" + (dir if not dir.contains("-") else "turn"))
		if mirrored():
			game.stat("toad_view_mirrored")
	anim_t = t


## The drawn canopy's centre (world px).
func _canopy() -> Vector2:
	var c := KIT.vec(fd("canopy", [0, 0]))
	return pos + Vector2(-c.x if mirrored() else c.x, c.y)


## Inside the canopy's ellipse (grown by `grow` px), turned to the drawn parasol's facing.
func _in_canopy(p: Vector2, grow := 0.0) -> bool:
	var pf := float(fd("parasol_facing", facing))
	if mirrored():
		pf = 180.0 - pf
	var d := (p - _canopy()).rotated(-deg_to_rad(pf))
	var a := CANOPY.x + grow
	var b := CANOPY.y + grow
	return (d.x * d.x) / (a * a) + (d.y * d.y) / (b * b) <= 1.0


## Where the drops spray from: the strike itself when it landed on the canopy, else the canopy's edge toward it
## (a toll or a sting reports the body's edge).
func _splash_at(at: Vector2) -> Vector2:
	if _in_canopy(at):
		return at
	var c := _canopy()
	return c + (at - c).normalized() * CANOPY.x


func _step_splashes(dt: float) -> void:
	if _splashes.is_empty():
		return
	for s: Dictionary in _splashes:
		s["t"] += dt * 1000.0
	_splashes = _splashes.filter(func(s: Dictionary) -> bool: return s["t"] < _splash_total)


func _on_view() -> bool:
	return game.view_rect().has_point(pos)


## Stats for lab_check: every block and hit, by its offset from the facing (INF = unknown source), taken when
## the attack was judged.
func _record(off: float, blocked: bool) -> void:
	off = absf(off)
	if blocked:
		game.stat("toad_blocks")
		if game.lv("particles") == 0:
			game.stat("toad_splashes")
		if off > BLOCK_HALF:
			game.stat("toad_block_outside")
		return
	if off == INF:
		game.stat("toad_hit_unknown")
		return
	game.stat("toad_hit_inside" if off <= BLOCK_HALF else ("toad_hit_side" if off <= SIDE_LIMIT else "toad_hit_back"))
