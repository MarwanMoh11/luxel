class_name LxPhysGravityWell
extends LxToy
## Spatial gravity well registered with LxFields.
## Pulls or pushes bolts, lantern throws, curved beams, Wick, enemies, and blocks deterministically.
## Supports optional `lens_only` reveal and Apogee Clasp (`power_orbit_ring`) tangential lantern orbit.

const ORBIT_HANG_TIME: float = 6.5
const ORBIT_OMEGA: float = 3.2

var field_radius: float = 64.0
var strength: float = 720.0
var is_push: bool = false
var orbit_capture: bool = true
var orbit_r: float = 34.0
var lens_only: bool = false

var _ring_phase: float = 0.0
var _revealed_t: float = 0.0
var _flip_flash_t: float = 0.0
var _orbit_captured: bool = false
var _orbit_angle: float = 0.0
var _orbit_sign: float = 1.0
var _orbit_hit_cds: Dictionary = {}


func _toy_setup() -> void:
	kind = "gravity_well"
	field_radius = maxf(16.0, float(props.get("radius", 64.0)))
	radius = 10.0
	strength = maxf(0.0, float(props.get("strength", 720.0)))
	var mode_s: String = str(props.get("mode", "")).strip_edges().to_lower()
	is_push = bool(props.get("push", mode_s == "push"))
	if props.has("pull") and not bool(props.get("pull")):
		is_push = true
	orbit_capture = bool(props.get("orbit_capture", true))
	orbit_r = clampf(float(props.get("orbit_r", minf(34.0, field_radius * 0.52))), 16.0, field_radius * 0.76)
	lens_only = bool(props.get("lens_only", false))
	_revealed_t = 0.0 if lens_only else 1.0
	_orbit_captured = false
	_orbit_hit_cds.clear()
	z_index = LxPhysDraw.floor_z(region, -4)
	LxFields.add(self)
	queue_redraw()


func _exit_tree() -> void:
	LxFields.remove(self)


func _on_power_changed(_is_on: bool) -> void:
	var sig_mode: String = str(props.get("on_signal", "flip")).strip_edges().to_lower()
	if sig_mode == "toggle_active":
		active = not active
	elif sig_mode == "flip":
		is_push = not is_push
		_flip_flash_t = 0.28
	_emit_sfx("phantom_phase")
	queue_redraw()


func on_light(light_radius: float, source: String) -> void:
	if not active or not lens_only or light_radius <= 0.0:
		return
	var allow: bool = source == "lens" or source == "lens_anchor" or (
		source == "lantern_hung" and Lx.state != null and Lx.state.has_move("lens")
	)
	if allow:
		if _revealed_t <= 0.0:
			_emit_sfx("phantom_phase")
		_revealed_t = 0.28
		queue_redraw()


func is_field_active() -> bool:
	if not active or strength <= 0.01:
		return false
	if lens_only and _revealed_t <= 0.0:
		return false
	return true


func is_orbiting_lantern() -> bool:
	return _orbit_captured


func _has_apogee_clasp() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get("power_orbit_ring", false))


func can_capture_orbit(p: Vector2, move_dir: Vector2) -> bool:
	if not is_field_active() or not orbit_capture or not _has_apogee_clasp():
		return false
	if move_dir.length_squared() <= 0.0001:
		return false
	var to_well: Vector2 = pos - p
	var dist: float = to_well.length()
	var min_r: float = maxf(12.0, orbit_r * 0.45)
	var max_r: float = minf(field_radius + 4.0, orbit_r + 22.0)
	if dist < min_r or dist > max_r:
		return false
	var radial_dot: float = absf(move_dir.normalized().dot(to_well / dist))
	return radial_dot < 0.48


func _what_multiplier(what: String) -> float:
	match what:
		"bolt", "beam":
			return 1.25
		"lantern":
			return 1.0
		"wick":
			return 0.24
		"enemy":
			return 0.30
		"block":
			return 0.55
	return 1.0


