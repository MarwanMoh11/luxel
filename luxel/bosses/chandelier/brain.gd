class_name LxChandelierBoss
extends LxBossBase
## Island 1 Major Boss: The Chandelier (Manor r11).
## Possessed 6-arm wrought-iron candle tree suspended on 4 ceiling chains (3 if Right Verdict!).
## Ring the War Bell to turn chains brittle, shoot chains to drop it & expose its molten wax heart;
## P2 snuffs ballroom sconces & calls Snuffer Acolytes (Dawn Bell relights all sconces at once!);
## P3 snaps all chains and spins across the marble as a blazing wrought-iron carousel top!

const CHAIN_HP_BASE: float = 2.4
const CHAIN_HP_BRITTLE: float = 0.65
const BRITTLE_DUR: float = 5.5
const DROP_SLAM_R: float = 44.0
const DROP_STAGGER_S: float = 1.85

var _chains_remaining: int = 4
var _brittle_t: float = 0.0
var _blackout_active: bool = false
var _sconces_lit: Array[bool] = [true, true, true, true]
var _drop_target: Vector2 = Vector2.ZERO
var _swing_t: float = 0.0
var _swing_anchor: Vector2 = Vector2.ZERO
var _chain_anchors: Array[Vector2] = []
var _core_open_t: float = 0.0
var _spin_ang: float = 0.0


