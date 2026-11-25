class_name LxTollMenu
extends CanvasLayer
## "THE LANTERN ASKS" — Island 8 Toll Menu UI (the settings menu as a building).
## Callback to the jam game's Settings Shop, rebuilt in Luxel 1.0's Last Light 20-colour craft.
## Renders on CanvasLayer 15 (ABOVE LxSoldFx layer 7 and LxUiRoot layer 10) so the ledger
## always remains sharp and readable even when palette_4, fps_step, or display_pixels are sold.
## Esc ALWAYS closes/cancels (Sacred Unsellables law).

signal closed(result: Dictionary)
signal trade_completed(action: String, setting_id: String, mode: String)

const PAL: Dictionary = LxPalette.PAL
const VIEW_W: float = 320.0
const VIEW_H: float = 180.0
const PANEL_RECT := Rect2(14.0, 10.0, 292.0, 160.0)
const LIST_Y: float = 46.0
const ROW_H: float = 18.0
const MAX_ROWS_VISIBLE: int = 4

const TABS: Array[String] = ["INTERFACE", "FEEL", "BEAUTY"]

static var active_instance: LxTollMenu = null

var _canvas: Node2D = null
var _open: bool = false
var _mode: String = "shop" # "shop" | "gate" | "redemption" | "boon_toll" | "invoice" | "finale_pixels"
var _min_weight: int = 1
var _source_id: String = ""
var _source_pos: Vector2 = Vector2.ZERO
var _boss_id: String = ""
var _tab_idx: int = 0
var _row_idx: int = 0
var _rows: Array[Dictionary] = []
var _feedback_text: String = ""
var _feedback_col: Color = Color.WHITE
var _feedback_t: float = 0.0
var _clock: float = 0.0
var _prev_paused: bool = false
var _pause_world: bool = false
var _last_trade_id: String = ""
var _last_trade_action: String = ""


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	active_instance = self
	_canvas = Node2D.new()
	_canvas.name = "TollLedgerCanvas"
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.visible = false
	_canvas.draw.connect(_draw_ledger)
	add_child(_canvas)


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null
	if _open and _pause_world and get_tree() != null:
		get_tree().paused = _prev_paused


func is_open() -> bool:
	return _open


func get_mode() -> String:
	return _mode


func get_rows() -> Array[Dictionary]:
	return _rows.duplicate(true)


func get_selected_id() -> String:
	if _row_idx >= 0 and _row_idx < _rows.size():
		return str(_rows[_row_idx].get("id", ""))
	return ""


func open(opts: Dictionary = {}) -> void:
	_mode = str(opts.get("mode", "shop")).strip_edges().to_lower()
	_min_weight = maxi(1, int(opts.get("min_weight", 1)))
	_source_id = str(opts.get("source_id", ""))
	_source_pos = opts.get("source_pos", Vector2.ZERO) as Vector2
	_boss_id = str(opts.get("boss_id", ""))
	_pause_world = bool(opts.get("pause_world", true))
	_last_trade_id = ""
	_last_trade_action = ""
	_feedback_text = ""
	_feedback_t = 0.0
	_tab_idx = clampi(int(opts.get("tab_idx", 0)), 0, TABS.size() - 1)
	_row_idx = 0
	_rebuild_rows()
	_open = true
	if _canvas != null:
		_canvas.visible = true
		_canvas.queue_redraw()
	if LxSoldFx.active_instance != null and is_instance_valid(LxSoldFx.active_instance):
		LxSoldFx.active_instance.set_modal_suppressed(true)
	if _pause_world and get_tree() != null:
		_prev_paused = get_tree().paused
		get_tree().paused = true
	_play_ui_sfx("menu_open")


func close() -> void:
	if not _open:
		return
	_open = false
	if _canvas != null:
		_canvas.visible = false
	if LxSoldFx.active_instance != null and is_instance_valid(LxSoldFx.active_instance):
		LxSoldFx.active_instance.set_modal_suppressed(false)
	if _pause_world and get_tree() != null:
		get_tree().paused = _prev_paused
	_play_ui_sfx("menu_close")
	closed.emit({
		"mode": _mode,
		"source_id": _source_id,
		"action": _last_trade_action,
		"setting_id": _last_trade_id,
		"paid": not _last_trade_id.is_empty(),
	})


