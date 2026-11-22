class_name LxForgeWardenBoss
extends LxCinderGolemBrain
## Ashen Kiln mini-boss (Island 6): Forge Warden.
## 2 phases, HP 8.5, heavy armour 3.5 (cracked by Sunflare).
## Phase 2 chains a Double Forge Quake shockwave ring before its long recovery.

enum QuakeStage { RING_1, PAUSE, RING_2 }

const FORGE_ARMOUR_MAX: float = 3.5
const FORGE_RING_MAX_R: float = 76.0
const FORGE_RING_BAND: float = 10.5
const FORGE_TRIGGER_R: float = 84.0
const QUAKE_PAUSE_TIME: float = 0.46
const PHASE2_ROAR_TIME: float = 0.60

var quake_stage: int = QuakeStage.RING_1
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "forge_warden"
	boss_id = "forge_warden"
	island_id = 6
	is_boss = true
	max_hp = 8.5
	hp = 8.5
	armour_max = FORGE_ARMOUR_MAX
	armour_hp = FORGE_ARMOUR_MAX
	body_radius = 8.5
	routine_speed = 26.0
	leash_radius = 150.0
	notice_radius = 132.0
	tell_time = 0.64
	recover_time = 1.45
	give_up_time = 1.1
	attack_damage = 1.5
	reach = FORGE_TRIGGER_R
	lunge_reach = FORGE_TRIGGER_R
	shard_drop = 18


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "forge_warden"))
	island_id = int(spec.get("island_id", 6))
	armour_max = maxf(1.0, float(spec.get("armour_hp", FORGE_ARMOUR_MAX)))
	armour_hp = armour_max
	armour_intact = true
	quake_stage = QuakeStage.RING_1
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var res: int = super.take_hit(hit)
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition() -> void:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		_roaring = true
		quake_stage = QuakeStage.RING_1
		stomp_progress = 0.0
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
			Lx.events.shake_requested.emit(0.28)
		_emit_sfx("forge_warden_phase2")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _try_start_attack(_target_pos: Vector2, dist: float) -> bool:
	if dist <= FORGE_TRIGGER_R and _claim_token():
		state = State.TELL
		lunge_attack = false
		is_counter_attack = false
		var base_t: float = 0.56 if phase >= 2 else tell_time
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		stomp_progress = 0.0
		stomp_hit = false
		quake_stage = QuakeStage.RING_1
		_emit_attack_started()
		_emit_sfx("golem_stomp_tell")
		return true
	return false


func _enter_commit() -> void:
	quake_stage = QuakeStage.RING_1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if quake_stage == QuakeStage.PAUSE:
		state_timer -= dt
		if state_timer <= 0.0:
			quake_stage = QuakeStage.RING_2
			state_timer = STOMP_COMMIT_TIME
			stomp_progress = 0.0
			stomp_hit = false
			_emit_sfx("golem_stomp_shockwave")
		return

	state_timer = maxf(0.0, state_timer - dt)
	stomp_progress = 1.0 - clampf(state_timer / STOMP_COMMIT_TIME, 0.0, 1.0)
	var max_r: float = FORGE_RING_MAX_R if (phase >= 2 or quake_stage == QuakeStage.RING_2) else STOMP_MAX_R + 6.0
	var ring_r: float = lerpf(STOMP_START_R, max_r, stomp_progress)
	if not stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= FORGE_RING_BAND:
			stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if quake_stage == QuakeStage.RING_1 and phase >= 2:
			quake_stage = QuakeStage.PAUSE
			state_timer = _scaled_tell(QUAKE_PAUSE_TIME, false, attack_damage)
			stomp_progress = 0.0
			stomp_hit = false
			_emit_sfx("golem_stomp_tell")
		else:
			quake_stage = QuakeStage.RING_1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _body_color() -> Color:
	if armour_intact:
		return (PAL["mauve"] as Color) if phase >= 2 else (PAL["stone"] as Color)
	return (PAL["apricot"] as Color) if phase >= 2 else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Glowing forge grate core
		draw_rect(Rect2(off + Vector2(-4.0, -3.0), Vector2(8.0, 5.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(off + Vector2(-3.0, -2.0), Vector2(6.0, 3.0)), (PAL["gold"] as Color) if not armour_intact else (PAL["coral"] as Color), true)
	if armour_intact:
		var plate_col: Color = (PAL["cream"] as Color) if clank_t > 0.0 else (PAL["mauve"] as Color)
		var ar: float = body_radius + 3.0
		for i: int in range(4):
			var a: float = PI * 0.25 + float(i) * (PI * 0.5)
			draw_arc(off, ar, a - 0.38, a + 0.38, 4, plate_col, 1.8)
	var c: Vector2 = off.round()
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var tr: float = lerpf(FORGE_RING_MAX_R, STOMP_START_R + 5.0, prog)
		draw_arc(c, tr + 2.0, 0.0, TAU, 28, PAL["coral"] as Color, 1.4)
		draw_arc(c, tr, 0.0, TAU, 28, PAL["apricot"] as Color, 1.8)
		draw_arc(c, maxf(3.0, tr - 2.0), 0.0, TAU, 24, PAL["gold"] as Color, 1.0)
	elif state == State.COMMIT:
		if quake_stage == QuakeStage.PAUSE:
			var pr: float = FORGE_RING_MAX_R * 0.48 + 2.0 * sin(anim_t * 18.0)
			draw_arc(c, pr + 2.2, 0.0, TAU, 24, PAL["coral"] as Color, 2.0)
			draw_arc(c, pr, 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
		else:
			var max_r: float = FORGE_RING_MAX_R if (phase >= 2 or quake_stage == QuakeStage.RING_2) else STOMP_MAX_R + 6.0
			var ring_r: float = lerpf(STOMP_START_R, max_r, stomp_progress)
			draw_arc(c, ring_r + 2.8, 0.0, TAU, 36, PAL["wine"] as Color, 2.5)
			draw_arc(c, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.8)
			draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
			draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)
			for si: int in range(8):
				var sa: float = anim_t * 1.9 + float(si) * (TAU / 8.0)
				var sd: Vector2 = Vector2.from_angle(sa)
				var st: Vector2 = Vector2(-sd.y, sd.x)
				var base_c: Vector2 = c + sd * maxf(2.0, ring_r - 1.0)
				var tip: Vector2 = (c + sd * (ring_r + 6.5)).round()
				draw_line((base_c - st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line((base_c + st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line(base_c.round(), tip, PAL["gold"] as Color, 1.2)
				draw_circle(tip, 1.1, PAL["apricot"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 16.0
		draw_arc(c, rr + 2.4, 0.0, TAU, 28, PAL["coral"] as Color, 2.2)
		draw_arc(c, rr, 0.0, TAU, 28, PAL["apricot"] as Color, 2.4)
		draw_arc(c, maxf(3.0, rr - 2.2), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)
