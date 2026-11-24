class_name LxBramble
extends LxInteractable
## Dense thorn barrier burned away by Beam.

var burned: bool = false
var from_map_tile: bool = false
var size: Vector2 = Vector2(16.0, 16.0)
var _burn_t: float = 0.0
var _rustle_t: float = 0.0
var _sway_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "bramble"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	from_map_tile = bool(props.get("from_map_tile", false))
	burned = bool(props.get("burned", false))
	active = not burned
	z_index = -4 if burned else 0
	_burn_t = 0.0
	_rustle_t = 0.0
	_sway_stage = 0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _burn_t > 0.0:
		_burn_t = maxf(0.0, _burn_t - dt)
		dirty = true
	if _rustle_t > 0.0:
		_rustle_t = maxf(0.0, _rustle_t - dt)
		dirty = true
	if active and not burned:
		var st: int = int(floorf(_clock / 0.45 + absf(pos.x * 0.03))) % 2
		if st != _sway_stage:
			_sway_stage = st
			dirty = true
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var wb: LxWick = Lx.player as LxWick
			if wb.is_beam_charging() and wb.global_position.distance_squared_to(pos) <= 9216.0:
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
		_burn_t = 0.36
		_rustle_t = 0.0
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.14)
		_emit_gust(maxf(size.x, size.y) + 28.0, 62.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.SCORCH, pos, 12.0, 6.0)
		_emit_sfx("bramble_burn")
		if region != null and region.has_method("save_interactables_to_state"):
			region.call("save_interactables_to_state")
		_emit_save("bramble_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "throw", "recall"]:
		_rustle_t = 0.24
		_emit_sfx("thorn_clank")
		queue_redraw()
		return false
	return false


func is_solid() -> bool:
	return active and not burned


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if _burn_t > 0.0:
		var u: float = clampf(_burn_t / 0.36, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 58.0 * u, (0.88 if LxHudFx.flash_reduced() else 1.35) * u)
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
		# Transparent-backed charred stumps & ash flecks so the real painted ground shines cleanly underneath
		_draw_puzzle_tiled("bramble_charred", size)
		if _burn_t > 0.0:
			var el: float = 0.36 - _burn_t
			if el < 0.18:
				var stage_u: float = clampf(el / 0.18, 0.0, 1.0)
				var tint_c: Color = Color(PAL["cream"] as Color, 0.85) if stage_u < 0.34 else (Color(PAL["coral"] as Color, 0.68) if stage_u < 0.68 else Color(PAL["wine"] as Color, 0.42))
				_draw_puzzle_tiled("bramble_tile", size, Vector2(0.0, roundf(stage_u * 2.0)), _clock, tint_c, _sway_stage)
			_draw_burn_burst()
		_draw_signal_pulses()
		return
	if not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	_draw_ground_shadow(w * 0.44, 2.5, Vector2(2.0, floorf(h * 0.5)))
	_draw_puzzle_tiled("bramble_tile", size, Vector2.ZERO, _clock, Color.WHITE, _sway_stage)
	if _rustle_t > 0.0:
		var u: float = 1.0 - clampf(_rustle_t / 0.24, 0.0, 1.0)
		for k: int in range(4):
			var a: float = (TAU * float(k)) / 4.0 + 0.4
			var dp := Vector2(roundf(cos(a) * (4.0 + u * 5.0)), roundf(sin(a) * (3.0 + u * 4.0) - u * 4.0))
			draw_rect(Rect2(dp, Vector2.ONE), (PAL["rose"] if k % 2 == 0 else PAL["lime"]) as Color)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var wb_d: LxWick = Lx.player as LxWick
		if wb_d.is_beam_charging() and wb_d.global_position.distance_squared_to(pos) <= 9216.0:
			var bp: float = clampf(wb_d.beam_charge_progress(), 0.2, 1.0)
			var hc: Color = (PAL["cream"] if bp >= 0.99 else PAL["gold"]) as Color
			draw_rect(Rect2(x0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0 + h - 3.0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0 + h - 3.0, 1.0, 3.0), hc)


func _draw_burn_burst() -> void:
	var u: float = 1.0 - clampf(_burn_t / 0.36, 0.0, 1.0)
	var spread: float = maxf(size.x, size.y) * 0.45
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0 + 0.3
		var d: float = lerpf(2.0, spread + 11.0, u)
		var px: float = roundf(cos(a) * d)
		var py: float = roundf(sin(a) * d - u * 9.0)
		var sz: float = 2.0 if u < 0.45 else 1.0
		var c: Color = (PAL["cream"] if u < 0.25 else (PAL["gold"] if u < 0.55 else (PAL["coral"] if i % 2 == 0 else PAL["wine"]))) as Color
		draw_rect(Rect2(px, py, sz, sz), c)
