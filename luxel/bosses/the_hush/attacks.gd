extends RefCounted
## 4-Phase Dual-Island Attack Registry & Commit Steppers for LxTheHushBoss.
##   P1 (Isl 1+2): Rings & Tides — p1_ward_volley, p1_ward_bash, p1_tidal_toll
##   P2 (Isl 3+4): Growth & The Loop — p2_void_zip_briar, p2_recall_thorn_slam, p2_echo_loop_verdict
##   P3 (Isl 5+6): Gravity & Moving Floor — p3_shadow_belt_dash, p3_double_silence_ring, p3_gravity_kiln_cross
##   P4 (Isl 7+8): Mirrors & What Was Sold — p4_eclipse_beam_sweep, p4_mirror_silence_choir, p4_toll_verdict


static func register_all(b: LxTheHushBoss) -> void:
	_register_p1(b)
	_register_p2(b)
	_register_p3(b)
	_register_p4(b)


static func _register_p1(b: LxTheHushBoss) -> void:
	b.register_attack("p1_ward_volley", {
		"phases": [1], "weight": 1.35, "tell": 0.56, "commit": 0.36, "recover": 1.12, "cooldown": 1.35,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.VOLLEY, b._attention_target(tgt))
			b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + b.commit_dir * 168.0), 9.0, b.last_tell_duration, 0.0, "sky", "gold")
			b.patterns.emit_rain(b.ground, b._perimeter_targets(tgt, 3), b.last_tell_duration + 0.04, 19.0, 1.0, "sky", "coral")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.volley_shots = 0
			b.stage.play_sfx("bolt_fire", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			var expected: int = mini(4, int(el / 0.082) + 1)
			while b.volley_shots < expected:
				var bdir: Vector2 = b.commit_dir.rotated((float(b.volley_shots) - 1.5) * 0.16)
				b.volley_shots += 1
				b.hush_bolt_fired.emit(b.pos, bdir, b)
				b.patterns.emit_fan(b.pos, bdir, 1, 0.0, 134.0, {"color": "sky", "source": "hush_volley", "reflectable": true}),
	})

	b.register_attack("p1_ward_bash", {
		"phases": [1], "weight": 1.25, "tell": 0.54, "commit": 0.28, "recover": 1.10, "cooldown": 1.40,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.WARD_BASH, b._attention_target(tgt))
			b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + b.commit_dir * 72.0), 16.0, b.last_tell_duration, 0.0, "sky", "coral")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.patterns.emit_fan(b.pos, b.commit_dir, 3, 0.72, 122.0, {"color": "ice", "source": "hush_tide_spray", "reflectable": true})
			b._boss_impact(0.16, 76.0, 78.0)
			b.stage.play_sfx("warden_swing", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			b.move_boss(b.commit_dir * 170.0 * dt, false)
			if not b.commit_hit and b._has_player():
				var wv: Vector2 = b._get_wick_pos() - b.pos
				if wv.length() <= b.WARD_BASH_HIT_R and (wv.length() < 0.01 or absf(angle_difference(b.commit_dir.angle(), wv.angle())) <= b.WARD_BASH_ARC):
					b.commit_hit = true
					b.emit_boss_damage(b.commit_dir, 1.0, "hush_ward_bash", b.pos, true)
			if b._is_lantern_out() and b.pos.distance_to(b._get_lantern_pos()) <= b.WARD_BASH_HIT_R + 2.0 and Lx.events != null:
				Lx.events.lantern_struck.emit(b._get_lantern_pos()),
	})

	b.register_attack("p1_tidal_toll", {
		"phases": [1], "weight": 1.30, "tell": 0.64, "commit": b.RING_SINGLE_DUR + 0.06, "recover": 1.18, "cooldown": 1.55,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.SILENCE_RING, tgt)
			b.ground.warn_ring(b.pos, 50.0, b.last_tell_duration, 0.0, "gold", "coral")
			b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + b.commit_dir * 155.0), 10.0, b.last_tell_duration, 0.0, "sky", "ice")
			b.stage.play_sfx("bell_toll_heavy", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.ring_stage = 0; b.ring_progress = 0.0; b._ring_sub_t = b.RING_SINGLE_DUR
			b.patterns.emit_sweep_wall(b.pos, b.commit_dir, 136.0, 7, 2, 3, 112.0, {"color": "sky", "source": "hush_tide_wall", "reflectable": true})
			b.patterns.emit_gap_ring(b.pos, 8, 108.0, b.commit_dir.angle() + 0.55, 0.92, {"color": "gold", "source": "hush_bell_chime", "reflectable": true})
			b._boss_impact(0.22, 104.0, 102.0)
			b.stage.play_sfx("tide_surge", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			step_silence_ring(b, dt, false),
	})


