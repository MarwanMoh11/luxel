class_name LxIsland6Rule
extends RefCounted
## Island 6 (Ashen Kiln) Rule Engine:
## - Foundry Timetable (`island:6` / `kiln_shift`: station_a | station_b | station_c)
## - Global Bolt Tempering (`wick.temper` persisted in `story_flags["wick_temper"]` + `Lx.vars`,
##   with anvil ceremony and HUD mark via LxIsland6RuleFx)
## - Moving-train room visuals (scrolling carriage windows, roof wind streaks, train_brake slow)
## - Great Kiln Heat Flow (`dungeon:great_kiln` / `kiln_heat`: low | surge)
## - Iron Colossus stride HUD pendulum sync & Heat-Boots crumble grace.

const ISLAND_ID: int = 6
const SCOPE_ISLAND: String = "island:6"
const SCOPE_EXPRESS: String = "dungeon:ember_express"
const SCOPE_KILN: String = "dungeon:great_kiln"
const VAR_SHIFT: String = "kiln_shift"
const VAR_BRAKE: String = "train_brake"
const VAR_HEAT: String = "kiln_heat"
const VAR_TEMPER: String = "wick_temper"
const FLAG_TEMPER: String = "wick_temper"
const VALID_SHIFTS: Array[String] = ["station_a", "station_b", "station_c"]
const VALID_TEMPERS: Array[String] = ["", "skip", "scatter", "lance"]
const BRAKE_DURATION_S: float = 6.0

const PAL: Dictionary = LxPalette.PAL

static var active_instance: LxIsland6Rule = null

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false
var _vars_bound: LxWorldState = null

var _hud_node: Node2D = null
var _train_fx: Node2D = null
var _tick_driver: Node = null

var _clock: float = 0.0
var _temper_pop_t: float = 0.0
var _shift_flash_t: float = 0.0
var _brake_timer: float = 0.0
var _train_mode: String = "" # "", "interior", "roof"
var _train_scroll: float = 0.0
var _wind_base_strength: Dictionary = {}
var _cart_base_speed: Dictionary = {}
var _stride_warn: bool = false
var _stride_side: int = 1
var _stride_stabilized: bool = false
var _stride_active: bool = false


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_attached = true
	active_instance = self
	_ensure_default_vars()
	sync_temper_from_state()
	if _events != null and not _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.connect(_on_region_entered)
	_bind_vars()
	_mount_hud_overlay()
	_mount_tick_driver()


func detach() -> void:
	if active_instance == self:
		active_instance = null
	if _events != null and _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null
	_unmount_nodes()
	_wind_base_strength.clear()
	_cart_base_speed.clear()
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_bind_vars()
	_ensure_default_vars()
	sync_temper_from_state()
	_wind_base_strength.clear()
	_cart_base_speed.clear()
	_stride_active = false
	_stride_warn = false
	_apply_heat_boots_crumble_grace()
	_sync_train_brake_effects()
	_sync_heat_flow_wind_zones()
	_setup_train_fx(region_id)
	_mount_hud_overlay()
	_mount_tick_driver()
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id == ISLAND_ID:
		on_region_loaded(region_id)


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _ensure_default_vars() -> void:
	if Lx.vars == null:
		return
	if str(Lx.vars.get_var(SCOPE_ISLAND, VAR_SHIFT, "")) not in VALID_SHIFTS:
		Lx.vars.set_var(SCOPE_ISLAND, VAR_SHIFT, "station_a")
	if str(Lx.vars.get_var(SCOPE_KILN, VAR_HEAT, "")) not in ["low", "surge"]:
		Lx.vars.set_var(SCOPE_KILN, VAR_HEAT, "low")
	if str(Lx.vars.get_var(SCOPE_EXPRESS, VAR_BRAKE, "")) not in ["running", "braked"]:
		Lx.vars.set_var(SCOPE_EXPRESS, VAR_BRAKE, "running")


