class_name LxForgeWardenBoss
extends LxCinderGolemBrain
## Ashen Kiln mini-boss (Island 6): Forge Warden.
## 2 phases, HP 8.5, heavy armour 3.5 (cracked by Sunflare).
## Phase 2 follows its Forge Quake with a telegraphed Molten Line-Fissure hammer slam
## aimed along Wick's lane (tell >= 0.52s) instead of a 2nd shockwave ring!

enum QuakeStage { RING_1, FISSURE_TELL, FISSURE_COMMIT }

const FORGE_ARMOUR_MAX: float = 3.5
const FORGE_RING_MAX_R: float = 76.0
const FORGE_RING_BAND: float = 10.5
const FORGE_TRIGGER_R: float = 84.0
const FISSURE_TELL_TIME: float = 0.54
const FISSURE_COMMIT_TIME: float = 0.34
const FISSURE_RANGE: float = 114.0
const FISSURE_HALF_W: float = 13.0
const PHASE2_ROAR_TIME: float = 0.60

var quake_stage: int = QuakeStage.RING_1
var fissure_dir: Vector2 = Vector2.RIGHT
var fissure_progress: float = 0.0
var fissure_hit: bool = false
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "forge_warden"
	boss_id = "forge_warden"
	island_id = 6
	is_boss = true
	max_hp = 8.5
	hp = 8.5
	armour_max = FORGE_ARMOUR_MAX
	armour_hp = FORGE_ARMOUR_MAX
	body_radius = 8.5
	routine_speed = 26.0
	leash_radius = 150.0
	notice_radius = 132.0
	tell_time = 0.64
	recover_time = 1.45
	give_up_time = 1.1
	attack_damage = 1.5
	reach = FORGE_TRIGGER_R
	lunge_reach = FORGE_TRIGGER_R
	shard_drop = 18


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "forge_warden"))
	island_id = int(spec.get("island_id", 6))
	armour_max = maxf(1.0, float(spec.get("armour_hp", FORGE_ARMOUR_MAX)))
	armour_hp = armour_max
	armour_intact = true
	quake_stage = QuakeStage.RING_1
	fissure_dir = Vector2.from_angle(facing)
	fissure_progress = 0.0
	fissure_hit = false
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
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		_roaring = true
		quake_stage = QuakeStage.RING_1
		stomp_progress = 0.0
		fissure_progress = 0.0
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.28, 98.0, 96.0)
		_emit_sfx("forge_warden_phase2")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _try_start_attack(_target_pos: Vector2, dist: float) -> bool:
	if dist <= FORGE_TRIGGER_R and _claim_token():
		state = State.TELL
		lunge_attack = false
		is_counter_attack = false
		var base_t: float = 0.56 if phase >= 2 else tell_time
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		stomp_progress = 0.0
		stomp_hit = false
		quake_stage = QuakeStage.RING_1
		_emit_attack_started()
		_emit_sfx("golem_stomp_tell")
		return true
	return false


func _enter_commit() -> void:
	quake_stage = QuakeStage.RING_1
	super._enter_commit()
	_boss_impact(0.18, 88.0, 90.0)


