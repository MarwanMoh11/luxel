class_name LxBiomeWeather
extends Node2D
## Per-island atmospheric living weather & relit-dawn world transformation (z_index = 4).
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL).
##
## - Island 1 (Bell Isle): Gentle twilight petals -> warm golden dawn pollen when relit
## - Island 2 (Tidewater Harbor): Coastal sea-spray streaks & distant gliding gull silhouettes
## - Island 3 (Thornwood Hollow): Slanted woodland moonlight beams & drifting emerald canopy pollen
## - Island 4 (Mirefen Gardens): Soft botanical rain streaks & surface water-drop ripples
## - Island 5 (Starfall Observatory): High-altitude shooting comets & twinkling astral lines
## - Island 6 (Ashen Kiln): Rising volcanic cinder columns & glowing forge ember drift
## - Island 7 (Moon Shoals): Shimmering northern-lights lunar aurora ribbons across upper sky
## - Island 8 (The Long Night): Swirling eclipse ash reversing upward into golden dawn sparks!

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 176.0
const HALF_H: float = 104.0

var _island_id: int = 1
var _is_dungeon: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _drops: Array[Dictionary] = []
var _comets: Array[Dictionary] = []
var _gulls: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4


func configure(island_id: int, is_dungeon: bool, cam_center: Vector2) -> void:
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_clock = 0.0
	_cam_center = cam_center
	_drops.clear()
	_comets.clear()
	_gulls.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_island_id * 11939 + (401 if is_dungeon else 73))
	if not is_dungeon:
		match _island_id:
			2: # Sea spray + 3 distant gull silhouettes
				for i: int in range(14):
					_drops.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-HALF_H, HALF_H), "spd": rng.randf_range(36.0, 62.0), "len": rng.randf_range(3.0, 6.0)})
				for g: int in range(3):
					_gulls.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-82.0, -34.0), "spd": rng.randf_range(16.0, 26.0), "phase": rng.randf_range(0.0, TAU)})
			3: # Emerald pollen & forest canopy dust
				for i: int in range(18):
					_drops.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-HALF_H, HALF_H), "spd": rng.randf_range(8.0, 16.0), "phase": rng.randf_range(0.0, TAU)})
			4: # Gentle botanical rain streaks
				for i: int in range(22):
					_drops.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-HALF_H, HALF_H), "spd": rng.randf_range(74.0, 108.0), "len": rng.randf_range(4.0, 8.0)})
			5: # Cosmic shooting comets
				for i: int in range(4):
					_comets.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-88.0, 20.0), "age": rng.randf_range(0.0, 4.0), "period": rng.randf_range(3.4, 5.8)})
			6: # Rising volcanic embers & ash columns
				for i: int in range(20):
					_drops.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-HALF_H, HALF_H), "spd": rng.randf_range(18.0, 38.0), "phase": rng.randf_range(0.0, TAU)})
			8: # Swirling eclipse ash (reverses upward into golden dawn sparks once relit!)
				for i: int in range(22):
					_drops.append({"ox": rng.randf_range(-HALF_W, HALF_W), "oy": rng.randf_range(-HALF_H, HALF_H), "spd": rng.randf_range(16.0, 30.0), "phase": rng.randf_range(0.0, TAU)})
	queue_redraw()


