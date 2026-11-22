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
var _elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	_idx = 0
	_elapsed = 0.0
	visible = true
	_play_ui_sfx("ui_pause")
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = (event as InputEventMouseMotion).position
		for i: int in range(ITEMS.size()):
			if _row_rect(i).has_point(p):
				if _idx != i:
					_idx = i
					_play_ui_sfx("ui_move")
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
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_ui_sfx("ui_back")
			resume_requested.emit()
			get_viewport().set_input_as_handled()
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
	_draw_dimmed_frame()
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", "mauve", "night")
	_draw_brass_filigree()
	LxPixelFont.draw_centered(self, LxStrings.text("PAUSE_TITLE"), 160.0, PANEL_RECT.position.y + 8.0, LxPalette.PAL["gold"], 2)
	for i: int in range(ITEMS.size()):
		var r: Rect2 = _row_rect(i)
		var sel: bool = i == _idx
		if sel:
			LxPixelFont.draw_panel(self, r, "plum", "gold", "night")
			_draw_wick_lantern(r.position.x + 5.0, r.position.y + 2.0)
			_draw_wick_lantern(r.end.x - 12.0, r.position.y + 2.0)
		var col: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
		LxPixelFont.draw_centered(self, LxStrings.text(ITEMS[i]), r.get_center().x, r.position.y + 3.0, col, 1)
	LxPixelFont.draw_centered(self, LxStrings.text("PAUSE_HINT"), 160.0, PANEL_RECT.end.y - 10.0, LxPalette.PAL["stone"], 1)


func _draw_dimmed_frame() -> void:
	var v: Color = LxPalette.PAL["void"]
	var n: Color = LxPalette.PAL["night"]
	# Subtle pixel-stepped atmospheric frame border on viewport edges.
	draw_rect(Rect2(0.0, 0.0, 320.0, 2.0), v)
	draw_rect(Rect2(0.0, 178.0, 320.0, 2.0), v)
	draw_rect(Rect2(0.0, 2.0, 2.0, 176.0), v)
	draw_rect(Rect2(318.0, 2.0, 2.0, 176.0), v)
	for c: Vector2 in [Vector2(2.0, 2.0), Vector2(314.0, 2.0), Vector2(2.0, 174.0), Vector2(314.0, 174.0)]:
		draw_rect(Rect2(c, Vector2(4.0, 4.0)), n)
	# Recessed drop shadow + outer void rim behind pause panel.
	draw_rect(Rect2(PANEL_RECT.position + Vector2(3.0, 3.0), PANEL_RECT.size), v)
	draw_rect(PANEL_RECT.grow(1.0), v)


func _draw_brass_filigree() -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	# Corner brass brackets (gold tips + apricot arms).
	draw_rect(Rect2(p.x + 1.0, p.y + 1.0, 6.0, 1.0), apr)
	draw_rect(Rect2(p.x + 1.0, p.y + 1.0, 1.0, 6.0), apr)
	draw_rect(Rect2(e.x - 7.0, p.y + 1.0, 6.0, 1.0), apr)
	draw_rect(Rect2(e.x - 2.0, p.y + 1.0, 1.0, 6.0), apr)
	draw_rect(Rect2(p.x + 1.0, e.y - 2.0, 6.0, 1.0), apr)
	draw_rect(Rect2(p.x + 1.0, e.y - 7.0, 1.0, 6.0), apr)
	draw_rect(Rect2(e.x - 7.0, e.y - 2.0, 6.0, 1.0), apr)
	draw_rect(Rect2(e.x - 2.0, e.y - 7.0, 1.0, 6.0), apr)
	for tip: Vector2 in [
		Vector2(p.x + 1.0, p.y + 1.0), Vector2(e.x - 3.0, p.y + 1.0),
		Vector2(p.x + 1.0, e.y - 3.0), Vector2(e.x - 3.0, e.y - 3.0),
	]:
		draw_rect(Rect2(tip, Vector2(2.0, 2.0)), gold)
	# Decorative lantern-chain divider under PAUSE_TITLE.
	var cy: float = p.y + 21.0
	draw_rect(Rect2(p.x + 14.0, cy, PANEL_RECT.size.x - 28.0, 1.0), night)
	var x: float = p.x + 16.0
	while x < e.x - 16.0:
		draw_rect(Rect2(x, cy, 2.0, 1.0), apr if int(x) % 8 == 0 else dusk)
		draw_rect(Rect2(x + 2.0, cy + 1.0, 1.0, 1.0), night)
		x += 4.0
	draw_rect(Rect2(p.x + 13.0, cy - 1.0, 2.0, 3.0), gold)
	draw_rect(Rect2(e.x - 15.0, cy - 1.0, 2.0, 3.0), gold)
	var glow: bool = fmod(_elapsed * 2.2, 1.0) < 0.55
	draw_rect(Rect2(158.0, cy, 5.0, 1.0), apr)
	draw_rect(Rect2(159.0, cy - 1.0, 3.0, 3.0), gold)
	draw_rect(Rect2(160.0, cy, 1.0, 1.0), LxPalette.PAL["cream"] if glow else gold)


func _draw_wick_lantern(ox: float, oy: float) -> void:
	var x: float = roundf(ox)
	var y: float = roundf(oy)
	var bright: bool = fmod(_elapsed * 2.4, 1.0) < 0.55
	var shift: float = 0.0 if fmod(_elapsed * 4.8, 1.0) < 0.5 else 1.0
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 5.0), LxPalette.PAL["night"])
	draw_rect(Rect2(x + 2.0, y, 3.0, 1.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 1.0, y + 2.0, 1.0, 4.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 5.0, y + 2.0, 1.0, 4.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 1.0, y + 6.0, 5.0, 1.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 3.0, y, 1.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 1.0, y + 1.0, 5.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 6.0, 3.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 4.0), LxPalette.PAL["gold"] if bright else LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 3.0, y + 2.0, 1.0, 3.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x + 2.0 + shift, y + 3.0, 1.0, 1.0), LxPalette.PAL["cream"])
	if bright:
		draw_rect(Rect2(x, y + 3.0, 1.0, 1.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(x + 6.0, y + 3.0, 1.0, 1.0), LxPalette.PAL["gold"])


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL_RECT.position.x + 12.0, PANEL_RECT.position.y + 26.0 + float(i) * 16.0, PANEL_RECT.size.x - 24.0, 12.0)


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
