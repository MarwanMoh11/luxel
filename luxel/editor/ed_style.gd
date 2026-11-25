extends RefCounted
## Look of the level editor: Last Light colours, chunky buttons, pixel icons.

const PAL: Dictionary = LxInteractable.PAL

const ICONS: Dictionary = {
	"hand": ["..#.#.#....", "..#.#.#.#..", "..#.#.#.#..", "..#.#.#.#..", "#.#.#.#.#..", "##.######..", "##########.", ".#########.", "..########.", "...######..", "...######.."],
	"erase": [".......##..", "......####.", ".....######", "....######.", "...#.####..", "..###.##...", ".#####.....", "#######....", ".#####.....", "..###......", "########..."],
	"wire": [".###.......", "#...#......", "#...#......", ".####......", "....##.....", ".....##....", "......####.", "......#...#", "......#...#", ".......###.", "..........."],
	"note": ["###########", "#.........#", "#.#######.#", "#.........#", "#.#####...#", "#.........#", "###########", "..###......", "..##.......", "..#........", "..........."],
	"undo": ["...#.......", "..##.......", ".########..", "#########..", ".##.....##.", "..#......#.", ".........#.", ".........#.", "........##.", "...#####...", "..........."],
	"redo": [".......#...", ".......##..", "..########.", "..#########", ".##.....##.", ".#......#..", ".#.........", ".#.........", ".##........", "...#####...", "..........."],
	"play": ["##.........", "####.......", "######.....", "########...", "##########.", "###########", "##########.", "########...", "######.....", "####.......", "##........."],
	"heart": ["..##...##..", ".####.####.", "###########", "###########", "###########", ".#########.", "..#######..", "...#####...", "....###....", ".....#.....", "..........."],
	"fix": ["...##...##.", "..##....##.", "..##....###", "..####.####", "..########.", "...#####...", "..####.....", ".####......", "####.......", "###........", "##........."],
	"rooms": ["####.######", "####.######", "####.######", "####.......", "####.######", ".....######", "####.######", "####.######", "####.......", "####.######", "####.######"],
	"grid": ["#..#..#..#.", "##########.", "#..#..#..#.", "#..#..#..#.", "##########.", "#..#..#..#.", "#..#..#..#.", "##########.", "#..#..#..#.", "...........", "..........."],
	"trash": ["....###....", ".#########.", "...........", "..#######..", "..#.#.#.#..", "..#.#.#.#..", "..#.#.#.#..", "..#.#.#.#..", "..#.#.#.#..", "..#######..", "..........."],
	"copy": ["#######....", "#.....#....", "#.....#....", "#..#######.", "#..#.....#.", "#..#.....#.", "####.....#.", "...#.....#.", "...#.....#.", "...#######.", "..........."],
	"flip": ["....#.#....", "...##.##...", "..###.###..", ".####.####.", "#####.#####", ".####.####.", "..###.###..", "...##.##...", "....#.#....", "...........", "..........."],
	"fit": ["####...####", "#.........#", "#.........#", "#.........#", "...........", "...........", "...........", "#.........#", "#.........#", "#.........#", "####...####"],
	"check": [".........##", "........###", ".......###.", "##....###..", "###..###...", ".#####.....", "..###......", "...#.......", "...........", "...........", "..........."],
	"close": ["##.......##", "###.....###", ".###...###.", "..###.###..", "...#####...", "....###....", "...#####...", "..###.###..", ".###...###.", "###.....###", "##.......##"],
	"brush": ["........###", ".......####", "......####.", ".....####..", "....####...", "...###.....", "..##.......", ".####......", "#####......", "####.......", "##........."],
	"moon": ["...####....", "..###......", ".###.......", ".###.......", "####.......", "####.......", ".###.......", ".####....#.", "..########.", "...######..", "..........."],
}

static var _icons: Dictionary = {}


static func col(n: String, a: float = 1.0) -> Color:
	return Color(PAL.get(n, Color.MAGENTA) as Color, a)


static func icon(n: String, scale: int = 2) -> Texture2D:
	var key: String = "%s@%d" % [n, scale]
	if _icons.has(key):
		return _icons[key] as Texture2D
	var bits: Array = ICONS.get(n, []) as Array
	var img: Image = Image.create_empty(11, 11, false, Image.FORMAT_RGBA8)
	for y: int in range(bits.size()):
		var row: String = str(bits[y])
		for x: int in range(row.length()):
			if row[x] == "#":
				img.set_pixel(x, y, Color.WHITE)
	img.resize(11 * scale, 11 * scale, Image.INTERPOLATE_NEAREST)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func clear_icons() -> void:
	_icons.clear()


