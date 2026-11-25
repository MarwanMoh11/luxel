class_name LxIsland1Rule
extends RefCounted
## Island 1 (Bell Isle) Rule Engine:
## - Ring waves (Dawn/Dusk/War): universal Dusk 2.0 s motion freeze on toys/enemies, War crack shatter, Dawn relight.
## - Town Bell Evening / Midnight state (`island:1/bell_hour`), 1.2 s visual shift, ghost-stone shimmer, patrol & Grave Hand hooks.
## - Echo Clapper (`item_echo_clapper`) tracking & HUD indicator.
## - Shutter Hood (`item_shutter_hood`) stealth: `light_scale = 0.18` when lantern is out, cone visibility API,
##   alert state (`calm` | `lured` | `spotted`), and Dash slip-through on `shadow_gate`.
## Visual overlay & HUD badge live in `luxel/islands/1/rule_fx.gd` (`LxIsland1RuleFx`).
## Never disturbs legacy Island 1 tutorial flow (`tutorial_island_check`).

const ISLAND_ID: int = 1
const SCOPE_ISLAND: String = "island:1"
const VAR_BELL_HOUR: String = "bell_hour"
const HOUR_EVENING: String = "evening"
const HOUR_MIDNIGHT: String = "midnight"

const FLAG_ECHO_CLAPPER: String = "item_echo_clapper"
const FLAG_SHUTTER_HOOD: String = "item_shutter_hood"
const SHUTTER_LIGHT_SCALE: float = 0.18
const DUSK_FREEZE_S: float = 2.0
const HOUR_TRANSITION_S: float = 1.2
const CLOSE_HEAR_RADIUS: float = 34.0

const RuleFxScript := preload("res://luxel/islands/1/rule_fx.gd")

static var active_instance: LxIsland1Rule = null

var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _region: LxRegionLoader = null
var _attached: bool = false
var _region_id: String = ""

var _fx: LxIsland1RuleFx = null
var _applied_hood_scale: bool = false

# Frozen motion toys & enemies: instance_id -> {obj, kind, left, max_t, orig_speed, orig_target}
var _frozen: Dictionary = {}
var _slipped_gates: Dictionary = {}

# Town Bell transition & Stealth alert runtime
var transition_t: float = 0.0
var transition_to_midnight: bool = false
var stealth_alert: String = "calm" # "calm" | "lured" | "spotted"
var stealth_alert_pos: Vector2 = Vector2.ZERO
var _alert_decay_t: float = 0.0
var _alert_sfx_cd: float = 0.0
var last_ring_tone: String = ""
var last_ring_echo: bool = false
var ring_events_count: int = 0


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
	_attached = true
	active_instance = self
	if _events != null:
		for sig: StringName in [&"lantern_thrown", &"lantern_hung", &"lantern_caught", &"lantern_recalled", &"lantern_dropped", &"lantern_stolen"]:
			if not _events.is_connected(sig, _on_lantern_state_changed):
				_events.connect(sig, _on_lantern_state_changed)
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)


func detach() -> void:
	_restore_all_frozen()
	_slipped_gates.clear()
	_restore_hood_light_scale()
	_unmount_nodes()
	_disconnect_region()
	if _events != null and is_instance_valid(_events):
		for sig: StringName in [&"lantern_thrown", &"lantern_hung", &"lantern_caught", &"lantern_recalled", &"lantern_dropped", &"lantern_stolen"]:
			if _events.is_connected(sig, _on_lantern_state_changed):
				_events.disconnect(sig, _on_lantern_state_changed)
	if _vars != null and is_instance_valid(_vars) and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
	if active_instance == self:
		active_instance = null
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_restore_all_frozen()
	_slipped_gates.clear()
	_disconnect_region()
	_region_id = region_id
	stealth_alert = "calm"
	_alert_decay_t = 0.0
	transition_t = 0.0
	if _vars == null and Lx.vars != null:
		_vars = Lx.vars
		if not _vars.var_changed.is_connected(_on_var_changed):
			_vars.var_changed.connect(_on_var_changed)
	if Lx.world is LxRegionLoader and is_instance_valid(Lx.world):
		_region = Lx.world as LxRegionLoader
		if not _region.room_notified.is_connected(_on_room_notified):
			_region.room_notified.connect(_on_room_notified)
		_mount_nodes(_region)
	_sync_hour_entities(get_bell_hour(), true)
	sync_shutter_hood()


