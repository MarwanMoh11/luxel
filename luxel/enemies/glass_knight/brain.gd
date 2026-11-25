class_name LxGlassKnightBrain
extends LxEnemyBrain
## Island 7 Enemy: Glass Knight (Reflective Shield Tank, HP 5.0, Shield 2.5, Shards 7).
## Mirror buckler bounces raw frontal Yellow bolts straight back!
## Counters: Blue bolt shatters glass (1.4s stagger), Beam/Lance pierces, Throw behind = LURE,
## Black world turns glass shield rose-brittle to ANY hit!

signal ricochet_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)
signal shield_broken(source: LxEnemyBrain, at_pos: Vector2)

const NOTICE_TIME: float = 0.30
const THRUST_TELL: float = 0.50
const THRUST_COMMIT: float = 0.24
const THRUST_RECOVER: float = 1.20
const THRUST_SPEED: float = 180.0
const THRUST_REACH: float = 46.0
const THRUST_HIT_R: float = 30.0
const BLOCK_HALF: float = 1.12
const SHATTER_STAGGER: float = 1.40
const SHIELD_REFORM_TIME: float = 5.0

var shield_max: float = 2.5
var shield_hp: float = 2.5
var shield_gone_t: float = 0.0
var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var wary: bool = false
var _thrust_dir: Vector2 = Vector2.RIGHT
var _thrust_hit: bool = false
var _ping_flash_t: float = 0.0
var _ping_dir: Vector2 = Vector2.RIGHT


func _init() -> void:
	kind = "glass_knight"
	island_id = 7
	max_hp = 5.0
	hp = 5.0
	body_radius = 7.5
	routine_speed = 34.0
	leash_radius = 154.0
	notice_radius = 124.0
	tell_time = THRUST_TELL
	recover_time = THRUST_RECOVER
	give_up_time = 2.2
	shard_drop = 7
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	shield_max = float(spec.get("shield_hp", data.shield_hp if (data != null and data.shield_hp > 0.0) else 2.5))
	shield_hp = shield_max
	shield_gone_t = 0.0
	wary = false
	pause_t = 0.0
	_thrust_dir = Vector2.from_angle(facing)
	_thrust_hit = false
	_ping_flash_t = 0.0
	route.clear()
	var raw_route: Variant = spec.get("route", [])
	if raw_route is Array:
		for pt_v: Variant in (raw_route as Array):
			if pt_v is Vector2 or (pt_v is Array and (pt_v as Array).size() >= 2):
				var pt: Vector2 = _to_vec2(pt_v, home)
				if pt.distance_to(home) > leash_radius - 2.0:
					pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
				route.append(pt)
	route_i = 0


func _is_black_world() -> bool:
	if Lx.vars == null:
		return false
	var reg_id: String = Lx.state.region_id if Lx.state != null else ""
	if reg_id.is_empty() and Lx.world != null:
		reg_id = str(Lx.world.get("current_region_id"))
	return Lx.vars.eval("world_face==black", island_id, reg_id)


func _has_active_shield() -> bool:
	var guarding: bool = state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]
	return guarding and shield_max > 0.01 and shield_hp > 0.001 and shield_gone_t <= 0.0


func _shield_color() -> Color:
	return (PAL["rose"] if _is_black_world() else PAL["ice"]) as Color


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_blue: bool = hit.is_blue()
	var pierce: bool = bool(h["pierce"]) or src == LxHit.SOURCE_BEAM
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_SUNFLARE
	var is_heavy: bool = bool(h["stagger"]) or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]
	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < BLOCK_HALF

	if _has_active_shield() and front_hit:
		# Black world turns mirror shield rose-brittle to ANY hit! Blue bolts shatter glass instantly!
		if is_blue or _is_black_world() or cracks:
			_shatter_shield(hit)
			hp -= dmg * 1.15
			if hp <= 0.001:
				opened_kill = true
				_spawn_death_burst()
				_die(hit)
				return HitResult.KILLED
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		# Beam / Lance pierces straight through mirror shield!
		if not pierce:
			if src == LxHit.SOURCE_BOLT:
				# Raw Yellow bolt bounces straight back!
				clank_t = 0.16
				_ping_flash_t = 0.22
				_ping_dir = rel.normalized()
				ricochet_fired.emit(pos, _ping_dir, self)
				if world_ctx != null and world_ctx.has_method("on_enemy_ricochet"):
					world_ctx.call("on_enemy_ricochet", self, pos, _ping_dir)
				_emit_sfx("mirror_ping")
				if state == State.ROUTINE or state == State.RETURN:
					_enter_notice()
				_emit_enemy_hit(hit, HitResult.BLOCKED)
				return HitResult.BLOCKED
			# Heavy non-piercing frontal blow chips mirror shield wear
			shield_hp -= maxf(0.5, float(h["shield_wear"]))
			clank_t = 0.14
			if shield_hp <= 0.001:
				_shatter_shield(hit)
				_emit_enemy_hit(hit, HitResult.OPENED)
				return HitResult.OPENED
			_emit_sfx("crystal_clank")
			if state == State.ROUTINE or state == State.RETURN:
				_enter_notice()
			_emit_enemy_hit(hit, HitResult.BLOCKED)
			return HitResult.BLOCKED

	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_open: bool = shield_gone_t > 0.0 or pierce or cracks or state in [State.RECOVER, State.STAGGER, State.ROUTINE] or not front_hit
	if not front_hit and is_heavy:
		dmg *= 1.35
	hp -= dmg
	wary = true
	flash_t = 0.15 if (is_heavy or pierce) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 22.0)

	if hp <= 0.001:
		opened_kill = is_open
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy or pierce:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if src == LxHit.SOURCE_SUNFLARE else 0.55
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _shatter_shield(_hit: LxHit) -> void:
	shield_hp = 0.0
	shield_gone_t = SHIELD_REFORM_TIME
	wary = true
	_release_token()
	state = State.STAGGER
	state_timer = SHATTER_STAGGER
	last_recover_duration = SHATTER_STAGGER
	shield_broken.emit(self, pos)
	LxDamageFx.boss_impact(pos, 0.12, 56.0, 66.0, 54.0, 1.28, 0.28)
	_emit_sfx("glass_shatter")


