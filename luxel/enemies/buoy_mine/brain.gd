class_name LxBuoyMineBrain
extends LxEnemyBrain
## Buoy Mine (Island 2 — Living Physics Hazard):
## Bobs on its chain / slides on rolling decks. Shooting/hitting recoil-pushes it 48px
## (and Sluice Harpoon tows it!) while arming a 0.90s coral fuse -> 36px blast dealing
## 4.0 HP to ALL nearby enemies and cracking nearby cracked walls.
## Counterplay: Bolt/Throw bats like billiards, Prism bats multiple, Dash i-frames blast.

const BLAST_RADIUS: float = 36.0
const BLAST_ENEMY_DMG: float = 4.0
const RECOIL_PUSH_DIST: float = 48.0
const COMMIT_TIME: float = 0.18
const POST_COOLDOWN: float = 1.10

var _bob_t: float = 0.0
var _slide_vel: Vector2 = Vector2.ZERO
var _armed_by_player: bool = false
var _blast_done: bool = false
var _blast_ring_t: float = 0.0


func _init() -> void:
	kind = "buoy_mine"
	island_id = 2
	max_hp = 1.0
	hp = 1.0
	body_radius = 6.5
	routine_speed = 24.0
	leash_radius = 156.0
	notice_radius = 120.0
	tell_time = 0.90
	recover_time = 0.85
	give_up_time = 2.0
	shard_drop = 2
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_bob_t = _randf_range(0.0, TAU)
	_slide_vel = Vector2.ZERO
	_armed_by_player = false
	_blast_done = false
	_blast_ring_t = 0.0


func is_flying() -> bool:
	# Floats over water/tide channels cleanly.
	return true


func on_lantern_pull(pull_dir: Vector2, _src: String = "recall") -> void:
	if state == State.DEAD:
		return
	var d: Vector2 = pull_dir.normalized() if pull_dir.length_squared() > 0.001 else Vector2.RIGHT
	_slide_vel = d * 145.0
	_emit_sfx("mine_clang")


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var dir: Vector2 = h["dir"] as Vector2
	var orig: Vector2 = h["origin"] as Vector2
	var push_dir: Vector2 = dir.normalized() if dir.length_squared() > 0.001 else ((pos - orig).normalized() if pos.distance_to(orig) > 0.01 else Vector2.RIGHT)
	# Billiard recoil-push ~48px (slide decelerates at 360 px/s^2 -> v0^2/(2a) = 186^2/720 = 48px!)
	_slide_vel = push_dir * 186.0
	_armed_by_player = true
	hp -= dmg
	flash_t = 0.14
	_emit_sfx("mine_clang")

	if hp <= 0.001:
		opened_kill = true
		_detonate_aoe(true)
		_die(hit)
		return HitResult.KILLED

	# Arm the 0.90s coral fuse!
	if state != State.TELL and state != State.COMMIT:
		_claim_token(true)
		state = State.TELL
		is_counter_attack = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("mine_arm")
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _step_brain(dt: float) -> void:
	_bob_t += dt * 2.6
	_blast_ring_t = maxf(0.0, _blast_ring_t - dt)
	_step_slide_and_fields(dt)

	var target: Vector2 = _get_wick_pos()
	match state:
		State.ROUTINE:
			if pos.distance_to(home) > 6.0 and _slide_vel.length() < 4.0:
				_move_step((home - pos).limit_length(routine_speed * 0.55 * dt), true)
			if _has_player() and pos.distance_to(target) <= notice_radius and _has_clear_view(pos, target):
				state = State.NOTICE
				state_timer = 0.28
				alert_t = 0.60
				lost_t = 0.0
				_emit_sfx("mine_clang")
		State.NOTICE:
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_drift(dt, target)
		State.TELL:
			state_timer -= dt
			if state_timer <= 0.0:
				_enter_commit()
		State.COMMIT:
			state_timer -= dt
			if not _blast_done:
				_blast_done = true
				_detonate_aoe(_armed_by_player)
				if _armed_by_player:
					opened_kill = true
					_die(null)
					return
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = maxf(MIN_RECOVER_TIME, recover_time)
				last_recover_duration = state_timer
		State.RECOVER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				cooldown = POST_COOLDOWN
				state = State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token()
				state = State.POSITION
		State.RETURN:
			var to_h: Vector2 = home - pos
			if to_h.length() <= 4.0:
				pos = home
				state = State.ROUTINE
				lost_t = 0.0
			else:
				_move_step(to_h.limit_length(routine_speed * dt), true)


