class_name LxMoveDash
extends LxMove
## Flare Dash: directional dash with i-frames, shield-wear + stagger strike, gap crossing up to 32 px,
## perfect dodge cooldown refund, and Wings (LxMoveWings) glide continuation when lx_dash stays held.

const DASH_BOUNCE_TIME: float = 0.24
const DASH_BOUNCE_KNOCK: float = 150.0

var active: bool = false
var is_gliding: bool = false
var dash_held: bool = false

var dash_dir: Vector2 = Vector2.RIGHT
var dash_speed: float = 340.0
var dash_time_left: float = 0.0
var dash_elapsed: float = 0.0
var dash_dist_traveled: float = 0.0
var gap_max_px: float = 32.0
var iframes_left: float = 0.0
var perfect_window: float = 0.12
var perfect_refund_done: bool = false
var counter_t: float = 0.0

var hit_ids: Array[int] = []
var _afterimage_cd: float = 0.0
var _buffer_t: float = 0.0
var _mid_spray_done: bool = false


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or active or is_gliding or wick.is_gliding() or wick.is_zipping() or wick.bounce_t > 0.0:
		return false
	return true


func press() -> bool:
	dash_held = true
	if is_gliding and _is_wings_toggle():
		is_gliding = false
		if wick != null and wick.move_wings != null:
			wick.move_wings.stop_glide()
		return true
	if not can_use():
		if not unlocked and wick != null:
			wick.emit_sfx("denied", wick.global_position, false)
		elif unlocked and wick != null and not wick.dead and not active and not is_gliding and not wick.is_gliding():
			_buffer_t = 0.09
		return false
	return _execute_dash()


func _execute_dash() -> bool:
	_buffer_t = 0.0
	if wick.move_beam != null:
		wick.move_beam.cancel()

	var data: Dictionary = get_data()
	var move_v: Vector2 = wick.get_move_input()
	if move_v.length_squared() > 0.01:
		dash_dir = move_v.normalized()
	elif wick.facing.length_squared() > 0.0001:
		dash_dir = wick.facing.normalized()
	else:
		dash_dir = Vector2.RIGHT

	dash_speed = float(data.get("speed", 340.0))
	var duration: float = float(data.get("duration", 0.17))
	var eff_cd: float = _get_effective_cooldown()

	active = true
	is_gliding = false
	if wick.move_wings != null:
		wick.move_wings.stop_glide()
	dash_time_left = duration
	dash_elapsed = 0.0
	dash_dist_traveled = 0.0
	gap_max_px = float(data.get("gap_max_px", 32.0))
	iframes_left = float(data.get("iframes", 0.19))
	perfect_window = float(data.get("perfect_window", 0.12))
	perfect_refund_done = false
	cooldown_left = eff_cd + duration
	hit_ids.clear()
	_afterimage_cd = 0.0
	_mid_spray_done = false

	var isl_d: int = Lx.state.island_id if Lx.state != null else 1
	var b_hi: Color = LxBiomePalette.col(isl_d, "hi")
	var b_glow: Color = LxBiomePalette.col(isl_d, "glow")
	wick.spawn_afterimage(b_hi)
	wick.spawn_ring(wick.global_position, 2.0, 12.0, 0.16, b_glow, 1.0)
	_gust(38.0, 42.0)
	_shore_spray(true)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_dir_decal(LxGroundDecals.Kind.SKID, wick.global_position + Vector2(0.0, 4.0), dash_dir, 7.0, 2.4, false)
	wick.emit_sfx("dash_whoosh", wick.global_position, false)
	var panes_d: LxPanes = LxPanes.current()
	if panes_d != null and not panes_d.equipped_ids().is_empty():
		panes_d.fire_dash({"pos": wick.global_position, "dir": dash_dir, "wick": wick, "world": wick._world_ctx if wick._world_ctx != null else Lx.world})
	return true


func release() -> void:
	dash_held = false
	if _is_wings_toggle():
		return
	if wick != null and wick.move_wings != null:
		wick.move_wings.stop_glide()
	is_gliding = false


