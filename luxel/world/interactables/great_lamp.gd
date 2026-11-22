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
		var col_w: float = roundf(maxf(0.0, (1.0 - p) * 16.0))
		if col_w >= 2.0:
			draw_rect(Rect2(-floorf(col_w * 0.5), -68.0, col_w, 72.0), PAL["gold"] if p > 0.3 else PAL["cream"])
		if p < 0.75:
			draw_rect(Rect2(-2.0, -68.0, 4.0, 72.0), PAL["cream"])
		draw_arc(Vector2(0.0, -14.0), roundf(8.0 + p * 44.0), 0.0, TAU, 24, PAL["cream"] if p < 0.35 else PAL["gold"], 2.0 if p < 0.4 else 1.0)
	_draw_signal_pulses()


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
	var breath: float = sin(_clock * 2.2) * 2.0
	_draw_orbit_ring(front, 12, 26.0 + breath, 8.0 + breath * 0.35, 0.55, PAL["gold"] as Color, PAL["apricot"] as Color)
	_draw_orbit_ring(front, 8, 20.0 - breath * 0.5, 6.0, -0.85, PAL["cream"] as Color, PAL["gold"] as Color)


func _draw_orbit_ring(
	front: bool, count: int, rx: float, ry: float, speed: float, c_a: Color, c_b: Color
) -> void:
	for i: int in range(count):
		var a: float = _clock * speed + (TAU * float(i)) / float(count)
		var sa: float = sin(a)
		if (sa >= 0.0) == front:
			draw_rect(Rect2(roundf(cos(a) * rx), roundf(1.0 + sa * ry), 1.0, 1.0), c_a if i % 2 == 0 else c_b)


func _draw_beckon_motes() -> void:
	for i: int in range(4):
		var t: float = fmod(_clock * 0.5 + float(i) * 0.25, 1.0)
		var px: float = roundf(sin(_clock * 1.8 + float(i) * 1.57) * 12.0)
		draw_rect(Rect2(px, roundf(-14.0 - t * 36.0), 1.0, 1.0), PAL["cream"] if t < 0.45 else PAL["gold"])


func _draw_dawn_embers() -> void:
	for i: int in range(5):
		var t: float = fmod(_clock * 0.44 + float(i) * 0.2, 1.0)
		var px: float = roundf(sin(_clock * 1.6 + float(i) * 1.3) * (4.0 + t * 7.0))
		var col: Color = (PAL["cream"] if t < 0.28 else (PAL["gold"] if t < 0.68 else PAL["apricot"])) as Color
		draw_rect(Rect2(px, roundf(-28.0 - t * 32.0), 1.0, 1.0), col)
