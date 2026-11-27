class_name LxHubMenuServices
extends Node2D
## Shared modal panel for three Wick House services:
## 1) MOTH_CEREMONY: Moth Lantern reward tiers 5/10/20/35/50/65/80 with ceremony flash & First Dark teaser
## 2) LEAD_SHOP: Kiln Salamander's Pane Workshop Lead upgrades + Panes Bench shortcut
## 3) TAILOR: Tailor Spider's Last Light Lantern Flame Colour wardrobe

signal closed()

enum Mode { MOTH_CEREMONY, LEAD_SHOP, TAILOR }

const PANEL := Rect2(22.0, 12.0, 276.0, 156.0)

var mode: int = Mode.MOTH_CEREMONY
var _idx: int = 0
var _clock: float = 0.0
var _ceremony_t: float = 0.0
var _status_key: String = ""
var _status_t: float = 0.0
var _status_col: String = "gold"
var _hover_close: bool = false
var _hover_action: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open_mode(p_mode: int) -> void:
	mode = p_mode
	_idx = 0
	_ceremony_t = 0.0
	_status_key = ""
	_status_t = 0.0
	_hover_close = false
	_hover_action = false
	if mode == Mode.TAILOR:
		var eq: String = LxHubState.get_equipped_flame()
		for i: int in range(LxHubState.FLAME_CATALOG.size()):
			if str(LxHubState.FLAME_CATALOG[i]["id"]) == eq:
				_idx = i
				break
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_hover_close = false
	_hover_action = false


func select_index(i: int) -> void:
	var n: int = _item_count()
	if n <= 0:
		_idx = 0
		return
	_idx = clampi(i, 0, n - 1)
	queue_redraw()


func _item_count() -> int:
	match mode:
		Mode.MOTH_CEREMONY: return LxQuests.MOTH_TIERS.size()
		Mode.LEAD_SHOP: return 2 # 0 = Buy +1 Lead, 1 = Open Panes Bench
		Mode.TAILOR: return LxHubState.FLAME_CATALOG.size()
	return 1


func confirm_selected() -> bool:
	match mode:
		Mode.MOTH_CEREMONY:
			return _confirm_moth_ceremony()
		Mode.LEAD_SHOP:
			return _confirm_lead_shop()
		Mode.TAILOR:
			return _confirm_tailor()
	return false


func _confirm_moth_ceremony() -> bool:
	var claimed: Dictionary = LxQuests.current().claim_next_moth_tier()
	if not claimed.is_empty():
		_ceremony_t = 1.6
		var cue: String = str(claimed.get("cue_key", "MOTH_REWARD_CLAIMED"))
		_set_status(cue, "gold")
		_play_ui("shrine_unlock")
		LxHubState.sync_hub_vars()
		if Lx.events != null:
			Lx.events.narration_requested.emit(cue, "title", 3.0)
		return true
	_set_status("HUB_MOTH_NEED_MORE", "stone")
	_play_ui("ui_move")
	return false


func _confirm_lead_shop() -> bool:
	if _idx == 1:
		_play_ui("menu_open")
		closed.emit()
		if Lx.ui != null and Lx.ui.has_method("open_panes_menu"):
			Lx.ui.call("open_panes_menu")
		return true
	if LxHubState.buy_lead():
		_ceremony_t = 0.8
		_set_status("HUB_LEAD_BOUGHT", "lime")
		_play_ui("shop_buy")
		return true
	var price: int = LxHubState.get_next_lead_price()
	_set_status("HUB_LEAD_MAX" if price < 0 else "HUB_NEED_SHARDS", "coral")
	_play_ui("denied")
	return false


func _confirm_tailor() -> bool:
	if _idx < 0 or _idx >= LxHubState.FLAME_CATALOG.size():
		return false
	var spec: Dictionary = LxHubState.FLAME_CATALOG[_idx]
	var fid: String = str(spec["id"])
	if LxHubState.is_flame_owned(fid):
		LxHubState.equip_flame(fid)
		_ceremony_t = 0.65
		_set_status("HUB_TAILOR_EQUIPPED", fid)
		_play_ui("ui_confirm")
		return true
	if LxHubState.buy_flame(fid):
		_ceremony_t = 0.9
		_set_status("HUB_TAILOR_BOUGHT", fid)
		_play_ui("shop_buy")
		return true
	_set_status("HUB_NEED_SHARDS", "coral")
	_play_ui("denied")
	return false


