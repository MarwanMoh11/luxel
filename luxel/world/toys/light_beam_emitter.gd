class_name LxBeamEmitter
extends LxToy
## Continuous or pulsed optical beam emitter with cached per-tick ray tracing.
## Reflects off mirrors/blue_transformers (with colour change), splits on prisms, tints through LxColorGlass,
## blocked by walls/solids/enemies, feeds beam_sensor/light_sensor/light_plant, and can hurt Wick with a clear telegraph.
## Props: dir ("n"|"e"|"s"|"w"|[x,y]), color ("gold"|"blue"|"rose"), period (float, 0=always on),
## duty (float 0..1), offset (float), range (float), max_bounces (int), damage (float), harms_wick (bool),
## needs_signal (bool), invert_signal (bool).

const RAY_STEP: float = 4.0
const MAX_SEGMENTS: int = 12
const TELEGRAPH_BASE: float = 0.45
const SPLIT_DEG: float = 18.0

var emit_dir: Vector2 = Vector2.RIGHT
var beam_color: String = "gold"
var period: float = 0.0
var duty: float = 0.5
var phase_offset: float = 0.0
var max_range: float = 280.0
var max_bounces: int = 4
var beam_damage: float = 0.0
var harms_wick: bool = false
var needs_signal: bool = false
var invert_signal: bool = false

var beam_on: bool = true
var telegraphing: bool = false
var segments: Array[Dictionary] = [] # [{start, end, dir, color, bounce}]

var _cache_sig: int = 0
var _cache_valid: bool = false
var _cycle_t: float = 0.0
var _harm_cd: float = 0.0
var _telegraph_sfx_played: bool = false
var _hit_sensors: Array[Dictionary] = []
var _hit_plants: Array[Dictionary] = []


func _toy_setup() -> void:
	kind = "beam_emitter"
	emit_dir = dir_vec("dir", Vector2.RIGHT)
	if emit_dir.length_squared() <= 0.001:
		emit_dir = Vector2.RIGHT
	beam_color = LxToyDraw.normalize_light_color(str(props.get("color", "gold")))
	period = maxf(0.0, float(props.get("period", 0.0)))
	duty = clampf(float(props.get("duty", 0.5)), 0.05, 0.95)
	phase_offset = float(props.get("offset", 0.0))
	max_range = maxf(32.0, float(props.get("range", 280.0)))
	max_bounces = clampi(int(props.get("max_bounces", 4)), 0, 8)
	beam_damage = maxf(0.0, float(props.get("damage", 0.0)))
	harms_wick = bool(props.get("harms_wick", beam_damage > 0.0))
	if harms_wick and beam_damage <= 0.0:
		beam_damage = 1.0
	needs_signal = bool(props.get("needs_signal", false))
	invert_signal = bool(props.get("invert_signal", false))
	radius = maxf(10.0, radius)
	_cycle_t = phase_offset
	_cache_sig = 0
	_cache_valid = false
	_harm_cd = 0.0
	_telegraph_sfx_played = false
	segments.clear()
	_hit_sensors.clear()
	_hit_plants.clear()
	_update_cycle_state()
	if beam_on:
		retrace_beam(true)
	queue_redraw()


func reset_toy() -> void:
	_cycle_t = phase_offset
	_cache_sig = 0
	_cache_valid = false
	_harm_cd = 0.0
	_telegraph_sfx_played = false
	_update_cycle_state()
	if beam_on:
		retrace_beam(true)
	else:
		segments.clear()
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0)) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		segments.clear()
		return
	if _harm_cd > 0.0:
		_harm_cd = maxf(0.0, _harm_cd - dt)
	_cycle_t += dt
	var prev_on: bool = beam_on
	var prev_tel: bool = telegraphing
	_update_cycle_state()
	if telegraphing and not prev_tel and not _telegraph_sfx_played:
		_telegraph_sfx_played = true
		_emit_sfx("beam_charge")
	if not telegraphing:
		_telegraph_sfx_played = false
	if beam_on:
		retrace_beam(not prev_on)
		_deliver_beam_effects(dt)
	elif prev_on:
		segments.clear()
		_hit_sensors.clear()
		_hit_plants.clear()
		_cache_sig = 0
		_cache_valid = false
		queue_redraw()
	elif telegraphing:
		retrace_beam(not prev_tel)
		queue_redraw()


