extends RefCounted
## Shop state and rules (design 9.1): levels, tab and row states, sell, back, BUY BACK (design 9.4), the finale
## queue, LANGUAGE (it wears off: menus are counted through mark_seen, which settings_menu.open calls once per menu
## of every mode).

enum TabState { HIDDEN, LOCKED, OPEN }
enum RowState { OPEN, SOLD_OUT, NOT_FOR_SALE }

const DATA := preload("res://scripts/game/shop/shop_data.gd")
const ALPHA := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var levels := {} ## row id -> steps sold
var advanced := false ## the ADVANCED tab is revealed (the forced CONFIRM menu opened)
var last_tab := -1 ## the tab of the last player sale (the next menu opens on it if it has stock)
var seen: Array[int] = [] ## tabs some menu has shown (a tab flashes NEW the first time)
var lang_menus := 0 ## menus opened since LANGUAGE was sold
var lang_worn := false ## LANGUAGE wore off: English is back, the row stays SOLD OUT and keeps its +1 SHOT
var bought_back := "" ## the row BUY BACK returned this run ("" = unused; once per run, the row is closed for good)
var buy_back_seen := false ## a menu has offered BUY BACK (settings_menu.open sets it; the first offer blinks)


## Nothing sold.
func reset() -> void:
	levels = {}
	advanced = false
	last_tab = -1
	seen = []
	lang_menus = 0
	lang_worn = false
	bought_back = ""
	buy_back_seen = false


## Steps sold of row `id`.
func lv(id: String) -> int:
	return levels.get(id, 0)


## TabState of tab index `t` at player level `level`.
func tab_state(t: int, level: int) -> int:
	if t == DATA.ADVANCED_TAB:
		return TabState.OPEN if advanced or closing() else TabState.HIDDEN
	return TabState.OPEN if level >= int(DATA.TABS[t]["unlock"]) else TabState.LOCKED


## RowState of row `id` (NOT_FOR_SALE: a beauty row before CONFIRM SALES).
func row_state(id: String) -> int:
	if sold_out(id):
		return RowState.SOLD_OUT
	if id == DATA.CONFIRM:
		return RowState.OPEN if advanced else RowState.NOT_FOR_SALE
	if id == DATA.PIXELS:
		return RowState.OPEN if closing() and finale_queue().is_empty() else RowState.NOT_FOR_SALE
	if DATA.ROWS[id]["beauty"] and not closing():
		return RowState.NOT_FOR_SALE
	return RowState.OPEN


## Tab indices the menu shows at `level` (locked tabs too: they show dimmed with "LV n").
func menu_tabs(level: int) -> Array[int]:
	var out: Array[int] = []
	for t in DATA.TABS.size():
		if tab_state(t, level) != TabState.HIDDEN:
			out.append(t)
	return out


## Sells the next step of `id`: {} if refused, else {id, step, value, power, quip, label, auto}.
func sell(id: String, auto := false) -> Dictionary:
	if not DATA.ROWS.has(id) or row_state(id) != RowState.OPEN:
		return {}
	var i := lv(id)
	var s := DATA.step(id, i)
	levels[id] = i + 1
	if not auto:
		last_tab = DATA.tab_of(id)
	_count_choice(id)
	return {"id": id, "step": i, "value": s["value"], "power": s["power"], "quip": s["quip"],
			"label": DATA.label(s["power"]), "auto": auto}


## LANGUAGE's wear rule for a menu's one choice of row `id` (a sale of any mode, or a buy back): selling LANGUAGE
## starts the count; a choice in the 2nd menu after it ends it.
func _count_choice(id: String) -> void:
	if id == "language":
		lang_menus = 0
		lang_worn = false
	elif language_on() and lang_menus >= DATA.LANGUAGE_MENUS:
		lang_worn = true


## True while player menus offer BUY BACK: 11 early steps sold, not used yet, before the forced CONFIRM menu.
func buy_back_open() -> bool:
	return bought_back == "" and not advanced and not closing() and early_sold() >= DATA.BUY_BACK_AFTER


## True when row `id` can be bought back now: a sold-out BUY_BACK_ROWS row (DIFFICULTY at HARD still sells CRUEL
## first, so SPACE on a row with a step left always sells).
func can_buy_back(id: String) -> bool:
	return buy_back_open() and DATA.BUY_BACK_ROWS.has(id) and lv(id) > 0 and sold_out(id)


## BUY BACK: returns one step of `id` (power kept) and closes the row for good. {} if refused, else
## {id, step (the step returned), value (the restored value), power {}, quip "", label "", auto false,
## buy_back true, name}.
func buy_back(id: String) -> Dictionary:
	if not can_buy_back(id):
		return {}
	levels[id] = lv(id) - 1
	bought_back = id
	_count_choice(id)
	return {"id": id, "step": lv(id), "value": DATA.value(id, lv(id)), "power": {}, "quip": "", "label": "",
			"auto": false, "buy_back": true, "name": DATA.ROWS[id]["name"]}


