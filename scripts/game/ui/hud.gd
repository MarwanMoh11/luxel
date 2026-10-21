extends Node2D
## HUD (design 13) on CanvasLayer 4, under the screen effects so the finale degrades it: hearts, lantern gauge,
## timer, tips, warning pips, nags, restart ring. Hugs Display.screen_rect(); hides each piece from shop.lv().
## Last Light palette only. setup() connects the run's debut, formation_coming and shard_landed signals itself.

const STORY := preload("res://scripts/game/story/story_text.gd")
const TUTORIAL_PHASE := 0 ## run.gd Phase.TUTORIAL (not preloaded, so the HUD loads without the run)
const MENU := preload("res://scripts/game/ui/settings_menu.gd")
const PAL: Dictionary = preload("res://scripts/game/ui/palette.gd").PAL
const TIP_EVERY := 8.0 ## a general tip starts this often once the tutorial is over
const TIP_SHOW := 5.0 ## ...and shows this long
const TIP_FADE := 0.3
const TIP_COUNT := 8 ## tip.1 .. tip.8
const DEBUT_TIP := 6.0
const FORMATION_TIP := 3.0
const RAMP: Array[String] = ["dusk", "mauve", "stone", "cream"] ## tip text fades up these
const PULSE := 0.8 ## a pulsing tip swaps cream and stone this often (the idle T1 reminder)
const PIP_TIME := 1.5 ## seconds a warning pip shows
const PIP_COLOUR := {"formation": "coral", "owl": "sky", "magpie": "gold"}
const NAG_TIME := 0.6
const FORM_NAG_TIME := 2.0 ## a sale's new lantern form, called out over Wick
const UP_NAG := "UP: STUCK"
const UP_NAG_TIME := 0.15 ## the stuck nag fades this soon after Up works again (it is renewed every frame)
const RELIGHT_KEY_Y := 14.0 ## px under Wick's body centre: the relight's SPACE prompt
const RELIGHT_BLINK := 0.25 ## s the prompt's key cap stays lit, then dim
const GAUGE_W := 60
const TICK_TIME := 0.12
const BIG_TICK_TIME := 0.25
const RING_R := 11.0
const RING_DOTS := 28
const HEART: Array[Rect2] = [Rect2(0, 1, 5, 2), Rect2(1, 0, 1, 1), Rect2(3, 0, 1, 1), Rect2(1, 3, 3, 1),
		Rect2(2, 4, 1, 1)]
const LANTERN: Array[Rect2] = [Rect2(1, 0, 3, 1), Rect2(0, 1, 5, 1), Rect2(0, 2, 1, 4), Rect2(4, 2, 1, 4),
		Rect2(0, 6, 5, 1)]

var run ## run.gd
var shop ## shop.gd

var _tip := "" ## the explicit tip (tutorial, debut, formation)
var _tip_t := 0.0 ## seconds it has left
var _tip_len := 0.0
var _tip_priority := -1
var _tip_pulse := false
var _tip_clock := 0.0 ## time since the general tips started
var _pips: Array[Dictionary] = [] ## {pos, kind, t}
var _nag := ""
var _nag_t := 0.0
var _nag_colour := "coral"
var _tick_t := 0.0
var _tick_big := false
var _ring := 0.0
var _relight_blink := 0.0


## Keeps the run and the shop it reads; listens for debuts, formations and landed shards.
func setup(r: Node2D, s: RefCounted) -> void:
	run = r
	shop = s
	if run == null:
		return
	if run.has_signal("debut"):
		run.debut.connect(func(id: String) -> void: tip(STORY.line("tip." + id), DEBUT_TIP, 1))
	if run.has_signal("formation_coming"):
		run.formation_coming.connect(func(anchor: Vector2) -> void:
			warn(anchor, "formation")
			tip(STORY.line("tip.formation", "SOMETHING IS COMING."), FORMATION_TIP, 2))
	if run.has_signal("menu_closed"):
		run.menu_closed.connect(_on_menu_closed)
	if run.has_signal("shard_landed"):
		run.shard_landed.connect(func(light: float, _fill: float) -> void: gauge_tick(light >= 3.0))


## Shows or hides the whole HUD (ARCHITECTURE.md's show(on): `show` is CanvasItem's).
func set_shown(on: bool) -> void:
	visible = on


