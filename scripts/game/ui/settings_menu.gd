extends Node2D
## The Settings menu on CanvasLayer 10 (above the screen effects, always crisp): modes tutorial, player, forced,
## auto (self-sale staging, design 10.2) and pixels (10.4: a compact panel at the top, 1% per press, then
## AUTO-SELL); and the toast. Calls fx.menu(true/false) in tutorial,
## player and forced modes. Rewritten from scripts/proto/low_settings/settings_page.gd in the Last Light palette:
## panels dusk, frames night and mauve, text cream, titles gold, warnings coral. Every string goes through
## shop.txt (LANGUAGE) except the self-sale banner, the PIXELS row and the toast. For first-time players each row
## reads value now > after the sale, the footer spells out the picked sale (YOU LOSE / YOU GET, the stats it
## changes lit), and the tutorial menu adds a HOW IT WORKS box.

signal closed(sale: Dictionary)
signal pixel_sold(sale: Dictionary) ## pixels mode: one press sold 1% (the menu stays open; the run applies it)

const DATA := preload("res://scripts/game/shop/shop_data.gd")
const SHOP := preload("res://scripts/game/shop/shop.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const PAL: Dictionary = preload("res://scripts/game/ui/palette.gd").PAL
const CX := 160.0
const PANEL := Rect2(10, 4, 300, 172)
# Columns: name, slider, the value now > after the sale, and what the sale pays.
const NAME_X := 28.0
const SLIDER_X := 84.0
const SLIDER_W := 24.0
const NOW_X := 114.0
const ARROW_X := 146.0
const AFTER_X := 151.0
const GET_X := 192.0
const LOCK_X := 296.0
const TAG_END := 300.0 ## the row's NEW mark and the footer's form tag must end by here (the row band's right edge)
# Bands (top y of each).
const TAB_X := 18
const TAB_Y := 28
const TAB_GAP := 3
const ROW_Y := 48
const SEP_Y := 129
const QUIP_Y := 133 ## YOU LOSE (or the sale result)
const STAT_Y := 144 ## auto mode: the sold row's quip
const KEYS_Y := 160 ## auto mode: the AUTO / BLAST tag
const GET_Y := 141 ## YOU GET (or the sold row's quip)
const PREVIEW_Y := 151 ## the stat line, with what the picked sale changes lit
const HINT_Y := 163 ## the key hint
const STAT_W := 288.0 ## the stat line's widest (the panel's inside is 292)
## Tutorial menu: the HOW IT WORKS box under the one row.
const HOW_BOX := Rect2(52, 66, 216, 52)
## Rows with more steps than this get a fill bar instead of a notched slider (PIXELS has 100).
const MAX_NOTCHES := 8
## The 3x5 "%" glyph the font lacks.
const PERCENT: Array[Vector2] = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(1, 2), Vector2(0, 3),
		Vector2(0, 4), Vector2(2, 4)]
const PADLOCK: Array[Rect2] = [Rect2(1, 0, 3, 1), Rect2(0, 1, 1, 2), Rect2(4, 1, 1, 2), Rect2(0, 3, 5, 3)]
const SOLD_HOLD := 0.6 ## player, tutorial and pixels modes: the sale shows this long, then the menu closes
# Auto mode (design 10.2), seconds from open.
const AUTO_CURSOR := 0.10
const AUTO_STEP := 0.06
const AUTO_SELL := 0.45
const AUTO_DRAIN := 0.15
const AUTO_SHUT := 0.75
const AUTO_RESUME := 0.15 ## the world resumes this long after the menu shuts (sale["resume_in"])
## ... all of the above times `_pace`: 1 for self-sales 1-3, then 25% quicker each (settings_fx.finale_pace).
const AUTO_PACE_FLOOR := 0.40 ## the menu never runs quicker than this share (the SOLD stamp stays readable; the gaps go lower)
# Forced mode: the lock-break after CONFIRM SALES, seconds from the sale.
const CRACK_AT := 0.3
const CRACK_GAP := 0.12
const MUST_GO_AT := 0.8
const FORCED_HOLD := 2.0
# Pixels mode (design 10.4): the compact panel at the top, so the island, Wick and the lantern stay visible.
const PIXEL_PANEL := Rect2(46, 8, 228, 56)
const PIXEL_ROW_Y := 14
const PIXEL_ROW_GAP := 8
const PIXEL_NAME_X := 54.0
const VALUE_X := 116.0
const POWER_X := 158.0
const PIXEL_RULE_Y := 31
const PIXEL_QUIP_Y := 34
const PIXEL_STAT_Y := 43
const PIXEL_KEYS_Y := 52
const PIXEL_AUTO_AFTER := 5 ## presses before the AUTO-SELL row shows
const PIXEL_AUTO_HOLD := 0.3 ## AUTO-SELL ON. shows this long, then the menu closes
const PIXEL_PRESS_GAP := 0.05 ## s between presses at least
const PIXEL_GOLD := 0.25 ## the -1% PIXELS. line stays gold this long after a press
const PIXEL_FLASH := 2.0 / 60.0 ## the row flashes cream for 2 frames on a press
const AUTO_ROW := "auto_sell"

var shop ## shop.gd
var run ## run.gd (null in tests)

var _open := false
var _mode := ""
var _level := 1
var _line := ""
var _tabs: Array[int] = [] ## tabs on the strip
var _nav: Array[int] = [] ## tabs the cursor can visit
var _new: Array[int] = [] ## tabs flashing NEW
var _tab := 0
var _row := 0
var _t := 0.0 ## seconds since open
var _sold_t := -1.0 ## seconds since the sale (-1: not yet)
var _sale := {}
var _result := "" ## the quip line after a sale
var _drain_from := 0.0 ## the sold row's level before the sale (auto mode: the slider drains from it)
var _target := ""
var _cursor_steps := 0 ## auto mode: ghost cursor steps taken
var _cracked := 0
var _frames := 0 ## frames since open (the auto pop)
var _still := "" ## still menus: _still_sig() as last drawn ("": none yet)
var _toast := ""
var _toast_t := 0.0
var _plain := false
var _presses := 0 ## pixels mode: presses that sold 1%
var _press_t := -1.0 ## pixels mode: seconds since the last press (-1: none yet)
var _bb_first := false ## player mode: the first menu that offers BUY BACK (its header line blinks gold)
var _blast := 0 ## auto mode: this self-sale's charge of the blast (BLAST k/n, P8 B2); 0 = AUTO
var _blast_of := 0
var _pace := 1.0 ## auto mode: this self-sale's speed-up (settings_fx.finale_pace(_blast)); AUTO_* times scale by it


## Keeps the shop and the run.
func setup(s: RefCounted, r: Node2D) -> void:
	shop = s
	run = r


