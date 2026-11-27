class_name LxNightHarbingerBoss
extends LxBossBase
## The Long Night Mini-Boss (Island 8, sanctum_r4): NIGHT HARBINGER.
## Migrated onto LxBossBase keeping id, art (night_harbinger.{png,json}), personality,
## lunar shield + blink-feint slashes, B8 sold-setting reactions, and P2 Eclipse-Brazier Twist:
## - Front Lunar Shield + nocturnal plate armour outside punish windows (plain bolts chip with
##   ice-violet glint; Blue/Prism, Throw, Beam & Sunflare shatter guard; punish windows open full burst).
## - P1 (100-52%): Lunar Cleave, Twin Blink-Cross Slash (lateral blink-feint + echo crescent),
##   Eclipse Spear Rain (pressures all 8 perimeter spots).
## - P2 (<=52%): Snuffs West Eclipse Brazier summoning stationary Eclipse Mirror on East flank,
##   crystallises 2 outer mirror glass tiles, raises 2 lunar obelisks, adds Eclipse Mirror Volley.
##   Relighting West Brazier OR striking Eclipse Mirror shatters it for bonus damage + 1.80s stagger!
## - Phase checkpoint on retry: after reaching P2 once, retry_from_death() resumes at P2.

signal shield_broken(enemy: LxEnemyBrain, at_pos: Vector2)
signal shield_reformed(enemy: LxEnemyBrain, at_pos: Vector2)

const Visuals := preload("res://luxel/bosses/night_harbinger/visuals.gd")

const FRONT_GUARD_HALF: float = 1.08
const SHIELD_MAX_HP: float = 3.6
const SHIELD_REFORM_DUR: float = 5.0
const MAIN_SLASH_TIME: float = 0.24
const ECHO_SLASH_TIME: float = 0.26
const MAIN_SLASH_R: float = 44.0
const MAIN_SLASH_ARC: float = 1.24
const ECHO_CRESCENT_RANGE: float = 90.0
const ECHO_CRESCENT_HALF_W: float = 13.0
const BLINK_DIST: float = 26.0
const MIRROR_STAGGER_TIME: float = 1.80
const MIRROR_SHATTER_DMG: float = 8.0
const MIRROR_RESPAWN_CD: float = 13.0
const MIRROR_ARC_RANGE: float = 92.0
const MIRROR_ARC_DELAY: float = 0.34
const MIRROR_ARC_DUR: float = 0.28
const PHASE2_THRESHOLD: float = 0.52
const CP_FLAG: String = "night_harbinger_phase_cp"
const SANCTUM_R4_CORE := Rect2(128.0, 96.0, 176.0, 96.0)
const SANCTUM_R4_ENGAGE := Rect2(96.0, 80.0, 256.0, 156.0)

# Compat fields queried by luxel/world/miniboss_synergy.gd
var blink_slash_attack: bool = false
var shield_max: float = SHIELD_MAX_HP
var shield_hp: float = SHIELD_MAX_HP
var shield_gone_t: float = 0.0

var _feint_done: bool = false
var _feint_side: float = 1.0
var _main_dir: Vector2 = Vector2.RIGHT
var _main_hit: bool = false
var _echo_pos: Vector2 = Vector2.ZERO
var _echo_dir: Vector2 = Vector2.RIGHT
var _echo_fired: bool = false
var _echo_hit: bool = false
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0
var _guard_cracked_t: float = 0.0
var _clank_sfx_cd: float = 0.0
var _saw_first_tell: bool = false
var _checkpoint_phase: int = 1
var _phase_times: Dictionary = {1: 0.0, 2: 0.0}

# P2 Eclipse Brazier & Stationary Eclipse Mirror
var _west_brazier_pos: Vector2 = Vector2.ZERO
var _west_brazier_ref: Object = null
var _west_brazier_snuffed: bool = false
var _mirror_active: bool = false
var _mirror_pos: Vector2 = Vector2.ZERO
var _mirror_dir: Vector2 = Vector2.LEFT
var _mirror_firing: bool = false
var _mirror_fire_t: float = 0.0
var _mirror_hit: bool = false
var _mirror_respawn_t: float = 0.0
var _mirror_shatter_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "night_harbinger"
	boss_id = "night_harbinger"
	boss_name_key = "MINIBOSS_8"
	island_id = 8
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island8_boss_p1"
	music_p2_cue = "island8_boss_p2"
	max_hp = 395.0
	hp = 395.0
	body_radius = 8.5
	move_speed = 44.0
	stagger_threshold = 24.0
	stagger_duration = 1.75
	post_stagger_immunity = 4.2
	punish_dmg_mult = 1.30
	post_recover_cd = 0.38
	intro_duration = 0.48
	phase_shift_duration = 0.62
	death_duration = 1.9
	shard_drop = 22


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_apply_retry_checkpoint_if_needed()


