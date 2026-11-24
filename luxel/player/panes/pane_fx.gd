class_name LxPaneFx
extends Node2D
## In-world visual & tactical effect layer for equipped stained-glass panes:
## ember pools, ringing/petal decoys, orbiting stars, tide foam wakes, ash wards, chime arcs.
## Strict 20-colour Last Light palette; respects LxHudFx.flash_reduced().

static var active_instance: LxPaneFx = null

var _pools: Array[Dictionary] = []      # {pos, radius, ttl, max_ttl, dps, tick_cd, color, kind}
var _decoys: Array[Dictionary] = []     # {pos, ttl, max_ttl, pulse_cd, color, kind}
var _orbitals: Array[Dictionary] = []   # {angle, radius, ttl, hit_cd, color}
var _ash_ward: bool = false
var _clock: float = 0.0


static func ensure_in_world() -> LxPaneFx:
	if active_instance != null and is_instance_valid(active_instance):
		return active_instance
	if Lx.world == null or not is_instance_valid(Lx.world):
		return null
	var existing: Node = Lx.world.get_node_or_null("LxPaneFx")
	if existing is LxPaneFx and is_instance_valid(existing):
		active_instance = existing as LxPaneFx
		return active_instance
	var fx := LxPaneFx.new()
	fx.name = "LxPaneFx"
	fx.z_index = -2
	Lx.world.add_child(fx)
	active_instance = fx
	return fx


func _ready() -> void:
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func clear_all() -> void:
	_pools.clear()
	_decoys.clear()
	_orbitals.clear()
	_ash_ward = false
	queue_redraw()


func add_pool(at_pos: Vector2, radius: float, dur: float, dps: float, color_key: String, kind: String = "ember") -> void:
	if _pools.size() >= 12:
		_pools.remove_at(0)
	_pools.append({
		"pos": at_pos, "radius": radius, "ttl": dur, "max_ttl": dur,
		"dps": dps, "tick_cd": 0.15, "color": color_key, "kind": kind,
	})
	queue_redraw()


func add_decoy(at_pos: Vector2, dur: float, color_key: String, kind: String = "chime") -> void:
	if _decoys.size() >= 4:
		_decoys.remove_at(0)
	_decoys.append({
		"pos": at_pos, "ttl": dur, "max_ttl": dur,
		"pulse_cd": 0.35, "color": color_key, "kind": kind,
	})
	queue_redraw()


func add_orbital(dur: float, color_key: String = "gold") -> void:
	if _orbitals.size() >= 3:
		_orbitals.remove_at(0)
	_orbitals.append({
		"angle": _clock * 2.5 + float(_orbitals.size()) * (TAU / 3.0),
		"radius": 20.0, "ttl": dur, "hit_cd": 0.0, "color": color_key,
	})
	queue_redraw()


func set_ash_ward(enabled: bool) -> void:
	_ash_ward = enabled
	queue_redraw()


func consume_ash_ward() -> bool:
	if not _ash_ward:
		return false
	_ash_ward = false
	queue_redraw()
	return true


func has_ash_ward() -> bool:
	return _ash_ward


func pool_count() -> int:
	return _pools.size()


func decoy_count() -> int:
	return _decoys.size()


func orbital_count() -> int:
	return _orbitals.size()


func tick(dt: float) -> void:
	_clock += dt
	var dirty: bool = false
	var w: Node2D = Lx.player as Node2D if (Lx.player is Node2D and is_instance_valid(Lx.player)) else null
	var enemies: Array = []
	if w != null and Lx.world != null and is_instance_valid(Lx.world) and w.has_method("world_get_enemies"):
		enemies = w.call("world_get_enemies", Lx.world) as Array

	for i: int in range(_pools.size() - 1, -1, -1):
		var p: Dictionary = _pools[i]
		p["ttl"] = float(p["ttl"]) - dt
		p["tick_cd"] = float(p["tick_cd"]) - dt
		if float(p["tick_cd"]) <= 0.0:
			p["tick_cd"] = 0.40
			_apply_pool_effect(p, w, enemies)
		if float(p["ttl"]) <= 0.0:
			_pools.remove_at(i)
		dirty = true

	for i: int in range(_decoys.size() - 1, -1, -1):
		var d: Dictionary = _decoys[i]
		d["ttl"] = float(d["ttl"]) - dt
		d["pulse_cd"] = float(d["pulse_cd"]) - dt
		if float(d["pulse_cd"]) <= 0.0:
			d["pulse_cd"] = 0.65
			_apply_decoy_pulse(d, w, enemies)
		if float(d["ttl"]) <= 0.0:
			_decoys.remove_at(i)
		dirty = true

	for i: int in range(_orbitals.size() - 1, -1, -1):
		var o: Dictionary = _orbitals[i]
		o["ttl"] = float(o["ttl"]) - dt
		o["angle"] = float(o["angle"]) + dt * 4.2
		o["hit_cd"] = maxf(0.0, float(o["hit_cd"]) - dt)
		if w != null and float(o["hit_cd"]) <= 0.0:
			var opos: Vector2 = w.global_position + Vector2.from_angle(float(o["angle"])) * float(o["radius"])
			for ev: Variant in enemies:
				if not (ev is Object) or not is_instance_valid(ev as Object):
					continue
				if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", ev)):
					continue
				var epos: Vector2 = w.call("get_entity_pos", ev) as Vector2
				if epos.distance_to(opos) <= 13.0:
					var hit: LxHit = LxHit.make(LxHit.SOURCE_BOLT, 0.45, (epos - opos).normalized(), opos, 0.25, false, false, w)
					w.call("apply_hit_to_entity", ev, hit)
					o["hit_cd"] = 0.35
					break
		if float(o["ttl"]) <= 0.0:
			_orbitals.remove_at(i)
		dirty = true

	if dirty or _ash_ward:
		queue_redraw()


