class_name LxC4AbbessVista
extends LxToy
## Island 4 Drowned Conservatory (conservatory_r18): Wordless Scene #3 — The Bellfry Loft Bay Window.
## A stained-glass overlook peering straight down into `conservatory_r10`'s dome where the Heron Abbess
## folds her wet wings beneath falling rainlight.

var _anim_t: float = 0.0
var _seen: bool = false


func _toy_setup() -> void:
	kind = "c4_abbess_vista"
	radius = 24.0
	size = Vector2(64.0, 22.0)
	_anim_t = 0.0
	_seen = powered
	queue_redraw()


func get_interact_prompt() -> String:
	return "ISL4_C4_PROMPT_VISTA" if active else ""


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_seen = true
	if Lx.events != null and LxStrings.has_id("ISL4_C4_VISTA_LINE"):
		Lx.events.narration_requested.emit("ISL4_C4_VISTA_LINE", "narration", 3.4)
	_emit_sfx("prop_chime")
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_anim_t = fmod(_anim_t + dt * 1.4, TAU)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 52.0, 0.56)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Stained-glass bay-window casement overlooking r10 below
	LxToyDraw.draw_bevel_box(self, Rect2(-32.0, -14.0, 64.0, 22.0), c_void, c_night, c_gold, c_void)
	draw_rect(Rect2(-29.0, -11.0, 58.0, 16.0), c_deep)
	# Translucent conservatory water & dome mullions
	draw_rect(Rect2(-27.0, -9.0, 54.0, 12.0), Color(c_teal, 0.45))
	for mx: float in [-14.0, 0.0, 14.0]:
		draw_rect(Rect2(mx, -11.0, 1.0, 16.0), c_night)
	# Distant Great Lamp glow at top of dome
	draw_circle(Vector2(0.0, -7.0), 3.0, Color(c_gold, 0.72))
	draw_rect(Rect2(-1.0, -8.0, 2.0, 2.0), c_cream)
	# Heron Abbess folding her wet wings below the glass
	var fold: float = 0.0 if LxHudFx.flash_reduced() else sin(_anim_t) * 2.5
	var wing_w: float = roundf(7.0 + fold)
	draw_rect(Rect2(-wing_w, -3.0, wing_w * 2.0, 3.0), c_sky)
	draw_rect(Rect2(-2.0, -5.0, 4.0, 6.0), c_ice)
	draw_rect(Rect2(-1.0, -6.0, 2.0, 2.0), c_cream)
	# Falling silver rain streaks across the pane
	if not LxHudFx.flash_reduced():
		for k: int in range(5):
			var rx: float = -22.0 + float(k) * 11.0
			var ry: float = -10.0 + fposmod(_anim_t * 6.0 + float(k) * 3.0, 11.0)
			draw_rect(Rect2(roundf(rx), roundf(ry), 1.0, 3.0), Color(c_ice, 0.55))
	_draw_signal_pulses()
