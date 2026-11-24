class_name LxBubble
extends Node2D
## Pictogram speech bubble renderer for Lamp-Folk NPCs (SPEC 3.6).
## Draws strips of 9x9 icons from luxel/art/ui/bubble_icons.png (88 icons, Last Light palette),
## optional page pips & [E] advance indicator. Also exposes static draw_icon() for Journal/Hub.

const SHEET_JSON_PATH: String = "res://luxel/art/ui/bubble_icons.json"
const ICON_SZ: float = 9.0
const ICON_GAP: float = 2.0
const PAD_X: float = 5.0
const PAD_Y: float = 4.0

static var _sheet: LxSpriteSheet = null
static var _rects: Dictionary = {}
static var _loaded: bool = false

var icons: Array[String] = []
var page_index: int = 0
var page_count: int = 1
var accent_key: String = "gold"
var show_advance_pip: bool = false
var _age: float = 0.0


static func ensure_sheet() -> LxSpriteSheet:
	if not _loaded:
		_loaded = true
		_sheet = LxSpriteSheet.load_sheet(SHEET_JSON_PATH)
		_rects.clear()
		if FileAccess.file_exists(SHEET_JSON_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_JSON_PATH))
			if parsed is Dictionary:
				var ic: Variant = (parsed as Dictionary).get("icons", {})
				if ic is Dictionary:
					for k: Variant in (ic as Dictionary).keys():
						var arr: Variant = (ic as Dictionary)[k]
						if arr is Array and (arr as Array).size() >= 4:
							var a: Array = arr as Array
							_rects[str(k)] = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return _sheet


static func icon_names() -> PackedStringArray:
	ensure_sheet()
	var out := PackedStringArray()
	for k: Variant in _rects.keys():
		out.append(str(k))
	out.sort()
	return out


static func has_icon(icon_id: String) -> bool:
	ensure_sheet()
	return _rects.has(icon_id)


static func draw_icon(canvas: CanvasItem, icon_id: String, top_left: Vector2, scale: float = 1.0, modulate: Color = Color.WHITE) -> bool:
	if canvas == null:
		return false
	var s: LxSpriteSheet = ensure_sheet()
	if s == null or s.tex == null:
		return false
	var src: Rect2 = _rects.get(icon_id, _rects.get("question", Rect2(0.0, 0.0, 9.0, 9.0))) as Rect2
	var dst := Rect2(top_left.round(), src.size * scale)
	canvas.draw_texture_rect_region(s.tex, dst, src, modulate)
	return _rects.has(icon_id)


func _ready() -> void:
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func show_strip(p_icons: Array[String], p_page: int = 0, p_total: int = 1, p_accent: String = "gold") -> void:
	icons = p_icons.duplicate()
	page_index = clampi(p_page, 0, maxi(0, p_total - 1))
	page_count = maxi(1, p_total)
	accent_key = p_accent if LxPalette.is_valid_color(p_accent) else "gold"
	show_advance_pip = page_index + 1 < page_count
	_age = 0.0
	visible = not icons.is_empty()
	queue_redraw()


func hide_bubble() -> void:
	visible = false
	icons.clear()


func tick(dt: float) -> void:
	if not visible:
		return
	_age += dt
	queue_redraw()


func _draw() -> void:
	if not visible or icons.is_empty():
		return
	var fr: bool = LxHudFx.flash_reduced()
	var n: int = icons.size()
	var strip_w: float = float(n) * ICON_SZ + float(maxi(0, n - 1)) * ICON_GAP
	var extra_r: float = 7.0 if show_advance_pip else 0.0
	var bw: float = roundf(strip_w + PAD_X * 2.0 + extra_r)
	var bh: float = roundf(ICON_SZ + PAD_Y * 2.0 + (3.0 if page_count > 1 else 0.0))
	var bob: float = 0.0 if fr else roundf(sin(_age * 3.0) * 0.6)
	var bx: float = roundf(-bw * 0.5)
	var by: float = roundf(-bh - 6.0 + bob)

	var r := Rect2(bx, by, bw, bh)
	# Outer dark rim + palette border + night fill
	draw_rect(Rect2(r.position + Vector2(1.0, 1.0), r.size), LxPalette.PAL["void"])
	LxPixelFont.draw_panel(self, r, "night", accent_key, "void")
	# Inner top highlight line
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 1.0), LxPalette.PAL["dusk"])
	# Speech tail pointing down to speaker
	draw_rect(Rect2(-3.0, r.end.y - 1.0, 6.0, 2.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-2.0, r.end.y, 4.0, 2.0), LxPalette.color(accent_key))
	draw_rect(Rect2(-1.0, r.end.y, 2.0, 2.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-1.0, r.end.y + 2.0, 2.0, 1.0), LxPalette.PAL["void"])
	draw_rect(Rect2(0.0, r.end.y + 1.0, 1.0, 1.0), LxPalette.color(accent_key))

	# Draw icon strip with crisp staggered pop-in
	var ix: float = r.position.x + PAD_X
	var iy: float = r.position.y + PAD_Y
	for i: int in range(n):
		var pop_dy: float = 0.0
		if not fr:
			var dt_i: float = _age - float(i) * 0.055
			if dt_i < 0.0:
				continue
			if dt_i < 0.12:
				pop_dy = -1.0
		draw_icon(self, icons[i], Vector2(ix + float(i) * (ICON_SZ + ICON_GAP), iy + pop_dy), 1.0)

	# Small right-edge advance chevron when more pages follow
	if show_advance_pip:
		var pulse: bool = fr or (int(_age * 4.0) % 2 == 0)
		var ax: float = r.end.x - 6.0
		var ay: float = iy + 3.0 + (0.0 if pulse else 1.0)
		var ac: Color = LxPalette.PAL["cream"] if pulse else LxPalette.color(accent_key)
		draw_rect(Rect2(ax, ay, 3.0, 1.0), ac)
		draw_rect(Rect2(ax + 1.0, ay + 1.0, 1.0, 1.0), ac)

	# Page pips along bottom inside bubble when multi-page
	if page_count > 1:
		var tot_w: float = float(page_count * 3 - 1)
		var px0: float = roundf(-tot_w * 0.5)
		var py: float = r.end.y - 4.0
		for p: int in range(page_count):
			var pc: Color = LxPalette.PAL["gold"] if p == page_index else LxPalette.PAL["dusk"]
			draw_rect(Rect2(px0 + float(p * 3), py, 2.0, 1.0), pc)
