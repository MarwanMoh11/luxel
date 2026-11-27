class_name LxMsWeatherBuoy
extends LxToy
## Floating Skylight Mirror Buoy (mausoleum_r4 & mausoleum_r8):
## Place the room's movable `blue_transformer` (`mirror_id`) onto the buoy in SUN,
## arm the elevation pin (via `light_sensor` signal OR `shoot_latch` strike in RAIN),
## and flood the basin in RAIN to lift the mirror onto the brass skylight pin (`latched = true`)!
## Once latched, the mirror stays elevated when you return to SUN, firing `target_id` / `sets_flag`.
## Props: mirror_id (String), dock_radius (float, default 22.0), shoot_latch (bool, default false),
## needs_arm_signal (bool, default true), sets_flag (String), persist (bool), target_id/target_ids.

var mirror_id: String = ""
var dock_radius: float = 22.0
var shoot_latch: bool = false
var needs_arm_signal: bool = true

var mirror_docked: bool = false
var pin_armed: bool = false
var floating: bool = false
var latched: bool = false
var _lift_vis: float = 0.0
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "ms_weather_buoy"
	z_index = -4
	mirror_id = str(props.get("mirror_id", "")).strip_edges()
	dock_radius = maxf(14.0, float(props.get("dock_radius", 22.0)))
	shoot_latch = bool(props.get("shoot_latch", false))
	needs_arm_signal = bool(props.get("needs_arm_signal", not shoot_latch))
	radius = maxf(14.0, dock_radius * 0.75)
	mirror_docked = false
	pin_armed = not needs_arm_signal and not shoot_latch
	floating = false
	latched = powered
	_lift_vis = 1.0 if latched else 0.0
	_flash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and latched:
		return
	pin_armed = not needs_arm_signal and not shoot_latch
	floating = false
	latched = false
	_lift_vis = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func on_signal(_from_id: String, active_sig: bool) -> void:
	if not active:
		return
	if active_sig and not pin_armed:
		pin_armed = true
		_flash_t = 0.35
		_emit_sfx("switch_eye")
		_check_latch_elevation()
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not shoot_latch:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		_update_mirror_docked()
		var w: String = _current_weather()
		if mirror_docked and w == "rain":
			pin_armed = true
			_flash_t = 0.40
			_check_latch_elevation()
			queue_redraw()
			return true
		_flash_t = 0.22
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func interact(_actor: Node = null) -> bool:
	if not active or not shoot_latch:
		return false
	_update_mirror_docked()
	if mirror_docked and _current_weather() == "rain":
		pin_armed = true
		_flash_t = 0.40
		_check_latch_elevation()
		queue_redraw()
		return true
	return false


func on_weather_changed(_new_weather: String, _wind_dir: Vector2) -> void:
	_update_mirror_docked()
	_check_latch_elevation()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	var prev_dock: bool = mirror_docked
	var prev_float: bool = floating
	_update_mirror_docked()
	var w: String = _current_weather()
	floating = (w == "rain") or latched
	if prev_dock != mirror_docked or prev_float != floating:
		dirty = true
	_check_latch_elevation()
	var target_lift: float = 1.0 if (latched or (floating and mirror_docked)) else (0.55 if floating else 0.0)
	if not is_equal_approx(_lift_vis, target_lift):
		_lift_vis = move_toward(_lift_vis, target_lift, dt * 3.2)
		dirty = true
	if dirty:
		queue_redraw()


func _update_mirror_docked() -> void:
	mirror_docked = false
	if region == null or not region.has_method("find_interactable") or mirror_id.is_empty():
		return
	var m_v: Variant = region.call("find_interactable", mirror_id)
	if m_v is LxInteractable and is_instance_valid(m_v):
		var m: LxInteractable = m_v as LxInteractable
		if m.active and m.pos.distance_to(pos) <= dock_radius:
			mirror_docked = true


func _check_latch_elevation() -> void:
	if latched:
		return
	var w: String = _current_weather()
	if mirror_docked and pin_armed and w == "rain":
		latched = true
		floating = true
		_flash_t = 0.55
		# Snap mirror cleanly onto buoy center so skylight beam aligns pixel-accurately
		if region != null and region.has_method("find_interactable") and not mirror_id.is_empty():
			var m_v: Variant = region.call("find_interactable", mirror_id)
			if m_v is LxInteractable and is_instance_valid(m_v):
				var m: LxInteractable = m_v as LxInteractable
				if m.has_method("move_to"):
					m.call("move_to", pos)
		var sf: String = str(props.get("sets_flag", "")).strip_edges()
		if not sf.is_empty() and Lx.state != null:
			Lx.state.story_flags[sf] = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("ms_buoy_latch")
		_emit_gust(62.0, 44.0)
		if region != null and region.has_method("apply_layers"):
			region.call("apply_layers", true)


