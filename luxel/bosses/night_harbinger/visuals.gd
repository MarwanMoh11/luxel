extends RefCounted
## Custom draw layer for LxNightHarbingerBoss (strict 20-color Last Light palette).
## Draws lunar armour glint, gold punish crown, sound_off tell ring, P2 West Eclipse Brazier,
## stationary East Eclipse Mirror + shatter bloom, and Twin Blink-Cross echo tethers & arcs.

const PAL: Dictionary = LxPalette.PAL


static func draw_harbinger(b: LxNightHarbingerBoss, off: Vector2) -> void:
	var c: Vector2 = off.round()
	var sold_hf: bool = LxNightHarbingerBoss._is_setting_sold("hit_flash")
	if b.boss_state == LxBossBase.BossState.TELL and LxNightHarbingerBoss._is_setting_sold("sound_off"):
		b.draw_arc(c, b.body_radius + 7.5, 0.0, TAU, 20, PAL["cream"] as Color, 1.0)
	if b._armour_glint_t > 0.0 and b.boss_state != LxBossBase.BossState.DEATH:
		var ga: float = clampf(b._armour_glint_t / 0.22, 0.0, 1.0)
		var gc: Color = (PAL["gold"] if sold_hf else PAL["ice"]) as Color
		b.draw_arc(c, b.body_radius + 5.5, b._armour_glint_ang - 0.85, b._armour_glint_ang + 0.85, 10, Color(gc, ga), 2.0)
	elif b.is_punishable() and b.boss_state != LxBossBase.BossState.DEATH:
		b.draw_arc(c, b.body_radius + 5.0, 0.0, TAU, 20, PAL["gold"] as Color, 2.0)

	if b.phase >= 2 and b.boss_state != LxBossBase.BossState.DEATH:
		var bp: Vector2 = (b._west_brazier_pos - b.pos + off).round()
		b.draw_circle(bp, 7.0, PAL["night"] as Color)
		b.draw_arc(bp, 7.5, 0.0, TAU, 16, (PAL["plum"] if b._west_brazier_snuffed else PAL["gold"]) as Color, 1.0)
		if not b._west_brazier_snuffed:
			b.draw_circle(bp, 3.5, PAL["gold"] as Color)
			b.draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
		else:
			b.draw_arc(bp, 10.5, b.anim_t * 2.0, b.anim_t * 2.0 + PI, 10, PAL["coral"] as Color, 1.0)

	if b._mirror_active and b.boss_state != LxBossBase.BossState.DEATH:
		var mp: Vector2 = (b._mirror_pos - b.pos + off).round()
		b.draw_circle(mp, 8.0, PAL["void"] as Color)
		b.draw_arc(mp, 9.0, 0.0, TAU, 18, PAL["ice"] as Color, 2.0)
		_draw_eclipse_diamond(b, mp, 4.0, PAL["sky"] as Color, PAL["cream"] as Color)
		if b.boss_state == LxBossBase.BossState.TELL:
			b.draw_line(mp, (mp + b._mirror_dir * b.MIRROR_ARC_RANGE).round(), PAL["sky"] as Color, 1.0)
		elif b._mirror_firing and b._mirror_fire_t >= b.MIRROR_ARC_DELAY:
			var mprog: float = clampf((b._mirror_fire_t - b.MIRROR_ARC_DELAY) / b.MIRROR_ARC_DUR, 0.0, 1.0)
			var mac: Vector2 = (mp + b._mirror_dir * lerpf(8.0, b.MIRROR_ARC_RANGE, mprog)).round()
			var ma_m: float = b._mirror_dir.angle()
			b.draw_arc(mac, 13.0, ma_m - 1.0, ma_m + 1.0, 12, PAL["sky"] as Color, 3.0)
			b.draw_arc(mac, 11.0, ma_m - 0.85, ma_m + 0.85, 10, PAL["cream"] as Color, 1.0)

	if b._mirror_shatter_t > 0.0:
		var mp2: Vector2 = (b._mirror_pos - b.pos + off).round()
		var su: float = 1.0 - clampf(b._mirror_shatter_t / 0.65, 0.0, 1.0)
		b.draw_arc(mp2, lerpf(10.0, 42.0, su), 0.0, TAU, 20, Color(PAL["gold"] as Color, 1.0 - su), 2.0)

	if b.blink_slash_attack and b.boss_state == LxBossBase.BossState.TELL and b._feint_done:
		var ep: Vector2 = (b._echo_pos - b.pos + off).round()
		b.draw_line(ep, c, PAL["blue"] as Color, 1.0)
		b.draw_arc(ep, b.body_radius + 1.5, 0.0, TAU, 14, PAL["sky"] as Color, 1.0)
		_draw_eclipse_diamond(b, ep, 3.5, PAL["ice"] as Color, PAL["cream"] as Color)
	elif b.blink_slash_attack and b.boss_state == LxBossBase.BossState.COMMIT:
		var ep2: Vector2 = (b._echo_pos - b.pos + off).round()
		if b._commit_elapsed <= b.MAIN_SLASH_TIME:
			var p1: float = clampf(b._commit_elapsed / b.MAIN_SLASH_TIME, 0.0, 1.0)
			var ma: float = b._main_dir.angle()
			var a0: float = ma - b.MAIN_SLASH_ARC * 0.85
			var a1: float = lerpf(a0 + 0.35, ma + b.MAIN_SLASH_ARC * 0.85, p1)
			b.draw_arc(c, b.MAIN_SLASH_R, a0, a1, 16, PAL["coral"] as Color, 3.0)
			b.draw_arc(c, b.MAIN_SLASH_R - 2.5, a0, a1, 14, PAL["gold"] as Color, 2.0)
			b.draw_arc(ep2, b.body_radius + 3.0, 0.0, TAU, 14, PAL["ice"] as Color, 2.0)
		else:
			var e_prog: float = clampf((b._commit_elapsed - b.MAIN_SLASH_TIME) / b.ECHO_SLASH_TIME, 0.0, 1.0)
			var arc_c: Vector2 = (ep2 + b._echo_dir * lerpf(8.0, b.ECHO_CRESCENT_RANGE, e_prog)).round()
			var ea: float = b._echo_dir.angle()
			b.draw_line(ep2, arc_c, PAL["deep"] as Color, 2.0)
			b.draw_arc(arc_c, 15.0, ea - 1.15, ea + 1.15, 14, PAL["sky"] as Color, 3.0)
			b.draw_arc(arc_c, 13.0, ea - 1.0, ea + 1.0, 12, PAL["cream"] as Color, 1.0)
	elif b.boss_state == LxBossBase.BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(b.state_timer / maxf(b.phase_shift_duration, 0.05), 0.0, 1.0)
		var r1: float = b.body_radius + 11.0 + rp * 18.0
		b.draw_arc(c, r1, 0.0, TAU, 28, PAL["coral"] as Color, 2.0)
		b.draw_arc(c, maxf(5.0, r1 - 6.0), 0.0, TAU, 24, PAL["gold"] as Color, 2.0)


static func _draw_eclipse_diamond(b: CanvasItem, pt: Vector2, rad: float, outer: Color, inner: Color) -> void:
	var p: Vector2 = pt.round()
	b.draw_line(p + Vector2(0.0, -rad), p + Vector2(rad, 0.0), outer, 1.0)
	b.draw_line(p + Vector2(rad, 0.0), p + Vector2(0.0, rad), outer, 1.0)
	b.draw_line(p + Vector2(0.0, rad), p + Vector2(-rad, 0.0), outer, 1.0)
	b.draw_line(p + Vector2(-rad, 0.0), p + Vector2(0.0, -rad), outer, 1.0)
	b.draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), inner, true)
