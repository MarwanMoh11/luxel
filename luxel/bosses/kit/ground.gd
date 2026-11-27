class_name LxBossGround
extends RefCounted
## Boss ground telegraphs (via LxBossTelegraphFx), lingering hazards, and safe-zone inversions.
## Every damaging decal enforces the >= 0.45 s tell floor (scaled by assist_tell_scale).

const PAL: Dictionary = LxPalette.PAL
const MIN_TELL_S: float = 0.45
const MAX_DECALS: int = 48
const MAX_HAZARDS: int = 32
const MAX_INVERSIONS: int = 8

var boss: LxEnemyBrain = null
var _decals: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _inversions: Array[Dictionary] = []
var _clock: float = 0.0


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func clear() -> void:
	_decals.clear()
	_hazards.clear()
	_inversions.clear()


func active_count() -> int:
	return _decals.size() + _hazards.size() + _inversions.size()


func is_point_in_danger(p: Vector2) -> bool:
	for d: Dictionary in _decals:
		if _point_in_decal(p, d):
			return true
	for h: Dictionary in _hazards:
		if _point_in_hazard(p, h):
			return true
	for inv: Dictionary in _inversions:
		if not _point_in_safe_circles(p, inv["safes"] as Array, float(inv["safe_r"])):
			return true
	return false


func nearest_safe_spot(from_p: Vector2, arena: Rect2) -> Vector2:
	# Helper for bots & AI: if safe-zone inversion is active, steer straight into nearest safe circle.
	for inv: Dictionary in _inversions:
		var safes: Array = inv["safes"] as Array
		var best: Vector2 = from_p
		var best_d: float = INF
		for sv: Variant in safes:
			var sp: Vector2 = sv as Vector2
			var d: float = from_p.distance_to(sp)
			if d < best_d:
				best_d = d
				best = sp
		if best_d < INF:
			return best
	var center: Vector2 = arena.get_center() if arena.has_area() else from_p
	if not is_point_in_danger(from_p):
		return from_p
	for r: float in [24.0, 44.0, 68.0]:
		for k: int in range(8):
			var cand: Vector2 = from_p + Vector2.from_angle(float(k) * (TAU / 8.0)) * r
			if arena.has_area():
				cand = Vector2(clampf(cand.x, arena.position.x + 10.0, arena.end.x - 10.0), clampf(cand.y, arena.position.y + 10.0, arena.end.y - 10.0))
			if not is_point_in_danger(cand):
				return cand
	return center


# --- Telegraphed Ground Decals -----------------------------------------------

func _push_decal(d: Dictionary) -> Dictionary:
	if _decals.size() >= MAX_DECALS:
		_decals.remove_at(0)
	_decals.append(d)
	return d


func warn_ring(center: Vector2, radius: float, dur: float, dmg: float = 1.0, fill_key: String = "coral", rim_key: String = "gold", linger_s: float = 0.0, on_detonate: Callable = Callable()) -> Dictionary:
	return _push_decal({
		"kind": "ring", "pos": center, "radius": maxf(8.0, radius),
		"dur": _floor_tell(dur, dmg), "elapsed": 0.0, "damage": dmg,
		"fill": fill_key, "rim": rim_key, "linger": maxf(0.0, linger_s),
		"on_detonate": on_detonate, "detonated": false,
	})


func warn_lane(from_p: Vector2, to_p: Vector2, half_w: float, dur: float, dmg: float = 1.0, fill_key: String = "coral", rim_key: String = "gold", linger_s: float = 0.0, on_detonate: Callable = Callable()) -> Dictionary:
	return _push_decal({
		"kind": "lane", "pos": from_p, "to": to_p, "half_w": maxf(4.0, half_w),
		"dur": _floor_tell(dur, dmg), "elapsed": 0.0, "damage": dmg,
		"fill": fill_key, "rim": rim_key, "linger": maxf(0.0, linger_s),
		"on_detonate": on_detonate, "detonated": false,
	})


