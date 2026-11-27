class_name LxAudioService
extends Node
## Runtime audio bus rack (LxMusic, LxSfx, LxAmbience, LxUi) with continuous vertical-layered
## music that NEVER stops or restarts on explore/combat/pause switches (SWARM_SPEC 2.2 & 9).

const BUS_MUSIC: String = "LxMusic"
const BUS_SFX: String = "LxSfx"
const BUS_AMBIENCE: String = "LxAmbience"
const BUS_UI: String = "LxUi"

const OPEN_LP_HZ: float = 20000.0
const PAUSE_LP_HZ: float = 520.0
const AMB_LP_HZ: float = 4200.0
const AMB_INDOOR_LP_HZ: float = 1400.0
const AMB_BOSS_LP_HZ: float = 1100.0
const SILENT_DB: float = -80.0
const BASE_MUSIC_DB: float = -5.0
const BASE_AMBIENCE_DB: float = -12.0
const AMB_LAYER2_OFFSET_DB: float = -2.5
const AMB_COMBAT_DUCK_DB: float = -5.5
const AMB_INDOOR_DUCK_DB: float = -3.5
const AMB_PAUSE_DUCK_DB: float = -6.0
const PAUSE_DUCK_DB: float = -6.0
const CROSSFADE_S: float = 1.6
const CUE_XFADE_S: float = 0.65
const AMB_FADE_S: float = 1.0
const COMBAT_DWELL_S: float = 1.2
const COMBAT_TAIL_S: float = 6.0

const SHARD_SCALE: Array[float] = [1.0, 1.12246, 1.18921, 1.33484, 1.49831, 1.68179]
const ISLAND_AMBIENCE: Dictionary = LxAudioMix.ISLAND_AMBIENCE

const SfxMap := preload("res://luxel/core/sfx_map.gd")
const AudioMix := preload("res://luxel/core/audio_mix.gd")
const SFX_POOL_SIZE: int = 12
const SFX_2D_POOL_SIZE: int = 12
const SFX_MIN_INTERVAL_S: float = 0.05

var _music_bus_idx: int = -1; var _sfx_bus_idx: int = -1
var _amb_bus_idx: int = -1; var _ui_bus_idx: int = -1
var _lowpass: AudioEffectLowPassFilter = null
var _amb_lowpass: AudioEffectLowPassFilter = null
var _sfx_reverb: AudioEffectReverb = null
var _is_indoor: bool = false; var _amb_lp_target_hz: float = AMB_LP_HZ
var _stinger_duck_t: float = 0.0; var _music_duck_cur: float = 0.0
var _sfx_duck_db: float = 0.0; var _sfx_duck_t: float = 0.0
var _music_fade: float = 1.0; var _music_fade_target: float = 1.0; var _music_fade_rate: float = 1.0 / CUE_XFADE_S
var _fade_out_gain: float = 0.0; var _fade_out_rate: float = 1.0 / CUE_XFADE_S; var _fade_out_trim_db: float = 0.0

# Primary (explore/track), outgoing crossfade deck, and synced combat stem players.
var _explore_player: AudioStreamPlayer = null
var _fade_player: AudioStreamPlayer = null
var _combat_player: AudioStreamPlayer = null
var _stinger_player: AudioStreamPlayer = null
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_gains: Array[float] = []
var _amb_target_gains: Array[float] = []
var _amb_fade_players: Array[AudioStreamPlayer] = []
var _amb_fade_gains: Array[float] = []
var _current_amb_key: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_pool_ids: PackedStringArray = PackedStringArray()
var _sfx_2d_pool_ids: PackedStringArray = PackedStringArray()
var _sfx_cursor: int = 0
var _sfx_2d_cursor: int = 0

var _stream_cache: Dictionary = {}; var _music_lru: Array[String] = []; var _sfx_missing: Dictionary = {}
var _sfx_last_t: Dictionary = {}; var _sfx_variant_idx: Dictionary = {}
var _sfx_clock: float = 0.0
var _shard_streak: int = 0; var _shard_streak_t: float = -10.0
var _mirror_streak: int = 0; var _mirror_streak_t: float = -10.0
var _saved_positions: Dictionary = {}

var current_track_group: String = ""
var current_mode: String = "explore"
var _current_island_id: int = 0
var _current_region_id: String = ""
var is_paused: bool = false
var combat_blend: float = 0.0
var _target_combat_blend: float = 0.0
var _combat_request_timer: float = 0.0
var _combat_tail_timer: float = 0.0
var _mute_unfocus: bool = true
var _focused: bool = true
var _master_muted: bool = false