## Opens the menu. ctx = {mode, level, new_tab, target (auto), line}.
func open(ctx: Dictionary) -> void:
	_mode = String(ctx.get("mode", "player"))
	_level = int(ctx.get("level", run.prog.level if run and run.prog else 1))
	_line = String(ctx.get("line", ""))
	_blast = int(ctx.get("blast", 0))
	_blast_of = int(ctx.get("blast_of", 0))
	_pace = maxf(AUTO_PACE_FLOOR, run.fx.finale_pace(_blast)) if run and run.fx and _mode == "auto" else 1.0
	_target = String(ctx.get("target", ""))
	_open = true
	_t = 0.0
	_sold_t = -1.0
	_sale = {}
	_result = ""
	_cursor_steps = 0
	_cracked = 0
	_frames = 0
	_still = ""
	_new = []
	match _mode:
		"tutorial":
			_tabs = [0]
			_nav = [0]
			_tab = 0
		"forced":
			shop.reveal_advanced()
			_tabs = shop.menu_tabs(_level)
			_nav = [DATA.ADVANCED_TAB]
			_tab = DATA.ADVANCED_TAB
		"auto":
			_tabs = shop.menu_tabs(_level)
			_nav = []
			_tab = DATA.tab_of(_target)
		"pixels":
			_tabs = shop.menu_tabs(_level)
			_nav = [DATA.ADVANCED_TAB]
			_tab = DATA.ADVANCED_TAB
		_:
			_open_player(int(ctx.get("new_tab", -1)))
	_bb_first = false
	if _mode == "player" and shop.buy_back_open():
		_bb_first = not shop.buy_back_seen
		shop.buy_back_seen = true
	_row = 0 if _mode == "auto" else _first_row(_tab)
	if _mode == "pixels":
		_presses = 0
		_press_t = -1.0
		_row = 0 # row 0 = PIXELS, row 1 = AUTO-SELL (after PIXEL_AUTO_AFTER presses)
	# only open tabs count as seen, so a tab still showing "LV n" flashes NEW (and opens the menu) when it unlocks
	var shown: Array[int] = []
	shown.assign(_tabs.filter(func(t: int) -> bool: return shop.tab_state(t, _level) == SHOP.TabState.OPEN))
	shop.mark_seen(shown)
	if _walled() and run and run.fx:
		run.fx.menu(true)
	queue_redraw()


## True while the menu is open.
func is_open() -> bool:
	return _open


## A toast line for `secs` (top centre, plain English: the PIXELS countdown).
func toast(text: String, secs: float) -> void:
	_toast = text
	_toast_t = secs
	queue_redraw()


## Bots and tests: a menu key by name ("left", "right", "up", "down", "sell"). Same rules as the keyboard.
func press(key: String) -> void:
	if not _accepts_keys():
		return
	match key:
		"left":
			_move_tab(-1)
		"right":
			_move_tab(1)
		"up":
			_move_row(-1) # menus are spared: Up always works here, UP KEY sold or not
		"down":
			_move_row(1)
		"sell":
			if _mode == "pixels":
				_sell_pixel()
			else:
				_sell()


## Pixels mode: presses that sold 1% so far (checks and bots).
func pixel_presses() -> int:
	return _presses


## Bots and tests: moves the cursor to row `id` ("back" = BACK) on a tab the cursor can visit. False if it can't.
## Pixels mode: "pixels", or "auto_sell" once its row shows.
func select(id: String) -> bool:
	if not _accepts_keys():
		return false
	if _mode == "pixels":
		var i := _rows().find(id)
		if i < 0:
			return false
		_row = i
		queue_redraw()
		return true
	var t := _tab if id == "back" else DATA.tab_of(id)
	if not t in _nav:
		return false
	_tab = t
	var rows := _rows()
	_row = rows.size() if id == "back" else rows.find(id)
	if _row > rows.size() or (_row == rows.size() and not _has_back()):
		_row = _first_row(_tab)
		return false
	queue_redraw()
	return true


## The row id under the cursor ("back" for BACK).
func cursor_id() -> String:
	var rows := _rows()
	return "back" if _row >= rows.size() else rows[_row]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _accepts_keys():
		return
	var k := ""
	match key.keycode:
		KEY_LEFT, KEY_A:
			k = "left"
		KEY_RIGHT, KEY_D:
			k = "right"
		KEY_UP, KEY_W:
			k = "up"
		KEY_DOWN, KEY_S:
			k = "down"
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			k = "sell"
	if k != "":
		press(k)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0: # the toast is still, so it redraws once at expiry (toast() redrew it at the start)
			_toast = ""
			queue_redraw()
	if not _open:
		return
	_t += delta
	_frames += 1
	if _sold_t >= 0.0:
		_sold_t += delta
	if _press_t >= 0.0:
		_press_t += delta
	match _mode:
		"auto":
			_step_auto()
		"forced":
			_step_forced()
		"pixels":
			if _sold_t >= (PIXEL_AUTO_HOLD if _sale.has("auto_pixels") else SOLD_HOLD):
				_close()
		_:
			if _sold_t >= SOLD_HOLD:
				_close()
	if _mode == "auto" or _sold_t >= 0.0:
		queue_redraw() # these move every frame (cursor, drain, stamp, flashes)
		return
	# The other menus are still but for a few timed looks: redraw only when one flips (keys redraw themselves).
	var sig := _still_sig()
	if sig != _still:
		_still = sig
		queue_redraw()


## What the next frame of a still menu would draw differently: the two blinks (player, tutorial; the forced menu has
## none before its sale), or the press flash, the gold quip and the stat line (pixels).
func _still_sig() -> String:
	if _mode == "pixels":
		return "%d%d%s" % [int(_press_t >= 0.0 and _press_t < PIXEL_FLASH), int(_press_t >= 0.0 and _press_t < PIXEL_GOLD),
				_pixel_stat_text()]
	return "%d%d" % [int(_blink() and not _new.is_empty()), int(_bb_first and _t < 1.5 and fmod(_t, 0.5) >= 0.3)]


# --- modes -----------------------------------------------------------------------------------------------------

func _open_player(new_tab: int) -> void:
	_tabs = shop.menu_tabs(_level)
	_tabs.erase(DATA.ADVANCED_TAB)
	# Left/Right visit open tabs that still have a row to sell, now or later, or one to buy back (sold-out tabs are
	# skipped otherwise)
	_nav.assign(_tabs.filter(func(t: int) -> bool:
		return shop.tab_state(t, _level) == SHOP.TabState.OPEN and (not _sold_out_tab(t) or _has_buyable(t))))
	_new = shop.new_tabs(_level)
	_new.erase(DATA.ADVANCED_TAB)
	_tab = new_tab if new_tab in _nav and shop.has_stock(new_tab) else shop.pick_tab(_level)
	if _tab < 0:
		_tab = _nav[0] if not _nav.is_empty() else 0


