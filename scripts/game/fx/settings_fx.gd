extends Node
## Screen and audio handicaps (design 9.3), the staged finale effects (design 10.2), the music cues (design 14) and
## every sound effect. main.tscn's Fx node: `setup(run)` builds the CanvasLayer 5 screen rect and shader, the Music
## bus and the players. The run calls apply(levels) after every player sale (stage(id) for the menu's own sales),
## step() every frame, and the cues menu(), level_up(), died(), ending(), title() as they happen.
## Music: Lantern Gothic, made by docs/soundtrack/round2/lantern_gothic/soundtrack.py; the run track by
## docs/soundtrack/round3/arc.py: the lantern opening, the theme, Night, then Last light (D major) for good, as
## phrases that run_music.gd orders by the run time (menus stop the world, not the music, so the arc holds instead
## of running ahead). The level-up stings and the shard chimes follow its part.

const SHADER := preload("res://scripts/game/fx/screen_fx.gdshader")
const RunMusic := preload("res://scripts/game/fx/run_music.gd")
const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
## Every music file plays at this volume; soundtrack.py bakes in their levels against each other. The run loop
## is -16 LUFS, so it lands at -21 LUFS.
const MUSIC_DB := -5.0
const MUSIC_BUS := "Music"
## Base volume of each sound effect in dB (they follow the SOUND level). .ogg or .wav in SFX_DIR.
const SFX_DB := {"shoot": -16.0, "hit": -8.0, "kill": -6.0, "hurt": -2.0, "sell": 0.0, "pick": -8.0,
		"tab": -10.0, "crack": -14.0, "pause": -16.0, "snuff": -18.0,
		# Enemies (run.enemy_sound; Kenney CC0 foley, tonal ones on D or A). Set by measured level: hops, pops and
		# steps sit near "shoot", hurt and death sounds under "hit"/"kill", tells just under "kill", none near "hurt".
		"snuffer_spawn": -25.0, "snuffer_pop": -17.0, "snuffer_clatter": -21.0,
		"owl_hoot": -15.0, "owl_whoosh": -12.5, "owl_wingbeat": -14.5, "owl_thud": -22.0, "owl_ruffle": -22.0,
		"owl_puff": -17.0, "owl_squawk": -26.0,
		"magpie_chatter": -10.0, "magpie_alarm": -7.5, "magpie_squawk": -22.0, "magpie_laugh": -12.0,
		"star_chime": -11.0, "star_home": -12.0,
		"toad_block": -11.5, "toad_croak": -28.5, "toad_hop": -17.5, "toad_turn": -24.5, "toad_death": -22.0,
		"toad_whoosh": -15.0,
		"sporecap_land": -12.5, "sporecap_swell": -22.0, "sporecap_puff": -16.5, "spore_pop": -29.5,
		"sporecap_death": -19.0,
		"gloam_open": -16.5, "gloam_hush": -20.5, "gloam_tick": -19.5, "gloam_hiss": -21.0, "gloam_unravel": -16.5,
		"formation": -7.5,
		# Lantern forms (docs/soundtrack/sfx_forms.py): the BELL TOLL on A4 (tiers play pitch 1 / 0.667 / 0.5 =
		# A4, D4, A3) level with "hit"; the FIREFLY STING on D6 4 dB under it.
		"toll": -21.0, "sting": -19.5}
## Music one-shots (MUSIC_DIR + name + ".wav"). The three level-up stings take turns (they climb D6, E6, F6; under
## Last light the levelup_light ones climb D major to D6, E6, F#6).
const CUES: Array[String] = ["levelup_1", "levelup_2", "levelup_3", "levelup_light_1", "levelup_light_2",
		"levelup_light_3", "music_sold", "death", "ending"]
const STINGS := 3
## While the settings menu is open the run track is heard through a wall (the Music bus low-pass and cut).
const MUFFLE_HZ := 500.0
const MUFFLE_DB := -8.0
const MUFFLE_TIME := 0.15
const OPEN_HZ := 20000.0
## MUSIC sold: the run track slows to a stop like a tape (seconds) while the organ sighs and a bell answers.
const WIND_DOWN := 0.45
const TITLE_FADE := 1.0 ## the title loop fades out over this when the run track takes over
# Per sold step (index = level).
const GAIN: Array[float] = [1.0, 0.0]
const BRIGHTNESS: Array[float] = [1.0, 0.5]
const BLOCK: Array[float] = [1.0, 2.0, 4.0]
const FPS: Array[int] = [0, 20]
const LOWPASS_HZ := 700.0
const LOFI_DRIVE := 0.6
const PIXEL_FADE := 0.3 ## seconds for newly dead blocks to fade in
const PIXELS_MAX := 100.0
const GLOW_RADIUS := 20.0 ## px around the lantern that BRIGHTNESS never dims
const TEAR_PERIOD := 1.6 ## seconds for the VSYNC tear line to cross the screen
## Staged finale effects (design 10.2): how long each transition takes (the world runs meanwhile).
const STAGE_LEN := {"hit_flash": 0.1, "particles": 0.7, "animations": 0.0, "audio_quality": 0.6,
		"frame_rate": 0.5, "music": 0.45, "vsync": 0.3, "colour": 0.4, "brightness": 1.0, "resolution": 0.5,
		"sound": 0.0}
