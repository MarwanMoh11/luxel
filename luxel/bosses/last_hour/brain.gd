class_name LxLastHourBoss
extends LxBossBase
## Island 4 Superboss (vault_last_hour): The Last Hour.
## TIME RUNS BACKWARDS! Attacks play in reverse: glass bolts fly INWARD from the 12 outer
## clock numerals, shattered floor cracks snap whole, and a future afterimage appears BEFORE
## her body rewinds into it. Forward bolts meeting her backward bolts trigger Temporal
## Annihilation (2.2 s stagger). In P3, Zero O'Clock Rewind restores pillars every 10 s while
## dealt boss damage stays etched in gold glass!

const ANNIHILATE_STAGGER_S: float = 2.20
const REWIND_PERIOD_S: float = 10.0
const NUMERAL_COUNT: int = 12

var _hour_ang: float = -PI * 0.5
var _minute_ang: float = -PI * 0.5
var _rewind_t: float = REWIND_PERIOD_S
var _rewind_flash_t: float = 0.0
var _annihilate_charge: float = 0.0
var _annihilate_fx: Array[Dictionary] = []  # [{pos, ttl}]
var _afterimage_pos: Vector2 = Vector2.ZERO
var _afterimage_from: Vector2 = Vector2.ZERO
var _afterimage_active: bool = false
var _sweep_ang: float = 0.0
var _sweep_len: float = 108.0
var _inward_origins: Array[Vector2] = []
var _echo_rose_pos: Vector2 = Vector2.ZERO
var _death_forward_ticked: bool = false
var _death_moth_y: float = -34.0


