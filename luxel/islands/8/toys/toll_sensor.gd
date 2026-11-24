class_name LxTollSensor
extends LxToy
## Island 8 Toll Sensor — evaluates sold-setting predicates live and emits signals.
## Props: check ("sold:<id>|sold_tab:<tab>|sold_count>=<n>|toll_weight>=<n>|..."),
##        target_id / target_ids, invert (bool), show_glyph (bool).
## States: DORMANT (slit closed) / SATISFIED (open diamond eye + corner rays).

var check_expr: String = "sold_count>=1"
var invert: bool = false
var show_glyph: bool = true
var _sold_ref: LxSold = null
var _vars_ref: LxWorldState = null
var _initial_sync_done: bool = false


func _toy_setup() -> void:
	check_expr = str(props.get("check", "sold_count>=1")).strip_edges()
	invert = bool(props.get("invert", false))
	show_glyph = bool(props.get("show_glyph", true))
	radius = 12.0
	_bind_sources()
	powered = _eval_now()
	queue_redraw()


func _exit_tree() -> void:
	_unbind_sources()


func get_state_name() -> String:
	return "SATISFIED" if powered else "DORMANT"


func tick(dt: float) -> void:
	super.tick(dt)
	if not _initial_sync_done:
		_initial_sync_done = true
		var want: bool = _eval_now()
		powered = want
		if want:
			emit_power(true)
		queue_redraw()


func reevaluate(emit_if_changed: bool = true) -> bool:
	var want: bool = _eval_now()
	if want != powered:
		set_powered(want)
		if emit_if_changed:
			emit_power(want)
	return powered


func get_light_pool() -> Vector4:
	if not active or not powered:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 28.0, 0.55)


func _eval_now() -> bool:
	var raw: bool = LxSold.current().eval_check(check_expr)
	return (not raw) if invert else raw


func _on_source_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	reevaluate(true)


func _bind_sources() -> void:
	_sold_ref = LxSold.current()
	if _sold_ref != null and not _sold_ref.state_changed.is_connected(_on_source_changed):
		_sold_ref.state_changed.connect(_on_source_changed)
	_vars_ref = Lx.vars
	if _vars_ref != null and not _vars_ref.var_changed.is_connected(_on_source_changed):
		_vars_ref.var_changed.connect(_on_source_changed)


func _unbind_sources() -> void:
	if _sold_ref != null and _sold_ref.state_changed.is_connected(_on_source_changed):
		_sold_ref.state_changed.disconnect(_on_source_changed)
	_sold_ref = null
	if _vars_ref != null and _vars_ref.var_changed.is_connected(_on_source_changed):
		_vars_ref.var_changed.disconnect(_on_source_changed)
	_vars_ref = null


func _draw() -> void:
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var stone: Color = PAL["stone"] as Color

	# Octagonal brass-mounted floor/wall sensor plate
	draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), void_c)
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), gold if powered else dusk)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), night)

	if powered:
		# Open bright diamond eye + 4 cardinal corner sparks (clear in greyscale)
		draw_rect(Rect2(-3.0, -1.0, 6.0, 2.0), gold)
		draw_rect(Rect2(-1.0, -3.0, 2.0, 6.0), gold)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), cream)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), void_c)
		draw_rect(Rect2(0.0, 0.0, 1.0, 1.0), cream)
		for sp: Vector2 in [Vector2(-6.0, 0.0), Vector2(5.0, 0.0), Vector2(0.0, -6.0), Vector2(0.0, 5.0)]:
			draw_rect(Rect2(sp, Vector2.ONE), cream)
	else:
		# Closed vertical slit (clearly dark/dormant in greyscale)
		draw_rect(Rect2(-3.0, -1.0, 6.0, 2.0), dusk)
		draw_rect(Rect2(-1.0, -3.0, 2.0, 6.0), void_c)
		if show_glyph:
			draw_rect(Rect2(0.0, -2.0, 1.0, 4.0), stone)

	_draw_signal_pulses()
