class_name LxDredgeHulkBoss
extends LxBossBase
## Island 2 Mini-Boss B: THE DREDGE HULK (`dredge_hulk`, `locks_r6`).
## Armored smuggling turret-barge in a circular flooded basin (Skiff duel).
## Armored prow/flanks deflect non-punish frontal yellow bolts (0.40x);
## glowing Brass Rudder Stern takes 1.65x + coughs panicked cream smoke rings!
## Interactive wake mines can be shot/batted/harpooned into its stern for 2.0x + 1.4s stall.
## P2 (50%): opens sluice vents -> swirling moat LxFields current, outer sluice tile flood,
## reversed orbit, and Bilge Ram!

const FRONT_ARMOR_HALF: float = 1.05
const STERN_WEAK_HALF: float = 1.15

var _aim_dir: Vector2 = Vector2.LEFT
var _ram_dir: Vector2 = Vector2.LEFT
var _orbit_ang: float = 0.0
var _orbit_sign: float = 1.0
var _smoke_rings: Array[Dictionary] = [] # {pos, age, life, r}
var _mines: Array[Dictionary] = [] # {pos, vel, arm_t, ttl, batted}
var _swirl_field: _DredgeSwirlField = null


class _DredgeSwirlField:
	extends RefCounted
	var active: bool = false
	var center: Vector2 = Vector2.ZERO
	var radius: float = 156.0
	var swirl_sign: float = 1.0
	var strength: float = 64.0
	func is_field_active() -> bool:
		return active
	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var rel: Vector2 = p - center
		var d: float = rel.length()
		if d < 12.0 or d > radius:
			return Vector2.ZERO
		var tang := Vector2(-rel.y, rel.x) / d * swirl_sign
		var mult: float = 0.26 if what in ["bolt", "lantern", "block"] else (0.24 if what == "wick" else 0.30)
		return tang * (strength * mult)


func _init() -> void:
	super._init()
	kind = "dredge_hulk"
	boss_id = "dredge_hulk"
	boss_name_key = "BOSS_DREDGE"
	island_id = 2
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 60.0
	hp = 60.0
	body_radius = 13.0
	move_speed = 36.0
	stagger_threshold = 11.0
	stagger_duration = 1.45
	punish_dmg_mult = 1.30
	post_recover_cd = 0.38
	shard_drop = 18
	intro_duration = 0.70
	phase_shift_duration = 0.75
	death_duration = 2.2


