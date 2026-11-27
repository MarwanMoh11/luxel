class_name LxMsWeatherSync
extends LxToy
## Rain Mausoleum Brass Barometer Plaque:
## Mirrors `weather` between `dungeon:rain_mausoleum` (canonical dungeon scope for layers,
## HUD, rain_frog, mist_eel) and `dungeon:mausoleum` (scope read/written by boss_cloud_deacon
## and boss_drowned_choir), ensuring weather wheels, bosses, enemies, and flood layers stay
## 100% synchronized in both directions.

const SCOPE_CANON: String = "dungeon:rain_mausoleum"
const SCOPE_LEGACY: String = "dungeon:mausoleum"

var _vars_bound: LxWorldState = null
var _syncing: bool = false
var _weather: String = "rain"
var _shift_t: float = 0.0


func _toy_setup() -> void:
	kind = "ms_weather_sync"
	z_index = -5
	radius = 8.0
	_shift_t = 0.0
	_bind_vars()
	_initial_sync()
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


func _initial_sync() -> void:
	if Lx.vars == null:
		return
	var canon: String = str(Lx.vars.get_var(SCOPE_CANON, "weather", "")).strip_edges().to_lower()
	if canon in ["sun", "rain", "wind"]:
		_weather = canon
		_syncing = true
		Lx.vars.set_var(SCOPE_LEGACY, "weather", canon)
		_syncing = false
	else:
		var leg: String = str(Lx.vars.get_var(SCOPE_LEGACY, "weather", "rain")).strip_edges().to_lower()
		if leg not in ["sun", "rain", "wind"]:
			leg = "rain"
		_weather = leg
		_syncing = true
		Lx.vars.set_var(SCOPE_CANON, "weather", leg)
		Lx.vars.set_var(SCOPE_LEGACY, "weather", leg)
		_syncing = false


func _on_var_changed(scope: String, nm: String, value: Variant) -> void:
	if _syncing or nm != "weather":
		return
	var w: String = str(value).strip_edges().to_lower()
	if w not in ["sun", "rain", "wind"]:
		return
	_weather = w
	_shift_t = 0.45
	_syncing = true
	if scope == SCOPE_CANON:
		Lx.vars.set_var(SCOPE_LEGACY, "weather", w)
	elif scope == SCOPE_LEGACY:
		Lx.vars.set_var(SCOPE_CANON, "weather", w)
		if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
			region.call("apply_layers", true)
	_syncing = false
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _shift_t > 0.0:
		_shift_t = maxf(0.0, _shift_t - dt)
		queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_ring: Color = (PAL["gold"] if _weather == "sun" else (c_ice if _weather == "wind" else PAL["sky"])) as Color
	var fred: bool = LxHudFx.flash_reduced()
	draw_circle(Vector2.ZERO, 7.0, c_void)
	draw_circle(Vector2.ZERO, 6.0, PAL["night"] as Color)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 14, c_ring, 1.0)
	# Distinct greyscale-legible weather glyph inside brass barometer dial
	if _weather == "sun":
		draw_rect(Rect2(-2.0, 0.0, 5.0, 1.0), c_ring)
		draw_rect(Rect2(0.0, -2.0, 1.0, 5.0), c_ring)
		draw_rect(Rect2(0.0, 0.0, 1.0, 1.0), c_cream)
	elif _weather == "wind":
		draw_rect(Rect2(-3.0, -1.0, 5.0, 1.0), c_ice)
		draw_rect(Rect2(-2.0, 1.0, 5.0, 1.0), PAL["sky"] as Color)
		draw_rect(Rect2(2.0, -2.0, 1.0, 1.0), c_cream)
	else:
		draw_rect(Rect2(-2.0, -2.0, 1.0, 2.0), c_ring)
		draw_rect(Rect2(0.0, -1.0, 1.0, 3.0), c_ice)
		draw_rect(Rect2(2.0, 0.0, 1.0, 2.0), c_ring)
	if _shift_t > 0.0:
		var u: float = 1.0 - clampf(_shift_t / 0.45, 0.0, 1.0)
		var sa: float = (1.0 - u) * (0.42 if fred else 0.78)
		var sr: float = 8.0 if fred else roundf(lerpf(6.0, 13.0, u))
		draw_arc(Vector2.ZERO, sr, 0.0, TAU, 14, Color(c_ring, sa), 1.0)
