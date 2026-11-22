class_name LxHollowWickBoss
extends LxHollowWickBrain
## Moon Shoals Boss (Island 7): the Hollow Wick duel — the dark wearing Wick's full kit.
## 3 phases, HP 13.0, boss_id = "hollow_wick".
## Honest tells >= 0.40s across all phases, LURE works on him!
## Phase 1: Bolt Volley, Flare Dash, Lantern Throw+Zip.
## Phase 2: adds Dark Beam piercing line + 5-bolt spread. Phase 3: adds Eclipse Flare ring.

enum BossMove { BOLT_VOLLEY, FLARE_DASH, LANTERN_ZIP, DARK_BEAM, ECLIPSE_FLARE }

const TELL_BEAM: float = 0.56
const TELL_FLARE: float = 0.56
const BEAM_COMMIT_TIME: float = 0.28
const BEAM_RANGE: float = 152.0
const BEAM_HALF_W: float = 9.0
const FLARE_COMMIT_TIME: float = 0.30
const FLARE_START_R: float = 10.0
const FLARE_MAX_R: float = 70.0
const FLARE_BAND: float = 9.5
const ROAR_TIME: float = 0.58

var flare_progress: float = 0.0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "hollow_wick_boss"
	boss_id = "hollow_wick"
	island_id = 7
	is_boss = true
	max_hp = 13.0
	hp = 13.0
	body_radius = 5.5
	routine_speed = 56.0
	leash_radius = 185.0
	notice_radius = 152.0
	tell_time = 0.45
	recover_time = 1.05
	give_up_time = 1.8
	shard_drop = 40


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "hollow_wick"))
	island_id = int(spec.get("island_id", 7))
	flare_progress = 0.0
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
	dark_lantern_out = false
	flare_progress = 0.0
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.30)
	_emit_sfx("hollow_wick_phase")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	lured_now = _is_lured()
	if state == State.RECOVER:
		dark_lantern_out = false
		state_timer -= dt
		if state_timer <= 0.0:
			_release_token()
			var count: int = 5 if phase >= 3 else (4 if phase >= 2 else 3)
			move_index = (move_index + 1) % count
			cooldown = 0.56 if phase >= 3 else (0.64 if phase >= 2 else 0.72)
			_orbit_side = -_orbit_side
			state = State.RETURN if _should_give_up() else State.POSITION
		return
	super._step_brain(dt)


func _begin_move_tell(target: Vector2) -> void:
	active_move = move_index
	state = State.TELL
	is_counter_attack = false
	var base_t: float = TELL_VOLLEY
	match active_move:
		BossMove.FLARE_DASH:
			base_t = maxf(0.40, TELL_DASH)
		BossMove.LANTERN_ZIP:
			base_t = 0.48 if phase >= 3 else TELL_ZIP
		BossMove.DARK_BEAM:
			base_t = 0.50 if phase >= 3 else TELL_BEAM
		BossMove.ECLIPSE_FLARE:
			base_t = TELL_FLARE
		_:
			base_t = 0.42 if phase >= 3 else TELL_VOLLEY
	last_tell_duration = _scaled_tell(base_t, false, attack_damage)
	state_timer = last_tell_duration
	flare_progress = 0.0
	if target.distance_to(pos) > 0.01:
		facing = (target - pos).angle()
	commit_dir = Vector2.from_angle(facing)
	_emit_attack_started()
	_emit_sfx("hollow_wick_tell")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16:
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 3.4, dt)
			commit_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		commit_elapsed = 0.0
		commit_hit = false
		volley_shots = 0
		zip_started = false
		flare_progress = 0.0
		match active_move:
			BossMove.BOLT_VOLLEY:
				state_timer = VOLLEY_COMMIT_TIME
				_emit_sfx("bolt_fire")
			BossMove.FLARE_DASH:
				state_timer = DASH_COMMIT_TIME
				_emit_sfx("hollow_wick_commit")
			BossMove.LANTERN_ZIP:
				state_timer = ZIP_THROW_TIME + ZIP_FLY_TIME
				dark_lantern_pos = _clamp_point(pos + commit_dir * clampf(_attention_target().distance_to(pos), 34.0, 98.0))
				dark_lantern_out = true
				hollow_lantern_thrown.emit(pos, dark_lantern_pos, self)
				_emit_sfx("lantern_throw")
			BossMove.DARK_BEAM:
				state_timer = BEAM_COMMIT_TIME
				_emit_sfx("beam_fire")
			BossMove.ECLIPSE_FLARE:
				state_timer = FLARE_COMMIT_TIME
				_emit_sfx("sunflare_burst")


