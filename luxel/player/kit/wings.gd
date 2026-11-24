class_name LxMoveWings
extends LxMove
## Wings (Island 4): hold lx_dash (Shift / A) at the end of a Flare Dash to glide up to
## glide_max_px (96 px) at glide_speed (120 px/s, max glide_duration 0.8 s).
## While gliding, Wick crosses pit and water tiles and hops over ground shockwave rings.
## Includes 0.10 s coyote grace at landing edges and a crisp small stamina arc under Wick.

const COYOTE_GRACE_S: float = 0.10
const COYOTE_EDGE_PX: float = 14.0

class WingsArcOverlay:
	extends Node2D
	var owner_wings: LxMoveWings = null

	func _draw() -> void:
		if owner_wings == null or not owner_wings.gliding:
			return
		var frac: float = owner_wings.get_stamina_ratio()
		var is_coyote: bool = owner_wings.coyote_active
		var c_void: Color = LxWick.PAL_VOID
		var c_arc: Color = LxWick.PAL_CORAL if (is_coyote or frac < 0.28) else (LxWick.PAL_GOLD if frac < 0.55 else LxWick.PAL_ICE)
		if owner_wings.has_updraft_boost() and frac > 0.60:
			c_arc = LxWick.PAL_CREAM
		var center := Vector2(0.0, 2.0)
		var rad: float = 9.0
		var a0: float = PI * 0.16
		var span: float = PI * 0.68
		# Crisp dark backing arc for contrast over both bright water and dark pits
		draw_arc(center, rad, a0 - 0.08, a0 + span + 0.08, 12, Color(c_void, 0.88), 3.0, false)
		if frac > 0.01:
			draw_arc(center, rad, a0, a0 + span * frac, 12, c_arc, 1.5, false)
			var tip_a: float = a0 + span * frac
			var tip := Vector2(roundf(center.x + cos(tip_a) * rad), roundf(center.y + sin(tip_a) * rad))
			draw_rect(Rect2(tip, Vector2.ONE), LxWick.PAL_CREAM)
		elif is_coyote:
			var c_u: float = clampf(owner_wings.coyote_left / COYOTE_GRACE_S, 0.0, 1.0)
			var pip_c: Color = LxWick.PAL_CREAM if (LxHudFx.flash_reduced() or c_u > 0.5) else LxWick.PAL_GOLD
			draw_arc(center, rad, a0, a0 + span * 0.18 * c_u, 6, pip_c, 1.5, false)

var gliding: bool = false
var glide_dir: Vector2 = Vector2.RIGHT
var glide_speed: float = 120.0
var glide_max_px: float = 96.0
var glide_duration: float = 0.8
var glide_dist_traveled: float = 0.0
var glide_dist_left: float = 0.0
var glide_time_left: float = 0.0
var glides_count: int = 0

var coyote_active: bool = false
var coyote_left: float = 0.0

var _afterimage_cd: float = 0.0
var _sw_cleared_this_glide: bool = false
var _updraft_boost_mult: float = 1.0
var _updraft_boost_t: float = 0.0
var _arc_node: WingsArcOverlay = null


func can_use() -> bool:
	return unlocked and wick != null and not wick.dead and not gliding and not wick.is_zipping()


func is_gliding() -> bool:
	return gliding


func is_in_coyote_grace() -> bool:
	return gliding and coyote_active and coyote_left > 0.0


func has_updraft_boost() -> bool:
	return _updraft_boost_t > 0.0


func get_stamina_ratio() -> float:
	if not gliding or coyote_active:
		return 0.0
	var rt: float = glide_time_left / maxf(glide_duration, 0.01)
	var rd: float = glide_dist_left / maxf(glide_max_px, 1.0)
	return clampf(minf(rt, rd), 0.0, 1.0)


func clears_shockwave() -> bool:
	return gliding and bool(get_data().get("clears_shockwave", true))


func clears_pit() -> bool:
	return gliding and bool(get_data().get("clears_pit", true))


func start_glide(dir: Vector2) -> bool:
	if not can_use():
		return false
	var data: Dictionary = get_data()
	glide_speed = float(data.get("glide_speed", 120.0))
	glide_max_px = Lx.state.get_effective_wings_glide() if Lx.state != null else float(data.get("glide_max_px", 96.0))
	glide_duration = maxf(float(data.get("glide_duration", 0.8)), glide_max_px / maxf(1.0, glide_speed))
	if dir.length_squared() > 0.0001:
		glide_dir = dir.normalized()
	elif wick.facing.length_squared() > 0.0001:
		glide_dir = wick.facing.normalized()
	else:
		glide_dir = Vector2.RIGHT

	gliding = true
	coyote_active = false
	coyote_left = 0.0
	glide_dist_traveled = 0.0
	glide_dist_left = glide_max_px
	glide_time_left = glide_duration
	glides_count += 1
	_afterimage_cd = 0.0
	_sw_cleared_this_glide = false
	_sync_arc_node()

	var isl_w: int = Lx.state.island_id if Lx.state != null else 1
	wick.spawn_ring(wick.global_position, 2.0, 11.0, 0.18, LxBiomePalette.col(isl_w, "glow"), 1.0)
	_gust(44.0, 48.0)
	wick.emit_sfx("wings_glide", wick.global_position, false)
	return true


