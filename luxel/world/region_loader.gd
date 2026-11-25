class_name LxRegionLoader
extends Node2D
## Loads .map + .json regions, dynamic layers, painted/greybox tiles,
## tile/interactable collision + sight queries, room scripts, arena lock, and dungeon slides.

signal room_notified(event: String, data: Dictionary)

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
var room_script: Object = null

var _ground_sprite: Sprite2D = null
var _greybox_ground: Node2D = null
var _layers: LxRegionLayers = null
var _arena: LxRegionArena = null
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
var _inter_defaults: Dictionary = {}
var _signal_states: Dictionary = {}
var _lens_circles: Array[Vector3] = []
var _current_room_id: String = ""
var _current_room_rect: Rect2 = Rect2()
var _room_anchor_pos: Vector2 = Vector2(-1.0, -1.0)
var _exits_locked: bool = false
var _fired_triggers: Dictionary = {}
var _director: LxAttackDirector = null
var _vars_connected: LxWorldState = null
var _loading_region: bool = false

func _ready() -> void:
	_ensure_containers()
	_bind_world_vars()

func _exit_tree() -> void:
	if _vars_connected != null and _vars_connected.var_changed.is_connected(_on_world_var_changed):
		_vars_connected.var_changed.disconnect(_on_world_var_changed)
	_vars_connected = null
	LxRegionRuntime.clear_fields()

func _bind_world_vars() -> void:
	if Lx.vars == null or _vars_connected == Lx.vars: return
	if _vars_connected != null and _vars_connected.var_changed.is_connected(_on_world_var_changed):
		_vars_connected.var_changed.disconnect(_on_world_var_changed)
	_vars_connected = Lx.vars
	if not _vars_connected.var_changed.is_connected(_on_world_var_changed):
		_vars_connected.var_changed.connect(_on_world_var_changed)

func _on_world_var_changed(scope: String, var_name: String, value: Variant) -> void:
	if current_region_id.is_empty(): return
	apply_layers(true)
	notify("var:" + var_name, {"scope": scope, "name": var_name, "value": value})

func _ensure_containers() -> void:
	if _greybox_ground == null:
		_greybox_ground = Node2D.new(); _greybox_ground.name = "GreyboxGround"; _greybox_ground.z_index = -10
		_greybox_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_greybox_ground.draw.connect(_draw_greybox_ground); add_child(_greybox_ground)
	if _water_fx == null: _water_fx = LxWaterFx.new(); _water_fx.name = "WaterFx"; add_child(_water_fx)
	if _signal_conduits == null: _signal_conduits = LxSignalConduits.new(); _signal_conduits.name = "SignalConduits"; _signal_conduits.z_index = -6; add_child(_signal_conduits)
	if _visual_teaching == null: _visual_teaching = LxVisualTeachingFx.new(); _visual_teaching.name = "VisualTeachingFx"; _visual_teaching.z_index = -4; add_child(_visual_teaching)
	if _failure_teaching == null: _failure_teaching = LxFailureTeachingFx.new(); _failure_teaching.name = "FailureTeachingFx"; _failure_teaching.z_index = 6; add_child(_failure_teaching)
	if _floor_interactables_root == null: _floor_interactables_root = _make_layer("FloorInteractables", -6, false)
	if _scenery_ground_root == null: _scenery_ground_root = _make_layer("SceneryGround", -5, false)
	if _world_ysort_root == null: _world_ysort_root = _make_layer("WorldYSort", 0, true)
	if _scenery_sort_root == null: _scenery_sort_root = _make_layer("ScenerySort", 0, true, _world_ysort_root)
	if _interactables_root == null: _interactables_root = _make_layer("Interactables", 0, true, _world_ysort_root)
	if _enemies_root == null: _enemies_root = _make_layer("Enemies", 0, true, _world_ysort_root)
	if _ambient_life == null: _ambient_life = LxAmbientLife.new(); _ambient_life.name = "AmbientLife"; _ambient_life.z_index = 3; add_child(_ambient_life)
	if _scenery_over_root == null: _scenery_over_root = _make_layer("SceneryOver", 4, false)
	if _layers == null: _layers = LxRegionLayers.new(); _layers.name = "RegionLayers"; add_child(_layers)
	if _arena == null: _arena = LxRegionArena.new(); _arena.name = "RegionArena"; add_child(_arena)

