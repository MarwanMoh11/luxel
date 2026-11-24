class_name LxBiomeDiscoveries
extends Node2D
## Bespoke interactive overworld micro-discoveries across Islands 2..8 (complementing Island 1 LxBellChimes),
## silent knowledge-gated True-Lens backtrack secret breadcrumbs on early overworlds (Islands 1..4),
## and foreground Okami-style Living World-Healing Keepsakes + Island 8 Rose-Window Shafts (Islands 1..8).
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL); zero blocking collision.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 196.0
const HALF_H: float = 124.0
const LENS_SECRET_RADIUS: float = 64.0
const LENS_SECRET_SHARDS: int = 12

static var active_instance: LxBiomeDiscoveries = null

var _rules: LxBiomeRules = null
var _island_id: int = 1
var _active: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _door_pos: Vector2 = Vector2.ZERO
var _spawn_pos: Vector2 = Vector2.ZERO
var _landmark_pos: Vector2 = Vector2.ZERO
var _nodes: Array[Dictionary] = [] # {pos, anim_t, cd, found, phase}
var _rings: Array[Dictionary] = [] # {pos, age, dur, col}
var _lens_secret: Dictionary = {}  # {pos, shore_pos, claimed, burst_t, phase} on Islands 1..4
var _hint_dir: Vector2 = Vector2.ZERO
var _hint_alpha: float = 0.0
var _hint_wick_pos: Vector2 = Vector2.ZERO
var _hint_pulse_cd: float = 1.2


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func configure(rules: LxBiomeRules, region_node: Node, door_pos: Vector2) -> void:
	active_instance = self
	_rules = rules
	_island_id = rules.island_id if rules != null else 1
	_active = rules != null and not rules.is_dungeon and _island_id >= 1 and _island_id <= 8
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_door_pos = door_pos
	var sp_v: Variant = region_node.get("spawn_pos") if (region_node != null and is_instance_valid(region_node)) else null
	_spawn_pos = (sp_v as Vector2) if (sp_v is Vector2 and (sp_v as Vector2) != Vector2.ZERO) else _cam_center
	_landmark_pos = _pick_landmark_pos(region_node, _spawn_pos)
	_nodes.clear()
	_rings.clear()
	_lens_secret.clear()
	_hint_dir = Vector2.ZERO
	_hint_alpha = 0.0
	_hint_pulse_cd = 1.2
	if not _active or region_node == null or not is_instance_valid(region_node):
		queue_redraw()
		return
	if _island_id >= 2:
		_place_discoveries(region_node)
	if _island_id >= 1 and _island_id <= 4:
		_place_lens_secret(region_node)
	queue_redraw()


func _pick_landmark_pos(region_node: Node, spawn_p: Vector2) -> Vector2:
	var best: Vector2 = _cam_center
	if region_node == null or not is_instance_valid(region_node) or not region_node.has_method("get_interactables"):
		return best
	var items_v: Variant = region_node.call("get_interactables")
	if not (items_v is Array):
		return best
	var best_sc: float = -1.0
	for it: Variant in (items_v as Array):
		if not (it is LxInteractable) or not is_instance_valid(it):
			continue
		var obj: LxInteractable = it as LxInteractable
		var pri: float = 3.0 if obj.kind == "beacon" else (2.0 if obj.kind in ["shrine", "mirror", "blue_transformer", "obsidian_seal", "rest_shrine"] else (1.0 if obj.kind in ["waystone", "chest"] else 0.0))
		var d: float = obj.pos.distance_to(spawn_p)
		if pri > 0.0 and d >= 96.0:
			var sc: float = pri * 1000.0 - absf(d - 320.0)
			if sc > best_sc:
				best_sc = sc
				best = obj.pos
	return best