## The self-sale: pop open, a ghost cursor walks to the row, SELL, the SOLD stamp, snap shut (design 10.2).
func _step_auto() -> void:
	var target := _rows().find(_target)
	# 60 ms a row, faster for deep rows so the cursor always arrives before SELL
	var cursor := AUTO_CURSOR * _pace
	var sell := AUTO_SELL * _pace
	var step := minf(AUTO_STEP * _pace, (sell - cursor - 0.05 * _pace) / maxf(target, 1.0))
	var due := clampi(floori((_t - cursor) / step), 0, maxi(target, 0)) if _t >= cursor else 0
	while _cursor_steps < due:
		_cursor_steps += 1
		_row = _cursor_steps
		_fx_play("pick")
	if _t >= sell and _sold_t < 0.0:
		_row = maxi(target, 0)
		_drain_from = shop.lv(_target)
		_sale = shop.sell(_target, true)
		_fx_play("sell", 0.0)
		_sold_t = _t - sell
		_result = "%s: SOLD" % DATA.ROWS[_target]["name"] if _target in DATA.ROWS else "SOLD"
	if _t >= AUTO_SHUT * _pace:
		_sale["resume_in"] = AUTO_RESUME * _pace
		_close()


## After CONFIRM SALES: the padlocks crack, the strip flashes, the header turns, then the menu closes.
func _step_forced() -> void:
	if _sold_t < 0.0:
		return
	while _cracked < 2 and _sold_t >= CRACK_AT + _cracked * CRACK_GAP:
		_cracked += 1
		if run and run.fx:
			run.fx.crack()
	if _sold_t >= FORCED_HOLD:
		_close()


func _sell() -> void:
	if _sold_t >= 0.0:
		return
	var rows := _rows()
	if _row >= rows.size():
		if not _has_back():
			return
		_sale = shop.back()
		_sale["back"] = true
		_sale["id"] = ""
		_result = "YOU REST. +1 HEART." if int(_sale["heal"]) > 0 else "YOU KEEP EVERYTHING."
		_fx_play("pick")
	else:
		var id: String = rows[_row]
		if _buyable(id):
			_buy_back(id)
			return
		if shop.row_state(id) != SHOP.RowState.OPEN:
			_fx_play("tab")
			return
		_drain_from = shop.lv(id)
		_fx_play("sell", 0.0) # before SOUND applies, so the coins are the last thing you hear
		var forms := _new_forms(id)
		_sale = shop.sell(id)
		_sale["forms"] = forms # the lantern forms it lights: the HUD calls them out over Wick
		if id == DATA.CONFIRM:
			_sale["refill"] = true # CONFIRM SALES refills every heart, even with HEALING sold
		_result = "SOLD FOR " + String(_sale["label"])
	_sold_t = 0.0
	queue_redraw()


## BUY BACK (design 9.4): the row gets one step back, its power stays, and this menu's choice is spent.
func _buy_back(id: String) -> void:
	_sale = shop.buy_back(id)
	if _sale.is_empty():
		return
	_result = STORY.line("menu.buy_back.done", "BOUGHT BACK. POWER KEPT.")
	_fx_play("pick")
	_sold_t = 0.0
	queue_redraw()


## True when the cursor can buy back row `id` in this menu (player menus only; the row is sold out).
func _buyable(id: String) -> bool:
	return _mode == "player" and shop.can_buy_back(id)


func _has_buyable(t: int) -> bool:
	return _rows_of(t).any(func(id: String) -> bool: return _buyable(id))


## Pixels mode: SPACE on PIXELS sells 1% (the world stays frozen; at 100% the menu closes), on AUTO-SELL the menu
## closes and the rest sell themselves (design 10.4).
func _sell_pixel() -> void:
	if _press_t >= 0.0 and _press_t < PIXEL_PRESS_GAP:
		return
	if cursor_id() == AUTO_ROW:
		_sale = {"id": "", "auto_pixels": true}
		_result = STORY.line("menu.pixels.auto_on", "AUTO-SELL ON.")
		_fx_play("pick")
		_sold_t = 0.0
		queue_redraw()
		return
	_fx_play("sell", 0.0)
	var sale: Dictionary = shop.sell(DATA.PIXELS)
	if sale.is_empty():
		return
	_presses += 1
	_press_t = 0.0
	_result = String(sale.get("quip", DATA.PIXEL_QUIP))
	pixel_sold.emit(sale)
	if shop.lv(DATA.PIXELS) >= DATA.PIXEL_STEPS:
		_sale = {"id": "", "pixels_done": true}
		_sold_t = 0.0
	queue_redraw()


func _close() -> void:
	if not _open:
		return
	_open = false
	if _walled() and run and run.fx:
		run.fx.menu(false)
	queue_redraw()
	closed.emit(_sale)


func _walled() -> bool:
	return _mode in ["tutorial", "player", "forced"]


func _accepts_keys() -> bool:
	return _open and _sold_t < 0.0 and _mode != "auto"


func _has_back() -> bool:
	return _mode == "player"


## The rows the current tab shows (the tutorial shows only SUBTITLES; PIXELS appears after the 13th self-sale).
func _rows() -> Array:
	return _rows_of(_tab)


func _rows_of(t: int) -> Array:
	if _mode == "tutorial":
		return ["subtitles"]
	if _mode == "pixels":
		return [DATA.PIXELS, AUTO_ROW] if _presses >= PIXEL_AUTO_AFTER else [DATA.PIXELS]
	var rows: Array = DATA.TABS[t]["rows"].duplicate()
	if t == DATA.ADVANCED_TAB and not (shop.closing() and shop.finale_queue().is_empty()):
		rows.erase(DATA.PIXELS)
	return rows


## Rows of tab `t` the player can sell in this menu (0 in the finale menus and on tabs the cursor can't visit).
func _stock(t: int) -> int:
	if not _mode in ["player", "tutorial"] or not t in _nav:
		return 0
	var n := 0
	for id: String in _rows_of(t):
		if shop.row_state(id) == SHOP.RowState.OPEN:
			n += 1
	return n


## True when tab `t` has a NOT FOR SALE row (a beauty row before CONFIRM SALES: it sells later).
func _has_later(t: int) -> bool:
	for id: String in _rows_of(t):
		if shop.row_state(id) == SHOP.RowState.NOT_FOR_SALE:
			return true
	return false


func _sold_out_tab(t: int) -> bool:
	return _rows_of(t).all(func(id: String) -> bool: return shop.sold_out(id))


func _first_row(t: int) -> int:
	var rows := _rows_of(t)
	for i in rows.size():
		if shop.row_state(rows[i]) == SHOP.RowState.OPEN:
			return i
	return rows.size() if _has_back() else 0


func _move_tab(dir: int) -> void:
	if _nav.size() < 2:
		return
	var i := _nav.find(_tab)
	_tab = _nav[posmod(i + dir, _nav.size())]
	_row = _first_row(_tab)
	_fx_play("tab")
	queue_redraw()