func _on_var_changed(_scope: String, var_name: String, value: Variant) -> void:
	var val_s: String = str(value).strip_edges().to_lower()
	match var_name:
		VAR_SHIFT:
			_on_kiln_shift_changed(val_s)
		VAR_HEAT:
			_on_kiln_heat_changed(val_s)
		VAR_BRAKE:
			_on_train_brake_changed(val_s)
		VAR_TEMPER:
			if Lx.player is LxWick and is_instance_valid(Lx.player) and val_s in VALID_TEMPERS:
				(Lx.player as LxWick).temper = val_s
			if _hud_node != null and is_instance_valid(_hud_node):
				_hud_node.queue_redraw()


func _on_kiln_shift_changed(station: String) -> void:
	if station not in VALID_SHIFTS:
		return
	_shift_flash_t = 1.2
	var st: LxGameState = _get_state()
	if st != null:
		st.story_flags["shift_" + station] = true
		if bool(st.story_flags.get("shift_station_a", false)) \
				and bool(st.story_flags.get("shift_station_b", false)) \
				and bool(st.story_flags.get("shift_station_c", false)):
			st.story_flags["q6_timetable_stamped"] = true
	if _events != null:
		_events.sfx_requested.emit("steam_whistle", Vector2.ZERO, false)
		_events.shake_requested.emit(0.06 if LxHudFx.flash_reduced() else 0.14)
		var cue: String = "ISL6_SHIFT_A" if station == "station_a" else ("ISL6_SHIFT_B" if station == "station_b" else "ISL6_SHIFT_C")
		if LxStrings.has_id(cue):
			_events.narration_requested.emit(cue, "narration", 2.8)
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_kiln_heat_changed(heat_val: String) -> void:
	if heat_val not in ["low", "surge"]:
		return
	var st: LxGameState = _get_state()
	if st != null:
		st.story_flags["kiln_heat_toggle"] = true
	_sync_heat_flow_wind_zones()
	if _events != null:
		_events.sfx_requested.emit("furnace_draw" if heat_val == "surge" else "magma_crack", Vector2.ZERO, false)
		_events.shake_requested.emit(0.05 if LxHudFx.flash_reduced() else 0.10)
		var cue: String = "ISL6_HEAT_SURGE" if heat_val == "surge" else "ISL6_HEAT_LOW"
		if LxStrings.has_id(cue):
			_events.narration_requested.emit(cue, "narration", 2.6)
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_train_brake_changed(brake_val: String) -> void:
	if brake_val == "braked":
		_brake_timer = BRAKE_DURATION_S
		if _events != null:
			_events.sfx_requested.emit("steam_whistle", Vector2.ZERO, false)
			_events.shake_requested.emit(0.04 if LxHudFx.flash_reduced() else 0.09)
	else:
		_brake_timer = 0.0
	_sync_train_brake_effects()


# ---- Public Rule & Tempering API ----

static func get_kiln_shift() -> String:
	if Lx.vars != null:
		var s: String = str(Lx.vars.get_var(SCOPE_ISLAND, VAR_SHIFT, "station_a")).strip_edges().to_lower()
		if s in VALID_SHIFTS:
			return s
	return "station_a"


static func set_kiln_shift(station: String) -> String:
	var s: String = station.strip_edges().to_lower()
	if s not in VALID_SHIFTS:
		s = "station_a"
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_ISLAND, VAR_SHIFT, s)
	return s


static func cycle_kiln_shift() -> String:
	var idx: int = VALID_SHIFTS.find(get_kiln_shift())
	return set_kiln_shift(VALID_SHIFTS[(idx + 1) % VALID_SHIFTS.size()])


static func get_kiln_heat() -> String:
	if Lx.vars != null:
		var h: String = str(Lx.vars.get_var(SCOPE_KILN, VAR_HEAT, "low")).strip_edges().to_lower()
		if h in ["low", "surge"]:
			return h
	return "low"


static func set_kiln_heat(mode: String) -> String:
	var m: String = "surge" if mode.strip_edges().to_lower() == "surge" else "low"
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_KILN, VAR_HEAT, m)
	return m


static func get_train_brake() -> String:
	if Lx.vars != null:
		var b: String = str(Lx.vars.get_var(SCOPE_EXPRESS, VAR_BRAKE, "running")).strip_edges().to_lower()
		if b in ["running", "braked"]:
			return b
	return "running"


