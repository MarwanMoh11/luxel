class_name LxChoirGloamBrain
extends LxEnemyBrain
## Island 8 Enemy: Choir Gloam (Coordinated Ranged Pair | HP 2.5 | Shards 4).
## Tall eclipse-singer drifting outside light; harmonizes via LxAttackDirector — Singer A
## fires a crisp 3-bolt narrow lane (tell 0.56s), Singer B a staggered gap ring (tell 0.60s)
## with zero unfair overlap! Projectiles bend with LxFields. True Lens reveals (+35% dmg);
## Dusk Bell silences 2.2s; Throw interrupts; Dash i-frames.

const LANE_TELL: float = 0.56
const RING_TELL: float = 0.60
const CHORD_COMMIT: float = 0.26
const CHORD_RECOVER: float = 1.25
const BOLT_SPEED: float = 148.0
const BOLT_R: float = 3.6
const BOLT_MAX_AGE: float = 1.65
const NOTICE_TIME: float = 0.24

var _voice_role: int = 0 # 0 = Singer A (narrow lane), 1 = Singer B (staggered ring)
var _revealed_t: float = 0.0
var _silenced_t: float = 0.0
var _fire_dir: Vector2 = Vector2.RIGHT
var _fired_commit: bool = false
var _bolts: Array[Dictionary] = []


func _init() -> void:
	kind = "choir_gloam"
	island_id = 8
	max_hp = 2.5
	hp = 2.5
	body_radius = 6.0
	routine_speed = 40.0
	leash_radius = 160.0
	notice_radius = 145.0
	tell_time = LANE_TELL
	recover_time = CHORD_RECOVER
	give_up_time = 2.2
	shard_drop = 4
	attack_damage = 1.0


func is_flying() -> bool:
	return true


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_voice_role = int(spec.get("voice", slot % 2)) % 2
	_revealed_t = 0.0
	_silenced_t = 0.0
	_fire_dir = Vector2.from_angle(facing)
	_fired_commit = false
	_bolts.clear()


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if state == State.DEAD:
		return
	var orig: Vector2 = a as Vector2 if a is Vector2 else (b as Vector2 if b is Vector2 else _get_lantern_pos())
	var rad: float = float(b) if (b is float or b is int) else (float(a) if (a is float or a is int) else 72.0)
	if pos.distance_to(orig) <= rad + 8.0:
		var src_s: String = str(source).to_lower()
		if src_s.contains("lens"):
			_revealed_t = maxf(_revealed_t, 4.0)
			_emit_sfx("lens_reveal")
		else:
			_revealed_t = maxf(_revealed_t, 0.35)


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		_silenced_t = 2.2
		state = State.STAGGER
		state_timer = 2.2
		_emit_sfx("choir_silence")
	elif t == "dawn":
		_revealed_t = maxf(_revealed_t, 2.5)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_lens: bool = src == "lens"
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_heavy: bool = bool(h["stagger"]) or is_throw or src == LxHit.SOURCE_SUNFLARE

	if is_lens:
		_revealed_t = 4.0
		_emit_sfx("lens_reveal")
	if _revealed_t > 0.0:
		dmg *= 1.35

	var is_opening: bool = _revealed_t > 0.0 or _silenced_t > 0.0 or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (105.0 if is_heavy else 34.0)

	if hp <= 0.001:
		opened_kill = is_opening
		_bolts.clear()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if src == LxHit.SOURCE_SUNFLARE else 1.05
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	_revealed_t = maxf(0.0, _revealed_t - dt)
	_silenced_t = maxf(0.0, _silenced_t - dt)
	_step_bolts(dt)

	match state:
		State.ROUTINE:
			var want: Vector2 = home + Vector2(sin(anim_t * 1.1) * 24.0, sin(anim_t * 2.2) * 12.0)
			var step: Vector2 = (want - pos).limit_length(routine_speed * dt)
			if step.length() > 0.05:
				_turn_toward(step.angle(), 3.6, dt)
				_move_step(step, true)
			if _has_player() and pos.distance_to(_get_wick_pos()) <= notice_radius and _has_clear_view(pos, _get_wick_pos()):
				_enter_notice()
		State.NOTICE:
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.1:
				_turn_toward(to_w.angle(), 4.2, dt)
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
				_voice_role = 1 - _voice_role
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.60
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
		_turn_toward(to_w.angle(), 3.4, dt)
		# Drift gracefully along outer lamp edge (78-112px preferred)
		var pref: float = 92.0
		var rad_v: Vector2 = to_w / dist
		var step_v: Vector2 = rad_v * clampf((dist - pref) / 36.0, -0.75, 0.75) + rad_v.rotated(PI * 0.5) * (0.55 if _voice_role == 0 else -0.55)
		_move_step(step_v.normalized() * routine_speed * 0.88 * dt, true)

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and _silenced_t <= 0.0 and _is_on_screen() and dist <= notice_radius + 10.0 and _has_clear_view(pos, wp):
		if _claim_token():
			_fire_dir = to_w.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = _fire_dir.angle()
			state = State.TELL
			is_counter_attack = false
			var base_tell: float = LANE_TELL if _voice_role == 0 else RING_TELL
			last_tell_duration = _scaled_tell(base_tell, false, attack_damage)
			state_timer = last_tell_duration
			_fired_commit = false
			_emit_attack_started()
			_emit_sfx("choir_chord")


