class_name LxSignalConduits
extends Node2D
## Carved floor-rune signal conduits linking switches/braziers to doors/bridges
## and nearby paired blue portals (z_index = -6, strictly 20 Last Light colours).

const PAL: Dictionary = LxInteractable.PAL
const MAX_LINK_DIST: float = 260.0
const MAX_PORTAL_DIST: float = 220.0
const MAX_OPTICAL_DIST: float = 170.0
const GRID_SNAP: float = 8.0
const SAMPLE_STEP: float = 2.0
const INLAY_STEP: float = 10.0
const PULSE_HZ: float = 10.0
const PULSE_SPEED: float = 68.0
const PULSE_PAD: float = 28.0

class FloorRun:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var d0: float = 0.0
	var d1: float = 0.0

class Conduit:
	var src: LxInteractable = null
	var dst: LxInteractable = null
	var is_blue: bool = false
	var is_portal: bool = false
	var runs: Array[FloorRun] = []
	var total_len: float = 0.0
	var powered: bool = false
	var opened: bool = false

class OpticalChevron:
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2i = Vector2i.RIGHT

var _conduits: Array[Conduit] = []
var _chevrons: Array[OpticalChevron] = []
var _clock: float = 0.0
var _last_step: int = -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -6

func clear() -> void:
	_conduits.clear(); _chevrons.clear(); _clock = 0.0; _last_step = -1
	queue_redraw()

func rebuild(region: LxRegionLoader) -> void:
	_conduits.clear(); _chevrons.clear(); _clock = 0.0; _last_step = -1
	if region == null:
		queue_redraw(); return
	var seen: Dictionary = {}
	var by_pair: Dictionary = {}
	for it: LxInteractable in region.get_interactables():
		if it == null or not is_instance_valid(it): continue
		if it.kind == "switch_eye" or it.kind == "brazier":
			_collect_switch_links(region, it, seen)
		elif it.kind == "blue_portal":
			_collect_portal_link(region, it, seen, by_pair)
	_collect_optical_chevrons(region)
	queue_redraw()

func _collect_switch_links(region: LxRegionLoader, src: LxInteractable, seen: Dictionary) -> void:
	var tids: Array[String] = []
	var single: String = str(src.props.get("target_id", "")).strip_edges()
	if not single.is_empty(): tids.append(single)
	var multi: Variant = src.props.get("target_ids", [])
	if multi is Array:
		for raw: Variant in (multi as Array):
			var tid: String = str(raw).strip_edges()
			if not tid.is_empty() and not tids.has(tid): tids.append(tid)
	var is_blue: bool = (src is LxSwitchEye and (src as LxSwitchEye).requires_prism) or bool(src.props.get("requires_blue", false))
	for tid: String in tids:
		var dst: LxInteractable = region.find_interactable(tid)
		if dst == null or not (dst is LxDoor): continue
		var door: LxDoor = dst as LxDoor
		if door.door_type != "switch_door" and door.door_type != "bridge_platform": continue
		var dist: float = src.pos.distance_to(dst.pos)
		var key: String = "sw:%s->%s" % [src.id, dst.id]
		if dist <= 8.0 or dist > MAX_LINK_DIST or seen.has(key): continue
		seen[key] = true
		_add_conduit(region, src, dst, is_blue, false)

func _collect_portal_link(region: LxRegionLoader, src: LxInteractable, seen: Dictionary, by_pair: Dictionary) -> void:
	var dst: LxInteractable = null
	var tpid: String = (src as LxBluePortal).target_portal_id if src is LxBluePortal else ""
	if tpid.is_empty(): tpid = str(src.props.get("target_portal_id", "")).strip_edges()
	if not tpid.is_empty():
		var found: LxInteractable = region.find_interactable(tpid)
		if found is LxBluePortal: dst = found
	if dst == null:
		var pid: String = str(src.props.get("pair_id", "")).strip_edges()
		if not pid.is_empty():
			if by_pair.has(pid): dst = by_pair[pid] as LxInteractable
			else: by_pair[pid] = src; return
	if dst == null or dst == src: return
	var dist: float = src.pos.distance_to(dst.pos)
	var key: String = "pt:%s<->%s" % ([src.id, dst.id] if src.id < dst.id else [dst.id, src.id])
	if dist <= 8.0 or dist > MAX_PORTAL_DIST or seen.has(key): return
	seen[key] = true
	_add_conduit(region, src, dst, true, true)

func _add_conduit(region: LxRegionLoader, src: LxInteractable, dst: LxInteractable, is_blue: bool, is_portal: bool) -> void:
	var c := Conduit.new()
	c.src = src; c.dst = dst; c.is_blue = is_blue; c.is_portal = is_portal
	_build_masked_path(region, src.pos, dst.pos, c)
	if c.runs.is_empty(): return
	c.powered = _is_source_powered(src, dst, is_portal)
	c.opened = _is_target_opened(dst)
	_conduits.append(c)

