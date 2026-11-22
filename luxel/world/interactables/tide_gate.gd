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
var _bar_px: int = -1


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
		var cur_px: int = int(floorf(maxf(0.0, roundf(size.x) - 8.0) * _low_remain_frac))
		if cur_px != _bar_px:
			_bar_px = cur_px
			changed = true
	if is_flooded or is_warning:
		var ws: int = int(floorf(_clock * (5.0 if is_warning else 2.5))) % 4
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


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	if is_flooded:
		draw_rect(Rect2(x0, y0, w, h), PAL["deep"])
		draw_rect(Rect2(x0 + 2.0, y0 + 1.0, w - 4.0, h - 2.0), PAL["blue"])
		var crest_c: Color = (PAL["cream"] if (is_warning and _wave_stage % 2 == 0) else PAL["ice"]) as Color
		var wy: float = y0 + 3.0 + float(_wave_stage % 2)
		var idx: int = 0
		while wy < y0 + h - 3.0:
			var shift: float = float(((_wave_stage + idx) % 3) - 1)
			draw_rect(Rect2(x0 + 5.0 + shift, wy, maxf(4.0, w - 11.0), 1.0), PAL["sky"])
			if idx % 2 == 0 or is_warning:
				draw_rect(Rect2(x0 + 7.0 + shift, wy, maxf(3.0, w - 16.0), 1.0), crest_c)
			wy += 5.0
			idx += 1
		var jw: float = minf(4.0, floorf(w * 0.2))
		for jx: float in [x0, x0 + w - jw]:
			draw_rect(Rect2(jx, y0, jw, h), PAL["void"])
			draw_rect(Rect2(jx + 1.0, y0 + 1.0, jw - 2.0, h - 2.0), PAL["night"])
			draw_rect(Rect2(jx + 1.0, y0 + 1.0, jw - 2.0, h - 3.0), PAL["dusk"])
			draw_rect(Rect2(jx + 1.0, y0 + 1.0, jw - 2.0, 1.0), PAL["stone"])
			draw_rect(Rect2(jx + 1.0, y0 + 3.0, 1.0, 2.0), PAL["apricot"])
			draw_rect(Rect2(jx + 1.0, y0 + h - 5.0, 1.0, 2.0), PAL["apricot"])
		return
	draw_rect(Rect2(x0, y0 + 1.0, w, h), PAL["void"])
	draw_rect(Rect2(x0, y0, w, h), PAL["void"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), PAL["pine"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 2.0), PAL["teal"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["stone"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 1.0, h - 4.0), PAL["teal"])
	var gx: float = x0 + 5.0
	var gi: int = 0
	while gx <= x0 + w - 6.0:
		draw_rect(Rect2(gx, y0 + 4.0, 2.0, h - 8.0), PAL["void"])
		draw_rect(Rect2(gx + 2.0, y0 + 4.0, 1.0, h - 8.0), PAL["teal"])
		var glow: bool = is_warning and ((gi + _wave_stage) % 2 == 0)
		var bar_c: Color = (PAL["ice"] if glow else PAL["sky"]) as Color
		draw_rect(Rect2(gx, y0 + 5.0, 1.0, maxf(2.0, h - 10.0)), bar_c if is_warning else PAL["deep"])
		gx += 4.0
		gi += 1
	var mid_y: float = floorf(y0 + h * 0.5)
	draw_rect(Rect2(x0 + 3.0, mid_y - 1.0, w - 6.0, 2.0), PAL["night"])
	var no_flash: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var bar_w: float = floorf(maxf(0.0, w - 8.0) * _low_remain_frac)
	if bar_w > 0.0:
		var bar_col: Color = (PAL["apricot"] if (is_warning and no_flash) else (PAL["coral"] if (is_warning and _wave_stage % 2 == 0) else (PAL["ice"] if is_warning else PAL["sky"]))) as Color
		draw_rect(Rect2(x0 + 4.0, mid_y - 1.0, bar_w, 1.0), bar_col)
	var bolts: Array[Vector2] = [
		Vector2(x0 + 2.0, y0 + 2.0), Vector2(x0 + w - 4.0, y0 + 2.0),
		Vector2(x0 + 2.0, y0 + h - 4.0), Vector2(x0 + w - 4.0, y0 + h - 4.0),
	]
	for bp: Vector2 in bolts:
		draw_rect(Rect2(bp, Vector2(2.0, 2.0)), PAL["apricot"])
		draw_rect(Rect2(bp, Vector2(1.0, 1.0)), PAL["gold"])
	if is_warning:
		var rim_c: Color = (PAL["sky"] if no_flash else (PAL["ice"] if _wave_stage % 2 == 0 else PAL["sky"])) as Color
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), rim_c, false, 1.0)
