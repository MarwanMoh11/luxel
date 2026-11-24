class_name LxBrassMetronomeBoss
extends LxBossBase
## Island 1 Mini-Boss #2: The Brass Metronome (Belfry r16).
## Inverted pendulum knight swinging on a crisp L-R-L escapement track;
## ring a Dusk Bell to freeze its arm wide open, popping out its bronze cuckoo core for 2.0s!
## P1: Pendulum Shear, Escapement Fan.
## P2 (<= 50% HP): Flanking escapement gear recesses + Twin-Tick Rail Lunge.

const SHEAR_RADIUS: float = 52.0
const RAIL_DASH_SPEED: float = 230.0
const DUSK_CUCKOO_STAGGER_S: float = 2.00
const BOB_ARMOR_MULT: float = 0.62
const CUCKOO_CRIT_MULT: float = 1.60

var _tick_phase: float = 0.0
var _shear_dir: Vector2 = Vector2.LEFT
var _shear_hit: bool = false
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_leg: int = 0
var _lunge_hit: bool = false
var _cuckoo_popped_t: float = 0.0
var _rail_y: float = 0.0


func _init() -> void:
	super._init()
	kind = "brass_metronome"
	boss_id = "brass_metronome"
	boss_name_key = "ISL1_BOSS_METRO"
	island_id = 1
	is_miniboss = true
	reward_heart = "half"
	music_cue = "island1_boss_p1"
	music_p2_cue = "island1_boss_p2"
	max_hp = 38.0
	hp = 38.0
	body_radius = 11.0
	move_speed = 40.0
	stagger_threshold = 9.5
	stagger_duration = 1.90
	post_recover_cd = 0.28
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.1
	shard_drop = 22


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Pendulum Shear (apex coral glint -> 52px sweeping halberd shear + 5/7 brass arcs!)
	register_attack("pendulum_shear", {
		"weight": 1.35, "tell": 0.50, "commit": 0.28, "recover": 1.10, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_shear_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _shear_dir.angle()
			_shear_hit = false
			ground.warn_sector(pos, facing - 1.15, facing + 1.15, SHEAR_RADIUS, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _shear_dir * 140.0), 11.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("metronome_tick", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 7 if phase >= 2 else 5
			patterns.emit_fan(pos, _shear_dir, cnt, 1.05, 134.0 if phase >= 2 else 118.0, {"color": "gold", "source": "pendulum_shear"})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			move_boss(_shear_dir * 86.0 * dt, false)
			if not _shear_hit and pos.distance_to(tgt) <= SHEAR_RADIUS:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.20:
					_shear_hit = true
					emit_boss_damage(_shear_dir, 1.0, "pendulum_shear", pos, true),
	})

	# Attack 2: Escapement Fan (crisp tempo 3/5-bolt brass fan + staggered aimed lane)
	register_attack("escapement_fan", {
		"weight": 1.20, "tell": 0.46, "commit": 0.26, "recover": 1.00, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim_d.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 145.0), 9.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("metronome_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 5 if phase >= 2 else 3, 0.62, 136.0 if phase >= 2 else 120.0, {"color": "apricot", "source": "escapement_fan"})
			patterns.emit_lane(pos, aim_d, 3 if phase >= 2 else 2, 146.0, 0.09, {"color": "coral", "source": "escapement_fan"})
			stage.shake(0.12)
			stage.play_sfx("clockwork_chime", pos),
	})

	# Attack 3: Twin-Tick Lunge (L-then-R rail dash sweeping across arena + cross-bolts!)
	register_attack("twin_tick_lunge", {
		"phases": [1, 2], "weight": 1.45, "tell": 0.52, "commit": 0.44, "recover": 1.30, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.RIGHT
			facing = _lunge_dir.angle()
			_lunge_leg = 0
			_lunge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _lunge_dir * 135.0), 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("metronome_tick", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_lunge_leg = 0
			_lunge_hit = false
			stage.shake(0.14)
			stage.play_sfx("hollow_dash", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, elapsed: float) -> void:
			_step_twin_tick(tgt, dt, elapsed),
	})

	# Attack 4 (P2): Escapement Gear Ring (P2 floor-gear resonance gap-ring pressuring all 8 perimeter spots!)
	register_attack("gear_ring_burst", {
		"phases": [2], "weight": 2.50, "tell": 0.52, "commit": 0.28, "recover": 1.15, "cooldown": 1.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 50.0, last_tell_duration, 1.0, "coral", "gold")
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 145.0), 8.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10, 126.0, aim_a + PI * 0.44, 0.70, {"color": "gold", "source": "gear_ring"})
			stage.shake(0.20)
			stage.play_sfx("bell_slam", pos),
	})


func _on_reset_encounter() -> void:
	_tick_phase = 0.0
	_shear_hit = false
	_lunge_leg = 0
	_lunge_hit = false
	_cuckoo_popped_t = 0.0
	_rail_y = arena_rect.get_center().y
	_spawn_escapement_bells()


