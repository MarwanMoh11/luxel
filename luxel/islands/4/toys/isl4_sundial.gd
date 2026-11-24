class_name LxIsl4Sundial
extends LxToy
## Island 4 Garden Sundial (`garden_sundial`):
## Displays a 6-pip (or 4-pip room-locked) brass sundial synced to `dusk_hour` (or `hg_room_hour`).
## Tap E: advance +1 hour (0.4 s amber sweep, wraps max_hour -> 1).
## Hold E (0.6 s) or Beam hit: rewind to Hour 1 (0.6 s rose-gold sweep) if `can_rewind: true`.
## Never wipes earned keys, flags, moths, panes, embers, shards, or pin-sconces.
## Props: region_hour_lock (bool), can_rewind (bool, default true), visual_radius (float, default 14),
## scope (String), var (String), max_hour (int), shootable (bool), target_id/target_ids.

enum State { IDLE, SWEEPING, REWINDING }

const SWEEP_DUR: float = 0.40
const REWIND_DUR: float = 0.60
const HOLD_REWIND_S: float = 0.60

var region_hour_lock: bool = false
var can_rewind: bool = true
var visual_radius: float = 14.0
var var_scope: String = "island:4"
var var_name: String = "dusk_hour"
var max_hour: int = 6
var shootable: bool = false

var state: int = State.IDLE
var current_hour: int = 1
var _state_t: float = 0.0
var _cd: float = 0.0
var _hold_t: float = 0.0
var _hold_consumed: bool = false
var _was_interact_held: bool = false
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "garden_sundial"
	region_hour_lock = bool(props.get("region_hour_lock", false))
	can_rewind = bool(props.get("can_rewind", true))
	visual_radius = maxf(10.0, float(props.get("visual_radius", 14.0)))
	radius = maxf(visual_radius, 14.0)
	if region_hour_lock:
		var_scope = str(props.get("scope", "room:%d:%s" % [island_id, region_id])).strip_edges()
		var_name = str(props.get("var", "hg_room_hour")).strip_edges()
		max_hour = clampi(int(props.get("max_hour", 4)), 2, 6)
		shootable = bool(props.get("shootable", true))
	else:
		var_scope = str(props.get("scope", "island:%d" % island_id)).strip_edges()
		var_name = str(props.get("var", "dusk_hour")).strip_edges()
		max_hour = clampi(int(props.get("max_hour", 6)), 2, 6)
		shootable = bool(props.get("shootable", false))
	state = State.IDLE
	_state_t = 0.0
	_cd = 0.0
	_hold_t = 0.0
	_hold_consumed = false
	_was_interact_held = false
	_bind_vars()
	_sync_hour_from_vars()
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


func _on_var_changed(scope: String, nm: String, value: Variant) -> void:
	if nm != var_name:
		return
	if scope != var_scope and not (not region_hour_lock and scope == "island:4"):
		return
	var nh: int = clampi(int(value) if str(value).is_valid_float() else current_hour, 1, max_hour)
	if nh != current_hour:
		current_hour = nh
		queue_redraw()


func _sync_hour_from_vars() -> void:
	var v: Variant = LxToyDraw.world_get_var(var_scope, var_name, 1)
	if str(v).is_valid_float():
		current_hour = clampi(int(v), 1, max_hour)
	else:
		current_hour = 1
		LxToyDraw.world_set_var(var_scope, var_name, current_hour)


func reset_toy() -> void:
	state = State.IDLE
	_state_t = 0.0
	_hold_t = 0.0
	_hold_consumed = false
	_sync_hour_from_vars()
	queue_redraw()


func get_state_name() -> String:
	match state:
		State.SWEEPING: return "sweeping"
		State.REWINDING: return "rewinding"
		_: return "idle"


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	if _hold_consumed:
		_hold_consumed = false
		return true
	return advance_hour()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.source in ["beam", "sunflare"] and can_rewind:
		return rewind()
	if shootable and hit.source in ["bolt", "prism_bolt", "throw", "recall"]:
		return advance_hour()
	return false


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_SUNDIAL" if active else ""


func advance_hour() -> bool:
	_cd = 0.28
	var next_h: int = 1 if current_hour >= max_hour else (current_hour + 1)
	current_hour = next_h
	state = State.SWEEPING
	_state_t = SWEEP_DUR
	if not region_hour_lock and var_name == "dusk_hour" and LxIsland4Rule.active_instance != null and is_instance_valid(LxIsland4Rule.active_instance):
		LxIsland4Rule.active_instance.set_hour(next_h, true, true)
	else:
		LxToyDraw.world_set_var(var_scope, var_name, next_h)
		if region != null and region.has_method("apply_layers"):
			region.call("apply_layers", true)
		_emit_sfx("sundial_skip")
	set_powered(true)
	emit_power(true)
	_emit_gust(48.0, 32.0)
	queue_redraw()
	return true


