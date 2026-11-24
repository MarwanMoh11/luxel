class_name LxSaveService
extends Node
## Atomic save/load with backup fallback and forward version migration (SWARM_SPEC 3.7).
## Stores exclusively in user://luxel1/ (debug runs use debug_*.json).

const SAVE_DIR: String = "user://luxel1"
const CURRENT_VERSION: int = 2
const SLOT_COUNT: int = 3
const AUTOSAVE_DEBOUNCE_S: float = 1.5
const OBSIDIAN_SEAL_IDS: Array[String] = [
	"obsidian_5_secret", "seal_kiln_r5", "seal_kiln_r7", "seal_kiln_r9", "seal_7_ow_terrace",
	"seal_spire_r5", "seal_spire_r9", "seal_8_g3", "seal_sanctum_r5",
]

var debug_mode: bool = false
var settings: Dictionary = {}
var last_load_used_backup: bool = false
var last_notice_key: String = ""

var _debounce_timer: float = -1.0
var _pending_slot: int = -1
var _pending_state: LxGameState = null
var _io_thread: Thread = null
var _io_mutex: Mutex = Mutex.new()
var _io_queue: Array[Dictionary] = []
var _io_running: bool = false


func _init() -> void:
	settings = default_settings()


func _exit_tree() -> void:
	flush_pending()


func setup(is_debug: bool) -> void:
	flush_pending()
	debug_mode = is_debug
	_ensure_dir()
	load_settings()


func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func slot_path(slot_num: int) -> String:
	var n: int = clampi(slot_num, 1, SLOT_COUNT)
	if debug_mode:
		return "%s/debug_slot_%d.json" % [SAVE_DIR, n]
	return "%s/slot_%d.json" % [SAVE_DIR, n]


func settings_path() -> String:
	if debug_mode:
		return "%s/debug_settings.json" % SAVE_DIR
	return "%s/settings.json" % SAVE_DIR


func slot_exists(slot_num: int) -> bool:
	flush_pending()
	var p: String = slot_path(slot_num)
	return FileAccess.file_exists(p) or FileAccess.file_exists(p + ".bak")


func slot_summary(slot_num: int) -> Dictionary:
	var d: Dictionary = load_slot_dict(slot_num)
	if d.is_empty():
		return {"empty": true, "slot": slot_num}
	var relit_raw: Array = d.get("relit_islands", []) as Array
	var relit_arr: Array[int] = []
	for v: Variant in relit_raw:
		relit_arr.append(int(v))
	var harmony_arr: Array[int] = []
	var sflags_v: Variant = d.get("story_flags", {})
	if sflags_v is Dictionary:
		var sflags: Dictionary = sflags_v as Dictionary
		for iid: int in range(1, 9):
			if bool(sflags.get("disc_all_%d" % iid, false)):
				harmony_arr.append(iid)
	return {
		"empty": false,
		"slot": slot_num,
		"island_id": int(d.get("island_id", 1)),
		"hearts": int(d.get("max_hearts", 4)),
		"play_time_s": float(d.get("play_time_s", 0.0)),
		"relit_count": relit_arr.size(),
		"relit_islands": relit_arr.duplicate(),
		"harmony_count": harmony_arr.size(),
		"harmony_islands": harmony_arr,
	}


func save_slot(slot_num: int, state: LxGameState) -> bool:
	if state == null:
		return false
	flush_pending()
	state.slot_id = str(clampi(slot_num, 1, SLOT_COUNT))
	state.version = CURRENT_VERSION
	return _write_atomic_json(slot_path(slot_num), state.to_dict())


func autosave_slot(slot_num: int, state: LxGameState, immediate: bool = false) -> bool:
	if state == null:
		return false
	state.slot_id = str(clampi(slot_num, 1, SLOT_COUNT))
	state.version = CURRENT_VERSION
	if not immediate:
		_pending_slot = slot_num
		_pending_state = state
		_debounce_timer = AUTOSAVE_DEBOUNCE_S
		return true
	_pending_slot = -1
	_pending_state = null
	_debounce_timer = -1.0
	return _dispatch_async_write(slot_path(slot_num), _snapshot_state_fast(state))


