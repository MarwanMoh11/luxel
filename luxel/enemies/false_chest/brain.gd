class_name LxFalseChestBrain
extends LxEnemyBrain
## Island 7 Enemy: False Chest (Ambush Mimic, HP 4.5, Shards 7).
## Disguised silver Moon Shoals chest betrayed by its NW shadow & 3.0s clasp glint!
## Routine: still (0 px/s). Wakes at 38px (or hit / Lens pulse). Bite-leap 175 px/s,
## jaw wide open (1.30s recover, 1.5x dmg). Throw into jaw staggers 1.8s; Sunflare flips lid-down.

const WAKE_RANGE_DORMANT: float = 42.0
const WAKE_RANGE_ROUSED: float = 72.0
const GLINT_PERIOD: float = 3.00
const BITE_TELL: float = 0.52
const BITE_COMMIT: float = 0.28
const BITE_RECOVER: float = 1.30
const BITE_SPEED: float = 175.0
const BITE_HIT_R: float = 24.0
const JAW_STAGGER: float = 1.80
const NOTICE_TIME: float = 0.24

var dormant: bool = true
var glint_t: float = 0.0
var _lens_exposed_t: float = 0.0
var _bite_dir: Vector2 = Vector2.RIGHT
var _bite_hit: bool = false


func _init() -> void:
	kind = "false_chest"
	island_id = 7
	max_hp = 4.5
	hp = 4.5
	body_radius = 7.5
	routine_speed = 32.0
	leash_radius = 148.0
	notice_radius = WAKE_RANGE_ROUSED
	tell_time = BITE_TELL
	recover_time = BITE_RECOVER
	give_up_time = 2.1
	shard_drop = 7
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	dormant = true
	glint_t = _randf_range(0.0, GLINT_PERIOD)
	_lens_exposed_t = 0.0
	_bite_dir = Vector2.from_angle(facing)
	_bite_hit = false


func on_light(_a: Variant, _b: Variant = Vector2.ZERO, source: String = "") -> void:
	if state == State.DEAD:
		return
	if source == "lens":
		_trigger_lens_expose()


func _trigger_lens_expose() -> void:
	if _lens_exposed_t > 0.0:
		return
	_lens_exposed_t = 2.5
	if dormant:
		dormant = false
		_release_token()
		state = State.STAGGER
		state_timer = 1.05
		_emit_sfx("lens_reveal")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_throw: bool = src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]
	var is_sunflare: bool = src == LxHit.SOURCE_SUNFLARE
	var is_heavy: bool = bool(h["stagger"]) or is_throw or is_sunflare or src == LxHit.SOURCE_BEAM
	var jaw_open: bool = state in [State.RECOVER, State.STAGGER, State.COMMIT]

	if dormant and state == State.ROUTINE and not is_heavy:
		dmg *= 0.70
		clank_t = 0.12
	elif jaw_open or is_sunflare:
		dmg *= 1.50

	dormant = false
	hp -= dmg
	flash_t = 0.15 if (jaw_open or is_heavy) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (120.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = jaw_open or is_heavy
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if (is_throw and (jaw_open or state == State.TELL)) or is_sunflare or is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = JAW_STAGGER if (is_throw or is_sunflare) else 0.75
		_emit_sfx("heavy_hit" if not is_sunflare else "sunflare_burst")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if jaw_open else HitResult.CHIPPED)
	return HitResult.OPENED if jaw_open else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_lens_exposed_t = maxf(0.0, _lens_exposed_t - dt)
	glint_t = fmod(glint_t + dt, GLINT_PERIOD)
	if dormant and Lx.player != null and is_instance_valid(Lx.player):
		var ml: Variant = Lx.player.get("move_lens")
		if ml is Object and (ml as Object).has_method("is_pulse_active") and bool((ml as Object).call("is_pulse_active")):
			if pos.distance_to(_get_wick_pos()) <= 112.0:
				_trigger_lens_expose()

	match state:
		State.ROUTINE:
			if _has_player():
				var snap_r: float = WAKE_RANGE_DORMANT if dormant else WAKE_RANGE_ROUSED
				if _get_wick_pos().distance_to(pos) <= snap_r:
					dormant = false
					_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
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
		if dist > 44.0:
			_move_step((to_w / dist) * (routine_speed * 0.86) * dt, false)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= WAKE_RANGE_ROUSED + 14.0 and _claim_token():
		_bite_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _bite_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(BITE_TELL, false, attack_damage)
		state_timer = last_tell_duration
		_bite_hit = false
		_emit_attack_started()
		_emit_sfx("chest_creak")


func _step_tell(dt: float) -> void:
	if state_timer > 0.16 and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 3.0, dt)
			_bite_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = BITE_COMMIT
		_bite_hit = false
		_emit_sfx("chest_open")


func _step_commit(dt: float) -> void:
	_move_step(_bite_dir * BITE_SPEED * dt, false)
	if not _bite_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= BITE_HIT_R:
		_bite_hit = true
		_emit_player_hit(_bite_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, BITE_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		dormant = true
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.6, dt)
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _has_player() and _get_wick_pos().distance_to(pos) <= WAKE_RANGE_DORMANT:
		dormant = false
		_enter_notice()


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.72
	lost_t = 0.0
	_emit_sfx("chest_creak")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 46.0, 52.0, 46.0, 1.24, 0.24)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["ice"] if si % 2 == 0 else PAL["rose"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 32.0, 78.0, 0.28)


func _body_color() -> Color:
	return PAL["sky"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Explicit NW shadow cue while disguised (Island 7 Shadow-Truth Law!)
	if state == State.ROUTINE:
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 2.0), 8.0, 3.0, "nw_wrong", false)
		if glint_t < 0.28:
			var gp: Vector2 = (c + Vector2(3.0, -6.0)).round()
			draw_line(gp + Vector2(-2.0, 0.0), gp + Vector2(2.0, 0.0), PAL["gold"] as Color, 1.0)
			draw_line(gp + Vector2(0.0, -2.0), gp + Vector2(0.0, 2.0), PAL["cream"] as Color, 1.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, _bite_dir * (BITE_SPEED * BITE_COMMIT), 12.0, prog, anim_t, "coral", "gold")
	elif state == State.RECOVER:
		var glow_a: float = 0.45 if LxHudFx.flash_reduced() else (0.45 + 0.25 * sin(anim_t * 10.0))
		draw_arc(c, body_radius + 3.5, 0.0, TAU, 16, Color(PAL["rose"] as Color, glow_a), 1.5)
