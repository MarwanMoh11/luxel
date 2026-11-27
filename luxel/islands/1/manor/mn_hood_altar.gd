class_name LxMnHoodAltar
extends LxToy
## Manor Dungeon Power Pedestal: awards `item_shutter_hood` and `manor_parlor_key`
## after defeating The Clockwork Valet in `manor_r5`.

var claimed: bool = false
var requires_flag: String = "manor_miniboss_done"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "mn_hood_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "manor_miniboss_done")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("item_shutter_hood", false))
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
	elif _unlocked and not claimed and not LxHudFx.flash_reduced():
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not _unlocked or claimed:
		return false
	claimed = true
	_claim_t = 0.65
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["item_shutter_hood"] = true
		Lx.state.story_flags["manor_parlor_key"] = true
	if LxIsland1Rule.active_instance != null:
		LxIsland1Rule.active_instance.sync_shutter_hood()
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL1_POW_HOOD", "title", 3.4)
	_emit_shake(0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("shadow_whisper")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 88.0, 0.90 if LxHudFx.flash_reduced() else 1.35, 0.48)
	_notify_linked_targets(true)
	_emit_save("shutter_hood")
	queue_redraw()
	return true


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func get_interact_prompt() -> String:
	return "ISL1_PROMPT_HOOD" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 68.0 * u, (0.85 if LxHudFx.flash_reduced() else 1.15) * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 24.0, 0.32)
	return Vector4(pos.x, pos.y - 6.0, 48.0, 0.72 if LxHudFx.flash_reduced() else 0.85)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("item_shutter_hood", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var red: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Velvet tailor mannequin plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), c_night, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_wine if not claimed else PAL["mauve"] as Color)
	if not claimed:
		var bob: float = 0.0 if red else roundf(sin(_clock * 3.2) * 2.0)
		var cy: float = -12.0 + bob
		# Soft dusk stealth aura behind the Shutter Hood
		var r1: float = 8.0 + (0.0 if red else fmod(_clock * 12.0, 9.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_ice, 0.38 if red else 0.55), 1.0, false)
		# Hooded velvet mantle silhouette with brass shutter clasp
		draw_rect(Rect2(-6.0, cy - 6.0, 12.0, 12.0), c_void)
		draw_rect(Rect2(-5.0, cy - 5.0, 10.0, 5.0), c_plum)
		draw_rect(Rect2(-4.0, cy - 4.0, 8.0, 4.0), c_night)
		draw_rect(Rect2(-5.0, cy, 10.0, 5.0), c_wine)
		# Glowing brass shutter clasp + crescent moon stitch
		draw_rect(Rect2(-2.0, cy, 4.0, 2.0), c_gold)
		draw_rect(Rect2(-1.0, cy, 2.0, 1.0), c_cream)
		draw_rect(Rect2(-2.0, cy - 3.0, 1.0, 2.0), c_ice)
		draw_rect(Rect2(1.0, cy - 3.0, 1.0, 2.0), c_ice)
	else:
		# Recessed empty clasp cradle once claimed (greyscale-legible)
		draw_rect(Rect2(-4.0, -3.0, 8.0, 3.0), c_void)
		draw_rect(Rect2(-3.0, -2.0, 6.0, 1.0), PAL["mauve"] as Color)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
			var a_ring: float = (1.0 - u) * (0.55 if red else 0.92)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 24.0 if red else 32.0, u)), 0.0, TAU, 20, Color(c_ice, a_ring), 1.0 if red else 2.0, false)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 18.0 if red else 22.0, u)), 0.0, TAU, 16, Color(c_gold, a_ring), 1.0, false)
	_draw_signal_pulses()