## Up/Down: the next row that can be sold or bought back, or BACK (dead rows are skipped, so SPACE always does
## something).
func _move_row(dir: int) -> void:
	var rows := _rows()
	var n := rows.size() + (1 if _has_back() else 0)
	var to := _row
	for i in n:
		to = posmod(to + dir, n)
		if to >= rows.size() or not rows[to] in DATA.ROWS or shop.row_state(rows[to]) == SHOP.RowState.OPEN \
				or _buyable(rows[to]):
			break
	if to == _row:
		return
	_row = to
	_fx_play("pick")
	queue_redraw()


func _fx_play(sfx: String, jitter := 0.06) -> void:
	if run and run.fx:
		run.fx.play(sfx, jitter)


# --- drawing ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	if _open and _mode == "pixels":
		draw_set_transform(Vector2.ZERO)
		_draw_pixels_panel()
	elif _open:
		_apply_pop()
		_draw_menu()
	if _toast != "" and not (_open and _mode == "pixels"): # the panel's row shows the %
		draw_set_transform(Vector2.ZERO)
		_plain = true
		_draw_toast()
		_plain = false


## Auto mode pops open over 2 frames: 90% then 100% scale.
func _apply_pop() -> void:
	var s := 0.9 if _mode == "auto" and _frames <= 1 else 1.0
	draw_set_transform(Vector2(CX, 90.0) * (1.0 - s), 0.0, Vector2(s, s))


func _draw_menu() -> void:
	_draw_panel(PANEL)
	_draw_header()
	_draw_tabs()
	var rows := _rows()
	var gap := 8 if rows.size() + 1 > 8 else 10
	for i in rows.size():
		_plain = rows[i] == DATA.PIXELS
		_draw_row(rows[i], i, ROW_Y + i * gap)
		_plain = false
	if _has_back():
		_draw_back(rows.size(), ROW_Y + rows.size() * gap)
	if _mode == "auto" and _sold_t >= 0.0:
		_draw_stamp(ROW_Y + _row * gap)
	draw_rect(Rect2(20, SEP_Y, 280, 1), PAL["mauve"])
	_draw_footer(rows)
	if _mode == "tutorial":
		_draw_how_to()


## Tutorial menu: the trade in three plain steps, in the empty space under its one row.
func _draw_how_to() -> void:
	draw_rect(HOW_BOX, PAL["mauve"])
	draw_rect(HOW_BOX.grow(-1), PAL["night"])
	_centered(STORY.line("menu.how.title", "HOW IT WORKS"), CX, HOW_BOX.position.y + 5, PAL["gold"], PAL["night"])
	for i in 3:
		var x := HOW_BOX.position.x + 8
		var y := HOW_BOX.position.y + 16 + i * 10
		draw_rect(Rect2(x, y - 1, 7, 7), PAL["gold"])
		_text(str(i + 1), x + 2, y, PAL["night"], PAL["gold"])
		_text(STORY.line("menu.how.%d" % (i + 1)), x + 12, y, PAL["cream"], PAL["night"])


func _draw_header() -> void:
	var title := STORY.line("menu.levelup", "LEVEL UP!")
	if _mode == "forced" and _sold_t >= MUST_GO_AT:
		title = STORY.line("finale.must_go", "EVERYTHING MUST GO")
	_text(title, 22, 12, PAL["gold"], PAL["night"], 2)
	_right("LV %d" % _level, 298, 12, PAL["stone"])
	var sub := STORY.line("menu.header", "SELL 1 SETTING. GET 1 POWER.")
	match _mode:
		"tutorial":
			sub = STORY.line("tut.menu_header", "THE LANTERN BUYS SETTINGS")
		"forced":
			sub = STORY.line("finale.nothing_left", "THERE IS NOTHING LEFT TO SELL.")
		"auto", "pixels":
			sub = STORY.line("finale.header", "THE LANTERN WANTS THE GOOD STUFF")
	var ink: Color = PAL["cream"]
	if _mode == "player" and shop.buy_back_open():
		sub = STORY.line("menu.buy_back.header", "SELL ONE OR BUY ONE BACK ONCE")
		if _bb_first: # gold in the first menu that offers it, blinking 3 times
			ink = PAL["gold"]
			if _t < 1.5 and fmod(_t, 0.5) >= 0.3:
				return
	_right(sub, 298, 19, ink)


## The tab strip: the current tab stands up and opens into the page; locked tabs are dim with "LV n" under them.
## One sign after each name: a gold badge counting the rows you can sell there now, or a padlock when nothing on
## it sells yet (the beauty rows, until CONFIRM SALES breaks the locks); sold-out tabs are dim with no sign.
func _draw_tabs() -> void:
	draw_rect(Rect2(16, TAB_Y + 8, 288, 1), PAL["mauve"])
	var x := TAB_X
	for t in _tabs:
		_plain = t == DATA.ADVANCED_TAB # the hidden tab always reads plain, as in the prototype, even while LANGUAGE lasts
		var locked := _tab_padlock(t)
		var sign := locked or _cracked_tab(t) or _stock(t) > 0
		var w := PixelFont.width(_txt(DATA.TABS[t]["name"])) + 6 + (6 if sign else 0)
		_draw_tab(t, x, w, locked)
		_plain = false
		x += w + TAB_GAP


func _draw_tab(t: int, x: int, w: int, locked: bool) -> void:
	var title: String = DATA.TABS[t]["name"]
	var state: int = shop.tab_state(t, _level)
	var usable := t in _nav or (_mode == "auto" and t == _tab)
	var ink: Color = PAL["cream"]
	if t == _tab:
		draw_rect(Rect2(x, TAB_Y - 2, w, 11), PAL["mauve"])
		draw_rect(Rect2(x + 1, TAB_Y - 1, w - 2, 10), PAL["dusk"])
		_text(title, x + 3, TAB_Y, ink, PAL["dusk"])
	else:
		draw_rect(Rect2(x, TAB_Y, w, 9), PAL["night"])
		draw_rect(Rect2(x + 1, TAB_Y + 1, w - 2, 7), PAL["plum"] if usable else PAL["night"])
		ink = PAL["stone"] if usable else PAL["mauve"]
		if _mode == "forced" and _sold_t >= CRACK_AT and _sold_t < 1.4 and int(_sold_t * 10.0) % 2 == 0:
			ink = PAL["cream"]
		_text(title, x + 3, TAB_Y + 2, ink, PAL["night"])
	var y := TAB_Y if t == _tab else TAB_Y + 2
	if locked:
		_draw_padlock(Vector2(x + w - 8, y), PAL["stone"], false)
	elif _cracked_tab(t):
		_draw_padlock(Vector2(x + w - 8, y), PAL["coral"], true)
	elif _stock(t) > 0:
		_draw_badge(Vector2(x + w - 8, y - 1), _stock(t))
	var mid := x + w / 2.0
	if t in _new:
		if _blink():
			_centered("NEW", mid, TAB_Y + 11, PAL["coral"], PAL["dusk"])
	elif state == SHOP.TabState.LOCKED:
		_centered("LV %d" % int(DATA.TABS[t]["unlock"]), mid, TAB_Y + 11, PAL["mauve"], PAL["dusk"])


