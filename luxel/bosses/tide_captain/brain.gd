class_name LxTideCaptainBoss
extends LxBossBase
## Tidewater Harbor Grand Mini-Boss (Island 2, `lighthouse_r6`): Tide Captain (Bible §4.6).
## 2 phases on LxBossBase. Armored brass-claw carapace chips plain bolts outside punish windows
## with a sea-gold armour glint; Blue / Prism-Split hits shatter his active claw guard for a 1.6s
## 1.5x Guard-Crack stagger!
## Preserves B2 upgrades: Brine Surge Cone, P2 Lateral Claw-Rush Feint, P2 Double Cross-Surge
## (twin +-45 deg cones with safe center lane), P2 sluice basin flood (`tower_tide -> "mid"`),
## drifting mirrors (pinned by Ballast Clamp / hung lantern), and floating bicorne hat beat!

const FRONT_GUARD_HALF: float = 1.05
const SHIELD_MAX_HP: float = 4.0
const SHIELD_GONE_DUR: float = 6.2
const GUARD_CRACK_STAGGER: float = 1.60
const GUARD_CRACK_MULT: float = 1.50
const SURGE_START_R: float = 10.0
const SURGE_MAX_R: float = 60.0
const SURGE_HALF_ARC: float = 0.48
const CROSS_OFFSET_RAD: float = 0.785
const CROSS_HALF_ARC: float = 0.34
const SURGE_BAND: float = 12.0
const FEINT_DIST: float = 18.0

var shield_max: float = SHIELD_MAX_HP
var shield_hp: float = SHIELD_MAX_HP
var shield_gone_t: float = 0.0
var guard_cracked_t: float = 0.0

