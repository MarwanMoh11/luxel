class_name LxBossProps
extends RefCounted
## Arena props owned by a boss: breakable pillars, crates, chandeliers, boulders, resonance bells.
## Supports grabbing/throwing, ceiling drops with telegraphed danger rings, cover blocking, and shattering.

const PAL: Dictionary = LxPalette.PAL
const MIN_DROP_TELL: float = 0.50

var boss: LxEnemyBrain = null
var props: Array[Dictionary] = []
var _clock: float = 0.0
var _next_uid: int = 1


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func clear() -> void:
	props.clear()
	_next_uid = 1


func active_count() -> int:
	var n: int = 0
	for p: Dictionary in props:
		if str(p["state"]) != "broken":
			n += 1
	return n


func get_prop(id: String) -> Dictionary:
	for p: Dictionary in props:
		if str(p["id"]) == id:
			return p
	return {}


func get_positions(kind_filter: String = "") -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Dictionary in props:
		if str(p["state"]) == "broken":
			continue
		if not kind_filter.is_empty() and str(p["kind"]) != kind_filter:
			continue
		out.append(p["pos"] as Vector2)
	return out


func spawn_pillar(pos: Vector2, hp: float = 4.0, id: String = "") -> Dictionary:
	return _add_prop(id, "pillar", pos, {"hp": hp, "radius": 10.0, "solid": true, "breakable": true, "color": "stone"})


func spawn_crate(pos: Vector2, hp: float = 2.5, id: String = "") -> Dictionary:
	return _add_prop(id, "crate", pos, {"hp": hp, "radius": 8.0, "solid": true, "breakable": true, "throwable": true, "color": "apricot"})


func spawn_chandelier(pos: Vector2, hp: float = 3.0, id: String = "") -> Dictionary:
	return _add_prop(id, "chandelier", pos, {"hp": hp, "radius": 12.0, "solid": false, "breakable": true, "z": 36.0, "color": "gold"})


func spawn_boulder(pos: Vector2, hp: float = 3.0, id: String = "") -> Dictionary:
	return _add_prop(id, "boulder", pos, {"hp": hp, "radius": 9.0, "solid": true, "breakable": true, "throwable": true, "color": "mauve"})


func spawn_bell(pos: Vector2, on_ring: Callable = Callable(), id: String = "") -> Dictionary:
	return _add_prop(id, "bell", pos, {"hp": 999.0, "radius": 9.0, "solid": true, "breakable": false, "color": "gold", "on_hit": on_ring})


func _add_prop(id: String, kind: String, pos: Vector2, cfg: Dictionary) -> Dictionary:
	var pid: String = id if not id.is_empty() else ("%s_%d" % [kind, _next_uid])
	_next_uid += 1
	var p: Dictionary = {
		"id": pid, "kind": kind, "pos": pos, "start_pos": pos, "target_pos": pos,
		"radius": maxf(5.0, float(cfg.get("radius", 9.0))),
		"hp": maxf(0.5, float(cfg.get("hp", 3.0))),
		"max_hp": maxf(0.5, float(cfg.get("hp", 3.0))),
		"solid": bool(cfg.get("solid", true)),
		"breakable": bool(cfg.get("breakable", true)),
		"throwable": bool(cfg.get("throwable", false)),
		"state": "idle", # idle | held | thrown | falling | broken
		"z": float(cfg.get("z", 0.0)),
		"flight_t": 0.0, "flight_dur": 0.6, "impact_r": 24.0, "damage": 1.0,
		"color": str(cfg.get("color", "stone")),
		"flash_t": 0.0, "cd": 0.0,
		"on_break": cfg.get("on_break", Callable()),
		"on_impact": cfg.get("on_impact", Callable()),
		"on_hit": cfg.get("on_hit", Callable()),
	}
	props.append(p)
	if props.size() > 32:
		for i: int in range(props.size() - 1, -1, -1):
			if str(props[i]["state"]) == "broken":
				props.remove_at(i)
	return p


func grab_prop(id: String) -> bool:
	var p: Dictionary = get_prop(id)
	if p.is_empty() or str(p["state"]) != "idle":
		return false
	p["state"] = "held"
	p["solid"] = false
	p["z"] = 14.0
	return true


func throw_prop(id: String, target_pos: Vector2, flight_s: float = 0.62, impact_r: float = 24.0, dmg: float = 1.0) -> bool:
	var p: Dictionary = get_prop(id)
	if p.is_empty() or str(p["state"]) == "broken":
		return false
	p["state"] = "thrown"
	p["start_pos"] = p["pos"]
	p["target_pos"] = target_pos
	p["flight_t"] = 0.0
	p["flight_dur"] = maxf(MIN_DROP_TELL, flight_s) * _assist_scale()
	p["impact_r"] = maxf(14.0, impact_r)
	p["damage"] = maxf(0.5, dmg)
	p["solid"] = false
	return true


