class_name LxSceneryProp
extends Node2D
## Renders hand-crafted Last Light scenic props and landmarks from a region's "scenery" array.

const PAL: Dictionary = LxInteractable.PAL

var sheet_name: String = ""
var prop_key: String = ""
var layer_name: String = "sort"
var flip_x: bool = false
var cast_shadow: bool = true
var animated: bool = false

var _sheet: LxSpriteSheet = null
var _clock: float = 0.0
var _valid: bool = false
var _frame_size: Vector2 = Vector2.ZERO
var _shadow_poly: PackedVector2Array = PackedVector2Array()
var _ms_arr: Array = []
var _frame_count: int = 0
var _loop: bool = true
var _last_frame: int = -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(spec: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet_name = str(spec.get("sheet", "")).strip_edges()
	prop_key = str(spec.get("prop", "")).strip_edges()
	layer_name = str(spec.get("layer", "sort")).strip_edges().to_lower()
	flip_x = bool(spec.get("flip_x", false))
	cast_shadow = bool(spec.get("shadow", true))
	_clock = maxf(0.0, float(spec.get("phase", 0.0)))
	position = LxMapFormat.to_vec2(spec.get("pos", Vector2.ZERO)).round()
	if not prop_key.is_empty():
		name = prop_key

	_sheet = null
	_valid = false
	animated = false
	_frame_size = Vector2.ZERO
	_shadow_poly = PackedVector2Array()

	var path: String = ""
	if not sheet_name.is_empty() and not prop_key.is_empty():
		path = sheet_name if sheet_name.begins_with("res://") else (
			"res://luxel/art/props/%s" % sheet_name if sheet_name.ends_with(".json")
			else "res://luxel/art/props/%s.json" % sheet_name
		)
		_sheet = LxSpriteSheet.load_sheet(path)
	if _sheet != null and _sheet.props.has(prop_key):
		var pinfo_var: Variant = _sheet.props.get(prop_key, null)
		var rects_var: Variant = (pinfo_var as Dictionary).get("rects", null) if pinfo_var is Dictionary else null
		if rects_var is Array and not (rects_var as Array).is_empty():
			var pinfo: Dictionary = pinfo_var as Dictionary
			var rects: Array = rects_var as Array
			_valid = true
			_frame_count = rects.size()
			animated = _frame_count > 1
			var ms_v: Variant = pinfo.get("ms", [])
			_ms_arr = ms_v as Array if ms_v is Array else []
			_loop = bool(pinfo.get("loop", true))
			_last_frame = LxSpriteSheet._pick_frame(_frame_count, _ms_arr, _clock, _loop) if animated else 0
			var first: Variant = rects[0]
			if first is Array and (first as Array).size() >= 4:
				_frame_size = Vector2(float((first as Array)[2]), float((first as Array)[3]))
			if layer_name == "sort" and cast_shadow:
				_shadow_poly = _build_shadow_ellipse(_frame_size)
	queue_redraw()


func is_animated() -> bool:
	return animated


func tick(dt: float) -> void:
	if not animated:
		return
	_clock += dt
	var f: int = LxSpriteSheet._pick_frame(_frame_count, _ms_arr, _clock, _loop)
	if f != _last_frame:
		_last_frame = f
		queue_redraw()


func _draw() -> void:
	if not _valid or _sheet == null:
		return
	if _shadow_poly.size() >= 3:
		draw_colored_polygon(_shadow_poly, Color(PAL["void"] as Color, 0.32))
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	_sheet.draw_prop(self, Vector2.ZERO, prop_key, _clock)
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _build_shadow_ellipse(frame_sz: Vector2) -> PackedVector2Array:
	var rx: float = clampf(frame_sz.x * 0.34, 4.0, 26.0)
	var ry: float = clampf(frame_sz.x * 0.12, 2.0, 8.0)
	var pts := PackedVector2Array()
	pts.resize(12)
	for i: int in range(12):
		var a: float = (TAU * float(i)) / 12.0
		var sx: float = cos(a) * rx + sin(a) * ry * 0.35 + 2.0
		var sy: float = sin(a) * ry + 1.0
		pts[i] = Vector2(roundf(sx), roundf(sy))
	return pts


static func spawn_from_specs(specs: Array, ground_root: Node2D, sort_root: Node2D, over_root: Node2D) -> Array[LxSceneryProp]:
	var out: Array[LxSceneryProp] = []
	for raw: Variant in specs:
		if not (raw is Dictionary):
			continue
		var prop := LxSceneryProp.new()
		prop.setup(raw as Dictionary)
		var target: Node2D = ground_root if prop.layer_name == "ground" else (over_root if (prop.layer_name == "overhead" or prop.layer_name == "over") else sort_root)
		if target == null:
			target = sort_root if sort_root != null else (ground_root if ground_root != null else over_root)
		if target != null:
			target.add_child(prop)
		out.append(prop)
	return out
