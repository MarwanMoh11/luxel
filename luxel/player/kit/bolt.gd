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
	var skim_dist: float = 0.0
	var max_range: float = 118.0
	var damage: float = 0.35
	var shield_wear: float = 0.25
	var age: float = 0.0
	var bounces_left: int = 0
	var bounce_count: int = 0
	var is_prism: bool = false
	var is_split_shard: bool = false
	var light_color: String = LxHit.COLOR_YELLOW
	var is_counter: bool = false
	var is_pierce: bool = false
	var cracks_armour: bool = false
	var biome_tint: String = ""
	var temper: String = ""
	var wall_bounces_left: int = 0
	var wall_bounced: bool = false
	var enemy_bounces_left: int = 1
	var base_speed: float = 330.0
	var curve_angle_deg: float = 0.0
	var hit_ids: Array[int] = []

const MAX_BOLTS: int = 64

var is_held: bool = false


func can_use() -> bool:
	if not super.can_use() or not wick.has_lantern(): return false
	if wick.dead or wick.is_dashing() or wick.is_zipping() or wick.is_beam_charging() or wick.is_grabbing(): return false
	return wick.lantern == null or wick.lantern.is_in_hand()

func press() -> bool:
	is_held = true
	return _fire_bolt() if can_use() else false

func release() -> void: is_held = false

func tick(dt: float) -> void:
	super.tick(dt)
	if is_held and can_use(): _fire_bolt()

func reset() -> void:
	super.reset(); is_held = false; _sync_saved_temper()

func _sync_saved_temper() -> void:
	if wick == null: return
	var saved_t: String = ""
	if Lx.state != null: saved_t = str(Lx.state.story_flags.get("wick_temper", "")).strip_edges().to_lower()
	elif Lx.vars != null: saved_t = str(Lx.vars.get_var("game", "wick_temper", "")).strip_edges().to_lower()
	wick.temper = saved_t if saved_t in ["skip", "scatter", "lance"] else ""

func _push_bolt(b: Bolt) -> void:
	if wick.bolts.size() >= MAX_BOLTS: wick.bolts.remove_at(0)
	wick.bolts.append(b)


func _mod_stat(stat_name: String, base_val: float) -> float:
	var panes: LxPanes = LxPanes.current()
	if panes != null and not panes.equipped_ids().is_empty():
		return panes.modify_stat(stat_name, base_val, {"wick": wick})
	return base_val


func _get_effective_damage() -> float:
	var base: float = Lx.state.get_effective_bolt_damage() if Lx.state != null else float(get_data().get("damage", 0.35))
	return _mod_stat("bolt_damage", base)


func _get_effective_cooldown() -> float:
	var base: float = Lx.state.get_effective_bolt_cooldown() if Lx.state != null else float(get_data().get("cooldown", 0.18))
	return _mod_stat("bolt_cooldown", base)


func _get_prism_bounces() -> int:
	if wick != null and wick.move_prism != null:
		return wick.move_prism.get_bounces()
	if Lx.state != null and Lx.state.get_upgrade_rank("prism_bounce") > 0:
		return 3
	return 2