static func _register_p2(b: LxTheHushBoss) -> void:
	b.register_attack("p2_void_zip_briar", {
		"phases": [2], "weight": 1.35, "tell": 0.58, "commit": 0.48, "recover": 1.15, "cooldown": 1.38,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = b._attention_target(tgt)
			b._prep_move(LxTheHushBoss.HushMove.VOID_ZIP, att)
			b.void_orb_pos = b.clamp_to_arena(b.pos + b.commit_dir * clampf(att.distance_to(b.pos), 36.0, 104.0))
			b.void_orb_out = false; b._zip_landed = false
			b.ground.warn_ring(b.void_orb_pos, 26.0, b.last_tell_duration, 0.0, "jade", "coral")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_tell": func(_x: LxBossBase, tgt: Vector2, _dt: float, _p: float) -> void:
			if b.state_timer > 0.22:
				var att: Vector2 = b._attention_target(tgt)
				b.commit_dir = (att - b.pos).normalized() if att.distance_to(b.pos) > 1.0 else b.commit_dir
				b.void_orb_pos = b.clamp_to_arena(b.pos + b.commit_dir * clampf(att.distance_to(b.pos), 36.0, 104.0)),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.void_orb_pos = b.clamp_to_arena(b.void_orb_pos); b.void_orb_out = true; b._zip_landed = false
			b.stage.play_sfx("zip_streak", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			if el >= 0.18:
				if b.void_orb_pos.distance_to(b.pos) > 3.0:
					b.move_boss((b.void_orb_pos - b.pos).limit_length(330.0 * dt), false)
				if b.pos.distance_to(b.void_orb_pos) <= 9.0 and not b._zip_landed:
					b._zip_landed = true
					b._boss_impact(0.18, 78.0, 82.0)
					b.stage.play_sfx("thorn_burst", b.pos)
					b.ground.add_hazard_circle(b.pos, 20.0, 1.5, 1.0, "jade", true)
					b.patterns.emit_gap_ring(b.pos, 8, 118.0, b.commit_dir.angle() + 0.45, 0.90, {"color": "jade", "source": "hush_briar_burst", "reflectable": true})
					b.check_contact_damage(26.0, b.commit_dir, 1.0, "hush_void_zip"),
	})

	b.register_attack("p2_recall_thorn_slam", {
		"phases": [2], "weight": 1.35, "tell": 0.58, "commit": 0.44, "recover": 1.18, "cooldown": 1.42,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = b._attention_target(tgt)
			b._prep_move(LxTheHushBoss.HushMove.RECALL_SLAM, att)
			b.void_orb_pos = b.clamp_to_arena(b.pos + b.commit_dir * clampf(att.distance_to(b.pos) + 22.0, 52.0, 108.0))
			b.void_orb_out = true; b._slam_burst_done = false
			b.ground.warn_ring(b.pos, b.RECALL_SLAM_BURST_R, b.last_tell_duration, 0.0, "sky", "coral")
			for ang_o: float in [-0.46, 0.0, 0.46]:
				b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + b.commit_dir.rotated(ang_o) * 155.0), 7.5, b.last_tell_duration + 0.10, 1.0, "jade", "lime", 0.0)
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.void_orb_out = true; b._slam_burst_done = false
			b.stage.play_sfx("zip_streak", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var prev_orb: Vector2 = b.void_orb_pos
			if not b._slam_burst_done:
				b.void_orb_pos = b.void_orb_pos.move_toward(b.pos, 370.0 * dt)
				if not b.commit_hit and b._has_player() and Geometry2D.get_closest_point_to_segment(b._get_wick_pos(), prev_orb, b.void_orb_pos).distance_to(b._get_wick_pos()) <= 12.0:
					b.commit_hit = true
					b.emit_boss_damage((b.pos - prev_orb).normalized(), 1.0, "hush_recall_orb", prev_orb, true)
				if b.void_orb_pos.distance_to(b.pos) <= 6.0:
					b._slam_burst_done = true; b.void_orb_out = false
					b._boss_impact(0.20, 92.0, 94.0); b.stage.play_sfx("hush_pulse", b.pos)
					b.patterns.emit_boomerang(b.pos, b.commit_dir.rotated(0.32), 132.0, 0.65, 0.62, {"color": "lime", "source": "hush_thorn_boom", "reflectable": true})
					b.patterns.emit_boomerang(b.pos, b.commit_dir.rotated(-0.32), 132.0, 0.65, -0.62, {"color": "jade", "source": "hush_thorn_boom", "reflectable": true})
					b.check_contact_damage(b.RECALL_SLAM_BURST_R, b.commit_dir, 1.0, "hush_recall_slam"),
	})

	b.register_attack("p2_echo_loop_verdict", {
		"phases": [2], "weight": 1.30, "tell": 0.60, "commit": 0.40, "recover": 1.18, "cooldown": 1.48,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.VOLLEY, tgt)
			b.arena.echo_flash_t = b.last_tell_duration + 0.30
			var spots: Array[Vector2] = b._perimeter_targets(tgt, 3)
			spots.append(b.arena.echo_ghost_pos)
			b.patterns.emit_rain(b.ground, spots, b.last_tell_duration, 19.0, 1.0, "lime", "coral")
			b.stage.play_sfx("wing_gale", b.pos),
		"on_commit_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			var d_main: Vector2 = (tgt - b.pos).normalized() if tgt.distance_to(b.pos) > 1.0 else b.commit_dir
			b.patterns.emit_fan(b.pos, d_main, 3, 0.64, 130.0, {"color": "jade", "source": "hush_loop_main", "reflectable": true})
			var d_echo: Vector2 = (tgt - b.arena.echo_ghost_pos).normalized() if tgt.distance_to(b.arena.echo_ghost_pos) > 1.0 else -d_main
			b.patterns.emit_fan(b.arena.echo_ghost_pos, d_echo, 3, 0.56, 124.0, {"color": "ice", "source": "hush_loop_echo", "reflectable": true})
			b.stage.shake(0.16); b.stage.play_sfx("hush_pulse", b.pos),
	})


