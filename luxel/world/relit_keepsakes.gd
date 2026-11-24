class_name LxRelitKeepsakes
extends RefCounted
## Monumental Dawn Keepsakes & Okami-style Living World-Healing Keepsakes across Islands 1..8,
## plus Island 8's stained-glass rose-window diagonal light shafts scaling with Dawn Seals.
## Strictly uses the 20 Last Light colours (LxPalette.PAL); zero raw player-facing strings.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 200.0
const HALF_H: float = 128.0


static func draw_keepsake(ci: CanvasItem, island_id: int, door_pos: Vector2, clock: float, fred: bool) -> void:
	if ci == null:
		return
	var c: Vector2 = (door_pos + Vector2(0.0, -28.0)).round()
	var g: Color = LxBiomePalette.col(island_id, "glow")
	var hi: Color = LxBiomePalette.col(island_id, "hi")
	var cr: Color = PAL["cream"] as Color
	var gold: Color = PAL["gold"] as Color
	var pulse: float = 0.72 if fred else (0.64 + 0.36 * sin(clock * 2.4))
	match island_id:
		1: # Bell Isle: Restored Golden Belfry Carillon Arch + 3 swaying micro-bells
			ci.draw_arc(c + Vector2(0.0, 6.0), 18.0, PI * 1.12, PI * 1.88, 16, Color(gold, 0.78 * pulse), 1.5)
			ci.draw_arc(c + Vector2(0.0, 6.0), 15.0, PI * 1.16, PI * 1.84, 14, Color(cr, 0.55 * pulse), 1.0)
			for k: int in range(-1, 2):
				var sw: float = 0.0 if fred else roundf(sin(clock * 2.6 + float(k) * 1.1) * 1.2)
				var bp := (c + Vector2(float(k) * 10.0 + sw, -5.0 + absf(float(k)) * 3.0)).round()
				ci.draw_rect(Rect2(bp + Vector2(-2.0, 0.0), Vector2(4.0, 3.0)), gold)
				ci.draw_rect(Rect2(bp + Vector2(-1.0, 0.0), Vector2(2.0, 2.0)), cr)
				ci.draw_rect(Rect2(bp + Vector2(0.0, 3.0), Vector2.ONE), PAL["apricot"] as Color)
		2: # Tidewater Harbor: Twin Azure-Gold Triumph Pennants + Fresnel Sun-Crown
			for side: float in [-1.0, 1.0]:
				var px: float = c.x + side * 20.0
				ci.draw_line(Vector2(px, c.y + 10.0), Vector2(px, c.y - 8.0), PAL["apricot"] as Color, 1.0)
				ci.draw_rect(Rect2(px - 1.0, c.y - 9.0, 2.0, 2.0), gold)
				var wav: float = 0.0 if fred else roundf(sin(clock * 3.2 + side) * 1.5)
				var tip := Vector2(px + side * 9.0, c.y - 5.0 + wav)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px, c.y - 8.0), tip, Vector2(px, c.y - 2.0)]), Color(PAL["sky"] as Color, 0.82))
				ci.draw_line(Vector2(px, c.y - 5.0), tip, Color(gold, 0.85), 1.0)
			ci.draw_arc(c + Vector2(0.0, -4.0), 10.0, 0.0, TAU, 16, Color(gold, 0.65 * pulse), 1.2)
			ci.draw_rect(Rect2(c + Vector2(-1.0, -5.0), Vector2(2.0, 2.0)), cr)
		3: # Thornwood Hollow: Blooming Emerald-Gold Heartwood Dawn Canopy
			ci.draw_arc(c + Vector2(0.0, 8.0), 22.0, PI * 1.08, PI * 1.92, 18, Color(PAL["jade"] as Color, 0.72), 2.0)
			ci.draw_arc(c + Vector2(0.0, 8.0), 20.0, PI * 1.12, PI * 1.88, 16, Color(PAL["lime"] as Color, 0.82 * pulse), 1.0)
			for k: int in range(5):
				var ang: float = PI * 1.18 + float(k) * (PI * 0.64 / 4.0)
				var bob: float = 0.0 if fred else sin(clock * 2.4 + float(k)) * 1.0
				var lp: Vector2 = (c + Vector2(0.0, 8.0) + Vector2.from_angle(ang) * (21.0 + bob)).round()
				ci.draw_rect(Rect2(lp - Vector2.ONE, Vector2(3.0, 3.0)), gold if k % 2 == 0 else (PAL["lime"] as Color))
				ci.draw_rect(Rect2(lp, Vector2.ONE), cr)
		4: # Mirefen Gardens: Rotating 8-Petal Rose/Ice/Gold Stained-Glass Sun-Rosette
			var rot: float = 0.0 if fred else clock * 0.45
			ci.draw_arc(c + Vector2(0.0, -2.0), 13.0, 0.0, TAU, 20, Color(gold, 0.74 * pulse), 1.2)
			for k: int in range(8):
				var a: float = rot + float(k) * (TAU / 8.0)
				var p0: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(a) * 4.0).round()
				var p1: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(a) * 12.0).round()
				var pc: Color = (PAL["rose"] if k % 3 == 0 else (PAL["ice"] if k % 3 == 1 else gold)) as Color
				ci.draw_line(p0, p1, Color(pc, 0.82 * pulse), 1.4)
			ci.draw_circle(c + Vector2(0.0, -2.0), 2.5, cr)
		5: # Starfall Observatory: Illuminated Golden-Sky Zodiac Astrolabe Crown
			var r1: float = 0.0 if fred else clock * 0.65
			var r2: float = 0.0 if fred else -clock * 0.45
			ci.draw_arc(c + Vector2(0.0, -2.0), 15.0, r1, r1 + PI * 1.5, 18, Color(gold, 0.82 * pulse), 1.4)
			ci.draw_arc(c + Vector2(0.0, -2.0), 10.0, r2, r2 + PI * 1.5, 16, Color(PAL["sky"] as Color, 0.82 * pulse), 1.2)
			for k: int in range(6):
				var sa: float = r1 * 0.5 + float(k) * (TAU / 6.0)
				var sp: Vector2 = (c + Vector2(0.0, -2.0) + Vector2.from_angle(sa) * 15.0).round()
				ci.draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), cr if k % 2 == 0 else gold)
		6: # Ashen Kiln: Twin Tempered Phoenix Hearth Braziers + Crown Arch
			ci.draw_arc(c + Vector2(0.0, 6.0), 19.0, PI * 1.15, PI * 1.85, 16, Color(PAL["coral"] as Color, 0.70 * pulse), 1.2)
			for side: float in [-1.0, 1.0]:
				var bx: float = c.x + side * 18.0
				var fh: float = roundf(9.0 + (0.0 if fred else absf(sin(clock * 5.2 + side)) * 4.0))
				ci.draw_rect(Rect2(bx - 3.0, c.y + 4.0, 6.0, 3.0), PAL["apricot"] as Color)
				ci.draw_rect(Rect2(bx - 2.0, c.y + 4.0 - fh, 4.0, fh), PAL["coral"] as Color)
				ci.draw_rect(Rect2(bx - 1.0, c.y + 4.0 - fh * 0.72, 2.0, fh * 0.72), gold)
				ci.draw_rect(Rect2(bx, c.y + 3.0 - fh * 0.45, 1.0, fh * 0.45), cr)
		7: # Moon Shoals: Interlocking Silver-Ice & Dawn-Gold Twin Crescent Mirror Halos
			var cen := c + Vector2(0.0, -2.0)
			ci.draw_arc(cen + Vector2(-4.0, 0.0), 11.0, PI * 0.35, PI * 1.65, 16, Color(PAL["ice"] as Color, 0.84 * pulse), 1.6)
			ci.draw_arc(cen + Vector2(4.0, 0.0), 11.0, -PI * 0.65, PI * 0.65, 16, Color(gold, 0.84 * pulse), 1.6)
			ci.draw_line(cen + Vector2(0.0, -9.0), cen + Vector2(0.0, 9.0), Color(cr, 0.68 * pulse), 1.0)
			ci.draw_rect(Rect2(cen - Vector2.ONE, Vector2(2.0, 2.0)), cr)
		_: # The Long Night: Grand Cathedral Dawn Sun-Cross orbited by all 8 islands' biome stars!
			var cen8 := c + Vector2(0.0, -4.0)
			ci.draw_arc(cen8, 16.0, 0.0, TAU, 24, Color(gold, 0.78 * pulse), 1.4)
			for r_i: int in range(8):
				var ra: float = float(r_i) * (TAU / 8.0)
				var len_r: float = 15.0 if r_i % 2 == 0 else 10.0
				ci.draw_line(cen8, (cen8 + Vector2.from_angle(ra) * len_r).round(), Color(gold if r_i % 2 == 0 else cr, 0.82 * pulse), 1.4 if r_i % 2 == 0 else 1.0)
			var orb_rot: float = 0.0 if fred else clock * 0.55
			for isl_s: int in range(1, 9):
				var oa: float = orb_rot + float(isl_s - 1) * (TAU / 8.0)
				var op: Vector2 = (cen8 + Vector2.from_angle(oa) * 20.0).round()
				ci.draw_rect(Rect2(op - Vector2.ONE, Vector2(2.0, 2.0)), LxBiomePalette.col(isl_s, "glow"))
				ci.draw_rect(Rect2(op, Vector2.ONE), cr)
			ci.draw_circle(cen8, 3.0, cr)

	# Harmony Star crown & orbiting mastery sparks floating directly above the Keepsake when all discoveries are found!
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % island_id, false)):
		var hy: float = c.y - 24.0 + (0.0 if fred else roundf(sin(clock * 2.2) * 1.2))
		var hs := Vector2(c.x, hy).round()
		var h_rot: float = 0.0 if fred else clock * 1.1
		ci.draw_arc(hs, 6.0, h_rot, h_rot + PI * 1.35, 10, Color(g, 0.56 * pulse), 1.0)
		for hk: int in range(2):
			var ha: float = h_rot + float(hk) * PI
			var hp: Vector2 = (hs + Vector2(cos(ha) * 6.0, sin(ha) * 3.5)).round()
			ci.draw_rect(Rect2(hp, Vector2.ONE), Color(cr if hk == 0 else gold, 0.85))
		ci.draw_rect(Rect2(hs + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), g)
		ci.draw_rect(Rect2(hs + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), g)
		ci.draw_rect(Rect2(hs + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), hi)
		ci.draw_rect(Rect2(hs, Vector2.ONE), cr)
	# Post-game 8/8 True Dawn Chorus: revisiting any saved island crowns its Keepsake with gentle golden dawn motes!
	if Lx.state != null and Lx.state.relit_islands.size() >= 8 and island_id < 8:
		var dc_rot: float = 0.0 if fred else clock * 0.45
		for dk: int in range(4):
			var da: float = dc_rot + float(dk) * (PI * 0.5)
			var dp: Vector2 = (c + Vector2(cos(da) * 24.0, -2.0 + sin(da) * 10.0)).round()
			ci.draw_rect(Rect2(dp, Vector2(2.0 if dk % 2 == 0 else 1.0, 1.0)), Color(cr if dk % 2 == 0 else gold, 0.65 * pulse))


