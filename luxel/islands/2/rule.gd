class_name LxIsland2Rule
extends RefCounted
## Island 2 (Tidewater Harbor) Rule Engine:
## - Manages Lx.vars tides (ebb/half/flood), tower_tide (low/mid/high), galleon list (port/starboard),
##   locks lock_water (west_high/east_high), and lighthouse relays (relay_f1..f3).
## - Drives Ballast Clamp (thrown lantern pins sliding crates/mirrors/kegs/rafts) and
##   Sluice Harpoon (lantern recall tows floating rafts, kegs, and buoy mines).
## - Renders a compact pixel-art Tide Gauge HUD (CanvasLayer) below hearts without disturbing legacy checks.
## - Restores Skiff mount carryover across water region exits.

const ISLAND_ID: int = 2
const TIDE_VALUES: Array[String] = ["ebb", "half", "flood"]
const TOWER_TIDE_VALUES: Array[String] = ["low", "mid", "high"]
const LIST_VALUES: Array[String] = ["port", "starboard"]
const LOCK_VALUES: Array[String] = ["west_high", "east_high"]

const TIDE_STRINGS: Dictionary = {
	"ebb": "ISL2_TIDE_EBB",
	"half": "ISL2_TIDE_HALF",
	"flood": "ISL2_TIDE_FLOOD",
}
const CLAMP_CATCH_RADIUS: float = 20.0
const HARPOON_CATCH_RADIUS: float = 34.0

var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _attached: bool = false
var _region_id: String = ""

var _driver_node: Node2D = null
var _hud_layer: CanvasLayer = null
var _hud_node: Node2D = null

var _clamped_target: LxInteractable = null
var _clamped_pos: Vector2 = Vector2.ZERO
var _clamp_ring_t: float = 0.0
var _harpoon_streaks: Array[Dictionary] = [] # {from, to, age, life}
var _transition_flash_t: float = 0.0


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
	_attached = true
	_seed_default_vars()
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)
	if _events != null:
		if not _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.connect(_on_region_entered)
		if not _events.lantern_recalled.is_connected(_on_lantern_recalled):
			_events.lantern_recalled.connect(_on_lantern_recalled)
		if not _events.lantern_caught.is_connected(_on_lantern_caught):
			_events.lantern_caught.connect(_on_lantern_caught)
	_ensure_runtime_nodes()


func detach() -> void:
	_release_clamp()
	if _vars != null and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
	if _events != null:
		if _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.disconnect(_on_region_entered)
		if _events.lantern_recalled.is_connected(_on_lantern_recalled):
			_events.lantern_recalled.disconnect(_on_lantern_recalled)
		if _events.lantern_caught.is_connected(_on_lantern_caught):
			_events.lantern_caught.disconnect(_on_lantern_caught)
	_free_runtime_nodes()
	_harpoon_streaks.clear()
	_attached = false


func _seed_default_vars() -> void:
	if _vars == null:
		return
	var st_vars: Dictionary = _vars.to_dict()
	if not (st_vars.has("island:2") and (st_vars["island:2"] as Dictionary).has("tide")):
		_vars.set_var("island:2", "tide", "ebb")
	if not (st_vars.has("dungeon:lighthouse") and (st_vars["dungeon:lighthouse"] as Dictionary).has("tower_tide")):
		_vars.set_var("dungeon:lighthouse", "tower_tide", "low")
	if not (st_vars.has("dungeon:galleon") and (st_vars["dungeon:galleon"] as Dictionary).has("list")):
		_vars.set_var("dungeon:galleon", "list", "port")
	if not (st_vars.has("dungeon:locks") and (st_vars["dungeon:locks"] as Dictionary).has("lock_water")):
		_vars.set_var("dungeon:locks", "lock_water", "west_high")


func get_tide() -> String:
	if _vars == null:
		return "ebb"
	var v: String = str(_vars.get_var("island:2", "tide", "ebb")).strip_edges().to_lower()
	return v if v in TIDE_VALUES else "ebb"