func rewind() -> bool:
	if not can_rewind:
		return false
	_cd = 0.40
	current_hour = 1
	state = State.REWINDING
	_state_t = REWIND_DUR
	if not region_hour_lock and var_name == "dusk_hour" and LxIsland4Rule.active_instance != null and is_instance_valid(LxIsland4Rule.active_instance):
		LxIsland4Rule.active_instance.rewind_to_hour_one(true)
	else:
		LxToyDraw.world_set_var(var_scope, var_name, 1)
		if region != null and region.has_method("apply_layers"):
			region.call("apply_layers", true)
		_emit_sfx("sundial_skip")
	set_powered(false)
	emit_power(false)
	_emit_gust(62.0, 44.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not region_hour_lock and var_name == "dusk_hour":
		LxIsland4Rule.notify_sim_tick(dt, get_instance_id())
	if not active:
		return
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _state_t > 0.0:
		_state_t = maxf(0.0, _state_t - dt)
		if _state_t <= 0.0:
			state = State.IDLE
		queue_redraw()
	_poll_hold_rewind(dt)


func _poll_hold_rewind(dt: float) -> void:
	if not can_rewind or Lx.input == null:
		return
	var held: bool = Lx.input.is_action_active("lx_interact")
	var near: bool = wick_pos().distance_to(pos) <= radius + 24.0
	if held and near:
		if not _was_interact_held:
			_hold_t = 0.0
			_hold_consumed = false
		_hold_t += dt
		if _hold_t >= HOLD_REWIND_S and not _hold_consumed:
			_hold_consumed = true
			rewind()
		queue_redraw()
	else:
		if _hold_t > 0.0:
			_hold_t = 0.0
			queue_redraw()
	_was_interact_held = held


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var boost: float = 18.0 if state != State.IDLE else 0.0
	return Vector4(pos.x, pos.y - 4.0, 34.0 + boost, 0.72 if state != State.IDLE else 0.45)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color

	var r: float = roundf(visual_radius)
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), r * 0.85, 3.5)

	# Carved octagonal stone pedestal + brass dial plate
	LxToyDraw.draw_bevel_box(self, Rect2(-r + 1.0, -r + 3.0, (r - 1.0) * 2.0, (r - 1.0) * 2.0), c_night, c_dusk, c_stone, c_void)
	draw_circle(Vector2(0.0, 1.0), r - 2.0, c_void)
	draw_circle(Vector2(0.0, 1.0), r - 3.0, c_dusk)
	draw_arc(Vector2(0.0, 1.0), r - 3.0, 0.0, TAU, 16, c_gold if state != State.IDLE else c_apricot, 1.0)

	# 6-pip (or 4-pip) hour markers around rim, distinct in greyscale
	var hand_ang: float = -PI * 0.5
	for i: int in range(max_hour):
		var h_i: int = i + 1
		var ang: float = -PI * 0.5 + (TAU * float(i)) / float(max_hour)
		var pr: float = r - 5.0
		var pp := Vector2(roundf(cos(ang) * pr), roundf(1.0 + sin(ang) * pr))
		var is_cur: bool = (h_i == current_hour)
		if is_cur:
			hand_ang = ang
			draw_rect(Rect2(pp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
			draw_rect(Rect2(pp - Vector2.ONE, Vector2(3.0, 3.0)), c_gold)
			draw_rect(Rect2(pp, Vector2.ONE), c_cream)
		else:
			var pc: Color = c_apricot if h_i < current_hour else c_mauve
			draw_rect(Rect2(pp - Vector2.ONE, Vector2(2.0, 2.0)), pc)

	# Gnomon brass needle & shadow pointing to current hour
	var tip := Vector2(roundf(cos(hand_ang) * (r - 5.0)), roundf(1.0 + sin(hand_ang) * (r - 5.0)))
	draw_line(Vector2(1.0, 2.0), tip + Vector2(1.0, 1.0), c_void, 2.0)
	draw_line(Vector2(0.0, 1.0), tip, c_cream if state != State.IDLE else c_gold, 1.0)
	draw_rect(Rect2(-2.0, -1.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, 0.0, 2.0, 2.0), c_cream)

	# Hold-to-rewind progress arc
	if _hold_t > 0.05 and can_rewind:
		var hf: float = clampf(_hold_t / HOLD_REWIND_S, 0.0, 1.0)
		draw_arc(Vector2(0.0, 1.0), r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * hf, 16, c_rose, 1.5)

	# Sweep / Rewind ripple ring
	if _state_t > 0.0:
		var dur: float = REWIND_DUR if state == State.REWINDING else SWEEP_DUR
		var u: float = 1.0 - clampf(_state_t / maxf(dur, 0.01), 0.0, 1.0)
		var ring_r: float = roundf(lerpf(r + 12.0, 4.0, u) if state == State.REWINDING else lerpf(6.0, r + 12.0, u))
		var rc: Color = c_rose if state == State.REWINDING else c_gold
		var ring_a: float = (1.0 - u * 0.8) * (0.55 if LxHudFx.flash_reduced() else 1.0)
		draw_arc(Vector2(0.0, 1.0), ring_r, 0.0, TAU, 16, Color(rc, ring_a), 1.5)
	_draw_signal_pulses()
