class_name LxIsland6MotionFx
extends Node2D
## Live animated train & giant movement on Island 6 overworld districts (zero waiting tax):
## - On `overworld`: distant Ember Express streaking along the northern viaduct + Iron Colossus
##   striding across the southern caldera horizon (visible in the first 3 minutes!).
## - On `ow_rail_yard`, `ow_giant_stride`, `ow_slag_basin`, `ow_cinder_overlook`:
##   animated arrival/departure of the Ember Express & Iron Colossus whenever `kiln_shift` changes,
##   plus living docked steam puffs, firebox glow, headlight beams, and Colossus furnace-slit pulse.
## - On `island_6_relit` / `great_lamp_6`: warm amber dawn motes & peaceful golden glow.
## Strictly uses LxPalette.PAL (20 colours) and respects LxHudFx.flash_reduced().

const PAL: Dictionary = LxPalette.PAL
const ARRIVE_DUR: float = 1.15

var region_id: String = ""
var _clock: float = 0.0
var _shift: String = "station_a"
var _prev_shift: String = "station_a"
var _anim_t: float = 0.0
var _relit: bool = false
var _bounds: Rect2 = Rect2(0, 0, 768, 512)
var _puffs: Array[Dictionary] = []
var _puff_cd: float = 0.0


func setup(p_region_id: String, p_bounds: Rect2, p_shift: String, p_relit: bool) -> void:
	region_id = p_region_id
	_bounds = p_bounds if p_bounds.has_area() else Rect2(0, 0, 768, 512)
	_shift = p_shift
	_prev_shift = p_shift
	_relit = p_relit
	_anim_t = 0.0
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
	queue_redraw()


func set_relit(v: bool) -> void:
	if _relit != v:
		_relit = v
		queue_redraw()


func _process(dt: float) -> void:
	var step: float = clampf(dt, 0.0, 0.08)
	_clock += step
	if _anim_t > 0.0:
		_anim_t = maxf(0.0, _anim_t - step)
	_tick_puffs(step)
	_puff_cd -= step
	if _puff_cd <= 0.0:
		_puff_cd = 0.42 if LxHudFx.flash_reduced() else 0.24
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
	if _puffs.size() >= 36:
		return
	_puffs.append({"pos": at, "vel": vel, "t": dur, "dur": dur, "col": col, "rad": rad})


func _spawn_shift_burst() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var n: int = 4 if fred else 9
	match region_id:
		"ow_rail_yard":
			if _shift == "station_a" or _prev_shift == "station_a":
				for i: int in range(n):
					_add_puff(Vector2(170.0 + float(i) * 26.0, 108.0), Vector2(-14.0, -18.0 - float(i % 3) * 6.0), 0.75, "cream" if i % 2 == 0 else "apricot", 3.0)
			if _shift == "station_c" or _prev_shift == "station_c":
				for i: int in range(n):
					_add_puff(Vector2(512.0 + float(i % 4) * 18.0, 124.0), Vector2(0.0, -14.0), 0.85, "gold" if i % 2 == 0 else "coral", 3.0)
		"ow_giant_stride":
			if _shift == "station_b" or _prev_shift == "station_b":
				for i: int in range(n):
					_add_puff(Vector2(288.0 + float(i) * 24.0, 412.0), Vector2((float(i) - 4.0) * 8.0, -16.0), 0.90, "coral" if i % 2 == 0 else "gold", 3.5)
		"ow_slag_basin":
			if _shift == "station_a" or _prev_shift == "station_a":
				for i: int in range(n):
					_add_puff(Vector2(144.0 + float(i % 4) * 18.0, 344.0), Vector2(0.0, -14.0), 0.85, "coral" if i % 2 == 0 else "apricot", 3.0)
			if _shift == "station_c" or _prev_shift == "station_c":
				for i: int in range(n):
					_add_puff(Vector2(544.0 + float(i % 4) * 20.0, 224.0), Vector2(-12.0, -18.0), 0.80, "cream" if i % 2 == 0 else "gold", 3.0)
		"ow_cinder_overlook":
			if _shift == "station_b" or _prev_shift == "station_b":
				for i: int in range(n):
					_add_puff(Vector2(560.0 + float(i % 4) * 16.0, 192.0), Vector2(-10.0, -16.0), 0.80, "cream" if i % 2 == 0 else "gold", 3.0)


