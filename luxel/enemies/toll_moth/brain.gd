class_name LxTollMothBrain
extends LxEnemyBrain
## Island 1 Enemy: Toll Moth (Disrupter / Catalyst, HP 1.5, Shards 3).
## Hovers between 2 perches. Shooting with a bolt rings a 96px WAR wave (shatters cracks/shields
## & alerts foes!). Throwing the lantern is a silent 1-shot kill; Dash knocks it silent;
## Dusk ring wave mutes & staggers it for 2.0s.

const RING_TELL: float = 0.50
const RING_COMMIT: float = 0.25
const RING_RECOVER: float = 1.20
const ATTACK_RING_R: float = 64.0
const CATALYST_WAR_R: float = 96.0
const NOTICE_TIME: float = 0.28
const STAGGER_TIME: float = 1.20
const DUSK_MUTE_TIME: float = 2.00

var perches: Array[Vector2] = []
var perch_i: int = 0
var pause_t: float = 0.0
var muted_t: float = 0.0
var ring_hit_done: bool = false
var pulse_fx_t: float = 0.0
var pulse_fx_r: float = 0.0
var pulse_fx_col: String = "coral"
var _waves: Array[LxRingWave] = []
var _hover_t: float = 0.0


func _init() -> void:
	kind = "toll_moth"
	island_id = 1
	max_hp = 1.5
	hp = 1.5
	body_radius = 6.5
	routine_speed = 44.0
	leash_radius = 156.0
	notice_radius = 110.0
	tell_time = RING_TELL
	recover_time = RING_RECOVER
	give_up_time = 1.9
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	perches.clear()
	var raw_p: Variant = spec.get("perches", spec.get("route", []))
	if raw_p is Array:
		for pv: Variant in (raw_p as Array):
			var pt: Vector2 = _to_vec2(pv, home)
			if pt.distance_to(home) > leash_radius - 4.0:
				pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 4.0)
			perches.append(pt)
	if perches.size() < 2:
		perches = [home + Vector2(-28.0, -10.0), home + Vector2(28.0, 10.0)]
	perch_i = 0
	pause_t = 0.0
	muted_t = 0.0
	ring_hit_done = false
	pulse_fx_t = 0.0
	pulse_fx_r = 0.0
	_hover_t = _randf_range(0.0, TAU)
	_clear_waves()


func is_flying() -> bool:
	return state != State.RECOVER and state != State.STAGGER


