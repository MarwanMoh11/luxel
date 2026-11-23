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
var _ripples: Array[Dictionary] = [] # {pos, age, dur, r0, r1, col}
var _fireflies: Array[Dictionary] = [] # {pos, vel, age, dur}
var _step_cd: float = 0.0
var _last_wpos: Vector2 = Vector2.ZERO
var _moon_mirror_pos: Vector2 = Vector2.ZERO
var _moon_mirror_on: bool = false


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
	_ripples.clear()
	_fireflies.clear()
	_step_cd = 0.0
	_last_wpos = Vector2.ZERO
	_moon_mirror_on = false
	queue_redraw()


func tick(dt: float) -> void:
	if dt <= 0.0 or _rules == null or not is_instance_valid(_rules):
		return
	_clock += dt
	_step_cd = maxf(0.0, _step_cd - dt)
	for arr: Array in [_trails, _ripples, _fireflies]:
		for i: int in range(arr.size() - 1, -1, -1):
			var it: Dictionary = arr[i] as Dictionary
			it["age"] = float(it["age"]) + dt
			if it.has("vel"):
				it["pos"] = (it["pos"] as Vector2) + (it["vel"] as Vector2) * dt
			if float(it["age"]) >= float(it["dur"]):
				arr.remove_at(i)

	_moon_mirror_on = false
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if w != null and not w.dead:
		var wpos: Vector2 = w.global_position
		var moved: bool = _last_wpos != Vector2.ZERO and wpos.distance_squared_to(_last_wpos) > 4.0
		_last_wpos = wpos
		var dashing: bool = w.is_dashing()
		var tile_kind: String = str(_region.call("tile_at", wpos)) if (_region != null and _region.has_method("tile_at")) else ""

		# Island 1: Warm brass chime motes on Dash
		if _island_id == 1 and dashing and not _was_dashing:
			_trails.append({"pos": wpos, "age": 0.0, "dur": 0.34, "col": "gold"})
		# Island 2: Sea-Spray Surge on tide + tidal footstep ripples
		if _island_id == 2 and tile_kind == "tide":
			if dashing and not _was_dashing:
				var dir: Vector2 = w.facing.normalized() if w.facing.length_squared() > 0.01 else Vector2.RIGHT
				w.apply_recoil(dir * 26.0)
				w.spawn_sparks(wpos, -dir, 6, LxWick.PAL_ICE, 26.0, 64.0, 0.22)
				_ripples.append({"pos": wpos, "age": 0.0, "dur": 0.42, "r0": 3.0, "r1": 14.0, "col": "ice"})
			elif moved and _step_cd <= 0.0:
				_step_cd = 0.24
				_ripples.append({"pos": wpos + Vector2(0.0, 2.0), "age": 0.0, "dur": 0.38, "r0": 2.0, "r1": 9.0, "col": "sky"})
		# Island 3: Canopy Ember Dew + guiding emerald fireflies toward nearest unlit beacon
		if _island_id == 3:
			if w.move_sunflare != null and w.move_sunflare.unlocked:
				for b: Dictionary in _rules._blooms:
					if float(b["lit_t"]) > 0.0 and wpos.distance_squared_to(b["pos"] as Vector2) <= 3136.0:
						w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 6.0 * dt)
						if fmod(_clock, 0.25) < dt:
							_trails.append({"pos": wpos + Vector2(sin(_clock * 9.0) * 5.0, -4.0), "age": 0.0, "dur": 0.42, "col": "lime"})
						break
			if not _rules.is_dungeon and _step_cd <= 0.0 and _fireflies.size() < 4:
				_step_cd = 0.95
				var b_dir: Vector2 = _dir_to_nearest_unlit_beacon(wpos)
				if b_dir != Vector2.ZERO:
					_fireflies.append({"pos": wpos + Vector2(0.0, -4.0), "vel": b_dir * 26.0, "age": 0.0, "dur": 1.15})
		# Island 4: Rose-ice lagoon ripples under Moth Wings glide over water
		if _island_id == 4 and w.is_gliding() and tile_kind in ["water", "tide"] and _step_cd <= 0.0:
			_step_cd = 0.20
			_ripples.append({"pos": wpos + Vector2(0.0, 4.0), "age": 0.0, "dur": 0.46, "r0": 2.0, "r1": 11.0, "col": "rose"})
		# Island 5: Starlight Surge golden boot trail
		if _island_id == 5 and _rules.starlight_surge_t > 0.0 and moved and _step_cd <= 0.0:
			_step_cd = 0.14
			_trails.append({"pos": wpos, "age": 0.0, "dur": 0.30, "col": "gold"})
		# Island 6: Volcanic cinder steps
		if _island_id == 6 and moved and _step_cd <= 0.0:
			_step_cd = 0.28
			_trails.append({"pos": wpos + Vector2(0.0, 2.0), "age": 0.0, "dur": 0.28, "col": "coral"})
		# Island 7: Full Silver Moon floor reflection + crystalline dash afterimages
		if _island_id == 7 and _rules.lunar_phase > 0.65:
			_moon_mirror_on = true
			_moon_mirror_pos = wpos
			if dashing and fmod(_clock, 0.06) < dt:
				_trails.append({"pos": wpos, "age": 0.0, "dur": 0.34, "col": "ice"})
		# Island 8: Golden Dawn Ribbon trail when Dawn Seals are broken
		if _island_id == 8 and dashing and LxBiomeMechanics.active_instance != null and LxBiomeMechanics.active_instance.dawn_seals_broken > 0:
			if fmod(_clock, 0.05) < dt:
				_trails.append({"pos": wpos, "age": 0.0, "dur": 0.38, "col": "gold"})
		# Relit Overworld Grace: warm golden-biome dawn motes gently trail Wick on saved islands!
		if not _rules.is_dungeon and moved and _step_cd <= 0.0 and Lx.state != null and Lx.state.relit_islands.has(_island_id):
			_step_cd = 0.22
			_trails.append({"pos": wpos + Vector2(sin(_clock * 6.0) * 3.0, -2.0), "vel": Vector2(0.0, -14.0), "age": 0.0, "dur": 0.42, "col": LxBiomePalette.key(_island_id, "glow")})
		_was_dashing = dashing
	if not _trails.is_empty() or not _ripples.is_empty() or not _fireflies.is_empty() or _moon_mirror_on:
		queue_redraw()


