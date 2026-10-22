extends Node2D
## The cinematic ending (STORY.md 6): about 61 s from DISPLAY: OFF to the results, on CanvasLayer 14.
## It takes Wick over (wick.cinematic: the run's step/draw calls go quiet and this draws him) and the enemies'
## eyes (run.eye_pairs, then run.hide_eyes), and draws the void, the lines, the toasts, the credits and the
## letterbox itself. The island comes back through fx.apply / island.apply with a shrinking levels dictionary.
## Part 4 is timed by the ending theme's playback position (one setting back per bar).
## main forwards key presses to key(): the first shows PRESS AGAIN TO SKIP, a second within 2 s skips.

signal finished

const PALETTE := preload("res://scripts/game/ui/palette.gd")
const FONT := preload("res://scripts/game/ui/pixel_font.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const SHADE := preload("res://scripts/cast/shade.gdshader")
const MUSIC := "res://audio/music/"

const BAR := 240.0 / 108.0 ## one bar of the ending theme (108 BPM, 4/4)
const THEME_AT := 25.7 ## the theme starts: part 4, bar 1
const TAIL := 35.0 ## theme seconds: the results step in
const SCREEN := Vector2(320, 180)
const LANTERN := Vector2(0, -7) ## the lantern glass from Wick's feet in the `ending` frames
const RAMP_STEP := 0.075 ## fades step through the palette ramp, 4 steps in 0.3 s (STORY.md 0)
const LUX := preload("res://scripts/game/ui/luxels.gd")
const LUX_Y := 20.0 ## LUXEL's top, under the letterbox (16 px)
const LUX_GAP := 0.025 ## the luxels leave the lantern one after another
const LUX_FLIGHT := 0.7
const RAMPS := {
	"cream": ["dusk", "mauve", "stone", "cream"], "stone": ["dusk", "mauve", "stone"], "mauve": ["dusk", "mauve"],
	"ice": ["deep", "blue", "sky", "ice"], "gold": ["plum", "coral", "apricot", "gold"],
	"lime": ["pine", "teal", "jade", "lime"]}
const PERCENT: Array[Vector2] = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(1, 2), Vector2(0, 3),
		Vector2(0, 4), Vector2(2, 4)] ## the 3x5 "%" the font lacks
## Lines of parts 1-3: [from, to, story id, text, colour, y, scale].
const LINES := [
	[0.4, 3.4, "ending.display_off", "DISPLAY: OFF", "ice", 40, 2],
	[4.0, 6.6, "ending.one_light", "THEY CAN STILL SEE ONE LIGHT.", "stone", 150, 1],
	[9.5, 12.0, "ending.ate", "THE DARK ATE THE LAST LIGHT.", "mauve", 150, 1],
	[20.0, 22.6, "ending.kept", "THE LANTERN KEPT EVERYTHING YOU SOLD.", "cream", 150, 1],
	[22.8, 25.4, "ending.too_much", "IT WAS TOO MUCH LIGHT FOR THE DARK.", "cream", 150, 1],
	[23.3, 25.7, "ending.display_on", "DISPLAY: ON", "gold", 40, 2],
]
## Part 4, one row per restore: [bar, id (":n" = down to level n), toast]. A bar's toast names its first two
## restores that were sold (+n for the rest); rows that were never sold drop out.
const BUY_BACK := [
	[1.0, "music", "MUSIC: ON"], [2.0, "vsync", "VSYNC: ON"], [3.0, "colour:1", "COLOURS: 4"],
	[4.0, "colour", "COLOURS: 20"], [5.0, "resolution:1", "RESOLUTION: HALF"], [5.5, "resolution", "RESOLUTION: FULL"],
	[6.0, "frame_rate", "FRAME RATE: 60"], [7.0, "sound", "SOUND: ON"], [8.0, "animations", "ANIMATIONS: ON"],
	[9.0, "brightness", "BRIGHTNESS: 100%"], [10.0, "particles", "PARTICLES: ON"], [10.0, "hit_flash", "HIT FLASH: ON"],
	[11.0, "timer", "TIMER: ON"], [11.0, "hearts", "HEARTS: SHOWN"], [11.0, "gauge", "LANTERN GAUGE: SHOWN"],
	[11.0, "warnings", "WARNINGS: ON"], [12.0, "movement", "MOVEMENT: SNAPPY"], [12.0, "input_delay", "INPUT DELAY: 0 MS"],
	[12.0, "aim", "AIM ASSIST: NEAREST"], [12.0, "difficulty", "DIFFICULTY: NORMAL"], [12.0, "mercy", "MERCY TIME: 1.5 S"],
	[12.0, "knockback", "KNOCKBACK: ON"], [12.0, "healing", "HEALING: ON"], [13.0, "up_key", "UP KEY: ON"],
	[14.0, "subtitles", "SUBTITLES: ON"], [14.0, "tips", "TIPS: ON"], [14.0, "shake", "SCREEN SHAKE: ON"],
	[14.0, "ray_tracing", "RAY TRACING: OFF"], [14.0, "confirm", "CONFIRM SALES: ON"],
]
## Credits in the bottom bar: [bar, story id, text ("\n" = two lines), the row it needs sold ("" = always)].
const CREDITS := [
	[1, "ending.credit.1", "A GAME BY MARWAN", ""], [2, "ending.credit.2", "THEME: TRADE-OFF", ""],
	[5, "ending.credit.5", "MADE IN GODOT 4.7", ""], [6, "ending.credit.6", "MADE WITH CLAUDE", ""],
	[7, "ending.credit.7", "SOUND EFFECTS: KENNEY.NL - CC0", ""], [8, "ending.credit.8", "MUSIC: LANTERN GOTHIC", ""],
	[10, "ending.credit.10", "SOUNDFONT: MUSESCORE GENERAL\nFLUIDR3 - FLUIDR3MONO - S. CHRISTIAN COLLINS", ""],
	[11, "ending.credit.11", "", ""], [13, "ending.credit.13", "THE UP KEY IS BACK. LOOK AFTER IT.", "up_key"],
	[14, "ending.credit.14", "STILL NO SUBTITLES. SORRY.", "subtitles"], [15, "ending.see_you", "SEE YOU AT SUNSET.", ""],
]
const TOWER := Vector2(480, 20) ## camera origins (the game screen's top-left in the world)
const GROVE := Vector2(100, 0)
const RISE: Array[int] = [69, 73, 74, 76, 77, 79, 81, 86] ## a chime per rekindled frame: A4 C#5 D5 E5 F5 G5 A5 D6
const RING := Vector2(40, 31) ## the eyes' ring radii around the lantern
const MAX_EYES := 28
const MIN_EYES := 16
const MOTES := 18
const MOTE_FLIGHT := 0.65
const MOTE_ROWS := {"gold": ["cream", "gold", "apricot"], "rose": ["cream", "rose", "wine"],
	"sky": ["ice", "sky", "blue"], "lime": ["cream", "lime", "jade"], "ice": ["cream", "ice", "sky"]}
