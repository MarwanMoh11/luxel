class_name LxLantern
extends Node2D
## Wick's lantern entity: IN_HAND, FLYING, HANGING (LURE anchor), RECALLING, CARRIED (stolen by Snatcher).
## Renders in the 20-colour Last Light palette with smooth glow and zip guide line when out.

enum State { IN_HAND, FLYING, HANGING, RECALLING, CARRIED }

const PAL_NIGHT: Color = Color("211a3b")
const PAL_DUSK: Color = Color("3d2c5c")
const PAL_CORAL: Color = Color("e2725b")
const PAL_APRICOT: Color = Color("f5a96a")
const PAL_GOLD: Color = Color("ffd98c")
const PAL_CREAM: Color = Color("fff4dc")

var state: State = State.IN_HAND
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var dist_traveled: float = 0.0
var max_range: float = 108.0
var hang_timer: float = 0.0
var hang_max: float = 4.5
var throw_speed: float = 360.0
var recall_speed: float = 440.0
var throw_damage: float = 2.0
var recall_damage: float = 2.0
var shield_wear: float = 2.0
var lure_radius: float = 135.0
var harmless_recall: bool = false

var carrier: Object = null
var hit_ids: Array[int] = []

var _owner_wick: LxWick = null
var _anim_t: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 2


func setup(p_wick: LxWick) -> void:
	_owner_wick = p_wick
	reset_to_hand(p_wick.global_position if p_wick != null else Vector2.ZERO)


func reset_to_hand(at_pos: Vector2) -> void:
	state = State.IN_HAND
	pos = at_pos
	prev_pos = at_pos
	global_position = at_pos.round()
	vel = Vector2.ZERO
	dist_traveled = 0.0
	hang_timer = 0.0
	harmless_recall = false
	carrier = null
	hit_ids.clear()
	queue_redraw()


func is_in_hand() -> bool:
	return state == State.IN_HAND


func is_hanging() -> bool:
	return state == State.HANGING


func is_out() -> bool:
	return state != State.IN_HAND


func is_lure_active() -> bool:
	return state == State.FLYING or state == State.HANGING


func get_light_radius() -> float:
	if _owner_wick != null and _owner_wick.move_lens != null and _owner_wick.move_lens.unlocked:
		return _owner_wick.move_lens.get_reveal_radius()
	var has_lens: bool = Lx.state != null and Lx.state.has_move("lens")
	if has_lens:
		var ldata: Dictionary = Lx.get_move_data("lens")
		if state == State.IN_HAND:
			return float(ldata.get("hand_radius", 68.0))
		if state == State.CARRIED:
			return 44.0
		return float(ldata.get("hung_radius", 118.0))
	match state:
		State.IN_HAND:
			return 96.0
		State.CARRIED:
			return 48.0
		_:
			return 82.0


func throw_out(
	from_pos: Vector2,
	p_dir: Vector2,
	p_speed: float,
	p_range: float,
	p_hang: float,
	p_recall_speed: float,
	p_throw_dmg: float,
	p_recall_dmg: float,
	p_wear: float,
	p_lure_r: float
) -> void:
	state = State.FLYING
	pos = from_pos
	prev_pos = from_pos
	global_position = from_pos.round()
	dir = p_dir.normalized() if p_dir.length_squared() > 0.0001 else Vector2.RIGHT
	throw_speed = p_speed
	vel = dir * throw_speed
	dist_traveled = 0.0
	max_range = p_range
	hang_max = p_hang
	hang_timer = p_hang
	recall_speed = p_recall_speed
	throw_damage = p_throw_dmg
	recall_damage = p_recall_dmg
	shield_wear = p_wear
	lure_radius = p_lure_r
	harmless_recall = false
	carrier = null
	hit_ids.clear()
	if Lx.events != null:
		Lx.events.lantern_thrown.emit(pos, dir)
	queue_redraw()