func set_tide(level: String) -> void:
	var lv: String = level.strip_edges().to_lower()
	if lv not in TIDE_VALUES or _vars == null:
		return
	_vars.set_var("island:2", "tide", lv)


func cycle_tide() -> String:
	var idx: int = TIDE_VALUES.find(get_tide())
	var nxt: String = TIDE_VALUES[(idx + 1) % TIDE_VALUES.size()]
	set_tide(nxt)
	return nxt


func get_tower_tide() -> String:
	if _vars == null:
		return "low"
	var v: String = str(_vars.get_var("dungeon:lighthouse", "tower_tide", "low")).strip_edges().to_lower()
	return v if v in TOWER_TIDE_VALUES else "low"


func set_tower_tide(level: String) -> void:
	var lv: String = level.strip_edges().to_lower()
	if lv not in TOWER_TIDE_VALUES or _vars == null:
		return
	_vars.set_var("dungeon:lighthouse", "tower_tide", lv)


func is_ballast_clamp_unlocked() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("power_ballast_clamp", false))


func is_sluice_harpoon_unlocked() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("power_sluice_harpoon", false))


func get_clamped_target() -> LxInteractable:
	return _clamped_target if (_clamped_target != null and is_instance_valid(_clamped_target)) else null


func on_region_loaded(region_id: String) -> void:
	_region_id = region_id
	_release_clamp()
	_ensure_runtime_nodes()
	# Restore Skiff mount carryover across water region exits
	if Lx.world is LxRegionLoader and Lx.player is LxWick and Lx.state != null:
		LxVehicleSkiff.restore_mount_carryover(Lx.world as LxRegionLoader, Lx.player as LxWick, Lx.state.spawn_pos)
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	_region_id = region_id
	_release_clamp()
	_ensure_runtime_nodes()
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_var_changed(scope: String, var_name: String, value: Variant) -> void:
	var st: LxGameState = _state if _state != null else Lx.state
	if st != null and st.island_id != ISLAND_ID:
		return
	var val_s: String = str(value).strip_edges().to_lower()
	_transition_flash_t = 0.65
	if scope == "island:2" and var_name == "tide":
		if st != null:
			st.story_flags["tide_organ_used"] = true
		_on_tide_shifted(val_s)
	elif scope == "dungeon:lighthouse" and var_name == "tower_tide":
		if _events != null:
			_events.sfx_requested.emit("clockwork_chime", Vector2.ZERO, false)
			_events.sfx_requested.emit("tide_surge", Vector2.ZERO, false)
			_events.shake_requested.emit(0.10)
	elif scope == "dungeon:galleon" and var_name == "list":
		if _events != null:
			_events.sfx_requested.emit("harbor_creak", Vector2.ZERO, false)
			_events.shake_requested.emit(0.08)
	elif scope == "dungeon:locks" and var_name == "lock_water":
		if _events != null:
			_events.sfx_requested.emit("tide_surge", Vector2.ZERO, false)
			_events.shake_requested.emit(0.09)
	elif scope == "dungeon:lighthouse" and var_name.begins_with("relay_f") and (val_s == "1" or val_s == "true"):
		if _events != null and LxStrings.has_id("LH2_RELAY_ON"):
			_events.narration_requested.emit("LH2_RELAY_ON", "ice", 3.0)
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _on_tide_shifted(level: String) -> void:
	if _events != null:
		_events.sfx_requested.emit("lighthouse_toll", Vector2.ZERO, false)
		_events.sfx_requested.emit("tide_surge", Vector2.ZERO, false)
		_events.shake_requested.emit(0.11)
		var sid: String = str(TIDE_STRINGS.get(level, ""))
		if not sid.is_empty() and LxStrings.has_id(sid):
			if not LxLegacy.is_legacy_region(ISLAND_ID, _region_id) or _region_has_tide_organ():
				_events.narration_requested.emit(sid, "ice" if level == "flood" else "narration", 2.6)
	if Lx.world != null and is_instance_valid(Lx.world):
		var wfx: Variant = Lx.world.get("_water_fx")
		if wfx is Object and is_instance_valid(wfx) and (wfx as Object).has_method("spawn_ripple"):
			var p: Vector2 = Lx.player.global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(160.0, 90.0)
			(wfx as Object).call("spawn_ripple", p, "ice", 22.0)


