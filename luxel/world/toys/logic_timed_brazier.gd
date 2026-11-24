class_name LxTimedBrazier
extends LxToy
## Timed brazier that burns for `secs` then snuffs out, OR acts as a room/puzzle reset brazier when `reset:true`.
## Props: secs (float, default 6.0), reset (bool), allow_interact (bool), persist (bool), target_id/target_ids.

var secs: float = 6.0
var is_reset_brazier: bool = false
var lit: bool = false
var time_left: float = 0.0
var _ignite_t: float = 0.0
var _reset_flash_t: float = 0.0
var _flicker_frame: int = 0


func _toy_setup() -> void:
	kind = "timed_brazier"
	secs = maxf(0.0, float(props.get("secs", 6.0)))
	is_reset_brazier = bool(props.get("reset", false))
	lit = bool(props.get("lit", powered))
	time_left = secs if lit else 0.0
	powered = lit
	radius = maxf(12.0, radius)
	_ignite_t = 0.0
	_reset_flash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if is_reset_brazier or (persist and lit):
		return
	if lit:
		_extinguish(false)


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		dirty = true
	if _reset_flash_t > 0.0:
		_reset_flash_t = maxf(0.0, _reset_flash_t - dt)
		dirty = true
	if lit and secs > 0.0 and not is_reset_brazier:
		time_left -= dt
		dirty = true
		if time_left <= 0.0:
			_extinguish(true)
	if lit:
		var rate: float = 4.0 if LxHudFx.flash_reduced() else 10.0
		var fr: int = int(floorf(_clock * rate + absf(pos.x * 0.05))) % 4
		if fr != _flicker_frame:
			_flicker_frame = fr
			dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return _trigger()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or is_reset_brazier or light_radius <= 0.0:
		return
	if source in ["thrown_lantern", "lantern_hung", "lantern_fly", "lantern_recall", "beam", "sunflare"]:
		_trigger()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if is_reset_brazier or bool(props.get("allow_interact", false)):
		return _trigger()
	return false


func get_interact_prompt() -> String:
	if not active:
		return ""
	if is_reset_brazier:
		return "PROMPT_RESET_PUZZLE"
	if not lit and bool(props.get("allow_interact", false)):
		return "PROMPT_IGNITE"
	return ""


func _trigger() -> bool:
	if is_reset_brazier:
		_reset_flash_t = 0.40
		LxToyDraw.trigger_room_reset(self)
		_emit_sfx("prop_chime")
		_emit_gust(48.0, 32.0, Vector2(0.0, -8.0))
		queue_redraw()
		return true
	var was_lit: bool = lit
	lit = true
	time_left = secs
	_ignite_t = 0.30
	if not was_lit:
		set_powered(true)
		_notify_linked_targets(true)
		_emit_sfx("brazier_lit")
		_emit_gust(52.0, 38.0, Vector2(0.0, -10.0))
	else:
		_emit_sfx("lamp_lit")
	queue_redraw()
	return true


func _extinguish(play_sfx: bool) -> void:
	lit = false
	time_left = 0.0
	set_powered(false)
	_notify_linked_targets(false)
	if play_sfx:
		_emit_sfx("snuffer_snuff")
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if is_reset_brazier:
		var r_f: float = 44.0 if _reset_flash_t > 0.0 else 28.0
		return Vector4(pos.x, pos.y - 6.0, r_f, 0.75 if _reset_flash_t > 0.0 else 0.42)
	if not lit:
		return Vector4.ZERO
	var frac: float = clampf(time_left / maxf(secs, 0.01), 0.25, 1.0) if secs > 0.0 else 1.0
	return Vector4(pos.x, pos.y - 8.0, 56.0 * (0.55 + 0.45 * frac), 0.65 + 0.45 * frac)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["lit"] = lit
		d["time_left"] = time_left
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("lit"):
		lit = bool(d["lit"])
		time_left = float(d.get("time_left", secs if lit else 0.0))
		powered = lit
		if lit:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, "blue" if is_reset_brazier else skin)
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 2.5)
	# Pedestal base
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, 0.0, 12.0, 6.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["mauve"] as Color, c_void)
	# Bowl
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -6.0, 14.0, 6.0), trip[0], trip[1], trip[2], c_void)

	if is_reset_brazier:
		# Reset emblem: cool ice flame + circular reset motif
		var rc: Color = c_cream if _reset_flash_t > 0.0 else (PAL["ice"] as Color)
		draw_rect(Rect2(-3.0, -9.0, 6.0, 3.0), PAL["blue"] as Color)
		draw_rect(Rect2(-2.0, -11.0, 4.0, 4.0), PAL["sky"] as Color)
		draw_rect(Rect2(-1.0, -12.0, 2.0, 3.0), rc)
		LxToyDraw.draw_shape_glyph(self, Vector2(0.0, 3.0), 0, _reset_flash_t > 0.0, PAL["sky"] as Color, rc)
	elif lit:
		var frac: float = clampf(time_left / maxf(secs, 0.01), 0.0, 1.0) if secs > 0.0 else 1.0
		var warn: bool = secs > 0.0 and frac < 0.28
		var fl_h: float = roundf(lerpf(3.0, 8.0, frac))
		var sway: float = 0.0 if LxHudFx.flash_reduced() else (1.0 if _flicker_frame % 2 == 0 else -1.0)
		var outer_c: Color = c_coral if warn else (PAL["apricot"] as Color)
		var inner_c: Color = c_gold if not warn else c_coral
		draw_rect(Rect2(-4.0, -6.0 - fl_h, 8.0, fl_h), outer_c)
		draw_rect(Rect2(-2.0 + sway * 0.5, -5.0 - fl_h, 4.0, maxf(2.0, fl_h - 1.0)), inner_c)
		draw_rect(Rect2(-1.0 + sway, -6.0 - fl_h - 1.0, 2.0, 2.0), c_cream)
		if secs > 0.0:
			LxToyDraw.draw_bar(self, Vector2(-7.0, 7.0), 14.0, frac, c_gold, c_coral)
	else:
		# Cold coals + hourglass pip showing it's a timed brazier
		draw_rect(Rect2(-4.0, -7.0, 8.0, 2.0), PAL["night"] as Color)
		draw_rect(Rect2(-2.0, -7.0, 4.0, 1.0), PAL["plum"] as Color)
		draw_rect(Rect2(-2.0, 2.0, 4.0, 1.0), c_gold)
		draw_rect(Rect2(-1.0, 3.0, 2.0, 1.0), PAL["apricot"] as Color)
		draw_rect(Rect2(-2.0, 4.0, 4.0, 1.0), c_gold)

	if _ignite_t > 0.0:
		var u: float = 1.0 - clampf(_ignite_t / 0.30, 0.0, 1.0)
		var r: float = roundf(lerpf(4.0, 13.0, u))
		draw_arc(Vector2(0.0, -8.0), r, 0.0, TAU, 14, c_cream if u < 0.4 else c_gold, 1.0)
	_draw_signal_pulses()
