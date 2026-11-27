class_name LxRegionArena
extends Node2D
## Generic boss/mini-boss arena lock (R2 play audit) + geometry helpers for LxRegionLoader.
## Locks room exits visibly once an arena_lock boss/mini-boss is engaged and Wick is inside,
## and reopens cleanly on boss death or Wick death.

const PAL: Dictionary = LxPalette.PAL

var locked: bool = false
var _lock_flash: float = 0.0
var _rise_t: float = 0.0
var _clock: float = 0.0
var _region: LxRegionLoader = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4


func get_rise_progress() -> float:
	return _rise_t


func reset(region: LxRegionLoader) -> void:
	_region = region
	locked = false
	_lock_flash = 0.0
	_rise_t = 0.0
	_clock = 0.0
	queue_redraw()


static func tune_boss_ranges(brain: LxEnemyBrain, region: LxRegionLoader) -> void:
	if brain == null or region == null or not (brain.is_boss or not brain.boss_id.is_empty()):
		return
	var bid: String = brain.boss_id if not brain.boss_id.is_empty() else brain.kind
	var meta: Dictionary = Lx.packs.boss_meta(bid) if Lx.packs != null else {}
	if not bool(meta.get("arena_lock", true)):
		return
	var max_d: float = brain.home.distance_to(region.spawn_pos)
	for ex: Dictionary in region.exits:
		var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		if er.has_area():
			max_d = maxf(max_d, brain.home.distance_to(er.get_center()))
	var diag: float = region.bounds.size.length() if region.bounds.has_area() else 420.0
	var cap: float = maxf(240.0, diag)
	brain.notice_radius = clampf(maxf(brain.notice_radius, max_d + 36.0), brain.notice_radius, cap)
	brain.leash_radius = clampf(maxf(brain.leash_radius, max_d + 24.0), brain.leash_radius, cap)


func tick(dt: float, region: LxRegionLoader, wick_pos: Vector2) -> void:
	_region = region
	if region == null:
		return
	var wick_dead: bool = Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("dead") == true
	var has_engaged_boss: bool = false
	var any_live_lock_boss: bool = false
	for e_v: Variant in region.get_enemies():
		if not is_instance_valid(e_v) or not (e_v is LxEnemyBrain):
			continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or not e.visible:
			continue
		if not (e.is_boss or not e.boss_id.is_empty()):
			continue
		var bid: String = e.boss_id if not e.boss_id.is_empty() else e.kind
		var meta: Dictionary = Lx.packs.boss_meta(bid) if Lx.packs != null else {}
		if not bool(meta.get("arena_lock", true)):
			continue
		any_live_lock_boss = true
		var engaged: bool = (e.state != LxEnemyBrain.State.ROUTINE and e.state != LxEnemyBrain.State.DEAD) or e.hp < e.max_hp - 0.01
		if engaged:
			has_engaged_boss = true
			break

	var inside: bool = wick_pos.x > -9000.0 and region.bounds.grow(-12.0).has_point(wick_pos)
	if not locked:
		if has_engaged_boss and inside and not wick_dead:
			locked = true
			_lock_flash = 0.35
			if Lx.events != null:
				Lx.events.sfx_requested.emit("arena_bars_rise", wick_pos, false)
				Lx.events.shake_requested.emit(0.04 if LxHudFx.flash_reduced() else 0.08)
			queue_redraw()
		elif _rise_t > 0.0:
			_rise_t = maxf(0.0, _rise_t - dt / 0.26)
			queue_redraw()
	else:
		if not any_live_lock_boss or wick_dead:
			locked = false
			_lock_flash = 0.0
			if not wick_dead and Lx.events != null:
				Lx.events.sfx_requested.emit("arena_bars_fall", wick_pos, false)
			queue_redraw()
		else:
			_clock += dt
			_lock_flash = maxf(0.0, _lock_flash - dt)
			_rise_t = minf(1.0, _rise_t + dt / 0.34)
			queue_redraw()


