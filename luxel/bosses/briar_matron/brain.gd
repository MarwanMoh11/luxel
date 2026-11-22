class_name LxBriarMatronBoss
extends LxBrambleKnightBrain
## Thornwood Hollow Boss (Island 3): the Briar Matron, a great beetle-spider.
## 3 phases, HP 12.5, web/thorn barrier 3.5.
## Beam burns/pierces her web barrier straight through for bonus damage + guard-break stagger.
## Combines lunging thorn swings, web-spore burst rings, and a 0.32s thorn counter.

const SPORE_TELL_P1: float = 0.60
const SPORE_TELL_P3: float = 0.52
const SPORE_COMMIT_TIME: float = 0.32
const SPORE_START_R: float = 10.0
const SPORE_MAX_R: float = 74.0
const SPORE_BAND: float = 9.5
const SPORE_RECOVER_P1: float = 1.25
const SPORE_RECOVER_P3: float = 1.05
const SPORE_CD_P1: float = 4.4
const SPORE_CD_P2: float = 3.2
const SPORE_CD_P3: float = 2.4
const ROAR_TIME: float = 0.68

var spore_burst_attack: bool = false
var spore_cd: float = 1.8
var spore_progress: float = 0.0
var spore_hit: bool = false
var swings_since_spore: int = 0
var _roaring: bool = false


func _init() -> void:
	super._init()
	kind = "briar_matron"
	boss_id = "briar_matron"
	island_id = 3
	is_boss = true
	max_hp = 12.5
	hp = 12.5
	shield_max = 3.5
	shield_hp = 3.5
	shield_gone_duration = 5.2
	body_radius = 8.5
	routine_speed = 34.0
	leash_radius = 185.0
	notice_radius = 152.0
	reach = 42.0
	lunge_reach = 104.0
	swing_r = 34.0
	swing_arc = 1.30
	tell_time = 0.50
	lunge_tell_time = 0.56
	recover_time = 1.20
	give_up_time = 1.8
	shard_drop = 30


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "briar_matron"))
	island_id = int(spec.get("island_id", 3))
	spore_burst_attack = false
	spore_cd = 1.8
	spore_progress = 0.0
	spore_hit = false
	swings_since_spore = 0
	_roaring = false


func take_hit(hit: LxHit) -> int:
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit) if hit != null else {}
	var is_beam_burn: bool = hit != null and (str(h.get("source", "")) == LxHit.SOURCE_BEAM or bool(h.get("pierce", false)))
	var had_shield: bool = _has_active_shield()
	var res: int = super.take_hit(hit)
	if is_alive() and is_beam_burn and had_shield and res == HitResult.OPENED:
		# Extra web-burn damage reward when Beam melts her web barrier
		hp = maxf(0.0, hp - float(h.get("damage", 0.0)) * 0.25)
		_emit_sfx("briar_web_burn")
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _is_hit_invulnerable() -> bool:
	return _roaring


func _on_damaged_alive(_hit: LxHit) -> bool:
	return _check_phase_transition()


func _check_phase_transition() -> bool:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001:
		_enter_phase(2)
		return true
	if phase < 3 and hp <= max_hp * 0.33 and hp > 0.001:
		_enter_phase(3)
		return true
	return false


func _enter_phase(next_phase: int) -> void:
	phase = next_phase
	wary = false
	_roaring = true
	spore_burst_attack = false
	thorn_burst_active = false
	lunge_attack = false
	is_counter_attack = false
	spore_progress = 0.0
	if phase == 3 and shield_gone_t > 0.0:
		shield_gone_t = 0.0
		shield_hp = shield_max * 0.65
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	spore_cd = 0.70
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.32)
	_emit_sfx("briar_matron_phase")


func _step_brain(dt: float) -> void:
	spore_cd = maxf(0.0, spore_cd - dt)
	super._step_brain(dt)


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.4, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false
		state = State.POSITION
		step_clock = 0.0
		cooldown = 0.35


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if spore_cd <= 0.0 and (phase >= 2 or swings_since_spore >= 1) and dist < SPORE_MAX_R + 20.0 \
			and _claim_token():
		spore_burst_attack = true
		thorn_burst_active = false
		lunge_attack = false
		is_counter_attack = false
		state = State.TELL
		var base_t: float = SPORE_TELL_P3 if phase >= 3 else SPORE_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		spore_progress = 0.0
		spore_hit = false
		swings_since_spore = 0
		_emit_attack_started()
		_emit_sfx("briar_spore_tell")
		return true
	spore_burst_attack = false
	return super._try_start_attack(target_pos, dist)


