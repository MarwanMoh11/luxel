class_name LxBossBolt
extends RefCounted
## Pooled fair boss projectile supporting blocking, reflection, freeze hooks,
## and dynamic LxFields bending (gravity wells / wind). Strictly 20 Last Light colours.

const PAL: Dictionary = LxPalette.PAL
const MAX_SPEED: float = 340.0
const MIN_SPEED: float = 32.0

static var _fields_checked: bool = false
static var _fields_script: Object = null

var active: bool = false
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var speed: float = 135.0
var radius: float = 4.0
var damage: float = 1.0
var age: float = 0.0
var max_age: float = 4.0
var color_key: String = "coral"
var core_key: String = "cream"
var source_kind: String = "boss_bolt"
var telegraphed: bool = true

var blockable: bool = true
var reflectable: bool = true
var pierces_walls: bool = false
var field_scale: float = 1.0
var reflected: bool = false
var frozen_t: float = 0.0
var freeze_hook_tag: String = ""

var mode: String = "linear" # linear | orbit | boomerang
var orbit_center: Vector2 = Vector2.ZERO
var orbit_follow_boss: bool = false
var orbit_radius: float = 32.0
var orbit_target_radius: float = 44.0
var orbit_angle: float = 0.0
var orbit_omega: float = 2.0

var start_pos: Vector2 = Vector2.ZERO
var return_time: float = 0.75
var curve_rate: float = 0.0
var returning: bool = false


func reset(
	p_pos: Vector2,
	p_dir: Vector2,
	p_speed: float,
	cfg: Dictionary = {}
) -> void:
	active = true
	pos = p_pos
	prev_pos = p_pos
	start_pos = p_pos
	dir = p_dir.normalized() if p_dir.length_squared() > 0.0001 else Vector2.RIGHT
	speed = clampf(p_speed, MIN_SPEED, MAX_SPEED)
	vel = dir * speed
	radius = clampf(float(cfg.get("radius", 4.0)), 2.5, 10.0)
	damage = maxf(0.5, float(cfg.get("damage", 1.0)))
	age = 0.0
	max_age = maxf(0.35, float(cfg.get("max_age", 4.2)))
	color_key = str(cfg.get("color", "coral"))
	core_key = str(cfg.get("core", "cream"))
	source_kind = str(cfg.get("source", "boss_bolt"))
	telegraphed = bool(cfg.get("telegraphed", true))
	blockable = bool(cfg.get("blockable", true))
	reflectable = bool(cfg.get("reflectable", true))
	pierces_walls = bool(cfg.get("pierces_walls", false))
	field_scale = clampf(float(cfg.get("field_scale", 1.0)), 0.0, 2.0)
	reflected = false
	frozen_t = 0.0
	freeze_hook_tag = ""
	mode = str(cfg.get("mode", "linear"))
	orbit_center = cfg.get("orbit_center", p_pos) as Vector2
	orbit_follow_boss = bool(cfg.get("orbit_follow_boss", false))
	orbit_radius = float(cfg.get("orbit_radius", 24.0))
	orbit_target_radius = float(cfg.get("orbit_target_radius", 44.0))
	orbit_angle = float(cfg.get("orbit_angle", dir.angle()))
	orbit_omega = float(cfg.get("orbit_omega", 2.0))
	return_time = maxf(0.25, float(cfg.get("return_time", 0.72)))
	curve_rate = float(cfg.get("curve_rate", 0.0))
	returning = false


func deactivate() -> void:
	active = false
	frozen_t = 0.0
	reflected = false


func freeze(duration: float, tag: String = "hook") -> void:
	if not active:
		return
	frozen_t = maxf(frozen_t, maxf(0.1, duration))
	freeze_hook_tag = tag


func reflect(new_dir: Vector2, speed_mult: float = 1.35) -> bool:
	if not active or not reflectable or reflected:
		return false
	reflected = true
	frozen_t = 0.0
	mode = "linear"
	dir = new_dir.normalized() if new_dir.length_squared() > 0.0001 else -dir
	speed = clampf(speed * speed_mult, 120.0, MAX_SPEED)
	vel = dir * speed
	color_key = "ice"
	core_key = "cream"
	age = 0.0
	max_age = maxf(max_age, 2.6)
	return true


