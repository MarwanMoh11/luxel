class_name LxHgEchoAltar
extends LxToy
## Hourglass Maze Dungeon Power Pedestal (hourglass_r1):
## Grants `hg_echo_bud` (lets Wick bloom Echo Roses across The Hourglass Maze).

var claimed: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "hg_echo_altar"
	radius = 16.0
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("hg_echo_bud", false))
	active = true
	visible = true
	_claim_t = 0.0
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
	_claim_t = 0.70
	set_powered(true)
	if Lx.state != null:
		Lx.state.story_flags["hg_echo_bud"] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL4_PROMPT_ECHO_BUD", "title", 3.4)
		Lx.events.shake_requested.emit(0.14)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.05)
	_emit_sfx("shrine_claimed")
	_emit_sfx("hg_echo_bud_bloom")
	_emit_gust(72.0, 56.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 0.90 if LxHudFx.flash_reduced() else 1.40, 0.50)
	_notify_linked_targets(true)
	_emit_save("hg_echo_bud")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_CLAIM_BUD" if (active and not claimed) else ""


func get_light_pool() -> Vector4:
	if not visible:
		return Vector4.ZERO
	if _claim_t > 0.0:
		var u: float = clampf(_claim_t / 0.70, 0.0, 1.0)
		return Vector4(pos.x, pos.y - 6.0, 74.0 * u, 1.20 * u)
	if claimed:
		return Vector4(pos.x, pos.y - 4.0, 30.0, 0.40)
	return Vector4(pos.x, pos.y - 6.0, 54.0, 0.92)


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed)) or (Lx.state != null and bool(Lx.state.story_flags.get("hg_echo_bud", false)))
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_jade: Color = PAL["jade"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.0)
	# Octagonal brass-trimmed garden plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 9.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_gold if not claimed else PAL["mauve"] as Color)
	draw_rect(Rect2(-5.0, -4.0, 10.0, 2.0), PAL["pine"] as Color)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 1.0), c_jade)

	if not claimed:
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.2) * 2.0)
		var cy: float = -12.0 + bob
		# Concentric rose-gold time ripples
		var r1: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else fmod(_clock * 12.0, 10.0))
		var r2: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else fmod(_clock * 12.0 + 5.0, 10.0))
		draw_arc(Vector2(0.0, cy), roundf(r1), 0.0, TAU, 16, Color(c_rose, 0.65), 1.0, false)
		draw_arc(Vector2(0.0, cy), roundf(r2), 0.0, TAU, 16, Color(c_gold, 0.45), 1.0, false)
		# Floating glass Echo Bud silhouette
		draw_rect(Rect2(-5.0, cy - 5.0, 10.0, 10.0), c_void)
		draw_rect(Rect2(-4.0, cy - 4.0, 8.0, 8.0), c_wine)
		draw_rect(Rect2(-3.0, cy - 3.0, 6.0, 6.0), c_rose)
		draw_rect(Rect2(-2.0, cy - 2.0, 4.0, 4.0), c_gold)
		draw_rect(Rect2(-1.0, cy - 1.0, 2.0, 2.0), c_cream)
		# Stem and twin emerald sepals
		draw_rect(Rect2(-1.0, cy + 5.0, 2.0, 4.0), c_jade)
		draw_rect(Rect2(-3.0, cy + 5.0, 2.0, 2.0), c_jade)
		draw_rect(Rect2(1.0, cy + 5.0, 2.0, 2.0), c_jade)
	elif _claim_t > 0.0:
		var u: float = 1.0 - clampf(_claim_t / 0.70, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 36.0, u)), 0.0, TAU, 20, c_rose, 1.6, false)
		draw_arc(Vector2(0.0, -10.0), roundf(lerpf(4.0, 24.0, u)), 0.0, TAU, 16, c_cream, 1.0, false)
	_draw_signal_pulses()