func _init() -> void:
	super._init()
	kind = "chandelier"
	boss_id = "chandelier"
	boss_name_key = "ISL1_BOSS_CHAND"
	island_id = 1
	is_miniboss = false
	reward_heart = "none" # Pack JSON heart="half" awarded once via LxBossHud (avoids double-award)
	music_cue = "isl1_boss_minor_p1"
	music_p2_cue = "isl1_boss_minor_p2"
	max_hp = 92.0
	hp = 92.0
	body_radius = 12.5
	move_speed = 38.0
	stagger_threshold = 12.0
	stagger_duration = 1.90
	post_recover_cd = 0.30
	intro_duration = 0.65
	phase_shift_duration = 0.72
	death_duration = 2.2
	shard_drop = 34


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.65, 0.32])

	# Attack 1: Pendulum Wax Sweep (swings wide across ballroom tossing burning wax pools!)
	register_attack("pendulum_wax_sweep", {
		"phases": [1, 2], "weight": 1.35, "tell": 0.68, "commit": 0.42, "recover": 1.36, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim_d.angle()
			var pools: Array[Vector2] = _build_wax_arc_targets(tgt).slice(0, 2)
			patterns.emit_rain(ground, pools, last_tell_duration + 0.16, 12.0, 1.0, "coral", "apricot")
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 130.0), 8.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 3, 0.88, 72.0, {"color": "apricot", "source": "wax_sweep"})
			stage.shake(0.14)
			stage.play_sfx("chandelier_wax_splash", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _elapsed: float) -> void:
			var swing_v := Vector2(cos(_swing_t * 4.2), sin(_swing_t * 2.8) * 0.45) * 56.0 * dt
			move_boss(swing_v, true),
	})

	# Attack 2: Spotlight Drop (shrinking ring telegraph -> heavy marble crash -> molten core open!)
	register_attack("spotlight_drop", {
		"weight": 1.30, "tell": 0.72, "commit": 0.30, "recover": 1.50, "cooldown": 1.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var approach: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 2.0 else Vector2.from_angle(facing)
			_drop_target = clamp_to_arena(tgt - approach * 42.0)
			facing = approach.angle()
			ground.warn_ring(_drop_target, DROP_SLAM_R * 0.64, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("bell_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			pos = _drop_target
			position = pos.round()
			_core_open_t = 1.50
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var cnt: int = 6 if phase >= 2 else 5
			patterns.emit_gap_ring(pos, cnt, 74.0 if phase >= 2 else 70.0, aim_a + PI * 0.32, 1.24, {"color": "gold", "source": "chandelier_drop"})
			stage.shake(0.20)
			stage.play_sfx("bell_slam", pos),
	})

	# Attack 3 (P2): Blackout Snuff (dims sconces, conjures grinning candle-mask pillars + coral fan)
	register_attack("blackout_snuff", {
		"phases": [2], "weight": 2.40, "tell": 0.74, "commit": 0.38, "recover": 1.48, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_snuff_all_sconces()
			var pts: Array[Vector2] = _build_wax_arc_targets(tgt).slice(1, 3)
			patterns.emit_pillars(pts, last_tell_duration + 0.14, 12.0, 0.32, 1.0, "coral")
			stage.darkness_pulse(0.68, 1.2)
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 3, 0.90, 72.0, {"color": "coral", "source": "blackout_mask"})
			stage.shake(0.16)
			stage.play_sfx("chandelier_blackout", pos),
	})

	# Attack 4 (P3): Carousel Spin (0 chains left! Blazing wrought-iron fire spiral across the marble!)
	register_attack("carousel_spin", {
		"phases": [3], "weight": 2.80, "tell": 0.64, "commit": 0.78, "recover": 1.50, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_spin_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			ground.warn_ring(pos, 32.0, last_tell_duration, 0.0, "coral", "gold")
			for arm: int in range(3):
				var ad: Vector2 = Vector2.from_angle(_spin_ang + float(arm) * (TAU / 3.0))
				ground.warn_lane(pos, clamp_to_arena(pos + ad * 115.0), 8.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("bell_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 3, 74.0, _spin_ang, 0.38, 3, 0.28, {"color": "coral", "source": "carousel_fire", "follow_boss": true})
			stage.shake(0.18)
			stage.play_sfx("chandelier_wax_splash", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			var to_t: Vector2 = tgt - pos
			if to_t.length() > 30.0:
				move_boss(to_t.normalized() * 34.0 * dt, false)
			facing = wrapf(facing + 7.5 * dt, -PI, PI),
	})


func _on_reset_encounter() -> void:
	var pre_cut: bool = Lx.state != null and bool(Lx.state.story_flags.get("chandelier_chain_cut", false))
	_chains_remaining = 3 if pre_cut else 4
	_brittle_t = 0.0
	_blackout_active = false
	_sconces_lit = [true, true, true, true]
	_swing_t = 0.0
	_core_open_t = 0.0
	_swing_anchor = arena_rect.get_center()
	_setup_ceiling_chains(_chains_remaining)
	_spawn_ballroom_lab_bells()


func _setup_ceiling_chains(count: int) -> void:
	tethers.clear()
	_chain_anchors.clear()
	var c: Vector2 = arena_rect.get_center()
	var ox: float = minf(72.0, arena_rect.size.x * 0.28)
	var oy: float = minf(38.0, arena_rect.size.y * 0.28)
	var all_anchors: Array[Vector2] = [
		c + Vector2(-ox, -oy),
		c + Vector2(ox, -oy),
		c + Vector2(-ox, oy),
		c + Vector2(ox, oy),
	]
	for i: int in range(mini(count, all_anchors.size())):
		var anc: Vector2 = all_anchors[i]
		_chain_anchors.append(anc)
		var cid: String = "chandelier_chain_%d" % (i + 1)
		tethers.add_tether(cid, anc, func() -> Vector2: return pos + Vector2(0.0, -14.0), {
			"hp": CHAIN_HP_BASE, "cuttable": true, "color": "gold",
			"max_length": 115.0,
			"on_cut": func(_t: Dictionary) -> void: _on_chain_snapped(anc),
		})


func _spawn_ballroom_lab_bells() -> void:
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if is_instance_valid(it_v) and it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if not has_room_bell:
		var war_p := Vector2(arena_rect.position.x + 26.0, arena_rect.position.y + 24.0)
		var dawn_p := Vector2(arena_rect.end.x - 26.0, arena_rect.end.y - 24.0)
		var b_war: Dictionary = props.spawn_bell(war_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("war", (pos - bp).normalized())
			stage.play_sfx("bell_slam", bp), "chand_lab_bell_war")
		b_war["solid"] = false
		var b_dawn: Dictionary = props.spawn_bell(dawn_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dawn", (pos - bp).normalized())
			stage.play_sfx("bell_toll", bp), "chand_lab_bell_dawn")
		b_dawn["solid"] = false


func _on_chain_snapped(at_p: Vector2) -> void:
	_chains_remaining = tethers.active_count()
	_core_open_t = DROP_STAGGER_S
	stage.play_sfx("chandelier_chain_snap", at_p)
	stage.shake(0.24)
	if boss_state != BossState.DEATH and boss_state != BossState.PHASE_SHIFT:
		_release_token()
		active_attack_id = ""
		stagger_meter = 0.0
		_set_boss_state(BossState.STAGGER, DROP_STAGGER_S)
		staggered.emit(DROP_STAGGER_S)
		LxDamageFx.boss_impact(pos, 0.22, 86.0, 88.0, 86.0, 1.42, 0.36)


func _snuff_all_sconces() -> void:
	_blackout_active = true
	for i: int in range(_sconces_lit.size()):
		_sconces_lit[i] = false


func _relight_all_sconces() -> void:
	_blackout_active = false
	for i: int in range(_sconces_lit.size()):
		_sconces_lit[i] = true
	stage.light_burst(arena_rect.get_center(), 145.0, 1.45, 0.55)
	stage.play_sfx("brazier_lit", pos)


func _build_wax_arc_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(clamp_to_arena(tgt + Vector2(28.0, -18.0)))
	out.append(clamp_to_arena(tgt + Vector2(-28.0, 18.0)))
	out.append(corners[1])
	return out


func on_ring(tone: String, _dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "war":
		# Vibrates all active ceiling chains brittle coral (1-bolt snap!)
		_brittle_t = BRITTLE_DUR
		for td: Dictionary in tethers.tethers:
			if not bool(td["cut"]):
				td["hp"] = minf(float(td["hp"]), CHAIN_HP_BRITTLE)
				td["color"] = "coral"
		add_stagger(2.5)
		stage.shake(0.14)
		stage.play_sfx("harbor_creak", pos)
	elif t == "dawn":
		# Relights all ballroom sconces at once & dispels P2 blackout!
		if _blackout_active:
			_relight_all_sconces()
			add_stagger(4.5)
		else:
			_relight_all_sconces()
			add_stagger(1.8)
	elif t == "dusk":
		patterns.freeze_bolts_in_radius(pos, 120.0, 1.6, "dusk")
		add_stagger(2.0)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_swing_t += dt
	_core_open_t = maxf(0.0, _core_open_t - dt)
	if _brittle_t > 0.0:
		_brittle_t = maxf(0.0, _brittle_t - dt)
		if _brittle_t <= 0.0:
			for td: Dictionary in tethers.tethers:
				if not bool(td["cut"]):
					td["color"] = "gold"
	move_speed = 46.0 if phase >= 3 else (40.0 if phase == 2 else 34.0)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Snap down to at most 2 chains, snuff ballroom sconces, summon 2 Snuffer Acolytes!
		for td: Dictionary in tethers.tethers:
			if tethers.active_count() <= 2:
				break
			if not bool(td["cut"]):
				td["cut"] = true
		_chains_remaining = tethers.active_count()
		_snuff_all_sconces()
		var tl_tx: int = maxi(1, int(arena_rect.position.x / 16.0))
		var tl_ty: int = maxi(1, int(arena_rect.position.y / 16.0))
		var br_tx: int = maxi(tl_tx + 4, int(arena_rect.end.x / 16.0) - 1)
		var br_ty: int = maxi(tl_ty + 3, int(arena_rect.end.y / 16.0) - 1)
		var wp: Vector2 = _get_wick_pos() if _has_player() else Vector2(-9999.0, -9999.0)
		if wp.distance_to(Vector2((float(tl_tx) + 0.5) * 16.0, (float(tl_ty) + 0.5) * 16.0)) >= 24.0:
			stage.set_tiles(world_ctx, Rect2i(tl_tx, tl_ty, 1, 1), "pit")
		if wp.distance_to(Vector2((float(br_tx) + 0.5) * 16.0, (float(br_ty) + 0.5) * 16.0)) >= 24.0:
			stage.set_tiles(world_ctx, Rect2i(br_tx, br_ty, 1, 1), "pit")
		adds.queue_wave([
			{"kind": "snuffer_acolyte", "pos": c + Vector2(-72.0, -32.0), "hp_scale": 0.55},
		], 0.85, 1)
		stage.darkness_pulse(0.76, 1.4)
		stage.shake(0.24)
		stage.play_sfx("chandelier_chain_snap", pos)
	elif new_phase == 3:
		# Snap all remaining chains -> drops onto marble as spinning Carousel Top!
		for td: Dictionary in tethers.tethers:
			td["cut"] = true
		_chains_remaining = 0
		_relight_all_sconces()
		stage.shake(0.28)
		stage.play_sfx("chandelier_chain_snap", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	# While high on chains and NOT open/dropped, iron cage cushions bolt chip slightly;
	# dropped molten wax heart takes 1.35x burst damage!
	if _core_open_t > 0.0 or boss_state == BossState.STAGGER or boss_state == BossState.RECOVER:
		return dmg * 1.38
	var h: Dictionary = _read_hit(hit)
	if _chains_remaining >= 3 and str(h["source"]) == LxHit.SOURCE_BOLT and not bool(h["pierce"]):
		return dmg * 0.85
	return dmg


func _on_death_start() -> void:
	for td: Dictionary in tethers.tethers:
		td["cut"] = true
	_chains_remaining = 0
	_relight_all_sconces()
	stage.play_sfx("boss_victory", pos)
	stage.shake(0.26)


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["wine"] if phase == 2 else PAL["apricot"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Draw ballroom corner sconce indicators (lit gold vs snuffed dusk during P2 blackout)
	var ox: float = minf(84.0, arena_rect.size.x * 0.34)
	var oy: float = minf(44.0, arena_rect.size.y * 0.32)
	var s_offs: Array[Vector2] = [Vector2(-ox, -oy), Vector2(ox, -oy), Vector2(-ox, oy), Vector2(ox, oy)]
	var ac: Vector2 = arena_rect.get_center()
	for i: int in range(4):
		var sp: Vector2 = (ac + s_offs[i] - pos).round()
		var lit: bool = _sconces_lit[i]
		draw_circle(sp, 4.5, PAL["void"] as Color)
		draw_circle(sp, 3.2, PAL["gold"] if lit else PAL["dusk"])
		if lit:
			draw_circle(sp, 1.5, PAL["cream"] as Color)
	# Brittle chain shimmer pulse
	if _brittle_t > 0.0 and _chains_remaining > 0:
		draw_arc(c + Vector2(0.0, -14.0), 16.0, 0.0, TAU, 16, PAL["void"] as Color, 3.0)
		draw_arc(c + Vector2(0.0, -14.0), 16.0, 0.0, TAU, 16, PAL["coral"] as Color, 1.0)
	# Exposed molten wax heart glow when dropped/open
	if (_core_open_t > 0.0 or boss_state == BossState.STAGGER) and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 18, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 18, PAL["gold"] as Color, 2.0)
