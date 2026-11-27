class_name LxRestShop
extends Node2D
## Lamplighter's Rest paginated upgrade & wares shrine reading luxel/data/upgrades.json (ECON-1).

signal closed()
signal upgrade_bought(upgrade_id: String, new_rank: int)

const PANEL_RECT := Rect2(20.0, 12.0, 280.0, 156.0)
const VISIBLE_ROWS: int = 6

var _pages: Array[Dictionary] = []
var _page_idx: int = 0
var _items: Array[Dictionary] = []
var _idx: int = 0
var _scroll: int = 0
var _hover_tab: int = -1
var _close_hover: bool = false
var _panes_hover: bool = false
var _feedback_txt: String = ""
var _feedback_col: String = "lime"
var _feedback_t: float = 0.0
var _elapsed: float = 0.0
var _spark_row: int = -1
var _spark_pip: int = -1
var _spark_t: float = 0.0
var _deny_row: int = -1
var _deny_t: float = 0.0


func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS; visible = false
func close() -> void: visible = false


func open() -> void:
	_load_pages()
	_page_idx = 0
	_rebuild_page_items()
	_feedback_txt = ""; _feedback_t = 0.0; _elapsed = 0.0
	_spark_row = -1; _spark_pip = -1; _spark_t = 0.0; _deny_row = -1; _deny_t = 0.0
	visible = true
	_play_ui_sfx("menu_open")
	queue_redraw()


func _load_pages() -> void:
	_pages.clear()
	if Lx.data_upgrades.is_empty(): Lx.load_all_data()
	var pv: Variant = Lx.data_upgrades.get("pages", [])
	if pv is Array and not (pv as Array).is_empty():
		for item: Variant in (pv as Array):
			if item is Dictionary: _pages.append(item as Dictionary)
	if _pages.is_empty():
		_pages.append({"id": "core", "name_key": "SHOP_SUBTITLE"})


func _rebuild_page_items() -> void:
	_items.clear()
	if _pages.is_empty(): return
	var pid: String = str(_pages[_page_idx].get("id", "core"))
	if pid == "wares":
		for wv: Variant in (Lx.data_upgrades.get("wares", []) as Array):
			if wv is Dictionary:
				var wd: Dictionary = (wv as Dictionary).duplicate()
				wd["_is_ware"] = true
				_items.append(wd)
	else:
		for uv: Variant in (Lx.data_upgrades.get("upgrades", []) as Array):
			if uv is Dictionary:
				var ud: Dictionary = uv as Dictionary
				var up: String = str(ud.get("page", "core"))
				if up == pid or _pages.size() == 1:
					_items.append(ud)
	_idx = clampi(_idx, 0, maxi(0, _items.size() - 1))
	_scroll = 0; _sync_scroll()


func _switch_page(next_p: int) -> void:
	if _pages.size() <= 1: return
	var wrapped: int = (next_p + _pages.size()) % _pages.size()
	if wrapped == _page_idx: return
	_page_idx = wrapped; _idx = 0; _scroll = 0
	_spark_row = -1; _deny_row = -1
	_rebuild_page_items()
	_play_ui_sfx("ui_move")
	queue_redraw()