# Telemetry for QA's 50-switch audio_check.
var stream_restart_count: int = 0
var mode_switch_count: int = 0
var pause_switch_count: int = 0


func setup() -> void:
	_setup_buses()
	_setup_players()


func _setup_buses() -> void:
	_music_bus_idx = _ensure_bus(BUS_MUSIC)
	_sfx_bus_idx = _ensure_bus(BUS_SFX)
	_amb_bus_idx = _ensure_bus(BUS_AMBIENCE)
	_ui_bus_idx = _ensure_bus(BUS_UI)

	AudioMix.ensure_limiter(0, -1.2, -1.2, 2.0)

	_lowpass = null
	for i: int in range(AudioServer.get_bus_effect_count(_music_bus_idx)):
		var fx: AudioEffect = AudioServer.get_bus_effect(_music_bus_idx, i)
		if fx is AudioEffectLowPassFilter: _lowpass = fx as AudioEffectLowPassFilter; break
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new(); _lowpass.cutoff_hz = OPEN_LP_HZ
		AudioServer.add_bus_effect(_music_bus_idx, _lowpass)

	_sfx_reverb = null
	for i: int in range(AudioServer.get_bus_effect_count(_sfx_bus_idx)):
		if AudioServer.get_bus_effect(_sfx_bus_idx, i) is AudioEffectReverb:
			_sfx_reverb = AudioServer.get_bus_effect(_sfx_bus_idx, i) as AudioEffectReverb; break
	if _sfx_reverb == null:
		_sfx_reverb = AudioEffectReverb.new(); _sfx_reverb.room_size = 0.24; _sfx_reverb.damping = 0.72; _sfx_reverb.wet = 0.03; _sfx_reverb.dry = 1.0
		AudioServer.add_bus_effect(_sfx_bus_idx, _sfx_reverb)
	AudioMix.ensure_limiter(_sfx_bus_idx, -2.2, -2.2, 2.0)
	AudioMix.ensure_limiter(_ui_bus_idx, -4.0, -4.0, 1.5)

	_amb_lowpass = null
	for i: int in range(AudioServer.get_bus_effect_count(_amb_bus_idx)):
		if AudioServer.get_bus_effect(_amb_bus_idx, i) is AudioEffectLowPassFilter:
			_amb_lowpass = AudioServer.get_bus_effect(_amb_bus_idx, i) as AudioEffectLowPassFilter; break
	if _amb_lowpass == null:
		_amb_lowpass = AudioEffectLowPassFilter.new(); _amb_lowpass.cutoff_hz = AMB_LP_HZ
		AudioServer.add_bus_effect(_amb_bus_idx, _amb_lowpass)


func _ensure_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _setup_players() -> void:
	_explore_player = AudioStreamPlayer.new()
	_explore_player.bus = BUS_MUSIC; _explore_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_explore_player)
	_fade_player = AudioStreamPlayer.new()
	_fade_player.bus = BUS_MUSIC; _fade_player.volume_db = SILENT_DB; _fade_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_player)
	_combat_player = AudioStreamPlayer.new()
	_combat_player.bus = BUS_MUSIC; _combat_player.volume_db = SILENT_DB; _combat_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_combat_player)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = BUS_MUSIC; _stinger_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_stinger_player)
	for i: int in range(2):
		var ap := AudioStreamPlayer.new(); ap.bus = BUS_AMBIENCE; ap.volume_db = SILENT_DB; ap.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ap); _amb_players.append(ap); _amb_gains.append(0.0); _amb_target_gains.append(0.0)
		var fp := AudioStreamPlayer.new(); fp.bus = BUS_AMBIENCE; fp.volume_db = SILENT_DB; fp.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(fp); _amb_fade_players.append(fp); _amb_fade_gains.append(0.0)
	_sfx_pool_ids.resize(SFX_POOL_SIZE)
	for i: int in range(SFX_POOL_SIZE):
		var sp := AudioStreamPlayer.new()
		sp.bus = BUS_SFX; sp.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sp); _sfx_pool.append(sp); _sfx_pool_ids[i] = ""
	_sfx_2d_pool_ids.resize(SFX_2D_POOL_SIZE)
	for i: int in range(SFX_2D_POOL_SIZE):
		var sp2 := AudioStreamPlayer2D.new()
		sp2.bus = BUS_SFX; sp2.process_mode = Node.PROCESS_MODE_ALWAYS
		sp2.max_distance = 360.0; sp2.panning_strength = 0.72; sp2.attenuation = 0.85
		add_child(sp2); _sfx_2d_pool.append(sp2); _sfx_2d_pool_ids[i] = ""