static func engage_train_brake(secs: float = BRAKE_DURATION_S) -> void:
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_EXPRESS, VAR_BRAKE, "braked")
	if active_instance != null:
		active_instance._brake_timer = maxf(0.5, secs)
		active_instance._sync_train_brake_effects()


static func get_known_tempers() -> Array[String]:
	var out: Array[String] = []
	if Lx.state == null:
		return out
	for t: String in ["skip", "scatter", "lance"]:
		if bool(Lx.state.story_flags.get("temper_%s_known" % t, false)):
			out.append(t)
	return out


static func next_cycle_temper(cur: String, include_base: bool = false) -> String:
	var known: Array[String] = get_known_tempers()
	if known.is_empty():
		return "skip"
	var ring: Array[String] = known.duplicate()
	if include_base:
		ring.append("")
	var idx: int = ring.find(cur)
	return ring[(idx + 1) % ring.size()] if idx >= 0 else ring[0]


static func get_saved_temper() -> String:
	var t: String = ""
	if Lx.state != null and Lx.state.story_flags.has(FLAG_TEMPER):
		t = str(Lx.state.story_flags.get(FLAG_TEMPER, "")).strip_edges().to_lower()
	elif Lx.vars != null:
		t = str(Lx.vars.get_var("game", VAR_TEMPER, "")).strip_edges().to_lower()
	return t if t in VALID_TEMPERS else ""


static func sync_temper_from_state() -> String:
	var saved: String = get_saved_temper()
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).temper = saved
	return saved


static func apply_temper(mode: String, world_pos: Vector2 = Vector2.ZERO, play_ceremony: bool = true) -> String:
	var m: String = mode.strip_edges().to_lower()
	if m == "base":
		m = ""
	if m not in VALID_TEMPERS:
		m = ""
	var st: LxGameState = Lx.state
	var first_time: bool = false
	if st != null:
		st.story_flags[FLAG_TEMPER] = m
		if not m.is_empty():
			var kf: String = "temper_%s_known" % m
			first_time = not bool(st.story_flags.get(kf, false))
			st.story_flags[kf] = true
	if Lx.vars != null:
		Lx.vars.set_var("game", VAR_TEMPER, m)
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if wick != null:
		wick.temper = m
	if active_instance != null:
		active_instance._temper_pop_t = 0.55
		if active_instance._hud_node != null and is_instance_valid(active_instance._hud_node):
			active_instance._hud_node.queue_redraw()
	if play_ceremony:
		_play_anvil_ceremony(m, world_pos, first_time, wick)
	if Lx.events != null:
		Lx.events.save_requested.emit("temper_" + (m if not m.is_empty() else "base"))
	return m


static func _play_anvil_ceremony(mode: String, world_pos: Vector2, first_time: bool, wick: LxWick) -> void:
	var at: Vector2 = world_pos if world_pos != Vector2.ZERO else (wick.global_position if wick != null else Vector2.ZERO)
	var sfx_id: String = "anvil_clang_skip" if mode == "skip" else ("anvil_clang_scatter" if mode == "scatter" else ("anvil_clang_lance" if mode == "lance" else "anvil_clang_heavy"))
	var col: Color = LxIsland6RuleFx.temper_color(mode)
	var fred: bool = LxHudFx.flash_reduced()
	if Lx.events != null:
		Lx.events.sfx_requested.emit(sfx_id, at, true)
		Lx.events.hitstop_requested.emit(0.032)
		Lx.events.shake_requested.emit(0.03 if fred else 0.08)
	if wick != null:
		wick.spawn_ring(at, 3.0, 20.0, 0.30, PAL["cream"] as Color if not fred else col, 1.6)
		wick.spawn_ring(at, 4.0, 26.0, 0.34, col, 1.0)
		wick.spawn_sparks(at, Vector2.UP, 6 if fred else 11, col, 32.0, 96.0, 0.26)
		wick.spawn_sparks(at, Vector2.UP, 4, PAL["cream"] as Color, 42.0, 110.0, 0.20)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(at, 64.0, 0.72 if fred else 1.18, 0.28)
	var cue: String = "ISL6_TEMP_SKIP" if mode == "skip" else ("ISL6_TEMP_SCAT" if mode == "scatter" else ("ISL6_TEMP_LANCE" if mode == "lance" else ""))
	if not cue.is_empty() and LxStrings.has_id(cue):
		if first_time and Lx.events != null:
			Lx.events.narration_requested.emit(cue, "narration", 3.2)
		elif Lx.ui != null and Lx.ui.get("hud") != null and (Lx.ui.get("hud") as Object).has_method("spawn_world_cue"):
			var short_k: String = "ISL6_HUD_SKIP" if mode == "skip" else ("ISL6_HUD_SCAT" if mode == "scatter" else "ISL6_HUD_LANC")
			var cname: String = "gold" if mode == "skip" else ("apricot" if mode == "scatter" else "coral")
			(Lx.ui.get("hud") as Object).call("spawn_world_cue", short_k, at + Vector2(0.0, -14.0), cname, 1.2)


