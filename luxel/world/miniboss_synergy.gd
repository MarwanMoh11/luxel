class_name LxMinibossSynergy
extends RefCounted
## Interactive flanking Biome Resonance Anchors inside all 8 Mini-Boss Arenas
## (belfry_r5, lighthouse_r6, oak_r6, conservatory_r6, orrery_r6, kiln_r6, spire_r6, sanctum_r4).
## Island 1: grounded Brass Sanctuary Bell Pedestals with 120px shield-cracking Sonic Shockwave.

const PAL: Dictionary = LxPalette.PAL
const BELL_SHOCK_R: float = 120.0
const BELL_CD: float = 5.5
const DEFAULT_CD: float = 6.0
const WALK_TILES: PackedStringArray = ["ground", "path", "bridge"]

var _rules: LxBiomeRules = null
var _mech: LxBiomeMechanics = null
var _region: Node = null
var _island_id: int = 1
var _center: Vector2 = Vector2.ZERO
var _anchors: Array[Dictionary] = [] # {pos, cd, max_cd, flash_t, ready_t}
var _was_live: bool = false
var _victory_t: float = 0.0

func configure(rules: LxBiomeRules, mech: LxBiomeMechanics, region_node: Node, center: Vector2) -> void:
	_rules = rules; _mech = mech; _region = region_node
	_island_id = rules.island_id if rules != null else 1
	_center = center.round(); _anchors.clear(); _was_live = false; _victory_t = 0.0
	if rules == null: return
	var safe: Rect2 = rules.bounds.grow(-34.0)
	var span_x: float = minf(76.0, maxf(44.0, safe.size.x * 0.28))
	var base_cd: float = BELL_CD if _island_id == 1 else DEFAULT_CD
	var placed: Array[Vector2] = []
	for sx: float in [-span_x, span_x]:
		var ideal := Vector2(clampf(center.x + sx, safe.position.x, safe.end.x), clampf(center.y, safe.position.y, safe.end.y))
		var pt: Vector2 = _snap_open_floor(ideal, placed)
		placed.append(pt)
		_anchors.append({"pos": pt, "cd": 0.0, "max_cd": base_cd, "flash_t": 0.0, "ready_t": 0.0})

func _snap_open_floor(target: Vector2, placed: Array[Vector2]) -> Vector2:
	if _region == null or not is_instance_valid(_region): return target.round()
	var grid_v: Variant = _region.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty(): return _fallback_walkable(target)
	var grid: Array = grid_v as Array
	var h: int = grid.size()
	var w: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(_region.get("tile_size")) if (_region.get("tile_size") != null and float(_region.get("tile_size")) > 0.0) else 16.0
	var has_walk_fn: bool = _region.has_method("is_walkable")
	var spawn_p: Vector2 = _region.get("spawn_pos") as Vector2 if _region.get("spawn_pos") is Vector2 else Vector2.ZERO
	var exit_rects: Array[Rect2] = []
	if _region.get("exits") is Array:
		for ex_v: Variant in (_region.get("exits") as Array):
			if ex_v is Dictionary:
				var er: Rect2 = LxMapFormat.to_rect2((ex_v as Dictionary).get("rect", []))
				if er.has_area(): exit_rects.append(er.grow(28.0))
	var inter_pts: Array[Vector2] = []
	if _region.has_method("get_interactables"):
		var iv: Variant = _region.call("get_interactables")
		if iv is Array:
			for it_v: Variant in (iv as Array):
				if it_v is Node2D and is_instance_valid(it_v):
					var ip_v: Variant = (it_v as Object).get("pos")
					inter_pts.append(ip_v as Vector2 if ip_v is Vector2 else (it_v as Node2D).global_position)
	var empty_pts: Array[Vector2] = []
	for req_clear: bool in [true, false]:
		var best_pt: Vector2 = Vector2.ZERO
		var best_d2: float = 1e18
		for ty: int in range(h):
			for tx: int in range(w):
				if not _is_walk_tile(grid, w, h, tx, ty) or (req_clear and not _has_tile_clearance(grid, w, h, tx, ty)): continue
				var pt := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts).round()
				if has_walk_fn and not bool(_region.call("is_walkable", pt)): continue
				if not _point_clear_of(pt, spawn_p, exit_rects, placed, inter_pts if req_clear else empty_pts): continue
				var d2: float = pt.distance_squared_to(target)
				if d2 < best_d2: best_d2 = d2; best_pt = pt
		if best_d2 < 1e17: return best_pt
	return _fallback_walkable(target)