func tick_autosave(dt: float) -> void:
	if _debounce_timer >= 0.0:
		_debounce_timer -= maxf(0.0, dt)
		if _debounce_timer <= 0.0:
			var sl: int = _pending_slot
			var st: LxGameState = _pending_state
			_pending_slot = -1
			_pending_state = null
			_debounce_timer = -1.0
			if sl > 0 and st != null and is_instance_valid(st):
				_dispatch_async_write(slot_path(sl), _snapshot_state_fast(st))
	_reap_finished_thread()


func flush_pending() -> void:
	if _pending_slot > 0 and _pending_state != null and is_instance_valid(_pending_state):
		var sl: int = _pending_slot
		var st: LxGameState = _pending_state
		_pending_slot = -1
		_pending_state = null
		_debounce_timer = -1.0
		_dispatch_async_write(slot_path(sl), _snapshot_state_fast(st))
	if _io_thread != null:
		if _io_thread.is_started():
			_io_thread.wait_to_finish()
		_io_thread = null
		_io_running = false


func _snapshot_state_fast(state: LxGameState) -> Dictionary:
	# Shallow-copy interactable_states map (entries are replaced atomically on save) so
	# even 5,000+ entries snapshot in < 1 ms on the main thread while JSON stringify runs off-thread.
	var d: Dictionary = {
		"version": state.version, "slot_id": state.slot_id,
		"island_id": state.island_id, "region_id": state.region_id, "room_id": state.room_id,
		"spawn_pos": [state.spawn_pos.x, state.spawn_pos.y],
		"room_anchor_region": state.room_anchor_region,
		"room_anchor_pos": [state.room_anchor_pos.x, state.room_anchor_pos.y],
		"last_waystone_island": state.last_waystone_island, "last_waystone_id": state.last_waystone_id,
		"max_hearts": state.max_hearts, "hearts": state.hearts,
		"ember_pieces": state.ember_pieces, "half_lanterns": state.half_lanterns, "shards": state.shards,
		"unlocked_moves": state.unlocked_moves.duplicate(), "upgrades": state.upgrades.duplicate(),
		"lit_waystones": state.lit_waystones.duplicate(), "lit_beacons": state.lit_beacons.duplicate(),
		"claimed_shrines": state.claimed_shrines.duplicate(), "broken_seals": state.broken_seals.duplicate(),
		"relit_islands": state.relit_islands.duplicate(), "defeated_bosses": state.defeated_bosses.duplicate(),
		"collected_keys": state.collected_keys.duplicate(), "opened_doors": state.opened_doors.duplicate(),
		"visited_regions": state.visited_regions.duplicate(),
		"interactable_states": state.interactable_states.duplicate(false),
		"story_flags": state.story_flags.duplicate(true), "world_vars": state.world_vars.duplicate(true),
		"play_time_s": state.play_time_s, "deaths": state.deaths, "hits_taken": state.hits_taken,
		"boss_retries": state.boss_retries.duplicate(), "zone_times": state.zone_times.duplicate(),
	}
	return d


func _dispatch_async_write(user_path: String, data: Dictionary) -> bool:
	_ensure_dir()
	var abs_target: String = ProjectSettings.globalize_path(user_path)
	if OS.has_feature("web"):
		return _write_atomic_abs(abs_target, data)
	_reap_finished_thread()
	_io_mutex.lock()
	# Coalesce multiple queued writes to the same slot file.
	var replaced: bool = false
	for i: int in range(_io_queue.size()):
		if str(_io_queue[i].get("path", "")) == abs_target:
			_io_queue[i]["data"] = data
			replaced = true
			break
	if not replaced:
		_io_queue.append({"path": abs_target, "data": data})
	var start_worker: bool = not _io_running
	if start_worker:
		_io_running = true
	_io_mutex.unlock()
	if start_worker:
		if _io_thread != null and _io_thread.is_started():
			_io_thread.wait_to_finish()
		_io_thread = Thread.new()
		_io_thread.start(_io_worker_loop)
	return true


func _io_worker_loop() -> void:
	while true:
		_io_mutex.lock()
		if _io_queue.is_empty():
			_io_running = false
			_io_mutex.unlock()
			return
		var job: Dictionary = _io_queue.pop_front() as Dictionary
		_io_mutex.unlock()
		_write_atomic_abs(str(job["path"]), job["data"] as Dictionary)


func _reap_finished_thread() -> void:
	if _io_thread != null and _io_thread.is_started() and not _io_thread.is_alive():
		_io_thread.wait_to_finish()
		_io_thread = null


