class_name LxRoomScript
extends Node2D
## Runs region JSON `events` (SPEC 3.3): triggers, conditions, timed action queues,
## 0.6s telegraphed waves (>= 64px from Wick), exit lock/reopen on clear or death, and challenges.

const PAL: Dictionary = LxPalette.PAL
const TELEGRAPH_SECS: float = 0.6
const MIN_WICK_SPAWN_DIST: float = 64.0
const ChallengeScript := preload("res://luxel/world/challenge.gd")

var region: Node = null
var island_id: int = 1
var region_id: String = ""
var events: Array[Dictionary] = []
var active_challenge: Node = null

var _elapsed_s: float = 0.0
var _entered_fired: bool = false
var _fired_once: Dictionary = {}
var _timer_next: Dictionary = {}
var _prev_cond_state: Dictionary = {}
var _had_enemies: bool = false
var _had_zone_enemies: Dictionary = {}
var _zone_cleared_fired: Dictionary = {}
var _signal_cache: Dictionary = {}
var _queues: Array[Dictionary] = []
var _pending_spawns: Array[Dictionary] = []
var _locked_door_ids: Array[String] = []
var _locked_exit_ids: Dictionary = {}
var _all_exits_locked: bool = false
var _auto_unlock_on_clear: bool = false
var _connected_events: bool = false
var _local_vars: Dictionary = {}
var _pending_once_wave_ids: Array[String] = []
var _challenge_spawned: Dictionary = {} # challenge_tag -> Array[LxEnemyBrain]
var _aborted: bool = false

func setup(p_region: Node, p_events: Array, p_island_id: int = 0, p_region_id: String = "") -> void:
	cleanup()
	_aborted = false
	region = p_region
	island_id = p_island_id if p_island_id > 0 else (int(p_region.get("current_island_id")) if p_region != null else 1)
	region_id = p_region_id if not p_region_id.is_empty() else (str(p_region.get("current_region_id")) if p_region != null else "")
	events.clear()
	for i: int in range(p_events.size()):
		if p_events[i] is Dictionary:
			var ev: Dictionary = (p_events[i] as Dictionary).duplicate(true)
			if str(ev.get("id", "")).is_empty(): ev["id"] = "ev_%d" % i
			events.append(ev)
	_elapsed_s = 0.0; _entered_fired = false; _all_exits_locked = false; _auto_unlock_on_clear = false
	for d: Dictionary in [_fired_once, _timer_next, _prev_cond_state, _zone_cleared_fired, _signal_cache, _locked_exit_ids, _challenge_spawned]: d.clear()
	_queues.clear(); _pending_spawns.clear(); _locked_door_ids.clear(); _pending_once_wave_ids.clear()
	_scan_initial_enemies(); _bind_bus(); z_index = 2; queue_redraw()

func _exit_tree() -> void: cleanup()

func cleanup() -> void:
	_aborted = true
	if _connected_events and Lx.events != null:
		if Lx.events.player_died.is_connected(_on_player_died): Lx.events.player_died.disconnect(_on_player_died)
		if Lx.events.enemy_killed.is_connected(_on_enemy_killed): Lx.events.enemy_killed.disconnect(_on_enemy_killed)
	_connected_events = false
	if not _locked_door_ids.is_empty() and region != null and is_instance_valid(region) and region.has_method("find_interactable"):
		for did: String in _locked_door_ids:
			var it: LxInteractable = region.call("find_interactable", did) as LxInteractable
			if it != null and is_instance_valid(it) and it is LxDoor: (it as LxDoor).set_script_locked(false)
		_locked_door_ids.clear()
	if active_challenge != null and is_instance_valid(active_challenge):
		if active_challenge.has_method("cleanup"): active_challenge.call("cleanup")
		active_challenge.queue_free()
	active_challenge = null; _pending_spawns.clear(); _queues.clear(); _challenge_spawned.clear()

func _bind_bus() -> void:
	if _connected_events or Lx.events == null: return
	_connected_events = true
	if not Lx.events.player_died.is_connected(_on_player_died): Lx.events.player_died.connect(_on_player_died)
	if not Lx.events.enemy_killed.is_connected(_on_enemy_killed): Lx.events.enemy_killed.connect(_on_enemy_killed)

