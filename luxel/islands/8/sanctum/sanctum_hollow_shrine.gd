class_name LxSanctumHollowShrine
extends LxToy
## Bell Sanctum r11 Hollow Wick's Empty Broken Lantern Shrine.
## Renders a shattered brass lantern resting on plum velvet; inspecting triggers a quiet
## 2.2s golden-violet spotlight vision and records sanctum_hollow_shrine_seen.

const SEEN_FLAG: String = "sanctum_hollow_shrine_seen"

var _spot_t: float = 0.0
var _seen: bool = false


func _toy_setup() -> void:
	kind = "sanctum_hollow_shrine"
	radius = 16.0
	size = Vector2(20.0, 16.0)
	_spot_t = 0.0
	_seen = Lx.state != null and bool(Lx.state.story_flags.get(SEEN_FLAG, false))
	powered = _seen
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-9.0, -4.0), Vector2(18.0, 10.0)) if active else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_seen = true
	_spot_t = 2.2
	set_powered(true)
	emit_power(true)
	if Lx.state != null:
		Lx.state.story_flags[SEEN_FLAG] = true
	_emit_sfx("sanctum_vigil_chime")
	if Lx.events != null and LxStrings.has_id("ISL8_SC_HOLLOW_SHRINE"):
		Lx.events.narration_requested.emit("ISL8_SC_HOLLOW_SHRINE", "ominous", 3.6)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _spot_t > 0.0:
		_spot_t = maxf(0.0, _spot_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL8_SC_PROMPT_SHRINE" if LxStrings.has_id("ISL8_SC_PROMPT_SHRINE") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _spot_t > 0.0:
		var u: float = sin(clampf(_spot_t / 2.2, 0.0, 1.0) * PI)
		var boost: float = 0.6 if LxHudFx.flash_reduced() else 1.0
		return Vector4(pos.x, pos.y - 6.0, 42.0 + 30.0 * u * boost, 0.72 + 0.45 * u * boost)
	return Vector4(pos.x, pos.y - 6.0, 32.0 if _seen else 22.0, 0.42 if _seen else 0.25)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Pedestal + plum velvet cloth
	draw_rect(Rect2(-10.0, -3.0, 20.0, 10.0), c_void)
	draw_rect(Rect2(-9.0, -4.0, 18.0, 9.0), c_dusk)
	draw_rect(Rect2(-8.0, -3.0, 16.0, 5.0), c_plum)
	draw_rect(Rect2(-6.0, -2.0, 12.0, 3.0), c_wine)
	# Cracked empty brass lantern cage lying slightly tilted
	draw_rect(Rect2(-4.0, -10.0, 8.0, 7.0), c_night)
	draw_rect(Rect2(-4.0, -10.0, 8.0, 1.0), c_gold)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 1.0), c_gold)
	draw_rect(Rect2(-4.0, -10.0, 1.0, 7.0), c_mauve)
	draw_rect(Rect2(3.0, -9.0, 1.0, 4.0), c_mauve) # snapped right strut
	# Dim violet ember inside dead cage (flares during spotlight)
	draw_rect(Rect2(-1.0, -7.0, 2.0, 2.0), c_cream if _spot_t > 0.0 else (c_ice if _seen else c_dusk))
	# Wordless spotlight shaft during inspection
	if _spot_t > 0.0:
		var a: float = clampf(_spot_t / 2.2, 0.0, 1.0) * (0.22 if LxHudFx.flash_reduced() else 0.32)
		draw_rect(Rect2(-11.0, -28.0, 22.0, 34.0), Color(c_ice, a))
		draw_arc(Vector2(0.0, -6.0), 14.0, 0.0, TAU, 18, Color(c_gold, a * 2.0), 1.0)
	_draw_signal_pulses()
