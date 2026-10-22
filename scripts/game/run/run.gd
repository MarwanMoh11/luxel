extends Node2D
## The Run (ARCHITECTURE.md 4.2, 5.3): owns the simulation (fixed 1/60 s steps), the phases and every sale effect,
## and is the `game` object the enemy brains and light_fx talk to (names fixed by scripts/cast/enemies/README.md).
## Helpers are RefCounted with a back-reference `run`, stepped in order from one _step function.
## Phases: TUTORIAL and MAIN play; a full gauge opens the menu (MENU, or CONFIRM once the shop's ADVANCED tab is
## due); CONFIRM SALES starts CLOSING, where the gauge fills by the clock and each fill is a self-sale (AUTO_SALE).
## The finale story (P8, design 10): the last player menu starts the swell (the director's tide); each self-sale
## charges the blast; after the last one BLAST kills every enemy as its ring passes, 2 s of aftermath (CLOSING),
## then RELIGHT: mashing SPACE grows the restored look from the lantern (`flare`: the screen shows the beauty rows
## unsold) and spends the lantern (RELIGHT_POWER); a calm look and the rest of the dark (CLOSING), then the menu
## waits on PIXELS (PIXELS_PROMPT): each press sells 1% with the world frozen; AUTO-SELL (or a stub menu) starts the
## automatic PIXELS steps (PIXELS) under the tide until the screen is black (OFF, then the ending). DEAD: Wick fell.
## Debug builds: keys 1-6 drop a snuffer/owl/toad/sporecap/gloam/magpie near Wick (0 = one of each), F5 fills
## the gauge.

signal phase_changed(phase: int)
signal moved(px: float)
signal killed(id: String, pos: Vector2)
signal shard_landed(light: float, fill: float)
signal gauge_full()
signal menu_opened(ctx: Dictionary)
signal menu_closed(sale: Dictionary)
signal hurt(hp: int)
signal died(stats: Dictionary)
signal display_off_reached(stats: Dictionary) ## ARCHITECTURE.md's `display_off` signal (the name is the brain API func)
signal debut(id: String)
signal formation_coming(anchor: Vector2)
signal closing_started()
signal pixels_stage(stage: int) ## 0 at the first pixel sold, 1-3 at 70/40/15% left, 4 at the last pixel (1% left)
signal finale_line(id: String, colour: String, secs: float) ## a finale narration line (STORY.md 5): main says it
signal stop_line(id: String, colour: String, scale: int, y: float) ## a stop's big centred line (P8b): main says it
signal stop_cleared() ## the stop's lines go as its menu opens

enum Phase { TUTORIAL, MAIN, MENU, CONFIRM, CLOSING, AUTO_SALE, PIXELS_PROMPT, PIXELS, OFF, DEAD, BLAST, RELIGHT, STOP }

const STEP := 1.0 / 60.0
const MAX_STEPS := 6 # sub-steps a frame at most: a long hitch (hidden tab, stall) slows the world, never skips ahead
const WICK := preload("res://scripts/cast/wick.gd")
const SHARD_FX := preload("res://scripts/cast/shard_fx.gd")
const LIGHT := preload("res://scripts/cast/light_fx.gd")
const PLAYER := preload("res://scripts/game/run/player.gd")
const COMBAT := preload("res://scripts/game/run/combat.gd")
const ENEMIES := preload("res://scripts/game/run/enemies.gd")
const DIRECTOR := preload("res://scripts/game/run/director.gd")
const SHARDS := preload("res://scripts/game/run/shards.gd")
const PROGRESSION := preload("res://scripts/game/run/progression.gd")
const VIEW := preload("res://scripts/game/run/view.gd")
const DATA := preload("res://scripts/game/shop/shop_data.gd")
const STORY := preload("res://scripts/game/story/story_text.gd")
const OWL := preload("res://scripts/cast/enemies/owl.gd")
const KIT := preload("res://scripts/cast/enemies/enemy_kit.gd")

const PLAYING: Array[int] = [Phase.TUTORIAL, Phase.MAIN, Phase.CLOSING, Phase.PIXELS] ## the world runs
const LEVELUP_DELAY := 0.3 # s the world runs on after the gauge fills (Wick can't be hurt meanwhile)
const HIT_STOP := 0.06 # s the world stops when Wick is hit
const SHAKE_TIME := 0.25
const TEMPO: Array[float] = [1.0, 1.15, 1.30] # enemy tempo per DIFFICULTY level
const GAMER_TEMPO := 1.15 # x the enemy tempo in GAMER MODE
const PIXEL_TOAST := 0.6 # s the PIXELS toast stays up
const PIXEL_STAGES: Array[int] = [70, 40, 15] # % of the pixels left at last-light stages 1-3
const BLACK_WAIT := 2.0 # s after the last pixel before OFF even if fx.screen_black() never says so
## The relight (design 10.3): from its end to DISPLAY: OFF the screen shows these rows unsold (lv() reads 0); the
## shop's levels and every power stay.
const FLARE_RESTORES: Array[String] = ["hit_flash", "particles", "animations", "frame_rate", "vsync", "colour",
		"brightness", "resolution", "audio_quality"]
const KIND_OWL := 1 # enemy.kind: the index in director.gd KINDS
const KIND_MAGPIE := 5
const LV_HOT: Array[String] = ["animations", "hit_flash", "particles"] ## FLARE_RESTORES rows lv() keeps (shop.rev)
## The finale story (P8, design 10). Times are world seconds unless the world is frozen (BLAST, RELIGHT).
const SAY := 2.5 # s a finale line stays (main's FINALE_SAY)
const NEED_POWER_AFTER := 5.0 # s of play from finale.swell to finale.need_power
const SWELL_MIN := 15.0 # s of play the swell runs at least before the forced CONFIRM menu opens
const EDGE_SWELL := 36.0 # px of the night band at the screen edges by the end of the swell (fx.dark_edges)
const EDGE_SWELL_SECS := 12.0
const EDGE_CHARGE := 44.0 # ...at the last self-sale
const EDGE_SURGE := 8.0 # ...more as the blast gathers
const BLAST_RING_AT := 0.6 # s into the blast's freeze when the shockwave starts
const BLAST_RING := 0.5 # s the ring takes past the screen diagonal (when fx.blast doesn't say)
const BLAST_FREEZE := 1.4 # s the world stays frozen
const AFTERMATH := 2.0 # s of play on the empty, wrecked island before the relight
const RELIGHT_PRESSES := 12
const RELIGHT_GAP := 0.05 # s between counted presses at least
const RELIGHT_IDLE := 8.0 # s with no press before the lantern finishes by itself
const RELIGHT_SELF := 0.15 # s between its own presses then
const RELIGHT_HOLD := 0.3 # s after the last press before the world resumes (the ring eases to the corners)
const RELIGHT_FPS := {3: 30, 6: 40, 9: 0} # press -> frame cap (0 = the base)
const RELIGHT_NOTES: Array[int] = [69, 70, 73, 74, 76, 77, 79, 81, 82, 85, 86, 86] # D harmonic minor from A4
const RELIGHT_MOTES := 4 # outward sell motes per press, to the ring's edge
const RELIGHT_POWER := 0.25 # x the lantern's damage once it has fixed the screen (P8b: the dark wins)
const POWER_BACK := (1.0 - RELIGHT_POWER) / 10.0 # ...back per PIXELS step sold: 1.0 again at 10 sold
const PIXEL_MEND := 10 # PIXELS steps sold per heart mended
const RELIGHT_FIRE := 0.4 # x the lantern's fire rate (volleys, stings) when spent; back with lantern_power
const CALM_LOOK := 3.0 # s of play on the restored island, no spawns
const OVERWHELM_LEN := 8.0 # s of play from the second tide's first ring to the PIXELS stop (P8b M2)...
const OVERWHELM_MIN := 5.0 # ...or from this on, once Wick has been on 1 heart for LAST_HEART_END
const LAST_HEART_END := 2.0
const EDGE_OVERWHELM := 60.0 # px of the night band by the end of the overwhelm (only a pocket around Wick left)
const EDGE_PER_HIT := 5.0 # ...it closes over OVERWHELM_LEN, and this much faster per heart lost since the first ring
const EDGE_HIT_SECS := 0.25
const EDGE_GONE_AT := 30 # PIXELS sold by which the lantern has pushed the band back out (M3)
const PIXEL_GLOW_FULL := 40.0 # PIXELS sold by which the halo is back to its full B2 size (M3)
const SPUTTER_PX := 12.0 # the spent lantern's halo at the first ring; it shrinks to GLOW_PX[0] with the hearts
const SPUTTER_TICK := 0.06 # s per flicker frame
const SPUTTER_DARK := 7.0 # px of the night dither over the glass when it gutters out
const STOP_SLOW := 0.35 # x the world's speed as a stop begins (P8b: CONFIRM and PIXELS)...
const STOP_SLOW_LEN := 0.8 # ...for this long (real s), then the world freezes and the problem line shows
const STOP_ANSWER := 0.6 # s later the answer under it
const STOP_HOLD := 1.6 # s the two lines hold before the menu opens
const STOP_Y := 30.0 # the problem line's top (scale 2); the answer STOP_GAP under it
const STOP_GAP := 16.0
const STOP_LINES := {"confirm": ["finale.too_many", "finale.one_blast"], "pixels": ["finale.alone", "finale.give_screen"]}
const BLAST_TAG_Y := 13.0 # px over the lantern: BLAST k/13 in the CLOSING gaps
const LAST_HEART_Y := 25.0 # px over Wick's body centre: LAST HEART
const LAST_HEART_BLINK := 0.3 # s on, then the same off
const CLOSE_AT := 15 # % of the pixels left from which the tide rings come closer and twice as often
const GLOW_PX: Array[float] = [5.0, 18.0] # the lantern's halo radius at the first and the last charge notch
const PULSE := 0.2 # s a relight press makes the halo swell
const PAL: Dictionary = preload("res://scripts/game/ui/palette.gd").PAL
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5] # the 4x4 dither grid
const DEBUG_KEYS := {KEY_1: "snuffer", KEY_2: "owl", KEY_3: "toad", KEY_4: "sporecap", KEY_5: "gloam", KEY_6: "magpie"}
const DEBUG_RING := Vector2(45.0, 70.0) # px from Wick where debug keys drop enemies

