class_name LxLevHeartbeatDriver
extends LxToy
## Leviathan 8s Whale-Heartbeat Tide Controller (`lev_heartbeat_driver`, `leviathan_r3`):
## Displays a rhythmic organic rib-gauge pulsing on the whale's 8-second breath cycle.
## When `auto_cycle` is true, shifts `room:2:leviathan_r3` `belly_tide` (`low`/`high`)
## every `period_s` seconds, pausing cleanly for `manual_hold_s` whenever a rib-valve
## `state_lever` is manually switched (keeping puzzles fair and bot-deterministic!).

var var_scope: String = "room:2:leviathan_r3"
var var_name: String = "belly_tide"
var period_s: float = 8.0
var manual_hold_s: float = 16.0
var auto_cycle: bool = false
var _beat_t: float = 0.0
var _hold_t: float = 0.0
var _last_val: String = "low"


func _toy_setup() -> void:
	kind = "lev_heartbeat_driver"
	z_index = -3
	radius = 12.0
	var_scope = str(props.get("scope", "room:2:leviathan_r3")).strip_edges()
	var_name = str(props.get("var", "belly_tide")).strip_edges()
	period_s = maxf(3.0, float(props.get("period_s", 8.0)))
	manual_hold_s = maxf(4.0, float(props.get("manual_hold_s", 16.0)))
	auto_cycle = bool(props.get("auto_cycle", false))
	_beat_t = 0.0
	_hold_t = 0.0
	_last_val = _read_tide()
	queue_redraw()


func reset_toy() -> void:
	_beat_t = 0.0
	_hold_t = 0.0
	_last_val = _read_tide()
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func _read_tide() -> String:
	var v: String = str(LxToyDraw.world_get_var(var_scope, var_name, "low")).strip_edges().to_lower()
	return "high" if v == "high" else "low"


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var cur: String = _read_tide()
	if cur != _last_val:
		_last_val = cur
		_hold_t = manual_hold_s
		_beat_t = 0.0
		_emit_sfx("whale_groan_low")
	if _hold_t > 0.0:
		_hold_t = maxf(0.0, _hold_t - dt)
	_beat_t += dt
	if _beat_t >= period_s:
		_beat_t = 0.0
		if auto_cycle and _hold_t <= 0.0:
			var nxt: String = "high" if _last_val == "low" else "low"
			_last_val = nxt
			LxToyDraw.world_set_var(var_scope, var_name, nxt)
			if region != null and region.has_method("apply_layers"):
				region.call("apply_layers")
			_emit_sfx("whale_groan_low")
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var high: bool = _last_val == "high"
	return Vector4(pos.x, pos.y, 42.0 if high else 28.0, 0.72 if high else 0.45)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var high: bool = _last_val == "high"
	var pulse: float = 0.5 + 0.5 * sin(_clock * TAU / 4.0)
	var col_core: Color = (PAL["gold"] if high else PAL["rose"]) as Color
	LxPhysDraw.draw_bevel_box(self, Rect2(-10.0, -8.0, 20.0, 16.0), PAL["night"] as Color, col_core, PAL["plum"] as Color, c_void)
	var r: float = 3.0 + roundf(pulse * 2.0)
	draw_circle(Vector2.ZERO, r, col_core)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
	# Organic whale-breath pulse wave radiating across the rib-cage chamber
	if not LxHudFx.flash_reduced():
		var bu: float = fmod(_clock / maxf(2.0, period_s * 0.5), 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(8.0, 44.0, bu)), 0.0, TAU, 20, Color(col_core, (1.0 - bu) * 0.45), 1.0)
	# Tide indicator pips (1 = low exhale, 2 = high inhale)
	draw_rect(Rect2(-5.0, 5.0, 3.0, 2.0), PAL["ice"] as Color)
	draw_rect(Rect2(2.0, 5.0, 3.0, 2.0), PAL["cream"] as Color if high else PAL["dusk"] as Color)