func _is_sanctum_r4() -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx): return false
	var reg: String = str(world_ctx.get("current_region_id")) if world_ctx.get("current_region_id") != null else str(world_ctx.get("region_id"))
	return reg == "sanctum_r4"


func _infer_arena_rect() -> Rect2:
	return SANCTUM_R4_CORE if _is_sanctum_r4() else super._infer_arena_rect()


func take_hit(hit: LxHit) -> int:
	if not engaged and hit != null and _is_sanctum_r4() and SANCTUM_R4_ENGAGE.has_point(_get_wick_pos()):
		engage()
	return super.take_hit(hit)


func _configure_boss(spec: Dictionary) -> void:
	var base_hp: float = 395.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	kind = "night_harbinger"
	boss_id = str(spec.get("boss_id", "night_harbinger"))
	island_id = int(spec.get("island_id", 8))
	configure_phases([PHASE2_THRESHOLD])

	# Attack 1: Lunar Cleave — heavy crescent sweep + reflectable ice wave fan
	register_attack("lunar_cleave", {
		"weight": 1.20, "tell": 0.52, "commit": 0.28, "recover": 1.08, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			blink_slash_attack = false
			_main_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _main_dir.angle()
			_aim_mirror_at(tgt)
			ground.warn_sector(pos, facing - 1.12, facing + 1.12, 42.0, last_tell_duration, 1.0, "sky", "coral")
			ground.warn_lane(pos, clamp_to_arena(pos + _main_dir * 165.0), 8.0, last_tell_duration, 0.0, "ice", "gold")
			if tgt.distance_to(pos) > 72.0:
				ground.warn_ring(tgt, 20.0, last_tell_duration + 0.08, 1.0, "sky", "coral")
			stage.play_sfx("moonshade_feint", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 4 if phase >= 2 else 3
			patterns.emit_fan(pos, _main_dir, cnt, 0.78, 132.0 if phase >= 2 else 124.0, {"color": "ice", "source": "harbinger_cleave", "reflectable": true})
			_trigger_mirror_echo()
			stage.shake(0.15)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_main_dir * 66.0 * dt, false),
	})

	# Attack 2: Twin Blink-Cross Slash — lateral blink-feint + main crescent lunge + delayed echo crescent
	register_attack("blink_cross_slash", {
		"weight": 1.40, "tell": 0.58, "commit": MAIN_SLASH_TIME + ECHO_SLASH_TIME, "recover": 1.14, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			blink_slash_attack = true
			_feint_done = false
			_feint_side = -_feint_side
			_echo_pos = pos
			_main_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _main_dir.angle()
			_echo_dir = _main_dir
			_aim_mirror_at(tgt)
			_main_hit = false; _echo_fired = false; _echo_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _main_dir * 102.0), 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("harbinger_wave_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, dt: float, _prog: float) -> void:
			if not _feint_done and state_timer <= last_tell_duration * 0.62:
				_feint_done = true
				_echo_pos = pos
				_do_lateral_feint(tgt, BLINK_DIST)
				_echo_dir = (tgt - _echo_pos).normalized() if tgt.distance_to(_echo_pos) > 1.0 else _main_dir
				ground.warn_lane(_echo_pos, clamp_to_arena(_echo_pos + _echo_dir * ECHO_CRESCENT_RANGE), ECHO_CRESCENT_HALF_W * 0.75, maxf(0.45, state_timer + MAIN_SLASH_TIME), 0.0, "sky", "ice")
			if state_timer > 0.16 * get_tell_scale():
				_face_point(tgt, 4.2, dt)
				_main_dir = Vector2.from_angle(facing)
				if tgt.distance_to(_echo_pos) > 1.0:
					_echo_dir = (tgt - _echo_pos).normalized()
				_aim_mirror_at(tgt),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_main_hit = false; _echo_fired = false; _echo_hit = false
			_main_dir = Vector2.from_angle(facing)
			_trigger_mirror_echo()
			_boss_impact(0.16, 76.0, 80.0)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			_step_blink_slash_commit(dt, el),
	})

	# Attack 3: Eclipse Spear Rain — rains lunar rings on Wick & nearest perimeter corners + gap ring
	register_attack("eclipse_spear_rain", {
		"weight": 1.25, "tell": 0.56, "commit": 0.34, "recover": 1.10, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			blink_slash_attack = false
			_main_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _main_dir.angle()
			_aim_mirror_at(tgt)
			patterns.emit_rain(ground, _perimeter_targets(tgt, 3), last_tell_duration, 20.0, 1.0, "sky", "coral")
			stage.play_sfx("mirror_ping", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 8 if phase >= 2 else 7, 124.0, a + PI * 0.42, 0.88, {"color": "ice", "source": "harbinger_eclipse_ring", "reflectable": true})
			patterns.emit_lane(pos, _main_dir, 2, 138.0, 0.09, {"color": "sky", "source": "harbinger_lance", "reflectable": true})
			_trigger_mirror_echo()
			stage.shake(0.14)
			stage.play_sfx("harbinger_wave_fire", pos),
	})

	# Attack 4 (P2): Eclipse Mirror Volley — crossfire lanes from Harbinger + Eclipse Mirror + boomerang
	register_attack("eclipse_mirror_volley", {
		"phases": [2], "weight": 2.20, "tell": 0.56, "commit": 0.42, "recover": 1.16, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			blink_slash_attack = false
			_feint_side = -_feint_side
			_do_lateral_feint(tgt, 28.0)
			_main_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _main_dir.angle()
			_aim_mirror_at(tgt)
			ground.warn_lane(pos, clamp_to_arena(pos + _main_dir * 165.0), 9.0, last_tell_duration, 0.0, "coral", "gold")
			if _mirror_active:
				ground.warn_lane(_mirror_pos, clamp_to_arena(_mirror_pos + _mirror_dir * 155.0), 8.5, last_tell_duration, 0.0, "sky", "ice")
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.06, 19.0, 1.0, "plum", "coral")
			stage.play_sfx("moonshade_blink", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _main_dir, 3, 0.56, 136.0, {"color": "coral", "source": "harbinger_cross_main", "reflectable": true})
			patterns.emit_boomerang(pos, _main_dir.rotated(0.28 * _feint_side), 132.0, 0.65, 0.60 * _feint_side, {"color": "sky", "source": "harbinger_crescent", "reflectable": true})
			if _mirror_active:
				patterns.emit_fan(_mirror_pos, _mirror_dir, 3, 0.50, 128.0, {"color": "ice", "source": "harbinger_mirror_cross", "reflectable": true})
			_trigger_mirror_echo()
			stage.shake(0.16)
			stage.play_sfx("harbinger_wave_fire", pos),
	})


