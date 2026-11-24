class_name LxHollowWickBoss
extends LxHollowWickBrain
## Moon Shoals Boss (Island 7, spire_r10): HOLLOW WICK UNMASKED (Upgraded to Epic Bible 4.7).
## 3 phases, HP 26.0, boss_id = "hollow_wick". Honest tells >= 0.40s across all phases, LURE works!
## P1 (100-66%): Classic honest mirror duel (Bolt Volley 0.45s, Flare Dash 0.42s, Lantern Throw+Zip 0.52s).
## P2 (66-33% — "THE MIRROR CRACKS OPEN!"): Diagonal Silver/Black arena fault + Mirrored Clone
##   (spot real via dark-lantern SE shadow; shooting Clone sparks mirror ping; Blue/Beam or flipping
##   center moon_pool shatters Clone for 1.6s stagger!) + Dark Beam (0.56s) + 5-bolt spread.
## P3 (<=33%): Eclipse Flare (0.56s) + Stolen Lantern Clash (0.58s bright ice-coral tell while Dark
##   Lantern flies — shoot or Zip-intercept to knock it free for 2.2s stagger + 3.0 clash damage!)
##   + unmasked pale moth shimmer on low HP / peaceful sky-blue dissolve on death.

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
const ROAR_TIME: float = 0.66
const CLONE_SHATTER_STAGGER: float = 1.60
const CLASH_THROW_TIME_P3: float = 0.58
const CLASH_STAGGER: float = 2.20
const CLASH_DAMAGE: float = 3.0

var flare_progress: float = 0.0
var _roaring: bool = false

# Epic Bible 4.7 P2/P3 upgrades: Diagonal Silver/Black split, Mirrored Clone, Stolen Lantern Clash
var p2_split_active: bool = false
var clone_active: bool = false
var clone_pos: Vector2 = Vector2.ZERO
var clone_flash_t: float = 0.0
var clone_respawn_cd: float = 0.0
var _last_world_face: String = "silver"
var clash_window_open: bool = false
var clash_flash_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "hollow_wick_boss"
	boss_id = "hollow_wick"
	island_id = 7
	is_boss = true
	max_hp = 26.0
	hp = 26.0
	body_radius = 5.5
	routine_speed = 56.0
	leash_radius = 185.0
	notice_radius = 152.0
	tell_time = 0.45
	recover_time = 1.05
	give_up_time = 1.8
	shard_drop = 45


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	max_hp = maxf(26.0, max_hp)
	hp = max_hp
	is_boss = true
	boss_id = str(spec.get("boss_id", "hollow_wick"))
	island_id = int(spec.get("island_id", 7))
	flare_progress = 0.0
	_roaring = false
	p2_split_active = false
	clone_active = false
	clone_pos = home
	clone_flash_t = 0.0
	clone_respawn_cd = 0.0
	_last_world_face = _read_spire_face()
	clash_window_open = false
	clash_flash_t = 0.0


func _read_spire_face() -> String:
	if Lx.vars == null:
		return "silver"
	return "black" if Lx.vars.eval("world_face==black", 7, "spire_r10") else "silver"


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	# P3 Stolen Lantern Clash: striking with Beam / Throw / Recall / Zip / Blue while flying Dark Lantern is open!
	if phase >= 3 and clash_window_open and dark_lantern_out and hit != null:
		var h_cl: Dictionary = _read_hit(hit)
		var src_cl: String = str(h_cl["source"])
		if src_cl in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or hit.is_blue():
			return _trigger_lantern_clash(hit)
	var res: int = super.take_hit(hit)
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _trigger_lantern_clash(hit: LxHit) -> int:
	clash_window_open = false
	dark_lantern_out = false
	clash_flash_t = 0.65
	_release_token()
	hp = maxf(0.0, hp - CLASH_DAMAGE)
	flash_t = 0.22
	LxDamageFx.boss_impact(dark_lantern_pos, 0.24, 96.0, 96.0, 94.0, 1.48, 0.36, "ice")
	_emit_sfx("perfect_counter")
	_emit_sfx("mirror_crack")
	if hp <= 0.001:
		opened_kill = true
		_die(hit)
		return HitResult.KILLED
	state = State.STAGGER
	state_timer = CLASH_STAGGER
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _shatter_mirror_clone() -> void:
	if not clone_active:
		return
	clone_active = false
	clone_respawn_cd = 10.0
	clone_flash_t = 0.0
	LxDamageFx.boss_impact(clone_pos, 0.18, 76.0, 74.0, 76.0, 1.36, 0.30, "ice")
	_emit_sfx("glass_shatter")
	_release_token()
	dark_lantern_out = false
	clash_window_open = false
	state = State.STAGGER
	state_timer = CLONE_SHATTER_STAGGER


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001:
		_enter_phase(2)
	elif phase < 3 and hp <= max_hp * 0.33 and hp > 0.001:
		_enter_phase(3)