func _set_status(key: String, col: String) -> void:
	_status_key = key
	_status_col = col
	_status_t = 2.6
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if _ceremony_t > 0.0:
		_ceremony_t = maxf(0.0, _ceremony_t - delta)
	if _status_t > 0.0:
		_status_t = maxf(0.0, _status_t - delta)
		if _status_t <= 0.0:
			_status_key = ""
	queue_redraw()


func handle_menu_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseMotion:
		_handle_hover((event as InputEventMouseMotion).position)
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_ui("menu_close"); closed.emit(); return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _close_rect().has_point(mb.position):
				_play_ui("menu_close"); closed.emit(); return true
			return _handle_click(mb.position)
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_BACKSPACE:
			_play_ui("menu_close"); closed.emit(); return true
		if k == KEY_UP or k == KEY_W or k == KEY_LEFT or k == KEY_A:
			select_index(_idx - 1); _play_ui("ui_move"); return true
		if k == KEY_DOWN or k == KEY_S or k == KEY_RIGHT or k == KEY_D:
			select_index(_idx + 1); _play_ui("ui_move"); return true
		if k == KEY_ENTER or k == KEY_SPACE or k == KEY_E:
			confirm_selected(); return true
	if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause"):
		_play_ui("menu_close"); closed.emit(); return true
	if event.is_action_pressed("lx_ui_accept"):
		confirm_selected(); return true
	if event.is_action_pressed("lx_move_up") or event.is_action_pressed("lx_move_left"):
		select_index(_idx - 1); _play_ui("ui_move"); return true
	if event.is_action_pressed("lx_move_down") or event.is_action_pressed("lx_move_right"):
		select_index(_idx + 1); _play_ui("ui_move"); return true
	return false


func _handle_hover(pos: Vector2) -> void:
	var hc: bool = _close_rect().has_point(pos)
	if hc != _hover_close:
		_hover_close = hc
		if hc:
			_play_ui("ui_move")
		queue_redraw()
	match mode:
		Mode.MOTH_CEREMONY:
			var ha: bool = _action_btn_rect().has_point(pos)
			if ha != _hover_action:
				_hover_action = ha
				if ha:
					_play_ui("ui_move")
				queue_redraw()
			var n_tiers: int = mini(LxFolkData.moth_tiers().size(), 7)
			for i: int in range(n_tiers):
				if _moth_tier_rect(i).has_point(pos):
					if _idx != i:
						select_index(i)
						_play_ui("ui_move")
					break
		Mode.LEAD_SHOP:
			_hover_action = false
			for i: int in range(2):
				if _lead_btn_rect(i).has_point(pos):
					if _idx != i:
						select_index(i)
						_play_ui("ui_move")
					break
		Mode.TAILOR:
			_hover_action = false
			for i: int in range(LxHubState.FLAME_CATALOG.size()):
				if _tailor_tile_rect(i).has_point(pos):
					if _idx != i:
						select_index(i)
						_play_ui("ui_move")
					break


func _handle_click(pos: Vector2) -> bool:
	match mode:
		Mode.MOTH_CEREMONY:
			if _action_btn_rect().has_point(pos):
				confirm_selected()
				return true
			var n_tiers: int = mini(LxFolkData.moth_tiers().size(), 7)
			for i: int in range(n_tiers):
				if _moth_tier_rect(i).has_point(pos):
					select_index(i)
					_play_ui("ui_move")
					return true
		Mode.LEAD_SHOP:
			for i: int in range(2):
				if _lead_btn_rect(i).has_point(pos):
					_idx = i
					confirm_selected()
					return true
		Mode.TAILOR:
			for i: int in range(LxHubState.FLAME_CATALOG.size()):
				if _tailor_tile_rect(i).has_point(pos):
					_idx = i
					confirm_selected()
					return true
	return true


func _play_ui(sfx: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx, Vector2.ZERO, false, true)


func _close_rect() -> Rect2:
	return Rect2(PANEL.end.x - 18.0, PANEL.position.y + 4.0, 12.0, 12.0)


func _moth_tier_rect(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 14.0 + float(i) * 36.0, PANEL.position.y + 42.0, 32.0, 38.0)


func _action_btn_rect() -> Rect2:
	return Rect2(PANEL.position.x + 76.0, PANEL.end.y - 34.0, 124.0, 16.0)


func _lead_btn_rect(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 18.0, PANEL.position.y + 72.0 + float(i) * 28.0, PANEL.size.x - 36.0, 22.0)


