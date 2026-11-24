class_name LxLighthouseHermitBoss
extends LxWardenBrain
## Tidewater Harbor Grand Boss (Island 2, `lighthouse_r10`): Upgraded 3-Phase Lighthouse Hermit.
## HP 34.0 (~97 bolts), lamp-shell shield 5.0.
## - P1: Sweeping Lamp Beam (reflects off LxMirrors into BLUE overcharge ray -> 1.2s stagger + 4.5s 1.5x crack!).
## - P2 (66%): Raises `tower_tide` -> "high", floods outer pockets, floats room mirrors (Ballast Clamp pins!),
##   & Tide Ring spawns 2 interactive Buoy Mines!
## - P3 (33%): Cupola shutters dim arena to dramatic twilight, adds Double-Sweep Counter-Spin &
##   Whirlpool Shell-Pull (LxFields inward pull — bat/pull mine into face for stagger!), & tiny crab leak beat!

const ArenaFx := preload("res://luxel/bosses/lighthouse_hermit/arena_fx.gd")

enum BossMove { NONE, LAMP_BEAM, TIDE_RING, WHIRLPOOL_PULL }
enum BeamStage { SWEEP_1, COUNTER_PAUSE, SWEEP_2 }

const BEAM_TELL_P1: float = 0.65
const BEAM_TELL_P3: float = 0.56
const BEAM_COMMIT_TIME: float = 0.68
const BEAM_REVERSE_PAUSE: float = 0.42
const BEAM_REVERSE_TIME: float = 0.56
const BEAM_RANGE: float = 142.0
const BEAM_HALF_W: float = 9.0
const BEAM_SWEEP_ARC_P1: float = 1.25
const BEAM_SWEEP_ARC_P3: float = 1.55
const BEAM_RECOVER_P1: float = 1.30
const BEAM_RECOVER_P3: float = 1.05
const BEAM_CD_P1: float = 3.8
const BEAM_CD_P3: float = 2.6
const SELF_REFLECT_STAGGER: float = 1.20
const LAMP_CRACK_DURATION: float = 4.50
const LAMP_CRACK_MULT: float = 1.50
const TIDE_TELL_P2: float = 0.62
const TIDE_TELL_P3: float = 0.54
const TIDE_COMMIT_TIME: float = 0.30
const TIDE_START_R: float = 10.0
const TIDE_MAX_R: float = 74.0
const TIDE_BAND: float = 10.0
const TIDE_RECOVER_P2: float = 1.25
const TIDE_RECOVER_P3: float = 1.05
const TIDE_CD_P2: float = 4.2
const TIDE_CD_P3: float = 3.0
const PULL_TELL_P3: float = 0.60
const PULL_COMMIT_TIME: float = 0.50
const PULL_RECOVER_P3: float = 1.25
const PULL_CD_P3: float = 4.6
const ROAR_TIME: float = 0.70

var active_move: int = BossMove.NONE
var beam_stage: int = BeamStage.SWEEP_1
var beam_cd: float = 1.2
var tide_cd: float = 2.0
var pull_cd: float = 2.4
var sweep_start_ang: float = 0.0
var sweep_dir: float = 1.0
var beam_angle: float = 0.0
var beam_hit: bool = false
var beam_hit_len: float = BEAM_RANGE
var reflected_active: bool = false
var reflect_origin: Vector2 = Vector2.ZERO
var reflect_end: Vector2 = Vector2.ZERO
var reflect_dir_v: Vector2 = Vector2.RIGHT
var lamp_cracked_t: float = 0.0
var _beam_light_t: float = 0.0
var _mirror_ping_t: float = 0.0
var tide_progress: float = 0.0
var tide_hit: bool = false
var pull_hit: bool = false
var _roaring: bool = false
var _arena: ArenaFx = null


func _init() -> void:
	super._init()
	kind = "lighthouse_hermit"; boss_id = "lighthouse_hermit"; island_id = 2; is_boss = true
	max_hp = 34.0; hp = 34.0; shield_max = 5.0; shield_hp = 5.0; shield_gone_duration = 4.8
	body_radius = 8.5; routine_speed = 34.0; leash_radius = 185.0; notice_radius = 152.0
	reach = 44.0; lunge_reach = 104.0; swing_r = 34.0; swing_arc = 1.28
	tell_time = 0.50; lunge_tell_time = 0.56; recover_time = 1.20; give_up_time = 1.8; shard_drop = 34


