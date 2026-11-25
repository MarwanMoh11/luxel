class_name LxCrashHollowCameo
extends LxToy
## Wordless 2.0s Hollow Wick cameo in `crash_r1` (Runaway Viaduct).
## Dark-cloaked Hollow Wick raises a blazing violet Lance, slices the glowing master brake
## chain in a shower of flying iron links and violet sparks, and dissolves into dark moth feathers,
## setting `hollow_cameo_6` and emitting `ISL6_CRASH_CUT`.

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
			Lx.events.shake_requested.emit(0.07 if LxHudFx.flash_reduced() else 0.18)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(chain_pos, 68.0, 1.15, 0.30)
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
		return Vector4(pos.x, pos.y, 52.0, 0.72)
	return Vector4(chain_pos.x, chain_pos.y, 28.0, 0.38)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var cp: Vector2 = (chain_pos - pos).round()

	# Master Brake Chain stanchion (intact taut brass links -> snapped recoiling links)
	draw_rect(Rect2(cp + Vector2(-9.0, -6.0), Vector2(18.0, 12.0)), c_void)
	if not _sliced:
		for li: int in range(4):
			draw_rect(Rect2(cp + Vector2(-7.0 + float(li * 4), -2.0), Vector2(3.0, 4.0)), c_gold)
		draw_rect(Rect2(cp + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), c_cream)
	else:
		draw_rect(Rect2(cp + Vector2(-8.0, -2.0), Vector2(3.0, 4.0)), c_dusk)
		draw_rect(Rect2(cp + Vector2(5.0, 1.0), Vector2(3.0, 4.0)), c_dusk)
		# Flying snapped links immediately after cut
		if _playing and _stage_t >= 0.95 and _stage_t <= 1.65:
			var ku: float = clampf((_stage_t - 0.95) / 0.70, 0.0, 1.0)
			draw_rect(Rect2(cp + Vector2(roundf(-ku * 14.0), roundf(-ku * 12.0)), Vector2(3.0, 2.0)), c_gold)
			draw_rect(Rect2(cp + Vector2(roundf(ku * 16.0), roundf(-ku * 9.0 + ku * ku * 10.0)), Vector2(3.0, 2.0)), c_coral)
		if not fred and fmod(_clock, 0.40) < 0.20:
			draw_rect(Rect2(cp + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)), c_coral)
			draw_rect(Rect2(cp + Vector2(1.0, -1.0), Vector2(1.0, 1.0)), c_cream)

	# Violet Lance charge gleam (0.35..0.95s) & slashing arc (0.95..1.55s)
	if _playing and _stage_t >= 0.35 and _stage_t < 0.95:
		var cu: float = clampf((_stage_t - 0.35) / 0.60, 0.0, 1.0)
		var r_c: float = roundf(lerpf(10.0, 3.0, cu))
		draw_arc(Vector2(6.0, -4.0), r_c, 0.0, TAU, 12, Color(c_rose, 0.75), 1.2)
		draw_rect(Rect2(5.0, -5.0, 2.0, 2.0), c_cream)
	elif _playing and _stage_t >= 0.95 and _stage_t <= 1.55:
		var u: float = clampf((_stage_t - 0.95) / 0.22, 0.0, 1.0)
		var tip: Vector2 = Vector2(5.0, -4.0).lerp(cp + Vector2(6.0, 2.0), u)
		draw_line(Vector2(5.0, -4.0), tip, c_plum, 4.5)
		draw_line(Vector2(5.0, -4.0), tip, c_rose, 2.4)
		draw_line(Vector2(5.0, -4.0), tip, c_cream, 1.0)
		if u >= 0.75:
			var ru: float = clampf((_stage_t - 0.95) / 0.60, 0.0, 1.0)
			draw_arc(cp, roundf(lerpf(4.0, 22.0, ru)), 0.0, TAU, 14, Color(c_rose, 1.0 - ru), 1.5)
			draw_arc(cp, roundf(lerpf(2.0, 14.0, ru)), 0.0, TAU, 12, Color(c_cream, (1.0 - ru) * 0.8), 1.0)

	# Horned-hood Hollow Wick cloaked silhouette + billowing cape + moth-feather dissolve
	if _playing and not _vanished:
		var fade: float = 1.0 - clampf((_stage_t - 1.55) / 0.45, 0.0, 1.0)
		var wind_sway: float = 0.0 if fred else roundf(sin(_clock * 14.0) * 1.5)
		LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 5.0), 8.0, 3.0)
		# Flowing dark cape streaming west in roof gale
		draw_colored_polygon(
			PackedVector2Array([Vector2(-4.0, -6.0), Vector2(-13.0, -2.0 + wind_sway), Vector2(-11.0, 4.0 + wind_sway), Vector2(-3.0, 4.0)]),
			Color(c_void, fade)
		)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-4.0, -5.0), Vector2(-11.0, -1.0 + wind_sway), Vector2(-9.0, 3.0 + wind_sway), Vector2(-3.0, 3.0)]),
			Color(c_plum, fade * 0.85)
		)
		# Cloaked body & peaked hood horns
		draw_rect(Rect2(-6.0, -11.0, 12.0, 16.0), Color(c_void, fade))
		draw_rect(Rect2(-5.0, -10.0, 10.0, 14.0), Color(c_night, fade))
		draw_rect(Rect2(-5.0, -13.0, 3.0, 3.0), Color(c_void, fade))
		draw_rect(Rect2(2.0, -13.0, 3.0, 3.0), Color(c_void, fade))
		draw_rect(Rect2(-4.0, -12.0, 2.0, 2.0), Color(c_plum, fade))
		draw_rect(Rect2(2.0, -12.0, 2.0, 2.0), Color(c_plum, fade))
		draw_rect(Rect2(-4.0, -9.0, 8.0, 4.0), Color(c_wine, fade))
		# Twin glowing rose-violet eyes
		draw_rect(Rect2(-3.0, -8.0, 2.0, 1.0), Color(c_rose, fade))
		draw_rect(Rect2(1.0, -8.0, 2.0, 1.0), Color(c_rose, fade))
		draw_rect(Rect2(-2.0, -8.0, 1.0, 1.0), Color(c_cream, fade))
		draw_rect(Rect2(2.0, -8.0, 1.0, 1.0), Color(c_cream, fade))
		# Unlit black-glass lantern
		draw_rect(Rect2(5.0, -5.0, 4.0, 7.0), Color(c_void, fade))
		draw_rect(Rect2(6.0, -4.0, 2.0, 5.0), Color(c_rose, fade))
		# Rising violet moth feathers during dissolve (1.50..2.0s)
		if _stage_t >= 1.50:
			var du: float = clampf((_stage_t - 1.50) / 0.50, 0.0, 1.0)
			for fi: int in range(5):
				var fx: float = (float(fi) - 2.0) * 5.0 - du * 12.0
				var fy: float = -6.0 - du * (12.0 + float(fi % 3) * 4.0)
				draw_rect(Rect2(roundf(fx), roundf(fy), 2.0, 2.0), Color(c_rose if fi % 2 == 0 else c_plum, 1.0 - du))
	_draw_signal_pulses()