func _place_discoveries(region_node: Node) -> void:
	var grid_v: Variant = region_node.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		return
	var grid: Array = grid_v as Array
	var gh: int = grid.size()
	var gw: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(region_node.get("tile_size")) if region_node.get("tile_size") != null else 16.0
	var avoid: Array[Vector2] = _collect_avoid_positions(region_node)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(_island_id * 48271 + gw * 131 + gh * 71)
	var target_n: int = 5
	var tries: int = 0
	while _nodes.size() < target_n and tries < 320:
		tries += 1
		var tx: int = rng.randi_range(4, maxi(4, gw - 5))
		var ty: int = rng.randi_range(4, maxi(4, gh - 5))
		var row: PackedStringArray = grid[ty] as PackedStringArray
		if not (row[tx] in ["ground", "path"]):
			continue
		if not (row[tx - 1] in ["ground", "path"] and row[tx + 1] in ["ground", "path"]):
			continue
		var p := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts).round()
		var ok: bool = true
		for av: Vector2 in avoid:
			if av.distance_squared_to(p) < 2304.0: # >= 48 px clearance
				ok = false
				break
		if not ok:
			continue
		for prev: Dictionary in _nodes:
			if (prev["pos"] as Vector2).distance_squared_to(p) < 25600.0: # >= 160 px apart
				ok = false
				break
		if not ok:
			continue
		var idx: int = _nodes.size()
		var was_found: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_%d_%d" % [_island_id, idx], false))
		_nodes.append({
			"idx": idx,
			"pos": p,
			"anim_t": 0.0,
			"cd": 0.0,
			"found": was_found,
			"phase": rng.randf_range(0.0, TAU),
		})


func _place_lens_secret(region_node: Node) -> void:
	# Place 1 silent True-Lens backtrack starlight breadcrumb over a quiet water/cliff overlook (Islands 1..4)
	var grid_v: Variant = region_node.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		return
	var grid: Array = grid_v as Array
	var gh: int = grid.size()
	var gw: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(region_node.get("tile_size")) if region_node.get("tile_size") != null else 16.0
	var avoid: Array[Vector2] = _collect_avoid_positions(region_node)
	for nd: Dictionary in _nodes:
		avoid.append(nd["pos"] as Vector2)

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var best_score: float = -INF
	var best_overlook: Vector2 = Vector2.ZERO
	var best_shore: Vector2 = Vector2.ZERO
	for ty: int in range(2, gh - 2):
		var row: PackedStringArray = grid[ty] as PackedStringArray
		for tx: int in range(2, gw - 2):
			var t: String = row[tx]
			if not (t in ["water", "tide", "pit", "void"]):
				continue
			var shore_tile := Vector2i(-1, -1)
			var open_neighbors: int = 0
			for d: Vector2i in dirs:
				var nt: String = (grid[ty + d.y] as PackedStringArray)[tx + d.x]
				if nt in ["ground", "path"] and shore_tile.x < 0:
					shore_tile = Vector2i(tx + d.x, ty + d.y)
				elif nt in ["water", "tide", "pit", "void"]:
					open_neighbors += 1
			if shore_tile.x < 0 or open_neighbors < 2:
				continue
			var op := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts).round()
			var sp := Vector2((float(shore_tile.x) + 0.5) * ts, (float(shore_tile.y) + 0.5) * ts).round()
			var clear_ok: bool = true
			for av: Vector2 in avoid:
				if av.distance_squared_to(sp) < 3136.0: # >= 56 px from interactables/discoveries
					clear_ok = false
					break
			if not clear_ok:
				continue
			var dist_spawn: float = sp.distance_to(_spawn_pos)
			if dist_spawn < 112.0:
				continue
			var water_bonus: float = 40.0 if (t == "water" or t == "tide") else 0.0
			var quiet_score: float = water_bonus + float(open_neighbors) * 14.0 - absf(dist_spawn - 210.0) * 0.45
			if quiet_score > best_score:
				best_score = quiet_score
				best_overlook = op
				best_shore = sp
	if best_overlook != Vector2.ZERO:
		var claimed: bool = Lx.state != null and bool(Lx.state.story_flags.get("lens_secret_%d" % _island_id, false))
		_lens_secret = {
			"pos": best_overlook,
			"shore_pos": best_shore,
			"claimed": claimed,
			"burst_t": 0.0,
			"phase": float(_island_id) * 1.37,
		}


