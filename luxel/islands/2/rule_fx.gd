class_name LxIsland2RuleFx
extends RefCounted
## Island 2 signature feel FX (strict 20-color LxPalette, respects flash_reduced()):
## - 1.2s full-viewport Tide-Line Sweep on Tide Organ / Tower Tide / Lock Water shifts.
## - Diegetic Skiff bow spray, twin stern wake ribbons, first-ride recoil thrust arrow,
##   and taut Mooring-Post hawser + slingshot chevron.

const SWEEP_DUR: float = 1.20
const FIRST_RIDE_GUIDE_SHOTS: int = 4

var sweep_t: float = 0.0
var sweep_rising: bool = true
var sweep_local: bool = false
var organ_rings: Array[Dictionary] = [] # {pos, age, life, col}
var _recoil_shots_seen: int = 0
var _last_wick_shots: int = -1
var _wake_trail: Array[Dictionary] = [] # {pos, dir, age, life}
var _wake_cd: float = 0.0


func reset() -> void:
	sweep_t = 0.0
	organ_rings.clear()
	_wake_trail.clear()
	_wake_cd = 0.0


func trigger_tide_sweep(rising: bool, is_local: bool, origin_pos: Vector2 = Vector2.ZERO) -> void:
	sweep_t = SWEEP_DUR
	sweep_rising = rising
	sweep_local = is_local
	if origin_pos != Vector2.ZERO:
		organ_rings.append({
			"pos": origin_pos,
			"age": 0.0,
			"life": 0.75,
			"col": "ice" if rising else "gold",
		})


func tick(dt: float, wick: LxWick) -> void:
	if sweep_t > 0.0:
		sweep_t = maxf(0.0, sweep_t - dt)
	for i: int in range(organ_rings.size() - 1, -1, -1):
		organ_rings[i]["age"] = float(organ_rings[i]["age"]) + dt
		if float(organ_rings[i]["age"]) >= float(organ_rings[i]["life"]):
			organ_rings.remove_at(i)
	for i: int in range(_wake_trail.size() - 1, -1, -1):
		_wake_trail[i]["age"] = float(_wake_trail[i]["age"]) + dt
		if float(_wake_trail[i]["age"]) >= float(_wake_trail[i]["life"]):
			_wake_trail.remove_at(i)
	if wick == null or not is_instance_valid(wick):
		return
	if wick.is_mounted():
		var veh: Node = wick.get_mounted_vehicle()
		if veh is LxVehicleSkiff:
			var sk: LxVehicleSkiff = veh as LxVehicleSkiff
			if _last_wick_shots >= 0 and wick.shots_fired > _last_wick_shots:
				_recoil_shots_seen += wick.shots_fired - _last_wick_shots
			_last_wick_shots = wick.shots_fired
			_wake_cd = maxf(0.0, _wake_cd - dt)
			if sk.vel.length() > 34.0 and _wake_cd <= 0.0:
				_wake_cd = 0.07
				var dir: Vector2 = sk.vel.normalized()
				_wake_trail.append({
					"pos": sk.pos - dir * 7.0,
					"dir": dir,
					"age": 0.0,
					"life": 0.42,
				})
	else:
		_last_wick_shots = wick.shots_fired


