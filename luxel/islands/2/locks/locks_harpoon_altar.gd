class_name LxLocksHarpoonAltar
extends LxToy
## Smugglers' Locks Dungeon Power Pedestal (locks_r6):
## Unlocks after defeating The Dredge Hulk (`boss_dredge_hulk_defeated`) and grants
## **Sluice Harpoon** (`power_sluice_harpoon` + `locks_harpoon_claimed`) while opening
## the Aqueduct Shortcut (`locks_r6_aqueduct`) back to `locks_r2` and North door to `locks_r7`.

var claimed: bool = false
var requires_flag: String = "boss_dredge_hulk_defeated"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "locks_harpoon_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "boss_dredge_hulk_defeated")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("locks_harpoon_claimed", false))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	_claim_t = 0.0
	if claimed:
		set_powered(true)
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
		Lx.state.story_flags["power_sluice_harpoon"] = true
		Lx.state.story_flags["locks_harpoon_claimed"] = true
		Lx.state.story_flags["locks_r6_aqueduct"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("LCK_HARPOON", "title", 3.4)
		Lx.events.shake_requested.emit(0.16 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("harbor_creak")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("sluice_harpoon")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "LCK_PROMPT_HARPOON" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 72.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 28.0, 0.40)
	return Vector4(pos.x, pos.y - 6.0, 54.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("locks_harpoon_claimed", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	if claimed:
		set_powered(true)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Riveted brass quay winch plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["deep"] as Color, PAL["sky"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), PAL["ice"] as Color if not claimed else PAL["blue"] as Color)
	if not claimed:
		var bob: float = 0.0 if fred else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if fred else fmod(_clock * 14.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(PAL["ice"] as Color, 0.45 if fred else 0.72), 1.0, false)
		# Brass Sluice Harpoon barbed grapnel relic silhouette
		draw_rect(Rect2(-6.0, cy - 6.0, 12.0, 12.0), c_void)
		draw_line(Vector2(-4.0, cy + 4.0), Vector2(4.0, cy - 4.0), PAL["gold"] as Color, 2.0)
		draw_rect(Rect2(2.0, cy - 5.0, 3.0, 3.0), PAL["cream"] as Color)
		draw_rect(Rect2(-1.0, cy - 5.0, 3.0, 1.0), PAL["ice"] as Color)
		draw_rect(Rect2(4.0, cy - 2.0, 1.0, 3.0), PAL["ice"] as Color)
		draw_rect(Rect2(-5.0, cy + 3.0, 3.0, 2.0), PAL["apricot"] as Color)
	else:
		# Recessed empty grapnel cradle slot on claimed plinth (greyscale-distinct)
		draw_rect(Rect2(-5.0, -3.0, 10.0, 2.0), c_void)
		draw_rect(Rect2(-4.0, -2.0, 8.0, 1.0), PAL["dusk"] as Color)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
			var a1: float = (1.0 - u) * (0.55 if fred else 0.90)
			var a2: float = (1.0 - u) * (0.50 if fred else 0.85)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, Color(PAL["ice"] as Color, a1), 1.0 if fred else 2.0, false)
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 24.0, u)), 0.0, TAU, 16, Color(PAL["cream"] as Color, a2), 1.0, false)
	_draw_signal_pulses()