func select_tab(idx: int) -> void:
	if _mode == "redemption" or _mode == "finale_pixels":
		return
	var next: int = posmod(idx, TABS.size())
	if next == _tab_idx:
		return
	_tab_idx = next
	_row_idx = 0
	_rebuild_rows()
	_play_ui_sfx("ui_move")
	if _canvas != null:
		_canvas.queue_redraw()


func select_setting(setting_id: String) -> bool:
	var target: String = setting_id.strip_edges().to_lower()
	if _mode != "redemption" and _mode != "finale_pixels":
		for ti: int in range(TABS.size()):
			var list: Array[Dictionary] = LxSold.current().list_settings(TABS[ti], false)
			for ri: int in range(list.size()):
				if str(list[ri].get("id", "")) == target:
					_tab_idx = ti
					_rebuild_rows()
					_row_idx = ri
					if _canvas != null:
						_canvas.queue_redraw()
					return true
	for ri: int in range(_rows.size()):
		if str(_rows[ri].get("id", "")) == target:
			_row_idx = ri
			if _canvas != null:
				_canvas.queue_redraw()
			return true
	return false


func confirm_selected() -> bool:
	if not _open or _rows.is_empty():
		return false
	var sold: LxSold = LxSold.current()
	var row: Dictionary = _rows[clampi(_row_idx, 0, _rows.size() - 1)]
	var sid: String = str(row.get("id", ""))

	if _mode == "finale_pixels":
		if sid == "sell_display":
			sold.apply_hush_finale_choice("display")
			_last_trade_id = "display_pixels"
			_last_trade_action = "sell"
			_play_ui_sfx("setting_sold_visual")
			_play_ui_sfx("toll_coin_clink")
			trade_completed.emit("sell", "display_pixels", _mode)
			close()
			return true
		else:
			sold.apply_hush_finale_choice("keep")
			_last_trade_id = "keep_display"
			_last_trade_action = "keep"
			_play_ui_sfx("toll_coin_clink")
			trade_completed.emit("keep", "keep_display", _mode)
			close()
			return true

	if _mode == "redemption":
		if sold.redeem(sid):
			_last_trade_id = sid
			_last_trade_action = "redeem"
			_set_feedback(LxStrings.text("ISL8_TOLL_REDEEMED"), PAL["lime"] as Color)
			_play_ui_sfx("toll_coin_clink")
			trade_completed.emit("redeem", sid, _mode)
			_rebuild_rows()
			close()
			return true
		_set_feedback(LxStrings.text("ISL8_TOLL_USED"), PAL["coral"] as Color)
		_play_ui_sfx("ui_back")
		return false

	if not sold.can_sell(sid):
		_set_feedback(LxStrings.text("ISL8_TOLL_ALREADY_SOLD"), PAL["coral"] as Color)
		_play_ui_sfx("ui_back")
		return false

	var ok: bool = sold.sell(sid, {"source_pos": _source_pos, "save": true})
	if not ok:
		_play_ui_sfx("ui_back")
		return false
	_last_trade_id = sid
	_last_trade_action = "sell"
	_set_feedback(LxStrings.text("ISL8_TOLL_SOLD_OK"), PAL["gold"] as Color)
	_play_ui_sfx(_sold_sfx_for(sid, str(row.get("tab", ""))))
	_play_ui_sfx("toll_coin_clink")
	trade_completed.emit("sell", sid, _mode)
	_rebuild_rows()
	if _mode in ["gate", "boon_toll", "invoice"]:
		if _mode != "gate" or sold.get_toll_weight() >= _min_weight:
			close()
	elif _canvas != null:
		_canvas.queue_redraw()
	return true


func _process(dt: float) -> void:
	if not _open:
		return
	_clock += dt
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - dt)
		if _canvas != null:
			_canvas.queue_redraw()
	_poll_navigation()


