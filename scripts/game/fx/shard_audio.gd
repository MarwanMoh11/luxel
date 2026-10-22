extends Node
## Shard sound behaviour (design 7.4): arrivals on the music's 16th grid, the ladder by gauge fill, a voice cap.
## Loads audio/sfx/shards/shards.json (written by docs/soundtrack/round2/lantern_gothic/sfx_shards.py).
## Respects fx.sound_gain (silent once SOUND is sold); plays on Master so AUDIO QUALITY applies.
## Slot times are run (world) seconds; the grid phase comes from fx.music_clock() while the run track plays and
## from a free-running 144 BPM clock (the last music phase, carried on in run time) once it stops. Chimes and bells
## follow the run track's key (fx.key_shift: Night flattens E, Last light raises F and Bb).

const JSON_PATH := "res://audio/sfx/shards/shards.json"
const GRID := 60.0 / 144.0 / 4.0 ## one 16th of the run track (0.1042 s)
const DEGREES := 15 ## D5 .. D7
const CHIME_POOL := 6 ## players: 4 ringing + room for the ones fading out

var fx ## settings_fx.gd (music_clock, key_shift, sound_gain); null = full volume, free clock, D harmonic minor
var chime_streams: Array[AudioStream] = []
var bell_streams: Array[AudioStream] = []
var chime_midi: Array[int] = [] ## the ladder's pitches (shards.json)
var bell_midi: Array[int] = []
var pop_streams: Array[AudioStream] = []
var pull_stream: AudioStream
var full_stream: AudioStream
var db := {"chime": -18.0, "chime_fill": 4.0, "bell": -20.0, "pop": -20.0, "pull": -24.0, "full": -12.0}
var chime_voices := 4
var cut_fade := 0.01
var pull_len := 0.22
var pull_gap := 0.1
var star_step := 0.052
var full_delay := GRID
var pop_jitter := Vector2(0.97, 1.03)
## The last sounds played, newest last (for tests and debugging): {"kind", "deg", "db", "ms", "pitch"}.
var history: Array[Dictionary] = []

var _slots: PackedFloat64Array = PackedFloat64Array() # reserved arrival times (run seconds)
var _offset := 0.0 # music seconds - run seconds: slot k sits at k * GRID - _offset in run time
var _phase_known := false
var _voices := {} # pool name -> Array of {"p": AudioStreamPlayer, "start": ms, "end": ms, "fading": bool, "tw": Tween}
var _pop_rr := 0
var _last_pull_ms := -100000.0
var _queue: Array[Dictionary] = [] # {"in": s, "kind": "chime" | "full" | "pull", "deg", "fill", "big"}
var _loaded := false


## Keeps the fx node (music_clock, sound_gain) and loads the sounds.
func setup(fx_node: Node) -> void:
	fx = fx_node
	if not _loaded:
		_load()


## Clears the reserved slots, the queue, the voices and the free clock (new run).
func reset() -> void:
	_slots.clear()
	_queue.clear()
	_phase_known = false
	_offset = 0.0
	_last_pull_ms = -100000.0
	for pool: String in _voices:
		for v: Dictionary in _voices[pool]:
			_kill_fade(v)
			(v["p"] as AudioStreamPlayer).stop()
			v["end"] = 0.0
			v["fading"] = false
	history.clear()


## Run time of the first free 16th slot at or after `earliest` (grid from fx.music_clock() or the free clock).
func reserve(earliest: float, now: float) -> float:
	var m := _music_clock()
	if m >= 0.0:
		_offset = m - now
		_phase_known = true
	elif not _phase_known:
		_offset = 0.0 # no music yet: the grid starts at run time 0
		_phase_known = true
	var keep := PackedFloat64Array()
	for s: float in _slots:
		if s >= now - GRID:
			keep.append(s)
	_slots = keep
	var k := ceili((maxf(earliest, now) + _offset) / GRID - 0.0001)
	var t := k * GRID - _offset
	while _taken(t):
		k += 1
		t = k * GRID - _offset
	_slots.append(t)
	return t


## Frees every reserved slot (menus) and drops pulls waiting to start; a star run and a pending full play on.
func release_all() -> void:
	_slots.clear()
	_queue = _queue.filter(func(q: Dictionary) -> bool: return q["kind"] != "pull")


