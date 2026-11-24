class_name LxRegionLayers
extends Node2D
## Dynamic tile layers + 1.2 s line-sweep transition for LxRegionLoader (SPEC 3.2).
## Zero per-frame work when no transition is running.

const GreyboxDraw := preload("res://luxel/world/greybox_draw.gd")
const SWEEP_DUR: float = 1.2

var _region: LxRegionLoader = null
var _layers: Array[Dictionary] = []
var _base_grid: Array[PackedStringArray] = []
var _tile_overrides: Array[Dictionary] = [] # {rect: Rect2i, tile: String}
var _active_ids: PackedStringArray = PackedStringArray()
var _initialized: bool = false

var _overlay_root: Node2D = null
var _overlay_sprites: Dictionary = {} # layer_id -> Sprite2D
var _greybox_overlay: Node2D = null
var _changed_cells: Array[Dictionary] = [] # {tx, ty, tile}
var _sweep_t: float = 0.0
var _sweep_dir_vertical: bool = false

var _disabled_exits: Dictionary = {}
var _disabled_enemies: Dictionary = {}
var _disabled_inters: Dictionary = {}
var _saved_inter_active: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5


func setup(region: LxRegionLoader, layer_specs: Array[Dictionary], base_grid: Array[PackedStringArray]) -> void:
	clear()
	_region = region
	_layers = layer_specs.duplicate(true)
	_base_grid = _clone_grid(base_grid)
	_initialized = false
	_ensure_overlay_nodes()
	if not _layers.is_empty():
		apply(false)
	else:
		_initialized = true


func clear() -> void:
	_layers.clear()
	_base_grid.clear()
	_tile_overrides.clear()
	_active_ids = PackedStringArray()
	_changed_cells.clear()
	_disabled_exits.clear()
	_disabled_enemies.clear()
	_disabled_inters.clear()
	_saved_inter_active.clear()
	_sweep_t = 0.0
	_initialized = false
	for sp: Variant in _overlay_sprites.values():
		if sp is Node and is_instance_valid(sp as Node):
			(sp as Node).queue_free()
	_overlay_sprites.clear()
	if _greybox_overlay != null and is_instance_valid(_greybox_overlay):
		_greybox_overlay.queue_redraw()
	queue_redraw()


func _ensure_overlay_nodes() -> void:
	if _region == null:
		return
	if _overlay_root == null or not is_instance_valid(_overlay_root):
		_overlay_root = Node2D.new()
		_overlay_root.name = "LayerOverlays"
		_overlay_root.z_index = -9
		_region.add_child(_overlay_root)
	if _greybox_overlay == null or not is_instance_valid(_greybox_overlay):
		_greybox_overlay = Node2D.new()
		_greybox_overlay.name = "LayerTileDraw"
		_greybox_overlay.z_index = -9
		_greybox_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_greybox_overlay.draw.connect(_draw_changed_tiles)
		_region.add_child(_greybox_overlay)


func has_layers() -> bool:
	return not _layers.is_empty()

func is_transitioning() -> bool:
	return _sweep_t > 0.0


func is_exit_disabled(exit_id: String) -> bool:
	return not exit_id.is_empty() and bool(_disabled_exits.get(exit_id, false))


func is_enemy_disabled(enemy_id: String) -> bool:
	return not enemy_id.is_empty() and bool(_disabled_enemies.get(enemy_id, false))


func record_tile_override(rect: Rect2i, tile: String) -> void:
	_tile_overrides.append({"rect": rect, "tile": tile})
	_rebuild_changed_cells()
	if _greybox_overlay != null:
		_greybox_overlay.queue_redraw()