func _visual_offset() -> Vector2:
	if state == State.STAGGER or state == State.RECOVER:
		return Vector2.ZERO
	return Vector2(0.0, -5.0 - sin(_hover_t * 4.5) * 2.5)


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		muted_t = DUSK_MUTE_TIME
		state = State.STAGGER
		state_timer = DUSK_MUTE_TIME
		alert_t = 0.0
		_emit_sfx("clockwork_chime")
	elif t == "war":
		cooldown = minf(cooldown, 0.25)
		if state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
		_trigger_pulse_fx(42.0, "coral")
	elif t == "dawn":
		if state == State.ROUTINE:
			_enter_notice()
		_trigger_pulse_fx(36.0, "gold")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_bolt: bool = src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_dash: bool = src == LxHit.SOURCE_DASH
	var is_heavy: bool = bool(h["stagger"]) or is_dash or is_throw

	# Throw / Recall / Zip = silent 1-shot kill (never rings War wave!)
	if is_throw:
		dmg = maxf(dmg, max_hp + 0.5)
	# Dash knocks it silent & deals crisp stagger without ringing War wave
	elif is_dash:
		muted_t = maxf(muted_t, STAGGER_TIME)
	# Bolt = intentional WAR ring-wave catalyst (unless muted by Dusk/Dash!)
	elif is_bolt and muted_t <= 0.0:
		_emit_war_ring_wave()

	var is_opening: bool = is_throw or state == State.RECOVER or state == State.STAGGER or state == State.ROUTINE
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (130.0 if is_heavy else 42.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _emit_war_ring_wave() -> void:
	_trigger_pulse_fx(CATALYST_WAR_R, "coral")
	_emit_sfx("toll_moth_war_ring")
	if director != null:
		director.rally_nearby(self, CATALYST_WAR_R + 24.0, 0.25)
	var region_n: Node = world_ctx if (world_ctx != null and is_instance_valid(world_ctx)) else Lx.world
	var wave := LxRingWave.new()
	var parent_n: Node = region_n if (region_n != null and is_instance_valid(region_n)) else get_parent()
	if parent_n != null:
		parent_n.add_child(wave)
		wave.setup(pos, "war", region_n, 145.0, CATALYST_WAR_R, enemy_id if not enemy_id.is_empty() else "toll_moth_%d" % get_instance_id())
		_waves.append(wave)
	else:
		wave.free()


func _step_brain(dt: float) -> void:
	_hover_t += dt
	muted_t = maxf(0.0, muted_t - dt)
	pulse_fx_t = maxf(0.0, pulse_fx_t - dt)
	_tick_waves(dt)

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_player() and _get_wick_pos().distance_to(pos) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.01:
				_turn_toward(to_w.angle(), 5.0, dt)
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
				cooldown = 1.05
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
	var dest: Vector2 = perches[perch_i % perches.size()]
	var to_d: Vector2 = dest - pos
	if to_d.length() <= 3.0:
		perch_i = (perch_i + 1) % perches.size()
		pause_t = 0.75
		return
	facing = to_d.angle()
	_move_step(to_d.limit_length(routine_speed * dt), true)


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
	if dist > 0.01:
		_turn_toward(to_w.angle(), 4.5, dt)

	# Gentle perch orbit staying strictly <= routine_speed
	var desired: Vector2 = perches[perch_i % perches.size()]
	if dist < 44.0 and dist > 0.1:
		desired = pos - (to_w / dist) * 28.0
	elif dist > 78.0 and dist > 0.1:
		desired = pos + (to_w / dist) * 24.0
	var to_des: Vector2 = desired - pos
	if to_des.length() > 3.0:
		_move_step(to_des.limit_length(routine_speed * 0.85 * dt), true)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and muted_t <= 0.0 and _is_on_screen() and dist <= ATTACK_RING_R + 20.0:
		if _claim_token():
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(RING_TELL, false, attack_damage)
			state_timer = last_tell_duration
			ring_hit_done = false
			_emit_attack_started()
			_emit_sfx("toll_moth_tell")


func _step_tell(dt: float) -> void:
	if state_timer > 0.14 * _assist_tell_scale():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.01:
			_turn_toward(to_w.angle(), 3.2, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = RING_COMMIT
		ring_hit_done = false
		_trigger_pulse_fx(ATTACK_RING_R, "coral")
		_emit_sfx("toll_moth_ring")


func _step_commit(dt: float) -> void:
	var prog: float = 1.0 - clampf(state_timer / maxf(RING_COMMIT, 0.05), 0.0, 1.0)
	var cur_r: float = lerpf(10.0, ATTACK_RING_R, prog)
	if not ring_hit_done and _has_player():
		var wp: Vector2 = _get_wick_pos()
		var d: float = pos.distance_to(wp)
		if absf(d - cur_r) <= 10.0 or d <= 16.0:
			ring_hit_done = true
			var push: Vector2 = (wp - pos).normalized() if d > 0.1 else Vector2.from_angle(facing)
			_emit_player_hit(push)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, RING_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	facing = to_h.angle()
	_move_step(to_h.limit_length(routine_speed * 0.92 * dt), true)
	if _has_player() and _get_wick_pos().distance_to(home) <= notice_radius * 0.85:
		_enter_notice()


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("clockwork_chime")


func _trigger_pulse_fx(rad: float, col: String) -> void:
	pulse_fx_t = 0.36
	pulse_fx_r = rad
	pulse_fx_col = col


func _tick_waves(dt: float) -> void:
	for i: int in range(_waves.size() - 1, -1, -1):
		var w: LxRingWave = _waves[i]
		if w == null or not is_instance_valid(w):
			_waves.remove_at(i)
			continue
		w.tick(dt)
		if w.done:
			w.queue_free()
			_waves.remove_at(i)


func _clear_waves() -> void:
	for w: LxRingWave in _waves:
		if w != null and is_instance_valid(w):
			w.queue_free()
	_waves.clear()


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.06, 36.0, 40.0, 38.0, 1.15, 0.18)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(5):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 5.0))
			Lx.player.call("spawn_sparks", pos, sd, 2, PAL["gold"] as Color, 28.0, 68.0, 0.28)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if muted_t > 0.0:
		var a: float = clampf(muted_t / DUSK_MUTE_TIME, 0.25, 1.0)
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 16, Color(PAL["ice"] as Color, a), 1.0)
		draw_line(c + Vector2(-5.0, -5.0), c + Vector2(5.0, 5.0), Color(PAL["sky"] as Color, a), 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, Vector2.ZERO, ATTACK_RING_R, prog, anim_t, "coral", "gold")
	elif state == State.COMMIT:
		var prog2: float = 1.0 - clampf(state_timer / maxf(RING_COMMIT, 0.05), 0.0, 1.0)
		var r_now: float = lerpf(10.0, ATTACK_RING_R, prog2)
		draw_arc(Vector2.ZERO, r_now, 0.0, TAU, 24, PAL["void"] as Color, 4.0)
		draw_arc(Vector2.ZERO, r_now, 0.0, TAU, 24, PAL["coral"] as Color, 2.0)
		draw_arc(Vector2.ZERO, maxf(4.0, r_now - 2.0), 0.0, TAU, 20, PAL["cream"] as Color, 1.0)
	if pulse_fx_t > 0.0:
		var u: float = 1.0 - clampf(pulse_fx_t / 0.36, 0.0, 1.0)
		var pr: float = lerpf(8.0, pulse_fx_r, u)
		var col: Color = LxPalette.color(pulse_fx_col, "coral")
		draw_arc(Vector2.ZERO, pr, 0.0, TAU, 24, Color(col, (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.85)), 2.0)