func _fallback_walkable(target: Vector2) -> Vector2:
	if _region == null or not is_instance_valid(_region): return target.round()
	var has_walk: bool = _region.has_method("is_walkable")
	if not has_walk and not _region.has_method("tile_at"): return target.round()
	for off: Vector2 in [Vector2.ZERO, Vector2(0.0, -16.0), Vector2(0.0, 16.0), Vector2(-16.0, 0.0), Vector2(16.0, 0.0)]:
		var pt: Vector2 = (target + off).round()
		if bool(_region.call("is_walkable", pt)) if has_walk else WALK_TILES.has(str(_region.call("tile_at", pt))): return pt
	return target.round()

static func _is_walk_tile(grid: Array, w: int, h: int, tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < w and ty < h and WALK_TILES.has((grid[ty] as PackedStringArray)[tx])

static func _has_tile_clearance(grid: Array, w: int, h: int, tx: int, ty: int) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not _is_walk_tile(grid, w, h, tx + dx, ty + dy): return false
	return true

static func _point_clear_of(pt: Vector2, spawn_p: Vector2, exit_rects: Array[Rect2], placed: Array[Vector2], inter_pts: Array[Vector2]) -> bool:
	if spawn_p != Vector2.ZERO and pt.distance_to(spawn_p) < 36.0: return false
	for er: Rect2 in exit_rects:
		if er.has_point(pt): return false
	for op: Vector2 in placed:
		if pt.distance_to(op) < 48.0: return false
	for ip: Vector2 in inter_pts:
		if pt.distance_to(ip) < 24.0: return false
	return true

func tick(dt: float, live: bool) -> void:
	if _victory_t > 0.0: _victory_t = maxf(0.0, _victory_t - dt)
	if _was_live and not live:
		_victory_t = 0.68
		if Lx.audio != null and _island_id in [1, 2, 5, 8]:
			var vsfx: String = "bell_toll" if _island_id in [1, 8] else ("lighthouse_toll" if _island_id == 2 else "clockwork_chime")
			Lx.audio.play_sfx(vsfx, _center, true)
	_was_live = live
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var act: bool = w != null and not w.dead and (w.is_dashing() or w.is_gliding() or w.is_zipping())
	var lp: Vector2 = w.lantern.pos if (w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out()) else Vector2(-9999.0, -9999.0)
	for anc: Dictionary in _anchors:
		var prev_cd: float = float(anc["cd"])
		anc["cd"] = maxf(0.0, prev_cd - dt)
		anc["flash_t"] = maxf(0.0, float(anc["flash_t"]) - dt)
		anc["ready_t"] = maxf(0.0, float(anc["ready_t"]) - dt)
		var ap: Vector2 = anc["pos"] as Vector2
		if live and prev_cd > 0.0 and float(anc["cd"]) <= 0.0:
			anc["ready_t"] = 0.42
			if _island_id == 1 and Lx.audio != null: Lx.audio.play_sfx("prop_chime", ap, true)
			elif _island_id >= 2 and Lx.audio != null: Lx.audio.play_sfx(_ready_sfx_for(_island_id), ap, true)
		if not live or float(anc["cd"]) > 0.0: continue
		var hc: Vector2 = ap + Vector2(0.0, -4.0) if _island_id == 1 else ap + Vector2(0.0, -5.0)
		if (act and (w.global_position.distance_to(ap) <= 24.0 or w.global_position.distance_to(hc) <= 24.0)) \
				or lp.distance_to(ap) <= 22.0 or lp.distance_to(hc) <= 22.0:
			_activate(anc, w)

func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick, live: bool) -> bool:
	if not live: return false
	for anc: Dictionary in _anchors:
		if float(anc["cd"]) > 0.0: continue
		var ap: Vector2 = anc["pos"] as Vector2
		var hc: Vector2 = ap + Vector2(0.0, -5.0)
		if Geometry2D.get_closest_point_to_segment(hc, from_p, to_p).distance_to(hc) <= 17.0:
			_activate(anc, w); return true
	return false