func start_recall(wick: LxWick, world_ctx: Node, slam_radius: float = 18.0, hs: float = 0.085, sh: float = 0.14) -> void:
	if state != State.FLYING and state != State.HANGING:
		return
	state = State.RECALLING
	harmless_recall = false
	hit_ids.clear()
	if Lx.events != null:
		Lx.events.lantern_recalled.emit(pos)
	if wick != null:
		wick.emit_sfx("lantern_recall", pos, true)
		wick.spawn_ring(pos, 2.0, slam_radius, 0.20, PAL_GOLD, 1.0)
		_emit_gust(pos, 52.0, 68.0)
		_burst_light(pos, 56.0, 1.20, 0.22)
		# Immediate 18 px recall-on-grab slam (catches diving/wrestling Snatchers and nearby foes)
		var enemies: Array = wick.world_get_enemies(world_ctx)
		for e_var: Variant in enemies:
			if not (e_var is Object):
				continue
			var enemy: Object = e_var as Object
			if not wick.is_entity_alive(enemy):
				continue
			var epos: Vector2 = wick.get_entity_pos(enemy)
			if epos.distance_to(pos) <= slam_radius:
				var eid: int = enemy.get_instance_id()
				hit_ids.append(eid)
				var kdir: Vector2 = (epos - pos).normalized() if epos.distance_to(pos) > 0.1 else (wick.global_position - pos).normalized()
				var hit: LxHit = LxHit.make(
					LxHit.SOURCE_RECALL, recall_damage, kdir, pos,
					shield_wear, true, false, wick, false
				)
				var res: int = wick.apply_hit_to_entity(enemy, hit)
				wick.on_hit_landed(hit, res, epos, hs, sh)


func catch_by_wick(wick: LxWick) -> void:
	state = State.IN_HAND
	vel = Vector2.ZERO
	carrier = null
	harmless_recall = false
	hit_ids.clear()
	if wick != null:
		pos = wick.global_position
		prev_pos = pos
		global_position = pos.round()
		wick.catch_anim_t = 0.22
		var isl_c: int = Lx.state.island_id if Lx.state != null else 1
		var c_gl: Color = LxBiomePalette.col(isl_c, "glow")
		wick.spawn_ring(pos, 2.0, 9.0, 0.16, PAL_CREAM, 1.0)
		wick.spawn_ring(pos, 3.0, 12.0, 0.19, c_gl, 1.0)
		wick.spawn_sparks(pos, Vector2.UP, 4, PAL_CREAM, 14.0, 42.0, 0.18)
		wick.spawn_sparks(pos, Vector2.UP, 3, c_gl, 18.0, 48.0, 0.20)
		_emit_gust(pos, 32.0, 38.0)
		wick.emit_sfx("lantern_catch", pos, false)
	if Lx.events != null:
		Lx.events.lantern_caught.emit(pos)
	queue_redraw()


func on_grabbed(thief: Object) -> void:
	state = State.CARRIED
	carrier = thief
	vel = Vector2.ZERO
	hit_ids.clear()
	if thief != null and is_instance_valid(thief):
		if _owner_wick != null:
			pos = _owner_wick.get_entity_pos(thief)
		elif thief is Node2D:
			pos = (thief as Node2D).global_position
		else:
			var pv: Variant = thief.get("pos")
			if pv is Vector2:
				pos = pv as Vector2
		global_position = pos.round()
	if _owner_wick != null:
		_owner_wick.spawn_ring(pos, 2.0, 18.0, 0.28, PAL_CORAL, 1.5)
		_owner_wick.spawn_sparks(pos, Vector2.UP, 8, PAL_GOLD, 25.0, 85.0, 0.24)
		_owner_wick.emit_sfx("magpie_grab", pos, true)
	if Lx.events != null:
		Lx.events.lantern_stolen.emit(thief, pos)
	queue_redraw()


func on_dropped(at_pos: Vector2) -> void:
	carrier = null
	state = State.HANGING
	pos = at_pos
	prev_pos = at_pos
	global_position = at_pos.round()
	vel = Vector2.ZERO
	var tdata: Dictionary = Lx.get_move_data("throw")
	hang_max = float(tdata.get("hang_time", 4.5))
	hang_timer = hang_max
	harmless_recall = false
	hit_ids.clear()
	if _owner_wick != null:
		var isl_dr: int = Lx.state.island_id if Lx.state != null else 1
		_owner_wick.spawn_ring(pos, 3.0, 22.0, 0.30, PAL_GOLD, 2.0)
		_owner_wick.spawn_ring(pos, 5.0, 28.0, 0.34, LxBiomePalette.col(isl_dr, "glow"), 1.0)
		_owner_wick.spawn_sparks(pos, Vector2.UP, 12, PAL_GOLD, 30.0, 95.0, 0.28)
		_owner_wick.trigger_hitstop(0.085)
		_owner_wick.trigger_shake(0.12)
		_emit_gust(pos, 56.0, 72.0)
		_burst_light(pos, 68.0, 1.38, 0.30)
		_owner_wick.emit_sfx("magpie_drop", pos, true)
	if Lx.events != null:
		Lx.events.lantern_dropped.emit(pos)
	queue_redraw()


