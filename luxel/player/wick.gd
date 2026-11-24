class_name LxWick
extends Node2D
## Wick: player controller (92 px/s movement, 100% manual aim, 8-move modular kit, hearts/mercy/Assist).
## FX pools and sprite/greybox rendering live in luxel/player/wick_fx.gd.

const MovePrism := preload("res://luxel/player/kit/prism.gd")
const MoveBeam := preload("res://luxel/player/kit/beam.gd")
const MoveWings := preload("res://luxel/player/kit/wings.gd")
const MoveLens := preload("res://luxel/player/kit/lens.gd")
const MoveSunflare := preload("res://luxel/player/kit/sunflare.gd")
const WickFx := preload("res://luxel/player/wick_fx.gd")

const MOVE_SPEED: float = 92.0
const BODY_RADIUS: float = 4.0
const MERCY_TIME: float = 1.05
const KNOCK_DECAY: float = 700.0
const INTERACT_RADIUS: float = 24.0
const GRAB_HOLD_DELAY: float = 0.16
const GRAB_SLIDE_SPEED: float = 58.0
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
var move_prism: MovePrism = null
var move_beam: MoveBeam = null
var move_wings: MoveWings = null
var move_lens: MoveLens = null
var move_sunflare: MoveSunflare = null
var moves: Dictionary = {}
var bolts: Array = []

var shots_fired: int = 0
var zips_count: int = 0
var perfect_dodges: int = 0

var grabbed_block: Object = null
var grab_axis: Vector2 = Vector2.ZERO
var grab_slide_speed: float = 0.0
var _interact_held: bool = false
var _interact_hold_t: float = 0.0
var _interact_cand: Object = null
var _last_safe_pos: Vector2 = Vector2.ZERO

var _world_ctx: Node = null
var _prev_act: Dictionary = {}
var _walk_phase: float = 0.0
var _clock_t: float = 0.0
var _arity_cache: Dictionary = {}
var _fx: WickFx = WickFx.new()

func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_kit()
	_fx.try_load_sprite()

func setup(world_ctx: Node) -> void:
	_world_ctx = world_ctx
	_ensure_kit()
	_fx.try_load_sprite()
	if Lx.debug != null and Lx.debug.god:
		god = true
	Lx.player = self
	_bind_world_ctx(world_ctx)
	if Lx.events != null and not Lx.events.move_unlocked.is_connected(_on_move_unlocked):
		Lx.events.move_unlocked.connect(_on_move_unlocked)
	if Lx.events != null and not Lx.events.lantern_picked_up.is_connected(_on_lantern_picked_up):
		Lx.events.lantern_picked_up.connect(_on_lantern_picked_up)
	sync_unlocks_from_state()
	if Lx.state != null:
		_local_max_hearts = Lx.state.max_hearts
		_local_hearts = Lx.state.hearts
	reset_for_room(global_position)

func _bind_world_ctx(world_ctx: Node) -> void:
	if move_throw != null: move_throw.set_world_ctx(world_ctx)
	if move_beam != null: move_beam.set_world_ctx(world_ctx)
	if move_lens != null: move_lens.set_world_ctx(world_ctx)
	if move_sunflare != null: move_sunflare.set_world_ctx(world_ctx)

func _ensure_kit() -> void:
	if lantern == null or not is_instance_valid(lantern):
		lantern = LxLantern.new()
		lantern.name = "LxLantern"
		add_child(lantern)
		lantern.setup(self)
	if move_bolt == null: move_bolt = LxMoveBolt.new(); register_move(move_bolt, "bolt")
	if move_dash == null: move_dash = LxMoveDash.new(); register_move(move_dash, "dash")
	if move_throw == null: move_throw = LxMoveThrow.new(); register_move(move_throw, "throw")
	if move_prism == null: move_prism = MovePrism.new(); register_move(move_prism, "prism")
	if move_beam == null: move_beam = MoveBeam.new(); register_move(move_beam, "beam")
	if move_wings == null: move_wings = MoveWings.new(); register_move(move_wings, "wings")
	if move_lens == null: move_lens = MoveLens.new(); register_move(move_lens, "lens")
	if move_sunflare == null: move_sunflare = MoveSunflare.new(); register_move(move_sunflare, "sunflare")

func register_move(move: LxMove, move_id: String) -> void:
	if move != null:
		move.setup(self, move_id)
		moves[move_id] = move

func sync_unlocks_from_state() -> void:
	_ensure_kit()
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).sync_unlock()

