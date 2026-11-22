class_name LxTitleScreen
extends Node2D
## Title screen with west-to-east LUXEL luxel wordmark, 3-slot save selector,
## delete confirmation, Options, and Quit.

signal slot_selected(slot_num: int, is_new_game: bool)
signal options_requested()
signal quit_requested()

enum Mode { MAIN, SLOTS, CONFIRM_DELETE }

const MAIN_ITEMS: Array[String] = ["TITLE_PLAY", "TITLE_OPTIONS", "TITLE_QUIT"]
const SLOT_COUNT: int = 3
const MOON_ROWS: Array[String] = [
	"...CIIS", "..CCII", ".CCIS", ".CIS", "CCIS", "CCI", "CCI", "CCI", "CCIS", ".CIS", ".CCIS", "..CCII", "...CIIS",
]

var mode: int = Mode.MAIN
var _elapsed: float = 0.0
var _main_idx: int = 0
var _slot_idx: int = 0
var _confirm_idx: int = 1 # 0 = YES, 1 = NO (safe default)
var _summaries: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _fireflies: Array[Dictionary] = []
var _wisps: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_backdrop()
	refresh_slots()


func open(show_slots: bool = false) -> void:
	visible = true
	mode = Mode.SLOTS if show_slots else Mode.MAIN
	_elapsed = 0.0
	_confirm_idx = 1
	refresh_slots()
	queue_redraw()


func close() -> void:
	visible = false


func refresh_slots() -> void:
	_summaries.clear()
	for i: int in range(1, SLOT_COUNT + 1):
		if Lx.save != null:
			_summaries.append(Lx.save.slot_summary(i))
		else:
			_summaries.append({"empty": true, "slot": i})
	queue_redraw()


