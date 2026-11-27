class_name LxGardenerTwiceBoss
extends LxBossBase
## Island 4 Boss A (hourglass_r12): The Gardener, Twice.
## Fights with YOUR recorded past! Continuously records Wick's trail and shots (like
## LxEchoRose + LxBossDuel). In Phase 2 he splits into Present Gardener + Echo Gardener
## replaying Wick's trail & shots; banking Echo shots off arena mirrors (or Beam/Dash
## reflection) into Present Gardener shatters his glass cloche for 2.5 s (2x dmg)!
## In Phase 3, baiting Present & Echo Gardeners to cross shears triggers a resonant clash!

const REC_WINDOW_S: float = 6.0
const REC_STEP_S: float = 0.05
const ECHO_DELAY_S: float = 3.2
const LUNGE_DIST: float = 84.0
const MIRROR_STAGGER_S: float = 2.50
const CLASH_STAGGER_S: float = 2.40
const CLASH_DIST: float = 24.0

var _lunge_dir: Vector2 = Vector2.RIGHT
var _cross_present_to: Vector2 = Vector2.ZERO
var _cross_echo_from: Vector2 = Vector2.ZERO
var _cross_echo_to: Vector2 = Vector2.ZERO
var _cross_clashed: bool = false
var _cloche_broken: bool = false

# Wick trail & shot recorder (modeled on LxEchoRose + LxBossDuel)
var _rec_clock: float = 0.0
var _rec_accum: float = 0.0
var _last_wick_shots: int = 0
var _rec_buf: Array[Dictionary] = []     # [{t, pos, facing, shot}]
var _last_replayed_t: float = -1.0

# Phase 2+ Echo Gardener state
var _echo_active: bool = false
var _echo_pos: Vector2 = Vector2.ZERO
var _echo_facing: Vector2 = Vector2.LEFT
var _echo_shot_cd: float = 0.0
var _echo_dash_cd: float = 0.0

# Arena mirrors (used when hourglass_r12 blue_transformers are absent in boss_lab)
var _mirrors: Array[Dictionary] = []     # [{pos, radius, flash_t}]
var _p3_roses: Array[Vector2] = []       # Phase 3 perimeter bloom roses
var _death_rose_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "boss_gardener_twice"
	boss_id = "boss_gardener_twice"
	boss_name_key = "ISL4_BOSS_GARDENER"
	island_id = 4
	is_miniboss = false
	reward_heart = "half"
	music_cue = "isl4_boss_minor_p1"
	music_p2_cue = "isl4_boss_minor_p2"
	max_hp = 204.0
	hp = 204.0
	body_radius = 10.0
	move_speed = 44.0
	stagger_threshold = 20.0
	stagger_duration = 1.75
	post_recover_cd = 0.42
	shard_drop = 65
	death_duration = 2.4


