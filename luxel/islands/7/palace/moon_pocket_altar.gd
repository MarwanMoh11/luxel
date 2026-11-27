class_name LxPalaceMoonPocketAltar
extends LxToy
## Inverted Palace Dungeon Power Reliquary: awards `item_moon_pocket` after defeating
## THE SILVER-TIDE MIMIC in `palace_r5`. Allows carrying 1 `carry_orb` across Moon Pool flips
## and triggers a 48px Dual-World Ripple on lantern throws (handled by LxIsland7Rule).

var claimed: bool = false
var requires_flag: String = "palace_miniboss_done"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "palace_moon_pocket_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "palace_miniboss_done")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("item_moon_pocket", false))
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
		Lx.state.story_flags["item_moon_pocket"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL7_POW_POCKET", "title", 3.4)
		Lx.events.shake_requested.emit(0.08 if LxHudFx.flash_reduced() else 0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("mirror_ping")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("item_moon_pocket")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL7_PL_PROMPT_POCKET" if (active and _unlocked and not claimed) else ""


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
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("item_moon_pocket", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 6.0), 10.0, 3.0, "se_gold", false)
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["deep"] as Color, c_ice, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_sky if not claimed else PAL["dusk"] as Color)
	if not claimed:
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else fmod(_clock * 13.0, 9.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_ice, 0.65), 1.0, false)
		# Split Silver/Black Moon-Glass Pocket lens-satchel emblem
		draw_circle(Vector2(0.0, cy), 6.0, c_void)
		draw_circle(Vector2(0.0, cy), 5.0, c_ice)
		draw_rect(Rect2(0.0, cy - 5.0, 5.0, 10.0), PAL["night"] as Color)
		draw_arc(Vector2(0.0, cy), 5.0, -PI * 0.5, PI * 0.5, 10, c_rose, 1.0)
		draw_rect(Rect2(-3.0, cy - 2.0, 2.0, 2.0), c_cream)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
		var ca: float = (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.95)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, Color(c_ice, ca), 2.0, false)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 24.0, u)), 0.0, TAU, 16, Color(c_rose, ca), 1.0, false)
	_draw_signal_pulses()
