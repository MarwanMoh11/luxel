class_name LxSpireFakeLamp
extends LxToy
## Island 7 Mirror Spire r15 Counterfeit Bell Isle Fake Great Lamp:
## Masquerades as Island 1's Great Lamp with a reversed NW shadow and eerie chime.
## Interacting, shooting, or pulsing True Lens shatters the painted sunlit sky into
## the obsidian Black Spire (`spire_false_lamp_shattered`), flips world_face -> black,
## and emits its signal so the 2-wave Mirror-Court ambush begins!
## Props: shatter_flag (String, default "spire_false_lamp_shattered"), persist (bool, true), target_id/target_ids.

var shatter_flag: String = "spire_false_lamp_shattered"
var shattered: bool = false
var _burst_t: float = 0.0
var _lens_glint_t: float = 0.0


func _toy_setup() -> void:
	kind = "spire_fake_lamp"
	shatter_flag = str(props.get("shatter_flag", "spire_false_lamp_shattered")).strip_edges()
	if not props.has("persist"):
		persist = true
	radius = 20.0
	size = Vector2(24.0, 24.0)
	shattered = (not shatter_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(shatter_flag, false))) \
		or (Lx.state != null and bool(Lx.state.story_flags.get("spire_false_lamp_broken", false)))
	powered = shattered
	_burst_t = 0.0
	_lens_glint_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and shattered:
		return
	shattered = false
	powered = false
	_burst_t = 0.0
	_lens_glint_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return active and not shattered


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-9.0, -5.0), Vector2(18.0, 12.0)) if is_solid() else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active or shattered:
		return false
	return _shatter_illusion()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return _shatter_illusion()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or shattered or light_radius <= 0.0:
		return
	if source in ["lens", "lens_anchor"]:
		_lens_glint_t = 1.4
		_shatter_illusion()


func _shatter_illusion() -> bool:
	if shattered:
		return false
	shattered = true
	_burst_t = 0.9
	if not shatter_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[shatter_flag] = true
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.set_world_face(LxIsland7Rule.SCOPE_ISLAND, "black", true, pos)
	elif Lx.vars != null:
		Lx.vars.set_var(LxIsland7Rule.SCOPE_ISLAND, "world_face", "black")
		if region != null and region.has_method("apply_layers"):
			region.call("apply_layers", true)
	set_powered(true)
	emit_power(true)
	_emit_sfx("spire_reverse_chime")
	_emit_sfx("glass_shatter")
	_emit_gust(90.0, 64.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.32)
		if LxStrings.has_id("ISL7_LORE_FAKE_DAWN"):
			Lx.events.narration_requested.emit("ISL7_LORE_FAKE_DAWN", "ominous", 3.4)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 6.0, 72.0, 0.45, PAL["rose"] as Color, 2.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _burst_t > 0.0:
		_burst_t = maxf(0.0, _burst_t - dt); dirty = true
	if _lens_glint_t > 0.0:
		_lens_glint_t = maxf(0.0, _lens_glint_t - dt); dirty = true
	if not shattered and not LxHudFx.flash_reduced():
		dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	if not active or shattered:
		return ""
	return "ISL7_SP_PROMPT_FAKE_LAMP" if LxStrings.has_id("ISL7_SP_PROMPT_FAKE_LAMP") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if shattered:
		return Vector4(pos.x, pos.y - 4.0, 56.0 if _burst_t > 0.0 else 28.0, 0.72 if _burst_t > 0.0 else 0.34)
	return Vector4(pos.x, pos.y - 8.0, 68.0, 0.80)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["shattered"] = shattered
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("shattered", false)):
		shattered = true
		powered = true
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_plum: Color = PAL["plum"] as Color

	if shattered:
		# Broken obsidian dais + scattered painted-glass sky shards
		LxToyDraw.draw_bevel_box(self, Rect2(-11.0, -4.0, 22.0, 10.0), c_void, c_night, c_plum, c_void)
		draw_rect(Rect2(-6.0, -2.0, 4.0, 2.0), c_ice)
		draw_rect(Rect2(3.0, -1.0, 4.0, 2.0), c_rose)
		draw_rect(Rect2(-2.0, 2.0, 3.0, 2.0), c_gold)
		if _burst_t > 0.0:
			var u: float = 1.0 - clampf(_burst_t / 0.9, 0.0, 1.0)
			draw_arc(Vector2(0.0, -6.0), roundf(lerpf(8.0, 46.0, u)), 0.0, TAU, 22, Color(c_rose, 1.0 - u), 1.6)
		_draw_signal_pulses()
		return

	# TELLTALE LIE: Fake Great Lamp casts a crisp WRONG-WAY NW shadow!
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 6.0), 11.0, 4.0, "nw_wrong", _lens_glint_t > 0.0)
	# Counterfeit brass-and-sunstone Great Lamp pedestal
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -3.0, 20.0, 9.0), c_night, c_stone, c_gold, c_void)
	draw_rect(Rect2(-5.0, -16.0, 10.0, 14.0), c_void)
	draw_rect(Rect2(-4.0, -15.0, 8.0, 12.0), c_gold)
	draw_rect(Rect2(-3.0, -14.0, 6.0, 9.0), c_apricot)
	var flick: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 6.0) * 1.0)
	draw_rect(Rect2(-2.0, -13.0 + flick, 4.0, 5.0), c_cream)
	# Hairline silver mirror-crack betraying the painted glass
	draw_line(Vector2(-3.0, -14.0), Vector2(2.0, -8.0), c_ice, 1.0)
	_draw_signal_pulses()
