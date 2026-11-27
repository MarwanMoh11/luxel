class_name LxWick
extends Node2D
## Wick: player controller (92 px/s movement, 100% manual aim, 8-move modular kit, hearts/mercy/Assist).
## Helpers: wick_fx.gd, wick_fx_extra.gd, wick_grab.gd, wick_combat.gd, wick_world.gd.

signal fired(dir: Vector2, kind: String)

const MovePrism := preload("res://luxel/player/kit/prism.gd")
const MoveBeam := preload("res://luxel/player/kit/beam.gd")
const MoveWings := preload("res://luxel/player/kit/wings.gd")
const MoveLens := preload("res://luxel/player/kit/lens.gd")
const MoveSunflare := preload("res://luxel/player/kit/sunflare.gd")
const WickFx := preload("res://luxel/player/wick_fx.gd")
const WickWorld := preload("res://luxel/player/wick_world.gd")
const WickGrab := preload("res://luxel/player/wick_grab.gd")
const WickCombat := preload("res://luxel/player/wick_combat.gd")
const FIREFLY_SCRIPT_PATH: String = "res://luxel/companion/firefly_companion.gd"

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
var temper: String = "" # "", "scatter", "lance", "skip"
var light_scale: float = 1.0
var _local_hearts: float = 4.0
var _local_max_hearts: int = 4

var lantern: LxLantern = null
var firefly: Node2D = null
var move_bolt: LxMoveBolt = null
var move_dash: LxMoveDash = null
var move_throw: LxMoveThrow = null
var move_zip: LxMoveThrow = null
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
var carried_item: Node = null
var mounted_vehicle: Node = null
var _interact_held: bool = false
var _interact_hold_t: float = 0.0
var _interact_cand: Object = null
var _last_safe_pos: Vector2 = Vector2.ZERO

var _external_vel: Vector2 = Vector2.ZERO
var _external_source: String = ""
var _field_vel: Vector2 = Vector2.ZERO
var _launch_vel: Vector2 = Vector2.ZERO
var _launch_t: float = 0.0
var _void_retry_t: float = 0.0
var _void_resume_hearts: float = 0.0
var _locked_moves: Dictionary = {}

var _world_ctx: Node = null
var _bound_events: Object = null
var _prev_act: Dictionary = {}
var _walk_phase: float = 0.0
var _clock_t: float = 0.0
var _fx: WickFx = WickFx.new()
var _world_q: WickWorld = WickWorld.new()


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
	_bind_event_signals()
	sync_unlocks_from_state()
	if Lx.state != null:
		_local_max_hearts = Lx.state.max_hearts
		_local_hearts = Lx.state.hearts
	reset_for_room(global_position)


func _exit_tree() -> void:
	_unbind_event_signals()
	if Lx.player == self:
		Lx.player = null


func _bind_event_signals() -> void:
	if _bound_events == Lx.events:
		if is_instance_valid(_bound_events):
			if not _bound_events.move_unlocked.is_connected(_on_move_unlocked):
				_bound_events.move_unlocked.connect(_on_move_unlocked)
			if not _bound_events.lantern_picked_up.is_connected(_on_lantern_picked_up):
				_bound_events.lantern_picked_up.connect(_on_lantern_picked_up)
		return
	_unbind_event_signals()
	_bound_events = Lx.events
	if is_instance_valid(_bound_events):
		if not _bound_events.move_unlocked.is_connected(_on_move_unlocked):
			_bound_events.move_unlocked.connect(_on_move_unlocked)
		if not _bound_events.lantern_picked_up.is_connected(_on_lantern_picked_up):
			_bound_events.lantern_picked_up.connect(_on_lantern_picked_up)