func _handoff_to_fade_deck(fade_rate: float = 1.0 / CUE_XFADE_S, prev_blend: float = 0.0, prev_cue: String = "") -> void:
	if _fade_player == null: return
	var use_cmb: bool = prev_blend > 0.5 and _combat_player != null and _combat_player.playing and _combat_player.stream != null
	var src: AudioStreamPlayer = _combat_player if use_cmb else _explore_player
	if src == null or not src.playing or src.stream == null: return
	var stem_w: float = sin(prev_blend * PI * 0.5) if use_cmb else cos(prev_blend * PI * 0.5)
	_fade_player.stream = src.stream; _fade_out_gain = clampf(_music_fade * stem_w, 0.0, 1.0); _fade_out_rate = maxf(fade_rate, 0.1)
	_fade_out_trim_db = AudioMix.cue_trim_db(prev_cue if not prev_cue.is_empty() else current_track_group)
	_fade_player.volume_db = src.volume_db; _fade_player.play(src.get_playback_position())


func apply_settings(cfg: Dictionary) -> void:
	_mute_unfocus = bool(cfg.get("mute_unfocus", true))
	_set_bus_linear(0, float(cfg.get("master_vol", 1.0)))
	_set_bus_linear(_music_bus_idx, float(cfg.get("music_vol", 0.85)))
	_set_bus_linear(_sfx_bus_idx, float(cfg.get("sfx_vol", 0.9)))
	_set_bus_linear(_amb_bus_idx, float(cfg.get("ambience_vol", 0.8)))
	_set_bus_linear(_ui_bus_idx, float(cfg.get("sfx_vol", 0.9)))

func _set_bus_linear(idx: int, linear: float) -> void:
	if idx < 0: return
	var v: float = clampf(linear, 0.0, 1.0)
	if idx == 0:
		_master_muted = v <= 0.001
		AudioServer.set_bus_mute(0, _master_muted or (_mute_unfocus and not _focused))
	else:
		AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

func set_window_focus(focused: bool) -> void:
	_focused = focused
	AudioServer.set_bus_mute(0, _master_muted or (_mute_unfocus and not _focused))

func _is_overworld_layer_active() -> bool:
	return _current_island_id > 0 and current_track_group == ("island%d" % _current_island_id)

func start_island_music(island_id: int) -> void:
	_current_island_id = island_id
	var group: String = "island%d" % island_id
	if current_track_group == group and _explore_player.playing:
		_music_fade_target = 1.0; _set_indoor_acoustics(false); _start_island_ambience(island_id); return
	var prev_group: String = current_track_group
	var prev_blend: float = combat_blend
	if current_track_group != "" and _explore_player.playing:
		_saved_positions[current_track_group] = _explore_player.get_playback_position()
	current_track_group = group; current_mode = "explore"
	_target_combat_blend = 0.0; combat_blend = 0.0; _combat_request_timer = 0.0; _combat_tail_timer = 0.0
	var exp_stream: AudioStream = _load_music_stream("island%d_explore" % island_id, "island1_explore")
	var cmb_stream: AudioStream = _load_music_stream("island%d_combat" % island_id, "island1_combat")
	var resume_pos: float = float(_saved_positions.get(group, 0.0))
	if exp_stream != null:
		_handoff_to_fade_deck(1.0 / CUE_XFADE_S, prev_blend, prev_group)
		if _explore_player.playing: _explore_player.stop()
		_explore_player.stream = exp_stream; _explore_player.volume_db = SILENT_DB; _explore_player.play(resume_pos)
	if cmb_stream != null:
		if _combat_player.playing: _combat_player.stop()
		_combat_player.stream = cmb_stream; _combat_player.volume_db = SILENT_DB; _combat_player.play(resume_pos)
	_music_fade = 0.0; _music_fade_target = 1.0; _music_fade_rate = 1.0 / CUE_XFADE_S
	_start_island_ambience(island_id); _set_indoor_acoustics(false)

func start_dungeon_music(island_id: int) -> void:
	_current_island_id = island_id; _start_island_ambience(island_id); _set_indoor_acoustics(true)
	play_cue("island%d_dungeon" % island_id)


