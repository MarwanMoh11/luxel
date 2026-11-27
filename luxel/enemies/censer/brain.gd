class_name LxCenserBrain
extends LxEnemyBrain
## Island 8 Enemy: Censer (Zone Denial / Dimmer | HP 3.0 | Shards 4).
## Hooded incense-moth orbiting lamps and swinging a dark thurible that leaves 2.5s dusk-smoke
## pools shrinking lantern radius 35% (never blind!). Beam slices chain (1.4s stun); Sunflare
## ignites smoke clouds for 2.0 AoE bonus damage; Wings glides safely over smoke!

const ORBIT_R: float = 28.0
const SPIN_TELL: float = 0.52
const WHIP_COMMIT: float = 0.28
const WHIP_RECOVER: float = 1.15
const WHIP_RANGE: float = 56.0
const SMOKE_R: float = 34.0
const SMOKE_DUR: float = 2.5
const LIGHT_DIM_SCALE: float = 0.65
const NOTICE_TIME: float = 0.22

var _orbit_ang: float = 0.0
var _whip_dir: Vector2 = Vector2.RIGHT
var _whip_hit_done: bool = false
var _chain_cut_t: float = 0.0
var _dusk_frozen_t: float = 0.0
var _smoke_pools: Array[Dictionary] = []
var _dimming_wick: bool = false
var _saved_light_scale: float = 1.0


func _init() -> void:
	kind = "censer"
	island_id = 8
	max_hp = 3.0
	hp = 3.0
	body_radius = 6.5
	routine_speed = 46.0
	leash_radius = 160.0
	notice_radius = 130.0
	tell_time = SPIN_TELL
	recover_time = WHIP_RECOVER
	give_up_time = 2.2
	shard_drop = 4
	attack_damage = 1.0


func is_flying() -> bool:
	return true


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_orbit_ang = _randf_range(0.0, TAU)
	_whip_dir = Vector2.from_angle(facing)
	_whip_hit_done = false
	_chain_cut_t = 0.0
	_dusk_frozen_t = 0.0
	_smoke_pools.clear()
	_restore_wick_light()


func _exit_tree() -> void:
	_restore_wick_light()


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		_dusk_frozen_t = 2.0
		state = State.STAGGER
		state_timer = 2.0
		_emit_sfx("clockwork_chime")
	elif t == "war":
		_smoke_pools.clear()
		_restore_wick_light()
		if state == State.ROUTINE:
			_enter_notice()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_beam: bool = src == LxHit.SOURCE_BEAM
	var is_sunflare: bool = src == LxHit.SOURCE_SUNFLARE
	var is_heavy: bool = bool(h["stagger"]) or src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_DASH

	# Beam slices the censer chain -> 1.4s stun + bonus damage!
	if is_beam:
		dmg *= 1.35
		_chain_cut_t = 1.4
		_emit_sfx("censer_chain_cut")

	# Sunflare ignites active dusk-smoke clouds for +2.0 AoE detonation!
	if is_sunflare and not _smoke_pools.is_empty():
		dmg += 2.0
		_smoke_pools.clear()
		_restore_wick_light()
		LxDamageFx.boss_impact(pos, 0.14, 68.0, 74.0, 70.0, 1.32, 0.28)
		_emit_sfx("bramble_burn")

	var is_opening: bool = is_beam or is_sunflare or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if (is_beam or is_heavy or is_sunflare) else 0.07
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (110.0 if (is_beam or is_heavy) else 36.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_smoke_pools.clear()
		_restore_wick_light()
		_die(hit)
		return HitResult.KILLED

	if is_beam or is_sunflare or is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.4 if is_beam else (1.6 if is_sunflare else 1.0)
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_chain_cut_t = maxf(0.0, _chain_cut_t - dt)
	_dusk_frozen_t = maxf(0.0, _dusk_frozen_t - dt)
	_tick_smoke_pools(dt)

	match state:
		State.ROUTINE:
			_orbit_ang = wrapf(_orbit_ang + dt * 1.35, -PI, PI)
			var want: Vector2 = home + Vector2(cos(_orbit_ang), sin(_orbit_ang)) * ORBIT_R
			var step: Vector2 = (want - pos).limit_length(routine_speed * dt)
			if step.length() > 0.05:
				_turn_toward(step.angle(), 4.2, dt)
				_move_step(step, true)
			if _has_player() and pos.distance_to(_get_wick_pos()) <= notice_radius and _has_clear_view(pos, _get_wick_pos()):
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
				_turn_toward(to_w.angle(), 4.5, dt)
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
				cooldown = 0.85
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.55
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


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

	var wp: Vector2 = _get_wick_pos()
	var to_w: Vector2 = wp - pos
	var dist: float = to_w.length()
	if dist > 0.1:
		_turn_toward(to_w.angle(), 3.6, dt)
		var pref: float = 48.0
		var move_v: Vector2 = (to_w / dist) * clampf((dist - pref) / 28.0, -0.5, 0.85) \
				+ (to_w / dist).rotated(PI * 0.5) * 0.45
		_move_step(move_v.normalized() * routine_speed * 0.90 * dt, true)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= WHIP_RANGE + 14.0:
		if _claim_token():
			_whip_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = _whip_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(SPIN_TELL, false, attack_damage)
			state_timer = last_tell_duration
			_whip_hit_done = false
			_emit_attack_started()
			_emit_sfx("censer_swing")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 * _assist_tell_scale() and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 2.8, dt)
			_whip_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = WHIP_COMMIT
		_whip_hit_done = false
		_spawn_smoke_pool(pos + _whip_dir * 32.0)
		_emit_sfx("censer_swing")


