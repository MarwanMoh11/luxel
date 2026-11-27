class_name LxIsl4WeatherWheel
extends LxToy
## Island 4 Weather Wheel (`weather_wheel`):
## Rotates 120 deg across ["sun", "rain", "wind"] on E, bolt, Echo bolt, beam, or throw.
## Updates `Lx.vars` (`weather` in `scope`) with a 1.0 s visual sweep and notifies
## timed_brazier (rain snuffs unroofed flames), wind_zone (wind toggles weather-driven zones),
## updraft_vent (refreshes weather-gated vents), and weather-aware enemies (rain_frog, mist_eel).
## Props: scope (String, default "dungeon:mausoleum"), wind_dir ("n|e|s|w" or [x,y]),
## start ("sun"|"rain"|"wind", default "rain"), states (Array), var (String, default "weather"),
## target_id/target_ids.

const SWEEP_DUR: float = 1.0

var var_scope: String = "dungeon:rain_mausoleum"
var var_name: String = "weather"
var states: Array[String] = ["sun", "rain", "wind"]
var wind_dir: Vector2 = Vector2.RIGHT
var current_weather: String = "rain"
var state_idx: int = 1

var sweep_t: float = 0.0
var _needle_ang: float = 0.0
var _cd: float = 0.0
var _vars_bound: LxWorldState = null
var _init_notified: bool = false


func _toy_setup() -> void:
	kind = "weather_wheel"
	radius = maxf(14.0, radius)
	var_scope = str(props.get("scope", "dungeon:rain_mausoleum")).strip_edges()
	if var_scope.is_empty():
		var_scope = "room:%d:%s" % [island_id, region_id]
	var_name = str(props.get("var", "weather")).strip_edges()
	if var_name.is_empty():
		var_name = "weather"
	wind_dir = dir_vec("wind_dir", Vector2.RIGHT)
	states.clear()
	var raw_st: Variant = props.get("states", ["sun", "rain", "wind"])
	if raw_st is Array and not (raw_st as Array).is_empty():
		for item: Variant in (raw_st as Array):
			var s: String = str(item).strip_edges().to_lower()
			if not s.is_empty() and not states.has(s):
				states.append(s)
	if states.is_empty():
		states = ["sun", "rain", "wind"]
	var start_w: String = str(props.get("start", "rain")).strip_edges().to_lower()
	if not states.has(start_w):
		start_w = states[0]
	var existing: String = str(LxToyDraw.world_get_var(var_scope, var_name, "__unset__")).strip_edges().to_lower()
	if not bool(props.get("reset_on_enter", false)) and existing != "__unset__" and states.has(existing):
		current_weather = existing
	else:
		current_weather = start_w
		LxToyDraw.world_set_var(var_scope, var_name, current_weather)
	state_idx = maxi(0, states.find(current_weather))
	_needle_ang = _sector_angle(state_idx)
	sweep_t = 0.0
	_cd = 0.0
	_init_notified = false
	_bind_vars()
	_notify_room_weather(false)
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
	if nm != var_name or scope != var_scope:
		return
	var w: String = str(value).strip_edges().to_lower()
	if states.has(w) and w != current_weather:
		current_weather = w
		state_idx = states.find(w)
		sweep_t = SWEEP_DUR
		_notify_room_weather(false)
		queue_redraw()


func reset_toy() -> void:
	var start_w: String = str(props.get("start", "rain")).strip_edges().to_lower()
	if not states.has(start_w):
		start_w = states[0]
	set_weather(start_w, false)


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	return cycle_weather()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return cycle_weather()
	return false


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_WHEEL" if active else ""


func cycle_weather() -> bool:
	if states.is_empty():
		return false
	var nxt_idx: int = (state_idx + 1) % states.size()
	return set_weather(states[nxt_idx], true)


func set_weather(new_weather: String, with_feedback: bool = true) -> bool:
	var w: String = new_weather.strip_edges().to_lower()
	if not states.has(w):
		return false
	_cd = 0.25
	current_weather = w
	state_idx = states.find(w)
	sweep_t = SWEEP_DUR if with_feedback else 0.0
	LxToyDraw.world_set_var(var_scope, var_name, current_weather)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers", with_feedback)
	_notify_room_weather(with_feedback)
	set_powered(current_weather != str(props.get("start", "rain")).to_lower())
	emit_power(true)
	if with_feedback:
		_emit_sfx("weather_wheel_turn")
		_emit_sfx("weather_shift_" + current_weather)
		_emit_gust(60.0, 42.0)
		if Lx.events != null:
			var cue_key: String = "ISL4_CUE_WEATHER_SUN" if current_weather == "sun" else ("ISL4_CUE_WEATHER_WIND" if current_weather == "wind" else "ISL4_CUE_WEATHER_RAIN")
			if LxStrings.has_id(cue_key):
				Lx.events.narration_requested.emit(cue_key, "narration", 1.8)
	if region != null and region.has_method("notify"):
		region.call("notify", "weather_changed", {"weather": current_weather, "wind_dir": wind_dir})
	queue_redraw()
	return true


