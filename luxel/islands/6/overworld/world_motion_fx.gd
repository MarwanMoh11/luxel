class_name LxIsland6MotionFx
extends Node2D
## Live animated train & giant movement on Island 6 overworld districts (zero waiting tax):
## - On `overworld`: immediate first-arrival spectacle right inside Wick's landing viewport
##   (elevated trestle Express streaking with golden headlight + cinder trail, colossal giant
##   walking shadow & distant furnace silhouette striding across the lava caldera, plus the
##   north viaduct Express and southern caldera Colossus as you explore).
## - On `ow_rail_yard`, `ow_giant_stride`, `ow_slag_basin`, `ow_cinder_overlook`:
##   high-craft animated arrival/departure of the Ember Express (spinning brass wheels,
##   boiler firebox, steam plume, headlight cone, brake sparks) & Iron Colossus (riveted
##   plating, pulsing furnace rib-slits, stomp shockwave ring & dust burst).
## - On `island_6_relit` / `great_lamp_6`: warm amber dawn motes & peaceful golden glow.
## Strictly uses LxPalette.PAL (20 colours) and respects LxHudFx.flash_reduced().

const PAL: Dictionary = LxPalette.PAL
const ARRIVE_DUR: float = 1.20

var region_id: String = ""
var _clock: float = 0.0
var _shift: String = "station_a"
var _prev_shift: String = "station_a"
var _anim_t: float = 0.0
var _relit: bool = false
var _bounds: Rect2 = Rect2(0, 0, 768, 512)
var _puffs: Array[Dictionary] = []
var _puff_cd: float = 0.0
var _stomp_ring_t: float = 0.0
var _stomp_center: Vector2 = Vector2.ZERO
var _arrival_whistle_done: bool = false


func setup(p_region_id: String, p_bounds: Rect2, p_shift: String, p_relit: bool) -> void:
	region_id = p_region_id
	_bounds = p_bounds if p_bounds.has_area() else Rect2(0, 0, 768, 512)
	_shift = p_shift
	_prev_shift = p_shift
	_relit = p_relit
	_anim_t = 0.0
	_stomp_ring_t = 0.0
	_arrival_whistle_done = false
	_puffs.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	z_index = 3
	queue_redraw()


func trigger_shift(new_shift: String) -> void:
	if new_shift == _shift:
		return
	_prev_shift = _shift
	_shift = new_shift
	_anim_t = ARRIVE_DUR
	_spawn_shift_burst()
	_arm_stomp_ring()
	queue_redraw()


func set_relit(v: bool) -> void:
	if _relit != v:
		_relit = v
		queue_redraw()


func _arm_stomp_ring() -> void:
	if region_id == "ow_giant_stride" and _shift == "station_b":
		_stomp_center = Vector2(416.0, 404.0)
		_stomp_ring_t = 0.85
	elif region_id == "ow_rail_yard" and _shift == "station_c":
		_stomp_center = Vector2(536.0, 128.0)
		_stomp_ring_t = 0.85
	elif region_id == "ow_slag_basin" and _shift == "station_a":
		_stomp_center = Vector2(176.0, 340.0)
		_stomp_ring_t = 0.85


func _process(dt: float) -> void:
	var step: float = clampf(dt, 0.0, 0.08)
	_clock += step
	if _anim_t > 0.0:
		var was_falling: bool = _anim_t > 0.25
		_anim_t = maxf(0.0, _anim_t - step)
		if was_falling and _anim_t <= 0.25 and _stomp_ring_t > 0.0 and Lx.events != null:
			Lx.events.sfx_requested.emit("colossus_step", _stomp_center, true)
			Lx.events.shake_requested.emit(0.06 if LxHudFx.flash_reduced() else 0.14)
	if _stomp_ring_t > 0.0:
		_stomp_ring_t = maxf(0.0, _stomp_ring_t - step)
	if region_id == "overworld" and not _arrival_whistle_done and _clock >= 1.15:
		_arrival_whistle_done = true
		if Lx.events != null and not _relit:
			Lx.events.sfx_requested.emit("colossus_step", Vector2(220.0, 320.0), false)
	_tick_puffs(step)
	_puff_cd -= step
	if _puff_cd <= 0.0:
		_puff_cd = 0.40 if LxHudFx.flash_reduced() else 0.22
		_emit_ambient_puffs()
	queue_redraw()


