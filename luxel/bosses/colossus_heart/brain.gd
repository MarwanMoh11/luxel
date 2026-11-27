class_name LxColossusHeartBoss
extends LxBossBase
## Island 6 Iron Colossus Boss: THE COLOSSUS HEART (`colossus_r11`).
## 3-phase suspended clockwork furnace-heart -> Half-Lantern #2 (`reward_heart = "half"`).
## P1 (100-60%): Chained center core protected by 4 Steam Valves (`props`); shattering valves drops cage!
## P2 (60-25%): PENDULUM DETACH! Swings on heavy brass ceiling tether (`tethers`), doubles ribcage stride,
##              drips live `slag_slime`s — cool a slime with Blue in the pendulum path for a 2.4s MEGA-STAGGER + 6.0 dmg!
## P3 (<=25%): Figure-8 double pendulum sweep + rhythmic 2-beat Heartbeat Shockwaves!

const PENDULUM_ARC_RAD: float = 1.22
const PENDULUM_LEN: float = 64.0
const SLIME_BONK_BONUS_DMG: float = 6.0
const SLIME_BONK_STAGGER: float = 2.4

var _pendulum_pivot: Vector2 = Vector2.ZERO
var _pendulum_dir: float = 1.0
var _pendulum_bonked: bool = false
var _double_beat_fired: bool = false
var _valve_ids: Array[String] = ["valve_nw", "valve_ne", "valve_sw", "valve_se"]
var _cage_dropped_t: float = 0.0
var _slime_bonk_flash_t: float = 0.0
var _drip_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "colossus_heart"
	boss_id = "colossus_heart"
	boss_name_key = "ISL6_BOSS_HEART"
	island_id = 6
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 68.0
	hp = 68.0
	body_radius = 13.0
	move_speed = 28.0
	stagger_threshold = 13.0
	stagger_duration = 2.0
	punish_dmg_mult = 1.65
	post_recover_cd = 0.30
	intro_duration = 0.55
	death_duration = 2.0
	shard_drop = 36


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.64, 0.36])

	# Attack 1 (P1+P2+P3): Heartbeat Shockwave (lub-dub 84px ring + expanding gap volley!)
	register_attack("heartbeat_shockwave", {
		"weight": 1.25, "tell": 0.58, "commit": 0.32, "recover": 1.15, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_ring(pos, 82.0, last_tell_duration, 1.0, "coral", "cream")
			stage.play_sfx("heart_thump", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 128.0 if phase >= 2 else 116.0, gap_a, 0.68, {"color": "coral", "source": "heart_beat"})
			stage.light_burst(pos, 86.0, 1.3, 0.26)
			stage.play_sfx("heart_thump", pos)
			stage.shake(0.20),
	})

	# Attack 2 (P1+P2+P3): Molten Artery Drip (ceiling lava drops targeting Wick + corners + P2 slag_slime!)
	register_attack("molten_artery_drip", {
		"weight": 1.25, "tell": 0.50, "commit": 0.35, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_drip_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "coral", "gold")
			stage.play_sfx("furnace_draw", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.DOWN
			patterns.emit_fan(pos, aim, 5 if phase >= 2 else 3, 0.78, 134.0, {"color": "apricot", "source": "heart_artery"})
			if phase >= 2 and _drip_cd <= 0.0:
				_drip_cd = 10.5
				_try_drip_slag_slime()
			stage.play_sfx("magma_crack", pos)
			stage.shake(0.14),
	})

	# Attack 3 (P1+P2+P3): Valve Steam Cross (4 brass pistons vent steam lanes across the ribcage!)
	register_attack("valve_steam_vent", {
		"weight": 1.15, "tell": 0.54, "commit": 0.30, "recover": 1.15, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var base_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			set_meta("_vent_ang", base_a)
			for k: int in range(4):
				var d: Vector2 = Vector2.from_angle(base_a + float(k) * (PI * 0.5))
				ground.warn_lane(pos, clamp_to_arena(pos + d * 145.0), 10.0, last_tell_duration, 1.0, "apricot", "gold")
			stage.play_sfx("piston_hiss", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var base_a: float = float(get_meta("_vent_ang", 0.0))
			for k: int in range(4):
				var d: Vector2 = Vector2.from_angle(base_a + float(k) * (PI * 0.5))
				patterns.emit_lane(pos, d, 2, 140.0, 0.08, {"color": "gold", "source": "heart_valve"})
			stage.play_sfx("forge_gust", pos)
			stage.shake(0.16),
	})

	# Attack 4 (P2+P3): Pendulum Smash (sweeps 140 deg on brass chain -> SLAMS frozen slag_slime for 2.4s mega-stagger!)
	register_attack("pendulum_smash", {
		"phases": [2, 3],
		"weight": 1.75, "tell": 0.62, "commit": 0.56, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_pendulum_bonked = false
			_pendulum_dir = -_pendulum_dir
			var start_a: float = PI * 0.5 - PENDULUM_ARC_RAD * _pendulum_dir
			var end_a: float = PI * 0.5 + PENDULUM_ARC_RAD * _pendulum_dir
			ground.warn_sector(_pendulum_pivot, minf(start_a, end_a), maxf(start_a, end_a), PENDULUM_LEN + 22.0, last_tell_duration, 0.0, "apricot", "cream")
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("golem_stomp", pos)
			stage.shake(0.18),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			if _pendulum_bonked:
				return
			var u: float = clampf(el / 0.56, 0.0, 1.0)
			var ang: float = lerpf(PI * 0.5 - PENDULUM_ARC_RAD * _pendulum_dir, PI * 0.5 + PENDULUM_ARC_RAD * _pendulum_dir, u)
			var target_p: Vector2 = clamp_to_arena(_pendulum_pivot + Vector2.from_angle(ang) * PENDULUM_LEN)
			pos = target_p
			position = pos.round()
			var sweep_dir: Vector2 = Vector2.from_angle(ang + PI * 0.5 * _pendulum_dir)
			check_contact_damage(body_radius + 12.0, sweep_dir, 1.0, "heart_pendulum")
			_check_frozen_slime_collision(),
	})

	# Attack 5 (P3): Double-Beat Surge (2 rapid heartbeat rings 0.40s apart + molten scatter!)
	register_attack("double_beat_surge", {
		"phases": [3],
		"weight": 3.40, "tell": 0.54, "commit": 0.64, "recover": 1.35, "cooldown": 1.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_double_beat_fired = false
			ground.warn_ring(pos, 84.0, last_tell_duration, 1.0, "coral", "cream")
			patterns.emit_rain(ground, _build_drip_targets(tgt), last_tell_duration + 0.14, 22.0, 1.0, "apricot", "gold")
			stage.play_sfx("heart_thump", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 12, 128.0, gap_a, 0.68, {"color": "coral", "source": "heart_surge_1"})
			stage.play_sfx("heart_thump", pos)
			stage.shake(0.22),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			if el >= 0.40 and not _double_beat_fired:
				_double_beat_fired = true
				var gap_b: float = ((tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0) + 0.35
				patterns.emit_gap_ring(pos, 12, 134.0, gap_b, 0.68, {"color": "gold", "source": "heart_surge_2"})
				stage.light_burst(pos, 96.0, 1.4, 0.28)
				stage.play_sfx("heart_thump", pos)
				stage.shake(0.22),
	})


func _on_reset_encounter() -> void:
	_pendulum_pivot = Vector2(arena_rect.get_center().x, arena_rect.position.y + 12.0)
	_pendulum_dir = 1.0
	_pendulum_bonked = false
	_double_beat_fired = false
	_cage_dropped_t = 0.0
	_slime_bonk_flash_t = 0.0
	_drip_cd = 2.0
	_spawn_steam_valves()
	_set_room_stride_speed(1.0, false)


func _spawn_steam_valves() -> void:
	var c: Vector2 = arena_rect.get_center()
	var offs: Array[Vector2] = [
		Vector2(-56.0, -34.0), Vector2(56.0, -34.0),
		Vector2(-56.0, 34.0), Vector2(56.0, 34.0),
	]
	for i: int in range(_valve_ids.size()):
		var vp: Vector2 = clamp_to_arena(c + offs[i])
		var p: Dictionary = props.spawn_pillar(vp, 3.0, _valve_ids[i])
		p["color"] = "apricot"
		p["on_break"] = func(_prop: Dictionary) -> void: _on_valve_shattered()


func _on_valve_shattered() -> void:
	_cage_dropped_t = 5.5
	stage.play_sfx("shield_shatter", pos)
	stage.light_burst(pos, 72.0, 1.25, 0.28)
	if _alive_valve_count() == 0:
		stagger_immunity_t = 0.0
		add_stagger(stagger_threshold)
	else:
		add_stagger(stagger_threshold * 0.42)


func _alive_valve_count() -> int:
	var n: int = 0
	for vid: String in _valve_ids:
		var p: Dictionary = props.get_prop(vid)
		if not p.is_empty() and str(p["state"]) != "broken":
			n += 1
	return n


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# PENDULUM DETACH! Brass ceiling tether attaches, ribcage tilt speeds up, iron rib-baffles rise!
		var self_pos: Callable = func() -> Vector2: return pos
		tethers.add_tether("heart_pendulum_chain", _pendulum_pivot, self_pos, {
			"max_length": PENDULUM_LEN + 8.0, "cuttable": false, "color": "gold",
		})
		stage.set_tiles(world_ctx, Rect2i(4, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(4, 8, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 8, 1, 1), "wall")
		_set_room_stride_speed(1.8, false)
		_try_drip_slag_slime()
		stage.play_sfx("harbor_creak", pos)
		stage.play_sfx("boss_kilnmother_roar", pos)
		stage.darkness_pulse(0.60, 0.90)
		stage.shake(0.26)
	elif new_phase == 3:
		_set_room_stride_speed(2.0, false)
		_try_drip_slag_slime()
		stage.play_sfx("heart_thump", pos)
		stage.light_burst(pos, 100.0, 1.45, 0.34)
		stage.shake(0.28)


func _try_drip_slag_slime() -> void:
	if adds.alive_count() + adds.pending_count() >= 2:
		return
	var c: Vector2 = arena_rect.get_center()
	var sx: float = c.x + (34.0 if (adds.alive_count() % 2 == 0) else -34.0)
	var sy: float = clampf(_pendulum_pivot.y + PENDULUM_LEN - 6.0, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0)
	var sp: Vector2 = clamp_to_arena(Vector2(sx, sy))
	adds.queue_wave([{"kind": "slag_slime", "pos": sp, "summon_color": "coral"}], 0.65, 2)


func _check_frozen_slime_collision() -> void:
	var enemies: Array = world_ctx.call("get_enemies") as Array if (world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_enemies")) else []
	for ev: Variant in enemies:
		if not is_instance_valid(ev) or not (ev is LxEnemyBrain) or ev == self:
			continue
		var eb: LxEnemyBrain = ev as LxEnemyBrain
		if not eb.is_alive() or not eb.has_method("is_frozen_block") or not bool(eb.call("is_frozen_block")):
			continue
		if eb.pos.distance_to(pos) <= body_radius + 16.0:
			_pendulum_bonked = true
			_slime_bonk_flash_t = SLIME_BONK_STAGGER
			# Shatter the frozen slime & slam Heart for bonus damage + 2.4s mega-stagger!
			eb.take_hit(LxHit.make(LxHit.SOURCE_SUNFLARE, 99.0, Vector2.DOWN, pos, 2.0, true, true, self, true))
			hp = maxf(1.0, hp - SLIME_BONK_BONUS_DMG)
			stage.play_sfx("heart_pendulum_bonk", pos)
			stage.play_sfx("shield_shatter", pos)
			stage.shake(0.28)
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				(Lx.player as LxWick).spawn_ring(pos, 6.0, 38.0, 0.34, PAL["ice"] as Color, 2.0)
			stagger_duration = SLIME_BONK_STAGGER
			stagger_immunity_t = 0.0
			add_stagger(stagger_threshold)
			_check_phase_thresholds()
			break


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _cage_dropped_t > 0.0:
		_cage_dropped_t = maxf(0.0, _cage_dropped_t - dt)
	if _slime_bonk_flash_t > 0.0:
		_slime_bonk_flash_t = maxf(0.0, _slime_bonk_flash_t - dt)
	if phase >= 2 and engaged and boss_state != BossState.DEATH:
		_drip_cd -= dt
		if _drip_cd <= 0.0 and adds.alive_count() + adds.pending_count() == 0:
			_drip_cd = 10.5
			_try_drip_slag_slime()


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	if phase == 1:
		# P1 stays moored near ribcage center with subtle pulsing drift
		var to_h: Vector2 = home - pos
		if to_h.length() > 4.0:
			move_boss(to_h.limit_length(move_speed * dt), true)
	else:
		# P2/P3 gently sways on the brass pendulum chain
		var sway_a: float = PI * 0.5 + sin(anim_t * (1.8 if phase >= 3 else 1.25)) * 0.62
		var want: Vector2 = clamp_to_arena(_pendulum_pivot + Vector2.from_angle(sway_a) * PENDULUM_LEN)
		move_boss((want - pos).limit_length(move_speed * 2.2 * dt), true)
		_face_point(target, 3.2, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null or is_punishable():
		return dmg
	# P1 iron cage slightly shields core while valves stay intact; P2 swinging hull rewards frozen-slime bonks!
	if phase == 1 and _alive_valve_count() > 0 and _cage_dropped_t <= 0.0:
		if not hit.cracks_armour and hit.source != LxHit.SOURCE_SUNFLARE:
			clank_t = 0.08
			return dmg * 0.96
	return dmg


func _on_death_start() -> void:
	_set_room_stride_speed(1.0, true)
	stage.play_sfx("boss_victory", pos)
	stage.light_burst(pos, 110.0, 1.5, 0.45)


func _set_room_stride_speed(mult: float, calm: bool) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if is_instance_valid(it_v) and it_v is LxInteractable and (it_v as LxInteractable).kind == "colossus_stride_cam":
			if (it_v as Object).has_method("set_speed_mult"):
				(it_v as Object).call("set_speed_mult", mult)
			if calm and (it_v as Object).has_method("set_stabilized"):
				(it_v as Object).call("set_stabilized", true)


func _build_drip_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	return out


func _body_color() -> Color:
	return (PAL["ice"] if _slime_bonk_flash_t > 0.0 else (PAL["gold"] if phase >= 3 else PAL["coral"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	# P1 iron cage shimmer while valves remain
	if phase == 1 and _alive_valve_count() > 0 and _cage_dropped_t <= 0.0 and boss_state != BossState.DEATH:
		draw_arc(off.round(), body_radius + 4.0, 0.0, TAU, 20, Color(PAL["stone"] as Color, 0.65), 1.0)
	# P2+ faint pendulum arc track on ribcage floor so players know where to freeze slag_slimes!
	if phase >= 2 and boss_state != BossState.DEATH:
		var piv_rel: Vector2 = (_pendulum_pivot - pos).round()
		draw_arc(piv_rel, PENDULUM_LEN, PI * 0.5 - PENDULUM_ARC_RAD, PI * 0.5 + PENDULUM_ARC_RAD, 24, Color(PAL["apricot"] as Color, 0.34), 1.0)
	if _slime_bonk_flash_t > 0.0 and boss_state == BossState.STAGGER:
		var fa: float = 0.60 if is_flash_reduced() else 1.0
		draw_arc(off.round(), body_radius + 6.0, 0.0, TAU, 20, Color(PAL["void"] as Color, fa * 0.85), 4.0)
		draw_arc(off.round(), body_radius + 6.0, 0.0, TAU, 20, Color(PAL["ice"] as Color, fa), 2.0)
