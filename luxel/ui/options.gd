class_name LxOptionsMenu
extends Node2D
## Options menu (SWARM_SPEC 3.9): Audio, Display, Controls, and Assist.
## Assist NEVER includes aim assist. All values persist via Lx.save.settings.

signal closed()
signal settings_changed(settings: Dictionary)
signal rebind_requested()

enum Tab { AUDIO, DISPLAY, CONTROLS, ASSIST }

const TAB_KEYS: Array[String] = [
	"OPT_TAB_AUDIO",
	"OPT_TAB_DISPLAY",
	"OPT_TAB_CONTROLS",
	"OPT_TAB_ASSIST",
]

const COLOR_LABEL_KEYS: Dictionary = {
	"gold": "OPT_COL_GOLD",
	"cream": "OPT_COL_CREAM",
	"ice": "OPT_COL_ICE",
	"lime": "OPT_COL_LIME",
	"coral": "OPT_COL_CORAL",
	"rose": "OPT_COL_ROSE",
	"sky": "OPT_COL_SKY",
	"apricot": "OPT_COL_APRICOT",
}

const CURSOR_SIZE_KEYS: Array[String] = [
	"OPT_CURSOR_SMALL",
	"OPT_CURSOR_MED",
	"OPT_CURSOR_LARGE",
]

const PANEL_RECT := Rect2(18.0, 12.0, 284.0, 156.0)

var current_tab: int = Tab.AUDIO
var _row_idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(initial_tab: int = Tab.AUDIO) -> void:
	current_tab = clampi(initial_tab, 0, TAB_KEYS.size() - 1)
	_row_idx = 0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _cfg() -> Dictionary:
	if Lx.save != null:
		return Lx.save.settings
	return LxSaveService.default_settings()