## Shows a tip line for `secs` (a higher `priority` replaces a lower one); gone once TIPS is sold. "\n" = 2 lines.
## An empty `text` fades the current tip out. `pulse` swaps cream and stone every 0.8 s (a reminder).
func tip(text: String, secs: float, priority := 0, pulse := false) -> void:
	if text == "":
		if _tip_t > TIP_FADE:
			_tip_len = TIP_FADE + (_tip_len - _tip_t) # keep the fade-in age, fade out from now
			_tip_t = TIP_FADE
		return
	if _tip_t > 0.0 and priority < _tip_priority:
		return
	_tip = text
	_tip_t = secs
	_tip_len = secs
	_tip_priority = priority
	_tip_pulse = pulse
	queue_redraw()


## A warning pip at the screen edge toward `world_pos`; kind "formation", "owl" or "magpie".
func warn(world_pos: Vector2, kind: String) -> void:
	for p in _pips:
		if p["kind"] == kind and p["pos"].distance_to(world_pos) < 24.0:
			p["pos"] = world_pos
			p["t"] = PIP_TIME
			return
	_pips.append({"pos": world_pos, "kind": kind, "t": PIP_TIME})


## A line over Wick for `secs`: the UP: STUCK nag (coral), or a sale's new lantern form (gold).
func nag(text: String, secs := NAG_TIME, colour := "coral") -> void:
	_nag = text
	_nag_t = secs
	_nag_colour = colour


## A sale that lit a lantern form (the menu's sale["forms"]): "NEW: FIREFLY" over Wick. None once the run closes.
func _on_menu_closed(sale: Dictionary) -> void:
	if bool(sale.get("buy_back", false)): # the setting that came back, in gold over Wick: MOVEMENT: SNAPPY
		nag("%s: %s" % [sale.get("name", ""), sale.get("value", "")], FORM_NAG_TIME, "gold")
		return
	var forms: Array = sale.get("forms", [])
	if not forms.is_empty() and not (run.has_method("closing") and run.closing()):
		nag(STORY.form_tag(forms), FORM_NAG_TIME, "gold")


## The gauge ticks for a landed shard (a big one flashes the whole bar).
func gauge_tick(big: bool) -> void:
	_tick_t = BIG_TICK_TIME if big else TICK_TIME
	_tick_big = big


## The hold-R restart ring, 0..1 (0 hides it).
func restart_ring(progress: float) -> void:
	_ring = clampf(progress, 0.0, 1.0)


## Back to a fresh run: no tip, pips, nag or ring.
func reset() -> void:
	_tip = ""
	_tip_t = 0.0
	_tip_priority = -1
	_tip_pulse = false
	_tip_clock = 0.0
	_pips.clear()
	_nag_t = 0.0
	_tick_t = 0.0
	_ring = 0.0


func _process(delta: float) -> void:
	_tip_t = maxf(_tip_t - delta, 0.0)
	if _tip_t <= 0.0:
		_tip_priority = -1
	if run and not run.frozen and not _in_tutorial():
		_tip_clock += delta
	for p in _pips:
		p["t"] -= delta
	_pips.assign(_pips.filter(func(p: Dictionary) -> bool: return p["t"] > 0.0))
	_nag_t = maxf(_nag_t - delta, 0.0)
	_tick_t = maxf(_tick_t - delta, 0.0)
	_relight_blink += delta
	_check_up_key()
	queue_redraw()


## The flaky Up key held in play while it cuts out: "UP: STUCK" over Wick.
func _check_up_key() -> void:
	if run == null or shop == null or shop.lv("up_key") == 0 or run.frozen or run.autopilot:
		return
	if run.player == null or not run.player.has_method("up_dead") or not run.player.up_dead():
		return
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		nag(UP_NAG, UP_NAG_TIME)


func _draw() -> void:
	if run == null or shop == null:
		return
	var screen := Display.screen_rect()
	if shop.lv("hearts") == 0 and run.player:
		_draw_hearts(screen.position + Vector2(4, 4))
	if shop.lv("gauge") == 0 and (run.gauge_revealed or not _in_tutorial()):
		_draw_gauge(screen.position.x + screen.size.x / 2.0, screen.position.y + 4)
	if shop.lv("timer") == 0 and not _in_tutorial():
		var secs := floori(run.run_time)
		var clock := "%d:%02d" % [floori(secs / 60.0), secs % 60]
		PixelFont.draw(self, clock, Vector2(screen.end.x - 4 - PixelFont.width(clock), screen.position.y + 4),
				PAL["cream"], PAL["night"])
	if shop.lv("warnings") == 0:
		for p in _pips:
			_draw_pip(p, screen)
	_draw_tip(screen)
	_draw_world_bits()


