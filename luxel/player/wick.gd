class_name LxWick
extends Node2D
## Wick: player controller (92 px/s movement, 100% manual aim, modular kit, hearts/mercy/Assist).
## Loads res://luxel/art/wick/ sprite sheet if present; falls back to Last Light coloured-squares moth.

const MOVE_SPEED: float = 92.0
const BODY_RADIUS: float = 4.0
const MERCY_TIME: float = 1.05
const KNOCK_DECAY: float = 700.0
const INTERACT_RADIUS: float = 24.0
const HS_HURT: float = 0.12
const HS_BLOCK: float = 0.045
const SHAKE_HURT: float = 0.25
const SHAKE_BLOCK: float = 0.08

const PAL_VOID: Color = Color("0d0b1e")
const PAL_NIGHT: Color = Color("211a3b")
const PAL_DUSK: Color = Color("3d2c5c")
const PAL_PLUM: Color = Color("6a3d6f")
const PAL_CORAL: Color = Color("e2725b")
const PAL_APRICOT: Color = Color("f5a96a")
const PAL_GOLD: Color = Color("ffd98c")
const PAL_CREAM: Color = Color("fff4dc")
const PAL_SKY: Color = Color("78a9da")
const PAL_ICE: Color = Color("c7e5ef")
const PAL_STONE: Color = Color("c2a7ae")

var facing: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var knock: Vector2 = Vector2.ZERO
var last_pos: Vector2 = Vector2.ZERO
var mercy_t: float = 0.0
var hurt_flash: float = 0.0
var bounce_t: float = 0.0
var muzzle_t: float = 0.0
var shoot_anim_t: float = 0.0
var throw_anim_t: float = 0.0
var catch_anim_t: float = 0.0
var recoil_vis: float = 0.0
var god: bool = false
var dead: bool = false
var ember: float = 0.0
var _local_hearts: float = 4.0
var _local_max_hearts: int = 4

var lantern: LxLantern = null
var move_bolt: LxMoveBolt = null
var move_dash: LxMoveDash = null
var move_throw: LxMoveThrow = null
var moves: Dictionary = {}
var bolts: Array = []

var shots_fired: int = 0
var zips_count: int = 0
var perfect_dodges: int = 0

var _world_ctx: Node = null
var _prev_act: Dictionary = {}
var _walk_phase: float = 0.0
var _clock_t: float = 0.0
var _arity_cache: Dictionary = {}
var _afterimages: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _sprite_tex: Texture2D = null
var _sprite_frame_size: Vector2i = Vector2i(24, 24)

func _ready() -> void:
	z_index = 1
	_ensure_kit()
	_try_load_sprite()

func setup(world_ctx: Node) -> void:
	_world_ctx = world_ctx
	_ensure_kit()
	_try_load_sprite()
	if Lx.debug != null and Lx.debug.god:
		god = true
	Lx.player = self
	if move_throw != null:
		move_throw.set_world_ctx(world_ctx)
	if Lx.events != null and not Lx.events.move_unlocked.is_connected(_on_move_unlocked):
		Lx.events.move_unlocked.connect(_on_move_unlocked)
	sync_unlocks_from_state()
	if Lx.state != null:
		_local_max_hearts = Lx.state.max_hearts
		_local_hearts = Lx.state.hearts
	reset_for_room(global_position)

func _ensure_kit() -> void:
	if lantern == null or not is_instance_valid(lantern):
		lantern = LxLantern.new()
		lantern.name = "LxLantern"
		add_child(lantern)
		lantern.setup(self)
	if move_bolt == null:
		move_bolt = LxMoveBolt.new()
		register_move(move_bolt, "bolt")
	if move_dash == null:
		move_dash = LxMoveDash.new()
		register_move(move_dash, "dash")
	if move_throw == null:
		move_throw = LxMoveThrow.new()
		register_move(move_throw, "throw")

func register_move(move: LxMove, move_id: String) -> void:
	if move != null:
		move.setup(self, move_id)
		moves[move_id] = move

