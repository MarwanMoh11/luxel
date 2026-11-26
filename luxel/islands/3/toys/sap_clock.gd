class_name LxSapClock
extends LxToy
## Island 3 Sap Clock / Sap Valve / Growth-Ring Floor Dial (`oak_sap`: "low" <-> "high").
## Modes:
## - "valve" (default): toggling via interact (E) or bolt/beam flips `oak_sap` between "low" and "high",
##   floating rafts/bridges, lubricating rotors, and waking sap-powered `stump_shrink` portals.
## - "timed": activating floods `oak_sap = "high"` for `secs` seconds with visible amber countdown ring,
##   1.0 s drain telegraph, then drains back to "low".
## - "cycle": automatically oscillates "low" <-> "high" every `secs` seconds (with 1.0 s telegraph);
##   Blue light (`hit.is_blue()`) frost-pins the clock at its current level for `freeze_secs` (8 s)!
## - "dial": read-only floor dial displaying live `oak_sap` state (e.g. `oak_r1` Heartwood Hub).
## Props: mode ("valve"|"timed"|"cycle"|"dial"), scope ("dungeon:hollow_oak"), var ("oak_sap"),
## secs (float, 8.0), freeze_secs (float, 8.0), shootable (bool, true), persist (bool), target_id/target_ids.

const TELEGRAPH_SECS: float = 1.0

var mode: String = "valve"
var var_scope: String = "dungeon:hollow_oak"
var var_name: String = "oak_sap"
var secs: float = 8.0
var freeze_secs: float = 8.0
var shootable: bool = true

var timer_left: float = 0.0
var frozen_t: float = 0.0
var _timed_running: bool = false
var _cd: float = 0.0
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "sap_clock"
	mode = str(props.get("mode", "valve")).strip_edges().to_lower()
	if mode not in ["valve", "timed", "cycle", "dial"]:
		mode = "valve"
	var_scope = str(props.get("scope", "dungeon:hollow_oak")).strip_edges()
	if var_scope.is_empty():
		var_scope = "dungeon:hollow_oak"
	var_name = str(props.get("var", "oak_sap")).strip_edges()
	if var_name.is_empty():
		var_name = "oak_sap"
	secs = maxf(1.0, float(props.get("secs", 8.0)))
	freeze_secs = maxf(1.0, float(props.get("freeze_secs", 8.0)))
	shootable = bool(props.get("shootable", true))
	radius = maxf(13.0, radius)
	z_index = -5 if mode == "dial" else 0
	timer_left = secs if mode == "cycle" else 0.0
	frozen_t = 0.0
	_timed_running = false
	_cd = 0.0
	_pulse_t = 0.0
	powered = is_sap_high()
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	frozen_t = 0.0
	_timed_running = false
	timer_left = secs if mode == "cycle" else 0.0
	if mode == "timed" and is_sap_high():
		_set_sap("low", false)
	queue_redraw()


func is_sap_high() -> bool:
	return str(LxToyDraw.world_get_var(var_scope, var_name, "low")).strip_edges().to_lower() == "high"


func is_frozen() -> bool:
	return frozen_t > 0.0


func is_telegraphing() -> bool:
	return (mode == "cycle" or (mode == "timed" and is_sap_high())) and not is_frozen() and timer_left > 0.0 and timer_left <= TELEGRAPH_SECS


func _set_sap(level: String, with_fx: bool = true) -> void:
	var norm: String = "high" if level == "high" else "low"
	LxToyDraw.world_set_var(var_scope, var_name, norm)
	var hi: bool = norm == "high"
	set_powered(hi)
	emit_power(hi)
	_pulse_t = 0.34
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")
	if with_fx:
		_emit_sfx("sap_clock_tick")
		_emit_gust(48.0, 34.0)
	queue_redraw()


func trigger_valve() -> bool:
	if not active or mode == "dial" or _cd > 0.0:
		return false
	_cd = 0.25
	match mode:
		"valve":
			_set_sap("low" if is_sap_high() else "high", true)
			return true
		"timed":
			timer_left = secs
			_timed_running = true
			_set_sap("high", true)
			return true
		"cycle":
			timer_left = secs
			_set_sap("low" if is_sap_high() else "high", true)
			return true
	return false


func interact(_actor: Node = null) -> bool:
	return trigger_valve()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or mode == "dial":
		return false
	if hit.is_blue() and mode in ["timed", "cycle"]:
		frozen_t = freeze_secs
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	if shootable and hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxDewLens.SOURCE_DEW_RAY]:
		return trigger_valve()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		dirty = true
	else:
		if mode == "timed" and _timed_running:
			timer_left = maxf(0.0, timer_left - dt)
			dirty = true
			if timer_left <= 0.0:
				_timed_running = false
				_set_sap("low", true)
		elif mode == "cycle":
			timer_left = maxf(0.0, timer_left - dt)
			dirty = true
			if timer_left <= 0.0:
				timer_left = secs
				_set_sap("low" if is_sap_high() else "high", true)
	var hi_now: bool = is_sap_high()
	if hi_now != powered:
		set_powered(hi_now)
		emit_power(hi_now)
		dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	if not active or mode == "dial":
		return ""
	return "PROMPT_SAP_VALVE"