func _scan_initial_enemies() -> void:
	_had_enemies = false; _had_zone_enemies.clear()
	if region == null or not region.has_method("get_enemies"): return
	for e: Variant in (region.call("get_enemies") as Array):
		if is_instance_valid(e) and e is LxEnemyBrain and (e as LxEnemyBrain).is_alive():
			_had_enemies = true
			var z: String = (e as LxEnemyBrain).zone
			if not z.is_empty(): _had_zone_enemies[z] = true

func _region_changed() -> bool:
	if _aborted or region == null or not is_instance_valid(region): return true
	return int(region.get("current_island_id")) != island_id or str(region.get("current_region_id")) != region_id

func tick(dt: float) -> void:
	if _region_changed(): return
	_elapsed_s += dt
	if not _entered_fired:
		_entered_fired = true; _dispatch_trigger("enter", {})
		if _region_changed(): return
	_tick_pending_spawns(dt)
	if _region_changed(): return
	_tick_queues(dt)
	if _region_changed(): return
	if active_challenge != null and is_instance_valid(active_challenge) and active_challenge.has_method("tick"):
		active_challenge.call("tick", dt)
		if _region_changed(): return
	_poll_events()
	if _region_changed(): return
	_commit_pending_wave_once_flags()
	_check_wave_auto_unlock()
	if not _pending_spawns.is_empty(): queue_redraw()

func notify(event_name: String, data: Dictionary = {}) -> void:
	var ev_s: String = event_name.strip_edges()
	if ev_s.is_empty() or _region_changed(): return
	if ev_s == "player_died": _on_player_died(); return
	if ev_s.begins_with("signal:"):
		var pwr: bool = bool(data.get("powered", true))
		_signal_cache[ev_s.substr(7)] = pwr
		if pwr: _dispatch_trigger(ev_s, data)
		return
	if ev_s == "cleared":
		var z: String = str(data.get("zone", ""))
		_dispatch_trigger("cleared" if z.is_empty() else ("cleared:" + z), data)
		if not z.is_empty(): _dispatch_trigger("cleared", data)
		return
	var fired_n: int = _dispatch_trigger(ev_s, data)
	if fired_n == 0 and ev_s.begins_with("trial_start:"):
		var ch_spec: Variant = data.get("challenge", null)
		if ch_spec is Dictionary:
			_act_challenge(ch_spec, data)
		else:
			var g_v: Variant = data.get("gate", null)
			if is_instance_valid(g_v) and (g_v as Object).has_method("on_challenge_result"):
				(g_v as Object).call("on_challenge_result", false)

func is_exit_locked(exit_id: String) -> bool: return _all_exits_locked or bool(_locked_exit_ids.get(exit_id, false))
func has_pending_waves() -> bool: return not _pending_spawns.is_empty()

func run_actions(actions: Array, ctx: Dictionary = {}, once_ev_id: String = "") -> void:
	var copy: Array = []
	for a: Variant in actions:
		if a is Dictionary: copy.append((a as Dictionary).duplicate(true))
	if not copy.is_empty():
		_queues.append({"actions": copy, "idx": 0, "wait_t": 0.0, "ctx": ctx, "once_ev_id": once_ev_id})
		_tick_queues(0.0)

func eval_condition(cond: String) -> bool:
	var c: String = cond.strip_edges()
	if c.is_empty(): return true
	var ws: Object = _get_world_state()
	if ws != null and ws.has_method("eval"): return bool(ws.call("eval", c, island_id, region_id))
	return LxRegionRuntime.eval_cond_fallback(c, island_id, region_id, _local_vars, Callable(self, "_is_flag_set"))

func _dispatch_trigger(trig: String, data: Dictionary) -> int:
	var count: int = 0
	for ev: Dictionary in events:
		if _region_changed(): break
		if str(ev.get("on", "")).strip_edges() == trig:
			if _try_fire_event(ev, data): count += 1
	return count