func _unbind_event_signals() -> void:
	if is_instance_valid(_bound_events):
		if _bound_events.move_unlocked.is_connected(_on_move_unlocked):
			_bound_events.move_unlocked.disconnect(_on_move_unlocked)
		if _bound_events.lantern_picked_up.is_connected(_on_lantern_picked_up):
			_bound_events.lantern_picked_up.disconnect(_on_lantern_picked_up)
	_bound_events = null


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
	if (firefly == null or not is_instance_valid(firefly)) and ResourceLoader.exists(FIREFLY_SCRIPT_PATH):
		var fsc: Variant = ResourceLoader.load(FIREFLY_SCRIPT_PATH)
		if fsc is GDScript:
			var finst: Variant = (fsc as GDScript).new()
			if finst is Node2D:
				firefly = finst as Node2D
				firefly.name = "LxFireflyCompanion"
				add_child(firefly)
				if firefly.has_method("setup"): firefly.call("setup", self)
	if move_bolt == null: move_bolt = LxMoveBolt.new(); register_move(move_bolt, "bolt")
	if move_dash == null: move_dash = LxMoveDash.new(); register_move(move_dash, "dash")
	if move_throw == null: move_throw = LxMoveThrow.new(); register_move(move_throw, "throw")
	move_zip = move_throw
	if move_prism == null: move_prism = MovePrism.new(); register_move(move_prism, "prism")
	if move_beam == null: move_beam = MoveBeam.new(); register_move(move_beam, "beam")
	if move_wings == null: move_wings = MoveWings.new(); register_move(move_wings, "wings")
	if move_lens == null: move_lens = MoveLens.new(); register_move(move_lens, "lens")
	if move_sunflare == null: move_sunflare = MoveSunflare.new(); register_move(move_sunflare, "sunflare")


func register_move(move: LxMove, move_id: String) -> void:
	if move != null:
		move.setup(self, move_id)
		move.locked = bool(_locked_moves.get(move_id, false))
		moves[move_id] = move


func sync_unlocks_from_state() -> void:
	_ensure_kit()
	for mid_v: Variant in moves.keys():
		var mid: String = str(mid_v)
		var mv: LxMove = moves[mid] as LxMove
		if mv != null:
			mv.sync_unlock()
			mv.locked = bool(_locked_moves.get(mid, false))


func has_lantern() -> bool: return Lx.state == null or Lx.state.has_lantern()
func _on_move_unlocked(_move_id: String) -> void: sync_unlocks_from_state()
func _on_lantern_picked_up(_pickup_id: String, pickup_pos: Vector2) -> void:
	sync_unlocks_from_state()
	if lantern != null: lantern.reset_to_hand(global_position)
	if firefly != null and is_instance_valid(firefly) and firefly.has_method("on_lantern_picked_up"):
		firefly.call("on_lantern_picked_up", pickup_pos)
	catch_anim_t = 0.28
	_fx.trigger_lantern_ignite(self)
	queue_redraw()


func reset_for_room(at_pos: Vector2) -> void:
	_ensure_kit()
	if is_mounted(): dismount(at_pos)
	if is_carrying(): drop_carried()
	global_position = at_pos; last_pos = at_pos
	_last_safe_pos = at_pos if WickCombat.is_safe_ground(_world_ctx, at_pos) else Vector2.ZERO
	velocity = Vector2.ZERO; knock = Vector2.ZERO
	_external_vel = Vector2.ZERO; _external_source = ""; _field_vel = Vector2.ZERO
	_launch_vel = Vector2.ZERO; _launch_t = 0.0; _void_retry_t = 0.0; _void_resume_hearts = 0.0
	mercy_t = 0.0; hurt_flash = 0.0; bounce_t = 0.0; muzzle_t = 0.0
	shoot_anim_t = 0.0; throw_anim_t = 0.0; catch_anim_t = 0.0; recoil_vis = 0.0
	dead = false
	grabbed_block = null; grab_axis = Vector2.ZERO; grab_slide_speed = 0.0
	_interact_held = false; _interact_hold_t = 0.0; _interact_cand = null
	bolts.clear(); _fx.clear(); _world_q.clear(); _prev_act.clear()
	if Lx.input != null: Lx.input.clear_all_toggles()
	for mv_var: Variant in moves.values():
		if mv_var is LxMove: (mv_var as LxMove).reset()
	if not has_lantern():
		facing = Vector2.LEFT
		if Lx.input != null: Lx.input.last_aim_dir = Vector2.LEFT
	if lantern != null: lantern.reset_to_hand(at_pos)
	if firefly != null and is_instance_valid(firefly) and firefly.has_method("reset_for_room"):
		firefly.call("reset_for_room", at_pos)
	queue_redraw()


