class_name LxVisualTeachingFx
extends Node2D
## Visual-first diegetic teaching FX across Islands 2..8 (z_index = -4, strictly 20 Last Light colours).
## Strictly excludes Island 1. Zero per-frame allocations in _draw(); all caches precomputed in rebuild/configure.

const PAL: Dictionary = LxPalette.PAL
const PULSE_HZ: float = 10.0
const HALF_W: float = 196.0
const HALF_H: float = 124.0
const PHANTOM_NEAR_SQ: float = 18496.0 # 136 px
const OWL_NEAR_SQ: float = 19600.0 # 140 px

var _region: LxRegionLoader = null
var _island_id: int = 0
var _region_id: String = ""
var _is_dungeon: bool = false
var _clock: float = 0.0
var _last_step: int = -1
var _cam_center: Vector2 = Vector2.ZERO
var _last_cam: Vector2 = Vector2(-99999.0, -99999.0)
var _has_medallion: bool = false
var _medallion_pos: Vector2 = Vector2(400.0, 208.0)
var _phantom_tiles: PackedVector2Array = PackedVector2Array()
var _guides: Array[Dictionary] = []
var _fans: Array[Dictionary] = []
var _glides: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _leylines: Array[Dictionary] = []
var _oct_pts: PackedVector2Array = PackedVector2Array([
	Vector2(4.0, -8.0), Vector2(8.0, -4.0), Vector2(8.0, 4.0), Vector2(4.0, 8.0),
	Vector2(-4.0, 8.0), Vector2(-8.0, 4.0), Vector2(-8.0, -4.0), Vector2(-4.0, -8.0),
])

func _ready() -> void: texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; z_index = -4
func configure(region: LxRegionLoader) -> void: rebuild(region)

func clear() -> void:
	_region = null; _island_id = 0; _region_id = ""; _is_dungeon = false
	_clock = 0.0; _last_step = -1; _has_medallion = false; _phantom_tiles = PackedVector2Array()
	_guides.clear(); _fans.clear(); _glides.clear(); _rings.clear(); _leylines.clear(); queue_redraw()

func rebuild(region: LxRegionLoader) -> void:
	clear()
	if region == null or region.current_island_id <= 1: return
	_region = region; _island_id = region.current_island_id
	_region_id = region.current_region_id; _is_dungeon = region.is_dungeon
	_cam_center = region.spawn_pos if region.spawn_pos != Vector2.ZERO else region.bounds.get_center()
	_last_cam = _cam_center
	_cache_phantom_tiles(region)
	_build_island_setpieces(region)
	queue_redraw()

func tick(dt: float, cam_center: Vector2) -> void:
	if _island_id <= 1 or _region == null: return
	_cam_center = cam_center; _clock += maxf(0.0, dt)
	var hz: float = (PULSE_HZ * 0.5) if LxHudFx.flash_reduced() else PULSE_HZ
	var step: int = int(floorf(_clock * hz))
	if step != _last_step or _cam_center.distance_squared_to(_last_cam) >= 4.0:
		_last_step = step; _last_cam = _cam_center; queue_redraw()

func _cache_phantom_tiles(region: LxRegionLoader) -> void:
	if region.width <= 0 or region.height <= 0: return
	var ts: float = float(region.tile_size)
	for ty: int in range(region.height):
		var row: PackedStringArray = region.grid[ty]
		for tx: int in range(region.width):
			if row[tx] == "phantom":
				_phantom_tiles.append(Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts))

