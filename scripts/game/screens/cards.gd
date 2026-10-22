extends Node2D
## Pause, death and results cards (STORY.md 7, design 11 and 13); emits action("resume" | "restart" | "title").
## Each card takes its own keys while it is open and closes itself before it emits. Pause and death go through
## LANGUAGE while it lasts (two menus after its sale; the gibberish is the joke); the results come after the run,
## when LANGUAGE has long worn off (or the ending gave it back).

signal action(name: String)

enum Card { NONE, PAUSE, DEATH, RESULTS }

const N := preload("res://scripts/game/ui/narration.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const SAVE := preload("res://scripts/game/save.gd")
const TAP := preload("res://scripts/game/ui/tap.gd")
const PAL: Dictionary = N.PAL
const CX := 160.0
const FADE := 0.3 ## the card's text climbs its ramp
const PAUSE_PANEL := Rect2(72, 62, 176, 46)
const DEATH_PANEL := Rect2(56, 42, 208, 86)
const RESULTS_PANEL := Rect2(70, 100, 180, 58) ## below Wick, the letterbox still on (STORY.md 7)
const TITLE_CUE_AFTER := 2.0 ## the title cue fades in quietly under the results panel
const KEYS_SLOT := "results_keys" ## the results' key line sits in the letterbox's bottom bar, so the narration draws it
const BUTTON_GAP := 10.0 ## px between touch buttons (wider than twice the hit growth, so no two hit areas meet)
const BUTTON_Y := {Card.PAUSE: 89.0, Card.DEATH: 111.0, Card.RESULTS: 167.0} ## the touch buttons' top, where the key line was

var run ## run.gd (shop for LANGUAGE, fx for the sounds)
var card: int = Card.NONE
var _stats := {}
var _best := ""
var _new_best := false
var _quip := ""
var _t := 0.0
var _opened_frame := -1
var _cue_started := false
var _tap := TAP.new() ## touch: reads taps on the open card's buttons
var _items: Array[Dictionary] = [] ## the open card's touch buttons: {rect, label, action}
var _held := -1 ## the button a finger is down on (-1: none)


func _ready() -> void:
	Touch.mode_changed.connect(_on_touch_mode)


## Keeps the run.
func setup(r: Node2D) -> void:
	run = r
	visible = false


## Shows the pause card.
func pause() -> void:
	_open(Card.PAUSE)
	_sfx("pause")


## Shows the death card with the run's stats and the quip `quip_id` (death.<setting_id> or death.default_n).
## `best` and `new_best` come from main after SAVE.submit(stats); without them the card reads the save itself.
func death(stats: Dictionary, quip_id: String, best := {}, new_best := false) -> void:
	_stats = stats
	_quip = STORY.line(quip_id, STORY.line("death.default_1"))
	_set_best(stats, best, new_best)
	_open(Card.DEATH)


## Shows the results card after the ending.
func results(stats: Dictionary, best: Dictionary, new_best: bool) -> void:
	_stats = stats
	_set_best(stats, best, new_best)
	_cue_started = false
	_open(Card.RESULTS)
	_sync_keys()


## Hides any card (ARCHITECTURE.md's hide(): `hide` is CanvasItem's).
func close() -> void:
	if card == Card.RESULTS and get_node_or_null("%Narration") != null:
		get_node("%Narration").unsay(KEYS_SLOT)
		get_node("%Narration").set_buttons([])
	card = Card.NONE
	_tap.disarm()
	visible = false


## True while a card is up.
func is_open() -> bool:
	return card != Card.NONE


func _open(c: int) -> void:
	card = c
	_t = 0.0
	_opened_frame = Engine.get_process_frames()
	_items = _make_buttons()
	_held = -1
	_tap.arm()
	visible = true
	queue_redraw()


## The card's touch buttons, centred in a row at BUTTON_Y: the same actions as its keys.
func _make_buttons() -> Array[Dictionary]:
	var specs: Array = []
	match card:
		Card.PAUSE:
			specs = [["button.resume", "resume"], ["button.restart", "restart"], ["button.title", "title"]]
		Card.DEATH:
			specs = [["button.again", "restart"], ["button.title", "title"]]
		Card.RESULTS:
			specs = [["button.play_again", "restart"], ["button.title", "title"]]
	var items: Array[Dictionary] = []
	var width := BUTTON_GAP * maxf(specs.size() - 1, 0)
	for spec: Array in specs:
		items.append({"label": STORY.line(spec[0]), "action": spec[1]})
		width += N.button_size(items[-1]["label"]).x
	var x := roundf(CX - width / 2.0)
	for item: Dictionary in items:
		var size := N.button_size(item["label"])
		item["rect"] = Rect2(Vector2(x, BUTTON_Y[card]), size)
		x += size.x + BUTTON_GAP
	return items


## The results' bottom bar shows the key line, or the buttons on a touch screen (the narration draws both).
func _sync_keys() -> void:
	var narration := get_node_or_null("%Narration")
	if narration == null or card != Card.RESULTS:
		return
	if Touch.active:
		narration.unsay(KEYS_SLOT)
		narration.set_buttons(_items, _held)
	else:
		narration.say(STORY.lines("results.keys"), "cream", 3600.0, -1.0, 1, KEYS_SLOT)
		narration.set_buttons([])


func _on_touch_mode(_on: bool) -> void:
	if card == Card.NONE:
		return
	queue_redraw()
	_sync_keys()


## The button under the finger that is down (the hit area), or -1.
func _button_at(at: Vector2) -> int:
	for i in _items.size():
		if N.button_hit(_items[i]["rect"]).has_point(at):
			return i
	return -1


func _set_best(stats: Dictionary, best: Dictionary, new_best: bool) -> void:
	if best.is_empty() and not new_best:
		best = SAVE.load_best()
		new_best = not best.is_empty() and best.get("time") == stats.get("time") \
			and best.get("sold") == stats.get("sold") and best.get("done") == stats.get("done")
	_new_best = new_best
	var line := STORY.best_line(_as_record(stats) if new_best else best, SAVE.gamer)
	_best = "NEW " + line if new_best else line


func _as_record(stats: Dictionary) -> Dictionary:
	return {"done": stats.get("done", false), "time": stats.get("time", 0.0), "sold": stats.get("sold", 0)}


func _process(delta: float) -> void:
	if card == Card.NONE:
		return
	_t += delta
	if card == Card.RESULTS and not _cue_started and _t >= TITLE_CUE_AFTER:
		_cue_started = true
		run.fx.title(true)
	var held := _button_at(_tap.held()) if Touch.active else -1
	if held != _held:
		_held = held
		queue_redraw()
		_sync_keys()
	if _t <= FADE + delta:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if card == Card.NONE:
		return
	var key := event as InputEventKey
	if key == null:
		var i := _button_at(_tap.feed(event, self))
		if i >= 0 and Touch.active and Engine.get_process_frames() != _opened_frame:
			var choice: String = _items[i]["action"]
			get_viewport().set_input_as_handled()
			close()
			action.emit(choice)
		return
	if not key.pressed or key.echo:
		return
	if Engine.get_process_frames() == _opened_frame:
		return # the press that opened this card
	var choice := _choice(key.keycode)
	if choice != "":
		get_viewport().set_input_as_handled()
		close()
		action.emit(choice)


## The action for `keycode` on the open card ("" = none). Esc does nothing on the pause card (design 11).
func _choice(keycode: int) -> String:
	match card:
		Card.PAUSE:
			if keycode in [KEY_SPACE, KEY_P]:
				return "resume"
			if keycode == KEY_R:
				return "restart"
			if keycode == KEY_Q:
				return "title"
		Card.DEATH, Card.RESULTS:
			if keycode in [KEY_SPACE, KEY_R]:
				return "restart"
			if keycode == KEY_ESCAPE:
				return "title"
	return ""


# ---- drawing ------------------------------------------------------------------------------------------------

func _draw() -> void:
	match card:
		Card.PAUSE:
			_draw_pause()
		Card.DEATH:
			_draw_death()
		Card.RESULTS:
			_draw_results()


func _draw_pause() -> void:
	N.panel(self, PAUSE_PANEL)
	_line(_txt(STORY.line("pause.title")), 70, "gold", 2)
	if Touch.active:
		_draw_buttons()
	else:
		_line(_txt(STORY.line("pause.keys")), 92, "cream")


func _draw_death() -> void:
	N.panel(self, DEATH_PANEL)
	_line(_txt(STORY.line("death.title")), 50, "coral", 2)
	_line(_txt(_quip), 66, "stone")
	_line(_txt(_stat_line()), 80, "cream")
	_line(_txt("SOLD %d OF %d SETTINGS" % [int(_stats.get("sold", 0)), STORY.SETTINGS_TOTAL]), 90, "stone")
	if _best != "":
		_line(_txt(_best), 100, "lime" if _new_best else "mauve")
	if Touch.active:
		_draw_buttons()
	else:
		_line(_txt(STORY.line("death.keys")), 116, "cream")


func _draw_results() -> void:
	var spills: int = run.player.spills if run != null and run.get("player") != null else 0
	N.panel(self, Rect2(RESULTS_PANEL.position, RESULTS_PANEL.size + Vector2(0, 12 if spills > 0 else 0)))
	_line(STORY.line("results.title"), 106, "gold")
	_line(_stat_line(), 118, "cream")
	_line(STORY.line("results.line"), 130, "stone")
	if _best != "":
		_line(_best, 142, "lime" if _new_best else "mauve")
	if spills > 0:
		_line(STORY.line("results.lantern_saves", "SAVED BY THE LANTERN x%d") % spills, 154, "gold")
	if get_node_or_null("%Narration") == null:
		if Touch.active:
			_draw_buttons()
		else:
			_line(STORY.line("results.keys"), 166, "cream")


func _draw_buttons() -> void:
	for i in _items.size():
		N.button(self, _items[i]["rect"], _items[i]["label"], i == _held)


func _stat_line() -> String:
	return "TIME %s   LV %d   KILLS %d" % [STORY.clock(_stats.get("time", 0.0)), int(_stats.get("level", 1)),
		int(_stats.get("kills", 0))]


func _line(s: String, y: float, colour: String, scale := 1) -> void:
	N.centred(self, s, CX, y, N.ramp(colour, _t / FADE), scale)


## `s` through LANGUAGE (the shop's cipher while it lasts).
func _txt(s: String) -> String:
	return run.shop.txt(s) if run != null and run.shop != null else s


func _sfx(id: String) -> void:
	if run == null or run.fx == null:
		return
	var db: Dictionary = run.fx.get_script().get_script_constant_map().get("SFX_DB", {})
	if db.has(id):
		run.fx.play(id, 0.0)