static func _ready_sfx_for(id: int) -> String:
	match id:
		2: return "lighthouse_toll"
		5: return "clockwork_chime"
		6: return "forge_gust"
		7: return "lens_reveal"
		_: return "prop_chime"

func _activate(anc: Dictionary, w: LxWick) -> void:
	var ap: Vector2 = anc["pos"] as Vector2
	var is_bell: bool = _island_id == 1
	anc["cd"] = BELL_CD if is_bell else DEFAULT_CD
	anc["max_cd"] = BELL_CD if is_bell else DEFAULT_CD
	anc["flash_t"] = 0.58 if is_bell else 0.52
	var sfx_id: String = "prop_chime"
	var decal_k: int = LxGroundDecals.Kind.PRISM_STAR
	var burst_r: float = 86.0
	match _island_id:
		1:
			sfx_id = "bell_toll"; decal_k = LxGroundDecals.Kind.BLOSSOM; burst_r = 128.0
			_fire_bell_shockwave(ap, w)
		2:
			sfx_id = "lighthouse_toll"; decal_k = LxGroundDecals.Kind.RIPPLE; burst_r = 105.0
			if _rules != null: _rules.beam_buff_t = maxf(_rules.beam_buff_t, 3.0)
			_fire_island2_pulse(ap, w)
		3:
			sfx_id = "spore_pop"; decal_k = LxGroundDecals.Kind.BLOSSOM; burst_r = 110.0
			if _mech != null and is_instance_valid(_mech): _mech.on_bloom_ignited(ap, false)
			_fire_island3_wave(ap, w)
		4:
			sfx_id = "wing_gale"; decal_k = LxGroundDecals.Kind.RIPPLE; burst_r = 115.0
			if _mech != null and is_instance_valid(_mech): _mech.tailwind_t = maxf(_mech.tailwind_t, 2.8)
			if w != null and is_instance_valid(w) and w.is_gliding() and w.move_wings != null:
				w.move_wings.glide_time_left = w.move_wings.glide_duration; w.move_wings.glide_dist_left = w.move_wings.glide_max_px
			_fire_island4_gust(ap, w)
		5:
			sfx_id = "clockwork_chime"; decal_k = LxGroundDecals.Kind.PRISM_STAR; burst_r = 120.0
			if _rules != null: _rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 3.2)
			_fire_island5_pulse(ap, w)
		6:
			sfx_id = "forge_gust"; decal_k = LxGroundDecals.Kind.SCORCH; burst_r = 96.0
			if _mech != null and is_instance_valid(_mech): _mech.grant_molten_overdrive(2)
			if w != null and is_instance_valid(w) and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 18.0)
			_fire_island6_blast(ap, w)
		7:
			sfx_id = "lens_reveal"; decal_k = LxGroundDecals.Kind.PRISM_STAR; burst_r = 110.0
			if _rules != null: _rules.lunar_phase = 1.0; _rules.clock = 0.0
			_fire_island7_flash(ap, w)
		8:
			sfx_id = "bell_toll"; decal_k = LxGroundDecals.Kind.BLOSSOM; burst_r = 118.0
			if w != null and is_instance_valid(w) and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 12.0)
			_fire_island8_wave(ap, w)
	if w != null and is_instance_valid(w):
		w.spawn_ring(ap, 6.0 if is_bell else 4.0, 56.0 if is_bell else 26.0, 0.34 if is_bell else 0.28, LxBiomePalette.col(_island_id, "glow"), 1.8 if is_bell else 1.5)
	if Lx.audio != null: Lx.audio.play_sfx(sfx_id, ap, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(ap, burst_r, 0.85 if LxHudFx.flash_reduced() else 1.32, 0.48 if is_bell else 0.42)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(decal_k, ap, 18.0 if is_bell else 14.0, 5.5)

func _get_enemies() -> Array:
	if _region == null or not _region.has_method("get_enemies"): return []
	var ev: Variant = _region.call("get_enemies")
	return ev as Array if ev is Array else []

func _fire_bell_shockwave(origin: Vector2, w: LxWick) -> void:
	if w != null and is_instance_valid(w):
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 5.0)
		w.spawn_ring(origin, 4.0, BELL_SHOCK_R, 0.40, PAL["cream"] as Color, 1.4)
		w.spawn_sparks(origin + Vector2(0.0, -8.0), Vector2.UP, 8, PAL["gold"] as Color, 34.0, 108.0, 0.28)
	if Lx.events != null: Lx.events.hitstop_requested.emit(0.045); Lx.events.shake_requested.emit(0.18)
	elif Lx.hitstop != null: Lx.hitstop.trigger(0.045)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > BELL_SHOCK_R: continue
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		var sh_v: Variant = e.get("shield_hp")
		var sg_v: Variant = e.get("shield_gone_t")
		var sh_before: float = float(sh_v) if (sh_v != null and (sg_v == null or float(sg_v) <= 0.0)) else 0.0
		var hit: LxHit = LxHit.make(LxHit.SOURCE_DASH, 0.55, kdir, origin, 1.6, true, false, w, false)
		var res: int = e.take_hit(hit)
		if sh_before > 0.01 and e.is_alive():
			if float(e.get("shield_hp")) >= sh_before - 0.001 and e.has_method("_wear_shield"):
				if not bool(e.call("_wear_shield", 1.6)):
					e.clank_t = 0.18
					if Lx.audio != null: Lx.audio.play_sfx("shield_strain", e.pos, true)
			if res == LxEnemyBrain.HitResult.BLOCKED: e.knock += kdir * 48.0
		if not e.is_boss and e.is_alive(): e.knock += kdir * 52.0
		if w != null and is_instance_valid(w):
			w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 6, PAL["gold"] as Color, 32.0, 96.0, 0.24)