func _build_island_setpieces(region: LxRegionLoader) -> void:
	match "%d:%s" % [_island_id, _region_id]:
		"2:overworld":
			_add_fan(Vector2(296, 200), Vector2.RIGHT, Vector2.RIGHT, false, "switch_eye_2_1")
			_add_guide(PackedVector2Array([Vector2(264, 200), Vector2(296, 200)]), 0, "apricot", "gold", "cream", "switch_eye_2_1")
			_add_guide(PackedVector2Array([Vector2(296, 200), Vector2(376, 200)]), 0, "sky", "ice", "cream", "switch_eye_2_1")
		"2:lighthouse_r3":
			_add_fan(Vector2(200, 120), Vector2.RIGHT, (Vector2(328, 56) - Vector2(200, 120)).normalized(), true, "lh_r3_cleared")
		"2:lighthouse_r5":
			_add_fan(Vector2(120, 136), Vector2.RIGHT, Vector2.RIGHT, true, "lh_r5_prism_solved")
			_add_fan(Vector2(136, 184), Vector2.RIGHT, (Vector2(264, 88) - Vector2(136, 184)).normalized(), false, "lh_r5_bridge_open")
			_add_fan(Vector2(312, 184), Vector2.RIGHT, (Vector2(360, 56) - Vector2(312, 184)).normalized(), false, "lh_r5_prism_solved")
			_add_guide(PackedVector2Array([Vector2(136, 184), Vector2(264, 88)]), 0, "sky", "ice", "cream", "lh_r5_bridge_open")
			_add_guide(PackedVector2Array([Vector2(312, 184), Vector2(360, 56)]), 0, "sky", "ice", "cream", "lh_r5_prism_solved")
		"2:lighthouse_r7":
			_add_guide(PackedVector2Array([Vector2(120, 184), Vector2(184, 72)]), 0, "sky", "ice", "cream", "lh_r7_portal_lit")
			_add_guide(PackedVector2Array([Vector2(296, 168), Vector2(392, 104)]), 0, "sky", "ice", "cream", "lh_r7_gallery_open")
		"3:oak_r5":
			_add_ring(Vector2(136, 104), 0, 11.0, Vector2.RIGHT, "oak_r5_beam_solved", "shrine_beam")
			_add_guide(PackedVector2Array([Vector2(120, 104), Vector2(184, 104), Vector2(248, 104), Vector2(312, 104)]), 1, "jade", "gold", "cream", "oak_r5_beam_solved")
			_add_guide(PackedVector2Array([Vector2(336, 120), Vector2(336, 152)]), 1, "apricot", "gold", "cream", "bramble_oak_r5_cache")
		"3:oak_r7":
			_add_guide(PackedVector2Array([Vector2(200, 152), Vector2(200, 72), Vector2(248, 72), Vector2(280, 72), Vector2(312, 72)]), 2, "sky", "ice", "lime", "oak_r7_loom_open", "", false, 1)
			_add_ring(Vector2(200, 72), 7, 8.0, Vector2.RIGHT, "oak_r7_loom_open")
		"3:overworld":
			_add_ring(Vector2(464, 760), 6, 12.0, Vector2.RIGHT, "bramble_3_shortcut_east")
			_add_ring(Vector2(224, 488), 6, 12.0, Vector2.UP, "bramble_3_shortcut_canopy")
		"4:conservatory_r5":
			_add_glide(Vector2(124, 112), Vector2(196, 112), true, Vector2(152, 104), Vector2(168, 124), true, Vector2(160, 112))
			_add_glide(Vector2(284, 112), Vector2(356, 112), true, Vector2(312, 104), Vector2(328, 124), true, Vector2(320, 112))
			_add_glide(Vector2(124, 208), Vector2(180, 208))
			_add_glide(Vector2(252, 208), Vector2(356, 208))
		"4:conservatory_r2", "4:overworld":
			var centers: PackedVector2Array = PackedVector2Array()
			var bridges: Array[Rect2] = _collect_bridge_rects(region)
			_scan_lagoon_gaps(region, true, centers, bridges); _scan_lagoon_gaps(region, false, centers, bridges)
		"5:orrery_r2":
			_add_guide(PackedVector2Array([Vector2(176, 108), Vector2(176, 64)]), 4, "apricot", "gold", "cream", "cracked_o5_r2")
		"5:orrery_r5":
			_add_ring(Vector2(112, 88), 1, 13.0, Vector2.RIGHT, "shrine_lens")
			_add_ring(Vector2(248, 120), 2, 78.0, Vector2.RIGHT, "shrine_lens")
		"5:orrery_r7":
			_add_ring(Vector2(304, 184), 2, 78.0, Vector2.LEFT, "shrine_lens")
			_add_ring(Vector2(152, 112), 2, 78.0, Vector2.DOWN, "shrine_lens")
		"6:kiln_r5":
			_add_guide(PackedVector2Array([Vector2(200, 104), Vector2(272, 120)]), 1, "coral", "gold", "cream", "seal_kiln_r5")
			_add_ring(Vector2(272, 120), 3, 76.0, Vector2.RIGHT, "seal_kiln_r5", "shrine_sunflare")
		"6:kiln_r7":
			_add_guide(PackedVector2Array([Vector2(232, 184), Vector2(232, 88)]), 0, "sky", "ice", "cream", "switch_eye_kiln_r7")
		"7:spire_r5":
			_add_guide(PackedVector2Array([Vector2(120, 168), Vector2(168, 56)]), 0, "sky", "ice", "cream", "switch_eye_spire_r5_west")
			_add_guide(PackedVector2Array([Vector2(120, 168), Vector2(248, 136), Vector2(312, 152), Vector2(440, 72)]), 1, "sky", "ice", "cream", "switch_eye_spire_r5_east", "bramble_spire_r5_baffle")
			_add_ring(Vector2(392, 200), 4, 15.0, Vector2.UP, "spire_r5_portal_lit")
		"7:spire_r7":
			_add_guide(PackedVector2Array([Vector2(104, 104), Vector2(184, 40)]), 3, "sky", "ice", "cream", "spire_r7_terrace_portal", "", true)
			_add_guide(PackedVector2Array([Vector2(184, 168), Vector2(232, 72), Vector2(344, 40)]), 0, "sky", "ice", "cream", "switch_eye_spire_r7_a")
		"8:overworld":
			_has_medallion = true
			_add_leyline(region, PackedVector2Array([Vector2(88, 804), Vector2(312, 804), Vector2(312, 696), Vector2(360, 696), Vector2(360, 612), Vector2(404, 612), Vector2(404, 456), Vector2(396, 456), Vector2(396, 184)]), "sky", "ice", "beacon_8_1")
			_add_leyline(region, PackedVector2Array([Vector2(632, 504), Vector2(408, 504), Vector2(408, 328), Vector2(404, 328), Vector2(404, 184)]), "jade", "lime", "beacon_8_2")
			_add_leyline(region, PackedVector2Array([Vector2(136, 312), Vector2(400, 312), Vector2(400, 184)]), "coral", "apricot", "beacon_8_3")
		"8:sanctum_r1":
			_add_guide(PackedVector2Array([Vector2(120, 88), Vector2(360, 168)]), 3, "sky", "ice", "cream", "sanctum_r1_cloister_portal", "", true)
			_add_guide(PackedVector2Array([Vector2(232, 232), Vector2(120, 88)]), 0, "sky", "ice", "cream", "sanctum_r1_cloister_portal")
		"8:sanctum_r5":
			_add_guide(PackedVector2Array([Vector2(56, 216), Vector2(208, 104)]), 3, "coral", "apricot", "cream", "brazier_sanctum_r5_west", "", true)
			_add_guide(PackedVector2Array([Vector2(440, 152), Vector2(208, 104)]), 3, "sky", "ice", "cream", "switch_eye_sanctum_r5_blue", "", true)
			_add_guide(PackedVector2Array([Vector2(208, 104), Vector2(208, 72), Vector2(208, 24)]), 4, "gold", "cream", "cream", "keepers_flame_8", "", true)
		"8:sanctum_r6":
			_add_guide(PackedVector2Array([Vector2(192, 304), Vector2(264, 248), Vector2(264, 168), Vector2(296, 72)]), 5, "plum", "wine", "gold", "boss_the_hush_defeated", "", true)
			_add_ring(Vector2(168, 200), 5, 13.0, Vector2.RIGHT, "boss_the_hush_defeated")
			_add_ring(Vector2(360, 136), 5, 13.0, Vector2.LEFT, "boss_the_hush_defeated")