# ---- Public State & Power Queries ----

func get_bell_hour() -> String:
	var vs: LxWorldState = _vars if _vars != null else Lx.vars
	var v: Variant = vs.get_var(SCOPE_ISLAND, VAR_BELL_HOUR, HOUR_EVENING) if vs != null else LxToyDraw.world_get_var(SCOPE_ISLAND, VAR_BELL_HOUR, HOUR_EVENING)
	var s: String = str(v).strip_edges().to_lower()
	return HOUR_MIDNIGHT if s == HOUR_MIDNIGHT else HOUR_EVENING


func is_midnight() -> bool:
	return get_bell_hour() == HOUR_MIDNIGHT


func set_bell_hour(hour: String, silent: bool = false) -> void:
	var h: String = HOUR_MIDNIGHT if hour.strip_edges().to_lower() == HOUR_MIDNIGHT else HOUR_EVENING
	var prev: String = get_bell_hour()
	var vs: LxWorldState = _vars if _vars != null else Lx.vars
	if vs != null:
		vs.set_var(SCOPE_ISLAND, VAR_BELL_HOUR, h)
	else:
		LxToyDraw.world_set_var(SCOPE_ISLAND, VAR_BELL_HOUR, h)
	if prev == h:
		_sync_hour_entities(h, silent)
		return
	if vs == null or _vars == null:
		_apply_bell_hour_transition(h, silent)


func toggle_bell_hour(silent: bool = false) -> String:
	var nxt: String = HOUR_EVENING if is_midnight() else HOUR_MIDNIGHT
	set_bell_hour(nxt, silent)
	return nxt


func has_echo_clapper() -> bool:
	var st: LxGameState = _get_state()
	return st != null and bool(st.story_flags.get(FLAG_ECHO_CLAPPER, false))


func has_shutter_hood() -> bool:
	var st: LxGameState = _get_state()
	return st != null and bool(st.story_flags.get(FLAG_SHUTTER_HOOD, false))


func is_wick_cloaked() -> bool:
	if not has_shutter_hood():
		return false
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return false
	var w: LxWick = Lx.player as LxWick
	return w.has_lantern() and w.lantern != null and w.lantern.is_out()


func sync_shutter_hood() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if is_wick_cloaked():
		if not is_equal_approx(w.light_scale, SHUTTER_LIGHT_SCALE):
			w.set_light_scale(SHUTTER_LIGHT_SCALE)
			if not _applied_hood_scale and _events != null:
				_events.sfx_requested.emit("shadow_whisper", w.global_position, false)
		_applied_hood_scale = true
	elif _applied_hood_scale:
		w.set_light_scale(1.0)
		_applied_hood_scale = false


func _restore_hood_light_scale() -> void:
	if _applied_hood_scale and Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).set_light_scale(1.0)
	_applied_hood_scale = false


