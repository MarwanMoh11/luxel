class_name LxHeronAbbessVisuals
extends RefCounted
## Drawing helpers for Heron Abbess (wing gust, shockwaves, gale-leap, P2+ shattered skylights).

const PAL: Dictionary = LxPalette.PAL


static func draw_extra(b: LxHeronAbbessBoss, off: Vector2) -> void:
	if b.abbess_z > 0.5:
		var sh_sc: float = clampf(1.0 - b.abbess_z / 30.0, 0.32, 1.0)
		var sh_rx: float = maxf(2.5, b.body_radius * 1.15 * sh_sc)
		var sh_ry: float = maxf(1.4, b.body_radius * 0.50 * sh_sc)
		var sh_outer := PackedVector2Array()
		var sh_inner := PackedVector2Array()
		for si: int in range(12):
			var sa: float = (TAU * float(si)) / 12.0
			sh_outer.append(Vector2(roundf(cos(sa) * sh_rx), roundf(sin(sa) * sh_ry)))
			sh_inner.append(Vector2(roundf(cos(sa) * sh_rx * 0.62), roundf(sin(sa) * sh_ry * 0.62)))
		b.draw_colored_polygon(sh_outer, Color(PAL["void"] as Color, 0.64))
		b.draw_colored_polygon(sh_inner, Color(PAL["void"] as Color, 0.88))

	if b._sprite_sheet == null:
		var top: Vector2 = off + Vector2(0.0, -b.body_radius - 6.0)
		b.draw_line(top + Vector2(-4.0, 2.0), top + Vector2(0.0, -4.0), PAL["gold"] as Color, 1.8)
		b.draw_line(top + Vector2(4.0, 2.0), top + Vector2(0.0, -4.0), PAL["gold"] as Color, 1.8)

	if b.active_move == LxHeronAbbessBoss.BossMove.WING_GUST and b.state == LxEnemyBrain.State.TELL:
		var side: Vector2 = Vector2(-b.gust_dir.y, b.gust_dir.x)
		var g_prog: float = 1.0 - clampf(b.state_timer / maxf(b.last_tell_duration, 0.05), 0.0, 1.0)
		var dmg_pt: Vector2 = off + b.gust_dir * LxHeronAbbessBoss.GUST_DMG_R
		var end_pt: Vector2 = off + b.gust_dir * LxHeronAbbessBoss.GUST_RANGE
		LxBossTelegraphFx.draw_ground_danger_lane(b, dmg_pt, end_pt, LxHeronAbbessBoss.GUST_HALF_W, g_prog, b.anim_t, "sky", "ice")
		LxBossTelegraphFx.draw_ground_danger_lane(b, off, dmg_pt, LxHeronAbbessBoss.GUST_HALF_W, g_prog, b.anim_t, "coral", "gold")
		var pull_d: float = lerpf(44.0, 10.0, g_prog)
		b.draw_line((off + b.gust_dir * pull_d - side * 12.0).round(), (off + b.gust_dir * (pull_d - 6.0)).round(), PAL["ice"] as Color, 1.2)
		b.draw_line((off + b.gust_dir * pull_d + side * 12.0).round(), (off + b.gust_dir * (pull_d - 6.0)).round(), PAL["ice"] as Color, 1.2)
	elif b.active_move == LxHeronAbbessBoss.BossMove.WING_GUST and b.state == LxEnemyBrain.State.COMMIT:
		_draw_gust_commit(b, off)
	elif b.active_move == LxHeronAbbessBoss.BossMove.SHOCKWAVE_RING and b.state == LxEnemyBrain.State.TELL:
		var prog: float = 1.0 - clampf(b.state_timer / maxf(b.last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(b, off, LxHeronAbbessBoss.RING_MAX_R, prog, b.anim_t, "sky", "coral")
	elif b.active_move == LxHeronAbbessBoss.BossMove.SHOCKWAVE_RING and b.state == LxEnemyBrain.State.COMMIT:
		var ring_r: float = lerpf(LxHeronAbbessBoss.RING_START_R, LxHeronAbbessBoss.RING_MAX_R, b.ring_progress)
		_draw_ring(b, off, ring_r, true)
	elif b.active_move == LxHeronAbbessBoss.BossMove.GALE_LEAP and b.state == LxEnemyBrain.State.TELL:
		var rel: Vector2 = (b.leap_to - b.pos).round()
		var l_urg: float = 1.0 - clampf(b.state_timer / maxf(b.last_tell_duration, 0.05), 0.0, 1.0)
		var col_l: Color = (PAL["gold"] if b.state_timer <= 0.18 else PAL["sky"]) as Color
		LxBossTelegraphFx.draw_ground_danger_ring(b, rel, LxHeronAbbessBoss.LEAP_RING_MAX_R, l_urg * 0.72, b.anim_t, "sky", "gold")
		LxBossTelegraphFx.draw_ground_danger_ring(b, rel, 16.0, l_urg, b.anim_t, "coral", "gold")
		for bi: int in range(1, 6):
			var t: float = float(bi) / 6.0
			var bp: Vector2 = (off.lerp(rel, t) + Vector2(0.0, -sin(t * PI) * 18.0)).round()
			b.draw_circle(bp, 1.6, col_l)
			b.draw_circle(bp, 0.8, PAL["cream"] as Color)
	elif b.active_move == LxHeronAbbessBoss.BossMove.GALE_LEAP and b.state == LxEnemyBrain.State.COMMIT and b.leap_stage == 0:
		var rel_air: Vector2 = (b.leap_to - b.pos).round()
		var air_u: float = 1.0 - clampf(b.state_timer / maxf(LxHeronAbbessBoss.LEAP_AIR_TIME, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(b, rel_air, LxHeronAbbessBoss.LEAP_RING_MAX_R, lerpf(0.72, 1.0, air_u), b.anim_t, "sky", "coral")
		LxBossTelegraphFx.draw_ground_danger_ring(b, rel_air, 16.0, lerpf(0.78, 1.0, air_u), b.anim_t, "coral", "gold")
		b.draw_line(off.round(), rel_air, Color(PAL["ice"] as Color, 0.45), 1.1)
	elif b.active_move == LxHeronAbbessBoss.BossMove.GALE_LEAP and b.state == LxEnemyBrain.State.COMMIT and b.leap_stage == 1:
		var ring_r2: float = lerpf(LxHeronAbbessBoss.RING_START_R, LxHeronAbbessBoss.LEAP_RING_MAX_R, b.ring_progress)
		_draw_ring(b, Vector2.ZERO, ring_r2, false)
	elif b._roaring:
		var rp: float = 1.0 - clampf(b.state_timer / LxHeronAbbessBoss.ROAR_TIME, 0.0, 1.0)
		var rr: float = b.body_radius + 10.0 + rp * 16.0
		b.draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["sky"] as Color, 1.8)
		b.draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.2)

	if b.phase >= 2:
		for sk: Dictionary in b._skylights:
			var sp: Vector2 = ((sk["pos"] as Vector2) - b.pos).round()
			if bool(sk["shattered"]):
				b.draw_arc(sp, LxHeronAbbessBoss.SKYLIGHT_UPDRAFT_R, 0.0, TAU, 18, Color(PAL["sky"] as Color, 0.45), 1.0)
				b.draw_arc(sp, LxHeronAbbessBoss.SKYLIGHT_UPDRAFT_R - 5.0, b.anim_t * 3.8, b.anim_t * 3.8 + PI * 1.1, 12, Color(PAL["ice"] as Color, 0.80), 1.3)
				b.draw_circle(sp, 3.0, PAL["cream"] as Color)
			else:
				b.draw_rect(Rect2(sp + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), Color(PAL["ice"] as Color, 0.25))
				b.draw_rect(Rect2(sp + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), PAL["gold"] as Color, false, 1.2)


static func _draw_ring(b: LxHeronAbbessBoss, center: Vector2, ring_r: float, trail: bool) -> void:
	b.draw_arc(center, ring_r + 2.8, 0.0, TAU, 36, PAL["blue"] as Color, 2.2)
	b.draw_arc(center, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
	b.draw_arc(center, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
	b.draw_arc(center, maxf(2.0, ring_r - 4.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.1)
	if trail and ring_r > 16.0:
		b.draw_arc(center, ring_r - 8.5, 0.0, TAU, 24, PAL["blue"] as Color, 1.1)


static func _draw_gust_commit(b: LxHeronAbbessBoss, off: Vector2) -> void:
	var perp: Vector2 = Vector2(-b.gust_dir.y, b.gust_dir.x)
	var fred_g: bool = LxHudFx.flash_reduced()
	var g_start: Vector2 = off
	var g_end: Vector2 = off + b.gust_dir * LxHeronAbbessBoss.GUST_RANGE
	var outer_w: Vector2 = perp * LxHeronAbbessBoss.GUST_HALF_W
	var inner_w: Vector2 = perp * (LxHeronAbbessBoss.GUST_HALF_W * 0.45)
	b.draw_colored_polygon(PackedVector2Array([
		(g_start - outer_w).round(), (g_end - outer_w).round(),
		(g_end + outer_w).round(), (g_start + outer_w).round(),
	]), Color(PAL["sky"] as Color, 0.16 if fred_g else 0.22))
	b.draw_colored_polygon(PackedVector2Array([
		(g_start - inner_w).round(), (g_end - inner_w).round(),
		(g_end + inner_w).round(), (g_start + inner_w).round(),
	]), Color(PAL["ice"] as Color, 0.16 if fred_g else 0.26))
	var g_len: float = LxHeronAbbessBoss.GUST_RANGE * 0.92
	for idx: int in range(-1, 2):
		var s_off: Vector2 = perp * float(idx) * (LxHeronAbbessBoss.GUST_HALF_W * 0.50)
		var l_end: float = g_len if idx == 0 else g_len * 0.88
		var p0: Vector2 = (off + s_off).round()
		var p1: Vector2 = (off + s_off + b.gust_dir * l_end).round()
		b.draw_line(p0, p1, Color(PAL["sky"] as Color, 0.70 if fred_g else 0.90), 2.4 if idx == 0 else 1.6)
		b.draw_line(p0, p1, Color((PAL["cream"] if idx == 0 else PAL["ice"]) as Color, 0.75 if fred_g else 0.95), 1.2 if idx == 0 else 1.0)
	for ci: int in range(4):
		var ct: float = fposmod(b.anim_t * 4.6 + float(ci) * 0.25, 1.0)
		var dist_c: float = lerpf(12.0, g_len, ct)
		var span: float = lerpf(LxHeronAbbessBoss.GUST_HALF_W * 0.42, LxHeronAbbessBoss.GUST_HALF_W * 0.90, ct)
		var tip: Vector2 = (off + b.gust_dir * dist_c).round()
		b.draw_line((off + b.gust_dir * (dist_c - 10.0) - perp * span).round(), tip, Color(PAL["sky"] as Color, 0.72 if fred_g else 0.92), 2.0)
		b.draw_line((off + b.gust_dir * (dist_c - 10.0) + perp * span).round(), tip, Color(PAL["sky"] as Color, 0.72 if fred_g else 0.92), 2.0)
	for k: int in range(8):
		var s_len: float = 8.0 + float((k * 5) % 7)
		var prog_k: float = fposmod(b.anim_t * 220.0 + float(k) * 29.0, LxHeronAbbessBoss.GUST_RANGE)
		var lat_off: Vector2 = perp * (LxHeronAbbessBoss.GUST_HALF_W * (-0.85 + 1.70 * (float((k * 3 + 1) % 8) / 7.0)))
		var head_p: Vector2 = (g_start + lat_off + b.gust_dir * prog_k).round()
		var tail_p: Vector2 = (g_start + lat_off + b.gust_dir * maxf(0.0, prog_k - s_len)).round()
		b.draw_line(tail_p, head_p, Color((PAL["cream"] if k % 2 == 0 else PAL["ice"]) as Color, 0.72 if fred_g else 0.92), 1.0)
		if k % 2 == 0:
			b.draw_rect(Rect2(head_p - Vector2.ONE, Vector2(2.0, 2.0)), (PAL["rose"] if (k % 4 == 0) else PAL["cream"]) as Color)
