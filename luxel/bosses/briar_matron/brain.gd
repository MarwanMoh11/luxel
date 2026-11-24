class_name LxBriarMatronBoss
extends LxBrambleKnightBrain
## Thornwood Hollow Boss (Island 3): the Briar Matron, a great beetle-spider.
## 3 phases, HP 12.5, web/thorn barrier 3.5.
## Beam burns/pierces her web barrier AND clears P2 3-Lane Silk Web Snares for stagger!
## P3 adds Scuttle Ambush (fast flank skitter + cross-web slash, tell >= 0.50s).

enum MatronMove { MELEE, SPORE_RING, WEB_SNARE, SCUTTLE_AMBUSH }

const SPORE_TELL_P1: float = 0.60
const SPORE_TELL_P3: float = 0.52
const SPORE_COMMIT_TIME: float = 0.32
const SPORE_START_R: float = 10.0
const SPORE_MAX_R: float = 74.0
const SPORE_BAND: float = 9.5
const SPORE_RECOVER_P1: float = 1.25
const SPORE_RECOVER_P3: float = 1.05
const SPORE_CD_P1: float = 4.4
const SPORE_CD_P2: float = 3.6
const SPORE_CD_P3: float = 3.0

const SNARE_TELL: float = 0.54
const SNARE_COMMIT_TIME: float = 0.28
const SNARE_LANE_LEN: float = 92.0
const SNARE_HALF_W: float = 12.0
const SNARE_TTL: float = 5.5
const SNARE_CD: float = 5.4
const SNARE_SPREAD: float = 0.42

const AMBUSH_TELL: float = 0.52
const AMBUSH_COMMIT_TIME: float = 0.26
const AMBUSH_FLANK_DIST: float = 24.0
const AMBUSH_LUNGE_SPEED: float = 220.0
const AMBUSH_SLASH_R: float = 40.0
const AMBUSH_SLASH_ARC: float = 1.45
const AMBUSH_CD: float = 3.6
const ROAR_TIME: float = 0.68

var active_move: int = MatronMove.MELEE
var spore_cd: float = 1.8
var snare_cd: float = 2.0
var ambush_cd: float = 2.2
var spore_progress: float = 0.0
var spore_hit: bool = false
var swings_since_special: int = 0
var snare_dir: Vector2 = Vector2.RIGHT
var snare_spawned: bool = false
var web_lanes: Array[Dictionary] = []
var _snare_tick_cd: float = 0.0
var ambush_flank_done: bool = false
var ambush_side: float = 1.0
var ambush_dir: Vector2 = Vector2.RIGHT
var ambush_hit: bool = false
var ambush_ghost_pos: Vector2 = Vector2.ZERO
var ambush_ghost_t: float = 0.0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "briar_matron"
	boss_id = "briar_matron"
	island_id = 3
	is_boss = true
	max_hp = 12.5
	hp = 12.5
	shield_max = 3.5
	shield_hp = 3.5
	shield_gone_duration = 5.2
	body_radius = 8.5
	routine_speed = 34.0
	leash_radius = 185.0
	notice_radius = 152.0
	reach = 42.0
	lunge_reach = 104.0
	swing_r = 34.0
	swing_arc = 1.30
	tell_time = 0.50
	lunge_tell_time = 0.56
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 30


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "briar_matron"))
	island_id = int(spec.get("island_id", 3))
	active_move = MatronMove.MELEE
	spore_cd = 1.8
	snare_cd = 2.0
	ambush_cd = 2.2
	spore_progress = 0.0
	spore_hit = false
	swings_since_special = 0
	snare_dir = Vector2.from_angle(facing)
	snare_spawned = false
	web_lanes.clear()
	_snare_tick_cd = 0.0
	ambush_flank_done = false
	ambush_side = 1.0
	ambush_dir = Vector2.from_angle(facing)
	ambush_hit = false
	ambush_ghost_pos = pos
	ambush_ghost_t = 0.0
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit) if hit != null else {}
	var is_beam_burn: bool = hit != null and (str(h.get("source", "")) == LxHit.SOURCE_BEAM or bool(h.get("pierce", false)))
	var had_shield: bool = _has_active_shield()
	var had_webs: bool = not web_lanes.is_empty()
	var res: int = super.take_hit(hit)
	if is_alive() and is_beam_burn:
		var burn_bonus: bool = false
		if had_shield and res == HitResult.OPENED:
			hp = maxf(0.0, hp - float(h.get("damage", 0.0)) * 0.25)
			burn_bonus = true
		if had_webs:
			_spawn_web_burn_fx()
			web_lanes.clear()
			hp = maxf(0.0, hp - 0.5)
			burn_bonus = true
			if state != State.STAGGER:
				_release_token()
				active_move = MatronMove.MELEE
				state = State.STAGGER
				state_timer = 0.85
		if burn_bonus:
			_emit_sfx("briar_web_burn")
			if hp <= 0.001:
				opened_kill = true
				_die(hit)
				return HitResult.KILLED
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	return _check_phase_transition()


