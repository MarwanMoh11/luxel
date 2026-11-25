class_name LxPlSextantAltar
extends LxToy
## Planetarium Dungeon Power Pedestal: awards `power_sextant` (Starlight Sextant).
## Thrown lantern acts as a portable Star Vertex over void, linking nearby lit stars
## into solid star-glass bridges and enabling Blue/Prism CCW rotation on Star Bells.

var claimed: bool = false
var requires_flag: String = ""
var _unlocked: bool = true
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "pl_sextant_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("power_sextant", false))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	_claim_t = 0.0
	queue_redraw()


func _flag_ok() -> bool:
	if requires_flag.is_empty():
		return true
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", requires_flag))
	return Lx.state != null and bool(Lx.state.story_flags.get(requires_flag, false))


func tick(dt: float) -> void:
	super.tick(dt)
	if _claim_t > 0.0:
		_claim_t = maxf(0.0, _claim_t - dt)
		queue_redraw()
	if not _unlocked and _flag_ok():
		_unlocked = true
		active = true
		visible = true
		_emit_sfx("shrine_unlock")
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 16.0, 6.0)
		queue_redraw()
	elif _unlocked and not claimed:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not _unlocked or claimed:
		return false
	claimed = true
	_claim_t = 0.65
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["power_sextant"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("I5_PWR_SEXTANT", "title", 3.4)
		Lx.events.shake_requested.emit(0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("star_ignite")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("power_sextant")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "I5_PL_PROMPT_SEXTANT" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 76.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 28.0, 0.40)
	return Vector4(pos.x, pos.y - 6.0, 58.0, 0.95)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("power_sextant", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Marble-and-brass meridian pedestal base
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["plum"] as Color, PAL["deep"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), PAL["gold"] as Color if not claimed else PAL["ice"] as Color)
	if not claimed:
		var bob: float = 0.0 if fr else roundf(sin(_clock * 3.0) * 2.0)
		var cy: float = -12.0 + bob
		# Brass sextant quarter-arc + index arm + starlight vertex crystal
		draw_arc(Vector2(0.0, cy), 9.0, deg_to_rad(15.0), deg_to_rad(165.0), 14, PAL["gold"] as Color, 1.6)
		draw_line(Vector2(0.0, cy - 6.0), Vector2(-7.0, cy + 5.0), PAL["apricot"] as Color, 1.4)
		draw_line(Vector2(0.0, cy - 6.0), Vector2(7.0, cy + 5.0), PAL["apricot"] as Color, 1.4)
		var sweep: float = deg_to_rad(90.0 + (0.0 if fr else sin(_clock * 2.2) * 32.0))
		draw_line(Vector2(0.0, cy - 6.0), Vector2(roundf(cos(sweep) * 8.0), roundf(cy + sin(sweep) * 8.0)), PAL["ice"] as Color, 1.2)
		# Floating cream 4-point star at sextant pivot
		draw_line(Vector2(-4.0, cy - 6.0), Vector2(4.0, cy - 6.0), PAL["gold"] as Color, 1.0)
		draw_line(Vector2(0.0, cy - 10.0), Vector2(0.0, cy - 2.0), PAL["gold"] as Color, 1.0)
		draw_rect(Rect2(-1.0, cy - 7.0, 2.0, 2.0), PAL["cream"] as Color)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 38.0, u)), 0.0, TAU, 24, PAL["ice"] as Color, 1.6)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 26.0, u)), 0.0, TAU, 16, PAL["gold"] as Color, 1.0)
	_draw_signal_pulses()