## Canonical Manor stealth & lamp-cone query used by wall-shifting portraits, Lamp Butlers, and tests.
## Returns {seen: bool, target: "none"|"lantern"|"wick", pos: Vector2, alert: "calm"|"lured"|"spotted"}.
func can_cone_see_light(
	origin: Vector2,
	dir: Vector2,
	half_angle_rad: float,
	max_range: float,
	region: Node = null,
	ignore_obj: Object = null
) -> Dictionary:
	var reg: Node = region if region != null else _region
	var fdir: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	var cos_lim: float = cos(clampf(half_angle_rad, 0.05, PI))
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	if w == null or w.dead:
		return {"seen": false, "target": "none", "pos": Vector2.ZERO, "alert": "calm"}

	# 1. Thrown / hanging lantern lures cones & shifts portrait walls
	if w.has_lantern() and w.lantern != null and w.lantern.is_out():
		var lpos: Vector2 = w.lantern.pos
		if _point_in_cone(origin, fdir, cos_lim, max_range, lpos, reg, ignore_obj):
			return {"seen": true, "target": "lantern", "pos": lpos, "alert": "lured"}

	# 2. Active lantern_hook pools inside the cone lure cones & shift portrait walls
	if reg != null and reg.has_method("get_interactables"):
		for it_v: Variant in (reg.call("get_interactables") as Array):
			if it_v is LxInteractable and is_instance_valid(it_v):
				var it: LxInteractable = it_v as LxInteractable
				if it.active and it.kind == "lantern_hook" and (it.get("hooked") == true):
					if _point_in_cone(origin, fdir, cos_lim, max_range, it.pos, reg, ignore_obj):
						return {"seen": true, "target": "lantern", "pos": it.pos, "alert": "lured"}

	# 3. Wick directly: invisible and silent while cloaked by Shutter Hood!
	if is_wick_cloaked():
		return {"seen": false, "target": "none", "pos": Vector2.ZERO, "alert": "calm"}
	var wpos: Vector2 = w.global_position
	var in_cone: bool = _point_in_cone(origin, fdir, cos_lim, max_range, wpos, reg, ignore_obj)
	var heard_close: bool = wpos.distance_to(origin) <= CLOSE_HEAR_RADIUS and _has_clear_sight(reg, origin, wpos, ignore_obj)
	if in_cone or heard_close:
		return {"seen": true, "target": "wick", "pos": wpos, "alert": "spotted"}
	return {"seen": false, "target": "none", "pos": Vector2.ZERO, "alert": "calm"}


func report_stealth_alert(level: String, at_pos: Vector2) -> void:
	var lv: String = level.strip_edges().to_lower()
	if lv not in ["lured", "spotted"]:
		return
	var rank_new: int = 2 if lv == "spotted" else 1
	var rank_cur: int = 2 if stealth_alert == "spotted" else (1 if stealth_alert == "lured" else 0)
	if rank_new >= rank_cur:
		if lv == "spotted" and stealth_alert != "spotted" and _alert_sfx_cd <= 0.0 and _events != null:
			_events.sfx_requested.emit("warden_alert", at_pos, true)
			_alert_sfx_cd = 0.85
		stealth_alert = lv
		stealth_alert_pos = at_pos
		_alert_decay_t = 1.8 if lv == "spotted" else 1.2


func is_frozen(obj: Object) -> bool:
	return obj != null and _frozen.has(obj.get_instance_id())


func freeze_remaining(obj: Object) -> float:
	if obj == null:
		return 0.0
	var ent: Variant = _frozen.get(obj.get_instance_id(), null)
	return float((ent as Dictionary).get("left", 0.0)) if ent is Dictionary else 0.0


