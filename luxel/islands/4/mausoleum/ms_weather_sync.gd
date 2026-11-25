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


func _toy_setup() -> void:
	kind = "ms_weather_sync"
	z_index = -5
	radius = 8.0
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
	_syncing = true
	if scope == SCOPE_CANON:
		Lx.vars.set_var(SCOPE_LEGACY, "weather", w)
	elif scope == SCOPE_LEGACY:
		Lx.vars.set_var(SCOPE_CANON, "weather", w)
		if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
			region.call("apply_layers", true)
	_syncing = false
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_ring: Color = (PAL["gold"] if _weather == "sun" else (PAL["ice"] if _weather == "wind" else PAL["sky"])) as Color
	draw_circle(Vector2.ZERO, 6.0, c_void)
	draw_circle(Vector2.ZERO, 5.0, PAL["night"] as Color)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 12, c_ring, 1.0)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
