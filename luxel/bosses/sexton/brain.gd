class_name LxSextonBoss
extends LxBossBase
## Island 1 Major Boss: The Sexton (Undercroft r11).
## Mole-toad gravedigger who tunnels beneath Wick digging pits; strike a Sanctuary Bell while
## he burrows to cave in his tunnel and flip him belly-up for a huge 2.4s punish window!
## P1: Tunnel Carve, Spade Cleave, Dirt Volley.
## P2 (<= 60% HP): Cross-trench splits arena into 4 islands + wakes 2 grave_hands.
## P3 (<= 32% HP): Raises stone coffin-lid front shield (War Bell shatters it!) + Coffin Slam.

const TUNNEL_SPEED: float = 112.0
const CLEAVE_RADIUS: float = 44.0
const COFFIN_RING_R: float = 60.0
const CAVE_IN_STAGGER_TIME: float = 2.40
const COFFIN_SHIELD_MAX: float = 5.0

var _burrowed: bool = false
var _tunnel_dir: Vector2 = Vector2.LEFT
var _tunnel_pit_cd: float = 0.0
var _cleave_dir: Vector2 = Vector2.LEFT
var _cleave_hit: bool = false
var _coffin_shield_hp: float = 0.0
var _dusk_slow_t: float = 0.0
var _pat_spade_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "sexton"
	boss_id = "sexton"
	boss_name_key = "ISL1_BOSS_SEXTON"
	island_id = 1
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island1_boss_p1"
	music_p2_cue = "island1_boss_p2"
	max_hp = 54.0
	hp = 54.0
	body_radius = 12.0
	move_speed = 36.0
	stagger_threshold = 12.0
	stagger_duration = 1.75
	post_recover_cd = 0.30
	intro_duration = 0.65
	phase_shift_duration = 0.72
	death_duration = 2.4
	shard_drop = 32


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.60, 0.32])

	# Attack 1: Tunnel Carve (burrows invulnerable digging erupting pits; ring bell to cave-in!)
	register_attack("tunnel_carve", {
		"weight": 1.30, "tell": 0.65, "commit": 1.25, "recover": 1.35, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_tunnel_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _tunnel_dir.angle()
			ground.warn_ring(pos, 24.0, last_tell_duration, 0.0, "apricot", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _tunnel_dir * 120.0), 14.0, last_tell_duration, 0.0, "coral", "apricot")
			stage.play_sfx("earth_burrow", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_burrowed = true
			_tunnel_pit_cd = 0.12
			stage.shake(0.14)
			stage.play_sfx("earth_burrow", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			_step_tunnel_commit(tgt, dt),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if _burrowed:
				_burrowed = false
				_pat_spade_t = 0.75
				stage.play_sfx("earth_burrow", pos),
	})

	# Attack 2: Spade Cleave (130 deg bronze bell-spade sweep + earth-wave bolts)
	register_attack("spade_cleave", {
		"weight": 1.20, "tell": 0.50, "commit": 0.26, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cleave_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _cleave_dir.angle()
			_cleave_hit = false
			ground.warn_sector(pos, facing - 1.13, facing + 1.13, CLEAVE_RADIUS, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _cleave_dir * 135.0), 10.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _cleave_dir, cnt, 0.78, 128.0 if phase >= 2 else 112.0, {"color": "apricot", "source": "spade_wave"})
			stage.shake(0.16)
			stage.play_sfx("sexton_cleave", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			move_boss(_cleave_dir * 82.0 * dt, false)
			if not _cleave_hit and pos.distance_to(tgt) <= CLEAVE_RADIUS:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.20:
					_cleave_hit = true
					emit_boss_damage(_cleave_dir, 1.0, "spade_cleave", pos, true),
	})

	# Attack 3: Dirt Volley (3-4 lobbed crypt clods targeting Wick + nearest corner + P2+ scatter)
	register_attack("dirt_volley", {
		"weight": 1.15, "tell": 0.48, "commit": 0.34, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_clod_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "coral", "apricot")
			stage.play_sfx("earth_burrow", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			if phase >= 2:
				patterns.emit_fan(pos, aim_d, 5, 0.90, 118.0, {"color": "coral", "source": "dirt_clod"})
			stage.shake(0.16)
			stage.play_sfx("stone_break", pos),
	})

	# Attack 4: P3 Coffin Slam (58px shockwave + gap ring; War Bell breaks coffin-lid shield!)
	register_attack("coffin_slam", {
		"phases": [3], "weight": 2.60, "tell": 0.54, "commit": 0.30, "recover": 1.25, "cooldown": 1.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, COFFIN_RING_R, last_tell_duration, 1.0, "coral", "gold")
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 145.0), 10.0, last_tell_duration, 0.0, "coral", "cream")
			stage.play_sfx("bell_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10, 122.0, aim_a + PI * 0.45, 0.68, {"color": "gold", "source": "coffin_ring"})
			stage.shake(0.24)
			stage.play_sfx("bell_slam_fire", pos),
	})


