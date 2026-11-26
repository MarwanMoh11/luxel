class_name LxShadowGate
extends LxToy
## Shadow barrier that opens ONLY when unlit. Samples region light pools, Wick's lantern, and active beams.
## Props: size [w,h], threshold (float, default 0.35), persist (bool), target_id/target_ids.

var threshold: float = 0.35
var opened: bool = false
var lit_level: float = 0.0
var _direct_lit: bool = false
var _trans_t: float = 0.0
var _toggle_cd: float = 0.0


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
	_toggle_cd = 0.0
	z_index = -4 if opened else 0
	queue_redraw()


func reset_toy() -> void:
	if persist and opened:
		return
	_direct_lit = false
	_toggle_cd = 0.0
	_evaluate_light(false)


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	# Lantern light is already accurately sampled (with distance falloff and self-ignoring LOS)
	# by LxToyDraw.sample_light_at(); ignoring lantern pushes here prevents edge-distance strobing.
	if source == "lantern_hand" or source == "lantern_hung":
		return
	_direct_lit = true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _toggle_cd > 0.0:
		_toggle_cd = maxf(0.0, _toggle_cd - dt)
	if _trans_t > 0.0:
		_trans_t = maxf(0.0, _trans_t - dt)
		queue_redraw()
	elif opened and not LxHudFx.flash_reduced():
		queue_redraw()
	_evaluate_light(true)


func _evaluate_light(with_sfx: bool) -> void:
	var sampled: float = LxToyDraw.sample_light_at(region, pos, self)
	if _direct_lit:
		sampled = maxf(sampled, 0.85)
		_direct_lit = false
	lit_level = sampled
	var unlock_flag: String = str(props.get("unlock_flag", "")).strip_edges()
	var flag_open: bool = not unlock_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(unlock_flag, false))
	var hyst: float = 0.04 if with_sfx else 0.0
	var want_open: bool = true if flag_open else ((lit_level < threshold - hyst) if not opened else (lit_level < threshold + hyst))
	if want_open == opened:
		return
	if with_sfx and _toggle_cd > 0.0:
		return
	# Anti-crush: never snap shut directly on top of Wick
	if not want_open and rect_at(pos).grow(4.0).has_point(wick_pos()):
		return
	opened = want_open
	powered = opened
	_trans_t = 0.28
	_toggle_cd = 0.14 if with_sfx else 0.0
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


