class_name LxFireflyCompanion
extends Node2D
## Pip the Firefly Companion: 100% manual-aim send/perch/recall partner for Wick.
## Handles Glow-Tag marks, Pollen Pops, Resonance Tether with hung lantern, and Luminous Nova.
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and integer pixel-snapped drawing.

enum State { BECKON, FOLLOW, SEND, PERCH, RECALL }

const AIM_ASSIST_ENABLED: bool = false
const SEND_SPEED: float = 340.0
const RECALL_SPEED: float = 460.0
const TETHER_MAX_DIST: float = 156.0
const TETHER_TICK_S: float = 0.38
const NOVA_RADIUS: float = 42.0
const POP_RADIUS: float = 28.0
const MARK_DURATION: float = 5.5
const BECKON_CENTER: Vector2 = Vector2(652.0, 352.0)

var state: State = State.FOLLOW
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var cooldown_left: float = 0.0
var perch_timer: float = 0.0
var perch_max: float = 6.5
var tether_active: bool = false
var sanctuary_buff_active: bool = false

var _owner_wick: LxWick = null
var _world_ctx: Node = null
var _anim_t: float = 0.0
var _send_dir: Vector2 = Vector2.RIGHT
var _send_dist: float = 0.0
var _send_max: float = 128.0
var _join_t: float = 0.0
var _idle_t: float = 0.0
var _chirp_cd: float = 0.0
var _tether_tick_cd: float = 0.0
var _perch_light_cd: float = 0.0
var _flight_intercepted: bool = false
var _prev_boss_stagger_ids: Dictionary = {}
var _tether_end: Vector2 = Vector2.ZERO
var _sense_dir: Vector2 = Vector2.ZERO
var _sense_active: bool = false
var _in_pop_burst: bool = false
var _trail_acc: float = 0.0
var _hit_ids: Array[int] = []
var _nova_hit_ids: Array[int] = []
var _trail: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _boosted_bolts: Dictionary = {}
var _meta_marks: Dictionary = {}

func _ready() -> void:
	top_level = true; z_index = 4; texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(p_wick: LxWick) -> void:
	_owner_wick = p_wick; Lx.companion = self
	reset_for_room(p_wick.global_position if p_wick != null else Vector2.ZERO)

func _exit_tree() -> void:
	if Lx.companion == self: Lx.companion = null

func reset_for_room(at_pos: Vector2) -> void:
	cooldown_left = 0.0; perch_timer = 0.0; tether_active = false; sanctuary_buff_active = false; vel = Vector2.ZERO
	_send_dist = 0.0; _join_t = 0.0; _idle_t = 0.0; _chirp_cd = 0.0; _tether_tick_cd = 0.0
	_perch_light_cd = 0.0; _flight_intercepted = false; _prev_boss_stagger_ids.clear()
	_sense_active = false; _sense_dir = Vector2.ZERO
	_hit_ids.clear(); _nova_hit_ids.clear(); _trail.clear(); _rings.clear()
	_sparks.clear(); _boosted_bolts.clear(); _meta_marks.clear()
	var on_i1_ow: bool = Lx.state != null and Lx.state.island_id == 1 and Lx.state.region_id == "overworld"
	if not LxFireflyState.is_joined() and on_i1_ow:
		state = State.BECKON; pos = Vector2(640.0, 350.0)
	else:
		state = State.FOLLOW; pos = at_pos + Vector2(-10.0, -10.0)
	prev_pos = pos; global_position = pos.round(); queue_redraw()

func on_lantern_picked_up(pickup_pos: Vector2) -> void:
	LxFireflyState.mark_joined()
	if state == State.BECKON: state = State.FOLLOW
	_join_t = 1.5; cooldown_left = 0.0
	_spawn_ring(pickup_pos, 3.0, 24.0, 0.45, "lime", 2.0)
	_spawn_ring(pickup_pos, 2.0, 18.0, 0.35, "gold", 1.0)
	_spawn_sparks(pickup_pos, 10, "lime", 24.0, 68.0, 0.42)
	_emit_sfx("pip_bond_up", pickup_pos, false)
	if Lx.events != null:
		Lx.events.narration_requested.emit("PIP_JOIN_TITLE", "title", 2.6)
		Lx.events.prompt_requested.emit("PIP_JOIN_HINT", "lx_firefly", 3.6)
	queue_redraw()

