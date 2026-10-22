## The Gloam: the dark itself, a lanky hare cut out of the starry void (art/cast/enemies/gloam/gloam.json). Packs
## of 3-5 from 3:00 arrive as a line of eyes just outside the view, wait a beat, then stalk in bursts: a PAUSE
## (0.45 s crouch; on frames 4-5 the eyes narrow to slits, the tell before every dash), then a DASH (0.35 s at
## 120 px/s toward Wick, angled up to 35 degrees to alternate sides: a zig-zag; within CLOSE px the angle shrinks
## so the last lunge goes straight at him). The rhythm runs on its own clock: hits don't break it.
## Visibility is the mechanic. Outside the light only its two ice eyes draw. Inside the lantern's light (radius
## 44 / 58 / 72 px by glow tier, fully revealed 20 px inside that) and the map's light pools (until BRIGHTNESS is
## sold) the body dithers in on the world's 4x4 Bayer grid: gloam.gdshader per screen pixel, the shadow on the CPU
## only where it crosses a light's edge. Eyes, death stars and the hit flash always draw, so a shot into the dark
## lights the whole shape for one frame (hurt frame 0 is baked cream; none once HIT FLASH is sold).
## Auto-aim targets it in the dark too (gloam.json reveal.aim): the eyes always show where it is, and shots
## flying into the dark that light it up are the feedback.
extends "res://scripts/cast/enemies/enemy.gd"

enum State { SPAWN, WAIT, PAUSE, DASH }

const SHADER := preload("res://scripts/cast/enemies/gloam.gdshader")
const LANTERN_RADIUS: Array[float] = [44.0, 58.0, 72.0] # px by glow tier (gloam.json reveal.lights.lantern)
const LANTERN_FULL := 20.0 # px: fully revealed this far inside the lantern's radius
const POOL_RAMP := 16.0 # px: fully revealed this far inside a pool's radius (gloam.json: radius 30, full 14)
const SPECK_LEAD := 0.3 # specks show ahead of the body inside a light (the stars lead the dark)
const MAX_LIGHTS := 8 # the lantern and the nearest pools (gloam.gdshader MAX_LIGHTS)
const BAYER4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5] # core.bayer, row-major
const BODY := Color(1, 1, 1) # draw modes for the shader (modulate red)
const SPECKS := Color(0.5, 1, 1)
const ALWAYS := Color(0, 1, 1)
const SAFE_UNTIL_MS := 370.0 # spawn frames 0-2: a puddle with eyes opening; can't hurt or be hurt
const CLOSE := Vector2(16.0, 64.0) # px to Wick: the dash angle is full from 64 px and gone at 16 px
const ANGLE_MIN := 0.55 # a dash turns at least this share of the angle (so the zig-zag reads)
const WAIT_S := Vector3(0.3, 0.15, 0.2) # after spawning it idles base + index * step + random s (the pack ripples)
const PACK_GAP := 14.0 # px between a pack's members, across the way to Wick
const PACK_DEPTH := 5.0 # px of random depth along it
const SOUND_GAP := 0.1 # s: the same gloam sound plays at most this often (a pack would stack it)
## Fair contact: only the dash bites (a crouched Gloam on Wick is harmless; the narrowed eyes before each dash are
## the tell), and one that bit spends its next dash bounding away into the dark, up to FLEE_TURN off straight back.
## A pack can't stack on him: each bite sends that hare off for a whole beat.
const FLEE_TURN := deg_to_rad(40.0)
const _NO_MASKS: Array = [] # a sheet with no mask read yet

static var _material: ShaderMaterial # shared by every Gloam: its uniforms are the world's lights
static var _lights := PackedVector4Array() # this frame's lights: x, y, radius, full
static var _synced := -1 # process frame of the last light update
static var _masks := {} # shadow sheet -> per frame, PackedVector2Array: its opaque pixels (warm() reads them all)
static var _images := {} # shadow sheet -> Image (null when it can't be read)
static var _heard := {} # sound -> run_time it last played
static var lab := {} # numbers for lab_check (one process = one check run)

