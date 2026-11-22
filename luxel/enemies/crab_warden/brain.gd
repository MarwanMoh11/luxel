class_name LxCrabWardenBrain
extends LxWardenBrain
## Crab Warden (Island 2): sidesteps along the beach keeping its giant claw shield
## toward Wick, uses a crisp 0.30s pinch counter, and is opened by prism_bolt banks or LURE.

const PINCH_COUNTER_TELL: float = 0.30
const PINCH_COUNTER_R: float = 46.0
const STRAFE_SWITCH_MIN: float = 1.2
const STRAFE_SWITCH_MAX: float = 2.2
const CLAW_BLOCK_HALF: float = 1.12

var strafe_sign: float = 1.0
var strafe_t: float = 1.5


func _init() -> void:
	kind = "crab_warden"
	island_id = 2
	max_hp = 4.5
	hp = 4.5
	shield_max = 2.0
	shield_hp = 2.0
	shield_gone_duration = 4.5
	body_radius = 6.0
	routine_speed = 36.0
	leash_radius = 158.0
	notice_radius = 124.0
	tell_time = 0.48
	lunge_tell_time = 0.56
	recover_time = 1.15
	give_up_time = 2.0
	shard_drop = 4


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	strafe_sign = 1.0 if _randf_range(0.0, 1.0) < 0.5 else -1.0
	strafe_t = _randf_range(STRAFE_SWITCH_MIN, STRAFE_SWITCH_MAX)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	# Prism bank shots curve around the front claw shield cleanly.
	if src == LxHit.SOURCE_PRISM and _has_active_shield():
		var dmg: float = float(h["damage"])
		var orig: Vector2 = h["origin"] as Vector2
		var rel: Vector2 = orig - pos
		hp -= dmg
		wary = true
		flash_t = 0.14
		if rel.length() > 0.01:
			knock = -rel.normalized() * 48.0
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		if state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
		_emit_sfx("crab_flank_hit")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	return super.take_hit(hit)


func _step_guard(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), TURN_GUARD * 1.25, dt)

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

	if is_lead and cooldown <= 0.0 and _is_on_screen() and _can_claim_token():
		if _try_start_attack(target_pos, dist):
			return

	# Sidestep laterally along the beach while keeping claw shield aimed at target.
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_sign = -strafe_sign
		strafe_t = _randf_range(STRAFE_SWITCH_MIN, STRAFE_SWITCH_MAX)

	var fwd: Vector2 = to_t / maxf(dist, 0.01) if dist > 0.01 else Vector2.from_angle(facing)
	var perp: Vector2 = Vector2(-fwd.y, fwd.x) * strafe_sign
	var want_r: float = (reach - 4.0) if is_lead else RING_R
	var radial: float = clampf((dist - want_r) / 28.0, -0.55, 0.55)
	var move_dir: Vector2 = (perp * 0.85 + fwd * radial).normalized()
	var spd: float = minf(routine_speed * 0.85, routine_speed - 2.0)
	var next_p: Vector2 = pos + move_dir * spd * dt
	if next_p.distance_to(home) > maxf(0.0, leash_radius - 4.0):
		strafe_sign = -strafe_sign
		move_dir = (home - pos).normalized()
	_move_step(move_dir * spd * dt, false)


func _on_stagger_end(target_pos: Vector2) -> void:
	var tw: Vector2 = _get_wick_pos() - pos
	if _has_player() and tw.length() < PINCH_COUNTER_R and _is_on_screen() and _claim_token(true):
		state = State.TELL
		is_counter_attack = true
		lunge_attack = false
		last_tell_duration = _scaled_tell(PINCH_COUNTER_TELL, true, attack_damage)
		state_timer = last_tell_duration
		if tw.length() > 0.01:
			facing = tw.angle()
		_emit_attack_started()
		_emit_sfx("crab_pinch_counter")
	else:
		_release_token()
		state = State.POSITION
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()


func _body_color() -> Color:
	return PAL["coral"] as Color


func _shield_color() -> Color:
	return PAL["apricot"] as Color


