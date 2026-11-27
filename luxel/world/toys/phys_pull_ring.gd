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
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var red: bool = LxHudFx.flash_reduced()
	var anchor_rel: Vector2 = (origin_pos - pos).round()
	var pull_a: Vector2 = axis.normalized() if axis.length_squared() > 0.001 else Vector2.RIGHT

	# Riveted stone & brass mounting plate anchored at origin_pos
	var plate := Rect2(anchor_rel - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
	LxPhysDraw.draw_shadow_rect(self, plate, Vector2(1.0, 3.0), 0.38)
	draw_rect(plate, c_void)
	draw_rect(Rect2(plate.position.x + 1.0, plate.end.y - 4.0, 14.0, 3.0), c_night)
	draw_rect(Rect2(plate.position.x + 1.0, plate.position.y + 1.0, 14.0, 11.0), c_dusk)
	draw_rect(Rect2(plate.position.x + 1.0, plate.position.y + 1.0, 14.0, 1.0), c_stone)
	draw_rect(Rect2(plate.position.x + 1.0, plate.position.y + 1.0, 1.0, 11.0), c_mauve)
	# Inset brass escutcheon collar + 4 riveted corners
	draw_rect(Rect2(anchor_rel - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), c_void)
	draw_rect(Rect2(anchor_rel - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), c_wine)
	draw_rect(Rect2(anchor_rel - Vector2(3.0, 3.0), Vector2(5.0, 5.0)), c_apricot)
	draw_rect(Rect2(anchor_rel - Vector2(2.0, 2.0), Vector2(4.0, 1.0)), c_gold)
	for rv: Vector2 in [
		plate.position + Vector2(2.0, 2.0),
		Vector2(plate.end.x - 4.0, plate.position.y + 2.0),
		Vector2(plate.position.x + 2.0, plate.end.y - 5.0),
		Vector2(plate.end.x - 4.0, plate.end.y - 5.0),
	]:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), c_void)
		draw_rect(Rect2(rv, Vector2.ONE), c_gold)

	# Drawn heavy chain links from mounting plate to ring when pulled
	var chain_len: float = anchor_rel.length()
	if chain_len > 1.0:
		draw_line(anchor_rel + Vector2(0.0, 2.0), Vector2(0.0, 2.0), Color(c_void, 0.42), 3.0, false)
		draw_line(anchor_rel, Vector2.ZERO, c_void, 4.0, false)
		draw_line(anchor_rel, Vector2.ZERO, c_dusk, 2.0, false)
		var step: float = 3.0
		var cdir: Vector2 = -anchor_rel / chain_len
		var link_i: int = 0
		while step < chain_len:
			var lp: Vector2 = (anchor_rel + cdir * step).round()
			draw_rect(Rect2(lp - Vector2.ONE, Vector2(2.0, 2.0)), c_apricot if link_i % 2 == 0 else c_stone)
			draw_rect(Rect2(lp - Vector2.ONE, Vector2.ONE), c_gold if link_i % 2 == 0 else c_cream)
			step += 4.0
			link_i += 1

	# Chunky metallic pull-ring anchored onto the brass staple lug
	var ring_off: Vector2 = (pull_a * 3.0).round() if chain_len <= 1.0 else Vector2.ZERO
	var rc: Vector2 = ring_off
	var engaged: bool = _tug_fx_t > 0.0 or _was_triggered
	var ring_body: Color = c_cream if engaged else c_gold
	var ring_sh: Color = c_gold if engaged else c_apricot
	# Grounded ring shadow + chunky dark outline + metallic shaded torus
	draw_arc(rc + Vector2(1.0, 2.0), 5.5, 0.0, TAU, 16, Color(c_void, 0.42), 3.0)
	draw_arc(rc, 5.5, 0.0, TAU, 16, c_void, 5.0)
	draw_arc(rc, 5.5, 0.0, TAU, 16, c_wine, 3.0)
	draw_arc(rc, 5.5, PI * 0.85, PI * 2.15, 14, ring_sh, 2.0)
	draw_arc(rc, 5.5, PI * 1.05, PI * 1.90, 12, ring_body, 1.0)
	# Crisp top-left metallic specular glint on ring
	draw_rect(Rect2(rc + Vector2(-3.0, -6.0), Vector2(4.0, 1.0)), c_cream)
	draw_rect(Rect2(rc + Vector2(-5.0, -4.0), Vector2(1.0, 2.0)), c_cream)
	# Brass staple clasp pinning ring to plate/chain
	var clasp: Vector2 = (rc - pull_a * 5.0).round()
	draw_rect(Rect2(clasp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
	draw_rect(Rect2(clasp - Vector2.ONE, Vector2(2.0, 2.0)), c_gold)
	draw_rect(Rect2(clasp - Vector2.ONE, Vector2.ONE), c_cream)

	# Directional pull ticks indicating pull direction
	if pull_dist < dist * 0.85:
		var hi_idx: int = 0 if red else int(floorf(_clock * 4.0)) % 3
		for ti: int in range(3):
			var tp: Vector2 = (rc + pull_a * (10.0 + float(ti) * 4.0)).round()
			var tc: Color = c_cream if (ti == hi_idx or engaged) else (c_gold if ti == 0 else c_stone)
			LxPhysDraw.draw_chevron(self, tp, pull_a, tc, c_void, 2.2)
	_draw_signal_pulses()