func _make_layer(layer_name: String, z: int, y_sort: bool, parent_node: Node = null) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name; n.z_index = z; n.y_sort_enabled = y_sort
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
	map_path: String, json_path: String, director: LxAttackDirector,
	island_override: int = -1, region_override: String = ""
) -> bool:
	_ensure_containers()
	_bind_world_vars()
	if not current_region_id.is_empty(): save_interactables_to_state()
	_clear_loaded()
	var parsed: Dictionary = LxMapFormat.parse_region(map_path, json_path)
	var w: int = int(parsed.get("width", 0)); var h: int = int(parsed.get("height", 0))
	if w <= 0 or h <= 0:
		push_warning("LxRegionLoader: failed to parse map " + map_path); return false
	_director = director; region_data = parsed
	current_island_id = island_override if island_override >= 0 else int(parsed.get("island_id", 1))
	current_region_id = region_override if not region_override.is_empty() else str(parsed.get("id", "region"))
	width = w; height = h; tile_size = int(parsed.get("tile_size", LxMapFormat.DEFAULT_TILE_SIZE))
	grid.clear(); grid.assign(parsed.get("grid", []))
	bounds = parsed.get("bounds", Rect2(0.0, 0.0, float(w * tile_size), float(h * tile_size))) as Rect2
	var reg_dng: String = Lx.packs.dungeon_of(current_island_id, current_region_id) if Lx.packs != null else ""
	is_dungeon = bool(parsed.get("is_dungeon", not reg_dng.is_empty()))
	spawn_pos = LxMapFormat.to_vec2(parsed.get("spawn", [bounds.size.x * 0.5, bounds.size.y * 0.5]))
	_room_anchor_pos = spawn_pos
	zones.clear(); zones.assign(parsed.get("zones", []))
	exits.clear(); exits.assign(parsed.get("exits", []))
	triggers.clear(); triggers.assign(parsed.get("triggers", []))
	rooms = LxMapFormat._ensure_dict_array(parsed.get("rooms", []))
	_ground_sprite = LxRegionRuntime.setup_ground_visual(self)
	var scenery_raw: Variant = parsed.get("scenery", [])
	if scenery_raw is Array:
		_scenery_props = LxSceneryProp.spawn_from_specs(scenery_raw as Array, _scenery_ground_root, _scenery_sort_root, _scenery_over_root)
	var inter_specs: Array[Dictionary] = []; inter_specs.assign(parsed.get("interactables", []))
	_loading_region = true
	for spec: Dictionary in inter_specs: spawn_interactable(spec)
	LxRegionRuntime.promote_destructible_map_tiles(self)
	load_interactables_from_state()
	_loading_region = false
	if _signal_conduits != null: _signal_conduits.rebuild(self)
	if LxLegacy.is_legacy_region(current_island_id, current_region_id):
		if _visual_teaching != null: _visual_teaching.rebuild(self)
		if _failure_teaching != null: _failure_teaching.rebuild(self)
	var enemy_specs: Array[Dictionary] = []; enemy_specs.assign(parsed.get("enemies", []))
	for espec: Dictionary in enemy_specs: spawn_enemy(espec)
	var layer_specs: Array[Dictionary] = []; layer_specs.assign(parsed.get("layers", []))
	if _layers != null: _layers.setup(self, layer_specs, grid)
	if not is_point_safe(spawn_pos):
		var safe_sp: Vector2 = find_nearest_safe_point(spawn_pos)
		if safe_sp.x >= 0.0:
			spawn_pos = safe_sp
			_room_anchor_pos = safe_sp
	_signal_states = LxRegionRuntime.snapshot_signals(_interactables)
	var ev_specs: Array[Dictionary] = []; ev_specs.assign(parsed.get("events", []))
	if not ev_specs.is_empty(): room_script = LxRegionRuntime.create_room_script(self, ev_specs)
	if Lx.state != null:
		Lx.state.island_id = current_island_id; Lx.state.region_id = current_region_id
		Lx.state.mark_region_visited(current_island_id, current_region_id)
	_init_camera(spawn_pos)
	var cam_p: Vector2 = Lx.camera.global_position if Lx.camera != null else spawn_pos
	if _water_fx != null: _water_fx.configure(grid, tile_size, current_island_id, is_dungeon); _water_fx.tick(0.0, cam_p)
	if _ambient_life != null: _ambient_life.configure(current_island_id, bounds, is_dungeon); _ambient_life.tick(0.0, cam_p)
	_redraw_ground()
	if Lx.events != null: Lx.events.region_entered.emit(current_island_id, current_region_id)
	return true