func _tick_puffs(dt: float) -> void:
	for i: int in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p["t"] = float(p["t"]) - dt
		if float(p["t"]) <= 0.0:
			_puffs.remove_at(i)
			continue
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt


func _add_puff(at: Vector2, vel: Vector2, dur: float, col: String, rad: float = 2.0) -> void:
	if _puffs.size() >= 44:
		return
	_puffs.append({"pos": at, "vel": vel, "t": dur, "dur": dur, "col": col, "rad": rad})


func _spawn_shift_burst() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var n: int = 5 if fred else 11
	match region_id:
		"ow_rail_yard":
			if _shift == "station_a" or _prev_shift == "station_a":
				for i: int in range(n):
					_add_puff(Vector2(150.0 + float(i) * 24.0, 114.0), Vector2(-18.0, -18.0 - float(i % 3) * 6.0), 0.85, "cream" if i % 2 == 0 else "apricot", 3.0)
			if _shift == "station_c" or _prev_shift == "station_c":
				for i: int in range(n):
					_add_puff(Vector2(506.0 + float(i % 4) * 20.0, 128.0), Vector2((float(i % 4) - 1.5) * 10.0, -14.0), 0.90, "gold" if i % 2 == 0 else "coral", 3.5)
		"ow_giant_stride":
			if _shift == "station_b" or _prev_shift == "station_b":
				for i: int in range(n):
					_add_puff(Vector2(308.0 + float(i) * 20.0, 412.0), Vector2((float(i) - 5.0) * 9.0, -18.0), 0.95, "coral" if i % 2 == 0 else "gold", 3.5)
		"ow_slag_basin":
			if _shift == "station_a" or _prev_shift == "station_a":
				for i: int in range(n):
					_add_puff(Vector2(138.0 + float(i % 4) * 20.0, 344.0), Vector2((float(i % 4) - 1.5) * 8.0, -14.0), 0.85, "coral" if i % 2 == 0 else "apricot", 3.0)
			if _shift == "station_c" or _prev_shift == "station_c":
				for i: int in range(n):
					_add_puff(Vector2(540.0 + float(i % 4) * 20.0, 224.0), Vector2(-14.0, -18.0), 0.80, "cream" if i % 2 == 0 else "gold", 3.0)
		"ow_cinder_overlook":
			if _shift == "station_b" or _prev_shift == "station_b":
				for i: int in range(n):
					_add_puff(Vector2(552.0 + float(i % 4) * 18.0, 192.0), Vector2(-12.0, -16.0), 0.80, "cream" if i % 2 == 0 else "gold", 3.0)


func _emit_ambient_puffs() -> void:
	match region_id:
		"overworld":
			var tx: float = fposmod(_clock * (40.0 if _relit else 68.0) + 265.0, _bounds.size.x + 220.0) - 110.0
			_add_puff(Vector2(tx + 16.0, 202.0), Vector2(-16.0, -10.0), 0.65, "cream" if _relit else "apricot", 2.0)
		"ow_rail_yard":
			if _shift == "station_a":
				_add_puff(Vector2(344.0, 96.0), Vector2(-14.0, -18.0), 0.90, "cream", 2.5)
				_add_puff(Vector2(246.0, 122.0), Vector2(-8.0, -10.0), 0.60, "gold", 1.5)
			elif _shift == "station_c":
				_add_puff(Vector2(536.0, 112.0), Vector2(4.0, -12.0), 0.75, "apricot", 2.0)
		"ow_giant_stride":
			if _shift == "station_b":
				_add_puff(Vector2(376.0, 376.0), Vector2(-4.0, -16.0), 0.95, "coral", 2.5)
				_add_puff(Vector2(456.0, 376.0), Vector2(4.0, -16.0), 0.95, "apricot", 2.5)
		"ow_slag_basin":
			if _shift == "station_a":
				_add_puff(Vector2(168.0, 336.0), Vector2(2.0, -12.0), 0.80, "coral", 2.0)
			elif _shift == "station_c":
				_add_puff(Vector2(568.0, 200.0), Vector2(-10.0, -16.0), 0.80, "cream", 2.0)
		"ow_cinder_overlook":
			if _shift == "station_b":
				_add_puff(Vector2(592.0, 180.0), Vector2(-12.0, -16.0), 0.80, "cream", 2.0)