func _step_slide_and_fields(dt: float) -> void:
	var fa: Vector2 = LxFields.accel_at(pos, "block")
	if fa.length_squared() > 0.01:
		_slide_vel = (_slide_vel + fa * 0.25 * dt).limit_length(220.0)
	if Lx.vars != null:
		var lv: String = str(Lx.vars.resolve_var("list", island_id, zone, "")).to_lower()
		if lv == "port":
			_slide_vel.x = move_toward(_slide_vel.x, -26.0, 28.0 * dt)
		elif lv == "starboard":
			_slide_vel.x = move_toward(_slide_vel.x, 26.0, 28.0 * dt)
	if _slide_vel.length() > 1.0:
		_move_step(_slide_vel * dt, true)
		_slide_vel = _slide_vel.move_toward(Vector2.ZERO, 360.0 * dt)


func _step_drift(dt: float, target: Vector2) -> void:
	if not _has_player() or target.distance_to(home) > leash_radius + 12.0:
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 2.8, dt)

	var can_act: bool = _can_claim_token()
	state = State.POSITION if can_act else State.WAIT_TOKEN
	if can_act and cooldown <= 0.0 and dist <= 72.0 and _is_on_screen() and _claim_token():
		state = State.TELL
		is_counter_attack = false
		_armed_by_player = false
		last_tell_duration = _scaled_tell(tell_time, false, attack_damage)
		state_timer = last_tell_duration
		_emit_attack_started()
		_emit_sfx("mine_arm")
		return

	if dist > 28.0:
		_move_step(to_t.normalized() * (routine_speed * 0.72 * dt), true)


func _enter_commit() -> void:
	state = State.COMMIT
	state_timer = COMMIT_TIME
	_blast_done = false


func _detonate_aoe(friendly_fire: bool) -> void:
	_blast_ring_t = 0.28
	_emit_sfx("mine_blast")
	LxDamageFx.boss_impact(pos, 0.16, 66.0, 74.0, 70.0, 1.32, 0.28, "coral")
	if _has_player() and pos.distance_to(_get_wick_pos()) <= BLAST_RADIUS:
		var pdir: Vector2 = (_get_wick_pos() - pos).normalized() if pos.distance_to(_get_wick_pos()) > 0.1 else Vector2.DOWN
		_emit_player_hit(pdir, attack_damage)
	if friendly_fire and world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_enemies"):
			for ev: Variant in (world_ctx.call("get_enemies") as Array):
				if ev is LxEnemyBrain and ev != self and is_instance_valid(ev):
					var other: LxEnemyBrain = ev as LxEnemyBrain
					if other.is_alive() and other.pos.distance_to(pos) <= BLAST_RADIUS + other.body_radius:
						var odir: Vector2 = (other.pos - pos).normalized() if other.pos.distance_to(pos) > 0.1 else Vector2.RIGHT
						var bhit: LxHit = LxHit.make(LxHit.SOURCE_HAZARD, BLAST_ENEMY_DMG, odir, pos, 3.0, true, true, self, true)
						other.take_hit(bhit)
		# Crack nearby cracked walls/tiles when detonated by player
		if world_ctx.has_method("tile_at") and world_ctx.has_method("set_tiles"):
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var probe: Vector2 = pos + Vector2(float(dx) * 16.0, float(dy) * 16.0)
					if probe.distance_to(pos) <= BLAST_RADIUS + 8.0 and str(world_ctx.call("tile_at", probe)) == "cracked":
						var tx: int = int(floor(probe.x / 16.0))
						var ty: int = int(floor(probe.y / 16.0))
						world_ctx.call("set_tiles", Rect2i(tx, ty, 1, 1), "ground")


func _visual_offset() -> Vector2:
	return Vector2(0.0, sin(_bob_t) * 1.8)


func _body_color() -> Color:
	return PAL["coral"] as Color if state == State.TELL else (PAL["dusk"] as Color)


func _draw_extra(off: Vector2) -> void:
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, BLAST_RADIUS, prog, anim_t, "coral", "gold")
	if _blast_ring_t > 0.0:
		var frac: float = 1.0 - clampf(_blast_ring_t / 0.28, 0.0, 1.0)
		draw_arc(off, lerpf(10.0, BLAST_RADIUS, frac), 0.0, TAU, 20, PAL["gold"] as Color, 2.0)
		draw_arc(off, lerpf(6.0, BLAST_RADIUS * 0.78, frac), 0.0, TAU, 16, PAL["cream"] as Color, 1.0)