func _on_reset_encounter() -> void:
	intro_duration = 0.48
	_checkpoint_phase = 1
	blink_slash_attack = false
	shield_hp = shield_max; shield_gone_t = 0.0
	_feint_done = false; _main_dir = Vector2.from_angle(facing); _main_hit = false
	_echo_pos = home; _echo_dir = _main_dir; _echo_fired = false; _echo_hit = false
	_armour_glint_t = 0.0; _guard_cracked_t = 0.0; _clank_sfx_cd = 0.0; _saw_first_tell = false
	_phase_times = {1: 0.0, 2: 0.0}
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", true)
		if _west_brazier_ref is CanvasItem: (_west_brazier_ref as CanvasItem).queue_redraw()
	_west_brazier_ref = null
	_west_brazier_pos = _safe_arena_point(home + Vector2(-72.0, 0.0))
	_west_brazier_snuffed = false
	_mirror_active = false
	_mirror_pos = _safe_arena_point(home + Vector2(68.0, -14.0))
	_mirror_dir = Vector2.LEFT
	_mirror_firing = false; _mirror_fire_t = 0.0; _mirror_hit = false
	_mirror_respawn_t = 0.0; _mirror_shatter_t = 0.0
	_find_west_brazier()


func _on_engage() -> void:
	if _checkpoint_phase >= 2:
		_setup_phase2_arena()


func _on_attack_recover_start(_attack_id: String) -> void:
	blink_slash_attack = false


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.IDLE and boss_state != BossState.DEATH:
		_phase_times[phase] = float(_phase_times.get(phase, 0.0)) + dt
	if boss_state == BossState.TELL:
		_saw_first_tell = true
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	_guard_cracked_t = maxf(0.0, _guard_cracked_t - dt)
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	_mirror_shatter_t = maxf(0.0, _mirror_shatter_t - dt)
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
			shield_reformed.emit(self, pos)
			stage.play_sfx("warden_shield_reform", pos)
	_tick_eclipse_mirror(dt)