func _check_phase_transition() -> bool:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001:
		_enter_phase(2)
		return true
	if phase < 3 and hp <= max_hp * 0.33 and hp > 0.001:
		_enter_phase(3)
		return true
	return false


func _enter_phase(next_phase: int) -> void:
	phase = next_phase
	wary = false
	_roaring = true
	active_move = MatronMove.MELEE
	thorn_burst_active = false
	lunge_attack = false
	is_counter_attack = false
	spore_progress = 0.0
	if phase == 3 and shield_gone_t > 0.0:
		shield_gone_t = 0.0
		shield_hp = shield_max * 0.65
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	spore_cd = 1.2
	snare_cd = 0.60
	ambush_cd = 0.80
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.32)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("briar_matron_phase")


func _step_brain(dt: float) -> void:
	spore_cd = maxf(0.0, spore_cd - dt)
	snare_cd = maxf(0.0, snare_cd - dt)
	ambush_cd = maxf(0.0, ambush_cd - dt)
	ambush_ghost_t = maxf(0.0, ambush_ghost_t - dt)
	_snare_tick_cd = maxf(0.0, _snare_tick_cd - dt)
	_step_web_lanes(dt)
	super._step_brain(dt)


func _step_web_lanes(dt: float) -> void:
	var i: int = web_lanes.size() - 1
	var wick_snared: bool = false
	var wp: Vector2 = _get_wick_pos()
	while i >= 0:
		var lane: Dictionary = web_lanes[i]
		var ttl: float = float(lane["ttl"]) - dt
		if ttl <= 0.0:
			web_lanes.remove_at(i)
		else:
			lane["ttl"] = ttl
			if _has_player() and not wick_snared:
				var lo: Vector2 = lane["origin"] as Vector2
				var ld: Vector2 = lane["dir"] as Vector2
				var llen: float = float(lane["length"])
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(wp, lo, lo + ld * llen)
				if closest.distance_to(wp) <= SNARE_HALF_W:
					wick_snared = true
					if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
						var pull_v: Vector2 = (closest - wp).normalized() if closest.distance_to(wp) > 0.5 else -ld
						Lx.player.call("apply_recoil", pull_v * 68.0 * dt)
					if _snare_tick_cd <= 0.0:
						_snare_tick_cd = 1.15
						_emit_player_hit(ld, 0.5)
		i -= 1


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.4, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false
		state = State.POSITION
		step_clock = 0.0
		cooldown = 0.35


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	var to_t: Vector2 = target_pos - pos
	if phase >= 3 and ambush_cd <= 0.0 and dist < 112.0 and _claim_token():
		active_move = MatronMove.SCUTTLE_AMBUSH
		thorn_burst_active = false
		lunge_attack = false
		is_counter_attack = false
		ambush_flank_done = false
		ambush_side = -ambush_side
		ambush_hit = false
		state = State.TELL
		last_tell_duration = _scaled_tell(AMBUSH_TELL, false, attack_damage)
		state_timer = last_tell_duration
		if to_t.length() > 0.01:
			facing = to_t.angle()
		ambush_dir = Vector2.from_angle(facing)
		swings_since_special = 0
		_emit_attack_started()
		_emit_sfx("briar_ambush_tell")
		return true
	if phase >= 2 and snare_cd <= 0.0 and web_lanes.is_empty() and dist < SNARE_LANE_LEN + 24.0 and _claim_token():
		active_move = MatronMove.WEB_SNARE
		thorn_burst_active = false
		lunge_attack = false
		is_counter_attack = false
		snare_spawned = false
		state = State.TELL
		last_tell_duration = _scaled_tell(SNARE_TELL, false, attack_damage)
		state_timer = last_tell_duration
		if to_t.length() > 0.01:
			facing = to_t.angle()
		snare_dir = Vector2.from_angle(facing)
		swings_since_special = 0
		_emit_attack_started()
		_emit_sfx("briar_spore_tell")
		return true
	if spore_cd <= 0.0 and (phase >= 2 or swings_since_special >= 1) and dist < SPORE_MAX_R + 20.0 \
			and _claim_token():
		active_move = MatronMove.SPORE_RING
		thorn_burst_active = false
		lunge_attack = false
		is_counter_attack = false
		state = State.TELL
		var base_t: float = SPORE_TELL_P3 if phase >= 3 else SPORE_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		spore_progress = 0.0
		spore_hit = false
		swings_since_special = 0
		_emit_attack_started()
		_emit_sfx("briar_spore_tell")
		return true
	active_move = MatronMove.MELEE
	return super._try_start_attack(target_pos, dist)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if active_move == MatronMove.WEB_SNARE:
		if state_timer > 0.20:
			var to_t: Vector2 = target_pos - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 2.8, dt)
				snare_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	if active_move == MatronMove.SCUTTLE_AMBUSH:
		if not ambush_flank_done and state_timer <= last_tell_duration * 0.56:
			ambush_flank_done = true
			ambush_ghost_pos = pos
			ambush_ghost_t = 0.30
			var to_f: Vector2 = target_pos - pos
			var perp: Vector2 = (to_f.normalized() if to_f.length() > 0.01 else Vector2.from_angle(facing)).rotated(PI * 0.5 * ambush_side)
			_move_step(perp * AMBUSH_FLANK_DIST, false)
			var re_aim: Vector2 = target_pos - pos
			if re_aim.length() > 0.01:
				facing = re_aim.angle()
			ambush_dir = Vector2.from_angle(facing)
			_emit_sfx("briar_scuttle")
		elif not ambush_flank_done:
			var to_a: Vector2 = target_pos - pos
			if to_a.length() > 0.01:
				_turn_toward(to_a.angle(), 3.4, dt)
				ambush_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_commit()
		return
	super._step_tell(dt, target_pos)


