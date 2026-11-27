class_name LxLampButlerBrain
extends LxEnemyBrain
## Island 1 Enemy: Lamp Butler (Stealth Tank / Patrol, HP 3.5, Shield 1.5 front, Shards 4).
## Tuxedoed toad-valet sweeping a 55 deg (108px) bullseye lamp cone with 1.1s door pauses.
## Front brass lamp-hood blocks bolts (3-4 bolts crack it). Throwing lantern behind him triggers
## polite LURE inspection exposing his back for 2x sneak damage! Dash breaks stance; Dusk freezes
## cone 2.0s; War cracks hood; Shutter Hood removes <34px hearing.

const CONE_RANGE: float = 108.0
const CONE_HALF_RAD: float = 0.48 # ~55 deg full cone
const HEAR_R: float = 34.0
const PATROL_PAUSE: float = 1.10
const WHISTLE_NOTICE: float = 0.50
const SLASH_TELL: float = 0.46
const SLASH_COMMIT: float = 0.20
const SLASH_RECOVER: float = 1.15
const SLASH_REACH: float = 38.0
const SLASH_HIT_R: float = 30.0
const SLASH_ARC: float = 1.10
const LUNGE_SPEED: float = 155.0
const BLOCK_HALF: float = 1.00
const SHIELD_REFORM_S: float = 5.0
const DUSK_FREEZE_TIME: float = 2.00
const STAGGER_TIME: float = 1.10
const SNEAK_MULT: float = 2.0

var route: Array[Vector2] = []
var route_i: int = 0
var home_facing: float = 0.0
var pause_t: float = 0.0
var shield_max: float = 1.5
var shield_hp: float = 1.5
var shield_gone_t: float = 0.0
var dusk_frozen_t: float = 0.0
var wary: bool = false
var slash_dir: Vector2 = Vector2.RIGHT
var slash_hit_done: bool = false


func _init() -> void:
	kind = "lamp_butler"
	island_id = 1
	max_hp = 3.5
	hp = 3.5
	body_radius = 6.5
	routine_speed = 34.0
	leash_radius = 158.0
	notice_radius = CONE_RANGE
	tell_time = SLASH_TELL
	recover_time = SLASH_RECOVER
	give_up_time = 2.2
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	if spec.has("shield_hp"):
		shield_max = maxf(0.0, float(spec["shield_hp"]))
	shield_hp = shield_max
	shield_gone_t = 0.0
	dusk_frozen_t = 0.0
	wary = false
	pause_t = 0.0
	slash_hit_done = false
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pv: Variant in (raw_r as Array):
			var pt: Vector2 = _to_vec2(pv, home)
			if pt.distance_to(home) > leash_radius - 2.0:
				pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
			route.append(pt)
	route_i = 0
	if not spec.has("facing") and not route.is_empty() and route[0].distance_to(home) > 1.0:
		facing = (route[0] - home).angle()
	home_facing = facing


func on_ring(tone: String, dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		dusk_frozen_t = DUSK_FREEZE_TIME
		state = State.STAGGER
		state_timer = DUSK_FREEZE_TIME
		_emit_sfx("clockwork_chime")
	elif t == "war":
		# War cracks lamp-hood shield and alerts!
		if _has_active_shield():
			_damage_shield(shield_max)
		elif state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
	elif t == "dawn":
		# Polite glance toward Dawn chime (turns toward sound!)
		if dir.length_squared() > 0.01:
			facing = (-dir).angle()
		if state == State.ROUTINE:
			pause_t = 0.9


func _has_active_shield() -> bool:
	return dusk_frozen_t <= 0.0 and shield_max > 0.001 and shield_hp > 0.001 and shield_gone_t <= 0.0 \
			and state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _is_lured() -> bool:
	if wary or not _is_lantern_out():
		return false
	return _get_lantern_pos().distance_to(home) <= leash_radius + 32.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var is_dash: bool = src == LxHit.SOURCE_DASH
	var is_heavy: bool = bool(h["stagger"]) or is_dash
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < BLOCK_HALF
	var from_behind: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) > 1.75

	# Front brass lamp-hood blocks frontal bolts (3-4 bolts crack it; Dash/cracks/pierce bypasses!)
	if _has_active_shield() and from_front and not pierce and not cracks and not is_dash:
		clank_t = 0.14
		var wear: float = maxf(0.5, float(h["shield_wear"]))
		if _damage_shield(wear):
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		_emit_sfx("warden_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	# Sneak attack from behind (especially while lured inspecting thrown lantern!) = 2x damage!
	var sneak: bool = from_behind and (state == State.ROUTINE or _is_lured() or state == State.NOTICE)
	if sneak:
		dmg *= SNEAK_MULT
	var is_opening: bool = sneak or state == State.RECOVER or state == State.STAGGER or shield_gone_t > 0.0

	hp -= dmg
	wary = true
	flash_t = 0.14 if (is_heavy or sneak) else 0.07
	if rel.length() > 0.01:
		knock = -rel.normalized() * (125.0 if is_heavy else 26.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		if is_dash and _has_active_shield():
			_damage_shield(shield_max * 0.65)
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if sneak else HitResult.CHIPPED)
	return HitResult.OPENED if sneak else HitResult.CHIPPED


func _damage_shield(amount: float) -> bool:
	shield_hp = maxf(0.0, shield_hp - amount)
	if shield_hp > 0.001:
		return false
	shield_gone_t = SHIELD_REFORM_S
	wary = true
	_release_token()
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, 1.25)
	last_recover_duration = state_timer
	_emit_sfx("warden_shield_break")
	return true