func _has_shielded_foe() -> bool:
	for e_v: Variant in _get_enemies():
		if e_v is LxEnemyBrain and is_instance_valid(e_v) and (e_v as LxEnemyBrain).is_alive():
			var sh_v: Variant = (e_v as Object).get("shield_hp")
			var sg_v: Variant = (e_v as Object).get("shield_gone_t")
			if sh_v != null and float(sh_v) > 0.01 and (sg_v == null or float(sg_v) <= 0.0): return true
	return false

func draw_anchors(canvas: CanvasItem, clock: float, fred: bool, cleared: bool) -> void:
	var c_hi: Color = LxBiomePalette.col(_island_id, "hi")
	var c_gl: Color = LxBiomePalette.col(_island_id, "glow")
	var cream: Color = PAL["cream"] as Color
	if _victory_t > 0.0 and _center != Vector2.ZERO:
		var vu: float = 1.0 - clampf(_victory_t / 0.68, 0.0, 1.0)
		var va: float = (1.0 - vu) * (0.55 if fred else 0.88)
		canvas.draw_arc(_center, roundf(lerpf(10.0, 86.0, vu)), 0.0, TAU, 24, Color(c_gl, va), 1.8)
		canvas.draw_arc(_center, roundf(lerpf(6.0, 58.0, vu)), 0.0, TAU, 18, Color(cream, va), 1.2)
		for vk: int in range(6):
			var vpt: Vector2 = (_center + Vector2.from_angle(float(vk) * (TAU / 6.0) + vu * 0.55) * lerpf(8.0, 66.0, vu)).round()
			canvas.draw_rect(Rect2(vpt - Vector2.ONE, Vector2(2.0, 2.0)), Color(cream if vk % 2 == 0 else c_hi, va))
	var shield_up: bool = (_island_id == 1) and (not cleared) and _has_shielded_foe()
	var boss_pulse: bool = (_island_id >= 2) and (not cleared) and _has_boss_pulse_state()
	for anc: Dictionary in _anchors:
		if _island_id == 1: _draw_bell_pedestal(canvas, anc, clock, fred, cleared, shield_up)
		else:
			var cd_i: float = float(anc["cd"])
			var cd_f: float = clampf(1.0 - cd_i / maxf(0.1, float(anc.get("max_cd", DEFAULT_CD))), 0.0, 1.0)
			LxMinibossPedestalArt.draw_island_pedestal(canvas, _island_id, anc["pos"] as Vector2, (not cleared) and cd_i <= 0.0, cd_f, boss_pulse, clock, cleared, fred, float(anc["flash_t"]), float(anc.get("ready_t", 0.0)))

