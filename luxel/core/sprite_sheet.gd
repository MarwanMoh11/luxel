class_name LxSpriteSheet
extends RefCounted
## Cached JSON + PNG sprite-sheet loader and CanvasItem renderer for Luxel 1.0 art sheets.

static var _cache: Dictionary = {}

var tex: Texture2D = null
var animations: Dictionary = {}
var props: Dictionary = {}
var default_anchor: Vector2 = Vector2.ZERO


static func load_sheet(json_path: String) -> LxSpriteSheet:
	if _cache.has(json_path):
		var cached: Variant = _cache[json_path]
		return cached as LxSpriteSheet if cached != null else null
	var data: Dictionary = _read_json(json_path)
	var sheet_name: String = str(data.get("sheet", ""))
	if data.is_empty() or sheet_name.is_empty():
		_cache[json_path] = null
		return null
	var loaded_tex: Texture2D = _load_texture(json_path.get_base_dir().path_join(sheet_name))
	if loaded_tex == null:
		_cache[json_path] = null
		return null
	var sheet := LxSpriteSheet.new()
	sheet.tex = loaded_tex
	var anims_var: Variant = data.get("animations", {})
	if anims_var is Dictionary:
		sheet.animations = anims_var as Dictionary
	var props_var: Variant = data.get("props", {})
	if props_var is Dictionary:
		sheet.props = props_var as Dictionary
	sheet.default_anchor = _to_vec2(data.get("anchor", null), Vector2.ZERO)
	_cache[json_path] = sheet
	return sheet


static func clear_cache() -> void:
	_cache.clear()


func draw_actor(canvas: CanvasItem, origin: Vector2, anim_name: String, facing: Vector2, time_s: float, modulate: Color = Color.WHITE, scale: Vector2 = Vector2.ONE) -> bool:
	if canvas == null or tex == null or animations.is_empty():
		return false
	var anim_var: Variant = animations.get(_resolve_anim_key(anim_name), null)
	if not (anim_var is Dictionary):
		return false
	var anim: Dictionary = anim_var as Dictionary
	var dirs_var: Variant = anim.get("dirs", null)
	if not (dirs_var is Dictionary) or (dirs_var as Dictionary).is_empty():
		return false
	var dirs: Dictionary = dirs_var as Dictionary

	var dir_key: String = "side"
	var flip_x: bool = false
	if absf(facing.y) > absf(facing.x) * 1.15:
		dir_key = "front" if facing.y >= 0.0 else "back"
	else:
		flip_x = facing.x < 0.0
	if not dirs.has(dir_key):
		if dirs.has("front"):
			dir_key = "front"
			flip_x = false
		elif dirs.has("side"):
			dir_key = "side"
			flip_x = facing.x < 0.0
		else:
			dir_key = str(dirs.keys()[0])
			flip_x = false

	var dinfo_var: Variant = dirs.get(dir_key, null)
	if not (dinfo_var is Dictionary):
		return false
	var dinfo: Dictionary = dinfo_var as Dictionary
	var rects_var: Variant = dinfo.get("rects", null)
	if not (rects_var is Array) or (rects_var as Array).is_empty():
		return false
	var rects: Array = rects_var as Array
	var ms_var: Variant = dinfo.get("ms", [])
	var ms_arr: Array = ms_var as Array if ms_var is Array else []
	var idx: int = _pick_frame(rects.size(), ms_arr, time_s, bool(anim.get("loop", true)))
	var src_rect: Rect2 = _to_rect2(rects[idx])
	if src_rect.size.x <= 0.0 or src_rect.size.y <= 0.0:
		return false

	var anchor: Vector2 = _to_vec2(anim.get("anchor", null), default_anchor)
	canvas.draw_set_transform(origin.round(), 0.0, Vector2(-scale.x if flip_x else scale.x, scale.y))
	canvas.draw_texture_rect_region(tex, Rect2(-anchor, src_rect.size), src_rect, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func draw_prop(canvas: CanvasItem, origin: Vector2, prop_key: String, time_s: float, modulate: Color = Color.WHITE, frame_override: int = -1) -> bool:
	if canvas == null or tex == null or not props.has(prop_key):
		return false
	var pinfo_var: Variant = props.get(prop_key, null)
	if not (pinfo_var is Dictionary):
		return false
	var pinfo: Dictionary = pinfo_var as Dictionary
	var rects_var: Variant = pinfo.get("rects", null)
	if not (rects_var is Array) or (rects_var as Array).is_empty():
		return false
	var rects: Array = rects_var as Array

	var idx: int = 0
	if frame_override >= 0:
		idx = clampi(frame_override, 0, rects.size() - 1)
	else:
		var ms_var: Variant = pinfo.get("ms", [])
		var ms_arr: Array = ms_var as Array if ms_var is Array else []
		idx = _pick_frame(rects.size(), ms_arr, time_s, bool(pinfo.get("loop", true)))
	var src_rect: Rect2 = _to_rect2(rects[idx])
	if src_rect.size.x <= 0.0 or src_rect.size.y <= 0.0:
		return false

	var anchor: Vector2 = _to_vec2(pinfo.get("anchor", null), default_anchor)
	canvas.draw_texture_rect_region(tex, Rect2((origin - anchor).round(), src_rect.size), src_rect, modulate)
	return true


func _resolve_anim_key(anim_name: String) -> String:
	if animations.has(anim_name):
		return anim_name
	if animations.has("idle"):
		return "idle"
	if animations.has("routine"):
		return "routine"
	return str(animations.keys()[0])


static func _read_json(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
	var txt: String = FileAccess.get_file_as_string(json_path)
	var parser := JSON.new()
	if parser.parse(txt) == OK and parser.data is Dictionary:
		return parser.data as Dictionary
	return {}


static func _load_texture(png_path: String) -> Texture2D:
	if ResourceLoader.exists(png_path):
		var res: Resource = ResourceLoader.load(png_path)
		if res is Texture2D:
			return res as Texture2D
	if FileAccess.file_exists(png_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(png_path)
		if not bytes.is_empty():
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null


static func _pick_frame(frame_count: int, ms_arr: Array, time_s: float, loop: bool) -> int:
	if frame_count <= 1:
		return 0
	var total_s: float = 0.0
	for i: int in range(frame_count):
		total_s += _frame_sec(ms_arr, i)
	if total_s <= 0.0:
		return 0
	var t: float = maxf(0.0, time_s)
	if loop:
		t = fmod(t, total_s)
	elif t >= total_s:
		return frame_count - 1
	var acc: float = 0.0
	for i: int in range(frame_count):
		acc += _frame_sec(ms_arr, i)
		if t < acc:
			return i
	return frame_count - 1


static func _frame_sec(ms_arr: Array, idx: int) -> float:
	if idx < ms_arr.size():
		var v: float = float(ms_arr[idx]) * 0.001
		if v > 0.0:
			return v
	return 0.12


static func _to_vec2(val: Variant, fallback: Vector2) -> Vector2:
	if val is Array and (val as Array).size() >= 2:
		var arr: Array = val as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


static func _to_rect2(val: Variant) -> Rect2:
	if val is Array and (val as Array).size() >= 4:
		var arr: Array = val as Array
		return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Rect2()
