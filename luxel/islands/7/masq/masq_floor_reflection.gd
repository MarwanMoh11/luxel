class_name LxMasqFloorReflection
extends LxToy
## Island 7 Masquerade r2 Under-Glass Floor Reflection Layer:
## Draws a shimmering mirror-floor reflection showing the hidden chasms, chandelier arcs,
## and crimson-masked reflections beneath the 3 impostor dancers!
## Pulsing True Lens sharpens the glass floor contrast and marks safe diamond paths.
## Props: impostor_ids (Array[String]), radius_px (float, default 180).

var impostor_ids: Array[String] = []
var _lens_boost_t: float = 0.0


func _toy_setup() -> void:
	kind = "masq_floor_reflection"
	impostor_ids.clear()
	var raw_ids: Variant = props.get("impostor_ids", [])
	if raw_ids is Array:
		for iv: Variant in (raw_ids as Array):
			var s: String = str(iv).strip_edges()
			if not s.is_empty():
				impostor_ids.append(s)
	radius = maxf(64.0, float(props.get("radius_px", 180.0)))
	z_index = -6
	_lens_boost_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	_lens_boost_t = 0.0
	queue_redraw()


func on_light(light_radius: float, source: String) -> void:
	if active and light_radius > 0.0 and source in ["lens", "lens_anchor"]:
		_lens_boost_t = 2.4
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _lens_boost_t > 0.0:
		_lens_boost_t = maxf(0.0, _lens_boost_t - dt)
		dirty = true
	if not LxHudFx.flash_reduced():
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var boost: bool = _lens_boost_t > 0.0
	var a_floor: float = 0.42 if boost else 0.24

	# Subtle under-glass diamond reflection filigree across the ballroom floor
	for gx: int in range(-160, 176, 48):
		for gy: int in range(-80, 96, 48):
			var dp := Vector2(float(gx), float(gy))
			draw_line(dp + Vector2(0, -10), dp + Vector2(12, 0), Color(c_sky if boost else c_ice, a_floor), 1.0)
			draw_line(dp + Vector2(12, 0), dp + Vector2(0, 10), Color(c_sky if boost else c_ice, a_floor), 1.0)
			draw_line(dp + Vector2(0, 10), dp + Vector2(-12, 0), Color(c_sky if boost else c_ice, a_floor), 1.0)
			draw_line(dp + Vector2(-12, 0), dp + Vector2(0, -10), Color(c_sky if boost else c_ice, a_floor), 1.0)

	# Draw telltale upside-down crimson-masked reflections beneath each unmasked impostor!
	if region == null or not region.has_method("find_interactable"):
		return
	for iid: String in impostor_ids:
		var it: Variant = region.call("find_interactable", iid)
		if not (it is LxInteractable) or not is_instance_valid(it):
			continue
		var d: LxInteractable = it as LxInteractable
		if not d.active or d.powered:
			continue
		var lp: Vector2 = (d.pos - pos).round()
		var ry: float = lp.y + 8.0
		var pulse: float = 0.85 if LxHudFx.flash_reduced() else (0.70 + 0.25 * sin(_clock * 4.5))
		var ra: float = minf(1.0, (0.90 if boost else 0.65) * pulse)
		# Upside-down cloak & crimson assassin mask reflected in the glass floor
		draw_rect(Rect2(lp.x - 4.0, ry, 8.0, 9.0), Color(c_void, ra * 0.75))
		draw_rect(Rect2(lp.x - 3.0, ry + 1.0, 6.0, 7.0), Color(c_wine, ra))
		draw_rect(Rect2(lp.x - 3.0, ry + 5.0, 6.0, 3.0), Color(c_coral if boost else c_rose, ra))
		draw_rect(Rect2(lp.x - 2.0, ry + 6.0, 1.0, 1.0), Color(c_cream, ra))
		draw_rect(Rect2(lp.x + 1.0, ry + 6.0, 1.0, 1.0), Color(c_cream, ra))
		if boost:
			draw_arc(Vector2(lp.x, ry + 4.0), 9.0, 0.0, TAU, 14, Color(c_gold, 0.72), 1.0)