const THEME_DB := -5.0 ## settings_fx's MUSIC_DB: the ending theme sits where the run track did
const THEME_SKIP_FADE := 0.5 ## s: a skip fades the theme out before the results' title loop comes in
const NOTE_DB := -5.0 ## the lantern notes, as in the finale
const SMOTHER_AT := 6.6 ## the ring closes over the lantern and more pairs pour in from the edges
const HEAP_BY := 8.3 ## every pair has reached the heap
const DARK_AT := 8.7 ## the lantern is out: black but the heap of eyes
const RELOCATE_AT := 15.6 ## every pair is shut: Wick and the camera go to the sundial unseen
const REHOME_AT := 16.2 ## after _check_pan: the shut heap moves to the lantern's new place
const WAKE_AT := 17.6 ## every pair snaps open at once (startled)
const REKINDLE_AT := 18.0
const REKINDLE_SECS := 1.9
const HEAP := Vector2(4, 10) ## the heap: each pair ends this many px (min, max) from the lantern glass
const HEAP_EYES := Vector2i(24, 32) ## pairs in all once the rest have poured in
const POUR := 10 ## pairs that pour in at the smother (more if needed to reach HEAP_EYES.x)
const RECOIL := Vector2(2, 4) ## px each pair backs off from the rekindling lantern
const BURST_SECS := 0.5 ## the gold ring sweeps past the farthest screen corner
const SPARK := 0.1 ## a popped pair's cream spark: two 0.05 s frames, then it streams into the lantern
const SWIRL := Vector2(22, 10) ## a spark's path bows this far out (along, across) before it streams in
const BELL := "res://audio/sfx/toll.wav" ## the burst's low bell: the BELL TOLL sample (A4) pitched to D3
const BELL_PITCH := 0.3337 ## A4 -> D3 (146.8 Hz)
const BELL_DB := -9.0
const BELL_RING := 74 ## lantern_74 (D5) an octave down (D4) rings on under the toll
const HINT_UP := 2.0 ## s the skip hint stays after a press; a second press inside it skips
const TOUCH_SKIP_AFTER := 0.25 ## s the hint must be up before a finger skips (two thumbs landing together count once)

var run ## run.gd (fx, island, view, wick, player, shop, hud)
var narration ## narration.gd

var _on := false ## between play() and stop()
var _done := false ## finished was emitted
var _now := 0.0 ## seconds since DISPLAY: OFF (nudged to the theme's playback in part 4)
var _cues: Array = [] ## [t, Callable], sorted
var _cue_i := 0
var _stats := {}
var _levels := {} ## what fx and the island show; sold rows come back bar by bar
var _was_sold := {} ## the levels at DISPLAY: OFF
var _rng := RandomNumberGenerator.new()
var _eyes: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _relight: Array = [] ## [t, Sprite2D]: BRIGHTNESS relights the grove west to east
var _wick_shown := true
var _pan_shift := Vector2.ZERO ## added to every pan target (see _check_pan)
var _pan_check_at := -1.0
var _wick_stage := "" ## which part of Wick's choreography runs ("down", "out", "rekindle", "stand", "")
var _last_frame := -1
var _rise_i := 0
var _gold_pixel := false
var _pixels_from := -1.0 ## when the pixels start coming back
var _bars_from := INF ## when the letterbox slides in
var _toast := ""
var _toast_from := 0.0
var _toast_to := 0.0
var _credit := PackedStringArray()
var _credit_from := 0.0
var _credit_to := 0.0
var _titles_to := INF
var _lux: Array[Dictionary] = [] ## LUXEL's luxels (luxels.gd cells), made on first draw
var _hint_to := -1.0
var _theme: AudioStreamPlayer
var _theme_tween: Tween
var _bell: AudioStreamPlayer ## the burst: the toll, low
var _bell_ring: AudioStreamPlayer ## the burst: a lantern note, low
var _heap_at := Vector2.ZERO ## the lantern on screen when the dark closed over it
var _burst_from := -1.0
var _burst_at := Vector2.ZERO
var _burst_r := 0.0
var _notes: Array[AudioStreamPlayer] = []
var _note_i := 0
var _finale_notes: Array = []
var _drone_end := -19.0 ## dB the finale drone ends PIXELS at (MUSIC_DB + music.json's last drone_db)
var _shade_layer: Node2D ## Wick's shadow through shade.gdshader (under him, over the island)
var _front: Node2D ## everything else


## Keeps the run and the narration node; builds the players and the two drawing layers.
func setup(r: Node2D, narr: Node2D) -> void:
	run = r
	narration = narr
	visible = false
	_shade_layer = Node2D.new()
	_shade_layer.material = ShaderMaterial.new()
	(_shade_layer.material as ShaderMaterial).shader = SHADE
	_shade_layer.draw.connect(_draw_shadow)
	add_child(_shade_layer)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	_theme = _player(load(MUSIC + "ending.wav"), THEME_DB)
	_bell = _player(load(BELL), BELL_DB)
	_bell.pitch_scale = BELL_PITCH
	_bell_ring = _player(load(MUSIC + "lantern_%d.wav" % BELL_RING), NOTE_DB)
	_bell_ring.pitch_scale = 0.5
	for i in 4:
		_notes.append(_player(null, NOTE_DB))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MUSIC + "music.json"))
	if data is Dictionary:
		_finale_notes = data["finale"]["notes"]
		_drone_end = THEME_DB + float(data["finale"]["drone_db"][-1])
	if run != null and run.has_signal("phase_changed"):
		run.phase_changed.connect(_on_phase)