func _exit_tree() -> void:
	if _arena != null:
		_arena.cleanup()


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	if _arena == null:
		_arena = ArenaFx.new(self)
	_arena.cleanup()
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "lighthouse_hermit"))
	island_id = int(spec.get("island_id", 2))
	if not spec.has("max_hp") and not spec.has("data"):
		max_hp = 34.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
		hp = max_hp
	if not spec.has("shield_hp") and not spec.has("data"):
		shield_max = 5.0; shield_hp = 5.0
	active_move = BossMove.NONE; beam_stage = BeamStage.SWEEP_1
	beam_cd = 1.2; tide_cd = 2.0; pull_cd = 2.4
	sweep_start_ang = facing; sweep_dir = 1.0; beam_angle = facing
	beam_hit = false; beam_hit_len = BEAM_RANGE; reflected_active = false
	reflect_origin = pos; reflect_end = pos; reflect_dir_v = Vector2.RIGHT
	lamp_cracked_t = 0.0; _mirror_ping_t = 0.0; tide_progress = 0.0
	tide_hit = false; pull_hit = false; _roaring = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null: return HitResult.GLANCED
	if _roaring: _emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	if is_blue_hit and _has_active_shield():
		var mult: float = LAMP_CRACK_MULT if lamp_cracked_t > 0.0 else 1.25
		var dmg: float = float(h["damage"]) * mult
		var rel: Vector2 = (h["origin"] as Vector2) - pos
		hp -= dmg; wary = true; flash_t = 0.16
		if rel.length() > 0.01: knock = -rel.normalized() * 44.0
		if hp <= 0.001: opened_kill = true; _die(hit); return HitResult.KILLED
		if not _on_damaged_alive(hit) and (state == State.ROUTINE or state == State.RETURN):
			_enter_notice()
		_emit_sfx("hermit_prism_bank_hit"); _emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	var hp_before: float = hp
	var res: int = super.take_hit(hit)
	if is_alive() and lamp_cracked_t > 0.0 and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		var dealt: float = maxf(0.0, hp_before - hp)
		if dealt > 0.001:
			hp -= dealt * (LAMP_CRACK_MULT - 1.0)
			if hp <= 0.001: opened_kill = true; _die(hit); return HitResult.KILLED
			_on_damaged_alive(hit)
	return res


func _die(hit: Object) -> void:
	if _arena != null: _arena.cleanup()
	LxDamageFx.boss_impact(pos, 0.24, 96.0, 88.0, 128.0, 1.55, 0.55, "gold")
	super._die(hit)


func _is_hit_invulnerable() -> bool: return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001: _enter_phase(2); return true
	if phase < 3 and hp <= max_hp * 0.33 and hp > 0.001: _enter_phase(3); return true
	return false


func _enter_phase(next_phase: int) -> void:
	phase = next_phase; wary = false; _roaring = true
	active_move = BossMove.NONE; beam_stage = BeamStage.SWEEP_1
	reflected_active = false; lunge_attack = false; is_counter_attack = false; tide_progress = 0.0
	if _arena != null: _arena.set_pull_active(false)
	_release_token(); state = State.NOTICE; state_timer = ROAR_TIME
	beam_cd = 0.85; tide_cd = 0.45; pull_cd = 1.6
	if phase == 2 and _arena != null: _arena.apply_p2_tower_tide()
	elif phase == 3 and _arena != null: _arena.apply_p3_eclipse()
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.32)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("hermit_phase_roar")


func _step_brain(dt: float) -> void:
	beam_cd = maxf(0.0, beam_cd - dt); tide_cd = maxf(0.0, tide_cd - dt)
	pull_cd = maxf(0.0, pull_cd - dt); lamp_cracked_t = maxf(0.0, lamp_cracked_t - dt)
	_mirror_ping_t = maxf(0.0, _mirror_ping_t - dt)
	if _arena != null:
		var pulling: bool = (active_move == BossMove.WHIRLPOOL_PULL and state == State.COMMIT)
		_arena.tick_mirrors_and_mines(dt, pulling, _on_tide_mine_hit)
	super._step_brain(dt)