func _build_masked_path(region: LxRegionLoader, a: Vector2, b: Vector2, out_c: Conduit) -> void:
	var p0: Vector2 = a.round()
	var p1: Vector2 = b.round()
	var cands: Array[PackedVector2Array] = []
	if absf(p1.x - p0.x) <= 4.0 or absf(p1.y - p0.y) <= 4.0:
		cands.append(PackedVector2Array([p0, p1]))
	else:
		var sx: float = roundf((p0.x + p1.x) * 0.5 / GRID_SNAP) * GRID_SNAP
		var sy: float = roundf((p0.y + p1.y) * 0.5 / GRID_SNAP) * GRID_SNAP
		cands.append(PackedVector2Array([p0, Vector2(p1.x, p0.y), p1]))
		cands.append(PackedVector2Array([p0, Vector2(p0.x, p1.y), p1]))
		cands.append(PackedVector2Array([p0, Vector2(sx, p0.y), Vector2(sx, p1.y), p1]))
		cands.append(PackedVector2Array([p0, Vector2(p0.x, sy), Vector2(p1.x, sy), p1]))
	var best_walk: float = -1.0
	for poly: PackedVector2Array in cands:
		var runs: Array[FloorRun] = []
		var stats: Vector2 = _mask_polyline_to_floor(region, poly, runs)
		if stats.x > best_walk + 4.0:
			best_walk = stats.x; out_c.runs = runs; out_c.total_len = stats.y

func _mask_polyline_to_floor(region: LxRegionLoader, poly: PackedVector2Array, out_runs: Array[FloorRun]) -> Vector2:
	var walk_len: float = 0.0
	var accum_d: float = 0.0
	for i: int in range(poly.size() - 1):
		var sa: Vector2 = poly[i]
		var sb: Vector2 = poly[i + 1]
		var slen: float = sa.distance_to(sb)
		if slen < 1.0: continue
		var steps: int = maxi(1, int(ceilf(slen / SAMPLE_STEP)))
		var in_run: bool = false
		var r_a: Vector2 = sa
		var r_b: Vector2 = sa
		var r_d0: float = accum_d
		var r_d1: float = accum_d
		for s: int in range(steps + 1):
			var t: float = float(s) / float(steps)
			var pt: Vector2 = sa.lerp(sb, t)
			var d_now: float = accum_d + slen * t
			var tt: String = region.tile_at(pt)
			if tt == "ground" or tt == "path":
				if not in_run:
					in_run = true; r_a = pt.round(); r_d0 = d_now
				r_b = pt.round(); r_d1 = d_now
			elif in_run:
				walk_len += _push_run(out_runs, r_a, r_b, r_d0, r_d1); in_run = false
		if in_run:
			walk_len += _push_run(out_runs, r_a, r_b, r_d0, r_d1)
		accum_d += slen
	return Vector2(walk_len, accum_d)

func _push_run(out_runs: Array[FloorRun], a: Vector2, b: Vector2, d0: float, d1: float) -> float:
	if d1 - d0 < 3.0: return 0.0
	var run := FloorRun.new()
	run.a = a; run.b = b; run.d0 = d0; run.d1 = d1
	out_runs.append(run)
	return d1 - d0

func _is_source_powered(src: LxInteractable, dst: LxInteractable, is_portal: bool) -> bool:
	if src == null or not is_instance_valid(src): return false
	if src is LxSwitchEye: return (src as LxSwitchEye).activated
	if src is LxBrazier: return (src as LxBrazier).lit
	if is_portal and src is LxBluePortal:
		return (src as LxBluePortal).powered or (dst is LxBluePortal and is_instance_valid(dst) and (dst as LxBluePortal).powered)
	return false

func _is_target_opened(dst: LxInteractable) -> bool:
	return dst is LxDoor and is_instance_valid(dst) and (dst as LxDoor).opened

func tick(dt: float) -> void:
	if _conduits.is_empty(): return
	_clock += dt
	var changed: bool = false
	var active_now: bool = false
	for c: Conduit in _conduits:
		var p_now: bool = _is_source_powered(c.src, c.dst, c.is_portal)
		var o_now: bool = _is_target_opened(c.dst)
		if p_now != c.powered or o_now != c.opened:
			c.powered = p_now; c.opened = o_now; changed = true
		if p_now or o_now: active_now = true
	var step: int = int(floorf(_clock * PULSE_HZ))
	if changed or (active_now and step != _last_step):
		_last_step = step; queue_redraw()

