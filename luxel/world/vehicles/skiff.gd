class_name LxVehicleSkiff
extends LxToy
## Island 2 Skiff: oarless lantern-recoil boat.
## Shots propel opposite aim; hanging lantern brakes as sea anchor; Zip whips around mooring posts;
## Dash triggers a Rudder Surge shaking off lampreys & batting mines; grounding at ebb weighs plates;
## mount persists across water region exits via capture/restore_mount_carryover().

const HULL_RADIUS: float = 8.5
const MAX_SPEED: float = 172.0
const SWING_MAX_SPEED: float = 198.0
const BOLT_THRUST: float = 96.0
const BEAM_THRUST: float = 220.0
const THROW_THRUST: float = 74.0
const FORWARD_DRAG: float = 1.50
const LATERAL_DRAG: float = 3.20
const ANCHOR_DRAG: float = 7.40
const RUDDER_CARVE: float = 2.50
const BUMP_RESTITUTION: float = 0.38
const SWING_DUR: float = 0.60
const DASH_COOLDOWN: float = 0.50
const DASH_IFRAME_S: float = 0.18
const DASH_IMPULSE: float = 135.0
const MINE_BAT_RADIUS: float = 26.0
const SLINGSHOT_LEAP_SPEED: float = 95.0
const SLINGSHOT_LEAP_DUR: float = 0.65

static var pending_carryover: Dictionary = {}

var vel: Vector2 = Vector2.ZERO
var heading: Vector2 = Vector2.RIGHT
var origin_pos: Vector2 = Vector2.ZERO
var rider: LxWick = null
var grounded: bool = false
var _swing_t: float = 0.0
var _swing_post: Vector2 = Vector2.ZERO
var _swing_post_node: Node = null
var _swing_sign: float = 1.0
var _swing_radius: float = 38.0
var _swing_boosted: bool = false
var _dash_cd: float = 0.0
var _dash_burst_t: float = 0.0
var _slingshot_t: float = 0.0
var _recoil_kick: float = 0.0
var _bank_amt: float = 0.0
var _bump_cd: float = 0.0
var _bat_cd: Dictionary = {}
var _wake_cd: float = 0.0
var _wake: Array[Dictionary] = []
var _bob_phase: float = 0.0
var _cached_dock_pos: Vector2 = Vector2.INF


# ---- Cross-region Water-Exit Mount Persistence Hook (for E0-1 loader & LxIsland2Rule) ----

static func capture_mount_carryover(wick: LxWick) -> bool:
	if wick == null or not is_instance_valid(wick) or not wick.is_mounted():
		return false
	var veh: Node = wick.get_mounted_vehicle()
	if not (veh is LxVehicleSkiff):
		return false
	var sk: LxVehicleSkiff = veh as LxVehicleSkiff
	pending_carryover = {
		"active": true, "vel": sk.vel, "heading": sk.heading,
		"island_id": sk.island_id, "from_region": sk.region_id,
	}
	return true

static func clear_mount_carryover() -> void:
	pending_carryover.clear()

static func restore_mount_carryover(reg: LxRegionLoader, wick: LxWick, spawn_at: Vector2) -> LxVehicleSkiff:
	if pending_carryover.is_empty() or not bool(pending_carryover.get("active", false)):
		return null
	var data: Dictionary = pending_carryover.duplicate(true)
	pending_carryover.clear()
	if reg == null or not is_instance_valid(reg) or wick == null or not is_instance_valid(wick) or wick.dead:
		return null
	var tt: String = str(reg.tile_at(spawn_at))
	var is_water_spawn: bool = tt == "water" or tt == "tide"
	var target_skiff: LxVehicleSkiff = _find_nearest_skiff(reg, spawn_at, 56.0)
	if not is_water_spawn and target_skiff == null:
		return null
	if target_skiff == null:
		var hv: Vector2 = data.get("heading", Vector2.RIGHT) as Vector2
		var created: LxInteractable = reg.spawn_interactable({
			"id": "skiff_carryover", "kind": "vehicle_skiff",
			"pos": [spawn_at.x, spawn_at.y], "props": {"dir": [hv.x, hv.y]},
		})
		target_skiff = created as LxVehicleSkiff if created is LxVehicleSkiff else null
	if target_skiff == null:
		return null
	if is_water_spawn and target_skiff._can_float_at(reg, spawn_at):
		target_skiff.pos = spawn_at
		target_skiff.position = spawn_at.round()
	var saved_h: Vector2 = data.get("heading", target_skiff.heading) as Vector2
	if saved_h.length_squared() > 0.01:
		target_skiff.heading = saved_h.normalized()
	target_skiff.vel = (data.get("vel", Vector2.ZERO) as Vector2) * 0.65
	wick.mount(target_skiff)
	wick.global_position = target_skiff.pos
	wick.last_pos = target_skiff.pos
	target_skiff.queue_redraw()
	return target_skiff

