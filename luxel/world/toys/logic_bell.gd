class_name LxBell
extends LxToy
## Resonant island bell (dawn / dusk / war) that emits an occluded LxRingWave when struck or rung.
## Supports Echo Clapper (Island 1 `item_echo_clapper` flag: throw/zip strikes emit a 1.4 s delayed
## second LxRingWave with a diegetic countdown ring) and relay chains (with anti-loop chain_ids).
## Props: tone ("dawn"|"dusk"|"war"), wave_radius (float), speed (float), cooldown (float),
## relay (bool), echo_delay (float, default 1.4), echo_enabled (bool), target_id/target_ids.

const DEFAULT_ECHO_DELAY: float = 1.4

var tone: String = "dawn"
var wave_radius: float = 176.0
var wave_speed: float = 135.0
var cooldown: float = 0.45
var relay: bool = false
var ring_count: int = 0
var echo_count: int = 0
var echo_delay_s: float = DEFAULT_ECHO_DELAY

var _cd_left: float = 0.0
var _swing_t: float = 0.0
var _relay_delay: float = -1.0
var _relay_chain: PackedStringArray = PackedStringArray()
var _clapper_echo_left: float = -1.0
var _clapper_echo_total: float = DEFAULT_ECHO_DELAY
var _waves: Array[LxRingWave] = []


func _toy_setup() -> void:
	kind = "bell"
	tone = str(props.get("tone", "dawn")).strip_edges().to_lower()
	if tone not in ["dawn", "dusk", "war"]:
		tone = "dawn"
	wave_radius = maxf(32.0, float(props.get("wave_radius", props.get("range", 176.0))))
	wave_speed = maxf(32.0, float(props.get("speed", 135.0)))
	cooldown = maxf(0.15, float(props.get("cooldown", 0.45)))
	relay = bool(props.get("relay", false))
	echo_delay_s = maxf(0.2, float(props.get("echo_delay", DEFAULT_ECHO_DELAY)))
	radius = maxf(12.0, radius)
	_cd_left = 0.0
	_swing_t = 0.0
	_relay_delay = -1.0
	_relay_chain = PackedStringArray()
	_clapper_echo_left = -1.0
	_clapper_echo_total = echo_delay_s
	_clear_waves()
	queue_redraw()


func reset_toy() -> void:
	_clear_waves()
	_cd_left = 0.0
	_swing_t = 0.0
	_relay_delay = -1.0
	_relay_chain = PackedStringArray()
	_clapper_echo_left = -1.0
	if not persist and powered:
		set_powered(false)
		_notify_linked_targets(false)
	queue_redraw()


func _clear_waves() -> void:
	for w: LxRingWave in _waves:
		if w != null and is_instance_valid(w):
			w.queue_free()
	_waves.clear()


func is_echo_armed() -> bool:
	return _clapper_echo_left > 0.0


func has_echo_clapper() -> bool:
	if bool(props.get("echo_enabled", false)):
		return true
	return island_id == 1 and Lx.state != null and bool(Lx.state.story_flags.get("item_echo_clapper", false))


func tick(dt: float) -> void:
	super.tick(dt)
	_tick_island1_rule(dt)
	var dirty: bool = false
	if _cd_left > 0.0:
		_cd_left = maxf(0.0, _cd_left - dt)
	if _swing_t > 0.0:
		_swing_t = maxf(0.0, _swing_t - dt)
		dirty = true
	if _relay_delay >= 0.0:
		_relay_delay -= dt
		if _relay_delay <= 0.0:
			_relay_delay = -1.0
			var ch: PackedStringArray = _relay_chain.duplicate()
			_relay_chain = PackedStringArray()
			ring(false, ch)
	if _clapper_echo_left > 0.0:
		_clapper_echo_left -= dt
		dirty = true
		if _clapper_echo_left <= 0.0:
			_clapper_echo_left = -1.0
			ring(true)
	for i: int in range(_waves.size() - 1, -1, -1):
		var w: LxRingWave = _waves[i]
		if w == null or not is_instance_valid(w):
			_waves.remove_at(i)
			continue
		w.tick(dt)
		if w.done:
			w.queue_free()
			_waves.remove_at(i)
	if dirty:
		queue_redraw()


func _tick_island1_rule(dt: float) -> void:
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd_left > 0.0:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		ring(false)
		if hit.source in ["throw", "zip"] and has_echo_clapper():
			_arm_echo_clapper()
		return true
	return false


func _arm_echo_clapper() -> void:
	_clapper_echo_total = echo_delay_s
	_clapper_echo_left = echo_delay_s
	_emit_sfx(_pick_sfx("echo_clapper_pulse", "prop_chime"))
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or _cd_left > 0.0:
		return false
	ring(false)
	return true


func on_ring(in_tone: String, _dir: Vector2) -> void:
	_accept_relay(in_tone, PackedStringArray())


func on_ring_wave(wave: LxRingWave, in_tone: String, _dir: Vector2) -> void:
	if wave != null and not id.is_empty() and wave.chain_ids.has(id):
		return
	_accept_relay(in_tone, wave.chain_ids if wave != null else PackedStringArray())