func tick(dt: float) -> void:
	super.tick(dt)
	if iframes_left > 0.0:
		iframes_left = maxf(0.0, iframes_left - dt)
	if counter_t > 0.0:
		counter_t = maxf(0.0, counter_t - dt)
	if _buffer_t > 0.0:
		_buffer_t = maxf(0.0, _buffer_t - dt)
		if can_use():
			_execute_dash()


func tick_dash(dt: float, world_ctx: Node) -> void:
	if wick == null:
		return

	if active:
		dash_elapsed += dt
		dash_time_left -= dt
		var step_vec: Vector2 = dash_dir * dash_speed * dt
		dash_dist_traveled += step_vec.length()

		var isl_t: int = Lx.state.island_id if Lx.state != null else 1
		_afterimage_cd -= dt
		if _afterimage_cd <= 0.0:
			_afterimage_cd = 0.032
			wick.spawn_afterimage(LxBiomePalette.col(isl_t, "hi"))
		wick.spawn_sparks(wick.global_position, -dash_dir, 1, LxBiomePalette.col(isl_t, "glow"), 8.0, 22.0, 0.16)

		_check_dash_hits(world_ctx)
		if active and not _mid_spray_done and dash_elapsed >= dash_time_left:
			_mid_spray_done = true
			_shore_spray(true)

		if active and dash_time_left <= 0.0:
			active = false
			_shore_spray(true)
			_maybe_start_wings_glide()
		return

	if wick.move_wings != null and wick.move_wings.gliding:
		wick.move_wings.tick_glide(dt, dash_held or _is_wings_toggle())
		is_gliding = wick.move_wings.gliding
		dash_dir = wick.move_wings.glide_dir
	else:
		is_gliding = false


func _maybe_start_wings_glide() -> void:
	if (not dash_held and not _is_wings_toggle()) or wick == null or wick.move_wings == null:
		is_gliding = false
		return
	is_gliding = wick.move_wings.start_glide(dash_dir)


func _is_wings_toggle() -> bool:
	return Lx.input != null and Lx.input.is_toggle_mode("lx_wings")


func _check_dash_hits(world_ctx: Node) -> void:
	var data: Dictionary = get_data()
	var dmg: float = float(data.get("damage", 1.25))
	var wear: float = float(data.get("shield_wear", 1.0))
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.12))

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not wick.is_entity_alive(enemy):
			continue
		var eid: int = enemy.get_instance_id()
		if hit_ids.has(eid):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		var extra: float = 8.5 if wick.is_snatcher_entity(enemy) else 3.5
		if Geometry2D.get_closest_point_to_segment(epos, wick.last_pos, wick.global_position).distance_to(epos) <= erad + extra:
			hit_ids.append(eid)
			var hit: LxHit = LxHit.make(
				LxHit.SOURCE_DASH, dmg, dash_dir, wick.global_position - dash_dir * 12.0,
				wear, stag, false, wick, false
			)
			var res: int = wick.apply_hit_to_entity(enemy, hit)
			wick.on_hit_landed(hit, res, epos, hs, sh)
			if res == 0:
				# Shield blocked the dash -> crisp bounce-back
				active = false
				is_gliding = false
				if wick.move_wings != null:
					wick.move_wings.stop_glide()
				dash_time_left = 0.0
				wick.bounce_t = DASH_BOUNCE_TIME
				wick.knock = -dash_dir * DASH_BOUNCE_KNOCK
				wick.spawn_ring(wick.global_position, 2.0, 12.0, 0.18, LxWick.PAL_STONE, 1.2)
				return


func get_active_velocity() -> Vector2:
	if active:
		return dash_dir * dash_speed
	if wick != null and wick.move_wings != null and wick.move_wings.gliding:
		return wick.move_wings.get_glide_velocity()
	return Vector2.ZERO


func can_cross_gaps() -> bool:
	if is_gliding or (wick != null and wick.move_wings != null and wick.move_wings.gliding):
		return true
	return active and dash_dist_traveled <= gap_max_px + 28.0


func has_iframes() -> bool:
	return iframes_left > 0.0