func _exit_tree() -> void:
	_unregister_swirl()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Broadside Volley (3 sightlines -> aimed fan + splash)
	register_attack("broadside_volley", {
		"weight": 1.25, "tell": 0.60, "commit": 0.28, "recover": 1.15, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			for off_a: float in [-0.34, 0.0, 0.34]:
				var ld: Vector2 = _aim_dir.rotated(off_a)
				ground.warn_lane(pos, pos + ld * 144.0, 7.5, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("dredge_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.94, 122.0, {"color": "coral", "source": "dredge_broadside", "field_scale": 0.85, "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("barnacle_fire", pos),
	})

	# Attack 2: Mine Wake Drop (drops 2 interactive stern mines + gap ring + perimeter rain)
	register_attack("mine_wake_drop", {
		"weight": 1.20, "tell": 0.56, "commit": 0.25, "recover": 1.10, "cooldown": 1.70,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var back: Vector2 = -Vector2.from_angle(facing)
			var perp := Vector2(-back.y, back.x)
			for sgn: float in [-1.0, 1.0]:
				ground.warn_ring(clamp_to_arena(pos + back * 24.0 + perp * (sgn * 18.0)), 18.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_ring(clamp_to_arena(tgt), 18.0, last_tell_duration + 0.06, 0.5, "coral", "gold")
			stage.play_sfx("mine_clang", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var back: Vector2 = -Vector2.from_angle(facing)
			var perp := Vector2(-back.y, back.x)
			for sgn: float in [-1.0, 1.0]:
				_spawn_wake_mine(clamp_to_arena(pos + back * 24.0 + perp * (sgn * 18.0)), back * 24.0 + perp * (sgn * 18.0))
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 104.0, aim_a + 0.55, 0.92, {"color": "sky", "source": "dredge_wake", "field_scale": 0.8, "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("tide_wave", pos),
	})

	# Attack 3: Sluice Mortar (pressures Wick + nearest perimeter corners so zero safe spots!)
	register_attack("sluice_mortar", {
		"weight": 1.15, "tell": 0.62, "commit": 0.34, "recover": 1.15, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _perimeter_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 19.0, 0.5, "coral", "gold")
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, _aim_dir, 3, 128.0, 0.09, {"color": "gold", "source": "dredge_mortar", "field_scale": 0.85, "damage": 0.5})
			stage.shake(0.15)
			stage.play_sfx("barnacle_fire", pos),
	})

	# Attack 4 (P2): Bilge Ram (high-speed foam ram charge + twin wake spreads)
	register_attack("bilge_ram", {
		"phases": [2], "weight": 2.40, "tell": 0.64, "commit": 0.44, "recover": 1.30, "cooldown": 1.25,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_ram_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _ram_dir * 144.0), 14.0, last_tell_duration, 0.5, "sky", "coral")
			stage.play_sfx("dredge_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _ram_dir.rotated(PI * 0.45), 2, 0.55, 108.0, {"color": "ice", "source": "dredge_bow_wake", "field_scale": 0.9, "damage": 0.5})
			patterns.emit_fan(pos, _ram_dir.rotated(-PI * 0.45), 2, 0.55, 108.0, {"color": "ice", "source": "dredge_bow_wake", "field_scale": 0.9, "damage": 0.5})
			stage.shake(0.20)
			stage.play_sfx("tide_surge", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_ram_dir * 138.0 * dt, true)
			check_contact_damage(body_radius + 11.0, _ram_dir, 0.5, "dredge_ram"),
	})


func _on_reset_encounter() -> void:
	_unregister_swirl()
	_orbit_ang = 0.0
	_orbit_sign = 1.0
	_smoke_rings.clear()
	_mines.clear()


func _on_engage() -> void:
	stage.play_sfx("dredge_whistle", pos)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_orbit_sign = -_orbit_sign
		if _swirl_field == null:
			_swirl_field = _DredgeSwirlField.new()
		_swirl_field.center = arena_rect.get_center()
		_swirl_field.swirl_sign = _orbit_sign
		_swirl_field.active = true
		LxFields.add(_swirl_field)
		# P2 Arena Mutation: sluice vents flood outer basin corners (reverted cleanly on retry!)
		var ts: float = 16.0
		var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
		var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
		var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
		var ty_s: int = int(floorf((arena_rect.end.y - 20.0) / ts))
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_s - 1, 1, 2), "water")
		stage.darkness_pulse(0.56, 0.9)
		stage.shake(0.24)
		stage.play_sfx("dredge_whistle", pos)


func _on_death_start() -> void:
	_unregister_swirl()
	_mines.clear()
	if Lx.state != null:
		Lx.state.story_flags["power_sluice_harpoon"] = true
	stage.play_sfx("hull_sink", pos)


func _unregister_swirl() -> void:
	if _swirl_field != null:
		_swirl_field.active = false
		LxFields.remove(_swirl_field)
		_swirl_field = null


func _on_boss_tick(dt: float, target: Vector2) -> void:
	for i: int in range(_smoke_rings.size() - 1, -1, -1):
		_smoke_rings[i]["age"] = float(_smoke_rings[i]["age"]) + dt
		var sp: Vector2 = _smoke_rings[i]["pos"] as Vector2
		_smoke_rings[i]["pos"] = sp + Vector2(0.0, -16.0 * dt)
		if float(_smoke_rings[i]["age"]) >= float(_smoke_rings[i]["life"]):
			_smoke_rings.remove_at(i)
	_tick_wake_mines(dt, target)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	_orbit_ang = wrapf(_orbit_ang + (0.88 if phase >= 2 else 0.58) * _orbit_sign * dt, -PI, PI)
	var orbit_r: float = minf(arena_rect.size.x, arena_rect.size.y) * 0.28
	var des: Vector2 = clamp_to_arena(c + Vector2.from_angle(_orbit_ang) * orbit_r)
	var step: Vector2 = (des - pos).limit_length(move_speed * dt)
	move_boss(step, true)
	_face_point(target, 3.2, dt)


func _spawn_wake_mine(at_pos: Vector2, init_vel: Vector2) -> void:
	if _mines.size() >= 4:
		_mines.remove_at(0)
	_mines.append({"pos": at_pos, "vel": init_vel, "ttl": 7.5, "batted": false})


