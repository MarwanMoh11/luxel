class_name LxPartyKeyPedestal
extends LxToy
## Island 4 Garden Party (party_r5): Golden Clock Key Pedestal & Wordless Banquet Scene.
## Holds `golden_clock_key` beside the balance scale. Requires Toastmaster defeated and the
## linked counterweight scale powered; swapping sets `golden_clock_key`, `party_done`, chimes
## Hour VI (`dusk_hour=6`, `party_phase="escape"`), and opens the High Aqueduct Escape!

var claimed: bool = false
var scale_id: String = ""
var require_flag: String = "boss_toastmaster_defeated"
var _warn_t: float = 0.0
var _ghost_t: float = 0.0


func _toy_setup() -> void:
	kind = "party_key_pedestal"
	radius = 18.0
	size = Vector2(20.0, 20.0)
	scale_id = str(props.get("scale_id", "scale_party_r5")).strip_edges()
	require_flag = str(props.get("require_flag", "boss_toastmaster_defeated")).strip_edges()
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("golden_clock_key", false))
	if claimed:
		powered = true
	_warn_t = 0.0
	_ghost_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	claimed = Lx.state != null and bool(Lx.state.story_flags.get("golden_clock_key", false))
	_warn_t = 0.0
	if claimed != powered:
		set_powered(claimed)
		emit_power(claimed)
	queue_redraw()


func _is_boss_clear() -> bool:
	if require_flag.is_empty():
		return true
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get(require_flag, false)) or Lx.state.defeated_bosses.has("boss_toastmaster")


func _is_scale_ready() -> bool:
	if scale_id.is_empty():
		return true
	if region != null and region.has_method("find_interactable"):
		var found: Variant = region.call("find_interactable", scale_id)
		if found is LxToy:
			return bool((found as LxToy).powered)
	return powered


func get_interact_prompt() -> String:
	if not active or claimed or not _is_boss_clear():
		return ""
	return "ISL4_PT_PROMPT_KEY"


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	if not _is_boss_clear():
		_emit_sfx("denied")
		return false
	if not _is_scale_ready():
		_warn_t = 0.65
		_emit_sfx("denied")
		if Lx.events != null and LxStrings.has_id("ISL4_PT_NEED_WEIGHT"):
			Lx.events.narration_requested.emit("ISL4_PT_NEED_WEIGHT", "narration", 2.8)
		queue_redraw()
		return false
	claimed = true
	if Lx.state != null:
		Lx.state.story_flags["golden_clock_key"] = true
		Lx.state.story_flags["party_done"] = true
		Lx.state.story_flags["dungeon_done:garden_party"] = true
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:garden_party", "party_phase", "escape")
		Lx.vars.set_var("island:4", "dusk_hour", 6)
	if LxIsland4Rule.active_instance != null and is_instance_valid(LxIsland4Rule.active_instance):
		LxIsland4Rule.active_instance.set_hour(6, true, true)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers", true)
	if Lx.events != null and LxStrings.has_id("ISL4_CUE_HEIST_WIN"):
		Lx.events.narration_requested.emit("ISL4_CUE_HEIST_WIN", "title", 3.2)
	_emit_sfx("key_pickup")
	_emit_save("golden_clock_key")
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_ghost_t = fmod(_ghost_t + dt * 1.8, TAU)
	if _warn_t > 0.0:
		_warn_t = maxf(0.0, _warn_t - dt)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 26.0 if claimed else 46.0, 0.40 if claimed else 0.72)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_coral: Color = PAL["coral"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	var scale_ok: bool = _is_scale_ready()
	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 5.0), 10.0, 3.0)
	# Wordless Scene #2: flanking ghost glass teacups gently lifting to an absent banquet
	var cup_bob: float = 0.0 if fred else roundf(sin(_ghost_t) * 2.0)
	for sx: float in [-24.0, 24.0]:
		var cp := Vector2(sx, -6.0 + cup_bob * (1.0 if sx > 0.0 else -1.0))
		draw_rect(Rect2(cp + Vector2(-3.0, -2.0), Vector2(6.0, 4.0)), Color(c_sky, 0.35 if fred else 0.45))
		draw_rect(Rect2(cp + Vector2(-2.0, -1.0), Vector2(4.0, 2.0)), Color(c_ice, 0.58 if fred else 0.78))
		draw_rect(Rect2(cp + Vector2(-1.0, -4.0), Vector2(2.0, 1.0)), Color(c_cream, 0.40 if fred else 0.55))

	# Marble & brass key pedestal
	var warn_hi: bool = _warn_t > 0.0
	var rim_c: Color = (c_coral if not fred else c_dusk) if warn_hi else (c_gold if scale_ok else c_dusk)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -8.0, 16.0, 14.0), c_night, c_dusk, rim_c, c_void)
	if not claimed:
		if scale_ok:
			draw_rect(Rect2(-7.0, -9.0, 2.0, 2.0), c_cream)
			draw_rect(Rect2(5.0, -9.0, 2.0, 2.0), c_cream)
		else:
			# Closed counterweight lock-bar across pedestal front until scale is balanced
			draw_rect(Rect2(-5.0, -3.0, 10.0, 3.0), c_void)
			draw_rect(Rect2(-4.0, -2.0, 8.0, 1.0), c_coral if warn_hi else c_dusk)
		if warn_hi:
			draw_line(Vector2(-4.0, -6.0), Vector2(4.0, 2.0), c_void, 2.0)
			draw_line(Vector2(4.0, -6.0), Vector2(-4.0, 2.0), c_void, 2.0)
			draw_line(Vector2(-4.0, -6.0), Vector2(4.0, 2.0), c_coral, 1.0)
			draw_line(Vector2(4.0, -6.0), Vector2(-4.0, 2.0), c_coral, 1.0)
		var kbob: float = 0.0 if fred else roundf(sin(_ghost_t * 1.5) * 1.5)
		var ky: float = -15.0 + kbob
		draw_circle(Vector2(0.0, ky), 4.0, c_void)
		draw_circle(Vector2(0.0, ky), 3.0, c_gold)
		draw_rect(Rect2(-1.0, ky - 1.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(-2.0, ky + 3.0, 4.0, 7.0), c_void)
		draw_rect(Rect2(-1.0, ky + 3.0, 2.0, 6.0), c_gold)
		draw_rect(Rect2(1.0, ky + 6.0, 2.0, 2.0), c_cream)
	else:
		# Void-backed counterweight silhouette resting on velvet cushion
		draw_rect(Rect2(-5.0, -12.0, 10.0, 6.0), c_void)
		draw_rect(Rect2(-4.0, -11.0, 8.0, 4.0), c_dusk)
		draw_rect(Rect2(-3.0, -10.0, 6.0, 2.0), c_ice)
	_draw_signal_pulses()