func _step_tell(dt: float) -> void:
	if state_timer > 0.18 * _assist_tell_scale() and _has_player():
		var to_w: Vector2 = _get_wick_pos() - pos
		if to_w.length() > 0.1:
			_turn_toward(to_w.angle(), 2.6, dt)
			_fire_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = CHORD_COMMIT
		_fired_commit = false
		_emit_sfx("choir_chord")


func _step_commit(dt: float) -> void:
	if not _fired_commit:
		_fired_commit = true
		if _voice_role == 0:
			# Singer A: narrow 3-note harmonic lane
			for s: int in range(-1, 2):
				var d: Vector2 = _fire_dir.rotated(float(s) * 0.14)
				_spawn_note(pos + d * 8.0, d * (BOLT_SPEED + (12.0 if s == 0 else 0.0)))
		else:
			# Singer B: staggered harmonic ring with wide safe gap facing away/sideways
			var base_a: float = _fire_dir.angle()
			for i: int in range(6):
				var a: float = base_a + 0.42 + float(i) * (TAU / 6.0)
				if absf(angle_difference(a, base_a)) < 0.35:
					continue
				var d: Vector2 = Vector2.from_angle(a)
				_spawn_note(pos + d * 8.0, d * (BOLT_SPEED * 0.88))
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, CHORD_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 6.0:
		pos = home
		state = State.ROUTINE
		lost_t = 0.0
		return
	_turn_toward(to_h.angle(), 3.6, dt)
	_move_step(to_h.limit_length(routine_speed * 0.95 * dt), true)


func _spawn_note(p: Vector2, v: Vector2) -> void:
	_bolts.append({"pos": p, "vel": v, "age": 0.0})


func _step_bolts(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	for i: int in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["age"] = float(b["age"]) + dt
		if float(b["age"]) >= BOLT_MAX_AGE:
			_bolts.remove_at(i)
			continue
		var bp: Vector2 = b["pos"] as Vector2
		var bv: Vector2 = b["vel"] as Vector2
		var acc: Vector2 = LxFields.accel_at(bp, "bolt")
		if acc.length_squared() > 0.001:
			bv += acc * dt
			bv = bv.normalized() * clampf(bv.length(), 85.0, 220.0)
		var next_p: Vector2 = bp + bv * dt
		if not _has_clear_view(bp, next_p):
			_bolts.remove_at(i)
			continue
		b["pos"] = next_p
		b["vel"] = bv
		if has_p and next_p.distance_to(wp) <= BOLT_R + 5.5:
			_emit_player_hit(bv.normalized())
			_bolts.remove_at(i)


func _should_give_up() -> bool:
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("gloam_notice")


func _body_color() -> Color:
	return PAL["deep"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if _revealed_t > 0.0:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 16, PAL["void"] as Color, 3.0)
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.0)
	if _silenced_t > 0.0:
		draw_arc(c, body_radius + 6.0, 0.0, TAU, 16, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 6.0, 0.0, TAU, 16, PAL["mauve"] as Color, 2.0)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		if _voice_role == 0:
			LxBossTelegraphFx.draw_ground_danger_lane(self, Vector2.ZERO, _fire_dir * 124.0, 8.0, prog, anim_t, "sky", "ice")
		else:
			LxBossTelegraphFx.draw_ground_danger_ring(self, Vector2.ZERO, 44.0, prog, anim_t, "sky", "ice")
	for b: Dictionary in _bolts:
		var rp: Vector2 = ((b["pos"] as Vector2) - pos).round()
		draw_circle(rp, BOLT_R + 2.0, PAL["void"] as Color)
		draw_circle(rp, BOLT_R + 1.0, PAL["deep"] as Color)
		draw_circle(rp, BOLT_R, PAL["sky"] as Color)
		draw_circle(rp, 1.8, PAL["cream"] as Color)