func _tailor_tile_rect(i: int) -> Rect2:
	var col_i: int = i % 4
	var row_i: int = i / 4
	return Rect2(PANEL.position.x + 16.0 + float(col_i) * 62.0, PANEL.position.y + 46.0 + float(row_i) * 38.0, 56.0, 32.0)


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(PANEL.position + Vector2(2.0, 2.0), PANEL.size), LxPalette.PAL["void"])
	var hdr_bdr: String = "rose" if mode == Mode.TAILOR else ("apricot" if mode == Mode.LEAD_SHOP else "gold")
	LxPixelFont.draw_panel(self, PANEL, "night", hdr_bdr, "void")
	var hdr_col: Color = LxPalette.PAL["plum"] if mode == Mode.TAILOR else (LxPalette.PAL["wine"] if mode == Mode.LEAD_SHOP else LxPalette.PAL["dusk"])
	draw_rect(Rect2(PANEL.position.x + 2.0, PANEL.position.y + 2.0, PANEL.size.x - 4.0, 16.0), hdr_col)
	draw_rect(Rect2(PANEL.position.x + 2.0, PANEL.position.y + 18.0, PANEL.size.x - 4.0, 1.0), LxPalette.color(hdr_bdr))
	for rv: Vector2 in [
		Vector2(PANEL.position.x + 3.0, PANEL.position.y + 3.0),
		Vector2(PANEL.end.x - 5.0, PANEL.position.y + 3.0),
		Vector2(PANEL.position.x + 3.0, PANEL.end.y - 5.0),
		Vector2(PANEL.end.x - 5.0, PANEL.end.y - 5.0),
	]:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), LxPalette.PAL["apricot"])
		draw_rect(Rect2(rv, Vector2.ONE), LxPalette.PAL["gold"])
	var cr: Rect2 = _close_rect()
	LxPixelFont.draw_panel(self, cr, "coral" if _hover_close else "wine", "gold" if _hover_close else "mauve", "void")
	LxPixelFont.draw_centered(self, "X", cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["cream"], 1)

	match mode:
		Mode.MOTH_CEREMONY: _draw_moth_ceremony()
		Mode.LEAD_SHOP: _draw_lead_shop()
		Mode.TAILOR: _draw_tailor()

	if _ceremony_t > 0.0:
		if LxHudFx.flash_reduced():
			var ir: Rect2 = PANEL.grow(-2.0)
			draw_rect(Rect2(ir.position.x, ir.position.y, ir.size.x, 1.0), LxPalette.PAL["gold"])
			draw_rect(Rect2(ir.position.x, ir.end.y - 1.0, ir.size.x, 1.0), LxPalette.PAL["gold"])
			draw_rect(Rect2(ir.position.x, ir.position.y, 1.0, ir.size.y), LxPalette.PAL["gold"])
			draw_rect(Rect2(ir.end.x - 1.0, ir.position.y, 1.0, ir.size.y), LxPalette.PAL["gold"])
		else:
			var u: float = 1.0 - clampf(_ceremony_t / 1.6, 0.0, 1.0)
			draw_arc(PANEL.get_center().round(), roundf(14.0 + u * 72.0), 0.0, TAU, 24, LxPalette.PAL["gold"], 1.5)
	if not _status_key.is_empty():
		LxPixelFont.draw_centered(self, LxStrings.text(_status_key), PANEL.position.x + PANEL.size.x * 0.5, PANEL.end.y - 12.0, LxPalette.color(_status_col, "gold"), 1)


