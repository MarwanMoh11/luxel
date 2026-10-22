extends Node
## One-shot shader warm-up at boot, behind the web shell's loader. WebGL compiles a canvas shader the first time it is
## drawn, mid-game: the first GRAPHICS sale (screen_fx), the finale's edge and blast (finale_fx), the first Gloam,
## the run's shadows (shade) and the first arc. This draws every custom shader and each kind of canvas draw call
## once into an 8x8 SubViewport that nothing shows, over the game's first frames, then frees itself. The main
## viewport's frames are untouched.

const SCREEN_FX := preload("res://scripts/game/fx/screen_fx.gdshader")
const FINALE_FX := preload("res://scripts/game/fx/finale_fx.gdshader")
const GLOAM := preload("res://scripts/cast/enemies/gloam.gdshader")
const SHADE := preload("res://scripts/cast/shade.gdshader")
const TITLE_LIGHT := preload("res://scripts/game/screens/title_light.gdshader")
const SIZE := Vector2i(8, 8)
const FRAMES := 3 ## drawn frames the viewport lives (it renders once, on the next frame)

var _frames := 0
var _tex: ImageTexture


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free() # nothing is drawn, so nothing compiles
		return
	_tex = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	var port := SubViewport.new()
	port.size = SIZE
	port.transparent_bg = true
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(port)
	for shader: Shader in [SCREEN_FX, FINALE_FX, GLOAM, SHADE, TITLE_LIGHT]:
		var m := ShaderMaterial.new()
		m.shader = shader
		var rect := ColorRect.new()
		rect.size = Vector2(SIZE)
		rect.material = m
		port.add_child(rect)
		var quad := Node2D.new() # a textured quad, as the sprites draw
		quad.material = m
		quad.draw.connect(_draw_quad.bind(quad))
		port.add_child(quad)
	var plain := Node2D.new() # the default shader's draw kinds
	plain.draw.connect(_draw_kinds.bind(plain))
	port.add_child(plain)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()


func _draw_quad(ci: CanvasItem) -> void:
	ci.draw_texture_rect_region(_tex, Rect2(0, 0, 4, 4), Rect2(0, 0, 2, 2), Color(1, 1, 1, 0.5))


func _draw_kinds(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 4, 4), Color.WHITE)
	ci.draw_texture_rect_region(_tex, Rect2(0, 0, 4, 4), Rect2(0, 0, 2, 2), Color.WHITE)
	ci.draw_arc(Vector2(4, 4), 3.0, 0.0, TAU, 16, Color.WHITE, 2.0)
	ci.draw_arc(Vector2(4, 4), 2.0, 0.0, TAU, 16, Color.WHITE, 1.0)
	ci.draw_line(Vector2(0, 0), Vector2(7, 7), Color.WHITE)
	ci.draw_line(Vector2(0, 7), Vector2(7, 0), Color.WHITE, 2.0)
	ci.draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(4, 2), Vector2(7, 7)]), Color.WHITE, 2.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(7, 0), Vector2(0, 7)]), Color.WHITE)
	ci.draw_primitive(PackedVector2Array([Vector2(0, 0), Vector2(7, 0), Vector2(0, 7)]), PackedColorArray([Color.WHITE]),
			PackedVector2Array())