func sync_unlocks_from_state() -> void:
	_ensure_kit()
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).sync_unlock()

func _on_move_unlocked(_move_id: String) -> void:
	sync_unlocks_from_state()

func reset_for_room(at_pos: Vector2) -> void:
	_ensure_kit()
	global_position = at_pos
	last_pos = at_pos
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	mercy_t = 0.0
	hurt_flash = 0.0
	bounce_t = 0.0
	muzzle_t = 0.0
	shoot_anim_t = 0.0
	throw_anim_t = 0.0
	catch_anim_t = 0.0
	recoil_vis = 0.0
	dead = false
	bolts.clear()
	_afterimages.clear()
	_rings.clear()
	_sparks.clear()
	_prev_act.clear()
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).reset()
	if lantern != null:
		lantern.reset_to_hand(at_pos)
	queue_redraw()

func tick_sim(dt: float, world_ctx: Node) -> void:
	_world_ctx = world_ctx
	_ensure_kit()
	if move_throw != null:
		move_throw.set_world_ctx(world_ctx)
	_clock_t += dt
	_age_fx(dt)
	if dead:
		queue_redraw()
		return

	mercy_t = maxf(0.0, mercy_t - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt * 2.8)
	bounce_t = maxf(0.0, bounce_t - dt)
	muzzle_t = maxf(0.0, muzzle_t - dt)
	shoot_anim_t = maxf(0.0, shoot_anim_t - dt)
	throw_anim_t = maxf(0.0, throw_anim_t - dt)
	catch_anim_t = maxf(0.0, catch_anim_t - dt)
	recoil_vis = maxf(0.0, recoil_vis - dt * 10.0)

	_update_manual_aim()
	_poll_inputs(world_ctx)
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).tick(dt)

	last_pos = global_position
	var desired_vel: Vector2 = Vector2.ZERO
	var airborne: bool = false
	if is_zipping():
		desired_vel = move_throw.get_zip_velocity()
		airborne = true
	elif is_dashing() or is_gliding():
		desired_vel = move_dash.get_active_velocity()
		airborne = move_dash.can_cross_gaps()
	elif bounce_t <= 0.0:
		desired_vel = get_move_input() * MOVE_SPEED

	desired_vel += knock
	knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * dt)
	var next_pos: Vector2 = world_collide_step(world_ctx, global_position, global_position + desired_vel * dt, BODY_RADIUS, airborne)
	velocity = (next_pos - global_position) / maxf(dt, 0.0001)
	global_position = next_pos
	_walk_phase = _walk_phase + dt * 13.0 if (velocity.length() > 10.0 and not is_dashing() and not is_zipping()) else 0.0

	if move_dash != null:
		move_dash.tick_dash(dt, world_ctx)
	if move_throw != null:
		move_throw.tick_zip(dt, world_ctx)
	if lantern != null:
		lantern.tick_sim(dt, self, world_ctx)
	if move_bolt != null:
		move_bolt.tick_bolts(dt, world_ctx)
	queue_redraw()

func _update_manual_aim() -> void:
	if Lx.input == null:
		return
	var mw: Vector2 = get_global_mouse_position() if is_inside_tree() else (global_position + facing * 32.0)
	var aim: Vector2 = Lx.input.get_aim_dir(global_position, mw)
	if aim.length_squared() > 0.0001:
		facing = aim.normalized()

func _poll_inputs(world_ctx: Node) -> void:
	if Lx.input == null:
		return
	for act: String in ["lx_fire", "lx_throw", "lx_dash", "lx_interact"]:
		var now: bool = Lx.input.is_action_active(act)
		var was: bool = bool(_prev_act.get(act, false))
		_prev_act[act] = now
		if now and not was:
			match act:
				"lx_fire": press_fire()
				"lx_throw": press_throw()
				"lx_dash": press_dash()
				"lx_interact": try_interact(world_ctx)
		elif not now and was:
			if act == "lx_fire": release_fire()
			elif act == "lx_dash": release_dash()

