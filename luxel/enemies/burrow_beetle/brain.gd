class_name LxBurrowBeetleBrain
extends LxEnemyBrain
## Burrow Beetle (Island 3): Armored tank + living mirror.
## Patrols soil tracks; front yellow bolts clank & provoke a brief burrow reposition;
## stationary mirrored carapace reflects Prism bolts (is_reflective / reflect_dir);
## charges along a telegraphed lane (0.54s tell, 0.42s commit, 1.15s recover) and
## flips onto its golden belly if it slams a wall or bloomed light_plant wall!

const CHARGE_RANGE: float = 108.0
const CHARGE_SPEED: float = 210.0
const CHARGE_TIME: float = 0.42
const CHARGE_HIT_R: float = 15.0
const FRONT_ARC_HALF: float = 1.12
const FLIP_STAGGER_TIME: float = 1.25
const BURROW_HOP_TIME: float = 0.55
const POST_COOLDOWN: float = 0.95

var is_flying: bool = false
var waypoints: Array[Vector2] = []
var wp_i: int = 0
var pause_t: float = 0.0
var burrowed: bool = false
var burrow_t: float = 0.0
var burrow_goal: Vector2 = Vector2.ZERO
var shell_cracked: bool = false
var flipped: bool = false
var charge_dir: Vector2 = Vector2.RIGHT
var charge_hit: bool = false
var _clank_burrow_cd: float = 0.0


