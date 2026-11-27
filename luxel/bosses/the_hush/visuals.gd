extends RefCounted
## Combat VFX & 20-colour Last Light spellcraft for LxTheHushBoss (LxBossBase).
## Renders all 4 dual-island arena layers, silence & light weapons, armour glint vs punish crown,
## Veil & 8-island stagger orbit, Comeback Beat golden bloom, closing dark band & Beauty Toll Sparks.


static func _draw_diamond(b: LxEnemyBrain, p: Vector2, rad: float, outer: Color, inner: Color) -> void:
	var c: Vector2 = p.round()
	var r: float = roundf(rad)
	b.draw_line(c + Vector2(0.0, -r), c + Vector2(r, 0.0), outer, 1.0)
	b.draw_line(c + Vector2(r, 0.0), c + Vector2(0.0, r), outer, 1.0)
	b.draw_line(c + Vector2(0.0, r), c + Vector2(-r, 0.0), outer, 1.0)
	b.draw_line(c + Vector2(-r, 0.0), c + Vector2(0.0, -r), outer, 1.0)
	b.draw_rect(Rect2(c - Vector2.ONE, Vector2(2.0, 2.0)), inner, true)


static func _draw_star_flare(b: LxEnemyBrain, p: Vector2, rad: float, outer: Color, core: Color) -> void:
	var c: Vector2 = p.round()
	var r: float = roundf(rad)
	var diag: float = roundf(r * 0.45)
	b.draw_line(c + Vector2(-r, 0.0), c + Vector2(r, 0.0), outer, 2.0)
	b.draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), outer, 2.0)
	b.draw_line(c + Vector2(-diag, -diag), c + Vector2(diag, diag), outer, 1.0)
	b.draw_line(c + Vector2(-diag, diag), c + Vector2(diag, -diag), outer, 1.0)
	b.draw_circle(c, 2.0, core)