func on_perched_loss() -> void:
	if state != State.CARRIED:
		return
	carrier = null
	state = State.RECALLING
	harmless_recall = true
	hit_ids.clear()
	if Lx.events != null:
		Lx.events.lantern_perched_loss.emit(pos)
	if _owner_wick != null:
		_owner_wick.emit_sfx("magpie_perch_loss", pos, false)
		_owner_wick.on_lantern_lost(pos, "perched_loss")
	queue_redraw()


func on_struck() -> void:
	if state != State.FLYING and state != State.HANGING:
		return
	state = State.RECALLING
	harmless_recall = true
	hit_ids.clear()
	if Lx.events != null:
		Lx.events.lantern_struck.emit(pos)
	if _owner_wick != null:
		_owner_wick.on_lantern_lost(pos, "struck")
	queue_redraw()


func tick_sim(dt: float, wick: LxWick, world_ctx: Node) -> void:
	_owner_wick = wick
	_anim_t += dt
	prev_pos = pos
	if wick == null:
		return

	match state:
		State.IN_HAND:
			pos = wick.global_position
			vel = Vector2.ZERO
		State.FLYING:
			var step_d: float = throw_speed * dt
			var nxt: Vector2 = pos + dir * step_d
			if wick.world_shot_blocked(world_ctx, pos, nxt):
				_land_hanging(wick)
			else:
				pos = nxt
				vel = dir * throw_speed
				dist_traveled += step_d
				_sweep_hits(wick, world_ctx, dir, LxHit.SOURCE_THROW, throw_damage)
				if state == State.FLYING and dist_traveled >= max_range:
					_land_hanging(wick)
		State.HANGING:
			vel = Vector2.ZERO
			hang_timer -= dt
			if hang_timer < hang_max - 0.15 and not wick.is_zipping() and wick.global_position.distance_to(pos) <= 8.0:
				catch_by_wick(wick)
			elif hang_timer <= 0.0:
				state = State.RECALLING
				harmless_recall = false
				hit_ids.clear()
				if Lx.events != null:
					Lx.events.lantern_recalled.emit(pos)
				wick.emit_sfx("lantern_recall", pos, true)
		State.RECALLING:
			var to_w: Vector2 = wick.global_position - pos
			var dlen: float = to_w.length()
			if dlen <= 6.0:
				catch_by_wick(wick)
			else:
				var rdir: Vector2 = to_w / dlen
				var step: float = minf(recall_speed * dt, dlen)
				pos += rdir * step
				vel = rdir * recall_speed
				if not harmless_recall:
					_sweep_hits(wick, world_ctx, rdir, LxHit.SOURCE_RECALL, recall_damage)
		State.CARRIED:
			vel = Vector2.ZERO
			if carrier != null and is_instance_valid(carrier) and wick.is_entity_alive(carrier):
				pos = wick.get_entity_pos(carrier)
			else:
				carrier = null
				state = State.RECALLING
				harmless_recall = false
				hit_ids.clear()

	global_position = pos.round()

	# Notify nearby interactables of lantern light (braziers, Lens phantom reveals).
	if is_out():
		var isl_s: int = Lx.state.island_id if Lx.state != null else 1
		wick.spawn_sparks(pos, Vector2.UP, 1, LxBiomePalette.col(isl_s, "hi"), 4.0, 14.0, 0.16)
	_notify_light(wick, world_ctx)
	queue_redraw()


func _land_hanging(wick: LxWick) -> void:
	state = State.HANGING
	vel = Vector2.ZERO
	hang_timer = hang_max
	if Lx.events != null:
		Lx.events.lantern_hung.emit(pos)
	var isl_l: int = Lx.state.island_id if Lx.state != null else 1
	wick.spawn_ring(pos, 2.0, 12.0, 0.22, LxBiomePalette.col(isl_l, "glow"), 1.0)
	_emit_gust(pos, 44.0, 56.0)
	_burst_light(pos, 52.0, 1.12, 0.20)
	wick.emit_sfx("lantern_land", pos, true)


func _burst_light(at_pos: Vector2, rad: float, intensity: float, dur: float) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var eff_i: float = intensity * (0.62 if LxHudFx.flash_reduced() else 1.0)
		LxDarknessLayer.active_instance.add_burst_light(at_pos, rad, eff_i, dur)


