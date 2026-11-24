class_name LxClockworkWardenBoss
extends LxOrrerySentinelBrain
## Starfall Observatory mini-boss (Island 5): Clockwork Warden.
## 2 phases, HP 8.0. Front brass armour blocks plain bolts; Prism, Beam, or rear-core hits pierce.
## Phase 2 upgrades into a Reverse-Gear Double-Fan; active True Lens grants rear-core 1.5x crit!

enum FanStage { FAN_1, REVERSE_PAUSE, FAN_2 }

const PHASE2_ROAR_TIME: float = 0.56
const FAN_SPREAD_RAD: float = 0.26
const REVERSE_PAUSE_TIME: float = 0.42
const REVERSE_OFFSET_RAD: float = 0.18
const LENS_REAR_CRIT_MULT: float = 1.50

var fan_stage: int = FanStage.FAN_1
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "clockwork_warden"
	boss_id = "clockwork_warden"
	island_id = 5
	is_boss = true
	max_hp = 8.0
	hp = 8.0
	body_radius = 8.0
	routine_speed = 36.0
	leash_radius = 168.0
	notice_radius = 144.0
	tell_time = 0.56
	recover_time = 1.15
	give_up_time = 1.8
	shard_drop = 16


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "clockwork_warden"))
	island_id = int(spec.get("island_id", 5))
	fan_stage = FanStage.FAN_1
	_roaring = false


func _back_crit_mult() -> float:
	return LENS_REAR_CRIT_MULT if lens_highlight_t > 0.0 else BACK_CRIT_MULT


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
		fan_stage = FanStage.FAN_1
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.24, 90.0, 86.0)
		_emit_sfx("clockwork_warden_phase2")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		facing = wrapf(facing + rail_spin * SCAN_TURN_SPEED * 1.4 * dt, -PI, PI)
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	_step_rail_patrol(dt)
	if lens_pause_t <= 0.0:
		var spin_mult: float = 1.30 if phase >= 2 else 1.05
		facing = wrapf(facing + rail_spin * SCAN_TURN_SPEED * spin_mult * dt, -PI, PI)
	state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN

	if cooldown <= 0.0 and _is_on_screen() and _target_in_cone() and _claim_token():
		fan_stage = FanStage.FAN_1
		state = State.TELL
		is_counter_attack = false
		var base_t: float = 0.50 if phase >= 2 else tell_time
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("orrery_bell_tell")


func _step_commit(dt: float) -> void:
	if fan_stage == FanStage.REVERSE_PAUSE:
		state_timer -= dt
		if state_timer <= 0.0:
			fan_stage = FanStage.FAN_2
			state_timer = COMMIT_TIME
			shot_dir = Vector2.from_angle(facing)
			shot_fired = false
			shot_hit = false
			_emit_sfx("orrery_beam_bolt")
		return

	var angles: Array[float] = [0.0]
	if phase >= 2:
		angles = [0.0, -FAN_SPREAD_RAD, FAN_SPREAD_RAD]
	if not shot_fired:
		shot_fired = true
		_boss_impact(0.16 if phase >= 2 else 0.12, 82.0, 78.0)
		for off_a: float in angles:
			beam_bolt_fired.emit(pos, shot_dir.rotated(off_a), self)
	if not shot_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		for off_a: float in angles:
			var rdir: Vector2 = shot_dir.rotated(off_a)
			var rend: Vector2 = pos + rdir * BOLT_RANGE
			if Geometry2D.get_closest_point_to_segment(wp, pos, rend).distance_to(wp) <= BOLT_HALF_W \
					and _has_clear_view(pos, wp):
				shot_hit = true
				_emit_player_hit(rdir)
				break
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		for off_a: float in angles:
			var rend_l: Vector2 = pos + shot_dir.rotated(off_a) * BOLT_RANGE
			if Geometry2D.get_closest_point_to_segment(lp, pos, rend_l).distance_to(lp) <= BOLT_HALF_W + 2.0:
				if Lx.events != null:
					Lx.events.lantern_struck.emit(lp)
				break
	state_timer -= dt
	if state_timer <= 0.0:
		if fan_stage == FanStage.FAN_1 and phase >= 2:
			# P2 Reverse-Gear Double-Fan: gears click in reverse and fire an offset 2nd fan!
			fan_stage = FanStage.REVERSE_PAUSE
			rail_spin = -rail_spin
			facing = wrapf(facing + rail_spin * REVERSE_OFFSET_RAD, -PI, PI)
			state_timer = REVERSE_PAUSE_TIME
			shot_fired = false
			shot_hit = false
			_emit_sfx("orrery_bell_tell")
		else:
			fan_stage = FanStage.FAN_1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer
			facing = wrapf(facing + rail_spin * 0.55, -PI, PI)


