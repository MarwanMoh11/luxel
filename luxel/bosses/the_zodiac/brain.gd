class_name LxTheZodiacBoss
extends LxBossBase
## Island 5 Dungeon B Boss (The Planetarium, planet_r11): The Zodiac.
## Four living starlight constellations — The Ram (0 deg), The Scales (90 deg),
## The Archer (180 deg), and The Serpent (270 deg). Between every body the entire dome
## clicks 90 deg (1.0s golden transition) and redraws the arena into that constellation's shape!

class BowGravityField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 64.0
	var strength: float = 520.0
	var active: bool = false

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
		var mult: float = 1.25 if what in ["bolt", "beam"] else (0.90 if what == "lantern" else (0.08 if what == "wick" else 0.25))
		return (delta / dist) * (strength * falloff * mult)


const BODY_NAMES: PackedStringArray = ["RAM", "SCALES", "ARCHER", "SERPENT"]

var _bow_field: BowGravityField = null
var _bow_field_reg: bool = false
var _turn_flash_t: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT
var _charge_vel: Vector2 = Vector2.ZERO
var _scales_pan_l: Vector2 = Vector2.ZERO
var _scales_pan_r: Vector2 = Vector2.ZERO
var _scales_balanced_t: float = 0.0
var _serpent_t: float = 0.0
var _constellation_pts: Array[Vector2] = []


func _init() -> void:
	super._init()
	kind = "the_zodiac"
	boss_id = "the_zodiac"
	boss_name_key = "I5_BOSS_ZODIAC"
	island_id = 5
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island5_boss_p1"
	music_p2_cue = "island5_boss_p2"
	max_hp = 108.0
	hp = 108.0
	body_radius = 12.0
	move_speed = 46.0
	phase_shift_duration = 0.90
	stagger_threshold = 13.0
	stagger_duration = 1.45
	post_recover_cd = 0.24
	shard_drop = 32


func _exit_tree() -> void:
	_unregister_bow_field()