func press_fire() -> bool:
	_ensure_kit()
	if dead:
		return false
	if lantern != null and lantern.is_lure_active():
		return try_zip()
	if lantern != null and lantern.state == LxLantern.State.CARRIED:
		emit_sfx("denied", global_position, false)
		return false
	return move_bolt.press() if move_bolt != null else false

func release_fire() -> void:
	if move_bolt != null:
		move_bolt.release()

func press_throw() -> bool:
	_ensure_kit()
	return false if dead or move_throw == null else move_throw.press()

func press_dash() -> bool:
	_ensure_kit()
	return false if dead or move_dash == null else move_dash.press()

func release_dash() -> void:
	if move_dash != null:
		move_dash.release()

func try_zip() -> bool:
	_ensure_kit()
	return false if dead or move_throw == null else move_throw.try_zip()

func try_interact(world_ctx: Node) -> bool:
	var best: Object = null
	var best_d: float = INF
	for it_var: Variant in world_get_interactables(world_ctx):
		if not (it_var is Object and is_instance_valid(it_var as Object)) or not (it_var as Object).has_method("interact"):
			continue
		var obj: Object = it_var as Object
		if obj.get("active") is bool and not bool(obj.get("active")):
			continue
		var irad_v: Variant = obj.get("radius")
		var reach: float = maxf(INTERACT_RADIUS, (float(irad_v) if (irad_v is float or irad_v is int) else 0.0) + 6.0)
		var d: float = get_entity_pos(obj).distance_to(global_position)
		if d <= reach and d < best_d:
			best_d = d
			best = obj
	if best != null:
		best.call("interact")
		return true
	return false

func take_damage(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String = "hazard") -> void:
	if dead:
		return
	if move_dash != null and move_dash.has_iframes():
		move_dash.on_perfect_dodge()
		return
	if is_gliding() and source == "shockwave":
		return
	if is_invulnerable():
		return
	_apply_damage_internal(amount, from_pos, knock_dir, source)

func on_lantern_lost(at_pos: Vector2, reason: String) -> void:
	spawn_ring(at_pos, 3.0, 20.0, 0.28, PAL_CORAL, 1.5)
	spawn_sparks(at_pos, Vector2.UP, 10, PAL_CORAL, 30.0, 95.0, 0.25)
	if not dead and mercy_t <= 0.0:
		_apply_damage_internal(1.0, at_pos, Vector2.ZERO, reason)

func _apply_damage_internal(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String) -> void:
	var mult: float = clampf(float(Lx.save.settings.get("assist_damage_mult", 1.0)), 0.0, 1.0) if Lx.save != null else 1.0
	var dmg: float = 0.0 if god else maxf(0.0, amount * mult)
	if Lx.state != null:
		Lx.state.hearts = maxf(0.0, Lx.state.hearts - dmg)
		if dmg > 0.0:
			Lx.state.hits_taken += 1
		_local_hearts = Lx.state.hearts
		_local_max_hearts = Lx.state.max_hearts
	else:
		_local_hearts = maxf(0.0, _local_hearts - dmg)

	var kdir: Vector2 = knock_dir.normalized() if knock_dir.length_squared() > 0.0001 else ((global_position - from_pos).normalized() if global_position.distance_to(from_pos) > 0.1 else Vector2.ZERO)
	mercy_t = MERCY_TIME
	hurt_flash = 1.0
	knock = kdir * 170.0
	trigger_hitstop(HS_HURT)
	trigger_shake(SHAKE_HURT)
	spawn_ring(global_position, 2.0, 16.0, 0.24, PAL_CORAL, 1.5)
	spawn_sparks(global_position, kdir, 10, PAL_CORAL, 35.0, 100.0, 0.26)
	emit_sfx("wick_hurt", global_position, false)
	if Lx.events != null:
		Lx.events.player_damaged.emit(dmg, from_pos, kdir, source)

	if get_hearts() <= 0.0 and not god and dmg > 0.0:
		dead = true
		if move_dash != null:
			move_dash.cancel()
		if move_throw != null:
			move_throw.cancel_zip()
		if Lx.state != null:
			Lx.state.deaths += 1
		if Lx.events != null:
			Lx.events.player_died.emit()