func is_solid() -> bool:
	return active and mode != "dial"


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(7.0, 5.0), Vector2(14.0, 10.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if is_sap_high():
		return Vector4(pos.x, pos.y - 4.0, 42.0 if _pulse_t > 0.0 else 30.0, 0.72 if _pulse_t > 0.0 else 0.48)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["sap"] = "high" if is_sap_high() else "low"
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("sap"):
		_set_sap(str(d["sap"]), false)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var hi: bool = is_sap_high()
	var frz: bool = is_frozen()
	var tel: bool = is_telegraphing()

	if mode == "dial":
		# Flat Heartwood growth-ring floor dial
		draw_circle(Vector2.ZERO, 12.0, c_void)
		draw_circle(Vector2.ZERO, 11.0, c_night)
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, c_apricot if hi else c_dusk, 1.5)
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, c_gold if hi else c_jade, 1.0)
		draw_circle(Vector2.ZERO, 3.0, c_cream if hi else c_dusk)
		return

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 9.0, 3.0)
	# Stepped carved-wood & brass base plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, 3.0, 16.0, 5.0), c_night, c_wine, c_apricot, c_void)
	# Glass amber sap reservoir tube framed by twin vertical brass struts
	draw_rect(Rect2(-7.0, -10.0, 14.0, 14.0), c_void)
	draw_rect(Rect2(-6.0, -9.0, 12.0, 12.0), PAL["deep"] as Color if frz else c_night)
	# Brass frame side pillars + riveted top collar
	draw_rect(Rect2(-7.0, -9.0, 2.0, 12.0), c_apricot if hi else c_wine)
	draw_rect(Rect2(5.0, -9.0, 2.0, 12.0), c_wine)
	draw_rect(Rect2(-7.0, -9.0, 1.0, 11.0), c_gold)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -11.0, 16.0, 4.0), c_wine, c_apricot, c_ice if frz else c_gold, c_void)

	# Inner glowing amber sap fluid column (rises high or sits low — unmistakable in greyscale!)
	var fill_h: float = 10.0 if hi else 3.0
	if mode == "timed" and hi:
		fill_h = maxf(2.0, roundf(10.0 * clampf(timer_left / secs, 0.0, 1.0)))
	var sap_col: Color = c_ice if frz else (c_coral if (tel and not LxHudFx.flash_reduced()) else (c_apricot if hi else c_jade))
	var sap_hi: Color = c_cream if (frz or hi) else c_gold
	draw_rect(Rect2(-4.0, 3.0 - fill_h, 8.0, fill_h), sap_col)
	draw_rect(Rect2(-3.0, 3.0 - fill_h, 6.0, maxf(1.0, fill_h - 1.0)), c_gold if (hi and not frz) else sap_col)
	draw_rect(Rect2(-4.0, 3.0 - fill_h, 8.0, 1.0), sap_hi)
	# Vertical glass reflection streak + tiny rising amber bubble when high
	draw_rect(Rect2(-3.0, -7.0, 1.0, 9.0), c_cream if hi else c_sky)
	if hi and not frz:
		var bub_y: float = -2.0 if LxHudFx.flash_reduced() else roundf(-6.0 + fposmod(-_clock * 6.0, maxf(2.0, fill_h - 2.0)))
		draw_rect(Rect2(1.0, clampf(bub_y, 3.0 - fill_h + 1.0, 1.0), 2.0, 1.0), c_cream)

	# Ornate spoked brass valve wheel atop stem
	draw_rect(Rect2(-2.0, -14.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, -13.0, 2.0, 3.0), c_gold)
	draw_rect(Rect2(-6.0, -15.0, 12.0, 3.0), c_void)
	draw_rect(Rect2(-5.0, -14.0, 10.0, 2.0), c_apricot)
	draw_rect(Rect2(-5.0, -14.0, 8.0, 1.0), c_cream if hi else c_gold)
	draw_rect(Rect2(-6.0, -14.0, 1.0, 2.0), c_gold)
	draw_rect(Rect2(5.0, -14.0, 1.0, 2.0), c_wine)

	if frz:
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, clampf(frozen_t / freeze_secs, 0.0, 1.0), c_ice, c_sky)
	elif mode == "cycle" or (mode == "timed" and hi):
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, clampf(timer_left / secs, 0.0, 1.0), c_gold, c_coral)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.34, 0.0, 1.0)
		draw_arc(Vector2(0.0, -2.0), roundf(lerpf(6.0, 15.0, u)), 0.0, TAU, 16, c_cream if hi else c_jade, 1.0)
	_draw_signal_pulses()