func _draw() -> void:
	var u: float = 1.0 - clampf(_anim_t / ARRIVE_DUR, 0.0, 1.0)
	var ease_u: float = 1.0 - pow(1.0 - u, 3.0)
	match region_id:
		"overworld":
			_draw_overworld_horizon()
		"ow_rail_yard":
			_draw_rail_yard_motion(ease_u)
		"ow_giant_stride":
			_draw_giant_stride_motion(ease_u)
		"ow_slag_basin":
			_draw_slag_basin_motion(ease_u)
		"ow_cinder_overlook":
			_draw_cinder_overlook_motion(ease_u)
	_draw_stomp_ring()
	_draw_puffs()
	if _relit:
		_draw_relit_embers()


func _draw_overworld_horizon() -> void:
	var spd: float = 40.0 if _relit else 68.0
	# 1. Opening-vista elevated viaduct Express (y=204: centered right in Wick's landing frame on frame 0!)
	var open_tx: float = fposmod(_clock * spd + 265.0, _bounds.size.x + 220.0) - 110.0
	var open_ty: float = 204.0
	draw_line(Vector2(24.0, open_ty + 8.0), Vector2(360.0, open_ty + 8.0), Color(PAL["dusk"] as Color, 0.55), 1.0)
	_draw_mini_train(Vector2(roundf(open_tx), open_ty), _relit, 0.88)

	# 2. Colossal striding shadow sweeping across the arrival caldera floor (y=326, visible from spawn!)
	var sh_x: float = 176.0 + sin(_clock * 0.95) * 44.0
	var sh_bob: float = absf(sin(_clock * 1.9)) * 3.0
	var sh_a: float = 0.20 if LxHudFx.flash_reduced() else 0.32
	draw_rect(Rect2(roundf(sh_x - 22.0), roundf(328.0 - sh_bob), 44.0, 14.0), Color(PAL["void"] as Color, sh_a))
	draw_rect(Rect2(roundf(sh_x - 16.0), roundf(316.0 - sh_bob), 32.0, 12.0), Color(PAL["void"] as Color, sh_a * 0.8))
	draw_rect(Rect2(roundf(sh_x - 7.0), roundf(322.0 - sh_bob), 14.0, 2.0), Color(PAL["gold"] as Color if _relit else PAL["coral"] as Color, sh_a * 1.5))

	# 3. Northern viaduct Ember Express (y=20)
	var tx: float = fposmod(_clock * spd + 140.0, _bounds.size.x + 180.0) - 90.0
	var ty: float = 20.0
	draw_line(Vector2(192.0, ty + 8.0), Vector2(1380.0, ty + 8.0), PAL["dusk"] as Color, 1.0)
	_draw_mini_train(Vector2(roundf(tx), ty), _relit, 1.0)

	# 4. Southern caldera Iron Colossus (y=522)
	var col_target_x: float = 840.0 if _shift == "station_a" else (560.0 if _shift == "station_b" else 380.0)
	var stride_sway: float = sin(_clock * 1.15) * (12.0 if _relit else 26.0)
	var step_bob: float = absf(sin(_clock * 2.3)) * (1.5 if _relit else 3.5)
	_draw_distant_colossus(Vector2(roundf(col_target_x + stride_sway), roundf(522.0 - step_bob)), _clock, _relit)