func freeze_motion_toy(obj: Object, secs: float = DUSK_FREEZE_S) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	var oid: int = obj.get_instance_id()
	if _frozen.has(oid):
		var cur: Dictionary = _frozen[oid] as Dictionary
		cur["left"] = maxf(float(cur["left"]), secs)
		cur["max_t"] = maxf(float(cur["max_t"]), secs)
		return true
	var k: String = str(obj.get("kind")) if obj.get("kind") != null else ""
	if k in ["spinner", "conveyor", "moving_platform", "mover_wall"]:
		var orig_spd: float = float(obj.get("speed"))
		obj.set("speed", 0.0)
		_frozen[oid] = {"obj": obj, "kind": k, "left": secs, "max_t": secs, "orig_speed": orig_spd}
		return true
	if k == "rotor":
		var orig_c: float = float(obj.get("continuous_speed"))
		var orig_t: float = float(obj.get("target_angle"))
		obj.set("continuous_speed", 0.0)
		obj.set("target_angle", float(obj.get("angle")))
		_frozen[oid] = {"obj": obj, "kind": k, "left": secs, "max_t": secs, "orig_speed": orig_c, "orig_target": orig_t}
		return true
	if k == "turret_eye":
		obj.set("_stun_t", maxf(float(obj.get("_stun_t")), secs))
		_frozen[oid] = {"obj": obj, "kind": k, "left": secs, "max_t": secs, "orig_speed": 0.0}
		return true
	if obj is LxEnemyBrain:
		var eb: LxEnemyBrain = obj as LxEnemyBrain
		var orig_r: float = eb.routine_speed
		eb.routine_speed = 0.0
		eb.cooldown = maxf(eb.cooldown, secs)
		if eb.state in [LxEnemyBrain.State.TELL, LxEnemyBrain.State.POSITION, LxEnemyBrain.State.NOTICE]:
			eb.state = LxEnemyBrain.State.STAGGER
			eb.state_timer = maxf(eb.state_timer, secs)
		_frozen[oid] = {"obj": eb, "kind": "enemy", "left": secs, "max_t": secs, "orig_speed": orig_r}
		return true
	return false


# ---- Simulation Tick ----

func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	sync_shutter_hood()
	if transition_t > 0.0:
		transition_t = maxf(0.0, transition_t - dt)
	if _alert_sfx_cd > 0.0:
		_alert_sfx_cd = maxf(0.0, _alert_sfx_cd - dt)
	if _alert_decay_t > 0.0:
		_alert_decay_t = maxf(0.0, _alert_decay_t - dt)
		if _alert_decay_t <= 0.0:
			stealth_alert = "calm"
	_tick_frozen(dt)
	_tick_shutter_dash_slip(dt)
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_redraw()
		_fx.sync_hud_visible()


func _tick_frozen(dt: float) -> void:
	if _frozen.is_empty():
		return
	var done_ids: Array[int] = []
	for oid_v: Variant in _frozen.keys():
		var oid: int = int(oid_v)
		var ent: Dictionary = _frozen[oid] as Dictionary
		var obj: Object = ent["obj"] as Object
		if obj == null or not is_instance_valid(obj):
			done_ids.append(oid)
			continue
		ent["left"] = float(ent["left"]) - dt
		if str(ent["kind"]) == "rotor":
			obj.set("target_angle", float(obj.get("angle")))
		if float(ent["left"]) <= 0.0:
			_restore_frozen_entry(ent)
			done_ids.append(oid)
	for oid: int in done_ids:
		_frozen.erase(oid)


func _restore_frozen_entry(ent: Dictionary) -> void:
	var obj: Object = ent.get("obj", null) as Object
	if obj == null or not is_instance_valid(obj):
		return
	var k: String = str(ent.get("kind", ""))
	if k in ["spinner", "conveyor", "moving_platform", "mover_wall"]:
		obj.set("speed", float(ent.get("orig_speed", 0.0)))
	elif k == "rotor":
		obj.set("continuous_speed", float(ent.get("orig_speed", 0.0)))
		obj.set("target_angle", float(ent.get("orig_target", obj.get("angle"))))
	elif k == "enemy" and obj is LxEnemyBrain:
		(obj as LxEnemyBrain).routine_speed = float(ent.get("orig_speed", 36.0))


func _restore_all_frozen() -> void:
	for ent_v: Variant in _frozen.values():
		if ent_v is Dictionary:
			_restore_frozen_entry(ent_v as Dictionary)
	_frozen.clear()