func _add_guide(pts: PackedVector2Array, kind: int, ca: String, cb: String, chi: String, flag: String = "", extra: String = "", inv: bool = false, split: int = 0) -> void:
	if pts.size() < 2: return
	var cum := PackedFloat32Array([0.0]); var acc: float = 0.0; var mn: Vector2 = pts[0]; var mx: Vector2 = pts[0]
	for i: int in range(1, pts.size()):
		acc += pts[i - 1].distance_to(pts[i]); cum.append(acc)
		mn = Vector2(minf(mn.x, pts[i].x), minf(mn.y, pts[i].y)); mx = Vector2(maxf(mx.x, pts[i].x), maxf(mx.y, pts[i].y))
	_guides.append({"pts": pts, "cum": cum, "len": maxf(1.0, acc), "kind": kind, "ca": ca, "cb": cb, "chi": chi, "flag": flag, "extra": extra, "inv": inv, "split": split, "bbox": Rect2(mn - Vector2(16.0, 16.0), (mx - mn) + Vector2(32.0, 32.0))})

func _add_fan(p: Vector2, idir: Vector2, odir: Vector2, is_fan: bool, flag: String) -> void: _fans.append({"pos": p, "in": idir, "out": odir, "fan": is_fan, "flag": flag})
func _add_ring(p: Vector2, kind: int, rad: float, dir: Vector2, flag: String = "", extra: String = "") -> void: _rings.append({"pos": p, "kind": kind, "rad": rad, "dir": dir, "flag": flag, "extra": extra})

func _add_glide(a: Vector2, b: Vector2, lil: bool = false, la: Vector2 = Vector2.ZERO, lb: Vector2 = Vector2.ZERO, upd: bool = false, up: Vector2 = Vector2.ZERO) -> void:
	var gl: float = maxf(1.0, a.distance_to(b)); var d: Vector2 = (b - a) / gl
	var mn := Vector2(minf(a.x, b.x) - 24.0, minf(a.y, b.y) - 24.0)
	_glides.append({"a": a, "b": b, "dir": d, "perp": Vector2(-d.y, d.x), "len": gl, "lil": lil, "la": la, "lb": lb, "upd": upd, "up": up, "bbox": Rect2(mn, Vector2(maxf(a.x, b.x) + 24.0, maxf(a.y, b.y) + 24.0) - mn)})

func _add_leyline(region: LxRegionLoader, poly: PackedVector2Array, ca: String, cb: String, bid: String) -> void:
	var ra_arr := PackedVector2Array(); var rb_arr := PackedVector2Array()
	var d0_arr := PackedFloat32Array(); var d1_arr := PackedFloat32Array()
	var acc: float = 0.0; var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for i: int in range(poly.size() - 1):
		var sa: Vector2 = poly[i]; var sb: Vector2 = poly[i + 1]; var slen: float = sa.distance_to(sb)
		if slen < 1.0: continue
		var steps: int = maxi(1, int(ceilf(slen / 4.0)))
		var in_r: bool = false; var ra: Vector2 = sa; var rb: Vector2 = sa; var d0: float = acc; var d1: float = acc
		for s: int in range(steps + 1):
			var t: float = float(s) / float(steps); var pt: Vector2 = sa.lerp(sb, t); var walk: bool = _is_walk(region.tile_at(pt))
			if walk:
				if not in_r: in_r = true; ra = pt.round(); d0 = acc + slen * t
				rb = pt.round(); d1 = acc + slen * t
			if in_r and (not walk or s == steps):
				if d1 - d0 >= 4.0:
					ra_arr.append(ra); rb_arr.append(rb); d0_arr.append(d0); d1_arr.append(d1)
					mn = Vector2(minf(mn.x, minf(ra.x, rb.x)), minf(mn.y, minf(ra.y, rb.y)))
					mx = Vector2(maxf(mx.x, maxf(ra.x, rb.x)), maxf(mx.y, maxf(ra.y, rb.y)))
				in_r = false
		acc += slen
	if ra_arr.size() > 0:
		_leylines.append({"ra": ra_arr, "rb": rb_arr, "d0": d0_arr, "d1": d1_arr, "len": maxf(1.0, acc), "ca": ca, "cb": cb, "bid": bid, "bbox": Rect2(mn - Vector2(12.0, 12.0), (mx - mn) + Vector2(24.0, 24.0))})

func _collect_bridge_rects(region: LxRegionLoader) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for it: LxInteractable in region.get_interactables():
		if it is LxDoor and is_instance_valid(it) and (it as LxDoor).door_type == "bridge_platform":
			var dr: LxDoor = it as LxDoor
			out.append(Rect2(dr.pos - dr.size * 0.5, dr.size).grow(24.0))
	return out

func _scan_lagoon_gaps(region: LxRegionLoader, horiz: bool, centers: PackedVector2Array, bridges: Array[Rect2]) -> void:
	if region.width < 6 or region.height < 6: return
	var ts: float = float(region.tile_size); var o_max: int = (region.height - 2) if horiz else (region.width - 2)
	var i_max: int = (region.width - 5) if horiz else (region.height - 5); var lim: int = region.width if horiz else region.height
	for o: int in range(2, o_max, 2):
		var i: int = 1
		while i < i_max and _glides.size() < 12:
			var t0: String = region.grid[o][i] if horiz else region.grid[i][o]
			var t1: String = region.grid[o][i + 1] if horiz else region.grid[i + 1][o]
			if _is_walk(t0) and _is_wet(t1):
				var sp: int = 0
				while i + 1 + sp < lim - 1 and sp <= 7 and _is_wet(region.grid[o][i + 1 + sp] if horiz else region.grid[i + 1 + sp][o]): sp += 1
				var te: String = (region.grid[o][i + 1 + sp] if horiz else region.grid[i + 1 + sp][o]) if (i + 1 + sp < lim) else ""
				if sp >= 4 and sp <= 6 and _is_walk(te):
					var a: Vector2 = Vector2((float(i) + 0.85) * ts, (float(o) + 0.5) * ts) if horiz else Vector2((float(o) + 0.5) * ts, (float(i) + 0.85) * ts)
					var b: Vector2 = Vector2((float(i + 1 + sp) + 0.15) * ts, (float(o) + 0.5) * ts) if horiz else Vector2((float(o) + 0.5) * ts, (float(i + 1 + sp) + 0.15) * ts)
					var mid: Vector2 = (a + b) * 0.5
					if not _near_bridge(a, mid, b, bridges) and _far_from_all(mid, centers, 4096.0): centers.append(mid); _add_glide(a, b)
				i += maxi(1, sp)
			else: i += 1

