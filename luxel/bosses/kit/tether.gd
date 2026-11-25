class_name LxBossTether
extends RefCounted
## Cuttable chains, anchor tethers, pendulum constraints, and charged lightning cords.

const PAL: Dictionary = LxPalette.PAL

var boss: LxEnemyBrain = null
var tethers: Array[Dictionary] = []
var _clock: float = 0.0


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func clear() -> void:
	tethers.clear()


func add_tether(id: String, a: Variant, b: Variant, cfg: Dictionary = {}) -> Dictionary:
	var t: Dictionary = {
		"id": id,
		"a": a, # Vector2 or Callable returning Vector2
		"b": b,
		"max_length": maxf(16.0, float(cfg.get("max_length", 88.0))),
		"hp": maxf(0.5, float(cfg.get("hp", 2.0))),
		"max_hp": maxf(0.5, float(cfg.get("hp", 2.0))),
		"cuttable": bool(cfg.get("cuttable", true)),
		"cut": false,
		"pull_strength": float(cfg.get("pull_strength", 0.0)),
		"electric": bool(cfg.get("electric", false)),
		"electric_warn_t": float(cfg.get("electric_warn_t", 0.0)),
		"electric_damage": float(cfg.get("electric_damage", 1.0)),
		"color": str(cfg.get("color", "stone")),
		"flash_t": 0.0,
		"hit_cd": 0.0,
		"on_cut": cfg.get("on_cut", Callable()),
	}
	tethers.append(t)
	if tethers.size() > 24:
		for i: int in range(tethers.size() - 1, -1, -1):
			if bool(tethers[i]["cut"]):
				tethers.remove_at(i)
	return t


func active_count() -> int:
	var n: int = 0
	for t: Dictionary in tethers:
		if not bool(t["cut"]):
			n += 1
	return n


func get_tether(id: String) -> Dictionary:
	for t: Dictionary in tethers:
		if str(t["id"]) == id:
			return t
	return {}


func charge_electric(id: String, warn_s: float = 0.55) -> void:
	var t: Dictionary = get_tether(id)
	if not t.is_empty() and not bool(t["cut"]):
		t["electric"] = true
		t["electric_warn_t"] = maxf(0.45, warn_s)


func discharge_all() -> void:
	for t: Dictionary in tethers:
		t["electric"] = false
		t["electric_warn_t"] = 0.0


func constrain_point(id: String, pt: Vector2) -> Vector2:
	var t: Dictionary = get_tether(id)
	if t.is_empty() or bool(t["cut"]):
		return pt
	var pa: Vector2 = _eval_end(t["a"])
	var max_l: float = float(t["max_length"])
	var off: Vector2 = pt - pa
	if off.length() > max_l and off.length() > 0.01:
		return pa + off.normalized() * max_l
	return pt


func try_hit_segment(from_p: Vector2, to_p: Vector2, hit: LxHit) -> bool:
	if hit == null:
		return false
	for t: Dictionary in tethers:
		if bool(t["cut"]) or not bool(t["cuttable"]):
			continue
		var pa: Vector2 = _eval_end(t["a"])
		var pb: Vector2 = _eval_end(t["b"])
		var mid: Vector2 = pa.lerp(pb, 0.5)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(mid, from_p, to_p)
		if Geometry2D.get_closest_point_to_segment(closest, pa, pb).distance_to(closest) <= 7.0:
			t["hp"] = maxf(0.0, float(t["hp"]) - hit.damage)
			t["flash_t"] = 0.14
			if float(t["hp"]) <= 0.001:
				cut_tether(str(t["id"]))
			return true
	return false


func cut_tether(id: String) -> bool:
	var t: Dictionary = get_tether(id)
	if t.is_empty() or bool(t["cut"]):
		return false
	t["cut"] = true
	t["electric"] = false
	var pa: Vector2 = _eval_end(t["a"])
	var pb: Vector2 = _eval_end(t["b"])
	LxDamageFx.boss_impact(pa.lerp(pb, 0.5), 0.14, 52.0, 58.0, 56.0, 1.28, 0.24)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("warden_shield_break", pa.lerp(pb, 0.5), true)
	var cb: Callable = t["on_cut"] as Callable
	if cb.is_valid():
		cb.call(t)
	return true


