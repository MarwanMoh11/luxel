extends Node
## Pictures of everything in the palette, taken from the live game objects one per frame.
## Each entry is {tex, rect}: rect is where the picture sits around the object's position (world px).

signal ready_thumb(key: String)

const SIZE: int = 112
const ORIGIN := Vector2(56.0, 76.0)

var catalog: RefCounted = null
var _cache: Dictionary = {}
var _queue: Array[Dictionary] = []
var _view: SubViewport = null
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = SubViewport.new()
	_view.size = Vector2i(SIZE, SIZE)
	_view.transparent_bg = true
	_view.disable_3d = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_view)


static func key_of(e: Dictionary) -> String:
	return "%s/%s/%s" % [e.get("type", ""), e.get("sheet", e.get("variant", "")), e.get("kind", "")]


func get_thumb(e: Dictionary) -> Dictionary:
	var k: String = key_of(e)
	if _cache.has(k):
		return _cache[k] as Dictionary
	if str(e.get("type", "")) == "scenery":
		var d: Dictionary = _scenery(e)
		_cache[k] = d
		return d
	_cache[k] = {}
	_queue.append(e)
	return {}


func get_thumb_by_key(k: String) -> Dictionary:
	return _cache.get(k, {}) as Dictionary


func forget_tiles() -> void:
	for k: String in _cache.keys():
		if k.begins_with("tile/"):
			_cache.erase(k)


func _scenery(e: Dictionary) -> Dictionary:
	var sh: LxSpriteSheet = LxSpriteSheet.load_sheet("res://luxel/art/props/%s.json" % str(e.get("sheet", "")))
	if sh == null or not (sh.props.get(str(e.get("kind", ""))) is Dictionary):
		return {}
	var p: Dictionary = sh.props[str(e["kind"])] as Dictionary
	var rects: Variant = p.get("rects", [])
	if not (rects is Array) or (rects as Array).is_empty():
		return {}
	var src: Rect2 = LxSpriteSheet._to_rect2((rects as Array)[0])
	var at := AtlasTexture.new()
	at.atlas = sh.tex
	at.region = src
	var anchor: Vector2 = LxSpriteSheet._to_vec2(p.get("anchor", null), sh.default_anchor)
	return {"tex": at, "rect": Rect2(-anchor, src.size)}


func _process(_dt: float) -> void:
	if _busy or _queue.is_empty() or DisplayServer.get_name() == "headless":
		return
	_busy = true
	_shoot(_queue.pop_front() as Dictionary)


func _shoot(e: Dictionary) -> void:
	var node: Node2D = _make(e)
	if node != null:
		_view.add_child(node)
		node.position = ORIGIN
		node.visible = true
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var img: Image = _view.get_texture().get_image()
		if is_instance_valid(node):
			_view.remove_child(node)
			node.queue_free()
		var used: Rect2i = img.get_used_rect() if img != null else Rect2i()
		if used.size.x > 1 and used.size.y > 1:
			var tex: ImageTexture = ImageTexture.create_from_image(img.get_region(used))
			_cache[key_of(e)] = {"tex": tex, "rect": Rect2(Vector2(used.position) - ORIGIN, Vector2(used.size))}
			ready_thumb.emit(key_of(e))
	_busy = false


func _make(e: Dictionary) -> Node2D:
	var kind: String = str(e.get("kind", ""))
	match str(e.get("type", "")):
		"interactables":
			var spec: Dictionary = {"id": "", "kind": kind, "pos": [ORIGIN.x, ORIGIN.y], "props": catalog.call("entry_props", e)}
			var it: LxInteractable = LxInteractableFactory.create(spec)
			if it == null:
				return null
			var w: LxRegionLoader = Lx.world as LxRegionLoader
			it.region = w
			it.island_id = w.current_island_id if w != null else 1
			it.region_id = "_thumb"
			it.setup(spec)
			return it
		"enemies":
			var dir: LxAttackDirector = LxAttackDirector.new()
			return LxEnemyFactory.create(kind, {"id": "", "kind": kind, "pos": [ORIGIN.x, ORIGIN.y], "leash": 60}, dir, Lx.world)
		"tile":
			var t := TilePic.new()
			t.tile = kind
			return t
		"decor":
			var dc := DecorPic.new()
			dc.kind = kind
			return dc
	return null


