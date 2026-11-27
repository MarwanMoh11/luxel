class_name LxFireflyCompanion
extends Node2D
## Pip the Firefly Companion: true wayfinder, puzzle partner, and scout light for Wick.
## 100% manual-aim Send/Perch/Recall (AIM_ASSIST_ENABLED == false), pure visual/light
## Resonance Bridge with hung lantern, active "when stuck" + on-demand Wayfinder Lead,
## and an earned, long-cooldown late-game Companion Special ("Starfall Radiance").
## Zero regular combat-weapon rotation; original Wick combat math stays 100% untouched.

enum State { BECKON, FOLLOW, SEND, PERCH, RECALL, GUIDE, SPECIAL }

const AIM_ASSIST_ENABLED: bool = false
const SEND_SPEED: float = 340.0
const RECALL_SPEED: float = 460.0
const GUIDE_SPEED: float = 168.0
const BRIDGE_MAX_DIST: float = 156.0
const HOLD_GUIDE_S: float = 0.35
const HOLD_SPECIAL_S: float = 0.50
const SPECIAL_DAMAGE: float = 4.5
const SPECIAL_SWOOP_S: float = 0.42
const SPECIAL_APEX_S: float = 0.16
const BECKON_CENTER: Vector2 = Vector2(652.0, 352.0)

var state: State = State.FOLLOW
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var cooldown_left: float = 0.0
var special_cd: float = 0.0
var perch_timer: float = 0.0
var perch_max: float = 6.5
var tether_active: bool = false
var sanctuary_buff_active: bool = false

var _owner_wick: LxWick = null
var _world_ctx: Node = null
var _anim_t: float = 0.0
var _send_dir: Vector2 = Vector2.RIGHT
var _send_dist: float = 0.0
var _send_max: float = 132.0
var _join_t: float = 0.0
var _idle_t: float = 0.0
var _stuck_t: float = 0.0
var _stuck_anchor: Vector2 = Vector2.INF
var _auto_guide_cd: float = 0.0
var _sense_cd: float = 0.0
var _chirp_cd: float = 0.0
var _perch_light_cd: float = 0.0
var _tether_end: Vector2 = Vector2.ZERO
var _sense_dir: Vector2 = Vector2.ZERO
var _sense_active: bool = false
var _sense_is_secret: bool = false

# Hold gesture state (tap = manual send/recall, hold = Wayfinder Lead / late-game Starfall)
var _hold_active: bool = false
var _hold_t: float = 0.0
var _hold_fired: bool = false
var _hold_will_special: bool = false

# Wayfinder Lead state
var _guide_target: Vector2 = Vector2.INF
var _guide_goal: Vector2 = Vector2.ZERO
var _guide_dir: Vector2 = Vector2.RIGHT
var _guide_kind: String = ""
var _guide_t: float = 0.0
var _guide_pulse_cd: float = 0.0

# Late-game Starfall Radiance state
var _special_t: float = 0.0
var _special_burst_done: bool = false
var _special_origin: Vector2 = Vector2.ZERO

var _trail_acc: float = 0.0
var _hit_ids: Array[int] = []
var _trail: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	top_level = true; z_index = 4; texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(p_wick: LxWick) -> void:
	_owner_wick = p_wick; Lx.companion = self
	reset_for_room(p_wick.global_position if p_wick != null else Vector2.ZERO)


func _exit_tree() -> void:
	if Lx.companion == self: Lx.companion = null


