class_name LxRegionLoader
extends Node2D
## Loads .map + .json regions, renders painted PNG or Last Light greybox tiles,
## builds tile/interactable collision + sight queries, and manages dungeon room slides.

const PAL: Dictionary = LxInteractable.PAL
const GreyboxDraw := preload("res://luxel/world/greybox_draw.gd")
const ROOM_W: float = 320.0
const ROOM_H: float = 180.0
const ROOM_SLIDE_S: float = 0.4

var current_island_id: int = 0
var current_region_id: String = ""
var region_data: Dictionary = {}
var width: int = 0
var height: int = 0
var tile_size: int = LxMapFormat.DEFAULT_TILE_SIZE
var grid: Array[PackedStringArray] = []
var bounds: Rect2 = Rect2()
var is_dungeon: bool = false
var spawn_pos: Vector2 = Vector2.ZERO
var zones: Array[Dictionary] = []
var exits: Array[Dictionary] = []
var triggers: Array[Dictionary] = []
var rooms: Array[Dictionary] = []

var _ground_sprite: Sprite2D = null
var _floor_interactables_root: Node2D = null
var _scenery_ground_root: Node2D = null
var _world_ysort_root: Node2D = null
var _scenery_sort_root: Node2D = null
var _scenery_over_root: Node2D = null
var _scenery_props: Array[LxSceneryProp] = []
var _water_fx: LxWaterFx = null
var _signal_conduits: LxSignalConduits = null
var _visual_teaching: LxVisualTeachingFx = null
var _failure_teaching: LxFailureTeachingFx = null
var _ambient_life: LxAmbientLife = null
var _interactables_root: Node2D = null
var _enemies_root: Node2D = null
var _enemies: Array[LxEnemyBrain] = []
var _interactables: Array[LxInteractable] = []
var _interactables_by_id: Dictionary = {}
var _lens_circles: Array[Vector3] = []
var _current_room_id: String = ""
var _current_room_rect: Rect2 = Rect2()
var _fired_triggers: Dictionary = {}
var _director: LxAttackDirector = null

func _ready() -> void:
	_ensure_containers()

func _ensure_containers() -> void:
	if _water_fx == null:
		_water_fx = LxWaterFx.new(); _water_fx.name = "WaterFx"; add_child(_water_fx)
	if _signal_conduits == null:
		_signal_conduits = LxSignalConduits.new(); _signal_conduits.name = "SignalConduits"; _signal_conduits.z_index = -6; add_child(_signal_conduits)
	if _visual_teaching == null:
		_visual_teaching = LxVisualTeachingFx.new(); _visual_teaching.name = "VisualTeachingFx"; _visual_teaching.z_index = -4; add_child(_visual_teaching)
	if _failure_teaching == null:
		_failure_teaching = LxFailureTeachingFx.new()
		_failure_teaching.name = "FailureTeachingFx"
		_failure_teaching.z_index = 6
		add_child(_failure_teaching)
	if _floor_interactables_root == null:
		_floor_interactables_root = _make_layer("FloorInteractables", -6, false)
	if _scenery_ground_root == null:
		_scenery_ground_root = _make_layer("SceneryGround", -5, false)
	if _world_ysort_root == null:
		_world_ysort_root = _make_layer("WorldYSort", 0, true)
	if _scenery_sort_root == null:
		_scenery_sort_root = _make_layer("ScenerySort", 0, true, _world_ysort_root)
	if _interactables_root == null:
		_interactables_root = _make_layer("Interactables", 0, true, _world_ysort_root)
	if _enemies_root == null:
		_enemies_root = _make_layer("Enemies", 0, true, _world_ysort_root)
	if _ambient_life == null:
		_ambient_life = LxAmbientLife.new()
		_ambient_life.name = "AmbientLife"
		_ambient_life.z_index = 3
		add_child(_ambient_life)
	if _scenery_over_root == null:
		_scenery_over_root = _make_layer("SceneryOver", 4, false)

func _make_layer(layer_name: String, z: int, y_sort: bool, parent_node: Node = null) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	n.z_index = z
	n.y_sort_enabled = y_sort
	(parent_node if parent_node != null else self).add_child(n)
	return n

func get_ysort_root() -> Node2D:
	_ensure_containers()
	return _world_ysort_root

