class_name LxCards
extends Node2D
## Intro beats, Death card (instant retry), Both Endings (display_off & dawn),
## Results/Rank card, and Credits roll reading res://luxel/credits.json.

signal intro_finished()
signal retry_requested()
signal title_requested()
signal ending_finished()
signal credits_finished()

enum Mode { NONE, INTRO, DEATH, ENDING, RESULTS, CREDITS }

const CREDITS_PATH: String = "res://luxel/credits.json"
const INTRO_KEYS: Array[String] = ["INTRO_1", "INTRO_2", "INTRO_3"]
const INTRO_BEAT_SECS: float = 2.0
const ENDING_DISPLAY_OFF_SECS: float = 7.8
const ENDING_DAWN_SECS: float = 7.6
const CREDITS_SPEED: float = 18.0
const DEATH_PANEL := Rect2(44.0, 36.0, 232.0, 102.0)
const RESULTS_PANEL := Rect2(40.0, 24.0, 240.0, 132.0)
const LANTERN_POS := Vector2(160.0, 96.0)
const EYE_COUNT: int = 24
const MOTE_COUNT: int = 18

const DAWN_ISLANDS: Array[Vector2] = [
	Vector2(28.0, 122.0), Vector2(66.0, 118.0), Vector2(104.0, 124.0), Vector2(142.0, 116.0),
	Vector2(178.0, 120.0), Vector2(216.0, 117.0), Vector2(254.0, 123.0), Vector2(292.0, 118.0),
]

var mode: int = Mode.NONE
var ending_mode: String = "display_off"
var _is_boss_death: bool = false
var _elapsed: float = 0.0
var _stats: Dictionary = {}
var _credit_lines: Array[Dictionary] = [] # {text, color, scale}
var _scroll_y: float = 184.0
var _ending_cue_stage: int = 0
var _intro_cue_stage: int = 0
var _eyes: Array[Dictionary] = [] # {start, heap, dir, blink_off, recoil}
var _motes: Array[Dictionary] = [] # {angle, speed, phase, color}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_intro() -> void:
	mode = Mode.INTRO
	_elapsed = 0.0
	_intro_cue_stage = 0
	visible = true
	queue_redraw()


func show_death(is_boss: bool = false) -> void:
	mode = Mode.DEATH
	_is_boss_death = is_boss
	_elapsed = 0.0
	visible = true
	queue_redraw()


func show_ending(p_mode: String = "display_off") -> void:
	ending_mode = "dawn" if p_mode == "dawn" else "display_off"
	mode = Mode.ENDING
	_elapsed = 0.0
	_ending_cue_stage = 0
	_build_ending_actors()
	visible = true
	queue_redraw()