## Plays the ending for a run that reached DISPLAY: OFF (the screen is black, the eyes still open).
func play(stats: Dictionary) -> void:
	_stats = stats
	_on = true
	_done = false
	_now = 0.0
	_rng.seed = 7
	_motes.clear()
	_relight.clear()
	_toast = ""
	_credit = PackedStringArray()
	_titles_to = INF
	_hint_to = -1.0
	_bars_from = INF
	_pixels_from = -1.0
	_gold_pixel = false
	_wick_shown = true
	_burst_from = -1.0
	var shop_levels: Dictionary = run.shop.levels if run.shop != null and "levels" in run.shop else {}
	_was_sold = shop_levels.duplicate()
	_levels = shop_levels.duplicate()
	_levels["pixels"] = 100
	_levels["music"] = maxi(int(_levels.get("music", 0)), 1) # fx keeps the run track off: the theme is the music
	if run.hud != null:
		run.hud.set_shown(false)
	if run.fx.has_method("drone_to"): # the agreed ending(): music held, the drone kept, no cue (P5 notes)
		run.fx.ending()
	_take_wick()
	_take_eyes()
	_build_cues()
	visible = true
	set_process(true)


## Skips to the results state at once (everything back, Wick at the sundial) and emits finished.
func skip() -> void:
	if not _on or _done:
		return
	_eyes.clear()
	_motes.clear()
	_relight.clear()
	_cue_i = _cues.size()
	_drone(-80.0, 0.05)
	if _now < RELOCATE_AT:
		_relocate()
	_burst_from = -1.0
	_gold_pixel = false
	_wick_shown = true
	_wick_stage = ""
	run.wick.play("sell")
	_restore_all()
	_set_pixels(0)
	_bars_from = minf(_bars_from, _now - 1.0)
	_toast = ""
	_credit = PackedStringArray()
	_titles_to = _now
	_pan(_wick_origin(), 0.0)
	_pan_check_at = _now + 0.15
	if _theme.playing: # the results start quiet; their title loop comes in 2 s later
		_kill_theme_tween()
		_theme_tween = create_tween()
		_theme_tween.tween_property(_theme, "volume_db", -60.0, THEME_SKIP_FADE)
		_theme_tween.tween_callback(_theme.stop)
	_finish()


## Lets Wick go and clears the screen (the next run, or the title). Called on the run's next phase change.
func stop() -> void:
	if not _on:
		return
	_on = false
	visible = false
	_kill_theme_tween()
	_theme.stop()
	_eyes.clear()
	_motes.clear()
	if run != null and run.wick != null:
		run.wick.cinematic = false


func _process(delta: float) -> void:
	if not _on:
		return
	_clock(delta)
	while _cue_i < _cues.size() and _cues[_cue_i][0] <= _now:
		(_cues[_cue_i][1] as Callable).call()
		_cue_i += 1
	if _pan_check_at >= 0.0 and _now >= _pan_check_at:
		_pan_check_at = -1.0
		_check_pan()
	run.wick.cine_step(delta)
	_step_wick()
	_step_eyes(delta)
	_step_pixels()
	_step_relight()
	for m in _motes:
		m["t"] += delta
	if not _motes.is_empty():
		_motes.assign(_motes.filter(func(m: Dictionary) -> bool: return m["t"] < MOTE_FLIGHT + 0.12))
	queue_redraw()
	_shade_layer.queue_redraw()
	_front.queue_redraw()


## A key press or a finger down while the ending plays (main forwards them): the first shows the hint, a second skips.
func key(event: InputEvent) -> void:
	if not _on or _done:
		return
	var k := event as InputEventKey
	var touch := event as InputEventScreenTouch
	if (k == null or not k.pressed or k.echo) and (touch == null or not touch.pressed):
		return
	if _now < _hint_to:
		if touch == null or _now >= _hint_to - HINT_UP + TOUCH_SKIP_AFTER:
			skip()
	else:
		_hint_to = _now + HINT_UP


# --- timeline ------------------------------------------------------------------------------------------------

func _build_cues() -> void:
	_cues.clear()
	_cue_i = 0
	_cue(1.0, _drone.bind(_drone_end + 3.0, 4.0)) # the drone swells a little while the eyes gather
	_cue(SMOTHER_AT, _smother)
	_cue(6.8, _wick_out)
	_cue(DARK_AT, func() -> void: _wick_shown = false)
	_cue(RELOCATE_AT, _relocate)
	_cue(REHOME_AT, _rehome_eyes)
	_cue(17.0, func() -> void: _gold_pixel = true)
	_cue(WAKE_AT, _chime.bind(69, 0.8))
	_cue(REKINDLE_AT, _wick_rekindle)
	_cue(REKINDLE_AT + REKINDLE_SECS + 0.3, _burst) # only if the frame-synced burst (in _step_wick) didn't come
	_cue(20.8, _pixels_back)
	_cue(21.0, func() -> void: _stream("", _feet_on_screen() + run.wick.emit())) # the intro's light sent back out
	for i in 10: # the finale's lantern notes, every 10th, backwards: a rewind
		var k := 99 - i * 10
		if k < _finale_notes.size():
			_cue(20.8 + i * 0.25, _chime.bind(int(_finale_notes[k]), 0.75))
	_cue(23.3, _restore_quiet)
	_cue(THEME_AT, _theme_start)
	var bars := {}
	for row: Array in BUY_BACK:
		bars[row[0]] = true
	for bar: float in bars:
		_cue(_bar(bar), _buy_back.bind(bar))
	for c: Array in CREDITS:
		_cue(_bar(c[0]), _show_credit.bind(c))
	_cue(_bar(5.0) + BAR * 0.5, _pan.bind(TOWER, 5.5)) # starts choppy at 20 fps, smooth from bar 6
	_cue(_bar(8.0), _pan.bind(GROVE, BAR))
	_cue(_bar(11.0), func() -> void: _pan(_wick_origin(), 2.0 * BAR))
	_cue(_bar(14.0), func() -> void: run.wick.play("sell"))
	_cue(_bar(15.0), _landing)
	_cue(THEME_AT + TAIL, _finish)
	_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _cue(t: float, f: Callable) -> void:
	_cues.append([t, f])


