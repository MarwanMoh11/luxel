class_name LxPortraitEyeBrain
extends LxEnemyBrain
## Island 1 Enemy: Portrait Eye (Stealth Sensor / Turret, HP 2.5, Shards 3).
## Wall/plinth gilt portrait sleeping in dark, waking on lit sources to sweep a 60 deg (110px)
## cone, emit logic signals to linked walls, and fire 210 px/s glare-bolts (bent by LxFields!).
## Bolt deals 2x when open; Shutter Hood hides Wick; Dusk freezes shut 2.5s; War cracks glass 3.0s.

signal gaze_signal_changed(powered: bool, source: LxEnemyBrain)

const CONE_RANGE: float = 112.0
const CONE_HALF_RAD: float = 0.5236 # 30 deg half -> 60 deg full cone
const SWEEP_RATE: float = 0.50
const SWEEP_HALF_ARC: float = 1.05
const GLARE_TELL: float = 0.52
const GLARE_COMMIT: float = 0.18
const GLARE_RECOVER: float = 1.25
const BOLT_SPEED: float = 210.0
const BOLT_RADIUS: float = 4.0
const BOLT_MAX_AGE: float = 1.35
const DUSK_FREEZE_TIME: float = 2.50
const WAR_CRACK_TIME: float = 3.00
const NOTICE_TIME: float = 0.24

var base_facing: float = PI * 0.5
var sweep_phase: float = 0.0
var sweep_dir: float = 1.0
var eye_open: bool = false
var signal_powered: bool = false
var target_ids: PackedStringArray = PackedStringArray()
var dusk_frozen_t: float = 0.0
var glass_cracked_t: float = 0.0
var light_seen_t: float = 0.0
var last_light_pos: Vector2 = Vector2.ZERO
var _fire_dir: Vector2 = Vector2.DOWN
var _fired_this_commit: bool = false
var _bolts: Array[Dictionary] = []


func _init() -> void:
	kind = "portrait_eye"
	island_id = 1
	max_hp = 2.5
	hp = 2.5
	body_radius = 7.0
	routine_speed = 24.0
	leash_radius = 128.0
	notice_radius = CONE_RANGE
	tell_time = GLARE_TELL
	recover_time = GLARE_RECOVER
	give_up_time = 1.8
	shard_drop = 3
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	base_facing = float(spec.get("facing", PI * 0.5))
	facing = base_facing
	sweep_phase = 0.0
	sweep_dir = 1.0
	eye_open = false
	signal_powered = false
	dusk_frozen_t = 0.0
	glass_cracked_t = 0.0
	light_seen_t = 0.0
	last_light_pos = home
	_fire_dir = Vector2.from_angle(facing)
	_fired_this_commit = false
	_bolts.clear()
	target_ids = PackedStringArray()
	var tids: Variant = spec.get("target_ids", [])
	if tids is Array:
		for tid: Variant in (tids as Array):
			var s: String = str(tid).strip_edges()
			if not s.is_empty():
				target_ids.append(s)
	var single_tid: String = str(spec.get("target_id", "")).strip_edges()
	if not single_tid.is_empty() and not target_ids.has(single_tid):
		target_ids.append(single_tid)


func on_light(a: Variant, b: Variant = Vector2.ZERO, _source: Variant = "") -> void:
	if state == State.DEAD or dusk_frozen_t > 0.0:
		return
	var orig: Vector2 = a as Vector2 if a is Vector2 else (b as Vector2 if b is Vector2 else _get_lantern_pos())
	var rad: float = float(b) if (b is float or b is int) else (float(a) if (a is float or a is int) else 96.0)
	if pos.distance_to(orig) <= maxf(rad, CONE_RANGE) + 12.0:
		light_seen_t = 0.45
		last_light_pos = orig