# Wiring (main.gd sets `top`, then calls setup once)
var island: Island
var fx ## settings_fx.gd (the Fx node)
var shard_audio ## shard_audio.gd (the ShardAudio node)
var shop: ## shop.gd
	set(v):
		shop = v
		_lv_rev = -1
var menu ## settings_menu.gd (the Menu node)
var hud ## hud.gd (the Hud node)
var top: Node2D ## the Node2D on CanvasLayer 6 the run paints: lantern, eyes and shards over the dead pixels

# State
var phase: int = Phase.MAIN
var run_time := 0.0
var frozen := true ## world stopped: MENU, CONFIRM, AUTO_SALE, FLARE, PIXELS_PROMPT, OFF, DEAD, pause, before the first run
var paused := false
var started := false ## a run has started (the title shows an idle island before)
var safe := false ## tutorial: Wick takes no damage
var tutorial_mode := false
var gauge_revealed := false ## tutorial: the HUD gauge shows once the first shard lands
var wick: WICK
var player: PLAYER
var combat: COMBAT
var enemies_host: ENEMIES
var director: DIRECTOR
var shards: SHARDS
var prog: PROGRESSION
var view: VIEW
var light: LIGHT ## scripts/cast/light_fx.gd, ported to the Run API
var shard_fx: SHARD_FX
var anim_time := 0.0 ## seconds, for animation ticks
var enemy_tempo := 1.0 ## from DIFFICULTY (and GAMER MODE)
var gamer := false ## GAMER MODE (the title's toggle, main sets it): the last heart can go until the blast, more
## enemies (director.gd), less MERCY TIME (player.gd), a faster crowd, a longer need curve (progression.gd)
var last_sold := "" ## the last setting the player or the menu sold (the death quip)
var bot = null ## tests/run_bot.gd: steers Wick while autopilot is on (else player.gd's dodge bot)
var no_levels := false ## checks: a full gauge opens no menu (counted as stats menus_opened)
var debug_keys := true ## debug builds: keys 1-6, 0 and F5
var show_wick := true ## false on the title (the intro shows him when he drops in)

# Brain facade properties (README.md contract)
var world_speed := 1.0
var enemies: Array = [] ## the same array as enemies_host.list
var remnants: Array = []
var hazards: Array = []
var player_pos := Vector2.ZERO ## Wick's body centre (the contact circle's)
var player_vel := Vector2.ZERO
var bullets: Array = [] ## the same array as combat.bullets
var bullet_speed := 220.0
var level: int: ## the player's level (a magpie star on its way counts already)
	get:
		return 1 if prog == null else prog.level + _stars_pending()
var immortal := false
var autopilot := false
var stats := {} ## enemy counters for the checks (spawned_<id>, killed_<id>, ...)

var _levelup_t := -1.0 # LEVELUP_DELAY left; < 0 = none running
var _hitstop := 0.0
var _last_hp := 0
var _tut_menu := false # the tutorial's menu has been shown
var _tut_done := false # tutorial.finished came (end_tutorial)
var _resume_t := -1.0 # AUTO_SALE: seconds until the world resumes after the menu shut (sale.resume_in)
var _eye_images := {} # eyes texture -> its Image (read back at DISPLAY: OFF, only for a sheet eyes.json lacks)
var _gap := 0.0 # CLOSING: play seconds since the last self-sale
var _gap_len := 0.0
var _auto_done := 0 # self-sales so far
var _auto_target := ""
var _pixel_t := 0.0
var _stage := 0 # last pixels_stage emitted
var _black_t := 0.0
var flare := false: ## the relight's override is on (FLARE_RESTORES show unsold), from its end to DISPLAY: OFF
	set(v):
		flare = v
		_lv_rev = -1
var _halo_imgs := {} # the lantern's halo baked (see _bake_halo): dither grid phase -> Image and its texture
var _halo_texs := {}
var _halo_baked := {} # the phases baked for _halo_key_r and _halo_key_out
var _halo_key_r := -2.0
var _halo_key_out := false
var _lv_rev := -1 # shop.rev the _lv_hot values were read at (-1: read them again)
var _lv_hot := {} # the hot rows (enemies read them every step) -> lv(), flare applied
var _flared := false # the blast and the relight have played (the next empty queue opens the PIXELS menu)
var lantern_power := 1.0 ## x the lantern's damage: RELIGHT_POWER after the relight, back with each pixel sold
var charge := 0.0 ## the blast's charge 0..1 (self-sales; drained by the relight presses): the lantern's halo
var relight_presses := 0 ## RELIGHT: presses counted so far
var _swelled := false # the swell has started this run
var _swell_t := 0.0 # seconds of play since
var _lines: Array = [] # finale lines waiting: [world seconds left, id, colour, secs]
var _edge := 0.0 # px the night band was last sent to
var _blast_t := -1.0 # BLAST: seconds into the freeze
var _blast_len := BLAST_RING
var _blast_from := Vector2.ZERO # the lantern on the map when the ring started
var _aftermath := -1.0 # CLOSING after the blast: seconds of play left before the relight
var _relight_t := 0.0 # RELIGHT: seconds since the last counted press
var _relight_done := -1.0 # RELIGHT: seconds since the last press landed (-1: not yet)
var _calm := false # CLOSING after the relight: the calm look runs (no spawns)
var _pulse := 0.0
var _idle_t := 0.0 # RELIGHT: seconds since the last press (RELIGHT_IDLE)
var _auto_from := 1 # PIXELS sold when the automatic steps started (their speed-up runs over the steps left)
var _hand_pixels := 0 # PIXELS steps the run has applied from the menu's presses
var _stop := "" # the stop running (P8b): "confirm" or "pixels"; "" = none
var _stop_t := 0.0 # real seconds into it
var _stopped := false # the CONFIRM stop has played this run
var _overwhelm := -1.0 # s of play since the second tide's first ring (-1: not yet)
var _one_heart := 0.0 # s of play Wick has been on 1 heart in the overwhelm
var _sputter_hp := 0 # Wick's hearts at the first ring (the sputtering halo shrinks from there)


## Wires the run to the scene's nodes and builds its helpers; main calls it once.
func setup(island_node: Island, fx_node: Node, audio_node: Node, shop_obj: RefCounted, menu_node: Node2D, hud_node: Node2D) -> void:
	island = island_node
	fx = fx_node
	shard_audio = audio_node
	shop = shop_obj
	menu = menu_node
	hud = hud_node
	wick = WICK.new()
	shard_fx = SHARD_FX.new()
	shard_fx.setup()
	view = VIEW.new()
	view.setup(self)
	player = PLAYER.new()
	player.setup(self)
	combat = COMBAT.new()
	combat.setup(self)
	enemies_host = ENEMIES.new()
	enemies_host.setup(self)
	director = DIRECTOR.new()
	director.setup(self, OS.get_cmdline_user_args())
	shards = SHARDS.new()
	shards.setup(self)
	prog = PROGRESSION.new()
	prog.setup(self)
	light = LIGHT.new()
	light.setup(self)
	view.build()
	top.draw.connect(_paint_glow) # after the view's top layer: the halo sits over the eyes and Wick
	enemies_host.read_sfx()
	bullets = combat.bullets
	enemies = enemies_host.list
	remnants = enemies_host.remnants
	hazards = enemies_host.hazards
	menu.closed.connect(_on_menu_closed)
	if menu.has_signal("pixel_sold"):
		menu.connect("pixel_sold", _on_pixel_sold)
	shard_landed.connect(_on_shard_landed)
	prog.reset()
	player.reset()
	view.step(0.0)
	view.sync()


