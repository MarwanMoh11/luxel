extends Node
## Two clean pictures of the room for the AI brush: the whole room, and a close-up of the boxed area with tile numbers and number tags.

const Style := preload("res://luxel/editor/ed_style.gd")

var ed: Node = null


func take(area: Rect2i, things: Array[Dictionary], dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ts: float = float(ed.room.ts)
	var px: Vector2 = ed.room.px_size()
	var box := Rect2(Vector2(area.position) * ts, Vector2(area.size) * ts)
	var k: float = clampf(1500.0 / maxf(px.x, px.y), 1.0, 4.0)
	await _one(Rect2(Vector2.ZERO, px).grow(8.0), k, box, [], 5, dir + "/room.png")
	var near: Rect2 = box.grow(ts * 2.0).intersection(Rect2(Vector2.ZERO, px).grow(ts))
	var z: float = clampf(1400.0 / maxf(near.size.x, near.size.y), 1.5, 6.0)
	await _one(near, z, box, things, 1, dir + "/area.png")


func _one(world: Rect2, zoom: float, box: Rect2, things: Array, every: int, path: String) -> void:
	var v := SubViewport.new()
	v.size = Vector2i((world.size * zoom).ceil())
	v.world_2d = get_viewport().find_world_2d()
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var cam := Camera2D.new()
	cam.position = world.get_center()
	cam.zoom = Vector2(zoom, zoom)
	v.add_child(cam)
	var layer := CanvasLayer.new()
	var marks := Marks.new()
	marks.world = world
	marks.zoom = zoom
	marks.box = box
	marks.things = things
	marks.every = every
	marks.ts = float(ed.room.ts)
	marks.room = ed.room.px_size()
	layer.add_child(marks)
	v.add_child(layer)
	add_child(v)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = v.get_texture().get_image()
	if img != null:
		img.save_png(path)
	v.queue_free()


class Marks extends Node2D:
	var world: Rect2
	var zoom: float = 1.0
	var box: Rect2
	var things: Array = []
	var every: int = 1
	var ts: float = 16.0
	var room: Vector2

	func _s(p: Vector2) -> Vector2: return (p - world.position) * zoom

	func _num(p: Vector2, t: String, bg: Color, fg: Color, size_px: int = 13) -> void:
		var f: Font = ThemeDB.fallback_font
		var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_rect(Rect2(p - Vector2(w * 0.5 + 3.0, size_px * 0.5 + 3.0), Vector2(w + 6.0, size_px + 6.0)), bg)
		draw_string(f, p + Vector2(-w * 0.5, size_px * 0.5 - 1.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, fg)

	func _draw() -> void:
		var line := Color(1, 1, 1, 0.16 if every == 1 else 0.0)
		var x0: int = maxi(0, floori(world.position.x / ts))
		var y0: int = maxi(0, floori(world.position.y / ts))
		var x1: int = mini(int(room.x / ts), ceili(world.end.x / ts))
		var y1: int = mini(int(room.y / ts), ceili(world.end.y / ts))
		for x: int in range(x0, x1 + 1):
			draw_line(_s(Vector2(x * ts, y0 * ts)), _s(Vector2(x * ts, y1 * ts)), line, 1.0)
		for y: int in range(y0, y1 + 1):
			draw_line(_s(Vector2(x0 * ts, y * ts)), _s(Vector2(x1 * ts, y * ts)), line, 1.0)
		draw_rect(Rect2(_s(box.position), box.size * zoom), Color("ffd98c"), false, 3.0)
		for t: Dictionary in things:
			if int(t["mark"]) > 0:
				var r: Rect2 = t["rect"] as Rect2
				_num(_s(Vector2(r.position.x, r.position.y)) + Vector2(6, 4), str(t["mark"]), Color("a0466a"), Color.WHITE)
		for x: int in range(x0, x1):
			if x % every == 0:
				_num(Vector2(_s(Vector2(x * ts + ts * 0.5, 0)).x, 10.0), str(x), Color("0d0b1e"), Color("ffd98c"), 12)
		for y: int in range(y0, y1):
			if y % every == 0:
				_num(Vector2(12.0, _s(Vector2(0, y * ts + ts * 0.5)).y), str(y), Color("0d0b1e"), Color("ffd98c"), 12)
