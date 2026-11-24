class_name LxToneDoor
extends LxToy
## Resonant barrier opened by an LxRingWave whose tone matches `tone` ("dawn" | "dusk" | "war").
## Props: tone ("dawn"|"dusk"|"war"), size [w,h], hold_secs (float, 0 = stays open), toggle (bool), persist (bool).

var tone: String = "dawn"
var opened: bool = false
var hold_secs: float = 0.0
var toggle_mode: bool = false
var _hold_left: float = 0.0
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _init_open: bool = false


func _toy_setup() -> void:
	kind = "tone_door"
	tone = str(props.get("tone", "dawn")).strip_edges().to_lower()
	if tone not in ["dawn", "dusk", "war"]:
		tone = "dawn"
	if not props.has("size"):
		size = Vector2(32.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	hold_secs = maxf(0.0, float(props.get("hold_secs", 0.0)))
	toggle_mode = bool(props.get("toggle", false))
	_init_open = bool(props.get("opened", powered))
	opened = _init_open
	powered = opened
	_hold_left = hold_secs if (opened and hold_secs > 0.0) else 0.0
	_open_t = 0.0
	_rattle_t = 0.0
	z_index = -4 if opened else 0
	queue_redraw()


func reset_toy() -> void:
	if persist and opened:
		return
	opened = _init_open
	_hold_left = 0.0
	powered = opened
	z_index = -4 if opened else 0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	var dirty: bool = false
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		dirty = true
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		dirty = true
	if opened and hold_secs > 0.0:
		_hold_left -= dt
		dirty = true
		if _hold_left <= 0.0 and not _wick_inside():
			opened = false
			powered = false
			z_index = 0
			_emit_sfx("door_locked")
			_notify_linked_targets(false)
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or opened:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		_rattle_t = 0.24
		_emit_sfx("door_locked")
		queue_redraw()
		return true
	return false


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active:
		return
	if in_tone.strip_edges().to_lower() != tone:
		_rattle_t = 0.28
		_emit_sfx("door_locked")
		queue_redraw()
		return
	if toggle_mode and opened:
		if not _wick_inside():
			opened = false
			powered = false
			z_index = 0
			_emit_sfx("door_locked")
			_notify_linked_targets(false)
			queue_redraw()
		return
	if not opened:
		opened = true
		powered = true
		_open_t = 0.36
		z_index = -4
		_emit_sfx("door_open")
		_emit_gust(maxf(size.x, size.y) + 18.0, 42.0)
		_notify_linked_targets(true)
		if persist and region != null and region.has_method("save_interactables_to_state"):
			region.call("save_interactables_to_state")
	if hold_secs > 0.0:
		_hold_left = hold_secs
	queue_redraw()


func _wick_inside() -> bool:
	return rect_at(pos).grow(4.0).has_point(wick_pos())


func is_solid() -> bool:
	return active and not opened


func blocks_sight() -> bool:
	return active and not opened


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if opened:
		return Vector4(pos.x, pos.y, 32.0, 0.42)
	return Vector4(pos.x, pos.y, 26.0, 0.36)


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
	var rdx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + rdx
	var y0: float = floorf(-h * 0.5)
	var trip: Array[Color] = LxToyDraw.color_triplet(tone)
	var c_void: Color = PAL["void"] as Color

	if opened:
		var jb: float = minf(5.0, floorf(minf(w, h) * 0.3))
		if w >= h:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, jb, h), PAL["night"] as Color, trip[0], trip[1], c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0 + w - jb, y0, jb, h), PAL["night"] as Color, trip[0], trip[1], c_void)
		else:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, jb), PAL["night"] as Color, trip[0], trip[1], c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0 + h - jb, w, jb), PAL["night"] as Color, trip[0], trip[1], c_void)
		if hold_secs > 0.0 and _hold_left > 0.0:
			LxToyDraw.draw_bar(self, Vector2(-7.0, y0 - 4.0), 14.0, _hold_left / hold_secs, trip[1])
		if _open_t > 0.0:
			var u: float = 1.0 - clampf(_open_t / 0.36, 0.0, 1.0)
			draw_arc(Vector2.ZERO, roundf(lerpf(4.0, maxf(w, h) * 0.5, u)), 0.0, TAU, 16, trip[2], 1.0)
		return

	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 2.0, 2.0), c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), PAL["night"] as Color, PAL["dusk"] as Color, trip[0], c_void)
	# Resonant inlay pattern (greyscale-distinct per tone: Dawn solid bar, Dusk dotted ribs, War diagonal slashes)
	if tone == "dusk":
		var sx: float = x0 + 4.0
		while sx < x0 + w - 3.0:
			draw_rect(Rect2(sx, y0 + 2.0, 1.0, h - 4.0), trip[1])
			sx += 4.0
	elif tone == "war":
		var wx: float = x0 + 3.0
		while wx < x0 + w - 5.0:
			draw_line(Vector2(wx, y0 + h - 3.0), Vector2(wx + 4.0, y0 + 2.0), trip[1], 1.0, false)
			wx += 6.0
	elif w >= h:
		draw_rect(Rect2(x0 + 3.0, -1.0, w - 6.0, 2.0), trip[0])
		draw_rect(Rect2(x0 + 4.0, -1.0, w - 8.0, 1.0), trip[1])
	else:
		draw_rect(Rect2(-1.0, y0 + 3.0, 2.0, h - 6.0), trip[0])
		draw_rect(Rect2(-1.0, y0 + 4.0, 1.0, h - 8.0), trip[1])
	LxToyDraw.draw_tone_crest(self, Vector2(rdx, 0.0), tone, _rattle_t <= 0.0)
	if _rattle_t > 0.0:
		LxPixelGlyphs.draw_reject_x(self, Vector2(0.0, -4.0), 1.0 - _rattle_t / 0.28, 1.0, LxHudFx.flash_reduced())
	_draw_signal_pulses()
