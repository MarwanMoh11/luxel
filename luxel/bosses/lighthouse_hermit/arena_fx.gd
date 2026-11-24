extends RefCounted
## Helper for Upgraded Lighthouse Hermit P2/P3 arena mutations:
## - P2 tower_tide -> "high", safe outer tile flood (cleanly reverted on death/setup),
##   drifting mirrors (Ballast Clamp pins them!), and 2 interactive Tide Ring Buoy Mines.
## - P3 cupola twilight dimmer, Whirlpool Shell-Pull LxFields well, and cracked-shell crab beat.

const PAL: Dictionary = LxPalette.PAL

class _HermitPullField:
	extends RefCounted
	var active: bool = false
	var center: Vector2 = Vector2.ZERO
	func is_field_active() -> bool:
		return active
	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var delta: Vector2 = center - p
		var d: float = delta.length()
		if d < 18.0 or d > 160.0:
			return Vector2.ZERO
		var mult: float = 0.42 if what == "wick" else 1.0
		return (delta / d) * (135.0 * mult)


var boss: LxEnemyBrain = null
var tide_mines: Array[Dictionary] = []
var _saved_tiles: Dictionary = {}
var _twilight_active: bool = false
var _saved_darkness: float = 0.36
var _pull_field: _HermitPullField = null


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func cleanup() -> void:
	tide_mines.clear()
	if _pull_field != null:
		_pull_field.active = false
		LxFields.remove(_pull_field)
		_pull_field = null
	if _twilight_active:
		_twilight_active = false
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.set_darkness(_saved_darkness)
	if not _saved_tiles.is_empty():
		var ctx: Node = boss.world_ctx if boss != null else null
		if ctx != null and is_instance_valid(ctx) and ctx.has_method("set_tiles"):
			for kv: Variant in _saved_tiles.keys():
				var k: Vector2i = kv as Vector2i
				ctx.call("set_tiles", Rect2i(k.x, k.y, 1, 1), str(_saved_tiles[k]))
		_saved_tiles.clear()


func apply_p2_tower_tide() -> void:
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:lighthouse", "tower_tide", "high")
	var ctx: Node = boss.world_ctx if boss != null else null
	if ctx != null and is_instance_valid(ctx) and ctx.get("grid") is Array:
		var g: Array = ctx.get("grid") as Array
		if g.size() >= 17 and (g[0] as PackedStringArray).size() >= 26:
			for cell: Vector2i in [Vector2i(4, 6), Vector2i(23, 6), Vector2i(5, 11), Vector2i(22, 11)]:
				_flood_cell(ctx, g, cell)


func _flood_cell(ctx: Node, g: Array, cell: Vector2i) -> void:
	var cell_c := Vector2((float(cell.x) + 0.5) * 16.0, (float(cell.y) + 0.5) * 16.0)
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2
	if wp.distance_to(cell_c) < 22.0 or boss.pos.distance_to(cell_c) < 22.0:
		return
	if cell.y >= 0 and cell.y < g.size():
		var row: PackedStringArray = g[cell.y] as PackedStringArray
		if cell.x >= 0 and cell.x < row.size() and not _saved_tiles.has(cell):
			_saved_tiles[cell] = row[cell.x]
			if ctx.has_method("set_tiles"):
				ctx.call("set_tiles", Rect2i(cell.x, cell.y, 1, 1), "water")


func apply_p3_eclipse() -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		if not _twilight_active:
			_saved_darkness = LxDarknessLayer.active_instance.darkness_strength
		_twilight_active = true
		var peak: float = 0.56 if LxHudFx.flash_reduced() else 0.72
		LxDarknessLayer.active_instance.set_darkness(maxf(_saved_darkness, peak))


func set_pull_active(on: bool) -> void:
	if on:
		if _pull_field == null:
			_pull_field = _HermitPullField.new()
			LxFields.add(_pull_field)
		_pull_field.center = boss.pos
		_pull_field.active = true
	elif _pull_field != null:
		_pull_field.active = false


func spawn_tide_mines() -> void:
	tide_mines.clear()
	for sgn: float in [-1.0, 1.0]:
		var ang: float = boss.facing + sgn * 1.25
		var mp: Vector2 = boss.pos + Vector2.from_angle(ang) * 44.0
		tide_mines.append({"pos": mp, "vel": Vector2.from_angle(ang) * 18.0, "ttl": 9.0, "batted": false})