func _on_phase_enter(new_phase: int) -> void:
	blink_slash_attack = false
	_guard_cracked_t = 0.0
	if new_phase == 2:
		_save_checkpoint(2)
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0; shield_hp = shield_max * 0.65
			shield_reformed.emit(self, pos)
		_setup_phase2_arena()
		_boss_impact(0.26, 94.0, 94.0)
		stage.darkness_pulse(0.64, 1.0)
		stage.play_sfx("night_harbinger_phase2", pos)


func _setup_phase2_arena() -> void:
	_summon_eclipse_mirror()
	var c: Vector2 = arena_rect.get_center()
	_place_safe_tile(c + Vector2(-72.0, -32.0), "mirror")
	_place_safe_tile(c + Vector2(72.0, 32.0), "mirror")
	if props.get_prop("nh_obelisk_w").is_empty():
		props.spawn_pillar(_safe_arena_point(c + Vector2(-52.0, 22.0)), 4.5, "nh_obelisk_w")
	if props.get_prop("nh_obelisk_e").is_empty():
		props.spawn_pillar(_safe_arena_point(c + Vector2(52.0, -22.0)), 4.5, "nh_obelisk_e")


func _step_blink_slash_commit(dt: float, el: float) -> void:
	if el <= MAIN_SLASH_TIME:
		move_boss(_main_dir * 155.0 * dt, false)
		if not _main_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= MAIN_SLASH_R and (wv.length() < 0.01 or absf(angle_difference(_main_dir.angle(), wv.angle())) <= MAIN_SLASH_ARC):
				_main_hit = true
				emit_boss_damage(_main_dir, 1.0, "harbinger_slash", pos, true)
		if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= MAIN_SLASH_R and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	else:
		if not _echo_fired:
			_echo_fired = true
			LxDamageFx.boss_impact(_echo_pos, 0.14, 70.0, 74.0, 68.0, 1.32, 0.28, "ice")
			stage.play_sfx("harbinger_wave_fire", _echo_pos)
			patterns.emit_fan(_echo_pos, _echo_dir, 2 if phase >= 2 else 1, 0.36, 134.0, {"color": "sky", "source": "harbinger_echo_wave", "reflectable": true})
		var e_prog: float = clampf((el - MAIN_SLASH_TIME) / ECHO_SLASH_TIME, 0.0, 1.0)
		var arc_p: Vector2 = _echo_pos + _echo_dir * lerpf(8.0, ECHO_CRESCENT_RANGE, e_prog)
		if not _echo_hit and _has_player() and arc_p.distance_to(_get_wick_pos()) <= ECHO_CRESCENT_HALF_W:
			_echo_hit = true
			emit_boss_damage(_echo_dir, 1.0, "harbinger_echo_slash", _echo_pos, true)
		if _is_lantern_out() and arc_p.distance_to(_get_lantern_pos()) <= ECHO_CRESCENT_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())


func _has_active_shield() -> bool:
	return shield_hp > 0.001 and shield_gone_t <= 0.0 and boss_state != BossState.STAGGER and boss_state != BossState.DEATH


func _wear_shield(amount: float) -> bool:
	if not _has_active_shield():
		return false
	var mult: float = 1.40 if _is_setting_sold("hit_flash") else 1.0
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amount) * mult)
	if shield_hp <= 0.001:
		shield_hp = 0.0; shield_gone_t = SHIELD_REFORM_DUR; _guard_cracked_t = 1.85
		shield_broken.emit(self, pos)
		stage.play_sfx("warden_shield_break", pos)
		add_stagger(stagger_threshold * 0.85)
		return true
	clank_t = 0.14
	return false


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_blue: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"]) or bool(h["cracks_armour"])
	var is_heavy: bool = is_pierce or bool(h["stagger"]) or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH]

	if _has_active_shield() and (is_blue or is_heavy or float(h["shield_wear"]) >= 1.0):
		_wear_shield(maxf(float(h["shield_wear"]), 1.50 if is_blue else 1.25))
	if is_blue:
		return dmg * (1.45 if (is_punishable() or _guard_cracked_t > 0.0) else 1.15)
	if is_pierce:
		return dmg * (1.20 if (is_punishable() or _guard_cracked_t > 0.0) else 0.92)
	if is_punishable() or _guard_cracked_t > 0.0:
		return dmg * (1.18 if _guard_cracked_t > 0.0 else 1.0)

	var is_front: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < FRONT_GUARD_HALF
	_armour_glint_t = 0.22
	_armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.24
		stage.play_sfx("warden_clank" if is_front else "mirror_ping", pos)
	if _has_active_shield() and is_front:
		if src == LxHit.SOURCE_BOLT:
			_wear_shield(0.24)
			return dmg * 0.18
		return dmg * 0.36
	return dmg * (0.24 if src == LxHit.SOURCE_BOLT else 0.42)