func _apply_pool_effect(p: Dictionary, w: Node2D, enemies: Array) -> void:
	if w == null or enemies.is_empty():
		return
	var ppos: Vector2 = p["pos"] as Vector2
	var prad: float = float(p["radius"])
	var kind: String = str(p["kind"])
	for ev: Variant in enemies:
		if not (ev is Object) or not is_instance_valid(ev as Object):
			continue
		if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", ev)):
			continue
		var epos: Vector2 = w.call("get_entity_pos", ev) as Vector2
		if epos.distance_to(ppos) <= prad:
			if kind == "foam" or kind == "vine":
				if ev.get("vel") is Vector2:
					ev.set("vel", (ev.get("vel") as Vector2) * 0.45)
			if float(p["dps"]) > 0.0:
				var hit: LxHit = LxHit.make(LxHit.SOURCE_BOLT, float(p["dps"]) * 0.4, Vector2.UP, ppos, 0.1, false, false, w)
				w.call("apply_hit_to_entity", ev, hit)


func _apply_decoy_pulse(d: Dictionary, w: Node2D, enemies: Array) -> void:
	if w == null:
		return
	var dpos: Vector2 = d["pos"] as Vector2
	if w.has_method("spawn_ring"):
		w.call("spawn_ring", dpos, 3.0, 22.0, 0.22, LxPalette.color(str(d["color"])), 1.0)
	for ev: Variant in enemies:
		if not (ev is Object) or not is_instance_valid(ev as Object):
			continue
		if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", ev)):
			continue
		var epos: Vector2 = w.call("get_entity_pos", ev) as Vector2
		if epos.distance_to(dpos) <= 26.0:
			var hit: LxHit = LxHit.make(LxHit.SOURCE_BOLT, 0.35, (epos - dpos).normalized(), dpos, 0.2, false, false, w)
			w.call("apply_hit_to_entity", ev, hit)


func _draw() -> void:
	var fr: bool = LxHudFx.flash_reduced()
	for p: Dictionary in _pools:
		var pos: Vector2 = (p["pos"] as Vector2).round()
		var r: float = roundf(float(p["radius"]))
		var col: Color = LxPalette.color(str(p["color"]))
		draw_arc(pos, r, 0.0, TAU, 16, col, 1.0)
		var core_r: float = maxf(2.0, roundf(r * 0.45))
		draw_rect(Rect2(pos - Vector2(core_r, 1.0), Vector2(core_r * 2.0, 2.0)), LxPalette.PAL["night"])
		draw_rect(Rect2(pos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxPalette.PAL["cream"] if (fr or int(_clock * 6.0) % 2 == 0) else col)

	for d: Dictionary in _decoys:
		var pos: Vector2 = (d["pos"] as Vector2).round()
		var col: Color = LxPalette.color(str(d["color"]))
		draw_rect(Rect2(pos + Vector2(-3.0, -7.0), Vector2(6.0, 8.0)), LxPalette.PAL["night"])
		draw_rect(Rect2(pos + Vector2(-2.0, -6.0), Vector2(4.0, 6.0)), col)
		draw_rect(Rect2(pos + Vector2(-1.0, -5.0), Vector2(2.0, 2.0)), LxPalette.PAL["cream"])

	var w: Node2D = Lx.player as Node2D if (Lx.player is Node2D and is_instance_valid(Lx.player)) else null
	if w != null:
		var wp: Vector2 = w.global_position.round()
		for o: Dictionary in _orbitals:
			var opos: Vector2 = (wp + Vector2.from_angle(float(o["angle"])) * float(o["radius"])).round()
			var col: Color = LxPalette.color(str(o["color"]))
			draw_rect(Rect2(opos - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), LxPalette.PAL["night"])
			draw_rect(Rect2(opos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col)
			draw_rect(Rect2(opos, Vector2.ONE), LxPalette.PAL["cream"])
		if _ash_ward:
			var a0: float = 0.0 if fr else _clock * 1.4
			draw_arc(wp + Vector2(0.0, -4.0), 10.0, a0, a0 + PI * 0.85, 10, LxPalette.PAL["apricot"], 1.0)
			draw_arc(wp + Vector2(0.0, -4.0), 10.0, a0 + PI, a0 + PI * 1.85, 10, LxPalette.PAL["gold"], 1.0)
