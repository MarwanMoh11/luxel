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

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 5.0), 9.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -14.0, 14.0, 18.0), c_night, c_dusk, c_gold if lit else c_teal, c_void)
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_pulse_t) * 1.2)
	var cy: float = -18.0 + bob
	draw_circle(Vector2(0.0, cy), 4.5, c_void)
	draw_circle(Vector2(0.0, cy), 3.5, c_gold if lit else c_sky)
	draw_circle(Vector2(0.0, cy), 1.5, c_cream if lit else c_dusk)
	_draw_signal_pulses()