func _update_cycle_state() -> void:
	var enabled: bool = true
	if needs_signal:
		enabled = powered
	elif invert_signal:
		enabled = not powered
	if not enabled:
		beam_on = false
		telegraphing = false
		return
	if period <= 0.01:
		beam_on = true
		telegraphing = false
		return
	var u: float = fposmod(_cycle_t, period)
	var on_dur: float = period * duty
	var tel_dur: float = minf(period - on_dur, TELEGRAPH_BASE * LxToyDraw.assist_tell_scale()) if harms_wick else 0.0
	if u < on_dur:
		beam_on = true
		telegraphing = false
	elif tel_dur > 0.0 and u >= period - tel_dur:
		beam_on = false
		telegraphing = true
	else:
		beam_on = false
		telegraphing = false


func retrace_beam(force: bool = false) -> void:
	var sig: int = _build_scene_signature()
	if not force and _cache_valid and sig == _cache_sig:
		return
	_cache_sig = sig
	_cache_valid = true
	segments.clear()
	_hit_sensors.clear()
	_hit_plants.clear()
	var queue: Array[Dictionary] = [{
		"start": pos + emit_dir * 8.0,
		"dir": emit_dir,
		"color": beam_color,
		"bounces": max_bounces,
		"bounce_idx": 0,
		"ignore_id": get_instance_id(),
	}]
	var inters: Array = region.call("get_interactables") as Array if (region != null and region.has_method("get_interactables")) else []
	var enemies: Array = region.call("get_enemies") as Array if (region != null and region.has_method("get_enemies")) else []
	while not queue.is_empty() and segments.size() < MAX_SEGMENTS:
		var ray: Dictionary = queue.pop_front() as Dictionary
		_trace_single_ray(ray, inters, enemies, queue)
	queue_redraw()


static func _mix_hash(h: int, v: int) -> int:
	return (h ^ v) * 1099511628211


func _build_scene_signature() -> int:
	var h: int = -3750763034362895579
	h = _mix_hash(h, (1 if beam_on else 0) | ((1 if telegraphing else 0) << 1) | (max_bounces << 2))
	h = _mix_hash(h, roundi(pos.x * 10.0))
	h = _mix_hash(h, roundi(pos.y * 10.0))
	h = _mix_hash(h, roundi(emit_dir.x * 100.0))
	h = _mix_hash(h, roundi(emit_dir.y * 100.0))
	h = _mix_hash(h, beam_color.hash())
	if region != null and is_instance_valid(region) and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not is_instance_valid(it_v) or it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			var c_s: String = str(it.call("get_tint_color")) if it.has_method("get_tint_color") else ""
			var is_sol: bool = it.is_solid()
			var is_ref: bool = it.is_reflective()
			if is_sol or is_ref or not c_s.is_empty() or it.kind in ["beam_sensor", "light_sensor", "light_plant"]:
				h = _mix_hash(h, it.get_instance_id())
				h = _mix_hash(h, (1 if it.active else 0) | ((1 if is_sol else 0) << 1))
				h = _mix_hash(h, roundi(it.pos.x))
				h = _mix_hash(h, roundi(it.pos.y))
				if is_ref:
					var nv: Variant = it.get("normal")
					if nv is Vector2:
						h = _mix_hash(h, roundi((nv as Vector2).x * 100.0))
						h = _mix_hash(h, roundi((nv as Vector2).y * 100.0))
				if not c_s.is_empty():
					h = _mix_hash(h, c_s.hash())
	if region != null and is_instance_valid(region) and region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if is_instance_valid(e_v) and e_v is LxEnemyBrain:
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive():
					h = _mix_hash(h, e.get_instance_id())
					h = _mix_hash(h, roundi(e.pos.x))
					h = _mix_hash(h, roundi(e.pos.y))
	return h