## A shard pops out of a kill (once per kill): a soft glass tick, round robin, pitch jitter.
func pop() -> void:
	if pop_streams.is_empty():
		return
	var s := pop_streams[_pop_rr % pop_streams.size()]
	_pop_rr += 1
	_play("pop", s, db["pop"], randf_range(pop_jitter.x, pop_jitter.y), {"kind": "pop", "deg": -1})


## The first shard of a kill starts its pull (at most one per pull_gap). Added (optional): `land_in` = seconds
## until that shard lands; the 0.22 s inhale is then delayed so it ends exactly on the landing.
func pull(land_in: float = 0.0) -> void:
	var ms := Time.get_ticks_msec() * 1.0
	if ms - _last_pull_ms < pull_gap * 1000.0:
		return
	_last_pull_ms = ms
	if land_in > pull_len + 0.01:
		_queue.append({"in": land_in - pull_len, "kind": "pull"})
	else:
		_play_pull()


## A shard lands: ladder degree from `fill` (0..1, after this shard), `big` for large shards (adds the bell).
func arrive(fill: float, big: bool) -> void:
	_chime(degree(fill), fill, big)


## The gauge is full: the dominant chord, one 16th after the shard that filled it (its D7 lands first).
func full() -> void:
	_queue.append({"in": full_delay, "kind": "full"})


## The magpie's star run up the ladder from `from_fill`: the remaining degrees as 32nds (chime + bell), the
## first at once. Only the notes: shards.gd calls full() when the star's last tick fills the gauge (P1b).
func star_run(from_fill: float) -> void:
	var d0 := degree(from_fill)
	var i := 0
	for d in range(d0 + 1, DEGREES):
		_queue.append({"in": i * star_step, "kind": "chime", "deg": d, "fill": d / float(DEGREES - 1), "big": true})
		i += 1


## Added: the ladder degree (0..14) for a fill after the shard: clamp(ceil(fill * 14), 0, 14).
func degree(fill: float) -> int:
	return clampi(ceili(fill * (DEGREES - 1) - 0.0001), 0, DEGREES - 1)


## Added: chimes ringing now (not fading); never more than chime_voices.
func ringing() -> int:
	var now := Time.get_ticks_msec() * 1.0
	var n := 0
	for v: Dictionary in _voices.get("chime", []):
		if not v["fading"] and now < float(v["end"]):
			n += 1
	return n


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	var due: Array[Dictionary] = []
	for q: Dictionary in _queue:
		q["in"] = float(q["in"]) - delta
		if float(q["in"]) <= 0.0:
			due.append(q)
	for q: Dictionary in due:
		_queue.erase(q)
		match q["kind"]:
			"chime":
				_chime(int(q["deg"]), float(q["fill"]), bool(q["big"]))
			"full":
				_play("full", full_stream, db["full"], 1.0, {"kind": "full", "deg": -1})
			"pull":
				_play_pull()


func _chime(deg: int, fill: float, big: bool) -> void:
	if deg < chime_streams.size():
		var vol: float = db["chime"] + db["chime_fill"] * clampf(fill, 0.0, 1.0)
		_play("chime", chime_streams[deg], vol, _key_pitch(chime_midi, deg), {"kind": "chime", "deg": deg})
	if big and deg < bell_streams.size():
		_play("bell", bell_streams[deg], db["bell"], _key_pitch(bell_midi, deg), {"kind": "bell", "deg": deg})


## pitch_scale that moves ladder note `deg` into the run track's current key (1.0 without fx or in D minor).
func _key_pitch(midi: Array[int], deg: int) -> float:
	if fx == null or not fx.has_method("key_shift") or deg >= midi.size():
		return 1.0
	return pow(2.0, int(fx.key_shift(midi[deg])) / 12.0)


func _play_pull() -> void:
	_play("pull", pull_stream, db["pull"], 1.0, {"kind": "pull", "deg": -1})


func _gain() -> float:
	if fx == null:
		return 1.0
	return clampf(float(fx.sound_gain), 0.0, 1.0)


func _music_clock() -> float:
	if fx != null and fx.has_method("music_clock"):
		return float(fx.music_clock())
	return -1.0


func _taken(t: float) -> bool:
	for s: float in _slots:
		if absf(s - t) < GRID * 0.5:
			return true
	return false


