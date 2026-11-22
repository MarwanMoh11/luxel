class_name LxShrine
extends LxInteractable
## Move Shrine: unlocks props.move_id, emits shrine_claimed + save_requested.

var claimed: bool = false
var move_id: String = ""


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "shrine"
	move_id = str(props.get("move_id", ""))
	claimed = bool(props.get("claimed", false))
	if Lx.state != null:
		if Lx.state.claimed_shrines.has(id) or (not move_id.is_empty() and Lx.state.has_move(move_id)):
			claimed = true
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = not claimed
	super.tick(dt)


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	claimed = true
	if Lx.state != null:
		if not move_id.is_empty():
			Lx.state.unlock_move(move_id)
		if not id.is_empty() and not Lx.state.claimed_shrines.has(id):
			Lx.state.claimed_shrines.append(id)
	if Lx.events != null:
		Lx.events.shrine_claimed.emit(id, move_id)
		Lx.events.shake_requested.emit(0.14)
	_emit_sfx("shrine_claimed")
	_emit_save("shrine_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
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
	var is_throw: bool = move_id == "throw"
	var c_main: Color = (PAL["gold"] as Color) if is_throw else (PAL["sky"] as Color)
	var c_hi: Color = (PAL["cream"] as Color) if is_throw else (PAL["ice"] as Color)
	if not claimed:
		_draw_floor_ring(false, c_main, c_hi)
	var prop_key: String = "shrine_throw" if is_throw else "shrine"
	var frame_ov: int = 0 if claimed else -1
	var tint: Color = (PAL["mauve"] as Color) if claimed else Color.WHITE
	if not _draw_prop_sprite(prop_key, Vector2.ZERO, frame_ov, tint):
		_draw_fallback()
	if not claimed:
		_draw_floor_ring(true, c_main, c_hi)
		_draw_starlight_motes(c_main, c_hi)


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