func _trace_single_ray(ray: Dictionary, inters: Array, enemies: Array, queue: Array[Dictionary]) -> void:
	var origin: Vector2 = ray["start"] as Vector2
	var dir: Vector2 = (ray["dir"] as Vector2).normalized()
	var col_name: String = str(ray["color"])
	var bounces_left: int = int(ray["bounces"])
	var b_idx: int = int(ray["bounce_idx"])
	var ignore_id: int = int(ray["ignore_id"])

	var cur: Vector2 = origin
	var dist: float = 0.0
	var end_pt: Vector2 = origin
	var passed_glass: Dictionary = {}

	while dist < max_range:
		var step: float = minf(RAY_STEP, max_range - dist)
		var nxt: Vector2 = cur + dir * step
		dist += step

		# 1. Wall tile block
		if region != null and region.has_method("tile_at"):
			var tt: String = str(region.call("tile_at", nxt))
			if LxMapFormat.blocks_sight_tile(tt):
				end_pt = cur
				break

		# 2. Live enemy block
		var blocked_enemy: bool = false
		for e_v: Variant in enemies:
			if is_instance_valid(e_v) and e_v is LxEnemyBrain:
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive() and Geometry2D.get_closest_point_to_segment(e.pos, cur, nxt).distance_to(e.pos) <= e.body_radius + 1.5:
					end_pt = cur
					blocked_enemy = true
					break
		if blocked_enemy:
			break

		# 3. Interactables (mirrors, color glass, sensors, plants, solid blocks)
		var stopped: bool = false
		for it_v: Variant in inters:
			if not is_instance_valid(it_v) or it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active:
				continue
			var iid: int = it.get_instance_id()
			if iid == ignore_id:
				continue
			if not _seg_hits_interactable(cur, nxt, it):
				continue

			# Color glass tints beam and spawns a new tinted continuation ray
			if it.has_method("get_tint_color") and not passed_glass.has(iid):
				passed_glass[iid] = true
				var new_col: String = LxToyDraw.normalize_light_color(str(it.call("get_tint_color")))
				if it.has_method("on_beam_pass"):
					it.call("on_beam_pass", col_name)
				if new_col != col_name:
					end_pt = it.pos
					if segments.size() + queue.size() < MAX_SEGMENTS:
						queue.append({
							"start": it.pos + dir * (maxf(it.radius, 8.0) + 1.0),
							"dir": dir,
							"color": new_col,
							"bounces": bounces_left,
							"bounce_idx": b_idx,
							"ignore_id": iid,
						})
					stopped = true
					break
				continue

			# Beam sensor receives beam and stops it (unless pass_through)
			if it.has_method("receive_beam"):
				_hit_sensors.append({"sensor": it, "color": col_name})
				if not bool(it.props.get("pass_through", false)):
					end_pt = it.pos
					stopped = true
					break
				continue

			# Light plant & light sensor receive light along beam
			if it.kind == "light_plant" or it.kind == "light_sensor":
				_hit_plants.append({"item": it, "color": col_name})
				if it.is_solid():
					end_pt = cur
					stopped = true
					break
				continue

			# Reflective mirror / blue_transformer / prism splitter
			if it.is_reflective():
				end_pt = it.pos
				if bounces_left > 0:
					var rdir: Vector2 = it.reflect_dir(dir)
					if rdir.length_squared() > 0.001:
						var next_col: String = col_name
						if it.has_method("get_transform_color"):
							var tc: String = str(it.call("get_transform_color")).strip_edges()
							if not tc.is_empty():
								next_col = LxToyDraw.normalize_light_color(tc)
						var exit_p: Vector2 = it.pos + rdir * (maxf(it.radius, 8.0) + 2.0)
						queue.append({
							"start": exit_p,
							"dir": rdir,
							"color": next_col,
							"bounces": bounces_left - 1,
							"bounce_idx": b_idx + 1,
							"ignore_id": iid,
						})
						var should_split: bool = bool(it.props.get("prism_split", false)) \
							or (it.has_method("is_prism_splitter") and bool(it.call("is_prism_splitter"))) \
							or (b_idx == 0 and it.kind == "blue_transformer" and bool(it.props.get("allow_prism_split", false)))
						if should_split:
							var srad: float = deg_to_rad(SPLIT_DEG)
							for sgn: float in [-1.0, 1.0]:
								var sdir: Vector2 = rdir.rotated(sgn * srad).normalized()
								queue.append({
									"start": it.pos + sdir * (maxf(it.radius, 8.0) + 2.0),
									"dir": sdir,
									"color": next_col,
									"bounces": maxi(0, bounces_left - 2),
									"bounce_idx": b_idx + 1,
									"ignore_id": iid,
								})
				stopped = true
				break

			# Solid blocker (toggle_block, door, push_block, mimic_statue, etc.)
			if it.is_solid() and it.blocks_sight():
				end_pt = cur
				stopped = true
				break
		if stopped:
			break
		cur = nxt
		end_pt = nxt

	segments.append({"start": origin, "end": end_pt, "dir": dir, "color": col_name, "bounce": b_idx})


