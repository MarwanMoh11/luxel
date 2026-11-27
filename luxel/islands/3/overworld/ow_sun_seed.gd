class_name LxOwSunSeed
extends LxToy
## Island 3 Sun-Seed bud for Gardener Frog's quest (`q_isl3_gardener`).
## Awakens when exposed to lantern light, bolt, beam, dew_ray, or E interact;
## blooms into a glowing golden canopy flower, sets `sets_flag` (e.g. `q_gardener_seed_1`),
## persists across save/load, and emits power to linked targets.

var awake: bool = false
var sets_flag_name: String = ""
var _bloom_t: float = 0.0
var _light_hold: float = 0.0


func _toy_setup() -> void:
	kind = "ow_sun_seed"
	size = Vector2(16.0, 16.0)
	radius = 14.0
	if not props.has("persist"):
		persist = true
	sets_flag_name = str(props.get("sets_flag", props.get("flag_id", ""))).strip_edges()
	awake = bool(props.get("awake", false)) or (not sets_flag_name.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag_name, false)))
	powered = awake
	_bloom_t = 0.0
	_light_hold = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and awake:
		return
	awake = false
	powered = false
	_bloom_t = 0.0
	_light_hold = 0.0
	queue_redraw()


func _awaken() -> bool:
	if awake or not active:
		return false
	awake = true
	_bloom_t = 0.55
	set_powered(true)
	emit_power(true)
	if not sets_flag_name.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag_name] = true
	_emit_sfx("seed_bloom")
	_emit_gust(52.0, 38.0)
	if Lx.events != null:
		if LxStrings.has_id("ISL3_SEED_AWAKE"):
			Lx.events.narration_requested.emit("ISL3_SEED_AWAKE", "narration", 2.6)
		if persist:
			Lx.events.save_requested.emit("sun_seed_" + (sets_flag_name if not sets_flag_name.is_empty() else id))
	queue_redraw()
	return true


func interact(_actor: Node = null) -> bool:
	return _awaken()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or awake:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_SUNFLARE, "dew_ray"]:
		return _awaken()
	return false


func on_light(light_radius: float, _source: String) -> void:
	if not active or awake or light_radius <= 0.0:
		return
	_light_hold += 0.08
	if _light_hold >= 0.30:
		_awaken()


func tick(dt: float) -> void:
	super.tick(dt)
	if _bloom_t > 0.0:
		_bloom_t = maxf(0.0, _bloom_t - dt)
		queue_redraw()
	elif not awake and _light_hold > 0.0:
		_light_hold = maxf(0.0, _light_hold - dt * 0.25)


func get_interact_prompt() -> String:
	return "ISL3_PROMPT_SUN_SEED" if (active and not awake) else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if awake:
		return Vector4(pos.x, pos.y - 6.0, 60.0, 0.84 if LxHudFx.flash_reduced() else 0.95)
	return Vector4(pos.x, pos.y - 4.0, 20.0, 0.28)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d["awake"] = awake
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	var by_flag: bool = not sets_flag_name.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag_name, false))
	awake = bool(d.get("awake", awake)) or by_flag
	powered = awake
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 3.0)
	# Leafy calyx base
	draw_rect(Rect2(-6.0, 1.0, 12.0, 4.0), c_void)
	draw_rect(Rect2(-5.0, 2.0, 10.0, 2.0), c_pine)
	draw_rect(Rect2(-4.0, 1.0, 8.0, 2.0), c_jade if awake else c_teal)

	if not awake:
		# Closed dormant bud with vertical recessed seam notch
		draw_rect(Rect2(-4.0, -7.0, 8.0, 9.0), c_void)
		draw_rect(Rect2(-3.0, -6.0, 6.0, 7.0), c_teal)
		draw_rect(Rect2(-2.0, -5.0, 4.0, 5.0), c_jade)
		draw_rect(Rect2(-1.0, -4.0, 2.0, 3.0), c_lime)
		draw_rect(Rect2(0.0, -5.0, 1.0, 4.0), c_void)
		draw_rect(Rect2(0.0, -4.0, 1.0, 2.0), c_gold)
		return

	# Radiant awakened Sun-Seed canopy blossom with 4-point center starburst
	draw_rect(Rect2(-2.0, -3.0, 4.0, 5.0), c_jade)
	draw_rect(Rect2(-7.0, -11.0, 14.0, 10.0), c_void)
	draw_rect(Rect2(-6.0, -10.0, 12.0, 8.0), c_apricot)
	draw_rect(Rect2(-5.0, -9.0, 10.0, 6.0), c_gold)
	draw_rect(Rect2(-2.0, -8.0, 4.0, 4.0), c_cream)
	draw_rect(Rect2(-4.0, -7.0, 8.0, 2.0), c_cream)
	draw_rect(Rect2(-1.0, -10.0, 2.0, 8.0), c_cream)
	# 4 outward petal tips
	for off: Vector2 in [Vector2(-7.0, -7.0), Vector2(6.0, -7.0), Vector2(-1.0, -12.0), Vector2(-1.0, -2.0)]:
		draw_rect(Rect2(off, Vector2(2.0, 2.0)), c_lime)

	if _bloom_t > 0.0:
		var u: float = 1.0 - clampf(_bloom_t / 0.55, 0.0, 1.0)
		var red: bool = LxHudFx.flash_reduced()
		var ring_c: Color = Color(c_gold, 0.55) if red else (c_cream if u < 0.5 else c_gold)
		draw_arc(Vector2(0.0, -6.0), roundf(lerpf(4.0, 20.0, u)), 0.0, TAU, 16, ring_c, 1.0)
	_draw_signal_pulses()