func select_slot(slot_num: int) -> void:
	var idx: int = clampi(slot_num - 1, 0, SLOT_COUNT - 1)
	if idx >= _summaries.size():
		refresh_slots()
	var is_new: bool = bool(_summaries[idx].get("empty", true))
	_play_ui_sfx("ui_confirm")
	slot_selected.emit(idx + 1, is_new)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	for ff: Dictionary in _fireflies:
		ff["y"] = float(ff["y"]) - float(ff["spd"]) * delta
		if float(ff["y"]) < -4.0:
			ff["y"] = 182.0
	for w: Dictionary in _wisps:
		var nx: float = float(w["x"]) + float(w["spd"]) * delta
		if nx > 344.0:
			nx = -float(w["w"]) - 8.0
		w["x"] = nx
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_handle_mouse_hover((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_mouse_click(mb.position):
				get_viewport().set_input_as_handled()
		return

	if mode == Mode.MAIN:
		_input_main(event)
	elif mode == Mode.SLOTS:
		_input_slots(event)
	elif mode == Mode.CONFIRM_DELETE:
		_input_confirm(event)


func _input_main(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_main_idx = (_main_idx - 1 + MAIN_ITEMS.size()) % MAIN_ITEMS.size()
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_main_idx = (_main_idx + 1) % MAIN_ITEMS.size()
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate_main(_main_idx)
		get_viewport().set_input_as_handled()


func _activate_main(idx: int) -> void:
	_play_ui_sfx("ui_confirm")
	match idx:
		0:
			refresh_slots()
			mode = Mode.SLOTS
		1:
			options_requested.emit()
		2:
			quit_requested.emit()
	queue_redraw()


func _input_slots(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_slot_idx = (_slot_idx - 1 + SLOT_COUNT) % SLOT_COUNT
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_slot_idx = (_slot_idx + 1) % SLOT_COUNT
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		select_slot(_slot_idx + 1)
		get_viewport().set_input_as_handled()
	elif _key_just(event, KEY_DELETE) or _key_just(event, KEY_BACKSPACE) or _joy_just(event, JOY_BUTTON_X):
		if _slot_idx < _summaries.size() and not bool(_summaries[_slot_idx].get("empty", true)):
			mode = Mode.CONFIRM_DELETE
			_confirm_idx = 1
			_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		mode = Mode.MAIN
		_play_ui_sfx("ui_back")
		get_viewport().set_input_as_handled()


func _input_confirm(event: InputEvent) -> void:
	if event.is_action_pressed("lx_move_left") or event.is_action_pressed("lx_move_right") or _key_just(event, KEY_LEFT) or _key_just(event, KEY_RIGHT):
		_confirm_idx = 1 - _confirm_idx
		_play_ui_sfx("ui_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		if _confirm_idx == 0 and Lx.save != null:
			Lx.save.delete_slot(_slot_idx + 1)
			refresh_slots()
			_play_ui_sfx("ui_confirm")
		else:
			_play_ui_sfx("ui_back")
		mode = Mode.SLOTS
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		mode = Mode.SLOTS
		_play_ui_sfx("ui_back")
		get_viewport().set_input_as_handled()


func _handle_mouse_hover(pos: Vector2) -> void:
	if mode == Mode.MAIN:
		for i: int in range(MAIN_ITEMS.size()):
			if _main_btn_rect(i).has_point(pos):
				_main_idx = i
				return
	elif mode == Mode.SLOTS:
		for i: int in range(SLOT_COUNT):
			if _slot_rect(i).has_point(pos):
				_slot_idx = i
				return
	elif mode == Mode.CONFIRM_DELETE:
		for i: int in range(2):
			if _confirm_btn_rect(i).has_point(pos):
				_confirm_idx = i
				return


func _handle_mouse_click(pos: Vector2) -> bool:
	if mode == Mode.MAIN:
		for i: int in range(MAIN_ITEMS.size()):
			if _main_btn_rect(i).has_point(pos):
				_main_idx = i
				_activate_main(i)
				return true
	elif mode == Mode.SLOTS:
		for i: int in range(SLOT_COUNT):
			var del_r: Rect2 = _slot_del_rect(i)
			if i < _summaries.size() and not bool(_summaries[i].get("empty", true)) and del_r.has_point(pos):
				_slot_idx = i
				mode = Mode.CONFIRM_DELETE
				_confirm_idx = 1
				_play_ui_sfx("ui_move")
				return true
			if _slot_rect(i).has_point(pos):
				_slot_idx = i
				select_slot(i + 1)
				return true
	elif mode == Mode.CONFIRM_DELETE:
		if _confirm_btn_rect(0).has_point(pos):
			if Lx.save != null:
				Lx.save.delete_slot(_slot_idx + 1)
				refresh_slots()
			_play_ui_sfx("ui_confirm")
			mode = Mode.SLOTS
			return true
		if _confirm_btn_rect(1).has_point(pos):
			_play_ui_sfx("ui_back")
			mode = Mode.SLOTS
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	_draw_backdrop()

	if mode == Mode.MAIN:
		_draw_main()
	else:
		_draw_slots()
		if mode == Mode.CONFIRM_DELETE:
			_draw_confirm_delete()


func _px(rects: Array, col: Color) -> void:
	for r: Array in rects:
		draw_rect(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), col)


func _draw_backdrop() -> void:
	_draw_sky_and_moon()
	_draw_archipelago()
	_draw_sea()
	_draw_atmosphere()


func _draw_sky_and_moon() -> void:
	# Stepped twilight sky bands (warm western sunset, cool eastern moonlight).
	draw_rect(Rect2(0.0, 66.0, 320.0, 32.0), LxPalette.PAL["night"])
	draw_rect(Rect2(0.0, 98.0, 320.0, 48.0), LxPalette.PAL["dusk"])
	_draw_dither_band(0.0, 320.0, 64.0, LxPalette.PAL["night"])
	_draw_dither_band(0.0, 320.0, 96.0, LxPalette.PAL["dusk"])

	# Western sunset glow (plum -> wine -> warm coral/apricot rim), tapering east.
	draw_rect(Rect2(0.0, 122.0, 152.0, 14.0), LxPalette.PAL["plum"])
	_draw_dither_band(0.0, 168.0, 120.0, LxPalette.PAL["plum"])
	for row: int in range(7):
		var wy: float = 122.0 + float(row) * 2.0
		var x: float = 152.0 + float((row % 2) * 3)
		while x < 204.0 - float(row % 3) * 14.0:
			draw_rect(Rect2(x, wy, 4.0 if x < 176.0 else 2.0, 2.0), LxPalette.PAL["plum"])
			x += 6.0 if x < 176.0 else 8.0
	draw_rect(Rect2(0.0, 134.0, 114.0, 12.0), LxPalette.PAL["wine"])
	_draw_dither_band(0.0, 126.0, 132.0, LxPalette.PAL["wine"])
	for row: int in range(6):
		var ry: float = 134.0 + float(row) * 2.0
		var rw: float = 44.0 - float((row * 5) % 19)
		draw_rect(Rect2(112.0, ry, rw, 1.0), LxPalette.PAL["wine"])
		draw_rect(Rect2(114.0 + rw + 6.0, ry + 1.0, maxf(6.0, rw * 0.35), 1.0), LxPalette.PAL["wine"])
	draw_rect(Rect2(0.0, 143.0, 74.0, 3.0), LxPalette.PAL["coral"])
	_draw_dither_band(56.0, 108.0, 143.0, LxPalette.PAL["coral"])
	draw_rect(Rect2(0.0, 145.0, 42.0, 1.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(226.0, 126.0, 94.0, 20.0), LxPalette.PAL["deep"])
	_draw_dither_band(212.0, 320.0, 124.0, LxPalette.PAL["deep"])

	# Twinkling 1 px and 3 px cross-sparkle stars.
	for st: Dictionary in _stars:
		var sx: float = float(st["x"])
		var sy: float = float(st["y"])
		var phase: float = fmod(_elapsed + float(st["off"]), float(st["per"]))
		draw_rect(Rect2(sx, sy, 1.0, 1.0), LxPalette.color(str(st["hi"]) if phase < 0.48 else str(st["lo"])))
		if bool(st["cross"]) and phase < 0.34:
			var arm: Color = LxPalette.color(str(st["arm"]))
			_px([[sx - 1.0, sy, 1.0, 1.0], [sx + 1.0, sy, 1.0, 1.0], [sx, sy - 1.0, 1.0, 1.0], [sx, sy + 1.0, 1.0, 1.0]], arm)

	_draw_crescent_moon(269.0, 19.0)


func _draw_dither_band(x0: float, x1: float, y: float, col: Color) -> void:
	var x: float = x0
	while x < x1:
		draw_rect(Rect2(x, y, 2.0, 1.0), col)
		draw_rect(Rect2(x + 4.0, y + 1.0, 4.0, 1.0), col)
		x += 8.0


func _draw_crescent_moon(ox: float, oy: float) -> void:
	var halo: Color = LxPalette.PAL["blue"] if fmod(_elapsed, 2.4) < 1.2 else LxPalette.PAL["deep"]
	_px([[ox - 2.0, oy + 6.0, 1.0, 1.0], [ox + 3.0, oy - 2.0, 1.0, 1.0], [ox + 3.0, oy + 14.0, 1.0, 1.0]], halo)
	_px([[ox - 1.0, oy + 1.0, 1.0, 1.0], [ox - 1.0, oy + 11.0, 1.0, 1.0]], LxPalette.PAL["deep"])
	for r: int in range(MOON_ROWS.size()):
		var row: String = MOON_ROWS[r]
		for c: int in range(row.length()):
			var ch: String = row[c]
			if ch != ".":
				var col: Color = LxPalette.PAL["cream"] if ch == "C" else (LxPalette.PAL["ice"] if ch == "I" else LxPalette.PAL["sky"])
				draw_rect(Rect2(ox + float(c), oy + float(r), 1.0, 1.0), col)


func _draw_archipelago() -> void:
	var night: Color = LxPalette.PAL["night"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var plum: Color = LxPalette.PAL["plum"]
	var deep: Color = LxPalette.PAL["deep"]

	# Left floating island + Lighthouse silhouette.
	_px([[20, 134, 50, 3], [24, 139, 14, 2], [54, 129, 2, 2], [33, 119, 10, 1], [37, 113, 2, 1]], dusk)
	_px([[16, 136, 58, 6], [22, 142, 44, 3], [30, 145, 24, 2], [13, 143, 3, 2], [75, 141, 2, 2], [53, 131, 4, 4], [60, 132, 5, 3], [34, 128, 8, 7], [35, 120, 6, 8], [36, 115, 4, 4], [35, 114, 6, 1]], night)
	_px([[34, 128, 1, 6], [35, 120, 1, 8]], dusk)
	_px([[20, 134, 16, 1], [35, 124, 5, 1]], plum)
	draw_rect(Rect2(38.0, 112.0, 1.0, 1.0), LxPalette.PAL["mauve"])
	var lh_p: float = 0.5 + 0.5 * sin(_elapsed * 1.9)
	draw_rect(Rect2(37.0, 116.0, 2.0, 2.0), LxPalette.PAL["cream"] if lh_p > 0.72 else (LxPalette.PAL["gold"] if lh_p > 0.35 else LxPalette.PAL["apricot"]))
	if lh_p > 0.52:
		_px([[34, 117, 2, 1], [40, 117, 2, 1]], LxPalette.PAL["gold"] if lh_p > 0.78 else LxPalette.PAL["apricot"])

	# Center-left distant Observatory dome silhouette (clear of main buttons).
	_px([[78, 138, 36, 3], [86, 135, 14, 4], [87, 132, 12, 3], [89, 130, 8, 2]], dusk)
	_px([[75, 140, 40, 5], [83, 145, 24, 2]], night)
	_px([[91, 129, 4, 1], [87, 132, 1, 3], [89, 130, 2, 1], [95, 128, 2, 1]], LxPalette.PAL["mauve"])
	draw_rect(Rect2(96.0, 127.0, 2.0, 1.0), LxPalette.PAL["stone"])
	draw_rect(Rect2(90.0, 135.0, 1.0, 2.0), LxPalette.PAL["apricot"])

	# Right iconic Bell Isle floating cliff, Bell Tower belfry & bronze bell.
	_px([[236, 128, 62, 5], [284, 120, 7, 2], [243, 120, 2, 3], [250, 112, 26, 2], [249, 98, 28, 1]], dusk)
	_px([[228, 132, 78, 9], [238, 141, 58, 3], [248, 144, 38, 2], [258, 146, 16, 2], [225, 140, 3, 2], [304, 142, 2, 2], [282, 122, 11, 7], [242, 123, 4, 6], [252, 114, 22, 16], [253, 99, 20, 13]], night)
	_px([[234, 134, 22, 2], [252, 114, 1, 15], [253, 99, 1, 13], [257, 101, 12, 11], [259, 100, 8, 1]], dusk)
	_px([[236, 128, 20, 1], [253, 115, 1, 8], [250, 112, 6, 1]], plum)
	_px([[284, 129, 14, 2], [276, 136, 20, 2], [273, 114, 1, 15], [270, 112, 6, 1], [272, 99, 1, 13]], deep)
	_px([[262, 119, 2, 5], [264, 105, 2, 3]], LxPalette.PAL["wine"])
	_px([[286, 125, 2, 2], [262, 120, 2, 3], [261, 102, 4, 3]], LxPalette.PAL["apricot"])
	draw_rect(Rect2(260.0, 101.0, 6.0, 1.0), night)
	draw_rect(Rect2(260.0, 105.0, 4.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(262.0, 108.0, 2.0, 1.0), LxPalette.PAL["cream"])
	for step: int in range(9):
		var sw: float = roundf(24.0 - float(step) * 2.5)
		var sx: float = roundf(263.0 - sw * 0.5)
		var sy: float = 97.0 - float(step)
		draw_rect(Rect2(sx, sy, sw, 1.0), night)
		draw_rect(Rect2(sx, sy, 1.0, 1.0), LxPalette.PAL["mauve"] if step > 4 else dusk)
		draw_rect(Rect2(sx + sw - 1.0, sy, 1.0, 1.0), deep)
	draw_rect(Rect2(262.0, 85.0, 2.0, 4.0), LxPalette.PAL["mauve"])
	draw_rect(Rect2(261.0, 86.0, 4.0, 1.0), LxPalette.PAL["stone"])

	# Gently swaying glowing lantern hanging off the west belfry arm.
	draw_rect(Rect2(244.0, 105.0, 9.0, 1.0), night)
	draw_rect(Rect2(244.0, 106.0, 2.0, 1.0), dusk)
	var sway: float = roundf(sin(_elapsed * 1.55) * 1.2)
	var lx: float = 244.0 + sway
	var ly: float = 111.0
	draw_rect(Rect2(244.0 + roundf(sway * 0.5), 107.0, 1.0, 2.0), dusk)
	var flk: bool = fmod(_elapsed * 2.6, 1.0) < 0.6
	_px([[lx - 4, ly, 1, 1], [lx + 4, ly, 1, 1], [lx, ly - 4, 1, 1], [lx, ly + 4, 1, 1], [lx - 3, ly - 3, 1, 1], [lx + 3, ly + 3, 1, 1], [lx - 3, ly + 3, 1, 1], [lx + 3, ly - 3, 1, 1]], LxPalette.PAL["coral"] if flk else LxPalette.PAL["wine"])
	_px([[lx - 2, ly, 1, 1], [lx + 2, ly, 1, 1], [lx, ly - 2, 1, 1], [lx, ly + 2, 1, 1]], LxPalette.PAL["gold"] if flk else LxPalette.PAL["apricot"])
	_px([[lx - 1, ly - 2, 3, 1], [lx - 1, ly + 2, 3, 1]], night)
	draw_rect(Rect2(lx - 1.0, ly - 1.0, 3.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(lx, ly - 1.0, 2.0 if flk else 1.0, 2.0), LxPalette.PAL["cream"])


func _draw_sea() -> void:
	draw_rect(Rect2(0.0, 146.0, 320.0, 34.0), LxPalette.PAL["night"])
	draw_rect(Rect2(0.0, 149.0, 320.0, 22.0), LxPalette.PAL["deep"])
	_draw_dither_band(0.0, 320.0, 148.0, LxPalette.PAL["deep"])
	_draw_dither_band(0.0, 320.0, 170.0, LxPalette.PAL["night"])
	draw_rect(Rect2(0.0, 174.0, 320.0, 6.0), LxPalette.PAL["void"])
	draw_rect(Rect2(0.0, 146.0, 320.0, 1.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(0.0, 146.0, 120.0, 1.0), LxPalette.PAL["plum"])
	draw_rect(Rect2(236.0, 146.0, 84.0, 1.0), LxPalette.PAL["blue"])

	# Animated horizontal pixel wave glints.
	for i: int in range(18):
		var wy: float = 149.0 + float((i * 5) % 23)
		var bx: float = float((i * 53 + 11) % 304)
		var drift: float = roundf(sin(_elapsed * (0.9 + float(i % 3) * 0.35) + float(i) * 1.1) * 3.0)
		draw_rect(Rect2(bx + drift, wy, 5.0 + float(i % 4) * 2.0, 1.0), LxPalette.PAL["blue"] if (bx > 175.0 or i % 3 == 0) else LxPalette.PAL["dusk"])

	# Vertical flickering golden reflection beneath Bell Tower lantern & ice/sky under moon.
	var sway_ref: float = roundf(sin(_elapsed * 1.55) * 1.2)
	for r: int in range(10):
		var wob: float = roundf(sin(_elapsed * 2.9 + float(r) * 0.95) * (1.2 + float(r) * 0.2))
		var rw: float = roundf(maxf(2.0, 8.0 - float(r) * 0.55 + (1.0 if fmod(_elapsed * 3.0 + float(r), 1.0) < 0.5 else 0.0)))
		var lcol: Color = LxPalette.PAL["cream"] if r == 0 else (LxPalette.PAL["gold"] if r < 4 else (LxPalette.PAL["apricot"] if r < 7 else LxPalette.PAL["coral"]))
		draw_rect(Rect2(roundf(244.0 + sway_ref + wob - rw * 0.5), roundf(148.0 + float(r) * 2.6), rw, 1.0), lcol)
		if r < 9:
			var mwob: float = roundf(sin(_elapsed * 2.1 + float(r) * 0.8) * (1.4 + float(r) * 0.22))
			var mrw: float = roundf(maxf(2.0, 9.0 - float(r) * 0.6))
			var mcol: Color = LxPalette.PAL["ice"] if r < 3 else (LxPalette.PAL["sky"] if r < 6 else LxPalette.PAL["blue"])
			draw_rect(Rect2(roundf(273.0 + mwob - mrw * 0.5), roundf(149.0 + float(r) * 2.8), mrw, 1.0), mcol)

	var lh_p: float = 0.5 + 0.5 * sin(_elapsed * 1.9)
	if lh_p > 0.42:
		for r: int in range(4):
			var wob: float = roundf(sin(_elapsed * 2.5 + float(r)) * 1.5)
			draw_rect(Rect2(36.0 + wob, 149.0 + float(r) * 3.0, maxf(2.0, 5.0 - float(r)), 1.0), LxPalette.PAL["gold"] if (r == 0 and lh_p > 0.72) else LxPalette.PAL["apricot"])


func _draw_atmosphere() -> void:
	for w: Dictionary in _wisps:
		var wx: float = roundf(float(w["x"]))
		var wy: float = float(w["y"])
		var ww: float = float(w["w"])
		draw_rect(Rect2(wx + 2.0, wy, ww - 4.0, 1.0), LxPalette.color(str(w["col"])))
		_px([[wx, wy + 1.0, 4.0, 1.0], [wx + ww - 4.0, wy + 1.0, 4.0, 1.0]], LxPalette.PAL["dusk"])

	for ff: Dictionary in _fireflies:
		var fx: float = roundf(float(ff["x"]) + sin(_elapsed * 1.3 + float(ff["off"])) * 5.0)
		var fy: float = roundf(float(ff["y"]))
		var pulse: float = fmod(_elapsed + float(ff["off"]), 1.6)
		if pulse < 0.65:
			draw_rect(Rect2(fx, fy, 2.0, 2.0), LxPalette.PAL["gold"])
			draw_rect(Rect2(fx, fy, 1.0, 1.0), LxPalette.PAL["cream"])
		elif pulse < 1.15:
			draw_rect(Rect2(fx, fy, 2.0, 2.0), LxPalette.PAL["apricot"])
		else:
			draw_rect(Rect2(fx, fy, 1.0, 1.0), LxPalette.PAL["coral"])


func _draw_wick_lantern(ox: float, oy: float) -> void:
	var x: float = roundf(ox)
	var y: float = roundf(oy)
	var bright: bool = fmod(_elapsed * 2.4, 1.0) < 0.55
	var shift: float = 0.0 if fmod(_elapsed * 4.8, 1.0) < 0.5 else 1.0
	_px([[x + 2, y + 2, 3, 5], [x + 2, y + 8, 3, 1]], LxPalette.PAL["night"])
	_px([[x + 2, y, 3, 1], [x + 1, y + 2, 1, 5], [x + 5, y + 2, 1, 5], [x + 1, y + 7, 5, 1]], LxPalette.PAL["apricot"])
	_px([[x + 3, y, 1, 1], [x + 1, y + 1, 5, 1], [x + 2, y + 7, 3, 1]], LxPalette.PAL["gold"])
	_px([[x + 2, y + 3, 3, 4], [x + 3, y + 2, 1, 1]], LxPalette.PAL["gold"] if bright else LxPalette.PAL["apricot"])
	_px([[x + 3, y + 3, 1, 3], [x + 2 + shift, y + 4, 1, 1]], LxPalette.PAL["cream"])
	if bright:
		_px([[x, y + 4, 1, 1], [x + 6, y + 4, 1, 1]], LxPalette.PAL["gold"])


func _draw_main() -> void:
	var word: String = LxStrings.text("TITLE_WORDMARK")
	LxLuxels.draw_wordmark(self, word, 160.0, 20.0, _elapsed)

	var sub_p: float = clampf((_elapsed - LxLuxels.intro_duration(word)) / 0.4, 0.0, 1.0)
	LxPixelFont.draw_faded(
		self,
		LxStrings.text("TITLE_SUBTITLE"),
		Vector2(160.0, 52.0),
		sub_p,
		"apricot",
		1,
		HORIZONTAL_ALIGNMENT_CENTER
	)

	for i: int in range(MAIN_ITEMS.size()):
		var r: Rect2 = _main_btn_rect(i)
		var sel: bool = i == _main_idx
		LxPixelFont.draw_panel(self, r, "plum" if sel else "dusk", "gold" if sel else "mauve", "night")
		var ink: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
		LxPixelFont.draw_centered(self, LxStrings.text(MAIN_ITEMS[i]), r.get_center().x, r.position.y + 4.0, ink, 1)
		if sel:
			_draw_wick_lantern(r.position.x + 5.0, r.position.y + 3.0)
			_draw_wick_lantern(r.end.x - 12.0, r.position.y + 3.0)

	var pulse_col: Color = LxPalette.PAL["cream"] if fmod(_elapsed, 1.6) < 0.8 else LxPalette.PAL["stone"]
	LxPixelFont.draw_centered(self, LxStrings.text("TITLE_PROMPT"), 160.0, 162.0, pulse_col, 1)


func _draw_slots() -> void:
	LxPixelFont.draw_centered(self, LxStrings.text("SLOT_SELECT_TITLE"), 160.0, 14.0, LxPalette.PAL["gold"], 2)
	for i: int in range(SLOT_COUNT):
		var r: Rect2 = _slot_rect(i)
		var sel: bool = i == _slot_idx
		var info: Dictionary = _summaries[i] if i < _summaries.size() else {"empty": true}
		var is_empty: bool = bool(info.get("empty", true))
		LxPixelFont.draw_panel(self, r, "plum" if sel else "dusk", "gold" if sel else "mauve", "night")

		var slot_lbl: String = LxStrings.fmt("SLOT_LABEL", [i + 1])
		LxPixelFont.draw_left(self, slot_lbl, r.position + Vector2(7.0, 5.0), LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"], 1)

		if is_empty:
			LxPixelFont.draw_left(self, LxStrings.text("SLOT_EMPTY"), r.position + Vector2(7.0, 15.0), LxPalette.PAL["stone"], 1)
			LxPixelFont.draw_right(self, LxStrings.text("SLOT_NEW"), r.end.x - 8.0, r.position.y + 10.0, LxPalette.PAL["lime"] if sel else LxPalette.PAL["stone"], 1)
		else:
			var isl_id: int = int(info.get("island_id", 1))
			var isl_data: Dictionary = Lx.get_island_data(isl_id)
			var isl_name: String = LxStrings.sanitize(str(isl_data.get("name", "")), 20)
			var relit: int = int(info.get("relit_count", 0))
			var time_str: String = LxStrings.format_time(float(info.get("play_time_s", 0.0)))
			var meta: String = LxStrings.fmt("SLOT_META", [isl_name, relit, time_str])
			LxPixelFont.draw_left(self, meta, r.position + Vector2(7.0, 15.0), LxPalette.PAL["cream"], 1)
			LxPixelFont.draw_right(self, LxStrings.text("SLOT_CONTINUE"), r.end.x - 42.0, r.position.y + 5.0, LxPalette.PAL["gold"] if sel else LxPalette.PAL["stone"], 1)
			var del_r: Rect2 = _slot_del_rect(i)
			LxPixelFont.draw_panel(self, del_r, "wine" if sel else "night", "coral" if sel else "mauve", "void")
			LxPixelFont.draw_centered(self, LxStrings.text("SLOT_DELETE"), del_r.get_center().x, del_r.position.y + 3.0, LxPalette.PAL["cream"], 1)

	LxPixelFont.draw_centered(self, LxStrings.text("SLOT_HINT"), 160.0, 164.0, LxPalette.PAL["stone"], 1)


func _draw_confirm_delete() -> void:
	var box := Rect2(74.0, 62.0, 172.0, 56.0)
	LxPixelFont.draw_panel(self, box, "night", "coral", "void")
	var msg: String = LxStrings.fmt("SLOT_CONFIRM_DEL", [_slot_idx + 1])
	LxPixelFont.draw_centered(self, msg, 160.0, 72.0, LxPalette.PAL["coral"], 1)
	var labels: Array[String] = ["SLOT_YES", "SLOT_NO"]
	for i: int in range(2):
		var br: Rect2 = _confirm_btn_rect(i)
		var sel: bool = i == _confirm_idx
		var fill: String = "coral" if (sel and i == 0) else ("plum" if sel else "dusk")
		LxPixelFont.draw_panel(self, br, fill, "gold" if sel else "mauve", "void")
		LxPixelFont.draw_centered(self, LxStrings.text(labels[i]), br.get_center().x, br.position.y + 4.0, LxPalette.PAL["cream"], 1)


func _main_btn_rect(i: int) -> Rect2:
	return Rect2(106.0, 76.0 + float(i) * 20.0, 108.0, 15.0)


func _slot_rect(i: int) -> Rect2:
	return Rect2(26.0, 40.0 + float(i) * 38.0, 268.0, 30.0)


func _slot_del_rect(i: int) -> Rect2:
	var r: Rect2 = _slot_rect(i)
	return Rect2(r.end.x - 36.0, r.position.y + 9.0, 31.0, 12.0)


func _confirm_btn_rect(i: int) -> Rect2:
	return Rect2(86.0 + float(i) * 78.0, 92.0, 70.0, 15.0)


func _build_backdrop() -> void:
	_stars.clear()
	for i: int in range(44):
		var sx: float = float((i * 73 + 17) % 314 + 3)
		var sy: float = float((i * 41 + 5) % 112 + 3)
		if sx > 260.0 and sx < 290.0 and sy > 12.0 and sy < 40.0:
			continue
		_stars.append({
			"x": sx, "y": sy, "off": float(i) * 0.37, "per": 1.8 + float(i % 5) * 0.55,
			"hi": "cream" if i % 6 == 0 else ("ice" if sx > 170.0 else "stone"),
			"lo": "dusk" if i % 3 == 0 else "mauve",
			"cross": i % 5 == 0,
			"arm": "sky" if sx > 170.0 else "stone",
		})
	_fireflies.clear()
	var ff_xs: Array[float] = [14.0, 28.0, 48.0, 66.0, 84.0, 232.0, 248.0, 268.0, 286.0, 302.0]
	for i: int in range(ff_xs.size()):
		_fireflies.append({"x": ff_xs[i], "y": float((i * 31 + 19) % 168), "spd": 5.5 + float(i % 3) * 2.5, "off": float(i) * 0.85})
	_wisps = [
		{"x": 18.0, "y": 141.0, "w": 28.0, "spd": 3.4, "col": "mauve"},
		{"x": 124.0, "y": 144.0, "w": 34.0, "spd": 2.4, "col": "dusk"},
		{"x": 212.0, "y": 142.0, "w": 26.0, "spd": 3.0, "col": "mauve"},
		{"x": 284.0, "y": 145.0, "w": 22.0, "spd": 2.1, "col": "dusk"},
	]


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _joy_just(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
