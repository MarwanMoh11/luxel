class_name LxLevBlowholeGeyser
extends LxToy
## Leviathan Blowhole Sky-Launch Plume (`lev_blowhole_geyser`, `leviathan_r5`):
## Dormant foaming vent while the overhead brass grate is closed; once the grate switch
## fires `on_signal(true)`, erupts into a roaring vertical geyser column, sets `leviathan_done`,
## narrates `ISL2_LEV_CALM`, and unlocks the sky-launch exit onto Lighthouse Promontory!

var state: String = "dormant" # "dormant" | "erupting"
var sets_flag: String = "leviathan_done"
var _erupt_t: float = 0.0


func _toy_setup() -> void:
	kind = "lev_blowhole_geyser"
	z_index = -3
	size = _parse_size(props.get("size", [32.0, 32.0]), Vector2(32.0, 32.0))
	radius = 18.0
	sets_flag = str(props.get("sets_flag", "leviathan_done")).strip_edges()
	if not props.has("persist"):
		persist = true
	var done: bool = powered or (not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false)))
	state = "erupting" if done else "dormant"
	powered = done
	_erupt_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and state == "erupting":
		return
	state = "dormant"
	powered = false
	_erupt_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_signal(_from_id: String, is_on: bool) -> void:
	if not active or not is_on or state == "erupting":
		return
	state = "erupting"
	_erupt_t = 0.80
	if Lx.state != null:
		if not sets_flag.is_empty():
			Lx.state.story_flags[sets_flag] = true
		Lx.state.story_flags["dungeon_done:leviathan"] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("whale_groan_low")
	_emit_sfx("tide_surge")
	_emit_gust(96.0, 72.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.28 * (0.45 if LxHudFx.flash_reduced() else 1.0))
		if LxStrings.has_id("ISL2_LEV_CALM"):
			Lx.events.narration_requested.emit("ISL2_LEV_CALM", "title", 3.6)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 118.0, 0.95 if LxHudFx.flash_reduced() else 1.50, 0.50)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _erupt_t > 0.0:
		_erupt_t = maxf(0.0, _erupt_t - dt)
	if state == "erupting" or _erupt_t > 0.0:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == "erupting":
		return Vector4(pos.x, pos.y, 96.0, 1.15)
	return Vector4(pos.x, pos.y, 34.0, 0.35)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["erupting"] = state == "erupting"
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("erupting", false)):
		state = "erupting"
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	# Concentric blowhole basin ring
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 18, c_void, 3.0)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 18, c_ice if state == "erupting" else PAL["deep"] as Color, 2.0)
	draw_circle(Vector2.ZERO, 10.0, PAL["blue"] as Color if state == "erupting" else PAL["night"] as Color)
	if state == "erupting":
		var wob: float = 0.0 if red else roundf(sin(_clock * 14.0) * 1.5)
		# Twilight sky-shaft piercing down through the open blowhole
		draw_rect(Rect2(-12.0, -44.0, 24.0, 46.0), Color(c_gold, 0.12 if red else 0.16))
		draw_rect(Rect2(-7.0 + wob, -34.0, 14.0, 36.0), Color(c_sky, 0.55 if red else 0.78))
		draw_rect(Rect2(-4.0 - wob, -38.0, 8.0, 40.0), c_ice)
		draw_rect(Rect2(-1.0, -42.0, 2.0, 44.0), c_cream)
		# Raised crown vent lips (greyscale-distinct open eruption vs barred dormant grate)
		draw_rect(Rect2(-13.0, -3.0, 3.0, 4.0), c_cream)
		draw_rect(Rect2(10.0, -3.0, 3.0, 4.0), c_cream)
		if not red:
			for di: int in range(6):
				var du: float = fmod(_clock * 1.6 + float(di) * 0.17, 1.0)
				var dx: float = roundf(sin(float(di) * 2.1 + _clock * 5.0) * (5.0 + du * 6.0))
				var dy: float = roundf(lerpf(2.0, -40.0, du))
				draw_rect(Rect2(dx, dy, 2.0, 2.0), c_cream if di % 2 == 0 else c_ice)
		LxPhysDraw.draw_chevron(self, Vector2(0.0, -24.0), Vector2.UP, c_gold, c_void, 3.0)
		LxPhysDraw.draw_chevron(self, Vector2(0.0, -10.0), Vector2.UP, c_cream, c_void, 3.0)
	else:
		var pulse_y: float = 0.0 if red else roundf(sin(_clock * 4.5) * 1.5)
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 16, Color(c_sky, 0.40 if red else 0.55), 1.0)
		# Sealed 3-bar brass grate across dormant blowhole mouth (greyscale-distinct)
		for gy: float in [-5.0, 0.0, 5.0]:
			draw_rect(Rect2(-8.0, gy - 1.0, 16.0, 2.0), c_void)
			draw_rect(Rect2(-7.0, gy, 14.0, 1.0), PAL["stone"] as Color)
		if not red:
			for di: int in range(3):
				var du: float = fmod(_clock * 0.9 + float(di) * 0.33, 1.0)
				draw_rect(Rect2(roundf(sin(float(di) * 2.2) * 5.0), roundf(lerpf(3.0, -14.0, du)), 2.0, 2.0), Color(c_ice, (1.0 - du) * 0.75))
		LxPhysDraw.draw_chevron(self, Vector2(0.0, -2.0 + pulse_y), Vector2.UP, c_gold, c_void, 2.0)
	if _erupt_t > 0.0:
		var u: float = 1.0 - clampf(_erupt_t / 0.80, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(10.0, 38.0, u)), 0.0, TAU, 20, Color(c_cream, (1.0 - u) * (0.55 if red else 1.0)), 1.0 if red else 2.0)
	_draw_signal_pulses()