func _step_brain(dt: float) -> void:
	dusk_frozen_t = maxf(0.0, dusk_frozen_t - dt)
	if shield_max > 0.001 and shield_gone_t > 0.0:
		shield_gone_t -= dt
		if shield_gone_t <= 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max
			_emit_sfx("warden_shield_reform")

	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = target_pos - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			_step_tell(dt, target_pos)
		State.COMMIT:
			_step_commit(dt)
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.90
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.55
				state = State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_walk_toward(home, dt)
			return
		_turn_toward(home_facing + sin(anim_t * 0.65) * 0.85, 1.4, dt)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i % route.size()]
	if pos.distance_to(wp) <= 3.0:
		route_i = (route_i + 1) % route.size()
		pause_t = PATROL_PAUSE
		return
	_walk_toward(wp, dt)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if dist > 0.1:
		_turn_toward(to_t.angle(), 3.2, dt)

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

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN

	if can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= SLASH_REACH + 18.0:
		if _claim_token():
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(SLASH_TELL, false, attack_damage)
			state_timer = last_tell_duration
			slash_hit_done = false
			_emit_attack_started()
			_emit_sfx("warden_windup")
			return

	if dist > SLASH_REACH - 8.0:
		_move_step(to_t.limit_length(routine_speed * 0.86 * dt), false)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if state_timer > 0.16 * _assist_tell_scale():
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 2.2, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = SLASH_COMMIT
		slash_dir = Vector2.from_angle(facing)
		slash_hit_done = false
		_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	_move_step(slash_dir * LUNGE_SPEED * dt, false)
	if not slash_hit_done and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		var wd: float = to_w.length()
		if wd <= SLASH_HIT_R and (wd < 0.1 or absf(angle_difference(facing, to_w.angle())) <= SLASH_ARC):
			slash_hit_done = true
			_emit_player_hit(slash_dir)
	if _is_lured():
		var lp: Vector2 = _get_lantern_pos()
		if pos.distance_to(lp) <= SLASH_HIT_R and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SLASH_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	_walk_toward(home, dt)
	if pos.distance_to(home) <= 3.0:
		pos = home
		state = State.ROUTINE
		wary = false
		pause_t = 0.6
	elif _sees_target() and _attention_target().distance_to(home) <= leash_radius:
		_enter_notice()


func _walk_toward(dest: Vector2, dt: float) -> void:
	var to_d: Vector2 = dest - pos
	if to_d.length() < 0.1:
		return
	_turn_toward(to_d.angle(), 3.2, dt)
	if absf(angle_difference(facing, to_d.angle())) < 0.35:
		_move_step(to_d.limit_length(routine_speed * dt), false)


func _sees_target() -> bool:
	if dusk_frozen_t > 0.0:
		return false
	var target_pos: Vector2 = _attention_target()
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if _is_lured():
		return dist <= CONE_RANGE + 20.0 and _has_clear_view(pos, target_pos)
	if not _has_player():
		return false
	# Shutter Hood removes <34px hearing & hides Wick from lamp cone!
	var cloaked: bool = _is_lantern_out() and Lx.state != null and bool(Lx.state.story_flags.get("item_shutter_hood", false))
	if cloaked:
		return false
	if dist <= HEAR_R:
		return true
	if dist > CONE_RANGE or absf(angle_difference(facing, to_t.angle())) > CONE_HALF_RAD:
		return false
	return _has_clear_view(pos, target_pos)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = WHISTLE_NOTICE
	alert_t = 0.85
	lost_t = 0.0
	_emit_sfx("butler_whistle")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 42.0, 48.0, 42.0, 1.20, 0.22)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(5):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 5.0))
			Lx.player.call("spawn_sparks", pos, sd, 2, PAL["gold"] as Color, 28.0, 72.0, 0.28)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Sweeping 55 deg bullseye lamp cone!
	if dusk_frozen_t <= 0.0 and state != State.STAGGER:
		var a0: float = facing - CONE_HALF_RAD
		var a1: float = facing + CONE_HALF_RAD
		var col: Color = (PAL["coral"] if state == State.TELL else PAL["gold"]) as Color
		var fill_a: float = 0.12 if LxHudFx.flash_reduced() else (0.20 if state == State.NOTICE else 0.14)
		var pts := PackedVector2Array([c])
		for si: int in range(9):
			var ang: float = lerpf(a0, a1, float(si) / 8.0)
			pts.append(c + Vector2.from_angle(ang) * CONE_RANGE)
		draw_colored_polygon(pts, Color(col, fill_a))
		draw_arc(c, CONE_RANGE, a0, a1, 10, Color(col, 0.45), 1.0)
	if dusk_frozen_t > 0.0:
		draw_arc(c, body_radius + 5.5, 0.0, TAU, 16, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 5.5, 0.0, TAU, 16, PAL["ice"] as Color, 2.0)
	if state == State.COMMIT:
		draw_arc(c, SLASH_HIT_R * 0.85, facing - SLASH_ARC, facing + SLASH_ARC, 14, PAL["void"] as Color, 4.0)
		draw_arc(c, SLASH_HIT_R * 0.85, facing - SLASH_ARC, facing + SLASH_ARC, 14, PAL["cream"] as Color, 2.0)
