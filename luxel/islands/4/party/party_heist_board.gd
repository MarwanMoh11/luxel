class_name LxPartyHeistBoard
extends LxToy
## Island 4 Garden Party (party_r1): 6-Hour Heist Schedule Board.
## Displays 6 permanent Roman-hour intel medallions (I-VI) synced to party progress flags.
## Interacting sets `party_board_seen`, narrates the next uncompleted heist clue, and emits power.

const INTEL_FLAGS: Array[String] = [
	"party_token_1",
	"party_fork_2",
	"party_cellar_3",
	"party_winch_4",
	"boss_toastmaster_defeated",
	"golden_clock_key",
]

var _inspected_t: float = 0.0


func _toy_setup() -> void:
	kind = "party_heist_board"
	radius = 18.0
	size = Vector2(40.0, 20.0)
	_inspected_t = 0.0
	if Lx.state != null and bool(Lx.state.story_flags.get("party_board_seen", false)):
		powered = true
	queue_redraw()


func get_interact_prompt() -> String:
	return "ISL4_PT_PROMPT_BOARD" if active else ""


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_inspected_t = 0.65
	if Lx.state != null:
		Lx.state.story_flags["party_board_seen"] = true
	var clue: String = _pick_clue_string()
	if Lx.events != null and LxStrings.has_id(clue):
		Lx.events.narration_requested.emit(clue, "narration", 3.2)
	_emit_sfx("prop_chime")
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func _pick_clue_string() -> String:
	var st: LxGameState = Lx.state
	if st == null:
		return "ISL4_PT_CLUE_1"
	if bool(st.story_flags.get("party_done", false)) or bool(st.story_flags.get("golden_clock_key", false)):
		return "ISL4_PT_BOARD_DONE"
	if not bool(st.story_flags.get("party_token_1", false)) or not bool(st.story_flags.get("party_fork_2", false)):
		return "ISL4_PT_CLUE_1"
	if not bool(st.story_flags.get("party_cellar_3", false)):
		return "ISL4_PT_CLUE_2"
	if not bool(st.story_flags.get("party_winch_4", false)):
		return "ISL4_PT_CLUE_3"
	return "ISL4_PT_CLUE_4"


func _is_stamp_lit(idx: int) -> bool:
	if Lx.state == null or idx < 0 or idx >= INTEL_FLAGS.size():
		return false
	return bool(Lx.state.story_flags.get(INTEL_FLAGS[idx], false))


func tick(dt: float) -> void:
	super.tick(dt)
	if _inspected_t > 0.0:
		_inspected_t = maxf(0.0, _inspected_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 42.0 if _inspected_t > 0.0 else 30.0, 0.55)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 6.0), 18.0, 4.0)
	# Brass-framed easel board
	draw_rect(Rect2(-16.0, -2.0, 3.0, 8.0), c_dusk)
	draw_rect(Rect2(13.0, -2.0, 3.0, 8.0), c_dusk)
	LxToyDraw.draw_bevel_box(self, Rect2(-20.0, -18.0, 40.0, 18.0), c_night, c_wine, c_gold, c_void)
	draw_rect(Rect2(-18.0, -16.0, 36.0, 14.0), c_night)
	# Top header bar
	draw_rect(Rect2(-16.0, -15.0, 32.0, 2.0), c_cream if _inspected_t > 0.0 else c_apricot)
	# 6 permanent Roman-hour medallions (I-VI)
	for i: int in range(6):
		var lit: bool = _is_stamp_lit(i)
		var mx: float = -15.0 + float(i) * 5.6
		var my: float = -10.0
		draw_rect(Rect2(roundf(mx), my, 4.0, 6.0), c_void)
		draw_rect(Rect2(roundf(mx) + 1.0, my + 1.0, 2.0, 4.0), c_gold if lit else c_dusk)
		if lit:
			draw_rect(Rect2(roundf(mx) + 1.0, my + 1.0, 2.0, 1.0), c_cream)
		elif i == 5:
			draw_rect(Rect2(roundf(mx) + 1.0, my + 2.0, 2.0, 1.0), c_rose)
	_draw_signal_pulses()
