class_name LxBeacon
extends LxInteractable
## Zone Beacon: unlocks once its zone's enemies are cleared, lights on interact or heavy light hit,
## emits beacon_lit, and lifts zone darkness via LxRegionLoader + LxDarknessLayer.

const IGNITE_DUR: float = 0.95
const APEX_T: float = 0.14

var lit: bool = false
var ignitable: bool = false
var zone_id: String = ""
var require_clear: bool = true
var _unlock_t: float = 0.0
var _ignite_t: float = 0.0
var _ignite_apex_fired: bool = false
var _unlock_from: Vector2 = Vector2.ZERO
var _locked_t: float = 0.0
var _synced_once: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "beacon"
	zone_id = str(props.get("zone", ""))
	require_clear = bool(props.get("require_clear", true))
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.lit_beacons.has(id):
		lit = true
	ignitable = lit or not require_clear
	_unlock_t = 0.0
	_ignite_t = 0.0
	_ignite_apex_fired = false
	_unlock_from = Vector2.ZERO
	_synced_once = false
	queue_redraw()


func tick(dt: float) -> void:
	if _unlock_t > 0.0:
		_unlock_t = maxf(0.0, _unlock_t - dt)
		queue_redraw()
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		if not _ignite_apex_fired and (IGNITE_DUR - _ignite_t) >= APEX_T:
			_fire_ignite_apex()
		queue_redraw()
	if _locked_t > 0.0:
		_locked_t = maxf(0.0, _locked_t - dt)
		queue_redraw()
	if lit:
		ignitable = true
	else:
		var cleared: bool = not require_clear
		if require_clear and region != null and region.has_method("is_zone_cleared"):
			cleared = bool(region.call("is_zone_cleared", zone_id))
		if cleared != ignitable:
			if cleared and _synced_once:
				_unlock_t = 0.55
				_unlock_from = Vector2.ZERO
				if Lx.player is Node2D and is_instance_valid(Lx.player):
					var delta_p: Vector2 = (Lx.player as Node2D).global_position - pos
					if delta_p.length() > 14.0 and delta_p.length() <= 260.0:
						_unlock_from = delta_p
				_emit_gust(62.0, 54.0, Vector2(0.0, -10.0))
				_emit_sfx("ember_pickup")
			ignitable = cleared
			queue_redraw()
		_synced_once = true
	_uses_prop_anim = lit or ignitable
	super.tick(dt)


func interact(_actor: Node = null) -> bool:
	if not active or lit:
		return false
	if not ignitable:
		_locked_t = 0.24
		_emit_sfx("door_locked")
		queue_redraw()
		return false
	return _ignite()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or lit or not ignitable:
		return false
	if hit.source in ["throw", "recall", "beam", "sunflare", "zip"]:
		return _ignite()
	return false


func _ignite() -> bool:
	lit = true
	ignitable = true
	_ignite_t = IGNITE_DUR
	_ignite_apex_fired = false
	if Lx.state != null and not id.is_empty() and not Lx.state.lit_beacons.has(id):
		Lx.state.lit_beacons.append(id)
	if Lx.events != null:
		Lx.events.beacon_lit.emit(island_id, id)
	_emit_sfx("beacon_lit")
	LxBeaconRituals.on_beacon_ignited(self)
	_emit_save("beacon_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func _fire_ignite_apex() -> void:
	_ignite_apex_fired = true
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.18)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.trigger_focus_nudge(pos, 0.65)
		Lx.camera.add_kick(Vector2.UP, 2.5)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.trigger_focus_flash(0.75)
	_emit_gust(112.0, 96.0, Vector2(0.0, -10.0))


func get_light_pool() -> Vector4:
	if lit:
		var surge: float = 0.0
		if _ignite_t > 0.0:
			var el: float = IGNITE_DUR - _ignite_t
			if el < APEX_T:
				surge = lerpf(0.25, 0.6, el / APEX_T)
			else:
				var u2: float = clampf((el - APEX_T) / (IGNITE_DUR - APEX_T), 0.0, 1.0)
				surge = (1.0 - u2) * (1.0 - u2 * 0.4)
			surge *= (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 12.0, 124.0 + surge * 64.0, 1.4 + surge * 0.55)
	if ignitable:
		return Vector4(pos.x, pos.y - 10.0, 52.0, 0.85)
	return Vector4(pos.x, pos.y - 8.0, 22.0, 0.35)


func get_interact_prompt() -> String:
	if lit or not ignitable:
		return ""
	match island_id:
		2: return "PROMPT_LIGHT_BEACON_2"
		3: return "PROMPT_LIGHT_BEACON_3"
		4: return "PROMPT_LIGHT_BEACON_4"
		5: return "PROMPT_LIGHT_BEACON_5"
		6: return "PROMPT_LIGHT_BEACON_6"
		7: return "PROMPT_LIGHT_BEACON_7"
		8: return "PROMPT_LIGHT_BEACON_8"
		_: return "PROMPT_LIGHT_BEACON"