func tick_sim(dt: float, world_ctx: Node) -> void:
	_world_ctx = world_ctx
	_ensure_kit()
	_bind_world_ctx(world_ctx)
	_clock_t += dt
	_fx.age(dt)
	if dead:
		_external_vel = Vector2.ZERO
		WickCombat.tick_void_retry(self, dt, world_ctx)
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
	WickGrab.tick_grab_hold(self, dt, world_ctx)
	for mv_var: Variant in moves.values():
		if mv_var is LxMove: (mv_var as LxMove).tick(dt)
	if move_lens != null and has_lantern(): move_lens.register_circle(world_ctx)

	last_pos = global_position
	var ext_v: Vector2 = _external_vel
	_external_vel = Vector2.ZERO
	_external_source = ""

	if is_mounted():
		if mounted_vehicle.has_method("tick_mounted"):
			mounted_vehicle.call("tick_mounted", dt, self, world_ctx)
		_walk_phase = 0.0
	elif is_grabbing():
		WickGrab.tick_grab_move(self, dt, world_ctx)
		_walk_phase = _walk_phase + dt * 10.0 if grab_slide_speed > 8.0 else 0.0
	else:
		grab_slide_speed = 0.0
		var desired_vel: Vector2 = Vector2.ZERO
		var airborne: bool = false
		if is_zipping():
			desired_vel = move_throw.get_zip_velocity(); airborne = true
		elif _launch_t > 0.0:
			_launch_t = maxf(0.0, _launch_t - dt)
			desired_vel = _launch_vel + get_move_input() * 24.0
			airborne = true
			if _launch_t <= 0.0: _launch_vel = Vector2.ZERO
		elif is_dashing() or is_gliding():
			desired_vel = move_dash.get_active_velocity()
			airborne = move_dash.can_cross_gaps()
		elif is_beam_charging():
			desired_vel = Vector2.ZERO
		elif bounce_t <= 0.0:
			var surge_m: float = 1.14 if (LxBiomeRules.active_instance != null and is_instance_valid(LxBiomeRules.active_instance) and LxBiomeRules.active_instance.starlight_surge_t > 0.0) else 1.0
			var pip_m: float = LxFireflyState.get_sanctuary_speed_mult() if (firefly != null and is_instance_valid(firefly) and firefly.get("sanctuary_buff_active") == true) else 1.0
			var move_spd: float = MOVE_SPEED * surge_m * pip_m
			var panes_m: LxPanes = LxPanes.current()
			if panes_m != null and not panes_m.equipped_ids().is_empty():
				move_spd = panes_m.modify_stat("move_speed", move_spd, {"wick": self})
			desired_vel = get_move_input() * move_spd

		if LxFields.has_fields() and not is_zipping():
			var fa: Vector2 = LxFields.accel_at(global_position, "wick")
			_field_vel = (_field_vel + fa * dt).limit_length(180.0) if fa.length_squared() > 0.01 else _field_vel.move_toward(Vector2.ZERO, 420.0 * dt)
		elif _field_vel.length_squared() > 0.01:
			_field_vel = _field_vel.move_toward(Vector2.ZERO, 420.0 * dt)

		desired_vel += knock + ext_v + _field_vel
		knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * dt)
		var next_pos: Vector2 = world_collide_step(world_ctx, global_position, global_position + desired_vel * dt, BODY_RADIUS, airborne)
		velocity = (next_pos - global_position) / maxf(dt, 0.0001)
		global_position = next_pos
		var walking: bool = velocity.length() > 10.0 and not is_dashing() and not is_gliding() and not is_zipping() and not is_beam_charging() and not is_launched()
		_walk_phase = _walk_phase + dt * 13.0 if walking else 0.0

	WickGrab.tick_carried(self)
	if move_dash != null: move_dash.tick_dash(dt, world_ctx)
	if move_throw != null: move_throw.tick_zip(dt, world_ctx)
	WickCombat.check_void_fall(self, world_ctx)
	if dead:
		queue_redraw()
		return
	if lantern != null: lantern.tick_sim(dt, self, world_ctx)
	if firefly != null and is_instance_valid(firefly) and firefly.has_method("tick_sim"):
		firefly.call("tick_sim", dt, self, world_ctx)
	if move_lens != null and has_lantern(): move_lens.tick_lens(dt, world_ctx)
	if move_bolt != null: move_bolt.tick_bolts(dt, world_ctx)
	queue_redraw()


func _update_manual_aim() -> void:
	if is_grabbing():
		if grab_axis.length_squared() > 0.0001: facing = grab_axis
		return
	if not has_lantern():
		var mv: Vector2 = get_move_input()
		if mv.length_squared() > 0.01: facing = mv.normalized()
		return
	if Lx.input == null: return
	var mw: Vector2 = get_global_mouse_position() if is_inside_tree() else (global_position + facing * 32.0)
	var aim: Vector2 = Lx.input.get_aim_dir(global_position, mw)
	if aim.length_squared() > 0.0001: facing = aim.normalized()


