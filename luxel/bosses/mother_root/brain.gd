class_name LxMotherRootBoss
extends LxBossBase
## Island 3 Superboss: The Mother Root (sb_mother_root).
## Colossal world-tree heart synthesizing all 3 Island 3 rules:
## 1) Seedlight Thorn-Walls: lingering lantern > 1.5 s sprouts a living thorn-wall pillar
##    (blocks her P3 Heartwood Beam Sweep and enemy bolts!).
## 2) Growth-Ring Rotor (P2+): swirling canopy sap field (`LxFields`) + outer trench rotation.
## 3) Mid-Fight Shrink Dive (66% & 33% HP): outer bark seals armored and opens a glowing
##    Shrink Fissure exposing her inner Taproot Heart — dive in or shoot/Beam the heart core
##    to shatter her bark seal for a 1.95 s stagger!

const THORN_GROW_S: float = 1.50
const MAX_THORN_WALLS: int = 3
const BARK_SEAL_S: float = 6.0
const HEART_SHATTER_STAGGER_S: float = 1.95


class GrowthRingField:
	extends RefCounted
	var center: Vector2 = Vector2.ZERO
	var outer_r: float = 112.0
	var inner_r: float = 42.0
	var strength: float = 68.0
	var active: bool = false
	var dir_sign: float = 1.0

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active or what == "wick":
			return Vector2.ZERO
		var rel: Vector2 = p - center
		var d: float = rel.length()
		if d < inner_r or d > outer_r or d < 1.0:
			return Vector2.ZERO
		var tang := Vector2(-rel.y, rel.x) / d
		return tang * strength * dir_sign


var _field: GrowthRingField = GrowthRingField.new()
var _lan_anchor_pos: Vector2 = Vector2.ZERO
var _lan_linger_t: float = 0.0
var _thorn_ids: Array[String] = []
var _thorn_seq: int = 0
var _bark_sealed_t: float = 0.0
var _fissure_pos: Vector2 = Vector2.ZERO
var _beam_ang: float = PI * 0.5
var _beam_sweep_dir: float = 1.0
var _beam_hit_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "mother_root"
	boss_id = "mother_root"
	boss_name_key = "ISL3_BOSS_MOTHER"
	island_id = 3
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 96.0
	hp = 96.0
	body_radius = 15.5
	move_speed = 24.0
	stagger_threshold = 15.0
	stagger_duration = 1.95
	post_recover_cd = 0.50
	intro_duration = 0.75
	phase_shift_duration = 0.78
	death_duration = 2.4
	shard_drop = 100