func reset_for_room(at_pos: Vector2) -> void:
	cooldown_left = 0.0; perch_timer = 0.0; perch_max = LxFireflyState.get_perch_duration()
	tether_active = false; sanctuary_buff_active = false; vel = Vector2.ZERO
	_send_dist = 0.0; _join_t = 0.0; _idle_t = 0.0; _stuck_t = 0.0; _stuck_anchor = at_pos
	_auto_guide_cd = 2.0; _sense_cd = 0.0; _chirp_cd = 0.0; _perch_light_cd = 0.0
	_sense_active = false; _sense_is_secret = false; _sense_dir = Vector2.ZERO
	_hold_active = false; _hold_t = 0.0; _hold_fired = false; _hold_will_special = false
	_guide_target = Vector2.INF; _guide_kind = ""; _guide_t = 0.0; _guide_pulse_cd = 0.0
	_special_t = 0.0; _special_burst_done = false
	_hit_ids.clear(); _trail.clear(); _rings.clear(); _sparks.clear()
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
		Lx.events.prompt_requested.emit("PIP_JOIN_HINT", "lx_firefly", 3.8)
	queue_redraw()


func on_input_down(world_ctx: Node) -> bool:
	_world_ctx = world_ctx
	if not is_joined() or _owner_wick == null or not is_instance_valid(_owner_wick) or _owner_wick.dead:
		return false
	if state == State.SEND or state == State.PERCH:
		_begin_recall(); return true
	if state == State.GUIDE:
		state = State.FOLLOW; _guide_t = 0.0; return press_command(world_ctx)
	if state == State.FOLLOW:
		_hold_active = true; _hold_t = 0.0; _hold_fired = false
		_hold_will_special = is_special_ready() and LxFireflyGuide.has_nearby_enemies(_owner_wick, world_ctx, 112.0)
		return true
	return false


func on_input_up(world_ctx: Node) -> bool:
	_world_ctx = world_ctx
	if not _hold_active:
		return false
	var should_send: bool = not _hold_fired
	_hold_active = false; _hold_t = 0.0; _hold_fired = false; _hold_will_special = false
	if should_send:
		return press_command(world_ctx)
	return false


func press_command(world_ctx: Node) -> bool:
	_world_ctx = world_ctx
	if not is_joined() or _owner_wick == null or not is_instance_valid(_owner_wick) or _owner_wick.dead:
		return false
	if state == State.FOLLOW or state == State.GUIDE:
		if cooldown_left > 0.0: return false
		if Lx.state != null: Lx.state.story_flags["pip_sent_once"] = true
		# 100% manual aim strictly along wick.facing (AIM_ASSIST_ENABLED == false).
		var aim: Vector2 = _owner_wick.facing.normalized() if _owner_wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var spd: float = SEND_SPEED * LxFireflyState.get_send_speed_mult()
		_send_dir = aim; prev_pos = _owner_wick.global_position
		pos = _owner_wick.global_position + aim * 6.0; vel = aim * spd
		_send_dist = 0.0; _send_max = LxFireflyState.get_send_range()
		state = State.SEND; tether_active = false; _hit_ids.clear()
		_spawn_ring(pos, 2.0, 12.0, 0.22, "lime", 1.0); _spawn_ring(pos, 1.0, 8.0, 0.18, "gold", 1.0)
		_spawn_sparks(pos, 5, "lime", 26.0, 68.0, 0.20); _emit_sfx("pip_send", pos, true)
		global_position = pos.round(); queue_redraw()
		return true
	if state == State.SEND or state == State.PERCH:
		_begin_recall(); return true
	return false


