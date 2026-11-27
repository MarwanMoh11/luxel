class_name LxShrine
extends LxInteractable
## Move Shrine: unlocks props.move_id, emits shrine_claimed + save_requested.

const CLAIM_DUR: float = 1.10
const APEX_T: float = 0.22

var claimed: bool = false
var move_id: String = ""
var _claim_t: float = 0.0
var _apex_fired: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "shrine"
	move_id = str(props.get("move_id", ""))
	claimed = bool(props.get("claimed", false))
	_claim_t = 0.0
	_apex_fired = false
	if Lx.state != null:
		if Lx.state.claimed_shrines.has(id) or (not move_id.is_empty() and Lx.state.has_move(move_id)):
			claimed = true
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = not claimed
	super.tick(dt)
	if _claim_t > 0.0:
		_claim_t = maxf(0.0, _claim_t - dt)
		if not _apex_fired and (CLAIM_DUR - _claim_t) >= APEX_T:
			_fire_claim_apex()
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	claimed = true
	_claim_t = CLAIM_DUR
	_apex_fired = false
	if Lx.state != null:
		if not move_id.is_empty():
			Lx.state.unlock_move(move_id)
		if not id.is_empty() and not Lx.state.claimed_shrines.has(id):
			Lx.state.claimed_shrines.append(id)
	if move_id == "sunflare":
		var emax: float = Lx.state.get_effective_ember_max() if Lx.state != null else 100.0
		var p_ref: Node = _actor if (_actor != null and is_instance_valid(_actor) and _actor.get("ember") != null) else Lx.player
		if p_ref != null and is_instance_valid(p_ref) and p_ref.get("ember") != null:
			p_ref.set("ember", emax)
	if Lx.events != null:
		Lx.events.shrine_claimed.emit(id, move_id)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.trigger_focus_nudge(pos, 0.75)
	_emit_sfx("shrine_claimed")
	_emit_save("shrine_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func _fire_claim_apex() -> void:
	_apex_fired = true
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.09)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.18)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.add_kick(Vector2.UP, 2.5)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.trigger_focus_flash(0.65)
	_emit_gust(108.0, 92.0, Vector2(0.0, -10.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 18.0, 8.0)
	var accent_sfx: String = _move_accent_sfx()
	if not accent_sfx.is_empty() and Lx.audio != null:
		Lx.audio.play_sfx(accent_sfx, pos, true)


func get_light_pool() -> Vector4:
	if _claim_t > 0.0:
		var el: float = CLAIM_DUR - _claim_t
		var surge: float = 0.0
		if el < APEX_T:
			surge = lerpf(0.25, 0.55, el / APEX_T)
		else:
			var u2: float = clampf((el - APEX_T) / (CLAIM_DUR - APEX_T), 0.0, 1.0)
			surge = (1.0 - u2) * (1.0 - u2 * 0.45)
		surge *= (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 10.0, 42.0 + surge * 82.0, 0.72 + surge * 0.92)
	if not claimed:
		return Vector4(pos.x, pos.y - 10.0, 68.0, 1.15)
	return Vector4(pos.x, pos.y - 8.0, 42.0, 0.72)


func get_interact_prompt() -> String:
	return "" if claimed else "PROMPT_CLAIM_SHRINE"


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed))
	if Lx.state != null and Lx.state.claimed_shrines.has(id):
		claimed = true
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-12.0, 2.0, 24.0, 2.0), shadow)
	draw_rect(Rect2(-10.0, 1.0, 20.0, 4.0), shadow)
	draw_rect(Rect2(-7.0, 0.0, 14.0, 5.0), shadow)
	var colors: Array[Color] = _move_palette()
	var c_main: Color = colors[0]
	var c_hi: Color = colors[1]
	if not claimed:
		_draw_floor_ring(false, c_main, c_hi)
	var frame_ov: int = 0 if claimed else -1
	var tint: Color = (PAL["mauve"] as Color) if claimed else Color.WHITE
	if not _draw_prop_sprite("shrine", Vector2.ZERO, frame_ov, tint):
		_draw_fallback()
	if not claimed:
		_draw_floor_ring(true, c_main, c_hi)
		_draw_move_emblem(c_main, c_hi)
		_draw_starlight_motes(c_main, c_hi)
		if Lx.player is Node2D and is_instance_valid(Lx.player):
			var d_s: float = (Lx.player as Node2D).global_position.distance_to(pos)
			if d_s <= 60.0:
				var prox_s: float = clampf(1.0 - d_s / 60.0, 0.0, 1.0)
				var fr_s: bool = LxHudFx.flash_reduced()
				var sa: float = (0.14 if fr_s else 0.24) * prox_s
				draw_rect(Rect2(-6.0, -38.0, 12.0, 38.0), Color(c_main, sa))
				draw_rect(Rect2(-2.0, -40.0, 4.0, 40.0), Color(c_hi, sa * 1.15))
				var spin_s: float = 0.0 if fr_s else _clock * 1.1
				draw_arc(Vector2(0.0, 1.0), 17.0, spin_s, spin_s + PI * 0.7, 10, Color(c_hi, prox_s * 0.65), 1.0)
				draw_arc(Vector2(0.0, 1.0), 17.0, spin_s + PI, spin_s + PI * 1.7, 10, Color(c_main, prox_s * 0.65), 1.0)
	else:
		# Sacred memory spark gently orbiting the claimed Shrine pedestal
		var fred_s: bool = LxHudFx.flash_reduced()
		var ma: float = _clock * (0.65 if fred_s else 1.25)
		var mp := Vector2(roundf(cos(ma) * 9.0), roundf(-16.0 + sin(ma) * 3.0))
		draw_rect(Rect2(mp, Vector2(2.0, 1.0)), Color(c_main, 0.65))
		draw_rect(Rect2(mp, Vector2.ONE), Color(c_hi, 0.85))
	if _claim_t > 0.0:
		_draw_claim_burst(c_main, c_hi)
	_draw_signal_pulses()


