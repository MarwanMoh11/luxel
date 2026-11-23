class_name LxGreatLamp
extends LxInteractable
## End-of-island Great Lamp / Great Belfry Brazier: relights the island and opens the bridge to the next island.

var lit: bool = false
var requires_boss: String = ""
var requires_flag: String = ""
var _ready_cache: bool = false
var _relight_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "great_lamp"
	requires_boss = str(props.get("requires_boss", ""))
	requires_flag = str(props.get("requires_flag", ""))
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.relit_islands.has(island_id):
		lit = true
	_ready_cache = _can_relight()
	_relight_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	if _relight_t > 0.0:
		_relight_t = maxf(0.0, _relight_t - dt)
		queue_redraw()
	var ready: bool = _can_relight()
	if ready != _ready_cache:
		_ready_cache = ready
		queue_redraw()
	_uses_prop_anim = lit or ready
	super.tick(dt)


func _can_relight() -> bool:
	if lit or not active:
		return false
	if region != null and region.has_method("get_enemies"):
		var enemies_var: Variant = region.call("get_enemies")
		if enemies_var is Array:
			for e: Variant in (enemies_var as Array):
				if e is Object and is_instance_valid(e):
					var obj: Object = e as Object
					if obj.has_method("is_alive") and bool(obj.call("is_alive")):
						return false
	if not requires_boss.is_empty() and (Lx.state == null or not Lx.state.defeated_bosses.has(requires_boss)):
		return false
	if not requires_flag.is_empty():
		if region != null and region.has_method("is_flag_set"):
			if not bool(region.call("is_flag_set", requires_flag)):
				return false
		elif Lx.state == null or not bool(Lx.state.story_flags.get(requires_flag, false)):
			return false
	return true


func interact(_actor: Node = null) -> bool:
	if not _can_relight():
		return false
	return _relight()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not _can_relight():
		return false
	if hit.source in ["throw", "recall", "zip", "beam", "sunflare"]:
		return _relight()
	return false