func trigger_wayfinder(world_ctx: Node, on_demand: bool = true) -> bool:
	_world_ctx = world_ctx
	if not is_joined() or _owner_wick == null or not is_instance_valid(_owner_wick) or _owner_wick.dead:
		return false
	if state != State.FOLLOW and state != State.GUIDE:
		return false
	var target: Dictionary = LxFireflyGuide.find_guide_target(_owner_wick, world_ctx, LxFireflyState.get_sense_range_mult(), on_demand)
	if target.is_empty():
		if on_demand:
			_join_t = 0.65; _emit_sfx("pip_chirp", pos, true)
			_spawn_ring(pos, 2.0, 14.0, 0.28, "lime", 1.0)
		return false
	var tpos: Vector2 = target["pos"] as Vector2
	var delta: Vector2 = tpos - _owner_wick.global_position
	var dist: float = delta.length()
	if dist < 12.0:
		return false
	_guide_target = tpos
	_guide_dir = delta / dist
	_guide_kind = str(target.get("kind", "objective"))
	var step_dist: float = minf(dist - 10.0, 56.0)
	_guide_goal = _find_clear_guide_goal(world_ctx, _owner_wick.global_position, _guide_dir, maxf(18.0, step_dist))
	_guide_t = 2.0; _guide_pulse_cd = 0.0; _auto_guide_cd = 8.5
	state = State.GUIDE; tether_active = false
	_emit_sfx("pip_chirp", pos, true)
	var col: String = "ice" if (_guide_kind in ["moth", "cracked_wall", "phantom_platform"] and LxFireflyState.has_charm("prism_wing")) else "gold"
	_spawn_ring(pos, 2.0, 14.0, 0.28, col, 1.0)
	_spawn_sparks(pos, 6, col, 18.0, 52.0, 0.28)
	if on_demand:
		var hud: Object = Lx.ui.get("hud") as Object if (Lx.ui != null and Lx.ui.get("hud") is Object) else null
		if hud != null and is_instance_valid(hud) and hud.has_method("spawn_world_cue"):
			hud.call("spawn_world_cue", "PIP_GUIDE_CUE", _owner_wick.global_position + Vector2(0.0, -16.0), col, 1.6)
	queue_redraw()
	return true


func trigger_special(world_ctx: Node) -> bool:
	_world_ctx = world_ctx
	if not is_joined() or _owner_wick == null or not is_instance_valid(_owner_wick) or _owner_wick.dead:
		return false
	if not is_special_ready() or state == State.SPECIAL:
		return false
	special_cd = LxFireflyState.get_special_cooldown()
	state = State.SPECIAL; tether_active = false
	_special_t = SPECIAL_SWOOP_S; _special_burst_done = false
	_special_origin = _owner_wick.global_position
	_spawn_ring(pos, 2.0, 16.0, 0.22, "gold", 2.0)
	_emit_sfx("pip_bond_up", pos, false)
	var hud: Object = Lx.ui.get("hud") as Object if (Lx.ui != null and Lx.ui.get("hud") is Object) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("spawn_world_cue"):
		hud.call("spawn_world_cue", "PIP_SPECIAL_NAME", _owner_wick.global_position + Vector2(0.0, -18.0), "gold", 1.8)
	queue_redraw()
	return true


func tick_sim(dt: float, wick: LxWick, world_ctx: Node) -> void:
	_owner_wick = wick; _world_ctx = world_ctx; _anim_t += dt; prev_pos = pos; tether_active = false
	cooldown_left = maxf(0.0, cooldown_left - dt)
	special_cd = maxf(0.0, special_cd - dt)
	_join_t = maxf(0.0, _join_t - dt)
	_chirp_cd = maxf(0.0, _chirp_cd - dt)
	_auto_guide_cd = maxf(0.0, _auto_guide_cd - dt)
	_age_fx(dt)
	sanctuary_buff_active = LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance) and LxFireflyWorldContent.active_instance.is_sanctuary_buff_active()
	_tick_hold_gesture(dt, wick, world_ctx)
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
		State.GUIDE: _tick_guide(dt, wick, world_ctx)
		State.SPECIAL: _tick_special(dt, wick, world_ctx)
	_emit_trail(dt); global_position = pos.round(); queue_redraw()


func _tick_hold_gesture(dt: float, wick: LxWick, world_ctx: Node) -> void:
	if not _hold_active or _hold_fired:
		return
	if state != State.FOLLOW or wick == null or not is_instance_valid(wick) or wick.dead:
		_hold_active = false; _hold_t = 0.0; return
	_hold_t += dt
	_hold_will_special = is_special_ready() and LxFireflyGuide.has_nearby_enemies(wick, world_ctx, 112.0)
	if _hold_will_special:
		if _hold_t >= HOLD_SPECIAL_S:
			_hold_fired = true
			trigger_special(world_ctx)
	elif _hold_t >= HOLD_GUIDE_S:
		_hold_fired = true
		trigger_wayfinder(world_ctx, true)