func _collect_avoid_positions(region_node: Node) -> Array[Vector2]:
	var avoid: Array[Vector2] = []
	if region_node.has_method("get_interactables"):
		var items_v: Variant = region_node.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if it is LxInteractable and is_instance_valid(it):
					avoid.append((it as LxInteractable).pos)
	return avoid


func get_found_count() -> int:
	var n: int = 0
	for nd: Dictionary in _nodes:
		if bool(nd["found"]):
			n += 1
	return n


func get_total_count() -> int:
	return _nodes.size()


func get_found_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for nd: Dictionary in _nodes:
		if bool(nd["found"]):
			out.append(nd["pos"] as Vector2)
	return out


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick) -> bool:
	if not _active or _nodes.is_empty():
		return false
	for nd: Dictionary in _nodes:
		if float(nd["cd"]) > 0.0:
			continue
		var cp: Vector2 = nd["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(cp, from_p, to_p).distance_to(cp) <= 14.0:
			_trigger_node(nd, w)
			return true
	return false


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if not _active or dt <= 0.0:
		return
	_clock += dt
	for i: int in range(_rings.size() - 1, -1, -1):
		var rg: Dictionary = _rings[i]
		rg["age"] = float(rg["age"]) + dt
		if float(rg["age"]) >= float(rg["dur"]):
			_rings.remove_at(i)

	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var wp: Vector2 = w.global_position if (w != null and not w.dead) else Vector2(-9999.0, -9999.0)
	var lp: Vector2 = Vector2(-9999.0, -9999.0)
	if w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out():
		lp = w.lantern.pos

	var relit_now: bool = Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var any_vis: bool = (not _rings.is_empty()) or relit_now or _island_id == 8
	_hint_pulse_cd = maxf(0.0, _hint_pulse_cd - dt)
	var best_unfound_d: float = 120.0
	var best_unfound_p: Vector2 = Vector2.ZERO
	for nd: Dictionary in _nodes:
		nd["anim_t"] = maxf(0.0, float(nd["anim_t"]) - dt)
		nd["cd"] = maxf(0.0, float(nd["cd"]) - dt)
		var cp: Vector2 = nd["pos"] as Vector2
		if absf(cp.x - _cam_center.x) <= HALF_W and absf(cp.y - _cam_center.y) <= HALF_H:
			any_vis = true
		if not bool(nd["found"]) and w != null and not w.dead:
			var ud: float = cp.distance_to(wp)
			if ud < best_unfound_d:
				best_unfound_d = ud
				best_unfound_p = cp
		if float(nd["cd"]) <= 0.0:
			var hit_r: float = 22.0 if (w != null and (w.is_dashing() or w.is_gliding())) else 16.0
			var hit_w: bool = w != null and not w.dead and cp.distance_to(wp) <= hit_r
			var hit_l: bool = cp.distance_to(lp) <= 22.0
			if hit_w or hit_l:
				_trigger_node(nd, w)
	if best_unfound_d < 116.0 and best_unfound_d > 26.0 and w != null and not w.dead:
		_hint_wick_pos = wp
		_hint_dir = (best_unfound_p - wp).normalized()
		_hint_alpha = clampf(1.0 - (best_unfound_d - 26.0) / 90.0, 0.15, 0.85)
		any_vis = true
		if best_unfound_d <= 98.0 and _hint_pulse_cd <= 0.0:
			_hint_pulse_cd = 2.8
			_rings.append({"pos": best_unfound_p + Vector2(0.0, -9.0), "age": 0.0, "dur": 0.52, "col": LxBiomePalette.key(_island_id, "glow")})
	else:
		_hint_alpha = 0.0

	if _tick_lens_secret(dt, w, wp):
		any_vis = true
	if any_vis:
		queue_redraw()


func _tick_lens_secret(dt: float, w: LxWick, wp: Vector2) -> bool:
	if _lens_secret.is_empty():
		return false
	var sp: Vector2 = _lens_secret["pos"] as Vector2
	var shore_p: Vector2 = _lens_secret["shore_pos"] as Vector2
	var vis: bool = absf(sp.x - _cam_center.x) <= HALF_W and absf(sp.y - _cam_center.y) <= HALF_H
	if float(_lens_secret["burst_t"]) > 0.0:
		_lens_secret["burst_t"] = maxf(0.0, float(_lens_secret["burst_t"]) - dt)
		vis = true
	if bool(_lens_secret["claimed"]):
		return vis
	if w == null or w.dead or w.move_lens == null or Lx.state == null or not Lx.state.has_move("lens"):
		return vis
	var lens_hit: bool = false
	if w.move_lens.is_pulse_active():
		if wp.distance_to(sp) <= LENS_SECRET_RADIUS or wp.distance_to(shore_p) <= LENS_SECRET_RADIUS:
			lens_hit = true
	elif w.move_lens.is_anchor_active() and w.lantern != null and is_instance_valid(w.lantern):
		var lan_p: Vector2 = w.lantern.pos
		if lan_p.distance_to(sp) <= LENS_SECRET_RADIUS or lan_p.distance_to(shore_p) <= LENS_SECRET_RADIUS:
			lens_hit = true
	if lens_hit:
		_claim_lens_secret(w, sp, shore_p)
		return true
	return vis


func _claim_lens_secret(w: LxWick, sp: Vector2, shore_p: Vector2) -> void:
	_lens_secret["claimed"] = true
	_lens_secret["burst_t"] = 0.90
	if Lx.state != null:
		Lx.state.story_flags["lens_secret_%d" % _island_id] = true
		Lx.state.add_shards(LENS_SECRET_SHARDS)
	elif Lx.events != null:
		Lx.events.shard_collected.emit(LENS_SECRET_SHARDS)
	if w != null and is_instance_valid(w):
		if w.move_sunflare != null and w.move_sunflare.unlocked:
			w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 12.0)
		w.spawn_sparks(shore_p + Vector2(0.0, -5.0), Vector2.UP, 10, PAL["ice"] as Color, 22.0, 62.0, 0.40)
		w.spawn_sparks(shore_p + Vector2(0.0, -5.0), Vector2.UP, 6, PAL["gold"] as Color, 16.0, 48.0, 0.36)
	_rings.append({"pos": sp, "age": 0.0, "dur": 0.55, "col": "ice"})
	_rings.append({"pos": shore_p + Vector2(0.0, -4.0), "age": 0.0, "dur": 0.65, "col": "gold"})
	if Lx.audio != null:
		Lx.audio.play_sfx("lens_reveal", shore_p, true)
		Lx.audio.play_sfx("prop_chime", shore_p, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(shore_p, 88.0, 0.80 if LxHudFx.flash_reduced() else 1.20, 0.55)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, shore_p, 13.0, 7.0)
	if Lx.events != null:
		Lx.events.save_requested.emit("discovery")


