class_name LxIsl4ClockGate
extends LxToy
## Island 4 Clock Gate (`clock_gate`):
## Topiary/brass gate synced to `dusk_hour` (or `hg_room_hour`). Opens on hours listed in `open_on`.
## Features a 6-pip brass plaque, 3 s warning rustle/tick before shifting, safe anti-crush Wick nudge,
## and permanent pin-sconce locking (`pin_sconce_id` + `pin_flag` survives all loop rewinds!).
## Props: var (String, default "dusk_hour"), scope (String), open_on (Array[int], default [2, 3]),
## rotate_deg (float, default 90), size ([w,h], default [16, 48]), pin_sconce_id (String),
## pin_flag (String), max_pip (int, default 6).

enum State { CLOSED, WARNING, OPEN, PINNED_OPEN }

const WARN_WINDOW_S: float = 3.0

var var_name: String = "dusk_hour"
var var_scope: String = ""
var open_on: Array[int] = [2, 3]
var rotate_deg: float = 90.0
var pin_sconce_id: String = ""
var pin_flag: String = ""
var max_pip: int = 6

var state: int = State.CLOSED
var current_hour: int = 1
var _phys_open: bool = false
var _anim_open: float = 0.0
var _warn_tick_cd: float = 0.0
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "clock_gate"
	if not props.has("size"):
		size = Vector2(16.0, 48.0)
	radius = maxf(size.x, size.y) * 0.5
	var_name = str(props.get("var", "dusk_hour")).strip_edges()
	if var_name.is_empty():
		var_name = "dusk_hour"
	var_scope = str(props.get("scope", "")).strip_edges()
	rotate_deg = float(props.get("rotate_deg", 90.0))
	pin_sconce_id = str(props.get("pin_sconce_id", "")).strip_edges()
	pin_flag = str(props.get("pin_flag", "")).strip_edges()
	max_pip = clampi(int(props.get("max_pip", 4 if var_name == "hg_room_hour" else 6)), 2, 6)

	open_on.clear()
	var raw_on: Variant = props.get("open_on", [2, 3])
	if raw_on is Array:
		for v: Variant in (raw_on as Array):
			open_on.append(int(v))
	if open_on.is_empty():
		open_on = [2, 3]

	_warn_tick_cd = 0.0
	_bind_vars()
	_evaluate_gate(false)
	_anim_open = 1.0 if _phys_open else 0.0
	queue_redraw()


func _exit_tree() -> void:
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _on_var_changed(_scope: String, nm: String, _value: Variant) -> void:
	if nm == var_name:
		_evaluate_gate(true)


func on_signal(from_id: String, is_on: bool) -> void:
	super.on_signal(from_id, is_on)
	if is_on and not pin_sconce_id.is_empty() and from_id == pin_sconce_id:
		pin_open(true)


func pin_open(with_feedback: bool = true) -> void:
	var was_pinned: bool = (state == State.PINNED_OPEN)
	if not pin_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[pin_flag] = true
	state = State.PINNED_OPEN
	_phys_open = true
	powered = true
	z_index = -4
	if not was_pinned and with_feedback:
		_emit_sfx("door_open")
		_emit_gust(56.0, 38.0)
		if Lx.events != null and LxStrings.has_id("ISL4_CUE_SEAL_PIN"):
			Lx.events.narration_requested.emit("ISL4_CUE_SEAL_PIN", "title", 2.4)
		emit_power(true)
	queue_redraw()


func is_pinned_open() -> bool:
	if state == State.PINNED_OPEN:
		return true
	if not pin_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(pin_flag, false)):
		return true
	return false


func get_state_name() -> String:
	match state:
		State.PINNED_OPEN: return "pinned_open"
		State.OPEN: return "open"
		State.WARNING: return "warning"
		_: return "closed"


