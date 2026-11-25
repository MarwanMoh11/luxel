class_name LxLyingPortrait
extends LxToy
## Island 1 Manor Portrait toy with two modes:
## 1) mode="verdict" (default, Bible section 6): Whodunit suspect portrait (`butler`|`choir`|`steward`).
##    States: IDLE (eyes track Wick & slyly glance at `points_to`), EXPOSED (`clue_flag` lights lectern),
##    ACCUSED_RIGHT (swings open on hinges, sets `manor_verdict="right"`), ACCUSED_WRONG (coral flare + `verdict_wrong`).
## 2) mode="watcher" (Hall of Shifting Eyes): Wall-shifting Portrait Eye with sweeping lamp-vision cone.
##    Queries LxIsland1Rule.can_cone_see_light(); powers linked `mover_wall` targets on lit Wick or thrown lantern;
##    cloaked Wick (Shutter Hood) passes unseen; Dusk ring freezes exact state for 2.5 s; War cracks glass for 3.0 s.

enum State { IDLE, EXPOSED, ACCUSED_RIGHT, ACCUSED_WRONG, WATCHING, ALERTED, FROZEN, CRACKED }

var mode: String = "verdict"
var suspect: String = "butler"
var is_culprit: bool = false
var points_to: Variant = ""
var clue_flag: String = ""
var verdict_bell_id: String = ""
var open_door_id: String = ""

var watch_dir: Vector2 = Vector2.DOWN
var cone_range: float = 108.0
var cone_half_rad: float = deg_to_rad(30.0)
var sweep_rad: float = deg_to_rad(28.0)
var sweep_speed: float = 0.65
var freeze_secs: float = 2.5
var current_look: Vector2 = Vector2.DOWN

var state: int = State.IDLE
var _glance_t: float = 0.0
var _flare_t: float = 0.0
var _freeze_left: float = 0.0
var _crack_left: float = 0.0
var _sweep_phase: float = 0.0
var _eye_offset: Vector2 = Vector2.ZERO
var _last_alert_kind: String = "calm"


func _toy_setup() -> void:
	kind = "lying_portrait"
	mode = str(props.get("mode", "verdict")).strip_edges().to_lower()
	if mode not in ["verdict", "watcher"]:
		mode = "verdict"
	suspect = str(props.get("suspect", "butler")).strip_edges().to_lower()
	is_culprit = bool(props.get("is_culprit", suspect == "steward"))
	points_to = props.get("points_to", "")
	clue_flag = str(props.get("clue_flag", "")).strip_edges()
	verdict_bell_id = str(props.get("verdict_bell_id", "")).strip_edges()
	open_door_id = str(props.get("open_door_id", "")).strip_edges()
	watch_dir = dir_vec("dir", Vector2.DOWN)
	if watch_dir.length_squared() <= 0.001:
		watch_dir = Vector2.DOWN
	current_look = watch_dir
	cone_range = maxf(32.0, float(props.get("cone_range", 108.0)))
	cone_half_rad = deg_to_rad(clampf(float(props.get("cone_deg", 60.0)) * 0.5, 8.0, 85.0))
	sweep_rad = deg_to_rad(clampf(float(props.get("sweep_deg", 32.0)), 0.0, 90.0))
	sweep_speed = float(props.get("sweep_speed", 0.65))
	freeze_secs = maxf(0.5, float(props.get("freeze_secs", 2.5)))
	size = _parse_size(props.get("size", [22.0, 26.0]), Vector2(22.0, 26.0))
	radius = maxf(size.x, size.y) * 0.5
	_glance_t = 0.0
	_flare_t = 0.0
	_freeze_left = 0.0
	_crack_left = 0.0
	_sweep_phase = float(props.get("phase_offset", 0.0))
	_last_alert_kind = "calm"
	state = State.WATCHING if mode == "watcher" else State.IDLE
	_sync_clue_state()
	queue_redraw()


