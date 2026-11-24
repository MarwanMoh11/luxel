class_name LxMagnetGolemBrain
extends LxEnemyBrain
## Magnet Golem (Island 6, Ashen Kiln — Lantern Disrupter / Puzzle Catalyst).
## Horseshoe-crowned iron golem whose magnetic pulse pulls Wick's thrown/hung lantern
## straight to its chest (110px radius, even across grates — recall 440 px/s always overrides!).
## Counterplay: Lance/Sunflare/Zip cracks horseshoe magnet (disables pull 3.5s + stagger),
## Skip/Prism banks around grates (1.25x); in puzzles, feed lantern to yank it onto plates/hooks!

const ARMOUR_MAX_DEFAULT: float = 2.0
const PULL_RADIUS: float = 110.0
const PULL_SPEED: float = 220.0
const SHOCK_RADIUS: float = 44.0
const COMMIT_TIME: float = 0.45
const MAGNET_CRACK_SECS: float = 3.5
const LANTERN_SLAM_LIMIT: float = 1.2
const GUARD_HOME_CAP: float = 68.0

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var armour_intact: bool = true
var armour_max: float = ARMOUR_MAX_DEFAULT
var armour_hp: float = ARMOUR_MAX_DEFAULT
var magnet_cracked_t: float = 0.0
var _lantern_stuck_t: float = 0.0
var _shock_hit: bool = false


