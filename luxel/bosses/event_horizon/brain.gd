class_name LxEventHorizonBoss
extends LxBossBase
## Island 5 Superboss (superboss_horizon): The Event Horizon.
## THE CORE TWIST: Devouring cosmic singularity registered with LxFields!
## Straight bolts & un-banked beams (LxHit.curve_angle_deg < 28 deg) are SWALLOWED WHOLE
## and HEAL the singularity (+0.5 HP)! Curve shots tangentially around its Photon Ring or
## orbiting Accretion Lens Wells (curve_angle_deg >= 28 deg) for 1.5x PERIAPSIS CRITS!
## Phase 3 flips into a blinding WHITE HOLE INVERSION pushing everything outward!

class SingularityField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 120.0
	var strength: float = 680.0
	var is_push: bool = false # P1/P2 Black Hole PULL -> P3 White Hole PUSH!
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
		var falloff: float = (0.40 + 0.60 * u) * (1.0 - exp(-dist / 12.0))
		var mult: float = 2.15 if what in ["bolt", "beam"] else (1.15 if what == "lantern" else (0.12 if what == "wick" else 0.25))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


class AccretionLensWell:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 64.0
	var strength: float = 620.0
	var is_push: bool = false
	var active: bool = true

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active or what == "wick":
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= radius * radius or d2 <= 0.0001:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		var falloff: float = (0.45 + 0.55 * u) * (1.0 - exp(-dist / 8.0))
		var mult: float = 2.35 if what in ["bolt", "beam"] else 1.05
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const CURVE_CRIT_DEG: float = 20.0
const STRAIGHT_HEAL_HP: float = 0.50

var _singularity: SingularityField = null
var _lens_a: AccretionLensWell = null
var _lens_b: AccretionLensWell = null
var _fields_reg: bool = false
var _lens_ang: float = 0.0
var _jet_ang: float = 0.0
var _ripple_t: float = 0.0
var _swallow_flash_t: float = 0.0
var _periapsis_flash_t: float = 0.0
var _white_flip_flash_t: float = 0.0
var shots_swallowed: int = 0
var curved_hits_landed: int = 0


func _init() -> void:
	super._init()
	kind = "event_horizon"
	boss_id = "event_horizon"
	boss_name_key = "I5_BOSS_HORIZON"
	island_id = 5
	is_miniboss = false
	reward_heart = "full"
	music_cue = "superboss_b"
	music_p2_cue = "superboss_b"
	max_hp = 175.0
	hp = 175.0
	body_radius = 13.5
	move_speed = 24.0
	phase_shift_duration = 0.85
	stagger_threshold = 13.5
	stagger_duration = 1.50
	post_recover_cd = 0.28
	shard_drop = 45