func _draw() -> void:
	if (not locked and _rise_t <= 0.01) or _region == null:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var rise: float = clampf(_rise_t, 0.15 if locked else 0.0, 1.0)
	var pulse: bool = fr or fmod(_clock * 4.0, 1.0) < 0.5
	var bar_col: Color = (PAL["cream"] if _lock_flash > 0.1 else (PAL["coral"] if pulse else PAL["gold"])) as Color
	var iron_col: Color = PAL["stone"] as Color
	var rim_col: Color = PAL["void"] as Color
	for ex: Dictionary in _region.exits:
		var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		if not er.has_area():
			continue
		draw_rect(er.grow(1.0), Color(rim_col, 0.72 * rise))
		draw_rect(er, Color(PAL["wine"] as Color, 0.34 * rise))
		if er.size.x >= er.size.y:
			# Horizontal exit: vertical portcullis bars rising from the bottom threshold.
			var span_h: float = maxf(2.0, roundf(er.size.y * rise))
			var y_top: float = roundf(er.end.y - span_h)
			var bx: float = roundf(er.position.x + 2.0)
			while bx <= er.end.x - 3.0:
				draw_rect(Rect2(bx - 1.0, y_top, 3.0, span_h), rim_col)
				draw_rect(Rect2(bx, y_top, 1.0, span_h), iron_col)
				draw_rect(Rect2(bx, y_top, 1.0, 2.0), bar_col)
				bx += 5.0
			draw_rect(Rect2(er.position.x, y_top - 1.0, er.size.x, 3.0), rim_col)
			draw_rect(Rect2(er.position.x + 1.0, y_top, maxf(1.0, er.size.x - 2.0), 1.0), bar_col)
		else:
			# Vertical exit: horizontal portcullis bars extending across the doorway.
			var span_w: float = maxf(2.0, roundf(er.size.x * rise))
			var x_edge: float = roundf(er.end.x - span_w)
			var by: float = roundf(er.position.y + 2.0)
			while by <= er.end.y - 3.0:
				draw_rect(Rect2(x_edge, by - 1.0, span_w, 3.0), rim_col)
				draw_rect(Rect2(x_edge, by, span_w, 1.0), iron_col)
				draw_rect(Rect2(x_edge, by, 2.0, 1.0), bar_col)
				by += 5.0
			draw_rect(Rect2(x_edge - 1.0, er.position.y, 3.0, er.size.y), rim_col)
			draw_rect(Rect2(x_edge, er.position.y + 1.0, 1.0, maxf(1.0, er.size.y - 2.0)), bar_col)


# ---- Pure geometry & visibility helpers extracted from LxRegionLoader ----