static func _register_p3(b: LxTheHushBoss) -> void:
	b.register_attack("p3_shadow_belt_dash", {
		"phases": [3], "weight": 1.35, "tell": 0.56, "commit": 0.30, "recover": 1.14, "cooldown": 1.38,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.SHADOW_DASH, tgt)
			b.arena.flip_conveyors()
			b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + b.commit_dir * 82.0), 16.0, b.last_tell_duration, 0.0, "sky", "coral")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.patterns.emit_orbit(b.pos, 3, 44.0, 1.9, 1.9, {"color": "sky", "source": "hush_star_orbit", "reflectable": true})
			b.patterns.emit_fan(b.pos, -b.commit_dir, 3, 0.76, 122.0, {"color": "ice", "source": "hush_gravity_spark", "field_scale": 1.0, "reflectable": true})
			b.stage.shake(0.15); b.stage.play_sfx("hollow_dash", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			b.move_boss(b.commit_dir * 225.0 * dt, false)
			b.check_contact_damage(17.0, b.commit_dir, 1.0, "hush_shadow_dash"),
	})

	b.register_attack("p3_double_silence_ring", {
		"phases": [3], "weight": 1.40, "tell": 0.62, "commit": b.RING_SINGLE_DUR * 2.0 + b.RING_GAP_DUR, "recover": 1.24, "cooldown": 1.55,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.SILENCE_RING, tgt)
			b.ground.warn_ring(b.pos, 50.0, b.last_tell_duration, 0.0, "sky", "coral")
			b.patterns.emit_pillars(b._perimeter_targets(tgt, 3), b.last_tell_duration + 0.08, 15.0, 0.50, 1.0, "sky")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.ring_stage = 0; b.ring_progress = 0.0; b._ring_sub_t = b.RING_SINGLE_DUR
			b.state_timer = b.RING_SINGLE_DUR * 2.0 + b.RING_GAP_DUR * b.get_tell_scale()
			b.patterns.emit_gap_ring(b.pos, 8, 114.0, b.commit_dir.angle() + 0.5, 0.90, {"color": "ice", "source": "hush_ring_star", "field_scale": 1.0, "reflectable": true})
			b._boss_impact(0.22, 108.0, 102.0); b.stage.play_sfx("hush_pulse", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			step_silence_ring(b, dt, true),
	})

	b.register_attack("p3_gravity_kiln_cross", {
		"phases": [3], "weight": 1.30, "tell": 0.62, "commit": 0.42, "recover": 1.20, "cooldown": 1.48,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.ECLIPSE_BEAM, tgt)
			var base_a: float = b.commit_dir.angle()
			for k: int in range(4):
				var dv: Vector2 = Vector2.from_angle(base_a + float(k) * (PI * 0.5))
				b.ground.warn_lane(b.pos, b.clamp_to_arena(b.pos + dv * 165.0), 8.5, b.last_tell_duration, 1.0, "coral", "gold", 0.0)
			b.patterns.emit_rain(b.ground, b._perimeter_targets(tgt, 3), b.last_tell_duration + 0.04, 19.0, 1.0, "apricot", "gold")
			b.stage.play_sfx("forge_gust", b.pos),
		"on_commit_start": func(_x: LxBossBase, _tgt: Vector2) -> void:
			b.patterns.emit_boomerang(b.pos, b.commit_dir.rotated(0.32), 134.0, 0.65, 0.68, {"color": "gold", "source": "hush_kiln_lance", "field_scale": 1.0, "reflectable": true})
			b.patterns.emit_boomerang(b.pos, b.commit_dir.rotated(-0.32), 134.0, 0.65, -0.68, {"color": "coral", "source": "hush_kiln_lance", "field_scale": 1.0, "reflectable": true})
			b.stage.shake(0.18); b.stage.play_sfx("star_lance", b.pos),
	})


