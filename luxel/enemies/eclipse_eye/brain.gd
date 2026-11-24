class_name LxEclipseEyeBrain
extends LxEnemyBrain
## Island 8 Enemy: Eclipse Eye (Tactical Mirror-Beam Turret | HP 3.0 | Shards 4).
## Floating stained-glass oculus scanning slowly at 0.45 rad/s; locks on with coral cue
## (tell 0.54s) and fires a 148px eclipse beam that bends with LxFields Gravity Wells and
## reflects off blue_transformer / color_glass — bouncing its own beam (or a Prism bolt)
## into its iris triggers an instant 1-hit shatter!

const SCAN_RATE: float = 0.45
const BEAM_RANGE: float = 148.0
const BEAM_HALF_W: float = 6.5
const LOCK_TELL: float = 0.54
const BEAM_COMMIT: float = 0.34
const BEAM_RECOVER: float = 1.30
const NOTICE_TIME: float = 0.22

var _fire_dir: Vector2 = Vector2.RIGHT
var _beam_pts: PackedVector2Array = PackedVector2Array()
var _beam_hit_done: bool = false
var _dusk_frozen_t: float = 0.0


func _init() -> void:
	kind = "eclipse_eye"
	island_id = 8
	max_hp = 3.0
	hp = 3.0
	body_radius = 7.0
	routine_speed = 24.0
	leash_radius = 128.0
	notice_radius = 155.0
	tell_time = LOCK_TELL
	recover_time = BEAM_RECOVER
	give_up_time = 1.9
	shard_drop = 4
	attack_damage = 1.0


func is_flying() -> bool:
	return true


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_fire_dir = Vector2.from_angle(facing)
	_beam_pts = PackedVector2Array()
	_beam_hit_done = false
	_dusk_frozen_t = 0.0


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		_dusk_frozen_t = 2.2
		_beam_pts = PackedVector2Array()
		state = State.STAGGER
		state_timer = 2.2
		_emit_sfx("clockwork_chime")
	elif t == "war":
		_release_token()
		state = State.STAGGER
		state_timer = 1.6
		_emit_sfx("hush_shatter")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_prism: bool = src == LxHit.SOURCE_PRISM
	var is_heavy: bool = bool(h["stagger"]) or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_THROW

	# Prism-reflected bolt shatters the stained-glass iris in 1 hit!
	if is_prism:
		hp = 0.0
		opened_kill = true
		_beam_pts = PackedVector2Array()
		_emit_sfx("hush_shatter")
		LxDamageFx.boss_impact(pos, 0.14, 62.0, 68.0, 64.0, 1.32, 0.28)
		_die(hit)
		return HitResult.KILLED

	var is_opening: bool = state == State.RECOVER or state == State.STAGGER or is_heavy
	hp -= dmg * (1.25 if is_opening else 1.0)
	flash_t = 0.14 if is_heavy else 0.08
	knock = Vector2.ZERO

	if hp <= 0.001:
		opened_kill = is_opening
		_beam_pts = PackedVector2Array()
		_emit_sfx("hush_shatter")
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		_beam_pts = PackedVector2Array()
		state = State.STAGGER
		state_timer = 1.4 if src == LxHit.SOURCE_SUNFLARE else 1.05
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	pos = home
	knock = Vector2.ZERO
	_dusk_frozen_t = maxf(0.0, _dusk_frozen_t - dt)
	if _dusk_frozen_t > 0.0:
		state_timer = maxf(0.0, state_timer - dt)
		if state_timer <= 0.0:
			_dusk_frozen_t = 0.0
			state = State.ROUTINE
		return

	var sees: bool = _sees_wick()
	match state:
		State.ROUTINE:
			facing = wrapf(facing + SCAN_RATE * dt, -PI, PI)
			_fire_dir = Vector2.from_angle(facing)
			_beam_pts = PackedVector2Array()
			if sees:
				_enter_notice()
		State.NOTICE:
			if sees:
				_turn_toward((_get_wick_pos() - pos).angle(), 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			if not sees:
				lost_t += dt
				facing = wrapf(facing + SCAN_RATE * 1.4 * dt, -PI, PI)
				if lost_t >= give_up_time:
					_release_token()
					state = State.ROUTINE
					lost_t = 0.0
					return
			else:
				lost_t = 0.0
				_turn_toward((_get_wick_pos() - pos).angle(), 3.6, dt)
			var can_tok: bool = _can_claim_token()
			state = State.POSITION if can_tok else State.WAIT_TOKEN
			if sees and can_tok and cooldown <= 0.0 and _is_on_screen():
				if _claim_token():
					var to_w: Vector2 = _get_wick_pos() - pos
					_fire_dir = to_w.normalized() if to_w.length() > 0.1 else Vector2.from_angle(facing)
					facing = _fire_dir.angle()
					state = State.TELL
					is_counter_attack = false
					last_tell_duration = _scaled_tell(LOCK_TELL, false, attack_damage)
					state_timer = last_tell_duration
					_beam_hit_done = false
					_beam_pts = _trace_eclipse_beam(_fire_dir, false)
					_emit_attack_started()
					_emit_sfx("eclipse_lock")
		State.TELL:
			if sees and state_timer > 0.18:
				var to_w: Vector2 = _get_wick_pos() - pos
				if to_w.length() > 0.1:
					_turn_toward(to_w.angle(), 2.6, dt)
					_fire_dir = Vector2.from_angle(facing)
			_beam_pts = _trace_eclipse_beam(_fire_dir, false)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = BEAM_COMMIT
				_beam_hit_done = false
				_emit_sfx("eclipse_beam")
		State.COMMIT:
			_beam_pts = _trace_eclipse_beam(_fire_dir, true)
			if state == State.DEAD:
				return
			state_timer -= dt
			if state_timer <= 0.0:
				_beam_pts = PackedVector2Array()
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, BEAM_RECOVER)
				last_recover_duration = state_timer
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.90
				state = State.POSITION if sees else State.ROUTINE
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.ROUTINE
		State.RETURN:
			state = State.ROUTINE