func press_command(world_ctx: Node) -> bool:
	_world_ctx = world_ctx
	if not is_joined() or _owner_wick == null or not is_instance_valid(_owner_wick) or _owner_wick.dead:
		return false
	if state == State.FOLLOW:
		if cooldown_left > 0.0: return false
		if Lx.state != null: Lx.state.story_flags["pip_sent_once"] = true
		# 100% manual aim strictly along wick.facing (AIM_ASSIST_ENABLED == false).
		var aim: Vector2 = _owner_wick.facing.normalized() if _owner_wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		_send_dir = aim; prev_pos = _owner_wick.global_position
		pos = _owner_wick.global_position + aim * 6.0; vel = aim * SEND_SPEED
		_send_dist = 0.0; _send_max = LxFireflyState.get_send_range()
		state = State.SEND; tether_active = false; _flight_intercepted = false; _hit_ids.clear(); _nova_hit_ids.clear()
		_spawn_ring(pos, 2.0, 12.0, 0.22, "lime", 1.0); _spawn_ring(pos, 1.0, 8.0, 0.18, "gold", 1.0)
		_spawn_sparks(pos, 5, "lime", 26.0, 68.0, 0.20); _emit_sfx("pip_send", pos, true)
		global_position = pos.round(); queue_redraw()
		return true
	if state == State.SEND or state == State.PERCH:
		_begin_recall(); return true
	return false

func tick_sim(dt: float, wick: LxWick, world_ctx: Node) -> void:
	_owner_wick = wick; _world_ctx = world_ctx; _anim_t += dt; prev_pos = pos; tether_active = false
	cooldown_left = maxf(0.0, cooldown_left - dt); _join_t = maxf(0.0, _join_t - dt)
	_chirp_cd = maxf(0.0, _chirp_cd - dt); _tether_tick_cd = maxf(0.0, _tether_tick_cd - dt)
	_age_fx(dt); _age_meta_marks(dt)
	sanctuary_buff_active = LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance) and LxFireflyWorldContent.active_instance.is_sanctuary_buff_active()
	_check_boss_stagger(wick, world_ctx)
	match state:
		State.BECKON:
			if LxFireflyState.is_joined(): state = State.FOLLOW
			else:
				pos = Vector2(BECKON_CENTER.x + sin(_anim_t * 1.9) * 12.0, BECKON_CENTER.y + sin(_anim_t * 3.8) * 2.5 + cos(_anim_t * 1.9) * 1.5)
				vel = (pos - prev_pos) / maxf(dt, 0.0001)
		State.FOLLOW:
			if wick != null and is_instance_valid(wick): _tick_follow(dt, wick, world_ctx)
		State.SEND: _tick_send(dt, wick, world_ctx)
		State.PERCH: _tick_perch(dt, wick, world_ctx)
		State.RECALL: _tick_recall(dt, wick, world_ctx)
	_emit_trail(dt); global_position = pos.round(); queue_redraw()

func _tick_follow(dt: float, wick: LxWick, world_ctx: Node) -> void:
	_idle_t = 0.0 if (wick.velocity.length_squared() > 16.0 or _join_t > 0.0) else (_idle_t + dt)
	var sense_p: Vector2 = _find_sense_target(wick, world_ctx)
	_sense_active = sense_p.is_finite()
	if _sense_active:
		var dvec: Vector2 = sense_p - wick.global_position
		_sense_dir = dvec.normalized() if dvec.length_squared() > 0.01 else Vector2.ZERO
		if _chirp_cd <= 0.0 and _join_t <= 0.0:
			_chirp_cd = 7.0; _emit_sfx("pip_chirp", pos, true); _spawn_ring(pos, 2.0, 9.0, 0.24, "lime", 1.0)
	else:
		_sense_dir = Vector2.ZERO
	var desired: Vector2 = wick.global_position
	if _join_t > 0.0:
		var u: float = _join_t / 1.5; var rad: float = lerpf(10.0, 22.0, u); var ang: float = _anim_t * 8.5
		desired = wick.global_position + Vector2(cos(ang) * rad, sin(ang) * rad * 0.65 - 8.0 - sin(u * PI) * 8.0)
	elif _idle_t > 3.5 and not _sense_active:
		desired = wick.global_position + Vector2(0.0, -13.0)
	else:
		var fdir: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var bob: float = 0.0 if LxHudFx.flash_reduced() else sin(_anim_t * 4.4) * 1.8
		desired = wick.global_position - fdir * 11.0 + Vector2(0.0, -10.0 + bob) + (_sense_dir * 10.0 if _sense_active else Vector2.ZERO)
	pos = desired if pos.distance_squared_to(desired) > 25600.0 else pos.lerp(desired, clampf(dt * 8.5, 0.0, 1.0))
	vel = (pos - prev_pos) / maxf(dt, 0.0001)

func _tick_send(dt: float, wick: LxWick, world_ctx: Node) -> void:
	var step: float = SEND_SPEED * dt
	var next_p: Vector2 = pos + _send_dir * step
	if _is_wall_tile(world_ctx, next_p): _enter_perch(); return
	pos = next_p; vel = _send_dir * SEND_SPEED; _send_dist += step
	_notify_world_pass(pos, prev_pos, 14.0)
	if not _flight_intercepted and LxFireflyState.get_bond_rank() >= 2: _sweep_pollen_shield(wick, world_ctx)
	_sweep_interactables(wick, world_ctx); _sweep_enemies_tag(wick, world_ctx)
	if state == State.SEND and _send_dist >= _send_max: _enter_perch()