func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - delta)
		if _feedback_t <= 0.0: _feedback_txt = ""
	if _spark_t > 0.0:
		_spark_t = maxf(0.0, _spark_t - delta)
		if _spark_t <= 0.0: _spark_row = -1; _spark_pip = -1
	if _deny_t > 0.0:
		_deny_t = maxf(0.0, _deny_t - delta)
		if _deny_t <= 0.0: _deny_row = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseMotion:
		_handle_mouse_motion((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if _key_just(event, KEY_TAB) or _key_just(event, KEY_Q) or _key_just(event, KEY_E) or _joy_btn(event, JOY_BUTTON_Y):
		_open_panes(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT) or _joy_btn(event, JOY_BUTTON_LEFT_SHOULDER):
		_switch_page(_page_idx - 1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT) or _joy_btn(event, JOY_BUTTON_RIGHT_SHOULDER):
		_switch_page(_page_idx + 1); get_viewport().set_input_as_handled(); return
	var count: int = maxi(1, _items.size())
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + count) % count; _sync_scroll(); _play_ui_sfx("ui_move"); queue_redraw(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % count; _sync_scroll(); _play_ui_sfx("ui_move"); queue_redraw(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_try_buy(_idx); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("menu_close"); closed.emit(); get_viewport().set_input_as_handled()


func _handle_mouse_motion(pos: Vector2) -> void:
	var over_close: bool = _close_btn_rect().has_point(pos)
	var over_panes: bool = _panes_btn_rect().has_point(pos)
	var new_tab: int = -1
	for ti: int in range(_pages.size()):
		if _tab_rect(ti).has_point(pos): new_tab = ti; break
	if over_close != _close_hover or over_panes != _panes_hover or new_tab != _hover_tab:
		_close_hover = over_close; _panes_hover = over_panes; _hover_tab = new_tab
		if over_close or over_panes or new_tab >= 0: _play_ui_sfx("ui_move")
		queue_redraw()
	for vis_i: int in range(VISIBLE_ROWS):
		var row_i: int = _scroll + vis_i
		if row_i >= _items.size(): break
		if _row_rect(vis_i).has_point(pos):
			if _idx != row_i: _idx = row_i; _play_ui_sfx("ui_move"); queue_redraw()
			return


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if not mb.pressed: return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		for ti: int in range(_pages.size()):
			if _tab_rect(ti).has_point(mb.position):
				_switch_page(ti); get_viewport().set_input_as_handled(); return
		if _panes_btn_rect().has_point(mb.position):
			_open_panes(); get_viewport().set_input_as_handled(); return
		if _close_btn_rect().has_point(mb.position):
			_play_ui_sfx("menu_close"); closed.emit(); get_viewport().set_input_as_handled(); return
		for vis_i: int in range(VISIBLE_ROWS):
			var row_i: int = _scroll + vis_i
			if row_i >= _items.size(): break
			if _row_rect(vis_i).has_point(mb.position):
				_idx = row_i; _try_buy(_idx); get_viewport().set_input_as_handled(); return
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_play_ui_sfx("menu_close"); closed.emit(); get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var max_s: int = maxi(0, _items.size() - VISIBLE_ROWS)
		var next_s: int = clampi(_scroll + (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 0, max_s)
		if next_s != _scroll:
			_scroll = next_s; _idx = clampi(_idx, _scroll, mini(_items.size() - 1, _scroll + VISIBLE_ROWS - 1))
			_play_ui_sfx("ui_move"); queue_redraw()
		get_viewport().set_input_as_handled()


func _open_panes() -> void:
	if Lx.ui != null and Lx.ui.has_method("show_panes"):
		_play_ui_sfx("ui_confirm")
		Lx.ui.call("show_panes", false, LxUiRoot.Screen.SHOP)


func _sync_scroll() -> void:
	if _idx < _scroll: _scroll = _idx
	elif _idx >= _scroll + VISIBLE_ROWS: _scroll = _idx - VISIBLE_ROWS + 1


func _try_buy(i: int) -> void:
	if i < 0 or i >= _items.size() or Lx.state == null: return
	var u: Dictionary = _items[i]
	var uid: String = str(u.get("id", ""))
	if bool(u.get("_is_ware", false)):
		var err: String = Lx.state.can_buy_ware(uid)
		if err.is_empty() and Lx.state.buy_ware(uid):
			var nr: int = Lx.state.get_ware_rank(uid)
			_on_buy_ok(i, uid, nr)
		else:
			var msg: String = fmt_shop(err, [Lx.state.get_ware_next_island(uid)]) if err == "SHOP_NEED_ISL_FMT" else tr_shop(err)
			_on_buy_deny(i, msg, "stone" if (err == "SHOP_MAXED" or err == "SHOP_WARE_CAP") else "coral")
		queue_redraw(); return

	var req_m: String = str(u.get("requires_move", ""))
	if uid == "spare_wick" and not Lx.state.is_spare_wick_allowed():
		_on_buy_deny(i, LxStrings.text("SHOP_HARD_NO_WICK"), "coral")
	elif not req_m.is_empty() and not Lx.state.has_move(req_m):
		_on_buy_deny(i, LxStrings.fmt("SHOP_NEED_MOVE_FMT", [_req_move_name(u)]), "coral")
	elif Lx.state.get_upgrade_rank(uid) >= int(u.get("max_rank", 0)):
		_on_buy_deny(i, LxStrings.text("SHOP_MAXED"), "stone")
	elif not Lx.state.is_next_rank_unlocked(uid):
		_on_buy_deny(i, fmt_shop("SHOP_NEED_ISL_FMT", [Lx.state.get_next_rank_island(uid)]), "coral")
	elif Lx.state.buy_upgrade(uid):
		_on_buy_ok(i, uid, Lx.state.get_upgrade_rank(uid))
	else:
		_on_buy_deny(i, LxStrings.text("SHOP_NO_SHARDS"), "coral")
	queue_redraw()


func _on_buy_ok(row_i: int, uid: String, new_rank: int) -> void:
	_feedback_txt = LxStrings.text("SHOP_BOUGHT"); _feedback_col = "lime"; _feedback_t = 1.4
	_spark_row = row_i; _spark_pip = maxi(0, new_rank - 1); _spark_t = LxRestShopDraw.SPARK_DUR
	_play_ui_sfx("shop_buy")
	if Lx.events != null: Lx.events.save_requested.emit("upgrade")
	upgrade_bought.emit(uid, new_rank)


func _on_buy_deny(row_i: int, msg: String, col: String) -> void:
	_feedback_txt = msg; _feedback_col = col; _feedback_t = 1.25
	_deny_row = row_i; _deny_t = 0.22
	_play_ui_sfx("denied")


func _page_has_affordable(p_idx: int) -> bool:
	if Lx.state == null or p_idx < 0 or p_idx >= _pages.size(): return false
	var pid: String = str(_pages[p_idx].get("id", "core"))
	if pid == "wares":
		for wv: Variant in (Lx.data_upgrades.get("wares", []) as Array):
			if wv is Dictionary and Lx.state.can_buy_ware(str((wv as Dictionary).get("id", ""))).is_empty():
				return true
		return false
	for uv: Variant in (Lx.data_upgrades.get("upgrades", []) as Array):
		if uv is Dictionary and str((uv as Dictionary).get("page", "core")) == pid:
			if Lx.state.can_buy_upgrade(str((uv as Dictionary).get("id", ""))):
				return true
	return false


func _draw() -> void:
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var prog: Vector2i = Lx.state.get_upgrade_totals() if Lx.state != null else Vector2i(0, 45)
	var all_done: bool = prog.y > 0 and prog.x >= prog.y
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", LxBiomePalette.key(isl, "border"), "night")
	LxRestShopDraw.draw_frame_ornaments(self, isl, _elapsed, all_done)
	LxRestShopDraw.draw_brazier_icon(self, Vector2(27.0, 15.0), isl, _elapsed, _spark_t > 0.0)
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_TITLE"), Vector2(38.0, 17.0), LxBiomePalette.col(isl, "glow"), 1)

	var shards: int = Lx.state.shards if Lx.state != null else 0
	var shard_txt: String = LxStrings.fmt("SHOP_SHARDS_FMT", [shards])
	var gem_x: float = 292.0 - float(LxPixelFont.width(shard_txt, 1)) - 10.0
	LxRestShopDraw.draw_shard_gem_icon(self, Vector2(gem_x, 15.0), _elapsed)
	LxPixelFont.draw_right(self, shard_txt, 292.0, 17.0, LxPalette.PAL["cream"] if _spark_t > 0.24 else LxPalette.PAL["apricot"], 1)

	var prog_txt: String = LxStrings.fmt("SHOP_PROGRESS_FMT", [prog.x, prog.y])
	var pw: float = float(LxPixelFont.width(prog_txt, 1)) + 8.0
	var pill_r := Rect2(roundf(gem_x - pw - 5.0), 14.0, pw, 10.0)
	LxPixelFont.draw_panel(self, pill_r, "night", "lime" if all_done else "mauve", "void")
	LxPixelFont.draw_centered(self, prog_txt, pill_r.get_center().x, 16.0, LxPalette.PAL["lime" if all_done else "cream"], 1)

	# Page tabs row
	for ti: int in range(_pages.size()):
		var tr: Rect2 = _tab_rect(ti)
		var active_t: bool = ti == _page_idx
		var hov_t: bool = ti == _hover_tab
		var fill_t: String = "plum" if active_t else ("dusk" if hov_t else "night")
		var bdr_t: String = "gold" if active_t else ("apricot" if hov_t else "mauve")
		LxPixelFont.draw_panel(self, tr, fill_t, bdr_t, "void")
		var lbl: String = tr_shop(str(_pages[ti].get("name_key", "SHOP_SUBTITLE")))
		LxPixelFont.draw_centered(self, lbl, tr.get_center().x, tr.position.y + 3.0, LxPalette.PAL["gold" if active_t else "cream"], 1)
		if _page_has_affordable(ti):
			draw_rect(Rect2(tr.end.x - 4.0, tr.position.y + 2.0, 2.0, 2.0), LxPalette.PAL["lime"])

	for vis_i: int in range(VISIBLE_ROWS):
		var row_i: int = _scroll + vis_i
		if row_i >= _items.size(): break
		_draw_row(vis_i, row_i, _items[row_i])
	LxRestShopDraw.draw_scrollbar(self, _items.size(), VISIBLE_ROWS, _scroll)

	_draw_desc_panel(shards)
	var hint_k: String = "SHOP_PAGE_HINT" if _pages.size() > 1 else "SHOP_BUY_HINT"
	LxPixelFont.draw_left(self, tr_shop(hint_k), Vector2(28.0, 157.0), LxPalette.PAL["stone"], 1)
	var pr_btn: Rect2 = _panes_btn_rect()
	LxPixelFont.draw_panel(self, pr_btn, "plum" if _panes_hover else "night", "gold" if _panes_hover else "sky", "void")
	LxPixelFont.draw_centered(self, LxStrings.text("SHOP_TAB_PANES"), pr_btn.get_center().x, pr_btn.position.y + 3.0, LxPalette.PAL["gold"] if _panes_hover else LxPalette.PAL["sky"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxStrings.text("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)


func _draw_row(vis_i: int, row_i: int, u: Dictionary) -> void:
	var r: Rect2 = _row_rect(vis_i)
	var denied: bool = _deny_t > 0.0 and row_i == _deny_row
	if denied and LxHudFx.shake_enabled():
		r.position.x += roundf(sin(_deny_t * 54.0) * 1.6)
	var sel: bool = row_i == _idx
	var uid: String = str(u.get("id", ""))
	var is_ware: bool = bool(u.get("_is_ware", false))
	var info: Dictionary = _item_status(u)
	var locked: bool = bool(info["locked"])
	var maxed: bool = bool(info["maxed"])
	var affordable: bool = bool(info["affordable"])
	var rank: int = int(info["rank"])
	var max_rank: int = int(info["max_rank"])
	var cost: int = int(info["cost"])

	if sel:
		LxPixelFont.draw_panel(self, r, "night" if locked else "plum", "coral" if denied else ("mauve" if locked else "gold"), "night")
		var bob: float = 0.0 if (denied or LxHudFx.flash_reduced()) else (1.0 if fmod(_elapsed * 3.0, 1.0) < 0.5 else 0.0)
		var cx: float = 23.0 + bob; var cy: float = r.position.y + 4.0
		var c_out: Color = LxPalette.PAL["coral"] if denied else (LxPalette.PAL["mauve"] if locked else LxPalette.PAL["gold"])
		draw_rect(Rect2(cx - 1.0, cy - 1.0, 3.0, 7.0), LxPalette.PAL["void"])
		draw_rect(Rect2(cx, cy, 1.0, 5.0), c_out)
		draw_rect(Rect2(cx + 1.0, cy + 1.0, 1.0, 3.0), LxPalette.PAL["cream"])
	else:
		LxPixelFont.draw_panel(self, r, "void" if locked else "night", "night" if locked else "dusk", "void")

	LxRestShopDraw.draw_item_icon(self, r.position + Vector2(5.0, 3.0), uid, sel and not locked, _elapsed, locked)
	var name_col: Color = (LxPalette.PAL["stone"] if sel else LxPalette.PAL["mauve"]) if locked else (LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"])
	LxPixelFont.draw_left(self, tr_shop(str(u.get("name_key", ""))), r.position + Vector2(16.0, 4.0), name_col, 1)

	var pip_x: float = r.position.x + 132.0
	if not (is_ware and bool(u.get("repeatable", false))):
		for p: int in range(max_rank):
			var pr := Rect2(pip_x + float(p * 7), r.position.y + 4.0, 5.0, 5.0)
			LxRestShopDraw.draw_rank_pip(self, pr, p < rank, sel and not locked, p, _elapsed, not locked and sel and not maxed and affordable and p == rank)
		if _spark_t > 0.0 and row_i == _spark_row and _spark_pip >= 0:
			LxRestShopDraw.draw_purchase_sparkle(self, Vector2(pip_x + float(_spark_pip * 7) + 2.0, r.position.y + 6.0), Lx.state.island_id if Lx.state != null else 1, _spark_t)

	var right_txt: String = str(info["right_txt"])
	var right_col: Color = LxPalette.color(str(info["right_col"]))
	if denied and locked: right_col = LxPalette.PAL["coral"]
	LxPixelFont.draw_right(self, right_txt, r.end.x - 6.0, r.position.y + 4.0, right_col, 1)


func _draw_desc_panel(shards: int) -> void:
	var desc_rect := Rect2(28.0, 130.0, 264.0, 22.0)
	LxPixelFont.draw_panel(self, desc_rect, "night", "mauve", "void")
	if not _feedback_txt.is_empty():
		LxPixelFont.draw_centered(self, _feedback_txt, 160.0, 138.0, LxPalette.color(_feedback_col), 1)
		return
	if _idx < 0 or _idx >= _items.size(): return
	var u: Dictionary = _items[_idx]
	var info: Dictionary = _item_status(u)
	var desc_txt: String = tr_shop(str(u.get("desc_key", "")))
	if bool(info["locked"]):
		LxPixelFont.draw_left(self, str(info["lock_detail"]), Vector2(34.0, 134.0), LxPalette.PAL["coral"], 1)
		LxPixelFont.draw_left(self, desc_txt, Vector2(34.0, 143.0), LxPalette.PAL["stone"], 1)
		LxRestShopDraw.draw_shard_pill(self, desc_rect, shards, 0, str(info["right_txt"]), "coral")
	elif bool(info["maxed"]):
		LxPixelFont.draw_left(self, desc_txt, Vector2(34.0, 134.0), LxPalette.PAL["cream"], 1)
		LxPixelFont.draw_left(self, _stat_delta_text(u), Vector2(34.0, 143.0), LxPalette.PAL["lime"], 1)
		LxRestShopDraw.draw_shard_pill(self, desc_rect, shards, 0, str(info["right_txt"]), "lime")
	else:
		LxPixelFont.draw_left(self, desc_txt, Vector2(34.0, 134.0), LxPalette.PAL["cream"], 1)
		LxPixelFont.draw_left(self, _stat_delta_text(u), Vector2(34.0, 143.0), LxPalette.PAL["sky"], 1)
		LxRestShopDraw.draw_shard_pill(self, desc_rect, shards, int(info["cost"]), "", "")


func _item_status(u: Dictionary) -> Dictionary:
	var uid: String = str(u.get("id", ""))
	if bool(u.get("_is_ware", false)):
		var rep: bool = bool(u.get("repeatable", false))
		var r: int = Lx.state.get_ware_rank(uid) if Lx.state != null else 0
		var mr: int = 1 if rep else int(u.get("max_rank", 1))
		var cost: int = Lx.state.get_ware_cost(uid) if Lx.state != null else 0
		var err: String = Lx.state.can_buy_ware(uid) if Lx.state != null else ""
		var isl_need: int = Lx.state.get_ware_next_island(uid) if Lx.state != null else 1
		if err == "SHOP_MAXED" or err == "SHOP_WARE_CAP" or err == "SHOP_WARE_NONE":
			return {"locked": false, "maxed": true, "affordable": false, "rank": r, "max_rank": mr, "cost": 0, "right_txt": LxStrings.text("SHOP_MAXED"), "right_col": "lime", "lock_detail": tr_shop(err)}
		if err == "SHOP_NEED_ISL_FMT":
			return {"locked": true, "maxed": false, "affordable": false, "rank": r, "max_rank": mr, "cost": cost, "right_txt": fmt_shop("SHOP_LOCKED_ISL_FMT", [isl_need]), "right_col": "mauve", "lock_detail": fmt_shop("SHOP_NEED_ISL_FMT", [isl_need])}
		if err == "SHOP_WARE_NEED_WICK" or err == "SHOP_WARE_ARMED" or err == "SHOP_HARD_NO_WICK":
			var rtxt_w: String = tr_shop("SHOP_HARD_OFF") if err == "SHOP_HARD_NO_WICK" else (tr_shop("SHOP_WICK_READY") if err == "SHOP_WARE_ARMED" else LxStrings.text("SHOP_LOCKED_MOVE"))
			var rcol_w: String = "coral" if err == "SHOP_HARD_NO_WICK" else ("lime" if err == "SHOP_WARE_ARMED" else "mauve")
			return {"locked": true, "maxed": false, "affordable": false, "rank": r, "max_rank": mr, "cost": cost, "right_txt": rtxt_w, "right_col": rcol_w, "lock_detail": tr_shop(err)}
		var aff: bool = err.is_empty()
		return {"locked": false, "maxed": false, "affordable": aff, "rank": r, "max_rank": mr, "cost": cost, "right_txt": LxStrings.fmt("SHOP_COST_FMT", [cost]), "right_col": "gold" if aff else "coral", "lock_detail": ""}

	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var max_rank: int = int(u.get("max_rank", 1))
	var costs: Array = u.get("costs", []) as Array
	var maxed: bool = rank >= max_rank
	var req_m: String = str(u.get("requires_move", ""))
	if uid == "spare_wick" and Lx.state != null and not Lx.state.is_spare_wick_allowed():
		return {"locked": true, "maxed": false, "affordable": false, "rank": rank, "max_rank": max_rank, "cost": 0, "right_txt": tr_shop("SHOP_HARD_OFF"), "right_col": "coral", "lock_detail": tr_shop("SHOP_HARD_NO_WICK")}
	if Lx.state != null and not req_m.is_empty() and not Lx.state.has_move(req_m):
		return {"locked": true, "maxed": false, "affordable": false, "rank": rank, "max_rank": max_rank, "cost": 0, "right_txt": LxStrings.text("SHOP_LOCKED_MOVE"), "right_col": "mauve", "lock_detail": LxStrings.fmt("SHOP_NEED_MOVE_FMT", [_req_move_name(u)])}
	if maxed:
		return {"locked": false, "maxed": true, "affordable": false, "rank": rank, "max_rank": max_rank, "cost": 0, "right_txt": LxStrings.text("SHOP_MAXED"), "right_col": "lime", "lock_detail": ""}
	if Lx.state != null and not Lx.state.is_next_rank_unlocked(uid):
		var need_i: int = Lx.state.get_next_rank_island(uid)
		return {"locked": true, "maxed": false, "affordable": false, "rank": rank, "max_rank": max_rank, "cost": 0, "right_txt": fmt_shop("SHOP_LOCKED_ISL_FMT", [need_i]), "right_col": "mauve", "lock_detail": fmt_shop("SHOP_NEED_ISL_FMT", [need_i])}
	var cost: int = int(costs[rank]) if rank < costs.size() else 0
	var aff2: bool = Lx.state != null and Lx.state.can_buy_upgrade(uid)
	return {"locked": false, "maxed": false, "affordable": aff2, "rank": rank, "max_rank": max_rank, "cost": cost, "right_txt": LxStrings.fmt("SHOP_COST_FMT", [cost]), "right_col": "gold" if aff2 else "coral", "lock_detail": ""}


func _req_move_name(u: Dictionary) -> String:
	var req: String = str(u.get("requires_move", ""))
	if req.is_empty(): return ""
	var mkey: String = str(Lx.get_move_data(req).get("name_key", ""))
	return LxStrings.text(mkey) if (not mkey.is_empty() and LxStrings.has_id(mkey)) else LxStrings.sanitize(req, 16)


func _stat_delta_text(u: Dictionary) -> String:
	var uid: String = str(u.get("id", ""))
	if bool(u.get("_is_ware", false)):
		var eff: String = str(u.get("effect", ""))
		var p: Object = LxGameState._panes_svc()
		match eff:
			"lead":
				var cur_l: int = int(p.call("get_max_lead")) if p != null else 6
				return LxStrings.fmt("SHOP_DELTA_FMT", [str(cur_l), str(mini(10, cur_l + 1))])
			"slot":
				var cur_s: int = int(p.call("get_slots")) if p != null else 3
				return LxStrings.fmt("SHOP_DELTA_FMT", [str(cur_s), str(mini(5, cur_s + 1))])
			"pane":
				var owned_n: int = (p.call("owned_ids") as PackedStringArray).size() if p != null else 0
				return LxStrings.fmt("SHOP_PROGRESS_FMT", [owned_n, LxFolkData.panes().size()])
			"rearm_wick": return tr_shop("SHOP_WICK_READY" if (Lx.state != null and Lx.state.spare_wick_ready) else "SHOP_WICK_SPENT")
		return ""
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var vals: Array = u.get("values", []) as Array
	var cur_v: float = _current_stat_val(uid)
	if rank >= vals.size():
		if uid == "spare_wick" and Lx.state != null:
			return LxStrings.fmt("SHOP_STAT_MAX_FMT", [tr_shop("SHOP_WICK_READY" if Lx.state.spare_wick_ready else "SHOP_WICK_SPENT")])
		return LxStrings.fmt("SHOP_STAT_MAX_FMT", [_fmt_stat_val(uid, cur_v)])
	return LxStrings.fmt("SHOP_DELTA_FMT", [_fmt_stat_val(uid, cur_v), _fmt_stat_val(uid, float(vals[rank]))])


func _current_stat_val(uid: String) -> float:
	if Lx.state == null: return 0.0
	match uid:
		"bolt_damage": return Lx.state.get_effective_bolt_damage()
		"bolt_rate": return Lx.state.get_effective_bolt_cooldown()
		"throw_damage": return Lx.state.get_effective_throw_damage()
		"throw_hang": return Lx.state.get_effective_throw_hang()
		"zip_bomb": return Lx.state.get_effective_zip_radius()
		"dash_cooldown": return Lx.state.get_effective_dash_cooldown()
		"dash_charges": return float(Lx.state.get_effective_dash_charges())
		"prism_bounce": return float(Lx.state.get_effective_prism_bounces())
		"beam_charge": return Lx.state.get_effective_beam_charge()
		"beam_width": return Lx.state.get_effective_beam_width()
		"wings_glide": return Lx.state.get_effective_wings_glide()
		"lens_duration": return Lx.state.get_effective_lens_duration()
		"lens_radius": return Lx.state.get_effective_lens_radius()
		"ember_meter": return Lx.state.get_effective_ember_max()
		"pickup_radius": return Lx.state.get_effective_pickup_scale()
		"spare_wick": return Lx.state.get_effective_spare_wick_hearts()
	return 0.0


func _fmt_stat_val(uid: String, v: float) -> String:
	match uid:
		"prism_bounce": return str(roundi(v))
		"dash_charges": return fmt_shop("SHOP_UNIT_CHG_FMT", [str(roundi(v))])
		"spare_wick": return fmt_shop("SHOP_UNIT_HRT_FMT", ["%.0f" % v])
		"pickup_radius": return LxStrings.fmt("FMT_PCT", [roundi(v * 100.0)])
		"ember_meter":
			var base_e: float = float(Lx.get_move_data("sunflare").get("ember_max", 100.0))
			return LxStrings.fmt("FMT_PCT", [roundi((base_e / maxf(1.0, v if v > 0.0 else base_e)) * 100.0)])
		"wings_glide", "zip_bomb", "beam_width", "lens_radius":
			return LxStrings.fmt("SHOP_UNIT_PX_FMT", [str(roundi(v))])
		"bolt_rate":
			var s3: String = "%.3f" % v
			if s3.ends_with("0"): s3 = s3.substr(0, s3.length() - 1)
			return LxStrings.fmt("SHOP_UNIT_SEC_FMT", [s3])
		"dash_cooldown", "beam_charge": return LxStrings.fmt("SHOP_UNIT_SEC_FMT", ["%.2f" % v])
		"lens_duration", "throw_hang": return LxStrings.fmt("SHOP_UNIT_SEC_FMT", ["%.1f" % v])
		"throw_damage":
			var st: String = "%.2f" % v
			if st.ends_with("0"): st = st.substr(0, st.length() - 1)
			return st
		_: return "%.2f" % v


static func tr_shop(key: String) -> String:
	if key.is_empty(): return ""
	if Lx.packs == null: Lx.ensure_packs()
	if LxStrings.has_id(key): return LxStrings.text(key)
	return LxStrings.sanitize(key, 45)


static func fmt_shop(key: String, args: Array) -> String:
	if Lx.packs == null: Lx.ensure_packs()
	if LxStrings.has_id(key): return LxStrings.fmt(key, args)
	return LxStrings._apply_fmt(tr_shop(key), args)


func _tab_rect(ti: int) -> Rect2:
	var n: int = maxi(1, _pages.size())
	var w: float = floorf((264.0 - float(n - 1) * 4.0) / float(n))
	return Rect2(28.0 + float(ti) * (w + 4.0), 24.0, w, 11.0)

func _row_rect(vis_i: int) -> Rect2:
	return Rect2(28.0, 39.0 + float(vis_i) * 15.0, 257.0 if _items.size() > VISIBLE_ROWS else 264.0, 13.0)

func _panes_btn_rect() -> Rect2: return Rect2(174.0, 154.0, 52.0, 11.0)
func _close_btn_rect() -> Rect2: return Rect2(230.0, 154.0, 62.0, 11.0)
func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null: Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)
static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
static func _joy_btn(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