func _poll_events() -> void:
	for ev: Dictionary in events:
		if _region_changed(): return
		var ev_id: String = str(ev.get("id", ""))
		if _is_once_consumed(ev): continue
		var on_s: String = str(ev.get("on", "")).strip_edges()
		if on_s.begins_with("timer:"):
			var secs: float = maxf(0.01, float(on_s.substr(6)))
			var nt: float = float(_timer_next.get(ev_id, secs))
			if _elapsed_s >= nt: _timer_next[ev_id] = nt + secs; _try_fire_event(ev, {"elapsed": _elapsed_s})
		elif on_s.begins_with("flag:") or on_s.begins_with("var:"):
			var ok: bool = _is_flag_set(on_s.substr(5).strip_edges()) if on_s.begins_with("flag:") else eval_condition(on_s.substr(4).strip_edges())
			if ok and not bool(_prev_cond_state.get(ev_id, false)): _prev_cond_state[ev_id] = true; _try_fire_event(ev, {})
			elif not ok: _prev_cond_state[ev_id] = false
		elif on_s == "cleared" or on_s.begins_with("cleared:"):
			var z: String = on_s.substr(8).strip_edges() if on_s.begins_with("cleared:") else ""
			var ck: String = ev_id + ":" + z
			if _is_zone_ready_cleared(z) and not bool(_zone_cleared_fired.get(ck, false)):
				_zone_cleared_fired[ck] = true; _try_fire_event(ev, {"zone": z})
		elif on_s.begins_with("boss_hp:"):
			if not bool(_prev_cond_state.get(ev_id, false)) and _any_boss_below_ratio(clampf(float(on_s.substr(8)), 0.0, 1.0)):
				_prev_cond_state[ev_id] = true; _try_fire_event(ev, {})
		elif on_s.begins_with("signal:"):
			var sid: String = on_s.substr(7).strip_edges()
			if not bool(_signal_cache.get(sid, false)) and _is_interactable_triggered(sid):
				_signal_cache[sid] = true; _try_fire_event(ev, {"signal": sid})

func _try_fire_event(ev: Dictionary, data: Dictionary) -> bool:
	if _is_once_consumed(ev): return false
	var cond: String = str(ev.get("if", "")).strip_edges()
	if not cond.is_empty() and not eval_condition(cond): return false
	var ev_id: String = str(ev.get("id", ""))
	var acts_v: Variant = ev.get("do", [])
	var acts: Array = acts_v as Array if acts_v is Array else []
	var is_once: bool = bool(ev.get("once", true))
	var has_wave: bool = _actions_have_key(acts, "wave")
	var has_wait: bool = _actions_have_key(acts, "wait")
	var deferred_once: String = ""
	if is_once:
		_fired_once[ev_id] = true
		if has_wave:
			if not _pending_once_wave_ids.has(ev_id): _pending_once_wave_ids.append(ev_id)
		elif has_wait:
			deferred_once = ev_id
		elif Lx.state != null:
			Lx.state.story_flags[_once_flag_key(ev_id)] = true
	var ctx: Dictionary = data.duplicate(false)
	ctx["ev_id"] = ev_id; ctx["on"] = str(ev.get("on", "")).strip_edges()
	if not acts.is_empty(): run_actions(acts, ctx, deferred_once)
	return true

static func _actions_have_key(acts: Array, key: String) -> bool:
	for a_v: Variant in acts:
		if a_v is Dictionary and (a_v as Dictionary).has(key): return true
	return false

func _commit_pending_wave_once_flags() -> void:
	if _pending_once_wave_ids.is_empty() or not _had_enemies or not _pending_spawns.is_empty(): return
	if region == null or not region.has_method("is_zone_cleared") or not bool(region.call("is_zone_cleared", "")): return
	if Lx.state != null:
		for eid: String in _pending_once_wave_ids:
			Lx.state.story_flags[_once_flag_key(eid)] = true
	_pending_once_wave_ids.clear()

func _once_flag_key(ev_id: String) -> String: return "rscr_%d_%s_%s" % [island_id, region_id, ev_id]

func _is_once_consumed(ev: Dictionary) -> bool:
	if not bool(ev.get("once", true)): return false
	var ev_id: String = str(ev.get("id", ""))
	return bool(_fired_once.get(ev_id, false)) or (Lx.state != null and LxRegionRuntime.flag_truthy(Lx.state.story_flags.get(_once_flag_key(ev_id), false)))