func draw_world(ci: CanvasItem, wick: LxWick, clock: float) -> void:
	var pal: Dictionary = LxPalette.PAL
	var red: bool = LxHudFx.flash_reduced()
	# Expanding Tide Organ / Sluice resonance rings in world space
	for r: Dictionary in organ_rings:
		var u: float = clampf(float(r["age"]) / maxf(0.01, float(r["life"])), 0.0, 1.0)
		var rp: Vector2 = (r["pos"] as Vector2).round()
		var col: Color = pal.get(str(r["col"]), pal["ice"]) as Color
		var a1: float = (1.0 - u) * (0.45 if red else 0.85)
		var a2: float = (1.0 - u) * (0.35 if red else 0.65)
		ci.draw_arc(rp, roundf(lerpf(8.0, 72.0, u)), 0.0, TAU, 24, Color(col, a1), 1.0 if red else 2.0)
		ci.draw_arc(rp, roundf(lerpf(4.0, 48.0, u)), 0.0, TAU, 18, Color(pal["cream"] as Color, a2), 1.0)

	# Skiff twin V-wake ribbons
	for wk: Dictionary in _wake_trail:
		var u: float = clampf(float(wk["age"]) / maxf(0.01, float(wk["life"])), 0.0, 1.0)
		var wp: Vector2 = wk["pos"] as Vector2
		var wd: Vector2 = wk["dir"] as Vector2
		var side := Vector2(-wd.y, wd.x)
		var spread: float = lerpf(3.0, 11.0, u)
		var alpha: float = (1.0 - u) * (0.45 if red else 0.72)
		var c_w: Color = Color((pal["cream"] if u < 0.35 else pal["ice"]) as Color, alpha)
		ci.draw_rect(Rect2((wp + side * spread).round(), Vector2(2.0, 1.0)), c_w)
		ci.draw_rect(Rect2((wp - side * spread).round(), Vector2(2.0, 1.0)), c_w)

	if wick == null or not is_instance_valid(wick) or not wick.is_mounted():
		return
	var veh: Node = wick.get_mounted_vehicle()
	if not (veh is LxVehicleSkiff):
		return
	var sk: LxVehicleSkiff = veh as LxVehicleSkiff

	# Bow spray pips when skimming fast
	if sk.vel.length() > 60.0 and not red:
		var hd: Vector2 = sk.vel.normalized()
		var side := Vector2(-hd.y, hd.x)
		var bow: Vector2 = sk.pos + hd * 9.0
		var flick: float = 1.0 if int(floorf(clock * 12.0)) % 2 == 0 else 2.0
		ci.draw_rect(Rect2((bow + side * (3.0 + flick)).round(), Vector2(2.0, 1.0)), pal["cream"] as Color)
		ci.draw_rect(Rect2((bow - side * (3.0 + flick)).round(), Vector2(2.0, 1.0)), pal["ice"] as Color)

	# First-ride diegetic recoil thrust guide (opposite aim) for first 4 shots
	if _recoil_shots_seen < FIRST_RIDE_GUIDE_SHOTS and not sk.grounded:
		var aim_d: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.01 else Vector2.RIGHT
		var thrust_d: Vector2 = -aim_d
		var pulse: float = 0.75 if red else (0.55 + 0.35 * sin(clock * 7.0))
		var c_g: Color = Color(pal["gold"] as Color, pulse)
		var c_c: Color = Color(pal["cream"] as Color, pulse)
		for step: int in range(1, 4):
			var dp: Vector2 = (sk.pos + thrust_d * (10.0 + float(step) * 5.0)).round()
			ci.draw_rect(Rect2(dp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_c if step == 3 else c_g)
		var tip: Vector2 = (sk.pos + thrust_d * 29.0).round()
		var perp := Vector2(-thrust_d.y, thrust_d.x)
		ci.draw_line(tip, (tip - thrust_d * 4.0 + perp * 3.0).round(), c_c, 1.0)
		ci.draw_line(tip, (tip - thrust_d * 4.0 - perp * 3.0).round(), c_c, 1.0)


func draw_hud_sweep(ci: CanvasItem, clock: float) -> void:
	if sweep_t <= 0.0:
		return
	var pal: Dictionary = LxPalette.PAL
	var red: bool = LxHudFx.flash_reduced()
	var u: float = 1.0 - clampf(sweep_t / SWEEP_DUR, 0.0, 1.0)
	var fade: float = sin(u * PI)
	if red:
		# Reduced-flash calm tide crest bar at top/bottom edge with directional chevrons
		var bar_h: float = 3.0 if sweep_local else 5.0
		var col: Color = (pal["ice"] if sweep_rising else pal["teal"]) as Color
		var by: float = (180.0 - bar_h) if sweep_rising else 0.0
		ci.draw_rect(Rect2(0.0, by, 320.0, bar_h), Color(col, fade * 0.60))
		var ch_dir: Vector2 = Vector2.UP if sweep_rising else Vector2.DOWN
		var ch_y: float = (by - 4.0) if sweep_rising else (by + bar_h + 3.0)
		var ch_c := Color(pal["cream"] as Color, fade * 0.75)
		var ch_sh := Color(pal["void"] as Color, fade * 0.65)
		for cx: float in [80.0, 160.0, 240.0]:
			LxPhysDraw.draw_chevron(ci, Vector2(cx, ch_y), ch_dir, ch_c, ch_sh, 2.0)
		return

	# Full 1.2s foaming tide-line sweep across the 320x180 viewport
	var band_h: float = 14.0 if sweep_local else 22.0
	var y_crest: float = lerpf(188.0, -band_h, u) if sweep_rising else lerpf(-band_h, 188.0, u)
	var c_deep: Color = Color(pal["deep"] as Color, fade * 0.30)
	var c_sky: Color = Color(pal["sky"] as Color, fade * 0.45)
	var c_ice: Color = Color(pal["ice"] as Color, fade * 0.78)
	var c_cream: Color = Color(pal["cream"] as Color, fade * 0.88)

	if sweep_rising:
		ci.draw_rect(Rect2(0.0, roundf(y_crest + 6.0), 320.0, band_h), c_deep)
		ci.draw_rect(Rect2(0.0, roundf(y_crest + 2.0), 320.0, 5.0), c_sky)
		ci.draw_rect(Rect2(0.0, roundf(y_crest), 320.0, 2.0), c_ice)
	else:
		ci.draw_rect(Rect2(0.0, roundf(y_crest - band_h), 320.0, band_h), c_deep)
		ci.draw_rect(Rect2(0.0, roundf(y_crest - 5.0), 320.0, 5.0), c_sky)
		ci.draw_rect(Rect2(0.0, roundf(y_crest), 320.0, 2.0), c_ice)

	# Scalloped pixel foam pips along the moving tide line
	var x: float = 4.0
	var idx: int = 0
	while x < 316.0:
		var wob: float = roundf(sin(clock * 14.0 + float(idx) * 0.9) * 2.0)
		var py: float = roundf(y_crest + wob)
		ci.draw_rect(Rect2(x, py, 6.0, 2.0), c_cream if idx % 2 == 0 else c_ice)
		if idx % 3 == 0:
			var trail_y: float = py + (7.0 if sweep_rising else -7.0)
			ci.draw_rect(Rect2(x + 2.0, trail_y, 3.0, 1.0), c_sky)
		x += 12.0
		idx += 1
