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
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_hi: Color = (PAL["coral"] as Color) if _error_t > 0.0 else (PAL["cream"] as Color if powered else c_glow)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -7.0, 14.0, 14.0), PAL["night"] as Color, PAL["dusk"] as Color, c_hi if powered else PAL["mauve"] as Color, c_void)

	# Distinct pixel shape per operator (greyscale readable)
	var shape_i: int = 3
	match op:
		"all": shape_i = 3   # Square
		"any": shape_i = 0   # Circle
		"xor": shape_i = 1   # Diamond
		"seq": shape_i = 2   # Triangle
		"count": shape_i = 4 # Plus
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -1.0), shape_i, powered, c_glow if powered else PAL["stone"] as Color, PAL["cream"] as Color if powered else PAL["mauve"] as Color)

	# Input status pips along bottom edge
	var n_pips: int = mini(5, inputs.size() if not inputs.is_empty() else _states.size())
	if n_pips > 0:
		var span: float = float(n_pips - 1) * 3.0
		for i: int in range(n_pips):
			var sid: String = inputs[i] if i < inputs.size() else str(_states.keys()[i])
			var lit_p: bool = bool(_states.get(sid, false))
			var px: float = roundf(-span * 0.5 + float(i) * 3.0)
			draw_rect(Rect2(px, 5.0, 2.0, 1.0), PAL["cream"] as Color if lit_p else PAL["night"] as Color)
	_draw_signal_pulses()