func _spawn_escapement_bells() -> void:
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if not has_room_bell:
		var c: Vector2 = arena_rect.get_center()
		var k1 := Vector2(arena_rect.position.x + 22.0, c.y)
		var k2 := Vector2(arena_rect.end.x - 22.0, c.y)
		props.spawn_bell(k1, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dusk", (pos - bp).normalized())
			stage.play_sfx("clockwork_chime", bp), "metro_lab_bell_k1")
		props.spawn_bell(k2, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dusk", (pos - bp).normalized())
			stage.play_sfx("clockwork_chime", bp), "metro_lab_bell_k2")


func _step_twin_tick(tgt: Vector2, dt: float, elapsed: float) -> void:
	if phase >= 2 and _lunge_leg == 0 and elapsed >= 0.22:
		_lunge_leg = 1
		_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 2.0 else -_lunge_dir
		facing = _lunge_dir.angle()
		_lunge_hit = false
		var perp := Vector2(-_lunge_dir.y, _lunge_dir.x)
		patterns.emit_fan(pos, perp, 3, 0.55, 118.0, {"color": "gold", "source": "twin_tick"})
		patterns.emit_fan(pos, -perp, 3, 0.55, 118.0, {"color": "gold", "source": "twin_tick"})
		stage.play_sfx("metronome_tick", pos)
	move_boss(_lunge_dir * RAIL_DASH_SPEED * dt, false)
	if not _lunge_hit and pos.distance_to(tgt) <= 21.0:
		_lunge_hit = true
		emit_boss_damage(_lunge_dir, 1.0, "twin_tick_lunge", pos, true)


func on_ring(tone: String, _dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		# Signature Dusk Freeze -> freezes pendulum wide open & pops out the helpless bronze cuckoo core!
		_cuckoo_popped_t = DUSK_CUCKOO_STAGGER_S
		_release_token()
		active_attack_id = ""
		stagger_meter = 0.0
		_set_boss_state(BossState.STAGGER, DUSK_CUCKOO_STAGGER_S)
		staggered.emit(DUSK_CUCKOO_STAGGER_S)
		patterns.freeze_bolts_in_radius(pos, 150.0, 1.8, "dusk")
		stage.shake(0.20)
		stage.play_sfx("cuckoo_pop", pos)
		LxDamageFx.boss_impact(pos, 0.16, 76.0, 80.0, 76.0, 1.36, 0.30)
	elif t == "war":
		add_stagger(2.2)
		stage.play_sfx("shield_clang", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.STAGGER:
		_tick_phase += dt * (4.6 if phase >= 2 else 3.4)
	_cuckoo_popped_t = maxf(0.0, _cuckoo_popped_t - dt)
	move_speed = 48.0 if phase >= 2 else 40.0


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(cx_t - 4, cy_t - 2, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 4, cy_t + 2, 1, 1), "pit")
		props.spawn_pillar(c + Vector2(-56.0, 26.0), 4.0, "metro_gear_w")
		props.spawn_pillar(c + Vector2(56.0, -26.0), 4.0, "metro_gear_e")
		stage.shake(0.24)
		stage.play_sfx("shield_shatter", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	# Popped cuckoo core takes huge 1.6x damage!
	if _cuckoo_popped_t > 0.0 or boss_state == BossState.STAGGER:
		return dmg * CUCKOO_CRIT_MULT
	var h: Dictionary = _read_hit(hit)
	# Moving brass pendulum bob partially deflects frontal bolts until Dusk-frozen or in recover!
	if not is_punishable() and str(h["source"]) == LxHit.SOURCE_BOLT and not bool(h["pierce"]) and not bool(h["cracks_armour"]):
		var orig: Vector2 = h["origin"] as Vector2
		var rel: Vector2 = orig - pos
		if rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 0.85:
			clank_t = 0.12
			stage.play_sfx("shield_clang", pos)
			return dmg * BOB_ARMOR_MULT
	return dmg


func _on_death_start() -> void:
	stage.play_sfx("metronome_winddown", pos)
	stage.shake(0.22)


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 2 else PAL["apricot"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Brass escapement rail guide line across the floor
	var rl_x0: float = arena_rect.position.x + 14.0 - pos.x
	var rl_x1: float = arena_rect.end.x - 14.0 - pos.x
	var rl_y: float = _rail_y - pos.y
	draw_line(Vector2(rl_x0, rl_y).round(), Vector2(rl_x1, rl_y).round(), Color(PAL["gold"] as Color, 0.22), 2.0)
	# Cuckoo-popped comedy beat: ice-frozen halo & floating musical note pips!
	if _cuckoo_popped_t > 0.0 or boss_state == BossState.STAGGER:
		draw_arc(c, body_radius + 6.0, 0.0, TAU, 18, PAL["ice"] as Color, 1.6)
		for k: int in range(2):
			var ny: float = -body_radius - 10.0 - fmod(anim_t * 16.0 + float(k) * 8.0, 14.0)
			var nx: float = -5.0 + float(k) * 10.0 + sin(anim_t * 6.0 + float(k)) * 2.0
			draw_rect(Rect2((c + Vector2(nx, ny)).round(), Vector2(2.0, 3.0)), PAL["gold"] as Color)
			draw_rect(Rect2((c + Vector2(nx + 1.0, ny)).round(), Vector2(2.0, 1.0)), PAL["cream"] as Color)