static func _near_bridge(a: Vector2, mid: Vector2, b: Vector2, rects: Array[Rect2]) -> bool:
	for r: Rect2 in rects:
		if r.has_point(mid) or r.has_point(a) or r.has_point(b): return true
	return false

static func _c(key: String, a: float = 1.0) -> Color: return Color(PAL[key] as Color, a)
static func _is_walk(tt: String) -> bool: return tt == "ground" or tt == "path" or tt == "bridge"
static func _is_wet(tt: String) -> bool: return tt == "water" or tt == "tide"
static func _far_from_all(p: Vector2, pts: PackedVector2Array, min_sq: float) -> bool:
	for o: Vector2 in pts:
		if p.distance_squared_to(o) < min_sq: return false
	return true

func _draw() -> void:
	if _island_id <= 1 or _region == null: return
	var fred: bool = LxHudFx.flash_reduced(); var hz: float = (PULSE_HZ * 0.5) if fred else PULSE_HZ
	var step: int = int(floorf(_clock * hz)); var st: float = float(step) / hz
	var cam_rect := Rect2(_cam_center.x - HALF_W, _cam_center.y - HALF_H, HALF_W * 2.0, HALF_H * 2.0)
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var wick_ok: bool = wick != null; var wick_pos: Vector2 = wick.global_position if wick_ok else _cam_center
	var ember_full: bool = wick_ok and wick.move_sunflare != null and wick.move_sunflare.unlocked and wick.ember >= wick.move_sunflare.get_ember_max() - 0.5
	for ll: Dictionary in _leylines:
		if cam_rect.intersects(ll["bbox"] as Rect2): _draw_leyline(ll, st, fred)
	if _has_medallion and cam_rect.has_point(_medallion_pos): _draw_medallion(st, fred)
	for gs: Dictionary in _glides:
		if cam_rect.intersects(gs["bbox"] as Rect2): _draw_glide(gs, st, fred)
	for g: Dictionary in _guides:
		if cam_rect.intersects(g["bbox"] as Rect2): _draw_guide(g, st, fred, ember_full)
	for f: Dictionary in _fans:
		if cam_rect.has_point(f["pos"] as Vector2): _draw_fan(f, step, fred)
	for r: Dictionary in _rings:
		var rp: Vector2 = r["pos"] as Vector2; var rr: float = float(r["rad"]) + 16.0
		if absf(rp.x - _cam_center.x) <= HALF_W + rr and absf(rp.y - _cam_center.y) <= HALF_H + rr: _draw_ring(r, st, step, fred, ember_full)
	if not _phantom_tiles.is_empty(): _draw_phantom_tiles(cam_rect, step, fred, wick_ok, wick_pos, wick)
	_draw_cloaked_owls(cam_rect, step, fred, wick_ok, wick_pos)
	if (_island_id == 6 or _island_id == 8) and not _is_dungeon: _draw_vent_chevrons(cam_rect, st, fred, wick)

func _draw_phantom_tiles(cam_rect: Rect2, step: int, fred: bool, wick_ok: bool, wick_pos: Vector2, wick: LxWick) -> void:
	var has_lens: bool = Lx.state != null and Lx.state.has_move("lens")
	var ml: LxMoveLens = wick.move_lens if wick != null else null
	var p_on: bool = ml != null and ml.is_pulse_active(); var p_r2: float = (ml.pulse_radius * ml.pulse_radius) if p_on else 0.0
	var a_on: bool = ml != null and ml.is_anchor_active() and wick.lantern != null
	var a_pos: Vector2 = wick.lantern.pos if a_on else Vector2.ZERO; var a_r2: float = (ml.hung_radius * ml.hung_radius) if a_on else 0.0
	var asc: float = 0.72 if fred else 1.0
	for i: int in range(_phantom_tiles.size()):
		var pt: Vector2 = _phantom_tiles[i]
		if not cam_rect.has_point(pt): continue
		if (p_on and pt.distance_squared_to(wick_pos) <= p_r2) or (a_on and pt.distance_squared_to(a_pos) <= a_r2): continue
		var near: bool = wick_ok and pt.distance_squared_to(wick_pos) <= PHANTOM_NEAR_SQ
		var ph: int = (int(pt.x) * 3 + int(pt.y) * 7) & 15; var tw: int = (step + ph) & 7; var flip: bool = ((step >> 2) + ph) % 2 == 0
		draw_rect(Rect2((pt + (Vector2(-5.0, -5.0) if flip else Vector2(-5.0, 4.0))).round(), Vector2.ONE), _c("ice" if (near and (has_lens or tw < 4)) else "sky", (0.86 if near else 0.58) * asc))
		draw_rect(Rect2((pt + (Vector2(4.0, 4.0) if flip else Vector2(4.0, -5.0))).round(), Vector2.ONE), _c("sky" if near else "deep", (0.72 if near else 0.48) * asc))
		if tw == 0 or (near and tw == 4): draw_rect(Rect2(pt.round(), Vector2.ONE), _c("cream" if (near and has_lens) else "ice", (0.84 if near else 0.54) * asc))
		var even_p: bool = (ph & 1) == 0; var ew: float = 3.0 if even_p else 2.0
		var ec: Color = _c("blue" if near else "deep", (0.55 if near else 0.36) * asc)
		draw_rect(Rect2((pt + Vector2(-2.0 if even_p else -1.0, -6.0)).round(), Vector2(ew, 1.0)), ec); draw_rect(Rect2((pt + Vector2(-1.0, 5.0)).round(), Vector2(ew, 1.0)), ec)