func _on_tide_mine_hit() -> void:
	hp = maxf(0.5, hp - 3.5)
	lamp_cracked_t = maxf(lamp_cracked_t, LAMP_CRACK_DURATION)
	_release_token(); active_move = BossMove.NONE; state = State.STAGGER; state_timer = SELF_REFLECT_STAGGER
	if _arena != null: _arena.set_pull_active(false)
	_emit_sfx("hermit_self_reflect_stagger")
	LxDamageFx.boss_impact(pos, 0.24, 88.0, 90.0, 92.0, 1.45, 0.36, "gold")


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01: _turn_toward(to_t.angle(), TURN_PATROL * 1.4, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false; state = State.POSITION; step_clock = 0.0; cooldown = 0.35


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if phase >= 3 and pull_cd <= 0.0 and dist < 148.0 and _claim_token():
		active_move = BossMove.WHIRLPOOL_PULL; lunge_attack = false; is_counter_attack = false
		state = State.TELL; last_tell_duration = _scaled_tell(PULL_TELL_P3, false, attack_damage)
		state_timer = last_tell_duration; pull_hit = false
		_emit_attack_started(); _emit_sfx("hermit_tide_tell"); return true
	if phase >= 2 and tide_cd <= 0.0 and dist < TIDE_MAX_R + 24.0 and _claim_token():
		active_move = BossMove.TIDE_RING; lunge_attack = false; is_counter_attack = false
		state = State.TELL; last_tell_duration = _scaled_tell(TIDE_TELL_P3 if phase >= 3 else TIDE_TELL_P2, false, attack_damage)
		state_timer = last_tell_duration; tide_progress = 0.0; tide_hit = false
		_emit_attack_started(); _emit_sfx("hermit_tide_tell"); return true
	if beam_cd <= 0.0 and dist < BEAM_RANGE + 14.0 and _claim_token():
		active_move = BossMove.LAMP_BEAM; beam_stage = BeamStage.SWEEP_1; reflected_active = false
		lunge_attack = false; is_counter_attack = false; state = State.TELL
		last_tell_duration = _scaled_tell(BEAM_TELL_P3 if phase >= 3 else BEAM_TELL_P1, false, attack_damage)
		state_timer = last_tell_duration; sweep_dir = -sweep_dir
		var to_t: Vector2 = target_pos - pos
		var aim_a: float = to_t.angle() if to_t.length() > 0.01 else facing
		var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
		sweep_start_ang = wrapf(aim_a - sweep_dir * (arc * 0.5), -PI, PI)
		beam_angle = sweep_start_ang; facing = aim_a; beam_hit = false; beam_hit_len = BEAM_RANGE
		_emit_attack_started(); _emit_sfx("hermit_beam_tell"); return true
	active_move = BossMove.NONE
	return super._try_start_attack(target_pos, dist)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if active_move == BossMove.LAMP_BEAM:
		if state_timer > 0.24:
			var to_t: Vector2 = target_pos - pos
			if to_t.length() > 0.01:
				var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
				sweep_start_ang = wrapf(to_t.angle() - sweep_dir * (arc * 0.5), -PI, PI)
				beam_angle = sweep_start_ang; facing = to_t.angle()
		state_timer -= dt
		if state_timer <= 0.0: _enter_commit()
		return
	if active_move == BossMove.TIDE_RING or active_move == BossMove.WHIRLPOOL_PULL:
		state_timer -= dt
		if state_timer <= 0.0: _enter_commit()
		return
	super._step_tell(dt, target_pos)


func _enter_commit() -> void:
	if active_move == BossMove.LAMP_BEAM:
		state = State.COMMIT; beam_stage = BeamStage.SWEEP_1; state_timer = BEAM_COMMIT_TIME
		beam_angle = sweep_start_ang; beam_hit = false; beam_hit_len = BEAM_RANGE; reflected_active = false; _beam_light_t = 0.0
		_boss_impact(0.16, 78.0, 72.0); _emit_sfx("hermit_beam_sweep"); return
	if active_move == BossMove.TIDE_RING:
		state = State.COMMIT; state_timer = TIDE_COMMIT_TIME; tide_progress = 0.0; tide_hit = false
		if _arena != null: _arena.spawn_tide_mines()
		_boss_impact(0.22, 96.0, 96.0); _emit_sfx("hermit_tide_fire"); return
	if active_move == BossMove.WHIRLPOOL_PULL:
		state = State.COMMIT; state_timer = PULL_COMMIT_TIME; pull_hit = false
		if _arena != null: _arena.set_pull_active(true)
		_boss_impact(0.18, 92.0, 90.0); _emit_sfx("bellows_inhale"); return
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == BossMove.LAMP_BEAM: _step_lamp_beam_commit(dt); return
	if active_move == BossMove.WHIRLPOOL_PULL:
		state_timer = maxf(0.0, state_timer - dt)
		if not pull_hit and _has_player() and _get_wick_pos().distance_to(pos) <= body_radius + 13.0:
			pull_hit = true; _emit_shockwave_hit((_get_wick_pos() - pos).normalized())
		if state_timer <= 0.0:
			if _arena != null: _arena.set_pull_active(false)
			active_move = BossMove.NONE; state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, PULL_RECOVER_P3); last_recover_duration = state_timer; pull_cd = PULL_CD_P3
		return
	if active_move == BossMove.TIDE_RING:
		state_timer = maxf(0.0, state_timer - dt)
		tide_progress = 1.0 - clampf(state_timer / TIDE_COMMIT_TIME, 0.0, 1.0)
		var ring_r: float = lerpf(TIDE_START_R, TIDE_MAX_R, tide_progress)
		if not tide_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if absf(wv.length() - ring_r) <= TIDE_BAND:
				tide_hit = true; _emit_shockwave_hit(wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing))
		if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
		if state_timer <= 0.0:
			active_move = BossMove.NONE; tide_progress = 0.0; state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, TIDE_RECOVER_P3 if phase >= 3 else TIDE_RECOVER_P2)
			last_recover_duration = state_timer; tide_cd = TIDE_CD_P3 if phase >= 3 else TIDE_CD_P2
		return
	super._step_commit(dt)


