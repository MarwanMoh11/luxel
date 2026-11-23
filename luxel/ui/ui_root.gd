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
signal ending_finished()
signal credits_finished()

enum Screen { NONE, TITLE, INTRO, HUD, PAUSE, MAP, OPTIONS, REBIND, SHOP, DEATH, ENDING, RESULTS, CREDITS }

var current_screen: int = Screen.NONE
var _return_screen: int = Screen.TITLE
var _main: Node = null

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
		if _main != null:
			if is_new and _main.has_method("start_new_game"):
				_main.call("start_new_game", slot_num, true)
			elif not is_new and _main.has_method("continue_slot"):
				_main.call("continue_slot", slot_num)
	)
	title.options_requested.connect(func() -> void: show_options(Screen.TITLE))
	title.quit_requested.connect(func() -> void:
		quit_requested.emit()
		if _main != null:
			get_tree().quit()
	)

	pause.resume_requested.connect(func() -> void:
		show_hud()
		resume_requested.emit()
		_notify_main_resume()
	)
	pause.map_requested.connect(func() -> void: show_map())
	pause.options_requested.connect(func() -> void: show_options(Screen.PAUSE))
	pause.retry_checkpoint_requested.connect(func() -> void:
		show_hud()
		retry_checkpoint_requested.emit()
		if _main != null and _main.has_method("retry_from_death"):
			_main.call("retry_from_death")
	)
	pause.title_requested.connect(func() -> void:
		return_to_title_requested.emit()
		if _main != null and _main.has_method("enter_title"):
			_main.call("enter_title")
	)

	map_screen.closed.connect(func() -> void:
		if _return_screen == Screen.PAUSE:
			show_pause()
		else:
			show_hud()
			resume_requested.emit()
			_notify_main_resume()
	)
	map_screen.fast_travel_requested.connect(func(isl: int, ws: String) -> void:
		show_hud()
		fast_travel_requested.emit(isl, ws)
		if _main != null and _main.has_method("fast_travel_waystone"):
			_main.call("fast_travel_waystone", isl, ws)
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
		if _main != null and _main.has_method("apply_runtime_settings"):
			_main.call("apply_runtime_settings")
	)

	rebind.closed.connect(func() -> void: show_options(_return_screen))
	rebind.bindings_updated.connect(func() -> void:
		if Lx.save != null:
			settings_changed.emit(Lx.save.settings)
		if _main != null and _main.has_method("apply_runtime_settings"):
			_main.call("apply_runtime_settings")
	)

	rest_shop.closed.connect(func() -> void:
		show_hud()
		resume_requested.emit()
		_notify_main_resume()
	)
	rest_shop.upgrade_bought.connect(func(uid: String, rank: int) -> void:
		upgrade_bought.emit(uid, rank)
	)

	cards.retry_requested.connect(func() -> void:
		show_hud()
		death_retry_requested.emit()
		if _main != null and _main.has_method("retry_from_death"):
			_main.call("retry_from_death")
	)
	cards.title_requested.connect(func() -> void:
		return_to_title_requested.emit()
		if _main != null and _main.has_method("enter_title"):
			_main.call("enter_title")
	)
	cards.intro_finished.connect(func() -> void:
		show_hud()
		intro_finished.emit()
		if _main != null and _main.has_method("finish_intro"):
			_main.call("finish_intro")
		elif _main != null and int(_main.get("flow")) == 1:
			_main.set("flow", 2)
	)
	cards.ending_finished.connect(func() -> void:
		ending_finished.emit()
		if _main != null and _main.has_method("enter_credits"):
			_main.call("enter_credits")
		else:
			show_credits()
	)
	cards.credits_finished.connect(func() -> void:
		credits_finished.emit()
		if _main != null and _main.has_method("enter_title"):
			_main.call("enter_title")
	)


func setup(main_node: Node) -> void:
	_main = main_node
	bind_events()
	if Lx.save != null:
		apply_display_settings(Lx.save.settings)


func _notify_main_resume() -> void:
	if _main == null or not _main.has_method("toggle_pause"):
		return
	var cur_flow: int = int(_main.get("flow"))
	if cur_flow == 3 or cur_flow == 4 or cur_flow == 5:
		_main.call("toggle_pause")


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
	if _cursor_node != null:
		_cursor_node.visible = false


func show_title(open_slots: bool = false) -> void:
	_hide_all_modals()
	if narration != null:
		narration.clear_all()
	if Lx.hitstop != null:
		Lx.hitstop.clear()
	hud.visible = false
	current_screen = Screen.TITLE
	title.open(open_slots)


func show_intro() -> void:
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.INTRO
	cards.show_intro()


func open_rest_shop() -> void:
	if _main != null and _main.has_method("open_rest_shop"):
		_main.call("open_rest_shop")
	else:
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
			show_death(hud != null and bool(hud.get("_boss_active")))
		7:
			show_ending()
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