static func draw_hush(b: LxBossBase, off: Vector2) -> void:
	var pal: Dictionary = LxEnemyBrain.PAL
	var fred: bool = b.is_flash_reduced()
	var phase: int = b.phase
	var r: float = b.body_radius
	var has_sprite: bool = b._sprite_sheet != null
	var c: Vector2 = off.round()
	var arena_obj: Object = b.get("arena") as Object

	# 1. Dual-island arena visuals (P1 Tide, P2 Briar/Echo, P3 Gravity/Conveyors, P4 Mirror Split)
	if arena_obj != null and b.boss_state != LxBossBase.BossState.DEATH:
		_draw_arena_rules(b, arena_obj, off, pal, fred)

	# 2. Armour glint outside punish windows vs golden punish crown halo
	var glint_t: float = float(b.get("_armour_glint_t"))
	if glint_t > 0.0 and b.boss_state != LxBossBase.BossState.DEATH:
		var ga: float = clampf(glint_t / 0.20, 0.0, 1.0)
		var gang: float = float(b.get("_armour_glint_ang"))
		b.draw_arc(c, roundf(r + 6.5), gang - 0.85, gang + 0.85, 12, Color(pal["ice"] as Color, ga), 2.0)
		b.draw_arc(c, roundf(r + 4.5), gang - 0.55, gang + 0.55, 8, Color(pal["cream"] as Color, ga), 1.0)
	elif b.is_punishable() and b.boss_state != LxBossBase.BossState.DEATH:
		b.draw_arc(c, roundf(r + 6.0), 0.0, TAU, 22, pal["gold"] as Color, 2.0)

	# 3. Phase 4 Final Veil & Exposed 8-Island Stagger Crown
	var veil_intact: bool = bool(b.get("veil_intact"))
	var lens_lit_t: float = float(b.get("lens_lit_t"))
	if veil_intact:
		var vc: Vector2 = (off + (Vector2(0.0, -14.0) if has_sprite else Vector2.ZERO)).round()
		var vr: float = roundf((r + 20.0) if has_sprite else (r + 4.0))
		var lit: bool = lens_lit_t > 0.0
		var v_outer: Color = (pal["sky"] if lit else pal["plum"]) as Color
		var v_mid: Color = (pal["ice"] if lit else pal["wine"]) as Color
		var v_hi: Color = (pal["cream"] if lit else pal["mauve"]) as Color
		var spin: float = b.anim_t * ((0.8 if lit else 0.45) if fred else (1.7 if lit else 0.9))
		var seg_step: float = TAU / 8.0
		for i: int in range(8):
			var a: float = spin + float(i) * seg_step
			b.draw_arc(vc, vr, a - seg_step * 0.34, a + seg_step * 0.34, 5, v_outer, 2.0)
			b.draw_arc(vc, maxf(2.0, vr - 2.0), a - seg_step * 0.25, a + seg_step * 0.25, 4, v_mid, 1.0)
		for k: int in range(4):
			var ca: float = -spin * 0.6 + float(k) * (TAU * 0.25)
			_draw_diamond(b, vc + Vector2.from_angle(ca) * (vr + 2.0), 3.0, v_mid, v_hi)
	elif b.boss_state == LxBossBase.BossState.STAGGER:
		var core_c: Vector2 = (off + (Vector2(0.0, -12.0) if has_sprite else Vector2.ZERO)).round()
		var s_rot: float = b.anim_t * (0.9 if fred else 2.2)
		for si: int in range(8):
			var sa: float = s_rot + float(si) * (TAU / 8.0)
			var sp_v: Vector2 = (core_c + Vector2.from_angle(sa) * (r + 12.0)).round()
			b.draw_rect(Rect2(sp_v, Vector2(2.0, 2.0)), LxBiomePalette.col(si + 1, "glow"))
			b.draw_rect(Rect2(sp_v, Vector2.ONE), pal["cream"] as Color)

	# 4. Void Orb tether (P2 Void Zip / Recall Slam)
	if bool(b.get("void_orb_out")):
		var orb_off: Vector2 = ((b.get("void_orb_pos") as Vector2) - b.pos).round()
		b.draw_line(c, orb_off, pal["deep"] as Color, 2.0)
		b.draw_line(c, orb_off, pal["sky"] as Color, 1.0)
		var pulse: float = 0.0 if fred else roundf(sin(b.anim_t * 14.0))
		b.draw_arc(orb_off, 7.0 + pulse, 0.0, TAU, 16, pal["sky"] as Color, 1.0)
		b.draw_circle(orb_off, 5.0, pal["void"] as Color)
		b.draw_circle(orb_off, 2.0, pal["cream"] as Color)

	# 5. Active Commit Attack VFX (Silence Ring, Ward Bash, Recall Slam, Shadow Dash, Eclipse Beam)
	var active_move: int = int(b.get("active_move"))
	var commit_dir: Vector2 = b.get("commit_dir") as Vector2
	var beam_ang: float = float(b.get("beam_angle"))
	var ring_stage: int = int(b.get("ring_stage"))
	var ring_prog: float = float(b.get("ring_progress"))
	if b.boss_state == LxBossBase.BossState.COMMIT:
		if active_move == 3 and ring_stage != 1: # SILENCE_RING
			var ring_r: float = roundf(lerpf(12.0, 54.0, ring_prog))
			b.draw_arc(c, ring_r + 2.0, 0.0, TAU, 36, pal["deep"] as Color, 2.0)
			b.draw_arc(c, ring_r, 0.0, TAU, 36, pal["sky"] as Color, 4.0)
			b.draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, pal["ice"] as Color, 2.0)
			b.draw_arc(c, maxf(2.0, ring_r - 4.0), 0.0, TAU, 24, pal["cream"] as Color, 1.0)
			for ni: int in range(8):
				var na: float = b.anim_t * (1.0 if fred else 2.5) + float(ni) * (TAU / 8.0)
				_draw_diamond(b, c + Vector2.from_angle(na) * ring_r, 3.0, pal["ice"] as Color, pal["cream"] as Color)
		elif active_move == 5: # WARD_BASH
			var ca_c: float = commit_dir.angle()
			b.draw_arc(c, 34.0, ca_c - 1.20, ca_c + 1.20, 16, pal["sky"] as Color, 3.0)
			b.draw_arc(c, 31.0, ca_c - 1.00, ca_c + 1.00, 14, pal["cream"] as Color, 1.0)
		elif active_move == 6 and bool(b.get("_slam_burst_done")): # RECALL_SLAM
			b.draw_arc(c, 36.0, 0.0, TAU, 24, pal["sky"] as Color, 3.0)
			b.draw_arc(c, 32.0, 0.0, TAU, 20, pal["cream"] as Color, 1.0)
		elif active_move == 2: # SHADOW_DASH
			b.draw_line(c, (off - commit_dir * 26.0).round(), pal["sky"] as Color, 3.0)
			b.draw_line(c, (off - commit_dir * 18.0).round(), pal["ice"] as Color, 2.0)
		elif active_move == 4 and b.active_attack_id == "p4_eclipse_beam_sweep": # ECLIPSE_BEAM
			var b_dir: Vector2 = Vector2.from_angle(beam_ang)
			var b_end: Vector2 = (off + b_dir * 162.0).round()
			b.draw_line(c, b_end, pal["wine"] as Color, 8.0)
			b.draw_line(c, b_end, pal["coral"] as Color, 5.0)
			b.draw_line(c, b_end, pal["gold"] as Color, 3.0)
			b.draw_line(c, b_end, pal["cream"] as Color, 1.0)
			_draw_star_flare(b, c, 9.0, pal["gold"] as Color, pal["cream"] as Color)
			_draw_star_flare(b, b_end, 10.0, pal["gold"] as Color, pal["cream"] as Color)
	elif b.boss_state == LxBossBase.BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(b.state_timer / maxf(b.phase_shift_duration, 0.05), 0.0, 1.0)
		var r1: float = roundf((r + 14.0) + rp * 26.0)
		b.draw_arc(c, r1, 0.0, TAU, 32, pal["coral"] as Color, 3.0)
		b.draw_arc(c, maxf(6.0, r1 - 7.0), 0.0, TAU, 28, pal["gold"] as Color, 2.0)
		for bi: int in range(8):
			var ba: float = float(bi) * (TAU / 8.0) + rp * 0.6
			b.draw_rect(Rect2((off + Vector2.from_angle(ba) * (r1 + 3.0)).round(), Vector2(2.0, 2.0)), LxBiomePalette.col(bi + 1, "glow"))

	# 6. P4 Closing 36px dark edge band + Beauty Toll Sparks + 8-Island Comeback Beat aura
	var band_px: float = float(b.get("dark_band_px"))
	if band_px > 0.5 and b.arena_rect.has_area():
		var ar: Rect2 = b.arena_rect
		var loc_p: Vector2 = (ar.position - b.pos + off).round()
		var dc := Color(pal["void"] as Color, 0.42 if fred else 0.58)
		b.draw_rect(Rect2(loc_p.x, loc_p.y, ar.size.x, band_px), dc, true)
		b.draw_rect(Rect2(loc_p.x, loc_p.y + ar.size.y - band_px, ar.size.x, band_px), dc, true)
		b.draw_rect(Rect2(loc_p.x, loc_p.y + band_px, band_px, ar.size.y - band_px * 2.0), dc, true)
		b.draw_rect(Rect2(loc_p.x + ar.size.x - band_px, loc_p.y + band_px, band_px, ar.size.y - band_px * 2.0), dc, true)
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var w_loc: Vector2 = ((Lx.player as Node2D).global_position - b.pos + off).round()
		var b_sparks: int = int(b.get("beauty_sparks"))
		for si: int in range(mini(b_sparks, 4)):
			var sa: float = b.anim_t * (1.2 if fred else 2.6) + float(si) * (TAU / float(mini(b_sparks, 4)))
			var sp: Vector2 = (w_loc + Vector2.from_angle(sa) * 14.0).round()
			b.draw_circle(sp, 2.2, pal["gold"] as Color)
			b.draw_rect(Rect2(sp - Vector2(0.5, 0.5), Vector2.ONE), pal["cream"] as Color)
		if arena_obj != null:
			var surge_t: float = float(arena_obj.get("comeback_surge_t"))
			if surge_t > 0.0:
				var sr: float = b.anim_t * (1.0 if fred else 2.5)
				b.draw_arc(w_loc, 13.0, 0.0, TAU, 20, pal["gold"] as Color, 2.0)
				b.draw_arc(w_loc, 16.0, sr, sr + PI, 12, pal["cream"] as Color, 1.0)
			var burst_t: float = float(arena_obj.get("comeback_burst_t"))
			if burst_t > 0.0:
				var bu: float = 1.0 - clampf(burst_t / 0.85, 0.0, 1.0)
				b.draw_arc(w_loc, lerpf(10.0, 118.0, bu), 0.0, TAU, 32, Color(pal["gold"] as Color, 1.0 - bu), 2.0)
				b.draw_arc(w_loc, lerpf(6.0, 96.0, bu), 0.0, TAU, 28, Color(pal["cream"] as Color, 1.0 - bu), 1.0)