func _draw_hearts(at: Vector2) -> void:
	for i in int(run.player.max_hp):
		var x := at + Vector2(i * 7, 0)
		draw_rect(Rect2(x - Vector2(1, 1), Vector2(7, 7)), PAL["night"])
		var full: bool = i < int(run.player.hp)
		for r in HEART:
			draw_rect(Rect2(x + r.position, r.size), PAL["coral"] if full else PAL["plum"])


## Lantern icon, LV n and the 60x3 bar (gold fill, cream tick flash), centred on `cx`.
func _draw_gauge(cx: float, y: float) -> void:
	var lv := _txt("LV %d" % int(run.prog.level if run.prog else 1))
	var w := 5 + 3 + PixelFont.width(lv) + 4 + GAUGE_W + 2
	var x := roundf(cx - w / 2.0)
	var fill := clampf(float(run.prog.fill()) if run.prog else 0.0, 0.0, 1.0)
	for r in LANTERN:
		draw_rect(Rect2(Vector2(x, y - 1) + r.position, r.size), PAL["mauve"])
	draw_rect(Rect2(x + 1, y + 1, 3, 4), PAL["gold"] if fill > 0.0 else PAL["plum"])
	x += 8
	PixelFont.draw(self, lv, Vector2(x, y), PAL["cream"], PAL["night"])
	x += PixelFont.width(lv) + 4
	draw_rect(Rect2(x, y, GAUGE_W + 2, 5), PAL["night"])
	draw_rect(Rect2(x + 1, y + 1, GAUGE_W, 3), PAL["dusk"])
	var px := roundf(GAUGE_W * fill)
	var flash := _tick_t > 0.0 and _tick_big
	draw_rect(Rect2(x + 1, y + 1, px, 3), PAL["cream"] if flash else PAL["gold"])
	if _tick_t > 0.0 and px > 0:
		draw_rect(Rect2(x + px, y, 1, 5), PAL["cream"])


## A 3x3 arrow at the screen edge pointing at an off-screen threat (blinking).
func _draw_pip(p: Dictionary, screen: Rect2) -> void:
	var s := _to_screen(p["pos"])
	var inner := screen.grow(-4)
	if inner.has_point(s) or fmod(p["t"], 0.3) < 0.1:
		return
	var at := s.clamp(inner.position, inner.end)
	var d := (s - at).normalized()
	var colour: Color = PAL[PIP_COLOUR.get(p["kind"], "coral")]
	var tip_px := (at + d * 1.5).round()
	draw_rect(Rect2(at.round() - Vector2(1, 1), Vector2(3, 3)), PAL["night"])
	draw_rect(Rect2(at.round(), Vector2(1, 1)), colour)
	draw_rect(Rect2(tip_px, Vector2(1, 1)), colour)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2((at + d.orthogonal() * side).round(), Vector2(1, 1)), colour)


## The tip line: an explicit tip, else a general one every TIP_EVERY s (after the tutorial; gone once TIPS is sold).
func _draw_tip(screen: Rect2) -> void:
	var text := ""
	var age := 0.0
	var left := 0.0
	if _tip_t > 0.0:
		text = _tip
		age = _tip_len - _tip_t
		left = _tip_t
	elif not _in_tutorial() and not run.frozen and _tip_clock > TIP_EVERY:
		var k := floori(_tip_clock / TIP_EVERY)
		age = _tip_clock - k * TIP_EVERY
		left = TIP_SHOW - age
		if left > 0.0:
			text = STORY.line("tip.%d" % ((k - 1) % TIP_COUNT + 1))
	if text == "" or (shop.lv("tips") > 0 and not _in_tutorial()):
		return
	var level := clampf(minf(age, left) / TIP_FADE, 0.0, 1.0)
	if level <= 0.0:
		return
	var ink: Color = PAL[RAMP[mini(1 + floori(level * (RAMP.size() - 1)), RAMP.size() - 1)]]
	if _tip_t > 0.0 and _tip_pulse and level >= 1.0 and fmod(age, PULSE * 2.0) >= PULSE:
		ink = PAL["stone"]
	var lines := _txt(text).split("\n")
	var cx := screen.position.x + screen.size.x / 2.0
	var y := screen.end.y - 10 - (lines.size() - 1) * 8
	var w := 0
	for line in lines:
		w = maxi(w, PixelFont.width(line))
	var box := Rect2(roundf(cx - w / 2.0) - 4, y - 3, w + 8, lines.size() * 8 + 3)
	draw_rect(box.grow(1), PAL["night"])
	draw_rect(box, PAL["mauve"])
	draw_rect(box.grow(-1), PAL["dusk"])
	for i in lines.size():
		MENU.draw_text_at(self, lines[i], Vector2(roundf(cx - PixelFont.width(lines[i]) / 2.0), y + i * 8), ink,
				PAL["dusk"])


