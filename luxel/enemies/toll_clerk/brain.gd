class_name LxTollClerkBrain
extends LxEnemyBrain
## Island 8 Enemy: Toll Clerk (Shield Tank / Taxer | HP 3.5 | Shield 2.0 | Shards 5).
## Brass-visored ledger-warden pacing braziers; hitting its front scale-shield 3x without
## breaking drops a 4s slowing Tax Ring (40px). Throw/Prism breaks shield; Beam pierces;
## sold:hit_flash adds +40% shield wear; sold:sound_off cuts notice to 50px sight-only!

const CONE_NOTICE_FULL: float = 120.0
const CONE_NOTICE_SILENT: float = 50.0
const CONE_HALF_RAD: float = 0.72
const BELL_TELL: float = 0.50
const SLAM_COMMIT: float = 0.22
const SLAM_RECOVER: float = 1.20
const SLAM_REACH: float = 36.0
const SLAM_ARC_HALF: float = 1.05 # 120 deg cone
const BLOCK_HALF: float = 1.02
const SHIELD_REFORM_S: float = 5.5
const TAX_RING_R: float = 40.0
const TAX_RING_DUR: float = 4.0
const NOTICE_TIME: float = 0.24

var route: Array[Vector2] = []
var route_i: int = 0
var home_facing: float = 0.0
var pause_t: float = 0.0
var shield_max: float = 2.0
var shield_hp: float = 2.0
var shield_gone_t: float = 0.0
var shield_block_count: int = 0
var tax_ring_t: float = 0.0
var tax_ring_pos: Vector2 = Vector2.ZERO
var dusk_frozen_t: float = 0.0
var slam_dir: Vector2 = Vector2.RIGHT
var slam_hit_done: bool = false
var wary: bool = false


func _init() -> void:
	kind = "toll_clerk"
	island_id = 8
	max_hp = 3.5
	hp = 3.5
	body_radius = 7.0
	routine_speed = 36.0
	leash_radius = 158.0
	notice_radius = CONE_NOTICE_FULL
	tell_time = BELL_TELL
	recover_time = SLAM_RECOVER
	give_up_time = 2.1
	shard_drop = 5
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	shield_max = maxf(0.0, float(spec.get("shield_hp", 2.0)))
	shield_hp = shield_max
	shield_gone_t = 0.0
	shield_block_count = 0
	tax_ring_t = 0.0
	tax_ring_pos = home
	dusk_frozen_t = 0.0
	pause_t = 0.0
	slam_hit_done = false
	wary = false
	route.clear()
	var raw_r: Variant = spec.get("route", [])
	if raw_r is Array:
		for pv: Variant in (raw_r as Array):
			var pt: Vector2 = _to_vec2(pv, home)
			if pt.distance_to(home) > leash_radius - 2.0:
				pt = home + (pt - home).normalized() * maxf(0.0, leash_radius - 2.0)
			route.append(pt)
	route_i = 0
	if not spec.has("facing") and not route.is_empty() and route[0].distance_to(home) > 1.0:
		facing = (route[0] - home).angle()
	home_facing = facing


func _is_setting_sold(setting_id: String) -> bool:
	if ResourceLoader.exists("res://luxel/core/sold_settings.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/core/sold_settings.gd")
		if sc is GDScript and (sc as GDScript).has_method("current"):
			var inst: Variant = (sc as GDScript).call("current")
			if inst is Object and (inst as Object).has_method("is_sold"):
				return bool((inst as Object).call("is_sold", setting_id))
	if Lx.vars != null:
		return bool(Lx.vars.get_var("island:8", "sold_" + setting_id, false))
	return false


func on_ring(tone: String, dir: Vector2) -> void:
	if state == State.DEAD:
		return
	var t: String = tone.strip_edges().to_lower()
	if t == "dusk":
		_release_token()
		dusk_frozen_t = 2.0
		state = State.STAGGER
		state_timer = 2.0
		_emit_sfx("clockwork_chime")
	elif t == "war":
		if _has_active_shield():
			_damage_shield(shield_max)
		elif state == State.ROUTINE or state == State.RETURN:
			_enter_notice()
	elif t == "dawn" and dir.length_squared() > 0.01:
		facing = (-dir).angle()
		if state == State.ROUTINE:
			pause_t = 0.8


func _has_active_shield() -> bool:
	return dusk_frozen_t <= 0.0 and shield_max > 0.001 and shield_hp > 0.001 and shield_gone_t <= 0.0 \
			and state in [State.ROUTINE, State.NOTICE, State.POSITION, State.WAIT_TOKEN, State.TELL]


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _is_lured() -> bool:
	if wary or not _is_lantern_out():
		return false
	return _get_lantern_pos().distance_to(home) <= leash_radius + 28.0