func on_perfect_dodge() -> bool:
	if iframes_left <= 0.0:
		return false
	var data: Dictionary = get_data()
	var allow_refund: bool = bool(data.get("perfect_refund", true))
	if allow_refund and not perfect_refund_done:
		perfect_refund_done = true
		cooldown_left = 0.0
		counter_t = 1.45
		wick.perfect_dodges += 1
		wick.trigger_hitstop(0.045)
		wick.trigger_shake(0.10)
		var isl_p: int = Lx.state.island_id if Lx.state != null else 1
		var p_glow: Color = LxBiomePalette.col(isl_p, "glow")
		wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.24, LxWick.PAL_ICE, 1.5)
		wick.spawn_ring(wick.global_position, 2.0, 12.0, 0.18, LxWick.PAL_CREAM, 1.0)
		wick.spawn_ring(wick.global_position, 4.0, 23.0, 0.28, p_glow, 1.1)
		wick.spawn_sparks(wick.global_position, -dash_dir, 8, LxWick.PAL_ICE, 34.0, 86.0, 0.22)
		wick.spawn_sparks(wick.global_position, dash_dir, 4, p_glow, 28.0, 78.0, 0.24)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			var p_dk: int = LxGroundDecals.Kind.BLOSSOM if isl_p in [3, 4] else (LxGroundDecals.Kind.SCORCH if isl_p == 6 else LxGroundDecals.Kind.PRISM_STAR)
			LxGroundDecals.active_instance.add_decal(p_dk, wick.global_position + Vector2(0.0, 3.0), 12.0, 4.5)
		_gust(64.0, 72.0)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.trigger_focus_flash(0.85)
			LxDarknessLayer.active_instance.add_burst_light(wick.global_position, 74.0, 0.94 if LxHudFx.flash_reduced() else 1.45, 0.30)
		wick.emit_sfx("perfect_dodge", wick.global_position, false)
		var panes_pd: LxPanes = LxPanes.current()
		if panes_pd != null and not panes_pd.equipped_ids().is_empty():
			panes_pd.fire_perfect_dodge({"pos": wick.global_position, "dir": dash_dir, "wick": wick, "world": wick._world_ctx if wick._world_ctx != null else Lx.world})
		if Lx.ui != null and Lx.ui.get("hud") != null and (Lx.ui.get("hud") as Node).has_method("spawn_world_cue"):
			(Lx.ui.get("hud") as Node).call("spawn_world_cue", "CUE_PERFECT_DODGE", wick.global_position + Vector2(0.0, -10.0), "ice", 1.1)
		if wick.move_sunflare != null and wick.move_sunflare.unlocked:
			var emax: float = wick.move_sunflare.get_ember_max()
			var was_full: bool = wick.ember >= emax - 0.001
			wick.ember = minf(emax, wick.ember + 10.0)
			if not was_full and wick.ember >= emax - 0.001:
				wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
				wick.emit_sfx("beam_ready", wick.global_position, false)
	return true


func consume_counter() -> bool:
	if counter_t > 0.0:
		counter_t = 0.0
		return true
	return false


func cancel() -> void:
	active = false
	is_gliding = false
	dash_time_left = 0.0
	_mid_spray_done = false
	if wick != null and wick.move_wings != null:
		wick.move_wings.stop_glide()


func reset() -> void:
	super.reset()
	cancel()
	dash_held = false
	_buffer_t = 0.0
	_mid_spray_done = false
	iframes_left = 0.0
	perfect_refund_done = false
	counter_t = 0.0
	hit_ids.clear()


func _get_effective_cooldown() -> float:
	var base: float = Lx.state.get_effective_dash_cooldown() if Lx.state != null else float(get_data().get("cooldown", 0.55))
	var panes: LxPanes = LxPanes.current()
	if panes != null and not panes.equipped_ids().is_empty():
		return panes.modify_stat("dash_cooldown", base, {"wick": wick})
	return base


func _gust(radius: float, strength: float) -> void:
	if wick != null and Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", wick.global_position, radius, strength)


func _shore_spray(burst: bool = true) -> void:
	if wick != null and LxWaterFx.active_instance != null and is_instance_valid(LxWaterFx.active_instance):
		LxWaterFx.active_instance.spawn_shore_spray(wick.global_position, dash_dir, burst)
