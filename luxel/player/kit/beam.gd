class_name LxMoveBeam
extends LxMove
## Beam (Island 3): hold lx_beam (F / X) for charge_time (0.6 s) while standing still with lantern
## IN_HAND, then release to fire ONE instant piercing polyline shot along manual wick.facing (ZERO aim assist).
## Stopped by solid "wall" tiles; pierces enemies, shields, brambles, webs, and cracked walls.
## Refracts off Blue Transformers (LxMirror) and glass/mirror tiles up to move_prism.get_bounces(),
## transforming remaining segments into a vivid Blue Piercing Beam (light_color = COLOR_BLUE).

const BEAM_VIS_DURATION: float = 0.24
const RAY_STEP_PX: float = 2.0

var charging: bool = false
var charge_t: float = 0.0
var charge_time: float = 0.6

var beam_vis_t: float = 0.0
var beam_vis_max: float = BEAM_VIS_DURATION
var beam_start: Vector2 = Vector2.ZERO
var beam_end: Vector2 = Vector2.ZERO
var beam_segments: Array[Dictionary] = [] # [{start, end, dir, color, bounce}]
var beam_width: float = 6.0
var beams_fired: int = 0

var _world_ctx: Node = null
var _charge_spark_cd: float = 0.0
var _buffer_t: float = 0.0
var _held: bool = false
var _vis_clock: float = 0.0


func set_world_ctx(world_ctx: Node) -> void: _world_ctx = world_ctx
func is_charging() -> bool: return charging
func press() -> bool: return press_beam()
func release() -> void: release_beam()

func can_use() -> bool:
	if not super.can_use(): return false
	if wick.dead or wick.is_dashing() or wick.is_gliding() or wick.is_zipping() or wick.bounce_t > 0.0: return false
	if wick.lantern != null and not wick.lantern.is_in_hand(): return false
	return true

func charge_progress() -> float:
	return clampf(charge_t / maxf(charge_time, 0.01), 0.0, 1.0) if charging else 0.0


func press_beam() -> bool:
	_held = true
	if charging:
		return true
	if not can_use():
		var can_buf: bool = unlocked and wick != null and not wick.dead and (
			wick.is_dashing() or wick.is_gliding() or wick.is_zipping() or cooldown_left > 0.0
			or (wick.lantern != null and wick.lantern.state == LxLantern.State.RECALLING)
		)
		if can_buf:
			_buffer_t = 0.12
			return false
		if wick != null and (not unlocked or (wick.lantern != null and not wick.lantern.is_in_hand())):
			wick.emit_sfx("denied", wick.global_position, false)
		return false
	_buffer_t = 0.0
	var data: Dictionary = get_data()
	charge_time = maxf(0.05, Lx.state.get_effective_beam_charge() if Lx.state != null else float(data.get("charge_time", 0.6)))
	charging = true
	charge_t = 0.0
	_charge_spark_cd = 0.0
	wick.emit_sfx("beam_charge", wick.global_position, false)
	return true


func release_beam() -> bool:
	_held = false
	_buffer_t = 0.0
	if not charging:
		return false
	var held_t: float = charge_t
	var ready: bool = charge_t >= charge_time - 0.001
	charging = false
	charge_t = 0.0
	if Lx.input != null:
		Lx.input.clear_toggle("lx_beam")
	if ready:
		return fire_instant_beam(_world_ctx)
	if held_t >= 0.15 and wick != null:
		wick.spawn_sparks(wick.global_position, wick.facing, 3, LxWick.PAL_APRICOT, 16.0, 42.0, 0.16)
		wick.emit_sfx("bolt_wall", wick.global_position, false)
	return false