func start_region_music(island_id: int, region_id: String, region_data: Dictionary = {}) -> void:
	_current_island_id = island_id
	_current_region_id = region_id
	var rmeta: Dictionary = Lx.packs.region_meta(island_id, region_id) if Lx.packs != null else {}
	var did: String = Lx.packs.dungeon_of(island_id, region_id) if Lx.packs != null else ""
	var dmeta: Dictionary = Lx.packs.dungeon(did) if (Lx.packs != null and not did.is_empty()) else {}
	var cue: String = str(region_data.get("music", "")).strip_edges()
	if cue.is_empty(): cue = str(rmeta.get("music", "")).strip_edges()
	var is_explore_cue: bool = cue == "explore" or cue == ("island%d_explore" % island_id)
	var is_dng: bool = false if is_explore_cue else bool(region_data.get("is_dungeon", not did.is_empty() or region_id != "overworld"))
	if cue.is_empty() and is_dng: cue = str(dmeta.get("music", "")).strip_edges()
	var custom_amb: Array = AudioMix.resolve_ambience_arg(region_data.get("ambience", null))
	if custom_amb.is_empty(): custom_amb = AudioMix.resolve_ambience_arg(rmeta.get("ambience", null))
	if not cue.is_empty() and not is_explore_cue:
		if custom_amb.is_empty(): _start_island_ambience(island_id)
		else: _start_ambience_layers(custom_amb, "%d:%s" % [island_id, region_id])
		_set_indoor_acoustics(is_dng, _is_boss_cue(cue))
		play_cue(cue)
		return
	if is_dng:
		start_dungeon_music(island_id)
		if not custom_amb.is_empty(): _start_ambience_layers(custom_amb, "%d:%s" % [island_id, region_id])
	else:
		start_island_music(island_id)
		if not custom_amb.is_empty(): _start_ambience_layers(custom_amb, "%d:%s" % [island_id, region_id])


func _is_boss_cue(cue: String) -> bool:
	if Lx.packs != null: return Lx.packs.is_boss_music_cue(cue)
	return cue.contains("_boss_")


func _is_phase_pair(prev_cue: String, next_cue: String) -> bool:
	if prev_cue.is_empty() or next_cue.is_empty() or prev_cue == next_cue: return false
	if Lx.packs != null and Lx.packs.is_boss_phase_pair(prev_cue, next_cue): return true
	return prev_cue.ends_with("_p1") and next_cue.ends_with("_p2") and prev_cue.trim_suffix("_p1") == next_cue.trim_suffix("_p2")


func _set_indoor_acoustics(indoor: bool, is_boss: bool = false) -> void:
	_is_indoor = indoor
	if _sfx_reverb != null:
		_sfx_reverb.room_size = 0.46 if is_boss else (0.40 if indoor else 0.22)
		_sfx_reverb.wet = 0.12 if is_boss else (0.11 if indoor else 0.03)
	_amb_lp_target_hz = AMB_BOSS_LP_HZ if is_boss else (AMB_INDOOR_LP_HZ if indoor else AMB_LP_HZ)


func _start_island_ambience(island_id: int) -> void:
	_start_ambience_layers(AudioMix.island_ambience(island_id), "isl:%d" % island_id)


func _start_ambience_layers(names: Array, key: String) -> void:
	if _amb_players.is_empty(): return
	var resolved_streams: Array[AudioStream] = []
	for raw_n: Variant in names:
		var mapped: String = AudioMix.resolve_ambience_name(str(raw_n))
		var st: AudioStream = _load_ambience_stream(mapped, "night_breeze")
		if st != null and not resolved_streams.has(st): resolved_streams.append(st)
		if resolved_streams.size() >= _amb_players.size(): break
	if _current_amb_key == key:
		var all_active: bool = true
		for i: int in range(resolved_streams.size()):
			if not _amb_players[i].playing or _amb_players[i].stream != resolved_streams[i]: all_active = false; break
		if all_active:
			for i: int in range(_amb_players.size()): _amb_target_gains[i] = 1.0 if i < resolved_streams.size() else 0.0
			return
	_current_amb_key = key
	for i: int in range(_amb_players.size()):
		var ap: AudioStreamPlayer = _amb_players[i]
		if i < resolved_streams.size():
			var st2: AudioStream = resolved_streams[i]
			_amb_target_gains[i] = 1.0
			if ap.stream != st2 or not ap.playing:
				if ap.playing and ap.stream != null and _amb_gains[i] > 0.01 and i < _amb_fade_players.size():
					var fp: AudioStreamPlayer = _amb_fade_players[i]
					fp.stream = ap.stream; _amb_fade_gains[i] = _amb_gains[i]; fp.volume_db = ap.volume_db; fp.play(ap.get_playback_position())
				ap.stream = st2; _amb_gains[i] = 0.0; ap.volume_db = SILENT_DB; ap.play()
		else:
			_amb_target_gains[i] = 0.0


