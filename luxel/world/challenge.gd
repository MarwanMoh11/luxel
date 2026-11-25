class_name LxChallenge
extends Node2D
## Room challenge runner (SPEC 3.3): survive, clear, no_hit, light_all, escort, race.
## Draws its own strict Last Light pixel timer HUD CanvasLayer until E0-1 exposes HUD hooks.

const PAL: Dictionary = LxPalette.PAL
const AUTO_RETRY_DELAY: float = 0.45

enum State { IDLE, RUNNING, WON, FAILED }

var state: int = State.IDLE
var challenge_id: String = ""
var kind: String = "survive"
var time_limit: float = 30.0
var elapsed_s: float = 0.0
var instant_retry: bool = true
var auto_retry: bool = false

var _owner_script: Node = null
var _region: Node = null
var _gate: Object = null
var _spec: Dictionary = {}
var _ok_actions: Array = []
var _fail_actions: Array = []
var _reward_spec: Dictionary = {}

var _start_wick_pos: Vector2 = Vector2.ZERO
var _start_hearts: float = 4.0
var _start_hits: int = 0
var _took_hit: bool = false
var _retry_t: float = 0.0
var _result_flash_t: float = 0.0

var _target_ids: Array[String] = []
var _checkpoints: Array[Vector2] = []
var _next_cp: int = 0
var _goal_pos: Vector2 = Vector2.ZERO
var _goal_radius: float = 20.0

var _escort_pos: Vector2 = Vector2.ZERO
var _escort_path: Array[Vector2] = []
var _escort_idx: int = 0
var _escort_speed: float = 36.0
var _escort_light_radius: float = 72.0
var _escort_hp: float = 3.0
var _escort_max_hp: float = 3.0

var _wave_schedule: Array[Dictionary] = []
var _hud_layer: CanvasLayer = null
var _hud_draw: _LxChallengeHudDraw = null
var _using_core_hud: bool = false
var _bus_bound: bool = false


class _LxChallengeHudDraw extends Node2D:
	var ch: LxChallenge = null

	func _draw() -> void:
		if ch != null and is_instance_valid(ch):
			ch._draw_hud_overlay(self)


func setup(p_script: Node, p_region: Node, p_spec: Dictionary, p_gate: Object = null) -> void:
	cleanup()
	_owner_script = p_script
	_region = p_region
	_gate = p_gate if (p_gate != null and is_instance_valid(p_gate)) else null
	_spec = p_spec.duplicate(true)
	challenge_id = str(_spec.get("id", "%s_%s" % [str(_spec.get("kind", "ch")), str(p_region.get("current_region_id")) if p_region != null else "r"]))
	kind = str(_spec.get("kind", "survive")).strip_edges().to_lower()
	time_limit = maxf(0.0, float(_spec.get("time", 30.0)))
	instant_retry = bool(_spec.get("instant_retry", true))
	auto_retry = bool(_spec.get("auto_retry", false))
	_ok_actions = _spec.get("ok", []) as Array if _spec.get("ok") is Array else []
	_fail_actions = _spec.get("fail", []) as Array if _spec.get("fail") is Array else []
	_reward_spec = _spec.get("reward", {}) as Dictionary if _spec.get("reward") is Dictionary else {}
	_goal_radius = maxf(8.0, float(_spec.get("goal_radius", 20.0)))
	_escort_speed = maxf(8.0, float(_spec.get("speed", 36.0)))
	_escort_light_radius = maxf(24.0, float(_spec.get("light_radius", 72.0)))
	_escort_max_hp = maxf(1.0, float(_spec.get("escort_hp", 3.0)))
	z_index = 2
	_bind_bus()
	_start_attempt()


func _exit_tree() -> void:
	cleanup()


func cleanup() -> void:
	if _bus_bound and Lx.events != null:
		if Lx.events.player_damaged.is_connected(_on_player_damaged):
			Lx.events.player_damaged.disconnect(_on_player_damaged)
	_bus_bound = false
	_hide_hud()


func _bind_bus() -> void:
	if _bus_bound or Lx.events == null:
		return
	_bus_bound = true
	if not Lx.events.player_damaged.is_connected(_on_player_damaged):
		Lx.events.player_damaged.connect(_on_player_damaged)


