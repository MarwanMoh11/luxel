class_name LxLanternPickup
extends LxInteractable
## Wick's resting brass lantern on Island 1 Sundial Plaza.
## Casts an inviting warm pool of light; auto-collects on walk-over (<= 18 px)
## or via [E] interact (<= 26 px) with zero text popup, granting Bolt + Lantern Throw.

const AUTO_PICKUP_R: float = 18.0
const INTERACT_PICKUP_R: float = 26.0
const PICKUP_FX_DUR: float = 0.45

var collected: bool = false
var _pickup_t: float = 0.0
var _anim_frame: int = 0


func _ready() -> void:
	super._ready()
	_sync_already_owned()


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "lantern_pickup"
	radius = maxf(14.0, float(spec.get("radius", props.get("radius", 20.0))))
	collected = bool(props.get("collected", false))
	_pickup_t = 0.0
	_anim_frame = 0
	active = not collected
	visible = active
	_sync_already_owned()
	queue_redraw()


func _sync_already_owned() -> void:
	if _pickup_t > 0.0:
		return
	if collected or (Lx.state != null and Lx.state.has_lantern()):
		collected = true
		active = false
		visible = false


func tick(dt: float) -> void:
	super.tick(dt)
	if _pickup_t > 0.0:
		_pickup_t = maxf(0.0, _pickup_t - dt)
		if _pickup_t <= 0.0:
			visible = false
		queue_redraw()
		return
	if collected or not active:
		return
	if Lx.state != null and Lx.state.has_lantern():
		_sync_already_owned()
		return
	var rate: float = 4.0 if LxHudFx.flash_reduced() else 10.0
	var fr: int = int(floorf(_clock * rate + absf(pos.x * 0.05)))
	if fr != _anim_frame:
		_anim_frame = fr
		queue_redraw()
	_check_auto_pickup()


func _check_auto_pickup() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var w: Node2D = Lx.player as Node2D
	if w.get("dead") is bool and bool(w.get("dead")):
		return
	if w.global_position.distance_to(pos) <= AUTO_PICKUP_R:
		_collect(w)


func interact(actor: Node = null) -> bool:
	if collected or not active:
		return false
	if actor is Node2D and is_instance_valid(actor):
		if (actor as Node2D).global_position.distance_to(pos) > INTERACT_PICKUP_R:
			return false
	return _collect(actor)


func _collect(_actor: Node) -> bool:
	if collected or not active:
		return false
	collected = true
	active = false
	visible = true
	_pickup_t = PICKUP_FX_DUR

	if Lx.state != null:
		Lx.state.grant_lantern()

	var fr_scale: float = 0.65 if LxHudFx.flash_reduced() else 1.0
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 118.0, 1.65 * fr_scale, 0.52)
		LxDarknessLayer.active_instance.trigger_focus_flash(0.55)
	_emit_gust(84.0, 72.0, Vector2(0.0, -4.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 16.0, 6.0)
	if Lx.events != null:
		Lx.events.hitstop_requested.emit(0.065)
		Lx.events.shake_requested.emit(0.10)
		Lx.events.sfx_requested.emit("lamp_lit", pos, true)
		Lx.events.sfx_requested.emit("shrine_claimed", pos, false)
		Lx.events.lantern_picked_up.emit(id, global_position)
	elif Lx.audio != null:
		Lx.audio.play_sfx("lamp_lit", pos, true)
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("trigger_focus_nudge"):
		Lx.camera.trigger_focus_nudge(Vector2(574.0, 366.0), 0.70)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("lantern_pickup")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return ""


func get_light_pool() -> Vector4:
	if _pickup_t > 0.0:
		var u: float = 1.0 - clampf(_pickup_t / PICKUP_FX_DUR, 0.0, 1.0)
		var surge: float = sin(u * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 4.0, 74.0 + surge * 54.0, 1.48 * (1.0 - u * 0.65))
	if collected or not active:
		return Vector4.ZERO
	var fr: bool = LxHudFx.flash_reduced()
	var breath: float = 0.0 if fr else sin(_clock * 3.8) * 3.5
	return Vector4(pos.x, pos.y - 4.0, 76.0 + breath, 1.38)


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected))
	active = not collected
	visible = active
	_sync_already_owned()
	queue_redraw()


func _draw_pixel_ellipse(center: Vector2, rx: float, ry: float, segs: int, col: Color) -> void:
	if col.a <= 0.0:
		return
	for i: int in range(segs):
		var a: float = float(i) * TAU / float(segs)
		draw_rect(Rect2(roundf(center.x + cos(a) * rx), roundf(center.y + sin(a) * ry), 1.0, 1.0), col)