## Full reset (design 11), then TUTORIAL (tutorial = true: safe, director paused) or MAIN.
func start_run(tutorial: bool) -> void:
	started = true
	show_wick = true
	tutorial_mode = tutorial
	safe = tutorial
	paused = false
	gauge_revealed = not tutorial
	run_time = 0.0
	enemy_tempo = GAMER_TEMPO if gamer else 1.0
	last_sold = ""
	stats.clear()
	_levelup_t = -1.0
	_hitstop = 0.0
	_tut_menu = false
	_tut_done = false
	_resume_t = -1.0
	_gap = 0.0
	_auto_done = 0
	_stage = 0
	_black_t = 0.0
	_reset_flare()
	shop.reset()
	prog.reset()
	director.reset()
	director.paused = tutorial
	enemies_host.reset()
	shards.reset()
	shards.cosmetic = false
	shard_fx.reset()
	shard_audio.reset()
	light.reset()
	combat.reset()
	view.reset()
	player.reset()
	_last_hp = player.hp
	wick.reset()
	if not tutorial:
		wick.play("spawn") # after the intro Wick has already dropped in
	fx.start_run()
	fx.apply(shop.levels)
	island.apply(shop.levels)
	if hud.has_method("reset"):
		hud.reset()
	hud.set_shown(true)
	_set_phase(Phase.TUTORIAL if tutorial else Phase.MAIN)


## No run (title, intro): the island empty and still, Wick at the sundial and hidden, the HUD's numbers at rest.
func idle() -> void:
	started = false
	show_wick = false
	paused = false
	enemies_host.reset()
	shards.reset()
	shard_fx.reset()
	combat.reset()
	light.reset()
	view.reset()
	shop.reset()
	prog.reset()
	player.reset()
	wick.reset()
	_reset_flare()
	fx.apply(shop.levels)
	island.apply(shop.levels)
	_set_phase(Phase.MAIN)


## Debug jumps (main's args): "swell" sells every early row and starts the swell (the next level-up opens the
## forced CONFIRM menu); "closing" sells every early row, then a level-up opens the forced CONFIRM menu at once;
## "blast" also sells CONFIRM and the whole finale queue, then the blast, the relight and the rest of the dark play
## and the PIXELS menu opens; "relight" starts at the relight (the island cleared); "pixels" skips the blast and the
## relight (the screen restored, the lantern spent) and opens the PIXELS menu; "ending" also sells every pixel and
## goes to DISPLAY: OFF.
func debug_jump(to: String) -> void:
	for id: String in DATA.early_rows():
		while shop.row_state(id) == shop.RowState.OPEN:
			_apply_sale(shop.sell(id))
	if to == "swell":
		_start_swell()
		return
	if to == "closing":
		prog.add_light(maxf(prog.need - prog.light, 0.0) + 0.001)
		return
	if shop.has_method("reveal_advanced"):
		shop.reveal_advanced()
	_apply_sale(shop.sell(DATA.CONFIRM))
	_start_closing()
	for id: String in shop.finale_queue():
		_apply_sale(shop.sell(id))
	charge = 1.0
	if to == "blast":
		_gap = _gap_len # the blast starts on the next step
		return
	_kill_all()
	if to == "relight":
		_start_relight()
		return
	_relit()
	_calm = false
	director.paused = false
	director.set_tide("rest")
	_overwhelm = OVERWHELM_LEN # the overwhelm's look: the pocket closed, the lantern sputtering
	_sputter_hp = player.hp
	_dark_edges(EDGE_OVERWHELM, 0.0)
	_gap = _gap_len # the PIXELS stop starts on the next step
	if to == "pixels":
		return
	_apply_sale(shop.sell(DATA.PIXELS))
	_start_auto_pixels()
	while shop.lv(DATA.PIXELS) < DATA.PIXEL_STEPS:
		var sale: Dictionary = shop.sell(DATA.PIXELS, true)
		if sale.is_empty():
			break
		_apply_sale(sale)
	_display_off()


## Freezes or thaws the world for the pause card (music behind the menu wall, shards held).
func set_paused(on: bool) -> void:
	if paused == on:
		return
	paused = on
	fx.menu(on)
	_update_frozen()


## Tutorial over (tutorial.finished): the run plays on as MAIN.
func end_tutorial() -> void:
	_tut_done = true
	tutorial_mode = false # the first run plays on as a normal run (the HUD's general tips start)
	safe = false
	director.paused = false
	if phase == Phase.TUTORIAL:
		_set_phase(Phase.MAIN)


## World positions of the enemies' eyes at DISPLAY: OFF (one point per enemy: the middle of its eyes layer in
## the current frame, else its hit centre), for the ending.
func eye_pairs() -> PackedVector2Array:
	var out := PackedVector2Array()
	for e in enemies:
		out.append(_eye_point(e))
	return out


## The ending takes the eyes over: the enemies, remnants and hazards leave the island for good (nothing of them
## shows when the pixels come back).
func hide_eyes() -> void:
	view.eyes_hidden = true
	enemies_host.reset()



## The centre of the opaque pixels of `e`'s eyes layer in its current frame, in world px (mirrored about the anchor
## like draw_layer).
func _eye_point(e) -> Vector2:
	var tex_by: Dictionary = e.clip["tex"]
	if not tex_by.has("eyes"):
		return e.centre()
	var f: int = e.frame()
	var mids: PackedVector2Array = e.clip["eye_mids"]
	var mid: Vector2 = mids[f] if f < mids.size() else _eye_mid(tex_by["eyes"], f, e.clip["size"])
	if mid == Vector2.INF:
		return e.centre()
	var anchor: Vector2 = e.clip["anchor"]
	var local := mid - anchor
	if e.mirrored():
		local.x = -local.x
	return e.pos.round() + local


## A frame's eye middle (KIT.eye_mid) from the sheet read back from the GPU: only for a sheet eyes.json lacks.
func _eye_mid(tex: Texture2D, f: int, size: Vector2) -> Vector2:
	if not _eye_images.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_eye_images[tex] = img
	var img: Image = _eye_images[tex]
	if img == null or img.is_empty():
		return Vector2.INF
	return KIT.eye_mid(KIT.eye_sum(img, f, size))


## Tutorial: spawns `count` enemies of kind `id` around `anchor` (the nearest walkable point to it), outside the
## director, at 0.8x tempo.
func spawn_scripted(id: String, count: int, anchor: Vector2) -> void:
	anchor = _nearest_open(anchor)
	for i in count:
		var e := spawn(id, anchor, i, count)
		enemies_host.scripted[e] = true


## The walkable point nearest `p` (rings of 4 px out to 64 px), else `p`.
func _nearest_open(p: Vector2) -> Vector2:
	if open(p):
		return p
	for r in range(4, 68, 4):
		for k in 16:
			var q := p + Vector2.from_angle(TAU * k / 16.0) * r
			if open(q):
				return q
	return p


## Tutorial: a walkable edge point on the emptiest side of the view.
func clear_side() -> Vector2:
	return director._clear_anchor()


## Tutorial: the next shard pull plays slowed over `secs`.
func slow_next_pull(secs: float) -> void:
	shards.slow_next_pull(secs)


## The gauge's fill 0..1 (the clock's fill while closing).
func gauge_fill() -> float:
	return prog.fill()


## True from CONFIRM SALES sold on: hits can't take the last heart, FINALE_RATE, no magpies.
func closing() -> bool:
	return (phase >= Phase.CLOSING and phase <= Phase.OFF) or phase == Phase.BLAST or phase == Phase.RELIGHT \
			or (phase == Phase.STOP and _stop == "pixels")


## A hit can't take the last heart (player.hurt): from act 3 (player.GUARD_LEVEL) and while closing; in GAMER MODE
## only from the blast on (the dark is meant to win the overwhelm).
func last_heart_guarded() -> bool:
	if gamer:
		return _flared or _aftermath >= 0.0 or phase == Phase.BLAST or phase == Phase.RELIGHT
	return closing() or prog.level >= PLAYER.GUARD_LEVEL


## RELIGHT waits on SPACE (the HUD's prompt).
func relighting() -> bool:
	return phase == Phase.RELIGHT and _relight_done < 0.0


## The lantern's shot damage (x10 scale): the shop's powers x lantern_power.
func shot_damage() -> int:
	return maxi(1, roundi(prog.damage() * lantern_power))


## The spent lantern also fires slower (P8b): x RELIGHT_FIRE at RELIGHT_POWER, back to 1 with lantern_power.
func fire_scale() -> float:
	return lerpf(RELIGHT_FIRE, 1.0, clampf((lantern_power - RELIGHT_POWER) / (1.0 - RELIGHT_POWER), 0.0, 1.0))


## Wick's death plays (phase DEAD).
func dead() -> bool:
	return phase == Phase.DEAD


## A level-up is about to open the menu (Wick can't be hurt).
func levelup_pending() -> bool:
	return _levelup_t >= 0.0 or _stop == "confirm"


