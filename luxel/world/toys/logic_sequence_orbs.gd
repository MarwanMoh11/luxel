class_name LxSequenceOrbs
extends LxToy
## Colour-blind safe sequence puzzle: `count` orbs struck in `order`.
## Every orb has a distinct shape, colour, pip count, and sound cue; plays a gentle preview pulse.
## Wrong hit flashes coral X and resets cleanly (no softlock).
## Props: count (int 2..6), order (Array of ints), spacing (float), positions (optional [[dx,dy]..]), persist, target_id/target_ids.

const ORB_COLORS: Array[String] = ["gold", "sky", "lime", "coral", "rose", "ice"]
const ORB_SFX: Array[String] = ["prop_chime", "mirror_ping", "clockwork_chime", "switch_eye", "prism_bounce", "bell_toll"]
const ORB_RADIUS: float = 9.0

var count: int = 3
var order: Array[int] = [0, 1, 2]
var orb_offsets: Array[Vector2] = []
var progress: int = 0
var solved: bool = false

var _orb_flash: PackedFloat32Array = PackedFloat32Array()
var _error_t: float = 0.0
var _demo_t: float = 0.0
var _demo_idx: int = -1
var _demo_interval: float = 4.2


func _toy_setup() -> void:
	kind = "sequence_orbs"
	count = clampi(int(props.get("count", 3)), 2, 6)
	order.clear()
	var raw_order: Variant = props.get("order", [])
	if raw_order is Array and not (raw_order as Array).is_empty():
		for item: Variant in (raw_order as Array):
			order.append(clampi(int(item), 0, count - 1))
	else:
		for i: int in range(count):
			order.append(i)
	orb_offsets.clear()
	var raw_pos: Variant = props.get("positions", [])
	var spacing: float = maxf(20.0, float(props.get("spacing", 28.0)))
	if raw_pos is Array and (raw_pos as Array).size() >= count:
		for i: int in range(count):
			orb_offsets.append(LxMapFormat.to_vec2((raw_pos as Array)[i], Vector2.ZERO))
	else:
		var span: float = float(count - 1) * spacing
		for i: int in range(count):
			orb_offsets.append(Vector2(-span * 0.5 + float(i) * spacing, 0.0))
	var max_r: float = ORB_RADIUS + 4.0
	for off: Vector2 in orb_offsets:
		max_r = maxf(max_r, off.length() + ORB_RADIUS + 4.0)
	radius = max_r
	_orb_flash.resize(count)
	for i: int in range(count):
		_orb_flash[i] = 0.0
	progress = order.size() if powered else 0
	solved = powered
	_error_t = 0.0
	_demo_t = 1.0
	_demo_idx = -1
	queue_redraw()


func reset_toy() -> void:
	if persist and solved:
		return
	progress = 0
	solved = false
	_error_t = 0.0
	_demo_t = 0.8
	_demo_idx = -1
	for i: int in range(count):
		_orb_flash[i] = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func orb_world_pos(idx: int) -> Vector2:
	if idx < 0 or idx >= orb_offsets.size():
		return pos
	return pos + orb_offsets[idx]


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _error_t > 0.0:
		_error_t = maxf(0.0, _error_t - dt)
		dirty = true
	for i: int in range(count):
		if _orb_flash[i] > 0.0:
			_orb_flash[i] = maxf(0.0, _orb_flash[i] - dt)
			dirty = true
	if active and not solved and progress == 0:
		_demo_t -= dt
		if _demo_t <= 0.0:
			_demo_idx += 1
			if _demo_idx >= order.size():
				_demo_idx = -1
				_demo_t = _demo_interval
			else:
				var o_i: int = order[_demo_idx]
				_orb_flash[o_i] = 0.45
				_demo_t = 0.58 if not LxHudFx.flash_reduced() else 0.75
				dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or solved:
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return false
	var idx: int = _pick_orb_from_hit(hit)
	if idx < 0:
		return false
	return hit_orb(idx)


