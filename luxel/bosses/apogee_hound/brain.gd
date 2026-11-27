class_name LxApogeeHoundBoss
extends LxBossBase
## Island 5 Mini-Boss (Meteor Vault, meteor_r6): The Apogee Hound.
## Iron-crested meteor wolf orbiting a central switchable polarity well (LxFields).
## Straight front bolts clank off its iron brow plate; flank/curved shots or flipping
## the central well to PUSH during Orbital Pounce derail & stagger it!

class WellField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 68.0
	var strength: float = 540.0
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
		var mult: float = 1.20 if what in ["bolt", "beam"] else (0.90 if what == "lantern" else (0.10 if what == "wick" else 0.32))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const FRONT_BROW_HALF: float = 0.90
const POUNCE_SPEED: float = 232.0

var _well: WellField = null
var _well_registered: bool = false
var _well_phase_anim: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT
var _pounce_vel: Vector2 = Vector2.ZERO
var _orbit_angle: float = 0.0
var _cycle_count: int = 0
var _pounce_curve_pts: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	super._init()
	kind = "apogee_hound"
	boss_id = "apogee_hound"
	boss_name_key = "I5_BOSS_HOUND"
	island_id = 5
	is_miniboss = true
	reward_heart = "half"
	music_cue = "isl5_boss_minor_p1"
	music_p2_cue = "isl5_boss_minor_p2"
	max_hp = 64.0
	hp = 64.0
	body_radius = 10.5
	move_speed = 54.0
	stagger_threshold = 9.0
	stagger_duration = 1.40
	post_recover_cd = 0.26
	shard_drop = 18


