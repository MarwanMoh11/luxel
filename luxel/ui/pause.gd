class_name LxPauseMenu
extends Node2D
## Pause overlay: Resume, Map, Options, Retry Checkpoint, Title.

signal resume_requested()
signal map_requested()
signal options_requested()
signal retry_checkpoint_requested()
signal title_requested()

const ITEMS: Array[String] = [
	"PAUSE_RESUME",
	"PAUSE_MAP",
	"PAUSE_OPTIONS",
	"PAUSE_RETRY",
	"PAUSE_TITLE_BTN",
]

const PANEL_RECT := Rect2(84.0, 30.0, 152.0, 120.0)

var _idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_idx = 0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = (event as InputEventMouseMotion).position
		for i: int in range(ITEMS.size()):
			if _row_rect(i).has_point(p):
				if _idx != i:
					_idx = i
					queue_redraw()
				return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i: int in range(ITEMS.size()):
				if _row_rect(i).has_point(mb.position):
					_idx = i
					_activate(_idx)
					get_viewport().set_input_as_handled()
					return
		return

	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + ITEMS.size()) % ITEMS.size()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % ITEMS.size()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate(_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("ui_back")
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _activate(i: int) -> void:
	_play_ui_sfx("ui_confirm")
	match i:
		0:
			resume_requested.emit()
		1:
			map_requested.emit()
		2:
			options_requested.emit()
		3:
			retry_checkpoint_requested.emit()
		4:
			title_requested.emit()


func _draw() -> void:
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", "mauve", "night")
	LxPixelFont.draw_centered(self, LxStrings.text("PAUSE_TITLE"), 160.0, PANEL_RECT.position.y + 8.0, LxPalette.PAL["gold"], 2)
	for i: int in range(ITEMS.size()):
		var r: Rect2 = _row_rect(i)
		var sel: bool = i == _idx
		if sel:
			LxPixelFont.draw_panel(self, r, "plum", "gold", "night")
			draw_rect(Rect2(r.position.x + 5.0, r.position.y + 4.0, 3.0, 3.0), LxPalette.PAL["cream"])
		var col: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
		LxPixelFont.draw_centered(self, LxStrings.text(ITEMS[i]), r.get_center().x, r.position.y + 3.0, col, 1)
	LxPixelFont.draw_centered(self, LxStrings.text("PAUSE_HINT"), 160.0, PANEL_RECT.end.y - 10.0, LxPalette.PAL["stone"], 1)


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL_RECT.position.x + 12.0, PANEL_RECT.position.y + 26.0 + float(i) * 16.0, PANEL_RECT.size.x - 24.0, 12.0)


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
