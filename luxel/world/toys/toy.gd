class_name LxToy
extends LxInteractable
## Base for every shared toy (Luxel Epic). Adds: power state, signal logic, wick access, skins, optional persistence.
##
## Common props: target_id / target_ids (signals out), persist (bool, keep solved state), skin (String), size [w,h],
## dir [x,y] or "n|e|s|w", on (bool, start state), period / offset (s).

var powered: bool = false
var persist: bool = false
var size: Vector2 = Vector2(16.0, 16.0)
var skin: String = ""
var _in_signals: Dictionary = {}


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	persist = bool(props.get("persist", false))
	skin = str(props.get("skin", ""))
	size = LxMapFormat.to_vec2(props.get("size", size), size)
	powered = bool(props.get("on", false))
	_toy_setup()


## Override instead of setup().
func _toy_setup() -> void:
	pass


## Override: called when the toy's own power flips (from signals or set_powered()).
func _on_power_changed(_is_on: bool) -> void:
	pass


func on_signal(from_id: String, is_on: bool) -> void:
	_in_signals[from_id] = is_on
	var mode: String = str(props.get("signal_mode", "any"))
	var any_on: bool = false
	var all_on: bool = true
	for v: Variant in _in_signals.values():
		any_on = any_on or bool(v)
		all_on = all_on and bool(v)
	var need_v: Variant = props.get("requires_signals", [])
	if need_v is Array and not (need_v as Array).is_empty():
		all_on = true
		for sid: Variant in need_v as Array:
			all_on = all_on and bool(_in_signals.get(str(sid), false))
	match mode:
		"all":
			set_powered(all_on)
		"toggle":
			if is_on:
				set_powered(not powered)
		_:
			set_powered(any_on)


func set_powered(is_on: bool) -> void:
	if powered == is_on:
		return
	powered = is_on
	_on_power_changed(is_on)
	queue_redraw()


## Send power to every target in props (uses the shared pulse arcs).
func emit_power(is_on: bool) -> void:
	_notify_linked_targets(is_on)
	if Lx.events != null and is_on and bool(props.get("sfx", true)):
		_emit_sfx(str(props.get("sfx_on", "switch_on")))


func wick_pos() -> Vector2:
	if region != null and region.has_method("get_wick_pos"):
		return region.call("get_wick_pos") as Vector2
	return Vector2(-9999.0, -9999.0)


func dir_vec(key: String = "dir", fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	var v: Variant = props.get(key, null)
	if v is String:
		match str(v).to_lower():
			"n": return Vector2.UP
			"s": return Vector2.DOWN
			"e": return Vector2.RIGHT
			"w": return Vector2.LEFT
	return LxMapFormat.to_vec2(v, fallback).normalized()


func rect_at(center: Vector2) -> Rect2:
	return Rect2(center - size * 0.5, size)


func biome(key: String) -> Color:
	return LxBiomePalette.col(island_id, key)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["powered"] = powered
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("powered"):
		powered = bool(d["powered"])
		_on_power_changed(powered)