func _step_commit(dt: float) -> void:
	commit_elapsed += dt
	state_timer = maxf(0.0, state_timer - dt)
	match active_move:
		BossMove.BOLT_VOLLEY:
			_step_boss_volley()
		BossMove.FLARE_DASH:
			_move_step(commit_dir * DASH_SPEED * dt, true)
			_check_contact_hit(DASH_HIT_R)
		BossMove.LANTERN_ZIP:
			_step_commit_zip(dt)
		BossMove.DARK_BEAM:
			_step_beam_commit()
		BossMove.ECLIPSE_FLARE:
			_step_flare_commit()
	if state_timer <= 0.0:
		dark_lantern_out = false
		state = State.RECOVER
		var rec: float = 1.15 if (active_move == BossMove.DARK_BEAM or active_move == BossMove.ECLIPSE_FLARE) else recover_time
		state_timer = maxf(MIN_RECOVER_TIME, rec)
		last_recover_duration = state_timer


func _step_boss_volley() -> void:
	var max_shots: int = 5 if phase >= 2 else 3
	var interval: float = 0.07 if phase >= 2 else 0.11
	var expected: int = mini(max_shots, int(commit_elapsed / interval) + 1)
	var mid: float = float(max_shots - 1) * 0.5
	while volley_shots < expected:
		var bdir: Vector2 = commit_dir.rotated((float(volley_shots) - mid) * 0.12)
		volley_shots += 1
		hollow_bolt_fired.emit(pos, bdir, self)
		var end_p: Vector2 = pos + bdir * VOLLEY_RANGE
		if not commit_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= VOLLEY_HALF_W and _has_clear_view(pos, wp):
				commit_hit = true
				_emit_player_hit(bdir)
		if _is_lantern_out():
			var lp: Vector2 = _get_lantern_pos()
			if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= VOLLEY_HALF_W + 2.0 and Lx.events != null:
				Lx.events.lantern_struck.emit(lp)


func _step_beam_commit() -> void:
	var end_p: Vector2 = pos + commit_dir * BEAM_RANGE
	if not commit_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= BEAM_HALF_W and _has_clear_view(pos, wp):
			commit_hit = true
			_emit_player_hit(commit_dir)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= BEAM_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)


