class_name LxOwHubPortal
extends LxToy
## Chime Town Wick House Portal (`bell_yard`).
## Unlocked by completing Grandma's `q1_cold_hearth` quest (`hub_door_1`) or relighting Island 1 (`great_lamp_1`).
## Interacting fast-travels straight to Wick House Hub (`LxHubTravel.fast_travel_to_hub()`).

var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "ow_hub_portal"
	size = Vector2(24.0, 26.0)
	radius = 20.0
	persist = true
	queue_redraw()


func is_unlocked() -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("hub_door_1", false)) \
		or bool(Lx.state.story_flags.get("great_lamp_1", false)) \
		or Lx.state.relit_islands.has(1)


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL1_PROMPT_HUB" if is_unlocked() else "PROMPT_INSPECT"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.45
	if not is_unlocked():
		_emit_sfx("door_locked")
		if Lx.events != null and LxStrings.has_id("ISL1_Q3_HINT"):
			Lx.events.narration_requested.emit("ISL1_Q3_HINT", "narration", 3.0)
		queue_redraw()
		return true
	_emit_sfx("waystone_warp")
	LxHubTravel.fast_travel_to_hub()
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 10.0, 52.0 if is_unlocked() else 24.0, 0.85 if is_unlocked() else 0.30)


func _draw() -> void:
	var open_now: bool = is_unlocked()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 4.0), 12.0, 3.5)
	draw_rect(Rect2(-11.0, -24.0, 22.0, 26.0), PAL["void"] as Color)
	draw_rect(Rect2(-10.0, -23.0, 20.0, 24.0), (PAL["apricot"] if open_now else PAL["dusk"]) as Color)
	draw_rect(Rect2(-8.0, -21.0, 16.0, 22.0), PAL["night"] as Color)
	draw_rect(Rect2(-7.0, -20.0, 14.0, 20.0), (PAL["gold"] if open_now else PAL["plum"]) as Color)
	if open_now:
		draw_rect(Rect2(-5.0, -18.0, 10.0, 16.0), PAL["cream"] as Color)
	LxBubble.draw_icon(self, "home", Vector2(-4.0, -14.0), 1.0)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, PAL["gold"] as Color, 1.0)
