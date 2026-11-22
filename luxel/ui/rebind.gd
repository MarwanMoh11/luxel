class_name LxRebindScreen
extends Node2D
## Keyboard, mouse, and gamepad input rebinding screen (SWARM_SPEC 3.9).

signal closed()
signal bindings_updated()

const ACTION_ROWS: Array[Array] = [
	["lx_move_up", "ACT_MOVE_UP"],
	["lx_move_down", "ACT_MOVE_DOWN"],
	["lx_move_left", "ACT_MOVE_LEFT"],
	["lx_move_right", "ACT_MOVE_RIGHT"],
	["lx_fire", "ACT_FIRE"],
	["lx_throw", "ACT_THROW"],
	["lx_dash", "ACT_DASH"],
	["lx_beam", "ACT_BEAM"],
	["lx_sunflare", "ACT_SUNFLARE"],
	["lx_interact", "ACT_INTERACT"],
	["lx_pause", "ACT_PAUSE"],
	["lx_map", "ACT_MAP"],
]

const PANEL_RECT := Rect2(18.0, 10.0, 284.0, 160.0)
const VISIBLE_ROWS: int = 8

var device_kind: String = "kbm" # "kbm" or "gamepad"
var _idx: int = 0
var _scroll: int = 0
var _listening: bool = false
var _blink_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if Lx.input != null:
		device_kind = Lx.input.last_device
	_idx = 0
	_scroll = 0
	_listening = false
	visible = true
	queue_redraw()


func close() -> void:
	_listening = false
	visible = false


func _total_rows() -> int:
	return ACTION_ROWS.size() + 1 # +1 for reset defaults row


func _process(delta: float) -> void:
	if not visible:
		return
	if _listening:
		_blink_t += delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening:
		_capture_binding(event)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var m_total: int = _total_rows()
		for vis_i: int in range(VISIBLE_ROWS):
			var row_i: int = _scroll + vis_i
			if row_i >= m_total:
				break
			if _row_rect(vis_i).has_point(pos):
				if _idx != row_i:
					_idx = row_i
					_play_ui_sfx("ui_move")
					queue_redraw()
				return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_click(mb.position):
				get_viewport().set_input_as_handled()
		return

	var total: int = _total_rows()
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + total) % total
		_sync_scroll()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % total
		_sync_scroll()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or event.is_action_pressed("lx_move_right") or _key_just(event, KEY_LEFT) or _key_just(event, KEY_RIGHT):
		device_kind = "gamepad" if device_kind == "kbm" else "kbm"
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("ui_back")
		closed.emit()
		get_viewport().set_input_as_handled()


func _activate_current() -> void:
	if _idx >= ACTION_ROWS.size():
		if Lx.input != null:
			Lx.input.register_default_actions()
			_persist_bindings()
		_play_ui_sfx("ui_confirm")
		bindings_updated.emit()
		queue_redraw()
		return
	_listening = true
	_blink_t = 0.0
	_play_ui_sfx("ui_confirm")
	queue_redraw()


func _capture_binding(event: InputEvent) -> void:
	if _key_just(event, KEY_ESCAPE):
		_listening = false
		_play_ui_sfx("ui_back")
		queue_redraw()
		return

	var captured: InputEvent = null
	if device_kind == "kbm":
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var k := InputEventKey.new()
			var src_k: InputEventKey = event as InputEventKey
			k.physical_keycode = src_k.physical_keycode if src_k.physical_keycode != KEY_NONE else src_k.keycode
			k.keycode = k.physical_keycode
			captured = k
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var m := InputEventMouseButton.new()
			m.button_index = (event as InputEventMouseButton).button_index
			captured = m
	else:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			var jb := InputEventJoypadButton.new()
			jb.button_index = (event as InputEventJoypadButton).button_index
			captured = jb
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.55:
			var jm := InputEventJoypadMotion.new()
			var src_jm: InputEventJoypadMotion = event as InputEventJoypadMotion
			jm.axis = src_jm.axis
			jm.axis_value = 1.0 if src_jm.axis_value > 0.0 else -1.0
			captured = jm

	if captured == null:
		return

	var action_id: String = str(ACTION_ROWS[_idx][0])
	if Lx.input != null:
		Lx.input.rebind_action(action_id, captured, device_kind)
		_persist_bindings()
	_listening = false
	_play_ui_sfx("ui_confirm")
	bindings_updated.emit()
	queue_redraw()


func _persist_bindings() -> void:
	if Lx.save == null or Lx.input == null:
		return
	Lx.save.settings["bindings"] = Lx.input.export_bindings()
	Lx.save.save_settings()


