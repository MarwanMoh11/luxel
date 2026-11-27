class_name LxI7HubDoor
extends LxToy
## Moon Shoals Wick House doorway in silver_quay (`hub_door_7`).
## Sealed in silver glass until `q7_true_reflection` sets `hub_door_7`, then warps to Wick House.

var require_flag: String = "hub_door_7"
var _pulse_t: float = 0.0
var _rattle_t: float = 0.0


func _toy_setup() -> void:
	kind = "i7_hub_door"
	require_flag = str(props.get("require_flag", "hub_door_7")).strip_edges()
	size = Vector2(28.0, 32.0)
	radius = 20.0
	_pulse_t = 0.0
	_rattle_t = 0.0
	queue_redraw()


func is_unlocked() -> bool:
	if require_flag.is_empty():
		return true
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get(require_flag, false)) \
		or bool(Lx.state.story_flags.get("quest:q7_true_reflection:done", false))


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL7_PROMPT_HUB_DOOR" if is_unlocked() else "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if not is_unlocked():
		_rattle_t = 0.24
		_emit_sfx("door_locked")
		if Lx.events != null and LxStrings.has_id("ISL7_HUB_DOOR_LOCKED"):
			Lx.events.narration_requested.emit("ISL7_HUB_DOOR_LOCKED", "narration", 2.8)
		queue_redraw()
		return true
	_pulse_t = 0.55
	_emit_sfx("waystone_warp")
	set_powered(true)
	emit_power(true)
	if Lx.events != null and LxStrings.has_id("ISL7_HUB_DOOR_OPEN"):
		Lx.events.narration_requested.emit("ISL7_HUB_DOOR_OPEN", "narration", 2.2)
	LxHubTravel.fast_travel_to_hub()
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if is_unlocked():
		return Vector4(pos.x, pos.y - 10.0, 56.0, 0.92)
	return Vector4(pos.x, pos.y - 10.0, 28.0, 0.36)


func _draw() -> void:
	if not active:
		return
	var unlocked: bool = is_unlocked()
	var dx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	LxIsland7Rule.draw_truth_shadow(self, Vector2(dx, 4.0), 11.0, 3.0, "se_gold", unlocked)

	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Ornate lunar archway frame
	draw_rect(Rect2(-12.0 + dx, -26.0, 24.0, 28.0), c_void)
	draw_rect(Rect2(-11.0 + dx, -25.0, 22.0, 26.0), c_blue if unlocked else c_dusk)
	draw_rect(Rect2(-9.0 + dx, -23.0, 18.0, 24.0), c_night)
	draw_rect(Rect2(-11.0 + dx, -25.0, 22.0, 2.0), c_gold if unlocked else c_sky)
	if unlocked:
		draw_rect(Rect2(-7.0 + dx, -20.0, 14.0, 20.0), c_dusk)
		draw_rect(Rect2(-5.0 + dx, -18.0, 10.0, 16.0), c_gold)
		draw_rect(Rect2(-3.0 + dx, -16.0, 6.0, 12.0), c_cream)
		LxBubble.draw_icon(self, "home", Vector2(-4.0 + dx, -15.0), 1.0)
	else:
		draw_rect(Rect2(-7.0 + dx, -20.0, 14.0, 20.0), c_void)
		draw_rect(Rect2(-5.0 + dx, -18.0, 10.0, 16.0), c_night)
		draw_line(Vector2(-6.0 + dx, -18.0), Vector2(6.0 + dx, -2.0), c_ice, 1.0)
		draw_line(Vector2(6.0 + dx, -18.0), Vector2(-6.0 + dx, -2.0), c_ice, 1.0)
		LxBubble.draw_icon(self, "mirror", Vector2(-4.0 + dx, -14.0), 1.0)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.55, 0.0, 1.0)
		var pa: float = (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.95)
		draw_arc(Vector2(dx, -10.0), roundf(6.0 + u * 24.0), 0.0, TAU, 16, Color(c_gold, pa), 2.0)
	_draw_signal_pulses()
