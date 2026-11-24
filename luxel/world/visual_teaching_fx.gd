class_name LxVisualTeachingFx
extends Node2D
## Carved, worn in-world light inlays, drifting petals, wind currents, and rune stones
## for Islands 2..8 (z_index = -4, strictly 20 Last Light colours, zero CAD wires/overlays).
## Strictly excludes Island 1. Zero per-frame allocations in _draw(); caches built in rebuild().

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
			_add_fan(Vector2(296, 200), Vector2.RIGHT, Vector2.RIGHT, false, "switch_eye_2_1|bridge_2_drydock|island_2_relit")
			_add_guide(PackedVector2Array([Vector2(264, 200), Vector2(296, 200)]), 0, "apricot", "gold", "cream", "switch_eye_2_1|bridge_2_drydock|island_2_relit", "", false, 0, "island_2_relit")
			_add_guide(PackedVector2Array([Vector2(296, 200), Vector2(376, 200)]), 0, "sky", "ice", "cream", "switch_eye_2_1|bridge_2_drydock|island_2_relit", "", false, 0, "island_2_relit")
		"2:lighthouse_r3":
			_add_fan(Vector2(200, 120), Vector2.RIGHT, (Vector2(328, 56) - Vector2(200, 120)).normalized(), true, "lh_r3_cleared|door_lh_r3_combat|island_2_relit")
		"2:lighthouse_r5":
			_add_fan(Vector2(120, 136), Vector2.RIGHT, Vector2.RIGHT, true, "lh_r5_prism_solved|door_lh_r5_shutter|island_2_relit", "shrine_prism&lh_r5_prism_solved|shrine_prism&door_lh_r5_shutter|island_2_relit")
			_add_fan(Vector2(136, 184), Vector2.RIGHT, (Vector2(264, 88) - Vector2(136, 184)).normalized(), false, "lh_r5_bridge_open|lh_r5_prism_solved|door_lh_r5_shutter|island_2_relit")
			_add_fan(Vector2(312, 184), Vector2.RIGHT, (Vector2(360, 56) - Vector2(312, 184)).normalized(), false, "lh_r5_prism_solved|door_lh_r5_shutter|island_2_relit")
			_add_guide(PackedVector2Array([Vector2(136, 184), Vector2(264, 88)]), 0, "sky", "ice", "cream", "lh_r5_bridge_open|door_lh_r5_shutter|island_2_relit", "", false, 0, "island_2_relit")
			_add_guide(PackedVector2Array([Vector2(312, 184), Vector2(360, 56)]), 0, "sky", "ice", "cream", "lh_r5_prism_solved|door_lh_r5_shutter|island_2_relit", "", false, 0, "island_2_relit")
		"2:lighthouse_r7":
			_add_guide(PackedVector2Array([Vector2(120, 184), Vector2(184, 72)]), 0, "sky", "ice", "cream", "lh_r7_portal_lit|portal_lh_r7_in|door_lh_r7_shutter|island_2_relit", "", false, 0, "island_2_relit")
			_add_guide(PackedVector2Array([Vector2(296, 168), Vector2(392, 104)]), 0, "sky", "ice", "cream", "lh_r7_gallery_open|door_lh_r7_shutter|island_2_relit", "", false, 0, "island_2_relit")
		"3:oak_r5":
			_add_ring(Vector2(136, 104), 0, 11.0, Vector2.RIGHT, "oak_r5_beam_solved|door_oak_r5_shutter|island_3_relit", "shrine_beam")
			_add_guide(PackedVector2Array([Vector2(120, 104), Vector2(184, 104), Vector2(248, 104), Vector2(312, 104)]), 1, "jade", "gold", "cream", "oak_r5_beam_solved|door_oak_r5_shutter|island_3_relit")
			_add_guide(PackedVector2Array([Vector2(336, 120), Vector2(336, 152)]), 1, "apricot", "gold", "cream", "bramble_oak_r5_cache|chest_oak_r5_shards", "", false, 0, "bramble_oak_r5_cache|chest_oak_r5_shards")
		"3:oak_r7":
			_add_guide(PackedVector2Array([Vector2(200, 152), Vector2(200, 72), Vector2(248, 72), Vector2(280, 72), Vector2(312, 72)]), 2, "sky", "ice", "lime", "oak_r7_loom_open|door_oak_r7_shutter|island_3_relit", "", false, 1)
			_add_ring(Vector2(200, 72), 7, 8.0, Vector2.RIGHT, "oak_r7_loom_open|door_oak_r7_shutter|island_3_relit")
		"3:overworld":
			_add_ring(Vector2(464, 760), 6, 12.0, Vector2.RIGHT, "bramble_3_shortcut_east")
			_add_ring(Vector2(224, 488), 6, 12.0, Vector2.UP, "bramble_3_shortcut_canopy")
		"4:conservatory_r5":
			# Real updrafts now live in LxBiomeRules at (160,112) & (320,112); upd=false here (D04)
			var c4_done: String = "door_c4_r5_exit|visited:4:conservatory_r6|island_4_relit"
			_add_glide(Vector2(124, 112), Vector2(196, 112), true, Vector2(152, 104), Vector2(168, 124), false, Vector2.ZERO, c4_done)
			_add_glide(Vector2(284, 112), Vector2(348, 112), true, Vector2(312, 104), Vector2(328, 124), false, Vector2.ZERO, c4_done)
			_add_glide(Vector2(124, 208), Vector2(180, 208), false, Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, c4_done)
			_add_glide(Vector2(252, 208), Vector2(356, 208), false, Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, c4_done)
		"4:conservatory_r2", "4:overworld":
			var centers: PackedVector2Array = PackedVector2Array()
			var bridges: Array[Rect2] = _collect_bridge_rects(region)
			var g_done: String = "bridge_c4_r2|wick_key_4_1|island_4_relit" if _region_id == "conservatory_r2" else "tut_wings_glided&visited:4:conservatory_r5|island_4_relit"
			_scan_lagoon_gaps(region, true, centers, bridges, g_done); _scan_lagoon_gaps(region, false, centers, bridges, g_done)
		"5:orrery_r2":
			_add_guide(PackedVector2Array([Vector2(176, 108), Vector2(176, 64)]), 4, "apricot", "gold", "cream", "cracked_o5_r2")
		"5:orrery_r5":
			var o5_done: String = "visited:5:orrery_r6|island_5_relit"
			_add_ring(Vector2(112, 88), 1, 13.0, Vector2.RIGHT, "shrine_lens", "", o5_done)
			_add_ring(Vector2(248, 120), 2, 78.0, Vector2.RIGHT, "shrine_lens", "", o5_done)
		"5:orrery_r7":
			var o7_done: String = "door_o5_r7_shutter|switch_eye_o5_r7|island_5_relit"
			_add_ring(Vector2(304, 184), 2, 78.0, Vector2.LEFT, "shrine_lens", "", o7_done)
			_add_ring(Vector2(152, 112), 2, 78.0, Vector2.DOWN, "shrine_lens", "", o7_done)
		"6:kiln_r5":
			_add_guide(PackedVector2Array([Vector2(200, 104), Vector2(272, 120)]), 1, "coral", "gold", "cream", "seal_kiln_r5")
			_add_ring(Vector2(272, 120), 3, 76.0, Vector2.RIGHT, "seal_kiln_r5", "shrine_sunflare")
		"6:kiln_r7":
			_add_guide(PackedVector2Array([Vector2(232, 184), Vector2(232, 88)]), 0, "sky", "ice", "cream", "switch_eye_kiln_r7|door_kiln_r7_west|island_6_relit", "", false, 0, "island_6_relit")
		"7:spire_r5":
			_add_guide(PackedVector2Array([Vector2(120, 168), Vector2(168, 56)]), 0, "sky", "ice", "cream", "switch_eye_spire_r5_west|island_7_relit", "", false, 0, "island_7_relit")
			_add_guide(PackedVector2Array([Vector2(120, 168), Vector2(248, 136), Vector2(312, 152), Vector2(440, 72)]), 0, "sky", "ice", "cream", "switch_eye_spire_r5_east|island_7_relit", "bramble_spire_r5_baffle", false, 0, "island_7_relit")
			_add_ring(Vector2(392, 200), 4, 15.0, Vector2.UP, "spire_r5_portal_lit")
		"7:spire_r7":
			_add_guide(PackedVector2Array([Vector2(104, 104), Vector2(184, 40)]), 3, "sky", "ice", "cream", "spire_r7_terrace_portal", "", true, 0, "door_spire_r7_west|island_7_relit")
			_add_guide(PackedVector2Array([Vector2(184, 168), Vector2(232, 72), Vector2(344, 40)]), 0, "sky", "ice", "cream", "switch_eye_spire_r7_a|door_spire_r7_west|island_7_relit", "", false, 0, "island_7_relit")
		"8:overworld":
			_has_medallion = true
			_add_leyline(region, PackedVector2Array([Vector2(88, 804), Vector2(312, 804), Vector2(312, 696), Vector2(360, 696), Vector2(360, 612), Vector2(404, 612), Vector2(404, 456), Vector2(396, 456), Vector2(396, 184)]), "sky", "ice", "beacon_8_1")
			_add_leyline(region, PackedVector2Array([Vector2(632, 504), Vector2(408, 504), Vector2(408, 328), Vector2(404, 328), Vector2(404, 184)]), "jade", "lime", "beacon_8_2")
			_add_leyline(region, PackedVector2Array([Vector2(136, 312), Vector2(400, 312), Vector2(400, 184)]), "coral", "apricot", "beacon_8_3")
		"8:sanctum_r1":
			_add_guide(PackedVector2Array([Vector2(120, 88), Vector2(360, 168)]), 3, "sky", "ice", "cream", "sanctum_r1_cloister_portal", "", true, 0, "door_sanctum_r1_shortcut|chest_sanctum_r1_cloister|island_8_relit")
			_add_guide(PackedVector2Array([Vector2(232, 232), Vector2(120, 88)]), 0, "sky", "ice", "cream", "sanctum_r1_cloister_portal|door_sanctum_r1_shortcut|island_8_relit", "", false, 0, "island_8_relit")
		"8:sanctum_r5":
			_add_guide(PackedVector2Array([Vector2(56, 216), Vector2(208, 104)]), 3, "coral", "apricot", "cream", "brazier_sanctum_r5_west", "", true, 0, "door_sanctum_r5_choir|island_8_relit")
			_add_guide(PackedVector2Array([Vector2(440, 152), Vector2(208, 104)]), 3, "sky", "ice", "cream", "switch_eye_sanctum_r5_blue", "", true, 0, "door_sanctum_r5_choir|island_8_relit")
			_add_guide(PackedVector2Array([Vector2(208, 104), Vector2(208, 72), Vector2(208, 24)]), 4, "gold", "cream", "cream", "keepers_flame_8", "", true, 0, "door_boss_8|boss_the_hush_defeated|island_8_relit")
		"8:sanctum_r6":
			_add_guide(PackedVector2Array([Vector2(192, 304), Vector2(264, 248), Vector2(264, 168), Vector2(296, 72)]), 5, "plum", "wine", "gold", "boss_the_hush_defeated", "", true, 0, "island_8_relit")
			_add_ring(Vector2(168, 200), 5, 13.0, Vector2.RIGHT, "boss_the_hush_defeated|island_8_relit")
			_add_ring(Vector2(360, 136), 5, 13.0, Vector2.LEFT, "boss_the_hush_defeated|island_8_relit")