func interact(_actor: Node = null) -> bool:
	if not active or solved:
		return false
	# Replay preview demo on interact
	_demo_idx = -1
	_demo_t = 0.01
	_emit_sfx("prop_chime")
	return true


func hit_orb(idx: int) -> bool:
	if idx < 0 or idx >= count or solved:
		return false
	_demo_idx = -1
	_demo_t = _demo_interval
	_orb_flash[idx] = 0.40
	var expected: int = order[progress]
	if idx == expected:
		progress += 1
		_emit_sfx(ORB_SFX[idx % ORB_SFX.size()])
		if progress >= order.size():
			solved = true
			set_powered(true)
			emit_power(true)
			_emit_sfx("shrine_claimed")
			_emit_gust(68.0, 44.0)
	else:
		progress = 0
		_error_t = 0.36
		_emit_sfx("denied")
	queue_redraw()
	return true


func _pick_orb_from_hit(hit: LxHit) -> int:
	var best_idx: int = -1
	var best_score: float = INF
	var d_n: Vector2 = hit.dir.normalized() if hit.dir.length_squared() > 0.0001 else Vector2.RIGHT
	for i: int in range(count):
		var op: Vector2 = orb_world_pos(i)
		var rel: Vector2 = op - hit.origin
		var proj: float = rel.dot(d_n)
		if proj >= -ORB_RADIUS:
			var perp: float = (rel - d_n * proj).length()
			if perp <= ORB_RADIUS + 4.0 and proj < best_score:
				best_score = proj
				best_idx = i
	if best_idx >= 0:
		return best_idx
	# Fallback: closest orb directly touching hit.origin
	var best_d: float = ORB_RADIUS + 6.0
	for i: int in range(count):
		var d: float = orb_world_pos(i).distance_to(hit.origin)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx


