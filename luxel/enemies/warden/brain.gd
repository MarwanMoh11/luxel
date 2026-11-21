class_name LxWardenBrain
extends LxEnemyBrain
## Parasol Toad Warden brain at full Act I parity.
## Breakable directional shield, parasol ricochet every 3rd blocked bolt, LURE rule,
## gap-closing hop-lunge, counter-swing on stagger punishment, and strict no-pursuit pacing.

signal ricochet_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)
signal shield_broken(source: LxEnemyBrain, at_pos: Vector2)
signal shield_reformed(source: LxEnemyBrain, at_pos: Vector2)

const WALK_SPEED: float = 34.0
const GUARD_STEP_RATIO: float = 0.88 # Strictly <= routine_speed so 7.4 no-pursuit holds.
const TURN_PATROL: float = 3.2
const TURN_GUARD: float = 2.8
const TURN_WINDUP: float = 1.65
const SIGHT_HALF: float = 0.95
const HEAR_R: float = 34.0
const LIGHT_R: float = 135.0
const NOTICE_TIME: float = 0.36
const RALLY_R: float = 128.0
const RALLY_DELAY: float = 0.28
const RING_R: float = 50.0
const RING_OFFSETS: Array[float] = [0.0, 0.7, -0.7]

const DEFAULT_REACH: float = 34.0
const DEFAULT_LUNGE_REACH: float = 92.0
const DEFAULT_WINDUP: float = 0.48
const DEFAULT_LUNGE_WINDUP: float = 0.56
const SWING_TIME: float = 0.19
const LUNGE_SWING_TIME: float = 0.24
const SWING_LUNGE_SPEED: float = 175.0
const GAP_LUNGE_SPEED: float = 285.0
const DEFAULT_SWING_R: float = 26.0
const DEFAULT_SWING_ARC: float = 1.15
const DEFAULT_RECOVER: float = 1.15
const DEFAULT_BREAK_OPEN: float = 1.25
const DEFAULT_STAGGER: float = 0.45
const KNOCK_SPEED: float = 135.0
const BLOCK_HALF: float = 1.05
const SNEAK_MULT: float = 2.0
const COUNTER_R: float = 44.0
const COUNTER_TELL: float = 0.28
const COUNTER_COOLDOWN: float = 0.85
const RICOCHET_NEED: int = 3

var route: Array[Vector2] = []
var route_i: int = 0
var home_facing: float = PI
var pause_t: float = 0.0
var look_t: float = 0.0
var step_clock: float = 0.0

var shield_max: float = 1.75
var shield_hp: float = 1.75
var shield_gone_duration: float = 4.8
var shield_gone_t: float = 0.0
var break_open_time: float = DEFAULT_BREAK_OPEN
var stagger_duration: float = DEFAULT_STAGGER
var reach: float = DEFAULT_REACH
var lunge_reach: float = DEFAULT_LUNGE_REACH
var lunge_tell_time: float = DEFAULT_LUNGE_WINDUP
var swing_r: float = DEFAULT_SWING_R
var swing_arc: float = DEFAULT_SWING_ARC

var wary: bool = false
var lunge_attack: bool = false
var deflect_charge: int = 0
var swing_dir: Vector2 = Vector2.RIGHT
var swing_hit: bool = false
var swings_count: int = 0