func _start_attempt() -> void:
	state = State.RUNNING
	elapsed_s = 0.0
	_took_hit = false
	_retry_t = 0.0
	_result_flash_t = 0.0
	_start_wick_pos = _get_wick_pos()
	if _spec.has("start_pos"):
		_start_wick_pos = LxMapFormat.to_vec2(_spec["start_pos"], _start_wick_pos)
	_start_hearts = Lx.state.hearts if Lx.state != null else 4.0
	_start_hits = Lx.state.hits_taken if Lx.state != null else 0
	_init_kind_state()
	_init_waves()
	_ensure_hud()
	queue_redraw()


func _init_kind_state() -> void:
	_target_ids.clear()
	_checkpoints.clear()
	_next_cp = 0
	_escort_path.clear()
	_escort_idx = 0
	_escort_hp = _escort_max_hp

	if kind == "light_all":
		var raw_t: Variant = _spec.get("targets", [])
		if raw_t is Array and not (raw_t as Array).is_empty():
			for v: Variant in (raw_t as Array):
				_target_ids.append(str(v))
		elif _region != null and _region.has_method("get_interactables"):
			for it_v: Variant in (_region.call("get_interactables") as Array):
				if it_v is LxInteractable:
					var it: LxInteractable = it_v as LxInteractable
					if it.active and it.kind in ["brazier", "timed_brazier", "road_lamp", "beacon"]:
						_target_ids.append(it.id)
	elif kind == "race":
		var raw_cp: Variant = _spec.get("checkpoints", [])
		if raw_cp is Array:
			for v: Variant in (raw_cp as Array):
				_checkpoints.append(LxMapFormat.to_vec2(v))
		_goal_pos = LxMapFormat.to_vec2(_spec.get("goal", _region_center()), _region_center())
		_checkpoints.append(_goal_pos)
	elif kind == "escort":
		var raw_p: Variant = _spec.get("path", [])
		if raw_p is Array:
			for v: Variant in (raw_p as Array):
				_escort_path.append(LxMapFormat.to_vec2(v))
		if _escort_path.is_empty():
			_escort_path.append(_start_wick_pos + Vector2(16.0, 0.0))
			_escort_path.append(LxMapFormat.to_vec2(_spec.get("goal", _region_center()), _region_center()))
		_escort_pos = _escort_path[0]
		_goal_pos = LxMapFormat.to_vec2(_spec.get("goal", _escort_path[_escort_path.size() - 1]), _escort_path[_escort_path.size() - 1])
		_escort_idx = 1 if _escort_path.size() > 1 else 0


func _init_waves() -> void:
	_wave_schedule.clear()
	var raw_w: Variant = _spec.get("waves", [])
	if raw_w is Array:
		for item: Variant in (raw_w as Array):
			if item is Dictionary:
				var wd: Dictionary = (item as Dictionary).duplicate(true)
				wd["_sent"] = false
				_wave_schedule.append(wd)


func retry() -> void:
	if _region != null and Lx.player is Node2D and is_instance_valid(Lx.player):
		if Lx.player.has_method("reset_for_room"):
			Lx.player.call("reset_for_room", _start_wick_pos)
		else:
			(Lx.player as Node2D).global_position = _start_wick_pos
	if Lx.state != null and bool(_spec.get("restore_hearts", true)):
		Lx.state.hearts = maxf(Lx.state.hearts, _start_hearts)
	_reset_light_targets()
	_start_attempt()


func cancel() -> void:
	var was_running: bool = state == State.RUNNING
	state = State.IDLE
	_despawn_challenge_enemies()
	if was_running:
		_notify_gate(false)
	_hide_hud()
	queue_redraw()


func on_player_died() -> void:
	if state == State.RUNNING:
		_fail_challenge("death")


func _on_player_damaged(amount: float, _from: Vector2, _dir: Vector2, _src: String) -> void:
	if state == State.RUNNING and amount > 0.0:
		_took_hit = true
		if kind == "no_hit":
			_fail_challenge("hit")