func _sees_wick() -> bool:
	if not _has_player():
		return false
	var wp: Vector2 = _get_wick_pos()
	if pos.distance_to(wp) > notice_radius:
		return false
	return _has_clear_view(pos, wp)


func _trace_eclipse_beam(dir: Vector2, deal_damage: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cur_p: Vector2 = pos + dir * 8.0
	var cur_d: Vector2 = dir.normalized()
	pts.append(cur_p)
	var bounced: bool = false
	var step_len: float = 6.0
	var steps: int = int(BEAM_RANGE / step_len)
	var wp: Vector2 = _get_wick_pos()
	var has_p: bool = _has_player()
	var mirrors: Array[Object] = _collect_mirrors()

	for _si: int in range(steps):
		var acc: Vector2 = LxFields.accel_at(cur_p, "beam")
		if acc.length_squared() > 0.001:
			cur_d = (cur_d * 220.0 + acc * 0.03).normalized()
		var next_p: Vector2 = cur_p + cur_d * step_len
		if not _has_clear_view(cur_p, next_p):
			pts.append(next_p)
			break
		# Mirror / color_glass reflection check
		if not bounced:
			for m: Object in mirrors:
				var mp: Vector2 = m.get("pos") as Vector2 if m.get("pos") is Vector2 else (m as Node2D).global_position
				if Geometry2D.get_closest_point_to_segment(mp, cur_p, next_p).distance_to(mp) <= 12.0:
					var mn_v: Variant = m.call("get_reflect_normal") if m.has_method("get_reflect_normal") else Vector2.ZERO
					var mn: Vector2 = mn_v as Vector2 if (mn_v is Vector2 and (mn_v as Vector2).length_squared() > 0.01) else (pos - mp).normalized()
					cur_d = cur_d.bounce(mn.normalized()).normalized()
					cur_p = mp + cur_d * 8.0
					pts.append(mp)
					bounced = true
					_emit_sfx("prism_bounce")
					break
		# Self-reflection instant 1-hit shatter!
		if bounced and deal_damage and next_p.distance_to(pos) <= body_radius + 8.0:
			pts.append(pos)
			var self_hit := LxHit.make(LxHit.SOURCE_PRISM, max_hp * 2.0, cur_d, next_p, 2.0, true, true, self, true)
			take_hit(self_hit)
			return pts
		# Damage Wick along active beam
		if deal_damage and not _beam_hit_done and has_p:
			if Geometry2D.get_closest_point_to_segment(wp, cur_p, next_p).distance_to(wp) <= BEAM_HALF_W + 4.5:
				_beam_hit_done = true
				_emit_player_hit(cur_d)
		cur_p = next_p
		pts.append(cur_p)
	return pts


func _collect_mirrors() -> Array[Object]:
	var out: Array[Object] = []
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx != null and is_instance_valid(ctx) and ctx.has_method("get_interactables"):
			for it: Variant in (ctx.call("get_interactables") as Array):
				if it is Object and is_instance_valid(it):
					var ik: String = str((it as Object).get("kind"))
					if ik == "blue_transformer" or ik == "color_glass":
						out.append(it as Object)
			break
	return out


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("eclipse_lock")


func _body_color() -> Color:
	return PAL["coral"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if state == State.ROUTINE:
		# Dotted scanning sightline
		for k: int in range(1, 7):
			var dp: Vector2 = c + Vector2.from_angle(facing) * float(k * 16)
			draw_circle(dp.round(), 1.2, Color(PAL["gold"] as Color, 0.55))
	elif state == State.TELL and _beam_pts.size() >= 2:
		var local_pts := PackedVector2Array()
		for p: Vector2 in _beam_pts:
			local_pts.append((p - pos).round())
		var a: float = 0.65 if LxHudFx.flash_reduced() else (0.55 + 0.30 * sin(anim_t * 18.0))
		draw_polyline(local_pts, Color(PAL["coral"] as Color, a), 2.0)
	elif state == State.COMMIT and _beam_pts.size() >= 2:
		var local_pts := PackedVector2Array()
		for p: Vector2 in _beam_pts:
			local_pts.append((p - pos).round())
		draw_polyline(local_pts, PAL["coral"] as Color, 6.0)
		draw_polyline(local_pts, PAL["gold"] as Color, 3.2)
		draw_polyline(local_pts, PAL["cream"] as Color, 1.4)
	if _dusk_frozen_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.6)
