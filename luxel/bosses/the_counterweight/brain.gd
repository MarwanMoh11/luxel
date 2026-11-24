class_name LxTheCounterweightBoss
extends LxBossBase
## Island 5 Set-Piece Boss (Fall, fall_r4): The Counterweight.
## Runaway brass pendulum colossus hammering the plunging Orrery Dome roof on 3 glowing chains!
## Central switchable LxFields polarity well bends shots behind its front iron cowling to snap
## its 3 cuttable LxBossTether chain links (3 links -> 2 -> 1 -> plunges into the stars!).

class RoofWellField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 68.0
	var strength: float = 540.0
	var is_push: bool = false
	var active: bool = true

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= radius * radius or d2 <= 0.0001:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		var falloff: float = (0.35 + 0.65 * u) * (1.0 - exp(-dist / 10.0))
		var mult: float = 1.20 if what in ["bolt", "beam"] else (0.95 if what == "lantern" else (0.08 if what == "wick" else 0.25))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const FRONT_COWL_HALF: float = 0.88

var _well: RoofWellField = null
var _well_reg: bool = false
var _well_anim: float = 0.0
var _pendulum_t: float = 0.0
var _slam_target: Vector2 = Vector2.ZERO
var _whip_ang: float = 0.0
var _cycle_count: int = 0
var _wind_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "the_counterweight"
	boss_id = "the_counterweight"
	boss_name_key = "I5_BOSS_WEIGHT"
	island_id = 5
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island5_boss_p1"
	music_p2_cue = "island5_boss_p2"
	max_hp = 108.0
	hp = 108.0
	body_radius = 12.5
	move_speed = 48.0
	stagger_threshold = 11.5
	stagger_duration = 1.45
	post_recover_cd = 0.26
	shard_drop = 26