func load_region(island_id: int, region_id: String, director: LxAttackDirector) -> bool:
	var map_path: String = "res://luxel/islands/%d/%s.map" % [island_id, region_id]
	var json_path: String = "res://luxel/islands/%d/%s.json" % [island_id, region_id]
	return load_region_from_paths(map_path, json_path, director, island_id, region_id)

func load_region_from_paths(
	map_path: String,
	json_path: String,
	director: LxAttackDirector,
	island_override: int = 0,
	region_override: String = ""
) -> bool:
	_ensure_containers()
	if not current_region_id.is_empty():
		save_interactables_to_state()
	_clear_loaded()
	var parsed: Dictionary = LxMapFormat.parse_region(map_path, json_path)
	var w: int = int(parsed.get("width", 0))
	var h: int = int(parsed.get("height", 0))
	if w <= 0 or h <= 0:
		push_warning("LxRegionLoader: failed to parse map " + map_path)
		return false
	_director = director
	region_data = parsed
	current_island_id = island_override if island_override > 0 else int(parsed.get("island_id", 1))
	current_region_id = region_override if not region_override.is_empty() else str(parsed.get("id", "region"))
	width = w
	height = h
	tile_size = int(parsed.get("tile_size", LxMapFormat.DEFAULT_TILE_SIZE))
	grid.clear()
	grid.assign(parsed.get("grid", []))
	bounds = parsed.get("bounds", Rect2(0.0, 0.0, float(w * tile_size), float(h * tile_size))) as Rect2
	is_dungeon = bool(parsed.get("is_dungeon", false))
	spawn_pos = LxMapFormat.to_vec2(parsed.get("spawn", [bounds.size.x * 0.5, bounds.size.y * 0.5]))
	zones.clear()
	zones.assign(parsed.get("zones", []))
	exits.clear()
	exits.assign(parsed.get("exits", []))
	triggers.clear()
	triggers.assign(parsed.get("triggers", []))
	rooms = LxMapFormat._ensure_dict_array(parsed.get("rooms", []))
	_setup_ground_visual()
	var scenery_raw: Variant = parsed.get("scenery", [])
	if scenery_raw is Array:
		_scenery_props = LxSceneryProp.spawn_from_specs(scenery_raw as Array, _scenery_ground_root, _scenery_sort_root, _scenery_over_root)
	var inter_specs: Array[Dictionary] = []
	inter_specs.assign(parsed.get("interactables", []))
	_spawn_interactables(inter_specs)
	_promote_destructible_map_tiles()
	load_interactables_from_state()
	if _signal_conduits != null:
		_signal_conduits.rebuild(self)
	if _visual_teaching != null: _visual_teaching.rebuild(self)
	if _failure_teaching != null:
		_failure_teaching.rebuild(self)
	var enemy_specs: Array[Dictionary] = []
	enemy_specs.assign(parsed.get("enemies", []))
	_spawn_enemies(enemy_specs, director)
	if Lx.state != null:
		Lx.state.island_id = current_island_id
		Lx.state.region_id = current_region_id
		Lx.state.mark_region_visited(current_island_id, current_region_id)
	_init_camera(spawn_pos)
	if _water_fx != null:
		_water_fx.configure(grid, tile_size, current_island_id, is_dungeon)
		_water_fx.tick(0.0, Lx.camera.global_position if Lx.camera != null else spawn_pos)
	if _ambient_life != null:
		_ambient_life.configure(current_island_id, bounds, is_dungeon)
		_ambient_life.tick(0.0, Lx.camera.global_position if Lx.camera != null else spawn_pos)
	queue_redraw()
	if Lx.events != null:
		Lx.events.region_entered.emit(current_island_id, current_region_id)
	return true

func discard_loaded() -> void:
	## Drops the live region without saving it (LxMain, before Lx.state switches to another save slot).
	_clear_loaded()
	current_region_id = ""

func _clear_loaded() -> void:
	if _director != null:
		_director.clear()
	_enemies.clear()
	_interactables.clear()
	_interactables_by_id.clear()
	if _signal_conduits != null:
		_signal_conduits.clear()
	if _visual_teaching != null: _visual_teaching.clear()
	if _failure_teaching != null:
		_failure_teaching.clear()
	_lens_circles.clear()
	_fired_triggers.clear()
	_current_room_id = ""
	_current_room_rect = Rect2()
	if _ground_sprite != null:
		_ground_sprite.queue_free()
		_ground_sprite = null
	_scenery_props.clear()
	for root_node: Node2D in [_floor_interactables_root, _interactables_root, _enemies_root, _scenery_ground_root, _scenery_sort_root, _scenery_over_root]:
		if root_node != null:
			for c: Node in root_node.get_children():
				c.queue_free()

