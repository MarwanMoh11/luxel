class_name LxSwitchEye
extends LxInteractable
## Eye switch activated by bolt, prism_bolt, beam, or lantern throw to open linked doors/bridges.

var activated: bool = false
var requires_prism: bool = false
var reset_time: float = 0.0
var _reset_left: float = 0.0
var _pulse_stage: int = 0
var _reject_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "switch_eye"
	requires_prism = bool(props.get("requires_prism", false))
	reset_time = maxf(0.0, float(props.get("reset_time", 0.0)))
	activated = bool(props.get("activated", false))
	_reject_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var changed: bool = false
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		changed = true
	if activated and reset_time > 0.0:
		_reset_left -= dt
		changed = true
		if _reset_left <= 0.0:
			activated = false
			_notify_linked_targets(false)
	if active:
		var rate: float = 3.0 if activated else 1.8
		var st: int = int(floorf(_clock * rate + absf(pos.x * 0.03))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			changed = true
	if changed:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if requires_prism and hit.source != "prism_bolt":
		if hit.source in ["bolt", "beam", "throw", "recall"]:
			_reject_t = 0.24
			_emit_sfx("mirror_ping")
			queue_redraw()
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
	draw_rect(Rect2(-7.0, 5.0, 14.0, 3.0), PAL["void"])
	draw_rect(Rect2(-6.0, 2.0, 12.0, 5.0), PAL["night"])
	draw_rect(Rect2(-5.0, 3.0, 10.0, 3.0), PAL["dusk"])
	draw_rect(Rect2(-5.0, 3.0, 10.0, 1.0), PAL["stone"])
	draw_rect(Rect2(-4.0, -7.0, 8.0, 11.0), PAL["night"])
	draw_rect(Rect2(-3.0, -6.0, 6.0, 9.0), PAL["dusk"])
	draw_rect(Rect2(-3.0, -6.0, 2.0, 8.0), PAL["mauve"])
	draw_rect(Rect2(-3.0, -6.0, 5.0, 1.0), PAL["stone"])
	draw_rect(Rect2(-8.0, -4.0, 16.0, 7.0), PAL["void"])
	draw_rect(Rect2(-7.0, -5.0, 14.0, 9.0), PAL["void"])
	draw_rect(Rect2(-6.0, -4.0, 12.0, 7.0), PAL["apricot"])
	draw_rect(Rect2(-7.0, -2.0, 14.0, 3.0), PAL["apricot"])
	draw_rect(Rect2(-5.0, -4.0, 10.0, 1.0), PAL["gold"])
	draw_rect(Rect2(-6.0, -3.0, 1.0, 3.0), PAL["gold"])
	draw_rect(Rect2(-5.0, 2.0, 10.0, 1.0), PAL["wine"])
	draw_rect(Rect2(-7.0, -1.0, 1.0, 1.0), PAL["gold"])
	draw_rect(Rect2(6.0, -1.0, 1.0, 1.0), PAL["gold"])
	if requires_prism:
		draw_rect(Rect2(-2.0, -7.0, 4.0, 2.0), PAL["deep"])
		draw_rect(Rect2(-1.0, -7.0, 2.0, 2.0), PAL["sky"])
		draw_rect(Rect2(-1.0, -7.0, 1.0, 1.0), PAL["ice"])
	draw_rect(Rect2(-5.0, -3.0, 10.0, 5.0), PAL["void"])
	if activated:
		draw_rect(Rect2(-4.0, -2.0, 8.0, 3.0), PAL["apricot"])
		draw_rect(Rect2(-3.0, -3.0, 6.0, 5.0), PAL["gold"])
		draw_rect(Rect2(-2.0, -2.0, 4.0, 3.0), PAL["cream"])
		var glint_c: Color = (PAL["cream"] if _pulse_stage < 2 else PAL["gold"]) as Color
		draw_rect(Rect2(0.0, -5.0, 1.0, 1.0), glint_c)
		draw_rect(Rect2(0.0, 3.0, 1.0, 1.0), glint_c)
		draw_rect(Rect2(-6.0, -1.0, 1.0, 1.0), glint_c)
		draw_rect(Rect2(5.0, -1.0, 1.0, 1.0), glint_c)
		if reset_time > 0.0 and _reset_left > 0.0:
			var frac: float = clampf(_reset_left / reset_time, 0.0, 1.0)
			var bar_w: float = roundf(10.0 * frac)
			draw_rect(Rect2(-5.0, 6.0, 10.0, 2.0), PAL["void"])
			if bar_w >= 1.0:
				draw_rect(Rect2(-5.0, 6.0, bar_w, 1.0), PAL["cream"] if frac > 0.35 else PAL["coral"])
	else:
		draw_rect(Rect2(-4.0, -2.0, 8.0, 3.0), PAL["sky"] if _reject_t > 0.0 else PAL["deep"])
		draw_rect(Rect2(-3.0, -2.0, 6.0, 3.0), PAL["ice"] if _reject_t > 0.0 else PAL["blue"])
		var shine: Color = (PAL["cream"] if _reject_t > 0.0 else (PAL["ice"] if (requires_prism or _pulse_stage == 0) else PAL["sky"])) as Color
		draw_rect(Rect2(-2.0, -2.0, 4.0, 1.0), PAL["sky"])
		draw_rect(Rect2(-2.0, -2.0, 2.0, 1.0), shine)
		draw_rect(Rect2(-1.0, -2.0, 2.0, 3.0), PAL["void"])
		draw_rect(Rect2(-2.0, -1.0, 1.0, 1.0), shine)
		if _reject_t > 0.0:
			draw_arc(Vector2(0.0, -1.0), 8.0, 0.0, TAU, 12, PAL["ice"], 1.0, false)
	_draw_signal_pulses()