func _fire_bolt() -> bool:
	var data: Dictionary = get_data()
	var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
	var b := Bolt.new()
	b.dir = aim
	b.pos = wick.global_position + aim * 6.0
	b.prev_pos = b.pos
	b.speed = _mod_stat("bolt_speed", float(data.get("speed", 330.0)))
	if LxBiomeRules.active_instance != null and LxBiomeRules.active_instance.starlight_surge_t > 0.0:
		b.speed *= 1.18
	b.max_range = _mod_stat("bolt_range", float(data.get("range", 118.0)))
	b.damage = _get_effective_damage()
	b.shield_wear = float(data.get("shield_wear", 0.25))
	b.bounces_left = _get_prism_bounces()
	b.bounce_count = 0
	b.is_prism = false
	b.is_counter = false
	b.temper = wick.temper
	var temper_cd_mult: float = 1.0
	var temper_recoil_mult: float = 1.0
	if b.temper == "scatter":
		b.max_range *= 0.58
		b.damage *= 0.55
		temper_cd_mult = 1.18
		temper_recoil_mult = 1.35
	elif b.temper == "lance":
		b.speed *= 0.68
		b.max_range *= 1.35
		b.damage *= 1.85
		b.shield_wear *= 2.2
		b.is_pierce = true
		b.cracks_armour = true
		b.biome_tint = "coral"
		temper_cd_mult = 1.65
		temper_recoil_mult = 1.45
	elif b.temper == "skip":
		b.speed *= 1.08
		b.wall_bounces_left = 1
		b.biome_tint = "gold"
	b.base_speed = b.speed
	if wick.move_dash != null and wick.move_dash.consume_counter():
		b.is_counter = true
		b.damage *= 1.25
		b.shield_wear += 0.15
		if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
			Lx.camera.call("add_kick", -aim, 1.3)
		wick.spawn_ring(b.pos, 2.0, 11.0, 0.16, LxWick.PAL_CREAM, 1.0)
		wick.spawn_sparks(b.pos, aim, 5, LxWick.PAL_CREAM, 55.0, 115.0, 0.16)
	var br: LxBiomeRules = LxBiomeRules.active_instance
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	if br != null and is_instance_valid(br):
		if br.island_id == 2 and br.beam_buff_t > 0.0:
			b.damage *= 1.25
			b.is_counter = true
			b.biome_tint = "ice"
		elif br.island_id == 5 and br.starlight_surge_t > 0.0:
			b.biome_tint = "sky"
		elif br.island_id == 7 and br.lunar_phase > 0.65:
			b.damage *= 1.20
			b.biome_tint = "ice"
		elif br.island_id == 8 and bm != null and is_instance_valid(bm) and bm.dawn_seals_broken > 0:
			b.biome_tint = "gold" if bm.dawn_seals_broken >= 3 else "rose"
	if bm != null and is_instance_valid(bm) and bm.consume_molten_charge():
		b.damage *= 1.35
		b.is_pierce = true
		b.is_counter = true
		b.biome_tint = "coral"
		wick.spawn_sparks(b.pos, aim, 5, LxWick.PAL_CORAL, 55.0, 120.0, 0.18)

	_push_bolt(b)
	var panes_f: LxPanes = LxPanes.current()
	if panes_f != null and not panes_f.equipped_ids().is_empty():
		panes_f.fire_bolt_fired({
			"bolt": b,
			"pos": b.pos,
			"dir": b.dir,
			"wick": wick,
			"world": wick._world_ctx if wick._world_ctx != null else Lx.world,
		})
		b.base_speed = b.speed
	if b.temper == "scatter":
		for sdeg: float in [-14.0, 14.0]:
			var sb_t := Bolt.new()
			sb_t.dir = aim.rotated(deg_to_rad(sdeg)).normalized()
			sb_t.pos = wick.global_position + sb_t.dir * 6.0
			sb_t.prev_pos = sb_t.pos
			sb_t.speed = b.speed
			sb_t.base_speed = b.base_speed
			sb_t.max_range = b.max_range
			sb_t.damage = b.damage
			sb_t.shield_wear = b.shield_wear
			sb_t.bounces_left = b.bounces_left
			sb_t.is_counter = b.is_counter
			sb_t.is_pierce = b.is_pierce
			sb_t.cracks_armour = b.cracks_armour
			sb_t.biome_tint = b.biome_tint
			sb_t.temper = "scatter"
			_push_bolt(sb_t)
	# Island 7 Full Silver Moon: Radiant Mirror Echo fires a synced parallel twin-bolt (zero aim assist)
	if bm != null and is_instance_valid(bm) and bm.mirror_echo_active:
		var eb := Bolt.new()
		eb.dir = aim
		eb.biome_tint = "ice"
		eb.pos = bm.mirror_echo_pos + aim * 4.0
		eb.prev_pos = eb.pos
		eb.speed = b.speed
		eb.base_speed = b.speed
		eb.max_range = b.max_range
		eb.damage = b.damage * 0.55
		eb.shield_wear = b.shield_wear * 0.6
		eb.bounces_left = 0
		eb.is_prism = true
		eb.light_color = LxHit.COLOR_BLUE
		_push_bolt(eb)
		wick.spawn_sparks(eb.pos, aim, 3, LxWick.PAL_ICE, 35.0, 85.0, 0.14)
	wick.shots_fired += 1
	var cd_scale: float = bm.get_fire_rate_mult() if (bm != null and is_instance_valid(bm)) else (0.82 if (br != null and is_instance_valid(br) and br.starlight_surge_t > 0.0) else 1.0)
	cooldown_left = _get_effective_cooldown() * cd_scale * temper_cd_mult

	var recoil: float = _mod_stat("recoil", float(data.get("recoil", 60.0))) * temper_recoil_mult
	wick.apply_recoil(-aim * recoil)
	wick.fired.emit(aim, "bolt")
	wick.muzzle_t = 0.065
	wick.shoot_anim_t = 0.20
	wick.recoil_vis = 1.0
	var muzzle_col: Color = LxWick.PAL_CORAL if b.temper == "lance" else (LxWick.PAL_APRICOT if b.temper == "scatter" else LxWick.PAL_GOLD)
	wick.spawn_sparks(b.pos, aim, 3 if b.temper == "scatter" else 2, muzzle_col, 40.0, 95.0, 0.12)
	var isl_spark: int = Lx.state.island_id if Lx.state != null else 1
	wick.spawn_sparks(b.pos, aim, 1, LxBiomePalette.col(isl_spark, "glow"), 34.0, 82.0, 0.14)
	if not LxHudFx.flash_reduced() and LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(b.pos, 32.0, 0.72, 0.10)
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
	var enemies: Array = wick.world_get_enemies(world_ctx)
	var inters: Array = wick.world_get_interactables(world_ctx)
	var props_v: Variant = world_ctx.get("_scenery_props") if (world_ctx != null and is_instance_valid(world_ctx)) else null
	var has_fields: bool = LxFields.has_fields()

	var i: int = wick.bolts.size() - 1
	while i >= 0:
		var b: Bolt = wick.bolts[i] as Bolt
		if b == null:
			wick.bolts.remove_at(i); i -= 1; continue

		b.age += dt
		b.prev_pos = b.pos
		if has_fields:
			var fa: Vector2 = LxFields.accel_at(b.pos, "bolt")
			if fa.length_squared() > 0.01:
				var old_dir: Vector2 = b.dir
				var bv: Vector2 = b.dir * b.speed + fa * dt
				if bv.length_squared() > 1.0:
					b.dir = bv.normalized()
					b.curve_angle_deg += rad_to_deg(absf(old_dir.angle_to(b.dir)))
					b.speed = clampf(bv.length(), b.base_speed * 0.72, b.base_speed * 1.40)
		var step_dist: float = b.speed * dt
		var nxt: Vector2 = b.pos + b.dir * step_dist
		var dead: bool = false
		var reflected: bool = false

		# 1. Enemy collision
		for e_var: Variant in enemies:
			if not is_instance_valid(e_var) or not (e_var is Object):
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
				var enemy_refl: bool = enemy.has_method("is_reflective") and bool(enemy.call("is_reflective")) and enemy.has_method("reflect_dir")
				var src: String = LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT
				var dmg_f: float = b.damage
				var bm_h: LxBiomeMechanics = LxBiomeMechanics.active_instance
				if bm_h != null and is_instance_valid(bm_h) and bm_h.is_in_lighthouse_beam(epos):
					dmg_f *= 1.25
				var hit: LxHit = LxHit.make(
					src, dmg_f, b.dir, b.pos,
					b.shield_wear, stagger, pierce or b.is_pierce, wick, b.cracks_armour, b.light_color, b.curve_angle_deg
				)
				hit.set_meta("temper", b.temper)
				hit.set_meta("wall_bounced", b.wall_bounced)
				hit.set_meta("bounces", b.bounce_count)
				var res: int = wick.apply_hit_to_entity(enemy, hit)
				wick.on_hit_landed(hit, res, epos, hs_chip, shake_chip)
				if (b.is_prism or b.is_counter) and res > 0 and LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					var bi_p: float = 0.88 if LxHudFx.flash_reduced() else 1.38
					LxDarknessLayer.active_instance.add_burst_light(epos, 58.0 if (b.is_counter or b.bounce_count >= 2) else 48.0, bi_p, 0.22)
				if b.is_prism and res > 0:
					wick.spawn_ring(epos, 2.0, 12.0 if b.bounce_count >= 2 else 10.0, 0.16, LxWick.PAL_ICE, 1.0)
					wick.spawn_sparks(epos, b.dir, 7 if b.bounce_count >= 2 else 5, LxWick.PAL_ICE, 32.0, 88.0, 0.18)
				if not b.biome_tint.is_empty() and res > 0:
					wick.spawn_sparks(epos, -b.dir, 3, LxPalette.color(b.biome_tint, "gold"), 28.0, 74.0, 0.16)
				if b.is_counter and res > 0:
					wick.spawn_ring(epos, 2.0, 13.0, 0.18, LxWick.PAL_GOLD, 1.2)
					wick.spawn_sparks(epos, b.dir, 6, LxWick.PAL_CREAM, 40.0, 105.0, 0.20)
					if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
						LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, epos + Vector2(0.0, 2.0), 9.5, 4.0)
					wick.emit_sfx("perfect_counter", epos, true)
					if wick.move_sunflare != null and wick.move_sunflare.unlocked:
						var emax_c: float = wick.move_sunflare.get_ember_max()
						var was_f: bool = wick.ember >= emax_c - 0.001
						wick.ember = minf(emax_c, wick.ember + 12.0)
						if not was_f and wick.ember >= emax_c - 0.001:
							wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
							wick.emit_sfx("beam_ready", wick.global_position, false)
				if enemy_refl and b.enemy_bounces_left > 0 and _try_enemy_ricochet(b, enemy, epos, erad, nxt, eid, prism_range):
					reflected = true
					break
				if not (pierce or b.is_pierce):
					dead = true
					break

		# 1b. Interactive Biome Targets (Island 3 Bloom-Lamp chain waves, Island 5 Starfall Nova Crystals)
		if not dead:
			var bm_t: LxBiomeMechanics = LxBiomeMechanics.active_instance
			if bm_t != null and is_instance_valid(bm_t) and bm_t.try_hit_biome_target(b.pos, nxt, b.dir, wick):
				dead = true

		# 2. Interactables (brass LxMirrors, custom reflect_bolt surfaces, switches, eyes, braziers)
		if not dead:
			for it_var: Variant in inters:
				if not is_instance_valid(it_var) or not (it_var is Object): continue
				var item: Object = it_var as Object
				if item is LxInteractable:
					if not (item as LxInteractable).active: continue
				elif item.get("active") is bool and not bool(item.get("active")): continue
				var iid: int = item.get_instance_id()
				if b.hit_ids.has(iid): continue
				var ipos: Vector2 = (item as LxInteractable).pos if item is LxInteractable else wick.get_entity_pos(item)
				var irad: float = (item as LxInteractable).radius if item is LxInteractable else wick.get_entity_radius(item, 8.0)
				if not _bolt_hits_item(b.pos, nxt, item, ipos, irad): continue

				if b.bounces_left > 0 and wick.move_prism != null:
					var refl: Dictionary = wick.move_prism.try_reflect_interactable(item, b.pos, nxt, b.dir)
					if bool(refl.get("hit", false)):
						var rpos: Vector2 = refl.get("pos", ipos) as Vector2
						var exit_pos: Vector2 = refl.get("exit_pos", rpos) as Vector2
						var rdir: Vector2 = refl.get("dir", -b.dir) as Vector2
						var t_col: String = str(item.call("get_transform_color")) if item.has_method("get_transform_color") else LxHit.COLOR_BLUE
						if t_col.is_empty():
							t_col = LxHit.COLOR_BLUE
						_apply_prism_bounce(b, rpos, exit_pos, rdir, prism_mult, prism_range, iid, t_col)
						if item.has_method("on_hit"):
							var ping: LxHit = LxHit.make(LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT, b.damage, b.dir, rpos, b.shield_wear, false, false, wick, false, b.light_color, b.curve_angle_deg)
							item.call("on_hit", ping)
						reflected = true
						break

				if item.has_method("on_hit"):
					b.hit_ids.append(iid)
					var src_i: String = LxHit.SOURCE_PRISM if b.is_prism else LxHit.SOURCE_BOLT
					var hit_i: LxHit = LxHit.make(src_i, b.damage, b.dir, b.pos, b.shield_wear, false, b.is_pierce, wick, b.cracks_armour, b.light_color, b.curve_angle_deg)
					hit_i.set_meta("temper", b.temper)
					hit_i.set_meta("wall_bounced", b.wall_bounced)
					hit_i.set_meta("bounces", b.bounce_count)
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
							var sp_col: Color = LxWick.PAL_ICE if (b.is_prism or b.light_color == LxHit.COLOR_BLUE) else LxWick.PAL_GOLD
							wick.spawn_sparks(ipos, -b.dir, 4, sp_col, 25.0, 65.0, 0.14)
						var solid_stop: bool = item.has_method("is_solid") and bool(item.call("is_solid"))
						if not (pierce or b.is_pierce) or solid_stop:
							dead = true
							break

		# 3. World mirror / glass tile reflection (when Prism bounces remain)
		if not dead and not reflected and b.bounces_left > 0 and wick.move_prism != null:
			var wrefl: Dictionary = wick.move_prism.try_reflect_world(world_ctx, b.pos, nxt, b.dir)
			if bool(wrefl.get("hit", false)):
				var wpos: Vector2 = wrefl.get("pos", b.pos) as Vector2
				var wexit: Vector2 = wrefl.get("exit_pos", wpos) as Vector2
				var wdir: Vector2 = wrefl.get("dir", -b.dir) as Vector2
				_apply_prism_bounce(b, wpos, wexit, wdir, prism_mult, prism_range, -1, LxHit.COLOR_BLUE)
				reflected = true

		# 3b. Scenery prop grazing (once per bolt per prop)
		if not dead and not reflected and props_v is Array:
			var bx0: float = minf(b.pos.x, nxt.x) - 14.0; var bx1: float = maxf(b.pos.x, nxt.x) + 14.0
			var by0: float = minf(b.pos.y, nxt.y) - 14.0; var by1: float = maxf(b.pos.y, nxt.y) + 14.0
			for pv: Variant in (props_v as Array):
				if not is_instance_valid(pv) or not (pv is LxSceneryProp): continue
				var sp: LxSceneryProp = pv as LxSceneryProp
				if sp.position.x < bx0 or sp.position.x > bx1 or sp.position.y < by0 or sp.position.y > by1: continue
				var pid: int = sp.get_instance_id()
				if b.hit_ids.has(pid): continue
				var cp: Vector2 = Geometry2D.get_closest_point_to_segment(sp.position, b.pos, nxt)
				if cp.distance_squared_to(sp.position) <= 169.0:
					b.hit_ids.append(pid)
					sp.on_bolt_graze(cp, b.dir, b.is_prism or b.light_color == LxHit.COLOR_BLUE)

		# 4. Wall / max range check (with Skip temper wall ricochet)
		if not dead and not reflected:
			b.dist += step_dist
			var hit_wall: bool = wick.world_shot_blocked(world_ctx, b.pos, nxt)
			if hit_wall and b.wall_bounces_left > 0:
				var wn: Vector2 = _estimate_wall_normal(world_ctx, b.pos, nxt, b.dir)
				b.dir = b.dir.bounce(wn).normalized()
				b.wall_bounces_left -= 1
				b.wall_bounced = true
				b.bounce_count += 1
				var nudged: Vector2 = b.pos + b.dir * 2.0
				if not wick.world_shot_blocked(world_ctx, b.pos, nudged):
					b.pos = nudged
				b.max_range = maxf(b.max_range, b.dist + 72.0)
				b.hit_ids.clear()
				wick.spawn_ring(b.pos, 1.5, 7.0, 0.14, LxWick.PAL_GOLD, 1.2)
				wick.spawn_sparks(b.pos, b.dir, 4, LxWick.PAL_CREAM, 28.0, 72.0, 0.14)
				wick.emit_sfx("prism_bounce", b.pos, true)
			elif hit_wall or b.dist >= b.max_range:
				var isl_w: int = Lx.state.island_id if Lx.state != null else 1
				var wcol: Color = LxWick.PAL_ICE if b.is_prism else (LxPalette.color(b.biome_tint, "apricot") if not b.biome_tint.is_empty() else LxBiomePalette.col(isl_w, "glow"))
				wick.spawn_sparks(b.pos, -b.dir, 3, wcol, 20.0, 52.0, 0.14)
				if hit_wall:
					wick.spawn_ring(b.pos, 1.5, 5.5, 0.12, wcol, 1.0)
					if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
						LxGroundDecals.active_instance.add_dir_decal(LxGroundDecals.Kind.WALL_SCUFF, b.pos, b.dir, 3.0, 1.8, b.is_prism or b.light_color == LxHit.COLOR_BLUE)
					wick.emit_sfx("bolt_wall", b.pos, true)
				dead = true
			else:
				if b.is_prism and b.bounce_count >= 1 and b.age < 0.14 and wick._fx != null:
					wick._fx._spawn_streak(b.pos, nxt, 0.09, LxWick.PAL_SKY if b.is_split_shard else LxWick.PAL_ICE, 1.5)
					wick._fx._spawn_mote(nxt, Vector2.ZERO, 0.045, LxWick.PAL_CREAM, 2.0, false, 0.5, true, 0.96)
				b.pos = nxt
				b.skim_dist += step_dist
				if b.skim_dist >= 18.0:
					b.skim_dist = fmod(b.skim_dist, 18.0)
					if LxWaterFx.active_instance != null and is_instance_valid(LxWaterFx.active_instance):
						LxWaterFx.active_instance.on_bolt_skim(b.pos, b.dir, b.is_prism or b.light_color == LxHit.COLOR_BLUE)

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
	ignore_id: int,
	transform_color: String = LxHit.COLOR_BLUE
) -> void:
	b.dir = rdir.normalized() if rdir.length_squared() > 0.0001 else -b.dir
	b.prev_pos = rpos
	b.pos = exit_pos
	b.bounces_left -= 1
	b.bounce_count += 1
	b.light_color = transform_color
	b.is_prism = (transform_color == LxHit.COLOR_BLUE)
	if wick.move_prism != null and wick.move_prism.should_crack_armour(b.bounce_count):
		b.cracks_armour = true
		b.is_pierce = true
	b.age = 0.0
	b.damage *= prism_mult
	b.dist = 0.0
	b.skim_dist = 0.0
	b.max_range = prism_range
	b.hit_ids.clear()
	if ignore_id != -1:
		b.hit_ids.append(ignore_id)
	if wick.move_prism != null:
		wick.move_prism.on_bolt_reflected(rpos, b.dir, b.bounce_count, b.light_color)
	# Prism Split: primary bolt's 1st reflection spawns 2 flanking shards (bounded max 3 bolts, never re-splits)
	if wick.move_prism != null and wick.move_prism.has_split() and not b.is_split_shard and b.bounce_count == 1:
		var split_rad: float = deg_to_rad(wick.move_prism.SPLIT_ANGLE_DEG)
		var split_dmg: float = b.damage * wick.move_prism.SPLIT_DMG_MULT
		for sign_a: float in [-1.0, 1.0]:
			var sb := Bolt.new()
			sb.dir = b.dir.rotated(sign_a * split_rad).normalized()
			sb.prev_pos = rpos
			sb.pos = exit_pos
			sb.speed = b.speed
			sb.dist = 0.0
			sb.max_range = prism_range * 0.92
			sb.damage = split_dmg
			sb.shield_wear = b.shield_wear
			sb.age = 0.0
			sb.bounces_left = 1
			sb.bounce_count = 1
			sb.is_prism = true
			sb.is_split_shard = true
			sb.light_color = transform_color
			sb.is_counter = b.is_counter
			sb.is_pierce = b.is_pierce
			sb.cracks_armour = true
			sb.biome_tint = b.biome_tint
			if ignore_id != -1:
				sb.hit_ids.append(ignore_id)
			_push_bolt(sb)
		wick.trigger_hitstop(0.028)
		if Lx.camera != null and is_instance_valid(Lx.camera):
			Lx.camera.add_kick(b.dir, 1.6)
		wick.move_prism.spawn_split_wedge(rpos, b.dir)
		wick.spawn_sparks(rpos, b.dir, 6, LxWick.PAL_SKY, 42.0, 108.0, 0.20)
		wick.spawn_sparks(rpos, b.dir, 4, LxWick.PAL_CREAM, 55.0, 118.0, 0.16)
		wick.emit_sfx("prism_chain", rpos, true)


