class_name LxToyColossusStrideCam
extends LxToy
## Island 6 Iron Colossus Stride Synchronizer (bible section 6.4).
## Drives the walking giant's rhythmic footsteps across colossus_* rooms:
##   LEFT_PLANT -> STEP_WARN (0.75s horn + HUD pendulum blink) -> RIGHT_PLANT -> STEP_WARN -> ...
##   or STABILIZED (calm post-boss when stabilized_flag is set).
## Synchronizes all linked tilt_groups, pulses bellows wind_zones on Right-Step exhale,
## emits screen-shake-safe footstep impacts, and updates the HUD pendulum indicator.
##
## Props:
##   step_period: float (default 6.0s for full L+R cycle; 3.0s per footstep)
##   axis: "x" | "y" (default "x")
##   shake_amp: float (default 0.07)
##   tilt_group_ids: Array[String] (if empty, auto-syncs all tilt_groups in the region)
##   wind_ids: Array[String] (optional wind_zones active on RIGHT_PLANT exhale)
##   stabilized_flag: String (default "colossus_heart_beaten")
##   warn_secs: float (default 0.75)

enum StrideState { LEFT_PLANT, STEP_WARN, RIGHT_PLANT, STABILIZED }

var step_period: float = 6.0
var stride_axis: String = "x"
var shake_amp: float = 0.07
var warn_secs: float = 0.75
var tilt_group_ids: Array[String] = []
var wind_ids: Array[String] = []
var stabilized_flag: String = "colossus_heart_beaten"
var speed_mult: float = 1.0

var state: int = StrideState.LEFT_PLANT
var state_name: String = "LEFT_PLANT"
var stride_side: int = -1 # -1 = LEFT_PLANT, +1 = RIGHT_PLANT
var next_side: int = 1
var is_warning: bool = false
var step_progress: float = 0.0
var step_count: int = 0
var _stride_t: float = 0.0
var _forced_stabilized: bool = false
var _last_plant_side: int = 0


func _toy_setup() -> void:
	kind = "colossus_stride_cam"
	step_period = maxf(2.0, float(props.get("step_period", 6.0)))
	stride_axis = str(props.get("axis", "x")).strip_edges().to_lower()
	if stride_axis not in ["x", "y"]:
		stride_axis = "x"
	shake_amp = clampf(float(props.get("shake_amp", 0.07)), 0.0, 0.35)
	warn_secs = clampf(float(props.get("warn_secs", 0.75)), 0.25, 1.5)
	stabilized_flag = str(props.get("stabilized_flag", "colossus_heart_beaten")).strip_edges()
	tilt_group_ids = _to_str_ids(props.get("tilt_group_ids", []))
	wind_ids = _to_str_ids(props.get("wind_ids", []))
	speed_mult = maxf(0.25, float(props.get("speed_mult", 1.0)))
	_stride_t = maxf(0.0, float(props.get("offset", 0.0)))
	_forced_stabilized = false
	stride_side = -1
	next_side = 1
	is_warning = false
	step_progress = 0.0
	step_count = 0
	_last_plant_side = 0
	size = Vector2(22.0, 18.0)
	radius = 12.0
	z_index = LxPhysDraw.floor_z(region, -3)
	_sync_state(false)
	queue_redraw()


func reset_toy() -> void:
	_stride_t = 0.0
	step_count = 0
	_last_plant_side = 0
	_forced_stabilized = false
	_sync_state(false)
	queue_redraw()


func set_speed_mult(mult: float) -> void:
	speed_mult = clampf(mult, 0.25, 3.0)


func set_stabilized(calm: bool) -> void:
	_forced_stabilized = calm
	_sync_state(false)
	queue_redraw()


func _on_power_changed(is_on: bool) -> void:
	var mode: String = str(props.get("on_signal", "stabilize")).strip_edges().to_lower()
	if mode == "stabilize":
		set_stabilized(is_on)


func is_stabilized() -> bool:
	if _forced_stabilized:
		return true
	if not stabilized_flag.is_empty() and LxRegionLoader.check_flag_static(stabilized_flag):
		return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if is_stabilized():
		_sync_state(false)
		queue_redraw()
		return
	_stride_t += dt * speed_mult
	_sync_state(true)
	queue_redraw()


