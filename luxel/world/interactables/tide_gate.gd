class_name LxTideGate
extends LxInteractable
## Cyclic tidal boardwalk: rises and falls on a readable timer, exposing or flooding water tiles.

var period: float = 8.0
var phase_offset: float = 0.0
var low_ratio: float = 0.55
var warn_time: float = 1.2
var size: Vector2 = Vector2(32.0, 32.0)
var is_flooded: bool = false
var is_warning: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "tide_gate"
	period = maxf(2.0, float(props.get("period", 8.0)))
	phase_offset = float(props.get("phase_offset", 0.0))
	low_ratio = clampf(float(props.get("low_ratio", 0.55)), 0.2, 0.85)
	warn_time = maxf(0.2, float(props.get("warn_time", 1.2)))
	size = _parse_size(props.get("size", [32.0, 32.0]), Vector2(32.0, 32.0))
	radius = maxf(size.x, size.y) * 0.5
	_update_phase()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var prev_f: bool = is_flooded
	var prev_w: bool = is_warning
	_update_phase()
	if prev_f != is_flooded or prev_w != is_warning:
		queue_redraw()


func _update_phase() -> void:
	var t: float = fposmod(_clock + phase_offset, period)
	var low_end: float = period * low_ratio
	is_flooded = t >= low_end
	is_warning = (not is_flooded and (low_end - t) <= warn_time) or (is_flooded and (period - t) <= warn_time)


func is_platform_solid() -> bool:
	return active and not is_flooded


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "clock": _clock}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	_clock = float(d.get("clock", _clock))
	_update_phase()
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = size * 0.5
	if is_flooded:
		draw_rect(Rect2(-half, size), PAL["blue"])
		var col: Color = PAL["ice"] if is_warning else PAL["sky"]
		draw_line(Vector2(-half.x + 3.0, -4.0), Vector2(half.x - 3.0, -4.0), col, 1.0)
		draw_line(Vector2(-half.x + 5.0, 4.0), Vector2(half.x - 5.0, 4.0), col, 1.0)
	else:
		draw_rect(Rect2(-half, size), PAL["plum"])
		draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["mauve"])
		if is_warning:
			draw_rect(Rect2(-half, size), PAL["sky"], false, 1.0)
		else:
			draw_rect(Rect2(-half, size), PAL["stone"], false, 1.0)