## BRIGHTNESS: the island's lights take this long to go out (Island.apply_staged), then the screen dims.
const BRIGHTNESS_WAVE := 0.75
const FPS_STEPS: Array[int] = [40, 30, 20]
const MOTES_MAX := 30 ## PARTICLES: at most this many island motes fly home
const CLANG_NOTE := 74 ## ANIMATIONS: the bells' last clang, the lantern's D an octave down
const CLANG_DB := -8.0
const PALETTE := preload("res://scripts/game/ui/palette.gd")
## The flare (design 10.3): the ring grows from the lantern to the screen's diagonal, four lantern notes rise, the
## frame cap climbs back to the base and the AUDIO QUALITY crush opens.
const FLARE_RING := 1.2
const FLARE_NOTES: Array[int] = [69, 74, 81, 86]
const FLARE_NOTE_GAP := 0.12
const BUY_BACK_NOTE := 69 ## BUY BACK's lantern note, A4 (loaded with FLARE_NOTES; the ending's first relight chime)
const FLARE_FPS: Array[int] = [30, 40] # the relight's frame cap climbs 20 -> 30 -> 40 -> base at 1/4, 1/2, 3/4
## P8, the finale story (docs/beta1/notes/P8_spec.md B1-B4, notes P8.md B): the dark at the screen edges, the blast
## and the relight, drawn by finale_fx.gdshader on two more full-screen rects.
const FINALE_SHADER := preload("res://scripts/game/fx/finale_fx.gdshader")
const EDGE_LAYER := 3 ## the dark at the edges: above the world (0), under the HUD (4), the sold look (5), the top (6)
const BLAST_LAYER := 7 ## the blast's ring and flash: above the top layer (6), under the menu (10)
const BLAST_RING := 0.5 ## s for the blast's ring from the lantern to past the farthest screen corner (ease out)
const BLAST_PAST := 4.0 ## px the ring ends beyond that corner
const BLAST_FLASH_FRAMES := 2 ## drawn frames of the cream flash
const RELIGHT_EASE := 0.15 ## s for the relight's circle to reach each new target
## The relight's rising scale: D harmonic minor from A4 (semitones over A of A Bb C# D E F G), an octave up every 7.
const SCALE_STEPS: Array[int] = [0, 1, 4, 5, 7, 8, 10]
const SCALE_ROOT := 69
const BLAST_TOLL := 1.0 / 3.0 ## the blast: toll.wav (A4) at 1/3 = D3 ...
const BLAST_TOLL_DB := -8.0 ## ... 8 dB under the music volume (its RMS sits 8 dB over the lantern notes')
const BLAST_LANTERN := 74 ## ... under lantern_74 (D5) at 0.5 = D4, at the music volume

## The screen shader's material (uniforms in screen_fx.gdshader).
var material: ShaderMaterial
## The run track's player (on the Music bus; stopped while MUSIC is OFF). _track plays it.
var music: AudioStreamPlayer
## Linear gain on every sound effect: 1, or 0 once SOUND is sold.
var sound_gain := 1.0
## HIT FLASH staging: seconds the unison flash still shows (run.lv("hit_flash") reads 0 meanwhile).
var unison_flash := 0.0

var _run ## run.gd (null in tests: stage() then uses the levels last applied)
var _rect: ColorRect
var _sfx := {}
var _cues := {}
var _lantern := {} # MIDI pitch -> player
var _drone: AudioStreamPlayer
var _title: AudioStreamPlayer
var _finale := {} # music.json "finale": per PIXELS step sold, the lantern note, its gain and the drone volume
var _track: RunMusic # the run track's phrases, ordered by the run time
var _notes := 0 # lantern notes played (= PIXELS steps sold)
var _sting := 0
var _menu := false
var _muffle: AudioEffectLowPassFilter
var _muffle_cut: AudioEffectAmplify
var _music_tween: Tween
var _muffle_tween: Tween
var _drone_tween: Tween
var _ending_tween: Tween
var _title_tween: Tween
var _stages: Array[Tween] = []
var _music_gain := 1.0
var _hold_music := false # after ending(): the run track stays off until start_run()
var _base_fps := -1
var _quality := 0
var _bus_fx: Array[AudioEffect] = []
var _levels := {} # the levels last applied
var _screen_active := false
var _screen_on := true
var _pixels_target := 0.0
var _pixels_shown := 0.0
var _tear_clock := 0.0
var _edges: ColorRect # the dark at the edges (EDGE_LAYER)
var _blast_rect: ColorRect # the blast's ring and flash (BLAST_LAYER)
var _edge := 0.0 # the band's depth shown (px), easing _edge_from -> _edge_to over _edge_secs
var _edge_from := 0.0
var _edge_to := 0.0
var _edge_t := 0.0
var _edge_secs := 0.0
var _blast_pos := Vector2.ZERO # whole-screen px (with Display.margin)
var _blast_t := -1.0 # s into the ring, < 0 = no ring
var _blast_len := 0.0
var _blast_r := -1.0 # the ring's radius; holds its last value after the ring until the next run
var _flash_frame := -100
var _blast_note_frame := -100
var _blast_notes: Array[AudioStreamPlayer] = []
var _scale := {} # MIDI -> the relight's own player for that note (pitch-shifted where no lantern file has it)
var _relight_r := -1.0 # the restored circle's radius shown, < 0 = no relight
var _relight_from := 0.0
var _relight_to := -1.0
var _relight_t := 0.0
var _flare_t := -1.0 # flare(): s into the timed relight, < 0 = not timed


## Builds the effect layer, the music and the sfx players; reads run.wick and run.view later. Records the frame cap.
func setup(r) -> void:
	_run = r
	_base_fps = Engine.max_fps
	_build_screen()
	_build_audio()