static func _draw_arena_rules(b: LxBossBase, ar_obj: Object, off: Vector2, pal: Dictionary, fred: bool) -> void:
	var ph: int = b.phase
	var ar: Rect2 = b.arena_rect
	var c_loc: Vector2 = (ar.get_center() - b.pos + off).round()
	if ph == 1:
		# Rings & Tides: golden resonance wave + subtle pixel-snapped shoreline tide edges (clear of boss silhouette)
		var tl: float = float(ar_obj.get("tide_level"))
		var foam_h: float = roundf(lerpf(3.0, 8.0, tl))
		var loc_tl: Vector2 = (ar.position - b.pos + off).round()
		var wash_c := Color(pal["blue"] as Color, 0.14 if fred else 0.20)
		var crest_c := Color(pal["sky"] as Color, 0.42 if fred else 0.62)
		var foam_c := Color(pal["ice"] as Color, 0.55 if fred else 0.78)
		b.draw_rect(Rect2(loc_tl.x, loc_tl.y, ar.size.x, foam_h), wash_c, true)
		b.draw_rect(Rect2(loc_tl.x, loc_tl.y + ar.size.y - foam_h, ar.size.x, foam_h), wash_c, true)
		var wave_shift: float = 0.0 if fred else roundf(fposmod(b.anim_t * 14.0, 8.0))
		var wx: float = loc_tl.x + 2.0
		while wx < loc_tl.x + ar.size.x - 4.0:
			var step_off: float = 1.0 if int(wx + wave_shift) % 8 < 4 else 0.0
			var ty_top: float = loc_tl.y + foam_h - 1.0 + step_off
			var ty_bot: float = loc_tl.y + ar.size.y - foam_h - step_off
			# Skip horizontal crests directly across The Hush's torso so silhouette stays razor-clean
			var over_body_top: bool = absf(wx + 2.0 - off.x) < 16.0 and absf(ty_top - (off.y - 12.0)) < 20.0
			var over_body_bot: bool = absf(wx + 2.0 - off.x) < 16.0 and absf(ty_bot - (off.y - 12.0)) < 20.0
			if not over_body_top:
				b.draw_rect(Rect2(wx, ty_top, 4.0, 1.0), foam_c if int(wx) % 12 < 6 else crest_c)
			if not over_body_bot:
				b.draw_rect(Rect2(wx, ty_bot, 4.0, 1.0), foam_c if int(wx + 4.0) % 12 < 6 else crest_c)
			wx += 6.0
		var br_t: float = float(ar_obj.get("bell_resonance_t"))
		if br_t > 0.0:
			b.draw_arc(c_loc, roundf(lerpf(32.0, 110.0, 1.0 - clampf(br_t / 3.2, 0.0, 1.0))), 0.0, TAU, 28, Color(pal["gold"] as Color, clampf(br_t / 3.2, 0.0, 0.7)), 2.0)
	elif ph == 2:
		# Growth & The Loop: pulsing jade Briar Pods + 6s Echo-Loop Ghost
		for bp_v: Variant in (ar_obj.get("briar_nodes") as Array):
			var bp: Vector2 = ((bp_v as Vector2) - b.pos + off).round()
			b.draw_circle(bp, 7.5, Color(pal["pine"] as Color, 0.80))
			b.draw_arc(bp, 8.5, 0.0, TAU, 14, pal["jade"] as Color, 2.0)
			_draw_diamond(b, bp, 3.5, pal["lime"] as Color, pal["cream"] as Color)
		if bool(ar_obj.get("echo_ghost_active")):
			var ep: Vector2 = ((ar_obj.get("echo_ghost_pos") as Vector2) - b.pos + off).round()
			var hot_e: bool = float(ar_obj.get("echo_flash_t")) > 0.0
			b.draw_circle(ep, 7.0, Color(pal["void"] as Color, 0.72))
			b.draw_circle(ep, 6.0, Color(pal["teal"] as Color, 0.45))
			b.draw_arc(ep, 8.5, 0.0, TAU, 16, pal["void"] as Color, 3.0)
			b.draw_arc(ep, 8.5, 0.0, TAU, 16, (pal["cream"] if hot_e else pal["lime"]) as Color, 1.0)
			_draw_diamond(b, ep, 3.0, pal["ice"] as Color, pal["cream"] as Color)
	elif ph == 3:
		# Gravity & Moving Floor: opposing animated Conveyor Bands + orbiting Starfall Gravity Well + Phantom Center
		var cdir: float = float(ar_obj.get("conveyor_dir"))
		var cscr: float = float(ar_obj.get("conveyor_scroll"))
		var crects: Array = ar_obj.get("conveyor_rects") as Array
		for idx: int in range(crects.size()):
			var rr: Rect2 = crects[idx] as Rect2
			var rl := Rect2((rr.position - b.pos + off).round(), rr.size.round())
			var sgn: float = cdir if (idx % 2 == 0) else -cdir
			b.draw_rect(rl, Color(pal["night"] as Color, 0.45), true)
			b.draw_rect(rl, pal["mauve"] as Color, false, 1.0)
			var step_off: float = cscr if sgn > 0.0 else (8.0 - cscr)
			var x: float = rl.position.x + 4.0 + step_off
			while x < rl.end.x - 4.0:
				var cy: float = rl.get_center().y
				b.draw_line(Vector2(roundf(x - sgn * 2.5), cy - 3.0), Vector2(roundf(x + sgn * 2.0), cy), pal["apricot"] as Color, 1.0)
				b.draw_line(Vector2(roundf(x - sgn * 2.5), cy + 3.0), Vector2(roundf(x + sgn * 2.0), cy), pal["apricot"] as Color, 1.0)
				x += 12.0
		var gw: Object = ar_obj.get("grav_well") as Object
		if gw != null and bool(gw.get("active")):
			var gp: Vector2 = ((gw.get("pos") as Vector2) - b.pos + off).round()
			b.draw_arc(gp, 24.0, 0.0, TAU, 22, Color(pal["sky"] as Color, 0.42), 1.0)
			b.draw_arc(gp, 13.0, b.anim_t * (1.2 if fred else 3.0), b.anim_t * (1.2 if fred else 3.0) + PI * 1.4, 14, pal["ice"] as Color, 1.0)
			b.draw_circle(gp, 3.0, pal["cream"] as Color)
		if b.active_attack_id == "p3_double_silence_ring" and b.boss_state in [LxBossBase.BossState.TELL, LxBossBase.BossState.COMMIT]:
			b.draw_rect(Rect2(c_loc - Vector2(36.0, 24.0), Vector2(72.0, 48.0)), Color(pal["plum"] as Color, 0.16), true)
			b.draw_rect(Rect2(c_loc - Vector2(36.0, 24.0), Vector2(72.0, 48.0)), pal["ice"] as Color, false, 1.0)
	elif ph == 4:
		# Mirrors & What Was Sold: diagonal Silver/Rose Mirror Split + Mirror Silhouette Twin
		if bool(ar_obj.get("mirror_fault_active")):
			b.draw_line(c_loc + Vector2(-140.0, 86.0), c_loc + Vector2(140.0, -86.0), Color(pal["ice"] as Color, 0.36), 2.0)
			b.draw_line(c_loc + Vector2(-140.0, 86.0), c_loc + Vector2(140.0, -86.0), Color(pal["rose"] as Color, 0.62), 1.0)
		if bool(ar_obj.get("mirror_active")):
			var mp: Vector2 = ((ar_obj.get("mirror_pos") as Vector2) - b.pos + off).round()
			b.draw_circle(mp, 10.0, Color(pal["void"] as Color, 0.78))
			b.draw_circle(mp, 9.0, Color(pal["deep"] as Color, 0.72))
			b.draw_arc(mp, 10.5, 0.0, TAU, 18, pal["void"] as Color, 3.0)
			b.draw_arc(mp, 10.5, 0.0, TAU, 18, pal["rose"] as Color, 2.0)
			_draw_diamond(b, mp, 4.5, pal["ice"] as Color, pal["cream"] as Color)
		var ms_t: float = float(ar_obj.get("mirror_shatter_t"))
		if ms_t > 0.0:
			var mp2: Vector2 = ((ar_obj.get("mirror_pos") as Vector2) - b.pos + off).round()
			var mu: float = 1.0 - clampf(ms_t / 0.70, 0.0, 1.0)
			b.draw_arc(mp2, lerpf(10.0, 44.0, mu), 0.0, TAU, 22, Color(pal["ice"] as Color, 1.0 - mu), 2.0)