func discard_loaded() -> void:
	_clear_loaded()
	current_region_id = ""

func _clear_loaded() -> void:
	LxRegionRuntime.clear_fields()
	if room_script != null:
		if room_script.has_method("cleanup"): room_script.call("cleanup")
		if room_script is Node and is_instance_valid(room_script as Node): (room_script as Node).queue_free()
		room_script = null
	if _layers != null: _layers.clear()
	if _arena != null: _arena.reset(self)
	if _director != null: _director.clear()
	_enemies.clear(); _interactables.clear(); _interactables_by_id.clear()
	_inter_defaults.clear(); _signal_states.clear()
	if _signal_conduits != null: _signal_conduits.clear()
	if _visual_teaching != null: _visual_teaching.clear()
	if _failure_teaching != null: _failure_teaching.clear()
	_lens_circles.clear(); _fired_triggers.clear()
	_current_room_id = ""; _current_room_rect = Rect2()
	_room_anchor_pos = Vector2(-1.0, -1.0); _exits_locked = false
	if _ground_sprite != null:
		if is_instance_valid(_ground_sprite):
			if _ground_sprite.get_parent() != null: _ground_sprite.get_parent().remove_child(_ground_sprite)
			_ground_sprite.free()
		_ground_sprite = null
	_scenery_props.clear()
	for sroot: Node2D in [_scenery_ground_root, _scenery_sort_root, _scenery_over_root]:
		if sroot != null:
			for c: Node in sroot.get_children():
				sroot.remove_child(c)
				c.free()
	for root_node: Node2D in [_floor_interactables_root, _interactables_root, _enemies_root]:
		if root_node != null:
			for c: Node in root_node.get_children():
				if c is CanvasItem: (c as CanvasItem).visible = false
				root_node.remove_child(c)
				c.queue_free()

# ---- Frozen Loader API (CONTRACTS.md) ----

func apply_layers(animate: bool = true) -> void:
	if _layers != null and _layers.apply(animate): _on_tiles_mutated()

func _on_tiles_mutated() -> void:
	if _water_fx != null: _water_fx.configure(grid, tile_size, current_island_id, is_dungeon)
	_redraw_ground()

func _on_enemy_tree_exiting(brain: LxEnemyBrain) -> void:
	_enemies.erase(brain)

func prune_freed_enemies() -> void:
	for i: int in range(_enemies.size() - 1, -1, -1):
		var e_v: Variant = _enemies[i]
		if e_v == null or not is_instance_valid(e_v) or (e_v is Node and (e_v as Node).is_queued_for_deletion()):
			_enemies.remove_at(i)