static func draw_living_world_keepsakes(
	ci: CanvasItem,
	island_id: int,
	spawn_pos: Vector2,
	landmark_pos: Vector2,
	door_pos: Vector2,
	cam_center: Vector2,
	clock: float,
	fred: bool
) -> void:
	if ci == null:
		return
	var relit: bool = Lx.state != null and Lx.state.relit_islands.has(island_id)
	# Island 8 (The Long Night): Stained-glass diagonal rose-window shaft at spawn & Sanctum scaling 0->1->2->3 + relit
	if island_id == 8:
		draw_island8_rose_shaft(ci, spawn_pos, landmark_pos, door_pos, cam_center, clock, fred, relit)
	if not relit:
		return
	var t: float = clock * (0.45 if fred else 1.0)
	var anchors: Array[Vector2] = [spawn_pos]
	if landmark_pos != Vector2.ZERO and landmark_pos.distance_squared_to(spawn_pos) > 4096.0:
		anchors.append(landmark_pos)
	for idx: int in range(anchors.size()):
		var anchor: Vector2 = anchors[idx]
		if not _in_view(anchor, cam_center, 44.0):
			continue
		var phase_off: float = float(idx) * 2.1
		match island_id:
			1: _draw_relit_bell_isle(ci, anchor, t, fred, phase_off)
			2: _draw_relit_salt_harbor(ci, anchor, t, fred, phase_off)
			3: _draw_relit_briar_hollow(ci, anchor, t, fred, phase_off)
			4: _draw_relit_lotus_conservatory(ci, anchor, t, fred, phase_off)
			5: _draw_relit_starlight_orrery(ci, anchor, t, fred, phase_off)
			6: _draw_relit_ash_kiln(ci, anchor, t, fred, phase_off)
			7: _draw_relit_mirror_spire(ci, anchor, t, fred, phase_off)
			8: _draw_relit_long_night_dawn(ci, anchor, t, fred, phase_off)
			_: pass