func tick(dt: float) -> void:
	if state == State.WON or state == State.FAILED:
		_result_flash_t = maxf(0.0, _result_flash_t - dt)
		if state == State.FAILED and instant_retry and auto_retry:
			_retry_t -= dt
			if _retry_t <= 0.0:
				retry()
				return
		if _result_flash_t <= 0.0 and not (state == State.FAILED and auto_retry):
			_hide_hud()
		_update_hud()
		return
	if state != State.RUNNING:
		return

	elapsed_s += dt
	_tick_wave_schedule()
	if Lx.state != null and Lx.state.hits_taken > _start_hits:
		_took_hit = true
		if kind == "no_hit":
			_fail_challenge("hit")
			return

	match kind:
		"survive":
			if time_limit > 0.0 and elapsed_s >= time_limit:
				_win_challenge()
				return
		"clear":
			if _all_waves_done() and _is_room_cleared():
				_win_challenge()
				return
			if time_limit > 0.0 and elapsed_s >= time_limit:
				_fail_challenge("timeout")
				return
		"no_hit":
			var has_combat: bool = not _wave_schedule.is_empty() or not _is_room_cleared()
			if has_combat:
				if _all_waves_done() and _is_room_cleared():
					_win_challenge()
					return
				if time_limit > 0.0 and elapsed_s >= time_limit:
					_fail_challenge("timeout")
					return
			elif time_limit > 0.0 and elapsed_s >= time_limit:
				_win_challenge()
				return
		"light_all":
			if _count_lit_targets() >= _target_ids.size() and not _target_ids.is_empty():
				_win_challenge()
				return
			if time_limit > 0.0 and elapsed_s >= time_limit:
				_fail_challenge("timeout")
				return
		"race":
			var wpos: Vector2 = _get_wick_pos()
			if _next_cp < _checkpoints.size() and wpos.distance_to(_checkpoints[_next_cp]) <= _goal_radius:
				_next_cp += 1
				if Lx.events != null:
					Lx.events.sfx_requested.emit("switch_on", wpos, false)
				if _next_cp >= _checkpoints.size():
					_win_challenge()
					return
			if time_limit > 0.0 and elapsed_s >= time_limit:
				_fail_challenge("timeout")
				return
		"escort":
			_tick_escort(dt)
			if state != State.RUNNING:
				return
			if time_limit > 0.0 and elapsed_s >= time_limit:
				_fail_challenge("timeout")
				return

	_update_hud()
	queue_redraw()


func _tick_wave_schedule() -> void:
	if _owner_script == null:
		return
	for w: Dictionary in _wave_schedule:
		if not bool(w.get("_sent", false)) and elapsed_s >= float(w.get("at", 0.0)):
			w["_sent"] = true
			var enemies: Variant = w.get("enemies", w.get("wave", []))
			if _owner_script.has_method("spawn_wave_for_challenge"):
				_owner_script.call("spawn_wave_for_challenge", enemies, challenge_id)
			elif _owner_script.has_method("run_actions"):
				_owner_script.call("run_actions", [{"wave": enemies}])


func _tick_escort(dt: float) -> void:
	var wpos: Vector2 = _get_wick_pos()
	var lpos: Vector2 = _region.call("get_lantern_pos") as Vector2 if (_region != null and _region.has_method("get_lantern_pos")) else wpos
	var lit_near: bool = _escort_pos.distance_to(wpos) <= _escort_light_radius or _escort_pos.distance_to(lpos) <= _escort_light_radius
	if lit_near and _escort_idx < _escort_path.size():
		var tgt: Vector2 = _escort_path[_escort_idx]
		_escort_pos = _escort_pos.move_toward(tgt, _escort_speed * dt)
		if _escort_pos.distance_to(tgt) <= 3.0:
			_escort_idx += 1
	if _region != null and _region.has_method("get_enemies"):
		for e_v: Variant in (_region.call("get_enemies") as Array):
			if is_instance_valid(e_v) and e_v is LxEnemyBrain:
				var e: LxEnemyBrain = e_v as LxEnemyBrain
				if e.is_alive() and e.pos.distance_to(_escort_pos) <= e.body_radius + 8.0:
					_escort_hp = maxf(0.0, _escort_hp - dt * 1.2)
	if _escort_hp <= 0.0:
		_fail_challenge("escort_lost")
		return
	if _escort_pos.distance_to(_goal_pos) <= _goal_radius:
		_win_challenge()


