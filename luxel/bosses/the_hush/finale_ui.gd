class_name LxHushFinalePanel
extends CanvasLayer
## Phase-4 Finale Climax Overlay for The Hush (Bible §4.8 & §8.2).
## Renders on CanvasLayer 15 (ABOVE screen-degrade shaders) so the 2-row choice panel
## ("PIXELS: 100% - OFF" vs "KEEP DISPLAY - STAND ALONE") and the 25s Unbroken Stand
## countdown always remain razor-sharp. Handles 5-tap pixel sell -> AUTO-SELL -> BIG BLAST!

signal display_off_completed()
signal keep_display_chosen()

const PAL: Dictionary = LxPalette.PAL
const PANEL_RECT := Rect2(46.0, 8.0, 228.0, 52.0)
const VIEW_W: float = 320.0
const VIEW_H: float = 180.0
const TAPS_FOR_AUTOSELL: int = 5
const AUTOSELL_DUR: float = 1.05
const BIG_BLAST_DUR: float = 0.72

enum Stage { HIDDEN, CHOICE, AUTOSELL, BIG_BLAST, STAND_HUD }

var stage: int = Stage.HIDDEN
var selected_row: int = 0 # 0 = PIXELS -> OFF, 1 = KEEP DISPLAY
var pixel_taps: int = 0
var dead_pct: float = 0.0
var stand_remaining: float = 25.0
var _clock: float = 0.0
var _stage_t: float = 0.0
var _manual_step: bool = false
var _canvas: Node2D = null
var _eyes: Array[Vector2] = []


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.name = "HushFinaleCanvas"
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.visible = false
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)
	_build_edge_eyes()


func open_choice() -> void:
	stage = Stage.CHOICE
	selected_row = 0
	pixel_taps = 0
	dead_pct = 0.0
	_stage_t = 0.0
	if _canvas != null:
		_canvas.visible = true
		_canvas.queue_redraw()


func start_auto_display_off() -> void:
	stage = Stage.AUTOSELL
	pixel_taps = TAPS_FOR_AUTOSELL
	dead_pct = 0.05
	_stage_t = 0.0
	if _canvas != null:
		_canvas.visible = true
		_canvas.queue_redraw()


func show_stand_hud(secs_left: float) -> void:
	stage = Stage.STAND_HUD
	stand_remaining = maxf(0.0, secs_left)
	if _canvas != null:
		_canvas.visible = true
		_canvas.queue_redraw()


func hide_panel() -> void:
	stage = Stage.HIDDEN
	dead_pct = 0.0
	if _canvas != null:
		_canvas.visible = false


func _process(dt: float) -> void:
	if _manual_step:
		_manual_step = false
		return
	step_panel(dt)


func step_panel(dt: float, manual: bool = false) -> void:
	if manual:
		_manual_step = true
	if stage == Stage.HIDDEN:
		return
	_clock += dt
	_stage_t += dt
	if stage == Stage.AUTOSELL:
		var u: float = clampf(_stage_t / AUTOSELL_DUR, 0.0, 1.0)
		dead_pct = lerpf(0.05, 1.0, u * u)
		_push_display_pct(dead_pct)
		if u >= 1.0:
			stage = Stage.BIG_BLAST
			_stage_t = 0.0
			_play_sfx("hush_big_blast")
	elif stage == Stage.BIG_BLAST:
		if _stage_t >= BIG_BLAST_DUR:
			stage = Stage.HIDDEN
			if _canvas != null:
				_canvas.visible = false
			display_off_completed.emit()
			return
	elif stage == Stage.CHOICE:
		_poll_choice_input()
	if _canvas != null:
		_canvas.queue_redraw()


func _poll_choice_input() -> void:
	if _stage_t < 0.16:
		return
	if Input.is_action_just_pressed("lx_move_up") or Input.is_action_just_pressed("lx_move_down"):
		selected_row = 1 - selected_row
		_play_sfx("ui_move")
	elif Input.is_action_just_pressed("lx_ui_accept") or Input.is_action_just_pressed("lx_interact"):
		_activate_row()


