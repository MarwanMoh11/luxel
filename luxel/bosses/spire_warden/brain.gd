class_name LxSpireWardenBoss
extends LxBossBase
## Mirror Spire Mini-Boss #1 (Island 7, spire_r6): MOONSHADE WARDEN migrated onto LxBossBase.
## Preserves spire_warden sprite, boss_id = "moonshade_warden", prismatic mirror-buckler,
## Moon-Mirror Pedestal synergy, and Island 7 Bible 4.5 upgrades:
## - Prismatic buckler + lunar plate armour outside punish windows (yellow bolts chip with rose-ice glint).
## - Banking a Blue Bolt (SOURCE_PRISM / is_blue) shatters BOTH buckler and Silver Blink-Ghost for 1.80s stagger!
## - P2 (<= 55% HP): Flips arena to BLACK while leaving a solid Silver Blink-Ghost executing
##   crossing spear lanes + 0.50s horror after-swing, carves obsidian reflection pits, and raises crystal pillars.
## - Flipping a moon_pool back to Silver erases the Silver Blink-Ghost cleanly.

signal shield_broken(enemy: LxEnemyBrain, at_pos: Vector2)
signal shield_reformed(enemy: LxEnemyBrain, at_pos: Vector2)

const FRONT_GUARD_HALF: float = 1.08
const SPEAR_COMMIT_TIME: float = 0.26
const MIRROR_COMMIT_TIME: float = 0.22
const SPEAR_RANGE: float = 104.0
const SPEAR_LUNGE_SPEED: float = 200.0
const SPEAR_ARC_R: float = 28.0
const SPEAR_HALF_ARC: float = 0.95
const MIRROR_RANGE: float = 92.0
const MIRROR_HALF_W: float = 10.0
const BLINK_DIST: float = 26.0
const GUARD_CRACK_STAGGER_P1: float = 1.35
const GUARD_CRACK_STAGGER_P2: float = 1.80
const GUARD_CRACK_MULT: float = 1.45
const GHOST_HORROR_LINGER: float = 0.50

var shield_max: float = 3.0
var shield_hp: float = 3.0
var shield_gone_duration: float = 4.6
var shield_gone_t: float = 0.0

var spear_dir: Vector2 = Vector2.RIGHT
var mirror_pos: Vector2 = Vector2.ZERO
var mirror_dir: Vector2 = Vector2.RIGHT
var feint_done: bool = false
var feint_side: float = 1.0
var _spear_hit: bool = false
var _mirror_fired: bool = false
var _mirror_hit: bool = false
var guard_cracked_t: float = 0.0
var shimmer_t: float = 0.0
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0

var silver_ghost_active: bool = false
var silver_ghost_linger_t: float = 0.0
var _p2_flipped_black: bool = false
var _ghost_respawn_cd: float = 0.0
var _prev_world_face: String = "silver"


func _init() -> void:
	super._init()
	kind = "spire_warden"
	boss_id = "moonshade_warden"
	boss_name_key = "MINIBOSS_7"
	island_id = 7
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 290.0
	hp = 290.0
	body_radius = 7.5
	move_speed = 38.0
	stagger_threshold = 24.0
	stagger_duration = 1.75
	punish_dmg_mult = 1.25
	post_recover_cd = 0.42
	intro_duration = 0.45
	phase_shift_duration = 0.62
	death_duration = 1.8
	shard_drop = 16