func _move_palette() -> Array[Color]:
	match move_id:
		"dash":
			return [PAL["apricot"] as Color, PAL["gold"] as Color]
		"prism":
			return [PAL["sky"] as Color, PAL["ice"] as Color]
		"beam":
			return [PAL["jade"] as Color, PAL["lime"] as Color]
		"wings":
			return [PAL["rose"] as Color, PAL["cream"] as Color]
		"lens":
			return [PAL["gold"] as Color, PAL["sky"] as Color]
		"sunflare":
			return [PAL["coral"] as Color, PAL["gold"] as Color]
		_:
			return [PAL["sky"] as Color, PAL["ice"] as Color]


func _move_accent_sfx() -> String:
	match move_id:
		"dash":
			return "dash_whoosh"
		"prism":
			return "prism_chain"
		"beam":
			return "prop_chime"
		"wings":
			return "wing_gale"
		"lens":
			return "phantom_phase"
		"sunflare":
			return "forge_gust"
		_:
			return ""


func _draw_move_emblem(c_main: Color, c_hi: Color, cy_override: float = -999.0, sc: float = 1.0) -> void:
	var fr: bool = LxHudFx.flash_reduced()
	var t_s: float = _clock * (0.45 if fr else 1.0)
	var cy: float = cy_override if cy_override > -500.0 else (-24.0 + (0.0 if fr else roundf(sin(_clock * 2.6) * 1.5)))
	match move_id:
		"dash": # Twin glowing flare-dash chevrons streaking right
			var sx: float = 0.0 if fr else roundf(sin(_clock * 4.5) * 2.0)
			for ci: int in range(2):
				var ox: float = sx + float(ci) * 5.0 * sc - 3.0 * sc
				var col: Color = c_hi if ci == 1 else c_main
				draw_line(Vector2(ox - 2.0 * sc, cy - 3.0 * sc).round(), Vector2(ox + 1.0 * sc, cy).round(), col, maxf(1.0, sc))
				draw_line(Vector2(ox - 2.0 * sc, cy + 3.0 * sc).round(), Vector2(ox + 1.0 * sc, cy).round(), col, maxf(1.0, sc))
		"prism": # Rotating 3-vertex diamond prism ring
			for k: int in range(3):
				var a: float = t_s * 2.2 + float(k) * (TAU / 3.0)
				var pt := Vector2(roundf(cos(a) * 9.0 * sc), roundf(cy + sin(a) * 4.0 * sc))
				var sz: float = roundf(2.0 * sc)
				draw_rect(Rect2(pt, Vector2(sz, sz)), c_hi if k == 0 else c_main)
		"beam": # Focused vertical emerald-gold spire aura
			draw_line(Vector2(0.0, roundf(cy - 10.0 * sc)), Vector2(0.0, roundf(cy + 6.0 * sc)), Color(c_main, 0.72), maxf(2.0, 2.0 * sc))
			draw_line(Vector2(0.0, roundf(cy - 12.0 * sc)), Vector2(0.0, roundf(cy + 4.0 * sc)), c_hi, maxf(1.0, sc))
		"wings": # Fluttering dual-wing motes
			var fl: float = 0.0 if fr else roundf(sin(_clock * 6.5) * 2.0)
			draw_rect(Rect2(roundf(-9.0 * sc), cy + fl, roundf(3.0 * sc), roundf(2.0 * sc)), c_main)
			draw_rect(Rect2(roundf(6.0 * sc), cy + fl, roundf(3.0 * sc), roundf(2.0 * sc)), c_main)
			draw_rect(Rect2(roundf(-7.0 * sc), cy + fl - 1.0, roundf(2.0 * sc), 1.0), c_hi)
			draw_rect(Rect2(roundf(5.0 * sc), cy + fl - 1.0, roundf(2.0 * sc), 1.0), c_hi)
		"lens": # Counter-rotating golden/sky astrolabe halo
			var lw: float = maxf(1.4, 1.2 * sc)
			draw_arc(Vector2(0.0, cy), roundf(8.0 * sc), t_s * 2.4, t_s * 2.4 + 2.2, 10, c_main, lw)
			draw_arc(Vector2(0.0, cy), roundf(8.0 * sc), -t_s * 2.4, -t_s * 2.4 + 2.2, 10, c_hi, lw)
		"sunflare": # Blazing solar corona flares
			for k: int in range(6):
				var a: float = t_s * 1.8 + float(k) * (TAU / 6.0)
				var p0 := Vector2(cos(a) * 5.0 * sc, cy + sin(a) * 5.0 * sc).round()
				var p1 := Vector2(cos(a) * 10.0 * sc, cy + sin(a) * 10.0 * sc).round()
				draw_line(p0, p1, c_hi if k % 2 == 0 else c_main, maxf(1.0, sc))


