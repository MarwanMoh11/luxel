class_name LxLevWaveChaser
extends LxToy
## Leviathan's Storm Bow-Wave Chaser (`lev_wave_chaser`, `leviathan_r1`):
## Sweeps east across the flooded rooftops after a fair grace window, pressuring Wick's
## Skiff sprint; resets instantly (< 0.3s) to the room anchor if the wave overtakes Wick,
## and halts cleanly once Wick crosses `safe_x` or triggers the end switch.

var start_x: float = 36.0
var stop_x: float = 616.0
var safe_x: float = 592.0
var speed: float = 42.0
var grace_s: float = 3.2
var band_h: float = 224.0

var wave_x: float = 36.0
var halted: bool = false
var _elapsed: float = 0.0
var _splash_t: float = 0.0
var _rumble_cd: float = 0.0


func _toy_setup() -> void:
	kind = "lev_wave_chaser"
	z_index = 3
	radius = 16.0
	start_x = float(props.get("start_x", pos.x))
	stop_x = float(props.get("stop_x", 616.0))
	safe_x = float(props.get("safe_x", 592.0))
	speed = maxf(16.0, float(props.get("speed", 42.0)))
	grace_s = maxf(0.5, float(props.get("grace_s", 3.2)))
	band_h = maxf(64.0, float(props.get("band_h", 224.0)))
	wave_x = start_x
	halted = false
	_elapsed = 0.0
	_splash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	wave_x = start_x
	halted = false
	_elapsed = 0.0
	_splash_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_signal(_from_id: String, is_on: bool) -> void:
	if is_on:
		halted = true
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _splash_t > 0.0:
		_splash_t = maxf(0.0, _splash_t - dt)
	if halted:
		queue_redraw()
		return
	_elapsed += dt
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.dead:
			wave_x = start_x
			_elapsed = 0.0
			queue_redraw()
			return
		if w.global_position.x >= safe_x:
			halted = true
			queue_redraw()
			return
		if _elapsed >= grace_s and wave_x < stop_x:
			wave_x = minf(stop_x, wave_x + speed * dt)
			_rumble_cd = maxf(0.0, _rumble_cd - dt)
			if w.global_position.x - wave_x < 108.0 and _rumble_cd <= 0.0:
				_rumble_cd = 0.85
				if Lx.events != null and not LxHudFx.flash_reduced():
					Lx.events.shake_requested.emit(0.09)
				_emit_sfx("water_level_sweep")
			if w.global_position.x < wave_x - 8.0 and w.global_position.x < safe_x:
				_reset_chase_on_catch(w)
	queue_redraw()


func _reset_chase_on_catch(w: LxWick) -> void:
	_splash_t = 0.45
	wave_x = start_x
	_elapsed = 0.0
	_emit_sfx("marsh_splash")
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.18 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	var rst: Vector2 = region.get_room_anchor() if (region != null and region.has_method("get_room_anchor")) else Vector2(start_x + 24.0, pos.y)
	if w.is_mounted():
		var veh: Node = w.get_mounted_vehicle()
		if veh is LxVehicleSkiff:
			(veh as LxVehicleSkiff).recall_to_dock(rst)
	w.global_position = rst
	w.last_pos = rst


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(wave_x, pos.y, 48.0, 0.48)


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var lx: float = roundf(wave_x - pos.x)
	var half_h: float = floorf(band_h * 0.5)
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	# Towering storm swell behind wave_x
	draw_rect(Rect2(lx - 38.0, -half_h, 30.0, band_h), Color(PAL["void"] as Color, 0.55))
	draw_rect(Rect2(lx - 26.0, -half_h, 20.0, band_h), Color(c_deep, 0.78))
	draw_rect(Rect2(lx - 10.0, -half_h, 8.0, band_h), Color(c_blue, 0.88))
	draw_rect(Rect2(lx - 4.0, -half_h, 4.0, band_h), c_sky)
	draw_rect(Rect2(lx - 1.0, -half_h, 2.0, band_h), c_ice)
	# Looming Leviathan dorsal ridge & glowing amber eye surging behind the wave wall
	var fin_y: float = 0.0 if (red or halted) else roundf(sin(_clock * 3.2) * 10.0)
	draw_rect(Rect2(lx - 32.0, fin_y - 26.0, 18.0, 52.0), PAL["night"] as Color)
	draw_rect(Rect2(lx - 26.0, fin_y - 18.0, 12.0, 36.0), c_deep)
	if not halted:
		draw_rect(Rect2(lx - 18.0, fin_y - 6.0, 5.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(lx - 17.0, fin_y - 5.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(lx - 14.0, fin_y - 16.0, 2.0, 4.0), c_ice)
		draw_rect(Rect2(lx - 14.0, fin_y + 12.0, 2.0, 4.0), c_ice)
	else:
		# Halted calm closed eye slit (greyscale-distinct from active chase)
		draw_rect(Rect2(lx - 18.0, fin_y - 4.0, 5.0, 1.0), PAL["stone"] as Color)
	# Foaming scalloped crest pips + leaping storm-spray droplets
	var y: float = -half_h + 6.0
	var idx: int = 0
	while y < half_h - 4.0:
		var wob: float = 0.0 if (red or halted) else roundf(sin(_clock * 7.0 + float(idx) * 1.1) * 2.5)
		draw_rect(Rect2(lx + wob, y, 4.0, 4.0), c_cream if idx % 2 == 0 else c_ice)
		draw_rect(Rect2(lx - 4.0 + wob, y + 4.0, 2.0, 3.0), c_sky)
		if not red and not halted and idx % 2 == 0:
			var sp_x: float = lx + 4.0 + fmod(_clock * 28.0 + float(idx) * 7.0, 14.0)
			draw_rect(Rect2(roundf(sp_x), y + 1.0, 2.0, 1.0), Color(c_cream, 0.75))
		y += 12.0
		idx += 1
	if _splash_t > 0.0:
		var u: float = 1.0 - clampf(_splash_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2(lx, 0.0), roundf(lerpf(10.0, 36.0, u)), 0.0, TAU, 16, Color(c_cream, (1.0 - u) * (0.55 if red else 1.0)), 1.0 if red else 2.0)