func _rebuild_active_enemies() -> void:
	prune_freed_enemies()
	if _layers == null: return
	for e_v: Variant in _enemies:
		if not is_instance_valid(e_v) or not (e_v is LxEnemyBrain): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		var eid: String = e.enemy_id if not e.enemy_id.is_empty() else (str(e.get("id")) if e.get("id") != null else "")
		e.visible = not (not eid.is_empty() and _layers.is_enemy_disabled(eid))

func _redraw_ground() -> void:
	if _greybox_ground != null and is_instance_valid(_greybox_ground): _greybox_ground.queue_redraw()
	queue_redraw()

func set_tiles(rect: Rect2i, tile: String) -> void:
	if width <= 0 or height <= 0 or tile.is_empty(): return
	var x0: int = clampi(rect.position.x, 0, width); var y0: int = clampi(rect.position.y, 0, height)
	var x1: int = clampi(rect.position.x + rect.size.x, 0, width); var y1: int = clampi(rect.position.y + rect.size.y, 0, height)
	if x1 <= x0 or y1 <= y0: return
	for ty: int in range(y0, y1):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(x0, x1): row[tx] = tile
		grid[ty] = row
	if _layers != null: _layers.record_tile_override(Rect2i(x0, y0, x1 - x0, y1 - y0), tile)
	_on_tiles_mutated()

func set_tiles_batch(ops: Array) -> void:
	if width <= 0 or height <= 0 or ops.is_empty(): return
	var changed: bool = false
	for op_v: Variant in ops:
		var r := Rect2i()
		var tile: String = ""
		if op_v is Dictionary:
			var d: Dictionary = op_v as Dictionary
			if d.get("rect") is Rect2i: r = d["rect"] as Rect2i
			tile = str(d.get("tile", ""))
		elif op_v is Array and (op_v as Array).size() >= 5:
			var a: Array = op_v as Array
			r = Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])); tile = str(a[4])
		if tile.is_empty(): continue
		var x0: int = clampi(r.position.x, 0, width); var y0: int = clampi(r.position.y, 0, height)
		var x1: int = clampi(r.position.x + r.size.x, 0, width); var y1: int = clampi(r.position.y + r.size.y, 0, height)
		if x1 <= x0 or y1 <= y0: continue
		for ty: int in range(y0, y1):
			var row: PackedStringArray = grid[ty]
			for tx: int in range(x0, x1): row[tx] = tile
			grid[ty] = row
		if _layers != null: _layers.record_tile_override(Rect2i(x0, y0, x1 - x0, y1 - y0), tile, false)
		changed = true
	if changed:
		if _layers != null: _layers.flush_tile_overrides()
		_on_tiles_mutated()

func spawn_enemy(spec: Dictionary) -> LxEnemyBrain:
	_ensure_containers()
	return LxRegionRuntime.spawn_enemy_for_region(self, spec, _director, _enemies_root, _enemies)

func spawn_interactable(spec: Dictionary) -> LxInteractable:
	_ensure_containers()
	var req_id: String = str(spec.get("id", ""))
	if not req_id.is_empty() and _interactables_by_id.has(req_id):
		var existing: Variant = _interactables_by_id[req_id]
		if existing is LxInteractable and is_instance_valid(existing):
			return existing as LxInteractable
	var prepped: Dictionary = LxRegionRuntime.prepare_interactable_spec(spec, current_island_id, current_region_id)
	var item: LxInteractable = LxInteractableFactory.create(prepped)
	if item == null: return null
	item.region = self; item.island_id = current_island_id; item.region_id = current_region_id
	item.setup(prepped)
	if not item.id.is_empty():
		_inter_defaults[item.get_state_key()] = LxRegionRuntime.capture_authored_default(item, prepped)
		_interactables_by_id[item.id] = item
	_sync_interactable_layer(item)
	_interactables.append(item)
	if not _loading_region and Lx.state != null and not item.id.is_empty():
		var skey: String = item.get_state_key()
		if Lx.state.interactable_states.has(skey) and Lx.state.interactable_states[skey] is Dictionary:
			item.load_state(Lx.state.interactable_states[skey] as Dictionary)
			_sync_interactable_layer(item)
	return item

