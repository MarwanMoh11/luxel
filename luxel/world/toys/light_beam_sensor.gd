class_name LxBeamSensor
extends LxToy
## Optical crystal receiver powered when struck by a matching-colour beam (or matching player beam/bolt).
## Colour-blind safe: distinct socket geometry per colour ("any"=circle, "gold"=diamond, "blue"=square, "rose"=triangle).
## Props: color ("any"|"gold"|"blue"|"rose"), hold (bool, default true), latch (bool), persist (bool), target_id/target_ids.

const GRACE_S: float = 0.16

var req_color: String = "any"
var hold_mode: bool = true
var latch_mode: bool = false
var _lit_grace: float = 0.0
var _reject_t: float = 0.0


func _toy_setup() -> void:
	kind = "beam_sensor"
	var raw_c: String = str(props.get("color", "any")).strip_edges().to_lower()
	if raw_c.is_empty() or raw_c == "any":
		req_color = "any"
	else:
		req_color = LxToyDraw.normalize_light_color(raw_c)
	latch_mode = bool(props.get("latch", false))
	hold_mode = bool(props.get("hold", not latch_mode))
	if latch_mode and not props.has("hold"):
		hold_mode = false
	radius = maxf(10.0, radius)
	_lit_grace = GRACE_S if powered else 0.0
	_reject_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	_lit_grace = 0.0
	_reject_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		dirty = true
	if powered and hold_mode and not latch_mode:
		_lit_grace -= dt
		if _lit_grace <= 0.0:
			set_powered(false)
			emit_power(false)
			dirty = true
	if dirty or (powered and not LxHudFx.flash_reduced()):
		queue_redraw()


func receive_beam(in_color: String, _from_id: String = "") -> bool:
	if not active:
		return false
	var norm: String = LxToyDraw.normalize_light_color(in_color)
	if req_color != "any" and norm != req_color:
		_reject_t = 0.20
		queue_redraw()
		return false
	_lit_grace = GRACE_S
	if not powered:
		set_powered(true)
		emit_power(true)
		_emit_sfx("switch_eye")
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source not in ["beam", "bolt", "prism_bolt", "sunflare"]:
		return false
	var hcol: String = LxToyDraw.normalize_light_color(hit.light_color)
	if hit.source == LxHit.SOURCE_PRISM:
		hcol = "blue"
	if req_color != "any" and hcol != req_color:
		_reject_t = 0.25
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	_lit_grace = maxf(GRACE_S, 0.35)
	if not powered:
		set_powered(true)
		emit_power(true)
		_emit_sfx("switch_eye")
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not active or not powered:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 2.0, 42.0, 0.78)


