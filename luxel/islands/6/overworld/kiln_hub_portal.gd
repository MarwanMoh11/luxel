class_name LxKilnHubPortal
extends LxInteractable
## Switchyard Camp Wick House Hub Door (`kind: "kiln_hub_door"`).
## Sets `hub_door_6` and fast-travels Wick directly to Wick House Hub (Island 0) via LxHubTravel.

var _pulse_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "kiln_hub_door"
	radius = maxf(16.0, radius)
	queue_redraw()


func get_interact_prompt() -> String:
	return "ISL6_PROMPT_HUB" if LxStrings.has_id("ISL6_PROMPT_HUB") else "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.50
	if Lx.state != null:
		Lx.state.story_flags["hub_door_6"] = true
	_emit_sfx("waystone_warp")
	_notify_linked_targets(true)
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
	return Vector4(pos.x, pos.y - 10.0, 44.0, 0.85)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(11.0, 3.5, Vector2(0.0, 2.0))
	# Riveted iron-and-gold Wick House travel arch
	draw_rect(Rect2(-11.0, -25.0, 22.0, 27.0), PAL["void"] as Color)
	draw_rect(Rect2(-10.0, -24.0, 20.0, 25.0), PAL["plum"] as Color)
	draw_rect(Rect2(-8.0, -22.0, 16.0, 23.0), PAL["night"] as Color)
	draw_rect(Rect2(-6.0, -20.0, 12.0, 20.0), PAL["wine"] as Color)
	draw_rect(Rect2(-9.0, -24.0, 18.0, 2.0), PAL["gold"] as Color)
	LxBubble.draw_icon(self, "home", Vector2(-4.0, -16.0), 1.0)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.50, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, PAL["cream"] as Color, 1.0)