func _step_brain(dt: float) -> void:
	_ping_flash_t = maxf(0.0, _ping_flash_t - dt)
	if shield_max > 0.01 and shield_gone_t > 0.0:
		shield_gone_t -= dt
		if shield_gone_t <= 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max
			_emit_sfx("shield_reform")

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt)
		State.TELL:
			_step_tell(dt)
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
				cooldown = 0.60
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			var to_h: Vector2 = home - pos
			_turn_toward(to_h.angle(), 3.2, dt)
			_move_step(to_h.limit_length(routine_speed * 0.85 * dt), false)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i]
	if pos.distance_to(wp) <= 3.0:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.8
		return
	var to_w: Vector2 = wp - pos
	_turn_toward(to_w.angle(), 3.2, dt)
	_move_step(to_w.limit_length(routine_speed * 0.88 * dt), false)


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

	var tgt: Vector2 = _attention_target()
	var to_t: Vector2 = tgt - pos
	var dist: float = to_t.length()
	if dist > 0.1:
		_turn_toward(to_t.angle(), 2.8, dt)
		if dist > THRUST_REACH - 8.0:
			_move_step((to_t / dist) * (routine_speed * 0.85) * dt, false)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= THRUST_REACH + 24.0 \
			and (dist < 0.1 or absf(angle_difference(facing, to_t.angle())) < 0.72) and _claim_token():
		_thrust_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _thrust_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(THRUST_TELL, false, attack_damage)
		state_timer = last_tell_duration
		_thrust_hit = false
		_emit_attack_started()
		_emit_sfx("warden_alert")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 and _has_attention_target():
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 2.2, dt)
			_thrust_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = THRUST_COMMIT
		_thrust_hit = false
		_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	_move_step(_thrust_dir * THRUST_SPEED * dt, false)
	if not _thrust_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		var to_w: Vector2 = wp - pos
		if to_w.length() <= THRUST_HIT_R and (to_w.length() < 0.1 or absf(angle_difference(facing, to_w.angle())) < 0.95):
			_thrust_hit = true
			_emit_player_hit(_thrust_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, THRUST_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		wary = false
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.4, dt)
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 26.0


func _has_attention_target() -> bool:
	return _has_player() or _is_lured()


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.78
	lost_t = 0.0
	_emit_sfx("warden_alert")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.10, 52.0, 58.0, 52.0, 1.26, 0.26)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(8):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 8.0))
			var col: Color = (PAL["ice"] if si % 2 == 0 else PAL["rose"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 36.0, 88.0, 0.30)


func _body_color() -> Color:
	return PAL["ice"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _ping_flash_t > 0.0:
		var p_frac: float = _ping_flash_t / 0.22
		draw_line(c, (c + _ping_dir * (26.0 * (1.2 - p_frac))).round(), PAL["gold"] as Color, 2.0)
		draw_line(c, (c + _ping_dir * (18.0 * (1.2 - p_frac))).round(), PAL["cream"] as Color, 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, _thrust_dir * (THRUST_SPEED * THRUST_COMMIT + 14.0), 10.0, prog, anim_t, "ice", "gold")
	elif state == State.COMMIT:
		draw_line(c, (c + _thrust_dir * 26.0).round(), PAL["ice"] as Color, 3.0)
		draw_line(c, (c + _thrust_dir * 28.0).round(), PAL["cream"] as Color, 1.4)
