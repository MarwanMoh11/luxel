class_name LxPhantomPlatform
extends LxInteractable
## Hidden bridge/platform that turns solid and visible when illuminated with Lens unlocked.

var revealed: bool = false
var persist_grace: float = 0.25
var size: Vector2 = Vector2(32.0, 16.0)
var _reveal_left: float = 0.0
var _reveal_fx_t: float = 0.0
var _shimmer_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "phantom_platform"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	persist_grace = maxf(0.05, float(props.get("persist_grace", 0.25)))
	revealed = bool(props.get("revealed", false))
	queue_redraw()


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	var has_lens: bool = source == "lens" or Lx.state == null or Lx.state.has_move("lens")
	if not has_lens:
		return
	var was: bool = revealed
	revealed = true
	_reveal_left = persist_grace
	if not was:
		_reveal_fx_t = 0.24
		_emit_gust(48.0, 34.0)
		_emit_sfx("phantom_phase")
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var changed: bool = false
	if _reveal_fx_t > 0.0:
		_reveal_fx_t = maxf(0.0, _reveal_fx_t - dt)
		changed = true
	if revealed and _reveal_left > 0.0:
		var was_warn: bool = _reveal_left < 0.14
		_reveal_left -= dt
		if _reveal_left <= 0.0:
			revealed = false
			changed = true
		elif _reveal_left < 0.14 or was_warn:
			changed = true
	if active:
		var rate: float = 3.0 if revealed else 1.5
		var st: int = int(floorf(_clock * rate + absf(pos.x * 0.02 + pos.y * 0.03))) % 4
		if st != _shimmer_stage:
			_shimmer_stage = st
			changed = true
	if changed:
		queue_redraw()