func tick(dt: float) -> void:
	_clock += dt
	var has_p: bool = boss != null and boss.has_method("_has_player") and bool(boss.call("_has_player"))
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2 if has_p else Vector2(-9999.0, -9999.0)
	var wick_node: LxWick = Lx.player as LxWick if (is_instance_valid(Lx.player) and Lx.player is LxWick) else null

	for t: Dictionary in tethers:
		if bool(t["cut"]):
			continue
		t["flash_t"] = maxf(0.0, float(t["flash_t"]) - dt)
		t["hit_cd"] = maxf(0.0, float(t["hit_cd"]) - dt)
		var pa: Vector2 = _eval_end(t["a"])
		var pb: Vector2 = _eval_end(t["b"])

		# Check player bolts slicing cuttable tethers
		if bool(t["cuttable"]) and wick_node != null:
			for bv: Variant in wick_node.bolts:
				if is_instance_valid(bv) and bv is Object:
					var bp: Vector2 = bv.get("pos") as Vector2
					if Geometry2D.get_closest_point_to_segment(bp, pa, pb).distance_to(bp) <= 6.5:
						var hit := LxHit.make(LxHit.SOURCE_BOLT, float(bv.get("damage")), bv.get("dir") as Vector2, bp)
						try_hit_segment(bp - Vector2(2.0, 0.0), bp + Vector2(2.0, 0.0), hit)
						break

		if bool(t["electric"]):
			if float(t["electric_warn_t"]) > 0.0:
				t["electric_warn_t"] = maxf(0.0, float(t["electric_warn_t"]) - dt)
			elif has_p and float(t["hit_cd"]) <= 0.0:
				if Geometry2D.get_closest_point_to_segment(wp, pa, pb).distance_to(wp) <= 7.0:
					t["hit_cd"] = 0.75
					var perp: Vector2 = (pb - pa).normalized().orthogonal() if pa.distance_to(pb) > 0.1 else Vector2.UP
					if boss != null and boss.has_method("emit_boss_damage"):
						boss.call("emit_boss_damage", perp, float(t["electric_damage"]), "tether_zap", pa.lerp(pb, 0.5), true)


func draw_tethers(ci: CanvasItem, origin_world: Vector2) -> void:
	var off: Vector2 = -origin_world
	for t: Dictionary in tethers:
		if bool(t["cut"]):
			continue
		var pa: Vector2 = _eval_end(t["a"]) + off
		var pb: Vector2 = _eval_end(t["b"]) + off
		var dist: float = pa.distance_to(pb)
		var links: int = clampi(int(dist / 6.0), 3, 28)
		var is_elec: bool = bool(t["electric"])
		var warn_t: float = float(t["electric_warn_t"])
		if is_elec and warn_t > 0.0:
			LxBossTelegraphFx.draw_ground_danger_lane(ci, pa, pb, 7.0, 1.0 - clampf(warn_t / 0.55, 0.0, 1.0), _clock, "sky", "gold")
		var col: Color = PAL["cream"] as Color if float(t["flash_t"]) > 0.0 else (
			PAL["ice"] as Color if (is_elec and warn_t <= 0.0) else LxPalette.color(str(t["color"]), "stone")
		)
		ci.draw_line(pa.round(), pb.round(), PAL["night"] as Color, 3.0)
		ci.draw_line(pa.round(), pb.round(), col, 1.4)
		for k: int in range(1, links):
			var u: float = float(k) / float(links)
			var lp: Vector2 = pa.lerp(pb, u).round()
			ci.draw_rect(Rect2(lp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["void"] as Color)
			ci.draw_rect(Rect2(lp, Vector2.ONE), PAL["gold"] as Color if (k % 2 == 0 and bool(t["cuttable"])) else col)
		# Anchor rivets
		ci.draw_circle(pa.round(), 3.0, PAL["night"] as Color)
		ci.draw_circle(pa.round(), 1.8, PAL["gold"] as Color)
		ci.draw_circle(pb.round(), 3.0, PAL["night"] as Color)
		ci.draw_circle(pb.round(), 1.8, col)


static func _eval_end(v: Variant) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is Callable and (v as Callable).is_valid():
		var res: Variant = (v as Callable).call()
		if res is Vector2:
			return res as Vector2
	return Vector2.ZERO
