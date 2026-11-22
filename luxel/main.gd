class_name LxMain
extends Node2D
## Root controller for Luxel 1.0 (res://luxel/luxel.tscn).
## Manages service bootstrap, game flow (title, intro, play, pause, map, rest_shop,
## death, ending, credits), autosaves, region transitions, and debug args (SWARM_SPEC 5.6).

enum Flow { TITLE, INTRO, PLAY, PAUSE, MAP, REST_SHOP, DEATH, ENDING, CREDITS }

const VIEW_SIZE := Vector2(320.0, 180.0)

var flow: int = Flow.TITLE
var active_slot: int = 1
var current_island_script: RefCounted = null
var ending_mode: String = "display_off"
var ending_timer: float = 0.0
var intro_timer: float = 0.0
var _region_loader: Node2D = null
var _darkness_layer: CanvasLayer = null
var _wick: Node2D = null
var _ui_root: CanvasLayer = null
var _director: RefCounted = null
var _services_ready: bool = false
var _headless_bot_active: bool = false
var _tracked_boss: Object = null
var _last_zone_id: String = ""


func _ready() -> void:
	_boot_services()
	_apply_debug_args()


func _boot_services() -> void:
	if _services_ready:
		return
	Lx.reset()
	Lx.root = self
	Lx.load_all_data()

	var dbg := LxDebugArgs.new()
	dbg.parse()
	Lx.debug = dbg

	var rng := LxRng.new(dbg.seed_val if dbg.has_seed else 101)
	Lx.rng = rng

	var plat := LxPlatformService.new()
	plat.init()
	Lx.platform = plat

	var events := LxEventBus.new()
	events.name = "EventBus"
	add_child(events)
	Lx.events = events

	var state := LxGameState.new()
	state.name = "GameState"
	add_child(state)
	state.reset_new_game("1")
	Lx.state = state

	var save_svc := LxSaveService.new()
	save_svc.name = "SaveService"
	add_child(save_svc)
	save_svc.setup(dbg.is_debug_run())
	Lx.save = save_svc

	var input_svc := LxInputService.new()
	input_svc.name = "InputService"
	add_child(input_svc)
	input_svc.setup()
	if save_svc.settings.has("bindings"):
		input_svc.import_bindings(save_svc.settings["bindings"] as Dictionary)
	if save_svc.settings.has("hold_mode"):
		input_svc.hold_modes = (save_svc.settings["hold_mode"] as Dictionary).duplicate(true)
	Lx.input = input_svc

	var audio_svc := LxAudioService.new()
	audio_svc.name = "AudioService"
	add_child(audio_svc)
	audio_svc.setup()
	audio_svc.apply_settings(save_svc.settings)
	Lx.audio = audio_svc

	var hitstop := LxHitstop.new()
	hitstop.name = "Hitstop"
	hitstop.game_speed = float(save_svc.settings.get("assist_game_speed", 1.0))
	add_child(hitstop)
	Lx.hitstop = hitstop

	var cam := LxCameraRig.new()
	cam.name = "CameraRig"
	cam.shake_scale = float(save_svc.settings.get("screen_shake", 100)) / 100.0
	add_child(cam)
	Lx.camera = cam

	_director = _instantiate_script("res://luxel/enemies/attack_director.gd")
	Lx.director = _director

	_region_loader = _instantiate_node("res://luxel/world/region_loader.gd", "RegionLoader") as Node2D
	if _region_loader != null:
		add_child(_region_loader)
		Lx.world = _region_loader

	_wick = _instantiate_node("res://luxel/player/wick.gd", "Wick") as Node2D
	if _wick != null:
		add_child(_wick)
		Lx.player = _wick
		if _wick.has_method("setup"):
			_wick.call("setup", _region_loader)

	_darkness_layer = _instantiate_node("res://luxel/world/darkness_layer.gd", "DarknessLayer") as CanvasLayer
	if _darkness_layer != null:
		add_child(_darkness_layer)

	_ui_root = _instantiate_node("res://luxel/ui/ui_root.gd", "UiRoot") as CanvasLayer
	if _ui_root != null:
		add_child(_ui_root)
		Lx.ui = _ui_root
		if _ui_root.has_method("setup"):
			_ui_root.call("setup", self)

	_connect_events()
	_validate_strings_debug()
	_services_ready = true

