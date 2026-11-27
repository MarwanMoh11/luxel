class_name LxTheatreCueMirrorAltar
extends LxToy
## Doppel Theatre Dungeon Power Reliquary: awards `item_cue_mirror` after defeating
## THE PROMPTER in `theatre_r5`. Standing in golden floor spotlights lets bolts/beams
## pierce `cue_curtain` walls AND doubles `echo_rose` duration (6s -> 12s via LxIsland7Rule).

var claimed: bool = false
var requires_flag: String = "theatre_miniboss_done"
var _unlocked: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "theatre_cue_mirror_altar"
	radius = 16.0
	requires_flag = str(props.get("requires_flag", "theatre_miniboss_done")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("item_cue_mirror", false))
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
		Lx.state.story_flags["item_cue_mirror"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL7_POW_CUE", "title", 3.4)
		Lx.events.shake_requested.emit(0.08 if LxHudFx.flash_reduced() else 0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_sfx("shrine_claimed")
	_emit_sfx("mirror_ping")
	_emit_gust(76.0, 64.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.50)
	_notify_linked_targets(true)
	_emit_save("item_cue_mirror")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL7_TH_PROMPT_CUE" if (active and _unlocked and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.65, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 72.0 * u, 1.2 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 28.0, 0.38)
	return Vector4(pos.x, pos.y - 6.0, 56.0, 0.94)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("item_cue_mirror", false)))
	_unlocked = _flag_ok()
	active = _unlocked
	visible = _unlocked or claimed
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_ice: Color = PAL["ice"] as Color
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 6.0), 10.0, 3.0, "se_gold", false)
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, c_wine, c_gold, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_gold if not claimed else PAL["dusk"] as Color)
	var fr: bool = LxHudFx.flash_reduced()
	if not claimed:
		var bob: float = 0.0 if fr else roundf(sin(_clock * 3.4) * 2.0)
		var cy: float = -12.0 + bob
		var r1: float = 8.0 + (0.0 if fr else fmod(_clock * 13.0, 9.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_gold, 0.45 if fr else 0.65), 1.0, false)
		# Gilded stagehand Cue-Mirror hand-glass emblem + cardinal spotlight alignment ticks
		draw_rect(Rect2(-1.0, cy + 4.0, 2.0, 5.0), c_gold)
		draw_circle(Vector2(0.0, cy), 6.0, c_void)
		draw_circle(Vector2(0.0, cy), 5.0, c_gold)
		draw_circle(Vector2(0.0, cy), 3.0, c_ice)
		draw_rect(Rect2(-2.0, cy - 2.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(0.0, cy - 8.0, 1.0, 2.0), c_cream)
		draw_rect(Rect2(-8.0, cy, 2.0, 1.0), c_gold)
		draw_rect(Rect2(6.0, cy, 2.0, 1.0), c_gold)
		draw_arc(Vector2(0.0, cy), 5.0, -PI * 0.2, PI * 0.4, 8, c_apricot, 1.0)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
		var ca: float = (1.0 - u) * (0.55 if fr else 0.95)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, Color(c_gold, ca), 2.0, false)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 24.0, u)), 0.0, TAU, 16, Color(c_cream, ca), 1.0, false)
	_draw_signal_pulses()