func apply(allow_animate: bool = true) -> bool:
	if _region == null or _base_grid.is_empty():
		return false
	var next_active := PackedStringArray()
	var active_layers: Array[Dictionary] = []
	for layer: Dictionary in _layers:
		var when_str: String = str(layer.get("when", "")).strip_edges()
		if when_str.is_empty():
			continue
		var matched: bool = Lx.vars.eval(when_str, _region.current_island_id, _region.current_region_id) if Lx.vars != null else false
		if matched:
			next_active.append(str(layer.get("id", "")))
			active_layers.append(layer)

	if _initialized and next_active == _active_ids:
		return false

	var was_init: bool = _initialized
	_initialized = true
	_active_ids = next_active

	# 1. Rebuild grid from base + active layers + explicit set_tiles overrides.
	var new_grid: Array[PackedStringArray] = _clone_grid(_base_grid)
	for layer: Dictionary in active_layers:
		var tiles_v: Variant = layer.get("tiles", [])
		if tiles_v is Array:
			for entry_v: Variant in (tiles_v as Array):
				if entry_v is Array and (entry_v as Array).size() >= 5:
					var e: Array = entry_v as Array
					_paint_rect(new_grid, Rect2i(int(e[0]), int(e[1]), int(e[2]), int(e[3])), str(e[4]))
	for ov: Dictionary in _tile_overrides:
		_paint_rect(new_grid, ov["rect"] as Rect2i, str(ov["tile"]))
	_region.grid = new_grid

	# 2. Update overlay PNGs & fallback tile overlay.
	_sync_overlays(active_layers)
	_rebuild_changed_cells()

	# 3. Apply enable/disable rules across interactables, enemies, and exits.
	_apply_entity_toggles(active_layers)

	# 4. Refresh region subsystems and safely relocate Wick.
	_region._on_tiles_mutated()
	relocate_wick_if_unsafe()

	# 5. Start readable 1.2 s sweep transition on live runtime change.
	if was_init and allow_animate:
		_sweep_t = SWEEP_DUR
		_sweep_dir_vertical = _region.current_island_id == 2
		if Lx.audio != null:
			Lx.audio.play_sfx("tide_surge" if _region.current_island_id == 2 else "phantom_phase", Vector2.ZERO, false)
		queue_redraw()
	return true


func tick(dt: float) -> void:
	if _sweep_t <= 0.0:
		return
	_sweep_t = maxf(0.0, _sweep_t - dt)
	queue_redraw()


func relocate_wick_if_unsafe() -> void:
	if _region == null or Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var wick_node: Node2D = Lx.player as Node2D
	if bool(wick_node.get("dead")):
		return
	var wpos: Vector2 = wick_node.global_position
	if _is_point_safe(wpos):
		return
	var safe: Vector2 = _find_nearest_safe_tile_center(wpos)
	if safe.x >= 0.0:
		wick_node.global_position = safe
		wick_node.set("last_pos", safe)
		wick_node.set("_last_safe_pos", safe)


func _is_point_safe(pt: Vector2) -> bool:
	if _region == null:
		return true
	if _region.is_lethal_void_at(pt):
		return false
	if _region.is_solid_tile(_region.tile_at(pt), false, false):
		return false
	for it: LxInteractable in _region.get_interactables():
		if it != null and is_instance_valid(it) and it.is_solid() and it.get_solid_rect().grow(3.0).has_point(pt):
			return false
	return true


func _find_nearest_safe_tile_center(from_pos: Vector2) -> Vector2:
	if _region == null or _region.width <= 0 or _region.height <= 0:
		return Vector2(-1.0, -1.0)
	var ts: float = float(_region.tile_size)
	var sx: int = clampi(int(floorf(from_pos.x / ts)), 0, _region.width - 1)
	var sy: int = clampi(int(floorf(from_pos.y / ts)), 0, _region.height - 1)
	var queue: Array[Vector2i] = [Vector2i(sx, sy)]
	var visited: Dictionary = {Vector2i(sx, sy): true}
	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var center := Vector2((float(cur.x) + 0.5) * ts, (float(cur.y) + 0.5) * ts)
		if _is_point_safe(center):
			return center
		for d: Vector2i in dirs:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or ny < 0 or nx >= _region.width or ny >= _region.height:
				continue
			var ncell := Vector2i(nx, ny)
			if not visited.has(ncell):
				visited[ncell] = true
				queue.append(ncell)
	return _region.spawn_pos


