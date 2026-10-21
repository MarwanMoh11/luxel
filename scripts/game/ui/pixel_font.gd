class_name PixelFont
extends RefCounted
## 3x5 bitmap font drawn from art/ui/font.png (white glyphs, tinted when drawn).
## Glyph order must match FONT_CHARS in docs/art_concepts/make_concepts.py.

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+="
const TEX := preload("res://art/ui/font.png")
const W := 3
const H := 5
const OUTLINE: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]


static func width(text: String, scale: int = 1) -> int:
	return maxi(text.length() * (W + 1) - 1, 0) * scale


## Draws `text` with its top-left at `pos`, with a dark outline so it reads on any background.
static func draw(ci: CanvasItem, text: String, pos: Vector2, color: Color, outline: Color, scale: int = 1) -> void:
	for offset in OUTLINE:
		_draw_glyphs(ci, text, pos + offset * scale, outline, scale)
	_draw_glyphs(ci, text, pos, color, scale)


static func draw_centered(ci: CanvasItem, text: String, center_x: float, y: float, color: Color, outline: Color, scale: int = 1) -> void:
	draw(ci, text, Vector2(roundf(center_x - width(text, scale) / 2.0), y), color, outline, scale)


static func _draw_glyphs(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale: int) -> void:
	for i in text.length():
		var index := CHARS.find(text[i])
		if index < 0:
			continue
		var dest := Rect2(pos + Vector2(i * (W + 1) * scale, 0), Vector2(W, H) * scale)
		ci.draw_texture_rect_region(TEX, dest, Rect2(index * W, 0, W, H), color)
