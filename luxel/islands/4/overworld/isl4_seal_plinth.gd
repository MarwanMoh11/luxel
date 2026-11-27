class_name LxIsl4SealPlinth
extends LxToy
## Island 4 Grand Seal Plinth (`isl4_seal_plinth`):
## Displays live visual status of one of Mirefen's 3 major wing seals
## (Hourglass Maze, Rain Mausoleum, The Garden Party) at Clock Terrace's
## 3-Seal Archway and Conservatory Court.
## Props: seal_flag (String), alt_flag (String), seal_kind ("hourglass"|"mausoleum"|"party"),
## hint_string_id (String).

var seal_flag: String = "dungeon_hourglass_done"
var alt_flag: String = ""
var seal_kind: String = "hourglass"
var hint_string_id: String = "ISL4_SEAL_HOURGLASS"
var seal_lit: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "isl4_seal_plinth"
	seal_flag = str(props.get("seal_flag", "dungeon_hourglass_done")).strip_edges()
	alt_flag = str(props.get("alt_flag", "")).strip_edges()
	seal_kind = str(props.get("seal_kind", "hourglass")).strip_edges().to_lower()
	hint_string_id = str(props.get("hint_string_id", "ISL4_SEAL_HOURGLASS")).strip_edges()
	radius = 16.0
	_refresh_lit(false)
	queue_redraw()


func _refresh_lit(with_fx: bool) -> void:
	var now_lit: bool = _check_flag(seal_flag) or (not alt_flag.is_empty() and _check_flag(alt_flag))
	if now_lit != seal_lit:
		seal_lit = now_lit
		set_powered(seal_lit)
		if seal_lit and with_fx:
			_pulse_t = 0.8
			_emit_sfx("prop_chime")
			emit_power(true)
		queue_redraw()


func _check_flag(fl: String) -> bool:
	if fl.is_empty() or Lx.state == null:
		return false
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", fl))
	return bool(Lx.state.story_flags.get(fl, false))


func tick(dt: float) -> void:
	super.tick(dt)
	_refresh_lit(true)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.75
	_emit_sfx("prop_chime" if seal_lit else "ui_move")
	if Lx.events != null:
		var sid: String = "ISL4_SEAL_LIT" if seal_lit else hint_string_id
		if LxStrings.has_id(sid):
			Lx.events.narration_requested.emit(sid, "narration", 3.2)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_INSPECT_SEAL" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -4.0), Vector2(14.0, 10.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if seal_lit:
		return Vector4(pos.x, pos.y - 8.0, 52.0, 0.82)
	return Vector4(pos.x, pos.y - 8.0, 22.0, 0.30)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var accent: Color = c_gold
	if seal_kind == "mausoleum":
		accent = PAL["sky"] as Color
	elif seal_kind == "party":
		accent = PAL["rose"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, 0.0, 16.0, 6.0), c_night, c_dusk, c_stone, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, -16.0, 12.0, 17.0), c_night, c_dusk, accent if seal_lit else c_mauve, c_void)
	# Crest emblem by wing (void-backed socket for greyscale contrast)
	draw_rect(Rect2(-4.0, -14.0, 8.0, 12.0), c_void)
	var crest_c: Color = c_cream if (seal_lit or (_pulse_t > 0.0 and not fred)) else c_mauve
	var fill_c: Color = accent if seal_lit else c_dusk
	if seal_kind == "hourglass":
		draw_rect(Rect2(-3.0, -13.0, 6.0, 2.0), crest_c)
		draw_rect(Rect2(-2.0, -11.0, 4.0, 2.0), fill_c)
		draw_rect(Rect2(-1.0, -9.0, 2.0, 2.0), crest_c)
		draw_rect(Rect2(-2.0, -7.0, 4.0, 2.0), fill_c)
		draw_rect(Rect2(-3.0, -5.0, 6.0, 2.0), crest_c)
	elif seal_kind == "mausoleum":
		draw_rect(Rect2(-1.0, -13.0, 2.0, 3.0), crest_c)
		draw_rect(Rect2(-3.0, -10.0, 6.0, 4.0), fill_c)
		draw_rect(Rect2(-2.0, -6.0, 4.0, 2.0), crest_c)
	else:
		draw_rect(Rect2(-3.0, -12.0, 6.0, 4.0), fill_c)
		draw_rect(Rect2(-1.0, -11.0, 2.0, 2.0), crest_c)
		draw_rect(Rect2(-1.0, -8.0, 2.0, 5.0), crest_c)
		draw_rect(Rect2(1.0, -5.0, 2.0, 1.0), crest_c)

	if seal_lit:
		var flick: float = 0.0 if fred else roundf(sin(_clock * 5.0) * 1.0)
		draw_rect(Rect2(-6.0, -18.0, 2.0, 2.0), accent)
		draw_rect(Rect2(4.0, -18.0, 2.0, 2.0), accent)
		draw_rect(Rect2(-3.0, -23.0 + flick, 6.0, 6.0), c_void)
		draw_rect(Rect2(-2.0, -21.0 + flick, 4.0, 4.0), accent)
		draw_rect(Rect2(-1.0, -22.0 + flick, 2.0, 3.0), c_cream)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.75, 0.0, 1.0)
		var pa: float = (1.0 - u) * (0.48 if fred else 0.88)
		draw_arc(Vector2(0.0, -9.0), roundf(lerpf(6.0, 18.0, u)), 0.0, TAU, 14, Color(c_cream if seal_lit else accent, pa), 1.0)
