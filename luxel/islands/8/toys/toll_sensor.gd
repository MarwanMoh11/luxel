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
	elif powered and not LxHudFx.flash_reduced():
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
	var mauve: Color = PAL["mauve"] as Color
	var stone: Color = PAL["stone"] as Color
	var coral: Color = PAL["coral"] as Color
	var apr: Color = PAL["apricot"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var fr: bool = LxHudFx.flash_reduced()

	# Grounded recess shadow under brass toll medallion
	_draw_ground_shadow(9.5, 4.5, Vector2(1.0, 6.0))

	# 4 diagonal carved brass corner prongs framing the medallion plate
	var prong_body: Color = gold if powered else dusk
	var prong_hi: Color = cream if powered else stone
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var px: float = sign_x * 7.0
			var py: float = sign_y * 7.0
			draw_rect(Rect2(px - 2.0, py - 2.0, 4.0, 4.0), void_c)
			draw_rect(Rect2(px - 1.0, py - 1.0, 2.0, 2.0), prong_body)
			draw_rect(Rect2(px if sign_x > 0.0 else (px - 1.0), py if sign_y > 0.0 else (py - 1.0), 1.0, 1.0), prong_hi)

	# Carved octagonal brass toll-medallion plate
	var oct_out := PackedVector2Array([
		Vector2(-4.0, -9.0), Vector2(4.0, -9.0),
		Vector2(9.0, -4.0), Vector2(9.0, 4.0),
		Vector2(4.0, 9.0), Vector2(-4.0, 9.0),
		Vector2(-9.0, 4.0), Vector2(-9.0, -4.0),
	])
	var oct_rim := PackedVector2Array([
		Vector2(-3.0, -8.0), Vector2(3.0, -8.0),
		Vector2(8.0, -3.0), Vector2(8.0, 3.0),
		Vector2(3.0, 8.0), Vector2(-3.0, 8.0),
		Vector2(-8.0, 3.0), Vector2(-8.0, -3.0),
	])
	var oct_in := PackedVector2Array([
		Vector2(-2.0, -6.0), Vector2(2.0, -6.0),
		Vector2(6.0, -2.0), Vector2(6.0, 2.0),
		Vector2(2.0, 6.0), Vector2(-2.0, 6.0),
		Vector2(-6.0, 2.0), Vector2(-6.0, -2.0),
	])
	draw_colored_polygon(oct_out, void_c)
	draw_colored_polygon(oct_rim, apr if powered else dusk)
	# Sunlit upper-left medallion bevel
	draw_rect(Rect2(-3.0, -8.0, 6.0, 1.0), cream if powered else stone)
	draw_rect(Rect2(-8.0, -3.0, 1.0, 6.0), gold if powered else mauve)
	draw_rect(Rect2(-3.0, 7.0, 6.0, 1.0), coral if powered else night)
	draw_colored_polygon(oct_in, night)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), void_c)

	if powered:
		# Unmistakable warm gold/cream pulsing toll-eye sigil (steady high-contrast when flash_reduced)
		var pulse_hi: bool = fr or (sin(_clock * 4.5) > -0.15)
		var pulse_a: float = 0.72 if fr else (0.50 + 0.35 * absf(sin(_clock * 4.5)))
		var pulse_r: float = 10.0 if fr else roundf(9.5 + 1.5 * absf(sin(_clock * 4.5)))
		draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 18, Color(gold, pulse_a), 1.2)
		# Almond / diamond glowing eye sclera & iris
		draw_rect(Rect2(-5.0, -1.0, 10.0, 2.0), apr)
		draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), gold)
		draw_rect(Rect2(-3.0, -2.0, 6.0, 4.0), cream if pulse_hi else gold)
		draw_rect(Rect2(-2.0, -3.0, 4.0, 6.0), gold)
		draw_rect(Rect2(-2.0, -1.0, 4.0, 2.0), cream)
		# Crisp dark vertical toll-eye pupil with bright starlight catchlight
		draw_rect(Rect2(-1.0, -2.0, 2.0, 4.0), void_c)
		draw_rect(Rect2(0.0, -1.0, 1.0, 1.0), cream)
		# 4 cardinal warm gold/cream pulse rays
		for sp: Vector2 in [Vector2(-8.0, 0.0), Vector2(7.0, 0.0), Vector2(0.0, -8.0), Vector2(0.0, 7.0)]:
			draw_rect(Rect2(sp, Vector2(1.0, 1.0)), cream if pulse_hi else gold)
	else:
		# Dormant closed heavy brass eyelid & recessed dark slit (clear greyscale contrast vs active!)
		draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), dusk)
		draw_rect(Rect2(-4.0, -2.0, 8.0, 1.0), mauve)
		draw_rect(Rect2(-4.0, 0.0, 8.0, 1.0), void_c)
		draw_rect(Rect2(-1.0, -3.0, 2.0, 6.0), void_c)
		if show_glyph:
			draw_rect(Rect2(0.0, -2.0, 1.0, 4.0), stone)

	_draw_signal_pulses()
