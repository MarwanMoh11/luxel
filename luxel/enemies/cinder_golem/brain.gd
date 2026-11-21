class_name LxCinderGolemBrain
extends LxWardenBrain
## Cinder Golem (Island 6, Ashen Kiln).
## Slow heavy-armoured patrol (routine_speed = 24.0, HP 6.0).
## Heavy armour resists normal hits to 25% until cracked by Sunflare (cracks_armour) or heavy blows.
## Stomp tell 0.65s (attack_damage = 1.5 > 1 heart), shockwave commit (source = "shockwave"),
## long recovery 1.55s.

signal armour_cracked_sig(source: LxEnemyBrain, at_pos: Vector2)

const ARMOUR_MAX_DEFAULT: float = 4.0
const ARMOUR_RES_MULT: float = 0.25
const STOMP_TRIGGER_R: float = 72.0
const STOMP_COMMIT_TIME: float = 0.30
const STOMP_START_R: float = 10.0
const STOMP_MAX_R: float = 64.0
const STOMP_BAND: float = 10.0
const GUARD_HOME_CAP: float = 64.0

var armour_intact: bool = true
var armour_max: float = ARMOUR_MAX_DEFAULT
var armour_hp: float = ARMOUR_MAX_DEFAULT
var stomp_progress: float = 0.0
var stomp_hit: bool = false


func _init() -> void:
	super._init()
	kind = "cinder_golem"
	max_hp = 6.0
	hp = 6.0
	body_radius = 8.0
	routine_speed = 24.0
	leash_radius = 128.0
	notice_radius = 118.0
	tell_time = 0.65
	recover_time = 1.55
	give_up_time = 1.1
	attack_damage = 1.5
	shield_max = 0.0
	shield_hp = 0.0
	reach = STOMP_TRIGGER_R
	lunge_reach = STOMP_TRIGGER_R
	shard_drop = 6


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	shield_max = 0.0
	shield_hp = 0.0
	armour_max = maxf(1.0, float(spec.get("armour_hp", ARMOUR_MAX_DEFAULT)))
	armour_hp = armour_max
	armour_intact = true
	stomp_progress = 0.0
	stomp_hit = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_heavy: bool = bool(h["stagger"])
	var cracks: bool = bool(h["cracks_armour"])
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = orig - pos

	if is_heavy and state == State.STAGGER and not cracks:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var just_cracked: bool = false
	if armour_intact:
		if cracks:
			_crack_armour()
			just_cracked = true
		else:
			clank_t = 0.14
			dmg *= ARMOUR_RES_MULT
			var armour_wear: float = wear if (is_heavy or wear >= 1.5) else wear * 0.25
			armour_hp -= armour_wear
			if armour_hp <= 0.001:
				_crack_armour()
				just_cracked = true
			else:
				_emit_sfx("golem_armour_clank")

	var is_opening: bool = (not armour_intact) or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	wary = true
	flash_t = 0.16 if (is_heavy or just_cracked) else 0.08
	if rel.length() > 0.01:
		var k_spd: float = (80.0 if not armour_intact else 20.0) if is_heavy else 10.0
		knock = -rel.normalized() * k_spd

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if just_cracked:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else 0.90
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy and not armour_intact:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["armour_intact"] = armour_intact
	d["armour_hp"] = armour_hp
	return d


func _crack_armour() -> void:
	armour_intact = false
	armour_hp = 0.0
	armour_cracked_sig.emit(self, pos)
	_emit_sfx("golem_armour_crack")


func _step_guard(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), TURN_GUARD * 0.75, dt)

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

	# Keep slow golem anchored close to home so return-home stays well inside 6s
	var dest: Vector2 = target_pos - (to_t / maxf(dist, 0.01)) * 28.0
	var cap: float = minf(GUARD_HOME_CAP, maxf(0.0, leash_radius - 2.0))
	if dest.distance_to(home) > cap:
		dest = home + (dest - home).normalized() * cap
	if dest.distance_to(pos) > 3.0:
		_move_step((dest - pos).limit_length(routine_speed * 0.85 * dt), false)


func _try_start_attack(_target_pos: Vector2, dist: float) -> bool:
	if dist <= STOMP_TRIGGER_R and _claim_token():
		state = State.TELL
		lunge_attack = false
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		stomp_progress = 0.0
		stomp_hit = false
		_emit_attack_started()
		_emit_sfx("golem_stomp_tell")
		return true
	return false


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = STOMP_COMMIT_TIME
	stomp_progress = 0.0
	stomp_hit = false
	_emit_sfx("golem_stomp_shockwave")


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	stomp_progress = 1.0 - clampf(state_timer / STOMP_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(STOMP_START_R, STOMP_MAX_R, stomp_progress)
	if not stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= STOMP_BAND:
			stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir, attack_damage)
	kind = prev_kind


func _step_brain(dt: float) -> void:
	var was_recover: bool = state == State.RECOVER
	super._step_brain(dt)
	# If Wick already left leash during our long stomp recovery, head straight home
	if was_recover and state == State.POSITION:
		var wp: Vector2 = _get_wick_pos()
		if not _is_lured() and (not _has_player() or wp.distance_to(home) > leash_radius + 16.0):
			_release_token()
			state = State.RETURN
			lost_t = 0.0


func _on_stagger_end(target_pos: Vector2) -> void:
	# Cinder Golem never counter-swings; resumes deliberate guard
	_release_token()
	state = State.POSITION
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()


func _walk_toward(dest: Vector2, dt: float) -> void:
	var to_d: Vector2 = dest - pos
	if to_d.length() < 0.01:
		return
	_turn_toward(to_d.angle(), TURN_PATROL * 1.4, dt)
	var spd: float = minf(WALK_SPEED, routine_speed)
	_move_step(to_d.limit_length(spd * dt), false)


func _has_active_shield() -> bool:
	return false


func _body_color() -> Color:
	return (PAL["stone"] as Color) if armour_intact else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	if armour_intact:
		var plate_col: Color = (PAL["cream"] as Color) if clank_t > 0.0 else (PAL["dusk"] as Color)
		draw_rect(Rect2(off - Vector2(body_radius + 1.0, body_radius + 1.0), Vector2((body_radius + 1.0) * 2.0, (body_radius + 1.0) * 2.0)), plate_col, false, 2.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var r: float = lerpf(STOMP_MAX_R, STOMP_START_R + 4.0, prog)
		draw_arc(off, r, 0.0, TAU, 24, PAL["apricot"] as Color, 1.5)
	elif state == State.COMMIT:
		var ring_r: float = lerpf(STOMP_START_R, STOMP_MAX_R, stomp_progress)
		draw_arc(off, ring_r, 0.0, TAU, 28, PAL["coral"] as Color, 3.0)
		draw_arc(off, maxf(2.0, ring_r - 2.0), 0.0, TAU, 24, PAL["gold"] as Color, 1.5)