static func _seg_hits_interactable(a: Vector2, b: Vector2, it: LxInteractable) -> bool:
	if it.is_solid():
		var sr: Rect2 = it.get_solid_rect()
		if sr.has_area():
			return sr.grow(1.0).has_point(b) or sr.grow(1.0).has_point(a.lerp(b, 0.5))
	return Geometry2D.get_closest_point_to_segment(it.pos, a, b).distance_to(it.pos) <= maxf(6.0, it.radius)


func _deliver_beam_effects(_dt: float) -> void:
	for entry: Dictionary in _hit_sensors:
		var s: Object = entry["sensor"] as Object
		if s != null and is_instance_valid(s) and s.has_method("receive_beam"):
			s.call("receive_beam", str(entry["color"]), id)
	for p_entry: Dictionary in _hit_plants:
		var it: Object = p_entry["item"] as Object
		if it != null and is_instance_valid(it) and it.has_method("on_light"):
			it.call("on_light", 64.0, "beam")
	if harms_wick and beam_damage > 0.0 and _harm_cd <= 0.0 and is_instance_valid(Lx.player) and Lx.player is LxWick:
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_invulnerable():
			for seg: Dictionary in segments:
				var a: Vector2 = seg["start"] as Vector2
				var b: Vector2 = seg["end"] as Vector2
				if Geometry2D.get_closest_point_to_segment(w.global_position, a, b).distance_to(w.global_position) <= 6.5:
					var d: Vector2 = seg["dir"] as Vector2
					var perp := Vector2(-d.y, d.x)
					w.take_damage(beam_damage, a, perp, "beam_emitter")
					_harm_cd = 0.65
					break


func beam_illuminates_point(world_p: Vector2) -> bool:
	if not active or not beam_on:
		return false
	for seg: Dictionary in segments:
		var a: Vector2 = seg["start"] as Vector2
		var b: Vector2 = seg["end"] as Vector2
		if Geometry2D.get_closest_point_to_segment(world_p, a, b).distance_to(world_p) <= 16.0:
			return true
	return false