func _draw_mini_train(p: Vector2, warm: bool, alpha: float = 1.0) -> void:
	var body_c: Color = Color(PAL["plum"] as Color if warm else PAL["night"] as Color, alpha)
	var win_c: Color = Color(PAL["cream"] as Color if warm else PAL["gold"] as Color, alpha)
	var trim_c: Color = Color(PAL["gold"] as Color if warm else PAL["apricot"] as Color, alpha)
	var void_c: Color = Color(PAL["void"] as Color, alpha)
	for i: int in range(3):
		var cx: float = p.x - float(i + 1) * 26.0
		draw_rect(Rect2(cx, p.y + 1.0, 22.0, 7.0), void_c)
		draw_rect(Rect2(cx + 1.0, p.y + 2.0, 20.0, 5.0), body_c)
		draw_rect(Rect2(cx + 4.0, p.y + 3.0, 3.0, 2.0), win_c)
		draw_rect(Rect2(cx + 10.0, p.y + 3.0, 3.0, 2.0), win_c)
		draw_rect(Rect2(cx + 16.0, p.y + 3.0, 3.0, 2.0), win_c)
		# Coupling bar between carriages
		draw_rect(Rect2(cx + 22.0, p.y + 4.0, 4.0, 2.0), Color(PAL["stone"] as Color, alpha))
	draw_rect(Rect2(p.x, p.y - 1.0, 24.0, 9.0), void_c)
	draw_rect(Rect2(p.x + 1.0, p.y, 22.0, 7.0), Color(PAL["wine"] as Color, alpha))
	draw_rect(Rect2(p.x + 16.0, p.y - 4.0, 4.0, 4.0), Color(PAL["dusk"] as Color, alpha))
	draw_rect(Rect2(p.x + 4.0, p.y + 1.0, 5.0, 3.0), win_c)
	draw_rect(Rect2(p.x + 22.0, p.y + 2.0, 3.0, 3.0), trim_c)
	draw_colored_polygon(
		PackedVector2Array([Vector2(p.x + 25.0, p.y + 2.0), Vector2(p.x + 60.0, p.y - 5.0), Vector2(p.x + 60.0, p.y + 11.0)]),
		Color(PAL["gold"] as Color if warm else PAL["apricot"] as Color, (0.18 if LxHudFx.flash_reduced() else 0.34) * alpha)
	)


func _draw_distant_colossus(p: Vector2, t: float, calm: bool) -> void:
	var hull: Color = PAL["dusk"] as Color
	var dark: Color = PAL["night"] as Color
	var eye: Color = PAL["gold"] as Color if calm else PAL["coral"] as Color
	var leg_l: float = roundf(sin(t * 2.3) * (1.0 if calm else 3.0))
	var leg_r: float = -leg_l
	draw_rect(Rect2(p.x - 10.0, p.y + 4.0 + leg_l, 7.0, 12.0), dark)
	draw_rect(Rect2(p.x + 3.0, p.y + 4.0 + leg_r, 7.0, 12.0), dark)
	draw_rect(Rect2(p.x - 14.0, p.y - 12.0, 28.0, 18.0), PAL["void"] as Color)
	draw_rect(Rect2(p.x - 13.0, p.y - 11.0, 26.0, 16.0), hull)
	draw_rect(Rect2(p.x - 8.0, p.y - 17.0, 16.0, 7.0), hull)
	for ry: int in range(3):
		draw_rect(Rect2(p.x - 6.0, p.y - 7.0 + float(ry * 4), 12.0, 2.0), eye)
	draw_rect(Rect2(p.x - 5.0, p.y - 15.0, 3.0, 2.0), PAL["cream"] as Color)
	draw_rect(Rect2(p.x + 2.0, p.y - 15.0, 3.0, 2.0), PAL["cream"] as Color)