func _handle_click(pos: Vector2) -> bool:
	if Rect2(26.0, 24.0, 268.0, 12.0).has_point(pos):
		device_kind = "gamepad" if device_kind == "kbm" else "kbm"
		_play_ui_sfx("ui_move")
		queue_redraw()
		return true
	var total: int = _total_rows()
	for vis_i: int in range(VISIBLE_ROWS):
		var row_i: int = _scroll + vis_i
		if row_i >= total:
			break
		if _row_rect(vis_i).has_point(pos):
			_idx = row_i
			_activate_current()
			return true
	return false


func _sync_scroll() -> void:
	if _idx < _scroll:
		_scroll = _idx
	elif _idx >= _scroll + VISIBLE_ROWS:
		_scroll = _idx - VISIBLE_ROWS + 1


func _draw() -> void:
	var pulse_hi: bool = fmod(_blink_t, 0.5) < 0.25
	draw_rect(Rect2(PANEL_RECT.position + Vector2(3.0, 3.0), PANEL_RECT.size), LxPalette.PAL["void"])
	draw_rect(PANEL_RECT.grow(1.0), LxPalette.PAL["void"])
	var panel_border: String = ("gold" if pulse_hi else "apricot") if _listening else "mauve"
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", panel_border, "night")
	_draw_frame_ornaments()
	LxPixelFont.draw_centered(self, LxStrings.text("REBIND_TITLE"), 160.0, 15.0, LxPalette.PAL["gold"], 1)

	var dev_key: String = "REBIND_DEVICE_KBM" if device_kind == "kbm" else "REBIND_DEVICE_PAD"
	var dev_rect := Rect2(26.0, 24.0, 268.0, 12.0)
	LxPixelFont.draw_panel(self, dev_rect, "night", "sky", "void")
	LxPixelFont.draw_centered(self, LxStrings.text(dev_key), 160.0, 27.0, LxPalette.PAL["ice"], 1)

	var total: int = _total_rows()
	for vis_i: int in range(VISIBLE_ROWS):
		var row_i: int = _scroll + vis_i
		if row_i >= total:
			break
		var r: Rect2 = _row_rect(vis_i)
		var sel: bool = row_i == _idx
		if sel:
			var row_bdr: String = ("cream" if pulse_hi else "gold") if _listening else "gold"
			LxPixelFont.draw_panel(self, r, "plum", row_bdr, "night")
		if row_i >= ACTION_ROWS.size():
			LxPixelFont.draw_centered(self, LxStrings.text("REBIND_RESET"), r.get_center().x, r.position.y + 3.0, LxPalette.PAL["coral"] if sel else LxPalette.PAL["stone"], 1)
		else:
			var act_id: String = str(ACTION_ROWS[row_i][0])
			var lbl_id: String = str(ACTION_ROWS[row_i][1])
			if sel:
				draw_rect(Rect2(r.position.x + 3.0, r.position.y + 3.0, 2.0, 6.0), LxPalette.PAL["gold"])
				draw_rect(Rect2(r.position.x + 3.0, r.position.y + 4.0, 1.0, 4.0), LxPalette.PAL["cream"])
			var lx: float = 8.0 if sel else 6.0
			LxPixelFont.draw_left(self, LxStrings.text(lbl_id), r.position + Vector2(lx, 3.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)
			_draw_keycap(r, _binding_glyph(act_id), sel)

	# Scrollbar indicator.
	if total > VISIBLE_ROWS:
		var track := Rect2(292.0, 40.0, 3.0, float(VISIBLE_ROWS * 14) - 2.0)
		draw_rect(track.grow(1.0), LxPalette.PAL["night"])
		draw_rect(track, LxPalette.PAL["void"])
		var thumb_h: float = maxf(10.0, track.size.y * float(VISIBLE_ROWS) / float(total))
		var frac: float = float(_scroll) / float(maxi(1, total - VISIBLE_ROWS))
		var thumb_y: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, roundf(thumb_h)), LxPalette.PAL["gold"])
		draw_rect(Rect2(track.position.x, thumb_y, track.size.x, 1.0), LxPalette.PAL["cream"])

	if _listening:
		_draw_listen_modal(pulse_hi)

	LxPixelFont.draw_centered(self, LxStrings.text("REBIND_HINT"), 160.0, 159.0, LxPalette.PAL["stone"], 1)


