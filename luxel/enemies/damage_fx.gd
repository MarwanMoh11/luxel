class_name LxDamageFx
extends RefCounted
## Death's Door-inspired progressive enemy wear, strained shield fissures,
## and non-blocking boss arena awakening entrance beats (strictly 20 Last Light colours).


static func _flash_reduced() -> bool:
	return Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))


static func draw_phase_sigil(enemy: LxEnemyBrain, off: Vector2) -> void:
	if enemy == null or not enemy.is_boss or enemy.phase < 2:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var r: float = enemy.body_radius
	var ph: int = enemy.phase
	var t: float = enemy.anim_t
	var fred: bool = _flash_reduced()
	var rx: float = r + 6.5
	var ry: float = rx * 0.48
	var base_y: float = r * 0.45
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var ring_col: Color = (pal["sky"] if ph >= 4 else (pal["coral"] if ph >= 3 else LxBiomePalette.col(isl, "hi"))) as Color
	var hi_col: Color = (pal["cream"] if ph >= 4 else (pal["gold"] if ph >= 3 else LxBiomePalette.col(isl, "glow"))) as Color
	var spin: float = t * (0.45 if fred else (0.75 + float(ph) * 0.25))
	# Pixel-snapped gothic ground rune dashes beneath the boss's feet
	var segs: int = 8 if ph == 2 else (10 if ph == 3 else 12)
	for si: int in range(segs):
		var a0: float = spin + float(si) * (TAU / float(segs))
		var p0: Vector2 = (off + Vector2(cos(a0) * rx, base_y + sin(a0) * ry)).round()
		var col_s: Color = hi_col if (ph >= 3 and si % 3 == 0) else ring_col
		enemy.draw_rect(Rect2(p0, Vector2(2.0 if si % 2 == 0 else 1.0, 1.0)), col_s)
	# Inner cardinal spokes for Phase 3 & 4 bosses
	if ph >= 3:
		for ci: int in range(4):
			var ca: float = -spin * 0.7 + float(ci) * (PI * 0.5)
			var cp: Vector2 = (off + Vector2(cos(ca) * (rx + 2.5), base_y + sin(ca) * (ry + 1.5))).round()
			enemy.draw_rect(Rect2(cp, Vector2(2.0, 2.0)), hi_col)
	# Orbiting phase motes
	var pn: int = mini(ph * 2, 8)
	var orb_spd: float = (1.1 if fred else (1.8 + float(ph) * 0.55))
	for pi: int in range(pn):
		var pa: float = t * orb_spd + float(pi) * (TAU / float(pn))
		var mp: Vector2 = (off + Vector2(cos(pa) * (r + 5.0), base_y + sin(pa) * (r * 0.48 + 2.0))).round()
		enemy.draw_rect(Rect2(mp, Vector2(2.0, 1.0)), hi_col if (pi % 2 == 0) else (pal["gold"] as Color))