func _init() -> void:
	super._init()
	kind = "boss_last_hour"
	boss_id = "boss_last_hour"
	boss_name_key = "ISL4_BOSS_LAST_HOUR"
	island_id = 4
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island4_boss_p1"
	music_p2_cue = "island4_boss_p2"
	max_hp = 136.0
	hp = 136.0
	body_radius = 11.0
	move_speed = 46.0
	stagger_threshold = 18.0
	stagger_duration = 1.95
	post_recover_cd = 0.28
	shard_drop = 120
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.36])

	# Attack 1: Un-Fired Ring — 10-12 glass bolts spawn on outer clock numerals & fly INWARD!
	register_attack("unfired_ring", {
		"weight": 1.30, "tell": 0.60, "commit": 0.45, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_inward_origins.clear()
			var c: Vector2 = arena_rect.get_center()
			var rx: float = arena_rect.size.x * 0.46
			var ry: float = arena_rect.size.y * 0.44
			var cnt: int = 12 if phase >= 2 else 10
			var gap_a: float = (tgt - c).angle() + 0.55
			for i: int in range(cnt):
				var a: float = -float(i) * (TAU / float(cnt)) + _hour_ang
				if absf(angle_difference(a, gap_a)) < 0.46:
					continue
				var op: Vector2 = clamp_to_arena(c + Vector2(cos(a) * rx, sin(a) * ry))
				_inward_origins.append(op)
				ground.warn_lane(op, pos, 5.0, last_tell_duration, 0.0, "gold", "ice")
			# Also aim one rim-convergence lane straight through Wick's spot (anti-perimeter cheese!)
			var rim_w: Vector2 = _project_to_rim(tgt)
			_inward_origins.append(rim_w)
			ground.warn_lane(rim_w, pos, 6.5, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("last_hour_rev_bell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var spd: float = 148.0 if phase >= 3 else (136.0 if phase >= 2 else 124.0)
			for op: Vector2 in _inward_origins:
				var inward: Vector2 = (pos - op).normalized() if pos.distance_to(op) > 2.0 else Vector2.LEFT
				patterns.emit_fan(op, inward, 1, 0.0, spd, {"color": "ice", "source": "unfired_ring", "max_age": 2.4})
			stage.shake(0.16)
			stage.play_sfx("last_hour_time_snap", pos),
	})

	# Attack 2: Un-Broken Tiles — 5-6 void floor cracks snap whole in reverse with 36 px rings!
	register_attack("unbroken_tiles", {
		"weight": 1.25, "tell": 0.62, "commit": 0.36, "recover": 1.00, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var pts: Array[Vector2] = _build_crack_targets(tgt)
			patterns.emit_rain(ground, pts, last_tell_duration, 24.0, 1.0, "ice", "gold")
			stage.play_sfx("last_hour_rev_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.72, 134.0, {"color": "gold", "source": "unbroken_shards"})
			stage.shake(0.16)
			stage.play_sfx("last_hour_time_snap", pos),
	})

	# Attack 3: Rewind Lunge — future afterimage appears FIRST at target; body rewinds into it!
	register_attack("rewind_lunge", {
		"weight": 1.20, "tell": 0.55, "commit": 0.34, "recover": 1.15, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_afterimage_from = pos
			_afterimage_pos = clamp_to_arena(tgt)
			_afterimage_active = true
			var d: Vector2 = (_afterimage_pos - pos).normalized() if _afterimage_pos.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = d.angle()
			ground.warn_lane(pos, _afterimage_pos, 12.0, last_tell_duration, 0.0, "coral", "ice")
			ground.warn_ring(_afterimage_pos, 18.0, last_tell_duration, 0.0, "ice", "cream")
			stage.play_sfx("last_hour_rev_tick", _afterimage_pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("hollow_dash", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, elapsed: float) -> void:
			var u: float = clampf(elapsed / 0.34, 0.0, 1.0)
			var want: Vector2 = _afterimage_from.lerp(_afterimage_pos, u)
			move_boss(want - pos, true)
			var ldir: Vector2 = (_afterimage_pos - _afterimage_from).normalized() if _afterimage_pos.distance_to(_afterimage_from) > 1.0 else Vector2.from_angle(facing)
			check_contact_damage(16.0, ldir, 1.0, "rewind_lunge")
			if u >= 0.92 and _afterimage_active:
				_afterimage_active = false
				patterns.emit_fan(pos, -ldir, 5, 0.95, 134.0, {"color": "coral", "source": "rewind_trail"}),
	})

	# Attack 4 (Phase 2 & 3): Minute-Hand Sweep — counter-clockwise sweeping radial clock hand!
	register_attack("minute_hand_sweep", {
		"phases": [2, 3], "weight": 1.50, "tell": 0.62, "commit": 0.52, "recover": 1.10, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			_sweep_ang = (tgt - c).angle() + 0.70
			_sweep_len = minf(arena_rect.size.x, arena_rect.size.y) * 0.48
			ground.warn_sector(c, _sweep_ang - 1.40, _sweep_ang, _sweep_len, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.04, 1.0, "ice", "gold")
			stage.play_sfx("last_hour_rev_bell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() + 0.45
			patterns.emit_gap_ring(pos, 14, 126.0, gap_a, 0.70, {"color": "gold", "source": "minute_hand_ring"})
			stage.shake(0.18)
			stage.play_sfx("last_hour_time_snap", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			# Counter-clockwise sweep! Gliding Wick passes cleanly over the hand!
			_sweep_ang -= 2.75 * dt
			_minute_ang = _sweep_ang
			var c: Vector2 = arena_rect.get_center()
			var tip: Vector2 = c + Vector2.from_angle(_sweep_ang) * _sweep_len
			if not _commit_hit_done and _has_player():
				var gliding: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).is_gliding()
				if not gliding:
					var wp: Vector2 = _get_wick_pos()
					if Geometry2D.get_closest_point_to_segment(wp, c, tip).distance_to(wp) <= 10.0:
						_commit_hit_done = true
						emit_boss_damage(Vector2.from_angle(_sweep_ang - PI * 0.5), 1.0, "minute_hand_sweep", c, true),
	})

	# Attack 5 (Phase 3): Reverse Spiral & Dual-Hand Cross — inward CCW spiral + cross clock hands!
	register_attack("reverse_spiral", {
		"phases": [3], "weight": 1.85, "tell": 0.60, "commit": 0.48, "recover": 1.15, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var rx: float = arena_rect.size.x * 0.44
			var ry: float = arena_rect.size.y * 0.42
			ground.warn_lane(c + Vector2(-rx, 0.0), c + Vector2(rx, 0.0), 10.0, last_tell_duration, 1.0, "coral", "gold")
			ground.warn_lane(c + Vector2(0.0, -ry), c + Vector2(0.0, ry), 10.0, last_tell_duration, 1.0, "ice", "cream")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.05, 1.0, "gold", "coral")
			stage.play_sfx("last_hour_rev_bell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var base_a: float = (tgt - pos).angle()
			patterns.emit_spiral(pos, 5, 134.0, base_a, -0.44, 3, 0.15, {"color": "ice", "source": "reverse_spiral"})
			stage.light_burst(pos, 96.0, 1.45, 0.36)
			stage.shake(0.22)
			stage.play_sfx("echo_annihilate", pos),
	})


func _on_reset_encounter() -> void:
	_hour_ang = -PI * 0.5
	_minute_ang = -PI * 0.5
	_rewind_t = REWIND_PERIOD_S
	_rewind_flash_t = 0.0
	_annihilate_charge = 0.0
	_annihilate_fx.clear()
	_afterimage_active = false
	_inward_origins.clear()
	_echo_rose_pos = arena_rect.get_center()
	_death_forward_ticked = false
	_death_moth_y = -34.0


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Outer void corners fracture open (rolled back cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		_spawn_clock_pillars()
		stage.darkness_pulse(0.64, 1.00)
		stage.shake(0.24)
		stage.play_sfx("last_hour_rev_bell", pos)
	elif new_phase == 3:
		_rewind_t = 6.0
		_spawn_clock_pillars()
		stage.darkness_pulse(0.72, 1.10)
		stage.shake(0.28)
		stage.play_sfx("echo_annihilate", pos)


func _spawn_clock_pillars() -> void:
	var c: Vector2 = arena_rect.get_center()
	if props.get_positions("pillar").size() < 2:
		props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, -26.0)), 4.0, "clock_pillar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, 26.0)), 4.0, "clock_pillar_e")


func _on_boss_tick(dt: float, tgt: Vector2) -> void:
	# Counter-clockwise hands tick backwards!
	var rate: float = 1.6 if phase >= 3 else (1.1 if phase == 2 else 0.65)
	_hour_ang = wrapf(_hour_ang - rate * 0.35 * dt, -PI, PI)
	if not (boss_state == BossState.COMMIT and active_attack_id == "minute_hand_sweep"):
		_minute_ang = wrapf(_minute_ang - rate * dt, -PI, PI)
	if boss_state != BossState.TELL and boss_state != BossState.COMMIT:
		_afterimage_active = false
	_rewind_flash_t = maxf(0.0, _rewind_flash_t - dt)

	# Temporal Annihilation: forward player bolts meeting her backward bolts annihilate!
	_check_temporal_annihilation()
	# Un-fired inward bolts absorb cleanly back into The Last Hour once they converge!
	for eb: LxBossBolt in patterns.pool:
		if eb.active and not eb.reflected and eb.source_kind == "unfired_ring" and eb.age >= 0.30 and eb.pos.distance_to(pos) <= body_radius + 4.0:
			eb.deactivate()

	# Phase 3: Zero O'Clock Rewind every 10 s restores cover pillars & replays a telegraphed ring!
	if phase >= 3 and boss_state != BossState.DEATH:
		_rewind_t -= dt
		if _rewind_t <= 0.0:
			_rewind_t = REWIND_PERIOD_S
			_rewind_flash_t = 0.65
			_hour_ang = -PI * 0.5
			_minute_ang = -PI * 0.5
			_spawn_clock_pillars()
			ground.warn_ring(clamp_to_arena(tgt), 26.0, 0.62, 1.0, "gold", "ice")
			stage.play_sfx("last_hour_rev_bell", pos)

	for i: int in range(_annihilate_fx.size() - 1, -1, -1):
		_annihilate_fx[i]["ttl"] = float(_annihilate_fx[i]["ttl"]) - dt
		if float(_annihilate_fx[i]["ttl"]) <= 0.0:
			_annihilate_fx.remove_at(i)


func _check_temporal_annihilation() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.move_bolt == null or not (w.move_bolt.get("bolts") is Array):
		return
	for b_v: Variant in (w.move_bolt.get("bolts") as Array):
		if not (b_v is Dictionary) or not bool((b_v as Dictionary).get("active", true)):
			continue
		var bp: Vector2 = (b_v as Dictionary).get("pos", Vector2.INF) as Vector2
		if not bp.is_finite():
			continue
		for eb: LxBossBolt in patterns.pool:
			if not eb.active or eb.reflected:
				continue
			if bp.distance_to(eb.pos) <= eb.radius + 7.0:
				var mid: Vector2 = bp.lerp(eb.pos, 0.5)
				(b_v as Dictionary)["active"] = false
				eb.deactivate()
				_annihilate_fx.append({"pos": mid, "ttl": 0.34})
				_annihilate_charge += 1.0
				stage.play_sfx("echo_annihilate", mid)
				if _annihilate_charge >= 4.0 and stagger_immunity_t <= 0.0 and boss_state != BossState.STAGGER:
					_annihilate_charge = 0.0
					_trigger_temporal_stagger()
				break


func _trigger_temporal_stagger() -> void:
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, ANNIHILATE_STAGGER_S)
	staggered.emit(ANNIHILATE_STAGGER_S)
	LxDamageFx.boss_impact(pos, 0.22, 96.0, 96.0, 96.0, 1.46, 0.40, "ice")
	stage.play_sfx("echo_annihilate", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if boss_state == BossState.STAGGER:
		return dmg * 1.75
	if hit != null and (hit.source == LxHit.SOURCE_PRISM or hit.source == "reflected_bolt"):
		add_stagger(4.5)
		return dmg * 1.50
	if not is_punishable():
		return dmg * 0.74
	return dmg


func _on_death_start() -> void:
	# Hands halt at XII and tick ONCE forward in golden light!
	_hour_ang = -PI * 0.5 + 0.16
	_minute_ang = -PI * 0.5 + 0.16
	_death_forward_ticked = true
	_death_moth_y = -28.0
	stage.play_sfx("clockwork_chime", pos)


func _project_to_rim(tgt: Vector2) -> Vector2:
	var c: Vector2 = arena_rect.get_center()
	var d: Vector2 = (tgt - c).normalized() if tgt.distance_to(c) > 2.0 else Vector2.LEFT
	var rx: float = arena_rect.size.x * 0.47
	var ry: float = arena_rect.size.y * 0.45
	return clamp_to_arena(c + Vector2(d.x * rx, d.y * ry))


func _build_crack_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.48)))
	if phase >= 2:
		out.append(corners[2])
	return out


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["plum"] if phase == 2 else PAL["dusk"])) as Color


