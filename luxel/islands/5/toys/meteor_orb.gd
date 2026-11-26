class_name LxI5MeteorOrb
extends LxToy
## Heavy gravity-curving meteor boulder (Island 5).
## Plain bolt gives a gentle 90 px/s nudge; Throw/Beam imparts a 240 px/s orbital slingshot.
## Samples LxFields.accel_at(pos, "block") every tick so gravity/polarity wells curve its flight!
## Breaks cracked_wall, triggers switch_eye/star_bell/crystal_toggle/star_node/pressure_plate,
## deals 2.5 stagger damage to enemies/bosses, and respawns cleanly at cradle_pos in respawn_s.

enum OrbState { RESTING, FLYING, RESPAWNING }

const NUDGE_SPEED: float = 90.0
const SLING_SPEED: float = 240.0
const MAX_SPEED: float = 340.0
const VOID_DROP_SPEED: float = 52.0
const GROUND_DRAG: float = 55.0
const METEOR_DAMAGE: float = 2.5

var cradle_pos: Vector2 = Vector2.ZERO
var mass: float = 1.0
var respawn_s: float = 0.8
var breaks_cracked: bool = true

var orb_state: int = OrbState.RESTING
var vel: Vector2 = Vector2.ZERO
var light_color: String = LxHit.COLOR_YELLOW
var curve_angle_deg: float = 0.0

var _respawn_left: float = 0.0
var _flight_t: float = 0.0
var _roll_sfx_cd: float = 0.0
var _hit_ids: Array[int] = []
var _trail: Array[Vector2] = []


func _toy_setup() -> void:
	kind = "meteor_orb"
	size = Vector2(14.0, 14.0)
	radius = 8.0
	cradle_pos = _parse_vec2(props.get("cradle_pos", pos), pos)
	mass = maxf(0.4, float(props.get("mass", 1.0)))
	respawn_s = maxf(0.15, float(props.get("respawn_s", 0.8)))
	breaks_cracked = bool(props.get("breaks_cracked", true))
	_reset_to_cradle()


func _reset_to_cradle() -> void:
	pos = cradle_pos
	position = pos.round()
	vel = Vector2.ZERO
	orb_state = OrbState.RESTING
	light_color = LxHit.COLOR_YELLOW
	curve_angle_deg = 0.0
	_respawn_left = 0.0
	_flight_t = 0.0
	_roll_sfx_cd = 0.22
	_hit_ids.clear()
	_trail.clear()
	queue_redraw()


func reset_toy() -> void:
	_reset_to_cradle()


func move_to(new_pos: Vector2) -> void:
	pos = new_pos
	position = pos.round()
	queue_redraw()


func is_solid() -> bool:
	return active and orb_state == OrbState.RESTING


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - Vector2(6.0, 6.0), Vector2(12.0, 12.0))


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or orb_state == OrbState.RESPAWNING:
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return false
	var dir: Vector2 = hit.dir.normalized() if hit.dir.length_squared() > 0.001 else Vector2.RIGHT
	var is_heavy: bool = hit.source in ["beam", "throw", "recall", "zip", "sunflare"]
	var launch_spd: float = (SLING_SPEED if is_heavy else NUDGE_SPEED) / mass
	vel = dir * launch_spd
	orb_state = OrbState.FLYING
	light_color = LxHit.COLOR_BLUE if hit.is_blue() else LxHit.COLOR_YELLOW
	curve_angle_deg = hit.curve_angle_deg
	_flight_t = 0.0
	_roll_sfx_cd = 0.22
	_hit_ids.clear()
	_trail.clear()
	_emit_sfx("meteor_clank")
	_emit_gust(48.0 if is_heavy else 28.0, 44.0 if is_heavy else 24.0)
	if is_heavy and Lx.events != null:
		Lx.events.shake_requested.emit(0.08)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	match orb_state:
		OrbState.RESPAWNING:
			_respawn_left -= dt
			if _respawn_left <= 0.0:
				_reset_to_cradle()
				_emit_sfx("phantom_phase")
			else:
				queue_redraw()
		OrbState.FLYING:
			_tick_flight(dt)
		OrbState.RESTING:
			if LxFields.has_fields():
				var fa: Vector2 = LxFields.accel_at(pos, "block")
				if fa.length_squared() > 2500.0 and pos.distance_to(cradle_pos) > 8.0:
					vel = (fa / mass) * dt
					orb_state = OrbState.FLYING
			if not LxHudFx.flash_reduced():
				queue_redraw()