func _poll_navigation() -> void:
	if Input.is_action_just_pressed("lx_ui_cancel") or Input.is_action_just_pressed("lx_pause"):
		close()
		return
	if Input.is_action_just_pressed("lx_move_up"):
		if not _rows.is_empty():
			_row_idx = posmod(_row_idx - 1, _rows.size())
			_play_ui_sfx("ui_move")
			if _canvas != null: _canvas.queue_redraw()
	elif Input.is_action_just_pressed("lx_move_down"):
		if not _rows.is_empty():
			_row_idx = posmod(_row_idx + 1, _rows.size())
			_play_ui_sfx("ui_move")
			if _canvas != null: _canvas.queue_redraw()
	elif Input.is_action_just_pressed("lx_move_left"):
		select_tab(_tab_idx - 1)
	elif Input.is_action_just_pressed("lx_move_right"):
		select_tab(_tab_idx + 1)
	elif Input.is_action_just_pressed("lx_ui_accept") or Input.is_action_just_pressed("lx_interact"):
		confirm_selected()


func _input(ev: InputEvent) -> void:
	if not _open:
		return
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var kc: Key = (ev as InputEventKey).keycode
		if kc == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_TAB:
			select_tab(_tab_idx + 1)
			get_viewport().set_input_as_handled()
			return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			close()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
			get_viewport().set_input_as_handled()


func _handle_click(pos: Vector2) -> void:
	# Tab bar click
	if _mode != "redemption" and _mode != "finale_pixels" and pos.y >= 28.0 and pos.y <= 41.0:
		for i: int in range(TABS.size()):
			var tr := Rect2(22.0 + float(i) * 92.0, 28.0, 88.0, 12.0)
			if tr.has_point(pos):
				select_tab(i)
				return
	# Row click
	for i: int in range(mini(_rows.size(), MAX_ROWS_VISIBLE)):
		var rr := Rect2(22.0, LIST_Y + float(i) * ROW_H, 276.0, ROW_H - 2.0)
		if rr.has_point(pos):
			if _row_idx == i:
				confirm_selected()
			else:
				_row_idx = i
				_play_ui_sfx("ui_move")
				if _canvas != null: _canvas.queue_redraw()
			return


func _rebuild_rows() -> void:
	_rows.clear()
	var sold: LxSold = LxSold.current()
	if _mode == "finale_pixels":
		_rows.append({
			"id": "sell_display",
			"name_key": "ISL8_FINALE_SELL_PX",
			"now_key": "ISL8_VAL_320X180",
			"after_key": "ISL8_VAL_DEAD_PX",
			"lose_key": "ISL8_LOSE_DISPLAY",
			"get_key": "ISL8_GET_DISPLAY",
			"power_key": "ISL8_PWR_LAST_CLARITY",
			"weight": 3,
		})
		_rows.append({
			"id": "keep_display",
			"name_key": "ISL8_FINALE_KEEP_PX",
			"now_key": "ISL8_VAL_320X180",
			"after_key": "ISL8_VAL_320X180",
			"lose_key": "ISL8_FINALE_KEEP_LOSE",
			"get_key": "ISL8_FINALE_KEEP_GET",
			"power_key": "ISL8_FINALE_PURE",
			"weight": 0,
		})
		_row_idx = clampi(_row_idx, 0, maxi(0, _rows.size() - 1))
		return
	if _mode == "redemption":
		for sid: String in sold.get_sold_ids():
			if sid == "display_pixels":
				continue
			var meta: Dictionary = sold.get_setting(sid)
			if not meta.is_empty():
				_rows.append(meta)
		_row_idx = clampi(_row_idx, 0, maxi(0, _rows.size() - 1))
		return
	var tab_name: String = TABS[clampi(_tab_idx, 0, TABS.size() - 1)]
	_rows = sold.list_settings(tab_name, false)
	_row_idx = clampi(_row_idx, 0, maxi(0, _rows.size() - 1))


func _set_feedback(txt: String, col: Color) -> void:
	_feedback_text = txt
	_feedback_col = col
	_feedback_t = 1.6


func _sold_sfx_for(sid: String, tab: String) -> String:
	if sid in ["sound_off", "music_off"]:
		return "setting_sold_audio"
	if tab.to_upper() == "INTERFACE" or sid in ["hud_hearts", "minimap_hud", "ember_hud", "cursor_ring"]:
		return "setting_sold_hud"
	return "setting_sold_visual"


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null and is_instance_valid(Lx.audio):
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false)
	elif Lx.events != null:
		Lx.events.sfx_requested.emit(sfx_id, Vector2.ZERO, false)