func _validate_strings_debug() -> void:
	if not OS.is_debug_build():
		return
	var script_res: Variant = load("res://luxel/story/strings.gd")
	if script_res != null and script_res.has_method("validate"):
		var errs: PackedStringArray = script_res.call("validate")
		if not errs.is_empty():
			push_warning("LxStrings validation issues: " + str(errs.size()))

func _connect_events() -> void:
	var ev: LxEventBus = Lx.events
	ev.player_damaged.connect(_on_player_damaged)
	ev.player_died.connect(_on_player_died)
	ev.enemy_attack_landed.connect(_on_enemy_attack_landed)
	ev.hitstop_requested.connect(func(d: float) -> void: Lx.hitstop.trigger(d))
	ev.shake_requested.connect(func(i: float) -> void: Lx.camera.add_shake(i))
	ev.sfx_requested.connect(func(id: String, p: Vector2, sp: bool) -> void: Lx.audio.play_sfx(id, p, sp))
	ev.music_mode_requested.connect(func(m: String) -> void: Lx.audio.set_music_mode(m))
	ev.save_requested.connect(_on_save_requested)
	ev.waystone_lit.connect(_on_waystone_lit)
	ev.beacon_lit.connect(_on_beacon_lit)
	ev.shrine_claimed.connect(_on_shrine_claimed)
	ev.boss_defeated.connect(_on_boss_defeated)
	ev.great_lamp_relit.connect(_on_great_lamp_relit)
	ev.ending_requested.connect(trigger_ending)

func _apply_debug_args() -> void:
	var dbg: LxDebugArgs = Lx.debug
	if dbg == null:
		enter_title()
		return
	if not dbg.ending.is_empty():
		start_new_game(1, false)
		trigger_ending(dbg.ending)
		return
	if dbg.smoke:
		_run_smoke_mode()
		return
	if dbg.quick_play or dbg.island > 0 or not dbg.region.is_empty() or not dbg.boss.is_empty():
		start_new_game(1, false)
		for mv: String in dbg.get_override_moves():
			Lx.state.unlock_move(mv)
		if dbg.hearts > 0:
			Lx.state.max_hearts = clampi(dbg.hearts, 4, 12)
			Lx.state.hearts = float(Lx.state.max_hearts)
		if _wick != null and _wick.has_method("sync_unlocks_from_state"):
			_wick.call("sync_unlocks_from_state")
		var target_isl: int = dbg.island if dbg.island > 0 else 1
		var target_reg: String = dbg.region if not dbg.region.is_empty() else (dbg.room if not dbg.room.is_empty() else "overworld")
		load_island_region(target_isl, target_reg)
		return
	enter_title()

func enter_title() -> void:
	flow = Flow.TITLE
	Lx.audio.set_paused(false)
	Lx.audio.play_cue("title")
	_sync_ui_flow()

func start_new_game(slot_num: int, play_intro: bool = true) -> void:
	active_slot = clampi(slot_num, 1, LxSaveService.SLOT_COUNT)
	Lx.state.reset_new_game(str(active_slot))
	Lx.save.save_slot(active_slot, Lx.state)
	Lx.state.append_run_log("new_game")
	load_island_region(1, "overworld")
	if play_intro:
		flow = Flow.INTRO
		intro_timer = 0.0
	else:
		flow = Flow.PLAY
	_sync_ui_flow()

func finish_intro() -> void:
	if flow != Flow.INTRO:
		return
	flow = Flow.PLAY
	_sync_ui_flow()
	if Lx.events != null and Lx.state != null and Lx.state.island_id == 1:
		Lx.events.narration_requested.emit("ISL1_ARRIVAL", "narration", 4.0)
		Lx.events.prompt_requested.emit("PROMPT_AIM_SHOOT", "lx_fire", 6.0)


func continue_slot(slot_num: int) -> bool:
	active_slot = clampi(slot_num, 1, LxSaveService.SLOT_COUNT)
	if not Lx.save.load_slot(active_slot, Lx.state):
		return false
	if Lx.state.hearts <= 0.0: Lx.state.heal_full()
	if _wick != null and _wick.has_method("sync_unlocks_from_state"):
		_wick.call("sync_unlocks_from_state")
	load_island_region(Lx.state.island_id, Lx.state.region_id, Lx.state.spawn_pos)
	flow = Flow.PLAY
	Lx.audio.set_paused(false)
	_sync_ui_flow()
	if Lx.save.last_load_used_backup and not Lx.save.last_notice_key.is_empty() and _ui_root != null and _ui_root.has_method("show_notice"):
		_ui_root.call("show_notice", Lx.save.last_notice_key, 4.0)
	return true

