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
var _afterimage_cd: float = 0.0
var _throw_buf_t: float = 0.0
var _zip_buf_t: float = 0.0
var _world_ctx: Node = null


func set_world_ctx(world_ctx: Node) -> void:
	_world_ctx = world_ctx


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or wick.lantern == null:
		return false
	if wick.lantern.state == LxLantern.State.CARRIED:
		return false
	return true


func press() -> bool:
	if not unlocked:
		if wick != null:
			wick.emit_sfx("denied", wick.global_position, false)
		return false
	if wick == null or wick.dead or wick.lantern == null:
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
		var spd: float = float(data.get("throw_speed", 360.0))
		var rng: float = float(data.get("throw_range", 108.0))
		var hang: float = float(data.get("hang_time", 4.5))
		var rspd: float = float(data.get("recall_speed", 440.0))
		var lure_r: float = float(data.get("lure_radius", 135.0))
		lan.throw_out(wick.global_position, aim, spd, rng, hang, rspd, dmg, dmg, wear, lure_r)
		wick.throw_anim_t = 0.25
		wick.spawn_sparks(wick.global_position, aim, 5, LxWick.PAL_GOLD, 35.0, 85.0, 0.16)
		wick.emit_sfx("lantern_throw", wick.global_position, false)
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
	if not unlocked or wick == null or wick.dead or wick.lantern == null:
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
	if dist <= 6.0:
		_trigger_zip_arrival_burst(_world_ctx)
		lan.catch_by_wick(wick)
		return true

	var data: Dictionary = get_data()
	zip_speed = float(data.get("zip_speed", 520.0))
	zip_dir = to / dist
	zip_time_left = dist / maxf(zip_speed, 1.0)
	zipping = true
	zip_hit_ids.clear()
	_afterimage_cd = 0.0

	# Hold lantern in place during the zip so it cannot auto-recall mid-flight.
	lan.state = LxLantern.State.HANGING
	lan.vel = Vector2.ZERO
	lan.hang_timer = maxf(lan.hang_timer, zip_time_left + 0.5)

	wick.zips_count += 1
	wick.spawn_afterimage(LxWick.PAL_GOLD)
	wick.spawn_ring(wick.global_position, 3.0, 14.0, 0.20, LxWick.PAL_GOLD, 1.0)
	wick.emit_sfx("zip_streak", wick.global_position, false)
	return true


func tick_zip(dt: float, world_ctx: Node) -> void:
	_world_ctx = world_ctx
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
		wick.spawn_afterimage(LxWick.PAL_GOLD)
	wick.spawn_sparks(wick.global_position, -zip_dir, 1, LxWick.PAL_GOLD, 10.0, 28.0, 0.18)

	var data: Dictionary = get_data()
	var zdmg: float = float(data.get("zip_damage", 1.75))
	var wear: float = float(data.get("shield_wear", 2.0))
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.14))

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
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
				return

	if zipping and (zip_time_left <= 0.0 or wick.global_position.distance_to(lan.pos) <= 8.0):
		zipping = false
		zip_time_left = 0.0
		wick.mercy_t = maxf(wick.mercy_t, 0.14)
		_trigger_zip_arrival_burst(world_ctx)
		if lan.state != LxLantern.State.IN_HAND and lan.state != LxLantern.State.CARRIED:
			if wick.global_position.distance_to(lan.pos) <= 18.0:
				lan.catch_by_wick(wick)


func _trigger_zip_arrival_burst(world_ctx: Node) -> void:
	if wick == null or wick.lantern == null:
		return
	var data: Dictionary = get_data()
	var burst_r: float = float(data.get("zip_burst_radius", 24.0))
	var zdmg: float = float(data.get("zip_damage", 1.75))
	var wear: float = float(data.get("shield_wear", 2.0))
	var stag: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.085))
	var sh: float = float(data.get("shake", 0.14))
	var center: Vector2 = wick.lantern.pos

	wick.spawn_ring(center, 3.0, burst_r, 0.22, LxWick.PAL_GOLD, 1.5)
	wick.spawn_sparks(center, zip_dir, 8, LxWick.PAL_CREAM, 30.0, 90.0, 0.20)

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
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


func get_zip_velocity() -> Vector2:
	return zip_dir * zip_speed if zipping else Vector2.ZERO


func cancel_zip() -> void:
	zipping = false
	zip_time_left = 0.0
	zip_hit_ids.clear()


func reset() -> void:
	super.reset()
	_throw_buf_t = 0.0
	_zip_buf_t = 0.0
	cancel_zip()


func _get_effective_throw_damage() -> float:
	if Lx.state != null:
		return Lx.state.get_effective_throw_damage()
	return float(get_data().get("throw_damage", 2.0))
