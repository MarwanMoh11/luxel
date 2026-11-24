class_name LxSnufferAcolyteBrain
extends LxEnemyBrain
## Island 1 Enemy: Snuffer Acolyte (Objective Pressure, HP 2.0, Shards 3).
## Hooded moth-monk patrolling braziers; sprints 118 px/s during COMMIT to snuff lit braziers,
## clamp thrown lanterns, or slam Wick. Dash knocks off its brass cone (1.2s stagger);
## Dusk ring wave freezes its sprint for 2.0s!

const SNUFF_TELL: float = 0.48
const SNUFF_COMMIT: float = 1.25
const SNUFF_RECOVER: float = 1.15
const SPRINT_SPEED: float = 118.0
const SNUFF_HIT_R: float = 20.0
const NOTICE_TIME: float = 0.30
const DASH_STAGGER_TIME: float = 1.20
const DUSK_FREEZE_TIME: float = 2.00

var route: Array[Vector2] = []
var route_i: int = 0
var pause_t: float = 0.0
var dusk_frozen_t: float = 0.0
var sprint_target: Vector2 = Vector2.ZERO
var sprint_kind: String = "wick" # "brazier" | "lantern" | "wick"
var sprint_brazier: Node = null
var sprint_hit_done: bool = false
var snuff_puff_t: float = 0.0


func _init() -> void:
	kind = "snuffer_acolyte"
	island_id = 1
	max_hp = 2.0
	hp = 2.0
	body_radius = 6.0
	routine_speed = 38.0
	leash_radius = 160.0
	notice_radius = 140.0
	tell_time = SNUFF_TELL
	recover_time = SNUFF_RECOVER
	give_up_time = 2.0
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pv: Variant in (raw_r as Array):
			var pt: Vector2 = _to_vec2(pv, home)
			if pt.distance_to(home) > leash_radius - 2.0:
				pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
			route.append(pt)
	if route.size() < 2:
		route = [home + Vector2(-26.0, 0.0), home + Vector2(26.0, 0.0)]
	route_i = 0
	pause_t = 0.0
	dusk_frozen_t = 0.0
	sprint_target = home
	sprint_kind = "wick"
	sprint_brazier = null
	sprint_hit_done = false
	snuff_puff_t = 0.0


func on_ring(tone: String, _dir: Vector2) -> void:
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
		cooldown = minf(cooldown, 0.25)
		if state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
	elif t == "dawn":
		if state == State.ROUTINE:
			_enter_notice()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_dash: bool = src == LxHit.SOURCE_DASH
	var is_zip: bool = src == LxHit.SOURCE_ZIP or src == LxHit.SOURCE_THROW
	var is_heavy: bool = bool(h["stagger"]) or is_dash or is_zip

	# Dash knocks brass snuffer cone off for bonus damage & crisp 1.2s stagger!
	if is_dash:
		dmg += 0.35

	var is_opening: bool = state == State.COMMIT or state == State.RECOVER or state == State.STAGGER or is_dash
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.07
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 34.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else DASH_STAGGER_TIME
		_emit_sfx("snuffer_cone_knock")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	dusk_frozen_t = maxf(0.0, dusk_frozen_t - dt)
	snuff_puff_t = maxf(0.0, snuff_puff_t - dt)

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _find_light_objective().get("found", false):
				_enter_notice()
		State.NOTICE:
			var obj: Dictionary = _find_light_objective()
			var tp: Vector2 = obj.get("pos", _get_wick_pos()) as Vector2
			if tp.distance_to(pos) > 0.1:
				_turn_toward((tp - pos).angle(), 5.0, dt)
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
				cooldown = 0.95
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i % route.size()]
	var to_w: Vector2 = wp - pos
	if to_w.length() <= 3.0:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.85
		return
	_turn_toward(to_w.angle(), 4.0, dt)
	_move_step(to_w.limit_length(routine_speed * dt), false)


func _find_light_objective() -> Dictionary:
	# Priority 1: Lit brazier / timed_brazier within notice_radius & leash
	var ctx: Node = world_ctx if (world_ctx != null and is_instance_valid(world_ctx)) else Lx.world
	if ctx != null and ctx.has_method("get_interactables"):
		var best_b: Node = null
		var best_d: float = notice_radius
		for it_v: Variant in (ctx.call("get_interactables") as Array):
			if not (it_v is Node) or not is_instance_valid(it_v as Node):
				continue
			var it: Node = it_v as Node
			var k: String = str(it.get("kind")) if it.get("kind") != null else ""
			if k != "brazier" and k != "timed_brazier":
				continue
			var is_lit: bool = bool(it.get("powered")) if it.get("powered") != null else (bool(it.get("lit")) if it.get("lit") != null else false)
			if not is_lit:
				continue
			var bp: Vector2 = it.get("pos") as Vector2 if it.get("pos") is Vector2 else ((it as Node2D).global_position if it is Node2D else Vector2.INF)
			if not bp.is_finite() or bp.distance_to(home) > leash_radius + 12.0:
				continue
			var d: float = pos.distance_to(bp)
			if d <= best_d:
				best_d = d
				best_b = it
		if best_b != null:
			var bpos: Vector2 = best_b.get("pos") as Vector2 if best_b.get("pos") is Vector2 else (best_b as Node2D).global_position
			return {"found": true, "kind": "brazier", "pos": bpos, "node": best_b}

	# Priority 2: Thrown / hung lantern within notice_radius
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if lp.distance_to(pos) <= notice_radius and lp.distance_to(home) <= leash_radius + 20.0:
			return {"found": true, "kind": "lantern", "pos": lp, "node": null}

	# Priority 3: Lit Wick within notice_radius (ignores cloaked Shutter Hood unless very close!)
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		var cloaked: bool = _is_wick_cloaked()
		var detect_r: float = 38.0 if cloaked else notice_radius
		if wp.distance_to(pos) <= detect_r and wp.distance_to(home) <= leash_radius + 14.0:
			return {"found": true, "kind": "wick", "pos": wp, "node": null}

	return {"found": false, "kind": "", "pos": home, "node": null}