func load_island_region(island_id: int, region_id: String, spawn_override: Vector2 = Vector2(-1.0, -1.0)) -> bool:
	if _tracked_boss != null and Lx.ui != null and Lx.ui.get("hud") != null:
		(Lx.ui.get("hud") as Node).call("hide_boss")
	_tracked_boss = null
	_last_zone_id = ""
	if _region_loader != null and _region_loader.has_method("save_interactables_to_state"):
		_region_loader.call("save_interactables_to_state")
	Lx.state.island_id = island_id
	Lx.state.region_id = region_id
	Lx.state.room_id = "" if region_id == "overworld" else region_id
	Lx.state.mark_region_visited(island_id, region_id)

	if current_island_script != null and current_island_script.has_method("detach"):
		current_island_script.call("detach")
	current_island_script = null
	var ok: bool = false
	if _region_loader != null and _region_loader.has_method("load_region"):
		ok = bool(_region_loader.call("load_region", island_id, region_id, _director))
	var spawn_at: Vector2 = spawn_override
	if spawn_at.x < 0.0 and _region_loader != null:
		if _region_loader.has_method("get_spawn_pos"):
			spawn_at = _region_loader.call("get_spawn_pos") as Vector2
		else:
			var sp_prop: Variant = _region_loader.get("spawn_pos")
			if sp_prop is Vector2:
				spawn_at = sp_prop as Vector2
	if spawn_at.x < 0.0: spawn_at = Vector2(160.0, 90.0)
	Lx.state.spawn_pos = spawn_at
	if Lx.hitstop != null: Lx.hitstop.clear()
	if _wick != null and _wick.has_method("reset_for_room"): _wick.call("reset_for_room", spawn_at)
	var is_dun: bool = false
	if _region_loader != null and _region_loader.has_method("get_bounds"):
		var b: Rect2 = _region_loader.call("get_bounds")
		is_dun = bool(_region_loader.get("is_dungeon"))
		Lx.camera.set_bounds(b, is_dun)
		Lx.camera.snap_to(spawn_at)
	if _darkness_layer != null:
		if _darkness_layer.has_method("reset_zones"): _darkness_layer.call("reset_zones")
		if _darkness_layer.has_method("stop_dawn_wave"): _darkness_layer.call("stop_dawn_wave")
		if _darkness_layer.has_method("set_darkness"): _darkness_layer.call("set_darkness", 0.0 if Lx.state.relit_islands.has(island_id) else 0.56)
		if _darkness_layer.has_method("trigger_transition_fade"): _darkness_layer.call("trigger_transition_fade", 0.22)
		if _darkness_layer.has_method("sync"): _darkness_layer.call("sync", 0.0, _region_loader)
	_load_island_controller(island_id)
	if is_dun:
		Lx.audio.start_dungeon_music(island_id)
	else:
		Lx.audio.start_island_music(island_id)
	Lx.events.region_entered.emit(island_id, region_id)
	if region_id != "overworld":
		Lx.save.save_slot(active_slot, Lx.state)
	return ok

func _load_island_controller(island_id: int) -> void:
	var path: String = "res://luxel/islands/%d/island.gd" % island_id
	if ResourceLoader.exists(path):
		current_island_script = _instantiate_script(path)
		if current_island_script != null:
			if current_island_script.has_method("attach"):
				current_island_script.call("attach", Lx.events, Lx.state)
			if current_island_script.has_method("on_region_loaded"):
				current_island_script.call("on_region_loaded", Lx.state.region_id)

func fast_travel_waystone(island_id: int, waystone_id: String) -> bool:
	if not Lx.state.lit_waystones.has(waystone_id):
		return false
	Lx.state.last_waystone_island = island_id
	Lx.state.last_waystone_id = waystone_id
	Lx.state.heal_full()
	var loc: Dictionary = LxMapFormat.find_waystone(island_id, waystone_id)
	load_island_region(island_id, str(loc.get("region", "overworld")), loc.get("pos", Vector2(-1.0, -1.0)) as Vector2)
	flow = Flow.PLAY
	Lx.audio.set_paused(false)
	Lx.audio.play_sfx("waystone_rest", Vector2.ZERO, false)
	_sync_ui_flow()
	return true

