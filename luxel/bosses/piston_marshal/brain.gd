class_name LxPistonMarshalBoss
extends LxBossBase
## Island 6 Iron Colossus Mini-Boss: THE PISTON MARSHAL (`colossus_r5`).
## Brass jackhammer sentinel whose slide-lunges accelerate downhill with the giant's rhythmic stride!
## P1 (100-50%): Downhill Jackhammer Slide-Lunge (jams in deck with comedy dakka-dakka rattle!),
##               Hydraulic Quake ring, Vent Steam Jet (quenchable with Blue / corner coolant crystals!).
## P2 (<=50%): Outer floor strips crumble (`stage.set_tiles`) + Double Downhill Slide-Lunge!

const LUNGE_BASE_SPEED: float = 235.0
const LUNGE_DOWNHILL_BONUS: float = 78.0
const STRIDE_PERIOD: float = 6.0
const STRIDE_WARN_S: float = 0.75
const TILT_PUSH_WICK: float = 14.0
const TILT_BOOTS_MULT: float = 0.15

var _lunge_dir: Vector2 = Vector2.LEFT
var _aim_dir: Vector2 = Vector2.LEFT
var _stride_t: float = 0.0
var _stride_side: int = -1
var _stride_warn: bool = false
var _last_side: int = -1
var _jammed_rattle_t: float = 0.0
var _quench_t: float = 0.0
var _quench_cd: float = 0.0
var _double_lunge_phase: int = 0
var _coolant_positions: Array[Vector2] = []


