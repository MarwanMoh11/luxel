class_name LxBossStage
extends RefCounted
## Boss arena stagecraft: dynamic tile edits with clean retry rollback, exit locking,
## zoom-free camera pans & shakes, music cues, darkness pulses, and scripted chase scrolling.

const WALKABLE_TILES: PackedStringArray = ["ground", "path", "bridge"]

var boss: LxEnemyBrain = null
var locked: bool = false
var _saved_tiles: Dictionary = {} # Vector2i -> original tile string
var _dark_pulse_t: float = 0.0
var _dark_pulse_dur: float = 0.0
var _dark_base: float = 0.36
var _dark_peak: float = 0.65

var chase_active: bool = false
var chase_dir: Vector2 = Vector2.RIGHT
var chase_speed: float = 28.0
var chase_traveled: float = 0.0
var chase_total: float = 240.0
var chase_window: Rect2 = Rect2()


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func reset_stage(world_ctx: Node) -> void:
	revert_tiles(world_ctx)
	lock_arena(false, world_ctx)
	chase_active = false
	chase_traveled = 0.0
	clear_darkness_pulse()


func clear_darkness_pulse() -> void:
	if _dark_pulse_t > 0.0:
		_dark_pulse_t = 0.0
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.set_darkness(_dark_base)


# --- Arena Lock & Tile Edits -------------------------------------------------

func lock_arena(is_locked: bool, world_ctx: Node) -> void:
	locked = is_locked
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("lock_exits"):
		world_ctx.call("lock_exits", is_locked)