func _is_relit() -> bool:
	return Lx.state != null and Lx.state.relit_islands.has(_island_id)


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0 or _is_dungeon:
		return
	_clock += dt
	var relit: bool = _is_relit()
	match _island_id:
		2:
			for d: Dictionary in _drops:
				d["ox"] = wrapf(float(d["ox"]) + float(d["spd"]) * dt, -HALF_W, HALF_W)
				d["oy"] = wrapf(float(d["oy"]) + 10.0 * dt, -HALF_H, HALF_H)
			for g: Dictionary in _gulls:
				g["ox"] = wrapf(float(g["ox"]) + float(g["spd"]) * dt, -HALF_W, HALF_W)
		3:
			for d: Dictionary in _drops:
				d["ox"] = wrapf(float(d["ox"]) + sin(_clock * 0.9 + float(d["phase"])) * 7.0 * dt, -HALF_W, HALF_W)
				d["oy"] = wrapf(float(d["oy"]) + float(d["spd"]) * 0.45 * dt, -HALF_H, HALF_H)
		4:
			for d: Dictionary in _drops:
				d["ox"] = wrapf(float(d["ox"]) - float(d["spd"]) * 0.22 * dt, -HALF_W, HALF_W)
				d["oy"] = wrapf(float(d["oy"]) + float(d["spd"]) * dt, -HALF_H, HALF_H)
		5:
			for cm: Dictionary in _comets:
				cm["age"] = fposmod(float(cm["age"]) + dt, float(cm["period"]))
		6:
			for d: Dictionary in _drops:
				d["ox"] = wrapf(float(d["ox"]) + sin(_clock * 2.2 + float(d["phase"])) * 10.0 * dt, -HALF_W, HALF_W)
				d["oy"] = wrapf(float(d["oy"]) - float(d["spd"]) * dt, -HALF_H, HALF_H)
		8:
			var dir_y: float = -1.0 if relit else 1.0
			for d: Dictionary in _drops:
				d["ox"] = wrapf(float(d["ox"]) + sin(_clock * 1.4 + float(d["phase"])) * 14.0 * dt, -HALF_W, HALF_W)
				d["oy"] = wrapf(float(d["oy"]) + dir_y * float(d["spd"]) * dt, -HALF_H, HALF_H)
	queue_redraw()


func _draw() -> void:
	if _is_dungeon:
		return
	var fred: bool = LxHudFx.flash_reduced()
	var relit: bool = _is_relit()
	match _island_id:
		1:
			if relit:
				_draw_dawn_sunbeams(fred)
		2:
			_draw_coastal_weather(fred, relit)
		3:
			_draw_forest_beams(fred, relit)
		4:
			_draw_lagoon_rain(fred, relit)
		5:
			_draw_comets(fred)
		6:
			_draw_volcanic_cinders(fred)
		7:
			_draw_lunar_aurora(fred)
		8:
			_draw_eclipse_ash(fred, relit)


func _draw_dawn_sunbeams(fred: bool) -> void:
	var a: float = 0.06 if fred else 0.11
	for k: int in range(3):
		var bx: float = roundf(_cam_center.x - 110.0 + float(k) * 110.0 + sin(_clock * 0.35 + float(k)) * 12.0)
		var top := Vector2(bx, _cam_center.y - 96.0)
		var poly := PackedVector2Array([top + Vector2(-10.0, 0.0), top + Vector2(14.0, 0.0), top + Vector2(44.0, 170.0), top + Vector2(12.0, 170.0)])
		draw_colored_polygon(poly, Color(PAL["gold"] as Color, a))


func _draw_coastal_weather(fred: bool, relit: bool) -> void:
	var c_spray: Color = (PAL["cream"] if relit else PAL["ice"]) as Color
	for d: Dictionary in _drops:
		var p: Vector2 = (_cam_center + Vector2(float(d["ox"]), float(d["oy"]))).round()
		draw_line(p, p + Vector2(float(d["len"]), 1.0), Color(c_spray, 0.25 if fred else 0.42), 1.0)
	var c_gull: Color = (PAL["cream"] if relit else PAL["stone"]) as Color
	for g: Dictionary in _gulls:
		var gp: Vector2 = (_cam_center + Vector2(float(g["ox"]), float(g["oy"]))).round()
		var wing: float = roundf(sin(_clock * 5.2 + float(g["phase"])) * 2.0)
		draw_line(gp + Vector2(-4.0, wing), gp, Color(c_gull, 0.65), 1.0)
		draw_line(gp, gp + Vector2(4.0, wing), Color(c_gull, 0.65), 1.0)