func _sync_state(emit_fx: bool) -> void:
	if is_stabilized():
		state = StrideState.STABILIZED
		state_name = "STABILIZED"
		is_warning = false
		step_progress = 0.0
		_drive_linked_toys(0, false, true)
		LxIsland6Rule.report_stride_state(0, false, true)
		return

	var half_p: float = maxf(1.0, step_period * 0.5)
	var cycle: float = fposmod(_stride_t, step_period)
	var cur_side: int = -1 if cycle < half_p else 1
	var local_t: float = cycle if cycle < half_p else (cycle - half_p)
	var eff_warn: float = minf(warn_secs, half_p * 0.45)
	var now_warn: bool = local_t >= (half_p - eff_warn)
	var was_warn: bool = is_warning

	stride_side = cur_side
	next_side = -cur_side
	is_warning = now_warn
	step_progress = clampf(local_t / half_p, 0.0, 1.0)

	if now_warn:
		state = StrideState.STEP_WARN
		state_name = "STEP_WARN"
	elif cur_side < 0:
		state = StrideState.LEFT_PLANT
		state_name = "LEFT_PLANT"
	else:
		state = StrideState.RIGHT_PLANT
		state_name = "RIGHT_PLANT"

	if emit_fx:
		if now_warn and not was_warn:
			_emit_sfx("colossus_horn")
		if cur_side != _last_plant_side:
			_last_plant_side = cur_side
			step_count += 1
			_emit_sfx("golem_stomp")
			var amp: float = shake_amp * (0.45 if LxHudFx.flash_reduced() else 1.0)
			if Lx.events != null and amp > 0.001:
				Lx.events.shake_requested.emit(amp)
			if region != null and region.has_method("notify"):
				region.call("notify", "stride_step", {"side": cur_side, "step": step_count, "id": id})

	_drive_linked_toys(cur_side, now_warn, false)
	LxIsland6Rule.report_stride_state(cur_side, now_warn, false)


func _drive_linked_toys(side: int, warn: bool, calm: bool) -> void:
	if region == null or not is_instance_valid(region) or not region.has_method("get_interactables"):
		return
	var axis_vec: Vector2 = Vector2.RIGHT if stride_axis == "x" else Vector2.DOWN
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or not is_instance_valid(it_v as Object):
			continue
		var it: LxInteractable = it_v as LxInteractable
		if it.kind == "tilt_group":
			if tilt_group_ids.is_empty() or tilt_group_ids.has(it.id):
				if it.get("tilt_axis") is Vector2:
					it.set("tilt_axis", axis_vec)
				if it.has_method("set_external_tilt"):
					it.call("set_external_tilt", side, warn, 1.0, calm)
		elif it.kind == "wind_zone" and not wind_ids.is_empty() and wind_ids.has(it.id):
			var exhale_on: bool = (not calm) and side > 0 and not warn
			if it.active != exhale_on:
				it.active = exhale_on
				it.visible = exhale_on
				it.queue_redraw()


static func _to_str_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for v: Variant in (raw as Array):
			var s: String = str(v).strip_edges()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	return out


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var calm: bool = state == StrideState.STABILIZED
	var fred: bool = LxHudFx.flash_reduced()

	# Brass giant-stride pendulum dial (clear greyscale contrast between LEFT, WARN, RIGHT, STABILIZED)
	var frame := Rect2(-11.0, -9.0, 22.0, 18.0)
	var rim: Color = c_ice if calm else (c_cream if (is_warning and (fred or fmod(_clock, 0.24) < 0.12)) else c_gold)
	LxPhysDraw.draw_bevel_box(self, frame, c_night, rim, c_dusk, c_void, c_stone)

	# L / R step markers at dial corners
	draw_rect(Rect2(-9.0, -6.0, 3.0, 3.0), c_gold if (not calm and stride_side < 0) else c_dusk)
	draw_rect(Rect2(6.0, -6.0, 3.0, 3.0), c_gold if (not calm and stride_side > 0) else c_dusk)

	# Swinging plumb line + brass weight bob
	var pivot := Vector2(0.0, -6.0)
	var ang: float = 0.0 if calm else (float(stride_side) * (0.28 if is_warning else 0.65))
	var bob: Vector2 = (pivot + Vector2(sin(ang) * 9.0, cos(ang) * 10.0)).round()
	draw_line(pivot, bob, c_ice if calm else c_stone, 1.0)
	draw_rect(Rect2(bob - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
	draw_rect(Rect2(bob - Vector2.ONE, Vector2(2.0, 2.0)), c_ice if calm else (c_coral if is_warning else c_cream))

	# Warning horn flare or calm center lock
	if calm:
		draw_rect(Rect2(-2.0, 5.0, 4.0, 2.0), c_ice)
	elif is_warning:
		LxPhysDraw.draw_chevron(self, Vector2(float(next_side) * 6.0, 5.0), Vector2(float(next_side), 0.0), c_cream, c_void, 2.0)
	else:
		LxPhysDraw.draw_chevron(self, Vector2(float(stride_side) * 6.0, 5.0), Vector2(float(stride_side), 0.0), c_gold, c_void, 2.0)