static func collide_world(
	region: LxRegionLoader, pos: Vector2, radius: float,
	can_cross_pit: bool, can_cross_water: bool, ignore_id: String, arena_locked: bool,
	is_flying: bool = false
) -> Vector2:
	if region.width <= 0 or region.height <= 0:
		return pos
	var b: Rect2 = region.bounds
	var p := Vector2(
		clampf(pos.x, b.position.x + radius, maxf(b.position.x + radius, b.end.x - radius)),
		clampf(pos.y, b.position.y + radius, maxf(b.position.y + radius, b.end.y - radius))
	)
	var ts: float = float(region.tile_size)
	var items: Array[LxInteractable] = region.get_interactables()
	var solid_rects: Array[Rect2] = []
	for it: LxInteractable in items:
		if it != null and it.is_solid() and (ignore_id.is_empty() or it.id != ignore_id):
			if is_flying and it.has_method("blocks_flyer") and not bool(it.call("blocks_flyer")):
				continue
			var srect: Rect2 = it.get_solid_rect()
			if srect.size.x > 0.0 and srect.size.y > 0.0:
				solid_rects.append(srect)
	var exit_rects: Array[Rect2] = []
	if arena_locked:
		for ex: Dictionary in region.exits:
			var er: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
			if er.has_area():
				exit_rects.append(er)
	for _pass: int in range(2):
		var tx0: int = maxi(0, int(floor((p.x - radius) / ts)))
		var tx1: int = mini(region.width - 1, int(floor((p.x + radius) / ts)))
		var ty0: int = maxi(0, int(floor((p.y - radius) / ts)))
		var ty1: int = mini(region.height - 1, int(floor((p.y + radius) / ts)))
		for ty: int in range(ty0, ty1 + 1):
			var row: PackedStringArray = region.grid[ty]
			for tx: int in range(tx0, tx1 + 1):
				var ttype: String = row[tx]
				if not region.is_solid_tile(ttype, can_cross_pit, can_cross_water):
					continue
				var tile_rect := Rect2(float(tx) * ts, float(ty) * ts, ts, ts)
				if not region._is_tile_supported(ttype, tile_rect.get_center()):
					var sl: bool = _is_solid_grid_cell(region, tx - 1, ty, ts, can_cross_pit, can_cross_water)
					var sr: bool = _is_solid_grid_cell(region, tx + 1, ty, ts, can_cross_pit, can_cross_water)
					var su: bool = _is_solid_grid_cell(region, tx, ty - 1, ts, can_cross_pit, can_cross_water)
					var sd: bool = _is_solid_grid_cell(region, tx, ty + 1, ts, can_cross_pit, can_cross_water)
					p = push_circle_out_of_tile(p, radius, tile_rect, sl, sr, su, sd)
		for srect: Rect2 in solid_rects:
			p = push_circle_out_of_rect(p, radius, srect)
		for er: Rect2 in exit_rects:
			p = push_circle_out_of_rect(p, radius, er)
	p = Vector2(
		clampf(p.x, b.position.x + radius, maxf(b.position.x + radius, b.end.x - radius)),
		clampf(p.y, b.position.y + radius, maxf(b.position.y + radius, b.end.y - radius))
	)
	return p


static func _is_solid_grid_cell(
	region: LxRegionLoader, tx: int, ty: int, ts: float, can_cross_pit: bool, can_cross_water: bool
) -> bool:
	if tx < 0 or ty < 0 or tx >= region.width or ty >= region.height:
		return true
	var ttype: String = region.grid[ty][tx]
	if not region.is_solid_tile(ttype, can_cross_pit, can_cross_water):
		return false
	return not region._is_tile_supported(ttype, Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts))


static func push_circle_out_of_tile(
	center: Vector2, radius: float, rect: Rect2,
	solid_l: bool, solid_r: bool, solid_u: bool, solid_d: bool
) -> Vector2:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	var delta: Vector2 = center - closest
	var dist_sq: float = delta.length_squared()
	if dist_sq >= radius * radius:
		return center
	if dist_sq > 0.0001:
		var into_seam: bool = false
		if absf(delta.x) >= absf(delta.y):
			into_seam = (delta.x < 0.0 and solid_l) or (delta.x > 0.0 and solid_r)
		else:
			into_seam = (delta.y < 0.0 and solid_u) or (delta.y > 0.0 and solid_d)
		if not into_seam:
			var d: float = sqrt(dist_sq)
			return center + (delta / d) * (radius - d)
	var dl: float = center.x - rect.position.x; var dr: float = rect.end.x - center.x
	var dt_: float = center.y - rect.position.y; var db: float = rect.end.y - center.y
	var best_d: float = INF
	var best_p: Vector2 = center
	if not solid_l and dl < best_d:
		best_d = dl; best_p = Vector2(rect.position.x - radius, center.y)
	if not solid_r and dr < best_d:
		best_d = dr; best_p = Vector2(rect.end.x + radius, center.y)
	if not solid_u and dt_ < best_d:
		best_d = dt_; best_p = Vector2(center.x, rect.position.y - radius)
	if not solid_d and db < best_d:
		best_d = db; best_p = Vector2(center.x, rect.end.y + radius)
	if best_d < INF:
		return best_p
	# All 4 neighboring tiles are also solid (e.g., landing mid-water next to a wall):
	# stay in place so void-respawn rescues Wick instead of shoving Wick into a wall tile.
	return center