func _emit_gust(at_pos: Vector2, rad: float, strength: float) -> void:
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", at_pos, rad, strength)


func _sweep_hits(wick: LxWick, world_ctx: Node, move_dir: Vector2, hit_source: String, dmg: float) -> void:
	var tdata: Dictionary = Lx.get_move_data("throw")
	var hs: float = float(tdata.get("hitstop", 0.085))
	var sh: float = float(tdata.get("shake", 0.14))

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
		var pad: float = 8.0 if (state == State.RECALLING and wick.is_snatcher_entity(enemy)) else 3.5
		if Geometry2D.get_closest_point_to_segment(epos, prev_pos, pos).distance_to(epos) > erad + pad:
			continue

		hit_ids.append(eid)
		if state == State.FLYING and enemy.has_method("try_catch_lantern"):
			if bool(enemy.call("try_catch_lantern", self)):
				return

		var hit: LxHit = LxHit.make(
			hit_source, dmg, move_dir, epos - move_dir * 10.0,
			shield_wear, true, false, wick, false
		)
		var res: int = wick.apply_hit_to_entity(enemy, hit)
		wick.on_hit_landed(hit, res, epos, hs, sh)
		if res == 0 and state == State.FLYING:
			var back: Vector2 = pos - move_dir * 6.0
			if not wick.world_shot_blocked(world_ctx, pos, back):
				pos = back
			wick.spawn_ring(pos, 2.0, 12.0, 0.18, LxWick.PAL_STONE, 1.2)
			state = State.HANGING
			vel = Vector2.ZERO
			hang_max = 0.6
			hang_timer = 0.6
			return

	# Biome mechanics, overworld setpieces, micro-discoveries, dungeon twists & boss/mini-boss sanctum features
	if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
		LxBiomeMechanics.active_instance.try_hit_biome_target(prev_pos, pos, move_dir, wick)

	# Interactables (distant braziers, switches, bells)
	var inters: Array = wick.world_get_interactables(world_ctx)
	for it_var: Variant in inters:
		if not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if not is_instance_valid(item) or not item.has_method("on_hit"):
			continue
		var iid: int = item.get_instance_id()
		if hit_ids.has(iid):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 8.0)
		if Geometry2D.get_closest_point_to_segment(ipos, prev_pos, pos).distance_to(ipos) <= irad + 3.5:
			hit_ids.append(iid)
			var hit_i: LxHit = LxHit.make(hit_source, dmg, move_dir, pos, shield_wear, true, false, wick, false)
			var consumed: Variant = item.call("on_hit", hit_i)
			if consumed is bool and bool(consumed) and str(item.get("kind")) == "obsidian_seal" and Lx.state != null and Lx.state.has_move("sunflare"):
				var emax: float = Lx.state.get_effective_ember_max()
				var was_full: bool = wick.ember >= emax - 0.001
				wick.ember = minf(emax, wick.ember + 22.0)
				if not was_full and wick.ember >= emax - 0.001:
					wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, PAL_GOLD, 1.5)
					wick.emit_sfx("beam_ready", wick.global_position, false)
				wick.spawn_sparks(ipos, -move_dir, 6, PAL_GOLD, 30.0, 85.0, 0.20)


