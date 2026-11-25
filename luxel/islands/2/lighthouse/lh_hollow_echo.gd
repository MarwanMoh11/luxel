class_name LxLhHollowEcho
extends LxToy
## Wordless Hollow Wick silhouette vignette for `lighthouse_r16` (Dark-Glass Gallery).
## Across the glass divider, Hollow Wick stands holding an unlit dark-glass lantern,
## fires a cold blue bolt shattering a dummy lamp, and vanishes through the north portal.

var lamp_pos: Vector2 = Vector2.ZERO
var portal_pos: Vector2 = Vector2.ZERO
var sets_flag: String = "lh_r16_hollow_seen"
var _stage_t: float = 0.0
var _playing: bool = false
var _done: bool = false
var _shot_fired: bool = false
var _vanished: bool = false
var _cur_pos: Vector2 = Vector2.ZERO


func _toy_setup() -> void:
	kind = "lh_hollow_echo"
	z_index = 2
	radius = 12.0
	lamp_pos = _parse_vec2(props.get("lamp_pos", [pos.x + 48.0, pos.y]), pos + Vector2(48.0, 0.0))
	portal_pos = _parse_vec2(props.get("portal_pos", [pos.x - 40.0, pos.y - 8.0]), pos + Vector2(-40.0, -8.0))
	sets_flag = str(props.get("sets_flag", "lh_r16_hollow_seen")).strip_edges()
	_done = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_playing = not _done
	_stage_t = 0.0
	_shot_fired = false
	_vanished = _done
	_cur_pos = pos
	queue_redraw()


func reset_toy() -> void:
	_done = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_playing = not _done
	_stage_t = 0.0
	_shot_fired = false
	_vanished = _done
	_cur_pos = pos
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
	if _stage_t >= 1.15 and not _shot_fired:
		_shot_fired = true
		_emit_sfx("prism_bounce")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.08)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(lamp_pos, 52.0, 1.0, 0.25)
	if _stage_t >= 1.85:
		var u: float = clampf((_stage_t - 1.85) / 1.10, 0.0, 1.0)
		_cur_pos = pos.lerp(portal_pos, u)
	if _stage_t >= 3.05 and not _vanished:
		_vanished = true
		_playing = false
		_done = true
		_emit_sfx("portal_swap_chime")
		if not sets_flag.is_empty() and Lx.state != null:
			Lx.state.story_flags[sets_flag] = true
		if Lx.events != null and LxStrings.has_id("LH2_HOLLOW_ECHO"):
			Lx.events.narration_requested.emit("LH2_HOLLOW_ECHO", "ice", 3.2)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if not _shot_fired:
		return Vector4(lamp_pos.x, lamp_pos.y, 44.0, 0.65)
	if _playing and not _vanished:
		return Vector4(_cur_pos.x, _cur_pos.y, 30.0, 0.40)
	return Vector4.ZERO


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var lp: Vector2 = (lamp_pos - pos).round()
	# Dummy brass lamp behind the glass (lit until shattered at 1.15s)
	draw_rect(Rect2(lp + Vector2(-4.0, -7.0), Vector2(8.0, 12.0)), c_void)
	if not _shot_fired:
		draw_rect(Rect2(lp + Vector2(-3.0, -6.0), Vector2(6.0, 8.0)), PAL["gold"] as Color)
		draw_rect(Rect2(lp + Vector2(-1.0, -4.0), Vector2(2.0, 4.0)), c_cream)
	else:
		draw_rect(Rect2(lp + Vector2(-3.0, 1.0), Vector2(6.0, 4.0)), PAL["dusk"] as Color)
		draw_rect(Rect2(lp + Vector2(-6.0, 4.0), Vector2(2.0, 2.0)), c_ice)
		draw_rect(Rect2(lp + Vector2(5.0, 3.0), Vector2(2.0, 2.0)), PAL["sky"] as Color)
	# Cold blue bolt streak during 1.15..1.55s
	if _playing and _stage_t >= 1.15 and _stage_t <= 1.55:
		var bu: float = clampf((_stage_t - 1.15) / 0.20, 0.0, 1.0)
		var bpt: Vector2 = Vector2.ZERO.lerp(lp, bu)
		draw_line(Vector2.ZERO, bpt, c_blue, 3.0)
		draw_line(Vector2.ZERO, bpt, c_ice, 1.4)
		if bu >= 0.85:
			draw_arc(lp, roundf(lerpf(4.0, 14.0, (_stage_t - 1.15) / 0.40)), 0.0, TAU, 12, c_ice, 1.2)
	# Hollow Wick silhouette (cloak + unlit dark-glass lantern) before vanish
	if _playing and not _vanished:
		var hp: Vector2 = (_cur_pos - pos).round()
		var fade: float = 1.0 - clampf((_stage_t - 2.75) / 0.30, 0.0, 1.0)
		# Cloak & hood
		draw_rect(Rect2(hp + Vector2(-4.0, -9.0), Vector2(8.0, 13.0)), Color(c_void, fade))
		draw_rect(Rect2(hp + Vector2(-3.0, -8.0), Vector2(6.0, 11.0)), Color(c_deep, fade))
		draw_rect(Rect2(hp + Vector2(-2.0, -7.0), Vector2(4.0, 3.0)), Color(c_blue, fade))
		# Cold ice eyes
		draw_rect(Rect2(hp + Vector2(-2.0, -6.0), Vector2(1.0, 1.0)), Color(c_ice, fade))
		draw_rect(Rect2(hp + Vector2(1.0, -6.0), Vector2(1.0, 1.0)), Color(c_ice, fade))
		# Unlit dark-glass lantern held forward
		draw_rect(Rect2(hp + Vector2(4.0, -4.0), Vector2(4.0, 6.0)), Color(c_void, fade))
		draw_rect(Rect2(hp + Vector2(5.0, -3.0), Vector2(2.0, 4.0)), Color(c_blue, fade))
	# Vanish portal ripple
	if _stage_t >= 2.85 and _stage_t <= 3.45:
		var pp: Vector2 = (portal_pos - pos).round()
		var vu: float = clampf((_stage_t - 2.85) / 0.60, 0.0, 1.0)
		draw_arc(pp, roundf(lerpf(3.0, 16.0, vu)), 0.0, TAU, 14, Color(c_ice, 1.0 - vu), 1.4)