var dash_s := 0.35
var pause_s := 0.45
var speed := 120.0
var angle := deg_to_rad(35.0)
var _state := State.SPAWN
var _t := 0.0 # seconds into the state (carries over, so the rhythm keeps time)
var _index := 0
var _wait := 0.0
var _sign := 1.0 # side of the next dash (flips every dash)
var _dir := Vector2.DOWN # dash direction
var _dash_from := Vector2.ZERO
var _dash_clean := true # no push, hit, crowd push or prop in the way during this dash (its speed is measured)
var _locked := false # this pause's lock tell showed
var _last_turn := 0.0 # sign of the last angled dash (lab: the zig-zag)
var _bit := false # this dash touched Wick: the next one breaks away (FLEE)


func arrive(anchor: Vector2, index: int, count: int) -> void:
	_index = index
	pos = anchor
	var to_wick: Vector2 = game.wick_feet() - anchor
	var fwd := to_wick.normalized() if to_wick.length_squared() > 1.0 else Vector2.DOWN
	var slot := float(index) - (count - 1) * 0.5
	for i in 6:
		var p := anchor + fwd.orthogonal() * slot * PACK_GAP * (1.0 - i * 0.15) \
			+ fwd * randf_range(-PACK_DEPTH, PACK_DEPTH)
		if game.open(p):
			pos = p
			return


func setup() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	node.material = _material
	var b := kit.behaviour
	dash_s = float(b.get("dash_s", dash_s))
	pause_s = float(b.get("pause_s", pause_s))
	speed = float(b.get("dash_speed", speed))
	angle = deg_to_rad(float(b.get("dash_angle_deg", 35.0)))
	_sign = 1.0 if _index % 2 == 0 else -1.0
	_wait = WAIT_S.x + _index * WAIT_S.y + randf() * WAIT_S.z
	look = kit.pick_look()
	play("spawn")
	if _index == 0:
		_sound("gloam_open")


func step(dt: float) -> void:
	age += dt
	_t += dt
	advance(dt)
	if anim == "hurt" and done():
		_show_state()
	match _state:
		State.SPAWN:
			if anim != "spawn" or done():
				_enter(State.WAIT)
		State.WAIT:
			if _t >= _wait:
				_enter(State.PAUSE)
		State.PAUSE:
			if anim == "pause" and frame() >= 4 and not done() and not _locked:
				_locked = true
				game.stat("gloam_lock")
			if _t >= pause_s:
				_enter(State.DASH)
		State.DASH:
			if _t >= dash_s:
				_enter(State.PAUSE)
	var sep: Vector2 = game.separation(self) * 0.5 * clampf(dt * 20.0, 0.0, 1.0)
	var move := push * dt + sep
	if _state == State.DASH:
		move += _dir * speed * dt
		if push.length_squared() > 1.0 or sep.length_squared() > 0.01:
			_dash_clean = false
	if move.length_squared() > 0.0001:
		var before := pos
		walk(move)
		if not pos.is_equal_approx(before + move):
			_dash_clean = false
	push = push.move_toward(Vector2.ZERO, 400.0 * dt)


func step_dead(dt: float) -> void:
	advance(dt)
	if done():
		gone = true


func aimable() -> bool:
	return not dead and (anim != "spawn" or anim_t >= SAFE_UNTIL_MS)


## The hurt frame 0 is the baked flash (drawn even in the dark). With ANIMATIONS sold the flash layer shows instead
## for FLASH_TIME (a held hurt frame 0 would glow for 200 ms).
func hurt(_damage: int, p: Vector2, _from: Vector2) -> void:
	hit_stop = HIT_STOP[game.damage_tier()]
	push = p
	_dash_clean = false
	_sound("gloam_hiss")
	if still() or anim == "spawn":
		flash = FLASH_TIME
	else:
		play("hurt")


func die(_p: Vector2, _from: Vector2) -> void:
	dead = true
	flash = 0.0
	hit_stop = HIT_STOP[game.damage_tier()]
	play("death")
	_sound("gloam_unravel")
	game.stat("gloam_death_" + dir)


