class_name LxLocksOrbitCapacitor
extends LxToy
## Pass-through Blue-Light Orbit Capacitor (locks_r10 Portal Whirlpool):
## Accepts passing blue/prism bolts WITHOUT consuming them so a single recirculating
## blue bolt orbiting through 4 Blue Portals + 2 mirror-rafts keeps twin capacitors
## charged simultaneously! Emits power while charged (or latches once both fire via logic_gate).
## Props: hold_secs (float, default 3.5), requires_blue (bool, default true),
## latch (bool, default false), persist (bool, default false), target_id/target_ids.

var hold_secs: float = 3.5
var requires_blue: bool = true
var latch: bool = false
var charge_left: float = 0.0
var _pulse_t: float = 0.0
var _reject_t: float = 0.0


func _toy_setup() -> void:
	kind = "locks_orbit_capacitor"
	radius = maxf(13.0, float(props.get("radius", 14.0)))
	hold_secs = maxf(0.8, float(props.get("hold_secs", 3.5)))
	requires_blue = bool(props.get("requires_blue", true))
	latch = bool(props.get("latch", false))
	charge_left = hold_secs if powered else 0.0
	_pulse_t = 0.0
	_reject_t = 0.0
	z_index = -1
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	charge_left = 0.0
	_pulse_t = 0.0
	_reject_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	var is_blue_hit: bool = (hit.has_method("is_blue") and hit.is_blue()) or hit.source == LxHit.SOURCE_PRISM
	if requires_blue and not is_blue_hit:
		if hit.source in ["bolt", "beam", "throw", "recall"]:
			_reject_t = 0.35
			_emit_sfx("mirror_ping")
			queue_redraw()
		# Return false so yellow test shots don't mysteriously vanish inside water
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "sunflare"]:
		return false
	charge_left = hold_secs
	_pulse_t = 0.32
	if not powered:
		set_powered(true)
		emit_power(true)
		_emit_sfx("switch_eye")
	else:
		_emit_sfx("prop_chime")
	queue_redraw()
	# CRITICAL: return false so the orbiting blue bolt passes straight through!
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		dirty = true
	if powered and not latch:
		charge_left = maxf(0.0, charge_left - dt)
		dirty = true
		if charge_left <= 0.0:
			set_powered(false)
			emit_power(false)
	if dirty or powered:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if powered:
		var surge: float = 16.0 * clampf(_pulse_t / 0.32, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 44.0 + surge, 0.88)
	return Vector4(pos.x, pos.y, 20.0, 0.25)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["powered"] = powered
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("powered", false)):
		powered = true
		charge_left = hold_secs
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var red: bool = LxHudFx.flash_reduced()
	var frac: float = clampf(charge_left / maxf(0.01, hold_secs), 0.0, 1.0) if powered else 0.0
	# Floating brass buoy ring with sea-glass capacitor core
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, c_void, 3.0)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, PAL["ice"] as Color if powered else (PAL["coral"] as Color if _reject_t > 0.0 else PAL["deep"] as Color), 1.5)
	# Outer charge arc
	if powered and frac > 0.01:
		draw_arc(Vector2.ZERO, 13.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, PAL["cream"] as Color if _pulse_t > 0.0 else PAL["sky"] as Color, 1.5)
	# Corner brass coil insulators (greyscale-distinct silhouette)
	for off: Vector2 in [Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Vector2(0.0, -9.0), Vector2(0.0, 9.0)]:
		draw_rect(Rect2(off - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
		draw_rect(Rect2(off - Vector2.ONE, Vector2(2.0, 2.0)), PAL["gold"] as Color if powered else PAL["stone"] as Color)
	# Central sea-glass diamond coil
	var core_r: float = 5.0 + (0.0 if (red or not powered) else roundf(sin(_clock * 6.0) * 0.8))
	var pts := PackedVector2Array([
		Vector2(0.0, -core_r), Vector2(core_r, 0.0), Vector2(0.0, core_r), Vector2(-core_r, 0.0),
	])
	draw_colored_polygon(pts, PAL["ice"] as Color if powered else PAL["night"] as Color)
	var closed := PackedVector2Array(pts); closed.append(pts[0])
	draw_polyline(closed, PAL["cream"] as Color if powered else PAL["blue"] as Color, 1.0)
	if powered:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.32, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 19.0, u)), 0.0, TAU, 16, PAL["cream"] as Color, 1.2)
	_draw_signal_pulses()