func _draw_fallback() -> void:
	draw_rect(Rect2(-8.0, -3.0, 16.0, 7.0), PAL["night"])
	draw_rect(Rect2(-6.0, -12.0, 12.0, 11.0), PAL["mauve"])
	draw_rect(Rect2(-5.0, -11.0, 10.0, 9.0), PAL["stone"])
	if not claimed:
		draw_circle(Vector2(0.0, -14.0), 4.5, PAL["apricot"])
		draw_circle(Vector2(0.0, -14.0), 2.5, PAL["gold"])
		draw_circle(Vector2(0.0, -14.0), 1.2, PAL["cream"])
	else:
		draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), PAL["dusk"])


func _draw_floor_ring(front: bool, c_main: Color, c_hi: Color) -> void:
	for i: int in range(6):
		var a: float = _clock * 0.85 + (TAU * float(i)) / 6.0
		var sa: float = sin(a)
		if (sa >= 0.0) != front:
			continue
		var px: float = roundf(cos(a) * 14.0)
		var py: float = roundf(1.0 + sa * 5.0)
		draw_rect(Rect2(px, py, 2.0, 1.0), c_hi if (i % 2 == 0) else c_main)


func _draw_starlight_motes(c_main: Color, c_hi: Color) -> void:
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var phase: float = float(i) * PI
		var px: float = roundf(side * (10.0 + sin(_clock * 1.4 + phase) * 1.5))
		var py: float = roundf(-25.0 + sin(_clock * 2.4 + phase) * 2.5)
		draw_rect(Rect2(px, py, 1.0, 1.0), c_hi)
		if sin(_clock * 4.2 + phase) > 0.35:
			draw_rect(Rect2(px + side, py, 1.0, 1.0), c_main)


