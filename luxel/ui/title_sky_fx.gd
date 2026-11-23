class_name LxTitleSkyFx
extends RefCounted
## Atmospheric pixel accents for the Title Screen sky & archipelago:
## periodic shooting star across the twilight sky & sweeping western lighthouse beam cone.
## Strictly uses LxPalette.PAL (20 opaque Last Light colours).


static func draw_sky_accents(ci: CanvasItem, elapsed: float) -> void:
	var fred: bool = LxHudFx.flash_reduced()

	# 0. Subtle etched twilight constellations in the far-left & far-right upper sky
	_draw_sky_constellations(ci, elapsed, fred)

	# 1. Two serene gliding twilight bird silhouettes crossing the upper moonlit sky
	for bi: int in range(2):
		var bx: float = roundf(fmod(42.0 + float(bi) * 148.0 + elapsed * (5.2 + float(bi) * 1.4), 344.0) - 12.0)
		var by: float = roundf(26.0 + float(bi) * 16.0 + sin(elapsed * 1.4 + float(bi) * 2.1) * 2.5)
		var flap: float = 0.0 if fred else (-1.0 if fmod(elapsed * 2.2 + float(bi) * 0.45, 1.0) < 0.5 else 1.0)
		ci.draw_rect(Rect2(bx, by, 1.0, 1.0), LxPalette.PAL["night"])
		ci.draw_rect(Rect2(bx - 1.0, by + flap, 1.0, 1.0), LxPalette.PAL["dusk"])
		ci.draw_rect(Rect2(bx + 1.0, by + flap, 1.0, 1.0), LxPalette.PAL["dusk"])

	# 1. Serene shooting star sweeping diagonally across upper sky every 7.4 s
	var cycle: float = fmod(elapsed + 2.8, 7.4)
	if cycle < 0.78:
		var u: float = cycle / 0.78
		var head := Vector2(lerpf(218.0, 128.0, u), lerpf(12.0, 44.0, u)).round()
		var dir := Vector2(90.0, -32.0).normalized()
		var tail_len: float = (12.0 if fred else 18.0) * sin(u * PI)
		if tail_len >= 2.0:
			var mid: Vector2 = (head + dir * (tail_len * 0.45)).round()
			var tip: Vector2 = (head + dir * tail_len).round()
			ci.draw_line(mid, tip, LxPalette.PAL["blue"], 1.0)
			ci.draw_line(head, mid, LxPalette.PAL["sky"], 1.0)
			ci.draw_rect(Rect2(head, Vector2.ONE), LxPalette.PAL["cream"])
			if u > 0.25 and u < 0.72:
				ci.draw_rect(Rect2(head + Vector2(-1.0, 0.0), Vector2.ONE), LxPalette.PAL["ice"])
				ci.draw_rect(Rect2(head + Vector2(0.0, 1.0), Vector2.ONE), LxPalette.PAL["ice"])

	# 2. Sweeping western lighthouse beacon cone (x=38, y=117) pulsing in sync with lh_p
	var lh_p: float = 0.5 + 0.5 * sin(elapsed * 1.9)
	if lh_p > 0.36:
		var reach: float = roundf(lerpf(10.0, 46.0 if not fred else 28.0, (lh_p - 0.36) / 0.64))
		var alpha: float = (0.14 if fred else 0.22) * ((lh_p - 0.36) / 0.64)
		var beam_col := Color(LxPalette.PAL["gold"], alpha)
		var core_col := Color(LxPalette.PAL["cream"], alpha * 1.15)
		var step_x: float = 4.0
		while step_x < reach:
			var frac: float = step_x / maxf(reach, 1.0)
			var half_h: float = roundf(1.0 + frac * 5.0)
			ci.draw_rect(Rect2(39.0 + step_x, 117.0 - half_h, 4.0, half_h * 2.0 + 1.0), beam_col)
			if frac < 0.55:
				ci.draw_rect(Rect2(39.0 + step_x, 117.0, 4.0, 1.0), core_col)
			step_x += 4.0

	# 3. Gentle drifting coastal twilight mist wisps along the dark horizon sea
	for mi: int in range(5):
		var mw: float = 22.0 + float(mi % 3) * 10.0
		var mspd: float = (2.4 if fred else 4.2) + float(mi % 2) * 1.4
		var mx: float = roundf(fmod(float(mi) * 71.0 + elapsed * mspd, 356.0) - 24.0)
		var my: float = 144.0 + float(mi % 3) * 2.0
		ci.draw_rect(Rect2(mx, my, mw, 1.0), Color(LxPalette.PAL["dusk"], 0.34 if fred else 0.44))
		ci.draw_rect(Rect2(mx + 4.0, my, mw - 8.0, 1.0), Color(LxPalette.PAL["mauve"], 0.22 if fred else 0.30))

	# 4. Living Horizon Progress: light tiny golden Great Lamp beacons on the Title archipelago
	#    for every island relit across save slots (and a serene dawn rim at 8/8).
	_draw_relit_horizon(ci, elapsed, fred)