func show_ending(p_mode: String = "") -> void:
	var mode_str: String = p_mode
	if mode_str.is_empty():
		var host: Node = _main if _main != null else Lx.root
		if host != null and host.get("ending_mode") != null:
			mode_str = str(host.get("ending_mode"))
	if mode_str.is_empty():
		mode_str = str(Lx.get_decision("ending_mode", "display_off"))
	_hide_all_modals()
	hud.visible = false
	current_screen = Screen.ENDING
	cards.show_ending(mode_str)


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


func advance_ending() -> void:
	if current_screen == Screen.ENDING:
		show_results()
	elif current_screen == Screen.RESULTS:
		ending_finished.emit()
		if _main != null and _main.has_method("enter_credits"):
			_main.call("enter_credits")
		else:
			show_credits()


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
		var usable: Rect2i = DisplayServer.screen_get_usable_rect()
		var target_sz := Vector2i(320 * sc, 180 * sc)
		if usable.size.x > 320 and usable.size.y > 180:
			target_sz.x = mini(target_sz.x, usable.size.x)
			target_sz.y = mini(target_sz.y, usable.size.y)
		DisplayServer.window_set_size(target_sz)
		if usable.size.x > target_sz.x and usable.size.y > target_sz.y:
			DisplayServer.window_set_position(usable.position + (usable.size - target_sz) / 2)


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if _cursor_node != null:
		var in_hud: bool = (current_screen == Screen.HUD)
		_cursor_node.visible = in_hud
		if DisplayServer.get_name() != "headless":
			var want_mode: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if in_hud else Input.MOUSE_MODE_VISIBLE
			if Input.get_mouse_mode() != want_mode:
				Input.set_mouse_mode(want_mode)
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
		pos = Vector2(clampf(pos.x, 8.0, 312.0), clampf(pos.y, 8.0, 172.0))
	var arm: float = float(sz + 2)
	var gap: float = float(sz + 1)
	var zip_ready: bool = false
	var lan_stolen: bool = false
	var beam_ready: bool = false
	var sunflare_ready: bool = false
	var counter_ready: bool = false
	if Lx.player != null and is_instance_valid(Lx.player):
		var mz: Variant = Lx.player.get("muzzle_t")
		if (mz is float or mz is int) and float(mz) > 0.0:
			gap += 1.0
		if Lx.player.has_method("beam_charge_progress"):
			var bp: float = float(Lx.player.call("beam_charge_progress"))
			if bp > 0.01:
				gap = maxf(1.0, roundf(gap + lerpf(2.0, -1.0, bp)))
				beam_ready = bp >= 0.999
		var md_v: Variant = Lx.player.get("move_dash")
		if md_v is Object and is_instance_valid(md_v):
			var ct_v: Variant = (md_v as Object).get("counter_t")
			counter_ready = (ct_v is float or ct_v is int) and float(ct_v) > 0.0
		var sf_v: Variant = Lx.player.get("move_sunflare")
		if sf_v is Object and is_instance_valid(sf_v) and (sf_v as Object).has_method("can_use"):
			sunflare_ready = bool((sf_v as Object).call("can_use"))
		var lan_v: Variant = Lx.player.get("lantern")
		if lan_v is Object and is_instance_valid(lan_v):
			if (lan_v as Object).has_method("is_lure_active"):
				zip_ready = bool((lan_v as Object).call("is_lure_active"))
			lan_stolen = int((lan_v as Object).get("state")) == 4
	var outline: Color = LxPalette.PAL["night"]
	var cream: Color = LxPalette.PAL["cream"]
	var draw_col: Color = LxPalette.PAL["coral"] if lan_stolen else (cream if beam_ready else (LxPalette.PAL["apricot"] if zip_ready else col))
	var arms: Array[Rect2] = [
		Rect2(pos.x - gap - arm, pos.y, arm, 1.0),
		Rect2(pos.x + 1.0 + gap, pos.y, arm, 1.0),
		Rect2(pos.x, pos.y - gap - arm, 1.0, arm),
		Rect2(pos.x, pos.y + 1.0 + gap, 1.0, arm),
	]
	if sz == 3:
		arms.append(Rect2(pos.x - gap - arm + 1.0, pos.y - 1.0, arm - 2.0, 3.0))
		arms.append(Rect2(pos.x + 2.0 + gap, pos.y - 1.0, arm - 2.0, 3.0))
		arms.append(Rect2(pos.x - 1.0, pos.y - gap - arm + 1.0, 3.0, arm - 2.0))
		arms.append(Rect2(pos.x - 1.0, pos.y + 2.0 + gap, 3.0, arm - 2.0))
	if sz >= 2 or zip_ready or lan_stolen:
		var d: float = float(sz + 1)
		for corner: Vector2 in [
			Vector2(-d, -d), Vector2(d, -d),
			Vector2(-d, d), Vector2(d, d),
		]:
			arms.append(Rect2(pos + corner, Vector2(1.0, 1.0)))
	for r: Rect2 in arms:
		_cursor_node.draw_rect(r.grow(1.0), outline)
	for r: Rect2 in arms:
		_cursor_node.draw_rect(r, draw_col)
	if sz == 3:
		_cursor_node.draw_rect(Rect2(pos.x - gap - arm + 2.0, pos.y, arm - 3.0, 1.0), cream)
		_cursor_node.draw_rect(Rect2(pos.x + 2.0 + gap, pos.y, arm - 3.0, 1.0), cream)
		_cursor_node.draw_rect(Rect2(pos.x, pos.y - gap - arm + 2.0, 1.0, arm - 3.0), cream)
		_cursor_node.draw_rect(Rect2(pos.x, pos.y + 2.0 + gap, 1.0, arm - 3.0), cream)
	# Dark-outlined center pinpoint stays razor-sharp on bright stone and dark floors.
	_cursor_node.draw_rect(Rect2(pos.x - 1.0, pos.y, 3.0, 1.0), outline)
	_cursor_node.draw_rect(Rect2(pos.x, pos.y - 1.0, 1.0, 3.0), outline)
	_cursor_node.draw_rect(Rect2(pos.x, pos.y, 1.0, 1.0), cream)
	if counter_ready and not lan_stolen:
		var cd: float = gap + 2.0
		for cp: Vector2 in [Vector2(-cd, -cd), Vector2(cd, -cd), Vector2(-cd, cd), Vector2(cd, cd)]:
			_cursor_node.draw_rect(Rect2(pos + cp - Vector2.ONE, Vector2(3.0, 3.0)), outline)
			_cursor_node.draw_rect(Rect2(pos + cp, Vector2(1.0, 1.0)), LxPalette.PAL["ice"])
	if sunflare_ready and not lan_stolen:
		var no_flash: bool = bool(cfg.get("flash_reduction", false))
		var sf_col: Color = LxPalette.PAL["gold"] if (no_flash or int(Time.get_ticks_msec() / 320) % 2 == 0) else cream
		var sd: float = gap + arm + 2.0
		for sp: Vector2 in [Vector2(-sd, 0.0), Vector2(sd, 0.0), Vector2(0.0, -sd), Vector2(0.0, sd)]:
			_cursor_node.draw_rect(Rect2(pos + sp - Vector2.ONE, Vector2(3.0, 3.0)), outline)
			_cursor_node.draw_rect(Rect2(pos + sp, Vector2(1.0, 1.0)), sf_col)
	var biome_col: Color = _active_biome_reticle_color()
	if biome_col.a > 0.5 and not lan_stolen:
		var no_flash_b: bool = bool(cfg.get("flash_reduction", false))
		var tick_b: int = 0 if no_flash_b else (int(Time.get_ticks_msec() / 420) % 2)
		var bd: float = gap + 4.0
		var b_pts: Array[Vector2] = [Vector2(-bd, -bd), Vector2(bd, -bd), Vector2(-bd, bd), Vector2(bd, bd)]
		for bi: int in range(b_pts.size()):
			var bp: Vector2 = b_pts[bi]
			var pip_c: Color = cream if (not no_flash_b and ((bi + tick_b) % 2 == 0)) else biome_col
			_cursor_node.draw_rect(Rect2(pos + bp - Vector2.ONE, Vector2(3.0, 3.0)), outline)
			_cursor_node.draw_rect(Rect2(pos + bp, Vector2(1.0, 1.0)), pip_c)


func _active_biome_reticle_color() -> Color:
	var rules: LxBiomeRules = LxBiomeRules.active_instance
	var mech: LxBiomeMechanics = LxBiomeMechanics.active_instance
	if rules != null and is_instance_valid(rules):
		if rules.beam_buff_t > 0.0:
			return LxPalette.PAL["ice"]
		if rules.starlight_surge_t > 0.0:
			return LxPalette.PAL["sky"]
	if mech != null and is_instance_valid(mech):
		if mech.molten_charges > 0:
			return LxPalette.PAL["coral"]
		if mech.tailwind_t > 0.0:
			return LxPalette.PAL["rose"]
		if mech.mirror_echo_active and rules != null and is_instance_valid(rules) and rules.lunar_phase > 0.65:
			return LxPalette.PAL["ice"]
		if mech.dawn_seals_broken > 0 and rules != null and is_instance_valid(rules) and rules.island_id == 8:
			return LxPalette.PAL["gold"]
	return Color(0.0, 0.0, 0.0, 0.0)
