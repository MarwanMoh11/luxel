class_name LxHgRoseGhost
extends LxToy
## Hourglass Maze Wordless Scene (hourglass_r11 — Sand-Glass Promenade):
## Auto-looping golden rose-ghost of The Gardener tenderly pruning a single glass flower
## twice before wilting into falling golden sand (foreshadowing Boss Phase 2).

const CYCLE_SECS: float = 6.4

var _cycle_t: float = 0.0
var _snip1_done: bool = false
var _snip2_done: bool = false


func _toy_setup() -> void:
	kind = "hg_rose_ghost"
	radius = 18.0
	active = true
	visible = true
	_cycle_t = 0.0
	_snip1_done = false
	_snip2_done = false
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var prev_t: float = _cycle_t
	_cycle_t = fmod(_cycle_t + dt, CYCLE_SECS)
	if _cycle_t < prev_t:
		_snip1_done = false
		_snip2_done = false
	if not _snip1_done and _cycle_t >= 1.8:
		_snip1_done = true
		if wick_pos().distance_to(pos) <= 130.0:
			_emit_sfx("hg_rose_prune")
	if not _snip2_done and _cycle_t >= 3.4:
		_snip2_done = true
		if wick_pos().distance_to(pos) <= 130.0:
			_emit_sfx("hg_rose_prune")
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var pulse: float = 0.65 if LxHudFx.flash_reduced() else (0.58 + 0.14 * sin(_clock * 2.4))
	return Vector4(pos.x, pos.y - 6.0, 44.0, pulse)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_jade: Color = PAL["jade"] as Color

	# Pedestal planter with single glass rose on the right (+14, 0)
	LxToyDraw.draw_contact_shadow(self, Vector2(14.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(8.0, 0.0, 12.0, 6.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(13.0, -7.0, 2.0, 7.0), c_jade)
	var rose_wilted: bool = _cycle_t >= 4.4
	if not rose_wilted:
		draw_rect(Rect2(10.0, -13.0, 8.0, 7.0), c_void)
		draw_rect(Rect2(11.0, -12.0, 6.0, 5.0), c_rose if _cycle_t < 3.4 else c_gold)
		draw_rect(Rect2(12.0, -11.0, 4.0, 3.0), c_cream if _cycle_t >= 3.4 else c_apricot)
	else:
		# Falling golden sand petals
		var fall_u: float = clampf((_cycle_t - 4.4) / 1.8, 0.0, 1.0)
		for k: int in range(5):
			var px: float = roundf(10.0 + float(k) * 2.0 + sin(_clock * 4.0 + float(k)) * 1.5)
			var py: float = roundf(-11.0 + fall_u * (14.0 + float(k % 3) * 2.0))
			draw_rect(Rect2(px, py, 2.0, 2.0), c_gold if k % 2 == 0 else c_cream)

	# Golden Gardener ghost stepping in from (-16, 0) -> (-2, 0), pruning twice, dissolving to sand
	var ghost_a: float = 0.72 if LxHudFx.flash_reduced() else 0.85
	var gx: float = -16.0
	if _cycle_t < 1.2:
		gx = lerpf(-18.0, -4.0, _cycle_t / 1.2)
	elif _cycle_t < 4.4:
		gx = -4.0
	else:
		gx = -4.0
		ghost_a *= clampf(1.0 - (_cycle_t - 4.4) / 1.6, 0.0, 1.0)

	if ghost_a > 0.06:
		var gp := Vector2(roundf(gx), 0.0)
		LxToyDraw.draw_contact_shadow(self, gp + Vector2(0.0, 5.0), 6.0, 2.0)
		# Coat & cloche dome silhouette
		draw_rect(Rect2(gp.x - 5.0, gp.y - 18.0, 10.0, 19.0), Color(c_wine, ghost_a * 0.7))
		draw_rect(Rect2(gp.x - 4.0, gp.y - 17.0, 8.0, 16.0), Color(c_apricot, ghost_a))
		draw_rect(Rect2(gp.x - 3.0, gp.y - 16.0, 6.0, 12.0), Color(c_gold, ghost_a))
		draw_circle(gp + Vector2(0.0, -21.0), 4.5, Color(c_ice, ghost_a * 0.85))
		draw_rect(Rect2(gp.x - 2.0, gp.y - 22.0, 1.0, 1.0), Color(c_cream, ghost_a))
		draw_rect(Rect2(gp.x + 1.0, gp.y - 22.0, 1.0, 1.0), Color(c_cream, ghost_a))
		# Twin golden shears snipping at t=1.8s and t=3.4s
		var snip_flash: bool = (_cycle_t >= 1.70 and _cycle_t <= 2.05) or (_cycle_t >= 3.30 and _cycle_t <= 3.65)
		var sx: float = gp.x + (11.0 if snip_flash else 8.0)
		draw_line(gp + Vector2(3.0, -11.0), Vector2(sx, gp.y - (10.0 if snip_flash else 13.0)), Color(c_cream if snip_flash else c_gold, ghost_a), 1.5)
		draw_line(gp + Vector2(3.0, -9.0), Vector2(sx, gp.y - (10.0 if snip_flash else 7.0)), Color(c_cream if snip_flash else c_rose, ghost_a), 1.5)
		if snip_flash and not LxHudFx.flash_reduced():
			draw_arc(Vector2(14.0, -10.0), 7.0, 0.0, TAU, 12, Color(c_cream, 0.8), 1.0)