static func draw_island8_rose_shaft(
	ci: CanvasItem,
	spawn_pos: Vector2,
	landmark_pos: Vector2,
	door_pos: Vector2,
	cam_center: Vector2,
	clock: float,
	fred: bool,
	relit: bool
) -> void:
	var seals_b: int = LxBiomeMechanics.active_instance.dawn_seals_broken if (LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance)) else 0
	var stage: int = 4 if relit else clampi(seals_b, 0, 3)
	var t: float = clock * (0.45 if fred else 1.0)
	var a_mul: float = (0.76 if fred else 1.0) * (1.0 + float(stage) * 0.16)
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color

	# 1. Spawn medallion (~28 deg diagonal stained-glass rose-window light shafts grazing medallion & flagstones)
	if _in_view(spawn_pos, cam_center, 88.0):
		var sp: Vector2 = spawn_pos.round()
		var fr_m: float = 0.78 if fred else 1.0
		var st_m: float = 1.0 + float(stage) * 0.12
		# 3 crisp ~28 deg stained-glass pixel bands (rose, gold, cream) sweeping across (336, 1104) medallion & outer pavers
		_draw_stepped_diagonal_beam(ci, sp + Vector2(-74.0, -82.0), 148.0, 22.0, 0.5317, c_rose, c_gold, c_cr, clampf(0.18 * fr_m * st_m, 0.14, 0.32), clampf(0.22 * fr_m * st_m, 0.18, 0.38))
		_draw_stepped_diagonal_beam(ci, sp + Vector2(-44.0, -86.0), 156.0, 28.0, 0.5317, c_rose, c_gold, c_cr, clampf(0.20 * fr_m * st_m, 0.16, 0.36), clampf(0.26 * fr_m * st_m, 0.20, 0.42))
		_draw_stepped_diagonal_beam(ci, sp + Vector2(-10.0, -80.0), 144.0, 20.0, 0.5317, c_gold, c_cr, c_cr, clampf(0.18 * fr_m * st_m, 0.14, 0.32), clampf(0.24 * fr_m * st_m, 0.18, 0.40))
		# Dappled rose-gold stained-glass cathedral floor patches on surrounding flagstones (matching Island 4 craft)
		_draw_rose_floor_dapple(ci, sp, c_rose, c_gold, c_cr, fr_m * st_m)
		# Northward cathedral guiding ray from spawn medallion pointing north toward the Sanctum
		for k_n: int in range(11):
			var ny: float = sp.y - 12.0 - float(k_n) * 6.0
			var nu: float = 1.0 - float(k_n) / 11.0
			var nw: float = roundf(lerpf(12.0, 4.0, 1.0 - nu))
			ci.draw_rect(Rect2(roundf(sp.x - nw * 0.5), ny, nw, 4.0), Color(c_gold if stage >= 1 else c_rose, clampf((0.15 + 0.03 * float(stage)) * nu * fr_m, 0.04, 0.32)))
		# Progressive extra golden dawn shafts as Dawn Seals break (1 -> 2 -> 3 -> full relit dawn)
		if stage >= 1:
			_draw_stepped_diagonal_beam(ci, sp + Vector2(-14.0, -84.0), 118.0, 14.0, 0.5317, c_gold, c_cr, c_cr, 0.14 * a_mul, 0.18 * a_mul)
		if stage >= 2:
			_draw_stepped_diagonal_beam(ci, sp + Vector2(-64.0, -72.0), 112.0, 12.0, 0.5317, c_rose, c_gold, c_cr, 0.13 * a_mul, 0.17 * a_mul)
		if stage >= 3:
			_draw_stepped_diagonal_beam(ci, sp + Vector2(14.0, -82.0), 110.0, 13.0, 0.5317, c_gold, c_cr, c_cr, 0.15 * a_mul, 0.20 * a_mul)
		# Drifting stained-glass dust motes inside the rose-window shafts
		var mote_n: int = 8 + stage * 2
		for m: int in range(mote_n):
			var fm: float = float(m)
			var u: float = fposmod(t * (0.14 + float(m % 3) * 0.04) + fm * 0.27, 1.0)
			var dy: float = lerpf(-64.0, 38.0, u)
			var sway: float = 0.0 if fred else sin(t * 1.6 + fm * 1.9) * 3.0
			var mx: float = roundf(sp.x - 16.0 + dy * 0.5317 + float((m % 5) - 2) * 9.0 + sway)
			var my: float = roundf(sp.y + dy)
			var mc: Color = c_cr if (m % 3 == 0) else (c_gold if (m % 2 == 0 or stage >= 2) else c_rose)
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), Color(mc, 0.68 if fred else 0.86))

	# 2. Sanctum Cathedral shattered rose-window shafts (near door_pos) + landmark dawn chorus when seals broken / relit
	if stage >= 1 and _in_view(door_pos, cam_center, 110.0):
		var rw: Vector2 = (door_pos + Vector2(0.0, -88.0)).round()
		var shafts: int = mini(stage + 1, 4)
		for s: int in range(shafts):
			var ox: float = (float(s) - float(shafts - 1) * 0.5) * 18.0
			var sc1: Color = c_gold if (s % 2 == 0 or stage >= 3) else c_rose
			_draw_stepped_diagonal_beam(ci, rw + Vector2(ox - 16.0, 0.0), 116.0, 14.0, 0.42, sc1, c_gold, c_cr, 0.09 * a_mul, 0.12 * a_mul)

	if relit and landmark_pos != Vector2.ZERO and landmark_pos.distance_squared_to(spawn_pos) > 4096.0 and _in_view(landmark_pos, cam_center, 72.0):
		_draw_stepped_diagonal_beam(ci, landmark_pos.round() + Vector2(-34.0, -68.0), 106.0, 18.0, 0.5317, c_gold, c_cr, c_cr, 0.095 * a_mul, 0.115 * a_mul)


