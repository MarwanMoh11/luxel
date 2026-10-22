extends Node2D
## Letterbox bars and narration lines (intro, finale lines, ending); ignores TIPS and LANGUAGE. Draws with
## PixelFont and the `%` glyph, fades by palette ramp (STORY.md 0). The static text helpers below are shared by
## the title, the intro, the cards and the ending.

const PALETTE := preload("res://scripts/game/ui/palette.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const PAL: Dictionary = PALETTE.PAL
const NIGHT: Color = PAL["night"]
const BAR := 16.0 ## letterbox bar height on the 320x180 game screen
const FADE := 0.3 ## seconds for a line to climb (or fall back down) its ramp
## Each colour's fade ramp, from just above void to the colour itself (void is the step before the first).
const RAMPS := {
	"cream": ["dusk", "mauve", "stone", "cream"], "gold": ["dusk", "plum", "apricot", "gold"],
	"ice": ["deep", "blue", "sky", "ice"], "stone": ["dusk", "mauve", "stone"], "mauve": ["night", "dusk", "mauve"],
	"coral": ["dusk", "plum", "wine", "coral"], "lime": ["pine", "teal", "jade", "lime"],
}
## The 3x5 "%" glyph the font lacks.
const PERCENT: Array[Vector2] = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(1, 2), Vector2(0, 3),
		Vector2(0, 4), Vector2(2, 4)]

var _bar := 0.0 ## 0 = bars out, 1 = bars in
var _bar_from := 0.0
var _bar_to := 0.0
var _bar_t := 0.0
var _bar_secs := 0.4
var _slots := {} ## slot name -> {lines, colour, y, scale, t, secs}
var _sig := 0 ## the lines' colours as last drawn (a line redraws only when its ramp steps)
var _sr := Rect2() ## the screen rect as last drawn (the bars hug it)


## Slides the letterbox bars in or out over `secs`.
func letterbox(on: bool, secs := 0.4) -> void:
	_bar_from = _bar
	_bar_to = 1.0 if on else 0.0
	_bar_t = 0.0
	_bar_secs = maxf(secs, 0.0)
	if _bar_secs == 0.0:
		_bar = _bar_to
	queue_redraw()


## True while the bars are in (or sliding in).
func bars_on() -> bool:
	return _bar_to > 0.5


## Shows `lines` in palette colour `colour` for `secs` (fades included). y -1 = the bottom bar slot (STORY.md 0:
## one line at y 166, two at 165 and 172; 150 / 143 and 150 without the letterbox). A new line in the same `slot`
## replaces the old one; other slots (the ending's title, toast and credits) stay.
func say(lines: PackedStringArray, colour: String, secs: float, y := -1.0, scale := 1, slot := "") -> void:
	_slots[slot] = {"lines": lines, "colour": colour, "y": y, "scale": scale, "t": 0.0, "secs": secs}
	queue_redraw()


## say() with the story line `id` (story_text.gd).
func say_id(id: String, colour: String, secs: float, y := -1.0, scale := 1, slot := "") -> void:
	say(STORY.lines(id), colour, secs, y, scale, slot)


## True while `slot` shows a line.
func saying(slot := "") -> bool:
	return _slots.has(slot)


## Removes the line in `slot` at once.
func unsay(slot := "") -> void:
	_slots.erase(slot)
	queue_redraw()


## Removes any narration line at once (every slot).
func clear() -> void:
	_slots.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var redraw := _bar != _bar_to # the bars move every frame; a line only when its colour steps (or it ends)
	if _bar != _bar_to:
		_bar_t += delta
		_bar = lerpf(_bar_from, _bar_to, clampf(_bar_t / _bar_secs, 0.0, 1.0)) if _bar_secs > 0.0 else _bar_to
	var sig := 0
	for slot: String in _slots.keys():
		var s: Dictionary = _slots[slot]
		s["t"] += delta
		if s["t"] >= s["secs"]:
			_slots.erase(slot)
			redraw = true
		else:
			var p := minf(float(s["t"]), float(s["secs"]) - float(s["t"])) / FADE
			sig = sig * 31 + ramp(s["colour"], p).to_rgba32()
	var sr := Display.screen_rect()
	if redraw or sig != _sig or sr != _sr:
		_sig = sig
		_sr = sr
		queue_redraw()