static func report_stride_state(side: int, warning: bool, stabilized: bool) -> void:
	if active_instance == null:
		return
	active_instance._stride_active = true
	active_instance._stride_side = side
	active_instance._stride_warn = warning
	active_instance._stride_stabilized = stabilized
	if active_instance._hud_node != null and is_instance_valid(active_instance._hud_node):
		active_instance._hud_node.queue_redraw()


# ---- Internal Region Sync & Tick ----

func _apply_heat_boots_crumble_grace() -> void:
	var st: LxGameState = _get_state()
	if st == null or not bool(st.story_flags.get("item_heat_boots", false)):
		return
	if Lx.world == null or not Lx.world.has_method("get_interactables"):
		return
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "crumble_floor":
			var cf: LxInteractable = it_v as LxInteractable
			if not bool(cf.get_meta("_heat_boots_applied", false)):
				cf.set_meta("_heat_boots_applied", true)
				var d_v: Variant = cf.get("delay")
				if d_v is float or d_v is int:
					cf.set("delay", float(d_v) + 0.35)


func _sync_train_brake_effects() -> void:
	if Lx.world == null or not Lx.world.has_method("get_interactables"):
		return
	var braked: bool = get_train_brake() == "braked"
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or not is_instance_valid(it_v as Object):
			continue
		var it: LxInteractable = it_v as LxInteractable
		var iid: int = it.get_instance_id()
		if it.kind == "wind_zone" and (_train_mode == "roof" or bool(it.props.get("train_wind", false))):
			if not _wind_base_strength.has(iid):
				_wind_base_strength[iid] = float(it.get("strength"))
			it.set("strength", float(_wind_base_strength[iid]) * (0.40 if braked else 1.0))
		elif it.kind == "vehicle_cart":
			if not _cart_base_speed.has(iid):
				_cart_base_speed[iid] = float(it.get("speed"))
			it.set("speed", float(_cart_base_speed[iid]) * (0.55 if braked else 1.0))


func _sync_heat_flow_wind_zones() -> void:
	if Lx.world == null or not Lx.world.has_method("get_interactables"):
		return
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or not is_instance_valid(it_v as Object):
			continue
		var it: LxInteractable = it_v as LxInteractable
		if it.kind == "wind_zone":
			var nv: String = str(it.props.get("needs_var", "")).strip_edges()
			if not nv.is_empty() and Lx.vars != null:
				var ok: bool = Lx.vars.eval(nv, it.island_id, it.region_id)
				it.active = ok
				it.visible = ok
				it.queue_redraw()


