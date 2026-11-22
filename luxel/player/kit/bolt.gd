class_name LxMoveBolt
extends LxMove
## Light Bolt: strictly manual aim along wick.facing (ZERO aim assist), disabled when lantern is out.
## Delegates Prism mirror/glass bounces to LxMovePrism (physical reflection only, zero auto-aim).

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
	var bounce_count: int = 0
	var is_prism: bool = false
	var is_counter: bool = false
	var hit_ids: Array[int] = []

var is_held: bool = false


func can_use() -> bool:
	if not super.can_use():
		return false
	if wick.dead or wick.is_dashing() or wick.is_zipping() or wick.is_beam_charging():
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
	if wick != null and wick.move_prism != null:
		return wick.move_prism.get_bounces()
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
	b.bounce_count = 0
	b.is_prism = false
	b.is_counter = false
	if wick.move_dash != null and wick.move_dash.consume_counter():
		b.is_counter = true
		b.damage *= 1.25
		b.shield_wear += 0.15
		wick.spawn_ring(b.pos, 2.0, 11.0, 0.16, LxWick.PAL_CREAM, 1.0)
		wick.spawn_sparks(b.pos, aim, 5, LxWick.PAL_CREAM, 55.0, 115.0, 0.16)

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
	var prism_mult: float = wick.move_prism.get_damage_mult() if wick.move_prism != null else float(Lx.get_move_data("prism").get("damage_mult", 1.15))
	var prism_range: float = wick.move_prism.get_range_refresh() if wick.move_prism != null else float(Lx.get_move_data("prism").get("range_refresh", 118.0))

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
		var reflected: bool = false

		# 1. Enemy collision
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
				if b.is_prism and res > 0:
					wick.spawn_ring(epos, 2.0, 12.0 if b.bounce_count >= 2 else 10.0, 0.16, LxWick.PAL_ICE, 1.0)
					wick.spawn_sparks(epos, b.dir, 7 if b.bounce_count >= 2 else 5, LxWick.PAL_ICE, 32.0, 88.0, 0.18)
				if b.is_counter and res > 0:
					wick.spawn_ring(epos, 2.0, 13.0, 0.18, LxWick.PAL_GOLD, 1.2)
					wick.spawn_sparks(epos, b.dir, 6, LxWick.PAL_CREAM, 40.0, 105.0, 0.20)
					wick.emit_sfx("perfect_counter", epos, true)
					if wick.move_sunflare != null and wick.move_sunflare.unlocked:
						var emax_c: float = wick.move_sunflare.get_ember_max()
						var was_f: bool = wick.ember >= emax_c - 0.001
						wick.ember = minf(emax_c, wick.ember + 12.0)
						if not was_f and wick.ember >= emax_c - 0.001:
							wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
							wick.emit_sfx("beam_ready", wick.global_position, false)
				if not pierce:
					dead = true
					break

		# 2. Interactables (brass LxMirrors, custom reflect_bolt surfaces, switches, eyes, braziers)
		if not dead:
			var inters: Array = wick.world_get_interactables(world_ctx)
			for it_var: Variant in inters:
				if not (it_var is Object):
					continue
				var item: Object = it_var as Object
				if not is_instance_valid(item):
					continue
				if item.get("active") is bool and not bool(item.get("active")):
					continue
				var iid: int = item.get_instance_id()
				if b.hit_ids.has(iid):
					continue
				var ipos: Vector2 = wick.get_entity_pos(item)
				var irad: float = wick.get_entity_radius(item, 8.0)
				if not _bolt_hits_item(b.pos, nxt, item, ipos, irad):
					continue

				if b.bounces_left > 0 and wick.move_prism != null:
					var refl: Dictionary = wick.move_prism.try_reflect_interactable(item, b.pos, nxt, b.dir)
					if bool(refl.get("hit", false)):
						var rpos: Vector2 = refl.get("pos", ipos) as Vector2
						var exit_pos: Vector2 = refl.get("exit_pos", rpos) as Vector2
						var rdir: Vector2 = refl.get("dir", -b.dir) as Vector2
						_apply_prism_bounce(b, rpos, exit_pos, rdir, prism_mult, prism_range, iid)
						if item.has_method("on_hit"):
							var ping: LxHit = LxHit.make(LxHit.SOURCE_PRISM, b.damage, b.dir, rpos, b.shield_wear, false, false, wick, false)
							item.call("on_hit", ping)
						reflected = true
						break

				if item.has_method("on_hit"):
					b.hit_ids.append(iid)
					var src_i: String = LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT
					var hit_i: LxHit = LxHit.make(src_i, b.damage, b.dir, b.pos, b.shield_wear, false, false, wick, false)
					var consumed: Variant = item.call("on_hit", hit_i)
					if consumed is bool and bool(consumed):
						if str(item.get("kind")) == "obsidian_seal" and Lx.state != null and Lx.state.has_move("sunflare"):
							var emax: float = Lx.state.get_effective_ember_max()
							var was_full: bool = wick.ember >= emax - 0.001
							wick.ember = minf(emax, wick.ember + 22.0)
							wick.spawn_sparks(ipos, -b.dir, 6, LxWick.PAL_GOLD, 30.0, 85.0, 0.20)
							if not was_full and wick.ember >= emax - 0.001:
								wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
								wick.emit_sfx("beam_ready", wick.global_position, false)
						else:
							wick.spawn_sparks(ipos, -b.dir, 4, LxWick.PAL_GOLD, 25.0, 65.0, 0.14)
						dead = true
						break

		# 3. World mirror / glass tile reflection (when Prism bounces remain)
		if not dead and not reflected and b.bounces_left > 0 and wick.move_prism != null:
			var wrefl: Dictionary = wick.move_prism.try_reflect_world(world_ctx, b.pos, nxt, b.dir)
			if bool(wrefl.get("hit", false)):
				var wpos: Vector2 = wrefl.get("pos", b.pos) as Vector2
				var wexit: Vector2 = wrefl.get("exit_pos", wpos) as Vector2
				var wdir: Vector2 = wrefl.get("dir", -b.dir) as Vector2
				_apply_prism_bounce(b, wpos, wexit, wdir, prism_mult, prism_range, -1)
				reflected = true

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


func _apply_prism_bounce(
	b: Bolt,
	rpos: Vector2,
	exit_pos: Vector2,
	rdir: Vector2,
	prism_mult: float,
	prism_range: float,
	ignore_id: int
) -> void:
	b.dir = rdir.normalized() if rdir.length_squared() > 0.0001 else -b.dir
	b.prev_pos = rpos
	b.pos = exit_pos
	b.bounces_left -= 1
	b.bounce_count += 1
	b.is_prism = true
	b.damage *= prism_mult
	b.dist = 0.0
	b.max_range = prism_range
	b.hit_ids.clear()
	if ignore_id != -1:
		b.hit_ids.append(ignore_id)
	if wick.move_prism != null:
		wick.move_prism.on_bolt_reflected(rpos, b.dir, b.bounce_count)


func _bolt_hits_item(from_p: Vector2, to_p: Vector2, item: Object, ipos: Vector2, irad: float) -> bool:
	if Geometry2D.get_closest_point_to_segment(ipos, from_p, to_p).distance_to(ipos) <= irad + 2.0:
		return true
	if item.has_method("get_solid_rect"):
		var srect: Rect2 = item.call("get_solid_rect") as Rect2
		if srect.has_area() and (srect.grow(1.5).has_point(to_p) or srect.grow(1.5).has_point(from_p.lerp(to_p, 0.5))):
			return true
	return false