func _tick_queues(dt: float) -> void:
	var i: int = 0
	while i < _queues.size():
		if _region_changed(): return
		var q: Dictionary = _queues[i]
		var wt: float = float(q.get("wait_t", 0.0))
		if wt > 0.0:
			q["wait_t"] = maxf(0.0, wt - dt)
			if float(q["wait_t"]) > 0.0: i += 1; continue
		var actions: Array = q.get("actions", []) as Array
		var idx: int = int(q.get("idx", 0))
		var ctx: Dictionary = q.get("ctx", {}) as Dictionary
		var paused: bool = false
		while idx < actions.size():
			var wait_s: float = _execute_action(actions[idx] as Dictionary, ctx)
			if _region_changed(): return
			idx += 1
			if wait_s > 0.0: q["idx"] = idx; q["wait_t"] = wait_s; paused = true; break
		if paused: i += 1
		else:
			var done_ev: String = str(q.get("once_ev_id", ""))
			if not done_ev.is_empty() and Lx.state != null:
				Lx.state.story_flags[_once_flag_key(done_ev)] = true
			_queues.remove_at(i)

func _execute_action(act: Dictionary, ctx: Dictionary = {}) -> float:
	if act.has("wait"): return maxf(0.0, float(act["wait"]))
	if act.has("wave"): _act_wave(act["wave"])
	if act.has("lock"): _act_lock(act["lock"])
	if act.has("unlock"): _act_unlock(act["unlock"])
	if act.has("set_var"): _act_set_var(act["set_var"])
	if act.has("set_flag"): _act_set_flag(act["set_flag"])
	if act.has("narrate"): _act_narrate(act["narrate"])
	if act.has("pan"): _act_pan(act["pan"])
	if act.has("shake"):
		var mag: float = float(act["shake"])
		if Lx.events != null: Lx.events.shake_requested.emit(mag)
		elif Lx.camera != null: Lx.camera.add_shake(mag)
	if act.has("music"): _act_music(str(act["music"]))
	if act.has("sfx"): _act_sfx(act["sfx"])
	if act.has("spawn"): _act_spawn_interactable(act["spawn"])
	if act.has("remove"): _act_remove_interactable(str(act["remove"]))
	if act.has("reward"): _act_reward(act["reward"], ctx)
	if act.has("warp"): _act_warp(act["warp"])
	if act.has("challenge"): _act_challenge(act["challenge"], ctx)
	return 0.0

func spawn_wave_for_challenge(raw: Variant, tag: String) -> void:
	_act_wave(raw, tag)

func clear_challenge_spawns(tag: String) -> void:
	if tag.is_empty(): return
	for i: int in range(_pending_spawns.size() - 1, -1, -1):
		if str(_pending_spawns[i].get("challenge_tag", "")) == tag:
			_pending_spawns.remove_at(i)
	var list_v: Variant = _challenge_spawned.get(tag, null)
	if list_v is Array:
		var reg_en: Variant = region.get("_enemies") if (region != null and is_instance_valid(region)) else null
		for e_v: Variant in (list_v as Array):
			if is_instance_valid(e_v) and e_v is LxEnemyBrain:
				var br: LxEnemyBrain = e_v as LxEnemyBrain
				if br.director != null: br.director.unregister(br)
				if reg_en is Array: (reg_en as Array).erase(br)
				br.queue_free()
	_challenge_spawned.erase(tag)
	queue_redraw()

func _act_wave(raw: Variant, challenge_tag: String = "") -> void:
	var specs: Array = raw as Array if raw is Array else ([raw] if raw is Dictionary else [])
	if specs.is_empty(): return
	var wick_pos: Vector2 = _get_wick_pos()
	for sp_v: Variant in specs:
		if not (sp_v is Dictionary): continue
		var spec: Dictionary = (sp_v as Dictionary).duplicate(true)
		var safe_pos: Vector2 = _find_safe_wave_pos(LxMapFormat.to_vec2(spec.get("pos", _region_center()), _region_center()), wick_pos)
		spec["pos"] = [safe_pos.x, safe_pos.y]; spec["home"] = [safe_pos.x, safe_pos.y]
		_pending_spawns.append({"spec": spec, "pos": safe_pos, "timer": TELEGRAPH_SECS, "dur": TELEGRAPH_SECS, "challenge_tag": challenge_tag})
		_had_enemies = true
		var z: String = str(spec.get("zone", ""))
		if not z.is_empty(): _had_zone_enemies[z] = true; _zone_cleared_fired.erase(z)
	if _all_exits_locked or not _locked_door_ids.is_empty() or not _locked_exit_ids.is_empty(): _auto_unlock_on_clear = true
	if Lx.events != null: Lx.events.sfx_requested.emit("enemy_alert", wick_pos, false)
	queue_redraw()