func _fade_out_ambience(immediate: bool = false) -> void:
	_current_amb_key = ""
	for i: int in range(_amb_players.size()):
		_amb_target_gains[i] = 0.0
		if immediate:
			_amb_gains[i] = 0.0; _amb_players[i].volume_db = SILENT_DB
			if _amb_players[i].playing: _amb_players[i].stop()
			if i < _amb_fade_players.size():
				_amb_fade_gains[i] = 0.0; _amb_fade_players[i].volume_db = SILENT_DB
				if _amb_fade_players[i].playing: _amb_fade_players[i].stop()


func play_cue(cue_name: String) -> void:
	if cue_name == "explore" or cue_name == "combat":
		set_music_mode(cue_name, true); return
	if cue_name == "silence":
		if current_track_group != "" and current_track_group != "silence" and _explore_player != null and _explore_player.playing:
			_saved_positions[current_track_group] = _explore_player.get_playback_position()
			_handoff_to_fade_deck(1.0 / CUE_XFADE_S, combat_blend, current_track_group)
		current_track_group = "silence"; current_mode = "silence"
		_target_combat_blend = 0.0; combat_blend = 0.0; _combat_request_timer = 0.0; _combat_tail_timer = 0.0
		_music_fade = 0.0; _music_fade_target = 0.0; _music_fade_rate = 1.0 / CUE_XFADE_S
		if _explore_player != null:
			_explore_player.volume_db = SILENT_DB
			if _explore_player.playing: _explore_player.stop()
		if _combat_player != null:
			_combat_player.volume_db = SILENT_DB
			if _combat_player.playing: _combat_player.stop()
		_set_indoor_acoustics(true, true)
		return
	if cue_name in ["title", "ending_dawn", "credits"]:
		_fade_out_ambience(false); _set_indoor_acoustics(false)
	elif cue_name == "hub":
		_set_indoor_acoustics(false)
	elif _is_boss_cue(cue_name):
		_set_indoor_acoustics(true, true)
	if current_track_group == cue_name and _explore_player.playing:
		_music_fade_target = 1.0; return
	var prev_group: String = current_track_group
	var prev_blend: float = combat_blend
	var boss_carry: bool = _is_phase_pair(current_track_group, cue_name)
	var carry_pos: float = _explore_player.get_playback_position() if (boss_carry and _explore_player.playing) else -1.0
	if current_track_group != "" and _explore_player.playing:
		_saved_positions[current_track_group] = _explore_player.get_playback_position()
	current_track_group = cue_name; current_mode = cue_name
	_target_combat_blend = 0.0; combat_blend = 0.0; _combat_request_timer = 0.0; _combat_tail_timer = 0.0
	var st: AudioStream = _load_music_stream(cue_name, "title")
	if st != null:
		var xfade_rate: float = 1.0 / (0.35 if boss_carry else CUE_XFADE_S)
		_handoff_to_fade_deck(xfade_rate, prev_blend, prev_group)
		if _explore_player.playing: _explore_player.stop()
		_explore_player.stream = st
		_music_fade = 0.0
		_music_fade_target = 1.0
		_music_fade_rate = xfade_rate
		_explore_player.volume_db = SILENT_DB
		var pos: float = carry_pos if carry_pos >= 0.0 else float(_saved_positions.get(cue_name, 0.0))
		_explore_player.play(pos)
	if _combat_player != null:
		_combat_player.volume_db = SILENT_DB
		if _combat_player.playing: _combat_player.stop()


func silence_music(fade_s: float = 0.85) -> void:
	_music_fade_target = 0.0
	_music_fade_rate = 1.0 / maxf(0.1, fade_s)


func set_music_mode(mode: String, immediate: bool = false) -> void:
	mode_switch_count += 1
	if mode == "combat":
		if not _is_overworld_layer_active(): return
		current_mode = "combat"; _combat_tail_timer = COMBAT_TAIL_S
		if immediate or _combat_request_timer >= COMBAT_DWELL_S: _target_combat_blend = 1.0
	elif mode == "explore":
		if not _is_overworld_layer_active() and _current_island_id > 0:
			start_island_music(_current_island_id); return
		current_mode = "explore"
		if immediate or _combat_tail_timer <= 0.0: _target_combat_blend = 0.0
	else:
		play_cue(mode)


func set_paused(paused: bool) -> void:
	if is_paused == paused: return
	is_paused = paused; pause_switch_count += 1
	if _lowpass != null: _lowpass.cutoff_hz = PAUSE_LP_HZ if paused else OPEN_LP_HZ
	_update_layer_volumes()