func has_lantern() -> bool: return Lx.state == null or Lx.state.has_lantern()
func _on_move_unlocked(_move_id: String) -> void: sync_unlocks_from_state()
func _on_lantern_picked_up(_pickup_id: String, _at_pos: Vector2) -> void:
	sync_unlocks_from_state()
	if lantern != null: lantern.reset_to_hand(global_position)
	catch_anim_t = 0.28
	_fx.trigger_lantern_ignite(self)
	queue_redraw()

func reset_for_room(at_pos: Vector2) -> void:
	_ensure_kit()
	global_position = at_pos
	last_pos = at_pos
	_last_safe_pos = at_pos
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
	grabbed_block = null
	grab_axis = Vector2.ZERO
	grab_slide_speed = 0.0
	_interact_held = false
	_interact_hold_t = 0.0
	_interact_cand = null
	bolts.clear()
	_fx.clear()
	_prev_act.clear()
	if Lx.input != null:
		Lx.input.clear_all_toggles()
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).reset()
	if not has_lantern():
		facing = Vector2.LEFT
		if Lx.input != null: Lx.input.last_aim_dir = Vector2.LEFT
	if lantern != null:
		lantern.reset_to_hand(at_pos)
	queue_redraw()

func tick_sim(dt: float, world_ctx: Node) -> void:
	_world_ctx = world_ctx
	_ensure_kit()
	_bind_world_ctx(world_ctx)
	_clock_t += dt
	_fx.age(dt)
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
	_tick_grab_hold(dt, world_ctx)
	for mv_var: Variant in moves.values():
		if mv_var is LxMove:
			(mv_var as LxMove).tick(dt)
	if move_lens != null and has_lantern():
		move_lens.register_circle(world_ctx)

	last_pos = global_position
	if is_grabbing():
		_tick_grab_move(dt, world_ctx)
		_walk_phase = _walk_phase + dt * 10.0 if grab_slide_speed > 8.0 else 0.0
	else:
		grab_slide_speed = 0.0
		var desired_vel: Vector2 = Vector2.ZERO
		var airborne: bool = false
		if is_zipping():
			desired_vel = move_throw.get_zip_velocity()
			airborne = true
		elif is_dashing() or is_gliding():
			desired_vel = move_dash.get_active_velocity()
			airborne = move_dash.can_cross_gaps()
		elif is_beam_charging():
			desired_vel = Vector2.ZERO
		elif bounce_t <= 0.0:
			desired_vel = get_move_input() * MOVE_SPEED * (1.14 if (LxBiomeRules.active_instance != null and is_instance_valid(LxBiomeRules.active_instance) and LxBiomeRules.active_instance.starlight_surge_t > 0.0) else 1.0)

		desired_vel += knock
		knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * dt)
		var next_pos: Vector2 = world_collide_step(world_ctx, global_position, global_position + desired_vel * dt, BODY_RADIUS, airborne)
		velocity = (next_pos - global_position) / maxf(dt, 0.0001)
		global_position = next_pos
		var walking: bool = velocity.length() > 10.0 and not is_dashing() and not is_gliding() and not is_zipping() and not is_beam_charging()
		_walk_phase = _walk_phase + dt * 13.0 if walking else 0.0

	if move_dash != null: move_dash.tick_dash(dt, world_ctx)
	if move_throw != null: move_throw.tick_zip(dt, world_ctx)
	_check_void_fall(world_ctx)
	if dead:
		queue_redraw()
		return
	if lantern != null: lantern.tick_sim(dt, self, world_ctx)
	if move_lens != null and has_lantern(): move_lens.tick_lens(dt, world_ctx)
	if move_bolt != null: move_bolt.tick_bolts(dt, world_ctx)
	queue_redraw()

func _update_manual_aim() -> void:
	if is_grabbing():
		if grab_axis.length_squared() > 0.0001:
			facing = grab_axis
		return
	if not has_lantern():
		var mv: Vector2 = get_move_input()
		if mv.length_squared() > 0.01:
			facing = mv.normalized()
		return
	if Lx.input == null:
		return
	var mw: Vector2 = get_global_mouse_position() if is_inside_tree() else (global_position + facing * 32.0)
	var aim: Vector2 = Lx.input.get_aim_dir(global_position, mw)
	if aim.length_squared() > 0.0001:
		facing = aim.normalized()