func _draw_cloaked_owls(cam_rect: Rect2, step: int, fred: bool, wick_ok: bool, wick_pos: Vector2) -> void:
	var ref_pos: Vector2 = wick_pos if wick_ok else _cam_center
	var c_ice: Color = _c("ice", 0.72 if fred else 0.92); var c_sky: Color = _c("sky", 0.45 if fred else 0.68)
	for e: LxEnemyBrain in _region.get_enemies():
		if e == null or not is_instance_valid(e) or not e.is_alive() or e.kind != "phantom_owl": continue
		if e is LxPhantomOwlBrain and (e as LxPhantomOwlBrain).revealed: continue
		if not cam_rect.has_point(e.pos) or e.pos.distance_squared_to(ref_pos) > OWL_NEAR_SQ: continue
		var p: Vector2 = (e.pos + Vector2(0.0, -4.0)).round()
		if (step % 6) != 0:
			draw_rect(Rect2(p + Vector2(-3.0, -2.0), Vector2(2.0, 1.0)), c_ice); draw_rect(Rect2(p + Vector2(1.0, -2.0), Vector2(2.0, 1.0)), c_ice)
			draw_rect(Rect2(p + Vector2(-3.0, -1.0), Vector2.ONE), c_sky); draw_rect(Rect2(p + Vector2(2.0, -1.0), Vector2.ONE), c_sky)
		for k: int in range(4):
			var a0: float = float(step) * 0.18 + float(k) * (PI * 0.5); draw_arc(p, 10.0, a0, a0 + 0.55, 4, c_sky, 1.0)

func _draw_fan(f: Dictionary, step: int, fred: bool) -> void:
	var calm: bool = _is_flag_active(str(f["flag"])); var asc: float = (0.42 if calm else 0.84) * (0.75 if fred else 1.0)
	var p: Vector2 = (f["pos"] as Vector2).round(); var idir: Vector2 = f["in"] as Vector2; var odir: Vector2 = f["out"] as Vector2
	var c_sky: Color = _c("sky", asc); var c_ice: Color = _c("ice", asc)
	draw_line((p - idir * 16.0).round(), (p - idir * 6.0).round(), _c("apricot", asc * 0.85), 1.0, false)
	draw_rect(Rect2((p - idir * (14.0 - float(step % 6))).round(), Vector2(2.0, 2.0)), _c("gold", asc))
	draw_line(p + Vector2(0.0, -4.0), p + Vector2(4.0, 0.0), c_ice, 1.0, false); draw_line(p + Vector2(4.0, 0.0), p + Vector2(0.0, 4.0), c_sky, 1.0, false)
	draw_line(p + Vector2(0.0, 4.0), p + Vector2(-4.0, 0.0), c_sky, 1.0, false); draw_line(p + Vector2(-4.0, 0.0), p + Vector2(0.0, -4.0), c_ice, 1.0, false)
	if bool(f["fan"]):
		for ri: int in range(-1, 2):
			var rd: Vector2 = odir.rotated(deg_to_rad(float(ri) * 18.0))
			draw_line((p + rd * 7.0).round(), (p + rd * 26.0).round(), c_sky if ri != 0 else c_ice, 1.0, false)
			draw_rect(Rect2((p + rd * (9.0 + float((step + ri + 2) % 8) * 2.2)).round(), Vector2.ONE), _c("cream", asc) if not calm else c_ice)
	else:
		draw_line((p + odir * 6.0).round(), (p + odir * 17.0).round(), c_sky, 1.0, false)
		draw_rect(Rect2((p + odir * (8.0 + float(step % 6) * 1.5)).round(), Vector2(2.0, 1.0)), c_ice)

func _draw_guide(g: Dictionary, st: float, fred: bool, ember_full: bool) -> void:
	var pts: PackedVector2Array = g["pts"] as PackedVector2Array; var kind: int = int(g["kind"])
	var flag_on: bool = _is_flag_active(str(g["flag"])); var extra_on: bool = _is_flag_active(str(g["extra"]))
	var ca_k: String = str(g["ca"]); var cb_k: String = str(g["cb"]); var chi_k: String = str(g["chi"]); var asc: float = 0.72 if fred else 1.0
	if kind == 0:
		var calm: bool = flag_on and not bool(g["inv"])
		var ca: Color = _c(ca_k, (0.36 if calm else 0.72) * asc)
		var cb: Color = _c(cb_k, (0.48 if calm else 0.95) * asc)
		for i: int in range(pts.size() - 1): _draw_beaded_line(pts[i], pts[i + 1], ca, Color(cb, minf(1.0, cb.a * (1.15 if (extra_on and i >= 1) else 1.0))), 8.0, st * (26.0 if fred else 42.0), not calm)
	elif kind == 1 or kind == 2:
		var is_kiln: bool = _region_id == "kiln_r5"
		if is_kiln and flag_on: return
		var beam_ok: bool = Lx.state != null and Lx.state.has_move("beam"); var sp_idx: int = int(g["split"])
		var c_a: Color = _c("jade" if flag_on else ("gold" if (ember_full and is_kiln) else ca_k), (0.40 if flag_on else (0.88 if (ember_full and is_kiln) else (0.78 if beam_ok else 0.62))) * asc)
		for i: int in range(pts.size() - 1):
			draw_line(pts[i].round(), pts[i + 1].round(), _c("night", 0.70), 3.0, false)
			draw_line(pts[i].round(), pts[i + 1].round(), _c("gold", c_a.a) if (kind == 2 and i < sp_idx) else c_a, 1.0, false)
		if not flag_on: _draw_bead(_sample_poly(pts, g["cum"] as PackedFloat32Array, float(g["len"]), fposmod(st * (52.0 if fred else 84.0), float(g["len"]) + 20.0)), _c("gold" if (ember_full and is_kiln) else cb_k, 0.90 * asc), PAL[chi_k] as Color)
	elif kind == 3:
		var lit: bool = flag_on if bool(g["inv"]) else not flag_on
		_draw_beaded_line(pts[0], pts[1], _c("gold" if (lit and _island_id == 8) else ca_k, (0.76 if lit else 0.44) * asc), _c("cream" if lit else cb_k, (0.90 if lit else 0.56) * asc), 10.0, st * (22.0 if fred else 36.0), true)
	elif kind == 4:
		if flag_on and not bool(g["inv"]): return
		var c_bg: Color = _c("night", 0.55)
		var c_m: Color = _c("cream" if flag_on else ca_k, (0.92 if flag_on else 0.78) * asc); var off: float = fposmod(st * (18.0 if fred else 30.0), 12.0)
		for i: int in range(pts.size() - 1):
			var sa: Vector2 = pts[i]; var sb: Vector2 = pts[i + 1]; var slen: float = maxf(1.0, sa.distance_to(sb))
			var dir: Vector2 = (sb - sa) / slen; var perp := Vector2(-dir.y, dir.x); var d: float = off
			while d < slen - 3.0:
				var p: Vector2 = (sa + dir * d).round()
				if not bool(g["inv"]): draw_line(p - dir * 2.0 + perp * 3.0 + Vector2(0.0, 1.0), p + Vector2(0.0, 1.0), c_bg, 1.0, false); draw_line(p - dir * 2.0 - perp * 3.0 + Vector2(0.0, 1.0), p + Vector2(0.0, 1.0), c_bg, 1.0, false)
				draw_line(p - dir * 2.0 + perp * 3.0, p, c_m, 1.0, false); draw_line(p - dir * 2.0 - perp * 3.0, p, c_m, 1.0, false); d += 12.0
	elif kind == 5:
		var c_line: Color = _c("gold" if flag_on else ca_k, (0.78 if flag_on else 0.50) * asc); var c_pip: Color = _c("cream" if flag_on else chi_k, (0.95 if flag_on else 0.72) * asc)
		var tlen: float = float(g["len"]); var cum: PackedFloat32Array = g["cum"] as PackedFloat32Array
		for i: int in range(pts.size() - 1): draw_line(pts[i].round(), pts[i + 1].round(), _c("night", 0.52), 4.0, false); draw_line(pts[i].round(), pts[i + 1].round(), c_line, 2.0 if flag_on else 1.0, false)
		var d0: float = fposmod(st * (38.0 if fred else 64.0), tlen)
		for k: int in range(3): _draw_bead(_sample_poly(pts, cum, tlen, fposmod(d0 + float(k) * (tlen / 3.0), tlen)), c_line, c_pip)

