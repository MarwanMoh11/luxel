class_name LxClockworkValetBoss
extends LxBossBase
## Island 1 Mini-Boss: The Clockwork Valet (Manor r5).
## Twin silver trays deflect frontal bolts; throw your lantern behind him (or onto a lantern hook)
## so he bows politely to inspect the light, exposing his glowing gold winding-key back!
## P1: Spotlight Salute, Silver Tray Lunge, Candle Toss.
## P2 (<= 50% HP): Dims workshop lamps, cracks outer corner grates, adds Twin Spotlight Waltz.

const FRONT_GUARD_HALF: float = 1.02
const FRONT_CHIP_MULT: float = 0.55
const BACK_CRIT_MULT: float = 1.55
const LUNGE_SPEED: float = 195.0
const LUNGE_HIT_R: float = 22.0
const BOW_LURE_DUR: float = 1.35

var _aim_dir: Vector2 = Vector2.LEFT
var _lunge_hit: bool = false
var _bow_lure_t: float = 0.0
var _bow_lure_cd: float = 0.0
var _dusk_freeze_t: float = 0.0
var _sweep_ang: float = 0.0
var _sweep_dir: float = 1.0
var _sweep_shots: int = 0
var _dust_spark_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "clockwork_valet"
	boss_id = "clockwork_valet"
	boss_name_key = "ISL1_BOSS_VALET"
	island_id = 1
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl1_boss_minor_p1"
	music_p2_cue = "isl1_boss_minor_p2"
	max_hp = 28.0
	hp = 28.0
	body_radius = 10.5
	move_speed = 42.0
	stagger_threshold = 8.5
	stagger_duration = 1.75
	punish_dmg_mult = 1.40
	post_recover_cd = 0.30
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.1
	shard_drop = 20


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Spotlight Salute (60 deg monocle beam sweep + crisp 3/5-bolt ice-gold volley)
	register_attack("spotlight_salute", {
		"weight": 1.30, "tell": 0.52, "commit": 0.56, "recover": 1.15, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			_sweep_ang = facing - 0.52
			_sweep_dir = 1.0 if _orbit_side >= 0.0 else -1.0
			_sweep_shots = 0
			ground.warn_sector(pos, facing - 0.52, facing + 0.52, 74.0, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 145.0), 10.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("valet_spotlight_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.72, 134.0 if phase >= 2 else 118.0, {"color": "ice", "source": "valet_spotlight"})
			stage.shake(0.12)
			stage.play_sfx("clockwork_chime", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, elapsed: float) -> void:
			if _dusk_freeze_t > 0.0:
				return
			_sweep_ang += _sweep_dir * 1.45 * dt
			facing = wrapf(_sweep_ang, -PI, PI)
			if _sweep_shots == 0 and elapsed >= 0.28:
				_sweep_shots = 1
				var d2: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
				patterns.emit_fan(pos, d2, 3, 0.42, 126.0, {"color": "gold", "source": "valet_spotlight"})
				stage.play_sfx("clockwork_chime", pos),
	})

	# Attack 2: Silver Tray Lunge (fast formal thrust + wide silver crescent bolts)
	register_attack("silver_tray_lunge", {
		"weight": 1.25, "tell": 0.48, "commit": 0.34, "recover": 1.10, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			_lunge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 124.0), 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_lunge_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_lunge_hit = false
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.62, 132.0, {"color": "apricot", "source": "valet_tray"})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			var spd: float = LUNGE_SPEED * (0.42 if _dusk_freeze_t > 0.0 else 1.0)
			move_boss(_aim_dir * spd * dt, false)
			if not _lunge_hit and pos.distance_to(tgt) <= LUNGE_HIT_R:
				_lunge_hit = true
				emit_boss_damage(_aim_dir, 1.0, "silver_tray_lunge", pos, true),
	})

	# Attack 3: Candle Toss (3/4 lingering wax-flame floor pools pressuring Wick + corners)
	register_attack("candle_toss", {
		"weight": 1.15, "tell": 0.50, "commit": 0.30, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			var drops: Array[Vector2] = _build_candle_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("valet_candle_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _aim_dir
			patterns.emit_fan(pos, d, 4 if phase >= 2 else 3, 0.75, 114.0, {"color": "apricot", "source": "valet_candle"})
			stage.shake(0.12)
			stage.play_sfx("brazier_lit", pos),
	})

	# Attack 4 (P2): Twin Spotlight Waltz (dimmed room + opposing dual monocle beams!)
	register_attack("twin_spotlight_waltz", {
		"phases": [2], "weight": 2.60, "tell": 0.52, "commit": 0.54, "recover": 1.20, "cooldown": 1.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			_sweep_shots = 0
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 145.0), 11.0, last_tell_duration, 0.0, "ice", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos - _aim_dir * 145.0), 11.0, last_tell_duration, 0.0, "gold", "cream")
			stage.darkness_pulse(0.68, 1.1)
			stage.play_sfx("valet_spotlight_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _aim_dir, 4, 0.65, 130.0, {"color": "ice", "source": "valet_dual_beam"})
			patterns.emit_fan(pos, -_aim_dir, 4, 0.65, 130.0, {"color": "gold", "source": "valet_dual_beam"})
			stage.shake(0.16)
			stage.play_sfx("clockwork_chime", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			if _dusk_freeze_t > 0.0:
				return
			facing = wrapf(facing + 2.4 * dt, -PI, PI)
			if _sweep_shots == 0 and elapsed >= 0.26:
				_sweep_shots = 1
				var perp := Vector2(-_aim_dir.y, _aim_dir.x)
				patterns.emit_fan(pos, perp, 3, 0.50, 122.0, {"color": "ice", "source": "valet_dual_beam"})
				patterns.emit_fan(pos, -perp, 3, 0.50, 122.0, {"color": "gold", "source": "valet_dual_beam"}),
	})