func _poll_inputs(world_ctx: Node) -> void:
	if Lx.input == null: return
	for act: String in ["lx_fire", "lx_throw", "lx_dash", "lx_beam", "lx_lens", "lx_sunflare", "lx_firefly", "lx_interact"]:
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
				"lx_firefly":
					if not dead and not is_grabbing() and firefly != null and is_instance_valid(firefly) and firefly.has_method("on_input_down"):
						firefly.call("on_input_down", world_ctx)
				"lx_interact": WickGrab.press_interact(self, world_ctx)
		elif not now and was:
			match act:
				"lx_fire": release_fire()
				"lx_dash": release_dash()
				"lx_beam": release_beam()
				"lx_firefly":
					if firefly != null and is_instance_valid(firefly) and firefly.has_method("on_input_up"):
						firefly.call("on_input_up", world_ctx)
				"lx_interact": WickGrab.release_interact(self, world_ctx)


func prime_input_edges() -> void:
	if Lx.input == null: return
	Lx.input.clear_all_toggles()
	release_fire()
	for act: String in ["lx_fire", "lx_throw", "lx_dash", "lx_beam", "lx_lens", "lx_sunflare", "lx_firefly", "lx_interact"]:
		if Lx.input.is_action_active(act): _prev_act[act] = true


# ---- E0-2 Physics, Carry, Mount & Lock Hooks ----

func push_external(v: Vector2, source: String = "") -> void:
	if v.is_finite():
		_external_vel += v
		_external_source = source

func launch(dir: Vector2, speed: float, secs: float) -> void:
	if dead or dir.length_squared() <= 0.0001 or speed <= 0.0 or secs <= 0.0: return
	if is_grabbing(): release_grab(_world_ctx)
	if is_mounted(): dismount(global_position)
	_launch_vel = dir.normalized() * speed
	_launch_t = secs
	bounce_t = 0.0
	spawn_ring(global_position, 2.0, 12.0, 0.18, PAL_ICE, 1.2)

func is_launched() -> bool: return _launch_t > 0.0
func carry(item: Node) -> bool: return WickGrab.carry_item(self, item)
func drop_carried() -> Node: return WickGrab.drop_carried(self, facing, 0.0)
func throw_carried(dir: Vector2 = Vector2.ZERO, speed: float = 190.0) -> bool:
	if not is_carrying(): return false
	WickGrab.drop_carried(self, dir.normalized() if dir.length_squared() > 0.01 else facing, speed)
	return true
func get_carried() -> Node: return carried_item if (carried_item != null and is_instance_valid(carried_item)) else null
func is_carrying() -> bool: return carried_item != null and is_instance_valid(carried_item)
func mount(vehicle: Node) -> bool: return WickGrab.mount_vehicle(self, vehicle)
func dismount(exit_pos: Vector2 = Vector2.INF) -> bool: return WickGrab.dismount_vehicle(self, exit_pos)
func is_mounted() -> bool: return mounted_vehicle != null and is_instance_valid(mounted_vehicle)
func get_mounted_vehicle() -> Node: return mounted_vehicle if is_mounted() else null

func set_move_locked(move_id: String, is_locked: bool) -> void:
	_ensure_kit()
	_locked_moves[move_id] = is_locked
	if moves.has(move_id) and moves[move_id] is LxMove:
		(moves[move_id] as LxMove).locked = is_locked
	if is_locked:
		if move_id == "beam" and move_beam != null: move_beam.cancel()
		elif move_id == "dash" and move_dash != null: move_dash.cancel()
		elif move_id == "wings" and move_wings != null: move_wings.stop_glide(false)
		elif move_id == "throw" and move_throw != null: move_throw.cancel_zip()
		elif move_id == "bolt" and move_bolt != null: move_bolt.release()
		elif move_id == "lens" and move_lens != null:
			move_lens.pulse_left = 0.0; move_lens.anchor_active = false
			move_lens.last_radius = 0.0; move_lens.anchor_radius = 0.0

func is_move_locked(move_id: String) -> bool: return bool(_locked_moves.get(move_id, false))
func get_locked_moves() -> Dictionary: return _locked_moves.duplicate()
func set_light_scale(f: float) -> void: light_scale = clampf(f, 0.1, 4.0); queue_redraw()
func get_light_scale() -> float: return light_scale