func _draw_boss_extra(_off: Vector2) -> void:
	var c_loc: Vector2 = (arena_rect.get_center() - pos).round()
	var face_r: float = minf(arena_rect.size.x, arena_rect.size.y) * 0.44

	# Floating 12-Numeral Clock-Face on arena floor + Gold Damage-Etched Arc!
	draw_arc(c_loc, face_r, 0.0, TAU, 36, Color(PAL["gold"] as Color, 0.34), 1.2)
	var dmg_frac: float = 1.0 - clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0)
	if dmg_frac > 0.02:
		# Dealt damage stays permanently etched in glowing gold glass!
		draw_arc(c_loc, face_r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * dmg_frac, 32, Color(PAL["gold"] as Color, 0.75), 1.8)
	for i: int in range(NUMERAL_COUNT):
		var a: float = -PI * 0.5 + float(i) * (TAU / float(NUMERAL_COUNT))
		var p0: Vector2 = (c_loc + Vector2.from_angle(a) * (face_r - 4.0)).round()
		var p1: Vector2 = (c_loc + Vector2.from_angle(a) * (face_r + 1.5)).round()
		draw_line(p0, p1, (PAL["cream"] if i % 3 == 0 else PAL["gold"]) as Color, 1.4 if i % 3 == 0 else 1.0)

	# Counter-clockwise Hour Hand & P2+ Sweeping Minute Hand
	var h_tip: Vector2 = (c_loc + Vector2.from_angle(_hour_ang) * (face_r * 0.56)).round()
	draw_line(c_loc, h_tip, Color(PAL["coral"] as Color, 0.65), 2.2)
	if phase >= 2 or _death_forward_ticked:
		var m_tip: Vector2 = (c_loc + Vector2.from_angle(_minute_ang) * (face_r * 0.96)).round()
		var sweeping: bool = boss_state == BossState.COMMIT and active_attack_id == "minute_hand_sweep"
		draw_line(c_loc, m_tip, (PAL["cream"] if sweeping else PAL["ice"]) as Color, 3.0 if sweeping else 1.6)
		# P2+ Central Echo Rose bloom
		var rp: Vector2 = (_echo_rose_pos - pos).round()
		draw_circle(rp, 5.0, Color(PAL["pine"] as Color, 0.72))
		draw_circle(rp, 3.0, PAL["rose"] as Color)
		draw_rect(Rect2(rp, Vector2.ONE), PAL["cream"] as Color)

	# Future Afterimage during Rewind Lunge tell/commit
	if _afterimage_active:
		var ap: Vector2 = (_afterimage_pos - pos).round()
		var a_col: Color = Color(PAL["ice"] as Color, 0.52 if is_flash_reduced() else 0.78)
		draw_arc(ap + Vector2(0.0, -16.0), 11.0, 0.0, TAU, 16, a_col, 1.5)
		draw_rect(Rect2(ap + Vector2(-5.0, -24.0), Vector2(10.0, 20.0)), Color(PAL["sky"] as Color, 0.40))
		draw_circle(ap + Vector2(0.0, -28.0), 4.5, a_col)

	# Zero O'Clock Rewind flash ring
	if _rewind_flash_t > 0.0:
		var ru: float = 1.0 - clampf(_rewind_flash_t / 0.65, 0.0, 1.0)
		draw_arc(c_loc, lerpf(face_r, 8.0, ru), 0.0, TAU, 28, PAL["gold"] as Color, 2.0)

	# Temporal Annihilation burst sparkles
	for fx: Dictionary in _annihilate_fx:
		var fp: Vector2 = ((fx["pos"] as Vector2) - pos).round()
		var fu: float = 1.0 - clampf(float(fx["ttl"]) / 0.34, 0.0, 1.0)
		draw_arc(fp, lerpf(4.0, 18.0, fu), 0.0, TAU, 14, PAL["ice"] as Color, 1.6)
		draw_circle(fp, maxf(1.5, 4.0 * (1.0 - fu)), PAL["cream"] as Color)

	# Death golden moth floating down at XII
	if _death_forward_ticked:
		var mp: Vector2 = (c_loc + Vector2(0.0, -face_r * 0.75)).round()
		draw_rect(Rect2(mp + Vector2(-3.0, -1.0), Vector2(6.0, 2.0)), PAL["gold"] as Color)
		draw_rect(Rect2(mp, Vector2.ONE), PAL["cream"] as Color)