func _draw_moth_ceremony() -> void:
	LxBubble.draw_icon(self, "moth", Vector2(PANEL.position.x + 7.0, PANEL.position.y + 5.0), 1.0)
	LxPixelFont.draw(self, LxStrings.text("HUB_MOTH_TITLE"), Vector2(PANEL.position.x + 20.0, PANEL.position.y + 7.0), LxPalette.PAL["gold"], 1)
	var q: LxQuests = LxQuests.current()
	var mc: int = q.get_moth_count()
	LxPixelFont.draw(self, LxStrings.fmt("HUB_MOTH_COUNT", [mc, 80]), Vector2(PANEL.position.x + 12.0, PANEL.position.y + 24.0), LxPalette.PAL["cream"], 1)

	# 7 tier nodes (5, 10, 20, 35, 50, 65, 80)
	var tiers: Array[Dictionary] = LxFolkData.moth_tiers()
	var can_claim: bool = false
	for i: int in range(mini(tiers.size(), 7)):
		var td: Dictionary = tiers[i]
		var req: int = int(td.get("count", 0))
		var claimed: bool = q.is_moth_tier_claimed(req)
		var reached: bool = mc >= req
		if reached and not claimed:
			can_claim = true
		var sel: bool = i == _idx
		var box: Rect2 = _moth_tier_rect(i)
		var bg_k: String = "teal" if claimed else ("plum" if reached else "void")
		var bdr_k: String = ("cream" if reached else "gold") if sel else ("lime" if claimed else ("apricot" if reached else "dusk"))
		LxPixelFont.draw_panel(self, box, bg_k, bdr_k, "void")
		LxPixelFont.draw_centered(self, "%d" % req, roundf(box.position.x + 16.0), roundf(box.position.y + 5.0), LxPalette.PAL["gold"] if reached else LxPalette.PAL["stone"], 1)
		var rk: String = str((td.get("reward", {}) as Dictionary).get("kind", "shards"))
		var ic: String = "flame" if rk == "flame" else ("ember" if rk == "ember_piece" else ("pane" if rk in ["lead", "slot"] else "shard"))
		LxBubble.draw_icon(self, ic, Vector2(roundf(box.position.x + 11.0), roundf(box.position.y + 14.0)), 1.0)
		var st_lbl: String = LxStrings.text("HUB_MOTH_DONE" if claimed else ("HUB_MOTH_READY" if reached else "HUB_MOTH_LOCK"))
		LxPixelFont.draw_centered(self, st_lbl, roundf(box.position.x + 16.0), roundf(box.position.y + 28.0), LxPalette.PAL["lime"] if claimed else (LxPalette.PAL["gold"] if reached else LxPalette.PAL["mauve"]), 1)

	var desc_key: String = "HUB_MOTH_TEASER_80" if mc >= 80 else "HUB_MOTH_CEREMONY_DESC"
	LxPixelFont.draw_centered(self, LxStrings.text(desc_key), PANEL.position.x + PANEL.size.x * 0.5, PANEL.position.y + 92.0, LxPalette.PAL["ice"] if mc >= 80 else LxPalette.PAL["stone"], 1)

	var btn: Rect2 = _action_btn_rect()
	var btn_fill: String = ("coral" if _hover_action else "wine") if can_claim else ("dusk" if _hover_action else "night")
	var btn_bdr: String = ("cream" if _hover_action else "gold") if can_claim else ("mauve" if _hover_action else "dusk")
	LxPixelFont.draw_panel(self, btn, btn_fill, btn_bdr, "void")
	var btxt: String = LxStrings.text("HUB_MOTH_CLAIM_BTN" if can_claim else "HUB_MOTH_NONE_BTN")
	var bcol: Color = LxPalette.PAL["cream"] if (can_claim and _hover_action) else (LxPalette.PAL["gold"] if can_claim else LxPalette.PAL["stone"])
	LxPixelFont.draw_centered(self, btxt, btn.get_center().x, btn.position.y + 5.0, bcol, 1)


func _draw_lead_shop() -> void:
	LxBubble.draw_icon(self, "pane", Vector2(PANEL.position.x + 7.0, PANEL.position.y + 5.0), 1.0)
	LxPixelFont.draw(self, LxStrings.text("HUB_LEAD_TITLE"), Vector2(PANEL.position.x + 20.0, PANEL.position.y + 7.0), LxPalette.PAL["gold"], 1)
	var pm: LxPanes = LxPanes.current()
	var sh: int = Lx.state.shards if Lx.state != null else 0
	var max_l: int = pm.get_max_lead()
	LxPixelFont.draw(self, LxStrings.fmt("HUB_LEAD_STATS", [max_l, LxPanes.MAX_LEAD_CAP, sh]), Vector2(PANEL.position.x + 18.0, PANEL.position.y + 28.0), LxPalette.PAL["cream"], 1)
	LxPixelFont.draw(self, LxStrings.text("HUB_LEAD_DESC"), Vector2(PANEL.position.x + 18.0, PANEL.position.y + 42.0), LxPalette.PAL["stone"], 1)

	# Lead pips meter (void-backed with specular highlight when filled)
	for li: int in range(LxPanes.MAX_LEAD_CAP):
		var px: float = roundf(PANEL.position.x + 18.0 + float(li * 10))
		var py: float = roundf(PANEL.position.y + 54.0)
		var lit: bool = li < max_l
		draw_rect(Rect2(px, py, 8.0, 7.0), LxPalette.PAL["void"])
		draw_rect(Rect2(px + 1.0, py + 1.0, 6.0, 5.0), LxPalette.PAL["gold"] if lit else LxPalette.PAL["dusk"])
		if lit:
			draw_rect(Rect2(px + 1.0, py + 1.0, 6.0, 1.0), LxPalette.PAL["cream"])

	var price: int = LxHubState.get_next_lead_price()
	var b0: Rect2 = _lead_btn_rect(0)
	LxPixelFont.draw_panel(self, b0, "plum" if _idx == 0 else "void", "gold" if _idx == 0 else "dusk", "void")
	var buy_lbl: String = LxStrings.text("HUB_LEAD_SOLD_OUT") if price < 0 else LxStrings.fmt("HUB_LEAD_BUY_FMT", [price])
	var buy_col: Color = LxPalette.PAL["lime"] if (price > 0 and sh >= price) else LxPalette.PAL["stone"]
	LxPixelFont.draw(self, buy_lbl, Vector2(b0.position.x + 8.0, b0.position.y + 8.0), buy_col, 1)

	var b1: Rect2 = _lead_btn_rect(1)
	LxPixelFont.draw_panel(self, b1, "plum" if _idx == 1 else "void", "gold" if _idx == 1 else "dusk", "void")
	LxPixelFont.draw(self, LxStrings.text("HUB_LEAD_OPEN_BENCH"), Vector2(b1.position.x + 8.0, b1.position.y + 8.0), LxPalette.PAL["ice"], 1)


