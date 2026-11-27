class_name LxFalseLanternBrain
extends LxEnemyBrain
## False Lantern (Island 3): Light-stealing flytrap mimic.
## Impersonates an unlit lantern post with an off-beat 0.9 Hz lime pulse (vs 1.4 Hz gold).
## Untested thrown lantern gets swallowed for 2.5 s; 1 test Bolt unmasks & opens its
## flytrap maw vulnerable (1.2 s stagger); lunges at close range (0.46s tell, 0.26s commit, 1.15s recover).

const AMBUSH_RADIUS: float = 72.0
const LUNGE_RANGE: float = 92.0
const LUNGE_SPEED: float = 225.0
const LUNGE_TIME: float = 0.26
const LUNGE_HIT_R: float = 14.0
const UNMASK_STAGGER: float = 1.20
const SWALLOW_TIME: float = 2.50
const POST_COOLDOWN: float = 1.00

var disguised: bool = true
var swallowed_lantern: bool = false
var swallow_t: float = 0.0
var _lantern_ref: Object = null
var lunge_dir: Vector2 = Vector2.RIGHT
var lunge_hit: bool = false


func _init() -> void:
	kind = "false_lantern"
	island_id = 3
	max_hp = 3.2
	hp = 3.2
	body_radius = 6.0
	routine_speed = 42.0
	leash_radius = 152.0
	notice_radius = 112.0
	tell_time = 0.46
	recover_time = 1.15
	give_up_time = 1.8
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	disguised = true
	swallowed_lantern = false
	swallow_t = 0.0
	_lantern_ref = null
	lunge_dir = Vector2.from_angle(facing)
	lunge_hit = false


## Called by LxLantern._sweep_hits when Wick throws an untested lantern right into the mimic!
func try_catch_lantern(lantern_obj: Object = null) -> bool:
	if state == State.DEAD or state == State.STAGGER or swallowed_lantern or not disguised:
		return false
	disguised = false
	swallowed_lantern = true
	swallow_t = SWALLOW_TIME
	_lantern_ref = lantern_obj
	_release_token()
	state = State.POSITION
	if lantern_obj != null and is_instance_valid(lantern_obj) and lantern_obj.has_method("on_grabbed"):
		lantern_obj.call("on_grabbed", self)
	elif Lx.events != null:
		Lx.events.lantern_stolen.emit(self, pos)
	_emit_sfx("false_lantern_swallow")
	return true


func _spit_lantern() -> void:
	if not swallowed_lantern:
		return
	swallowed_lantern = false
	swallow_t = 0.0
	var drop_p: Vector2 = pos + Vector2.from_angle(facing) * 14.0
	if _lantern_ref != null and is_instance_valid(_lantern_ref) and _lantern_ref.has_method("on_dropped"):
		_lantern_ref.call("on_dropped", drop_p)
	elif Lx.events != null:
		Lx.events.lantern_dropped.emit(drop_p)
	_lantern_ref = null


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_burn: bool = src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or bool(h["pierce"])
	var is_heavy: bool = bool(h["stagger"]) or is_burn
	var rel: Vector2 = orig - pos

	# Untested Throw while disguised gets swallowed instead of damaging!
	if src == LxHit.SOURCE_THROW and disguised and not swallowed_lantern:
		var lan_o: Object = Lx.player.lantern if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
		if try_catch_lantern(lan_o):
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED

	# 1 test Bolt while disguised unmasks the mimic & pops its maw wide open!
	if disguised and (src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM):
		disguised = false
		_release_token()
		hp -= dmg * 1.25
		flash_t = 0.18
		_emit_sfx("false_lantern_unmask")
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		state = State.STAGGER
		state_timer = UNMASK_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	disguised = false
	if swallowed_lantern:
		_spit_lantern()

	var maw_open: bool = state == State.STAGGER or state == State.RECOVER or is_burn
	if is_burn:
		dmg *= 1.50
	elif maw_open:
		dmg *= 1.40
	hp -= dmg
	flash_t = 0.16 if (maw_open or is_heavy) else 0.09
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 34.0)

	if hp <= 0.001:
		_spit_lantern()
		opened_kill = maw_open
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 0.70 if is_burn else 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if maw_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _step_brain(dt: float) -> void:
	if swallowed_lantern:
		swallow_t -= dt
		if swallow_t <= 0.0:
			_spit_lantern()
	var target_pos: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			disguised = true
			if _has_player() and pos.distance_to(target_pos) <= AMBUSH_RADIUS:
				_enter_notice()
		State.NOTICE:
			disguised = false
			_face_point(target_pos, 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			disguised = false
			_step_position(dt, target_pos)
		State.TELL:
			if state_timer > 0.16 * _assist_tell_scale():
				_face_point(target_pos, 3.4, dt)
				lunge_dir = Vector2.from_angle(facing)
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
				_release_token()
				cooldown = 0.45
				state = State.POSITION
		State.RETURN:
			_spit_lantern()
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				disguised = true
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * dt), false)