func _exit_tree() -> void:
	_unregister_well()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Elliptical Kick — curving meteor fan + targeted outer meteor drops
	register_attack("elliptical_kick", {
		"weight": 1.25, "tell": 0.58, "commit": 0.38, "recover": 0.95, "cooldown": 1.15,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 136.0), 10.0, last_tell_duration, 0.0, "apricot", "gold")
			var drops: Array[Vector2] = [clamp_to_arena(tgt)]
			if phase >= 2:
				drops.append(_nearest_corner(tgt))
			patterns.emit_rain(ground, drops, last_tell_duration + 0.06, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("i5_comet_bark", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var cnt: int = 5 if phase >= 2 else 3
			var spd: float = 148.0 if phase >= 2 else 134.0
			patterns.emit_fan(pos, _aim_dir, cnt, 0.78, spd, {"color": "apricot", "source": "apogee_meteor", "field_scale": 1.20})
			if phase >= 2:
				patterns.emit_fan(pos, -_aim_dir, 3, 0.65, 118.0, {"color": "coral", "source": "apogee_scatter", "field_scale": 1.15})
			stage.shake(0.14)
			stage.play_sfx("i5_meteor_hit", pos),
	})

	# Attack 2: Orbital Pounce — curved LxFields-bent lunge; PUSH well derails into wall -> stagger!
	register_attack("orbital_pounce", {
		"weight": 1.20, "tell": 0.62, "commit": 0.44, "recover": 1.10, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_pounce_curve_pts = LxFields.sample_curve(pos, _aim_dir, POUNCE_SPEED, "enemy", 104.0, 8.0, world_ctx).get("points", PackedVector2Array()) as PackedVector2Array
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 108.0), 12.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("i5_gravity_bend", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_pounce_vel = _aim_dir * POUNCE_SPEED
			stage.play_sfx("i5_comet_bark", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var fa: Vector2 = LxFields.accel_at(pos, "enemy")
			if fa.length_squared() > 0.5:
				_pounce_vel += fa * 1.9 * dt
			if _pounce_vel.length_squared() > 1.0:
				_pounce_vel = _pounce_vel.normalized() * POUNCE_SPEED
				facing = _pounce_vel.angle()
			var prev_p: Vector2 = pos
			move_boss(_pounce_vel * dt, false)
			check_contact_damage(body_radius + 6.0, _pounce_vel.normalized(), 1.0, "apogee_pounce")
			# PUSH polarity derails pounce into arena rim/spur -> dinner-bell bonk stagger!
			if _well != null and _well.is_push and prev_p.distance_to(pos) < _pounce_vel.length() * dt * 0.42:
				stage.play_sfx("i5_hound_stagger", pos)
				stage.shake(0.20)
				if add_stagger(stagger_threshold):
					return,
		"on_recover": func(_b: LxBossBase, dt: float) -> void:
			if _pounce_vel.length() > 12.0:
				move_boss(_pounce_vel * dt * 0.18, false)
				_pounce_vel = _pounce_vel.move_toward(Vector2.ZERO, 240.0 * dt),
	})

	# Attack 3: Comet Howl — radial curving gravity spiral + targeted ring punishing all 8 corners!
	register_attack("comet_howl", {
		"weight": 1.15, "tell": 0.68, "commit": 0.46, "recover": 1.05, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(clamp_to_arena(tgt), 24.0, last_tell_duration, 1.0, "coral", "gold")
			ground.warn_ring(_nearest_corner(tgt), 22.0, last_tell_duration + 0.08, 1.0, "sky", "ice")
			stage.play_sfx("i5_comet_bark", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var arms: int = 4 if phase >= 2 else 3
			var waves: int = 3 if phase >= 2 else 2
			patterns.emit_spiral(pos, arms, 118.0, (tgt - pos).angle(), 0.42, waves, 0.14, {"color": "sky", "source": "comet_howl", "field_scale": 1.15})
			if phase >= 2:
				patterns.emit_gap_ring(pos, 10, 108.0, (tgt - pos).angle() + PI * 0.5, 0.72, {"color": "gold", "source": "comet_ring", "field_scale": 1.0})
			stage.shake(0.18)
			stage.play_sfx("i5_gravity_bend", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_well()
	_cycle_count = 0
	_orbit_angle = 0.0
	_pounce_vel = Vector2.ZERO
	_pounce_curve_pts = PackedVector2Array()


func _on_engage() -> void:
	_ensure_well()
	var c: Vector2 = arena_rect.get_center()
	props.spawn_bell(c, func(_p: Dictionary) -> void:
		_flip_well_polarity(), "apogee_well_bell")


func _on_death_start() -> void:
	_unregister_well()


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_flip_well_polarity()
		var c: Vector2 = arena_rect.get_center()
		# Crack outer NW/SE corner tiles cleanly (auto-rolled back on reset_encounter!)
		var ts: float = 16.0
		var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
		var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
		var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
		var ty_s: int = int(floorf((arena_rect.end.y - 24.0) / ts))
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_s, 1, 1), "pit")
		props.spawn_pillar(c + Vector2(-56.0, -30.0), 4.5, "apogee_spur_w")
		props.spawn_pillar(c + Vector2(56.0, 30.0), 4.5, "apogee_spur_e")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.22)
		stage.play_sfx("boss_roar", pos)


func _on_attack_recover_start(_attack_id: String) -> void:
	_cycle_count += 1
	if phase >= 2 and _cycle_count % 2 == 0:
		_flip_well_polarity()


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	var spd: float = 0.45 if is_flash_reduced() else 1.0
	_well_phase_anim = fposmod(_well_phase_anim + dt * spd, 1.0)
	if _well != null:
		_well.pos = arena_rect.get_center()


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	var orb_r: float = minf(arena_rect.size.x, arena_rect.size.y) * 0.32
	_orbit_angle = wrapf(_orbit_angle + _orbit_side * (1.55 if phase >= 2 else 1.15) * dt, -PI, PI)
	var desired_pt: Vector2 = c + Vector2.from_angle(_orbit_angle) * orb_r
	var step: Vector2 = (desired_pt - pos).limit_length(move_speed * (1.15 if phase >= 2 else 1.0) * dt)
	move_boss(step, false)
	_face_point(target, 4.0, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 20.0
	var bypass: bool = is_curved or src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	if src == LxHit.SOURCE_BEAM:
		return dmg * 1.22

	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) < FRONT_BROW_HALF
	if front_hit and not bypass and not is_punishable():
		clank_t = 0.12
		stage.play_sfx("i5_meteor_hit", pos)
		return dmg * 0.45
	if (not front_hit) or is_curved:
		return dmg * 1.30
	return dmg


func _ensure_well() -> void:
	if _well == null:
		_well = WellField.new()
	_well.pos = arena_rect.get_center()
	_well.is_push = false
	_well.active = true
	if not _well_registered:
		LxFields.add(_well)
		_well_registered = true


func _unregister_well() -> void:
	if _well != null and _well_registered:
		LxFields.remove(_well)
		_well_registered = false


func _flip_well_polarity() -> void:
	if _well == null:
		return
	_well.is_push = not _well.is_push
	stage.play_sfx("i5_well_polarity", _well.pos)
	stage.light_burst(_well.pos, 72.0, 1.25, 0.30)


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 2 else PAL["blue"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Draw central polarity well ripples
	if _well != null and _well_registered:
		var wc: Vector2 = (_well.pos - pos + off).round()
		var c_ring: Color = (PAL["gold"] if _well.is_push else PAL["sky"]) as Color
		draw_arc(wc, _well.radius, 0.0, TAU, 32, Color(c_ring, 0.28), 1.0)
		for k: int in range(2):
			var ph: float = fposmod(_well_phase_anim + float(k) * 0.5, 1.0)
			var u: float = ph if _well.is_push else (1.0 - ph)
			draw_arc(wc, lerpf(10.0, _well.radius - 2.0, u), 0.0, TAU, 24, Color(c_ring, sin(ph * PI) * 0.50), 1.0)
		draw_circle(wc, 7.0, PAL["void"] as Color)
		draw_arc(wc, 7.0, 0.0, TAU, 16, c_ring, 1.0)
		draw_rect(Rect2(wc - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)

	# Curved pounce trajectory preview during orbital_pounce TELL
	if boss_state == BossState.TELL and active_attack_id == "orbital_pounce" and _pounce_curve_pts.size() >= 2:
		for k: int in range(_pounce_curve_pts.size() - 1):
			var a: Vector2 = (_pounce_curve_pts[k] - pos + off).round()
			var b: Vector2 = (_pounce_curve_pts[k + 1] - pos + off).round()
			draw_line(a, b, PAL["ice"] as Color, 2.0)
