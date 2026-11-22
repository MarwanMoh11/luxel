class_name LxHeronAbbessBoss
extends LxHeronStalkerBrain
## Mirefen Gardens Boss (Island 4): the Heron Abbess.
## 3 phases, HP 12.5. Combines long spear stabs (beak-stuck punish), wing gust push
## (pushes Wick & thrown lantern), and expanding shockwave rings cleared by Wings glide!

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

enum BossMove { STAB, WING_GUST, SHOCKWAVE_RING }

const GUST_TELL_P1: float = 0.56
const GUST_TELL_P3: float = 0.50
const GUST_COMMIT_TIME: float = 0.34
const GUST_RANGE: float = 128.0
const GUST_HALF_W: float = 28.0
const GUST_DMG_R: float = 58.0
const GUST_PUSH_WICK: float = 260.0
const GUST_PUSH_LANTERN: float = 150.0
const GUST_RECOVER: float = 1.15

const RING_TELL_P2: float = 0.58
const RING_TELL_P3: float = 0.50
const RING_COMMIT_TIME: float = 0.32
const RING_START_R: float = 10.0
const RING_MAX_R: float = 76.0
const RING_BAND: float = 9.5
const RING_RECOVER: float = 1.20
const ROAR_TIME: float = 0.66

var active_move: int = BossMove.STAB
var move_cycle: int = 0
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false
var ring_progress: float = 0.0
var ring_hit: bool = false
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "heron_abbess"
	boss_id = "heron_abbess"
	island_id = 4
	is_boss = true
	max_hp = 12.5
	hp = 12.5
	body_radius = 7.5
	routine_speed = 42.0
	leash_radius = 185.0
	notice_radius = 152.0
	tell_time = 0.56
	recover_time = 1.30
	give_up_time = 1.8
	shard_drop = 32


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "heron_abbess"))
	island_id = int(spec.get("island_id", 4))
	active_move = BossMove.STAB
	move_cycle = 0
	gust_dir = Vector2.from_angle(facing)
	gust_hit = false
	gust_announced = false
	ring_progress = 0.0
	ring_hit = false
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var res: int = super.take_hit(hit)
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
	beak_stuck = false
	active_move = BossMove.STAB
	ring_progress = 0.0
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.30)
	_emit_sfx("heron_abbess_phase")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	if state == State.TELL and active_move != BossMove.STAB:
		if active_move == BossMove.WING_GUST and state_timer > 0.18:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 2.8, dt)
				gust_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	super._step_brain(dt)


func _step_stalk(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.2, dt)

	var wick_p: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_p.distance_to(home) > leash_radius + 16.0):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN

	if is_lead and cooldown <= 0.0 and dist <= GUST_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		_begin_next_move(target_pos, dist)
		return

	var spd: float = minf(routine_speed * 0.84, routine_speed - 2.0)
	if dist > STAB_RANGE * 0.80:
		_move_step(to_t.normalized() * spd * dt, false)
	elif dist < 34.0 and dist > 0.01:
		_move_step(-to_t.normalized() * spd * 0.7 * dt, false)


func _begin_next_move(target_pos: Vector2, dist: float) -> void:
	var seq_len: int = 3 if phase >= 2 else 2
	var pick: int = move_cycle % seq_len
	move_cycle += 1
	if pick == 0:
		active_move = BossMove.STAB
	elif pick == 1:
		active_move = BossMove.WING_GUST
	else:
		active_move = BossMove.SHOCKWAVE_RING

	state = State.TELL
	is_counter_attack = false
	var to_t: Vector2 = target_pos - pos
	var aim_dir: Vector2 = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
	facing = aim_dir.angle()

	if active_move == BossMove.STAB:
		var base_s: float = 0.50 if phase >= 3 else tell_time
		last_tell_duration = _scaled_tell(base_s, false, attack_damage)
		stab_dir = aim_dir
		stab_len = clampf(dist + 26.0, STAB_MIN_LEN, STAB_MAX_LEN + 16.0)
		_emit_sfx("heron_stare")
	elif active_move == BossMove.WING_GUST:
		var base_g: float = GUST_TELL_P3 if phase >= 3 else GUST_TELL_P1
		last_tell_duration = _scaled_tell(base_g, false, attack_damage)
		gust_dir = aim_dir
		gust_hit = false
		gust_announced = false
		_emit_sfx("heron_gust_inhale")
	else:
		var base_r: float = RING_TELL_P3 if phase >= 3 else RING_TELL_P2
		last_tell_duration = _scaled_tell(base_r, false, attack_damage)
		ring_progress = 0.0
		ring_hit = false
		_emit_sfx("heron_ring_tell")

	state_timer = last_tell_duration
	_emit_attack_started()


func _enter_commit() -> void:
	if active_move == BossMove.WING_GUST:
		state = State.COMMIT
		state_timer = GUST_COMMIT_TIME
		gust_hit = false
		gust_announced = false
		_boss_impact(0.15, 110.0, 105.0)
		_emit_sfx("heron_gust_fire")
		return
	if active_move == BossMove.SHOCKWAVE_RING:
		state = State.COMMIT
		state_timer = RING_COMMIT_TIME
		ring_progress = 0.0
		ring_hit = false
		_boss_impact(0.20, 94.0, 92.0)
		_emit_sfx("heron_ring_fire")
		return
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == BossMove.WING_GUST:
		_step_gust_commit(dt)
		return
	if active_move == BossMove.SHOCKWAVE_RING:
		_step_ring_commit(dt)
		return
	super._step_commit(dt)


