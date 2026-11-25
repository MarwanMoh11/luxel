class_name LxMeridianWeaverBoss
extends LxBossBase
## Island 5 Dungeon B Mini-Boss (The Planetarium, planet_r6): The Meridian Weaver.
## Tall brass drafting-compass spider striding across an 8-star octagonal constellation ring,
## extinguishing lit stars behind its feet! Shoot corner Star Bells (or heavy-hit during
## Divider Slice tell) to rotate the dome 90 deg and drop its rear legs into void -> stagger!

const STAR_COUNT: int = 8
const BELL_COOLDOWN: float = 2.6

var _stars: Array[Dictionary] = []
var _dome_angle: float = 0.0
var _dome_turn_t: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT
var _stride_target: Vector2 = Vector2.ZERO
var _active_star_idx: int = 0
var _bell_cd: float = 0.0
var _snuff_flash_t: float = 0.0
var _snuff_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	super._init()
	kind = "meridian_weaver"
	boss_id = "meridian_weaver"
	boss_name_key = "I5_BOSS_WEAVER"
	island_id = 5
	is_miniboss = true
	reward_heart = "half"
	music_cue = "isl5_boss_minor_p1"
	music_p2_cue = "isl5_boss_minor_p2"
	max_hp = 74.0
	hp = 74.0
	body_radius = 11.0
	move_speed = 46.0
	stagger_threshold = 9.5
	stagger_duration = 1.45
	post_recover_cd = 0.28
	shard_drop = 20


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Compass Stride — lifts caliper legs, lunges to Wick's star, snuffs old star behind it!
	register_attack("compass_stride", {
		"weight": 1.25, "tell": 0.52, "commit": 0.38, "recover": 0.90, "cooldown": 1.15,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var next_idx: int = _nearest_star_idx(tgt)
			_stride_target = _star_pos(next_idx) if not _stars.is_empty() else clamp_to_arena(tgt)
			_aim_dir = (_stride_target - pos).normalized() if _stride_target.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_lane(pos, _stride_target, 11.0, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(tgt, 24.0, last_tell_duration + 0.05, 1.0, "plum", "coral")
			stage.play_sfx("compass_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_extinguish_star(_active_star_idx)
			if phase >= 2:
				_extinguish_star((_active_star_idx + 4) % STAR_COUNT)
			var to_w: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_fan(pos, to_w, 3, 0.42, 146.0, {"color": "coral", "source": "compass_needle", "field_scale": 0.0})
			stage.play_sfx("star_snuff", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var to_s: Vector2 = _stride_target - pos
			if to_s.length() > 3.0:
				move_boss(to_s.limit_length((210.0 if phase >= 2 else 175.0) * dt), true)
			check_contact_damage(body_radius + 6.0, _aim_dir, 1.0, "compass_stride"),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_active_star_idx = _nearest_star_idx(pos),
	})

	# Attack 2: Divider Slice — caliper legs open 90 deg firing twin scissor beams along star axes!
	register_attack("divider_slice", {
		"weight": 1.20, "tell": 0.60, "commit": 0.42, "recover": 1.05, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var a1: Vector2 = _aim_dir.rotated(0.32)
			var a2: Vector2 = _aim_dir.rotated(-0.32)
			ground.warn_lane(pos, clamp_to_arena(pos + a1 * 145.0), 8.0, last_tell_duration, 0.0, "gold", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + a2 * 145.0), 8.0, last_tell_duration, 0.0, "gold", "cream")
			ground.warn_ring(tgt, 22.0, last_tell_duration + 0.05, 1.0, "gold", "coral")
			stage.play_sfx("compass_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var p1: Vector2 = clamp_to_arena(pos + aim.rotated(0.28) * 140.0)
			var p2: Vector2 = clamp_to_arena(pos + aim.rotated(-0.28) * 140.0)
			patterns.emit_chain_lightning([p1, pos, p2], 0.45, 8.0, 0.24, 1.0)
			patterns.emit_fan(pos, aim, 5 if phase >= 2 else 3, 0.56, 146.0, {"color": "gold", "source": "divider_needle", "field_scale": 0.0})
			stage.shake(0.16)
			stage.play_sfx("orrery_beam_bolt", pos),
	})

	# Attack 3: Meridian Arc — brass needle sweep + corner-flushing star rings (zero safe spots!)
	register_attack("meridian_arc", {
		"weight": 1.15, "tell": 0.55, "commit": 0.38, "recover": 0.95, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = [tgt, _nearest_corner(tgt)]
			if phase >= 2:
				drops.append(arena_rect.get_center().lerp(tgt, 0.5))
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "plum", "gold")
			stage.play_sfx("compass_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var ang: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 122.0, ang + 0.55, 0.74, {"color": "apricot", "source": "meridian_needle"})
			patterns.emit_boomerang(pos, Vector2.from_angle(ang + 0.35), 140.0, 0.65, 0.65, {"color": "ice", "source": "meridian_arc"})
			stage.shake(0.14)
			stage.play_sfx("orrery_beam_bolt", pos),
	})

	# Attack 4 (P2): Ink Plumb Drop — hangs center & unleashes radial blackout snuff wave!
	register_attack("ink_plumb_drop", {
		"phases": [2], "weight": 1.65, "tell": 0.72, "commit": 0.44, "recover": 1.12, "cooldown": 1.25,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var to_c: Vector2 = (c - tgt).normalized() if tgt.distance_to(c) > 4.0 else Vector2.RIGHT
			var s1: Vector2 = clamp_to_arena(tgt + to_c * 44.0)
			var s2: Vector2 = clamp_to_arena(c + (c - s1).limit_length(52.0))
			ground.warn_safe_inversion(arena_rect, [s1, s2], 28.0, last_tell_duration, 0.26, 1.0, "gold", "plum")
			stage.play_sfx("star_snuff", c),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			for k: int in range(0, STAR_COUNT, 2):
				_extinguish_star(k)
			patterns.emit_spiral(pos, 4, 114.0, (tgt - pos).angle(), 0.45, 2, 0.16, {"color": "plum", "source": "ink_plumb"})
			stage.light_burst(c, 84.0, 1.35, 0.32)
			stage.shake(0.20)
			stage.play_sfx("eclipse_wave", pos),
	})


func _on_reset_encounter() -> void:
	_dome_angle = 0.0
	_dome_turn_t = 0.0
	_bell_cd = 0.0
	_snuff_flash_t = 0.0
	_active_star_idx = 0
	_build_octagonal_stars()


func _on_engage() -> void:
	_build_octagonal_stars()
	_spawn_corner_bells(false)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Open a small central void eye cleanly reverted on reset_encounter!
		var tx: int = int(floorf(c.x / 16.0))
		var ty: int = int(floorf(c.y / 16.0))
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")
		props.clear()
		_spawn_corner_bells(true)
		stage.darkness_pulse(0.64, 1.0)
		stage.shake(0.22)
		stage.play_sfx("star_bell_turn", c)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_bell_cd = maxf(0.0, _bell_cd - dt)
	_snuff_flash_t = maxf(0.0, _snuff_flash_t - dt)
	if _dome_turn_t > 0.0:
		_dome_turn_t = maxf(0.0, _dome_turn_t - dt)
	# Relight extinguished stars when hung lantern or player bolts sweep them!
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for i: int in range(_stars.size()):
		var st: Dictionary = _stars[i]
		if not bool(st["lit"]):
			var sp: Vector2 = _star_pos(i)
			if lan_out and lan_p.distance_to(sp) <= 26.0:
				st["lit"] = true
				stage.play_sfx("star_ignite", sp)
			elif wick_node != null:
				for bv: Variant in wick_node.bolts:
					if bv is Object and (bv.get("pos") as Vector2).distance_to(sp) <= 13.0:
						st["lit"] = true
						stage.play_sfx("star_ignite", sp)
						break
		st["flash"] = maxf(0.0, float(st["flash"]) - dt)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	if _stars.is_empty():
		super._step_boss_reposition(dt, target)
		return
	var best_idx: int = (_active_star_idx + (1 if _orbit_side >= 0.0 else STAR_COUNT - 1)) % STAR_COUNT
	var goal: Vector2 = _star_pos(best_idx)
	var step: Vector2 = (goal - pos).limit_length(move_speed * (1.15 if phase >= 2 else 1.0) * dt)
	move_boss(step, true)
	if pos.distance_to(goal) <= 8.0:
		_extinguish_star(_active_star_idx)
		_active_star_idx = best_idx
	_face_point(target, 4.0, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	# Heavy/Throw/Beam during Divider Slice TELL mimics dome-drop stagger!
	if boss_state == BossState.TELL and active_attack_id == "divider_slice" and (bool(h["stagger"]) or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_BEAM]):
		_rotate_dome_90()
		return dmg * 1.35
	# Bonus crit when >= 6 of the 8 dome stars are lit (player controls the star floor!)
	if _count_lit_stars() >= 6:
		return dmg * 1.15
	return dmg


func _on_death_start() -> void:
	# Light all 8 dome stars permanently in silver-gold celebration!
	for st: Dictionary in _stars:
		st["lit"] = true
	stage.play_sfx("star_ignite", arena_rect.get_center())


func _build_octagonal_stars() -> void:
	_stars.clear()
	for k: int in range(STAR_COUNT):
		_stars.append({"idx": k, "lit": true, "flash": 0.0})


func _spawn_corner_bells(swapped: bool) -> void:
	var inset: Rect2 = arena_rect.grow(-24.0)
	var b1: Vector2 = inset.position if swapped else Vector2(inset.end.x, inset.position.y)
	var b2: Vector2 = inset.end if swapped else Vector2(inset.position.x, inset.end.y)
	props.spawn_bell(b1, func(_p: Dictionary) -> void: _rotate_dome_90(), "weaver_bell_a")
	props.spawn_bell(b2, func(_p: Dictionary) -> void: _rotate_dome_90(), "weaver_bell_b")


func _rotate_dome_90() -> void:
	if _bell_cd > 0.0:
		return
	_bell_cd = BELL_COOLDOWN
	_dome_angle = wrapf(_dome_angle + PI * 0.5, -PI, PI)
	_dome_turn_t = 0.75
	stage.play_sfx("star_bell_turn", arena_rect.get_center())
	stage.shake(0.20)
	# Relight 2 stars on turn; if Weaver was mid-TELL, its legs drop into void -> comedic bell-slam stagger!
	var lit_added: int = 0
	for st: Dictionary in _stars:
		if not bool(st["lit"]) and lit_added < 2:
			st["lit"] = true; st["flash"] = 0.45; lit_added += 1
	if boss_state == BossState.TELL:
		pos = clamp_to_arena(arena_rect.get_center() + Vector2(18.0, 0.0))
		position = pos.round()
		stage.play_sfx("warden_shield_break", pos)
		add_stagger(stagger_threshold)


func _star_pos(idx: int) -> Vector2:
	var c: Vector2 = arena_rect.get_center()
	var rx: float = maxf(46.0, arena_rect.size.x * 0.34)
	var ry: float = maxf(34.0, arena_rect.size.y * 0.34)
	var ang: float = _dome_angle + float(idx % STAR_COUNT) * (TAU / float(STAR_COUNT))
	return clamp_to_arena(c + Vector2(cos(ang) * rx, sin(ang) * ry))


func _nearest_star_idx(pt: Vector2) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in range(_stars.size()):
		var d: float = pt.distance_squared_to(_star_pos(i))
		if d < best_d:
			best_d = d; best = i
	return best


func _extinguish_star(idx: int) -> void:
	if _stars.is_empty():
		return
	var k: int = posmod(idx, _stars.size())
	if bool(_stars[k]["lit"]):
		_stars[k]["lit"] = false
		_stars[k]["flash"] = 0.35
		_snuff_flash_t = 0.30
		_snuff_pos = _star_pos(k)


func _count_lit_stars() -> int:
	var n: int = 0
	for st: Dictionary in _stars:
		if bool(st["lit"]): n += 1
	return n


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["plum"] if phase >= 2 else PAL["apricot"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	if _stars.is_empty():
		return
	var c_loc: Vector2 = (arena_rect.get_center() - pos + off).round()
	# Subtle dome compass meridian ring
	draw_arc(c_loc, 36.0, 0.0, TAU, 24, Color(PAL["gold"] as Color if _dome_turn_t > 0.0 else PAL["dusk"] as Color, 0.35), 1.2)
	# Octagonal 8-star constellation bridges & sockets
	for i: int in range(_stars.size()):
		var p0: Vector2 = (_star_pos(i) - pos + off).round()
		var p1: Vector2 = (_star_pos((i + 1) % STAR_COUNT) - pos + off).round()
		var lit0: bool = bool(_stars[i]["lit"])
		var lit1: bool = bool(_stars[(i + 1) % STAR_COUNT]["lit"])
		if lit0 and lit1:
			draw_line(p0, p1, Color(PAL["gold"] as Color, 0.50), 1.5)
		else:
			draw_line(p0, p1, Color(PAL["dusk"] as Color, 0.25), 1.0)
		if lit0:
			draw_circle(p0, 5.0, Color(PAL["gold"] as Color, 0.30))
			draw_rect(Rect2(p0 - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), PAL["gold"] as Color)
			draw_rect(Rect2(p0 - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
		else:
			draw_arc(p0, 4.5, 0.0, TAU, 10, Color(PAL["plum"] as Color, 0.55), 1.0)
	if _snuff_flash_t > 0.0:
		var sp: Vector2 = (_snuff_pos - pos + off).round()
		var u: float = 1.0 - clampf(_snuff_flash_t / 0.30, 0.0, 1.0)
		draw_arc(sp, lerpf(4.0, 16.0, u), 0.0, TAU, 12, Color(PAL["ice"] as Color, 1.0 - u), 1.2)
