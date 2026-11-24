class_name LxBriarArbiterBoss
extends LxBossBase
## Island 3 Briar Court Final Judge: The Briar Arbiter (court_r4).
## Presides over the doubly-mutated courtroom arena, reading `court_v2` from Lx.vars ("island:3"):
##   - "mercy": opens a central miniature shrink-hollow sanctuary ring granting focused dew shots (1.35x).
##   - "fire": uncovers two flank blue-prism bells that shatter his thorn guard on hit!
## P2 (<= 50% HP): Weigh the Flame slams Left Scale Pan -> Wick counterbalances Right Scale Pan
## (by standing or throwing lantern onto Pan R) for a solemn 1.80 s stagger!

const SCALE_STAGGER_S: float = 1.80
const ANTLER_SPEED: float = 148.0

var _verdict_v2: String = "none"
var _pan_left: Vector2 = Vector2.ZERO
var _pan_right: Vector2 = Vector2.ZERO
var _mercy_ring_pos: Vector2 = Vector2.ZERO
var _scale_trial_t: float = 0.0
var _thorn_guard_up: bool = false
var _charge_dir: Vector2 = Vector2.LEFT
var _charge_hit: bool = false


func _init() -> void:
	super._init()
	kind = "briar_arbiter"
	boss_id = "briar_arbiter"
	boss_name_key = "ISL3_BOSS_ARBITER"
	island_id = 3
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 88.0
	hp = 88.0
	body_radius = 12.5
	move_speed = 36.0
	stagger_threshold = 13.0
	stagger_duration = 1.80
	post_recover_cd = 0.48
	intro_duration = 0.65
	phase_shift_duration = 0.70
	death_duration = 2.4
	shard_drop = 34


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Gavel Shockwave (expanding ring slam + gap ring + targeted judgment pillar)
	register_attack("gavel_shockwave", {
		"weight": 1.25, "tell": 0.66, "commit": 0.34, "recover": 1.25, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 42.0, last_tell_duration, 1.0, "coral", "gold")
			patterns.emit_pillars([clamp_to_arena(tgt)], last_tell_duration + 0.14, 15.0, 0.28, 1.0, "gold")
			stage.play_sfx("ba_court_gavel", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 8, 92.0, gap_a, 1.15, {"color": "gold", "source": "gavel_wave"})
			stage.shake(0.22)
			stage.play_sfx("ba_court_gavel", pos),
	})

	# Attack 2: Antler Charge (charges along telegraphed lane flinging emerald thorn fan)
	register_attack("antler_charge", {
		"weight": 1.20, "tell": 0.60, "commit": 0.40, "recover": 1.22, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_charge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = _charge_dir.angle()
			_charge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _charge_dir * 165.0), 13.0, last_tell_duration, 0.0, "coral", "lime")
			stage.play_sfx("ba_scale_clang", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _charge_dir, 3, 0.72, 96.0, {"color": "lime", "source": "antler_thorn"})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_charge_dir * ANTLER_SPEED * dt, false)
			if not _charge_hit and pos.distance_to(tgt) <= 17.0:
				_charge_hit = true
				emit_boss_damage(_charge_dir, 1.0, "antler_charge", pos, true),
	})

	# Attack 3: Verdict Columns (judgment rain across Wick & perimeter corners + aimed gavel lance)
	register_attack("verdict_columns", {
		"weight": 1.15, "tell": 0.62, "commit": 0.40, "recover": 1.20, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.18, 19.0, 1.0, "coral", "gold")
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 170.0), 9.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("ba_scale_clang", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, aim_d, 3, 108.0, 0.12, {"color": "gold", "source": "verdict_bolt"})
			stage.shake(0.16)
			stage.play_sfx("ba_court_gavel", pos),
	})

	# Attack 4: P2 Weigh the Flame (slams Pan L -> safe-zone scale trial; weigh Pan R for 1.8 s stagger!)
	register_attack("weigh_the_flame", {
		"phases": [2], "weight": 2.70, "tell": 0.94, "commit": 0.44, "recover": 1.35, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_scale_trial_t = last_tell_duration + 2.8
			_thorn_guard_up = true
			var to_r: Vector2 = (_pan_right - tgt).normalized() if tgt.distance_to(_pan_right) > 4.0 else Vector2.RIGHT
			var near_safe: Vector2 = clamp_to_arena(tgt + to_r * 36.0)
			ground.warn_safe_inversion(arena_rect, [_pan_right, near_safe], 34.0, last_tell_duration, 0.22, 1.0, "lime", "coral")
			stage.play_sfx("ba_scale_clang", _pan_left),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_ring(_pan_left, 5, 86.0, anim_t, {"color": "apricot", "source": "scale_burst"})
			stage.light_burst(_pan_right, 76.0, 1.35, 0.40)
			stage.shake(0.22)
			stage.play_sfx("ba_court_gavel", _pan_left),
	})


