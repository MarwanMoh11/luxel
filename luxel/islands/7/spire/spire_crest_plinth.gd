class_name LxSpireCrestPlinth
extends LxToy
## Island 7 Mirror Spire r9 Twin Reflection Crests Monument:
## Displays the two deepened Spire Crests (`spire_duchess_seal` from r13 Kaleidoscope Duchess
## and `spire_false_lamp_broken` from r15 Counterfeit Bell Isle) beside `door_boss_7`.
## When both crests shine, interacting grants the Twin Crest Blessing (full heal, full ember,
## +75 shards once) before challenging Hollow Wick!

var _claimed_flag: String = "spire_crest_blessing_claimed"
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "spire_crest_plinth"
	radius = 18.0
	size = Vector2(24.0, 14.0)
	_flash_t = 0.0
	powered = _both_crests_lit()
	queue_redraw()


func _both_crests_lit() -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("spire_duchess_seal", false)) \
		and bool(Lx.state.story_flags.get("spire_false_lamp_broken", false))


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-10.0, -4.0), Vector2(20.0, 10.0)) if active else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_flash_t = 0.55
	var both: bool = _both_crests_lit()
	if both:
		set_powered(true)
		emit_power(true)
		if Lx.state != null:
			Lx.state.heal_full()
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			(Lx.player as LxWick).ember = 1.0
		if Lx.state != null and not bool(Lx.state.story_flags.get(_claimed_flag, false)):
			Lx.state.story_flags[_claimed_flag] = true
			Lx.state.shards += 75
		_emit_sfx("spire_nave_chord")
		if Lx.events != null and LxStrings.has_id("ISL7_SP_CRESTS_READY"):
			Lx.events.narration_requested.emit("ISL7_SP_CRESTS_READY", "gold", 3.0)
	else:
		_emit_sfx("mirror_ping")
		if Lx.events != null and LxStrings.has_id("ISL7_SP_CRESTS_WAIT"):
			Lx.events.narration_requested.emit("ISL7_SP_CRESTS_WAIT", "narration", 2.8)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL7_SP_PROMPT_CRESTS" if LxStrings.has_id("ISL7_SP_PROMPT_CRESTS") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 44.0 if _both_crests_lit() else 26.0, 0.65 if _both_crests_lit() else 0.35)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var has_d: bool = Lx.state != null and bool(Lx.state.story_flags.get("spire_duchess_seal", false))
	var has_l: bool = Lx.state != null and bool(Lx.state.story_flags.get("spire_false_lamp_broken", false))

	var fr: bool = LxHudFx.flash_reduced()
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 11.0, 3.0, "se_gold", false)
	LxToyDraw.draw_bevel_box(self, Rect2(-11.0, -5.0, 22.0, 10.0), c_night, c_dusk, c_gold if (has_d and has_l) else c_ice, c_void)
	# Left Crest: Kaleidoscope Duchess Diamond (greyscale-distinct filled diamond vs dark empty recess)
	draw_rect(Rect2(-8.0, -3.0, 6.0, 6.0), c_void)
	if has_d:
		var d_pts := PackedVector2Array([Vector2(-5.0, -3.0), Vector2(-2.0, 0.0), Vector2(-5.0, 3.0), Vector2(-8.0, 0.0)])
		draw_colored_polygon(d_pts, c_ice)
		draw_rect(Rect2(-6.0, -1.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(-6.0, -6.0, 2.0, 1.0), c_cream)
	else:
		draw_rect(Rect2(-7.0, -2.0, 4.0, 4.0), c_night)
	# Right Crest: Shattered Dawn 4-point Star (greyscale-distinct bright star vs dark empty recess)
	draw_rect(Rect2(2.0, -3.0, 6.0, 6.0), c_void)
	if has_l:
		draw_rect(Rect2(4.0, -3.0, 2.0, 6.0), c_rose)
		draw_rect(Rect2(2.0, -1.0, 6.0, 2.0), c_rose)
		draw_rect(Rect2(4.0, -1.0, 2.0, 2.0), c_gold)
		draw_rect(Rect2(4.0, -6.0, 2.0, 1.0), c_gold)
	else:
		draw_rect(Rect2(3.0, -2.0, 4.0, 4.0), c_night)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 20.0, u)), 0.0, TAU, 16, Color(c_cream, (1.0 - u) * (0.55 if fr else 0.95)), 1.2)
	_draw_signal_pulses()
