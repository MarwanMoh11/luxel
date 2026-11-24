class_name LxBossBase
extends LxEnemyBrain
## Reusable Epic Boss base extending LxEnemyBrain.
## Threshold phases, weighted no-repeat deck, tell (>=0.45s) & punish (>=0.80s) floors,
## stagger meter, arena lock-in, HUD meta, half-heart rewards, clean retry reset,
## flash-reduction & assist tell scale, and auto-managed kit helpers.

signal phase_changed(new_phase: int)
signal staggered(duration: float)
signal attack_committed(attack_id: String)
signal death_finished(boss_id: String)

enum BossState { IDLE, INTRO, READY, TELL, COMMIT, RECOVER, STAGGER, PHASE_SHIFT, DEATH }

const MIN_BOSS_TELL: float = 0.45
const MIN_BOSS_PUNISH: float = 0.80
const MAX_DEATH_DURATION: float = 2.4

var boss_state: int = BossState.IDLE
var boss_name_key: String = ""
var is_miniboss: bool = false
var reward_heart: String = "full" # "full" | "half" | "none"
var music_cue: String = ""
var music_p2_cue: String = ""

var phase_thresholds: Array[float] = [0.66, 0.33]
var intro_duration: float = 0.55
var phase_shift_duration: float = 0.65
var death_duration: float = 1.6
var stagger_meter: float = 0.0
var stagger_threshold: float = 5.0
var stagger_duration: float = 1.45
var stagger_decay: float = 0.35
var post_stagger_immunity: float = 4.0
var stagger_immunity_t: float = 0.0
var punish_dmg_mult: float = 1.25
var post_recover_cd: float = 0.32
var move_speed: float = 42.0

var arena_rect: Rect2 = Rect2()
var engaged: bool = false
var active_attack_id: String = ""
var last_attack_id: String = ""
var _commit_elapsed: float = 0.0
var _commit_hit_done: bool = false
var _death_emitted: bool = false
var _reward_granted: bool = false
var _orbit_side: float = 1.0
var _attacks: Dictionary = {}
var _attack_order: Array[String] = []
var _attack_cds: Dictionary = {}

# Telemetry for boss_check QA
var attack_counts: Dictionary = {}
var phases_reached: Array[int] = [1]
var min_tell_seen: float = 99.0
var min_punish_seen: float = 99.0
var damage_without_telegraph_count: int = 0
var _had_telegraph_for_commit: bool = false

# Managed kit subsystems
var patterns: LxBossPatterns = null
var ground: LxBossGround = null
var segments: LxBossSegments = null
var tethers: LxBossTether = null
var props: LxBossProps = null
var adds: LxBossAdds = null
var stage: LxBossStage = null
var duel: LxBossDuel = null


func _init() -> void:
	is_boss = true; max_hp = 24.0; hp = 24.0; body_radius = 9.0
	routine_speed = 42.0; leash_radius = 0.0; notice_radius = 180.0
	tell_time = 0.52; recover_time = 1.05; shard_drop = 25


func _ensure_kit() -> void:
	if patterns == null: patterns = LxBossPatterns.new(self)
	if ground == null: ground = LxBossGround.new(self)
	if segments == null: segments = LxBossSegments.new(self)
	if tethers == null: tethers = LxBossTether.new(self)
	if props == null: props = LxBossProps.new(self)
	if adds == null: adds = LxBossAdds.new(self)
	if stage == null: stage = LxBossStage.new(self)
	if duel == null: duel = LxBossDuel.new(self)


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	_ensure_kit()
	super.setup(spec, p_director, p_world)
	is_boss = true; leash_radius = 0.0
	boss_id = str(spec.get("boss_id", kind if boss_id.is_empty() else boss_id))
	if spec.has("name_key"): boss_name_key = str(spec["name_key"])
	if spec.has("mini"): is_miniboss = bool(spec["mini"])
	if spec.has("heart"): reward_heart = str(spec["heart"])
	elif is_miniboss: reward_heart = "half"
	if spec.has("arena") and spec["arena"] is Rect2:
		arena_rect = spec["arena"] as Rect2
	elif spec.has("arena") and spec["arena"] is Array and (spec["arena"] as Array).size() >= 4:
		var a: Array = spec["arena"] as Array
		arena_rect = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	else:
		arena_rect = _infer_arena_rect()
	_attacks.clear()
	_attack_order.clear()
	_configure_boss(spec)
	reset_encounter()


