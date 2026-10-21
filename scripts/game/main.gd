extends Node2D
## The whole game in one scene (ARCHITECTURE.md 3, 4.1, 5.1): the flow state machine, input routing to the
## active screen, the wiring of main.tscn, and the debug args after `--` (run, tutorial, at=<s>, lab=<id>,
## seed=<n>, swell, closing, blast, relight, pixels, ending). Debug builds: keys 1-6 / 0 drop enemies, F5 fills the gauge (run.gd).
## Keys: the title, intro, cards and menu take their own keys while open (they mark them handled); main reads
## Esc/P (pause) and hold-R in play, and the ending's presses unless the ending has `key(event)` itself.

signal flow_changed(state: int)

enum Flow { TITLE, INTRO, RUN, PAUSE, DEAD, ENDING, RESULTS }

const SAVE := preload("res://scripts/game/save.gd")
const SHOP := preload("res://scripts/game/shop/shop.gd")
const RUN_GD := preload("res://scripts/game/run/run.gd")
const FX_GD := preload("res://scripts/game/fx/settings_fx.gd")
const SHARD_AUDIO_GD := preload("res://scripts/game/fx/shard_audio.gd")
const TUTORIAL_GD := preload("res://scripts/game/tutorial.gd")
const HUD_GD := preload("res://scripts/game/ui/hud.gd")
const MENU_GD := preload("res://scripts/game/ui/settings_menu.gd")
const NARRATION_GD := preload("res://scripts/game/ui/narration.gd")
const TITLE_GD := preload("res://scripts/game/screens/title.gd")
const INTRO_GD := preload("res://scripts/game/screens/intro.gd")
const CARDS_GD := preload("res://scripts/game/screens/cards.gd")
const ENDING_GD := preload("res://scripts/game/screens/ending.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const DEAD_CARD := 0.8 # s from Wick's fall to the WICK FELL card
const HOLD_R := 0.5 # s of R held in play to restart
const DEBUG_SAVE := "user://low_settings_debug.cfg" # debug runs (args) save here, never in the player's file
const PAUSABLE: Array[int] = [RUN_GD.Phase.TUTORIAL, RUN_GD.Phase.MAIN, RUN_GD.Phase.CLOSING, RUN_GD.Phase.PIXELS]
const FINALE_SAY := 2.5 # s each finale narration line stays (STORY.md 5: bottom centre, ice, no box)
const STOP_SAY := 30.0 # s a stop's line could stay: the menu opening clears it first
## The finale's narration by run.pixels_stage (0 = the first pixel sold, 1-3 at 70/40/15% left, 4 at 1% left).
const FINALE_STAGES: Array[String] = ["finale.pixel_first", "finale.stage1", "finale.stage2", "finale.stage3",
		"finale.last_pixel"]

var state: int = Flow.TITLE
var args := PackedStringArray() ## debug args after `--`
var shop: SHOP ## created here, shared by the run, the menu and the HUD
var last_stats := {} ## the last run's summary (death or DISPLAY: OFF)
var new_best := false
var debug_run := false ## a debug arg started the run: nothing is written to the save

var _dead_t := -1.0
var _hold_r := 0.0
var _r_released := false ## R was seen up since the run started: a card's R press can't also count as a hold
var _ending_presses := 0

@onready var island: Island = %Island
@onready var run: RUN_GD = %Run
@onready var fx: FX_GD = %Fx
@onready var shard_audio: SHARD_AUDIO_GD = %ShardAudio
@onready var tutorial_node: TUTORIAL_GD = %Tutorial
@onready var hud: HUD_GD = %Hud
@onready var top: Node2D = %Top
@onready var menu: MENU_GD = %Menu
@onready var title: TITLE_GD = %Title
@onready var intro: INTRO_GD = %Intro
@onready var cards: CARDS_GD = %Cards
@onready var ending: ENDING_GD = %Ending
@onready var narration: NARRATION_GD = %Narration


func _ready() -> void:
	args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("seed="):
			seed(int(a.trim_prefix("seed=")))
	Display.fill_screen(self, true)
	shop = SHOP.new()
	run.top = top
	run.setup(island, fx, shard_audio, shop, menu, hud)
	fx.setup(run)
	shard_audio.setup(fx)
	menu.setup(shop, run)
	hud.setup(run, shop)
	title.setup(run)
	intro.setup(run, narration)
	cards.setup(run)
	ending.setup(run, narration)
	run.died.connect(_on_died)
	run.display_off_reached.connect(_on_display_off)
	run.closing_started.connect(_on_closing_started)
	run.menu.closed.connect(_on_finale_sale_closed) # after the run's own connection: it has set the gap by then
	run.pixels_stage.connect(_on_pixels_stage)
	run.finale_line.connect(_on_finale_line)
	run.stop_line.connect(_on_stop_line)
	run.stop_cleared.connect(_on_stop_cleared)
	title.start.connect(_on_title_start)
	intro.finished.connect(_on_intro_finished)
	tutorial_node.finished.connect(_on_tutorial_finished)
	ending.finished.connect(_on_ending_finished)
	cards.action.connect(_on_card_action)
	_boot()


## The first screen: the title, or a debug jump.
func _boot() -> void:
	for a in args:
		if a in ["run", "tutorial", "swell", "closing", "blast", "relight", "pixels", "ending"] or a.begins_with("lab=") \
				or a.begins_with("at="):
			debug_run = true
	if debug_run and SAVE.path == SAVE.PATH:
		SAVE.path = DEBUG_SAVE # neither the best record nor tutorial_done reach the player's save
	if args.has("tutorial"):
		_start_intro()
		return
	for jump in ["swell", "closing", "blast", "relight", "pixels", "ending"]:
		if args.has(jump):
			start_run(false)
			run.debug_jump(jump)
			if jump == "ending":
				narration.clear() # the jump's burst of finale lines would sit over the ending's first seconds
			return
	if args.has("run") or _arg("lab=") != "" or _arg("at=") != "":
		start_run(false)
		return
	to_title()


## Starts a run with a full reset; with `tutorial` the run starts in TUTORIAL and the tutorial drives it.
func start_run(tutorial: bool) -> void:
	_close_screens()
	_dead_t = -1.0
	_hold_r = 0.0
	_r_released = false
	fx.title(false)
	_set_state(Flow.RUN)
	run.start_run(tutorial)
	if tutorial:
		tutorial_node.start(run, hud, menu)


## Restarts in place (nothing reloads): a new run with no intro and no tutorial.
func restart() -> void:
	start_run(false)


## Goes back to the title screen and shows the best record.
func to_title() -> void:
	_close_screens()
	_dead_t = -1.0
	run.idle()
	hud.set_shown(false)
	fx.title(true)
	fx.drone_to(-80.0, 0.0) # quitting from the PIXELS countdown: the finale drone stops with the run
	_set_state(Flow.TITLE)
	title.open(SAVE.load_best())


func _start_intro() -> void:
	_close_screens()
	run.idle()
	hud.set_shown(false)
	_set_state(Flow.INTRO)
	intro.play()


func _set_state(s: int) -> void:
	state = s
	flow_changed.emit(s)


func _close_screens() -> void:
	title.close()
	cards.close()
	if narration.bars_on():
		narration.letterbox(false, 0.0) # the ending leaves the bars in under the results card
	narration.clear()
	if run.paused:
		run.set_paused(false)


func _arg(prefix: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return ""


# ---- flow events ------------------------------------------------------------------------------------------------

func _on_title_start() -> void:
	if state != Flow.TITLE:
		return
	if SAVE.tutorial_done():
		start_run(false)
	else:
		_start_intro()


func _on_intro_finished() -> void:
	if state == Flow.INTRO:
		start_run(true)


func _on_tutorial_finished() -> void:
	run.end_tutorial()
	SAVE.set_tutorial_done()


## CONFIRM SALES sold: the finale opens (STORY.md 5).
func _on_closing_started() -> void:
	narration.say_id("finale.open", "ice", FINALE_SAY)


## A finale self-sale closed: the play gap before the next one shortens with the sale's pace (the menu scales its own
## times, settings_fx.finale_pace). The run has already set that gap; the CONFIRM and PIXELS menus pace at 1.
func _on_finale_sale_closed(_sale: Dictionary) -> void:
	if run.phase == RUN_GD.Phase.CLOSING or run.phase == RUN_GD.Phase.AUTO_SALE:
		run._gap_len *= fx.finale_pace(run._auto_done + 1)


## The finale story's other lines (P8: the swell, the blast, the relight, the rest of the dark), when the run says.
func _on_finale_line(id: String, colour: String, secs: float) -> void:
	narration.say_id(id, colour, secs)


## P8b, a stop before a decision: the big centred problem line (scale 2) and the answer under it, in their own
## slots; they hold until the menu opens (_on_stop_cleared).
func _on_stop_line(id: String, colour: String, scale: int, y: float) -> void:
	narration.say_id(id, colour, STOP_SAY, y, scale, "stop%d" % scale)


func _on_stop_cleared() -> void:
	narration.unsay("stop1")
	narration.unsay("stop2")


func _on_pixels_stage(stage: int) -> void:
	if stage >= 0 and stage < FINALE_STAGES.size():
		narration.say_id(FINALE_STAGES[stage], "ice", FINALE_SAY)


func _on_died(stats: Dictionary) -> void:
	last_stats = stats
	new_best = false if debug_run else SAVE.submit(stats)
	_dead_t = DEAD_CARD


func _on_display_off(stats: Dictionary) -> void:
	last_stats = stats
	new_best = false if debug_run else SAVE.submit(stats)
	_ending_presses = 0
	_set_state(Flow.ENDING)
	ending.play(stats)


func _on_ending_finished() -> void:
	if state != Flow.ENDING:
		return
	_set_state(Flow.RESULTS)
	cards.results(last_stats, SAVE.load_best(), new_best)


func _on_card_action(action: String) -> void:
	match action:
		"resume":
			if state == Flow.PAUSE:
				_resume()
		"restart":
			if state in [Flow.PAUSE, Flow.DEAD, Flow.RESULTS]:
				restart()
		"title":
			if state in [Flow.PAUSE, Flow.DEAD, Flow.RESULTS]:
				to_title()


func _pause() -> void:
	_hold_r = 0.0
	hud.restart_ring(0.0)
	run.set_paused(true)
	_set_state(Flow.PAUSE)
	cards.pause()


func _resume() -> void:
	cards.close()
	run.set_paused(false)
	_set_state(Flow.RUN)


## The death quip: the last setting sold (death.<id>) when the story has a line for it, else a default.
func _death_quip() -> String:
	return STORY.death_quip_id(String(last_stats.get("last", "")))


# ---- per frame and keys -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _dead_t >= 0.0:
		_dead_t -= delta
		if _dead_t < 0.0 and state == Flow.RUN:
			_set_state(Flow.DEAD)
			cards.death(last_stats, _death_quip(), SAVE.load_best(), new_best)
	_hold_restart(delta)


## Hold R 0.5 s in play restarts (a ring fills over Wick). R must have been up since the run started, so the R
## that restarted from a card (or a hold that just restarted) needs a fresh press.
func _hold_restart(delta: float) -> void:
	var r_down := Input.is_key_pressed(KEY_R)
	if not r_down:
		_r_released = true
	var holding := state == Flow.RUN and PAUSABLE.has(run.phase) and r_down and _r_released and not run.autopilot
	if not holding:
		if _hold_r > 0.0:
			_hold_r = 0.0
			hud.restart_ring(0.0)
		return
	_hold_r += delta
	hud.restart_ring(minf(_hold_r / HOLD_R, 1.0))
	if _hold_r >= HOLD_R:
		restart()


## Losing focus mid-run (alt-tab, or a click outside the itch.io iframe: the web canvas blurs) opens the pause
## card, since Godot drops the held keys and Wick would stand still while the world plays on.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if not is_node_ready() or OS.has_feature("movie") or run.autopilot:
		return
	if state == Flow.RUN and PAUSABLE.has(run.phase) and not menu.is_open():
		_pause()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode
	match state:
		Flow.RUN:
			if (code == KEY_ESCAPE or code == KEY_P) and PAUSABLE.has(run.phase) and not menu.is_open():
				_pause()
			else:
				return
		Flow.ENDING:
			if ending.has_method("key"):
				ending.call("key", key)
			else:
				_ending_presses += 1
				if _ending_presses >= 2:
					ending.skip()
		_:
			return
	get_viewport().set_input_as_handled()

