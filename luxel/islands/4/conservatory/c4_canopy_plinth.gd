class_name LxC4CanopyPlinth
extends LxToy
## Island 4 Drowned Conservatory (r1 & r9): Upper Canopy Seal Conduit Plinth.
## Teases the Upper Glass Canopy seal from r1/r9; once `c4_canopy_seal` is broken in r17,
## glows gold/ice and grants a one-time blessing (60 shards + full heal in r9) on interact.

var grant_blessing: bool = false
var seal_flag: String = "c4_canopy_seal"
var claimed_flag: String = "c4_canopy_blessing_claimed"
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "c4_canopy_plinth"
	radius = 16.0
	size = Vector2(16.0, 20.0)
	grant_blessing = bool(props.get("grant_blessing", false))
	seal_flag = str(props.get("seal_flag", "c4_canopy_seal")).strip_edges()
	claimed_flag = str(props.get("claimed_flag", "c4_canopy_blessing_claimed")).strip_edges()
	_pulse_t = 0.0
	_sync_power()
	queue_redraw()


func _is_seal_broken() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get(seal_flag, false))


func _sync_power() -> void:
	var lit: bool = _is_seal_broken()
	if lit != powered:
		set_powered(lit)
		emit_power(lit)


func get_interact_prompt() -> String:
	return "ISL4_C4_PROMPT_SEAL" if active else ""


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_power()
	if not _is_seal_broken():
		_emit_sfx("prop_chime")
		if Lx.events != null and LxStrings.has_id("ISL4_C4_CANOPY_HINT"):
			Lx.events.narration_requested.emit("ISL4_C4_CANOPY_HINT", "narration", 3.0)
		return true
	if grant_blessing and Lx.state != null and not bool(Lx.state.story_flags.get(claimed_flag, false)):
		Lx.state.story_flags[claimed_flag] = true
		Lx.state.add_shards(60)
		Lx.state.heal_full()
		_emit_sfx("ember_pickup")
		_emit_save(claimed_flag)
	else:
		_emit_sfx("prop_chime")
	if Lx.events != null and LxStrings.has_id("ISL4_C4_CANOPY_LIT"):
		Lx.events.narration_requested.emit("ISL4_C4_CANOPY_LIT", "narration", 3.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_pulse_t = fmod(_pulse_t + dt * 2.6, TAU)
	_sync_power()
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var lit: bool = _is_seal_broken()
	return Vector4(pos.x, pos.y - 8.0, 44.0 if lit else 26.0, 0.68 if lit else 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var lit: bool = _is_seal_broken()
	var fred: bool = LxHudFx.flash_reduced()
	var blessed_done: bool = Lx.state != null and bool(Lx.state.story_flags.get(claimed_flag, false))

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 5.0), 9.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -14.0, 14.0, 18.0), c_night, c_dusk, c_gold if lit else c_teal, c_void)
	# Visible seal socket in plinth body: recessed dark hollow until r17 breaks the Canopy Seal, then solid golden core
	draw_rect(Rect2(-4.0, -9.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(-3.0, -8.0, 6.0, 6.0), c_gold if lit else c_dusk)
	if lit:
		draw_rect(Rect2(-2.0, -7.0, 4.0, 4.0), c_cream)
	else:
		draw_rect(Rect2(-2.0, -7.0, 4.0, 4.0), c_teal)
		draw_rect(Rect2(-1.0, -6.0, 2.0, 2.0), c_void)
	# Blessing shoulder pips (raised bright gems when r9 blessing is ready, flat recessed slots once claimed)
	if grant_blessing and lit:
		for sx: float in [-6.0, 4.0]:
			draw_rect(Rect2(sx, -13.0, 2.0, 2.0 if not blessed_done else 1.0), c_cream if not blessed_done else c_dusk)
	var bob: float = 0.0 if fred else roundf(sin(_pulse_t) * 1.2)
	var cy: float = -18.0 + bob
	draw_circle(Vector2(0.0, cy), 5.0, c_void)
	draw_circle(Vector2(0.0, cy), 4.0, c_gold if lit else c_sky)
	draw_circle(Vector2(0.0, cy), 2.0, c_cream if lit else c_dusk)
	if lit:
		# 4-point starburst crown ticks around lit canopy orb (greyscale-legible)
		draw_rect(Rect2(-1.0, cy - 7.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(-7.0, cy - 1.0, 2.0, 2.0), c_gold)
		draw_rect(Rect2(5.0, cy - 1.0, 2.0, 2.0), c_gold)
		var rr: float = 9.0 if fred else roundf(9.0 + sin(_pulse_t) * 1.6)
		draw_arc(Vector2(0.0, -6.0), rr, 0.0, TAU, 16, Color(c_gold, 0.36 if fred else 0.55), 1.0)
	else:
		# Void-backed westward canopy pointer chevron on unsealed plinth
		var pulse_x: float = 0.0 if fred else roundf(sin(_pulse_t) * 1.0)
		draw_line(Vector2(-8.0 + pulse_x, -5.0), Vector2(-13.0 + pulse_x, -5.0), c_void, 2.0)
		draw_line(Vector2(-9.0 + pulse_x, -5.0), Vector2(-12.0 + pulse_x, -5.0), c_sky, 1.0)
		draw_line(Vector2(-10.0 + pulse_x, -7.0), Vector2(-12.0 + pulse_x, -5.0), c_sky, 1.0)
		draw_line(Vector2(-10.0 + pulse_x, -3.0), Vector2(-12.0 + pulse_x, -5.0), c_sky, 1.0)
	_draw_signal_pulses()