func _tick_wake_mines(dt: float, target: Vector2) -> void:
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	for i: int in range(_mines.size() - 1, -1, -1):
		var m: Dictionary = _mines[i]
		m["ttl"] = float(m["ttl"]) - dt
		var mp: Vector2 = m["pos"] as Vector2
		var mv: Vector2 = m["vel"] as Vector2
		# Sluice Harpoon / lantern proximity bats mine straight into Hulk's stern!
		if not bool(m["batted"]) and lan_out and mp.distance_to(lan_p) <= 22.0:
			var to_hulk: Vector2 = (pos - mp).normalized() if pos.distance_to(mp) > 2.0 else Vector2.RIGHT
			mv = to_hulk * 165.0
			m["batted"] = true
			stage.play_sfx("mine_clang", mp)
		# Skiff dash or fast pass bats mine!
		elif not bool(m["batted"]) and Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if (w.is_dashing() or w.is_mounted()) and mp.distance_to(target) <= 24.0:
				var to_h: Vector2 = (pos - mp).normalized() if pos.distance_to(mp) > 2.0 else Vector2.RIGHT
				mv = to_h * 175.0
				m["batted"] = true
				stage.play_sfx("mine_clang", mp)
		mp = clamp_to_arena(mp + mv * dt)
		mv *= exp(-1.8 * dt)
		m["pos"] = mp
		m["vel"] = mv
		if bool(m["batted"]) and mp.distance_to(pos) <= body_radius + 11.0:
			hp = maxf(0.5, hp - 3.2)
			_cough_smoke_ring()
			add_stagger(stagger_threshold)
			stage.shake(0.22)
			stage.play_sfx("mine_blast", mp)
			_mines.remove_at(i)
			continue
		if float(m["ttl"]) <= 0.0:
			_mines.remove_at(i)


func _cough_smoke_ring() -> void:
	if _smoke_rings.size() >= 6:
		_smoke_rings.remove_at(0)
	_smoke_rings.append({"pos": pos + Vector2(-8.0, -24.0), "age": 0.0, "life": 0.75, "r": 3.5})


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	if hit.is_blue() or hit.source == LxHit.SOURCE_BEAM or hit.cracks_armour:
		_cough_smoke_ring()
		return dmg * 1.38
	var rel: Vector2 = hit.origin - pos
	if rel.length() > 0.01:
		var ang: float = rel.angle()
		# Glowing Brass Rudder Stern weakpoint behind facing!
		if absf(angle_difference(wrapf(facing + PI, -PI, PI), ang)) <= STERN_WEAK_HALF:
			_cough_smoke_ring()
			return dmg * 1.65
		# Armored iron prow & flanks reduce non-punish yellow chip bolts
		if not is_punishable() and absf(angle_difference(facing, ang)) <= FRONT_ARMOR_HALF and hit.source == LxHit.SOURCE_BOLT and not hit.pierce:
			clank_t = 0.12
			return dmg * 0.45
	return dmg


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	return out


func _body_color() -> Color:
	return PAL["deep"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Glowing Brass Rudder Stern weakpoint indicator astern
	var stern_p: Vector2 = (off - Vector2.from_angle(facing) * (body_radius + 4.0)).round()
	draw_circle(stern_p, 4.2, PAL["coral"] as Color)
	draw_circle(stern_p, 2.5, PAL["gold"] as Color)
	draw_rect(Rect2(stern_p - Vector2(0.5, 0.5), Vector2.ONE), PAL["cream"] as Color)
	# Panicked smokestack cream smoke rings!
	for sr: Dictionary in _smoke_rings:
		var u: float = clampf(float(sr["age"]) / maxf(0.01, float(sr["life"])), 0.0, 1.0)
		var lp: Vector2 = ((sr["pos"] as Vector2) - pos + off).round()
		draw_arc(lp, lerpf(3.0, 9.0, u), 0.0, TAU, 12, Color(PAL["cream"] as Color, 1.0 - u), 1.0)
	# Interactive wake mines
	for m: Dictionary in _mines:
		var mp: Vector2 = ((m["pos"] as Vector2) - pos + off).round()
		var bat: bool = bool(m["batted"])
		draw_circle(mp, 5.5, PAL["night"] as Color)
		draw_circle(mp, 4.0, PAL["gold" if bat else "coral"] as Color)
		draw_arc(mp, 6.5, 0.0, TAU, 10, PAL["cream" if bat else "apricot"] as Color, 1.0)
	# P2 circular moat current ring
	if _swirl_field != null and _swirl_field.active:
		var cc: Vector2 = (_swirl_field.center - pos + off).round()
		draw_arc(cc, 68.0, anim_t * _orbit_sign, anim_t * _orbit_sign + PI * 1.4, 24, Color(PAL["sky"] as Color, 0.35), 1.0)