## Sets every handicap from the sold levels at once (missing id = 0). Called on reset ({}) and after a player sale.
func apply(levels: Dictionary) -> void:
	_kill_stages()
	_apply_screen(levels)
	var fps := FPS[_lv(levels, "frame_rate", 1)]
	Engine.max_fps = _base_fps if fps == 0 else fps
	_set_music(_lv(levels, "music", 1))
	var sold := int(levels.get("pixels", 0))
	if sold > _notes:
		_lantern_note(sold - 1)
	_notes = sold
	sound_gain = GAIN[_lv(levels, "sound", 1)]
	_set_quality(_lv(levels, "audio_quality", 1))
	_levels = levels.duplicate()
	_update_visible()


## The menu sold `id` by itself (design 10.2): applies the run's shop levels and plays that sale's staged
## transition. Returns its length in seconds (0 = instant; ids without a staging apply at once).
func stage(id: String) -> float:
	var before := _levels.duplicate()
	if _run and _run.has_method("shown_levels"):
		apply(_run.shown_levels())
	else:
		apply(_run.shop.levels if _run else _levels)
	match id:
		"hit_flash":
			_flash_all()
		"particles":
			_particles_home()
		"animations":
			_last_clang()
		"audio_quality":
			_sweep_quality()
		"frame_rate":
			_step_fps()
		"vsync":
			_drop_tear()
		"colour":
			_wipe_colours(before)
		"brightness":
			_dim_late()
		"resolution":
			_spread_blocks(before)
	return float(STAGE_LEN.get(id, 0.0))


## Every frame: eases the dead pixels in, moves the tear line, feeds Wick's and the lantern's screen positions to
## the shader. `screen_on` false (the death card) hides every screen effect.
func step(dt: float, wick_screen_pos: Vector2, screen_on: bool) -> void:
	if _pixels_shown < _pixels_target:
		var speed := maxf(1.0, (_pixels_target - _pixels_shown - 1.0) * 2.4) / PIXEL_FADE # big jumps catch up fast
		_pixels_shown = move_toward(_pixels_shown, _pixels_target, speed * dt)
		material.set_shader_parameter("dead", _pixels_shown)
	material.set_shader_parameter("center", wick_screen_pos + Display.margin)
	material.set_shader_parameter("glow_pos", _lantern_screen(wick_screen_pos) + Display.margin)
	if _lv(_levels, "vsync", 1) > 0:
		_tear_clock += dt
		var cycle := floori(_tear_clock / TEAR_PERIOD)
		var view: Vector2 = material.get_shader_parameter("view")
		material.set_shader_parameter("tear_y", fposmod(_tear_clock, TEAR_PERIOD) / TEAR_PERIOD * (view.y + 24.0) - 12.0)
		material.set_shader_parameter("tear_shift", (3.0 + (cycle * 7) % 4) * (1.0 if cycle % 2 == 0 else -1.0))
	unison_flash = maxf(unison_flash - dt, 0.0)
	_track.step(_run_time())
	_step_finale(dt)
	_screen_on = screen_on
	_update_visible()


## Plays a sound effect by name at `pitch` with a random jitter; unknown names are ignored. Silent when SOUND is
## OFF. (snuff: jitter 0.1 for the intro's wave, pitch 0.6 for Wick's breath.)
func play(sfx: String, jitter := 0.06, pitch := 1.0) -> void:
	if not _sfx.has(sfx) or sound_gain <= 0.0:
		return
	var p: AudioStreamPlayer = _sfx[sfx]
	p.volume_db = SFX_DB[sfx] + linear_to_db(sound_gain)
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.play()


## P8 B1-B2: the night band at the screen edges eases to `px` deep (0 = gone) over `secs` (0 = at once).
func dark_edges(px: float, secs := 0.5) -> void:
	_edge_from = _edge
	_edge_to = maxf(px, 0.0)
	_edge_t = 0.0
	_edge_secs = maxf(secs, 0.0)
	if _edge_secs <= 0.0:
		_edge = _edge_to
	_set_edge()


## P8 B3: the blast from `screen_pos` (game screen px, like step()'s Wick position): a cream ring to past the
## farthest screen corner in BLAST_RING s (ease out), a 2-frame cream flash, the edge band blown away as the ring
## passes, and blast_note(). Animates in step(), so it runs while the world is frozen. Returns the ring's length (s).
func blast(screen_pos: Vector2) -> float:
	_blast_pos = screen_pos + Display.margin
	var view: Vector2 = material.get_shader_parameter("view")
	_blast_len = 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(view.x, 0.0), Vector2(0.0, view.y), view]:
		_blast_len = maxf(_blast_len, _blast_pos.distance_to(corner))
	_blast_len += BLAST_PAST
	_blast_t = 0.0
	_blast_r = 0.0
	_flash_frame = Engine.get_process_frames()
	for m: ShaderMaterial in [_edges.material, _blast_rect.material]:
		m.set_shader_parameter("ring_pos", _blast_pos)
	_set_blast(0.0, true)
	blast_note()
	_update_visible()
	return BLAST_RING


## The blast ring's radius in screen px (0 at blast(), past the farthest corner at the end, and it stays there until
## the next run, so everything is "passed" from then on); -1 before any blast.
func blast_radius() -> float:
	return _blast_r


