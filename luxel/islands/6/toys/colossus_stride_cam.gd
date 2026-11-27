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
var _plant_fx_t: float = 0.0


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
	if _plant_fx_t > 0.0:
		_plant_fx_t = maxf(0.0, _plant_fx_t - dt)
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
			_plant_fx_t = 0.55
			_emit_sfx("colossus_step")
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
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var calm: bool = state == StrideState.STABILIZED
	var fred: bool = LxHudFx.flash_reduced()

	# Grounded shadow beneath clockwork housing
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 10.0), 13.0, 4.0)

	# Heavy iron mounting feet
	draw_rect(Rect2(-11.0, 7.0, 6.0, 4.0), c_void)
	draw_rect(Rect2(-10.0, 8.0, 4.0, 2.0), c_dusk)
	draw_rect(Rect2(5.0, 7.0, 6.0, 4.0), c_void)
	draw_rect(Rect2(6.0, 8.0, 4.0, 2.0), c_dusk)

	# Heavy riveted clockwork iron housing with sunlit top bevel
	var frame := Rect2(-12.0, -10.0, 24.0, 19.0)
	var warn_flash: bool = is_warning and (fred or fmod(_clock, 0.24) < 0.12)
	var top_bevel: Color = c_ice if calm else (c_cream if warn_flash else c_stone)
	LxPhysDraw.draw_bevel_box(self, frame, c_dusk, top_bevel, c_night, c_void, c_gold if not calm else c_sky)
	# Crisp sunlit steel crown bevel & extra side rivets
	draw_rect(Rect2(-10.0, -9.0, 20.0, 1.0), c_ice if calm else (c_cream if warn_flash else c_ice))
	draw_rect(Rect2(-10.0, -8.0, 20.0, 1.0), c_stone)
	for rv: Vector2 in [Vector2(-10.0, 0.0), Vector2(9.0, 0.0), Vector2(-10.0, 6.0), Vector2(9.0, 6.0)]:
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), c_apr if not calm else c_stone)

	# Recessed clockwork gear chamber + warm forge-ember active glow
	draw_rect(Rect2(-8.0, -6.0, 16.0, 12.0), c_void)
	var ember_bg: Color = c_deep if calm else (c_coral if (warn_flash or _plant_fx_t > 0.0) else c_wine)
	draw_rect(Rect2(-7.0, -5.0, 14.0, 10.0), c_night)
	draw_rect(Rect2(-6.0, -4.0, 12.0, 8.0), Color(ember_bg, 0.55 if calm else (0.72 if fred else 0.65 + 0.20 * step_progress)))
	# Lower furnace ember grate glow inside chamber
	if not calm:
		draw_rect(Rect2(-5.0, 3.0, 10.0, 1.0), c_coral)
		draw_rect(Rect2(-3.0, 3.0, 6.0, 1.0), c_apr if not is_warning else c_gold)

	# Visible rotating eccentric brass cam gear inside the window
	var cam_center := Vector2(0.0, -1.0)
	var cam_ang: float = 0.0 if calm else ((_stride_t / maxf(step_period, 0.5)) * TAU)
	var gear_rim: Color = c_sky if calm else (c_cream if warn_flash else c_gold)
	var gear_body: Color = c_ice if calm else c_apr
	# 8 rotating brass gear teeth around the cam wheel
	for ti: int in range(8):
		var ta: float = cam_ang + float(ti) * (TAU / 8.0)
		var tp := Vector2(roundf(cam_center.x + cos(ta) * 5.0), roundf(cam_center.y + sin(ta) * 4.5))
		draw_rect(Rect2(tp - Vector2.ONE, Vector2(2.0, 2.0)), gear_rim)
	# Cam wheel face + dark axle recess
	draw_circle(cam_center, 4.0, c_void)
	draw_circle(cam_center, 3.0, gear_body)
	draw_rect(Rect2(cam_center.x - 2.0, cam_center.y - 2.0, 3.0, 1.0), c_cream if not calm else c_ice)
	# Eccentric cam lobe bob extending toward current stride side
	var lobe_dir := Vector2(sin(cam_ang) * 3.0, cos(cam_ang) * 2.5) if not calm else Vector2(0.0, 1.0)
	var lobe_p: Vector2 = (cam_center + lobe_dir).round()
	draw_rect(Rect2(lobe_p - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
	draw_rect(Rect2(lobe_p, Vector2(1.0, 1.0)), c_ice if calm else (c_coral if is_warning else c_cream))
	draw_rect(Rect2(cam_center, Vector2(1.0, 1.0)), c_void)

	# L / R step indicator lamps on upper iron shoulders
	var l_lit: bool = not calm and stride_side < 0
	var r_lit: bool = not calm and stride_side > 0
	draw_rect(Rect2(-10.0, -6.0, 2.0, 3.0), c_void)
	draw_rect(Rect2(-10.0, -5.0, 2.0, 2.0), c_gold if l_lit else c_night)
	if l_lit:
		draw_rect(Rect2(-10.0, -5.0, 1.0, 1.0), c_cream)
	draw_rect(Rect2(8.0, -6.0, 2.0, 3.0), c_void)
	draw_rect(Rect2(8.0, -5.0, 2.0, 2.0), c_gold if r_lit else c_night)
	if r_lit:
		draw_rect(Rect2(8.0, -5.0, 1.0, 1.0), c_cream)

	# Bottom status crest: calm lock bar or directional stride chevron
	if calm:
		draw_rect(Rect2(-3.0, 6.0, 6.0, 2.0), c_void)
		draw_rect(Rect2(-2.0, 6.0, 4.0, 1.0), c_ice)
	elif is_warning:
		LxPhysDraw.draw_chevron(self, Vector2(float(next_side) * 5.0, 6.0), Vector2(float(next_side), 0.0), c_cream, c_void, 2.0)
	else:
		LxPhysDraw.draw_chevron(self, Vector2(float(stride_side) * 5.0, 6.0), Vector2(float(stride_side), 0.0), c_gold, c_void, 2.0)

	# Room-wide diegetic footstep shockwave & tilt-direction dust sweep (makes every step felt!)
	if not calm:
		var bounds: Rect2 = region.get("bounds") as Rect2 if (region != null and region.get("bounds") is Rect2) else Rect2(0, 0, 448, 288)
		var local_tl: Vector2 = bounds.position - pos
		var dir_x: float = float(next_side if is_warning else stride_side)
		if _plant_fx_t > 0.0:
			var pu: float = 1.0 - clampf(_plant_fx_t / 0.55, 0.0, 1.0)
			var ra: float = (1.0 - pu) * (0.35 if fred else 0.72)
			draw_arc(Vector2.ZERO, roundf(lerpf(10.0, 52.0, pu)), 0.0, TAU, 18, Color(c_gold, ra), 2.0)
			# Downhill edge furnace pulse strip
			var edge_x: float = (local_tl.x + bounds.size.x - 10.0) if stride_side > 0 else (local_tl.x + 6.0)
			draw_rect(Rect2(roundf(edge_x), local_tl.y + 18.0, 4.0, maxf(24.0, bounds.size.y - 36.0)), Color(c_coral, ra * 0.75))
		elif is_warning:
			var wa: float = 0.28 if fred else (0.35 + 0.30 * absf(sin(_clock * 14.0)))
			var warn_x: float = (local_tl.x + bounds.size.x - 14.0) if next_side > 0 else (local_tl.x + 10.0)
			draw_rect(Rect2(roundf(warn_x), local_tl.y + 24.0, 3.0, maxf(24.0, bounds.size.y - 48.0)), Color(c_cream, wa))
		# Subtle sliding brass dust motes drifting across the floor in the active tilt direction
		if not fred:
			var m_cnt: int = 8
			for i: int in range(m_cnt):
				var span_x: float = maxf(64.0, bounds.size.x - 48.0)
				var mx: float = local_tl.x + 24.0 + fposmod(float(i * 61) + _clock * 46.0 * dir_x, span_x)
				var my: float = local_tl.y + 32.0 + fmod(float(i * 43 + 17), maxf(32.0, bounds.size.y - 64.0))
				draw_rect(Rect2(roundf(mx), roundf(my), 3.0 if is_warning else 4.0, 1.0), Color(c_cream if is_warning else c_gold, 0.38))
