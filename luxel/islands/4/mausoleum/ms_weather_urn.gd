class_name LxMsWeatherUrn
extends LxToy
## Weather-Tuned Choral Singing Urn (mausoleum_r9 Tuning Nave):
## Teaches The Drowned Choir's sequence-silencing mechanic!
## Each urn has a Roman pip order (`urn_index` 1..4) and a required weather (`sun|rain|wind`).
## Only EXPOSED when active weather matches `weather_req` (otherwise veiled in mist/water).
## Silence all urns in `group` in exact order `1 -> 2 -> 3 -> 4` to unlock the Choir Arch!
## Props: urn_index (int 1..4), weather_req ("sun"|"rain"|"wind"), group (String), total (int 4),
## sets_flag (String), persist (bool), target_id/target_ids.

const URN_NOTES: Array[String] = ["choir_note_1", "choir_note_2", "choir_note_3", "choir_note_4"]

var urn_index: int = 1
var weather_req: String = "sun"
var group_name: String = "r9_choir"
var total_urns: int = 4

var silenced: bool = false
var solved: bool = false
var _flash_t: float = 0.0
var _err_t: float = 0.0


func _toy_setup() -> void:
	kind = "ms_weather_urn"
	urn_index = clampi(int(props.get("urn_index", 1)), 1, 5)
	weather_req = str(props.get("weather_req", "sun")).strip_edges().to_lower()
	group_name = str(props.get("group", "r9_choir")).strip_edges()
	total_urns = clampi(int(props.get("total", 4)), 1, 5)
	radius = maxf(13.0, radius)
	var sf: String = str(props.get("sets_flag", "")).strip_edges()
	var already_done: bool = not sf.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sf, false))
	solved = powered or already_done
	silenced = solved
	powered = solved
	_flash_t = 0.0
	_err_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and solved:
		return
	silenced = false
	solved = false
	_flash_t = 0.0
	_err_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func on_weather_changed(_new_weather: String, _wind_dir: Vector2) -> void:
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _err_t > 0.0:
		_err_t = maxf(0.0, _err_t - dt)
		dirty = true
	if not silenced and is_next_in_order():
		dirty = true
	if dirty:
		queue_redraw()


func is_exposed() -> bool:
	var w: String = _current_weather()
	return weather_req == "any" or w == weather_req


func is_next_in_order() -> bool:
	if solved or silenced:
		return false
	return _group_silenced_count() + 1 == urn_index


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or solved:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return _attempt_silence()
	return false


func interact(_actor: Node = null) -> bool:
	if not active or solved:
		return false
	return _attempt_silence()


func _attempt_silence() -> bool:
	if silenced or solved:
		return false
	if not is_exposed():
		_err_t = 0.42
		_emit_sfx("choir_discord")
		queue_redraw()
		return true
	var expected: int = _group_silenced_count() + 1
	if urn_index == expected:
		silenced = true
		_flash_t = 0.45
		var note_sfx: String = URN_NOTES[clampi(urn_index - 1, 0, URN_NOTES.size() - 1)]
		_emit_sfx(note_sfx)
		_emit_gust(48.0, 34.0)
		if _group_silenced_count() >= total_urns:
			_complete_group()
		queue_redraw()
		return true
	# Wrong order: reset all urns in this group!
	_reset_group_error()
	return true


func _group_urns() -> Array[LxMsWeatherUrn]:
	var out: Array[LxMsWeatherUrn] = []
	if region == null or not region.has_method("get_interactables"):
		out.append(self)
		return out
	for it_v: Variant in (region.call("get_interactables") as Array):
		if it_v is LxMsWeatherUrn and is_instance_valid(it_v):
			var u: LxMsWeatherUrn = it_v as LxMsWeatherUrn
			if u.group_name == group_name:
				out.append(u)
	return out


func _group_silenced_count() -> int:
	var n: int = 0
	for u: LxMsWeatherUrn in _group_urns():
		if u.silenced:
			n += 1
	return n


func _reset_group_error() -> void:
	_emit_sfx("choir_discord")
	for u: LxMsWeatherUrn in _group_urns():
		if not u.solved:
			u.silenced = false
			u._err_t = 0.45
			u.queue_redraw()


