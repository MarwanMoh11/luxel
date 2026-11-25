class_name LxKilnmotherBoss
extends LxBossBase
## Ashen Kiln Grand Boss (Island 6, `kiln_r10`): The Kilnmother (Bible §4.8).
## 3 phases (66%/33%) on LxBossBase. Towering furnace with heavy slag armour that chips plain bolts
## outside punish windows with a molten armour glint; Sunflare / Lance (`cracks_armour`) shatters
## armour (1.45x + stagger), hitting her blazing belly during Bellows Gust TELL interrupts & staggers,
## and hitting her P3 Core Meltdown inhale with Sunflare/Lance triggers a massive Meltdown Stagger!
## Preserves B6 upgrades: Slag Lob (2 coolable molten boulders), P2 Reforge Roar cracking outer basalt
## rims + summoning 2 director-compliant `slag_slime` adds (freeze for 4-Way Furnace Cross cover!),
## P2 4-Way Furnace Cross-Blast, and P3 Double Molten Ring Core Meltdown!

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)
signal add_spawn_requested(specs: Array, source: LxEnemyBrain)

enum KilnMove { MOLTEN_RING, BELLOWS_GUST, FURNACE_CROSS, SLAG_LOB }
enum RingStage { RING_1, PAUSE, RING_2 }

const KILN_ARMOUR_MAX: float = 4.5
const ARMOUR_REFORM_DUR: float = 9.0
const KILN_RING_START_R: float = 10.0
const KILN_RING_MAX_R: float = 56.0
const KILN_RING_BAND: float = 9.0
const RING_COMMIT_DUR: float = 0.32
const RING_PAUSE_P3: float = 0.48
const GUST_RANGE: float = 120.0
const GUST_HALF_W: float = 24.0
const GUST_DMG_R: float = 54.0
const GUST_PUSH_WICK: float = 210.0
const GUST_PUSH_LANTERN: float = 175.0
const CROSS_RANGE: float = 104.0
const CROSS_HALF_W: float = 10.0

# Compat fields referenced by tests/luxel/boss_qa_capture.gd, action_qa_capture.gd & teaching fx
var active_move: int = KilnMove.MOLTEN_RING
var _roaring: bool = false
var armour_max: float = KILN_ARMOUR_MAX
var armour_hp: float = KILN_ARMOUR_MAX
var armour_intact: bool = true

var _armour_broken_t: float = 0.0
var _ring_stage: int = RingStage.RING_1
var _ring_progress: float = 0.0
var _ring_hit: bool = false
var _gust_dir: Vector2 = Vector2.DOWN
var _gust_hit: bool = false
var _gust_announced: bool = false
var _cross_base_ang: float = 0.0
var _cross_progress: float = 0.0
var _cross_hit: bool = false
var _armor_forged_roar: bool = false
var _slimes_spawned_p2: bool = false
var _lob_done: bool = false
var _clank_sfx_cd: float = 0.0
var _slag: LxKilnSlagHelper = LxKilnSlagHelper.new()


