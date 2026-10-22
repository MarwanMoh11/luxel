extends RefCounted
## LUXEL in pixels of light (STORY.md 2): every lit pixel of the 3x5 font becomes one luxel, a 4 px lamp on a
## 5 px night grid, lit on its top and left like everything under the west sun. The title screen lights them one
## by one and the dark eats them; the ending flies them out of the lantern.

const PAL := preload("res://scripts/game/ui/palette.gd").PAL
const NIGHT: Color = PAL["night"]
const SCALE := 5 ## one font pixel = one luxel cell
const BLOCK := 4 ## the lamp inside its cell (the fifth pixel is the night grid)

enum { HIDDEN, UNLIT, EMBER, DIM, LIT, FLASH }
## Per state: body, lit edges (top, left), shaded edges (bottom, right).
const LOOKS := {
	UNLIT: ["dusk", "plum", "night"], EMBER: ["coral", "apricot", "wine"], DIM: ["apricot", "gold", "coral"],
	LIT: ["gold", "cream", "apricot"], FLASH: ["cream", "cream", "gold"],
}

const FLICKER_STEP := 0.14 ## s a lit luxel's flicker holds

static var _font: Image
static var _looks: Dictionary = {} ## LOOKS as colours: state -> [body, lit edge, shaded edge]


## The luxels of `text` with its top-left at `origin`: [{"p": top-left, "c": centre, "letter": index}], west to
## east, each font column top to bottom.
static func cells(text: String, origin: Vector2) -> Array[Dictionary]:
	if _font == null:
		_font = PixelFont.TEX.get_image()
	var out: Array[Dictionary] = []
	for i in text.length():
		var glyph := PixelFont.CHARS.find(text[i])
		if glyph < 0:
			continue
		for x in PixelFont.W:
			for y in PixelFont.H:
				if _font.get_pixel(glyph * PixelFont.W + x, y).a > 0.5:
					var p := origin.round() + Vector2((i * (PixelFont.W + 1) + x) * SCALE, y * SCALE)
					out.append({"p": p, "c": p + Vector2(BLOCK, BLOCK) / 2.0, "letter": i})
	return out


## The top-left that centres `text` on `cx`.
static func origin(text: String, cx: float, y: float) -> Vector2:
	return Vector2(roundf(cx - PixelFont.width(text, SCALE) / 2.0), y)


## One luxel in `state` with its top-left at `p`.
static func draw(ci: CanvasItem, p: Vector2, state: int) -> void:
	if state == HIDDEN:
		return
	if _looks.is_empty():
		for s: int in LOOKS:
			_looks[s] = [PAL[LOOKS[s][0]], PAL[LOOKS[s][1]], PAL[LOOKS[s][2]]]
	p = p.round()
	var look: Array = _looks[state]
	ci.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE * (BLOCK + 2)), NIGHT)
	ci.draw_rect(Rect2(p, Vector2.ONE * BLOCK), look[0])
	ci.draw_rect(Rect2(p + Vector2(1, BLOCK - 1), Vector2(BLOCK - 1, 1)), look[2])
	ci.draw_rect(Rect2(p + Vector2(BLOCK - 1, 1), Vector2(1, BLOCK - 1)), look[2])
	ci.draw_rect(Rect2(p, Vector2(BLOCK - 1, 1)), look[1])
	ci.draw_rect(Rect2(p, Vector2(1, BLOCK - 1)), look[1])


## A lit luxel's flicker: now and then one dips to DIM for a beat, never two neighbours in step.
static func flicker(index: int, t: float) -> int:
	var step := floori(t / FLICKER_STEP)
	var h := absi(hash(Vector2i(index, step))) % 1000
	return DIM if h < 55 else LIT