func field_accel(p: Vector2, what: String) -> Vector2:
	if not is_field_active():
		return Vector2.ZERO
	var delta: Vector2 = pos - p
	var dist_sq: float = delta.length_squared()
	if dist_sq >= field_radius * field_radius or dist_sq <= 0.0001:
		return Vector2.ZERO
	var dist: float = sqrt(dist_sq)
	# Deterministic softened radial falloff: crisp curve near rim, zero NaN at center, smooth edge
	var u: float = clampf(1.0 - dist / field_radius, 0.0, 1.0)
	var falloff: float = (0.35 + 0.65 * u) * (1.0 - exp(-dist / 10.0))
	var dir_n: Vector2 = delta / dist
	if is_push:
		dir_n = -dir_n
	return dir_n * (strength * falloff * _what_multiplier(what))


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		_orbit_captured = false
		return
	if lens_only and _revealed_t > 0.0:
		_revealed_t = maxf(0.0, _revealed_t - dt)
	if _flip_flash_t > 0.0:
		_flip_flash_t = maxf(0.0, _flip_flash_t - dt)
	var spd: float = 0.45 if LxHudFx.flash_reduced() else 1.0
	_ring_phase = fposmod(_ring_phase + dt * spd, 1.0)
	_tick_orbit_lantern(dt)
	queue_redraw()


func _tick_orbit_lantern(dt: float) -> void:
	if not _orbit_hit_cds.is_empty():
		var expired: Array[int] = []
		for k: Variant in _orbit_hit_cds.keys():
			var left: float = float(_orbit_hit_cds[k]) - dt
			if left <= 0.0:
				expired.append(int(k))
			else:
				_orbit_hit_cds[k] = left
		for ek: int in expired:
			_orbit_hit_cds.erase(ek)

	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		_orbit_captured = false
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead or w.lantern == null or not is_instance_valid(w.lantern):
		_orbit_captured = false
		return
	var lan: LxLantern = w.lantern

	if _orbit_captured:
		if not is_field_active() or lan.state != LxLantern.State.HANGING or w.is_zipping():
			_orbit_captured = false
			return
		_orbit_angle = wrapf(_orbit_angle + _orbit_sign * ORBIT_OMEGA * dt, -PI, PI)
		var prev_p: Vector2 = lan.pos
		var next_p: Vector2 = pos + Vector2.from_angle(_orbit_angle) * orbit_r
		lan.prev_pos = prev_p
		lan.pos = next_p
		lan.global_position = next_p.round()
		lan.dir = Vector2.from_angle(_orbit_angle + _orbit_sign * (PI * 0.5))
		_sweep_orbit_contacts(w, lan, prev_p, next_p)
		return

	if lan.state == LxLantern.State.FLYING and can_capture_orbit(lan.pos, lan.dir):
		var rel: Vector2 = lan.pos - pos
		var cross: float = rel.x * lan.dir.y - rel.y * lan.dir.x
		_orbit_sign = 1.0 if cross >= 0.0 else -1.0
		_orbit_angle = rel.angle()
		_orbit_captured = true
		_orbit_hit_cds.clear()
		lan.state = LxLantern.State.HANGING
		lan.vel = Vector2.ZERO
		lan.hang_max = maxf(lan.hang_max, ORBIT_HANG_TIME)
		lan.hang_timer = lan.hang_max
		var snap_p: Vector2 = pos + Vector2.from_angle(_orbit_angle) * orbit_r
		lan.prev_pos = lan.pos
		lan.pos = snap_p
		lan.global_position = snap_p.round()
		w.spawn_ring(pos, orbit_r - 3.0, orbit_r + 3.0, 0.24, PAL["gold"] as Color, 1.5)
		_emit_sfx("gravity_curve")


func _sweep_orbit_contacts(w: LxWick, lan: LxLantern, a: Vector2, b: Vector2) -> void:
	if region == null or not region.has_method("get_interactables"):
		return
	var move_d: Vector2 = (b - a).normalized() if b.distance_squared_to(a) > 0.001 else lan.dir
	var light_r: float = lan.get_light_radius()
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not is_instance_valid(it_v) or not (it_v is LxInteractable) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not it.active:
			continue
		var d_seg: float = Geometry2D.get_closest_point_to_segment(it.pos, a, b).distance_to(it.pos)
		if d_seg <= light_r + it.radius:
			it.on_light(light_r, "lantern_hung")
		if d_seg <= it.radius + 6.0 and it.kind in ["brazier", "timed_brazier", "switch_eye", "star_node", "crystal_toggle"]:
			var iid: int = it.get_instance_id()
			if not _orbit_hit_cds.has(iid):
				_orbit_hit_cds[iid] = 0.75
				var hit := LxHit.make(LxHit.SOURCE_THROW, lan.throw_damage, move_d, b, lan.shield_wear, true, false, w, false, LxHit.COLOR_YELLOW, 90.0)
				it.on_hit(hit)


