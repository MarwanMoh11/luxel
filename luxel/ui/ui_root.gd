class_name LxUiRoot
extends CanvasLayer
## Root UI coordinator for Luxel 1.0 (registered as Lx.ui).
## Manages Title, HUD, Pause, Map, Options, Rebind, Rest Shop, Narration, Cards,
## and the palette-coloured manual-aim cursor/reticle.

signal play_slot_requested(slot_num: int, is_new_game: bool)
signal quit_requested()
signal resume_requested()
signal retry_checkpoint_requested()
signal return_to_title_requested()
signal fast_travel_requested(island_id: int, waystone_id: String)
signal settings_changed(settings: Dictionary)
signal upgrade_bought(upgrade_id: String, new_rank: int)
signal death_retry_requested()
signal intro_finished()
signal credits_finished()

enum Screen { NONE, TITLE, INTRO, HUD, PAUSE, MAP, OPTIONS, REBIND, SHOP, DEATH, RESULTS, CREDITS }

var current_screen: int = Screen.NONE
var _return_screen: int = Screen.TITLE

var hud: LxHud = null
var narration: LxNarration = null
var title: LxTitleScreen = null
var pause: LxPauseMenu = null
var map_screen: LxMapScreen = null
var options: LxOptionsMenu = null
var rebind: LxRebindScreen = null
var rest_shop: LxRestShop = null
var cards: LxCards = null
var _cursor_node: Node2D = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	Lx.ui = self
	_build_children()
	_connect_signals()
	show_title()


func _build_children() -> void:
	hud = LxHud.new()
	hud.name = "Hud"
	add_child(hud)

	narration = LxNarration.new()
	narration.name = "Narration"
	add_child(narration)

	title = LxTitleScreen.new()
	title.name = "Title"
	add_child(title)

	pause = LxPauseMenu.new()
	pause.name = "Pause"
	add_child(pause)

	map_screen = LxMapScreen.new()
	map_screen.name = "Map"
	add_child(map_screen)

	options = LxOptionsMenu.new()
	options.name = "Options"
	add_child(options)

	rebind = LxRebindScreen.new()
	rebind.name = "Rebind"
	add_child(rebind)

	rest_shop = LxRestShop.new()
	rest_shop.name = "RestShop"
	add_child(rest_shop)

	cards = LxCards.new()
	cards.name = "Cards"
	add_child(cards)

	_cursor_node = Node2D.new()
	_cursor_node.name = "Reticle"
	_cursor_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor_node.draw.connect(_draw_reticle)
	add_child(_cursor_node)


func _connect_signals() -> void:
	title.slot_selected.connect(func(slot_num: int, is_new: bool) -> void:
		play_slot_requested.emit(slot_num, is_new)
	)
	title.options_requested.connect(func() -> void: show_options(Screen.TITLE))
	title.quit_requested.connect(func() -> void: quit_requested.emit())

	pause.resume_requested.connect(func() -> void:
		show_hud()
		resume_requested.emit()
	)
	pause.map_requested.connect(func() -> void: show_map())
	pause.options_requested.connect(func() -> void: show_options(Screen.PAUSE))
	pause.retry_checkpoint_requested.connect(func() -> void:
		show_hud()
		retry_checkpoint_requested.emit()
	)
	pause.title_requested.connect(func() -> void: return_to_title_requested.emit())

	map_screen.closed.connect(func() -> void:
		if _return_screen == Screen.PAUSE:
			show_pause()
		else:
			show_hud()
			resume_requested.emit()
	)
	map_screen.fast_travel_requested.connect(func(isl: int, ws: String) -> void:
		show_hud()
		fast_travel_requested.emit(isl, ws)
	)

	options.closed.connect(func() -> void:
		if _return_screen == Screen.TITLE:
			show_title()
		else:
			show_pause()
	)
	options.rebind_requested.connect(func() -> void: show_rebind())
	options.settings_changed.connect(func(cfg: Dictionary) -> void:
		apply_display_settings(cfg)
		settings_changed.emit(cfg)
	)

	rebind.closed.connect(func() -> void: show_options(_return_screen))
	rebind.bindings_updated.connect(func() -> void:
		if Lx.save != null:
			settings_changed.emit(Lx.save.settings)
	)

	rest_shop.closed.connect(func() -> void:
		show_hud()
		resume_requested.emit()
	)
	rest_shop.upgrade_bought.connect(func(uid: String, rank: int) -> void:
		upgrade_bought.emit(uid, rank)
	)

	cards.retry_requested.connect(func() -> void:
		show_hud()
		death_retry_requested.emit()
	)
	cards.title_requested.connect(func() -> void: return_to_title_requested.emit())
	cards.intro_finished.connect(func() -> void:
		show_hud()
		intro_finished.emit()
	)
	cards.credits_finished.connect(func() -> void: credits_finished.emit())


func bind_events() -> void:
	if hud != null:
		hud.bind_events()
	if narration != null:
		narration.bind_events()