func _on_lantern_recalled(from_pos: Vector2) -> void:
	_release_clamp()
	var st: LxGameState = _state if _state != null else Lx.state
	if st != null and st.island_id != ISLAND_ID:
		return
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var wick: LxWick = Lx.player as LxWick
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	var unlocked: bool = is_sluice_harpoon_unlocked()
	var pull_dir: Vector2 = (wick.global_position - from_pos).normalized() if wick.global_position.distance_to(from_pos) > 2.0 else -wick.facing
	var pulled_any: bool = false

	# 1. Tow floating tide_rafts & ballast_kegs within harpoon radius
	if Lx.world.has_method("get_interactables"):
		for it_v: Variant in Lx.world.call("get_interactables") as Array:
			if not (it_v is LxInteractable) or not is_instance_valid(it_v as Object):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active or it.kind not in ["tide_raft", "ballast_keg"]:
				continue
			if not unlocked and not bool(it.props.get("allow_harpoon_always", false)):
				continue
			if it.pos.distance_to(from_pos) <= HARPOON_CATCH_RADIUS + it.radius * 0.6:
				if it.has_method("on_lantern_pull"):
					it.call("on_lantern_pull", pull_dir, "recall")
					_harpoon_streaks.append({"from": it.pos, "to": wick.global_position, "age": 0.0, "life": 0.28})
					pulled_any = true
	# 2. Tow buoy_mine enemies within harpoon radius (locks_r8)
	if unlocked and Lx.world.has_method("get_enemies"):
		for e_v: Variant in Lx.world.call("get_enemies") as Array:
			if not (e_v is LxEnemyBrain) or not is_instance_valid(e_v):
				continue
			var en: LxEnemyBrain = e_v as LxEnemyBrain
			if not en.is_alive() or en.kind != "buoy_mine":
				continue
			if en.pos.distance_to(from_pos) <= HARPOON_CATCH_RADIUS + en.body_radius:
				if en.has_method("on_harpoon_tow"):
					en.call("on_harpoon_tow", pull_dir, wick.global_position)
				else:
					en.vel = pull_dir * 145.0
				_harpoon_streaks.append({"from": en.pos, "to": wick.global_position, "age": 0.0, "life": 0.28})
				pulled_any = true
	if pulled_any and _events != null:
		_events.sfx_requested.emit("harbor_creak", from_pos, true)


func _on_lantern_caught(_at_pos: Vector2) -> void:
	_release_clamp()


func tick_rule(dt: float) -> void:
	if not _attached:
		return
	if _transition_flash_t > 0.0:
		_transition_flash_t = maxf(0.0, _transition_flash_t - dt)
	if _clamp_ring_t > 0.0:
		_clamp_ring_t = maxf(0.0, _clamp_ring_t - dt)
	for i: int in range(_harpoon_streaks.size() - 1, -1, -1):
		_harpoon_streaks[i]["age"] = float(_harpoon_streaks[i]["age"]) + dt
		if float(_harpoon_streaks[i]["age"]) >= float(_harpoon_streaks[i]["life"]):
			_harpoon_streaks.remove_at(i)

	_tick_ballast_clamp()
	if _driver_node != null and is_instance_valid(_driver_node):
		_driver_node.queue_redraw()
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.visible = _should_show_hud()
		if _hud_node.visible:
			_hud_node.queue_redraw()