static func _find_nearest_skiff(reg: LxRegionLoader, at_pos: Vector2, max_d: float) -> LxVehicleSkiff:
	var best: LxVehicleSkiff = null
	var best_d2: float = max_d * max_d
	for it: LxInteractable in reg.get_interactables():
		if it is LxVehicleSkiff and is_instance_valid(it) and it.active:
			var d2: float = it.pos.distance_squared_to(at_pos)
			if d2 <= best_d2:
				best_d2 = d2; best = it as LxVehicleSkiff
	return best


# ---- Setup, Mounting & Docking ----

func _toy_setup() -> void:
	kind = "vehicle_skiff"
	size = Vector2(22.0, 14.0)
	radius = 15.0
	if not props.has("weight"):
		props["weight"] = 3.0
	origin_pos = pos
	heading = dir_vec("dir", Vector2.RIGHT)
	vel = Vector2.ZERO
	grounded = _check_grounded(region)
	_swing_t = 0.0; _swing_post_node = null; _swing_boosted = false
	_dash_cd = 0.0; _dash_burst_t = 0.0; _slingshot_t = 0.0
	_recoil_kick = 0.0; _bank_amt = 0.0; _cached_dock_pos = Vector2.INF
	_bat_cd.clear(); _wake.clear()
	z_index = LxPhysDraw.floor_z(region, -1)
	queue_redraw()

func is_grounded() -> bool: return grounded
func is_weight_body() -> bool: return active and grounded
func is_platform_solid() -> bool: return active
func get_platform_rect() -> Rect2: return Rect2(pos - size * 0.5, size)

func recall_to_dock(target_pos: Vector2) -> void:
	pos = target_pos; position = target_pos.round(); vel = Vector2.ZERO
	grounded = _check_grounded(region)
	_spawn_wake(pos, 6.0); _emit_sfx("harbor_creak"); queue_redraw()

func on_portal_warped(_from_p: Vector2, _to_p: Vector2, preserved_vel: Vector2) -> void:
	_swing_t = 0.0; _release_post_whip()
	if preserved_vel.length() >= SLINGSHOT_LEAP_SPEED:
		_slingshot_t = SLINGSHOT_LEAP_DUR
	_spawn_wake(pos, 7.0); queue_redraw()

func interact(actor: Node = null) -> bool:
	if not active or not (actor is LxWick):
		return false
	var w: LxWick = actor as LxWick
	if rider == w: return try_dismount(w)
	if w.is_mounted() or w.global_position.distance_to(pos) > 36.0: return false
	return w.mount(self)

func on_mounted(w: LxWick) -> void:
	rider = w
	if not w.fired.is_connected(_on_rider_fired):
		w.fired.connect(_on_rider_fired)
	w.global_position = pos; w.last_pos = pos
	_spawn_wake(pos, 5.5); _emit_sfx("harbor_creak"); queue_redraw()

func on_dismounted(w: LxWick) -> void:
	if w != null and w.fired.is_connected(_on_rider_fired):
		w.fired.disconnect(_on_rider_fired)
	if rider == w: rider = null
	_swing_t = 0.0; _release_post_whip()
	_emit_sfx("footstep_wood"); queue_redraw()

func try_dismount(w: LxWick) -> bool:
	var pref: Vector2 = w.get_move_input()
	var dock_p: Vector2 = _find_safe_dock_pos(pref if pref.length_squared() >= 0.04 else w.facing)
	if not dock_p.is_finite():
		_emit_sfx("denied"); return false
	w.dismount(dock_p)
	return true