func _draw_bead(bp: Vector2, c_out: Color, c_in: Color) -> void:
	if bp.x > -9000.0: draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), c_out); draw_rect(Rect2(bp, Vector2.ONE), c_in)

func _draw_beaded_line(a: Vector2, b: Vector2, col_dim: Color, col_hi: Color, spacing: float, scroll: float, anim: bool) -> void:
	var slen: float = a.distance_to(b)
	if slen < 2.0: return
	var dir: Vector2 = (b - a) / slen; var d: float = 4.0 + (fposmod(scroll, spacing) if anim else 0.0); var idx: int = 0
	var c_bg: Color = _c("night", minf(0.86, col_dim.a + 0.16))
	while d < slen - 4.0:
		var p: Vector2 = (a + dir * d).round()
		draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), c_bg)
		var hi_mod: int = 2 if (_region != null and _is_wet(_region.tile_at(p))) else 3
		draw_rect(Rect2(p, Vector2(2.0, 1.0)), col_hi if (idx % hi_mod == 0) else col_dim); d += spacing; idx += 1

func _draw_glide(gs: Dictionary, st: float, fred: bool) -> void:
	var a: Vector2 = gs["a"] as Vector2; var b: Vector2 = gs["b"] as Vector2; var dir: Vector2 = gs["dir"] as Vector2; var perp: Vector2 = gs["perp"] as Vector2; var gl: float = float(gs["len"])
	var asc: float = (0.94 if (Lx.state != null and Lx.state.has_move("wings")) else 0.74) * (0.76 if fred else 1.0)
	var c_rose: Color = _c("rose", 0.78 * asc); var c_cream: Color = _c("cream", 0.92 * asc); var c_ice: Color = _c("ice", 0.72 * asc); var spd: float = 20.0 if fred else 34.0
	var rsz: Vector2 = Vector2(5.0, 1.0) if absf(dir.x) >= absf(dir.y) else Vector2(1.0, 5.0)
	for lane: int in range(-1, 2):
		var loff: Vector2 = perp * (float(lane) * 9.0)
		draw_line((a + loff + dir * 2.0).round(), (b + loff - dir * 2.0).round(), _c("ice" if lane == 1 else "rose", 0.28 * asc), 1.0, false)
		var d: float = fposmod(st * spd + float(lane + 1) * 4.0, 12.0)
		while d < gl - 5.0:
			draw_rect(Rect2((a + loff + dir * d + perp * roundf(sin(d * 0.14 + st * 2.5) * 1.4)).round(), rsz), c_cream if (lane == 0 and int(d) % 2 == 0) else (c_rose if lane != 1 else c_ice)); d += 12.0
	for end_i: int in range(2):
		var ep: Vector2 = (a - dir * 2.0) if end_i == 0 else (b + dir * 2.0); var ed: Vector2 = dir if end_i == 0 else -dir
		for k: int in range(2):
			var o: Vector2 = (ep + ed * float(k * 3)).round(); var lc: Color = c_cream if k == 1 else c_rose
			draw_line(o - ed * 2.0 + perp * 3.0, o, lc, 1.0, false); draw_line(o - ed * 2.0 - perp * 3.0, o, lc, 1.0, false)
	if bool(gs["lil"]):
		for li: int in range(2):
			var lp: Vector2 = (gs["la"] as Vector2) if li == 0 else (gs["lb"] as Vector2)
			var p: Vector2 = (lp + Vector2(0.0, 0.0 if fred else roundf(sin(st * 2.8 + float(li) * 0.9 + lp.x * 0.05)))).round()
			draw_rect(Rect2(p + Vector2(-3.0, -2.0), Vector2(6.0, 5.0)), PAL["pine"] as Color); draw_rect(Rect2(p + Vector2(-4.0, -1.0), Vector2(8.0, 3.0)), PAL["pine"] as Color)
			draw_rect(Rect2(p + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), PAL["jade"] as Color); draw_rect(Rect2(p + Vector2(-3.0, 0.0), Vector2(5.0, 1.0)), PAL["jade"] as Color)
			draw_rect(Rect2(p + Vector2(-2.0, -1.0), Vector2(2.0, 1.0)), PAL["lime"] as Color); draw_rect(Rect2(p + Vector2(2.0, 0.0), Vector2(2.0, 1.0)), PAL["deep"] as Color)
	if bool(gs["upd"]):
		var up: Vector2 = gs["up"] as Vector2; var rot: float = st * (1.2 if fred else 2.6)
		for k: int in range(8):
			var ang: float = rot + float(k) * (TAU / 8.0)
			draw_rect(Rect2((up + Vector2(cos(ang) * 14.0, sin(ang) * 10.0)).round(), Vector2(2.0, 1.0)), c_cream if (k == 0 or k == 4) else (c_rose if (k % 2 == 0) else c_ice))