func _draw_claim_burst(c_main: Color, c_hi: Color) -> void:
	var el: float = CLAIM_DUR - _claim_t
	var cream: Color = PAL["cream"] as Color
	var bio_gl: Color = LxBiomePalette.col(island_id, "glow")
	# Beat 1 (0.00-0.22s): 2 inward-collapsing move-colored rings + gathering core
	if el < APEX_T:
		var u1: float = clampf(el / APEX_T, 0.0, 1.0)
		var r1: float = roundf(lerpf(28.0, 4.0, u1 * u1))
		var r2: float = roundf(lerpf(22.0, 3.0, clampf((u1 - 0.12) / 0.88, 0.0, 1.0)))
		draw_arc(Vector2(0.0, -10.0), r1, 0.0, TAU, 22, c_main, 2.0)
		draw_arc(Vector2(0.0, -10.0), r2, 0.0, TAU, 18, c_hi, 1.0)
		draw_circle(Vector2(0.0, -14.0), roundf(lerpf(2.0, 5.5, u1)), Color(cream if u1 > 0.6 else c_hi, 0.85))
		for k: int in range(6):
			var ka: float = float(k) * (TAU / 6.0) + u1 * 1.6
			var kd: float = roundf(lerpf(26.0, 4.0, u1))
			draw_rect(Rect2(roundf(cos(ka) * kd), roundf(-12.0 + sin(ka) * kd * 0.6), 2.0, 2.0), c_hi if k % 2 == 0 else cream)
		return
	# Beat 2 & Beat 3 (0.22-1.10s): Dual-layer pillar + enlarged rising move emblem + 12 starlight motes
	var u2: float = clampf((el - APEX_T) / (CLAIM_DUR - APEX_T), 0.0, 1.0)
	var fade: float = 1.0 - u2
	var wing_w: float = roundf(maxf(0.0, fade * 14.0))
	if wing_w >= 2.0:
		draw_rect(Rect2(-floorf(wing_w * 0.5), -58.0, wing_w, 60.0), Color(bio_gl, fade * 0.72))
	var mid_w: float = roundf(maxf(0.0, (1.0 - u2 * 1.15) * 8.0))
	if mid_w >= 2.0:
		draw_rect(Rect2(-floorf(mid_w * 0.5), -58.0, mid_w, 60.0), Color(c_main, fade * 0.90))
	var core_w: float = roundf(maxf(0.0, (1.0 - u2 * 1.35) * 4.0))
	if core_w >= 1.0:
		draw_rect(Rect2(-floorf(core_w * 0.5), -58.0, core_w, 60.0), Color(cream, minf(1.0, fade * 1.25)))
	if u2 < 0.72:
		var rp: float = u2 / 0.72
		var rw: float = 2.0 if rp < 0.35 else 1.0
		draw_arc(Vector2(0.0, -8.0), roundf(lerpf(6.0, 36.0, rp)), 0.0, TAU, 22, Color(cream if rp < 0.30 else c_hi, 1.0 - rp), rw)
	var rise_p: float = 1.0 - pow(1.0 - clampf(u2 * 1.55, 0.0, 1.0), 2.0)
	var emb_y: float = roundf(lerpf(-20.0, -26.0, rise_p))
	if Lx.camera != null and is_instance_valid(Lx.camera):
		emb_y = maxf(emb_y, roundf((Lx.camera.global_position.y - 76.0) - global_position.y))
	var emb_a: float = clampf((1.0 - u2) * 1.65, 0.0, 1.0)
	if emb_a > 0.05:
		_draw_rising_emblem_halo(emb_y, emb_a)
		_draw_move_emblem(Color(c_main, emb_a), Color(cream if u2 < 0.25 else c_hi, emb_a), emb_y, 0.92)
		for oi: int in range(4):
			var oa: float = _clock * 5.2 + float(oi) * (PI * 0.5)
			var op := Vector2(roundf(cos(oa) * 13.0), roundf(emb_y + sin(oa) * 6.0))
			draw_rect(Rect2(op, Vector2(2.0 if oi % 2 == 0 else 1.0, 1.0)), Color(cream if oi % 2 == 0 else c_hi, emb_a))
	for i: int in range(12):
		var a: float = float(i) * (TAU / 12.0) + u2 * 0.95
		var ease_d: float = 1.0 - pow(1.0 - u2, 2.0)
		var d: float = roundf(lerpf(6.0, 32.0 + float(i % 3) * 6.0, ease_d))
		var drift_y: float = sin(u2 * PI + float(i) * 0.7) * 5.0 - u2 * 14.0 + u2 * u2 * 8.0
		var pt := Vector2(roundf(cos(a) * d), roundf(-14.0 + sin(a) * d * 0.52 + drift_y))
		var m_sz: float = 2.0 if (u2 < 0.40 and i % 2 == 0) else 1.0
		var m_col: Color = cream if (i % 3 == 0) else (c_hi if i % 3 == 1 else c_main)
		draw_rect(Rect2(pt, Vector2(m_sz, m_sz)), Color(m_col, fade))