func get_hearts() -> float:
	return Lx.state.hearts if Lx.state != null else _local_hearts

func get_max_hearts() -> int:
	return Lx.state.max_hearts if Lx.state != null else _local_max_hearts

func is_invulnerable() -> bool:
	return god or mercy_t > 0.0 or is_zipping() or (move_dash != null and move_dash.has_iframes())

func is_dashing() -> bool:
	return move_dash != null and move_dash.active

func is_gliding() -> bool:
	return move_dash != null and move_dash.is_gliding

func is_zipping() -> bool:
	return move_throw != null and move_throw.zipping

func get_move_input() -> Vector2:
	return Lx.input.get_move_vector() if Lx.input != null else Vector2.ZERO

func apply_recoil(impulse: Vector2) -> void:
	knock += impulse

func on_hit_landed(hit: LxHit, result: int, target_pos: Vector2, hitstop_s: float, shake_i: float) -> void:
	if result < 0:
		return
	if result == 0:
		trigger_hitstop(HS_BLOCK)
		trigger_shake(SHAKE_BLOCK)
		spawn_sparks(target_pos, -hit.dir, 5, PAL_STONE, 25.0, 75.0, 0.16)
		emit_sfx("shield_clang", target_pos, true)
		return
	trigger_hitstop(hitstop_s)
	trigger_shake(shake_i)
	var heavy: bool = hit.is_heavy()
	spawn_sparks(target_pos, hit.dir, 8 if heavy else 4, PAL_GOLD if heavy else PAL_CREAM, 30.0, 95.0, 0.20)
	if heavy:
		spawn_ring(target_pos, 2.0, 14.0, 0.20, PAL_GOLD, 1.0)
	emit_sfx("heavy_hit" if heavy else "bolt_chip", target_pos, true)
	if Lx.state != null:
		var sd: Dictionary = Lx.get_move_data("sunflare")
		var gain: float = float(sd.get("ember_per_heavy", 18.0)) if heavy else float(sd.get("ember_per_bolt", 6.0))
		ember = minf(Lx.state.get_effective_ember_max(), ember + gain)

func trigger_hitstop(duration: float) -> void:
	if duration > 0.0:
		if Lx.hitstop != null:
			Lx.hitstop.trigger(duration)
		if Lx.events != null:
			Lx.events.hitstop_requested.emit(duration)

func trigger_shake(intensity: float) -> void:
	if intensity > 0.0:
		if Lx.camera != null:
			Lx.camera.add_shake(intensity)
		if Lx.events != null:
			Lx.events.shake_requested.emit(intensity)

func emit_sfx(sfx_id: String, at_pos: Vector2, spatial: bool) -> void:
	if Lx.events != null:
		Lx.events.sfx_requested.emit(sfx_id, at_pos, spatial)
	elif Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, at_pos, spatial)