func _find_safe_dock_pos(pref_dir: Vector2 = Vector2.ZERO) -> Vector2:
	if region == null:
		return pos + Vector2(0.0, -18.0)
	var base_ang: float = pref_dir.angle() if pref_dir.length_squared() > 0.01 else heading.angle()
	for dist: float in [16.0, 22.0, 28.0, 36.0]:
		for i: int in range(16):
			var step_i: int = (i / 2) * (1 if i % 2 == 0 else -1)
			var cand: Vector2 = pos + Vector2.from_angle(base_ang + TAU * float(step_i) / 16.0) * dist
			if LxPhysDraw.is_tile_safe_land(region, cand):
				var chk: Vector2 = region.call("collide", cand, LxWick.BODY_RADIUS, false, false, id) as Vector2 if region.has_method("collide") else cand
				if chk.distance_to(cand) < 2.2 and LxPhysDraw.is_tile_safe_land(region, chk):
					return chk
	if region.has_method("get_interactables"):
		var best_alt: Vector2 = Vector2.INF
		var best_d2: float = 44.0 * 44.0
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable): continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active: continue
			if it.kind == "tide_raft" and it.is_platform_solid():
				var d2: float = it.pos.distance_squared_to(pos)
				if d2 < best_d2: best_d2 = d2; best_alt = it.pos
			elif it.kind == "mooring_post" and it.has_method("get_dismount_pos"):
				var dp: Vector2 = it.call("get_dismount_pos", pos) as Vector2
				if dp.is_finite() and it.pos.distance_squared_to(pos) < best_d2:
					best_d2 = it.pos.distance_squared_to(pos); best_alt = dp
		if best_alt.is_finite(): return best_alt
	return Vector2.INF


# ---- Recoil Thrust, Rudder Surge Dash, Mine Batting & Mooring Whip ----

func _on_rider_fired(aim_dir: Vector2, fire_kind: String) -> void:
	if rider == null or not is_instance_valid(rider) or aim_dir.length_squared() <= 0.0001:
		return
	grounded = _check_grounded(region)
	if grounded:
		_recoil_kick = 0.14; return
	var thrust_dir: Vector2 = -aim_dir.normalized()
	var imp: float = BEAM_THRUST if fire_kind == "beam" else (THROW_THRUST if fire_kind == "throw" else BOLT_THRUST)
	if fire_kind == "bolt":
		if rider.temper == "scatter": imp *= 1.35
		elif rider.temper == "lance": imp *= 1.45
	vel = (vel + thrust_dir * imp).limit_length(MAX_SPEED)
	if vel.length_squared() > 16.0:
		heading = heading.lerp(vel.normalized(), 0.36).normalized()
	_recoil_kick = 1.0
	_spawn_wake(pos - thrust_dir * 8.0, 5.0)
	_emit_sfx("tide_wave")
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", thrust_dir, 0.9)
	queue_redraw()

func on_wick_dash(w: LxWick) -> bool:
	if rider != w or _dash_cd > 0.0 or grounded:
		return false
	_dash_cd = DASH_COOLDOWN; _dash_burst_t = 0.20
	w.mercy_t = maxf(w.mercy_t, DASH_IFRAME_S)
	var d_in: Vector2 = w.get_move_input()
	var sdir: Vector2 = d_in.normalized() if d_in.length_squared() > 0.04 else (heading.normalized() if heading.length_squared() > 0.01 else Vector2.RIGHT)
	vel = (vel * 0.45 + sdir * DASH_IMPULSE).limit_length(SWING_MAX_SPEED)
	heading = sdir
	_spawn_wake(pos - sdir * 8.0, 7.0)
	w.spawn_ring(pos, 4.0, 18.0, 0.20, PAL["ice"] as Color, 1.4)
	w.spawn_sparks(pos, -sdir, 7, PAL["cream"] as Color, 32.0, 90.0, 0.18)
	_emit_sfx("dash_whoosh")
	_shake_off_latched_enemies(w)
	_bat_nearby_mines(sdir, 210.0)
	queue_redraw()
	return true

