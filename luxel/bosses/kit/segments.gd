class_name LxBossSegments
extends RefCounted
## Articulated multi-segment boss bodies: chains, centipedes, trains, and tentacles.
## Supports per-segment HP, armour, sequential light state, and clean Last Light rendering.

const PAL: Dictionary = LxPalette.PAL

enum Mode { FOLLOW_CHAIN, TENTACLE, RAIL_TRAIN }

var boss: LxEnemyBrain = null
var mode: int = Mode.FOLLOW_CHAIN
var segments: Array[Dictionary] = []
var spacing: float = 13.0
var _trail: Array[Vector2] = []
var _rail: Array[Vector2] = []
var _rail_dist: float = 0.0
var _rail_speed: float = 48.0
var _rail_loop: bool = true
var _clock: float = 0.0
var _whip_amp: float = 0.42
var _whip_freq: float = 3.2
var damage_to_boss_ratio: float = 0.65


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func clear() -> void:
	segments.clear()
	_trail.clear()
	_rail.clear()
	_rail_dist = 0.0


func setup_follow_chain(count: int, p_spacing: float = 13.0, seg_radius: float = 6.0, seg_hp: float = 4.0, start_pos: Vector2 = Vector2.ZERO, facing: float = 0.0) -> void:
	clear()
	mode = Mode.FOLLOW_CHAIN
	spacing = maxf(6.0, p_spacing)
	var back_dir: Vector2 = -Vector2.from_angle(facing)
	for i: int in range(maxi(1, count)):
		var p: Vector2 = start_pos + back_dir * (float(i) * spacing)
		segments.append(_make_seg(i, p, facing, seg_radius, seg_hp))
	_seed_trail(start_pos, back_dir, count)


func setup_tentacle(count: int, p_spacing: float = 10.0, seg_radius: float = 5.0, seg_hp: float = 3.0, anchor: Vector2 = Vector2.ZERO, base_angle: float = 0.0) -> void:
	clear()
	mode = Mode.TENTACLE
	spacing = maxf(5.0, p_spacing)
	var d: Vector2 = Vector2.from_angle(base_angle)
	for i: int in range(maxi(1, count)):
		var p: Vector2 = anchor + d * (float(i) * spacing)
		var r: float = maxf(3.0, seg_radius * lerpf(1.0, 0.62, float(i) / float(maxi(1, count - 1))))
		segments.append(_make_seg(i, p, base_angle, r, seg_hp))


func setup_rail_train(count: int, rail_pts: Array[Vector2], p_spacing: float = 18.0, speed: float = 52.0, seg_radius: float = 7.0, seg_hp: float = 5.0, loop: bool = true) -> void:
	clear()
	mode = Mode.RAIL_TRAIN
	spacing = maxf(8.0, p_spacing)
	_rail = rail_pts.duplicate()
	_rail_speed = speed
	_rail_loop = loop
	_rail_dist = float(count) * spacing
	for i: int in range(maxi(1, count)):
		var sample: Dictionary = _sample_rail(_rail_dist - float(i) * spacing)
		segments.append(_make_seg(i, sample["pos"] as Vector2, float(sample["ang"]), seg_radius, seg_hp))


func _make_seg(idx: int, p: Vector2, ang: float, rad: float, seg_hp: float) -> Dictionary:
	return {
		"index": idx, "pos": p, "prev_pos": p, "facing": ang,
		"radius": rad, "hp": seg_hp, "max_hp": seg_hp,
		"alive": true, "armoured": false, "lit": false, "lit_t": 0.0,
		"flash_t": 0.0, "color": "teal" if idx > 0 else "jade", "glow": "gold",
	}


func _seed_trail(head: Vector2, back_dir: Vector2, count: int) -> void:
	_trail.clear()
	var total_len: float = float(count + 2) * spacing
	var steps: int = maxi(8, int(total_len / 2.5))
	for i: int in range(steps + 1):
		_trail.append(head + back_dir * (float(i) * (total_len / float(steps))))


func tick(dt: float, head_pos: Vector2, head_facing: float) -> void:
	_clock += dt
	if segments.is_empty():
		return
	for s: Dictionary in segments:
		s["prev_pos"] = s["pos"]
		s["flash_t"] = maxf(0.0, float(s["flash_t"]) - dt)
		if float(s["lit_t"]) > 0.0:
			s["lit_t"] = maxf(0.0, float(s["lit_t"]) - dt)
			if float(s["lit_t"]) <= 0.0:
				s["lit"] = false

	match mode:
		Mode.FOLLOW_CHAIN:
			_tick_follow(head_pos, head_facing)
		Mode.TENTACLE:
			_tick_tentacle(head_pos, head_facing)
		Mode.RAIL_TRAIN:
			_tick_rail(dt)


