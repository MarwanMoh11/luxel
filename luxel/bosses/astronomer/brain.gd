class_name LxAstronomerBoss
extends LxPhantomOwlBrain
## Starfall Observatory Boss (Island 5): the Astronomer, a great celestial phantom owl.
## 3 phases, HP 12.5. Constellation attacks are revealed by Lens light, and she stays
## briefly solid & visible during COMMIT/RECOVER/STAGGER so players & bots always have windows.

enum AstroMove { DIVE, CONSTELLATION }

const NOVA_TELL_P2: float = 0.64
const NOVA_TELL_P3: float = 0.56
const NOVA_COMMIT_TIME: float = 0.36
const NOVA_START_R: float = 10.0
const NOVA_MAX_R: float = 76.0
const NOVA_BAND: float = 9.5
const NOVA_RAY_RANGE: float = 124.0
const NOVA_RAY_HALF_W: float = 8.0
const NOVA_RECOVER: float = 1.35
const ROAR_TIME: float = 0.65

var active_move: int = AstroMove.DIVE
var move_cycle: int = 0
var nova_progress: float = 0.0
var nova_hit: bool = false
var star_base_ang: float = 0.0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "astronomer"
	boss_id = "astronomer"
	island_id = 5
	is_boss = true
	max_hp = 12.5
	hp = 12.5
	body_radius = 8.5
	routine_speed = 76.0
	leash_radius = 185.0
	notice_radius = 152.0
	tell_time = 0.62
	recover_time = 1.35
	give_up_time = 1.8
	shard_drop = 34


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "astronomer"))
	island_id = int(spec.get("island_id", 5))
	active_move = AstroMove.DIVE
	move_cycle = 0
	nova_progress = 0.0
	nova_hit = false
	star_base_ang = 0.0
	_roaring = false


func is_targetable() -> bool:
	if not is_alive() or not revealed:
		return false
	# Always targetable when revealed in ROUTINE, TELL, COMMIT, RECOVER, STAGGER
	return state == State.ROUTINE or state == State.TELL or state == State.COMMIT \
			or state == State.RECOVER or state == State.STAGGER


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
	active_move = AstroMove.DIVE
	nova_progress = 0.0
	reveal_t = maxf(reveal_t, ROAR_TIME + 0.35)
	revealed = true
	altitude = ALT_PERCH
	vel = Vector2.ZERO
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.30)
	_emit_sfx("astronomer_phase")


func _step_brain(dt: float) -> void:
	reveal_t = maxf(0.0, reveal_t - dt)
	_check_lens_reveal()
	if state == State.NOTICE and _roaring:
		reveal_t = maxf(reveal_t, 0.30)
		revealed = true
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			_enter_cruise(0.65)
		return
	if state == State.TELL and active_move == AstroMove.CONSTELLATION:
		altitude = move_toward(altitude, ALT_DIVE, ALT_CLIMB_SPEED * dt)
		vel = Vector2.ZERO
		if state_timer > 0.22:
			var to_t: Vector2 = (_get_lantern_pos() if _can_lure() else _get_wick_pos()) - pos
			if to_t.length() > 0.01:
				star_base_ang = to_t.angle()
				facing = star_base_ang
		state_timer -= dt
		if state_timer <= 0.0:
			_enter_constellation_commit()
		revealed = reveal_t > 0.0
		return
	if state == State.COMMIT and active_move == AstroMove.CONSTELLATION:
		_step_constellation_commit(dt)
		reveal_t = maxf(reveal_t, 0.45)
		revealed = true
		return

	super._step_brain(dt)
	# Keep Astronomer reliably visible during COMMIT, RECOVER, STAGGER for readable windows
	if state == State.COMMIT or state == State.RECOVER or state == State.STAGGER:
		reveal_t = maxf(reveal_t, 0.45)
		revealed = true


func _enter_lock(target: Vector2, lured: bool) -> void:
	move_cycle += 1
	if phase >= 2 and (move_cycle % 2 == 0):
		active_move = AstroMove.CONSTELLATION
		state = State.TELL
		is_counter_attack = false
		var base_n: float = NOVA_TELL_P3 if phase >= 3 else NOVA_TELL_P2
		last_tell_duration = _scaled_tell(base_n, false, attack_damage)
		state_timer = last_tell_duration
		vel = Vector2.ZERO
		lock_target = target
		lock_lured = lured
		nova_progress = 0.0
		nova_hit = false
		star_base_ang = (target - pos).angle() if target.distance_to(pos) > 0.01 else facing
		facing = star_base_ang
		_emit_attack_started()
		_emit_sfx("astronomer_constellation_tell")
		return
	active_move = AstroMove.DIVE
	super._enter_lock(target, lured)
	if phase >= 3:
		last_tell_duration = _scaled_tell(0.55, false, attack_damage)
		state_timer = last_tell_duration


func _enter_constellation_commit() -> void:
	state = State.COMMIT
	state_timer = NOVA_COMMIT_TIME
	altitude = ALT_PERCH
	nova_progress = 0.0
	nova_hit = false
	reveal_t = maxf(reveal_t, 0.55)
	revealed = true
	_emit_sfx("astronomer_constellation_fire")


func _step_constellation_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	nova_progress = 1.0 - clampf(state_timer / NOVA_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(NOVA_START_R, NOVA_MAX_R, nova_progress)
	var ray_count: int = 5 if phase >= 3 else 3
	if not nova_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		var wv: Vector2 = wp - pos
		if absf(wv.length() - ring_r) <= NOVA_BAND:
			nova_hit = true
			_emit_shockwave_hit(wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing))
		else:
			for i: int in range(ray_count):
				var ra: float = star_base_ang + float(i) * (TAU / float(ray_count))
				var rdir: Vector2 = Vector2.from_angle(ra)
				if Geometry2D.get_closest_point_to_segment(wp, pos, pos + rdir * NOVA_RAY_RANGE).distance_to(wp) <= NOVA_RAY_HALF_W:
					nova_hit = true
					_emit_player_hit(rdir)
					break
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		active_move = AstroMove.DIVE
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, NOVA_RECOVER)
		last_recover_duration = state_timer
		altitude = ALT_PERCH
		vel = Vector2.ZERO
		_emit_sfx("owl_recover")


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir)
	kind = prev_kind