func _notify_room_weather(with_sfx: bool) -> void:
	if region == null or not is_instance_valid(region):
		return
	if region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or not is_instance_valid(it_v):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if it is LxTimedBrazier:
				var tb: LxTimedBrazier = it as LxTimedBrazier
				if current_weather == "rain" and tb.lit and not tb.is_reset_brazier and not bool(tb.props.get("roofed", false)):
					tb._extinguish(with_sfx)
			elif it.kind == "wind_zone" and it is LxPhysWindZone:
				var wz: LxPhysWindZone = it as LxPhysWindZone
				var wreq: String = str(wz.props.get("weather_req", "")).strip_edges().to_lower()
				if wreq.is_empty() and bool(wz.props.get("weather_driven", false)):
					wreq = "wind"
				if not wreq.is_empty():
					var want_on: bool = (current_weather == wreq)
					wz.active = want_on
					wz.visible = want_on
					if want_on and bool(wz.props.get("adopt_wheel_dir", false)):
						wz.wind_dir = wind_dir
					wz.queue_redraw()
			elif it.has_method("on_weather_changed"):
				it.call("on_weather_changed", current_weather, wind_dir)
	if region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if e_v is Object and is_instance_valid(e_v) and (e_v as Object).has_method("on_weather_changed"):
				(e_v as Object).call("on_weather_changed", current_weather, wind_dir)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if not _init_notified:
		_init_notified = true
		_notify_room_weather(false)
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	var target_a: float = _sector_angle(state_idx)
	var diff: float = wrapf(target_a - _needle_ang, -PI, PI)
	if absf(diff) > 0.01:
		_needle_ang = wrapf(_needle_ang + clampf(diff, -dt * 9.0, dt * 9.0), -PI, PI)
		queue_redraw()
	if sweep_t > 0.0:
		sweep_t = maxf(0.0, sweep_t - dt)
		queue_redraw()


func _sector_angle(idx: int) -> float:
	var n: int = maxi(1, states.size())
	return -PI * 0.5 + (TAU * float(idx)) / float(n)


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var rad: float = 48.0 if sweep_t > 0.0 else 34.0
	return Vector4(pos.x, pos.y - 2.0, rad, 0.78 if current_weather == "sun" else 0.50)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_mauve: Color = PAL["mauve"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 12.0, 4.0)
	# Outer carved stone wheel frame
	draw_circle(Vector2.ZERO, 13.0, c_void)
	draw_circle(Vector2.ZERO, 12.0, c_night)
	draw_circle(Vector2.ZERO, 10.0, c_dusk)
	var rim_c: Color = c_gold if current_weather == "sun" else (c_sky if current_weather == "rain" else c_ice)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 18, rim_c, 1.0)

	# 3 sector weather icons (distinct geometric shapes readable in greyscale)
	for i: int in range(states.size()):
		var ang: float = _sector_angle(i)
		var sc := Vector2(roundf(cos(ang) * 6.5), roundf(sin(ang) * 6.5))
		var act: bool = (i == state_idx)
		var st_name: String = states[i]
		if act:
			var notch := Vector2(roundf(cos(ang) * 13.0), roundf(sin(ang) * 13.0))
			draw_rect(Rect2(notch - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
			draw_rect(Rect2(notch - Vector2.ONE, Vector2(2.0, 2.0)), c_cream)
			draw_circle(sc, 4.0, c_void)
			draw_circle(sc, 3.0, rim_c)
		match st_name:
			"sun":
				var col_s: Color = c_cream if act else c_gold
				draw_rect(Rect2(sc.x - 2.0, sc.y, 5.0, 1.0), col_s)
				draw_rect(Rect2(sc.x, sc.y - 2.0, 1.0, 5.0), col_s)
				if act:
					draw_rect(Rect2(sc - Vector2.ONE, Vector2(3.0, 3.0)), c_cream)
			"rain":
				var col_r: Color = c_cream if act else c_sky
				draw_rect(Rect2(sc.x - 2.0, sc.y - 1.0, 1.0, 2.0), col_r)
				draw_rect(Rect2(sc.x, sc.y - 2.0, 1.0, 3.0), c_ice if act else col_r)
				draw_rect(Rect2(sc.x + 2.0, sc.y, 1.0, 2.0), col_r)
			"wind":
				var col_w: Color = c_cream if act else c_lime
				draw_rect(Rect2(sc.x - 2.0, sc.y - 1.0, 4.0, 1.0), col_w)
				draw_rect(Rect2(sc.x - 1.0, sc.y + 1.0, 4.0, 1.0), c_ice if act else col_w)
			_:
				draw_rect(Rect2(sc - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if act else c_mauve)

	# Rotating brass pointer needle (void-backed for greyscale contrast)
	var tip := Vector2(roundf(cos(_needle_ang) * 9.0), roundf(sin(_needle_ang) * 9.0))
	draw_line(Vector2.ZERO, tip, c_void, 2.0)
	draw_line(Vector2.ZERO, tip, c_cream, 1.0)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), rim_c)

	# 1.0 s weather transition sweep ring (integer stroke width)
	if sweep_t > 0.0:
		var u: float = 1.0 - clampf(sweep_t / SWEEP_DUR, 0.0, 1.0)
		var r_sw: float = roundf(lerpf(10.0, 30.0, u))
		var sw_a: float = (1.0 - u) * (0.48 if fred else 0.85)
		draw_arc(Vector2.ZERO, r_sw, 0.0, TAU, 18, Color(rim_c, sw_a), 1.0 if fred else 2.0)
	_draw_signal_pulses()