## BACK: keeps everything; {heal: 1}, or {heal: 0} once HEALING is sold.
func back() -> Dictionary:
	return {"heal": 0 if lv("healing") > 0 else 1}


## True when the forced ADVANCED menu is due (18 early steps done, or past FINALE_DEADLINE).
func advanced_due(_level: int, run_time: float) -> bool:
	if closing():
		return false
	return early_done() >= DATA.early_steps() or run_time >= DATA.FINALE_DEADLINE


## Reveals ADVANCED (the forced menu calls it when it opens).
func reveal_advanced() -> void:
	advanced = true


## True once CONFIRM SALES is sold.
func closing() -> bool:
	return lv(DATA.CONFIRM) > 0


## Self-sale queue: CLEARANCE rows first, then FINALE_ORDER entries not yet sold.
func finale_queue() -> Array[String]:
	var out: Array[String] = []
	for id in DATA.early_rows():
		if id == bought_back:
			continue # closed for good: CLEARANCE skips it
		for k in range(lv(id), DATA.steps(id)):
			out.append(id)
	var count := {}
	for id in DATA.FINALE_ORDER:
		count[id] = int(count.get(id, 0)) + 1
		if lv(id) < count[id]:
			out.append(id)
	return out


## True while LANGUAGE scrambles text: from its sale until the 2nd menu opened after it ends (design 9.3).
func language_on() -> bool:
	return lv("language") > 0 and not lang_worn


## `s` through LANGUAGE (CIPHER while it lasts), else unchanged.
func txt(s: String) -> String:
	if not language_on():
		return s
	var out := ""
	for c in s:
		var i := ALPHA.find(c)
		out += DATA.CIPHER[i] if i >= 0 else c
	return out


## Row `id`'s current value text (ON, OFF, 60 FPS...).
func value_text(id: String) -> String:
	if id == "language" and lang_worn:
		return DATA.LANGUAGE_BACK
	return DATA.value(id, lv(id))


## The reward label of row `id`'s next step ("" once sold out; NOT FOR SALE rows still show their price).
func next_label(id: String) -> String:
	return "" if sold_out(id) else DATA.label(DATA.step(id, lv(id))["power"])


## The quip of row `id`'s next step ("" once sold out).
func next_quip(id: String) -> String:
	return "" if sold_out(id) else String(DATA.step(id, lv(id))["quip"])


## Player sales so far, of 19 (the 18 early steps and CONFIRM SALES).
func sold_count() -> int:
	return early_sold() + mini(lv(DATA.CONFIRM), 1)


## Early steps sold, of DATA.early_steps() (18).
func early_sold() -> int:
	var n := 0
	for id in DATA.early_rows():
		n += mini(lv(id), DATA.steps(id))
	return n


## Early steps done, for pacing (advanced_due): early_sold() plus the bought-back row's unsold steps.
func early_done() -> int:
	if bought_back == "":
		return early_sold()
	return early_sold() + DATA.steps(bought_back) - mini(lv(bought_back), DATA.steps(bought_back))


## True when row `id` has no step left (a bought-back row has none for good).
func sold_out(id: String) -> bool:
	return lv(id) >= DATA.steps(id) or (bought_back != "" and id == bought_back)


## True when tab `t` has a row the player can sell now.
func has_stock(t: int) -> bool:
	for id: String in DATA.TABS[t]["rows"]:
		if row_state(id) == RowState.OPEN:
			return true
	return false


## The tab the next player menu opens on at `level` (design 9.1): a tab no menu has shown yet that has stock,
## else the last tab used if it has stock, else the first open tab with stock (-1: nothing to sell).
func pick_tab(level: int) -> int:
	var open := menu_tabs(level).filter(func(t: int) -> bool:
		return tab_state(t, level) == TabState.OPEN and t != DATA.ADVANCED_TAB)
	for t: int in open:
		if not t in seen and has_stock(t):
			return t
	if last_tab in open and has_stock(last_tab):
		return last_tab
	for t: int in open:
		if has_stock(t):
			return t
	return -1


## Tabs shown at `level` that no menu has shown yet and that have a row to sell now (they flash NEW; AUDIO, all
## NOT FOR SALE when it appears, doesn't).
func new_tabs(level: int) -> Array[int]:
	var out: Array[int] = []
	for t in menu_tabs(level):
		if tab_state(t, level) == TabState.OPEN and not t in seen and has_stock(t):
			out.append(t)
	return out


## Remembers that a menu showed these tabs; settings_menu.open calls it once per menu, so it also counts the
## menus LANGUAGE has left: one closed with BACK in the 2nd menu ends it as the 3rd opens.
func mark_seen(tabs: Array[int]) -> void:
	if language_on():
		lang_menus += 1
		if lang_menus > DATA.LANGUAGE_MENUS:
			lang_worn = true
	for t in tabs:
		if not t in seen:
			seen.append(t)


## Percent of the screen still alive (100 - PIXELS sold).
func pixels_left() -> int:
	return DATA.PIXEL_STEPS - lv(DATA.PIXELS)
