class_name LxMgBellChoir
extends LxHubTrialBase
## Bell Choir Minigame (kind "mg_bell_choir") on the Roof Observatory:
## Rings 3 real LxBell toys (dawn / dusk / war) in 5 escalating melodic waves.
## Watch and listen to the ring-wave pattern, then strike the bells in exact order!

const WAVE_PATTERNS: Array = [
	[0, 1, 2],
	[2, 0, 1, 0],
	[0, 2, 1, 2, 0],
	[1, 0, 2, 1, 0, 2],
	[2, 1, 0, 2, 0, 1, 2],
]

var bell_ids: PackedStringArray = PackedStringArray(["choir_bell_dawn", "choir_bell_dusk", "choir_bell_war"])
var wave_idx: int = 0
var mistakes: int = 0
var _phase: String = "idle" # "show", "play", "pause"
var _step_idx: int = 0
var _show_t: float = 0.0
var _last_counts: Array[int] = [0, 0, 0]
var _choir_overlay: Node2D = null
var _highlight_bell: int = -1
var _highlight_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_bell_choir"
	mg_id = "bell_choir"
	title_key = "HUB_MG_CHOIR"
	lower_is_better = false
	bronze_goal = 2.0 # 2 waves cleared
	silver_goal = 4.0 # 4 waves cleared
	gold_goal = 5.0   # all 5 waves cleared
	trial_time_limit = 0.0
	var raw_b: Variant = props.get("bells", [])
	if raw_b is Array and (raw_b as Array).size() >= 3:
		bell_ids = PackedStringArray([str((raw_b as Array)[0]), str((raw_b as Array)[1]), str((raw_b as Array)[2])])
	queue_redraw()


func _exit_tree() -> void:
	_clear_overlay()
	super._exit_tree()


func _on_trial_start() -> void:
	wave_idx = 0
	mistakes = 0
	trial_score = 0.0
	_snapshot_bell_counts()
	_ensure_overlay()
	_begin_wave_show()


func _on_trial_end() -> void:
	_phase = "idle"
	_highlight_bell = -1
	_clear_overlay()


func _begin_wave_show() -> void:
	_phase = "show"
	_step_idx = 0
	_show_t = 0.55
	_highlight_bell = -1
	trial_subtext = "WATCH W%d" % (wave_idx + 1)


func _on_trial_tick(dt: float) -> void:
	if _highlight_t > 0.0:
		_highlight_t = maxf(0.0, _highlight_t - dt)
		if _highlight_t <= 0.0:
			_highlight_bell = -1
	if _phase == "show":
		_show_t -= dt
		if _show_t <= 0.0:
			var pat: Array = WAVE_PATTERNS[wave_idx] as Array
			if _step_idx < pat.size():
				var bi: int = int(pat[_step_idx])
				_demo_ring_bell(bi)
				_step_idx += 1
				_show_t = 0.72
			else:
				_phase = "play"
				_step_idx = 0
				_snapshot_bell_counts()
				trial_subtext = "RING W%d" % (wave_idx + 1)
	elif _phase == "play":
		_poll_player_rings()
	elif _phase == "pause":
		_show_t -= dt
		if _show_t <= 0.0:
			_begin_wave_show()
	if _choir_overlay != null and is_instance_valid(_choir_overlay):
		_choir_overlay.queue_redraw()


func _demo_ring_bell(bi: int) -> void:
	_highlight_bell = bi
	_highlight_t = 0.52
	var b: LxInteractable = _get_bell(bi)
	if b != null and b.has_method("ring"):
		b.call("ring", false)
		_snapshot_bell_counts()
	else:
		_emit_sfx("prop_chime")


func _poll_player_rings() -> void:
	for bi: int in range(3):
		var b: LxInteractable = _get_bell(bi)
		if b == null:
			continue
		var c: int = int(b.get("ring_count"))
		if c > _last_counts[bi]:
			_last_counts[bi] = c
			submit_note(bi)
			return


func submit_note(bi: int) -> bool:
	if not trial_running or _phase != "play":
		return false
	var pat: Array = WAVE_PATTERNS[wave_idx] as Array
	var expected: int = int(pat[_step_idx])
	_highlight_bell = bi
	_highlight_t = 0.35
	if bi == expected:
		_step_idx += 1
		if _step_idx >= pat.size():
			wave_idx += 1
			trial_score = float(wave_idx)
			_emit_sfx("shrine_unlock")
			if wave_idx >= WAVE_PATTERNS.size():
				stop_trial(true, trial_score)
			else:
				_phase = "pause"
				_show_t = 1.0
				trial_subtext = "CLEAR W%d" % wave_idx
		return true
	mistakes += 1
	_emit_sfx("denied")
	if mistakes >= 3:
		stop_trial(true, trial_score)
	else:
		_phase = "pause"
		_show_t = 0.9
		trial_subtext = "RETRY W%d" % (wave_idx + 1)
	return false


func _get_bell(bi: int) -> LxInteractable:
	if region == null or bi < 0 or bi >= bell_ids.size():
		return null
	return region.find_interactable(bell_ids[bi])


func _snapshot_bell_counts() -> void:
	for bi: int in range(3):
		var b: LxInteractable = _get_bell(bi)
		_last_counts[bi] = int(b.get("ring_count")) if b != null else 0


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_choir_overlay = Node2D.new()
	_choir_overlay.name = "BellChoirOverlay"
	_choir_overlay.z_index = 4
	_choir_overlay.draw.connect(_draw_choir)
	region.add_child(_choir_overlay)


func _clear_overlay() -> void:
	if _choir_overlay != null and is_instance_valid(_choir_overlay):
		_choir_overlay.queue_free()
	_choir_overlay = null


func _draw_choir() -> void:
	if not trial_running or _choir_overlay == null:
		return
	var tone_cols: Array[Color] = [LxPalette.PAL["gold"], LxPalette.PAL["ice"], LxPalette.PAL["coral"]]
	if _highlight_bell >= 0 and _highlight_bell < 3:
		var b: LxInteractable = _get_bell(_highlight_bell)
		if b != null:
			_choir_overlay.draw_arc(b.pos + Vector2(0.0, -8.0), 18.0, 0.0, TAU, 18, tone_cols[_highlight_bell], 2.0)
	# Draw note progress pips above the plinth
	var pat: Array = WAVE_PATTERNS[mini(wave_idx, WAVE_PATTERNS.size() - 1)] as Array
	for pi: int in range(pat.size()):
		var done: bool = _phase == "play" and pi < _step_idx
		var col: Color = tone_cols[int(pat[pi])] if (done or (_phase == "show" and pi < _step_idx)) else LxPalette.PAL["dusk"]
		_choir_overlay.draw_rect(Rect2(pos.x - float(pat.size() * 4) + float(pi * 8), pos.y - 26.0, 6.0, 4.0), col)


func _get_hud_primary_text() -> String:
	return "WAVE %d/5" % mini(wave_idx + 1, 5)


func _get_plinth_icon() -> String: return "bell"
func _get_plinth_accent() -> String: return "gold"