func toggle_pause() -> void:
	if flow == Flow.PLAY:
		flow = Flow.PAUSE
		Lx.audio.set_paused(true)
		Lx.events.pause_toggled.emit(true)
	elif flow == Flow.PAUSE or flow == Flow.MAP or flow == Flow.REST_SHOP:
		var was_shop: bool = flow == Flow.REST_SHOP
		flow = Flow.PLAY
		Lx.audio.set_paused(false)
		if was_shop:
			if _region_loader != null and bool(_region_loader.get("is_dungeon")): Lx.audio.start_dungeon_music(Lx.state.island_id)
			else: Lx.audio.set_music_mode("explore", true)
		Lx.events.pause_toggled.emit(false)
	_sync_ui_flow()

func open_map() -> void:
	if flow == Flow.PLAY or flow == Flow.PAUSE:
		flow = Flow.MAP
		Lx.audio.set_paused(true)
		_sync_ui_flow()
	elif flow == Flow.MAP:
		flow = Flow.PLAY
		Lx.audio.set_paused(false)
		_sync_ui_flow()

func open_rest_shop() -> void:
	if flow == Flow.PLAY:
		flow = Flow.REST_SHOP
		Lx.audio.set_paused(false)
		Lx.audio.play_cue("hub")
		_sync_ui_flow()


func retry_from_death() -> void:
	Lx.state.heal_full()
	if Lx.state.region_id != "overworld":
		load_island_region(Lx.state.island_id, Lx.state.region_id)
	else:
		var loc: Dictionary = LxMapFormat.find_waystone(Lx.state.last_waystone_island, Lx.state.last_waystone_id)
		var sp: Vector2 = loc.get("pos", Lx.state.spawn_pos) as Vector2
		load_island_region(Lx.state.last_waystone_island, str(loc.get("region", "overworld")), sp)
	flow = Flow.PLAY
	Lx.audio.set_paused(false)
	_sync_ui_flow()

func trigger_ending(mode: String = "") -> void:
	ending_mode = mode if not mode.is_empty() else str(Lx.get_decision("ending_mode", "display_off"))
	flow = Flow.ENDING
	ending_timer = 0.0
	Lx.audio.set_paused(false)
	Lx.audio.play_cue("ending_dawn")
	Lx.state.append_run_log("ending:" + ending_mode)
	_sync_ui_flow()


func enter_credits() -> void:
	flow = Flow.CREDITS
	Lx.audio.play_cue("credits")
	_sync_ui_flow()


func apply_runtime_settings() -> void:
	var cfg: Dictionary = Lx.save.settings
	Lx.audio.apply_settings(cfg)
	Lx.hitstop.game_speed = float(cfg.get("assist_game_speed", 1.0))
	Lx.camera.shake_scale = float(cfg.get("screen_shake", 100)) / 100.0
	Lx.save.save_settings()