func _tick_ballast_clamp() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		_release_clamp()
		return
	var wick: LxWick = Lx.player as LxWick
	var lan: LxLantern = wick.lantern
	if lan == null or not is_instance_valid(lan):
		_release_clamp()
		return
	if lan.state != LxLantern.State.FLYING and lan.state != LxLantern.State.HANGING:
		_release_clamp()
		return

	if _clamped_target != null:
		if not is_instance_valid(_clamped_target) or not _clamped_target.active:
			_release_clamp()
			return
		# Keep lantern pinned on the clamped target with sustained hang timer until recalled/caught
		lan.state = LxLantern.State.HANGING
		lan.pos = _clamped_pos
		lan.prev_pos = _clamped_pos
		lan.global_position = _clamped_pos.round()
		lan.vel = Vector2.ZERO
		lan.hang_timer = lan.hang_max
		# Hold shared push_block / mirror targets immobile against tilt_group / conveyors
		if _clamped_target.kind in ["push_block", "blue_transformer", "mirror"]:
			if _clamped_target.has_method("move_to"):
				_clamped_target.call("move_to", _clamped_pos)
			else:
				_clamped_target.pos = _clamped_pos
				_clamped_target.position = _clamped_pos.round()
			if _clamped_target.get("slide_vel") is Vector2:
				_clamped_target.set("slide_vel", Vector2.ZERO)
			if _clamped_target.get("_ext_vel") is Vector2:
				_clamped_target.set("_ext_vel", Vector2.ZERO)
		return

	# Scan for a clampable object under the thrown/hanging lantern
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return
	var unlocked: bool = is_ballast_clamp_unlocked()
	var best: LxInteractable = null
	var best_d: float = INF
	for it_v: Variant in Lx.world.call("get_interactables") as Array:
		if not (it_v is LxInteractable) or not is_instance_valid(it_v as Object):
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not it.active:
			continue
		if it.kind not in ["tide_raft", "ballast_keg", "push_block", "blue_transformer", "mirror"]:
			continue
		if not unlocked and not bool(it.props.get("allow_clamp_always", false)):
			continue
		if it.kind == "ballast_keg" and str(it.get("state")) in ["detonating", "respawning"]:
			continue
		var reach: float = CLAMP_CATCH_RADIUS + it.radius * 0.5
		var d: float = it.pos.distance_to(lan.pos)
		if d <= reach and d < best_d:
			best_d = d
			best = it
	if best != null:
		_engage_clamp(best, lan)


func _engage_clamp(target: LxInteractable, lan: LxLantern) -> void:
	_clamped_target = target
	_clamped_pos = target.pos
	_clamp_ring_t = 0.36
	lan.state = LxLantern.State.HANGING
	lan.pos = _clamped_pos
	lan.prev_pos = _clamped_pos
	lan.global_position = _clamped_pos.round()
	lan.vel = Vector2.ZERO
	lan.hang_timer = lan.hang_max
	if target.has_method("on_ballast_clamp"):
		target.call("on_ballast_clamp", true, _clamped_pos)
	elif _events != null:
		_events.sfx_requested.emit("anchor_slam", _clamped_pos, true)


func _release_clamp() -> void:
	if _clamped_target != null and is_instance_valid(_clamped_target):
		if _clamped_target.has_method("on_ballast_clamp"):
			_clamped_target.call("on_ballast_clamp", false, _clamped_pos)
	_clamped_target = null
	_clamped_pos = Vector2.ZERO


func _should_show_hud() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	if st == null or st.island_id != ISLAND_ID:
		return false
	if Lx.root != null and is_instance_valid(Lx.root) and Lx.root.get("flow") != null:
		if int(Lx.root.get("flow")) != 2: # LxMain.Flow.PLAY
			return false
	if LxLegacy.is_legacy_region(ISLAND_ID, _region_id):
		if not bool(st.story_flags.get("tide_organ_used", false)) and not _region_has_tide_organ():
			return false
	return true