func _exit_tree() -> void:
	LxFields.remove(_field)


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Root-Ring Sweep (expanding root ring + sweeping gap ring & root fan)
	register_attack("root_ring_sweep", {
		"weight": 1.25, "tell": 0.66, "commit": 0.42, "recover": 1.25, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.DOWN
			facing = aim_d.angle()
			ground.warn_ring(pos, 42.0, last_tell_duration, 1.0, "coral", "lime")
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 175.0), 10.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("mr_mother_groan", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 8, 88.0, gap_a, 1.15, {"color": "lime", "source": "root_ring"})
			patterns.emit_fan(pos, Vector2.from_angle(gap_a), 3, 0.78, 98.0, {"color": "gold", "source": "root_shard"})
			stage.shake(0.20)
			stage.play_sfx("mr_bark_seal", pos),
	})

	# Attack 2: Sun-Thorn Bloom (targeted thorn pillars at Wick & corners + expanding botanical square)
	register_attack("sun_thorn_bloom", {
		"weight": 1.20, "tell": 0.62, "commit": 0.36, "recover": 1.20, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_pillars([clamp_to_arena(tgt)], last_tell_duration + 0.16, 15.0, 0.28, 1.0, "lime")
			stage.play_sfx("mr_heart_pulse_tiny", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_expanding_square(pos, 2, 82.0, anim_t * 0.5, 1, {"color": "apricot", "source": "sun_thorn"})
			stage.shake(0.16)
			stage.play_sfx("thorn_burst", pos),
	})

	# Attack 3: Amber Sap Rain (glowing sap pools pressuring Wick + flanks)
	register_attack("amber_sap_rain", {
		"weight": 1.15, "tell": 0.70, "commit": 0.56, "recover": 1.28, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.16, 19.0, 1.0, "apricot", "gold")
			stage.play_sfx("mr_mother_groan", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.DOWN
			if phase >= 2:
				patterns.emit_spiral(pos, 4, 84.0, aim_d.angle(), 0.44, 2, 0.24, {"color": "gold", "source": "sap_orb"})
			stage.shake(0.18)
			stage.play_sfx("mr_heart_pulse_tiny", pos),
	})

	# Attack 4: P3 Heartwood Beam Sweep (colossal sweeping sun-beam; blocked by bloomed thorn-walls!)
	register_attack("heartwood_beam_sweep", {
		"phases": [3], "weight": 3.20, "tell": 0.72, "commit": 0.68, "recover": 1.35, "cooldown": 0.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else PI * 0.5
			_beam_sweep_dir = 1.0 if _orbit_side >= 0.0 else -1.0
			_beam_ang = aim_a - _beam_sweep_dir * 0.60
			_beam_hit_cd = 0.0
			facing = aim_a
			ground.warn_sector(pos, aim_a - 0.65, aim_a + 0.65, 140.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_lane(pos, _trace_heartwood_beam(), 12.0, 0.55, 0.0, "gold", "cream")
			stage.light_burst(pos, 110.0, 1.5, 0.50)
			stage.shake(0.24)
			stage.play_sfx("beam_fire", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			_beam_ang += _beam_sweep_dir * 1.45 * dt
			facing = _beam_ang
			_beam_hit_cd = maxf(0.0, _beam_hit_cd - dt)
			var b_end: Vector2 = _trace_heartwood_beam()
			if _beam_hit_cd <= 0.0 and Geometry2D.get_closest_point_to_segment(tgt, pos, b_end).distance_to(tgt) <= 8.0:
				_beam_hit_cd = 0.75
				var perp: Vector2 = Vector2.from_angle(_beam_ang + PI * 0.5)
				emit_boss_damage(perp, 1.0, "heartwood_beam", pos, true),
	})


func _on_reset_encounter() -> void:
	LxFields.remove(_field)
	_field.active = false
	_field.center = arena_rect.get_center()
	_lan_anchor_pos = Vector2.ZERO
	_lan_linger_t = 0.0
	_thorn_ids.clear()
	_thorn_seq = 0
	_bark_sealed_t = 0.0
	_fissure_pos = clamp_to_arena(pos + Vector2(0.0, 32.0))


func _trace_heartwood_beam() -> Vector2:
	var dir: Vector2 = Vector2.from_angle(_beam_ang)
	var max_len: float = 175.0
	# Bloomed Seedlight Thorn-Walls physically block the Heartwood Beam Sweep!
	for pp: Vector2 in props.get_positions("pillar"):
		var rel: Vector2 = pp - pos
		var proj: float = rel.dot(dir)
		if proj > 12.0 and proj < max_len:
			var perp_d: float = absf(rel.x * (-dir.y) + rel.y * dir.x)
			if perp_d <= 14.0:
				max_len = minf(max_len, proj)
	return pos + dir * max_len


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	return out


func _step_boss_reposition(dt: float, _target: Vector2) -> void:
	# Colossal tree-heart holds dignified north-center anchor, gently swaying
	var anchor := Vector2(arena_rect.get_center().x + sin(anim_t * 0.7) * 28.0, arena_rect.position.y + arena_rect.size.y * 0.34)
	var diff: Vector2 = clamp_to_arena(anchor) - pos
	if diff.length() > 3.0:
		move_boss(diff.normalized() * minf(diff.length(), move_speed * dt), false)


func _on_boss_tick(dt: float, target: Vector2) -> void:
	_fissure_pos = clamp_to_arena(pos + Vector2(0.0, 28.0))
	# Rule 1 (Seedlight): lingering lantern > 1.5 s sprouts a living Thorn-Wall pillar!
	var lan_p: Vector2 = _get_lantern_pos()
	if arena_rect.grow(-18.0).has_point(lan_p):
		if _lan_anchor_pos == Vector2.ZERO or lan_p.distance_to(_lan_anchor_pos) > 20.0:
			_lan_anchor_pos = lan_p
			_lan_linger_t = 0.0
		else:
			_lan_linger_t += dt
			if _lan_linger_t >= THORN_GROW_S:
				_lan_linger_t = 0.0
				_sprout_thorn_wall(clamp_to_arena(lan_p + Vector2(0.0, -14.0)))
	# Rule 3 (Mid-Fight Shrink Dive): step into glowing fissure during Bark Seal to scorch inner taproot!
	if _bark_sealed_t > 0.0:
		_bark_sealed_t = maxf(0.0, _bark_sealed_t - dt)
		if target.distance_to(_fissure_pos) <= 22.0:
			_shatter_bark_seal()


func _sprout_thorn_wall(at_pos: Vector2) -> void:
	if at_pos.distance_to(pos) < 30.0:
		return
	var active_pillars: Array[Vector2] = props.get_positions("pillar")
	if active_pillars.size() >= MAX_THORN_WALLS:
		return
	for ep: Vector2 in active_pillars:
		if ep.distance_to(at_pos) < 26.0:
			return
	_thorn_seq += 1
	var tid: String = "mr_thorn_%d" % _thorn_seq
	props.spawn_pillar(at_pos, 5.0, tid)
	_thorn_ids.append(tid)
	stage.play_sfx("thorn_burst", at_pos)


func _start_shrink_dive_seal() -> void:
	_bark_sealed_t = BARK_SEAL_S
	var hp_pos: Vector2 = clamp_to_arena(pos + Vector2(0.0, 28.0))
	var b_p: Dictionary = props.spawn_bell(hp_pos, func(_p: Dictionary) -> void:
		if _bark_sealed_t > 0.0:
			_shatter_bark_seal(), "mr_taproot_heart_%d" % phase)
	b_p["solid"] = false
	stage.play_sfx("mr_bark_seal", pos)


func _shatter_bark_seal() -> void:
	_bark_sealed_t = 0.0
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, HEART_SHATTER_STAGGER_S)
	staggered.emit(HEART_SHATTER_STAGGER_S)
	stage.light_burst(pos, 108.0, 1.5, 0.45)
	stage.shake(0.28)
	stage.play_sfx("mr_canopy_bloom", pos)
	LxDamageFx.boss_impact(pos, 0.24, 96.0, 96.0, 92.0, 1.46, 0.36)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Rule 2 (Growth-Ring Rotor): open outer corner sap trenches + activate swirling LxFields canopy current!
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "pit")
		_field.center = c
		_field.active = true
		_field.dir_sign = 1.0
		LxFields.add(_field)
		_start_shrink_dive_seal()
		stage.darkness_pulse(0.66, 1.1)
		stage.shake(0.26)
		stage.play_sfx("mr_mother_groan", pos)
	elif new_phase == 3:
		# Rotate outer corner trench geometry 90 deg + flip Growth-Ring swirl + Bark Seal #2!
		stage.set_tiles(world_ctx, Rect2i(17, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(2, 7, 1, 2), "pit")
		_field.dir_sign = -1.0
		_start_shrink_dive_seal()
		stage.darkness_pulse(0.74, 1.2)
		stage.shake(0.30)
		stage.play_sfx("mr_mother_groan", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE:
		if _bark_sealed_t > 0.0:
			_shatter_bark_seal()
		return dmg * 1.25
	if _bark_sealed_t > 0.0 and not is_punishable():
		clank_t = 0.08
		return dmg * 0.50
	return dmg


func _on_death_start() -> void:
	LxFields.remove(_field)
	_field.active = false
	_bark_sealed_t = 0.0
	if Lx.state != null:
		Lx.state.story_flags["mother_root_defeated"] = true
	stage.light_burst(pos, 140.0, 1.6, 0.65)
	stage.play_sfx("mr_canopy_bloom", pos)


func _has_active_shield() -> bool:
	return _bark_sealed_t > 0.0 and not is_punishable()


func _shield_color() -> Color:
	return PAL["apricot"] as Color


func _draw_boss_extra(_off: Vector2) -> void:
	var inv: Vector2 = -pos
	var fred: bool = is_flash_reduced()
	# Growth-ring orbital lines during P2/P3
	if _field.active:
		var cp: Vector2 = (_field.center + inv).round()
		var rot: float = anim_t * 0.8 * _field.dir_sign
		for k: int in range(4):
			var a0: float = rot + float(k) * (PI * 0.5)
			draw_arc(cp, 68.0, a0, a0 + 0.75, 10, Color(PAL["void"] as Color, 0.42), 3.0)
			draw_arc(cp, 68.0, a0, a0 + 0.75, 10, Color(PAL["lime"] as Color, 0.32), 1.0)
	# Glowing Shrink-Dive Fissure during Bark Seal!
	if _bark_sealed_t > 0.0:
		var fp: Vector2 = (_fissure_pos + inv).round()
		var r: float = 12.0 + (0.0 if fred else sin(anim_t * 7.0) * 2.0)
		draw_circle(fp, r, Color(PAL["pine"] as Color, 0.60))
		draw_arc(fp, r, 0.0, TAU, 18, PAL["void"] as Color, 4.0)
		draw_arc(fp, r, 0.0, TAU, 18, PAL["lime"] as Color, 2.0)
		draw_circle(fp, 4.0, PAL["cream"] as Color)
	# Active Heartwood Beam Sweep visual!
	if boss_state == BossState.COMMIT and active_attack_id == "heartwood_beam_sweep":
		var b_end: Vector2 = (_trace_heartwood_beam() + inv).round()
		draw_line(Vector2.ZERO, b_end, PAL["void"] as Color, 9.0)
		draw_line(Vector2.ZERO, b_end, PAL["lime"] as Color, 7.0)
		draw_line(Vector2.ZERO, b_end, PAL["gold"] as Color, 4.0)
		draw_line(Vector2.ZERO, b_end, PAL["cream"] as Color, 2.0)
