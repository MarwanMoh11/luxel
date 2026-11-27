class_name LxMsVanePedestal
extends LxToy
## Rain Mausoleum Dungeon Power Pedestal (mausoleum_r1):
## Grants `ms_vane_rod` (allows Wick to turn Weather Wheels across SUN / RAIN / WIND).

var claimed: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "ms_vane_pedestal"
	radius = 16.0
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("ms_vane_rod", false))
	active = true
	visible = true
	_claim_t = 0.0
	powered = claimed
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _claim_t > 0.0:
		_claim_t = maxf(0.0, _claim_t - dt)
		queue_redraw()
	elif not claimed:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	claimed = true
	_claim_t = 0.75
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["ms_vane_rod"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL4_PROMPT_VANE_ROD", "title", 3.4)
		Lx.events.shake_requested.emit(0.14 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.05)
	_emit_sfx("shrine_claimed")
	_emit_sfx("ms_vane_chime")
	_emit_gust(76.0, 58.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 98.0, 0.90 if LxHudFx.flash_reduced() else 1.40, 0.50)
	_notify_linked_targets(true)
	_emit_save("ms_vane_rod")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_CLAIM_VANE" if (active and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.75, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 76.0 * u, 1.20 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 32.0, 0.44)
	return Vector4(pos.x, pos.y - 6.0, 56.0, 0.94)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("ms_vane_rod", false)))
	powered = claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_teal: Color = PAL["teal"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 11.0, 3.0)
	# Carved slate cistern pedestal with brass trim
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["deep"] as Color, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_gold if not claimed else PAL["mauve"] as Color)
	draw_rect(Rect2(-5.0, -4.0, 10.0, 2.0), PAL["pine"] as Color)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 1.0), c_teal)

	if not claimed:
		var bob: float = 0.0 if fred else roundf(sin(_clock * 3.0) * 2.0)
		var cy: float = -13.0 + bob
		var r1: float = 8.0 if fred else roundf(8.0 + fmod(_clock * 11.0, 10.0))
		var r2: float = 11.0 if fred else roundf(8.0 + fmod(_clock * 11.0 + 5.0, 10.0))
		draw_arc(Vector2(0.0, cy), r1, 0.0, TAU, 16, Color(c_sky, 0.38 if fred else 0.65), 1.0, false)
		draw_arc(Vector2(0.0, cy), r2, 0.0, TAU, 16, Color(c_gold, 0.26 if fred else 0.48), 1.0, false)
		# Floating brass Vane Rod silhouette (crossbar + arrow vane + crystal drop)
		draw_rect(Rect2(-2.0, cy - 7.0, 4.0, 15.0), c_void)
		draw_rect(Rect2(-1.0, cy - 6.0, 2.0, 13.0), c_gold)
		draw_rect(Rect2(-6.0, cy - 3.0, 12.0, 3.0), c_void)
		draw_rect(Rect2(-5.0, cy - 2.0, 10.0, 1.0), c_cream)
		draw_rect(Rect2(4.0, cy - 4.0, 2.0, 5.0), c_ice)
		draw_rect(Rect2(-5.0, cy - 3.0, 2.0, 3.0), c_sky)
		draw_rect(Rect2(-1.0, cy - 6.0, 2.0, 2.0), c_cream)
	else:
		# Recessed empty vane-rod cradle slot on claimed cistern pedestal
		draw_rect(Rect2(-4.0, -4.0, 8.0, 2.0), c_void)
		draw_rect(Rect2(-3.0, -3.0, 6.0, 1.0), PAL["dusk"] as Color)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.75, 0.0, 1.0)
			var ra: float = (1.0 - u) * (0.48 if fred else 0.85)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 38.0, u)), 0.0, TAU, 20, Color(c_sky, ra), 1.0 if fred else 2.0, false)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 26.0, u)), 0.0, TAU, 16, Color(c_cream, ra), 1.0, false)
	_draw_signal_pulses()
