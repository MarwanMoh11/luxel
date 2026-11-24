class_name LxPewMimicBrain
extends LxEnemyBrain
## Island 1 Enemy: Pew Mimic (Ambush Bruiser, HP 4.0, Shards 4).
## Disguised carved chapel pew / manor bench (faint brass hinge-glint every 2.8s) snapping open
## at 42px (or 64px once roused) or on any WAR ring wave! Chomp-hops 165 px/s, then velvet mouth
## slams open for 1.35s (1.5x damage!). Throw into open jaw instant-staggers; Dusk clamps shut 2.0s!

const SNAP_RANGE_DORMANT: float = 48.0
const SNAP_RANGE_ROUSED: float = 72.0
const GLINT_PERIOD: float = 2.80
const CHOMP_TELL: float = 0.55
const CHOMP_COMMIT: float = 0.28
const CHOMP_RECOVER: float = 1.35
const CHOMP_SPEED: float = 165.0
const CHOMP_HIT_R: float = 22.0
const DUSK_CLAMP_TIME: float = 2.00
const JAW_STAGGER_TIME: float = 1.40
const NOTICE_TIME: float = 0.24

var dormant: bool = true
var dusk_clamped_t: float = 0.0
var glint_t: float = 0.0
var chomp_dir: Vector2 = Vector2.RIGHT
var chomp_hit_done: bool = false


func _init() -> void:
	kind = "pew_mimic"
	island_id = 1
	max_hp = 4.0
	hp = 4.0
	body_radius = 7.5
	routine_speed = 34.0
	leash_radius = 148.0
	notice_radius = SNAP_RANGE_ROUSED
	tell_time = CHOMP_TELL
	recover_time = CHOMP_RECOVER
	give_up_time = 2.1
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	dormant = true
	dusk_clamped_t = 0.0
	glint_t = _randf_range(0.0, GLINT_PERIOD)
	chomp_dir = Vector2.from_angle(facing)
	chomp_hit_done = false


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "war":
		# Any War wave immediately unmasks & rattles the mimic awake!
		dormant = false
		dusk_clamped_t = 0.0
		if state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
		_emit_sfx("warden_shield_break")
	elif t == "dusk":
		# Dusk clamps wooden lid tightly shut for 2.0s!
		_release_token()
		dusk_clamped_t = DUSK_CLAMP_TIME
		state = State.STAGGER
		state_timer = DUSK_CLAMP_TIME
		_emit_sfx("clockwork_chime")
	elif t == "dawn":
		glint_t = 0.0


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_heavy: bool = bool(h["stagger"]) or is_throw
	var mouth_open: bool = state == State.RECOVER or state == State.STAGGER or state == State.COMMIT

	# Closed stone pew lid resists chips (0.6x), open velvet mouth takes 1.5x damage!
	if dusk_clamped_t > 0.0 or (dormant and state == State.ROUTINE and not is_heavy):
		dmg *= 0.65
		clank_t = 0.12
	elif mouth_open:
		dmg *= 1.5

	dormant = false
	hp -= dmg
	flash_t = 0.15 if (mouth_open or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = mouth_open or is_heavy
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	# Throw into open velvet jaw (or heavy hit) instant-staggers!
	if (is_throw and (mouth_open or state == State.TELL)) or is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else JAW_STAGGER_TIME
		_emit_sfx("heavy_hit")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if mouth_open else HitResult.CHIPPED)
	return HitResult.OPENED if mouth_open else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	dusk_clamped_t = maxf(0.0, dusk_clamped_t - dt)
	glint_t = fmod(glint_t + dt, GLINT_PERIOD)

	match state:
		State.ROUTINE:
			# Dormant stone pew (0 px/s) waiting for Wick within snap range
			if _has_player():
				var wp: Vector2 = _get_wick_pos()
				var snap_r: float = SNAP_RANGE_DORMANT if dormant else SNAP_RANGE_ROUSED
				if wp.distance_to(pos) <= snap_r:
					dormant = false
					_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
				_turn_toward(to_w.angle(), 5.2, dt)
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
				cooldown = 0.65
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
		if dist > 46.0:
			_move_step(to_w.limit_length(routine_speed * 0.85 * dt), false)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and dusk_clamped_t <= 0.0 and _is_on_screen() and dist <= SNAP_RANGE_ROUSED + 12.0:
		if _claim_token():
			chomp_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = chomp_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(CHOMP_TELL, false, attack_damage)
			state_timer = last_tell_duration
			chomp_hit_done = false
			_emit_attack_started()
			_emit_sfx("pew_creak")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 3.2, dt)
			chomp_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = CHOMP_COMMIT
		chomp_hit_done = false
		_emit_sfx("pew_chomp")


func _step_commit(dt: float) -> void:
	_move_step(chomp_dir * CHOMP_SPEED * dt, false)
	if not chomp_hit_done and _has_player() and pos.distance_to(_get_wick_pos()) <= CHOMP_HIT_R:
		chomp_hit_done = true
		_emit_player_hit(chomp_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, CHOMP_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		dormant = true
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.5, dt)
	_move_step(to_h.limit_length(routine_speed * 0.92 * dt), false)
	if _has_player() and _get_wick_pos().distance_to(pos) <= SNAP_RANGE_DORMANT:
		dormant = false
		_enter_notice()


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.70
	lost_t = 0.0
	_emit_sfx("pew_creak")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 44.0, 50.0, 46.0, 1.24, 0.24)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["rose"] if si % 2 == 0 else PAL["gold"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 30.0, 76.0, 0.30)


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Subtle brass hinge glint every 2.8s while disguised!
	if state == State.ROUTINE and glint_t < 0.28:
		var gp: Vector2 = (c + Vector2(8.0, -5.0)).round()
		draw_line(gp + Vector2(-2.0, 0.0), gp + Vector2(2.0, 0.0), PAL["gold"] as Color, 1.0)
		draw_line(gp + Vector2(0.0, -2.0), gp + Vector2(0.0, 2.0), PAL["cream"] as Color, 1.0)
	if dusk_clamped_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.8)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, chomp_dir * (CHOMP_SPEED * CHOMP_COMMIT), 12.0, prog, anim_t, "coral", "gold")
	elif state == State.RECOVER:
		# Highlight vulnerable open velvet jaw!
		var glow_a: float = 0.45 if LxHudFx.flash_reduced() else (0.45 + 0.25 * sin(anim_t * 10.0))
		draw_arc(c, body_radius + 3.0, 0.0, TAU, 14, Color(PAL["rose"] as Color, glow_a), 1.4)