func _tick_perch(dt: float, wick: LxWick, world_ctx: Node) -> void:
	vel = Vector2.ZERO; perch_timer -= dt; _perch_light_cd = maxf(0.0, _perch_light_cd - dt)
	_notify_world_pass(pos, pos, 14.0)
	if _perch_light_cd <= 0.0:
		_perch_light_cd = 0.12
		if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("apply_light"):
			world_ctx.call("apply_light", pos, LxFireflyState.get_light_radius() * 0.72, "pip_light")
	if wick != null and is_instance_valid(wick) and wick.lantern != null and is_instance_valid(wick.lantern) and wick.lantern.is_lure_active():
		var lan_p: Vector2 = wick.lantern.pos
		if pos.distance_to(lan_p) <= TETHER_MAX_DIST:
			tether_active = true; _tether_end = lan_p; _tick_resonance_tether(wick, world_ctx, lan_p)
	if perch_timer <= 0.0: _begin_recall()

func _tick_recall(dt: float, wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): state = State.FOLLOW; vel = Vector2.ZERO; return
	var target: Vector2 = wick.global_position + Vector2(0.0, -8.0)
	var delta: Vector2 = target - pos; var dlen: float = delta.length()
	if dlen <= 10.0:
		pos = target; vel = Vector2.ZERO; state = State.FOLLOW
		cooldown_left = maxf(0.0, LxFireflyState.get_cooldown() - (0.15 if _flight_intercepted else 0.0))
		_emit_sfx("pip_chirp", pos, false); return
	var rdir: Vector2 = delta / dlen
	pos += rdir * minf(RECALL_SPEED * dt, dlen); vel = rdir * RECALL_SPEED
	_notify_world_pass(pos, prev_pos, 14.0)
	if not _flight_intercepted and LxFireflyState.get_bond_rank() >= 2: _sweep_pollen_shield(wick, world_ctx)
	if LxFireflyState.get_bond_rank() >= 4: _sweep_luminous_nova(wick, world_ctx)

func _enter_perch() -> void:
	state = State.PERCH; vel = Vector2.ZERO; perch_timer = perch_max; _perch_light_cd = 0.0
	_spawn_ring(pos, 2.0, 10.0, 0.22, "lime", 1.0); _burst_light(pos, 48.0, 1.05, 0.22)

func _begin_recall() -> void:
	state = State.RECALL; tether_active = false; _flight_intercepted = false; _nova_hit_ids.clear(); _emit_sfx("pip_recall", pos, true)

func _sweep_pollen_shield(wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): return
	for e_v: Variant in wick.world_get_enemies(world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object): continue
		var pats_v: Variant = (e_v as Object).get("patterns")
		if not (pats_v is LxBossPatterns): continue
		for b: LxBossBolt in (pats_v as LxBossPatterns).pool:
			if not b.active or b.reflected: continue
			if Geometry2D.get_closest_point_to_segment(b.pos, prev_pos, pos).distance_to(b.pos) > 14.0: continue
			var bpos: Vector2 = b.pos
			b.deactivate(); _flight_intercepted = true; cooldown_left = maxf(0.0, cooldown_left - 0.15)
			_spawn_ring(bpos, 2.0, 14.0, 0.24, "lime", 2.0); _spawn_ring(bpos, 1.0, 9.0, 0.18, "cream", 1.0)
			_spawn_sparks(bpos, 6, "cream", 24.0, 66.0, 0.20); _emit_sfx("pip_tag", bpos, true); return

func _check_boss_stagger(wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): _prev_boss_stagger_ids.clear(); return
	var next_ids: Dictionary = {}
	for e_v: Variant in wick.world_get_enemies(world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object): continue
		var enemy: Object = e_v as Object
		if not wick.is_entity_alive(enemy) or not bool(enemy.get("is_boss")): continue
		var st_v: Variant = enemy.get("state")
		var is_stag: bool = (st_v is int and int(st_v) == LxEnemyBrain.State.STAGGER) or (enemy is LxBossBase and (enemy as LxBossBase).boss_state == LxBossBase.BossState.STAGGER)
		if is_stag:
			var bid: int = enemy.get_instance_id(); next_ids[bid] = true
			if not _prev_boss_stagger_ids.has(bid):
				cooldown_left = 0.0; _spawn_ring(pos, 2.0, 18.0, 0.30, "lime", 2.0)
				_spawn_ring(pos, 1.0, 12.0, 0.24, "gold", 1.0); _spawn_sparks(pos, 6, "gold", 22.0, 58.0, 0.22)
				_emit_sfx("pip_chirp", pos, false)
	_prev_boss_stagger_ids = next_ids