## P8 B4: the restored look (as at the end of flare()) inside a circle from the lantern, `progress` 0..1 of the
## screen diagonal; it eases to each new target over RELIGHT_EASE s and never shrinks. The frame cap climbs and the
## AUDIO QUALITY crush opens with it. Once it is full and the run's `flare` is on, the run's shown levels apply.
func relight(progress: float) -> void:
	if _relight_to < 0.0: # the first call: the circle starts at the lantern
		_kill_stages()
		_relight_r = 0.0
		_relight_to = 0.0
		_flare_t = -1.0
	var target := clampf(progress, 0.0, 1.0) * _diagonal()
	if target <= _relight_to:
		return
	_relight_from = _relight_r
	_relight_to = target
	_relight_t = 0.0


## Note `i` (from 0) of the relight's rising lantern scale, D harmonic minor from A4 up (A4 Bb4 C#5 D5 E5 F5 G5 A5
## Bb5 C#6 D6 E6 ...), at the music volume. It always sounds (SOUND sold or not, no drone), like the other lantern
## notes. lantern_<midi>.wav where it exists, else the nearest file pitch-shifted on its own player.
func lantern_note(i: int) -> void:
	var n := maxi(i, 0)
	var p := _scale_player(SCALE_ROOT + 12 * floori(n / 7.0) + SCALE_STEPS[n % 7])
	if p:
		p.volume_db = MUSIC_DB
		p.play()


## The blast's low D (BLAST_TOLL, BLAST_LANTERN). It always sounds. blast() plays it; a second call within a few
## frames is ignored, so calling both is safe.
func blast_note() -> void:
	var frame := Engine.get_process_frames()
	if frame - _blast_note_frame < 6:
		return
	_blast_note_frame = frame
	for p in _blast_notes:
		p.play()


## The glass `crack` of a padlock breaking (CONFIRM SALES).
func crack() -> void:
	play("crack", 0.1)


## BUY BACK (design 9.4): one lantern note A4 at the music volume, no drone. It always sounds, like the other
## lantern notes.
func buy_back() -> void:
	_flare_note(BUY_BACK_NOTE)


## The title's luxels (title.gd): one lantern note `down` dB under the music.
func title_note(midi: int, down: float) -> void:
	if not _lantern.has(midi):
		return
	var p: AudioStreamPlayer = _lantern[midi]
	p.pitch_scale = 1.0
	p.volume_db = MUSIC_DB - down
	p.play()


## A new run: all music stops and the wall comes down, so the next apply() starts the run track from the top.
## A title loop still playing fades out (the intro hands over to the run track).
func start_run() -> void:
	_kill_stages()
	for t: Tween in [_music_tween, _muffle_tween, _drone_tween, _ending_tween]:
		if t:
			t.kill()
	_track.stop()
	for p: AudioStreamPlayer in _cues.values() + _lantern.values() + _scale.values() + _blast_notes + [_drone]:
		p.stop()
	_reset_finale()
	if _title.playing and _title_tween == null:
		title(false)
	_menu = false
	_muffle.cutoff_hz = OPEN_HZ
	_muffle_cut.volume_db = 0.0
	_notes = 0
	_sting = 0
	_music_gain = 1.0
	_hold_music = false
	unison_flash = 0.0


## The settings menu opened or closed: while it is open the run track plays behind a wall.
func menu(open: bool) -> void:
	if open == _menu:
		return
	_menu = open
	if _muffle_tween:
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_parallel()
	_muffle_tween.tween_property(_muffle, "cutoff_hz", MUFFLE_HZ if open else OPEN_HZ, MUFFLE_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_muffle_tween.tween_property(_muffle_cut, "volume_db", MUFFLE_DB if open else 0.0, MUFFLE_TIME)


## A level-up: the next sting in turn (the D major set under Last light), unless MUSIC is sold.
func level_up() -> void:
	_cue(("levelup_light_%d" if music_part() == "light" else "levelup_%d") % (_sting % STINGS + 1))
	_sting += 1


## WICK FELL: the run track stops and the death sting plays, unless MUSIC is sold.
func died() -> void:
	_stop_music(0.12)
	_cue("death")


## DISPLAY: OFF: the run track stays off from here (the ending drives the drone with drone_to() and starts the
## ending theme itself with play_cue("ending")); pending cues stop.
func ending() -> void:
	_hold_music = true
	if _ending_tween:
		_ending_tween.kill()


## Fades the finale drone to `db` over `secs` (db <= -60 stops it). It starts if it was silent.
func drone_to(db: float, secs: float) -> void:
	if _drone_tween:
		_drone_tween.kill()
	if db > -60.0 and not _drone.playing:
		_drone.volume_db = -60.0
		_drone.play()
	_drone_tween = create_tween()
	_drone_tween.tween_property(_drone, "volume_db", maxf(db, -60.0), maxf(secs, 0.001))
	if db <= -60.0:
		_drone_tween.tween_callback(_drone.stop)


## Plays a music one-shot (CUES) at the music volume, whatever MUSIC's level (the ending theme, renders).
func play_cue(cue: String) -> void:
	if _cues.has(cue):
		_cue(cue, true)


## The title loop: on starts it from the top (the run track stops); off fades it out over TITLE_FADE.
func title(on: bool) -> void:
	if _title_tween:
		_title_tween.kill()
		_title_tween = null
	if on:
		_hold_music = true
		_stop_music(0.0)
		_cues["ending"].stop()
		_title.volume_db = MUSIC_DB
		if not _title.playing:
			_title.play()
		return
	if not _title.playing:
		return
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "volume_db", MUSIC_DB - 40.0, TITLE_FADE).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN)
	_title_tween.tween_callback(func() -> void:
		_title.stop()
		_title_tween = null)


