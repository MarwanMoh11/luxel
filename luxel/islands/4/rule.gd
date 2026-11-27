class_name LxIsland4Rule
extends Node
## Island 4 (Mirefen Gardens) Rule Engine:
## The 150 s six-hour dusk loop (six 25 s hours I-VI), visible 28x12 px Dusk Sundial HUD
## beneath the minimap, manual skip/rewind via garden_sundial, automatic pause inside
## Drowned Conservatory, boss arenas, vault_last_hour, menus, and post-relight warm sunset.
## Generous Loop Law: nothing earned is EVER lost on rewind or Hour VI wrap.

signal hour_changed(new_hour: int, manual: bool)
signal loop_rewound(manual: bool)

const ISLAND_ID: int = 4
const HOUR_SECS: float = 25.0
const HOURS_TOTAL: int = 6
const LOOP_SECS: float = 150.0

const SKIP_SWEEP_S: float = 0.40
const REWIND_SWEEP_S: float = 0.60
const WRAP_SWEEP_S: float = 1.20

const SCOPE_ISLAND: String = "island:4"
const SCOPE_PARTY: String = "dungeon:garden_party"
const SCOPE_MAUSOLEUM: String = "dungeon:rain_mausoleum"

const HOUR_CUES: Array[String] = [
	"ISL4_CUE_HOUR_1",
	"ISL4_CUE_HOUR_2",
	"ISL4_CUE_HOUR_3",
	"ISL4_CUE_HOUR_4",
	"ISL4_CUE_HOUR_5",
	"ISL4_CUE_HOUR_6",
]

static var active_instance: LxIsland4Rule = null

class DuskSundialHud:
	extends Node2D
	var rule: LxIsland4Rule = null

	func _draw() -> void:
		if rule == null:
			return
		rule._draw_hud(self)

var dusk_hour: int = 1
var hour_elapsed: float = 0.0
var dusk_paused: bool = false
var current_region: String = ""

var sweep_t: float = 0.0
var sweep_dur: float = SKIP_SWEEP_S
var sweep_mode: String = "skip"

var _events: LxEventBus = null
var _state: LxGameState = null
var _hud_layer: CanvasLayer = null
var _hud_node: DuskSundialHud = null
var _last_phys_frame: int = -1
var _sim_driver_id: int = 0
var _vars_bound: LxWorldState = null


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	active_instance = self
	_sync_from_vars()
	_bind_vars()
	_mount_nodes()
	if _state != null:
		on_region_loaded(_state.region_id)


func detach_and_free() -> void:
	if active_instance == self:
		active_instance = null
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_node = null
	if is_inside_tree():
		queue_free()


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func _mount_nodes() -> void:
	var host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else null
	if host != null and get_parent() == null:
		name = "Island4Rule"
		host.add_child(self)
	if host != null and (_hud_layer == null or not is_instance_valid(_hud_layer)):
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "Island4SundialHud"
		_hud_layer.layer = 14
		host.add_child(_hud_layer)
		_hud_node = DuskSundialHud.new()
		_hud_node.name = "DuskSundialDraw"
		_hud_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hud_node.rule = self
		_hud_layer.add_child(_hud_node)


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _sync_from_vars() -> void:
	if Lx.vars == null:
		return
	var raw_h: Variant = Lx.vars.get_var(SCOPE_ISLAND, "dusk_hour", 1)
	dusk_hour = clampi(int(raw_h) if str(raw_h).is_valid_float() else 1, 1, HOURS_TOTAL)
	var raw_t: Variant = Lx.vars.get_var(SCOPE_ISLAND, "dusk_hour_t", 0.0)
	hour_elapsed = clampf(float(raw_t) if str(raw_t).is_valid_float() else 0.0, 0.0, HOUR_SECS)
	Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour", dusk_hour)


func _on_var_changed(scope: String, var_name: String, value: Variant) -> void:
	if scope == SCOPE_ISLAND and var_name == "dusk_hour":
		var nh: int = clampi(int(value) if str(value).is_valid_float() else dusk_hour, 1, HOURS_TOTAL)
		if nh != dusk_hour:
			dusk_hour = nh
			hour_elapsed = 0.0
			_on_hour_side_effects(dusk_hour)
			_redraw_hud()
	elif var_name == "weather" or var_name == "party_phase":
		_redraw_hud()


func on_region_loaded(region_id: String) -> void:
	current_region = region_id
	_sim_driver_id = 0
	_update_pause_state()
	_on_hour_side_effects(dusk_hour)
	_redraw_hud()