func _draw() -> void:
	if _conduits.is_empty() and _chevrons.is_empty(): return
	var groove_col: Color = Color(PAL["night"] as Color, 0.42)
	var inlay_gold: Color = PAL["dusk"] as Color
	var inlay_blue: Color = PAL["deep"] as Color
	var speed: float = PULSE_SPEED * (0.65 if LxHudFx.flash_reduced() else 1.0)
	var stepped_t: float = floorf(_clock * PULSE_HZ) / PULSE_HZ
	for c: Conduit in _conduits:
		var lit: bool = c.powered or c.opened
		var inlay_col: Color = inlay_blue if c.is_blue else inlay_gold
		var chan_col: Color = Color((PAL["sky"] if c.is_blue else PAL["apricot"]) as Color, 0.55)
		for r: FloorRun in c.runs:
			draw_line(r.a, r.b, groove_col, 2.0, false)
			if lit:
				draw_line(r.a, r.b, chan_col, 1.0, false)
			else:
				var slen: float = r.a.distance_to(r.b)
				var d_in: float = 5.0
				while d_in < slen - 2.0:
					draw_rect(Rect2(r.a.lerp(r.b, d_in / slen).round(), Vector2.ONE), inlay_col)
					d_in += INLAY_STEP
		if not lit: continue
		var bead_d: float = fposmod(stepped_t * speed, maxf(1.0, c.total_len) + PULSE_PAD)
		var bead_outer: Color = (PAL["ice"] if c.is_blue else PAL["gold"]) as Color
		var bead_core: Color = PAL["cream"] as Color
		for r: FloorRun in c.runs:
			if bead_d >= r.d0 and bead_d <= r.d1 and r.d1 > r.d0:
				var bp: Vector2 = r.a.lerp(r.b, (bead_d - r.d0) / (r.d1 - r.d0)).round()
				draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), bead_outer)
				draw_rect(Rect2(bp, Vector2.ONE), bead_core)
				break
	_draw_optical_chevrons()

func _collect_optical_chevrons(region: LxRegionLoader) -> void:
	var occ_tiles: Dictionary = {}
	for c: Conduit in _conduits:
		for r: FloorRun in c.runs:
			var slen: float = r.a.distance_to(r.b)
			var steps: int = maxi(1, int(ceilf(slen / 4.0)))
			for si: int in range(steps + 1):
				var p: Vector2 = r.a.lerp(r.b, float(si) / float(steps))
				occ_tiles[Vector2i(int(floorf(p.x / 16.0)), int(floorf(p.y / 16.0)))] = true
	var items: Array[LxInteractable] = region.get_interactables()
	for it: LxInteractable in items:
		if it == null or not is_instance_valid(it): continue
		if not (it is LxMirror or it.kind == "mirror" or it.kind == "blue_transformer"): continue
		var best_tgt: LxInteractable = null
		var best_d: float = MAX_OPTICAL_DIST + 0.01
		for tgt: LxInteractable in items:
			if tgt == null or not is_instance_valid(tgt) or tgt == it: continue
			if tgt.kind != "switch_eye" and tgt.kind != "blue_portal": continue
			var d: float = it.pos.distance_to(tgt.pos)
			if d > 16.0 and d < best_d:
				best_d = d; best_tgt = tgt
		if best_tgt == null: continue
		var axis: Vector2 = (best_tgt.pos - it.pos).normalized()
		var sdir: Vector2i = _snap_dir8(axis)
		var dists: Array[float] = [16.0, 28.0]
		for di: int in range(dists.size()):
			var d_off: float = dists[di]
			var pt: Vector2 = (it.pos + axis * d_off).round()
			if not _is_walkable_floor(region, pt) and di == 1:
				pt = (it.pos + axis * 22.0).round()
			if not _is_walkable_floor(region, pt): continue
			var tk := Vector2i(int(floorf(pt.x / 16.0)), int(floorf(pt.y / 16.0)))
			if occ_tiles.has(tk): continue
			var ch := OpticalChevron.new()
			ch.pos = pt; ch.dir = sdir
			_chevrons.append(ch)

func _is_walkable_floor(region: LxRegionLoader, pt: Vector2) -> bool:
	var tt: String = region.tile_at(pt)
	return tt == "ground" or tt == "path"

static func _snap_dir8(v: Vector2) -> Vector2i:
	var idx: int = int(posmod(roundi(v.angle() / (PI * 0.25)), 8))
	match idx:
		0: return Vector2i(1, 0)
		1: return Vector2i(1, 1)
		2: return Vector2i(0, 1)
		3: return Vector2i(-1, 1)
		4: return Vector2i(-1, 0)
		5: return Vector2i(-1, -1)
		6: return Vector2i(0, -1)
		_: return Vector2i(1, -1)

func _draw_optical_chevrons() -> void:
	var c_groove: Color = Color(PAL["night"] as Color, 0.45)
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	for ch: OpticalChevron in _chevrons:
		var p: Vector2 = ch.pos
		var dx: float = float(ch.dir.x)
		var dy: float = float(ch.dir.y)
		draw_rect(Rect2(p, Vector2.ONE), c_groove)
		if ch.dir.x == 0 or ch.dir.y == 0:
			var px: float = -dy
			var py: float = dx
			draw_rect(Rect2(p + Vector2(dx, dy), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(px, py), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(-px, -py), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(-dx + px, -dy + py), Vector2.ONE), c_dusk)
			draw_rect(Rect2(p + Vector2(-dx - px, -dy - py), Vector2.ONE), c_dusk)
		else:
			draw_rect(Rect2(p + Vector2(dx, dy), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(dx, 0.0), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(0.0, dy), Vector2.ONE), c_gold)
			draw_rect(Rect2(p + Vector2(-dx, dy), Vector2.ONE), c_dusk)
			draw_rect(Rect2(p + Vector2(dx, -dy), Vector2.ONE), c_dusk)