func _tick_follow(head_pos: Vector2, head_facing: float) -> void:
	if _trail.is_empty() or _trail[0].distance_to(head_pos) >= 1.5:
		_trail.insert(0, head_pos)
		var max_pts: int = maxi(32, segments.size() * int(spacing) + 16)
		while _trail.size() > max_pts:
			_trail.pop_back()
	segments[0]["pos"] = head_pos
	segments[0]["facing"] = head_facing
	var acc: float = 0.0
	var ti: int = 0
	for si: int in range(1, segments.size()):
		var want: float = float(si) * spacing
		while ti + 1 < _trail.size() and acc + _trail[ti].distance_to(_trail[ti + 1]) < want:
			acc += _trail[ti].distance_to(_trail[ti + 1])
			ti += 1
		var pt: Vector2 = _trail[mini(ti, _trail.size() - 1)]
		if ti + 1 < _trail.size():
			var seg_len: float = _trail[ti].distance_to(_trail[ti + 1])
			if seg_len > 0.001:
				var frac: float = clampf((want - acc) / seg_len, 0.0, 1.0)
				pt = _trail[ti].lerp(_trail[ti + 1], frac)
		var prev_p: Vector2 = segments[si - 1]["pos"] as Vector2
		segments[si]["pos"] = pt
		if prev_p.distance_to(pt) > 0.1:
			segments[si]["facing"] = (prev_p - pt).angle()


func _tick_tentacle(anchor: Vector2, base_angle: float) -> void:
	segments[0]["pos"] = anchor
	segments[0]["facing"] = base_angle
	var cur: Vector2 = anchor
	var ang: float = base_angle
	for i: int in range(1, segments.size()):
		var wave: float = sin(_clock * _whip_freq - float(i) * 0.72) * _whip_amp
		ang = base_angle + wave * (float(i) / float(maxi(1, segments.size() - 1)))
		cur += Vector2.from_angle(ang) * spacing
		segments[i]["pos"] = cur
		segments[i]["facing"] = ang


func _tick_rail(dt: float) -> void:
	if _rail.size() < 2:
		return
	_rail_dist += _rail_speed * dt
	for i: int in range(segments.size()):
		var sample: Dictionary = _sample_rail(_rail_dist - float(i) * spacing)
		segments[i]["pos"] = sample["pos"]
		segments[i]["facing"] = sample["ang"]


func _sample_rail(dist: float) -> Dictionary:
	var n: int = _rail.size()
	if n < 2:
		return {"pos": Vector2.ZERO, "ang": 0.0}
	var seg_count: int = n if _rail_loop else n - 1
	var total: float = 0.0
	var lens: Array[float] = []
	for i: int in range(seg_count):
		var l: float = _rail[i].distance_to(_rail[(i + 1) % n])
		lens.append(l)
		total += l
	if total <= 0.01:
		return {"pos": _rail[0], "ang": 0.0}
	var d: float = fposmod(dist, total) if _rail_loop else clampf(dist, 0.0, total)
	for i: int in range(seg_count):
		if d <= lens[i] or i == seg_count - 1:
			var a: Vector2 = _rail[i]
			var b: Vector2 = _rail[(i + 1) % n]
			var u: float = clampf(d / maxf(lens[i], 0.01), 0.0, 1.0)
			return {"pos": a.lerp(b, u), "ang": (b - a).angle()}
		d -= lens[i]
	return {"pos": _rail[0], "ang": 0.0}


# --- Per-Segment Interaction & Light State -----------------------------------

func apply_light(origin: Vector2, rad: float, lit_duration: float = 6.0, in_order: bool = false) -> int:
	var newly_lit: int = 0
	for i: int in range(segments.size()):
		var s: Dictionary = segments[i]
		if not bool(s["alive"]):
			continue
		if in_order and i > 0 and bool(segments[i - 1]["alive"]) and not bool(segments[i - 1]["lit"]):
			break
		if (s["pos"] as Vector2).distance_to(origin) <= rad + float(s["radius"]):
			if not bool(s["lit"]):
				newly_lit += 1
			s["lit"] = true
			s["lit_t"] = maxf(float(s["lit_t"]), lit_duration)
	return newly_lit


