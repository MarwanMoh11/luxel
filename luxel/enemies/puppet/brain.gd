class_name LxPuppetBrain
extends LxEnemyBrain
## Island 7 Enemy: Puppet (Tethered Marionette, HP 4.0, Shards 6).
## Suspended from an overhead rose-gold Anchor Spool — revives in 3.0s unless its cord is cut!
## Counters: Beam/Throw/Recall/Zip/Sunflare/Blue slices cord (2.0s collapse + 2x dmg, no revive);
## Lens / Black world exposes hidden spools brightly.

const NOTICE_TIME: float = 0.26
const SLASH_TELL: float = 0.52
const SLASH_COMMIT: float = 0.26
const SLASH_RECOVER: float = 1.15
const SLASH_SPEED: float = 195.0
const SLASH_HIT_R: float = 26.0
const COLLAPSE_STAGGER: float = 2.00
const REVIVE_DELAY: float = 3.00

var cord_intact: bool = true
var spool_pos: Vector2 = Vector2.ZERO
var spool_revealed_t: float = 0.0
var _reviving: bool = false
var _revive_t: float = 0.0
var _fray_hits: int = 0
var _sway_t: float = 0.0
var _slash_dir: Vector2 = Vector2.RIGHT
var _slash_hits_done: int = 0


func _init() -> void:
	kind = "puppet"
	island_id = 7
	max_hp = 4.0
	hp = 4.0
	body_radius = 6.5
	routine_speed = 28.0
	leash_radius = 148.0
	notice_radius = 130.0
	tell_time = SLASH_TELL
	recover_time = SLASH_RECOVER
	give_up_time = 2.1
	shard_drop = 6
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	cord_intact = true
	spool_pos = _to_vec2(spec.get("spool_pos", null), home + Vector2(0.0, -24.0))
	spool_revealed_t = 0.0
	_reviving = false
	_revive_t = 0.0
	_fray_hits = 0
	_sway_t = _randf_range(-PI, PI)
	_slash_dir = Vector2.from_angle(facing)
	_slash_hits_done = 0


func _is_black_world() -> bool:
	if Lx.vars == null:
		return false
	return Lx.vars.eval("world_face==black", island_id, "")


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	if state == State.DEAD:
		return
	if source == "lens" or source == "lantern_hung":
		spool_revealed_t = maxf(spool_revealed_t, 2.5)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var slices_cord: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_PRISM] or bool(h["pierce"]) or bool(h["cracks_armour"])
	var is_heavy: bool = bool(h["stagger"]) or slices_cord

	if cord_intact and slices_cord:
		cord_intact = false
		_reviving = false
		_revive_t = 0.0
		dmg *= 2.0
		_emit_sfx("cord_snap")
		LxDamageFx.boss_impact(pos, 0.10, 48.0, 56.0, 48.0, 1.26, 0.25)
	elif not cord_intact:
		dmg *= 1.5

	if _reviving and cord_intact:
		_fray_hits += 1
		if _fray_hits >= 2:
			cord_intact = false
			_reviving = false
			_emit_sfx("cord_snap")

	hp -= dmg
	flash_t = 0.15 if (slices_cord or not cord_intact) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (108.0 if is_heavy else 26.0)

	if hp <= 0.001:
		if cord_intact and not _reviving:
			# Revives in 3.0s unless finished / cord sliced!
			hp = 0.35
			_reviving = true
			_revive_t = REVIVE_DELAY
			_fray_hits = 0
			_release_token()
			state = State.STAGGER
			state_timer = REVIVE_DELAY
			_emit_sfx("shadow_whisper")
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		opened_kill = not cord_intact or state in [State.RECOVER, State.STAGGER]
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if slices_cord:
		_release_token()
		state = State.STAGGER
		state_timer = COLLAPSE_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if not cord_intact else HitResult.CHIPPED)
	return HitResult.OPENED if not cord_intact else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	spool_revealed_t = maxf(0.0, spool_revealed_t - dt)
	if _reviving:
		_revive_t -= dt
		if _revive_t <= 0.0:
			_reviving = false
			hp = max_hp * 0.65
			state = State.POSITION
			cooldown = 0.65
			_emit_sfx("shadow_whisper")
			return

	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _has_attention_target() and pos.distance_to(_attention_target()) <= notice_radius:
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.8, dt)
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
			if state_timer <= 0.0 and not _reviving:
				_release_token()
				cooldown = 0.65
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _step_routine(dt: float) -> void:
	_sway_t = wrapf(_sway_t + dt * 1.4, -PI, PI)
	var tgt: Vector2 = home + Vector2(sin(_sway_t) * 20.0, cos(_sway_t * 2.0) * 8.0)
	var d: Vector2 = tgt - pos
	if d.length() > 1.0:
		_move_step(d.limit_length(routine_speed * 0.80 * dt), false)
		_turn_toward(d.angle(), 3.2, dt)


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
		_turn_toward(to_t.angle(), 3.8, dt)
		if dist > 38.0:
			var jerk_s: float = 0.90 if fmod(anim_t, 0.65) < 0.42 else 0.25
			_move_step((to_t / dist) * (routine_speed * jerk_s) * dt, false)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and _is_on_screen() and dist <= 68.0 and _claim_token():
		_slash_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
		facing = _slash_dir.angle()
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(SLASH_TELL, false, attack_damage)
		state_timer = last_tell_duration
		_slash_hits_done = 0
		_emit_attack_started()
		_emit_sfx("shadow_whisper")


