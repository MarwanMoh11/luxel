class_name LxGreatLamp
extends LxInteractable
## End-of-island Great Lamp / Great Belfry Brazier: relights the island and opens the bridge to the next island.

var lit: bool = false
var requires_boss: String = ""
var requires_flag: String = ""


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "great_lamp"
	requires_boss = str(props.get("requires_boss", ""))
	requires_flag = str(props.get("requires_flag", ""))
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.relit_islands.has(island_id):
		lit = true
	queue_redraw()


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
	if Lx.state != null:
		if not Lx.state.relit_islands.has(island_id):
			Lx.state.relit_islands.append(island_id)
		Lx.state.story_flags["island_%d_bridge_open" % island_id] = true
		Lx.state.heal_full()
	if Lx.events != null:
		Lx.events.great_lamp_relit.emit(island_id)
		Lx.events.shake_requested.emit(0.24)
		var idata: Dictionary = Lx.get_island_data(island_id)
		var rline: String = str(idata.get("relight_line", ""))
		if not rline.is_empty():
			Lx.events.narration_requested.emit(rline, "title", 4.0)
	_emit_sfx("great_lamp_relit")
	_emit_save("great_lamp_%d" % island_id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if lit:
		return Vector4(pos.x, pos.y - 16.0, 148.0, 1.6)
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
	draw_rect(Rect2(-12.0, -5.0, 24.0, 10.0), PAL["night"])
	draw_rect(Rect2(-10.0, -8.0, 20.0, 10.0), PAL["dusk"])
	draw_rect(Rect2(-8.0, -20.0, 16.0, 14.0), PAL["mauve"])
	draw_rect(Rect2(-6.0, -18.0, 12.0, 10.0), PAL["stone"])
	if lit:
		draw_circle(Vector2(0.0, -22.0), 8.0, PAL["apricot"])
		draw_circle(Vector2(0.0, -22.0), 5.5, PAL["gold"])
		draw_circle(Vector2(0.0, -22.0), 3.0, PAL["cream"])
	elif _can_relight():
		draw_circle(Vector2(0.0, -21.0), 4.0, PAL["coral"])
		draw_circle(Vector2(0.0, -21.0), 2.0, PAL["gold"])
	else:
		draw_rect(Rect2(-5.0, -22.0, 10.0, 4.0), PAL["plum"])