func _enter_phase(next_phase: int) -> void:
	phase = next_phase
	_roaring = true
	dark_lantern_out = false
	clash_window_open = false
	flare_progress = 0.0
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if next_phase == 2:
		p2_split_active = true
		clone_active = true
		clone_pos = _clamp_point(home + (home - pos))
		_last_world_face = _read_spire_face()
	elif next_phase == 3:
		clone_active = false
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.34)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("hollow_wick_phase")


func _step_brain(dt: float) -> void:
	clone_flash_t = maxf(0.0, clone_flash_t - dt)
	clash_flash_t = maxf(0.0, clash_flash_t - dt)
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return

	# P2 Mirror Clone tracking, world-flip shatter, & bolt interception
	if phase == 2:
		var face_now: String = _read_spire_face()
		if face_now != _last_world_face:
			_last_world_face = face_now
			if clone_active:
				_shatter_mirror_clone()
		if clone_active:
			clone_pos = _clamp_point(home + (home - pos))
			_check_clone_bolts()
		elif clone_respawn_cd > 0.0:
			clone_respawn_cd = maxf(0.0, clone_respawn_cd - dt)
			if clone_respawn_cd <= 0.0 and state == State.POSITION:
				clone_active = true
				clone_pos = _clamp_point(home + (home - pos))

	# P3 Flying Dark Lantern Clash check (shoot or Zip-intercept flying Dark Lantern!)
	if phase >= 3 and clash_window_open and dark_lantern_out:
		_check_p3_lantern_clash()

	lured_now = _is_lured()
	if state == State.RECOVER:
		dark_lantern_out = false
		clash_window_open = false
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


func _check_clone_bolts() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object and (bv.get("pos") as Vector2).distance_to(clone_pos) <= 13.0:
			var is_b: bool = str(bv.get("color")) == LxHit.COLOR_BLUE
			w.bolts.remove_at(bi)
			if is_b:
				_shatter_mirror_clone()
			else:
				clone_flash_t = 0.45
				_emit_sfx("mirror_ping")
			break


func _check_p3_lantern_clash() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	# 1. Shooting the flying Dark Lantern with a bolt!
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object and (bv.get("pos") as Vector2).distance_to(dark_lantern_pos) <= 16.0:
			w.bolts.remove_at(bi)
			var cl_hit := LxHit.make(LxHit.SOURCE_BOLT, CLASH_DAMAGE, (dark_lantern_pos - w.global_position).normalized(), dark_lantern_pos, 1.0, true, true, w)
			_trigger_lantern_clash(cl_hit)
			return
	# 2. Zipping or Dashing right through the flying Dark Lantern!
	if (w.is_dashing() or w.is_zipping()) and w.global_position.distance_to(dark_lantern_pos) <= 24.0:
		var cl_hit2 := LxHit.make(LxHit.SOURCE_ZIP, CLASH_DAMAGE, (pos - w.global_position).normalized(), dark_lantern_pos, 1.0, true, true, w)
		_trigger_lantern_clash(cl_hit2)


