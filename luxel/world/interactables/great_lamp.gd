class_name LxGreatLamp
extends LxInteractable
## End-of-island Great Lamp / Great Belfry Brazier: relights the island and opens the bridge to the next island.

const RELIGHT_DUR: float = 1.40
const APEX_T: float = 0.22

var lit: bool = false
var requires_boss: String = ""
var requires_flag: String = ""
var _ready_cache: bool = false
var _relight_t: float = 0.0
var _dawn_apex_fired: bool = false


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
	_dawn_apex_fired = false
	queue_redraw()


func tick(dt: float) -> void:
	if _relight_t > 0.0:
		_relight_t = maxf(0.0, _relight_t - dt)
		if not _dawn_apex_fired and (RELIGHT_DUR - _relight_t) >= APEX_T:
			_fire_dawn_apex()
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
	_relight_t = RELIGHT_DUR
	_dawn_apex_fired = false
	if Lx.state != null:
		if not Lx.state.relit_islands.has(island_id):
			Lx.state.relit_islands.append(island_id)
		Lx.state.story_flags["great_lamp_%d" % island_id] = true
		Lx.state.story_flags["island_%d_relit" % island_id] = true
		Lx.state.story_flags["island_%d_bridge_open" % island_id] = true
		Lx.state.heal_full()
	if Lx.events != null:
		Lx.events.great_lamp_relit.emit(island_id)
		Lx.events.shake_requested.emit(0.16)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.12)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.trigger_focus_nudge(pos, 1.1)
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