func _tick_shutter_dash_slip(dt: float) -> void:
	if is_wick_cloaked() and _region != null and Lx.player is LxWick:
		var w: LxWick = Lx.player as LxWick
		if w.is_dashing():
			for it: LxInteractable in _region.get_interactables():
				if it != null and it.active and it.kind == "shadow_gate" and it.is_solid():
					if it.pos.distance_to(w.global_position) <= maxf(24.0, it.radius + 10.0):
						it.set("opened", true)
						it.z_index = -4
						_slipped_gates[it.get_instance_id()] = {"gate": it, "left": 0.35}
						if _events != null:
							_events.sfx_requested.emit("phantom_phase", it.pos, true)
	if not _slipped_gates.is_empty():
		var erase_g: Array[int] = []
		for gid_v: Variant in _slipped_gates.keys():
			var ent: Dictionary = _slipped_gates[gid_v] as Dictionary
			ent["left"] = float(ent["left"]) - dt
			if float(ent["left"]) <= 0.0:
				erase_g.append(int(gid_v))
		for gid: int in erase_g:
			_slipped_gates.erase(gid)


# ---- Event Handlers ----

func _on_lantern_state_changed(_a: Variant = null, _b: Variant = null) -> void:
	sync_shutter_hood()


func _on_var_changed(scope: String, var_name: String, value: Variant) -> void:
	if scope == SCOPE_ISLAND and var_name == VAR_BELL_HOUR:
		var h: String = HOUR_MIDNIGHT if str(value).strip_edges().to_lower() == HOUR_MIDNIGHT else HOUR_EVENING
		_apply_bell_hour_transition(h, false)


func _apply_bell_hour_transition(hour: String, silent: bool) -> void:
	var is_mid: bool = hour == HOUR_MIDNIGHT
	var st: LxGameState = _get_state()
	if st != null:
		st.story_flags["town_bell_midnight"] = is_mid
		st.story_flags["town_bell_evening"] = not is_mid
	if not silent:
		transition_t = HOUR_TRANSITION_S
		transition_to_midnight = is_mid
		if _events != null:
			var sfx_id: String = _pick_sfx("bell_dusk_ring" if is_mid else "bell_dawn_ring", "bell_toll_heavy" if is_mid else "bell_toll")
			_events.sfx_requested.emit(sfx_id, Vector2.ZERO, false)
			_events.shake_requested.emit(0.18 if not LxHudFx.flash_reduced() else 0.08)
			var nar_id: String = "ISL1_HOUR_MID" if is_mid else "ISL1_HOUR_EVE"
			if LxStrings.has_id(nar_id):
				_events.narration_requested.emit(nar_id, "narration", 3.2)
	_sync_hour_entities(hour, silent)


func _sync_hour_entities(hour: String, silent: bool) -> void:
	if _region == null or not is_instance_valid(_region):
		return
	if not silent:
		_region.apply_layers(true)
	for it: LxInteractable in _region.get_interactables():
		if it != null and is_instance_valid(it) and it.has_method("on_bell_hour_changed"):
			it.call("on_bell_hour_changed", hour)
	for e: LxEnemyBrain in _region.get_enemies():
		if e != null and is_instance_valid(e) and e.has_method("on_bell_hour_changed"):
			e.call("on_bell_hour_changed", hour)
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_redraw()
		_fx.sync_hud_visible()