func _tick_follow(dt: float, wick: LxWick, world_ctx: Node) -> void:
	var moving: bool = wick.velocity.length_squared() > 16.0
	_idle_t = 0.0 if (moving or _join_t > 0.0 or _hold_active) else (_idle_t + dt)
	if not _stuck_anchor.is_finite() or wick.global_position.distance_to(_stuck_anchor) > 48.0:
		_stuck_anchor = wick.global_position; _stuck_t = 0.0
	else:
		_stuck_t += dt
	_sense_cd = maxf(0.0, _sense_cd - dt)
	if _sense_cd <= 0.0:
		_sense_cd = 0.15
		var sense_info: Dictionary = LxFireflyGuide.find_passive_sense(wick, world_ctx, LxFireflyState.get_sense_range_mult())
		_sense_active = not sense_info.is_empty()
		_sense_is_secret = bool(sense_info.get("is_secret", false))
		if _sense_active:
			var dvec: Vector2 = (sense_info["pos"] as Vector2) - wick.global_position
			_sense_dir = dvec.normalized() if dvec.length_squared() > 0.01 else Vector2.ZERO
			if _chirp_cd <= 0.0 and _join_t <= 0.0:
				_chirp_cd = 7.0; _emit_sfx("pip_chirp", pos, true)
				var scol: String = "ice" if (_sense_is_secret and LxFireflyState.has_charm("prism_wing")) else "lime"
				_spawn_ring(pos, 2.0, 9.0, 0.24, scol, 1.0)
		else:
			_sense_dir = Vector2.ZERO

	# Auto "when stuck" Wayfinder flutter when lingering idle or wandering without progress (paused during locked boss arenas)
	var arena_locked: bool = world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("is_arena_locked") and bool(world_ctx.call("is_arena_locked"))
	var idle_lim: float = LxFireflyState.get_wayfinder_idle_delay()
	if not arena_locked and _auto_guide_cd <= 0.0 and _join_t <= 0.0 and not _hold_active and (_idle_t >= idle_lim or _stuck_t >= idle_lim * 2.4):
		if trigger_wayfinder(world_ctx, false):
			_stuck_t = 0.0; return

	var desired: Vector2 = wick.global_position
	if _join_t > 0.0:
		var u: float = _join_t / 1.5; var rad: float = lerpf(10.0, 22.0, u); var ang: float = _anim_t * 8.5
		desired = wick.global_position + Vector2(cos(ang) * rad, sin(ang) * rad * 0.65 - 8.0 - sin(u * PI) * 8.0)
	elif _idle_t > 3.2 and not _sense_active:
		desired = wick.global_position + Vector2(0.0, -13.0)
	else:
		var fdir: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var bob: float = 0.0 if LxHudFx.flash_reduced() else sin(_anim_t * 4.4) * 1.8
		desired = wick.global_position - fdir * 11.0 + Vector2(0.0, -10.0 + bob) + (_sense_dir * 10.0 if _sense_active else Vector2.ZERO)
	pos = desired if pos.distance_squared_to(desired) > 25600.0 else pos.lerp(desired, clampf(dt * 8.5, 0.0, 1.0))
	vel = (pos - prev_pos) / maxf(dt, 0.0001)