func show_results(stats: Dictionary = {}) -> void:
	mode = Mode.RESULTS
	_stats = stats.duplicate(true)
	_elapsed = 0.0
	visible = true
	if Lx.audio != null:
		var deaths: int = int(_stats.get("deaths", Lx.state.deaths if Lx.state != null else 0))
		Lx.audio.play_sfx("shrine_unlock" if deaths <= 3 else "waystone_lit", Vector2.ZERO, false, true)
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
		if Lx.audio != null:
			if _intro_cue_stage == 0 and _elapsed >= 0.04:
				_intro_cue_stage = 1
				Lx.audio.play_sfx("intro_toll", Vector2.ZERO, false, true)
			elif _intro_cue_stage == 1 and _elapsed >= 4.0:
				_intro_cue_stage = 2
				Lx.audio.play_sfx("lamp_lit", Vector2.ZERO, false, true)
		if _elapsed >= INTRO_BEAT_SECS * float(INTRO_KEYS.size()):
			close()
			intro_finished.emit()
			return
	elif mode == Mode.ENDING:
		_tick_ending_audio()
		var limit: float = ENDING_DAWN_SECS if ending_mode == "dawn" else ENDING_DISPLAY_OFF_SECS
		if _elapsed >= limit:
			_finish_ending()
			return
	elif mode == Mode.CREDITS:
		var fast_fwd: bool = Input.is_key_pressed(KEY_DOWN) or (InputMap.has_action("lx_move_down") and Input.is_action_pressed("lx_move_down"))
		_scroll_y -= CREDITS_SPEED * (3.2 if fast_fwd else 1.0) * delta
		var total_h: float = 40.0
		for entry: Dictionary in _credit_lines:
			total_h += 12.0 * float(int(entry.get("scale", 1)))
		if _scroll_y + total_h < -12.0:
			mode = Mode.NONE
			visible = false
			credits_finished.emit()
			return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or mode == Mode.NONE:
		return
	var guard_s: float = 0.18 if mode == Mode.DEATH else 0.25
	if _elapsed < guard_s:
		return

	if mode == Mode.INTRO:
		if _is_any_action_press(event):
			if Lx.audio != null:
				Lx.audio.play_sfx("ui_confirm", Vector2.ZERO, false, true)
			close()
			intro_finished.emit()
			get_viewport().set_input_as_handled()
		return

	if mode == Mode.ENDING:
		var lmb_end: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		if _elapsed >= 0.5 and (lmb_end or event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ESCAPE) or _key_just(event, KEY_SPACE) or _key_just(event, KEY_ENTER)):
			_finish_ending()
			get_viewport().set_input_as_handled()
		return

	if mode == Mode.DEATH:
		var rmb_d: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		if rmb_d or event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
			if Lx.audio != null: Lx.audio.play_sfx("ui_back", Vector2.ZERO, false, true)
			close()
			title_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if _is_any_action_press(event):
			if Lx.audio != null: Lx.audio.play_sfx("ui_confirm", Vector2.ZERO, false, true)
			close()
			retry_requested.emit()
			get_viewport().set_input_as_handled()
			return

	elif mode == Mode.RESULTS:
		var lmb_res: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		var rmb_res: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		if rmb_res or event.is_action_pressed("lx_ui_cancel") or _key_just(event, KEY_ESCAPE):
			if Lx.audio != null: Lx.audio.play_sfx("ui_back", Vector2.ZERO, false, true)
			close()
			title_requested.emit()
			get_viewport().set_input_as_handled()
		elif lmb_res or event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
			if Lx.audio != null: Lx.audio.play_sfx("ui_confirm", Vector2.ZERO, false, true)
			ending_finished.emit()
			if mode == Mode.RESULTS: show_credits()
			get_viewport().set_input_as_handled()

	elif mode == Mode.CREDITS:
		var mb_cred: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		if mb_cred or event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ESCAPE) or _key_just(event, KEY_SPACE):
			if Lx.audio != null: Lx.audio.play_sfx("ui_back", Vector2.ZERO, false, true)
			close()
			credits_finished.emit()
			get_viewport().set_input_as_handled()


func _finish_ending() -> void:
	if Lx.ui != null and Lx.ui.has_method("show_results"):
		Lx.ui.call("show_results")
	else:
		show_results()


func _tick_ending_audio() -> void:
	if Lx.audio == null:
		return
	if ending_mode == "display_off":
		if _ending_cue_stage == 0 and _elapsed >= 1.35:
			_ending_cue_stage = 1
			Lx.audio.play_sfx("display_sell", Vector2.ZERO, false, true)
		elif _ending_cue_stage == 1 and _elapsed >= 4.35:
			_ending_cue_stage = 2
			Lx.audio.play_sfx("shard_pickup", Vector2.ZERO, false, true)
		elif _ending_cue_stage == 2 and _elapsed >= 4.90:
			_ending_cue_stage = 3
			Lx.audio.play_sfx("dawn_burst", Vector2.ZERO, false, true)
	else:
		if _ending_cue_stage == 0 and _elapsed >= 1.0:
			_ending_cue_stage = 1
			Lx.audio.play_sfx("dawn_burst", Vector2.ZERO, false, true)
		elif _ending_cue_stage < 9 and _elapsed >= 1.0 + float(_ending_cue_stage) * 0.35:
			_ending_cue_stage += 1
			Lx.audio.play_sfx("shard_pickup", Vector2.ZERO, false, true)


func _draw() -> void:
	match mode:
		Mode.INTRO:
			_draw_intro()
		Mode.DEATH:
			_draw_death()
		Mode.ENDING:
			if ending_mode == "dawn":
				_draw_ending_dawn()
			else:
				_draw_ending_display_off()
		Mode.RESULTS:
			_draw_results()
		Mode.CREDITS:
			_draw_credits()


