class_name LxMoveThrow
extends LxMove
## Lantern Throw, Recall, and Light Zip.
## RMB throws along manual wick.facing (heavy hit, LURE anchor); RMB again recalls with 18 px slam;
## LMB while out zips Wick to the lantern with 24 px arrival burst. Disabled while carried by a Snatcher.

const ZIP_BOUNCE_TIME: float = 0.24
const ZIP_BOUNCE_KNOCK: float = 150.0

var zipping: bool = false
var zip_dir: Vector2 = Vector2.RIGHT
var zip_speed: float = 520.0
var zip_time_left: float = 0.0
var zip_hit_ids: Array[int] = []
var _zip_empowered: bool = false
var _afterimage_cd: float = 0.0
var _throw_buf_t: float = 0.0
var _zip_buf_t: float = 0.0
var _world_ctx: Node = null


func set_world_ctx(world_ctx: Node) -> void:
	_world_ctx = world_ctx


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or not wick.has_lantern() or wick.lantern == null:
		return false
	if wick.lantern.state == LxLantern.State.CARRIED:
		return false
	return true


func press() -> bool:
	if wick == null or wick.dead or not wick.has_lantern() or wick.lantern == null:
		return false
	if not unlocked or locked:
		wick.emit_sfx("denied", wick.global_position, false)
		return false

	var lan: LxLantern = wick.lantern
	if lan.state == LxLantern.State.CARRIED:
		wick.emit_sfx("denied", wick.global_position, false)
		return false

	var data: Dictionary = get_data()
	var dmg: float = _get_effective_throw_damage()
	var wear: float = float(data.get("shield_wear", 2.0))

	if lan.state == LxLantern.State.IN_HAND:
		var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var spd: float = _mod_stat("throw_speed", float(data.get("throw_speed", 360.0)))
		var rng: float = _mod_stat("throw_range", float(data.get("throw_range", 108.0)))
		var base_hang: float = Lx.state.get_effective_throw_hang() if Lx.state != null else float(data.get("hang_time", 4.5))
		var hang: float = _mod_stat("hang_time", base_hang)
		var rspd: float = _mod_stat("recall_speed", float(data.get("recall_speed", 440.0)))
		var lure_r: float = Lx.state.get_effective_lure_radius() if Lx.state != null else float(data.get("lure_radius", 135.0))
		var empowered: bool = wick.move_dash != null and wick.move_dash.consume_counter()
		if empowered:
			dmg *= 1.25
		lan.throw_out(wick.global_position, aim, spd, rng, hang, rspd, dmg, dmg, wear, lure_r)
		wick.fired.emit(aim, "throw")
		wick.throw_anim_t = 0.25
		wick.spawn_sparks(wick.global_position, aim, 8 if empowered else 5, LxWick.PAL_CREAM if empowered else LxWick.PAL_GOLD, 35.0, 95.0, 0.18)
		wick.spawn_ring(wick.global_position, 2.0, 14.0 if empowered else 10.0, 0.16, LxWick.PAL_GOLD if empowered else LxWick.PAL_CREAM, 1.2 if empowered else 1.0)
		wick.emit_sfx("lantern_throw", wick.global_position, false)
		if empowered:
			wick.emit_sfx("perfect_counter", wick.global_position, false)
		return true

	if lan.state == LxLantern.State.FLYING or lan.state == LxLantern.State.HANGING:
		var slam_r: float = float(data.get("recall_slam_radius", 18.0))
		var hs: float = float(data.get("hitstop", 0.085))
		var sh: float = float(data.get("shake", 0.14))
		lan.recall_damage = dmg
		lan.shield_wear = wear
		lan.start_recall(wick, _world_ctx, slam_r, hs, sh)
		return true

	if lan.state == LxLantern.State.RECALLING:
		_throw_buf_t = 0.09
		return false

	return false