func reset_toy() -> void:
	if persist and state in [State.ACCUSED_RIGHT, State.ACCUSED_WRONG]:
		return
	_freeze_left = 0.0
	_crack_left = 0.0
	_flare_t = 0.0
	_last_alert_kind = "calm"
	state = State.WATCHING if mode == "watcher" else State.IDLE
	set_powered(false)
	_notify_linked_targets(false)
	_sync_clue_state()
	queue_redraw()


func is_solid() -> bool:
	return active and state != State.ACCUSED_RIGHT


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "throw", "recall", "zip"]:
		_flare_t = 0.25
		_emit_sfx("shield_clang")
		queue_redraw()
		return true
	return false


func on_signal(from_id: String, is_on: bool) -> void:
	if mode == "verdict" and is_on and not verdict_bell_id.is_empty() and from_id == verdict_bell_id:
		accuse()
		return
	super.on_signal(from_id, is_on)


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active:
		return
	var t: String = in_tone.strip_edges().to_lower()
	if mode == "verdict":
		if t == "dawn" and verdict_bell_id.is_empty() and state in [State.IDLE, State.EXPOSED]:
			accuse()
		return
	# Watcher mode: Dusk freezes exact state (keeps linked walls locked as-is!); War cracks glass
	if t == "dusk":
		state = State.FROZEN
		_freeze_left = freeze_secs
		_flare_t = 0.28
		_emit_sfx(_pick_sfx("portrait_blink", "crystal_clank"))
		queue_redraw()
	elif t == "war":
		state = State.CRACKED
		_crack_left = 3.0
		_flare_t = 0.35
		_emit_sfx("stone_break")
		_set_watch_power(false)
		queue_redraw()


func accuse() -> bool:
	if mode != "verdict" or state == State.ACCUSED_RIGHT:
		return false
	if is_culprit:
		state = State.ACCUSED_RIGHT
		_flare_t = 0.55
		z_index = -4
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:manor", "manor_verdict", "right")
		else:
			LxToyDraw.world_set_var("dungeon:manor", "manor_verdict", "right")
		if Lx.state != null:
			Lx.state.story_flags["manor_verdict_right"] = true
		set_powered(true)
		_notify_linked_targets(true)
		if not open_door_id.is_empty() and region != null and region.has_method("find_interactable"):
			var door: Variant = region.call("find_interactable", open_door_id)
			if door is LxInteractable:
				(door as LxInteractable).on_signal(id, true)
		_emit_sfx("door_open")
		if Lx.events != null and LxStrings.has_id("ISL1_VERDICT_OK"):
			Lx.events.narration_requested.emit("ISL1_VERDICT_OK", "title", 3.2)
		if region != null and region.has_method("notify"):
			region.call("notify", "verdict_right", {"id": id, "suspect": suspect})
	else:
		state = State.ACCUSED_WRONG
		_flare_t = 0.65
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:manor", "manor_verdict", "wrong")
		else:
			LxToyDraw.world_set_var("dungeon:manor", "manor_verdict", "wrong")
		if Lx.state != null:
			Lx.state.story_flags["manor_verdict_wrong"] = true
		_emit_sfx("bell_slam")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.24)
			if LxStrings.has_id("ISL1_VERDICT_BAD"):
				Lx.events.narration_requested.emit("ISL1_VERDICT_BAD", "title", 3.2)
		if region != null and region.has_method("notify"):
			region.call("notify", "verdict_wrong", {"id": id, "suspect": suspect})
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	var dirty: bool = false
	if _flare_t > 0.0:
		_flare_t = maxf(0.0, _flare_t - dt)
		dirty = true
	if mode == "verdict":
		_sync_clue_state()
		_glance_t += dt
		var prev_off: Vector2 = _eye_offset
		_eye_offset = _compute_verdict_eye_offset()
		if _eye_offset != prev_off:
			dirty = true
	else:
		dirty = _tick_watcher(dt) or dirty
	if dirty:
		queue_redraw()


