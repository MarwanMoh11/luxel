class_name LxMapFormat
extends RefCounted
## Parser for Luxel 1.0 .map text grids and sibling .json placement files.
## Shared by LxRegionLoader at runtime and QA reach_check / tools so art and collision never drift.

const DEFAULT_TILE_SIZE: int = 16

const DEFAULT_LEGEND: Dictionary = {
	".": "ground",
	"#": "wall",
	",": "path",
	"~": "water",
	"O": "pit",
	"_": "void",
	"B": "bramble",
	"C": "cracked",
	"T": "tide",
	"P": "phantom",
	"+": "bridge",
	"G": "glass",
	" ": "void",
}


static func parse_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LxMapFormat.parse_map missing: " + path)
		return _empty_map()
	var text: String = FileAccess.get_file_as_string(path)
	return parse_map_text(text)


static func parse_map_text(text: String) -> Dictionary:
	var legend: Dictionary = DEFAULT_LEGEND.duplicate()
	var tile_size: int = DEFAULT_TILE_SIZE
	var raw_rows: PackedStringArray = PackedStringArray()
	var in_map: bool = false
	var saw_map_marker: bool = false

	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	for raw_line: String in lines:
		if not in_map:
			var trimmed: String = raw_line.strip_edges()
			if trimmed.is_empty() or trimmed.begins_with("#"):
				continue
			if trimmed == "MAP":
				in_map = true
				saw_map_marker = true
				continue
			if trimmed.begins_with("TILE_SIZE "):
				var ts: int = int(trimmed.substr(10).strip_edges())
				if ts > 0:
					tile_size = ts
				continue
			if trimmed.begins_with("LEGEND "):
				var rest: String = trimmed.substr(7).strip_edges()
				var parts: PackedStringArray = rest.split(" ", false)
				if parts.size() >= 2:
					var ch: String = parts[0].substr(0, 1)
					var tile_type: String = parts[1].strip_edges().to_lower()
					if not ch.is_empty() and not tile_type.is_empty():
						legend[ch] = tile_type
				continue
		else:
			var stripped: String = raw_line.strip_edges()
			if stripped.is_empty():
				continue
			if stripped == "END" or stripped == "ENDMAP":
				break
			raw_rows.append(raw_line)

	# Fallback for headerless raw grid files
	if not saw_map_marker and raw_rows.is_empty():
		for raw_line: String in lines:
			if not raw_line.strip_edges().is_empty():
				raw_rows.append(raw_line)

	var height: int = raw_rows.size()
	var width: int = 0
	for row: String in raw_rows:
		if row.length() > width:
			width = row.length()

	var grid: Array[PackedStringArray] = []
	grid.resize(height)
	for y: int in range(height):
		var src: String = raw_rows[y]
		var tile_row := PackedStringArray()
		tile_row.resize(width)
		for x: int in range(width):
			var ch: String = src.substr(x, 1) if x < src.length() else "_"
			if legend.has(ch):
				tile_row[x] = str(legend[ch])
			else:
				tile_row[x] = "void"
		grid[y] = tile_row

	return {
		"width": width,
		"height": height,
		"tile_size": tile_size,
		"legend": legend,
		"grid": grid,
		"raw_rows": raw_rows,
	}


static func parse_region(map_path: String, json_path: String) -> Dictionary:
	var m: Dictionary = parse_map(map_path)
	var j: Dictionary = {}
	if not json_path.is_empty() and FileAccess.file_exists(json_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			j = parsed as Dictionary
		else:
			push_warning("LxMapFormat.parse_region invalid JSON: " + json_path)

	var width: int = int(m.get("width", 0))
	var height: int = int(m.get("height", 0))
	var tile_size: int = int(j.get("tile_size", m.get("tile_size", DEFAULT_TILE_SIZE)))
	if tile_size <= 0:
		tile_size = DEFAULT_TILE_SIZE
	var px_w: float = float(width * tile_size)
	var px_h: float = float(height * tile_size)

	var out: Dictionary = j.duplicate(true)
	var default_id: String = map_path.get_file().get_basename()
	out["id"] = str(j.get("id", default_id))
	out["island_id"] = int(j.get("island_id", 1))
	out["tile_size"] = tile_size
	out["is_dungeon"] = bool(j.get("is_dungeon", false))
	out["width"] = width
	out["height"] = height
	out["pixel_width"] = int(px_w)
	out["pixel_height"] = int(px_h)
	out["bounds"] = Rect2(0.0, 0.0, px_w, px_h)
	out["legend"] = m.get("legend", DEFAULT_LEGEND.duplicate())
	out["grid"] = m.get("grid", [] as Array[PackedStringArray])
	out["raw_rows"] = m.get("raw_rows", PackedStringArray())
	out["map_path"] = map_path
	out["json_path"] = json_path

	var default_spawn: Array = [px_w * 0.5, px_h * 0.5]
	if not out.has("spawn"):
		out["spawn"] = default_spawn
	out["spawn_vec"] = to_vec2(out.get("spawn", default_spawn))

	out["zones"] = _ensure_dict_array(j.get("zones", []))
	out["exits"] = _ensure_dict_array(j.get("exits", []))
	out["enemies"] = _ensure_dict_array(j.get("enemies", []))
	out["interactables"] = _ensure_dict_array(j.get("interactables", []))
	out["triggers"] = _ensure_dict_array(j.get("triggers", []))
	out["scenery"] = _ensure_dict_array(j.get("scenery", []))
	return out


static func tile_at_grid(region_dict: Dictionary, world_pos: Vector2) -> String:
	var ts: int = int(region_dict.get("tile_size", DEFAULT_TILE_SIZE))
	var w: int = int(region_dict.get("width", 0))
	var h: int = int(region_dict.get("height", 0))
	if ts <= 0 or w <= 0 or h <= 0:
		return "void"
	var tx: int = int(floor(world_pos.x / float(ts)))
	var ty: int = int(floor(world_pos.y / float(ts)))
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return "void"
	var grid: Array = region_dict.get("grid", []) as Array
	if ty >= grid.size():
		return "void"
	var row: PackedStringArray = grid[ty] as PackedStringArray
	if tx >= row.size():
		return "void"
	return row[tx]


static func is_solid_tile(tile_type: String, can_cross_pit: bool = false, can_cross_water: bool = false) -> bool:
	match tile_type:
		"ground", "path", "bridge":
			return false
		"pit", "phantom":
			return not can_cross_pit
		"water", "tide":
			return not can_cross_water
		"wall", "void", "bramble", "cracked", "glass", "mirror":
			return true
		_:
			return true


static func blocks_sight_tile(tile_type: String) -> bool:
	match tile_type:
		"wall", "bramble", "cracked", "glass", "mirror":
			return true
		_:
			return false


static func to_vec2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is Array and (v as Array).size() >= 2:
		var arr: Array = v as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


static func to_rect2(v: Variant, fallback: Rect2 = Rect2()) -> Rect2:
	if v is Rect2:
		return v as Rect2
	if v is Array and (v as Array).size() >= 4:
		var arr: Array = v as Array
		return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return fallback


static func _ensure_dict_array(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for item: Variant in v:
			if item is Dictionary:
				out.append((item as Dictionary).duplicate(true))
	return out


static func _empty_map() -> Dictionary:
	var empty_grid: Array[PackedStringArray] = []
	return {
		"width": 0,
		"height": 0,
		"tile_size": DEFAULT_TILE_SIZE,
		"legend": DEFAULT_LEGEND.duplicate(),
		"grid": empty_grid,
		"raw_rows": PackedStringArray(),
	}