func world_collide_step(world_ctx: Node, from_p: Vector2, to_p: Vector2, rad: float, airborne: bool) -> Vector2:
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	if ctx == null:
		return to_p
	if ctx.has_method("collide"):
		var cross_pit: bool = airborne or is_dashing() or is_gliding() or is_zipping()
		var cross_water: bool = is_gliding() or is_zipping()
		return ctx.call("collide", to_p, rad, cross_pit, cross_water) as Vector2
	if ctx.has_method("resolve_move"):
		return ctx.call("resolve_move", from_p, to_p, rad, airborne) as Vector2
	if ctx.has_method("collide_step"):
		return (ctx.call("collide_step", from_p, to_p, rad, airborne) if _method_arity(ctx, "collide_step") >= 4 else ctx.call("collide_step", from_p, to_p, rad)) as Vector2
	if ctx.has_method("is_blocked"):
		var cur: Vector2 = from_p
		if not bool(ctx.call("is_blocked", Vector2(to_p.x, cur.y), rad, airborne)):
			cur.x = to_p.x
		if not bool(ctx.call("is_blocked", Vector2(cur.x, to_p.y), rad, airborne)):
			cur.y = to_p.y
		return cur
	var bvar: Variant = ctx.call("get_bounds") if ctx.has_method("get_bounds") else (ctx.get("bounds") if ctx.get("bounds") is Rect2 else ctx.get("world_bounds"))
	if bvar is Rect2 and (bvar as Rect2).has_area():
		var r: Rect2 = (bvar as Rect2).grow(-rad)
		return Vector2(clampf(to_p.x, r.position.x, r.end.x), clampf(to_p.y, r.position.y, r.end.y))
	return to_p

func world_shot_blocked(world_ctx: Node, from_p: Vector2, to_p: Vector2 = Vector2.INF) -> bool:
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	if ctx == null:
		return false
	var target: Vector2 = to_p if to_p.is_finite() else from_p
	if ctx.has_method("tile_at") and LxMapFormat.blocks_sight_tile(str(ctx.call("tile_at", target))):
		return true
	if ctx.has_method("clear_view"):
		return not bool(ctx.call("clear_view", from_p, target))
	if ctx.has_method("is_shot_blocked"):
		return bool(ctx.call("is_shot_blocked", target))
	return bool(ctx.call("shot_blocked", target)) if ctx.has_method("shot_blocked") else false

func world_get_mirror_hit(world_ctx: Node, from_p: Vector2, to_p: Vector2) -> Dictionary:
	if world_ctx != null and world_ctx.has_method("get_mirror_hit"):
		var res: Variant = world_ctx.call("get_mirror_hit", from_p, to_p)
		return res as Dictionary if res is Dictionary else {}
	return {}

func _world_list(world_ctx: Node, getter: String, prop: String, group_name: String) -> Array:
	if world_ctx != null:
		if world_ctx.has_method(getter):
			var a: Variant = world_ctx.call(getter)
			if a is Array:
				return a as Array
		var v: Variant = world_ctx.get(prop)
		if v is Array:
			return v as Array
	return get_tree().get_nodes_in_group(group_name) if is_inside_tree() else []

func world_get_enemies(world_ctx: Node) -> Array:
	return _world_list(world_ctx, "get_enemies", "enemies", "lx_enemies")

func world_get_interactables(world_ctx: Node) -> Array:
	return _world_list(world_ctx, "get_interactables", "interactables", "lx_interactables")

func get_entity_pos(entity: Object) -> Vector2:
	if entity is Node2D:
		return (entity as Node2D).global_position
	var pv: Variant = entity.get("pos")
	return pv as Vector2 if pv is Vector2 else Vector2.ZERO

func get_entity_radius(entity: Object, fallback: float = 8.0) -> float:
	for key: String in ["body_radius", "radius", "body"]:
		var rv: Variant = entity.get(key)
		if rv is float or rv is int:
			return float(rv)
	return fallback

func is_entity_alive(entity: Object) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.has_method("is_dead") and bool(entity.call("is_dead")):
		return false
	if entity.has_method("is_targetable") and not bool(entity.call("is_targetable")):
		return false
	var dv: Variant = entity.get("dead")
	if dv is bool and bool(dv):
		return false
	var hpv: Variant = entity.get("hp")
	return not ((hpv is float or hpv is int) and float(hpv) <= 0.0)

func is_snatcher_entity(entity: Object) -> bool:
	var kv: Variant = entity.get("kind")
	if kv is String:
		var ks: String = (kv as String).to_lower()
		return ks.contains("snatcher") or ks.contains("magpie") or ks.contains("gull") or ks.contains("thief")
	return false