func _region_has_tide_organ() -> bool:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return false
	for it_v: Variant in Lx.world.call("get_interactables") as Array:
		if it_v is LxInteractable and is_instance_valid(it_v as Object):
			var k: String = (it_v as LxInteractable).kind
			if k in ["state_lever", "tide_raft", "mooring_post", "optic_well", "ballast_keg", "vehicle_skiff"]:
				return true
	return false


func _ensure_runtime_nodes() -> void:
	var host: Node = Lx.world if (Lx.world != null and is_instance_valid(Lx.world)) else Lx.root
	if host == null or not is_instance_valid(host):
		return
	if _driver_node == null or not is_instance_valid(_driver_node):
		_driver_node = _RuleDriverNode.new()
		_driver_node.name = "Island2RuleFx"
		_driver_node.z_index = 4
		_driver_node.set("rule", self)
		host.add_child(_driver_node)
	var hud_host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else host
	if _hud_layer == null or not is_instance_valid(_hud_layer):
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "Island2TideHudLayer"
		_hud_layer.layer = 9
		hud_host.add_child(_hud_layer)
		_hud_node = _TideHudNode.new()
		_hud_node.name = "TideGauge"
		_hud_node.set("rule", self)
		_hud_layer.add_child(_hud_node)


func _free_runtime_nodes() -> void:
	if _driver_node != null and is_instance_valid(_driver_node):
		_driver_node.queue_free()
	_driver_node = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_node = null


func _draw_world_fx(ci: CanvasItem) -> void:
	var c_gold: Color = LxPalette.PAL["gold"] as Color
	var c_cream: Color = LxPalette.PAL["cream"] as Color
	var c_ice: Color = LxPalette.PAL["ice"] as Color
	if _clamped_target != null and is_instance_valid(_clamped_target):
		var cp: Vector2 = _clamped_pos.round()
		ci.draw_arc(cp, 12.0, 0.0, TAU, 16, c_gold, 1.0)
		if _clamp_ring_t > 0.0:
			var u: float = 1.0 - clampf(_clamp_ring_t / 0.36, 0.0, 1.0)
			ci.draw_arc(cp, roundf(lerpf(6.0, 20.0, u)), 0.0, TAU, 16, c_cream, 1.2)
	for hs: Dictionary in _harpoon_streaks:
		var u: float = clampf(float(hs["age"]) / maxf(0.01, float(hs["life"])), 0.0, 1.0)
		var a: Vector2 = (hs["from"] as Vector2).round()
		var b: Vector2 = (hs["to"] as Vector2).round()
		ci.draw_line(a, b, Color(c_ice, (1.0 - u) * 0.9), 1.5)
		ci.draw_line(a, b, Color(c_cream, (1.0 - u)), 1.0)