func _enter_notice() -> void:
	disguised = false
	state = State.NOTICE
	state_timer = 0.26
	alert_t = 0.8
	lost_t = 0.0
	_emit_sfx("false_lantern_unmask")


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	_face_point(target_pos, 3.6, dt)
	if not _has_player() or target_pos.distance_to(home) > leash_radius + 16.0:
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

	if is_lead and cooldown <= 0.0 and dist <= LUNGE_RANGE and _is_on_screen() \
			and _has_clear_view(pos, target_pos) and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		lunge_dir = to_t.normalized() if dist > 0.01 else Vector2.from_angle(facing)
		facing = lunge_dir.angle()
		_emit_attack_started()
		_emit_sfx("false_lantern_tell")
		return

	var spd: float = routine_speed * 0.80
	if dist > LUNGE_RANGE * 0.72:
		_move_step(to_t.normalized() * spd * dt, false)
	else:
		var perp: Vector2 = Vector2(-to_t.y, to_t.x).normalized() * (1.0 if slot % 2 == 0 else -1.0)
		_move_step(perp * spd * 0.65 * dt, false)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = LUNGE_TIME
	lunge_hit = false
	_emit_sfx("false_lantern_lunge")


func _step_commit(dt: float) -> void:
	_move_step(lunge_dir * LUNGE_SPEED * dt, false)
	if not lunge_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= LUNGE_HIT_R:
		lunge_hit = true
		_emit_player_hit(lunge_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length() > 0.01:
		_turn_toward(to_p.angle(), rate, dt)


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = LxHudFx.flash_reduced()
	if disguised and state == State.ROUTINE:
		# Tell-tale off-beat 0.9 Hz pale LIME pulse (real lamps pulse 1.4 Hz gold!)
		var pulse: float = 0.5 + 0.5 * sin(anim_t * TAU * 0.9)
		if fred:
			pulse = 0.7
		draw_circle(c + Vector2(0.0, -10.0), 4.5 + pulse * 2.5, Color(PAL["lime"] as Color, 0.28 * pulse))
		return
	if swallowed_lantern:
		draw_circle(c + Vector2(0.0, -8.0), 5.0, Color(PAL["gold"] as Color, 0.55))
		draw_arc(c + Vector2(0.0, -8.0), 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(swallow_t / SWALLOW_TIME, 0.0, 1.0), 16, PAL["gold"] as Color, 1.0)
	if state == State.TELL:
		var reach: float = LUNGE_SPEED * LUNGE_TIME
		var tip: Vector2 = (c + lunge_dir * reach).round()
		var locked: bool = state_timer <= 0.16 * _assist_tell_scale()
		draw_line(c, tip, PAL["void"] as Color, 4.0 if locked else 3.0)
		draw_line(c, tip, PAL["cream"] as Color if locked else PAL["coral"] as Color, 2.0 if locked else 1.0)
		draw_circle(tip, 4.0, PAL["void"] as Color)
		draw_circle(tip, 3.0, PAL["coral"] as Color)
	elif state == State.COMMIT:
		draw_line(c, (c - lunge_dir * 14.0).round(), PAL["void"] as Color, 5.0)
		draw_line(c, (c - lunge_dir * 14.0).round(), PAL["coral"] as Color, 3.0)