## True while tab `t` shows a padlock: nothing on it sells in this menu but some rows sell later (the beauty rows
## before CONFIRM SALES: AUDIO, and GRAPHICS once RAY TRACING is gone or in the forced menu). After the CONFIRM sale
## the AUDIO and GRAPHICS locks crack one by one. Never on ADVANCED or a tab still showing "LV n".
func _tab_padlock(t: int) -> bool:
	if _mode == "forced" and _sold_t >= 0.0 and (t == DATA.AUDIO_TAB or t == DATA.GRAPHICS_TAB):
		return _cracked <= (0 if t == DATA.AUDIO_TAB else 1)
	if t == DATA.ADVANCED_TAB or shop.tab_state(t, _level) != SHOP.TabState.OPEN:
		return false
	return _stock(t) == 0 and _has_later(t)


## The for-sale badge: a gold block with the number of rows the tab can sell now.
func _draw_badge(at: Vector2, n: int) -> void:
	draw_rect(Rect2(at, Vector2(5, 7)), PAL["gold"])
	PixelFont.draw(self, str(mini(n, 9)), at + Vector2(1, 1), PAL["night"], PAL["gold"])


## A broken padlock hangs on the beauty tabs for the rest of the lock-break.
func _cracked_tab(t: int) -> bool:
	return _mode == "forced" and _sold_t >= 0.0 and (t == DATA.AUDIO_TAB or t == DATA.GRAPHICS_TAB)


## One setting row: name, slider, the value now > after the sale, and what the sale pays, with a gold NEW when it
## lights a lantern form (the footer names it). A row BUY BACK can return shows the value it goes back to.
func _draw_row(id: String, row: int, y: int) -> void:
	var band := _row_band(row, y)
	var hot := band != PAL["dusk"]
	var state: int = shop.row_state(id)
	var just_sold := _sold_t >= 0.0 and row == _row
	var lv: int = shop.lv(id)
	var buyable := _buyable(id)
	var dim := state != SHOP.RowState.OPEN and not just_sold and not buyable
	var ink: Color = PAL["cream"] if hot or not dim else PAL["mauve"]
	_text(DATA.ROWS[id]["name"], NAME_X, y, ink, band)
	var steps := DATA.steps(id)
	var shown := float(lv)
	if just_sold and _mode == "auto":
		shown = lerpf(_drain_from, float(lv), clampf(_sold_t / (AUTO_DRAIN * _pace), 0.0, 1.0))
	if steps > MAX_NOTCHES:
		_draw_fill_bar(steps, shown, y)
	else:
		_draw_slider(steps, shown, y, dim)
	_text(shop.value_text(id), NOW_X, y, ink if hot or lv == 0 or dim else PAL["coral"], band)
	if buyable:
		_draw_after(DATA.value(id, lv - 1), y, PAL["cream"] if hot else PAL["lime"], band)
		_text(STORY.line("menu.buy_back.tag", "BUY BACK"), GET_X, y, PAL["gold"], band)
		return
	if id == shop.bought_back:
		_text(STORY.line("menu.buy_back.kept", "BOUGHT BACK"), GET_X, y, PAL["cream"] if hot else PAL["stone"], band)
		return
	if state == SHOP.RowState.SOLD_OUT:
		_text("SOLD OUT", GET_X, y, ink if hot or dim else PAL["lime"], band)
		return
	var open := state == SHOP.RowState.OPEN
	_draw_after(String(DATA.step(id, lv)["value"]), y, ink if hot or not open else PAL["coral"], band)
	var label: String = shop.next_label(id)
	if state == SHOP.RowState.NOT_FOR_SALE: # its price stays as a tease if it fits; LATER says it is not broken
		var later := "LATER"
		var later_x := LOCK_X - 3 - PixelFont.width(_txt(later))
		if GET_X + PixelFont.width(_txt(label)) + 4 <= later_x:
			_text(label, GET_X, y, ink, band)
		_text(later, later_x, y, PAL["cream"] if hot else PAL["stone"], band)
		_draw_padlock(Vector2(LOCK_X, y), PAL["stone"], false)
		return
	_text(label, GET_X, y, ink if hot else PAL["lime"], band)
	var mark := STORY.line("menu.new_mark", "NEW")
	if not just_sold and not _form_tags(id).is_empty() \
			and GET_X + PixelFont.width(_txt(label)) + 4 + PixelFont.width(_txt(mark)) <= TAG_END:
		_text(mark, TAG_END - PixelFont.width(_txt(mark)), y, PAL["gold"], band)


## The arrow and the value a row will read after the sale (or after BUY BACK).
func _draw_after(value: String, y: int, color: Color, band: Color) -> void:
	_draw_arrow(ARROW_X, y, PAL["stone"] if color != PAL["mauve"] else PAL["mauve"])
	_text(value, AFTER_X, y, color, band)


## A 5x5 right arrow with its head's back at x (the font has no ">"): a 2 px stem, then the head.
func _draw_arrow(x: float, y: int, color: Color) -> void:
	draw_rect(Rect2(x - 2, y + 2, 2, 1), color)
	draw_rect(Rect2(x, y, 1, 5), color)
	draw_rect(Rect2(x + 1, y + 1, 1, 3), color)
	draw_rect(Rect2(x + 2, y + 2, 1, 1), color)


## The footer's lantern-form tag for row `id`, longest first (the first that fits is drawn): "NEW LANTERN FORM:
## BELL TOLL", then "NEW: FIREFLY 2 + BELL TOLL", then the first form alone. The forced CONFIRM SALES lights the
## finale's blast (P8 B2). Empty when the sale lights nothing.
func _form_tags(id: String) -> Array:
	if id == DATA.CONFIRM and _mode == "forced":
		return [STORY.line("finale.blast_tag", "NEW: BLAST")]
	var gained := _new_forms(id)
	if gained.is_empty():
		return []
	var tags := [STORY.form_tag(gained), STORY.form_tag(gained.slice(0, 1))]
	if gained.size() == 1:
		tags.push_front(STORY.line("menu.new_form", "NEW LANTERN FORM:") + " " + STORY.form_tag(gained, false))
	return tags


## [[form, tier], ...] that selling row `id` would light or raise (light_fx.gd); none in the self-selling and
## PIXELS menus, or without a run (tests).
func _new_forms(id: String) -> Array:
	if not _mode in ["player", "tutorial", "forced"] or run == null or run.get("light") == null or shop.sold_out(id):
		return []
	return run.light.new_forms(DATA.step(id, shop.lv(id))["power"])