func _begin_move_tell(target: Vector2) -> void:
	active_move = move_index
	state = State.TELL
	is_counter_attack = false
	var base_t: float = TELL_VOLLEY
	match active_move:
		BossMove.FLARE_DASH:
			base_t = maxf(0.40, TELL_DASH)
		BossMove.LANTERN_ZIP:
			base_t = 0.52 if phase >= 3 else TELL_ZIP
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
	if active_move == BossMove.LANTERN_ZIP:
		dark_lantern_pos = _clamp_point(pos + commit_dir * clampf(target.distance_to(pos), 34.0, 98.0))
	_emit_attack_started()
	_emit_sfx("hollow_wick_tell")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16:
		var target_now: Vector2 = _attention_target()
		var to_t: Vector2 = target_now - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 3.4, dt)
			commit_dir = Vector2.from_angle(facing)
		if active_move == BossMove.LANTERN_ZIP:
			dark_lantern_pos = _clamp_point(pos + commit_dir * clampf(target_now.distance_to(pos), 34.0, 98.0))
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
				var th_dur: float = CLASH_THROW_TIME_P3 if phase >= 3 else ZIP_THROW_TIME
				state_timer = th_dur + ZIP_FLY_TIME
				dark_lantern_pos = _clamp_point(dark_lantern_pos)
				dark_lantern_out = true
				clash_window_open = (phase >= 3)
				hollow_lantern_thrown.emit(pos, dark_lantern_pos, self)
				_emit_sfx("lantern_throw")
			BossMove.DARK_BEAM:
				state_timer = BEAM_COMMIT_TIME
				_boss_impact(0.16, 76.0, 72.0)
				_emit_sfx("beam_fire")
			BossMove.ECLIPSE_FLARE:
				state_timer = FLARE_COMMIT_TIME
				_boss_impact(0.24, 102.0, 100.0)
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
			_step_boss_zip(dt)
		BossMove.DARK_BEAM:
			_step_beam_commit()
		BossMove.ECLIPSE_FLARE:
			_step_flare_commit()
	if state_timer <= 0.0:
		dark_lantern_out = false
		clash_window_open = false
		state = State.RECOVER
		var rec: float = 1.15 if (active_move == BossMove.DARK_BEAM or active_move == BossMove.ECLIPSE_FLARE) else recover_time
		state_timer = maxf(MIN_RECOVER_TIME, rec)
		last_recover_duration = state_timer