static func draw_wear(enemy: LxEnemyBrain, off: Vector2) -> void:
	if enemy == null or enemy.state == LxEnemyBrain.State.DEAD:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var r: float = enemy.body_radius
	var t: float = enemy.anim_t
	var fred: bool = _flash_reduced()

	# 1. Boss Awakening Entrance Ring (0.55 s non-blocking gothic aura pulse)
	if enemy.awaken_t > 0.0:
		var prog: float = 1.0 - clampf(enemy.awaken_t / 0.55, 0.0, 1.0)
		var ease_p: float = 1.0 - pow(1.0 - prog, 2.0)
		var outer_r: float = lerpf(r + 3.0, r + 34.0, ease_p)
		var inner_r: float = lerpf(r + 1.0, r + 20.0, ease_p)
		var a_out: float = (1.0 - prog) * (0.55 if fred else 0.90)
		var isl_a: int = Lx.state.island_id if Lx.state != null else 1
		enemy.draw_arc(off, outer_r, 0.0, TAU, 24, Color(LxBiomePalette.col(isl_a, "glow"), a_out), 1.5)
		enemy.draw_arc(off, inner_r, 0.0, TAU, 18, Color(pal["cream"] as Color, a_out * 0.85), 1.0)
		for ci: int in range(4):
			var ang: float = float(ci) * (PI * 0.5) + prog * 0.45
			var p0: Vector2 = (off + Vector2.from_angle(ang) * (r + 4.0 + ease_p * 10.0)).round()
			var p1: Vector2 = (off + Vector2.from_angle(ang) * (r + 8.0 + ease_p * 16.0)).round()
			enemy.draw_line(p0, p1, Color(LxBiomePalette.col(isl_a, "hi"), a_out), 1.0)
			if enemy.is_boss and enemy.phase >= 2:
				var da: float = float(ci) * (PI * 0.5) + PI * 0.25 - prog * 0.35
				var q0: Vector2 = (off + Vector2.from_angle(da) * (r + 6.0 + ease_p * 14.0)).round()
				var q1: Vector2 = (off + Vector2.from_angle(da) * (r + 12.0 + ease_p * 22.0)).round()
				enemy.draw_line(q0, q1, Color(pal["gold"] as Color, a_out * 0.90), 1.2)

	if enemy.max_hp <= 0.01 or enemy.hp <= 0.0:
		return
	if enemy.alert_t > 0.0:
		_draw_alert_ring(enemy, off, r, fred)
	_draw_biome_aura(enemy, off, r, t, fred)
	if enemy.state == LxEnemyBrain.State.STAGGER:
		_draw_stagger_halo(enemy, off, r, t, fred)
	var hp_ratio: float = clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)

	# 2. Stage 1 Wear (<= 65% HP on bosses & heavy foes): subtle hairline fracture + drifting spark
	if hp_ratio <= 0.65 and (enemy.is_boss or enemy.max_hp >= 5.0):
		var c1: Vector2 = (off + Vector2(-r * 0.35, -r * 0.25)).round()
		enemy.draw_line(c1, c1 + Vector2(2.0, 3.0), pal["void"] as Color, 1.0)
		enemy.draw_rect(Rect2(c1 + Vector2(1.0, 1.0), Vector2.ONE), pal["apricot"] as Color)
		var dr: float = fmod(t * 1.4, 1.0)
		var sp1: Vector2 = (off + Vector2(sin(t * 2.3) * (r * 0.6), -r * 0.3 - dr * 7.0)).round()
		if dr < 0.72:
			enemy.draw_rect(Rect2(sp1, Vector2.ONE), pal["apricot"] as Color)

	# 3. Stage 2 Critical Wear (<= 35% HP on all foes): deep fracture + unstable coral embers
	if hp_ratio <= 0.35:
		var c2: Vector2 = (off + Vector2(r * 0.25, -r * 0.10)).round()
		enemy.draw_line(c2, c2 + Vector2(-3.0, 2.0), pal["night"] as Color, 1.0)
		enemy.draw_rect(Rect2(c2 + Vector2(-1.0, 1.0), Vector2.ONE), pal["coral"] as Color)
		var blink_ok: bool = fred or fmod(t * 3.5, 1.0) < 0.62
		if blink_ok:
			var ca: float = t * 4.2
			enemy.draw_rect(Rect2((off + Vector2(cos(ca) * (r + 1.0), -r * 0.4 + sin(ca * 1.3) * 3.0)).round(), Vector2(2.0, 1.0)), pal["coral"] as Color)
			enemy.draw_rect(Rect2((off + Vector2(-cos(ca * 0.9) * r, -r * 0.1 + cos(ca) * 2.5)).round(), Vector2.ONE), pal["apricot"] as Color)
		if enemy.is_boss:
			var pulse_a: float = 0.55 if fred else (0.38 + 0.34 * absf(sin(t * 5.2)))
			var bcol: Color = Color(pal["coral"] as Color, pulse_a)
			enemy.draw_arc(off, r + 4.0, t * 1.5, t * 1.5 + 1.15, 10, bcol, 1.0)
			enemy.draw_arc(off, r + 4.0, t * 1.5 + PI, t * 1.5 + PI + 1.15, 10, bcol, 1.0)


