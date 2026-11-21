class_name LxPixelFont
extends RefCounted
## 3x5 bitmap pixel font renderer for Luxel 1.0.
## Loads res://luxel/art/ui/font.png or res://art/ui/font.png when available,
## and falls back to crisp procedural 3x5 glyphs built in memory so it always renders.

const CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+="
const W: int = 3
const H: int = 5
const STEP_X: int = 4
const CELL_W: int = 5
const CELL_H: int = 7

const OUTLINE_OFFSETS: Array[Vector2] = [
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
	Vector2(1.0, 1.0),
]

const GLYPH_BITS: Dictionary = {
	"A": ".#.#.#####.##.#", "B": "##.#.###.#.###.", "C": ".###..#..#...##",
	"D": "##.#.##.##.###.", "E": "####..##.#..###", "F": "####..##.#..#..",
	"G": ".###..#.###..##", "H": "#.##.#####.##.#", "I": "###.#..#..#.###",
	"J": "..#..#..##.#.#.", "K": "#.##.###.#.##.#", "L": "#..#..#..#..###",
	"M": "#.########.##.#", "N": "##.#.##.##.##.#", "O": ".#.#.##.##.#.#.",
	"P": "##.#.###.#..#..", "Q": ".#.#.##.###..##", "R": "##.#.###.#.##.#",
	"S": ".###...#...###.", "T": "###.#..#..#..#.", "U": "#.##.##.##.####",
	"V": "#.##.##.##.#.#.", "W": "#.##.########.#", "X": "#.##.#.#.#.##.#",
	"Y": "#.##.#.#..#..#.", "Z": "###..#.#.#..###",
	"0": "####.##.##.####", "1": ".#.###.#..#.###", "2": "##...#.#.#..###",
	"3": "##...#.#...###.", "4": "#.##.####..#..#", "5": "####..##...###.",
	"6": ".###..####.####", "7": "###..#.#..#..#.", "8": "####.#####.####",
	"9": "####.####..###.",
	"!": ".#..#..#.....#.", "-": "......###......", ":": "....#.....#....",
	"x": "......#.#.#.#.#", "/": "..#..#.#.#..#..", ".": ".............#.",
	"+": "....#.###.#....", "=": "...###...###...", "%": "#.#..#.#.#..#.#",
}

static var _lut: PackedInt32Array = _make_lut()
static var _tex: Texture2D = null
static var _outline_tex: Texture2D = null
static var _font_img: Image = null
static var _tried_load: bool = false


static func width(text: String, scale: int = 1) -> int:
	var sc: int = clampi(scale, 1, 5)
	return maxi(text.length() * STEP_X - 1, 0) * sc


static func height(scale: int = 1) -> int:
	return H * clampi(scale, 1, 5)