func is_solid() -> bool:
	return active and not _phys_open


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if var_name == "dusk_hour":
		LxIsland4Rule.notify_sim_tick(dt, get_instance_id())
	if not active:
		return
	_check_pin_sconce()
	_evaluate_gate(true)
	if state == State.WARNING:
		_warn_tick_cd -= dt
		if _warn_tick_cd <= 0.0:
			_warn_tick_cd = 1.0
			_emit_sfx("clock_gate_warn")
		queue_redraw()
	else:
		_warn_tick_cd = 0.0
	var target_a: float = 1.0 if _phys_open else 0.0
	if not is_equal_approx(_anim_open, target_a):
		_anim_open = move_toward(_anim_open, target_a, dt * 6.5)
		queue_redraw()


func _check_pin_sconce() -> void:
	if is_pinned_open() or pin_sconce_id.is_empty():
		return
	if region == null or not is_instance_valid(region) or not region.has_method("find_interactable"):
		return
	var sc: LxInteractable = region.call("find_interactable", pin_sconce_id) as LxInteractable
	if sc == null or not is_instance_valid(sc):
		return
	var is_lit: bool = (sc.get("lit") is bool and bool(sc.get("lit"))) \
		or (sc.get("powered") is bool and bool(sc.get("powered"))) \
		or (sc.get("activated") is bool and bool(sc.get("activated")))
	if is_lit:
		pin_open(true)


func _read_hour() -> int:
	if not var_scope.is_empty():
		var v0: Variant = LxToyDraw.world_get_var(var_scope, var_name, 1)
		return clampi(int(v0) if str(v0).is_valid_float() else 1, 1, max_pip)
	if Lx.vars != null:
		var v1: Variant = Lx.vars.resolve_var(var_name, island_id, region_id, 1)
		return clampi(int(v1) if str(v1).is_valid_float() else 1, 1, max_pip)
	return 1


func _evaluate_gate(with_sfx: bool) -> void:
	current_hour = _read_hour()
	if is_pinned_open():
		state = State.PINNED_OPEN
		_phys_open = true
		powered = true
		z_index = -4
		return

	var want_open: bool = open_on.has(current_hour)
	var prev_open: bool = _phys_open
	if prev_open and not want_open:
		_safe_nudge_wick_clear()
	_phys_open = want_open
	powered = want_open
	z_index = -4 if _phys_open else 0

	var warning_now: bool = false
	if var_name == "dusk_hour" and LxIsland4Rule.active_instance != null and is_instance_valid(LxIsland4Rule.active_instance):
		var rule: LxIsland4Rule = LxIsland4Rule.active_instance
		if not rule.is_paused() and rule.get_hour_time_left() <= WARN_WINDOW_S:
			var next_h: int = 1 if current_hour >= max_pip else (current_hour + 1)
			if open_on.has(next_h) != want_open:
				warning_now = true

	var next_state: int = State.WARNING if warning_now else (State.OPEN if _phys_open else State.CLOSED)
	if next_state != state:
		state = next_state
		if with_sfx and prev_open != _phys_open:
			_emit_sfx("door_open" if _phys_open else "prop_rustle")
			emit_power(_phys_open)
		queue_redraw()


