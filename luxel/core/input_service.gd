class_name LxInputService
extends Node
## Runtime InputMap actions (prefix lx_), full keyboard/mouse/gamepad rebinding,
## hold/toggle modes, last-device glyph tracking, and 100% manual aim (ZERO aim assist).

signal device_changed(device_kind: String)
signal bindings_changed()

const ACTIONS: PackedStringArray = [
	"lx_move_up",
	"lx_move_down",
	"lx_move_left",
	"lx_move_right",
	"lx_fire",
	"lx_throw",
	"lx_dash",
	"lx_beam",
	"lx_sunflare",
	"lx_interact",
	"lx_pause",
	"lx_map",
	"lx_ui_accept",
	"lx_ui_cancel",
]

const STICK_DEADZONE: float = 0.22
const AIM_ASSIST_ENABLED: bool = false # Locked non-negotiable: never true.

var last_device: String = "kbm" # "kbm" or "gamepad"
var last_aim_dir: Vector2 = Vector2.RIGHT
var _active_joy_id: int = 0
var hold_modes: Dictionary = {"lx_fire": "hold", "lx_beam": "hold", "lx_wings": "hold"}
var _toggle_states: Dictionary = {}
var _synthetic_move: Vector2 = Vector2.ZERO
var _synthetic_aim: Vector2 = Vector2.ZERO
var _use_synthetic: bool = false


func setup() -> void:
	register_default_actions()