func _init() -> void:
	kind = "magnet_golem"
	island_id = 6
	max_hp = 4.5
	hp = 4.5
	body_radius = 7.5
	routine_speed = 24.0
	leash_radius = 140.0
	notice_radius = 130.0
	tell_time = 0.54
	recover_time = 1.25
	give_up_time = 1.5
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pt_v: Variant in (raw_r as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				route.append(pt)
	route_i = 0
	pause_t = 0.0
	armour_max = maxf(1.0, float(spec.get("armour_hp", ARMOUR_MAX_DEFAULT)))
	armour_hp = armour_max
	armour_intact = true
	magnet_cracked_t = 0.0
	_lantern_stuck_t = 0.0
	_shock_hit = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_ZIP
	var is_prism: bool = src == LxHit.SOURCE_PRISM
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = (h["origin"] as Vector2) - pos

	var just_cracked: bool = false
	if cracks:
		magnet_cracked_t = MAGNET_CRACK_SECS
		_lantern_stuck_t = 0.0
		if armour_intact:
			_crack_armour()
			just_cracked = true
		else:
			_emit_sfx("magma_crack")
			just_cracked = true
	elif is_prism or bool(h["pierce"]):
		dmg *= 1.25
		if armour_intact:
			armour_hp -= maxf(wear, 1.2)
			if armour_hp <= 0.001:
				_crack_armour()
				just_cracked = true
	elif armour_intact:
		clank_t = 0.14
		dmg *= 0.45
		armour_hp -= wear if is_heavy else wear * 0.4
		if armour_hp <= 0.001:
			_crack_armour()
			just_cracked = true
		else:
			_emit_sfx("shield_clang")

	var is_opening: bool = (not armour_intact) or magnet_cracked_t > 0.0 or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.16 if (just_cracked or is_heavy) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (70.0 if (just_cracked or not armour_intact) else 18.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if just_cracked:
		_release_token()
		state = State.STAGGER
		state_timer = 1.45 if src == LxHit.SOURCE_SUNFLARE else 1.30
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if is_heavy and not armour_intact:
		_release_token()
		state = State.STAGGER
		state_timer = 0.60
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _crack_armour() -> void:
	armour_intact = false
	armour_hp = 0.0
	magnet_cracked_t = MAGNET_CRACK_SECS
	LxDamageFx.boss_impact(pos, 0.14, 64.0, 72.0, 68.0, 1.32, 0.30, "sky")
	_emit_sfx("magma_crack")


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["armour_intact"] = armour_intact
	d["magnet_cracked_t"] = magnet_cracked_t
	return d


func _step_brain(dt: float) -> void:
	if magnet_cracked_t > 0.0:
		magnet_cracked_t = maxf(0.0, magnet_cracked_t - dt)
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 3.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01:
				_turn_toward(to_t.angle(), 2.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = COMMIT_TIME
				_shock_hit = false
				_emit_sfx("coupler_snap")
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.90
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 2.5:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
				if _sees_target() and _attention_target().distance_to(home) <= leash_radius:
					_enter_notice()


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_move_step((home - pos).limit_length(routine_speed * 0.80 * dt), false)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 2.5:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.90
		return
	var to_wp: Vector2 = wp - pos
	_turn_toward(to_wp.angle(), 2.6, dt)
	_move_step(to_wp.limit_length(routine_speed * 0.82 * dt), false)


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

	var target: Vector2 = _attention_target()
	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 2.8, dt)

	var lantern_in_pull: bool = magnet_cracked_t <= 0.0 and _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= PULL_RADIUS
	var can_attack: bool = dist <= PULL_RADIUS or lantern_in_pull
	var is_lead: bool = director == null or director.lead_enemy == self or director.lead_enemy == null
	state = State.POSITION if is_lead else State.WAIT_TOKEN

	if is_lead and cooldown <= 0.0 and can_attack and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("magnet_hum")
		return

	var dest: Vector2 = target - (to_t / maxf(dist, 0.01)) * 36.0
	var cap: float = minf(GUARD_HOME_CAP, maxf(0.0, leash_radius - 2.0))
	if dest.distance_to(home) > cap:
		dest = home + (dest - home).normalized() * cap
	if dest.distance_to(pos) > 3.0:
		_move_step((dest - pos).limit_length(routine_speed * 0.86 * dt), false)


func _step_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	if magnet_cracked_t <= 0.0:
		_pull_thrown_lantern(dt)
	if not _shock_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= SHOCK_RADIUS:
		_shock_hit = true
		var push: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.from_angle(facing)
		_emit_player_hit(push, attack_damage)
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, recover_time)
		last_recover_duration = state_timer


func _pull_thrown_lantern(dt: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if not (lan_v is Object and is_instance_valid(lan_v as Object)):
		return
	var lan: Object = lan_v as Object
	var st: int = int(lan.get("state"))
	# Only pull FLYING (1) or HANGING (2); RECALLING (3) at 440 px/s ALWAYS wins!
	if st != 1 and st != 2:
		_lantern_stuck_t = 0.0
		return
	var lp_v: Variant = lan.get("pos")
	if not (lp_v is Vector2):
		return
	var lp: Vector2 = lp_v as Vector2
	var to_me: Vector2 = pos - lp
	var dist: float = to_me.length()
	if dist > PULL_RADIUS:
		_lantern_stuck_t = 0.0
		return
	if dist > 10.0:
		var pulled: Vector2 = lp + (to_me / dist) * minf(PULL_SPEED * dt, dist - 8.0)
		lan.set("pos", pulled)
		if lan is Node2D:
			(lan as Node2D).global_position = pulled.round()
	if dist <= 16.0:
		_lantern_stuck_t += dt
		if _lantern_stuck_t >= LANTERN_SLAM_LIMIT:
			_lantern_stuck_t = 0.0
			if lan.has_method("on_struck"):
				lan.call("on_struck")
			elif Lx.events != null:
				Lx.events.lantern_struck.emit(lp)


func _sees_target() -> bool:
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= PULL_RADIUS:
		return true
	if not _has_player():
		return false
	return pos.distance_to(_get_wick_pos()) <= notice_radius and _has_clear_view(pos, _get_wick_pos())


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = 0.30
	alert_t = 0.75
	lost_t = 0.0
	_emit_sfx("warden_alert")


func _body_color() -> Color:
	return (PAL["mauve"] as Color) if armour_intact else (PAL["sky"] as Color)


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 2.0, 1.5, armour_hp, armour_max)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		if magnet_cracked_t <= 0.0:
			draw_arc(c, PULL_RADIUS, 0.0, TAU, 28, Color(PAL["sky"] as Color, 0.35 + 0.35 * prog), 1.0)
			draw_arc(c, lerpf(PULL_RADIUS, 16.0, prog), 0.0, TAU, 24, PAL["ice"] as Color, 1.3)
		draw_arc(c, SHOCK_RADIUS, 0.0, TAU, 20, (PAL["cream"] if prog > 0.72 else PAL["coral"]) as Color, 1.4)
	elif state == State.COMMIT:
		var prog: float = 1.0 - clampf(state_timer / COMMIT_TIME, 0.0, 1.0)
		if magnet_cracked_t <= 0.0:
			var r_in: float = lerpf(PULL_RADIUS, 14.0, fmod(prog * 2.0, 1.0))
			draw_arc(c, r_in, 0.0, TAU, 24, PAL["sky"] as Color, 1.6)
			if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= PULL_RADIUS:
				draw_line(c, (_get_lantern_pos() - pos + off).round(), PAL["ice"] as Color, 1.5)
		draw_arc(c, lerpf(10.0, SHOCK_RADIUS, prog), 0.0, TAU, 20, PAL["gold"] as Color, 1.8)