func _init() -> void:
	super._init()
	kind = "piston_marshal"
	boss_id = "piston_marshal"
	boss_name_key = "ISL6_BOSS_MARSHAL"
	island_id = 6
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 102.0
	hp = 102.0
	body_radius = 11.0
	move_speed = 38.0
	stagger_threshold = 13.0
	stagger_duration = 1.95
	post_recover_cd = 0.28
	intro_duration = 0.55
	death_duration = 1.8
	shard_drop = 24


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1 (P1+P2): Piston Slide-Lunge (accelerates downhill with Colossus stride -> jams in deck!)
	register_attack("piston_slide_lunge", {
		"weight": 1.35, "tell": 0.56, "commit": 0.42, "recover": 1.45, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var boost: float = _downhill_mult(_lunge_dir)
			var dest: Vector2 = clamp_to_arena(pos + _lunge_dir * (118.0 * boost))
			ground.warn_lane(pos, dest, 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("piston_hiss", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("golem_stomp", pos)
			stage.shake(0.16),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var spd: float = LUNGE_BASE_SPEED + maxf(0.0, _lunge_dir.x * float(_stride_side)) * LUNGE_DOWNHILL_BONUS
			var prev: Vector2 = pos
			move_boss(_lunge_dir * spd * dt, false)
			check_contact_damage(body_radius + 11.0, _lunge_dir, 1.0, "marshal_lunge")
			# Overshooting into the iron curb jams his jackhammer immediately with sparks!
			if pos.distance_to(prev) < spd * dt * 0.28 and state_timer < 0.28:
				_jammed_rattle_t = 1.45
				stage.play_sfx("marshal_rattle", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if _jammed_rattle_t <= 0.0:
				_jammed_rattle_t = 1.35
				stage.play_sfx("marshal_rattle", pos),
	})

	# Attack 2 (P1+P2): Hydraulic Quake (56px shockwave + targeted rivet bursts reaching corners!)
	register_attack("hydraulic_quake", {
		"weight": 1.20, "tell": 0.54, "commit": 0.30, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 58.0, last_tell_duration, 1.0, "coral", "gold")
			var drops: Array[Vector2] = _build_corner_drops(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration + 0.06, 26.0, 1.0, "apricot", "gold")
			stage.play_sfx("golem_stomp", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 124.0, gap_a, 0.72, {"color": "apricot", "source": "marshal_quake"})
			stage.play_sfx("magma_crack", pos)
			stage.shake(0.18),
	})

	# Attack 3 (P1+P2): Vent Steam Jet (96px pressurized steam cone + rear boiler opens for Blue quench!)
	register_attack("vent_steam_jet", {
		"weight": 1.25, "tell": 0.50, "commit": 0.32, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var ang: float = _aim_dir.angle()
			ground.warn_sector(pos, ang - 0.55, ang + 0.55, 104.0, last_tell_duration, 1.0, "apricot", "cream")
			stage.play_sfx("piston_hiss", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 2 else 3, 0.85, 146.0, {"color": "gold", "source": "marshal_steam"})
			stage.play_sfx("forge_gust", pos)
			stage.shake(0.14),
	})

	# Attack 4 (P2): Double Downhill Slide-Lunge (back-to-back hydraulic rush + spark wall!)
	register_attack("double_slide_lunge", {
		"phases": [2],
		"weight": 1.65, "tell": 0.54, "commit": 0.62, "recover": 1.40, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_double_lunge_phase = 0
			_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _lunge_dir * 132.0), 13.0, last_tell_duration, 0.0, "coral", "cream")
			stage.play_sfx("colossus_horn", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("golem_stomp", pos)
			stage.shake(0.18),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			if el >= 0.30 and _double_lunge_phase == 0:
				_double_lunge_phase = 1
				_commit_hit_done = false
				_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else -_lunge_dir
				patterns.emit_fan(pos, _lunge_dir, 5, 0.90, 134.0, {"color": "coral", "source": "marshal_double"})
				stage.play_sfx("piston_hiss", pos)
				stage.shake(0.16)
			var spd: float = (LUNGE_BASE_SPEED + 25.0) + maxf(0.0, _lunge_dir.x * float(_stride_side)) * LUNGE_DOWNHILL_BONUS
			move_boss(_lunge_dir * spd * dt, false)
			check_contact_damage(body_radius + 11.0, _lunge_dir, 1.0, "marshal_double_lunge"),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if _jammed_rattle_t <= 0.0:
				_jammed_rattle_t = 1.40
				stage.play_sfx("marshal_rattle", pos),
	})


func _on_reset_encounter() -> void:
	_stride_t = 0.0
	_stride_side = -1
	_stride_warn = false
	_last_side = -1
	_jammed_rattle_t = 0.0
	_quench_t = 0.0
	_quench_cd = 0.0
	_double_lunge_phase = 0
	_coolant_positions.clear()
	var c: Vector2 = arena_rect.get_center()
	var c1: Vector2 = clamp_to_arena(c + Vector2(-72.0, -44.0))
	var c2: Vector2 = clamp_to_arena(c + Vector2(72.0, -44.0))
	_coolant_positions = [c1, c2]
	props.spawn_bell(c1, func(_p: Dictionary) -> void: _fire_coolant_quench(c1), "coolant_nw")
	props.spawn_bell(c2, func(_p: Dictionary) -> void: _fire_coolant_quench(c2), "coolant_ne")


func _fire_coolant_quench(from_p: Vector2) -> void:
	stage.play_sfx("mirror_ping", from_p)
	stage.light_burst(from_p, 46.0, 1.15, 0.24)
	if not engaged or boss_state == BossState.DEATH or _quench_cd > 0.0:
		return
	# Corner coolant mirror reflects a Blue quench jet straight into Marshal's steam boiler (with cooldown so it cannot stunlock)!
	_trigger_quench_stagger()


func _trigger_quench_stagger() -> void:
	if _quench_cd > 0.0 or boss_state == BossState.STAGGER:
		return
	_quench_t = 2.0
	_quench_cd = 9.5
	stage.play_sfx("magma_crack", pos)
	stage.shake(0.20)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 4.0, 26.0, 0.28, PAL["ice"] as Color, 1.6)
	add_stagger(stagger_threshold)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _jammed_rattle_t > 0.0:
		_jammed_rattle_t = maxf(0.0, _jammed_rattle_t - dt)
	if _quench_t > 0.0:
		_quench_t = maxf(0.0, _quench_t - dt)
	if _quench_cd > 0.0:
		_quench_cd = maxf(0.0, _quench_cd - dt)
	if not engaged or boss_state == BossState.DEATH:
		return

	# Sync with room's colossus_stride_cam if present; otherwise run local 6.0s giant stride!
	var synced: bool = _sync_room_stride_cam()
	if not synced:
		_stride_t += dt * (1.25 if phase >= 2 else 1.0)
		var half_p: float = STRIDE_PERIOD * 0.5
		var cyc: float = fposmod(_stride_t, STRIDE_PERIOD)
		var cur_s: int = -1 if cyc < half_p else 1
		var loc_t: float = cyc if cyc < half_p else (cyc - half_p)
		var now_w: bool = loc_t >= (half_p - STRIDE_WARN_S * get_tell_scale())
		if now_w and not _stride_warn:
			stage.play_sfx("colossus_horn", pos)
		if cur_s != _last_side:
			_last_side = cur_s
			stage.shake(0.06 if is_flash_reduced() else 0.10)
		_stride_side = cur_s
		_stride_warn = now_w

	# Gentle downhill stride tilt push (Heat-Boots cuts by 85%; never shoves into rim pits!)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and arena_rect.grow(-22.0).has_point(w.global_position) and w.has_method("push_external"):
			var has_boots: bool = Lx.state != null and bool(Lx.state.story_flags.get("item_heat_boots", false))
			var mult: float = TILT_BOOTS_MULT if has_boots else 1.0
			w.call("push_external", Vector2(float(_stride_side) * TILT_PUSH_WICK * mult, 0.0), "colossus_tilt")


