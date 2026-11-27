class_name LxPalaceFalseKeyDecoy
extends LxToy
## Inverted Palace False Throne decoy Boss Key (`palace_r11`):
## Gleams golden in Silver World but casts a telltale NW shadow (`nw_wrong`).
## Touching, interacting, or hitting it shatters the counterfeit glass crown,
## announces "THE CROWN WAS GLASS!", reveals the hidden Moon Pool, and triggers its signal.

var shattered: bool = false
var sets_flag_id: String = "palace_false_throne_broken"
var _shatter_t: float = 0.0


func _toy_setup() -> void:
	kind = "palace_false_key"
	radius = 14.0
	sets_flag_id = str(props.get("sets_flag", "palace_false_throne_broken")).strip_edges()
	shattered = (not sets_flag_id.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag_id, false)))
	active = not shattered
	visible = true
	_shatter_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _shatter_t > 0.0:
		_shatter_t = maxf(0.0, _shatter_t - dt)
		queue_redraw()
	elif not shattered and active:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or shattered:
		return false
	return _trigger_shatter()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return _trigger_shatter()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or shattered or light_radius <= 0.0:
		return
	if source in ["lens", "lens_anchor"]:
		queue_redraw()


func _trigger_shatter() -> bool:
	shattered = true
	active = false
	_shatter_t = 0.55
	set_powered(true)
	if not sets_flag_id.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag_id] = true
	if Lx.events != null:
		Lx.events.narration_requested.emit("ISL7_PL_FAKE_CROWN", "title", 2.8)
		Lx.events.shake_requested.emit(0.08 if LxHudFx.flash_reduced() else 0.18)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.05)
	_emit_sfx("glass_shatter")
	_emit_gust(68.0, 56.0, Vector2.ZERO)
	_notify_linked_targets(true)
	_emit_save("false_key_" + id)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL7_PL_PROMPT_CROWN" if (active and not shattered) else ""


func get_light_pool() -> Vector4:
	if shattered:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 44.0, 0.78)


func save_state() -> Dictionary:
	return {"active": active, "shattered": shattered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	shattered = bool(d.get("shattered", shattered)) or (not sets_flag_id.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag_id, false)))
	active = not shattered
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_rose: Color = PAL["rose"] as Color
	if shattered:
		# Broken gilded glass shards on the floor
		for sp: Vector2 in [Vector2(-6.0, 2.0), Vector2(4.0, -2.0), Vector2(-1.0, 5.0), Vector2(6.0, 3.0)]:
			draw_rect(Rect2(sp, Vector2(3.0, 2.0)), c_ice)
			draw_rect(Rect2(sp, Vector2(1.0, 1.0)), c_rose)
		if _shatter_t > 0.0:
			var u: float = 1.0 - clampf(_shatter_t / 0.55, 0.0, 1.0)
			var sa: float = (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.95)
			draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 36.0, u)), 0.0, TAU, 18, Color(c_rose, sa), 2.0)
		return

	# Telltale NW LIE shadow (betrays the false golden key!)
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 8.0, 3.0, "nw_wrong", true)
	# Alabaster cushion pedestal
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -1.0, 16.0, 7.0), PAL["deep"] as Color, PAL["sky"] as Color, c_ice, c_void)
	# Counterfeit floating golden crown-key
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.8) * 2.0)
	var ky: float = -12.0 + bob
	draw_rect(Rect2(-5.0, ky - 4.0, 10.0, 8.0), c_void)
	draw_rect(Rect2(-4.0, ky - 3.0, 8.0, 6.0), c_gold)
	draw_rect(Rect2(-3.0, ky - 2.0, 2.0, 2.0), c_cream)
	draw_rect(Rect2(1.0, ky - 2.0, 2.0, 2.0), c_cream)
	draw_rect(Rect2(-1.0, ky + 3.0, 2.0, 5.0), c_void)
	draw_rect(Rect2(0.0, ky + 3.0, 1.0, 4.0), c_gold)
	_draw_signal_pulses()
