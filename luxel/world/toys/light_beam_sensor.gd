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
	if dirty:
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
	var trip: Array[Color] = LxToyDraw.color_triplet(req_color if req_color != "any" else "gold")
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -7.0, 14.0, 14.0), PAL["night"] as Color, PAL["dusk"] as Color, trip[1] if powered else PAL["mauve"] as Color, c_void)
	var main_c: Color = (PAL["coral"] as Color) if _reject_t > 0.0 else (trip[1] if powered else trip[0])
	var hi_c: Color = PAL["cream"] as Color if powered else trip[2]
	LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, _shape_for_color(), powered, main_c, hi_c)
	if powered and not LxHudFx.flash_reduced():
		draw_arc(Vector2.ZERO, 9.0, _clock * 2.0, _clock * 2.0 + PI, 10, trip[2], 1.0)
	_draw_signal_pulses()