## Wick blinks while invulnerable, once the hurt animation is over; the death animation always shows.
func wick_visible() -> bool:
	if not show_wick:
		return false
	if dead() or wick.playing("hurt"):
		return true
	return not (player.invuln > 0.0 and int(player.invuln * 10.0) % 2 == 0)


## The run's numbers for the cards, the save and the ending: {time, level, kills, light, sold, done, last}.
func summary() -> Dictionary:
	return {"time": run_time, "level": prog.level, "kills": enemies_host.kills, "light": prog.total_light,
		"sold": shop.sold_count(), "done": phase == Phase.OFF, "last": last_sold}


## Draws the shards (and their one-shot sprites) on `ci`, `origin` = world position of ci's (0, 0).
func paint_shards(ci: CanvasItem, origin: Vector2) -> void:
	shards.draw(ci, origin)
	if origin != Vector2.ZERO:
		ci.draw_set_transform(-origin)
	shard_fx.draw(ci, lantern())
	if origin != Vector2.ZERO:
		ci.draw_set_transform(Vector2.ZERO)


# ---- Simulation -------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if prog == null:
		return
	var left := minf(delta, STEP * MAX_STEPS)
	while left > 0.0:
		var dt := minf(left, STEP)
		left -= dt
		_step(dt)
	view.sync()
	queue_redraw()


func _step(dt: float) -> void:
	anim_time += dt
	view.step(dt)
	fx.step(dt, player_pos - view.origin(), phase != Phase.DEAD)
	if not started or paused:
		return
	_step_cast(dt)
	if phase == Phase.OFF or phase == Phase.RELIGHT:
		light.step(dt) # the ending's sell streams, the relight's motes
	if phase == Phase.AUTO_SALE and _resume_t >= 0.0:
		_resume_t -= dt
		if _resume_t < 0.0:
			_set_phase(Phase.CLOSING)
	if phase == Phase.BLAST:
		_step_blast(dt)
	elif phase == Phase.RELIGHT:
		_step_relight(dt)
	elif phase == Phase.STOP:
		_step_stop(dt)
	if frozen:
		return
	if _hitstop > 0.0:
		_hitstop -= dt
		return
	_world(dt * STOP_SLOW if phase == Phase.STOP else dt)
	match phase:
		Phase.TUTORIAL, Phase.MAIN:
			_step_levels(dt)
		Phase.CLOSING:
			_step_closing(dt)
		Phase.PIXELS:
			_step_pixels(dt)


## One world step: Wick, the lantern, the director, the enemies, the shards, contact.
func _world(dt: float) -> void:
	run_time += dt
	var before := player.feet
	player.step(dt)
	var px := before.distance_to(player.feet)
	if px > 0.0:
		moved.emit(px)
	combat.step(dt)
	director.step(dt)
	enemies_host.step(dt)
	shards.step(dt)
	shard_fx.step(dt)
	light.step(dt)
	_contact()
	_threats()
	_step_lines(dt)
	if _swelled:
		_swell_t += dt


## Wick's animation and the lantern's light tier (also while the menu holds the world: the levelup pose).
func _step_cast(dt: float) -> void:
	wick.still = still()
	wick.tier = _lantern_tier()
	_pulse = maxf(_pulse - dt, 0.0)
	wick.step(dt, player_vel if not frozen else Vector2.ZERO)
	if wick.landed:
		light.land(wick_feet())
		if lv("particles") == 0 and view.ground_speed(wick_feet()) < 1.0:
			view.kick_soil(wick_feet())
	if player.hp > _last_hp and lv("healing") == 0:
		light.heal()
	_last_hp = player.hp


func _contact() -> void:
	if not player.hittable():
		return
	var src := enemies_host.contact()
	if src != "":
		stat("wick_hurt_" + src)
		_hurt_wick()


## A hit on Wick: hit-stop, shake, the crowd shoved, MERCY TIME; a heart unless safe or the last one while closing.
func _hurt_wick() -> void:
	var lost := player.hurt()
	_hitstop = HIT_STOP
	if lv("shake") == 0:
		view.shake = SHAKE_TIME
	enemies_host.shove(player_pos)
	fx.play("hurt", 0.0)
	if player.hp <= 0:
		_die()
		return
	wick.play("hurt")
	if lost:
		hurt.emit(player.hp)


func _die() -> void:
	_set_phase(Phase.DEAD)
	wick.play("death")
	fx.died()
	hurt.emit(0)
	died.emit(summary())


## A full gauge opens the menu after LEVELUP_DELAY (the world runs on meanwhile).
func _step_levels(dt: float) -> void:
	if prog.pending <= 0:
		_levelup_t = -1.0
		if phase == Phase.MAIN and not _swelled and shop.advanced_due(prog.level, run_time):
			_start_swell() # the next level-up opens the forced CONFIRM menu
		return
	if no_levels:
		while prog.pending > 0:
			prog.take_level_up()
			stat("menus_opened")
		return
	if _swelled and _swell_t < SWELL_MIN and shop.advanced_due(prog.level, run_time):
		_levelup_t = -1.0 # the swell runs SWELL_MIN first; the full gauge waits for the forced CONFIRM menu
		return
	if _levelup_t < 0.0:
		_levelup_t = LEVELUP_DELAY
	_levelup_t -= dt
	if _levelup_t <= 0.0:
		_open_menu()


func _open_menu() -> void:
	_levelup_t = -1.0
	if not _stopped and (phase == Phase.MAIN or phase == Phase.MENU) and shop.advanced_due(prog.level, run_time):
		_start_stop("confirm") # P8b: the world slows, freezes, says the problem and the answer, then this menu
		return
	var lvl := prog.take_level_up()
	var mode := "player"
	if phase == Phase.TUTORIAL and not _tut_menu:
		mode = "tutorial"
		_tut_menu = true
	elif shop.advanced_due(lvl, run_time):
		mode = "forced"
	var ctx := {"mode": mode, "level": lvl, "new_tab": _new_tab(lvl, mode), "target": "", "line": ""}
	if mode == "tutorial":
		ctx["line"] = STORY.line("tut.menu_quip")
	if mode == "forced":
		ctx["line"] = STORY.line("finale.nothing_left", "THERE IS NOTHING LEFT TO SELL.")
	_set_phase(Phase.CONFIRM if mode == "forced" else Phase.MENU)
	wick.play("levelup")
	fx.level_up()
	stat("menus_opened")
	menu_opened.emit(ctx)
	menu.open(ctx)


## The tab the menu opens on (design 9.1; the shop keeps which tabs a menu has shown).
func _new_tab(lvl: int, mode: String) -> int:
	if mode == "forced":
		return DATA.ADVANCED_TAB
	if mode == "tutorial":
		return 0
	return shop.pick_tab(lvl)


func _on_menu_closed(sale: Dictionary) -> void:
	match phase:
		Phase.MENU:
			if bool(sale.get("buy_back", false)):
				_apply_buy_back(sale)
			else:
				_apply_sale(sale)
			_after_menu()
		Phase.CONFIRM:
			_apply_sale(sale)
			if sale.get("id", "") == DATA.CONFIRM or shop.closing():
				_start_closing()
			else:
				_after_menu()
		Phase.AUTO_SALE:
			if sale.is_empty() and _auto_target != "":
				sale = shop.sell(_auto_target, true) # a menu that didn't sell (the Phase 0 stub)
			_apply_sale(sale)
			_auto_done += 1
			var of: int = _auto_done + shop.finale_queue().size()
			charge = float(_auto_done) / maxf(of, 1.0) # the lantern's glow, one notch per self-sale (B2)
			_dark_edges(lerpf(EDGE_SWELL, EDGE_CHARGE, charge), 0.5)
			_gap = 0.0
			_gap_len = _gap_for(_auto_done)
			wick.play("sell")
			_resume_t = float(sale.get("resume_in", 0.0)) # the world resumes this long after the menu shut
			if _resume_t <= 0.0:
				_resume_t = -1.0
				_set_phase(Phase.CLOSING)
		Phase.PIXELS_PROMPT:
			if String(sale.get("id", "")) == DATA.PIXELS and shop.lv(DATA.PIXELS) > _hand_pixels:
				_on_pixel_sold(sale) # a menu that sold its pixel without pixel_sold
			elif shop.lv(DATA.PIXELS) == 0:
				_on_pixel_sold(shop.sell(DATA.PIXELS)) # a menu that didn't sell (the Phase 0 stub)
			if shop.lv(DATA.PIXELS) >= DATA.PIXEL_STEPS:
				_black_t = 0.0 # sold by hand to the end: the black wait, then OFF
				prog.clock_fill = 1.0
				_set_phase(Phase.PIXELS)
			elif shop.lv(DATA.PIXELS) > 0:
				_start_auto_pixels() # AUTO-SELL: the rest sell themselves while Wick fights