func _tick_watcher(dt: float) -> bool:
	if state == State.FROZEN:
		_freeze_left -= dt
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			state = State.WATCHING
		return true
	if state == State.CRACKED:
		_crack_left -= dt
		if _crack_left <= 0.0:
			_crack_left = 0.0
			state = State.WATCHING
		return true
	_sweep_phase += sweep_speed * dt
	var base_a: float = watch_dir.angle()
	var sweep_a: float = base_a + sin(_sweep_phase) * sweep_rad
	current_look = Vector2.from_angle(sweep_a)
	var seen_res: Dictionary = _sample_watch_cone()
	var saw: bool = bool(seen_res.get("seen", false))
	var alert: String = str(seen_res.get("alert", "calm"))
	if saw:
		var tpos: Vector2 = seen_res.get("pos", pos + current_look * 32.0) as Vector2
		if tpos.distance_to(pos) > 1.0:
			_eye_offset = ((tpos - pos).normalized() * 2.0).round()
		if state != State.ALERTED:
			state = State.ALERTED
			_emit_sfx(_pick_sfx("portrait_blink", "switch_eye"))
		_set_watch_power(true)
		if LxIsland1Rule.active_instance != null:
			LxIsland1Rule.active_instance.report_stealth_alert(alert, pos)
	else:
		_eye_offset = (current_look * 1.5).round()
		if state == State.ALERTED:
			state = State.WATCHING
		_set_watch_power(false)
	_last_alert_kind = alert
	return true


func _set_watch_power(on_now: bool) -> void:
	if powered != on_now:
		set_powered(on_now)
		_notify_linked_targets(on_now)


func _sample_watch_cone() -> Dictionary:
	if LxIsland1Rule.active_instance != null:
		return LxIsland1Rule.active_instance.can_cone_see_light(pos, current_look, cone_half_rad, cone_range, region, self)
	var wp: Vector2 = wick_pos()
	var rel: Vector2 = wp - pos
	if rel.length() <= cone_range and (rel.length() <= 2.0 or rel.normalized().dot(current_look) >= cos(cone_half_rad)):
		return {"seen": true, "target": "wick", "pos": wp, "alert": "spotted"}
	return {"seen": false, "target": "none", "pos": Vector2.ZERO, "alert": "calm"}


func _sync_clue_state() -> void:
	if mode != "verdict" or clue_flag.is_empty() or state != State.IDLE:
		return
	if LxRegionLoader.check_flag_static(clue_flag):
		state = State.EXPOSED
		queue_redraw()


func _compute_verdict_eye_offset() -> Vector2:
	# Slyly glance at `points_to` every 3.4 s; otherwise track Wick
	if fmod(_glance_t, 3.4) > 2.4:
		var p_dir: Vector2 = _resolve_points_to_dir()
		if p_dir.length_squared() > 0.01:
			return Vector2(clampf(roundf(p_dir.x * 2.0), -2.0, 2.0), clampf(roundf(p_dir.y), -1.0, 1.0))
	var wp: Vector2 = wick_pos()
	if wp.x > -9000.0:
		var d: Vector2 = (wp - pos).normalized()
		return Vector2(clampf(roundf(d.x * 2.0), -2.0, 2.0), clampf(roundf(d.y), -1.0, 1.0))
	return Vector2.ZERO


