class_name LxCards
extends Node2D
## Death card (instant retry), Results/Rank card, and Credits roll reading res://luxel/credits.json.

signal intro_finished()
signal retry_requested()
signal title_requested()
signal credits_finished()

enum Mode { NONE, INTRO, DEATH, RESULTS, CREDITS }

const CREDITS_PATH: String = "res://luxel/credits.json"
const INTRO_KEYS: Array[String] = ["INTRO_1", "INTRO_2", "INTRO_3"]
const INTRO_BEAT_SECS: float = 2.0
const CREDITS_SPEED: float = 18.0
const DEATH_PANEL := Rect2(44.0, 36.0, 232.0, 102.0)
const RESULTS_PANEL := Rect2(40.0, 24.0, 240.0, 132.0)

var mode: int = Mode.NONE
var _is_boss_death: bool = false
var _elapsed: float = 0.0
var _stats: Dictionary = {}
var _credit_lines: Array[Dictionary] = [] # {text, color, scale}
var _scroll_y: float = 184.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_intro() -> void:
	mode = Mode.INTRO
	_elapsed = 0.0
	visible = true
	queue_redraw()


func show_death(is_boss: bool = false) -> void:
	mode = Mode.DEATH
	_is_boss_death = is_boss
	_elapsed = 0.0
	visible = true
	queue_redraw()


func show_results(stats: Dictionary = {}) -> void:
	mode = Mode.RESULTS
	_stats = stats.duplicate(true)
	_elapsed = 0.0
	visible = true
	queue_redraw()


func show_credits() -> void:
	mode = Mode.CREDITS
	_elapsed = 0.0
	_scroll_y = 184.0
	_load_credits()
	visible = true
	queue_redraw()


func close() -> void:
	mode = Mode.NONE
	visible = false


func _process(delta: float) -> void:
	if not visible or mode == Mode.NONE:
		return
	_elapsed += delta
	if mode == Mode.INTRO:
		if _elapsed >= INTRO_BEAT_SECS * float(INTRO_KEYS.size()):
			close()
			intro_finished.emit()
			return
	elif mode == Mode.CREDITS:
		_scroll_y -= CREDITS_SPEED * delta
		var total_h: float = float(_credit_lines.size()) * 12.0 + 40.0
		if _scroll_y + total_h < -12.0:
			mode = Mode.NONE
			visible = false
			credits_finished.emit()
			return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or mode == Mode.NONE:
		return
	if _elapsed < 0.25:
		return

	if mode == Mode.INTRO:
		if _is_any_action_press(event):
			close()
			intro_finished.emit()
			get_viewport().set_input_as_handled()
		return

	if mode == Mode.DEATH:
		if event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
			close()
			title_requested.emit()
			get_viewport().set_input_as_handled()
			return
		var any_press: bool = _is_any_action_press(event)
		if any_press:
			close()
			retry_requested.emit()
			get_viewport().set_input_as_handled()
			return

	elif mode == Mode.RESULTS:
		if event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
			close()
			title_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
			show_credits()
			get_viewport().set_input_as_handled()

	elif mode == Mode.CREDITS:
		if event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ESCAPE) or _key_just(event, KEY_SPACE):
			close()
			credits_finished.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	match mode:
		Mode.INTRO:
			_draw_intro()
		Mode.DEATH:
			_draw_death()
		Mode.RESULTS:
			_draw_results()
		Mode.CREDITS:
			_draw_credits()