## Back to play after a player menu, or the next menu when more level-ups wait.
func _after_menu() -> void:
	if prog.pending > 0:
		_open_menu()
		return
	if tutorial_mode and _tut_menu and safe:
		safe = false # T5: hearts can be lost and the director runs from the menu's close (design 12)
		director.paused = false
	wick.play("sell")
	_set_phase(Phase.TUTORIAL if tutorial_mode and not _tut_done else Phase.MAIN)


## DIFFICULTY's enemy tempo, x GAMER_TEMPO in GAMER MODE.
func _tempo() -> float:
	return TEMPO[mini(lv("difficulty"), TEMPO.size() - 1)] * (GAMER_TEMPO if gamer else 1.0)


## Shows the shop's levels as they are (checks and renders that set shop.levels by hand): fx, island, enemy tempo.
func refresh_levels() -> void:
	shop.rev += 1 # a hand-set level is read again
	enemy_tempo = _tempo()
	fx.apply(shown_levels())
	island.apply(shown_levels())


## The levels the screen shows: the shop's, with FLARE_RESTORES at 0 while the flare is on (design 10.3).
func shown_levels() -> Dictionary:
	var out: Dictionary = shop.levels.duplicate()
	if flare:
		for id: String in FLARE_RESTORES:
			out[id] = 0
	return out


## The only place a sale changes the game (on menu.closed): power, fx, island, light, flags.
func _apply_sale(sale: Dictionary) -> void:
	if sale.is_empty():
		return
	var id := String(sale.get("id", ""))
	if lv("healing") == 0 and not bool(sale.get("auto", false)) and id != DATA.PIXELS:
		player.heal(1) # every menu sale mends a heart until HEALING is sold (that sale included)
	if id == "" or bool(sale.get("back", false)): # BACK: keep everything, heal (0 once HEALING is sold)
		player.heal(int(sale.get("heal", 0)))
		menu_closed.emit(sale)
		return
	last_sold = id
	prog.gain(sale.get("power", {}), lv("healing") == 0)
	if id == DATA.PIXELS:
		lantern_power = minf(lantern_power + POWER_BACK, 1.0) # the spent lantern takes the screen's light back
		if shop.lv(DATA.PIXELS) % PIXEL_MEND == 0:
			player.heal(1) # P8b M3: the comeback mends a heart every PIXEL_MEND pixels
	if id == DATA.CONFIRM or bool(sale.get("refill", false)):
		player.hp = player.max_hp # CONFIRM SALES refills every heart, even with HEALING sold
	enemy_tempo = _tempo()
	if bool(sale.get("auto", false)) and id != DATA.PIXELS:
		_stage_sale(id)
	else:
		fx.apply(shown_levels())
		island.apply(shown_levels())
	light.sell(id)
	menu_closed.emit(sale)


## BUY BACK (design 9.4): the row's step comes back (it reverts, being read live) and its power stays: no gain,
## no last_sold. The level-up heals as for a sale until HEALING is sold (a bought-back HEALING heals). The sell
## stream runs outward, the lantern lending the setting back.
func _apply_buy_back(sale: Dictionary) -> void:
	if lv("healing") == 0:
		player.heal(1)
	enemy_tempo = _tempo()
	fx.apply(shown_levels())
	island.apply(shown_levels())
	light.stream_out(String(sale.get("id", "")))
	fx.buy_back()
	menu_closed.emit(sale)


## A self-sale's staged effect (design 10.2): fx.stage first (the PARTICLES staging streams the motes on screen
## into the lantern), then the island's part of it (BRIGHTNESS: the lights go out from the farthest to Wick).
func _stage_sale(id: String) -> void:
	fx.stage(id)
	if id == "brightness":
		island.apply_staged(shown_levels(), fx.BRIGHTNESS_WAVE, wick_feet())
	else:
		island.apply(shown_levels())


# ---- the finale -------------------------------------------------------------------------------------------------

## B1, the swell (design 10.1): the last player menu closed and the next level-up is the forced CONFIRM menu.
## The tide starts, the night band creeps in from the screen edges, two lines.
func _start_swell() -> void:
	_swelled = true
	director.set_tide("swell")
	_dark_edges(EDGE_SWELL, EDGE_SWELL_SECS)
	_say("finale.swell", "ice", SAY)
	_say("finale.need_power", "ice", SAY, NEED_POWER_AFTER)


## CONFIRM SALES sold: shards turn cosmetic, the gauge fills by the clock, the self-sales start (B2: each one
## charges the blast; the tide comes in the gaps).
func _start_closing() -> void:
	shards.cosmetic = true
	_auto_done = 0
	_gap = 0.0
	_gap_len = _gap_for(0)
	if director.tide == "":
		director.set_tide("swell") # reached CONFIRM without the swell (debug jump, magpie): the rings start here
	director.set_tide("charge")
	_lines = _lines.filter(func(l: Array) -> bool: return l[1] != "finale.need_power")
	wick.play("sell")
	_set_phase(Phase.CLOSING)
	closing_started.emit()


func _gap_for(k: int) -> float:
	return lerpf(DATA.FINALE_GAP[0], DATA.FINALE_GAP[1], clampf(k / 12.0, 0.0, 1.0))


func _step_closing(dt: float) -> void:
	if _aftermath >= 0.0: # B3: the empty island after the blast, then the relight
		_aftermath -= dt
		if _aftermath < 0.0:
			_start_relight()
		return
	_gap += dt
	if _calm and _gap >= CALM_LOOK: # B5: the calm look is over, the rest of the dark comes
		_calm = false
		director.paused = false
		director.set_tide("rest")
		_say("finale.rest", "ice", SAY)
		_overwhelm = 0.0 # P8b M2: the dark closes in to a pocket round Wick, the spent lantern sputters
		_one_heart = 0.0
		_sputter_hp = player.hp
		_edge = 0.0 # the blast blew the band away (fx cleared it)
	elif _overwhelm >= 0.0:
		_overwhelm += dt
		_one_heart = _one_heart + dt if player.hp <= 1 else 0.0
		var lost := maxi(_sputter_hp - player.hp, 0) # the light shrinks as the hits land
		var want := minf(EDGE_OVERWHELM * clampf(_overwhelm / OVERWHELM_LEN, 0.0, 1.0) + EDGE_PER_HIT * lost,
			EDGE_OVERWHELM)
		if want > _edge + 0.5:
			_dark_edges(want, EDGE_HIT_SECS)
	prog.clock_fill = clampf(_gap / maxf(_gap_len, 0.01), 0.0, 1.0)
	if _gap < _gap_len and not (_overwhelm >= OVERWHELM_MIN and _one_heart >= LAST_HEART_END):
		return
	var queue: Array = shop.finale_queue()
	if queue.is_empty() and not _flared:
		_start_blast()
		return
	if queue.is_empty():
		_start_stop("pixels") # P8b: THE LANTERN CANNOT DO THIS ALONE, then the PIXELS menu
		return
	var ctx := {"level": prog.level, "new_tab": DATA.ADVANCED_TAB, "target": "", "line": ""}
	_auto_target = queue[0]
	ctx["mode"] = "auto"
	ctx["target"] = _auto_target
	ctx["new_tab"] = DATA.tab_of(_auto_target)
	ctx["line"] = STORY.line("finale.header", "")
	ctx["blast"] = _auto_done + 1 # BLAST k/n in the menu (B2)
	ctx["blast_of"] = _auto_done + queue.size()
	_set_phase(Phase.AUTO_SALE)
	menu_opened.emit(ctx)
	menu.open(ctx)


## The PIXELS menu (the world frozen, the horde frozen round Wick): the last setting is the screen.
func _open_pixels() -> void:
	var ctx := {"level": prog.level, "new_tab": DATA.ADVANCED_TAB, "mode": "pixels", "target": DATA.PIXELS,
		"line": STORY.line("finale.pixels", "ONE SETTING LEFT. IT IS THE SCREEN.")}
	_set_phase(Phase.PIXELS_PROMPT)
	menu_opened.emit(ctx)
	menu.open(ctx)


## P8b, a stop before a decision (CONFIRM SALES, PIXELS): the world runs at STOP_SLOW for STOP_SLOW_LEN, then
## freezes; the problem line (scale 2, coral), STOP_ANSWER later the answer (cream); STOP_HOLD on, the menu opens and
## the lines go. Real seconds (the world is slowed, then frozen).
func _start_stop(kind: String) -> void:
	_stop = kind
	_stop_t = 0.0
	if kind == "confirm":
		_stopped = true
	else:
		_dark_edges(maxf(_edge, EDGE_OVERWHELM), STOP_SLOW_LEN) # an early end: the pocket closes now
	_set_phase(Phase.STOP)


