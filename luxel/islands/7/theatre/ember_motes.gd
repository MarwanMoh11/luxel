class_name LxTheatreEmberMotes
extends LxToy
## Ambient golden ember-motes drifting under the stage spotlights in Act IV (`theatre_r9`).
## Because Hollow Wick steals Bolt and Beam in Act IV, walking into or interacting with these
## motes charges Wick's Ember bar cleanly so `sunflare` is ALWAYS ready to break the Obsidian Seal!

var charge_radius: float = 22.0
var _pulse_t: float = 0.0
var _cd: float = 0.0


func _toy_setup() -> void:
	kind = "theatre_ember_motes"
	charge_radius = maxf(16.0, float(props.get("charge_radius", 22.0)))
	radius = charge_radius
	_pulse_t = 0.0
	_cd = 0.0
	z_index = -2
	queue_redraw()


func is_floor_toy() -> bool:
	return true


func _charge_wick(announce: bool) -> bool:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return false
	var w: LxWick = Lx.player as LxWick
	var emax: float = w.move_sunflare.get_ember_max() if w.move_sunflare != null else 100.0
	if w.ember >= emax - 0.5 and not announce:
		return false
	w.ember = emax
	_pulse_t = 0.55
	_cd = 0.90
	_emit_sfx("ember_pickup")
	_emit_gust(42.0, 34.0)
	if announce and Lx.events != null and LxStrings.has_id("ISL7_TH_MOTES_FULL"):
		Lx.events.narration_requested.emit("ISL7_TH_MOTES_FULL", "narration", 2.4)
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	return _charge_wick(true)


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL7_TH_PROMPT_MOTES"


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
	var wp: Vector2 = wick_pos()
	if _cd <= 0.0 and wp.x > -9000.0 and wp.distance_to(pos) <= charge_radius:
		_charge_wick(false)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 46.0 if _pulse_t > 0.0 else 36.0, 0.85 if _pulse_t > 0.0 else 0.60)


func _draw() -> void:
	if not active:
		return
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	# Golden stage spotlight disc on floor
	draw_circle(Vector2.ZERO, charge_radius * 0.78, Color(c_gold, 0.18))
	draw_arc(Vector2.ZERO, charge_radius * 0.78, 0.0, TAU, 20, Color(c_gold, 0.55), 1.0)
	# Floating golden ember-motes rising through cone
	for i: int in range(6):
		var a: float = float(i) * (TAU / 6.0) + (0.0 if fr else _clock * 1.4)
		var r: float = 5.0 + float(i % 3) * 4.0
		var rise: float = 0.0 if fr else fmod(_clock * 14.0 + float(i) * 3.7, 14.0)
		var mp := Vector2(roundf(cos(a) * r), roundf(sin(a) * r * 0.55 - rise))
		draw_rect(Rect2(mp - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if i % 2 == 0 else c_apricot)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, charge_radius * 1.2, u)), 0.0, TAU, 18, Color(c_cream, 1.0 - u), 1.5)
	_draw_signal_pulses()