static func _draw_rose_floor_dapple(ci: CanvasItem, sp: Vector2, c_rose: Color, c_gold: Color, c_cr: Color, mul: float) -> void:
	var a_r: float = clampf(0.20 * mul, 0.14, 0.34)
	var a_g: float = clampf(0.24 * mul, 0.16, 0.38)
	var a_c: float = clampf(0.26 * mul, 0.18, 0.42)
	var patches: Array[Vector2] = [Vector2(-46.0, -8.0), Vector2(-24.0, 26.0), Vector2(18.0, 24.0), Vector2(44.0, -10.0), Vector2(-18.0, -34.0)]
	for idx: int in range(patches.size()):
		var o: Vector2 = (sp + patches[idx]).round()
		for row: int in range(4):
			var rx: float = o.x + float(row) * 2.0
			var ry: float = o.y + float(row) * 3.0
			ci.draw_rect(Rect2(rx - 7.0, ry, 5.0, 2.0), Color(c_rose, a_r))
			ci.draw_rect(Rect2(rx - 1.0, ry, 6.0, 2.0), Color(c_gold if idx % 2 == 0 else c_rose, a_g))
			ci.draw_rect(Rect2(rx + 6.0, ry, 3.0, 2.0), Color(c_cr if row == 1 or row == 2 else c_gold, a_c))