func _step_stop(dt: float) -> void:
	var was := _stop_t
	_stop_t += dt
	var ids: Array = STOP_LINES[_stop]
	if was < STOP_SLOW_LEN and _stop_t >= STOP_SLOW_LEN:
		_update_frozen() # the freeze
		stop_line.emit(ids[0], "coral", 2, STOP_Y)
	if was < STOP_SLOW_LEN + STOP_ANSWER and _stop_t >= STOP_SLOW_LEN + STOP_ANSWER:
		stop_line.emit(ids[1], "cream", 1, STOP_Y + STOP_GAP)
	if _stop_t < STOP_SLOW_LEN + STOP_ANSWER + STOP_HOLD:
		return
	var kind := _stop
	_stop = ""
	stop_cleared.emit()
	if kind == "confirm":
		_open_menu() # the forced CONFIRM menu (the stop has played)
	else:
		_open_pixels()


## B3, the blast (design 10.3): the queue ran out. The world freezes, Wick raises the lantern, the night band
## surges; at BLAST_RING_AT the shockwave leaves the lantern and every enemy dies as it passes (_step_blast).
func _start_blast() -> void:
	_blast_t = 0.0
	charge = 1.0
	wick.play("levelup")
	_dark_edges(_edge + EDGE_SURGE, BLAST_RING_AT)
	_set_phase(Phase.BLAST)


func _step_blast(dt: float) -> void:
	var was := _blast_t
	_blast_t += dt
	if was < BLAST_RING_AT and _blast_t >= BLAST_RING_AT:
		_blast_from = lantern()
		_blast_len = BLAST_RING
		if fx.has_method("blast"):
			_blast_len = maxf(float(fx.blast(_blast_from - view.origin())), 0.01)
		else:
			_lantern_note(-1)
		_edge = 0.0
		bullets.clear()
		hazards.clear()
	if _blast_t >= BLAST_RING_AT:
		var reach := _blast_reach()
		for i in range(enemies.size() - 1, -1, -1):
			var e = enemies[i]
			if e.pos.distance_to(_blast_from) <= reach or e.centre().distance_to(_blast_from) <= reach:
				_kill(e)
		if _blast_t >= BLAST_RING_AT + _blast_len:
			_kill_all() # off screen too
		_step_remnants(dt)
	if _blast_t >= BLAST_FREEZE:
		_kill_all()
		_blast_t = -1.0
		_aftermath = AFTERMATH
		director.paused = true # no spawns until the second tide
		wick.play("sell")
		_set_phase(Phase.CLOSING)
		_say("finale.cleared", "ice", 3.0)


## The ring's radius in screen px: fx's, else a 0.5 s ease-out past the screen diagonal.
func _blast_reach() -> float:
	if fx.has_method("blast_radius"):
		return float(fx.blast_radius())
	var u := clampf((_blast_t - BLAST_RING_AT) / _blast_len, 0.0, 1.0)
	return (1.0 - (1.0 - u) * (1.0 - u)) * Display.view_size.length() * 1.1


## Kills `e` (the normal kill: its death, the pop, cosmetic shards to the lantern).
func _kill(e) -> void:
	hurt_enemy(e, maxi(int(e.hp), 1) + 100000, Vector2.ZERO)


func _kill_all() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		_kill(enemies[i])
	bullets.clear()
	hazards.clear()


## The world is frozen in the blast, but the deaths it causes play out (enemies.gd's remnant step).
func _step_remnants(dt: float) -> void:
	for i in range(remnants.size() - 1, -1, -1):
		var r = remnants[i]
		if r.hit_stop > 0.0:
			r.hit_stop -= dt
			continue
		r.step_dead(dt)
		if r.gone:
			remnants.remove_at(i)
			if r.node != null:
				r.node.queue_free()
				r.node = null
	light.step(dt)
	shard_fx.step(dt)


## B4, the relight (design 10.3): the world frozen, Wick holds the lantern up; the HUD's prompt and a line ask
## for SPACE. Each press grows the restored look from the lantern (relight_press).
func _start_relight() -> void:
	_aftermath = -1.0
	relight_presses = 0
	_relight_t = 0.0
	_relight_done = -1.0
	_idle_t = 0.0
	wick.play("levelup")
	if fx.has_method("relight"):
		fx.relight(0.0)
	_set_phase(Phase.RELIGHT)
	_say("finale.relight", "cream", RELIGHT_IDLE + 2.0)


## One SPACE in RELIGHT (presses RELIGHT_GAP apart at least): the ring grows a twelfth, the lantern pulses and
## pours motes out to the ring's edge, the next note of the rising scale, the frame cap climbs at 3 / 6 / 9.
func relight_press() -> void:
	if not relighting() or _relight_t < RELIGHT_GAP or relight_presses >= RELIGHT_PRESSES:
		return
	_relight_t = 0.0
	_idle_t = 0.0
	relight_presses += 1
	var u := float(relight_presses) / RELIGHT_PRESSES
	charge = 1.0 - u
	_pulse = PULSE
	_lantern_note(relight_presses - 1)
	if fx.has_method("relight"):
		fx.relight(u) # it climbs the frame cap and opens the AUDIO QUALITY crush with the circle
	elif RELIGHT_FPS.has(relight_presses):
		var cap: int = RELIGHT_FPS[relight_presses]
		Engine.max_fps = cap if cap > 0 else maxi(int(fx.get("_base_fps")), 0)
	var points := PackedVector2Array()
	var reach := maxf(u * Display.view_size.length() * 0.5, 24.0)
	for k in RELIGHT_MOTES:
		points.append(lantern() + Vector2.from_angle(randf() * TAU) * reach * randf_range(0.8, 1.0))
	light.stream_out("gold", points)
	if relight_presses >= RELIGHT_PRESSES:
		_relight_done = 0.0


func _step_relight(dt: float) -> void:
	_relight_t += dt
	if _relight_done >= 0.0:
		_relight_done += dt
		if _relight_done >= RELIGHT_HOLD:
			_relit()
			_gap = 0.0
			_gap_len = CALM_LOOK + OVERWHELM_LEN
			wick.play("sell")
			_set_phase(Phase.CLOSING)
		return
	_idle_t += dt
	if _idle_t >= RELIGHT_IDLE and _relight_t >= RELIGHT_SELF: # nobody presses: the lantern finishes by itself
		relight_press()
		_idle_t = RELIGHT_IDLE


## The screen is fixed: the beauty rows show unsold (flare), the lantern is spent (RELIGHT_POWER, its lowest glow),
## the calm look starts (no spawns).
func _relit() -> void:
	relight_presses = RELIGHT_PRESSES
	charge = 0.0
	_flared = true
	flare = true
	lantern_power = RELIGHT_POWER
	if fx.has_method("relight"):
		fx.relight(1.0) # full: with flare on, fx applies the shown levels
	elif fx.has_method("flare"):
		fx.flare() # before P8's fx: the old ring (it applies the shown levels at its end)
	island.apply(shown_levels())
	_calm = true
	director.paused = true
	_say("finale.relit", "cream", 2.0)
	_say("finale.spent", "ice", SAY, 2.0)


func _reset_flare() -> void:
	flare = false
	_flared = false
	_auto_from = 1
	_hand_pixels = 0
	lantern_power = 1.0
	charge = 0.0
	relight_presses = 0
	_swelled = false
	_swell_t = 0.0
	_lines.clear()
	_edge = 0.0
	_blast_t = -1.0
	_aftermath = -1.0
	_relight_done = -1.0
	_calm = false
	_pulse = 0.0
	_stop = ""
	_stop_t = 0.0
	_stopped = false
	_overwhelm = -1.0
	_one_heart = 0.0
	_sputter_hp = 0


## One press in the PIXELS menu sold 1% (design 10.4; the world stays frozen): power, the note, the dead blocks,
## and the last-light stages by the pixels sold.
func _on_pixel_sold(sale: Dictionary) -> void:
	if phase != Phase.PIXELS_PROMPT or sale.is_empty():
		return
	var first: bool = _hand_pixels == 0
	_hand_pixels += 1
	_apply_sale(sale)
	if first:
		wick.play("sell")
		_stage = 0
		pixels_stage.emit(0)
	_pixels_toast()


## AUTO-SELL: the rest of the pixels sell themselves while the world runs.
func _start_auto_pixels() -> void:
	_auto_from = shop.lv(DATA.PIXELS)
	_pixel_t = 0.0
	_black_t = 0.0
	prog.clock_fill = 0.0
	director.paused = false
	director.set_tide("close" if DATA.PIXEL_STEPS - shop.lv(DATA.PIXELS) <= CLOSE_AT else "stand") # B6
	_set_phase(Phase.PIXELS)


## The automatic PIXELS steps, faster and faster over the steps left (design 10.4), then DISPLAY: OFF once the
## screen is black.
func _step_pixels(dt: float) -> void:
	var sold: int = shop.lv(DATA.PIXELS)
	if sold >= DATA.PIXEL_STEPS:
		prog.clock_fill = 1.0
		_black_t += dt
		if fx.screen_black() or _black_t >= BLACK_WAIT:
			_display_off()
		return
	var u := clampf(float(sold - _auto_from) / float(maxi(DATA.PIXEL_STEPS - 1 - _auto_from, 1)), 0.0, 1.0)
	var step_len := lerpf(DATA.PIXEL_STEP_LEN[0], DATA.PIXEL_STEP_LEN[1], u)
	_pixel_t += dt
	prog.clock_fill = clampf(_pixel_t / step_len, 0.0, 1.0)
	if _pixel_t < step_len:
		return
	_pixel_t -= step_len
	var sale: Dictionary = shop.sell(DATA.PIXELS, true)
	if sale.is_empty():
		return
	_apply_sale(sale)
	_pixels_toast()