func _trigger_node(nd: Dictionary, w: LxWick) -> void:
	var cp: Vector2 = nd["pos"] as Vector2
	var first_time: bool = not bool(nd["found"])
	nd["found"] = true
	nd["anim_t"] = 1.4
	nd["cd"] = 4.5
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var glow_k: String = LxBiomePalette.key(_island_id, "glow")
	_rings.append({"pos": cp + Vector2(0.0, -7.0), "age": 0.0, "dur": 0.45, "col": glow_k})
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % _island_id, false)):
		_rings.append({"pos": cp + Vector2(0.0, -7.0), "age": 0.0, "dur": 0.65, "col": glow_k})

	var sfx_id: String = "prop_chime"
	var decal_k: int = LxGroundDecals.Kind.BLOSSOM
	var light_r: float = 72.0
	match _island_id:
		2:
			sfx_id = "lighthouse_toll" if first_time else "prop_chime"
			decal_k = LxGroundDecals.Kind.RIPPLE
		3:
			sfx_id = "spore_pop"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			if w != null and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 4.0)
		4:
			sfx_id = "prop_chime"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			if bm != null and is_instance_valid(bm):
				bm.tailwind_t = maxf(bm.tailwind_t, 1.8)
		5:
			sfx_id = "clockwork_chime"
			decal_k = LxGroundDecals.Kind.PRISM_STAR
			if _rules != null and is_instance_valid(_rules):
				_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 2.2)
		6:
			sfx_id = "forge_gust"
			decal_k = LxGroundDecals.Kind.SCORCH
			if bm != null and is_instance_valid(bm):
				bm.grant_molten_overdrive(1)
		7:
			sfx_id = "lens_reveal"
			decal_k = LxGroundDecals.Kind.PRISM_STAR
			light_r = 96.0
		8:
			sfx_id = "lamp_lit"
			decal_k = LxGroundDecals.Kind.BLOSSOM
			light_r = 84.0
			if w != null and w.move_sunflare != null and w.move_sunflare.unlocked:
				w.ember = minf(w.move_sunflare.get_ember_max(), w.ember + 8.0)

	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, cp, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(cp, light_r, 0.78 if LxHudFx.flash_reduced() else 1.15, 0.48)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(decal_k, cp, 12.0, 5.5)
	if first_time:
		if Lx.state != null:
			Lx.state.story_flags["disc_%d_%d" % [_island_id, int(nd.get("idx", 0))]] = true
			Lx.state.add_shards(2)
		elif Lx.events != null:
			Lx.events.shard_collected.emit(2)
		if w != null and is_instance_valid(w):
			w.spawn_sparks(cp + Vector2(0.0, -7.0), Vector2.UP, 5, LxBiomePalette.col(_island_id, "glow"), 20.0, 54.0, 0.28)
		var all_k: String = "disc_all_%d" % _island_id
		if get_total_count() > 0 and get_found_count() >= get_total_count() and Lx.state != null and not bool(Lx.state.story_flags.get(all_k, false)):
			_celebrate_all_found(cp, w, glow_k)
		elif Lx.events != null:
			Lx.events.save_requested.emit("discovery")


