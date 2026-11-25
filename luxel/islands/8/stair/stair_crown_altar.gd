class_name LxStairCrownAltar
extends LxToy
## Floor 12 Eclipse Crown Victory Plinth (`stair_r10`).
## Activates once Stair Warden Act III (Eclipse Sovereign) falls, locks in
## Floor 12 Iron Ascent score + Express Lift F12 + `stair_cleared`, and displays
## the climb's score & Toll Multiplier on a radiant star-crown ledger.

var _cleared: bool = false
var _final_score: int = 0
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "stair_crown_altar"
	radius = 22.0
	_sync_cleared()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	var prev: bool = _cleared
	_sync_cleared()
	if _cleared and not prev:
		_on_crown_claimed()
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_cleared()
	_pulse_t = 0.60
	_emit_sfx("boon_draft")
	if _cleared:
		_on_crown_claimed()
		if Lx.events != null and LxStrings.has_id("ISL8_STAIR_CLEARED"):
			Lx.events.narration_requested.emit("ISL8_STAIR_CLEARED", "title", 2.8)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_STAIR_PROMPT_CROWN" if (active and _cleared) else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 56.0 if _cleared else 24.0, 0.90 if _cleared else 0.36)


func _sync_cleared() -> void:
	if Lx.state == null:
		return
	var done: bool = bool(Lx.state.story_flags.get("stair_cleared", false)) \
		or bool(Lx.state.story_flags.get("stair_warden_defeated", false)) \
		or Lx.state.defeated_bosses.has("stair_warden")
	_cleared = done
	if _cleared:
		var dir: LxStairDirector = _get_director()
		if dir != null:
			_final_score = maxi(_final_score, dir.get_best_score())
		else:
			_final_score = int(Lx.state.story_flags.get("stair_best_score", 0))


func _on_crown_claimed() -> void:
	if Lx.state != null:
		Lx.state.story_flags["stair_cleared"] = true
		Lx.state.story_flags["stair_lift_f12"] = true
		Lx.state.story_flags["dungeon_done:endless_stair"] = true
	var dir: LxStairDirector = _get_director()
	if dir != null:
		var info: Dictionary = dir.complete_floor(12)
		_final_score = maxi(_final_score, int(info.get("score", 0)))
	set_powered(true)
	emit_power(true)


func _get_director() -> LxStairDirector:
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.stair != null:
		return LxIsland8Rule.active_instance.stair
	return null


func _draw() -> void:
	_draw_ground_shadow(15.0, 6.0, Vector2(0.0, 6.0))
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	draw_rect(Rect2(-14.0, -2.0, 28.0, 8.0), c_void)
	draw_rect(Rect2(-13.0, -1.0, 26.0, 6.0), c_rose if _cleared else c_dusk)
	draw_rect(Rect2(-11.0, 0.0, 22.0, 4.0), c_night)

	# Crown spire silhouette
	draw_rect(Rect2(-9.0, -16.0, 18.0, 14.0), c_void)
	draw_rect(Rect2(-8.0, -15.0, 16.0, 12.0), c_gold if _cleared else c_night)
	draw_rect(Rect2(-7.0, -14.0, 14.0, 10.0), c_night)
	if _cleared:
		draw_rect(Rect2(-6.0, -18.0, 2.0, 4.0), c_cream)
		draw_rect(Rect2(-1.0, -20.0, 2.0, 6.0), c_cream)
		draw_rect(Rect2(4.0, -18.0, 2.0, 4.0), c_cream)
		LxPixelFont.draw_centered(self, "F12", 0.0, -12.0, c_cream, 1, c_void)
		if _final_score > 0:
			LxPixelFont.draw_centered(self, "%d" % _final_score, 0.0, -6.0, c_gold, 1, c_void)
	else:
		LxPixelFont.draw_centered(self, "XII", 0.0, -11.0, PAL["mauve"] as Color, 1, c_void)

	if _pulse_t > 0.0:
		var u: float = 1.0 - (_pulse_t / 0.60)
		draw_arc(Vector2(0.0, -8.0), roundf(12.0 + u * 28.0), 0.0, TAU, 20, Color(c_cream, 1.0 - u), 1.5)
	_draw_signal_pulses()
