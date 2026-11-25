class_name LxKilnDamperGauge
extends LxToy
## Diegetic Heat-Flow Conduit Gauge for the Great Kiln Casting Wing (`kiln_r11`, `kiln_r12`, `kiln_r16`).
## Visually displays `dungeon:great_kiln/kiln_heat` ("low" = ice/stone crusted, "surge" = coral/gold flowing)
## with zero text clutter so players read the macro heat state immediately on room entry.

var _surge: bool = false


func _toy_setup() -> void:
	kind = "kiln_damper_gauge"
	size = Vector2(20.0, 16.0)
	radius = 12.0
	z_index = -2
	_sync_heat()
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func _sync_heat() -> void:
	var now_surge: bool = LxIsland6Rule.get_kiln_heat() == "surge"
	if now_surge != _surge:
		_surge = now_surge
		set_powered(_surge)
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	_sync_heat()
	if not LxHudFx.flash_reduced():
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 46.0 if _surge else 26.0, 0.72 if _surge else 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -8.0, 20.0, 16.0), c_night, c_dusk, c_gold if _surge else PAL["sky"] as Color, c_void)
	# Pressure dial glass
	draw_rect(Rect2(-7.0, -5.0, 14.0, 10.0), c_void)
	if _surge:
		draw_rect(Rect2(-6.0, -4.0, 12.0, 8.0), c_coral)
		draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), c_gold)
		var px: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 6.0) * 2.0)
		draw_rect(Rect2(px - 1.0, -1.0, 2.0, 2.0), c_cream)
	else:
		draw_rect(Rect2(-6.0, -4.0, 12.0, 8.0), PAL["deep"] as Color)
		draw_rect(Rect2(-4.0, 0.0, 8.0, 3.0), PAL["teal"] as Color)
		draw_rect(Rect2(-2.0, 1.0, 4.0, 1.0), c_ice)
	_draw_signal_pulses()