func get_light_pool() -> Vector4:
	if not is_field_active():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, field_radius * 0.65, 0.55 if _orbit_captured else 0.45)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["is_push"] = is_push
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("is_push"):
		is_push = bool(d.get("is_push", is_push))
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	if lens_only and _revealed_t <= 0.0:
		# Subtle ice corner glints hint at a cloaked well without giving away polarity
		var c_sh := Color(PAL["ice"] as Color, 0.28)
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 12, c_sh, 1.0)
		for i: int in range(4):
			var gp: Vector2 = (Vector2.from_angle(float(i) * PI * 0.5 + 0.4) * 14.0).round()
			draw_rect(Rect2(gp, Vector2.ONE), c_sh)
		return

	var fr: bool = LxHudFx.flash_reduced()
	var c_ring: Color = (PAL["coral"] if is_push else PAL["sky"]) as Color
	var c_hi: Color = (PAL["gold"] if is_push else PAL["ice"]) as Color
	var c_core: Color = (PAL["cream"] if is_push else PAL["deep"]) as Color

	# Outer boundary dashed ring
	for s: int in range(16):
		var a0: float = float(s) * (TAU / 16.0)
		draw_arc(Vector2.ZERO, field_radius, a0, a0 + 0.22, 3, Color(c_ring, 0.30), 1.0)

	# 2 animated concentric pull (inward) / push (outward) wave rings
	for k: int in range(2):
		var ph: float = fposmod(_ring_phase + float(k) * 0.5, 1.0)
		var u: float = ph if is_push else (1.0 - ph)
		var r: float = lerpf(10.0, field_radius - 2.0, u)
		var a: float = sin(ph * PI) * (0.42 if fr else 0.58)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(c_hi if k == 0 else c_ring, a), 1.0)

	# Apogee Clasp tangent orbit track guide
	if orbit_capture and (_has_apogee_clasp() or _orbit_captured):
		var orb_c: Color = (PAL["cream"] if _orbit_captured else PAL["gold"]) as Color
		var orb_a: float = 0.85 if _orbit_captured else 0.34
		draw_arc(Vector2.ZERO, orbit_r, 0.0, TAU, 28, Color(orb_c, orb_a), 1.2 if _orbit_captured else 1.0)
		for ti: int in range(2):
			var ta: float = _clock * (0.7 if fr else 1.5) + float(ti) * PI
			var tp: Vector2 = (Vector2.from_angle(ta) * orbit_r).round()
			var tdir := Vector2(-sin(ta), cos(ta))
			LxPhysDraw.draw_chevron(self, tp, tdir, Color(orb_c, orb_a + 0.12), Color.TRANSPARENT, 2.5)

	# Greyscale-distinct directional chevrons: PULL points inward, PUSH points outward
	var chev_r: float = clampf(field_radius * 0.42, 16.0, 28.0)
	var spin: float = _clock * (0.45 if fr else 1.15) * (1.0 if is_push else -1.0)
	for i: int in range(4):
		var ang: float = spin + float(i) * (PI * 0.5)
		var radial := Vector2.from_angle(ang)
		var cp: Vector2 = (radial * chev_r).round()
		var cdir: Vector2 = radial if is_push else -radial
		LxPhysDraw.draw_chevron(self, cp, cdir, c_hi, PAL["void"] as Color, 3.0)

	# Central singularity core (distinct silhouette: PUSH = bright sunburst + spikes, PULL = dark hollow eye)
	draw_circle(Vector2.ZERO, 8.0, PAL["void"] as Color)
	draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 16, c_ring, 1.0)
	if is_push:
		draw_circle(Vector2.ZERO, 5.0, PAL["gold"] as Color)
		draw_circle(Vector2.ZERO, 3.0, c_core)
		for si: int in range(4):
			var sd := Vector2.from_angle(float(si) * PI * 0.5)
			draw_line((sd * 6.0).round(), (sd * 10.0).round(), PAL["gold"] as Color, 1.0)
	else:
		draw_circle(Vector2.ZERO, 5.0, c_core)
		draw_circle(Vector2.ZERO, 2.5, PAL["void"] as Color)
		draw_arc(Vector2.ZERO, 4.5, 0.0, TAU, 12, c_hi, 1.0)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["ice"] as Color)

	if _flip_flash_t > 0.0:
		var fu: float = 1.0 - clampf(_flip_flash_t / 0.28, 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(8.0, field_radius * 0.75, fu), 0.0, TAU, 24, Color(PAL["cream"] as Color, (1.0 - fu) * 0.85), 1.5)
