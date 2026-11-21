class_name LxMoveBolt
extends LxMove
## Light Bolt: strictly manual aim along wick.facing (ZERO aim assist), disabled when lantern is out.
## Supports Prism mirror bounces via bounces_left hook.

class Bolt:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var prev_pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 330.0
	var dist: float = 0.0
	var max_range: float = 118.0
	var damage: float = 0.35
	var shield_wear: float = 0.25
	var age: float = 0.0
	var bounces_left: int = 0
	var is_prism: bool = false
	var hit_ids: Array[int] = []

var is_held: bool = false


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or wick.is_dashing() or wick.is_zipping():
		return false
	if wick.lantern != null and not wick.lantern.is_in_hand():
		return false
	return true


func press() -> bool:
	is_held = true
	if not can_use():
		return false
	return _fire_bolt()


func release() -> void:
	is_held = false


func tick(dt: float) -> void:
	super.tick(dt)
	if is_held and can_use():
		_fire_bolt()


func reset() -> void:
	super.reset()
	is_held = false


func _get_effective_damage() -> float:
	if Lx.state != null:
		return Lx.state.get_effective_bolt_damage()
	return float(get_data().get("damage", 0.35))


func _get_effective_cooldown() -> float:
	if Lx.state != null:
		return Lx.state.get_effective_bolt_cooldown()
	return float(get_data().get("cooldown", 0.18))


func _get_prism_bounces() -> int:
	if Lx.state != null and Lx.state.has_move("prism"):
		return maxi(1, Lx.state.get_effective_prism_bounces())
	return 0


func _fire_bolt() -> bool:
	var data: Dictionary = get_data()
	var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
	var b := Bolt.new()
	b.dir = aim
	b.pos = wick.global_position + aim * 6.0
	b.prev_pos = b.pos
	b.speed = float(data.get("speed", 330.0))
	b.max_range = float(data.get("range", 118.0))
	b.damage = _get_effective_damage()
	b.shield_wear = float(data.get("shield_wear", 0.25))
	b.bounces_left = _get_prism_bounces()
	b.is_prism = false

	wick.bolts.append(b)
	wick.shots_fired += 1
	cooldown_left = _get_effective_cooldown()

	var recoil: float = float(data.get("recoil", 60.0))
	wick.apply_recoil(-aim * recoil)
	wick.muzzle_t = 0.065
	wick.shoot_anim_t = 0.20
	wick.recoil_vis = 1.0
	wick.spawn_sparks(b.pos, aim, 3, LxWick.PAL_GOLD, 40.0, 95.0, 0.12)
	wick.emit_sfx("bolt_fire", wick.global_position, false)
	return true


