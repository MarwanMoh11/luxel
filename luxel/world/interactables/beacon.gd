class_name LxBeacon
extends LxInteractable
## Zone Beacon: unlocks once its zone's enemies are cleared, lights on interact or heavy light hit,
## emits beacon_lit, and lifts zone darkness via LxRegionLoader + LxDarknessLayer.

var lit: bool = false
var ignitable: bool = false
var zone_id: String = ""
var require_clear: bool = true
var _unlock_t: float = 0.0
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
	_synced_once = false
	queue_redraw()


func tick(dt: float) -> void:
	if _unlock_t > 0.0:
		_unlock_t = maxf(0.0, _unlock_t - dt)
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
	if Lx.state != null and not id.is_empty() and not Lx.state.lit_beacons.has(id):
		Lx.state.lit_beacons.append(id)
	if Lx.events != null:
		Lx.events.beacon_lit.emit(island_id, id)
		Lx.events.shake_requested.emit(0.18)
	_emit_sfx("beacon_lit")
	_emit_save("beacon_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if lit:
		return Vector4(pos.x, pos.y - 12.0, 124.0, 1.4)
	if ignitable:
		return Vector4(pos.x, pos.y - 10.0, 52.0, 0.85)
	return Vector4(pos.x, pos.y - 8.0, 22.0, 0.35)


func get_interact_prompt() -> String:
	if lit or not ignitable:
		return ""
	return "PROMPT_LIGHT_BEACON"


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
	var jx: float = roundf(sin(_locked_t * 55.0) * 1.5) if _locked_t > 0.0 else 0.0
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
			draw_arc(Vector2(0.0, -10.0), roundf(lerpf(6.0, 34.0, u)), 0.0, TAU, 20, (PAL["cream"] if u < 0.35 else PAL["gold"]) as Color, 2.0 if u < 0.4 else 1.0, false)
	elif lit:
		_draw_lit_embers()
	_draw_signal_pulses()


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
	var c_gold: Color = PAL["gold"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	for i: int in range(12):
		var a: float = _clock * 0.65 + (TAU * float(i)) / 12.0
		var sa: float = sin(a)
		if (sa >= 0.0) != front:
			continue
		var px: float = roundf(cos(a) * rx)
		var py: float = roundf(2.0 + sa * ry)
		draw_rect(Rect2(px - 1.0, py, 2.0, 1.0), c_gold if (i % 2 == 0) else c_apr)


func _draw_ready_sparks() -> void:
	var c_gold: Color = PAL["gold"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	for i: int in range(3):
		var t: float = fmod(_clock * 0.62 + float(i) * 0.33, 1.0)
		var px: float = roundf(sin(_clock * 2.1 + float(i) * 2.2) * 4.5)
		var py: float = roundf(-17.0 - t * 14.0)
		draw_rect(Rect2(px, py, 1.0, 1.0), c_gold if t < 0.55 else c_apr)


func _draw_lit_embers() -> void:
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	for i: int in range(3):
		var t: float = fmod(_clock * 0.48 + float(i) * 0.33, 1.0)
		var px: float = roundf(sin(_clock * 1.7 + float(i) * 2.1) * (2.5 + t * 2.5))
		var py: float = roundf(-24.0 - t * 18.0)
		var col: Color = c_cream if t < 0.3 else (c_gold if t < 0.7 else c_apr)
		draw_rect(Rect2(px, py, 1.0, 1.0), col)