func _draw_gatepost(rect: Rect2, c_void: Color, c_night: Color, c_dusk: Color, c_plum: Color, c_mauve: Color, c_stone: Color, c_sky: Color, c_ice: Color, c_cream: Color) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	# Grounded drop shadow under obsidian post
	draw_rect(Rect2(r.position.x + 1.0, r.end.y, r.size.x, 2.0), Color(c_void, 0.38))
	draw_rect(r, c_void)
	draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, maxf(1.0, r.size.x - 2.0), maxf(1.0, r.size.y - 2.0)), c_night)
	draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, maxf(1.0, r.size.x - 2.0), maxf(1.0, r.size.y - 4.0)), c_dusk)
	draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, maxf(1.0, r.size.x - 2.0), 1.0), c_stone)
	draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, 1.0, maxf(1.0, r.size.y - 3.0)), c_mauve)
	if r.size.y >= 8.0:
		draw_rect(Rect2(r.position.x + 1.0, floorf(r.get_center().y), maxf(1.0, r.size.x - 2.0), 1.0), c_plum)
	# Ornate wrought-iron crescent-moon finial perched atop post
	var fx: float = floorf(r.get_center().x)
	var fy: float = r.position.y - 4.0
	draw_rect(Rect2(fx - 3.0, fy, 7.0, 5.0), c_void)
	draw_rect(Rect2(fx - 2.0, fy + 3.0, 5.0, 1.0), c_plum)
	draw_rect(Rect2(fx - 2.0, fy + 1.0, 1.0, 2.0), c_ice)
	draw_rect(Rect2(fx + 2.0, fy + 1.0, 1.0, 2.0), c_sky)
	draw_rect(Rect2(fx - 1.0, fy + 2.0, 3.0, 1.0), c_sky)
	draw_rect(Rect2(fx - 2.0, fy + 1.0, 1.0, 1.0), c_cream)


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var red: bool = LxHudFx.flash_reduced()
	var horiz: bool = w >= h
	var pw: float = clampf(floorf(minf(w, h) * 0.34), 5.0, 7.0)

	if opened:
		# Recessed threshold sill + ornate obsidian gateposts with crescent-moon finials
		if horiz:
			draw_rect(Rect2(x0 + pw, y0 + h - 4.0, maxf(2.0, w - pw * 2.0), 3.0), Color(c_void, 0.36))
			draw_rect(Rect2(x0 + pw, y0 + h - 3.0, maxf(2.0, w - pw * 2.0), 1.0), c_dusk)
			_draw_gatepost(Rect2(x0, y0, pw, h), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
			_draw_gatepost(Rect2(x0 + w - pw, y0, pw, h), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
		else:
			draw_rect(Rect2(x0 + 2.0, y0 + pw, maxf(2.0, w - 4.0), maxf(2.0, h - pw * 2.0)), Color(c_void, 0.30))
			_draw_gatepost(Rect2(x0, y0, w, pw), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
			_draw_gatepost(Rect2(x0, y0 + h - pw, w, pw), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
		# Subtle floating shadow-wisp pips drifting between the open gateposts
		var span: float = maxf(4.0, (w if horiz else h) - pw * 2.0 - 2.0)
		for wi: int in range(3):
			var u: float = (float(wi) + 0.5) / 3.0 - 0.5
			var bob: float = 0.0 if red else roundf(sin(_clock * 2.6 + float(wi) * 2.1) * 1.6)
			var wp: Vector2 = Vector2(roundf(u * span), bob) if horiz else Vector2(bob, roundf(u * span))
			draw_rect(Rect2(wp - Vector2.ONE, Vector2(3.0, 3.0)), Color(c_void, 0.45))
			draw_rect(Rect2(wp, Vector2(2.0, 2.0)), c_plum if wi != 1 else c_mauve)
			draw_rect(Rect2(wp, Vector2.ONE), c_sky if wi == 1 else c_mauve)
		return

	# Solid midnight-stone moon-crest barrier sealed by light
	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 2.0, 3.0), Color(c_void, 0.40))
	draw_rect(Rect2(x0, y0, w, h), c_void)
	# Recessed dark south foundation course
	var base_h: float = minf(4.0, floorf(h * 0.25))
	draw_rect(Rect2(x0 + 1.0, y0 + h - base_h, w - 2.0, base_h - 1.0), c_night)
	# Main midnight-stone wall body + sunlit bevelled coping
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, maxf(3.0, h - base_h - 1.0)), c_dusk)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, 1.0), c_mauve)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 1.0, maxf(2.0, h - base_h - 1.0)), c_plum)
	# Sculpted staggered masonry stonework courses
	var row_y: float = y0 + 4.0
	var row_i: int = 0
	while row_y < y0 + h - base_h - 1.0:
		draw_rect(Rect2(x0 + 2.0, row_y, w - 4.0, 1.0), c_night)
		var bx: float = x0 + 4.0 + (3.0 if row_i % 2 == 1 else 0.0)
		while bx < x0 + w - 4.0:
			draw_rect(Rect2(bx, row_y - 3.0, 1.0, 3.0), c_night)
			draw_rect(Rect2(bx + 1.0, row_y - 3.0, 2.0, 1.0), c_plum)
			bx += 6.0
		row_y += 4.0
		row_i += 1
	# Flanking obsidian gateposts with crescent-moon finials framing the wall
	if horiz:
		_draw_gatepost(Rect2(x0, y0, pw, h), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
		_draw_gatepost(Rect2(x0 + w - pw, y0, pw, h), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
	else:
		_draw_gatepost(Rect2(x0, y0, w, pw), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)
		_draw_gatepost(Rect2(x0, y0 + h - pw, w, pw), c_void, c_night, c_dusk, c_plum, c_mauve, c_stone, c_sky, c_ice, c_cream)

	# Central carved Moon-Crest bezel medallion
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), c_void)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), c_night)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 1.0), c_plum)
	LxToyDraw.draw_tone_crest(self, Vector2.ZERO, "dusk", lit_level >= threshold)
	if lit_level >= threshold:
		draw_rect(Rect2(-4.0, y0 + 1.0, 8.0, 1.0), c_cream if (red or int(floorf(_clock * 6.0)) % 2 == 0) else c_ice)
	_draw_signal_pulses()