func tick(dt: float, in_combat: bool = false) -> void:
	_sfx_clock += dt
	_stinger_duck_t = maxf(0.0, _stinger_duck_t - dt)
	if _sfx_duck_t > 0.0: _sfx_duck_t = maxf(0.0, _sfx_duck_t - dt)
	else: _sfx_duck_db = move_toward(_sfx_duck_db, 0.0, dt * 6.5)
	var duck_tgt: float = maxf(6.0 * clampf(_stinger_duck_t / 0.8, 0.0, 1.0), _sfx_duck_db)
	_music_duck_cur = move_toward(_music_duck_cur, duck_tgt, dt * (48.0 if duck_tgt > _music_duck_cur else 14.0))
	if _amb_lowpass != null: _amb_lowpass.cutoff_hz = move_toward(_amb_lowpass.cutoff_hz, _amb_lp_target_hz, dt * 8000.0)
	_music_fade = move_toward(_music_fade, _music_fade_target, dt * _music_fade_rate)
	if _fade_out_gain > 0.0: _fade_out_gain = move_toward(_fade_out_gain, 0.0, dt * _fade_out_rate)
	if _is_overworld_layer_active():
		if in_combat:
			_combat_request_timer += dt; _combat_tail_timer = COMBAT_TAIL_S
			if _combat_request_timer >= COMBAT_DWELL_S: _target_combat_blend = 1.0
		else:
			_combat_request_timer = maxf(0.0, _combat_request_timer - dt * 2.0)
			if _combat_tail_timer > 0.0: _combat_tail_timer -= dt
			else: _target_combat_blend = 0.0
		combat_blend = move_toward(combat_blend, _target_combat_blend, dt / maxf(CROSSFADE_S, 0.05))
	else:
		_combat_request_timer = 0.0; _combat_tail_timer = 0.0; _target_combat_blend = 0.0; combat_blend = 0.0
	var amb_step: float = dt / maxf(AMB_FADE_S, 0.05)
	for i: int in range(_amb_players.size()):
		_amb_gains[i] = move_toward(_amb_gains[i], _amb_target_gains[i], amb_step)
		if i < _amb_fade_gains.size() and _amb_fade_gains[i] > 0.0:
			_amb_fade_gains[i] = move_toward(_amb_fade_gains[i], 0.0, amb_step)
	_update_layer_volumes()


func _update_layer_volumes() -> void:
	var cue_trim: float = AudioMix.cue_trim_db(current_track_group)
	var duck: float = (PAUSE_DUCK_DB if is_paused else 0.0) - _music_duck_cur
	var in_curve: float = sin(clampf(_music_fade, 0.0, 1.0) * PI * 0.5)
	var out_curve: float = sin(clampf(_fade_out_gain, 0.0, 1.0) * PI * 0.5)
	var exp_gain: float = cos(combat_blend * PI * 0.5) * in_curve
	var cmb_gain: float = sin(combat_blend * PI * 0.5) * in_curve
	if _explore_player != null:
		_explore_player.volume_db = BASE_MUSIC_DB + cue_trim + duck + linear_to_db(maxf(exp_gain, 0.0001)) if exp_gain > 0.001 else SILENT_DB
	if _fade_player != null:
		if out_curve > 0.001: _fade_player.volume_db = BASE_MUSIC_DB + _fade_out_trim_db + duck + linear_to_db(out_curve)
		else:
			_fade_player.volume_db = SILENT_DB
			if _fade_player.playing: _fade_player.stop()
	if _combat_player != null and _combat_player.stream != null:
		_combat_player.volume_db = BASE_MUSIC_DB + cue_trim + duck + linear_to_db(maxf(cmb_gain, 0.0001)) if cmb_gain > 0.001 else SILENT_DB
	var amb_duck: float = (AMB_PAUSE_DUCK_DB if is_paused else 0.0) + (AMB_INDOOR_DUCK_DB if _is_indoor else 0.0)
	amb_duck += AMB_COMBAT_DUCK_DB * (1.0 if _is_boss_cue(current_track_group) else combat_blend)
	for i: int in range(_amb_players.size()):
		var ap: AudioStreamPlayer = _amb_players[i]; var g: float = sin(clampf(_amb_gains[i], 0.0, 1.0) * PI * 0.5)
		var l2: float = AMB_LAYER2_OFFSET_DB if i > 0 else 0.0
		if g > 0.001: ap.volume_db = BASE_AMBIENCE_DB + l2 + amb_duck + linear_to_db(g)
		else:
			ap.volume_db = SILENT_DB
			if _amb_target_gains[i] <= 0.001 and ap.playing: ap.stop()
		if i < _amb_fade_players.size():
			var fp: AudioStreamPlayer = _amb_fade_players[i]; var fg: float = sin(clampf(_amb_fade_gains[i], 0.0, 1.0) * PI * 0.5)
			if fg > 0.001: fp.volume_db = BASE_AMBIENCE_DB + l2 + amb_duck + linear_to_db(fg)
			else:
				fp.volume_db = SILENT_DB
				if fp.playing: fp.stop()


