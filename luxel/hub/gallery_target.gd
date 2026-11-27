class_name LxGalleryTarget
extends LxInteractable
## Dynamic target interactable spawned by Shooting Gallery & Lantern Juggling minigames.
## Supports manual-aim bolts, Prism blue-bounce targets, Gravity-curved targets, and Throw/Recall/Zip motes.

signal target_scored(target: LxGalleryTarget, hit: LxHit, points: int)

var mode: String = "classic" # "classic", "prism", "curve", "juggle"
var points_base: int = 10
var move_origin: Vector2 = Vector2.ZERO
var move_amp: Vector2 = Vector2.ZERO
var move_speed: float = 0.0
var lifetime: float = 7.0
var age: float = 0.0
var hit_done: bool = false
var _phase: float = 0.0
var _reject_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "gallery_target"
	radius = maxf(10.0, float(props.get("radius", 10.0)))
	mode = str(props.get("mode", "classic"))
	points_base = int(props.get("points", 10))
	lifetime = maxf(2.0, float(props.get("lifetime", 7.0)))
	move_origin = pos
	move_amp = _parse_vec2(props.get("amp", [0.0, 0.0]), Vector2.ZERO)
	move_speed = float(props.get("speed", 0.0))
	_phase = float(props.get("phase", 0.0))
	age = 0.0
	hit_done = false
	_reject_t = 0.0
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if not active or hit_done or hit == null:
		return false
	var pts: int = points_base
	match mode:
		"prism":
			if not hit.is_blue():
				_reject_t = 0.24
				_emit_sfx("shield_clang")
				queue_redraw()
				return true
			pts = points_base * 2
		"curve":
			if hit.curve_angle_deg < 8.0 and not hit.is_blue():
				_reject_t = 0.24
				_emit_sfx("shield_clang")
				queue_redraw()
				return true
			pts = points_base * 2
		"juggle":
			if hit.source not in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]:
				_reject_t = 0.24
				_emit_sfx("shield_clang")
				queue_redraw()
				return false
			pts = 4 if hit.source == LxHit.SOURCE_ZIP else (3 if hit.source == LxHit.SOURCE_RECALL else 2)
		_:
			if age < 1.3:
				pts += 5 # Quick-draw bullseye bonus
	hit_done = true
	active = false
	visible = false
	_emit_sfx("prop_chime" if mode == "juggle" else "switch_on")
	target_scored.emit(self, hit, pts)
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or hit_done:
		return
	age += dt
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
	_phase += dt * move_speed
	if move_amp.length_squared() > 0.1:
		pos = move_origin + Vector2(sin(_phase) * move_amp.x, cos(_phase) * move_amp.y)
		position = pos.round()
	if age >= lifetime:
		active = false
		visible = false
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active or hit_done:
		return Vector4.ZERO
	var fr: bool = LxHudFx.flash_reduced()
	return Vector4(pos.x, pos.y - 6.0, 32.0 if fr else 34.0, 0.58 if fr else 0.72)


