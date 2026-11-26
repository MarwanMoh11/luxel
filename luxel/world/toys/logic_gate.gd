class_name LxLogicGate
extends LxToy
## Combinational & sequential signal gate connecting puzzle toys to doors, bridges, or scripts.
## Props: op ("all"|"any"|"xor"|"seq"|"count"), n (int, for count), inputs (Array[String]),
## invert (bool), persist (bool), target_id/target_ids.

var op: String = "all"
var need_n: int = 2
var inputs: Array[String] = []
var invert: bool = false

var _states: Dictionary = {}
var _seq_idx: int = 0
var _error_t: float = 0.0


func _toy_setup() -> void:
	kind = "logic_gate"
	z_index = -5
	op = str(props.get("op", "all")).strip_edges().to_lower()
	if op not in ["all", "any", "xor", "seq", "count"]:
		op = "all"
	need_n = maxi(1, int(props.get("n", 2)))
	invert = bool(props.get("invert", false))
	inputs.clear()
	var raw_in: Variant = props.get("inputs", [])
	if raw_in is Array:
		for item: Variant in (raw_in as Array):
			var sid: String = str(item).strip_edges()
			if not sid.is_empty():
				inputs.append(sid)
	_states.clear()
	for sid: String in inputs:
		_states[sid] = false
	_seq_idx = inputs.size() if powered else 0
	_error_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	for sid: String in _states.keys():
		_states[sid] = false
	_seq_idx = 0
	_error_t = 0.0
	var out_now: bool = _evaluate_output()
	if out_now != powered:
		set_powered(out_now)
		emit_power(out_now)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _error_t > 0.0:
		_error_t = maxf(0.0, _error_t - dt)
		queue_redraw()


func on_signal(from_id: String, is_on: bool) -> void:
	if not active:
		return
	if not inputs.is_empty() and not inputs.has(from_id):
		return
	if op == "seq":
		_handle_seq_signal(from_id, is_on)
		return
	_states[from_id] = is_on
	_sync_output()


func _handle_seq_signal(from_id: String, is_on: bool) -> void:
	if not is_on:
		return
	if inputs.is_empty():
		return
	if _seq_idx >= inputs.size():
		return
	if from_id == inputs[_seq_idx]:
		_states[from_id] = true
		_seq_idx += 1
		_emit_sfx("prop_chime")
		_sync_output()
	else:
		# Out-of-order input resets sequence cleanly
		_seq_idx = 0
		for sid: String in inputs:
			_states[sid] = false
		# A wrong note that happens to be the first of the sequence already starts the next try.
		if from_id == inputs[0]:
			_seq_idx = 1
			_states[from_id] = true
		_error_t = 0.30
		_emit_sfx("denied")
		_sync_output()


func _evaluate_output() -> bool:
	var keys: Array[String] = inputs.duplicate()
	if keys.is_empty():
		for k: Variant in _states.keys():
			keys.append(str(k))
	var on_count: int = 0
	for sid: String in keys:
		if bool(_states.get(sid, false)):
			on_count += 1
	var raw: bool = false
	match op:
		"any":
			raw = on_count >= 1
		"xor":
			raw = (on_count % 2) == 1
		"count":
			raw = on_count >= need_n
		"seq":
			raw = (not inputs.is_empty()) and _seq_idx >= inputs.size()
		_: # "all"
			raw = (not keys.is_empty()) and on_count == keys.size()
	return (not raw) if invert else raw


