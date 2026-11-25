class_name LxTwinMoonsBoss
extends LxBossBase
## Island 5 Dungeon A Boss (Meteor Vault, meteor_r11): The Twin Moons (Sola & Umbra).
## Sola (gold PUSH) & Umbra (indigo PULL) orbit as live moving LxFields gravity wells!
## Curved shots, Prism, Beam, or heavy hits knock the moons inward until they collide
## in an outraged twin-bell CLASH STAGGER (bonus clash dmg + polarity swap)!

class MoonField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 64.0
	var strength: float = 480.0
	var is_push: bool = false
	var active: bool = true

	func is_field_active() -> bool:
		return active and strength > 0.01

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not is_field_active():
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= radius * radius or d2 <= 0.0001:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		var falloff: float = (0.35 + 0.65 * u) * (1.0 - exp(-dist / 10.0))
		var mult: float = 1.15 if what in ["bolt", "beam"] else (0.90 if what == "lantern" else (0.10 if what == "wick" else 0.25))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const BASE_ORBIT_R: float = 46.0
const CLASH_THRESHOLD: float = 6.5

var _sola_field: MoonField = null
var _umbra_field: MoonField = null
var _fields_registered: bool = false
var _orbit_ang: float = 0.0
var _orbit_r: float = BASE_ORBIT_R
var _umbra_pos: Vector2 = Vector2.ZERO
var _swapped: bool = false
var _clash_charge: float = 0.0
var _clash_flash_t: float = 0.0
var _tether_active: bool = false
var _aim_dir: Vector2 = Vector2.LEFT


func _init() -> void:
	super._init()
	kind = "twin_moons"
	boss_id = "twin_moons"
	boss_name_key = "I5_BOSS_MOONS"
	island_id = 5
	is_miniboss = false
	reward_heart = "half"
	music_cue = "isl5_boss_minor_p1"
	music_p2_cue = "isl5_boss_minor_p2"
	max_hp = 116.0
	hp = 116.0
	body_radius = 12.0
	move_speed = 48.0
	stagger_threshold = 12.0
	stagger_duration = 1.60
	post_recover_cd = 0.30
	shard_drop = 28


