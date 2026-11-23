class_name LxBiomePassives
extends Node2D
## Subtle, skill-rewarding per-island combat & movement passives (Islands 1..8) so every
## island's moment-to-moment rhythm feels genuinely distinct. Zero aim assist; strict 20-colour palette.

const PAL: Dictionary = LxPalette.PAL

var _rules: LxBiomeRules = null
var _region: Node = null
var _island_id: int = 1
var _clock: float = 0.0
var _was_dashing: bool = false
var _bound_events: LxEventBus = null
var _trails: Array[Dictionary] = [] # {pos, age, dur, col}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	_bind_events(true)


func _exit_tree() -> void:
	_bind_events(false)


func _bind_events(enable: bool) -> void:
	var ev: LxEventBus = Lx.events if enable else _bound_events
	if ev == null or not is_instance_valid(ev):
		return
	var cb := Callable(self, "_on_enemy_killed")
	if enable:
		if _bound_events == ev:
			return
		_bind_events(false)
		_bound_events = ev
		if not ev.is_connected(&"enemy_killed", cb):
			ev.connect(&"enemy_killed", cb)
	else:
		if ev.is_connected(&"enemy_killed", cb):
			ev.disconnect(&"enemy_killed", cb)
		_bound_events = null


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	_bind_events(true)
	_rules = rules
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_clock = 0.0
	_was_dashing = false
	_trails.clear()
	queue_redraw()


func tick(dt: float) -> void:
	if dt <= 0.0 or _rules == null or not is_instance_valid(_rules):
		return
	_clock += dt
	for i: int in range(_trails.size() - 1, -1, -1):
		_trails[i]["age"] = float(_trails[i]["age"]) + dt
		if float(_trails[i]["age"]) >= float(_trails[i]["dur"]):
			_trails.remove_at(i)

	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if w != null and not w.dead:
		var dashing: bool = w.is_dashing()
		# Island 2: Sea-Spray Surge when dashing across shallow coastal tide water
		if _island_id == 2 and dashing and not _was_dashing and _region != null and _region.has_method("tile_at"):
			if str(_region.call("tile_at", w.global_position)) == "tide":
				var dir: Vector2 = w.facing.normalized() if w.facing.length_squared() > 0.01 else Vector2.RIGHT
				w.apply_recoil(dir * 26.0)
				w.spawn_sparks(w.global_position, -dir, 6, LxWick.PAL_ICE, 26.0, 64.0, 0.22)
		# Island 3: Canopy Ember Dew near any lit Forest Bloom-Lamp
		if _island_id == 3 and w.move_sunflare != null and w.move_sunflare.unlocked:
			for b: Dictionary in _rules._blooms:
				if float(b["lit_t"]) > 0.0 and w.global_position.distance_squared_to(b["pos"] as Vector2) <= 3136.0:
					w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 6.0 * dt)
					if fmod(_clock, 0.25) < dt:
						_trails.append({"pos": w.global_position + Vector2(sin(_clock * 9.0) * 5.0, -4.0), "age": 0.0, "dur": 0.42, "col": "lime"})
					break
		# Island 7: Full Silver Moon crystalline afterimage trail on Dash
		if _island_id == 7 and _rules.lunar_phase > 0.65 and dashing:
			if fmod(_clock, 0.06) < dt:
				_trails.append({"pos": w.global_position, "age": 0.0, "dur": 0.34, "col": "ice"})
		# Island 8: Golden Dawn Ribbon trail when Dawn Seals are broken
		if _island_id == 8 and dashing and LxBiomeMechanics.active_instance != null and LxBiomeMechanics.active_instance.dawn_seals_broken > 0:
			if fmod(_clock, 0.05) < dt:
				_trails.append({"pos": w.global_position, "age": 0.0, "dur": 0.38, "col": "gold"})
		_was_dashing = dashing
	if not _trails.is_empty():
		queue_redraw()


func on_updraft_gust(origin: Vector2) -> void:
	# Island 4: Thermal Lift mist ring gently pushes nearby non-boss foes clear of Wick's glide!
	if _region == null or not _region.has_method("get_enemies"):
		return
	var enemies_v: Variant = _region.call("get_enemies")
	if not (enemies_v is Array):
		return
	for e_v: Variant in (enemies_v as Array):
		if e_v is LxEnemyBrain and is_instance_valid(e_v):
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if e.is_alive() and not e.is_boss and e.pos.distance_to(origin) <= 56.0:
				var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
				e.knock += kdir * 70.0


func _on_enemy_killed(_enemy: Object, _kind: String, pos: Vector2, _opened_kill: bool) -> void:
	# Island 1: Acoustic Echo widens lantern light briefly
	if _island_id == 1:
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(pos, 72.0, 0.78 if LxHudFx.flash_reduced() else 1.15, 0.38)
	# Island 6: Hearthfire Harvest feeds +8 bonus Ember toward Sunflare!
	elif _island_id == 6 and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 8.0)
			_trails.append({"pos": pos, "age": 0.0, "dur": 0.45, "col": "coral"})
			_trails.append({"pos": pos.lerp(w.global_position, 0.5), "age": 0.0, "dur": 0.45, "col": "gold"})
			queue_redraw()


func _draw() -> void:
	for tr: Dictionary in _trails:
		var u: float = clampf(float(tr["age"]) / maxf(float(tr["dur"]), 0.01), 0.0, 1.0)
		var p: Vector2 = (tr["pos"] as Vector2).round()
		var col: Color = PAL[str(tr["col"])] as Color
		var a: float = (1.0 - u) * 0.78
		draw_circle(p + Vector2(0.0, -3.0), roundf(lerpf(4.0, 1.5, u)), Color(col, a))
		if u < 0.45:
			draw_rect(Rect2(p + Vector2(-1.0, -4.0), Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, a))