func _configure_boss(spec: Dictionary) -> void:
	max_hp = 112.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	hp = max_hp
	configure_phases([0.75, 0.50, 0.25]) # 4 Bodies: Ram(1), Scales(2), Archer(3), Serpent(4)

	# Shared All-Phase Attack: Constellation Flare (star pillars + perimeter pressure across all 8 spots!)
	register_attack("constellation_flare", {
		"weight": 0.90, "tell": 0.56, "commit": 0.36, "recover": 0.92, "cooldown": 1.85,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var pts: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			if phase >= 3:
				pts.append(arena_rect.get_center().lerp(tgt, 0.55))
			patterns.emit_pillars(pts, last_tell_duration, 17.0, 0.35, 1.0, "gold")
			stage.play_sfx("star_ignite", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var ang: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			patterns.emit_gap_ring(pos, 10 + phase, 114.0 + float(phase) * 5.0, ang + 0.50, 0.76, {"color": "gold", "source": "zodiac_flare"})
			stage.shake(0.14)
			stage.play_sfx("zodiac_chord", pos),
	})

	# ---- BODY 1 (P1): THE RAM (0 deg, Horn Arena) ----
	register_attack("horn_charge", {
		"phases": [1], "weight": 1.60, "tell": 0.55, "commit": 0.44, "recover": 1.00, "cooldown": 0.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 138.0), 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("star_ignite", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_charge_vel = _aim_dir * 238.0
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var prev_p: Vector2 = pos
			move_boss(_charge_vel * dt, false)
			check_contact_damage(body_radius + 7.0, _aim_dir, 1.0, "ram_horn")
			if prev_p.distance_to(pos) < _charge_vel.length() * dt * 0.35:
				patterns.emit_fan(pos, -_aim_dir, 5, 1.05, 116.0, {"color": "gold", "source": "ram_sparks"})
				stage.shake(0.18),
	})

	register_attack("star_stamp", {
		"phases": [1], "weight": 1.50, "tell": 0.58, "commit": 0.36, "recover": 0.95, "cooldown": 1.00,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt), arena_rect.get_center()]
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "apricot", "gold")
			stage.play_sfx("bellkeeper_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_fan(pos, aim, 5, 0.85, 134.0, {"color": "apricot", "source": "ram_stamp"})
			stage.shake(0.16)
			stage.play_sfx("bellkeeper_slam_fire", pos),
	})

	# ---- BODY 2 (P2): THE SCALES (90 deg, Twin-Pan Arena) ----
	register_attack("counterweight_beam", {
		"phases": [2], "weight": 1.65, "tell": 0.72, "commit": 0.42, "recover": 1.00, "cooldown": 1.00,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var to_c: Vector2 = (c - tgt).normalized() if tgt.distance_to(c) > 4.0 else Vector2.RIGHT
			var s1: Vector2 = clamp_to_arena(tgt + to_c * 44.0)
			var s2: Vector2 = _scales_pan_r if tgt.x < c.x else _scales_pan_l
			ground.warn_safe_inversion(arena_rect, [s1, clamp_to_arena(s2)], 28.0, last_tell_duration, 0.26, 1.0, "gold", "plum")
			stage.play_sfx("star_bell_turn", c),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			patterns.emit_sweep_wall(Vector2(c.x, arena_rect.position.y + 8.0), Vector2.DOWN, arena_rect.size.x - 28.0, 9, 4, 2, 114.0, {"color": "gold", "source": "scales_beam"})
			stage.shake(0.18)
			stage.play_sfx("eclipse_wave", pos),
	})

	register_attack("fulcrum_swing", {
		"phases": [2], "weight": 1.55, "tell": 0.56, "commit": 0.40, "recover": 0.95, "cooldown": 0.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			ground.warn_lane(_scales_pan_l, _scales_pan_r, 8.0, last_tell_duration, 0.0, "ice", "gold")
			stage.play_sfx("compass_tick", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d1: Vector2 = (tgt - _scales_pan_l).normalized() if tgt.distance_to(_scales_pan_l) > 0.1 else Vector2.RIGHT
			var d2: Vector2 = (tgt - _scales_pan_r).normalized() if tgt.distance_to(_scales_pan_r) > 0.1 else Vector2.LEFT
			patterns.emit_fan(_scales_pan_l, d1, 3, 0.55, 130.0, {"color": "gold", "source": "scales_pan"})
			patterns.emit_fan(_scales_pan_r, d2, 3, 0.55, 130.0, {"color": "ice", "source": "scales_pan"})
			patterns.emit_orbit(pos, 4, 42.0, 2.2, 2.0, {"color": "gold", "source": "fulcrum_orb"})
			stage.play_sfx("orrery_beam_bolt", pos),
	})

	# ---- BODY 3 (P3): THE ARCHER (180 deg, Bow-Arc Arena + Gravity Well!) ----
	register_attack("curved_star_volley", {
		"phases": [3], "weight": 1.65, "tell": 0.58, "commit": 0.42, "recover": 1.00, "cooldown": 0.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 145.0), 9.0, last_tell_duration, 0.0, "sky", "cream")
			stage.play_sfx("i5b_gravity_curve", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_fan(pos, aim, 3, 0.72, 134.0, {"color": "sky", "source": "archer_arrow", "field_scale": 1.25})
			patterns.emit_boomerang(pos, aim.rotated(0.42), 138.0, 0.65, 0.85, {"color": "ice", "source": "archer_curve", "field_scale": 1.15})
			stage.shake(0.15)
			stage.play_sfx("star_lance", pos),
	})

	register_attack("bowstring_snap", {
		"phases": [3], "weight": 1.55, "tell": 0.62, "commit": 0.38, "recover": 1.05, "cooldown": 1.05,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration, 21.0, 1.0, "sky", "gold")
			stage.play_sfx("orrery_bell_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var perp: Vector2 = ((tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.RIGHT).orthogonal()
			var p1: Vector2 = clamp_to_arena(pos + perp * 68.0)
			var p2: Vector2 = clamp_to_arena(pos - perp * 68.0)
			patterns.emit_chain_lightning([p1, pos, p2], 0.50, 7.5, 0.22, 1.0)
			patterns.emit_lane(pos, (tgt - pos).normalized(), 2, 142.0, 0.10, {"color": "ice", "source": "bowstring_shot", "field_scale": 1.20})
			stage.play_sfx("star_lance", pos),
	})

	# ---- BODY 4 (P4): THE SERPENT (270 deg, S-Curve Arena + Star Tail Segments!) ----
	register_attack("ouroboros_slither", {
		"phases": [4], "weight": 1.65, "tell": 0.52, "commit": 0.62, "recover": 1.05, "cooldown": 0.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 136.0), 11.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("star_snuff", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_serpent_t = 0.0
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			_serpent_t += dt * 9.0
			var perp: Vector2 = _aim_dir.orthogonal()
			var step_v: Vector2 = (_aim_dir * 182.0 + perp * sin(_serpent_t) * 84.0) * dt
			move_boss(step_v, true)
			check_contact_damage(body_radius + 6.0, _aim_dir, 1.0, "serpent_slither")
			if int(elapsed * 4.0) != int((elapsed - dt) * 4.0):
				ground.add_hazard_circle(pos, 9.0, 0.72, 1.0, "coral"),
	})

	register_attack("venom_spiral", {
		"phases": [4], "weight": 1.55, "tell": 0.60, "commit": 0.44, "recover": 1.08, "cooldown": 1.05,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(clamp_to_arena(tgt), 21.0, last_tell_duration, 1.0, "coral", "ice")
			stage.play_sfx("zodiac_chord", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 4, 108.0, (tgt - pos).angle(), 0.42, 2, 0.16, {"color": "coral", "source": "serpent_venom"})
			patterns.emit_expanding_square(pos, 2, 94.0, anim_t, 1, {"color": "gold", "source": "serpent_star"})
			stage.shake(0.18)
			stage.play_sfx("eclipse_wave", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_bow_field()
	_turn_flash_t = 0.0
	_scales_balanced_t = 0.0
	_charge_vel = Vector2.ZERO
	_rebuild_constellation_geometry(1)


func _on_engage() -> void:
	_redraw_constellation_arena(1)


func _on_death_start() -> void:
	_unregister_bow_field()
	stage.play_sfx("zodiac_chord", arena_rect.get_center())


func _on_phase_enter(new_phase: int) -> void:
	_turn_flash_t = 1.0
	_unregister_bow_field()
	segments.clear()
	_redraw_constellation_arena(new_phase)
	stage.darkness_pulse(0.65, 1.0)
	stage.shake(0.24)
	stage.play_sfx("star_bell_turn", arena_rect.get_center())
	stage.play_sfx("zodiac_chord", pos)
	if new_phase == 3:
		_register_bow_field()
	elif new_phase == 4:
		segments.setup_follow_chain(5, 11.0, 5.5, 4.0, pos, facing)


func _redraw_constellation_arena(body_idx: int) -> void:
	# Revert previous constellation tiles first so every phase cleanly redraws the arena silhouette!
	stage.revert_tiles(world_ctx)
	_rebuild_constellation_geometry(body_idx)
	var ts: float = 16.0
	var c: Vector2 = arena_rect.get_center()
	var tx_l: int = int(floorf((arena_rect.position.x + 24.0) / ts))
	var tx_r: int = int(floorf((arena_rect.end.x - 36.0) / ts))
	var tx_c: int = int(floorf(c.x / ts))
	var ty_t: int = int(floorf((arena_rect.position.y + 24.0) / ts))
	var ty_b: int = int(floorf((arena_rect.end.y - 36.0) / ts))
	var ty_m: int = int(floorf(c.y / ts))
	match body_idx:
		1:
			# THE RAM (0 deg): Horn cutouts framing outer top corners
			_carve_constellation_pit(tx_l, ty_t)
			_carve_constellation_pit(tx_r, ty_t)
		2:
			# THE SCALES (90 deg): Central N/S fulcrum notches framing Twin Pans!
			_carve_constellation_pit(tx_c, ty_t)
			_carve_constellation_pit(tx_c, ty_b)
		3:
			# THE ARCHER (180 deg): Bow-arc W/E flank notches around central gravity well!
			_carve_constellation_pit(tx_l, ty_m)
			_carve_constellation_pit(tx_r, ty_m)
		4:
			# THE SERPENT (270 deg): Diagonal S-curve opposite void cutouts!
			_carve_constellation_pit(tx_l, ty_b)
			_carve_constellation_pit(tx_r, ty_t)


func _carve_constellation_pit(tx: int, ty: int) -> void:
	var tile_c := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if _has_player() and _get_wick_pos().distance_to(tile_c) < 24.0:
		return
	stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


func _rebuild_constellation_geometry(body_idx: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	var rx: float = maxf(48.0, arena_rect.size.x * 0.32)
	var ry: float = maxf(32.0, arena_rect.size.y * 0.30)
	_scales_pan_l = clamp_to_arena(c + Vector2(-rx * 0.85, 0.0))
	_scales_pan_r = clamp_to_arena(c + Vector2(rx * 0.85, 0.0))
	_constellation_pts.clear()
	match body_idx:
		1: # Ram horns arc
			_constellation_pts = [
				c + Vector2(-rx, -ry * 0.2), c + Vector2(-rx * 0.55, -ry), c + Vector2(0.0, -ry * 0.35),
				c + Vector2(rx * 0.55, -ry), c + Vector2(rx, -ry * 0.2),
			]
		2: # Scales balance beam + twin pans
			_constellation_pts = [
				_scales_pan_l + Vector2(0.0, ry * 0.45), _scales_pan_l, c, _scales_pan_r, _scales_pan_r + Vector2(0.0, ry * 0.45),
			]
		3: # Archer curved bow arc
			_constellation_pts = [
				c + Vector2(-rx * 0.4, -ry), c + Vector2(rx * 0.45, -ry * 0.5), c + Vector2(rx * 0.72, 0.0),
				c + Vector2(rx * 0.45, ry * 0.5), c + Vector2(-rx * 0.4, ry),
			]
		4: # Serpent S-curve
			_constellation_pts = [
				c + Vector2(-rx * 0.85, ry * 0.7), c + Vector2(-rx * 0.25, ry * 0.15), c + Vector2(rx * 0.35, ry * 0.45),
				c + Vector2(rx * 0.25, -ry * 0.2), c + Vector2(-rx * 0.35, -ry * 0.65), c + Vector2(rx * 0.75, -ry * 0.7),
			]


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_turn_flash_t = maxf(0.0, _turn_flash_t - dt)
	_scales_balanced_t = maxf(0.0, _scales_balanced_t - dt)
	if _bow_field != null and _bow_field_reg:
		_bow_field.pos = arena_rect.get_center()
	# Body 2 (Scales) counterplay: tossing lantern onto opposite pan balances Scales -> stagger!
	if phase == 2 and _is_lantern_out() and boss_state != BossState.STAGGER and _scales_balanced_t <= 0.0:
		var lp: Vector2 = _get_lantern_pos()
		if lp.distance_to(_scales_pan_l) <= 28.0 or lp.distance_to(_scales_pan_r) <= 28.0:
			_scales_balanced_t = 5.0
			stage.play_sfx("zodiac_chord", arena_rect.get_center())
			add_stagger(stagger_threshold * 0.85)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	# Body 3 (Archer): curving bolts/Beams through the Archer's own Bow Well deals 1.45x crit!
	if phase == 3 and (curve_deg >= 20.0 or src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM]):
		return dmg * 1.35
	return dmg


func _register_bow_field() -> void:
	if _bow_field == null:
		_bow_field = BowGravityField.new()
	_bow_field.pos = arena_rect.get_center()
	_bow_field.active = true
	if not _bow_field_reg:
		LxFields.add(_bow_field)
		_bow_field_reg = true


func _unregister_bow_field() -> void:
	if _bow_field != null and _bow_field_reg:
		_bow_field.active = false
		LxFields.remove(_bow_field)
		_bow_field_reg = false


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	match phase:
		2: return PAL["gold"] as Color
		3: return PAL["sky"] as Color
		4: return PAL["coral"] as Color
		_: return PAL["blue"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Glowing constellation star-wire mosaic redrawn across the dome floor for each Zodiac body!
	var wire_col: Color = _body_color()
	for i: int in range(_constellation_pts.size()):
		var p0: Vector2 = (_constellation_pts[i] - pos + off).round()
		if i + 1 < _constellation_pts.size():
			var p1: Vector2 = (_constellation_pts[i + 1] - pos + off).round()
			draw_line(p0, p1, Color(wire_col, 0.55), 1.5)
		draw_circle(p0, 3.5, Color(PAL["gold"] as Color, 0.35))
		draw_rect(Rect2(p0 - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)

	# Archer's central Bow Gravity Well in Phase 3
	if _bow_field != null and _bow_field_reg:
		var wc: Vector2 = (_bow_field.pos - pos + off).round()
		draw_arc(wc, _bow_field.radius, 0.0, TAU, 28, Color(PAL["sky"] as Color, 0.30), 1.0)
		draw_circle(wc, 6.0, PAL["void"] as Color)
		draw_arc(wc, 6.0, 0.0, TAU, 14, PAL["ice"] as Color, 1.2)

	# 90-degree dome rotation golden sweep flash on body transitions!
	if _turn_flash_t > 0.0:
		var c_loc: Vector2 = (arena_rect.get_center() - pos + off).round()
		var u: float = 1.0 - clampf(_turn_flash_t / 1.0, 0.0, 1.0)
		draw_arc(c_loc, lerpf(18.0, 88.0, u), 0.0, TAU, 28, Color(PAL["gold"] as Color, (1.0 - u) * 0.75), 2.0)