func _exit_tree() -> void:
	_unregister_well()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33]) # 3 links -> 2 links -> 1 link

	# Attack 1: Plumb Slam — looming shadow circle + shockwave ring (Wings/Dash over, curve Throw/Beam!)
	register_attack("plumb_slam", {
		"weight": 1.25, "tell": 0.65, "commit": 0.38, "recover": 1.15, "cooldown": 1.25,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_slam_target = tgt
			ground.warn_ring(_slam_target, 28.0, last_tell_duration, 1.0, "coral", "gold")
			if phase >= 2:
				ground.warn_ring(_nearest_corner(tgt), 22.0, last_tell_duration + 0.08, 1.0, "apricot", "gold")
			stage.play_sfx("chain_groan", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var step: Vector2 = (_slam_target - pos).limit_length(54.0)
			move_boss(step, true)
			var cnt: int = 12 if phase >= 2 else 10
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			patterns.emit_gap_ring(pos, cnt, 118.0 + float(phase) * 8.0, gap_a, 0.78, {"color": "gold", "source": "plumb_wave", "field_scale": 0.85})
			stage.shake(0.24)
			stage.play_sfx("anchor_slam", pos),
	})

	# Attack 2: Chain Whip Arc — taut chain whine -> 180 deg sweeping bar + curved fan!
	register_attack("chain_whip_arc", {
		"weight": 1.20, "tell": 0.58, "commit": 0.48, "recover": 1.00, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_whip_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			ground.warn_sector(pos, _whip_ang - 1.05, _whip_ang + 1.05, 76.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("chain_groan", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var tip: Vector2 = clamp_to_arena(pos + Vector2.from_angle(_whip_ang) * 96.0)
			patterns.emit_chain_lightning([c, pos, tip], 0.45, 9.0, 0.26, 1.0)
			patterns.emit_fan(pos, Vector2.from_angle(_whip_ang), 5 if phase >= 2 else 3, 1.05, 136.0, {"color": "apricot", "source": "chain_whip", "field_scale": 1.15})
			stage.shake(0.18)
			stage.play_sfx("crystal_clank", pos),
	})

	# Attack 3: Debris Shed — roof shakes, fracturing falling stone rings across Wick & corners!
	register_attack("debris_shed", {
		"weight": 1.15, "tell": 0.56, "commit": 0.42, "recover": 0.95, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = [tgt, _nearest_corner(tgt)]
			if phase >= 2:
				drops.append(arena_rect.get_center().lerp(tgt, 0.5))
			if phase >= 3:
				drops.append(_farthest_corner(tgt))
			patterns.emit_rain(ground, drops, last_tell_duration, 23.0, 1.0, "coral", "gold")
			stage.play_sfx("chain_groan", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_boomerang(pos, aim.rotated(0.32), 142.0, 0.68, 0.78, {"color": "coral", "source": "roof_debris", "field_scale": 1.10})
			if phase >= 2:
				patterns.emit_boomerang(pos, aim.rotated(-0.32), 142.0, 0.68, -0.78, {"color": "gold", "source": "roof_debris", "field_scale": 1.10})
			stage.shake(0.16)
			stage.play_sfx("stone_break", pos),
	})

	# Attack 4 (P2/P3): Pendulum Maelstrom — reverses well polarity & sweeps orbiting weights + wall!
	register_attack("pendulum_maelstrom", {
		"phases": [2, 3], "weight": 1.55, "tell": 0.70, "commit": 0.50, "recover": 1.10, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_flip_well()
			ground.warn_ring(pos, 34.0, last_tell_duration, 0.0, "gold", "ice")
			ground.warn_ring(clamp_to_arena(tgt), 24.0, last_tell_duration + 0.06, 1.0, "coral", "gold")
			stage.play_sfx("chain_groan", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			patterns.emit_orbit(pos, 4 if phase >= 3 else 3, 44.0, 2.2 if phase >= 3 else 1.8, 2.0, {"color": "gold", "source": "pendulum_weight"})
			patterns.emit_sweep_wall(Vector2(c.x, arena_rect.position.y + 8.0), Vector2.DOWN, arena_rect.size.x - 28.0, 9, 3, 3, 102.0, {"color": "ice", "source": "chain_wall"})
			stage.shake(0.20)
			stage.play_sfx("eclipse_wave", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_well()
	_pendulum_t = 0.0
	_cycle_count = 0
	_wind_t = 0.0


func _on_engage() -> void:
	_ensure_well()
	_spawn_chain_links(3)
	var c: Vector2 = arena_rect.get_center()
	props.spawn_bell(c, func(_p: Dictionary) -> void: _flip_well(), "cw_well_bell")


func _on_death_start() -> void:
	_unregister_well()
	stage.play_sfx("i5b_chain_snap", pos)
	stage.play_sfx("zodiac_chord", arena_rect.get_center())


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	var ts: float = 16.0
	var tx_l: int = int(floorf((arena_rect.position.x + 8.0) / ts))
	var tx_r: int = int(floorf((arena_rect.end.x - 20.0) / ts))
	var ty_t: int = int(floorf((arena_rect.position.y + 8.0) / ts))
	var ty_b: int = int(floorf((arena_rect.end.y - 20.0) / ts))
	if new_phase == 2:
		tethers.cut_tether("cw_link_1")
		# Crack 2 roof corners into falling void cleanly reverted on reset!
		stage.set_tiles(world_ctx, Rect2i(tx_l, ty_t, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_r, ty_b, 1, 1), "pit")
		props.spawn_pillar(c + Vector2(-54.0, 26.0), 4.0, "cw_roof_spur_w")
		props.spawn_pillar(c + Vector2(54.0, -26.0), 4.0, "cw_roof_spur_e")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("i5b_chain_snap", pos)
	elif new_phase == 3:
		tethers.cut_tether("cw_link_2")
		_flip_well()
		stage.set_tiles(world_ctx, Rect2i(tx_r, ty_t, 1, 1), "pit")
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.28)
		stage.play_sfx("i5b_chain_snap", pos)
		stage.play_sfx("boss_roar", pos)


func _on_attack_recover_start(_attack_id: String) -> void:
	_cycle_count += 1
	if phase >= 3 and _cycle_count % 2 == 0:
		_flip_well()


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	var spd: float = 0.45 if is_flash_reduced() else 1.0
	_well_anim = fposmod(_well_anim + dt * spd, 1.0)
	_wind_t += dt * (1.8 if phase >= 3 else (1.3 if phase == 2 else 0.9))
	if _well != null:
		_well.pos = arena_rect.get_center()


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	# Sweeping giant pendulum figure-eight arc across the plunging Orrery roof!
	var c: Vector2 = arena_rect.get_center()
	var rate: float = 1.65 if phase >= 3 else (1.25 if phase == 2 else 0.95)
	_pendulum_t = wrapf(_pendulum_t + rate * dt, -PI, PI)
	var amp_x: float = maxf(44.0, arena_rect.size.x * 0.30)
	var amp_y: float = maxf(24.0, arena_rect.size.y * 0.24)
	var goal: Vector2 = clamp_to_arena(c + Vector2(sin(_pendulum_t) * amp_x, sin(_pendulum_t * 2.0) * amp_y))
	move_boss((goal - pos).limit_length(move_speed * (1.25 if phase >= 3 else 1.0) * dt), true)
	_face_point(target, 4.0, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 18.0
	var bypass: bool = is_curved or src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) < FRONT_COWL_HALF
	if front_hit and not bypass and not is_punishable():
		clank_t = 0.12
		stage.play_sfx("crystal_clank", pos)
		return dmg * 0.50
	if is_curved or (not front_hit):
		return dmg * 1.32
	return dmg


func _spawn_chain_links(count: int) -> void:
	tethers.clear()
	var top_y: float = arena_rect.position.y + 4.0
	var cx: float = arena_rect.get_center().x
	for i: int in range(count):
		var ox: float = (float(i) - 1.0) * 32.0
		var anchor_p := Vector2(cx + ox, top_y)
		var link_id: String = "cw_link_%d" % (i + 1)
		tethers.add_tether(link_id, anchor_p, func() -> Vector2: return pos + Vector2(ox * 0.25, -14.0), {
			"hp": 12.0, "max_length": 160.0, "color": "ice" if i == 1 else "gold",
			"on_cut": func(_t: Dictionary) -> void:
				hp = maxf(1.0, hp - 5.0)
				stage.play_sfx("i5b_chain_snap", pos)
				stage.shake(0.24)
				add_stagger(stagger_threshold),
		})


func _ensure_well() -> void:
	if _well == null:
		_well = RoofWellField.new()
	_well.pos = arena_rect.get_center()
	_well.is_push = false
	_well.active = true
	if not _well_reg:
		LxFields.add(_well)
		_well_reg = true


func _unregister_well() -> void:
	if _well != null and _well_reg:
		_well.active = false
		LxFields.remove(_well)
		_well_reg = false


func _flip_well() -> void:
	if _well == null:
		return
	_well.is_push = not _well.is_push
	stage.play_sfx("i5b_polarity_flip", _well.pos)
	stage.light_burst(_well.pos, 72.0, 1.3, 0.30)


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _farthest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) > b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["gold"] if phase == 2 else PAL["apricot"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Rushing vertical star-wind freefall streaks across the plunging Orrery Dome roof!
	var fred: bool = is_flash_reduced()
	var streak_n: int = 4 if fred else 8
	for si: int in range(streak_n):
		var sx_w: float = arena_rect.position.x + (float(si) + 0.5) * (arena_rect.size.x / float(streak_n))
		var sy_w: float = arena_rect.position.y + fposmod(_wind_t * 80.0 + float(si) * 37.0, maxf(16.0, arena_rect.size.y))
		var p0: Vector2 = (Vector2(sx_w, sy_w) - pos + off).round()
		draw_line(p0, p0 + Vector2(0.0, -10.0), Color(PAL["ice"] as Color, 0.25), 1.0)

	# Central polarity well ripples on roof
	if _well != null and _well_reg:
		var wc: Vector2 = (_well.pos - pos + off).round()
		var c_ring: Color = (PAL["gold"] if _well.is_push else PAL["sky"]) as Color
		draw_arc(wc, _well.radius, 0.0, TAU, 28, Color(c_ring, 0.26), 1.0)
		for k: int in range(2):
			var ph: float = fposmod(_well_anim + float(k) * 0.5, 1.0)
			var u: float = ph if _well.is_push else (1.0 - ph)
			draw_arc(wc, lerpf(10.0, _well.radius - 2.0, u), 0.0, TAU, 24, Color(c_ring, sin(ph * PI) * 0.45), 1.2)
		draw_circle(wc, 6.5, PAL["void"] as Color)
		draw_arc(wc, 6.5, 0.0, TAU, 14, c_ring, 1.2)