func _draw_bell_pedestal(canvas: CanvasItem, anc: Dictionary, clock: float, fred: bool, cleared: bool, shield_up: bool) -> void:
	var ap: Vector2 = (anc["pos"] as Vector2).round()
	var cd: float = float(anc["cd"])
	var ft: float = float(anc["flash_t"])
	var rt: float = float(anc.get("ready_t", 0.0))
	var rdy: bool = (not cleared) and cd <= 0.0
	var pulse: float = 0.0 if fred else sin(clock * (4.8 if shield_up else 2.8) + ap.x * 0.03)
	var sway: float = 0.0 if (fred or cleared) else (roundf(sin(clock * 26.0) * 2.5 * (ft / 0.58)) if ft > 0.0 else (roundf(sin(clock * 4.2 + ap.x * 0.02) * 0.9) if (rdy and shield_up) else 0.0))
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var sh_c := Color(PAL["void"] as Color, 0.40)
	canvas.draw_rect(Rect2(ap + Vector2(-9.0, 0.0), Vector2(18.0, 3.0)), sh_c); canvas.draw_rect(Rect2(ap + Vector2(-7.0, -1.0), Vector2(14.0, 5.0)), sh_c)
	if rdy:
		var ra: float = (0.58 if shield_up else 0.34) + (0.0 if fred else pulse * (0.20 if shield_up else 0.08))
		canvas.draw_arc(ap + Vector2(0.0, 1.0), roundf(11.0 + (pulse * 1.2 if shield_up else 0.0)), 0.0, TAU, 18, Color(gold, clampf(ra, 0.2, 0.85)), 1.4 if shield_up else 1.0)
	elif not cleared:
		var prog: float = clampf(1.0 - cd / maxf(0.1, float(anc.get("max_cd", BELL_CD))), 0.0, 1.0)
		canvas.draw_arc(ap + Vector2(0.0, 1.0), 10.0, 0.0, TAU, 16, Color(PAL["dusk"] as Color, 0.45), 1.0)
		canvas.draw_arc(ap + Vector2(0.0, 1.0), 10.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 16, Color(PAL["apricot"] as Color, 0.65), 1.2)
	var st_hi: Color = (PAL["stone"] if rdy else PAL["mauve"]) as Color
	var beam_c: Color = (PAL["apricot"] if rdy else PAL["mauve"]) as Color
	var night_c: Color = PAL["night"] as Color
	var dusk_c: Color = PAL["dusk"] as Color
	canvas.draw_rect(Rect2(ap + Vector2(-8.0, -1.0), Vector2(16.0, 3.0)), night_c); canvas.draw_rect(Rect2(ap + Vector2(-7.0, -3.0), Vector2(14.0, 3.0)), dusk_c)
	canvas.draw_rect(Rect2(ap + Vector2(-6.0, -4.0), Vector2(12.0, 1.0)), st_hi)
	canvas.draw_rect(Rect2(ap + Vector2(-6.0, -14.0), Vector2(2.0, 10.0)), night_c); canvas.draw_rect(Rect2(ap + Vector2(4.0, -14.0), Vector2(2.0, 10.0)), night_c)
	canvas.draw_rect(Rect2(ap + Vector2(-5.0, -13.0), Vector2(1.0, 9.0)), dusk_c); canvas.draw_rect(Rect2(ap + Vector2(4.0, -13.0), Vector2(1.0, 9.0)), dusk_c)
	canvas.draw_rect(Rect2(ap + Vector2(-7.0, -15.0), Vector2(14.0, 2.0)), (PAL["wine"] if rdy else PAL["dusk"]) as Color)
	canvas.draw_rect(Rect2(ap + Vector2(-6.0, -15.0), Vector2(12.0, 1.0)), beam_c); canvas.draw_rect(Rect2(ap + Vector2(-1.0, -17.0), Vector2(2.0, 2.0)), gold if rdy else st_hi)
	var bc: Vector2 = (ap + Vector2(sway, -9.0)).round()
	var b_sh: Color = (PAL["wine"] if rdy else (PAL["plum"] if not cleared else PAL["dusk"])) as Color
	var b_mid: Color = (PAL["coral"] if rdy else PAL["mauve"]) as Color
	var b_rim: Color = cream if ft > 0.35 else (gold if rdy else ((PAL["stone"] if cleared else PAL["mauve"]) as Color))
	canvas.draw_rect(Rect2(bc + Vector2(-1.0, -4.0), Vector2(2.0, 2.0)), beam_c); canvas.draw_rect(Rect2(bc + Vector2(-2.0, -3.0), Vector2(4.0, 2.0)), b_sh)
	canvas.draw_rect(Rect2(bc + Vector2(-3.0, -1.0), Vector2(6.0, 3.0)), b_sh); canvas.draw_rect(Rect2(bc + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), b_mid)
	canvas.draw_rect(Rect2(bc + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), b_rim); canvas.draw_rect(Rect2(bc + Vector2(-2.0, -2.0), Vector2(1.0, 3.0)), cream if (rdy or ft > 0.0) else st_hi)
	canvas.draw_rect(Rect2(bc + Vector2(-3.0, 3.0), Vector2(6.0, 1.0)), PAL["void"] as Color)
	canvas.draw_rect(Rect2(bc + Vector2(-1.0, 3.0), Vector2(2.0, 2.0)), cream if ft > 0.25 else (gold if rdy else (PAL["mauve"] as Color)))
	if rdy:
		var wa: float = (0.72 if shield_up else 0.42) * (0.75 if fred else (0.85 + 0.15 * pulse))
		var wr1: float = roundf(8.5 + (0.0 if fred else fposmod(clock * 4.5, 3.0)))
		for side_a: float in [0.0, PI]:
			canvas.draw_arc(bc, wr1, side_a - 0.52, side_a + 0.52, 6, Color(cream if shield_up else gold, wa), 1.2)
			if shield_up:
				var wr2: float = roundf(12.0 + (0.0 if fred else fposmod(clock * 4.5 + 1.5, 3.5)))
				canvas.draw_arc(bc, wr2, side_a - 0.44, side_a + 0.44, 6, Color(gold, wa * 0.72), 1.0)
	if rt > 0.0 and not cleared:
		var ru: float = 1.0 - clampf(rt / 0.42, 0.0, 1.0)
		canvas.draw_arc(bc, roundf(lerpf(6.0, 22.0, ru)), 0.0, TAU, 16, Color(gold, (1.0 - ru) * 0.65), 1.1)
	if ft > 0.0:
		var u: float = 1.0 - clampf(ft / 0.58, 0.0, 1.0)
		var fa: float = (1.0 - u) * (0.58 if fred else 0.92)
		var r_out: float = roundf(lerpf(10.0, BELL_SHOCK_R, u))
		canvas.draw_arc(ap, r_out, 0.0, TAU, 32, Color(gold, fa), 2.2)
		canvas.draw_arc(ap, maxf(2.0, r_out - 3.0), 0.0, TAU, 28, Color(PAL["apricot"] as Color, fa * 0.72), 1.2)
		canvas.draw_arc(ap, roundf(lerpf(6.0, BELL_SHOCK_R * 0.76, u)), 0.0, TAU, 24, Color(cream, fa * 0.85), 1.3)
		for k: int in range(8):
			var kp: Vector2 = (ap + Vector2.from_angle(float(k) * (TAU / 8.0) + u * 0.45) * r_out).round()
			canvas.draw_rect(Rect2(kp - Vector2.ONE, Vector2(2.0, 2.0)), Color(cream if k % 2 == 0 else gold, fa))