func apply_hit_to_entity(entity: Object, hit: LxHit) -> int:
	return int(entity.call("take_hit", hit)) if (entity != null and is_instance_valid(entity) and entity.has_method("take_hit")) else -1

func _method_arity(obj: Object, method_name: String) -> int:
	var key: String = "%d:%s" % [obj.get_instance_id(), method_name]
	if _arity_cache.has(key):
		return int(_arity_cache[key])
	for m: Dictionary in obj.get_method_list():
		if str(m.get("name", "")) == method_name:
			var sz: int = (m.get("args", []) as Array).size()
			_arity_cache[key] = sz
			return sz
	_arity_cache[key] = 4
	return 4

func spawn_afterimage(col: Color) -> void:
	_afterimages.append({"pos": global_position, "age": 0.0, "life": 0.20, "col": col})

func spawn_ring(at_pos: Vector2, r0: float, r1: float, life: float, col: Color, width: float = 1.0) -> void:
	_rings.append({"pos": at_pos, "r0": r0, "r1": r1, "age": 0.0, "life": maxf(0.02, life), "col": col, "w": width})

func spawn_sparks(at_pos: Vector2, base_dir: Vector2, count: int, col: Color, min_spd: float, max_spd: float, life: float) -> void:
	var dn: Vector2 = base_dir.normalized() if base_dir.length_squared() > 0.0001 else Vector2.RIGHT
	for _i: int in range(count):
		_sparks.append({"pos": at_pos, "vel": dn.rotated(randf_range(-0.65, 0.65)) * randf_range(min_spd, max_spd), "age": 0.0, "life": life, "col": col})

func _age_fx(dt: float) -> void:
	for arr: Array[Dictionary] in [_afterimages, _rings]:
		for i: int in range(arr.size() - 1, -1, -1):
			arr[i]["age"] = float(arr[i]["age"]) + dt
			if float(arr[i]["age"]) >= float(arr[i]["life"]):
				arr.remove_at(i)
	for i: int in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s["age"] = float(s["age"]) + dt
		var vel: Vector2 = s["vel"] as Vector2
		s["pos"] = (s["pos"] as Vector2) + vel * dt
		s["vel"] = vel * pow(0.08, dt)
		if float(s["age"]) >= float(s["life"]):
			_sparks.remove_at(i)

func _try_load_sprite() -> void:
	if _sprite_tex != null:
		return
	for path: String in ["res://luxel/art/wick/wick.png", "res://luxel/art/wick/sheet.png"]:
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is Texture2D:
				_sprite_tex = res as Texture2D
				return

