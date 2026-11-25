class_name LxJournal
extends Node2D
## Pause-menu & Hub Desk Journal (SPEC 3.6):
## 4 icon-driven pages: Quests (icon steps + place to go + pin), Moths (8x10 pips + 2-visit hint icon),
## Bestiary (all 60+ pack enemies, idle sprite + seen/defeated + weakness), Toys (move icon + unlock state).

signal closed()

enum Page { QUESTS, MOTHS, BESTIARY, TOYS }

const PANEL_RECT := Rect2(14.0, 11.0, 292.0, 161.0)
const CONTENT_RECT := Rect2(22.0, 44.0, 276.0, 108.0)
const TAB_KEYS: Array[String] = [
	"JOURNAL_TAB_QUESTS",
	"JOURNAL_TAB_MOTHS",
	"JOURNAL_TAB_BESTIARY",
	"JOURNAL_TAB_TOYS",
]
const TAB_ICONS: Array[String] = ["book", "moth", "skull", "gear"]

var current_page: int = Page.QUESTS
var _sel: int = 0
var _scroll: int = 0
var _elapsed: float = 0.0
var _close_hover: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func close() -> void:
	visible = false


func open(start_page: int = Page.QUESTS) -> void:
	current_page = clampi(start_page, Page.QUESTS, Page.TOYS)
	_sel = clampi((Lx.state.island_id - 1) if (current_page == Page.MOTHS and Lx.state != null and Lx.state.island_id > 0) else 0, 0, maxi(0, _count_for_page() - 1))
	_scroll = 0
	_elapsed = 0.0
	visible = true
	_play_sfx("menu_open")
	queue_redraw()


func set_page(p: int) -> void:
	var np: int = clampi(p, Page.QUESTS, Page.TOYS)
	if np != current_page:
		current_page = np
		_sel = clampi((Lx.state.island_id - 1) if (current_page == Page.MOTHS and Lx.state != null and Lx.state.island_id > 0) else 0, 0, maxi(0, _count_for_page() - 1))
		_scroll = 0
		_play_sfx("ui_move")
		queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if LxUiNav.handle_tab_bar_key(event, 13):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var oc: bool = _close_btn_rect().has_point(pos)
		if oc != _close_hover:
			_close_hover = oc
			if oc: _play_sfx("ui_move")
			queue_redraw()
		var hi: int = LxJournalPages.hit_test_item(current_page, CONTENT_RECT, pos, _scroll)
		if hi >= 0 and hi != _sel and hi < _count_for_page():
			_sel = hi
			_play_sfx("ui_move")
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if LxUiNav.handle_tab_bar_click(mb.position, 13):
				get_viewport().set_input_as_handled()
				return
			if _close_btn_rect().has_point(mb.position):
				_play_sfx("menu_close")
				closed.emit()
				get_viewport().set_input_as_handled()
				return
			for ti: int in range(TAB_KEYS.size()):
				if _tab_rect(ti).has_point(mb.position):
					set_page(ti)
					get_viewport().set_input_as_handled()
					return
			var ci: int = LxJournalPages.hit_test_item(current_page, CONTENT_RECT, mb.position, _scroll)
			if ci >= 0 and ci < _count_for_page():
				_sel = ci
				if current_page == Page.QUESTS:
					_pin_selected_quest()
				else:
					_play_sfx("ui_move")
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_sfx("menu_close")
			closed.emit()
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_step_scroll(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause") or _key_just(event, KEY_ESCAPE):
		_play_sfx("menu_close")
		closed.emit()
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_Q) or _key_just(event, KEY_PAGEUP) or _joy_btn(event, JOY_BUTTON_LEFT_SHOULDER):
		set_page((current_page - 1 + TAB_KEYS.size()) % TAB_KEYS.size())
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_E) or _key_just(event, KEY_TAB) or _key_just(event, KEY_PAGEDOWN) or _joy_btn(event, JOY_BUTTON_RIGHT_SHOULDER):
		set_page((current_page + 1) % TAB_KEYS.size())
		get_viewport().set_input_as_handled()
	elif (_key_just(event, KEY_P) or _joy_btn(event, JOY_BUTTON_Y)) and current_page == Page.QUESTS:
		_pin_selected_quest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
		if current_page == Page.QUESTS:
			set_page((current_page - 1 + TAB_KEYS.size()) % TAB_KEYS.size())
		else:
			_move_item(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
		if current_page == Page.QUESTS:
			set_page((current_page + 1) % TAB_KEYS.size())
		else:
			_move_item(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_move_item(-_cols_for_page())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_move_item(_cols_for_page())
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE)) and current_page == Page.QUESTS:
		_pin_selected_quest()
		get_viewport().set_input_as_handled()