func _draw_forest_beams(fred: bool, relit: bool) -> void:
	var beam_c: Color = (PAL["gold"] if relit else PAL["lime"]) as Color
	var a: float = 0.05 if fred else 0.09
	for k: int in range(3):
		var bx: float = roundf(_cam_center.x - 115.0 + float(k) * 105.0 + sin(_clock * 0.3 + float(k)) * 8.0)
		var top := Vector2(bx, _cam_center.y - 96.0)
		var poly := PackedVector2Array([top + Vector2(-8.0, 0.0), top + Vector2(10.0, 0.0), top + Vector2(36.0, 175.0), top + Vector2(12.0, 175.0)])
		draw_colored_polygon(poly, Color(beam_c, a))
	for d: Dictionary in _drops:
		var p: Vector2 = (_cam_center + Vector2(float(d["ox"]), float(d["oy"]))).round()
		draw_rect(Rect2(p, Vector2(2.0, 1.0)), Color((PAL["gold"] if relit else PAL["lime"]) as Color, 0.55))


func _draw_lagoon_rain(fred: bool, relit: bool) -> void:
	var a: float = 0.18 if relit else (0.28 if fred else 0.46)
	var col: Color = (PAL["cream"] if relit else PAL["ice"]) as Color
	for d: Dictionary in _drops:
		var p: Vector2 = (_cam_center + Vector2(float(d["ox"]), float(d["oy"]))).round()
		var l: float = float(d["len"])
		draw_line(p, p + Vector2(-l * 0.25, l), Color(col, a), 1.0)


func _draw_comets(fred: bool) -> void:
	for cm: Dictionary in _comets:
		var age: float = float(cm["age"])
		if age > 0.72:
			continue
		var u: float = age / 0.72
		var head: Vector2 = (_cam_center + Vector2(float(cm["ox"]) + u * 96.0, float(cm["oy"]) + u * 44.0)).round()
		var tail: Vector2 = (head - Vector2(22.0, 10.0)).round()
		var a: float = sin(u * PI) * (0.55 if fred else 0.90)
		draw_line(tail, head, Color(PAL["sky"] as Color, a * 0.75), 1.2)
		draw_line(tail.lerp(head, 0.5), head, Color(PAL["gold"] as Color, a), 1.4)
		draw_rect(Rect2(head - Vector2.ONE, Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, a))


func _draw_volcanic_cinders(fred: bool) -> void:
	var a: float = 0.52 if fred else 0.85
	for i: int in range(_drops.size()):
		var d: Dictionary = _drops[i]
		var p: Vector2 = (_cam_center + Vector2(float(d["ox"]), float(d["oy"]))).round()
		var col: Color = (PAL["gold"] if i % 3 == 0 else (PAL["coral"] if i % 3 == 1 else PAL["apricot"])) as Color
		draw_rect(Rect2(p, Vector2(2.0 if i % 4 == 0 else 1.0, 2.0 if i % 5 == 0 else 1.0)), Color(col, a))


func _draw_lunar_aurora(fred: bool) -> void:
	var a: float = 0.08 if fred else 0.15
	for band: int in range(2):
		var col: Color = (PAL["ice"] if band == 0 else PAL["sky"]) as Color
		var pts := PackedVector2Array()
		var base_y: float = _cam_center.y - 76.0 + float(band) * 14.0
		for s: int in range(14):
			var fx: float = _cam_center.x - 168.0 + float(s) * 26.0
			var fy: float = base_y + sin(_clock * 0.7 + float(s) * 0.55 + float(band) * 1.4) * 7.0
			pts.append(Vector2(roundf(fx), roundf(fy)))
		for s: int in range(pts.size() - 1):
			draw_line(pts[s], pts[s + 1], Color(col, a), 3.0 if band == 0 else 2.0)


func _draw_eclipse_ash(fred: bool, relit: bool) -> void:
	var a: float = 0.55 if fred else 0.82
	for i: int in range(_drops.size()):
		var d: Dictionary = _drops[i]
		var p: Vector2 = (_cam_center + Vector2(float(d["ox"]), float(d["oy"]))).round()
		var col: Color
		if relit:
			col = (PAL["cream"] if i % 3 == 0 else PAL["gold"]) as Color
		else:
			col = (PAL["plum"] if i % 3 == 0 else (PAL["rose"] if i % 5 == 0 else PAL["mauve"])) as Color
		draw_rect(Rect2(p, Vector2(2.0 if i % 4 == 0 else 1.0, 1.0)), Color(col, a))
