class_name LxAstronomerBoss
extends LxPhantomOwlBrain
## Starfall Observatory Boss (Island 5): the Astronomer, a great celestial phantom owl.
## 3 phases, HP 18.0. During P2/P3 Constellation TELL, renders 1-2 decoy phantom silhouettes;
## active True Lens (on_light(..., "lens")) exposes her true gold core and staggers her 0.8s!

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
const LENS_STAGGER_TIME: float = 0.80
const ROAR_TIME: float = 0.65

var active_move: int = AstroMove.DIVE
var move_cycle: int = 0
var nova_progress: float = 0.0
var nova_hit: bool = false
var star_base_ang: float = 0.0
var decoy_offsets: Array[Vector2] = []
var true_core_lit_t: float = 0.0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "astronomer"
	boss_id = "astronomer"
	island_id = 5
	is_boss = true
	max_hp = 18.0
	hp = 18.0
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
	max_hp = maxf(18.0, max_hp)
	hp = max_hp
	is_boss = true
	boss_id = str(spec.get("boss_id", "astronomer"))
	island_id = int(spec.get("island_id", 5))
	active_move = AstroMove.DIVE
	move_cycle = 0
	nova_progress = 0.0
	nova_hit = false
	star_base_ang = 0.0
	decoy_offsets.clear()
	true_core_lit_t = 0.0
	_roaring = false


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = source
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2
		elif b is String and src.is_empty():
			src = str(b)
	super.on_light(a, b, src)
	if state == State.DEAD or src != "lens" or rad <= 0.0:
		return
	var in_light: bool = orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius
	if not in_light:
		return
	true_core_lit_t = maxf(true_core_lit_t, 0.85)
	if state == State.TELL and active_move == AstroMove.CONSTELLATION:
		# Active True Lens pulse during Constellation TELL shatters decoys and staggers her 0.8s!
		_spawn_decoy_shatter_fx()
		active_move = AstroMove.DIVE
		decoy_offsets.clear()
		_release_token()
		state = State.STAGGER
		state_timer = LENS_STAGGER_TIME
		altitude = ALT_PERCH
		vel = Vector2.ZERO
		reveal_t = maxf(reveal_t, 1.35)
		revealed = true
		_boss_impact(0.18, 76.0, 74.0)
		_emit_sfx("astronomer_lens_shatter")


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
	decoy_offsets.clear()
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
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("astronomer_phase")


func _step_brain(dt: float) -> void:
	reveal_t = maxf(0.0, reveal_t - dt)
	true_core_lit_t = maxf(0.0, true_core_lit_t - dt)
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
		decoy_offsets.clear()
		if phase == 2:
			decoy_offsets.append(Vector2.from_angle(star_base_ang + PI * 0.55) * 44.0)
		else:
			decoy_offsets.append(Vector2.from_angle(star_base_ang + 2.1) * 46.0)
			decoy_offsets.append(Vector2.from_angle(star_base_ang - 2.1) * 46.0)
		_emit_attack_started()
		_emit_sfx("astronomer_constellation_tell")
		return
	active_move = AstroMove.DIVE
	decoy_offsets.clear()
	super._enter_lock(target, lured)
	if phase >= 3:
		last_tell_duration = _scaled_tell(0.55, false, attack_damage)
		state_timer = last_tell_duration


func _enter_constellation_commit() -> void:
	state = State.COMMIT
	state_timer = NOVA_COMMIT_TIME
	altitude = ALT_PERCH
	decoy_offsets.clear()
	nova_progress = 0.0
	nova_hit = false
	reveal_t = maxf(reveal_t, 0.55)
	revealed = true
	_boss_impact(0.22, 104.0, 98.0)
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


func _is_constellation_tell() -> bool:
	return state == State.TELL and active_move == AstroMove.CONSTELLATION


func _draw() -> void:
	if revealed or not _is_constellation_tell():
		super._draw()
		return
	# Unrevealed: keep the wisps, drop the phantom-owl dive ring, show the real Constellation telegraph
	state = State.POSITION
	super._draw()
	state = State.TELL
	_draw_extra(_visual_offset())


