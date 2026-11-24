class_name LxQueenInGlassBoss
extends LxBossBase
## Island 7 Boss: QUEEN IN THE GLASS (Inverted Palace Boss, palace_r12).
## Frontal mirror pane bounces raw Yellow bolts harmlessly — damage her through Blue banks,
## reflected Crown Shards, Mirror Avatar hits, Black-world flips, or Beam/Sunflare/flank punishes!
## P1 (100-66%): Mirror-pane court. P2 (66-33%): Shatters barrier into 3 orbiting mirror-shields
## + arena rift + glass pillars! P3 (<=33%): Steps forth with 2 NW-shadow clones (real Queen casts SE shadow).
## Whenever struck via mirror/opening, her serene face stays calm while her reflection screams in rose cracks.

var _aim_dir: Vector2 = Vector2.LEFT
var _reflect_scream_t: float = 0.0
var _reflect_bounce_t: float = 0.0
var _bounce_dir: Vector2 = Vector2.RIGHT
var _orbit_shields: int = 0
var _orbit_ang: float = 0.0
var _clones: Array[Dictionary] = []
var _lunge_dir: Vector2 = Vector2.LEFT


func _init() -> void:
	super._init()
	kind = "queen_in_glass"
	boss_id = "queen_in_glass"
	boss_name_key = "ISL7_BOSS_QUEEN"
	island_id = 7
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 186.0
	hp = 186.0
	body_radius = 11.0
	move_speed = 36.0
	stagger_threshold = 24.0
	stagger_duration = 1.60
	post_recover_cd = 0.34
	shard_drop = 40


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Crown Shard Fan — 5 (P2+: 7) reflectable silver-ice needles + perimeter check
	register_attack("crown_shard_fan", {
		"weight": 1.25, "tell": 0.50, "commit": 0.32, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var a: float = _aim_dir.angle()
			ground.warn_sector(pos, a - 0.55, a + 0.55, 130.0, last_tell_duration, 0.0, "sky", "ice")
			stage.play_sfx("glass_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var cnt: int = 7 if phase >= 2 else 5
			var spd: float = 152.0 if phase >= 3 else 140.0
			patterns.emit_fan(pos, _aim_dir, cnt, 0.92, spd, {"color": "ice", "source": "crown_shard", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("mirror_ping", pos),
	})

	# Attack 2: Looking-Glass Beam — 175px prism sweep; opens back cleanly during 1.30s recover!
	register_attack("looking_glass_beam", {
		"weight": 1.20, "tell": 0.58, "commit": 0.34, "recover": 1.30, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + _aim_dir * 185.0, 12.0, last_tell_duration, 1.0, "sky", "cream")
			stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _aim_dir, 4 if phase >= 2 else 3, 185.0, 0.055, {"color": "sky", "source": "looking_glass_beam", "reflectable": true})
			if phase >= 2:
				patterns.emit_fan(pos, _aim_dir, 3, 0.45, 135.0, {"color": "rose", "source": "prism_split", "reflectable": true})
			stage.light_burst(pos, 84.0, 1.35, 0.30)
			stage.shake(0.18)
			stage.play_sfx("prism_beam", pos),
	})

	# Attack 3: Prism Rain Court — drops crystalline rings on Wick & nearest corners (zero safe spots!)
	register_attack("prism_rain_court", {
		"weight": 1.05, "tell": 0.54, "commit": 0.36, "recover": 1.20, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_court_rain(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "rose" if phase >= 2 else "sky", "ice")
			stage.play_sfx("glass_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_gap_ring(pos, 10, 118.0, d.angle() + PI * 0.4, 0.72, {"color": "ice", "source": "court_ring", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("mirror_crack", pos),
	})

	# Attack 4 (P2+): Mirror Carousel — 3 orbiting glass panes + expanding ice gap-rings!
	register_attack("mirror_carousel", {
		"phases": [2, 3], "weight": 1.35, "tell": 0.54, "commit": 0.85, "recover": 1.25, "cooldown": 2.4,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_ring(pos, 42.0, last_tell_duration, 1.0, "rose", "ice")
			stage.play_sfx("glass_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.RIGHT
			patterns.emit_orbit(pos, 3, 44.0, 2.4, 2.2, {"color": "ice", "source": "carousel_pane", "reflectable": true, "follow_boss": true})
			patterns.emit_gap_ring(pos, 12, 122.0, d.angle(), 0.72, {"color": "sky", "source": "carousel_ring", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("mirror_ping", pos),
	})

	# Attack 5 (P3): Royal Reflection — 2 NW-shadow clones cross-lunge while real SE-shadow Queen leads!
	register_attack("royal_reflection", {
		"phases": [3], "weight": 1.50, "tell": 0.56, "commit": 0.34, "recover": 1.35, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_spawn_p3_clones(tgt)
			ground.warn_lane(pos, clamp_to_arena(pos + _lunge_dir * 110.0), 11.0, last_tell_duration, 0.0, "rose", "cream")
			for cl: Dictionary in _clones:
				var cp: Vector2 = cl["pos"] as Vector2
				var cd: Vector2 = (tgt - cp).normalized() if tgt.distance_to(cp) > 0.1 else -_lunge_dir
				cl["dir"] = cd
				ground.warn_lane(cp, clamp_to_arena(cp + cd * 95.0), 9.0, last_tell_duration, 1.0, "sky", "ice")
			stage.play_sfx("glass_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("hollow_dash", pos)
			for cl: Dictionary in _clones:
				var cp: Vector2 = cl["pos"] as Vector2
				var cd: Vector2 = cl["dir"] as Vector2
				patterns.emit_fan(cp, cd, 3, 0.50, 138.0, {"color": "sky", "source": "clone_shard", "reflectable": true}),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_lunge_dir * 210.0 * dt, false)
			check_contact_damage(18.0, _lunge_dir, 1.0, "royal_lunge")
			for cl: Dictionary in _clones:
				cl["pos"] = clamp_to_arena((cl["pos"] as Vector2) + (cl["dir"] as Vector2) * 185.0 * dt),
	})


func _on_reset_encounter() -> void:
	_reflect_scream_t = 0.0
	_reflect_bounce_t = 0.0
	_orbit_shields = 0
	_orbit_ang = 0.0
	_clones.clear()


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_reflect_scream_t = maxf(0.0, _reflect_scream_t - dt)
	_reflect_bounce_t = maxf(0.0, _reflect_bounce_t - dt)
	_orbit_ang = wrapf(_orbit_ang + dt * 2.1, -PI, PI)
	if _is_black_world() and _orbit_shields > 0:
		_orbit_shields = 0
		stage.play_sfx("glass_shatter", pos)


func _is_black_world() -> bool:
	if Lx.vars == null:
		return false
	return Lx.vars.eval("world_face==black", island_id, "")


func _has_active_shield() -> bool:
	return not _is_black_world() and not is_punishable() and phase <= 2


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if dmg >= max_hp * 0.25:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < 1.15
	var is_mirror_avatar: bool = src == "mirror_avatar" or (hit.attacker is Node and (hit.attacker as Node).is_in_group("mirror_avatar"))
	var is_reflected_or_blue: bool = hit.is_blue() or is_mirror_avatar
	var is_heavy_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"]) or bool(h["cracks_armour"])
	var is_flank_or_open: bool = not is_front or is_punishable() or _is_black_world()

	# Frontal glass pane bounces raw direct Yellow bolts harmlessly!
	if src == LxHit.SOURCE_BOLT and not is_reflected_or_blue and not _is_black_world() and is_front and not is_punishable():
		_reflect_bounce_t = 0.24
		_bounce_dir = rel.normalized() if rel.length() > 0.1 else Vector2.from_angle(facing)
		clank_t = 0.14
		stage.play_sfx("mirror_ping", pos)
		return 0.0

	# Mirror/Blue/Black/Opening hits fracture her reflection!
	_reflect_scream_t = 0.42
	if _orbit_shields > 0 and (is_reflected_or_blue or is_heavy_pierce or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]):
		_orbit_shields = maxi(0, _orbit_shields - 1)
		stage.play_sfx("mirror_crack", pos)
		if _orbit_shields == 0:
			add_stagger(stagger_threshold * 0.75)

	if is_reflected_or_blue:
		stage.play_sfx("mirror_crack", pos)
		return dmg * 1.30
	if _is_black_world():
		return dmg * 1.15
	if is_punishable():
		return dmg * 0.78
	if is_flank_or_open or is_heavy_pierce:
		return dmg * 0.35
	return dmg * 0.20


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		_orbit_shields = 0 if _is_black_world() else 3
		# Arena change: glass barrier shatters into corner pits + 2 crystalline pillars!
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-48.0, -26.0), 4.0, "queen_pillar_w")
		props.spawn_pillar(c + Vector2(48.0, 26.0), 4.0, "queen_pillar_e")
		stage.darkness_pulse(0.60, 1.0)
		stage.shake(0.24)
		stage.play_sfx("glass_shatter", pos)
	elif new_phase == 3:
		_orbit_shields = 0
		_spawn_p3_clones(_get_wick_pos())
		stage.darkness_pulse(0.68, 1.0)
		stage.shake(0.26)
		stage.play_sfx("mirror_crack", pos)


func _spawn_p3_clones(tgt: Vector2) -> void:
	_clones.clear()
	var c: Vector2 = arena_rect.get_center()
	var base_a: float = (pos - c).angle() if pos.distance_to(c) > 4.0 else 0.0
	for k: int in [1, 2]:
		var ang: float = base_a + float(k) * (TAU / 3.0)
		var cp: Vector2 = clamp_to_arena(c + Vector2.from_angle(ang) * 58.0)
		_clones.append({"pos": cp, "dir": (tgt - cp).normalized()})


func _build_court_rain(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(clamp_to_arena(corners[0]))
	out.append(clamp_to_arena(corners[1]))
	if phase >= 2:
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	return out


func _on_death_start() -> void:
	_clones.clear()
	stage.play_sfx("glass_shatter", pos)


func _body_color() -> Color:
	return PAL["ice"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Real Queen casts crisp warm SE shadow (truth cue in P3!)
	draw_circle(Vector2(6.0, 5.0), 10.0, Color(PAL["void"] as Color, 0.42))

	# Frontal glass mirror pane + silver bounce arrow when direct yellow bolt bounces
	if _has_active_shield():
		var fwd: Vector2 = Vector2.from_angle(facing)
		draw_arc(c, body_radius + 7.0, facing - 1.05, facing + 1.05, 14, PAL["ice"] as Color, 2.0)
		if _reflect_bounce_t > 0.0:
			draw_line(c + fwd * 12.0, (c + _bounce_dir * 34.0).round(), PAL["cream"] as Color, 1.8)

	# P2 Orbiting mirror-shields
	if _orbit_shields > 0:
		for si: int in range(_orbit_shields):
			var sa: float = _orbit_ang + float(si) * (TAU / float(_orbit_shields))
			var sp: Vector2 = (c + Vector2.from_angle(sa) * 24.0).round()
			var scol: Color = (PAL["rose"] if _is_black_world() else PAL["ice"]) as Color
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -5), sp + Vector2(3, 0), sp + Vector2(0, 5), sp + Vector2(-3, 0)]), scol)

	# Horror beat: when struck via reflection, her reflection screams silently in rose cracks beside her!
	if _reflect_scream_t > 0.0:
		var rp: Vector2 = (c + Vector2(18.0, -14.0)).round()
		draw_circle(rp, 7.0, Color(PAL["plum"] as Color, 0.55))
		draw_arc(rp, 7.0, 0.0, TAU, 14, PAL["rose"] as Color, 1.4)
		draw_line(rp + Vector2(-4, -4), rp + Vector2(4, 4), PAL["cream"] as Color, 1.0)
		draw_line(rp + Vector2(3, -4), rp + Vector2(-3, 4), PAL["rose"] as Color, 1.0)
		draw_circle(rp + Vector2(0, 2), 2.2, PAL["void"] as Color)

	# P3 NW-shadow mirror clones (visibly cast NW shadow instead of SE!)
	for cl: Dictionary in _clones:
		var lp: Vector2 = ((cl["pos"] as Vector2) - pos).round()
		draw_circle(lp + Vector2(-7.0, -5.0), 9.0, Color(PAL["void"] as Color, 0.45))
		draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -18), lp + Vector2(9, 2), lp + Vector2(-9, 2)]), Color(PAL["sky"] as Color, 0.65))
		draw_arc(lp + Vector2(0, -10), 8.0, 0.0, TAU, 12, PAL["ice"] as Color, 1.2)