static func box(bg: Color, border: Color = Color.TRANSPARENT, bottom: int = 0, pad: int = 8, radius: int = 5, bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if bw > 0 or bottom > 0:
		s.border_color = border
		s.set_border_width_all(bw)
		s.border_width_bottom = maxi(bw, bottom)
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var n: StyleBoxFlat = box(col("dusk"), col("void"), 3, 7)
	var h: StyleBoxFlat = box(col("plum"), col("void"), 3, 7)
	var p: StyleBoxFlat = box(col("gold"), col("wine"), 3, 7)
	var d: StyleBoxFlat = box(col("night"), col("void"), 3, 7)
	for cls: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, n)
		t.set_stylebox("hover", cls, h)
		t.set_stylebox("pressed", cls, p)
		t.set_stylebox("hover_pressed", cls, p)
		t.set_stylebox("disabled", cls, d)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, col("cream"))
		t.set_color("font_hover_color", cls, col("cream"))
		t.set_color("font_pressed_color", cls, col("night"))
		t.set_color("font_hover_pressed_color", cls, col("night"))
		t.set_color("font_focus_color", cls, col("cream"))
		t.set_color("font_disabled_color", cls, col("mauve"))
		t.set_color("icon_normal_color", cls, col("cream"))
		t.set_color("icon_hover_color", cls, col("cream"))
		t.set_color("icon_pressed_color", cls, col("night"))
		t.set_color("icon_hover_pressed_color", cls, col("night"))
		t.set_color("icon_disabled_color", cls, col("plum"))
	for cls: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, box(col("void"), col("mauve"), 0, 7, 4, 1))
		t.set_stylebox("focus", cls, box(Color.TRANSPARENT, col("gold"), 0, 7, 4, 2))
		t.set_color("font_color", cls, col("cream"))
		t.set_color("font_placeholder_color", cls, col("mauve"))
		t.set_color("caret_color", cls, col("gold"))
	t.set_stylebox("panel", "PanelContainer", box(col("night", 0.97), col("plum"), 0, 10, 8, 1))
	t.set_color("font_color", "Label", col("cream"))
	t.set_stylebox("panel", "PopupMenu", box(col("night"), col("plum"), 0, 8, 6, 1))
	t.set_color("font_color", "PopupMenu", col("cream"))
	t.set_stylebox("hover", "PopupMenu", box(col("plum"), Color.TRANSPARENT, 0, 4))
	t.set_stylebox("panel", "TooltipPanel", box(col("void", 0.95), col("gold"), 0, 8, 5, 1))
	t.set_color("font_color", "TooltipLabel", col("cream"))
	t.set_font_size("font_size", "TooltipLabel", 14)
	var grab: StyleBoxFlat = box(col("plum"), Color.TRANSPARENT, 0, 4, 4)
	for cls: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(col("void", 0.5), Color.TRANSPARENT, 0, 4, 4))
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, box(col("wine"), Color.TRANSPARENT, 0, 4, 4))
		t.set_stylebox("grabber_pressed", cls, box(col("gold"), Color.TRANSPARENT, 0, 4, 4))
	return t


static func label(text: String, size: int = 15, c: String = "cream", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col(c))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, ic: String = "", tip: String = "", cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	if not ic.is_empty():
		b.icon = icon(ic)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	if text.is_empty():
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func tint(b: Button, bg: String, fg: String = "night", shade: String = "void") -> Button:
	## A coloured call-to-action button.
	b.add_theme_stylebox_override("normal", box(col(bg), col(shade), 4, 8))
	b.add_theme_stylebox_override("hover", box(col(bg).lightened(0.15), col(shade), 4, 8))
	b.add_theme_stylebox_override("pressed", box(col(bg).darkened(0.1), col(shade), 1, 8))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(k, col(fg))
	return b


class Pix extends Control:
	## One line of the game's own pixel font.
	var text: String = "":
		set(v):
			text = v.to_upper()
			_fit()
	var size_px: int = 3
	var color: Color = Color.WHITE
	var align: int = HORIZONTAL_ALIGNMENT_LEFT

	func _init(t: String = "", s: int = 3, c: Color = LxInteractable.PAL["cream"], a: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		size_px = s
		color = c
		align = a
		text = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _fit() -> void:
		custom_minimum_size = Vector2(LxPixelFont.width(text, size_px) + 2 * size_px, (5 + 2) * size_px)
		queue_redraw()

	func _draw() -> void:
		var x: float = float(size_px)
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x = size.x * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - float(size_px)
		LxPixelFont.draw(self, text, Vector2(x, roundf((size.y - 5.0 * size_px) * 0.5)), color, size_px, LxInteractable.PAL["void"], align)