# ---- Kit Actions ----

func press_fire() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern(): return false
	if is_carrying(): return throw_carried(facing)
	if lantern != null and lantern.is_lure_active(): return try_zip()
	if lantern != null and lantern.state == LxLantern.State.CARRIED:
		emit_sfx("denied", global_position, false)
		return false
	return move_bolt.press() if move_bolt != null else false

func release_fire() -> void:
	if move_bolt != null: move_bolt.release()

func press_throw() -> bool:
	_ensure_kit()
	if dead or is_grabbing(): return false
	if is_carrying(): return throw_carried(facing)
	if not has_lantern() or move_throw == null: return false
	var ok: bool = move_throw.press()
	if ok and move_beam != null: move_beam.cancel()
	return ok

func press_dash() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or move_dash == null: return false
	if is_mounted() and mounted_vehicle.has_method("on_wick_dash") and bool(mounted_vehicle.call("on_wick_dash", self)):
		return true
	if is_carrying(): drop_carried()
	var ok: bool = move_dash.press()
	if ok and move_beam != null: move_beam.cancel()
	return ok

func release_dash() -> void:
	if move_dash != null: move_dash.release()

func press_beam() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or is_carrying() or not has_lantern() or move_beam == null: return false
	move_beam.set_world_ctx(_world_ctx)
	return move_beam.press_beam()

func release_beam() -> bool:
	if move_beam == null: return false
	move_beam.set_world_ctx(_world_ctx)
	return move_beam.release_beam()

func press_sunflare() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_sunflare == null: return false
	move_sunflare.set_world_ctx(_world_ctx)
	return move_sunflare.press()

func press_lens() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_lens == null: return false
	move_lens.set_world_ctx(_world_ctx)
	return move_lens.press()

func press_firefly() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or firefly == null or not is_instance_valid(firefly): return false
	return bool(firefly.call("press_command", _world_ctx)) if firefly.has_method("press_command") else false

func trigger_firefly_wayfinder() -> bool:
	return (not dead) and firefly != null and is_instance_valid(firefly) and firefly.has_method("trigger_wayfinder") and bool(firefly.call("trigger_wayfinder", _world_ctx, true))

func trigger_firefly_special() -> bool:
	return (not dead) and firefly != null and is_instance_valid(firefly) and firefly.has_method("trigger_special") and bool(firefly.call("trigger_special", _world_ctx))

func try_zip() -> bool:
	_ensure_kit()
	if dead or is_grabbing() or not has_lantern() or move_throw == null: return false
	if is_mounted() and mounted_vehicle.has_method("on_wick_zip") and bool(mounted_vehicle.call("on_wick_zip", self)):
		return true
	return move_throw.try_zip()

func begin_grab(block: Object, world_ctx: Node = null) -> bool: return WickGrab.begin_grab(self, block, world_ctx)
func release_grab(world_ctx: Node = null) -> void: WickGrab.release_grab(self, world_ctx)
func try_interact(world_ctx: Node) -> bool: return WickGrab.try_interact(self, world_ctx)


# ---- Combat, State & Delegated World/FX API ----

func take_damage(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String = "hazard") -> void:
	WickCombat.take_damage(self, amount, from_pos, knock_dir, source)
func on_lantern_lost(at_pos: Vector2, reason: String) -> void:
	WickCombat.on_lantern_lost(self, at_pos, reason)
func kill_by_void(at_pos: Vector2) -> void:
	WickCombat.kill_by_void(self, at_pos)
func on_hit_landed(hit: LxHit, result: int, target_pos: Vector2, hitstop_s: float, shake_i: float) -> void:
	WickCombat.on_hit_landed(self, hit, result, target_pos, hitstop_s, shake_i)

func get_hearts() -> float: return Lx.state.hearts if Lx.state != null else _local_hearts
func get_max_hearts() -> int: return Lx.state.max_hearts if Lx.state != null else _local_max_hearts
func get_ember() -> float: return ember
func get_ember_ratio() -> float:
	var emax: float = move_sunflare.get_ember_max() if move_sunflare != null else 100.0
	return clampf(ember / maxf(emax, 1.0), 0.0, 1.0)