func _attention_target() -> Vector2:
	return _get_lantern_pos() if _is_lured() else _get_wick_pos()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"]) or src == LxHit.SOURCE_BEAM
	var cracks: bool = bool(h["cracks_armour"])
	var is_throw: bool = src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP
	var is_prism: bool = src == LxHit.SOURCE_PRISM
	var is_heavy: bool = bool(h["stagger"]) or is_throw or src == LxHit.SOURCE_DASH
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < BLOCK_HALF
	var from_behind: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) > 1.75

	# Front scale-shield blocks raw frontal bolts; Throw/Prism/Beam/cracks smash or bypass it!
	if _has_active_shield() and from_front and not pierce and not cracks and not is_throw and not is_prism:
		clank_t = 0.14
		var wear_mult: float = 1.40 if _is_setting_sold("hit_flash") else 1.0
		var wear: float = maxf(0.45, float(h["shield_wear"])) * wear_mult
		shield_block_count += 1
		if shield_block_count >= 3:
			shield_block_count = 0
			tax_ring_pos = pos
			tax_ring_t = TAX_RING_DUR
			_emit_sfx("tax_ring_drop")
		if _damage_shield(wear):
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		_emit_sfx("warden_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	if _has_active_shield() and (is_throw or is_prism or cracks):
		_damage_shield(shield_max)

	var sneak: bool = from_behind and (state == State.ROUTINE or _is_lured() or _is_setting_sold("sound_off"))
	if sneak:
		dmg *= 1.65
	var is_opening: bool = sneak or state == State.RECOVER or state == State.STAGGER or shield_gone_t > 0.0

	hp -= dmg
	wary = true
	flash_t = 0.14 if (is_heavy or sneak) else 0.07
	if rel.length() > 0.01:
		knock = -rel.normalized() * (115.0 if is_heavy else 24.0)

	if hp <= 0.001:
		opened_kill = is_opening
		tax_ring_t = 0.0
		_spawn_death_burst()
		_die(hit)
		return HitResult.KILLED

	if is_heavy:
		_release_token()
		state = State.STAGGER
		state_timer = 1.5 if src == LxHit.SOURCE_SUNFLARE else 1.1
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	_emit_enemy_hit(hit, HitResult.OPENED if is_opening else HitResult.CHIPPED)
	return HitResult.OPENED if is_opening else HitResult.CHIPPED


func _damage_shield(amount: float) -> bool:
	shield_hp = maxf(0.0, shield_hp - amount)
	if shield_hp > 0.001:
		return false
	shield_gone_t = SHIELD_REFORM_S
	shield_block_count = 0
	wary = true
	_release_token()
	state = State.RECOVER
	state_timer = maxf(MIN_RECOVER_TIME, 1.25)
	last_recover_duration = state_timer
	_emit_sfx("shield_shatter")
	return true


func _step_brain(dt: float) -> void:
	dusk_frozen_t = maxf(0.0, dusk_frozen_t - dt)
	if shield_max > 0.001 and shield_gone_t > 0.0:
		shield_gone_t -= dt
		if shield_gone_t <= 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max
			_emit_sfx("warden_shield_reform")

	if tax_ring_t > 0.0:
		tax_ring_t = maxf(0.0, tax_ring_t - dt)
		_apply_tax_ring_slow()

	var target_pos: Vector2 = _attention_target()
	match state:
		State.ROUTINE:
			_step_routine(dt)
			if _sees_target():
				_enter_notice()
		State.NOTICE:
			var to_t: Vector2 = target_pos - pos
			if to_t.length() > 0.1:
				_turn_toward(to_t.angle(), 4.2, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				state = State.POSITION
		State.POSITION, State.WAIT_TOKEN:
			_step_position(dt, target_pos)
		State.TELL:
			_step_tell(dt, target_pos)
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
				cooldown = 0.55
				state = State.RETURN if _should_give_up() else State.POSITION
		State.RETURN:
			_step_return(dt)


func _apply_tax_ring_slow() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var wp: Vector2 = _get_real_wick_pos()
	if wp.distance_to(tax_ring_pos) <= TAX_RING_R and Lx.player.has_method("push_external"):
		var vel_v: Variant = Lx.player.get("vel")
		if vel_v is Vector2 and (vel_v as Vector2).length() > 4.0:
			Lx.player.call("push_external", -(vel_v as Vector2) * 0.42, "tax_ring")


func _step_routine(dt: float) -> void:
	if route.size() < 2:
		if pos.distance_to(home) > 2.5:
			_walk_toward(home, dt)
			return
		_turn_toward(home_facing + sin(anim_t * 0.7) * 0.8, 1.4, dt)
		return
	if pause_t > 0.0:
		pause_t -= dt
		return
	var wp: Vector2 = route[route_i % route.size()]
	if pos.distance_to(wp) <= 3.0:
		route_i = (route_i + 1) % route.size()
		pause_t = 0.90
		return
	_walk_toward(wp, dt)


func _step_position(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	var dist: float = to_t.length()
	if dist > 0.1:
		_turn_toward(to_t.angle(), 3.2, dt)
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token()
			state = State.RETURN
			lost_t = 0.0
			return
	else:
		lost_t = 0.0

	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if can_tok and cooldown <= 0.0 and _is_on_screen() and dist <= SLAM_REACH + 16.0:
		if _claim_token():
			slam_dir = to_t.normalized() if dist > 0.1 else Vector2.from_angle(facing)
			facing = slam_dir.angle()
			state = State.TELL
			is_counter_attack = false
			last_tell_duration = _scaled_tell(BELL_TELL, false, attack_damage)
			state_timer = last_tell_duration
			slam_hit_done = false
			_emit_attack_started()
			_emit_sfx("clerk_bell")
			return
	if dist > SLAM_REACH - 8.0:
		_move_step(to_t.limit_length(routine_speed * 0.88 * dt), false)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if state_timer > 0.16:
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.1:
			_turn_toward(to_t.angle(), 2.2, dt)
			slam_dir = Vector2.from_angle(facing)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT
		state_timer = SLAM_COMMIT
		slam_hit_done = false
		_emit_sfx("warden_swing")


func _step_commit(dt: float) -> void:
	_move_step(slam_dir * 124.0 * dt, false)
	if not slam_hit_done and _has_player():
		var rel: Vector2 = _get_wick_pos() - pos
		if rel.length() <= SLAM_REACH and (rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= SLAM_ARC_HALF):
			slam_hit_done = true
			_emit_player_hit(slam_dir)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, SLAM_RECOVER)
		last_recover_duration = state_timer


func _step_return(dt: float) -> void:
	var to_h: Vector2 = home - pos
	if to_h.length() <= 3.5:
		pos = home
		state = State.ROUTINE
		wary = false
		lost_t = 0.0
		return
	_walk_toward(home, dt)
	if _sees_target():
		_enter_notice()


func _walk_toward(dst: Vector2, dt: float) -> void:
	var to_d: Vector2 = dst - pos
	if to_d.length() > 0.1:
		_turn_toward(to_d.angle(), 3.6, dt)
		_move_step(to_d.limit_length(routine_speed * dt), false)


func _sees_target() -> bool:
	if not _has_player():
		return false
	var wp: Vector2 = _get_wick_pos()
	var silent: bool = _is_setting_sold("sound_off")
	var eff_r: float = CONE_NOTICE_SILENT if silent else notice_radius
	var rel: Vector2 = wp - pos
	if rel.length() > eff_r:
		return false
	if silent and absf(angle_difference(facing, rel.angle())) > CONE_HALF_RAD:
		return false
	return _has_clear_view(pos, wp)


func _should_give_up() -> bool:
	if _is_lured():
		return false
	return not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0


func _enter_notice() -> void:
	state = State.NOTICE
	state_timer = NOTICE_TIME
	alert_t = 0.65
	lost_t = 0.0
	_emit_sfx("clerk_bell")


func _spawn_death_burst() -> void:
	LxDamageFx.boss_impact(pos, 0.08, 42.0, 48.0, 44.0, 1.22, 0.22)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if tax_ring_t > 0.0:
		var rp: Vector2 = (tax_ring_pos - pos).round()
		var a: float = 0.35 if LxHudFx.flash_reduced() else (0.30 + 0.12 * sin(anim_t * 8.0))
		draw_circle(rp, TAX_RING_R, Color(PAL["gold"] as Color, a * 0.35))
		draw_arc(rp, TAX_RING_R, 0.0, TAU, 24, Color(PAL["coral"] as Color, minf(0.85, tax_ring_t)), 1.6)
	if dusk_frozen_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.6)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_sector(self, Vector2.ZERO, facing - SLAM_ARC_HALF, facing + SLAM_ARC_HALF, SLAM_REACH, prog, anim_t, "coral", "gold")
