class_name LxI7ShadowDecoy
extends LxToy
## Lying NW-shadow plinth / decoy for `q7_true_reflection` and Shadow-Step Waltz.
## Truth objects cast SE gold shadow; lies cast NW wrong-way shadow (`nw_wrong`).
## Unmasking (interact or hit) shatters a lie, sets `reveal_flag`, and emits signal.

var reveal_flag: String = ""
var decoy_style: String = "mirror"
var is_truth: bool = false
var silent: bool = false
var unmasked: bool = false
var lit: bool = false
var activated: bool = false
var _lens_t: float = 0.0
var _shatter_t: float = 0.0


func _toy_setup() -> void:
	kind = "i7_shadow_decoy"
	reveal_flag = str(props.get("reveal_flag", props.get("sets_flag", ""))).strip_edges()
	decoy_style = str(props.get("decoy_style", "mirror")).strip_edges().to_lower()
	is_truth = bool(props.get("truth", false))
	silent = bool(props.get("silent", false))
	if not props.has("persist"):
		persist = true
	radius = 15.0
	_lens_t = 0.0
	_shatter_t = 0.0
	unmasked = (not reveal_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(reveal_flag, false)))
	lit = unmasked
	activated = unmasked
	powered = unmasked
	queue_redraw()


func reset_toy() -> void:
	if persist and unmasked:
		return
	unmasked = false
	lit = false
	activated = false
	_shatter_t = 0.0
	set_powered(false)
	queue_redraw()


func get_interact_prompt() -> String:
	if not active or unmasked:
		return ""
	return "ISL7_PROMPT_UNMASK" if LxStrings.has_id("ISL7_PROMPT_UNMASK") else "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if not active or unmasked:
		return false
	return _trigger_unmask()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or unmasked:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE]:
		return _trigger_unmask()
	return false


func on_light(light_radius: float, source: String) -> void:
	if active and not unmasked and light_radius > 0.0 and source in ["lens", "lens_anchor"]:
		_lens_t = 1.8
		queue_redraw()


func _trigger_unmask() -> bool:
	if is_truth:
		_emit_sfx("denied")
		return false
	unmasked = true
	lit = true
	activated = true
	_shatter_t = 0.50
	if not reveal_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[reveal_flag] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("mask_shatter")
	_emit_gust(48.0, 42.0)
	if not silent and Lx.events != null and LxStrings.has_id("ISL7_DECOY_FOUND"):
		Lx.events.narration_requested.emit("ISL7_DECOY_FOUND", "narration", 2.6)
	if persist and Lx.events != null and not reveal_flag.is_empty():
		Lx.events.save_requested.emit(reveal_flag)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	# Keep unmasked synced if LxChallenge._reset_light_targets() resets lit = false
	if not lit and unmasked and not persist:
		unmasked = false
		activated = false
		set_powered(false)
		dirty = true
	if _lens_t > 0.0:
		_lens_t = maxf(0.0, _lens_t - dt)
		dirty = true
	if _shatter_t > 0.0:
		_shatter_t = maxf(0.0, _shatter_t - dt)
		dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if unmasked:
		return Vector4(pos.x, pos.y - 4.0, 26.0, 0.34)
	return Vector4(pos.x, pos.y - 6.0, 34.0, 0.46)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["unmasked"] = unmasked
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("unmasked", false)):
		unmasked = true
		lit = true
		activated = true
		powered = true
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	if unmasked:
		# Shattered silver-glass shards showing the broken illusion
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 3.0), 6.0, 2.0, "se_gold", false)
		draw_rect(Rect2(-6.0, -2.0, 12.0, 6.0), c_void)
		draw_rect(Rect2(-5.0, -1.0, 10.0, 4.0), c_night)
		draw_rect(Rect2(-4.0, 0.0, 3.0, 2.0), c_rose)
		draw_rect(Rect2(1.0, -1.0, 3.0, 2.0), c_ice)
		if _shatter_t > 0.0:
			var u: float = 1.0 - clampf(_shatter_t / 0.50, 0.0, 1.0)
			draw_arc(Vector2(0.0, -4.0), roundf(4.0 + u * 20.0), 0.0, TAU, 16, c_rose, 1.5)
		return

	# Truth Shadow Law: lies cast NW wrong shadow, truth casts SE gold shadow!
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 3.0), 7.0, 3.0, "se_gold" if is_truth else "nw_wrong", _lens_t > 0.0)

	# Plinth + mirror/lantern/bust silhouette
	draw_rect(Rect2(-7.0, -2.0, 14.0, 6.0), c_void)
	draw_rect(Rect2(-6.0, -1.0, 12.0, 4.0), c_dusk)
	if decoy_style == "lantern":
		draw_rect(Rect2(-5.0, -14.0, 10.0, 13.0), c_void)
		draw_rect(Rect2(-4.0, -13.0, 8.0, 11.0), c_night)
		draw_rect(Rect2(-3.0, -11.0, 6.0, 7.0), c_gold if is_truth else c_ice)
		draw_rect(Rect2(-1.0, -10.0, 2.0, 4.0), c_cream)
	elif decoy_style == "bust":
		draw_rect(Rect2(-5.0, -15.0, 10.0, 14.0), c_void)
		draw_rect(Rect2(-4.0, -14.0, 8.0, 12.0), c_sky)
		draw_rect(Rect2(-3.0, -13.0, 6.0, 5.0), c_ice)
		draw_rect(Rect2(-2.0, -11.0, 1.0, 1.0), c_void)
		draw_rect(Rect2(1.0, -11.0, 1.0, 1.0), c_void)
	else:
		# Standing silver oval mirror decoy
		draw_rect(Rect2(-6.0, -17.0, 12.0, 16.0), c_void)
		draw_rect(Rect2(-5.0, -16.0, 10.0, 14.0), c_gold if is_truth else c_sky)
		draw_rect(Rect2(-3.0, -14.0, 6.0, 10.0), c_ice)
		draw_line(Vector2(-2.0, -12.0), Vector2(2.0, -8.0), c_cream, 1.0)
	_draw_signal_pulses()