func _draw_rail_yard_motion(ease_u: float) -> void:
	if _shift == "station_a":
		var slide_x: float = roundf(lerpf(-260.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(128.0 + slide_x, 112.0), 240.0, true, _anim_t > 0.0)
		# Glowing boarding archway beacon over Track 1 door when docked
		if _anim_t <= 0.05:
			var bp: float = 0.85 if LxHudFx.flash_reduced() else (0.55 + 0.45 * sin(_clock * 4.2))
			draw_rect(Rect2(236.0, 44.0, 24.0, 3.0), Color(PAL["gold"] as Color, bp))
			draw_rect(Rect2(244.0, 40.0, 8.0, 3.0), Color(PAL["cream"] as Color, bp))
	elif _anim_t > 0.0 and _prev_shift == "station_a":
		var depart_x: float = roundf(lerpf(0.0, 360.0, ease_u))
		_draw_express_live_fx(Vector2(128.0 + depart_x, 112.0), 240.0, true, true)
	if _shift == "station_c":
		var drop_y: float = roundf(lerpf(-76.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(496.0, 96.0 + drop_y, 80.0, 64.0), _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_c":
		var lift_y: float = roundf(lerpf(0.0, -76.0, ease_u))
		_draw_colossus_limb_fx(Rect2(496.0, 96.0 + lift_y, 80.0, 64.0), true)


func _draw_giant_stride_motion(ease_u: float) -> void:
	if _shift == "station_b":
		var drop_y: float = roundf(lerpf(-92.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(352.0, 368.0 + drop_y, 128.0, 64.0), _anim_t > 0.0)
		# Ankle hatch beacon pulse inviting Wick inside
		var pulse: float = 0.85 if LxHudFx.flash_reduced() else (0.55 + 0.45 * sin(_clock * 4.0))
		draw_rect(Rect2(406.0, 398.0 + drop_y, 20.0, 8.0), Color(PAL["gold"] as Color, pulse * 0.85))
		draw_rect(Rect2(410.0, 400.0 + drop_y, 12.0, 4.0), Color(PAL["cream"] as Color, pulse))
	elif _anim_t > 0.0 and _prev_shift == "station_b":
		var lift_y: float = roundf(lerpf(0.0, -92.0, ease_u))
		_draw_colossus_limb_fx(Rect2(352.0, 368.0 + lift_y, 128.0, 64.0), true)


func _draw_slag_basin_motion(ease_u: float) -> void:
	if _shift == "station_a":
		var drop_y: float = roundf(lerpf(-68.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(128.0, 312.0 + drop_y, 96.0, 56.0), _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_a":
		var lift_y: float = roundf(lerpf(0.0, -68.0, ease_u))
		_draw_colossus_limb_fx(Rect2(128.0, 312.0 + lift_y, 96.0, 56.0), true)
	if _shift == "station_c":
		var slide_y: float = roundf(lerpf(-140.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(496.0, 192.0 + slide_y), 120.0, false, _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_c":
		var out_y: float = roundf(lerpf(0.0, 160.0, ease_u))
		_draw_express_live_fx(Vector2(496.0, 192.0 + out_y), 120.0, false, true)


func _draw_cinder_overlook_motion(ease_u: float) -> void:
	if _shift == "station_b":
		var slide_y: float = roundf(lerpf(-128.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(496.0, 184.0 + slide_y), 136.0, true, _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_b":
		var out_y: float = roundf(lerpf(0.0, 140.0, ease_u))
		_draw_express_live_fx(Vector2(496.0, 184.0 + out_y), 136.0, true, true)


func _draw_express_live_fx(origin: Vector2, length_px: float, facing_east: bool, moving: bool) -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var pulse: float = 0.85 if fred else (0.65 + 0.35 * sin(_clock * 5.0))
	var head_x: float = roundf(origin.x + (length_px if facing_east else 0.0))
	var dir_x: float = 1.0 if facing_east else -1.0
	if moving:
		draw_rect(Rect2(origin.x - 2.0, origin.y - 11.0, length_px + 4.0, 28.0), Color(PAL["void"] as Color, 0.88))
		draw_rect(Rect2(origin.x, origin.y - 9.0, length_px, 24.0), PAL["wine"] as Color)
		draw_rect(Rect2(origin.x + 2.0, origin.y - 7.0, length_px - 4.0, 3.0), PAL["apricot"] as Color)
		draw_rect(Rect2(origin.x + 2.0, origin.y + 11.0, length_px - 4.0, 2.0), PAL["gold"] as Color)
		var wx: float = origin.x + 12.0
		while wx < origin.x + length_px - 18.0:
			draw_rect(Rect2(roundf(wx), origin.y - 2.0, 10.0, 7.0), PAL["gold"] as Color)
			draw_rect(Rect2(roundf(wx) + 2.0, origin.y, 6.0, 3.0), PAL["cream"] as Color)
			wx += 22.0
		# Brass drive-wheels + pumping coupling rod
		var rod_off: float = 0.0 if fred else roundf(sin(_clock * 22.0) * 3.0)
		var whx: float = origin.x + 16.0
		while whx < origin.x + length_px - 14.0:
			draw_circle(Vector2(roundf(whx), origin.y + 15.0), 4.0, PAL["dusk"] as Color)
			draw_rect(Rect2(roundf(whx) - 1.0, origin.y + 14.0, 2.0, 2.0), PAL["gold"] as Color)
			whx += 28.0
		draw_line(Vector2(roundf(origin.x + 16.0 + rod_off), origin.y + 15.0), Vector2(roundf(origin.x + length_px - 20.0 + rod_off), origin.y + 15.0), PAL["cream"] as Color, 1.2)
	# Glowing firebox embers beneath boiler & headlight cone (always alive while docked!)
	var fx_x: float = roundf(origin.x + length_px * 0.55)
	draw_rect(Rect2(fx_x - 10.0, origin.y + 10.0, 20.0, 3.0), Color(PAL["coral"] as Color, 0.55 * pulse))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(head_x, origin.y),
			Vector2(head_x + dir_x * 48.0, origin.y - 14.0),
			Vector2(head_x + dir_x * 48.0, origin.y + 16.0),
		]),
		Color(PAL["gold"] as Color, (0.16 if fred else 0.28) * pulse)
	)
	draw_rect(Rect2(head_x - 2.0, origin.y - 3.0, 5.0, 6.0), PAL["cream"] as Color)


func _draw_colossus_limb_fx(r: Rect2, moving: bool) -> void:
	var pulse: float = 0.82 if LxHudFx.flash_reduced() else (0.55 + 0.45 * sin(_clock * 2.6))
	var slit_c: Color = PAL["gold"] as Color if _relit else PAL["coral"] as Color
	if moving:
		draw_rect(r.grow(2.0), Color(PAL["void"] as Color, 0.86))
		draw_rect(r, PAL["dusk"] as Color)
		draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 5.0), PAL["stone"] as Color)
		draw_rect(Rect2(r.position.x + 2.0, r.end.y - 6.0, r.size.x - 4.0, 4.0), PAL["night"] as Color)
	# Pulsing furnace rib-slits + brass rivets along the Colossus's armor plating
	var gx: float = r.position.x + 12.0
	var sy: float = roundf(r.position.y + r.size.y * 0.34)
	while gx < r.end.x - 16.0:
		draw_rect(Rect2(roundf(gx), sy, 12.0, 4.0), Color(slit_c, pulse))
		draw_rect(Rect2(roundf(gx) + 2.0, sy + 1.0, 8.0, 2.0), Color(PAL["cream"] as Color, pulse * 0.85))
		draw_rect(Rect2(roundf(gx) + 4.0, r.position.y + 5.0, 2.0, 2.0), Color(PAL["gold"] as Color, 0.7))
		gx += 24.0


func _draw_stomp_ring() -> void:
	if _stomp_ring_t <= 0.0:
		return
	var u: float = 1.0 - clampf(_stomp_ring_t / 0.85, 0.0, 1.0)
	var rad: float = roundf(lerpf(14.0, 74.0, u))
	var alpha: float = (1.0 - u) * (0.45 if LxHudFx.flash_reduced() else 0.80)
	draw_arc(_stomp_center, rad, 0.0, TAU, 24, Color(PAL["gold"] as Color, alpha), 2.0)
	draw_arc(_stomp_center, maxf(4.0, rad - 8.0), 0.0, TAU, 20, Color(PAL["coral"] as Color, alpha * 0.7), 1.2)


func _draw_puffs() -> void:
	for p: Dictionary in _puffs:
		var u: float = clampf(float(p["t"]) / maxf(0.05, float(p["dur"])), 0.0, 1.0)
		var pos: Vector2 = (p["pos"] as Vector2).round()
		var rad: float = maxf(1.0, roundf(float(p["rad"]) * (1.3 - u * 0.5)))
		var col: Color = PAL.get(str(p["col"]), PAL["cream"]) as Color
		draw_rect(Rect2(pos.x - rad, pos.y - rad, rad * 2.0, rad * 2.0), Color(col, u * 0.72))


func _draw_relit_embers() -> void:
	var cnt: int = 10 if LxHudFx.flash_reduced() else 18
	for i: int in range(cnt):
		var ex: float = fposmod(float(i * 97 + 41) + sin(_clock * 0.8 + float(i)) * 8.0, _bounds.size.x)
		var ey: float = fposmod(float(i * 73 + 29) - _clock * (12.0 + float(i % 4) * 3.0), _bounds.size.y)
		var c: Color = PAL["gold"] as Color if i % 2 == 0 else PAL["cream"] as Color
		draw_rect(Rect2(roundf(ex), roundf(ey), 2.0, 2.0), Color(c, 0.55))
