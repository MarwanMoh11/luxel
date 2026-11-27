class_name LxBellkeeperBoss
extends LxBossBase
## Grand Bellkeeper Boss (Island 1, belfry_r7): Migrated onto LxBossBase.
## First major boss most players meet: FAIR, READABLE, and GRAND.
## Preserves existing bellkeeper sprite (including phase2 anim), crown silhouette, SFX,
## teaching role, and Island 1 Bible upgrades:
## - Crown shield + brass vestment armour outside punish windows (bolts chip with gold glint).
## - P1 (100-55%): Crown Cleave, Spire Lunge, Bell Toll Slam (+ War Bell cracks gold crown shield!).
## - P2 (<= 55%): Spire Clock Face illuminates with slow sweeping Phantom Minute Hand
##   (0.35 rad/s; Dash passes cleanly through; Dusk Bell freezes 2.0s) + Double-Toll Slam +
##   carved clock-well pits + belfry pillars + director-compliant toll_moth + owl adds!
## - P3 (<= 25%): Three-Tone Toll Duel — telegraphs Gold (Dawn) / Ice (Dusk) / Coral (War)
##   crown aura; countering with matching rim bell triggers 1.60s counter-stagger!

signal add_spawn_requested(specs: Array[Dictionary], boss: LxEnemyBrain)
signal shield_broken(enemy: LxEnemyBrain, at_pos: Vector2)
signal shield_reformed(enemy: LxEnemyBrain, at_pos: Vector2)

const FRONT_GUARD_HALF: float = 1.05
const SLAM_START_R: float = 8.0
const SLAM_MAX_R: float = 68.0
const SLAM_BAND: float = 9.5
const SLAM_RING_TIME: float = 0.26
const DOUBLE_TOLL_GAP_P2: float = 0.48
const DOUBLE_TOLL_GAP_P3: float = 0.46
const LUNGE_SPEED: float = 188.0
const CLOCK_HAND_SPEED: float = 0.30
const CLOCK_HAND_LEN: float = 90.0
const CLOCK_HAND_HIT_CD: float = 2.80
const TONE_CYCLE: PackedStringArray = ["dawn", "dusk", "war"]

enum SlamStage { NONE, RING_1, TOLL_PAUSE, RING_2 }

var shield_max: float = 4.0
var shield_hp: float = 4.0
var shield_gone_duration: float = 3.6
var shield_gone_t: float = 0.0

var double_toll_enabled: bool = false
var slam_stage: int = SlamStage.NONE
var _slam_stage_t: float = 0.0
var _slam_progress: float = 0.0
var _slam_hit: bool = false
var _aim_dir: Vector2 = Vector2.LEFT
var _lunge_hit: bool = false
var _clock_active: bool = false
var _clock_ang: float = -PI * 0.5
var _clock_freeze_t: float = 0.0
var _clock_hit_cd: float = 0.0
var _clock_warm_t: float = 0.0
var _saw_first_tell: bool = false
var _toll_tone: String = "dawn"
var _tone_idx: int = 0
var _p3_chime_t: float = 0.0
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0
var _chorus_wave2_done: bool = false


func _init() -> void:
	super._init()
	kind = "bellkeeper"
	boss_id = "bellkeeper"
	boss_name_key = "BOSS_BELLKEEPER"
	island_id = 1
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island1_boss_p1"
	music_p2_cue = "island1_boss_p2"
	max_hp = 146.0
	hp = 146.0
	body_radius = 8.0
	move_speed = 42.0
	stagger_threshold = 14.0
	stagger_duration = 1.70
	punish_dmg_mult = 1.15
	post_recover_cd = 0.50
	intro_duration = 0.50
	phase_shift_duration = 0.75
	death_duration = 2.0
	shard_drop = 30