func _init() -> void:
	kind = "warden"
	max_hp = 4.0
	hp = 4.0
	body_radius = 5.0
	routine_speed = 36.0
	leash_radius = 158.0
	notice_radius = 120.0
	tell_time = DEFAULT_WINDUP
	recover_time = DEFAULT_RECOVER
	give_up_time = 2.2
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	if data != null and data.shield_hp > 0.0:
		shield_max = data.shield_hp
		shield_gone_duration = data.shield_gone_time
	if spec.has("shield_hp"):
		shield_max = maxf(0.0, float(spec["shield_hp"]))
	if spec.has("shield_gone_time"):
		shield_gone_duration = maxf(0.5, float(spec["shield_gone_time"]))
	shield_hp = shield_max
	shield_gone_t = 0.0
	wary = false
	lunge_attack = false
	deflect_charge = 0
	swing_hit = false
	swings_count = 0
	pause_t = 0.0
	look_t = 0.0
	step_clock = 0.0

	route.clear()
	var raw_route: Variant = spec.get("route", [])
	if raw_route is Array:
		for pt_v: Variant in (raw_route as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 1.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 1.0)
				route.append(pt)
	route_i = 0
	if not spec.has("facing") and not route.is_empty() and route[0].distance_to(home) > 1.0:
		facing = (route[0] - home).angle()
	home_facing = facing


func distance_to_attention_target() -> float:
	return pos.distance_to(_attention_target())


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if _is_hit_invulnerable():
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_heavy: bool = bool(h["stagger"])
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = orig - pos

	# Front parasol shield block check
	if _has_active_shield() and not pierce and not cracks and rel.length() > 0.01 \
			and absf(angle_difference(facing, rel.angle())) < BLOCK_HALF:
		clank_t = 0.14
		var is_bolt: bool = (src == "bolt" or src == "prism_bolt")
		if is_bolt:
			cooldown = maxf(0.0, cooldown - 0.14)
			deflect_charge += 1
		if _wear_shield(wear):
			deflect_charge = 0
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		if is_bolt and deflect_charge >= RICOCHET_NEED:
			deflect_charge = 0
			var r_dir: Vector2 = rel.normalized()
			ricochet_fired.emit(pos, r_dir, self)
			_emit_sfx("warden_deflect")
			if world_ctx != null and world_ctx.has_method("on_enemy_ricochet"):
				world_ctx.call("on_enemy_ricochet", self, pos, r_dir)
		else:
			_emit_sfx("warden_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	# Already staggered: heavy blows glance (no stunlock), bolts still chip
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = (state == State.RECOVER or state == State.STAGGER or state == State.ROUTINE) \
			or shield_gone_t > 0.0 or pierce or cracks
	if state == State.ROUTINE and is_heavy:
		dmg *= SNEAK_MULT

	hp -= dmg
	wary = true
	flash_t = 0.15 if is_heavy else 0.07
	if rel.length() > 0.01:
		var k_spd: float = KNOCK_SPEED if is_heavy else 25.0
		knock = (-rel.normalized() * k_spd) if is_heavy else (knock - rel.normalized() * k_spd)

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if _on_damaged_alive(hit):
		_emit_enemy_hit(hit, HitResult.OPENED if is_heavy else HitResult.CHIPPED)
		return HitResult.OPENED if is_heavy else HitResult.CHIPPED

	if is_heavy:
		_release_token()
		if director != null:
			director.rally_nearby(self, RALLY_R, RALLY_DELAY)
		lunge_attack = false
		is_counter_attack = false
		state = State.STAGGER
		state_timer = 1.6 if src == "sunflare" else stagger_duration
		alert_t = 0.0
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _wear_shield(amount: float) -> bool:
	if shield_max <= 0.001:
		return false
	shield_hp -= maxf(0.0, amount)
	if shield_hp > 0.001:
		return false
	shield_hp = 0.0
	shield_gone_t = shield_gone_duration
	wary = true
	lunge_attack = false
	is_counter_attack = false
	_release_token()
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, break_open_time)
	last_recover_duration = state_timer
	shield_broken.emit(self, pos)
	_emit_sfx("warden_shield_break")
	return true