func _shake_off_latched_enemies(w: LxWick) -> void:
	if region == null or not region.has_method("get_enemies"): return
	for e_v: Variant in region.call("get_enemies") as Array:
		if e_v is Object and is_instance_valid(e_v as Object) and (e_v as Object).has_method("on_skiff_shake_off"):
			(e_v as Object).call("on_skiff_shake_off", self, w)

func _bat_nearby_mines(bat_dir: Vector2, bat_speed: float) -> void:
	if region == null or not is_instance_valid(region): return
	var bd: Vector2 = bat_dir.normalized() if bat_dir.length_squared() > 0.001 else heading
	if region.has_method("get_enemies"):
		for e_v: Variant in region.call("get_enemies") as Array:
			if not (e_v is LxEnemyBrain) or not is_instance_valid(e_v): continue
			var en: LxEnemyBrain = e_v as LxEnemyBrain
			var eid: int = en.get_instance_id()
			if not en.is_alive() or en.kind != "buoy_mine" or _bat_cd.has(eid) or en.pos.distance_to(pos) > MINE_BAT_RADIUS: continue
			_bat_cd[eid] = 0.28
			var push_d: Vector2 = ((en.pos - pos).normalized() * 0.65 + bd * 0.35).normalized() if en.pos.distance_to(pos) > 2.0 else bd
			if en.has_method("on_skiff_bat"): en.call("on_skiff_bat", push_d, bat_speed)
			else: en.vel = push_d * bat_speed
			_emit_bat_fx(en.pos, push_d)
	if region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable): continue
			var it: LxInteractable = it_v as LxInteractable
			var iid: int = it.get_instance_id()
			if not is_instance_valid(it) or not it.active or (it.kind != "ballast_keg" and it.kind != "buoy_mine"): continue
			if _bat_cd.has(iid) or it.pos.distance_to(pos) > MINE_BAT_RADIUS: continue
			_bat_cd[iid] = 0.28
			var push_i: Vector2 = ((it.pos - pos).normalized() * 0.6 + bd * 0.4).normalized() if it.pos.distance_to(pos) > 2.0 else bd
			if it.has_method("on_skiff_bat"): it.call("on_skiff_bat", push_i, bat_speed)
			elif it.has_method("push_keg"): it.call("push_keg", push_i * bat_speed)
			_emit_bat_fx(it.pos, push_i)

func _emit_bat_fx(at_pos: Vector2, push_dir: Vector2) -> void:
	if rider != null and is_instance_valid(rider):
		rider.spawn_ring(at_pos, 2.0, 14.0, 0.18, PAL["gold"] as Color, 1.4)
		rider.spawn_sparks(at_pos, push_dir, 6, PAL["cream"] as Color, 40.0, 105.0, 0.18)
	_emit_sfx("shield_clang")

func on_wick_zip(w: LxWick) -> bool:
	if rider != w or w.lantern == null or not w.lantern.is_lure_active() or grounded:
		return false
	var post_node: Node = _find_anchored_mooring_post(w.lantern.pos)
	var anchor_p: Vector2 = (post_node.get("pos") as Vector2) if (post_node != null and post_node.get("pos") is Vector2) else w.lantern.pos
	var to_post: Vector2 = anchor_p - pos
	var dist: float = to_post.length()
	if dist < 10.0:
		w.lantern.catch_by_wick(w); return true
	_release_post_whip()
	_swing_post = anchor_p; _swing_post_node = post_node; _swing_boosted = post_node != null
	var pref_r: float = float(post_node.get("orbit_r")) if (post_node != null and post_node.get("orbit_r") != null) else 38.0
	_swing_radius = clampf(lerpf(dist, pref_r, 0.45), 22.0, 84.0) if _swing_boosted else clampf(dist, 22.0, 96.0)
	_swing_t = SWING_DUR * (1.12 if _swing_boosted else 0.92)
	var radial: Vector2 = to_post / dist
	var perp_ccw := Vector2(-radial.y, radial.x)
	var steer_ref: Vector2 = vel if vel.length_squared() > 25.0 else w.get_move_input()
	_swing_sign = 1.0 if steer_ref.dot(perp_ccw) >= 0.0 else -1.0
	var tang: Vector2 = perp_ccw * _swing_sign
	var swing_spd: float = clampf(maxf(vel.length() * (1.32 if _swing_boosted else 1.15), 178.0 if _swing_boosted else 124.0), 114.0, SWING_MAX_SPEED if _swing_boosted else MAX_SPEED)
	vel = (tang * 0.86 + radial * 0.36).normalized() * swing_spd
	if _swing_boosted and post_node.has_method("begin_whip"): post_node.call("begin_whip", self)
	_shake_off_latched_enemies(w)
	w.spawn_ring(_swing_post, 2.0, 16.0 if _swing_boosted else 12.0, 0.22, PAL["gold"] as Color, 1.4)
	w.spawn_sparks(_swing_post, tang, 8 if _swing_boosted else 5, PAL["cream"] as Color, 40.0, 100.0, 0.20)
	_emit_sfx("zip_streak")
	return true

