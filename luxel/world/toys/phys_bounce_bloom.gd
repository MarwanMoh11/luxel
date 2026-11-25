class_name LxPhysBounceBloom
extends LxToy
## Living spring pad that launches Wick (or orbs / sliding blocks) in `dir` for `dist` px,
## crossing pits and water cleanly.

const LAUNCH_SPEED: float = 240.0

var launch_dir: Vector2 = Vector2.RIGHT
var dist: float = 64.0
var _spring_t: float = 0.0
var _trigger_cd: float = 0.0


func _toy_setup() -> void:
	kind = "bounce_bloom"
	size = _parse_size(props.get("size", [18.0, 18.0]), Vector2(18.0, 18.0))
	radius = maxf(9.0, maxf(size.x, size.y) * 0.5)
	launch_dir = dir_vec("dir", Vector2.RIGHT)
	dist = maxf(24.0, float(props.get("dist", 64.0)))
	_spring_t = 0.0
	_trigger_cd = 0.0
	z_index = LxPhysDraw.floor_z(region, -3)
	queue_redraw()


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	_spring_t = 0.24
	_emit_sfx("spore_pop")
	queue_redraw()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _spring_t > 0.0:
		_spring_t = maxf(0.0, _spring_t - dt)
		dirty = true
	if _trigger_cd > 0.0:
		_trigger_cd = maxf(0.0, _trigger_cd - dt)
	if active and _trigger_cd <= 0.0:
		var trigger_r := Rect2(pos - size * 0.45, size * 0.9)
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and not w.is_launched() and not w.is_mounted() and trigger_r.has_point(w.global_position):
				var secs: float = clampf(dist / LAUNCH_SPEED, 0.12, 0.95)
				w.launch(launch_dir, LAUNCH_SPEED, secs)
				w.spawn_sparks(pos, launch_dir, 6, biome("glow"), 35.0, 95.0, 0.22)
				_spring_t = 0.32
				_trigger_cd = 0.28
				_emit_sfx("spore_pop")
				dirty = true
		# Also bounce carry_orb and sliding push_blocks
		if region != null and region.has_method("get_interactables"):
			for it_v: Variant in region.call("get_interactables") as Array:
				if not is_instance_valid(it_v) or it_v == self or not (it_v is LxInteractable):
					continue
				var it: LxInteractable = it_v as LxInteractable
				if not it.active or not trigger_r.has_point(it.pos):
					continue
				if it.kind == "carry_orb" and it.has_method("on_thrown"):
					it.call("on_thrown", pos + launch_dir * 8.0, launch_dir, 200.0)
					_spring_t = 0.28
					_trigger_cd = 0.25
					_emit_sfx("spore_pop")
					dirty = true
				elif it.kind == "push_block" and it.has_method("start_ice_slide"):
					if bool(it.call("start_ice_slide", launch_dir)):
						_spring_t = 0.28
						_trigger_cd = 0.25
						dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var swell: float = sin(clampf(_spring_t / 0.32, 0.0, 1.0) * PI) * 3.0 if _spring_t > 0.0 else 0.0
	var r: float = 8.0 + swell
	_draw_ground_shadow(r, r * 0.6, Vector2(1.0, 3.0))
	# Outer botanical/biome cap petals
	var c_dark: Color = biome("dark")
	var c_mid: Color = biome("mid")
	var c_hi: Color = biome("hi")
	var c_glow: Color = biome("glow")
	draw_circle(Vector2.ZERO, r + 1.0, PAL["void"] as Color)
	draw_circle(Vector2.ZERO, r, c_dark)
	draw_circle(Vector2(0.0, -1.0), r - 1.5, c_mid)
	for i: int in range(6):
		var a: float = float(i) * (TAU / 6.0) + _clock * 0.4
		var pp: Vector2 = (Vector2.from_angle(a) * (r - 3.0)).round()
		draw_rect(Rect2(pp - Vector2.ONE, Vector2(2.0, 2.0)), c_hi)
	draw_circle(Vector2(0.0, -1.0), 3.0, c_glow)
	# Crisp directional launch chevron
	LxPhysDraw.draw_chevron(self, launch_dir * 2.0, launch_dir, PAL["cream"] as Color, PAL["void"] as Color, 3.5)