func load_slot(slot_num: int, state: LxGameState) -> bool:
	var d: Dictionary = load_slot_dict(slot_num)
	if d.is_empty():
		return false
	state.from_dict(d)
	return true


func load_slot_dict(slot_num: int) -> Dictionary:
	flush_pending()
	last_load_used_backup = false
	last_notice_key = ""
	var p: String = slot_path(slot_num)
	var d: Dictionary = _read_json_dict(p)
	if not d.is_empty() and _is_valid_save_dict(d):
		return migrate(d)
	var bak: String = p + ".bak"
	var db: Dictionary = _read_json_dict(bak)
	if not db.is_empty() and _is_valid_save_dict(db):
		last_load_used_backup = true
		last_notice_key = "NOTICE_SAVE_BACKUP"
		return migrate(db)
	return {}


func delete_slot(slot_num: int) -> void:
	flush_pending()
	var p: String = slot_path(slot_num)
	for suffix: String in ["", ".bak", ".tmp"]:
		var full: String = ProjectSettings.globalize_path(p + suffix)
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(full)


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var ver: int = int(out.get("version", 1))
	if ver < 2:
		if not out.has("visited_regions"):
			out["visited_regions"] = ["%d:%s" % [int(out.get("island_id", 1)), str(out.get("region_id", "overworld"))]]
		if not out.has("collected_keys"):
			out["collected_keys"] = {}
		if not out.has("opened_doors"):
			out["opened_doors"] = []
		if not out.has("boss_retries"):
			out["boss_retries"] = {}
		if not out.has("zone_times"):
			out["zone_times"] = {}
		if not out.has("upgrades"):
			out["upgrades"] = {}
		if not out.has("interactable_states"):
			out["interactable_states"] = {}
		if not out.has("story_flags"):
			out["story_flags"] = {}
		out["version"] = 2
	_normalize_save_dict(out)
	return out


static func _normalize_save_dict(out: Dictionary) -> void:
	# Normalize Island 7 mini-boss alias ("spire_warden" -> canonical "moonshade_warden") and deduplicate.
	if out.get("defeated_bosses") is Array:
		var bosses: Array = []
		for b_v: Variant in (out["defeated_bosses"] as Array):
			var bid: String = str(b_v)
			if bid == "spire_warden":
				bid = "moonshade_warden"
			if not bid.is_empty() and not bosses.has(bid):
				bosses.append(bid)
		out["defeated_bosses"] = bosses
	# Deduplicate lit_waystones while preserving order.
	if out.get("lit_waystones") is Array:
		var ws_clean: Array = []
		for ws_v: Variant in (out["lit_waystones"] as Array):
			var wid: String = str(ws_v)
			if not wid.is_empty() and not ws_clean.has(wid):
				ws_clean.append(wid)
		out["lit_waystones"] = ws_clean
	# Clamp loaded hearts safely within [0, max_hearts].
	if out.has("hearts"):
		var mh: int = clampi(int(out.get("max_hearts", 4)), 4, 12)
		out["hearts"] = clampf(float(out.get("hearts", float(mh))), 0.0, float(mh))
	# Backfill Round 17 tut_* flags only for relit islands (a gate seal breaks before its move is owned).
	var relit_set: Dictionary = {}
	if out.get("relit_islands") is Array:
		for r_v: Variant in (out["relit_islands"] as Array):
			relit_set[int(r_v)] = true
	var has_obsidian_seal: bool = false
	if out.get("broken_seals") is Array:
		for s_v: Variant in (out["broken_seals"] as Array):
			if OBSIDIAN_SEAL_IDS.has(str(s_v)):
				has_obsidian_seal = true
	var sf: Dictionary = out["story_flags"] as Dictionary if out.get("story_flags") is Dictionary else {}
	out["story_flags"] = sf
	if not (out.get("world_vars") is Dictionary):
		out["world_vars"] = {}
	if not out.has("half_lanterns"):
		out["half_lanterns"] = 0
	if relit_set.has(2):
		sf["tut_blue_refract_done"] = true
	if relit_set.has(3):
		sf["tut_beam_break_done"] = true
	if relit_set.has(4):
		sf["tut_wings_glided"] = true
	if relit_set.has(5):
		sf["tut_lens_pulsed"] = true
		sf["tut_lens_anchored"] = true
	if relit_set.has(6) or has_obsidian_seal:
		sf["tut_seal_shattered"] = true
	elif not relit_set.has(8):
		sf.erase("tut_seal_shattered") # older builds set it from the beacon gate seals
	if relit_set.has(6):
		sf["tut_vent_dashed"] = true