func _tick_flight(dt: float) -> void:
	_flight_t += dt
	var prev_p: Vector2 = pos
	if LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(pos, "block")
		if fa.length_squared() > 0.01:
			var old_dir: Vector2 = vel.normalized() if vel.length_squared() > 1.0 else Vector2.RIGHT
			vel += (fa / mass) * dt
			if vel.length_squared() > 1.0:
				curve_angle_deg += rad_to_deg(absf(old_dir.angle_to(vel.normalized())))
		else:
			vel = vel.move_toward(Vector2.ZERO, GROUND_DRAG * dt)
	else:
		vel = vel.move_toward(Vector2.ZERO, GROUND_DRAG * dt)

	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED

	var nxt: Vector2 = pos + vel * dt
	_trail.append(prev_p)
	if _trail.size() > 8:
		_trail.remove_at(0)

	# 1. Check enemies/bosses along sweep
	if _check_enemy_hits(prev_p, nxt):
		_start_respawn()
		return

	# 2. Check interactable hits (cracked_wall, switches, star_bells, crystals, stars, plates)
	if _check_interactable_hits(prev_p, nxt):
		_start_respawn()
		return

	# 3. Check world bounds & solid walls
	if region != null:
		var b_v: Variant = region.get("bounds")
		if b_v is Rect2 and not (b_v as Rect2).grow(-4.0).has_point(nxt):
			_start_respawn()
			return
		if region.has_method("tile_at"):
			var tt: String = str(region.call("tile_at", nxt))
			if tt in ["wall", "glass", "mirror"]:
				_emit_sfx("meteor_clank")
				_start_respawn()
				return
			var over_void: bool = region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", nxt))
			if over_void and vel.length() <= VOID_DROP_SPEED:
				_start_respawn()
				return

	pos = nxt
	position = pos.round()
	_roll_sfx_cd = maxf(0.0, _roll_sfx_cd - dt)
	if vel.length() > 60.0 and _roll_sfx_cd <= 0.0:
		_roll_sfx_cd = 0.40
		_emit_sfx("meteor_orb_roll")

	# Stop smoothly on solid ground when coasted out, or respawn if flown too long
	if vel.length() <= 14.0:
		if region != null and region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", pos)):
			_start_respawn()
		else:
			vel = Vector2.ZERO
			orb_state = OrbState.RESTING
			_trail.clear()
	elif _flight_t > 4.5:
		_start_respawn()
	queue_redraw()


func _check_enemy_hits(a: Vector2, b: Vector2) -> bool:
	if region == null or not region.has_method("get_enemies"):
		return false
	var move_d: Vector2 = vel.normalized() if vel.length_squared() > 1.0 else Vector2.RIGHT
	var hit_any: bool = false
	for e_v: Variant in (region.call("get_enemies") as Array):
		if not (e_v is Object) or not is_instance_valid(e_v as Object):
			continue
		var en: Object = e_v as Object
		if en.has_method("is_alive") and not bool(en.call("is_alive")):
			continue
		var eid: int = en.get_instance_id()
		if _hit_ids.has(eid):
			continue
		var ep: Vector2 = (en as Node2D).global_position if en is Node2D else (en.get("pos") as Vector2 if en.get("pos") is Vector2 else Vector2(-9999.0, -9999.0))
		var erad: float = float(en.get("body_radius")) if (en.get("body_radius") is float or en.get("body_radius") is int) else 8.0
		if Geometry2D.get_closest_point_to_segment(ep, a, b).distance_to(ep) <= erad + radius:
			_hit_ids.append(eid)
			var hit := LxHit.make(LxHit.SOURCE_THROW, METEOR_DAMAGE, move_d, pos, 2.5, true, false, self, true, light_color, curve_angle_deg)
			if en.has_method("on_hit"):
				en.call("on_hit", hit)
			elif en.has_method("take_hit"):
				en.call("take_hit", hit)
			_emit_sfx("meteor_clank")
			if Lx.events != null:
				Lx.events.shake_requested.emit(0.14)
				Lx.events.hitstop_requested.emit(0.05)
			hit_any = true
	return hit_any