func _physics_process(delta: float) -> void:
	var f: int = Engine.get_physics_frames()
	if f == _last_phys_frame:
		return
	_last_phys_frame = f
	if Lx.root != null and Lx.root.get("flow") != null and int(Lx.root.get("flow")) != 2:
		_redraw_hud()
		return
	var dt: float = delta
	if Lx.hitstop != null and Lx.hitstop.get("game_speed") != null:
		dt *= clampf(float(Lx.hitstop.get("game_speed")), 0.25, 1.5)
	tick_rule(dt)


## Called from Island 4 toys inside synchronous step_sim(dt) test loops so headless tests tick 1x per step.
static func notify_sim_tick(dt: float, caller_id: int) -> void:
	var inst: LxIsland4Rule = active_instance
	if inst == null or not is_instance_valid(inst):
		return
	if inst._sim_driver_id == 0:
		inst._sim_driver_id = caller_id
	if inst._sim_driver_id != caller_id:
		return
	inst._last_phys_frame = Engine.get_physics_frames()
	inst.tick_rule(dt)


func tick_rule(dt: float) -> void:
	if dt <= 0.0:
		return
	var st: LxGameState = _get_state()
	if st != null and st.island_id != ISLAND_ID:
		if _hud_node != null and is_instance_valid(_hud_node):
			_hud_node.visible = false
		return
	if sweep_t > 0.0:
		sweep_t = maxf(0.0, sweep_t - dt)
	_update_pause_state()
	if not dusk_paused:
		hour_elapsed += dt
		if Lx.vars != null:
			Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour_t", snappedf(hour_elapsed, 0.05))
		if hour_elapsed >= HOUR_SECS:
			hour_elapsed -= HOUR_SECS
			if dusk_hour >= HOURS_TOTAL:
				_wrap_loop_to_hour_one()
			else:
				set_hour(dusk_hour + 1, true, false)
	_redraw_hud()


func get_hour() -> int:
	return dusk_hour


func get_hour_progress() -> float:
	return clampf(hour_elapsed / HOUR_SECS, 0.0, 1.0)


func get_hour_time_left() -> float:
	return maxf(0.0, HOUR_SECS - hour_elapsed)


func is_paused() -> bool:
	return dusk_paused


func advance_hour(manual: bool = true) -> int:
	var next_h: int = 1 if dusk_hour >= HOURS_TOTAL else (dusk_hour + 1)
	if next_h == 1 and dusk_hour == HOURS_TOTAL:
		rewind_to_hour_one(manual)
		return 1
	set_hour(next_h, true, manual)
	return dusk_hour


func rewind_to_hour_one(manual: bool = true) -> void:
	dusk_hour = 1
	hour_elapsed = 0.0
	sweep_mode = "rewind" if manual else "wrap"
	sweep_dur = REWIND_SWEEP_S if manual else WRAP_SWEEP_S
	sweep_t = sweep_dur
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour_t", 0.0)
		Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour", 1)
	_apply_region_layers_safe()
	_on_hour_side_effects(1)
	if _events != null:
		_events.sfx_requested.emit("sundial_skip", Vector2.ZERO, false)
		if manual or not LxLegacy.is_legacy_region(ISLAND_ID, current_region):
			_emit_narration("ISL4_CUE_REWIND", "narration", 2.4)
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("notify"):
		Lx.world.call("notify", "dusk_rewound", {"manual": manual, "hour": 1})
	loop_rewound.emit(manual)
	hour_changed.emit(1, manual)
	_redraw_hud()


func set_hour(new_hour: int, animate: bool = true, manual: bool = false) -> void:
	var clamped: int = clampi(new_hour, 1, HOURS_TOTAL)
	dusk_hour = clamped
	hour_elapsed = 0.0
	if animate:
		sweep_mode = "skip"
		sweep_dur = SKIP_SWEEP_S
		sweep_t = sweep_dur
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour_t", 0.0)
		Lx.vars.set_var(SCOPE_ISLAND, "dusk_hour", clamped)
	_apply_region_layers_safe()
	_on_hour_side_effects(clamped)
	if _events != null:
		if manual:
			_events.sfx_requested.emit("sundial_skip", Vector2.ZERO, false)
		if manual or not LxLegacy.is_legacy_region(ISLAND_ID, current_region):
			var cue_id: String = HOUR_CUES[clamped - 1]
			_emit_narration(cue_id, "narration", 2.0)
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("notify"):
		Lx.world.call("notify", "dusk_hour_changed", {"hour": clamped, "manual": manual})
	hour_changed.emit(clamped, manual)
	_redraw_hud()


func _wrap_loop_to_hour_one() -> void:
	# Generous Loop Law: nothing earned (keys, flags, moths, panes, embers, shards, pin-sconces) is lost.
	if Lx.vars != null and current_region.begins_with("party_"):
		var pp: String = str(Lx.vars.get_var(SCOPE_PARTY, "party_phase", "scout"))
		if pp == "heist":
			Lx.vars.set_var(SCOPE_PARTY, "party_phase", "scout")
	rewind_to_hour_one(false)


