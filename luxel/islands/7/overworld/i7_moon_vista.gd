class_name LxI7MoonVista
extends LxToy
## Sunken Moon Pool vista shrine in silver_quay for Mirror Crab's `q_silver_lens`.
## Flip to Black World and shine lantern light (or interact) to mark `quest:view:moon_pool`.

var view_id: String = "moon_pool"
var require_face: String = "black"
var viewed: bool = false
var _lit_t: float = 0.0
var _bloom_t: float = 0.0


func _toy_setup() -> void:
	kind = "i7_moon_vista"
	view_id = str(props.get("view_id", "moon_pool")).strip_edges()
	require_face = str(props.get("require_face", "black")).strip_edges().to_lower()
	radius = 20.0
	z_index = -3
	viewed = LxQuests.current().has_flag("quest:view:" + view_id)
	powered = viewed
	_lit_t = 0.0
	_bloom_t = 0.0
	queue_redraw()


func _face_matches() -> bool:
	if require_face.is_empty():
		return true
	var cur: String = str(LxToyDraw.world_get_var("island:7", "world_face", "silver")).strip_edges().to_lower()
	return cur == require_face


func on_light(light_radius: float, _source: String) -> void:
	if not active or light_radius <= 0.0 or not _face_matches():
		return
	_lit_t = 0.65
	if not viewed:
		_complete_vista()
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not _face_matches():
		return false
	if not viewed:
		return _complete_vista()
	_lit_t = 0.65
	_emit_sfx("mirror_ping")
	queue_redraw()
	return true


func _complete_vista() -> bool:
	viewed = true
	_bloom_t = 0.85
	LxQuests.current().mark_light_view(view_id)
	set_powered(true)
	emit_power(true)
	_emit_sfx("shrine_unlock")
	_emit_gust(56.0, 44.0)
	if Lx.events != null:
		Lx.events.save_requested.emit("vista_" + view_id)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active or viewed or not _face_matches():
		return ""
	return "PROMPT_IGNITE"


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _lit_t > 0.0:
		_lit_t = maxf(0.0, _lit_t - dt)
		dirty = true
	if _bloom_t > 0.0:
		_bloom_t = maxf(0.0, _bloom_t - dt)
		dirty = true
	if not viewed and LxQuests.current().has_flag("quest:view:" + view_id):
		viewed = true
		powered = true
		dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active or not _face_matches():
		return Vector4.ZERO
	if viewed or _lit_t > 0.0:
		return Vector4(pos.x, pos.y, 58.0, 0.92)
	return Vector4(pos.x, pos.y, 32.0, 0.44)


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	if not _face_matches():
		# Faint submerged silhouette beneath Silver tide
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 16, Color(c_sky, 0.35), 1.0)
		draw_circle(Vector2.ZERO, 6.0, Color(c_night, 0.25))
		return

	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 12.0, 4.0, "se_gold", viewed or _lit_t > 0.0)
	draw_circle(Vector2.ZERO, 14.0, c_void)
	draw_circle(Vector2.ZERO, 12.5, c_gold if viewed else c_plum)
	draw_circle(Vector2.ZERO, 10.0, c_night)
	draw_circle(Vector2.ZERO, 8.0, c_ice if viewed else c_rose)
	draw_circle(Vector2(-1.0, -1.0), 4.0, c_cream if viewed else c_void)
	if viewed:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 18, Color(c_gold, 0.65), 1.0)
	if _bloom_t > 0.0:
		var u: float = 1.0 - clampf(_bloom_t / 0.85, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 32.0, u)), 0.0, TAU, 20, Color(c_cream, 1.0 - u), 1.5)
	_draw_signal_pulses()
