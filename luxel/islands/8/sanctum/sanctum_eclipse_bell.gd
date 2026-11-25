class_name LxSanctumEclipseBell
extends LxToy
## Bell Sanctum r13 Centerpiece: The Great Eclipse Bell Contraption.
## Bound by 3 visible chains synthesizing all 8 moves + Island 8's rule:
##   Chain 1 (blue): shattered via signal from sensor_r13_blue (gravity + rotor + prism)
##   Chain 2 (dais): shattered via signal from plate_r13_dais (beam + hook + lens + wings + portal)
##   Chain 3 (sunflare): shattered by Wick's Sunflare on the central dais once Chains 1 & 2 fall!
## Ringing tolls the Great Eclipse Bell across the cathedral, sets sanctum_bell_rung = true,
## and emits power to door_r13_north.

const RUNG_FLAG: String = "sanctum_bell_rung"

var chain_1_id: String = "sensor_r13_blue"
var chain_2_id: String = "plate_r13_dais"
var chain_1_broken: bool = false
var chain_2_broken: bool = false
var bell_rung: bool = false
var _ring_t: float = 0.0
var _reject_t: float = 0.0


func _toy_setup() -> void:
	kind = "sanctum_eclipse_bell"
	radius = 22.0
	size = Vector2(36.0, 28.0)
	persist = bool(props.get("persist", true))
	chain_1_id = str(props.get("chain_1_id", "sensor_r13_blue")).strip_edges()
	chain_2_id = str(props.get("chain_2_id", "plate_r13_dais")).strip_edges()
	bell_rung = (Lx.state != null and bool(Lx.state.story_flags.get(RUNG_FLAG, false))) or powered
	chain_1_broken = bell_rung
	chain_2_broken = bell_rung
	_ring_t = 0.0
	_reject_t = 0.0
	if bell_rung:
		powered = true
	queue_redraw()


func reset_toy() -> void:
	if persist and bell_rung:
		return
	chain_1_broken = false
	chain_2_broken = false
	bell_rung = false
	_ring_t = 0.0
	_reject_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -6.0), Vector2(14.0, 12.0)) if active else Rect2()


func on_signal(from_id: String, is_on: bool) -> void:
	if not active or not is_on or bell_rung:
		return
	var changed: bool = false
	if from_id == chain_1_id and not chain_1_broken:
		chain_1_broken = true
		changed = true
	elif from_id == chain_2_id and not chain_2_broken:
		chain_2_broken = true
		changed = true
	if changed:
		_emit_sfx("shield_shatter")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.14)
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or bell_rung:
		return false
	if hit.source == LxHit.SOURCE_SUNFLARE:
		return _try_ring_bell()
	if hit.source in [LxHit.SOURCE_BEAM, LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW]:
		_reject_t = 0.35
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or bell_rung or light_radius <= 0.0:
		return
	if source == "sunflare":
		_try_ring_bell()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if bell_rung:
		_ring_t = 0.85
		_emit_sfx("sanctum_bell_toll")
		queue_redraw()
		return true
	_reject_t = 0.35
	_emit_sfx("mirror_ping")
	if Lx.events != null and LxStrings.has_id("ISL8_SC_BELL_HINT"):
		Lx.events.narration_requested.emit("ISL8_SC_BELL_HINT", "narration", 3.0)
	queue_redraw()
	return true