func _step_gust_commit(dt: float) -> void:
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
				_emit_player_hit(gust_dir)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= GUST_HALF_W + 4.0:
			_push_thrown_lantern(dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		beak_stuck = false
		state_timer = maxf(MIN_RECOVER_TIME, GUST_RECOVER)
		last_recover_duration = state_timer


func _step_ring_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / RING_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
	if not ring_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= RING_BAND:
			ring_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		state = State.RECOVER
		beak_stuck = false
		state_timer = maxf(MIN_RECOVER_TIME, RING_RECOVER)
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


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir)
	kind = prev_kind


func _body_color() -> Color:
	if phase >= 3:
		return PAL["ice"] as Color
	if phase >= 2:
		return PAL["sky"] as Color
	return PAL["stone"] as Color


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if _sprite_sheet == null:
		# Mitered abbess crest
		var top: Vector2 = off + Vector2(0.0, -body_radius - 6.0)
		draw_line(top + Vector2(-4.0, 2.0), top + Vector2(0.0, -4.0), PAL["gold"] as Color, 1.8)
		draw_line(top + Vector2(4.0, 2.0), top + Vector2(0.0, -4.0), PAL["gold"] as Color, 1.8)

	if active_move == BossMove.WING_GUST and state == State.TELL:
		var side: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var g_prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var g_locked: bool = state_timer <= 0.18
		var rail_col: Color = (PAL["gold"] if g_locked else PAL["sky"]) as Color
		draw_line((off - side * GUST_HALF_W * 0.72).round(), (off - side * GUST_HALF_W * 0.72 + gust_dir * GUST_RANGE).round(), rail_col, 1.4)
		draw_line((off + side * GUST_HALF_W * 0.72).round(), (off + side * GUST_HALF_W * 0.72 + gust_dir * GUST_RANGE).round(), rail_col, 1.4)
		var dmg_pt: Vector2 = off + gust_dir * GUST_DMG_R
		draw_line((dmg_pt - side * GUST_HALF_W * 0.72).round(), (dmg_pt + side * GUST_HALF_W * 0.72).round(), (PAL["cream"] if g_locked else PAL["gold"]) as Color, 1.4)
		var pull_d: float = lerpf(44.0, 10.0, g_prog)
		draw_line((off + gust_dir * pull_d - side * 12.0).round(), (off + gust_dir * (pull_d - 6.0)).round(), PAL["ice"] as Color, 1.2)
		draw_line((off + gust_dir * pull_d + side * 12.0).round(), (off + gust_dir * (pull_d - 6.0)).round(), PAL["ice"] as Color, 1.2)
	elif active_move == BossMove.WING_GUST and state == State.COMMIT:
		var side2: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var g_len: float = GUST_RANGE * 0.88
		for idx: int in range(-1, 2):
			var s_off: Vector2 = side2 * float(idx) * (GUST_HALF_W * 0.50)
			var l_end: float = g_len if idx == 0 else g_len * 0.86
			var p0: Vector2 = (off + s_off).round()
			var p1: Vector2 = (off + s_off + gust_dir * l_end).round()
			draw_line(p0, p1, PAL["sky"] as Color, 3.2 if idx == 0 else 2.2)
			draw_line(p0, p1, (PAL["cream"] if idx == 0 else PAL["ice"]) as Color, 1.5 if idx == 0 else 1.2)
		for ci: int in range(4):
			var ct: float = fposmod(anim_t * 4.6 + float(ci) * 0.25, 1.0)
			var dist_c: float = lerpf(12.0, g_len, ct)
			var span: float = lerpf(GUST_HALF_W * 0.42, GUST_HALF_W * 0.90, ct)
			var tip: Vector2 = (off + gust_dir * dist_c).round()
			var wing_l: Vector2 = (off + gust_dir * (dist_c - 10.0) - side2 * span).round()
			var wing_r: Vector2 = (off + gust_dir * (dist_c - 10.0) + side2 * span).round()
			draw_line(wing_l, tip, PAL["sky"] as Color, 2.2)
			draw_line(wing_r, tip, PAL["sky"] as Color, 2.2)
			draw_line((tip - gust_dir * 6.0 - side2 * (span * 0.62)).round(), tip, PAL["ice"] as Color, 1.4)
			draw_line((tip - gust_dir * 6.0 + side2 * (span * 0.62)).round(), tip, PAL["ice"] as Color, 1.4)
			draw_line((tip - gust_dir * 3.5 - side2 * (span * 0.30)).round(), tip, PAL["cream"] as Color, 1.0)
			draw_line((tip - gust_dir * 3.5 + side2 * (span * 0.30)).round(), tip, PAL["cream"] as Color, 1.0)
	elif active_move == BossMove.SHOCKWAVE_RING and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(off, RING_MAX_R, a0, a0 + 0.24, 3, PAL["blue"] as Color, 1.0)
		draw_arc(off, lerpf(RING_MAX_R, RING_START_R + 6.0, prog), 0.0, TAU, 28, (PAL["cream"] if state_timer <= 0.14 else PAL["sky"]) as Color, 1.8)
	elif active_move == BossMove.SHOCKWAVE_RING and state == State.COMMIT:
		var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
		draw_arc(off, ring_r + 3.0, 0.0, TAU, 36, PAL["blue"] as Color, 2.2)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
		draw_arc(off, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
		draw_arc(off, maxf(2.0, ring_r - 4.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.1)
		if ring_r > 16.0:
			draw_arc(off, ring_r - 8.5, 0.0, TAU, 24, PAL["blue"] as Color, 1.1)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["sky"] as Color, 1.8)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.2)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	var rip: String = "ice" if active_move == BossMove.SHOCKWAVE_RING else ""
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.42, 0.40, rip)