func step_motion(dt: float, world_ctx: Node, boss_pos: Vector2) -> void:
	if not active:
		return
	prev_pos = pos
	if frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		return
	age += dt
	if age >= max_age:
		deactivate()
		return

	if mode == "orbit" and not reflected:
		if orbit_follow_boss:
			orbit_center = boss_pos
		orbit_radius = move_toward(orbit_radius, orbit_target_radius, 64.0 * dt)
		orbit_angle = wrapf(orbit_angle + orbit_omega * dt, -PI, PI)
		pos = orbit_center + Vector2.from_angle(orbit_angle) * orbit_radius
		var tangent: Vector2 = Vector2.from_angle(orbit_angle + (PI * 0.5 if orbit_omega >= 0.0 else -PI * 0.5))
		dir = tangent
		vel = tangent * absf(orbit_omega) * orbit_radius
		return

	if mode == "boomerang" and not reflected:
		if not returning and age >= return_time:
			returning = true
			var to_start: Vector2 = start_pos - pos
			if to_start.length_squared() > 4.0:
				dir = to_start.normalized()
			else:
				dir = -dir
			vel = dir * speed
		elif not returning and absf(curve_rate) > 0.001:
			dir = dir.rotated(curve_rate * dt).normalized()
			vel = dir * speed
		elif returning:
			var to_home: Vector2 = start_pos - pos
			if to_home.length() <= maxf(8.0, speed * dt * 1.4):
				deactivate()
				return
			dir = dir.lerp(to_home.normalized(), minf(1.0, dt * 6.0)).normalized()
			vel = dir * speed

	if field_scale > 0.001:
		var accel: Vector2 = sample_fields(pos, world_ctx) * field_scale
		if accel.length_squared() > 0.01:
			vel += accel * dt
			var spd: float = clampf(vel.length(), MIN_SPEED, MAX_SPEED)
			if vel.length_squared() > 0.0001:
				dir = vel.normalized()
				vel = dir * spd

	pos += vel * dt


static func sample_fields(p: Vector2, world_ctx: Node) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	if not _fields_checked:
		_fields_checked = true
		if ResourceLoader.exists("res://luxel/world/fields.gd"):
			var res: Resource = ResourceLoader.load("res://luxel/world/fields.gd")
			if res != null:
				_fields_script = res
	if _fields_script != null and _fields_script.has_method("accel_at"):
		var fv: Variant = _fields_script.call("accel_at", p, "bolt")
		if fv is Vector2:
			out += fv as Vector2
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("accel_at"):
		var wv: Variant = world_ctx.call("accel_at", p, "bolt")
		if wv is Vector2:
			out += wv as Vector2
	return out


func draw_bolt(ci: CanvasItem, local_off: Vector2, clock: float, flash_red: bool) -> void:
	if not active:
		return
	var p: Vector2 = (pos + local_off).round()
	var r: float = radius
	var rim_col: Color = LxPalette.color("ice" if frozen_t > 0.0 else color_key, "coral")
	var core_col: Color = LxPalette.color(core_key, "cream")
	var void_col: Color = PAL["void"] as Color

	# Tail streak for readable motion direction
	if frozen_t <= 0.0 and vel.length_squared() > 64.0:
		var tail: Vector2 = (p - dir * minf(10.0, r * 2.2)).round()
		ci.draw_line(tail, p, void_col, r + 1.6)
		ci.draw_line(tail, p, rim_col, maxf(1.2, r * 0.7))

	ci.draw_circle(p, r + 1.2, void_col)
	ci.draw_circle(p, r, rim_col)
	var pulse_r: float = maxf(1.2, r * (0.55 if flash_red else (0.50 + 0.12 * sin(clock * 14.0))))
	ci.draw_circle(p, pulse_r, core_col)

	if frozen_t > 0.0:
		var fr: float = r + 2.4
		ci.draw_line(p + Vector2(-fr, 0.0), p + Vector2(fr, 0.0), PAL["ice"] as Color, 1.0)
		ci.draw_line(p + Vector2(0.0, -fr), p + Vector2(0.0, fr), PAL["ice"] as Color, 1.0)
	elif mode == "boomerang" and returning:
		ci.draw_arc(p, r + 2.0, 0.0, TAU, 10, PAL["gold"] as Color, 1.0)