## True while the run track plays (false once MUSIC is sold, also while it winds down).
func music_on() -> bool:
	return music.playing and _music_gain > 0.0


## The part of the run track playing: "night", "light" (Last light) or "" (the theme in D minor, or no track).
func music_part() -> String:
	return _track.part() if music_on() else ""


## Semitones that move a D harmonic minor pitch into the run track's key: Night flattens E (its Eb), Last light
## raises F, Bb and C (D major). The shard chimes and bells use it.
func key_shift(midi: int) -> int:
	match music_part():
		"night":
			return -1 if midi % 12 == 4 else 0
		"light":
			return 1 if midi % 12 in [5, 10, 0] else 0
	return 0


## Run track time in seconds for the shard grid (on its beats), -1 when not playing.
func music_clock() -> float:
	return _track.clock() if music_on() else -1.0


## True once the PIXELS effect shows the full 100% (the screen is black, the ending may start).
func screen_black() -> bool:
	return _pixels_shown >= PIXELS_MAX


## Undoes every handicap (restart, title): clean screen, the original frame cap, no Master effects, full sound.
## The music is left alone.
func restore() -> void:
	_kill_stages()
	if material:
		_apply_screen({})
		_pixels_shown = 0.0
		material.set_shader_parameter("dead", 0.0)
		_update_visible()
	if _base_fps >= 0:
		Engine.max_fps = _base_fps
	_remove_bus_fx()
	sound_gain = 1.0
	_levels = {}
	unison_flash = 0.0
	if _edges:
		_reset_finale()


func _exit_tree() -> void:
	restore()
	if _muffle:
		_remove_effects(AudioServer.get_bus_index(MUSIC_BUS), [_muffle, _muffle_cut])


# --- screen ------------------------------------------------------------------------------------------------------

func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ring_colour", PALETTE.PAL["cream"])
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = material
	_rect.visible = false
	layer.add_child(_rect)
	_edges = _finale_rect(EDGE_LAYER, 0)
	_blast_rect = _finale_rect(BLAST_LAYER, 1)
	_fit_screen()
	Display.changed.connect(_fit_screen)


## A full-screen rect for finale_fx.gdshader (`mode` 0 = the dark at the edges, 1 = the blast) on its own layer.
func _finale_rect(index: int, mode: int) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = index
	add_child(layer)
	var m := ShaderMaterial.new()
	m.shader = FINALE_SHADER
	m.set_shader_parameter("mode", mode)
	for c: String in ["void", "night", "cream"]:
		m.set_shader_parameter(c + "_colour", PALETTE.PAL[c])
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = m
	r.visible = false
	layer.add_child(r)
	return r


## The effects cover the whole screen, also the margin around the game screen when Display fills a bigger one.
func _fit_screen() -> void:
	var screen := Display.screen_rect()
	for r: ColorRect in [_rect, _edges, _blast_rect]:
		r.position = screen.position
		r.size = screen.size
		(r.material as ShaderMaterial).set_shader_parameter("view", screen.size)


func _apply_screen(levels: Dictionary) -> void:
	var colour := _lv(levels, "colour", 2)
	var brightness := _lv(levels, "brightness", 1)
	var resolution := _lv(levels, "resolution", 2)
	var vsync := _lv(levels, "vsync", 1)
	if vsync > 0 and _lv(_levels, "vsync", 1) == 0:
		_tear_clock = 0.0
	material.set_shader_parameter("colours", colour)
	material.set_shader_parameter("colours_prev", colour)
	material.set_shader_parameter("wipe", 1.0)
	material.set_shader_parameter("brightness", BRIGHTNESS[brightness])
	material.set_shader_parameter("glow_radius", GLOW_RADIUS if brightness > 0 else 0.0)
	material.set_shader_parameter("block", BLOCK[resolution])
	material.set_shader_parameter("block_prev", BLOCK[resolution])
	material.set_shader_parameter("block_radius", -1.0)
	material.set_shader_parameter("tear", float(vsync))
	material.set_shader_parameter("fov_radius", 0.0)
	material.set_shader_parameter("clear_radius", -1.0)
	_screen_active = colour + brightness + resolution + vsync > 0
	_pixels_target = clampf(float(levels.get("pixels", 0)), 0.0, PIXELS_MAX)
	_pixels_shown = minf(_pixels_shown, _pixels_target) # pixels bought back return at once
	material.set_shader_parameter("dead", _pixels_shown)


func _update_visible() -> void:
	_rect.visible = _screen_on and (_screen_active or _pixels_shown > 0.0)
	_edges.visible = _screen_on and _edge > 0.0
	_blast_rect.visible = _screen_on and (_blast_t >= 0.0 or _flashing())


## The lantern glass on screen: run.lantern() through the view, else a little above Wick.
func _lantern_screen(wick_screen_pos: Vector2) -> Vector2:
	if _run and _run.view and _run.view.has_method("origin"):
		return _run.lantern() - _run.view.origin()
	return wick_screen_pos + Vector2(0, -10)


# --- staged finale effects (design 10.2) ---------------------------------------------------------------------

func _stage_tween() -> Tween:
	var t := create_tween()
	_stages.append(t)
	return t


func _kill_stages() -> void:
	for t in _stages:
		if t.is_valid():
			t.kill()
	_stages.clear()