func _add_guide(pts: PackedVector2Array, kind: int, ca: String, cb: String, chi: String, flag: String = "", extra: String = "", inv: bool = false, split: int = 0, done_flag: String = "") -> void:
	if pts.size() < 2: return
	var cum := PackedFloat32Array([0.0]); var acc: float = 0.0; var mn: Vector2 = pts[0]; var mx: Vector2 = pts[0]
	for i: int in range(1, pts.size()):
		acc += pts[i - 1].distance_to(pts[i]); cum.append(acc)
		mn = Vector2(minf(mn.x, pts[i].x), minf(mn.y, pts[i].y)); mx = Vector2(maxf(mx.x, pts[i].x), maxf(mx.y, pts[i].y))
	_guides.append({"pts": pts, "cum": cum, "len": maxf(1.0, acc), "kind": kind, "ca": ca, "cb": cb, "chi": chi, "flag": flag, "extra": extra, "inv": inv, "split": split, "done": done_flag, "bbox": Rect2(mn - Vector2(16.0, 16.0), (mx - mn) + Vector2(32.0, 32.0))})

func _add_fan(p: Vector2, idir: Vector2, odir: Vector2, is_fan: bool, flag: String, done_flag: String = "") -> void: _fans.append({"pos": p, "in": idir, "out": odir, "fan": is_fan, "flag": flag, "done": done_flag})
func _add_ring(p: Vector2, kind: int, rad: float, dir: Vector2, flag: String = "", extra: String = "", done_flag: String = "") -> void: _rings.append({"pos": p, "kind": kind, "rad": rad, "dir": dir, "flag": flag, "extra": extra, "done": done_flag})

