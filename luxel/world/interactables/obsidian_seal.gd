class_name LxObsidianSeal
extends LxInteractable
## Heavy obsidian barrier shattered only by Sunflare.

var shattered: bool = false
var size: Vector2 = Vector2(32.0, 16.0)


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "obsidian_seal"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	shattered = bool(props.get("shattered", false))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source == "sunflare":
		shattered = true
		active = false
		if Lx.state != null and not id.is_empty() and not Lx.state.broken_seals.has(id):
			Lx.state.broken_seals.append(id)
		if Lx.events != null:
			Lx.events.seal_broken.emit(island_id, id)
			Lx.events.shake_requested.emit(0.24)
		_emit_sfx("seal_shatter")
		_emit_save("seal_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active and not shattered


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "shattered": shattered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	shattered = bool(d.get("shattered", shattered))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	queue_redraw()


func _draw() -> void:
	if shattered or not active:
		return
	var half: Vector2 = size * 0.5
	draw_rect(Rect2(-half, size), PAL["void"])
	draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["night"])
	draw_rect(Rect2(-half + Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), PAL["dusk"])
	draw_circle(Vector2.ZERO, 4.0, PAL["coral"])
	draw_circle(Vector2.ZERO, 2.0, PAL["gold"])
