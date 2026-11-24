class_name LxBluePortal
extends LxInteractable
## Playable blue-light powered warp portal.
## Dormant until struck by blue light (reflected off a Blue Transformer) or signaled;
## latches ON (and syncs its paired portal), warping Wick cleanly on contact.

const DEPART_DUR: float = 0.28
const THREAD_DUR: float = 0.16

var powered: bool = false
var requires_blue: bool = true
var pair_sync: bool = true
var target_portal_id: String = ""
var dest_pos: Vector2 = Vector2.ZERO
var has_dest_pos: bool = false
var sets_flag: String = ""
var warp_cd: float = 0.0
var _reject_t: float = 0.0
var _ignite_t: float = 0.0
var _warp_t: float = 0.0
var _depart_t: float = 0.0
var _warp_thread_t: float = 0.0
var _warp_thread_to: Vector2 = Vector2.ZERO
var _anim_stage: int = 0
var _pair_phase: float = 0.0
var _moon_step: int = -1


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "blue_portal"
	radius = maxf(10.0, float(spec.get("radius", props.get("radius", 11.0))))
	requires_blue = bool(props.get("requires_blue", true))
	pair_sync = bool(props.get("pair_sync", true))
	target_portal_id = str(props.get("target_portal_id", "")).strip_edges()
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	has_dest_pos = props.has("dest_pos")
	if has_dest_pos:
		dest_pos = _parse_vec2(props.get("dest_pos"), pos)
	powered = bool(props.get("starts_powered", props.get("powered", false)))
	if not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false)):
		powered = true
	active = true
	warp_cd = 0.0
	_reject_t = 0.0
	_ignite_t = 0.0
	_warp_t = 0.0
	_depart_t = 0.0
	_warp_thread_t = 0.0
	_warp_thread_to = Vector2.ZERO
	_pair_phase = _compute_pair_phase()
	_moon_step = -1
	z_index = -1
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if warp_cd > 0.0:
		warp_cd = maxf(0.0, warp_cd - dt)
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		dirty = true
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		dirty = true
	if _warp_t > 0.0:
		_warp_t = maxf(0.0, _warp_t - dt)
		dirty = true
	if _depart_t > 0.0:
		_depart_t = maxf(0.0, _depart_t - dt)
		dirty = true
	if _warp_thread_t > 0.0:
		_warp_thread_t = maxf(0.0, _warp_thread_t - dt)
		dirty = true
	var rate: float = (1.0 / 0.11) if powered else 1.5
	var st: int = int(floorf(_clock * rate + absf(pos.x * 0.02))) % 4
	if st != _anim_stage:
		_anim_stage = st
		dirty = true
	var m_hz: float = 4.0 if LxHudFx.flash_reduced() else 8.0
	var m_step: int = int(floorf(_clock * m_hz + _pair_phase))
	if m_step != _moon_step:
		_moon_step = m_step
		dirty = true
	if powered and active and warp_cd <= 0.0:
		_check_player_warp()
	if dirty:
		queue_redraw()


func _check_player_warp() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var w: Node2D = Lx.player as Node2D
	if w.get("dead") is bool and bool(w.get("dead")):
		return
	if w.has_method("is_grabbing") and bool(w.call("is_grabbing")):
		return
	if w.global_position.distance_to(pos) > 10.5:
		return
	var paired: LxBluePortal = _get_paired_portal()
	var dest: Vector2 = paired.pos if paired != null else (dest_pos if has_dest_pos else Vector2.INF)
	if not dest.is_finite():
		return
	warp_cd = 0.85
	_warp_t = 0.36
	_depart_t = DEPART_DUR
	if pos.distance_to(dest) <= 240.0:
		_warp_thread_t = THREAD_DUR
		_warp_thread_to = dest - pos
	if paired != null:
		paired.warp_cd = 0.85
		paired._warp_t = 0.36
		paired.queue_redraw()
	var fx_v: Variant = w.get("_fx")
	if fx_v is LxWickFx:
		var fdir: Vector2 = (w.get("facing") as Vector2) if (w.get("facing") is Vector2) else Vector2.RIGHT
		(fx_v as LxWickFx).spawn_afterimage(pos, PAL["ice"] as Color, fdir, "dash", DEPART_DUR)
	if w.has_method("spawn_ring"):
		w.call("spawn_ring", pos, 3.0, 16.0, 0.24, PAL["sky"], 1.5)
		w.call("spawn_sparks", pos, Vector2.UP, 8, PAL["ice"], 35.0, 95.0, 0.22)
	w.global_position = dest
	if w.get("last_pos") is Vector2:
		w.set("last_pos", dest)
	var lan: Variant = w.get("lantern")
	if lan is Object and is_instance_valid(lan) and (lan as Object).has_method("is_in_hand") and bool((lan as Object).call("is_in_hand")):
		if (lan as Object).has_method("reset_to_hand"):
			(lan as Object).call("reset_to_hand", dest)
	if w.has_method("spawn_ring"):
		w.call("spawn_ring", dest, 14.0, 3.0, 0.24, PAL["ice"], 1.5)
		w.call("spawn_sparks", dest, Vector2.UP, 8, PAL["sky"], 35.0, 95.0, 0.22)
	if w.has_method("trigger_hitstop"):
		w.call("trigger_hitstop", 0.035)
	elif Lx.hitstop != null:
		Lx.hitstop.trigger(0.035)
	if Lx.camera != null and is_instance_valid(Lx.camera) and pos.distance_squared_to(dest) > 1.0:
		Lx.camera.add_kick((dest - pos).normalized(), 2.2)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(dest, 60.0, 1.15, 0.24)
	_emit_sfx("waystone_lit")
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if powered:
		return false
	var is_blue_hit: bool = (hit.has_method("is_blue") and hit.is_blue()) or hit.source == LxHit.SOURCE_PRISM
	if requires_blue and not is_blue_hit:
		if hit.source in ["bolt", "beam", "throw", "recall"]:
			_reject_t = 0.42
			_emit_sfx("mirror_ping")
			queue_redraw()
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return false
	_power_on(true)
	return true