func _tick_guide(dt: float, wick: LxWick, _world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick):
		state = State.FOLLOW; vel = Vector2.ZERO; return
	_guide_t -= dt; _guide_pulse_cd = maxf(0.0, _guide_pulse_cd - dt)
	var desired: Vector2 = _guide_goal if _guide_t > 0.55 else (wick.global_position + Vector2(0.0, -10.0))
	if _guide_t > 0.55:
		var bob_ang: float = _anim_t * 6.2
		desired += Vector2(cos(bob_ang) * 3.5, sin(bob_ang) * 2.5 - 4.0)
	var delta: Vector2 = desired - pos
	var dlen: float = delta.length()
	if dlen > 1.0:
		var step: float = minf(GUIDE_SPEED * dt, dlen)
		pos += (delta / dlen) * step
		vel = (delta / dlen) * GUIDE_SPEED
	else:
		vel = Vector2.ZERO
	if _guide_t > 0.55 and _guide_pulse_cd <= 0.0:
		_guide_pulse_cd = 0.42
		var pcol: String = "ice" if (_guide_kind in ["moth", "cracked_wall", "phantom_platform"] and LxFireflyState.has_charm("prism_wing")) else "gold"
		_spawn_ring(pos, 2.0, 11.0, 0.26, pcol, 1.0)
		if _sparks.size() < 32:
			_sparks.append({"pos": pos + Vector2(0.0, -3.0), "vel": _guide_dir * 42.0, "age": 0.0, "life": 0.36, "col": pcol})
	if _guide_t <= 0.0:
		state = State.FOLLOW; _guide_target = Vector2.INF; _idle_t = 0.0


func _tick_special(dt: float, wick: LxWick, world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick):
		state = State.FOLLOW; vel = Vector2.ZERO; return
	_special_t -= dt
	var elapsed: float = SPECIAL_SWOOP_S - _special_t
	var u: float = clampf(elapsed / SPECIAL_SWOOP_S, 0.0, 1.0)
	var ang: float = u * TAU * 1.5
	var rad: float = sin(u * PI) * 18.0
	pos = wick.global_position + Vector2(cos(ang) * rad, sin(ang) * rad * 0.55 - 10.0 - sin(u * PI) * 10.0)
	vel = (pos - prev_pos) / maxf(dt, 0.0001)
	if not _special_burst_done and elapsed >= SPECIAL_APEX_S:
		_special_burst_done = true
		_execute_starfall_radiance(wick, world_ctx, wick.global_position)
	if _special_t <= 0.0:
		state = State.FOLLOW; vel = Vector2.ZERO


func _execute_starfall_radiance(wick: LxWick, world_ctx: Node, center: Vector2) -> void:
	var wave_r: float = LxFireflyState.get_special_radius()
	_spawn_ring(center, 6.0, wave_r, 0.40, "gold", 2.0)
	_spawn_ring(center, 4.0, wave_r * 0.72, 0.32, "lime", 2.0)
	_spawn_ring(center, 2.0, wave_r * 0.45, 0.24, "cream", 1.0)
	_spawn_sparks(center, 16, "gold", 42.0, 128.0, 0.36)
	_spawn_sparks(center, 10, "cream", 28.0, 92.0, 0.28)
	_burst_light(center, wave_r * 1.4, 1.38, 0.55)
	_emit_sfx("dawn_burst", center, false)
	wick.trigger_shake(0.14)
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("apply_light"):
		world_ctx.call("apply_light", center, wave_r, "pip_light")
	for e_v: Variant in wick.world_get_enemies(world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object):
			continue
		var enemy: Object = e_v as Object
		var pats: Variant = enemy.get("patterns")
		if is_instance_valid(pats) and pats is Object and (pats as Object).has_method("clear_bolts_in_radius"):
			(pats as Object).call("clear_bolts_in_radius", center, wave_r)
		if not wick.is_entity_alive(enemy):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		if epos.distance_to(center) <= wave_r:
			var ndir: Vector2 = (epos - center).normalized() if epos.distance_to(center) > 0.1 else Vector2.RIGHT
			wick.apply_hit_to_entity(enemy, LxHit.make("pip_special", SPECIAL_DAMAGE, ndir, center, 2.2, true, false, wick, false))


func _tick_send(dt: float, wick: LxWick, world_ctx: Node) -> void:
	var spd: float = SEND_SPEED * LxFireflyState.get_send_speed_mult()
	var step: float = spd * dt
	var next_p: Vector2 = pos + _send_dir * step
	if _is_wall_tile(world_ctx, next_p): _enter_perch(); return
	pos = next_p; vel = _send_dir * spd; _send_dist += step
	var pass_r: float = LxFireflyState.get_pass_radius()
	_notify_world_pass(pos, prev_pos, pass_r)
	_sweep_interactables(wick, world_ctx, pass_r)
	if state == State.SEND and _send_dist >= _send_max: _enter_perch()