func _bolt_hits_item(from_p: Vector2, to_p: Vector2, item: Object, ipos: Vector2, irad: float) -> bool:
	var rpad: float = irad + 2.0
	if Geometry2D.get_closest_point_to_segment(ipos, from_p, to_p).distance_squared_to(ipos) <= rpad * rpad:
		return true
	if item is LxInteractable:
		var it: LxInteractable = item as LxInteractable
		if not it.is_solid(): return false
		var srect: Rect2 = it.get_solid_rect()
		if srect.size.x > 0.0 and srect.size.y > 0.0:
			var g: Rect2 = srect.grow(1.5)
			if g.has_point(to_p) or g.has_point(from_p.lerp(to_p, 0.5)): return true
		return false
	if item.has_method("get_solid_rect"):
		var srect2: Rect2 = item.call("get_solid_rect") as Rect2
		if srect2.has_area():
			var g2: Rect2 = srect2.grow(1.5)
			if g2.has_point(to_p) or g2.has_point(from_p.lerp(to_p, 0.5)): return true
	return false


func _try_enemy_ricochet(b: Bolt, enemy: Object, epos: Vector2, erad: float, nxt: Vector2, eid: int, prism_range: float) -> bool:
	var rdir_v: Variant = enemy.call("reflect_dir", b.dir)
	if not (rdir_v is Vector2) or (rdir_v as Vector2).length_squared() <= 0.0001:
		return false
	var rdir: Vector2 = (rdir_v as Vector2).normalized()
	var hit_pt: Vector2 = Geometry2D.get_closest_point_to_segment(epos, b.pos, nxt)
	b.dir = rdir
	b.prev_pos = hit_pt
	b.pos = hit_pt + rdir * maxf(2.5, erad * 0.4)
	b.enemy_bounces_left -= 1
	b.bounce_count += 1
	b.dist = 0.0
	b.skim_dist = 0.0
	b.max_range = maxf(b.max_range, prism_range)
	b.hit_ids.clear()
	b.hit_ids.append(eid)
	var t_col: String = ""
	if enemy.has_method("get_transform_color"):
		t_col = str(enemy.call("get_transform_color")).strip_edges().to_lower()
	elif enemy.get("transforms_to") is String:
		t_col = str(enemy.get("transforms_to")).strip_edges().to_lower()
	elif enemy.has_method("converts_to_blue") and bool(enemy.call("converts_to_blue")):
		t_col = LxHit.COLOR_BLUE
	if t_col == LxHit.COLOR_BLUE:
		b.light_color = LxHit.COLOR_BLUE
		b.is_prism = true
		if wick.move_prism != null and wick.move_prism.should_crack_armour(b.bounce_count):
			b.cracks_armour = true
	var is_b: bool = b.light_color == LxHit.COLOR_BLUE
	wick.spawn_sparks(hit_pt, rdir, 5, LxWick.PAL_ICE if is_b else LxWick.PAL_GOLD, 34.0, 90.0, 0.16)
	wick.spawn_ring(hit_pt, 2.0, 10.0, 0.16, LxWick.PAL_ICE if is_b else LxWick.PAL_CREAM, 1.1)
	wick.emit_sfx("prism_bounce", hit_pt, true)
	return true


func _estimate_wall_normal(world_ctx: Node, from_p: Vector2, to_p: Vector2, dir: Vector2) -> Vector2:
	var blk_x: bool = wick.world_shot_blocked(world_ctx, from_p, Vector2(to_p.x, from_p.y))
	var blk_y: bool = wick.world_shot_blocked(world_ctx, from_p, Vector2(from_p.x, to_p.y))
	if blk_x and not blk_y:
		return Vector2(-signf(dir.x) if absf(dir.x) > 0.01 else -1.0, 0.0)
	if blk_y and not blk_x:
		return Vector2(0.0, -signf(dir.y) if absf(dir.y) > 0.01 else -1.0)
	return -dir.normalized()