func is_modal_open() -> bool:
	return current_screen != Screen.HUD and current_screen != Screen.NONE


func _hide_all_modals() -> void:
	title.close()
	pause.close()
	map_screen.close()
	options.close()
	rebind.close()
	rest_shop.close()
	cards.close()


func show_title(open_slots: bool = false) -> void:
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.TITLE
	title.open(open_slots)


func show_intro() -> void:
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.INTRO
	cards.show_intro()


func open_rest_shop() -> void:
	show_shop()


func set_flow(flow_id: int) -> void:
	match flow_id:
		0:
			show_title()
		1:
			show_intro()
		2:
			show_hud()
		3:
			show_pause()
		4:
			show_map()
		5:
			show_shop()
		6:
			show_death()
		7:
			show_results()
		8:
			show_credits()


func show_hud() -> void:
	_hide_all_modals()
	hud.visible = true
	current_screen = Screen.HUD


func show_pause() -> void:
	_hide_all_modals()
	hud.visible = true
	current_screen = Screen.PAUSE
	pause.open()


func show_map(from_screen: int = -1) -> void:
	if from_screen >= 0:
		_return_screen = from_screen
	elif current_screen == Screen.PAUSE or current_screen == Screen.HUD:
		_return_screen = current_screen
	_hide_all_modals()
	hud.visible = true
	current_screen = Screen.MAP
	map_screen.open()


func show_options(from_screen: int = -1) -> void:
	if from_screen >= 0:
		_return_screen = from_screen
	elif current_screen == Screen.TITLE or current_screen == Screen.PAUSE:
		_return_screen = current_screen
	_hide_all_modals()
	hud.visible = _return_screen != Screen.TITLE
	current_screen = Screen.OPTIONS
	options.open()


func show_rebind() -> void:
	_hide_all_modals()
	hud.visible = _return_screen != Screen.TITLE
	current_screen = Screen.REBIND
	rebind.open()


func show_shop() -> void:
	_hide_all_modals()
	hud.visible = true
	current_screen = Screen.SHOP
	rest_shop.open()


func show_death(is_boss: bool = false) -> void:
	_hide_all_modals()
	hud.visible = true
	current_screen = Screen.DEATH
	cards.show_death(is_boss)


func show_results(stats: Dictionary = {}) -> void:
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.RESULTS
	cards.show_results(stats)


func show_credits() -> void:
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.CREDITS
	cards.show_credits()


func close_modal() -> void:
	show_hud()


func show_notice(string_id: String, duration: float = 3.5) -> void:
	if hud != null:
		hud.show_notice(string_id, duration)


func apply_display_settings(cfg: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	var full: bool = bool(cfg.get("fullscreen", false))
	var target_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)
	if not full:
		var sc: int = clampi(int(cfg.get("window_scale", 3)), 1, 5)
		DisplayServer.window_set_size(Vector2i(320 * sc, 180 * sc))


func _process(_delta: float) -> void:
	if _cursor_node != null:
		_cursor_node.visible = (current_screen == Screen.HUD)
		if _cursor_node.visible:
			_cursor_node.queue_redraw()


func _draw_reticle() -> void:
	if _cursor_node == null or current_screen != Screen.HUD:
		return
	var cfg: Dictionary = Lx.save.settings if Lx.save != null else LxSaveService.default_settings()
	var sz: int = clampi(int(cfg.get("cursor_size", 1)), 1, 3)
	var cname: String = str(cfg.get("cursor_color", "gold"))
	var col: Color = LxPalette.color(cname, "gold")
	var pos: Vector2 = get_viewport().get_mouse_position().round()
	if Lx.input != null and Lx.input.last_device == "gamepad":
		var center: Vector2 = Vector2(160.0, 90.0)
		if Lx.player != null and Lx.camera != null and Lx.player is Node2D:
			center = (Lx.player as Node2D).global_position - Lx.camera.global_position + Vector2(160.0, 90.0)
		pos = (center + Lx.input.last_aim_dir.normalized() * 42.0).round()
	var arm: float = float(sz + 2)
	var gap: float = float(sz + 1)
	var thick: float = float(sz)
	var outline: Color = LxPalette.PAL["night"]
	var rects: Array[Rect2] = [
		Rect2(pos.x - gap - arm, pos.y - floorf(thick * 0.5), arm, thick),
		Rect2(pos.x + gap, pos.y - floorf(thick * 0.5), arm, thick),
		Rect2(pos.x - floorf(thick * 0.5), pos.y - gap - arm, thick, arm),
		Rect2(pos.x - floorf(thick * 0.5), pos.y + gap, thick, arm),
	]
	for r: Rect2 in rects:
		_cursor_node.draw_rect(r.grow(1.0), outline)
	for r: Rect2 in rects:
		_cursor_node.draw_rect(r, col)
	_cursor_node.draw_rect(Rect2(pos.x, pos.y, 1.0, 1.0), LxPalette.PAL["cream"])