func drop_prop(id: String, drop_s: float = 0.62, impact_r: float = 28.0, dmg: float = 1.0) -> bool:
	var p: Dictionary = get_prop(id)
	if p.is_empty() or str(p["state"]) == "broken":
		return false
	p["state"] = "falling"
	p["start_pos"] = p["pos"]
	p["target_pos"] = p["pos"]
	p["flight_t"] = 0.0
	p["flight_dur"] = maxf(MIN_DROP_TELL, drop_s) * _assist_scale()
	p["impact_r"] = maxf(16.0, impact_r)
	p["damage"] = maxf(0.5, dmg)
	p["z"] = maxf(24.0, float(p["z"]))
	return true


func hit_by_bolt(b: LxBossBolt) -> bool:
	if b == null or not b.active:
		return false
	for p: Dictionary in props:
		if str(p["state"]) != "idle" or not bool(p["solid"]):
			continue
		var pp: Vector2 = p["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(pp, b.prev_pos, b.pos).distance_to(pp) <= float(p["radius"]) + b.radius:
			if bool(p["breakable"]):
				_damage_prop(p, 0.5)
			return true
	return false


func collide_circle(pt: Vector2, rad: float) -> Vector2:
	var out: Vector2 = pt
	for p: Dictionary in props:
		if str(p["state"]) != "idle" or not bool(p["solid"]):
			continue
		var pp: Vector2 = p["pos"] as Vector2
		var min_d: float = float(p["radius"]) + rad
		var d: Vector2 = out - pp
		var dist: float = d.length()
		if dist < min_d:
			out = pp + ((d / dist) if dist > 0.01 else Vector2.RIGHT) * min_d
	return out


func tick(dt: float) -> void:
	_clock += dt
	var wick_node: LxWick = Lx.player as LxWick if (is_instance_valid(Lx.player) and Lx.player is LxWick) else null
	var has_p: bool = boss != null and boss.has_method("_has_player") and bool(boss.call("_has_player"))
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2 if has_p else Vector2(-9999.0, -9999.0)

	for p: Dictionary in props:
		if str(p["state"]) == "broken":
			continue
		p["flash_t"] = maxf(0.0, float(p["flash_t"]) - dt)
		p["cd"] = maxf(0.0, float(p["cd"]) - dt)

		# Player bolt interaction (shoot chandeliers / pillars / bells)
		if wick_node != null and str(p["state"]) == "idle":
			var pp: Vector2 = p["pos"] as Vector2
			var pr: float = float(p["radius"])
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if not is_instance_valid(bv) or not (bv is Object):
					continue
				var bp: Vector2 = bv.get("pos") as Vector2
				if bp.distance_to(pp) <= pr + 4.0:
					var dmg: float = float(bv.get("damage"))
					wick_node.bolts.remove_at(bi)
					_on_player_hit_prop(p, dmg)
					break

		var st: String = str(p["state"])
		if st == "held" and boss != null and is_instance_valid(boss):
			p["pos"] = boss.pos + Vector2(0.0, -boss.body_radius - 6.0)
		elif st == "thrown" or st == "falling":
			p["flight_t"] = float(p["flight_t"]) + dt
			var u: float = clampf(float(p["flight_t"]) / maxf(float(p["flight_dur"]), 0.05), 0.0, 1.0)
			if st == "thrown":
				p["pos"] = (p["start_pos"] as Vector2).lerp(p["target_pos"] as Vector2, u)
				p["z"] = sin(u * PI) * 28.0
			else:
				p["z"] = lerpf(36.0, 0.0, u * u)
			if u >= 1.0:
				_impact_prop(p, has_p, wp)


func _on_player_hit_prop(p: Dictionary, dmg: float) -> void:
	p["flash_t"] = 0.14
	var cb: Callable = p["on_hit"] as Callable
	if cb.is_valid() and float(p["cd"]) <= 0.0:
		p["cd"] = 1.5
		cb.call(p)
	if str(p["kind"]) == "chandelier" and float(p["hp"]) - dmg <= 0.001:
		drop_prop(str(p["id"]), 0.55, 30.0, 1.0)
		return
	if bool(p["breakable"]):
		_damage_prop(p, dmg)


func _damage_prop(p: Dictionary, dmg: float) -> void:
	p["hp"] = maxf(0.0, float(p["hp"]) - dmg)
	p["flash_t"] = 0.12
	if float(p["hp"]) <= 0.001:
		p["state"] = "broken"
		p["solid"] = false
		var pp: Vector2 = p["pos"] as Vector2
		LxDamageFx.boss_impact(pp, 0.12, 48.0, 52.0, 48.0, 1.20, 0.22)
		if Lx.events != null:
			Lx.events.sfx_requested.emit("warden_shield_break", pp, true)
		var cb: Callable = p["on_break"] as Callable
		if cb.is_valid():
			cb.call(p)


func _impact_prop(p: Dictionary, has_p: bool, wp: Vector2) -> void:
	var tp: Vector2 = p["target_pos"] as Vector2
	var ir: float = float(p["impact_r"])
	p["pos"] = tp
	p["z"] = 0.0
	LxDamageFx.boss_impact(tp, 0.20, 82.0, 84.0, 82.0, 1.40, 0.32)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("bellkeeper_slam_fire", tp, true)
	if has_p and wp.distance_to(tp) <= ir:
		var push: Vector2 = (wp - tp).normalized() if wp.distance_to(tp) > 0.1 else Vector2.DOWN
		if boss != null and boss.has_method("emit_boss_damage"):
			boss.call("emit_boss_damage", push, float(p["damage"]), "prop_impact", tp, true)
	# Dropped chandeliers can also stagger the boss if boss is underneath!
	if str(p["kind"]) == "chandelier" and boss != null and is_instance_valid(boss) and boss.pos.distance_to(tp) <= ir + boss.body_radius:
		if boss.has_method("add_stagger"):
			boss.call("add_stagger", 3.5)
	var cb: Callable = p["on_impact"] as Callable
	if cb.is_valid():
		cb.call(p)
	p["state"] = "broken" if bool(p["breakable"]) else "idle"
	p["solid"] = str(p["state"]) == "idle"


func draw_props(ci: CanvasItem, origin_world: Vector2) -> void:
	var off: Vector2 = -origin_world
	for p: Dictionary in props:
		var st: String = str(p["state"])
		if st == "broken":
			continue
		var gp: Vector2 = ((p["pos"] as Vector2) + off).round()
		var r: float = float(p["radius"])
		var z: float = float(p["z"])
		if st == "thrown" or st == "falling":
			var tp: Vector2 = ((p["target_pos"] as Vector2) + off).round()
			var u: float = clampf(float(p["flight_t"]) / maxf(float(p["flight_dur"]), 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(ci, tp, float(p["impact_r"]), u, _clock, "coral", "gold")
		ci.draw_circle(gp + Vector2(0.0, r * 0.35), r * 0.85, Color(PAL["void"] as Color, 0.36))
		var body_p: Vector2 = (gp + Vector2(0.0, -z)).round()
		var col: Color = PAL["cream"] as Color if float(p["flash_t"]) > 0.0 else LxPalette.color(str(p["color"]), "stone")
		var kind: String = str(p["kind"])
		if kind == "pillar":
			ci.draw_rect(Rect2(body_p + Vector2(-r * 0.7, -r * 1.4), Vector2(r * 1.4, r * 1.8)), PAL["night"] as Color)
			ci.draw_rect(Rect2(body_p + Vector2(-r * 0.55, -r * 1.25), Vector2(r * 1.1, r * 1.5)), col)
			ci.draw_rect(Rect2(body_p + Vector2(-r * 0.55, -r * 1.25), Vector2(r * 1.1, 3.0)), PAL["cream"] as Color)
		elif kind == "chandelier":
			ci.draw_arc(body_p, roundf(r), 0.0, TAU, 16, PAL["void"] as Color, 3.0)
			ci.draw_arc(body_p, roundf(r) - 1.0, 0.0, TAU, 16, col, 2.0)
			for k: int in range(4):
				var cp: Vector2 = (body_p + Vector2.from_angle(float(k) * PI * 0.5) * (r - 1.5)).round()
				ci.draw_circle(cp, 2.0, PAL["cream"] as Color)
		elif kind == "bell":
			ci.draw_rect(Rect2(body_p + Vector2(-5.0, -8.0), Vector2(10.0, 9.0)), PAL["night"] as Color)
			ci.draw_rect(Rect2(body_p + Vector2(-4.0, -7.0), Vector2(8.0, 7.0)), col)
			ci.draw_rect(Rect2(body_p + Vector2(-2.0, -6.0), Vector2(2.0, 5.0)), PAL["cream"] as Color)
		else:
			ci.draw_rect(Rect2(body_p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), PAL["night"] as Color)
			ci.draw_rect(Rect2(body_p - Vector2(r - 1.0, r - 1.0), Vector2(r * 2.0 - 2.0, r * 2.0 - 2.0)), col)


func _assist_scale() -> float:
	if boss != null and boss.has_method("get_tell_scale"):
		return float(boss.call("get_tell_scale"))
	return 1.0