func is_platform_solid() -> bool:
	return active and revealed


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if not revealed:
		return Vector4.ZERO
	var surge: float = (sin((1.0 - clampf(_reveal_fx_t / 0.24, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _reveal_fx_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y, 32.0 + surge * 24.0, 0.55 + surge * 0.35)


func save_state() -> Dictionary:
	return {"active": active, "revealed": revealed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	revealed = bool(d.get("revealed", revealed))
	if revealed:
		_reveal_left = persist_grace
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var b_dk: Color = LxBiomePalette.col(island_id, "ward_a")
	var b_md: Color = LxBiomePalette.col(island_id, "ward_b")
	var b_hi: Color = LxBiomePalette.col(island_id, "ward_hi")
	var b_glow: Color = LxBiomePalette.col(island_id, "glow")
	if revealed:
		draw_rect(Rect2(x0, y0 + 1.0, w, h), PAL["night"])
		draw_rect(Rect2(x0, y0, w, h), b_dk)
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["blue"] if island_id in [2, 5, 7] else b_dk)
		var tile_w: float = 8.0
		var tile_h: float = 8.0
		var ty: float = y0 + 1.0
		var row: int = 0
		while ty < y0 + h - 1.0:
			var th: float = minf(tile_h, y0 + h - 1.0 - ty)
			var tx: float = x0 + 1.0
			var col_i: int = 0
			while tx < x0 + w - 1.0:
				var tw: float = minf(tile_w, x0 + w - 1.0 - tx)
				draw_rect(Rect2(tx, ty, tw - 1.0, th - 1.0), b_md)
				draw_rect(Rect2(tx, ty, tw - 1.0, 1.0), b_hi)
				draw_rect(Rect2(tx, ty, 1.0, th - 1.0), b_hi)
				draw_rect(Rect2(tx + tw - 1.0, ty, 1.0, th), b_dk)
				draw_rect(Rect2(tx, ty + th - 1.0, tw, 1.0), b_dk)
				var cx: float = floorf(tx + (tw - 1.0) * 0.5)
				var cy: float = floorf(ty + (th - 1.0) * 0.5)
				draw_rect(Rect2(cx, cy - 1.0, 1.0, 3.0), b_hi)
				draw_rect(Rect2(cx - 1.0, cy, 3.0, 1.0), b_hi)
				if (row + col_i + _shimmer_stage) % 4 == 0:
					draw_rect(Rect2(cx, cy, 1.0, 1.0), PAL["cream"])
				tx += tile_w
				col_i += 1
			ty += tile_h
			row += 1
		var stars: Array[Vector2] = [
			Vector2(x0 + 1.0, y0 + 1.0), Vector2(x0 + w - 2.0, y0 + 1.0),
			Vector2(x0 + 1.0, y0 + h - 2.0), Vector2(x0 + w - 2.0, y0 + h - 2.0),
		]
		for si: int in range(stars.size()):
			var sp: Vector2 = stars[si]
			var bright: bool = (si + _shimmer_stage) % 2 == 0
			draw_rect(Rect2(sp.x - 1.0, sp.y, 3.0, 1.0), b_glow if bright else b_md)
			draw_rect(Rect2(sp.x, sp.y - 1.0, 1.0, 3.0), b_glow if bright else b_md)
			draw_rect(Rect2(sp.x, sp.y, 1.0, 1.0), PAL["cream"] if bright else b_glow)
		if _reveal_fx_t > 0.0:
			var ru: float = 1.0 - clampf(_reveal_fx_t / 0.24, 0.0, 1.0)
			draw_rect(Rect2(x0, y0, w, h), PAL["cream"] if _reveal_fx_t > 0.12 else b_glow, false, 1.0)
			draw_arc(Vector2.ZERO, roundf(lerpf(4.0, maxf(w, h) * 0.56, ru)), 0.0, TAU, 14, Color(PAL["cream"] if ru < 0.4 else b_glow, (1.0 - ru) * 0.85), 1.0)
		elif _reveal_left > 0.0 and _reveal_left < 0.14:
			var no_flash: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
			var warn_c: Color = (b_md if (no_flash or int(floorf(_clock * 24.0)) % 2 == 0) else b_dk)
			draw_rect(Rect2(x0, y0, w, h), warn_c, false, 1.0)
		return
	var br_c: Color = b_dk
	var tip_c: Color = b_md
	var near_player: bool = Lx.player != null and is_instance_valid(Lx.player) and Lx.player is Node2D and (Lx.player as Node2D).global_position.distance_squared_to(pos) < 3025.0
	if near_player:
		br_c = b_md
		tip_c = b_hi
	draw_rect(Rect2(x0, y0, 4.0, 1.0), br_c)
	draw_rect(Rect2(x0, y0, 1.0, 4.0), br_c)
	draw_rect(Rect2(x0 + w - 4.0, y0, 4.0, 1.0), br_c)
	draw_rect(Rect2(x0 + w - 1.0, y0, 1.0, 4.0), br_c)
	draw_rect(Rect2(x0, y0 + h - 1.0, 4.0, 1.0), br_c)
	draw_rect(Rect2(x0, y0 + h - 4.0, 1.0, 4.0), br_c)
	draw_rect(Rect2(x0 + w - 4.0, y0 + h - 1.0, 4.0, 1.0), br_c)
	draw_rect(Rect2(x0 + w - 1.0, y0 + h - 4.0, 1.0, 4.0), br_c)
	var glint_c: Color = (PAL["cream"] if near_player else b_hi) as Color
	draw_rect(Rect2(x0, y0, 1.0, 1.0), glint_c if _shimmer_stage == 0 else tip_c)
	draw_rect(Rect2(x0 + w - 1.0, y0, 1.0, 1.0), glint_c if (_shimmer_stage == 1 and near_player) else tip_c)
	draw_rect(Rect2(x0, y0 + h - 1.0, 1.0, 1.0), glint_c if (_shimmer_stage == 2 and near_player) else tip_c)
	draw_rect(Rect2(x0 + w - 1.0, y0 + h - 1.0, 1.0, 1.0), glint_c if (_shimmer_stage == 3 and near_player) else tip_c)
	var m1x: float = floorf(-w * 0.18)
	var m1y: float = floorf(-h * 0.12)
	var m2x: float = floorf(w * 0.18)
	var m2y: float = floorf(h * 0.12)
	draw_rect(Rect2(m1x, m1y, 1.0, 1.0), (b_hi if near_player else b_md) if _shimmer_stage % 2 == 0 else br_c)
	draw_rect(Rect2(m2x, m2y, 1.0, 1.0), br_c if _shimmer_stage % 2 == 0 else (b_hi if near_player else b_md))