func _accept_relay(in_tone: String, in_chain: PackedStringArray) -> void:
	if not active or not relay or _cd_left > 0.0 or _relay_delay >= 0.0:
		return
	if in_tone == tone or bool(props.get("relay_any_tone", false)):
		_relay_chain = in_chain.duplicate()
		_relay_delay = 0.08


func ring(is_echo_wave: bool = false, in_chain: PackedStringArray = PackedStringArray()) -> LxRingWave:
	if not is_echo_wave:
		_cd_left = cooldown
	_swing_t = 0.85
	ring_count += 1
	if is_echo_wave:
		echo_count += 1
	var wave := LxRingWave.new()
	var parent_n: Node = region if (region != null and is_instance_valid(region)) else get_parent()
	if parent_n != null:
		parent_n.add_child(wave)
	else:
		add_child(wave)
	wave.setup(pos, tone, region, wave_speed, wave_radius, id, is_echo_wave, in_chain)
	_waves.append(wave)
	var sfx_id: String = _tone_sfx(is_echo_wave)
	_emit_sfx(sfx_id)
	_emit_gust(64.0, 42.0, Vector2(0.0, -8.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 62.0, 0.72 if LxHudFx.flash_reduced() else 1.08, 0.34)
	set_powered(true)
	_notify_linked_targets(true)
	if region != null and region.has_method("notify"):
		region.call("notify", "bell_rung", {"id": id, "tone": tone, "pos": pos, "echo": is_echo_wave})
	queue_redraw()
	return wave


func _tone_sfx(is_echo_wave: bool) -> String:
	if is_echo_wave:
		return _pick_sfx("echo_clapper_pulse", "prop_chime")
	if tone == "dawn":
		return _pick_sfx("bell_dawn_ring", "bell_toll")
	if tone == "dusk":
		return _pick_sfx("bell_dusk_ring", "clockwork_chime")
	return _pick_sfx("bell_war_ring", "bell_slam")


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func get_active_waves() -> Array[LxRingWave]:
	return _waves


func get_interact_prompt() -> String:
	return "PROMPT_RING_BELL" if active else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _swing_t > 0.0 or _clapper_echo_left > 0.0:
		return Vector4(pos.x, pos.y - 6.0, 52.0 if _clapper_echo_left > 0.0 else 48.0, 0.88)
	return Vector4(pos.x, pos.y - 6.0, 26.0, 0.35)


func _draw() -> void:
	var trip: Array[Color] = LxToyDraw.color_triplet(tone)
	var c_void: Color = PAL["void"] as Color
	var c_frame_d: Color = PAL["night"] as Color
	var c_frame_m: Color = PAL["dusk"] as Color
	var c_frame_h: Color = PAL["stone"] as Color
	var sway_x: float = 0.0 if (LxHudFx.flash_reduced() or _swing_t <= 0.0) else roundf(sin(_swing_t * 22.0) * 2.0 * (_swing_t / 0.85))

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.5)
	# Belfry frame posts & beam
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -14.0, 4.0, 20.0), c_frame_d, c_frame_m, c_frame_h, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(5.0, -14.0, 4.0, 20.0), c_frame_d, c_frame_m, c_frame_h, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -16.0, 20.0, 4.0), c_frame_d, c_frame_m, c_frame_h, c_void)

	# Hanging bell silhouette
	var bx: float = sway_x
	draw_rect(Rect2(bx - 1.0, -12.0, 2.0, 2.0), c_void)
	draw_rect(Rect2(bx - 4.0, -10.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(bx - 5.0, -4.0, 10.0, 4.0), c_void)
	draw_rect(Rect2(bx - 3.0, -9.0, 6.0, 6.0), trip[0])
	draw_rect(Rect2(bx - 4.0, -3.0, 8.0, 2.0), trip[1])
	draw_rect(Rect2(bx - 2.0, -8.0, 3.0, 5.0), trip[1])
	draw_rect(Rect2(bx - 2.0, -8.0, 1.0, 4.0), trip[2])
	# Clapper
	draw_rect(Rect2(bx - 1.0 + sway_x * 0.5, -1.0, 2.0, 2.0), PAL["cream"] as Color if (_swing_t > 0.0 or _clapper_echo_left > 0.0) else trip[2])
	# Relay chime dots on posts
	if relay:
		draw_rect(Rect2(-8.0, -7.0, 2.0, 2.0), trip[2])
		draw_rect(Rect2(6.0, -7.0, 2.0, 2.0), trip[2])
	# Echo Clapper armed countdown ring (1.4 s delayed second wave)
	if _clapper_echo_left > 0.0:
		var frac: float = clampf(_clapper_echo_left / maxf(0.05, _clapper_echo_total), 0.0, 1.0)
		var pulse_r: float = roundf(lerpf(11.0, 16.0, frac))
		draw_arc(Vector2(0.0, -6.0), pulse_r, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, PAL["cream"] as Color, 1.0)
		draw_arc(Vector2(0.0, -6.0), pulse_r - 2.0, 0.0, TAU, 16, Color(trip[1], 0.65), 1.0)
	# Tone crest on top crossbar (colour-blind distinct)
	LxToyDraw.draw_tone_crest(self, Vector2(0.0, -18.0), tone, _swing_t > 0.0 or _clapper_echo_left > 0.0)
	_draw_signal_pulses()