func _rows_for_tab(tab: int) -> Array[String]:
	match tab:
		Tab.AUDIO:
			return ["master_vol", "music_vol", "sfx_vol", "ambience_vol", "mute_unfocus"]
		Tab.DISPLAY:
			return ["fullscreen", "window_scale", "screen_shake", "flash_reduction", "cursor_size", "cursor_color"]
		Tab.CONTROLS:
			return ["rebind", "hold_fire", "hold_beam", "hold_wings", "reset_controls"]
		Tab.ASSIST:
			return ["assist_damage_mult", "assist_tell_scale", "assist_game_speed"]
		_:
			return []


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_click(mb.position):
				get_viewport().set_input_as_handled()
		return

	var rows: Array[String] = _rows_for_tab(current_tab)
	if _key_just(event, KEY_TAB) or _joy_just(event, JOY_BUTTON_RIGHT_SHOULDER):
		current_tab = (current_tab + 1) % TAB_KEYS.size()
		_row_idx = 0
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif _joy_just(event, JOY_BUTTON_LEFT_SHOULDER):
		current_tab = (current_tab - 1 + TAB_KEYS.size()) % TAB_KEYS.size()
		_row_idx = 0
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_row_idx = (_row_idx - 1 + rows.size()) % rows.size()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_row_idx = (_row_idx + 1) % rows.size()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_left") or _key_just(event, KEY_LEFT):
		_adjust_row(rows[_row_idx], -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_right") or _key_just(event, KEY_RIGHT):
		_adjust_row(rows[_row_idx], 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_activate_row(rows[_row_idx])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("ui_back")
		closed.emit()
		get_viewport().set_input_as_handled()


func _handle_click(pos: Vector2) -> bool:
	for i: int in range(TAB_KEYS.size()):
		if _tab_rect(i).has_point(pos):
			current_tab = i
			_row_idx = 0
			_play_ui_sfx("ui_move")
			queue_redraw()
			return true
	var rows: Array[String] = _rows_for_tab(current_tab)
	for i: int in range(rows.size()):
		var r: Rect2 = _row_rect(i)
		if r.has_point(pos):
			_row_idx = i
			if pos.x < r.position.x + r.size.x * 0.55:
				_activate_row(rows[i])
			elif pos.x < r.position.x + r.size.x * 0.77:
				_adjust_row(rows[i], -1)
			else:
				_adjust_row(rows[i], 1)
			return true
	return false


func _activate_row(row_id: String) -> void:
	if row_id == "rebind":
		_play_ui_sfx("ui_confirm")
		rebind_requested.emit()
		return
	if row_id == "reset_controls":
		_reset_controls()
		return
	_adjust_row(row_id, 1)


func _adjust_row(row_id: String, dir: int) -> void:
	var cfg: Dictionary = _cfg()
	match row_id:
		"master_vol", "music_vol", "sfx_vol", "ambience_vol":
			var v: float = snappedf(clampf(float(cfg.get(row_id, 1.0)) + float(dir) * 0.05, 0.0, 1.0), 0.05)
			cfg[row_id] = v
		"mute_unfocus", "fullscreen", "flash_reduction":
			cfg[row_id] = not bool(cfg.get(row_id, false))
		"window_scale":
			cfg[row_id] = clampi(int(cfg.get(row_id, 3)) + dir, 1, 5)
		"screen_shake":
			cfg[row_id] = clampi(int(cfg.get(row_id, 100)) + dir * 10, 0, 100)
		"cursor_size":
			cfg[row_id] = clampi(int(cfg.get(row_id, 1)) + dir, 1, 3)
		"cursor_color":
			var cur: String = str(cfg.get(row_id, "gold"))
			var ci: int = LxPalette.CURSOR_COLORS.find(cur)
			if ci < 0:
				ci = 0
			ci = (ci + dir + LxPalette.CURSOR_COLORS.size()) % LxPalette.CURSOR_COLORS.size()
			cfg[row_id] = LxPalette.CURSOR_COLORS[ci]
		"hold_fire":
			_toggle_hold(cfg, "lx_fire")
		"hold_beam":
			_toggle_hold(cfg, "lx_beam")
		"hold_wings":
			_toggle_hold(cfg, "lx_wings")
		"assist_damage_mult":
			var steps: Array[float] = [1.0, 0.5, 0.0]
			var idx: int = _closest_step(float(cfg.get(row_id, 1.0)), steps)
			idx = (idx + dir + steps.size()) % steps.size()
			cfg[row_id] = steps[idx]
		"assist_tell_scale":
			var cur_t: float = float(cfg.get(row_id, 1.0))
			cfg[row_id] = 1.5 if cur_t < 1.25 else 1.0
		"assist_game_speed":
			var spd: float = snappedf(clampf(float(cfg.get(row_id, 1.0)) + float(dir) * 0.05, 0.7, 1.0), 0.05)
			cfg[row_id] = spd
		_:
			return
	_play_ui_sfx("ui_move")
	_apply_and_save(cfg)
	queue_redraw()


func _toggle_hold(cfg: Dictionary, action_id: String) -> void:
	var hm: Dictionary = cfg.get("hold_mode", {}) as Dictionary
	var cur: String = str(hm.get(action_id, "hold"))
	var nxt: String = "toggle" if cur == "hold" else "hold"
	hm[action_id] = nxt
	cfg["hold_mode"] = hm
	if Lx.input != null:
		Lx.input.hold_modes[action_id] = nxt
		Lx.input.clear_toggle(action_id)


func _reset_controls() -> void:
	var cfg: Dictionary = _cfg()
	if Lx.input != null:
		Lx.input.register_default_actions()
		Lx.input.hold_modes = {"lx_fire": "hold", "lx_beam": "hold", "lx_wings": "hold"}
		Lx.input.clear_all_toggles()
		cfg["bindings"] = Lx.input.export_bindings()
	cfg["hold_mode"] = {"lx_fire": "hold", "lx_beam": "hold", "lx_wings": "hold"}
	_play_ui_sfx("ui_confirm")
	_apply_and_save(cfg)
	queue_redraw()


func _apply_and_save(cfg: Dictionary) -> void:
	if Lx.audio != null:
		Lx.audio.apply_settings(cfg)
	if Lx.camera != null:
		Lx.camera.shake_scale = clampf(float(cfg.get("screen_shake", 100)) / 100.0, 0.0, 1.0)
	if Lx.hitstop != null:
		Lx.hitstop.game_speed = clampf(float(cfg.get("assist_game_speed", 1.0)), 0.7, 1.0)
	if Lx.save != null:
		Lx.save.settings = cfg
		Lx.save.save_settings()
	settings_changed.emit(cfg)


func _draw() -> void:
	draw_rect(Rect2(PANEL_RECT.position + Vector2(3.0, 3.0), PANEL_RECT.size), LxPalette.PAL["void"])
	draw_rect(PANEL_RECT.grow(1.0), LxPalette.PAL["void"])
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", "mauve", "night")
	_draw_frame_ornaments()
	LxPixelFont.draw_centered(self, LxStrings.text("OPT_TITLE"), 160.0, PANEL_RECT.position.y + 6.0, LxPalette.PAL["gold"], 1)

	for i: int in range(TAB_KEYS.size()):
		var tr: Rect2 = _tab_rect(i)
		var active: bool = i == current_tab
		LxPixelFont.draw_panel(self, tr, "plum" if active else "night", "gold" if active else "mauve", "void")
		LxPixelFont.draw_centered(self, LxStrings.text(TAB_KEYS[i]), tr.get_center().x, tr.position.y + 3.0, LxPalette.PAL["gold"] if active else LxPalette.PAL["stone"], 1)

	if current_tab == Tab.ASSIST:
		LxPixelFont.draw_centered(self, LxStrings.text("OPT_ASSIST_NOTE"), 160.0, 44.0, LxPalette.PAL["ice"], 1)

	var cfg: Dictionary = _cfg()
	var rows: Array[String] = _rows_for_tab(current_tab)
	for i: int in range(rows.size()):
		_draw_row(i, rows[i], cfg)

	LxPixelFont.draw_centered(self, LxStrings.text("OPT_HINT"), 160.0, PANEL_RECT.end.y - 10.0, LxPalette.PAL["stone"], 1)


func _draw_frame_ornaments() -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	# Corner brass brackets and rivets with shadow depth.
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
	# Decorative lantern-chain divider beneath OPT_TITLE.
	var cy: float = p.y + 12.0
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


func _draw_row(idx: int, row_id: String, cfg: Dictionary) -> void:
	var r: Rect2 = _row_rect(idx)
	var sel: bool = idx == _row_idx
	if sel:
		LxPixelFont.draw_panel(self, r, "plum", "gold", "night")
		_draw_lantern_pip(r.position + Vector2(5.0, 4.0))
	var label_col: Color = LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"]
	var val_col: Color = LxPalette.PAL["cream"] if sel else LxPalette.PAL["stone"]
	var label: String = _row_label(row_id)
	var val_txt: String = _row_value_text(row_id, cfg)

	var label_x: float = 12.0 if sel else 6.0
	LxPixelFont.draw_left(self, label, r.position + Vector2(label_x, 4.0), label_col, 1)
	if not val_txt.is_empty():
		LxPixelFont.draw_right(self, val_txt, r.end.x - 8.0, r.position.y + 4.0, val_col, 1)

	if row_id in ["master_vol", "music_vol", "sfx_vol", "ambience_vol", "screen_shake", "assist_game_speed"]:
		_draw_slider(r, row_id, cfg, sel)
	elif row_id == "cursor_color":
		var cname: String = str(cfg.get("cursor_color", "gold"))
		var sw := Rect2(r.end.x - 54.0, r.position.y + 3.0, 8.0, 7.0)
		draw_rect(sw.grow(1.0), LxPalette.PAL["void"])
		draw_rect(sw, LxPalette.color(cname))


func _draw_lantern_pip(at: Vector2) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	draw_rect(Rect2(x - 1.0, y, 5.0, 5.0), LxPalette.PAL["night"])
	draw_rect(Rect2(x + 1.0, y, 1.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x, y + 1.0, 3.0, 1.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x, y + 2.0, 3.0, 2.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 1.0, y + 2.0, 1.0, 2.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x, y + 4.0, 3.0, 1.0), LxPalette.PAL["apricot"])


func _draw_slider(r: Rect2, row_id: String, cfg: Dictionary, sel: bool) -> void:
	var frac: float = 1.0
	if row_id == "screen_shake":
		frac = clampf(float(cfg.get(row_id, 100)) / 100.0, 0.0, 1.0)
	elif row_id == "assist_game_speed":
		frac = clampf((float(cfg.get(row_id, 1.0)) - 0.7) / 0.3, 0.0, 1.0)
	else:
		frac = clampf(float(cfg.get(row_id, 1.0)), 0.0, 1.0)
	var bar := Rect2(r.end.x - 94.0, r.position.y + 4.0, 56.0, 5.0)
	draw_rect(bar.grow(1.0), LxPalette.PAL["night"])
	draw_rect(bar, LxPalette.PAL["void"])
	draw_rect(Rect2(bar.position.x, bar.end.y - 1.0, bar.size.x, 1.0), LxPalette.PAL["dusk"])
	for t: int in range(1, 5):
		var tx: float = roundf(bar.position.x + bar.size.x * float(t) * 0.2)
		draw_rect(Rect2(tx, bar.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["mauve"])
		draw_rect(Rect2(tx, bar.end.y, 1.0, 1.0), LxPalette.PAL["dusk"])
	var fill_w: float = floorf(bar.size.x * frac)
	if fill_w > 0.0:
		draw_rect(Rect2(bar.position, Vector2(fill_w, bar.size.y)), LxPalette.PAL["apricot"])
		draw_rect(Rect2(bar.position, Vector2(fill_w, 4.0 if sel else 2.0)), LxPalette.PAL["gold"])
	var thumb_x: float = clampf(roundf(bar.position.x + fill_w - 1.0), bar.position.x, bar.end.x - 3.0)
	var thumb := Rect2(thumb_x, bar.position.y - 1.0, 3.0, bar.size.y + 2.0)
	draw_rect(thumb.grow(1.0), LxPalette.PAL["night"])
	draw_rect(thumb, LxPalette.PAL["gold"] if sel else LxPalette.PAL["apricot"])
	draw_rect(Rect2(thumb_x + 1.0, bar.position.y, 1.0, bar.size.y), LxPalette.PAL["cream"] if sel else LxPalette.PAL["gold"])


func _row_label(row_id: String) -> String:
	match row_id:
		"master_vol":
			return LxStrings.text("OPT_MASTER")
		"music_vol":
			return LxStrings.text("OPT_MUSIC")
		"sfx_vol":
			return LxStrings.text("OPT_SFX")
		"ambience_vol":
			return LxStrings.text("OPT_AMBIENCE")
		"mute_unfocus":
			return LxStrings.text("OPT_MUTE_UNFOCUS")
		"fullscreen":
			return LxStrings.text("OPT_FULLSCREEN")
		"window_scale":
			return LxStrings.text("OPT_WIN_SCALE")
		"screen_shake":
			return LxStrings.text("OPT_SHAKE")
		"flash_reduction":
			return LxStrings.text("OPT_FLASH_RED")
		"cursor_size":
			return LxStrings.text("OPT_CURSOR_SIZE")
		"cursor_color":
			return LxStrings.text("OPT_CURSOR_COLOR")
		"rebind":
			return LxStrings.text("OPT_REBIND_OPEN")
		"hold_fire":
			return LxStrings.text("OPT_HOLD_FIRE")
		"hold_beam":
			return LxStrings.text("OPT_HOLD_BEAM")
		"hold_wings":
			return LxStrings.text("OPT_HOLD_WINGS")
		"reset_controls":
			return LxStrings.text("OPT_RESET_DEFAULTS")
		"assist_damage_mult":
			return LxStrings.text("OPT_ASSIST_DMG")
		"assist_tell_scale":
			return LxStrings.text("OPT_ASSIST_TELLS")
		"assist_game_speed":
			return LxStrings.text("OPT_ASSIST_SPEED")
		_:
			return LxStrings.text("OPT_BACK")


func _row_value_text(row_id: String, cfg: Dictionary) -> String:
	match row_id:
		"master_vol", "music_vol", "sfx_vol", "ambience_vol":
			return LxStrings.fmt("FMT_PCT", [roundi(float(cfg.get(row_id, 1.0)) * 100.0)])
		"mute_unfocus", "fullscreen", "flash_reduction":
			return LxStrings.text("OPT_ON" if bool(cfg.get(row_id, false)) else "OPT_OFF")
		"window_scale":
			return LxStrings.fmt("OPT_SCALE_FMT", [int(cfg.get(row_id, 3))])
		"screen_shake":
			return LxStrings.fmt("FMT_PCT", [int(cfg.get(row_id, 100))])
		"cursor_size":
			var sz: int = clampi(int(cfg.get(row_id, 1)) - 1, 0, CURSOR_SIZE_KEYS.size() - 1)
			return LxStrings.text(CURSOR_SIZE_KEYS[sz])
		"cursor_color":
			var cname: String = str(cfg.get(row_id, "gold"))
			return LxStrings.text(str(COLOR_LABEL_KEYS.get(cname, "OPT_COL_GOLD")))
		"hold_fire":
			return _hold_label(cfg, "lx_fire")
		"hold_beam":
			return _hold_label(cfg, "lx_beam")
		"hold_wings":
			return _hold_label(cfg, "lx_wings")
		"assist_damage_mult":
			var dm: float = float(cfg.get(row_id, 1.0))
			if dm <= 0.05:
				return LxStrings.text("OPT_DMG_ZERO")
			if dm <= 0.75:
				return LxStrings.text("OPT_DMG_HALF")
			return LxStrings.text("OPT_DMG_1")
		"assist_tell_scale":
			return LxStrings.text("OPT_TELL_15" if float(cfg.get(row_id, 1.0)) >= 1.25 else "OPT_TELL_1")
		"assist_game_speed":
			return LxStrings.fmt("FMT_PCT", [roundi(float(cfg.get(row_id, 1.0)) * 100.0)])
		_:
			return ""


func _hold_label(cfg: Dictionary, action_id: String) -> String:
	var hm: Dictionary = cfg.get("hold_mode", {}) as Dictionary
	var is_toggle: bool = str(hm.get(action_id, "hold")) == "toggle"
	return LxStrings.text("OPT_MODE_TOGGLE" if is_toggle else "OPT_MODE_HOLD")


func _tab_rect(i: int) -> Rect2:
	return Rect2(26.0 + float(i) * 68.0, 26.0, 64.0, 12.0)


func _row_rect(i: int) -> Rect2:
	var base_y: float = 54.0 if current_tab == Tab.ASSIST else 44.0
	return Rect2(26.0, base_y + float(i) * 16.0, 268.0, 13.0)


func _closest_step(v: float, steps: Array[float]) -> int:
	var best_i: int = 0
	var best_d: float = 999.0
	for i: int in range(steps.size()):
		var d: float = absf(v - steps[i])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _joy_just(event: InputEvent, btn: JoyButton) -> bool:
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == btn
