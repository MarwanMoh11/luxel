class_name LxTollReceiptAltar
extends LxToy
## Toll House Dungeon Power Pedestal (toll_r5): awards `item_brass_receipt` after
## defeating The Chief Auditor. Throwing the lantern onto a pressure_plate or scale
## stamps a 6.0 s golden Brass Receipt weight body (via LxIsland8Rule / LxArchiveRemix).

var claimed: bool = false
var requires_flag: String = "chief_auditor_defeated"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "toll_receipt_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "chief_auditor_defeated")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("item_brass_receipt", false))
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
		Lx.state.story_flags["item_brass_receipt"] = true
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.archive != null:
		LxIsland8Rule.active_instance.archive.grant_brass_receipt()
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL8_POW_RECEIPT", "title", 3.4)
		Lx.events.shake_requested.emit(0.16 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("invoice_stamp")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("brass_receipt")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_PROMPT_RECEIPT" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 72.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 26.0, 0.35)
	return Vector4(pos.x, pos.y - 6.0, 52.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("item_brass_receipt", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Mahogany & brass ledger plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["plum"] as Color, PAL["gold"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), PAL["gold"] as Color if not claimed else PAL["dusk"] as Color)
	if not claimed:
		var bob: float = 0.0 if fred else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if fred else fmod(_clock * 14.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(PAL["gold"] as Color, 0.45 if fred else 0.65), 1.0, false)
		# Brass wax-seal stamp silhouette (handle + wide octagonal seal base)
		draw_rect(Rect2(-2.0, cy - 6.0, 4.0, 7.0), c_void)
		draw_rect(Rect2(-5.0, cy + 1.0, 10.0, 6.0), c_void)
		draw_rect(Rect2(-1.0, cy - 5.0, 2.0, 6.0), PAL["apricot"] as Color)
		draw_rect(Rect2(-4.0, cy + 2.0, 8.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(-3.0, cy + 2.0, 4.0, 2.0), PAL["cream"] as Color)
	else:
		# Recessed empty wax-seal indentation (greyscale-distinct from active floating stamp)
		draw_rect(Rect2(-4.0, -3.0, 8.0, 2.0), c_void)
		draw_rect(Rect2(-3.0, -2.0, 6.0, 1.0), PAL["dusk"] as Color)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
			var a1: float = (1.0 - u) * (0.55 if fred else 0.90)
			var a2: float = (1.0 - u) * (0.50 if fred else 0.85)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, Color(PAL["gold"] as Color, a1), 1.0 if fred else 2.0, false)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 24.0, u)), 0.0, TAU, 16, Color(PAL["cream"] as Color, a2), 1.0, false)
	_draw_signal_pulses()