func _celebrate_all_found(cp: Vector2, w: LxWick, glow_k: String) -> void:
	if Lx.state != null:
		Lx.state.story_flags["disc_all_%d" % _island_id] = true
		Lx.state.add_shards(10)
	for other: Dictionary in _nodes:
		other["anim_t"] = 2.0
		_rings.append({"pos": (other["pos"] as Vector2) + Vector2(0.0, -7.0), "age": 0.0, "dur": 0.68, "col": glow_k})
	if Lx.audio != null:
		Lx.audio.play_sfx("great_lamp_bloom", cp, true)
	if Lx.events != null:
		Lx.events.narration_requested.emit(_harmony_cue_id(), "title", 3.4)
		Lx.events.save_requested.emit("discovery")
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.add_shake(0.30)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(cp, 136.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.74)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, cp, 16.0, 8.0)
	if w != null and is_instance_valid(w):
		w.spawn_sparks(cp + Vector2(0.0, -7.0), Vector2.UP, 10, LxBiomePalette.col(_island_id, "glow"), 28.0, 70.0, 0.44)


func _harmony_cue_id() -> String:
	match _island_id:
		2: return "CUE_HARMONY_2"
		3: return "CUE_HARMONY_3"
		4: return "CUE_HARMONY_4"
		5: return "CUE_HARMONY_5"
		6: return "CUE_HARMONY_6"
		7: return "CUE_HARMONY_7"
		8: return "CUE_HARMONY_8"
		_: return "CUE_HARMONY_1"