func _bar(bar: float) -> float:
	return THEME_AT + (bar - 1.0) * BAR


## Free-running seconds, nudged toward the theme's playback position while it plays (10 ms per frame at most).
func _clock(delta: float) -> void:
	_now += delta
	if _theme.playing:
		var pos := _theme.get_playback_position() + (0.0 if OS.has_feature("movie") else AudioServer.get_time_since_last_mix())
		_now += clampf(THEME_AT + pos - _now, -0.01, 0.01)


func _finish() -> void:
	if _done:
		return
	_done = true
	_bars_from = minf(_bars_from, _now - 1.0)
	_titles_to = minf(_titles_to, _now + 0.3)
	_credit_to = minf(_credit_to, _now + 0.3)
	if narration != null:
		narration.letterbox(true, 0.0)
	run.wick.cinematic = false # the run draws and steps Wick again under the results (and hides him on the title)
	finished.emit()


func _on_phase(_phase: int) -> void:
	if _done:
		stop()


# --- Wick ----------------------------------------------------------------------------------------------------

func _take_wick() -> void:
	var w = run.wick
	w.cinematic = false
	w.tier = 2 # the full glow the storyboard dims from; held from here on
	w.cinematic = true
	w.dir = "front"
	w.flip = false
	w.play_range("ending", 0, 3) # sits, the lantern in its lap, looks down at it, then up
	_wick_stage = "down"
	_last_frame = -1


func _wick_out() -> void:
	run.wick.play_range("ending", 4, 11) # the lantern dims to nothing under the eyes; Wick's eyes shut
	_wick_stage = "out"


func _wick_rekindle() -> void:
	_wick_shown = true
	_rise_i = 0
	run.wick.play_range("ending", 3, 11, true, 2.3 / 1.9)
	_wick_stage = "rekindle"
	_last_frame = 11


## Frame-synced sounds and the hand-offs between Wick's ranges.
func _step_wick() -> void:
	var w = run.wick
	var f: int = w.range_frame()
	var changed := f != _last_frame and f >= 0
	_last_frame = f
	match _wick_stage:
		"out":
			if changed and f == 11:
				_drone(-80.0, 0.05) # stops exactly on "out"
		"rekindle":
			if changed and _rise_i < RISE.size():
				_chime(RISE[_rise_i], 0.6 + 0.05 * _rise_i)
				_rise_i += 1
			if f >= 0 and f < 8:
				_gold_pixel = false
			if w.range_done():
				w.play_range("ending", 0, 2, true) # stands
				_wick_stage = "stand"
				_burst()
		"stand":
			if w.range_done():
				w.play("levelup") # the lantern raised high; levelup_hold follows by itself
				_wick_stage = ""


## In the dark nobody sees it (every pair is shut): Wick and the camera go to the sundial.
func _relocate() -> void:
	_wick_shown = false
	if run.island != null:
		run.player.feet = run.island.spawn
		if run.view.has_method("place_wick"):
			run.view.place_wick(run.island.spawn)
	_pan(_wick_origin(), 0.0)
	_pan_check_at = _now + 0.15


## view.pan_to takes the camera origin (the game screen's top-left in the world), as STORY.md writes them.
func _pan(origin: Vector2, secs: float) -> void:
	run.view.pan_to(origin + _pan_shift, secs)


## The cut to the sundial happens in the dark, so it doubles as a test: if the view took the origin for the
## screen centre (view.pan_to's reading is still open, P5 notes), every later pan is shifted to match.
func _check_pan() -> void:
	var want := _wick_origin()
	if _origin().distance_to(want - SCREEN / 2.0) < 3.0: # the view centred on `want`
		_pan_shift = SCREEN / 2.0
		_pan(want, 0.0)


## The camera origin that puts the lantern at the centre of the game screen.
func _wick_origin() -> Vector2:
	return (run.player.feet + LANTERN - SCREEN / 2.0).round()


func _origin() -> Vector2:
	if run.view.has_method("origin"):
		return run.view.origin()
	return run.view.view_rect().position + Display.margin


func _feet_on_screen() -> Vector2:
	return (run.player.feet - _origin()).round()


# --- eyes ----------------------------------------------------------------------------------------------------

## Takes the enemies' eyes (world positions) as screen points, tops them up to 16 pairs and gives each a place on
## a loose ring around the lantern (the smother adds the rest and closes them over it).
func _take_eyes() -> void:
	_eyes.clear()
	var pairs: PackedVector2Array = run.eye_pairs()
	run.hide_eyes()
	var lantern := _feet_on_screen() + LANTERN
	var points: Array[Vector2] = []
	for p in pairs:
		var s := p - _origin()
		if Rect2(Vector2(-40, -40), SCREEN + Vector2(80, 80)).has_point(s):
			points.append(s)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(lantern) < b.distance_to(lantern))
	points.resize(mini(points.size(), MAX_EYES))
	for p in points:
		_eyes.append({"p": p, "open": 0.0})
	while _eyes.size() < MIN_EYES:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.0, 2.7)
		var p := lantern + Vector2(cos(a) * RING.x, sin(a) * RING.y) * r
		_eyes.append({"p": p.clamp(Vector2(8, 22), SCREEN - Vector2(8, 22)), "open": _rng.randf_range(1.0, 2.2)})
	_ring(lantern)
	_closing_order()


## The 18 nearest pairs take the inner ring, the rest an outer one; each keeps its side of the lantern.
func _ring(lantern: Vector2) -> void:
	_eyes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["p"].distance_to(lantern) < b["p"].distance_to(lantern))
	var inner := _eyes.slice(0, 18)
	var outer := _eyes.slice(18)
	for g in 2:
		var group: Array = [inner, outer][g]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["p"] - lantern).angle() < (b["p"] - lantern).angle())
		for k in group.size():
			_ring_place(group[k], k, group.size(), g == 1, lantern)