func _sweep_interactables(wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): return
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not is_instance_valid(it_v) or not (it_v is Object): continue
		var item: Object = it_v as Object
		if item.get("active") is bool and not bool(item.get("active")): continue
		var iid: int = item.get_instance_id()
		if _hit_ids.has(iid): continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		if Geometry2D.get_closest_point_to_segment(ipos, prev_pos, pos).distance_to(ipos) > wick.get_entity_radius(item, 8.0) + 14.0: continue
		var k: String = str(item.get("kind")).to_lower()
		if k == "switch_eye" and not bool(item.get("requires_prism")) and item.has_method("on_hit"):
			_hit_ids.append(iid)
			item.call("on_hit", LxHit.make(LxHit.SOURCE_BOLT, 0.5, _send_dir, pos, 0.0, false, false, wick, false))
			_spawn_sparks(ipos, 5, "gold", 22.0, 56.0, 0.18)
		elif (k == "brazier" or k == "road_lamp") and not bool(item.get("lit")) and item.has_method("on_light"):
			_hit_ids.append(iid); item.call("on_light", 24.0, "lantern_fly"); _spawn_sparks(ipos, 5, "gold", 22.0, 56.0, 0.20)
		elif k == "pressure_plate" or k == "floor_switch":
			_hit_ids.append(iid)
			if item.has_method("on_light"): item.call("on_light", 24.0, "lantern_fly")
			elif item.has_method("on_hit"): item.call("on_hit", LxHit.make(LxHit.SOURCE_BOLT, 0.5, _send_dir, pos, 0.0, false, false, wick, false))

func _sweep_enemies_tag(wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): return
	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_v: Variant in enemies:
		if not is_instance_valid(e_v) or not (e_v is Object): continue
		var enemy: Object = e_v as Object
		var eid: int = enemy.get_instance_id()
		if _hit_ids.has(eid) or not wick.is_entity_alive(enemy): continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		if Geometry2D.get_closest_point_to_segment(epos, prev_pos, pos).distance_to(epos) > wick.get_entity_radius(enemy, 8.0) + 14.0: continue
		_hit_ids.append(eid); _apply_glow_tag(wick, enemy, epos)
		if LxFireflyState.get_bond_rank() >= 3: _bounce_twin_tag(wick, enemies, eid, epos)

func _apply_glow_tag(wick: LxWick, enemy: Object, epos: Vector2) -> void:
	_set_enemy_mark(enemy, MARK_DURATION)
	if wick.is_entity_alive(enemy):
		wick.apply_hit_to_entity(enemy, LxHit.make("pip_tag", 0.15, _send_dir, pos, 0.45, false, false, wick, false))
	_emit_sfx("pip_tag", epos, true); _spawn_ring(epos, 2.0, 12.0, 0.22, "lime", 1.0)
	_spawn_sparks(epos, 6, "lime", 24.0, 68.0, 0.22); _burst_light(epos, 44.0, 0.95, 0.20)

func _bounce_twin_tag(wick: LxWick, enemies: Array, skip_id: int, origin: Vector2) -> void:
	var best: Object = null; var best_pos: Vector2 = Vector2.ZERO; var best_d2: float = 56.0 * 56.0
	for o_v: Variant in enemies:
		if not is_instance_valid(o_v) or not (o_v is Object): continue
		var other: Object = o_v as Object
		var oid: int = other.get_instance_id()
		if oid == skip_id or _hit_ids.has(oid) or not wick.is_entity_alive(other): continue
		var opos: Vector2 = wick.get_entity_pos(other)
		var d2: float = opos.distance_squared_to(origin)
		if d2 <= best_d2: best_d2 = d2; best = other; best_pos = opos
	if best != null:
		_hit_ids.append(best.get_instance_id()); _apply_glow_tag(wick, best, best_pos)

