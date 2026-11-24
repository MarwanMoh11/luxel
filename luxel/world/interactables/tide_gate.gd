class_name LxTideGate
extends LxInteractable
## Cyclic tidal boardwalk: rises and falls on a readable timer, exposing or flooding water tiles.

var period: float = 8.0
var phase_offset: float = 0.0
var low_ratio: float = 0.55
var warn_time: float = 1.2
var size: Vector2 = Vector2(32.0, 32.0)
var is_flooded: bool = false
var is_warning: bool = false
var _wave_stage: int = 0
var _low_remain_frac: float = 1.0
var _lit_runes: int = -1


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "tide_gate"
	period = maxf(2.0, float(props.get("period", 8.0)))
	phase_offset = float(props.get("phase_offset", 0.0))
	low_ratio = clampf(float(props.get("low_ratio", 0.55)), 0.2, 0.85)
	warn_time = maxf(0.2, float(props.get("warn_time", 1.2)))
	size = _parse_size(props.get("size", [32.0, 32.0]), Vector2(32.0, 32.0))
	radius = maxf(size.x, size.y) * 0.5
	_update_phase()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var prev_f: bool = is_flooded
	var prev_w: bool = is_warning
	_update_phase()
	if prev_f != is_flooded and Lx.player != null and is_instance_valid(Lx.player) and Lx.player is Node2D and (Lx.player as Node2D).global_position.distance_to(pos) <= 145.0:
		_emit_sfx("tide_surge")
		_emit_gust(48.0, 34.0)
		if Lx.world != null and is_instance_valid(Lx.world):
			var wfx: Variant = Lx.world.get("_water_fx")
			if wfx is Object and is_instance_valid(wfx) and (wfx as Object).has_method("spawn_ripple"):
				(wfx as Object).call("spawn_ripple", pos, "ice")
	var changed: bool = prev_f != is_flooded or prev_w != is_warning
	if not is_flooded:
		var rc: int = _rune_stone_count()
		var cur_lit: int = int(ceilf(_low_remain_frac * float(rc)))
		if cur_lit != _lit_runes:
			_lit_runes = cur_lit
			changed = true
	if is_flooded or is_warning:
		var ws: int = int(floorf(_clock * (5.0 if is_warning else 3.5))) % 4
		if ws != _wave_stage:
			_wave_stage = ws
			changed = true
	if changed:
		queue_redraw()


func _update_phase() -> void:
	var t: float = fposmod(_clock + phase_offset, period)
	var low_end: float = period * low_ratio
	is_flooded = t >= low_end
	_low_remain_frac = 0.0 if is_flooded else clampf((low_end - t) / maxf(0.01, low_end), 0.0, 1.0)
	is_warning = (not is_flooded and (low_end - t) <= warn_time) or (is_flooded and (period - t) <= warn_time)


func is_platform_solid() -> bool:
	return active and not is_flooded


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "clock": _clock}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	_clock = float(d.get("clock", _clock))
	_update_phase()
	queue_redraw()


func _rune_stone_count() -> int:
	return clampi(int(roundf(roundf(size.x) / 7.0)), 4, 6)


func _draw() -> void:
	# Flat water/pier pad — no drop shadow.
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var no_flash: bool = LxHudFx.flash_reduced()
	if is_flooded:
		_draw_puzzle_tiled("tide_closed", size, Vector2.ZERO, _clock, Color.WHITE, _wave_stage % 2)
		if is_warning:
			var foam_c: Color = (PAL["cream"] if (no_flash or _wave_stage % 2 == 0) else PAL["ice"]) as Color
			var fx: float = x0 + 2.0 + float(_wave_stage % 2)
			while fx < x0 + w - 2.0:
				draw_rect(Rect2(fx, y0 + 1.0, 2.0, 1.0), foam_c)
				draw_rect(Rect2(fx, y0 + h - 2.0, 2.0, 1.0), foam_c)
				fx += 6.0
		return
	_draw_puzzle_tiled("tide_open", size)
	# Diegetic glowing tide-rune stones embedded along the south pier timber rim
	var rc: int = _rune_stone_count()
	var lit_cnt: int = int(ceilf(_low_remain_frac * float(rc)))
	var span_w: float = maxf(8.0, w - 11.0)
	var ry: float = y0 + h - 4.0
	for i: int in range(rc):
		var t: float = float(i) / float(maxi(1, rc - 1))
		var rx: float = roundf(x0 + 4.0 + t * span_w)
		# Carved dark recessed rune bezel
		draw_rect(Rect2(rx, ry, 3.0, 3.0), PAL["void"] as Color)
		if i < lit_cnt:
			var warn_coral: bool = is_warning and (no_flash or (_wave_stage % 2 == 0))
			var rim_col: Color = (PAL["coral"] if warn_coral else (PAL["apricot"] if is_warning else PAL["blue"])) as Color
			var core_col: Color = (PAL["gold"] if warn_coral else (PAL["cream"] if not is_warning else PAL["ice"])) as Color
			draw_rect(Rect2(rx + 1.0, ry, 1.0, 2.0), rim_col)
			draw_rect(Rect2(rx, ry + 1.0, 3.0, 1.0), rim_col)
			draw_rect(Rect2(rx + 1.0, ry + 1.0, 1.0, 1.0), core_col)
		else:
			draw_rect(Rect2(rx + 1.0, ry + 1.0, 1.0, 1.0), PAL["deep"] as Color)
	if is_warning:
		var edge_c: Color = (PAL["sky"] if no_flash else (PAL["ice"] if _wave_stage % 2 == 0 else PAL["sky"])) as Color
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 3.0, 1.0), edge_c)
		draw_rect(Rect2(x0 + w - 4.0, y0 + 1.0, 3.0, 1.0), edge_c)
		draw_rect(Rect2(x0 + 1.0, y0 + h - 2.0, 3.0, 1.0), edge_c)
		draw_rect(Rect2(x0 + w - 4.0, y0 + h - 2.0, 3.0, 1.0), edge_c)
