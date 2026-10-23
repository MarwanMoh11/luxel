extends RefCounted
## Reads finger taps for a menu or a card: a touch that went down after arm() (and ARM_DELAY later) and lifted within
## SLOP px and HOLD s of where it went down. The thumb that was steering when the menu opened, a finger still down
## from the last screen, or the touch that switched the game from keys to touch (its buttons weren't drawn yet) never
## counts. Feed it every input event from _unhandled_input; it only reads touches.

const SLOP := 8.0 ## px a tap may slide before it counts as a drag
const HOLD := 0.8 ## s a tap may stay down
const ARM_DELAY := 0.2 ## s after arm() before a touch can start a tap (a stray thumb as the menu pops open)

var _armed_at := -1.0 # s (ticks) arm() was called; -1: disarmed
var _tapping := false # a finger down now may become a tap
var _index := 0 # its index: any int (on iOS it can be negative)
var _from := Vector2.ZERO
var _from_t := 0.0


## Start reading taps (the screen just opened). Fingers already down are ignored.
func arm() -> void:
	_armed_at = _now()
	_tapping = false


func disarm() -> void:
	_armed_at = -1.0
	_tapping = false


## Feed `event`; returns where a finished tap went down, local to `item`, or Vector2.INF if this event finishes none.
func feed(event: InputEvent, item: CanvasItem) -> Vector2:
	if _armed_at < 0.0:
		return Vector2.INF
	var drag := event as InputEventScreenDrag
	if drag != null:
		if _tapping and drag.index == _index and (item.make_input_local(drag) as InputEventScreenDrag).position.distance_to(_from) > SLOP:
			_tapping = false
		return Vector2.INF
	var touch := event as InputEventScreenTouch
	if touch == null:
		return Vector2.INF
	var at: Vector2 = (item.make_input_local(touch) as InputEventScreenTouch).position
	if touch.pressed:
		if not _tapping and Touch.settled() and _now() - _armed_at >= ARM_DELAY: # the first touch only shows the buttons
			_tapping = true
			_index = touch.index
			_from = at
			_from_t = _now()
		return Vector2.INF
	if not _tapping or touch.index != _index:
		return Vector2.INF
	_tapping = false
	if at.distance_to(_from) > SLOP or _now() - _from_t > HOLD:
		return Vector2.INF
	return _from


## Where the finger that may become a tap is down now (local to the item it was fed with), or Vector2.INF.
func held() -> Vector2:
	return _from if _tapping else Vector2.INF


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
