class_name LxWaystone
extends LxInteractable
## Restores full hearts, sets the respawn point, unlocks fast travel, and requests an autosave.

var lit: bool = false
var _dormant_pip_on: bool = false
var _pulse_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "waystone"
	lit = bool(props.get("lit", false))
	if Lx.state != null and Lx.state.lit_waystones.has(id):
		lit = true
	_dormant_pip_on = _is_dormant_pip_on()
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = lit
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	if not lit:
		var pip_on: bool = _is_dormant_pip_on()
		if pip_on != _dormant_pip_on:
			_dormant_pip_on = pip_on
			queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	var first_time: bool = not lit
	lit = true
	_pulse_t = 0.48 if first_time else 0.32
	if Lx.state != null:
		if not id.is_empty() and not Lx.state.lit_waystones.has(id):
			Lx.state.lit_waystones.append(id)
		Lx.state.heal_full()
		Lx.state.last_waystone_island = island_id
		Lx.state.last_waystone_id = id
		Lx.state.spawn_pos = pos + Vector2(0.0, 14.0)
	if Lx.events != null:
		Lx.events.waystone_lit.emit(island_id, id)
		if first_time:
			Lx.events.narration_requested.emit("CUE_WAYSTONE_LIT", "title", 2.5)
	_emit_gust(76.0 if first_time else 52.0, 64.0 if first_time else 40.0, Vector2(0.0, -8.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, pos, 16.0 if first_time else 12.0, 6.0)
	_emit_sfx("waystone_lit" if first_time else "waystone_rest")
	_emit_save("waystone_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if lit:
		var surge: float = (sin((1.0 - clampf(_pulse_t / 0.48, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _pulse_t > 0.0 else 0.0
		return Vector4(pos.x, pos.y - 10.0, 58.0 + surge * 44.0, 1.05 + surge * 0.42)
	return Vector4(pos.x, pos.y - 8.0, 26.0, 0.45)


func get_interact_prompt() -> String:
	return "PROMPT_WAYSTONE_REST" if lit else "PROMPT_WAYSTONE_LIGHT"


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	if Lx.state != null and Lx.state.lit_waystones.has(id):
		lit = true
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-8.0, 1.0, 16.0, 2.0), shadow)
	draw_rect(Rect2(-6.0, 0.0, 12.0, 4.0), shadow)
	var frame_ov: int = -1 if lit else 0
	if not _draw_prop_sprite("waystone" if lit else "waystone_dormant", Vector2.ZERO, frame_ov):
		_draw_fallback()
	if lit:
		_draw_lit_aura()
	elif _is_dormant_pip_on():
		draw_rect(Rect2(0.0, -17.0, 1.0, 1.0), PAL["sky"])
	if _pulse_t > 0.0:
		var p: float = 1.0 - clampf(_pulse_t / 0.48, 0.0, 1.0)
		var wc: Array[Color] = _biome_waystone_colors()
		draw_arc(Vector2(0.0, -8.0), roundf(5.0 + p * 22.0), 0.0, TAU, 18, wc[1] if p < 0.4 else wc[0], 1.0)
		for j: int in range(6):
			var a: float = float(j) * TAU / 6.0 + p * 0.9
			var sp := Vector2(roundf(cos(a) * (4.0 + p * 18.0)), roundf(-10.0 + sin(a) * (2.0 + p * 7.0) - p * 10.0))
			draw_rect(Rect2(sp, Vector2(1.0, 1.0)), PAL["cream"] if j % 2 == 0 else wc[1])


func _draw_fallback() -> void:
	draw_rect(Rect2(-6.0, -3.0, 12.0, 6.0), PAL["night"])
	draw_rect(Rect2(-5.0, -14.0, 10.0, 13.0), PAL["dusk"])
	draw_rect(Rect2(-4.0, -13.0, 8.0, 11.0), PAL["stone"])
	if lit:
		draw_rect(Rect2(-2.0, -11.0, 4.0, 7.0), PAL["sky"])
		draw_rect(Rect2(-1.0, -10.0, 2.0, 5.0), PAL["ice"])
		draw_circle(Vector2(0.0, -15.0), 2.5, PAL["gold"])
	else:
		draw_rect(Rect2(-2.0, -11.0, 4.0, 7.0), PAL["deep"])


func _biome_waystone_colors() -> Array[Color]:
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
			return [PAL["coral"] as Color, PAL["apricot"] as Color]
		7:
			return [PAL["ice"] as Color, PAL["cream"] as Color]
		8:
			return [PAL["rose"] as Color, PAL["gold"] as Color]
		_:
			return [PAL["sky"] as Color, PAL["gold"] as Color]


func _draw_lit_aura() -> void:
	var wc: Array[Color] = _biome_waystone_colors()
	var pulse: float = sin(_clock * 2.6)
	var base_col: Color = wc[0] if pulse > 0.0 else (PAL["blue"] as Color)
	draw_rect(Rect2(-1.0, 2.0, 2.0, 1.0), base_col)
	if pulse > 0.45:
		draw_rect(Rect2(0.0, 1.0, 1.0, 1.0), wc[1])
	var lanes: Array[float] = [-8.0, 7.0, -5.0]
	for i: int in range(3):
		var t: float = fmod(_clock * 0.42 + float(i) * 0.33, 1.0)
		var px: float = roundf(lanes[i] + sin(_clock * 1.5 + float(i) * 2.0) * 1.5)
		var py: float = roundf(-5.0 - t * 27.0)
		draw_rect(Rect2(px, py, 1.0, 1.0), wc[1] if t < 0.5 else wc[0])


func _is_dormant_pip_on() -> bool:
	var phase: float = fmod(absf(pos.x * 0.023 + pos.y * 0.019), 2.6)
	return fmod(_clock + phase, 2.6) < 0.75