func _step_lamp_beam_commit(dt: float) -> void:
	if beam_stage == BeamStage.COUNTER_PAUSE:
		reflected_active = false; state_timer -= dt
		if state_timer <= 0.0:
			beam_stage = BeamStage.SWEEP_2; state_timer = BEAM_REVERSE_TIME; beam_hit = false
			_boss_impact(0.16, 78.0, 72.0); _emit_sfx("hermit_beam_sweep")
		return
	state_timer = maxf(0.0, state_timer - dt)
	var dur: float = BEAM_REVERSE_TIME if beam_stage == BeamStage.SWEEP_2 else BEAM_COMMIT_TIME
	var prog: float = 1.0 - clampf(state_timer / maxf(dur, 0.05), 0.0, 1.0)
	var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
	beam_angle = wrapf(sweep_start_ang + sweep_dir * arc * prog, -PI, PI); facing = beam_angle
	var bdir: Vector2 = Vector2.from_angle(beam_angle)
	beam_hit_len = BEAM_RANGE; reflected_active = false
	var hit_mirror: LxMirror = _find_beam_mirror(bdir)
	if hit_mirror != null:
		beam_hit_len = clampf((hit_mirror.pos - pos).dot(bdir), body_radius + 4.0, BEAM_RANGE)
		if _mirror_ping_t <= 0.0:
			_mirror_ping_t = 0.18; hit_mirror.on_hit(LxHit.make(LxHit.SOURCE_BEAM, 0.0, bdir, pos))
		var rdir: Vector2 = hit_mirror.reflect_dir(bdir)
		if rdir.length_squared() > 0.01:
			reflected_active = true; reflect_origin = hit_mirror.pos; reflect_dir_v = rdir; reflect_end = hit_mirror.pos + rdir * BEAM_RANGE
			if Geometry2D.get_closest_point_to_segment(pos, reflect_origin + rdir * 8.0, reflect_end).distance_to(pos) <= body_radius + 7.5:
				_trigger_self_reflect_stagger(); return
	var bend: Vector2 = pos + bdir * beam_hit_len
	_beam_light_t -= dt
	if _beam_light_t <= 0.0:
		_beam_light_t = 0.14; LxDamageFx.boss_impact(pos + bdir * minf(66.0, beam_hit_len * 0.5), 0.0, 0.0, 0.0, 76.0, 1.38, 0.22)
	if not beam_hit and _has_player() and Geometry2D.get_closest_point_to_segment(_get_wick_pos(), pos, bend).distance_to(_get_wick_pos()) <= BEAM_HALF_W:
		beam_hit = true; _emit_player_hit(bdir)
	if _is_lantern_out() and Geometry2D.get_closest_point_to_segment(_get_lantern_pos(), pos, bend).distance_to(_get_lantern_pos()) <= BEAM_HALF_W + 2.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		reflected_active = false
		if beam_stage == BeamStage.SWEEP_1 and phase >= 3:
			beam_stage = BeamStage.COUNTER_PAUSE; state_timer = BEAM_REVERSE_PAUSE; sweep_dir = -sweep_dir; sweep_start_ang = beam_angle; beam_hit = false
			_emit_sfx("hermit_beam_tell")
		else:
			active_move = BossMove.NONE; beam_stage = BeamStage.SWEEP_1; state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, BEAM_RECOVER_P3 if phase >= 3 else BEAM_RECOVER_P1)
			last_recover_duration = state_timer; beam_cd = BEAM_CD_P3 if phase >= 3 else BEAM_CD_P1


