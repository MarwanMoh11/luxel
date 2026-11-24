class_name LxHeronAbbessBoss
extends LxHeronStalkerBrain
## Mirefen Gardens Boss (Island 4): the Heron Abbess (Bible §4.7 upgrade).
## 3 phases, HP 22.0. Combines long spear stabs (beak-stuck punish), wing gust push,
## expanding shockwave rings, P2 Shattered Skylights (4 corner thermal updraft columns),
## P3 Clock-Chime Double Ripple on Gale-Leap (2x air-stagger!), & 15% ground bolt resistance.

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

enum BossMove { STAB, WING_GUST, SHOCKWAVE_RING, GALE_LEAP }

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

const LEAP_TELL_P3: float = 0.54
const LEAP_AIR_TIME: float = 0.34
const LEAP_HEIGHT: float = 22.0
const LEAP_RING_TIME: float = 0.30
const LEAP_RING_MAX_R: float = 72.0
const LEAP_RECOVER: float = 1.25
const DOUBLE_RIPPLE_GAP: float = 0.35
const SKYLIGHT_UPDRAFT_R: float = 22.0
const ROAR_TIME: float = 0.66

var active_move: int = BossMove.STAB
var move_cycle: int = 0
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false
var ring_progress: float = 0.0
var ring_hit: bool = false
var leap_stage: int = 0
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var abbess_z: float = 0.0
var _roaring: bool = false
var _skylights: Array[Dictionary] = []  # [{pos, shattered, catch_cd}]
var _double_ripple_pending: bool = false
var _double_ripple_wait: float = 0.0


func _init() -> void:
	super._init()
	kind = "heron_abbess"
	boss_id = "heron_abbess"
	island_id = 4
	is_boss = true
	max_hp = 22.0
	hp = 22.0
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
	max_hp = maxf(22.0, max_hp)
	hp = max_hp
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
	leap_stage = 0
	leap_from = pos
	leap_to = pos
	abbess_z = 0.0
	_roaring = false
	_skylights.clear()
	_double_ripple_pending = false
	_double_ripple_wait = 0.0
	for off_v: Vector2 in [Vector2(-78.0, -42.0), Vector2(78.0, -42.0), Vector2(-78.0, 46.0), Vector2(78.0, 46.0)]:
		_skylights.append({"pos": _clamp_pt(home + off_v), "shattered": false, "catch_cd": 0.0})


func is_flying() -> bool:
	return active_move == BossMove.GALE_LEAP and state == State.COMMIT and leap_stage == 0 and abbess_z > 5.0


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	# P3 Gale-Leap 2x air-stagger punish!
	if is_flying() and (bool(h["stagger"]) or gliding):
		var air_dmg: float = float(h["damage"]) * 2.0
		hp = maxf(0.0, hp - air_dmg)
		abbess_z = 0.0
		leap_stage = 0
		_double_ripple_pending = false
		flash_t = 0.18
		LxDamageFx.boss_impact(pos, 0.16, 78.0, 82.0, 74.0, 1.38, 0.34, "ice")
		_emit_sfx("hopper_air_stagger")
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		_release_token()
		state = State.STAGGER
		state_timer = 1.10
		_emit_enemy_hit(hit, HitResult.OPENED)
		_check_phase_transition()
		return HitResult.OPENED
	# 15% ground bolt-spam resistance while perched/stalking (rewards Wings & beak-stuck punishes!)
	var use_hit: LxHit = hit
	var is_open: bool = beak_stuck or state == State.RECOVER or state == State.STAGGER
	if not is_open and not gliding and str(h["source"]) == LxHit.SOURCE_BOLT:
		use_hit = LxHit.make(hit.source, float(h["damage"]) * 0.85, hit.dir, hit.origin, hit.shield_wear, hit.stagger, hit.pierce, hit.attacker, hit.cracks_armour, hit.color)
	var res: int = super.take_hit(use_hit)
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
	leap_stage = 0
	abbess_z = 0.0
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.30)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("heron_abbess_phase")
	# P2 Shattered Skylights: crack 1st skylight visually on phase shift to teach thermal columns!
	if next_phase == 2 and not _skylights.is_empty():
		_skylights[0]["shattered"] = true
	elif next_phase == 3:
		for sk: Dictionary in _skylights:
			sk["shattered"] = true


func _step_brain(dt: float) -> void:
	if phase >= 2:
		_step_skylights(dt)
	if state == State.NOTICE and _roaring:
		abbess_z = 0.0
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	if state == State.TELL and active_move != BossMove.STAB:
		abbess_z = 0.0
		if active_move == BossMove.WING_GUST and state_timer > 0.18:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 2.8, dt)
				gust_dir = Vector2.from_angle(facing)
		elif active_move == BossMove.GALE_LEAP and state_timer > 0.18:
			var tpos: Vector2 = _attention_target()
			_face_point(tpos, 3.2, dt)
			leap_to = _clamp_pt(tpos)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	if state != State.COMMIT:
		abbess_z = 0.0
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
	var seq_len: int = 4 if phase >= 3 else (3 if phase >= 2 else 2)
	var pick: int = move_cycle % seq_len
	move_cycle += 1
	if pick == 0:
		active_move = BossMove.STAB
	elif pick == 1:
		active_move = BossMove.WING_GUST
	elif pick == 2:
		active_move = BossMove.SHOCKWAVE_RING
	else:
		active_move = BossMove.GALE_LEAP

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
	elif active_move == BossMove.SHOCKWAVE_RING:
		var base_r: float = RING_TELL_P3 if phase >= 3 else RING_TELL_P2
		last_tell_duration = _scaled_tell(base_r, false, attack_damage)
		ring_progress = 0.0
		ring_hit = false
		_emit_sfx("heron_ring_tell")
	else:
		last_tell_duration = _scaled_tell(LEAP_TELL_P3, false, attack_damage)
		leap_from = pos
		leap_to = _clamp_pt(target_pos)
		leap_stage = 0
		ring_progress = 0.0
		ring_hit = false
		_emit_sfx("heron_gust_inhale")

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
	if active_move == BossMove.GALE_LEAP:
		state = State.COMMIT
		leap_stage = 0
		state_timer = LEAP_AIR_TIME
		leap_from = pos
		ring_progress = 0.0
		ring_hit = false
		_boss_impact(0.14, 72.0, 74.0)
		_emit_sfx("heron_gust_fire")
		return
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == BossMove.WING_GUST:
		_step_gust_commit(dt)
		return
	if active_move == BossMove.SHOCKWAVE_RING:
		_step_ring_commit(dt)
		return
	if active_move == BossMove.GALE_LEAP:
		_step_leap_commit(dt)
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
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil") and not _in_active_skylight(wp):
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


