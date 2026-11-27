class_name LxGraveHandBrain
extends LxEnemyBrain
## Island 1 Enemy: Grave Hand (Zone Denial, HP 2.0, Shards 2).
## Brass-cuffed skeletal hand rooted in crypt soil / Midnight graves. Taps floor every 2.4s.
## Snatches Wick at 46px (tell 0.50s, commit 0.22s = 1 heart + 0.6s ankle snare, limp recover 1.20s).
## Bolt safely >46px; Dash snaps wrist (1.2s stagger); Throw pins flat; Dusk sinks underground 2.5s!

const GRAB_RANGE: float = 54.0
const GRAB_HIT_R: float = 46.0
const TAP_PERIOD: float = 2.40
const GRAB_TELL: float = 0.50
const GRAB_COMMIT: float = 0.22
const GRAB_RECOVER: float = 1.20
const SNARE_DURATION: float = 0.60
const WRIST_STAGGER_TIME: float = 1.20
const DUSK_SINK_TIME: float = 2.50
const NOTICE_TIME: float = 0.22

var tap_t: float = 0.0
var sunk_t: float = 0.0
var snare_t: float = 0.0
var grab_dir: Vector2 = Vector2.RIGHT
var grab_hit_done: bool = false


func _init() -> void:
	kind = "grave_hand"
	island_id = 1
	max_hp = 2.0
	hp = 2.0
	body_radius = 5.5
	routine_speed = 24.0
	leash_radius = 96.0
	notice_radius = GRAB_RANGE
	tell_time = GRAB_TELL
	recover_time = GRAB_RECOVER
	give_up_time = 1.8
	shard_drop = 2
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	tap_t = _randf_range(0.0, TAP_PERIOD)
	sunk_t = 0.0
	snare_t = 0.0
	grab_dir = Vector2.from_angle(facing)
	grab_hit_done = false


func is_targetable() -> bool:
	return is_alive() and sunk_t <= 0.0


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		# Dusk sinks the skeletal hand harmlessly underground for 2.5s!
		_release_token()
		sunk_t = DUSK_SINK_TIME
		snare_t = 0.0
		state = State.STAGGER
		state_timer = DUSK_SINK_TIME
		_emit_sfx("earth_burrow")
	elif t == "war":
		# War immediately resurfaces & enrages!
		sunk_t = 0.0
		cooldown = minf(cooldown, 0.20)
		if state == State.ROUTINE or state == State.STAGGER:
			_enter_notice()
	elif t == "dawn":
		if sunk_t <= 0.0:
			tap_t = 0.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null or sunk_t > 0.0:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_dash: bool = src == LxHit.SOURCE_DASH
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_heavy: bool = bool(h["stagger"]) or is_dash or is_throw

	# Dash snaps wrist for bonus damage & 1.2s stagger; Throw pins hand flat!
	if is_dash:
		dmg += 0.35
	snare_t = 0.0

	var is_opening: bool = state == State.RECOVER or state == State.STAGGER or is_dash or is_throw
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	knock = Vector2.ZERO # Rooted in grave soil

	if hp <= 0.001:
		opened_kill = is_opening
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else (1.40 if is_throw else WRIST_STAGGER_TIME)
		_emit_sfx("grave_wrist_snap")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	pos = home
	knock = Vector2.ZERO
	tap_t = fmod(tap_t + dt, TAP_PERIOD)
	if sunk_t > 0.0:
		sunk_t = maxf(0.0, sunk_t - dt)
		state_timer = maxf(0.0, state_timer - dt)
		if sunk_t <= 0.0:
			state = State.ROUTINE
		return

	# Gentle ankle snare pull while Wick is snared (0.6s after grab)
	if snare_t > 0.0:
		snare_t = maxf(0.0, snare_t - dt)
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			var to_h: Vector2 = pos - w.global_position
			if to_h.length() > 8.0 and to_h.length() < 64.0 and w.has_method("push_external"):
				w.call("push_external", to_h.normalized() * 68.0, "grave_hand_snare")

	match state:
		State.ROUTINE:
			if _has_player() and _get_wick_pos().distance_to(pos) <= GRAB_RANGE:
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
				_turn_toward(to_w.angle(), 6.0, dt)
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
				state = State.ROUTINE if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
				state = State.ROUTINE
		State.RETURN:
			state = State.ROUTINE


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.ROUTINE
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var wp: Vector2 = _get_wick_pos()
	var to_w: Vector2 = wp - pos
	var dist: float = to_w.length()
	if dist > 0.1:
		_turn_toward(to_w.angle(), 5.0, dt)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= GRAB_RANGE:
		if _claim_token():
			grab_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = grab_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(GRAB_TELL, false, attack_damage)
			state_timer = last_tell_duration
			grab_hit_done = false
			_emit_attack_started()
			_emit_sfx("earth_burrow")


func _step_tell(dt: float) -> void:
	if state_timer > 0.15 * _assist_tell_scale() and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 4.0, dt)
			grab_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = GRAB_COMMIT
		grab_hit_done = false
		_emit_sfx("grave_grab")


func _step_commit(dt: float) -> void:
	if not grab_hit_done and _has_player() and pos.distance_to(_get_wick_pos()) <= GRAB_HIT_R:
		grab_hit_done = true
		snare_t = SNARE_DURATION
		_emit_player_hit(grab_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, GRAB_RECOVER)
		last_recover_duration = state_timer


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(pos) > GRAB_RANGE + 24.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.55
	lost_t = 0.0
	_emit_sfx("earth_burrow")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.06, 34.0, 38.0, 36.0, 1.15, 0.18)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(4):
			var sd: Vector2 = Vector2.from_angle(float(si) * (PI * 0.5))
			Lx.player.call("spawn_sparks", pos, sd, 2, PAL["stone"] as Color, 24.0, 60.0, 0.25)


func _body_color() -> Color:
	return PAL["mauve"] as Color


func _draw() -> void:
	if state == State.DEAD:
		return
	if sunk_t > 0.0:
		# Sunk underground under Dusk hush — show quiet ice-rimmed dirt mound only!
		draw_circle(Vector2(0.0, 2.0), 8.0, PAL["night"] as Color)
		draw_arc(Vector2(0.0, 2.0), 8.5, 0.0, TAU, 14, PAL["ice"] as Color, 1.0)
		return
	super._draw()


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Finger tap ripple every 2.4s in routine
	if state == State.ROUTINE and tap_t < 0.30:
		var u: float = tap_t / 0.30
		draw_arc(Vector2(0.0, 2.0), 7.0 + u * 8.0, 0.0, TAU, 12, Color(PAL["stone"] as Color, 1.0 - u), 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, Vector2.ZERO, GRAB_HIT_R, prog, anim_t, "coral", "apricot")
	elif state == State.COMMIT:
		draw_arc(c, GRAB_HIT_R * 0.88, facing - 1.1, facing + 1.1, 14, PAL["coral"] as Color, 2.0)
	if snare_t > 0.0 and _has_player():
		var rel: Vector2 = (_get_wick_pos() - pos).round()
		draw_line(c, rel, PAL["apricot"] as Color, 2.0)
		draw_circle(rel, 3.0, PAL["gold"] as Color)