func _find_anchored_mooring_post(lan_pos: Vector2) -> Node:
	if region == null or not region.has_method("get_interactables"): return null
	var best: Node = null; var best_d: float = 26.0
	for it_v: Variant in region.call("get_interactables") as Array:
		if it_v is LxInteractable and is_instance_valid(it_v as Object):
			var it: LxInteractable = it_v as LxInteractable
			if it.active and it.kind == "mooring_post" and it.pos.distance_to(lan_pos) <= best_d:
				best_d = it.pos.distance_to(lan_pos); best = it
	return best

func _release_post_whip() -> void:
	if _swing_post_node != null and is_instance_valid(_swing_post_node) and _swing_post_node.has_method("end_whip"):
		_swing_post_node.call("end_whip", self)
	_swing_post_node = null; _swing_boosted = false


# ---- Physics Simulation ----

func tick_mounted(dt: float, w: LxWick, world_ctx: Node) -> void:
	if rider != w: return
	var steer: Vector2 = w.get_move_input()
	if not grounded and steer.length_squared() > 0.04 and vel.length() > 10.0:
		var spd: float = vel.length()
		vel = (vel / spd).lerp(steer.normalized(), minf(1.0, dt * RUDDER_CARVE)).normalized() * spd
	_step_water_physics(dt, world_ctx)
	w.global_position = pos; w.velocity = vel
	_cached_dock_pos = _find_safe_dock_pos(steer if steer.length_squared() > 0.04 else w.facing)
	if world_ctx != null and world_ctx.has_method("check_exit"):
		var ex: Dictionary = world_ctx.call("check_exit", pos) as Dictionary
		if not ex.is_empty(): capture_mount_carryover(w)

func tick(dt: float) -> void:
	super.tick(dt)
	_bob_phase += dt * 2.5
	_bump_cd = maxf(0.0, _bump_cd - dt); _dash_cd = maxf(0.0, _dash_cd - dt)
	_dash_burst_t = maxf(0.0, _dash_burst_t - dt); _slingshot_t = maxf(0.0, _slingshot_t - dt)
	_recoil_kick = maxf(0.0, _recoil_kick - dt * 5.0)
	if not _bat_cd.is_empty():
		var exp_b: Array[int] = []
		for k: Variant in _bat_cd.keys():
			var r: float = float(_bat_cd[k]) - dt
			if r <= 0.0: exp_b.append(int(k))
			else: _bat_cd[k] = r
		for ek: int in exp_b: _bat_cd.erase(ek)
	for i: int in range(_wake.size() - 1, -1, -1):
		_wake[i]["age"] = float(_wake[i]["age"]) + dt
		if float(_wake[i]["age"]) >= float(_wake[i]["life"]): _wake.remove_at(i)
	grounded = _check_grounded(region)
	if grounded:
		vel = Vector2.ZERO; _swing_t = 0.0; _release_post_whip()
	if rider == null or not is_instance_valid(rider):
		rider = null; _cached_dock_pos = Vector2.INF
		if not grounded and (vel.length_squared() > 0.5 or LxFields.has_fields()):
			_step_water_physics(dt, region)
	queue_redraw()

