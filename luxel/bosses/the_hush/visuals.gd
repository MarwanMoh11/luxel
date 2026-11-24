extends RefCounted
## Combat VFX & 20-colour Last Light spellcraft for LxTheHushBoss (keeps brain.gd <= 400 lines).


static func _draw_diamond(b: LxEnemyBrain, p: Vector2, rad: float, outer: Color, inner: Color) -> void:
	var c: Vector2 = p.round()
	var t: Vector2 = c + Vector2(0.0, -rad)
	var r: Vector2 = c + Vector2(rad, 0.0)
	var d: Vector2 = c + Vector2(0.0, rad)
	var l: Vector2 = c + Vector2(-rad, 0.0)
	b.draw_line(t, r, outer, 1.2)
	b.draw_line(r, d, outer, 1.2)
	b.draw_line(d, l, outer, 1.2)
	b.draw_line(l, t, outer, 1.2)
	b.draw_rect(Rect2(c - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), inner, true)


static func _draw_star_flare(b: LxEnemyBrain, p: Vector2, rad: float, outer: Color, core: Color) -> void:
	var c: Vector2 = p.round()
	var diag: float = rad * 0.45
	b.draw_line(c + Vector2(-rad, 0.0), c + Vector2(rad, 0.0), outer, 1.6)
	b.draw_line(c + Vector2(0.0, -rad), c + Vector2(0.0, rad), outer, 1.6)
	b.draw_line(c + Vector2(-diag, -diag), c + Vector2(diag, diag), outer, 1.0)
	b.draw_line(c + Vector2(-diag, diag), c + Vector2(diag, -diag), outer, 1.0)
	b.draw_line(c + Vector2(-rad * 0.62, 0.0), c + Vector2(rad * 0.62, 0.0), core, 1.0)
	b.draw_line(c + Vector2(0.0, -rad * 0.62), c + Vector2(0.0, rad * 0.62), core, 1.0)
	b.draw_circle(c, 2.0, core)


