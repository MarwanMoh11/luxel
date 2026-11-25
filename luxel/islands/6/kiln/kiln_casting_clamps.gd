class_name LxKilnCastingClamps
extends LxToy
## Twin Casting Clamps conduit plinth for `kiln_r1` (teaser) and `kiln_r9` (blessing plinth).
## Shows live status of `kiln_cast_west` (`kiln_r13`) and `kiln_cast_east` (`kiln_r16`).
## When both clamps are released and `grant_blessing` is true, interacting grants a one-time
## Forge Blessing (+70 shards, full heal, full Ember) and sets `kiln_clamps_blessing`.

var grant_blessing: bool = false
var west_flag: String = "kiln_cast_west"
var east_flag: String = "kiln_cast_east"
var claimed_flag: String = "kiln_clamps_blessing"
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "kiln_casting_clamps"
	radius = 18.0
	size = Vector2(24.0, 18.0)
	grant_blessing = bool(props.get("grant_blessing", false))
	west_flag = str(props.get("west_flag", "kiln_cast_west")).strip_edges()
	east_flag = str(props.get("east_flag", "kiln_cast_east")).strip_edges()
	claimed_flag = str(props.get("claimed_flag", "kiln_clamps_blessing")).strip_edges()
	_pulse_t = 0.0
	_sync_power()
	queue_redraw()


func _has_flag(fl: String) -> bool:
	return not fl.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(fl, false))


func _both_free() -> bool:
	return _has_flag(west_flag) and _has_flag(east_flag)


func _sync_power() -> void:
	var lit: bool = _both_free()
	if lit != powered:
		set_powered(lit)
		emit_power(lit)


func get_interact_prompt() -> String:
	return "ISL6_PROMPT_CLAMPS" if active else ""


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_power()
	if not _both_free():
		_emit_sfx("shield_clang")
		if Lx.events != null and LxStrings.has_id("ISL6_KILN_CLAMP_WAIT"):
			Lx.events.narration_requested.emit("ISL6_KILN_CLAMP_WAIT", "narration", 3.0)
		return true
	if grant_blessing and Lx.state != null and not bool(Lx.state.story_flags.get(claimed_flag, false)):
		Lx.state.story_flags[claimed_flag] = true
		Lx.state.add_shards(70)
		Lx.state.heal_full()
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			(Lx.player as LxWick).ember = Lx.state.get_effective_ember_max()
		_emit_sfx("ember_pickup")
		_emit_save(claimed_flag)
	else:
		_emit_sfx("anvil_clang_skip")
	if Lx.events != null and LxStrings.has_id("ISL6_KILN_CLAMP_BLESS"):
		Lx.events.narration_requested.emit("ISL6_KILN_CLAMP_BLESS", "narration", 3.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_pulse_t = fmod(_pulse_t + dt * 2.5, TAU)
	_sync_power()
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var lit: bool = _both_free()
	return Vector4(pos.x, pos.y - 6.0, 48.0 if lit else 28.0, 0.72 if lit else 0.38)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var w_ok: bool = _has_flag(west_flag)
	var e_ok: bool = _has_flag(east_flag)
	var both: bool = w_ok and e_ok

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 6.0), 11.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-12.0, -10.0, 24.0, 16.0), c_night, c_dusk, c_gold if both else PAL["stone"] as Color, c_void)
	# West clamp pip (left) & East clamp pip (right)
	draw_rect(Rect2(-9.0, -6.0, 7.0, 7.0), c_void)
	draw_rect(Rect2(-8.0, -5.0, 5.0, 5.0), c_gold if w_ok else c_coral)
	if w_ok:
		draw_rect(Rect2(-7.0, -4.0, 3.0, 3.0), c_cream)
	draw_rect(Rect2(2.0, -6.0, 7.0, 7.0), c_void)
	draw_rect(Rect2(3.0, -5.0, 5.0, 5.0), c_gold if e_ok else c_coral)
	if e_ok:
		draw_rect(Rect2(4.0, -4.0, 3.0, 3.0), c_cream)
	if both and not LxHudFx.flash_reduced():
		var rr: float = 12.0 + sin(_pulse_t) * 2.0
		draw_arc(Vector2(0.0, -2.0), roundf(rr), 0.0, TAU, 16, Color(c_gold, 0.55), 1.0)
	_draw_signal_pulses()