static func _register_p4(b: LxTheHushBoss) -> void:
	b.register_attack("p4_eclipse_beam_sweep", {
		"phases": [4], "weight": 1.40, "tell": 0.66, "commit": b.BEAM_DUR, "recover": 1.24, "cooldown": 1.38,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.ECLIPSE_BEAM, tgt)
			b.sweep_sign = -b.sweep_sign
			b.sweep_start_ang = wrapf(b.facing - b.sweep_sign * (b.BEAM_ARC * 0.5), -PI, PI)
			b.beam_angle = b.sweep_start_ang
			b.ground.warn_sector(b.pos, b.sweep_start_ang, b.sweep_start_ang + b.sweep_sign * b.BEAM_ARC, b.BEAM_RANGE, b.last_tell_duration, 0.0, "plum", "coral")
			if b.arena.mirror_active:
				var md: Vector2 = (tgt - b.arena.mirror_pos).normalized() if tgt.distance_to(b.arena.mirror_pos) > 1.0 else -b.commit_dir
				b.ground.warn_lane(b.arena.mirror_pos, b.clamp_to_arena(b.arena.mirror_pos + md * 145.0), 7.5, b.last_tell_duration, 0.0, "ice", "rose")
			b.stage.play_sfx("beam_charge", b.pos),
		"on_commit_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b.beam_angle = b.sweep_start_ang; b._beam_light_t = 0.0; b.commit_hit = false
			if b.arena.mirror_active:
				var md: Vector2 = (tgt - b.arena.mirror_pos).normalized() if tgt.distance_to(b.arena.mirror_pos) > 1.0 else -b.commit_dir
				b.patterns.emit_fan(b.arena.mirror_pos, md, 3, 0.48, 134.0, {"color": "ice", "source": "hush_mirror_beam", "reflectable": true})
			b._boss_impact(0.18, 84.0, 82.0); b.stage.play_sfx("beam_fire", b.pos),
		"on_commit": func(_x: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			var u: float = clampf(el / b.BEAM_DUR, 0.0, 1.0)
			b.beam_angle = wrapf(b.sweep_start_ang + b.sweep_sign * b.BEAM_ARC * u, -PI, PI)
			b.facing = b.beam_angle
			var eb_dir: Vector2 = Vector2.from_angle(b.beam_angle)
			b._beam_light_t -= dt
			if b._beam_light_t <= 0.0:
				b._beam_light_t = 0.14
				LxDamageFx.boss_impact(b.pos + eb_dir * 72.0, 0.0, 0.0, 0.0, 82.0, 1.48, 0.22)
			check_beam_hit(b, eb_dir, b.BEAM_RANGE, 9.0),
	})

	b.register_attack("p4_mirror_silence_choir", {
		"phases": [4], "weight": 1.35, "tell": 0.90, "commit": 0.42, "recover": 1.24, "cooldown": 1.55,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.SILENCE_RING, tgt)
			b.ground.warn_safe_inversion(b.arena_rect, b._pick_sanctuary_circles(tgt), 46.0, b.last_tell_duration, 0.26, 1.0, "gold", "plum")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - b.pos).normalized() if tgt.distance_to(b.pos) > 1.0 else b.commit_dir
			b.patterns.emit_gap_ring(b.pos, 8, 118.0, d.angle() + 0.50, 0.92, {"color": "rose", "source": "hush_choir_ring", "reflectable": true})
			b._boss_impact(0.22, 108.0, 104.0); b.stage.play_sfx("hush_pulse", b.pos),
	})

	b.register_attack("p4_toll_verdict", {
		"phases": [4], "weight": 1.35, "tell": 0.58, "commit": 0.40, "recover": 1.18, "cooldown": 1.42,
		"on_tell_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			b._prep_move(LxTheHushBoss.HushMove.VOLLEY, tgt)
			b.patterns.emit_rain(b.ground, b._perimeter_targets(tgt, 3), b.last_tell_duration, 19.0, 1.0, "rose", "gold")
			b.stage.play_sfx("hush_tell", b.pos),
		"on_commit_start": func(_x: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - b.pos).normalized() if tgt.distance_to(b.pos) > 1.0 else b.commit_dir
			b.patterns.emit_expanding_square(b.pos, 3, 116.0, d.angle(), 0, {"color": "gold", "source": "hush_toll_sq", "reflectable": true})
			if b.arena.mirror_active:
				var md: Vector2 = (tgt - b.arena.mirror_pos).normalized() if tgt.distance_to(b.arena.mirror_pos) > 1.0 else -d
				b.patterns.emit_boomerang(b.arena.mirror_pos, md, 134.0, 0.65, 0.55, {"color": "ice", "source": "hush_mirror_boom", "reflectable": true})
			b.stage.shake(0.16); b.stage.play_sfx("hush_pulse", b.pos),
	})