func _draw_tailor() -> void:
	LxBubble.draw_icon(self, "flame", Vector2(PANEL.position.x + 7.0, PANEL.position.y + 5.0), 1.0)
	LxPixelFont.draw(self, LxStrings.text("HUB_TAILOR_TITLE"), Vector2(PANEL.position.x + 20.0, PANEL.position.y + 7.0), LxPalette.PAL["rose"], 1)
	var sh: int = Lx.state.shards if Lx.state != null else 0
	var eq: String = LxHubState.get_equipped_flame()
	LxPixelFont.draw(self, LxStrings.fmt("HUB_TAILOR_SHARDS", [sh]), Vector2(PANEL.position.x + 16.0, PANEL.position.y + 24.0), LxPalette.PAL["stone"], 1)

	for i: int in range(LxHubState.FLAME_CATALOG.size()):
		var spec: Dictionary = LxHubState.FLAME_CATALOG[i]
		var fid: String = str(spec["id"])
		var owned: bool = LxHubState.is_flame_owned(fid)
		var is_eq: bool = fid == eq
		var sel: bool = i == _idx
		var r: Rect2 = _tailor_tile_rect(i)
		var tile_fill: String = "plum" if sel else ("dusk" if is_eq else "void")
		var tile_bdr: String = "gold" if sel else ("lime" if is_eq else ("mauve" if owned else "dusk"))
		LxPixelFont.draw_panel(self, r, tile_fill, tile_bdr, "void")
		if is_eq:
			draw_rect(Rect2(r.end.x - 6.0, r.position.y + 3.0, 3.0, 3.0), LxPalette.PAL["lime"])
			draw_rect(Rect2(r.end.x - 5.0, r.position.y + 4.0, 1.0, 1.0), LxPalette.PAL["cream"])
		# Miniature lantern flame swatch (pixel-snapped)
		var sx: float = roundf(r.position.x + r.size.x * 0.5)
		var sy: float = roundf(r.position.y + 11.0)
		draw_rect(Rect2(sx - 5.0, sy - 5.0, 10.0, 10.0), LxPalette.PAL["void"])
		draw_rect(Rect2(sx - 4.0, sy - 4.0, 8.0, 8.0), LxPalette.color(str(spec["rim"]), "apricot"))
		draw_rect(Rect2(sx - 3.0, sy - 3.0, 6.0, 6.0), LxPalette.color(fid, "gold"))
		draw_rect(Rect2(sx - 1.0, sy - 1.0, 2.0, 2.0), LxPalette.color(str(spec["core"]), "cream"))
		var tag: String = LxStrings.text("HUB_FLAME_ON") if is_eq else (LxStrings.text("HUB_FLAME_USE") if owned else "%dS" % int(spec["price"]))
		var tc: Color = LxPalette.PAL["lime"] if is_eq else (LxPalette.PAL["cream"] if owned else LxPalette.PAL["gold"])
		LxPixelFont.draw_centered(self, tag, roundf(r.position.x + r.size.x * 0.5), roundf(r.position.y + 21.0), tc, 1)

	if _idx >= 0 and _idx < LxHubState.FLAME_CATALOG.size():
		var cur_n: String = LxStrings.text(str(LxHubState.FLAME_CATALOG[_idx]["name_key"]))
		LxPixelFont.draw_centered(self, cur_n, PANEL.position.x + PANEL.size.x * 0.5, PANEL.end.y - 26.0, LxPalette.color(str(LxHubState.FLAME_CATALOG[_idx]["id"]), "gold"), 1)