func _emit_ambient_puffs() -> void:
	match region_id:
		"ow_rail_yard":
			if _shift == "station_a":
				_add_puff(Vector2(344.0, 96.0), Vector2(-12.0, -18.0), 0.85, "cream", 2.5)
			elif _shift == "station_c":
				_add_puff(Vector2(536.0, 112.0), Vector2(4.0, -12.0), 0.75, "apricot", 2.0)
		"ow_giant_stride":
			if _shift == "station_b":
				_add_puff(Vector2(376.0, 376.0), Vector2(0.0, -14.0), 0.90, "coral", 2.5)
				_add_puff(Vector2(456.0, 376.0), Vector2(0.0, -14.0), 0.90, "apricot", 2.5)
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
	_draw_puffs()
	if _relit:
		_draw_relit_embers()


func _draw_overworld_horizon() -> void:
	var spd: float = 38.0 if _relit else 62.0
	var tx: float = fposmod(_clock * spd + 140.0, _bounds.size.x + 180.0) - 90.0
	var ty: float = 20.0
	# Distant northern viaduct rail line
	draw_line(Vector2(192.0, ty + 8.0), Vector2(1380.0, ty + 8.0), PAL["dusk"] as Color, 1.0)
	# Distant Ember Express streaking eastward along the north rim
	_draw_mini_train(Vector2(roundf(tx), ty), _relit)

	# Distant Iron Colossus striding along the southern caldera horizon
	var col_target_x: float = 840.0 if _shift == "station_a" else (560.0 if _shift == "station_b" else 380.0)
	var stride_sway: float = sin(_clock * 1.15) * (12.0 if _relit else 26.0)
	var step_bob: float = absf(sin(_clock * 2.3)) * (1.5 if _relit else 3.5)
	_draw_distant_colossus(Vector2(roundf(col_target_x + stride_sway), roundf(522.0 - step_bob)), _clock, _relit)


func _draw_mini_train(p: Vector2, warm: bool) -> void:
	var body_c: Color = PAL["plum"] as Color if warm else PAL["night"] as Color
	var win_c: Color = PAL["cream"] as Color if warm else PAL["gold"] as Color
	var trim_c: Color = PAL["gold"] as Color if warm else PAL["apricot"] as Color
	# 3 carriages + locomotive facing east
	for i: int in range(3):
		var cx: float = p.x - float(i + 1) * 26.0
		draw_rect(Rect2(cx, p.y + 1.0, 22.0, 7.0), PAL["void"] as Color)
		draw_rect(Rect2(cx + 1.0, p.y + 2.0, 20.0, 5.0), body_c)
		draw_rect(Rect2(cx + 4.0, p.y + 3.0, 3.0, 2.0), win_c)
		draw_rect(Rect2(cx + 10.0, p.y + 3.0, 3.0, 2.0), win_c)
		draw_rect(Rect2(cx + 16.0, p.y + 3.0, 3.0, 2.0), win_c)
	# Locomotive engine
	draw_rect(Rect2(p.x, p.y - 1.0, 24.0, 9.0), PAL["void"] as Color)
	draw_rect(Rect2(p.x + 1.0, p.y, 22.0, 7.0), PAL["wine"] as Color)
	draw_rect(Rect2(p.x + 16.0, p.y - 4.0, 4.0, 4.0), PAL["dusk"] as Color)
	draw_rect(Rect2(p.x + 4.0, p.y + 1.0, 5.0, 3.0), win_c)
	draw_rect(Rect2(p.x + 22.0, p.y + 2.0, 3.0, 3.0), trim_c)
	# Headlight cone
	draw_colored_polygon(
		PackedVector2Array([Vector2(p.x + 25.0, p.y + 2.0), Vector2(p.x + 56.0, p.y - 4.0), Vector2(p.x + 56.0, p.y + 10.0)]),
		Color(trim_c, 0.22 if LxHudFx.flash_reduced() else 0.36)
	)