## Called by updraft_vent toys to refresh glide stamina 100% and grant a temporary tailwind boost.
func refresh_glide(boost_mult: float = 1.25, boost_secs: float = 2.2) -> void:
	if not gliding:
		return
	glide_time_left = glide_duration
	glide_dist_left = glide_max_px
	coyote_active = false
	coyote_left = 0.0
	_updraft_boost_mult = maxf(1.0, boost_mult)
	_updraft_boost_t = maxf(_updraft_boost_t, maxf(0.0, boost_secs))
	_sync_arc_node()


func tick(dt: float) -> void:
	super.tick(dt)
	if _updraft_boost_t > 0.0:
		_updraft_boost_t = maxf(0.0, _updraft_boost_t - dt)
		if _updraft_boost_t <= 0.0:
			_updraft_boost_mult = 1.0
	if _arc_node != null and is_instance_valid(_arc_node):
		_arc_node.visible = gliding
		if gliding:
			_arc_node.queue_redraw()


func on_shockwave_cleared() -> void:
	if wick == null or _sw_cleared_this_glide:
		return
	_sw_cleared_this_glide = true
	var isl_sw: int = Lx.state.island_id if Lx.state != null else 1
	var sw_glow: Color = LxBiomePalette.col(isl_sw, "glow")
	wick.spawn_ring(wick.global_position, 3.0, 15.0, 0.22, LxWick.PAL_SKY, 1.4)
	wick.spawn_ring(wick.global_position, 2.0, 10.0, 0.16, LxWick.PAL_CREAM, 1.0)
	wick.spawn_ring(wick.global_position, 4.0, 20.0, 0.26, sw_glow, 1.0)
	wick.spawn_sparks(wick.global_position, Vector2.UP, 6, LxWick.PAL_ICE, 24.0, 66.0, 0.22)
	wick.spawn_sparks(wick.global_position, -glide_dir, 4, sw_glow, 20.0, 58.0, 0.22)
	_gust(60.0, 68.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(wick.global_position, 64.0, 0.85 if LxHudFx.flash_reduced() else 1.32, 0.24)
		LxDarknessLayer.active_instance.trigger_focus_flash(0.50)
	wick.emit_sfx("prism_bounce", wick.global_position, false)
	if wick.move_sunflare != null and wick.move_sunflare.unlocked:
		var emax: float = wick.move_sunflare.get_ember_max()
		var was_full: bool = wick.ember >= emax - 0.001
		wick.ember = minf(emax, wick.ember + 6.0)
		if not was_full and wick.ember >= emax - 0.001:
			wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
			wick.emit_sfx("beam_ready", wick.global_position, false)


func stop_glide(emit_land: bool = true) -> void:
	if emit_land and gliding and not coyote_active and wick != null and not wick.dead \
			and not wick.is_zipping() and not wick.is_dashing() and wick.bounce_t <= 0.0 \
			and _can_enter_coyote():
		_begin_coyote()
		return
	_finish_glide(emit_land)


func _finish_glide(emit_land: bool) -> void:
	if emit_land and gliding and wick != null and not wick.dead and glide_dist_traveled >= 14.0:
		var isl_l: int = Lx.state.island_id if Lx.state != null else 1
		wick.spawn_ring(wick.global_position, 2.0, 8.0, 0.14, LxWick.PAL_ICE, 1.0)
		wick.spawn_sparks(wick.global_position, -glide_dir, 2, LxWick.PAL_ICE, 12.0, 32.0, 0.18)
		wick.spawn_sparks(wick.global_position, -glide_dir, 2, LxBiomePalette.col(isl_l, "glow"), 14.0, 36.0, 0.20)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			var wdk: int = LxGroundDecals.Kind.RIPPLE if isl_l in [2, 4] else (LxGroundDecals.Kind.BLOSSOM if isl_l == 3 else (LxGroundDecals.Kind.PRISM_STAR if isl_l in [5, 7] else LxGroundDecals.Kind.FOOTSTEP))
			LxGroundDecals.active_instance.add_decal(wdk, wick.global_position + Vector2(0.0, 4.0), 9.0, 3.2)
		wick.emit_sfx("feather_flutter", wick.global_position, false)
	if emit_land and gliding and wick != null and not wick.dead and glide_dist_traveled >= 48.0 and Lx.state != null:
		var on_void: bool = _is_over_lethal_tile()
		if not on_void:
			Lx.state.story_flags["tut_wings_glided"] = true
	gliding = false
	coyote_active = false
	coyote_left = 0.0
	glide_time_left = 0.0
	glide_dist_left = 0.0
	if _arc_node != null and is_instance_valid(_arc_node):
		_arc_node.visible = false
		_arc_node.queue_redraw()


func _begin_coyote() -> void:
	coyote_active = true
	coyote_left = COYOTE_GRACE_S
	glide_time_left = 0.0
	glide_dist_left = 0.0
	_sync_arc_node()


func tick_glide(dt: float, dash_held: bool) -> void:
	if not gliding:
		return
	if wick == null or wick.dead or wick.is_zipping():
		_finish_glide(false)
		return
	if coyote_active:
		var c_steer: Vector2 = wick.get_move_input()
		if c_steer.length_squared() > 0.04:
			glide_dir = glide_dir.lerp(c_steer.normalized(), minf(1.0, dt * 6.0)).normalized()
		coyote_left = maxf(0.0, coyote_left - dt)
		_sync_arc_node()
		if not _is_over_lethal_tile() or coyote_left <= 0.0:
			_finish_glide(true)
		return
	if not dash_held:
		if _can_enter_coyote():
			_begin_coyote()
		else:
			_finish_glide(true)
		return
	var steer: Vector2 = wick.get_move_input()
	if steer.length_squared() > 0.04:
		glide_dir = glide_dir.lerp(steer.normalized(), minf(1.0, dt * 6.0)).normalized()

	var spd_mult: float = _effective_speed_mult()
	var step_d: float = glide_speed * spd_mult * dt
	glide_dist_traveled += step_d
	glide_dist_left = maxf(0.0, glide_dist_left - step_d)
	glide_time_left = maxf(0.0, glide_time_left - dt)
	_sync_arc_node()

	_afterimage_cd -= dt
	if _afterimage_cd <= 0.0:
		_afterimage_cd = 0.06
		var isl_g: int = Lx.state.island_id if Lx.state != null else 1
		wick.spawn_afterimage(LxBiomePalette.col(isl_g, "hi"))
		wick.spawn_sparks(wick.global_position, -glide_dir, 1, LxBiomePalette.col(isl_g, "glow"), 8.0, 22.0, 0.16)
		if isl_g in [2, 4, 7] and Lx.world != null and is_instance_valid(Lx.world):
			var wfx: Variant = Lx.world.get("_water_fx")
			if wfx is Object and is_instance_valid(wfx) and (wfx as Object).has_method("spawn_ripple"):
				(wfx as Object).call("spawn_ripple", wick.global_position + Vector2(0.0, 4.0), "rose" if isl_g == 4 else "ice", 10.0)

	if glide_time_left <= 0.0 or glide_dist_left <= 0.0:
		if _can_enter_coyote():
			_begin_coyote()
		else:
			_finish_glide(true)


func get_glide_velocity() -> Vector2:
	if not gliding:
		return Vector2.ZERO
	return glide_dir * (glide_speed * _effective_speed_mult())


func reset() -> void:
	super.reset()
	_finish_glide(false)
	glide_dist_traveled = 0.0
	glides_count = 0
	_updraft_boost_mult = 1.0
	_updraft_boost_t = 0.0


func _effective_speed_mult() -> float:
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var mult: float = bm.get_glide_speed_mult() if (bm != null and is_instance_valid(bm)) else 1.0
	if _updraft_boost_t > 0.0:
		mult = maxf(mult, _updraft_boost_mult)
	return mult


func _world_ctx_node() -> Node:
	if Lx.world != null and is_instance_valid(Lx.world):
		return Lx.world
	if wick != null and wick._world_ctx != null and is_instance_valid(wick._world_ctx):
		return wick._world_ctx
	return null


func _is_over_lethal_tile() -> bool:
	var ctx: Node = _world_ctx_node()
	if wick == null or ctx == null or not ctx.has_method("is_lethal_void_at"):
		return false
	return bool(ctx.call("is_lethal_void_at", wick.global_position))


## Coyote grace ONLY triggers when Wick is over lethal water/pit AND safe walkable ground lies within 14 px.
func _can_enter_coyote() -> bool:
	if wick == null:
		return false
	var ctx: Node = _world_ctx_node()
	if ctx == null or not ctx.has_method("is_lethal_void_at"):
		return false
	var wp: Vector2 = wick.global_position
	if not bool(ctx.call("is_lethal_void_at", wp)):
		return false
	var fwd: Vector2 = glide_dir.normalized() if glide_dir.length_squared() > 0.001 else Vector2.RIGHT
	var dirs: Array[Vector2] = [fwd, fwd.rotated(0.45), fwd.rotated(-0.45), Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d: Vector2 in dirs:
		for dist: float in [6.0, COYOTE_EDGE_PX]:
			var probe: Vector2 = wp + d * dist
			if bool(ctx.call("is_lethal_void_at", probe)):
				continue
			if ctx.has_method("tile_at") and ctx.has_method("is_solid_tile"):
				var tname: String = str(ctx.call("tile_at", probe))
				if bool(ctx.call("is_solid_tile", tname, false, false)):
					continue
			return true
	return false


func _sync_arc_node() -> void:
	if wick == null or not is_instance_valid(wick):
		return
	if _arc_node == null or not is_instance_valid(_arc_node):
		_arc_node = WingsArcOverlay.new()
		_arc_node.name = "WingsStaminaArc"
		_arc_node.z_index = -1
		_arc_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_arc_node.owner_wings = self
		wick.add_child(_arc_node)
	_arc_node.visible = gliding
	_arc_node.queue_redraw()


func _gust(radius: float, strength: float) -> void:
	if wick != null and Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", wick.global_position, radius, strength)
