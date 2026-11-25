class_name LxCourtSeedArch
extends LxToy
## Briar Court wordless finale monument (`court_r4`): once `briar_court_done` is set,
## the Arbiter's brass Justice Scales rest peacefully beneath a sprouting golden seed-arch
## whose roots open the Hollow Oak seal!
## Props: requires_flag ("briar_court_done").

var requires_flag: String = "briar_court_done"
var bloomed: bool = false
var _bloom_t: float = 0.0


func _toy_setup() -> void:
	kind = "court_seed_arch"
	requires_flag = str(props.get("requires_flag", "briar_court_done")).strip_edges()
	radius = 22.0
	z_index = -3
	bloomed = LxRegionLoader.check_flag_static(requires_flag)
	_bloom_t = 1.0 if bloomed else 0.0
	powered = bloomed
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var now_b: bool = LxRegionLoader.check_flag_static(requires_flag)
	if now_b and not bloomed:
		bloomed = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("ba_seed_verdict")
	if bloomed and _bloom_t < 1.0:
		_bloom_t = minf(1.0, _bloom_t + dt * 0.9)
		queue_redraw()
	elif bloomed:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active or not bloomed:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 74.0 * _bloom_t, 0.78 * _bloom_t)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Mossy inlaid court plinth always visible
	draw_circle(Vector2.ZERO, 16.0, c_void)
	draw_circle(Vector2.ZERO, 14.0, c_pine)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, c_gold if bloomed else c_dusk, 1.2)
	if not bloomed:
		draw_rect(Rect2(-3.0, -2.0, 6.0, 4.0), c_dusk)
		return

	# Laid-down brass Justice Scales + golden sprouting seed-arch
	var h: float = roundf(18.0 * _bloom_t)
	draw_line(Vector2(-10.0, 2.0), Vector2(10.0, 2.0), c_apricot, 2.0)
	draw_circle(Vector2(-10.0, 3.0), 3.0, c_gold)
	draw_circle(Vector2(10.0, 3.0), 3.0, c_gold)
	# Twin golden sapling vines curving into a glowing crown
	draw_line(Vector2(-8.0, 0.0), Vector2(-6.0, -h), c_jade, 2.5)
	draw_line(Vector2(8.0, 0.0), Vector2(6.0, -h), c_jade, 2.5)
	draw_line(Vector2(-6.0, -h), Vector2(0.0, -h - 4.0), c_lime, 2.0)
	draw_line(Vector2(6.0, -h), Vector2(0.0, -h - 4.0), c_lime, 2.0)
	draw_circle(Vector2(0.0, -h - 3.0), 4.0, c_gold)
	draw_circle(Vector2(0.0, -h - 3.0), 2.0, c_cream)