func try_zip() -> bool:
	if not unlocked or wick == null or wick.dead or not wick.has_lantern() or wick.lantern == null:
		return false
	if locked:
		wick.emit_sfx("denied", wick.global_position, false)
		return false
	var lan: LxLantern = wick.lantern
	if lan.state == LxLantern.State.CARRIED:
		wick.emit_sfx("denied", wick.global_position, false)
		return false
	if lan.state != LxLantern.State.FLYING and lan.state != LxLantern.State.HANGING:
		return false
	if zipping or wick.bounce_t > 0.0:
		return false
	if wick.is_dashing():
		_zip_buf_t = 0.09
		return false

	var to: Vector2 = lan.pos - wick.global_position
	var dist: float = to.length()
	if dist > 4.0 and wick.world_zip_blocked(_world_ctx, wick.global_position, lan.pos):
		wick.emit_sfx("denied", wick.global_position, false)
		return false
	if dist <= 6.0:
		_trigger_zip_arrival_burst(_world_ctx)
		lan.catch_by_wick(wick)
		return true

	var data: Dictionary = get_data()
	zip_speed = float(data.get("zip_speed", 520.0))
	zip_dir = to / dist
	zip_time_left = dist / maxf(zip_speed, 1.0)
	zipping = true
	_zip_empowered = wick.move_dash != null and wick.move_dash.consume_counter()
	zip_hit_ids.clear()
	_afterimage_cd = 0.0

	# Hold lantern in place during the zip so it cannot auto-recall mid-flight.
	lan.state = LxLantern.State.HANGING
	lan.vel = Vector2.ZERO
	lan.hang_timer = maxf(lan.hang_timer, zip_time_left + 0.5)

	wick.zips_count += 1
	wick.spawn_afterimage(LxWick.PAL_CREAM if _zip_empowered else LxWick.PAL_GOLD)
	wick.spawn_ring(wick.global_position, 3.0, 18.0 if _zip_empowered else 14.0, 0.20, LxWick.PAL_CREAM if _zip_empowered else LxWick.PAL_GOLD, 1.4 if _zip_empowered else 1.0)
	wick.emit_sfx("zip_streak", wick.global_position, false)
	if _zip_empowered:
		wick.emit_sfx("perfect_counter", wick.global_position, false)
	var panes_z: LxPanes = LxPanes.current()
	if panes_z != null and not panes_z.equipped_ids().is_empty():
		panes_z.fire_zip({"from_pos": wick.global_position, "to_pos": lan.pos, "phase": "start", "wick": wick, "world": _world_ctx if _world_ctx != null else Lx.world})
	return true


func tick_zip(dt: float, world_ctx: Node) -> void:
	_world_ctx = world_ctx
	if locked:
		_throw_buf_t = 0.0
		_zip_buf_t = 0.0
		if zipping:
			cancel_zip()
		return
	if _throw_buf_t > 0.0:
		_throw_buf_t = maxf(0.0, _throw_buf_t - dt)
		if wick != null and wick.lantern != null and wick.lantern.state == LxLantern.State.IN_HAND:
			_throw_buf_t = 0.0
			press()
	if _zip_buf_t > 0.0:
		_zip_buf_t = maxf(0.0, _zip_buf_t - dt)
		if wick != null and not wick.is_dashing() and not zipping:
			_zip_buf_t = 0.0
			try_zip()
	if not zipping or wick == null or wick.lantern == null:
		return

	var lan: LxLantern = wick.lantern
	if lan.state == LxLantern.State.CARRIED or lan.state == LxLantern.State.IN_HAND:
		zipping = false
		zip_time_left = 0.0
		return

	zip_time_left -= dt
	_afterimage_cd -= dt
	if _afterimage_cd <= 0.0:
		_afterimage_cd = 0.028
		wick.spawn_afterimage(LxWick.PAL_CREAM if _zip_empowered else LxWick.PAL_GOLD)
	wick.spawn_sparks(wick.global_position, -zip_dir, 1, LxWick.PAL_CREAM if _zip_empowered else LxWick.PAL_GOLD, 10.0, 28.0, 0.18)

	var data: Dictionary = get_data()
	var base_zdmg: float = Lx.state.get_effective_zip_damage() if Lx.state != null else float(data.get("zip_damage", 1.75))
	var zdmg: float = base_zdmg * (1.25 if _zip_empowered else 1.0)
	var wear: float = float(data.get("shield_wear", 2.0)) + (0.5 if _zip_empowered else 0.0)
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.14))

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not is_instance_valid(e_var) or not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not wick.is_entity_alive(enemy):
			continue
		var eid: int = enemy.get_instance_id()
		if zip_hit_ids.has(eid):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		var extra: float = 8.5 if wick.is_snatcher_entity(enemy) else 3.5
		if Geometry2D.get_closest_point_to_segment(epos, wick.last_pos, wick.global_position).distance_to(epos) <= erad + extra:
			zip_hit_ids.append(eid)
			var hit: LxHit = LxHit.make(
				LxHit.SOURCE_ZIP, zdmg, zip_dir, wick.global_position - zip_dir * 12.0,
				wear, stag, false, wick, false
			)
			var res: int = wick.apply_hit_to_entity(enemy, hit)
			wick.on_hit_landed(hit, res, epos, hs, sh)
			if res == 0:
				zipping = false
				zip_time_left = 0.0
				wick.bounce_t = ZIP_BOUNCE_TIME
				wick.knock = -zip_dir * ZIP_BOUNCE_KNOCK
				wick.spawn_ring(wick.global_position, 2.0, 13.0, 0.18, LxWick.PAL_STONE, 1.2)
				return

	if wick.global_position.distance_to(lan.pos) > 8.0 and wick.world_zip_blocked(world_ctx, wick.global_position, lan.pos):
		cancel_zip()
		return

	if zipping and (zip_time_left <= 0.0 or wick.global_position.distance_to(lan.pos) <= 8.0):
		var blocked_end: bool = wick.world_zip_blocked(world_ctx, wick.global_position, lan.pos)
		if not blocked_end and wick.global_position.distance_to(lan.pos) <= 18.0:
			wick.global_position = wick.world_collide_step(world_ctx, wick.global_position, lan.pos, LxWick.BODY_RADIUS, true)
		zipping = false
		zip_time_left = 0.0
		wick.mercy_t = maxf(wick.mercy_t, 0.14)
		if not blocked_end:
			_trigger_zip_arrival_burst(world_ctx)
			if lan.state != LxLantern.State.IN_HAND and lan.state != LxLantern.State.CARRIED:
				if wick.global_position.distance_to(lan.pos) <= 18.0:
					lan.catch_by_wick(wick)