func _pulse_impact(origin: Vector2, w: LxWick, rad: float, ring_c: Color, spark_c: Color, hs: float, shake: float) -> void:
	if w != null and is_instance_valid(w):
		w.spawn_ring(origin, 4.0, rad, 0.38, ring_c, 1.5)
		w.spawn_sparks(origin + Vector2(0.0, -9.0), Vector2.UP, 8, spark_c, 30.0, 98.0, 0.26)
	if Lx.events != null:
		if hs > 0.0: Lx.events.hitstop_requested.emit(hs)
		Lx.events.shake_requested.emit(shake)
	elif hs > 0.0 and Lx.hitstop != null: Lx.hitstop.trigger(hs)

static func _active_shield_hp(e: LxEnemyBrain) -> float:
	var sh_v: Variant = e.get("shield_hp")
	var sg_v: Variant = e.get("shield_gone_t")
	return float(sh_v) if (sh_v != null and (sg_v == null or float(sg_v) <= 0.0)) else 0.0

static func _apply_extra_shield_wear(e: LxEnemyBrain, sh_before: float, wear: float) -> void:
	if sh_before <= 0.01 or not e.is_alive(): return
	if e.has_method("_is_hit_invulnerable") and bool(e.call("_is_hit_invulnerable")): return # Never break a shield mid phase-roar
	if float(e.get("shield_hp")) >= sh_before - 0.001 and e.has_method("_wear_shield"):
		if not bool(e.call("_wear_shield", wear)):
			e.clank_t = 0.18
			if Lx.audio != null: Lx.audio.play_sfx("shield_strain", e.pos, true)