func remove_interactable(id: String) -> void:
	if id.is_empty(): return
	var item: LxInteractable = find_interactable(id)
	if item == null: return
	_interactables.erase(item); _interactables_by_id.erase(id)
	_inter_defaults.erase(item.get_state_key()); _signal_states.erase(id)
	if is_instance_valid(item): item.queue_free()

func lock_exits(locked: bool) -> void: _exits_locked = locked
func is_arena_locked() -> bool: return _exits_locked or (_arena != null and _arena.locked)
func get_wick() -> LxWick: return Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
func add_field(f: Object) -> void: LxRegionRuntime.add_field(f)

func notify(event: String, data: Dictionary = {}) -> void:
	room_notified.emit(event, data)
	if room_script != null and room_script.has_method("notify"): room_script.call("notify", event, data)

func is_point_safe(p: Vector2) -> bool:
	if _layers != null: return _layers.is_point_safe(p)
	if bounds.has_area() and not bounds.has_point(p): return false
	if is_lethal_void_at(p): return false
	return not is_solid_tile(tile_at(p), false, false)

func find_nearest_safe_point(from_pos: Vector2) -> Vector2:
	if _layers != null: return _layers.find_nearest_safe_tile_center(from_pos)
	return spawn_pos

func set_room_anchor(p: Vector2) -> void:
	if not p.is_finite() or p.x < 0.0 or p.y < 0.0: return
	if not is_point_safe(p): return
	_room_anchor_pos = p
	if bounds.has_area() and bounds.has_point(p): spawn_pos = p
	if Lx.state != null and not current_region_id.is_empty():
		Lx.state.room_anchor_region = "%d:%s" % [current_island_id, current_region_id]
		Lx.state.room_anchor_pos = p

func get_room_anchor() -> Vector2: return _room_anchor_pos if _room_anchor_pos.x >= 0.0 else spawn_pos

# ---- Layering, Camera, Collision & Queries ----

func _is_floor_interactable(item: LxInteractable) -> bool:
	if item == null: return false
	if item.has_method("is_floor_toy") and bool(item.call("is_floor_toy")): return true
	if item.kind in [
		"blue_portal", "phantom_platform", "floor_switch", "room_anchor", "pressure_plate",
		"floor_sigil", "scale", "logic_gate", "light_plant", "conveyor", "crumble_floor", "spike_floor",
		"moon_pool", "star_node", "star_bell_socket", "updraft_vent", "optic_well", "tide_raft",
	]: return true
	if item.kind == "star_bell" and (not item.is_solid() or bool(item.props.get("socket", false))): return true
	if item.kind in ["toggle_block", "tone_door", "shadow_gate"] and not item.is_solid(): return true
	if item is LxDoor:
		var d: LxDoor = item as LxDoor
		return d.door_type == "bridge_platform" or (bool(d.get("_is_light_bridge")) and d.opened)
	return false

func _sync_interactable_layer(item: LxInteractable) -> void:
	if item == null or not is_instance_valid(item): return
	var target: Node2D = _floor_interactables_root if _is_floor_interactable(item) else _interactables_root
	if target == null: return
	if item.get_parent() == null: target.add_child(item)
	elif item.get_parent() != target: item.reparent(target, false)

func _init_camera(focus_pos: Vector2) -> void:
	if is_dungeon:
		var rinfo: Dictionary = LxRegionRuntime.resolve_room_for_pos(self, focus_pos, ROOM_W, ROOM_H)
		_current_room_id = str(rinfo.get("id", "r_0_0")); _current_room_rect = rinfo.get("rect", bounds) as Rect2
	else:
		_current_room_id = ""; _current_room_rect = bounds
	if Lx.state != null: Lx.state.room_id = _current_room_id
	if Lx.camera != null: Lx.camera.set_bounds(_current_room_rect, is_dungeon); Lx.camera.snap_to(focus_pos)