func _exit_tree() -> void:
	_unregister_fields()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Tidal Pull / Repulse — twin gap rings from Sola & Umbra + targeted ring
	register_attack("tidal_wave", {
		"weight": 1.25, "tell": 0.65, "commit": 0.50, "recover": 1.00, "cooldown": 1.25,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			ground.warn_ring(pos, 26.0, last_tell_duration, 0.0, "gold", "cream")
			ground.warn_ring(_umbra_pos, 26.0, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "coral", "gold")
			stage.play_sfx("i5_gravity_bend", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var cnt: int = 12 if phase >= 2 else 10
			var spd: float = 124.0 if phase >= 3 else 110.0
			var gap_a: float = (tgt - pos).angle()
			patterns.emit_gap_ring(pos, cnt, spd, gap_a, 0.78, {"color": "gold", "source": "sola_tide", "field_scale": 0.90})
			patterns.emit_gap_ring(_umbra_pos, cnt - 2, spd * 0.92, (tgt - _umbra_pos).angle() + 0.35, 0.82, {"color": "sky", "source": "umbra_tide", "field_scale": 0.90})
			stage.shake(0.16)
			stage.play_sfx("eclipse_wave", pos),
	})

	# Attack 2: Eclipse Tether Sweep — gold-indigo chord connecting Sola & Umbra + curving twin fans
	register_attack("eclipse_tether", {
		"weight": 1.20, "tell": 0.72, "commit": 0.65, "recover": 1.15, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_tether_active = false
			ground.warn_lane(pos, _umbra_pos, 9.0, last_tell_duration, 0.0, "gold", "ice")
			ground.warn_lane(_umbra_pos, clamp_to_arena(tgt), 9.0, last_tell_duration, 0.0, "sky", "cream")
			stage.play_sfx("orrery_bell_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_tether_active = true
			patterns.emit_chain_lightning([pos, _umbra_pos], 0.45, 9.0, 0.28, 1.0)
			var fan_n: int = 5 if phase >= 2 else 3
			var d1: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			var d2: Vector2 = (tgt - _umbra_pos).normalized() if tgt.distance_to(_umbra_pos) > 0.1 else Vector2.RIGHT
			patterns.emit_fan(pos, d1, fan_n, 0.70, 134.0, {"color": "gold", "source": "tether_sola", "field_scale": 1.05})
			patterns.emit_fan(_umbra_pos, d2, fan_n, 0.70, 128.0, {"color": "sky", "source": "tether_umbra", "field_scale": 1.05})
			stage.shake(0.18)
			stage.play_sfx("orrery_beam_bolt", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_tether_active = false,
	})

	# Attack 3: Periapsis Meteor Hail — curving sky rings + boomerang meteors pressuring all 8 perimeter spots!
	register_attack("periapsis_hail", {
		"weight": 1.15, "tell": 0.60, "commit": 0.52, "recover": 1.05, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_hail_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 23.0, 1.0, "coral", "gold")
			stage.play_sfx("i5_meteor_hit", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d1: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_boomerang(pos, d1.rotated(0.32), 144.0, 0.68, 0.85, {"color": "apricot", "source": "periapsis_orb", "field_scale": 1.0})
			patterns.emit_boomerang(_umbra_pos, (tgt - _umbra_pos).normalized().rotated(-0.32), 138.0, 0.68, -0.85, {"color": "sky", "source": "periapsis_orb", "field_scale": 1.0})
			if phase >= 3:
				patterns.emit_expanding_square(arena_rect.get_center(), 3, 106.0, anim_t, 1, {"color": "gold", "source": "eclipse_square", "field_scale": 0.8})
			stage.shake(0.16)
			stage.play_sfx("i5_gravity_bend", pos),
	})

	# Attack 4 (P2/P3): Syzygy Eclipse — safe-zone inversion + orbiting star motes
	register_attack("syzygy_eclipse", {
		"phases": [2, 3], "weight": 1.35, "tell": 0.82, "commit": 0.44, "recover": 1.20, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var to_c: Vector2 = (c - tgt).normalized() if tgt.distance_to(c) > 4.0 else Vector2.RIGHT
			var s1: Vector2 = clamp_to_arena(tgt + to_c * 44.0)
			var s2: Vector2 = clamp_to_arena(c + (c - s1).limit_length(54.0))
			ground.warn_safe_inversion(arena_rect, [s1, s2], 28.0, last_tell_duration, 0.28, 1.0, "ice", "plum")
			stage.play_sfx("i5_moon_clash_bong", c),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_orbit(arena_rect.get_center(), 5 if phase >= 3 else 4, 48.0, 2.1, 2.2, {"color": "gold", "source": "syzygy_mote", "follow_boss": false})
			stage.light_burst(arena_rect.get_center(), 96.0, 1.4, 0.36)
			stage.shake(0.20),
	})


func _on_reset_encounter() -> void:
	_unregister_fields()
	_orbit_ang = 0.0
	_orbit_r = BASE_ORBIT_R
	_swapped = false
	_clash_charge = 0.0
	_clash_flash_t = 0.0
	_tether_active = false
	_umbra_pos = arena_rect.get_center() + Vector2(-BASE_ORBIT_R, 0.0)


func _on_engage() -> void:
	_ensure_fields()
	var c: Vector2 = arena_rect.get_center()
	props.spawn_pillar(c + Vector2(-62.0, -34.0), 5.0, "moon_bumper_nw")
	props.spawn_pillar(c + Vector2(62.0, -34.0), 5.0, "moon_bumper_ne")
	props.spawn_pillar(c + Vector2(-62.0, 34.0), 5.0, "moon_bumper_sw")
	props.spawn_pillar(c + Vector2(62.0, 34.0), 5.0, "moon_bumper_se")


func _on_death_start() -> void:
	_unregister_fields()


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		_swap_polarities()
		var ts: float = 16.0
		var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
		var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
		var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_n, 1, 2), "pit")
		stage.darkness_pulse(0.64, 1.0)
		stage.shake(0.22)
		stage.play_sfx("i5_moon_clash_bong", c)
	elif new_phase == 3:
		_swap_polarities()
		# Crumble 2 bumper pillars leaving wide orbital space
		for pid: String in ["moon_bumper_nw", "moon_bumper_se"]:
			var p: Dictionary = props.get_prop(pid)
			if not p.is_empty():
				p["state"] = "broken"; p["solid"] = false
		stage.darkness_pulse(0.72, 1.1)
		stage.shake(0.26)
		stage.play_sfx("boss_roar", c)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clash_flash_t = maxf(0.0, _clash_flash_t - dt)
	var c: Vector2 = arena_rect.get_center()
	var target_r: float = (34.0 if phase >= 3 else (40.0 if phase == 2 else BASE_ORBIT_R)) * (1.0 - clampf(_clash_charge / CLASH_THRESHOLD, 0.0, 0.55))
	_orbit_r = move_toward(_orbit_r, target_r, 36.0 * dt)
	if boss_state in [BossState.READY, BossState.TELL, BossState.COMMIT]:
		var spd: float = 1.45 if phase >= 3 else (1.10 if phase == 2 else 0.82)
		_orbit_ang = wrapf(_orbit_ang + spd * dt * (1.0 if not _swapped else -1.0), -PI, PI)
	# Sola = primary body pos; Umbra = counter-orbiting twin opposite center!
	var sola_des: Vector2 = clamp_to_arena(c + Vector2.from_angle(_orbit_ang) * _orbit_r)
	var step: Vector2 = (sola_des - pos).limit_length(move_speed * 2.2 * dt)
	move_boss(step, true)
	_umbra_pos = clamp_to_arena(c - Vector2.from_angle(_orbit_ang) * _orbit_r)

	# Hung lantern near Umbra tugs the moons inward toward CLASH!
	if _is_lantern_out() and _get_lantern_pos().distance_to(_umbra_pos) <= 58.0 and boss_state != BossState.STAGGER:
		_clash_charge += 0.90 * dt
		if _clash_charge >= CLASH_THRESHOLD:
			_trigger_moon_clash()

	if _sola_field != null:
		_sola_field.pos = pos
		_sola_field.is_push = not _swapped
	if _umbra_field != null:
		_umbra_field.pos = _umbra_pos
		_umbra_field.is_push = _swapped


func _step_boss_reposition(_dt: float, target: Vector2) -> void:
	_face_point(target, 4.0, _dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 20.0
	var high_impact: bool = is_curved or src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL]

	if high_impact and boss_state != BossState.STAGGER:
		_clash_charge += 2.2 if is_curved else 1.5
		if _clash_charge >= CLASH_THRESHOLD:
			_trigger_moon_clash()
		return dmg * (1.35 if is_curved else 1.12)
	return dmg


func _trigger_moon_clash() -> void:
	_clash_charge = 0.0
	_clash_flash_t = 0.42
	var mid: Vector2 = pos.lerp(_umbra_pos, 0.5)
	hp = maxf(1.0, hp - 3.5)
	_swap_polarities()
	_orbit_r = BASE_ORBIT_R + 12.0
	stage.play_sfx("i5_moon_clash_bong", mid)
	stage.shake(0.24)
	stage.light_burst(mid, 92.0, 1.5, 0.35)
	add_stagger(stagger_threshold)


func _swap_polarities() -> void:
	_swapped = not _swapped
	stage.play_sfx("i5_well_polarity", arena_rect.get_center())


func _ensure_fields() -> void:
	if _sola_field == null: _sola_field = MoonField.new()
	if _umbra_field == null: _umbra_field = MoonField.new()
	_sola_field.is_push = not _swapped; _sola_field.active = true
	_umbra_field.is_push = _swapped; _umbra_field.active = true
	if not _fields_registered:
		LxFields.add(_sola_field)
		LxFields.add(_umbra_field)
		_fields_registered = true


func _unregister_fields() -> void:
	if _fields_registered:
		if _sola_field != null: LxFields.remove(_sola_field)
		if _umbra_field != null: LxFields.remove(_umbra_field)
		_fields_registered = false


func _build_hail_targets(tgt: Vector2) -> Array[Vector2]:
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
		out.append(arena_rect.get_center().lerp(tgt, 0.5))
	if phase >= 3:
		out.append(corners[2])
	return out


func _body_color() -> Color:
	return (PAL["sky"] if _swapped else PAL["gold"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var u_loc: Vector2 = (_umbra_pos - pos + off).round()
	var s_loc: Vector2 = off.round()
	var sola_c: Color = (PAL["sky"] if _swapped else PAL["gold"]) as Color
	var umbra_c: Color = (PAL["gold"] if _swapped else PAL["sky"]) as Color

	# Meridian track & live gravity rings around Sola and Umbra
	var c_loc: Vector2 = (arena_rect.get_center() - pos + off).round()
	draw_arc(c_loc, _orbit_r, 0.0, TAU, 32, Color(PAL["gold"] as Color if phase >= 2 else PAL["dusk"] as Color, 0.32), 1.0)
	if _fields_registered:
		draw_arc(s_loc, _sola_field.radius, 0.0, TAU, 28, Color(sola_c, 0.24), 1.0)
		draw_arc(u_loc, _umbra_field.radius, 0.0, TAU, 28, Color(umbra_c, 0.24), 1.0)

	# Syzygy tether chord connecting the twin moons in P2+ or active tether
	if phase >= 2 or _tether_active:
		draw_line(s_loc, u_loc, Color(sola_c, 0.65), 2.5 if _tether_active else 1.2)
		if _tether_active:
			draw_line(s_loc, u_loc, PAL["cream"] as Color, 1.0)

	# Draw live satellite twin (Umbra) at its independent counter-orbiting world coordinate!
	draw_circle(u_loc + Vector2(0.0, 9.0), 9.0, Color(PAL["void"] as Color, 0.36))
	draw_arc(u_loc, 12.5, 0.0, TAU, 20, umbra_c, 1.5)
	draw_circle(u_loc, 10.0, PAL["night"] as Color)
	draw_circle(u_loc, 8.8, PAL["apricot"] as Color if _swapped else PAL["blue"] as Color)
	draw_circle(u_loc + Vector2(-2.0, -2.0), 4.0, PAL["gold"] as Color if _swapped else PAL["sky"] as Color)
	draw_line(u_loc + Vector2(-7.0, 0.0), u_loc + Vector2(7.0, 0.0), PAL["cream"] as Color if _swapped else PAL["ice"] as Color, 1.0)
	draw_rect(Rect2(u_loc + Vector2(-1.0, -2.0), Vector2(2.0, 2.0)), PAL["cream"] as Color)

	# Clash burst flash
	if _clash_flash_t > 0.0:
		var mid: Vector2 = s_loc.lerp(u_loc, 0.5)
		var u: float = 1.0 - clampf(_clash_flash_t / 0.42, 0.0, 1.0)
		draw_arc(mid, lerpf(8.0, 38.0, u), 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
		draw_arc(mid, lerpf(4.0, 28.0, u), 0.0, TAU, 18, PAL["cream"] as Color, 1.2)