func _on_death_start() -> void:
	blink_slash_attack = false; _mirror_active = false; _mirror_firing = false
	_clear_checkpoint()
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", true)
		if _west_brazier_ref is CanvasItem: (_west_brazier_ref as CanvasItem).queue_redraw()
	stage.revert_tiles(world_ctx)
	stage.light_burst(pos, 104.0, 1.45, 0.45)
	stage.play_sfx("eclipse_mirror_shatter", pos)


# --- P2 Eclipse Brazier & Mirror ---------------------------------------------

func _find_west_brazier() -> void:
	_west_brazier_ref = null
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	var best_x: float = INF
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is Object and str((it_v as Object).get("kind")) == "brazier":
			var bp: Vector2 = (it_v as Object).get("pos") as Vector2
			if bp.x < best_x:
				best_x = bp.x; _west_brazier_ref = it_v as Object; _west_brazier_pos = bp


func _summon_eclipse_mirror() -> void:
	_west_brazier_snuffed = true
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", false)
		if _west_brazier_ref is CanvasItem: (_west_brazier_ref as CanvasItem).queue_redraw()
	_mirror_active = true; _mirror_firing = false; _mirror_fire_t = 0.0; _mirror_hit = false
	_mirror_pos = _safe_arena_point(home + Vector2(68.0, -14.0))
	_aim_mirror_at(_get_wick_pos())


func _aim_mirror_at(tgt: Vector2) -> void:
	if _mirror_active and tgt.distance_to(_mirror_pos) > 1.0:
		_mirror_dir = (tgt - _mirror_pos).normalized()


func _trigger_mirror_echo() -> void:
	if _mirror_active and _saw_first_tell:
		_mirror_firing = true; _mirror_fire_t = 0.0; _mirror_hit = false


func _shatter_eclipse_mirror() -> void:
	if not _mirror_active:
		return
	_mirror_active = false; _mirror_firing = false; _west_brazier_snuffed = false
	_mirror_respawn_t = MIRROR_RESPAWN_CD; _mirror_shatter_t = 0.65
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", true)
		if _west_brazier_ref is CanvasItem: (_west_brazier_ref as CanvasItem).queue_redraw()
	LxDamageFx.boss_impact(_mirror_pos, 0.20, 86.0, 90.0, 88.0, 1.44, 0.36, "gold")
	stage.play_sfx("eclipse_mirror_shatter", _mirror_pos)
	if hp > MIRROR_SHATTER_DMG + 1.0:
		hp -= MIRROR_SHATTER_DMG
	_guard_cracked_t = maxf(_guard_cracked_t, MIRROR_STAGGER_TIME)
	if boss_state != BossState.DEATH and boss_state != BossState.PHASE_SHIFT:
		_release_token(); active_attack_id = ""; blink_slash_attack = false
		stagger_meter = 0.0; stagger_immunity_t = 0.0
		_set_boss_state(BossState.STAGGER, MIRROR_STAGGER_TIME)
		staggered.emit(MIRROR_STAGGER_TIME)