func _draw_back(row: int, y: int) -> void:
	var band := _row_band(row, y)
	var hot := band != PAL["dusk"]
	_text(STORY.line("menu.skip", "SKIP: KEEP ALL SETTINGS"), NAME_X, y, PAL["cream"], band)
	if int(shop.back()["heal"]) > 0:
		_text("HEAL 1 HEART", GET_X, y, PAL["cream"] if hot else PAL["lime"], band)
	else:
		_text("NO HEALING", GET_X, y, PAL["cream"] if hot else PAL["mauve"], band)


## Draws the row's highlight (plum when picked, flashing coral just after a sale) and returns its colour.
func _row_band(row: int, y: int) -> Color:
	var picked := row == _row and (_mode != "auto" or _t >= AUTO_CURSOR * _pace)
	var flashing := _sold_t >= 0.0
	var band: Color = PAL["dusk"]
	if picked and flashing:
		band = PAL["coral"] if int(_sold_t * 10.0) % 2 == 0 else PAL["plum"]
	elif picked:
		band = PAL["plum"]
	if band != PAL["dusk"]:
		draw_rect(Rect2(18, y - 2, 284, 9), band)
	if picked and not flashing:
		var arrow: Color = PAL["stone"] if _mode == "auto" else PAL["gold"] # the ghost cursor is pale
		draw_rect(Rect2(21, y, 1, 5), arrow)
		draw_rect(Rect2(22, y + 1, 1, 3), arrow)
		draw_rect(Rect2(23, y + 2, 1, 1), arrow)
	return band


## A little settings slider: full on the right, each sale moves the knob one notch left.
func _draw_slider(steps: int, lv: float, y: int, dim: bool) -> void:
	var rail: Color = PAL["mauve"] if dim else PAL["stone"]
	draw_rect(Rect2(SLIDER_X, y + 2, SLIDER_W, 1), rail)
	for k in steps + 1:
		draw_rect(Rect2(SLIDER_X + roundf(SLIDER_W * k / steps), y + 1, 1, 3), rail)
	var knob := SLIDER_X + roundf(SLIDER_W * (steps - lv) / steps)
	draw_rect(Rect2(SLIDER_X, y + 2, knob - SLIDER_X, 1), PAL["mauve"] if dim else PAL["gold"])
	draw_rect(Rect2(knob - 2, y - 1, 5, 7), PAL["night"])
	draw_rect(Rect2(knob - 1, y, 3, 5), PAL["mauve"] if dim else (PAL["lime"] if lv <= 0.0 else PAL["coral"]))


## For rows with many steps (PIXELS): a bar that empties from the right as it is sold.
func _draw_fill_bar(steps: int, lv: float, y: int) -> void:
	draw_rect(Rect2(SLIDER_X - 1, y, SLIDER_W + 2, 5), PAL["night"])
	draw_rect(Rect2(SLIDER_X, y + 1, SLIDER_W, 3), PAL["plum"])
	draw_rect(Rect2(SLIDER_X, y + 1, roundf(SLIDER_W * (steps - lv) / steps), 3), PAL["ice"])


## The self-sale's SOLD stamp: 2x, gold on wine, slammed over the row with a 1-frame overshoot.
func _draw_stamp(y: int) -> void:
	var s := 3 if _sold_t < 0.04 else 2
	var w := PixelFont.width("SOLD", s) + 8
	var box := Rect2(roundf(CX - w / 2.0), y + 2 - (PixelFont.H * s + 6) / 2.0, w, PixelFont.H * s + 6)
	draw_rect(box.grow(1), PAL["night"])
	draw_rect(box, PAL["wine"])
	_plain = true
	_centered("SOLD", CX, box.position.y + 3, PAL["gold"], PAL["wine"], s)
	_plain = false


## Under the rows: what the picked row costs and pays (YOU LOSE / YOU GET, or one line when it does not sell), the
## stat line with what the sale changes lit, and the key hint. Just after a sale: the result and the row's quip.
## Auto mode: the result, the quip and the blinking AUTO tag.
func _draw_footer(rows: Array) -> void:
	if _mode == "auto":
		if _sold_t >= 0.0:
			_plain = true
			_centered(_result, CX, QUIP_Y, PAL["gold"], PAL["dusk"])
			_centered(_quip_of(_target, int(_sale.get("step", 0))), CX, STAT_Y, PAL["stone"], PAL["dusk"])
			_plain = false
		if _blink():
			_plain = true
			var tag := "AUTO" if _blast <= 0 else "%s %d/%d" % [STORY.line("finale.blast_count", "BLAST"), _blast,
					maxi(_blast_of, _blast)] # each self-sale charges the blast (P8 B2)
			_centered(tag, CX, KEYS_Y, PAL["coral"], PAL["dusk"])
			_plain = false
		return
	var power := {}
	var refill := false
	if _sold_t >= 0.0:
		_centered(_result, CX, QUIP_Y, PAL["gold"], PAL["dusk"])
		var sold := String(_sale.get("id", ""))
		if sold != "" and not _sale.has("buy_back"): # the joke lands after the sale
			_centered(_quip_of(sold, int(_sale.get("step", 0))), CX, GET_Y, PAL["stone"], PAL["dusk"])
	elif _row >= rows.size():
		if _mode == "player" and _stock(_tab) == 0 and _has_later(_tab): # a padlocked tab: the cursor waits on SKIP
			_centered(_not_yet_line(), CX, QUIP_Y, PAL["stone"], PAL["dusk"])
		elif int(shop.back()["heal"]) > 0:
			_draw_trade(STORY.line("menu.skip.lose", "NOTHING."), "HEAL 1 HEART", [])
		else:
			_draw_trade(STORY.line("menu.skip.lose", "NOTHING."), STORY.line("menu.skip.no_heal", "NOTHING."), [])
	else:
		var id: String = rows[_row]
		if _buyable(id):
			_draw_trade(STORY.line("menu.buy_back.lose"), "%s %s %s" % [DATA.ROWS[id]["name"],
					DATA.value(id, shop.lv(id) - 1), STORY.line("menu.buy_back.get")], [])
		elif id == shop.bought_back:
			_centered(STORY.line("menu.buy_back.done", "BOUGHT BACK. POWER KEPT."), CX, QUIP_Y, PAL["stone"], PAL["dusk"])
		elif shop.row_state(id) == SHOP.RowState.SOLD_OUT:
			_centered("ALREADY SOLD.", CX, QUIP_Y, PAL["stone"], PAL["dusk"])
		elif shop.row_state(id) == SHOP.RowState.NOT_FOR_SALE:
			_centered(_not_yet_line(), CX, QUIP_Y, PAL["stone"], PAL["dusk"])
		else:
			power = DATA.step(id, shop.lv(id))["power"]
			refill = id == DATA.CONFIRM # it refills every heart, even with HEALING sold
			_draw_trade(_lose_of(id), shop.next_label(id), _form_tags(id))
	if _mode != "tutorial":
		_draw_stats(power, refill)
	var keys := "SPACE: SELL"
	if _mode == "player":
		keys = "LEFT RIGHT: TAB   UP DOWN: PICK   SPACE: " + ("SKIP" if _row >= rows.size() else "SELL")
		if _row < rows.size() and _buyable(rows[_row]):
			keys = "LEFT RIGHT: TAB   UP DOWN: PICK   " + STORY.line("menu.buy_back.key", "SPACE: BUY")
	_draw_keys_at(keys, HINT_Y)