func light_next_segment(lit_duration: float = 8.0) -> bool:
	for s: Dictionary in segments:
		if bool(s["alive"]) and not bool(s["lit"]):
			s["lit"] = true
			s["lit_t"] = lit_duration
			s["flash_t"] = 0.16
			return true
	return false


func all_lit() -> bool:
	var alive_n: int = 0
	for s: Dictionary in segments:
		if bool(s["alive"]):
			alive_n += 1
			if not bool(s["lit"]):
				return false
	return alive_n > 0


func lit_count() -> int:
	var n: int = 0
	for s: Dictionary in segments:
		if bool(s["alive"]) and bool(s["lit"]):
			n += 1
	return n


func alive_count() -> int:
	var n: int = 0
	for s: Dictionary in segments:
		if bool(s["alive"]):
			n += 1
	return n


func extinguish_all() -> void:
	for s: Dictionary in segments:
		s["lit"] = false
		s["lit_t"] = 0.0


func find_segment_at(pt: Vector2, extra_r: float = 4.0) -> int:
	for i: int in range(segments.size()):
		var s: Dictionary = segments[i]
		if bool(s["alive"]) and (s["pos"] as Vector2).distance_to(pt) <= float(s["radius"]) + extra_r:
			return i
	return -1


func damage_segment(idx: int, hit: LxHit) -> int:
	if idx < 0 or idx >= segments.size() or hit == null:
		return LxEnemyBrain.HitResult.GLANCED
	var s: Dictionary = segments[idx]
	if not bool(s["alive"]):
		return LxEnemyBrain.HitResult.GLANCED
	if bool(s["armoured"]) and not hit.pierce and not hit.cracks_armour:
		s["flash_t"] = 0.08
		return LxEnemyBrain.HitResult.BLOCKED
	s["hp"] = maxf(0.0, float(s["hp"]) - hit.damage)
	s["flash_t"] = 0.14
	if float(s["hp"]) <= 0.001 and idx > 0:
		s["alive"] = false
		s["lit"] = false
		return LxEnemyBrain.HitResult.KILLED
	return LxEnemyBrain.HitResult.CHIPPED


func get_segment_positions(only_alive: bool = true) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in segments:
		if not only_alive or bool(s["alive"]):
			out.append(s["pos"] as Vector2)
	return out


func draw_segments(ci: CanvasItem, origin_world: Vector2) -> void:
	if segments.is_empty():
		return
	var off: Vector2 = -origin_world
	# Draw tail-to-head so head overlaps cleanly
	for i: int in range(segments.size() - 1, -1, -1):
		var s: Dictionary = segments[i]
		if not bool(s["alive"]):
			continue
		var p: Vector2 = ((s["pos"] as Vector2) + off).round()
		var r: float = float(s["radius"])
		if i > 0 and bool(segments[i - 1]["alive"]):
			var prev_p: Vector2 = ((segments[i - 1]["pos"] as Vector2) + off).round()
			ci.draw_line(p, prev_p, PAL["night"] as Color, r * 0.9)
			ci.draw_line(p, prev_p, PAL["pine"] as Color, maxf(1.5, r * 0.45))
		var lit: bool = bool(s["lit"])
		var fill: Color = PAL["cream"] as Color if float(s["flash_t"]) > 0.0 else (
			PAL["gold"] as Color if lit else LxPalette.color(str(s["color"]), "teal")
		)
		ci.draw_circle(p + Vector2(0.0, r * 0.35), r * 0.9, Color(PAL["void"] as Color, 0.35))
		ci.draw_circle(p, r + 1.2, PAL["night"] as Color)
		ci.draw_circle(p, r, fill)
		ci.draw_circle((p + Vector2(-r * 0.25, -r * 0.25)).round(), maxf(1.5, r * 0.42), PAL["cream"] as Color if lit else PAL["lime"] as Color)
		if bool(s["armoured"]):
			ci.draw_arc(p, r + 1.4, 0.0, TAU, 12, PAL["stone"] as Color, 1.4)
		if i == 0:
			var fwd: Vector2 = Vector2.from_angle(float(s["facing"]))
			var side := Vector2(-fwd.y, fwd.x)
			for sgn: float in [-1.0, 1.0]:
				var ep: Vector2 = (p + fwd * (r * 0.45) + side * (sgn * r * 0.4)).round()
				ci.draw_rect(Rect2(ep - Vector2(0.5, 0.5), Vector2(2.0, 2.0)), PAL["coral"] as Color)
				ci.draw_rect(Rect2(ep, Vector2.ONE), PAL["gold"] as Color)