func _apply_region_layers_safe() -> void:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("apply_layers"):
		Lx.world.call("apply_layers", true)


func _on_hour_side_effects(hr: int) -> void:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return
	# Hour III (Glass Shower) douses unroofed timed braziers in overworld / party districts
	if hr == 3 and not dusk_paused:
		for it_v: Variant in (Lx.world.call("get_interactables") as Array):
			if it_v is LxTimedBrazier and is_instance_valid(it_v):
				var tb: LxTimedBrazier = it_v as LxTimedBrazier
				if tb.lit and not tb.is_reset_brazier and not bool(tb.props.get("roofed", false)):
					tb._extinguish(true)


func _update_pause_state() -> void:
	var want: bool = _compute_paused()
	if want != dusk_paused:
		dusk_paused = want
		if Lx.vars != null:
			Lx.vars.set_var(SCOPE_ISLAND, "dusk_paused", 1 if dusk_paused else 0)
		_redraw_hud()
	elif Lx.vars != null and Lx.vars.get_var(SCOPE_ISLAND, "dusk_paused", -1) is int and int(Lx.vars.get_var(SCOPE_ISLAND, "dusk_paused", -1)) == -1:
		Lx.vars.set_var(SCOPE_ISLAND, "dusk_paused", 1 if dusk_paused else 0)


func _compute_paused() -> bool:
	var st: LxGameState = _get_state()
	var reg: String = current_region if not current_region.is_empty() else (st.region_id if st != null else "")
	if reg.begins_with("conservatory_") or reg == "vault_last_hour":
		return true
	if st != null and (st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("island_4_relit", false))):
		return true
	if reg == "party_r1" and Lx.vars != null and str(Lx.vars.get_var(SCOPE_PARTY, "party_phase", "scout")) == "scout":
		return true
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		for e_v: Variant in (Lx.world.call("get_enemies") as Array):
			if e_v is LxEnemyBrain and is_instance_valid(e_v):
				var en: LxEnemyBrain = e_v as LxEnemyBrain
				if en.is_alive() and en.visible and (en.is_boss or not en.boss_id.is_empty()):
					return true
	return false


func get_effective_weather() -> String:
	if Lx.vars != null:
		var w_v: Variant = Lx.vars.resolve_var("weather", ISLAND_ID, current_region, "")
		var ws: String = str(w_v).strip_edges().to_lower()
		if ws in ["sun", "rain", "wind"]:
			if current_region.begins_with("mausoleum_") or current_region == "cave_rain_cistern" or current_region.begins_with("_proof_i4_2"):
				return ws
	if dusk_hour == 3:
		return "rain"
	if dusk_hour == 4:
		return "wind"
	return "sun"


func _redraw_hud() -> void:
	var modal_open: bool = Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open"))
	var st: LxGameState = _get_state()
	var in_play: bool = Lx.root == null or Lx.root.get("flow") == null or int(Lx.root.get("flow")) in [2, 3, 4]
	var show_hud: bool = (not modal_open) and st != null and st.island_id == ISLAND_ID and in_play
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.visible = show_hud
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.visible = show_hud
		if show_hud:
			_hud_node.queue_redraw()