func register_default_actions() -> void:
	for act: String in ACTIONS:
		if not InputMap.has_action(act):
			InputMap.add_action(act, STICK_DEADZONE)
		else:
			InputMap.action_erase_events(act)

	_add_key("lx_move_up", KEY_W)
	_add_key("lx_move_up", KEY_UP)
	_add_joy_axis("lx_move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_btn("lx_move_up", JOY_BUTTON_DPAD_UP)

	_add_key("lx_move_down", KEY_S)
	_add_key("lx_move_down", KEY_DOWN)
	_add_joy_axis("lx_move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_btn("lx_move_down", JOY_BUTTON_DPAD_DOWN)

	_add_key("lx_move_left", KEY_A)
	_add_key("lx_move_left", KEY_LEFT)
	_add_joy_axis("lx_move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_btn("lx_move_left", JOY_BUTTON_DPAD_LEFT)

	_add_key("lx_move_right", KEY_D)
	_add_key("lx_move_right", KEY_RIGHT)
	_add_joy_axis("lx_move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_btn("lx_move_right", JOY_BUTTON_DPAD_RIGHT)

	_add_mouse("lx_fire", MOUSE_BUTTON_LEFT)
	_add_key("lx_fire", KEY_SPACE)
	_add_key("lx_fire", KEY_J)
	_add_joy_axis("lx_fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_add_mouse("lx_throw", MOUSE_BUTTON_RIGHT)
	_add_joy_axis("lx_throw", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_add_key("lx_dash", KEY_SHIFT)
	_add_key("lx_dash", KEY_K)
	_add_joy_btn("lx_dash", JOY_BUTTON_A)

	_add_key("lx_beam", KEY_F)
	_add_joy_btn("lx_beam", JOY_BUTTON_X)

	_add_key("lx_sunflare", KEY_Q)
	_add_joy_btn("lx_sunflare", JOY_BUTTON_Y)

	_add_key("lx_interact", KEY_E)
	_add_joy_btn("lx_interact", JOY_BUTTON_B)

	_add_key("lx_pause", KEY_ESCAPE)
	_add_key("lx_pause", KEY_P)
	_add_joy_btn("lx_pause", JOY_BUTTON_START)

	_add_key("lx_map", KEY_TAB)
	_add_joy_btn("lx_map", JOY_BUTTON_BACK)

	_add_key("lx_ui_accept", KEY_ENTER)
	_add_key("lx_ui_accept", KEY_SPACE)
	_add_joy_btn("lx_ui_accept", JOY_BUTTON_A)

	_add_key("lx_ui_cancel", KEY_ESCAPE)
	_add_joy_btn("lx_ui_cancel", JOY_BUTTON_B)

	bindings_changed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE):
		_active_joy_id = maxi(0, event.device)
		_set_device("gamepad")
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_device("kbm")

	for act: String in hold_modes.keys():
		if str(hold_modes[act]) == "toggle" and InputMap.has_action(act) and event.is_action_pressed(act):
			_toggle_states[act] = not bool(_toggle_states.get(act, false))


func _set_device(kind: String) -> void:
	if last_device != kind:
		last_device = kind
		device_changed.emit(kind)


func is_action_active(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	if str(hold_modes.get(action, "hold")) == "toggle":
		return bool(_toggle_states.get(action, false))
	return Input.is_action_pressed(action)


func is_toggle_mode(action: String) -> bool:
	return str(hold_modes.get(action, "hold")) == "toggle"


func clear_toggle(action: String) -> void:
	_toggle_states.erase(action)


func clear_all_toggles() -> void:
	_toggle_states.clear()


func set_synthetic(active: bool, move_vec: Vector2 = Vector2.ZERO, aim_vec: Vector2 = Vector2.RIGHT) -> void:
	_use_synthetic = active
	_synthetic_move = move_vec
	if aim_vec.length_squared() > 0.0001:
		_synthetic_aim = aim_vec.normalized()
		last_aim_dir = _synthetic_aim


func get_move_vector() -> Vector2:
	if _use_synthetic:
		return _synthetic_move.limit_length(1.0)
	var v: Vector2 = Input.get_vector("lx_move_left", "lx_move_right", "lx_move_up", "lx_move_down")
	return v.limit_length(1.0)


func get_aim_dir(from_world: Vector2, mouse_world: Vector2) -> Vector2:
	# Strictly manual aim: never nudges, magnetizes, or snaps onto any enemy or target.
	if _use_synthetic:
		return last_aim_dir
	if last_device == "gamepad":
		var rx: float = Input.get_joy_axis(_active_joy_id, JOY_AXIS_RIGHT_X)
		var ry: float = Input.get_joy_axis(_active_joy_id, JOY_AXIS_RIGHT_Y)
		var stick: Vector2 = Vector2(rx, ry)
		if stick.length() >= STICK_DEADZONE:
			last_aim_dir = stick.normalized()
		return last_aim_dir
	var delta: Vector2 = mouse_world - from_world
	if delta.length_squared() > 0.001:
		last_aim_dir = delta.normalized()
	return last_aim_dir


func rebind_action(action: String, new_event: InputEvent, device_kind: String = "kbm") -> bool:
	if not InputMap.has_action(action) or new_event == null:
		return false
	var existing: Array[InputEvent] = InputMap.action_get_events(action)
	for ev: InputEvent in existing:
		var ev_is_pad: bool = ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if (device_kind == "gamepad" and ev_is_pad) or (device_kind != "gamepad" and not ev_is_pad):
			InputMap.action_erase_event(action, ev)
	InputMap.action_add_event(action, new_event)
	bindings_changed.emit()
	return true


func export_bindings() -> Dictionary:
	var out: Dictionary = {}
	for act: String in ACTIONS:
		if not InputMap.has_action(act):
			continue
		var list: Array[Dictionary] = []
		for ev: InputEvent in InputMap.action_get_events(act):
			if ev is InputEventKey:
				list.append({"t": "key", "code": int((ev as InputEventKey).physical_keycode)})
			elif ev is InputEventMouseButton:
				list.append({"t": "mouse", "btn": int((ev as InputEventMouseButton).button_index)})
			elif ev is InputEventJoypadButton:
				list.append({"t": "jbtn", "btn": int((ev as InputEventJoypadButton).button_index)})
			elif ev is InputEventJoypadMotion:
				var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
				list.append({"t": "jaxis", "axis": int(jm.axis), "val": float(jm.axis_value)})
		out[act] = list
	return out


func import_bindings(data: Dictionary) -> void:
	if data.is_empty():
		return
	for act: String in data.keys():
		if not InputMap.has_action(act):
			continue
		var arr: Variant = data[act]
		if not (arr is Array) or (arr as Array).is_empty():
			continue
		InputMap.action_erase_events(act)
		for item: Variant in (arr as Array):
			if not (item is Dictionary):
				continue
			var d: Dictionary = item as Dictionary
			match str(d.get("t", "")):
				"key":
					_add_key(act, int(d.get("code", 0)) as Key)
				"mouse":
					_add_mouse(act, int(d.get("btn", 1)) as MouseButton)
				"jbtn":
					_add_joy_btn(act, int(d.get("btn", 0)) as JoyButton)
				"jaxis":
					_add_joy_axis(act, int(d.get("axis", 0)) as JoyAxis, float(d.get("val", 1.0)))
	bindings_changed.emit()


func get_glyph(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var want_pad: bool = last_device == "gamepad"
	for ev: InputEvent in InputMap.action_get_events(action):
		var is_pad: bool = ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad != want_pad:
			continue
		return event_to_glyph(ev)
	return "-"


static func event_to_glyph(ev: InputEvent) -> String:
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "MB" + str(int((ev as InputEventMouseButton).button_index))
	if ev is InputEventKey:
		var kc: Key = (ev as InputEventKey).physical_keycode
		if kc == KEY_NONE:
			kc = (ev as InputEventKey).keycode
		var s: String = OS.get_keycode_string(kc).to_upper()
		return s.replace(" ", "-")
	if ev is InputEventJoypadButton:
		match (ev as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				return "A"
			JOY_BUTTON_B:
				return "B"
			JOY_BUTTON_X:
				return "X"
			JOY_BUTTON_Y:
				return "Y"
			JOY_BUTTON_START:
				return "START"
			JOY_BUTTON_BACK:
				return "SELECT"
			JOY_BUTTON_LEFT_SHOULDER:
				return "LB"
			JOY_BUTTON_RIGHT_SHOULDER:
				return "RB"
			_:
				return "PAD" + str(int((ev as InputEventJoypadButton).button_index))
	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		if jm.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		if jm.axis == JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		return "STICK"
	return "-"


func _add_key(action: String, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, btn: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


func _add_joy_btn(action: String, btn: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, val: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	InputMap.action_add_event(action, ev)