## Plays `stream` in `pool`: a free voice, else the oldest; chimes keep at most chime_voices ringing by fading
## the oldest out over cut_fade.
func _play(pool: String, stream: AudioStream, vol_db: float, pitch: float, entry: Dictionary) -> void:
	var g := _gain()
	if stream == null or g <= 0.001:
		return
	var now := Time.get_ticks_msec() * 1.0
	var voices: Array = _voices[pool]
	if pool == "chime":
		var live: Array = voices.filter(func(v: Dictionary) -> bool: return not v["fading"] and now < float(v["end"]))
		while live.size() >= chime_voices:
			var old: Dictionary = live[0]
			for v: Dictionary in live:
				if float(v["start"]) < float(old["start"]):
					old = v
			_fade_out(old)
			live.erase(old)
	var pick: Dictionary = {}
	for v: Dictionary in voices:
		if now >= float(v["end"]):
			pick = v
			break
	if pick.is_empty():
		pick = voices[0]
		for v: Dictionary in voices:
			if float(v["start"]) < float(pick["start"]):
				pick = v
	var p: AudioStreamPlayer = pick["p"]
	_kill_fade(pick)
	p.stop()
	p.stream = stream
	p.volume_db = vol_db + linear_to_db(g)
	p.pitch_scale = pitch
	p.play()
	pick["start"] = now
	pick["end"] = now + stream.get_length() * 1000.0 / pitch
	pick["fading"] = false
	entry["db"] = p.volume_db
	entry["ms"] = now
	entry["pitch"] = pitch
	history.append(entry)
	if history.size() > 64:
		history.pop_front()


func _fade_out(v: Dictionary) -> void:
	v["fading"] = true
	v["end"] = Time.get_ticks_msec() + cut_fade * 1000.0
	var p: AudioStreamPlayer = v["p"]
	_kill_fade(v)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, cut_fade)
	tw.tween_callback(func() -> void:
		if v["fading"]:
			p.stop())
	v["tw"] = tw


## Stops `v`'s fade-out, so a stolen or reset voice keeps the volume it is given next.
func _kill_fade(v: Dictionary) -> void:
	var tw: Tween = v["tw"]
	if tw != null and tw.is_valid():
		tw.kill()
	v["tw"] = null


func _load() -> void:
	_loaded = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("shard_audio: cannot read " + JSON_PATH)
		data = {}
	var d: Dictionary = data
	if d.has("chime"):
		for f: String in d["chime"]["files"]:
			chime_streams.append(load(f))
		for m: Variant in d["chime"]["midi"]:
			chime_midi.append(int(m))
		db["chime"] = float(d["chime"]["db"])
		db["chime_fill"] = float(d["chime"]["db_per_fill"])
		chime_voices = int(d["chime"]["voices"])
		cut_fade = float(d["chime"]["cut_fade_s"])
	if d.has("bell"):
		for f: String in d["bell"]["files"]:
			bell_streams.append(load(f))
		for m: Variant in d["bell"]["midi"]:
			bell_midi.append(int(m))
		db["bell"] = float(d["bell"]["db"])
	if d.has("pop"):
		for f: String in d["pop"]["files"]:
			pop_streams.append(load(f))
		db["pop"] = float(d["pop"]["db"])
		pop_jitter = Vector2(float(d["pop"]["pitch_scale"][0]), float(d["pop"]["pitch_scale"][1]))
	if d.has("pull"):
		pull_stream = load(d["pull"]["file"])
		db["pull"] = float(d["pull"]["db"])
		pull_len = float(d["pull"]["length_s"])
		pull_gap = float(d["pull"]["min_gap_s"])
	if d.has("full"):
		full_stream = load(d["full"]["file"])
		db["full"] = float(d["full"]["db"])
		full_delay = GRID * float(d["full"]["delay_16ths"])
	if d.has("star_run"):
		star_step = float(d["star_run"]["step_s"])
	var sizes := {"chime": CHIME_POOL, "bell": 2, "pop": 2, "pull": 2, "full": 1}
	for pool: String in sizes:
		var arr: Array = []
		for i in int(sizes[pool]):
			var p := AudioStreamPlayer.new()
			p.bus = &"Master"
			p.name = "%s_%d" % [pool, i]
			add_child(p)
			arr.append({"p": p, "start": -1.0, "end": 0.0, "fading": false, "tw": null})
		_voices[pool] = arr