func warn_sector(origin: Vector2, ang0: float, ang1: float, radius: float, dur: float, dmg: float = 1.0, fill_key: String = "coral", rim_key: String = "gold", on_detonate: Callable = Callable()) -> Dictionary:
	return _push_decal({
		"kind": "sector", "pos": origin, "ang0": ang0, "ang1": ang1,
		"radius": maxf(12.0, radius), "dur": _floor_tell(dur, dmg), "elapsed": 0.0,
		"damage": dmg, "fill": fill_key, "rim": rim_key, "linger": 0.0,
		"on_detonate": on_detonate, "detonated": false,
	})


func warn_rect(rect: Rect2, dur: float, dmg: float = 1.0, fill_key: String = "coral", rim_key: String = "gold", linger_s: float = 0.0, on_detonate: Callable = Callable()) -> Dictionary:
	return _push_decal({
		"kind": "rect", "rect": rect, "pos": rect.get_center(),
		"dur": _floor_tell(dur, dmg), "elapsed": 0.0, "damage": dmg,
		"fill": fill_key, "rim": rim_key, "linger": maxf(0.0, linger_s),
		"on_detonate": on_detonate, "detonated": false,
	})


func warn_summon(center: Vector2, radius: float, dur: float, col_key: String = "gold", on_detonate: Callable = Callable()) -> Dictionary:
	return _push_decal({
		"kind": "summon", "pos": center, "radius": maxf(10.0, radius),
		"dur": maxf(0.45, dur), "elapsed": 0.0, "damage": 0.0,
		"fill": col_key, "rim": "cream", "linger": 0.0,
		"on_detonate": on_detonate, "detonated": false,
	})


# --- Lingering Hazards -------------------------------------------------------

func add_hazard_circle(center: Vector2, radius: float, duration: float, dmg: float = 1.0, fill_key: String = "coral", airborne_safe: bool = true) -> void:
	if _hazards.size() >= MAX_HAZARDS:
		_hazards.remove_at(0)
	_hazards.append({
		"kind": "circle", "pos": center, "radius": maxf(6.0, radius),
		"ttl": maxf(0.25, duration), "max_ttl": maxf(0.25, duration),
		"damage": maxf(0.5, dmg), "fill": fill_key, "airborne_safe": airborne_safe,
		"tick_cd": 0.0,
	})


func add_hazard_rect(rect: Rect2, duration: float, dmg: float = 1.0, fill_key: String = "coral", airborne_safe: bool = true) -> void:
	if _hazards.size() >= MAX_HAZARDS:
		_hazards.remove_at(0)
	_hazards.append({
		"kind": "rect", "rect": rect, "pos": rect.get_center(),
		"ttl": maxf(0.25, duration), "max_ttl": maxf(0.25, duration),
		"damage": maxf(0.5, dmg), "fill": fill_key, "airborne_safe": airborne_safe,
		"tick_cd": 0.0,
	})


# --- Safe-Zone Inversions ----------------------------------------------------

func warn_safe_inversion(arena: Rect2, safe_centers: Array[Vector2], safe_radius: float, warn_s: float = 0.72, active_s: float = 0.28, dmg: float = 1.0, safe_key: String = "lime", danger_key: String = "coral") -> void:
	var safes_copy: Array[Vector2] = []
	for p: Vector2 in safe_centers:
		safes_copy.append(p)
	if _inversions.size() >= MAX_INVERSIONS:
		_inversions.remove_at(0)
	_inversions.append({
		"arena": arena, "safes": safes_copy, "safe_r": maxf(16.0, safe_radius),
		"warn_dur": maxf(0.55, warn_s) * _assist_scale(),
		"active_dur": maxf(0.16, active_s), "elapsed": 0.0,
		"damage": maxf(0.5, dmg), "safe_key": safe_key, "danger_key": danger_key,
		"hit": false, "burst": false,
	})


# --- Tick & Draw -------------------------------------------------------------