func on_signal(_from_id: String, is_on: bool) -> void:
	if is_on:
		_power_on(true)


func _power_on(propagate_pair: bool) -> void:
	var was_powered: bool = powered
	powered = true
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	if not was_powered:
		_ignite_t = 0.45
		_emit_gust(56.0, 38.0)
		_emit_sfx("switch_eye")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.06)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(pos, 64.0, 1.2, 0.28)
		_notify_linked_targets(true)
		if region != null and region.has_method("save_interactables_to_state"):
			region.call("save_interactables_to_state")
	if propagate_pair and pair_sync:
		var paired: LxBluePortal = _get_paired_portal()
		if paired != null and not paired.powered:
			paired._power_on(false)
	queue_redraw()


func _get_paired_portal() -> LxBluePortal:
	if target_portal_id.is_empty() or region == null or not region.has_method("find_interactable"):
		return null
	var found: Variant = region.call("find_interactable", target_portal_id)
	return found as LxBluePortal if found is LxBluePortal else null


func _compute_pair_phase() -> float:
	var partner_key: String = target_portal_id
	if partner_key.is_empty():
		partner_key = str(props.get("pair_id", "")).strip_edges()
	if partner_key.is_empty():
		return 0.0
	var a: String = id if id < partner_key else partner_key
	var b: String = partner_key if id < partner_key else id
	var key: String = a + "|" + b
	var h: int = 0
	for i: int in range(key.length()):
		h = (h * 31 + key.unicode_at(i)) & 0x7fffffff
	return (float(h % 360) / 360.0) * TAU


func _get_partner_pos() -> Vector2:
	var paired: LxBluePortal = _get_paired_portal()
	if paired != null and is_instance_valid(paired):
		return paired.pos
	if has_dest_pos:
		return dest_pos
	return Vector2.INF


func _get_shared_clock() -> float:
	var paired: LxBluePortal = _get_paired_portal()
	if paired != null and is_instance_valid(paired):
		return minf(_clock, paired._clock)
	return _clock


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func get_light_pool() -> Vector4:
	if powered:
		var surge: float = (sin((1.0 - clampf(_ignite_t / 0.45, 0.0, 1.0)) * PI) * 20.0) if _ignite_t > 0.0 else 0.0
		return Vector4(pos.x, pos.y, 46.0 + surge, 0.85)
	if _reject_t > 0.0:
		return Vector4(pos.x, pos.y, 28.0, 0.45)
	return Vector4.ZERO