func _notify_light(wick: LxWick, world_ctx: Node) -> void:
	var rad: float = get_light_radius()
	var src_tag: String = "lantern_hung" if is_lure_active() else "lantern_hand"
	var inters: Array = wick.world_get_interactables(world_ctx)
	for it_var: Variant in inters:
		if not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if not is_instance_valid(item) or not item.has_method("on_light"):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 0.0)
		if ipos.distance_to(pos) <= rad + irad:
			item.call("on_light", rad, src_tag)

	var enemies: Array = wick.world_get_enemies(world_ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not is_instance_valid(enemy) or not enemy.has_method("on_light"):
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		if epos.distance_to(pos) <= rad + erad:
			var arity: int = wick.get_method_arity(enemy, "on_light")
			if arity >= 3:
				enemy.call("on_light", rad, pos, src_tag)
			elif arity == 2:
				enemy.call("on_light", rad, src_tag)
			else:
				enemy.call("on_light", rad)


func _draw() -> void:
	if state == State.IN_HAND:
		return
	var flash_red: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var pulse: float = (0.95 + 0.04 * sin(_anim_t * 5.0)) if flash_red else (0.90 + 0.10 * sin(_anim_t * 7.5))
	var bob_y: float = roundf(sin(_anim_t * 5.0) * 1.5) if state == State.HANGING else 0.0
	var center := Vector2(0.0, -5.0 + bob_y)

	# Soft ground contact shadow oval below the hovering/flying lantern
	if state != State.CARRIED:
		var sh_c := Vector2(0.0, 2.0)
		var sh_col := Color(LxWick.PAL_VOID, 0.34 - maxf(0.0, -bob_y) * 0.04)
		draw_rect(Rect2(sh_c + Vector2(-2.0, -1.0), Vector2(4.0, 1.0)), sh_col)
		draw_rect(Rect2(sh_c + Vector2(-3.0, 0.0), Vector2(6.0, 1.0)), sh_col)
		draw_rect(Rect2(sh_c + Vector2(-2.0, 1.0), Vector2(4.0, 1.0)), sh_col)

	# Luminous golden thread of gliding lantern beads from Wick when zippable/recalling (urgent coral when stolen)
	if (is_lure_active() or state == State.CARRIED or state == State.RECALLING) and _owner_wick != null and is_instance_valid(_owner_wick):
		var rel_wick: Vector2 = (_owner_wick.global_position - global_position).round()
		var t_a: Vector2 = center if state == State.RECALLING else rel_wick + Vector2(0.0, -5.0)
		var t_b: Vector2 = rel_wick + Vector2(0.0, -5.0) if state == State.RECALLING else center
		_draw_lantern_tether(t_a, t_b, flash_red, state == State.CARRIED)

	var isl_id: int = Lx.state.island_id if Lx.state != null else 1
	var glow_col: Color = PAL_CORAL if state == State.CARRIED else LxBiomePalette.col(isl_id, "glow")
	var hi_col: Color = PAL_CORAL if state == State.CARRIED else LxBiomePalette.col(isl_id, "hi")
	var glow_sc: float = 0.78 if flash_red else 1.0
	draw_circle(center, 15.0 * pulse, Color(glow_col, 0.13 * glow_sc))
	draw_circle(center, 9.0 * pulse, Color(hi_col, 0.16 * glow_sc))
	if (state == State.FLYING or state == State.RECALLING) and vel.length_squared() > 400.0:
		var v_ang: float = (-vel).angle()
		draw_arc(center, 8.5, v_ang - 0.85, v_ang + 0.85, 10, Color(glow_col, 0.62 * glow_sc), 1.3)
		draw_arc(center, 11.0, v_ang - 0.55, v_ang + 0.55, 8, Color(PAL_CREAM, 0.46 * glow_sc), 1.0)

	# Hang timer arc (shifts coral in final 1.1s before auto-recall) + 2 orbiting rising candlelight motes
	if state == State.HANGING and hang_max > 0.05:
		var frac: float = clampf(hang_timer / hang_max, 0.0, 1.0)
		var urgent_arc: bool = hang_timer <= 1.1 and (flash_red or fmod(_anim_t * 6.0, 1.0) < 0.6)
		draw_arc(center, 7.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, Color(PAL_CORAL if urgent_arc else PAL_GOLD, 0.85 if urgent_arc else 0.72), 1.2 if urgent_arc else 1.0)
		for mi: int in range(2):
			var m_ph: float = fmod(_anim_t * 0.72 + float(mi) * 0.5, 1.0)
			var m_ang: float = _anim_t * 1.85 + float(mi) * PI
			var m_pos: Vector2 = (center + Vector2(cos(m_ang) * 9.0, 2.0 - m_ph * 11.0)).round()
			var m_col: Color = PAL_CREAM if mi == 0 else glow_col
			draw_rect(Rect2(m_pos, Vector2(1.0, 1.0)), Color(m_col, sin(m_ph * PI) * (0.65 if flash_red else 0.90)))
		if Lx.state != null and Lx.state.has_move("lens"):
			var l_spin: float = _anim_t * (0.55 if flash_red else 1.25)
			for li: int in range(6):
				var la: float = l_spin + float(li) * (TAU / 6.0)
				var lp: Vector2 = (center + Vector2(cos(la) * 11.5, sin(la) * 11.5)).round()
				draw_rect(Rect2(lp, Vector2(1.0, 1.0)), LxPalette.PAL["ice" if li % 2 == 0 else "sky"])
	if state == State.HANGING or state == State.FLYING:
		LxWickEvolution.draw_lantern_constellation(self, center, _anim_t, flash_red)

	# Sculpted miniature Last Light Brass Lantern (curved bail, iron hood, 4 brass struts, flame, finial)
	draw_rect(Rect2(center + Vector2(-1.0, -7.0), Vector2(2.0, 1.0)), PAL_GOLD)
	draw_rect(Rect2(center + Vector2(-2.0, -6.0), Vector2(1.0, 1.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(1.0, -6.0), Vector2(1.0, 1.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(-2.0, -5.0), Vector2(4.0, 1.0)), PAL_NIGHT)
	draw_rect(Rect2(center + Vector2(-1.0, -5.0), Vector2(2.0, 1.0)), PAL_DUSK)
	draw_rect(Rect2(center + Vector2(-4.0, -4.0), Vector2(8.0, 1.0)), PAL_NIGHT)
	draw_rect(Rect2(center + Vector2(-3.0, -4.0), Vector2(6.0, 1.0)), PAL_DUSK)
	draw_rect(Rect2(center + Vector2(-4.0, -3.0), Vector2(8.0, 6.0)), PAL_NIGHT)
	draw_rect(Rect2(center + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), PAL_GOLD)
	var sway_x: float = 0.0 if flash_red else roundf(sin(_anim_t * 6.5) * 0.65)
	draw_rect(Rect2(center + Vector2(-1.0 + sway_x, -1.0), Vector2(2.0, 2.0)), PAL_CREAM)
	draw_rect(Rect2(center + Vector2(sway_x, -2.0), Vector2(1.0, 1.0)), Color(PAL_CREAM, 0.84))
	# Four thin vertical brass cage struts (outer rim + inner mullions)
	draw_rect(Rect2(center + Vector2(-4.0, -2.0), Vector2(1.0, 4.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(3.0, -2.0), Vector2(1.0, 4.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(-4.0, -1.0), Vector2(1.0, 2.0)), PAL_GOLD)
	draw_rect(Rect2(center + Vector2(3.0, -1.0), Vector2(1.0, 2.0)), PAL_GOLD)
	draw_rect(Rect2(center + Vector2(-2.0, -3.0), Vector2(1.0, 6.0)), Color(PAL_CORAL, 0.54))
	draw_rect(Rect2(center + Vector2(1.0, -3.0), Vector2(1.0, 6.0)), Color(PAL_CORAL, 0.54))
	# Base plinth + tiny brass finial
	draw_rect(Rect2(center + Vector2(-3.0, 3.0), Vector2(6.0, 1.0)), PAL_NIGHT)
	draw_rect(Rect2(center + Vector2(-2.0, 3.0), Vector2(4.0, 1.0)), PAL_DUSK)
	draw_rect(Rect2(center + Vector2(-1.0, 4.0), Vector2(2.0, 1.0)), PAL_APRICOT)
	draw_rect(Rect2(center + Vector2(0.0, 4.0), Vector2(1.0, 1.0)), PAL_GOLD)


func _draw_lantern_tether(a: Vector2, b: Vector2, flash_red: bool, stolen: bool = false) -> void:
	var delta: Vector2 = b - a
	var total: float = delta.length()
	if total <= 2.0:
		return
	var step_dir: Vector2 = delta / total
	var isl_t: int = Lx.state.island_id if Lx.state != null else 1
	var line_c: Color = PAL_CORAL if stolen else LxBiomePalette.col(isl_t, "hi")
	var bead_c: Color = PAL_CORAL if stolen else LxBiomePalette.col(isl_t, "glow")
	var hi_c: Color = PAL_APRICOT if stolen else LxBiomePalette.col(isl_t, "core")
	draw_line(a, b, Color(line_c, 0.30 if stolen else 0.22), 1.0)
	var cursor: float = fmod(_anim_t * (20.0 if (stolen and not flash_red) else (14.0 if flash_red else 24.0)), 7.0)
	var idx: int = 0
	while cursor < total:
		var edge: float = clampf(minf(cursor, total - cursor) / 9.0, 0.28, 1.0)
		var bp: Vector2 = (a + step_dir * cursor).round()
		draw_rect(Rect2(bp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(bead_c, (0.55 if stolen else 0.42) * edge))
		draw_rect(Rect2(bp, Vector2(1.0, 1.0)), Color(hi_c if (idx % 2 == 0) else bead_c, 0.90 * edge))
		cursor += 7.0
		idx += 1