func play_stinger(stinger_name: String) -> void:
	var st: AudioStream = _load_music_stream(stinger_name, "")
	if st != null and _stinger_player != null:
		_stinger_player.stream = st; _stinger_player.volume_db = -6.0; _stinger_player.play(); _stinger_duck_t = 2.8


func play_sfx(sfx_id: String, world_pos: Vector2 = Vector2.ZERO, spatial: bool = false, ui_bus: bool = false) -> void:
	if sfx_id.is_empty(): return
	var eff_id: String = AudioMix.surface_override(sfx_id, _current_island_id, _current_region_id)
	var base_id: String = eff_id
	var st: AudioStream = _pick_variant_stream(eff_id)
	var pitch_mul: float = 1.0
	var gain_db: float = SfxMap.base_trim_db(eff_id)
	if st == null:
		var mapped: Dictionary = SfxMap.resolve(eff_id)
		var mapped_id: String = str(mapped.get("id", ""))
		if not mapped_id.is_empty():
			base_id = mapped_id
			st = _pick_variant_stream(mapped_id)
			pitch_mul = float(mapped.get("pitch", 1.0))
			gain_db = float(mapped.get("db", 0.0)) + SfxMap.base_trim_db(mapped_id)
			if st == null:
				# 2-hop fallback when a pack alias targets an EXACT/EPIC_EXACT alias (e.g. bell_toll -> bell_toll_heavy).
				var mapped2: Dictionary = SfxMap.resolve(mapped_id)
				var m2_id: String = str(mapped2.get("id", ""))
				if not m2_id.is_empty() and m2_id != mapped_id:
					base_id = m2_id
					st = _pick_variant_stream(m2_id)
					pitch_mul *= float(mapped2.get("pitch", 1.0))
					gain_db += float(mapped2.get("db", 0.0)) + SfxMap.base_trim_db(m2_id)
	if st == null: return
	var min_iv: float = 0.035 if ui_bus else AudioMix.min_interval_for(eff_id, base_id, SFX_MIN_INTERVAL_S)
	if _sfx_last_t.has(eff_id) and (_sfx_clock - float(_sfx_last_t[eff_id])) < min_iv: return
	if not ui_bus and base_id != eff_id and _sfx_last_t.has(base_id) and (_sfx_clock - float(_sfx_last_t[base_id])) < min_iv: return
	if base_id == "shield_clang" and (_sfx_clock - float(_sfx_last_t.get("shield_strain", -1.0))) < 0.09: return
	_sfx_last_t[eff_id] = _sfx_clock; _sfx_last_t[base_id] = _sfx_clock

	var d_info: Vector2 = AudioMix.dynamic_music_duck(eff_id, base_id)
	if d_info.x > 0.0:
		_sfx_duck_db = maxf(_sfx_duck_db, d_info.x)
		_sfx_duck_t = maxf(_sfx_duck_t, d_info.y)

	var jit: float = 1.0 if ui_bus else randf_range(0.96, 1.04)
	if base_id == "bolt_fire": jit = randf_range(0.95, 1.05)
	elif base_id == "shard_pickup":
		_shard_streak = mini(SHARD_SCALE.size() - 1, _shard_streak + 1) if (_sfx_clock - _shard_streak_t) <= 0.85 else 0
		_shard_streak_t = _sfx_clock; jit = SHARD_SCALE[_shard_streak]
	elif base_id in ["mirror_ping", "prism_bounce", "prism_chain", "prop_chime"]:
		_mirror_streak = mini(SHARD_SCALE.size() - 1, _mirror_streak + 1) if (_sfx_clock - _mirror_streak_t) <= 0.75 else 0
		_mirror_streak_t = _sfx_clock; jit = SHARD_SCALE[_mirror_streak]

	var max_poly: int = AudioMix.max_polyphony_for(base_id)
	if spatial and not _sfx_2d_pool.is_empty():
		var pick2: Vector2i = AudioMix.pick_pool_slot(_sfx_2d_pool, _sfx_2d_pool_ids, base_id, max_poly, _sfx_2d_cursor)
		_sfx_2d_cursor = pick2.y
		var p2: AudioStreamPlayer2D = _sfx_2d_pool[pick2.x]
		if p2.playing: p2.stop()
		_sfx_2d_pool_ids[pick2.x] = base_id
		p2.global_position = world_pos; p2.stream = st; p2.volume_db = gain_db + randf_range(-0.9, 0.9); p2.pitch_scale = pitch_mul * jit; p2.play()
	elif not _sfx_pool.is_empty():
		var pick1: Vector2i = AudioMix.pick_pool_slot(_sfx_pool, _sfx_pool_ids, base_id, max_poly, _sfx_cursor)
		_sfx_cursor = pick1.y
		var p: AudioStreamPlayer = _sfx_pool[pick1.x]
		if p.playing: p.stop()
		_sfx_pool_ids[pick1.x] = base_id
		p.bus = BUS_UI if ui_bus else BUS_SFX; p.stream = st; p.volume_db = gain_db if ui_bus else gain_db + randf_range(-0.9, 0.9); p.pitch_scale = pitch_mul * jit; p.play()