## YOU LOSE: `lose`, then YOU GET: `get` and the first of `tags` that fits (the lantern form, gold).
func _draw_trade(lose: String, get: String, tags: Array) -> void:
	var x := _label(STORY.line("menu.lose", "YOU LOSE:"), QUIP_Y, PAL["coral"])
	_text(lose, x, QUIP_Y, PAL["cream"], PAL["dusk"])
	x = _label(STORY.line("menu.get", "YOU GET:"), GET_Y, PAL["lime"])
	_text(get, x, GET_Y, PAL["cream"], PAL["dusk"])
	x += PixelFont.width(_txt(get)) + 12
	for tag: String in tags:
		if x + PixelFont.width(_txt(tag)) <= TAG_END:
			_text(tag, x, GET_Y, PAL["gold"], PAL["dusk"])
			return


## A footer label at the left edge; returns the x its text starts at.
func _label(s: String, y: int, color: Color) -> float:
	_text(s, 24, y, color, PAL["dusk"])
	return 24.0 + PixelFont.width(_txt(s)) + 4


## What selling row `id` takes away, in plain words: lose.<id> (lose.<id>_2 for its second step), else its quip.
func _lose_of(id: String) -> String:
	var lv: int = shop.lv(id)
	var key := "lose." + id + ("_%d" % (lv + 1) if lv > 0 else "")
	return STORY.line(key, _quip_of(id, lv))


## The key hint, centred on one line: key names in cream, what they do in stone.
func _draw_keys_at(keys: String, y: int) -> void:
	var x := roundf(CX - PixelFont.width(_txt(keys)) / 2.0)
	for group: String in keys.split("   "):
		var colon := maxi(group.find(":"), 0)
		for piece: Array in [[group.substr(0, colon), PAL["cream"]], [group.substr(colon), PAL["stone"]]]:
			var s: String = piece[0]
			if s != "":
				_text(s, x, y, piece[1], PAL["dusk"])
				x += PixelFont.width(_txt(s)) + 1
		x += 3 * (PixelFont.W + 1)


## Why nothing here sells: NOT FOR SALE YET., plus TRY ANOTHER TAB. when another tab has stock.
func _not_yet_line() -> String:
	var line := STORY.line("menu.not_yet", "NOT FOR SALE YET.")
	for t in _nav:
		if t != _tab and _stock(t) > 0:
			return line + " " + STORY.line("menu.try_tab", "TRY ANOTHER TAB.")
	return line


## The quip of step `step` of row `id`: STORY.md's line where it has one (it owns the text), else the table's.
func _quip_of(id: String, step: int) -> String:
	if not id in DATA.ROWS or step >= DATA.steps(id):
		return ""
	var fallback := String(DATA.step(id, step)["quip"])
	var key := "quip." + id
	if id == DATA.CONFIRM:
		key = "finale.confirm_quip"
	elif id == "colour":
		key = "quip.colour_4" if step == 0 else "quip.colour_2"
	elif id == "resolution":
		key = "quip.resolution_half" if step == 0 else "quip.resolution_quarter"
	return STORY.line(key, fallback)


## Hearts, damage, fire rate, speed, shots and pierce on one line, centred; each stat `power` would change is lit
## lime as old > new. Past STAT_W the unchanged stats drop from the right, then lit stats show just the new value.
## `refill`: the sale refills every heart (CONFIRM SALES). Nothing without a run.
func _draw_stats(power: Dictionary, refill := false) -> void:
	if run == null or run.prog == null or run.player == null:
		return
	var prog = run.prog
	var after: Dictionary = prog.preview(power)
	var hp: int = run.player.hp
	var top: int = run.player.max_hp
	var more := int(power.get("hearts", 0))
	var fire := 1.0 / maxf(prog.fire_interval(), 0.01)
	var stats := [ # [name, now, after the sale, lit]
		["HEARTS", "%d/%d" % [hp, top], "%d/%d" % [top + more if refill else hp + (more if shop.lv("healing") == 0 else 0),
				top + more], more > 0 or (refill and hp < top)],
		["DAMAGE", _pct(prog.mult["damage"]), _pct(after["mult"]["damage"]), power.has("damage")],
		["FIRE", "%.1f/S" % fire, "%.1f/S" % (fire * after["mult"]["fire"] / prog.mult["fire"]), power.has("fire")],
		["SPEED", _pct(prog.mult["speed"]), _pct(after["mult"]["speed"]), power.has("speed")],
		["SHOTS", str(prog.shots), str(after["shots"]), power.has("shots")],
		["PIERCE", str(prog.pierce), str(after["pierce"]), power.has("pierce")],
	]
	while _stat_line(stats, true, 0.0, false) > STAT_W:
		var spare := stats.filter(func(s: Array) -> bool: return not s[3])
		if spare.is_empty():
			break
		stats.erase(spare[-1])
	var both := _stat_line(stats, true, 0.0, false) <= STAT_W
	_stat_line(stats, both, roundf(CX - _stat_line(stats, both, 0.0, false) / 2.0), true)


