class_name LxHitstop
extends Node
## Hit-stop freeze timer and Assist game-speed scaler.

var _remaining: float = 0.0
var _slow_t: float = 0.0
var _slow_dur: float = 0.0
var _slow_scale: float = 1.0
var game_speed: float = 1.0


func trigger(duration: float) -> void:
	_remaining = maxf(_remaining, maxf(0.0, duration))


func trigger_slowmo(time_scale: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var sc: float = clampf(time_scale, 0.15, 1.0)
	if _slow_t <= 0.0 or sc < _slow_scale:
		_slow_scale = sc
	_slow_t = maxf(_slow_t, duration)
	_slow_dur = maxf(_slow_dur, _slow_t)


func clear() -> void:
	_remaining = 0.0
	_slow_t = 0.0
	_slow_dur = 0.0
	_slow_scale = 1.0


func is_frozen() -> bool:
	return _remaining > 0.0


func step(raw_dt: float) -> float:
	if _remaining > 0.0:
		_remaining = maxf(0.0, _remaining - raw_dt)
		return 0.0
	var scale: float = clampf(game_speed, 0.7, 1.0)
	if _slow_t > 0.0:
		var u: float = 1.0 - clampf(_slow_t / maxf(0.01, _slow_dur), 0.0, 1.0)
		scale *= lerpf(_slow_scale, 1.0, u * u)
		_slow_t = maxf(0.0, _slow_t - raw_dt)
	return raw_dt * scale