func _tick_perch(dt: float, wick: LxWick, world_ctx: Node) -> void:
	vel = Vector2.ZERO; perch_timer -= dt; _perch_light_cd = maxf(0.0, _perch_light_cd - dt)
	_notify_world_pass(pos, pos, LxFireflyState.get_pass_radius())
	var bridge_on: bool = false
	var lan_p: Vector2 = Vector2.ZERO
	if wick != null and is_instance_valid(wick) and wick.lantern != null and is_instance_valid(wick.lantern) and wick.lantern.is_lure_active():
		lan_p = wick.lantern.pos
		if pos.distance_to(lan_p) <= BRIDGE_MAX_DIST:
			bridge_on = true; tether_active = true; _tether_end = lan_p
	if _perch_light_cd <= 0.0:
		_perch_light_cd = 0.12
		if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("apply_light"):
			world_ctx.call("apply_light", pos, LxFireflyState.get_light_radius() * 0.72, "pip_light")
			# Pure visual/light Resonance Bridge illuminates path, phantom platforms, light plants & sensors (zero DPS!)
			if bridge_on:
				world_ctx.call("apply_light", pos.lerp(lan_p, 0.35), 42.0, "pip_light")
				world_ctx.call("apply_light", pos.lerp(lan_p, 0.68), 42.0, "pip_light")
				_burst_light(pos.lerp(lan_p, 0.5), 52.0, 0.85, 0.18)
	if perch_timer <= 0.0: _begin_recall()


func _tick_recall(dt: float, wick: LxWick, _world_ctx: Node) -> void:
	if wick == null or not is_instance_valid(wick): state = State.FOLLOW; vel = Vector2.ZERO; return
	var target: Vector2 = wick.global_position + Vector2(0.0, -8.0)
	var delta: Vector2 = target - pos; var dlen: float = delta.length()
	var spd: float = RECALL_SPEED * LxFireflyState.get_send_speed_mult()
	if dlen <= 10.0:
		pos = target; vel = Vector2.ZERO; state = State.FOLLOW
		cooldown_left = LxFireflyState.get_cooldown()
		_emit_sfx("pip_chirp", pos, false); return
	var rdir: Vector2 = delta / dlen
	pos += rdir * minf(spd * dt, dlen); vel = rdir * spd
	_notify_world_pass(pos, prev_pos, LxFireflyState.get_pass_radius())


func _enter_perch() -> void:
	state = State.PERCH; vel = Vector2.ZERO
	perch_max = LxFireflyState.get_perch_duration(); perch_timer = perch_max; _perch_light_cd = 0.0
	_spawn_ring(pos, 2.0, 10.0, 0.22, "lime", 1.0); _burst_light(pos, 48.0, 1.05, 0.22)


func _begin_recall() -> void:
	state = State.RECALL; tether_active = false; _emit_sfx("pip_recall", pos, true)


func _sweep_interactables(wick: LxWick, world_ctx: Node, pass_r: float) -> void:
	if wick == null or not is_instance_valid(wick): return
	for it_v: Variant in wick.world_get_interactables(world_ctx):
		if not is_instance_valid(it_v) or not (it_v is Object): continue
		var item: Object = it_v as Object
		if item.get("active") is bool and not bool(item.get("active")): continue
		var iid: int = item.get_instance_id()
		if _hit_ids.has(iid): continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		if Geometry2D.get_closest_point_to_segment(ipos, prev_pos, pos).distance_to(ipos) > wick.get_entity_radius(item, 8.0) + pass_r: continue
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
		elif (k == "light_plant" or k == "light_sensor" or k == "phantom_platform" or k == "moth") and item.has_method("on_light"):
			item.call("on_light", LxFireflyState.get_light_radius() * 0.72, "pip_light")


