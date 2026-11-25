class_name LxStairBoard
extends LxToy
## Endless Stair Iron Ascent Scoreboard & Climb Launcher (`stair_r1` Base Hub).
## Displays live Best Floor, Best Iron Ascent Score, Toll Multiplier (+0.15x/sale),
## and Express Lift status (F4 / F8 / F12). Interacting starts a fresh seeded
## Iron Ascent climb (rotating pool seeds so consecutive climbs stay varied).

var _pulse_t: float = 0.0
var _best_score: int = 0
var _best_floor: int = 0
var _mult: float = 1.0
var _lifts: Array[bool] = [false, false, false]


func _toy_setup() -> void:
	kind = "stair_board"
	radius = 22.0
	_sync_stats()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	var prev_sc: int = _best_score
	var prev_fl: int = _best_floor
	_sync_stats()
	if _best_score != prev_sc or _best_floor != prev_fl:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_stats()
	_pulse_t = 0.65
	var dir: LxStairDirector = _get_director()
	if dir != null:
		dir.start_new_climb(true, 0)
	_emit_sfx("boon_draft")
	set_powered(true)
	emit_power(true)
	if Lx.events != null and LxStrings.has_id("ISL8_STAIR_IRON_START"):
		Lx.events.narration_requested.emit("ISL8_STAIR_IRON_START", "title", 2.4)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_STAIR_PROMPT_BOARD" if active else ""


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 4.0, 44.0, 0.70) if active else Vector4.ZERO


func _sync_stats() -> void:
	var dir: LxStairDirector = _get_director()
	if dir != null:
		_best_score = dir.get_best_score()
		_best_floor = dir.get_best_floor()
		_lifts[0] = dir.is_lift_unlocked(4)
		_lifts[1] = dir.is_lift_unlocked(8)
		_lifts[2] = dir.is_lift_unlocked(12)
	elif Lx.state != null:
		_best_score = int(Lx.state.story_flags.get("stair_best_score", 0))
		_best_floor = int(Lx.state.story_flags.get("stair_best_floor", 0))
		_lifts[0] = bool(Lx.state.story_flags.get("stair_lift_f4", false))
		_lifts[1] = bool(Lx.state.story_flags.get("stair_lift_f8", false))
		_lifts[2] = bool(Lx.state.story_flags.get("stair_lift_f12", false))
	_mult = 1.0 + 0.15 * float(LxSold.current().get_sold_count())


func _get_director() -> LxStairDirector:
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.stair != null:
		return LxIsland8Rule.active_instance.stair
	return null


func _draw() -> void:
	_draw_ground_shadow(18.0, 6.0, Vector2(0.0, 7.0))
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_sky: Color = PAL["sky"] as Color

	# Tall gothic brass ledger board on twin fluted legs
	draw_rect(Rect2(-15.0, 1.0, 4.0, 7.0), c_void)
	draw_rect(Rect2(11.0, 1.0, 4.0, 7.0), c_void)
	draw_rect(Rect2(-14.0, 2.0, 2.0, 5.0), c_dusk)
	draw_rect(Rect2(12.0, 2.0, 2.0, 5.0), c_dusk)

	draw_rect(Rect2(-20.0, -20.0, 40.0, 23.0), c_void)
	draw_rect(Rect2(-19.0, -19.0, 38.0, 21.0), c_gold)
	draw_rect(Rect2(-18.0, -18.0, 36.0, 19.0), c_night)
	draw_rect(Rect2(-17.0, -17.0, 34.0, 2.0), c_dusk)

	# Header: IRON + multiplier
	LxPixelFont.draw_centered(self, "x%.2f" % _mult, 0.0, -16.0, c_gold, 1, c_void)
	# Best score / floor readout
	var line2: String = "F%d %d" % [_best_floor, _best_score]
	LxPixelFont.draw_centered(self, line2, 0.0, -9.0, c_cream, 1, c_void)

	# 3 Express Lift indicator gems (F4 gold, F8 sky, F12 rose)
	var cols: Array[Color] = [c_gold, c_sky, c_rose]
	for i: int in range(3):
		var gx: float = -10.0 + float(i) * 10.0
		draw_rect(Rect2(gx - 3.0, -2.0, 6.0, 3.0), c_void)
		draw_rect(Rect2(gx - 2.0, -1.0, 4.0, 1.0), cols[i] if _lifts[i] else c_dusk)

	if _pulse_t > 0.0:
		var u: float = 1.0 - (_pulse_t / 0.65)
		draw_arc(Vector2(0.0, -8.0), roundf(12.0 + u * 22.0), 0.0, TAU, 20, Color(c_cream, 1.0 - u), 1.2)
	_draw_signal_pulses()
