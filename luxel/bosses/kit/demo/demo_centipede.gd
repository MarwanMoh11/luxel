class_name LxDemoCentipedeBoss
extends LxBossBase
## Reference Boss 2 (Segmented): "The Lamp-Wyrm".
## Proves LxBossBase + Segments (7-segment centipede with per-segment HP/light) +
## Tether (cuttable tail anchor) + Patterns (gap ring, boomerang, orbit, pillars) + Stage tile edit.

var _slither_dir: Vector2 = Vector2.LEFT
var _coil_ang: float = 0.0
var _seg_light_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "demo_centipede"
	boss_id = "demo_centipede"
	boss_name_key = "BOSS_DEMO_CENTIPEDE"
	island_id = 3
	is_miniboss = false
	reward_heart = "full"
	music_cue = "boss_3"
	music_p2_cue = "boss_3_p2"
	max_hp = 66.0
	hp = 66.0
	body_radius = 8.5
	move_speed = 46.0
	stagger_threshold = 13.0
	stagger_duration = 1.50
	post_recover_cd = 0.28


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.65, 0.30])

	# Attack 1: Coil Slither dash across the arena leaving glowing trails + aimed dart
	register_attack("coil_slither", {
		"weight": 1.25, "tell": 0.52, "commit": 0.48, "recover": 0.95, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_slither_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var end_p: Vector2 = clamp_to_arena(pos + _slither_dir * 136.0)
			ground.warn_lane(pos, end_p, 11.0, last_tell_duration, 0.0, "lime", "gold"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _slither_dir
			patterns.emit_fan(pos, aim, 3, 0.36, 152.0, {"color": "lime", "source": "coil_spit"})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			move_boss(_slither_dir * (250.0 if phase >= 2 else 215.0) * dt, true)
			check_contact_damage(16.0, _slither_dir, 1.0, "coil_slither")
			if int(elapsed * 8.0) != int((elapsed - dt) * 8.0):
				ground.add_hazard_circle(pos, 11.0, 1.35, 1.0, "coral"),
	})

	# Attack 2: Lamp Barrage (gap ring from head + aimed boomerang & lane toward Wick)
	register_attack("lamp_barrage", {
		"weight": 1.15, "tell": 0.55, "commit": 0.36, "recover": 1.00, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.RIGHT
			ground.warn_ring(pos, 46.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_lane(pos, pos + aim * 136.0, 8.0, last_tell_duration, 0.0, "lime", "gold"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 128.0, aim.angle() + 0.55, 0.66, {"color": "lime", "source": "lamp_ring"})
			patterns.emit_lane(pos, aim, 3 if phase >= 2 else 2, 162.0, 0.09, {"color": "apricot", "source": "lamp_lane"})
			patterns.emit_boomerang(pos, aim, 152.0, 0.68, 0.55, {"color": "gold", "source": "lamp_boomerang"})
			if phase >= 3:
				patterns.emit_boomerang(pos, aim.rotated(0.28), 148.0, 0.65, -0.55, {"color": "gold", "source": "lamp_boomerang"})
			stage.play_sfx("spore_pop", pos),
	})

	# Attack 3: Radiant Coil (orbiting lantern sparks + corner-flushing pillars!)
	register_attack("radiant_coil", {
		"weight": 1.05, "tell": 0.58, "commit": 0.42, "recover": 1.08, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_coil_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			ground.warn_sector(pos, _coil_ang - 0.85, _coil_ang + 0.85, 86.0, last_tell_duration, 0.0, "gold", "coral")
			var p_pts: Array[Vector2] = [clamp_to_arena(tgt), clamp_to_arena(tgt + Vector2(28.0, 0.0))]
			patterns.emit_pillars(p_pts, last_tell_duration + 0.06, 20.0, 0.50, 1.0, "gold"),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var orb_n: int = 5 if phase >= 2 else 4
			patterns.emit_orbit(pos, orb_n, 42.0, 2.5 if phase >= 2 else 2.0, 2.2, {"color": "gold", "source": "lamp_orbit"})
			if phase >= 2:
				patterns.emit_spiral(pos, 4, 122.0, _coil_ang, 0.38, 3, 0.16, {"color": "lime", "source": "lamp_spiral"})
			stage.light_burst(pos, 88.0, 1.40, 0.34),
	})


func _on_reset_encounter() -> void:
	_seg_light_cd = 0.0
	segments.setup_follow_chain(7, 13.0, 6.0, 6.0, home, PI)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_seg_light_cd = maxf(0.0, _seg_light_cd - dt)


func on_light(a: Variant, b: Variant = Vector2.ZERO, _source: Variant = "") -> void:
	if boss_state == BossState.DEATH:
		return
	var orig: Vector2 = pos
	var rad: float = 0.0
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2; rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2 and (b as Vector2) != Vector2.ZERO: orig = b as Vector2
	if rad <= 0.0:
		return
	var newly: int = segments.apply_light(orig, rad, 7.0, true)
	if newly > 0 and segments.all_lit():
		segments.extinguish_all()
		add_stagger(stagger_threshold)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit != null:
		var seg_i: int = segments.find_segment_at(hit.origin + hit.dir * 8.0, 10.0)
		if seg_i > 0:
			segments.damage_segment(seg_i, hit)
		if _seg_light_cd <= 0.0 and boss_state != BossState.RECOVER:
			_seg_light_cd = 1.6
			segments.light_next_segment(9.0)
			if segments.all_lit():
				segments.extinguish_all()
				add_stagger(stagger_threshold * 0.75)
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		stage.set_tiles(world_ctx, Rect2i(9, 5, 2, 1), "pit")
		var tail_getter: Callable = func() -> Vector2:
			var pts: Array[Vector2] = segments.get_segment_positions(true)
			return pts[pts.size() - 1] if not pts.is_empty() else pos
		tethers.add_tether("wyrm_tail_chain", c, tail_getter, {
			"hp": 2.0, "max_length": 110.0, "color": "lime",
			"on_cut": func(_t: Dictionary) -> void:
				add_stagger(stagger_threshold * 0.8),
		})
		stage.darkness_pulse(0.60, 0.95)
	elif new_phase == 3:
		tethers.charge_electric("wyrm_tail_chain", 0.55)
		stage.shake(0.22)


func _body_color() -> Color:
	return (PAL["lime"] if phase >= 3 else (PAL["jade"] if phase == 2 else PAL["teal"])) as Color