func _find_beam_mirror(bdir: Vector2) -> LxMirror:
	var best: LxMirror = null; var best_proj: float = BEAM_RANGE
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx): continue
		var inters_v: Variant = ctx.call("get_interactables") if ctx.has_method("get_interactables") else ctx.get("interactables")
		if not (inters_v is Array): continue
		for it_v: Variant in (inters_v as Array):
			if not (it_v is LxMirror): continue
			var m: LxMirror = it_v as LxMirror
			if not is_instance_valid(m) or not m.is_reflective(): continue
			var rel: Vector2 = m.pos - pos; var proj: float = rel.dot(bdir)
			if proj <= body_radius + 2.0 or proj >= best_proj: continue
			if (rel - bdir * proj).length() <= maxf(m.size.x, m.size.y) * 0.62:
				best_proj = proj; best = m
	return best


func _trigger_self_reflect_stagger() -> void:
	active_move = BossMove.NONE; beam_stage = BeamStage.SWEEP_1; reflected_active = false
	lamp_cracked_t = LAMP_CRACK_DURATION; shield_hp = 0.0; shield_gone_t = shield_gone_duration
	shield_broken.emit(self, pos); _release_token(); state = State.STAGGER; state_timer = SELF_REFLECT_STAGGER
	beam_cd = BEAM_CD_P3 if phase >= 3 else BEAM_CD_P1
	LxDamageFx.boss_impact(pos, 0.28, 98.0, 102.0, 96.0, 1.50, 0.42, "ice")
	_emit_sfx("hermit_self_reflect_stagger")


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind; kind = "shockwave"; _emit_player_hit(push_dir); kind = prev_kind


func _post_recover_cooldown() -> float: return 0.60 if phase >= 3 else (0.78 if phase >= 2 else 0.92)
func _body_color() -> Color: return (PAL["coral"] if phase >= 3 else (PAL["blue"] if phase == 2 else PAL["teal"])) as Color
func _shield_color() -> Color: return PAL["gold"] as Color


