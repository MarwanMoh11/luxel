class_name LxWeb
extends LxInteractable
## Silk web barrier burned away by Beam.

var burned: bool = false
var size: Vector2 = Vector2(24.0, 16.0)
var _burn_t: float = 0.0
var _tremble_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "web"
	size = _parse_size(props.get("size", [24.0, 16.0]), Vector2(24.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	burned = bool(props.get("burned", false))
	active = not burned
	z_index = -4 if burned else 0
	_burn_t = 0.0
	_tremble_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _burn_t > 0.0:
		_burn_t = maxf(0.0, _burn_t - dt)
		dirty = true
	if _tremble_t > 0.0:
		_tremble_t = maxf(0.0, _tremble_t - dt)
		dirty = true
	if active and not burned and Lx.player is LxWick and is_instance_valid(Lx.player):
		var ww: LxWick = Lx.player as LxWick
		if ww.is_beam_charging() and ww.global_position.distance_squared_to(pos) <= 9216.0:
			dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or burned:
		return false
	if hit.source in ["beam", "sunflare"]:
		burned = true
		active = false
		z_index = -4
		_burn_t = 0.34
		_tremble_t = 0.0
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.10)
		_emit_gust(maxf(size.x, size.y) + 26.0, 56.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.SCORCH, pos, 10.0, 5.0)
		_emit_sfx("web_burn")
		_emit_save("web_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "throw", "recall"]:
		_tremble_t = 0.22
		_emit_sfx("prop_rustle")
		queue_redraw()
		return false
	return false


func is_solid() -> bool:
	return active and not burned


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if _burn_t > 0.0:
		var u: float = clampf(_burn_t / 0.34, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 54.0 * u, (0.82 if LxHudFx.flash_reduced() else 1.25) * u)
	return Vector4.ZERO


func save_state() -> Dictionary:
	return {"active": active, "burned": burned}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	burned = bool(d.get("burned", burned))
	active = not burned
	z_index = -4 if burned else 0
	queue_redraw()


func _draw() -> void:
	if burned:
		_draw_puzzle_tiled("web_torn", size)
		if _burn_t > 0.0:
			_draw_burn_burst()
		_draw_signal_pulses()
		return
	if not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var jx: float = (1.0 if int(floorf(_tremble_t * 32.0)) % 2 == 0 else -1.0) if (_tremble_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + jx
	var y0: float = floorf(-h * 0.5)
	_draw_puzzle_tiled("web_tile", size, Vector2(jx, 0.0))
	if _tremble_t > 0.0:
		var u: float = 1.0 - clampf(_tremble_t / 0.22, 0.0, 1.0)
		for k: int in range(4):
			var a: float = (TAU * float(k)) / 4.0
			var pt := Vector2(roundf(cos(a) * (3.0 + u * 5.0)), roundf(sin(a) * (2.0 + u * 4.0)))
			draw_rect(Rect2(pt, Vector2.ONE), (PAL["gold"] if k % 2 == 0 else PAL["ice"]) as Color)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var ww_d: LxWick = Lx.player as LxWick
		if ww_d.is_beam_charging() and ww_d.global_position.distance_squared_to(pos) <= 9216.0:
			var bp_w: float = clampf(ww_d.beam_charge_progress(), 0.2, 1.0)
			var hc: Color = (PAL["cream"] if bp_w >= 0.99 else PAL["gold"]) as Color
			draw_rect(Rect2(x0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0 + h - 3.0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0 + h - 3.0, 1.0, 3.0), hc)


func _draw_burn_burst() -> void:
	var u: float = 1.0 - clampf(_burn_t / 0.34, 0.0, 1.0)
	var rx: float = size.x * 0.45
	var ry: float = size.y * 0.45
	var b_glow_w: Color = LxBiomePalette.col(island_id, "glow")
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0
		var px: float = roundf(cos(a) * lerpf(3.0, rx + 7.0, u))
		var py: float = roundf(sin(a) * lerpf(2.0, ry + 5.0, u) - u * 7.0)
		var c: Color = (PAL["cream"] as Color) if u < 0.3 else (b_glow_w if i % 2 == 0 else (PAL["ice"] as Color))
		draw_rect(Rect2(px, py, 2.0 if u < 0.4 else 1.0, 1.0), c)