func get_light_pool() -> Vector4:
	if not active or not beam_on:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 40.0, 0.72)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var trip: Array[Color] = LxToyDraw.color_triplet(beam_color)
	var red: bool = LxHudFx.flash_reduced()
	var lit: bool = beam_on or telegraphing
	var pulse_hi: bool = red or int(floorf(_clock * 5.0)) % 2 == 0
	var d: Vector2 = emit_dir.normalized() if emit_dir.length_squared() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-d.y, d.x)

	# Grounded contact shadow under optical plinth
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.8)

	# Carved 3/4 stone plinth base (recessed south face + bevelled side ledges)
	draw_rect(Rect2(-8.0, -5.0, 16.0, 13.0), c_void)
	draw_rect(Rect2(-7.0, 3.0, 14.0, 4.0), c_night)
	draw_rect(Rect2(-6.0, 4.0, 12.0, 2.0), c_dusk)
	draw_rect(Rect2(-7.0, -4.0, 14.0, 8.0), c_dusk)
	draw_rect(Rect2(-6.0, -4.0, 12.0, 1.0), c_stone)
	draw_rect(Rect2(-7.0, -4.0, 1.0, 7.0), c_mauve)
	draw_rect(Rect2(6.0, -3.0, 1.0, 6.0), c_night)

	# Upper carved brass optical housing + corner rivets
	draw_rect(Rect2(-6.0, -8.0, 12.0, 10.0), c_void)
	draw_rect(Rect2(-5.0, -7.0, 10.0, 8.0), c_wine)
	draw_rect(Rect2(-5.0, -7.0, 9.0, 7.0), c_apricot)
	draw_rect(Rect2(-5.0, -7.0, 10.0, 1.0), c_gold)
	draw_rect(Rect2(-5.0, -7.0, 1.0, 7.0), c_gold)
	draw_rect(Rect2(-5.0, -7.0, 2.0, 1.0), c_cream)
	# Subtle active rim highlight on brass crown
	if lit:
		var rim_c: Color = trip[2] if pulse_hi else trip[1]
		draw_rect(Rect2(-4.0, -8.0, 8.0, 1.0), rim_c)
		draw_rect(Rect2(-6.0, -5.0, 1.0, 4.0), trip[1])
		draw_rect(Rect2(5.0, -5.0, 1.0, 4.0), trip[1])
	# Corner brass rivets on stone plinth
	for rv: Vector2 in [Vector2(-6.0, -2.0), Vector2(5.0, -2.0), Vector2(-6.0, 2.0), Vector2(5.0, 2.0)]:
		draw_rect(Rect2(rv, Vector2.ONE), c_gold if lit else c_stone)

	# Recessed crystal condenser dome inside optical housing
	draw_rect(Rect2(-3.0, -6.0, 6.0, 6.0), c_void)
	draw_rect(Rect2(-2.0, -5.0, 4.0, 4.0), trip[1] if lit else trip[0])
	draw_rect(Rect2(-2.0, -5.0, 3.0, 2.0), trip[2] if lit else trip[1])
	draw_rect(Rect2(-1.0, -4.0, 2.0, 2.0), c_cream if beam_on else (trip[2] if telegraphing else trip[1]))
	draw_rect(Rect2(-2.0, -5.0, 1.0, 1.0), c_cream)

	# Directional brass nozzle barrel + flared flanges + glowing firing lens
	var neck: Vector2 = (Vector2(0.0, -2.0) + d * 4.0).round()
	var muz: Vector2 = (Vector2(0.0, -2.0) + d * 7.0).round()
	var fl_a: Vector2 = (neck + perp * 3.0).round()
	var fl_b: Vector2 = (neck - perp * 3.0).round()
	draw_rect(Rect2(fl_a - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
	draw_rect(Rect2(fl_b - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
	draw_rect(Rect2(fl_a, Vector2.ONE), c_gold)
	draw_rect(Rect2(fl_b, Vector2.ONE), c_apricot)
	draw_rect(Rect2(neck - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), c_void)
	draw_rect(Rect2(neck - Vector2.ONE, Vector2(3.0, 3.0)), c_apricot)
	draw_rect(Rect2(neck - Vector2.ONE, Vector2(2.0, 1.0)), c_gold)
	# Glowing focusing crystal lens on the firing face
	draw_rect(Rect2(muz - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
	draw_rect(Rect2(muz - Vector2.ONE, Vector2(2.0, 2.0)), trip[2] if lit else trip[0])
	draw_rect(Rect2(muz - Vector2.ONE, Vector2.ONE), c_cream if lit else trip[2])
	if beam_on:
		draw_circle(muz, 4.0, Color(trip[1], 0.24 if red else (0.30 if pulse_hi else 0.20)))

	# Telegraph dotted warning line (for hazard beams)
	if telegraphing and not beam_on:
		var t_col: Color = PAL["coral"] as Color if (red or int(floorf(_clock * 12.0)) % 2 == 0) else c_cream
		for seg: Dictionary in segments:
			var a: Vector2 = (seg["start"] as Vector2) - pos
			var b: Vector2 = (seg["end"] as Vector2) - pos
			var slen: float = a.distance_to(b)
			var d_p: float = 0.0
			while d_p < slen:
				var pt: Vector2 = a.lerp(b, d_p / maxf(slen, 1.0)).round()
				draw_rect(Rect2(pt, Vector2.ONE), t_col)
				d_p += 5.0
		return

	if not beam_on:
		return
	var outer_w: float = 3.0 if not red else 2.0
	for seg: Dictionary in segments:
		var a: Vector2 = (seg["start"] as Vector2) - pos
		var b: Vector2 = (seg["end"] as Vector2) - pos
		var st: Array[Color] = LxToyDraw.color_triplet(str(seg["color"]))
		draw_line(a.round(), b.round(), Color(st[0], 0.55 if red else 0.72), outer_w + 1.0, false)
		draw_line(a.round(), b.round(), st[1], outer_w - 1.0, false)
		draw_line(a.round(), b.round(), c_cream, 1.0, false)
		var bp: Vector2 = b.round()
		draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), st[2])
		draw_rect(Rect2(bp, Vector2.ONE), c_cream)