static func draw_shield_arc(enemy: LxEnemyBrain, off: Vector2, base_col: Color) -> void:
	if enemy == null:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var r: float = enemy.body_radius
	var rad: float = r + 3.0
	var sh_v: Variant = enemy.get("shield_hp")
	var sm_v: Variant = enemy.get("shield_max")
	var sfrac: float = 1.0
	if (sh_v is float or sh_v is int) and (sm_v is float or sm_v is int) and float(sm_v) > 0.01:
		sfrac = clampf(float(sh_v) / float(sm_v), 0.0, 1.0)

	var fred: bool = _flash_reduced()
	var col: Color = base_col
	if enemy.clank_t > 0.0:
		col = pal["cream"] as Color
	elif sfrac <= 0.45:
		if fred:
			col = pal["apricot"] as Color
		else:
			col = (pal["coral"] if int(enemy.anim_t * 10.0) % 2 == 0 else pal["apricot"]) as Color

	enemy.draw_arc(off, rad, enemy.facing - 1.05, enemy.facing + 1.05, 12, col, 2.5)

	# Visible hairline fractures across the shield as it wears down
	var isl_sh: int = Lx.state.island_id if Lx.state != null else 1
	if sfrac <= 0.65:
		var a0: float = enemy.facing - 0.25
		var p_in: Vector2 = (off + Vector2.from_angle(a0) * (rad - 1.5)).round()
		var p_out: Vector2 = (off + Vector2.from_angle(a0) * (rad + 2.0)).round()
		enemy.draw_line(p_in, p_out, pal["night"] as Color, 1.0)
		enemy.draw_rect(Rect2(p_out, Vector2.ONE), LxBiomePalette.col(isl_sh, "glow"))
	if sfrac <= 0.45:
		var a1: float = enemy.facing + 0.42
		var q_in: Vector2 = (off + Vector2.from_angle(a1) * (rad - 1.5)).round()
		var q_out: Vector2 = (off + Vector2.from_angle(a1) * (rad + 2.5)).round()
		enemy.draw_line(q_in, q_out, pal["void"] as Color, 1.0)
		enemy.draw_rect(Rect2(q_out, Vector2.ONE), pal["cream"] as Color)


static func trigger_boss_awaken(boss: LxEnemyBrain) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive():
		return
	if boss.has_meta("_lx_awakened"):
		return
	boss.set_meta("_lx_awakened", true)
	boss.awaken_t = 0.55
	if Lx.camera != null and is_instance_valid(Lx.camera):
		if Lx.camera.has_method("trigger_focus_nudge"):
			Lx.camera.call("trigger_focus_nudge", boss.pos, 0.55)
		Lx.camera.add_shake(0.20)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", boss.pos, 96.0, 95.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(boss.pos, 72.0, 1.35 * (0.62 if _flash_reduced() else 1.0), 0.55)
		LxDarknessLayer.active_instance.trigger_focus_flash(0.45)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("boss_awaken", boss.pos, true)


static func trigger_boss_phase_burst(boss_id: String, at_pos: Vector2) -> void:
	gust_arena(at_pos, 118.0, 125.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at_pos, 96.0, 0.85 if _flash_reduced() else 1.38, 0.46)
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"):
		return
	var enemies: Variant = Lx.world.call("get_enemies")
	if not (enemies is Array):
		return
	for e: Variant in (enemies as Array):
		if e is LxEnemyBrain and is_instance_valid(e):
			var b: LxEnemyBrain = e as LxEnemyBrain
			if b.is_alive() and (b.boss_id == boss_id or b.kind == boss_id or b.is_boss):
				b.awaken_t = 0.55
				break


static func gust_arena(at_pos: Vector2, radius: float, strength: float) -> void:
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", at_pos, radius, strength)