static func _draw_stepped_diagonal_beam(
	ci: CanvasItem,
	top_origin: Vector2,
	height_px: float,
	width_px: float,
	slope_dx_per_dy: float,
	col_outer: Color,
	col_inner: Color,
	col_core: Color,
	a_outer: float,
	a_inner: float
) -> void:
	# Strictly pixel-stepped world-anchored diagonal light shaft (zero blurry AA edges, zero sliding grid)
	var step_y: float = 4.0
	var dy: float = 0.0
	while dy < height_px:
		var u: float = dy / maxf(1.0, height_px)
		var env: float = sin(u * PI)
		if env > 0.06:
			var bx: float = roundf(top_origin.x + dy * slope_dx_per_dy)
			var by: float = roundf(top_origin.y + dy)
			var w_out: float = maxf(4.0, roundf(width_px * (0.78 + 0.36 * u)))
			var w_in: float = maxf(2.0, roundf(w_out * 0.52))
			ci.draw_rect(Rect2(bx - roundf(w_out * 0.5), by, w_out, step_y), Color(col_outer, a_outer * env))
			ci.draw_rect(Rect2(bx - roundf(w_in * 0.5), by, w_in, step_y), Color(col_inner, a_inner * env))
			if env > 0.35:
				ci.draw_rect(Rect2(bx, by, 1.0, step_y), Color(col_core, a_inner * 0.85 * env))
		dy += step_y