func _find_safe_wave_pos(want: Vector2, wick_pos: Vector2) -> Vector2:
	if _is_valid_spawn_point(want, wick_pos): return want
	for base_p: Vector2 in [want, wick_pos]:
		for r: float in [72.0, 88.0, 108.0, 128.0, 152.0]:
			for step: int in range(12):
				var cand: Vector2 = base_p + Vector2.from_angle(float(step) * (TAU / 12.0)) * r
				if _is_valid_spawn_point(cand, wick_pos): return cand
	var best: Vector2 = want; var best_d: float = -1.0
	var w: int = int(region.get("width")) if region != null else 0
	var h: int = int(region.get("height")) if region != null else 0
	var ts: float = float(region.get("tile_size")) if region != null else 16.0
	for ty: int in range(1, maxi(1, h - 1)):
		for tx: int in range(1, maxi(1, w - 1)):
			var pt := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
			if _is_walkable_tile(pt) and pt.distance_to(wick_pos) > best_d: best_d = pt.distance_to(wick_pos); best = pt
	return best

func _is_valid_spawn_point(p: Vector2, wick_pos: Vector2) -> bool:
	if wick_pos.x > -9000.0 and p.distance_to(wick_pos) < MIN_WICK_SPAWN_DIST: return false
	if region != null:
		var b: Rect2 = region.get("bounds") as Rect2
		if b.has_area() and not b.grow(-10.0).has_point(p): return false
	return _is_walkable_tile(p)