func fire_instant_beam(world_ctx: Node = null) -> bool:
	if wick == null or wick.dead or not unlocked:
		return false
	if wick.lantern != null and not wick.lantern.is_in_hand():
		cancel()
		return false
	charging = false
	charge_t = 0.0
	if Lx.input != null:
		Lx.input.clear_toggle("lx_beam")

	var ctx: Node = world_ctx if world_ctx != null else (_world_ctx if _world_ctx != null else Lx.world)
	var data: Dictionary = get_data()
	var max_range: float = float(data.get("range", 220.0))
	var width_px: float = float(data.get("width", 6.0))
	var half_w: float = width_px * 0.5
	var dmg: float = float(data.get("damage", 2.5))
	var wear: float = float(data.get("shield_wear", 3.0))
	var empowered: bool = wick.move_dash != null and wick.move_dash.consume_counter()
	if empowered:
		dmg *= 1.25
		wear += 1.0
	var br_b: LxBiomeRules = LxBiomeRules.active_instance
	if br_b != null and is_instance_valid(br_b) and br_b.island_id == 2 and br_b.beam_buff_t > 0.0:
		dmg *= 1.20
		empowered = true
	var pierce: bool = bool(data.get("pierce", true))
	var stagger: bool = bool(data.get("stagger", true))
	var hs: float = float(data.get("hitstop", 0.095))
	var sh: float = float(data.get("shake", 0.16))
	var max_bounces: int = wick.move_prism.get_bounces() if wick.move_prism != null else 2
	var prism_mult: float = wick.move_prism.get_damage_mult() if wick.move_prism != null else 1.15

	# Strictly manual aim along wick.facing (ZERO aim assist)
	var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
	var start_p: Vector2 = wick.global_position
	var reflections: Array[Dictionary] = []
	var segs: Array[Dictionary] = _trace_beam_segments(ctx, start_p, aim, max_range, max_bounces, reflections)
	if segs.is_empty():
		segs.append({"start": start_p, "end": start_p + aim * max_range, "dir": aim, "color": LxHit.COLOR_YELLOW, "bounce": 0, "curve_angle_deg": 0.0})
	var end_p: Vector2 = segs[segs.size() - 1]["end"] as Vector2
	var end_dir: Vector2 = segs[segs.size() - 1]["dir"] as Vector2
	var end_blue: bool = str(segs[segs.size() - 1]["color"]) == LxHit.COLOR_BLUE

	var reflected_mirror_ids: Dictionary = {}
	for refl: Dictionary in reflections:
		var m_obj: Object = refl.get("item") as Object
		var rpos: Vector2 = refl.get("pos", start_p) as Vector2
		var exit_p: Vector2 = refl.get("exit_pos", rpos + (refl.get("dir", aim) as Vector2) * 2.0) as Vector2
		var rdir: Vector2 = refl.get("dir", aim) as Vector2
		var t_col: String = str(refl.get("color", LxHit.COLOR_BLUE))
		var b_idx: int = int(refl.get("bounce", 1))
		if wick.move_prism != null:
			wick.move_prism.on_bolt_reflected(rpos, rdir, b_idx, t_col)
		if m_obj != null and is_instance_valid(m_obj):
			reflected_mirror_ids[m_obj.get_instance_id()] = true
			if m_obj.has_method("on_hit"):
				var ping: LxHit = LxHit.make(LxHit.SOURCE_BEAM, dmg, rdir, rpos, wear, false, pierce, wick, false, t_col)
				m_obj.call("on_hit", ping)
		if b_idx == 1 and wick.move_prism != null and wick.move_prism.has_split() and wick.move_bolt != null:
			var split_rad: float = deg_to_rad(wick.move_prism.SPLIT_ANGLE_DEG)
			var bolt_spd: float = float(wick.move_bolt.get_data().get("speed", 330.0))
			var m_id: int = m_obj.get_instance_id() if (m_obj != null and is_instance_valid(m_obj)) else -1
			for sign_a: float in [-1.0, 1.0]:
				var sb := LxMoveBolt.Bolt.new()
				sb.dir = rdir.rotated(sign_a * split_rad).normalized()
				sb.prev_pos = rpos
				sb.pos = exit_p
				sb.speed = bolt_spd
				sb.max_range = 110.0
				sb.damage = dmg * 0.45
				sb.shield_wear = 0.5
				sb.bounces_left = 0
				sb.bounce_count = 1
				sb.is_prism = true
				sb.is_split_shard = true
				sb.light_color = t_col
				sb.cracks_armour = true
				if m_id != -1:
					sb.hit_ids.append(m_id)
				wick.bolts.append(sb)
			wick.move_prism.spawn_split_wedge(rpos, rdir)
			wick.spawn_sparks(rpos, rdir, 6, LxWick.PAL_SKY, 42.0, 108.0, 0.20)
			wick.spawn_sparks(rpos, rdir, 4, LxWick.PAL_CREAM, 55.0, 118.0, 0.16)
			wick.emit_sfx("prism_chain", rpos, true)
	if not reflections.is_empty():
		wick.trigger_hitstop(0.035)

	var any_enemy_hit: bool = false
	var hit_enemy_ids: Dictionary = {}
	var hit_inter_keys: Dictionary = {}
	var enemies: Array = wick.world_get_enemies(ctx)
	var inters: Array = wick.world_get_interactables(ctx)

	for seg: Dictionary in segs:
		var s_a: Vector2 = seg["start"] as Vector2
		var s_b: Vector2 = seg["end"] as Vector2
		var s_dir: Vector2 = seg["dir"] as Vector2
		var s_col: String = str(seg["color"])
		var s_bounce: int = int(seg["bounce"])
		var s_dmg: float = dmg * pow(prism_mult, float(s_bounce)) if s_bounce > 0 else dmg
		var s_cracks: bool = wick.move_prism != null and wick.move_prism.should_crack_armour(s_bounce)
		var s_curve_deg: float = float(seg.get("curve_angle_deg", 0.0))
		var seg_hit: LxHit = LxHit.make(
			LxHit.SOURCE_BEAM, s_dmg, s_dir, s_a,
			wear, stagger, pierce, wick, s_cracks, s_col, s_curve_deg
		)

		for e_var: Variant in enemies:
			if not (e_var is Object):
				continue
			var enemy: Object = e_var as Object
			if not wick.is_entity_alive(enemy):
				continue
			var eid: int = enemy.get_instance_id()
			if hit_enemy_ids.has(eid):
				continue
			var epos: Vector2 = wick.get_entity_pos(enemy)
			var erad: float = wick.get_entity_radius(enemy, 8.0)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, s_a, s_b)
			if closest.distance_to(epos) <= erad + half_w:
				hit_enemy_ids[eid] = true
				var res: int = wick.apply_hit_to_entity(enemy, seg_hit)
				wick.on_hit_landed(seg_hit, res, epos, hs, sh)
				if res >= 0:
					any_enemy_hit = true
					if s_col == LxHit.COLOR_BLUE:
						wick.spawn_ring(epos, 2.0, 14.0, 0.20, LxWick.PAL_ICE, 1.2)
						wick.spawn_sparks(epos, s_dir, 6, LxWick.PAL_ICE, 34.0, 96.0, 0.20)

		for it_var: Variant in inters:
			if not (it_var is Object):
				continue
			var item: Object = it_var as Object
			if not is_instance_valid(item) or not item.has_method("on_hit"):
				continue
			if item.get("active") is bool and not bool(item.get("active")):
				continue
			var iid: int = item.get_instance_id()
			if reflected_mirror_ids.has(iid):
				continue
			var ikey: String = "%d:%s" % [iid, s_col]
			if hit_inter_keys.has(ikey):
				continue
			var ipos: Vector2 = wick.get_entity_pos(item)
			var irad: float = wick.get_entity_radius(item, 8.0)
			if _segment_hits_item(s_a, s_b, half_w, item, ipos, irad):
				hit_inter_keys[ikey] = true
				var consumed: Variant = item.call("on_hit", seg_hit)
				if consumed is bool and bool(consumed):
					if str(item.get("kind")) == "obsidian_seal" and Lx.state != null and Lx.state.has_move("sunflare"):
						var emax: float = Lx.state.get_effective_ember_max()
						var was_full: bool = wick.ember >= emax - 0.001
						wick.ember = minf(emax, wick.ember + 22.0)
						if not was_full and wick.ember >= emax - 0.001:
							wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
							wick.emit_sfx("beam_ready", wick.global_position, false)
					var sp_c: Color = LxWick.PAL_ICE if s_col == LxHit.COLOR_BLUE else LxWick.PAL_GOLD
					wick.spawn_sparks(ipos, s_dir, 6, sp_c, 30.0, 90.0, 0.22)

		if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
			LxBiomeMechanics.active_instance.try_hit_biome_target(s_a, s_b, s_dir, wick)
		LxSceneryProp.graze_segment(ctx, s_a, s_b, s_dir, s_col == LxHit.COLOR_BLUE)

	var isl_dec: int = Lx.state.island_id if Lx.state != null else 1
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		var dk: int = LxGroundDecals.Kind.PRISM_STAR if end_blue else LxGroundDecals.Kind.SCORCH
		if not end_blue:
			if isl_dec in [2, 4]:
				dk = LxGroundDecals.Kind.RIPPLE
			elif isl_dec == 3:
				dk = LxGroundDecals.Kind.BLOSSOM
			elif isl_dec in [5, 7]:
				dk = LxGroundDecals.Kind.PRISM_STAR
		LxGroundDecals.active_instance.add_decal(dk, end_p, 11.0, 5.2)

	beam_start = start_p
	beam_end = end_p
	beam_segments = segs
	beam_width = width_px
	beam_vis_max = BEAM_VIS_DURATION
	beam_vis_t = BEAM_VIS_DURATION
	cooldown_left = float(data.get("cooldown", 0.45))
	beams_fired += 1

	wick.apply_recoil(-aim * 52.0)
	wick.fired.emit(aim, "beam")
	wick.muzzle_t = 0.11
	wick.shoot_anim_t = 0.26
	wick.recoil_vis = 1.0
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", -aim, 2.6)
	if not any_enemy_hit:
		wick.trigger_shake(sh * 0.6)
	var end_col: Color = LxWick.PAL_ICE if end_blue else LxWick.PAL_GOLD
	wick.spawn_ring(start_p, 2.0, 16.0 if empowered else 12.0, 0.22, LxWick.PAL_CREAM, 1.8 if empowered else 1.5)
	wick.spawn_ring(end_p, 2.0, 14.0 if empowered else 10.0, 0.22, end_col, 1.8 if empowered else 1.5)
	wick.spawn_sparks(start_p, aim, 9 if empowered else 6, LxWick.PAL_CREAM, 35.0, 105.0, 0.20)
	wick.spawn_sparks(start_p, aim, 3, LxBiomePalette.col(isl_dec, "glow"), 28.0, 92.0, 0.22)
	wick.spawn_sparks(end_p, -end_dir, 10 if empowered else 8, end_col, 30.0, 105.0, 0.22)
	wick.spawn_sparks(end_p, -end_dir, 3, LxWick.PAL_SKY if end_blue else LxBiomePalette.col(isl_dec, "glow"), 26.0, 88.0, 0.24)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var fred_b: bool = LxHudFx.flash_reduced()
		var bi_b: float = (1.12 if empowered else 0.92) if fred_b else (1.72 if empowered else 1.45)
		LxDarknessLayer.active_instance.add_burst_light(start_p, 74.0 if empowered else 62.0, bi_b, 0.28)
		for seg_l: Dictionary in segs:
			var la: Vector2 = seg_l["start"] as Vector2
			var lb: Vector2 = seg_l["end"] as Vector2
			LxDarknessLayer.active_instance.add_burst_light(la.lerp(lb, 0.5), 68.0 if empowered else 56.0, bi_b * 0.85, 0.24)
		LxDarknessLayer.active_instance.add_burst_light(end_p, 78.0 if empowered else 64.0, bi_b, 0.30)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", start_p, 56.0, 72.0)
			(amb as Object).call("_gust_particles", end_p, 52.0, 84.0)
	wick.emit_sfx("beam_fire", start_p, false)
	if empowered:
		wick.emit_sfx("perfect_counter", start_p, false)
	return true


