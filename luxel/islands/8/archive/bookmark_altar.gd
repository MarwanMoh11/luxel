class_name LxArchiveBookmarkAltar
extends LxToy
## Archive Dungeon Power Pedestal (archive_r6): awards `item_bookmark` (The Bookmark Sigil)
## after defeating The Indexer. Throwing/tapping on any decaying toy (`timed_brazier`,
## `light_plant`, `echo_rose`, `lantern_hook`) pins it active for 12.0 s via LxArchiveRemix.

var claimed: bool = false
var requires_flag: String = "indexer_defeated"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "archive_bookmark_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "indexer_defeated")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("item_bookmark", false))
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
		Lx.state.story_flags["item_bookmark"] = true
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.archive != null:
		LxIsland8Rule.active_instance.archive.grant_bookmark()
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL8_POW_BOOKMARK", "title", 3.4)
		Lx.events.shake_requested.emit(0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("bookmark_pin")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("archive_bookmark")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_PROMPT_BOOKMARK" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 74.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 26.0, 0.35)
	return Vector4(pos.x, pos.y - 6.0, 52.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("item_bookmark", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Walnut & sky-gilded reading plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["plum"] as Color, PAL["sky"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), PAL["gold"] as Color if not claimed else PAL["dusk"] as Color)
	if not claimed:
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else fmod(_clock * 14.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(PAL["sky"] as Color, 0.65), 1.0, false)
		# Floating silk Bookmark Sigil ribbon (pointed forked tail + gold clasp)
		draw_rect(Rect2(-4.0, cy - 6.0, 8.0, 11.0), c_void)
		draw_rect(Rect2(-3.0, cy - 5.0, 6.0, 9.0), PAL["wine"] as Color)
		draw_rect(Rect2(-2.0, cy - 4.0, 4.0, 6.0), PAL["rose"] as Color)
		draw_rect(Rect2(-3.0, cy - 5.0, 6.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(-1.0, cy - 2.0, 2.0, 3.0), PAL["cream"] as Color)
		draw_rect(Rect2(-1.0, cy + 3.0, 2.0, 2.0), c_void)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 36.0, u)), 0.0, TAU, 20, PAL["sky"] as Color, 1.6, false)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 26.0, u)), 0.0, TAU, 16, PAL["cream"] as Color, 1.0, false)
	_draw_signal_pulses()
