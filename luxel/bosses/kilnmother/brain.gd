class_name LxKilnmotherBoss
extends LxCinderGolemBrain
## Ashen Kiln Boss (Island 6): the Kilnmother, a towering furnace with heavy slag armour (4.5).
## 3 phases, HP 13.5. Sunflare cracks her armour and stuns her for huge damage.
## Combines Bellows Gust (pushes Wick & thrown lantern straight back) and Molten Shockwave rings!

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

enum KilnMove { MOLTEN_RING, BELLOWS_GUST }
enum RingStage { RING_1, PAUSE, RING_2 }

const KILN_ARMOUR_MAX: float = 4.5
const KILN_RING_MAX_R: float = 80.0
const KILN_RING_BAND: float = 10.5
const KILN_TRIGGER_R: float = 128.0
const RING_PAUSE_P3: float = 0.46

const GUST_TELL_P1: float = 0.60
const GUST_TELL_P3: float = 0.54
const GUST_COMMIT_TIME: float = 0.36
const GUST_RANGE: float = 132.0
const GUST_HALF_W: float = 30.0
const GUST_DMG_R: float = 60.0
const GUST_PUSH_WICK: float = 275.0
const GUST_PUSH_LANTERN: float = 175.0
const GUST_RECOVER: float = 1.25
const ROAR_TIME: float = 0.70

var active_move: int = KilnMove.MOLTEN_RING
var ring_stage: int = RingStage.RING_1
var move_cycle: int = 0
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "kilnmother"
	boss_id = "kilnmother"
	island_id = 6
	is_boss = true
	max_hp = 13.5
	hp = 13.5
	armour_max = KILN_ARMOUR_MAX
	armour_hp = KILN_ARMOUR_MAX
	body_radius = 9.5
	routine_speed = 26.0
	leash_radius = 160.0
	notice_radius = 140.0
	tell_time = 0.66
	recover_time = 1.45
	give_up_time = 1.1
	attack_damage = 1.5
	reach = KILN_TRIGGER_R
	lunge_reach = KILN_TRIGGER_R
	shard_drop = 36


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "kilnmother"))
	island_id = int(spec.get("island_id", 6))
	armour_max = maxf(1.0, float(spec.get("armour_hp", KILN_ARMOUR_MAX)))
	armour_hp = armour_max
	armour_intact = true
	active_move = KilnMove.MOLTEN_RING
	ring_stage = RingStage.RING_1
	move_cycle = 0
	gust_dir = Vector2.from_angle(facing)
	gust_hit = false
	gust_announced = false
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit) if hit != null else {}
	var sunflare_crack: bool = hit != null and bool(h.get("cracks_armour", false)) and armour_intact
	var res: int = super.take_hit(hit)
	if is_alive() and sunflare_crack:
		hp = maxf(0.0, hp - float(h.get("damage", 0.0)) * 0.25)
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001:
		_enter_phase(2)
	elif phase < 3 and hp <= max_hp * 0.33 and hp > 0.001:
		_enter_phase(3)


func _enter_phase(next_phase: int) -> void:
	phase = next_phase
	_roaring = true
	active_move = KilnMove.MOLTEN_RING
	ring_stage = RingStage.RING_1
	stomp_progress = 0.0
	if phase == 2 and not armour_intact:
		armour_intact = true
		armour_hp = 2.0
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.35)
	_emit_sfx("kilnmother_phase")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if dist > KILN_TRIGGER_R:
		return false
	var want_gust: bool = (_is_lantern_out() and dist <= GUST_RANGE) or (move_cycle % 2 == 1)
	if not want_gust and dist > KILN_RING_MAX_R + 14.0:
		want_gust = true
	if not _claim_token():
		return false

	move_cycle += 1
	state = State.TELL
	lunge_attack = false
	is_counter_attack = false
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()

	if want_gust:
		active_move = KilnMove.BELLOWS_GUST
		gust_dir = to_t.normalized() if to_t.length() > 0.01 else Vector2.from_angle(facing)
		gust_hit = false
		gust_announced = false
		var base_g: float = GUST_TELL_P3 if phase >= 3 else GUST_TELL_P1
		last_tell_duration = _scaled_tell(base_g, false, attack_damage)
		_emit_sfx("kilnmother_bellows_inhale")
	else:
		active_move = KilnMove.MOLTEN_RING
		ring_stage = RingStage.RING_1
		stomp_progress = 0.0
		stomp_hit = false
		var base_r: float = 0.58 if phase >= 3 else tell_time
		last_tell_duration = _scaled_tell(base_r, false, attack_damage)
		_emit_sfx("golem_stomp_tell")

	state_timer = last_tell_duration
	_emit_attack_started()
	return true


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if active_move == KilnMove.BELLOWS_GUST and state_timer > 0.22:
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 2.4, dt)
			gust_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		_enter_commit()


