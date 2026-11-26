class_name LxColorGlass
extends LxToy
## Stained-glass optical filter pane: tints passing bolts, beams, and turret shots to "gold" | "blue" | "rose".
## Never blocks sight/light; optionally movable (push/pull) or interact-cyclable (`cycles_color:true`).
## Props: color ("gold"|"blue"|"rose"), size [w,h], solid (bool, default true for walking),
## movable (bool), cycles_color (bool), persist (bool).

const CYCLE_ORDER: Array[String] = ["gold", "blue", "rose"]

var glass_color: String = "blue"
var solid_walk: bool = true
var movable: bool = false
var cycles_color: bool = false
var origin_pos: Vector2 = Vector2.ZERO
var _init_color: String = "blue"
var _gleam_t: float = 0.0


func _toy_setup() -> void:
	kind = "color_glass"
	glass_color = LxToyDraw.normalize_light_color(str(props.get("color", "blue")))
	_init_color = glass_color
	if not props.has("size"):
		size = Vector2(16.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	solid_walk = bool(props.get("solid", true))
	movable = bool(props.get("movable", false))
	cycles_color = bool(props.get("cycles_color", false))
	origin_pos = pos
	_gleam_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	glass_color = _init_color
	pos = origin_pos
	position = pos.round()
	_gleam_t = 0.0
	queue_redraw()


func get_tint_color() -> String:
	return glass_color


func on_beam_pass(_in_color: String) -> void:
	_gleam_t = 0.16
	queue_redraw()


func is_solid() -> bool:
	return active and solid_walk


## Glass NEVER blocks sight or light rays.
func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func is_movable() -> bool:
	return active and movable


func get_push_rect_at(target_pos: Vector2) -> Rect2:
	var inset := Vector2(maxf(8.0, size.x - 2.0), maxf(8.0, size.y - 2.0))
	return Rect2(target_pos - inset * 0.5, inset)


func move_to(new_pos: Vector2) -> void:
	pos = new_pos
	position = new_pos.round()
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not cycles_color:
		return false
	var idx: int = CYCLE_ORDER.find(glass_color)
	glass_color = CYCLE_ORDER[(idx + 1) % CYCLE_ORDER.size()]
	_gleam_t = 0.28
	_emit_sfx("mirror_turn")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active:
		return ""
	if cycles_color:
		return "PROMPT_CYCLE_GLASS"
	if movable:
		return "PROMPT_PUSH_BLOCK"
	return ""


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	# Let passing bolts keep flying while tinting Wick's matching bolt in flight!
	if hit.source in ["bolt", "prism_bolt", "beam"]:
		_tint_passing_wick_bolts()
		_gleam_t = 0.26
		_emit_sfx("mirror_ping")
		queue_redraw()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _gleam_t > 0.0:
		_gleam_t = maxf(0.0, _gleam_t - dt)
		queue_redraw()
	if active:
		_tint_passing_wick_bolts()


func _tint_passing_wick_bolts() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var bolts_v: Variant = Lx.player.get("bolts")
	if not (bolts_v is Array):
		return
	var grect: Rect2 = rect_at(pos).grow(2.0)
	var hit_col: String = LxToyDraw.to_hit_color(glass_color)
	for b_v: Variant in (bolts_v as Array):
		if not is_instance_valid(b_v) or not (b_v is Object):
			continue
		var b: Object = b_v as Object
		var bp_v: Variant = b.get("pos")
		var pp_v: Variant = b.get("prev_pos")
		if not (bp_v is Vector2):
			continue
		var bp: Vector2 = bp_v as Vector2
		var pp: Vector2 = pp_v as Vector2 if pp_v is Vector2 else bp
		if grect.has_point(bp) or grect.has_point(pp.lerp(bp, 0.5)):
			b.set("light_color", hit_col)
			b.set("is_prism", glass_color == "blue")
			b.set("biome_tint", glass_color)
			_gleam_t = maxf(_gleam_t, 0.18)


func get_light_pool() -> Vector4:
	if not active or _gleam_t <= 0.0:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 34.0, 0.58)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["color"] = glass_color
		d["pos"] = [pos.x, pos.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("color"):
			glass_color = LxToyDraw.normalize_light_color(str(d["color"]))
		if d.has("pos"):
			move_to(LxMapFormat.to_vec2(d["pos"], pos))
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var trip: Array[Color] = LxToyDraw.color_triplet(glass_color)
	var lit: bool = _gleam_t > 0.0
	var red: bool = LxHudFx.flash_reduced()

	# Grounded contact shadow
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, floorf(h * 0.5) + 2.0), w * 0.48, 2.6)

	# Soft tinted refraction halo when active/lit
	if lit:
		draw_circle(Vector2(0.0, -1.0), maxf(w, h) * 0.56, Color(trip[1], 0.20 if red else 0.26))

	# Carved 3/4 stone plinth base holding the prism upright
	var pl_h: float = 5.0
	var pl_y: float = y0 + h - pl_h + 1.0
	draw_rect(Rect2(x0 - 1.0, pl_y, w + 2.0, pl_h + 1.0), c_void)
	draw_rect(Rect2(x0, pl_y + 2.0, w, pl_h - 2.0), c_night)
	draw_rect(Rect2(x0, pl_y + 1.0, w, 2.0), c_dusk)
	draw_rect(Rect2(x0, pl_y + 1.0, w, 1.0), c_stone)
	draw_rect(Rect2(x0 + 1.0, pl_y + 3.0, w - 2.0, 1.0), c_dusk)

	# Tall leaded stained-glass prism frame rising above the stone sill
	var fy: float = y0 - 2.0
	var fh: float = maxf(10.0, h - 1.0)
	draw_rect(Rect2(x0, fy, w, fh), c_void)
	# Outer wrought-iron / lead casing
	draw_rect(Rect2(x0 + 1.0, fy + 1.0, w - 2.0, fh - 2.0), c_dusk)
	draw_rect(Rect2(x0 + 1.0, fy + 1.0, w - 2.0, 1.0), c_stone)
	draw_rect(Rect2(x0 + 1.0, fy + 1.0, 1.0, fh - 2.0), c_mauve)
	draw_rect(Rect2(x0 + w - 2.0, fy + 2.0, 1.0, fh - 3.0), c_night)

	# Faceted stained-glass pane interior (3-step prism gradient + lead cames)
	var gx: float = x0 + 2.0
	var gy: float = fy + 2.0
	var gw: float = maxf(4.0, w - 4.0)
	var gh: float = maxf(4.0, fh - 4.0)
	draw_rect(Rect2(gx, gy, gw, gh), trip[1] if lit else trip[0])
	# Sunlit upper-left prism bevel & deeper lower-right facet
	draw_rect(Rect2(gx, gy, gw - 1.0, maxf(2.0, floorf(gh * 0.55))), trip[2] if lit else trip[1])
	draw_rect(Rect2(gx + 1.0, gy + gh - 2.0, gw - 1.0, 2.0), trip[0] if lit else c_night)
	draw_rect(Rect2(gx, gy, gw, 1.0), c_cream if lit else trip[2])
	# Fine horizontal & vertical lead-work crossbars
	var mid_x: float = floorf(gx + gw * 0.5)
	var mid_y: float = floorf(gy + gh * 0.5)
	draw_rect(Rect2(gx, mid_y, gw, 1.0), c_void)
	draw_rect(Rect2(mid_x, gy, 1.0, gh), c_void)

	# Corner lead-work gussets with brass/stone pins
	for gc: Vector2 in [
		Vector2(gx, gy),
		Vector2(gx + gw - 2.0, gy),
		Vector2(gx, gy + gh - 2.0),
		Vector2(gx + gw - 2.0, gy + gh - 2.0),
	]:
		draw_rect(Rect2(gc, Vector2(2.0, 2.0)), c_void)
		draw_rect(Rect2(gc, Vector2.ONE), c_gold if lit else c_stone)

	# Distinct colour-blind inner lead pattern: gold=diamond, blue=square, rose=triangle
	var sh_i: int = 1 if glass_color == "gold" else (3 if glass_color == "blue" else 2)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, fy + floorf(fh * 0.5)), sh_i, lit, trip[0], c_cream if lit else trip[2])

	# Crisp diagonal specular glass gleams
	draw_line(Vector2(gx + 1.0, gy + 4.0), Vector2(gx + 4.0, gy + 1.0), c_cream, 1.0, false)
	if gw >= 10.0 and gh >= 10.0:
		draw_line(Vector2(gx + gw - 5.0, gy + gh - 2.0), Vector2(gx + gw - 2.0, gy + gh - 5.0), c_cream if lit else trip[2], 1.0, false)

	# Vibrant lit refraction shimmer pips
	if lit:
		var sh_off: float = 0.0 if red else float(int(floorf(_clock * 14.0)) % 3)
		draw_rect(Rect2(gx + 2.0 + sh_off, gy + 1.0, 2.0, 1.0), c_cream)
		draw_rect(Rect2(x0 - 1.0, fy + 2.0, 1.0, 1.0), trip[2])
		draw_rect(Rect2(x0 + w, fy + gh, 1.0, 1.0), c_cream)
	if cycles_color:
		draw_rect(Rect2(-2.0, fy - 2.0, 4.0, 2.0), c_void)
		draw_rect(Rect2(-1.0, fy - 1.0, 2.0, 1.0), c_gold)