static func _is_valid_save_dict(d: Dictionary) -> bool:
	return d.has("version") and d.has("island_id")


static func default_settings() -> Dictionary:
	return {
		"version": 1,
		"master_vol": 1.0,
		"music_vol": 0.85,
		"sfx_vol": 0.9,
		"ambience_vol": 0.65,
		"mute_unfocus": true,
		"fullscreen": false,
		"window_scale": 3,
		"screen_shake": 100,
		"flash_reduction": false,
		"cursor_size": 1,
		"cursor_color": "gold",
		"bindings": {},
		"hold_mode": {"lx_fire": "hold", "lx_beam": "hold", "lx_wings": "hold"},
		"assist_damage_mult": 1.0,
		"assist_tell_scale": 1.0,
		"assist_game_speed": 1.0,
	}


func load_settings() -> Dictionary:
	var base: Dictionary = default_settings()
	var p: String = settings_path()
	var d: Dictionary = _read_json_dict(p)
	if d.is_empty():
		d = _read_json_dict(p + ".bak")
	for k: String in d.keys():
		if not base.has(k):
			continue
		if k == "hold_mode" and d[k] is Dictionary:
			var hm: Dictionary = base["hold_mode"] as Dictionary
			for hk: Variant in (d[k] as Dictionary).keys():
				var hs: String = str(hk)
				if hm.has(hs):
					hm[hs] = "toggle" if str((d[k] as Dictionary)[hk]) == "toggle" else "hold"
		elif k == "bindings" and not (d[k] is Dictionary):
			continue
		else:
			base[k] = d[k]
	# Clamp Audio, Display & Assist options strictly to valid ranges; aim assist never exists.
	for vk: String in ["master_vol", "music_vol", "sfx_vol", "ambience_vol"]:
		base[vk] = clampf(float(base.get(vk, 1.0)), 0.0, 1.0)
	base["window_scale"] = clampi(int(base.get("window_scale", 3)), 1, 5)
	base["cursor_size"] = clampi(int(base.get("cursor_size", 1)), 1, 3)
	base["assist_damage_mult"] = clampf(float(base.get("assist_damage_mult", 1.0)), 0.0, 1.0)
	base["assist_tell_scale"] = clampf(float(base.get("assist_tell_scale", 1.0)), 1.0, 1.5)
	base["assist_game_speed"] = clampf(float(base.get("assist_game_speed", 1.0)), 0.7, 1.0)
	base["screen_shake"] = clampi(int(base.get("screen_shake", 100)), 0, 100)
	settings = base
	return settings


func save_settings() -> bool:
	return _write_atomic_json(settings_path(), settings)


func _write_atomic_json(user_path: String, data: Dictionary) -> bool:
	_ensure_dir()
	return _write_atomic_abs(ProjectSettings.globalize_path(user_path), data)


static func _write_atomic_abs(abs_target: String, data: Dictionary) -> bool:
	var abs_tmp: String = abs_target + ".tmp"
	var abs_bak: String = abs_target + ".bak"
	var json_text: String = JSON.stringify(data)
	var f: FileAccess = FileAccess.open(abs_tmp, FileAccess.WRITE)
	if f == null:
		push_warning("LxSaveService: failed to open tmp " + abs_tmp)
		return false
	f.store_string(json_text)
	f.flush()
	f.close()
	if FileAccess.file_exists(abs_target):
		var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_target)
		var fb: FileAccess = FileAccess.open(abs_bak, FileAccess.WRITE)
		if fb != null:
			fb.store_buffer(old_bytes)
			fb.flush()
			fb.close()
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_target)
	if err != OK:
		push_warning("LxSaveService: rename failed " + str(err))
		return false
	return true


func _read_json_dict(user_path: String) -> Dictionary:
	if not FileAccess.file_exists(user_path):
		return {}
	var txt: String = FileAccess.get_file_as_string(user_path)
	if txt.strip_edges().is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		return {}
	if parser.data is Dictionary:
		return parser.data as Dictionary
	return {}