## HIT FLASH: every enemy flashes white once, together, then never again.
func _flash_all() -> void:
	unison_flash = STAGE_LEN["hit_flash"]
	if _run == null:
		return
	for e in _run.enemies:
		if "flash" in e:
			e.flash = unison_flash


## PARTICLES: each mote, firefly and petal on screen flies into the lantern as a sell mote.
func _particles_home() -> void:
	if _run == null or _run.island == null or _run.light == null:
		return
	var view: Rect2 = _run.view_rect()
	var points := PackedVector2Array()
	for s: Node in _run.island.get_tree().get_nodes_in_group("setting_particles"):
		if s is Node2D and view.has_point(s.global_position) and points.size() < MOTES_MAX:
			points.append(s.global_position)
	if not points.is_empty():
		_run.light.stream_from(points, "particles")


## ANIMATIONS: the bells give one last clang as everything stops.
func _last_clang() -> void:
	if sound_gain <= 0.0 or not _lantern.has(CLANG_NOTE):
		return
	var p: AudioStreamPlayer = _lantern[CLANG_NOTE]
	p.pitch_scale = 0.5
	p.volume_db = CLANG_DB
	p.play()
	_stage_tween().tween_interval(2.0)
	_stages[-1].tween_callback(func() -> void: p.pitch_scale = 1.0)


## AUDIO QUALITY: the Master low-pass sweeps 20 kHz -> 700 Hz while the lo-fi crush fades in.
func _sweep_quality() -> void:
	if _bus_fx.size() < 2:
		return
	var low_pass := _bus_fx[0] as AudioEffectLowPassFilter
	var crush := _bus_fx[1] as AudioEffectDistortion
	low_pass.cutoff_hz = OPEN_HZ
	crush.drive = 0.0
	var t := _stage_tween().set_parallel()
	var secs: float = STAGE_LEN["audio_quality"]
	t.tween_property(low_pass, "cutoff_hz", LOWPASS_HZ, secs).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(crush, "drive", LOFI_DRIVE, secs)


## FRAME RATE: the cap steps 60 -> 40 -> 30 -> 20.
func _step_fps() -> void:
	var t := _stage_tween()
	var gap: float = STAGE_LEN["frame_rate"] / (FPS_STEPS.size() - 1)
	for i in FPS_STEPS.size():
		if i > 0:
			t.tween_interval(gap)
		t.tween_callback(func() -> void: Engine.max_fps = FPS_STEPS[i])


## VSYNC: the tear line drops in from the top as the rows start to shift.
func _drop_tear() -> void:
	_tear_clock = 0.0
	material.set_shader_parameter("tear", 0.0)
	_stage_tween().tween_property(material, "shader_parameter/tear", 1.0, STAGE_LEN["vsync"])


## COLOURS: the palette collapse wipes down the screen (4 colours) or up it (2 colours).
func _wipe_colours(before: Dictionary) -> void:
	var now := _lv(_levels, "colour", 2)
	material.set_shader_parameter("colours_prev", _lv(before, "colour", 2))
	material.set_shader_parameter("wipe_down", now <= 1)
	material.set_shader_parameter("wipe", 0.0)
	_stage_tween().tween_property(material, "shader_parameter/wipe", 1.0, STAGE_LEN["colour"])


## BRIGHTNESS: the island's lights go out first (the run calls Island.apply_staged), then the screen dims.
func _dim_late() -> void:
	material.set_shader_parameter("brightness", 1.0)
	var t := _stage_tween()
	t.tween_interval(BRIGHTNESS_WAVE)
	t.tween_property(material, "shader_parameter/brightness", BRIGHTNESS[1], STAGE_LEN["brightness"] - BRIGHTNESS_WAVE)


## The flare (design 10.3), kept for runs that still call it: a timed relight 0 -> 1 over FLARE_RING (quad ease
## out) with the four notes rising (always, without the drone); the frame cap climbs and the lo-fi crush opens with
## the ring, and at its end the run's shown levels apply (step() -> _step_finale). Returns the ring's length.
func flare() -> float:
	relight(0.0)
	_relight_from = 0.0
	_relight_to = _diagonal()
	_flare_t = 0.0
	var notes := _stage_tween()
	for i in FLARE_NOTES.size():
		if i > 0:
			notes.tween_interval(FLARE_NOTE_GAP)
		notes.tween_callback(_flare_note.bind(FLARE_NOTES[i]))
	return FLARE_RING


# --- the finale story (P8): the dark at the edges, the blast, the relight -----------------------------------------

## Every step (also while the world is frozen): the edge band eases, the blast ring grows and blows the band away,
## the relight circle eases to its target and, once full with the run's flare on, hands over to the shown levels.
func _step_finale(dt: float) -> void:
	if _edge != _edge_to:
		_edge_t += dt
		var k := 1.0 if _edge_secs <= 0.0 else clampf(_edge_t / _edge_secs, 0.0, 1.0)
		_edge = _edge_to if k >= 1.0 else lerpf(_edge_from, _edge_to, smoothstep(0.0, 1.0, k))
		_set_edge()
	if _blast_t >= 0.0:
		_blast_t += dt
		var k := minf(_blast_t / BLAST_RING, 1.0)
		_blast_r = _blast_len * (1.0 - pow(1.0 - k, 3.0))
		if k >= 1.0: # the ring is past every corner: the band is gone for good
			_blast_t = -1.0
			_edge = 0.0
			_edge_from = 0.0
			_edge_to = 0.0
			_set_edge()
			_set_blast(-1.0, false)
		else:
			_set_blast(_blast_r, _flashing())
	elif _blast_rect.visible:
		_set_blast(-1.0, _flashing())
	if _relight_to < 0.0:
		return
	if _flare_t >= 0.0:
		_flare_t += dt
		var q := minf(_flare_t / FLARE_RING, 1.0)
		_relight_r = _relight_to * (1.0 - (1.0 - q) * (1.0 - q))
		if q >= 1.0:
			_flare_t = -1.0
	elif _relight_r < _relight_to:
		_relight_t += dt
		var k := minf(_relight_t / RELIGHT_EASE, 1.0)
		_relight_r = lerpf(_relight_from, _relight_to, 1.0 - (1.0 - k) * (1.0 - k))
	material.set_shader_parameter("clear_radius", _relight_r)
	var full := _diagonal()
	_restore_by(_relight_r / full)
	if _relight_r >= full - 0.01 and _flare_t < 0.0 and _run and _run.get("flare") == true and _run.has_method("shown_levels"):
		_relight_to = -1.0
		_relight_r = -1.0
		apply(_run.shown_levels()) # the restored levels take over; the circle is off (clear_radius -1)