func tick(dt: float) -> void:
	_clock += dt
	var has_p: bool = _has_wick()
	var wp: Vector2 = _wick_pos()

	for i: int in range(_decals.size() - 1, -1, -1):
		var d: Dictionary = _decals[i]
		d["elapsed"] = float(d["elapsed"]) + dt
		if float(d["elapsed"]) >= float(d["dur"]):
			_detonate_decal(d, has_p, wp)
			_decals.remove_at(i)

	var gliding: bool = is_instance_valid(Lx.player) and Lx.player is LxWick and (Lx.player as LxWick).is_gliding()
	for i: int in range(_hazards.size() - 1, -1, -1):
		var h: Dictionary = _hazards[i]
		h["ttl"] = float(h["ttl"]) - dt
		h["tick_cd"] = maxf(0.0, float(h["tick_cd"]) - dt)
		if has_p and float(h["tick_cd"]) <= 0.0 and not (bool(h["airborne_safe"]) and gliding):
			if _point_in_hazard(wp, h):
				h["tick_cd"] = 0.65
				var hp_pos: Vector2 = h["pos"] as Vector2
				var push: Vector2 = (wp - hp_pos).normalized() if wp.distance_to(hp_pos) > 0.1 else Vector2.DOWN
				_damage_wick(push, float(h["damage"]), "ground_hazard", hp_pos, true)
		if float(h["ttl"]) <= 0.0:
			_hazards.remove_at(i)

	for i: int in range(_inversions.size() - 1, -1, -1):
		var inv: Dictionary = _inversions[i]
		inv["elapsed"] = float(inv["elapsed"]) + dt
		var el: float = float(inv["elapsed"])
		var wd: float = float(inv["warn_dur"])
		var ad: float = float(inv["active_dur"])
		if el >= wd:
			if not bool(inv["burst"]):
				inv["burst"] = true
				var ar: Rect2 = inv["arena"] as Rect2
				LxDamageFx.boss_impact(ar.get_center(), 0.22, 110.0, 96.0, 108.0, 1.42, 0.36)
			if not bool(inv["hit"]) and has_p:
				var ar2: Rect2 = inv["arena"] as Rect2
				if ar2.has_point(wp) and not _point_in_safe_circles(wp, inv["safes"] as Array, float(inv["safe_r"])):
					inv["hit"] = true
					var c: Vector2 = ar2.get_center()
					var push: Vector2 = (wp - c).normalized() if wp.distance_to(c) > 0.1 else Vector2.DOWN
					_damage_wick(push, float(inv["damage"]), "safe_inversion", c, true)
		if el >= wd + ad:
			_inversions.remove_at(i)


func _detonate_decal(d: Dictionary, has_p: bool, wp: Vector2) -> void:
	var dmg: float = float(d["damage"])
	var kind: String = str(d["kind"])
	var p: Vector2 = d["pos"] as Vector2
	if dmg > 0.0:
		LxDamageFx.boss_impact(p, 0.14, 56.0, 62.0, 62.0, 1.30, 0.24)
		if has_p and _point_in_decal(wp, d):
			var push: Vector2 = (wp - p).normalized() if wp.distance_to(p) > 0.1 else Vector2.DOWN
			_damage_wick(push, dmg, "ground_" + kind, p, true)
		var linger: float = float(d["linger"])
		if linger > 0.0:
			if kind == "ring":
				add_hazard_circle(p, float(d["radius"]) * 0.85, linger, dmg, str(d["fill"]))
			elif kind == "rect":
				add_hazard_rect(d["rect"] as Rect2, linger, dmg, str(d["fill"]))
	var cb: Callable = d["on_detonate"] as Callable
	if cb.is_valid():
		cb.call(d)