func _step_commit(dt: float) -> void:
	_move_step(_whip_dir * 92.0 * dt, true)
	if not _whip_hit_done and _has_player():
		var rel: Vector2 = _get_wick_pos() - pos
		if rel.length() <= WHIP_RANGE and (rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.05):
			_whip_hit_done = true
			_emit_player_hit(_whip_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, WHIP_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= ORBIT_R + 4.0:
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.6, dt)
	_move_step(to_h.limit_length(routine_speed * 0.95 * dt), true)


func _spawn_smoke_pool(at: Vector2) -> void:
	if _smoke_pools.size() >= 3:
		_smoke_pools.pop_front()
	_smoke_pools.append({"pos": at, "ttl": SMOKE_DUR, "max_ttl": SMOKE_DUR})


func _is_wick_gliding() -> bool:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return false
	var gv: Variant = Lx.player.get("gliding")
	if gv is bool and (gv as bool):
		return true
	var mw: Variant = Lx.player.get("move_wings")
	if mw is Object and is_instance_valid(mw):
		var mg: Variant = (mw as Object).get("gliding")
		if mg is bool and (mg as bool):
			return true
	return false


func _tick_smoke_pools(dt: float) -> void:
	var wick_in_smoke: bool = false
	var wp: Vector2 = _get_real_wick_pos()
	var gliding: bool = _is_wick_gliding()
	for i: int in range(_smoke_pools.size() - 1, -1, -1):
		var sp: Dictionary = _smoke_pools[i]
		sp["ttl"] = float(sp["ttl"]) - dt
		if float(sp["ttl"]) <= 0.0:
			_smoke_pools.remove_at(i)
			continue
		if not gliding and wp.distance_to(sp["pos"] as Vector2) <= SMOKE_R:
			wick_in_smoke = true
	if wick_in_smoke and not _dimming_wick:
		if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_light_scale"):
			_saved_light_scale = float(Lx.player.call("get_light_scale")) if Lx.player.has_method("get_light_scale") else 1.0
			_dimming_wick = true
			Lx.player.call("set_light_scale", _saved_light_scale * LIGHT_DIM_SCALE)
	elif not wick_in_smoke and _dimming_wick:
		_restore_wick_light()


func _restore_wick_light() -> void:
	if not _dimming_wick:
		return
	_dimming_wick = false
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_light_scale"):
		Lx.player.call("set_light_scale", _saved_light_scale)


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("censer_swing")


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	for sp: Dictionary in _smoke_pools:
		var rp: Vector2 = ((sp["pos"] as Vector2) - pos).round()
		var frac: float = clampf(float(sp["ttl"]) / maxf(float(sp["max_ttl"]), 0.1), 0.0, 1.0)
		var r: float = SMOKE_R * lerpf(0.75, 1.0, frac)
		draw_circle(rp, r, Color(PAL["dusk"] as Color, 0.36 * frac))
		draw_arc(rp, r, 0.0, TAU, 20, Color(PAL["void"] as Color, 0.45 * frac), 3.0)
		draw_arc(rp, r, 0.0, TAU, 20, Color(PAL["plum"] as Color, 0.65 * frac), 1.0)
	if _chain_cut_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["gold"] as Color, 2.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_sector(self, Vector2.ZERO, facing - 1.05, facing + 1.05, WHIP_RANGE, prog, anim_t, "coral", "apricot")
