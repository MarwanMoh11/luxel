class_name LxUrSapHornAltar
extends LxToy
## Under-Root Dungeon Power Pedestal (underroot_r6): awards `sap_horn` after defeating The Stag Colossus,
## emitting power to unseal the northern drop-bridge back to the Acorn Atrium (`underroot_r2`).

var claimed: bool = false
var requires_flag: String = "stag_colossus_defeated"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "ur_sap_horn_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "stag_colossus_defeated")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("sap_horn", false))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	_claim_t = 0.0
	if claimed:
		powered = true
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
	elif _unlocked and not claimed and not LxHudFx.flash_reduced():
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not _unlocked or claimed:
		return false
	claimed = true
	_claim_t = 0.70
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["sap_horn"] = true
		Lx.state.story_flags["ur_r6_drop_open"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL3_PWR_HORN", "title", 3.4)
		Lx.events.shake_requested.emit(0.16 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("sap_horn_call")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 100.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	_emit_save("sap_horn")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL3_PROMPT_HORN" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.70, 0.0, 1.0)
		var peak: float = 0.85 if LxHudFx.flash_reduced() else 1.20
		return Vector4(pos.x, pos.y - 6.0, roundf(76.0 * u), peak * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 28.0, 0.38)
	return Vector4(pos.x, pos.y - 6.0, 56.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("sap_horn", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	if claimed:
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var red: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Mossy acorn-cup plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), c_pine, c_teal, c_jade, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_gold if not claimed else c_jade)
	if not claimed:
		var bob: float = 0.0 if red else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if red else fmod(_clock * 14.0, 10.0))
		var r2: float = 12.0 if red else (8.0 + fmod(_clock * 14.0 + 5.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_gold, 0.40 if red else 0.65), 1.0, false)
		draw_arc(Vector2(0.0, cy), roundf(r2), 0.0, TAU, 16, Color(c_cream, 0.28 if red else 0.45), 1.0, false)
		# Curved brass Sap-Horn silhouette
		draw_line(Vector2(-6.0, cy + 3.0), Vector2(0.0, cy - 3.0), c_void, 5.0)
		draw_line(Vector2(0.0, cy - 3.0), Vector2(6.0, cy - 6.0), c_void, 6.0)
		draw_line(Vector2(-6.0, cy + 3.0), Vector2(0.0, cy - 3.0), c_apricot, 3.0)
		draw_line(Vector2(0.0, cy - 3.0), Vector2(6.0, cy - 6.0), c_gold, 4.0)
		draw_rect(Rect2(4.0, cy - 8.0, 3.0, 4.0), c_cream)
		draw_rect(Rect2(-7.0, cy + 2.0, 2.0, 2.0), c_gold)
	else:
		# Recessed empty horn cradle slot on claimed plinth (greyscale-distinct)
		draw_rect(Rect2(-5.0, -1.0, 10.0, 3.0), PAL["night"] as Color)
		draw_rect(Rect2(-4.0, 0.0, 8.0, 1.0), c_void)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.70, 0.0, 1.0)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 36.0, u)), 0.0, TAU, 20, Color(c_gold, 0.55 if red else 1.0), 1.0 if red else 2.0, false)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 26.0, u)), 0.0, TAU, 16, Color(c_cream, 0.45 if red else 1.0), 1.0, false)
	_draw_signal_pulses()