## The nag over Wick and the restart ring around him.
func _draw_world_bits() -> void:
	if (_nag_t <= 0.0 and _ring <= 0.0) or not run.has_method("wick_body"):
		return
	var wick := _to_screen(run.wick_body())
	if _nag_t > 0.0:
		var text := _txt(_nag)
		PixelFont.draw_centered(self, text, wick.x, wick.y - 22, PAL[_nag_colour], PAL["night"])
	if _ring > 0.0:
		var dots := ceili(RING_DOTS * _ring)
		for i in dots:
			var a := -PI / 2.0 + TAU * i / RING_DOTS
			draw_rect(Rect2((wick + Vector2(cos(a), sin(a)) * RING_R).round(), Vector2(1, 1)), PAL["cream"])


## P8 B4: SPACE: FIX THE SCREEN in gold under Wick (`wick` = his body on the game screen), the SPACE key cap
## blinking; plain English (LANGUAGE never scrambles it). The run draws it on its top layer (`ci`), above the sold
## look, so it reads on the wrecked screen whatever HUD rows are sold.
func draw_relight_key(ci: CanvasItem, wick: Vector2) -> void:
	var text := STORY.line("finale.relight_key", "SPACE: FIX THE SCREEN")
	var colon := maxi(text.find(":"), 0)
	var key := text.substr(0, colon)
	var rest := text.substr(colon)
	var w := PixelFont.width(key) + 4 + PixelFont.width(rest)
	var x := roundf(wick.x - w / 2.0)
	var y := roundf(wick.y + RELIGHT_KEY_Y)
	var lit := fmod(_relight_blink, RELIGHT_BLINK * 2.0) < RELIGHT_BLINK
	var cap := Rect2(x - 1, y - 2, PixelFont.width(key) + 4, PixelFont.H + 4)
	ci.draw_rect(cap.grow(1), PAL["night"])
	ci.draw_rect(cap, PAL["gold"] if lit else PAL["mauve"])
	ci.draw_rect(cap.grow(-1), PAL["night"] if lit else PAL["dusk"])
	PixelFont.draw(ci, key, Vector2(x + 1, y), PAL["gold"] if lit else PAL["stone"], PAL["night"])
	PixelFont.draw(ci, rest, Vector2(x + PixelFont.width(key) + 4, y), PAL["gold"], PAL["night"])


## World position -> HUD position (the HUD layer shares the game screen's coordinates).
func _to_screen(world: Vector2) -> Vector2:
	if run.view and run.view.has_method("origin"):
		return world - run.view.origin()
	return get_viewport().get_canvas_transform() * world


## The tutorial phase (the run's phase; a stand-in run without one uses tutorial_mode).
func _in_tutorial() -> bool:
	var phase = run.get("phase")
	return run.tutorial_mode if phase == null else phase == TUTORIAL_PHASE


func _txt(s: String) -> String:
	return shop.txt(s) if shop else s


## P8b B2: `BLAST k/n` centred over the lantern (gold) in the CLOSING gaps; the run calls it on Top, so it reads
## over the wrecked screen. `at` is the text's centre top in game-screen px.
func draw_blast_tag(ci: CanvasItem, at: Vector2, k: int, n: int) -> void:
	var text := "%s %d/%d" % [STORY.line("finale.blast_count", "BLAST"), k, n]
	var pos := Vector2(roundf(at.x - PixelFont.width(text) / 2.0), roundf(at.y))
	ci.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(PixelFont.width(text) + 4, PixelFont.H + 4)), PAL["night"])
	PixelFont.draw(ci, text, pos, PAL["gold"], PAL["night"])


## P8b M2: a coral heart and `LAST HEART` centred at `at` (over Wick) while he is on his last heart, whatever the
## HUD shows; the run calls it on Top (it blinks it).
func draw_last_heart(ci: CanvasItem, at: Vector2) -> void:
	var text := STORY.line("finale.last_heart", "LAST HEART")
	var w := 7 + PixelFont.width(text)
	var x := roundf(at.x - w / 2.0)
	var y := roundf(at.y)
	ci.draw_rect(Rect2(x - 2, y - 2, w + 4, PixelFont.H + 4), PAL["night"]) # a plate: it reads over the swarm
	for r in HEART:
		ci.draw_rect(Rect2(Vector2(x, y) + r.position, r.size), PAL["coral"])
	PixelFont.draw(ci, text, Vector2(x + 7, y), PAL["coral"], PAL["night"])