func _pixels_toast() -> void:
	var left: int = DATA.PIXEL_STEPS - shop.lv(DATA.PIXELS)
	menu.toast("PIXELS %d%%" % left, PIXEL_TOAST)
	while _stage < PIXEL_STAGES.size() and left <= PIXEL_STAGES[_stage]:
		_stage += 1
		pixels_stage.emit(_stage)
	if left <= CLOSE_AT and director.tide == "stand":
		director.set_tide("close") # the screen fills with eyes
	if left <= 1 and _stage < 4:
		_stage = 4
		pixels_stage.emit(4)
	var sold: int = shop.lv(DATA.PIXELS) # P8b M3: the lantern pushes the dark back out
	_dark_edges(EDGE_OVERWHELM * (1.0 - clampf(float(sold) / EDGE_GONE_AT, 0.0, 1.0)), 0.3)


## DISPLAY: OFF: the shards vanish, the fighting stops, the lantern and the eyes stay for the ending.
func _display_off() -> void:
	flare = false # the ending reads the shop's levels (everything still sold); the screen is black anyway
	shards.reset()
	bullets.clear()
	hazards.clear()
	_set_phase(Phase.OFF)
	display_off_reached.emit(summary())


# ---- phase bookkeeping and events ---------------------------------------------------------------------------------

func _set_phase(p: int) -> void:
	phase = p
	_update_frozen()
	phase_changed.emit(p)


func _update_frozen() -> void:
	var was := frozen
	frozen = paused or not started or not (PLAYING.has(phase) or (phase == Phase.STOP and _stop_t < STOP_SLOW_LEN))
	if frozen and not was:
		shards.freeze()
	elif was and not frozen:
		shards.thaw()


func _on_shard_landed(_light: float, _fill: float) -> void:
	gauge_revealed = true


## Off-screen threats for the HUD pips (refreshed every step): owls locking on Wick from outside the view, magpies
## outside it. Formation pips come from formation_coming (the HUD listens).
func _threats() -> void:
	view.warn.clear()
	var rect := view_rect()
	for e in enemies:
		if rect.has_point(e.pos):
			continue
		var kind: int = e.kind
		if kind == KIND_OWL and e.phase == OWL.Phase.LOCK:
			view.warn.append({"pos": e.pos, "kind": "owl"})
			hud.warn(e.pos, "owl")
		elif kind == KIND_MAGPIE:
			view.warn.append({"pos": e.pos, "kind": "magpie"})
			hud.warn(e.pos, "magpie")


func _stars_pending() -> int:
	return int(shards.stars_pending()) if shards.has_method("stars_pending") else 0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE and relighting() and not paused:
		relight_press()
		get_viewport().set_input_as_handled()
		return
	if key == null or not key.pressed or key.echo or not OS.is_debug_build() or not debug_keys or frozen:
		return
	if DEBUG_KEYS.has(key.keycode):
		_debug_spawn(DEBUG_KEYS[key.keycode])
	elif key.keycode == KEY_0:
		for id in DIRECTOR.KINDS:
			_debug_spawn(id)
	elif key.keycode == KEY_F5 and not closing():
		prog.add_light(maxf(prog.need - prog.light, 0.0) + 0.001)
	else:
		return
	get_viewport().set_input_as_handled()


func _debug_spawn(id: String) -> void:
	var at := wick_feet()
	for i in 12:
		var p := wick_feet() + Vector2.from_angle(randf() * TAU) * randf_range(DEBUG_RING.x, DEBUG_RING.y)
		if open(p):
			at = p
			break
	spawn(id, at)


## A finale line through main's narration, now or after `delay` s of play.
func _say(id: String, colour: String, secs: float, delay := 0.0) -> void:
	if delay <= 0.0:
		finale_line.emit(id, colour, secs)
	else:
		_lines.append([delay, id, colour, secs])


func _step_lines(dt: float) -> void:
	if _lines.is_empty():
		return
	for l: Array in _lines.duplicate():
		l[0] -= dt
		if l[0] <= 0.0:
			_lines.erase(l)
			finale_line.emit(l[1], l[2], l[3])


## The night band at the screen edges (fx.dark_edges, P8's fx; nothing before it lands).
func _dark_edges(px: float, secs: float) -> void:
	_edge = px
	if fx.has_method("dark_edges"):
		fx.dark_edges(px, secs)


## Lantern note `i` of the relight's rising scale (-1: the blast's low D), audible with SOUND sold: fx.lantern_note
## when P8's fx has it, else settings_fx's lantern players (the nearest loaded note, pitched).
func _lantern_note(i: int) -> void:
	if fx.has_method("lantern_note"):
		fx.lantern_note(i)
		return
	var players = fx.get("_lantern")
	if not players is Dictionary or players.is_empty():
		return
	var midi: int = 62 if i < 0 else RELIGHT_NOTES[clampi(i, 0, RELIGHT_NOTES.size() - 1)]
	var near := -1
	for m: int in players:
		if near < 0 or absi(m - midi) < absi(near - midi):
			near = m
	var p: AudioStreamPlayer = players[near]
	p.pitch_scale = pow(2.0, (midi - near) / 12.0)
	p.volume_db = -5.0 # settings_fx MUSIC_DB
	p.play()


## Wick's lantern sprite tier: the forms' glow, brighter with the blast's charge, dimmed while the lantern is spent.
func _lantern_tier() -> int:
	var t: int = light.glow_tier()
	var glow := maxf(charge, _pixel_glow())
	if glow > 0.0:
		t = maxi(t, 1 if glow < 0.5 else 2)
	if lantern_power < 1.0:
		t = mini(t, 0 if lantern_power < 0.75 else 1)
	return t


## Above the screen effects (Top): the lantern's halo (a dithered gold band around the glass, GLOW_PX by the
## charge, swelling on each relight press), then the relight's SPACE prompt (hud.gd draws it).
func _paint_glow() -> void:
	_paint_eyes()
	_paint_halo()
	if relighting() and hud.has_method("draw_relight_key"):
		hud.draw_relight_key(top, player_pos - view.origin()) # the prompt reads above the wrecked screen
	if not started or display_off() or dead():
		return
	var o := view.origin()
	var last: bool = player.hp == 1 and (_swelled or shop.closing()) and show_wick and hud.has_method("draw_last_heart")
	var heart_at := player_pos - o - Vector2(0.0, LAST_HEART_Y)
	if phase == Phase.CLOSING and not _flared and _aftermath < 0.0 and shop.closing() and hud.has_method("draw_blast_tag"):
		var tag_at := lantern() - o - Vector2(0.0, BLAST_TAG_Y)
		if last:
			tag_at.y = minf(tag_at.y, heart_at.y - 8.0) # stacked over LAST HEART
		hud.draw_blast_tag(top, tag_at, _auto_done, _auto_done + shop.finale_queue().size()) # P8b B2: the charge
	if last and fmod(anim_time, LAST_HEART_BLINK * 2.0) < LAST_HEART_BLINK:
		hud.draw_last_heart(top, heart_at) # whatever the HUD shows


## P8b: while the night band is in on a clean screen (the swell, the overwhelm), the enemies' eyes show over it (as
## they do from PIXELS on), so the swarm in the dark reads.
func _paint_eyes() -> void:
	if not started or finale() or display_off() or not ((_edge > 0.0 and not shards.cosmetic) or _sputtering()):
		return
	top.draw_set_transform(-view.origin())
	for e in enemies:
		e.draw_eyes(top)
	top.draw_set_transform(Vector2.ZERO)


## The spent lantern sputters in the overwhelm (P8b M2): from the second tide's first ring to the first pixel sold.
func _sputtering() -> bool:
	return _overwhelm >= 0.0 and flare and not finale()


## The lantern's glow in PIXELS (P8b M3), 0..1 in the B2 halo's notches: it grows back with the pixels sold.
func _pixel_glow() -> float:
	if shop == null or not finale() or display_off():
		return 0.0
	var notches := 13.0
	return ceilf(clampf(shop.lv(DATA.PIXELS) / PIXEL_GLOW_FULL, 0.0, 1.0) * notches) / notches