func _win_challenge() -> void:
	state = State.WON
	_result_flash_t = 1.0
	var done_flag: String = "challenge_done_" + challenge_id
	var already_done: bool = Lx.state != null and bool(Lx.state.story_flags.get(done_flag, false))
	if Lx.state != null:
		Lx.state.story_flags[done_flag] = true
	if Lx.events != null:
		Lx.events.sfx_requested.emit("chest_open", _get_wick_pos(), false)
	_notify_gate(true)
	if _region != null and is_instance_valid(_region) and _region.has_method("save_interactables_to_state"):
		_region.call("save_interactables_to_state")
	if _owner_script != null and _owner_script.has_method("run_actions"):
		var acts: Array = []
		for a_v: Variant in _ok_actions:
			if a_v is Dictionary:
				var ad: Dictionary = (a_v as Dictionary).duplicate(true)
				if already_done:
					ad.erase("reward")
				if not ad.is_empty():
					acts.append(ad)
		if not already_done and not _reward_spec.is_empty():
			acts.append({"reward": _reward_spec})
		if not acts.is_empty():
			_owner_script.call("run_actions", acts)
	if not already_done and Lx.events != null:
		Lx.events.save_requested.emit("challenge_" + challenge_id)
	_update_hud()
	queue_redraw()


func _fail_challenge(_reason: String) -> void:
	state = State.FAILED
	_result_flash_t = 0.8
	_retry_t = AUTO_RETRY_DELAY
	_despawn_challenge_enemies()
	_notify_gate(false)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("denied", _get_wick_pos(), false)
	if _owner_script != null and _owner_script.has_method("run_actions") and not _fail_actions.is_empty():
		_owner_script.call("run_actions", _fail_actions)
	_update_hud()
	queue_redraw()


func _notify_gate(won: bool) -> void:
	if _gate != null and is_instance_valid(_gate) and _gate.has_method("on_challenge_result"):
		_gate.call("on_challenge_result", won)


func _despawn_challenge_enemies() -> void:
	if _owner_script != null and is_instance_valid(_owner_script) and _owner_script.has_method("clear_challenge_spawns"):
		_owner_script.call("clear_challenge_spawns", challenge_id)


func _all_waves_done() -> bool:
	for w: Dictionary in _wave_schedule:
		if not bool(w.get("_sent", false)):
			return false
	if _owner_script != null and _owner_script.has_method("has_pending_waves") and bool(_owner_script.call("has_pending_waves")):
		return false
	return true


func _is_room_cleared() -> bool:
	var z: String = str(_spec.get("zone", ""))
	return _region == null or not _region.has_method("is_zone_cleared") or bool(_region.call("is_zone_cleared", z))


func _count_lit_targets() -> int:
	if _region == null or not _region.has_method("find_interactable"):
		return 0
	var n: int = 0
	for tid: String in _target_ids:
		var it: LxInteractable = _region.call("find_interactable", tid) as LxInteractable
		if it != null and ((it.get("lit") == true) or (it.get("activated") == true) or (it.get("powered") == true)):
			n += 1
	return n


func _reset_light_targets() -> void:
	if kind != "light_all" or _region == null or not _region.has_method("find_interactable"):
		return
	for tid: String in _target_ids:
		var it: LxInteractable = _region.call("find_interactable", tid) as LxInteractable
		if it != null and it.get("lit") is bool:
			it.set("lit", false)
			it.queue_redraw()


func _get_hud() -> Node:
	if Lx.ui != null and is_instance_valid(Lx.ui) and Lx.ui.get("hud") is Node:
		return Lx.ui.get("hud") as Node
	return null


func _ensure_hud() -> void:
	var hud: Node = _get_hud()
	if hud != null and hud.has_method("show_challenge_timer"):
		_using_core_hud = true
		hud.call("show_challenge_timer", kind, time_limit)
		return
	_using_core_hud = false
	if _hud_layer == null or not is_instance_valid(_hud_layer):
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "ChallengeHudLayer"
		_hud_layer.layer = 25
		add_child(_hud_layer)
		_hud_draw = _LxChallengeHudDraw.new()
		_hud_draw.ch = self
		_hud_layer.add_child(_hud_draw)
	_hud_layer.visible = true
	if _hud_draw != null:
		_hud_draw.queue_redraw()


func _update_hud() -> void:
	var rem: float = maxf(0.0, time_limit - elapsed_s) if time_limit > 0.0 else elapsed_s
	var frac: float = clampf(rem / maxf(0.01, time_limit), 0.0, 1.0) if time_limit > 0.0 else 1.0
	if _using_core_hud:
		var hud: Node = _get_hud()
		if hud != null and hud.has_method("update_challenge_timer"):
			hud.call("update_challenge_timer", rem, frac, state)
	elif _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func _hide_hud() -> void:
	if _using_core_hud:
		var hud: Node = _get_hud()
		if hud != null and hud.has_method("hide_challenge_timer"):
			hud.call("hide_challenge_timer")
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_draw = null