func _tick_resonance_tether(wick: LxWick, world_ctx: Node, lan_p: Vector2) -> void:
	if not wick.bolts.is_empty():
		if _boosted_bolts.size() > 64: _boosted_bolts.clear()
		for bv: Variant in wick.bolts:
			if not (bv is Object): continue
			var bo: Object = bv as Object; var bid: int = bo.get_instance_id()
			if _boosted_bolts.has(bid): continue
			var bp_v: Variant = bo.get("pos")
			if bp_v is Vector2 and Geometry2D.get_closest_point_to_segment(bp_v as Vector2, pos, lan_p).distance_to(bp_v as Vector2) <= 10.0:
				_boosted_bolts[bid] = true; bo.set("speed", float(bo.get("speed")) * 1.18)
				_spawn_sparks(bp_v as Vector2, 3, "lime", 18.0, 48.0, 0.14)
	if _tether_tick_cd > 0.0: return
	var dmg: float = 0.85 if LxFireflyState.get_bond_rank() >= 3 else 0.50; var struck: bool = false
	for e_v: Variant in wick.world_get_enemies(world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object): continue
		var enemy: Object = e_v as Object
		if not wick.is_entity_alive(enemy): continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		if Geometry2D.get_closest_point_to_segment(epos, pos, lan_p).distance_to(epos) <= wick.get_entity_radius(enemy, 8.0) + 5.0:
			var tdir: Vector2 = (lan_p - pos).normalized() if lan_p.distance_to(pos) > 0.1 else Vector2.RIGHT
			wick.apply_hit_to_entity(enemy, LxHit.make("pip_tether", dmg, tdir, epos, 0.25, false, false, wick, false))
			_spawn_sparks(epos, 4, "gold", 18.0, 52.0, 0.16); struck = true
	if struck: _tether_tick_cd = TETHER_TICK_S; _emit_sfx("pip_tether", pos.lerp(lan_p, 0.5), true)

func _sweep_luminous_nova(wick: LxWick, world_ctx: Node) -> void:
	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_v: Variant in enemies:
		if not is_instance_valid(e_v) or not (e_v is Object): continue
		var enemy: Object = e_v as Object; var eid: int = enemy.get_instance_id()
		if _nova_hit_ids.has(eid) or not wick.is_entity_alive(enemy) or not _is_enemy_marked(enemy): continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		if Geometry2D.get_closest_point_to_segment(epos, prev_pos, pos).distance_to(epos) <= 18.0:
			_nova_hit_ids.append(eid); _trigger_luminous_nova(wick, enemies, enemy, epos)

func _trigger_luminous_nova(wick: LxWick, enemies: Array, enemy: Object, center: Vector2) -> void:
	_set_enemy_mark(enemy, 0.0)
	_spawn_ring(center, 4.0, NOVA_RADIUS, 0.34, "lime", 2.0); _spawn_ring(center, 2.0, NOVA_RADIUS * 0.72, 0.28, "cream", 1.0)
	_spawn_sparks(center, 12, "cream", 34.0, 96.0, 0.28); _burst_light(center, 88.0, 1.38, 0.36)
	_emit_sfx("pip_pop", center, true); wick.trigger_shake(0.12)
	for o_v: Variant in enemies:
		if not is_instance_valid(o_v) or not (o_v is Object): continue
		var other: Object = o_v as Object; var pats: Variant = other.get("patterns")
		if is_instance_valid(pats) and pats is Object and (pats as Object).has_method("clear_bolts_in_radius"):
			(pats as Object).call("clear_bolts_in_radius", center, NOVA_RADIUS)
		if not wick.is_entity_alive(other): continue
		var opos: Vector2 = wick.get_entity_pos(other)
		if opos.distance_to(center) <= NOVA_RADIUS:
			var ndir: Vector2 = (opos - center).normalized() if opos.distance_to(center) > 0.1 else Vector2.RIGHT
			wick.apply_hit_to_entity(other, LxHit.make("pip_nova", 2.2, ndir, center, 1.5, true, false, wick, false))

func on_wick_hit_enemy(wick: LxWick, enemy: Object, hit: LxHit, result: int, target_pos: Vector2, world_ctx: Node) -> void:
	if _in_pop_burst or wick == null or enemy == null or not is_instance_valid(enemy) or hit == null: return
	if hit.source in ["pip_pop", "pip_mark", "pip_tag", "pip_tether", "pip_nova"] or not _is_enemy_marked(enemy): return
	if hit.is_heavy():
		_in_pop_burst = true; _set_enemy_mark(enemy, 0.0); cooldown_left = 0.0
		_spawn_ring(target_pos, 3.0, POP_RADIUS, 0.28, "lime", 2.0)
		_spawn_ring(target_pos, 2.0, POP_RADIUS * 0.75, 0.22, "gold", 1.0)
		_spawn_ring(target_pos, 1.0, POP_RADIUS * 0.45, 0.16, "cream", 1.0)
		_spawn_sparks(target_pos, 10, "lime", 30.0, 92.0, 0.24)
		_burst_light(target_pos, 72.0, 1.28, 0.30); _emit_sfx("pip_pop", target_pos, true)
		var emax: float = wick.move_sunflare.get_ember_max() if wick.move_sunflare != null else (Lx.state.get_effective_ember_max() if Lx.state != null else 100.0)
		wick.ember = minf(emax, wick.ember + 14.0)
		var pop_dmg: float = LxFireflyState.get_pop_damage()
		for o_v: Variant in wick.world_get_enemies(world_ctx):
			if not is_instance_valid(o_v) or not (o_v is Object): continue
			var other: Object = o_v as Object
			if not wick.is_entity_alive(other): continue
			var opos: Vector2 = wick.get_entity_pos(other)
			if opos.distance_to(target_pos) <= POP_RADIUS:
				var pdir: Vector2 = (opos - target_pos).normalized() if opos.distance_to(target_pos) > 0.1 else hit.dir
				wick.apply_hit_to_entity(other, LxHit.make("pip_pop", pop_dmg, pdir, target_pos, 1.0, false, false, wick, false))
		if LxFireflyState.record_pollen_pop(): _trigger_dewdrop_heal(wick)
		_in_pop_burst = false
	elif hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM] and result != LxEnemyBrain.HitResult.BLOCKED and result != LxEnemyBrain.HitResult.KILLED:
		_in_pop_burst = true
		var bonus: float = maxf(0.05, hit.damage * LxFireflyState.get_mark_bonus())
		wick.apply_hit_to_entity(enemy, LxHit.make("pip_mark", bonus, hit.dir, target_pos, 0.0, false, false, wick, false))
		_spawn_sparks(target_pos, 4, "lime", 24.0, 62.0, 0.16); _in_pop_burst = false

