class_name LxCourtVerdictBrazier
extends LxToy
## Briar Court mutual-exclusion Verdict Brazier (`court_r2` -> `court_v1`, `court_r3` -> `court_v2`).
## Lighting either the Mercy or Fire brazier sets `island:3.<var_name>` to `"mercy"` or `"fire"`,
## locks out the sibling brazier (anti-exploit #9), emits narration, sets `<var_name>_chosen`,
## and emits power to open the courtroom verdict gate!
## Props: var_name ("court_v1"|"court_v2"), verdict ("mercy"|"fire"), sibling_id (String),
## requires_flag (String), persist (bool, true), target_id/target_ids.

var var_name: String = "court_v1"
var verdict: String = "mercy"
var sibling_id: String = ""
var requires_flag: String = ""

var lit: bool = false
var locked_out: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "court_verdict_brazier"
	var_name = str(props.get("var_name", "court_v1")).strip_edges()
	if var_name not in ["court_v1", "court_v2"]:
		var_name = "court_v1"
	verdict = str(props.get("verdict", "mercy")).strip_edges().to_lower()
	if verdict not in ["mercy", "fire"]:
		verdict = "mercy"
	sibling_id = str(props.get("sibling_id", "")).strip_edges()
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	radius = maxf(14.0, radius)
	lit = false
	locked_out = false
	_pulse_t = 0.0
	_sync_from_world_var()
	queue_redraw()


func reset_toy() -> void:
	if persist and (lit or locked_out):
		return
	lit = false
	locked_out = false
	_pulse_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func _sync_from_world_var() -> void:
	var cur: String = str(LxToyDraw.world_get_var("island:3", var_name, "none")).strip_edges().to_lower()
	var chosen: bool = LxRegionLoader.check_flag_static(var_name + "_chosen")
	if chosen and cur in ["mercy", "fire"]:
		lit = (cur == verdict)
		locked_out = (cur != verdict)
		powered = lit


func _can_choose() -> bool:
	if not active or lit or locked_out:
		return false
	if not requires_flag.is_empty() and not LxRegionLoader.check_flag_static(requires_flag):
		return false
	return true


func choose_verdict() -> bool:
	if not _can_choose():
		if active and not lit:
			_emit_sfx("denied")
		return false
	lit = true
	locked_out = false
	_pulse_t = 0.50
	LxToyDraw.world_set_var("island:3", var_name, verdict)
	if Lx.state != null:
		Lx.state.story_flags[var_name + "_chosen"] = true
	# Lock out sibling brazier immediately (mutual exclusion)
	if not sibling_id.is_empty() and region != null and region.has_method("find_interactable"):
		var sib: Variant = region.call("find_interactable", sibling_id)
		if sib is LxCourtVerdictBrazier:
			(sib as LxCourtVerdictBrazier).lock_out()
	set_powered(true)
	emit_power(true)
	_emit_sfx("ba_seed_verdict" if verdict == "mercy" else "ba_court_gavel")
	_emit_gust(56.0, 42.0)
	if Lx.events != null:
		var sk: String = "ISL3_VERDICT_MERCY" if verdict == "mercy" else "ISL3_VERDICT_FIRE"
		if LxStrings.has_id(sk):
			Lx.events.narration_requested.emit(sk, "narration", 3.4)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var col: Color = (PAL["lime"] if verdict == "mercy" else PAL["coral"]) as Color
		(Lx.player as LxWick).spawn_ring(pos, 5.0, 26.0, 0.36, col, 1.8)
	queue_redraw()
	return true


func lock_out() -> void:
	if lit:
		return
	locked_out = true
	set_powered(false)
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	return choose_verdict()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_SUNFLARE]:
		return choose_verdict()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not _can_choose():
		return ""
	return "ISL3_PROMPT_MERCY" if verdict == "mercy" else "ISL3_PROMPT_FIRE"


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(7.0, 5.0), Vector2(14.0, 10.0)) if active else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if lit:
		return Vector4(pos.x, pos.y - 4.0, 62.0 if _pulse_t > 0.0 else 48.0, 0.88 if _pulse_t > 0.0 else 0.68)
	if _can_choose():
		return Vector4(pos.x, pos.y - 2.0, 24.0, 0.28)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["lit"] = lit
		d["locked_out"] = locked_out
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("lit"):
			lit = bool(d["lit"])
		if d.has("locked_out"):
			locked_out = bool(d["locked_out"])
		powered = lit
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var is_mercy: bool = verdict == "mercy"
	var ready: bool = _can_choose()

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 3.0)
	# Brass courtroom verdict basin
	var rim_c: Color = c_dusk if locked_out else (c_lime if is_mercy else c_coral)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -4.0, 16.0, 10.0), c_night, c_dusk if locked_out else (c_pine if is_mercy else c_wine), rim_c if (lit or ready) else c_stone, c_void)

	# Distinct greyscale shape glyph below basin: leaf-diamond (Mercy) vs flame-chevron (Fire)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, 2.0), 1 if is_mercy else 0, lit, rim_c, c_cream if lit else c_gold)

	if locked_out:
		# Ash cap sealing the unchosen brazier
		draw_rect(Rect2(-6.0, -5.0, 12.0, 3.0), c_dusk)
		return

	if lit:
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 9.0))
		var outer: Color = c_jade if is_mercy else c_coral
		var mid: Color = c_lime if is_mercy else c_apricot
		draw_rect(Rect2(-5.0, -11.0 + bob, 10.0, 7.0), outer)
		draw_rect(Rect2(-3.0, -13.0 + bob, 6.0, 8.0), mid)
		draw_rect(Rect2(-2.0, -10.0 + bob, 4.0, 4.0), c_gold)
		draw_rect(Rect2(-1.0, -9.0 + bob, 2.0, 2.0), c_cream)
		if _pulse_t > 0.0 and not LxHudFx.flash_reduced():
			var u: float = 1.0 - clampf(_pulse_t / 0.50, 0.0, 1.0)
			draw_arc(Vector2(0.0, -6.0), roundf(lerpf(8.0, 20.0, u)), 0.0, TAU, 16, c_cream, 1.0)
	elif ready:
		# Inviting ember seed waiting for verdict
		draw_rect(Rect2(-3.0, -7.0, 6.0, 3.0), c_jade if is_mercy else c_coral)
		draw_rect(Rect2(-1.0, -8.0, 2.0, 2.0), c_gold)
	_draw_signal_pulses()