func _poll_inputs(world_ctx: Node) -> void:
	if Lx.input == null:
		return
	for act: String in ["lx_fire", "lx_throw", "lx_dash", "lx_beam", "lx_lens", "lx_sunflare", "lx_interact"]:
		var now: bool = Lx.input.is_action_active(act)
		var was: bool = bool(_prev_act.get(act, false))
		_prev_act[act] = now
		if now and not was:
			match act:
				"lx_fire": press_fire()
				"lx_throw": press_throw()
				"lx_dash": press_dash()
				"lx_beam": press_beam()
				"lx_lens": press_lens()
				"lx_sunflare": press_sunflare()
				"lx_interact": _press_interact(world_ctx)
		elif not now and was:
			match act:
				"lx_fire": release_fire()
				"lx_dash": release_dash()
				"lx_beam": release_beam()
				"lx_interact": _release_interact(world_ctx)

func prime_input_edges() -> void:
	## Swallows presses made in a menu. Keys let go there keep their release edge (beam, glide, grab).
	if Lx.input == null: return
	Lx.input.clear_all_toggles()
	release_fire()
	for act: String in ["lx_fire", "lx_throw", "lx_dash", "lx_beam", "lx_lens", "lx_sunflare", "lx_interact"]:
		if Lx.input.is_action_active(act): _prev_act[act] = true

func press_fire() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern():
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
	if dead or is_grabbing() or not has_lantern() or move_throw == null:
		return false
	var ok: bool = move_throw.press()
	if ok and move_beam != null:
		move_beam.cancel()
	return ok

func press_dash() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or move_dash == null:
		return false
	var ok: bool = move_dash.press()
	if ok and move_beam != null:
		move_beam.cancel()
	return ok

func release_dash() -> void:
	if move_dash != null:
		move_dash.release()

func press_beam() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_beam == null:
		return false
	move_beam.set_world_ctx(_world_ctx)
	return move_beam.press_beam()

func release_beam() -> bool:
	if move_beam == null:
		return false
	move_beam.set_world_ctx(_world_ctx)
	return move_beam.release_beam()

func press_sunflare() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_sunflare == null:
		return false
	move_sunflare.set_world_ctx(_world_ctx)
	return move_sunflare.press()

func press_lens() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_lens == null:
		return false
	move_lens.set_world_ctx(_world_ctx)
	return move_lens.press()

func try_zip() -> bool:
	_ensure_kit()
	return false if dead or is_grabbing() or not has_lantern() or move_throw == null else move_throw.try_zip()

func _is_obj_movable(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj) and obj.has_method("is_movable") and bool(obj.call("is_movable"))

func _get_interact_candidates(world_ctx: Node) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for it_var: Variant in world_get_interactables(world_ctx):
		if not (it_var is Object and is_instance_valid(it_var as Object)):
			continue
		var obj: Object = it_var as Object
		if not obj.has_method("interact") and not _is_obj_movable(obj):
			continue
		if obj.get("active") is bool and not bool(obj.get("active")):
			continue
		if obj.get("opened") is bool and bool(obj.get("opened")):
			continue
		if obj.get("collected") is bool and bool(obj.get("collected")):
			continue
		if obj.get("shattered") is bool and bool(obj.get("shattered")):
			continue
		var irad_v: Variant = obj.get("radius")
		var reach: float = maxf(INTERACT_RADIUS, (float(irad_v) if (irad_v is float or irad_v is int) else 0.0) + 6.0)
		var d: float = get_entity_pos(obj).distance_to(global_position)
		if d <= reach:
			var has_prompt: bool = obj.has_method("get_interact_prompt") and not str(obj.call("get_interact_prompt")).is_empty()
			candidates.append({"obj": obj, "d": d, "prompted": has_prompt})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap: bool = bool(a.get("prompted", false))
		var bp: bool = bool(b.get("prompted", false))
		if ap != bp:
			return ap
		return float(a.get("d", INF)) < float(b.get("d", INF))
	)
	return candidates

func _call_interact_on(cand_obj: Object, world_ctx: Node) -> bool:
	if cand_obj == null or not is_instance_valid(cand_obj) or not cand_obj.has_method("interact"):
		return false
	var arity: int = get_method_arity(cand_obj, "interact")
	var res: Variant = cand_obj.call("interact", self) if arity >= 1 else cand_obj.call("interact")
	if res is bool and bool(res):
		if world_ctx != null and world_ctx.has_method("save_interactables_to_state"):
			world_ctx.call("save_interactables_to_state")
		return true
	return false