func _trigger_dewdrop_heal(wick: LxWick) -> void:
	if Lx.state != null: Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 0.5)
	if Lx.events != null: Lx.events.player_healed.emit(0.5)
	_emit_sfx("heart_pickup", wick.global_position, false)
	_spawn_ring(wick.global_position, 2.0, 16.0, 0.28, "lime", 1.0)
	_spawn_sparks(wick.global_position, 6, "cream", 20.0, 56.0, 0.24)
	var hud: Object = Lx.ui.get("hud") as Object if (Lx.ui != null and Lx.ui.get("hud") is Object) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("spawn_world_cue"):
		hud.call("spawn_world_cue", "PIP_DEW_HEAL", wick.global_position + Vector2(0.0, -14.0), "lime", 1.8)
	elif Lx.events != null: Lx.events.narration_requested.emit("PIP_DEW_HEAL", "narration", 1.8)

func is_out() -> bool: return state == State.SEND or state == State.PERCH or state == State.RECALL
func is_perched() -> bool: return state == State.PERCH
func is_joined() -> bool: return LxFireflyState.is_joined()

func get_light_pool() -> Vector4:
	if state == State.BECKON: return Vector4(pos.x, pos.y - 3.0, 52.0, 0.92)
	var mult: float = 1.10 if state == State.PERCH else (0.95 if is_out() else 0.72)
	return Vector4(pos.x, pos.y - 3.0, LxFireflyState.get_light_radius() * mult, 1.08 if is_out() else 0.78)

func get_hud_state() -> Dictionary:
	return {
		"joined": is_joined(), "state": state, "out": is_out(), "perched": is_perched(),
		"cooldown": cooldown_left, "cooldown_max": LxFireflyState.get_cooldown(),
		"perch_left": perch_timer, "perch_max": perch_max, "perch_frac": clampf(perch_timer / maxf(perch_max, 0.05), 0.0, 1.0), "tether": tether_active, "tethered": tether_active,
		"rank": LxFireflyState.get_bond_rank(), "nectar": LxFireflyState.get_nectar_count(),
		"blooms": LxFireflyState.get_bloom_count(), "total_blooms": LxFireflyState.TOTAL_BLOOMS,
		"relays": LxFireflyState.get_relay_count(), "total_relays": LxFireflyState.TOTAL_RELAYS,
		"perches": LxFireflyState.get_perch_count(), "total_perches": LxFireflyState.TOTAL_PERCHES,
		"sanctuary": sanctuary_buff_active, "tint": LxFireflyState.get_tint_id(),
	}

func _find_sense_target(wick: LxWick, world_ctx: Node) -> Vector2:
	var wp: Vector2 = wick.global_position; var best: Vector2 = Vector2.INF; var best_d: float = 118.0
	if LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance):
		var wt: Vector2 = LxFireflyWorldContent.active_instance.find_nearest_sense_target(wp, 118.0)
		if wt.is_finite(): best = wt; best_d = wp.distance_to(wt)
	var cap: float = minf(best_d, 104.0)
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not is_instance_valid(it_v) or not (it_v is Object): continue
		var item: Object = it_v as Object
		if item.get("active") is bool and not bool(item.get("active")): continue
		var k: String = str(item.get("kind")).to_lower()
		if (k == "chest" and not bool(item.get("opened"))) or (k == "beacon" and not bool(item.get("lit"))):
			var ip: Vector2 = wick.get_entity_pos(item); var d: float = wp.distance_to(ip)
			if d < cap: cap = d; best = ip
	return best

func _notify_world_pass(cur_p: Vector2, old_p: Vector2, rad: float) -> void:
	if LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance):
		LxFireflyWorldContent.active_instance.on_pip_pass(cur_p, old_p, rad, self)