func _setup_ground_visual() -> void:
	var png_path: String = "res://luxel/art/islands/%d/%s_ground.png" % [current_island_id, current_region_id]
	var tex: Texture2D = null
	if ResourceLoader.exists(png_path):
		var loaded: Resource = ResourceLoader.load(png_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	elif FileAccess.file_exists(png_path):
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(png_path)) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		return
	_ground_sprite = Sprite2D.new()
	_ground_sprite.name = "PaintedGround"
	_ground_sprite.texture = tex
	_ground_sprite.centered = false
	_ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_sprite.z_index = -10
	add_child(_ground_sprite)

func _spawn_interactables(specs: Array[Dictionary]) -> void:
	for spec: Dictionary in specs:
		var item: LxInteractable = LxInteractableFactory.create(spec)
		if item == null:
			continue
		item.region = self
		item.island_id = current_island_id
		item.region_id = current_region_id
		item.setup(spec)
		_sync_interactable_layer(item)
		_interactables.append(item)
		if not item.id.is_empty():
			_interactables_by_id[item.id] = item

func _is_floor_interactable(item: LxInteractable) -> bool:
	if item == null:
		return false
	if item.kind in ["blue_portal", "phantom_platform", "floor_switch"]:
		return true
	if item is LxDoor:
		var d: LxDoor = item as LxDoor
		return d.door_type == "bridge_platform" or (bool(d.get("_is_light_bridge")) and d.opened)
	return false

func _sync_interactable_layer(item: LxInteractable) -> void:
	if item == null or not is_instance_valid(item):
		return
	var target: Node2D = _floor_interactables_root if _is_floor_interactable(item) else _interactables_root
	if target == null:
		return
	if item.get_parent() == null:
		target.add_child(item)
	elif item.get_parent() != target:
		item.reparent(target, false)


func _promote_destructible_map_tiles() -> void:
	if width <= 0 or height <= 0:
		return
	var ts: float = float(tile_size)
	var visited: Dictionary = {}
	for ty: int in range(height):
		for tx: int in range(width):
			var key := Vector2i(tx, ty)
			if visited.has(key):
				continue
			var ttype: String = grid[ty][tx]
			if ttype != "bramble" and ttype != "cracked":
				continue
			var target_kind: String = "bramble" if ttype == "bramble" else "cracked_wall"
			var tile_center := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
			if _has_interactable_covering(target_kind, tile_center):
				grid[ty][tx] = "ground"
				visited[key] = true
				continue
			# Group contiguous horizontal run first; if single-wide, group vertical run.
			var rx1: int = tx
			while rx1 + 1 < width and grid[ty][rx1 + 1] == ttype and not visited.has(Vector2i(rx1 + 1, ty)):
				var nc := Vector2((float(rx1 + 1) + 0.5) * ts, (float(ty) + 0.5) * ts)
				if _has_interactable_covering(target_kind, nc):
					break
				rx1 += 1
			var ry1: int = ty
			if rx1 == tx:
				while ry1 + 1 < height and grid[ry1 + 1][tx] == ttype and not visited.has(Vector2i(tx, ry1 + 1)):
					var vc := Vector2((float(tx) + 0.5) * ts, (float(ry1 + 1) + 0.5) * ts)
					if _has_interactable_covering(target_kind, vc):
						break
					ry1 += 1
			for cy: int in range(ty, ry1 + 1):
				for cx: int in range(tx, rx1 + 1):
					visited[Vector2i(cx, cy)] = true
					grid[cy][cx] = "ground"
			var cols_n: int = rx1 - tx + 1
			var rows_n: int = ry1 - ty + 1
			var size_px := Vector2(float(cols_n) * ts, float(rows_n) * ts)
			var center_px := Vector2((float(tx) + float(cols_n) * 0.5) * ts, (float(ty) + float(rows_n) * 0.5) * ts)
			var auto_id: String = "map_%s_%d_%d" % [ttype, tx, ty]
			var spec: Dictionary = {
				"id": auto_id,
				"kind": target_kind,
				"pos": [center_px.x, center_px.y],
				"props": {
					"size": [size_px.x, size_px.y],
					"from_map_tile": true,
				},
			}
			var item: LxInteractable = LxInteractableFactory.create(spec)
			if item != null:
				item.region = self
				item.island_id = current_island_id
				item.region_id = current_region_id
				item.setup(spec)
				_interactables_root.add_child(item)
				_interactables.append(item)
				_interactables_by_id[auto_id] = item