func tick_bolts(dt: float, world_ctx: Node) -> void:
	if wick == null or wick.bolts.is_empty():
		return
	var data: Dictionary = get_data()
	var hs_chip: float = float(data.get("hitstop", 0.025))
	var shake_chip: float = float(data.get("shake", 0.03))
	var stagger: bool = bool(data.get("stagger", false))
	var pierce: bool = bool(data.get("pierce", false))
	var prism_data: Dictionary = Lx.get_move_data("prism")
	var prism_mult: float = float(prism_data.get("damage_mult", 1.15))
	var prism_range: float = float(prism_data.get("range_refresh", 118.0))

	var i: int = wick.bolts.size() - 1
	while i >= 0:
		var b: Bolt = wick.bolts[i] as Bolt
		if b == null:
			wick.bolts.remove_at(i)
			i -= 1
			continue

		b.age += dt
		b.prev_pos = b.pos
		var step_dist: float = b.speed * dt
		var nxt: Vector2 = b.pos + b.dir * step_dist
		var dead: bool = false

		# 1. Prism mirror reflection hook (active once Prism is unlocked)
		if b.bounces_left > 0:
			var mhit: Dictionary = wick.world_get_mirror_hit(world_ctx, b.pos, nxt)
			if bool(mhit.get("hit", false)):
				var hit_pos: Vector2 = mhit.get("pos", nxt) as Vector2
				var normal: Vector2 = mhit.get("normal", -b.dir) as Vector2
				if normal.length_squared() > 0.0001:
					b.dir = b.dir.bounce(normal.normalized()).normalized()
				else:
					b.dir = -b.dir
				b.pos = hit_pos + b.dir * 2.0
				b.bounces_left -= 1
				b.is_prism = true
				b.damage *= prism_mult
				b.dist = 0.0
				b.max_range = prism_range
				b.hit_ids.clear()
				wick.spawn_sparks(hit_pos, b.dir, 5, LxWick.PAL_ICE, 35.0, 85.0, 0.16)
				wick.spawn_ring(hit_pos, 2.0, 10.0, 0.18, LxWick.PAL_ICE, 1.0)
				wick.emit_sfx("prism_bounce", hit_pos, true)
				i -= 1
				continue

		# 2. Enemy collision
		var enemies: Array = wick.world_get_enemies(world_ctx)
		for e_var: Variant in enemies:
			if not (e_var is Object):
				continue
			var enemy: Object = e_var as Object
			if not wick.is_entity_alive(enemy):
				continue
			var eid: int = enemy.get_instance_id()
			if b.hit_ids.has(eid):
				continue
			var epos: Vector2 = wick.get_entity_pos(enemy)
			var erad: float = wick.get_entity_radius(enemy, 8.0)
			if Geometry2D.get_closest_point_to_segment(epos, b.pos, nxt).distance_to(epos) <= erad + 2.5:
				b.hit_ids.append(eid)
				var src: String = LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT
				var hit: LxHit = LxHit.make(
					src, b.damage, b.dir, b.pos,
					b.shield_wear, stagger, pierce, wick, false
				)
				var res: int = wick.apply_hit_to_entity(enemy, hit)
				wick.on_hit_landed(hit, res, epos, hs_chip, shake_chip)
				if not pierce:
					dead = true
					break

		# 3. Interactables (switches, eyes, mirrors, braziers)
		var reflected: bool = false
		if not dead:
			var inters: Array = wick.world_get_interactables(world_ctx)
			for it_var: Variant in inters:
				if not (it_var is Object):
					continue
				var item: Object = it_var as Object
				if not is_instance_valid(item):
					continue
				var iid: int = item.get_instance_id()
				if b.hit_ids.has(iid):
					continue
				var ipos: Vector2 = wick.get_entity_pos(item)
				var irad: float = wick.get_entity_radius(item, 8.0)
				if Geometry2D.get_closest_point_to_segment(ipos, b.pos, nxt).distance_to(ipos) <= irad + 2.0:
					if b.bounces_left > 0 and item.has_method("reflect_bolt"):
						var rinfo: Variant = item.call("reflect_bolt", b.pos, b.dir)
						if rinfo is Dictionary and bool((rinfo as Dictionary).get("hit", false)):
							var rd: Dictionary = rinfo as Dictionary
							var rdir: Vector2 = rd.get("dir", -b.dir) as Vector2
							var rpos: Vector2 = rd.get("pos", ipos) as Vector2
							b.dir = rdir.normalized() if rdir.length_squared() > 0.0001 else -b.dir
							b.pos = rpos + b.dir * 2.0
							b.bounces_left -= 1
							b.is_prism = true
							b.damage *= prism_mult
							b.dist = 0.0
							b.max_range = prism_range
							b.hit_ids.clear()
							b.hit_ids.append(iid)
							wick.spawn_sparks(rpos, b.dir, 5, LxWick.PAL_ICE, 35.0, 85.0, 0.16)
							wick.emit_sfx("prism_bounce", rpos, true)
							reflected = true
							break
					if item.has_method("on_hit"):
						b.hit_ids.append(iid)
						var src_i: String = LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT
						var hit_i: LxHit = LxHit.make(src_i, b.damage, b.dir, b.pos, b.shield_wear, false, false, wick, false)
						var consumed: Variant = item.call("on_hit", hit_i)
						if consumed is bool and bool(consumed):
							wick.spawn_sparks(ipos, -b.dir, 4, LxWick.PAL_GOLD, 25.0, 65.0, 0.14)
							dead = true
							break

		# 4. Wall / max range check
		if not dead and not reflected:
			b.dist += step_dist
			var hit_wall: bool = wick.world_shot_blocked(world_ctx, b.pos, nxt)
			if hit_wall or b.dist >= b.max_range:
				wick.spawn_sparks(b.pos, -b.dir, 3, LxWick.PAL_APRICOT, 20.0, 50.0, 0.14)
				if hit_wall:
					wick.emit_sfx("bolt_wall", b.pos, true)
				dead = true
			else:
				b.pos = nxt

		if dead:
			wick.bolts.remove_at(i)
		i -= 1
