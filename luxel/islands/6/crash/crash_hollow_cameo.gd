class_name LxCrashHollowCameo
extends LxToy
## Wordless 2.0s Hollow Wick cameo in `crash_r1` (Runaway Viaduct).
## Dark-cloaked Hollow Wick slices the glowing brake chain with a violet Lance and vanishes
## into dark cinders, setting `hollow_cameo_6` and emitting `ISL6_CRASH_CUT`.

var sets_flag: String = "hollow_cameo_6"
var chain_pos: Vector2 = Vector2.ZERO
var _stage_t: float = 0.0
var _playing: bool = false
var _sliced: bool = false
var _vanished: bool = false


func _toy_setup() -> void:
	kind = "crash_hollow_cameo"
	z_index = 2
	radius = 14.0
	sets_flag = str(props.get("sets_flag", "hollow_cameo_6")).strip_edges()
	chain_pos = _parse_vec2(props.get("chain_pos", [pos.x + 28.0, pos.y + 8.0]), pos + Vector2(28.0, 8.0))
	var done: bool = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_playing = not done
	_sliced = done
	_vanished = done
	_stage_t = 0.0
	if done:
		set_powered(true)
	queue_redraw()


func reset_toy() -> void:
	var done: bool = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_playing = not done
	_sliced = done
	_vanished = done
	_stage_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or not _playing:
		return
	_stage_t += dt
	if _stage_t >= 0.95 and not _sliced:
		_sliced = true
		_emit_sfx("coupler_snap")
		_emit_sfx("steam_whistle")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.06 if LxHudFx.flash_reduced() else 0.14)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(chain_pos, 56.0, 1.0, 0.25)
	if _stage_t >= 2.0 and not _vanished:
		_vanished = true
		_playing = false
		if not sets_flag.is_empty() and Lx.state != null:
			Lx.state.story_flags[sets_flag] = true
		if Lx.events != null and LxStrings.has_id("ISL6_CRASH_CUT"):
			Lx.events.narration_requested.emit("ISL6_CRASH_CUT", "narration", 3.0)
		set_powered(true)
		emit_power(true)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _playing and not _vanished:
		return Vector4(pos.x, pos.y, 44.0, 0.62)
	return Vector4(chain_pos.x, chain_pos.y, 26.0, 0.34)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var cp: Vector2 = (chain_pos - pos).round()

	# Master Brake Chain stanchion (intact gold links -> severed sparking ends)
	draw_rect(Rect2(cp + Vector2(-7.0, -5.0), Vector2(14.0, 10.0)), c_void)
	if not _sliced:
		for li: int in range(3):
			draw_rect(Rect2(cp + Vector2(-5.0 + float(li * 4), -2.0), Vector2(3.0, 4.0)), c_gold)
		draw_rect(Rect2(cp + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), c_cream)
	else:
		draw_rect(Rect2(cp + Vector2(-6.0, -2.0), Vector2(3.0, 4.0)), PAL["dusk"] as Color)
		draw_rect(Rect2(cp + Vector2(3.0, 0.0), Vector2(3.0, 4.0)), PAL["dusk"] as Color)
		if not LxHudFx.flash_reduced() and fmod(_clock, 0.45) < 0.22:
			draw_rect(Rect2(cp + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)), c_coral)

	# Violet Lance slash streak (0.95..1.45s)
	if _playing and _stage_t >= 0.95 and _stage_t <= 1.45:
		var u: float = clampf((_stage_t - 0.95) / 0.25, 0.0, 1.0)
		var tip: Vector2 = Vector2.ZERO.lerp(cp, u)
		draw_line(Vector2.ZERO, tip, c_plum, 4.0)
		draw_line(Vector2.ZERO, tip, c_rose, 2.2)
		draw_line(Vector2.ZERO, tip, c_cream, 1.0)
		if u >= 0.8:
			draw_arc(cp, roundf(lerpf(3.0, 15.0, (_stage_t - 0.95) / 0.50)), 0.0, TAU, 12, c_rose, 1.3)

	# Dark-cloaked Hollow Wick silhouette before vanishing into cinders
	if _playing and not _vanished:
		var fade: float = 1.0 - clampf((_stage_t - 1.65) / 0.35, 0.0, 1.0)
		draw_rect(Rect2(-5.0, -10.0, 10.0, 14.0), Color(c_void, fade))
		draw_rect(Rect2(-4.0, -9.0, 8.0, 12.0), Color(c_night, fade))
		draw_rect(Rect2(-3.0, -8.0, 6.0, 4.0), Color(c_plum, fade))
		draw_rect(Rect2(-2.0, -7.0, 1.0, 1.0), Color(c_rose, fade))
		draw_rect(Rect2(1.0, -7.0, 1.0, 1.0), Color(c_rose, fade))
		# Unlit black-glass lantern
		draw_rect(Rect2(4.0, -4.0, 4.0, 6.0), Color(c_void, fade))
		draw_rect(Rect2(5.0, -3.0, 2.0, 4.0), Color(c_rose, fade))
	_draw_signal_pulses()