func _resolve_points_to_dir() -> Vector2:
	if points_to is String and not str(points_to).is_empty() and region != null and region.has_method("find_interactable"):
		var tgt: Variant = region.call("find_interactable", str(points_to))
		if tgt is LxInteractable:
			return ((tgt as LxInteractable).pos - pos).normalized()
	if points_to is Array and (points_to as Array).size() >= 2:
		return Vector2(float((points_to as Array)[0]), float((points_to as Array)[1])).normalized()
	return Vector2.RIGHT if suspect == "butler" else (Vector2.LEFT if suspect == "steward" else Vector2.RIGHT)


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.ALERTED or state == State.EXPOSED or state == State.ACCUSED_RIGHT:
		return Vector4(pos.x, pos.y, 40.0, 0.65)
	return Vector4(pos.x, pos.y, 24.0, 0.28)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["state"] = state
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("state"):
		state = int(d.get("state", state))
		z_index = -4 if state == State.ACCUSED_RIGHT else 0
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var r := Rect2((-size * 0.5).round(), size.round())

	# Watcher vision cone on floor
	if mode == "watcher" and state not in [State.FROZEN, State.CRACKED]:
		var cone_c: Color = c_coral if state == State.ALERTED else (PAL["gold"] as Color if _last_alert_kind == "lured" else PAL["sky"] as Color)
		var a0: float = current_look.angle() - cone_half_rad
		var a1: float = current_look.angle() + cone_half_rad
		var pts := PackedVector2Array([Vector2.ZERO])
		for i: int in range(9):
			var a: float = lerpf(a0, a1, float(i) / 8.0)
			pts.append((Vector2.from_angle(a) * cone_range).round())
		draw_colored_polygon(pts, Color(cone_c, 0.16 if state == State.ALERTED else 0.09))
		draw_line(Vector2.ZERO, pts[1], Color(cone_c, 0.45), 1.0)
		draw_line(Vector2.ZERO, pts[pts.size() - 1], Color(cone_c, 0.45), 1.0)

	# Swung-open doorway on ACCUSED_RIGHT
	if state == State.ACCUSED_RIGHT:
		LxToyDraw.draw_bevel_box(self, Rect2(r.position.x, r.position.y, 5.0, r.size.y), PAL["wine"] as Color, PAL["apricot"] as Color, c_gold, c_void)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_gold)
		_draw_signal_pulses()
		return

	# Gilt frame
	var frame_mid: Color = PAL["sky"] as Color if state == State.FROZEN else (c_coral if state in [State.ACCUSED_WRONG, State.ALERTED] else PAL["apricot"] as Color)
	var frame_hi: Color = c_ice if state == State.FROZEN else (c_cream if _flare_t > 0.0 else c_gold)
	LxToyDraw.draw_bevel_box(self, r, PAL["wine"] as Color, frame_mid, frame_hi, c_void)
	# Velvet canvas interior
	var inner := Rect2(r.position + Vector2(3.0, 3.0), r.size - Vector2(6.0, 6.0))
	draw_rect(inner, c_night)
	var coat_c: Color = c_coral if suspect == "steward" else (PAL["sky"] as Color if suspect == "choir" else PAL["plum"] as Color)
	draw_rect(Rect2(-5.0, 2.0, 10.0, 7.0), coat_c)
	# Head silhouette
	draw_rect(Rect2(-4.0, -6.0, 8.0, 8.0), PAL["dusk"] as Color)

	# Eyes (closed when frozen/cracked, bright open when alert/verdict)
	if state == State.FROZEN:
		draw_rect(Rect2(-3.0, -3.0, 6.0, 1.0), c_ice)
		draw_rect(r.grow(1.0), c_ice, false, 1.0)
		LxToyDraw.draw_bar(self, Vector2(-7.0, r.position.y - 5.0), 14.0, _freeze_left / maxf(0.1, freeze_secs), c_ice)
	elif state == State.CRACKED:
		draw_line(inner.position, inner.end, c_coral, 1.0)
		draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), c_stone_col(), 1.0)
		LxToyDraw.draw_bar(self, Vector2(-7.0, r.position.y - 5.0), 14.0, _crack_left / 3.0, c_coral)
	else:
		var eye_c: Color = c_coral if state in [State.ALERTED, State.ACCUSED_WRONG] else c_cream
		draw_rect(Rect2(-3.0 + _eye_offset.x * 0.5, -4.0 + _eye_offset.y * 0.5, 2.0, 2.0), eye_c)
		draw_rect(Rect2(1.0 + _eye_offset.x * 0.5, -4.0 + _eye_offset.y * 0.5, 2.0, 2.0), eye_c)

	# Evidence lectern pip beneath portrait when EXPOSED
	if state == State.EXPOSED:
		draw_rect(Rect2(-5.0, r.end.y + 1.0, 10.0, 4.0), c_void)
		draw_rect(Rect2(-4.0, r.end.y + 2.0, 8.0, 2.0), c_coral if is_culprit else c_gold)
		draw_rect(Rect2(-1.0, r.end.y + 2.0, 2.0, 2.0), c_cream)
	_draw_signal_pulses()


func c_stone_col() -> Color:
	return PAL["stone"] as Color