func _input(ev: InputEvent) -> void:
	if stage != Stage.CHOICE or _stage_t < 0.16:
		return
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var kc: Key = (ev as InputEventKey).keycode
		if kc == KEY_UP or kc == KEY_W or kc == KEY_DOWN or kc == KEY_S:
			selected_row = 1 - selected_row
			_play_sfx("ui_move")
			get_viewport().set_input_as_handled()
		elif kc == KEY_SPACE or kc == KEY_ENTER:
			_activate_row()
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var r1 := Rect2(PANEL_RECT.position.x + 6.0, PANEL_RECT.position.y + 18.0, PANEL_RECT.size.x - 12.0, 14.0)
			var r2 := Rect2(PANEL_RECT.position.x + 6.0, PANEL_RECT.position.y + 34.0, PANEL_RECT.size.x - 12.0, 14.0)
			if r1.has_point(mb.position):
				selected_row = 0
				_activate_row()
				get_viewport().set_input_as_handled()
			elif r2.has_point(mb.position):
				selected_row = 1
				_activate_row()
				get_viewport().set_input_as_handled()


func _activate_row() -> void:
	if selected_row == 0:
		pixel_taps += 1
		dead_pct = clampf(float(pixel_taps) * 0.01, 0.01, 0.05)
		_push_display_pct(dead_pct)
		_play_sfx("hush_pixel_sell")
		if pixel_taps >= TAPS_FOR_AUTOSELL:
			stage = Stage.AUTOSELL
			_stage_t = 0.0
	else:
		stage = Stage.STAND_HUD
		stand_remaining = 25.0
		_stage_t = 0.0
		_play_sfx("shield_shatter")
		keep_display_chosen.emit()


func _push_display_pct(pct: float) -> void:
	if ResourceLoader.exists("res://luxel/core/sold_settings.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/core/sold_settings.gd")
		if sc is GDScript and (sc as GDScript).has_method("current"):
			var inst: Variant = (sc as GDScript).call("current")
			if inst is Object and (inst as Object).has_method("set_display_pixels"):
				(inst as Object).call("set_display_pixels", pct)
	if Lx.vars != null:
		Lx.vars.set_var("island:8", "display_pixels_pct", pct)
		Lx.vars.set_var("game", "display_pixels_pct", pct)


func _play_sfx(id: String) -> void:
	if Lx.audio != null and is_instance_valid(Lx.audio):
		Lx.audio.play_sfx(id, Vector2.ZERO, false)
	elif Lx.events != null:
		Lx.events.sfx_requested.emit(id, Vector2.ZERO, false)


func _build_edge_eyes() -> void:
	_eyes.clear()
	for i: int in range(20):
		var a: float = float(i) * (TAU / 20.0)
		var ex: float = clampf(160.0 + cos(a) * 150.0, 8.0, 312.0)
		var ey: float = clampf(90.0 + sin(a) * 82.0, 12.0, 170.0)
		_eyes.append(Vector2(ex, ey).round())