func _enter_commit() -> void:
	if active_move == MatronMove.SPORE_RING:
		state = State.COMMIT
		state_timer = SPORE_COMMIT_TIME
		spore_progress = 0.0
		spore_hit = false
		_boss_impact(0.20, 94.0, 92.0)
		_emit_sfx("briar_spore_burst")
		return
	if active_move == MatronMove.WEB_SNARE:
		state = State.COMMIT
		state_timer = SNARE_COMMIT_TIME
		snare_spawned = false
		_boss_impact(0.14, 72.0, 74.0)
		_emit_sfx("briar_web_cast")
		return
	if active_move == MatronMove.SCUTTLE_AMBUSH:
		state = State.COMMIT
		state_timer = AMBUSH_COMMIT_TIME
		ambush_hit = false
		ambush_dir = Vector2.from_angle(facing)
		_boss_impact(0.16, 78.0, 82.0)
		_emit_sfx("warden_swing")
		return
	if not thorn_burst_active:
		swings_since_special += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == MatronMove.WEB_SNARE:
		if not snare_spawned:
			snare_spawned = true
			web_lanes.clear()
			for idx: int in [-1, 0, 1]:
				var ldir: Vector2 = snare_dir.rotated(float(idx) * SNARE_SPREAD)
				web_lanes.append({
					"origin": pos + ldir * (body_radius + 2.0),
					"dir": ldir,
					"length": SNARE_LANE_LEN,
					"ttl": SNARE_TTL,
				})
		state_timer -= dt
		if state_timer <= 0.0:
			active_move = MatronMove.MELEE
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, 1.15)
			last_recover_duration = state_timer
			snare_cd = SNARE_CD
		return
	if active_move == MatronMove.SCUTTLE_AMBUSH:
		_move_step(ambush_dir * AMBUSH_LUNGE_SPEED * dt, false)
		if not ambush_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= AMBUSH_SLASH_R and (wv.length() < 0.01 or absf(angle_difference(ambush_dir.angle(), wv.angle())) <= AMBUSH_SLASH_ARC):
				ambush_hit = true
				_emit_player_hit(ambush_dir)
		state_timer -= dt
		if state_timer <= 0.0:
			active_move = MatronMove.MELEE
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, 1.15)
			last_recover_duration = state_timer
			ambush_cd = AMBUSH_CD
		return
	if active_move != MatronMove.SPORE_RING:
		super._step_commit(dt)
		return
	state_timer = maxf(0.0, state_timer - dt)
	spore_progress = 1.0 - clampf(state_timer / SPORE_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(SPORE_START_R, SPORE_MAX_R, spore_progress)
	if not spore_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= SPORE_BAND:
			spore_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		active_move = MatronMove.MELEE
		spore_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SPORE_RECOVER_P3 if phase >= 3 else SPORE_RECOVER_P1)
		last_recover_duration = state_timer
		spore_cd = SPORE_CD_P3 if phase >= 3 else (SPORE_CD_P2 if phase >= 2 else SPORE_CD_P1)


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir)
	kind = prev_kind


