class_name LxAstronomerBoss
extends LxBossBase
## Starfall Observatory Keeper Boss (Island 5, orrery_r10): The Astronomer (Bible §4.7).
## 3 phases (66%/33%) on LxBossBase. Starlight spectral veil reduces plain bolt spam outside
## punish windows (ice/gold astrolabe glint); True Lens exposes her true gold core (1.35x) and
## shatters her Constellation Nova decoy silhouettes for an instant 1.5s stagger!
## Island 5 rule: P2 Astral Chime carves outer star-void alcoves with glowing star pedestals;
## P3 Gravity Syzygy awakens 2 live orbiting LxFields polarity wells curving her 5-arm spirals!

enum AstroMove { DIVE, CONSTELLATION }

class SyzygyWellField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 54.0
	var strength: float = 420.0
	var is_push: bool = false
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
		var mult: float = 1.20 if what in ["bolt", "beam"] else (0.85 if what == "lantern" else (0.0 if what == "wick" else 0.25))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const NOVA_TELL_P2: float = 0.62
const NOVA_RAY_RANGE: float = 140.0
const NOVA_RAY_HALF_W: float = 8.0
const ALT_PERCH: float = 16.0
const ALT_DIVE: float = 28.0

# Compat fields referenced by tests/luxel/boss_qa_capture.gd
var active_move: int = AstroMove.DIVE
var revealed: bool = true
var reveal_t: float = 2.0
var star_base_ang: float = 0.0
var decoy_offsets: Array[Vector2] = []
var _roaring: bool = false

var altitude: float = ALT_PERCH
var true_core_lit_t: float = 0.0
var _dive_from: Vector2 = Vector2.ZERO
var _dive_to: Vector2 = Vector2.ZERO
var _dive_landed: bool = false
var _sweep_dir: Vector2 = Vector2.DOWN
var _well_a: SyzygyWellField = null
var _well_b: SyzygyWellField = null
var _wells_reg: bool = false
var _well_orbit_a: float = 0.0
var _star_pedestals: Array[Vector2] = []
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "astronomer"
	boss_id = "astronomer"
	boss_name_key = "BOSS_ASTRONOMER"
	island_id = 5
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island5_boss_p1"
	music_p2_cue = "island5_boss_p2"
	max_hp = 108.0
	hp = 108.0
	body_radius = 9.0
	move_speed = 48.0
	stagger_threshold = 15.0
	stagger_duration = 1.65
	punish_dmg_mult = 1.30
	post_recover_cd = 0.32
	shard_drop = 45
	death_duration = 2.4