func _current_weather() -> String:
	if Lx.vars != null:
		return str(Lx.vars.resolve_var("weather", island_id, region_id, "rain")).strip_edges().to_lower()
	return "rain"


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - Vector2(16.0, 16.0), Vector2(32.0, 32.0)) if active else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if latched:
		return Vector4(pos.x, pos.y - 4.0, 52.0, 0.85)
	if pin_armed or mirror_docked:
		return Vector4(pos.x, pos.y - 2.0, 34.0, 0.52)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["latched"] = latched
		d["pin_armed"] = pin_armed
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("latched"):
		latched = bool(d["latched"])
		pin_armed = bool(d.get("pin_armed", pin_armed))
		powered = latched
		_lift_vis = 1.0 if latched else 0.0
		if latched:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	# Outer sunken cistern buoy well
	draw_rect(Rect2(-16.0, -16.0, 32.0, 32.0), c_void)
	draw_rect(Rect2(-15.0, -15.0, 30.0, 30.0), c_deep if floating else c_night)
	draw_rect(Rect2(-14.0, -14.0, 28.0, 28.0), Color(c_sky, (0.18 if fred else 0.25) if floating else 0.08))

	# Rising wooden/bronze buoy raft pad + grounded dry chocks vs floating foam collar
	var lift_y: float = -roundf(_lift_vis * 5.0)
	var pad := Rect2(-12.0, -12.0 + lift_y, 24.0, 24.0)
	if floating:
		draw_rect(Rect2(-13.0, -13.0 + lift_y, 26.0, 26.0), Color(c_ice, 0.34 if fred else 0.55))
	else:
		draw_rect(Rect2(-13.0, -2.0, 2.0, 4.0), c_stone)
		draw_rect(Rect2(11.0, -2.0, 2.0, 4.0), c_stone)
	LxToyDraw.draw_bevel_box(self, pad, c_night, PAL["dusk"] as Color, c_gold if latched else (c_sky if floating else c_stone), c_void)

	# Four corner elevation latch pins: recessed sockets (unarmed) vs raised pins (armed) vs locked 4x4 clamps (latched)
	var flash_hi: bool = _flash_t > 0.0 and not fred
	var pin_c: Color = c_cream if flash_hi else (c_gold if latched else (c_ice if pin_armed else PAL["mauve"] as Color))
	for off_p: Vector2 in [Vector2(-13.0, -13.0), Vector2(10.0, -13.0), Vector2(-13.0, 10.0), Vector2(10.0, 10.0)]:
		if latched:
			draw_rect(Rect2(off_p - Vector2(0.0, 1.0), Vector2(4.0, 4.0)), c_void)
			draw_rect(Rect2(off_p, Vector2(3.0, 3.0)), pin_c)
			draw_rect(Rect2(off_p + Vector2.ONE, Vector2.ONE), c_cream)
		elif pin_armed:
			draw_rect(Rect2(off_p, Vector2(3.0, 3.0)), c_void)
			draw_rect(Rect2(off_p + Vector2.ONE, Vector2(2.0, 2.0)), pin_c)
		else:
			draw_rect(Rect2(off_p, Vector2(3.0, 3.0)), c_void)
			draw_rect(Rect2(off_p + Vector2.ONE, Vector2(2.0, 1.0)), pin_c)

	# Center alignment target ring + 4-way cardinal lock ticks when latched
	var mid_c: Color = c_gold if (latched or mirror_docked) else c_sky
	draw_arc(Vector2(0.0, lift_y), 8.0, 0.0, TAU, 16, mid_c, 1.0)
	if latched:
		draw_arc(Vector2(0.0, lift_y), 13.0, 0.0, TAU, 18, Color(c_gold, 0.42 if fred else 0.72), 1.0 if fred else 2.0)
		for tick_p: Vector2 in [Vector2(-1.0, lift_y - 10.0), Vector2(-1.0, lift_y + 8.0), Vector2(-10.0, lift_y - 1.0), Vector2(8.0, lift_y - 1.0)]:
			draw_rect(Rect2(tick_p, Vector2(2.0, 2.0)), c_cream)
	_draw_signal_pulses()