func _step_commit(dt: float) -> void:
	if quake_stage == QuakeStage.FISSURE_TELL:
		if state_timer > 0.20:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 3.2, dt)
				fissure_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			quake_stage = QuakeStage.FISSURE_COMMIT
			state_timer = FISSURE_COMMIT_TIME
			fissure_progress = 0.0
			fissure_hit = false
			fissure_dir = Vector2.from_angle(facing)
			_boss_impact(0.22, 98.0, 102.0)
			_emit_sfx("golem_stomp_shockwave")
		return

	if quake_stage == QuakeStage.FISSURE_COMMIT:
		state_timer = maxf(0.0, state_timer - dt)
		fissure_progress = 1.0 - clampf(state_timer / FISSURE_COMMIT_TIME, 0.0, 1.0)
		var cur_len: float = lerpf(12.0, FISSURE_RANGE, fissure_progress)
		var fend: Vector2 = pos + fissure_dir * cur_len
		if not fissure_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			if Geometry2D.get_closest_point_to_segment(wp, pos, fend).distance_to(wp) <= FISSURE_HALF_W:
				fissure_hit = true
				_emit_player_hit(fissure_dir, attack_damage)
		if _is_lured():
			var lp: Vector2 = _get_lantern_pos()
			if Geometry2D.get_closest_point_to_segment(lp, pos, fend).distance_to(lp) <= FISSURE_HALF_W + 2.0:
				if Lx.events != null:
					Lx.events.lantern_struck.emit(lp)
		if state_timer <= 0.0:
			quake_stage = QuakeStage.RING_1
			fissure_progress = 0.0
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer
		return

	state_timer = maxf(0.0, state_timer - dt)
	stomp_progress = 1.0 - clampf(state_timer / STOMP_COMMIT_TIME, 0.0, 1.0)
	var max_r: float = FORGE_RING_MAX_R if phase >= 2 else STOMP_MAX_R + 6.0
	var ring_r: float = lerpf(STOMP_START_R, max_r, stomp_progress)
	if not stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= FORGE_RING_BAND:
			stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if quake_stage == QuakeStage.RING_1 and phase >= 2:
			# P2 chains a telegraphed Molten Line-Fissure aimed along Wick's lane!
			quake_stage = QuakeStage.FISSURE_TELL
			state_timer = _scaled_tell(FISSURE_TELL_TIME, false, attack_damage)
			var to_w: Vector2 = _attention_target() - pos
			if to_w.length() > 0.01:
				facing = to_w.angle()
			fissure_dir = Vector2.from_angle(facing)
			fissure_progress = 0.0
			fissure_hit = false
			_emit_sfx("golem_stomp_tell")
		else:
			quake_stage = QuakeStage.RING_1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _body_color() -> Color:
	if armour_intact:
		return (PAL["mauve"] as Color) if phase >= 2 else (PAL["stone"] as Color)
	return (PAL["apricot"] as Color) if phase >= 2 else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Glowing forge grate core
		draw_rect(Rect2(off + Vector2(-4.0, -3.0), Vector2(8.0, 5.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(off + Vector2(-3.0, -2.0), Vector2(6.0, 3.0)), (PAL["gold"] as Color) if not armour_intact else (PAL["coral"] as Color), true)
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 3.0, 1.8, armour_hp, armour_max)
	var c: Vector2 = off.round()
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var tell_max_r: float = FORGE_RING_MAX_R if phase >= 2 else STOMP_MAX_R + 6.0
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(c, tell_max_r, a0, a0 + 0.24, 3, PAL["coral"] as Color, 1.0)
		var tr: float = lerpf(tell_max_r, STOMP_START_R + 5.0, prog)
		var hot: bool = state_timer <= 0.14
		draw_arc(c, tr + 2.0, 0.0, TAU, 28, (PAL["apricot"] if hot else PAL["coral"]) as Color, 1.4)
		draw_arc(c, tr, 0.0, TAU, 28, (PAL["cream"] if hot else PAL["apricot"]) as Color, 2.0 if hot else 1.8)
		draw_arc(c, maxf(3.0, tr - 2.0), 0.0, TAU, 24, (PAL["cream"] if hot else PAL["gold"]) as Color, 1.0)
	elif state == State.COMMIT:
		if quake_stage == QuakeStage.FISSURE_TELL:
			var perp: Vector2 = Vector2(-fissure_dir.y, fissure_dir.x)
			var fend: Vector2 = (c + fissure_dir * FISSURE_RANGE).round()
			var hot_f: bool = state_timer <= 0.20
			var fc: Color = (PAL["cream"] if hot_f else PAL["apricot"]) as Color
			draw_line((c + perp * (FISSURE_HALF_W * 0.72)).round(), (fend + perp * (FISSURE_HALF_W * 0.72)).round(), PAL["coral"] as Color, 1.4)
			draw_line((c - perp * (FISSURE_HALF_W * 0.72)).round(), (fend - perp * (FISSURE_HALF_W * 0.72)).round(), PAL["coral"] as Color, 1.4)
			draw_line(c, fend, fc, 2.0 if hot_f else 1.4)
			for ci: int in range(1, 6):
				var t: float = float(ci) / 6.0
				var mp: Vector2 = c.lerp(fend, t).round()
				var zig: float = (4.0 if ci % 2 == 0 else -4.0)
				draw_line(mp, (mp + perp * zig).round(), PAL["gold"] as Color, 1.2)
		elif quake_stage == QuakeStage.FISSURE_COMMIT:
			var cur_len: float = lerpf(12.0, FISSURE_RANGE, fissure_progress)
			var perp2: Vector2 = Vector2(-fissure_dir.y, fissure_dir.x)
			var fend2: Vector2 = (c + fissure_dir * cur_len).round()
			draw_line(c, fend2, PAL["wine"] as Color, 10.0)
			draw_line(c, fend2, PAL["coral"] as Color, 6.8)
			draw_line(c, fend2, PAL["apricot"] as Color, 4.0)
			draw_line(c, fend2, PAL["gold"] as Color, 2.2)
			draw_line(c, fend2, PAL["cream"] as Color, 1.0)
			for ei: int in range(5):
				var et: float = float(ei + 1) / 5.5
				var ep: Vector2 = (c + fissure_dir * (cur_len * et) + perp2 * (sin(anim_t * 18.0 + float(ei) * 2.1) * 6.0)).round()
				draw_circle(ep, 2.0, PAL["gold"] as Color)
				draw_circle(ep, 1.0, PAL["cream"] as Color)
		else:
			var max_r: float = FORGE_RING_MAX_R if phase >= 2 else STOMP_MAX_R + 6.0
			var ring_r: float = lerpf(STOMP_START_R, max_r, stomp_progress)
			draw_arc(c, ring_r + 2.8, 0.0, TAU, 36, PAL["wine"] as Color, 2.5)
			draw_arc(c, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.8)
			draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
			draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)
			for si: int in range(8):
				var sa: float = anim_t * 1.9 + float(si) * (TAU / 8.0)
				var sd: Vector2 = Vector2.from_angle(sa)
				var st: Vector2 = Vector2(-sd.y, sd.x)
				var base_c: Vector2 = c + sd * maxf(2.0, ring_r - 1.0)
				var tip: Vector2 = (c + sd * (ring_r + 6.5)).round()
				draw_line((base_c - st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line((base_c + st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line(base_c.round(), tip, PAL["gold"] as Color, 1.2)
				draw_circle(tip, 1.1, PAL["apricot"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 16.0
		draw_arc(c, rr + 2.4, 0.0, TAU, 28, PAL["coral"] as Color, 2.2)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["apricot"] as Color, 2.4)
		draw_arc(c, maxf(3.0, rr - 2.2), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.48, 0.42)