func _ring_place(e: Dictionary, k: int, n: int, outer: bool, lantern: Vector2) -> void:
	var a := -PI + TAU * (k + 0.5) / n + _rng.randf_range(-0.12, 0.12)
	var r := (1.4 if outer else 1.0) * _rng.randf_range(0.92, 1.08)
	e["goal"] = lantern + Vector2(cos(a) * RING.x, sin(a) * RING.y) * r
	e["v"] = maxf(6.0, e["p"].distance_to(e["goal"]) / 3.2)
	e["blink"] = maxf(e["open"], 1.0) + _rng.randf_range(0.0, 0.3)
	e["wob"] = 0
	e["step"] = 8.7 + _rng.randf_range(0.0, 0.6)


## The pairs close one by one in random order, faster and faster; the last one drifts in, blinks slowly, closes.
func _closing_order() -> void:
	var order := range(_eyes.size())
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var n := order.size()
	for k in n:
		var e := _eyes[order[k]]
		e["shut"] = 12.2 + 2.3 * sqrt(float(k) / maxf(n - 1, 1)) if k < n - 1 else 15.5
		e["last"] = k == n - 1


func _step_eyes(dt: float) -> void:
	var centre := SCREEN / 2.0
	for e in _eyes:
		var slow := 2.0 if _now >= DARK_AT else 1.0 # the heap blinks slowly
		if _now >= e["blink"] + 0.25 * slow and _now < 12.2:
			e["blink"] = _now + _rng.randf_range(1.8, 3.6)
		if _now > maxf(e["open"], 1.0) + 0.3 and _now < DARK_AT:
			e["p"] = (e["p"] as Vector2).move_toward(e["goal"], e["v"] * dt)
		if _now >= e["step"] and _now < 15.5: # the heap jostles
			e["wob"] = clampi(e["wob"] + (1 if _rng.randf() < 0.5 else -1), -1, 1)
			e["step"] = _now + _rng.randf_range(0.4, 0.8)
		if e["last"] and _now >= 14.6 and not e.has("drift"):
			e["drift"] = true
			e["p"] = (e["p"] as Vector2) + ((centre - e["p"]) as Vector2).sign() * Vector2(1, 0)
			e["blink"] = 14.9
		if _now >= WAKE_AT + 0.1 and _now >= e.get("jit_at", 0.0) and not e.has("pop"): # startled: they jitter
			e["jit"] = Vector2(_rng.randi_range(-1, 1), _rng.randi_range(-1, 1))
			e["jit_at"] = _now + _rng.randf_range(0.06, 0.14)
		if e.has("pop") and _now >= e["pop"] + SPARK and not e.has("homed"): # the spark streams into the lantern
			e["homed"] = true
			_motes.append({"j": _motes.size(), "t": _now - e["pop"] - SPARK, "from": e["at"], "home": true,
				"out": ((e["at"] - _burst_at) as Vector2).normalized(), "row": "gold"})
	_eyes.assign(_eyes.filter(func(e: Dictionary) -> bool: return not e.has("homed")))


## Where a pair is drawn: its place, the jostle, and once awake the flinch, the recoil and the jitter.
func _eye_pos(e: Dictionary) -> Vector2:
	var p: Vector2 = (e["p"] as Vector2) + Vector2(e["wob"], 0)
	if _now >= WAKE_AT:
		p += e.get("jit", Vector2.ZERO) as Vector2
		if _now < WAKE_AT + 0.1:
			p.y -= 1.0
		var u := clampf((_now - REKINDLE_AT) / REKINDLE_SECS, 0.0, 1.0)
		p += (e.get("away", Vector2.ZERO) as Vector2) * float(e.get("recoil", 0.0)) * u
	return p.round()


## 0 = hidden, 1 = half (blue), 2 = open (ice), 3 = popped (the cream spark).
func _eye_state(e: Dictionary) -> int:
	var t := _now
	if e.has("pop") and t >= e["pop"]:
		return 3 if t < e["pop"] + SPARK else 0
	if t >= WAKE_AT: # wide awake, all at once
		return 2
	if t < e["open"]:
		return 0
	if t < e["open"] + 0.08 or (t >= e["shut"] and t < e["shut"] + 0.1):
		return 1
	if t >= e["shut"]:
		return 0
	var b: float = t - e["blink"]
	var slow := 2.0 if t >= DARK_AT else 1.0
	if b >= 0.0 and b < 0.05 * slow or b >= 0.15 * slow and b < 0.2 * slow:
		return 1
	if b >= 0.05 * slow and b < 0.15 * slow:
		return 0
	return 2


## The smother: more pairs pour in from the screen edges (HEAP_EYES in all) and every pair closes over the
## lantern, 4-10 px out, stacked over Wick; each keeps its side so none crosses the glass.
func _smother() -> void:
	var lantern := _feet_on_screen() + LANTERN
	_heap_at = lantern
	var want := clampi(_eyes.size() + POUR, HEAP_EYES.x, HEAP_EYES.y)
	var m := want - _eyes.size()
	var perimeter := 2.0 * (SCREEN.x + SCREEN.y)
	for k in m:
		var open := SMOTHER_AT + 0.9 * k / maxf(m, 1)
		_eyes.append({"p": _border(_rng.randf() * perimeter, SCREEN), "open": open, "wob": 0,
			"blink": open + _rng.randf_range(1.0, 2.0), "step": DARK_AT + _rng.randf_range(0.0, 0.6)})
	_eyes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["p"] - lantern).angle() < (b["p"] - lantern).angle())
	var n := _eyes.size()
	for k in n:
		var e := _eyes[k]
		var a := -PI + TAU * (k + 0.5) / n + _rng.randf_range(-0.2, 0.2)
		e["goal"] = lantern + Vector2(cos(a), sin(a) * 0.8) * _rng.randf_range(HEAP.x, HEAP.y)
		var from := maxf(maxf(e["open"], 1.0) + 0.3, SMOTHER_AT)
		e["v"] = maxf(6.0, e["p"].distance_to(e["goal"]) / maxf(HEAP_BY - from, 0.4))
	_closing_order()


## Every pair is shut and Wick has moved to the sundial: the heap follows the lantern, and each pair learns which
## way it will back off when the lantern rekindles.
func _rehome_eyes() -> void:
	var lantern := _feet_on_screen() + LANTERN
	var shift := lantern - _heap_at
	_heap_at = lantern
	for e in _eyes:
		e["p"] = (e["p"] as Vector2) + shift
		var away: Vector2 = (e["p"] - lantern) as Vector2
		e["away"] = away.normalized() if away.length() > 0.5 else Vector2.UP
		e["recoil"] = _rng.randf_range(RECOIL.x, RECOIL.y)