func _draw_hud(ci: CanvasItem) -> void:
	var pal: Dictionary = LxPalette.PAL
	var c_void: Color = pal["void"] as Color
	var c_night: Color = pal["night"] as Color
	var c_dusk: Color = pal["dusk"] as Color
	var c_mauve: Color = pal["mauve"] as Color
	var c_gold: Color = pal["gold"] as Color
	var c_apricot: Color = pal["apricot"] as Color
	var c_cream: Color = pal["cream"] as Color
	var c_sky: Color = pal["sky"] as Color
	var c_ice: Color = pal["ice"] as Color
	var c_rose: Color = pal["rose"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	# 1. Screen-space gentle sweep overlay on skip (0.4 s) / rewind (0.6 s) / wrap (1.2 s)
	if sweep_t > 0.0 and sweep_dur > 0.01:
		var u: float = 1.0 - clampf(sweep_t / sweep_dur, 0.0, 1.0)
		var a: float = sin(u * PI) * (0.22 if fred else 0.52)
		var band_x: float = roundf(lerpf(320.0, -24.0, u) if sweep_mode == "rewind" else lerpf(-24.0, 320.0, u))
		var sweep_c: Color = c_rose if sweep_mode == "rewind" else c_gold
		ci.draw_rect(Rect2(band_x - 8.0, 0.0, 18.0, 180.0), Color(sweep_c, a * 0.45))
		ci.draw_rect(Rect2(band_x, 0.0, 2.0, 180.0), Color(c_cream, a * (0.55 if fred else 0.85)))
		if sweep_mode == "wrap" and not fred:
			for k: int in range(6):
				var px: float = roundf(band_x + float((k % 3) - 1) * 7.0)
				var py: float = roundf(22.0 + float(k) * 26.0 + sin(u * TAU + float(k)) * 5.0)
				ci.draw_rect(Rect2(px, py, 2.0, 2.0), Color(c_gold if k % 2 == 0 else c_rose, a))

	# 2. Compact 28x12 px 6-petal Dusk Sundial beneath the minimap (x=285, y=63)
	var ox: float = 285.0
	var oy: float = 63.0
	var bw: float = 28.0
	var bh: float = 12.0
	ci.draw_rect(Rect2(ox - 1.0, oy - 1.0, bw + 2.0, bh + 2.0), c_void)
	ci.draw_rect(Rect2(ox, oy, bw, bh), c_night)
	ci.draw_rect(Rect2(ox, oy, bw, 1.0), c_dusk if dusk_paused else c_mauve)

	# 6 hour petals (left 20px, 3px stride; greyscale-distinct tall active vs mid past vs flat future)
	for i: int in range(HOURS_TOTAL):
		var h_idx: int = i + 1
		var px: float = ox + 2.0 + float(i) * 3.0
		var py: float = oy + 2.0
		if h_idx == dusk_hour:
			var body_c: Color = c_mauve if dusk_paused else c_gold
			ci.draw_rect(Rect2(px, py, 2.0, 5.0), body_c)
			ci.draw_rect(Rect2(px, py, 2.0, 2.0 if not dusk_paused else 1.0), c_dusk if dusk_paused else c_cream)
		elif h_idx < dusk_hour:
			ci.draw_rect(Rect2(px, py + 1.0, 2.0, 3.0), c_dusk if dusk_paused else c_apricot)
		else:
			ci.draw_rect(Rect2(px, py + 3.0, 2.0, 1.0), c_dusk)

	# Weather / pause icon (right 6px)
	var wx: float = ox + 21.0
	var wy: float = oy + 2.0
	if dusk_paused:
		ci.draw_rect(Rect2(wx + 1.0, wy, 1.0, 4.0), c_mauve)
		ci.draw_rect(Rect2(wx + 3.0, wy, 1.0, 4.0), c_mauve)
		ci.draw_rect(Rect2(wx + 1.0, wy, 1.0, 1.0), c_cream)
		ci.draw_rect(Rect2(wx + 3.0, wy, 1.0, 1.0), c_cream)
	else:
		var wmode: String = get_effective_weather()
		if wmode == "rain":
			ci.draw_rect(Rect2(wx + 1.0, wy, 1.0, 2.0), c_sky)
			ci.draw_rect(Rect2(wx + 3.0, wy + 1.0, 1.0, 2.0), c_ice)
			ci.draw_rect(Rect2(wx + 2.0, wy + 3.0, 1.0, 2.0), c_sky)
		elif wmode == "wind":
			ci.draw_rect(Rect2(wx, wy + 1.0, 4.0, 1.0), c_ice)
			ci.draw_rect(Rect2(wx + 1.0, wy + 3.0, 4.0, 1.0), c_sky)
			ci.draw_rect(Rect2(wx + 4.0, wy, 1.0, 1.0), c_cream)
		else:
			ci.draw_rect(Rect2(wx + 2.0, wy, 1.0, 5.0), c_gold)
			ci.draw_rect(Rect2(wx, wy + 2.0, 5.0, 1.0), c_gold)
			ci.draw_rect(Rect2(wx + 2.0, wy + 2.0, 1.0, 1.0), c_cream)

	# Smooth sand-sweep progress bar along bottom (24px wide)
	var bar_w: float = 24.0
	var frac: float = get_hour_progress()
	var near_wrap: bool = (not dusk_paused) and dusk_hour == HOURS_TOTAL and frac > 0.80
	ci.draw_rect(Rect2(ox + 2.0, oy + 8.0, bar_w, 2.0), c_void)
	var fill_w: float = roundf(bar_w * frac)
	if fill_w >= 1.0:
		var bc: Color = c_mauve if dusk_paused else (c_rose if near_wrap else c_gold)
		ci.draw_rect(Rect2(ox + 2.0, oy + 8.0, fill_w, 2.0), bc)
		ci.draw_rect(Rect2(ox + 2.0, oy + 8.0, fill_w, 1.0), c_dusk if dusk_paused else c_cream)
		if not dusk_paused and fill_w >= 2.0:
			ci.draw_rect(Rect2(ox + 1.0 + fill_w, oy + 8.0, 1.0, 2.0), c_cream)
	if near_wrap:
		ci.draw_rect(Rect2(ox + 24.0, oy + 7.0, 2.0, 1.0), c_cream if fred else c_rose)


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
