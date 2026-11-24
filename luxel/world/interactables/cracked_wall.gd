class_name LxCrackedWall
extends LxInteractable
## Fractured stone barrier broken by Beam or Sunflare.

var broken: bool = false
var from_map_tile: bool = false
var size: Vector2 = Vector2(16.0, 16.0)
var _break_t: float = 0.0
var _hint_t: float = 0.0
var _pulse_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "cracked_wall"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	from_map_tile = bool(props.get("from_map_tile", false))
	broken = bool(props.get("broken", false))
	active = not broken
	z_index = -4 if broken else 0
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
		z_index = -4
		_break_t = 0.38
		_hint_t = 0.0
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.16)
			Lx.events.hitstop_requested.emit(0.045)
		_emit_gust(maxf(size.x, size.y) + 34.0, 74.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, pos, 13.0, 7.0)
		_emit_sfx("stone_break")
		if region != null and region.has_method("save_interactables_to_state"):
			region.call("save_interactables_to_state")
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
	z_index = -4 if broken else 0
	queue_redraw()


func _draw() -> void:
	if broken:
		# Transparent-backed scattered rubble ring so painted ground shines cleanly underneath
		_draw_puzzle_tiled("cracked_rubble", size)
		if _break_t > 0.0:
			_draw_shatter_burst()
		_draw_signal_pulses()
		return
	if not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var jx: float = (1.0 if int(floorf(_hint_t * 36.0)) % 2 == 0 else -1.0) if (_hint_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + jx
	var y0: float = floorf(-h * 0.5)
	_draw_ground_shadow(w * 0.44, 2.5, Vector2(2.0, floorf(h * 0.5)))
	var wall_key: String = _cracked_prop_key()
	var frame_ov: int = 1 if (_hint_t > 0.0 or _pulse_stage == 0) else 0
	_draw_puzzle_tiled(wall_key, size, Vector2(jx, 0.0), _clock, Color.WHITE, frame_ov)
	if _hint_t > 0.0:
		var u: float = 1.0 - clampf(_hint_t / 0.30, 0.0, 1.0)
		var b_glow: Color = LxBiomePalette.col(island_id, "glow")
		for k: int in range(4):
			var a: float = (TAU * float(k)) / 4.0 + 0.5
			var dp := Vector2(roundf(cos(a) * (3.0 + u * 5.0)), roundf(sin(a) * (3.0 + u * 5.0) + u * 3.0))
			draw_rect(Rect2(dp, Vector2.ONE), (PAL["stone"] as Color) if k % 2 == 0 else b_glow)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var wc_d: LxWick = Lx.player as LxWick
		if wc_d.is_beam_charging() and wc_d.global_position.distance_squared_to(pos) <= 9216.0:
			var bp_c: float = clampf(wc_d.beam_charge_progress(), 0.2, 1.0)
			var hc: Color = (PAL["cream"] if bp_c >= 0.99 else PAL["gold"]) as Color
			draw_rect(Rect2(x0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0, y0 + h - 3.0, 1.0, 3.0), hc)
			draw_rect(Rect2(x0 + w - 3.0, y0 + h - 1.0, 3.0, 1.0), hc)
			draw_rect(Rect2(x0 + w - 1.0, y0 + h - 3.0, 1.0, 3.0), hc)


func _cracked_prop_key() -> String:
	if island_id in [2, 4, 7]:
		return "cracked_coastal"
	if island_id in [6, 8]:
		return "cracked_basalt"
	return "cracked_slate"


func _draw_shatter_burst() -> void:
	var u: float = 1.0 - clampf(_break_t / 0.38, 0.0, 1.0)
	var spread: float = maxf(size.x, size.y) * 0.48
	var c0: Color = (PAL["blue"] if island_id in [2, 4, 7] else (PAL["plum"] if island_id in [6, 8] else PAL["dusk"])) as Color
	var c1: Color = (PAL["sky"] if island_id in [2, 4, 7] else (PAL["wine"] if island_id in [6, 8] else PAL["mauve"])) as Color
	var c2: Color = (PAL["ice"] if island_id in [2, 4, 7] else (PAL["coral"] if island_id in [6, 8] else PAL["stone"])) as Color
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0 + 0.2
		var d: float = lerpf(2.0, spread + 12.0, u)
		var px: float = roundf(cos(a) * d)
		var py: float = roundf(sin(a) * d + u * u * 10.0 - u * 4.0)
		var sz: float = 3.0 if (u < 0.35 and i % 2 == 0) else (2.0 if u < 0.65 else 1.0)
		var c: Color = c2 if i % 3 == 0 else (c1 if i % 3 == 1 else c0)
		draw_rect(Rect2(px, py, sz, sz), c)