func _sync_output() -> void:
	var out_now: bool = _evaluate_output()
	if out_now != powered:
		set_powered(out_now)
		emit_power(out_now)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active or not powered:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 28.0, 0.52)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["states"] = _states.duplicate()
		d["seq_idx"] = _seq_idx
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.get("states") is Dictionary:
			_states = (d["states"] as Dictionary).duplicate()
		if d.has("seq_idx"):
			_seq_idx = int(d["seq_idx"])
		if powered:
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
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var reduced: bool = LxHudFx.flash_reduced()
	var is_err: bool = _error_t > 0.0
	var trim_c: Color = c_coral if is_err else (c_gold if powered else c_apricot)
	var hi_c: Color = c_coral if is_err else (c_cream if powered else c_stone)

	# Grounded shadow beneath arcane brass/stone relay pylon
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 9.0, 3.0)

	# Stepped stone plinth with brass corner anchors
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, 2.0, 18.0, 5.0), c_night, c_dusk, c_stone, c_void)
	draw_rect(Rect2(-8.0, 3.0, 2.0, 2.0), trim_c)
	draw_rect(Rect2(6.0, 3.0, 2.0, 2.0), trim_c)

	# Side input conduit lugs (distinguishes pylon from flat square sensors)
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -5.0, 4.0, 6.0), c_night, c_dusk, trim_c, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(6.0, -5.0, 4.0, 6.0), c_night, c_dusk, trim_c, c_void)
	draw_rect(Rect2(-9.0, -3.0, 2.0, 2.0), c_cream if powered else c_mauve)
	draw_rect(Rect2(7.0, -3.0, 2.0, 2.0), c_cream if powered else c_mauve)

	# Main stone/brass relay pylon housing
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -9.0, 14.0, 12.0), c_night, c_dusk, c_stone if not powered else c_gold, c_void)
	# Vertical brass circuit trim rails on left and right edges
	draw_rect(Rect2(-6.0, -8.0, 1.0, 9.0), trim_c)
	draw_rect(Rect2(5.0, -8.0, 1.0, 9.0), trim_c)

	# Top output conduit finial + radiant emitter pip
	LxToyDraw.draw_bevel_box(self, Rect2(-4.0, -13.0, 8.0, 5.0), c_night, c_dusk, trim_c, c_void)
	draw_rect(Rect2(-2.0, -15.0, 4.0, 3.0), c_void)
	draw_rect(Rect2(-1.0, -14.0, 2.0, 2.0), c_cream if powered else (c_coral if invert else c_mauve))
	if invert:
		# Clear NOT-gate inversion ring at output crown
		draw_rect(Rect2(-2.0, -13.0, 4.0, 1.0), c_coral if not powered else c_cream)
	if powered:
		var pulse_ok: bool = reduced or int(floorf(_clock * 5.0)) % 2 == 0
		if pulse_ok:
			draw_arc(Vector2(0.0, -13.0), 4.0, PI, TAU, 10, c_glow, 1.0)

	# Recessed arcane faceplate + radiant powered core
	draw_rect(Rect2(-5.0, -7.0, 10.0, 8.0), c_void)
	draw_rect(Rect2(-4.0, -6.0, 8.0, 6.0), c_dusk if powered else c_night)
	if powered:
		draw_rect(Rect2(-3.0, -5.0, 6.0, 4.0), Color(c_glow, 0.38))

	# Etched gate emblem (AND / OR / XOR / SEQ / COUNT + NOT bubble if inverted)
	var em_c: Color = c_coral if is_err else (c_cream if powered else c_gold)
	_draw_gate_emblem(Vector2(0.0, -3.0), em_c, hi_c)

	# Input conduit pips inlaid across plinth front
	var n_pips: int = mini(5, inputs.size() if not inputs.is_empty() else _states.size())
	if n_pips > 0:
		var span: float = float(n_pips - 1) * 3.0
		for i: int in range(n_pips):
			var sid: String = inputs[i] if i < inputs.size() else str(_states.keys()[i])
			var lit_p: bool = bool(_states.get(sid, false))
			var px: float = roundf(-span * 0.5 + float(i) * 3.0)
			draw_rect(Rect2(px - 1.0, 3.0, 3.0, 3.0), c_void)
			draw_rect(Rect2(px, 4.0, 1.0, 1.0), c_cream if lit_p else (c_glow if powered else c_mauve))
	_draw_signal_pulses()


func _draw_gate_emblem(center: Vector2, col: Color, hi: Color) -> void:
	var cx: float = roundf(center.x)
	var cy: float = roundf(center.y)
	match op:
		"any": # OR: curved crescent shield pointing right
			draw_rect(Rect2(cx - 3.0, cy - 2.0, 3.0, 1.0), col)
			draw_rect(Rect2(cx - 3.0, cy + 2.0, 3.0, 1.0), col)
			draw_rect(Rect2(cx - 2.0, cy - 1.0, 1.0, 3.0), col)
			draw_rect(Rect2(cx, cy - 1.0, 2.0, 1.0), hi)
			draw_rect(Rect2(cx, cy + 1.0, 2.0, 1.0), hi)
			draw_rect(Rect2(cx + 2.0, cy, 1.0, 1.0), hi)
		"xor": # XOR: double arc + pointed tip
			draw_rect(Rect2(cx - 3.0, cy - 2.0, 1.0, 5.0), col)
			draw_rect(Rect2(cx - 1.0, cy - 2.0, 2.0, 1.0), hi)
			draw_rect(Rect2(cx - 1.0, cy + 2.0, 2.0, 1.0), hi)
			draw_rect(Rect2(cx - 1.0, cy - 1.0, 1.0, 3.0), col)
			draw_rect(Rect2(cx + 1.0, cy - 1.0, 1.0, 3.0), hi)
			draw_rect(Rect2(cx + 2.0, cy, 1.0, 1.0), hi)
		"seq": # SEQ: stepped arrow chevron
			draw_rect(Rect2(cx - 3.0, cy, 5.0, 1.0), col)
			draw_rect(Rect2(cx, cy - 2.0, 1.0, 5.0), hi)
			draw_rect(Rect2(cx + 1.0, cy - 1.0, 1.0, 3.0), hi)
			draw_rect(Rect2(cx + 2.0, cy, 1.0, 1.0), hi)
		"count": # COUNT: bold plus tally
			draw_rect(Rect2(cx, cy - 2.0, 1.0, 5.0), hi)
			draw_rect(Rect2(cx - 2.0, cy, 5.0, 1.0), col)
			draw_rect(Rect2(cx, cy, 1.0, 1.0), hi)
		_: # ALL (AND): classic D-shape block
			draw_rect(Rect2(cx - 2.0, cy - 2.0, 1.0, 5.0), col)
			draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 1.0), col)
			draw_rect(Rect2(cx - 2.0, cy + 2.0, 4.0, 1.0), col)
			draw_rect(Rect2(cx + 2.0, cy - 1.0, 1.0, 3.0), hi)
			if powered:
				draw_rect(Rect2(cx - 1.0, cy - 1.0, 3.0, 3.0), hi)
	if invert:
		draw_rect(Rect2(cx + 3.0, cy, 1.0, 1.0), PAL["coral"] as Color if not powered else PAL["cream"] as Color)