static func _draw_relit_horizon(ci: CanvasItem, elapsed: float, fred: bool) -> void:
	var sums: Variant = ci.get("_summaries")
	if not (sums is Array):
		return
	var relit: Dictionary = {}
	var harmony: Dictionary = {}
	for s: Variant in (sums as Array):
		if s is Dictionary and not bool((s as Dictionary).get("empty", true)):
			var arr: Variant = (s as Dictionary).get("relit_islands", [])
			if arr is Array:
				for iid: Variant in (arr as Array):
					relit[int(iid)] = true
			var harr: Variant = (s as Dictionary).get("harmony_islands", [])
			if harr is Array:
				for hid: Variant in (harr as Array):
					harmony[int(hid)] = true
	if relit.is_empty() and harmony.is_empty():
		return
	# Subtle horizon beacon coordinates across the archipelago skyline (Islands 1..8)
	var pts: Array[Vector2] = [
		Vector2(263.0, 84.0),  # 1 Bell Isle belfry spire
		Vector2(37.0, 112.0),  # 2 Tidewater Lighthouse
		Vector2(66.0, 141.0),  # 3 Thornwood Hollow
		Vector2(126.0, 142.0), # 4 Mirefen Gardens
		Vector2(93.0, 127.0),  # 5 Starfall Observatory dome
		Vector2(188.0, 142.0), # 6 Ashen Kiln
		Vector2(214.0, 140.0), # 7 Moon Shoals
		Vector2(158.0, 142.0), # 8 The Long Night
	]
	if relit.size() >= 8:
		var glow_a: float = 0.22 if fred else 0.30
		ci.draw_rect(Rect2(0.0, 141.0, 320.0, 2.0), Color(LxPalette.PAL["coral"], glow_a * 0.55))
		ci.draw_rect(Rect2(0.0, 143.0, 320.0, 2.0), Color(LxPalette.PAL["apricot"], glow_a * 0.78))
		ci.draw_rect(Rect2(0.0, 145.0, 320.0, 1.0), Color(LxPalette.PAL["gold"], 0.35 if fred else 0.50))
	for i: int in range(pts.size()):
		var isl_i: int = i + 1
		var is_relit: bool = relit.has(isl_i)
		var is_harm: bool = harmony.has(isl_i)
		if not is_relit and not is_harm:
			continue
		var p: Vector2 = pts[i]
		var tw: float = 0.85 if fred else (0.72 + 0.28 * sin(elapsed * 2.2 + float(i) * 1.1))
		var bh: float = roundf(6.0 + 3.0 * tw)
		var b_glow: Color = LxBiomePalette.col(isl_i, "glow")
		var b_hi: Color = LxBiomePalette.col(isl_i, "hi")
		if is_relit:
			ci.draw_rect(Rect2(p.x, p.y - bh, 1.0, bh), Color(b_glow, 0.34 * tw))
			ci.draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(b_hi, 0.72 * tw))
			ci.draw_rect(Rect2(p, Vector2.ONE), Color(LxPalette.PAL["cream"], 0.95))
			var rx: float = roundf(p.x + (0.0 if fred else sin(elapsed * 2.4 + float(i)) * 1.0))
			ci.draw_rect(Rect2(rx - 1.0, 148.0 + float(i % 3) * 2.0, 3.0, 1.0), Color(b_glow, 0.42 * tw))
			# Shimmering 3-step biome reflection ripple down the dark archipelago sea
			for rw: int in range(3):
				var wy: float = 151.0 + float(rw) * 3.0 + float(i % 2)
				var wx: float = roundf(p.x + (0.0 if fred else sin(elapsed * 1.9 + float(i) * 1.3 + float(rw) * 1.7) * (1.2 + float(rw) * 0.5)))
				var ww: float = 3.0 - float(rw) * 0.5
				ci.draw_rect(Rect2(wx - 1.0, wy, maxf(1.0, roundf(ww)), 1.0), Color(b_hi if rw == 2 else b_glow, (0.34 - float(rw) * 0.08) * tw))
			# Subtle biome-signature horizon whisper for each relit island
			if not fred:
				var wu: float = fposmod(elapsed * 0.45 + float(i) * 0.27, 1.0)
				match isl_i:
					3: # Rising emerald firefly above Thornwood
						ci.draw_rect(Rect2(roundf(p.x + sin(elapsed * 2.0) * 3.0), roundf(p.y - 4.0 - wu * 9.0), 1.0, 1.0), Color(LxPalette.PAL["lime"], sin(wu * PI) * 0.85))
					4: # Rose-ice conservatory sparkle above Mirefen
						ci.draw_rect(Rect2(roundf(p.x + cos(elapsed * 1.8) * 3.0), roundf(p.y - 5.0 - wu * 7.0), 1.0, 1.0), Color(LxPalette.PAL["rose"], sin(wu * PI) * 0.85))
					5: # Orbiting gold starlet around Observatory dome
						ci.draw_rect(Rect2(roundf(p.x + cos(elapsed * 1.6) * 5.0), roundf(p.y - 6.0 + sin(elapsed * 1.6) * 2.0), 1.0, 1.0), Color(LxPalette.PAL["gold"], 0.85))
					6: # Rising warm hearth ember over Ashen Kiln
						ci.draw_rect(Rect2(roundf(p.x + sin(elapsed * 2.6) * 2.0), roundf(p.y - 3.0 - wu * 10.0), 1.0, 1.0), Color(LxPalette.PAL["apricot"], sin(wu * PI) * 0.85))
					7: # Tiny silver-gold lunar aurora shimmer over Moon Shoals
						ci.draw_line(Vector2(roundf(p.x - 4.0), roundf(p.y - 9.0)), Vector2(roundf(p.x + 4.0), roundf(p.y - 9.0)), Color(LxPalette.PAL["ice"], 0.45 * tw), 1.0)
					8: # Radiant dawn crest sparks above The Long Night
						for dk: int in [-1, 1]:
							ci.draw_rect(Rect2(roundf(p.x + float(dk) * (3.0 + wu * 4.0)), roundf(p.y - 6.0 - wu * 8.0), 1.0, 1.0), Color(LxPalette.PAL["gold"], sin(wu * PI) * 0.85))
		if is_harm:
			var sc := Vector2(p.x, p.y - (bh + 5.0 if is_relit else 6.0)).round()
			ci.draw_rect(Rect2(sc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(b_glow, 0.82 * tw))
			ci.draw_rect(Rect2(sc + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(b_glow, 0.82 * tw))
			ci.draw_rect(Rect2(sc, Vector2.ONE), Color(LxPalette.PAL["cream"], 0.96))
	# Rising biome-tinted edge fireflies along the far left/right sky margins for saved islands
	if not fred and not relit.is_empty():
		var relit_ids: Array = relit.keys()
		relit_ids.sort()
		var n_ff: int = mini(relit_ids.size(), 6)
		for fi: int in range(n_ff):
			var iid: int = int(relit_ids[fi])
			var u: float = fposmod(elapsed * 0.16 + float(fi) * 0.19, 1.0)
			var on_right: bool = (fi % 2 == 1)
			var base_x: float = (294.0 + float(fi % 3) * 6.0) if on_right else (12.0 + float(fi % 3) * 6.0)
			var fx: float = roundf(base_x + sin(elapsed * 1.4 + float(fi) * 2.1) * 3.0)
			var fy: float = roundf(138.0 - u * 86.0)
			var fa: float = sin(u * PI) * 0.72
			if fa > 0.05:
				ci.draw_rect(Rect2(fx, fy, 1.0, 1.0), Color(LxBiomePalette.col(iid, "glow"), fa))
	# 8/8 Harmony Mastery serene North Star halo crowning the upper center sky
	if harmony.size() >= 8:
		var ns := Vector2(160.0, 8.0)
		var nt: float = 0.88 if fred else (0.76 + 0.24 * sin(elapsed * 1.9))
		ci.draw_line(ns + Vector2(-4.0, 0.0), ns + Vector2(4.0, 0.0), Color(LxPalette.PAL["gold"] as Color, 0.58 * nt), 1.0)
		ci.draw_line(ns + Vector2(0.0, -3.0), ns + Vector2(0.0, 3.0), Color(LxPalette.PAL["gold"] as Color, 0.58 * nt), 1.0)
		ci.draw_rect(Rect2(ns - Vector2(1.0, 0.0), Vector2(3.0, 1.0)), Color(LxPalette.PAL["cream"] as Color, nt))
		ci.draw_rect(Rect2(ns - Vector2(0.0, 1.0), Vector2(1.0, 3.0)), Color(LxPalette.PAL["cream"] as Color, nt))


static func _draw_sky_constellations(ci: CanvasItem, elapsed: float, fred: bool) -> void:
	# Left sky: The Lantern Bearer constellation; Right sky: The Great Bell constellation
	var figs: Array = [
		[Vector2(24.0, 22.0), Vector2(36.0, 15.0), Vector2(49.0, 23.0), Vector2(36.0, 34.0), Vector2(24.0, 22.0)],
		[Vector2(284.0, 56.0), Vector2(296.0, 46.0), Vector2(307.0, 56.0), Vector2(303.0, 68.0), Vector2(288.0, 68.0), Vector2(284.0, 56.0)],
	]
	var line_a: float = 0.14 if fred else (0.13 + 0.05 * sin(elapsed * 1.1))
	for fi: int in range(figs.size()):
		var pts: Array = figs[fi] as Array
		var lc: Color = Color(LxPalette.PAL["blue"] if fi == 0 else LxPalette.PAL["dusk"], line_a)
		for k: int in range(pts.size() - 1):
			ci.draw_line(pts[k] as Vector2, pts[k + 1] as Vector2, lc, 1.0)
		for k: int in range(pts.size() - 1):
			var sp: Vector2 = pts[k] as Vector2
			var tw: float = 0.72 if fred else (0.52 + 0.42 * sin(elapsed * 1.8 + float(fi) * 2.3 + float(k) * 1.2))
			var sc: Color = LxPalette.PAL["gold"] if (fi == 0 and k == 3) else (LxPalette.PAL["ice"] if k % 2 == 0 else LxPalette.PAL["sky"])
			ci.draw_rect(Rect2(sp, Vector2.ONE), Color(sc, tw))
