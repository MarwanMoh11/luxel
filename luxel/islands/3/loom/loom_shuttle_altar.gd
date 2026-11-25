class_name LxLoomShuttleAltar
extends LxToy
## Weaver's Loom Dungeon Power Pedestal (loom_r6): awards the Brass Shuttle mastery
## after defeating The Thread-Keeper, emitting power to unseal the north balcony back to loom_r2.

var claimed: bool = false
var requires_flag: String = "brass_shuttle"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "loom_shuttle_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "brass_shuttle")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("loom_shuttle_claimed", false))
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
	elif _unlocked and not claimed:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not _unlocked or claimed:
		return false
	claimed = true
	_claim_t = 0.70
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["brass_shuttle"] = true
		Lx.state.story_flags["loom_shuttle_claimed"] = true
		Lx.state.story_flags["loom_r6_balcony_open"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL3_PWR_SHUTTLE", "title", 3.6)
		Lx.events.shake_requested.emit(0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("silk_spark_run")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 100.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	_emit_save("brass_shuttle")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL3_PROMPT_SHUTTLE" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.70, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 78.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 28.0, 0.38)
	return Vector4(pos.x, pos.y - 6.0, 56.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("loom_shuttle_claimed", false)))
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
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), c_plum, c_wine, c_rose, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_gold if not claimed else c_rose)
	if not claimed:
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else fmod(_clock * 14.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_gold, 0.65), 1.0, false)
		# Pointed Brass Shuttle boat silhouette with golden bobbin core
		var pts := PackedVector2Array([
			Vector2(-9.0, cy), Vector2(-4.0, cy - 4.0), Vector2(4.0, cy - 4.0),
			Vector2(9.0, cy), Vector2(4.0, cy + 4.0), Vector2(-4.0, cy + 4.0),
		])
		draw_colored_polygon(pts, c_void)
		var inner := PackedVector2Array([
			Vector2(-7.0, cy), Vector2(-3.0, cy - 3.0), Vector2(3.0, cy - 3.0),
			Vector2(7.0, cy), Vector2(3.0, cy + 3.0), Vector2(-3.0, cy + 3.0),
		])
		draw_colored_polygon(inner, c_apricot)
		draw_rect(Rect2(-3.0, cy - 2.0, 6.0, 4.0), c_gold)
		draw_rect(Rect2(-2.0, cy - 1.0, 4.0, 2.0), c_cream)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.70, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 36.0, u)), 0.0, TAU, 20, c_gold, 1.6, false)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 26.0, u)), 0.0, TAU, 16, c_cream, 1.0, false)
	_draw_signal_pulses()