func _draw_overlay() -> void:
	if _canvas == null or stage == Stage.HIDDEN:
		return
	var c: Node2D = _canvas
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var plum: Color = PAL["plum"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var coral: Color = PAL["coral"] as Color
	var ice: Color = PAL["ice"] as Color
	var stone: Color = PAL["stone"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Dead 4px void pixel blocks eating inward during CHOICE (visible from tap 1) & AUTOSELL
	if dead_pct > 0.001 and stage in [Stage.CHOICE, Stage.AUTOSELL]:
		var cols: int = 80
		var rows: int = 45
		var reach_in: float = clampf(dead_pct * 2.4 if dead_pct <= 0.06 else lerpf(0.144, 1.0, (dead_pct - 0.06) / 0.94), 0.0, 1.0)
		for gy: int in range(rows):
			for gx: int in range(cols):
				var dx: float = absf(float(gx) - 39.5) / 40.0
				var dy: float = absf(float(gy) - 22.0) / 22.5
				var edge_d: float = maxf(dx, dy)
				var bayer: float = float(((gx & 1) * 2 + (gy & 1)) % 4) * 0.025
				var thresh: float = (1.0 - reach_in) * 0.99 - (0.0 if fred else bayer)
				if edge_d >= thresh or dead_pct >= 0.99:
					c.draw_rect(Rect2(float(gx * 4), float(gy * 4), 4.0, 4.0), void_c)

	# Dark eyes ringing the screen edge during climax!
	if stage in [Stage.CHOICE, Stage.AUTOSELL]:
		for ep: Vector2 in _eyes:
			c.draw_rect(Rect2(ep - Vector2(1.0, 0.0), Vector2(1.0, 1.0)), ice)
			c.draw_rect(Rect2(ep + Vector2(1.0, 0.0), Vector2(1.0, 1.0)), ice)

	if stage == Stage.BIG_BLAST:
		var u: float = clampf(_stage_t / BIG_BLAST_DUR, 0.0, 1.0)
		c.draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), void_c)
		var r: float = lerpf(4.0, 210.0, 1.0 - pow(1.0 - u, 2.0))
		c.draw_arc(Vector2(160.0, 90.0), r, 0.0, TAU, 36, cream, 2.4)
		if r > 6.0:
			c.draw_arc(Vector2(160.0, 90.0), r - 4.0, 0.0, TAU, 32, gold, 2.0)
		return

	if stage == Stage.STAND_HUD:
		var pill := Rect2(94.0, 18.0, 132.0, 13.0)
		c.draw_rect(pill.grow(1.0), void_c)
		c.draw_rect(pill, night)
		c.draw_rect(pill, gold, false, 1.0)
		var secs_i: int = int(ceilf(stand_remaining))
		var txt: String = LxStrings.fmt("ISL8_FINALE_STAND_FMT", [secs_i]) if LxStrings.has_id("ISL8_FINALE_STAND_FMT") else ("UNBROKEN STAND: %dS" % secs_i)
		LxPixelFont.draw_centered(c, txt, 160.0, 22.0, cream if secs_i > 5 else gold, 1, void_c)
		return

	# Crisp 2-row Finale Choice Panel (Rect2(46, 8, 228, 52))
	var r: Rect2 = PANEL_RECT
	c.draw_rect(r.grow(2.0), void_c)
	c.draw_rect(r, dusk)
	c.draw_rect(r.grow(-1.0), night)
	var hdr: String = LxStrings.text("ISL8_ASK_FINALE_1") if LxStrings.has_id("ISL8_ASK_FINALE_1") else "ONE SETTING LEFT. IT IS THE SCREEN."
	LxPixelFont.draw_centered(c, hdr, 160.0, r.position.y + 4.0, gold, 1, void_c)
	c.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 13.0, r.size.x - 12.0, 1.0), plum)

	var pct_left: int = maxi(0, 100 - int(round(dead_pct * 100.0)))
	var row1_txt: String = LxStrings.text("ISL8_FINALE_AUTOSELL") if stage == Stage.AUTOSELL else (
		LxStrings.fmt("ISL8_FINALE_PIXELS_ROW", [pct_left]) if LxStrings.has_id("ISL8_FINALE_PIXELS_ROW") else ("PIXELS: %d%% - OFF" % pct_left)
	)
	var row2_txt: String = LxStrings.text("ISL8_ASK_FINALE_2") if LxStrings.has_id("ISL8_ASK_FINALE_2") else "KEEP DISPLAY - STAND ALONE"
	var rows: Array[String] = [row1_txt, row2_txt]
	for ri: int in range(2):
		var sel: bool = (ri == selected_row) or (stage == Stage.AUTOSELL and ri == 0)
		var ry: float = r.position.y + 17.0 + float(ri) * 16.0
		var rr := Rect2(r.position.x + 6.0, ry, r.size.x - 12.0, 13.0)
		c.draw_rect(rr, gold if sel else dusk)
		c.draw_rect(rr.grow(-1.0), plum if sel else night)
		if sel:
			c.draw_rect(Rect2(rr.position.x + 3.0, ry + 4.0, 3.0, 5.0), cream)
		LxPixelFont.draw(c, rows[ri], Vector2(rr.position.x + 9.0, ry + 4.0), cream if sel else stone, 1, void_c)
		if ri == 0 and stage == Stage.CHOICE and pixel_taps > 0:
			LxPixelFont.draw(c, "%d/%d" % [pixel_taps, TAPS_FOR_AUTOSELL], Vector2(rr.end.x - 4.0, ry + 4.0), coral, 1, void_c, HORIZONTAL_ALIGNMENT_RIGHT)


