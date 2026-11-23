class_name LxLuxels
extends RefCounted
## LUXEL luxel-lamp wordmark: each lit pixel of the 3x5 font becomes a 4 px lamp
## on a 5 px night grid, lighting west to east with subtle warm flicker.

const SCALE: int = 5
const BLOCK: int = 4
const FLICKER_STEP: float = 0.14
const INTRO_DELAY: float = 0.35
const INTRO_STEP: float = 0.045
const SNUFF_STEP: float = 0.085

enum State { HIDDEN, UNLIT, EMBER, DIM, LIT, FLASH }

const LOOKS: Dictionary = {
	State.UNLIT: ["dusk", "plum", "night"],
	State.EMBER: ["coral", "apricot", "wine"],
	State.DIM: ["apricot", "gold", "coral"],
	State.LIT: ["gold", "cream", "apricot"],
	State.FLASH: ["cream", "cream", "gold"],
}


## Returns luxel cells for `word` ordered west to east, column top to bottom.
## Each entry: {"p": Vector2 top-left, "c": Vector2 center, "letter": int, "col": int}.
static func cells(word: String, origin_pos: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base: Vector2 = origin_pos.round()
	for i: int in range(word.length()):
		var pts: Array[Vector2i] = LxPixelFont.get_glyph_pixels(word[i])
		for pt: Vector2i in pts:
			var gx: int = i * LxPixelFont.STEP_X + pt.x
			var p: Vector2 = base + Vector2(float(gx * SCALE), float(pt.y * SCALE))
			out.append({
				"p": p,
				"c": p + Vector2(float(BLOCK) * 0.5, float(BLOCK) * 0.5),
				"letter": i,
				"col": gx,
			})
	return out


static func origin(word: String, cx: float, y: float) -> Vector2:
	return Vector2(roundf(cx - float(LxPixelFont.width(word, SCALE)) * 0.5), roundf(y))


static func draw_cell(ci: CanvasItem, pos: Vector2, state: int) -> void:
	if state == State.HIDDEN or not LOOKS.has(state):
		return
	var names: Array = LOOKS[state] as Array
	var body: Color = LxPalette.color(str(names[0]))
	var lit_edge: Color = LxPalette.color(str(names[1]))
	var shade_edge: Color = LxPalette.color(str(names[2]))
	var p: Vector2 = pos.round()
	var b: float = float(BLOCK)
	ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(b + 2.0, b + 2.0)), LxPalette.PAL["night"])
	ci.draw_rect(Rect2(p, Vector2(b, b)), body)
	ci.draw_rect(Rect2(p + Vector2(1.0, b - 1.0), Vector2(b - 1.0, 1.0)), shade_edge)
	ci.draw_rect(Rect2(p + Vector2(b - 1.0, 1.0), Vector2(1.0, b - 1.0)), shade_edge)
	ci.draw_rect(Rect2(p, Vector2(b - 1.0, 1.0)), lit_edge)
	ci.draw_rect(Rect2(p, Vector2(1.0, b - 1.0)), lit_edge)


static func flicker(index: int, elapsed: float) -> int:
	if LxHudFx.flash_reduced():
		return State.LIT
	var step: int = floori(elapsed / FLICKER_STEP)
	var h: int = absi(hash(Vector2i(index, step))) % 1000
	return State.DIM if h < 55 else State.LIT


static func intro_state(col: int, index: int, elapsed: float) -> int:
	var lit_at: float = INTRO_DELAY + float(col) * INTRO_STEP
	var age: float = elapsed - lit_at
	if age < 0.0:
		return State.UNLIT
	if age < 0.09:
		return State.FLASH
	if age < 0.16:
		return State.LIT
	return flicker(index, elapsed)


static func snuff_state(letter: int, total_letters: int, snuff_t: float) -> int:
	var rev_idx: int = maxi(0, total_letters - 1 - letter)
	var age: float = snuff_t - float(rev_idx) * SNUFF_STEP
	if age < 0.0:
		return State.LIT
	if age < 0.08:
		return State.EMBER
	if age < 0.16:
		return State.UNLIT
	return State.HIDDEN


static func intro_duration(word: String) -> float:
	var max_col: int = maxi(0, word.length() * LxPixelFont.STEP_X - 1)
	return INTRO_DELAY + float(max_col) * INTRO_STEP + 0.18


static func draw_wordmark(
	ci: CanvasItem,
	word: String,
	cx: float,
	y: float,
	elapsed: float,
	extinguishing: bool = false,
	snuff_t: float = 0.0
) -> void:
	var list: Array[Dictionary] = cells(word, origin(word, cx, y))
	var total_letters: int = word.length()
	for i: int in range(list.size()):
		var item: Dictionary = list[i]
		var st: int = snuff_state(int(item["letter"]), total_letters, snuff_t) if extinguishing else intro_state(int(item["col"]), i, elapsed)
		draw_cell(ci, item["p"] as Vector2, st)