func _tick_eclipse_mirror(dt: float) -> void:
	if boss_state == BossState.DEATH or phase < 2:
		return
	if not _mirror_active:
		if _mirror_respawn_t > 0.0:
			_mirror_respawn_t -= dt
			if _mirror_respawn_t <= 0.0 and boss_state == BossState.READY:
				_summon_eclipse_mirror()
		return
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref) and bool(_west_brazier_ref.get("lit")):
		_shatter_eclipse_mirror(); return
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		for tp: Vector2 in [_west_brazier_pos, _mirror_pos]:
			for bi: int in range(w.bolts.size() - 1, -1, -1):
				var bv: Variant = w.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(tp) <= 14.0:
					w.bolts.remove_at(bi); _shatter_eclipse_mirror(); return
			if w.move_beam != null and w.move_beam.beam_vis_t > 0.0:
				if Geometry2D.get_closest_point_to_segment(tp, w.move_beam.beam_start, w.move_beam.beam_end).distance_to(tp) <= 14.0:
					_shatter_eclipse_mirror(); return
			if w.lantern != null and w.lantern.is_out() and w.lantern.pos.distance_to(tp) <= 18.0:
				_shatter_eclipse_mirror(); return
	if _mirror_firing:
		_mirror_fire_t += dt
		if _mirror_fire_t >= MIRROR_ARC_DELAY:
			var prog: float = clampf((_mirror_fire_t - MIRROR_ARC_DELAY) / MIRROR_ARC_DUR, 0.0, 1.0)
			var arc_p: Vector2 = _mirror_pos + _mirror_dir * lerpf(8.0, MIRROR_ARC_RANGE, prog)
			if not _mirror_hit and _has_player() and arc_p.distance_to(_get_wick_pos()) <= 12.0:
				_mirror_hit = true
				emit_boss_damage(_mirror_dir, 1.0, "harbinger_mirror_arc", _mirror_pos, true)
			if prog >= 1.0:
				_mirror_firing = false


# --- Phase Checkpoint on Retry -----------------------------------------------

func _save_checkpoint(ph: int) -> void:
	var best: int = maxi(ph, get_phase_checkpoint())
	if Lx.state != null: Lx.state.story_flags[CP_FLAG] = best
	if Lx.vars != null: Lx.vars.set_var("island:8", CP_FLAG, best)


func get_phase_checkpoint() -> int:
	var cp: int = 1
	if Lx.state != null: cp = maxi(cp, int(Lx.state.story_flags.get(CP_FLAG, 1)))
	if Lx.vars != null: cp = maxi(cp, int(Lx.vars.get_var("island:8", CP_FLAG, 1)))
	return clampi(cp, 1, 2)


func _clear_checkpoint() -> void:
	if Lx.state != null: Lx.state.story_flags.erase(CP_FLAG)
	if Lx.vars != null: Lx.vars.set_var("island:8", CP_FLAG, 1)


func _apply_retry_checkpoint_if_needed() -> void:
	if Lx.state == null or Lx.state.defeated_bosses.has(boss_id):
		return
	var retries: int = int(Lx.state.boss_retries.get(boss_id, 0))
	var cp: int = get_phase_checkpoint()
	if retries <= 0 or cp < 2:
		return
	_checkpoint_phase = cp; intro_duration = 0.26; phase = cp; hp = max_hp * PHASE2_THRESHOLD
	if not phases_reached.has(cp): phases_reached.append(cp)


# --- Arena & Sold-Setting Helpers --------------------------------------------

func _do_lateral_feint(tgt: Vector2, dist_px: float) -> void:
	var to_t: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
	move_boss(Vector2(-to_t.y, to_t.x) * _feint_side * dist_px, false)
	stage.play_sfx("moonshade_blink", pos)


func _place_safe_tile(world_pt: Vector2, tile_name: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var p: Vector2 = clamp_to_arena(world_pt)
	var tx: int = int(floorf(p.x / 16.0)); var ty: int = int(floorf(p.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 52.0 and cp.distance_to(_get_wick_pos()) > 36.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_name)


func _safe_arena_point(pt: Vector2) -> Vector2:
	var p: Vector2 = clamp_to_arena(pt)
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return p
	if str(world_ctx.call("tile_at", p)) in ["ground", "path", "bridge"]:
		return p
	for r_s: float in [16.0, 32.0, 48.0]:
		for k: int in range(8):
			var cand: Vector2 = clamp_to_arena(p + Vector2.from_angle(float(k) * (TAU / 8.0)) * r_s)
			if str(world_ctx.call("tile_at", cand)) in ["ground", "path", "bridge"]:
				return cand
	return home


func _perimeter_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-14.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


static func _is_setting_sold(setting_id: String) -> bool:
	var sold: LxSold = LxSold.current()
	if sold != null:
		return sold.is_sold(setting_id)
	if Lx.vars != null:
		return bool(Lx.vars.get_var("island:8", "sold_" + setting_id, Lx.vars.get_var("game", "sold_" + setting_id, false)))
	return false


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["phase_times"] = _phase_times.duplicate()
	d["checkpoint_phase"] = get_phase_checkpoint()
	d["mirror_active"] = _mirror_active
	return d


func _body_color() -> Color:
	return (PAL["plum"] if phase >= 2 else PAL["deep"]) as Color


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	Visuals.draw_harbinger(self, off)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.44, 0.40)
