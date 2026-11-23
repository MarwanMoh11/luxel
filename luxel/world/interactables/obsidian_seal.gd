class_name LxObsidianSeal
extends LxInteractable
## Heavy obsidian barrier shattered only by Sunflare.

var shattered: bool = false
var size: Vector2 = Vector2(32.0, 16.0)
var _resonate_t: float = 0.0
var _shatter_t: float = 0.0
var _pulse_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "obsidian_seal"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	shattered = bool(props.get("shattered", false))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	_resonate_t = 0.0
	_shatter_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _shatter_t > 0.0:
		_shatter_t = maxf(0.0, _shatter_t - dt)
		queue_redraw()
		return
	if _resonate_t > 0.0:
		_resonate_t = maxf(0.0, _resonate_t - dt)
		queue_redraw()
		return
	if active and not shattered:
		var st: int = int(floorf(_clock * 2.2 + absf(pos.x * 0.03))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			queue_redraw()
		elif Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).global_position.distance_squared_to(pos) <= 4624.0:
			queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source == "sunflare":
		shattered = true
		active = false
		_shatter_t = 0.42
		if Lx.state != null and not id.is_empty() and not Lx.state.broken_seals.has(id):
			Lx.state.broken_seals.append(id)
		if Lx.events != null:
			Lx.events.seal_broken.emit(island_id, id)
			Lx.events.shake_requested.emit(0.24)
			Lx.events.hitstop_requested.emit(0.055)
		_emit_gust(96.0, 92.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, pos, 16.0, 9.0)
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 15.0, 8.0)
		_emit_sfx("seal_shatter")
		_emit_save("seal_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "dash"]:
		_resonate_t = 0.22
		_emit_sfx("shield_clang")
		queue_redraw()
		return true
	return false


func get_light_pool() -> Vector4:
	if _shatter_t > 0.0:
		var u: float = clampf(_shatter_t / 0.42, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 76.0 * u, (0.95 if LxHudFx.flash_reduced() else 1.50) * u)
	if shattered or not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 44.0 if _resonate_t > 0.0 else 38.0, 0.95 if _resonate_t > 0.0 else 0.68)


func is_solid() -> bool:
	return active and not shattered


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "shattered": shattered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	shattered = bool(d.get("shattered", shattered))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	queue_redraw()