func _draw_intro() -> void:
	draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	var idx: int = clampi(int(_elapsed / INTRO_BEAT_SECS), 0, INTRO_KEYS.size() - 1)
	var local_t: float = _elapsed - float(idx) * INTRO_BEAT_SECS
	var p: float = minf(local_t / 0.35, (INTRO_BEAT_SECS - local_t) / 0.35)
	LxPixelFont.draw_faded(
		self,
		LxStrings.text(INTRO_KEYS[idx]),
		Vector2(160.0, 86.0),
		p,
		"cream" if idx < 2 else "gold",
		1,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	LxPixelFont.draw_right(self, LxStrings.text("INTRO_SKIP"), 312.0, 168.0, LxPalette.PAL["mauve"], 1)


func _draw_death() -> void:
	LxPixelFont.draw_panel(self, DEATH_PANEL, "dusk", "coral", "night")
	var p: float = clampf(_elapsed / 0.3, 0.0, 1.0)
	LxPixelFont.draw_faded(self, LxStrings.text("DEATH_TITLE"), Vector2(160.0, 48.0), p, "coral", 2, HORIZONTAL_ALIGNMENT_CENTER)
	var sub_key: String = "DEATH_BOSS_SUB" if _is_boss_death else "DEATH_SUB"
	LxPixelFont.draw_faded(self, LxStrings.text(sub_key), Vector2(160.0, 68.0), p, "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)

	var play_s: float = Lx.state.play_time_s if Lx.state != null else 0.0
	var deaths: int = Lx.state.deaths if Lx.state != null else 0
	var shards: int = Lx.state.shards if Lx.state != null else 0
	var stats_line: String = LxStrings.fmt("DEATH_STATS_FMT", [LxStrings.format_time(play_s), deaths, shards])
	LxPixelFont.draw_centered(self, stats_line, 160.0, 86.0, LxPalette.PAL["stone"], 1)

	var pulse: Color = LxPalette.PAL["gold"] if fmod(_elapsed, 1.2) < 0.6 else LxPalette.PAL["apricot"]
	LxPixelFont.draw_centered(self, LxStrings.text("DEATH_RETRY_HINT"), 160.0, 108.0, pulse, 1)
	LxPixelFont.draw_centered(self, LxStrings.text("DEATH_TITLE_HINT"), 160.0, 122.0, LxPalette.PAL["mauve"], 1)


func _draw_results() -> void:
	LxPixelFont.draw_panel(self, RESULTS_PANEL, "dusk", "gold", "night")
	var p: float = clampf(_elapsed / 0.35, 0.0, 1.0)
	LxPixelFont.draw_faded(self, LxStrings.text("RESULTS_TITLE"), Vector2(160.0, 34.0), p, "gold", 2, HORIZONTAL_ALIGNMENT_CENTER)

	var play_s: float = float(_stats.get("play_time_s", Lx.state.play_time_s if Lx.state != null else 0.0))
	var deaths: int = int(_stats.get("deaths", Lx.state.deaths if Lx.state != null else 0))
	var embers: int = int(_stats.get("ember_pieces", Lx.state.ember_pieces if Lx.state != null else 0))
	var relit: int = int(_stats.get("relit_count", Lx.state.relit_islands.size() if Lx.state != null else 0))
	var rank_key: String = _compute_rank_key(deaths, relit)

	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_RANK_FMT", [LxStrings.text(rank_key)]), 160.0, 56.0, LxPalette.PAL["lime"], 2)
	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_TIME_FMT", [LxStrings.format_time(play_s)]), 160.0, 78.0, LxPalette.PAL["cream"], 1)
	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_DEATHS_FMT", [deaths]), 160.0, 90.0, LxPalette.PAL["cream"], 1)
	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_EMBERS_FMT", [embers]), 160.0, 102.0, LxPalette.PAL["apricot"], 1)
	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_ISLANDS_FMT", [relit]), 160.0, 114.0, LxPalette.PAL["gold"], 1)
	LxPixelFont.draw_centered(self, LxStrings.text("RESULTS_HINT"), 160.0, 140.0, LxPalette.PAL["stone"], 1)


func _draw_credits() -> void:
	draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])
	var y: float = roundf(_scroll_y)
	for entry: Dictionary in _credit_lines:
		var line: String = str(entry["text"])
		var sc: int = int(entry["scale"])
		if y >= -16.0 and y <= 184.0 and not line.is_empty():
			LxPixelFont.draw_centered(self, line, 160.0, y, LxPalette.color(str(entry["color"])), sc)
		y += 12.0 * float(sc)
	LxPixelFont.draw_right(self, LxStrings.text("CREDITS_SKIP"), 312.0, 168.0, LxPalette.PAL["mauve"], 1)