func _draw_frame_ornaments() -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	for c: Array in [
		[p.x + 1.0, p.y + 1.0, 1.0, 1.0], [e.x - 2.0, p.y + 1.0, -1.0, 1.0],
		[p.x + 1.0, e.y - 2.0, 1.0, -1.0], [e.x - 2.0, e.y - 2.0, -1.0, -1.0],
	]:
		var cx: float = float(c[0])
		var cy0: float = float(c[1])
		var sx: float = float(c[2])
		var sy: float = float(c[3])
		draw_rect(Rect2(cx if sx > 0.0 else cx - 4.0, cy0, 5.0, 1.0), apr)
		draw_rect(Rect2(cx, cy0 if sy > 0.0 else cy0 - 4.0, 1.0, 5.0), apr)
		draw_rect(Rect2(cx if sx > 0.0 else cx - 1.0, cy0 if sy > 0.0 else cy0 - 1.0, 2.0, 2.0), gold)
		var rv := Vector2(cx + sx * 2.0 - (0.0 if sx > 0.0 else 1.0), cy0 + sy * 2.0 - (0.0 if sy > 0.0 else 1.0))
		draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), night)
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), apr)
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), gold)
	# Lantern-chain divider under REBIND_TITLE.
	var cy: float = 22.0
	draw_rect(Rect2(p.x + 12.0, cy, PANEL_RECT.size.x - 24.0, 1.0), night)
	var x: float = p.x + 16.0
	while x < e.x - 16.0:
		draw_rect(Rect2(x, cy, 2.0, 1.0), apr if int(x) % 8 == 0 else dusk)
		x += 4.0
	draw_rect(Rect2(p.x + 12.0, cy, 2.0, 1.0), gold)
	draw_rect(Rect2(e.x - 14.0, cy, 2.0, 1.0), gold)
	draw_rect(Rect2(158.0, cy, 5.0, 1.0), apr)
	draw_rect(Rect2(159.0, cy, 3.0, 1.0), gold)
	draw_rect(Rect2(160.0, cy, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_keycap(r: Rect2, glyph: String, sel: bool) -> void:
	var gw: float = float(LxPixelFont.width(glyph, 1))
	var cap_w: float = maxf(16.0, gw + 8.0)
	var cap := Rect2(roundf(r.end.x - 5.0 - cap_w), r.position.y + 1.0, cap_w, 10.0)
	draw_rect(cap, LxPalette.PAL["void"])
	var inner := Rect2(cap.position.x + 1.0, cap.position.y + 1.0, cap.size.x - 2.0, cap.size.y - 2.0)
	draw_rect(inner, LxPalette.PAL["night"])
	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 1.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["mauve"])
	draw_rect(Rect2(inner.position.x, inner.end.y - 1.0, inner.size.x, 1.0), LxPalette.PAL["void"])
	LxPixelFont.draw_centered(self, glyph, cap.get_center().x, r.position.y + 3.0, LxPalette.PAL["cream"] if sel else LxPalette.PAL["apricot"], 1)


func _draw_listen_modal(pulse_hi: bool) -> void:
	var box := Rect2(54.0, 72.0, 212.0, 26.0)
	var phase: int = int(floorf(_blink_t * 6.0)) % 4
	var bdr: String = "cream" if phase == 0 else ("apricot" if phase == 2 else "gold")
	draw_rect(Rect2(box.position + Vector2(3.0, 3.0), box.size), LxPalette.PAL["void"])
	draw_rect(box.grow(2.0), LxPalette.PAL["void"])
	draw_rect(box.grow(1.0), LxPalette.PAL["gold"] if pulse_hi else LxPalette.PAL["apricot"])
	LxPixelFont.draw_panel(self, box, "night", bdr, "void")
	var pip: Color = LxPalette.PAL["cream"] if pulse_hi else LxPalette.PAL["gold"]
	for c: Vector2 in [
		Vector2(box.position.x + 2.0, box.position.y + 2.0), Vector2(box.end.x - 4.0, box.position.y + 2.0),
		Vector2(box.position.x + 2.0, box.end.y - 4.0), Vector2(box.end.x - 4.0, box.end.y - 4.0),
	]:
		draw_rect(Rect2(c, Vector2(2.0, 2.0)), pip)
	LxPixelFont.draw_centered(self, LxStrings.text("REBIND_LISTEN"), 160.0, 82.0, LxPalette.PAL["gold"] if pulse_hi else LxPalette.PAL["cream"], 1)


func _binding_glyph(action_id: String) -> String:
	if not InputMap.has_action(action_id):
		return "-"
	var want_pad: bool = device_kind == "gamepad"
	for ev: InputEvent in InputMap.action_get_events(action_id):
		var is_pad: bool = ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad == want_pad:
			return LxStrings.sanitize(LxInputService.event_to_glyph(ev), 12)
	return "-"


func _row_rect(vis_i: int) -> Rect2:
	return Rect2(26.0, 40.0 + float(vis_i) * 14.0, 262.0, 12.0)


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