func _draw_extra(off: Vector2) -> void:
	var lc: Vector2 = off.round()
	if _arena != null: _arena.draw_extras(self, off)
	if lamp_cracked_t > 0.0:
		draw_arc(lc, body_radius + 4.5, 0.0, TAU, 20, PAL["sky"] as Color, 1.8)
		draw_arc(lc, body_radius + 2.5, 0.0, TAU, 16, PAL["ice"] as Color, 1.1)
	if active_move == BossMove.WHIRLPOOL_PULL and (state == State.TELL or state == State.COMMIT):
		var pulling_now: bool = state == State.COMMIT
		var r_pull: float = 52.0 if pulling_now else lerpf(64.0, 22.0, 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0))
		draw_arc(lc, r_pull, anim_t * 3.0, anim_t * 3.0 + PI * 1.5, 24, PAL["coral" if pulling_now else "sky"] as Color, 2.0)
		draw_arc(lc, r_pull * 0.62, -anim_t * 4.0, -anim_t * 4.0 + PI * 1.4, 18, PAL["cream" if pulling_now else "ice"] as Color, 1.4)
	elif active_move == BossMove.LAMP_BEAM and (state == State.TELL or (state == State.COMMIT and beam_stage == BeamStage.COUNTER_PAUSE)):
		var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
		var end_a: float = sweep_start_ang + sweep_dir * arc
		var denom: float = BEAM_REVERSE_PAUSE if beam_stage == BeamStage.COUNTER_PAUSE else maxf(last_tell_duration, 0.05)
		var prog_b: float = 1.0 - clampf(state_timer / maxf(denom, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_sector(self, off, sweep_start_ang, end_a, minf(BEAM_RANGE, 108.0), prog_b, anim_t, "gold", "coral")
		_draw_sweep_mirror_glints(sweep_start_ang + sweep_dir * (arc * 0.5), arc * 0.5 + 0.12, prog_b)
	elif active_move == BossMove.LAMP_BEAM and state == State.COMMIT:
		var b_dir: Vector2 = Vector2.from_angle(beam_angle)
		var b_end: Vector2 = (off + b_dir * beam_hit_len).round()
		draw_line(lc, b_end, PAL["apricot"] as Color, 6.8)
		draw_line(lc, b_end, PAL["gold"] as Color, 3.8)
		draw_line(lc, b_end, PAL["cream"] as Color, 1.6)
		if reflected_active:
			var r0: Vector2 = (reflect_origin - pos + off).round(); var r1: Vector2 = (reflect_end - pos + off).round()
			draw_line(r0, r1, PAL["blue"] as Color, 5.0); draw_line(r0, r1, PAL["sky"] as Color, 3.0); draw_line(r0, r1, PAL["cream"] as Color, 1.2)
	elif active_move == BossMove.TIDE_RING and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, TIDE_MAX_R, prog, anim_t, "sky", "coral")
	elif active_move == BossMove.TIDE_RING and state == State.COMMIT:
		var ring_r: float = lerpf(TIDE_START_R, TIDE_MAX_R, tide_progress)
		draw_arc(off, ring_r + 2.4, 0.0, TAU, 36, PAL["blue"] as Color, 2.4)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
		draw_arc(off, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 18.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)


func _draw_sweep_mirror_glints(mid_a: float, half_arc: float, prog: float) -> void:
	var rad_d: float = 7.5 + (0.0 if LxHudFx.flash_reduced() else 1.5 * sin(anim_t * 18.0))
	var col_d: Color = (PAL["ice"] if prog > 0.50 else PAL["sky"]) as Color
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx): continue
		var inters_v: Variant = ctx.call("get_interactables") if ctx.has_method("get_interactables") else ctx.get("interactables")
		if not (inters_v is Array): continue
		for it_v: Variant in (inters_v as Array):
			if not (it_v is LxMirror) or not is_instance_valid(it_v as LxMirror): continue
			var m: LxMirror = it_v as LxMirror
			var rel: Vector2 = m.pos - pos
			if not m.is_reflective() or rel.length() <= body_radius + 2.0 or rel.length() > BEAM_RANGE + 8.0 or absf(angle_difference(mid_a, rel.angle())) > half_arc:
				continue
			var mp: Vector2 = rel.round()
			var pts: PackedVector2Array = PackedVector2Array([mp + Vector2(0.0, -rad_d), mp + Vector2(rad_d, 0.0), mp + Vector2(0.0, rad_d), mp + Vector2(-rad_d, 0.0), mp + Vector2(0.0, -rad_d)])
			draw_polyline(pts, PAL["void"] as Color, 2.6); draw_polyline(pts, col_d, 1.5); draw_circle(mp, 2.2, PAL["cream"] as Color)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	var rip: String = "ice" if active_move in [BossMove.TIDE_RING, BossMove.WHIRLPOOL_PULL] else ""
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.48, 0.40, rip)