static func boss_impact(at_pos: Vector2, shake: float, gust_r: float, gust_s: float, light_r: float = 0.0, light_i: float = 1.38, light_dur: float = 0.38, ripple_col: String = "") -> void:
	if Lx.events != null and shake > 0.0:
		Lx.events.shake_requested.emit(shake)
	if gust_r > 0.0:
		gust_arena(at_pos, gust_r, gust_s)
	if light_r > 0.0 and LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var eff_i: float = light_i * (0.62 if _flash_reduced() else 1.0)
		LxDarknessLayer.active_instance.add_burst_light(at_pos, light_r, eff_i, light_dur)
	if not ripple_col.is_empty() and Lx.world != null and is_instance_valid(Lx.world):
		var wfx: Variant = Lx.world.get("_water_fx")
		if wfx is Object and is_instance_valid(wfx) and (wfx as Object).has_method("spawn_ripple"):
			(wfx as Object).call("spawn_ripple", at_pos, ripple_col)
	if shake >= 0.16 and LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		var isl_b: int = Lx.state.island_id if Lx.state != null else 1
		if isl_b in [2, 5, 7]:
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, at_pos, 15.0, 7.5)
		elif isl_b == 3:
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, at_pos, 15.0, 7.0)
		elif isl_b == 6:
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, at_pos, 14.0, 8.0)
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.SCORCH, at_pos, 16.0, 8.5)
		else:
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, at_pos, 14.0, 8.0)


static func draw_armour_plates(enemy: LxEnemyBrain, off: Vector2, ar: float, width: float, armour_hp: float, armour_max: float) -> void:
	if enemy == null:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var frac: float = clampf(armour_hp / maxf(armour_max, 0.01), 0.0, 1.0)
	var fred: bool = _flash_reduced()
	var plate_col: Color = pal["mauve"] as Color
	if enemy.clank_t > 0.0:
		plate_col = pal["cream"] as Color
	elif frac <= 0.45:
		if fred:
			plate_col = pal["apricot"] as Color
		else:
			plate_col = (pal["coral"] if int(enemy.anim_t * 10.0) % 2 == 0 else pal["apricot"]) as Color
	for i: int in range(4):
		var a: float = PI * 0.25 + float(i) * (PI * 0.5)
		enemy.draw_arc(off, ar, a - 0.38, a + 0.38, 4, plate_col, width)
		if frac <= 0.65:
			var p_in: Vector2 = (off + Vector2.from_angle(a) * (ar - 1.5)).round()
			var p_out: Vector2 = (off + Vector2.from_angle(a) * (ar + 1.8)).round()
			enemy.draw_line(p_in, p_out, pal["night"] as Color, 1.0)
			enemy.draw_rect(Rect2(p_out, Vector2.ONE), (pal["coral"] if frac <= 0.45 else pal["gold"]) as Color)
		if frac <= 0.45 and (i % 2 == 0):
			var sa: float = a + 0.22
			var sp: Vector2 = (off + Vector2.from_angle(sa) * (ar + 2.2)).round()
			enemy.draw_rect(Rect2(sp, Vector2.ONE), pal["cream"] as Color)


static func _draw_alert_ring(enemy: LxEnemyBrain, off: Vector2, r: float, fred: bool) -> void:
	var u: float = clampf(1.0 - (enemy.alert_t / 0.55), 0.0, 1.0)
	if u >= 0.98:
		return
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var ac: Color = LxBiomePalette.col(isl, "glow")
	var top: Vector2 = (off + Vector2(0.0, -r - 11.0)).round()
	var rad: float = roundf(lerpf(3.0, 11.0, u))
	var alpha: float = (1.0 - u) * (0.42 if fred else 0.72)
	enemy.draw_arc(top, rad, 0.0, TAU, 14, Color(ac, alpha), 1.0)


