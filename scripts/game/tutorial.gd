extends Node
## Tutorial beats T1-T5 (design 12, STORY.md 4) on a run that started with start_run(true): the run is `safe` with
## the director paused; this node only watches the run's signals, spawns the scripted Snuffers and shows the tips.
## The run opens the first menu itself (TUTORIAL phase, gauge full, menu mode "tutorial"). Beat time is world time:
## it stops while the run is frozen (menu, pause).

signal finished

enum Beat { NONE, MOVE, LANTERN, SHARD, MENU, GO }

const STORY := preload("res://scripts/game/story/story_text.gd")
const SAVE := preload("res://scripts/game/save.gd")
const MOVE_SECS := 1.0 ## T1 is done after this much movement in total...
const MOVE_PX := 40.0 ## ...or this many px
const MOVE_PAUSE := 0.5 ## quiet gap between T1 and T2
const IDLE_PULSE := 6.0 ## idle this long in T1: the tip pulses
const T1_MAX := 8.0 ## T1 completes anyway after this long (failure-proof)
const SLOW_PULL := 0.7 ## the first shard's pull (s)
const PAIR_GAP := 2.5 ## T3: Snuffer pairs this often, from alternating sides...
const PAIRS_UNTIL := 6 ## ...until this many Snuffers have come (the gauge needs 6 light)
const NO_KILL := 8.0 ## no kill for this long: one Snuffer 50 px ahead of Wick
const AHEAD := 50.0
const EDGE_IN := 6.0 ## scripted Snuffers start this far inside the view edge, so the player sees them come
const GO_SECS := 4.0
const TIP_PRIORITY := 5
const TIP_HOLD := 30.0 ## a beat's tip outlasts the beat (the next beat's tip replaces it)

var run ## run.gd
var hud ## hud.gd
var menu ## settings_menu.gd
var beat: int = Beat.NONE
var _t := 0.0 ## world seconds in the current beat
var _move_t := 0.0
var _moved_px := 0.0
var _idle := 0.0
var _pulsed := false
var _done_at := -1.0 ## T1: beat time it was done (then MOVE_PAUSE)
var _since_kill := 0.0
var _pair_t := 0.0
var _side := 1.0
var _spawned := 0


## Starts the tutorial beats on a run that just started with start_run(true).
func start(r: Node2D, h: Node2D, m: Node2D) -> void:
	run = r
	hud = h
	menu = m
	_connect()
	if not Touch.mode_changed.is_connected(_on_touch_mode):
		Touch.mode_changed.connect(_on_touch_mode)
	_spawned = 0
	_side = 1.0
	run.gauge_revealed = false
	run.slow_next_pull(SLOW_PULL)
	_enter(Beat.MOVE)


## True while a tutorial beat is running.
func active() -> bool:
	return beat != Beat.NONE


## Ends the tutorial without finishing it (restart or title mid-tutorial): no `finished`, nothing saved.
func stop() -> void:
	if beat != Beat.NONE:
		_tip("", 0.0)
	beat = Beat.NONE


func _connect() -> void:
	for pair: Array in [[run.moved, _on_moved], [run.killed, _on_killed], [run.shard_landed, _on_shard_landed],
			[run.gauge_full, _on_gauge_full], [run.menu_closed, _on_menu_closed]]:
		var sig: Signal = pair[0]
		if not sig.is_connected(pair[1]):
			sig.connect(pair[1])


func _enter(b: int) -> void:
	beat = b
	_t = 0.0
	match b:
		Beat.MOVE:
			_move_t = 0.0
			_moved_px = 0.0
			_idle = 0.0
			_pulsed = false
			_done_at = -1.0
			_tip(STORY.line("tut.move"), TIP_HOLD)
		Beat.LANTERN:
			_since_kill = 0.0
			_tip(STORY.line("tut.lantern"), TIP_HOLD)
			_spawn(1, _edge_point(1.0))
		Beat.SHARD:
			_pair_t = 0.0
			_tip(STORY.line("tut.shard"), TIP_HOLD)
		Beat.MENU:
			_tip("", 0.0)
		Beat.GO:
			SAVE.set_tutorial_done() # every beat is taught once SUBTITLES sells: a death or quit from here still counts
			run.safe = false
			run.gauge_revealed = true
			run.director.paused = false
			_tip(STORY.line("tut.go"), GO_SECS)