## The burst: Wick stands with the light back, and a gold ring from the lantern sweeps past the farthest corner;
## each pair pops as the ring reaches it.
func _burst() -> void:
	if _burst_from >= 0.0 or not _on:
		return
	_burst_from = _now
	_burst_at = _feet_on_screen() + run.wick.emit()
	var far := 0.0
	for c: Vector2 in [Vector2.ZERO, Vector2(SCREEN.x, 0), Vector2(0, SCREEN.y), SCREEN]:
		far = maxf(far, _burst_at.distance_to(c))
	_burst_r = far + 8.0
	for e in _eyes:
		e["at"] = _eye_pos(e)
		var d := minf(_burst_at.distance_to(e["at"]) / _burst_r, 1.0)
		e["pop"] = _burst_from + BURST_SECS * (1.0 - sqrt(1.0 - d)) # the ring's ease-out, inverted
	_bell_toll()


# --- the island coming back ----------------------------------------------------------------------------------

func _pixels_back() -> void:
	_pixels_from = _now
	_bars_from = _now
	_shade_layer.visible = true


func _step_pixels() -> void:
	if _pixels_from < 0.0:
		return
	var u := clampf((_now - _pixels_from) / 2.5, 0.0, 1.0)
	var sold := roundi(100.0 * (1.0 - u))
	if sold != int(_levels.get("pixels", 0)):
		_set_pixels(sold)
	if u < 1.0:
		_toast = "PIXELS: %d%%" % (100 - sold)
		_toast_from = _pixels_from + 0.2
		_toast_to = _pixels_from + 2.9
	else:
		_pixels_from = -1.0


func _set_pixels(sold: int) -> void:
	_levels["pixels"] = sold
	_apply()


## LANGUAGE (only if it hasn't worn off yet: the debug jumps sell it without menus) and AUDIO QUALITY come back
## without a word, before the music.
func _restore_quiet() -> void:
	for id: String in ["language", "audio_quality"]:
		if id == "language" and run.shop != null and run.shop.has_method("language_on") \
				and not run.shop.language_on():
			continue
		_restore(id, 0)
	_apply()


func _theme_start() -> void:
	_kill_theme_tween()
	_theme.volume_db = THEME_DB
	_theme.play()


func _kill_theme_tween() -> void:
	if _theme_tween:
		_theme_tween.kill()
		_theme_tween = null


func _buy_back(bar: float) -> void:
	var names := PackedStringArray()
	var key := ""
	for row: Array in BUY_BACK:
		if row[0] != bar:
			continue
		var parts: PackedStringArray = (row[1] as String).split(":")
		var id := parts[0]
		var to := int(parts[1]) if parts.size() > 1 else 0
		if int(_was_sold.get(id, 0)) > to and int(_levels.get(id, 0)) > to:
			_restore(id, to)
			names.append(row[2])
			key = id if key == "" else key
	if names.is_empty():
		return
	if key == "brightness" and run.island.has_method("lit_props"):
		_stage_relight()
	else:
		_apply()
	_toast = " - ".join(names.slice(0, 2)) + ("" if names.size() <= 2 else " +%d" % (names.size() - 2))
	_toast_from = _now
	_toast_to = _now + BAR - 0.1
	_stream(key)


func _restore(id: String, to: int) -> void:
	if id != "music":
		_levels[id] = to
	if run.shop != null and "levels" in run.shop and run.shop.levels.has(id):
		run.shop.levels[id] = to
		run.shop.rev += 1


## Bar 15, the D major landing: everything else comes back at once.
func _landing() -> void:
	_restore_all()
	_titles_to = INF


func _restore_all() -> void:
	for id: String in _levels.keys():
		if id != "music":
			_restore(id, 0)
	if run.shop != null and "levels" in run.shop:
		for id: String in run.shop.levels.keys():
			run.shop.levels[id] = 0
		run.shop.rev += 1
	_apply()


func _apply() -> void:
	run.fx.apply(_levels)
	if run.island != null:
		run.island.apply(_levels)


## BRIGHTNESS: the lit props come back west to east, the Lantern Mother first (the intro, reversed).
func _stage_relight() -> void:
	run.fx.apply(_levels)
	var props: Array = run.island.lit_props()
	var mother := props.filter(func(s: Sprite2D) -> bool: return s.name.contains("lantern_mother"))
	props = mother + props.filter(func(s: Sprite2D) -> bool: return not mother.has(s))
	for i in props.size():
		_relight.append([_now + 1.6 * i / maxf(props.size(), 1.0), props[i]])


func _step_relight() -> void:
	if _relight.is_empty():
		return
	while not _relight.is_empty() and _relight[0][0] <= _now:
		run.island.set_lit(_relight.pop_front()[1], true)
	if _relight.is_empty():
		run.island.apply(_levels)


## A credit not filled in yet (story_text TBD) falls back to this file's text, never a placeholder.
func _credit_text(c: Array) -> String:
	return c[2] if STORY.TBD.has(c[1]) else STORY.line(c[1], c[2])


func _show_credit(c: Array) -> void:
	var text := _credit_text(c)
	if text == "" or (c[3] != "" and int(_was_sold.get(c[3], 0)) == 0):
		return
	_credit = text.split("\n")
	_credit_from = _now + 0.15
	var next := INF
	for d: Array in CREDITS:
		if d[0] > c[0] and _credit_text(d) != "":
			next = minf(next, _bar(d[0]))
	_credit_to = minf(next, _now + 2.0 * BAR) - 0.25


# --- sound ---------------------------------------------------------------------------------------------------

func _player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Master" # the ending always plays: MUSIC and SOUND may still be sold
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM # web: sample playback reports its position 1 s late
	add_child(p)
	return p


func _chime(midi: int, gain: float) -> void:
	var path := MUSIC + "lantern_%d.wav" % midi
	if not ResourceLoader.exists(path):
		return
	var p := _notes[_note_i % _notes.size()]
	_note_i += 1
	p.stream = load(path)
	p.volume_db = NOTE_DB + linear_to_db(gain)
	p.play()