func _body_color() -> Color:
	if not revealed:
		return PAL["deep"] as Color
	if phase >= 3:
		return PAL["gold"] as Color
	if phase >= 2:
		return PAL["ice"] as Color
	return PAL["sky"] as Color


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if _sprite_sheet == null:
		# Astrolabe celestial halo
		draw_arc(off, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.2)
	var ray_count: int = 5 if phase >= 3 else 3
	var c_orig: Vector2 = off.round()
	if active_move == AstroMove.CONSTELLATION and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(off, NOVA_MAX_R, a0, a0 + 0.24, 3, PAL["sky"] as Color, 1.0)
		var t_r: float = lerpf(NOVA_MAX_R, NOVA_START_R + 8.0, prog)
		draw_arc(off, t_r, 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
		var ray_len: float = NOVA_RAY_RANGE
		for i: int in range(ray_count):
			var ra: float = star_base_ang + float(i) * (TAU / float(ray_count))
			var nb: float = star_base_ang + float((i + 1) % ray_count) * (TAU / float(ray_count))
			var p_a: Vector2 = (off + Vector2.from_angle(ra) * ray_len).round()
			var p_b: Vector2 = (off + Vector2.from_angle(nb) * ray_len).round()
			draw_line(c_orig, p_a, PAL["sky"] as Color, 1.3)
			draw_line(p_a, p_b, PAL["gold"] as Color, 1.0)
			draw_line(p_a + Vector2(-4.5, 0.0), p_a + Vector2(4.5, 0.0), PAL["gold"] as Color, 1.3)
			draw_line(p_a + Vector2(0.0, -4.5), p_a + Vector2(0.0, 4.5), PAL["gold"] as Color, 1.3)
			draw_circle(p_a, 1.4, PAL["cream"] as Color)
		var cf: float = lerpf(4.0, 8.0, prog)
		draw_line(c_orig + Vector2(-cf, 0.0), c_orig + Vector2(cf, 0.0), PAL["gold"] as Color, 1.5)
		draw_line(c_orig + Vector2(0.0, -cf), c_orig + Vector2(0.0, cf), PAL["gold"] as Color, 1.5)
		draw_circle(c_orig, 1.8, PAL["cream"] as Color)
	elif active_move == AstroMove.CONSTELLATION and state == State.COMMIT:
		var ring_r: float = lerpf(NOVA_START_R, NOVA_MAX_R, nova_progress)
		draw_arc(off, ring_r + 2.2, 0.0, TAU, 36, PAL["sky"] as Color, 2.0)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["ice"] as Color, 3.2)
		draw_arc(off, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.3)
		var fl: float = 6.5 + 1.2 * sin(anim_t * 22.0)
		for i: int in range(ray_count):
			var ra: float = star_base_ang + float(i) * (TAU / float(ray_count))
			var nb: float = star_base_ang + float((i + 1) % ray_count) * (TAU / float(ray_count))
			var p_a: Vector2 = (off + Vector2.from_angle(ra) * NOVA_RAY_RANGE).round()
			var p_b: Vector2 = (off + Vector2.from_angle(nb) * NOVA_RAY_RANGE).round()
			draw_line(p_a, p_b, PAL["gold"] as Color, 1.2)
			draw_line((off + Vector2.from_angle(ra) * ring_r).round(), (off + Vector2.from_angle(nb) * ring_r).round(), PAL["apricot"] as Color, 1.0)
			draw_line(c_orig, p_a, PAL["apricot"] as Color, 4.2)
			draw_line(c_orig, p_a, PAL["gold"] as Color, 2.5)
			draw_line(c_orig, p_a, PAL["cream"] as Color, 1.1)
			draw_line(p_a + Vector2(-fl, 0.0), p_a + Vector2(fl, 0.0), PAL["gold"] as Color, 1.6)
			draw_line(p_a + Vector2(0.0, -fl), p_a + Vector2(0.0, fl), PAL["gold"] as Color, 1.6)
			draw_line(p_a + Vector2(-fl * 0.6, 0.0), p_a + Vector2(fl * 0.6, 0.0), PAL["cream"] as Color, 1.0)
			draw_line(p_a + Vector2(0.0, -fl * 0.6), p_a + Vector2(0.0, fl * 0.6), PAL["cream"] as Color, 1.0)
			draw_circle(p_a, 1.8, PAL["cream"] as Color)
		var c_fl: float = fl + 3.0
		draw_line(c_orig + Vector2(-c_fl, 0.0), c_orig + Vector2(c_fl, 0.0), PAL["gold"] as Color, 2.0)
		draw_line(c_orig + Vector2(0.0, -c_fl), c_orig + Vector2(0.0, c_fl), PAL["gold"] as Color, 2.0)
		draw_line(c_orig + Vector2(-c_fl * 0.65, 0.0), c_orig + Vector2(c_fl * 0.65, 0.0), PAL["cream"] as Color, 1.2)
		draw_line(c_orig + Vector2(0.0, -c_fl * 0.65), c_orig + Vector2(0.0, c_fl * 0.65), PAL["cream"] as Color, 1.2)
		draw_circle(c_orig, 2.4, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 16.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["sky"] as Color, 1.8)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["ice"] as Color, 2.2)