func _draw() -> void:
	if _bar > 0.0:
		var sr := Display.screen_rect()
		var top := lerpf(sr.position.y, BAR, _bar)
		var bottom := lerpf(sr.end.y, 180.0 - BAR, _bar)
		draw_rect(Rect2(sr.position.x, sr.position.y, sr.size.x, top - sr.position.y).abs(), PAL["void"])
		draw_rect(Rect2(sr.position.x, bottom, sr.size.x, sr.end.y - bottom).abs(), PAL["void"])
	for slot: Dictionary in _slots.values():
		_draw_slot(slot)


func _draw_slot(s: Dictionary) -> void:
	var t: float = s["t"]
	var p := minf(t, float(s["secs"]) - t) / FADE
	var c := ramp(s["colour"], p)
	if c.a == 0.0:
		return
	var lines: PackedStringArray = s["lines"]
	var scale: int = s["scale"]
	var y: float = s["y"]
	var gap := 7.0 * scale
	if y < 0.0:
		y = (166.0 if lines.size() == 1 else 165.0) if bars_on() else 150.0 - gap * (lines.size() - 1)
	for i in lines.size():
		centred(self, lines[i], 160.0, y + gap * i, c, scale)


# ---- shared text helpers (static: any CanvasItem can call them) ----------------------------------------------

## The colour of a line `p` of the way up its ramp (0 = void, transparent; 1 or more = the colour itself).
static func ramp(colour: String, p: float) -> Color:
	var steps: Array = RAMPS.get(colour, [colour])
	var i := mini(floori(clampf(p, 0.0, 1.0) * (steps.size() + 1)) - 1, steps.size() - 1)
	return Color(0, 0, 0, 0) if i < 0 else PAL[steps[i]]


## Draws `s` (3x5 font, "%" included) with its top-left at `pos` and a 1 px outline.
static func text(ci: CanvasItem, s: String, pos: Vector2, colour: Color, scale := 1, outline := NIGHT) -> void:
	if colour.a == 0.0:
		return
	pos = pos.round()
	PixelFont.draw(ci, s, pos, colour, outline, scale)
	for i in s.length():
		if s[i] != "%":
			continue
		var at := pos + Vector2(i * (PixelFont.W + 1) * scale, 0)
		for offset in PixelFont.OUTLINE:
			_percent(ci, at + offset * scale, outline, scale)
		_percent(ci, at, colour, scale)


## Draws `s` centred on `cx` with its top at `y`.
static func centred(ci: CanvasItem, s: String, cx: float, y: float, colour: Color, scale := 1, outline := NIGHT) -> void:
	text(ci, s, Vector2(roundf(cx - PixelFont.width(s, scale) / 2.0), y), colour, scale, outline)


## Draws `s` with its right edge at `right_x`.
static func right(ci: CanvasItem, s: String, right_x: float, y: float, colour: Color, scale := 1, outline := NIGHT) -> void:
	text(ci, s, Vector2(right_x - PixelFont.width(s, scale), y), colour, scale, outline)


## A card panel (design 13): dusk, framed night then mauve.
static func panel(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, NIGHT)
	ci.draw_rect(r.grow(-1), PAL["mauve"])
	ci.draw_rect(r.grow(-2), PAL["dusk"])


static func _percent(ci: CanvasItem, at: Vector2, colour: Color, scale: int) -> void:
	for p in PERCENT:
		ci.draw_rect(Rect2(at + p * scale, Vector2(scale, scale)), colour)