static func draw(
	ci: CanvasItem,
	text: String,
	pos: Vector2,
	color: Color,
	scale: int = 1,
	outline: Color = LxPalette.PAL["night"],
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	if text.is_empty() or color.a <= 0.0:
		return
	var sc: int = clampi(scale, 1, 5)
	var draw_pos: Vector2 = pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		draw_pos.x = roundf(pos.x - float(width(text, sc)) * 0.5)
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		draw_pos.x = roundf(pos.x - float(width(text, sc)))
	else:
		draw_pos.x = roundf(pos.x)
	draw_pos.y = roundf(pos.y)

	_ensure_textures()
	var step: float = float(STEP_X * sc)
	if _tex != null and _outline_tex != null:
		var cell_sz: Vector2 = Vector2(float(CELL_W * sc), float(CELL_H * sc))
		var out_origin: Vector2 = draw_pos - Vector2(float(sc), float(sc))
		var fill_sz: Vector2 = Vector2(float(W * sc), float(H * sc))
		for i: int in range(text.length()):
			var ch: String = text[i]
			if ch == " ":
				continue
			if ch == "%":
				_draw_procedural_char(ci, "%", draw_pos + Vector2(float(i) * step, 0.0), color, outline, sc)
				continue
			var code: int = text.unicode_at(i)
			var idx: int = _lut[code] if code < 128 else -1
			if idx < 0:
				continue
			ci.draw_texture_rect_region(
				_outline_tex,
				Rect2(out_origin + Vector2(float(i) * step, 0.0), cell_sz),
				Rect2(float(idx * CELL_W), 0.0, float(CELL_W), float(CELL_H)),
				outline
			)
		for i: int in range(text.length()):
			var ch: String = text[i]
			if ch == " " or ch == "%":
				continue
			var code: int = text.unicode_at(i)
			var idx: int = _lut[code] if code < 128 else -1
			if idx < 0:
				continue
			ci.draw_texture_rect_region(
				_tex,
				Rect2(draw_pos + Vector2(float(i) * step, 0.0), fill_sz),
				Rect2(float(idx * W), 0.0, float(W), float(H)),
				color
			)
		return

	# Procedural fallback when textures are unavailable.
	for i: int in range(text.length()):
		var ch: String = text[i]
		if ch == " ":
			continue
		_draw_procedural_char(ci, ch, draw_pos + Vector2(float(i) * step, 0.0), color, outline, sc)


static func draw_left(
	ci: CanvasItem,
	text: String,
	pos: Vector2,
	color: Color,
	scale: int = 1,
	outline: Color = LxPalette.PAL["night"]
) -> void:
	draw(ci, text, pos, color, scale, outline, HORIZONTAL_ALIGNMENT_LEFT)


static func draw_centered(
	ci: CanvasItem,
	text: String,
	center_x: float,
	y: float,
	color: Color,
	scale: int = 1,
	outline: Color = LxPalette.PAL["night"]
) -> void:
	draw(ci, text, Vector2(center_x, y), color, scale, outline, HORIZONTAL_ALIGNMENT_CENTER)


static func draw_right(
	ci: CanvasItem,
	text: String,
	right_x: float,
	y: float,
	color: Color,
	scale: int = 1,
	outline: Color = LxPalette.PAL["night"]
) -> void:
	draw(ci, text, Vector2(right_x, y), color, scale, outline, HORIZONTAL_ALIGNMENT_RIGHT)


static func fade_color(progress: float, colour_name: String = "cream") -> Color:
	return LxPalette.fade_step(progress, colour_name)


static func draw_faded(
	ci: CanvasItem,
	text: String,
	pos: Vector2,
	progress: float,
	colour_name: String = "cream",
	scale: int = 1,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var c: Color = fade_color(progress, colour_name)
	if c.a <= 0.0:
		return
	draw(ci, text, pos, c, scale, LxPalette.PAL["night"], align)


static func draw_panel(
	ci: CanvasItem,
	rect: Rect2,
	fill: String = "dusk",
	border: String = "mauve",
	outer: String = "night"
) -> void:
	var r: Rect2 = Rect2(rect.position.round(), rect.size.round())
	ci.draw_rect(r, LxPalette.color(outer))
	if r.size.x > 2.0 and r.size.y > 2.0:
		ci.draw_rect(r.grow(-1.0), LxPalette.color(border))
	if r.size.x > 4.0 and r.size.y > 4.0:
		ci.draw_rect(r.grow(-2.0), LxPalette.color(fill))


static func get_glyph_pixels(ch: String) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	_ensure_textures()
	var idx: int = CHARS.find(ch)
	if _font_img != null and idx >= 0:
		for x: int in range(W):
			for y: int in range(H):
				if _font_img.get_pixel(idx * W + x, y).a > 0.5:
					pts.append(Vector2i(x, y))
		return pts
	var bits: String = str(GLYPH_BITS.get(ch, ""))
	if bits.length() != W * H:
		return pts
	for x: int in range(W):
		for y: int in range(H):
			if bits[y * W + x] == "#":
				pts.append(Vector2i(x, y))
	return pts


static func _draw_procedural_char(
	ci: CanvasItem,
	ch: String,
	at: Vector2,
	color: Color,
	outline: Color,
	sc: int
) -> void:
	var bits: String = str(GLYPH_BITS.get(ch, ""))
	if bits.length() != W * H:
		return
	var px_sz: Vector2 = Vector2(float(sc), float(sc))
	for off: Vector2 in OUTLINE_OFFSETS:
		var o: Vector2 = off * float(sc)
		for y: int in range(H):
			for x: int in range(W):
				if bits[y * W + x] == "#":
					ci.draw_rect(Rect2(at + Vector2(float(x * sc), float(y * sc)) + o, px_sz), outline)
	for y: int in range(H):
		for x: int in range(W):
			if bits[y * W + x] == "#":
				ci.draw_rect(Rect2(at + Vector2(float(x * sc), float(y * sc)), px_sz), color)


static func _ensure_textures() -> void:
	if _tried_load:
		return
	_tried_load = true
	var candidates: Array[Array] = [
		["res://luxel/art/ui/font.png", "res://luxel/art/ui/font_outline.png"],
		["res://art/ui/font.png", "res://art/ui/font_outline.png"],
	]
	for pair: Array in candidates:
		var fp: String = str(pair[0])
		var op: String = str(pair[1])
		if ResourceLoader.exists(fp):
			var res: Resource = ResourceLoader.load(fp)
			if res is Texture2D:
				_tex = res as Texture2D
				_font_img = _tex.get_image()
				if ResourceLoader.exists(op):
					var ores: Resource = ResourceLoader.load(op)
					if ores is Texture2D:
						_outline_tex = ores as Texture2D
				if _outline_tex == null and _font_img != null:
					_outline_tex = _bake_outline_texture(_font_img)
				return
	# Build crisp procedural textures in memory when PNG assets are not imported yet.
	_font_img = _build_procedural_image()
	_tex = ImageTexture.create_from_image(_font_img)
	_outline_tex = _bake_outline_texture(_font_img)


static func _build_procedural_image() -> Image:
	var img: Image = Image.create(CHARS.length() * W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i: int in range(CHARS.length()):
		var bits: String = str(GLYPH_BITS.get(CHARS[i], ""))
		if bits.length() != W * H:
			continue
		for y: int in range(H):
			for x: int in range(W):
				if bits[y * W + x] == "#":
					img.set_pixel(i * W + x, y, Color.WHITE)
	return img


static func _bake_outline_texture(src: Image) -> Texture2D:
	var count: int = CHARS.length()
	var out_img: Image = Image.create(count * CELL_W, CELL_H, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i: int in range(count):
		for y: int in range(H):
			for x: int in range(W):
				if src.get_pixel(i * W + x, y).a > 0.5:
					for off: Vector2 in OUTLINE_OFFSETS:
						var ox: int = 1 + x + int(off.x)
						var oy: int = 1 + y + int(off.y)
						if ox >= 0 and ox < CELL_W and oy >= 0 and oy < CELL_H:
							out_img.set_pixel(i * CELL_W + ox, oy, Color.WHITE)
	return ImageTexture.create_from_image(out_img)


static func _make_lut() -> PackedInt32Array:
	var lut := PackedInt32Array()
	lut.resize(128)
	lut.fill(-1)
	for i: int in range(CHARS.length()):
		lut[CHARS.unicode_at(i)] = i
	return lut