## Death frame 0 and hurt frame 0 are drawn cream (the flash) but not marked in the JSON.
func is_flash_frame(f: int) -> bool:
	return f == 0 and (anim == "hurt" or anim == "death")


## Only a dash bites. The game asks only while Wick can be hurt and hurts him on the first yes, so a yes is a bite.
func touches(body: Vector2, radius: float) -> bool:
	if _state != State.DASH or not super(body, radius):
		return false
	_bit = true
	game.stat("gloam_bite")
	return true


# --- drawing -------------------------------------------------------------------------------------------------

func draw_body(ci: CanvasItem) -> void:
	_sync_lights()
	var f := _shown()
	if flash > 0.0 and game.lv("hit_flash") == 0 and clip["tex"].has("flash"):
		_draw(ci, "flash", f, ALWAYS)
		_saw_flash()
	elif is_flash_frame(f): # still the flash (_shown skips it once HIT FLASH is sold)
		_draw(ci, "body", f, ALWAYS)
		_saw_flash()
	else:
		_draw(ci, "body", f, BODY)
		_draw(ci, "specks", f, SPECKS)
	_draw(ci, "eyes", f, ALWAYS)
	_draw(ci, "stars", f, ALWAYS)


## The shadow shows only where the body does (a shadow in the dark would give it away): whole inside the light,
## per pixel on the same Bayer grid across a light's edge, nothing in the dark.
func draw_shadow(ci: CanvasItem) -> void:
	_sync_lights()
	var f := _shown()
	var layer := "shadow"
	var mirror := mirrored()
	var tex_by: Dictionary = clip["tex"]
	if mirror:
		for alt in SHADOW_ALTS:
			if tex_by.has(alt):
				layer = alt
				mirror = false
				break
	if not tex_by.has(layer):
		return
	var size := kit.shadow_size
	var anchor := kit.shadow_anchor
	var feet := pos.round()
	var area := Rect2(feet.x - ((size.x - anchor.x) if mirror else anchor.x), feet.y - anchor.y, size.x, size.y)
	var span := reveal_span(_lights, area)
	if span.y <= 0.0:
		return
	var tex: Texture2D = tex_by[layer]
	var src := Rect2(f * size.x, 0, size.x, size.y)
	var pixels := _mask(tex, f, size)
	if span.x >= 1.0 or pixels.is_empty() and _images.get(tex) == null:
		if span.x >= 1.0 or reveal(_lights, feet) >= 0.5: # no readable mask: all or nothing at the feet
			var dest := area
			if mirror:
				dest.size.x = -size.x
			ci.draw_texture_rect_region(tex, dest, src)
		return
	var lit := reaching(_lights, area) # a light that doesn't reach the area adds 0 to every pixel's reveal
	var run := Rect2i(0, 0, 0, 1) # shown pixels next to each other in a row: one rect
	for q in pixels:
		var x := int(area.position.x + ((size.x - 1.0 - q.x) if mirror else q.x))
		var y := int(area.position.y + q.y)
		var p := Vector2(x + 0.5, y + 0.5)
		var best := 0.0 # reveal(lit, p)
		for l in lit:
			best = maxf(best, clampf((l.z - p.distance_to(Vector2(l.x, l.y))) / (l.z - l.w), 0.0, 1.0))
		if best <= (BAYER4[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0: # bayer(x, y)
			continue
		if y == run.position.y and x == run.end.x:
			run.size.x += 1
		elif y == run.position.y and x == run.position.x - 1: # mirrored rows run right to left
			run.position.x = x
			run.size.x += 1
		else:
			if run.size.x > 0:
				ci.draw_rect(Rect2(run), Color.WHITE) # the shade shader only reads the coverage
			run = Rect2i(x, y, 1, 1)
	if run.size.x > 0:
		ci.draw_rect(Rect2(run), Color.WHITE)


func draw_eyes(ci: CanvasItem) -> void:
	draw_layer(ci, "eyes", Vector2.INF, _shown())


## One layer of frame `f` with the anchor on `pos` (mirrored like draw_layer); `mode` tells the shader what it is.
func _draw(ci: CanvasItem, layer: String, f: int, mode: Color) -> void:
	var tex_by: Dictionary = clip["tex"]
	if not tex_by.has(layer):
		return
	var size: Vector2 = clip["size"]
	var anchor: Vector2 = clip["anchor"]
	var mirror := mirrored()
	var feet := pos.round()
	var dest := Rect2(Vector2(feet.x - ((size.x - anchor.x) if mirror else anchor.x), feet.y - anchor.y), size)
	if mirror:
		dest.size.x = -size.x
	ci.draw_texture_rect_region(tex_by[layer], dest, Rect2(f * size.x, 0, size.x, size.y), mode)


## The frame to draw: a flash frame is skipped once HIT FLASH is sold (with ANIMATIONS sold, frame() already shows
## it for FLASH_TIME only).
func _shown() -> int:
	var f := frame()
	if is_flash_frame(f) and game.lv("hit_flash") > 0:
		f = mini(f + 1, clip["frames"] - 1)
	return f


func _saw_flash() -> void:
	game.stat("gloam_flash")
	if reveal(_lights, centre()) < 0.5:
		game.stat("gloam_flash_dark")


# --- the light -----------------------------------------------------------------------------------------------

## Once per frame: the lantern (radius by glow tier) and the pools near the view, into the shared material.
func _sync_lights() -> void:
	var now := Engine.get_process_frames()
	if now == _synced:
		return
	_synced = now
	var pools: PackedVector3Array = game.light_pools()
	_lights = lights_for(game.glow_tier(), game.lantern(), pools, game.view_rect())
	var padded := _lights.duplicate()
	padded.resize(MAX_LIGHTS)
	_material.set_shader_parameter("lights", padded)
	_material.set_shader_parameter("light_count", _lights.size())
	_count("syncs")
	if _lights[0].z != LANTERN_RADIUS[game.glow_tier()]:
		_count("radius_wrong")
	_count("tier_%d" % game.glow_tier())
	if _lights.size() > 1:
		_count("pool_frames")
		if game.lv("brightness") > 0:
			_count("pool_frames_sold")


## The lights that reveal: the lantern at `lantern` with its radius for glow `tier`, then each pool (x, y, radius)
## whose light reaches `view`, up to MAX_LIGHTS.
static func lights_for(tier: int, lantern: Vector2, pools: PackedVector3Array, view: Rect2) -> PackedVector4Array:
	var r: float = LANTERN_RADIUS[clampi(tier, 0, LANTERN_RADIUS.size() - 1)]
	var out := PackedVector4Array([Vector4(lantern.x, lantern.y, r, r - LANTERN_FULL)])
	for p in pools:
		if out.size() >= MAX_LIGHTS:
			break
		if view.grow(p.z).has_point(Vector2(p.x, p.y)):
			out.append(Vector4(p.x, p.y, p.z, maxf(p.z - POOL_RAMP, 0.0)))
	return out


## 0 (dark) .. 1 (fully revealed) at world point `p` (gloam.gdshader does the same per pixel).
static func reveal(lights: PackedVector4Array, p: Vector2) -> float:
	var best := 0.0
	for l in lights:
		best = maxf(best, clampf((l.z - p.distance_to(Vector2(l.x, l.y))) / (l.z - l.w), 0.0, 1.0))
	return best


## The least and most reveal over the world rect `area` (x = min, y = max).
static func reveal_span(lights: PackedVector4Array, area: Rect2) -> Vector2:
	var lo := 0.0
	var hi := 0.0
	for l in lights:
		var c := Vector2(l.x, l.y)
		var near := c.clamp(area.position, area.end).distance_to(c)
		var far := Vector2(maxf(absf(c.x - area.position.x), absf(c.x - area.end.x)),
			maxf(absf(c.y - area.position.y), absf(c.y - area.end.y))).length()
		hi = maxf(hi, clampf((l.z - near) / (l.z - l.w), 0.0, 1.0))
		lo = maxf(lo, clampf((l.z - far) / (l.z - l.w), 0.0, 1.0))
	return Vector2(lo, hi)


## The lights whose reveal reaches into the world rect `area` (reveal_span's most above 0), in order.
static func reaching(lights: PackedVector4Array, area: Rect2) -> PackedVector4Array:
	var out := PackedVector4Array()
	for l in lights:
		var c := Vector2(l.x, l.y)
		if clampf((l.z - c.clamp(area.position, area.end).distance_to(c)) / (l.z - l.w), 0.0, 1.0) > 0.0:
			out.append(l)
	return out


## The ordered-dither threshold at world pixel (x, y) (core.bayer).
static func bayer(x: int, y: int) -> float:
	return (BAYER4[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


## At load (enemies.gd setup): reads every shadow frame's mask now, not in the middle of a run (a GPU readback on
## the web).
static func warm(k: KIT) -> void:
	for anim: String in k.data["animations"]:
		for d: String in k.dirs(anim):
			var c := k.clip(anim, d)
			for layer: String in c["tex"]:
				if layer.contains("shadow"):
					for f in int(c["frames"]):
						_mask(c["tex"][layer], f, k.shadow_size)


## Opaque pixels of frame `f` of a shadow sheet (read once per sheet and frame).
static func _mask(tex: Texture2D, f: int, size: Vector2) -> PackedVector2Array:
	var by_frame: Array = _masks.get(tex, _NO_MASKS)
	if f < by_frame.size() and by_frame[f] != null:
		return by_frame[f]
	if not _images.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_images[tex] = img if img != null and not img.is_empty() else null
	var out := PackedVector2Array()
	var img: Image = _images[tex]
	if img != null:
		for y in int(size.y):
			for x in int(size.x):
				if img.get_pixel(int(f * size.x) + x, y).a > 0.5:
					out.append(Vector2(x, y))
	if by_frame.is_empty():
		by_frame = []
		_masks[tex] = by_frame
	if f >= by_frame.size():
		by_frame.resize(f + 1)
	by_frame[f] = out
	return out


# --- the stalk -------------------------------------------------------------------------------------------------

func _enter(s: State) -> void:
	var lasted := _t
	var carry := 0.0
	var from := _state
	match _state:
		State.WAIT:
			carry = _t - _wait
		State.PAUSE:
			carry = _t - pause_s
			_measure("pause", lasted, pause_s)
		State.DASH:
			carry = _t - dash_s
			_measure("dash", lasted, dash_s)
			if _dash_clean:
				_count("dash_clean")
				var v := pos.distance_to(_dash_from) / lasted
				if absf(v - speed) <= speed * 0.1:
					_count("dash_speed_ok")
	_state = s
	_t = clampf(carry, 0.0, 0.1)
	var to_wick: Vector2 = game.wick_feet() - pos
	match s:
		State.WAIT:
			_show_state()
		State.PAUSE:
			_locked = false
			_show_state()
			_turn(to_wick)
			game.stat("gloam_pause_" + dir)
			if from == State.DASH and _on_screen():
				_sound("gloam_tick") # the landing
		State.DASH:
			if _bit:
				_bit = false
				_dir = (-to_wick.normalized() if to_wick.length_squared() > 0.25 else Vector2.UP) \
					.rotated(randf_range(-FLEE_TURN, FLEE_TURN))
				_dash_from = pos
				_dash_clean = false # not a stalking dash: its speed and angle aren't the rhythm's
				_show_state()
				_turn(_dir)
				game.stat("gloam_flee")
				return
			var d := to_wick.length()
			var close := clampf((d - CLOSE.x) / (CLOSE.y - CLOSE.x), 0.0, 1.0)
			if close > 0.0:
				_sign = -_sign # a straight lunge doesn't count as a side
			var turn := angle * randf_range(ANGLE_MIN, 1.0) * close * _sign
			_dir = (to_wick / d if d > 0.5 else Vector2.DOWN).rotated(turn)
			_dash_from = pos
			_dash_clean = push.length_squared() <= 1.0
			_show_state()
			_turn(_dir)
			game.stat("gloam_dash_" + dir)
			_lab_angle(turn, close)
			if _on_screen():
				_sound("gloam_hush")


## Plays the state's clip at the state's time (unless the hurt clip is still playing: it resumes after).
func _show_state() -> void:
	if anim == "hurt" and not done():
		return
	match _state:
		State.WAIT:
			play("idle")
			anim_t = randf() * clip["total"]
		State.PAUSE:
			play("pause")
			anim_t = _t * 1000.0
		State.DASH:
			play("dash")
			anim_t = _t * 1000.0


func _turn(v: Vector2) -> void:
	set_dir("side" if absf(v.x) > SIDE_RATIO * absf(v.y) else ("front" if v.y > 0.0 else "back"), v.x < 0.0)


func _on_screen() -> bool:
	var view: Rect2 = game.view_rect()
	return view.grow(8.0).has_point(pos)


func _sound(sfx: String) -> void:
	var now: float = game.run_time
	var last := float(_heard.get(sfx, -INF))
	if now >= last and now - last < SOUND_GAP:
		return
	_heard[sfx] = now
	game.enemy_sound(sfx)


# --- lab numbers -----------------------------------------------------------------------------------------------

static func _count(key: String, n := 1) -> void:
	lab[key] = int(lab.get(key, 0)) + n


static func _most(key: String, v: float) -> void:
	lab[key] = maxf(float(lab.get(key, -INF)), v)


static func _least(key: String, v: float) -> void:
	lab[key] = minf(float(lab.get(key, INF)), v)


func _measure(what: String, lasted: float, want: float) -> void:
	_count(what + "s")
	_most(what + "_late", lasted - want)
	_least(what + "_least", lasted - want)


func _lab_angle(turn: float, close: float) -> void:
	_most("angle_max", absf(rad_to_deg(turn)))
	if close >= 1.0:
		_least("angle_far_min", absf(rad_to_deg(turn)))
	if turn != 0.0:
		if signf(turn) == _last_turn:
			_count("sign_repeats")
		_last_turn = signf(turn)


## enemy_check: the rhythm and the zig-zag, the reveal by glow tier and the pools until BRIGHTNESS is sold, the
## hit flash in the dark (none with HIT FLASH sold), the lock tell (none with ANIMATIONS sold), every view.
func lab_check(stats: Dictionary) -> PackedStringArray:
	var fails := PackedStringArray()
	var frame_dt: float = 1.0 / 60.0 * game.enemy_tempo + 0.001 # one brain step (DIFFICULTY scales it)
	var short: bool = game.finale() or game.display_off()
	# the numbers are gloam.json's
	var rj: Dictionary = kit.data["reveal"]["lights"]
	for t in 3:
		if float(rj["lantern"]["radius_by_glow_tier"][t]) != LANTERN_RADIUS[t]:
			fails.append("lantern radius for tier %d is not gloam.json's" % t)
	if int(rj["light_pools"]["radius"]) - int(rj["light_pools"]["full_inside"]) != int(POOL_RAMP):
		fails.append("POOL_RAMP is not gloam.json's pool ramp")
	# rhythm
	var dashes := int(lab.get("dashs", 0))
	if dashes < (2 if short else 8):
		fails.append("only %d dashes" % dashes)
	for what: String in ["dash", "pause"]:
		if float(lab.get(what + "_late", 0.0)) > frame_dt or float(lab.get(what + "_least", 0.0)) < -0.0001:
			fails.append("%s timing off: %.3f to %.3f s from %.2f s" % [what, lab.get(what + "_least", 0.0),
				lab.get(what + "_late", 0.0), dash_s if what == "dash" else pause_s])
	if float(lab.get("angle_max", 0.0)) > rad_to_deg(angle) + 0.01:
		fails.append("a dash turned %.1f deg (max %.0f)" % [lab["angle_max"], rad_to_deg(angle)])
	if float(lab.get("angle_far_min", INF)) < rad_to_deg(angle) * ANGLE_MIN - 0.01:
		fails.append("a far dash turned only %.1f deg" % lab["angle_far_min"])
	if int(lab.get("sign_repeats", 0)) > 0:
		fails.append("%d dashes turned the same way twice (no zig-zag)" % lab["sign_repeats"])
	var clean := int(lab.get("dash_clean", 0))
	if clean < 4 and not short:
		fails.append("only %d dashes ran free of pushes and props: their speed went unmeasured" % clean)
	elif clean >= 4 and int(lab.get("dash_speed_ok", 0)) * 2 < clean:
		fails.append("only %d of %d clean dashes ran at %.0f px/s" % [lab.get("dash_speed_ok", 0), clean, speed])
	if not short:
		for v in ["side", "front", "back"]:
			for what in ["dash", "pause"]:
				if int(stats.get("gloam_%s_%s" % [what, v], 0)) < 1:
					fails.append("never saw a %s in the %s view" % [what, v])
	# the reveal: the lantern by glow tier, a pool until BRIGHTNESS is sold
	var far := Vector2(-5000, -5000)
	var world := Rect2(-10000, -10000, 20000, 20000)
	for t in 3:
		var r := LANTERN_RADIUS[t]
		var ls := lights_for(t, Vector2.ZERO, PackedVector3Array(), world)
		var full := r - LANTERN_FULL
		if reveal(ls, Vector2(r + 0.5, 0)) > 0.0 or reveal(ls, Vector2(r - 1.0, 0)) <= 0.0 \
				or reveal(ls, Vector2(full, 0)) < 1.0 or reveal(ls, Vector2(full + 2.0, 0)) >= 1.0:
			fails.append("glow tier %d does not reveal out to %.0f px (full at %.0f)" % [t, r, r - LANTERN_FULL])
	if int(lab.get("radius_wrong", 0)) > 0 or int(lab.get("syncs", 0)) == 0:
		fails.append("the shader's lantern radius missed the glow tier (%d of %d frames)" % [
			lab.get("radius_wrong", 0), lab.get("syncs", 0)])
	var all_pools: PackedVector3Array = game.view.pools
	var pools: PackedVector3Array = game.light_pools()
	var sold: bool = game.lv("brightness") > 0
	if all_pools.is_empty():
		fails.append("the map has no light pools")
	elif sold:
		var ls := lights_for(0, far, pools, world)
		if reveal(ls, Vector2(all_pools[0].x, all_pools[0].y)) > 0.0 or int(lab.get("pool_frames_sold", 0)) > 0:
			fails.append("a light pool revealed with BRIGHTNESS sold")
	else:
		for p in pools:
			var c := Vector2(p.x, p.y)
			var ls := lights_for(0, far, PackedVector3Array([p]), world)
			if reveal(ls, c) < 1.0 or reveal(ls, c + Vector2(p.z + 0.5, 0)) > 0.0:
				fails.append("the pool at %s does not reveal out to its %.0f px" % [c.round(), p.z])
				break
	# the hit flash shows the shape in the dark, unless HIT FLASH is sold
	if game.lv("hit_flash") > 0:
		if int(stats.get("gloam_flash", 0)) > 0:
			fails.append("%d flash frames drew with HIT FLASH sold" % stats["gloam_flash"])
	elif int(stats.get("hits", 0)) > 0 and int(stats.get("gloam_flash", 0)) == 0:
		fails.append("hits but no flash frame drew")
	elif not short and int(stats.get("gloam_flash_dark", 0)) == 0:
		fails.append("never flashed in the dark")
	# the lock tell needs ANIMATIONS
	if game.still() and int(stats.get("gloam_lock", 0)) > 0:
		fails.append("the lock tell showed with ANIMATIONS sold")
	elif not game.still() and not short and int(stats.get("gloam_lock", 0)) == 0:
		fails.append("the lock tell never showed")
	return fails