static func _draw_biome_aura(enemy: LxEnemyBrain, off: Vector2, r: float, t: float, fred: bool) -> void:
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var pal: Dictionary = LxEnemyBrain.PAL
	var ph: float = float(enemy.get_instance_id() & 63) * 0.17
	var u: float = fposmod(t * (0.45 if fred else 0.72) + ph, 1.0)
	match isl:
		2: # Tidewater sea-mist droplet near feet
			if u < 0.65:
				var px: float = roundf(off.x + sin(t * 2.1 + ph) * (r + 1.0))
				enemy.draw_rect(Rect2(px, roundf(off.y + r * 0.45 - u * 4.0), 1.0, 1.0), Color(pal["ice"] as Color, (1.0 - u / 0.65) * 0.62))
		3: # Thornwood emerald spore drifting upward
			var sx: float = roundf(off.x + sin(t * 2.4 + ph) * (r * 0.85))
			var sy: float = roundf(off.y - r * 0.2 - u * 9.0)
			enemy.draw_rect(Rect2(sx, sy, 1.0, 1.0), Color((pal["lime"] if u < 0.5 else pal["jade"]) as Color, sin(u * PI) * 0.75))
		4: # Mirefen rose-ice dew mote
			var mx: float = roundf(off.x + cos(t * 2.0 + ph) * (r + 1.5))
			var my: float = roundf(off.y - r * 0.1 - u * 7.0)
			enemy.draw_rect(Rect2(mx, my, 1.0, 1.0), Color((pal["rose"] if u < 0.5 else pal["ice"]) as Color, sin(u * PI) * 0.68))
		5: # Starfall tiny orbiting gold-sky starlight spark
			var ang: float = t * (1.2 if fred else 2.2) + ph
			var gx: float = roundf(off.x + cos(ang) * (r + 2.5))
			var gy: float = roundf(off.y - r * 0.35 + sin(ang) * 3.0)
			enemy.draw_rect(Rect2(gx, gy, 1.0, 1.0), Color((pal["gold"] if sin(ang) >= 0.0 else pal["sky"]) as Color, 0.72))
		6: # Ashen Kiln rising forge cinder
			var kx: float = roundf(off.x + sin(t * 3.0 + ph) * (r * 0.75))
			var ky: float = roundf(off.y - u * 11.0)
			enemy.draw_rect(Rect2(kx, ky, 1.0, 1.0), Color((pal["gold"] if u < 0.35 else pal["coral"]) as Color, (1.0 - u) * 0.80))
		7: # Moon Shoals crisp silver reflection bar beneath feet
			var rw: float = roundf(maxf(4.0, r * 1.1))
			enemy.draw_rect(Rect2(roundf(off.x - rw * 0.5), roundf(off.y + r * 0.75 + 2.0), rw, 1.0), Color(pal["ice"] as Color, 0.38))
		8: # Long Night dark plum/rose eclipse mote
			var ex: float = roundf(off.x + cos(t * 1.8 + ph) * (r + 2.0))
			var ey: float = roundf(off.y - r * 0.25 + sin(t * 2.4 + ph) * 3.5)
			enemy.draw_rect(Rect2(ex, ey, 1.0, 1.0), Color((pal["rose"] if u < 0.45 else pal["plum"]) as Color, 0.75))
		_:
			var bx: float = roundf(off.x + sin(t * 1.8 + ph) * (r + 1.5))
			var by: float = roundf(off.y - r * 0.2 - u * 8.0)
			var b1_col: Color = (pal["gold"] if (enemy.is_boss or enemy.max_hp >= 5.0) else pal["apricot"]) as Color
			enemy.draw_rect(Rect2(bx, by, 1.0, 1.0), Color(b1_col, sin(u * PI) * (0.60 if (enemy.is_boss or enemy.max_hp >= 5.0) else 0.42)))


static func _draw_stagger_halo(enemy: LxEnemyBrain, off: Vector2, r: float, t: float, fred: bool) -> void:
	var pal: Dictionary = LxEnemyBrain.PAL
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var bio_g: Color = LxBiomePalette.col(isl, "glow")
	var rx: float = r + 4.5
	var ry: float = rx * 0.48
	var by: float = r * 0.48
	var spin: float = t * (1.2 if fred else 3.4)
	for k: int in range(6):
		var a: float = spin + float(k) * (TAU / 6.0)
		var pt: Vector2 = (off + Vector2(cos(a) * rx, by + sin(a) * ry)).round()
		var col: Color = (pal["cream"] if (k % 3 == 0 and (fred or int(t * 8.0) % 2 == 0)) else (bio_g if k % 2 == 0 else (pal["gold"] as Color))) as Color
		enemy.draw_rect(Rect2(pt, Vector2(2.0, 1.0)), col)
	var top: Vector2 = (off + Vector2(0.0, -r - 8.0)).round()
	enemy.draw_rect(Rect2(top + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), bio_g)
	enemy.draw_rect(Rect2(top + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), bio_g)
	enemy.draw_rect(Rect2(top, Vector2.ONE), pal["cream"] as Color)