## The halo's radius now (0 = none): the blast's charge (B2), the pixels' power (M3), or the sputter (M2: it shrinks
## with the hearts lost since the first ring and flickers down, more often on fewer hearts); a relight press swells it.
func _halo_r() -> float:
	var r := 0.0
	if charge > 0.0:
		r = lerpf(GLOW_PX[0], GLOW_PX[1], charge)
	elif _pixel_glow() > 0.0:
		r = lerpf(GLOW_PX[0], GLOW_PX[1], _pixel_glow())
	elif _sputtering():
		var u := clampf(float(player.hp - 1) / maxf(_sputter_hp - 1, 1.0), 0.0, 1.0)
		r = lerpf(GLOW_PX[0], SPUTTER_PX, u)
		var noise := float(absi(hash(int(anim_time / SPUTTER_TICK))) % 1000) / 1000.0
		if noise < lerpf(0.3, 0.08, u):
			r = -1.0 # it gutters out for a frame: _paint_halo darkens the glass
		elif noise < lerpf(0.6, 0.25, u):
			r *= 0.6
	if _pulse > 0.0:
		r = maxf(r, GLOW_PX[0]) + 4.0 * _pulse / PULSE
	return r


func _paint_halo() -> void:
	if not started or not show_wick or display_off() or dead():
		return
	var r := _halo_r()
	var out := r < 0.0 # the sputter: a night dither over the glass for a frame
	if out:
		r = SPUTTER_DARK
	elif r <= 4.0:
		return
	var c := lantern().round()
	var o := view.origin()
	if r != _halo_key_r or out != _halo_key_out:
		_halo_key_r = r
		_halo_key_out = out
		_halo_baked.clear()
	var phase := (int(c.y) & 3) * 4 + (int(c.x) & 3) # the dither grid's phase under the glass
	if not _halo_baked.has(phase):
		_halo_baked[phase] = true
		_bake_halo(phase, r, out, c)
	var reach := ceili(r)
	top.draw_texture(_halo_texs[phase], c - Vector2(reach, reach) - o)


## Dithers the halo (a band from 4 px out to `r`, the whole disc when `out`) as seen under dither grid `phase`
## into its texture: one texel per screen pixel, centred on the glass `c`. _paint_halo calls it for a phase it has
## not baked since the radius or the sputter flag last changed.
func _bake_halo(phase: int, r: float, out: bool, c: Vector2) -> void:
	var reach := ceili(r)
	var side := reach * 2 + 1
	var img: Image = _halo_imgs.get(phase)
	var fresh := img == null or img.get_width() != side
	if fresh:
		img = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		_halo_imgs[phase] = img
	else:
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var inner := 0.0 if out else 4.0
	var span := maxf(r - inner, 1.0)
	var base := 0.75 if out else 0.45
	var half := (inner + r) * 0.5
	var gold: Color = PAL["gold"]
	var apricot: Color = PAL["apricot"]
	var night: Color = PAL["night"]
	var cx := int(c.x)
	var cy := int(c.y)
	for y in range(-reach, reach + 1):
		var spread := r * r - float(y * y)
		if spread < -1.0:
			continue # the row lies wholly outside the disc
		var wide := mini(ceili(sqrt(maxf(spread, 0.0))) + 1, reach) # |x| beyond it is out of reach
		for x in range(-wide, wide + 1):
			var d := sqrt(float(x * x + y * y))
			if d < inner or d > r:
				continue
			var level := base * (1.0 - (d - inner) / span)
			if BAYER[((cy + y) & 3) * 4 + ((cx + x) & 3)] / 16.0 < level:
				img.set_pixel(x + reach, y + reach, night if out else gold if d < half else apricot)
	if fresh:
		_halo_texs[phase] = ImageTexture.create_from_image(img)
	else:
		_halo_texs[phase].update(img)


func _draw() -> void:
	if light == null or not started or display_off():
		return
	var origin := view.origin()
	draw_set_transform(origin)
	light.draw_stream(self, lantern() - origin)
	draw_set_transform(Vector2.ZERO)


# ---- Brain facade (scripts/cast/enemies/README.md; keep the names) ----

## Wick's feet on the map (ground point).
func wick_feet() -> Vector2:
	return player.feet.round()


## The centre of Wick's body.
func wick_body() -> Vector2:
	return player_pos


## The lantern glass: where shots leave from.
func lantern() -> Vector2:
	return wick_feet() + wick.emit()


## The lantern's glow tier 0-2 (from the light's powers).
func glow_tier() -> int:
	return light.glow_tier()


## The shots' damage tier (bell toll I-III), 0 = none.
func damage_tier() -> int:
	return light.damage_tier()


## The level of setting `id` in the shop (0 = not sold; "pixels" = % dead). HIT FLASH reads 0 while its
## self-sale's unison flash plays; FLARE_RESTORES read 0 while the flare is on.
func lv(id: String) -> int:
	if shop.rev != _lv_rev:
		_lv_rev = shop.rev
		for hot: String in LV_HOT:
			_lv_hot[hot] = 0 if flare else shop.lv(hot)
	var hot_lv: int = _lv_hot.get(id, -1)
	if hot_lv >= 0: # all three are FLARE_RESTORES rows
		return 0 if hot_lv > 0 and id == "hit_flash" and fx.unison_flash > 0.0 else hot_lv
	if flare and FLARE_RESTORES.has(id):
		return 0
	if id == "hit_flash" and fx.unison_flash > 0.0:
		return 0
	return shop.lv(id)


## The director's clock in seconds (start_at included).
func clock() -> float:
	return director.time()


## ANIMATIONS sold: sprites hold their first frame (README.md contract; movement goes on).
func still() -> bool:
	if shop.rev != _lv_rev:
		lv("animations") # reads the hot rows again
	return _lv_hot["animations"] > 0


## The 2 s animation loop's tick 0-23 (0 while ANIMATIONS is sold).
func tick() -> int:
	return 0 if still() else int(anim_time * 12.0) % 24


## True from the first pixel sold (by hand or not) to DISPLAY: OFF and after (shop.reset clears it).
func finale() -> bool:
	return shop != null and shop.lv(DATA.PIXELS) > 0


## True once the screen is off (phase OFF).
func display_off() -> bool:
	return phase == Phase.OFF


## The visible world rectangle.
func view_rect() -> Rect2:
	return view.view_rect()


## A walkable point just outside the view, for spawns.
func edge_point() -> Vector2:
	return view.edge_point()


## True if `p` is on the island and clear of colliders on physics `mask` (1 walk, 2 shots).
func open(p: Vector2, mask := 1) -> bool:
	return view.open(p, mask)


## True if a shot can pass `p` (physics layer 2; the rim ignored).
func shot_open(p: Vector2) -> bool:
	return view.open(p, 2, false)


## Moves enemy `e` by `step`, sliding around solid props and slowed on rough ground (flyers only stay on the
## island); returns the new position.
func walk(e, step: Vector2, fly := false) -> Vector2:
	var mask := 0 if fly else 1
	if not fly:
		step *= view.ground_speed(e.pos)
	if view.open(e.pos + step, mask):
		return e.pos + step
	if view.open(e.pos + Vector2(step.x, 0), mask):
		return e.pos + Vector2(step.x, 0)
	if view.open(e.pos + Vector2(0, step.y), mask):
		return e.pos + Vector2(0, step.y)
	return e.pos


## The crowd push on enemy `e` from its neighbours.
func separation(e) -> Vector2:
	return enemies_host.separation(e)


## Light pools on the map (x, y, radius); empty once BRIGHTNESS is sold.
func light_pools() -> PackedVector3Array:
	return PackedVector3Array() if lv("brightness") > 0 else view.pools


## Adds an enemy projectile (scripts/cast/enemies/hazard.gd).
func add_hazard(h: RefCounted) -> void:
	h.set("game", self)
	hazards.append(h)
	stat("hazards")


## Plays an enemy sound through the thinning rules (gaps, voices, tells).
func enemy_sound(sfx: String) -> void:
	enemies_host.sound(sfx, anim_time)


## The magpie's star: grants one level-up (shards run the gauge up the ladder; queued if a menu is open).
func free_level_up() -> void:
	if closing():
		return
	shards.star(lantern())


## Plays a light_fx overlay sheet at `pos` (kill dissolves and the like).
func light_overlay(sheet: String, pos: Vector2) -> void:
	light.overlay(sheet, pos)


## Spawns `count` enemies of kind `id` around `anchor`; returns the brain at `index`.
func spawn(id: String, anchor: Vector2, index := 0, count := 1) -> RefCounted:
	var e := enemies_host.spawn(id, anchor, index, count)
	if id == "magpie" and not view_rect().has_point(e.pos):
		hud.warn(e.pos, "magpie")
	return e


## How many enemies of kind `id` are alive.
func alive(id: String) -> int:
	return enemies_host.alive(id)


## Adds `n` to the check counter `key` in `stats`.
func stat(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n


## Damages enemy `e` (`from` = the hit's source, for the toad's parasol); kills it at 0 hp.
func hurt_enemy(e, dmg: int, push: Vector2, from := Vector2.INF) -> void:
	enemies_host.hurt_enemy(e, dmg, push, from)


## A kill (from enemies.gd): the shards drop, the signal goes out.
func on_kill(id: String, at: Vector2) -> void:
	if id != "magpie":
		shards.drop(at, id)
	killed.emit(id, at)