func _init() -> void:
	super._init()
	kind = "kilnmother"
	boss_id = "kilnmother"
	boss_name_key = "BOSS_KILNMOTHER"
	island_id = 6
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 172.0
	hp = 172.0
	body_radius = 10.0
	move_speed = 32.0
	stagger_threshold = 18.0
	stagger_duration = 1.70
	punish_dmg_mult = 1.30
	post_recover_cd = 0.28
	shard_drop = 44
	intro_duration = 0.65
	phase_shift_duration = 0.70
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "kiln_r10":
		arena_rect = Rect2(176.0, 80.0, 144.0, 80.0)
	configure_phases([0.66, 0.33])

	# Attack 1: Molten Ring — expanding fiery shockwave + cinder gap ring
	register_attack("molten_ring", {
		"weight": 1.25, "tell": 0.62, "commit": 0.36, "recover": 1.25, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = KilnMove.MOLTEN_RING
			_ring_stage = RingStage.RING_1
			_ring_progress = 0.0
			_ring_hit = false
			ground.warn_ring(pos, KILN_RING_MAX_R, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(tgt, 24.0, last_tell_duration + 0.06, 0.5, "apricot", "coral")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_ring_stage = RingStage.RING_1
			_ring_progress = 0.0
			_ring_hit = false
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 120.0, gap_a, 0.85, {"color": "coral", "source": "kiln_ring_ember", "damage": 0.5})
			_boss_impact(0.20, 96.0, 96.0)
			stage.play_sfx("golem_stomp_shockwave", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_single_ring(el, 0.36),
	})

	# Attack 2: Bellows Gust — glowing belly inhale (shoot to interrupt!), pushes Wick & lantern + ember fan
	register_attack("bellows_gust", {
		"weight": 1.20, "tell": 0.60, "commit": 0.38, "recover": 1.25, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = KilnMove.BELLOWS_GUST
			_gust_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _gust_dir.angle()
			_gust_hit = false
			_gust_announced = false
			ground.warn_lane(pos, pos + _gust_dir * 58.0, 14.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("kilnmother_bellows_inhale", pos),
		"on_tell": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _prog: float) -> void:
			if state_timer > 0.22:
				_gust_dir = Vector2.from_angle(facing),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_gust_hit = false
			_gust_announced = false
			patterns.emit_fan(pos, _gust_dir, 5 if phase >= 2 else 3, 0.72, 142.0, {"color": "apricot", "source": "bellows_cinder", "damage": 0.5})
			_boss_impact(0.20, 115.0, 110.0)
			stage.play_sfx("kilnmother_bellows_gust", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			_step_bellows_commit(dt),
	})

	# Attack 3: Slag Lob — drops 2 coolable molten slag boulders + perimeter corner cinder rain!
	register_attack("slag_lob", {
		"weight": 1.20, "tell": 0.54, "commit": 0.34, "recover": 1.15, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = KilnMove.SLAG_LOB
			_lob_done = false
			var targets: Array[Vector2] = _slag.pick_lob_targets(pos, tgt, world_ctx)
			for tp: Vector2 in targets:
				ground.warn_ring(tp, 18.0, last_tell_duration, 0.0, "coral", "gold")
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration + 0.04, 24.0, 0.5, "apricot", "gold")
			stage.play_sfx("kilnmother_bellows_inhale", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_lob_done = true
			_slag.commit_lobs(self)
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, d, 3, 146.0, 0.08, {"color": "gold", "source": "slag_sparks", "damage": 0.5})
			_boss_impact(0.16, 80.0, 82.0)
			stage.play_sfx("magma_crack", pos),
	})

	# Attack 4 (P2/P3): 4-Way Furnace Cross-Blast — occluded by cooled slag boulders / frozen slimes!
	register_attack("furnace_cross", {
		"phases": [2, 3], "weight": 1.80, "tell": 0.58, "commit": 0.38, "recover": 1.30, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = KilnMove.FURNACE_CROSS
			_cross_base_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			facing = _cross_base_ang
			_cross_progress = 0.0
			_cross_hit = false
			for ci: int in range(4):
				var cdir: Vector2 = Vector2.from_angle(_cross_base_ang + float(ci) * (PI * 0.5))
				ground.warn_lane(pos, pos + cdir * 62.0, CROSS_HALF_W, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_cross_progress = 0.0
			_cross_hit = false
			for ci: int in range(4):
				var cdir: Vector2 = Vector2.from_angle(_cross_base_ang + float(ci) * (PI * 0.5))
				patterns.emit_lane(pos, cdir, 2, 140.0, 0.09, {"color": "coral", "source": "furnace_cross_bolt", "damage": 0.5})
			_boss_impact(0.22, 108.0, 104.0)
			stage.play_sfx("kilnmother_bellows_gust", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_cross_commit(el, 0.38),
	})

	# Attack 5 (P3): Core Meltdown Double-Ring — Ring 1 -> blazing inhale pause (Sunflare/Lance staggers!) -> Ring 2!
	register_attack("core_meltdown_rings", {
		"phases": [3], "weight": 2.05, "tell": 0.62, "commit": RING_COMMIT_DUR + RING_PAUSE_P3 + RING_COMMIT_DUR, "recover": 1.35, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = KilnMove.MOLTEN_RING
			_ring_stage = RingStage.RING_1
			_ring_progress = 0.0
			_ring_hit = false
			ground.warn_ring(pos, KILN_RING_MAX_R, last_tell_duration, 0.0, "coral", "cream")
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration + 0.08, 22.0, 0.5, "coral", "gold")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_ring_stage = RingStage.RING_1
			_ring_progress = 0.0
			_ring_hit = false
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 12, 122.0, gap_a, 0.85, {"color": "gold", "source": "meltdown_ring1", "damage": 0.5})
			_boss_impact(0.22, 98.0, 100.0)
			stage.play_sfx("golem_stomp_shockwave", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			_step_meltdown_commit(el, tgt),
	})


func _on_reset_encounter() -> void:
	active_move = KilnMove.MOLTEN_RING
	_roaring = false
	armour_max = KILN_ARMOUR_MAX
	armour_hp = KILN_ARMOUR_MAX
	armour_intact = true
	_armour_broken_t = 0.0
	_ring_stage = RingStage.RING_1
	_ring_progress = 0.0
	_ring_hit = false
	_gust_dir = Vector2.from_angle(facing)
	_gust_hit = false
	_gust_announced = false
	_cross_base_ang = facing
	_cross_progress = 0.0
	_cross_hit = false
	_armor_forged_roar = false
	_slimes_spawned_p2 = false
	_lob_done = false
	_clank_sfx_cd = 0.0
	_slag.reset()


func _enter_phase(next_phase: int) -> void:
	# Compat hook for tests/luxel/boss_qa_capture.gd
	phase = clampi(next_phase, 1, 3)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true
	_armor_forged_roar = false
	active_move = KilnMove.MOLTEN_RING
	_ring_stage = RingStage.RING_1
	_ring_progress = 0.0
	_cross_progress = 0.0
	_slag.trigger_room_pourers(world_ctx)
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		if not armour_intact:
			armour_intact = true
			armour_hp = 2.5
			_armor_forged_roar = true
			stage.play_sfx("golem_armour_clank", pos)
			_spawn_reforge_sparks()
		_slag.rim_cracked = true
		# P2 Arena Mutation: crack outer basalt rim into lava channels + spawn 2 director-compliant slag_slimes!
		_carve_safe_pit_near(c + Vector2(-64.0, -56.0))
		_carve_safe_pit_near(c + Vector2(64.0, -56.0))
		if not _slimes_spawned_p2 and Lx.packs != null and not Lx.packs.enemy_script("slag_slime").is_empty():
			_slimes_spawned_p2 = true
			var slime_specs: Array[Dictionary] = [
				{"kind": "slag_slime", "pos": clamp_to_arena(home + Vector2(-44.0, 22.0)), "summon_color": "coral"},
				{"kind": "slag_slime", "pos": clamp_to_arena(home + Vector2(44.0, 22.0)), "summon_color": "coral"},
			]
			adds.queue_wave(slime_specs, 0.70, 2)
		stage.darkness_pulse(0.62, 1.0)
	elif new_phase == 3:
		_carve_safe_pit_near(c + Vector2(-88.0, 8.0))
		_carve_safe_pit_near(c + Vector2(96.0, 8.0))
		props.spawn_pillar(clamp_to_arena(c + Vector2(-58.0, -32.0)), 4.5, "kiln_slag_pillar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(58.0, -32.0)), 4.5, "kiln_slag_pillar_e")
		stage.darkness_pulse(0.72, 1.1)
	stage.shake(0.30)
	stage.play_sfx("kilnmother_phase", pos)


func _spawn_reforge_sparks() -> void:
	var fred_f: bool = is_flash_reduced()
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player.has_method("spawn_ring"):
			Lx.player.call("spawn_ring", pos, body_radius + 2.0, 44.0, 0.34, PAL["gold"] as Color, 1.5 if fred_f else 2.0)
			Lx.player.call("spawn_ring", pos, body_radius + 4.0, 32.0, 0.26, PAL["coral"] as Color, 1.2 if fred_f else 1.6)
		if Lx.player.has_method("spawn_sparks"):
			for fi: int in range(4):
				var fdir: Vector2 = Vector2.from_angle(PI * 0.25 + float(fi) * (PI * 0.5))
				Lx.player.call("spawn_sparks", pos, fdir, 3, (PAL["gold"] if fi % 2 == 0 else PAL["coral"]) as Color, 36.0, 92.0, 0.32)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
		_armor_forged_roar = false
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	if not armour_intact:
		_armour_broken_t = maxf(0.0, _armour_broken_t - dt)
		if _armour_broken_t <= 0.0:
			armour_intact = true
			armour_hp = armour_max * 0.65
			stage.play_sfx("golem_armour_clank", pos)
	_slag.tick(dt, self)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_SUNFLARE
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_PRISM] or bool(h["pierce"])

	# P3 Core Meltdown Inhale Interrupt: Sunflare / Lance into open furnace mouth triggers huge stagger!
	var in_meltdown_pause: bool = phase >= 3 and boss_state == BossState.COMMIT and active_attack_id == "core_meltdown_rings" and _ring_stage == RingStage.PAUSE
	if in_meltdown_pause and (cracks or heavy):
		if armour_intact:
			_crack_armour()
		_ring_stage = RingStage.RING_1
		_boss_impact(0.26, 94.0, 96.0)
		stage.play_sfx("kilnmother_belly_interrupt", pos)
		stage.play_sfx("magma_crack", pos)
		stagger_immunity_t = 0.0
		add_stagger(stagger_threshold)
		return dmg * 1.60

	# Bellows Gust Belly Interrupt: hitting blazing belly during TELL interrupts & staggers!
	if boss_state == BossState.TELL and active_attack_id == "bellows_gust" and stagger_immunity_t <= 0.0:
		if cracks and armour_intact:
			_crack_armour()
		active_move = KilnMove.MOLTEN_RING
		_boss_impact(0.22, 84.0, 88.0)
		stage.play_sfx("kilnmother_belly_interrupt", pos)
		add_stagger(stagger_threshold)
		return dmg * 1.35

	# Sunflare / Lance cracks heavy furnace slag armour for 1.45x + stagger!
	if cracks and armour_intact:
		_crack_armour()
		add_stagger(stagger_threshold * 0.70)
		return dmg * 1.45

	if boss_state == BossState.STAGGER:
		return dmg * 1.50
	if is_punishable():
		if (heavy or cracks) and armour_intact:
			_wear_armour(float(h["shield_wear"]))
		return dmg * (1.20 if (not armour_intact or heavy or cracks) else 1.0)
	if heavy or cracks:
		if armour_intact:
			_wear_armour(float(h["shield_wear"]))
		return dmg * 1.15

	# Heavy furnace slag armour outside punish windows: reduced bolt chip + clear slag armour glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("golem_armour_clank", pos)
	if armour_intact:
		_wear_armour(0.10)
	return dmg * (0.24 if armour_intact else 0.34)


func _wear_armour(amt: float) -> void:
	armour_hp = maxf(0.0, armour_hp - maxf(0.0, amt))
	if armour_hp <= 0.001:
		_crack_armour()


func _crack_armour() -> void:
	armour_hp = 0.0
	armour_intact = false
	_armour_broken_t = ARMOUR_REFORM_DUR
	stage.play_sfx("golem_armour_crack", pos)
	_boss_impact(0.22, 86.0, 88.0)


func _step_single_ring(el: float, dur: float) -> void:
	_ring_progress = clampf(el / maxf(dur, 0.05), 0.0, 1.0)
	var ring_r: float = lerpf(KILN_RING_START_R, KILN_RING_MAX_R, _ring_progress)
	if not _ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= KILN_RING_BAND:
			_ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.1 else Vector2.from_angle(facing)
			emit_boss_damage(push, 0.5, "shockwave", pos, true)
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _step_meltdown_commit(el: float, tgt: Vector2) -> void:
	if el < RING_COMMIT_DUR:
		_step_single_ring(el, RING_COMMIT_DUR)
	elif el < RING_COMMIT_DUR + RING_PAUSE_P3:
		if _ring_stage == RingStage.RING_1:
			_ring_stage = RingStage.PAUSE
			_ring_progress = 0.0
			_ring_hit = false
			ground.warn_ring(pos, KILN_RING_MAX_R, RING_PAUSE_P3, 0.0, "coral", "cream")
			stage.play_sfx("golem_stomp_tell", pos)
	else:
		if _ring_stage != RingStage.RING_2:
			_ring_stage = RingStage.RING_2
			_ring_progress = 0.0
			_ring_hit = false
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 14, 126.0, gap_a, 0.85, {"color": "coral", "source": "meltdown_ring2", "damage": 0.5})
			_boss_impact(0.24, 100.0, 102.0)
			stage.play_sfx("golem_stomp_shockwave", pos)
		_step_single_ring(el - RING_COMMIT_DUR - RING_PAUSE_P3, RING_COMMIT_DUR)


func _step_cross_commit(el: float, dur: float) -> void:
	_cross_progress = clampf(el / maxf(dur, 0.05), 0.0, 1.0)
	var raw_len: float = lerpf(14.0, CROSS_RANGE, _cross_progress)
	if not _cross_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		for ci: int in range(4):
			var cdir: Vector2 = Vector2.from_angle(_cross_base_ang + float(ci) * (PI * 0.5))
			var arm_len: float = _slag.arm_length_with_cover(pos, cdir, raw_len, CROSS_HALF_W, world_ctx, self)
			if Geometry2D.get_closest_point_to_segment(wp, pos, pos + cdir * arm_len).distance_to(wp) <= CROSS_HALF_W:
				_cross_hit = true
				emit_boss_damage(cdir, 0.5, "furnace_cross", pos, true)
				break
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		for ci: int in range(4):
			var cdir_l: Vector2 = Vector2.from_angle(_cross_base_ang + float(ci) * (PI * 0.5))
			var arm_len_l: float = _slag.arm_length_with_cover(pos, cdir_l, raw_len, CROSS_HALF_W, world_ctx, self)
			if Geometry2D.get_closest_point_to_segment(lp, pos, pos + cdir_l * arm_len_l).distance_to(lp) <= CROSS_HALF_W + 3.0:
				if Lx.events != null:
					Lx.events.lantern_struck.emit(lp)
				break


func _step_bellows_commit(dt: float) -> void:
	if not _gust_announced:
		_gust_announced = true
		gust_emitted.emit(pos, _gust_dir, GUST_RANGE, GUST_HALF_W, self)
		if world_ctx != null and world_ctx.has_method("on_enemy_gust"):
			world_ctx.call("on_enemy_gust", self, pos, _gust_dir, GUST_RANGE, GUST_HALF_W)
	var end_p: Vector2 = pos + _gust_dir * GUST_RANGE
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= GUST_HALF_W:
			var safe_push: bool = world_ctx == null or not world_ctx.has_method("is_lethal_void_at") or not bool(world_ctx.call("is_lethal_void_at", wp + _gust_dir * 24.0))
			if safe_push and Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil") and arena_rect.grow(-20.0).has_point(wp + _gust_dir * 20.0):
				Lx.player.call("apply_recoil", _gust_dir * GUST_PUSH_WICK * dt)
			if not _gust_hit and pos.distance_to(wp) <= GUST_DMG_R:
				_gust_hit = true
				emit_boss_damage(_gust_dir, 0.5, "bellows_gust", pos, true)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= GUST_HALF_W + 6.0:
			_push_thrown_lantern(dt)


func _push_thrown_lantern(dt: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if lan_v is Object and is_instance_valid(lan_v as Object):
		var lan: Object = lan_v as Object
		var st_v: Variant = lan.get("state")
		if st_v != null and (int(st_v) == 1 or int(st_v) == 2):
			var cur_v: Variant = lan.get("pos")
			if cur_v is Vector2:
				var pushed: Vector2 = (cur_v as Vector2) + _gust_dir * GUST_PUSH_LANTERN * dt
				lan.set("pos", pushed)
				if lan is Node2D:
					(lan as Node2D).global_position = pushed.round()


func _carve_safe_pit_near(world_pt: Vector2) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var tx: int = int(floorf(world_pt.x / 16.0))
	var ty: int = int(floorf(world_pt.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if cp.y < 216.0 and str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 44.0 and cp.distance_to(_get_wick_pos()) > 28.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-14.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	if phase >= 2:
		out.append(corners[2])
	return out


func _on_death_start() -> void:
	_slag.reset()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("kilnmother_phase", pos)


func _body_color() -> Color:
	if armour_intact:
		return (PAL["dusk"] if phase >= 3 else PAL["stone"]) as Color
	return (PAL["gold"] if phase >= 3 else PAL["coral"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var belly_exposed: bool = active_attack_id == "bellows_gust" and boss_state == BossState.TELL
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 3.5, 2.0, armour_hp, armour_max)
	if belly_exposed:
		var br: float = 5.5 + (0.0 if is_flash_reduced() else 1.2 * sin(anim_t * 22.0))
		draw_arc(c + Vector2(0.0, 1.0), br, 0.0, TAU, 16, PAL["gold"] as Color, 1.8)
		draw_circle(c + Vector2(0.0, 1.0), 2.5, PAL["cream"] as Color)
	elif active_attack_id == "bellows_gust" and boss_state == BossState.COMMIT:
		var side2 := Vector2(-_gust_dir.y, _gust_dir.x)
		var g_len: float = GUST_RANGE * 0.88
		for idx: int in range(-1, 2):
			var s_off: Vector2 = side2 * float(idx) * (GUST_HALF_W * 0.48)
			var p0: Vector2 = (off + s_off).round()
			var p1: Vector2 = (off + s_off + _gust_dir * (g_len if idx == 0 else g_len * 0.86)).round()
			draw_line(p0, p1, PAL["wine"] as Color, 6.8 if idx == 0 else 4.8)
			draw_line(p0, p1, PAL["coral"] as Color, 4.6 if idx == 0 else 3.2)
			draw_line(p0, p1, PAL["gold"] as Color, 1.8 if idx == 0 else 1.1)
	elif active_attack_id == "furnace_cross" and boss_state == BossState.COMMIT:
		var raw_len: float = lerpf(14.0, CROSS_RANGE, _cross_progress)
		for ci: int in range(4):
			var cdir: Vector2 = Vector2.from_angle(_cross_base_ang + float(ci) * (PI * 0.5))
			var arm_len: float = _slag.arm_length_with_cover(pos, cdir, raw_len, CROSS_HALF_W, world_ctx, self)
			var cend: Vector2 = (c + cdir * arm_len).round()
			draw_line(c, cend, PAL["wine"] as Color, 9.0)
			draw_line(c, cend, PAL["coral"] as Color, 6.0)
			draw_line(c, cend, PAL["apricot"] as Color, 3.6)
			draw_line(c, cend, PAL["gold"] as Color, 2.0)
			draw_line(c, cend, PAL["cream"] as Color, 1.0)
			draw_circle(cend, 2.4, (PAL["ice"] if arm_len < raw_len - 1.0 else PAL["gold"]) as Color)
	elif active_attack_id in ["molten_ring", "core_meltdown_rings"] and boss_state == BossState.COMMIT:
		if _ring_stage == RingStage.PAUSE:
			var pr: float = KILN_RING_MAX_R * 0.45 + (0.0 if is_flash_reduced() else 2.0 * sin(anim_t * 18.0))
			draw_arc(c, pr + 2.0, 0.0, TAU, 24, PAL["coral"] as Color, 2.0)
			draw_arc(c, pr, 0.0, TAU, 24, PAL["cream"] as Color, 2.2)
		else:
			var ring_r: float = lerpf(KILN_RING_START_R, KILN_RING_MAX_R, _ring_progress)
			draw_arc(c, ring_r + 2.8, 0.0, TAU, 36, PAL["wine"] as Color, 2.5)
			draw_arc(c, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.8)
			draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
			draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)
	var lob_prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
	_slag.draw_slag(self, pos, off, lob_prog, active_attack_id == "slag_lob" and boss_state == BossState.TELL, anim_t)
	# Heavy slag armour glint outside punish windows vs golden punish halo
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.5, facing - 1.2, facing + 1.2, 16, PAL["cream"] as Color, 2.2)
		draw_arc(c, body_radius + 7.5, facing - 0.9, facing + 0.9, 12, PAL["gold"] as Color, 1.3)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.18, 1.54, 0.44)