## The burst's sound: a low bell on D under the last rekindle chime (both players skip SOUND: Master bus).
func _bell_toll() -> void:
	_bell.play()
	_bell_ring.play()


## The finale's drone (settings_fx owns it): fades to `db` over `secs`; -80 stops it.
func _drone(db: float, secs: float) -> void:
	if run.fx.has_method("drone_to"):
		run.fx.drone_to(db, secs)


# --- drawing -------------------------------------------------------------------------------------------------

func _draw() -> void:
	if _pixels_from < 0.0 and _bars_from == INF: # parts 1-3: the void over everything below
		draw_rect(Display.screen_rect(), _c("void"))


func _draw_shadow() -> void:
	if _on and _wick_shown and _bars_from != INF and run.wick.cinematic:
		run.wick.cine_shadow(_shade_layer, _feet_on_screen(), Color.WHITE)


func _draw_front() -> void:
	if not _on:
		return
	var ci := _front
	var feet := _feet_on_screen()
	if _wick_shown and run.wick.cinematic:
		run.wick.cine_draw(ci, feet)
	_draw_eyes(ci) # over Wick: the dark stacks on the lantern
	if _gold_pixel:
		ci.draw_rect(Rect2(feet + LANTERN, Vector2.ONE), _c("gold"))
	_draw_burst(ci)
	_draw_motes(ci, feet + run.wick.emit())
	_draw_bars(ci)
	for l: Array in LINES if not _done else []:
		if _ramp(l[4], l[0], l[1]).a != 0.0: # most lines are not showing: skip their lookup
			_line(ci, STORY.line(l[2], l[3]), l[0], l[1], l[4], l[5], l[6])
	_draw_luxels(ci, feet + LANTERN, _bar(15.0), _titles_to)
	var built := _lux_built(_bar(15.0))
	if _ramp("lime", built, _titles_to).a != 0.0:
		_line(ci, STORY.line("ending.all_high", "ALL SETTINGS: HIGH"), built, _titles_to, "lime", 50, 1)
	_draw_toast(ci)
	for i in _credit.size():
		var y := 166 if _credit.size() == 1 else 165 + 7 * i
		_line(ci, _credit[i], _credit_from, _credit_to, "cream", y, 1)
	if _now < _hint_to:
		var hint := STORY.line("ending.skip", "PRESS AGAIN TO SKIP")
		_text(ci, hint, Vector2(SCREEN.x - 4 - FONT.width(hint), 6), _c("mauve"))


func _draw_bars(ci: CanvasItem) -> void:
	if _bars_from == INF or _done: # after the ending the narration's letterbox takes over
		return
	var h := 16.0 * clampf((_now - _bars_from) / 0.4, 0.0, 1.0)
	if h <= 0.0:
		return
	var sr := Display.screen_rect()
	ci.draw_rect(Rect2(sr.position.x, sr.position.y, sr.size.x, roundf(h) - sr.position.y), _c("void"))
	var bottom := SCREEN.y - roundf(h)
	ci.draw_rect(Rect2(sr.position.x, bottom, sr.size.x, sr.end.y - bottom), _c("void"))


func _draw_eyes(ci: CanvasItem) -> void:
	for e in _eyes:
		var s := _eye_state(e)
		if s == 3: # the pop: a cream plus, then four cream points 2 px out
			var at: Vector2 = e["at"]
			var big: bool = _now >= float(e["pop"]) + SPARK / 2.0
			for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				ci.draw_rect(Rect2(at + o * (2.0 if big else 1.0), Vector2.ONE), _c("cream"))
			if not big:
				ci.draw_rect(Rect2(at, Vector2.ONE), _c("cream"))
		elif s > 0:
			var p := _eye_pos(e)
			var col := _c("ice") if s == 2 else _c("blue")
			ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2.ONE), col)
			ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), col)


## The burst's ring: 2 px of gold with a cream leading edge, easing out past the farthest corner, cooling through
## apricot and coral as it goes.
func _draw_burst(ci: CanvasItem) -> void:
	if _burst_from < 0.0 or _now >= _burst_from + BURST_SECS:
		return
	var u := (_now - _burst_from) / BURST_SECS
	var r := maxf(1.0, _burst_r * (1.0 - (1.0 - u) * (1.0 - u)))
	var col := _c("gold") if u < 0.6 else (_c("apricot") if u < 0.8 else _c("coral"))
	ci.draw_arc(_burst_at, r, 0.0, TAU, 128, col, 2.0)
	if u < 0.6:
		ci.draw_arc(_burst_at, r + 1.5, 0.0, TAU, 128, _c("cream"), 1.0)


## Toasts pop like the menu's: the box and the text appear together, cream for one frame step, then gold.
func _draw_toast(ci: CanvasItem) -> void:
	if _toast == "" or _now < _toast_from or _now >= _toast_to:
		return
	var col := _c("cream") if _now < _toast_from + RAMP_STEP else _c("gold")
	var w := FONT.width(_toast)
	var x := roundf(SCREEN.x / 2.0 - w / 2.0)
	ci.draw_rect(Rect2(x - 4, 3, w + 8, 11), _c("dusk"))
	_text(ci, _toast, Vector2(x, 6), col)


## 18 motes stream out of the lantern to the screen edges, in the setting's sell-stream colour.
func _stream(id: String, from := Vector2.INF) -> void:
	var lantern := _feet_on_screen() + LANTERN if from == Vector2.INF else from.round()
	if not Rect2(Vector2(8, 16), SCREEN - Vector2(16, 32)).has_point(lantern):
		return
	var sr := Display.screen_rect()
	var perimeter := 2.0 * (sr.size.x + sr.size.y)
	for j in MOTES:
		var to := sr.position + _border(perimeter * (j + 0.5) / MOTES, sr.size)
		_motes.append({"j": j, "t": -0.03 * ((j * 7) % MOTES), "from": lantern, "to": to, "row": _mote_row(id, j)})