func _draw_ring(r: Dictionary, st: float, step: int, fred: bool, ember_full: bool) -> void:
	var p: Vector2 = (r["pos"] as Vector2).round(); var kind: int = int(r["kind"]); var rad: float = float(r["rad"])
	var dir: Vector2 = r["dir"] as Vector2; var flag: String = str(r["flag"]); var extra: String = str(r["extra"]); var asc: float = 0.75 if fred else 1.0
	match kind:
		0: # oak_r5 inward-pulsing charge-focus stance pad
			var solved: bool = _is_flag_active(flag); var claimed: bool = _is_flag_active(extra) or (Lx.state != null and Lx.state.has_move("beam"))
			_draw_dotted_ring(p, 11.0 if solved else lerpf(13.0, 6.0, fposmod(st * (0.7 if fred else 1.25), 1.0)), _c("jade" if solved else ("gold" if claimed else "lime"), (0.45 if solved else 0.85) * asc), 12, st * 0.6)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), _c("cream" if (claimed and not solved) else "jade", 0.85 * asc))
		1: # orrery_r5 astrolabe pulse-stance ring
			var has_lens: bool = _is_flag_active(flag) or (Lx.state != null and Lx.state.has_move("lens"))
			var u: float = fposmod(st * (0.55 if fred else 0.95), 1.0); var c_sky: Color = _c("sky", (0.72 if has_lens else 0.52) * asc)
			_draw_dotted_ring(p, 11.0, c_sky, 12, st * 0.4); _draw_dotted_ring(p, lerpf(6.0, 22.0, u), _c("ice", (1.0 - u) * (0.85 if has_lens else 0.55) * asc), 16, -st * 0.5)
			draw_line((p + dir * 13.0).round(), (p + dir * 26.0).round(), c_sky, 1.0, false); draw_rect(Rect2((p + dir * (14.0 + u * 12.0)).round(), Vector2(2.0, 1.0)), PAL["cream"] as Color)
		2: # orrery_r5 / orrery_r7 78px Lantern-Anchor cradle rune
			var c_gold: Color = _c("gold", 0.84 * asc)
			for si: int in range(4):
				var sx: float = -1.0 if (si & 1) == 0 else 1.0; var sy: float = -1.0 if si < 2 else 1.0
				draw_line(p + Vector2(sx * 7.0, sy * 7.0), p + Vector2(sx * 4.0, sy * 7.0), c_gold, 1.0, false); draw_line(p + Vector2(sx * 7.0, sy * 7.0), p + Vector2(sx * 7.0, sy * 4.0), c_gold, 1.0, false)
			draw_arc(p, 3.0, PI, TAU, 6, _c("ice", 0.78 * asc), 1.0); draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(2.0, 3.0)), c_gold)
			_draw_dotted_ring(p, rad, _c("sky", 0.54 * asc), 28, st * (0.12 if fred else 0.25))
		3: # kiln_r5 Solar Detonation Focus Ring (r_inner=12, r_outer=76)
			if _is_flag_active(flag): return
			var claimed: bool = _is_flag_active(extra) or (Lx.state != null and Lx.state.has_move("sunflare"))
			var c_in: Color = _c("cream" if ember_full else ("gold" if claimed else "apricot"), 0.90 * asc)
			var c_out: Color = _c("gold" if ember_full else ("apricot" if claimed else "coral"), (0.88 if ember_full else (0.62 if claimed else 0.40)) * asc)
			_draw_dotted_ring(p, 12.0, c_in, 16, st * 0.5); draw_line(p + Vector2(-4.0, 0.0), p + Vector2(4.0, 0.0), c_in, 1.0, false); draw_line(p + Vector2(0.0, -4.0), p + Vector2(0.0, 4.0), c_in, 1.0, false)
			var rot: float = -st * (0.12 if fred else 0.24)
			for k: int in range(24):
				var a0: float = rot + float(k) * (TAU / 24.0)
				draw_arc(p, rad, a0, a0 + 0.09, 4, c_out, 1.0)
				if ember_full and (k % 6) == 0: draw_rect(Rect2((p + Vector2.from_angle(a0 + 0.045) * rad).round() - Vector2.ONE, Vector2(2.0, 2.0)), _c("cream", 0.92 * asc))
		4: # spire_r5 return portal moon-arc
			var ang: float = st * (0.6 if fred else 1.2)
			draw_arc(p, rad, ang, ang + PI * 0.85, 10, _c("cream" if _is_flag_active(flag) else "sky", 0.72 * asc), 1.0)
			draw_arc(p, rad - 3.0, ang + PI, ang + PI * 1.75, 8, _c("ice", 0.56 * asc), 1.0)
		5: _draw_dotted_ring(p, rad, _c("ice" if (step % 4 == 0) else "sky", 0.65 * asc), 8, 0.0) # sanctum_r6 transformer ticks
		6: # island 3 overworld bramble beam-return ticks
			if Lx.state == null or not Lx.state.has_move("beam") or _is_flag_active(flag): return
			var c_g: Color = _c("gold" if (step % 2 == 0) else "jade", 0.76 * asc)
			draw_line(p + Vector2(-10.0, 0.0), p + Vector2(-5.0, 0.0), c_g, 1.0, false); draw_line(p + Vector2(5.0, 0.0), p + Vector2(10.0, 0.0), c_g, 1.0, false); draw_rect(Rect2(p + Vector2(0.0, -10.0), Vector2(1.0, 4.0)), c_g)
		7: # oak_r7 octagonal push-socket pad at L-bend
			var solved: bool = _is_flag_active(flag); var sa: float = (0.42 if solved else 0.82) * asc
			var c_bg: Color = _c("night", 0.58); var c_g: Color = _c("jade" if solved else "gold", sa); var c_s: Color = _c("jade" if solved else "sky", sa)
			for oi: int in range(8):
				var qa: Vector2 = p + _oct_pts[oi]; var qb: Vector2 = p + _oct_pts[(oi + 1) & 7]
				draw_line(qa, qb, c_bg, 2.0, false); draw_line(qa, qb, c_g if (oi >= 2 and oi <= 5) else c_s, 1.0, false)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), _c("jade" if solved else ("cream" if (step % 4 == 0 and not fred) else "ice"), 0.86 * asc))