func _check_interactable_hits(a: Vector2, b: Vector2) -> bool:
	if region == null or not region.has_method("get_interactables"):
		return false
	var move_d: Vector2 = vel.normalized() if vel.length_squared() > 1.0 else Vector2.RIGHT
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not it.active:
			continue
		var iid: int = it.get_instance_id()
		if _hit_ids.has(iid):
			continue
		var hit_ok: bool = false
		if it.is_solid():
			var sr: Rect2 = it.get_solid_rect().grow(radius * 0.7)
			hit_ok = sr.has_point(b) or sr.has_point(a.lerp(b, 0.5))
		else:
			hit_ok = Geometry2D.get_closest_point_to_segment(it.pos, a, b).distance_to(it.pos) <= it.radius + radius
		if not hit_ok:
			continue

		if it.kind == "cracked_wall" and breaks_cracked:
			_hit_ids.append(iid)
			var h_brk := LxHit.make(LxHit.SOURCE_BEAM, METEOR_DAMAGE, move_d, pos, 3.0, true, true, self, true, light_color, curve_angle_deg)
			it.on_hit(h_brk)
			_emit_sfx("meteor_orb_shatter")
			return true

		if it.kind in ["switch_eye", "star_bell", "crystal_toggle", "timed_brazier", "brazier", "star_node", "polarity_well"]:
			_hit_ids.append(iid)
			var h_tr := LxHit.make(LxHit.SOURCE_THROW, METEOR_DAMAGE, move_d, pos, 2.0, true, false, self, true, light_color, curve_angle_deg)
			it.on_hit(h_tr)
			if it.is_solid():
				_emit_sfx("meteor_clank")
				return true
			continue

		if it.is_solid() and it.kind != "pressure_plate":
			_emit_sfx("meteor_clank")
			return true
	return false