class TilePic extends Node2D:
	const Greybox := preload("res://luxel/world/greybox_draw.gd")
	var tile: String = "ground"

	func _draw() -> void:
		var at: Rect2 = Rect2(-16, -16, 32, 32)
		var src: Dictionary = {}
		var w: Node = Lx.world
		if w != null and is_instance_valid(w) and w.has_meta("ed_tile_src"):
			src = w.get_meta("ed_tile_src") as Dictionary
		if src.has(tile):
			draw_texture_rect_region(src["tex"] as Texture2D, at, src[tile] as Rect2)
			return
		draw_set_transform(Vector2(-16, -16), 0.0, Vector2(2, 2))
		Greybox.draw_tile(self, 0, 0, 16.0, tile)
		var mark: Color = LxInteractable.PAL["cream"]
		match tile:
			"carpet": draw_rect(Rect2(0, 0, 16, 16), LxInteractable.PAL["wine"]); draw_rect(Rect2(2, 2, 12, 12), LxInteractable.PAL["gold"], false, 1.0)
			"stairs":
				draw_rect(Rect2(0, 0, 16, 16), LxInteractable.PAL["mauve"])
				for i: int in range(4): draw_rect(Rect2(0, i * 4, 16, 1), LxInteractable.PAL["night"])
			"grate":
				draw_rect(Rect2(0, 0, 16, 16), LxInteractable.PAL["void"])
				for i: int in range(4): draw_rect(Rect2(1 + i * 4, 0, 2, 16), LxInteractable.PAL["mauve"])
			"rail": draw_rect(Rect2(0, 0, 16, 16), LxInteractable.PAL["dusk"]); draw_rect(Rect2(0, 5, 16, 2), mark); draw_rect(Rect2(3, 5, 2, 8), mark); draw_rect(Rect2(11, 5, 2, 8), mark)
			"foliage": draw_rect(Rect2(0, 0, 16, 16), LxInteractable.PAL["pine"]); draw_circle(Vector2(5, 8), 4, LxInteractable.PAL["jade"]); draw_circle(Vector2(11, 8), 4, LxInteractable.PAL["teal"])
		draw_set_transform(Vector2.ZERO)


class DecorPic extends Node2D:
	var kind: String = ""

	func _draw() -> void:
		var g: Color = LxInteractable.PAL["gold"]
		var m: Color = LxInteractable.PAL["mauve"]
		match kind:
			"circle": draw_arc(Vector2.ZERO, 18, 0, TAU, 28, g, 2.0); draw_arc(Vector2.ZERO, 12, 0, TAU, 24, m, 1.0)
			"compass":
				draw_arc(Vector2.ZERO, 18, 0, TAU, 28, m, 2.0)
				for i: int in range(4): draw_line(Vector2.ZERO, Vector2.from_angle(TAU * i / 4.0) * 17.0, g, 2.0)
			"inlay": draw_rect(Rect2(-20, -15, 40, 30), m, false, 2.0); draw_rect(Rect2(-15, -10, 30, 20), g, false, 1.0)
			"rug": draw_rect(Rect2(-20, -12, 40, 24), LxInteractable.PAL["wine"]); draw_rect(Rect2(-17, -9, 34, 18), g, false, 1.0)
			"light_shaft": draw_colored_polygon(PackedVector2Array([Vector2(-6, -22), Vector2(8, -22), Vector2(20, 20), Vector2(-14, 20)]), Color(g, 0.6))
			"cracks":
				draw_polyline(PackedVector2Array([Vector2(-16, -8), Vector2(-4, 0), Vector2(2, -6), Vector2(16, 8)]), m, 2.0)
				draw_line(Vector2(-4, 0), Vector2(-8, 14), m, 2.0)
			"stain": draw_circle(Vector2(-4, 0), 12, LxInteractable.PAL["pine"]); draw_circle(Vector2(8, 4), 8, LxInteractable.PAL["teal"])
			"grate":
				for i: int in range(5): draw_rect(Rect2(-18 + i * 8, -14, 4, 28), m)
			"window_strip":
				for i: int in range(3): draw_rect(Rect2(-20 + i * 14, -14, 10, 24), LxInteractable.PAL["sky"])
			"mural": draw_rect(Rect2(-18, -18, 36, 36), LxInteractable.PAL["deep"]); draw_circle(Vector2(0, -2), 9, LxInteractable.PAL["ice"])