func _draw_distant_colossus(p: Vector2, t: float, calm: bool) -> void:
	var hull: Color = PAL["dusk"] as Color
	var dark: Color = PAL["night"] as Color
	var eye: Color = PAL["gold"] as Color if calm else PAL["coral"] as Color
	var leg_l: float = roundf(sin(t * 2.3) * (1.0 if calm else 3.0))
	var leg_r: float = -leg_l
	# Silhouette legs + massive furnace torso + glowing twin eyes
	draw_rect(Rect2(p.x - 10.0, p.y + 4.0 + leg_l, 7.0, 12.0), dark)
	draw_rect(Rect2(p.x + 3.0, p.y + 4.0 + leg_r, 7.0, 12.0), dark)
	draw_rect(Rect2(p.x - 14.0, p.y - 12.0, 28.0, 18.0), PAL["void"] as Color)
	draw_rect(Rect2(p.x - 13.0, p.y - 11.0, 26.0, 16.0), hull)
	draw_rect(Rect2(p.x - 8.0, p.y - 17.0, 16.0, 7.0), hull)
	# Furnace chest rib slits
	for ry: int in range(3):
		draw_rect(Rect2(p.x - 6.0, p.y - 7.0 + float(ry * 4), 12.0, 2.0), eye)
	# Glowing twin eyes
	draw_rect(Rect2(p.x - 5.0, p.y - 15.0, 3.0, 2.0), PAL["cream"] as Color)
	draw_rect(Rect2(p.x + 2.0, p.y - 15.0, 3.0, 2.0), PAL["cream"] as Color)