func tick_mirrors_and_mines(dt: float, pulling: bool, on_mine_hit: Callable) -> void:
	if _pull_field != null:
		_pull_field.center = boss.pos
		_pull_field.active = pulling
	if boss.phase >= 2:
		_drift_mirrors(dt)
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2
	var lan_out: bool = bool(boss.call("_is_lantern_out"))
	var lan_p: Vector2 = boss.call("_get_lantern_pos") as Vector2
	for i: int in range(tide_mines.size() - 1, -1, -1):
		var m: Dictionary = tide_mines[i]
		m["ttl"] = float(m["ttl"]) - dt
		var mp: Vector2 = m["pos"] as Vector2
		var mv: Vector2 = m["vel"] as Vector2
		if not bool(m["batted"]):
			if (lan_out and mp.distance_to(lan_p) <= 22.0) or (Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).is_dashing() and mp.distance_to(wp) <= 24.0):
				m["batted"] = true
				mv = (boss.pos - mp).normalized() * 170.0
				boss.call("_emit_sfx", "warden_clank")
			elif pulling:
				mv += (boss.pos - mp).normalized() * 165.0 * dt
				if mp.distance_to(boss.pos) <= boss.body_radius + 10.0:
					m["batted"] = true
		mp += mv * dt
		mv *= exp(-1.6 * dt)
		m["pos"] = mp
		m["vel"] = mv
		if bool(m["batted"]) and mp.distance_to(boss.pos) <= boss.body_radius + 11.0:
			tide_mines.remove_at(i)
			if on_mine_hit.is_valid():
				on_mine_hit.call()
			continue
		if float(m["ttl"]) <= 0.0:
			tide_mines.remove_at(i)


func _drift_mirrors(dt: float) -> void:
	var ctx: Node = boss.world_ctx
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("get_interactables"):
		return
	var lan_out: bool = bool(boss.call("_is_lantern_out"))
	var lan_p: Vector2 = boss.call("_get_lantern_pos") as Vector2
	var idx: int = 0
	for it_v: Variant in ctx.call("get_interactables") as Array:
		if not (it_v is LxMirror) or not is_instance_valid(it_v):
			continue
		var m: LxMirror = it_v as LxMirror
		idx += 1
		if lan_out and m.pos.distance_to(lan_p) <= 22.0:
			continue
		var vel_m := Vector2(cos(boss.anim_t * 0.9 + float(idx) * 1.6) * 5.5, sin(boss.anim_t * 1.1 + float(idx) * 1.2) * 3.5)
		var cand: Vector2 = m.pos + vel_m * dt
		if ctx.has_method("tile_at") and str(ctx.call("tile_at", cand)) != "wall":
			m.pos = cand
			m.position = cand.round()


func draw_extras(ci: CanvasItem, off: Vector2) -> void:
	var lc: Vector2 = off.round()
	for m: Dictionary in tide_mines:
		var mp: Vector2 = ((m["pos"] as Vector2) - boss.pos + off).round()
		ci.draw_circle(mp, 5.2, PAL["night"] as Color)
		ci.draw_circle(mp, 3.6, PAL["gold" if bool(m["batted"]) else "coral"] as Color)
		ci.draw_arc(mp, 6.4, 0.0, TAU, 10, PAL["cream" if bool(m["batted"]) else "apricot"] as Color, 1.0)
	# P3 Personality beat: cracked cupola reveals tiny terrified crab plugging golden light leaks!
	if boss.phase >= 3:
		var leak_p: Vector2 = lc + Vector2(sin(boss.anim_t * 14.0) * 1.2, -boss.body_radius - 6.0)
		ci.draw_line(lc + Vector2(-5.0, -9.0), lc + Vector2(4.0, -3.0), PAL["cream"] as Color, 1.4)
		ci.draw_circle(leak_p, 2.4, PAL["coral"] as Color)
		ci.draw_rect(Rect2(leak_p + Vector2(-1.5, -1.0), Vector2(1.0, 1.0)), PAL["cream"] as Color)
		ci.draw_rect(Rect2(leak_p + Vector2(0.5, -1.0), Vector2(1.0, 1.0)), PAL["cream"] as Color)