func on_ring(tone: String, _dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		# Freezes eye shut 2.5s (preserves current wired signal state cleanly!)
		_release_token()
		dusk_frozen_t = DUSK_FREEZE_TIME
		eye_open = false
		state = State.STAGGER
		state_timer = DUSK_FREEZE_TIME
		_emit_sfx("clockwork_chime")
	elif t == "war":
		# Shatters portrait glass for 3.0s stun + extra vulnerability!
		_release_token()
		glass_cracked_t = WAR_CRACK_TIME
		eye_open = true
		state = State.STAGGER
		state_timer = WAR_CRACK_TIME
		_set_signal_powered(false)
		_emit_sfx("portrait_glass_crack")
	elif t == "dawn":
		if dusk_frozen_t <= 0.0:
			eye_open = true
			light_seen_t = 1.2
			if state == State.ROUTINE:
				_enter_notice()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_bolt: bool = src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM
	var is_heavy: bool = bool(h["stagger"]) or bool(h["cracks_armour"])

	# Bolt deals 2x when eye is open or glass cracked; 0.5x when sleeping shut
	if is_bolt:
		dmg *= 2.0 if (eye_open or glass_cracked_t > 0.0) else 0.5
	elif glass_cracked_t > 0.0:
		dmg *= 1.35

	var is_opening: bool = eye_open or state == State.RECOVER or state == State.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	knock = Vector2.ZERO # Mounted on plinth/wall

	if hp <= 0.001:
		opened_kill = is_opening
		_set_signal_powered(false)
		_bolts.clear()
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		glass_cracked_t = maxf(glass_cracked_t, 1.4)
		eye_open = true
		state = State.STAGGER
		state_timer = 1.6 if src == LxHit.SOURCE_SUNFLARE else 1.15
		_emit_sfx("portrait_glass_crack")
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE and dusk_frozen_t <= 0.0:
		eye_open = true
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _step_brain(dt: float) -> void:
	pos = home
	knock = Vector2.ZERO
	dusk_frozen_t = maxf(0.0, dusk_frozen_t - dt)
	glass_cracked_t = maxf(0.0, glass_cracked_t - dt)
	light_seen_t = maxf(0.0, light_seen_t - dt)
	_step_bolts(dt)

	if dusk_frozen_t > 0.0:
		state_timer = maxf(0.0, state_timer - dt)
		if state_timer <= 0.0:
			dusk_frozen_t = 0.0
			state = State.ROUTINE
		return

	var lit_target: Dictionary = _detect_lit_target()
	var sees_light: bool = bool(lit_target["found"])
	_set_signal_powered(sees_light)

	match state:
		State.ROUTINE:
			# Sweep 60 deg cone at 0.5 rad/s looking for lit sources
			sweep_phase += dt * SWEEP_RATE * sweep_dir
			if absf(sweep_phase) >= SWEEP_HALF_ARC:
				sweep_phase = clampf(sweep_phase, -SWEEP_HALF_ARC, SWEEP_HALF_ARC)
				sweep_dir = -sweep_dir
			facing = wrapf(base_facing + sweep_phase, -PI, PI)
			eye_open = light_seen_t > 0.0 or sees_light
			if sees_light:
				_enter_notice()
		State.NOTICE:
			eye_open = true
			if sees_light:
				_turn_toward(((lit_target["pos"] as Vector2) - pos).angle(), 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			eye_open = true
			if not sees_light:
				lost_t += dt
				# Slowly scan around while searching
				facing = wrapf(facing + dt * SWEEP_RATE * 1.6, -PI, PI)
				if lost_t >= give_up_time:
					_release_token()
					eye_open = false
					state = State.ROUTINE
					lost_t = 0.0
					return
			else:
				lost_t = 0.0
				var tp: Vector2 = lit_target["pos"] as Vector2
				_turn_toward((tp - pos).angle(), 3.8, dt)

			var can_tok: bool = _can_claim_token()
			state = State.POSITION if can_tok else State.WAIT_TOKEN
			if sees_light and can_tok and cooldown <= 0.0 and _is_on_screen():
				if _claim_token():
					var tp2: Vector2 = lit_target["pos"] as Vector2
					_fire_dir = (tp2 - pos).normalized() if tp2.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
					facing = _fire_dir.angle()
					state = State.TELL
					is_counter_attack = false
					last_tell_duration = _scaled_tell(GLARE_TELL, false, attack_damage)
					state_timer = last_tell_duration
					_fired_this_commit = false
					_emit_attack_started()
					_emit_sfx("portrait_eye_blink")
		State.TELL:
			eye_open = true
			if sees_light and state_timer > 0.16:
				var tp3: Vector2 = lit_target["pos"] as Vector2
				if tp3.distance_to(pos) > 0.1:
					_turn_toward((tp3 - pos).angle(), 2.8, dt)
					_fire_dir = Vector2.from_angle(facing)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.COMMIT
				state_timer = GLARE_COMMIT
				_fired_this_commit = false
		State.COMMIT:
			eye_open = true
			if not _fired_this_commit:
				_fired_this_commit = true
				_spawn_glare_bolt(_fire_dir)
			state_timer -= dt
			if state_timer <= 0.0:
				eye_open = false
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, GLARE_RECOVER)
				last_recover_duration = state_timer
		State.RECOVER:
			eye_open = false
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.85
				state = State.POSITION if sees_light else State.ROUTINE
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = 0.65
				state = State.ROUTINE
		State.RETURN:
			state = State.ROUTINE


func _detect_lit_target() -> Dictionary:
	# Priority 1: Thrown / hung lantern in range (lures gaze & triggers linked walls!)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if _point_in_gaze(lp):
			return {"found": true, "pos": lp, "kind": "lantern"}
	# Priority 2: Lit Wick (Shutter Hood while unarmed makes Wick invisible!)
	var cloaked: bool = _is_lantern_out() and Lx.state != null and bool(Lx.state.story_flags.get("item_shutter_hood", false))
	if not cloaked and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if _point_in_gaze(wp):
			return {"found": true, "pos": wp, "kind": "wick"}
	return {"found": false, "pos": home, "kind": ""}


func _point_in_gaze(pt: Vector2) -> bool:
	var rel: Vector2 = pt - pos
	var dist: float = rel.length()
	if dist > CONE_RANGE:
		return false
	if dist > 26.0 and absf(angle_difference(facing, rel.angle())) > CONE_HALF_RAD + (0.45 if state != State.ROUTINE else 0.0):
		return false
	return _has_clear_view(pos, pt)


func _spawn_glare_bolt(dir: Vector2) -> void:
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.01 else Vector2.from_angle(facing)
	_bolts.append({
		"pos": pos + d * (body_radius + 3.0),
		"vel": d * BOLT_SPEED,
		"age": 0.0,
	})
	_emit_sfx("orrery_bolt")


func _step_bolts(dt: float) -> void:
	var has_p: bool = _has_player()
	var wp: Vector2 = _get_wick_pos() if has_p else Vector2.INF
	for i: int in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["age"] = float(b["age"]) + dt
		var bp: Vector2 = b["pos"] as Vector2
		var bv: Vector2 = b["vel"] as Vector2
		# Sample LxFields so wind / gravity wells bend glare-bolts!
		var accel: Vector2 = LxBossBolt.sample_fields(bp, world_ctx)
		if accel.length_squared() > 0.01:
			bv += accel * dt
			var spd: float = clampf(bv.length(), 70.0, 290.0)
			if bv.length_squared() > 0.01:
				bv = bv.normalized() * spd
		var next_p: Vector2 = bp + bv * dt
		b["pos"] = next_p
		b["vel"] = bv

		var hit_wall: bool = not _has_clear_view(bp, next_p)
		if has_p and next_p.distance_to(wp) <= BOLT_RADIUS + 6.0:
			_emit_player_hit(bv.normalized())
			_bolts.remove_at(i)
			continue
		if hit_wall or float(b["age"]) >= BOLT_MAX_AGE:
			_bolts.remove_at(i)


func _set_signal_powered(powered: bool) -> void:
	if signal_powered == powered:
		return
	signal_powered = powered
	gaze_signal_changed.emit(powered, self)
	var ctx: Node = world_ctx if (world_ctx != null and is_instance_valid(world_ctx)) else Lx.world
	if ctx != null and is_instance_valid(ctx):
		if ctx.has_method("notify") and not enemy_id.is_empty():
			ctx.call("notify", "signal:" + enemy_id, {"powered": powered, "id": enemy_id})
		if ctx.has_method("get_interactables") and not target_ids.is_empty():
			for it_v: Variant in (ctx.call("get_interactables") as Array):
				if not (it_v is Object) or not is_instance_valid(it_v as Object):
					continue
				var it: Object = it_v as Object
				var tid: String = str(it.get("id")) if it.get("id") != null else ""
				if target_ids.has(tid) and it.has_method("on_signal"):
					it.call("on_signal", enemy_id, powered)


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.60
	lost_t = 0.0
	_emit_sfx("portrait_eye_blink")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.06, 40.0, 44.0, 40.0, 1.18, 0.20)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		for si: int in range(5):
			var sd: Vector2 = Vector2.from_angle(float(si) * (TAU / 5.0))
			Lx.player.call("spawn_sparks", pos, sd, 2, PAL["gold"] as Color, 28.0, 68.0, 0.28)


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Vision gaze cone overlay (faint gold when scanning, coral on tell/alert!)
	if dusk_frozen_t <= 0.0 and state != State.STAGGER and state != State.RECOVER:
		var a0: float = facing - CONE_HALF_RAD
		var a1: float = facing + CONE_HALF_RAD
		var col: Color = (PAL["coral"] if (state == State.TELL or signal_powered) else PAL["gold"]) as Color
		var fill_a: float = 0.14 if LxHudFx.flash_reduced() else (0.22 if state == State.TELL else 0.12)
		var pts := PackedVector2Array([c])
		for si: int in range(9):
			var ang: float = lerpf(a0, a1, float(si) / 8.0)
			pts.append(c + Vector2.from_angle(ang) * CONE_RANGE)
		draw_colored_polygon(pts, Color(col, fill_a))
		draw_arc(c, CONE_RANGE, a0, a1, 12, Color(col, 0.55), 1.0)
	if dusk_frozen_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.8)
	elif glass_cracked_t > 0.0:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 14, PAL["coral"] as Color, 1.4)
	# Draw live glare-bolts
	for b: Dictionary in _bolts:
		var bp: Vector2 = ((b["pos"] as Vector2) - pos).round()
		draw_circle(bp, BOLT_RADIUS + 1.2, PAL["void"] as Color)
		draw_circle(bp, BOLT_RADIUS, PAL["coral"] as Color)
		draw_circle(bp, 1.8, PAL["cream"] as Color)