func is_invulnerable() -> bool: return god or mercy_t > 0.0 or is_zipping() or (move_dash != null and move_dash.has_iframes())
func is_dashing() -> bool: return move_dash != null and move_dash.active
func is_gliding() -> bool: return (move_wings != null and move_wings.gliding) or (move_dash != null and move_dash.is_gliding)
func is_zipping() -> bool: return move_throw != null and move_throw.zipping
func is_beam_charging() -> bool: return move_beam != null and move_beam.is_charging()
func is_grabbing() -> bool: return grabbed_block != null and is_instance_valid(grabbed_block)
func beam_charge_progress() -> float: return move_beam.charge_progress() if move_beam != null else 0.0
func get_move_input() -> Vector2: return Lx.input.get_move_vector() if Lx.input != null else Vector2.ZERO
func apply_recoil(impulse: Vector2) -> void:
	if not is_mounted(): knock += impulse

func trigger_hitstop(duration: float) -> void:
	if duration > 0.0:
		if Lx.hitstop != null: Lx.hitstop.trigger(duration)
		if Lx.events != null: Lx.events.hitstop_requested.emit(duration)
func trigger_shake(intensity: float) -> void:
	if intensity > 0.0:
		if Lx.camera != null: Lx.camera.add_shake(intensity)
		if Lx.events != null: Lx.events.shake_requested.emit(intensity)
func emit_sfx(sfx_id: String, at_pos: Vector2, spatial: bool) -> void:
	if Lx.events != null: Lx.events.sfx_requested.emit(sfx_id, at_pos, spatial)
	elif Lx.audio != null: Lx.audio.play_sfx(sfx_id, at_pos, spatial)

func world_collide_step(world_ctx: Node, from_p: Vector2, to_p: Vector2, rad: float, airborne: bool) -> Vector2:
	return _world_q.collide_step(self, world_ctx, from_p, to_p, rad, airborne)
func world_shot_blocked(world_ctx: Node, from_p: Vector2, to_p: Vector2 = Vector2.INF) -> bool:
	return _world_q.shot_blocked(self, world_ctx, from_p, to_p)
func world_lantern_blocked(world_ctx: Node, from_p: Vector2, to_p: Vector2) -> bool:
	return _world_q.lantern_blocked(self, world_ctx, from_p, to_p)
func world_zip_blocked(world_ctx: Node, from_p: Vector2, to_p: Vector2) -> bool:
	return _world_q.zip_blocked(self, world_ctx, from_p, to_p)
func world_has_clear_view(world_ctx: Node, from_p: Vector2, to_p: Vector2, pad: float = 0.0) -> bool:
	return _world_q.has_clear_view(self, world_ctx, from_p, to_p, pad)
func world_get_mirror_hit(world_ctx: Node, from_p: Vector2, to_p: Vector2) -> Dictionary:
	return _world_q.get_mirror_hit(world_ctx, from_p, to_p)
func world_get_enemies(world_ctx: Node) -> Array:
	return _world_q.world_list(self, world_ctx, "get_enemies", "enemies", "lx_enemies")
func world_get_interactables(world_ctx: Node) -> Array:
	return _world_q.world_list(self, world_ctx, "get_interactables", "interactables", "lx_interactables")
func get_entity_pos(entity: Object) -> Vector2: return _world_q.get_entity_pos(entity)
func get_entity_radius(entity: Object, fallback: float = 8.0) -> float: return _world_q.get_entity_radius(entity, fallback)
func is_entity_alive(entity: Object) -> bool: return _world_q.is_entity_alive(entity)
func is_snatcher_entity(entity: Object) -> bool: return _world_q.is_snatcher_entity(entity)
func apply_hit_to_entity(entity: Object, hit: LxHit) -> int:
	return _world_q.apply_hit_to_entity(entity, hit)
func get_method_arity(obj: Object, method_name: String) -> int: return _world_q.get_method_arity(obj, method_name)

func spawn_afterimage(col: Color) -> void: _fx.spawn_afterimage(global_position, col, facing, "zip" if is_zipping() else "dash")
func spawn_ring(at_pos: Vector2, r0: float, r1: float, life: float, col: Color, width: float = 1.0) -> void: _fx.spawn_ring(at_pos, r0, r1, life, col, width)
func spawn_sparks(at_pos: Vector2, base_dir: Vector2, count: int, col: Color, min_spd: float, max_spd: float, life: float) -> void: _fx.spawn_sparks(at_pos, base_dir, count, col, min_spd, max_spd, life)
func _draw() -> void: _fx.draw(self, _walk_phase, _clock_t)
