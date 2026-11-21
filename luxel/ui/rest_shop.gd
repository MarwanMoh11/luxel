class_name LxRestShop
extends Node2D
## Lamplighter's Rest upgrade shrine reading luxel/data/upgrades.json (SWARM_SPEC 3.5).

signal closed()
signal upgrade_bought(upgrade_id: String, new_rank: int)

const PANEL_RECT := Rect2(20.0, 12.0, 280.0, 156.0)

var _upgrades: Array[Dictionary] = []
var _idx: int = 0
var _close_hover: bool = false
var _feedback_key: String = ""
var _feedback_col: String = "lime"
var _feedback_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_load_upgrades()
	_idx = 0
	_feedback_key = ""
	_feedback_t = 0.0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _load_upgrades() -> void:
	_upgrades.clear()
	if Lx.data_upgrades.is_empty():
		Lx.load_all_data()
	var arr: Variant = Lx.data_upgrades.get("upgrades", [])
	if arr is Array:
		for item: Variant in (arr as Array):
			if item is Dictionary:
				_upgrades.append(item as Dictionary)


func _process(delta: float) -> void:
	if not visible:
		return
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - delta)
		if _feedback_t <= 0.0:
			_feedback_key = ""
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var over_close: bool = _close_btn_rect().has_point(pos)
		if over_close != _close_hover:
			_close_hover = over_close
			queue_redraw()
		for i: int in range(_upgrades.size()):
			if _row_rect(i).has_point(pos):
				if _idx != i:
					_idx = i
					queue_redraw()
				return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _close_btn_rect().has_point(mb.position):
				_play_ui_sfx("ui_back")
				closed.emit()
				get_viewport().set_input_as_handled()
				return
			for i: int in range(_upgrades.size()):
				if _row_rect(i).has_point(mb.position):
					_idx = i
					_try_buy(_idx)
					get_viewport().set_input_as_handled()
					return
		return

	var count: int = maxi(1, _upgrades.size())
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + count) % count
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % count
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_try_buy(_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("ui_back")
		closed.emit()
		get_viewport().set_input_as_handled()


func _try_buy(i: int) -> void:
	if i < 0 or i >= _upgrades.size() or Lx.state == null:
		return
	var u: Dictionary = _upgrades[i]
	var uid: String = str(u.get("id", ""))
	if Lx.state.buy_upgrade(uid):
		var new_rank: int = Lx.state.get_upgrade_rank(uid)
		_feedback_key = "SHOP_BOUGHT"
		_feedback_col = "lime"
		_feedback_t = 1.6
		_play_ui_sfx("ui_confirm")
		if Lx.events != null:
			Lx.events.save_requested.emit("upgrade")
		upgrade_bought.emit(uid, new_rank)
	else:
		_feedback_key = "SHOP_MAXED" if Lx.state.get_upgrade_rank(uid) >= int(u.get("max_rank", 0)) else "SHOP_NO_SHARDS"
		_feedback_col = "stone" if _feedback_key == "SHOP_MAXED" else "coral"
		_feedback_t = 1.2
		_play_ui_sfx("ui_back")
	queue_redraw()


func _draw() -> void:
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", "gold", "night")
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_TITLE"), Vector2(28.0, 18.0), LxPalette.PAL["gold"], 1)
	var shards: int = Lx.state.shards if Lx.state != null else 0
	LxPixelFont.draw_right(self, LxStrings.fmt("SHOP_SHARDS_FMT", [shards]), 292.0, 18.0, LxPalette.PAL["apricot"], 1)
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_SUBTITLE"), Vector2(28.0, 27.0), LxPalette.PAL["stone"], 1)

	for i: int in range(_upgrades.size()):
		_draw_upgrade_row(i, _upgrades[i])

	# Selected item description box.
	var desc_rect := Rect2(28.0, 134.0, 264.0, 18.0)
	LxPixelFont.draw_panel(self, desc_rect, "night", "mauve", "void")
	if not _feedback_key.is_empty():
		LxPixelFont.draw_centered(self, LxStrings.text(_feedback_key), 160.0, 140.0, LxPalette.color(_feedback_col), 1)
	elif _idx >= 0 and _idx < _upgrades.size():
		var desc_key: String = str(_upgrades[_idx].get("desc_key", ""))
		LxPixelFont.draw_centered(self, LxStrings.text(desc_key), 160.0, 140.0, LxPalette.PAL["cream"], 1)

	LxPixelFont.draw_left(self, LxStrings.text("SHOP_BUY_HINT"), Vector2(28.0, 157.0), LxPalette.PAL["stone"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxStrings.text("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)


func _draw_upgrade_row(i: int, u: Dictionary) -> void:
	var r: Rect2 = _row_rect(i)
	var sel: bool = i == _idx
	var uid: String = str(u.get("id", ""))
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var max_rank: int = int(u.get("max_rank", 1))
	var costs: Array = u.get("costs", []) as Array
	var maxed: bool = rank >= max_rank
	var affordable: bool = Lx.state != null and Lx.state.can_buy_upgrade(uid)

	if sel:
		LxPixelFont.draw_panel(self, r, "plum", "gold", "night")
	else:
		LxPixelFont.draw_panel(self, r, "night", "dusk", "void")

	var name_key: String = str(u.get("name_key", ""))
	var name_col: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
	LxPixelFont.draw_left(self, LxStrings.text(name_key), r.position + Vector2(6.0, 4.0), name_col, 1)

	# Rank pips.
	var pip_x: float = r.position.x + 150.0
	for p: int in range(max_rank):
		var pr := Rect2(pip_x + float(p * 8), r.position.y + 4.0, 5.0, 5.0)
		draw_rect(pr.grow(1.0), LxPalette.PAL["void"])
		draw_rect(pr, LxPalette.PAL["gold"] if p < rank else LxPalette.PAL["dusk"])

	if maxed:
		LxPixelFont.draw_right(self, LxStrings.text("SHOP_MAXED"), r.end.x - 6.0, r.position.y + 4.0, LxPalette.PAL["lime"], 1)
	else:
		var cost: int = int(costs[rank]) if rank < costs.size() else 0
		var c_col: Color = LxPalette.PAL["gold"] if affordable else LxPalette.PAL["coral"]
		LxPixelFont.draw_right(self, LxStrings.fmt("SHOP_COST_FMT", [cost]), r.end.x - 6.0, r.position.y + 4.0, c_col, 1)


func _row_rect(i: int) -> Rect2:
	return Rect2(28.0, 38.0 + float(i) * 15.0, 264.0, 13.0)


func _close_btn_rect() -> Rect2:
	return Rect2(230.0, 154.0, 62.0, 11.0)


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
