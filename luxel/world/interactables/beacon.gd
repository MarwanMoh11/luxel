class_name LxBeacon
extends LxInteractable
## Zone Beacon: unlocks once its zone's enemies are cleared, lights on interact or heavy light hit,
## emits beacon_lit, and lifts zone darkness via LxRegionLoader + LxDarknessLayer.

var lit: bool = false
var ignitable: bool = false
var zone_id: String = ""
var require_clear: bool = true


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "beacon"
	zone_id = str(props.get("zone", ""))
	require_clear = bool(props.get("require_clear", true))
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.lit_beacons.has(id):
		lit = true
	ignitable = lit or not require_clear
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if lit:
		ignitable = true
		return
	var cleared: bool = not require_clear
	if require_clear and region != null and region.has_method("is_zone_cleared"):
		cleared = bool(region.call("is_zone_cleared", zone_id))
	if cleared != ignitable:
		ignitable = cleared
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or lit or not ignitable:
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