func _add_glide(a: Vector2, b: Vector2, lil: bool = false, la: Vector2 = Vector2.ZERO, lb: Vector2 = Vector2.ZERO, upd: bool = false, up: Vector2 = Vector2.ZERO, done_flag: String = "") -> void:
	var gl: float = maxf(1.0, a.distance_to(b)); var d: Vector2 = (b - a) / gl
	var mn := Vector2(minf(a.x, b.x) - 24.0, minf(a.y, b.y) - 24.0)
	_glides.append({"a": a, "b": b, "dir": d, "perp": Vector2(-d.y, d.x), "len": gl, "lil": lil, "la": la, "lb": lb, "upd": upd, "up": up, "done": done_flag, "bbox": Rect2(mn, Vector2(maxf(a.x, b.x) + 24.0, maxf(a.y, b.y) + 24.0) - mn)})

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

func _scan_lagoon_gaps(region: LxRegionLoader, horiz: bool, centers: PackedVector2Array, bridges: Array[Rect2], done_flag: String = "") -> void:
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
					if not _near_bridge(a, mid, b, bridges) and _far_from_all(mid, centers, 4096.0): centers.append(mid); _add_glide(a, b, false, Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, done_flag)
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

func _is_blocked_point(pt: Vector2) -> bool:
	if _region == null: return false
	if _region.tile_at(pt) == "wall": return true
	for it: LxInteractable in _region.get_interactables():
		if it != null and is_instance_valid(it) and it.is_solid() and it.kind in ["bramble", "cracked_wall", "obsidian_seal"]:
			if it.get_solid_rect().grow(2.0).has_point(pt): return true
	return false

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
	if (_island_id == 6 or _island_id == 8) and not _is_dungeon: _draw_vent_petals(cam_rect, st, fred, wick)

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
		var ph: int = (int(pt.x) * 3 + int(pt.y) * 7) & 15; var tw: int = (step + ph) & 7
		var d_off: float = 0.0 if fred else roundf(sin(_clock * 1.8 + float(ph)) * 1.0)
		draw_rect(Rect2((pt + Vector2(-4.0, -3.0 + d_off)).round(), Vector2.ONE), _c("ice" if (near and (has_lens or tw < 4)) else "sky", (0.76 if near else 0.44) * asc))
		draw_rect(Rect2((pt + Vector2(3.0, 3.0 - d_off)).round(), Vector2.ONE), _c("sky" if near else "deep", (0.62 if near else 0.36) * asc))
		if tw == 0 or (near and tw == 4):
			draw_rect(Rect2(pt.round(), Vector2.ONE), _c("cream" if (near and has_lens) else "ice", (0.80 if near else 0.46) * asc))