func _has_interactable_covering(target_kind: String, pt: Vector2) -> bool:
	for it: LxInteractable in _interactables:
		if it != null and it.kind == target_kind and it.get_solid_rect().grow(2.0).has_point(pt):
			return true
	return false

func _spawn_enemies(specs: Array[Dictionary], director: LxAttackDirector) -> void:
	for spec: Dictionary in specs:
		var kind: String = str(spec.get("kind", "")).strip_edges()
		if kind.is_empty(): continue
		var s: Dictionary = spec.duplicate(true)
		s["island_id"] = current_island_id
		var ep: Dictionary = s.get("props", {}) as Dictionary if s.get("props") is Dictionary else {}
		for k: String in ["max_hp", "shield_hp", "facing", "notice_radius", "tutorial_wait_lantern"]:
			if not s.has(k) and ep.has(k): s[k] = ep[k]
		if s.has("max_hp") and float(s["max_hp"]) <= 0.0: s.erase("max_hp")
		if s.has("notice_radius") and float(s["notice_radius"]) <= 0.0: s.erase("notice_radius")
		if s.has("shield_hp"): s["shield_hp"] = maxf(0.0, float(s["shield_hp"]))
		var brain: LxEnemyBrain = LxEnemyFactory.create(kind, s, director, self)
		if brain == null: continue
		if brain.is_boss and Lx.state != null:
			var bid: String = brain.boss_id if not brain.boss_id.is_empty() else brain.kind
			var alt: String = "hollow_wick" if brain.kind == "hollow_wick_boss" else ""
			if Lx.state.defeated_bosses.has(bid) or Lx.state.defeated_bosses.has(brain.kind) \
					or (not alt.is_empty() and Lx.state.defeated_bosses.has(alt)):
				brain.free()
				continue
		_enemies_root.add_child(brain)
		brain.position = brain.pos.round()
		_enemies.append(brain)

func _init_camera(focus_pos: Vector2) -> void:
	if is_dungeon:
		var rinfo: Dictionary = _resolve_room_for_pos(focus_pos)
		_current_room_id = str(rinfo.get("id", "r_0_0"))
		_current_room_rect = rinfo.get("rect", bounds) as Rect2
	else:
		_current_room_id = ""
		_current_room_rect = bounds
	if Lx.state != null:
		Lx.state.room_id = _current_room_id
	if Lx.camera != null:
		Lx.camera.set_bounds(_current_room_rect, is_dungeon)
		Lx.camera.snap_to(focus_pos)

func update_dungeon_room(player_pos: Vector2) -> void:
	if not is_dungeon:
		return
	var rinfo: Dictionary = _resolve_room_for_pos(player_pos)
	var rid: String = str(rinfo.get("id", ""))
	var rrect: Rect2 = rinfo.get("rect", bounds) as Rect2
	if rid.is_empty() or rid == _current_room_id:
		return
	_current_room_id = rid
	_current_room_rect = rrect
	if Lx.state != null:
		Lx.state.room_id = rid
	if Lx.camera != null:
		Lx.camera.slide_to_room(rrect, ROOM_SLIDE_S)
	if Lx.events != null:
		Lx.events.room_changed.emit(current_island_id, rid)

func _resolve_room_for_pos(p: Vector2) -> Dictionary:
	for rm: Dictionary in rooms:
		var r: Rect2 = LxMapFormat.to_rect2(rm.get("rect", []))
		if r.has_point(p):
			return {"id": str(rm.get("id", "room")), "rect": r}
	var rw: float = ROOM_W
	var rh: float = ROOM_H
	if region_data.has("room_size"):
		var rs: Vector2 = LxMapFormat.to_vec2(region_data.get("room_size", [ROOM_W, ROOM_H]))
		rw = maxf(ROOM_W, rs.x)
		rh = maxf(ROOM_H, rs.y)
	elif bool(region_data.get("is_2x2_room", false)):
		return {"id": current_region_id, "rect": bounds}
	if bounds.size.x <= rw + 16.0 and bounds.size.y <= rh + 16.0:
		return {"id": current_region_id, "rect": bounds}
	var rx: int = maxi(0, int(floor(p.x / rw)))
	var ry: int = maxi(0, int(floor(p.y / rh)))
	var rect := Rect2(
		float(rx) * rw,
		float(ry) * rh,
		minf(rw, bounds.size.x - float(rx) * rw),
		minf(rh, bounds.size.y - float(ry) * rh)
	)
	return {"id": "r_%d_%d" % [rx, ry], "rect": rect}