func _pin_selected_quest() -> void:
	var list: Array[Dictionary] = LxQuests.current().all_quests()
	if _sel < 0 or _sel >= list.size():
		return
	var q: Dictionary = list[_sel]
	var qid: String = str(q.get("id", ""))
	var place: Dictionary = LxUiNav.resolve_quest_place(q)
	LxUiNav.toggle_pin({
		"island": int(place.get("island", int(q.get("island", 1)))),
		"id": "quest:" + qid,
		"kind": "folk",
		"region": str(place.get("region", "overworld")),
		"icon": str(q.get("icon", "book")),
		"label": str(place.get("label", "")),
	})
	_play_sfx("ui_confirm")
	queue_redraw()


func _cols_for_page() -> int:
	match current_page:
		Page.MOTHS: return 2
		Page.BESTIARY: return 3
		Page.TOYS: return 4
		_: return 1


func _vis_rows_for_page() -> int:
	match current_page:
		Page.QUESTS: return 5
		Page.MOTHS: return 4
		Page.BESTIARY, Page.TOYS: return 3
		_: return 1


func _count_for_page() -> int:
	match current_page:
		Page.QUESTS: return LxQuests.current().all_quests().size()
		Page.MOTHS: return 8
		Page.BESTIARY: return LxEnemyFactory.known_kinds().size()
		Page.TOYS: return LxFolkData.toys_catalog().size()
		_: return 0


func _move_item(delta: int) -> void:
	var n: int = _count_for_page()
	if n <= 0:
		return
	_sel = clampi(_sel + delta, 0, n - 1)
	var cols: int = _cols_for_page()
	var vis_r: int = _vis_rows_for_page()
	var row: int = _sel / cols
	if row < _scroll:
		_scroll = row
	elif row >= _scroll + vis_r:
		_scroll = row - vis_r + 1
	_play_sfx("ui_move")
	queue_redraw()


func _step_scroll(delta: int) -> void:
	var n: int = _count_for_page()
	if n <= 0:
		return
	var cols: int = _cols_for_page()
	var max_s: int = maxi(0, ceili(float(n) / float(cols)) - _vis_rows_for_page())
	_scroll = clampi(_scroll + delta, 0, max_s)
	queue_redraw()


func _draw() -> void:
	var isl: int = clampi(Lx.state.island_id if Lx.state != null else 1, 1, 8)
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", LxBiomePalette.key(isl, "border"), "night")
	for rv: Vector2 in [
		Vector2(17.0, 14.0), Vector2(301.0, 14.0),
		Vector2(17.0, 167.0), Vector2(301.0, 167.0),
	]:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), LxPalette.PAL["apricot"])
		draw_rect(Rect2(rv, Vector2.ONE), LxPalette.PAL["gold"])
	LxUiNav.draw_pause_tab_bar(self, 13)

	LxPixelFont.draw_left(self, LxFolkData.tr_id("JOURNAL_TITLE"), Vector2(24.0, 16.0), LxPalette.PAL["gold"], 1)
	var pct: int = Lx.state.get_completion_pct() if Lx.state != null else 0
	LxPixelFont.draw_right(self, LxFolkData.fmt_id("MAP_COMPLETION_FMT", [pct]), 296.0, 16.0, LxPalette.PAL["cream"], 1)

	for ti: int in range(TAB_KEYS.size()):
		var tr: Rect2 = _tab_rect(ti)
		var active_t: bool = ti == current_page
		LxPixelFont.draw_panel(self, tr, "plum" if active_t else "night", "gold" if active_t else "dusk", "void")
		LxBubble.draw_icon(self, TAB_ICONS[ti], tr.position + Vector2(4.0, 3.0), 1.0)
		LxPixelFont.draw_left(self, LxFolkData.tr_id(TAB_KEYS[ti]), tr.position + Vector2(16.0, 5.0), LxPalette.PAL["gold"] if active_t else LxPalette.PAL["stone"], 1)

	LxPixelFont.draw_panel(self, CONTENT_RECT, "void", "dusk", "night")
	match current_page:
		Page.QUESTS: LxJournalPages.draw_quests(self, CONTENT_RECT, _sel, _scroll)
		Page.MOTHS: LxJournalPages.draw_moths(self, CONTENT_RECT, _sel)
		Page.BESTIARY: LxJournalPages.draw_bestiary(self, CONTENT_RECT, _sel, _scroll, _elapsed)
		Page.TOYS: LxJournalPages.draw_toys(self, CONTENT_RECT, _sel, _scroll)

	LxPixelFont.draw_left(self, LxFolkData.tr_id("JOURNAL_HINT"), Vector2(22.0, 160.0), LxPalette.PAL["stone"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxFolkData.tr_id("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)


func _tab_rect(ti: int) -> Rect2:
	return Rect2(22.0 + float(ti) * 70.0, 26.0, 66.0, 15.0)


func _close_btn_rect() -> Rect2:
	return Rect2(242.0, 158.0, 56.0, 11.0)


func _play_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _joy_btn(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