func _infer_arena_rect() -> Rect2:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_bounds"):
		var b: Rect2 = world_ctx.call("get_bounds") as Rect2
		if b.has_area():
			return b.grow(-16.0)
	return Rect2(home - Vector2(140.0, 74.0), Vector2(280.0, 148.0))


func _configure_boss(_spec: Dictionary) -> void: pass


func configure_phases(thresholds: Array[float]) -> void:
	phase_thresholds = thresholds.duplicate()
	phase_thresholds.sort()
	phase_thresholds.reverse()


func register_attack(id: String, cfg: Dictionary) -> void:
	var c: Dictionary = cfg.duplicate()
	c["id"] = id
	c["phases"] = c.get("phases", [])
	c["weight"] = maxf(0.05, float(c.get("weight", 1.0)))
	c["tell"] = maxf(MIN_BOSS_TELL, float(c.get("tell", 0.52)))
	c["commit"] = maxf(0.15, float(c.get("commit", 0.30)))
	c["recover"] = maxf(MIN_BOSS_PUNISH, float(c.get("recover", 1.00)))
	c["cooldown"] = maxf(0.0, float(c.get("cooldown", 1.6)))
	c["min_range"] = float(c.get("min_range", 0.0))
	c["max_range"] = float(c.get("max_range", 9999.0))
	c["damage"] = maxf(0.5, float(c.get("damage", 1.0)))
	c["allow_repeat"] = bool(c.get("allow_repeat", false))
	_attacks[id] = c
	if not _attack_order.has(id): _attack_order.append(id)
	if not attack_counts.has(id): attack_counts[id] = 0


func reset_encounter() -> void:
	_ensure_kit()
	hp = max_hp; phase = 1; pos = home; position = pos.round()
	knock = Vector2.ZERO; flash_t = 0.0; clank_t = 0.0; awaken_t = 0.0; alert_t = 0.0
	cooldown = 0.25; stagger_meter = 0.0; stagger_immunity_t = 0.0; engaged = false
	active_attack_id = ""; last_attack_id = ""
	_commit_elapsed = 0.0; _commit_hit_done = false
	_death_emitted = false; _reward_granted = false; _had_telegraph_for_commit = false
	_attack_cds.clear(); attack_counts.clear()
	for id: String in _attack_order:
		attack_counts[id] = 0; _attack_cds[id] = 0.0
	phases_reached = [1]; min_tell_seen = 99.0; min_punish_seen = 99.0
	damage_without_telegraph_count = 0
	_release_token()
	if director != null: director.register(self)
	patterns.clear(); ground.clear(); segments.clear(); tethers.clear()
	props.clear(); adds.clear_all(); stage.reset_stage(world_ctx); duel.reset()
	_set_boss_state(BossState.IDLE, 0.0)
	_on_reset_encounter()
	queue_redraw()


func _on_reset_encounter() -> void: pass


func _set_boss_state(next_st: int, dur: float = 0.0) -> void:
	boss_state = next_st
	state_timer = dur
	match next_st:
		BossState.IDLE: state = State.ROUTINE
		BossState.INTRO, BossState.PHASE_SHIFT: state = State.NOTICE
		BossState.READY: state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN
		BossState.TELL: state = State.TELL
		BossState.COMMIT: state = State.COMMIT
		BossState.RECOVER: state = State.RECOVER
		BossState.STAGGER: state = State.STAGGER
		BossState.DEATH: state = State.DEAD


func engage() -> void:
	if engaged or boss_state == BossState.DEATH: return
	engaged = true
	stage.lock_arena(true, world_ctx)
	LxDamageFx.trigger_boss_awaken(self)
	if not music_cue.is_empty(): stage.set_music(music_cue)
	_set_boss_state(BossState.INTRO, maxf(0.15, intro_duration))
	_on_engage()


func _on_engage() -> void: pass