## Never crushes Wick: if gate closes over Wick, nudges Wick cleanly to the nearest safe point outside.
func _safe_nudge_wick_clear() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead:
		return
	var r: Rect2 = rect_at(pos).grow(4.5)
	if not r.has_point(w.global_position):
		return
	var wp: Vector2 = w.global_position
	var cands: Array[Vector2] = [
		Vector2(r.position.x - 6.0, wp.y),
		Vector2(r.end.x + 6.0, wp.y),
		Vector2(wp.x, r.position.y - 6.0),
		Vector2(wp.x, r.end.y + 6.0),
	]
	cands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(wp) < b.distance_squared_to(wp))
	for cand: Vector2 in cands:
		if region != null and region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", cand)):
			continue
		if region != null and region.has_method("tile_at") and region.has_method("is_solid_tile"):
			if bool(region.call("is_solid_tile", str(region.call("tile_at", cand)), false, false)):
				continue
		w.global_position = cand
		w.last_pos = cand
		w._last_safe_pos = cand
		return


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.PINNED_OPEN:
		return Vector4(pos.x, pos.y, 44.0, 0.78)
	if state == State.WARNING:
		return Vector4(pos.x, pos.y, 32.0, 0.50)
	return Vector4.ZERO


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color

	var rustle: float = 0.0
	if state == State.WARNING and not LxHudFx.flash_reduced():
		rustle = 1.0 if int(floorf(_clock * 14.0)) % 2 == 0 else -1.0

	if _phys_open:
		# Pivoted / retracted topiary gate pockets at both ends + open threshold line
		var jb: float = minf(6.0, floorf(minf(w, h) * 0.35))
		var post_hi: Color = c_cream if state == State.PINNED_OPEN else c_gold
		if w >= h:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, jb, h), c_pine, c_jade, post_hi, c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0 + w - jb, y0, jb, h), c_pine, c_jade, post_hi, c_void)
		else:
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, jb), c_pine, c_jade, post_hi, c_void)
			LxToyDraw.draw_bevel_box(self, Rect2(x0, y0 + h - jb, w, jb), c_pine, c_jade, post_hi, c_void)
		_draw_brass_plaque(Vector2(0.0, y0 + 3.0 if h > w else 0.0))
		return

	# Closed topiary hedge + wrought brass clockwork bars
	draw_rect(Rect2(x0 + 1.0, y0 + h, w - 2.0, 2.0), Color(c_void, 0.55))
	var hi_c: Color = c_coral if state == State.WARNING else c_lime
	LxToyDraw.draw_bevel_box(self, Rect2(x0 + rustle, y0, w, h), c_pine, c_jade, hi_c, c_void)
	# Vertical/horizontal brass trellis ribs
	if h >= w:
		var gy: float = y0 + 6.0
		while gy < y0 + h - 5.0:
			draw_rect(Rect2(x0 + 2.0 + rustle, gy, w - 4.0, 2.0), c_apricot if state != State.WARNING else c_gold)
			gy += 8.0
	else:
		var gx: float = x0 + 6.0
		while gx < x0 + w - 5.0:
			draw_rect(Rect2(gx + rustle, y0 + 2.0, 2.0, h - 4.0), c_apricot if state != State.WARNING else c_gold)
			gx += 8.0
	_draw_brass_plaque(Vector2(rustle, 0.0))
	_draw_signal_pulses()


func _draw_brass_plaque(center: Vector2) -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_mauve: Color = PAL["mauve"] as Color

	var pw: float = float(max_pip) * 2.0 + 4.0
	var px0: float = floorf(center.x - pw * 0.5)
	var py0: float = floorf(center.y - 3.0)
	draw_rect(Rect2(px0, py0, pw, 6.0), c_void)
	draw_rect(Rect2(px0 + 1.0, py0 + 1.0, pw - 2.0, 4.0), c_night)
	if state == State.PINNED_OPEN:
		# Permanent gold flame crest across plaque
		draw_rect(Rect2(px0 + 2.0, py0 + 2.0, pw - 4.0, 2.0), c_gold)
		draw_rect(Rect2(center.x - 1.0, py0 + 1.0, 2.0, 4.0), c_cream)
		return
	for i: int in range(max_pip):
		var h_i: int = i + 1
		var ix: float = px0 + 2.0 + float(i) * 2.0
		var is_open_h: bool = open_on.has(h_i)
		var is_now: bool = (h_i == current_hour)
		var col_p: Color = c_mauve
		if is_now:
			col_p = c_coral if state == State.WARNING else c_cream
		elif is_open_h:
			col_p = c_gold
		draw_rect(Rect2(ix, py0 + 2.0, 1.0, 2.0 if (is_open_h or is_now) else 1.0), col_p)