func _on_reset_encounter() -> void:
	_lunge_hit = false
	_bow_lure_t = 0.0
	_bow_lure_cd = 0.0
	_dusk_freeze_t = 0.0
	_dust_spark_t = 0.0
	_spawn_workshop_bells()


func _spawn_workshop_bells() -> void:
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if not has_room_bell:
		var c: Vector2 = arena_rect.get_center()
		var dusk_p := Vector2(c.x + 34.0, arena_rect.position.y + 20.0)
		var b_dusk: Dictionary = props.spawn_bell(dusk_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dusk", (pos - bp).normalized())
			stage.play_sfx("clockwork_chime", bp), "valet_lab_bell_dusk")
		b_dusk["solid"] = false


func _build_candle_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.45)))
	if phase >= 2:
		out.append(corners[1])
	return out


func on_ring(tone: String, _dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_dusk_freeze_t = 2.0
		patterns.freeze_bolts_in_radius(pos, 140.0, 1.5, "dusk")
		add_stagger(3.5)
		stage.play_sfx("clockwork_chime", pos)
	elif t == "war":
		add_stagger(2.0)
		stage.play_sfx("shield_clang", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_dusk_freeze_t = maxf(0.0, _dusk_freeze_t - dt)
	_bow_lure_cd = maxf(0.0, _bow_lure_cd - dt)
	_dust_spark_t = maxf(0.0, _dust_spark_t - dt)
	move_speed = 18.0 if _dusk_freeze_t > 0.0 else (48.0 if phase >= 2 else 42.0)

	# Signature polite-bow lure: if Wick hangs/throws lantern behind Valet, he turns & bows politely!
	if _bow_lure_t > 0.0:
		_bow_lure_t = maxf(0.0, _bow_lure_t - dt)
	elif _bow_lure_cd <= 0.0 and boss_state == BossState.READY and _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if lp.distance_to(pos) <= 136.0:
			var to_l: Vector2 = lp - pos
			if to_l.length() > 4.0:
				facing = to_l.angle()
			_bow_lure_t = BOW_LURE_DUR
			_bow_lure_cd = 5.5
			_release_token()
			active_attack_id = ""
			_set_boss_state(BossState.RECOVER, BOW_LURE_DUR)
			last_recover_duration = BOW_LURE_DUR
			stage.play_sfx("valet_bow_chime", pos)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var tl_tx: int = maxi(2, int(arena_rect.position.x / 16.0) + 1)
		var tl_ty: int = maxi(1, int(arena_rect.position.y / 16.0) + 1)
		var br_tx: int = maxi(tl_tx + 4, int(arena_rect.end.x / 16.0) - 2)
		var br_ty: int = maxi(tl_ty + 3, int(arena_rect.end.y / 16.0) - 2)
		stage.set_tiles(world_ctx, Rect2i(tl_tx, tl_ty, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(br_tx, br_ty, 1, 1), "pit")
		stage.darkness_pulse(0.74, 1.3)
		stage.shake(0.22)
		stage.play_sfx("bell_warden_phase2", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var ang_diff: float = absf(angle_difference(facing, rel.angle())) if rel.length() > 1.0 else 0.0
	var is_back: bool = rel.length() > 1.0 and ang_diff >= 1.85
	var is_front: bool = rel.length() > 1.0 and ang_diff < FRONT_GUARD_HALF

	# Exposed winding-key back crit (especially when bowing politely to thrown lantern!)
	if is_back or _bow_lure_t > 0.0 or boss_state == BossState.STAGGER:
		if boss_state == BossState.STAGGER:
			_dust_spark_t = 0.45
		return dmg * (BACK_CRIT_MULT if is_back else 1.20)

	# Twin silver trays guard frontal bolts while poised in READY/TELL/COMMIT
	if is_front and not is_punishable() and str(h["source"]) == LxHit.SOURCE_BOLT and not bool(h["pierce"]) and not bool(h["cracks_armour"]):
		clank_t = 0.14
		stage.play_sfx("shield_clang", pos)
		return dmg * FRONT_CHIP_MULT
	return dmg


func _on_death_start() -> void:
	stage.play_sfx("valet_unwind", pos)
	stage.shake(0.22)


func _body_color() -> Color:
	return (PAL["wine"] if phase >= 2 else PAL["plum"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# Silver tray front guard gleam
	if not is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.0, facing - FRONT_GUARD_HALF, facing + FRONT_GUARD_HALF, 12, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 4.0, facing - FRONT_GUARD_HALF, facing + FRONT_GUARD_HALF, 12, PAL["stone"] as Color, 2.0)
	# Glowing exposed winding-key marker on back when bowing / staggered
	if _bow_lure_t > 0.0 or boss_state == BossState.STAGGER or boss_state == BossState.RECOVER:
		var back_p: Vector2 = (c - Vector2.from_angle(facing) * (body_radius + 5.0)).round()
		draw_circle(back_p, 4.0, PAL["void"] as Color)
		draw_circle(back_p, 3.0, PAL["gold"] as Color)
		draw_circle(back_p, 1.5, PAL["cream"] as Color)
	if _dusk_freeze_t > 0.0:
		draw_arc(c, body_radius + 6.5, 0.0, TAU, 16, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 6.5, 0.0, TAU, 16, PAL["ice"] as Color, 2.0)
	# Comedy beat: tiny floating dust puffs while Valet furiously dusts scorch marks in STAGGER!
	if boss_state == BossState.STAGGER:
		for k: int in range(3):
			var a: float = anim_t * (2.2 if fred else 7.0) + float(k) * 2.1
			var dp: Vector2 = (c + Vector2(cos(a) * 14.0, -8.0 + sin(a) * 6.0)).round()
			draw_circle(dp, 1.6, PAL["rose"] if k % 2 == 0 else PAL["cream"])