func _try_ring_bell() -> bool:
	if bell_rung:
		return true
	if not (chain_1_broken and chain_2_broken):
		_reject_t = 0.45
		_emit_sfx("mirror_ping")
		if Lx.events != null and LxStrings.has_id("ISL8_SC_BELL_LOCKED"):
			Lx.events.narration_requested.emit("ISL8_SC_BELL_LOCKED", "narration", 2.8)
		queue_redraw()
		return true
	bell_rung = true
	_ring_t = 1.4
	if Lx.state != null:
		Lx.state.story_flags[RUNG_FLAG] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("sanctum_bell_toll")
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.32)
		if LxStrings.has_id("ISL8_SC_BELL_RUNG"):
			Lx.events.narration_requested.emit("ISL8_SC_BELL_RUNG", "title", 3.6)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("sanctum_eclipse_bell")
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _ring_t > 0.0:
		_ring_t = maxf(0.0, _ring_t - dt)
		dirty = true
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		dirty = true
	# Dawn Resonance: once Chains 1 & 2 shatter, the Bell Dais charges Wick's Ember so Sunflare is never softlocked.
	if active and chain_1_broken and chain_2_broken and not bell_rung and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and w.global_position.distance_to(pos) <= 64.0:
			var emax: float = Lx.state.get_effective_ember_max() if Lx.state != null else 100.0
			if w.ember < emax:
				w.ember = minf(emax, w.ember + 220.0 * dt)
				dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL8_SC_PROMPT_BELL" if LxStrings.has_id("ISL8_SC_PROMPT_BELL") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if bell_rung:
		var pulse: float = 18.0 * sin(clampf(_ring_t / 1.4, 0.0, 1.0) * PI) if _ring_t > 0.0 else 0.0
		return Vector4(pos.x, pos.y - 6.0, 96.0 + pulse, 1.30)
	var broken_n: int = int(chain_1_broken) + int(chain_2_broken)
	return Vector4(pos.x, pos.y - 6.0, 34.0 + float(broken_n) * 16.0, 0.45 + float(broken_n) * 0.20)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["c1"] = chain_1_broken
		d["c2"] = chain_2_broken
		d["rung"] = bell_rung
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		chain_1_broken = bool(d.get("c1", chain_1_broken))
		chain_2_broken = bool(d.get("c2", chain_2_broken))
		bell_rung = bool(d.get("rung", bell_rung))
		if bell_rung:
			powered = true
			emit_power(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Shadow & stone drum plinth
	draw_circle(Vector2(0.0, 4.0), 17.0, c_void)
	draw_arc(Vector2(0.0, 2.0), 16.0, 0.0, TAU, 24, c_gold if bell_rung else c_plum, 1.5)
	# Bell dome silhouette (dark bronze -> radiant gold when rung)
	var body_c: Color = c_apricot if bell_rung else c_dusk
	var hi_c: Color = c_cream if bell_rung else c_mauve_safe()
	draw_rect(Rect2(-12.0, -4.0, 24.0, 10.0), body_c)
	draw_rect(Rect2(-10.0, -12.0, 20.0, 9.0), body_c)
	draw_rect(Rect2(-6.0, -16.0, 12.0, 5.0), body_c)
	draw_rect(Rect2(-13.0, 5.0, 26.0, 3.0), c_gold if bell_rung else c_night)
	draw_rect(Rect2(-7.0, -11.0, 3.0, 11.0), hi_c)
	# Clapper jewel
	draw_circle(Vector2(0.0, 7.0), 3.0, c_cream if bell_rung else c_gold)
	# Chain 1 (west blue prism chain)
	if not chain_1_broken:
		draw_line(Vector2(-16.0, -12.0), Vector2(-6.0, -4.0), c_sky, 2.0)
		draw_rect(Rect2(-14.0, -10.0, 4.0, 4.0), c_ice)
	# Chain 2 (east phantom dais chain)
	if not chain_2_broken:
		draw_line(Vector2(16.0, -12.0), Vector2(6.0, -4.0), c_plum, 2.0)
		draw_rect(Rect2(10.0, -10.0, 4.0, 4.0), c_cream)
	# Chain 3 (center Sunflare seal)
	if not bell_rung:
		var ready_c: Color = c_gold if (chain_1_broken and chain_2_broken) else c_coral
		draw_arc(Vector2(0.0, -4.0), 5.0, 0.0, TAU, 12, ready_c, 1.4)
	# Sold-settings golden rim sparks
	var sold_w: int = LxSold.current().get_toll_weight() if LxSold.current() != null else 0
	var pips: int = mini(6, sold_w / 2)
	for i: int in range(pips):
		var a: float = _clock * 0.8 + float(i) * (TAU / maxf(1.0, float(pips)))
		draw_rect(Rect2(roundf(cos(a) * 19.0) - 1.0, roundf(sin(a) * 12.0) - 3.0, 2.0, 2.0), c_gold)
	if _ring_t > 0.0:
		var u: float = 1.0 - clampf(_ring_t / 1.4, 0.0, 1.0)
		draw_arc(Vector2(0.0, -2.0), roundf(lerpf(12.0, 78.0, u)), 0.0, TAU, 28, Color(c_cream, 1.0 - u), 2.0)
	if _reject_t > 0.0:
		draw_arc(Vector2(0.0, -2.0), 18.0, 0.0, TAU, 18, c_coral, 1.4)
	_draw_signal_pulses()


func c_mauve_safe() -> Color:
	return PAL["mauve"] as Color