func _relight() -> bool:
	lit = true
	_relight_t = 0.72
	if Lx.state != null:
		if not Lx.state.relit_islands.has(island_id):
			Lx.state.relit_islands.append(island_id)
		Lx.state.story_flags["great_lamp_%d" % island_id] = true
		Lx.state.story_flags["island_%d_relit" % island_id] = true
		Lx.state.story_flags["island_%d_bridge_open" % island_id] = true
		Lx.state.heal_full()
	if Lx.events != null:
		Lx.events.great_lamp_relit.emit(island_id)
		Lx.events.shake_requested.emit(0.24)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.09)
	_emit_gust(144.0, 125.0, Vector2(0.0, -14.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, pos, 22.0, 9.0)
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 26.0, 10.0)
	_emit_sfx("great_lamp_relit")
	var accent: String = _island_relight_sfx()
	if not accent.is_empty() and Lx.audio != null:
		Lx.audio.play_sfx(accent, pos, true)
	_emit_save("great_lamp_%d" % island_id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if lit:
		var surge: float = (sin((1.0 - clampf(_relight_t / 0.72, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _relight_t > 0.0 else 0.0
		return Vector4(pos.x, pos.y - 16.0, 148.0 + surge * 76.0, 1.6 + surge * 0.55)
	if _can_relight():
		return Vector4(pos.x, pos.y - 14.0, 58.0, 0.9)
	return Vector4(pos.x, pos.y - 12.0, 26.0, 0.4)


func get_interact_prompt() -> String:
	return "PROMPT_RELIGHT_GREAT_LAMP" if _can_relight() else ""


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	if Lx.state != null and Lx.state.relit_islands.has(island_id):
		lit = true
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-21.0, 2.0, 42.0, 2.0), shadow)
	draw_rect(Rect2(-18.0, 1.0, 36.0, 4.0), shadow)
	draw_rect(Rect2(-13.0, 0.0, 26.0, 6.0), shadow)
	var ready: bool = _can_relight()
	if not lit and ready:
		_draw_relight_rings(false)
	var frame_ov: int = -1 if (lit or ready) else 0
	if not _draw_prop_sprite("great_lamp" if lit else "great_lamp_unlit", Vector2.ZERO, frame_ov):
		_draw_fallback(ready)
	if not lit and ready:
		_draw_relight_rings(true)
		_draw_beckon_motes()
	elif lit:
		_draw_dawn_embers()
	if _relight_t > 0.0:
		var p: float = 1.0 - clampf(_relight_t / 0.72, 0.0, 1.0)
		var rc: Array[Color] = _island_relight_colors()
		var col_w: float = roundf(maxf(0.0, (1.0 - p) * 16.0))
		if col_w >= 2.0:
			draw_rect(Rect2(-floorf(col_w * 0.5), -68.0, col_w, 72.0), rc[0] if p > 0.3 else rc[1])
		if p < 0.75:
			draw_rect(Rect2(-2.0, -68.0, 4.0, 72.0), PAL["cream"])
		draw_arc(Vector2(0.0, -14.0), roundf(8.0 + p * 44.0), 0.0, TAU, 24, rc[1] if p < 0.35 else rc[0], 2.0 if p < 0.4 else 1.0)
		draw_arc(Vector2(0.0, -14.0), roundf(4.0 + p * 28.0), 0.0, TAU, 18, PAL["cream"], 1.0)
	_draw_signal_pulses()


func _island_relight_colors() -> Array[Color]:
	match island_id:
		2:
			return [PAL["sky"] as Color, PAL["ice"] as Color]
		3:
			return [PAL["jade"] as Color, PAL["lime"] as Color]
		4:
			return [PAL["rose"] as Color, PAL["ice"] as Color]
		5:
			return [PAL["gold"] as Color, PAL["sky"] as Color]
		6:
			return [PAL["coral"] as Color, PAL["gold"] as Color]
		7:
			return [PAL["ice"] as Color, PAL["cream"] as Color]
		8:
			return [PAL["gold"] as Color, PAL["rose"] as Color]
		_:
			return [PAL["gold"] as Color, PAL["cream"] as Color]


func _island_relight_sfx() -> String:
	match island_id:
		2:
			return "lighthouse_toll"
		3:
			return "prop_chime"
		4:
			return "wing_gale"
		5:
			return "prism_chain"
		6:
			return "forge_gust"
		7, 8:
			return "bell_toll"
		_:
			return ""


func _draw_fallback(ready: bool) -> void:
	draw_rect(Rect2(-12.0, -5.0, 24.0, 10.0), PAL["night"])
	draw_rect(Rect2(-10.0, -8.0, 20.0, 10.0), PAL["dusk"])
	draw_rect(Rect2(-8.0, -20.0, 16.0, 14.0), PAL["mauve"])
	draw_rect(Rect2(-6.0, -18.0, 12.0, 10.0), PAL["stone"])
	if lit:
		draw_circle(Vector2(0.0, -22.0), 8.0, PAL["apricot"])
		draw_circle(Vector2(0.0, -22.0), 5.5, PAL["gold"])
		draw_circle(Vector2(0.0, -22.0), 3.0, PAL["cream"])
	elif ready:
		draw_circle(Vector2(0.0, -21.0), 4.0, PAL["coral"])
		draw_circle(Vector2(0.0, -21.0), 2.0, PAL["gold"])
	else:
		draw_rect(Rect2(-5.0, -22.0, 10.0, 4.0), PAL["plum"])


func _draw_relight_rings(front: bool) -> void:
	var rc: Array[Color] = _island_relight_colors()
	var breath: float = 0.0 if LxHudFx.flash_reduced() else sin(_clock * 2.2) * 2.0
	_draw_orbit_ring(front, 12, 26.0 + breath, 8.0 + breath * 0.35, 0.55, rc[1], rc[0])
	_draw_orbit_ring(front, 8, 20.0 - breath * 0.5, 6.0, -0.85, PAL["cream"] as Color, rc[1])


func _draw_orbit_ring(
	front: bool, count: int, rx: float, ry: float, speed: float, c_a: Color, c_b: Color
) -> void:
	for i: int in range(count):
		var a: float = _clock * speed + (TAU * float(i)) / float(count)
		var sa: float = sin(a)
		if (sa >= 0.0) == front:
			draw_rect(Rect2(roundf(cos(a) * rx), roundf(1.0 + sa * ry), 1.0, 1.0), c_a if i % 2 == 0 else c_b)


func _draw_beckon_motes() -> void:
	var rc: Array[Color] = _island_relight_colors()
	for i: int in range(4):
		var t: float = fmod(_clock * 0.5 + float(i) * 0.25, 1.0)
		var px: float = roundf(sin(_clock * 1.8 + float(i) * 1.57) * 12.0)
		draw_rect(Rect2(px, roundf(-14.0 - t * 36.0), 1.0, 1.0), PAL["cream"] if t < 0.45 else rc[1])


func _draw_dawn_embers() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var rc: Array[Color] = _island_relight_colors()
	var beam_h: float = 34.0 + (0.0 if fred else roundf(sin(_clock * 1.9) * 4.0))
	var by: float = -30.0
	var step_i: int = 0
	while by > -30.0 - beam_h:
		if step_i % 2 == 0:
			var bcol: Color = (PAL["cream"] as Color) if step_i < 2 else (rc[1] if step_i < 6 else rc[0])
			draw_rect(Rect2(0.0, by, 1.0, 2.0), bcol)
		by -= 3.0
		step_i += 1
	for hi: int in range(6):
		var ha: float = _clock * 0.38 + float(hi) * (TAU / 6.0)
		draw_rect(Rect2(roundf(cos(ha) * 22.0), roundf(2.0 + sin(ha) * 6.5), 2.0 if hi % 2 == 0 else 1.0, 1.0), rc[1] if hi % 2 == 0 else rc[0])
	# Biome-specific ceremonial crown shimmer above the relit Great Lamp!
	match island_id:
		1: # Warm acoustic brass bell-chime halo
			var r_b: float = 12.0 + (0.0 if fred else fposmod(_clock * 10.0, 8.0))
			var a_b: float = 0.65 * clampf(1.0 - (r_b - 12.0) / 8.0, 0.25, 1.0)
			draw_arc(Vector2(0.0, -24.0), roundf(r_b), PI * 1.12, PI * 1.88, 12, Color(PAL["gold"] as Color, a_b), 1.2)
		2: # Rotating Fresnel lighthouse beams
			for k: int in range(2):
				var ba: float = _clock * 1.1 + float(k) * PI
				draw_line(Vector2(0.0, -24.0), Vector2(roundf(cos(ba) * 26.0), roundf(-24.0 + sin(ba) * 10.0)), Color(PAL["ice"] as Color, 0.55), 1.0)
		3: # Rising emerald-lime canopy petals
			for k: int in range(4):
				var pa: float = _clock * 1.6 + float(k) * (TAU / 4.0)
				draw_rect(Rect2(roundf(cos(pa) * 14.0), roundf(-22.0 + sin(pa) * 6.0), 2.0, 2.0), PAL["lime"] as Color)
		4: # Glasshouse prism rainbow arc
			draw_arc(Vector2(0.0, -22.0), 16.0, PI * 1.12, PI * 1.88, 12, Color(PAL["rose"] as Color, 0.65), 1.0)
			draw_arc(Vector2(0.0, -22.0), 14.0, PI * 1.15, PI * 1.85, 12, Color(PAL["ice"] as Color, 0.65), 1.0)
		5: # Counter-rotating golden astrolabe rings
			draw_arc(Vector2(0.0, -22.0), 15.0, _clock * 1.8, _clock * 1.8 + 2.4, 12, PAL["gold"] as Color, 1.2)
			draw_arc(Vector2(0.0, -22.0), 15.0, -_clock * 1.8, -_clock * 1.8 + 2.4, 12, PAL["sky"] as Color, 1.2)
		6: # Twin volcanic solar hearth spirals
			for side: float in [-1.0, 1.0]:
				var h_j: float = roundf(10.0 + (0.0 if fred else absf(sin(_clock * 6.0 + side)) * 5.0))
				draw_rect(Rect2(side * 10.0, -20.0 - h_j, 2.0, h_j), Color(PAL["coral"] as Color, 0.72))
		7: # Radiant silver lunar crescent corona
			draw_arc(Vector2(0.0, -24.0), 13.0, -PI * 0.65, PI * 0.65, 12, PAL["ice"] as Color, 1.4)
		8: # Colossal 8-ray Dawn Sunburst!
			for k: int in range(8):
				var sa: float = _clock * 0.6 + float(k) * (TAU / 8.0)
				draw_line(Vector2(0.0, -22.0), Vector2(roundf(cos(sa) * 20.0), roundf(-22.0 + sin(sa) * 14.0)), Color(PAL["gold"] as Color, 0.65), 1.0)
	for i: int in range(5):
		var t: float = fmod(_clock * 0.44 + float(i) * 0.2, 1.0)
		var px: float = roundf(sin(_clock * 1.6 + float(i) * 1.3) * (4.0 + t * 7.0))
		var col: Color = (PAL["cream"] as Color) if t < 0.28 else (rc[1] if t < 0.68 else rc[0])
		draw_rect(Rect2(px, roundf(-28.0 - t * 32.0), 1.0, 1.0), col)