func _draw_extra(off: Vector2) -> void:
	var c := Vector2(roundf(off.x), roundf(off.y))
	var fwd: Vector2 = Vector2.from_angle(facing)
	var side := Vector2(-fwd.y, fwd.x)
	if _sprite_sheet == null:
		# Wide scuttling crab legs on both flanks.
		var scuttle: float = sin(anim_t * 11.0) * 1.5
		for s: float in [-1.0, 1.0]:
			var leg_base: Vector2 = off + side * (body_radius * s)
			draw_line(leg_base, leg_base + side * 3.5 + fwd * (2.0 + scuttle * s), PAL["wine"] as Color, 1.5)
			draw_line(leg_base, leg_base + side * 3.5 - fwd * (2.0 + scuttle * s), PAL["wine"] as Color, 1.5)
		# Oversized front guard claw
		var claw_c: Color = (PAL["cream"] as Color) if clank_t > 0.0 else (PAL["gold"] as Color if is_counter_attack and state == State.TELL else PAL["apricot"] as Color)
		if _has_active_shield():
			var claw_p: Vector2 = off + fwd * (body_radius + 3.5) + side * 3.0
			draw_circle(claw_p, 3.5, PAL["night"] as Color)
			draw_circle(claw_p, 2.5, claw_c)
	if clank_t > 0.0:
		var cp: float = clampf(clank_t / 0.14, 0.0, 1.0)
		var sp := Vector2(roundf(c.x + fwd.x * (body_radius + 4.0)), roundf(c.y + fwd.y * (body_radius + 4.0)))
		for i: int in range(-2, 3):
			var sd: Vector2 = Vector2.from_angle(facing + float(i) * 0.45)
			var sl: float = (5.0 if (i % 2 == 0) else 3.5) + (1.0 - cp) * 3.0
			var tip := Vector2(roundf(sp.x + sd.x * sl), roundf(sp.y + sd.y * sl))
			draw_line(sp, tip, (PAL["gold"] as Color) if (i % 2 == 0) else (PAL["apricot"] as Color), 1.2)
			draw_rect(Rect2(tip, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	if state == State.TELL or state == State.COMMIT:
		var is_c: bool = state == State.COMMIT
		var spread: float = 0.14 if is_c else 0.58
		var arc_r: float = body_radius + (9.5 if is_c else 8.0)
		for si: int in range(-1, 2, 2):
			var s: float = float(si)
			var piv := Vector2(roundf(c.x + side.x * (s * 2.5)), roundf(c.y + side.y * (s * 2.5)))
			var a0: float = facing + s * (spread + 0.55)
			var a1: float = facing + s * spread
			var lo: float = minf(a0, a1)
			var hi: float = maxf(a0, a1)
			draw_arc(piv, arc_r + 1.5, lo, hi, 8, PAL["wine"] as Color, 2.4)
			draw_arc(piv, arc_r, lo, hi, 8, PAL["coral"] as Color, 1.8)
			draw_arc(piv, arc_r - 1.2, lo, hi, 8, PAL["apricot"] as Color, 1.2)
			draw_arc(piv, arc_r - 2.2, lo, hi, 6, PAL["gold"] as Color, 1.0)
		var focal := Vector2(roundf(c.x + fwd.x * (body_radius + 10.5)), roundf(c.y + fwd.y * (body_radius + 10.5)))
		if is_c:
			for ki: int in range(4):
				var kd: Vector2 = Vector2.from_angle(facing + float(ki) * (PI * 0.5) + PI * 0.25)
				var kp := Vector2(roundf(focal.x + kd.x * 4.0), roundf(focal.y + kd.y * 4.0))
				draw_line(focal, kp, PAL["gold"] as Color, 1.0)
				draw_rect(Rect2(kp, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
			draw_rect(Rect2(focal - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PAL["cream"] as Color, true)
		elif is_counter_attack:
			var arm: float = 3.0 if LxHudFx.flash_reduced() else roundf(3.0 + sin(anim_t * 28.0) * 1.5)
			draw_line(focal + Vector2(-arm, 0.0), focal + Vector2(arm, 0.0), PAL["gold"] as Color, 1.4)
			draw_line(focal + Vector2(0.0, -arm), focal + Vector2(0.0, arm), PAL["gold"] as Color, 1.4)
			draw_rect(Rect2(focal, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