func draw_ground(ci: CanvasItem, origin_world: Vector2) -> void:
	var off: Vector2 = -origin_world
	var fred: bool = LxHudFx.flash_reduced()

	# 1. Safe-zone inversions
	for inv: Dictionary in _inversions:
		var ar: Rect2 = inv["arena"] as Rect2
		var el: float = float(inv["elapsed"])
		var wd: float = float(inv["warn_dur"])
		var u: float = clampf(el / maxf(wd, 0.05), 0.0, 1.0)
		var d_col: Color = LxPalette.color(str(inv["danger_key"]), "coral")
		var s_col: Color = LxPalette.color(str(inv["safe_key"]), "lime")
		var active_now: bool = el >= wd
		var fill_a: float = (0.34 if fred else 0.48) if active_now else lerpf(0.08, 0.22, u)
		var r_local := Rect2((ar.position + off).round(), ar.size.round())
		ci.draw_rect(r_local, Color(d_col, fill_a), true)
		ci.draw_rect(r_local, PAL["cream"] as Color if active_now else d_col, false, 2.0)
		for sv: Variant in (inv["safes"] as Array):
			var sc: Vector2 = ((sv as Vector2) + off).round()
			var sr: float = roundf(float(inv["safe_r"]))
			ci.draw_circle(sc, sr, Color(PAL["night"] as Color, 0.72))
			ci.draw_circle(sc, sr - 1.5, Color(s_col, 0.22))
			ci.draw_arc(sc, sr + 1.0, 0.0, TAU, 24, PAL["void"] as Color, 3.0)
			ci.draw_arc(sc, sr, 0.0, TAU, 24, PAL["cream"] as Color if u > 0.72 else s_col, 2.0)
			# Greyscale-legible sanctuary cross & inward notches marking the safe zone
			ci.draw_rect(Rect2(sc + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), PAL["cream"] as Color)
			ci.draw_rect(Rect2(sc + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), PAL["cream"] as Color)
			for ni: int in range(4):
				var nd: Vector2 = Vector2.from_angle(float(ni) * (PI * 0.5))
				ci.draw_line((sc + nd * (sr - 4.0)).round(), (sc + nd * (sr + 1.0)).round(), PAL["cream"] as Color, 1.0)
			if not active_now:
				ci.draw_arc(sc, maxf(3.0, roundf(sr * lerpf(1.35, 1.0, u))), 0.0, TAU, 20, PAL["gold"] as Color, 1.0)

	# 2. Lingering hazards
	for h: Dictionary in _hazards:
		var frac: float = clampf(float(h["ttl"]) / maxf(float(h["max_ttl"]), 0.05), 0.0, 1.0)
		var col: Color = LxPalette.color(str(h["fill"]), "coral")
		var rim: Color = PAL["apricot"] as Color if (fred or int(_clock * 10.0) % 2 == 0) else (PAL["gold"] as Color)
		if str(h["kind"]) == "circle":
			var hc: Vector2 = ((h["pos"] as Vector2) + off).round()
			var hr: float = roundf(float(h["radius"]))
			ci.draw_circle(hc, hr, Color(col, 0.34 * frac))
			ci.draw_arc(hc, hr + 1.0, 0.0, TAU, 20, Color(PAL["void"] as Color, 0.72 * frac), 2.0)
			ci.draw_arc(hc, hr, 0.0, TAU, 20, Color(rim, 0.80 * frac), 1.0)
		else:
			var hr2: Rect2 = h["rect"] as Rect2
			var rl := Rect2((hr2.position + off).round(), hr2.size.round())
			ci.draw_rect(rl, Color(col, 0.34 * frac), true)
			ci.draw_rect(rl.grow(1.0), Color(PAL["void"] as Color, 0.72 * frac), false, 2.0)
			ci.draw_rect(rl, Color(rim, 0.80 * frac), false, 1.0)

	# 3. Telegraphed decals (via LxBossTelegraphFx)
	for d: Dictionary in _decals:
		var u: float = clampf(float(d["elapsed"]) / maxf(float(d["dur"]), 0.05), 0.0, 1.0)
		var kind: String = str(d["kind"])
		var fk: String = str(d["fill"])
		var rk: String = str(d["rim"])
		match kind:
			"ring":
				LxBossTelegraphFx.draw_ground_danger_ring(ci, (d["pos"] as Vector2) + off, float(d["radius"]), u, _clock, fk, rk)
			"lane":
				LxBossTelegraphFx.draw_ground_danger_lane(ci, (d["pos"] as Vector2) + off, (d["to"] as Vector2) + off, float(d["half_w"]), u, _clock, fk, rk)
			"sector":
				LxBossTelegraphFx.draw_ground_danger_sector(ci, (d["pos"] as Vector2) + off, float(d["ang0"]), float(d["ang1"]), float(d["radius"]), u, _clock, fk, rk)
			"summon":
				LxBossTelegraphFx.draw_ground_summon_ring(ci, (d["pos"] as Vector2) + off, float(d["radius"]), u, _clock, fk)
			"rect":
				var rr: Rect2 = d["rect"] as Rect2
				var rl := Rect2((rr.position + off).round(), rr.size.round())
				var c_fill: Color = LxPalette.color(fk, "coral")
				var c_rim: Color = LxPalette.color(rk, "gold")
				ci.draw_rect(rl, Color(c_fill, lerpf(0.14, 0.28, u)), true)
				ci.draw_rect(rl.grow(1.0), PAL["void"] as Color, false, 2.0)
				ci.draw_rect(rl, PAL["cream"] as Color if u > 0.78 else c_rim, false, 1.0)
				var inset_x: float = roundf(rl.size.x * 0.42 * u)
				var inset_y: float = roundf(rl.size.y * 0.42 * u)
				var inner_r := Rect2(rl.position + Vector2(inset_x, inset_y), Vector2(maxf(2.0, rl.size.x - inset_x * 2.0), maxf(2.0, rl.size.y - inset_y * 2.0)))
				ci.draw_rect(inner_r, PAL["cream"] as Color if u > 0.78 else c_rim, false, 1.0)