func _step_tell(dt: float) -> void:
	if state_timer > 0.18 and _has_attention_target():
		var to_t: Vector2 = _attention_target() - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 3.2, dt)
			_slash_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = SLASH_COMMIT
		_slash_hits_done = 0
		_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	var elapsed: float = SLASH_COMMIT - state_timer
	var cur_dir: Vector2 = _slash_dir.rotated(0.22 if elapsed < SLASH_COMMIT * 0.5 else -0.22)
	_move_step(cur_dir * SLASH_SPEED * dt, false)
	if _slash_hits_done == 0 and _has_player() and pos.distance_to(_get_wick_pos()) <= SLASH_HIT_R:
		_slash_hits_done = 1
		_emit_player_hit(cur_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SLASH_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.6, dt)
	_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
	if _has_attention_target() and _attention_target().distance_to(home) <= leash_radius * 0.85:
		_enter_notice()


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 24.0


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
	alert_t = 0.72
	lost_t = 0.0
	_emit_sfx("shadow_whisper")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 44.0, 50.0, 44.0, 1.24, 0.24)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(6):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 6.0))
			var col: Color = (PAL["rose"] if si % 2 == 0 else PAL["gold"]) as Color
			Lx.player.call("spawn_sparks", pos, sd, 2, col, 30.0, 74.0, 0.28)


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Glowing rose-gold Anchor Spool & taut marionette cord
	if cord_intact:
		var sp_l: Vector2 = (spool_pos - pos).round()
		var bright: bool = _is_black_world() or spool_revealed_t > 0.0 or _reviving
		var cord_c: Color = (PAL["cream"] if (_reviving and not LxHudFx.flash_reduced() and int(anim_t * 12.0) % 2 == 0) else (PAL["rose"] if bright else PAL["wine"])) as Color
		draw_line(c + Vector2(0.0, -14.0), sp_l, cord_c, 1.4 if bright else 1.0)
		draw_circle(sp_l, 3.5 if bright else 2.5, PAL["gold"] as Color)
		draw_circle(sp_l, 1.6, PAL["cream"] as Color if bright else PAL["rose"] as Color)
		if _reviving:
			var r_prog: float = 1.0 - clampf(_revive_t / REVIVE_DELAY, 0.0, 1.0)
			draw_arc(c, body_radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * r_prog, 16, PAL["rose"] as Color, 1.8)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, _slash_dir * (SLASH_SPEED * SLASH_COMMIT), 11.0, prog, anim_t, "rose", "gold")
	elif state == State.COMMIT:
		draw_arc(c, body_radius + 14.0, facing - 1.15, facing + 1.15, 14, PAL["rose"] as Color, 2.2)
		draw_arc(c, body_radius + 11.5, facing - 0.95, facing + 0.95, 12, PAL["cream"] as Color, 1.2)