func _draw() -> void:
	if not _active:
		return
	var fred: bool = LxHudFx.flash_reduced()
	# Living World-Healing Keepsakes (Islands 1..8) + Island 8 Rose-Window Diagonal Light Shaft
	LxRelitKeepsakes.draw_living_world_keepsakes(self, _island_id, _spawn_pos, _landmark_pos, _door_pos, _cam_center, _clock, fred)

	var wp_d: Vector2 = (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(-9999.0, -9999.0)
	var harm_d: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % _island_id, false))
	var glow_d: Color = LxBiomePalette.col(_island_id, "glow")
	for nd: Dictionary in _nodes:
		var cp: Vector2 = (nd["pos"] as Vector2).round()
		if absf(cp.x - _cam_center.x) > HALF_W or absf(cp.y - _cam_center.y) > HALF_H:
			continue
		var at: float = float(nd["anim_t"])
		var found: bool = bool(nd["found"])
		var ph: float = float(nd["phase"])
		var sway: float = 0.0 if fred else roundf(sin(_clock * (10.0 if at > 0.0 else 2.0) + ph) * (2.0 if at > 0.0 else 0.7))
		draw_rect(Rect2(cp + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), Color(PAL["void"] as Color, 0.46))
		if found:
			var near_h: bool = harm_d and cp.distance_to(wp_d) <= 42.0
			draw_arc(cp + Vector2(0.0, 1.0), 8.0 if near_h else 6.0, 0.0, TAU, 12, Color(glow_d, 0.36 if near_h else 0.20), 1.0)
		_draw_biome_toy(cp, at, found, sway, fred, ph)
		if not found and (fred or fmod(_clock * 1.9 + ph, 1.4) < 0.55):
			draw_rect(Rect2(cp + Vector2(0.0, -15.0), Vector2.ONE), PAL["cream"] as Color)
		elif found and harm_d:
			var st_y: float = -16.0 + (0.0 if fred else roundf(sin(_clock * 2.4 + ph) * 1.0))
			draw_rect(Rect2(cp + Vector2(-1.0, st_y), Vector2(3.0, 1.0)), glow_d)
			draw_rect(Rect2(cp + Vector2(0.0, st_y - 1.0), Vector2(1.0, 3.0)), glow_d)
			draw_rect(Rect2(cp + Vector2(0.0, st_y), Vector2.ONE), PAL["cream"] as Color)
	_draw_lens_secret(fred)
	if _hint_alpha > 0.01:
		var shimmer: float = 0.72 if fred else (0.55 + 0.45 * sin(_clock * 4.2))
		var gp: Vector2 = (_hint_wick_pos + Vector2(0.0, -5.0) + _hint_dir * 19.0).round()
		draw_rect(Rect2(gp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(glow_d, _hint_alpha * shimmer * 0.72))
		draw_rect(Rect2(gp + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(glow_d, _hint_alpha * shimmer * 0.72))
		draw_rect(Rect2(gp, Vector2.ONE), Color(PAL["cream"] as Color, _hint_alpha * shimmer))
	for rg: Dictionary in _rings:
		var u: float = clampf(float(rg["age"]) / maxf(float(rg["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(4.0, 24.0, u))
		var a: float = (1.0 - u) * (0.55 if fred else 0.85)
		var col: Color = (PAL["cream"] if u < 0.32 else PAL[str(rg["col"])]) as Color
		draw_arc((rg["pos"] as Vector2).round(), r, 0.0, TAU, 16, Color(col, a), 1.2)


func _draw_lens_secret(fred: bool) -> void:
	if _lens_secret.is_empty():
		return
	var sp: Vector2 = (_lens_secret["pos"] as Vector2).round()
	var shore_p: Vector2 = (_lens_secret["shore_pos"] as Vector2).round()
	if absf(sp.x - _cam_center.x) > HALF_W or absf(sp.y - _cam_center.y) > HALF_H:
		return
	var ph: float = float(_lens_secret["phase"])
	var claimed: bool = bool(_lens_secret["claimed"])
	var bt: float = float(_lens_secret["burst_t"])
	var c_ice: Color = PAL["ice"] as Color
	var c_cr: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_gold: Color = PAL["gold"] as Color
	if not claimed:
		# Lone twinkling starlight breadcrumb hovering over quiet water/cliff overlook (zero text/HUD!)
		var tw: float = 0.78 if fred else (0.5 + 0.5 * sin(_clock * 2.1 + ph))
		var bob: float = 0.0 if fred else roundf(sin(_clock * 1.4 + ph) * 1.0)
		var pt := sp + Vector2(0.0, -3.0 + bob)
		draw_rect(Rect2(sp + Vector2(0.0, 3.0), Vector2.ONE), Color(c_sky, tw * 0.34))
		if tw > 0.82:
			draw_rect(Rect2(pt + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(c_ice, 0.42))
			draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(c_ice, 0.42))
			draw_rect(Rect2(pt, Vector2.ONE), c_cr)
		else:
			draw_rect(Rect2(pt, Vector2.ONE), Color(c_ice, 0.52 + tw * 0.42))
	elif bt > 0.0:
		# Revealed shimmering starlight glyph cache bursting on the shore!
		var u: float = clampf(bt / 0.90, 0.0, 1.0)
		draw_line(sp, shore_p + Vector2(0.0, -4.0), Color(c_ice, u * 0.72), 1.0)
		var gc := shore_p + Vector2(0.0, -4.0)
		draw_arc(gc, roundf(lerpf(14.0, 5.0, u)), 0.0, TAU, 14, Color(c_gold, u * 0.80), 1.2)
		draw_rect(Rect2(gc + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), Color(c_ice, u * 0.90))
		draw_rect(Rect2(gc + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), Color(c_ice, u * 0.90))
		draw_rect(Rect2(gc + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), Color(c_gold, u))
		draw_rect(Rect2(gc, Vector2.ONE), c_cr)
	else:
		# Quiet persistent starlight memory glyph etched into the shore
		var sc := shore_p
		draw_rect(Rect2(sc + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), Color(c_sky, 0.30))
		draw_rect(Rect2(sc + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), Color(c_sky, 0.30))
		draw_rect(Rect2(sc, Vector2.ONE), Color(c_ice, 0.44))


func _draw_biome_toy(cp: Vector2, at: float, found: bool, sway: float, fred: bool, ph: float) -> void:
	match _island_id:
		2: # Brass Harbor Tide-Bell Buoy
			draw_rect(Rect2(cp + Vector2(-2.0, -4.0), Vector2(4.0, 5.0)), PAL["blue"] as Color)
			draw_rect(Rect2(cp + Vector2(-1.0 + sway, -11.0), Vector2(3.0, 7.0)), PAL["apricot"] as Color)
			draw_rect(Rect2(cp + Vector2(-2.0 + sway, -10.0), Vector2(5.0, 3.0)), (PAL["cream"] if at > 0.4 else PAL["gold"]) as Color)
			draw_rect(Rect2(cp + Vector2(0.0 + sway, -12.0), Vector2.ONE), PAL["ice"] as Color)
		3: # Giant Glowing Lantern-Shroom
			draw_rect(Rect2(cp + Vector2(-1.0, -6.0), Vector2(3.0, 7.0)), PAL["stone"] as Color)
			var cap_c: Color = (PAL["lime"] if (at > 0.0 or found) else PAL["jade"]) as Color
			draw_rect(Rect2(cp + Vector2(-5.0, -10.0), Vector2(10.0, 4.0)), PAL["pine"] as Color)
			draw_rect(Rect2(cp + Vector2(-4.0, -11.0), Vector2(8.0, 4.0)), cap_c)
			draw_rect(Rect2(cp + Vector2(-2.0, -10.0), Vector2(2.0, 1.0)), PAL["cream"] as Color)
			draw_rect(Rect2(cp + Vector2(2.0, -9.0), Vector2.ONE), PAL["cream"] as Color)
		4: # Crystal Lotus Pedestal
			draw_rect(Rect2(cp + Vector2(-4.0, -2.0), Vector2(8.0, 3.0)), PAL["teal"] as Color)
			var spread: float = 2.0 if (at > 0.0 or found) else 0.0
			draw_rect(Rect2(cp + Vector2(-3.0 - spread, -6.0), Vector2(3.0, 3.0)), PAL["rose"] as Color)
			draw_rect(Rect2(cp + Vector2(1.0 + spread, -6.0), Vector2(3.0, 3.0)), PAL["rose"] as Color)
			draw_rect(Rect2(cp + Vector2(-1.0, -8.0), Vector2(3.0, 4.0)), (PAL["cream"] if (at > 0.0 or found) else PAL["ice"]) as Color)
		5: # Spinning Brass Star-Prism
			draw_rect(Rect2(cp + Vector2(-2.0, -5.0), Vector2(4.0, 6.0)), PAL["deep"] as Color)
			var rot: float = _clock * (4.5 if at > 0.0 else 1.4) + ph
			draw_arc(cp + Vector2(0.0, -10.0), 5.0, rot, rot + PI * 1.3, 10, (PAL["cream"] if at > 0.4 else PAL["gold"]) as Color, 1.2)
			draw_rect(Rect2(cp + Vector2(-1.0, -11.0), Vector2(2.0, 2.0)), PAL["sky"] as Color)
			if at > 0.3:
				var ray_end: Vector2 = cp.lerp(_door_pos, 0.25).round()
				draw_line(cp + Vector2(0.0, -10.0), ray_end, Color(PAL["gold"] as Color, 0.55 if fred else 0.80), 1.0)
		6: # Cracked Obsidian Geode Vent
			draw_rect(Rect2(cp + Vector2(-4.0, -5.0), Vector2(8.0, 6.0)), PAL["night"] as Color)
			draw_rect(Rect2(cp + Vector2(-3.0, -7.0), Vector2(6.0, 4.0)), PAL["dusk"] as Color)
			var hot_c: Color = (PAL["gold"] if (at > 0.0 or found) else PAL["coral"]) as Color
			draw_rect(Rect2(cp + Vector2(-1.0, -6.0), Vector2(2.0, 4.0)), hot_c)
			if at > 0.0 or found:
				draw_rect(Rect2(cp + Vector2(0.0, -8.0 + sway), Vector2.ONE), PAL["cream"] as Color)
		7: # Silver Lunar Mirror-Bell
			draw_rect(Rect2(cp + Vector2(-1.0, -11.0), Vector2(2.0, 12.0)), PAL["blue"] as Color)
			draw_arc(cp + Vector2(sway, -10.0), 4.0, -PI * 0.65, PI * 0.65, 10, (PAL["cream"] if (at > 0.0 or found) else PAL["ice"]) as Color, 1.4)
			draw_rect(Rect2(cp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), PAL["sky"] as Color)
		8: # Dormant -> Golden Dawn-Candle Reliquary
			draw_rect(Rect2(cp + Vector2(-2.0, -6.0), Vector2(4.0, 7.0)), PAL["plum"] as Color)
			draw_rect(Rect2(cp + Vector2(-1.0, -9.0), Vector2(2.0, 4.0)), PAL["stone"] as Color)
			if found or at > 0.0:
				draw_rect(Rect2(cp + Vector2(-1.0, -12.0), Vector2(2.0, 3.0)), PAL["gold"] as Color)
				draw_rect(Rect2(cp + Vector2(0.0, -13.0), Vector2.ONE), PAL["cream"] as Color)
			else:
				draw_rect(Rect2(cp + Vector2(0.0, -10.0), Vector2.ONE), PAL["rose"] as Color)