func _draw_ledger() -> void:
	if _canvas == null or not _open:
		return
	var c: Node2D = _canvas
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var plum: Color = PAL["plum"] as Color
	var gold: Color = PAL["gold"] as Color
	var apricot: Color = PAL["apricot"] as Color
	var cream: Color = PAL["cream"] as Color
	var stone: Color = PAL["stone"] as Color
	var coral: Color = PAL["coral"] as Color
	var lime: Color = PAL["lime"] as Color

	# Scrim behind building ledger
	c.draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(void_c, 0.84))

	# Outer brass-trimmed ledger frame
	var r: Rect2 = PANEL_RECT
	c.draw_rect(r.grow(2.0), void_c)
	c.draw_rect(r, dusk)
	c.draw_rect(r.grow(-1.0), night)
	# Corner brass rivets
	for pt: Vector2 in [
		Vector2(r.position.x + 2.0, r.position.y + 2.0),
		Vector2(r.end.x - 4.0, r.position.y + 2.0),
		Vector2(r.position.x + 2.0, r.end.y - 4.0),
		Vector2(r.end.x - 4.0, r.end.y - 4.0),
	]:
		c.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), gold)

	var sold: LxSold = LxSold.current()
	var title_key: String = "ISL8_MENU_TITLE"
	if _mode == "redemption":
		title_key = "ISL8_MENU_REDEEM_TITLE"
	elif _mode == "invoice":
		title_key = "ISL8_MENU_INVOICE_TITLE"
	elif _mode == "boon_toll":
		title_key = "ISL8_MENU_BOON_TITLE"
	elif _mode == "finale_pixels":
		title_key = "ISL8_MENU_FINALE_TITLE"
	LxPixelFont.draw(c, LxStrings.text(title_key), Vector2(22.0, 16.0), gold, 1, void_c)

	var weight_str: String = "WT:%d" % sold.get_toll_weight()
	if _mode == "gate" or _mode == "invoice":
		weight_str = "WT:%d/%d" % [sold.get_toll_weight(), _min_weight]
	elif sold.get_sold_count() > 0:
		weight_str = "SOLD:%d/12  WT:%d" % [sold.get_sold_count(), sold.get_toll_weight()]
	LxPixelFont.draw(c, weight_str, Vector2(298.0, 16.0), cream, 1, void_c, HORIZONTAL_ALIGNMENT_RIGHT)
	c.draw_rect(Rect2(20.0, 24.0, 280.0, 1.0), plum)

	# Tabs (for multi-tab modes)
	if _mode != "redemption" and _mode != "finale_pixels":
		for i: int in range(TABS.size()):
			var active_t: bool = (i == _tab_idx)
			var tx: float = 22.0 + float(i) * 92.0
			c.draw_rect(Rect2(tx, 28.0, 88.0, 12.0), dusk if active_t else void_c)
			c.draw_rect(Rect2(tx + 1.0, 29.0, 86.0, 10.0), plum if active_t else night)
			if active_t:
				c.draw_rect(Rect2(tx, 39.0, 88.0, 1.0), gold)
			var tlabel: String = "%s +%d" % [TABS[i], 2 if TABS[i] == "BEAUTY" else 1]
			LxPixelFont.draw_centered(c, tlabel, tx + 44.0, 31.0, cream if active_t else stone, 1, void_c)
	else:
		var sub_key: String = "ISL8_MENU_REDEEM_SUB" if _mode == "redemption" else "ISL8_MENU_FINALE_SUB"
		LxPixelFont.draw(c, LxStrings.text(sub_key), Vector2(22.0, 31.0), apricot, 1, void_c)

	# Setting rows
	if _rows.is_empty():
		var empty_key: String = "ISL8_MENU_REDEEM_EMPTY" if _mode == "redemption" else "ISL8_MENU_EMPTY"
		LxPixelFont.draw_centered(c, LxStrings.text(empty_key), 160.0, 74.0, stone, 1, void_c)
	else:
		for i: int in range(mini(_rows.size(), MAX_ROWS_VISIBLE)):
			var row: Dictionary = _rows[i]
			var sid: String = str(row.get("id", ""))
			var sel: bool = (i == _row_idx)
			var already_sold: bool = sold.is_sold(sid) and _mode != "redemption"
			var redeemed: bool = sold.is_redeemed(sid)
			var ry: float = LIST_Y + float(i) * ROW_H
			c.draw_rect(Rect2(22.0, ry, 276.0, ROW_H - 2.0), gold if sel else dusk)
			c.draw_rect(Rect2(23.0, ry + 1.0, 274.0, ROW_H - 4.0), plum if sel else night)
			if sel:
				c.draw_rect(Rect2(25.0, ry + 5.0, 3.0, 5.0), cream)
			var label: String = LxStrings.text(str(row.get("name_key", sid.to_upper())))
			var name_col: Color = cream if sel else (stone if already_sold else apricot)
			LxPixelFont.draw(c, label, Vector2(31.0, ry + 5.0), name_col, 1, void_c)

			var state_txt: String = ""
			var state_col: Color = gold
			if _mode == "redemption":
				state_txt = LxStrings.text("ISL8_TAG_BUYBACK")
				state_col = lime
			elif already_sold:
				state_txt = LxStrings.text("ISL8_TAG_SOLD")
				state_col = coral
			elif redeemed:
				state_txt = LxStrings.text("ISL8_TAG_REDEEMED")
				state_col = lime
			else:
				var now_s: String = LxStrings.text(str(row.get("now_key", "ISL8_VAL_ON")))
				var aft_s: String = LxStrings.text(str(row.get("after_key", "ISL8_VAL_OFF")))
				state_txt = "%s - %s" % [now_s, aft_s]
				state_col = cream if sel else stone
			LxPixelFont.draw(c, state_txt, Vector2(292.0, ry + 5.0), state_col, 1, void_c, HORIZONTAL_ALIGNMENT_RIGHT)

	# Detail footer card: YOU LOSE / YOU GET (and Flash-Reduction note if active)
	var fy: float = 122.0
	c.draw_rect(Rect2(22.0, fy, 276.0, 32.0), void_c)
	c.draw_rect(Rect2(23.0, fy + 1.0, 274.0, 30.0), dusk)
	c.draw_rect(Rect2(24.0, fy + 2.0, 272.0, 28.0), night)
	if not _rows.is_empty():
		var cur: Dictionary = _rows[clampi(_row_idx, 0, _rows.size() - 1)]
		var cur_sid: String = str(cur.get("id", ""))
		var cur_sold: bool = sold.is_sold(cur_sid) and _mode != "redemption"
		var lose_s: String = LxStrings.text(str(cur.get("lose_key", "")))
		var get_s: String = LxStrings.text(str(cur.get("get_key", "")))
		var pwr_s: String = LxStrings.text(str(cur.get("power_key", "")))
		var pwr_col: Color = cream
		if _mode == "redemption":
			lose_s = LxStrings.text("ISL8_REDEEM_FREE_LINE")
			get_s = LxStrings.text("ISL8_REDEEM_KEEP_PWR")
		elif cur_sold:
			var redeem_ready: bool = Lx.state != null and bool(Lx.state.story_flags.get("toll_redemption_ready", false))
			if redeem_ready and not sold.is_redemption_used():
				pwr_s = LxStrings.text("ISL8_SOLD_BUYBACK_READY")
				pwr_col = lime
			elif not sold.is_redemption_used():
				pwr_s = LxStrings.text("ISL8_SOLD_BUYBACK_HINT")
				pwr_col = apricot
			else:
				pwr_s = LxStrings.text("ISL8_SOLD_UNTIL_DAWN")
				pwr_col = stone
		LxPixelFont.draw(c, lose_s, Vector2(28.0, fy + 5.0), coral, 1, void_c)
		LxPixelFont.draw(c, get_s, Vector2(28.0, fy + 14.0), gold, 1, void_c)
		LxPixelFont.draw(c, pwr_s, Vector2(28.0, fy + 22.0), pwr_col, 1, void_c)

	# Bottom controls / feedback bar (Esc always visible)
	if _feedback_t > 0.0 and not _feedback_text.is_empty():
		LxPixelFont.draw_centered(c, _feedback_text, 160.0, 159.0, _feedback_col, 1, void_c)
	else:
		LxPixelFont.draw_centered(c, LxStrings.text("ISL8_MENU_CONTROLS"), 160.0, 159.0, stone, 1, void_c)