func _apply_entity_toggles(active_layers: Array[Dictionary]) -> void:
	var all_enable_controlled: Dictionary = {}
	for layer: Dictionary in _layers:
		var en_v: Variant = layer.get("enable", [])
		if en_v is Array:
			for id_v: Variant in (en_v as Array):
				var eid: String = str(id_v).strip_edges()
				if not eid.is_empty():
					all_enable_controlled[eid] = true

	var desired_disabled: Dictionary = {}
	for eid: Variant in all_enable_controlled.keys():
		desired_disabled[str(eid)] = true
	for layer: Dictionary in active_layers:
		var en_v: Variant = layer.get("enable", [])
		if en_v is Array:
			for id_v: Variant in (en_v as Array):
				desired_disabled.erase(str(id_v).strip_edges())
		var dis_v: Variant = layer.get("disable", [])
		if dis_v is Array:
			for id_v: Variant in (dis_v as Array):
				var did: String = str(id_v).strip_edges()
				if not did.is_empty():
					desired_disabled[did] = true

	_disabled_exits.clear()
	for ex: Dictionary in _region.exits:
		var ex_id: String = str(ex.get("id", ""))
		if not ex_id.is_empty() and desired_disabled.has(ex_id):
			_disabled_exits[ex_id] = true

	_disabled_inters.clear()
	for it: LxInteractable in _region.get_interactables():
		if it == null or not is_instance_valid(it) or it.id.is_empty():
			continue
		var want_off: bool = desired_disabled.has(it.id)
		var was_off: bool = _saved_inter_active.has(it.id)
		if want_off:
			_disabled_inters[it.id] = true
			if not was_off:
				_saved_inter_active[it.id] = it.active
			it.active = false
			it.visible = false
		elif was_off:
			var prev_act: bool = bool(_saved_inter_active[it.id])
			_saved_inter_active.erase(it.id)
			it.active = prev_act
			it.visible = prev_act

	_disabled_enemies.clear()
	for id_k: Variant in desired_disabled.keys():
		_disabled_enemies[str(id_k)] = true
	_region._rebuild_active_enemies()


func _sync_overlays(active_layers: Array[Dictionary]) -> void:
	_ensure_overlay_nodes()
	var active_map: Dictionary = {}
	for layer: Dictionary in active_layers:
		var lid: String = str(layer.get("id", ""))
		if lid.is_empty():
			continue
		active_map[lid] = layer
		if not _overlay_sprites.has(lid):
			var tex: Texture2D = _load_layer_texture(layer, lid)
			if tex != null:
				var sp := Sprite2D.new()
				sp.name = "Overlay_" + lid
				sp.texture = tex
				sp.centered = false
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sp.z_as_relative = false
				sp.z_index = -9
				_overlay_root.add_child(sp)
				_overlay_sprites[lid] = sp
	for lid: Variant in _overlay_sprites.keys():
		var sp: Sprite2D = _overlay_sprites[lid] as Sprite2D
		if sp != null and is_instance_valid(sp):
			sp.visible = active_map.has(str(lid))


func _load_layer_texture(layer: Dictionary, lid: String) -> Texture2D:
	var cands: Array[String] = []
	var ov: String = str(layer.get("overlay", "")).strip_edges()
	if not ov.is_empty():
		if ov.begins_with("res://"):
			cands.append(ov)
		elif ov.ends_with(".png"):
			cands.append("res://luxel/art/islands/%d/%s" % [_region.current_island_id, ov])
		else:
			cands.append("res://luxel/art/islands/%d/%s__%s.png" % [_region.current_island_id, _region.current_region_id, ov])
			cands.append("res://luxel/art/islands/%d/%s.png" % [_region.current_island_id, ov])
	cands.append("res://luxel/art/islands/%d/%s__%s.png" % [_region.current_island_id, _region.current_region_id, lid])
	for path: String in cands:
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is Texture2D:
				return res as Texture2D
		elif FileAccess.file_exists(path):
			var img := Image.new()
			if img.load(ProjectSettings.globalize_path(path)) == OK:
				return ImageTexture.create_from_image(img)
	return null


