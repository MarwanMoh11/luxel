class_name LxLhPrismTriad
extends LxToy
## Lighthouse Simultaneous Prism-Split Gate (`lh_prism_triad`):
## Requires all `inputs` to trigger within `window_s` seconds (e.g. one 3-way Prism Split fan
## or one 360-degree Catoptric cascade). Sequential shots that exceed `window_s` flash coral
## and reset the switch inputs so players learn simultaneous fan alignment with zero softlock.

var inputs: Array[String] = []
var window_s: float = 0.55
var sets_flag: String = ""
var _hit_times: Dictionary = {}
var _fail_flash_t: float = 0.0
var _solve_flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "lh_prism_triad"
	z_index = -4
	radius = 12.0
	window_s = maxf(0.15, float(props.get("window_s", 0.55)))
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	if not props.has("persist"):
		persist = true
	inputs.clear()
	var raw: Variant = props.get("inputs", [])
	if raw is Array:
		for item: Variant in (raw as Array):
			var sid: String = str(item).strip_edges()
			if not sid.is_empty():
				inputs.append(sid)
	_hit_times.clear()
	_fail_flash_t = 0.0
	_solve_flash_t = 0.0
	if not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false)):
		powered = true
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	_hit_times.clear()
	_fail_flash_t = 0.0
	_solve_flash_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_signal(from_id: String, is_on: bool) -> void:
	if not active or powered:
		return
	if not inputs.is_empty() and not inputs.has(from_id):
		return
	if not is_on:
		_hit_times.erase(from_id)
		queue_redraw()
		return
	_hit_times[from_id] = _clock
	_check_triad_complete()
	queue_redraw()


func _check_triad_complete() -> void:
	if inputs.is_empty():
		return
	var oldest: float = INF
	for sid: String in inputs:
		if not _hit_times.has(sid):
			return
		oldest = minf(oldest, float(_hit_times[sid]))
	if (_clock - oldest) <= window_s:
		_solve_triad()
	else:
		_expire_inputs()


func _solve_triad() -> void:
	_solve_flash_t = 0.55
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("prism_chain")
	_emit_sfx("waystone_lit")
	_emit_gust(64.0, 48.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.10)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 86.0, 1.35, 0.36)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	queue_redraw()


func _expire_inputs() -> void:
	if _hit_times.is_empty():
		return
	_hit_times.clear()
	_fail_flash_t = 0.40
	_emit_sfx("mirror_ping")
	if region != null and region.has_method("find_interactable"):
		for sid: String in inputs:
			var it: LxInteractable = region.call("find_interactable", sid) as LxInteractable
			if it == null or not is_instance_valid(it):
				continue
			if it.has_method("reset_toy"):
				it.call("reset_toy")
			elif it.kind == "switch_eye":
				it.set("activated", false)
				it.set("powered", false)
				it.queue_redraw()
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _fail_flash_t > 0.0:
		_fail_flash_t = maxf(0.0, _fail_flash_t - dt)
		dirty = true
	if _solve_flash_t > 0.0:
		_solve_flash_t = maxf(0.0, _solve_flash_t - dt)
		dirty = true
	if not powered and not _hit_times.is_empty():
		var oldest: float = INF
		for sid: String in _hit_times.keys():
			oldest = minf(oldest, float(_hit_times[sid]))
		if (_clock - oldest) > window_s:
			_expire_inputs()
			dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if powered:
		return Vector4(pos.x, pos.y, 44.0, 0.72)
	if not _hit_times.is_empty():
		return Vector4(pos.x, pos.y, 26.0, 0.42)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["powered"] = powered
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("powered", false)):
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_rim: Color = (PAL["coral"] if _fail_flash_t > 0.0 else (PAL["cream"] if powered else PAL["gold"])) as Color
	var c_core: Color = (PAL["ice"] if powered else (PAL["sky"] if not _hit_times.is_empty() else PAL["deep"])) as Color
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -9.0, 18.0, 18.0), PAL["night"] as Color, c_rim, PAL["dusk"] as Color, c_void)
	# Prism triangle glyph in center
	var tri := PackedVector2Array([Vector2(0.0, -5.0), Vector2(5.0, 4.0), Vector2(-5.0, 4.0)])
	draw_colored_polygon(tri, c_core)
	var tri_c := PackedVector2Array([Vector2(0.0, -5.0), Vector2(5.0, 4.0), Vector2(-5.0, 4.0), Vector2(0.0, -5.0)])
	draw_polyline(tri_c, c_rim, 1.0)
	# Input pips along bottom
	var n: int = mini(4, inputs.size())
	if n > 0:
		var span: float = float(n - 1) * 4.0
		for i: int in range(n):
			var lit_p: bool = powered or _hit_times.has(inputs[i])
			var px: float = roundf(-span * 0.5 + float(i) * 4.0) - 1.0
			draw_rect(Rect2(px, 6.0, 2.0, 2.0), PAL["cream"] as Color if lit_p else PAL["night"] as Color)
	if _solve_flash_t > 0.0:
		var u: float = 1.0 - clampf(_solve_flash_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 22.0, u)), 0.0, TAU, 16, PAL["ice"] as Color, 1.5)
	_draw_signal_pulses()