func _enter_commit() -> void:
	if active_move == KilnMove.BELLOWS_GUST:
		state = State.COMMIT
		state_timer = GUST_COMMIT_TIME
		gust_hit = false
		gust_announced = false
		_emit_sfx("kilnmother_bellows_gust")
		return
	ring_stage = RingStage.RING_1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == KilnMove.BELLOWS_GUST:
		_step_bellows_commit(dt)
		return
	if ring_stage == RingStage.PAUSE:
		state_timer -= dt
		if state_timer <= 0.0:
			ring_stage = RingStage.RING_2
			state_timer = STOMP_COMMIT_TIME
			stomp_progress = 0.0
			stomp_hit = false
			_emit_sfx("golem_stomp_shockwave")
		return

	state_timer = maxf(0.0, state_timer - dt)
	stomp_progress = 1.0 - clampf(state_timer / STOMP_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(STOMP_START_R, KILN_RING_MAX_R, stomp_progress)
	if not stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= KILN_RING_BAND:
			stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if ring_stage == RingStage.RING_1 and phase >= 3:
			ring_stage = RingStage.PAUSE
			state_timer = _scaled_tell(RING_PAUSE_P3, false, attack_damage)
			stomp_progress = 0.0
			stomp_hit = false
			_emit_sfx("golem_stomp_tell")
		else:
			ring_stage = RingStage.RING_1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _step_bellows_commit(dt: float) -> void:
	if not gust_announced:
		gust_announced = true
		gust_emitted.emit(pos, gust_dir, GUST_RANGE, GUST_HALF_W, self)
		if world_ctx != null and world_ctx.has_method("on_enemy_gust"):
			world_ctx.call("on_enemy_gust", self, pos, gust_dir, GUST_RANGE, GUST_HALF_W)
	var end_p: Vector2 = pos + gust_dir * GUST_RANGE
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= GUST_HALF_W:
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
				Lx.player.call("apply_recoil", gust_dir * GUST_PUSH_WICK * dt)
			if not gust_hit and pos.distance_to(wp) <= GUST_DMG_R:
				gust_hit = true
				_emit_player_hit(gust_dir, 1.0)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= GUST_HALF_W + 6.0:
			_push_thrown_lantern(dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, GUST_RECOVER)
		last_recover_duration = state_timer


func _push_thrown_lantern(dt: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if lan_v is Object and is_instance_valid(lan_v as Object):
		var lan: Object = lan_v as Object
		var st_v: Variant = lan.get("state")
		if st_v != null and (int(st_v) == 1 or int(st_v) == 2):
			var cur_v: Variant = lan.get("pos")
			if cur_v is Vector2:
				var pushed: Vector2 = (cur_v as Vector2) + gust_dir * GUST_PUSH_LANTERN * dt
				lan.set("pos", pushed)
				if lan is Node2D:
					(lan as Node2D).global_position = pushed.round()


func _body_color() -> Color:
	if armour_intact:
		return (PAL["dusk"] as Color) if phase >= 3 else (PAL["stone"] as Color)
	return (PAL["gold"] as Color) if phase >= 3 else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	# Kiln chimney crown + glowing furnace belly
	draw_rect(Rect2(off + Vector2(-4.0, -body_radius - 5.0), Vector2(8.0, 5.0)), PAL["night"] as Color, true)
	draw_rect(Rect2(off + Vector2(-2.5, -body_radius - 4.0), Vector2(5.0, 3.0)), PAL["apricot"] as Color, true)
	draw_circle(off + Vector2(0.0, 1.0), 4.2, PAL["night"] as Color)
	draw_circle(off + Vector2(0.0, 1.0), 2.8, (PAL["cream"] as Color) if not armour_intact else (PAL["coral"] as Color))
	if armour_intact:
		var plate_col: Color = (PAL["cream"] as Color) if clank_t > 0.0 else (PAL["mauve"] as Color)
		draw_rect(Rect2(off - Vector2(body_radius + 2.0, body_radius + 2.0), Vector2((body_radius + 2.0) * 2.0, (body_radius + 2.0) * 2.0)), plate_col, false, 2.5)
	if active_move == KilnMove.BELLOWS_GUST and state == State.TELL:
		var side: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		draw_line(off - side * 14.0, off - side * 14.0 + gust_dir * 52.0, PAL["gold"] as Color, 1.5)
		draw_line(off + side * 14.0, off + side * 14.0 + gust_dir * 52.0, PAL["gold"] as Color, 1.5)
	elif active_move == KilnMove.BELLOWS_GUST and state == State.COMMIT:
		var side2: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		for idx: int in [-1, 0, 1]:
			var s_off: Vector2 = side2 * float(idx) * (GUST_HALF_W * 0.45)
			draw_line(off + s_off, off + s_off + gust_dir * GUST_RANGE * 0.80, (PAL["cream"] as Color) if idx == 0 else (PAL["apricot"] as Color), 2.2)
	elif active_move == KilnMove.MOLTEN_RING and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		draw_arc(off, lerpf(KILN_RING_MAX_R, STOMP_START_R + 6.0, prog), 0.0, TAU, 28, PAL["apricot"] as Color, 1.8)
	elif active_move == KilnMove.MOLTEN_RING and state == State.COMMIT:
		if ring_stage == RingStage.PAUSE:
			draw_arc(off, KILN_RING_MAX_R * 0.5, 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
		else:
			var ring_r: float = lerpf(STOMP_START_R, KILN_RING_MAX_R, stomp_progress)
			draw_arc(off, ring_r, 0.0, TAU, 32, PAL["coral"] as Color, 3.5)
			draw_arc(off, maxf(2.0, ring_r - 2.5), 0.0, TAU, 24, PAL["gold"] as Color, 1.5)
	elif _roaring:
		draw_arc(off, body_radius + 14.0, 0.0, TAU, 24, PAL["gold"] as Color, 2.5)