func _fire_island2_pulse(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 105.0, PAL["ice"] as Color, PAL["sky"] as Color, 0.035, 0.15)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 105.0: continue
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		e.take_hit(LxHit.make(LxHit.SOURCE_PRISM, 0.5, kdir, origin, 1.0, true, false, w, false, LxHit.COLOR_BLUE))
		if not e.is_boss and e.is_alive(): e.knock += kdir * 48.0
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 5, PAL["ice"] as Color, 28.0, 88.0, 0.22)

func _fire_island3_wave(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 110.0, PAL["lime"] as Color, PAL["gold"] as Color, 0.035, 0.14)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 110.0: continue
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		var was_burrowed: bool = e.get("burrowed") == true
		var hit_src: String = LxHit.SOURCE_BEAM if was_burrowed else LxHit.SOURCE_DASH
		e.take_hit(LxHit.make(hit_src, 0.5, kdir, origin, 0.0, was_burrowed, was_burrowed, w, false))
		if was_burrowed and e.is_alive() and not (e.get("_roaring") == true):
			e.set("burrowed", false)
			if e.get("combat_burrowing") != null: e.set("combat_burrowing", false)
			if e.get("cap_open") != null: e.set("cap_open", true)
			if e.has_method("_release_token"): e.call("_release_token")
			e.state = LxEnemyBrain.State.STAGGER
			e.state_timer = maxf(e.state_timer, 0.9)
		if not e.is_boss and e.is_alive(): e.knock += kdir * 72.0
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 5, PAL["lime"] as Color, 28.0, 88.0, 0.22)

func _fire_island4_gust(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 115.0, PAL["rose"] as Color, PAL["ice"] as Color, 0.025, 0.12)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive(): continue
		var in_range: bool = e.pos.distance_to(origin) <= 115.0
		var pv: Variant = e.get("petals")
		if pv is Array:
			var arr: Array = pv as Array
			for pi: int in range(arr.size() - 1, -1, -1):
				var pd: Variant = arr[pi]
				var pp: Vector2 = (pd as Dictionary).get("pos", e.pos) as Vector2 if pd is Dictionary else e.pos
				if in_range or pp.distance_to(origin) <= 115.0:
					if w != null and is_instance_valid(w): w.spawn_sparks(pp, Vector2.UP, 3, PAL["rose"] as Color, 20.0, 56.0, 0.18)
					arr.remove_at(pi)
		if not in_range: continue
		var hz_v: Variant = e.get("hop_z")
		if hz_v == null or float(hz_v) <= 1.0:
			var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
			e.take_hit(LxHit.make(LxHit.SOURCE_DASH, 0.45, kdir, origin, 0.0, false, false, w, false))
			if not e.is_boss and e.is_alive(): e.knock += kdir * 52.0
			if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 4, PAL["ice"] as Color, 24.0, 72.0, 0.20)