func _exit_tree() -> void:
	_unregister_fields()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33]) # P1 Black Hole -> P2 Time Dilation -> P3 WHITE HOLE INVERSION!

	# Attack 1: Accretion Jet — twin polar flares + rotating double polar beam across the ring!
	register_attack("accretion_jet", {
		"weight": 1.25, "tell": 0.62, "commit": 0.50, "recover": 1.00, "cooldown": 1.25,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_jet_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			var d1: Vector2 = Vector2.from_angle(_jet_ang)
			ground.warn_lane(pos, pos + d1 * 180.0, 10.0, last_tell_duration, 0.0, "sky", "cream")
			ground.warn_lane(pos, pos - d1 * 180.0, 10.0, last_tell_duration, 0.0, "sky", "cream")
			ground.warn_ring(tgt.lerp(pos, 0.22), 24.0, last_tell_duration + 0.05, 1.0, "sky", "gold")
			stage.play_sfx("horizon_pull", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var d1: Vector2 = Vector2.from_angle(_jet_ang)
			var p1: Vector2 = pos + d1 * 170.0
			var p2: Vector2 = pos - d1 * 170.0
			patterns.emit_chain_lightning([p1, pos, p2], 0.45, 10.0, 0.28, 1.0)
			patterns.emit_lane(pos, d1, 4, 174.0, 0.07, {"color": "ice", "source": "accretion_jet", "field_scale": 0.0})
			patterns.emit_lane(pos, -d1, 3, 152.0, 0.08, {"color": "gold", "source": "accretion_jet", "field_scale": 0.0})
			stage.shake(0.18)
			stage.play_sfx("star_lance", pos),
	})

	# Attack 2: Tidal Shred — intensifies vortex rings + curving debris orbit & targeted crush ring!
	register_attack("tidal_shred", {
		"weight": 1.20, "tell": 0.70, "commit": 0.55, "recover": 1.10, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			if _singularity != null:
				_singularity.strength = 860.0 if phase >= 3 else 780.0
			ground.warn_ring(pos, 32.0, last_tell_duration, 0.0, "plum" if phase < 3 else "gold", "cream")
			ground.warn_ring(tgt, 24.0, last_tell_duration + 0.05, 1.0, "coral", "gold")
			ground.warn_ring(tgt.lerp(pos, 0.26), 24.0, last_tell_duration + 0.08, 1.0, "plum", "coral")
			stage.play_sfx("horizon_pull", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim, 3, 0.42, 154.0, {"color": "coral", "source": "tidal_lance", "field_scale": 0.0})
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 118.0, aim.angle() + 0.45, 0.78, {"color": "gold" if phase >= 3 else "plum", "source": "tidal_shred", "field_scale": 0.65})
			patterns.emit_orbit(pos, 5 if phase >= 2 else 4, 48.0, -2.2 if phase >= 3 else 2.2, 2.3, {"color": "ice" if phase >= 3 else "gold", "source": "accretion_debris"})
			stage.shake(0.18)
			stage.play_sfx("eclipse_wave", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if _singularity != null:
				_singularity.strength = 680.0 if phase >= 3 else 640.0,
	})

	# Attack 3: Hawking Rain — curving star-shards targeting Wick & perimeter corners!
	register_attack("hawking_rain", {
		"weight": 1.15, "tell": 0.60, "commit": 0.45, "recover": 1.05, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = [tgt, tgt.lerp(pos, 0.24), _nearest_corner(tgt)]
			if phase >= 2:
				drops.append(arena_rect.get_center().lerp(tgt, 0.55))
			if phase >= 3:
				drops.append(_farthest_corner(tgt))
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "ice" if phase >= 3 else "gold", "cream")
			stage.play_sfx("i5b_gravity_curve", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_boomerang(pos, aim.rotated(0.38), 146.0, 0.66, 0.90, {"color": "gold", "source": "hawking_shard", "field_scale": 1.15})
			patterns.emit_boomerang(pos, aim.rotated(-0.38), 146.0, 0.66, -0.90, {"color": "ice", "source": "hawking_shard", "field_scale": 1.15})
			stage.shake(0.15)
			stage.play_sfx("orrery_beam_bolt", pos),
	})

	# Attack 4 (P2/P3): White Hole Supernova — blinding contraction -> safe-zone inversion + burst!
	register_attack("white_hole_supernova", {
		"phases": [2, 3], "weight": 1.55, "tell": 0.78, "commit": 0.52, "recover": 1.25, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var to_c: Vector2 = (c - tgt).normalized() if tgt.distance_to(c) > 4.0 else Vector2.RIGHT
			var s1: Vector2 = clamp_to_arena(tgt + to_c * 44.0)
			var s2: Vector2 = clamp_to_arena(c + (c - s1).limit_length(56.0))
			ground.warn_safe_inversion(arena_rect, [s1, s2], 28.0, last_tell_duration, 0.28, 1.0, "gold" if phase >= 3 else "ice", "coral" if phase >= 3 else "plum")
			stage.play_sfx("white_hole_flip" if phase >= 3 else "horizon_pull", c),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_expanding_square(pos, 3, 108.0, anim_t, 1, {"color": "cream" if phase >= 3 else "gold", "source": "supernova_wave", "field_scale": 0.75})
			stage.light_burst(pos, 108.0, 1.55, 0.42)
			stage.shake(0.24)
			stage.play_sfx("sunflare_burst", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_fields()
	_lens_ang = 0.0
	_ripple_t = 0.0
	_swallow_flash_t = 0.0
	_periapsis_flash_t = 0.0
	_white_flip_flash_t = 0.0
	shots_swallowed = 0
	curved_hits_landed = 0
	pos = arena_rect.get_center()
	position = pos.round()


func _on_engage() -> void:
	pos = arena_rect.get_center()
	position = pos.round()
	_ensure_fields()


func _on_death_start() -> void:
	_unregister_fields()
	stage.light_burst(pos, 128.0, 1.6, 0.55)
	stage.play_sfx("zodiac_chord", pos)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	var ts: float = 16.0
	var tx_l: int = int(floorf((arena_rect.position.x + 8.0) / ts))
	var tx_r: int = int(floorf((arena_rect.end.x - 20.0) / ts))
	var ty_t: int = int(floorf((arena_rect.position.y + 8.0) / ts))
	var ty_b: int = int(floorf((arena_rect.end.y - 20.0) / ts))
	if new_phase == 2:
		# Time Dilation & Blind Stars: fracture 4 outer corners cleanly reverted on retry!
		stage.set_tiles(world_ctx, Rect2i(tx_l, ty_t, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_r, ty_t, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_l, ty_b, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(tx_r, ty_b, 1, 1), "pit")
		adds.queue_wave([{"kind": "null_moth", "pos": c + Vector2(-58.0, -34.0)}], 0.72, 1)
		stage.darkness_pulse(0.68, 1.05)
		stage.shake(0.22)
		stage.play_sfx("horizon_pull", c)
	elif new_phase == 3:
		# WHITE HOLE INVERSION: Singularity flips from PULL to violent PUSH!
		if _singularity != null:
			_singularity.is_push = true
			_singularity.strength = 680.0
		if _lens_a != null: _lens_a.is_push = true
		if _lens_b != null: _lens_b.is_push = false
		_white_flip_flash_t = 0.85
		props.spawn_pillar(c + Vector2(-62.0, 0.0), 5.0, "wh_bumper_w")
		props.spawn_pillar(c + Vector2(62.0, 0.0), 5.0, "wh_bumper_e")
		stage.light_burst(c, 120.0, 1.65, 0.45)
		stage.shake(0.28)
		stage.play_sfx("white_hole_flip", c)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	var spd: float = 0.45 if is_flash_reduced() else 1.0
	_ripple_t = fposmod(_ripple_t + dt * spd * (1.35 if phase >= 3 else 1.0), 1.0)
	_swallow_flash_t = maxf(0.0, _swallow_flash_t - dt)
	_periapsis_flash_t = maxf(0.0, _periapsis_flash_t - dt)
	_white_flip_flash_t = maxf(0.0, _white_flip_flash_t - dt)

	# Keep Singularity anchored near center with subtle orbital drift; orbit the 2 Accretion Lens Wells!
	var c: Vector2 = arena_rect.get_center()
	var lens_spd: float = 2.15 if phase >= 3 else (1.75 if phase == 2 else 1.45)
	_lens_ang = wrapf(_lens_ang + lens_spd * dt * (-1.0 if phase >= 3 else 1.0), -PI, PI)
	if _singularity != null:
		_singularity.pos = pos
		_singularity.is_push = phase >= 3
	var lens_r: float = 52.0
	if _lens_a != null:
		_lens_a.pos = c + Vector2.from_angle(_lens_ang) * lens_r
	if _lens_b != null:
		_lens_b.pos = c - Vector2.from_angle(_lens_ang) * lens_r


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	var drift: Vector2 = c + Vector2(cos(anim_t * 0.9) * 14.0, sin(anim_t * 1.2) * 10.0)
	move_boss((drift - pos).limit_length(move_speed * dt), true)
	_face_point(target, 3.5, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if dmg >= max_hp * 0.25:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var curve_deg: float = hit.curve_angle_deg if hit != null else 0.0
	var is_curved: bool = curve_deg >= CURVE_CRIT_DEG

	# THE SIGNATURE TWIST: Straight bolts & un-banked beams are SWALLOWED and HEAL the singularity!
	if src in [LxHit.SOURCE_BOLT, LxHit.SOURCE_BEAM] and not is_curved and not bool(h["cracks_armour"]):
		hp = minf(max_hp, hp + STRAIGHT_HEAL_HP)
		shots_swallowed += 1
		_swallow_flash_t = 0.28
		clank_t = 0.14
		stage.play_sfx("horizon_swallow", pos)
		return 0.0

	# Curved shots grazing the Photon Ring / Accretion Wells -> 1.25x PERIAPSIS CRIT during openings (0.80x outside)!
	if is_curved:
		curved_hits_landed += 1
		_periapsis_flash_t = 0.28
		stage.play_sfx("i5b_gravity_curve", pos)
		return dmg * (1.25 if is_punishable() else 0.80)

	# Mirror-banked Prism / armor-cracking Beams / Reflected bolts -> 1.20x in punish, 0.72x outside!
	if src == LxHit.SOURCE_PRISM or bool(h["cracks_armour"]):
		curved_hits_landed += 1
		_periapsis_flash_t = 0.24
		return dmg * (1.20 if is_punishable() else 0.72)

	# Lantern Throw / Recall / Zip / Sunflare strikes pierce the event horizon rim (curved shots stay king!)
	return dmg * (0.58 if is_punishable() else 0.36)


func _ensure_fields() -> void:
	var c: Vector2 = arena_rect.get_center()
	if _singularity == null: _singularity = SingularityField.new()
	if _lens_a == null: _lens_a = AccretionLensWell.new()
	if _lens_b == null: _lens_b = AccretionLensWell.new()
	_singularity.pos = pos; _singularity.is_push = phase >= 3; _singularity.active = true
	_lens_a.pos = c + Vector2(48.0, 0.0); _lens_a.is_push = false; _lens_a.active = true
	_lens_b.pos = c - Vector2(48.0, 0.0); _lens_b.is_push = false; _lens_b.active = true
	if not _fields_reg:
		LxFields.add(_singularity)
		LxFields.add(_lens_a)
		LxFields.add(_lens_b)
		_fields_reg = true


func _unregister_fields() -> void:
	if _fields_reg:
		if _singularity != null: _singularity.active = false; LxFields.remove(_singularity)
		if _lens_a != null: _lens_a.active = false; LxFields.remove(_lens_a)
		if _lens_b != null: _lens_b.active = false; LxFields.remove(_lens_b)
		_fields_reg = false


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
	return (PAL["cream"] if phase >= 3 else (PAL["wine"] if phase == 2 else PAL["void"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var is_wh: bool = phase >= 3
	var ring_c: Color = (PAL["gold"] if is_wh else PAL["plum"]) as Color
	var hi_c: Color = (PAL["cream"] if is_wh else PAL["ice"]) as Color

	# Live Singularity gravitational pull / White Hole push ripples + Photon Ring aim guide
	if _singularity != null and _fields_reg:
		draw_arc(c, _singularity.radius, 0.0, TAU, 36, Color(ring_c, 0.25), 1.0)
		draw_arc(c, 34.0, 0.0, TAU, 24, Color(PAL["gold"] as Color, 0.42 if is_wh else 0.52), 1.2)
		for k: int in range(3):
			var ph: float = fposmod(_ripple_t + float(k) / 3.0, 1.0)
			var u: float = ph if is_wh else (1.0 - ph)
			draw_arc(c, lerpf(16.0, _singularity.radius - 4.0, u), 0.0, TAU, 28, Color(hi_c if k == 0 else ring_c, sin(ph * PI) * 0.42), 1.2)

	# Draw the two orbiting Accretion Lens Satellite Wells (visual aim cues for curved shots!)
	for lw: AccretionLensWell in [_lens_a, _lens_b]:
		if lw != null and _fields_reg:
			var lp: Vector2 = (lw.pos - pos + off).round()
			var lc: Color = (PAL["gold"] if lw.is_push else PAL["sky"]) as Color
			draw_arc(lp, lw.radius * 0.58, 0.0, TAU, 20, Color(lc, 0.42), 1.2)
			draw_circle(lp, 5.5, PAL["void"] as Color)
			draw_arc(lp, 5.5, 0.0, TAU, 12, lc, 1.4)
			draw_rect(Rect2(lp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)

	# Straight-shot SWALLOW / HEAL visual feedback (dark imploding ring + plum cross!)
	if _swallow_flash_t > 0.0:
		var u_s: float = clampf(_swallow_flash_t / 0.28, 0.0, 1.0)
		draw_arc(c, lerpf(10.0, 28.0, u_s), 0.0, TAU, 20, PAL["rose"] as Color, 2.0)

	# Curved-shot PERIAPSIS CRIT visual feedback (blazing gold burst ring!)
	if _periapsis_flash_t > 0.0:
		var u_p: float = 1.0 - clampf(_periapsis_flash_t / 0.28, 0.0, 1.0)
		draw_arc(c, lerpf(14.0, 38.0, u_p), 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
		draw_arc(c, lerpf(10.0, 30.0, u_p), 0.0, TAU, 18, PAL["cream"] as Color, 1.2)

	# White Hole P3 inversion flash
	if _white_flip_flash_t > 0.0:
		var u_w: float = 1.0 - clampf(_white_flip_flash_t / 0.85, 0.0, 1.0)
		draw_arc(c, lerpf(16.0, 110.0, u_w), 0.0, TAU, 32, Color(PAL["cream"] as Color, 1.0 - u_w), 3.0)
