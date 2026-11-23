class_name LxCrackedWall
extends LxInteractable
## Fractured stone barrier broken by Beam or Sunflare.

var broken: bool = false
var size: Vector2 = Vector2(16.0, 16.0)
var _break_t: float = 0.0
var _hint_t: float = 0.0
var _pulse_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "cracked_wall"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	broken = bool(props.get("broken", false))
	active = not broken
	_break_t = 0.0
	_hint_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _break_t > 0.0:
		_break_t = maxf(0.0, _break_t - dt)
		dirty = true
	if _hint_t > 0.0:
		_hint_t = maxf(0.0, _hint_t - dt)
		dirty = true
	if active and not broken:
		var st: int = int(floorf(_clock * 1.4 + absf(pos.x * 0.02 + pos.y * 0.03))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			dirty = true
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var wc: LxWick = Lx.player as LxWick
			if wc.is_beam_charging() and wc.global_position.distance_squared_to(pos) <= 9216.0:
				dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or broken:
		return false
	if hit.source in ["beam", "sunflare"]:
		broken = true
		active = false
		_break_t = 0.38
		_hint_t = 0.0
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.16)
			Lx.events.hitstop_requested.emit(0.045)
		_emit_gust(maxf(size.x, size.y) + 34.0, 74.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, pos, 13.0, 7.0)
		_emit_sfx("stone_break")
		_emit_save("cracked_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "throw", "recall"]:
		_hint_t = 0.30
		_emit_sfx("lantern_land")
		queue_redraw()
		return false
	return false


func is_solid() -> bool:
	return active and not broken


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if _break_t > 0.0:
		var u: float = clampf(_break_t / 0.38, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 64.0 * u, (0.88 if LxHudFx.flash_reduced() else 1.35) * u)
	if _hint_t > 0.0 and active and not broken:
		var h: float = clampf(_hint_t / 0.30, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 34.0, 0.85 * h)
	return Vector4.ZERO


func save_state() -> Dictionary:
	return {"active": active, "broken": broken}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	broken = bool(d.get("broken", broken))
	active = not broken
	queue_redraw()


func _draw() -> void:
	if _break_t > 0.0:
		_draw_shatter_burst()
		_draw_signal_pulses()
		return
	if broken or not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var jx: float = (1.0 if int(floorf(_hint_t * 36.0)) % 2 == 0 else -1.0) if (_hint_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + jx
	var y0: float = floorf(-h * 0.5)
	draw_rect(Rect2(x0, y0, w, h), PAL["void"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	var st_cols: Array[String] = _biome_stone_colors()
	var c_brick0: Color = PAL[st_cols[0]] as Color
	var c_brick1: Color = PAL[st_cols[1]] as Color
	var c_brick2: Color = PAL[st_cols[2]] as Color
	var row_h: float = 6.0 if h >= 14.0 else maxf(4.0, floorf((h - 2.0) * 0.5))
	var by: float = y0 + 1.0
	var row: int = 0
	while by < y0 + h - 1.0:
		var bh: float = minf(row_h, y0 + h - 1.0 - by)
		var bx: float = x0 + 1.0 - (4.0 if row % 2 == 1 else 0.0)
		while bx < x0 + w - 1.0:
			var rx0: float = maxf(x0 + 1.0, bx)
			var rx1: float = minf(x0 + w - 1.0, bx + 9.0)
			var bw: float = rx1 - rx0
			if bw >= 3.0 and bh >= 3.0:
				draw_rect(Rect2(rx0, by, bw - 1.0, bh - 1.0), c_brick0)
				draw_rect(Rect2(rx0, by, bw - 1.0, maxf(1.0, bh - 2.0)), c_brick1)
				draw_rect(Rect2(rx0, by, bw - 1.0, 1.0), c_brick2)
				draw_rect(Rect2(rx0, by, 1.0, bh - 2.0), c_brick2)
			bx += 9.0
		by += row_h
		row += 1
	var hub: Vector2 = Vector2(floorf(x0 + w * 0.52), floorf(y0 + h * 0.48))
	var cracks: Array = [
		[Vector2(x0 + 2.0, y0 + 2.0), Vector2(floorf(x0 + w * 0.3), floorf(y0 + h * 0.35)), hub],
		[hub, Vector2(floorf(x0 + w * 0.68), floorf(y0 + h * 0.68)), Vector2(x0 + w - 2.0, y0 + h - 2.0)],
		[hub, Vector2(floorf(x0 + w * 0.72), floorf(y0 + h * 0.25)), Vector2(x0 + w - 3.0, y0 + 2.0)],
		[hub, Vector2(floorf(x0 + w * 0.32), floorf(y0 + h * 0.78)), Vector2(x0 + 3.0, y0 + h - 2.0)],
	]
	for raw_seg: Variant in cracks:
		var seg: Array = raw_seg as Array
		var a: Vector2 = seg[0] as Vector2
		var b: Vector2 = seg[1] as Vector2
		var c: Vector2 = seg[2] as Vector2
		draw_line(a - Vector2(1.0, 1.0), b - Vector2(1.0, 1.0), c_brick2, 1.0)
		draw_line(a, b, PAL["void"], 2.0)
		draw_line(b, c, PAL["void"], 1.5)
	draw_rect(Rect2(hub - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PAL["void"])
	var hint_on: bool = _hint_t > 0.0
	var b_glow: Color = LxBiomePalette.col(island_id, "glow")
	var seam_c: Color = (PAL["cream"] if hint_on else (b_glow if _pulse_stage == 0 else LxBiomePalette.col(island_id, "hi"))) as Color
	draw_line(Vector2(hub.x - 2.0, hub.y - 1.0), Vector2(hub.x + 2.0, hub.y + 1.0), seam_c, 1.0)
	draw_rect(Rect2(hub, Vector2(1.0, 1.0)), PAL["cream"] if (hint_on or _pulse_stage == 0) else PAL["gold"])
	if hint_on:
		var u: float = 1.0 - clampf(_hint_t / 0.30, 0.0, 1.0)
		draw_line(Vector2(hub.x - 3.0, hub.y + 1.0), Vector2(hub.x + 3.0, hub.y - 1.0), PAL["gold"], 1.0)
		for k: int in range(4):
			var a: float = (TAU * float(k)) / 4.0 + 0.5
			var dp: Vector2 = hub + Vector2(roundf(cos(a) * (3.0 + u * 5.0)), roundf(sin(a) * (3.0 + u * 5.0) + u * 3.0))
			draw_rect(Rect2(dp, Vector2.ONE), c_brick2 if k % 2 == 0 else b_glow)
	draw_rect(Rect2(x0 + 2.0, y0 + h - 2.0, 2.0, 2.0), c_brick1)
	draw_rect(Rect2(x0 + 2.0, y0 + h - 2.0, 1.0, 1.0), c_brick2)
	draw_rect(Rect2(x0 + w - 5.0, y0 + h - 2.0, 2.0, 1.0), c_brick0)
	draw_rect(Rect2(hub.x - 3.0, y0 + h - 1.0, 2.0, 1.0), c_brick2)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var wc_d: LxWick = Lx.player as LxWick
		if wc_d.is_beam_charging() and wc_d.global_position.distance_squared_to(pos) <= 9216.0:
			var bp_c: float = clampf(wc_d.beam_charge_progress(), 0.2, 1.0)
			draw_rect(Rect2(x0, y0, w, h), Color((PAL["cream"] if bp_c >= 0.99 else b_glow) as Color, bp_c * 0.62), false, 1.0)
			draw_rect(Rect2(hub - Vector2.ONE, Vector2(3.0, 3.0)), Color(PAL["cream"] as Color, bp_c * 0.85))


func _biome_stone_colors() -> Array[String]:
	match island_id:
		2: return ["deep", "blue", "sky"]      # Sea-worn coastal harbor slate
		3: return ["pine", "teal", "jade"]     # Mossy ancient forest stone
		4: return ["teal", "sky", "ice"]       # Pale glasshouse marble
		5: return ["deep", "blue", "stone"]    # Celestial observatory ashlar
		6: return ["night", "dusk", "wine"]    # Volcanic kiln basalt
		7: return ["deep", "sky", "ice"]       # Silver moonstone masonry
		8: return ["night", "dusk", "plum"]    # Eclipsed cathedral stone
		_: return ["dusk", "mauve", "stone"]   # Bell Isle warm abbey stone


func _draw_shatter_burst() -> void:
	var u: float = 1.0 - clampf(_break_t / 0.38, 0.0, 1.0)
	var spread: float = maxf(size.x, size.y) * 0.48
	var st_cols: Array[String] = _biome_stone_colors()
	if u < 0.45:
		draw_arc(Vector2.ZERO, roundf(lerpf(3.0, spread + 8.0, u / 0.45)), 0.0, TAU, 14, (LxBiomePalette.col(island_id, "glow") if u < 0.22 else PAL[st_cols[2]]) as Color, 1.0, false)
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0 + 0.2
		var d: float = lerpf(2.0, spread + 12.0, u)
		var px: float = roundf(cos(a) * d)
		var py: float = roundf(sin(a) * d + u * u * 10.0 - u * 4.0)
		var sz: float = 3.0 if (u < 0.35 and i % 2 == 0) else (2.0 if u < 0.65 else 1.0)
		var c: Color = (PAL[st_cols[2]] if i % 3 == 0 else (PAL[st_cols[1]] if i % 3 == 1 else PAL[st_cols[0]])) as Color
		draw_rect(Rect2(px, py, sz, sz), c)