func _post_recover_cooldown() -> float:
	if phase >= 3:
		return 0.62
	if phase >= 2:
		return 0.78
	return 0.92


func _body_color() -> Color:
	if phase >= 3:
		return PAL["wine"] as Color
	if phase >= 2:
		return PAL["dusk"] as Color
	return PAL["pine"] as Color


func _shield_color() -> Color:
	return PAL["cream"] as Color


func _draw_extra(off: Vector2) -> void:
	# Active 3-Lane Silk Web Snares (drawn in world-relative local coords)
	for lane: Dictionary in web_lanes:
		var lo: Vector2 = ((lane["origin"] as Vector2) - pos + off).round()
		var ld: Vector2 = lane["dir"] as Vector2
		var llen: float = float(lane["length"])
		var lp: Vector2 = Vector2(-ld.y, ld.x)
		var le: Vector2 = (lo + ld * llen).round()
		draw_line(lo, le, PAL["stone"] as Color, 2.2)
		draw_line((lo + lp * (SNARE_HALF_W * 0.6)).round(), (le + lp * (SNARE_HALF_W * 0.6)).round(), PAL["ice"] as Color, 1.0)
		draw_line((lo - lp * (SNARE_HALF_W * 0.6)).round(), (le - lp * (SNARE_HALF_W * 0.6)).round(), PAL["ice"] as Color, 1.0)
		for wi: int in range(1, 6):
			var mid: Vector2 = lo.lerp(le, float(wi) / 6.0)
			draw_line((mid - lp * (SNARE_HALF_W * 0.65)).round(), (mid + lp * (SNARE_HALF_W * 0.65)).round(), PAL["cream"] as Color, 1.0)

	super._draw_extra(off)
	var fwd: Vector2 = Vector2.from_angle(facing)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var c: Vector2 = off.round()
	if _sprite_sheet == null:
		for s: float in [-1.0, 1.0]:
			for k: int in [-1, 0, 1]:
				var b_pt: Vector2 = off + side * (body_radius * s) + fwd * (float(k) * 3.0)
				draw_line(b_pt, b_pt + side * (5.0 * s) + fwd * (float(k) * 2.5), PAL["jade"] as Color, 1.5)
	if ambush_ghost_t > 0.0:
		var gp: Vector2 = (ambush_ghost_pos - pos + off).round()
		draw_line(gp, c, PAL["ice"] as Color, 1.2)
		draw_arc(gp, body_radius, 0.0, TAU, 12, PAL["stone"] as Color, 1.2)
	if _has_active_shield():
		var w_in: Vector2 = off + fwd * (body_radius + 1.5)
		var w_mid: Vector2 = off + fwd * (body_radius + 4.0)
		var w_out: Vector2 = off + fwd * (body_radius + 6.5)
		var w_col: Color = (PAL["cream"] if clank_t > 0.0 else PAL["ice"]) as Color
		draw_line((w_mid - side * 9.0).round(), (w_mid + side * 9.0).round(), PAL["stone"] as Color, 1.5)
		draw_line((w_in - side * 7.5).round(), (w_out + side * 7.5).round(), w_col, 1.1)
		draw_line((w_in + side * 7.5).round(), (w_out - side * 7.5).round(), w_col, 1.1)
		draw_line((w_out - side * 5.0).round(), (w_out + side * 5.0).round(), PAL["cream"] as Color, 1.0)
		for wi: int in range(-1, 2):
			var anchor: Vector2 = w_in + side * (float(wi) * 4.5)
			draw_line(anchor.round(), (anchor + fwd * 5.0).round(), PAL["ice"] as Color, 1.0)
		draw_circle((w_mid + side * (sin(anim_t * 5.0) * 2.0)).round(), 1.2, PAL["cream"] as Color)
	if active_move == MatronMove.WEB_SNARE and state == State.TELL:
		var w_urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for idx: int in [-1, 0, 1]:
			var ldir: Vector2 = snare_dir.rotated(float(idx) * SNARE_SPREAD)
			var l0: Vector2 = off + ldir * (body_radius + 2.0)
			LxBossTelegraphFx.draw_ground_danger_lane(self, l0, l0 + ldir * SNARE_LANE_LEN, SNARE_HALF_W, w_urg, anim_t, "jade", "lime")
	elif active_move == MatronMove.SCUTTLE_AMBUSH and state == State.TELL:
		var a_urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var a_end: Vector2 = off + ambush_dir * (AMBUSH_LUNGE_SPEED * AMBUSH_COMMIT_TIME)
		var aa_t: float = ambush_dir.angle()
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, a_end, 12.0, a_urg, anim_t, "coral", "gold")
		LxBossTelegraphFx.draw_ground_danger_sector(self, a_end, aa_t - AMBUSH_SLASH_ARC * 0.5, aa_t + AMBUSH_SLASH_ARC * 0.5, AMBUSH_SLASH_R, a_urg, anim_t, "coral", "gold")
	elif active_move == MatronMove.SCUTTLE_AMBUSH and state == State.COMMIT:
		var aa: float = ambush_dir.angle()
		draw_arc(c, AMBUSH_SLASH_R, aa - AMBUSH_SLASH_ARC * 0.85, aa + AMBUSH_SLASH_ARC * 0.85, 16, PAL["coral"] as Color, 2.8)
		draw_arc(c, AMBUSH_SLASH_R - 3.0, aa - AMBUSH_SLASH_ARC * 0.75, aa + AMBUSH_SLASH_ARC * 0.75, 14, PAL["cream"] as Color, 1.4)
	elif active_move == MatronMove.SPORE_RING and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, SPORE_MAX_R, prog, anim_t, "lime", "coral")
	elif active_move == MatronMove.SPORE_RING and state == State.COMMIT:
		var ring_r: float = lerpf(SPORE_START_R, SPORE_MAX_R, spore_progress)
		draw_arc(off, ring_r + 2.6, 0.0, TAU, 36, PAL["pine"] as Color, 2.4)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["jade"] as Color, 3.6)
		draw_arc(off, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["lime"] as Color, 2.0)
		for sw: int in range(4):
			var sw_a: float = anim_t * 3.2 + float(sw) * (TAU * 0.25)
			draw_arc(off, maxf(3.0, ring_r - 4.0), sw_a, sw_a + 0.65, 6, PAL["lime"] as Color, 1.2)
		for pi: int in range(8):
			var pa: float = anim_t * 2.6 + float(pi) * (TAU / 8.0)
			var wob: float = sin(anim_t * 10.0 + float(pi) * 1.6) * 2.6
			var pp: Vector2 = (off + Vector2.from_angle(pa) * (ring_r + wob)).round()
			draw_circle(pp, 2.2, PAL["pine"] as Color)
			draw_circle(pp, 1.4, PAL["lime"] as Color)
			draw_circle(pp, 0.7, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 16.0
		draw_arc(off, rr + 2.2, 0.0, TAU, 28, PAL["jade"] as Color, 2.0)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["lime"] as Color, 2.4)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.44, 0.40)