func _press_interact(world_ctx: Node) -> void:
	if dead:
		return
	var cands: Array[Dictionary] = _get_interact_candidates(world_ctx)
	if cands.is_empty():
		return
	var top: Object = cands[0].get("obj") as Object
	if _is_obj_movable(top):
		_interact_held = true
		_interact_hold_t = 0.0
		_interact_cand = top
		return
	try_interact(world_ctx)

func _release_interact(world_ctx: Node) -> void:
	if is_grabbing():
		release_grab(world_ctx)
		_interact_held = false
		_interact_hold_t = 0.0
		_interact_cand = null
		return
	if _interact_held and _interact_cand != null and is_instance_valid(_interact_cand):
		_call_interact_on(_interact_cand, world_ctx)
	_interact_held = false
	_interact_hold_t = 0.0
	_interact_cand = null

func _tick_grab_hold(dt: float, world_ctx: Node) -> void:
	if not _interact_held or is_grabbing():
		return
	if _interact_cand == null or not is_instance_valid(_interact_cand) or not _is_obj_movable(_interact_cand):
		_interact_held = false
		_interact_cand = null
		return
	var irad_v: Variant = _interact_cand.get("radius")
	var reach: float = maxf(INTERACT_RADIUS, (float(irad_v) if (irad_v is float or irad_v is int) else 0.0) + 8.0)
	if get_entity_pos(_interact_cand).distance_to(global_position) > reach:
		_interact_held = false
		_interact_cand = null
		return
	_interact_hold_t += dt
	if _interact_hold_t >= GRAB_HOLD_DELAY or get_move_input().length() > 0.25:
		begin_grab(_interact_cand, world_ctx)

func begin_grab(block: Object, world_ctx: Node = null) -> bool:
	if dead or not _is_obj_movable(block):
		return false
	if is_dashing() or is_gliding() or is_zipping() or is_beam_charging():
		return false
	var bpos: Vector2 = get_entity_pos(block)
	var rel: Vector2 = bpos - global_position
	if rel.length_squared() <= 0.0001:
		rel = facing if facing.length_squared() > 0.0001 else Vector2.RIGHT
	if absf(rel.x) >= absf(rel.y):
		grab_axis = Vector2(1.0 if rel.x >= 0.0 else -1.0, 0.0)
	else:
		grab_axis = Vector2(0.0, 1.0 if rel.y >= 0.0 else -1.0)
	grabbed_block = block
	facing = grab_axis
	grab_slide_speed = 0.0
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	# Gently align Wick onto the cardinal face center if unobstructed
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	var half_b: float = 8.0
	if block.has_method("get_solid_rect"):
		var srect: Rect2 = block.call("get_solid_rect") as Rect2
		if srect.has_area():
			half_b = (srect.size.x * 0.5) if absf(grab_axis.x) > 0.5 else (srect.size.y * 0.5)
	var ideal_pos: Vector2 = bpos - grab_axis * (half_b + BODY_RADIUS + 1.5)
	var bid: String = str(block.get("id")) if block.get("id") != null else ""
	if ctx != null and ctx.has_method("collide_ignoring"):
		var checked: Vector2 = ctx.call("collide_ignoring", ideal_pos, BODY_RADIUS, bid, false, false) as Vector2
		if checked.distance_to(ideal_pos) < 1.5:
			global_position = checked
	emit_sfx("mirror_turn", bpos, true)
	return true

func release_grab(world_ctx: Node = null) -> void:
	if not is_grabbing():
		grabbed_block = null
		grab_axis = Vector2.ZERO
		grab_slide_speed = 0.0
		return
	var blk: Object = grabbed_block
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	if blk != null and is_instance_valid(blk) and blk.has_method("move_to"):
		var bpos: Vector2 = get_entity_pos(blk)
		var snapped := Vector2(roundf(bpos.x / 8.0) * 8.0, roundf(bpos.y / 8.0) * 8.0)
		if snapped.distance_to(bpos) <= 3.2 and snapped.distance_to(bpos) > 0.01:
			var bid: String = str(blk.get("id")) if blk.get("id") != null else ""
			var can_snap: bool = true
			if ctx != null and ctx.has_method("can_place_rect") and blk.has_method("get_push_rect_at"):
				var prect: Rect2 = blk.call("get_push_rect_at", snapped) as Rect2
				can_snap = bool(ctx.call("can_place_rect", prect, bid))
			if can_snap:
				blk.call("move_to", snapped)
				if ctx != null and ctx.has_method("collide"):
					global_position = ctx.call("collide", global_position, BODY_RADIUS, false, false) as Vector2
		if ctx != null and ctx.has_method("save_interactables_to_state"):
			ctx.call("save_interactables_to_state")
	grabbed_block = null
	grab_axis = Vector2.ZERO
	grab_slide_speed = 0.0