func _draw_cloaked_owls(cam_rect: Rect2, step: int, fred: bool, wick_ok: bool, wick_pos: Vector2) -> void:
	var ref_pos: Vector2 = wick_pos if wick_ok else _cam_center
	var c_ice: Color = _c("ice", 0.72 if fred else 0.90); var c_sky: Color = _c("sky", 0.42 if fred else 0.62)
	for e: LxEnemyBrain in _region.get_enemies():
		if e == null or not is_instance_valid(e) or not e.is_alive() or e.kind != "phantom_owl": continue
		if e is LxPhantomOwlBrain and (e as LxPhantomOwlBrain).revealed: continue
		if not cam_rect.has_point(e.pos) or e.pos.distance_squared_to(ref_pos) > OWL_NEAR_SQ: continue
		var p: Vector2 = (e.pos + Vector2(0.0, -4.0)).round()
		if (step % 6) != 0:
			draw_rect(Rect2(p + Vector2(-3.0, -2.0), Vector2(2.0, 1.0)), c_ice); draw_rect(Rect2(p + Vector2(1.0, -2.0), Vector2(2.0, 1.0)), c_ice)
		for k: int in range(6):
			var a0: float = float(step) * 0.14 + float(k) * (TAU / 6.0)
			draw_rect(Rect2((p + Vector2(cos(a0) * 9.0, sin(a0) * 6.0)).round(), Vector2.ONE), c_sky)

func _draw_fan(f: Dictionary, step: int, fred: bool) -> void:
	# Carved floor prism-rose inlay + drifting prism-dust motes (zero rigid laser spokes)
	if _is_flag_active(str(f["done"])): return
	var calm: bool = _is_flag_active(str(f["flag"])); var asc: float = (0.24 if calm else 0.78) * (0.75 if fred else 1.0)
	var p: Vector2 = (f["pos"] as Vector2).round(); var idir: Vector2 = f["in"] as Vector2; var odir: Vector2 = f["out"] as Vector2
	var c_rec: Color = _c("night", 0.36 * asc)
	var c_in: Color = _c("mauve" if calm else "apricot", 0.60 * asc)
	var c_sky: Color = _c("stone" if calm else "sky", 0.66 * asc); var c_ice: Color = _c("mauve" if calm else "ice", 0.85 * asc)
	# Subtle carved diamond stone inlay beneath the prism/mirror pedestal
	for dp: Vector2 in [Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]:
		draw_rect(Rect2(p + dp + Vector2(0, 1), Vector2.ONE), c_rec)
		draw_rect(Rect2(p + dp, Vector2.ONE), c_ice)
	# Incoming golden spark mote
	if not calm:
		var u_in: float = fposmod(_clock * (0.55 if fred else 0.95), 1.0)
		var ip: Vector2 = (p - idir * lerpf(18.0, 6.0, u_in)).round()
		draw_rect(Rect2(ip, Vector2.ONE), _c("gold", sin(u_in * PI) * asc))
	# Outgoing drifting prism-dust motes along split fan or reflection vector
	var rays: Array[float] = [0.0]
	if bool(f["fan"]):
		rays = [-18.0, 0.0, 18.0]
	for ri: int in range(rays.size()):
		var rd: Vector2 = odir.rotated(deg_to_rad(rays[ri]))
		for mi: int in range(2):
			var u: float = fposmod(_clock * (0.42 if fred else 0.76) + float(mi) * 0.5 + float(ri) * 0.19, 1.0)
			var mp: Vector2 = (p + rd * lerpf(7.0, 26.0 if bool(f["fan"]) else 20.0, u)).round()
			var ma: float = (0.30 if calm else sin(u * PI) * 0.92) * asc
			draw_rect(Rect2(mp + Vector2(0, 1), Vector2.ONE), _c("night", ma * 0.45))
			draw_rect(Rect2(mp, Vector2.ONE), _c("cream", ma) if (ri == 1 or not bool(f["fan"])) and u > 0.35 and u < 0.7 else (c_ice if mi == 0 else c_sky))
	if not calm and (step % 4) != 3:
		draw_rect(Rect2((p + odir * 16.0).round(), Vector2.ONE), _c("cream", 0.72 * asc))