func get_light_pool() -> Vector4:
	if not active or not solved:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 56.0, 0.85)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["solved"] = solved
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("solved"):
		solved = bool(d["solved"])
		powered = solved
		progress = order.size() if solved else 0
		if solved:
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var reduced: bool = LxHudFx.flash_reduced()

	# Faint floor conduit thread connecting completed steps in order
	var done_steps: int = order.size() if solved else mini(progress, order.size())
	for k: int in range(done_steps - 1):
		var ia: int = order[k]
		var ib: int = order[k + 1]
		if ia >= 0 and ia < orb_offsets.size() and ib >= 0 and ib < orb_offsets.size():
			var pa: Vector2 = orb_offsets[ia].round() + Vector2(0.0, 4.0)
			var pb: Vector2 = orb_offsets[ib].round() + Vector2(0.0, 4.0)
			draw_line(pa, pb, Color(c_void, 0.55), 3.0, false)
			draw_line(pa, pb, c_gold if solved else Color(c_apricot, 0.72), 1.0, false)

	for i: int in range(count):
		var off: Vector2 = orb_offsets[i].round()
		var col_key: String = ORB_COLORS[i % ORB_COLORS.size()]
		var c_main: Color = LxPalette.color(col_key, "gold")
		var is_done: bool = solved or _is_orb_done(i)
		var is_flashing: bool = _orb_flash[i] > 0.0
		var is_lit: bool = is_done or is_flashing
		var is_err: bool = _error_t > 0.0

		# Grounded shadow beneath taller fluted plinth
		LxToyDraw.draw_contact_shadow(self, off + Vector2(1.0, 7.0), 7.0, 2.5)

		# Stepped base & taller fluted stone plinth
		LxToyDraw.draw_bevel_box(self, Rect2(off.x - 6.0, off.y + 2.0, 12.0, 5.0), c_night, c_dusk, c_stone, c_void)
		draw_rect(Rect2(off.x - 5.0, off.y - 4.0, 10.0, 7.0), c_void)
		draw_rect(Rect2(off.x - 4.0, off.y - 3.0, 8.0, 5.0), c_dusk)
		for fx: float in [-3.0, 0.0, 3.0]:
			draw_rect(Rect2(off.x + fx, off.y - 3.0, 1.0, 5.0), c_stone if fx <= 0.0 else c_mauve)
		for gx: float in [-2.0, 1.0]:
			draw_rect(Rect2(off.x + gx, off.y - 3.0, 1.0, 5.0), c_night)
		# Brass/stone cradle cup holding the orb
		draw_rect(Rect2(off.x - 6.0, off.y - 5.0, 12.0, 2.0), c_void)
		draw_rect(Rect2(off.x - 5.0, off.y - 4.0, 10.0, 1.0), c_gold if is_lit else c_apricot)

		# Perched crystal orb (rounded pixel sphere centered at off + (0, -10))
		var orb_c: Vector2 = off + Vector2(0.0, -10.0)
		draw_rect(Rect2(orb_c.x - 4.0, orb_c.y - 6.0, 9.0, 13.0), c_void)
		draw_rect(Rect2(orb_c.x - 6.0, orb_c.y - 4.0, 13.0, 9.0), c_void)
		draw_rect(Rect2(orb_c.x - 5.0, orb_c.y - 5.0, 11.0, 11.0), c_void)

		var glass_fill: Color = c_coral if is_err else (c_main if is_lit else c_dusk)
		var glass_shade: Color = PAL["wine"] as Color if is_err else (c_dusk if is_lit else c_night)
		draw_rect(Rect2(orb_c.x - 4.0, orb_c.y - 5.0, 9.0, 11.0), glass_shade)
		draw_rect(Rect2(orb_c.x - 5.0, orb_c.y - 4.0, 11.0, 9.0), glass_shade)
		draw_rect(Rect2(orb_c.x - 4.0, orb_c.y - 4.0, 9.0, 8.0), glass_fill)
		draw_rect(Rect2(orb_c.x - 3.0, orb_c.y - 5.0, 7.0, 9.0), glass_fill)
		# Dim glass colour-tint rim when unlit + crisp upper-left crystal specular gleam
		if not is_lit and not is_err:
			draw_rect(Rect2(orb_c.x - 3.0, orb_c.y - 5.0, 5.0, 1.0), c_main)
			draw_rect(Rect2(orb_c.x - 4.0, orb_c.y - 4.0, 1.0, 4.0), c_main)
		draw_rect(Rect2(orb_c.x - 3.0, orb_c.y - 4.0, 2.0, 1.0), c_cream if is_lit else c_stone)
		draw_rect(Rect2(orb_c.x - 4.0, orb_c.y - 3.0, 1.0, 1.0), c_cream if is_lit else c_stone)

		# Colour-blind safe geometric shape emblem inside crystal orb
		LxToyDraw.draw_shape_glyph(self, orb_c, i, is_lit, c_main, c_cream if is_lit else c_stone)

		# Framed pip count badge beneath pedestal (1..count)
		var pip_span: float = float(i) * 2.0
		var bx0: float = roundf(off.x - pip_span * 0.5) - 1.0
		draw_rect(Rect2(bx0, off.y + 7.0, pip_span + 3.0, 3.0), c_void)
		for p: int in range(i + 1):
			var px: float = roundf(off.x - pip_span * 0.5 + float(p) * 2.0)
			draw_rect(Rect2(px, off.y + 8.0, 1.0, 1.0), c_cream if is_lit else c_stone)

		if is_flashing:
			var ring_c: Color = c_main if reduced else c_cream
			draw_arc(orb_c, 8.0, 0.0, TAU, 16, ring_c, 1.0)
	_draw_signal_pulses()


func _is_orb_done(orb_idx: int) -> bool:
	for k: int in range(mini(progress, order.size())):
		if order[k] == orb_idx:
			return true
	return false