func _on_reset_encounter() -> void:
	_burrowed = false
	_coffin_shield_hp = 0.0
	_dusk_slow_t = 0.0
	_pat_spade_t = 0.0
	_spawn_sanctuary_lab_bells()


func _spawn_sanctuary_lab_bells() -> void:
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if not has_room_bell:
		var c: Vector2 = arena_rect.get_center()
		var dawn_p: Vector2 = Vector2(arena_rect.position.x + 22.0, c.y)
		var war_p: Vector2 = Vector2(arena_rect.end.x - 22.0, c.y)
		props.spawn_bell(dawn_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dawn", (pos - bp).normalized())
			stage.play_sfx("bell_toll", bp), "sexton_lab_bell_dawn")
		props.spawn_bell(war_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("war", (pos - bp).normalized())
			stage.play_sfx("bell_slam", bp), "sexton_lab_bell_war")


func _step_tunnel_commit(tgt: Vector2, dt: float) -> void:
	var to_t: Vector2 = tgt - pos
	if to_t.length() > 6.0:
		_tunnel_dir = _tunnel_dir.lerp(to_t.normalized(), minf(1.0, dt * 2.4)).normalized()
		facing = _tunnel_dir.angle()
	move_boss(_tunnel_dir * TUNNEL_SPEED * dt, false)
	_tunnel_pit_cd -= dt
	if _tunnel_pit_cd <= 0.0:
		_tunnel_pit_cd = 0.36
		ground.warn_ring(pos, 20.0, 0.50, 1.0, "coral", "apricot", 2.6)
		stage.play_sfx("earth_burrow", pos)


func _build_clod_targets(tgt: Vector2) -> Array[Vector2]:
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
	# Ringing ANY Sanctuary Bell while burrowed caves in his tunnel -> belly-up 2.4s stagger!
	if _burrowed:
		_trigger_cave_in()
		return
	if t == "war" and _coffin_shield_hp > 0.0:
		_coffin_shield_hp = 0.0
		add_stagger(5.5)
		stage.shake(0.22)
		stage.play_sfx("stone_break", pos)
	elif t == "dusk":
		_dusk_slow_t = 2.0
		add_stagger(2.2)
		stage.play_sfx("clockwork_chime", pos)


func _trigger_cave_in() -> void:
	_burrowed = false
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, CAVE_IN_STAGGER_TIME)
	staggered.emit(CAVE_IN_STAGGER_TIME)
	stage.shake(0.28)
	stage.play_sfx("sexton_cave_in", pos)
	LxDamageFx.boss_impact(pos, 0.22, 88.0, 92.0, 88.0, 1.44, 0.36)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_dusk_slow_t = maxf(0.0, _dusk_slow_t - dt)
	_pat_spade_t = maxf(0.0, _pat_spade_t - dt)
	if boss_state != BossState.COMMIT and _burrowed:
		_burrowed = false
	move_speed = 20.0 if _dusk_slow_t > 0.0 else (42.0 if phase >= 2 else 36.0)