func _setup_train_fx(region_id: String) -> void:
	if _train_fx != null and is_instance_valid(_train_fx):
		_train_fx.visible = false
		_train_fx.queue_free()
	_train_fx = null
	_train_mode = ""
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	var rdata: Dictionary = Lx.world.get("region_data") as Dictionary if Lx.world.get("region_data") is Dictionary else {}
	var th: String = str(rdata.get("theme", "")).strip_edges().to_lower()
	if th == "ember_express_roof" or region_id in ["train_r5", "train_r6", "train_r7", "train_r10", "crash_r1", "crash_r3"]:
		_train_mode = "roof"
	elif th == "ember_express" or region_id.begins_with("train_") or region_id == "_proof_i6_1" or bool(rdata.get("moving_train", false)):
		_train_mode = "interior"
	if _train_mode.is_empty():
		return
	var fx := Node2D.new()
	fx.name = "Island6TrainFx"
	fx.z_index = 4 if _train_mode == "roof" else -3
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mode_snap: String = _train_mode
	fx.draw.connect(func() -> void:
		if fx == _train_fx and is_instance_valid(fx) and not fx.is_queued_for_deletion():
			LxIsland6RuleFx.draw_train_fx(fx, mode_snap, _train_scroll)
	)
	_train_fx = fx
	Lx.world.add_child(fx)
	fx.queue_redraw()


func _mount_hud_overlay() -> void:
	if _hud_node != null and is_instance_valid(_hud_node):
		return
	if Lx.ui == null or not is_instance_valid(Lx.ui):
		return
	var parent_hud: Node = Lx.ui.get("hud") as Node if Lx.ui.get("hud") is Node else Lx.ui
	if parent_hud == null or not is_instance_valid(parent_hud):
		return
	var hud := Node2D.new()
	hud.name = "Island6HudMark"
	hud.z_index = 2
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud.draw.connect(func() -> void:
		if hud == _hud_node and is_instance_valid(hud) and not hud.is_queued_for_deletion():
			LxIsland6RuleFx.draw_hud_mark(hud, _clock, _temper_pop_t, _shift_flash_t, _stride_active, _stride_side, _stride_warn, _stride_stabilized)
	)
	_hud_node = hud
	parent_hud.add_child(hud)


func _mount_tick_driver() -> void:
	if _tick_driver != null and is_instance_valid(_tick_driver):
		return
	var host: Node = Lx.world if (Lx.world != null and is_instance_valid(Lx.world)) else Lx.root
	if host == null or not is_instance_valid(host):
		return
	_tick_driver = Node.new()
	_tick_driver.name = "Island6RuleDriver"
	_tick_driver.set_process(true)
	host.add_child(_tick_driver)
	_tick_driver.get_tree().process_frame.connect(_on_process_frame)


func _unmount_nodes() -> void:
	if _tick_driver != null and is_instance_valid(_tick_driver):
		if _tick_driver.get_tree() != null and _tick_driver.get_tree().process_frame.is_connected(_on_process_frame):
			_tick_driver.get_tree().process_frame.disconnect(_on_process_frame)
		_tick_driver.queue_free()
	_tick_driver = null
	if _train_fx != null and is_instance_valid(_train_fx):
		_train_fx.visible = false
		_train_fx.queue_free()
	_train_fx = null
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.visible = false
		_hud_node.queue_free()
	_hud_node = null


func _on_process_frame() -> void:
	if not _attached:
		return
	var dt: float = 1.0 / 60.0
	if _tick_driver != null and is_instance_valid(_tick_driver):
		dt = clampf(_tick_driver.get_process_delta_time(), 0.0, 0.1)
	tick_rule(dt)


func tick_rule(dt: float) -> void:
	_clock += dt
	var redraw_hud: bool = false
	if _temper_pop_t > 0.0:
		_temper_pop_t = maxf(0.0, _temper_pop_t - dt)
		redraw_hud = true
	if _shift_flash_t > 0.0:
		_shift_flash_t = maxf(0.0, _shift_flash_t - dt)
		redraw_hud = true
	if _brake_timer > 0.0:
		_brake_timer = maxf(0.0, _brake_timer - dt)
		if _brake_timer <= 0.0 and get_train_brake() == "braked" and Lx.vars != null:
			Lx.vars.set_var(SCOPE_EXPRESS, VAR_BRAKE, "running")
	if _train_fx != null and is_instance_valid(_train_fx):
		var spd: float = 42.0 if get_train_brake() == "braked" else 118.0
		if LxHudFx.flash_reduced():
			spd *= 0.45
		_train_scroll = fposmod(_train_scroll + spd * dt, 96.0)
		_train_fx.queue_redraw()
	if _stride_active:
		redraw_hud = true
	if redraw_hud and _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
