class_name LxMgSkiffRace
extends LxHubTrialBase
## Skiff Race Time Trial (kind "mg_skiff_race") on Garden Pier lagoon:
## Uses the real LxVehicleSkiff (gun recoil thrust + mooring post zip-swing) to thread
## 8 glowing buoy gates around the lagoon for Bronze / Silver / Gold times.

const DEFAULT_GATES: Array = [
	[248.0, 152.0], [384.0, 128.0], [528.0, 144.0], [576.0, 248.0],
	[480.0, 336.0], [344.0, 344.0], [224.0, 296.0], [184.0, 200.0],
]

var gates: Array[Vector2] = []
var gate_idx: int = 0
var _gate_overlay: Node2D = null
var _skiff_id: String = "hub_race_skiff"


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_skiff_race"
	mg_id = "skiff_race"
	title_key = "HUB_MG_SKIFF"
	lower_is_better = true
	bronze_goal = 48.0
	silver_goal = 34.0
	gold_goal = 24.0
	trial_time_limit = 0.0 # Time trial ends on finishing all gates (or 90s cap)
	_skiff_id = str(props.get("skiff_id", "hub_race_skiff"))
	gates.clear()
	var raw_g: Variant = props.get("gates", DEFAULT_GATES)
	if raw_g is Array:
		for pt: Variant in (raw_g as Array):
			if pt is Array and (pt as Array).size() >= 2:
				gates.append(Vector2(float((pt as Array)[0]), float((pt as Array)[1])))
	if gates.is_empty():
		for pt2: Variant in DEFAULT_GATES:
			gates.append(Vector2(float((pt2 as Array)[0]), float((pt2 as Array)[1])))
	queue_redraw()


func _exit_tree() -> void:
	_clear_overlay()
	super._exit_tree()


func _on_trial_start() -> void:
	gate_idx = 0
	trial_subtext = "1/%d" % gates.size()
	# Recall the skiff cleanly to the starting dock if it drifted far away
	if region != null:
		var sk: LxInteractable = region.find_interactable(_skiff_id)
		if sk != null and sk.has_method("recall_to_dock"):
			var dock_p: Vector2 = sk.get("origin_pos") as Vector2 if sk.get("origin_pos") is Vector2 else sk.pos
			if dock_p.length_squared() > 1.0:
				sk.call("recall_to_dock", dock_p)
	_ensure_overlay()
	if Lx.events != null:
		Lx.events.narration_requested.emit("HUB_SKIFF_GO", "narration", 2.2)


func _on_trial_end() -> void:
	_clear_overlay()


func _on_trial_tick(_dt: float) -> void:
	if trial_elapsed >= 90.0:
		stop_trial(false)
		return
	var w: LxWick = region.get_wick() if region != null else null
	if w != null and gate_idx < gates.size():
		var target: Vector2 = gates[gate_idx]
		if w.global_position.distance_to(target) <= 28.0:
			advance_gate()
	if _gate_overlay != null and is_instance_valid(_gate_overlay):
		_gate_overlay.queue_redraw()


func advance_gate() -> void:
	if not trial_running or gate_idx >= gates.size():
		return
	gate_idx += 1
	_emit_sfx("prop_chime")
	if gate_idx >= gates.size():
		trial_score = maxf(0.1, trial_elapsed)
		stop_trial(true, trial_score)
	else:
		trial_subtext = "%d/%d" % [gate_idx + 1, gates.size()]


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_gate_overlay = Node2D.new()
	_gate_overlay.name = "SkiffRaceGates"
	_gate_overlay.z_index = 4
	_gate_overlay.draw.connect(_draw_gates)
	region.add_child(_gate_overlay)


func _clear_overlay() -> void:
	if _gate_overlay != null and is_instance_valid(_gate_overlay):
		_gate_overlay.queue_free()
	_gate_overlay = null


func _draw_gates() -> void:
	if not trial_running or _gate_overlay == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	for i: int in range(gates.size()):
		var g: Vector2 = gates[i]
		if i < gate_idx:
			_gate_overlay.draw_circle(g, 4.0, LxPalette.PAL["jade"])
		elif i == gate_idx:
			var r: float = 16.0 if fred else 15.0 + roundf(sin(_clock * 7.0) * 2.0)
			_gate_overlay.draw_arc(g, r, 0.0, TAU, 20, LxPalette.PAL["gold"], 2.0)
			_gate_overlay.draw_arc(g, r - 4.0, 0.0, TAU, 16, LxPalette.PAL["cream"], 1.0)
			# Buoy flags left & right
			_gate_overlay.draw_rect(Rect2(g.x - 16.0, g.y - 10.0, 4.0, 10.0), LxPalette.PAL["coral"])
			_gate_overlay.draw_rect(Rect2(g.x + 12.0, g.y - 10.0, 4.0, 10.0), LxPalette.PAL["coral"])
		elif i == gate_idx + 1:
			_gate_overlay.draw_arc(g, 11.0, 0.0, TAU, 12, LxPalette.PAL["sky"], 1.0)
	# Directional pointer around Wick toward active gate
	var w: LxWick = region.get_wick() if region != null else null
	if w != null and gate_idx < gates.size():
		var to_g: Vector2 = gates[gate_idx] - w.global_position
		if to_g.length() > 26.0:
			var d: Vector2 = to_g.normalized()
			var tip: Vector2 = (w.global_position + d * 20.0).round()
			_gate_overlay.draw_rect(Rect2(tip - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), LxPalette.PAL["gold"])
			_gate_overlay.draw_rect(Rect2(tip - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxPalette.PAL["cream"])


func _get_plinth_icon() -> String: return "toy_skiff"
func _get_plinth_accent() -> String: return "sky"