func get_current_room_rect() -> Rect2:
	return _current_room_rect if _current_room_rect.size.x > 0.0 else bounds

func get_current_room_id() -> String:
	return _current_room_id

func collide(pos: Vector2, radius: float, can_cross_pit: bool = false, can_cross_water: bool = false, ignore_id: String = "") -> Vector2:
	if width <= 0 or height <= 0:
		return pos
	var p := Vector2(
		clampf(pos.x, bounds.position.x + radius, maxf(bounds.position.x + radius, bounds.end.x - radius)),
		clampf(pos.y, bounds.position.y + radius, maxf(bounds.position.y + radius, bounds.end.y - radius))
	)
	var ts: float = float(tile_size)
	for _pass: int in range(2):
		var tx0: int = maxi(0, int(floor((p.x - radius) / ts)))
		var tx1: int = mini(width - 1, int(floor((p.x + radius) / ts)))
		var ty0: int = maxi(0, int(floor((p.y - radius) / ts)))
		var ty1: int = mini(height - 1, int(floor((p.y + radius) / ts)))
		for ty: int in range(ty0, ty1 + 1):
			var row: PackedStringArray = grid[ty]
			for tx: int in range(tx0, tx1 + 1):
				var ttype: String = row[tx]
				if not is_solid_tile(ttype, can_cross_pit, can_cross_water):
					continue
				var tile_rect := Rect2(float(tx) * ts, float(ty) * ts, ts, ts)
				if not _is_tile_supported(ttype, tile_rect.get_center()):
					p = _push_circle_out_of_rect(p, radius, tile_rect)
		for it: LxInteractable in _interactables:
			if it != null and it.is_solid() and (ignore_id.is_empty() or it.id != ignore_id):
				var srect: Rect2 = it.get_solid_rect()
				if srect.size.x > 0.0 and srect.size.y > 0.0:
					p = _push_circle_out_of_rect(p, radius, srect)
	return p

func collide_ignoring(pos: Vector2, radius: float, ignore_id: String, can_cross_pit: bool = false, can_cross_water: bool = false) -> Vector2:
	return collide(pos, radius, can_cross_pit, can_cross_water, ignore_id)

func can_place_rect(rect: Rect2, ignore_id: String = "") -> bool:
	if width <= 0 or height <= 0 or not rect.has_area():
		return false
	if rect.position.x < bounds.position.x or rect.position.y < bounds.position.y \
			or rect.end.x > bounds.end.x or rect.end.y > bounds.end.y:
		return false
	var eps: float = 0.25
	var x0: float = rect.position.x + eps
	var x1: float = rect.end.x - eps
	var xm: float = (x0 + x1) * 0.5
	var y0: float = rect.position.y + eps
	var y1: float = rect.end.y - eps
	var ym: float = (y0 + y1) * 0.5
	var samples: Array[Vector2] = [
		Vector2(x0, y0), Vector2(xm, y0), Vector2(x1, y0),
		Vector2(x0, ym), Vector2(xm, ym), Vector2(x1, ym),
		Vector2(x0, y1), Vector2(xm, y1), Vector2(x1, y1),
	]
	for pt: Vector2 in samples:
		var ttype: String = tile_at(pt)
		if is_solid_tile(ttype, false, false) and not _is_tile_supported(ttype, pt):
			return false
	for it: LxInteractable in _interactables:
		if it != null and it.is_solid() and (ignore_id.is_empty() or it.id != ignore_id):
			var srect: Rect2 = it.get_solid_rect()
			if srect.has_area() and rect.intersects(srect):
				return false
	return true