## The relight at `p` (0..1 of the diagonal): the frame cap 20 -> 30 -> 40 -> base at 1/4, 1/2, 3/4 (only while
## FRAME RATE is sold) and the AUDIO QUALITY low-pass and crush open.
func _restore_by(p: float) -> void:
	if _lv(_levels, "frame_rate", 1) > 0:
		var cap := FPS[1]
		if p >= 0.75:
			cap = _base_fps
		elif p >= 0.25:
			cap = FLARE_FPS[0] if p < 0.5 else FLARE_FPS[1]
		if Engine.max_fps != cap:
			Engine.max_fps = cap
	if _bus_fx.size() >= 2:
		var q := clampf(p, 0.0, 1.0)
		(_bus_fx[0] as AudioEffectLowPassFilter).cutoff_hz = LOWPASS_HZ * pow(OPEN_HZ / LOWPASS_HZ, q)
		(_bus_fx[1] as AudioEffectDistortion).drive = LOFI_DRIVE * (1.0 - q)


func _set_edge() -> void:
	(_edges.material as ShaderMaterial).set_shader_parameter("edge", _edge)
	_update_visible()


## The ring's radius (< 0 = none) and the flash on the blast layer; the edge band clears inside the ring.
func _set_blast(r: float, flash: bool) -> void:
	var m := _blast_rect.material as ShaderMaterial
	m.set_shader_parameter("ring_r", r)
	m.set_shader_parameter("flash", flash)
	(_edges.material as ShaderMaterial).set_shader_parameter("clear_r", r)
	_update_visible()


func _flashing() -> bool:
	return Engine.get_process_frames() - _flash_frame < BLAST_FLASH_FRAMES


func _diagonal() -> float:
	return (material.get_shader_parameter("view") as Vector2).length()


## A new run or restore(): no band, no ring, no relight.
func _reset_finale() -> void:
	_edge = 0.0
	_edge_from = 0.0
	_edge_to = 0.0
	_blast_t = -1.0
	_blast_r = -1.0
	_flash_frame = -100
	_relight_to = -1.0
	_relight_r = -1.0
	_flare_t = -1.0
	_set_edge()
	_set_blast(-1.0, false)


## The relight scale's player for `midi`: lantern_<midi>.wav, else the nearest lantern file (within 6 semitones,
## lower first) at the pitch that makes the note. Each note has its own player, so a ringing note never bends.
func _scale_player(midi: int) -> AudioStreamPlayer:
	if _scale.has(midi):
		return _scale[midi]
	for k in 7:
		for n: int in ([midi] if k == 0 else [midi - k, midi + k]):
			var path := MUSIC_DIR + "lantern_%d.wav" % n
			if ResourceLoader.exists(path):
				var p := _player(load(path))
				p.pitch_scale = pow(2.0, (midi - n) / 12.0)
				p.max_polyphony = 4
				_scale[midi] = p
				return p
	return null


func _flare_note(midi: int) -> void:
	if not _lantern.has(midi):
		return
	var p: AudioStreamPlayer = _lantern[midi]
	p.pitch_scale = 1.0
	p.volume_db = MUSIC_DB
	p.play()


## RESOLUTION: the bigger blocks spread from Wick outward in a circle.
func _spread_blocks(before: Dictionary) -> void:
	material.set_shader_parameter("block_prev", BLOCK[_lv(before, "resolution", 2)])
	material.set_shader_parameter("block_radius", 0.0)
	var view: Vector2 = material.get_shader_parameter("view")
	var t := _stage_tween()
	t.tween_property(material, "shader_parameter/block_radius", view.length(), STAGE_LEN["resolution"])
	t.tween_callback(func() -> void: material.set_shader_parameter("block_radius", -1.0))


# --- audio -----------------------------------------------------------------------------------------------------