func _is_wall_tile(world_ctx: Node, p: Vector2) -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"): return false
	var t: String = str(world_ctx.call("tile_at", p))
	return t == "wall" or t == "pillar"

func _set_enemy_mark(enemy: Object, secs: float) -> void:
	if enemy.has_method("apply_pip_mark"): enemy.call("apply_pip_mark", secs)
	else:
		enemy.set_meta("pip_mark_t", secs); var eid: int = enemy.get_instance_id()
		if secs > 0.0: _meta_marks[eid] = {"obj": enemy, "t": secs}
		else: _meta_marks.erase(eid)

func _is_enemy_marked(enemy: Object) -> bool:
	if enemy.has_method("is_pip_marked"): return bool(enemy.call("is_pip_marked"))
	return enemy.has_meta("pip_mark_t") and float(enemy.get_meta("pip_mark_t")) > 0.0

func _age_meta_marks(dt: float) -> void:
	for eid: Variant in _meta_marks.keys():
		var entry: Dictionary = _meta_marks[eid] as Dictionary; var obj: Variant = entry["obj"]
		var rem: float = float(entry["t"]) - dt
		if rem <= 0.0 or not is_instance_valid(obj):
			if is_instance_valid(obj) and obj is Object: (obj as Object).set_meta("pip_mark_t", 0.0)
			_meta_marks.erase(eid)
		else:
			entry["t"] = rem
			if obj is Object: (obj as Object).set_meta("pip_mark_t", rem)

func _emit_trail(dt: float) -> void:
	var rate: float = 0.032 if (state == State.SEND or state == State.RECALL) else (0.14 if LxHudFx.flash_reduced() else 0.09)
	_trail_acc += dt
	if _trail_acc < rate: return
	_trail_acc = 0.0
	if _trail.size() >= 5: _trail.pop_front()
	_trail.append({"pos": pos + Vector2(0.0, -3.0), "age": 0.0, "life": 0.28})

func _age_fx(dt: float) -> void:
	for arr: Array[Dictionary] in [_trail, _rings, _sparks]:
		for i: int in range(arr.size() - 1, -1, -1):
			var item: Dictionary = arr[i]; item["age"] = float(item["age"]) + dt
			if item.has("vel"): item["pos"] = (item["pos"] as Vector2) + (item["vel"] as Vector2) * dt
			if float(item["age"]) >= float(item["life"]): arr.remove_at(i)

func _spawn_ring(p: Vector2, r0: float, r1: float, life: float, col: String, w: float) -> void:
	if _rings.size() >= 12: _rings.pop_front()
	_rings.append({"pos": p, "r0": r0, "r1": r1, "age": 0.0, "life": life, "col": col, "w": clampf(roundf(w), 1.0, 2.0)})

func _spawn_sparks(p: Vector2, count: int, col: String, min_s: float, max_s: float, life: float) -> void:
	var n: int = maxi(1, count / 2) if LxHudFx.flash_reduced() else count
	for i: int in range(n):
		if _sparks.size() >= 32: _sparks.pop_front()
		var a: float = (TAU * float(i)) / float(maxi(1, n)) + _anim_t * 1.7
		var spd: float = lerpf(min_s, max_s, fmod(float(i) * 0.37, 1.0))
		_sparks.append({"pos": p, "vel": Vector2(cos(a), sin(a)) * spd, "age": 0.0, "life": life, "col": col})

func _burst_light(at_p: Vector2, rad: float, intensity: float, dur: float) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at_p, rad, intensity * (0.62 if LxHudFx.flash_reduced() else 1.0), dur)

func _emit_sfx(sfx_id: String, at_p: Vector2, spatial: bool) -> void:
	if Lx.events != null: Lx.events.sfx_requested.emit(sfx_id, at_p, spatial)
	elif Lx.audio != null: Lx.audio.play_sfx(sfx_id, at_p, spatial)