func _draw() -> void:
	if _shatter_t > 0.0:
		_draw_shatter_burst()
		_draw_signal_pulses()
		return
	if shattered or not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var jx: float = (1.0 if int(floorf(_resonate_t * 36.0)) % 2 == 0 else -1.0) if (_resonate_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + jx
	var y0: float = floorf(-h * 0.5)
	var res: bool = _resonate_t > 0.0
	draw_rect(Rect2(x0 + 1.0, y0, w - 2.0, h), PAL["void"])
	draw_rect(Rect2(x0, y0 + 2.0, w, h - 4.0), PAL["void"])
	draw_rect(Rect2(x0 + 2.0, y0 + 1.0, w - 4.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 1.0, y0 + 3.0, w - 2.0, h - 6.0), PAL["night"])
	draw_rect(Rect2(x0 + 3.0, y0 + 2.0, floorf(w * 0.45), floorf(h * 0.55)), PAL["dusk"])
	draw_rect(Rect2(x0 + floorf(w * 0.5), y0 + 2.0, floorf(w * 0.35), floorf(h * 0.45)), PAL["dusk"])
	draw_rect(Rect2(x0 + 3.0, y0 + 2.0, floorf(w * 0.4), 1.0), PAL["mauve"])
	draw_rect(Rect2(x0 + 2.0, y0 + 3.0, 1.0, floorf(h * 0.45)), PAL["mauve"])
	draw_rect(Rect2(x0 + floorf(w * 0.58), y0 + 2.0, floorf(w * 0.25), 1.0), PAL["mauve"])
	var v_outer: Color = (PAL["coral"] if res else PAL["wine"]) as Color
	var v_mid: Color = (PAL["gold"] if res else (PAL["apricot"] if _pulse_stage < 2 else PAL["coral"])) as Color
	var v_hot: Color = (PAL["cream"] if res else PAL["gold"]) as Color
	var veins: Array = [
		[Vector2(0.0, 0.0), Vector2(floorf(-w * 0.24), -2.0), Vector2(floorf(-w * 0.42), floorf(-h * 0.32))],
		[Vector2(0.0, 0.0), Vector2(floorf(w * 0.22), -1.0), Vector2(floorf(w * 0.42), floorf(-h * 0.28))],
		[Vector2(0.0, 0.0), Vector2(floorf(-w * 0.2), 2.0), Vector2(floorf(-w * 0.38), floorf(h * 0.34))],
		[Vector2(0.0, 0.0), Vector2(floorf(w * 0.24), 2.0), Vector2(floorf(w * 0.4), floorf(h * 0.32))],
	]
	for raw_br: Variant in veins:
		var br: Array = raw_br as Array
		var a: Vector2 = br[0] as Vector2
		var b: Vector2 = br[1] as Vector2
		var c: Vector2 = br[2] as Vector2
		draw_line(a, b, v_outer, 2.0)
		draw_line(b, c, v_outer, 1.0)
		draw_line(a, b, v_mid, 1.0)
		draw_rect(Rect2(b, Vector2(1.0, 1.0)), v_hot)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), PAL["void"])
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), PAL["night"])
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), v_outer)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), v_mid)
	draw_rect(Rect2(0.0, -5.0, 1.0, 2.0), v_hot)
	draw_rect(Rect2(0.0, 3.0, 1.0, 2.0), v_hot)
	draw_rect(Rect2(-5.0, 0.0, 2.0, 1.0), v_hot)
	draw_rect(Rect2(3.0, 0.0, 2.0, 1.0), v_hot)
	if res:
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["gold"], false, 1.0)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), PAL["cream"])
	else:
		var core_c: Color = (PAL["cream"] if _pulse_stage == 0 else PAL["gold"]) as Color
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), core_c)
	# Sympathetic solar crackle when Wick carries Sunflare near an intact Obsidian Seal
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w_s: LxWick = Lx.player as LxWick
		if w_s.move_sunflare != null and w_s.move_sunflare.unlocked:
			var d_os: float = w_s.global_position.distance_to(pos)
			if d_os <= 64.0:
				var prox_os: float = clampf(1.0 - d_os / 64.0, 0.0, 1.0)
				var fr_os: bool = LxHudFx.flash_reduced()
				var charged: bool = w_s.ember >= w_s.move_sunflare.get_ember_max() - 0.001
				var ca_os: float = (0.45 if fr_os else (0.55 if charged else 0.34)) * prox_os
				draw_rect(Rect2(x0, y0, w, h), Color((PAL["gold"] if charged else PAL["coral"]) as Color, ca_os), false, 1.0)
				for si: int in range(3 if charged else 2):
					var su: float = fposmod(_clock * (0.95 if charged else 0.65) + float(si) * 0.33, 1.0)
					var sx: float = roundf(sin(_clock * 2.8 + float(si) * 2.4) * (w * 0.32))
					var sy: float = roundf(-2.0 - su * 14.0)
					draw_rect(Rect2(sx, sy, 1.0, 1.0), Color((PAL["cream"] if (charged and su < 0.4) else PAL["gold"]) as Color, sin(su * PI) * prox_os * 0.9))


func _draw_shatter_burst() -> void:
	var u: float = 1.0 - clampf(_shatter_t / 0.42, 0.0, 1.0)
	var spread: float = maxf(size.x, size.y) * 0.52
	var b_glow: Color = LxBiomePalette.col(island_id, "glow")
	if u < 0.6:
		draw_arc(Vector2.ZERO, roundf(lerpf(5.0, spread + 14.0, u / 0.6)), 0.0, TAU, 18, (PAL["cream"] if u < 0.25 else PAL["gold"]) as Color, 2.0 if u < 0.3 else 1.0, false)
		draw_arc(Vector2.ZERO, roundf(lerpf(8.0, spread + 20.0, u / 0.6)), 0.0, TAU, 18, b_glow, 1.0, false)
	for i: int in range(10):
		var a: float = (TAU * float(i)) / 10.0 + 0.15
		var d: float = lerpf(3.0, spread + 16.0, u)
		var px: float = roundf(cos(a) * d)
		var py: float = roundf(sin(a) * d + u * u * 8.0 - u * 5.0)
		var sz: float = 3.0 if (u < 0.35 and i % 2 == 0) else (2.0 if u < 0.7 else 1.0)
		var c: Color = (PAL["gold"] if i % 3 == 0 else (b_glow if i % 3 == 1 else PAL["dusk"])) as Color
		draw_rect(Rect2(px, py, sz, sz), c)