func _trigger_zip_arrival_burst(world_ctx: Node) -> void:
	if wick == null or wick.lantern == null:
		return
	var data: Dictionary = get_data()
	var base_br: float = Lx.state.get_effective_zip_radius() if Lx.state != null else float(data.get("zip_burst_radius", 24.0))
	var burst_r: float = base_br * (1.15 if _zip_empowered else 1.0)
	var base_zdmg: float = Lx.state.get_effective_zip_damage() if Lx.state != null else float(data.get("zip_damage", 1.75))
	var zdmg: float = base_zdmg * (1.25 if _zip_empowered else 1.0)
	var wear: float = float(data.get("shield_wear", 2.0)) + (0.5 if _zip_empowered else 0.0)
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.14))
	var center: Vector2 = wick.lantern.pos
	var was_emp: bool = _zip_empowered
	_zip_empowered = false

	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var b_glow: Color = LxBiomePalette.col(isl, "glow")
	wick.spawn_ring(center, 3.0, burst_r, 0.22, LxWick.PAL_CREAM if was_emp else LxWick.PAL_GOLD, 1.8 if was_emp else 1.5)
	wick.spawn_ring(center, 5.0, burst_r + 6.0, 0.26, b_glow, 1.0)
	wick.spawn_sparks(center, zip_dir, 11 if was_emp else 8, LxWick.PAL_CREAM, 30.0, 95.0, 0.20)
	wick.spawn_sparks(center, -zip_dir, 5, b_glow, 24.0, 74.0, 0.22)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		var dk: int = LxGroundDecals.Kind.PRISM_STAR if isl in [2, 5, 7] else (LxGroundDecals.Kind.BLOSSOM if isl in [3, 4] else LxGroundDecals.Kind.SCORCH)
		LxGroundDecals.active_instance.add_decal(dk, center + Vector2(0.0, 3.0), 10.0, 5.0)
	if isl in [2, 4] and world_ctx != null and is_instance_valid(world_ctx):
		var wfx: Variant = world_ctx.get("_water_fx")
		if is_instance_valid(wfx) and wfx is Object and (wfx as Object).has_method("spawn_ripple"):
			(wfx as Object).call("spawn_ripple", center, "ice" if isl == 2 else "rose", 14.0)
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", zip_dir, 2.2 if was_emp else 1.6)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var z_sc: float = 0.65 if LxHudFx.flash_reduced() else 1.0
		LxDarknessLayer.active_instance.add_burst_light(center, 78.0 if was_emp else 64.0, (1.48 if was_emp else 1.28) * z_sc, 0.30)
	if world_ctx != null and is_instance_valid(world_ctx):
		var amb: Variant = world_ctx.get("_ambient_life")
		if is_instance_valid(amb) and amb is Object and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", center, burst_r * 2.2, 85.0)
	if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
		LxBiomeMechanics.active_instance.try_hit_biome_target(center - zip_dir * burst_r, center + zip_dir * burst_r, zip_dir, wick)
	var panes_za: LxPanes = LxPanes.current()
	if panes_za != null and not panes_za.equipped_ids().is_empty():
		panes_za.fire_zip({"from_pos": wick.global_position, "to_pos": center, "phase": "arrival", "wick": wick, "world": world_ctx if world_ctx != null else Lx.world})

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not is_instance_valid(e_var) or not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not wick.is_entity_alive(enemy):
			continue
		var eid: int = enemy.get_instance_id()
		if zip_hit_ids.has(eid):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		if epos.distance_to(center) <= burst_r:
			zip_hit_ids.append(eid)
			var kdir: Vector2 = (epos - center).normalized() if epos.distance_to(center) > 0.1 else zip_dir
			var hit: LxHit = LxHit.make(
				LxHit.SOURCE_ZIP, zdmg, kdir, center,
				wear, stag, false, wick, false
			)
			var res: int = wick.apply_hit_to_entity(enemy, hit)
			wick.on_hit_landed(hit, res, epos, hs, sh)

	var inters: Array = wick.world_get_interactables(world_ctx)
	for it_var: Variant in inters:
		if not is_instance_valid(it_var) or not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if not item.has_method("on_hit"):
			continue
		if item.get("active") is bool and not bool(item.get("active")):
			continue
		var iid: int = item.get_instance_id()
		if zip_hit_ids.has(iid):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 8.0)
		if ipos.distance_to(center) <= burst_r + irad:
			zip_hit_ids.append(iid)
			var idir: Vector2 = (ipos - center).normalized() if ipos.distance_to(center) > 0.1 else zip_dir
			var hit_i: LxHit = LxHit.make(
				LxHit.SOURCE_ZIP, zdmg, idir, center,
				wear, stag, false, wick, false
			)
			if item.has_method("on_lantern_pull"):
				item.call("on_lantern_pull", -zip_dir, "zip")
			var consumed: Variant = item.call("on_hit", hit_i)
			if consumed is bool and bool(consumed):
				if str(item.get("kind")) == "obsidian_seal" and Lx.state != null and Lx.state.has_move("sunflare"):
					var emax: float = Lx.state.get_effective_ember_max()
					var was_full: bool = wick.ember >= emax - 0.001
					wick.ember = minf(emax, wick.ember + 22.0)
					if not was_full and wick.ember >= emax - 0.001:
						wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
						wick.emit_sfx("beam_ready", wick.global_position, false)
				wick.spawn_sparks(ipos, idir, 6, LxWick.PAL_GOLD, 28.0, 82.0, 0.20)


func is_active() -> bool:
	return zipping


func get_zip_velocity() -> Vector2:
	return zip_dir * zip_speed if zipping else Vector2.ZERO


func cancel_zip() -> void:
	zipping = false
	_zip_empowered = false
	zip_time_left = 0.0
	zip_hit_ids.clear()


func reset() -> void:
	super.reset()
	_throw_buf_t = 0.0
	_zip_buf_t = 0.0
	cancel_zip()


func _mod_stat(stat_name: String, base_val: float) -> float:
	var panes: LxPanes = LxPanes.current()
	if panes != null and not panes.equipped_ids().is_empty():
		return panes.modify_stat(stat_name, base_val, {"wick": wick})
	return base_val


func _get_effective_throw_damage() -> float:
	var base: float = Lx.state.get_effective_throw_damage() if Lx.state != null else float(get_data().get("throw_damage", 2.0))
	return _mod_stat("throw_damage", base)