func _start_respawn() -> void:
	orb_state = OrbState.RESPAWNING
	vel = Vector2.ZERO
	_respawn_left = respawn_s
	_trail.clear()
	_emit_gust(42.0, 36.0)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active or orb_state == OrbState.RESPAWNING:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 40.0 if orb_state == OrbState.FLYING else 24.0, 0.65 if orb_state == OrbState.FLYING else 0.35)


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	var is_blue: bool = (light_color == LxHit.COLOR_BLUE)

	# Carved celestial cradle socket at cradle_pos (relative to orb position)
	var cr: Vector2 = (cradle_pos - pos).round()
	draw_circle(cr, 8.0, Color(c_void, 0.48))
	draw_arc(cr, 7.0, 0.0, TAU, 16, c_apr, 1.0)
	draw_arc(cr, 4.5, 0.0, TAU, 12, c_dusk, 1.0)
	for ct: Vector2 in [Vector2(-8.0, 0.0), Vector2(7.0, 0.0), Vector2(0.0, -8.0), Vector2(0.0, 7.0)]:
		draw_rect(Rect2((cr + ct).round(), Vector2(1.0, 1.0)), c_gold)

	if orb_state == OrbState.RESPAWNING:
		var u: float = 1.0 - clampf(_respawn_left / maxf(respawn_s, 0.01), 0.0, 1.0)
		var ring_r: float = roundf(lerpf(14.0, 5.0, u))
		draw_arc(cr, ring_r, 0.0, TAU, 14, Color(c_gold, 0.45 if fr else (0.35 + u * 0.6)), 1.0)
		draw_circle(cr, roundf(maxf(2.0, u * 5.0)), Color(c_coral, 0.65 if fr else (0.5 + u * 0.4)))
		draw_rect(Rect2((cr - Vector2.ONE).round(), Vector2(2.0, 2.0)), c_cream)
		return

	# Blazing comet tail while flying
	if orb_state == OrbState.FLYING and not _trail.is_empty():
		var tc: Color = c_ice if is_blue else c_coral
		var mid_c: Color = c_sky if is_blue else c_apr
		var hi_c: Color = c_cream if is_blue else c_gold
		for ti: int in range(_trail.size()):
			var frac: float = float(ti + 1) / float(_trail.size() + 1)
			var tp: Vector2 = (_trail[ti] - pos).round()
			draw_circle(tp, roundf(lerpf(2.0, 5.5, frac)), Color(tc, frac * 0.52))
			draw_rect(Rect2((tp - Vector2(1.0, 1.0)).round(), Vector2(3.0, 3.0)), Color(mid_c, frac * 0.68))
			draw_rect(Rect2(tp, Vector2(1.0, 1.0)), Color(hi_c, frac * 0.88))

	# Grounded shadow beneath asteroid core
	_draw_ground_shadow(8.0, 3.5, Vector2(1.0, 6.0))

	# Faceted cosmic asteroid/meteor silhouette (chiseled octagonal rock, not a smooth circle)
	var hull := PackedVector2Array([
		Vector2(-3.0, -8.0), Vector2(3.0, -8.0),
		Vector2(7.0, -4.0), Vector2(8.0, 1.0),
		Vector2(5.0, 6.0), Vector2(-2.0, 7.0),
		Vector2(-7.0, 4.0), Vector2(-8.0, -3.0),
	])
	var body := PackedVector2Array([
		Vector2(-3.0, -7.0), Vector2(3.0, -7.0),
		Vector2(6.0, -3.0), Vector2(7.0, 1.0),
		Vector2(4.0, 5.0), Vector2(-2.0, 6.0),
		Vector2(-6.0, 3.0), Vector2(-7.0, -3.0),
	])
	var top_facet := PackedVector2Array([
		Vector2(-3.0, -7.0), Vector2(3.0, -7.0),
		Vector2(5.0, -3.0), Vector2(0.0, -1.0),
		Vector2(-5.0, -1.0), Vector2(-6.0, -3.0),
	])
	var left_facet := PackedVector2Array([
		Vector2(-6.0, -3.0), Vector2(-3.0, -2.0),
		Vector2(-2.0, 4.0), Vector2(-6.0, 3.0),
	])
	draw_colored_polygon(hull, c_void)
	draw_colored_polygon(body, c_night)
	draw_colored_polygon(top_facet, c_plum)
	draw_colored_polygon(left_facet, c_dusk)
	# Crisp sunlit rock bevel on upper-left ridge
	draw_rect(Rect2(-3.0, -7.0, 5.0, 1.0), c_mauve)
	draw_rect(Rect2(-6.0, -4.0, 2.0, 1.0), c_mauve)
	draw_rect(Rect2(-5.0, -5.0, 2.0, 1.0), c_coral if not is_blue else c_sky)

	# Cratered basalt pits with lit inner rims
	draw_rect(Rect2(-5.0, 1.0, 3.0, 2.0), c_void)
	draw_rect(Rect2(-5.0, 3.0, 2.0, 1.0), c_plum)
	draw_rect(Rect2(3.0, -4.0, 2.0, 2.0), c_void)
	draw_rect(Rect2(2.0, -3.0, 1.0, 2.0), c_coral if not is_blue else c_blue)

	# Glowing star-vein fissures radiating across the rock face
	var flying: bool = (orb_state == OrbState.FLYING)
	var pulse_hi: bool = fr or flying or (int(floorf(_clock * 3.5)) % 2 == 0)
	var fissure_edge: Color = c_blue if is_blue else c_coral
	var fissure_mid: Color = c_sky if is_blue else c_gold
	var fissure_hot: Color = c_cream if (flying or pulse_hi) else (c_ice if is_blue else c_apr)

	# Outer fissure glow
	draw_line(Vector2(-5.0, -2.0), Vector2(1.0, 1.0), fissure_edge, 2.0)
	draw_line(Vector2(1.0, 1.0), Vector2(5.0, -1.0), fissure_edge, 2.0)
	draw_line(Vector2(0.0, -5.0), Vector2(1.0, 1.0), fissure_edge, 2.0)
	draw_line(Vector2(1.0, 1.0), Vector2(2.0, 5.0), fissure_edge, 1.0)
	# Inner bright star-veins
	draw_line(Vector2(-4.0, -2.0), Vector2(1.0, 1.0), fissure_mid, 1.0)
	draw_line(Vector2(1.0, 1.0), Vector2(5.0, -1.0), fissure_mid, 1.0)
	draw_line(Vector2(0.0, -5.0), Vector2(1.0, 1.0), fissure_mid, 1.0)
	draw_line(Vector2(1.0, 1.0), Vector2(2.0, 4.0), fissure_mid, 1.0)
	# Radiant star-vein nexus core
	draw_rect(Rect2(-1.0, -1.0, 3.0, 3.0), fissure_mid)
	draw_rect(Rect2(0.0, 0.0, 2.0, 2.0), fissure_hot)
	draw_rect(Rect2(0.0, -1.0, 1.0, 1.0), c_cream)

	# Orbital cosmic dust pips circling the asteroid
	var orb_phase: float = 0.0 if fr else _clock * (2.6 if flying else 1.2)
	for di: int in range(3):
		var ang: float = orb_phase + float(di) * (TAU / 3.0)
		var rx: float = 10.5 if di == 0 else 9.5
		var ry: float = 6.5 if di == 1 else 8.0
		var dp := Vector2(roundf(cos(ang) * rx), roundf(sin(ang) * ry - 1.0))
		draw_rect(Rect2(dp - Vector2.ONE, Vector2(3.0, 3.0)), Color(c_void, 0.65))
		var pip_c: Color = c_cream if di == 0 else (c_ice if is_blue else (c_gold if di == 1 else c_apr))
		draw_rect(Rect2(dp, Vector2(1.0, 1.0)), pip_c)

	_draw_signal_pulses()