func _configure_boss(spec: Dictionary) -> void:
	# Override legacy spire_r6.json max_hp=7.5 with tuned Epic LxBossBase HP
	var base_hp: float = 290.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	kind = "spire_warden"
	boss_id = str(spec.get("boss_id", "moonshade_warden"))
	island_id = int(spec.get("island_id", 7))
	configure_phases([0.55])

	# Attack 1: Lunar Arc — prismatic halberd sweep + sky/ice crescent fan
	register_attack("lunar_arc", {
		"weight": 1.25, "tell": 0.50, "commit": 0.28, "recover": 1.10, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			spear_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = spear_dir.angle()
			ground.warn_sector(pos, facing - 1.05, facing + 1.05, 40.0, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_lane(pos, clamp_to_arena(pos + spear_dir * 165.0), 8.0, last_tell_duration, 0.0, "rose", "ice")
			stage.play_sfx("moonshade_feint", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 4 if phase >= 2 else 3
			patterns.emit_fan(pos, spear_dir, cnt, 0.76, 114.0 if phase >= 2 else 104.0, {"color": "ice", "source": "spire_lunar_arc", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(spear_dir * 58.0 * dt, false),
	})

	# Attack 2: Prismatic Spear Lunge — lateral blink-feint + lunge + P2 Silver Blink-Ghost lane & 0.50s horror linger!
	register_attack("prismatic_spear_lunge", {
		"weight": 1.35, "tell": 0.56, "commit": 0.48, "recover": 1.15, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			feint_done = false
			feint_side = -feint_side
			mirror_pos = pos
			spear_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = spear_dir.angle()
			mirror_dir = spear_dir
			_spear_hit = false
			_mirror_fired = false
			_mirror_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + spear_dir * SPEAR_RANGE), 11.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("harbinger_wave_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, dt: float, _prog: float) -> void:
			if phase >= 2 and not feint_done and state_timer <= last_tell_duration * 0.62:
				feint_done = true
				mirror_pos = pos
				_do_lateral_feint(tgt, BLINK_DIST)
				mirror_dir = (tgt - mirror_pos).normalized() if tgt.distance_to(mirror_pos) > 1.0 else spear_dir
				if silver_ghost_active or _is_spire_black():
					ground.warn_lane(mirror_pos, clamp_to_arena(mirror_pos + mirror_dir * MIRROR_RANGE), MIRROR_HALF_W, maxf(0.45, state_timer + SPEAR_COMMIT_TIME), 0.0, "sky", "ice")
			if state_timer > 0.16:
				_face_point(tgt, 4.0, dt)
				spear_dir = Vector2.from_angle(facing)
				if tgt.distance_to(mirror_pos) > 1.0:
					mirror_dir = (tgt - mirror_pos).normalized(),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var has_ghost: bool = phase >= 2 and feint_done and (silver_ghost_active or _is_spire_black())
			state_timer = (SPEAR_COMMIT_TIME + MIRROR_COMMIT_TIME) if has_ghost else SPEAR_COMMIT_TIME
			_spear_hit = false
			_mirror_fired = false
			_mirror_hit = false
			spear_dir = Vector2.from_angle(facing)
			LxDamageFx.boss_impact(pos, 0.16, 76.0, 80.0, 82.0, 1.38, 0.34, "ice")
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			_step_spear_commit(dt, el),
	})

	# Attack 3: Mirror Shard Barrage — rains lunar crystal rings on Wick & corners + gap-ring (anti-safe-spot!)
	register_attack("mirror_shard_barrage", {
		"weight": 1.15, "tell": 0.56, "commit": 0.32, "recover": 1.15, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			spear_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var spots: Array[Vector2] = _perimeter_targets(tgt, 3)
			patterns.emit_rain(ground, spots, last_tell_duration, 15.0, 1.0, "sky", "ice")
			stage.play_sfx("mirror_ping", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 6, 102.0, a + PI * 0.42, 0.96, {"color": "ice", "source": "spire_shard_ring", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("lens_reveal", pos),
	})

	# Attack 4 (P2): Cross-World Blink — Silver Blink-Ghost & Black Warden fire crossing spear lanes!
	register_attack("cross_world_blink", {
		"phases": [2], "weight": 4.20, "tell": 0.54, "commit": 0.44, "recover": 1.15, "cooldown": 0.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			feint_side = -feint_side
			mirror_pos = pos
			_do_lateral_feint(tgt, 36.0)
			spear_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			mirror_dir = (tgt - mirror_pos).normalized() if tgt.distance_to(mirror_pos) > 1.0 else -spear_dir
			facing = spear_dir.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + spear_dir * 160.0), 10.0, last_tell_duration, 0.0, "rose", "gold")
			ground.warn_lane(mirror_pos, clamp_to_arena(mirror_pos + mirror_dir * 160.0), 10.0, last_tell_duration, 0.0, "sky", "ice")
			stage.play_sfx("moonshade_blink", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, spear_dir, 3, 0.56, 118.0, {"color": "rose", "source": "spire_cross_black", "reflectable": true})
			if silver_ghost_active or _is_spire_black():
				patterns.emit_fan(mirror_pos, mirror_dir, 3, 0.52, 112.0, {"color": "ice", "source": "spire_cross_silver", "reflectable": true})
				silver_ghost_linger_t = GHOST_HORROR_LINGER
			stage.shake(0.18)
			stage.play_sfx("lens_reveal", pos),
	})


func _on_reset_encounter() -> void:
	shield_hp = shield_max
	shield_gone_t = 0.0
	feint_done = false
	_spear_hit = false
	_mirror_fired = false
	_mirror_hit = false
	guard_cracked_t = 0.0
	shimmer_t = 0.0
	_armour_glint_t = 0.0
	silver_ghost_active = false
	silver_ghost_linger_t = 0.0
	_ghost_respawn_cd = 0.0
	mirror_pos = home
	if _p2_flipped_black:
		_p2_flipped_black = false
		_set_spire_face(_prev_world_face)
	_prev_world_face = "black" if _is_spire_black() else "silver"


func _on_attack_recover_start(attack_id: String) -> void:
	if attack_id == "prismatic_spear_lunge" and phase >= 2 and silver_ghost_active:
		silver_ghost_linger_t = GHOST_HORROR_LINGER


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	guard_cracked_t = maxf(0.0, guard_cracked_t - dt)
	shimmer_t = maxf(0.0, shimmer_t - dt)
	silver_ghost_linger_t = maxf(0.0, silver_ghost_linger_t - dt)
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
			shield_reformed.emit(self, pos)
			stage.play_sfx("warden_shield_reform", pos)
	if phase >= 2:
		if silver_ghost_active and _p2_flipped_black and Lx.vars != null and not _is_spire_black():
			silver_ghost_active = false
			silver_ghost_linger_t = 0.0
			_p2_flipped_black = false
			_ghost_respawn_cd = 6.5
			stage.play_sfx("shield_shatter", pos)
		elif not silver_ghost_active and _ghost_respawn_cd > 0.0:
			_ghost_respawn_cd = maxf(0.0, _ghost_respawn_cd - dt)
			if _ghost_respawn_cd <= 0.0 and _is_spire_black():
				silver_ghost_active = true
				mirror_pos = pos


func _step_spear_commit(dt: float, el: float) -> void:
	if el <= SPEAR_COMMIT_TIME:
		move_boss(spear_dir * (SPEAR_LUNGE_SPEED * (1.12 if phase >= 2 else 1.0)) * dt, false)
		if not _spear_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= SPEAR_ARC_R and (wv.length() < 0.01 or absf(angle_difference(spear_dir.angle(), wv.angle())) <= SPEAR_HALF_ARC):
				_spear_hit = true
				emit_boss_damage(spear_dir, 1.0, "spire_spear", pos, true)
		if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= SPEAR_ARC_R and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	elif phase >= 2 and feint_done and (silver_ghost_active or _is_spire_black()):
		if not _mirror_fired:
			_mirror_fired = true
			LxDamageFx.boss_impact(mirror_pos, 0.14, 72.0, 76.0, 68.0, 1.32, 0.28, "ice")
			stage.play_sfx("lens_reveal", mirror_pos)
		var m_prog: float = clampf((el - SPEAR_COMMIT_TIME) / MIRROR_COMMIT_TIME, 0.0, 1.0)
		var m_pt: Vector2 = mirror_pos + mirror_dir * lerpf(8.0, MIRROR_RANGE, m_prog)
		if not _mirror_hit and _has_player() and m_pt.distance_to(_get_wick_pos()) <= MIRROR_HALF_W:
			_mirror_hit = true
			emit_boss_damage(mirror_dir, 1.0, "spire_ghost_spear", mirror_pos, true)
		if _is_lantern_out() and m_pt.distance_to(_get_lantern_pos()) <= MIRROR_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() > 42.0:
		move_boss(to_h.normalized() * move_speed * dt, false)
		return
	super._step_boss_reposition(dt, target)


func _do_lateral_feint(tgt: Vector2, dist_px: float) -> void:
	var to_t: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
	var lat: Vector2 = Vector2(-to_t.y, to_t.x) * feint_side
	var cand: Vector2 = pos + lat * dist_px
	if cand.distance_to(home) > 52.0:
		lat = (home - pos).normalized() if home.distance_to(pos) > 4.0 else -lat
	move_boss(lat * dist_px, false)
	stage.play_sfx("moonshade_blink", pos)


func _is_spire_black() -> bool:
	if Lx.vars == null:
		return _p2_flipped_black
	return Lx.vars.eval("world_face==black", 7, "spire_r6")


func _set_spire_face(face_s: String) -> void:
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.set_world_face(LxIsland7Rule.SCOPE_ISLAND, face_s, true, pos)
	elif Lx.vars != null:
		Lx.vars.set_var("island:7", "world_face", face_s)


func _has_active_shield() -> bool:
	return shield_hp > 0.001 and shield_gone_t <= 0.0


func _is_hit_invulnerable() -> bool:
	return boss_state == BossState.PHASE_SHIFT


func _wear_shield(amount: float) -> bool:
	if not _has_active_shield():
		return false
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amount))
	if shield_hp <= 0.001:
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		guard_cracked_t = GUARD_CRACK_STAGGER_P2 if phase >= 2 else GUARD_CRACK_STAGGER_P1
		shield_broken.emit(self, pos)
		stage.play_sfx("warden_shield_break", pos)
		add_stagger(stagger_threshold * 0.85)
		return true
	clank_t = 0.14
	return false


func take_hit(hit: LxHit) -> int:
	if boss_state == BossState.DEATH or hit == null:
		return HitResult.GLANCED
	if not engaged:
		if not arena_rect.grow(2.0).has_point(_get_wick_pos()):
			clank_t = 0.12
			_emit_enemy_hit(hit, HitResult.GLANCED)
			return HitResult.GLANCED
		engage()
	if boss_state == BossState.INTRO or boss_state == BossState.PHASE_SHIFT:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var is_blue_hit: bool = hit.is_blue() or str(h["source"]) == LxHit.SOURCE_PRISM
	if is_blue_hit and (_has_active_shield() or silver_ghost_active):
		var rel: Vector2 = (h["origin"] as Vector2) - pos
		var shattered_both: bool = silver_ghost_active
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		silver_ghost_active = false
		silver_ghost_linger_t = 0.0
		_ghost_respawn_cd = 6.0
		var stag_dur: float = GUARD_CRACK_STAGGER_P2 if (phase >= 2 or shattered_both) else GUARD_CRACK_STAGGER_P1
		guard_cracked_t = stag_dur
		hp = maxf(0.0, hp - float(h["damage"]) * (GUARD_CRACK_MULT + (0.25 if shattered_both else 0.0)))
		flash_t = 0.20
		if rel.length() > 0.01:
			knock = -rel.normalized() * 64.0
		shield_broken.emit(self, pos)
		LxDamageFx.boss_impact(pos, 0.20, 82.0, 86.0, 88.0, 1.38, 0.36, "ice")
		stage.play_sfx("warden_shield_break", pos)
		stage.play_sfx("lens_reveal", pos)
		if shattered_both:
			stage.play_sfx("shield_shatter", pos)
		if hp <= 0.001:
			opened_kill = true
			_begin_death(hit)
			return HitResult.KILLED
		if not _check_phase_thresholds():
			_release_token()
			active_attack_id = ""
			stagger_meter = 0.0
			_set_boss_state(BossState.STAGGER, stag_dur)
			staggered.emit(stag_dur)
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	var is_heavy: bool = is_pierce or bool(h["stagger"]) or bool(h["cracks_armour"]) or float(h["shield_wear"]) >= 1.2 or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH]

	if _has_active_shield() and (is_heavy or float(h["shield_wear"]) >= 1.0):
		_wear_shield(maxf(float(h["shield_wear"]), 1.25))

	if is_pierce:
		return dmg * (1.20 if (is_punishable() or guard_cracked_t > 0.0) else 0.95)
	if is_punishable() or guard_cracked_t > 0.0:
		return dmg * (1.15 if guard_cracked_t > 0.0 else 1.0)

	# Outside punish windows: prismatic buckler & lunar plate armour chip yellow bolts with glint!
	var ang_diff: float = absf(angle_difference(facing, rel.angle())) if rel.length() > 1.0 else 0.0
	var is_front: bool = rel.length() > 1.0 and ang_diff < FRONT_GUARD_HALF
	_armour_glint_t = 0.22
	_armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing
	if _has_active_shield() and is_front:
		clank_t = 0.14
		if src == LxHit.SOURCE_BOLT:
			_wear_shield(0.20)
			stage.play_sfx("warden_clank", pos)
			return dmg * 0.18
		return dmg * 0.36
	clank_t = 0.10
	if src == LxHit.SOURCE_BOLT:
		stage.play_sfx("mirror_ping", pos)
		return dmg * 0.26
	return dmg * 0.42


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		shimmer_t = 0.70
		guard_cracked_t = 0.0
		shield_gone_t = 0.0
		shield_hp = shield_max
		_prev_world_face = "black" if _is_spire_black() else "silver"
		_p2_flipped_black = true
		silver_ghost_active = true
		mirror_pos = clamp_to_arena(pos + Vector2(-28.0, 0.0))
		mirror_dir = Vector2.from_angle(facing)
		_set_spire_face("black")
		shield_reformed.emit(self, pos)
		_carve_safe_pit(0.76, 0.24)
		_carve_safe_pit(0.88, 0.62)
		var c: Vector2 = arena_rect.get_center()
		props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, 26.0)), 4.0, "spire_prism_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, -26.0)), 4.0, "spire_prism_e")
		stage.darkness_pulse(0.64, 1.1)
		stage.shake(0.26)
		stage.play_sfx("boss_roar", pos)
		stage.play_sfx("lens_reveal", pos)


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


