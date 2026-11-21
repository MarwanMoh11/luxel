class_name LxSwitchEye
extends LxInteractable
## Eye switch activated by bolt, prism_bolt, beam, or lantern throw to open linked doors/bridges.

var activated: bool = false
var requires_prism: bool = false
var reset_time: float = 0.0
var _reset_left: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "switch_eye"
	requires_prism = bool(props.get("requires_prism", false))
	reset_time = maxf(0.0, float(props.get("reset_time", 0.0)))
	activated = bool(props.get("activated", false))
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if activated and reset_time > 0.0:
		_reset_left -= dt
		if _reset_left <= 0.0:
			activated = false
			_notify_linked_targets(false)
			queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if requires_prism and hit.source != "prism_bolt":
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return false
	var was_active: bool = activated
	activated = true
	if reset_time > 0.0:
		_reset_left = reset_time
	if not was_active:
		_emit_sfx("switch_eye")
		_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not activated:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 42.0, 0.9)


func save_state() -> Dictionary:
	return {"active": active, "activated": activated}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	activated = bool(d.get("activated", activated))
	if activated:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, PAL["night"])
	draw_circle(Vector2.ZERO, 6.0, PAL["dusk"])
	if activated:
		draw_circle(Vector2.ZERO, 4.0, PAL["gold"])
		draw_circle(Vector2.ZERO, 2.0, PAL["cream"])
	else:
		var iris: Color = PAL["sky"] if requires_prism else PAL["coral"]
		draw_circle(Vector2.ZERO, 3.5, iris)
		draw_circle(Vector2.ZERO, 1.5, PAL["night"])