# --- Guarded LxSold & Finale State Helpers (shared with the_hush/brain.gd) ---

static func get_sold_singleton() -> Object:
	if ResourceLoader.exists("res://luxel/core/sold_settings.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/core/sold_settings.gd")
		if sc is GDScript and (sc as GDScript).has_method("current"):
			var inst: Variant = (sc as GDScript).call("current")
			if inst is Object: return inst as Object
	return null


static func get_sold_count() -> int:
	var s: Object = get_sold_singleton()
	if s != null and s.has_method("get_sold_count"):
		return int(s.call("get_sold_count"))
	if Lx.vars != null:
		return int(Lx.vars.get_var("island:8", "sold_count", Lx.vars.get_var("game", "sold_count", 0)))
	return 0


static func is_setting_sold(setting_id: String) -> bool:
	var s: Object = get_sold_singleton()
	if s != null and s.has_method("is_sold"):
		return bool(s.call("is_sold", setting_id))
	if Lx.vars != null:
		return bool(Lx.vars.get_var("island:8", "sold_" + setting_id, Lx.vars.get_var("game", "sold_" + setting_id, false)))
	return false


static func is_tab_sold(tab_name: String) -> bool:
	var s: Object = get_sold_singleton()
	if s != null and s.has_method("is_tab_sold"):
		return bool(s.call("is_tab_sold", tab_name))
	var ids: Array = ["hud_hearts", "minimap_hud", "ember_hud", "cursor_ring"] if tab_name.to_upper() == "INTERFACE" else ["palette_4", "music_off", "sound_off", "fps_step"]
	for sid_v: Variant in ids:
		if is_setting_sold(str(sid_v)): return true
	return false


static func get_beauty_sold_count() -> int:
	var s: Object = get_sold_singleton()
	if s != null and s.has_method("count_in_tab"):
		return int(s.call("count_in_tab", "BEAUTY"))
	var n: int = 0
	for sid: String in ["palette_4", "music_off", "sound_off", "fps_step"]:
		if is_setting_sold(sid): n += 1
	return n


static func record_finale_choice(choice: String) -> void:
	var c: String = "dawn" if choice == "dawn" else "display_off"
	if Lx.vars != null:
		Lx.vars.set_var("island:8", "hush_finale_choice", c)
		Lx.vars.set_var("game", "hush_finale_choice", c)
	if Lx.state != null:
		Lx.state.story_flags["hush_finale_choice"] = c
	var sold_obj: Object = get_sold_singleton()
	if sold_obj != null and sold_obj.has_method("apply_hush_finale_choice"):
		sold_obj.call("apply_hush_finale_choice", "keep" if c == "dawn" else "display")


static func forced_finale_choice() -> String:
	if Lx.debug != null and not Lx.debug.ending.is_empty():
		return "dawn" if Lx.debug.ending == "dawn" else "display_off"
	if Lx.vars != null:
		var v: String = str(Lx.vars.get_var("island:8", "hush_finale_choice", Lx.vars.get_var("game", "hush_finale_choice", ""))).strip_edges().to_lower()
		if v == "dawn" or v == "keep": return "dawn"
		if v == "display_off" or v == "display": return "display_off"
	return ""


static func is_automated_run() -> bool:
	if Lx.input != null:
		var syn: Variant = Lx.input.get("synthetic_active")
		if syn is bool and (syn as bool):
			return true
	return DisplayServer.get_name() == "headless"