func _draw_rail_yard_motion(ease_u: float) -> void:
	# Station A: Ember Express docked on Track 1 (x=112..384, y=96..144)
	if _shift == "station_a":
		var slide_x: float = roundf(lerpf(-240.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(128.0 + slide_x, 112.0), 240.0, true, _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_a":
		var depart_x: float = roundf(lerpf(0.0, 360.0, ease_u))
		_draw_express_live_fx(Vector2(128.0 + depart_x, 112.0), 240.0, true, true)
	# Station C: Iron Colossus forearm bridging NE canyon (x=480..592, y=80..176)
	if _shift == "station_c":
		var drop_y: float = roundf(lerpf(-72.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(496.0, 96.0 + drop_y, 80.0, 64.0), _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_c":
		var lift_y: float = roundf(lerpf(0.0, -72.0, ease_u))
		_draw_colossus_limb_fx(Rect2(496.0, 96.0 + lift_y, 80.0, 64.0), true)


func _draw_giant_stride_motion(ease_u: float) -> void:
	# Station B: Colossus colossal left boot in South Trench (x=320..512, y=352..448)
	if _shift == "station_b":
		var drop_y: float = roundf(lerpf(-88.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(352.0, 368.0 + drop_y, 128.0, 64.0), _anim_t > 0.0)
		# Ankle hatch beacon pulse
		var pulse: float = 0.55 + 0.45 * sin(_clock * 4.0)
		draw_rect(Rect2(408.0, 404.0 + drop_y, 16.0, 6.0), Color(PAL["gold"] as Color, pulse))
	elif _anim_t > 0.0 and _prev_shift == "station_b":
		var lift_y: float = roundf(lerpf(0.0, -88.0, ease_u))
		_draw_colossus_limb_fx(Rect2(352.0, 368.0 + lift_y, 128.0, 64.0), true)


func _draw_slag_basin_motion(ease_u: float) -> void:
	# Station A: Colossus leg bridging SW canal (x=112..240, y=304..384)
	if _shift == "station_a":
		var drop_y: float = roundf(lerpf(-64.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_colossus_limb_fx(Rect2(128.0, 312.0 + drop_y, 96.0, 56.0), _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_a":
		var lift_y: float = roundf(lerpf(0.0, -64.0, ease_u))
		_draw_colossus_limb_fx(Rect2(128.0, 312.0 + lift_y, 96.0, 56.0), true)
	# Station C: Ember Express flatcar bridging East canal (x=480..624, y=176..256)
	if _shift == "station_c":
		var slide_y: float = roundf(lerpf(-140.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(496.0, 192.0 + slide_y), 120.0, false, _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_c":
		var out_y: float = roundf(lerpf(0.0, 160.0, ease_u))
		_draw_express_live_fx(Vector2(496.0, 192.0 + out_y), 120.0, false, true)


func _draw_cinder_overlook_motion(ease_u: float) -> void:
	# Station B: Ember Express flatcars bridging East Trestle Abyss (x=480..640, y=160..240)
	if _shift == "station_b":
		var slide_y: float = roundf(lerpf(-128.0, 0.0, ease_u)) if _anim_t > 0.0 else 0.0
		_draw_express_live_fx(Vector2(496.0, 184.0 + slide_y), 136.0, true, _anim_t > 0.0)
	elif _anim_t > 0.0 and _prev_shift == "station_b":
		var out_y: float = roundf(lerpf(0.0, 140.0, ease_u))
		_draw_express_live_fx(Vector2(496.0, 184.0 + out_y), 136.0, true, true)


func _draw_express_live_fx(origin: Vector2, length_px: float, facing_east: bool, moving: bool) -> void:
	var pulse: float = 0.65 + 0.35 * sin(_clock * 5.0)
	var head_x: float = origin.x + (length_px if facing_east else 0.0)
	var dir_x: float = 1.0 if facing_east else -1.0
	if moving:
		# Crisp sliding locomotive silhouette during the 1.15s arrival/departure
		draw_rect(Rect2(origin.x - 2.0, origin.y - 10.0, length_px + 4.0, 26.0), Color(PAL["void"] as Color, 0.85))
		draw_rect(Rect2(origin.x, origin.y - 8.0, length_px, 22.0), PAL["wine"] as Color)
		draw_rect(Rect2(origin.x + 2.0, origin.y - 6.0, length_px - 4.0, 3.0), PAL["apricot"] as Color)
		var wx: float = origin.x + 12.0
		while wx < origin.x + length_px - 18.0:
			draw_rect(Rect2(wx, origin.y - 1.0, 10.0, 6.0), PAL["gold"] as Color)
			wx += 22.0
	# Headlight beam + glowing firebox sparks (always alive while docked!)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(head_x, origin.y),
			Vector2(head_x + dir_x * 42.0, origin.y - 12.0),
			Vector2(head_x + dir_x * 42.0, origin.y + 14.0),
		]),
		Color(PAL["gold"] as Color, (0.14 if LxHudFx.flash_reduced() else 0.24) * pulse)
	)
	draw_rect(Rect2(head_x - 2.0, origin.y - 2.0, 4.0, 5.0), PAL["cream"] as Color)


func _draw_colossus_limb_fx(r: Rect2, moving: bool) -> void:
	var pulse: float = 0.55 + 0.45 * sin(_clock * 2.6)
	var slit_c: Color = PAL["gold"] as Color if _relit else PAL["coral"] as Color
	if moving:
		draw_rect(r.grow(2.0), Color(PAL["void"] as Color, 0.82))
		draw_rect(r, PAL["dusk"] as Color)
		draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 4.0), PAL["stone"] as Color)
	# Pulsing furnace grate slits along the Colossus's brass plating
	var gx: float = r.position.x + 12.0
	while gx < r.end.x - 16.0:
		draw_rect(Rect2(gx, r.position.y + r.size.y * 0.35, 10.0, 3.0), Color(slit_c, pulse))
		draw_rect(Rect2(gx + 2.0, r.position.y + r.size.y * 0.35 + 1.0, 6.0, 1.0), Color(PAL["cream"] as Color, pulse * 0.85))
		gx += 24.0


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