func _draw_guide(g: Dictionary, st: float, fred: bool, ember_full: bool) -> void:
	# Worn carved floor-stone notches + gentle drifting light-dust motes (never cuts through solid walls/brambles)
	var pts: PackedVector2Array = g["pts"] as PackedVector2Array; var kind: int = int(g["kind"])
	var flag_on: bool = _is_flag_active(str(g["flag"])); var extra_on: bool = _is_flag_active(str(g["extra"])); var done_on: bool = _is_flag_active(str(g["done"]))
	if done_on: return
	var ca_k: String = str(g["ca"]); var cb_k: String = str(g["cb"]); var chi_k: String = str(g["chi"]); var asc: float = 0.74 if fred else 1.0
	var is_kiln: bool = _region_id == "kiln_r5"
	if (kind == 1 or kind == 2 or kind == 4) and flag_on and not bool(g["inv"]): return
	var calm: bool = (flag_on and not bool(g["inv"])) and kind != 5
	var lit: bool = (flag_on if bool(g["inv"]) else not flag_on) if kind == 3 else not calm
	var col_base: Color = _c("gold" if ((ember_full and is_kiln) or (kind == 5 and flag_on)) else ca_k, (0.30 if calm else 0.64) * asc)
	var col_mote: Color = _c("cream" if (ember_full and is_kiln) else cb_k, (0.38 if calm else 0.90) * asc)
	var col_hi: Color = _c(chi_k, (0.44 if calm else 0.96) * asc)
	var c_rec: Color = _c("night", 0.32 * asc)
	var sp_idx: int = int(g["split"])
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]; var slen: float = a.distance_to(b)
		if slen < 4.0: continue
		var seg_c: Color = _c("gold", col_base.a) if (kind == 2 and i < sp_idx) else col_base
		var d: float = 8.0
		var idx: int = 0
		while d < slen - 6.0:
			var pt: Vector2 = a.lerp(b, d / slen).round()
			if not _is_blocked_point(pt):
				draw_rect(Rect2(pt + Vector2(0.0, 1.0), Vector2(2.0 if idx % 2 == 0 else 1.0, 1.0)), c_rec)
				draw_rect(Rect2(pt, Vector2(2.0 if idx % 2 == 0 else 1.0, 1.0)), seg_c)
			d += 11.0
			idx += 1
	if not lit and kind != 5: return
	# Gentle drifting light-dust motes traveling along the sightline (stops cleanly if blocked)
	var tlen: float = float(g["len"]); var cum: PackedFloat32Array = g["cum"] as PackedFloat32Array
	var mote_n: int = 3 if tlen >= 120.0 else 2
	var spd: float = (26.0 if fred else 42.0) * (1.25 if extra_on else 1.0)
	var d0: float = fposmod(st * spd, tlen + 16.0)
	for k: int in range(mote_n):
		var md: float = fposmod(d0 + float(k) * (tlen / float(mote_n)), tlen)
		var bp: Vector2 = _sample_poly(pts, cum, tlen, md)
		if bp.x > -9000.0 and not _is_blocked_point(bp):
			var edge_a: float = sin(clampf(md / maxf(1.0, tlen), 0.0, 1.0) * PI)
			draw_rect(Rect2(bp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(col_mote, col_mote.a * edge_a * 0.55))
			draw_rect(Rect2(bp, Vector2.ONE), Color(col_hi, col_hi.a * edge_a))

func _draw_glide(gs: Dictionary, st: float, fred: bool) -> void:
	# Organic drifting petals & pale wind-mist ribbons masked strictly to water tiles (zero CAD rails/arrows)
	var a: Vector2 = gs["a"] as Vector2; var b: Vector2 = gs["b"] as Vector2; var dir: Vector2 = gs["dir"] as Vector2; var perp: Vector2 = gs["perp"] as Vector2; var gl: float = float(gs["len"])
	var settled: bool = _is_flag_active(str(gs["done"]))
	if settled: return
	var asc: float = (0.86 if (Lx.state != null and Lx.state.has_move("wings")) else 0.68) * (0.76 if fred else 1.0)
	var c_rose: Color = _c("rose", 0.72 * asc); var c_cream: Color = _c("cream", 0.82 * asc); var c_ice: Color = _c("ice", 0.58 * asc)
	var spd: float = 16.0 if fred else 28.0
	var rsz: Vector2 = Vector2(3.0, 1.0) if absf(dir.x) >= absf(dir.y) else Vector2(1.0, 3.0)
	for lane: int in range(-1, 2):
		var loff: Vector2 = perp * (float(lane) * 8.0)
		var step_g: float = 18.0
		var d: float = fposmod(st * spd + float(lane + 1) * 6.0, step_g)
		while d < gl - 4.0:
			var wp: Vector2 = (a + loff + dir * d + perp * roundf(sin(d * 0.12 + st * 2.2 + float(lane)) * 1.8)).round()
			if _region == null or _is_wet(_region.tile_at(wp)):
				var edge_f: float = sin(clampf(d / gl, 0.0, 1.0) * PI)
				var is_petal: bool = lane != 1 and (int(d) % 2 == 0)
				var col: Color = Color(c_cream if (lane == 0 and int(d) % 3 == 0) else (c_rose if is_petal else c_ice), edge_f * asc)
				draw_rect(Rect2(wp, Vector2(2.0, 1.0) if is_petal else rsz), col)
			d += step_g
	# Subtle carved stone takeoff-lip notches on dry banks only (never floating over water)
	for end_i: int in range(2):
		var ep: Vector2 = (a - dir * 3.0) if end_i == 0 else (b + dir * 3.0)
		if _region != null and _is_walk(_region.tile_at(ep)):
			for sgn: float in [-3.0, 0.0, 3.0]:
				var np: Vector2 = (ep + perp * sgn).round()
				draw_rect(Rect2(np + Vector2(0.0, 1.0), Vector2.ONE), _c("night", 0.38 * asc))
				draw_rect(Rect2(np, Vector2.ONE), c_rose if sgn == 0.0 else c_ice)
	if bool(gs["lil"]):
		for li: int in range(2):
			var lp: Vector2 = (gs["la"] as Vector2) if li == 0 else (gs["lb"] as Vector2)
			if _region != null and not _is_wet(_region.tile_at(lp)): continue
			var p: Vector2 = (lp + Vector2(0.0, 0.0 if fred else roundf(sin(st * 2.4 + float(li) * 0.9 + lp.x * 0.05)))).round()
			draw_rect(Rect2(p + Vector2(-3.0, -2.0), Vector2(6.0, 5.0)), PAL["pine"] as Color); draw_rect(Rect2(p + Vector2(-4.0, -1.0), Vector2(8.0, 3.0)), PAL["pine"] as Color)
			draw_rect(Rect2(p + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), PAL["jade"] as Color); draw_rect(Rect2(p + Vector2(-2.0, -1.0), Vector2(2.0, 1.0)), PAL["lime"] as Color)

func _draw_ring(r: Dictionary, st: float, step: int, fred: bool, ember_full: bool) -> void:
	var p: Vector2 = (r["pos"] as Vector2).round(); var kind: int = int(r["kind"]); var rad: float = float(r["rad"])
	var dir: Vector2 = r["dir"] as Vector2; var flag: String = str(r["flag"]); var extra: String = str(r["extra"]); var done: String = str(r["done"]); var asc: float = 0.75 if fred else 1.0
	var c_rec: Color = _c("night", 0.36 * asc)
	match kind:
		0: # oak_r5 carved moss-stone focus stance inlay
			var solved: bool = _is_flag_active(flag); var claimed: bool = _is_flag_active(extra) or (Lx.state != null and Lx.state.has_move("beam"))
			if solved: return
			var rr: float = lerpf(11.0, 6.0, fposmod(st * (0.55 if fred else 0.95), 1.0))
			_draw_carved_rune_ring(p, rr, _c("gold" if claimed else "lime", 0.72 * asc), c_rec, 8, st * 0.35)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), _c("cream" if claimed else "jade", 0.78 * asc))
		1: # orrery_r5 astrolabe floor star-inlay
			if _is_flag_active(done): return
			var has_lens: bool = _is_flag_active(flag) or (Lx.state != null and Lx.state.has_move("lens"))
			var u: float = fposmod(st * (0.48 if fred else 0.82), 1.0)
			_draw_carved_rune_ring(p, 10.0, _c("sky", (0.60 if has_lens else 0.42) * asc), c_rec, 8, st * 0.25)
			_draw_carved_rune_ring(p, lerpf(6.0, 20.0, u), _c("ice", (1.0 - u) * (0.72 if has_lens else 0.44) * asc), Color(0, 0, 0, 0), 8, -st * 0.35)
			var mp: Vector2 = (p + dir * lerpf(10.0, 24.0, u)).round()
			draw_rect(Rect2(mp, Vector2.ONE), _c("cream", sin(u * PI) * 0.85 * asc))
		2: # orrery_r5 / orrery_r7 carved lantern-cradle floor stone + sparse constellation flecks (no 78px CAD ring!)
			var settled: bool = _is_flag_active(done) if not done.is_empty() else _is_flag_active(flag)
			if settled: return
			var c_gold: Color = _c("gold", 0.76 * asc); var c_ice: Color = _c("ice", 0.68 * asc)
			# Carved circular floor-stone cradle (4 diagonal notches + tiny hanging lantern emblem)
			for si: int in range(4):
				var ca: float = float(si) * (PI * 0.5) + PI * 0.25
				var np: Vector2 = (p + Vector2(cos(ca) * 7.0, sin(ca) * 7.0)).round()
				draw_rect(Rect2(np + Vector2(0, 1), Vector2(2.0, 1.0)), c_rec)
				draw_rect(Rect2(np, Vector2(2.0, 1.0)), c_gold)
			draw_rect(Rect2(p + Vector2(-1.0, -2.0), Vector2(2.0, 1.0)), c_ice)
			draw_rect(Rect2(p + Vector2(-1.0, -1.0), Vector2(2.0, 3.0)), c_gold)
			# 8 gentle breathing starlight dust flecks marking lantern reach without a dotted wireframe circle
			for k: int in range(8):
				var ang: float = st * (0.08 if fred else 0.16) + float(k) * (TAU / 8.0)
				var sp: Vector2 = (p + Vector2(cos(ang) * rad, sin(ang) * rad)).round()
				var tw: float = 0.55 if fred else (0.35 + 0.35 * sin(st * 2.0 + float(k) * 1.3))
				draw_rect(Rect2(sp, Vector2.ONE), _c("ice" if k % 2 == 0 else "sky", tw * asc))
		3: # kiln_r5 carved solar hearth rune + drifting cinder sparks (no 24-arc CAD circle)
			if _is_flag_active(flag): return
			var claimed: bool = _is_flag_active(extra) or (Lx.state != null and Lx.state.has_move("sunflare"))
			var c_in: Color = _c("cream" if ember_full else ("gold" if claimed else "apricot"), 0.82 * asc)
			var c_out: Color = _c("gold" if ember_full else ("apricot" if claimed else "coral"), (0.74 if ember_full else 0.44) * asc)
			_draw_carved_rune_ring(p, 11.0, c_in, c_rec, 8, st * 0.35)
			draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), c_in); draw_rect(Rect2(p + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), c_in)
			for k: int in range(12):
				var a0: float = -st * (0.10 if fred else 0.20) + float(k) * (TAU / 12.0)
				var sp: Vector2 = (p + Vector2(cos(a0) * rad, sin(a0) * rad)).round()
				draw_rect(Rect2(sp, Vector2(2.0 if (ember_full and k % 3 == 0) else 1.0, 1.0)), _c("cream", 0.82 * asc) if (ember_full and k % 3 == 0) else c_out)
		4: # spire_r5 return portal carved moon-dust arc
			_draw_carved_rune_ring(p, rad, _c("cream" if _is_flag_active(flag) else "sky", 0.64 * asc), c_rec, 10, st * (0.45 if fred else 0.85))
		5: # sanctum_r6 transformer floor rune flecks
			if _is_flag_active(flag) or _is_flag_active(done): return
			_draw_carved_rune_ring(p, rad, _c("ice" if (step % 4 == 0) else "sky", 0.58 * asc), c_rec, 6, 0.0)
		6: # island 3 overworld bramble beam-return moss ticks
			if Lx.state == null or not Lx.state.has_move("beam") or _is_flag_active(flag): return
			var c_g: Color = _c("gold" if (step % 2 == 0) else "jade", 0.68 * asc)
			for off_t: Vector2 in [Vector2(-8, 0), Vector2(6, 0), Vector2(0, -8)]:
				draw_rect(Rect2(p + off_t, Vector2(2.0, 1.0)), c_g)
		7: # oak_r7 carved stone socket pad at L-bend (worn notches instead of solid octagon wire)
			var solved: bool = _is_flag_active(flag); var sa: float = (0.32 if solved else 0.72) * asc
			_draw_carved_rune_ring(p, 8.0, _c("jade" if solved else "gold", sa), c_rec, 8, 0.0)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), _c("jade" if solved else ("cream" if (step % 4 == 0 and not fred) else "ice"), 0.80 * asc))