func _step_leap_commit(dt: float) -> void:
	if leap_stage == 0:
		state_timer = maxf(0.0, state_timer - dt)
		var prog: float = 1.0 - clampf(state_timer / LEAP_AIR_TIME, 0.0, 1.0)
		abbess_z = sin(prog * PI) * LEAP_HEIGHT
		var desired: Vector2 = leap_from.lerp(leap_to, prog)
		_move_step(desired - pos, true)
		if state_timer <= 0.0:
			abbess_z = 0.0
			leap_stage = 1
			state_timer = LEAP_RING_TIME
			ring_progress = 0.0
			ring_hit = false
			_double_ripple_pending = phase >= 3
			_double_ripple_wait = 0.0
			_boss_impact(0.22, 108.0, 104.0)
			_emit_sfx("heron_ring_fire")
			if _has_player() and pos.distance_to(_get_wick_pos()) <= 16.0:
				ring_hit = true
				var pdir: Vector2 = (_get_wick_pos() - pos).normalized() if _get_wick_pos().distance_to(pos) > 0.01 else Vector2.from_angle(facing)
				_emit_shockwave_hit(pdir)
		return
	if _double_ripple_wait > 0.0:
		_double_ripple_wait -= dt
		if _double_ripple_wait <= 0.0:
			state_timer = LEAP_RING_TIME
			ring_progress = 0.0
			ring_hit = false
			_boss_impact(0.18, 96.0, 96.0)
			_emit_sfx("clockwork_chime")
			_emit_sfx("heron_ring_fire")
		return
	state_timer = maxf(0.0, state_timer - dt)
	ring_progress = 1.0 - clampf(state_timer / LEAP_RING_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, LEAP_RING_MAX_R, ring_progress)
	if _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= RING_BAND:
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
				Lx.player.call("apply_recoil", push * 180.0 * dt)
			if not ring_hit:
				ring_hit = true
				_emit_shockwave_hit(push)
	if state_timer <= 0.0:
		if _double_ripple_pending:
			_double_ripple_pending = false
			_double_ripple_wait = DOUBLE_RIPPLE_GAP
			return
		abbess_z = 0.0
		leap_stage = 0
		state = State.RECOVER
		beak_stuck = false
		state_timer = maxf(MIN_RECOVER_TIME, LEAP_RECOVER)
		last_recover_duration = state_timer


func _step_skylights(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	var bolts: Array = wick.move_bolt.get("bolts") as Array if (wick != null and wick.move_bolt != null and wick.move_bolt.get("bolts") is Array) else []
	for sk: Dictionary in _skylights:
		sk["catch_cd"] = maxf(0.0, float(sk["catch_cd"]) - dt)
		var sp: Vector2 = sk["pos"] as Vector2
		if not bool(sk["shattered"]):
			for b_v: Variant in bolts:
				if b_v is Dictionary and bool((b_v as Dictionary).get("active", true)):
					var bp: Vector2 = (b_v as Dictionary).get("pos", Vector2.INF) as Vector2
					if bp.is_finite() and bp.distance_to(sp) <= 14.0:
						sk["shattered"] = true
						(b_v as Dictionary)["active"] = false
						_emit_sfx("seal_break")
						break
		elif gliding and wick.move_wings != null and wick.global_position.distance_to(sp) <= SKYLIGHT_UPDRAFT_R + 6.0:
			wick.move_wings.refresh_glide(1.25, 2.2)
			if float(sk["catch_cd"]) <= 0.0:
				sk["catch_cd"] = 0.42
				_emit_sfx("updraft_catch")


func _in_active_skylight(pt: Vector2) -> bool:
	if phase < 2:
		return false
	for sk: Dictionary in _skylights:
		if bool(sk["shattered"]) and pt.distance_to(sk["pos"] as Vector2) <= SKYLIGHT_UPDRAFT_R + 4.0:
			return true
	return false


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


func _visual_offset() -> Vector2:
	return Vector2(0.0, -abbess_z)


func _body_color() -> Color:
	if phase >= 3:
		return PAL["ice"] as Color
	if phase >= 2:
		return PAL["sky"] as Color
	return PAL["stone"] as Color


func _draw_extra(off: Vector2) -> void:
	# Guard parent Stab laser/thrust tell so it NEVER draws during WING_GUST, SHOCKWAVE_RING, or GALE_LEAP!
	if active_move == BossMove.STAB or (state != State.TELL and state != State.COMMIT):
		super._draw_extra(off)
	LxHeronAbbessVisuals.draw_extra(self, off)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	var rip: String = "ice" if (active_move == BossMove.SHOCKWAVE_RING or active_move == BossMove.GALE_LEAP) else ""
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.42, 0.40, rip)