func _body_color() -> Color:
	return (PAL["plum"] as Color) if phase >= 2 else (PAL["deep"] as Color)


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Clockwork brass gear teeth ring
		for i: int in range(8):
			var ga: float = anim_t * 1.4 * rail_spin + float(i) * (TAU / 8.0)
			var g0: Vector2 = off + Vector2.from_angle(ga) * (body_radius + 0.5)
			var g1: Vector2 = off + Vector2.from_angle(ga) * (body_radius + 3.5)
			draw_line(g0, g1, PAL["apricot"] as Color, 1.5)
	super._draw_extra(off)
	var c: Vector2 = off.round()
	if state == State.TELL or (state == State.COMMIT and fan_stage == FanStage.REVERSE_PAUSE):
		var denom: float = REVERSE_PAUSE_TIME if fan_stage == FanStage.REVERSE_PAUSE else maxf(last_tell_duration, 0.05)
		var prog: float = 1.0 - clampf(state_timer / maxf(denom, 0.05), 0.0, 1.0)
		var locked_c: bool = state_timer <= 0.24
		var ray_n: int = 3 if phase >= 2 else 1
		for ri: int in range(ray_n):
			var off_a: float = 0.0 if ri == 0 else (-FAN_SPREAD_RAD if ri == 1 else FAN_SPREAD_RAD)
			var r_end: Vector2 = (c + Vector2.from_angle(facing + off_a) * BOLT_RANGE).round()
			draw_line(c, r_end, (PAL["coral"] if locked_c else PAL["sky"]) as Color, 2.2 if locked_c else 2.0)
			draw_line(c, r_end, (PAL["cream"] if locked_c else PAL["gold"]) as Color, 1.0)
		draw_arc(c, lerpf(16.0, 4.0, prog), 0.0, TAU, 16, (PAL["cream"] if state_timer <= 0.12 else (PAL["coral"] if locked_c else PAL["sky"])) as Color, 1.6 if state_timer <= 0.12 else 1.2)
		_draw_cw_star_flare(c, lerpf(3.5, 7.5, prog), (PAL["cream"] if state_timer <= 0.12 else (PAL["coral"] if locked_c else PAL["gold"])) as Color, PAL["cream"] as Color)
	elif state == State.COMMIT:
		var fl: float = 6.5 + (0.0 if LxHudFx.flash_reduced() else 1.2 * sin(anim_t * 22.0))
		var ray_n: int = 3 if phase >= 2 else 1
		for ri: int in range(ray_n):
			var off_a: float = 0.0 if ri == 0 else (-FAN_SPREAD_RAD if ri == 1 else FAN_SPREAD_RAD)
			var r_end: Vector2 = (c + shot_dir.rotated(off_a) * BOLT_RANGE).round()
			draw_line(c, r_end, PAL["sky"] as Color, 5.0)
			draw_line(c, r_end, PAL["gold"] as Color, 3.2)
			draw_line(c, r_end, PAL["ice"] as Color, 2.0)
			draw_line(c, r_end, PAL["cream"] as Color, 1.0)
			_draw_cw_star_flare(r_end, fl, PAL["gold"] as Color, PAL["cream"] as Color)
		_draw_cw_star_flare(c, fl + 2.0, PAL["sky"] as Color, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 16.0
		draw_arc(c, rr + 2.4, 0.0, TAU, 28, PAL["sky"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
		draw_arc(c, maxf(3.0, rr - 2.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)


func _draw_cw_star_flare(pt: Vector2, rad: float, outer: Color, core: Color) -> void:
	var p: Vector2 = pt.round()
	draw_line(p + Vector2(-rad, 0.0), p + Vector2(rad, 0.0), outer, 1.8)
	draw_line(p + Vector2(0.0, -rad), p + Vector2(0.0, rad), outer, 1.8)
	draw_line(p + Vector2(-rad * 0.62, 0.0), p + Vector2(rad * 0.62, 0.0), core, 1.0)
	draw_line(p + Vector2(0.0, -rad * 0.62), p + Vector2(0.0, rad * 0.62), core, 1.0)
	draw_circle(p, 1.8, core)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.44, 0.38)