func _step_brain(dt: float) -> void:
	if boss_state == BossState.DEATH:
		if state_timer > 0.0:
			state_timer = maxf(0.0, state_timer - dt)
			if state_timer <= 0.0 and not _death_emitted: _finalize_death()
		return
	for id: String in _attack_cds.keys():
		_attack_cds[id] = maxf(0.0, float(_attack_cds[id]) - dt)
	if stagger_immunity_t > 0.0:
		stagger_immunity_t = maxf(0.0, stagger_immunity_t - dt)
	if stagger_meter > 0.0 and boss_state != BossState.STAGGER:
		stagger_meter = maxf(0.0, stagger_meter - stagger_decay * dt)

	var target: Vector2 = _get_wick_pos()
	if not engaged:
		if _has_player() and arena_rect.has_point(target): engage()
		return

	stage.tick(dt); ground.tick(dt); patterns.tick(dt, world_ctx, props)
	props.tick(dt); tethers.tick(dt); adds.tick(dt, world_ctx); segments.tick(dt, pos, facing)
	_on_boss_tick(dt, target)

	match boss_state:
		BossState.INTRO:
			_face_point(target, 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_set_boss_state(BossState.READY, 0.0); cooldown = 0.22
		BossState.PHASE_SHIFT:
			_face_point(target, 4.5, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_set_boss_state(BossState.READY, 0.0); cooldown = 0.28
		BossState.READY:
			_step_ready(dt, target)
		BossState.TELL:
			_step_tell_state(dt, target)
		BossState.COMMIT:
			_step_commit_state(dt, target)
		BossState.RECOVER:
			state_timer -= dt
			var cfg_r: Dictionary = _attacks.get(active_attack_id, {}) as Dictionary
			var cb_r: Variant = cfg_r.get("on_recover", Callable())
			if cb_r is Callable and (cb_r as Callable).is_valid(): (cb_r as Callable).call(self, dt)
			if state_timer <= 0.0:
				_release_token(); active_attack_id = ""; cooldown = post_recover_cd
				_orbit_side = -_orbit_side; _set_boss_state(BossState.READY, 0.0)
		BossState.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token(); active_attack_id = ""; cooldown = 0.35
				stagger_immunity_t = post_stagger_immunity
				_set_boss_state(BossState.READY, 0.0)


func _step_ready(dt: float, target: Vector2) -> void:
	_face_point(target, 4.2, dt)
	var can_tok: bool = _can_claim_token()
	state = State.POSITION if can_tok else State.WAIT_TOKEN
	if cooldown <= 0.0 and can_tok:
		var pick: String = _pick_next_attack(pos.distance_to(target))
		if not pick.is_empty() and _claim_token():
			_begin_attack(pick, target)
			return
	_step_boss_reposition(dt, target)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 1.0:
		var rad: Vector2 = to_t / dist
		var desire: Vector2 = (rad.rotated(PI * 0.5 * _orbit_side) + rad * clampf((dist - 68.0) / 52.0, -0.5, 0.5)).normalized()
		move_boss(desire * move_speed * dt, false)


func _pick_next_attack(dist: float) -> String:
	var cands: Array[String] = []
	var min_used: int = 999999
	for id: String in _attack_order:
		var c: Dictionary = _attacks[id] as Dictionary
		if not _attack_allowed_in_phase(c, phase) or float(_attack_cds.get(id, 0.0)) > 0.0: continue
		if dist < float(c["min_range"]) or dist > float(c["max_range"]): continue
		cands.append(id); min_used = mini(min_used, int(attack_counts.get(id, 0)))
	if cands.is_empty():
		for id: String in _attack_order:
			if _attack_allowed_in_phase(_attacks[id] as Dictionary, phase):
				cands.append(id); min_used = mini(min_used, int(attack_counts.get(id, 0)))
	if cands.is_empty(): return ""
	var filtered: Array[String] = []
	for id: String in cands:
		var c: Dictionary = _attacks[id] as Dictionary
		if id == last_attack_id and not bool(c["allow_repeat"]) and cands.size() >= 2: continue
		filtered.append(id)
	if filtered.is_empty(): filtered = cands
	var weights: Array[float] = []
	var total_w: float = 0.0
	for id: String in filtered:
		var w: float = float((_attacks[id] as Dictionary)["weight"])
		if int(attack_counts.get(id, 0)) == min_used: w *= 1.85
		weights.append(w); total_w += w
	var roll: float = _randf_range(0.0, maxf(0.001, total_w))
	var acc: float = 0.0
	for i: int in range(filtered.size()):
		acc += weights[i]
		if roll <= acc: return filtered[i]
	return filtered[filtered.size() - 1]


func _begin_attack(id: String, target: Vector2) -> void:
	var c: Dictionary = _attacks[id] as Dictionary
	active_attack_id = id; last_attack_id = id
	attack_counts[id] = int(attack_counts.get(id, 0)) + 1
	is_counter_attack = false; _commit_elapsed = 0.0; _commit_hit_done = false
	_had_telegraph_for_commit = true
	var tell_dur: float = maxf(MIN_BOSS_TELL, float(c["tell"])) * get_tell_scale()
	last_tell_duration = tell_dur; min_tell_seen = minf(min_tell_seen, tell_dur)
	if target.distance_to(pos) > 0.1: facing = (target - pos).angle()
	_set_boss_state(BossState.TELL, tell_dur)
	_emit_attack_started()
	_on_attack_tell_start(id, target)
	var cb_s: Variant = c.get("on_tell_start", Callable())
	if cb_s is Callable and (cb_s as Callable).is_valid(): (cb_s as Callable).call(self, target)
	var cb: Variant = c.get("on_tell", Callable())
	if cb is Callable and (cb as Callable).is_valid(): (cb as Callable).call(self, target, 0.0, 0.0)


func _step_tell_state(dt: float, target: Vector2) -> void:
	var c: Dictionary = _attacks.get(active_attack_id, {}) as Dictionary
	state_timer -= dt
	var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
	if state_timer > 0.16: _face_point(target, 2.8, dt)
	var cb: Variant = c.get("on_tell", Callable())
	if cb is Callable and (cb as Callable).is_valid(): (cb as Callable).call(self, target, dt, prog)
	if state_timer <= 0.0: _enter_attack_commit(c, target)


func _enter_attack_commit(c: Dictionary, target: Vector2) -> void:
	_commit_elapsed = 0.0; _commit_hit_done = false
	_set_boss_state(BossState.COMMIT, float(c.get("commit", 0.30)))
	attack_committed.emit(active_attack_id)
	_on_attack_commit_start(active_attack_id, target)
	var cb: Variant = c.get("on_commit_start", Callable())
	if cb is Callable and (cb as Callable).is_valid(): (cb as Callable).call(self, target)


func _step_commit_state(dt: float, target: Vector2) -> void:
	_commit_elapsed += dt; state_timer = maxf(0.0, state_timer - dt)
	var c: Dictionary = _attacks.get(active_attack_id, {}) as Dictionary
	var cb: Variant = c.get("on_commit", Callable())
	if cb is Callable and (cb as Callable).is_valid(): (cb as Callable).call(self, target, dt, _commit_elapsed)
	if state_timer <= 0.0:
		var rec: float = maxf(MIN_BOSS_PUNISH, float(c.get("recover", 1.0)))
		last_recover_duration = rec; min_punish_seen = minf(min_punish_seen, rec)
		_attack_cds[active_attack_id] = float(c.get("cooldown", 1.5))
		_set_boss_state(BossState.RECOVER, rec)
		_on_attack_recover_start(active_attack_id)


func take_hit(hit: LxHit) -> int:
	if boss_state == BossState.DEATH or hit == null: return HitResult.GLANCED
	var wp: Vector2 = _get_wick_pos()
	if not engaged:
		if not arena_rect.grow(2.0).has_point(wp):
			clank_t = 0.12; _emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED
		engage()
	if boss_state == BossState.INTRO or boss_state == BossState.PHASE_SHIFT:
		_emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_open: bool = is_punishable()
	if is_open: dmg *= punish_dmg_mult
	dmg = _modify_incoming_damage(hit, dmg)
	if dmg <= 0.0:
		_emit_enemy_hit(hit, HitResult.BLOCKED); return HitResult.BLOCKED
	hp = maxf(0.0, hp - dmg); flash_t = 0.14 if is_open else 0.07
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	if rel.length() > 0.01: knock = -rel.normalized() * (52.0 if bool(h["stagger"]) else 14.0)
	if hp <= 0.001:
		opened_kill = is_open; _begin_death(hit); return HitResult.KILLED
	var stag_gain: float = dmg * (1.5 if bool(h["stagger"]) or bool(h["cracks_armour"]) else 0.55)
	if _check_phase_thresholds():
		_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED
	if add_stagger(stag_gain):
		_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED
	var res: int = HitResult.OPENED if is_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func add_stagger(amount: float) -> bool:
	if boss_state in [BossState.DEATH, BossState.INTRO, BossState.PHASE_SHIFT, BossState.STAGGER]:
		return false
	if stagger_immunity_t > 0.0:
		return false
	stagger_meter += maxf(0.0, amount)
	if stagger_meter >= stagger_threshold:
		stagger_meter = 0.0; _release_token(); active_attack_id = ""
		_set_boss_state(BossState.STAGGER, stagger_duration)
		staggered.emit(stagger_duration)
		LxDamageFx.boss_impact(pos, 0.18, 76.0, 82.0, 80.0, 1.38, 0.32)
		_emit_sfx("warden_shield_break")
		return true
	return false


func _check_phase_thresholds() -> bool:
	var target_p: int = 1
	var ratio: float = hp / maxf(max_hp, 0.01)
	for th: float in phase_thresholds:
		if ratio <= th: target_p += 1
	if target_p <= phase: return false
	phase = target_p
	if not phases_reached.has(phase): phases_reached.append(phase)
	_release_token(); active_attack_id = ""; stagger_meter = 0.0
	_set_boss_state(BossState.PHASE_SHIFT, maxf(0.35, phase_shift_duration))
	if Lx.events != null: Lx.events.boss_phase_changed.emit(boss_id, phase)
	LxDamageFx.trigger_boss_phase_reset(self, phase)
	if phase == 2 and not music_p2_cue.is_empty(): stage.set_music(music_p2_cue)
	phase_changed.emit(phase); _on_phase_enter(phase)
	return true


func _begin_death(hit: Object) -> void:
	hp = 0.0; _release_token(); active_attack_id = ""
	patterns.clear(); ground.clear(); tethers.discharge_all(); adds.clear_all(); duel.restore_stolen_moves()
	_set_boss_state(BossState.DEATH, clampf(death_duration, 0.2, MAX_DEATH_DURATION))
	LxDamageFx.spawn_boss_defeat_burst(self)
	_emit_enemy_hit(hit, HitResult.KILLED); _emit_sfx("boss_kill")
	_on_death_start(); _finalize_death()


func _finalize_death() -> void:
	if _death_emitted: return
	_death_emitted = true
	if director != null:
		director.release_light(self); director.unregister(self)
	stage.lock_arena(false, world_ctx)
	if Lx.state != null and shard_drop > 0: Lx.state.add_shards(shard_drop + (1 if opened_kill else 0))
	_grant_heart_reward()
	if Lx.events != null:
		Lx.events.enemy_killed.emit(self, kind, pos, opened_kill)
		if not boss_id.is_empty(): Lx.events.boss_defeated.emit(boss_id, island_id)
	death_finished.emit(boss_id); queue_redraw()


func _grant_heart_reward() -> void:
	if _reward_granted or Lx.state == null or reward_heart == "none": return
	var flag_k: String = "boss_reward_" + boss_id
	if bool(Lx.state.story_flags.get(flag_k, false)): return
	_reward_granted = true; Lx.state.story_flags[flag_k] = true
	if reward_heart == "half":
		if Lx.state.has_method("add_half_lantern"): Lx.state.call("add_half_lantern")
		else:
			var halves: int = int(Lx.state.story_flags.get("half_lanterns", 0)) + 1
			Lx.state.story_flags["half_lanterns"] = halves
			if halves % 2 == 0: Lx.state.add_boss_heart()


func move_boss(step_vec: Vector2, flying: bool = false) -> void:
	pos = clamp_to_arena(_collide_move(pos, pos + step_vec, flying))
	position = pos.round()


func clamp_to_arena(pt: Vector2) -> Vector2:
	if not arena_rect.has_area(): return pt
	var inner: Rect2 = arena_rect.grow(-body_radius)
	if not inner.has_area(): return arena_rect.get_center()
	return Vector2(clampf(pt.x, inner.position.x, inner.end.x), clampf(pt.y, inner.position.y, inner.end.y))


func check_contact_damage(rad: float, hit_dir: Vector2, dmg: float = 1.0, src: String = "boss_contact") -> bool:
	if _commit_hit_done or not _has_player(): return false
	if pos.distance_to(_get_wick_pos()) <= rad:
		_commit_hit_done = true
		emit_boss_damage(hit_dir, dmg, src, pos, _had_telegraph_for_commit)
		return true
	return false


func emit_boss_damage(hit_dir: Vector2, dmg: float, src: String = "", from_pos: Vector2 = Vector2.ZERO, telegraphed: bool = true) -> void:
	if not telegraphed: damage_without_telegraph_count += 1
	var p_from: Vector2 = pos if from_pos == Vector2.ZERO else from_pos
	var d: Vector2 = hit_dir.normalized() if hit_dir.length_squared() > 0.001 else Vector2.from_angle(facing)
	var k_src: String = kind if src.is_empty() else src
	if Lx.events != null:
		Lx.events.enemy_attack_landed.emit(self, k_src, p_from, d, dmg)


func get_arena_rect() -> Rect2: return arena_rect
func is_punishable() -> bool: return boss_state == BossState.RECOVER or boss_state == BossState.STAGGER
func is_flash_reduced() -> bool: return LxHudFx.flash_reduced()
func get_tell_scale() -> float: return _assist_tell_scale()
func get_registered_attacks() -> Array[String]: return _attack_order.duplicate()
func get_max_phase() -> int: return phase_thresholds.size() + 1


func boss_meta() -> Dictionary:
	return {
		"id": boss_id, "name_key": boss_name_key if not boss_name_key.is_empty() else boss_id,
		"phases": phase_thresholds.duplicate(), "mini": is_miniboss, "heart": reward_heart,
		"music": music_cue, "music_p2": music_p2_cue, "island_id": island_id,
		"hp": hp, "max_hp": max_hp, "phase": phase,
		"stagger_ratio": clampf(stagger_meter / maxf(stagger_threshold, 0.01), 0.0, 1.0),
	}


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["boss_state"] = boss_state; d["phase"] = phase; d["max_phase"] = get_max_phase()
	d["engaged"] = engaged; d["active_attack"] = active_attack_id
	d["stagger_ratio"] = clampf(stagger_meter / maxf(stagger_threshold, 0.01), 0.0, 1.0)
	d["punishable"] = is_punishable(); d["attack_counts"] = attack_counts.duplicate()
	d["phases_reached"] = phases_reached.duplicate(); d["min_tell_seen"] = min_tell_seen
	d["min_punish_seen"] = min_punish_seen; d["damage_without_telegraph"] = damage_without_telegraph_count
	d["active_bolts"] = patterns.active_bolt_count() if patterns != null else 0
	return d


func _draw_extra(off: Vector2) -> void:
	if ground != null: ground.draw_ground(self, pos)
	if tethers != null: tethers.draw_tethers(self, pos)
	if props != null: props.draw_props(self, pos)
	if segments != null: segments.draw_segments(self, pos)
	if adds != null: adds.draw_summons(self, pos)
	if patterns != null: patterns.draw_patterns(self, pos)
	if stagger_meter > stagger_threshold * 0.25 and boss_state != BossState.STAGGER and boss_state != BossState.DEATH:
		var frac: float = clampf(stagger_meter / maxf(stagger_threshold, 0.01), 0.0, 1.0)
		var bw: float = roundf(body_radius * 2.2)
		var bp: Vector2 = (off + Vector2(-bw * 0.5, body_radius + 4.0)).round()
		draw_rect(Rect2(bp, Vector2(bw, 2.0)), PAL["night"] as Color)
		draw_rect(Rect2(bp, Vector2(roundf(bw * frac), 2.0)), PAL["gold"] as Color)
	_draw_boss_extra(off)


func _face_point(pt: Vector2, rate: float, dt: float) -> void:
	var to_p: Vector2 = pt - pos
	if to_p.length_squared() > 0.01: _turn_toward(to_p.angle(), rate, dt)


static func _attack_allowed_in_phase(c: Dictionary, ph: int) -> bool:
	var phs: Variant = c.get("phases", [])
	return (not (phs is Array)) or (phs as Array).is_empty() or (phs as Array).has(ph)


func _on_boss_tick(_dt: float, _target: Vector2) -> void: pass
func _on_phase_enter(_new_phase: int) -> void: pass
func _on_attack_tell_start(_attack_id: String, _target: Vector2) -> void: pass
func _on_attack_commit_start(_attack_id: String, _target: Vector2) -> void: pass
func _on_attack_recover_start(_attack_id: String) -> void: pass
func _on_death_start() -> void: pass
func _modify_incoming_damage(_hit: LxHit, dmg: float) -> float: return dmg
func _draw_boss_extra(_off: Vector2) -> void: pass
