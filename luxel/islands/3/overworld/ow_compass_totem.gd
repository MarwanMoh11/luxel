class_name LxOwCompassTotem
extends LxToy
## Island 3 Lantern Glade Wood-Compass Totem:
## - Always displays the Shifting Woods' live 3-wedge state (0=MOSS, 1=SILK, 2=CROWN)
##   and pin-pips for Western, Eastern, and Crown clearings (pin_w / pin_e / pin_n).
## - Before `island_3_relit`: interacting reads the compass and whispers ISL3_HINT_SHIFT.
## - After `island_3_relit`: interacting or shooting freely rotates `wood_turn = (wood_turn + 1) % 3`
##   so endgame exploration can select any Shifting Wood configuration right from camp!

const SCOPE_ISLAND: String = "island:3"
const TOGGLE_CD: float = 0.28

var _pulse_t: float = 0.0
var _cd_t: float = 0.0


func _toy_setup() -> void:
	kind = "ow_compass_totem"
	size = Vector2(24.0, 24.0)
	radius = 16.0
	_pulse_t = 0.0
	_cd_t = 0.0
	queue_redraw()


func _is_relit() -> bool:
	if Lx.state == null:
		return false
	return Lx.state.relit_islands.has(3) or bool(Lx.state.story_flags.get("island_3_relit", false))


func _current_turn() -> int:
	return posmod(int(LxToyDraw.world_get_var(SCOPE_ISLAND, "wood_turn", 0)), 3)


func _is_pinned(c: String) -> bool:
	return int(LxToyDraw.world_get_var(SCOPE_ISLAND, "pin_" + c, 0)) != 0


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _cd_t > 0.0:
		_cd_t = maxf(0.0, _cd_t - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or _cd_t > 0.0:
		return false
	_cd_t = TOGGLE_CD
	_pulse_t = 0.45
	if _is_relit():
		var nxt: int = (_current_turn() + 1) % 3
		LxToyDraw.world_set_var(SCOPE_ISLAND, "wood_turn", nxt)
		for c: String in ["w", "e", "n"]:
			if not _is_pinned(c):
				LxToyDraw.world_set_var(SCOPE_ISLAND, "eff_turn_" + c, nxt)
		_emit_sfx("wood_shift")
		_emit_gust(56.0, 36.0)
		if Lx.events != null and LxStrings.has_id("ISL3_RELIT_NOTE"):
			Lx.events.narration_requested.emit("ISL3_RELIT_NOTE", "narration", 2.8)
	else:
		_emit_sfx("prop_chime")
		if Lx.events != null and LxStrings.has_id("ISL3_HINT_SHIFT"):
			Lx.events.narration_requested.emit("ISL3_HINT_SHIFT", "narration", 3.4)
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not _is_relit() or _cd_t > 0.0:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW]:
		return interact(null)
	return false


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL3_PROMPT_STEER_WOOD" if _is_relit() else "ISL3_PROMPT_TOTEM"


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(8.0, 6.0), Vector2(16.0, 12.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 56.0 if _is_relit() else 40.0, 0.85 if _is_relit() else 0.55)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var turn: int = _current_turn()
	var relit: bool = _is_relit()

	# Mossy inlaid stone compass ring on ground
	draw_circle(Vector2(0.0, 4.0), 15.0, c_void)
	draw_circle(Vector2(0.0, 4.0), 14.0, c_night)
	draw_arc(Vector2(0.0, 4.0), 13.0, 0.0, TAU, 20, c_gold if relit else c_dusk, 1.0)

	var dirs: Array[Vector2] = [Vector2(-1.0, 0.55).normalized(), Vector2(1.0, 0.55).normalized(), Vector2(0.0, -1.0)]
	var cols: Array[Color] = [c_lime, c_rose, c_gold]
	var shapes: Array[int] = [2, 1, 5] # triangle=MOSS, diamond=SILK, star=CROWN
	for i: int in range(3):
		var wp: Vector2 = (Vector2(0.0, 4.0) + dirs[i] * 9.0).round()
		var is_cur: bool = i == turn
		LxToyDraw.draw_shape_glyph(self, wp, shapes[i], is_cur, cols[i] if is_cur else c_dusk, c_cream if is_cur else c_pine)
		if is_cur:
			draw_line(Vector2(0.0, 4.0), wp, c_cream if relit else cols[i], 1.5)

	# Carved heartwood totem pillar
	LxToyDraw.draw_bevel_box(self, Rect2(-5.0, -16.0, 10.0, 18.0), c_night, c_pine if not relit else c_apricot, c_gold if relit else c_stone, c_void)
	# Three clearing pin-pips (W / E / N)
	var clr_keys: Array[String] = ["w", "e", "n"]
	for j: int in range(3):
		var px: float = -3.0 + float(j) * 3.0
		var pinned: bool = _is_pinned(clr_keys[j])
		draw_rect(Rect2(px, -13.0, 2.0, 2.0), c_cream if pinned else c_dusk)
		if pinned:
			draw_rect(Rect2(px, -14.0, 2.0, 1.0), c_gold)
	# Sun crown atop totem
	draw_rect(Rect2(-3.0, -19.0, 6.0, 3.0), c_void)
	draw_rect(Rect2(-2.0, -18.0, 4.0, 2.0), c_cream if relit else c_gold)

	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2(0.0, -6.0), roundf(lerpf(6.0, 20.0, u)), 0.0, TAU, 18, c_cream if relit else c_lime, 1.0)
	_draw_signal_pulses()