func _enter_commit() -> void:
	if spore_burst_attack:
		state = State.COMMIT
		state_timer = SPORE_COMMIT_TIME
		spore_progress = 0.0
		spore_hit = false
		_boss_impact(0.20, 94.0, 92.0)
		_emit_sfx("briar_spore_burst")
		return
	if not thorn_burst_active:
		swings_since_spore += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not spore_burst_attack:
		super._step_commit(dt)
		return
	state_timer = maxf(0.0, state_timer - dt)
	spore_progress = 1.0 - clampf(state_timer / SPORE_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(SPORE_START_R, SPORE_MAX_R, spore_progress)
	if not spore_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= SPORE_BAND:
			spore_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		spore_burst_attack = false
		spore_progress = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SPORE_RECOVER_P3 if phase >= 3 else SPORE_RECOVER_P1)
		last_recover_duration = state_timer
		spore_cd = SPORE_CD_P3 if phase >= 3 else (SPORE_CD_P2 if phase >= 2 else SPORE_CD_P1)


func _emit_shockwave_hit(push_dir: Vector2) -> void:
	var prev_kind: String = kind
	kind = "shockwave"
	_emit_player_hit(push_dir)
	kind = prev_kind


func _post_recover_cooldown() -> float:
	if phase >= 3:
		return 0.62
	if phase >= 2:
		return 0.78
	return 0.92


func _body_color() -> Color:
	if phase >= 3:
		return PAL["wine"] as Color
	if phase >= 2:
		return PAL["dusk"] as Color
	return PAL["pine"] as Color


func _shield_color() -> Color:
	return PAL["cream"] as Color


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	var fwd: Vector2 = Vector2.from_angle(facing)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	if _sprite_sheet == null:
		# Spider-beetle legs
		for s: float in [-1.0, 1.0]:
			for k: int in [-1, 0, 1]:
				var b_pt: Vector2 = off + side * (body_radius * s) + fwd * (float(k) * 3.0)
				draw_line(b_pt, b_pt + side * (5.0 * s) + fwd * (float(k) * 2.5), PAL["jade"] as Color, 1.5)
	# Glistening woven web-shield cross-strands while shield is active
	if _has_active_shield():
		var w_in: Vector2 = off + fwd * (body_radius + 1.5)
		var w_mid: Vector2 = off + fwd * (body_radius + 4.0)
		var w_out: Vector2 = off + fwd * (body_radius + 6.5)
		var w_col: Color = (PAL["cream"] if clank_t > 0.0 else PAL["ice"]) as Color
		draw_line((w_mid - side * 9.0).round(), (w_mid + side * 9.0).round(), PAL["stone"] as Color, 1.5)
		draw_line((w_in - side * 7.5).round(), (w_out + side * 7.5).round(), w_col, 1.1)
		draw_line((w_in + side * 7.5).round(), (w_out - side * 7.5).round(), w_col, 1.1)
		draw_line((w_out - side * 5.0).round(), (w_out + side * 5.0).round(), PAL["cream"] as Color, 1.0)
		for wi: int in range(-1, 2):
			var anchor: Vector2 = w_in + side * (float(wi) * 4.5)
			draw_line(anchor.round(), (anchor + fwd * 5.0).round(), PAL["ice"] as Color, 1.0)
		draw_circle((w_mid + side * (sin(anim_t * 5.0) * 2.0)).round(), 1.2, PAL["cream"] as Color)
	if spore_burst_attack and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ti: int in range(12):
			var a0: float = float(ti) * (TAU / 12.0)
			draw_arc(off, SPORE_MAX_R, a0, a0 + 0.24, 3, PAL["jade"] as Color, 1.0)
		draw_arc(off, lerpf(SPORE_MAX_R, SPORE_START_R + 6.0, prog), 0.0, TAU, 28, (PAL["cream"] if state_timer <= 0.14 else PAL["lime"]) as Color, 1.8)
	elif spore_burst_attack and state == State.COMMIT:
		var ring_r: float = lerpf(SPORE_START_R, SPORE_MAX_R, spore_progress)
		draw_arc(off, ring_r + 2.6, 0.0, TAU, 36, PAL["pine"] as Color, 2.4)
		draw_arc(off, ring_r, 0.0, TAU, 36, PAL["jade"] as Color, 3.6)
		draw_arc(off, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["lime"] as Color, 2.0)
		for sw: int in range(4):
			var sw_a: float = anim_t * 3.2 + float(sw) * (TAU * 0.25)
			draw_arc(off, maxf(3.0, ring_r - 4.0), sw_a, sw_a + 0.65, 6, PAL["lime"] as Color, 1.2)
		for pi: int in range(8):
			var pa: float = anim_t * 2.6 + float(pi) * (TAU / 8.0)
			var wob: float = sin(anim_t * 10.0 + float(pi) * 1.6) * 2.6
			var pp: Vector2 = (off + Vector2.from_angle(pa) * (ring_r + wob)).round()
			draw_circle(pp, 2.2, PAL["pine"] as Color)
			draw_circle(pp, 1.4, PAL["lime"] as Color)
			draw_circle(pp, 0.7, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 16.0
		draw_arc(off, rr + 2.2, 0.0, TAU, 28, PAL["jade"] as Color, 2.0)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["lime"] as Color, 2.4)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(shake)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", pos, gust_r, gust_s)