func _step_water_physics(dt: float, world_ctx: Node) -> void:
	var ctx: Node = world_ctx if world_ctx != null else region
	grounded = _check_grounded(ctx)
	if grounded and _slingshot_t <= 0.0:
		vel = Vector2.ZERO; _bank_amt = move_toward(_bank_amt, 0.0, dt * 6.0); return
	var top_spd: float = SWING_MAX_SPEED if (_swing_boosted or _dash_burst_t > 0.0 or _slingshot_t > 0.0) else MAX_SPEED
	if _swing_t > 0.0 and rider != null and rider.lantern != null and rider.lantern.is_lure_active():
		_swing_t = maxf(0.0, _swing_t - dt)
		_swing_post = (_swing_post_node.get("pos") as Vector2) if (_swing_post_node != null and is_instance_valid(_swing_post_node) and _swing_post_node.get("pos") is Vector2) else rider.lantern.pos
		var to_c: Vector2 = _swing_post - pos
		var dist: float = maxf(8.0, to_c.length())
		var radial: Vector2 = to_c / dist
		var tang := Vector2(-radial.y, radial.x) * _swing_sign
		var speed: float = maxf(vel.length(), 174.0 if _swing_boosted else 116.0)
		vel = (tang * speed + radial * clampf((dist - _swing_radius * 0.78) * 3.8, -68.0, 105.0)).limit_length(top_spd)
		if _swing_t <= 0.0:
			if _swing_boosted: vel = tang * clampf(speed * 1.06, 130.0, SWING_MAX_SPEED)
			_release_post_whip()
	elif _swing_t > 0.0 or _swing_post_node != null:
		_swing_t = 0.0; _release_post_whip()

	if LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(pos, "wick")
		if fa.length_squared() > 0.01: vel = (vel + fa * dt).limit_length(top_spd)

	var anchored: bool = rider != null and rider.lantern != null and rider.lantern.is_hanging() and _swing_t <= 0.0 and rider.lantern.pos.distance_to(pos) <= 145.0
	var fwd: Vector2 = heading.normalized() if heading.length_squared() > 0.01 else Vector2.RIGHT
	var lat := Vector2(-fwd.y, fwd.x)
	var lat_v: float = vel.dot(lat)
	_bank_amt = lerpf(_bank_amt, clampf(lat_v / 95.0, -1.0, 1.0), minf(1.0, dt * 8.0))
	if anchored:
		vel *= exp(-ANCHOR_DRAG * dt)
	elif _slingshot_t <= 0.0:
		vel = fwd * (vel.dot(fwd) * exp(-FORWARD_DRAG * dt)) + lat * (lat_v * exp(-LATERAL_DRAG * dt))

	if vel.length_squared() < 1.5:
		vel = Vector2.ZERO; return

	var desired: Vector2 = pos + vel * dt
	var resolved: Vector2 = _resolve_water_step(ctx, pos, desired)
	if resolved.distance_to(desired) > 0.45:
		var bx: bool = not _can_float_at(ctx, Vector2(desired.x, pos.y))
		var by: bool = not _can_float_at(ctx, Vector2(pos.x, desired.y))
		if bx: vel.x = -vel.x * BUMP_RESTITUTION
		if by: vel.y = -vel.y * BUMP_RESTITUTION
		if not bx and not by: vel = -vel * BUMP_RESTITUTION
		if _bump_cd <= 0.0 and vel.length() > 14.0:
			_bump_cd = 0.25; _emit_sfx("harbor_creak"); _spawn_wake(resolved, 5.0)
	pos = resolved; position = pos.round()

	var spd_now: float = vel.length()
	if spd_now >= 52.0 or _dash_burst_t > 0.0:
		_bat_nearby_mines(vel / maxf(spd_now, 1.0), maxf(165.0, spd_now * 1.25))
	if spd_now > 10.0:
		heading = heading.lerp(vel / spd_now, minf(1.0, dt * 7.5)).normalized()
		_wake_cd -= dt
		if _wake_cd <= 0.0:
			_wake_cd = clampf(0.15 - spd_now * 0.00055, 0.048, 0.15)
			_spawn_wake(pos - heading * 8.0, 2.5 + spd_now * 0.022)