var _surge_dir: Vector2 = Vector2.RIGHT
var _surge_progress: float = 0.0
var _surge_hit: bool = false
var _cross_active: bool = false
var _rush_dir: Vector2 = Vector2.RIGHT
var _feint_done: bool = false
var _feint_side: float = 1.0
var _feint_ghost_pos: Vector2 = Vector2.ZERO
var _feint_ghost_t: float = 0.0
var _hat_float_t: float = 0.0
var _hat_pos: Vector2 = Vector2.ZERO
var _p2_flood_active: bool = false
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "tide_captain"
	boss_id = "tide_captain"
	boss_name_key = "MINIBOSS_2"
	island_id = 2
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 90.0
	hp = 90.0
	body_radius = 8.0
	move_speed = 38.0
	stagger_threshold = 14.0
	stagger_duration = 1.55
	punish_dmg_mult = 1.18
	post_recover_cd = 0.36
	shard_drop = 18
	intro_duration = 0.60
	phase_shift_duration = 0.65
	death_duration = 2.0


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "lighthouse_r6":
		arena_rect = Rect2(176.0, 88.0, 176.0, 80.0)
	configure_phases([0.50])

	# Attack 1: Brine Surge Cone — sweeping saltwater cone + aimed brine fan
	register_attack("brine_surge_cone", {
		"weight": 1.25, "tell": 0.58, "commit": 0.34, "recover": 1.15, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cross_active = false
			_surge_progress = 0.0
			_surge_hit = false
			_surge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _surge_dir.angle()
			ground.warn_sector(pos, facing - SURGE_HALF_ARC, facing + SURGE_HALF_ARC, SURGE_MAX_R, last_tell_duration, 0.0, "sky", "coral")
			stage.play_sfx("tide_captain_slam_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, _dt: float, _prog: float) -> void:
			if state_timer > 0.20 * get_tell_scale() and tgt.distance_to(pos) > 1.0:
				_surge_dir = Vector2.from_angle(facing),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_surge_progress = 0.0
			_surge_hit = false
			_surge_dir = Vector2.from_angle(facing)
			patterns.emit_fan(pos, _surge_dir, 5 if phase >= 2 else 3, 0.82, 126.0, {"color": "sky", "source": "tide_surge_bolt", "damage": 0.5})
			_boss_impact(0.18, 84.0, 88.0)
			stage.play_sfx("tide_captain_slam_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_surge_wave(el, 0.34, false),
	})

	# Attack 2: Claw-Rush Cleave — advancing lunge + P2 Lateral Claw-Rush Feint!
	register_attack("claw_rush_cleave", {
		"weight": 1.20, "tell": 0.54, "commit": 0.36, "recover": 1.08, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_feint_done = false
			_feint_side = -_feint_side
			_rush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _rush_dir.angle()
			ground.warn_lane(pos, pos + _rush_dir * 60.0, 10.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_swing", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
			if phase >= 2 and not _feint_done and prog >= 0.35:
				_feint_done = true
				_feint_ghost_pos = pos
				_feint_ghost_t = 0.30
				var to_f: Vector2 = tgt - pos
				var perp: Vector2 = (to_f.normalized() if to_f.length() > 0.1 else _rush_dir).rotated(PI * 0.5 * _feint_side)
				move_boss(perp * FEINT_DIST, false)
				if tgt.distance_to(pos) > 1.0:
					_rush_dir = (tgt - pos).normalized()
					facing = _rush_dir.angle()
				stage.play_sfx("tide_captain_feint", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _rush_dir, 5 if phase >= 2 else 3, 0.74, 128.0, {"color": "coral", "source": "claw_cleave", "damage": 0.5})
			stage.shake(0.15)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_rush_dir * 108.0 * dt, false)
			check_contact_damage(body_radius + 11.0, _rush_dir, 0.5, "claw_rush"),
	})

	# Attack 3: Harbor Squall Barrage — targeted brine geysers + perimeter corner pressure + lane bolts
	register_attack("harbor_squall_barrage", {
		"weight": 1.15, "tell": 0.56, "commit": 0.32, "recover": 1.08, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_rush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _rush_dir.angle()
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 24.0, 0.5, "sky", "coral")
			ground.warn_lane(pos, pos + _rush_dir * 58.0, 8.0, last_tell_duration, 0.0, "ice", "gold")
			stage.play_sfx("tide_captain_slam_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _rush_dir, 4 if phase >= 2 else 3, 134.0, 0.09, {"color": "ice", "source": "harbor_squall", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("tide_surge", pos),
	})

	# Attack 4 (P2): Double Cross-Surge — twin +-45 deg surge cones with safe center lane!
	register_attack("double_cross_surge", {
		"phases": [2], "weight": 1.95, "tell": 0.60, "commit": 0.36, "recover": 1.25, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cross_active = true
			_surge_progress = 0.0
			_surge_hit = false
			_surge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _surge_dir.angle()
			for sgn: float in [-1.0, 1.0]:
				var ca: float = facing + sgn * CROSS_OFFSET_RAD
				ground.warn_sector(pos, ca - CROSS_HALF_ARC, ca + CROSS_HALF_ARC, SURGE_MAX_R, last_tell_duration, 0.0, "sky", "coral")
			ground.warn_ring(tgt, 24.0, last_tell_duration + 0.06, 0.5, "coral", "gold")
			stage.play_sfx("tide_captain_slam_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_surge_progress = 0.0
			_surge_hit = false
			_surge_dir = Vector2.from_angle(facing)
			patterns.emit_fan(pos, _surge_dir.rotated(-CROSS_OFFSET_RAD), 3, 0.56, 138.0, {"color": "sky", "source": "cross_surge", "damage": 0.5})
			patterns.emit_fan(pos, _surge_dir.rotated(CROSS_OFFSET_RAD), 3, 0.56, 138.0, {"color": "sky", "source": "cross_surge", "damage": 0.5})
			_boss_impact(0.20, 88.0, 90.0)
			stage.play_sfx("tide_captain_slam_fire", pos)
			stage.play_sfx("tide_surge", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_surge_wave(el, 0.36, true),
	})


func _on_reset_encounter() -> void:
	shield_max = SHIELD_MAX_HP
	shield_hp = SHIELD_MAX_HP
	shield_gone_t = 0.0
	guard_cracked_t = 0.0
	_surge_progress = 0.0
	_surge_hit = false
	_cross_active = false
	_feint_done = false
	_feint_side = 1.0
	_feint_ghost_pos = pos
	_feint_ghost_t = 0.0
	_hat_float_t = 0.0
	_hat_pos = pos
	_p2_flood_active = false
	_clank_sfx_cd = 0.0


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_p2_flood_active = true
		_hat_float_t = 1.80
		_hat_pos = pos + Vector2(-18.0, -14.0)
		guard_cracked_t = 0.0
		if shield_gone_t <= 0.0:
			shield_hp = maxf(shield_hp, shield_max * 0.65)
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:lighthouse", "tower_tide", "mid")
		# P2 Arena Mutation: sluice flood carves outer basin rim pockets (reverted cleanly on retry/death!)
		var c: Vector2 = arena_rect.get_center()
		_flood_safe_tile_near(c + Vector2(-48.0, -72.0))
		_flood_safe_tile_near(c + Vector2(56.0, -72.0))
		_flood_safe_tile_near(c + Vector2(-48.0, 64.0))
		props.spawn_pillar(clamp_to_arena(c + Vector2(-72.0, 26.0)), 4.0, "tide_piling_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(72.0, -26.0)), 4.0, "tide_piling_e")
		stage.darkness_pulse(0.56, 0.90)
		_boss_impact(0.26, 92.0, 92.0)
		stage.play_sfx("tide_captain_phase2", pos)
		stage.play_sfx("tide_surge", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	guard_cracked_t = maxf(0.0, guard_cracked_t - dt)
	_feint_ghost_t = maxf(0.0, _feint_ghost_t - dt)
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
			stage.play_sfx("warden_shield_reform", pos)
	if _hat_float_t > 0.0:
		_hat_float_t = maxf(0.0, _hat_float_t - dt)
		var u: float = 1.0 - clampf(_hat_float_t / 1.80, 0.0, 1.0)
		var drift_p: Vector2 = pos + Vector2(-24.0 + sin(u * PI * 3.0) * 4.0, -14.0)
		_hat_pos = drift_p.lerp(pos + Vector2(0.0, -body_radius - 6.0), clampf((u - 0.62) / 0.38, 0.0, 1.0))
	if _p2_flood_active:
		_drift_floating_mirrors(dt)


func _has_active_shield() -> bool:
	return shield_hp > 0.0 and shield_gone_t <= 0.0 and boss_state != BossState.STAGGER and boss_state != BossState.DEATH


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	# Signature Blue-Bolt / Prism-Split Guard Crack: shatters active claw guard for 1.6s 1.5x punish!
	if is_blue_hit and _has_active_shield():
		shield_hp = 0.0
		shield_gone_t = SHIELD_GONE_DUR
		guard_cracked_t = GUARD_CRACK_STAGGER
		_boss_impact(0.20, 80.0, 84.0)
		stage.play_sfx("tide_captain_guard_crack", pos)
		stagger_immunity_t = 0.0
		add_stagger(stagger_threshold)
		return dmg * GUARD_CRACK_MULT

	if boss_state == BossState.STAGGER or guard_cracked_t > 0.0:
		return dmg * GUARD_CRACK_MULT

	var rel: Vector2 = orig - pos
	var rear_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) > 1.95
	var front_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) < FRONT_GUARD_HALF

	if rear_hit or is_blue_hit:
		return dmg * 1.30
	if is_punishable():
		if heavy and _has_active_shield():
			_wear_shield(float(h["shield_wear"]))
		return dmg * (1.20 if heavy else 1.0)
	if heavy:
		if _has_active_shield():
			_wear_shield(float(h["shield_wear"]) * 1.15)
		return dmg * 1.15

	# Armored brass-claw carapace outside punish windows: reduced bolt chip + clear armour glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crab_shell_clank", pos)
	if _has_active_shield():
		_wear_shield(0.18)
	return dmg * (0.24 if (front_hit and _has_active_shield()) else 0.32)


func _wear_shield(amt: float) -> void:
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amt))
	if shield_hp <= 0.001:
		shield_hp = 0.0
		shield_gone_t = SHIELD_GONE_DUR
		guard_cracked_t = maxf(guard_cracked_t, 1.20)
		stage.play_sfx("tide_captain_guard_crack", pos)
		add_stagger(stagger_threshold * 0.65)


func _step_surge_wave(elapsed: float, dur: float, is_cross: bool) -> void:
	_surge_progress = clampf(elapsed / maxf(dur, 0.05), 0.0, 1.0)
	var wave_r: float = lerpf(SURGE_START_R, SURGE_MAX_R, _surge_progress)
	var cones: Array[Vector2] = _surge_cones(_surge_dir.angle(), is_cross)
	if not _surge_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		var wd: float = wv.length()
		if wd > 0.1 and absf(wd - wave_r) <= SURGE_BAND:
			for ci: Vector2 in cones:
				if absf(angle_difference(ci.x, wv.angle())) <= ci.y:
					_surge_hit = true
					var push_d: Vector2 = Vector2.from_angle(ci.x)
					emit_boss_damage(push_d, 0.5, "brine_surge", pos, true)
					if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil") and arena_rect.grow(-22.0).has_point(_get_wick_pos() + push_d * 20.0):
						Lx.player.call("apply_recoil", push_d * 42.0)
					break
	if _is_lantern_out():
		var lv: Vector2 = _get_lantern_pos() - pos
		if lv.length() <= wave_r + 4.0:
			for ci: Vector2 in cones:
				if lv.length() < 0.1 or absf(angle_difference(ci.x, lv.angle())) <= ci.y:
					if Lx.events != null:
						Lx.events.lantern_struck.emit(_get_lantern_pos())
					break


func _surge_cones(base_a: float, is_cross: bool) -> Array[Vector2]:
	if is_cross:
		return [Vector2(base_a - CROSS_OFFSET_RAD, CROSS_HALF_ARC), Vector2(base_a + CROSS_OFFSET_RAD, CROSS_HALF_ARC)]
	return [Vector2(base_a, SURGE_HALF_ARC)]


func _drift_floating_mirrors(dt: float) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	var idx: int = 0
	for it_v: Variant in world_ctx.call("get_interactables") as Array:
		if not (it_v is LxMirror) or not is_instance_valid(it_v):
			continue
		var m: LxMirror = it_v as LxMirror
		idx += 1
		if lan_out and m.pos.distance_to(lan_p) <= 22.0:
			continue # Ballast Clamp pins drifting mirror steady!
		var dx: float = sin(anim_t * 1.15 + float(idx) * 2.1) * 7.0 * dt
		var cand: Vector2 = m.pos + Vector2(dx, 0.0)
		if world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", cand)) != "wall":
			m.pos = cand
			m.position = cand.round()


func _flood_safe_tile_near(world_pt: Vector2) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var tx: int = int(floorf(world_pt.x / 16.0))
	var ty: int = int(floorf(world_pt.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 44.0 and cp.distance_to(_get_wick_pos()) > 28.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "water")


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
	_p2_flood_active = false
	stage.revert_tiles(world_ctx)
	stage.play_sfx("tide_captain_phase2", pos)


func _body_color() -> Color:
	return (PAL["wine"] if phase >= 2 else PAL["coral"]) as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P2 basin tide foam ripples around Captain
	if _p2_flood_active and not is_flash_reduced():
		var fr: float = 24.0 + fmod(anim_t * 22.0, 26.0)
		draw_arc(c, fr, 0.0, TAU, 20, Color(PAL["sky"] as Color, 0.32), 1.0)
	# Personality beat: bicorne hat pops off & bobs on P2 tide before he snatches it back!
	if _hat_float_t > 0.0:
		var hp_l: Vector2 = (_hat_pos - pos + off).round()
		draw_line(hp_l + Vector2(-7.0, 0.0), hp_l + Vector2(7.0, 0.0), PAL["deep"] as Color, 3.0)
		draw_line(hp_l + Vector2(-4.5, -2.5), hp_l + Vector2(4.5, -2.5), PAL["gold"] as Color, 2.0)
	if _feint_ghost_t > 0.0:
		var gp: Vector2 = (_feint_ghost_pos - pos + off).round()
		draw_line(gp, c, PAL["void"] as Color, 3.0)
		draw_line(gp, c, PAL["sky"] as Color, 1.0)
		draw_arc(gp, body_radius, 0.0, TAU, 12, PAL["void"] as Color, 3.0)
		draw_arc(gp, body_radius, 0.0, TAU, 12, PAL["ice"] as Color, 1.0)
	if guard_cracked_t > 0.0:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 18, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 18, PAL["sky"] as Color, 2.0)
		draw_arc(c, body_radius + 2.5, 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	# Active Brine Surge / Cross-Surge wave visual
	if boss_state == BossState.COMMIT and active_attack_id in ["brine_surge_cone", "double_cross_surge"]:
		var wave_r: float = lerpf(SURGE_START_R, SURGE_MAX_R, _surge_progress)
		for ci: Vector2 in _surge_cones(_surge_dir.angle(), _cross_active):
			var a0: float = ci.x - ci.y
			var a1: float = ci.x + ci.y
			draw_arc(c, wave_r, a0, a1, 16, PAL["void"] as Color, 5.0)
			draw_arc(c, wave_r + 3.0, a0, a1, 16, PAL["deep"] as Color, 2.0)
			draw_arc(c, wave_r, a0, a1, 16, PAL["sky"] as Color, 3.0)
			draw_arc(c, maxf(3.0, wave_r - 2.4), a0, a1, 14, PAL["ice"] as Color, 2.0)
			draw_arc(c, maxf(3.0, wave_r - 3.6), a0, a1, 12, PAL["cream"] as Color, 1.0)
	# Armour glint outside punish windows vs golden punish halo
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.0, facing - 1.1, facing + 1.1, 14, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 5.0, facing - 1.1, facing + 1.1, 14, PAL["cream"] as Color, 2.0)
		draw_arc(c, body_radius + 7.0, facing - 0.85, facing + 0.85, 12, PAL["gold"] as Color, 1.0)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 2.0)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.10, 1.38, 0.38, "ice")