func update_dungeon_room(player_pos: Vector2) -> void:
	if not is_dungeon: return
	var rinfo: Dictionary = LxRegionRuntime.resolve_room_for_pos(self, player_pos, ROOM_W, ROOM_H)
	var rid: String = str(rinfo.get("id", "")); var rrect: Rect2 = rinfo.get("rect", bounds) as Rect2
	if rid.is_empty() or rid == _current_room_id: return
	_current_room_id = rid; _current_room_rect = rrect
	if Lx.state != null: Lx.state.room_id = rid
	if Lx.camera != null: Lx.camera.slide_to_room(rrect, ROOM_SLIDE_S)
	if Lx.events != null: Lx.events.room_changed.emit(current_island_id, rid)

func get_current_room_rect() -> Rect2: return _current_room_rect if _current_room_rect.size.x > 0.0 else bounds
func get_current_room_id() -> String: return _current_room_id

func collide(pos: Vector2, radius: float, can_cross_pit: bool = false, can_cross_water: bool = false, ignore_id: String = "", is_flying: bool = false) -> Vector2:
	return LxRegionArena.collide_world(self, pos, radius, can_cross_pit, can_cross_water, ignore_id, is_arena_locked(), is_flying)

func collide_ignoring(pos: Vector2, radius: float, ignore_id: String, can_cross_pit: bool = false, can_cross_water: bool = false) -> Vector2:
	return collide(pos, radius, can_cross_pit, can_cross_water, ignore_id)

func can_place_rect(rect: Rect2, ignore_id: String = "") -> bool:
	return LxRegionArena.can_place_rect_world(self, rect, ignore_id)

func _is_tile_supported(tile_type: String, tile_center: Vector2) -> bool:
	return LxRegionRuntime.is_tile_supported(self, tile_type, tile_center, _lens_circles)

