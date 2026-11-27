class_name LxHollowRamPhantomBoss
extends LxBossBase
## Island 6 Iron Collision Skirmish Boss: IRON PHANTOM (`crash_r3`).
## Hollow Wick's dark violet echo aboard the runaway Ember Express roof — mirrors YOUR current Bolt Temper
## (Skip / Scatter / Lance) via LxBossDuel while defending both Master Throttle Locks (R1 / R2)!
## Pulling/striking the twin Throttle Locks staggers Phantom & surges the locomotive; defeating Phantom
## (or locking both room throttle pull_rings) completes the Iron Collision duel!

const DASH_SPEED: float = 232.0
const ZIP_SPEED: float = 310.0

var _aim_dir: Vector2 = Vector2.LEFT
var _zip_target: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.LEFT
var _active_temper: String = ""
var _locks_pulled: int = 0
var _lock_done: Dictionary = {}
var _lock_positions: Array[Vector2] = []
var _throttle_stagger_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "hollow_ram_phantom"
	boss_id = "hollow_ram_phantom"
	boss_name_key = "ISL6_BOSS_PHANTOM"
	island_id = 6
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 96.0
	hp = 96.0
	body_radius = 8.5
	move_speed = 54.0
	stagger_threshold = 13.0
	stagger_duration = 1.75
	post_recover_cd = 0.24
	intro_duration = 0.48
	death_duration = 1.6
	shard_drop = 22


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1 (P1+P2): Mirrored Temper Burst (fires Wick's live Temper: Skip / Scatter / Lance!)
	register_attack("mirrored_temper_burst", {
		"weight": 1.45, "tell": 0.50, "commit": 0.26, "recover": 1.10, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_active_temper = duel.read_wick_temper()
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var t_col: String = _temper_color(_active_temper)
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 145.0), 10.0, last_tell_duration, 0.0, t_col, "cream")
			stage.play_sfx("prism_bounce", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_fire_mirrored_temper(_aim_dir, _active_temper)
			stage.play_sfx("hollow_dash", pos)
			stage.shake(0.14),
	})

	# Attack 2 (P1+P2): Dark Zip Feint (flings black-glass lantern -> zips with 24px violet burst!)
	register_attack("dark_zip_feint", {
		"weight": 1.25, "tell": 0.48, "commit": 0.28, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_zip_target = clamp_to_arena(tgt)
			ground.warn_ring(_zip_target, 26.0, last_tell_duration, 0.0, "rose", "cream")
			stage.play_sfx("lantern_throw", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("zip_streak", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss((_zip_target - pos).limit_length(ZIP_SPEED * dt), true)
			if pos.distance_to(_zip_target) <= 10.0 and not _commit_hit_done:
				check_contact_damage(26.0, Vector2.from_angle(facing), 1.0, "phantom_zip")
				patterns.emit_ring(pos, 6 if phase >= 2 else 4, 126.0, facing, {"color": "rose", "source": "phantom_zip_burst"})
				_commit_hit_done = true
				stage.shake(0.14),
	})

	# Attack 3 (P1+P2): Brake-Slice Dash (high-speed violet roof slice!)
	register_attack("brake_slice_dash", {
		"weight": 1.20, "tell": 0.46, "commit": 0.28, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_dash_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _dash_dir * 96.0), 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("steam_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("hollow_dash", pos)
			stage.shake(0.12),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_dash_dir * DASH_SPEED * dt, true)
			check_contact_damage(16.0, _dash_dir, 1.0, "phantom_slice"),
	})

	# Attack 4 (P2): Echo Shadow Snare (uses LxBossDuel echo recorder + flanking violet volley!)
	register_attack("echo_temper_ambush", {
		"phases": [2],
		"weight": 1.65, "tell": 0.52, "commit": 0.30, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var snap: Dictionary = duel.get_echo_snapshot(1.3)
			var ep: Vector2 = clamp_to_arena(snap.get("pos", tgt) as Vector2) if not snap.is_empty() else clamp_to_arena(tgt)
			var drops: Array[Vector2] = [clamp_to_arena(tgt), ep]
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "rose", "coral")
			stage.play_sfx("hollow_dash", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			_fire_mirrored_temper(d, duel.read_wick_temper())
			stage.play_sfx("prism_bounce", pos)
			stage.shake(0.16),
	})


func _fire_mirrored_temper(dir: Vector2, t: String) -> void:
	var tm: String = t.to_lower()
	if tm == "scatter":
		patterns.emit_fan(pos, dir, 5 if phase >= 2 else 3, 0.72, 138.0, {"color": "apricot", "source": "phantom_scatter"})
	elif tm == "lance":
		patterns.emit_lane(pos, dir, 3 if phase >= 2 else 2, 174.0, 0.08, {"color": "coral", "source": "phantom_lance"})
		patterns.emit_fan(pos, dir, 3, 0.42, 128.0, {"color": "rose", "source": "phantom_lance_side"})
	elif tm == "skip":
		# Ricocheting Skip twin-bank volley!
		patterns.emit_fan(pos, dir, 3, 0.55, 148.0, {"color": "gold", "source": "phantom_skip", "bounces": 1})
		if phase >= 2:
			patterns.emit_fan(pos, dir.rotated(0.35), 2, 0.30, 132.0, {"color": "rose", "source": "phantom_skip_2", "bounces": 1})
	else:
		# Default dark-violet temper mirror (alternates Skip bounce & 3-shot burst)
		var cnt: int = 5 if phase >= 2 else 3
		patterns.emit_fan(pos, dir, cnt, 0.62, 144.0, {"color": "rose", "source": "phantom_temper", "bounces": 1})


func _on_reset_encounter() -> void:
	_active_temper = ""
	_locks_pulled = 0
	_lock_done.clear()
	_throttle_stagger_t = 0.0
	_lock_positions.clear()
	var c: Vector2 = arena_rect.get_center()
	var r1: Vector2 = clamp_to_arena(c + Vector2(-54.0, -44.0))
	var r2: Vector2 = clamp_to_arena(c + Vector2(54.0, 44.0))
	_lock_positions = [r1, r2]
	# Twin Master Throttle Lock bells (one-time lock each; can be pulled/struck in boss_lab or real crash_r3!)
	props.spawn_bell(r1, func(_p: Dictionary) -> void: on_throttle_lock(r1, "r1"), "throttle_r1")
	props.spawn_bell(r2, func(_p: Dictionary) -> void: on_throttle_lock(r2, "r2"), "throttle_r2")


func on_throttle_lock(at_p: Vector2 = Vector2.ZERO, lock_id: String = "") -> void:
	if not engaged or boss_state == BossState.DEATH:
		return
	if not lock_id.is_empty() and bool(_lock_done.get(lock_id, false)):
		return
	if not lock_id.is_empty():
		_lock_done[lock_id] = true
	_locks_pulled += 1
	_throttle_stagger_t = 1.9
	var fx_p: Vector2 = pos if at_p == Vector2.ZERO else at_p
	stage.play_sfx("steam_whistle", fx_p)
	stage.play_sfx("coupler_snap", fx_p)
	stage.light_burst(fx_p, 64.0, 1.35, 0.28)
	stage.shake(0.20)
	hp = maxf(1.0, hp - 6.0)
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)
	_check_phase_thresholds()


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _throttle_stagger_t > 0.0:
		_throttle_stagger_t = maxf(0.0, _throttle_stagger_t - dt)
	if engaged and boss_state != BossState.DEATH:
		duel.tick_echo_recorder(dt)
		# Speeding sunset roof wind streaks (gentle, never shoves into edge!)
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and arena_rect.grow(-28.0).has_point(w.global_position) and w.has_method("push_external"):
				w.call("push_external", Vector2(-10.0 if phase == 1 else -14.0, 0.0), "collision_wind")


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Runaway throttle surges — twin roof smokestack cowlings lock up (reverted cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(5, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(14, 8, 1, 1), "wall")
		stage.play_sfx("steam_whistle", pos)
		stage.darkness_pulse(0.62, 0.85)
		stage.shake(0.22)


func _on_death_start() -> void:
	stage.play_sfx("steam_whistle", pos)
	stage.light_burst(pos, 84.0, 1.35, 0.35)


static func _temper_color(t: String) -> String:
	match t.to_lower():
		"skip": return "gold"
		"scatter": return "apricot"
		"lance": return "coral"
		_: return "rose"


func _body_color() -> Color:
	return (PAL["rose"] if phase >= 2 else PAL["plum"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var fred: bool = is_flash_reduced()
	# Streaking sunset wind trails across locomotive roof
	if engaged and boss_state != BossState.DEATH and not fred:
		var c_off: Vector2 = -pos
		for wi: int in range(5):
			var wx: float = fmod(arena_rect.end.x - anim_t * 175.0 - float(wi) * 56.0, arena_rect.size.x)
			if wx < 0.0: wx += arena_rect.size.x
			var wy: float = arena_rect.position.y + 18.0 + float(wi) * (arena_rect.size.y - 36.0) * 0.25
			var p0: Vector2 = (Vector2(arena_rect.position.x + wx, wy) + c_off).round()
			draw_line(p0, p0 + Vector2(-16.0, 0.0), Color(PAL["apricot"] as Color, 0.30), 1.0)
	# Pulsing gold halos on Master Throttle Locks (R1 / R2)
	for lp_w: Vector2 in _lock_positions:
		var lp: Vector2 = (lp_w - pos).round()
		draw_arc(lp, 10.5, 0.0, TAU, 16, Color(PAL["void"] as Color, 0.68), 3.0)
		draw_arc(lp, 10.5, 0.0, TAU, 16, Color(PAL["gold"] as Color, 0.68), 1.0)
	# Violet-coral temper aura around Phantom during TELL / P2
	if boss_state == BossState.TELL or (phase >= 2 and boss_state != BossState.DEATH):
		var col: Color = LxPalette.color(_temper_color(_active_temper), "rose")
		var ta: float = anim_t * (1.8 if fred else 6.0)
		draw_arc(off.round(), body_radius + 4.0, ta, ta + PI * 1.4, 16, Color(PAL["void"] as Color, 0.72), 3.0)
		draw_arc(off.round(), body_radius + 4.0, ta, ta + PI * 1.4, 16, Color(col, 0.72), 1.0)
