class_name LxMsRoofedBrazier
extends LxToy
## Stone-canopied Rain Mausoleum brazier (mausoleum_r2):
## Sheltered beneath a carved gothic slate roof so RAIN never snuffs its flame,
## contrasting directly with exposed timed_braziers that hiss out when RAIN begins.
## Props: secs (float, default 0.0 = stays lit), allow_interact (bool, default true),
## persist (bool), target_id/target_ids, sets_flag.

var secs: float = 0.0
var lit: bool = false
var time_left: float = 0.0
var _ignite_t: float = 0.0
var _rain_glint_t: float = 0.0
var _flicker_frame: int = 0


func _toy_setup() -> void:
	kind = "ms_roofed_brazier"
	secs = maxf(0.0, float(props.get("secs", 0.0)))
	lit = bool(props.get("lit", powered))
	time_left = secs if lit else 0.0
	powered = lit
	radius = maxf(13.0, radius)
	_ignite_t = 0.0
	_rain_glint_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and lit:
		return
	if lit:
		lit = false
		time_left = 0.0
		set_powered(false)
		_notify_linked_targets(false)
		queue_redraw()


func on_weather_changed(new_weather: String, _wind_dir: Vector2) -> void:
	if new_weather == "rain" and lit:
		# Rain bounces cleanly off the carved stone canopy while the flame stays warmly lit!
		_rain_glint_t = 1.2
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		dirty = true
	if _rain_glint_t > 0.0:
		_rain_glint_t = maxf(0.0, _rain_glint_t - dt)
		dirty = true
	if lit and secs > 0.0:
		time_left -= dt
		dirty = true
		if time_left <= 0.0:
			lit = false
			time_left = 0.0
			set_powered(false)
			_notify_linked_targets(false)
			_emit_sfx("snuffer_snuff")
	if lit:
		var rate: float = 4.0 if LxHudFx.flash_reduced() else 9.0
		var fr: int = int(floorf(_clock * rate + absf(pos.x * 0.05))) % 4
		if fr != _flicker_frame:
			_flicker_frame = fr
			dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return _ignite()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	if source in ["thrown_lantern", "lantern_hung", "lantern_fly", "lantern_recall", "beam", "sunflare"]:
		_ignite()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if bool(props.get("allow_interact", true)):
		return _ignite()
	return false


func get_interact_prompt() -> String:
	if not active or lit:
		return ""
	return "PROMPT_IGNITE" if bool(props.get("allow_interact", true)) else ""


func _ignite() -> bool:
	var was_lit: bool = lit
	lit = true
	time_left = secs
	_ignite_t = 0.34
	if not was_lit:
		set_powered(true)
		_notify_linked_targets(true)
		var sf: String = str(props.get("sets_flag", "")).strip_edges()
		if not sf.is_empty() and Lx.state != null:
			Lx.state.story_flags[sf] = true
		_emit_sfx("brazier_lit")
		_emit_gust(54.0, 38.0, Vector2(0.0, -8.0))
	else:
		_emit_sfx("lamp_lit")
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if not lit:
		return Vector4(pos.x, pos.y - 6.0, 22.0, 0.25)
	return Vector4(pos.x, pos.y - 8.0, 62.0, 1.05)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["lit"] = lit
		d["time_left"] = time_left
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("lit"):
		lit = bool(d["lit"])
		time_left = float(d.get("time_left", secs if lit else 0.0))
		powered = lit
		if lit:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 10.0, 3.0)
	# Twin carved stone canopy pillars behind the brazier bowl
	draw_rect(Rect2(-11.0, -16.0, 3.0, 22.0), c_void)
	draw_rect(Rect2(-10.0, -15.0, 2.0, 20.0), c_dusk)
	draw_rect(Rect2(-10.0, -15.0, 1.0, 18.0), c_stone)
	draw_rect(Rect2(8.0, -16.0, 3.0, 22.0), c_void)
	draw_rect(Rect2(8.0, -15.0, 2.0, 20.0), c_dusk)
	draw_rect(Rect2(8.0, -15.0, 1.0, 18.0), c_stone)

	# Brazier pedestal & iron bowl
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, 0.0, 12.0, 6.0), c_night, c_dusk, PAL["mauve"] as Color, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -5.0, 14.0, 5.0), PAL["deep"] as Color, PAL["teal"] as Color, c_stone, c_void)

	# Warm sheltered flame inside the stone arch
	if lit:
		var sway: float = 0.0 if LxHudFx.flash_reduced() else (1.0 if _flicker_frame % 2 == 0 else -1.0)
		draw_rect(Rect2(-4.0, -12.0, 8.0, 7.0), c_apricot)
		draw_rect(Rect2(-2.0 + sway * 0.5, -13.0, 4.0, 7.0), c_gold)
		draw_rect(Rect2(-1.0 + sway, -14.0, 2.0, 3.0), c_cream)
	else:
		draw_rect(Rect2(-4.0, -6.0, 8.0, 2.0), c_night)
		draw_rect(Rect2(-2.0, -6.0, 4.0, 1.0), PAL["plum"] as Color)

	# Carved gothic pitched slate roof canopy (unmistakable visual rain shelter!)
	draw_rect(Rect2(-13.0, -19.0, 26.0, 4.0), c_void)
	draw_rect(Rect2(-12.0, -18.0, 24.0, 2.0), c_dusk)
	draw_rect(Rect2(-10.0, -21.0, 20.0, 3.0), c_void)
	draw_rect(Rect2(-9.0, -20.0, 18.0, 2.0), c_stone)
	draw_rect(Rect2(-5.0, -23.0, 10.0, 3.0), c_void)
	draw_rect(Rect2(-4.0, -22.0, 8.0, 2.0), c_ice if _rain_glint_t > 0.0 else c_stone)
	draw_rect(Rect2(-1.0, -24.0, 2.0, 2.0), c_gold if lit else c_stone)

	# Rain deflection droplets off the stone canopy when RAIN hits while lit
	if _rain_glint_t > 0.0:
		draw_rect(Rect2(-13.0, -16.0, 1.0, 2.0), c_sky)
		draw_rect(Rect2(12.0, -16.0, 1.0, 2.0), c_sky)
		draw_rect(Rect2(-7.0, -23.0, 2.0, 1.0), c_ice)
		draw_rect(Rect2(5.0, -23.0, 2.0, 1.0), c_ice)

	if _ignite_t > 0.0:
		var u: float = 1.0 - clampf(_ignite_t / 0.34, 0.0, 1.0)
		draw_arc(Vector2(0.0, -9.0), roundf(lerpf(4.0, 14.0, u)), 0.0, TAU, 14, c_cream if u < 0.4 else c_gold, 1.0)
	_draw_signal_pulses()