func _is_tile_supported(tile_type: String, tile_center: Vector2) -> bool:
	if tile_type == "phantom":
		for c: Vector3 in _lens_circles:
			if tile_center.distance_squared_to(Vector2(c.x, c.y)) <= c.z * c.z:
				return true
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			var ml: LxMoveLens = w.move_lens
			if ml != null and ml.unlocked:
				if ml.is_pulse_active() and tile_center.distance_squared_to(w.global_position) <= ml.pulse_radius * ml.pulse_radius:
					return true
				if ml.is_anchor_active() and w.lantern != null and tile_center.distance_squared_to(w.lantern.pos) <= ml.hung_radius * ml.hung_radius:
					return true
	if tile_type in ["pit", "void", "water", "tide", "phantom"]:
		for it: LxInteractable in _interactables:
			if it != null and it.is_platform_solid() and it.get_platform_rect().has_point(tile_center):
				return true
	return false

static func _push_circle_out_of_rect(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	var delta: Vector2 = center - closest
	var dist_sq: float = delta.length_squared()
	if dist_sq >= radius * radius:
		return center
	if dist_sq > 0.0001:
		var d: float = sqrt(dist_sq)
		return center + (delta / d) * (radius - d)
	var dl: float = center.x - rect.position.x
	var dr: float = rect.end.x - center.x
	var dt_: float = center.y - rect.position.y
	var db: float = rect.end.y - center.y
	var m: float = minf(minf(dl, dr), minf(dt_, db))
	if m == dl:
		return Vector2(rect.position.x - radius, center.y)
	if m == dr:
		return Vector2(rect.end.x + radius, center.y)
	return Vector2(center.x, rect.position.y - radius) if m == dt_ else Vector2(center.x, rect.end.y + radius)

func clear_view(a: Vector2, b: Vector2) -> bool:
	var dist: float = a.distance_to(b)
	if dist <= 1.0:
		return true
	var steps: int = maxi(1, int(ceil(dist / 4.0)))
	for i: int in range(1, steps):
		var pt: Vector2 = a.lerp(b, float(i) / float(steps))
		if LxMapFormat.blocks_sight_tile(tile_at(pt)):
			return false
		for it: LxInteractable in _interactables:
			if it != null and it.blocks_sight() and it.get_solid_rect().has_point(pt):
				return false
	return true

func tile_at(world_pos: Vector2) -> String:
	if tile_size <= 0 or width <= 0 or height <= 0:
		return "void"
	var tx: int = int(floor(world_pos.x / float(tile_size)))
	var ty: int = int(floor(world_pos.y / float(tile_size)))
	return grid[ty][tx] if (tx >= 0 and ty >= 0 and tx < width and ty < height) else "void"

func is_solid_tile(tile_type: String, can_cross_pit: bool = false, can_cross_water: bool = false) -> bool:
	return LxMapFormat.is_solid_tile(tile_type, can_cross_pit, can_cross_water)

func is_lethal_void_at(world_pos: Vector2) -> bool:
	if width <= 0 or height <= 0:
		return false
	var ttype: String = tile_at(world_pos)
	if ttype in ["pit", "void", "phantom", "water", "tide"]:
		var ts: float = float(tile_size)
		var tile_center := Vector2((floorf(world_pos.x / ts) + 0.5) * ts, (floorf(world_pos.y / ts) + 0.5) * ts)
		if _is_tile_supported(ttype, world_pos) or _is_tile_supported(ttype, tile_center):
			return false
		return true
	return false

func is_hazard_at(world_pos: Vector2) -> bool:
	return is_lethal_void_at(world_pos)

func find_interactable(id: String) -> LxInteractable:
	var found: Variant = _interactables_by_id.get(id, null)
	return found as LxInteractable if found is LxInteractable else null

func check_exit(pos: Vector2) -> Dictionary:
	for ex: Dictionary in exits:
		if not LxMapFormat.to_rect2(ex.get("rect", [])).has_point(pos):
			continue
		var door_id: String = str(ex.get("locked_door_id", ""))
		if not door_id.is_empty():
			var door: LxInteractable = find_interactable(door_id)
			if door != null and door.is_solid():
				continue
		if _exit_requirements_met(ex):
			return ex
	return {}

func _exit_requirements_met(ex: Dictionary) -> bool:
	var req_moves: Variant = ex.get("requires_moves", [])
	if req_moves is Array and Lx.state != null:
		for m: Variant in (req_moves as Array):
			if not Lx.state.has_move(str(m)):
				return false
	var req_flags: Variant = ex.get("requires_flags", [])
	if req_flags is Array:
		for fl: Variant in (req_flags as Array):
			if not is_flag_set(str(fl)):
				return false
	return true

func save_interactables_to_state() -> void:
	if Lx.state == null:
		return
	for it: LxInteractable in _interactables:
		if it != null and not it.id.is_empty():
			Lx.state.interactable_states[it.get_state_key()] = it.save_state()

func load_interactables_from_state() -> void:
	if Lx.state == null:
		return
	for it: LxInteractable in _interactables:
		if it != null and not it.id.is_empty():
			var key: String = it.get_state_key()
			if Lx.state.interactable_states.has(key) and Lx.state.interactable_states[key] is Dictionary:
				it.load_state(Lx.state.interactable_states[key] as Dictionary)
				_sync_interactable_layer(it)

func tick(dt: float, player_pos: Vector2 = Vector2(-9999.0, -9999.0)) -> void:
	_lens_circles.clear()
	for sp: LxSceneryProp in _scenery_props:
		if sp != null and sp.animated:
			sp.tick(dt)
	var cam_pos: Vector2 = Lx.camera.global_position if Lx.camera != null else (player_pos if player_pos.x > -9000.0 else spawn_pos)
	if _water_fx != null:
		_water_fx.tick(dt, cam_pos)
	if _ambient_life != null:
		_ambient_life.tick(dt, cam_pos)
	if _signal_conduits != null:
		_signal_conduits.tick(dt)
	if _visual_teaching != null: _visual_teaching.tick(dt, cam_pos)
	if _failure_teaching != null:
		_failure_teaching.tick(dt, cam_pos)
	for it: LxInteractable in _interactables:
		if it != null:
			it.tick(dt)
			if it is LxDoor:
				_sync_interactable_layer(it)
	if player_pos.x > -9000.0:
		_check_triggers(player_pos)
		if is_dungeon:
			update_dungeon_room(player_pos)

func tick_region(dt: float, player_pos: Vector2 = Vector2.ZERO) -> int:
	var ppos: Vector2 = get_wick_pos() if (player_pos == Vector2.ZERO and Lx.player != null and is_instance_valid(Lx.player)) else player_pos
	tick(dt, ppos)
	var engaged: int = 0
	for e: LxEnemyBrain in _enemies:
		if e != null and is_instance_valid(e) and e.is_alive():
			e.tick(dt)
			if e.is_alive() and e.state != LxEnemyBrain.State.ROUTINE \
					and e.state != LxEnemyBrain.State.RETURN and e.state != LxEnemyBrain.State.DEAD:
				engaged += 1
	return engaged

func get_spawn_pos() -> Vector2: return spawn_pos
func collide_fly(pos: Vector2, radius: float) -> Vector2: return collide(pos, radius, true, true)
func get_bounds() -> Rect2: return bounds
func get_enemies() -> Array[LxEnemyBrain]: return _enemies
func get_interactables() -> Array[LxInteractable]: return _interactables
func get_zones() -> Array[Dictionary]: return zones
func is_lantern_hung() -> bool: return get_lantern_state() == 2
func is_lantern_out() -> bool: return get_lantern_state() in [1, 2]

func get_wick_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player is Node2D:
			return (Lx.player as Node2D).global_position
		if Lx.player.get("pos") is Vector2:
			return Lx.player.get("pos") as Vector2
	return Vector2(-99999.0, -99999.0)

func get_lantern_state() -> int:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan) and (lan as Object).get("state") != null:
			return int((lan as Object).get("state"))
	return 0