static func can_place_rect_world(region: LxRegionLoader, rect: Rect2, ignore_id: String) -> bool:
	if region.width <= 0 or region.height <= 0 or not rect.has_area():
		return false
	var b: Rect2 = region.bounds
	if rect.position.x < b.position.x or rect.position.y < b.position.y or rect.end.x > b.end.x or rect.end.y > b.end.y:
		return false
	var eps: float = 0.25
	var x0: float = rect.position.x + eps; var x1: float = rect.end.x - eps; var xm: float = (x0 + x1) * 0.5
	var y0: float = rect.position.y + eps; var y1: float = rect.end.y - eps; var ym: float = (y0 + y1) * 0.5
	for pt: Vector2 in [
		Vector2(x0, y0), Vector2(xm, y0), Vector2(x1, y0),
		Vector2(x0, ym), Vector2(xm, ym), Vector2(x1, ym),
		Vector2(x0, y1), Vector2(xm, y1), Vector2(x1, y1),
	]:
		var ttype: String = region.tile_at(pt)
		if region.is_solid_tile(ttype, false, false) and not region._is_tile_supported(ttype, pt):
			return false
	for it: LxInteractable in region.get_interactables():
		if it != null and it.is_solid() and (ignore_id.is_empty() or it.id != ignore_id):
			var srect: Rect2 = it.get_solid_rect()
			if srect.has_area() and rect.intersects(srect):
				return false
	return true


static func clear_view_world(region: LxRegionLoader, a: Vector2, b: Vector2, skip_item: LxInteractable = null) -> bool:
	var dist: float = a.distance_to(b)
	if dist <= 1.0:
		return true
	var steps: int = maxi(1, int(ceil(dist / 4.0)))
	var seg_rect := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))).grow(1.0)
	var blockers: Array[Rect2] = []
	for it: LxInteractable in region.get_interactables():
		if it != null and it != skip_item and it.blocks_sight():
			var srect: Rect2 = it.get_solid_rect()
			if srect.size.x > 0.0 and srect.size.y > 0.0 and srect.intersects(seg_rect):
				blockers.append(srect)
	var inv_steps: float = 1.0 / float(steps)
	var has_blockers: bool = not blockers.is_empty()
	var ts: float = float(region.tile_size)
	var rw: int = region.width
	var rh: int = region.height
	var rgrid: Array[PackedStringArray] = region.grid
	var inv_ts: float = (1.0 / ts) if ts > 0.0 else 0.0
	for i: int in range(1, steps):
		var pt: Vector2 = a.lerp(b, float(i) * inv_steps)
		var tt: String = "void"
		if inv_ts > 0.0:
			var tx: int = int(floorf(pt.x * inv_ts))
			var ty: int = int(floorf(pt.y * inv_ts))
			if tx >= 0 and ty >= 0 and tx < rw and ty < rh:
				tt = rgrid[ty][tx]
		if LxMapFormat.blocks_sight_tile(tt):
			return false
		if has_blockers:
			for sr: Rect2 in blockers:
				if sr.has_point(pt):
					return false
	return true


static func push_circle_out_of_rect(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	var delta: Vector2 = center - closest
	var dist_sq: float = delta.length_squared()
	if dist_sq >= radius * radius:
		return center
	if dist_sq > 0.0001:
		var d: float = sqrt(dist_sq)
		return center + (delta / d) * (radius - d)
	var dl: float = center.x - rect.position.x; var dr: float = rect.end.x - center.x
	var dt_: float = center.y - rect.position.y; var db: float = rect.end.y - center.y
	var m: float = minf(minf(dl, dr), minf(dt_, db))
	if m == dl: return Vector2(rect.position.x - radius, center.y)
	if m == dr: return Vector2(rect.end.x + radius, center.y)
	return Vector2(center.x, rect.position.y - radius) if m == dt_ else Vector2(center.x, rect.end.y + radius)