func _process(delta: float) -> void:
	if beat == Beat.NONE:
		return
	if not run.tutorial_mode:
		stop() # a restart or the title replaced the tutorial run
		return
	if run.frozen:
		return
	_t += delta
	match beat:
		Beat.MOVE:
			_step_move(delta)
		Beat.LANTERN:
			_step_no_kill(delta)
		Beat.SHARD:
			_step_shard(delta)
		Beat.GO:
			if _t >= GO_SECS:
				_finish()


func _step_move(delta: float) -> void:
	if _done_at >= 0.0:
		if _t - _done_at >= MOVE_PAUSE:
			_enter(Beat.LANTERN)
		return
	var vel: Vector2 = run.player_vel
	if vel.length() > 10.0:
		_move_t += delta
		_idle = 0.0
	else:
		_idle += delta
	if _idle >= IDLE_PULSE and not _pulsed:
		_pulsed = true
		_tip(STORY.line("tut.move"), TIP_HOLD, true)
	if _move_t >= MOVE_SECS or _moved_px >= MOVE_PX or _t >= T1_MAX:
		_done_at = _t
		_tip("", 0.0)


func _step_no_kill(delta: float) -> void:
	_since_kill += delta
	if _since_kill >= NO_KILL:
		_since_kill = 0.0
		var vel: Vector2 = run.player_vel
		var ahead := vel.normalized() if vel.length() > 10.0 else Vector2.RIGHT
		_spawn(1, run.wick_feet() + ahead * AHEAD)


func _step_shard(delta: float) -> void:
	_step_no_kill(delta)
	_pair_t += delta
	if _pair_t >= PAIR_GAP and _spawned < PAIRS_UNTIL:
		_pair_t = 0.0
		_side = -_side
		_spawn(2, _edge_point(_side))


func _finish() -> void:
	beat = Beat.NONE
	SAVE.set_tutorial_done()
	finished.emit()


# ---- run signals --------------------------------------------------------------------------------------------

## The prompt names keys or a thumb: say it again in the new words while the move prompt is up.
func _on_touch_mode(_on: bool) -> void:
	if beat == Beat.MOVE and _done_at < 0.0:
		_tip(STORY.line("tut.move"), TIP_HOLD, _pulsed)


func _on_moved(px: float) -> void:
	if beat == Beat.MOVE:
		_moved_px += px


func _on_killed(_id: String, _pos: Vector2) -> void:
	_since_kill = 0.0
	if beat == Beat.LANTERN:
		_enter(Beat.SHARD)


func _on_shard_landed(_light: float, _fill: float) -> void:
	if beat != Beat.NONE:
		run.gauge_revealed = true


func _on_gauge_full() -> void:
	if beat in [Beat.MOVE, Beat.LANTERN, Beat.SHARD]:
		_enter(Beat.MENU)


func _on_menu_closed(_sale: Dictionary) -> void:
	if beat == Beat.MENU:
		_enter(Beat.GO)


# ---- helpers ------------------------------------------------------------------------------------------------

func _spawn(count: int, anchor: Vector2) -> void:
	_spawned += count
	run.spawn_scripted("snuffer", count, anchor)


## A point just inside the view's left (side -1) or right (side 1) edge, level with Wick.
func _edge_point(side: float) -> Vector2:
	var r: Rect2 = run.view_rect()
	var x := r.end.x - EDGE_IN if side > 0.0 else r.position.x + EDGE_IN
	return Vector2(x, clampf(run.wick_feet().y, r.position.y + EDGE_IN, r.end.y - EDGE_IN))


## A tip in the HUD's tip slot ("" clears it); `pulse` asks the HUD for its cream/stone pulse if it has one.
func _tip(text: String, secs: float, pulse := false) -> void:
	if hud == null:
		return
	if pulse and hud.get_method_argument_count("tip") >= 4:
		hud.tip(text, secs, TIP_PRIORITY, true)
	else:
		hud.tip(text, secs, TIP_PRIORITY)