func _draw_extra(off: Vector2) -> void:
	if _is_constellation_tell():
		# Nothing lands on lock_target here: draw the owl layers without their TELL dive marker
		state = State.POSITION
		super._draw_extra(off)
		state = State.TELL
	else:
		super._draw_extra(off)
	var c_orig: Vector2 = off.round()
	if _sprite_sheet == null:
		# Astrolabe celestial halo
		draw_arc(off, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.2)
	if true_core_lit_t > 0.0:
		# Active True Lens exposes the true gold core!
		draw_arc(c_orig, body_radius + 6.5, 0.0, TAU, 20, PAL["gold"] as Color, 2.0)
		draw_arc(c_orig, body_radius + 3.5, 0.0, TAU, 16, PAL["cream"] as Color, 1.2)
		draw_circle(c_orig, 3.0, PAL["gold"] as Color)
		draw_circle(c_orig, 1.5, PAL["cream"] as Color)
	var ray_count: int = 5 if phase >= 3 else 3
	if active_move == AstroMove.CONSTELLATION and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var fred: bool = LxHudFx.flash_reduced()
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, NOVA_MAX_R, prog, anim_t, "sky", "gold")
		for i: int in range(ray_count):
			var ra: float = star_base_ang + float(i) * (TAU / float(ray_count))
			var nb: float = star_base_ang + float((i + 1) % ray_count) * (TAU / float(ray_count))
			var p_a: Vector2 = off + Vector2.from_angle(ra) * NOVA_RAY_RANGE
			var p_b: Vector2 = (off + Vector2.from_angle(nb) * NOVA_RAY_RANGE).round()
			LxBossTelegraphFx.draw_ground_danger_lane(self, off, p_a, NOVA_RAY_HALF_W, prog, anim_t, "sky", "gold")
			var pa_r: Vector2 = p_a.round()
			draw_line(pa_r, p_b, PAL["gold"] as Color, 1.0)
			draw_line(pa_r + Vector2(-4.5, 0.0), pa_r + Vector2(4.5, 0.0), PAL["gold"] as Color, 1.3)
			draw_line(pa_r + Vector2(0.0, -4.5), pa_r + Vector2(0.0, 4.5), PAL["gold"] as Color, 1.3)
			draw_circle(pa_r, 1.4, PAL["cream"] as Color)
		# Render 1-2 decoy phantom silhouettes with faint ground tether & shimmering ice-diamond True-Lens halo
		var tether_a: float = 0.24 if fred else (0.20 + 0.12 * sin(anim_t * 10.0))
		for d_off: Vector2 in decoy_offsets:
			var dc: Vector2 = (c_orig + d_off).round()
			draw_line(c_orig, dc, Color(PAL["ice"] as Color, tether_a), 1.0)
			var dr: float = body_radius + 6.0 + (0.0 if fred else 1.2 * sin(anim_t * 14.0 + d_off.x))
			var dpts: PackedVector2Array = PackedVector2Array([dc + Vector2(0.0, -dr), dc + Vector2(dr, 0.0), dc + Vector2(0.0, dr), dc + Vector2(-dr, 0.0), dc + Vector2(0.0, -dr)])
			draw_polyline(dpts, PAL["void"] as Color, 2.2)
			draw_polyline(dpts, PAL["ice"] as Color, 1.2)
			draw_arc(dc, body_radius + 4.0, 0.0, TAU, 16, PAL["plum"] as Color, 1.2)
			draw_circle(dc, body_radius * 0.72, PAL["deep"] as Color)
			draw_arc(dc, body_radius * 0.85, 0.0, TAU, 14, PAL["sky"] as Color, 1.0)
			draw_line(dc + Vector2(-5.0, -2.0), dc + Vector2(-9.0, -5.0), PAL["sky"] as Color, 1.4)
			draw_line(dc + Vector2(5.0, -2.0), dc + Vector2(9.0, -5.0), PAL["sky"] as Color, 1.4)
			draw_rect(Rect2(dc + Vector2(-2.0, -1.0), Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
			draw_rect(Rect2(dc + Vector2(2.0, -1.0), Vector2(1.0, 1.0)), PAL["ice"] as Color, true)
		var cf: float = lerpf(4.0, 8.0, prog)
		draw_line(c_orig + Vector2(-cf, 0.0), c_orig + Vector2(cf, 0.0), PAL["gold"] as Color, 1.5)
		draw_line(c_orig + Vector2(0.0, -cf), c_orig + Vector2(0.0, cf), PAL["gold"] as Color, 1.5)
		draw_circle(c_orig, 1.8, PAL["cream"] as Color)
	elif active_move == AstroMove.CONSTELLATION and state == State.COMMIT:
		var ring_r: float = lerpf(NOVA_START_R, NOVA_MAX_R, nova_progress)
		draw_arc(off, ring_r + 2.2, 0.0, TAU, 36, PAL["sky"] as Color, 2.0)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["ice"] as Color, 3.2)
		draw_arc(off, maxf(2.0, ring_r - 2.4), 0.0, TAU, 28, PAL["cream"] as Color, 1.3)
		var fl: float = 6.5 + (0.0 if LxHudFx.flash_reduced() else 1.2 * sin(anim_t * 22.0))
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


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.24, 1.60, 0.48)


func _spawn_decoy_shatter_fx() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var ice_col: Color = PAL["ice"] as Color
	var gold_col: Color = PAL["gold"] as Color
	var cream_col: Color = PAL["cream"] as Color
	var has_p: bool = Lx.player != null and is_instance_valid(Lx.player)
	var can_ring: bool = has_p and Lx.player.has_method("spawn_ring")
	var can_spark: bool = has_p and Lx.player.has_method("spawn_sparks")
	for d_off: Vector2 in decoy_offsets:
		var dpos: Vector2 = pos + d_off
		if can_ring:
			Lx.player.call("spawn_ring", dpos, 4.0, 26.0, 0.30, ice_col, 1.4 if fred else 1.8)
			Lx.player.call("spawn_ring", dpos, 2.0, 16.0, 0.22, gold_col, 1.2 if fred else 1.5)
		if can_spark:
			for si: int in range(4):
				var sdir: Vector2 = Vector2.from_angle(float(si) * (PI * 0.5) + PI * 0.25)
				var scol: Color = ice_col if si % 2 == 0 else (gold_col if si == 1 else cream_col)
				Lx.player.call("spawn_sparks", dpos, sdir, 3, scol, 34.0, 96.0, 0.32)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(dpos, 58.0, 1.38 * (0.62 if fred else 1.0), 0.34)
	if Lx.hitstop != null and is_instance_valid(Lx.hitstop):
		Lx.hitstop.trigger(0.065)