func _pick_variant_stream(sfx_id: String) -> AudioStream:
	var arr: Array = SfxMap.variant_list(sfx_id)
	if not arr.is_empty():
		var idx: int = int(_sfx_variant_idx.get(sfx_id, 0)) % arr.size()
		_sfx_variant_idx[sfx_id] = (idx + 1) % arr.size()
		var cand: AudioStream = _load_sfx_stream(str(arr[idx]))
		if cand != null: return cand
	return _load_sfx_stream(sfx_id)

func get_music_position() -> float: return _explore_player.get_playback_position() if (_explore_player != null and _explore_player.playing) else 0.0
func is_music_playing() -> bool: return _explore_player != null and _explore_player.playing
func get_lowpass_cutoff() -> float: return _lowpass.cutoff_hz if _lowpass != null else OPEN_LP_HZ

func _load_music_stream(cue_name: String, fallback: String) -> AudioStream:
	if cue_name == "silence": return null
	var cands: Array[String] = ["res://luxel/audio/music/%s.ogg" % cue_name]
	if not fallback.is_empty() and fallback != cue_name: cands.append("res://luxel/audio/music/%s.ogg" % fallback)
	var do_loop: bool = not cue_name.begins_with("stinger_") and cue_name != "ending_dawn"
	for path: String in cands:
		var loaded: AudioStream = _load_cached_ogg(path, do_loop)
		if loaded != null: return loaded
	var gen := AudioStreamGenerator.new(); gen.mix_rate = 44100.0; gen.buffer_length = 0.5; return gen

func _load_ambience_stream(amb_name: String, fallback: String = "night_breeze") -> AudioStream:
	var cands: Array[String] = ["res://luxel/audio/ambience/%s.ogg" % amb_name]
	if not fallback.is_empty() and fallback != amb_name: cands.append("res://luxel/audio/ambience/%s.ogg" % fallback)
	for path: String in cands:
		var loaded: AudioStream = _load_cached_ogg(path, true)
		if loaded != null: return loaded
	return null

func _load_sfx_stream(sfx_id: String) -> AudioStream:
	if _sfx_missing.has(sfx_id): return null
	for ext: String in [".ogg", ".wav"]:
		var loaded: AudioStream = _load_cached_ogg("res://luxel/audio/sfx/%s%s" % [sfx_id, ext], false, ext == ".ogg")
		if loaded != null: return loaded
	_sfx_missing[sfx_id] = true; return null

func _touch_music_lru(path: String) -> void:
	if not (path.contains("/music/") or path.contains("/ambience/")): return
	var idx: int = _music_lru.find(path)
	if idx >= 0: _music_lru.remove_at(idx)
	_music_lru.append(path)
	while _music_lru.size() > 16: _stream_cache.erase(_music_lru.pop_front())

func _load_cached_ogg(path: String, set_loop: bool, allow_disk_ogg: bool = true) -> AudioStream:
	if _stream_cache.has(path): _touch_music_lru(path); return _stream_cache[path] as AudioStream
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is AudioStream:
			if res is AudioStreamOggVorbis and allow_disk_ogg: (res as AudioStreamOggVorbis).loop = set_loop
			_stream_cache[path] = res; _touch_music_lru(path); return res as AudioStream
	if allow_disk_ogg:
		var abs_p: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(abs_p)
			if ogg != null: ogg.loop = set_loop; _stream_cache[path] = ogg; _touch_music_lru(path); return ogg
	return null
