class_name LxBiomeDiscoveries
extends Node2D
## Bespoke interactive overworld micro-discoveries across Islands 2..8 (complementing Island 1 LxBellChimes):
## - Island 2 (Tidewater Harbor): 5 Brass Harbor Tide-Bell Buoys (spray rings + lighthouse chime)
## - Island 3 (Thornwood Hollow): 5 Giant Glowing Lantern-Shrooms (lime spore burst + Ember)
## - Island 4 (Mirefen Gardens): 5 Crystal Lotus Pedestals (rose petals + Tailwind glide boost)
## - Island 5 (Starfall Observatory): 5 Spinning Brass Star-Prisms (star-ray + Starlight Surge)
## - Island 6 (Ashen Kiln): 5 Cracked Obsidian Geodes (cinder burst + Molten Overdrive charge)
## - Island 7 (Moon Shoals): 5 Silver Lunar Mirror-Bells (twin crescent rings + moonlight burst)
## - Island 8 (The Long Night): 5 Dormant Dawn-Candle Reliquaries (golden candlelight + Sunflare Ember)
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL); zero blocking collision.

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 196.0
const HALF_H: float = 124.0

static var active_instance: LxBiomeDiscoveries = null

var _rules: LxBiomeRules = null
var _island_id: int = 2
var _active: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _door_pos: Vector2 = Vector2.ZERO
var _nodes: Array[Dictionary] = [] # {pos, anim_t, cd, found, phase}
var _rings: Array[Dictionary] = [] # {pos, age, dur, col}


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
	_active = rules != null and not rules.is_dungeon and _island_id >= 2 and _island_id <= 8
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_door_pos = door_pos
	_nodes.clear()
	_rings.clear()
	if not _active or region_node == null or not is_instance_valid(region_node):
		queue_redraw()
		return
	_place_discoveries(region_node)
	queue_redraw()


func _place_discoveries(region_node: Node) -> void:
	var grid_v: Variant = region_node.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		return
	var grid: Array = grid_v as Array
	var gh: int = grid.size()
	var gw: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(region_node.get("tile_size")) if region_node.get("tile_size") != null else 16.0

	var avoid: Array[Vector2] = []
	if region_node.has_method("get_interactables"):
		var items_v: Variant = region_node.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if it is LxInteractable and is_instance_valid(it):
					avoid.append((it as LxInteractable).pos)

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
		_nodes.append({
			"pos": p,
			"anim_t": 0.0,
			"cd": 0.0,
			"found": false,
			"phase": rng.randf_range(0.0, TAU),
		})


func get_found_count() -> int:
	var n: int = 0
	for nd: Dictionary in _nodes:
		if bool(nd["found"]):
			n += 1
	return n


func get_total_count() -> int:
	return _nodes.size()


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick) -> bool:
	if not _active:
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

	var any_vis: bool = not _rings.is_empty()
	for nd: Dictionary in _nodes:
		nd["anim_t"] = maxf(0.0, float(nd["anim_t"]) - dt)
		nd["cd"] = maxf(0.0, float(nd["cd"]) - dt)
		var cp: Vector2 = nd["pos"] as Vector2
		if absf(cp.x - _cam_center.x) <= HALF_W and absf(cp.y - _cam_center.y) <= HALF_H:
			any_vis = true
		if float(nd["cd"]) <= 0.0:
			var hit_r: float = 22.0 if (w != null and (w.is_dashing() or w.is_gliding())) else 16.0
			var hit_w: bool = w != null and not w.dead and cp.distance_to(wp) <= hit_r
			var hit_l: bool = cp.distance_to(lp) <= 22.0
			if hit_w or hit_l:
				_trigger_node(nd, w)
	if any_vis:
		queue_redraw()


func _trigger_node(nd: Dictionary, w: LxWick) -> void:
	var cp: Vector2 = nd["pos"] as Vector2
	var first_time: bool = not bool(nd["found"])
	nd["found"] = true
	nd["anim_t"] = 1.4
	nd["cd"] = 4.5
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var glow_k: String = LxBiomePalette.key(_island_id, "glow")
	_rings.append({"pos": cp + Vector2(0.0, -7.0), "age": 0.0, "dur": 0.45, "col": glow_k})

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
			Lx.state.shards += 2
		if Lx.events != null:
			Lx.events.shard_collected.emit(2)
		if w != null and is_instance_valid(w):
			w.spawn_sparks(cp + Vector2(0.0, -7.0), Vector2.UP, 5, LxBiomePalette.col(_island_id, "glow"), 20.0, 54.0, 0.28)


func _draw() -> void:
	if not _active:
		return
	var fred: bool = LxHudFx.flash_reduced()
	for nd: Dictionary in _nodes:
		var cp: Vector2 = (nd["pos"] as Vector2).round()
		if absf(cp.x - _cam_center.x) > HALF_W or absf(cp.y - _cam_center.y) > HALF_H:
			continue
		var at: float = float(nd["anim_t"])
		var found: bool = bool(nd["found"])
		var ph: float = float(nd["phase"])
		var sway: float = 0.0 if fred else roundf(sin(_clock * (10.0 if at > 0.0 else 2.0) + ph) * (2.0 if at > 0.0 else 0.7))
		draw_rect(Rect2(cp + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), Color(PAL["void"] as Color, 0.46))
		_draw_biome_toy(cp, at, found, sway, fred, ph)
		if not found and (fred or fmod(_clock * 1.9 + ph, 1.4) < 0.55):
			draw_rect(Rect2(cp + Vector2(0.0, -15.0), Vector2.ONE), PAL["cream"] as Color)
	for rg: Dictionary in _rings:
		var u: float = clampf(float(rg["age"]) / maxf(float(rg["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(4.0, 24.0, u))
		var a: float = (1.0 - u) * (0.55 if fred else 0.85)
		var col: Color = (PAL["cream"] if u < 0.32 else PAL[str(rg["col"])]) as Color
		draw_arc((rg["pos"] as Vector2).round(), r, 0.0, TAU, 16, Color(col, a), 1.2)


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