func _configure_boss(spec: Dictionary) -> void:
	var base_hp: float = 146.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	boss_id = str(spec.get("boss_id", "bellkeeper"))
	island_id = int(spec.get("island_id", 1))
	configure_phases([0.60, 0.34])

	# Attack 1: Crown Cleave — wide bell-staff swing + golden chime fan
	register_attack("crown_cleave", {
		"weight": 1.25, "tell": 0.50, "commit": 0.28, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			ground.warn_sector(pos, facing - 1.20, facing + 1.20, 44.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 175.0), 9.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 4 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.80, 114.0 if phase >= 2 else 104.0, {"color": "gold", "source": "bellkeeper_cleave", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * 60.0 * dt, false),
	})

	# Attack 2: Spire Lunge — grand hop-lunge closing across the spire + coral-gold fan
	register_attack("spire_lunge", {
		"weight": 1.20, "tell": 0.54, "commit": 0.36, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			_lunge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 128.0), 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_lunge_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_lunge_hit = false
			patterns.emit_fan(pos, _aim_dir, 4 if phase >= 2 else 3, 0.62, 124.0, {"color": "apricot", "source": "bellkeeper_lunge", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * LUNGE_SPEED * (1.08 if phase >= 3 else 1.0) * dt, false)
			if not _lunge_hit:
				_lunge_hit = check_contact_damage(22.0, _aim_dir, 1.0, "bellkeeper_lunge"),
	})

	# Attack 3: Bell Toll Slam — expanding 68px bell shockwave + gap-ring chimes; P2/P3 Double-Toll!
	register_attack("bell_toll_slam", {
		"weight": 1.40, "tell": 0.64, "commit": 1.04, "recover": 1.25, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			slam_stage = SlamStage.NONE
			_slam_progress = 0.0
			_slam_hit = false
			if phase >= 3:
				_toll_tone = TONE_CYCLE[_tone_idx % TONE_CYCLE.size()]
				_tone_idx += 1
			else:
				_toll_tone = "dawn"
			var fk: String = _tone_color_key()
			ground.warn_ring(pos, SLAM_MAX_R, last_tell_duration, 0.0, fk, "coral")
			stage.play_sfx("bellkeeper_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			slam_stage = SlamStage.RING_1
			_slam_stage_t = SLAM_RING_TIME
			_slam_progress = 0.0
			_slam_hit = false
			var gap_t: float = (DOUBLE_TOLL_GAP_P3 if phase >= 3 else DOUBLE_TOLL_GAP_P2) * get_tell_scale()
			state_timer = (SLAM_RING_TIME * 2.0 + gap_t) if double_toll_enabled else SLAM_RING_TIME
			_emit_chime_bolts(false)
			LxDamageFx.boss_impact(pos, 0.20, 92.0, 95.0, 102.0, 1.48, 0.42)
			stage.play_sfx("bellkeeper_slam_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			_step_bell_slam_commit(dt),
	})

	# Attack 4 (P2, P3): Carillon Rain — bronze toll rings on Wick & nearest perimeter corners
	register_attack("carillon_rain", {
		"phases": [2, 3], "weight": 2.00, "tell": 0.62, "commit": 0.34, "recover": 1.25, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var spots: Array[Vector2] = _perimeter_targets(tgt, 3)
			patterns.emit_rain(ground, spots, last_tell_duration, 20.0, 1.0, "coral", "gold")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _aim_dir
			patterns.emit_fan(pos, d, 4, 0.82, 94.0, {"color": _tone_color_key(), "source": "bellkeeper_carillon", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("bellkeeper_slam_fire", pos),
	})

	# Attack 5 (P3): Three-Tone Chorus — Gold/Ice/Coral crown aura duel wave (counterable by matching rim bell!)
	register_attack("three_tone_chorus", {
		"phases": [3], "weight": 3.20, "tell": 0.64, "commit": 0.52, "recover": 1.30, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_toll_tone = TONE_CYCLE[_tone_idx % TONE_CYCLE.size()]
			_tone_idx += 1
			_chorus_wave2_done = false
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var fk: String = _tone_color_key()
			ground.warn_ring(pos, 52.0, last_tell_duration, 0.0, fk, "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 185.0), 10.0, last_tell_duration, 0.0, fk, "coral")
			stage.play_sfx("bellkeeper_phase3_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_emit_chime_bolts(false)
			patterns.emit_fan(pos, _aim_dir, 4, 0.70, 96.0, {"color": _tone_color_key(), "source": "bellkeeper_chorus", "reflectable": true})
			stage.shake(0.18)
			stage.play_sfx("bellkeeper_double_toll", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			if not _chorus_wave2_done and el >= 0.28:
				_chorus_wave2_done = true
				_emit_chime_bolts(true)
				var d2: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _aim_dir
				patterns.emit_fan(pos, d2, 2, 0.45, 92.0, {"color": _tone_color_key(), "source": "bellkeeper_chorus", "reflectable": true})
				stage.play_sfx("clockwork_chime", pos),
	})


func _on_reset_encounter() -> void:
	shield_hp = shield_max
	shield_gone_t = 0.0
	double_toll_enabled = false
	slam_stage = SlamStage.NONE
	_slam_stage_t = 0.0
	_slam_progress = 0.0
	_slam_hit = false
	_lunge_hit = false
	_clock_active = false
	_clock_ang = -PI * 0.5
	_clock_freeze_t = 0.0
	_clock_hit_cd = 0.0
	_clock_warm_t = 0.0
	_saw_first_tell = false
	_toll_tone = "dawn"
	_tone_idx = 0
	_p3_chime_t = 0.0
	_armour_glint_t = 0.0
	_chorus_wave2_done = false
	_spawn_rim_bells_if_missing()


func _spawn_rim_bells_if_missing() -> void:
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if is_instance_valid(it_v) and it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if has_room_bell:
		return
	var c: Vector2 = arena_rect.get_center()
	var specs: Array = [
		["dawn", Vector2(arena_rect.position.x + 28.0, c.y), "gold"],
		["dusk", Vector2(arena_rect.end.x - 28.0, c.y), "ice"],
		["war", Vector2(c.x, arena_rect.position.y + 24.0), "coral"],
	]
	for item: Array in specs:
		var t_id: String = str(item[0])
		var bp_pos: Vector2 = clamp_to_arena(item[1] as Vector2)
		var prop_d: Dictionary = props.spawn_bell(bp_pos, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring(t_id, (pos - bp).normalized())
			stage.play_sfx("clockwork_chime", bp), "bk_rim_bell_" + t_id)
		prop_d["solid"] = false
		prop_d["color"] = str(item[2])


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_p3_chime_t = maxf(0.0, _p3_chime_t - dt)
	_clock_freeze_t = maxf(0.0, _clock_freeze_t - dt)
	_clock_hit_cd = maxf(0.0, _clock_hit_cd - dt)
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	if boss_state == BossState.TELL:
		_saw_first_tell = true
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
			shield_reformed.emit(self, pos)
			stage.play_sfx("warden_shield_reform", pos)
	if _clock_active and boss_state != BossState.DEATH:
		_step_clock_hand(dt)
	if boss_state != BossState.COMMIT:
		slam_stage = SlamStage.NONE


func _step_clock_hand(dt: float) -> void:
	_clock_warm_t += dt
	if _clock_freeze_t > 0.0:
		return
	_clock_ang = wrapf(_clock_ang + CLOCK_HAND_SPEED * dt, -PI, PI)
	if not _saw_first_tell or boss_state == BossState.PHASE_SHIFT or _clock_warm_t < 1.25 or _clock_hit_cd > 0.0 or not _has_player():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if wick_node != null and wick_node.is_dashing() and wick_node.move_dash != null and wick_node.move_dash.has_iframes():
		return
	var wp: Vector2 = _get_wick_pos()
	var inner: Vector2 = home + Vector2.from_angle(_clock_ang) * 18.0
	var tip: Vector2 = home + Vector2.from_angle(_clock_ang) * CLOCK_HAND_LEN
	if Geometry2D.get_closest_point_to_segment(wp, inner, tip).distance_to(wp) <= 5.5:
		_clock_hit_cd = CLOCK_HAND_HIT_CD
		emit_boss_damage(Vector2.from_angle(_clock_ang + PI * 0.5), 0.5, "bellkeeper_clock_hand", home, true)


func _step_bell_slam_commit(dt: float) -> void:
	match slam_stage:
		SlamStage.RING_1, SlamStage.RING_2:
			_slam_stage_t = maxf(0.0, _slam_stage_t - dt)
			_slam_progress = 1.0 - clampf(_slam_stage_t / SLAM_RING_TIME, 0.0, 1.0)
			var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, _slam_progress)
			if not _slam_hit and _has_player():
				var wv: Vector2 = _get_wick_pos() - pos
				if absf(wv.length() - ring_r) <= 7.5:
					_slam_hit = true
					var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
					emit_boss_damage(push, 0.5, "bellkeeper_slam", pos, true)
			if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
			if _slam_stage_t <= 0.0:
				if slam_stage == SlamStage.RING_1 and double_toll_enabled:
					slam_stage = SlamStage.TOLL_PAUSE
					_slam_stage_t = (DOUBLE_TOLL_GAP_P3 if phase >= 3 else DOUBLE_TOLL_GAP_P2) * get_tell_scale()
					_slam_progress = 0.0
					_slam_hit = false
					ground.warn_ring(pos, SLAM_MAX_R, _slam_stage_t, 0.0, _tone_color_key(), "coral")
					stage.play_sfx("bellkeeper_double_toll", pos)
				else:
					slam_stage = SlamStage.NONE
					state_timer = 0.0
		SlamStage.TOLL_PAUSE:
			_slam_stage_t = maxf(0.0, _slam_stage_t - dt)
			if _slam_stage_t <= 0.0:
				slam_stage = SlamStage.RING_2
				_slam_stage_t = SLAM_RING_TIME
				_slam_progress = 0.0
				_slam_hit = false
				_emit_chime_bolts(true)
				LxDamageFx.boss_impact(pos, 0.20, 92.0, 95.0, 102.0, 1.48, 0.42)
				stage.play_sfx("bellkeeper_slam_fire", pos)


func _emit_chime_bolts(is_second_ring: bool) -> void:
	var aim_a: float = (_get_wick_pos() - pos).angle() if _has_player() else facing
	var col_k: String = _tone_color_key() if phase >= 3 else "gold"
	var cnt: int = 6 if phase >= 3 else (5 if phase >= 2 else 5)
	var spd: float = 94.0 if phase >= 3 else (88.0 if phase >= 2 else 84.0)
	var gap_off: float = PI * (0.35 if is_second_ring else 0.50)
	patterns.emit_gap_ring(pos, cnt, spd, aim_a + gap_off, 1.12, {"color": col_k, "source": "bellkeeper_chime", "reflectable": true})


func on_ring(tone: String, _dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk" and _clock_active:
		_clock_freeze_t = 2.0
		patterns.freeze_bolts_in_radius(pos, 150.0, 1.6, "dusk")
		stage.play_sfx("clockwork_chime", pos)
	if t == "war" and _has_active_shield():
		_wear_shield(shield_max)
	if phase >= 3 and active_attack_id in ["bell_toll_slam", "three_tone_chorus"] \
			and (boss_state == BossState.TELL or (boss_state == BossState.COMMIT and slam_stage == SlamStage.TOLL_PAUSE)):
		if t == _toll_tone or (t == "dusk" and slam_stage == SlamStage.TOLL_PAUSE):
			slam_stage = SlamStage.NONE
			_release_token()
			active_attack_id = ""
			stagger_meter = 0.0
			_set_boss_state(BossState.STAGGER, 1.65)
			last_recover_duration = 1.65
			staggered.emit(1.65)
			LxDamageFx.boss_impact(pos, 0.22, 88.0, 90.0, 96.0, 1.44, 0.36)
			stage.play_sfx("warden_shield_break", pos)


func _has_active_shield() -> bool:
	return shield_hp > 0.001 and shield_gone_t <= 0.0


func _wear_shield(amount: float) -> bool:
	if not _has_active_shield():
		return false
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amount))
	if shield_hp <= 0.001:
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		shield_broken.emit(self, pos)
		stage.play_sfx("warden_shield_break", pos)
		add_stagger(stagger_threshold * 0.80)
		return true
	clank_t = 0.14
	return false


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	var is_heavy: bool = is_pierce or bool(h["stagger"]) or bool(h["cracks_armour"]) or float(h["shield_wear"]) >= 1.2 or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH]

	if _has_active_shield() and (is_heavy or float(h["shield_wear"]) >= 1.0):
		_wear_shield(maxf(float(h["shield_wear"]), 1.35))

	if is_pierce:
		return dmg * (1.15 if is_punishable() else 1.0)
	if is_punishable():
		return dmg

	# Outside punish windows: crown shield & gilded vestment armour chip bolts with glint!
	var ang_diff: float = absf(angle_difference(facing, rel.angle())) if rel.length() > 1.0 else 0.0
	var is_front: bool = rel.length() > 1.0 and ang_diff < FRONT_GUARD_HALF
	_armour_glint_t = 0.22
	_armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing
	if _has_active_shield() and is_front:
		clank_t = 0.14
		if src == LxHit.SOURCE_BOLT:
			_wear_shield(0.22)
			stage.play_sfx("warden_clank", pos)
			return dmg * 0.15
		return dmg * 0.44
	clank_t = 0.10
	if src == LxHit.SOURCE_BOLT:
		stage.play_sfx("warden_clank", pos)
		return dmg * 0.26
	return dmg * 0.52


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		double_toll_enabled = true
		_clock_active = true
		_clock_warm_t = 0.0
		slam_stage = SlamStage.NONE
		shield_gone_t = 0.0
		shield_hp = shield_max
		shield_reformed.emit(self, pos)
		_carve_safe_pit(0.24, 0.50)
		_carve_safe_pit(0.76, 0.50)
		props.spawn_pillar(clamp_to_arena(c + Vector2(-58.0, -28.0)), 4.0, "bk_clock_pillar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(58.0, -28.0)), 4.0, "bk_clock_pillar_e")
		stage.shake(0.32)
		stage.play_sfx("bellkeeper_phase2_roar", pos)
		stage.play_sfx("clockwork_chime", pos)
		_queue_phase2_adds()
	elif new_phase == 3:
		double_toll_enabled = true
		_clock_active = true
		_p3_chime_t = 0.65
		_carve_safe_pit(0.30, 0.74)
		_carve_safe_pit(0.70, 0.74)
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.26)
		stage.play_sfx("bellkeeper_phase3_chime", pos)


func _queue_phase2_adds() -> void:
	var add1_kind: String = "toll_moth" if (Lx.packs != null and not Lx.packs.enemy_script("toll_moth").is_empty()) else "snatcher"
	var specs: Array[Dictionary] = [
		{"kind": add1_kind, "pos": home + Vector2(-64.0, -32.0), "home": home + Vector2(-64.0, -32.0), "summon_color": "gold"},
		{"kind": "owl", "pos": home + Vector2(64.0, -32.0), "home": home + Vector2(64.0, -32.0), "orbit_center": home, "start_airborne": true, "summon_color": "gold"},
	]
	adds.queue_wave(specs, 0.75, 2)


func _carve_safe_pit(fx: float, fy: float) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var wp := Vector2(lerpf(arena_rect.position.x, arena_rect.end.x, fx), lerpf(arena_rect.position.y, arena_rect.end.y, fy))
	var tx: int = int(wp.x / 16.0)
	var ty: int = int(wp.y / 16.0)
	var center_p := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", center_p)) in ["ground", "path"]:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


func _perimeter_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _tone_color_key() -> String:
	return "ice" if _toll_tone == "dusk" else ("coral" if _toll_tone == "war" else "gold")


func _body_color() -> Color:
	if phase >= 3:
		return PAL["coral"] as Color
	return (PAL["wine"] if phase >= 2 else PAL["plum"]) as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# P2/P3 Grand Spire Clock Face overlay & sweeping Phantom Minute Hand
	if _clock_active and boss_state != BossState.DEATH:
		var hc: Vector2 = (home - pos).round()
		var frozen: bool = _clock_freeze_t > 0.0
		var ring_c: Color = (PAL["ice"] if frozen else PAL["gold"]) as Color
		draw_arc(hc, CLOCK_HAND_LEN, 0.0, TAU, 48, Color(ring_c, 0.28), 1.4)
		for hi: int in range(12):
			var ha: float = float(hi) * (TAU / 12.0)
			var d_h: Vector2 = Vector2.from_angle(ha)
			draw_line((hc + d_h * (CLOCK_HAND_LEN - 7.0)).round(), (hc + d_h * CLOCK_HAND_LEN).round(), Color(ring_c, 0.42), 1.5 if hi % 3 == 0 else 1.0)
		var hand_dir: Vector2 = Vector2.from_angle(_clock_ang)
		var p0: Vector2 = (hc + hand_dir * 16.0).round()
		var p1: Vector2 = (hc + hand_dir * CLOCK_HAND_LEN).round()
		var live_hand: bool = _saw_first_tell and boss_state != BossState.PHASE_SHIFT and _clock_warm_t >= 1.25
		var ha_f: float = 0.85 if live_hand else 0.32
		draw_circle(hc, 5.2, Color(PAL["void"] as Color, ha_f))
		draw_arc(hc, 4.4, 0.0, TAU, 14, Color(ring_c, ha_f), 1.4)
		draw_circle(hc, 2.0, Color(PAL["cream"] as Color, ha_f * 0.90))
		draw_line(p0, p1, Color(PAL["night"] as Color, ha_f), 4.2)
		draw_line(p0, p1, Color(ring_c, ha_f), 2.2)
		draw_line(p0, p1, Color(PAL["cream"] as Color, ha_f * 0.85), 1.0)

	if phase >= 3 and boss_state != BossState.DEATH:
		_draw_p3_tone_aura(c, fred)
	if _armour_glint_t > 0.0 and boss_state != BossState.DEATH:
		var ga: float = clampf(_armour_glint_t / 0.22, 0.0, 1.0)
		draw_arc(c, body_radius + 5.0, _armour_glint_ang - 0.80, _armour_glint_ang + 0.80, 10, Color(PAL["cream"] as Color, ga), 2.0)

	if boss_state == BossState.COMMIT and active_attack_id == "bell_toll_slam":
		if slam_stage == SlamStage.TOLL_PAUSE:
			var p_den: float = (DOUBLE_TOLL_GAP_P3 if phase >= 3 else DOUBLE_TOLL_GAP_P2) * get_tell_scale()
			var p_u: float = 1.0 - clampf(_slam_stage_t / maxf(p_den, 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, c, SLAM_MAX_R, p_u, anim_t, _tone_color_key(), "coral")
		elif slam_stage == SlamStage.RING_1 or slam_stage == SlamStage.RING_2:
			var ring_r: float = lerpf(SLAM_START_R, SLAM_MAX_R, _slam_progress)
			draw_arc(c, ring_r + 3.0, 0.0, TAU, 36, PAL["apricot"] as Color, 2.2)
			draw_arc(c, ring_r, 0.0, TAU, 36, PAL["gold"] as Color, 3.4)
			draw_arc(c, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	elif boss_state == BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(state_timer / maxf(phase_shift_duration, 0.05), 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 18.0
		var ph_a: float = (1.0 - rp * 0.45) * (0.58 if fred else 1.0)
		draw_arc(c, rr + 2.5, 0.0, TAU, 28, Color(PAL["apricot"] as Color, ph_a), 1.4 if fred else 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, Color(PAL["gold"] as Color, ph_a), 1.6 if fred else 2.4)
	if _p3_chime_t > 0.0:
		var cp: float = 1.0 - clampf(_p3_chime_t / 0.65, 0.0, 1.0)
		var cr: float = body_radius + 10.0 + cp * 22.0
		var ch_a: float = (1.0 - cp * 0.45) * (0.58 if fred else 1.0)
		draw_arc(c, cr + 2.0, 0.0, TAU, 28, Color(PAL["coral"] as Color, ch_a), 1.4 if fred else 2.0)
		draw_arc(c, cr, 0.0, TAU, 28, Color(PAL["gold"] as Color, ch_a), 1.6 if fred else 2.2)


func _draw_p3_tone_aura(c: Vector2, fred: bool) -> void:
	var tc: Color = PAL[_tone_color_key()] as Color
	var aura_r: float = body_radius + 7.5
	var ring_a: float = 0.62 if fred else 0.78
	var spin: float = anim_t * (0.45 if fred else 1.1)
	draw_arc(c, aura_r, 0.0, TAU, 20, Color(PAL["void"] as Color, ring_a), 3.0)
	draw_arc(c, aura_r, 0.0, TAU, 20, Color(tc, ring_a), 1.5)
	if _toll_tone == "dawn":
		for i: int in range(4):
			var a: float = spin + float(i) * (PI * 0.5)
			var sc: Vector2 = (c + Vector2.from_angle(a) * (aura_r + 3.0)).round()
			draw_line((sc + Vector2(-3.0, 0.0)).round(), (sc + Vector2(3.0, 0.0)).round(), PAL["void"] as Color, 2.8)
			draw_line((sc + Vector2(0.0, -3.0)).round(), (sc + Vector2(0.0, 3.0)).round(), PAL["void"] as Color, 2.8)
			draw_line((sc + Vector2(-2.5, 0.0)).round(), (sc + Vector2(2.5, 0.0)).round(), tc, 1.2)
			draw_line((sc + Vector2(0.0, -2.5)).round(), (sc + Vector2(0.0, 2.5)).round(), tc, 1.2)
			draw_rect(Rect2(sc, Vector2.ONE), PAL["cream"] as Color)
	elif _toll_tone == "dusk":
		for sgn: float in [0.0, PI]:
			var a0: float = spin + sgn - 0.65
			var a1: float = spin + sgn + 0.65
			draw_arc(c, aura_r + 3.5, a0, a1, 10, PAL["void"] as Color, 3.2)
			draw_arc(c, aura_r + 3.5, a0, a1, 10, tc, 1.6)
			draw_arc(c, aura_r + 2.2, a0 + 0.18, a1 - 0.18, 8, PAL["cream"] as Color, 1.0)
	else:
		for i: int in range(3):
			var a: float = -PI * 0.5 + spin * 0.8 + float(i) * (TAU / 3.0)
			var d_v: Vector2 = Vector2.from_angle(a)
			var p_v: Vector2 = Vector2(-d_v.y, d_v.x)
			var tip: Vector2 = (c + d_v * (aura_r + 6.0)).round()
			var bl: Vector2 = (c + d_v * (aura_r + 1.0) - p_v * 3.0).round()
			var br: Vector2 = (c + d_v * (aura_r + 1.0) + p_v * 3.0).round()
			var tri := PackedVector2Array([tip, bl, br, tip])
			draw_polyline(tri, PAL["void"] as Color, 2.8)
			draw_colored_polygon(PackedVector2Array([tip, bl, br]), tc)
			draw_polyline(tri, PAL["cream"] as Color, 1.0)