static func step_silence_ring(b: LxTheHushBoss, dt: float, double_ring: bool) -> void:
	b._ring_sub_t = maxf(0.0, b._ring_sub_t - dt)
	if b.ring_stage == 1:
		if b._ring_sub_t <= 0.0:
			b.ring_stage = 2; b._ring_sub_t = b.RING_SINGLE_DUR; b.ring_progress = 0.0; b.commit_hit = false
			b.patterns.emit_gap_ring(b.pos, 8, 118.0, b.commit_dir.angle() - 0.42, 0.90, {"color": "sky", "source": "hush_ring2_star", "field_scale": 1.0, "reflectable": true})
			b._boss_impact(0.22, 106.0, 102.0); b.stage.play_sfx("hush_pulse", b.pos)
		return
	b.ring_progress = 1.0 - clampf(b._ring_sub_t / b.RING_SINGLE_DUR, 0.0, 1.0)
	var ring_r: float = lerpf(b.RING_START_R, b.RING_MAX_R, b.ring_progress)
	if not b.commit_hit and b._has_player() and absf((b._get_wick_pos() - b.pos).length() - ring_r) <= 9.0:
		b.commit_hit = true
		var wv: Vector2 = b._get_wick_pos() - b.pos
		b.emit_boss_damage(wv.normalized() if wv.length() > 0.1 else b.commit_dir, 1.0, "shockwave", b.pos, true)
	if b._is_lantern_out() and b._get_lantern_pos().distance_to(b.pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(b._get_lantern_pos())
	if b._ring_sub_t <= 0.0 and b.ring_stage == 0 and double_ring:
		b.ring_stage = 1
		b._ring_sub_t = b.RING_GAP_DUR * b.get_tell_scale()
		b.ring_progress = 0.0; b.commit_hit = false
		b.ground.warn_ring(b.pos, 50.0, b._ring_sub_t, 0.0, "sky", "coral")


static func check_beam_hit(b: LxTheHushBoss, dir_v: Vector2, length: float, half_w: float) -> void:
	var end_p: Vector2 = b.pos + dir_v * length
	if not b.commit_hit and b._has_player():
		var wp: Vector2 = b._get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, b.pos, end_p).distance_to(wp) <= half_w:
			b.commit_hit = true
			b.emit_boss_damage(dir_v, 1.0, "hush_eclipse_beam", b.pos, true)
	if b._is_lantern_out() and Geometry2D.get_closest_point_to_segment(b._get_lantern_pos(), b.pos, end_p).distance_to(b._get_lantern_pos()) <= half_w + 2.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(b._get_lantern_pos())