func _build_audio() -> void:
	_build_music_bus()
	_track = RunMusic.new()
	add_child(_track)
	_track.setup(MUSIC_BUS)
	music = _track.player
	_title = _player(load(MUSIC_DIR + "title.wav"), MUSIC_BUS) # loops by its import settings
	_title.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	for cue in CUES:
		_cues[cue] = _player(load(MUSIC_DIR + cue + ".wav"))
	_finale = JSON.parse_string(FileAccess.get_file_as_string(MUSIC_DIR + "music.json"))["finale"]
	for pitch in Array(_finale["notes"]) + Array(FLARE_NOTES):
		if not _lantern.has(int(pitch)):
			_lantern[int(pitch)] = _player(load(MUSIC_DIR + "lantern_%d.wav" % int(pitch)))
			_lantern[int(pitch)].max_polyphony = 4
	_drone = _player(load(MUSIC_DIR + "drone.wav")) # loops by its import settings
	var toll := _player(load(SFX_DIR + "toll.wav")) # the blast's low D (blast_note), apart from the SOUND players
	toll.pitch_scale = BLAST_TOLL
	toll.volume_db = MUSIC_DB + BLAST_TOLL_DB
	var low := _player(load(MUSIC_DIR + "lantern_%d.wav" % BLAST_LANTERN))
	low.pitch_scale = 0.5
	low.volume_db = MUSIC_DB
	_blast_notes = [toll, low]
	for sfx: String in SFX_DB:
		for ext in [".ogg", ".wav"]:
			if ResourceLoader.exists(SFX_DIR + sfx + ext):
				_sfx[sfx] = _player(load(SFX_DIR + sfx + ext))
				_sfx[sfx].max_polyphony = 4
				break


func _player(stream: AudioStream, bus := "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	add_child(p)
	return p


## A Music bus into Master carries the run track, with this node's wall (open: a 20 kHz low-pass and 0 dB).
func _build_music_bus() -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, MUSIC_BUS)
		AudioServer.set_bus_send(bus, "Master")
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = OPEN_HZ
	_muffle_cut = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus, _muffle)
	AudioServer.add_bus_effect(bus, _muffle_cut)


func _set_music(level: int) -> void:
	var gain := GAIN[level]
	if gain <= 0.0 and _music_gain > 0.0 and music.playing: # MUSIC just sold
		_wind_down()
		_cue("music_sold", true)
	_music_gain = gain
	if gain > 0.0 and not music.playing and not _hold_music:
		music.volume_db = MUSIC_DB
		_track.play(_run_time())


## MUSIC sold: the run track slows to a stop like a tape running down, then stops.
func _wind_down() -> void:
	if _music_tween:
		_music_tween.kill()
	var tape := _track.tape_out()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(tape, "pitch_scale", 0.05, WIND_DOWN).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)
	_music_tween.tween_property(tape, "volume_db", MUSIC_DB - 30.0, WIND_DOWN).set_trans(Tween.TRANS_EXPO) \
			.set_ease(Tween.EASE_IN)
	_music_tween.chain().tween_callback(_stop_music.bind(0.0))


func _stop_music(fade: float) -> void:
	if _music_tween and fade > 0.0:
		_music_tween.kill()
	if fade <= 0.0 or not music.playing:
		_track.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", MUSIC_DB - 40.0, fade)
	_music_tween.tween_callback(_stop_music.bind(0.0))


## The run's clock (world seconds; it stops in menus), 0 without a run.
func _run_time() -> float:
	return float(_run.get("run_time")) if _run != null and _run.get("run_time") != null else 0.0


## Plays a music one-shot at the music volume; unless `always`, only while MUSIC plays.
func _cue(cue: String, always := false) -> void:
	if _music_gain <= 0.0 and not always:
		return
	var p: AudioStreamPlayer = _cues[cue]
	p.volume_db = MUSIC_DB
	p.play()


## The finale: one lantern note per PIXELS step sold (step `i` from 0), spelling out the hook while the organ
## drone grows under it. The lantern always sounds: it is the last light.
func _lantern_note(i: int) -> void:
	var notes: Array = _finale["notes"]
	if i < 0 or i >= notes.size():
		return
	var p: AudioStreamPlayer = _lantern[int(notes[i])]
	p.pitch_scale = 1.0
	p.volume_db = MUSIC_DB + linear_to_db(float(_finale["gain"][i]))
	p.play()
	if not _drone.playing:
		_drone.volume_db = -60.0
		_drone.play()
	if _drone_tween:
		_drone_tween.kill()
	_drone_tween = create_tween()
	_drone_tween.tween_property(_drone, "volume_db", MUSIC_DB + float(_finale["drone_db"][i]), 0.5)


## AUDIO QUALITY sold: a 700 Hz low-pass plus a lo-fi crush on the Master bus.
func _set_quality(level: int) -> void:
	if level == _quality:
		if level > 0 and _bus_fx.size() >= 2: # a stage may have left the sweep half done
			(_bus_fx[0] as AudioEffectLowPassFilter).cutoff_hz = LOWPASS_HZ
			(_bus_fx[1] as AudioEffectDistortion).drive = LOFI_DRIVE
		return
	_remove_bus_fx()
	_quality = level
	if level == 0:
		return
	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = LOWPASS_HZ
	_bus_fx.append(low_pass)
	var crush := AudioEffectDistortion.new()
	crush.mode = AudioEffectDistortion.MODE_LOFI
	crush.drive = LOFI_DRIVE
	_bus_fx.append(crush)
	var master := AudioServer.get_bus_index("Master")
	for effect in _bus_fx:
		AudioServer.add_bus_effect(master, effect)


## Removes only the effects this node added, leaving any others on the bus.
func _remove_bus_fx() -> void:
	_remove_effects(AudioServer.get_bus_index("Master"), _bus_fx)
	_bus_fx.clear()
	_quality = 0


static func _remove_effects(bus: int, effects: Array) -> void:
	if bus < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, i) in effects:
			AudioServer.remove_bus_effect(bus, i)


static func _lv(levels: Dictionary, id: String, top: int) -> int:
	return clampi(int(levels.get(id, 0)), 0, top)