func get_lantern_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan: Variant = Lx.player.get("lantern")
		if lan is Object and is_instance_valid(lan):
			if (lan as Object).get("pos") is Vector2:
				return (lan as Object).get("pos") as Vector2
			if lan is Node2D:
				return (lan as Node2D).global_position
	return get_wick_pos()

func apply_light(world_pos: Vector2, light_radius: float, source: String) -> void:
	if light_radius <= 0.0:
		return
	if source == "lens" or source == "lens_anchor":
		_lens_circles.append(Vector3(world_pos.x, world_pos.y, light_radius))
	for it: LxInteractable in _interactables:
		if it != null and it.active:
			var reach: float = light_radius + it.radius
			if it.pos.distance_squared_to(world_pos) <= reach * reach:
				it.on_light(light_radius, source)

func try_interact(actor: Node, actor_pos: Vector2, reach: float = 20.0) -> LxInteractable:
	var best: LxInteractable = null
	var best_d2: float = INF
	for it: LxInteractable in _interactables:
		if it == null or not it.active:
			continue
		var max_r: float = reach + it.radius
		var d2: float = it.pos.distance_squared_to(actor_pos)
		if d2 <= max_r * max_r and d2 < best_d2:
			best = it
			best_d2 = d2
	if best != null and best.interact(actor):
		save_interactables_to_state()
		return best
	return null

