class_name LxTheatreVanityMirror
extends LxToy
## Royal Box Dressing Mirror (`theatre_r11` wordless horror beat):
## Reflects Wick's silhouette with a 0.5s delay — and when Wick passes or gazes in,
## the reflection smiles half a beat late and points north toward The Understudy below!

const DELAY_S: float = 0.50

var _history: Array[Dictionary] = []
var _smile_t: float = 0.0
var _seen_beat: bool = false
var _auto_triggered: bool = false


func _toy_setup() -> void:
	kind = "theatre_vanity_mirror"
	size = Vector2(22.0, 28.0)
	radius = 20.0
	_history.clear()
	_smile_t = 0.0
	_seen_beat = false
	_auto_triggered = false
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-9.0, -6.0), Vector2(18.0, 12.0)) if is_solid() else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_trigger_grin_beat(true)
	return true


func get_interact_prompt() -> String:
	return "ISL7_TH_PROMPT_MIRROR" if active else ""


func _trigger_grin_beat(explicit: bool) -> void:
	_smile_t = 2.0
	_emit_sfx("shadow_whisper")
	if not _seen_beat or explicit:
		_seen_beat = true
		set_powered(true)
		emit_power(true)
		if Lx.events != null and LxStrings.has_id("ISL7_TH_VANITY_BEAT"):
			Lx.events.narration_requested.emit("ISL7_TH_VANITY_BEAT", "narration", 2.8)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var wp: Vector2 = wick_pos()
	if wp.x > -9000.0:
		var rel: Vector2 = wp - pos
		_history.append({"t": _clock, "rel": rel})
		while _history.size() > 60 and (_clock - float(_history[0]["t"])) > 1.2:
			_history.pop_front()
		if not _auto_triggered and rel.length() <= 44.0:
			_auto_triggered = true
			_trigger_grin_beat(false)
	if _smile_t > 0.0:
		_smile_t = maxf(0.0, _smile_t - dt)
	queue_redraw()


func _delayed_rel() -> Vector2:
	if _history.is_empty():
		return Vector2(0.0, 20.0)
	var target_t: float = _clock - DELAY_S
	var best: Vector2 = _history[0]["rel"] as Vector2
	for s: Dictionary in _history:
		if float(s["t"]) <= target_t:
			best = s["rel"] as Vector2
		else:
			break
	return best


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 38.0 if _smile_t > 0.0 else 28.0, 0.62 if _smile_t > 0.0 else 0.42)


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color

	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 7.0), 11.0, 3.0, "nw_wrong", false)
	# Ornate gilded dressing mirror frame
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -20.0, 20.0, 26.0), c_night, c_wine, c_gold, c_void)
	draw_rect(Rect2(-8.0, -18.0, 16.0, 22.0), c_night)
	draw_rect(Rect2(-7.0, -17.0, 14.0, 20.0), c_sky)
	draw_rect(Rect2(-6.0, -16.0, 12.0, 18.0), c_night)
	# Delayed mirrored Wick silhouette inside glass (pixel-snapped)
	var fr: bool = LxHudFx.flash_reduced()
	var drel: Vector2 = _delayed_rel()
	var rx: float = roundf(clampf(drel.x * 0.14, -3.5, 3.5))
	var ry: float = roundf(-7.0 + clampf(drel.y * 0.05, -2.0, 2.0))
	draw_rect(Rect2(rx - 3.0, ry - 4.0, 6.0, 8.0), c_void)
	draw_rect(Rect2(rx - 2.0, ry - 3.0, 4.0, 6.0), c_wine)
	# Eyes & late eerie coral smile + pointing hand north
	draw_rect(Rect2(rx - 1.0, ry - 2.0, 1.0, 1.0), c_cream)
	draw_rect(Rect2(rx + 1.0, ry - 2.0, 1.0, 1.0), c_cream)
	if _smile_t > 0.0:
		var sa: float = 0.72 if fr else (0.78 + 0.22 * absf(sin(_clock * 8.0)))
		draw_line(Vector2(rx - 2.0, ry + 1.0), Vector2(rx + 2.0, ry + 1.0), Color(c_coral, sa), 1.0)
		draw_rect(Rect2(rx - 1.0, ry - 6.0, 2.0, 2.0), Color(c_gold, sa))
		# Subtle north-pointing finger glint toward The Understudy
		draw_rect(Rect2(rx, ry - 8.0, 1.0, 2.0), Color(c_cream, sa))
	# Mirror sheen diagonal
	draw_line(Vector2(-6.0, -14.0), Vector2(-2.0, -17.0), Color(c_ice, 0.55), 1.0)
	# Vanity footlights
	draw_rect(Rect2(-7.0, -19.0, 2.0, 2.0), c_gold)
	draw_rect(Rect2(5.0, -19.0, 2.0, 2.0), c_gold)
	_draw_signal_pulses()