func _rebuild_changed_cells() -> void:
	_changed_cells.clear()
	if _region == null or _base_grid.is_empty():
		return
	var h: int = mini(_region.height, _base_grid.size())
	for ty: int in range(h):
		var base_row: PackedStringArray = _base_grid[ty]
		var cur_row: PackedStringArray = _region.grid[ty]
		var w: int = mini(base_row.size(), cur_row.size())
		for tx: int in range(w):
			if cur_row[tx] != base_row[tx]:
				_changed_cells.append({"tx": tx, "ty": ty, "tile": cur_row[tx]})
	if _greybox_overlay != null and is_instance_valid(_greybox_overlay):
		_greybox_overlay.queue_redraw()


func _draw_changed_tiles() -> void:
	if _region == null or _changed_cells.is_empty() or _region._ground_sprite == null:
		return
	var any_png_visible: bool = false
	for sp: Variant in _overlay_sprites.values():
		if sp is Sprite2D and is_instance_valid(sp as Node) and (sp as Sprite2D).visible:
			any_png_visible = true
			break
	if any_png_visible and _tile_overrides.is_empty():
		return
	var ts: float = float(_region.tile_size)
	for c: Dictionary in _changed_cells:
		GreyboxDraw.draw_tile(_greybox_overlay, int(c["tx"]), int(c["ty"]), ts, str(c["tile"]))


func _draw() -> void:
	if _sweep_t <= 0.0 or _region == null:
		return
	var u: float = 1.0 - clampf(_sweep_t / SWEEP_DUR, 0.0, 1.0)
	var b: Rect2 = _region.bounds
	var fred: bool = LxHudFx.flash_reduced()
	var fade: float = sin(u * PI) * (0.55 if fred else 0.90)
	var glow: Color = LxBiomePalette.col(_region.current_island_id, "glow")
	var cream: Color = LxPalette.PAL["cream"] as Color
	if _sweep_dir_vertical:
		var sy: float = roundf(lerpf(b.position.y, b.end.y, u))
		draw_rect(Rect2(b.position.x, sy - 6.0, b.size.x, 12.0), Color(glow, fade * 0.35))
		draw_rect(Rect2(b.position.x, sy - 1.0, b.size.x, 2.0), Color(cream, fade))
	else:
		var sx: float = roundf(lerpf(b.position.x, b.end.x, u))
		draw_rect(Rect2(sx - 6.0, b.position.y, 12.0, b.size.y), Color(glow, fade * 0.35))
		draw_rect(Rect2(sx - 1.0, b.position.y, 2.0, b.size.y), Color(cream, fade))


static func _paint_rect(grid: Array[PackedStringArray], rect: Rect2i, tile: String) -> void:
	var h: int = grid.size()
	if h <= 0 or tile.is_empty():
		return
	var w: int = grid[0].size()
	var x0: int = clampi(rect.position.x, 0, w)
	var y0: int = clampi(rect.position.y, 0, h)
	var x1: int = clampi(rect.position.x + rect.size.x, 0, w)
	var y1: int = clampi(rect.position.y + rect.size.y, 0, h)
	for ty: int in range(y0, y1):
		var row: PackedStringArray = grid[ty]
		for tx: int in range(x0, x1):
			row[tx] = tile
		grid[ty] = row


static func _clone_grid(src: Array[PackedStringArray]) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	out.resize(src.size())
	for i: int in range(src.size()):
		out[i] = src[i].duplicate()
	return out