func _step_flare_commit() -> void:
	flare_progress = 1.0 - clampf(state_timer / FLARE_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(FLARE_START_R, FLARE_MAX_R, flare_progress)
	if not commit_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= FLARE_BAND:
			commit_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else commit_dir
			var prev_kind: String = kind
			kind = "shockwave"
			_emit_player_hit(push)
			kind = prev_kind
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _body_color() -> Color:
	if phase >= 3:
		return PAL["dusk"] as Color
	if phase >= 2:
		return PAL["deep"] as Color
	return PAL["night"] as Color


func _volley_count() -> int:
	return 5 if phase >= 2 else 3


func _volley_spread() -> float:
	return 0.12


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Rival moth antenna crown
		draw_line(off + Vector2(-3.0, -body_radius), off + Vector2(-5.5, -body_radius - 4.0), PAL["ice"] as Color, 1.4)
		draw_line(off + Vector2(3.0, -body_radius), off + Vector2(5.5, -body_radius - 4.0), PAL["ice"] as Color, 1.4)
	super._draw_extra(off)
	if active_move == BossMove.DARK_BEAM and state == State.TELL:
		var locked_hw: bool = state_timer <= 0.16
		var t_col: Color = (PAL["coral"] if locked_hw else (PAL["gold"] if lured_now else PAL["sky"])) as Color
		var b_perp: Vector2 = Vector2(-commit_dir.y, commit_dir.x)
		var b_tip: Vector2 = (off + commit_dir * BEAM_RANGE).round()
		draw_line(off.round(), b_tip, t_col, 2.2 if locked_hw else 1.6)
		if locked_hw:
			draw_line(off.round(), b_tip, PAL["cream"] as Color, 1.0)
		draw_line((b_tip - b_perp * BEAM_HALF_W).round(), (b_tip + b_perp * BEAM_HALF_W).round(), t_col, 1.2)
		draw_circle(off.round(), 2.8 if locked_hw else 2.2, (PAL["cream"] if locked_hw else PAL["ice"]) as Color)
	elif active_move == BossMove.DARK_BEAM and state == State.COMMIT:
		var orig: Vector2 = off.round()
		var b_end: Vector2 = (off + commit_dir * BEAM_RANGE).round()
		draw_line(orig, b_end, PAL["deep"] as Color, 7.6)
		draw_line(orig, b_end, PAL["blue"] as Color, 5.4)
		draw_line(orig, b_end, PAL["sky"] as Color, 3.6)
		draw_line(orig, b_end, PAL["ice"] as Color, 2.2)
		draw_line(orig, b_end, PAL["cream"] as Color, 1.1)
		var fl: float = 8.0 + 1.4 * sin(anim_t * 24.0)
		for ep_i: int in range(2):
			var fp: Vector2 = orig if ep_i == 0 else b_end
			var fr: float = fl if ep_i == 0 else fl + 1.5
			draw_line(fp + Vector2(-fr, 0.0), fp + Vector2(fr, 0.0), PAL["sky"] as Color, 1.8)
			draw_line(fp + Vector2(0.0, -fr), fp + Vector2(0.0, fr), PAL["sky"] as Color, 1.8)
			draw_line(fp + Vector2(-fr * 0.65, 0.0), fp + Vector2(fr * 0.65, 0.0), PAL["cream"] as Color, 1.1)
			draw_line(fp + Vector2(0.0, -fr * 0.65), fp + Vector2(0.0, fr * 0.65), PAL["cream"] as Color, 1.1)
			draw_circle(fp, 2.0, PAL["cream"] as Color)
	elif active_move == BossMove.ECLIPSE_FLARE and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(off, FLARE_MAX_R, a0, a0 + 0.24, 3, PAL["sky"] as Color, 1.0)
		draw_arc(off, lerpf(FLARE_MAX_R, FLARE_START_R + 6.0, prog), 0.0, TAU, 26, PAL["ice"] as Color, 1.8)
	elif active_move == BossMove.ECLIPSE_FLARE and state == State.COMMIT:
		var ring_r: float = lerpf(FLARE_START_R, FLARE_MAX_R, flare_progress)
		draw_arc(off, ring_r + 2.6, 0.0, TAU, 36, PAL["blue"] as Color, 2.2)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
		draw_arc(off, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 1.8)
		draw_arc(off, maxf(2.0, ring_r - 4.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.1)
		for ci: int in range(8):
			var rd: Vector2 = Vector2.from_angle(float(ci) * (TAU / 8.0))
			var is_card: bool = (ci % 2 == 0)
			var r_in: float = maxf(3.0, ring_r - (6.5 if is_card else 4.0))
			var r_out: float = ring_r + (7.5 if is_card else 4.5)
			var c_col: Color = (PAL["cream"] if is_card else PAL["ice"]) as Color
			draw_line((off + rd * r_in).round(), (off + rd * r_out).round(), c_col, 1.6 if is_card else 1.1)
			if is_card:
				draw_circle((off + rd * r_out).round(), 1.2, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 26, PAL["blue"] as Color, 1.8)
		draw_arc(off, rr, 0.0, TAU, 26, PAL["ice"] as Color, 2.2)
