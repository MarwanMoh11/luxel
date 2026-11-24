class_name LxShadowGate
extends LxToy
## Shadow barrier that opens ONLY when unlit. Samples region light pools, Wick's lantern, and active beams.
## Props: size [w,h], threshold (float, default 0.35), persist (bool), target_id/target_ids.

var threshold: float = 0.35
var opened: bool = false
var lit_level: float = 0.0
var _direct_lit: bool = false
var _trans_t: float = 0.0


func _toy_setup() -> void:
	kind = "shadow_gate"
	if not props.has("size"):
		size = Vector2(32.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	threshold = clampf(float(props.get("threshold", 0.35)), 0.05, 1.0)
	opened = bool(props.get("opened", false))
	powered = opened
	lit_level = 0.0
	_direct_lit = false
	_trans_t = 0.0
	z_index = -4 if opened else 0
	queue_redraw()


func reset_toy() -> void:
	if persist and opened:
		return
	_direct_lit = false
	_evaluate_light(false)


func on_light(light_radius: float, _source: String) -> void:
	if active and light_radius > 0.0:
		_direct_lit = true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _trans_t > 0.0:
		_trans_t = maxf(0.0, _trans_t - dt)
		queue_redraw()
	_evaluate_light(true)


func _evaluate_light(with_sfx: bool) -> void:
	var sampled: float = LxToyDraw.sample_light_at(region, pos, self)
	if _direct_lit:
		sampled = maxf(sampled, 0.85)
		_direct_lit = false
	lit_level = sampled
	var want_open: bool = lit_level < threshold
	if want_open == opened:
		return
	# Anti-crush: never snap shut directly on top of Wick
	if not want_open and rect_at(pos).grow(4.0).has_point(wick_pos()):
		return
	opened = want_open
	powered = opened
	_trans_t = 0.28
	z_index = -4 if opened else 0
	_notify_linked_targets(opened)
	if with_sfx:
		_emit_sfx("phantom_phase" if opened else "shadow_whisper")
	queue_redraw()


func is_solid() -> bool:
	return active and not opened


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["opened"] = opened
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("opened"):
		opened = bool(d["opened"])
		powered = opened
		z_index = -4 if opened else 0
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_ice: Color = PAL["ice"] as Color

	if opened:
		var jb: float = minf(5.0, floorf(minf(w, h) * 0.3))
		if w >= h:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, jb, h), c_night, c_dusk, c_plum, c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0 + w - jb, y0, jb, h), c_night, c_dusk, c_plum, c_void)
		else:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, jb), c_night, c_dusk, c_plum, c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0 + h - jb, w, jb), c_night, c_dusk, c_plum, c_void)
		# Subtle dark-moon open pip
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_plum)
		return

	# Closed shadow barrier: sealed by ambient light
	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 2.0, 2.0), c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), c_void, c_night, c_plum, c_void)
	# Interlocking vertical shadow ribs
	var sx: float = x0 + 4.0
	while sx < x0 + w - 4.0:
		draw_rect(Rect2(sx, y0 + 2.0, 2.0, h - 4.0), c_dusk)
		sx += 5.0
	# Moon emblem shows light is sealing it
	LxToyDraw.draw_tone_crest(self, Vector2.ZERO, "dusk", lit_level >= threshold)
	if lit_level >= threshold:
		draw_rect(Rect2(-3.0, y0 + 1.0, 6.0, 1.0), c_ice)
	_draw_signal_pulses()