func _spawn_web_burn_fx() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var gold_col: Color = PAL["gold"] as Color
	var lime_col: Color = PAL["lime"] as Color
	var cream_col: Color = PAL["cream"] as Color
	var has_p: bool = Lx.player != null and is_instance_valid(Lx.player)
	var can_ring: bool = has_p and Lx.player.has_method("spawn_ring")
	var can_spark: bool = has_p and Lx.player.has_method("spawn_sparks")
	for lane: Dictionary in web_lanes:
		var lo: Vector2 = lane["origin"] as Vector2
		var ld: Vector2 = lane["dir"] as Vector2
		var llen: float = float(lane["length"])
		for k: int in range(3):
			var pt: Vector2 = lo + ld * (llen * (0.20 + float(k) * 0.30))
			if can_ring:
				Lx.player.call("spawn_ring", pt, 3.0, 18.0, 0.28, gold_col if k % 2 == 0 else lime_col, 1.4 if fred else 1.8)
			if can_spark:
				Lx.player.call("spawn_sparks", pt, ld, 3, gold_col, 28.0, 86.0, 0.30)
				Lx.player.call("spawn_sparks", pt, -ld, 2, lime_col if k % 2 == 0 else cream_col, 22.0, 72.0, 0.26)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(lo + ld * (llen * 0.5), 54.0, 1.32 * (0.62 if fred else 1.0), 0.32)
	if Lx.hitstop != null and is_instance_valid(Lx.hitstop):
		Lx.hitstop.trigger(0.065)
	_boss_impact(0.18, 84.0, 82.0)