func _draw_motes(ci: CanvasItem, lantern: Vector2) -> void:
	for m in _motes:
		var cols: Array = MOTE_ROWS[m["row"]]
		for back in range(4, -1, -1):
			var t: float = m["t"] - 0.025 * back
			if t < 0.0:
				continue
			var p := _mote_at(m, t, lantern).round()
			if back == 0:
				for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					ci.draw_rect(Rect2(p + o, Vector2.ONE), _c(cols[1]))
				ci.draw_rect(Rect2(p, Vector2.ONE), _c(cols[0]))
			else:
				ci.draw_rect(Rect2(p, Vector2.ONE), _c(cols[1] if back < 3 else cols[2]))


## Out of the lantern, bowing left or right, slowing toward the edge. A burst spark ("home") is flung out first,
## then streams into the lantern wherever it is now.
func _mote_at(m: Dictionary, t: float, lantern: Vector2) -> Vector2:
	var p0: Vector2 = m["from"]
	var bow := 1.0 if m["j"] % 2 == 0 else -1.0
	if m.has("home"):
		var out: Vector2 = m["out"]
		var swing := p0 + out * SWIRL.x + Vector2(-out.y, out.x) * SWIRL.y * bow
		var v := clampf(t / MOTE_FLIGHT, 0.0, 1.0)
		var ev := v * v * (3.0 - 2.0 * v)
		return p0.lerp(swing, ev).lerp(swing.lerp(lantern, ev), ev)
	var p2: Vector2 = m["to"]
	var span := p2 - p0
	var p1 := (p0 + p2) / 2.0 + Vector2(-span.y, span.x).normalized() * 0.3 * span.length() * bow
	var u := clampf(t / MOTE_FLIGHT, 0.0, 1.0)
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	return p0.lerp(p1, e).lerp(p1.lerp(p2, e), e)


static func _mote_row(id: String, j: int) -> String:
	match id:
		"colour":
			return ["rose", "sky", "lime", "gold"][j % 4]
		"particles":
			return ["gold", "lime"][j % 2]
		"vsync", "resolution", "frame_rate":
			return ["sky", "ice"][j % 2]
	return "gold"


## A point `d` px along the border of a `size` screen (inset 2 px), clockwise from the top-left corner.
static func _border(d: float, size: Vector2) -> Vector2:
	var w := size.x - 4.0
	var h := size.y - 4.0
	if d < w:
		return Vector2(2.0 + d, 2.0)
	d -= w
	if d < h:
		return Vector2(2.0 + w, 2.0 + d)
	d -= h
	if d < w:
		return Vector2(2.0 + w - d, 2.0 + h)
	return Vector2(2.0, 2.0 + h - minf(d - w, h))


## The title screen's payoff (STORY.md 6, bar 15): LUXEL's luxels fly out of the lantern one after another and
## land lit, flickering like the title's; at `to` they go out through dim, ember and unlit, a ramp step each.
func _draw_luxels(ci: CanvasItem, lantern: Vector2, from: float, to: float) -> void:
	if _now < from or _now >= to:
		return
	if _lux.is_empty():
		var label := STORY.line("title.name", "LUXEL")
		_lux = LUX.cells(label, LUX.origin(label, SCREEN.x / 2.0, LUX_Y))
	var left := floori((to - _now) / RAMP_STEP) if to < 1e6 else 99
	for i in _lux.size():
		var t := _now - from - LUX_GAP * i
		if t < 0.0:
			continue
		var c: Dictionary = _lux[i]
		if t < LUX_FLIGHT:
			var bow := 1.0 if i % 2 == 0 else -1.0
			for back in [1, 0]:
				var p := _lux_at(lantern, c["c"], maxf(t - 0.04 * back, 0.0) / LUX_FLIGHT, bow).round()
				ci.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), _c("apricot" if back == 1 else "gold"))
			continue
		var state := LUX.FLASH if t < LUX_FLIGHT + 0.08 else LUX.flicker(i, _now)
		if left < 3:
			state = [LUX.UNLIT, LUX.EMBER, LUX.DIM][left]
		LUX.draw(ci, c["p"], state)


## When the last luxel has landed.
func _lux_built(from: float) -> float:
	return from + LUX_GAP * maxf(_lux.size() - 1, 0.0) + LUX_FLIGHT if not _lux.is_empty() else from + 1.8


## Out of the lantern on a bowed path, slowing as it lands.
func _lux_at(p0: Vector2, p2: Vector2, u: float, bow: float) -> Vector2:
	var span := p2 - p0
	var p1 := (p0 + p2) / 2.0 + Vector2(-span.y, span.x).normalized() * 0.25 * span.length() * bow
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	return p0.lerp(p1, e).lerp(p1.lerp(p2, e), e)


## A centred line that fades in and out through its palette ramp between `from` and `to`.
func _line(ci: CanvasItem, text: String, from: float, to: float, colour: String, y: int, scale: int) -> void:
	var col := _ramp(colour, from, to)
	if text == "" or col.a == 0.0:
		return
	_text(ci, text, Vector2(roundf(SCREEN.x / 2.0 - FONT.width(text, scale) / 2.0), y), col, scale)


## The ramp colour at `_now` for a line shown from `from` to `to`; transparent when it isn't showing.
func _ramp(colour: String, from: float, to: float) -> Color:
	var ramp: Array = RAMPS[colour]
	if _now < from or _now >= to:
		return Color(0, 0, 0, 0)
	var k := floori((_now - from) / RAMP_STEP)
	if to < 1e6:
		k = mini(k, floori((to - _now) / RAMP_STEP))
	return _c(ramp[mini(k, ramp.size() - 1)])


## PixelFont text with a night outline, plus the "%" glyph.
func _text(ci: CanvasItem, text: String, pos: Vector2, col: Color, scale := 1) -> void:
	FONT.draw(ci, text, pos, col, _c("night"), scale)
	for i in text.length():
		if text[i] != "%":
			continue
		var at := pos + Vector2(i * (FONT.W + 1) * scale, 0)
		for o in FONT.OUTLINE:
			_percent(ci, at + o * scale, _c("night"), scale)
		_percent(ci, at, col, scale)


func _percent(ci: CanvasItem, at: Vector2, col: Color, scale: int) -> void:
	for p in PERCENT:
		ci.draw_rect(Rect2(at + p * scale, Vector2.ONE * scale), col)


func _c(name: String) -> Color:
	return PALETTE.PAL[name]