func hit_interactables(hit: LxHit, hit_pos: Vector2, hit_radius: float = 8.0) -> LxInteractable:
	for it: LxInteractable in _interactables:
		if it == null or not it.active:
			continue
		var hit_ok: bool = it.get_solid_rect().grow(hit_radius).has_point(hit_pos) if it.is_solid() else (
			it.pos.distance_squared_to(hit_pos) <= (it.radius + hit_radius) * (it.radius + hit_radius)
		)
		if hit_ok and it.on_hit(hit):
			save_interactables_to_state()
			return it
	return null

func is_zone_cleared(zone_id: String = "") -> bool:
	for e: LxEnemyBrain in _enemies:
		if e == null or not is_instance_valid(e) or not e.is_alive():
			continue
		if zone_id.is_empty() or e.zone == zone_id:
			return false
	return true

func is_zone_lit(zone_id: String) -> bool:
	if Lx.state != null and Lx.state.relit_islands.has(current_island_id):
		return true
	for z: Dictionary in zones:
		if str(z.get("id", "")) == zone_id and not bool(z.get("dark", true)):
			return true
	for it: LxInteractable in _interactables:
		if it != null and it.kind == "beacon" and bool(it.get("lit")):
			if str(it.props.get("zone", "")) == zone_id:
				return true
			var relit: Variant = it.props.get("relit_zones", [])
			if relit is Array and (relit as Array).has(zone_id):
				return true
	return false

func get_light_pools() -> Array[Vector4]:
	var pools: Array[Vector4] = []
	for it: LxInteractable in _interactables:
		if it != null:
			var p: Vector4 = it.get_light_pool()
			if p.z > 1.0 and p.w > 0.001:
				pools.append(p)
	for sp: LxSceneryProp in _scenery_props:
		if sp != null and sp.light_pool.z > 1.0:
			pools.append(sp.light_pool)
	return pools

func is_flag_set(flag: String) -> bool:
	if flag.is_empty():
		return true
	if Lx.state == null:
		return false
	if bool(Lx.state.story_flags.get(flag, false)):
		return true
	if Lx.state.lit_beacons.has(flag) or Lx.state.claimed_shrines.has(flag) \
			or Lx.state.broken_seals.has(flag) or Lx.state.defeated_bosses.has(flag) \
			or Lx.state.opened_doors.has(flag) or Lx.state.lit_waystones.has(flag):
		return true
	if flag.begins_with("island_") and flag.ends_with("_relit"):
		return Lx.state.relit_islands.has(int(flag.substr(7, flag.length() - 13)))
	if flag.begins_with("great_lamp_"):
		return Lx.state.relit_islands.has(int(flag.substr(11)))
	return false

func _check_triggers(player_pos: Vector2) -> void:
	for trig: Dictionary in triggers:
		var tid: String = str(trig.get("id", ""))
		if tid.is_empty():
			continue
		var unless_flag: String = str(trig.get("unless_flag", ""))
		if not unless_flag.is_empty() and is_flag_set(unless_flag):
			continue
		var once: bool = bool(trig.get("once", true))
		var flag_key: String = "trig_%d_%s_%s" % [current_island_id, current_region_id, tid]
		if once and (_fired_triggers.has(tid) or (Lx.state != null and bool(Lx.state.story_flags.get(flag_key, false)))):
			continue
		if not LxMapFormat.to_rect2(trig.get("rect", [])).has_point(player_pos):
			continue
		_fired_triggers[tid] = true
		if once and Lx.state != null:
			Lx.state.story_flags[flag_key] = true
		var sid: String = str(trig.get("string_id", ""))
		if not sid.is_empty() and Lx.events != null:
			Lx.events.narration_requested.emit(sid, str(trig.get("style", "narration")), float(trig.get("duration", 3.5)))


func _draw() -> void:
	if _ground_sprite != null or width <= 0 or height <= 0:
		return
	var ts: float = float(tile_size)
	for ty: int in range(height):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(width):
			GreyboxDraw.draw_tile(self, tx, ty, ts, row[tx])