func _tick_grab_move(dt: float, world_ctx: Node) -> void:
	if not is_grabbing() or not _is_obj_movable(grabbed_block):
		release_grab(world_ctx)
		return
	var blk: Object = grabbed_block
	var move_in: Vector2 = get_move_input()
	var proj: float = move_in.dot(grab_axis)
	if absf(proj) <= 0.15:
		velocity = Vector2.ZERO
		grab_slide_speed = 0.0
		return
	var step: Vector2 = grab_axis * (signf(proj) * GRAB_SLIDE_SPEED * dt)
	var bpos: Vector2 = get_entity_pos(blk)
	var bnext: Vector2 = bpos + step
	var wnext: Vector2 = global_position + step
	var bid: String = str(blk.get("id")) if blk.get("id") != null else ""
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	var block_ok: bool = true
	if ctx != null and ctx.has_method("can_place_rect") and blk.has_method("get_push_rect_at"):
		var prect: Rect2 = blk.call("get_push_rect_at", bnext) as Rect2
		block_ok = bool(ctx.call("can_place_rect", prect, bid))
	var wick_ok: bool = true
	if ctx != null and ctx.has_method("collide_ignoring"):
		var wchk: Vector2 = ctx.call("collide_ignoring", wnext, BODY_RADIUS, bid, false, false) as Vector2
		if wchk.distance_to(wnext) > 0.35:
			wick_ok = false
	if block_ok and wick_ok:
		if blk.has_method("move_to"):
			blk.call("move_to", bnext)
		global_position = wnext
		velocity = step / maxf(dt, 0.0001)
		grab_slide_speed = velocity.length()
	else:
		velocity = Vector2.ZERO
		grab_slide_speed = 0.0

func try_interact(world_ctx: Node) -> bool:
	var candidates: Array[Dictionary] = _get_interact_candidates(world_ctx)
	for cand: Dictionary in candidates:
		var cand_obj: Object = cand.get("obj") as Object
		if _call_interact_on(cand_obj, world_ctx):
			return true
	return false

func take_damage(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String = "hazard") -> void:
	if dead:
		return
	if move_dash != null and move_dash.has_iframes():
		move_dash.on_perfect_dodge()
		return
	if is_gliding() and source == "shockwave" and (move_wings == null or move_wings.clears_shockwave()):
		if move_wings != null: move_wings.on_shockwave_cleared()
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
	if is_grabbing():
		release_grab(_world_ctx)
	_interact_held = false
	_interact_cand = null
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
		if move_dash != null: move_dash.cancel()
		if move_wings != null: move_wings.stop_glide()
		if move_beam != null: move_beam.cancel()
		if move_throw != null: move_throw.cancel_zip()
		if Lx.state != null: Lx.state.deaths += 1
		if Lx.events != null: Lx.events.player_died.emit()

func _check_void_fall(world_ctx: Node) -> void:
	if dead or is_dashing() or is_gliding() or is_zipping():
		return
	var ctx: Node = world_ctx if world_ctx != null else _world_ctx
	if ctx == null:
		return
	var lethal: bool = false
	if ctx.has_method("is_lethal_void_at"):
		lethal = bool(ctx.call("is_lethal_void_at", global_position))
	elif ctx.has_method("tile_at"):
		var ttype: String = str(ctx.call("tile_at", global_position))
		lethal = ttype in ["pit", "void"]
	if not lethal:
		_last_safe_pos = global_position
		return
	kill_by_void(global_position)