func _body_color() -> Color:
	return (PAL["sky"] if phase >= 2 else PAL["deep"]) as Color


func _shield_color() -> Color:
	return (PAL["rose"] if phase >= 2 else PAL["ice"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()

	# Bible 4.5: P2 rose/ice world-split rim
	if phase >= 2 and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 3.2, -PI * 0.5, PI * 0.5, 14, PAL["rose"] as Color, 1.4)
		draw_arc(c, body_radius + 3.2, PI * 0.5, PI * 1.5, 14, PAL["ice"] as Color, 1.4)

	# Armour glint when yellow bolts chip outside punish windows
	if _armour_glint_t > 0.0 and boss_state != BossState.DEATH:
		var ga: float = clampf(_armour_glint_t / 0.22, 0.0, 1.0)
		draw_arc(c, body_radius + 5.0, _armour_glint_ang - 0.80, _armour_glint_ang + 0.80, 10, Color(PAL["ice"] as Color, ga), 2.0)

	# Horror beat: Silver Blink-Ghost keeps swinging 0.50s after Warden stops!
	if silver_ghost_linger_t > 0.0 and silver_ghost_active:
		var mp_l: Vector2 = (mirror_pos - pos + off).round()
		var lu: float = 1.0 - clampf(silver_ghost_linger_t / GHOST_HORROR_LINGER, 0.0, 1.0)
		var sw_a: float = mirror_dir.angle() + sin(lu * TAU) * 1.1
		draw_circle(mp_l, body_radius * 0.72, Color(PAL["ice"] as Color, 0.45 * (1.0 - lu)))
		draw_arc(mp_l, body_radius + 2.0, sw_a - 0.85, sw_a + 0.85, 12, Color(PAL["cream"] as Color, 0.80 * (1.0 - lu)), 1.6)
		draw_line(mp_l, (mp_l + Vector2.from_angle(sw_a) * 24.0).round(), Color(PAL["ice"] as Color, 0.75 * (1.0 - lu)), 1.6)

	if guard_cracked_t > 0.0:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 18, PAL["sky"] as Color, 1.8)
		draw_arc(c, body_radius + 2.5, 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	if shimmer_t > 0.0:
		var sp: float = 1.0 - clampf(shimmer_t / 0.70, 0.0, 1.0)
		draw_arc(c, body_radius + 6.0 + sp * 14.0, 0.0, TAU, 24, PAL["rose"] as Color, 1.8 if fred else 2.2)
		draw_arc(c, body_radius + 3.0 + sp * 9.0, 0.0, TAU, 20, PAL["ice"] as Color, 1.2)

	if boss_state == BossState.COMMIT and active_attack_id == "prismatic_spear_lunge":
		var mp2: Vector2 = (mirror_pos - pos + off).round()
		if _commit_elapsed <= SPEAR_COMMIT_TIME:
			var p1: float = clampf(_commit_elapsed / SPEAR_COMMIT_TIME, 0.0, 1.0)
			var a0: float = spear_dir.angle() - SPEAR_HALF_ARC * 0.90
			var a1: float = lerpf(a0 + 0.30, spear_dir.angle() + SPEAR_HALF_ARC * 0.90, p1)
			draw_arc(c, SPEAR_ARC_R, a0, a1, 16, PAL["blue"] as Color, 3.0)
			draw_arc(c, SPEAR_ARC_R - 2.2, a0, a1, 14, PAL["sky"] as Color, 2.0)
			draw_arc(c, SPEAR_ARC_R - 3.8, a0 + 0.1, a1, 12, PAL["cream"] as Color, 1.1)
		elif phase >= 2 and feint_done and (silver_ghost_active or _is_spire_black()):
			var p2: float = clampf((_commit_elapsed - SPEAR_COMMIT_TIME) / MIRROR_COMMIT_TIME, 0.0, 1.0)
			var tip: Vector2 = (mp2 + mirror_dir * lerpf(8.0, MIRROR_RANGE, p2)).round()
			draw_line(mp2, tip, PAL["sky"] as Color, 2.6)
			draw_line(mp2, tip, PAL["ice"] as Color, 1.6)
			draw_arc(tip, 11.0, mirror_dir.angle() - 1.05, mirror_dir.angle() + 1.05, 12, PAL["cream"] as Color, 1.8)
	elif boss_state == BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(state_timer / maxf(phase_shift_duration, 0.05), 0.0, 1.0)
		var r1: float = body_radius + 10.0 + rp * 18.0
		draw_arc(c, r1, 0.0, TAU, 28, PAL["rose"] as Color, 2.2)
		draw_arc(c, maxf(4.0, r1 - 4.0), 0.0, TAU, 24, PAL["ice"] as Color, 1.6)
		draw_arc(c, maxf(3.0, r1 - 6.5), 0.0, TAU, 20, PAL["cream"] as Color, 1.0)