func _dir_to_nearest_unlit_beacon(from_pos: Vector2) -> Vector2:
	if _region == null or not _region.has_method("get_interactables"):
		return Vector2.ZERO
	var items_v: Variant = _region.call("get_interactables")
	if not (items_v is Array):
		return Vector2.ZERO
	var best_d2: float = INF
	var best_p: Vector2 = Vector2.ZERO
	for it: Variant in (items_v as Array):
		if it is LxBeacon and is_instance_valid(it):
			var b: LxBeacon = it as LxBeacon
			if b.active and not b.lit:
				var d2: float = b.pos.distance_squared_to(from_pos)
				if d2 > 400.0 and d2 < best_d2:
					best_d2 = d2
					best_p = b.pos
	return (best_p - from_pos).normalized() if best_d2 < INF else Vector2.ZERO


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
	# Biome-flavoured defeat burst ring + radial sparks (strictly 20 Last Light colours)
	var k_mid: String = LxBiomePalette.key(_island_id, "hi")
	var k_glow: String = LxBiomePalette.key(_island_id, "glow")
	_ripples.append({"pos": pos, "age": 0.0, "dur": 0.36, "r0": 3.0, "r1": 18.0, "col": k_glow})
	for k: int in range(6):
		var ang: float = float(k) * (TAU / 6.0) + pos.x * 0.03
		_trails.append({
			"pos": pos + Vector2(cos(ang) * 4.0, sin(ang) * 4.0),
			"vel": Vector2(cos(ang), sin(ang)) * 34.0,
			"age": 0.0, "dur": 0.34,
			"col": k_glow if k % 2 == 0 else k_mid,
		})
	# Island 1: Acoustic Echo widens lantern light briefly
	if _island_id == 1:
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(pos, 72.0, 0.78 if LxHudFx.flash_reduced() else 1.15, 0.38)
	# Island 6: Hearthfire Harvest feeds +8 bonus Ember toward Sunflare!
	elif _island_id == 6 and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 8.0)
			_trails.append({"pos": pos.lerp(w.global_position, 0.5), "age": 0.0, "dur": 0.45, "col": "gold"})
	queue_redraw()


func _draw() -> void:
	if _moon_mirror_on:
		var mp: Vector2 = _moon_mirror_pos.round() + Vector2(0.0, 6.0)
		draw_rect(Rect2(mp + Vector2(-3.0, -1.0), Vector2(6.0, 3.0)), Color(PAL["sky"] as Color, 0.32))
		draw_rect(Rect2(mp + Vector2(-2.0, 1.0), Vector2(4.0, 2.0)), Color(PAL["ice"] as Color, 0.28))
	for rp: Dictionary in _ripples:
		var u: float = clampf(float(rp["age"]) / maxf(float(rp["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(float(rp["r0"]), float(rp["r1"]), u))
		draw_arc((rp["pos"] as Vector2).round(), r, 0.0, TAU, 14, Color(PAL[str(rp["col"])] as Color, (1.0 - u) * 0.72), 1.0)
	for ff: Dictionary in _fireflies:
		var u: float = clampf(float(ff["age"]) / maxf(float(ff["dur"]), 0.01), 0.0, 1.0)
		var fp: Vector2 = (ff["pos"] as Vector2).round() + Vector2(0.0, roundf(sin(_clock * 7.0 + u * 8.0) * 2.0))
		var a: float = sin(u * PI) * 0.88
		draw_rect(Rect2(fp, Vector2(2.0, 2.0)), Color(PAL["lime"] as Color, a))
		draw_rect(Rect2(fp, Vector2.ONE), Color(PAL["cream"] as Color, a))
	for tr: Dictionary in _trails:
		var u: float = clampf(float(tr["age"]) / maxf(float(tr["dur"]), 0.01), 0.0, 1.0)
		var p: Vector2 = (tr["pos"] as Vector2).round()
		var col: Color = PAL[str(tr["col"])] as Color
		var a: float = (1.0 - u) * 0.78
		draw_circle(p + Vector2(0.0, -3.0), roundf(lerpf(4.0, 1.5, u)), Color(col, a))
		if u < 0.45:
			draw_rect(Rect2(p + Vector2(-1.0, -4.0), Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, a))