func _shape_for_color() -> int:
	match req_color:
		"gold": return 1 # Diamond
		"blue": return 3 # Square
		"rose": return 2 # Triangle
		_: return 0      # Circle ("any")


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var trip: Array[Color] = LxToyDraw.color_triplet(req_color if req_color != "any" else "gold")
	var red: bool = LxHudFx.flash_reduced()
	var rej: bool = _reject_t > 0.0

	# Grounded contact shadow
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.8)

	# Carved 3/4 octagonal stone plinth base
	draw_rect(Rect2(-8.0, -3.0, 16.0, 10.0), c_void)
	draw_rect(Rect2(-6.0, -7.0, 12.0, 14.0), c_void)
	draw_rect(Rect2(-7.0, 3.0, 14.0, 3.0), c_night)
	draw_rect(Rect2(-7.0, -2.0, 14.0, 5.0), c_dusk)
	draw_rect(Rect2(-5.0, -6.0, 10.0, 11.0), c_dusk)
	# Sunlit top & left plinth lip
	draw_rect(Rect2(-5.0, -6.0, 10.0, 1.0), c_stone)
	draw_rect(Rect2(-7.0, -2.0, 1.0, 5.0), c_mauve)
	draw_rect(Rect2(-5.0, 4.0, 10.0, 1.0), c_night)

	# Faceted crystal dish receptor recessed into plinth
	var dish_out: Color = (PAL["coral"] as Color) if rej else (trip[1] if powered else (c_blue if req_color == "any" else trip[0]))
	var dish_mid: Color = (PAL["apricot"] as Color) if rej else (c_gold if (powered and req_color == "any") else (trip[2] if powered else (c_mauve if req_color == "any" else trip[1])))
	var dish_hi: Color = c_cream if powered else (c_sky if req_color == "any" else trip[2])
	var dish_sh: Color = c_deep if (not powered and req_color == "any") else (trip[0] if powered else c_night)

	draw_rect(Rect2(-5.0, -5.0, 10.0, 9.0), c_void)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 7.0), dish_sh)
	# Chamfered crystal facets
	draw_rect(Rect2(-3.0, -4.0, 6.0, 6.0), dish_out)
	draw_rect(Rect2(-4.0, -3.0, 8.0, 4.0), dish_out)
	draw_rect(Rect2(-3.0, -3.0, 5.0, 4.0), dish_mid)
	draw_rect(Rect2(-3.0, -3.0, 3.0, 2.0), dish_hi)
	draw_rect(Rect2(-3.0, -3.0, 1.0, 1.0), c_cream if powered else c_ice)

	# Four corner retaining prongs clasping the crystal dish
	var prong_c: Color = c_gold if powered else c_stone
	var prong_sh: Color = PAL["apricot"] as Color if powered else c_mauve
	for pr: Vector2 in [Vector2(-7.0, -7.0), Vector2(5.0, -7.0), Vector2(-7.0, 3.0), Vector2(5.0, 3.0)]:
		draw_rect(Rect2(pr, Vector2(3.0, 3.0)), c_void)
		draw_rect(Rect2(pr.x + 1.0, pr.y + 1.0, 1.0, 1.0), prong_c if pr.y < 0.0 else prong_sh)
	# Inner claw tips biting onto the dish rim
	draw_rect(Rect2(-5.0, -5.0, 1.0, 1.0), prong_c)
	draw_rect(Rect2(4.0, -5.0, 1.0, 1.0), prong_c)
	draw_rect(Rect2(-5.0, 3.0, 1.0, 1.0), prong_sh)
	draw_rect(Rect2(4.0, 3.0, 1.0, 1.0), prong_sh)

	# Colour-blind safe inner receptor socket glyph
	var g_main: Color = (PAL["coral"] as Color) if rej else (trip[1] if powered else dish_out)
	var g_hi: Color = c_cream if powered else dish_hi
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -1.0), _shape_for_color(), powered, g_main, g_hi)

	# Radiant gold/cream core glow + cardinal optical rays when powered
	if powered:
		var ray_len: float = 4.0 if (red or int(floorf(_clock * 6.0)) % 2 == 0) else 3.0
		var ray_c: Color = c_gold if req_color == "any" else trip[1]
		draw_circle(Vector2(0.0, -1.0), 8.0, Color(ray_c, 0.22))
		# Cardinal rays (N, S, E, W)
		draw_rect(Rect2(-1.0, -7.0 - ray_len, 2.0, ray_len), ray_c)
		draw_rect(Rect2(0.0, -7.0 - ray_len, 1.0, ray_len), c_cream)
		draw_rect(Rect2(-1.0, 6.0, 2.0, ray_len), ray_c)
		draw_rect(Rect2(0.0, 6.0, 1.0, ray_len), c_cream)
		draw_rect(Rect2(-7.0 - ray_len, -2.0, ray_len, 2.0), ray_c)
		draw_rect(Rect2(-7.0 - ray_len, -1.0, ray_len, 1.0), c_cream)
		draw_rect(Rect2(7.0, -2.0, ray_len, 2.0), ray_c)
		draw_rect(Rect2(7.0, -1.0, ray_len, 1.0), c_cream)
		if not red:
			var ang: float = _clock * 2.4
			for k: int in range(2):
				var sp: Vector2 = (Vector2(0.0, -1.0) + Vector2(cos(ang + float(k) * PI), sin(ang + float(k) * PI)) * 9.0).round()
				draw_rect(Rect2(sp, Vector2.ONE), c_cream)
	_draw_signal_pulses()