func _draw_rising_emblem_halo(emb_y: float, emb_a: float) -> void:
	var c_void: Color = Color(PAL["void"] as Color, emb_a * 0.96)
	var c_night: Color = Color(PAL["night"] as Color, emb_a * 0.94)
	var c_gold: Color = Color(PAL["gold"] as Color, emb_a)
	var c_ice: Color = Color(PAL["ice"] as Color, emb_a)
	# 1px PAL["void"] octagonal outer outline (r=9) + PAL["night"] backing disc (r=8)
	draw_rect(Rect2(-9.0, emb_y - 4.0, 18.0, 8.0), c_void)
	draw_rect(Rect2(-8.0, emb_y - 6.0, 16.0, 12.0), c_void)
	draw_rect(Rect2(-6.0, emb_y - 8.0, 12.0, 16.0), c_void)
	draw_rect(Rect2(-4.0, emb_y - 9.0, 8.0, 18.0), c_void)
	draw_rect(Rect2(-8.0, emb_y - 3.0, 16.0, 6.0), c_night)
	draw_rect(Rect2(-7.0, emb_y - 5.0, 14.0, 10.0), c_night)
	draw_rect(Rect2(-5.0, emb_y - 7.0, 10.0, 14.0), c_night)
	draw_rect(Rect2(-3.0, emb_y - 8.0, 6.0, 16.0), c_night)
	# Crisp PAL["gold"] cardinal & PAL["ice"] diagonal trim pixels on the medallion rim
	for gp: Vector2 in [Vector2(-1.0, emb_y - 8.0), Vector2(0.0, emb_y - 8.0), Vector2(-1.0, emb_y + 7.0), Vector2(0.0, emb_y + 7.0), Vector2(-8.0, emb_y - 1.0), Vector2(-8.0, emb_y), Vector2(7.0, emb_y - 1.0), Vector2(7.0, emb_y)]:
		draw_rect(Rect2(gp, Vector2.ONE), c_gold)
	for ip: Vector2 in [Vector2(-6.0, emb_y - 6.0), Vector2(5.0, emb_y - 6.0), Vector2(-6.0, emb_y + 5.0), Vector2(5.0, emb_y + 5.0)]:
		draw_rect(Rect2(ip, Vector2.ONE), c_ice)