func _draw() -> void:
	var pal: Dictionary = LxPalette.PAL; var void_c: Color = pal["void"] as Color
	var tint: Dictionary = LxFireflyState.get_tint_colors()
	var c_core: Color = tint["core"] as Color; var c_glow: Color = tint["glow"] as Color
	var c_wing: Color = tint["wing"] as Color; var c_rim: Color = tint["rim"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	if _owner_wick != null and is_instance_valid(_owner_wick):
		for e_v: Variant in _owner_wick.world_get_enemies(_world_ctx):
			if not is_instance_valid(e_v) or not (e_v is Object): continue
			var enemy: Object = e_v as Object
			if not _owner_wick.is_entity_alive(enemy) or not _is_enemy_marked(enemy): continue
			var erad: float = _owner_wick.get_entity_radius(enemy, 8.0)
			var mp: Vector2 = (_owner_wick.get_entity_pos(enemy) + Vector2(0.0, -erad - 11.0 + (0.0 if fred else roundf(sin(_anim_t * 6.0)))) - global_position).round()
			draw_rect(Rect2(mp + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), void_c)
			draw_rect(Rect2(mp + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), void_c)
			draw_rect(Rect2(mp + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), void_c)
			draw_rect(Rect2(mp + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), c_glow)
			draw_rect(Rect2(mp + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), c_glow)
			draw_rect(Rect2(mp + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), pal["gold"] as Color)
			draw_rect(Rect2(mp, Vector2.ONE), c_core)
	if tether_active:
		var a := Vector2(0.0, -3.0); var b: Vector2 = (_tether_end + Vector2(0.0, -4.0) - global_position).round()
		var seg: Vector2 = b - a; var total: float = seg.length()
		if total > 4.0:
			var sdir: Vector2 = seg / total
			draw_line(a, b, void_c, 3.0); draw_line(a, b, c_rim, 1.0)
			var off: float = fmod(_anim_t * (14.0 if fred else 28.0), 8.0); var bi: int = 0
			while off < total:
				var bp: Vector2 = (a + sdir * off).round()
				draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
				draw_rect(Rect2(bp, Vector2(2.0, 2.0)), c_glow if (bi % 2 == 0) else (pal["gold"] as Color))
				draw_rect(Rect2(bp, Vector2.ONE), c_core); off += 8.0; bi += 1
	for tm: Dictionary in _trail:
		var u: float = clampf(float(tm["age"]) / maxf(0.01, float(tm["life"])), 0.0, 1.0)
		var tp: Vector2 = ((tm["pos"] as Vector2) - global_position).round(); var sz: float = 2.0 if u < 0.45 else 1.0
		draw_rect(Rect2(tp - Vector2.ONE, Vector2(sz + 2.0, sz + 2.0)), void_c)
		draw_rect(Rect2(tp, Vector2(sz, sz)), c_core if u < 0.3 else (c_glow if u < 0.68 else c_rim))
	if state == State.PERCH:
		var frac: float = clampf(perch_timer / maxf(0.1, perch_max), 0.0, 1.0)
		draw_arc(Vector2(0.0, 2.0), 7.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(Vector2(0.0, 2.0), 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, c_glow if perch_timer > 1.5 else (pal["coral"] as Color), 1.0)
	for rg: Dictionary in _rings:
		var u: float = clampf(float(rg["age"]) / maxf(0.01, float(rg["life"])), 0.0, 1.0)
		var r: float = roundf(lerpf(float(rg["r0"]), float(rg["r1"]), u))
		var rp: Vector2 = ((rg["pos"] as Vector2) - global_position).round()
		draw_arc(rp, r, 0.0, TAU, 20, void_c, 3.0)
		draw_arc(rp, r, 0.0, TAU, 20, LxPalette.color(str(rg["col"]), "lime"), roundf(float(rg["w"])))
	for sp: Dictionary in _sparks:
		var sp_p: Vector2 = ((sp["pos"] as Vector2) - global_position).round()
		draw_rect(Rect2(sp_p - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
		draw_rect(Rect2(sp_p, Vector2.ONE), LxPalette.color(str(sp["col"]), "lime"))
	var c := Vector2(0.0, -4.0 + (0.0 if fred else roundf(sin(_anim_t * 6.5))))
	if not (state == State.FOLLOW and _idle_t > 3.5 and not _sense_active):
		draw_rect(Rect2(-2.0, 2.0, 4.0, 1.0), void_c)
	var flap: float = 0.0 if fred else (1.0 if (int(floorf(_anim_t * 18.0)) % 2 == 0) else -1.0)
	draw_rect(Rect2(c + Vector2(-4.0, -3.0 + flap), Vector2(3.0, 3.0)), void_c)
	draw_rect(Rect2(c + Vector2(1.0, -3.0 - flap), Vector2(3.0, 3.0)), void_c)
	draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(5.0, 6.0)), void_c)
	draw_rect(Rect2(c + Vector2(-3.0, -2.0 + flap), Vector2(2.0, 1.0)), c_wing)
	draw_rect(Rect2(c + Vector2(2.0, -2.0 - flap), Vector2(2.0, 1.0)), c_wing)
	draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(3.0, 2.0)), c_rim)
	draw_rect(Rect2(c + Vector2(-1.0, 1.0), Vector2(3.0, 2.0)), c_glow)
	draw_rect(Rect2(c + Vector2(0.0, 1.0), Vector2(1.0, 2.0)), c_core)
	if LxFireflyState.get_bond_rank() >= 3:
		draw_rect(Rect2(c + Vector2(-1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
		draw_rect(Rect2(c + Vector2(1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