func _draw_intro() -> void:
	LxEndingArt.draw_intro_backdrop(self, _elapsed)
	var idx: int = clampi(int(_elapsed / INTRO_BEAT_SECS), 0, INTRO_KEYS.size() - 1)
	var local_t: float = _elapsed - float(idx) * INTRO_BEAT_SECS
	var p: float = minf(local_t / 0.35, (INTRO_BEAT_SECS - local_t) / 0.35)
	var col_name: String = "cream" if idx < 2 else "gold"
	LxPixelFont.draw_faded(self, LxStrings.text(INTRO_KEYS[idx]), Vector2(160.0, 86.0), p, col_name, 1, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_right(self, LxStrings.text("INTRO_SKIP"), 312.0, 168.0, LxPalette.PAL["mauve"], 1)


func _draw_death() -> void:
	LxEndingArt.draw_death_vignette(self, DEATH_PANEL)
	LxPixelFont.draw_panel(self, DEATH_PANEL, "dusk", "coral", "night")
	LxEndingArt.draw_death_ornaments(self, DEATH_PANEL, _elapsed)
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
	var retry_txt: String = LxStrings.text("DEATH_RETRY_HINT")
	var rw: float = float(LxPixelFont.width(retry_txt, 1))
	draw_rect(Rect2(roundf(160.0 - rw * 0.5 - 6.0), 109.0, 2.0, 2.0), pulse)
	draw_rect(Rect2(roundf(160.0 + rw * 0.5 + 4.0), 109.0, 2.0, 2.0), pulse)
	LxPixelFont.draw_centered(self, retry_txt, 160.0, 108.0, pulse, 1)
	LxPixelFont.draw_centered(self, LxStrings.text("DEATH_TITLE_HINT"), 160.0, 122.0, LxPalette.PAL["mauve"], 1)


func _draw_ending_display_off() -> void:
	var t: float = _elapsed
	draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), LxPalette.PAL["void"])

	# Stage 1 (0.0 - 1.4): THE LANTERN ASKS / SELL LOOK - SOUND - PIXELS
	if t < 1.4:
		var p1: float = _window_fade(t, 0.0, 1.4, 0.25)
		_draw_lantern_core(LANTERN_POS, 2 if t < 1.0 else 1)
		LxPixelFont.draw_faded(self, LxStrings.text("END_ASK_TITLE"), Vector2(160.0, 42.0), p1, "gold", 2, HORIZONTAL_ALIGNMENT_CENTER)
		var p_sell: float = _window_fade(t, 0.25, 1.4, 0.22)
		LxPixelFont.draw_faded(self, LxStrings.text("END_ASK_SELL"), Vector2(160.0, 144.0), p_sell, "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)

	# Stage 2 (1.4 - 2.6): DISPLAY: OFF
	if t >= 1.35 and t < 2.65:
		var p_off: float = _window_fade(t, 1.35, 2.65, 0.25)
		LxPixelFont.draw_faded(self, LxStrings.text("END_DISPLAY_OFF"), Vector2(160.0, 38.0), p_off, "ice", 2, HORIZONTAL_ALIGNMENT_CENTER)

	# Dimming lantern before dark smothers it (1.4 - 3.3)
	if t >= 1.4 and t < 3.3:
		var tier: int = 2 if t < 2.4 else (1 if t < 2.95 else 0)
		_draw_lantern_core(LANTERN_POS, tier)

	# Stage 3 (1.9 - 5.3): Eyes creeping in void -> smother -> startled -> popped by burst
	if t >= 1.9 and t < 5.35:
		_draw_void_eyes(t)

	if t >= 3.0 and t < 4.25:
		var p_ate: float = _window_fade(t, 3.0, 4.25, 0.25)
		LxPixelFont.draw_faded(self, LxStrings.text("END_DARK_ATE"), Vector2(160.0, 148.0), p_ate, "mauve", 1, HORIZONTAL_ALIGNMENT_CENTER)

	# Stage 4 (4.35 - 4.9): Single gold pixel in the void, then rekindling
	if t >= 4.35 and t < 4.95:
		var px_col: Color = LxPalette.PAL["cream"] if t >= 4.75 else LxPalette.PAL["gold"]
		var sz: float = 1.0 if t < 4.68 else 3.0
		var half: float = floorf(sz * 0.5)
		draw_rect(Rect2(LANTERN_POS.x - half, LANTERN_POS.y - half, sz, sz), px_col)

	# Stage 5 (4.9 - 5.7): Burst ring sweeping past the screen corners
	if t >= 4.9:
		_draw_burst_and_motes(t)

	# Stage 6 & 7: THE LANTERN KEPT EVERYTHING YOU SOLD. -> IT WAS TOO MUCH LIGHT FOR THE DARK.
	if t >= 5.35 and t < 6.45:
		var p_kept: float = _window_fade(t, 5.35, 6.45, 0.22)
		LxPixelFont.draw_faded(self, LxStrings.text("END_KEPT_ALL"), Vector2(160.0, 148.0), p_kept, "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)
	elif t >= 6.45 and t < 7.65:
		var p_much: float = _window_fade(t, 6.45, 7.65, 0.22)
		LxPixelFont.draw_faded(self, LxStrings.text("END_TOO_MUCH"), Vector2(160.0, 148.0), p_much, "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)

	# Stage 8 (6.75 - 7.8): DISPLAY: ON
	if t >= 6.75:
		var p_on: float = _window_fade(t, 6.75, ENDING_DISPLAY_OFF_SECS, 0.25)
		LxPixelFont.draw_faded(self, LxStrings.text("END_DISPLAY_ON"), Vector2(160.0, 38.0), p_on, "gold", 2, HORIZONTAL_ALIGNMENT_CENTER)

	# Cinematic 16 px void letterbox bars
	draw_rect(Rect2(0.0, 0.0, 320.0, 16.0), LxPalette.PAL["void"])
	draw_rect(Rect2(0.0, 164.0, 320.0, 16.0), LxPalette.PAL["void"])
	if t >= 0.5:
		LxPixelFont.draw_right(self, LxStrings.text("INTRO_SKIP"), 312.0, 168.0, LxPalette.PAL["mauve"], 1)


func _draw_ending_dawn() -> void:
	var t: float = _elapsed
	LxEndingArt.draw_ending_dawn(self, t, DAWN_ISLANDS, _motes)

	# Dawn lines
	if t >= 1.5:
		var p_title: float = _window_fade(t, 1.5, ENDING_DAWN_SECS, 0.35)
		LxPixelFont.draw_faded(self, LxStrings.text("END_DAWN_TITLE"), Vector2(160.0, 34.0), p_title, "gold", 1, HORIZONTAL_ALIGNMENT_CENTER)
	if t >= 3.6:
		var p_sub: float = _window_fade(t, 3.6, ENDING_DAWN_SECS, 0.35)
		LxPixelFont.draw_faded(self, LxStrings.text("END_DAWN_SUB"), Vector2(160.0, 144.0), p_sub, "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)

	# Cinematic letterbox
	draw_rect(Rect2(0.0, 0.0, 320.0, 16.0), LxPalette.PAL["void"])
	draw_rect(Rect2(0.0, 164.0, 320.0, 16.0), LxPalette.PAL["void"])
	if t >= 0.5:
		LxPixelFont.draw_right(self, LxStrings.text("INTRO_SKIP"), 312.0, 168.0, LxPalette.PAL["mauve"], 1)


func _draw_lantern_core(at: Vector2, tier: int) -> void:
	LxEndingArt.draw_lantern_core(self, at, tier, _elapsed)


func _draw_void_eyes(t: float) -> void:
	var burst_r: float = _burst_radius(t)
	for i: int in range(_eyes.size()):
		var e: Dictionary = _eyes[i]
		var start_p: Vector2 = e["start"] as Vector2
		var heap_p: Vector2 = e["heap"] as Vector2
		var dir: Vector2 = e["dir"] as Vector2
		var creep: float = clampf((t - 1.9) / 1.5, 0.0, 1.0)
		var pos: Vector2 = start_p.lerp(heap_p, creep)
		# Eyes shut between 3.7 and 4.55, then snap open startled on the gold pixel
		var shut_at: float = 3.6 + float(i) * 0.025
		if t >= shut_at and t < 4.55:
			continue
		var col: Color = LxPalette.PAL["ice"]
		if t < 4.55:
			var bl: float = fmod(t + float(e["blink_off"]), 1.8)
			if bl < 0.08:
				continue
			if bl < 0.14:
				col = LxPalette.PAL["blue"]
		else:
			# Startled recoil away from the single gold pixel
			var rec: float = clampf((t - 4.55) / 0.35, 0.0, 1.0) * float(e["recoil"])
			pos += dir * rec
		pos = pos.round()
		var dist: float = pos.distance_to(LANTERN_POS)
		if t >= 4.9 and burst_r >= dist:
			var pop_age: float = (burst_r - dist) / 380.0
			if pop_age < 0.12:
				draw_rect(Rect2(pos - Vector2(1.0, 0.0), Vector2(3.0, 1.0)), LxPalette.PAL["cream"])
				draw_rect(Rect2(pos - Vector2(0.0, 1.0), Vector2(1.0, 3.0)), LxPalette.PAL["cream"])
			continue
		draw_rect(Rect2(pos - Vector2(1.0, 0.0), Vector2(1.0, 1.0)), col)
		draw_rect(Rect2(pos + Vector2(1.0, 0.0), Vector2(1.0, 1.0)), col)


func _draw_burst_and_motes(t: float) -> void:
	var age: float = t - 4.9
	var r: float = _burst_radius(t)
	if age < 0.7:
		draw_arc(LANTERN_POS, r, 0.0, TAU, 36, LxPalette.PAL["cream"], 2.0)
		if r > 4.0:
			draw_arc(LANTERN_POS, r - 3.0, 0.0, TAU, 36, LxPalette.PAL["gold"], 2.0)
		if r > 9.0:
			draw_arc(LANTERN_POS, r - 7.0, 0.0, TAU, 32, LxPalette.PAL["apricot"], 1.0)
	_draw_lantern_core(LANTERN_POS, 2)
	for m: Dictionary in _motes:
		var ang: float = float(m["angle"])
		var spd: float = float(m["speed"])
		var dist: float = fmod(age * spd + float(m["phase"]) * 40.0, 150.0)
		var pos: Vector2 = (LANTERN_POS + Vector2(cos(ang), sin(ang)) * dist).round()
		draw_rect(Rect2(pos, Vector2(2.0, 2.0)), LxPalette.color(str(m["color"])))


func _burst_radius(t: float) -> float:
	if t < 4.9:
		return 0.0
	var u: float = clampf((t - 4.9) / 0.55, 0.0, 1.0)
	var ease_u: float = 1.0 - pow(1.0 - u, 2.0)
	return ease_u * 210.0


func _build_ending_actors() -> void:
	_eyes.clear()
	_motes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(EYE_COUNT):
		var ang: float = -PI + TAU * (float(i) + 0.5) / float(EYE_COUNT) + rng.randf_range(-0.14, 0.14)
		var dir := Vector2(cos(ang), sin(ang))
		var start_p: Vector2 = (LANTERN_POS + Vector2(dir.x * 136.0, dir.y * 74.0)).clamp(Vector2(10.0, 22.0), Vector2(310.0, 158.0))
		var heap_r: float = rng.randf_range(7.0, 22.0)
		var heap_p: Vector2 = LANTERN_POS + Vector2(dir.x * heap_r * 1.3, dir.y * heap_r * 0.85)
		_eyes.append({"start": start_p, "heap": heap_p, "dir": dir, "blink_off": rng.randf_range(0.0, 1.8), "recoil": rng.randf_range(3.0, 7.0)})
	var mote_cols: Array[String] = ["cream", "gold", "apricot", "sky", "lime"]
	for i: int in range(MOTE_COUNT):
		_motes.append({"angle": TAU * float(i) / float(MOTE_COUNT) + rng.randf_range(-0.1, 0.1), "speed": rng.randf_range(42.0, 88.0), "phase": rng.randf(), "color": mote_cols[i % mote_cols.size()]})


func _draw_results() -> void:
	LxEndingArt.draw_results_backdrop(self, RESULTS_PANEL, _elapsed)
	LxPixelFont.draw_panel(self, RESULTS_PANEL, "dusk", "gold", "night")
	var play_s: float = float(_stats.get("play_time_s", Lx.state.play_time_s if Lx.state != null else 0.0))
	var deaths: int = int(_stats.get("deaths", Lx.state.deaths if Lx.state != null else 0))
	var embers: int = int(_stats.get("ember_pieces", Lx.state.ember_pieces if Lx.state != null else 0))
	var relit: int = int(_stats.get("relit_count", Lx.state.relit_islands.size() if Lx.state != null else 0))
	var rank_key: String = _compute_rank_key(deaths, relit)
	LxEndingArt.draw_results_ornaments(self, RESULTS_PANEL, rank_key, _elapsed)

	var p: float = clampf(_elapsed / 0.35, 0.0, 1.0)
	LxPixelFont.draw_faded(self, LxStrings.text("RESULTS_TITLE"), Vector2(160.0, 34.0), p, "gold", 2, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_centered(self, LxStrings.fmt("RESULTS_RANK_FMT", [LxStrings.text(rank_key)]), 160.0, 56.0, LxEndingArt.rank_text_color(rank_key), 2)
	LxPixelFont.draw_faded(self, LxStrings.fmt("RESULTS_TIME_FMT", [LxStrings.format_time(play_s)]), Vector2(160.0, 78.0), clampf((_elapsed - 0.10) / 0.25, 0.0, 1.0), "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_faded(self, LxStrings.fmt("RESULTS_DEATHS_FMT", [deaths]), Vector2(160.0, 90.0), clampf((_elapsed - 0.18) / 0.25, 0.0, 1.0), "cream", 1, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_faded(self, LxStrings.fmt("RESULTS_EMBERS_FMT", [embers]), Vector2(160.0, 102.0), clampf((_elapsed - 0.26) / 0.25, 0.0, 1.0), "apricot", 1, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_faded(self, LxStrings.fmt("RESULTS_ISLANDS_FMT", [relit]), Vector2(160.0, 114.0), clampf((_elapsed - 0.34) / 0.25, 0.0, 1.0), "gold", 1, HORIZONTAL_ALIGNMENT_CENTER)
	LxPixelFont.draw_faded(self, LxStrings.text("RESULTS_HINT"), Vector2(160.0, 140.0), clampf((_elapsed - 0.42) / 0.25, 0.0, 1.0), "stone", 1, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_credits() -> void:
	LxEndingArt.draw_credits_backdrop(self, _elapsed)
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
	for list_key: String in ["sections", "entries", "engine", "art", "audio", "third_party_audio", "third_party", "credits"]:
		if d.has(list_key) and d[list_key] is Array:
			if _parse_credits_array(d[list_key] as Array):
				added = true
	if d.has("disclosure") and d["disclosure"] is String:
		var disc: String = str(d["disclosure"])
		for wrapped: String in _wrap_sanitized(disc, LxStrings.MAX_LEN):
			_credit_lines.append({"text": wrapped, "color": "stone", "scale": 1})
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
			added = _add_credit_line(LxStrings.sanitize(item as String), "cream") or added
		elif item is Dictionary:
			var md: Dictionary = item as Dictionary
			var title: String = LxStrings.sanitize(str(md.get("title", md.get("role", md.get("id", md.get("file", ""))))))
			var name_s: String = LxStrings.sanitize(str(md.get("name", md.get("author", md.get("source", md.get("generator", ""))))))
			var lic: String = LxStrings.sanitize(str(md.get("license", "")))
			added = _add_credit_line(title, "gold") or added
			var sub: String = (name_s if lic.is_empty() else LxStrings.sanitize(LxStrings.fmt("FMT_DASH_PAIR", [name_s, lic]))) if not name_s.is_empty() else lic
			added = _add_credit_line(sub, "cream") or added
			for wrapped: String in _wrap_sanitized(str(md.get("description", "")), LxStrings.MAX_LEN):
				added = _add_credit_line(wrapped, "stone") or added
			var lines: Variant = md.get("lines", [])
			if lines is Array:
				for ln: Variant in (lines as Array):
					added = _add_credit_line(LxStrings.sanitize(str(ln)), "stone") or added
			if added:
				_credit_lines.append({"text": "", "color": "cream", "scale": 1})
	return added


func _add_credit_line(txt: String, col: String, sc: int = 1) -> bool:
	if txt.is_empty():
		return false
	_credit_lines.append({"text": txt, "color": col, "scale": sc})
	return true


static func _wrap_sanitized(raw: String, max_chars: int) -> PackedStringArray:
	var clean: String = LxStrings.sanitize(raw, 0)
	var out := PackedStringArray()
	if clean.is_empty():
		return out
	var words: PackedStringArray = clean.split(" ", false)
	var cur: String = ""
	for w: String in words:
		if cur.is_empty():
			cur = w.substr(0, max_chars)
		elif cur.length() + 1 + w.length() <= max_chars:
			cur += " " + w
		else:
			out.append(cur)
			cur = w.substr(0, max_chars)
	if not cur.is_empty():
		out.append(cur)
	return out


static func _window_fade(t: float, from_t: float, to_t: float, edge: float) -> float:
	if t < from_t or t > to_t:
		return 0.0
	var fade_e: float = maxf(edge, 0.05)
	return clampf(minf((t - from_t) / fade_e, (to_t - t) / fade_e), 0.0, 1.0)


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