func _point_in_decal(p: Vector2, d: Dictionary) -> bool:
	match str(d["kind"]):
		"ring":
			return p.distance_to(d["pos"] as Vector2) <= float(d["radius"])
		"lane":
			return Geometry2D.get_closest_point_to_segment(p, d["pos"] as Vector2, d["to"] as Vector2).distance_to(p) <= float(d["half_w"])
		"sector":
			var o: Vector2 = d["pos"] as Vector2
			var rel: Vector2 = p - o
			if rel.length() > float(d["radius"]):
				return false
			var a0: float = float(d["ang0"])
			var a1: float = float(d["ang1"])
			var mid: float = (a0 + a1) * 0.5
			var half: float = absf(a1 - a0) * 0.5
			return rel.length() < 1.0 or absf(angle_difference(mid, rel.angle())) <= half
		"rect":
			return (d["rect"] as Rect2).has_point(p)
		_:
			return false


func _point_in_hazard(p: Vector2, h: Dictionary) -> bool:
	if str(h["kind"]) == "circle":
		return p.distance_to(h["pos"] as Vector2) <= float(h["radius"])
	return (h["rect"] as Rect2).has_point(p)


static func _point_in_safe_circles(p: Vector2, safes: Array, safe_r: float) -> bool:
	for sv: Variant in safes:
		if p.distance_to(sv as Vector2) <= safe_r:
			return true
	return false


func _floor_tell(dur: float, dmg: float) -> float:
	var fl: float = MIN_TELL_S if dmg > 0.0 else 0.25
	return maxf(fl, dur) * _assist_scale()


func _assist_scale() -> float:
	if boss != null and boss.has_method("get_tell_scale"):
		return float(boss.call("get_tell_scale"))
	if Lx.save != null and Lx.save.settings.has("assist_tell_scale"):
		return clampf(float(Lx.save.settings["assist_tell_scale"]), 1.0, 1.5)
	return 1.0


func _has_wick() -> bool:
	return boss != null and boss.has_method("_has_player") and bool(boss.call("_has_player"))


func _wick_pos() -> Vector2:
	if boss != null and boss.has_method("_get_wick_pos"):
		return boss.call("_get_wick_pos") as Vector2
	if is_instance_valid(Lx.player) and Lx.player is Node2D:
		return (Lx.player as Node2D).global_position
	return Vector2(-9999.0, -9999.0)


func _damage_wick(hit_dir: Vector2, dmg: float, src: String, from_pos: Vector2, telegraphed: bool) -> void:
	if boss != null and boss.has_method("emit_boss_damage"):
		boss.call("emit_boss_damage", hit_dir, dmg, src, from_pos, telegraphed)
	elif boss != null and boss.has_method("_emit_player_hit"):
		boss.call("_emit_player_hit", hit_dir, dmg)