func _fire_dawn_apex() -> void:
	_dawn_apex_fired = true
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.26)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.add_kick(Vector2.UP, 3.5)
	_emit_gust(156.0, 135.0, Vector2(0.0, -14.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var dl: LxDarknessLayer = LxDarknessLayer.active_instance
		dl.trigger_focus_flash(0.85)
		dl.add_burst_light(pos, 168.0, 1.25 if LxHudFx.flash_reduced() else 1.85, 0.72)
		if not dl.wave_active:
			dl.trigger_dawn_wave(pos, 260.0, 1400.0)


func get_light_pool() -> Vector4:
	if lit:
		var surge: float = 0.0
		if _relight_t > 0.0:
			var el: float = RELIGHT_DUR - _relight_t
			if el < APEX_T:
				surge = lerpf(0.30, 0.65, el / APEX_T)
			else:
				var u2: float = clampf((el - APEX_T) / (RELIGHT_DUR - APEX_T), 0.0, 1.0)
				surge = (1.0 - u2) * (1.0 - u2 * 0.35)
			surge *= (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 16.0, 148.0 + surge * 92.0, 1.6 + surge * 0.65)
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
		_draw_dawn_crescendo()
	_draw_signal_pulses()


func _draw_dawn_crescendo() -> void:
	var el: float = RELIGHT_DUR - _relight_t
	var rc: Array[Color] = _island_relight_colors()
	var cream: Color = PAL["cream"] as Color
	var gold: Color = PAL["gold"] as Color
	# Stage 1 (0.00-0.22s): Golden core compression pulling radiance inward
	if el < APEX_T:
		var u1: float = clampf(el / APEX_T, 0.0, 1.0)
		draw_arc(Vector2(0.0, -18.0), roundf(lerpf(42.0, 6.0, u1 * u1)), 0.0, TAU, 24, gold, 2.0)
		draw_arc(Vector2(0.0, -18.0), roundf(lerpf(28.0, 4.0, u1)), 0.0, TAU, 18, rc[1], 1.0)
		draw_circle(Vector2(0.0, -20.0), roundf(lerpf(3.0, 9.0, u1)), cream if u1 > 0.55 else gold)
		for k: int in range(8):
			var a: float = float(k) * (TAU / 8.0) + u1 * 1.8
			var d: float = roundf(lerpf(36.0, 5.0, u1))
			draw_rect(Rect2(roundf(cos(a) * d), roundf(-20.0 + sin(a) * d * 0.6), 2.0, 2.0), cream if k % 2 == 0 else gold)
		return
	# Stage 2 (0.22-1.40s): Huge cream/gold dawn flare + 24 rising biome-colored dawn embers
	var u2: float = clampf((el - APEX_T) / (RELIGHT_DUR - APEX_T), 0.0, 1.0)
	var fade: float = 1.0 - u2
	var e2: float = 1.0 - pow(1.0 - u2, 2.0)
	var outer_w: float = roundf(maxf(0.0, fade * 22.0))
	if outer_w >= 2.0:
		draw_rect(Rect2(-floorf(outer_w * 0.5), -96.0, outer_w, 100.0), Color(rc[0], fade * 0.72))
	var mid_w: float = roundf(maxf(0.0, (1.0 - u2 * 1.15) * 12.0))
	if mid_w >= 2.0:
		draw_rect(Rect2(-floorf(mid_w * 0.5), -96.0, mid_w, 100.0), Color(gold, fade * 0.90))
	var core_w: float = roundf(maxf(0.0, (1.0 - u2 * 1.35) * 5.0))
	if core_w >= 1.0:
		draw_rect(Rect2(-floorf(core_w * 0.5), -96.0, core_w, 100.0), Color(cream, minf(1.0, fade * 1.25)))
	var w_o: float = 2.0 if u2 < 0.35 else 1.0
	var w_m: float = 2.0 if u2 < 0.4 else 1.0
	draw_arc(Vector2(0.0, -16.0), roundf(lerpf(8.0, 74.0, e2)), 0.0, TAU, 28, Color(cream if u2 < 0.28 else gold, fade), w_o)
	draw_arc(Vector2(0.0, -16.0), roundf(lerpf(6.0, 56.0, e2)), 0.0, TAU, 24, Color(rc[1], fade * 0.90), w_m)
	draw_arc(Vector2(0.0, -16.0), roundf(lerpf(4.0, 38.0, e2)), 0.0, TAU, 18, Color(rc[0], fade * 0.85), 1.0)
	if u2 < 0.35:
		var ray_f: float = 1.0 - (u2 / 0.35)
		var rlen: float = roundf(lerpf(12.0, 44.0, 1.0 - ray_f))
		for rk: int in range(8):
			var ra: float = float(rk) * (TAU / 8.0) + u2 * 0.6
			draw_line(Vector2(0.0, -20.0), Vector2(roundf(cos(ra) * rlen), roundf(-20.0 + sin(ra) * rlen * 0.72)), Color(cream if rk % 2 == 0 else gold, ray_f), 1.0)
	for ei: int in range(24):
		var frac: float = float(ei) / 24.0
		var seed_x: float = (fmod(float(ei) * 37.0, 19.0) - 9.0) * 10.5
		var sway: float = sin(u2 * 5.0 + float(ei) * 1.3) * 5.0
		var rise: float = lerpf(0.0, 78.0 + float(ei % 4) * 12.0, clampf(u2 * 1.15 - frac * 0.15, 0.0, 1.0))
		var ex: float = roundf(seed_x + sway)
		var ey: float = roundf(-6.0 + float(ei % 3) * 5.0 - rise)
		var ecol: Color = cream if (ei % 4 == 0) else (gold if (ei % 4 == 1) else (rc[1] if (ei % 4 == 2) else rc[0]))
		var esz: float = 2.0 if (u2 < 0.55 and ei % 3 == 0) else 1.0
		draw_rect(Rect2(ex, ey, esz, esz), Color(ecol, fade))


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
		1:
			return "bell_toll"
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
	var t_cr: float = _clock * (0.45 if fred else 1.0)
	match island_id:
		1: # Warm acoustic brass bell-chime halo
			var r_b: float = 12.0 + (0.0 if fred else fposmod(_clock * 10.0, 8.0))
			var a_b: float = 0.65 * clampf(1.0 - (r_b - 12.0) / 8.0, 0.25, 1.0)
			draw_arc(Vector2(0.0, -24.0), roundf(r_b), PI * 1.12, PI * 1.88, 12, Color(PAL["gold"] as Color, a_b), 1.0)
		2: # Rotating Fresnel lighthouse beams
			for k: int in range(2):
				var ba: float = t_cr * 1.1 + float(k) * PI
				draw_line(Vector2(0.0, -24.0), Vector2(roundf(cos(ba) * 26.0), roundf(-24.0 + sin(ba) * 10.0)), Color(PAL["ice"] as Color, 0.55), 1.0)
		3: # Rising emerald-lime canopy petals
			for k: int in range(4):
				var pa: float = t_cr * 1.6 + float(k) * (TAU / 4.0)
				draw_rect(Rect2(roundf(cos(pa) * 14.0), roundf(-22.0 + sin(pa) * 6.0), 2.0, 2.0), PAL["lime"] as Color)
		4: # Glasshouse prism rainbow arc
			draw_arc(Vector2(0.0, -22.0), 16.0, PI * 1.12, PI * 1.88, 12, Color(PAL["rose"] as Color, 0.65), 1.0)
			draw_arc(Vector2(0.0, -22.0), 14.0, PI * 1.15, PI * 1.85, 12, Color(PAL["ice"] as Color, 0.65), 1.0)
		5: # Counter-rotating golden astrolabe rings
			draw_arc(Vector2(0.0, -22.0), 15.0, t_cr * 1.8, t_cr * 1.8 + 2.4, 12, PAL["gold"] as Color, 1.0)
			draw_arc(Vector2(0.0, -22.0), 15.0, -t_cr * 1.8, -t_cr * 1.8 + 2.4, 12, PAL["sky"] as Color, 1.0)
		6: # Twin volcanic solar hearth spirals
			for side: float in [-1.0, 1.0]:
				var h_j: float = roundf(10.0 + (0.0 if fred else absf(sin(_clock * 6.0 + side)) * 5.0))
				draw_rect(Rect2(side * 10.0, -20.0 - h_j, 2.0, h_j), Color(PAL["coral"] as Color, 0.72))
		7: # Radiant silver lunar crescent corona
			draw_arc(Vector2(0.0, -24.0), 13.0, -PI * 0.65, PI * 0.65, 12, PAL["ice"] as Color, 2.0)
		8: # Colossal 8-ray Dawn Sunburst!
			for k: int in range(8):
				var sa: float = t_cr * 0.6 + float(k) * (TAU / 8.0)
				draw_line(Vector2(0.0, -22.0), Vector2(roundf(cos(sa) * 20.0), roundf(-22.0 + sin(sa) * 14.0)), Color(PAL["gold"] as Color, 0.65), 1.0)
	for i: int in range(5):
		var t: float = fmod(_clock * 0.44 + float(i) * 0.2, 1.0)
		var px: float = roundf(sin(_clock * 1.6 + float(i) * 1.3) * (4.0 + t * 7.0))
		var col: Color = (PAL["cream"] as Color) if t < 0.28 else (rc[1] if t < 0.68 else rc[0])
		draw_rect(Rect2(px, roundf(-28.0 - t * 32.0), 1.0, 1.0), col)
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % island_id, false)):
		var h_spin: float = 0.0 if fred else _clock * 0.9
		for hi2: int in range(4):
			var ha2: float = h_spin + float(hi2) * (PI * 0.5)
			var hx: float = roundf(cos(ha2) * 14.0)
			var hy: float = roundf(-36.0 + sin(ha2) * 3.5)
			draw_rect(Rect2(hx - 1.0, hy, 3.0, 1.0), PAL["gold"] as Color if hi2 % 2 == 0 else rc[1])
			draw_rect(Rect2(hx, hy - 1.0, 1.0, 3.0), PAL["gold"] as Color if hi2 % 2 == 0 else rc[1])
			draw_rect(Rect2(hx, hy, 1.0, 1.0), PAL["cream"] as Color)
