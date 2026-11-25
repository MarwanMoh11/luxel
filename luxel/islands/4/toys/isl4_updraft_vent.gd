class_name LxIsl4UpdraftVent
extends LxToy
## Island 4 Updraft Vent (`updraft_vent`):
## Bronze floor grate emitting a swirling thermal plume. When gliding Wick touches the plume,
## refreshes `move_wings` stamina to 100%, grants a 2.2 s 1.25x tailwind boost, plays `updraft_catch`,
## and nudges Wick along `dir` if non-zero.
## Props: radius (float, default 22), on (bool, default true), requires_signals (Array[String]),
## weather_req (String), hour_req (Array[int]), dir ([x,y] or "n|e|s|w"), boost_mult (float, default 1.25),
## boost_secs (float, default 2.2), period (float, default 0.0), duty (float, default 0.5), offset (float).

enum State { DORMANT, BLOWING }

var vent_radius: float = 22.0
var weather_req: String = ""
var hour_req: Array[int] = []
var nudge_dir: Vector2 = Vector2.ZERO
var boost_mult: float = 1.25
var boost_secs: float = 2.2
var period: float = 0.0
var duty: float = 0.5
var phase_offset: float = 0.0

var state: int = State.BLOWING
var _signal_open: bool = true
var _wheel_weather: String = ""
var _catch_cd: float = 0.0
var _burst_t: float = 0.0
var _helix_t: float = 0.0
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "updraft_vent"
	z_as_relative = false
	z_index = -4
	vent_radius = maxf(10.0, float(props.get("radius", 22.0)))
	radius = vent_radius
	weather_req = str(props.get("weather_req", "")).strip_edges().to_lower()
	hour_req.clear()
	var raw_hr: Variant = props.get("hour_req", [])
	if raw_hr is Array:
		for h_v: Variant in (raw_hr as Array):
			hour_req.append(int(h_v))
	var raw_dir: Variant = props.get("dir", [0.0, 0.0])
	if raw_dir is String and not (raw_dir as String).strip_edges().is_empty():
		nudge_dir = dir_vec("dir", Vector2.ZERO)
	else:
		var dv: Vector2 = LxMapFormat.to_vec2(raw_dir, Vector2.ZERO)
		nudge_dir = dv.normalized() if dv.length_squared() > 0.01 else Vector2.ZERO
	boost_mult = maxf(1.0, float(props.get("boost_mult", 1.25)))
	boost_secs = maxf(0.2, float(props.get("boost_secs", 2.2)))
	period = maxf(0.0, float(props.get("period", 0.0)))
	duty = clampf(float(props.get("duty", 0.5)), 0.1, 0.95)
	phase_offset = float(props.get("offset", 0.0))

	var need_v: Variant = props.get("requires_signals", [])
	var has_req_sigs: bool = need_v is Array and not (need_v as Array).is_empty()
	_signal_open = bool(props.get("on", not has_req_sigs))
	powered = _signal_open
	_catch_cd = 0.0
	_burst_t = 0.0
	_helix_t = 0.0
	_bind_vars()
	_evaluate_state()
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
	if nm == "weather" or nm == "dusk_hour":
		_evaluate_state()
		queue_redraw()


func on_weather_changed(weather: String, _wind_dir: Vector2) -> void:
	_wheel_weather = weather.strip_edges().to_lower()
	_evaluate_state()
	queue_redraw()


func _on_power_changed(is_on: bool) -> void:
	_signal_open = is_on
	_evaluate_state()
	queue_redraw()


func is_blowing() -> bool:
	return active and state == State.BLOWING


func get_state_name() -> String:
	return "blowing" if is_blowing() else "dormant"


func _evaluate_state() -> void:
	var ok: bool = active and _signal_open
	if ok and not weather_req.is_empty():
		var cur_w: String = _wheel_weather
		if cur_w.is_empty() and Lx.vars != null:
			cur_w = str(Lx.vars.resolve_var("weather", island_id, region_id, "")).strip_edges().to_lower()
		ok = (cur_w == weather_req)
	if ok and not hour_req.is_empty():
		var cur_h: int = int(Lx.vars.resolve_var("dusk_hour", island_id, region_id, 1)) if Lx.vars != null else 1
		ok = hour_req.has(cur_h)
	if ok and period > 0.05:
		var cyc: float = fposmod(_clock + phase_offset, period) / period
		ok = cyc < duty
	state = State.BLOWING if ok else State.DORMANT