func _draw_carved_rune_ring(c: Vector2, rad: float, col: Color, rec_col: Color, notches: int, phase: float) -> void:
	for k: int in range(notches):
		var a: float = phase + (TAU * float(k)) / float(notches)
		var pt: Vector2 = (c + Vector2(cos(a) * rad, sin(a) * rad)).round()
		var sz := Vector2(2.0, 1.0) if absf(sin(a)) >= absf(cos(a)) else Vector2(1.0, 2.0)
		if rec_col.a > 0.01:
			draw_rect(Rect2(pt + Vector2(0.0, 1.0), sz), rec_col)
		draw_rect(Rect2(pt, sz), col)

func _draw_leyline(ll: Dictionary, st: float, fred: bool) -> void:
	var lit: bool = Lx.state != null and Lx.state.lit_beacons.has(str(ll["bid"])); var gate_open: bool = _is_flag_active("door_dungeon_8|visited:8:sanctum_r1|island_8_relit")
	var asc: float = 0.76 if fred else 1.0; var calm_lit: bool = lit and gate_open
	var c_grv: Color = _c("night", 0.34 if calm_lit else 0.42); var c_main: Color = _c("gold" if lit else str(ll["ca"]), (0.38 if calm_lit else (0.70 if lit else 0.44)) * asc); var c_hi: Color = _c("cream" if lit else str(ll["cb"]), (0.88 if lit else 0.62) * asc)
	var ra_arr: PackedVector2Array = ll["ra"] as PackedVector2Array; var rb_arr: PackedVector2Array = ll["rb"] as PackedVector2Array
	var d0_arr: PackedFloat32Array = ll["d0"] as PackedFloat32Array; var d1_arr: PackedFloat32Array = ll["d1"] as PackedFloat32Array
	var bead_d: float = fposmod(st * (40.0 if fred else 66.0), float(ll["len"]) + 28.0)
	for i: int in range(ra_arr.size()):
		var ra: Vector2 = ra_arr[i]; var rb: Vector2 = rb_arr[i]; var d0: float = d0_arr[i]; var d1: float = d1_arr[i]
		var slen: float = ra.distance_to(rb)
		var horiz: bool = absf(rb.x - ra.x) >= absf(rb.y - ra.y)
		var dn: float = 3.0
		while dn < slen - 2.0:
			var np: Vector2 = ra.lerp(rb, dn / maxf(1.0, slen)).round()
			var nsz := Vector2(3.0, 1.0) if horiz else Vector2(1.0, 3.0)
			draw_rect(Rect2(np + Vector2(0.0, 1.0), nsz), c_grv); draw_rect(Rect2(np, nsz), c_main)
			dn += 7.0
		if lit and not calm_lit and bead_d >= d0 and bead_d <= d1 and d1 > d0:
			var bp: Vector2 = ra.lerp(rb, (bead_d - d0) / (d1 - d0)).round()
			draw_rect(Rect2(bp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), c_main); draw_rect(Rect2(bp, Vector2.ONE), c_hi)