func set_tiles(world_ctx: Node, rect: Rect2i, tile: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var grid_v: Variant = world_ctx.get("grid")
	if grid_v is Array:
		var g: Array = grid_v as Array
		var h: int = g.size()
		var w: int = (g[0] as PackedStringArray).size() if h > 0 else 0
		for ty: int in range(maxi(0, rect.position.y), mini(h, rect.end.y)):
			var row: PackedStringArray = g[ty] as PackedStringArray
			for tx: int in range(maxi(0, rect.position.x), mini(w, rect.end.x)):
				var key := Vector2i(tx, ty)
				if not _saved_tiles.has(key):
					_saved_tiles[key] = row[tx]
	if world_ctx.has_method("set_tiles"):
		world_ctx.call("set_tiles", rect, tile)
	elif grid_v is Array:
		var g2: Array = grid_v as Array
		var h2: int = g2.size()
		var w2: int = (g2[0] as PackedStringArray).size() if h2 > 0 else 0
		for ty: int in range(maxi(0, rect.position.y), mini(h2, rect.end.y)):
			var row2: PackedStringArray = g2[ty] as PackedStringArray
			for tx: int in range(maxi(0, rect.position.x), mini(w2, rect.end.x)):
				row2[tx] = tile
			g2[ty] = row2
		if world_ctx is CanvasItem:
			(world_ctx as CanvasItem).queue_redraw()
	# SPEC 3.2 law: dynamic tile edits never instant-kill Wick; nudge to nearest safe tile!
	if not WALKABLE_TILES.has(tile):
		_rescue_wick_if_unsafe(world_ctx)


func revert_tiles(world_ctx: Node) -> void:
	if _saved_tiles.is_empty() or world_ctx == null or not is_instance_valid(world_ctx):
		_saved_tiles.clear()
		return
	if world_ctx.has_method("set_tiles_batch"):
		world_ctx.call("set_tiles_batch", _saved_tiles)
	elif world_ctx.has_method("set_tiles"):
		var by_tile: Dictionary = {}
		for key_v: Variant in _saved_tiles.keys():
			var k: Vector2i = key_v as Vector2i
			var t: String = str(_saved_tiles[k])
			if not by_tile.has(t):
				by_tile[t] = []
			(by_tile[t] as Array).append(k)
		for t_v: Variant in by_tile.keys():
			var tile_s: String = str(t_v)
			for rect: Rect2i in _coalesce_tile_rects(by_tile[tile_s] as Array):
				world_ctx.call("set_tiles", rect, tile_s)
	else:
		var grid_v: Variant = world_ctx.get("grid")
		if grid_v is Array:
			var g: Array = grid_v as Array
			for key_v: Variant in _saved_tiles.keys():
				var k: Vector2i = key_v as Vector2i
				if k.y >= 0 and k.y < g.size():
					var row: PackedStringArray = g[k.y] as PackedStringArray
					if k.x >= 0 and k.x < row.size():
						row[k.x] = str(_saved_tiles[k])
						g[k.y] = row
			if world_ctx is CanvasItem:
				(world_ctx as CanvasItem).queue_redraw()
	_saved_tiles.clear()


static func _coalesce_tile_rects(cells: Array) -> Array[Rect2i]:
	var by_y: Dictionary = {}
	var ys: Array[int] = []
	for cv: Variant in cells:
		var c: Vector2i = cv as Vector2i
		if not by_y.has(c.y):
			by_y[c.y] = []
			ys.append(c.y)
		(by_y[c.y] as Array).append(c.x)
	ys.sort()
	var active: Dictionary = {} # Vector2i(x0, w) -> Rect2i
	var rects: Array[Rect2i] = []
	for y: int in ys:
		var xs: Array = by_y[y] as Array
		xs.sort()
		var next_active: Dictionary = {}
		var i: int = 0
		while i < xs.size():
			var x0: int = int(xs[i])
			var x1: int = x0
			while i + 1 < xs.size() and int(xs[i + 1]) <= x1 + 1:
				i += 1
				x1 = int(xs[i])
			var span := Vector2i(x0, x1 - x0 + 1)
			if active.has(span):
				var prev: Rect2i = active[span] as Rect2i
				if prev.end.y == y:
					next_active[span] = Rect2i(prev.position.x, prev.position.y, prev.size.x, prev.size.y + 1)
					active.erase(span)
					i += 1
					continue
			next_active[span] = Rect2i(x0, y, span.y, 1)
			i += 1
		for rem_v: Variant in active.values():
			rects.append(rem_v as Rect2i)
		active = next_active
	for rem2_v: Variant in active.values():
		rects.append(rem2_v as Rect2i)
	return rects


func _rescue_wick_if_unsafe(world_ctx: Node) -> void:
	if not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var w: Node2D = Lx.player as Node2D
	if not world_ctx.has_method("tile_at"):
		return
	var cur_t: String = str(world_ctx.call("tile_at", w.global_position))
	if WALKABLE_TILES.has(cur_t):
		return
	var ts: float = float(world_ctx.get("tile_size")) if (world_ctx.get("tile_size") != null and float(world_ctx.get("tile_size")) > 0.0) else 16.0
	var best: Vector2 = w.global_position
	var best_d: float = INF
	for rad_t: int in range(1, 6):
		for dy: int in range(-rad_t, rad_t + 1):
			for dx: int in range(-rad_t, rad_t + 1):
				var cand: Vector2 = w.global_position + Vector2(float(dx) * ts, float(dy) * ts)
				if WALKABLE_TILES.has(str(world_ctx.call("tile_at", cand))):
					var d: float = cand.distance_to(w.global_position)
					if d < best_d:
						best_d = d
						best = cand
		if best_d < INF:
			break
	w.global_position = best.round()


# --- Camera, Music & Darkness ------------------------------------------------

func pan_to(world_pos: Vector2, duration: float = 0.65) -> void:
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("trigger_focus_nudge"):
		Lx.camera.call("trigger_focus_nudge", world_pos, maxf(0.15, duration))


func shake(intensity: float) -> void:
	if not LxHudFx.shake_enabled():
		return
	var scaled: float = clampf(intensity, 0.0, 0.45) * (0.55 if LxHudFx.flash_reduced() else 1.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(scaled)
	elif Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.add_shake(scaled)


func set_music(cue: String) -> void:
	if cue.is_empty():
		return
	if Lx.events != null:
		Lx.events.music_mode_requested.emit(cue)


func play_sfx(sfx_id: String, at_pos: Vector2 = Vector2.ZERO) -> void:
	if Lx.events != null and not sfx_id.is_empty():
		Lx.events.sfx_requested.emit(sfx_id, at_pos, true)


func darkness_pulse(peak_strength: float = 0.68, duration: float = 1.1) -> void:
	if LxDarknessLayer.active_instance == null or not is_instance_valid(LxDarknessLayer.active_instance):
		return
	if _dark_pulse_t <= 0.0:
		_dark_base = LxDarknessLayer.active_instance.darkness_strength
	var cap: float = lerpf(_dark_base, peak_strength, 0.55 if LxHudFx.flash_reduced() else 1.0)
	_dark_peak = clampf(cap, 0.0, 0.92)
	_dark_pulse_dur = maxf(0.2, duration)
	_dark_pulse_t = _dark_pulse_dur


func light_burst(at_pos: Vector2, radius: float = 92.0, intensity: float = 1.4, dur: float = 0.40) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var mult: float = 0.62 if LxHudFx.flash_reduced() else 1.0
		LxDarknessLayer.active_instance.add_burst_light(at_pos, radius, intensity * mult, dur)


# --- Scripted Chase Scrolling Helper -----------------------------------------

func start_chase(dir: Vector2, speed: float, start_window: Rect2, total_dist: float) -> void:
	chase_active = true
	chase_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	chase_speed = maxf(8.0, speed)
	chase_window = start_window
	chase_traveled = 0.0
	chase_total = maxf(32.0, total_dist)


func stop_chase() -> void:
	chase_active = false


func chase_progress() -> float:
	return clampf(chase_traveled / maxf(chase_total, 1.0), 0.0, 1.0)


func tick(dt: float) -> void:
	if _dark_pulse_t > 0.0:
		_dark_pulse_t = maxf(0.0, _dark_pulse_t - dt)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			var u: float = sin(clampf(_dark_pulse_t / maxf(_dark_pulse_dur, 0.05), 0.0, 1.0) * PI)
			LxDarknessLayer.active_instance.set_darkness(lerpf(_dark_base, _dark_peak, u))
	if chase_active:
		var step: float = minf(chase_speed * dt, maxf(0.0, chase_total - chase_traveled))
		chase_traveled += step
		chase_window.position += chase_dir * step
		if Lx.camera != null and is_instance_valid(Lx.camera):
			Lx.camera.set_bounds(chase_window, true)
		if chase_traveled >= chase_total:
			chase_active = false