static func draw_hush(b: LxEnemyBrain, off: Vector2) -> void:
	var pal: Dictionary = LxEnemyBrain.PAL
	var fred: bool = LxHudFx.flash_reduced()
	var phase: int = b.phase
	var r: float = b.body_radius
	var has_sprite: bool = b._sprite_sheet != null
	if not has_sprite:
		# Crown of the Hush: 4 phase sigil pips orbiting the dark core
		for i: int in range(4):
			var pip: Vector2 = off + Vector2.from_angle(b.anim_t * 1.6 + float(i) * (TAU * 0.25)) * (r + 5.0)
			b.draw_circle(pip, 2.0, (pal["gold"] as Color) if i < phase else (pal["dusk"] as Color))

	var veil_intact: bool = bool(b.get("veil_intact"))
	var lens_lit_t: float = float(b.get("lens_lit_t"))
	if veil_intact:
		var veil_center: Vector2 = (off + (Vector2(0.0, -14.0) if has_sprite else Vector2.ZERO)).round()
		var veil_r: float = (r + 20.0) if has_sprite else (r + 3.0)
		var lit: bool = lens_lit_t > 0.0
		var v_outer: Color = (pal["sky"] if lit else pal["plum"]) as Color
		var v_mid: Color = (pal["ice"] if lit else pal["wine"]) as Color
		var v_hi: Color = (pal["cream"] if lit else pal["mauve"]) as Color
		var spin: float = b.anim_t * (1.7 if lit else 0.9)
		var seg_step: float = TAU / 8.0
		var half_span: float = seg_step * 0.34
		for i: int in range(8):
			var a: float = spin + float(i) * seg_step
			b.draw_arc(veil_center, veil_r, a - half_span, a + half_span, 5, v_outer, 2.4)
			b.draw_arc(veil_center, maxf(2.0, veil_r - 1.6), a - half_span * 0.75, a + half_span * 0.75, 4, v_mid, 1.2)
		for k: int in range(4):
			var ca: float = -spin * 0.6 + float(k) * (TAU * 0.25)
			var pip_p: Vector2 = veil_center + Vector2.from_angle(ca) * (veil_r + 2.0)
			_draw_diamond(b, pip_p, 3.0, v_mid, v_hi)
		var v_hp: float = float(b.get("veil_hp"))
		if v_hp > 0.0 and v_hp <= 1.65:
			for fi: int in range(4):
				var fa: float = spin * 0.5 + float(fi) * (TAU * 0.25) + 0.4
				var f0: Vector2 = (veil_center + Vector2.from_angle(fa) * (veil_r - 3.0)).round()
				var f1: Vector2 = (veil_center + Vector2.from_angle(fa) * (veil_r + 3.5)).round()
				b.draw_line(f0, f1, pal["gold"] as Color, 1.2)
				b.draw_rect(Rect2(f1, Vector2.ONE), pal["cream"] as Color)
	elif b.state == LxEnemyBrain.State.STAGGER:
		# Exposed Veil Shatter: the light of all 8 islands orbits The Hush's vulnerable core!
		var core_c: Vector2 = (off + (Vector2(0.0, -12.0) if has_sprite else Vector2.ZERO)).round()
		var s_rot: float = b.anim_t * (0.9 if fred else 2.2)
		for si: int in range(8):
			var sa: float = s_rot + float(si) * (TAU / 8.0)
			var sp_v: Vector2 = (core_c + Vector2.from_angle(sa) * (r + 12.0)).round()
			b.draw_rect(Rect2(sp_v, Vector2(2.0, 2.0)), LxBiomePalette.col(si + 1, "glow"))
			b.draw_rect(Rect2(sp_v, Vector2.ONE), pal["cream"] as Color)

	if bool(b.get("void_orb_out")):
		var orb_off: Vector2 = ((b.get("void_orb_pos") as Vector2) - b.pos).round()
		var o_orig: Vector2 = off.round()
		var active_m0: int = int(b.get("active_move"))
		if b.state == LxEnemyBrain.State.COMMIT and active_m0 == 1 and not bool(b.get("_zip_landed")):
			var hang_u: float = clampf(float(b.get("commit_elapsed")) / 0.20, 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(b, orb_off, 26.0, lerpf(0.75, 1.0, hang_u), b.anim_t, "sky", "coral")
		var is_recall_hot: bool = active_m0 == 6 and b.state == LxEnemyBrain.State.TELL and b.state_timer <= 0.22
		b.draw_line(o_orig, orb_off, (pal["coral"] if is_recall_hot else pal["deep"]) as Color, 2.4)
		b.draw_line(o_orig, orb_off, (pal["ice"] if active_m0 == 6 else pal["sky"]) as Color, 1.1)
		for bi: int in range(4):
			var bt: float = fposmod(b.anim_t * 2.4 + float(bi) * 0.25, 1.0)
			var bp: Vector2 = o_orig.lerp(orb_off, bt).round()
			b.draw_circle(bp, 1.8, pal["deep"] as Color)
			b.draw_circle(bp, 1.0, (pal["ice"] if bi % 2 == 0 else pal["sky"]) as Color)
		var pulse: float = 0.0 if fred else 0.8 * sin(b.anim_t * 14.0)
		b.draw_arc(orb_off, 6.8 + pulse, 0.0, TAU, 16, pal["sky"] as Color, 1.3)
		b.draw_circle(orb_off, 5.2 + pulse * 0.4, pal["deep"] as Color)
		b.draw_circle(orb_off, 3.5, pal["void"] as Color)
		b.draw_arc(orb_off, 3.8, b.anim_t * 4.2, b.anim_t * 4.2 + PI * 1.15, 10, pal["ice"] as Color, 1.4)
		b.draw_circle(orb_off, 1.4, pal["cream"] as Color if active_m0 == 6 else pal["ice"] as Color)

	var active_move: int = int(b.get("active_move"))
	var commit_dir: Vector2 = b.get("commit_dir") as Vector2
	var sweep_start: float = float(b.get("sweep_start_ang"))
	var sweep_sign: float = float(b.get("sweep_sign"))
	var beam_ang: float = float(b.get("beam_angle"))
	var ring_stage: int = int(b.get("ring_stage"))
	var ring_prog: float = float(b.get("ring_progress"))

	if b.state == LxEnemyBrain.State.TELL:
		var prog: float = 1.0 - clampf(b.state_timer / maxf(b.last_tell_duration, 0.05), 0.0, 1.0)
		if active_move == 3: # SILENCE_RING
			LxBossTelegraphFx.draw_ground_danger_ring(b, off, 84.0, prog, b.anim_t, "sky", "coral")
		elif active_move == 4: # ECLIPSE_BEAM
			var sw_end: float = sweep_start + sweep_sign * 1.45
			var locked_e: bool = b.state_timer <= 0.22
			LxBossTelegraphFx.draw_ground_danger_sector(b, off, sweep_start, sw_end, 158.0, prog, b.anim_t, "plum", "coral")
			var s_tip: Vector2 = (off + Vector2.from_angle(sweep_start) * 158.0).round()
			b.draw_line(off.round(), s_tip, (pal["cream"] if locked_e else pal["gold"]) as Color, 1.6 if locked_e else 1.2)
			_draw_star_flare(b, off, lerpf(4.5, 9.0, prog), (pal["coral"] if locked_e else pal["gold"]) as Color, pal["cream"] as Color)
		elif active_move == 0: # VOLLEY (honest 5-ray spread preview)
			for vi: int in range(5):
				var vdir: Vector2 = commit_dir.rotated((float(vi) - 2.0) * 0.14)
				var is_edge: bool = (vi == 0 or vi == 4 or vi == 2)
				b.draw_line(off.round(), (off + vdir * (152.0 if is_edge else 96.0)).round(), (pal["sky"] if is_edge else pal["deep"]) as Color, 1.4 if vi == 2 else 1.0)
				b.draw_circle((off + vdir * 26.0).round(), 1.3, pal["ice"] as Color)
		elif active_move == 1: # VOID_ZIP (exact void_orb_pos ground danger ring + tether)
			var locked_z: bool = b.state_timer <= 0.22
			var z_tip: Vector2 = ((b.get("void_orb_pos") as Vector2) - b.pos).round()
			var z_col: Color = (pal["gold"] if locked_z else pal["sky"]) as Color
			LxBossTelegraphFx.draw_ground_danger_ring(b, z_tip, 26.0, prog, b.anim_t, "sky", "coral")
			for di: int in range(6):
				var dt0: float = float(di) / 6.0
				var dt1: float = minf(1.0, dt0 + 0.10)
				b.draw_line(off.lerp(z_tip, dt0).round(), off.lerp(z_tip, dt1).round(), z_col, 1.4 if locked_z else 1.1)
			_draw_diamond(b, z_tip, lerpf(6.0, 3.5, prog), z_col, (pal["cream"] if locked_z else pal["ice"]) as Color)
		elif active_move == 5: # WARD_BASH (lunge lane + forward bash arc)
			var ca_b: float = commit_dir.angle()
			LxBossTelegraphFx.draw_ground_danger_lane(b, off, off + commit_dir * 52.0, 16.0, prog, b.anim_t, "sky", "coral")
			b.draw_arc(off.round(), 32.0, ca_b - 1.0, ca_b + 1.0, 14, (pal["cream"] if b.state_timer <= 0.20 else pal["ice"]) as Color, 1.8)
		elif active_move == 6: # RECALL_SLAM (r=38 arrival blast ring)
			LxBossTelegraphFx.draw_ground_danger_ring(b, off, 38.0, prog, b.anim_t, "sky", "coral")
		else: # SHADOW_DASH (honest 76px dash lane matching 290*0.26 = 75.4px)
			LxBossTelegraphFx.draw_ground_danger_lane(b, off, off + commit_dir * 76.0, 16.0, prog, b.anim_t, "sky", "coral")
	elif b.state == LxEnemyBrain.State.COMMIT:
		if active_move == 3 and ring_stage != 1:
			var ring_r: float = lerpf(12.0, 84.0, ring_prog)
			b.draw_arc(off, ring_r + 2.2, 0.0, TAU, 36, pal["deep"] as Color, 2.2)
			b.draw_arc(off, ring_r, 0.0, TAU, 36, pal["sky"] as Color, 3.6)
			b.draw_arc(off, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, pal["ice"] as Color, 1.8)
			b.draw_arc(off, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, pal["cream"] as Color, 1.0)
			for ni: int in range(8):
				var na: float = b.anim_t * 2.5 + float(ni) * (TAU / 8.0)
				var np: Vector2 = off + Vector2.from_angle(na) * ring_r
				_draw_diamond(b, np, 3.0, pal["ice"] as Color, pal["cream"] as Color)
		elif active_move == 3 and ring_stage == 1:
			var p_urg: float = 1.0 - clampf(b.state_timer / 0.44, 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(b, off, 84.0, p_urg, b.anim_t, "sky", "coral")
		elif active_move == 5: # WARD_BASH commit arc
			var ca_c: float = commit_dir.angle()
			var c_wb: Vector2 = off.round()
			b.draw_arc(c_wb, 34.0, ca_c - 1.18, ca_c + 1.18, 16, pal["sky"] as Color, 3.2)
			b.draw_arc(c_wb, 31.0, ca_c - 1.00, ca_c + 1.00, 14, pal["ice"] as Color, 1.8)
			b.draw_arc(c_wb, 29.0, ca_c - 0.82, ca_c + 0.82, 12, pal["cream"] as Color, 1.1)
		elif active_move == 6: # RECALL_SLAM burst commit
			if bool(b.get("_slam_burst_done")):
				var c_rs: Vector2 = off.round()
				b.draw_arc(c_rs, 40.0, 0.0, TAU, 24, pal["deep"] as Color, 2.4)
				b.draw_arc(c_rs, 38.0, 0.0, TAU, 24, pal["sky"] as Color, 3.2)
				b.draw_arc(c_rs, 35.0, 0.0, TAU, 20, pal["cream"] as Color, 1.4)
		elif active_move == 2: # SHADOW_DASH ink-ice slash wake
			var d_perp2: Vector2 = Vector2(-commit_dir.y, commit_dir.x)
			var tail_p: Vector2 = (off - commit_dir * 26.0).round()
			b.draw_line(off.round(), tail_p, pal["sky"] as Color, 3.0)
			b.draw_line(off.round(), (off - commit_dir * 18.0).round(), pal["ice"] as Color, 1.6)
			b.draw_line((off + d_perp2 * 5.0).round(), (tail_p + d_perp2 * 2.0).round(), pal["deep"] as Color, 1.2)
			b.draw_line((off - d_perp2 * 5.0).round(), (tail_p - d_perp2 * 2.0).round(), pal["deep"] as Color, 1.2)
		elif active_move == 4:
			var b_orig: Vector2 = off.round()
			var b_dir: Vector2 = Vector2.from_angle(beam_ang)
			var b_perp: Vector2 = Vector2(-b_dir.y, b_dir.x)
			var b_end: Vector2 = (off + b_dir * 158.0).round()
			b.draw_line(b_orig, b_end, pal["wine"] as Color, 7.6)
			b.draw_line(b_orig, b_end, pal["coral"] as Color, 5.0)
			b.draw_line(b_orig, b_end, pal["gold"] as Color, 2.8)
			b.draw_line(b_orig, b_end, pal["cream"] as Color, 1.3)
			for si: int in range(5):
				var st: float = fposmod(b.anim_t * 3.8 + float(si) * 0.20, 1.0)
				var sp: Vector2 = b_orig.lerp(b_end, st).round()
				b.draw_line(sp - b_perp * 4.5, sp + b_perp * 4.5, pal["gold"] as Color, 1.4)
				b.draw_rect(Rect2(sp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), pal["cream"] as Color, true)
			var fl_r: float = 9.0 + (0.0 if fred else 1.5 * sin(b.anim_t * 24.0))
			_draw_star_flare(b, b_orig, fl_r, pal["gold"] as Color, pal["cream"] as Color)
			_draw_star_flare(b, b_end, fl_r + 1.5, pal["gold"] as Color, pal["cream"] as Color)
		elif active_move == 0: # VOLLEY (honest 5-bolt fan matching hitbox)
			var shots_n: int = maxi(1, int(b.get("volley_shots")))
			for vi: int in range(shots_n):
				var vdir: Vector2 = commit_dir.rotated((float(vi) - 2.0) * 0.14)
				var v_end: Vector2 = (off + vdir * 152.0).round()
				b.draw_line(off.round(), v_end, pal["sky"] as Color, 2.6)
				b.draw_line(off.round(), v_end, pal["ice"] as Color, 1.2)
	elif bool(b.get("_roaring")):
		var rp: float = 1.0 - clampf(b.state_timer / 0.62, 0.0, 1.0)
		var base_r: float = (r + 14.0) if has_sprite else (r + 10.0)
		var r1: float = base_r + rp * 24.0
		var r2: float = maxf(6.0, r1 - 8.0)
		b.draw_arc(off, r1, 0.0, TAU, 32, pal["coral"] as Color, 2.6)
		b.draw_arc(off, r2, 0.0, TAU, 28, pal["gold"] as Color, 2.2)
		b.draw_arc(off, maxf(4.0, r2 - 2.0), 0.0, TAU, 24, pal["cream"] as Color, 1.0)
		for ci: int in range(4):
			var cd: Vector2 = Vector2.from_angle(float(ci) * (TAU * 0.25))
			b.draw_line((off + cd * (r1 - 4.0)).round(), (off + cd * (r1 + 5.5)).round(), pal["gold"] as Color, 1.8)
			b.draw_line((off + cd * (r1 - 2.0)).round(), (off + cd * (r1 + 3.5)).round(), pal["cream"] as Color, 1.0)
		for bi: int in range(8):
			var ba: float = float(bi) * (TAU / 8.0) + rp * 0.5
			var bp_r: Vector2 = (off + Vector2.from_angle(ba) * (r1 + 3.0)).round()
			b.draw_rect(Rect2(bp_r, Vector2(2.0, 2.0)), LxBiomePalette.col(bi + 1, "glow"))