func _draw() -> void:
	var off: Vector2 = -global_position
	for a: Dictionary in _afterimages:
		var t: float = 1.0 - clampf(float(a["age"]) / float(a["life"]), 0.0, 1.0)
		draw_rect(Rect2(((a["pos"] as Vector2) + off).round() + Vector2(-4.0, -10.0), Vector2(8.0, 10.0)), Color(a["col"] as Color, t * 0.55))
	for r: Dictionary in _rings:
		var t: float = clampf(float(r["age"]) / float(r["life"]), 0.0, 1.0)
		draw_arc(((r["pos"] as Vector2) + off).round(), lerpf(float(r["r0"]), float(r["r1"]), t), 0.0, TAU, 20, Color(r["col"] as Color, 1.0 - t), float(r["w"]))
	for s: Dictionary in _sparks:
		draw_rect(Rect2(((s["pos"] as Vector2) + off).round(), Vector2(1.0, 1.0)), s["col"] as Color)
	for b_var: Variant in bolts:
		var b: LxMoveBolt.Bolt = b_var as LxMoveBolt.Bolt
		if b != null:
			var bp: Vector2 = (b.pos + off).round()
			draw_line((bp - b.dir * 5.0).round(), bp, PAL_ICE if b.is_prism else PAL_GOLD, 2.0)
			draw_rect(Rect2(bp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), PAL_CREAM)

	var flash_red: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var alpha: float = 0.40 if (mercy_t > 0.0 and not flash_red and (int(mercy_t * 14.0) % 2 == 0)) else 1.0
	var base: Vector2 = (-facing * clampf(recoil_vis * 1.5, 0.0, 1.5)).round() + Vector2(0.0, -roundf(absf(sin(_walk_phase)) * 2.0))
	var lan_in_hand: bool = lantern == null or lantern.is_in_hand()
	var hand_pos: Vector2 = (base + facing * 6.0 + Vector2(0.0, -6.0)).round()

	draw_rect(Rect2(Vector2(-4.0, -1.0), Vector2(8.0, 3.0)), Color(PAL_VOID, 0.45))
	if lan_in_hand:
		var pulse: float = 0.92 + 0.08 * sin(_clock_t * 7.0)
		draw_circle(hand_pos, 13.0 * pulse, Color(PAL_GOLD, 0.10))
		draw_circle(hand_pos, 6.5 * pulse, Color(PAL_APRICOT, 0.15))

	var hit_white: bool = hurt_flash > 0.55 and not flash_red
	if _sprite_tex != null:
		var sz := Vector2(_sprite_frame_size)
		var mod: Color = Color(PAL_CREAM, alpha) if hit_white else Color(1.0, 1.0, 1.0, alpha)
		draw_texture_rect_region(_sprite_tex, Rect2(base + Vector2(-sz.x * 0.5, -sz.y), sz), Rect2(Vector2.ZERO, sz), mod)
	else:
		_draw_fallback_moth(base, hit_white, alpha, lan_in_hand, hand_pos)

	draw_rect(Rect2((facing * 12.0 + Vector2(0.0, -6.0)).round() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), PAL_GOLD)
	if muzzle_t > 0.0:
		draw_circle(hand_pos, 3.5, PAL_CREAM)

func _draw_fallback_moth(base: Vector2, hit_white: bool, alpha: float, lan_in_hand: bool, hand_pos: Vector2) -> void:
	var c_out := Color(PAL_NIGHT, alpha)
	var c_cloak := Color(PAL_CREAM if hit_white else (PAL_ICE if is_dashing() else (PAL_GOLD if is_zipping() else PAL_DUSK)), alpha)
	var c_wing := Color(PAL_CREAM if hit_white else PAL_PLUM, alpha)
	var wing_w: float = 12.0 if is_gliding() else 10.0
	draw_rect(Rect2(base + Vector2(-wing_w * 0.5, -10.0), Vector2(wing_w, 6.0)), c_out)
	draw_rect(Rect2(base + Vector2(-wing_w * 0.5 + 1.0, -9.0), Vector2(wing_w - 2.0, 4.0)), c_wing)
	draw_rect(Rect2(base + Vector2(-4.0, -11.0), Vector2(8.0, 10.0)), c_out)
	draw_rect(Rect2(base + Vector2(-3.0, -10.0), Vector2(6.0, 8.0)), c_cloak)
	draw_rect(Rect2(base + Vector2(-3.0, -15.0), Vector2(6.0, 5.0)), c_out)
	draw_rect(Rect2(base + Vector2(-2.0, -14.0), Vector2(4.0, 3.0)), Color(PAL_CREAM, alpha))
	draw_rect(Rect2(base + Vector2(-2.0, -17.0), Vector2(1.0, 2.0)), Color(PAL_GOLD, alpha))
	draw_rect(Rect2(base + Vector2(1.0, -17.0), Vector2(1.0, 2.0)), Color(PAL_GOLD, alpha))
	if lan_in_hand:
		draw_rect(Rect2(hand_pos + Vector2(-2.0, -2.0), Vector2(4.0, 5.0)), c_out)
		draw_rect(Rect2(hand_pos + Vector2(-1.0, -1.0), Vector2(2.0, 3.0)), Color(PAL_GOLD, alpha))
		draw_rect(Rect2(hand_pos + Vector2(-1.0, 0.0), Vector2(2.0, 1.0)), Color(PAL_CREAM, alpha))