func _load_credits() -> void:
	_credit_lines.clear()
	_credit_lines.append({"text": LxStrings.text("CREDITS_TITLE"), "color": "gold", "scale": 2})
	_credit_lines.append({"text": "", "color": "cream", "scale": 1})

	var loaded: bool = false
	if FileAccess.file_exists(CREDITS_PATH):
		var raw: String = FileAccess.get_file_as_string(CREDITS_PATH)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			loaded = _parse_credits_dict(parsed as Dictionary)
		elif parsed is Array:
			loaded = _parse_credits_array(parsed as Array)

	if not loaded:
		_credit_lines.append({"text": LxStrings.text("CREDITS_DEFAULT_1"), "color": "cream", "scale": 1})
		_credit_lines.append({"text": LxStrings.text("CREDITS_DEFAULT_2"), "color": "stone", "scale": 1})
		_credit_lines.append({"text": LxStrings.text("CREDITS_DEFAULT_3"), "color": "apricot", "scale": 1})

	_credit_lines.append({"text": "", "color": "cream", "scale": 1})
	_credit_lines.append({"text": LxStrings.text("CREDITS_END"), "color": "gold", "scale": 1})


func _parse_credits_dict(d: Dictionary) -> bool:
	var added: bool = false
	for list_key: String in ["sections", "entries", "audio", "third_party", "credits"]:
		if d.has(list_key) and d[list_key] is Array:
			if _parse_credits_array(d[list_key] as Array):
				added = true
	if not added:
		for k: Variant in d.keys():
			var ks: String = LxStrings.sanitize(str(k))
			var vs: String = LxStrings.sanitize(str(d[k]))
			if not ks.is_empty() and not vs.is_empty():
				_credit_lines.append({"text": LxStrings.fmt("FMT_PAIR", [ks, vs]).substr(0, LxStrings.MAX_LEN), "color": "cream", "scale": 1})
				added = true
	return added


func _parse_credits_array(arr: Array) -> bool:
	var added: bool = false
	for item: Variant in arr:
		if item is String:
			var s: String = LxStrings.sanitize(item as String)
			if not s.is_empty():
				_credit_lines.append({"text": s, "color": "cream", "scale": 1})
				added = true
		elif item is Dictionary:
			var md: Dictionary = item as Dictionary
			var title: String = LxStrings.sanitize(str(md.get("title", md.get("role", md.get("file", "")))))
			var name_s: String = LxStrings.sanitize(str(md.get("name", md.get("author", md.get("source", "")))))
			var lic: String = LxStrings.sanitize(str(md.get("license", "")))
			if not title.is_empty():
				_credit_lines.append({"text": title, "color": "gold", "scale": 1})
				added = true
			if not name_s.is_empty():
				var sub: String = name_s if lic.is_empty() else LxStrings.sanitize(LxStrings.fmt("FMT_DASH_PAIR", [name_s, lic]))
				_credit_lines.append({"text": sub, "color": "cream", "scale": 1})
				added = true
			var lines: Variant = md.get("lines", [])
			if lines is Array:
				for ln: Variant in (lines as Array):
					var sl: String = LxStrings.sanitize(str(ln))
					if not sl.is_empty():
						_credit_lines.append({"text": sl, "color": "stone", "scale": 1})
						added = true
	return added


func _compute_rank_key(deaths: int, relit: int) -> String:
	if deaths == 0 and relit >= 8:
		return "RANK_S"
	if deaths <= 3:
		return "RANK_A"
	if deaths <= 8:
		return "RANK_B"
	return "RANK_C"


static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc


static func _is_any_action_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false