func _notification(what: int) -> void:
	if not _services_ready:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Lx.audio.set_window_focus(false)
		if flow == Flow.PLAY:
			toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Lx.audio.set_window_focus(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _services_ready:
		return
	if event.is_action_pressed("lx_pause") and flow in [Flow.PLAY, Flow.PAUSE, Flow.MAP, Flow.REST_SHOP]:
		toggle_pause()
	elif (flow == Flow.PLAY or flow == Flow.MAP) and event.is_action_pressed("lx_map"):
		open_map()
	elif flow == Flow.INTRO and (event.is_action_pressed("lx_ui_accept") or event.is_action_pressed("lx_ui_cancel")):
		finish_intro()


func _physics_process(delta: float) -> void:
	if not _services_ready:
		return
	step_sim(delta)


func step_sim(raw_dt: float) -> void:
	if flow == Flow.INTRO:
		intro_timer += raw_dt
		Lx.audio.tick(raw_dt, false)
		if intro_timer >= 6.0:
			finish_intro()
		return
	if flow == Flow.ENDING:
		ending_timer += raw_dt
		Lx.audio.tick(raw_dt, false)
		if ending_timer >= 8.0 and _ui_root != null and int(_ui_root.get("current_screen")) == 10:
			_ui_root.call("show_results")
		return
	if flow != Flow.PLAY:
		Lx.audio.tick(raw_dt, false)
		return

	var dt: float = Lx.hitstop.step(raw_dt)
	Lx.state.play_time_s += raw_dt
	Lx.state.record_zone_time("%d:%s" % [Lx.state.island_id, Lx.state.region_id], raw_dt)
	if dt <= 0.0:
		return

	if _wick != null and _wick.has_method("tick_sim"):
		_wick.call("tick_sim", dt, _region_loader)
	if _director != null and _director.has_method("tick"):
		_director.call("tick", dt)
	var engaged_enemies: int = 0
	var wpos: Vector2 = _wick.global_position if _wick != null else Vector2.ZERO
	if _region_loader != null:
		if _region_loader.has_method("tick_region"):
			engaged_enemies = int(_region_loader.call("tick_region", dt, wpos))
		elif _region_loader.has_method("tick"):
			_region_loader.call("tick", dt, wpos)

	Lx.audio.tick(raw_dt, engaged_enemies > 0)
	_sync_boss_hud()
	if _wick != null:
		wpos = _wick.global_position
		_sync_zone_banner(wpos)
		Lx.camera.follow(wpos, raw_dt)
		if _darkness_layer != null and _darkness_layer.has_method("sync"):
			_darkness_layer.call("sync", raw_dt, _region_loader)
		if _region_loader != null and _region_loader.has_method("check_exit"):
			var ex: Dictionary = _region_loader.call("check_exit", wpos)
			if not ex.is_empty():
				var next_isl: int = int(ex.get("to_island", Lx.state.island_id))
				var next_reg: String = str(ex.get("to_region", ""))
				if next_reg.begins_with("island") and next_reg.contains(":"):
					var parts: PackedStringArray = next_reg.split(":", false, 1)
					var parsed_isl: int = int(parts[0].substr(6))
					if parsed_isl > 0:
						next_isl = parsed_isl
						next_reg = parts[1] if parts.size() > 1 and not parts[1].is_empty() else "overworld"
				var sp_arr: Array = ex.get("to_spawn", [-1.0, -1.0]) as Array
				var sp_vec := Vector2(float(sp_arr[0]), float(sp_arr[1])) if sp_arr.size() >= 2 else Vector2(-1.0, -1.0)
				if not next_reg.is_empty():
					load_island_region(next_isl, next_reg, sp_vec)


func _on_enemy_attack_landed(_enemy: Object, kind: String, pos: Vector2, dir: Vector2, damage: float) -> void:
	if _wick != null and _wick.has_method("take_damage"):
		_wick.call("take_damage", damage, pos, dir, kind)


func _on_player_damaged(_amount: float, _from_pos: Vector2, _knock_dir: Vector2, _source: String) -> void:
	pass # LxWick already increments Lx.state.hits_taken once.


func _on_player_died() -> void:
	Lx.state.append_run_log("death")
	flow = Flow.DEATH
	_sync_ui_flow()


func _on_save_requested(_reason: String) -> void:
	if _region_loader != null and _region_loader.has_method("save_interactables_to_state"):
		_region_loader.call("save_interactables_to_state")
	Lx.save.save_slot(active_slot, Lx.state)


func _on_waystone_lit(isl: int, ws_id: String) -> void:
	if not Lx.state.lit_waystones.has(ws_id):
		Lx.state.lit_waystones.append(ws_id)
	Lx.state.last_waystone_island = isl
	Lx.state.last_waystone_id = ws_id
	Lx.state.heal_full()
	_on_save_requested("waystone")


func _on_beacon_lit(_isl: int, beacon_id: String) -> void:
	if not Lx.state.lit_beacons.has(beacon_id):
		Lx.state.lit_beacons.append(beacon_id)
	Lx.audio.play_stinger("stinger_lamp")
	_on_save_requested("beacon")


func _on_shrine_claimed(shrine_id: String, move_id: String) -> void:
	if not Lx.state.claimed_shrines.has(shrine_id):
		Lx.state.claimed_shrines.append(shrine_id)
	Lx.state.unlock_move(move_id)
	if _wick != null and _wick.has_method("sync_unlocks_from_state"):
		_wick.call("sync_unlocks_from_state")
	Lx.audio.play_stinger("stinger_move")
	_on_save_requested("shrine")


func _on_boss_defeated(boss_id: String, isl: int) -> void:
	if not Lx.state.defeated_bosses.has(boss_id): Lx.state.defeated_bosses.append(boss_id)
	var is_major: bool = str(Lx.get_island_data(isl).get("boss", "")) == boss_id or boss_id == "hollow_wick_boss"
	if is_major and not bool(Lx.state.story_flags.get("boss_heart_" + boss_id, false)):
		Lx.state.story_flags["boss_heart_" + boss_id] = true
		Lx.state.add_boss_heart()
	if Lx.audio != null and Lx.audio.current_track_group.contains("_boss_"): Lx.audio.silence_music(0.85)
	if is_major: Lx.audio.play_stinger("stinger_lamp")
	_on_save_requested("boss")


func _on_great_lamp_relit(isl: int) -> void:
	if not Lx.state.relit_islands.has(isl):
		Lx.state.relit_islands.append(isl)
	if _darkness_layer != null and _darkness_layer.has_method("trigger_dawn_wave"):
		var wave_pos: Vector2 = _wick.global_position if _wick != null else Vector2(160.0, 90.0)
		_darkness_layer.call("trigger_dawn_wave", wave_pos, 260.0, 1400.0)
	Lx.audio.play_stinger("stinger_lamp")
	_on_save_requested("great_lamp")
	if isl >= 8:
		trigger_ending()


func _sync_ui_flow() -> void:
	if flow != Flow.PLAY and Lx.input != null: Lx.input.clear_all_toggles()
	if _ui_root != null and _ui_root.has_method("set_flow"): _ui_root.call("set_flow", flow)
	if _darkness_layer != null: _darkness_layer.visible = flow in [Flow.PLAY, Flow.PAUSE, Flow.MAP, Flow.REST_SHOP, Flow.DEATH]

func _sync_boss_hud() -> void:
	var hud: Node = Lx.ui.get("hud") as Node if (Lx.ui != null and Lx.ui.get("hud") != null) else null
	var boss: LxEnemyBrain = null
	if _region_loader != null and _region_loader.has_method("get_enemies"):
		for e: LxEnemyBrain in _region_loader.call("get_enemies"):
			if e != null and is_instance_valid(e) and e.is_alive() and (e.is_boss or not e.boss_id.is_empty()):
				boss = e
				break
	if boss != null and hud != null:
		if not is_instance_valid(_tracked_boss) or _tracked_boss != boss:
			_tracked_boss = boss
			hud.call("show_boss", boss.boss_id if not boss.boss_id.is_empty() else boss.kind, boss.hp, boss.max_hp, boss.phase)
		else:
			hud.call("update_boss", boss.hp, boss.max_hp, boss.phase)
	elif boss == null and _tracked_boss != null:
		_tracked_boss = null
		if hud != null:
			hud.call("hide_boss")

func _sync_zone_banner(wpos: Vector2) -> void:
	if _region_loader == null or not _region_loader.has_method("get_zones"):
		return
	for z: Dictionary in _region_loader.call("get_zones"):
		if LxMapFormat.to_rect2(z.get("rect", [])).has_point(wpos):
			var zid: String = str(z.get("id", ""))
			if zid != _last_zone_id:
				_last_zone_id = zid
				var nk: String = str(z.get("name_key", ""))
				if not nk.is_empty() and LxStrings.has_id(nk) and Lx.ui != null and Lx.ui.get("hud") != null:
					(Lx.ui.get("hud") as Node).call("show_notice", nk, 2.8)
			return


func _run_smoke_mode() -> void:
	start_new_game(1, false)
	for i: int in range(600):
		step_sim(1.0 / 60.0)
	var islands_arr: Array = Lx.data_islands.get("islands", []) as Array
	for item: Variant in islands_arr:
		if item is Dictionary:
			var iid: int = int((item as Dictionary).get("id", 1))
			var map_p: String = "res://luxel/islands/%d/overworld.map" % iid
			if FileAccess.file_exists(map_p):
				load_island_region(iid, "overworld")
	print("LUXEL SMOKE PASS")
	get_tree().quit(0)


static func _instantiate_script(path: String) -> RefCounted:
	if not ResourceLoader.exists(path):
		return null
	var sc: Variant = load(path)
	if sc is GDScript:
		return (sc as GDScript).new() as RefCounted
	return null


static func _instantiate_node(path: String, node_name: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var sc: Variant = load(path)
	if sc is GDScript:
		var inst: Variant = (sc as GDScript).new()
		if inst is Node:
			(inst as Node).name = node_name
			return inst as Node
	return null