func save_state() -> Dictionary:
	return {"active": active, "powered": powered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	active = true
	if d.has("powered"):
		powered = bool(d.get("powered", powered))
	queue_redraw()


func _draw() -> void:
	# Flat floor pad — no drop shadow; strictly pixel-art sprites from puzzle_interactables atlas.
	var key: String = "portal_reject" if _reject_t > 0.0 else ("portal_active" if powered else "portal_dormant")
	var frame_ov: int = _anim_stage if key == "portal_active" else 0
	_draw_puzzle_sprite(key, Vector2.ZERO, _clock, Color.WHITE, frame_ov)
	if _reject_t <= 0.0:
		_draw_twin_moon_and_compass()
	if _ignite_t > 0.0:
		var ip: float = 1.0 - clampf(_ignite_t / 0.45, 0.0, 1.0)
		var rad: float = lerpf(6.0, 20.0, ip)
		var c_ig: Color = (PAL["cream"] if ip < 0.4 else PAL["sky"]) as Color
		for k: int in range(8):
			var a: float = (TAU * float(k)) / 8.0
			var pt: Vector2 = Vector2(roundf(cos(a) * rad), roundf(sin(a) * rad))
			var sz: float = 2.0 if ip < 0.35 else 1.0
			draw_rect(Rect2(pt, Vector2(sz, sz)), c_ig if k % 2 == 0 else (PAL["ice"] as Color))
	if _warp_thread_t > 0.0:
		var wt: float = clampf(_warp_thread_t / THREAD_DUR, 0.0, 1.0)
		var fsc: float = 0.65 if LxHudFx.flash_reduced() else 1.0
		var dest_rel: Vector2 = _warp_thread_to.round()
		var o_p := Vector2(0.0, -4.0)
		var d_p: Vector2 = dest_rel + Vector2(0.0, -4.0)
		draw_line(o_p, d_p, Color(PAL["sky"] as Color, wt * 0.55 * fsc), maxf(1.0, 3.0 * wt))
		draw_line(o_p, d_p, Color(PAL["ice"] as Color, wt * 0.90 * fsc), maxf(1.0, 2.0 * wt))
		draw_line(o_p, d_p, Color(PAL["cream"] as Color, wt * fsc), 1.0)
		for ti: int in range(3):
			var frac: float = clampf(0.20 + float(ti) * 0.30 + (1.0 - wt) * 0.12, 0.0, 1.0)
			var tp: Vector2 = o_p.lerp(d_p, frac).round()
			draw_rect(Rect2(tp - Vector2.ONE, Vector2(2.0, 2.0)), Color(PAL["cream"] as Color, wt))
	if _depart_t > 0.0:
		var dp: float = 1.0 - clampf(_depart_t / DEPART_DUR, 0.0, 1.0)
		var da: float = (1.0 - dp) * (0.55 if LxHudFx.flash_reduced() else 0.82)
		draw_rect(Rect2(-3.0, roundf(-11.0 - dp * 4.0), 6.0, 9.0), Color(PAL["sky"] as Color, da * 0.65))
		draw_rect(Rect2(-2.0, roundf(-10.0 - dp * 4.0), 4.0, 7.0), Color(PAL["ice"] as Color, da))
		for dk: int in range(6):
			var a_d: float = (TAU * float(dk)) / 6.0 + dp * 1.4
			var dr: float = lerpf(3.0, 16.0, dp)
			var pt_d := Vector2(roundf(cos(a_d) * dr), roundf(-6.0 + sin(a_d) * dr * 0.6 - dp * 5.0))
			draw_rect(Rect2(pt_d, Vector2(2.0 if dp < 0.35 else 1.0, 1.0)), Color((PAL["cream"] if dk % 2 == 0 else PAL["ice"]) as Color, da))
	if _warp_t > 0.0:
		var wp: float = 1.0 - clampf(_warp_t / 0.36, 0.0, 1.0)
		var wrad: float = lerpf(4.0, 15.0, wp)
		for k: int in range(8):
			var a: float = (TAU * float(k)) / 8.0 + wp * 1.2
			var pt: Vector2 = Vector2(roundf(cos(a) * wrad), roundf(sin(a) * wrad))
			draw_rect(Rect2(pt, Vector2.ONE), (PAL["cream"] if wp < 0.35 else PAL["ice"]) as Color)
	_draw_signal_pulses()


func _draw_twin_moon_and_compass() -> void:
	var reduced: bool = LxHudFx.flash_reduced()
	var sync_t: float = _get_shared_clock()
	var speed: float = (1.1 if reduced else 2.2) if powered else (0.7 if reduced else 1.25)
	var base_ang: float = sync_t * speed + _pair_phase
	var crest: bool = sin(sync_t * (2.0 if reduced else 3.6) + _pair_phase) > 0.35
	var c_deep: Color = PAL["deep"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	# Synchronized twin moon-arc shimmer pulsing in unison across paired portals
	for half_i: int in range(2):
		var a0: float = base_ang + float(half_i) * PI
		for j: int in range(-2, 3):
			var ang: float = a0 + float(j) * 0.24
			var mp: Vector2 = Vector2(roundf(cos(ang) * 10.5), roundf(sin(ang) * 10.5))
			var mc: Color
			if j == 0:
				mc = c_cream if (powered and crest and not reduced) else c_ice
			elif absi(j) == 1:
				mc = c_ice if (powered or crest) else c_sky
			else:
				mc = c_sky if powered else c_deep
			draw_rect(Rect2(mp, Vector2.ONE), mc)
	# Crisp 2x2 directional partner compass pip on outer rim (r = 12 px)
	var p_pos: Vector2 = _get_partner_pos()
	if p_pos.is_finite() and pos.distance_squared_to(p_pos) > 4.0:
		var dir: Vector2 = (p_pos - pos).normalized()
		var tip: Vector2 = (dir * 12.0).round()
		draw_rect(Rect2((dir * 10.0).round(), Vector2.ONE), c_sky)
		draw_rect(Rect2(tip - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if powered else c_ice)
		if crest and not powered and not reduced:
			draw_rect(Rect2(tip, Vector2.ONE), c_cream)
