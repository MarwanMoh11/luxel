class_name LxPhysPullRing
extends LxToy
## Heavy brass pull-ring mounted on a socket track.
## Lantern throw + recall OR zip pulls the ring along `axis` up to `dist`,
## emitting power to `target` / `target_id` / `target_ids`.

var axis: Vector2 = Vector2.RIGHT
var dist: float = 24.0
var latch: bool = false
var retract_speed: float = 12.0
var pull_dist: float = 0.0
var origin_pos: Vector2 = Vector2.ZERO
var _was_triggered: bool = false
var _tug_fx_t: float = 0.0


func _toy_setup() -> void:
	kind = "pull_ring"
	radius = 11.0
	origin_pos = pos
	var raw_axis: Variant = props.get("axis", "e")
	if raw_axis is String:
		var s: String = str(raw_axis).strip_edges().to_lower()
		match s:
			"n": axis = Vector2.UP
			"s": axis = Vector2.DOWN
			"w": axis = Vector2.LEFT
			"e", "x": axis = Vector2.RIGHT
			"y": axis = Vector2.DOWN
			_: axis = Vector2.RIGHT
	else:
		axis = LxMapFormat.to_vec2(raw_axis, Vector2.RIGHT).normalized()
	dist = maxf(8.0, float(props.get("dist", 24.0)))
	latch = bool(props.get("latch", false))
	retract_speed = maxf(2.0, float(props.get("retract_speed", 12.0)))
	# Support CONTRACTS `target` prop seamlessly alongside LxToy `target_id`
	var tgt: String = str(props.get("target", "")).strip_edges()
	if not tgt.is_empty() and str(props.get("target_id", "")).is_empty():
		props["target_id"] = tgt
	pull_dist = 0.0
	_was_triggered = false
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]:
		on_lantern_pull(hit.dir, hit.source)
		return true
	return false


func on_lantern_pull(pull_dir: Vector2, _source: String = "recall") -> void:
	if not active:
		return
	var align: float = pull_dir.normalized().dot(axis) if pull_dir.length_squared() > 0.01 else 1.0
	# Accept aligned pulls (or any recall/zip tug if pulling roughly along axis)
	if align < -0.35:
		return
	var gain: float = dist * (0.65 if _source == "throw" else 1.0)
	pull_dist = clampf(pull_dist + gain, 0.0, dist)
	pos = origin_pos + axis * pull_dist
	position = pos.round()
	_tug_fx_t = 0.25
	_emit_sfx("harbor_creak")
	_sync_trigger_state()
	queue_redraw()


func _sync_trigger_state() -> void:
	var now_on: bool = pull_dist >= dist * 0.85
	if now_on != _was_triggered:
		_was_triggered = now_on
		set_powered(now_on)
		emit_power(now_on)
		if now_on:
			_emit_sfx("door_open")


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _tug_fx_t > 0.0:
		_tug_fx_t = maxf(0.0, _tug_fx_t - dt)
		dirty = true
	if not latch and pull_dist > 0.0 and _tug_fx_t <= 0.0:
		pull_dist = maxf(0.0, pull_dist - retract_speed * dt)
		pos = origin_pos + axis * pull_dist
		position = pos.round()
		_sync_trigger_state()
		dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	return "PROMPT_PULL_RING" if active and not _was_triggered else ""


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pull_dist"] = pull_dist
		d["triggered"] = _was_triggered
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pull_dist"):
		pull_dist = clampf(float(d.get("pull_dist", 0.0)), 0.0, dist)
		pos = origin_pos + axis * pull_dist
		position = pos.round()
		_was_triggered = bool(d.get("triggered", pull_dist >= dist * 0.85))
		powered = _was_triggered
	queue_redraw()


func _draw() -> void:
	var anchor_rel: Vector2 = (origin_pos - pos).round()
	# Wall socket mount plate at origin_pos
	var plate := Rect2(anchor_rel - Vector2(6.0, 6.0), Vector2(12.0, 12.0))
	LxPhysDraw.draw_bevel_box(self, plate, PAL["dusk"] as Color, PAL["stone"] as Color, PAL["night"] as Color, PAL["void"] as Color, biome("hi"))
	# Drawn chain links from anchor to ring
	var chain_len: float = anchor_rel.length()
	if chain_len > 1.0:
		draw_line(anchor_rel + Vector2(0.0, 2.0), Vector2(0.0, 2.0), Color(PAL["void"] as Color, 0.45), 2.0)
		draw_line(anchor_rel, Vector2.ZERO, PAL["mauve"] as Color, 2.0)
		var step: float = 4.0
		var cdir: Vector2 = -anchor_rel / chain_len
		while step < chain_len:
			var lp: Vector2 = (anchor_rel + cdir * step).round()
			draw_rect(Rect2(lp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["stone"] as Color)
			step += 5.0
	# Brass pull ring
	var ring_c: Color = PAL["cream"] as Color if (_tug_fx_t > 0.0 or _was_triggered) else PAL["gold"] as Color
	draw_arc(Vector2(1.0, 2.0), 6.0, 0.0, TAU, 14, Color(PAL["void"] as Color, 0.45), 2.0)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, PAL["void"] as Color, 3.0)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, ring_c, 1.6)
	draw_rect(Rect2(-2.0, -6.0, 3.0, 1.0), PAL["cream"] as Color)
	# Subtle pull direction chevron when retracted
	if pull_dist < dist * 0.25:
		LxPhysDraw.draw_chevron(self, axis * 11.0, axis, biome("glow"), PAL["void"] as Color, 2.5)
	_draw_signal_pulses()
