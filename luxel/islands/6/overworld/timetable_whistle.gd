class_name LxTimetableWhistle
extends LxInteractable
## High Trestle Convergence Signal Board & Express Whistle Fast-Shift (`kind: "signal_board"`).
## - Displays live Convergence pips (3 Crucibles + Ember Express + Iron Colossus).
## - Once `q6_timetable_key` is complete (or when `free_shift: true`), interacting also cycles
##   `kiln_shift` immediately from right here (Express Whistle Fast-Shift — zero backtracking tax!).

var _flash_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "signal_board"
	radius = maxf(16.0, radius)
	queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	if _can_fast_shift():
		return "ISL6_PROMPT_WHISTLE" if LxStrings.has_id("ISL6_PROMPT_WHISTLE") else "ISL6_PROMPT_SHIFT"
	return "ISL6_PROMPT_SIGNAL" if LxStrings.has_id("ISL6_PROMPT_SIGNAL") else "PROMPT_TALK"


func _can_fast_shift() -> bool:
	if bool(props.get("free_shift", false)):
		return true
	return LxQuests.current().is_quest_done("q6_timetable_key")


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_flash_t = 0.55
	if _can_fast_shift():
		LxIsland6Rule.cycle_kiln_shift()
		if region != null and region.has_method("apply_layers"):
			region.call("apply_layers")
		_notify_linked_targets(true)
		queue_redraw()
		return true
	_emit_sfx("ui_move")
	if Lx.events != null:
		var ready: bool = _convergence_ready()
		var sid: String = "ISL6_SIGNAL_READY" if ready else "ISL6_SIGNAL_WAIT"
		if LxStrings.has_id(sid):
			Lx.events.narration_requested.emit(sid, "narration", 3.0)
	queue_redraw()
	return true


func _convergence_ready() -> bool:
	if Lx.state == null:
		return false
	for b: String in ["beacon_6_1", "beacon_6_2", "beacon_6_3"]:
		if not Lx.state.lit_beacons.has(b) and not bool(Lx.state.story_flags.get(b, false)):
			return false
	return bool(Lx.state.story_flags.get("express_cleared", false)) and bool(Lx.state.story_flags.get("colossus_cleared", false))


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 10.0, 46.0 if _convergence_ready() else 32.0, 0.85 if _convergence_ready() else 0.55)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(12.0, 3.5, Vector2(0.0, 2.0))
	# Brass Railway Convergence Signal Tower Board
	draw_rect(Rect2(-14.0, -24.0, 28.0, 26.0), PAL["void"] as Color)
	draw_rect(Rect2(-13.0, -23.0, 26.0, 24.0), PAL["dusk"] as Color)
	draw_rect(Rect2(-12.0, -22.0, 24.0, 16.0), PAL["night"] as Color)
	draw_rect(Rect2(-12.0, -23.0, 24.0, 2.0), PAL["apricot"] as Color)
	# Row 1: 3 Crucible Beacon pips
	var st: LxGameState = Lx.state
	var beacons: Array[String] = ["beacon_6_1", "beacon_6_2", "beacon_6_3"]
	for i: int in range(3):
		var lit: bool = st != null and (st.lit_beacons.has(beacons[i]) or bool(st.story_flags.get(beacons[i], false)))
		draw_rect(Rect2(-9.0 + float(i * 7), -19.0, 5.0, 4.0), PAL["gold"] as Color if lit else PAL["plum"] as Color)
		if lit:
			draw_rect(Rect2(-8.0 + float(i * 7), -18.0, 3.0, 2.0), PAL["cream"] as Color)
	# Row 2: Express Wheel (L) & Colossus Fist (R)
	var exp_ok: bool = st != null and bool(st.story_flags.get("express_cleared", false))
	var col_ok: bool = st != null and bool(st.story_flags.get("colossus_cleared", false))
	draw_rect(Rect2(-9.0, -12.0, 7.0, 4.0), PAL["apricot"] as Color if exp_ok else PAL["plum"] as Color)
	draw_rect(Rect2(2.0, -12.0, 7.0, 4.0), PAL["coral"] as Color if col_ok else PAL["plum"] as Color)
	# Active shift indicator pips at base
	var sidx: int = LxIsland6Rule.VALID_SHIFTS.find(LxIsland6Rule.get_kiln_shift())
	for j: int in range(3):
		draw_rect(Rect2(-7.0 + float(j * 6), -4.0, 4.0, 2.0), PAL["cream"] as Color if j == sidx else PAL["night"] as Color)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2(0.0, -12.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, PAL["gold"] as Color, 1.0)