func save_state() -> Dictionary:
	return {"active": active, "lit": lit, "ignitable": ignitable}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	ignitable = bool(d.get("ignitable", ignitable))
	if Lx.state != null and Lx.state.lit_beacons.has(id):
		lit = true
		ignitable = true
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-14.0, 2.0, 28.0, 2.0), shadow)
	draw_rect(Rect2(-12.0, 1.0, 24.0, 4.0), shadow)
	draw_rect(Rect2(-8.0, 0.0, 16.0, 6.0), shadow)
	var ready: bool = not lit and ignitable
	var jx: float = roundf(sin(_locked_t * 55.0) * 1.5) if (_locked_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	if ready:
		_draw_invite_ring(false)
	var frame_ov: int = -1 if (lit or ignitable) else 0
	if not _draw_prop_sprite("beacon" if lit else "beacon_unlit", Vector2(jx, 0.0), frame_ov):
		_draw_fallback()
	if not lit and not ignitable:
		var wc: Color = (PAL["coral"] if _locked_t > 0.0 else PAL["plum"]) as Color
		for k: int in range(8):
			var wa: float = _clock * 0.4 + float(k) * (TAU / 8.0)
			draw_rect(Rect2(roundf(cos(wa) * 13.0) + jx, roundf(1.5 + sin(wa) * 4.0), 2.0, 1.0), wc)
	if ready:
		_draw_invite_ring(true)
		_draw_ready_sparks()
		if _unlock_t > 0.0:
			var u: float = 1.0 - clampf(_unlock_t / 0.55, 0.0, 1.0)
			var w_u: float = 2.0 if u < 0.4 else 1.0
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, (PAL["cream"] if u < 0.35 else PAL["gold"]) as Color, w_u, false)
			if _unlock_from.length_squared() > 16.0:
				for tk: int in range(3):
					var tu: float = clampf(u * 1.15 - float(tk) * 0.08, 0.0, 1.0)
					var tp: Vector2 = (_unlock_from.lerp(Vector2(0.0, -14.0), tu) + Vector2(0.0, -sin(tu * PI) * 18.0)).round()
					draw_rect(Rect2(tp, Vector2(2.0 if tk == 0 else 1.0, 2.0 if tk == 0 else 1.0)), (PAL["cream"] if tk == 0 else PAL["gold"]) as Color)
	elif lit:
		_draw_lit_embers()
		if _ignite_t > 0.0:
			_draw_ignite_wave()
	var crown_t: float = clampf(_ignite_t, 0.0, 0.56) if (lit and _ignite_t > 0.0 and (IGNITE_DUR - _ignite_t) >= APEX_T) else 0.0
	LxBeaconRituals.draw_biome_crown(self, island_id, lit, ignitable, _clock, crown_t)
	_draw_signal_pulses()