func _step_boss_zip(dt: float) -> void:
	var th_dur: float = CLASH_THROW_TIME_P3 if phase >= 3 else ZIP_THROW_TIME
	if commit_elapsed < th_dur:
		return
	clash_window_open = false
	if not zip_started:
		zip_started = true
		_emit_sfx("hollow_wick_zip")
	var to_l: Vector2 = dark_lantern_pos - pos
	if to_l.length() > 3.0:
		_move_step(to_l.limit_length(340.0 * dt), true)
	if pos.distance_to(dark_lantern_pos) <= 6.0:
		_check_contact_hit(ZIP_BURST_R)


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
	# Bible 4.7: Real Hollow Wick casts SE black-lantern shadow; P2 diagonal NW Silver / SE Black split!
	if p2_split_active:
		var hc: Vector2 = (home - pos).round()
		draw_line(hc + Vector2(-130.0, 82.0), hc + Vector2(130.0, -82.0), Color(PAL["ice"] as Color, 0.45), 2.4)
		draw_line(hc + Vector2(-130.0, 82.0), hc + Vector2(130.0, -82.0), Color(PAL["rose"] as Color, 0.65), 1.0)
	if phase >= 2:
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 8.0, 3.0, "black_lantern", false)

	# P2 Mirrored Clone (NW lie shadow! Flashes silver on decoy bolt hit)
	if clone_active and phase == 2:
		var cl: Vector2 = (clone_pos - pos).round()
		LxIsland7Rule.draw_truth_shadow(self, cl + Vector2(0.0, 4.0), 7.5, 2.8, "nw_wrong", false)
		draw_circle(cl, body_radius + 1.0, Color(PAL["deep"] as Color, 0.72))
		draw_arc(cl, body_radius + 2.5, 0.0, TAU, 14, PAL["cream"] as Color if clone_flash_t > 0.0 else PAL["ice"] as Color, 1.4)
		if clone_flash_t > 0.0:
			draw_arc(cl, body_radius + 8.0, 0.0, TAU, 16, PAL["sky"] as Color, 1.4)

	# P3 Unmasked pale moth shimmer (hood slipping open!)
	if phase >= 3:
		draw_arc(off.round() + Vector2(0.0, -4.0), 5.0, 0.0, TAU, 12, Color(PAL["ice"] as Color, 0.65), 1.0)

	if _sprite_sheet == null:
		draw_line(off + Vector2(-3.0, -body_radius), off + Vector2(-5.5, -body_radius - 4.0), PAL["ice"] as Color, 1.4)
		draw_line(off + Vector2(3.0, -body_radius), off + Vector2(5.5, -body_radius - 4.0), PAL["ice"] as Color, 1.4)
	super._draw_extra(off)

	# P3 Bright ice-coral Stolen Lantern Clash intercept tell!
	if phase >= 3 and clash_window_open and dark_lantern_out:
		var lp: Vector2 = (dark_lantern_pos - pos).round()
		var cu: float = clampf(commit_elapsed / CLASH_THROW_TIME_P3, 0.0, 1.0)
		draw_arc(lp, roundf(lerpf(18.0, 8.0, cu)), 0.0, TAU, 18, PAL["coral"] as Color, 1.8)
		draw_arc(lp, 11.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.4)
		draw_circle(lp, 2.5, PAL["cream"] as Color)
	if clash_flash_t > 0.0:
		var cf: float = 1.0 - clampf(clash_flash_t / 0.65, 0.0, 1.0)
		draw_arc(off.round(), roundf(lerpf(10.0, 38.0, cf)), 0.0, TAU, 22, Color(PAL["ice"] as Color, 1.0 - cf), 2.0)

	if active_move == BossMove.DARK_BEAM and state == State.TELL:
		var b_urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked_hw: bool = state_timer <= 0.16
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, off + commit_dir * BEAM_RANGE, BEAM_HALF_W, b_urg, anim_t, "sky", "coral")
		draw_circle(off.round(), 2.8 if locked_hw else 2.2, (PAL["cream"] if locked_hw else PAL["ice"]) as Color)
	elif active_move == BossMove.DARK_BEAM and state == State.COMMIT:
		var orig: Vector2 = off.round()
		var b_end: Vector2 = (off + commit_dir * BEAM_RANGE).round()
		draw_line(orig, b_end, PAL["deep"] as Color, 7.6)
		draw_line(orig, b_end, PAL["blue"] as Color, 5.4)
		draw_line(orig, b_end, PAL["sky"] as Color, 3.6)
		draw_line(orig, b_end, PAL["ice"] as Color, 2.2)
		draw_line(orig, b_end, PAL["cream"] as Color, 1.1)
		var fl: float = 8.0 + (0.0 if LxHudFx.flash_reduced() else 1.4 * sin(anim_t * 24.0))
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
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, FLARE_MAX_R, prog, anim_t, "sky", "coral")
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
		var fred_r: bool = LxHudFx.flash_reduced()
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 18.0
		var rot: float = anim_t * (1.2 if fred_r else 3.4)
		var c_r: Vector2 = off.round()
		draw_arc(c_r, rr + 2.5, 0.0, TAU, 26, PAL["blue"] as Color, 1.6)
		draw_arc(c_r, rr, 0.0, TAU, 26, PAL["ice"] as Color, 1.8)
		for ci: int in range(2):
			var base_a: float = rot + float(ci) * PI
			var cr: float = rr * 0.78 + float(ci) * 3.5
			draw_arc(c_r, cr + 1.4, base_a, base_a + PI * 0.72, 14, PAL["void"] as Color, 2.4)
			draw_arc(c_r, cr, base_a, base_a + PI * 0.72, 14, (PAL["sky"] if ci == 0 else PAL["ice"]) as Color, 2.0)
			draw_arc(c_r, maxf(3.0, cr - 1.6), base_a + 0.14, base_a + PI * 0.58, 10, PAL["cream"] as Color, 1.1)
		var sh_in: float = body_radius + 5.0 + rp * 12.0
		var sh_out: float = sh_in + lerpf(7.0, 13.0, rp)
		for si: int in range(6):
			var sa: float = -rot * 0.6 + float(si) * (TAU / 6.0)
			var sd: Vector2 = Vector2.from_angle(sa)
			var p0: Vector2 = (c_r + sd * sh_in).round()
			var p1: Vector2 = (c_r + sd * sh_out).round()
			draw_line(p0, p1, PAL["void"] as Color, 2.4)
			draw_line(p0, p1, (PAL["ice"] if si % 2 == 0 else PAL["sky"]) as Color, 1.4)
			if not fred_r or si % 2 == 0:
				draw_circle(p1, 1.1, PAL["cream"] as Color)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.14, 1.48, 0.40)