func tick(dt: float) -> void:
	super.tick(dt)
	if _catch_cd > 0.0:
		_catch_cd = maxf(0.0, _catch_cd - dt)
	if _burst_t > 0.0:
		_burst_t = maxf(0.0, _burst_t - dt)
		queue_redraw()
	var prev_state: int = state
	_evaluate_state()
	if state != prev_state:
		queue_redraw()
	if not is_blowing():
		return
	var spd: float = 2.4 if LxHudFx.flash_reduced() else 5.2
	_helix_t = fmod(_helix_t + dt * spd, TAU)
	_check_wick_catch()
	queue_redraw()


func _check_wick_catch() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead or not w.is_gliding() or w.move_wings == null:
		return
	var dist: float = w.global_position.distance_to(pos)
	if dist > vent_radius + 6.0:
		return
	# Continuously keep stamina refreshed and nudge along dir while inside plume
	w.move_wings.refresh_glide(boost_mult, boost_secs)
	if LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance):
		LxBiomeMechanics.active_instance.tailwind_t = maxf(LxBiomeMechanics.active_instance.tailwind_t, boost_secs)
	if nudge_dir.length_squared() > 0.01:
		w.push_external(nudge_dir * 42.0, "updraft")
	if _catch_cd <= 0.0:
		_catch_cd = 0.38
		_burst_t = 0.34
		_emit_sfx("updraft_catch")
		w.spawn_ring(pos, 4.0, vent_radius + 4.0, 0.24, PAL["ice"] as Color, 1.5)
		w.spawn_sparks(w.global_position, Vector2.UP, 6, PAL["cream"] as Color, 18.0, 56.0, 0.24)
		_emit_gust(vent_radius + 16.0, 52.0)


func get_light_pool() -> Vector4:
	if not is_blowing():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, vent_radius + 18.0, 0.65 if _burst_t > 0.0 else 0.42)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color

	var blowing: bool = is_blowing()
	# Sunken bronze grate base (16x16 core)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -8.0, 16.0, 16.0), c_night, c_dusk, c_gold if blowing else c_apricot, c_void)
	for sy: float in [-5.0, -1.0, 3.0]:
		draw_rect(Rect2(-6.0, sy, 12.0, 2.0), c_void)
		if blowing:
			draw_rect(Rect2(-5.0, sy, 10.0, 1.0), c_sky)

	if not blowing:
		# Dormant center pip + faint boundary ring so inactive vents still read clearly
		draw_arc(Vector2.ZERO, vent_radius - 2.0, 0.0, TAU, 16, Color(c_sky, 0.24), 1.0)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_dusk)
		return

	# Plume outer boundary ring (shows exact catch radius cleanly)
	var ring_a: float = 0.36 if LxHudFx.flash_reduced() else 0.52
	draw_arc(Vector2.ZERO, vent_radius, 0.0, TAU, 20, Color(c_sky, ring_a), 1.0)
	draw_arc(Vector2.ZERO, vent_radius - 5.0, _helix_t, _helix_t + PI * 1.15, 14, Color(c_ice, 0.80), 1.0)
	draw_arc(Vector2.ZERO, vent_radius - 5.0, _helix_t + PI, _helix_t + TAU * 0.85, 14, Color(c_cream, 0.72), 1.0)

	# Rising swirling pixel helix ribbons (sky/ice/cream)
	for k: int in range(6):
		var frac: float = fposmod(float(k) / 6.0 + _helix_t / TAU, 1.0)
		var ang: float = _helix_t * 1.4 + float(k) * (TAU / 3.0)
		var hr: float = lerpf(4.0, vent_radius * 0.65, 1.0 - frac * 0.35)
		var hx: float = roundf(cos(ang) * hr)
		var hy: float = roundf(2.0 - frac * 18.0 + sin(ang) * 3.0)
		var col_m: Color = c_cream if (k % 3 == 0) else (c_ice if k % 3 == 1 else c_sky)
		draw_rect(Rect2(hx, hy, 2.0 if k % 2 == 0 else 1.0, 2.0), col_m)

	# Directional tailwind chevron if dir != ZERO
	if nudge_dir.length_squared() > 0.01:
		var ch_p: Vector2 = (nudge_dir * 6.0).round()
		draw_rect(Rect2(ch_p - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
		draw_rect(Rect2(ch_p, Vector2.ONE), c_cream)

	if _burst_t > 0.0:
		var u: float = 1.0 - clampf(_burst_t / 0.34, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, vent_radius + 6.0, u)), 0.0, TAU, 18, Color(c_cream, 1.0 - u), 1.5)
	_draw_signal_pulses()
