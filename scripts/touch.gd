extends Node
## Autoload "Touch": playing on a touch screen.
## `active` is true while the last input came from a finger (a phone or tablet starts that way): the game then shows
## touch prompts and buttons in place of key hints. A key press or a real mouse click turns it off again.
## In play, a thumb down anywhere drops the floating stick there and dragging steers Wick (`move()`); the stick's
## base trails a thumb that pulls past its reach, so reversing is instant. The pause button sits in the screen's
## top-right corner. main.gd sets `stick_enabled` and `pause_enabled` every frame. Menus and cards read their taps
## with TapReader (scripts/game/ui/tap.gd).
## Everything is in game-screen pixels (the 320x180 screen's top-left is 0,0; Display.screen_rect() is the window).
## Debug arg `touch` (after `--`) starts in touch mode and turns mouse drags into touches, to try it on a desktop.

signal mode_changed(active: bool)
signal pause_pressed

const LAYER := 20 ## above the menu (10) and the cards: the controls stay crisp through every sold look
const STICK_R := 12.0 ## px: how far the knob reaches from the base
const DEAD := 2.0 ## px: a smaller pull stands still
const KNOB_R := 4.0
const PAUSE_BOX := Vector2(11, 11) ## the drawn button
const PAUSE_HIT := Vector2(30, 24) ## px from the screen's top-right corner that press the pause button
const PAL: Dictionary = preload("res://scripts/game/ui/palette.gd").PAL

var active := false ## the last input was a finger
var stick_enabled := false: set = _set_stick_enabled ## main: Wick takes moves now (in play, world running, no card)
var pause_enabled := false: set = _set_pause_enabled ## main: the pause button shows and works
var _on_frame := -1 # the process frame touch mode last turned on
var _finger := -1 # the steering finger's index (-1: none)
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _view: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if OS.has_feature("web"): # iPads report a desktop browser: ask the page whether the main pointer is a finger
		active = active or bool(JavaScriptBridge.eval("matchMedia('(hover: none) and (pointer: coarse)').matches", true))
	if "touch" in OS.get_cmdline_user_args():
		active = true
		Input.emulate_touch_from_mouse = true
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	add_child(layer)
	_view = Node2D.new()
	_view.draw.connect(_draw_view)
	layer.add_child(_view)
	Display.changed.connect(_view.queue_redraw)


## The stick's direction: a unit vector, or zero when no thumb steers (or it pulls less than DEAD px).
func move() -> Vector2:
	if _finger < 0:
		return Vector2.ZERO
	var pull := _knob - _base
	return pull.normalized() if pull.length() > DEAD else Vector2.ZERO


## The pause button's touch area, in game-screen pixels.
func pause_rect() -> Rect2:
	var screen := Display.screen_rect()
	return Rect2(Vector2(screen.end.x - PAUSE_HIT.x, screen.position.y), PAUSE_HIT)


## Px the HUD's top-right readout (the clock) moves left to clear the pause button (0 when it doesn't show).
func corner_room() -> float:
	return PAUSE_BOX.x + 3.0 if active and pause_enabled else 0.0


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_set_active(false)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.device != InputEvent.DEVICE_ID_EMULATION \
			and not Input.emulate_touch_from_mouse: # the debug arg `touch`: the mouse plays a finger
		_set_active(false)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_set_active(true)
		var at: Vector2 = (_view.make_input_local(touch) as InputEventScreenTouch).position
		if touch.pressed:
			if pause_enabled and pause_rect().has_point(at):
				get_viewport().set_input_as_handled()
				pause_pressed.emit()
			elif stick_enabled and _finger < 0:
				_finger = touch.index
				_base = at
				_knob = at
				_view.queue_redraw()
				get_viewport().set_input_as_handled()
		elif touch.index == _finger:
			_finger = -1
			_view.queue_redraw()
			get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _finger:
		_knob = (_view.make_input_local(drag) as InputEventScreenDrag).position
		var pull := _knob - _base
		if pull.length() > STICK_R:
			_base = _knob - pull.normalized() * STICK_R
		_view.queue_redraw()
		get_viewport().set_input_as_handled()


## Touch mode was already on before this frame, so the buttons a finger can press were on screen when it went down.
func settled() -> bool:
	return active and Engine.get_process_frames() > _on_frame


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on:
		_on_frame = Engine.get_process_frames()
	_view.queue_redraw()
	mode_changed.emit(on)


func _set_stick_enabled(on: bool) -> void:
	if on == stick_enabled:
		return
	stick_enabled = on
	if not on: # a thumb held through a menu or a card lets go: steering again takes a fresh touch
		_finger = -1
	if _view != null:
		_view.queue_redraw()


func _set_pause_enabled(on: bool) -> void:
	if on == pause_enabled:
		return
	pause_enabled = on
	if _view != null:
		_view.queue_redraw()


func _draw_view() -> void:
	if not active:
		return
	if pause_enabled:
		var screen := Display.screen_rect()
		var box := Rect2(Vector2(screen.end.x - 4.0 - PAUSE_BOX.x, screen.position.y + 3.0), PAUSE_BOX)
		_view.draw_rect(box, PAL["mauve"])
		_view.draw_rect(box.grow(-1), PAL["night"])
		for x in [3.0, 6.0]:
			_view.draw_rect(Rect2(box.position + Vector2(x, 3), Vector2(2, 5)), PAL["stone"])
	if _finger >= 0 and stick_enabled:
		var base := _base.round()
		_view.draw_circle(base, STICK_R + 1.0, Color(PAL["night"], 0.45))
		_view.draw_arc(base, STICK_R, 0.0, TAU, 32, Color(PAL["stone"], 0.7), 1.0)
		var knob := (base + (_knob - _base).limit_length(STICK_R)).round()
		_view.draw_circle(knob, KNOB_R + 1.0, PAL["night"])
		_view.draw_circle(knob, KNOB_R, PAL["cream"])
