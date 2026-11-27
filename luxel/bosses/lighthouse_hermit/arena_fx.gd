extends RefCounted
## Helper for Upgraded Lighthouse Hermit P2/P3 arena mutations on LxBossBase:
## - P2 tower_tide -> "high", safe outer tile flood via stage.set_tiles (auto-reverted on retry/death),
##   drifting mirrors (Ballast Clamp pins them!), and 2 interactive Tide Ring Buoy Mines.
## - P3 cupola twilight dimmer, Whirlpool Shell-Pull LxFields well, and cracked-shell tiny crab beat.

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
		var mult: float = 0.38 if what == "wick" else 1.0
		return (delta / d) * (128.0 * mult)


var boss: LxBossBase = null
var tide_mines: Array[Dictionary] = []
var _twilight_active: bool = false
var _saved_darkness: float = 0.36
var _pull_field: _HermitPullField = null


func _init(p_boss: LxBossBase = null) -> void:
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


func apply_p2_tower_tide() -> void:
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:lighthouse", "tower_tide", "high")
	if boss == null:
		return
	var ctx: Node = boss.world_ctx
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("tile_at"):
		return
	var c: Vector2 = boss.arena_rect.get_center()
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2
	for off_v: Vector2 in [Vector2(-112.0, -64.0), Vector2(112.0, -64.0), Vector2(-112.0, 48.0), Vector2(112.0, 48.0)]:
		var pt: Vector2 = c + off_v
		var tx: int = int(floorf(pt.x / 16.0))
		var ty: int = int(floorf(pt.y / 16.0))
		var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
		if str(ctx.call("tile_at", cp)) == "ground" and cp.distance_to(boss.home) > 48.0 and cp.distance_to(wp) > 28.0:
			boss.stage.set_tiles(ctx, Rect2i(tx, ty, 1, 1), "water")


func apply_p3_eclipse() -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		if not _twilight_active:
			_saved_darkness = LxDarknessLayer.active_instance.darkness_strength
		_twilight_active = true
		var peak: float = 0.56 if LxHudFx.flash_reduced() else 0.72
		LxDarknessLayer.active_instance.set_darkness(maxf(_saved_darkness, peak))


func set_pull_active(on: bool) -> void:
	if on and boss != null:
		if _pull_field == null:
			_pull_field = _HermitPullField.new()
			LxFields.add(_pull_field)
		_pull_field.center = boss.pos
		_pull_field.active = true
	elif _pull_field != null:
		_pull_field.active = false


func spawn_tide_mines() -> void:
	if boss == null:
		return
	tide_mines.clear()
	for sgn: float in [-1.0, 1.0]:
		var ang: float = boss.facing + sgn * 1.25
		var mp: Vector2 = boss.clamp_to_arena(boss.pos + Vector2.from_angle(ang) * 44.0)
		tide_mines.append({"pos": mp, "vel": Vector2.from_angle(ang) * 18.0, "ttl": 9.0, "batted": false})


func tick_mirrors_and_mines(dt: float, pulling: bool, on_mine_hit: Callable) -> void:
	if boss == null:
		return
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
				boss.stage.play_sfx("crab_shell_clank", mp)
			elif pulling:
				mv += (boss.pos - mp).normalized() * 165.0 * dt
				if mp.distance_to(boss.pos) <= boss.body_radius + 10.0:
					m["batted"] = true
		mp = boss.clamp_to_arena(mp + mv * dt)
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
	if boss == null:
		return
	var lc: Vector2 = off.round()
	for m: Dictionary in tide_mines:
		var mp: Vector2 = ((m["pos"] as Vector2) - boss.pos + off).round()
		ci.draw_arc(mp, 6.0, 0.0, TAU, 12, PAL["void"] as Color, 3.0)
		ci.draw_circle(mp, 5.0, PAL["night"] as Color)
		ci.draw_circle(mp, 3.0, PAL["gold" if bool(m["batted"]) else "coral"] as Color)
		ci.draw_arc(mp, 6.0, 0.0, TAU, 12, PAL["cream" if bool(m["batted"]) else "apricot"] as Color, 1.0)
	# P3 Personality beat: cracked cupola reveals tiny terrified crab plugging golden light leaks!
	if boss.phase >= 3:
		var jitter_x: float = 0.0 if boss.is_flash_reduced() else sin(boss.anim_t * 14.0) * 1.2
		var leak_p: Vector2 = (lc + Vector2(jitter_x, -boss.body_radius - 6.0)).round()
		ci.draw_line((lc + Vector2(-5.0, -9.0)).round(), (lc + Vector2(4.0, -3.0)).round(), PAL["void"] as Color, 3.0)
		ci.draw_line((lc + Vector2(-5.0, -9.0)).round(), (lc + Vector2(4.0, -3.0)).round(), PAL["cream"] as Color, 1.0)
		ci.draw_circle(leak_p, 2.4, PAL["coral"] as Color)
		ci.draw_rect(Rect2((leak_p + Vector2(-1.5, -1.0)).round(), Vector2(1.0, 1.0)), PAL["cream"] as Color)
		ci.draw_rect(Rect2((leak_p + Vector2(0.5, -1.0)).round(), Vector2(1.0, 1.0)), PAL["cream"] as Color)