func _complete_group() -> void:
	_emit_sfx("drowned_choir_chord")
	for u: LxMsWeatherUrn in _group_urns():
		u.silenced = true
		u.solved = true
		u._flash_t = 0.65
		var sf: String = str(u.props.get("sets_flag", "")).strip_edges()
		if not sf.is_empty() and Lx.state != null:
			Lx.state.story_flags[sf] = true
		u.set_powered(true)
		u.emit_power(true)
		u.queue_redraw()


func _current_weather() -> String:
	if Lx.vars != null:
		return str(Lx.vars.resolve_var("weather", island_id, region_id, "rain")).strip_edges().to_lower()
	return "rain"


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if silenced or solved:
		return Vector4(pos.x, pos.y - 4.0, 44.0, 0.78)
	if is_exposed() and is_next_in_order():
		return Vector4(pos.x, pos.y - 4.0, 38.0, 0.62)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["solved"] = solved
		d["silenced"] = silenced
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("solved"):
		solved = bool(d["solved"])
		silenced = bool(d.get("silenced", solved))
		powered = solved
		if solved:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color

	var exp: bool = is_exposed()
	var is_nxt: bool = is_next_in_order()
	var w_col: Color = c_gold if weather_req == "sun" else (c_sky if weather_req == "rain" else c_lime)

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 3.0)
	# Pulsing harmonic floor halo for next-in-sequence or silenced urn
	if (is_nxt or silenced) and not _err_t > 0.0:
		var hr: float = 12.0 + (0.0 if (LxHudFx.flash_reduced() or silenced) else sin(_clock * 6.0) * 1.5)
		draw_arc(Vector2.ZERO, roundf(hr), 0.0, TAU, 16, c_cream if silenced else (w_col if exp else PAL["mauve"] as Color), 1.5 if (is_nxt and exp) else 1.0)

	# Carved choral pedestal + porcelain singing bust-urn
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -1.0, 14.0, 8.0), c_night, c_dusk, c_gold if silenced else c_stone, c_void)
	var body_c: Color = c_coral if _err_t > 0.0 else (c_cream if _flash_t > 0.0 else (c_ice if (exp or silenced) else PAL["mauve"] as Color))
	draw_circle(Vector2(0.0, -7.0), 6.0, c_void)
	draw_circle(Vector2(0.0, -7.0), 5.0, body_c)

	if silenced:
		# Closed peaceful eyes + warm gold chime crown
		draw_line(Vector2(-3.0, -8.0), Vector2(-1.0, -8.0), c_night, 1.0)
		draw_line(Vector2(1.0, -8.0), Vector2(3.0, -8.0), c_night, 1.0)
		draw_rect(Rect2(-2.0, -13.0, 4.0, 2.0), c_gold)
	elif exp:
		# Open singing mouth ring in weather color
		draw_circle(Vector2(0.0, -5.0), 2.2 if is_nxt else 1.5, w_col)
		draw_circle(Vector2(0.0, -5.0), 0.9, c_void)
	else:
		# Veiled in rain/mist bars showing it cannot be silenced in this weather
		draw_rect(Rect2(-5.0, -10.0, 10.0, 6.0), Color(PAL["deep"] as Color, 0.65))
		draw_line(Vector2(-4.0, -9.0), Vector2(4.0, -5.0), PAL["mauve"] as Color, 1.0)

	# Weather crest icon above urn (gold cross = SUN, sky drops = RAIN, lime bars = WIND)
	var iy: float = -17.0
	match weather_req:
		"sun":
			draw_rect(Rect2(-2.0, iy, 5.0, 1.0), w_col)
			draw_rect(Rect2(0.0, iy - 2.0, 1.0, 5.0), w_col)
		"rain":
			draw_rect(Rect2(-2.0, iy - 1.0, 1.0, 2.0), w_col)
			draw_rect(Rect2(0.0, iy - 2.0, 1.0, 3.0), c_ice)
			draw_rect(Rect2(2.0, iy, 1.0, 2.0), w_col)
		"wind":
			draw_rect(Rect2(-2.0, iy - 1.0, 4.0, 1.0), w_col)
			draw_rect(Rect2(-1.0, iy + 1.0, 4.0, 1.0), c_ice)

	# Roman order pips along plinth bottom (1..4 pips)
	for pi: int in range(urn_index):
		var px: float = -float(urn_index - 1) * 1.5 + float(pi) * 3.0
		draw_rect(Rect2(roundf(px), 3.0, 2.0, 2.0), c_cream if silenced else w_col)
	_draw_signal_pulses()
