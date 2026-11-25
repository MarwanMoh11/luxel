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
	var perp := Vector2(-d.y, d.x)
	var c_wind: Color = biome("hi")
	var c_gust: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_void: Color = PAL["void"] as Color
	var c_leaf_a: Color = PAL["lime"] as Color if island_id in [0, 1, 3, 4] else biome("glow")
	var c_leaf_b: Color = PAL["apricot"] as Color if island_id in [2, 4, 6] else c_wind
	var fred: bool = LxHudFx.flash_reduced()
	var horiz: bool = absf(d.x) >= absf(d.y)
	var span_along: float = maxf(16.0, size.x if horiz else size.y)
	var span_cross: float = maxf(14.0, size.y if horiz else size.x)
	var lane_count: int = clampi(int(roundf(span_cross / 11.0)), 2, 5)
	var wave_amp: float = 1.2 if fred else 2.2

	# 1. Upwind origin breeze tufts (subtle grounded source ticks, NO box fill!)
	var upwind_center: Vector2 = -d * (span_along * 0.5 - 2.0)
	for ti: int in range(lane_count):
		var frac: float = (float(ti) + 0.5) / float(lane_count) - 0.5
		var tp: Vector2 = (upwind_center + perp * (frac * (span_cross - 6.0))).round()
		draw_rect(Rect2(tp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_void)
		draw_rect(Rect2(tp, Vector2(1.0, 1.0)), c_sky if ti % 2 == 0 else c_wind)

	# 2. Drifting layered wind ribbon streaks with curled eddies (bounded <= 10 ribbons)
	var rib_cycle: float = span_along + 14.0
	for li: int in range(lane_count):
		var cross_f: float = (float(li) + 0.5) / float(lane_count) - 0.5
		var cross_off: float = cross_f * (span_cross - 8.0)
		var per_lane: int = 2 if span_along >= 42.0 else 1
		for ri: int in range(per_lane):
			var seed_o: float = float(li * 17 + ri * 29)
			var u_px: float = fposmod(_scroll * 2.2 + seed_o, rib_cycle) - 7.0
			var head_s: float = -span_along * 0.5 + u_px
			var seg_len: float = 12.0 if (li + ri) % 2 == 0 else 9.0
			var tail_s: float = maxf(-span_along * 0.5 + 2.0, head_s - seg_len)
			var clamp_head: float = minf(span_along * 0.5 - 2.0, head_s)
			if clamp_head - tail_s < 4.0:
				continue
			var rib_col: Color = c_gust if (li + ri) % 2 == 0 else c_sky
			var steps: int = 4
			var prev_p: Vector2 = Vector2.ZERO
			for si: int in range(steps + 1):
				var t: float = float(si) / float(steps)
				var s_cur: float = lerpf(tail_s, clamp_head, t)
				var wob: float = sin(s_cur * 0.24 + float(li) * 1.7 + (_clock * 2.5 if not fred else 0.0)) * wave_amp
				var pt: Vector2 = (d * s_cur + perp * (cross_off + wob)).round()
				if si > 0:
					draw_line(prev_p, pt, c_void, 2.0)
					draw_line(prev_p, pt, rib_col if si < steps else c_cream, 1.0)
				prev_p = pt
			# Trailing eddy curl pixel at ribbon tail
			var curl_dir: float = 1.0 if (li % 2 == 0) else -1.0
			var tail_wob: float = sin(tail_s * 0.24 + float(li) * 1.7) * wave_amp
			var curl_p: Vector2 = (d * (tail_s - 1.0) + perp * (cross_off + tail_wob + curl_dir * 2.0)).round()
			draw_rect(Rect2(curl_p, Vector2(1.0, 1.0)), c_wind)

	# 3. Drifting leaves / petals carried by the wind (bounded <= 6 leaves)
	var leaf_n: int = clampi(int(roundf((span_along * span_cross) / 260.0)), 3, 6)
	for k: int in range(leaf_n):
		var lu: float = fposmod(_scroll * 1.85 + float(k) * (span_along / float(leaf_n)) * 1.37, span_along - 6.0)
		var ls: float = -span_along * 0.5 + 3.0 + lu
		var lc_base: float = (float(k % 3) - 1.0) * (span_cross * 0.28)
		var lc: float = lc_base + sin(_clock * (1.8 if fred else 4.2) + float(k) * 2.1) * (2.0 if fred else 3.2)
		var lp: Vector2 = (d * ls + perp * lc).round()
		var leaf_c: Color = c_leaf_a if k % 2 == 0 else c_leaf_b
		var flip: bool = int(floorf(_clock * (2.0 if fred else 5.0) + float(k))) % 2 == 0
		draw_rect(Rect2(lp - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), c_void)
		if flip:
			draw_rect(Rect2(lp + Vector2(-1.0, 0.0), Vector2(2.0, 1.0)), leaf_c)
			draw_rect(Rect2(lp + Vector2(0.0, -1.0), Vector2(1.0, 1.0)), c_cream)
		else:
			draw_rect(Rect2(lp + Vector2(0.0, -1.0), Vector2(1.0, 2.0)), leaf_c)
			draw_rect(Rect2(lp + Vector2(-1.0, 0.0), Vector2(1.0, 1.0)), c_cream)

	# 4. Crisp central flow chevron so direction reads instantly even in stills
	LxPhysDraw.draw_chevron(self, Vector2.ZERO, d, c_cream, c_void, 3.0)
	LxPhysDraw.draw_chevron(self, -d * 4.0, d, c_gust, c_void, 2.0)