func _draw_ignite_wave() -> void:
	var el: float = IGNITE_DUR - _ignite_t
	var c_gl: Color = LxBiomePalette.col(island_id, "glow")
	var c_hi: Color = LxBiomePalette.col(island_id, "hi")
	var cream: Color = PAL["cream"] as Color
	# Beat 1 (0.00-0.14s): hearth-catch flash + 6 inward sparks drawn into the bowl
	if el < APEX_T:
		var u1: float = clampf(el / APEX_T, 0.0, 1.0)
		draw_circle(Vector2(0.0, -14.0), roundf(lerpf(3.0, 7.5, u1)), cream if u1 > 0.5 else (PAL["gold"] as Color))
		draw_arc(Vector2(0.0, -14.0), roundf(lerpf(22.0, 5.0, u1)), 0.0, TAU, 16, c_gl, 1.0)
		for k: int in range(6):
			var ka: float = float(k) * (TAU / 6.0) + u1 * 1.4
			var kd: float = roundf(lerpf(24.0, 3.0, u1))
			draw_rect(Rect2(roundf(cos(ka) * kd), roundf(-14.0 + sin(ka) * kd * 0.65), 2.0, 2.0), cream if k % 2 == 0 else c_gl)
		return
	# Beat 2 & 3 (0.14-0.95s): tall biome-crowned sky pillar (-72px) + 2 staggered expanding horizon rings
	var u2: float = clampf((el - APEX_T) / (IGNITE_DUR - APEX_T), 0.0, 1.0)
	var fade: float = 1.0 - u2
	var cw: float = roundf(maxf(0.0, fade * 12.0))
	if cw >= 2.0:
		draw_rect(Rect2(-floorf(cw * 0.5), -72.0, cw, 74.0), Color(c_gl, fade * 0.85))
	var core_w: float = roundf(maxf(0.0, (1.0 - u2 * 1.25) * 4.0))
	if core_w >= 1.0:
		draw_rect(Rect2(-floorf(core_w * 0.5), -72.0, core_w, 74.0), Color(cream, minf(1.0, fade * 1.2)))
	var e1: float = 1.0 - pow(1.0 - u2, 2.0)
	var w1: float = 2.0 if u2 < 0.35 else 1.0
	draw_arc(Vector2(0.0, -12.0), roundf(lerpf(8.0, 64.0, e1)), 0.0, TAU, 26, Color(cream if u2 < 0.25 else c_gl, fade), w1, false)
	if u2 > 0.12:
		var u2b: float = clampf((u2 - 0.12) / 0.88, 0.0, 1.0)
		var e2: float = 1.0 - pow(1.0 - u2b, 2.0)
		var w2: float = 2.0 if u2b < 0.3 else 1.0
		draw_arc(Vector2(0.0, -12.0), roundf(lerpf(4.0, 42.0, e2)), 0.0, TAU, 22, Color(c_hi if u2b > 0.25 else cream, 1.0 - u2b), w2, false)
	for i: int in range(10):
		var a: float = float(i) * (TAU / 10.0) + u2 * 0.8
		var d: float = roundf(lerpf(5.0, 34.0 + float(i % 2) * 8.0, e1))
		var pt := Vector2(roundf(cos(a) * d), roundf(-14.0 + sin(a) * d * 0.45 - u2 * 22.0))
		draw_rect(Rect2(pt, Vector2(2.0 if u2 < 0.35 else 1.0, 2.0 if u2 < 0.35 else 1.0)), Color(cream if i % 3 == 0 else (c_gl if i % 3 == 1 else c_hi), fade))


func _draw_fallback() -> void:
	draw_rect(Rect2(-8.0, -4.0, 16.0, 8.0), PAL["night"])
	draw_rect(Rect2(-7.0, -5.0, 14.0, 7.0), PAL["dusk"])
	draw_rect(Rect2(-5.0, -14.0, 10.0, 10.0), PAL["mauve"])
	draw_rect(Rect2(-4.0, -13.0, 8.0, 8.0), PAL["stone"])
	if lit:
		draw_circle(Vector2(0.0, -16.0), 5.0, PAL["gold"])
		draw_circle(Vector2(0.0, -16.0), 3.0, PAL["cream"])
	elif ignitable:
		draw_circle(Vector2(0.0, -15.0), 3.0, PAL["apricot"])
		draw_circle(Vector2(0.0, -15.0), 1.5, PAL["gold"])
	else:
		draw_rect(Rect2(-3.0, -16.0, 6.0, 3.0), PAL["plum"])


func _draw_invite_ring(front: bool) -> void:
	var pulse: float = sin(_clock * 3.0) * 1.2
	var rx: float = 17.5 + pulse
	var ry: float = 5.5 + pulse * 0.3
	var c_gold: Color = LxBiomePalette.col(island_id, "glow")
	var c_apr: Color = LxBiomePalette.col(island_id, "hi")
	for i: int in range(12):
		var a: float = _clock * 0.65 + (TAU * float(i)) / 12.0
		var sa: float = sin(a)
		if (sa >= 0.0) != front:
			continue
		var px: float = roundf(cos(a) * rx)
		var py: float = roundf(2.0 + sa * ry)
		draw_rect(Rect2(px - 1.0, py, 2.0, 1.0), c_gold if (i % 2 == 0) else c_apr)


func _draw_ready_sparks() -> void:
	var c_gold: Color = LxBiomePalette.col(island_id, "glow")
	var c_apr: Color = LxBiomePalette.col(island_id, "hi")
	for i: int in range(3):
		var t: float = fmod(_clock * 0.62 + float(i) * 0.33, 1.0)
		var px: float = roundf(sin(_clock * 2.1 + float(i) * 2.2) * 4.5)
		var py: float = roundf(-17.0 - t * 14.0)
		draw_rect(Rect2(px, py, 1.0, 1.0), c_gold if t < 0.55 else c_apr)


func _draw_lit_embers() -> void:
	var c_cream: Color = PAL["cream"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_hi: Color = LxBiomePalette.col(island_id, "hi")
	for i: int in range(3):
		var t: float = fmod(_clock * 0.48 + float(i) * 0.33, 1.0)
		var px: float = roundf(sin(_clock * 1.7 + float(i) * 2.1) * (2.5 + t * 2.5))
		var py: float = roundf(-24.0 - t * 18.0)
		var col: Color = c_cream if t < 0.3 else (c_glow if t < 0.7 else c_hi)
		draw_rect(Rect2(px, py, 1.0, 1.0), col)
