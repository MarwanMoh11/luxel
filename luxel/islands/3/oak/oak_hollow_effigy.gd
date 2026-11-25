class_name LxOakHollowEffigy
extends LxToy
## Wordless Hollow Wick monument (`oak_r9c`, Bible §3.4 & §8.1):
## Fossilized amber effigy of Hollow Wick clutching an unlit seed-lantern.
## When both flanking braziers are lit (receiving signals `requires_signals`),
## it casts an unmistakable double-winged shadow across the north wall and emits power!
## Props: requires_signals (Array[String]), target_id/target_ids.

var req_signals: Array[String] = []
var wings_cast: bool = false
var _wing_t: float = 0.0


func _toy_setup() -> void:
	kind = "oak_hollow_effigy"
	req_signals.clear()
	var raw_s: Variant = props.get("requires_signals", [])
	if raw_s is Array:
		for sv: Variant in (raw_s as Array):
			var sid: String = str(sv).strip_edges()
			if not sid.is_empty():
				req_signals.append(sid)
	radius = 16.0
	wings_cast = powered
	_wing_t = 1.0 if wings_cast else 0.0
	queue_redraw()


func _all_braziers_lit() -> bool:
	if req_signals.is_empty() or region == null or not region.has_method("find_interactable"):
		return false
	for sid: String in req_signals:
		var it: Variant = region.call("find_interactable", sid)
		if not (it is LxInteractable):
			return false
		var node: LxInteractable = it as LxInteractable
		if not ((node.get("lit") == true) or (node.get("powered") == true)):
			return false
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var ok: bool = _all_braziers_lit()
	if ok and not wings_cast:
		wings_cast = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("phantom_phase")
	if wings_cast and _wing_t < 1.0:
		_wing_t = minf(1.0, _wing_t + dt * 0.85)
		queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(8.0, 6.0), Vector2(16.0, 12.0)) if active else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 48.0 if wings_cast else 24.0, 0.54 if wings_cast else 0.30)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_ice: Color = PAL["ice"] as Color

	# Double-winged shadow cast onto north sanctuary wall once twin braziers burn!
	if _wing_t > 0.02:
		var span: float = roundf(34.0 * _wing_t)
		var lift: float = roundf(24.0 * _wing_t)
		var l_wing := PackedVector2Array([
			Vector2(-4.0, -14.0), Vector2(-span, -14.0 - lift),
			Vector2(-span + 6.0, -4.0 - lift * 0.5), Vector2(-5.0, -4.0),
		])
		var r_wing := PackedVector2Array([
			Vector2(4.0, -14.0), Vector2(span, -14.0 - lift),
			Vector2(span - 6.0, -4.0 - lift * 0.5), Vector2(5.0, -4.0),
		])
		draw_colored_polygon(l_wing, Color(c_void, 0.82))
		draw_colored_polygon(r_wing, Color(c_void, 0.82))
		draw_polyline(l_wing, Color(c_plum, 0.70), 1.0)
		draw_polyline(r_wing, Color(c_plum, 0.70), 1.0)

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.5)
	# Amber fossil monolith encasing Hollow Wick silhouette
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -20.0, 18.0, 26.0), c_wine, c_apricot, c_gold, c_void)
	draw_rect(Rect2(-6.0, -17.0, 12.0, 20.0), c_apricot)
	# Cloaked silhouette clutching cold unlit seed-lantern
	draw_rect(Rect2(-3.0, -14.0, 6.0, 14.0), c_night)
	draw_rect(Rect2(-4.0, -8.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(-2.0, -12.0, 1.0, 1.0), c_ice)
	draw_rect(Rect2(1.0, -12.0, 1.0, 1.0), c_ice)
	# Unlit seed-lantern held at side
	draw_rect(Rect2(3.0, -7.0, 3.0, 4.0), c_dusk)
	draw_rect(Rect2(4.0, -6.0, 1.0, 2.0), c_cream if wings_cast else c_plum)
	_draw_signal_pulses()