func _exit_tree() -> void:
	_unregister_wells()


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "orrery_r10":
		arena_rect = Rect2(144.0, 72.0, 192.0, 160.0)
	configure_phases([0.66, 0.33])

	# Attack 1: Phantom Dive — high spectral owl swoop onto target + star-feather scatter
	register_attack("phantom_dive", {
		"weight": 1.25, "tell": 0.56, "commit": 0.42, "recover": 1.15, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = AstroMove.DIVE
			decoy_offsets.clear()
			_dive_from = pos
			_dive_to = clamp_to_arena(tgt)
			_dive_landed = false
			ground.warn_ring(_dive_to, 20.0, last_tell_duration + 0.16, 0.5, "sky", "gold")
			stage.play_sfx("astronomer_constellation_tell", pos),
		"on_tell": func(_b: LxBossBase, _tgt: Vector2, dt: float, _prog: float) -> void:
			altitude = move_toward(altitude, ALT_DIVE, 52.0 * dt),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_dive_from = pos
			_dive_landed = false
			stage.play_sfx("owl_dive", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			var u: float = clampf(el / 0.30, 0.0, 1.0)
			altitude = lerpf(ALT_DIVE, 4.0, u)
			if el <= 0.30:
				move_boss(_dive_from.lerp(_dive_to, u) - pos, true)
			elif not _dive_landed:
				_dive_landed = true
				var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
				patterns.emit_fan(pos, d, 5 if phase >= 3 else 3, 0.85, 118.0, {"color": "ice", "source": "owl_dive_stars", "field_scale": 0.90, "damage": 0.5})
				stage.shake(0.16)
				stage.play_sfx("astronomer_constellation_fire", pos),
	})

	# Attack 2: Starlight Barrage — aimed starlight fan + twin crescent boomerangs
	register_attack("starlight_barrage", {
		"weight": 1.20, "tell": 0.54, "commit": 0.38, "recover": 1.02, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = AstroMove.DIVE
			decoy_offsets.clear()
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_sector(pos, d.angle() - 0.52, d.angle() + 0.52, 42.0, last_tell_duration, 0.0, "sky", "gold")
			if not arena_rect.grow(-11.0).has_point(tgt):
				ground.warn_ring(tgt, 20.0, last_tell_duration + 0.04, 1.0, "sky", "gold")
			stage.play_sfx("astronomer_constellation_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.72, 122.0, {"color": "sky", "source": "star_fan", "field_scale": 1.0, "damage": 0.5})
			patterns.emit_boomerang(pos, d.rotated(0.28), 124.0, 0.68, 0.72, {"color": "gold", "source": "star_boomerang", "field_scale": 1.0, "damage": 0.5})
			if phase >= 2:
				patterns.emit_boomerang(pos, d.rotated(-0.28), 124.0, 0.68, -0.72, {"color": "ice", "source": "star_boomerang", "field_scale": 1.0, "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("astronomer_constellation_fire", pos),
	})

	# Attack 3: Astrolabe Sweep — meridian sweep-wall with dodge gap + targeted star-lance
	register_attack("astrolabe_sweep", {
		"weight": 1.15, "tell": 0.56, "commit": 0.38, "recover": 1.02, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = AstroMove.DIVE
			decoy_offsets.clear()
			_sweep_dir = Vector2.LEFT if tgt.x < arena_rect.get_center().x else Vector2.RIGHT
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + d * 56.0, 8.0, last_tell_duration, 0.0, "gold", "cream")
			if not arena_rect.grow(-11.0).has_point(tgt):
				ground.warn_ring(tgt, 20.0, last_tell_duration + 0.04, 1.0, "gold", "cream")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var sx: float = arena_rect.end.x - 10.0 if _sweep_dir.x < 0.0 else arena_rect.position.x + 10.0
			var gap_idx: int = 3 if int(anim_t * 10.0) % 2 == 0 else 5
			patterns.emit_sweep_wall(Vector2(sx, c.y), _sweep_dir, arena_rect.size.y - 24.0, 9, gap_idx, 3, 108.0, {"color": "ice", "source": "meridian_wall", "damage": 0.5})
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, d, 3, 134.0, 0.09, {"color": "gold", "source": "astrolabe_lance", "field_scale": 1.0, "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("astronomer_constellation_fire", pos),
	})

	# Attack 4 (P2/P3): Constellation Nova — 1-2 decoy silhouettes (True Lens shatters for stagger!) + star rays
	register_attack("constellation_nova", {
		"phases": [2, 3], "weight": 1.55, "tell": NOVA_TELL_P2, "commit": 0.42, "recover": 1.25, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = AstroMove.CONSTELLATION
			star_base_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			facing = star_base_ang
			decoy_offsets.clear()
			if phase == 2:
				decoy_offsets.append(Vector2.from_angle(star_base_ang + PI * 0.55) * 44.0)
			else:
				decoy_offsets.append(Vector2.from_angle(star_base_ang + 2.1) * 46.0)
				decoy_offsets.append(Vector2.from_angle(star_base_ang - 2.1) * 46.0)
			var rays: int = 5 if phase >= 3 else 3
			ground.warn_ring(pos, 32.0, last_tell_duration, 0.0, "sky", "gold")
			for i: int in range(rays):
				var rd: Vector2 = Vector2.from_angle(star_base_ang + float(i) * (TAU / float(rays)))
				ground.warn_lane(pos, pos + rd * 52.0, 6.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("astronomer_constellation_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			decoy_offsets.clear()
			var rays: int = 5 if phase >= 3 else 3
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10, 114.0, gap_a, 0.88, {"color": "ice", "source": "constellation_ring", "field_scale": 1.05, "damage": 0.5})
			for i: int in range(rays):
				var rd: Vector2 = Vector2.from_angle(star_base_ang + float(i) * (TAU / float(rays)))
				patterns.emit_lane(pos, rd, 2, 116.0, 0.10, {"color": "gold", "source": "constellation_ray", "field_scale": 1.05, "damage": 0.5})
			stage.shake(0.22)
			stage.play_sfx("astronomer_constellation_fire", pos),
	})

	# Attack 5 (P3): Gravity Syzygy — twin orbiting LxFields wells bend a 5-arm celestial spiral!
	register_attack("gravity_syzygy", {
		"phases": [3], "weight": 1.75, "tell": 0.64, "commit": 0.52, "recover": 1.25, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = AstroMove.CONSTELLATION
			_ensure_wells(true)
			star_base_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			ground.warn_ring(pos, 34.0, last_tell_duration, 0.0, "gold", "ice")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 5, 108.0, star_base_ang, 0.34, 2, 0.18, {"color": "gold", "source": "syzygy_spiral", "field_scale": 1.25, "damage": 0.5})
			stage.shake(0.22)
			stage.play_sfx("eclipse_wave", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_wells()
	active_move = AstroMove.DIVE
	revealed = true
	reveal_t = 2.0
	star_base_ang = 0.0
	decoy_offsets.clear()
	_roaring = false
	altitude = ALT_PERCH
	true_core_lit_t = 0.0
	_well_orbit_a = 0.0
	_star_pedestals.clear()
	_clank_sfx_cd = 0.0


func _enter_phase(next_phase: int) -> void:
	# Compat hook for tests/luxel/boss_qa_capture.gd
	phase = clampi(next_phase, 1, 3)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true
	decoy_offsets.clear()
	altitude = ALT_PERCH
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# P2 Arena Mutation: Astral Chime carves outer void alcoves + lights safe star pedestals!
		_carve_safe_tile_near(Vector2(arena_rect.position.x - 24.0, c.y - 16.0), "pit")
		_carve_safe_tile_near(Vector2(arena_rect.end.x + 24.0, c.y - 16.0), "pit")
		_star_pedestals = [
			clamp_to_arena(c + Vector2(-64.0, -34.0)), clamp_to_arena(c + Vector2(64.0, -34.0)),
			clamp_to_arena(c + Vector2(-64.0, 34.0)), clamp_to_arena(c + Vector2(64.0, 34.0)),
		]
		props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, 0.0)), 4.5, "astro_astrolabe_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, 0.0)), 4.5, "astro_astrolabe_e")
		stage.darkness_pulse(0.64, 1.0)
		stage.shake(0.24)
		stage.play_sfx("astronomer_phase", pos)
		stage.play_sfx("clockwork_chime", pos)
	elif new_phase == 3:
		# P3 Arena Mutation: Gravity Syzygy awakens twin live orbiting polarity wells!
		_ensure_wells(true)
		stage.darkness_pulse(0.74, 1.15)
		stage.shake(0.28)
		stage.play_sfx("astronomer_phase", pos)
		stage.play_sfx("eclipse_wave", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	true_core_lit_t = maxf(0.0, true_core_lit_t - dt)
	revealed = true
	reveal_t = maxf(reveal_t, 1.0)
	if boss_state != BossState.COMMIT and boss_state != BossState.TELL:
		altitude = move_toward(altitude, ALT_PERCH + sin(anim_t * 3.0) * 2.5, 36.0 * dt)
	if _well_a != null and _well_a.active and _well_b != null and _well_b.active:
		_well_orbit_a = wrapf(_well_orbit_a + 1.15 * dt, -PI, PI)
		var c: Vector2 = arena_rect.get_center()
		var orb_v := Vector2(cos(_well_orbit_a) * 66.0, sin(_well_orbit_a) * 38.0)
		_well_a.pos = clamp_to_arena(c + orb_v)
		_well_b.pos = clamp_to_arena(c - orb_v)


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = source
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2
		elif b is String and src.is_empty():
			src = str(b)
	if boss_state == BossState.DEATH or src != "lens" or rad <= 0.0:
		return
	if orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius:
		true_core_lit_t = maxf(true_core_lit_t, 3.0)
		patterns.freeze_bolts_in_radius(pos, 108.0, 1.2, "lens")
		if boss_state == BossState.TELL and active_move == AstroMove.CONSTELLATION and not decoy_offsets.is_empty():
			# Active True Lens during Constellation TELL shatters decoys & staggers her!
			decoy_offsets.clear()
			active_move = AstroMove.DIVE
			add_stagger(stagger_threshold)
			stage.light_burst(pos, 72.0, 1.45, 0.36)
			stage.play_sfx("astronomer_lens_shatter", pos)


func take_hit(hit: LxHit) -> int:
	if not engaged and boss_state != BossState.DEATH and hit != null:
		if world_ctx != null and str(world_ctx.get("current_region_id")) == "orrery_r10":
			if _get_wick_pos().distance_to(pos) <= 92.0:
				engage()
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 15.0
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])
	var lens_mult: float = 1.35 if true_core_lit_t > 0.0 else 1.0

	if boss_state == BossState.STAGGER:
		return dmg * (2.00 if heavy else 1.45) * lens_mult
	if is_curved:
		return dmg * 1.35 * lens_mult
	if is_punishable():
		return dmg * (1.90 if heavy else 1.0) * lens_mult
	if heavy:
		return dmg * 1.85 * lens_mult

	# Spectral starlight veil outside punish windows: reduced plain bolt chip + astrolabe glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crystal_clank", pos)
	return dmg * (0.45 if true_core_lit_t > 0.0 else 0.30)


func _on_death_start() -> void:
	_unregister_wells()
	decoy_offsets.clear()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("astronomer_phase", pos)


func _ensure_wells(activate: bool) -> void:
	if _well_a == null:
		_well_a = SyzygyWellField.new()
		_well_a.is_push = true
	if _well_b == null:
		_well_b = SyzygyWellField.new()
		_well_b.is_push = false
	_well_a.active = activate
	_well_b.active = activate
	var c: Vector2 = arena_rect.get_center()
	_well_a.pos = clamp_to_arena(c + Vector2(66.0, 0.0))
	_well_b.pos = clamp_to_arena(c + Vector2(-66.0, 0.0))
	if activate and not _wells_reg:
		LxFields.add(_well_a)
		LxFields.add(_well_b)
		_wells_reg = true


func _unregister_wells() -> void:
	if _well_a != null:
		_well_a.active = false
		if _wells_reg:
			LxFields.remove(_well_a)
	if _well_b != null:
		_well_b.active = false
		if _wells_reg:
			LxFields.remove(_well_b)
	_wells_reg = false


func _build_star_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	if phase >= 2:
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	if phase >= 3:
		out.append(corners[2])
	return out


func _carve_safe_tile_near(world_pt: Vector2, tile_kind: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var tx: int = int(floorf(world_pt.x / 16.0))
	var ty: int = int(floorf(world_pt.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 34.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _visual_offset() -> Vector2:
	return Vector2(0.0, -altitude)


func _body_color() -> Color:
	return (PAL["gold"] if phase >= 3 else (PAL["ice"] if phase >= 2 else PAL["sky"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Ground shadow beneath floating owl
	draw_circle(Vector2.ZERO, maxf(3.0, body_radius * 0.72), Color(PAL["void"] as Color, 0.48))

	# P2 Star pedestals
	for sp: Vector2 in _star_pedestals:
		var lp: Vector2 = (sp - pos).round()
		draw_arc(lp, 8.0, 0.0, TAU, 12, Color(PAL["gold"] as Color, 0.65), 1.1)
		draw_circle(lp, 2.0, PAL["cream"] as Color)

	# P3 Twin Gravity Syzygy Wells
	for wf: SyzygyWellField in [_well_a, _well_b]:
		if wf != null and wf.active:
			var wp: Vector2 = (wf.pos - pos).round()
			var wcol: Color = (PAL["gold"] if wf.is_push else PAL["sky"]) as Color
			draw_arc(wp, wf.radius * 0.68, 0.0, TAU, 20, Color(wcol, 0.35), 1.1)
			draw_arc(wp, 14.0, anim_t * 3.0, anim_t * 3.0 + PI, 12, wcol, 1.4)
			draw_circle(wp, 3.5, PAL["cream"] as Color)

	# Constellation decoy phantom silhouettes during TELL
	for d_off: Vector2 in decoy_offsets:
		var dc: Vector2 = (c + d_off).round()
		draw_line(c, dc, Color(PAL["ice"] as Color, 0.30), 1.0)
		draw_arc(dc, body_radius + 4.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.3)
		draw_circle(dc, body_radius * 0.70, PAL["deep"] as Color)

	# True Lens exposed gold core
	if true_core_lit_t > 0.0:
		draw_arc(c, body_radius + 6.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.8)
		draw_circle(c, 3.0, PAL["cream"] as Color)

	# Spectral veil glint outside punish windows vs golden punish halo
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.0, facing - 1.15, facing + 1.15, 16, PAL["cream"] as Color, 2.2)
		draw_arc(c, body_radius + 7.0, facing - 0.85, facing + 0.85, 12, PAL["sky"] as Color, 1.2)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)