func _on_phase_enter(new_phase: int) -> void:
	_burrowed = false
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# P2 cross-trench pit cuts splitting the crypt into 4 islands (leaves wide center & rim crossings!)
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(cx_t - 3, cy_t, 2, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 2, cy_t, 2, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t, cy_t - 3, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t, cy_t + 2, 1, 2), "pit")
		adds.queue_wave([
			{"kind": "grave_hand", "pos": c + Vector2(-62.0, -30.0)},
			{"kind": "grave_hand", "pos": c + Vector2(62.0, 30.0)},
		], 0.75, 2)
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("boss_bellkeeper_roar", pos)
	elif new_phase == 3:
		_coffin_shield_hp = COFFIN_SHIELD_MAX
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.26)
		stage.play_sfx("bell_slam_fire", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if _burrowed:
		clank_t = 0.10
		stage.play_sfx("earth_burrow", pos)
		return 0.0
	var h: Dictionary = _read_hit(hit)
	# P3 coffin-lid front shield reduces frontal bolts until cracked by War Bell or heavy/flank hits!
	if _coffin_shield_hp > 0.0 and not is_punishable():
		var orig: Vector2 = h["origin"] as Vector2
		var rel: Vector2 = orig - pos
		var from_front: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 1.05
		if from_front and not bool(h["pierce"]):
			if bool(h["cracks_armour"]) or bool(h["stagger"]):
				_coffin_shield_hp = maxf(0.0, _coffin_shield_hp - dmg * 1.4)
				if _coffin_shield_hp <= 0.0:
					stage.play_sfx("stone_break", pos)
				return dmg * 0.85
			_coffin_shield_hp = maxf(0.0, _coffin_shield_hp - dmg * 0.85)
			clank_t = 0.14
			stage.play_sfx("warden_clank", pos)
			if _coffin_shield_hp <= 0.0:
				stage.play_sfx("stone_break", pos)
			return dmg * 0.45
	return dmg


func _on_death_start() -> void:
	_burrowed = false
	_coffin_shield_hp = 0.0
	stage.play_sfx("bell_toll_heavy", pos)
	stage.shake(0.26)


func _body_color() -> Color:
	return (PAL["teal"] if phase == 1 else (PAL["wine"] if phase == 2 else PAL["coral"])) as Color


func _draw() -> void:
	if boss_state == BossState.DEATH:
		# Spade planted upright like a headstone in golden fireflies!
		draw_rect(Rect2(-2.0, -16.0, 4.0, 14.0), PAL["stone"] as Color)
		draw_rect(Rect2(-5.0, -4.0, 10.0, 4.0), PAL["gold"] as Color)
		for fi: int in range(5):
			var a: float = anim_t * 3.0 + float(fi) * (TAU / 5.0)
			draw_circle(Vector2(cos(a) * 12.0, -10.0 + sin(a) * 6.0), 1.4, PAL["gold"] as Color)
		return
	if _burrowed:
		# Rumbling moving dirt mound while underground!
		if ground != null: ground.draw_ground(self, pos)
		if props != null: props.draw_props(self, pos)
		if adds != null: adds.draw_summons(self, pos)
		if patterns != null: patterns.draw_patterns(self, pos)
		var jitter: float = 0.0 if is_flash_reduced() else sin(anim_t * 28.0) * 1.5
		draw_circle(Vector2(jitter, 2.0), 13.0, PAL["night"] as Color)
		draw_circle(Vector2(jitter, 0.0), 10.0, PAL["dusk"] as Color)
		draw_arc(Vector2(jitter, 1.0), 12.5, 0.0, TAU, 16, PAL["apricot"] as Color, 1.8)
		return
	super._draw()


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _coffin_shield_hp > 0.0 and boss_state != BossState.STAGGER:
		draw_arc(c, body_radius + 5.0, facing - 1.05, facing + 1.05, 14, PAL["stone"] as Color, 3.0)
		draw_arc(c, body_radius + 3.5, facing - 1.00, facing + 1.00, 12, PAL["gold"] as Color, 1.4)
	if _dusk_slow_t > 0.0:
		draw_arc(c, body_radius + 6.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.6)
	# Comedy beat: blinking confused "?" after patting fresh pit rim
	if _pat_spade_t > 0.0 and boss_state == BossState.RECOVER:
		draw_rect(Rect2(c + Vector2(-1.0, -body_radius - 14.0), Vector2(3.0, 3.0)), PAL["cream"] as Color)
