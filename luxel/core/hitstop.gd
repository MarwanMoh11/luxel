class_name LxHitstop
extends Node
## Hit-stop freeze timer and Assist game-speed scaler.

var _remaining: float = 0.0
var game_speed: float = 1.0


func trigger(duration: float) -> void:
	_remaining = maxf(_remaining, maxf(0.0, duration))


func clear() -> void:
	_remaining = 0.0


func is_frozen() -> bool:
	return _remaining > 0.0


func step(raw_dt: float) -> float:
	if _remaining > 0.0:
		_remaining = maxf(0.0, _remaining - raw_dt)
		return 0.0
	return raw_dt * clampf(game_speed, 0.7, 1.0)
