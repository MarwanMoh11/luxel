class_name LxPhysSpinner
extends LxToy
## Rotating multi-arm hazard beam hub.
## Readable rotating ember tips; dash i-frames and Wings glide clear the beam cleanly.

const HUB_RADIUS: float = 6.0

var length: float = 36.0
var speed: float = 1.6
var arms: int = 2
var angle: float = 0.0
var _hit_cd: float = 0.0


func _toy_setup() -> void:
	kind = "spinner"
	length = maxf(14.0, float(props.get("length", 36.0)))
	speed = float(props.get("speed", 1.6))
	arms = clampi(int(props.get("arms", 2)), 1, 6)
	angle = deg_to_rad(float(props.get("start_deg", 0.0)))
	radius = HUB_RADIUS
	_hit_cd = 0.0
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(HUB_RADIUS, HUB_RADIUS), Vector2(HUB_RADIUS * 2.0, HUB_RADIUS * 2.0)) if active else Rect2()


func _effective_speed() -> float:
	var sig_mode: String = str(props.get("on_signal", "stop")).strip_edges().to_lower()
	if powered:
		if sig_mode == "reverse":
			return -speed
		if sig_mode == "stop":
			return 0.0
	return speed


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var eff_spd: float = _effective_speed()
	angle = fposmod(angle + eff_spd * dt, TAU)
	_hit_cd = maxf(0.0, _hit_cd - dt)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_gliding() and not w.is_launched() and _hit_cd <= 0.0:
			var wpos: Vector2 = w.global_position
			if wpos.distance_squared_to(pos) <= (length + 6.0) * (length + 6.0):
				for i: int in range(arms):
					var a: float = angle + (TAU * float(i)) / float(arms)
					var adir := Vector2.from_angle(a)
					var tip: Vector2 = pos + adir * length
					var cp: Vector2 = Geometry2D.get_closest_point_to_segment(wpos, pos + adir * HUB_RADIUS, tip)
					if cp.distance_to(wpos) <= 5.5:
						var tang := Vector2(-adir.y, adir.x) * (1.0 if eff_spd >= 0.0 else -1.0)
						w.take_damage(1.0, cp, (tang + (wpos - pos).normalized() * 0.4).normalized(), "spinner")
						_hit_cd = 0.45
						break
		LxPhysDraw.safe_eject_wick(w, get_solid_rect(), region, id)
	queue_redraw()


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y, 26.0, 0.45) if active else Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["angle"] = angle
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("angle"):
		angle = float(d.get("angle", angle))
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var moving: bool = absf(_effective_speed()) > 0.01
	var c_arm: Color = PAL["coral"] as Color if moving else PAL["mauve"] as Color
	var c_tip: Color = PAL["gold"] as Color if (red or fmod(_clock * 6.0, 1.0) < 0.5) else PAL["cream"] as Color
	# Sweep ring hint on floor
	draw_arc(Vector2.ZERO, length, 0.0, TAU, 24, Color(PAL["dusk"] as Color, 0.35), 1.0)
	# Rotating arms with shadow + beads
	for i: int in range(arms):
		var a: float = angle + (TAU * float(i)) / float(arms)
		var adir := Vector2.from_angle(a)
		var tip: Vector2 = (adir * length).round()
		draw_line(Vector2(1.0, 2.0), tip + Vector2(1.0, 2.0), Color(PAL["void"] as Color, 0.40), 2.0)
		draw_line(Vector2.ZERO, tip, PAL["night"] as Color, 3.0)
		draw_line(Vector2.ZERO, tip, c_arm, 1.0)
		var d_px: float = 10.0
		while d_px < length - 3.0:
			var bp: Vector2 = (adir * d_px).round()
			draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["apricot"] as Color if moving else PAL["stone"] as Color)
			d_px += 8.0
		draw_rect(Rect2(tip - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), PAL["void"] as Color)
		draw_rect(Rect2(tip - Vector2.ONE, Vector2(2.0, 2.0)), c_tip if moving else PAL["stone"] as Color)
	# Center beveled gear hub
	var hr := Rect2(-HUB_RADIUS, -HUB_RADIUS, HUB_RADIUS * 2.0, HUB_RADIUS * 2.0)
	LxPhysDraw.draw_shadow_rect(self, hr, Vector2(1.0, 2.0), 0.45)
	LxPhysDraw.draw_bevel_box(self, hr, PAL["dusk"] as Color, PAL["stone"] as Color, PAL["night"] as Color, PAL["void"] as Color, biome("hi"))
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), biome("glow") if moving else PAL["plum"] as Color)