func _draw_medallion(st: float, fred: bool) -> void:
	var p: Vector2 = _medallion_pos.round(); var asc: float = 0.78 if fred else 1.0; var c_rec: Color = _c("night", 0.45)
	var b1: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_1")
	var b2: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_2")
	var b3: bool = Lx.state != null and Lx.state.lit_beacons.has("beacon_8_3")
	var lit_n: int = (1 if b1 else 0) + (1 if b2 else 0) + (1 if b3 else 0)
	var gate_open: bool = _is_flag_active("door_dungeon_8|visited:8:sanctum_r1|island_8_relit")
	_draw_carved_rune_ring(p, 18.0, _c("gold" if lit_n == 3 else "mauve", 0.52 * asc), c_rec, 18, 0.0)
	for si: int in range(3):
		var is_l: bool = (b1 if si == 0 else (b2 if si == 1 else b3))
		var ck: String = "gold" if is_l else ("sky" if si == 0 else ("jade" if si == 1 else "coral"))
		var base_a: float = deg_to_rad(180.0 if si == 0 else (60.0 if si == 1 else 300.0))
		for k: int in range(-2, 3):
			var sp: Vector2 = (p + Vector2.from_angle(base_a + float(k) * 0.22) * 18.0).round()
			draw_rect(Rect2(sp, Vector2(2.0, 2.0) if is_l else Vector2.ONE), _c(ck, (0.90 if is_l else 0.58) * asc))
	_draw_carved_rune_ring(p, 10.0, _c("cream" if lit_n == 3 else "gold", (0.78 if lit_n > 0 else 0.30) * asc), c_rec, 10, st * 0.2)
	if lit_n > 0 and not _is_flag_active("island_8_relit"):
		var u: float = fposmod(st * ((0.35 if fred else 0.55) if gate_open else (0.75 if fred else 1.25)), 1.0)
		for k: int in range(lit_n):
			draw_rect(Rect2(Vector2(p.x + float(k - 1) * 3.0, lerpf(p.y - 16.0, 168.0, fposmod(u + float(k) / float(lit_n), 1.0))).round(), Vector2(2.0, 2.0)), _c("cream", (0.50 if gate_open else 0.86) * asc))