func _draw_tide_hud(ci: CanvasItem) -> void:
	var origin := Vector2(5.0, 22.0)
	var pal: Dictionary = LxPalette.PAL
	var c_void: Color = pal["void"] as Color
	var c_night: Color = pal["night"] as Color
	var c_sky: Color = pal["sky"] as Color
	var c_ice: Color = pal["ice"] as Color
	var c_gold: Color = pal["gold"] as Color
	var c_cream: Color = pal["cream"] as Color

	var label_id: String = "HUD_I2_EBB"
	var bars_lit: int = 1
	var bars_max: int = 3
	if _region_id.begins_with("lighthouse_"):
		var tt: String = get_tower_tide()
		bars_lit = 1 if tt == "low" else (2 if tt == "mid" else 3)
		label_id = "HUD_I2_TLOW" if tt == "low" else ("HUD_I2_TMID" if tt == "mid" else "HUD_I2_THIGH")
	elif _region_id.begins_with("galleon_"):
		var lv: String = str(_vars.get_var("dungeon:galleon", "list", "port")) if _vars != null else "port"
		bars_max = 2
		bars_lit = 1 if lv == "port" else 2
		label_id = "HUD_I2_PORT" if lv == "port" else "HUD_I2_STBD"
	elif _region_id.begins_with("locks_"):
		var lw: String = str(_vars.get_var("dungeon:locks", "lock_water", "west_high")) if _vars != null else "west_high"
		bars_max = 2
		bars_lit = 1 if lw == "west_high" else 2
		label_id = "HUD_I2_LWEST" if lw == "west_high" else "HUD_I2_LEAST"
	else:
		var td: String = get_tide()
		bars_lit = 1 if td == "ebb" else (2 if td == "half" else 3)
		label_id = "HUD_I2_EBB" if td == "ebb" else ("HUD_I2_HALF" if td == "half" else "HUD_I2_FLOOD")

	var box_w: float = 54.0
	var box_h: float = 12.0
	var rim_c: Color = c_cream if _transition_flash_t > 0.25 else c_gold
	ci.draw_rect(Rect2(origin, Vector2(box_w, box_h)), c_void)
	ci.draw_rect(Rect2(origin + Vector2.ONE, Vector2(box_w - 2.0, box_h - 2.0)), c_night)
	ci.draw_rect(Rect2(origin + Vector2.ONE, Vector2(box_w - 2.0, 1.0)), rim_c)
	# Stepped tide-level bars (greyscale-distinct count & height)
	for i: int in range(bars_max):
		var bh: float = float((i + 1) * 2 + 1)
		var bx: float = origin.x + 3.0 + float(i * 4)
		var by: float = origin.y + box_h - 2.0 - bh
		var on: bool = i < bars_lit
		ci.draw_rect(Rect2(bx, by, 3.0, bh), c_ice if on else pal["deep"] as Color)
		if on:
			ci.draw_rect(Rect2(bx, by, 3.0, 1.0), c_cream)
	var label_txt: String = LxStrings.text(label_id) if LxStrings.has_id(label_id) else "EBB"
	LxPixelFont.draw(ci, label_txt, origin + Vector2(18.0, 4.0), 1, c_cream if _transition_flash_t > 0.0 else c_sky)

	# Power badges (Ballast Clamp anchor pip + Sluice Harpoon hook pip)
	var px: float = origin.x + box_w + 2.0
	if is_ballast_clamp_unlocked():
		ci.draw_rect(Rect2(px, origin.y + 1.0, 10.0, 10.0), c_void)
		ci.draw_rect(Rect2(px + 1.0, origin.y + 2.0, 8.0, 8.0), c_gold if _clamped_target != null else pal["dusk"] as Color)
		ci.draw_rect(Rect2(px + 4.0, origin.y + 3.0, 2.0, 6.0), c_cream)
		ci.draw_rect(Rect2(px + 2.0, origin.y + 7.0, 6.0, 2.0), c_cream)
		px += 12.0
	if is_sluice_harpoon_unlocked():
		ci.draw_rect(Rect2(px, origin.y + 1.0, 10.0, 10.0), c_void)
		ci.draw_rect(Rect2(px + 1.0, origin.y + 2.0, 8.0, 8.0), pal["blue"] as Color)
		ci.draw_line(Vector2(px + 2.0, origin.y + 8.0), Vector2(px + 8.0, origin.y + 3.0), c_cream, 1.0)
		ci.draw_rect(Rect2(px + 6.0, origin.y + 3.0, 2.0, 2.0), c_ice)


class _RuleDriverNode extends Node2D:
	var rule: LxIsland2Rule = null

	func _physics_process(delta: float) -> void:
		if rule != null:
			rule.tick_rule(delta)

	func _draw() -> void:
		if rule != null:
			rule._draw_world_fx(self)


class _TideHudNode extends Node2D:
	var rule: LxIsland2Rule = null

	func _draw() -> void:
		if rule != null:
			rule._draw_tide_hud(self)