## Lays the stat line out from `x` (drawing it if `draw`); returns its width. `both`: lit stats show old > new.
func _stat_line(stats: Array, both: bool, x: float, draw: bool) -> float:
	var start := x
	for s: Array in stats:
		var pieces := [[s[0] + " " + s[1], PAL["sky"]]]
		if s[3]:
			pieces = [[s[0] + " ", PAL["sky"]], [s[1], PAL["stone"]], [">", PAL["lime"]], [s[2], PAL["lime"]]]
			if not both:
				pieces = [[s[0] + " ", PAL["sky"]], [s[2], PAL["lime"]]]
		for p: Array in pieces:
			if p[0] == ">":
				if draw:
					_draw_arrow(x + 3, PREVIEW_Y, p[1])
				x += 9
				continue
			if draw:
				_text(p[0], x, PREVIEW_Y, p[1], PAL["dusk"])
			x += PixelFont.width(_txt(p[0])) + 1
		x += 5
	return x - start - 6


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## Pixels mode (design 10.4, 13): the compact panel, plain English. PIXELS with its bar, value and reward; after 5
## presses AUTO-SELL; a rule; the quip; the stat line (damage climbs with each press); the keys.
func _draw_pixels_panel() -> void:
	_plain = true
	_draw_panel(PIXEL_PANEL)
	var rows := _rows()
	for i in rows.size():
		var y := PIXEL_ROW_Y + i * PIXEL_ROW_GAP
		var band := _pixel_band(i, y)
		var ink: Color = PAL["night"] if band == PAL["cream"] else PAL["cream"]
		var hot := band != PAL["dusk"]
		if rows[i] == AUTO_ROW:
			_text(STORY.line("menu.pixels.auto", "AUTO-SELL"), PIXEL_NAME_X, y, ink, band)
			_text(STORY.line("menu.pixels.auto_note", "THE REST SELL THEMSELVES"), VALUE_X, y,
				ink if hot else PAL["stone"], band)
			continue
		_text(DATA.ROWS[DATA.PIXELS]["name"], PIXEL_NAME_X, y, ink, band)
		_draw_fill_bar(DATA.PIXEL_STEPS, float(shop.lv(DATA.PIXELS)), y)
		_text(shop.value_text(DATA.PIXELS), VALUE_X, y, ink, band)
		if not shop.sold_out(DATA.PIXELS):
			_text(shop.next_label(DATA.PIXELS), POWER_X, y, ink if hot else PAL["lime"], band)
	draw_rect(Rect2(PIXEL_PANEL.position.x + 10, PIXEL_RULE_Y, PIXEL_PANEL.size.x - 20, 1), PAL["mauve"])
	var quip := _line if _line != "" else STORY.line("finale.pixels", "ONE SETTING LEFT. IT IS THE SCREEN.")
	var quip_ink: Color = PAL["stone"]
	if _sold_t >= 0.0:
		quip = _result
		quip_ink = PAL["gold"]
	elif cursor_id() == AUTO_ROW:
		quip = STORY.line("menu.pixels.auto_quip", "KEEP FIGHTING. THE SCREEN SELLS ITSELF.")
	elif _press_t >= 0.0:
		quip = _result
		quip_ink = PAL["gold"] if _press_t < PIXEL_GOLD else PAL["stone"]
	_centered(quip, CX, PIXEL_QUIP_Y, quip_ink, PAL["dusk"])
	_centered(_pixel_stat_text(), CX, PIXEL_STAT_Y, PAL["sky"], PAL["dusk"])
	var keys := STORY.line("menu.pixels.sell_key", "SPACE: SELL 1%")
	if rows.size() > 1: # the pick key as in player mode (Up always works in menus)
		keys = "UP DOWN: PICK   " + (STORY.line("menu.pixels.auto_key", "SPACE: AUTO-SELL") if cursor_id() == AUTO_ROW
			else keys)
	_draw_keys_at(keys, PIXEL_KEYS_Y)
	_plain = false


## The panel's row highlight: plum under the cursor, cream for 2 frames on a press; returns its colour.
func _pixel_band(row: int, y: int) -> Color:
	var band: Color = PAL["dusk"]
	if row == _row:
		var flash := (_press_t >= 0.0 and _press_t < PIXEL_FLASH) or (_sold_t >= 0.0 and int(_sold_t * 10.0) % 2 == 0)
		band = PAL["cream"] if flash else PAL["plum"]
	var x := PIXEL_PANEL.position.x + 4
	if band != PAL["dusk"]:
		draw_rect(Rect2(x, y - 2, PIXEL_PANEL.size.x - 8, 9), band)
	if row == _row and band == PAL["plum"]:
		draw_rect(Rect2(x, y, 1, 5), PAL["gold"])
		draw_rect(Rect2(x + 1, y + 1, 1, 3), PAL["gold"])
		draw_rect(Rect2(x + 2, y + 2, 1, 1), PAL["gold"])
	return band


## The panel's stat line: the powers each press raises (the full line is wider than the panel).
func _pixel_stat_text() -> String:
	if run == null or run.prog == null:
		return ""
	var prog = run.prog
	return "DAMAGE %d%%  FIRE %.1f/S  SHOTS %d  PIERCE %d" % [roundi(prog.mult["damage"] * 100.0),
			1.0 / maxf(prog.fire_interval(), 0.01), prog.shots, prog.pierce]


## Pixels mode: rows the panel shows (1, or 2 once AUTO-SELL is offered).
func _pixel_rows() -> int:
	return _rows().size() if _mode == "pixels" else 0


## The PIXELS countdown toast, top centre: a quiet box that reads on the dying screen.
func _draw_toast() -> void:
	var w := PixelFont.width(_toast) + 10
	var box := Rect2(roundf(CX - w / 2.0), 4, w, 11)
	draw_rect(box, PAL["deep"])
	draw_rect(box.grow(-1), PAL["void"])
	_centered(_toast, CX, 7, PAL["ice"], PAL["void"])


# --- helpers -----------------------------------------------------------------------------------------------------

func _draw_panel(r: Rect2) -> void:
	draw_rect(r, PAL["night"])
	draw_rect(r.grow(-1), PAL["dusk"])
	draw_rect(r.grow(-3), PAL["mauve"])
	draw_rect(r.grow(-4), PAL["dusk"])


## A 5x6 padlock with its top-left at `at`; `open` lifts the shackle off one side (cracked).
func _draw_padlock(at: Vector2, color: Color, open: bool) -> void:
	for r in PADLOCK:
		var piece := r
		if open and r.position.y < 3:
			piece.position += Vector2(1 if r.position.x > 0 else 0, -1)
		draw_rect(Rect2(at + piece.position, piece.size), color)
	draw_rect(Rect2(at + Vector2(2, 4), Vector2(1, 1)), PAL["night"])


func _blink() -> bool:
	return fmod(_t, 0.5) < 0.3


func _txt(s: String) -> String:
	return s if _plain or shop == null else shop.txt(s)


func _text(s: String, x: float, y: float, color: Color, outline: Color, scale := 1) -> void:
	draw_text_at(self, _txt(s), Vector2(roundf(x), roundf(y)), color, outline, scale)


func _centered(s: String, center_x: float, y: float, color: Color, outline: Color, scale := 1) -> void:
	var w := PixelFont.width(_txt(s), scale)
	_text(s, roundf(center_x - w / 2.0), y, color, outline, scale)


func _right(s: String, right: float, y: float, color: Color) -> void:
	_text(s, right - PixelFont.width(_txt(s)), y, color, PAL["dusk"])


## PixelFont.draw plus the "%" glyph the font lacks (shared with the HUD).
static func draw_text_at(ci: CanvasItem, shown: String, pos: Vector2, color: Color, outline: Color, scale := 1) -> void:
	PixelFont.draw(ci, shown, pos, color, outline, scale)
	for i in shown.length():
		if shown[i] != "%":
			continue
		var at := pos + Vector2(i * (PixelFont.W + 1) * scale, 0)
		for offset in PixelFont.OUTLINE:
			_percent(ci, at + offset * scale, outline, scale)
		_percent(ci, at, color, scale)


static func _percent(ci: CanvasItem, at: Vector2, color: Color, scale: int) -> void:
	for p in PERCENT:
		ci.draw_rect(Rect2(at + p * scale, Vector2(scale, scale)), color)