func _step_brain(dt: float) -> void:
	if shield_gone_t > 0.0:
		shield_gone_t -= dt
		if shield_gone_t <= 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max
			shield_reformed.emit(self, pos)
			_emit_sfx("warden_shield_reform")

	if rally_t > 0.0:
		rally_t -= dt
		if rally_t <= 0.0 and (state == State.ROUTINE or state == State.RETURN):
			_enter_notice()

	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			_step_notice(dt, target_pos)
		State.POSITION, State.WAIT_TOKEN:
			_step_guard(dt, target_pos)
		State.TELL:
			_step_tell(dt, target_pos)
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				is_counter_attack = false
				lunge_attack = false
				_release_token()
				state = State.POSITION
				cooldown = _post_recover_cooldown()
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_on_stagger_end(target_pos)
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.0:
			_walk_toward(home, dt)
			return
		look_t += dt
		_turn_toward(home_facing + sin(look_t * 0.7) * 1.1, TURN_PATROL * 0.4, dt)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) < 2.0:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.9
		return
	_walk_toward(wp, dt)


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.5, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.POSITION
		step_clock = 0.0


func _step_guard(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), TURN_GUARD, dt)

	# Give up & return home within 6s after losing Wick
	var wick_pos: Vector2 = _get_wick_pos()
	if not _is_lured() and (not _has_player() or wick_pos.distance_to(home) > leash_radius + 16.0):
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

	# Measured guard positioning (strictly <= routine_speed so 7.4 no-pursuit holds)
	var dest: Vector2
	if is_lead:
		dest = target_pos - to_t / maxf(dist, 0.01) * (reach - 8.0)
	else:
		var ring_off: float = RING_OFFSETS[slot % RING_OFFSETS.size()]
		var lead_p: Vector2 = director.lead_enemy.pos if (director != null and director.lead_enemy != null) else pos
		var ang: float = (lead_p - target_pos).angle() + PI + ring_off
		dest = target_pos + Vector2.from_angle(ang) * RING_R
	var cap: float = maxf(0.0, leash_radius - 1.0)
	if dest.distance_to(home) > cap:
		dest = home + (dest - home).normalized() * cap

	step_clock -= dt
	if step_clock <= 0.0:
		step_clock = 0.80
	if step_clock > 0.25 and dest.distance_to(pos) > 2.0:
		var spd: float = minf(routine_speed * GUARD_STEP_RATIO, routine_speed - 1.0)
		_move_step((dest - pos).limit_length(spd * dt), false)


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	var to_t: Vector2 = target_pos - pos
	var ang_ok: bool = dist < 0.01 or absf(angle_difference(facing, to_t.angle())) < 0.65
	if dist < reach and ang_ok and _claim_token():
		_begin_swing_tell(false)
		return true
	if dist >= reach and dist < lunge_reach and absf(angle_difference(facing, to_t.angle())) < 0.55 \
			and _has_clear_view(pos, target_pos) and _claim_token():
		_begin_swing_tell(true)
		return true
	return false


func _begin_swing_tell(is_lunge: bool) -> void:
	state = State.TELL
	lunge_attack = is_lunge
	is_counter_attack = false
	var base_t: float = _lunge_tell_base() if is_lunge else _swing_tell_base()
	last_tell_duration = _scaled_tell(base_t, false, attack_damage)
	state_timer = last_tell_duration
	_emit_attack_started()
	_emit_sfx("warden_lunge_tell" if is_lunge else "warden_windup")


func _step_tell(dt: float, target_pos: Vector2) -> void:
	var to_w: Vector2 = target_pos - pos
	if to_w.length() > 0.01 and state_timer > 0.16:
		_turn_toward(to_w.angle(), TURN_WINDUP * (1.25 if lunge_attack else 1.0), dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_enter_commit()


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LUNGE_SWING_TIME if lunge_attack else SWING_TIME
	swing_dir = Vector2.from_angle(facing)
	swing_hit = false
	swings_count += 1
	_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	var spd: float = GAP_LUNGE_SPEED if lunge_attack else SWING_LUNGE_SPEED
	_move_step(swing_dir * spd * dt, false)
	var wick_p: Vector2 = _get_wick_pos()
	var to_w: Vector2 = wick_p - pos
	var wd: float = to_w.length()
	if not swing_hit and wd < swing_r and (wd < 0.01 or absf(angle_difference(facing, to_w.angle())) < swing_arc):
		swing_hit = true
		_emit_player_hit(swing_dir)
	if _is_lured():
		var lan_p: Vector2 = _get_lantern_pos()
		var to_l: Vector2 = lan_p - pos
		var ld: float = to_l.length()
		if ld < swing_r and (ld < 0.01 or absf(angle_difference(facing, to_l.angle())) < swing_arc):
			if Lx.events != null:
				Lx.events.lantern_struck.emit(lan_p)
	state_timer -= dt
	if state_timer <= 0.0:
		lunge_attack = false
		if is_counter_attack:
			# Counter-swing leaves no recovery opening: shield back up immediately.
			_release_token()
			state = State.POSITION
			cooldown = COUNTER_COOLDOWN
			last_recover_duration = COUNTER_COOLDOWN
		else:
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, _swing_recover_duration())
			last_recover_duration = state_timer