func _draw() -> void:
	if _pickup_t > 0.0:
		_draw_pickup_burst()
		return
	if collected or not active:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var center := Vector2(0.0, -3.0)

	# Crisp pixel-stepped warm stone halo matching tutorial_cues.gd (zero translucent ring clash)
	var flk: bool = fr or fmod(_clock * 3.2, 1.0) < 0.58
	_draw_pixel_ellipse(Vector2(0.0, 1.0), 10.0, 4.0, 16, LxPalette.color("apricot" if flk else "coral"))
	_draw_pixel_ellipse(Vector2(0.0, 1.0), 7.0, 3.0, 12, LxPalette.color("gold" if flk else "apricot"))

	# Clean opaque Last Light contact shadow beneath resting brass lantern
	draw_rect(Rect2(-5.0, 2.0, 10.0, 2.0), LxPalette.color("void"))
	draw_rect(Rect2(-4.0, 1.0, 8.0, 4.0), LxPalette.color("night"))
	draw_rect(Rect2(-3.0, 2.0, 6.0, 2.0), LxPalette.color("void"))

	# Resting brass handle (curved bail) & iron cap
	draw_rect(Rect2(center + Vector2(-1.0, -7.0), Vector2(2.0, 1.0)), LxPalette.color("gold"))
	draw_rect(Rect2(center + Vector2(-2.0, -6.0), Vector2(1.0, 1.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(1.0, -6.0), Vector2(1.0, 1.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(-2.0, -5.0), Vector2(4.0, 1.0)), LxPalette.color("night"))
	draw_rect(Rect2(center + Vector2(-1.0, -5.0), Vector2(2.0, 1.0)), LxPalette.color("dusk"))
	draw_rect(Rect2(center + Vector2(-4.0, -4.0), Vector2(8.0, 1.0)), LxPalette.color("night"))
	draw_rect(Rect2(center + Vector2(-3.0, -4.0), Vector2(6.0, 1.0)), LxPalette.color("dusk"))

	# Glass chamber & warm flickering flame core
	draw_rect(Rect2(center + Vector2(-4.0, -3.0), Vector2(8.0, 6.0)), LxPalette.color("night"))
	draw_rect(Rect2(center + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), LxPalette.color("gold"))
	var sway_x: float = 0.0 if fr else roundf(sin(_clock * 6.8) * 0.65)
	draw_rect(Rect2(center + Vector2(-1.0 + sway_x, -1.0), Vector2(2.0, 2.0)), LxPalette.color("cream"))
	draw_rect(Rect2(center + Vector2(sway_x, -2.0), Vector2(1.0, 1.0)), LxPalette.color("cream"))

	# Brass cage struts & resting plinth
	draw_rect(Rect2(center + Vector2(-4.0, -2.0), Vector2(1.0, 4.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(3.0, -2.0), Vector2(1.0, 4.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(-4.0, -1.0), Vector2(1.0, 2.0)), LxPalette.color("gold"))
	draw_rect(Rect2(center + Vector2(3.0, -1.0), Vector2(1.0, 2.0)), LxPalette.color("gold"))
	draw_rect(Rect2(center + Vector2(-2.0, -3.0), Vector2(1.0, 6.0)), LxPalette.color("coral"))
	draw_rect(Rect2(center + Vector2(1.0, -3.0), Vector2(1.0, 6.0)), LxPalette.color("coral"))
	draw_rect(Rect2(center + Vector2(-3.0, 3.0), Vector2(6.0, 1.0)), LxPalette.color("night"))
	draw_rect(Rect2(center + Vector2(-2.0, 3.0), Vector2(4.0, 1.0)), LxPalette.color("dusk"))
	draw_rect(Rect2(center + Vector2(-2.0, 4.0), Vector2(4.0, 1.0)), LxPalette.color("apricot"))
	draw_rect(Rect2(center + Vector2(-1.0, 4.0), Vector2(2.0, 1.0)), LxPalette.color("gold"))

	# Gentle rising warmth shimmer motes + subtle glass twinkle
	for mi: int in range(3):
		var ph: float = fmod(_clock * (0.34 if fr else 0.62) + float(mi) * 0.333, 1.0)
		var mx: float = roundf(sin(_clock * 1.9 + float(mi) * 2.1) * (4.0 + ph * 3.5))
		var my: float = roundf(-2.0 - ph * 14.0)
		var mcol: Color = LxPalette.fade_step(sin(ph * PI), "cream" if ph < 0.3 else ("gold" if ph < 0.72 else "apricot"))
		if mcol.a > 0.0:
			draw_rect(Rect2(mx, my, 1.0, 1.0), mcol)
	if not fr and fmod(_clock * 1.4, 1.0) < 0.25:
		var gpos := Vector2(3.0, -7.0)
		draw_rect(Rect2(gpos + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), LxPalette.color("cream"))
		draw_rect(Rect2(gpos + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), LxPalette.color("cream"))


func _draw_pickup_burst() -> void:
	var u: float = 1.0 - clampf(_pickup_t / PICKUP_FX_DUR, 0.0, 1.0)
	var fade: float = 1.0 - u
	var center := Vector2(0.0, -4.0)
	var c_gold: Color = LxPalette.fade_step(fade, "gold")
	var c_cream: Color = LxPalette.fade_step(fade, "cream")
	_draw_pixel_ellipse(center, roundf(lerpf(4.0, 28.0, u)), roundf(lerpf(4.0, 28.0, u)), 24, c_gold)
	_draw_pixel_ellipse(center, roundf(lerpf(2.0, 19.0, u)), roundf(lerpf(2.0, 19.0, u)), 18, c_cream)
	for k: int in range(10):
		var ang: float = (TAU * float(k)) / 10.0 + u * 0.35
		var dist: float = lerpf(3.0, 26.0, u)
		var sp := Vector2(roundf(cos(ang) * dist), roundf(center.y + sin(ang) * dist - u * 5.0))
		var scol: Color = c_cream if k % 2 == 0 else c_gold
		if scol.a > 0.0:
			draw_rect(Rect2(sp, Vector2.ONE), scol)