func _is_wick_cloaked() -> bool:
	return _is_lantern_out() and Lx.state != null and bool(Lx.state.story_flags.get("item_shutter_hood", false))


func _step_position(dt: float) -> void:
	var obj: Dictionary = _find_light_objective()
	if not bool(obj["found"]):
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var tp: Vector2 = obj["pos"] as Vector2
	var to_t: Vector2 = tp - pos
	var dist: float = to_t.length()
	if dist > 0.1:
		_turn_toward(to_t.angle(), 4.2, dt)
		# Calm stalking step strictly <= routine_speed * 0.85 (sprint is COMMIT-only!)
		if dist > 48.0:
			_move_step(to_t.limit_length(routine_speed * 0.85 * dt), false)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if bool(obj["found"]) and can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= notice_radius:
		if _claim_token():
			sprint_target = tp
			sprint_kind = str(obj["kind"])
			sprint_brazier = obj["node"] as Node
			sprint_hit_done = false
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(SNUFF_TELL, false, attack_damage)
			state_timer = last_tell_duration
			_emit_attack_started()
			_emit_sfx("snuffer_puff_tell")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16:
		if sprint_kind == "lantern" and _is_lantern_out():
			sprint_target = _get_lantern_pos()
		elif sprint_kind == "wick" and _has_player():
			sprint_target = _get_wick_pos()
		var to_t: Vector2 = sprint_target - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 4.5, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = SNUFF_COMMIT
		sprint_hit_done = false
		_emit_sfx("snuffer_snuff")


func _step_commit(dt: float) -> void:
	var to_t: Vector2 = sprint_target - pos
	var dist: float = to_t.length()
	var move_dir: Vector2 = to_t / dist if dist > 1.0 else Vector2.from_angle(facing)
	facing = move_dir.angle()
	_move_step(move_dir * minf(SPRINT_SPEED * dt, dist), false)

	var reached: bool = pos.distance_to(sprint_target) <= 14.0
	if not sprint_hit_done and _has_player() and pos.distance_to(_get_wick_pos()) <= SNUFF_HIT_R:
		sprint_hit_done = true
		_emit_player_hit(move_dir)
		reached = true

	if reached:
		_perform_snuff_action()
		_enter_recover()
		return

	state_timer -= dt
	if state_timer <= 0.0:
		_perform_snuff_action()
		_enter_recover()


func _perform_snuff_action() -> void:
	snuff_puff_t = 0.40
	_emit_sfx("snuffer_snuff")
	if sprint_kind == "brazier" and sprint_brazier != null and is_instance_valid(sprint_brazier):
		if pos.distance_to(sprint_target) <= 24.0:
			if sprint_brazier.has_method("extinguish"):
				sprint_brazier.call("extinguish")
			elif sprint_brazier.has_method("set_powered"):
				sprint_brazier.call("set_powered", false)
			elif sprint_brazier.get("lit") != null:
				sprint_brazier.set("lit", false)
	elif sprint_kind == "lantern" and _is_lantern_out():
		if pos.distance_to(_get_lantern_pos()) <= 24.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())


func _enter_recover() -> void:
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, SNUFF_RECOVER)
	last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 4.2, dt)
	_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
	if _find_light_objective().get("found", false) and (_find_light_objective()["pos"] as Vector2).distance_to(home) <= leash_radius:
		_enter_notice()


func _should_give_up() -> bool:
	return not bool(_find_light_objective().get("found", false))


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("snuffer_puff_tell")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.06, 36.0, 42.0, 38.0, 1.15, 0.20)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(4):
			var sd: Vector2 = Vector2.from_angle(float(si) * (PI * 0.5))
			Lx.player.call("spawn_sparks", pos, sd, 2, PAL["plum"] as Color, 25.0, 62.0, 0.26)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if dusk_frozen_t > 0.0:
		var a: float = clampf(dusk_frozen_t / DUSK_FREEZE_TIME, 0.25, 1.0)
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, Color(PAL["ice"] as Color, a), 1.6)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var local_t: Vector2 = sprint_target - pos
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, local_t.limit_length(120.0), 11.0, prog, anim_t, "coral", "gold")
	elif state == State.COMMIT:
		var fwd: Vector2 = Vector2.from_angle(facing)
		draw_line(c, (c + fwd * 18.0).round(), PAL["gold"] as Color, 1.8)
	if snuff_puff_t > 0.0:
		var u: float = 1.0 - clampf(snuff_puff_t / 0.40, 0.0, 1.0)
		draw_arc(c, 6.0 + u * 16.0, 0.0, TAU, 16, Color(PAL["mauve"] as Color, 1.0 - u), 1.6)