func _draw_leyline(ll: Dictionary, st: float, fred: bool) -> void:
	var lit: bool = Lx.state != null and Lx.state.lit_beacons.has(str(ll["bid"])); var asc: float = 0.76 if fred else 1.0
	var c_grv: Color = _c("night", 0.50); var c_main: Color = _c("gold" if lit else str(ll["ca"]), (0.78 if lit else 0.52) * asc); var c_hi: Color = _c("cream" if lit else str(ll["cb"]), (0.94 if lit else 0.68) * asc)
	var ra_arr: PackedVector2Array = ll["ra"] as PackedVector2Array; var rb_arr: PackedVector2Array = ll["rb"] as PackedVector2Array
	var d0_arr: PackedFloat32Array = ll["d0"] as PackedFloat32Array; var d1_arr: PackedFloat32Array = ll["d1"] as PackedFloat32Array
	var bead_d: float = fposmod(st * (44.0 if fred else 74.0), float(ll["len"]) + 28.0)
	for i: int in range(ra_arr.size()):
		var ra: Vector2 = ra_arr[i]; var rb: Vector2 = rb_arr[i]; var d0: float = d0_arr[i]; var d1: float = d1_arr[i]
		draw_line(ra, rb, c_grv, 3.0, false); draw_line(ra, rb, c_main, 1.0, false)
		if lit and bead_d >= d0 and bead_d <= d1 and d1 > d0: _draw_bead(ra.lerp(rb, (bead_d - d0) / (d1 - d0)).round(), c_main, c_hi)

func _draw_medallion(st: float, fred: bool) -> void:
	var p: Vector2 = _medallion_pos.round(); var asc: float = 0.78 if fred else 1.0
	var b1: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_1")
	var b2: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_2")
	var b3: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_3")
	var lit_n: int = (1 if b1 else 0) + (1 if b2 else 0) + (1 if b3 else 0)
	draw_arc(p, 19.0, 0.0, TAU, 24, _c("night", 0.55), 2.0)
	draw_arc(p, 18.0, deg_to_rad(130.0), deg_to_rad(235.0), 10, _c("gold" if b1 else "sky", (0.95 if b1 else 0.66) * asc), 2.0 if b1 else 1.0)
	draw_arc(p, 18.0, deg_to_rad(250.0), deg_to_rad(355.0), 10, _c("gold" if b3 else "coral", (0.95 if b3 else 0.66) * asc), 2.0 if b3 else 1.0)
	draw_arc(p, 18.0, deg_to_rad(10.0), deg_to_rad(115.0), 10, _c("gold" if b2 else "jade", (0.95 if b2 else 0.66) * asc), 2.0 if b2 else 1.0)
	draw_arc(p, 11.0, 0.0, TAU, 16, _c("cream" if lit_n == 3 else "gold", (0.85 if lit_n > 0 else 0.32) * asc), 1.0)
	if lit_n > 0:
		var u: float = fposmod(st * (0.8 if fred else 1.4), 1.0)
		for k: int in range(lit_n):
			draw_rect(Rect2(Vector2(p.x + float(k - 1) * 3.0, lerpf(p.y - 16.0, 168.0, fposmod(u + float(k) / float(lit_n), 1.0))).round(), Vector2(2.0, 2.0)), _c("cream", 0.90 * asc))

func _draw_vent_chevrons(cam_rect: Rect2, st: float, fred: bool, wick: LxWick) -> void:
	if wick == null or wick.move_sunflare == null or not wick.move_sunflare.unlocked or wick.ember >= wick.move_sunflare.get_ember_max() - 0.5: return
	var br: LxBiomeRules = LxBiomeRules.active_instance
	if br == null or not is_instance_valid(br): return
	var asc: float = 0.72 if fred else 1.0; var c_g: Color = _c("gold", 0.82 * asc); var c_c: Color = _c("cream", 0.90 * asc)
	for v: Dictionary in br._vents:
		var p: Vector2 = v["pos"] as Vector2
		if not cam_rect.has_point(p) or fposmod(br.vent_cycle + float(v["phase"]), 1.0) < 0.56: continue
		var lift: float = fposmod(st * (14.0 if fred else 24.0), 10.0)
		for side: int in range(-1, 2, 2):
			var c: Vector2 = (p + Vector2(float(side) * 11.0, -2.0 - lift)).round()
			draw_line(c + Vector2(-2.0, 2.0), c, c_g, 1.0, false); draw_line(c + Vector2(2.0, 2.0), c, c_g, 1.0, false); draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2.ONE), c_c)

func _draw_dotted_ring(c: Vector2, rad: float, col: Color, dots: int, phase: float) -> void:
	for k: int in range(dots): draw_rect(Rect2((c + Vector2.from_angle(phase + (TAU * float(k)) / float(dots)) * rad).round(), Vector2.ONE), col)

func _sample_poly(pts: PackedVector2Array, cum: PackedFloat32Array, total_len: float, dist: float) -> Vector2:
	if dist < 0.0 or dist > total_len: return Vector2(-99999.0, -99999.0)
	for i: int in range(pts.size() - 1):
		if dist >= cum[i] and dist <= cum[i + 1] and cum[i + 1] > cum[i]: return pts[i].lerp(pts[i + 1], (dist - cum[i]) / (cum[i + 1] - cum[i])).round()
	return Vector2(-99999.0, -99999.0)

func _is_flag_active(key: String) -> bool:
	if key.is_empty() or _region == null: return false
	if _region.is_flag_set(key): return true
	var it: LxInteractable = _region.find_interactable(key)
	if it == null or not is_instance_valid(it): return false
	if it is LxSwitchEye: return (it as LxSwitchEye).activated
	if it is LxBrazier: return (it as LxBrazier).lit
	if it is LxObsidianSeal: return (it as LxObsidianSeal).shattered
	if it is LxCrackedWall: return (it as LxCrackedWall).broken
	if it is LxBramble: return (it as LxBramble).burned
	if it is LxBluePortal: return (it as LxBluePortal).powered
	if it is LxShrine: return (it as LxShrine).claimed
	return (it as LxDoor).opened if it is LxDoor else false