func _sync_room_stride_cam() -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "colossus_stride_cam":
			var s_v: Variant = (it_v as Object).get("stride_side")
			var w_v: Variant = (it_v as Object).get("is_warning")
			if s_v != null:
				_stride_side = int(s_v)
				_stride_warn = bool(w_v)
				return true
	return false


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	# Blue light into Marshal's glowing steam vent immediately triggers 2.0s Quench Stagger!
	if hit.is_blue() and _quench_t <= 0.0:
		_trigger_quench_stagger()
		return dmg * 1.45
	if is_punishable():
		return dmg
	# Heavy riveted boiler-plate resists non-pierce frontal bolts slightly (Lance/Sunflare/rear cut clean!)
	var fwd: Vector2 = Vector2.from_angle(facing)
	var from_dir: Vector2 = (hit.origin - pos).normalized() if hit.origin.distance_to(pos) > 0.1 else -hit.dir
	if from_dir.dot(fwd) > 0.35 and hit.source == LxHit.SOURCE_BOLT and not hit.pierce and not hit.cracks_armour:
		clank_t = 0.10
		return dmg * 0.58
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Hydraulic floor pistons lock up as iron curb pillars (reverted cleanly on reset_encounter()!)
		stage.set_tiles(world_ctx, Rect2i(4, 3, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 7, 1, 1), "wall")
		stage.play_sfx("miniboss_forge_roar", pos)
		stage.shake(0.22)
		stage.darkness_pulse(0.54, 0.85)


func _on_death_start() -> void:
	stage.play_sfx("shield_shatter", pos)


func _downhill_mult(dir: Vector2) -> float:
	return 1.24 if dir.x * float(_stride_side) > 0.25 else 0.96


func _build_corner_drops(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	return out


func _body_color() -> Color:
	return (PAL["ice"] if _quench_t > 0.0 else (PAL["coral"] if phase >= 2 else PAL["mauve"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var fred: bool = is_flash_reduced()
	# Stride tilt floor chevrons showing current downhill slide direction!
	if engaged and boss_state != BossState.DEATH:
		var t_col: Color = PAL["cream"] as Color if _stride_warn else PAL["gold"] as Color
		var dir_x: float = float(_stride_side)
		for ci: int in range(3):
			var cy: float = arena_rect.position.y + 30.0 + float(ci) * (arena_rect.size.y - 60.0) * 0.5
			var cx: float = arena_rect.get_center().x + dir_x * 46.0
			var p: Vector2 = (Vector2(cx, cy) - pos).round()
			draw_line(p - Vector2(dir_x * 5.0, 4.0), p, Color(PAL["void"] as Color, 0.50 if fred else 0.75), 3.0)
			draw_line(p - Vector2(dir_x * 5.0, -4.0), p, Color(PAL["void"] as Color, 0.50 if fred else 0.75), 3.0)
			draw_line(p - Vector2(dir_x * 5.0, 4.0), p, Color(t_col, 0.45 if fred else 0.70), 1.0)
			draw_line(p - Vector2(dir_x * 5.0, -4.0), p, Color(t_col, 0.45 if fred else 0.70), 1.0)
	# Coolant crystal halos at NW/NE corners
	for cp: Vector2 in _coolant_positions:
		var lp: Vector2 = (cp - pos).round()
		draw_arc(lp, 10.0, 0.0, TAU, 16, Color(PAL["void"] as Color, 0.72), 3.0)
		draw_arc(lp, 10.0, 0.0, TAU, 16, Color(PAL["ice"] as Color, 0.72), 1.0)
	# Comedy jammed jackhammer rattle lines during recover!
	if boss_state == BossState.RECOVER and _jammed_rattle_t > 0.0:
		var jx: float = sin(anim_t * 48.0) * 3.0 if not fred else 0.0
		var hp_top: Vector2 = (off + Vector2(jx, -body_radius - 12.0)).round()
		draw_line(hp_top + Vector2(-9.0, -2.0), hp_top + Vector2(-5.0, 2.0), PAL["void"] as Color, 3.0)
		draw_line(hp_top + Vector2(5.0, 2.0), hp_top + Vector2(9.0, -2.0), PAL["void"] as Color, 3.0)
		draw_line(hp_top + Vector2(-9.0, -2.0), hp_top + Vector2(-5.0, 2.0), PAL["gold"] as Color, 1.0)
		draw_line(hp_top + Vector2(5.0, 2.0), hp_top + Vector2(9.0, -2.0), PAL["gold"] as Color, 1.0)
	elif boss_state == BossState.STAGGER and _quench_t > 0.0:
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 20, PAL["ice"] as Color, 2.0)