func _on_room_notified(event: String, data: Dictionary) -> void:
	if event == "bell_rung":
		last_ring_tone = str(data.get("tone", ""))
		last_ring_echo = bool(data.get("echo", false))
		ring_events_count += 1
		return
	if event != "ring_touch":
		return
	var target: Object = data.get("target", null) as Object
	if target == null or not is_instance_valid(target):
		return
	var tone: String = str(data.get("tone", "")).strip_edges().to_lower()
	var handled: bool = bool(data.get("handled", false))
	var dir: Vector2 = data.get("dir", Vector2.RIGHT) as Vector2
	var origin: Vector2 = data.get("origin", Vector2.ZERO) as Vector2
	var tkind: String = str(target.get("kind")) if target.get("kind") != null else ""

	if tone == "dusk":
		if not handled and tkind in ["spinner", "rotor", "conveyor", "moving_platform", "mover_wall", "turret_eye"]:
			freeze_motion_toy(target, 2.5 if tkind == "turret_eye" else DUSK_FREEZE_S)
		elif tkind in ["brazier", "timed_brazier"] and target is LxInteractable:
			var it_b: LxInteractable = target as LxInteractable
			if bool(it_b.props.get("dusk_douse", false)) and bool(it_b.get("lit")):
				if it_b.has_method("_extinguish"):
					it_b.call("_extinguish", true)
				else:
					it_b.set("lit", false)
					it_b.queue_redraw()
		elif not handled and target is LxEnemyBrain:
			freeze_motion_toy(target, DUSK_FREEZE_S)
	elif tone == "war":
		if tkind == "cracked_wall" and target is LxInteractable:
			var cw: LxInteractable = target as LxInteractable
			if not bool(cw.get("broken")) and bool(cw.props.get("war_breakable", true)):
				cw.on_hit(LxHit.make(LxHit.SOURCE_BEAM, 2.0, dir, origin))
		elif not handled and target is LxEnemyBrain:
			var eb: LxEnemyBrain = target as LxEnemyBrain
			if eb.state == LxEnemyBrain.State.ROUTINE:
				eb.state = LxEnemyBrain.State.NOTICE
				eb.alert_t = maxf(eb.alert_t, 0.35)
			var sh: Variant = eb.get("shield_hp")
			if sh is float and float(sh) > 0.0:
				eb.set("shield_hp", maxf(0.0, float(sh) - 1.0))
	elif tone == "dawn":
		if tkind in ["brazier", "timed_brazier"] and target is LxInteractable:
			var it_d: LxInteractable = target as LxInteractable
			if not bool(it_d.get("lit")) and bool(it_d.props.get("dawn_relight", false)):
				it_d.on_hit(LxHit.make(LxHit.SOURCE_BEAM, 1.0, dir, origin))


# ---- Helpers & Mounting ----

func _point_in_cone(origin: Vector2, fdir: Vector2, cos_lim: float, max_r: float, pt: Vector2, reg: Node, ignore_obj: Object = null) -> bool:
	var rel: Vector2 = pt - origin
	var d: float = rel.length()
	if d > max_r:
		return false
	if d > 2.0 and (rel / d).dot(fdir) < cos_lim:
		return false
	return _has_clear_sight(reg, origin, pt, ignore_obj)


func _has_clear_sight(reg: Node, a: Vector2, b: Vector2, ignore_obj: Object = null) -> bool:
	var start: Vector2 = a
	if ignore_obj != null and ignore_obj is LxInteractable and is_instance_valid(ignore_obj):
		var sr: Rect2 = (ignore_obj as LxInteractable).get_solid_rect()
		if sr.size.length_squared() > 0.0:
			var pad_rect: Rect2 = sr.grow(1.5)
			var delta: Vector2 = b - a
			var dist: float = delta.length()
			if dist > 0.5 and pad_rect.has_point(start):
				var step_dir: Vector2 = delta / dist
				var adv: float = 0.0
				var max_adv: float = minf(dist, maxf(pad_rect.size.x, pad_rect.size.y) + 4.0)
				while adv < max_adv and pad_rect.has_point(a + step_dir * adv):
					adv += 2.0
				start = a + step_dir * adv
	if reg != null and reg.has_method("clear_view"):
		return bool(reg.call("clear_view", start, b))
	return true


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state


func _disconnect_region() -> void:
	if _region != null and is_instance_valid(_region) and _region.room_notified.is_connected(_on_room_notified):
		_region.room_notified.disconnect(_on_room_notified)
	_region = null


func _mount_nodes(region: LxRegionLoader) -> void:
	_unmount_nodes()
	_fx = RuleFxScript.new() as LxIsland1RuleFx
	_fx.name = "Island1RuleOverlay"
	_fx.rule = self
	region.add_child(_fx)


func _unmount_nodes() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null


func should_show_hud_badge() -> bool:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID or not st.has_lantern():
		return false
	if Lx.root != null and int(Lx.root.get("flow")) != LxMain.Flow.PLAY:
		return false
	if not LxLegacy.is_legacy_region(ISLAND_ID, _region_id):
		return true
	return is_midnight() or has_echo_clapper() or has_shutter_hood()
