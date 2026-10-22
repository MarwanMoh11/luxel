class_name PixelFont
extends RefCounted
## 3x5 bitmap font drawn from art/ui/font.png (white glyphs, tinted when drawn).
## Glyph order must match FONT_CHARS in docs/art_concepts/make_concepts.py.

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+="
const TEX := preload("res://art/ui/font.png")
const OUTLINE_TEX := preload("res://art/ui/font_outline.png") ## per glyph, its W x H shifted by OUTLINE: CELL_W x CELL_H
const W := 3
const H := 5
const CELL_W := W + 2
const CELL_H := H + 2
const OUTLINE: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]

static var _lut := _make_lut() # character code -> its CHARS index (-1: none)


static func width(text: String, scale: int = 1) -> int:
	return maxi(text.length() * (W + 1) - 1, 0) * scale


## Draws `text` with its top-left at `pos`, with a dark outline so it reads on any background. An opaque outline is
## baked (font_outline.png: each cell is the glyph shifted by every OUTLINE offset): one draw per glyph for it, one
## for the fill. A see-through outline would show where the five passes overlap, so it takes the five passes.
static func draw(ci: CanvasItem, text: String, pos: Vector2, color: Color, outline: Color, scale: int = 1) -> void:
	if outline.a < 1.0:
		for offset in OUTLINE:
			_draw_glyphs(ci, text, pos + offset * scale, outline, scale)
		_draw_glyphs(ci, text, pos, color, scale)
		return
	var cell := Vector2(CELL_W, CELL_H) * scale
	var at := pos - Vector2(scale, scale)
	var step := (W + 1) * scale
	for i in text.length():
		var code := text.unicode_at(i)
		var index := _lut[code] if code < 128 else -1
		if index >= 0:
			ci.draw_texture_rect_region(OUTLINE_TEX, Rect2(at + Vector2(i * step, 0), cell),
					Rect2(index * CELL_W, 0, CELL_W, CELL_H), outline)
	_draw_glyphs(ci, text, pos, color, scale)


static func draw_centered(ci: CanvasItem, text: String, center_x: float, y: float, color: Color, outline: Color, scale: int = 1) -> void:
	draw(ci, text, Vector2(roundf(center_x - width(text, scale) / 2.0), y), color, outline, scale)


static func _draw_glyphs(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale: int) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		var index := _lut[code] if code < 128 else -1
		if index < 0:
			continue
		var dest := Rect2(pos + Vector2(i * (W + 1) * scale, 0), Vector2(W, H) * scale)
		ci.draw_texture_rect_region(TEX, dest, Rect2(index * W, 0, W, H), color)


static func _make_lut() -> PackedInt32Array:
	var lut := PackedInt32Array()
	lut.resize(128)
	lut.fill(-1)
	for i in CHARS.length():
		lut[CHARS.unicode_at(i)] = i
	return lut