func kill_by_void(at_pos: Vector2) -> void:
	if dead:
		return
	var assist_zero: bool = (Lx.save != null and float(Lx.save.settings.get("assist_damage_mult", 1.0)) <= 0.001) \
			or (Lx.state != null and Lx.state.get("assist_damage_mult") != null and float(Lx.state.get("assist_damage_mult")) <= 0.001)
	if god or assist_zero:
		if _last_safe_pos != Vector2.ZERO:
			global_position = _last_safe_pos
			last_pos = _last_safe_pos
		velocity = Vector2.ZERO
		knock = Vector2.ZERO
		return
	if is_grabbing():
		release_grab(_world_ctx)
	_interact_held = false
	_interact_cand = null
	var lost_hp: float = maxf(1.0, get_hearts())
	if Lx.state != null:
		Lx.state.hearts = 0.0
		Lx.state.hits_taken += 1
		Lx.state.deaths += 1
		_local_hearts = 0.0
	else:
		_local_hearts = 0.0
	dead = true
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	hurt_flash = 1.0
	if move_dash != null: move_dash.cancel()
	if move_wings != null: move_wings.stop_glide()
	if move_beam != null: move_beam.cancel()
	if move_throw != null: move_throw.cancel_zip()
	trigger_hitstop(HS_HURT)
	trigger_shake(SHAKE_HURT)
	spawn_ring(at_pos, 10.0, 2.0, 0.28, PAL_DUSK, 2.0)
	spawn_ring(at_pos, 2.0, 14.0, 0.24, PAL_CORAL, 1.2)
	spawn_sparks(at_pos, Vector2.UP, 10, PAL_CORAL, 20.0, 75.0, 0.28)
	emit_sfx("wick_hurt", at_pos, false)
	if Lx.events != null:
		Lx.events.player_damaged.emit(lost_hp, at_pos, Vector2.ZERO, "void")
		Lx.events.player_died.emit()

func get_hearts() -> float:
	return Lx.state.hearts if Lx.state != null else _local_hearts

func get_max_hearts() -> int:
	return Lx.state.max_hearts if Lx.state != null else _local_max_hearts

func get_ember() -> float:
	return ember

func get_ember_ratio() -> float:
	var emax: float = move_sunflare.get_ember_max() if move_sunflare != null else 100.0
	return clampf(ember / maxf(emax, 1.0), 0.0, 1.0)

func is_invulnerable() -> bool:
	return god or mercy_t > 0.0 or is_zipping() or (move_dash != null and move_dash.has_iframes())

func is_dashing() -> bool:
	return move_dash != null and move_dash.active

func is_gliding() -> bool:
	return (move_wings != null and move_wings.gliding) or (move_dash != null and move_dash.is_gliding)

func is_zipping() -> bool:
	return move_throw != null and move_throw.zipping

func is_beam_charging() -> bool:
	return move_beam != null and move_beam.is_charging()

func is_grabbing() -> bool:
	return grabbed_block != null and is_instance_valid(grabbed_block)

func beam_charge_progress() -> float:
	return move_beam.charge_progress() if move_beam != null else 0.0

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
	if hit.source != LxHit.SOURCE_SUNFLARE:
		var sd: Dictionary = Lx.get_move_data("sunflare")
		var gain: float = float(sd.get("ember_per_kill", 20.0)) if result == LxEnemyBrain.HitResult.KILLED else (
			float(sd.get("ember_per_heavy", 18.0)) if heavy else float(sd.get("ember_per_bolt", 6.0))
		)
		var emax: float = move_sunflare.get_ember_max() if move_sunflare != null else (
			Lx.state.get_effective_ember_max() if Lx.state != null else float(sd.get("ember_max", 100.0))
		)
		var was_full: bool = ember >= emax - 0.001
		ember = minf(emax, ember + gain)
		if not was_full and ember >= emax - 0.001 and move_sunflare != null and move_sunflare.unlocked:
			spawn_ring(global_position, 3.0, 18.0, 0.28, PAL_GOLD, 1.5)
			emit_sfx("beam_ready", global_position, false)

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
		return _fx.collide_with_corner_slide(ctx, from_p, to_p, rad, cross_pit, cross_water)
	if ctx.has_method("resolve_move"):
		return ctx.call("resolve_move", from_p, to_p, rad, airborne) as Vector2
	if ctx.has_method("collide_step"):
		return (ctx.call("collide_step", from_p, to_p, rad, airborne) if get_method_arity(ctx, "collide_step") >= 4 else ctx.call("collide_step", from_p, to_p, rad)) as Vector2
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

func get_method_arity(obj: Object, method_name: String) -> int:
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
	_fx.spawn_afterimage(global_position, col, facing, "zip" if is_zipping() else "dash")

func spawn_ring(at_pos: Vector2, r0: float, r1: float, life: float, col: Color, width: float = 1.0) -> void:
	_fx.spawn_ring(at_pos, r0, r1, life, col, width)

func spawn_sparks(at_pos: Vector2, base_dir: Vector2, count: int, col: Color, min_spd: float, max_spd: float, life: float) -> void:
	_fx.spawn_sparks(at_pos, base_dir, count, col, min_spd, max_spd, life)

func _draw() -> void:
	_fx.draw(self, _walk_phase, _clock_t)