func _on_stagger_end(target_pos: Vector2) -> void:
	var tw: Vector2 = _get_wick_pos() - pos
	if _has_player() and tw.length() < COUNTER_R and _is_on_screen() and _claim_token(true):
		state = State.TELL
		is_counter_attack = true
		lunge_attack = false
		last_tell_duration = _scaled_tell(COUNTER_TELL, true, attack_damage)
		state_timer = last_tell_duration
		if tw.length() > 0.01:
			facing = tw.angle()
		_emit_attack_started()
		_emit_sfx("warden_counter")
	else:
		_release_token()
		state = State.POSITION
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()


func _step_return(dt: float) -> void:
	lunge_attack = false
	deflect_charge = 0
	_walk_toward(home, dt)
	if pos.distance_to(home) < 2.5:
		pos = home
		state = State.ROUTINE
		wary = false
		route_i = 0
		pause_t = 0.6
	elif _sees_target() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()


func _walk_toward(dest: Vector2, dt: float) -> void:
	var to_d: Vector2 = dest - pos
	if to_d.length() < 0.01:
		return
	_turn_toward(to_d.angle(), TURN_PATROL, dt)
	if absf(angle_difference(facing, to_d.angle())) < 0.25:
		var spd: float = minf(WALK_SPEED, routine_speed)
		_move_step(to_d.limit_length(spd * dt), false)


func _sees_target() -> bool:
	var target_pos: Vector2 = _attention_target()
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if _is_lured():
		return dist < LIGHT_R and target_pos.distance_to(home) <= leash_radius + 30.0 and _has_clear_view(pos, target_pos)
	if not _has_player():
		return false
	if dist < HEAR_R:
		return true
	if dist > notice_radius or absf(angle_difference(facing, to_t.angle())) > SIGHT_HALF:
		return false
	return _has_clear_view(pos, target_pos)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.9
	lost_t = 0.0
	rally_t = -1.0
	if director != null:
		director.rally_nearby(self, RALLY_R, RALLY_DELAY)
	_emit_sfx("warden_notice")


func _is_lured() -> bool:
	if wary or not _is_lantern_out():
		return false
	return _get_lantern_pos().distance_to(home) <= leash_radius + 30.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


# --- Virtual hooks for Boss subclasses ------------------------------------------------------------------------

func _is_hit_invulnerable() -> bool:
	return false


func _on_damaged_alive(_hit: LxHit) -> bool:
	return false


func _swing_tell_base() -> float:
	return tell_time


func _lunge_tell_base() -> float:
	return lunge_tell_time


func _swing_recover_duration() -> float:
	return recover_time


func _post_recover_cooldown() -> float:
	return 0.95


func _has_active_shield() -> bool:
	var guarding: bool = state == State.NOTICE or state == State.POSITION \
			or state == State.WAIT_TOKEN or state == State.TELL
	return guarding and shield_max > 0.001 and shield_gone_t <= 0.0


func _body_color() -> Color:
	return PAL["jade"] as Color


func _shield_color() -> Color:
	return PAL["teal"] as Color