func _draw_hud_overlay(ci: CanvasItem) -> void:
	if state == State.IDLE:
		return
	var bar_w: float = 88.0
	var bar_h: float = 6.0
	var x0: float = 116.0
	var y0: float = 12.0
	ci.draw_rect(Rect2(x0 - 2.0, y0 - 2.0, bar_w + 4.0, bar_h + 4.0), PAL["void"] as Color)
	ci.draw_rect(Rect2(x0 - 1.0, y0 - 1.0, bar_w + 2.0, bar_h + 2.0), PAL["dusk"] as Color)
	ci.draw_rect(Rect2(x0, y0, bar_w, bar_h), PAL["night"] as Color)
	var rem: float = maxf(0.0, time_limit - elapsed_s) if time_limit > 0.0 else elapsed_s
	var frac: float = clampf(rem / maxf(0.01, time_limit), 0.0, 1.0) if time_limit > 0.0 else 1.0
	var fill_col: Color = PAL["gold"] as Color
	if state == State.WON:
		fill_col = PAL["lime"] as Color
	elif state == State.FAILED:
		fill_col = PAL["coral"] as Color
	elif frac < 0.25:
		fill_col = PAL["coral"] as Color
	elif kind == "no_hit":
		fill_col = PAL["ice"] as Color
	elif kind == "escort":
		fill_col = PAL["sky"] as Color
	var fw: float = roundf(bar_w * frac)
	if fw > 0.0:
		ci.draw_rect(Rect2(x0, y0, fw, bar_h), fill_col)
		ci.draw_rect(Rect2(x0, y0, fw, 1.0), PAL["cream"] as Color)
	var secs_i: int = int(ceilf(rem))
	var time_txt: String = "%d:%02d" % [secs_i / 60, secs_i % 60]
	LxPixelFont.draw(ci, time_txt, Vector2(x0 + bar_w + 6.0, y0), PAL["cream"] as Color, 1, PAL["void"] as Color)
	var pips_total: int = 0
	var pips_done: int = 0
	if kind == "light_all":
		pips_total = _target_ids.size()
		pips_done = _count_lit_targets()
	elif kind == "race":
		pips_total = _checkpoints.size()
		pips_done = _next_cp
	elif kind == "escort":
		pips_total = int(ceilf(_escort_max_hp))
		pips_done = int(ceilf(_escort_hp))
	if pips_total > 0:
		for pi: int in range(pips_total):
			var px: float = x0 + float(pi) * 6.0
			var py: float = y0 + bar_h + 3.0
			ci.draw_rect(Rect2(px, py, 4.0, 3.0), PAL["void"] as Color)
			ci.draw_rect(Rect2(px + 1.0, py + 1.0, 2.0, 1.0), (PAL["gold"] if pi < pips_done else PAL["dusk"]) as Color)


func _draw() -> void:
	if state != State.RUNNING:
		return
	if kind == "race" and _next_cp < _checkpoints.size():
		var cp: Vector2 = _checkpoints[_next_cp].round()
		var pulse: float = 2.0 * sin(elapsed_s * 6.0)
		draw_arc(cp, roundf(_goal_radius * 0.65 + pulse), 0.0, TAU, 20, PAL["gold"] as Color, 1.5)
		draw_arc(cp, roundf(_goal_radius * 0.35), 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	elif kind == "escort":
		var ep: Vector2 = _escort_pos.round()
		draw_arc(_goal_pos.round(), roundf(_goal_radius * 0.65), 0.0, TAU, 18, PAL["jade"] as Color, 1.0)
		draw_circle(ep, 6.0, PAL["sky"] as Color)
		draw_circle(ep, 3.5, PAL["ice"] as Color)
		draw_rect(Rect2(ep - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), PAL["cream"] as Color)


func _get_wick_pos() -> Vector2:
	if _region != null and _region.has_method("get_wick_pos"):
		return _region.call("get_wick_pos") as Vector2
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		return (Lx.player as Node2D).global_position
	return _region_center()


func _region_center() -> Vector2:
	if _region != null and _region.get("bounds") is Rect2:
		return (_region.get("bounds") as Rect2).get_center()
	return Vector2(160.0, 90.0)