func _on_reset_encounter() -> void:
	var c: Vector2 = arena_rect.get_center()
	_pan_left = clamp_to_arena(c + Vector2(-62.0, 0.0))
	_pan_right = clamp_to_arena(c + Vector2(62.0, 0.0))
	_mercy_ring_pos = clamp_to_arena(c + Vector2(0.0, 32.0))
	_scale_trial_t = 0.0
	_thorn_guard_up = false
	_charge_hit = false
	_verdict_v2 = str(Lx.vars.get_var("island:3", "court_v2", "none")) if Lx.vars != null else "none"
	_setup_verdict_v2_tools()


func _setup_verdict_v2_tools() -> void:
	if _verdict_v2 == "fire":
		var c: Vector2 = arena_rect.get_center()
		for off_v: Vector2 in [Vector2(-86.0, -34.0), Vector2(86.0, -34.0)]:
			var bp: Vector2 = clamp_to_arena(c + off_v)
			props.spawn_bell(bp, func(_p: Dictionary) -> void:
				_thorn_guard_up = false
				add_stagger(4.5)
				stage.play_sfx("prism_hit", bp), "ba_fire_prism_%d" % int(off_v.x))


func _judgment_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	return out


func _on_boss_tick(dt: float, target: Vector2) -> void:
	if _scale_trial_t > 0.0:
		_scale_trial_t = maxf(0.0, _scale_trial_t - dt)
		var lan_p: Vector2 = _get_lantern_pos()
		if target.distance_to(_pan_right) <= 22.0 or (_is_lantern_hung() and lan_p.distance_to(_pan_right) <= 24.0):
			_trigger_scale_balance()
		elif _scale_trial_t <= 0.0:
			_thorn_guard_up = false


func _trigger_scale_balance() -> void:
	_scale_trial_t = 0.0
	_thorn_guard_up = false
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, SCALE_STAGGER_S)
	staggered.emit(SCALE_STAGGER_S)
	stage.light_burst(_pan_right, 88.0, 1.4, 0.40)
	stage.shake(0.24)
	stage.play_sfx("ba_seed_verdict", _pan_right)
	LxDamageFx.boss_impact(pos, 0.22, 86.0, 88.0, 86.0, 1.42, 0.34)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Split outer courtroom corners with twin verdict recesses (safe from orbit ring; rolled back on retry!)
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "pit")
		_thorn_guard_up = true
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("ba_court_gavel", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var mult: float = 1.0
	if _verdict_v2 == "mercy" and _get_wick_pos().distance_to(_mercy_ring_pos) <= 24.0:
		mult = 1.35
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM:
		_thorn_guard_up = false
		return dmg * 1.25 * mult
	if src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_THROW:
		_thorn_guard_up = false
		return dmg * 1.15 * mult
	if _thorn_guard_up and not is_punishable():
		clank_t = 0.08
		return dmg * 0.52 * mult
	return dmg * mult


func _on_death_start() -> void:
	_thorn_guard_up = false
	_scale_trial_t = 0.0
	if Lx.state != null:
		Lx.state.story_flags["briar_court_done"] = true
	stage.light_burst(pos, 120.0, 1.5, 0.55)
	stage.play_sfx("ba_seed_verdict", pos)


func _has_active_shield() -> bool:
	return _thorn_guard_up and not is_punishable()


func _shield_color() -> Color:
	return PAL["lime"] as Color


func _draw_boss_extra(_off: Vector2) -> void:
	var inv: Vector2 = -pos
	# Mercy Shrink-Hollow sanctuary ring
	if _verdict_v2 == "mercy":
		var mp: Vector2 = (_mercy_ring_pos + inv).round()
		draw_circle(mp, 20.0, Color(PAL["pine"] as Color, 0.30))
		draw_arc(mp, 20.0, 0.0, TAU, 20, PAL["lime"] as Color, 1.2)
	# Twin P2 brass Justice Scale Pans!
	if phase >= 2 or _scale_trial_t > 0.0:
		var pl: Vector2 = (_pan_left + inv).round()
		var pr: Vector2 = (_pan_right + inv).round()
		draw_line(pl, pr, Color(PAL["gold"] as Color, 0.45), 1.0)
		var l_col: Color = PAL["coral"] as Color if _scale_trial_t > 0.0 else PAL["apricot"] as Color
		var r_col: Color = PAL["lime"] as Color if _scale_trial_t > 0.0 else PAL["gold"] as Color
		draw_circle(pl, 18.0, Color(l_col, 0.24))
		draw_arc(pl, 18.0, 0.0, TAU, 20, l_col, 1.5)
		draw_circle(pr, 18.0, Color(r_col, 0.28))
		draw_arc(pr, 18.0, 0.0, TAU, 20, PAL["cream"] as Color if (_scale_trial_t > 0.0 and not is_flash_reduced() and int(anim_t * 8.0) % 2 == 0) else r_col, 1.6)