func _configure_boss(spec: Dictionary) -> void:
	max_hp = 204.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	hp = max_hp
	configure_phases([0.66, 0.33])

	# Attack 1: Twin-Shear Lunge (84 px sweeping cross-shear slash)
	register_attack("twin_shear_lunge", {
		"weight": 1.25, "tell": 0.60, "commit": 0.38, "recover": 1.18, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _lunge_dir.angle()
			var end_p: Vector2 = clamp_to_arena(pos + _lunge_dir * LUNGE_DIST)
			ground.warn_lane(pos, end_p, 12.0, last_tell_duration, 0.0, "rose", "gold")
			stage.play_sfx("shear_clack", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _lunge_dir, 3, 0.68, 90.0, {"color": "rose", "source": "twin_shear_lunge", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("topiary_cleave", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_lunge_dir * (LUNGE_DIST / 0.38) * dt, false)
			check_contact_damage(14.5, _lunge_dir, 1.0, "twin_shear_lunge"),
	})

	# Attack 2: Rose-Thorn Arc (petal spread + corner-pressuring thorn rain)
	register_attack("rose_thorn_arc", {
		"weight": 1.15, "tell": 0.60, "commit": 0.28, "recover": 1.10, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = d.angle()
			ground.warn_sector(pos, d.angle() - 0.72, d.angle() + 0.72, 102.0, last_tell_duration, 0.0, "wine", "rose")
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration + 0.12, 16.5, 0.5, "rose", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var cnt: int = 4 if phase >= 2 else 3
			patterns.emit_fan(pos, d, cnt, 1.12, 88.0 if phase >= 3 else 82.0, {"color": "rose", "source": "rose_thorn_arc", "damage": 0.5})
			stage.play_sfx("petal_lunge", pos),
	})

	# Attack 3: Memory Lantern (rose halo recording Wick's past + hourglass ring)
	register_attack("memory_lantern", {
		"weight": 1.10, "tell": 0.74, "commit": 0.36, "recover": 1.16, "cooldown": 2.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 48.0, last_tell_duration, 0.0, "rose", "cream")
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration + 0.10, 16.5, 0.5, "gold", "rose")
			stage.play_sfx("gardener_record", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() + 0.48
			patterns.emit_gap_ring(pos, 8, 90.0, gap_a, 1.20, {"color": "gold", "source": "memory_lantern", "damage": 0.5})
			if _echo_active:
				_fire_echo_gardener_volley(tgt)
			stage.light_burst(pos, 86.0, 1.35, 0.32)
			stage.play_sfx("petal_echo", pos),
	})

	# Attack 4 (Phase 2 & 3): Pruned Scissor Cross — Present & Echo Gardener converge; clash = 2.4s Stagger!
	register_attack("pruned_scissor_cross", {
		"phases": [2, 3], "weight": 1.40, "tell": 0.70, "commit": 0.40, "recover": 1.28, "cooldown": 2.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cross_clashed = false
			var meet: Vector2 = clamp_to_arena(tgt)
			var p_dir: Vector2 = (meet - pos).normalized() if meet.distance_to(pos) > 1.0 else Vector2.LEFT
			_cross_present_to = clamp_to_arena(pos + p_dir * 86.0)
			_cross_echo_from = _echo_pos if _echo_active else clamp_to_arena(arena_rect.get_center() * 2.0 - pos)
			var e_dir: Vector2 = (meet - _cross_echo_from).normalized() if meet.distance_to(_cross_echo_from) > 1.0 else Vector2.RIGHT
			_cross_echo_to = clamp_to_arena(_cross_echo_from + e_dir * 86.0)
			ground.warn_lane(pos, _cross_present_to, 10.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_lane(_cross_echo_from, _cross_echo_to, 10.0, last_tell_duration, 0.0, "rose", "cream")
			stage.play_sfx("shear_clack", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("topiary_cleave", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			var u: float = clampf(elapsed / 0.40, 0.0, 1.0)
			var pd: Vector2 = (_cross_present_to - pos).normalized() if _cross_present_to.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			move_boss(pd * 185.0 * dt, true)
			check_contact_damage(14.0, pd, 1.0, "pruned_scissor_cross")
			if _echo_active:
				_echo_pos = _cross_echo_from.lerp(_cross_echo_to, u)
				if not _cross_clashed and pos.distance_to(_echo_pos) <= CLASH_DIST:
					_cross_clashed = true
					_trigger_cloche_stagger(CLASH_STAGGER_S, "gardener_clash")
				elif _has_player() and _echo_pos.distance_to(_get_wick_pos()) <= 13.0 and not _commit_hit_done:
					_commit_hit_done = true
					emit_boss_damage((_cross_echo_to - _cross_echo_from).normalized(), 0.5, "pruned_scissor_cross", _echo_pos, true),
	})


func _on_reset_encounter() -> void:
	_rec_clock = 0.0
	_rec_accum = 0.0
	_last_wick_shots = _read_wick_shots()
	_rec_buf.clear()
	_last_replayed_t = -1.0
	_echo_active = false
	_echo_pos = home
	_echo_facing = Vector2.LEFT
	_echo_shot_cd = 0.0
	_echo_dash_cd = 0.0
	_cloche_broken = false
	_cross_clashed = false
	_death_rose_t = 0.0
	_p3_roses.clear()
	_setup_arena_mirrors()


func _setup_arena_mirrors() -> void:
	_mirrors.clear()
	var c: Vector2 = arena_rect.get_center()
	_mirrors.append({"pos": clamp_to_arena(c + Vector2(0.0, -40.0)), "radius": 11.0, "flash_t": 0.0, "cd": 0.0})
	_mirrors.append({"pos": clamp_to_arena(c + Vector2(0.0, 40.0)), "radius": 11.0, "flash_t": 0.0, "cd": 0.0})


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Split into Present Gardener + Echo Gardener! Twin topiary hedge dividers rise cleanly!
		_echo_active = true
		_echo_pos = clamp_to_arena(c + Vector2(-46.0, 0.0))
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "wall")
		stage.set_tiles(world_ctx, Rect2i(17, 8, 1, 2), "wall")
		stage.darkness_pulse(0.58, 0.95)
		stage.shake(0.22)
		stage.play_sfx("gardener_record", pos)
	elif new_phase == 3:
		# Outer rim corners flood into P3 moat + 3 perimeter echo roses bloom!
		stage.set_tiles(world_ctx, Rect2i(2, 9, 1, 1), "water")
		stage.set_tiles(world_ctx, Rect2i(17, 1, 1, 1), "water")
		_p3_roses = [
			clamp_to_arena(c + Vector2(-68.0, -34.0)),
			clamp_to_arena(c + Vector2(68.0, -34.0)),
			clamp_to_arena(c + Vector2(68.0, 34.0)),
		]
		stage.darkness_pulse(0.68, 1.05)
		stage.shake(0.26)
		stage.play_sfx("gardener_annihilate", pos)


func _on_boss_tick(dt: float, target: Vector2) -> void:
	if boss_state != BossState.STAGGER:
		_cloche_broken = false
	duel.tick_echo_recorder(dt)
	_tick_wick_recorder(dt)
	for m: Dictionary in _mirrors:
		m["flash_t"] = maxf(0.0, float(m["flash_t"]) - dt)
		m["cd"] = maxf(0.0, float(m.get("cd", 0.0)) - dt)
	if _echo_active and boss_state != BossState.DEATH:
		_tick_echo_gardener(dt, target)
	_check_mirror_reflections()


func _tick_wick_recorder(dt: float) -> void:
	_rec_clock += dt
	_rec_accum += dt
	var cur_shots: int = _read_wick_shots()
	var fired: bool = cur_shots > _last_wick_shots
	_last_wick_shots = cur_shots
	if fired or _rec_accum >= REC_STEP_S:
		_rec_accum = 0.0
		var wp: Vector2 = _get_real_wick_pos()
		var wf: Vector2 = Vector2.RIGHT
		if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("facing") is Vector2:
			var fv: Vector2 = Lx.player.get("facing") as Vector2
			if fv.length_squared() > 0.001:
				wf = fv.normalized()
		_rec_buf.append({"t": _rec_clock, "pos": wp, "facing": wf, "shot": fired})
		while _rec_buf.size() > 2 and (_rec_clock - float(_rec_buf[0]["t"])) > REC_WINDOW_S:
			_rec_buf.pop_front()


func _tick_echo_gardener(dt: float, target: Vector2) -> void:
	_echo_shot_cd = maxf(0.0, _echo_shot_cd - dt)
	_echo_dash_cd = maxf(0.0, _echo_dash_cd - dt)
	if boss_state == BossState.COMMIT and active_attack_id == "pruned_scissor_cross":
		return
	var want_t: float = _rec_clock - ECHO_DELAY_S
	if _rec_buf.size() < 2 or want_t <= 0.0:
		return
	# Sample Wick's trail from ECHO_DELAY_S seconds ago!
	var prev_s: Dictionary = _rec_buf[0]
	var next_s: Dictionary = _rec_buf[_rec_buf.size() - 1]
	var shot_trigger: Dictionary = {}
	for s: Dictionary in _rec_buf:
		var st: float = float(s["t"])
		if st <= want_t:
			prev_s = s
			if bool(s["shot"]) and st > _last_replayed_t:
				shot_trigger = s
				_last_replayed_t = st
		else:
			next_s = s
			break
	var span: float = maxf(0.001, float(next_s["t"]) - float(prev_s["t"]))
	var u: float = clampf((want_t - float(prev_s["t"])) / span, 0.0, 1.0)
	var desired: Vector2 = clamp_to_arena((prev_s["pos"] as Vector2).lerp(next_s["pos"] as Vector2, u))
	_echo_pos = _echo_pos.move_toward(desired, 180.0 * dt)
	_echo_facing = (prev_s["facing"] as Vector2).normalized()

	# Replay Wick's recorded shots ONLY during READY pauses (so Echo never dogpiles a Present commit!)
	if not shot_trigger.is_empty() and _echo_shot_cd <= 0.0 and boss_state == BossState.READY:
		_echo_shot_cd = 5.2
		var sdir: Vector2 = (shot_trigger["facing"] as Vector2).normalized()
		ground.warn_lane(_echo_pos, clamp_to_arena(_echo_pos + sdir * 120.0), 6.0, 0.56, 0.0, "rose", "cream", 0.0, func(_d: Dictionary) -> void:
			if boss_state != BossState.DEATH and _echo_active:
				patterns.emit_fan(_echo_pos, sdir, 1, 0.0, 88.0, {"color": "rose", "source": "echo_gardener_bolt", "damage": 0.5})
				stage.play_sfx("bolt_fire", _echo_pos)
		)
	elif _echo_shot_cd <= 0.0 and _echo_dash_cd <= 0.0 and boss_state == BossState.READY and _rec_clock > 8.0:
		# Fallback if Wick fired 0 bolts: telegraphed Rose Shear-Dash from Echo Gardener
		_echo_dash_cd = 6.0
		var d: Vector2 = (target - _echo_pos).normalized() if target.distance_to(_echo_pos) > 1.0 else _echo_facing
		ground.warn_lane(_echo_pos, clamp_to_arena(_echo_pos + d * 80.0), 9.0, 0.58, 0.0, "rose", "gold", 0.0, func(_d: Dictionary) -> void:
			if boss_state != BossState.DEATH and _echo_active:
				patterns.emit_fan(_echo_pos, d, 2, 0.36, 92.0, {"color": "rose", "source": "echo_shear_dash", "damage": 0.5})
				stage.play_sfx("petal_echo", _echo_pos)
		)


func _fire_echo_gardener_volley(tgt: Vector2) -> void:
	var d: Vector2 = (tgt - _echo_pos).normalized() if tgt.distance_to(_echo_pos) > 1.0 else _echo_facing
	patterns.emit_fan(_echo_pos, d, 1, 0.0, 92.0, {"color": "rose", "source": "echo_gardener_bolt", "damage": 0.5})


func _check_mirror_reflections() -> void:
	# Any Echo Gardener bolt passing through an arena mirror reflects as a blue lance into Present Gardener!
	var mirror_pts: Array[Vector2] = []
	for m: Dictionary in _mirrors:
		mirror_pts.append(m["pos"] as Vector2)
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "blue_transformer":
				mirror_pts.append((it_v as LxInteractable).pos)

	for b: LxBossBolt in patterns.pool:
		if not b.active or b.reflected:
			continue
		for mi: int in range(mirror_pts.size()):
			if mi < _mirrors.size() and float(_mirrors[mi].get("cd", 0.0)) > 0.0:
				continue
			var mp: Vector2 = mirror_pts[mi]
			if b.pos.distance_to(mp) <= 13.0:
				var to_boss: Vector2 = (pos - mp).normalized() if pos.distance_to(mp) > 1.0 else -b.dir
				b.reflect(to_boss, 210.0)
				b.color_key = "sky"
				if mi < _mirrors.size():
					_mirrors[mi]["flash_t"] = 0.28
					_mirrors[mi]["cd"] = 3.5
				stage.play_sfx("mirror_ping", mp)
				break


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit != null and (hit.source == "reflected_bolt" or hit.source == LxHit.SOURCE_PRISM):
		if boss_state != BossState.STAGGER and stagger_immunity_t <= 0.0:
			_trigger_cloche_stagger(MIRROR_STAGGER_S, "gardener_annihilate")
		return dmg * 2.0
	if _cloche_broken and boss_state == BossState.STAGGER:
		return dmg * 2.0
	if hit != null and (hit.pierce or hit.cracks_armour):
		return dmg
	if not is_punishable():
		# Intact glass bell-jar cloche wards off unfocused bolts; Beam pierces, recover & cloche break pay big!
		return dmg * 0.40
	return dmg


func _trigger_cloche_stagger(dur: float, sfx_id: String) -> void:
	_cloche_broken = true
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, dur)
	staggered.emit(dur)
	LxDamageFx.boss_impact(pos, 0.20, 84.0, 88.0, 84.0, 1.42, 0.34, "ice")
	stage.play_sfx(sfx_id, pos)


func _on_death_start() -> void:
	_death_rose_t = 0.01


func _read_wick_shots() -> int:
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("shots_fired") != null:
		return int(Lx.player.get("shots_fired"))
	return 0


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["rose"] if phase >= 3 else (PAL["wine"] if phase == 2 else PAL["plum"])) as Color


func _draw_boss_extra(_off: Vector2) -> void:
	# Draw arena brass mirror prisms
	for m: Dictionary in _mirrors:
		var mp: Vector2 = ((m["pos"] as Vector2) - pos).round()
		var fl: bool = float(m["flash_t"]) > 0.0
		draw_rect(Rect2(mp + Vector2(-6.0, -7.0), Vector2(12.0, 14.0)), PAL["night"] as Color)
		draw_rect(Rect2(mp + Vector2(-5.0, -6.0), Vector2(10.0, 12.0)), (PAL["cream"] if fl else PAL["blue"]) as Color)
		draw_line(mp + Vector2(-4.0, 4.0), mp + Vector2(4.0, -4.0), PAL["ice"] as Color, 1.8)
		draw_rect(Rect2(mp + Vector2(-6.0, -7.0), Vector2(12.0, 2.0)), PAL["gold"] as Color)

	# Draw Phase 3 perimeter bloom roses
	for rp_w: Vector2 in _p3_roses:
		var rp: Vector2 = (rp_w - pos).round()
		draw_circle(rp, 5.5, Color(PAL["pine"] as Color, 0.7))
		draw_circle(rp, 3.4, PAL["rose"] as Color)
		draw_rect(Rect2(rp, Vector2.ONE), PAL["cream"] as Color)

	# Draw Echo Gardener ghost in rose/cream!
	if _echo_active and boss_state != BossState.DEATH:
		var ep: Vector2 = (_echo_pos - pos).round()
		var a: float = 0.55 if is_flash_reduced() else 0.80
		draw_circle(ep + Vector2(0.0, 4.0), 7.0, Color(PAL["void"] as Color, 0.32))
		draw_rect(Rect2(ep + Vector2(-6.0, -24.0), Vector2(12.0, 22.0)), Color(PAL["wine"] as Color, a * 0.72))
		draw_rect(Rect2(ep + Vector2(-5.0, -23.0), Vector2(10.0, 18.0)), Color(PAL["rose"] as Color, a))
		# Echo cloche dome + eyes
		draw_circle(ep + Vector2(0.0, -26.0), 5.5, Color(PAL["ice"] as Color, a * 0.85))
		draw_rect(Rect2(ep + Vector2(-2.0, -27.0), Vector2(1.0, 1.0)), Color(PAL["cream"] as Color, a))
		draw_rect(Rect2(ep + Vector2(1.0, -27.0), Vector2(1.0, 1.0)), Color(PAL["cream"] as Color, a))
		# Echo rose shears pip
		var tip: Vector2 = (ep + _echo_facing * 10.0 + Vector2(0.0, -10.0)).round()
		draw_line(ep + Vector2(0.0, -10.0), tip, Color(PAL["cream"] as Color, a), 1.6)