func _fire_island5_pulse(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 120.0, PAL["gold"] as Color, PAL["sky"] as Color, 0.035, 0.14)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 120.0: continue
		if e.get("lens_pause_t") != null: e.set("lens_pause_t", maxf(float(e.get("lens_pause_t")), 1.4))
		if e.get("lens_highlight_t") != null: e.set("lens_highlight_t", maxf(float(e.get("lens_highlight_t")), 3.2))
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		e.take_hit(LxHit.make(LxHit.SOURCE_PRISM, 0.45, kdir, origin, 0.0, false, true, w, false))
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 5, PAL["sky"] as Color, 28.0, 86.0, 0.22)

func _fire_island6_blast(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 96.0, PAL["coral"] as Color, PAL["gold"] as Color, 0.04, 0.16)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 96.0: continue
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		e.take_hit(LxHit.make(LxHit.SOURCE_DASH, 0.5, kdir, origin, 0.9, true, false, w, true))
		if not e.is_boss and e.is_alive(): e.knock += kdir * 54.0
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 6, PAL["apricot"] as Color, 32.0, 96.0, 0.24)

func _fire_island7_flash(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 110.0, PAL["ice"] as Color, PAL["sky"] as Color, 0.035, 0.15)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 110.0: continue
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		var sh_before: float = _active_shield_hp(e)
		var res: int = e.take_hit(LxHit.make(LxHit.SOURCE_PRISM, 0.5, kdir, origin, 1.4, true, false, w, false, LxHit.COLOR_BLUE))
		_apply_extra_shield_wear(e, sh_before, 1.4)
		if res == LxEnemyBrain.HitResult.BLOCKED: e.knock += kdir * 42.0
		if not e.is_boss and e.is_alive(): e.knock += kdir * 48.0
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 5, PAL["ice"] as Color, 28.0, 90.0, 0.22)

func _fire_island8_wave(origin: Vector2, w: LxWick) -> void:
	_pulse_impact(origin, w, 118.0, PAL["gold"] as Color, PAL["rose"] as Color, 0.045, 0.18)
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or e.pos.distance_to(origin) > 118.0: continue
		if e.get("blink_slash_attack") == true:
			e.set("echo_fired", true); e.set("echo_hit", true)
		var kdir: Vector2 = (e.pos - origin).normalized() if e.pos.distance_to(origin) > 1.0 else Vector2.RIGHT
		var sh_before: float = _active_shield_hp(e)
		var res: int = e.take_hit(LxHit.make(LxHit.SOURCE_DASH, 0.55, kdir, origin, 1.5, true, false, w, false))
		_apply_extra_shield_wear(e, sh_before, 1.5)
		if res == LxEnemyBrain.HitResult.BLOCKED: e.knock += kdir * 48.0
		if not e.is_boss and e.is_alive(): e.knock += kdir * 52.0
		if w != null and is_instance_valid(w): w.spawn_sparks(e.pos + Vector2(0.0, -4.0), kdir, 6, PAL["gold"] as Color, 32.0, 96.0, 0.24)

func _has_boss_pulse_state() -> bool:
	if _island_id == 7 and _rules != null and _rules.lunar_phase < 0.65: return true
	for e_v: Variant in _get_enemies():
		if not (e_v is LxEnemyBrain and is_instance_valid(e_v)): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive(): continue
		match _island_id:
			2, 7:
				if _active_shield_hp(e) > 0.01: return true
			3:
				if e.get("burrowed") == true: return true
			4:
				var pv: Variant = e.get("petals")
				if pv is Array and not (pv as Array).is_empty(): return true
			5:
				if e.get("lens_pause_t") != null and float(e.get("lens_pause_t")) <= 0.0: return true
			6:
				if e.get("armour_intact") == true: return true
			8:
				if _active_shield_hp(e) > 0.01 or e.get("blink_slash_attack") == true: return true
	return false