func _init() -> void:
	kind = "burrow_beetle"
	island_id = 3
	max_hp = 4.5
	hp = 4.5
	body_radius = 6.5
	routine_speed = 36.0
	leash_radius = 156.0
	notice_radius = 112.0
	tell_time = 0.54
	recover_time = 1.15
	give_up_time = 1.9
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	waypoints.clear()
	var raw_pts: Variant = spec.get("route", spec.get("perches", []))
	if raw_pts is Array:
		for pt_v: Variant in (raw_pts as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				waypoints.append(_clamp_pt(_to_vec2(pt_v, home)))
	if waypoints.size() < 2:
		var r: float = minf(42.0, leash_radius * 0.40)
		waypoints = [_clamp_pt(home + Vector2(-r, 0.0)), _clamp_pt(home + Vector2(r, 0.0))]
	wp_i = 0
	pause_t = 0.45
	burrowed = false
	burrow_t = 0.0
	burrow_goal = home
	shell_cracked = false
	flipped = false
	charge_dir = Vector2.from_angle(facing)
	charge_hit = false
	_clank_burrow_cd = 0.0


## Living Mirror Carapace contract for Prism bounces (puzzles & combat bank shots).
func is_reflective() -> bool:
	return is_alive() and not burrowed and not flipped and not shell_cracked and state != State.COMMIT


func reflect_dir(in_dir: Vector2) -> Vector2:
	var n: Vector2 = Vector2.from_angle(facing)
	if in_dir.dot(n) > 0.0:
		n = -n
	return in_dir.normalized().bounce(n).normalized()


func is_targetable() -> bool:
	return is_alive() and not burrowed


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or src == "dew_ray"
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_ARC_HALF

	if burrowed:
		if cracks or pierce:
			burrowed = false
			burrow_t = 0.0
			shell_cracked = true
			_emit_sfx("burrow_beetle_crack")
		else:
			clank_t = 0.14
			_emit_sfx("burrow_beetle_clank")
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED

	# Beam / Sunflare / Dew Ray cracks mirrored shell wide open!
	if cracks and not shell_cracked:
		shell_cracked = true
		flipped = true
		_release_token()
		LxDamageFx.boss_impact(pos, 0.12, 58.0, 64.0, 52.0, 1.25, 0.26, "ice")
		_emit_sfx("burrow_beetle_crack")
		hp -= dmg * 1.25
		flash_t = 0.18
		if rel.length() > 0.01:
			knock = -rel.normalized() * 105.0
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		state = State.STAGGER
		state_timer = FLIP_STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	# Front yellow bolt against intact mirrored dome clanks (small chip so never softlocked, plus burrow dodge)
	if from_front and not shell_cracked and not flipped and state != State.RECOVER and state != State.STAGGER:
		if src == LxHit.SOURCE_BOLT:
			clank_t = 0.16
			hp -= dmg * 0.25
			_emit_sfx("burrow_beetle_clank")
			if hp <= 0.001:
				_die(hit)
				return HitResult.KILLED
			if _clank_burrow_cd <= 0.0 and state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN]:
				_start_burrow_dodge(rel)
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED

	var is_open: bool = flipped or state == State.RECOVER or state == State.STAGGER or not from_front or shell_cracked
	if flipped:
		dmg *= 1.50
	elif not from_front or state == State.RECOVER:
		dmg *= 1.30
	hp -= dmg
	flash_t = 0.16 if (is_open or is_heavy) else 0.09
	if rel.length() > 0.01:
		knock = -rel.normalized() * (110.0 if is_heavy else 28.0)

	if hp <= 0.001:
		opened_kill = is_open
		_die(hit)
		return HitResult.KILLED

	if is_heavy and (not from_front or shell_cracked or state == State.RECOVER):
		_release_token()
		flipped = true
		state = State.STAGGER
		state_timer = 0.85
		_emit_sfx("burrow_beetle_flip")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if is_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _start_burrow_dodge(rel_attacker: Vector2) -> void:
	burrowed = true
	burrow_t = BURROW_HOP_TIME
	_clank_burrow_cd = 2.4
	var perp: Vector2 = Vector2(-rel_attacker.y, rel_attacker.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
	if perp.length_squared() < 0.01:
		perp = Vector2.UP
	burrow_goal = _clamp_pt(pos + perp * 34.0)
	state = State.POSITION
	_emit_sfx("burrow_beetle_dig")


func _step_brain(dt: float) -> void:
	_clank_burrow_cd = maxf(0.0, _clank_burrow_cd - dt)
	var target_pos: Vector2 = _attention_target()
	if burrowed:
		burrow_t -= dt
		var to_g: Vector2 = burrow_goal - pos
		if to_g.length() > 2.0:
			_move_step(to_g.limit_length(routine_speed * 0.90 * dt), false)
			facing = to_g.angle()
		if burrow_t <= 0.0:
			burrowed = false
			_emit_sfx("burrow_beetle_surface")
		return

	match state:
		State.ROUTINE:
			flipped = false
			_step_routine(dt)
			if _sees_target(target_pos):
				_enter_notice()
		State.NOTICE:
			_face_point(target_pos, 3.8, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.18 * _assist_tell_scale():
				_face_point(target_pos, 2.8, dt)
				charge_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				flipped = false
				_release_token()
				cooldown = 0.55
				state = State.POSITION
		State.RETURN:
			flipped = false
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.32
	alert_t = 0.8
	lost_t = 0.0
	_emit_sfx("burrow_beetle_notice")


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = waypoints[wp_i]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		wp_i = (wp_i + 1) % waypoints.size()
		pause_t = 0.75
		return
	facing = to_w.angle()
	_move_step(to_w.limit_length(routine_speed * 0.78 * dt), false)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.0, dt)
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

	if is_lead and cooldown <= 0.0 and dist <= CHARGE_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		charge_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = charge_dir.angle()
		_emit_attack_started()
		_emit_sfx("burrow_beetle_tell")
		return

	var spd: float = routine_speed * 0.80
	if dist > CHARGE_RANGE * 0.72:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
		_move_step(perp * spd * 0.55 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = CHARGE_TIME
	charge_hit = false
	_emit_sfx("burrow_beetle_charge")


func _step_commit(dt: float) -> void:
	var prev_p: Vector2 = pos
	var want: Vector2 = charge_dir * CHARGE_SPEED * dt
	_move_step(want, false)
	var moved: float = pos.distance_to(prev_p)
	var hit_wall: bool = moved < want.length() * 0.35 and want.length() > 1.0
	var hit_plant_wall: bool = _hit_grown_plant_wall()
	if hit_wall or hit_plant_wall:
		flipped = true
		_release_token()
		state = State.STAGGER
		state_timer = FLIP_STAGGER_TIME
		LxDamageFx.boss_impact(pos, 0.12, 54.0, 58.0, 50.0, 1.22, 0.25)
		_emit_sfx("burrow_beetle_flip")
		return
	if not charge_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= CHARGE_HIT_R:
		charge_hit = true
		_emit_player_hit(charge_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _hit_grown_plant_wall() -> bool:
	var ctx: Node = world_ctx if world_ctx != null else Lx.world
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (ctx.call("get_interactables") as Array):
		if it_v is Object and is_instance_valid(it_v as Object):
			var it: Object = it_v as Object
			if str(it.get("kind")) == "light_plant" and it.has_method("is_solid") and bool(it.call("is_solid")):
				var ip: Vector2 = it.get("pos") as Vector2 if it.get("pos") is Vector2 else Vector2.ZERO
				if ip.distance_to(pos) <= body_radius + 14.0:
					return true
	return false


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	return home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 20.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _sees_target(target_pos: Vector2) -> bool:
	return (_has_player() or _is_lured()) and pos.distance_to(target_pos) <= notice_radius


func _has_active_shield() -> bool:
	return is_reflective()


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _body_color() -> Color:
	return PAL["teal"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if burrowed:
		draw_arc(c + Vector2(0.0, 2.0), body_radius + 1.5, PI, TAU, 12, PAL["mauve"] as Color, 2.5)
		draw_arc(c + Vector2(0.0, 2.0), body_radius - 1.0, PI, TAU, 10, PAL["dusk"] as Color, 1.5)
		return
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked: bool = state_timer <= 0.18 * _assist_tell_scale()
		var len_c: float = CHARGE_SPEED * CHARGE_TIME
		var tip: Vector2 = (c + charge_dir * len_c).round()
		var perp := Vector2(-charge_dir.y, charge_dir.x)
		var lc: Color = (PAL["coral"] if locked else PAL["gold"]) as Color
		var fred: bool = LxHudFx.flash_reduced()
		draw_colored_polygon(
			PackedVector2Array([
				(c - perp * 8.0).round(), (tip - perp * 8.0).round(),
				(tip + perp * 8.0).round(), (c + perp * 8.0).round(),
			]),
			Color(lc, lerpf(0.08, 0.16 if fred else 0.22, prog)),
		)
		draw_line(c, tip, PAL["cream"] as Color if locked else lc, 1.4)
		draw_line((tip - charge_dir * 4.0 + perp * 3.5).round(), tip, lc, 1.2)
		draw_line((tip - charge_dir * 4.0 - perp * 3.5).round(), tip, lc, 1.2)
	elif state == State.COMMIT:
		draw_line(c, (c - charge_dir * 16.0).round(), PAL["ice"] as Color, 2.0)
		draw_line(c, (c - charge_dir * 10.0).round(), PAL["cream"] as Color, 1.2)
	elif is_reflective():
		# Mirror-carapace glint dot
		var glint_p: Vector2 = (c + Vector2(-2.0, -body_radius)).round()
		draw_rect(Rect2(glint_p, Vector2(2.0, 2.0)), PAL["ice"] as Color)