func _draw_vent_petals(cam_rect: Rect2, st: float, fred: bool, wick: LxWick) -> void:
	if _is_flag_active("tut_vent_dashed|island_6_relit"): return
	if wick == null or wick.move_sunflare == null or not wick.move_sunflare.unlocked or wick.ember >= wick.move_sunflare.get_ember_max() - 0.5: return
	var br: LxBiomeRules = LxBiomeRules.active_instance
	if br == null or not is_instance_valid(br): return
	var asc: float = 0.72 if fred else 1.0
	for v: Dictionary in br._vents:
		var p: Vector2 = v["pos"] as Vector2
		if not cam_rect.has_point(p) or fposmod(br.vent_cycle + float(v["phase"]), 1.0) < 0.56: continue
		for side: int in range(-1, 2, 2):
			var u: float = fposmod(st * (0.9 if fred else 1.6) + (0.0 if side < 0 else 0.5), 1.0)
			var ep: Vector2 = (p + Vector2(float(side) * 9.0 + sin(u * 4.0) * 1.5, -2.0 - u * 14.0)).round()
			draw_rect(Rect2(ep, Vector2(2.0 if u < 0.35 else 1.0, 1.0)), _c("cream" if u < 0.35 else "gold", sin(u * PI) * asc))

func _sample_poly(pts: PackedVector2Array, cum: PackedFloat32Array, total_len: float, dist: float) -> Vector2:
	if dist < 0.0 or dist > total_len: return Vector2(-99999.0, -99999.0)
	for i: int in range(pts.size() - 1):
		if dist >= cum[i] and dist <= cum[i + 1] and cum[i + 1] > cum[i]: return pts[i].lerp(pts[i + 1], (dist - cum[i]) / (cum[i + 1] - cum[i])).round()
	return Vector2(-99999.0, -99999.0)

func _is_flag_active(key: String) -> bool:
	if key.is_empty() or _region == null: return false
	if key.find("|") >= 0:
		for branch: String in key.split("|"):
			if _is_flag_active(branch): return true
		return false
	if key.find("&") >= 0:
		for term: String in key.split("&"):
			if not _is_flag_active(term): return false
		return true
	if key.begins_with("visited:"): return Lx.state != null and Lx.state.visited_regions.has(key.substr(8))
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
	if it is LxChest: return (it as LxChest).opened
	return (it as LxDoor).opened if it is LxDoor else false
