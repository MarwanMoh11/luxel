class_name LxI7SpotlightBench
extends LxToy
## Backstage Spotlight Bench in velvet_promenade unlocked by Tailor Spider (`q7_masked_tailor`).
## Resting under the golden stage spotlight refills Ember to max and restores 1 heart.

var require_flag: String = "q7_tailor_bench"
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "i7_spotlight_bench"
	require_flag = str(props.get("require_flag", "q7_tailor_bench")).strip_edges()
	size = Vector2(28.0, 14.0)
	radius = 18.0
	_flash_t = 0.0
	queue_redraw()


func is_unlocked() -> bool:
	if require_flag.is_empty():
		return true
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get(require_flag, false)) \
		or bool(Lx.state.story_flags.get("quest:q7_masked_tailor:done", false))


func get_interact_prompt() -> String:
	if not active or not is_unlocked():
		return ""
	return "ISL7_PROMPT_BENCH"


func interact(_actor: Node = null) -> bool:
	if not active or not is_unlocked():
		return false
	_flash_t = 0.65
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var emax: float = w.move_sunflare.get_ember_max() if w.move_sunflare != null else 100.0
		w.ember = maxf(w.ember, emax)
	if Lx.state != null:
		Lx.state.ember = maxf(Lx.state.ember, Lx.state.max_ember)
		Lx.state.hearts = minf(Lx.state.max_hearts, Lx.state.hearts + 1.0)
	_emit_sfx("shrine_unlock")
	_emit_gust(48.0, 36.0)
	if Lx.events != null and LxStrings.has_id("ISL7_BENCH_FULL"):
		Lx.events.narration_requested.emit("ISL7_BENCH_FULL", "narration", 2.4)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if is_unlocked():
		return Vector4(pos.x, pos.y - 4.0, 56.0, 0.95)
	return Vector4(pos.x, pos.y - 4.0, 22.0, 0.28)


func _draw() -> void:
	if not active:
		return
	var lit: bool = is_unlocked()
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	if lit:
		draw_circle(Vector2(0.0, 2.0), 20.0, Color(c_gold, 0.24))
		draw_arc(Vector2(0.0, 2.0), 20.0, 0.0, TAU, 18, Color(c_cream, 0.55), 1.0)
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 12.0, 3.0, "se_gold", lit)
	draw_rect(Rect2(-13.0, -5.0, 26.0, 10.0), c_void)
	draw_rect(Rect2(-12.0, -4.0, 24.0, 8.0), c_wine if lit else c_plum)
	draw_rect(Rect2(-12.0, -4.0, 24.0, 2.0), c_gold if lit else c_night)
	draw_rect(Rect2(-10.0, 5.0, 3.0, 3.0), c_void)
	draw_rect(Rect2(7.0, 5.0, 3.0, 3.0), c_void)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2(0.0, -2.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, c_cream, 1.5)