func _is_walkable_tile(p: Vector2) -> bool:
	if region == null or not region.has_method("tile_at"): return true
	var tt: String = str(region.call("tile_at", p))
	if region.has_method("is_solid_tile") and bool(region.call("is_solid_tile", tt, false, false)): return false
	return not (region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", p)))

func _tick_pending_spawns(dt: float) -> void:
	if _pending_spawns.is_empty(): return
	var cur_wick: Vector2 = _get_wick_pos()
	for i: int in range(_pending_spawns.size() - 1, -1, -1):
		_pending_spawns[i]["timer"] = float(_pending_spawns[i]["timer"]) - dt
		if float(_pending_spawns[i]["timer"]) <= 0.0:
			var sp_pos: Vector2 = _pending_spawns[i]["pos"] as Vector2
			if cur_wick.x > -9000.0 and sp_pos.distance_to(cur_wick) < MIN_WICK_SPAWN_DIST:
				sp_pos = _find_safe_wave_pos(sp_pos, cur_wick)
			var spec: Dictionary = (_pending_spawns[i]["spec"] as Dictionary).duplicate(true)
			spec["pos"] = [sp_pos.x, sp_pos.y]; spec["home"] = [sp_pos.x, sp_pos.y]
			var brain: LxEnemyBrain = _spawn_enemy_compat(spec)
			if brain != null and is_instance_valid(brain):
				brain.pos = sp_pos; brain.position = sp_pos.round()
				var ctag: String = str(_pending_spawns[i].get("challenge_tag", ""))
				if not ctag.is_empty():
					var arr: Array = _challenge_spawned.get(ctag, []) as Array
					arr.append(brain); _challenge_spawned[ctag] = arr
			_pending_spawns.remove_at(i)
	if _pending_spawns.is_empty(): queue_redraw()

func _spawn_enemy_compat(spec: Dictionary) -> LxEnemyBrain:
	if region == null: return null
	if region.has_method("spawn_enemy"):
		var res: Variant = region.call("spawn_enemy", spec)
		return res as LxEnemyBrain if res is LxEnemyBrain else null
	var s: Dictionary = spec.duplicate(true); s["island_id"] = island_id
	var brain: LxEnemyBrain = LxEnemyFactory.create(str(s.get("kind", "warden")), s, region.get("_director") as LxAttackDirector, region)
	if brain == null: return null
	var eroot: Node = region.get("_enemies_root") as Node
	(eroot if eroot != null else region).add_child(brain)
	brain.position = brain.pos.round()
	var arr: Variant = region.get("_enemies")
	if arr is Array: (arr as Array).append(brain)
	return brain

func _act_lock(raw: Variant) -> void:
	if raw is bool:
		if bool(raw): _lock_all_exits()
		return
	var ids: Array = raw as Array if raw is Array else [raw]
	if ids.is_empty() or (ids.size() == 1 and str(ids[0]) in ["all", ""]):
		_lock_all_exits()
	else:
		for id_v: Variant in ids:
			var tid: String = str(id_v).strip_edges()
			if tid == "all": _lock_all_exits(); continue
			var it: LxInteractable = region.call("find_interactable", tid) as LxInteractable if (not tid.is_empty() and region.has_method("find_interactable")) else null
			if it != null and it is LxDoor:
				(it as LxDoor).set_script_locked(true)
				if not _locked_door_ids.has(tid): _locked_door_ids.append(tid)
			elif not tid.is_empty():
				_locked_exit_ids[tid] = true; _set_exit_flag_lock(tid, true)
	if _has_alive_or_pending_enemies(): _auto_unlock_on_clear = true
	if Lx.events != null: Lx.events.sfx_requested.emit("door_locked", _get_wick_pos(), false)

func _act_unlock(raw: Variant) -> void:
	if raw is bool or (raw is String and str(raw) in ["all", ""]): _unlock_all_script_locks(); return
	var ids: Array = raw as Array if raw is Array else [raw]
	if ids.is_empty(): _unlock_all_script_locks(); return
	for id_v: Variant in ids:
		var tid: String = str(id_v).strip_edges()
		if tid == "all": _unlock_all_script_locks(); return
		var it: LxInteractable = region.call("find_interactable", tid) as LxInteractable if region.has_method("find_interactable") else null
		if it != null and it is LxDoor:
			if _locked_door_ids.has(tid):
				(it as LxDoor).set_script_locked(false)
				_locked_door_ids.erase(tid)
			elif not (it as LxDoor).opened:
				(it as LxDoor).call("_open", false)
		else: _locked_exit_ids.erase(tid); _set_exit_flag_lock(tid, false)

func _lock_all_exits() -> void:
	_all_exits_locked = true
	if region != null and region.has_method("lock_exits"): region.call("lock_exits", true); return
	var exs: Variant = region.get("exits")
	if exs is Array:
		for ex_v: Variant in (exs as Array):
			if ex_v is Dictionary and not str((ex_v as Dictionary).get("id", "")).is_empty():
				var eid: String = str((ex_v as Dictionary).get("id", ""))
				_locked_exit_ids[eid] = true; _set_exit_flag_lock(eid, true)

func _unlock_all_script_locks() -> void:
	var any_u: bool = _all_exits_locked or not _locked_door_ids.is_empty() or not _locked_exit_ids.is_empty()
	_all_exits_locked = false; _auto_unlock_on_clear = false
	if region != null and region.has_method("lock_exits"): region.call("lock_exits", false)
	for eid: Variant in _locked_exit_ids.keys(): _set_exit_flag_lock(str(eid), false)
	_locked_exit_ids.clear()
	for did: String in _locked_door_ids:
		var it: LxInteractable = region.call("find_interactable", did) as LxInteractable if (region != null and region.has_method("find_interactable")) else null
		if it != null and it is LxDoor: (it as LxDoor).set_script_locked(false)
	_locked_door_ids.clear()
	if any_u and Lx.events != null: Lx.events.sfx_requested.emit("door_open", _get_wick_pos(), false)

func _set_exit_flag_lock(exit_id: String, locked: bool) -> void:
	var exs: Variant = region.get("exits") if region != null else null
	if not (exs is Array): return
	var lf: String = "__rscr_lock_%s_%s" % [region_id, exit_id]
	for ex_v: Variant in (exs as Array):
		if ex_v is Dictionary and str((ex_v as Dictionary).get("id", "")) == exit_id:
			var ex: Dictionary = ex_v as Dictionary
			var req: Array = ex.get("requires_flags", []) as Array if ex.get("requires_flags") is Array else []
			if locked and not req.has(lf): req.append(lf); ex["requires_flags"] = req
			elif not locked and req.has(lf): req.erase(lf); ex["requires_flags"] = req

func _act_set_var(raw: Variant) -> void:
	if not (raw is Dictionary): return
	var d: Dictionary = raw as Dictionary
	var sc: String = str(d.get("scope", "island:%d" % island_id))
	var vn: String = str(d.get("name", d.get("var", "")))
	if vn.is_empty():
		for k: Variant in d.keys():
			if str(k) != "scope": _write_world_var(sc, str(k), d[k])
	else: _write_world_var(sc, vn, d.get("value", true))
	if region != null and region.has_method("apply_layers"): region.call("apply_layers")

func _write_world_var(scope: String, vname: String, val: Variant) -> void:
	_local_vars[vname] = val
	var ws: Object = _get_world_state()
	if ws != null and ws.has_method("set_var"): ws.call("set_var", scope, vname, val)
	elif Lx.state != null: Lx.state.story_flags["wvar:%s:%s" % [scope, vname]] = val

func _act_set_flag(raw: Variant) -> void:
	if Lx.state == null: return
	if raw is String and not str(raw).strip_edges().is_empty(): Lx.state.story_flags[str(raw).strip_edges()] = true
	elif raw is Dictionary:
		var fid: String = str((raw as Dictionary).get("id", (raw as Dictionary).get("flag", ""))).strip_edges()
		if not fid.is_empty(): Lx.state.story_flags[fid] = bool((raw as Dictionary).get("value", true))

func _act_narrate(raw: Variant) -> void:
	if Lx.events == null: return
	if raw is String and not str(raw).strip_edges().is_empty(): Lx.events.narration_requested.emit(str(raw).strip_edges(), "narration", 3.5)
	elif raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		var sid: String = str(d.get("id", d.get("string_id", ""))).strip_edges()
		if not sid.is_empty(): Lx.events.narration_requested.emit(sid, str(d.get("style", "narration")), float(d.get("duration", 3.5)))

func _act_pan(raw: Variant) -> void:
	if Lx.camera == null: return
	if raw is Array and (raw as Array).size() >= 2:
		var a: Array = raw as Array
		Lx.camera.trigger_focus_nudge(Vector2(float(a[0]), float(a[1])), float(a[2]) if a.size() >= 3 else 0.8)
	elif raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		Lx.camera.trigger_focus_nudge(LxMapFormat.to_vec2(d.get("pos", [160.0, 90.0])), float(d.get("secs", d.get("duration", 0.8))))

func _act_music(cue: String) -> void:
	if Lx.audio == null or cue.is_empty(): return
	if cue in ["explore", "combat", "dungeon", "boss_p1", "boss_p2"]: Lx.audio.set_music_mode(cue, true)
	else: Lx.audio.play_cue(cue)

func _act_sfx(raw: Variant) -> void:
	if Lx.events == null: return
	if raw is String: Lx.events.sfx_requested.emit(str(raw), _get_wick_pos(), false)
	elif raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		Lx.events.sfx_requested.emit(str(d.get("id", "")), LxMapFormat.to_vec2(d.get("pos", Vector2.ZERO)), d.has("pos"))

func _act_spawn_interactable(raw: Variant) -> void:
	if raw is Dictionary and region != null and region.has_method("spawn_interactable"):
		region.call("spawn_interactable", (raw as Dictionary).duplicate(true))

func _act_remove_interactable(tid: String) -> void:
	if not tid.is_empty() and region != null and region.has_method("remove_interactable"):
		region.call("remove_interactable", tid)

func _act_reward(raw: Variant, ctx: Dictionary = {}) -> void:
	LxRegionRuntime.apply_script_reward(raw, island_id, region_id, _get_wick_pos(), Callable(self, "_act_spawn_interactable"), str(ctx.get("ev_id", "")))

func _act_warp(raw: Variant) -> void:
	if not (raw is Dictionary): return
	var d: Dictionary = raw as Dictionary
	var to_reg: String = str(d.get("region", d.get("to_region", "")))
	var pos: Vector2 = LxMapFormat.to_vec2(d.get("pos", d.get("to_spawn", [-1.0, -1.0])), Vector2(-1.0, -1.0))
	if not to_reg.is_empty() and Lx.root != null and Lx.root.has_method("load_island_region"):
		Lx.root.call("load_island_region", int(d.get("island", d.get("to_island", island_id))), to_reg, pos)
	elif pos.x >= 0.0 and Lx.player is Node2D: (Lx.player as Node2D).global_position = pos

func _act_challenge(raw: Variant, ctx: Dictionary = {}) -> void:
	if not (raw is Dictionary): return
	if active_challenge != null and is_instance_valid(active_challenge): active_challenge.call("cleanup"); active_challenge.queue_free()
	var gate: Object = null
	var g_v: Variant = ctx.get("gate", null)
	if is_instance_valid(g_v) and g_v is Object: gate = g_v as Object
	elif str(ctx.get("on", "")).begins_with("trial_start:") and region != null and region.has_method("find_interactable"):
		gate = region.call("find_interactable", str(ctx.get("on", "")).substr(12)) as Object
	var ch: Node = ChallengeScript.new(); ch.name = "LxChallenge"; add_child(ch)
	ch.call("setup", self, region, (raw as Dictionary).duplicate(true), gate)
	active_challenge = ch

func _on_player_died() -> void:
	_pending_spawns.clear(); _unlock_all_script_locks()
	if active_challenge != null and is_instance_valid(active_challenge) and active_challenge.has_method("on_player_died"):
		active_challenge.call("on_player_died")

func _on_enemy_killed(_e: Object, _k: String, _p: Vector2, _o: bool) -> void: _check_wave_auto_unlock()
func _check_wave_auto_unlock() -> void:
	if _auto_unlock_on_clear and not _has_alive_or_pending_enemies(): _unlock_all_script_locks()
func _has_alive_or_pending_enemies() -> bool:
	return (not _pending_spawns.is_empty()) or (region != null and region.has_method("is_zone_cleared") and not bool(region.call("is_zone_cleared", "")))

func _is_zone_ready_cleared(zone: String) -> bool:
	if not _pending_spawns.is_empty(): return false
	if not (_had_enemies if zone.is_empty() else bool(_had_zone_enemies.get(zone, false))): return false
	return region != null and region.has_method("is_zone_cleared") and bool(region.call("is_zone_cleared", zone))

func _any_boss_below_ratio(thresh: float) -> bool:
	if region == null or not region.has_method("get_enemies"): return false
	for e_v: Variant in (region.call("get_enemies") as Array):
		if is_instance_valid(e_v) and e_v is LxEnemyBrain:
			var e: LxEnemyBrain = e_v as LxEnemyBrain
			if e.is_alive() and (e.is_boss or not e.boss_id.is_empty()) and e.max_hp > 0.0 and (e.hp / e.max_hp) <= thresh: return true
	return false

func _is_interactable_triggered(sid: String) -> bool:
	var it: LxInteractable = region.call("find_interactable", sid) as LxInteractable if (region != null and region.has_method("find_interactable")) else null
	return it != null and (it.get("activated") == true or it.get("lit") == true or it.get("powered") == true or it.get("opened") == true)

func _is_flag_set(flag: String) -> bool:
	if region != null and region.has_method("is_flag_set"): return bool(region.call("is_flag_set", flag))
	return Lx.state != null and LxRegionRuntime.flag_truthy(Lx.state.story_flags.get(flag, false))

func _get_world_state() -> Object:
	return Lx.vars if (Lx.vars != null and is_instance_valid(Lx.vars)) else null

func _get_wick_pos() -> Vector2:
	if region != null and region.has_method("get_wick_pos"): return region.call("get_wick_pos") as Vector2
	return (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else _region_center()

func _region_center() -> Vector2:
	return (region.get("bounds") as Rect2).get_center() if (region != null and region.get("bounds") is Rect2) else Vector2(160.0, 90.0)

func _draw() -> void:
	if _pending_spawns.is_empty(): return
	var fr: bool = LxHudFx.flash_reduced()
	for item: Dictionary in _pending_spawns:
		var p: Vector2 = (item["pos"] as Vector2).round()
		var frac: float = clampf(1.0 - float(item["timer"]) / maxf(0.01, float(item["dur"])), 0.0, 1.0)
		var r_out: float = roundf(lerpf(18.0, 6.0, frac))
		var col_ring: Color = (PAL["coral"] if (not fr and int(floorf(frac * 10.0)) % 2 == 0) else PAL["gold"]) as Color
		draw_arc(p, r_out, 0.0, TAU, 20, col_ring, 1.5)
		draw_arc(p, maxf(2.0, r_out - 4.0), 0.0, TAU, 16, PAL["cream"] as Color, 1.0)
		draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), PAL["cream"] as Color)