func _find_clear_guide_goal(world_ctx: Node, origin: Vector2, dir: Vector2, dist: float) -> Vector2:
	var out: Vector2 = origin
	var steps: int = maxi(1, int(ceilf(dist / 8.0)))
	for i: int in range(1, steps + 1):
		var cand: Vector2 = origin + dir * (dist * float(i) / float(steps))
		if _is_wall_tile(world_ctx, cand):
			break
		out = cand
	return out


func is_out() -> bool: return state == State.SEND or state == State.PERCH or state == State.RECALL
func is_perched() -> bool: return state == State.PERCH
func is_guiding() -> bool: return state == State.GUIDE
func is_joined() -> bool: return LxFireflyState.is_joined()
func is_special_ready() -> bool: return LxFireflyState.is_special_unlocked() and special_cd <= 0.01


func get_light_pool() -> Vector4:
	if state == State.BECKON: return Vector4(pos.x, pos.y - 3.0, 52.0, 0.92)
	if state == State.SPECIAL: return Vector4(pos.x, pos.y - 3.0, LxFireflyState.get_light_radius() * 1.45, 1.35)
	var mult: float = 1.10 if state == State.PERCH else (0.98 if (is_out() or state == State.GUIDE) else 0.74)
	return Vector4(pos.x, pos.y - 3.0, LxFireflyState.get_light_radius() * mult, 1.08 if (is_out() or state == State.GUIDE) else 0.78)


func get_hud_state() -> Dictionary:
	return {
		"joined": is_joined(), "state": state, "out": is_out(), "perched": is_perched(), "guiding": is_guiding(),
		"cooldown": cooldown_left, "cooldown_max": LxFireflyState.get_cooldown(),
		"special_unlocked": LxFireflyState.is_special_unlocked(), "special_ready": is_special_ready(),
		"special_cd": special_cd, "special_cd_max": LxFireflyState.get_special_cooldown(),
		"perch_left": perch_timer, "perch_max": perch_max,
		"perch_frac": clampf(perch_timer / maxf(perch_max, 0.05), 0.0, 1.0),
		"tether": tether_active, "tethered": tether_active,
		"rank": LxFireflyState.get_bond_rank(), "nectar": LxFireflyState.get_nectar_count(),
		"blooms": LxFireflyState.get_bloom_count(), "total_blooms": LxFireflyState.TOTAL_BLOOMS,
		"relays": LxFireflyState.get_relay_count(), "total_relays": LxFireflyState.TOTAL_RELAYS,
		"perches": LxFireflyState.get_perch_count(), "total_perches": LxFireflyState.TOTAL_PERCHES,
		"shrines": LxFireflyState.get_shrine_count(), "charms": LxFireflyState.get_charm_count(),
		"sanctuary": sanctuary_buff_active, "tint": LxFireflyState.get_tint_id(),
	}


func _notify_world_pass(cur_p: Vector2, old_p: Vector2, rad: float) -> void:
	if LxFireflyWorldContent.active_instance != null and is_instance_valid(LxFireflyWorldContent.active_instance):
		LxFireflyWorldContent.active_instance.on_pip_pass(cur_p, old_p, rad, self)


func _is_wall_tile(world_ctx: Node, p: Vector2) -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"): return false
	var t: String = str(world_ctx.call("tile_at", p))
	return t == "wall" or t == "pillar"


func _emit_trail(dt: float) -> void:
	var rate: float = 0.032 if (state == State.SEND or state == State.RECALL or state == State.GUIDE or state == State.SPECIAL) else (0.14 if LxHudFx.flash_reduced() else 0.09)
	_trail_acc += dt
	if _trail_acc < rate: return
	_trail_acc = 0.0
	if _trail.size() >= 6: _trail.pop_front()
	_trail.append({"pos": pos + Vector2(0.0, -3.0), "age": 0.0, "life": 0.30})


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
		if _sparks.size() >= 36: _sparks.pop_front()
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
	LxFireflyDraw.draw_companion(self, self)