func _check_grounded(ctx: Node) -> bool:
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("tile_at"): return false
	var tt: String = str(ctx.call("tile_at", pos))
	return tt != "water" and tt != "tide" and tt != "pit" and tt != "void"

func _is_navigable_tile(tt: String) -> bool:
	return tt == "water" or tt == "tide" or (_slingshot_t > 0.0 and (tt == "pit" or tt == "void"))

func _can_float_at(ctx: Node, p: Vector2) -> bool:
	if ctx == null or not is_instance_valid(ctx): return true
	var b_v: Variant = ctx.get("bounds")
	if b_v is Rect2 and (b_v as Rect2).has_area() and not (b_v as Rect2).grow(-HULL_RADIUS).has_point(p):
		return false
	if ctx.has_method("tile_at"):
		if not _is_navigable_tile(str(ctx.call("tile_at", p))): return false
		for off_p: Vector2 in [Vector2(HULL_RADIUS * 0.68, 0.0), Vector2(-HULL_RADIUS * 0.68, 0.0), Vector2(0.0, HULL_RADIUS * 0.58), Vector2(0.0, -HULL_RADIUS * 0.58)]:
			if not _is_navigable_tile(str(ctx.call("tile_at", p + off_p))): return false
	if ctx.has_method("get_interactables"):
		var my_r := Rect2(p - Vector2(HULL_RADIUS, HULL_RADIUS * 0.7), Vector2(HULL_RADIUS * 2.0, HULL_RADIUS * 1.4))
		for it_v: Variant in ctx.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable): continue
			var it: LxInteractable = it_v as LxInteractable
			if it.is_solid() and it.get_solid_rect().intersects(my_r): return false
	return true

func _resolve_water_step(ctx: Node, from_p: Vector2, to_p: Vector2) -> Vector2:
	if _can_float_at(ctx, to_p): return to_p
	if _can_float_at(ctx, Vector2(to_p.x, from_p.y)): return Vector2(to_p.x, from_p.y)
	if _can_float_at(ctx, Vector2(from_p.x, to_p.y)): return Vector2(from_p.x, to_p.y)
	var delta: Vector2 = to_p - from_p
	var step_len: float = delta.length()
	if step_len > 0.25:
		var perp := Vector2(-delta.y, delta.x) / step_len
		for sgn: float in [1.0, -1.0]:
			var nudged: Vector2 = to_p + perp * (sgn * 3.0)
			if _can_float_at(ctx, nudged): return from_p.move_toward(nudged, step_len)
	return from_p

func _spawn_wake(at_pos: Vector2, r1: float) -> void:
	if _wake.size() >= 16: _wake.remove_at(0)
	_wake.append({"pos": at_pos, "age": 0.0, "life": 0.48, "r1": r1})

func get_interact_prompt() -> String:
	if not active: return ""
	if rider != null: return "PROMPT_LEAVE_SKIFF" if _find_safe_dock_pos().is_finite() else ""
	return "PROMPT_BOARD_SKIFF"

func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist: d["pos"] = [pos.x, pos.y]; d["heading"] = [heading.x, heading.y]
	return d

func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pos"): pos = _parse_vec2(d.get("pos"), origin_pos); position = pos.round()
	if persist and d.has("heading"):
		var h: Vector2 = _parse_vec2(d.get("heading"), heading)
		if h.length_squared() > 0.01: heading = h.normalized()
	grounded = _check_grounded(region); queue_redraw()


# ---- Rendering ----

