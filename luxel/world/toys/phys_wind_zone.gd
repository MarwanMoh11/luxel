class_name LxPhysWindZone
extends LxToy
## Rectangular directional wind/updraft zone registered with LxFields.
## Pushes bolts, lantern throws, curved beams, Wick, enemies, and blocks along `dir`.

var wind_dir: Vector2 = Vector2.RIGHT
var strength: float = 520.0
var _scroll: float = 0.0


func _toy_setup() -> void:
	kind = "wind_zone"
	size = _parse_size(props.get("size", [64.0, 40.0]), Vector2(64.0, 40.0))
	radius = maxf(size.x, size.y) * 0.5
	wind_dir = dir_vec("dir", Vector2.RIGHT)
	strength = maxf(0.0, float(props.get("strength", 520.0)))
	z_index = LxPhysDraw.floor_z(region, -4)
	LxFields.add(self)
	queue_redraw()


func _exit_tree() -> void:
	LxFields.remove(self)


func _effective_dir() -> Vector2:
	var sig_mode: String = str(props.get("on_signal", "flip")).strip_edges().to_lower()
	if powered and sig_mode == "flip":
		return -wind_dir
	return wind_dir


func _on_power_changed(_is_on: bool) -> void:
	var sig_mode: String = str(props.get("on_signal", "flip")).strip_edges().to_lower()
	if sig_mode == "toggle_active":
		active = not active
	_emit_sfx("gust_whoosh")
	queue_redraw()


func is_field_active() -> bool:
	return active and strength > 0.01


func field_accel(p: Vector2, what: String) -> Vector2:
	if not is_field_active():
		return Vector2.ZERO
	var rect := Rect2(pos - size * 0.5, size)
	if not rect.has_point(p):
		return Vector2.ZERO
	var what_mult: float = 1.0
	match what:
		"bolt", "beam":
			what_mult = 1.15
		"lantern":
			what_mult = 1.0
		"wick":
			what_mult = 0.28
		"enemy":
			what_mult = 0.35
		"block":
			what_mult = 0.45
	return _effective_dir() * (strength * what_mult)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var vis_spd: float = 28.0 if LxHudFx.flash_reduced() else 58.0
	_scroll = fposmod(_scroll + vis_spd * dt, 24.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	var d: Vector2 = _effective_dir()
	var c_wind: Color = biome("hi")
	var c_gust: Color = PAL["ice"] as Color
	# Subtle translucent wind volume frame + corner brackets
	draw_rect(r, Color(c_wind, 0.08))
	draw_rect(r, Color(c_wind, 0.28), false, 1.0)
	# Animated streaking gust ribbons moving along wind_dir
	var horiz: bool = absf(d.x) >= absf(d.y)
	if horiz:
		var sgn: float = 1.0 if d.x >= 0.0 else -1.0
		var y: float = r.position.y + 6.0
		var row_i: int = 0
		while y < r.end.y - 4.0:
			var x_off: float = fposmod(_scroll + float(row_i) * 9.0, 24.0)
			var x: float = r.position.x + (x_off if sgn > 0.0 else (24.0 - x_off))
			while x < r.end.x - 4.0:
				var seg_len: float = minf(10.0, r.end.x - x - 2.0)
				if seg_len >= 3.0:
					draw_line(Vector2(roundf(x), roundf(y)), Vector2(roundf(x + seg_len), roundf(y)), Color(c_gust if row_i % 2 == 0 else c_wind, 0.62), 1.0)
				x += 24.0
			y += 10.0
			row_i += 1
	else:
		var sgn_y: float = 1.0 if d.y >= 0.0 else -1.0
		var x: float = r.position.x + 6.0
		var col_i: int = 0
		while x < r.end.x - 4.0:
			var y_off: float = fposmod(_scroll + float(col_i) * 9.0, 24.0)
			var y: float = r.position.y + (y_off if sgn_y > 0.0 else (24.0 - y_off))
			while y < r.end.y - 4.0:
				var seg_len: float = minf(10.0, r.end.y - y - 2.0)
				if seg_len >= 3.0:
					draw_line(Vector2(roundf(x), roundf(y)), Vector2(roundf(x), roundf(y + seg_len)), Color(c_gust if col_i % 2 == 0 else c_wind, 0.62), 1.0)
				y += 24.0
			x += 10.0
			col_i += 1
	LxPhysDraw.draw_chevron(self, Vector2.ZERO, d, PAL["cream"] as Color, PAL["void"] as Color, 3.0)