static func _push_circle_out_of_rect(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	return LxRegionArena.push_circle_out_of_rect(center, radius, rect)

func clear_view(a: Vector2, b: Vector2) -> bool:
	return LxRegionArena.clear_view_world(self, a, b, null)

func tile_at(world_pos: Vector2) -> String:
	if tile_size <= 0 or width <= 0 or height <= 0: return "void"
	var tx: int = int(floor(world_pos.x / float(tile_size))); var ty: int = int(floor(world_pos.y / float(tile_size)))
	return grid[ty][tx] if (tx >= 0 and ty >= 0 and tx < width and ty < height) else "void"

func is_solid_tile(tile_type: String, can_cross_pit: bool = false, can_cross_water: bool = false) -> bool:
	return LxMapFormat.is_solid_tile(tile_type, can_cross_pit, can_cross_water)

func is_lethal_void_at(world_pos: Vector2) -> bool:
	if width <= 0 or height <= 0: return false
	var ttype: String = tile_at(world_pos)
	if ttype in ["pit", "void", "phantom", "water", "tide"]:
		var ts: float = float(tile_size)
		var tc := Vector2((floorf(world_pos.x / ts) + 0.5) * ts, (floorf(world_pos.y / ts) + 0.5) * ts)
		if _is_tile_supported(ttype, world_pos) or _is_tile_supported(ttype, tc):
			return false
		# 2.5px foot-rim coyote footing so Wick doesn't dangle/die on a 1px floor edge
		for off: Vector2 in [Vector2(2.5, 0.0), Vector2(-2.5, 0.0), Vector2(0.0, 2.5), Vector2(0.0, -2.5)]:
			var p2: Vector2 = world_pos + off
			var t2: String = tile_at(p2)
			if t2 in ["ground", "path", "bridge"] or (t2 in ["pit", "void", "phantom", "water", "tide"] and _is_tile_supported(t2, p2)):
				return false
		return true
	return false

func is_hazard_at(world_pos: Vector2) -> bool: return is_lethal_void_at(world_pos)

func find_interactable(id: String) -> LxInteractable:
	var found: Variant = _interactables_by_id.get(id, null)
	return found as LxInteractable if found is LxInteractable else null

func check_exit(pos: Vector2) -> Dictionary:
	if is_arena_locked(): return {}
	for ex: Dictionary in exits:
		var eid: String = str(ex.get("id", ""))
		if _layers != null and _layers.is_exit_disabled(eid): continue
		if room_script != null and room_script.has_method("is_exit_locked") and bool(room_script.call("is_exit_locked", eid)): continue
		if not LxMapFormat.to_rect2(ex.get("rect", [])).has_point(pos): continue
		var door_id: String = str(ex.get("locked_door_id", ""))
		if not door_id.is_empty():
			var door: LxInteractable = find_interactable(door_id)
			if door != null and door.is_solid(): continue
		if LxRegionRuntime.exit_requirements_met(ex): return ex
	return {}

func save_interactables_to_state() -> void:
	LxRegionRuntime.save_dirty_interactables(_interactables, _inter_defaults, _layers)

func load_interactables_from_state() -> void:
	if Lx.state == null: return
	for it: LxInteractable in _interactables:
		if it != null and not it.id.is_empty():
			var key: String = it.get_state_key()
			if Lx.state.interactable_states.has(key) and Lx.state.interactable_states[key] is Dictionary:
				it.load_state(Lx.state.interactable_states[key] as Dictionary)
				_sync_interactable_layer(it)

func tick(dt: float, player_pos: Vector2 = Vector2(-9999.0, -9999.0)) -> void:
	var start_isl: int = current_island_id
	var start_reg: String = current_region_id
	_lens_circles.clear()
	for sp: LxSceneryProp in _scenery_props:
		if sp != null and sp.animated: sp.tick(dt)
	var cam_pos: Vector2 = Lx.camera.global_position if Lx.camera != null else (player_pos if player_pos.x > -9000.0 else spawn_pos)
	if _water_fx != null: _water_fx.tick(dt, cam_pos)
	if _ambient_life != null: _ambient_life.tick(dt, cam_pos)
	if _signal_conduits != null: _signal_conduits.tick(dt)
	if _visual_teaching != null: _visual_teaching.tick(dt, cam_pos)
	if _failure_teaching != null: _failure_teaching.tick(dt, cam_pos)
	if _layers != null: _layers.tick(dt)
	for it: LxInteractable in _interactables:
		if it != null:
			it.tick(dt)
			if it is LxDoor or it.kind in ["toggle_block", "tone_door", "shadow_gate"] or it.has_method("is_floor_toy"): _sync_interactable_layer(it)
	LxRegionRuntime.poll_signals(self, _signal_states)
	if current_island_id != start_isl or current_region_id != start_reg: return
	if room_script != null and room_script.has_method("tick"): room_script.call("tick", dt)
	if current_island_id != start_isl or current_region_id != start_reg: return
	if player_pos.x > -9000.0:
		LxRegionRuntime.check_triggers(self, player_pos, _fired_triggers)
		if is_dungeon: update_dungeon_room(player_pos)

func tick_region(dt: float, player_pos: Vector2 = Vector2.ZERO) -> int:
	var start_isl: int = current_island_id
	var start_reg: String = current_region_id
	var ppos: Vector2 = get_wick_pos() if (player_pos == Vector2.ZERO and Lx.player != null and is_instance_valid(Lx.player)) else player_pos
	tick(dt, ppos)
	if current_island_id != start_isl or current_region_id != start_reg: return 0
	prune_freed_enemies()
	var engaged: int = 0
	for e_v: Variant in _enemies:
		if is_instance_valid(e_v) and e_v is LxEnemyBrain:
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if e.is_alive() and e.visible:
				e.tick(dt)
				if current_island_id != start_isl or current_region_id != start_reg: return engaged
				if e.is_alive() and e.state != LxEnemyBrain.State.ROUTINE and e.state != LxEnemyBrain.State.RETURN and e.state != LxEnemyBrain.State.DEAD:
					engaged += 1
	if _arena != null: _arena.tick(dt, self, ppos)
	return engaged

func get_spawn_pos() -> Vector2: return spawn_pos
func collide_fly(pos: Vector2, radius: float) -> Vector2: return collide(pos, radius, true, true, "", true)
func get_bounds() -> Rect2: return bounds
func get_enemies() -> Array[LxEnemyBrain]:
	prune_freed_enemies()
	return _enemies
func get_interactables() -> Array[LxInteractable]: return _interactables
func get_zones() -> Array[Dictionary]: return zones
func is_lantern_hung() -> bool: return get_lantern_state() == 2
func is_lantern_out() -> bool: return get_lantern_state() in [1, 2]
func get_wick_pos() -> Vector2: return LxRegionRuntime.wick_pos()
func get_lantern_state() -> int: return LxRegionRuntime.lantern_state()
func get_lantern_pos() -> Vector2: return LxRegionRuntime.lantern_pos()

func apply_light(world_pos: Vector2, light_radius: float, source: String) -> void:
	if light_radius <= 0.0: return
	if source == "lens" or source == "lens_anchor": _lens_circles.append(Vector3(world_pos.x, world_pos.y, light_radius))
	for it: LxInteractable in _interactables:
		if it != null and it.active:
			var reach: float = light_radius + it.radius
			if it.pos.distance_squared_to(world_pos) <= reach * reach:
				if source == "lens" or source == "lens_anchor" or LxRegionArena.clear_view_world(self, world_pos, it.pos, it):
					it.on_light(light_radius, source)

func try_interact(actor: Node, actor_pos: Vector2, reach: float = 20.0) -> LxInteractable:
	var best: LxInteractable = null; var best_d2: float = INF
	for it: LxInteractable in _interactables:
		if it == null or not it.active: continue
		var max_r: float = reach + it.radius
		var d2: float = it.pos.distance_squared_to(actor_pos)
		if d2 <= max_r * max_r and d2 < best_d2: best = it; best_d2 = d2
	if best != null and best.interact(actor):
		save_interactables_to_state(); return best
	return null

func hit_interactables(hit: LxHit, hit_pos: Vector2, hit_radius: float = 8.0) -> LxInteractable:
	for it: LxInteractable in _interactables:
		if it == null or not it.active: continue
		var hit_ok: bool = it.get_solid_rect().grow(hit_radius).has_point(hit_pos) if it.is_solid() else (
			it.pos.distance_squared_to(hit_pos) <= (it.radius + hit_radius) * (it.radius + hit_radius)
		)
		if hit_ok and it.on_hit(hit):
			save_interactables_to_state(); return it
	return null

func is_zone_cleared(zone_id: String = "") -> bool:
	prune_freed_enemies()
	for e_v: Variant in _enemies:
		if not is_instance_valid(e_v) or not (e_v is LxEnemyBrain): continue
		var e: LxEnemyBrain = e_v as LxEnemyBrain
		if not e.is_alive() or not e.visible: continue
		if zone_id.is_empty() or e.zone == zone_id: return false
	return true

func is_zone_lit(zone_id: String) -> bool: return LxRegionRuntime.is_zone_lit(self, zone_id)
func get_light_pools() -> Array[Vector4]: return LxRegionRuntime.get_light_pools(_interactables, _scenery_props)
func is_flag_set(flag: String) -> bool: return check_flag_static(flag)
static func check_flag_static(flag: String) -> bool: return LxRegionRuntime.check_flag_static(flag)

func _draw_greybox_ground() -> void:
	if _ground_sprite != null or width <= 0 or height <= 0: return
	var ts: float = float(tile_size)
	for ty: int in range(height):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(width): GreyboxDraw.draw_tile(_greybox_ground, tx, ty, ts, row[tx])