func tick(dt: float) -> void:
	super.tick(dt); _vis_clock += dt
	if beam_vis_t > 0.0:
		beam_vis_t = maxf(0.0, beam_vis_t - dt)
	if _buffer_t > 0.0:
		_buffer_t = maxf(0.0, _buffer_t - dt)
		if _held and not charging and can_use():
			press_beam()
	if not charging:
		return
	if wick == null or wick.dead or wick.is_dashing() or wick.is_gliding() or wick.is_zipping() \
			or (wick.lantern != null and not wick.lantern.is_in_hand()):
		cancel()
		return
	var was_ready: bool = charge_t >= charge_time - 0.001
	charge_t = minf(charge_time, charge_t + dt)
	var is_ready: bool = charge_t >= charge_time - 0.001
	if is_ready and not was_ready:
		wick.spawn_ring(wick.global_position, 3.0, 13.0, 0.20, LxWick.PAL_CREAM, 1.5)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(wick.global_position, 46.0, 0.72 if LxHudFx.flash_reduced() else 1.12, 0.22)
		wick.emit_sfx("beam_ready", wick.global_position, false)
	_charge_spark_cd -= dt
	if _charge_spark_cd <= 0.0:
		_charge_spark_cd = 0.08 if is_ready else 0.14
		var col: Color = LxWick.PAL_CREAM if is_ready else LxWick.PAL_GOLD
		wick.spawn_sparks(wick.global_position, wick.facing, 1, col, 14.0, 38.0, 0.14)