func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var leap_y: float = -roundf(sin(clampf(_slingshot_t / SLINGSHOT_LEAP_DUR, 0.0, 1.0) * PI) * 5.0) if _slingshot_t > 0.0 else 0.0
	var bob: float = 0.0 if (red or grounded) else (roundf(sin(_bob_phase) * 0.8) + leap_y)
	var fwd: Vector2 = heading.normalized() if heading.length_squared() > 0.01 else Vector2.RIGHT
	var side := Vector2(-fwd.y, fwd.x)
	var base_off: Vector2 = -fwd * roundf(_recoil_kick * 1.5) + side * roundf(_bank_amt * 1.2) + Vector2(0.0, bob)

	for wk: Dictionary in _wake:
		var u: float = clampf(float(wk["age"]) / maxf(0.01, float(wk["life"])), 0.0, 1.0)
		var lp: Vector2 = ((wk["pos"] as Vector2) - pos).round()
		draw_arc(lp, lerpf(2.0, float(wk["r1"]) + 4.5, u), 0.0, TAU, 10, Color(PAL["ice"] as Color if u < 0.4 else PAL["sky"] as Color, (1.0 - u) * 0.72), 1.0)

	if rider != null and is_instance_valid(rider) and rider.lantern != null and rider.lantern.is_lure_active():
		var lrel: Vector2 = (rider.lantern.pos - pos).round()
		var prow_p: Vector2 = (fwd * 10.0 + base_off).round()
		var rope_c: Color = (PAL["cream"] if _swing_boosted else PAL["gold"]) as Color if _swing_t > 0.0 else PAL["apricot"] as Color
		draw_line(prow_p, lrel, Color(PAL["void"] as Color, 0.55), 2.0)
		draw_line(prow_p, lrel, Color(rope_c, 0.92), 1.0)

	if rider != null and _cached_dock_pos.is_finite() and _cached_dock_pos.distance_squared_to(pos) > 4.0:
		var ddir: Vector2 = (_cached_dock_pos - pos).normalized()
		var dc: Color = (PAL["cream"] if (red or int(floorf(_bob_phase * 2.0)) % 2 == 0) else PAL["gold"]) as Color
		LxPhysDraw.draw_chevron(self, (ddir * 15.0).round(), ddir, dc, PAL["void"] as Color, 2.5)

	var c_out: Color = PAL["void"] as Color
	var hull_pts := PackedVector2Array([
		(fwd * 11.0 + base_off).round(), (fwd * 4.0 + side * 6.5 + base_off).round(),
		(-fwd * 9.0 + side * 5.0 + base_off).round(), (-fwd * 10.0 + base_off).round(),
		(-fwd * 9.0 - side * 5.0 + base_off).round(), (fwd * 4.0 - side * 6.5 + base_off).round(),
	])
	var sh_pts := PackedVector2Array()
	for pt: Vector2 in hull_pts: sh_pts.append(pt + Vector2(1.0, 2.0 - leap_y))
	draw_colored_polygon(sh_pts, Color(c_out, 0.45))
	draw_colored_polygon(hull_pts, (PAL["dusk"] if grounded else PAL["wine"]) as Color)
	draw_colored_polygon(PackedVector2Array([
		(fwd * 7.5 + base_off).round(), (fwd * 3.0 + side * 4.0 + base_off).round(),
		(-fwd * 7.0 + side * 3.0 + base_off).round(), (-fwd * 7.0 - side * 3.0 + base_off).round(),
		(fwd * 3.0 - side * 4.0 + base_off).round(),
	]), (PAL["stone"] if grounded else PAL["apricot"]) as Color)
	var closed := PackedVector2Array(hull_pts); closed.append(hull_pts[0])
	draw_polyline(closed, c_out, 1.0)
	draw_line((side * 3.5 + base_off).round(), (-side * 3.5 + base_off).round(), biome("hi"), 1.0)
	draw_line((-fwd * 4.5 + side * 3.0 + base_off).round(), (-fwd * 4.5 - side * 3.0 + base_off).round(), PAL["dusk"] as Color, 1.0)
	draw_rect(Rect2((fwd * 9.0 + base_off).round() - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color if _dash_burst_t > 0.0 else biome("glow"))
	if not grounded and vel.length() > 16.0:
		var bow: Vector2 = (fwd * 10.0 + base_off).round()
		var wc: Color = PAL["cream"] as Color if (_dash_burst_t > 0.0 or _swing_boosted) else PAL["ice"] as Color
		draw_line(bow, (bow - fwd * 7.5 + side * 6.5).round(), wc, 1.0)
		draw_line(bow, (bow - fwd * 7.5 - side * 6.5).round(), wc, 1.0)