static func _draw_relit_bell_isle(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 1: Drifting warm gold/cream bell-blossom petals + subtle floating brass chime rings near spawn/landmark
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	for i: int in range(8):
		var fi: float = float(i)
		var u: float = fposmod(t * (0.16 + float(i % 3) * 0.04) + fi * 0.19 + ph, 1.0)
		var px: float = roundf(anchor.x - 56.0 + u * 112.0 + sin(t * 1.4 + fi * 2.1) * 5.0)
		var py: float = roundf(anchor.y - 34.0 + float((i * 19) % 64) + cos(t * 1.7 + fi) * 4.0)
		var env: float = sin(u * PI)
		if env > 0.08:
			var sz: Vector2 = Vector2(2.0, 1.0) if ((i + int(floorf(t * 2.0))) % 2 == 0) else Vector2(1.0, 2.0)
			var col: Color = c_cr if (i % 3 == 0) else (c_gold if (i % 3 == 1) else c_apr)
			ci.draw_rect(Rect2(px, py, sz.x, sz.y), Color(col, env * (0.70 if fred else 0.88)))
	# Subtle floating brass chime rings radiating softly above the anchor
	for r_i: int in range(2):
		var ru: float = fposmod(t * 0.28 + float(r_i) * 0.5 + ph, 1.0)
		var rad: float = roundf(lerpf(6.0, 22.0, ru))
		var ra: float = (1.0 - ru) * (0.30 if fred else 0.46)
		var rc: Vector2 = (anchor + Vector2(0.0, -18.0)).round()
		ci.draw_arc(rc, rad, PI * 1.15, PI * 1.85, 12, Color(c_gold if r_i == 0 else c_cr, ra), 1.0)


static func _draw_relit_salt_harbor(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 2: Sweeping warm golden lighthouse Fresnel beam edge grazing Harbor Quay + ice/cream water glints
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var sweep: float = 0.0 if fred else sin(t * 0.55 + ph) * 26.0
	var top_p: Vector2 = (anchor + Vector2(46.0 + sweep * 0.4, -70.0)).round()
	_draw_stepped_diagonal_beam(ci, top_p, 112.0, 24.0, -0.46, c_gold, c_cr, c_cr, 0.075 if fred else 0.11, 0.09 if fred else 0.13)
	for i: int in range(7):
		var fi: float = float(i)
		var sh: float = 0.72 if fred else maxf(0.0, sin(t * 2.4 + fi * 1.7 + ph))
		if sh > 0.25:
			var gx: float = roundf(anchor.x + float((i * 37) % 104) - 52.0 + sin(t + fi) * 2.0)
			var gy: float = roundf(anchor.y + float((i * 23) % 68) - 26.0)
			ci.draw_rect(Rect2(gx, gy, 3.0 if sh > 0.75 else 2.0, 1.0), Color(c_cr if sh > 0.78 else c_ice, sh * 0.76))


static func _draw_relit_briar_hollow(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 3: Gentle rising lime/cream bioluminescent fireflies drifting north along Thornwood Gate
	var c_lime: Color = PAL["lime"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_cr: Color = PAL["cream"] as Color
	for i: int in range(9):
		var fi: float = float(i)
		var u: float = fposmod(t * (0.18 + float(i % 3) * 0.04) + fi * 0.17 + ph, 1.0)
		var env: float = sin(u * PI)
		if env <= 0.06:
			continue
		var fx: float = roundf(anchor.x + float((i * 29) % 88) - 44.0 + sin(t * 1.9 + fi * 1.6) * 6.0)
		var fy: float = roundf(anchor.y + 42.0 - u * 96.0)
		var pulse: float = 0.75 if fred else (0.55 + 0.45 * sin(t * 3.4 + fi * 2.2))
		var a: float = env * pulse * 0.90
		if pulse > 0.74:
			ci.draw_rect(Rect2(fx - 1.0, fy, 3.0, 1.0), Color(c_jade if i % 2 == 0 else c_lime, a * 0.65))
			ci.draw_rect(Rect2(fx, fy - 1.0, 1.0, 3.0), Color(c_lime, a * 0.65))
		ci.draw_rect(Rect2(fx, fy, 1.0, 1.0), Color(c_cr if pulse > 0.62 else c_lime, a))


static func _draw_relit_lotus_conservatory(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 4: Warm glowing floating lotus blossoms + gentle drifting rose/ice conservatory petals
	var c_rose: Color = PAL["rose"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var lotus_offs: Array[Vector2] = [Vector2(-38.0, 20.0), Vector2(36.0, -14.0), Vector2(-24.0, -28.0)]
	for k: int in range(lotus_offs.size()):
		var bob: float = 0.0 if fred else roundf(sin(t * 1.5 + float(k) * 2.0 + ph) * 1.2)
		var lp: Vector2 = (anchor + lotus_offs[k] + Vector2(0.0, bob)).round()
		ci.draw_rect(Rect2(lp + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), Color(c_teal, 0.68))
		ci.draw_rect(Rect2(lp + Vector2(-3.0, -1.0), Vector2(2.0, 2.0)), Color(c_rose, 0.86))
		ci.draw_rect(Rect2(lp + Vector2(1.0, -1.0), Vector2(2.0, 2.0)), Color(c_rose, 0.86))
		ci.draw_rect(Rect2(lp + Vector2(-1.0, -2.0), Vector2(2.0, 2.0)), Color(c_gold, 0.90))
		ci.draw_rect(Rect2(lp + Vector2(0.0, -2.0), Vector2.ONE), c_cr)
	for i: int in range(7):
		var fi: float = float(i)
		var u: float = fposmod(t * 0.14 + fi * 0.21 + ph, 1.0)
		var env: float = sin(u * PI)
		if env > 0.08:
			var px: float = roundf(anchor.x - 48.0 + u * 96.0 + sin(t * 1.3 + fi) * 4.0)
			var py: float = roundf(anchor.y - 34.0 + u * 52.0 + float((i * 17) % 36) - 18.0)
			ci.draw_rect(Rect2(px, py, 2.0 if i % 2 == 0 else 1.0, 1.0), Color(c_rose if i % 2 == 0 else c_ice, env * 0.82))


static func _draw_relit_starlight_orrery(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 5: Rotating brass star-vane glints + warm golden constellation links above spawn astrolabe
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var cen: Vector2 = (anchor + Vector2(0.0, -24.0)).round()
	var rot: float = 0.0 if fred else t * 0.42 + ph
	var pts: Array[Vector2] = []
	for k: int in range(4):
		var a: float = rot + float(k) * (PI * 0.5)
		var r: float = 28.0 if k % 2 == 0 else 20.0
		pts.append((cen + Vector2(cos(a) * r, sin(a) * r * 0.58)).round())
	for k: int in range(4):
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[(k + 1) % 4]
		ci.draw_line(p0, p1, Color(c_gold, 0.28 if fred else 0.42), 1.0)
		# Brass star-vane glint at each orbital node
		ci.draw_rect(Rect2(p0 + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), Color(c_gold if k % 2 == 0 else c_sky, 0.72))
		ci.draw_rect(Rect2(p0 + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), Color(c_gold if k % 2 == 0 else c_sky, 0.72))
		ci.draw_rect(Rect2(p0, Vector2.ONE), c_cr)
	# Fine rotating brass cardinal vane ticks
	ci.draw_arc(cen, 14.0, rot, rot + PI * 1.15, 14, Color(c_gold, 0.36 if fred else 0.52), 1.0)


static func _draw_relit_ash_kiln(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 6: Rising warm gold/cream hearth-ember updrafts (replacing harsh smoke with warm forge-hearth light)
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	for i: int in range(10):
		var fi: float = float(i)
		var u: float = fposmod(t * (0.24 + float(i % 3) * 0.05) + fi * 0.16 + ph, 1.0)
		var env: float = sin(u * PI)
		if env <= 0.06:
			continue
		var ex: float = roundf(anchor.x + float((i * 27) % 92) - 46.0 + sin(t * 2.2 + fi * 1.8) * 5.0)
		var ey: float = roundf(anchor.y + 32.0 - u * 86.0)
		var col: Color = c_cr if u > 0.62 else (c_gold if u > 0.28 else c_apr)
		ci.draw_rect(Rect2(ex, ey, 1.0, 2.0 if u < 0.45 else 1.0), Color(col, env * (0.74 if fred else 0.92)))
		if u > 0.35 and i % 3 == 0:
			ci.draw_rect(Rect2(ex, ey + 2.0, 1.0, 2.0), Color(c_gold, env * 0.38))


static func _draw_relit_mirror_spire(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 7: Crisp diagonal prism rainbow glint (ice/gold/rose) refracting off foreground crystal obelisks
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var cols: Array[Color] = [c_ice, c_gold, c_rose]
	var pulse: float = 0.72 if fred else (0.58 + 0.42 * sin(t * 2.1 + ph))
	var ob_offs: Array[Vector2] = [Vector2(-34.0, -18.0), Vector2(36.0, -12.0)]
	for ob_i: int in range(ob_offs.size()):
		var orig: Vector2 = (anchor + ob_offs[ob_i]).round()
		var dir_x: float = 1.0 if ob_i == 0 else -1.0
		for b: int in range(3):
			var p0: Vector2 = orig + Vector2(0.0, float(b - 1) * 2.0)
			var p1: Vector2 = (p0 + Vector2(dir_x * 24.0, 14.0 + float(b - 1) * 2.0)).round()
			ci.draw_line(p0, p1, Color(cols[b], pulse * (0.34 if fred else 0.54)), 1.0)
		# Crisp 4-point prism refraction core star
		ci.draw_rect(Rect2(orig + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), Color(c_ice, pulse * 0.80))
		ci.draw_rect(Rect2(orig + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), Color(c_gold, pulse * 0.80))
		ci.draw_rect(Rect2(orig, Vector2.ONE), c_cr)


static func _draw_relit_long_night_dawn(ci: CanvasItem, anchor: Vector2, t: float, fred: bool, ph: float) -> void:
	# Isl 8: Ascending 8-biome dawn petals (one per saved island) + warm golden cathedral crown motes
	var c_gold: Color = PAL["gold"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var pulse: float = 0.72 if fred else (0.62 + 0.38 * sin(t * 2.0 + ph))
	# Ascending 8-biome celebration petals rising along the cathedral rose-window shafts
	for k: int in range(1, 9):
		if Lx.state != null and k < 8 and not Lx.state.relit_islands.has(k):
			continue
		var fk: float = float(k - 1)
		var u: float = fposmod(t * (0.16 + float(k % 3) * 0.03) + fk * 0.125 + ph, 1.0)
		var env: float = sin(u * PI)
		if env <= 0.08:
			continue
		var sway: float = 0.0 if fred else sin(t * 1.8 + fk * 1.7 + ph) * 5.0
		var px: float = roundf(anchor.x - 42.0 + fk * 12.0 + sway)
		var py: float = roundf(anchor.y + 34.0 - u * 92.0)
		var b_col: Color = LxBiomePalette.col(k, "glow")
		var p_a: float = env * (0.72 if fred else 0.92)
		var sz: Vector2 = Vector2(2.0, 1.0) if ((k + int(floorf(t * 2.0))) % 2 == 0) else Vector2(1.0, 2.0)
		ci.draw_rect(Rect2(px, py, sz.x, sz.y), Color(b_col, p_a))
		if env > 0.45:
			ci.draw_rect(Rect2(px, py, 1.0, 1.0), Color(c_cr, p_a * 0.78))
	# Warm golden cathedral crown motes drifting upward near the rose-window shafts
	for m: int in range(8):
		var fm: float = float(m)
		var mu: float = fposmod(t * (0.20 + float(m % 3) * 0.04) + fm * 0.17 + ph * 0.7, 1.0)
		var menv: float = sin(mu * PI)
		if menv <= 0.06:
			continue
		var mx: float = roundf(anchor.x + float((m * 29) % 84) - 42.0 + (0.0 if fred else sin(t * 1.5 + fm * 2.2) * 4.0))
		var my: float = roundf(anchor.y + 26.0 - mu * 84.0)
		var mc: Color = c_cr if (m % 3 == 0) else (c_gold if (m % 3 == 1) else c_rose)
		var ma: float = menv * (0.66 if fred else 0.88)
		ci.draw_rect(Rect2(mx, my, 1.0, 1.0), Color(mc, ma))
		if m % 2 == 0 and menv > 0.55:
			ci.draw_rect(Rect2(mx - 1.0, my, 3.0, 1.0), Color(c_gold, ma * 0.45))
			ci.draw_rect(Rect2(mx, my - 1.0, 1.0, 3.0), Color(c_gold, ma * 0.45))
	# Subtle golden dawn crown arc hovering above the shaft anchor
	var crown_c: Vector2 = (anchor + Vector2(0.0, -24.0)).round()
	ci.draw_arc(crown_c, 16.0, PI * 1.15, PI * 1.85, 14, Color(c_gold, (0.28 if fred else 0.44) * pulse), 1.0)
	ci.draw_rect(Rect2(crown_c + Vector2(-1.0, -16.0), Vector2(2.0, 1.0)), Color(c_cr, 0.75 * pulse))


static func _in_view(p: Vector2, cam_center: Vector2, pad: float = 0.0) -> bool:
	return absf(p.x - cam_center.x) <= (HALF_W + pad) and absf(p.y - cam_center.y) <= (HALF_H + pad)