func _draw() -> void:
	if not active or hit_done:
		return
	var fr: bool = LxHudFx.flash_reduced()
	_draw_ground_shadow(6.0, 2.0, Vector2(0.0, 2.0))
	var bob: float = 0.0 if fr else roundf(sin(_clock * 5.0) * 1.0)
	var shake_x: float = 0.0 if (fr or _reject_t <= 0.0) else roundf(sin(_reject_t * 42.0) * 1.0)
	var c := Vector2(shake_x, -8.0 + bob)
	var c_void: Color = LxPalette.PAL["void"]
	var c_night: Color = LxPalette.PAL["night"]
	var c_cream: Color = LxPalette.PAL["cream"]
	var rim_c: Color = LxPalette.PAL["sky"] if mode == "prism" else (LxPalette.PAL["rose"] if mode == "curve" else (LxPalette.PAL["lime"] if mode == "juggle" else LxPalette.PAL["coral"]))
	var core_c: Color = LxPalette.PAL["ice"] if mode == "prism" else (c_cream if mode == "juggle" else LxPalette.PAL["gold"])
	if _reject_t > 0.0:
		rim_c = LxPalette.PAL["stone"] if fr else LxPalette.PAL["mauve"]

	match mode:
		"prism":
			# Stepped crystal diamond silhouette (requires blue prism bounce)
			draw_rect(Rect2(c + Vector2(-2.0, -8.0), Vector2(4.0, 16.0)), c_void)
			draw_rect(Rect2(c + Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), c_void)
			draw_rect(Rect2(c + Vector2(-8.0, -2.0), Vector2(16.0, 4.0)), c_void)
			draw_rect(Rect2(c + Vector2(-1.0, -7.0), Vector2(2.0, 14.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-7.0, -1.0), Vector2(14.0, 2.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-2.0, -3.0), Vector2(4.0, 6.0)), c_night)
			draw_rect(Rect2(c + Vector2(-3.0, -2.0), Vector2(6.0, 4.0)), c_night)
			draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(2.0, 4.0)), core_c)
			draw_rect(Rect2(c + Vector2(-2.0, -1.0), Vector2(4.0, 2.0)), core_c)
			draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(1.0, 1.0)), c_cream)
		"curve":
			# Orbital crescent-bracket silhouette (requires curved gravity shot)
			draw_rect(Rect2(c + Vector2(-8.0, -5.0), Vector2(4.0, 10.0)), c_void)
			draw_rect(Rect2(c + Vector2(4.0, -5.0), Vector2(4.0, 10.0)), c_void)
			draw_rect(Rect2(c + Vector2(-7.0, -4.0), Vector2(2.0, 8.0)), rim_c)
			draw_rect(Rect2(c + Vector2(5.0, -4.0), Vector2(2.0, 8.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), c_void)
			draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), c_night)
			draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), core_c)
			draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(2.0, 1.0)), c_cream)
		"juggle":
			# Winged moth mote silhouette (for Throw / Recall / Zip chains)
			var flap: float = 0.0 if fr else roundf(sin(_clock * 12.0) * 1.0)
			draw_rect(Rect2(c + Vector2(-9.0, -5.0 + flap), Vector2(18.0, 7.0)), c_void)
			draw_rect(Rect2(c + Vector2(-8.0, -4.0 + flap), Vector2(5.0, 5.0)), LxPalette.PAL["jade"])
			draw_rect(Rect2(c + Vector2(3.0, -4.0 + flap), Vector2(5.0, 5.0)), LxPalette.PAL["jade"])
			draw_rect(Rect2(c + Vector2(-7.0, -3.0 + flap), Vector2(3.0, 3.0)), rim_c)
			draw_rect(Rect2(c + Vector2(4.0, -3.0 + flap), Vector2(3.0, 3.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-4.0, -5.0), Vector2(8.0, 10.0)), c_void)
			draw_rect(Rect2(c + Vector2(-3.0, -4.0), Vector2(6.0, 8.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-2.0, -3.0), Vector2(4.0, 6.0)), LxPalette.PAL["gold"])
			draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(2.0, 3.0)), core_c)
		_:
			# Classic brass-lugged bullseye target (+ quick-draw cream glint when age < 1.3)
			draw_rect(Rect2(c + Vector2(-7.0, -7.0), Vector2(14.0, 14.0)), c_void)
			draw_rect(Rect2(c + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), rim_c)
			draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), c_night)
			draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), core_c)
			if age < 1.3:
				draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), c_cream)

	# Remaining lifetime bar
	var frac: float = clampf(1.0 - age / maxf(lifetime, 0.1), 0.0, 1.0)
	var bar_c: Color = LxPalette.PAL["coral"] if frac < 0.28 else core_c
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_void)
	draw_rect(Rect2(-6.0, 1.0, roundf(12.0 * frac), 2.0), bar_c)