func cancel() -> void:
	charging = false; charge_t = 0.0; _buffer_t = 0.0; _held = false
	if Lx.input != null: Lx.input.clear_toggle("lx_beam")

func reset() -> void:
	super.reset(); cancel(); beam_vis_t = 0.0; beam_segments.clear(); beams_fired = 0; _vis_clock = 0.0


func draw_fx(canvas: CanvasItem, off: Vector2, hand_pos: Vector2) -> void:
	var flash_red: bool = LxHudFx.flash_reduced()
	var flash_sc: float = 0.72 if flash_red else 1.0
	if charging:
		var isl_c: int = Lx.state.island_id if Lx.state != null else 1
		var b_glow: Color = LxBiomePalette.col(isl_c, "glow")
		var prog: float = charge_progress()
		var ready: bool = prog >= 0.999
		var r: float = lerpf(14.0, 4.5, prog)
		var ring_col: Color = LxWick.PAL_CREAM if ready else LxWick.PAL_GOLD
		canvas.draw_arc(hand_pos, r, -PI * 0.5, -PI * 0.5 + TAU * prog, 20, ring_col, 1.5)
		var spin: float = _vis_clock * (3.2 if flash_red else 5.5)
		var mote_r: float = lerpf(15.0, 3.0, prog)
		for i: int in range(4):
			var ang: float = spin + TAU * float(i) * 0.25 + prog * 2.4
			var mp: Vector2 = (hand_pos + Vector2.from_angle(ang) * mote_r).round()
			var mcol: Color = LxWick.PAL_CREAM if (ready or i % 2 == 0) else b_glow
			canvas.draw_rect(Rect2(mp, Vector2(1.0, 1.0)), Color(mcol, lerpf(0.55, 0.95, prog) * flash_sc))
			var tp: Vector2 = (hand_pos + Vector2.from_angle(ang - 0.26) * (mote_r + 2.0)).round()
			canvas.draw_rect(Rect2(tp, Vector2(1.0, 1.0)), Color(b_glow if i % 2 == 0 else LxWick.PAL_APRICOT, 0.48 * flash_sc))
		if ready:
			canvas.draw_circle(hand_pos, 3.0, LxWick.PAL_CREAM)
			canvas.draw_arc(hand_pos, 7.5, 0.0, TAU, 16, Color(LxWick.PAL_GOLD, 0.70 * flash_sc), 1.0)
			canvas.draw_arc(hand_pos, 9.5, 0.0, TAU, 16, Color(b_glow, 0.45 * flash_sc), 1.0)
			var sr: float = roundf(5.5 if flash_red else (6.0 + 1.5 * sin(spin * 2.6)))
			_draw_star_flare(canvas, hand_pos, Vector2.RIGHT, sr, sr, 0.92 * flash_sc, false)

		# Charge-up aim preview (previews 1st reflected blue segment when aiming at a Blue Transformer!)
		var aim_dir: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var aim_len: float = 128.0 if ready else lerpf(18.0, 76.0, prog)
		var ctx: Node = _world_ctx if _world_ctx != null else Lx.world
		var preview_segs: Array[Dictionary] = _trace_beam_segments(ctx, wick.global_position, aim_dir, aim_len, 1)
		if not preview_segs.is_empty():
			var s0: Dictionary = preview_segs[0]
			var seg0_len: float = minf(aim_len, (s0["start"] as Vector2).distance_to(s0["end"] as Vector2))
			var tip0: Vector2 = (hand_pos + aim_dir * seg0_len).round()
			if ready:
				for si: int in range(0, 12, 2):
					var p0: Vector2 = (hand_pos + aim_dir * (seg0_len * float(si) / 12.0)).round()
					var p1: Vector2 = (hand_pos + aim_dir * (seg0_len * float(si + 1) / 12.0)).round()
					canvas.draw_line(p0, p1, Color(LxWick.PAL_GOLD, 0.62 * flash_sc), 1.0)
				canvas.draw_rect(Rect2(tip0 - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_CREAM)
			else:
				canvas.draw_line(hand_pos, tip0, Color(ring_col, 0.48), 1.0)

			if preview_segs.size() >= 2:
				var s1: Dictionary = preview_segs[1]
				var r_start: Vector2 = (s1["start"] as Vector2) + off + Vector2(0.0, -5.0)
				var r_dir: Vector2 = s1["dir"] as Vector2
				var r_max: float = 72.0 if ready else lerpf(14.0, 44.0, prog)
				var r_len: float = minf(r_max, (s1["start"] as Vector2).distance_to(s1["end"] as Vector2))
				var r_end: Vector2 = (r_start + r_dir * r_len).round()
				var b_vtx: Vector2 = ((s0["end"] as Vector2) + off + Vector2(0.0, -5.0)).round()
				canvas.draw_rect(Rect2(b_vtx - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_ICE)
				if ready:
					for sj: int in range(0, 10, 2):
						var q0: Vector2 = (r_start + r_dir * (r_len * float(sj) / 10.0)).round()
						var q1: Vector2 = (r_start + r_dir * (r_len * float(sj + 1) / 10.0)).round()
						canvas.draw_line(q0, q1, Color(LxWick.PAL_ICE if (sj % 4 == 0) else LxWick.PAL_SKY, 0.78 * flash_sc), 1.0)
					canvas.draw_rect(Rect2(r_end - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_ICE)
				else:
					canvas.draw_line(r_start.round(), r_end, Color(LxWick.PAL_SKY, 0.58 * flash_sc), 1.0)

	if beam_vis_t > 0.0:
		var t: float = clampf(beam_vis_t / maxf(beam_vis_max, 0.01), 0.0, 1.0)
		var hot_pulse: bool = beam_vis_t > beam_vis_max * 0.78 and not flash_red
		var isl_b: int = Lx.state.island_id if Lx.state != null else 1
		var draw_segs: Array[Dictionary] = beam_segments
		if draw_segs.is_empty():
			draw_segs = [{"start": beam_start, "end": beam_end, "dir": (beam_end - beam_start).normalized(), "color": LxHit.COLOR_YELLOW, "bounce": 0}]
		for idx: int in range(draw_segs.size()):
			var seg: Dictionary = draw_segs[idx]
			var a: Vector2 = ((seg["start"] as Vector2) + off).round() + Vector2(0.0, -5.0)
			var b: Vector2 = ((seg["end"] as Vector2) + off).round() + Vector2(0.0, -5.0)
			var is_blue: bool = str(seg.get("color", LxHit.COLOR_YELLOW)) == LxHit.COLOR_BLUE
			var delta: Vector2 = b - a
			var blen: float = delta.length()
			var bdir: Vector2 = delta / blen if blen > 0.5 else Vector2.RIGHT
			var perp := Vector2(-bdir.y, bdir.x)
			var core_w: float = maxf(1.0, beam_width * 0.30 * t) + (2.0 if hot_pulse else 0.0)
			if is_blue:
				canvas.draw_line(a, b, Color(LxWick.PAL_SKY, t * 0.48 * flash_sc), maxf(2.0, (beam_width + 3.5) * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_SKY, t * 0.90 * flash_sc), maxf(1.0, beam_width * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_ICE, t * lerpf(1.0, 0.88, 1.0 - flash_sc)), maxf(1.0, beam_width * 0.65 * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_CREAM, t), core_w)
			else:
				canvas.draw_line(a, b, Color(LxBiomePalette.col(isl_b, "glow"), t * 0.42 * flash_sc), maxf(2.0, (beam_width + 3.0) * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_APRICOT, t * 0.85 * flash_sc), maxf(1.0, beam_width * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_GOLD, t * lerpf(1.0, 0.85, 1.0 - flash_sc)), maxf(1.0, beam_width * 0.65 * t))
				canvas.draw_line(a, b, Color(LxWick.PAL_CREAM, t), core_w)
			var node_col: Color = LxWick.PAL_ICE if is_blue else LxWick.PAL_GOLD
			var cursor: float = 12.0 + (1.0 - t) * 10.0
			while cursor < blen - 8.0:
				var np: Vector2 = (a + bdir * cursor).round()
				var hw: float = maxf(1.0, roundf((1.5 + beam_width * 0.35) * t))
				canvas.draw_line((np - perp * hw).round(), (np + perp * hw).round(), Color(node_col, t * 0.85 * flash_sc), 1.0)
				canvas.draw_rect(Rect2(np - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(LxWick.PAL_CREAM, t * 0.92))
				cursor += 18.0
			if idx == 0:
				canvas.draw_circle(a, 4.0 * t, Color(LxWick.PAL_CREAM, t * flash_sc))
				_draw_star_flare(canvas, a, bdir, roundf(9.0 * t * flash_sc), roundf(6.5 * t * flash_sc), t, is_blue)
			else:
				canvas.draw_circle(a, 4.2 * t, Color(LxWick.PAL_ICE, t * flash_sc))
				_draw_star_flare(canvas, a, bdir, roundf(8.5 * t * flash_sc), roundf(7.5 * t * flash_sc), t, true)
			if idx == draw_segs.size() - 1:
				canvas.draw_circle(b, 4.5 * t, Color(LxWick.PAL_ICE if is_blue else LxWick.PAL_GOLD, t * flash_sc))
				_draw_star_flare(canvas, b, bdir, roundf(10.0 * t * flash_sc), roundf(8.5 * t * flash_sc), t, is_blue)


func _draw_star_flare(canvas: CanvasItem, c: Vector2, axis: Vector2, main_r: float, cross_r: float, alpha: float, is_blue: bool = false) -> void:
	if main_r < 1.5 and cross_r < 1.5:
		return
	var perp := Vector2(-axis.y, axis.x)
	var cg := Color(LxWick.PAL_ICE if is_blue else LxWick.PAL_GOLD, alpha * 0.92)
	var cc := Color(LxWick.PAL_CREAM, alpha)
	canvas.draw_line((c - axis * main_r).round(), (c + axis * main_r).round(), cg, 1.0)
	canvas.draw_line((c - perp * cross_r).round(), (c + perp * cross_r).round(), cg, 1.0)
	canvas.draw_line((c - axis * roundf(main_r * 0.55)).round(), (c + axis * roundf(main_r * 0.55)).round(), cc, 1.0)
	canvas.draw_line((c - perp * roundf(cross_r * 0.55)).round(), (c + perp * roundf(cross_r * 0.55)).round(), cc, 1.0)
	canvas.draw_rect(Rect2(c - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), cc)


func _trace_beam_segments(
	ctx: Node,
	origin: Vector2,
	aim_dir: Vector2,
	max_range: float,
	max_bounces: int,
	reflections_out: Array[Dictionary] = []
) -> Array[Dictionary]:
	return LxBeamTrace.trace_segments(wick, ctx, origin, aim_dir, max_range, max_bounces, reflections_out)


func _segment_hits_item(a: Vector2, b: Vector2, half_w: float, item: Object, ipos: Vector2, irad: float) -> bool:
	return LxBeamTrace.segment_hits_item(a, b, half_w, item, ipos, irad)
